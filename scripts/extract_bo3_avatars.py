#!/usr/bin/env python3
"""Extract the reference BO3 draft board's character avatars into native resources.

Usage:
    python3 scripts/extract_bo3_avatars.py /path/to/moba-bo3-draft.html [--output DIR]

The reference HTML is not bundled into the app. Pass its local path each time
you need to regenerate the assets (for example, a local copy under `htmls/`).
The generated WebP files and `avatar-index.json` are committed so the app builds
and runs offline.
"""

import argparse
import base64
import json
import re
import sys
from pathlib import Path

DEFAULT_OUTPUT = Path(__file__).resolve().parent.parent / "MobaRandom/Resources/BO3"


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract BO3 character avatars from the reference HTML."
    )
    parser.add_argument("html", type=Path, help="path to the reference BO3 HTML file")
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"output directory (default: {DEFAULT_OUTPUT})",
    )
    args = parser.parse_args()

    if not args.html.is_file():
        fail(f"reference HTML not found: {args.html}")

    text = args.html.read_text(encoding="utf-8")
    data_match = re.search(
        r'<script id="heroAvatarData" type="application/json">(.*?)</script>',
        text,
        re.S,
    )
    if not data_match:
        fail("could not find the heroAvatarData JSON block in the reference HTML")

    avatars = json.loads(data_match.group(1))
    aliases_match = re.search(r"var HERO_ALIASES = \{(.*?)\};", text, re.S)
    aliases = (
        dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', aliases_match.group(1)))
        if aliases_match
        else {}
    )

    names = sorted(avatars)
    output = args.output
    avatars_dir = output / "avatars"
    avatars_dir.mkdir(parents=True, exist_ok=True)

    for old in avatars_dir.glob("a*.webp"):
        old.unlink()

    index = {"version": 1, "aliases": aliases, "avatars": {}}
    for number, name in enumerate(names, 1):
        meta = avatars[name]
        source = meta.get("src", "")
        prefix = "data:image/webp;base64,"
        if not isinstance(source, str) or not source.startswith(prefix):
            fail(f"avatar {name!r} is not a base64 WebP image")
        try:
            image_bytes = base64.b64decode(source[len(prefix):], validate=True)
        except Exception as error:  # noqa: BLE001 - report the offending name
            fail(f"avatar {name!r} could not be decoded: {error}")
        file_id = f"a{number:03d}"
        (avatars_dir / f"{file_id}.webp").write_bytes(image_bytes)
        index["avatars"][name] = {
            "file": file_id,
            "element": meta.get("element", ""),
        }

    index_path = output / "avatar-index.json"
    index_path.write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Extracted {len(names)} avatars to {avatars_dir}")
    print(f"Wrote {index_path}")


if __name__ == "__main__":
    main()
