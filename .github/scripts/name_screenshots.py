"""Renames attachments exported by `xcresulttool export attachments` to readable names.

Screenshots keep their test names ("light-05-home.png"). XCTest's own failure files
("Debug description for "x" Button.txt") get the characters upload-artifact rejects removed.
"""

import json
import re
import sys
from pathlib import Path

NOT_ALLOWED = re.compile(r'["`:<>|*?\\/\r\n]')
TRAILING_ID = re.compile(r"_\d+_[0-9A-Fa-f-]{36}(?=\.\w+$|$)")


def readable(name: str) -> str:
    return NOT_ALLOWED.sub("", TRAILING_ID.sub("", name)).strip() or "attachment"


def main(folder: str) -> None:
    out = Path(folder)
    manifest = out / "manifest.json"
    if not manifest.exists():
        print("No manifest.json; nothing to rename")
        return
    for test in json.loads(manifest.read_text()):
        for attachment in test.get("attachments", []):
            exported = attachment.get("exportedFileName")
            if not exported or not (out / exported).exists():
                continue
            name = readable(attachment.get("suggestedHumanReadableName") or exported)
            target = out / name
            counter = 2
            while target.exists():
                stem, dot, ext = name.rpartition(".")
                target = out / (f"{stem}-{counter}.{ext}" if dot else f"{name}-{counter}")
                counter += 1
            (out / exported).rename(target)
            print(f"{exported} -> {target.name}")
    # Anything left with a character the upload rejects.
    for path in out.iterdir():
        if NOT_ALLOWED.search(path.name):
            path.rename(out / readable(path.name))


if __name__ == "__main__":
    main(sys.argv[1])
