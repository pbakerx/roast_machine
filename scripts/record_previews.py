#!/usr/bin/env python3
"""Pre-record the voice-preview clips bundled in the app.

Voices come from VOICES in supabase/functions/_shared/personas.ts (one per
flavor); lines come from previewLine / hypePreviewLine in RoastMode.swift.
Writes RoastMachine/Previews/preview_<mode>_<roast|hype>.mp3.

    python3 scripts/record_previews.py [roast|hype|all]

Reads ELEVENLABS_API_KEY from Secrets.xcconfig; the key is never printed.
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def secret(name: str) -> str:
    for line in (ROOT / "Secrets.xcconfig").read_text().splitlines():
        m = re.match(rf"^{name}\s*=\s*(\S+)", line)
        if m:
            return m.group(1)
    sys.exit(f"{name} missing from Secrets.xcconfig")


def main() -> None:
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    ts = (ROOT / "supabase/functions/_shared/personas.ts").read_text()
    voices_block = ts[ts.index("export const VOICES"):]
    voices = {
        "roast": re.search(r'roast:\s*"(\w+)"', voices_block).group(1),
        "hype": re.search(r'compliment:\s*"(\w+)"', voices_block).group(1),
    }
    swift = (ROOT / "RoastMachine/Models/RoastMode.swift").read_text()
    def lines(var: str) -> dict:
        block = swift[swift.index(f"var {var}: String"):]
        block = block[:block.index("default:")]
        return dict(re.findall(r'case "(\w+)":\s+return "([^"]+)"', block))
    texts = {"roast": lines("previewLine"), "hype": lines("hypePreviewLine")}

    key = secret("ELEVENLABS_API_KEY")
    out = ROOT / "RoastMachine/Previews"
    out.mkdir(exist_ok=True)
    for flavor in (["roast", "hype"] if which == "all" else [which]):
        for mode, text in texts[flavor].items():
            req = urllib.request.Request(
                f"https://api.elevenlabs.io/v1/text-to-speech/{voices[flavor]}",
                data=json.dumps({"text": text, "model_id": "eleven_multilingual_v2",
                                 "voice_settings": {"stability": 0.4, "similarity_boost": 0.75,
                                                    "style": 0.6, "use_speaker_boost": True}}).encode(),
                headers={"xi-api-key": key, "content-type": "application/json", "accept": "audio/mpeg"})
            data = urllib.request.urlopen(req, timeout=60).read()
            (out / f"preview_{mode}_{flavor}.mp3").write_bytes(data)
            print(f"{flavor:5s} {mode:12s} {len(data):6d} bytes  \"{text}\"")


if __name__ == "__main__":
    main()
