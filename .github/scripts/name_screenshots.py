"""Renames attachments exported by `xcresulttool export attachments` to their test names."""

import json
import re
import sys
from pathlib import Path


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
            name = attachment.get("suggestedHumanReadableName") or exported
            # "light-05-home_0_<UUID>.png" -> "light-05-home.png"
            clean = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(?=\.\w+$)", "", name)
            target = out / clean
            if target.exists():
                target = out / name
            (out / exported).rename(target)
            print(f"{exported} -> {target.name}")


if __name__ == "__main__":
    main(sys.argv[1])
