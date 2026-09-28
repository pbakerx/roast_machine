#!/usr/bin/env python3
"""Pre-record the bundled voice clips, in every voice from VOICE_CATALOG in
supabase/functions/_shared/personas.ts.

samples  the picker's audition lines (every voice reads the same two lines, so
         players compare voices, not jokes) -> voice_<key>_<roast|hype>.mp3
soldout  the escalating out-of-tickets roasts played when someone hits the
         shutter with no tickets -> soldout_<key>_<1|2|3>.mp3

    python3 scripts/record_previews.py [samples|soldout|all] [voice-key ...]

Reads ELEVENLABS_API_KEY from Secrets.xcconfig; the key is never printed.
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LINES = {
    "roast": "Oh wow. That outfit has been through some things, and honestly? It lost.",
    "hype": "Your Majesty! The crowd is on its feet. Nobody has ever looked this good!",
}

# Strike 1 nudges, strike 2 stings, strike 3 (and every try after) goes in hard.
# Keep them clean and aimed at sneaking in, never at money trouble.
SOLD_OUT = [
    "Whoa, whoa, whoa. You're out of tickets! I don't work for free, but the Box Office "
    "is right there. Grab a few and I'll give you the show you deserve.",
    "You again? Still no ticket? Bold move. I've seen raccoons sneak into a dumpster with "
    "more subtlety. The Box Office is open, the prices are tiny, and I am not budging. "
    "Go on. I'll wait.",
    "Third time?! Okay, let's talk. You've tried to sneak into this show more times than "
    "your haircut has tried to make a comeback. The comedian left. The lights are off. "
    "Even the janitor bought a ticket! Tickets cost less than the coffee you're holding. "
    "So march to that Box Office, you magnificent freeloader, and don't come back empty-handed!",
]


def secret(name: str) -> str:
    for line in (ROOT / "Secrets.xcconfig").read_text().splitlines():
        m = re.match(rf"^{name}\s*=\s*(\S+)", line)
        if m:
            return m.group(1)
    sys.exit(f"{name} missing from Secrets.xcconfig")


def catalog() -> dict:
    ts = (ROOT / "supabase/functions/_shared/personas.ts").read_text()
    block = ts[ts.index("export const VOICE_CATALOG"):]
    block = block[:block.index("};")]
    return dict(re.findall(r'(\w+):\s*"(\w+)"', block))


def speak(key: str, voice_id: str, text: str) -> bytes:
    # 64 kbps keeps the bundle small; plenty for one voice out of a phone speaker.
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_64",
        data=json.dumps({"text": text, "model_id": "eleven_multilingual_v2",
                         "voice_settings": {"stability": 0.4, "similarity_boost": 0.75,
                                            "style": 0.6, "use_speaker_boost": True}}).encode(),
        headers={"xi-api-key": key, "content-type": "application/json", "accept": "audio/mpeg"})
    return urllib.request.urlopen(req, timeout=90).read()


def main() -> None:
    args = sys.argv[1:]
    which = args.pop(0) if args and args[0] in ("samples", "soldout", "all") else "all"
    voices = catalog()
    wanted = args or list(voices)
    key = secret("ELEVENLABS_API_KEY")
    out = ROOT / "RoastMachine/Previews"
    out.mkdir(exist_ok=True)
    jobs = []
    if which in ("samples", "all"):
        jobs += [(f"voice_{{v}}_{flavor}", text) for flavor, text in LINES.items()]
    if which in ("soldout", "all"):
        jobs += [(f"soldout_{{v}}_{n}", text) for n, text in enumerate(SOLD_OUT, 1)]
    for name in wanted:
        for pattern, text in jobs:
            data = speak(key, voices[name], text)
            file = pattern.format(v=name) + ".mp3"
            (out / file).write_bytes(data)
            print(f"{file:28s} {len(data):7d} bytes")


if __name__ == "__main__":
    main()
