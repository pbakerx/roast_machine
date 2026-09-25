#!/usr/bin/env python3
"""Synthetic 70s-yearbook portrait for App Store screenshots and smoke tests.

A cartoon, not a real person, so there are no likeness or photo-rights issues.
Drawn in the Footlight Pop language: lit from below, bold silhouette, violet
shadows.

    python3 scripts/make_demo_portrait.py marketing/demo_portrait.jpg
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 1170, 1560
SKIN = (232, 184, 138)
HAIR = (74, 46, 24)
GOLD = (240, 210, 120)


def soft(img: Image.Image, draw_fn, blur: int) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.paste(layer, (0, 0), layer)


def main(out: str) -> None:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):  # mottled studio backdrop, brown to mustard
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(96 + 90 * t), int(66 + 70 * t), int(46 + 30 * t)))

    cx = W // 2
    soft(img, lambda g: g.ellipse([cx - 360, 300, cx + 360, 1280], fill=(70, 40, 110, 140)), 50)
    d = ImageDraw.Draw(img)

    # Burnt-orange turtleneck with a huge collar.
    d.polygon([(cx - 360, H), (cx - 280, 1020), (cx - 130, 930), (cx + 130, 930),
               (cx + 280, 1020), (cx + 360, H)], fill=(200, 88, 40))
    d.rounded_rectangle([cx - 120, 880, cx + 120, 990], radius=40, fill=(176, 72, 32))
    d.rectangle([cx - 70, 820, cx + 70, 900], fill=(214, 164, 120))

    # Hair back layer, then the face.
    d.ellipse([cx - 250, 300, cx + 250, 700], fill=HAIR)
    d.rectangle([cx - 250, 480, cx - 180, 760], fill=HAIR)
    d.rectangle([cx + 180, 480, cx + 250, 760], fill=HAIR)
    d.ellipse([cx - 185, 430, cx + 185, 900], fill=SKIN)
    # Hair fringe on top of the forehead.
    d.chord([cx - 215, 330, cx + 215, 640], start=180, end=360, fill=HAIR)
    d.rectangle([cx - 195, 470, cx - 150, 780], fill=HAIR)   # sideburns
    d.rectangle([cx + 150, 470, cx + 195, 780], fill=HAIR)

    # Footlight glow on the chin.
    soft(img, lambda g: g.ellipse([cx - 160, 720, cx + 160, 900], fill=(255, 226, 170, 90)), 30)
    d = ImageDraw.Draw(img)

    # Eyes behind big amber aviators.
    for sx in (-1, 1):
        ex = cx + sx * 88
        d.rounded_rectangle([ex - 78, 560, ex + 78, 668], radius=46,
                            fill=(214, 150, 66), outline=GOLD, width=9)
        d.ellipse([ex - 26, 594, ex + 26, 636], fill=(250, 240, 220))
        d.ellipse([ex - 12, 602, ex + 12, 628], fill=(40, 26, 20))
    d.line([cx - 12, 596, cx + 12, 596], fill=GOLD, width=9)
    # Eyebrows raised in confidence.
    for sx in (-1, 1):
        ex = cx + sx * 88
        d.arc([ex - 70, 505, ex + 70, 575], start=200, end=340, fill=HAIR, width=14)

    # Nose, then a proud handlebar mustache, then the grin.
    d.polygon([(cx, 650), (cx - 26, 730), (cx + 26, 730)], fill=(214, 160, 116))
    d.chord([cx - 120, 715, cx + 120, 800], start=180, end=360, fill=HAIR)
    d.ellipse([cx - 150, 745, cx - 100, 790], fill=HAIR)
    d.ellipse([cx + 100, 745, cx + 150, 790], fill=HAIR)
    d.chord([cx - 70, 770, cx + 70, 850], start=0, end=180, fill=(120, 50, 40))
    d.rectangle([cx - 52, 772, cx + 52, 790], fill=(250, 245, 235))

    # Shoebox-print vignette.
    soft(img, lambda g: g.rectangle([0, 0, W, H], outline=(40, 20, 10, 210), width=70), 60)

    img.convert("RGB").save(out, "JPEG", quality=92)
    print(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "marketing/demo_portrait.jpg")
