#!/usr/bin/env python3
"""Frame raw simulator captures into App Store screenshots.

Footlight Pop: lit from below, bold silhouettes, violet shadows. Each raw
1320×2868 capture (iPhone 17 Pro Max / 6.9") is set on a stage-lit canvas of
the same size with a big headline above it, so App Store Connect accepts the
output unchanged.

    python3 scripts/frame_screenshots.py <raw_dir> <out_dir>

Raw files are matched by name to the CAPTIONS table below; anything unmatched
is skipped with a note.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868

# name-stem -> (headline, subline)
CAPTIONS = {
    "01_stage_classic": ("GET ROASTED",           "14 AI comedians. One big button."),
    "02_result_roast":  ("IT TALKS BACK",         "Real voices. Emoji punchlines."),
    "03_stage_hype":    ("OR GET HYPED",          "Flip the switch for over-the-top compliments."),
    "04_result_hype":   ("ZERO BURNS. ALL LOVE.", "Shakespeare thinks you're a legend."),
    "05_stage_mom":     ("PICK YOUR POISON",      "Angry Chef, Disappointed Mom, Shakespeare & more."),
    "06_paywall":       ("ONE PRICE. FOREVER.",   "Your first roast and first hype are free."),
}

BG_TOP = (18, 10, 20)        # deep violet-black
BG_MID = (60, 26, 58)        # violet
GLOW = (255, 122, 61)        # footlight orange
CREAM = (243, 233, 220)
AMBER = (255, 181, 71)

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def backdrop() -> Image.Image:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        c = tuple(int(BG_TOP[i] + (BG_MID[i] - BG_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=c)
    # Footlight: a hot glow rising from the bottom edge.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-W * 0.3, H * 0.78, W * 1.3, H * 1.35], fill=GLOW + (150,))
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img.paste(glow, (0, 0), glow)
    # A few drifting embers.
    ember = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ed = ImageDraw.Draw(ember)
    seeds = [(0.12, 0.62, 9), (0.86, 0.55, 7), (0.2, 0.83, 6), (0.78, 0.9, 10),
             (0.5, 0.7, 5), (0.94, 0.72, 5), (0.07, 0.9, 7), (0.63, 0.95, 8)]
    for fx, fy, r in seeds:
        x, y = fx * W, fy * H
        ed.ellipse([x - r, y - r, x + r, y + r], fill=AMBER + (200,))
    ember = ember.filter(ImageFilter.GaussianBlur(3))
    img.paste(ember, (0, 0), ember)
    return img


def rounded_device(shot: Image.Image, width: int, radius: int) -> Image.Image:
    scale = width / shot.width
    dev = shot.resize((width, int(shot.height * scale)), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", dev.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, dev.width - 1, dev.height - 1],
                                           radius=radius, fill=255)
    dev.putalpha(mask)
    return dev


def fit_font(d: ImageDraw.ImageDraw, text: str, size: int, max_w: int) -> ImageFont.FreeTypeFont:
    """Largest font (starting at size) that keeps a single line within max_w."""
    while size > 40:
        f = font(size)
        left, _, right, _ = d.textbbox((0, 0), text, font=f)
        if right - left <= max_w:
            return f
        size -= 4
    return font(size)


def wrap(d: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, max_w: int) -> list:
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        left, _, right, _ = d.textbbox((0, 0), trial, font=f)
        if right - left <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_centered(d: ImageDraw.ImageDraw, text: str, y: int, f: ImageFont.FreeTypeFont,
                  fill, spacing: int = 0) -> int:
    """Draw one line centered; returns the y just below it."""
    left, top, right, bottom = d.textbbox((0, 0), text, font=f)
    x = (W - (right - left)) // 2 - left
    # Violet drop shadow keeps the type legible over the glow.
    d.text((x + 6, y + 8), text, font=f, fill=(40, 16, 48))
    d.text((x, y), text, font=f, fill=fill)
    return y + (bottom - top) + spacing


def frame(raw: Path, headline: str, subline: str, out: Path) -> None:
    canvas = backdrop()
    d = ImageDraw.Draw(canvas)

    y = 170
    y = draw_centered(d, headline, y, fit_font(d, headline, 118, W - 120), AMBER, spacing=28)
    for line in wrap(d, subline, font(54), W - 160):
        y = draw_centered(d, line, y, font(54), CREAM, spacing=14)

    shot = Image.open(raw)
    dev = rounded_device(shot, width=int(W * 0.80), radius=110)
    x = (W - dev.width) // 2
    top = y + 110

    # Violet shadow under the device.
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([x - 10, top + 40, x + dev.width + 10, top + dev.height + 60],
                         radius=120, fill=(30, 8, 40, 200))
    shadow = shadow.filter(ImageFilter.GaussianBlur(60))
    canvas.paste(shadow, (0, 0), shadow)

    # Thin bezel line so the device reads as an object, not a floating image.
    bezel = Image.new("RGBA", (dev.width + 16, dev.height + 16), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle([0, 0, bezel.width - 1, bezel.height - 1],
                                            radius=118, fill=(12, 8, 14, 255))
    canvas.paste(bezel, (x - 8, top - 8), bezel)
    canvas.paste(dev, (x, top), dev)

    canvas.convert("RGB").save(out, "PNG", optimize=True)
    print(f"wrote {out.name}  ({canvas.width}×{canvas.height})")


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    for raw in sorted(raw_dir.glob("*.png")):
        caption = CAPTIONS.get(raw.stem)
        if not caption:
            print(f"skip {raw.name}: no caption entry")
            continue
        frame(raw, *caption, out_dir / raw.name)


if __name__ == "__main__":
    main()
