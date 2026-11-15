#!/usr/bin/env python3
"""Stage the owner's original Red Alert CD data outside the source tree."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path


def digest(path: Path) -> str:
    checksum = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("allied", type=Path, help="Extracted Allied CD directory")
parser.add_argument("soviet", type=Path, help="Extracted Soviet CD directory")
parser.add_argument("destination", type=Path, help="Private RAData staging directory")
args = parser.parse_args()

sources = {
    "REDALERT.MIX": args.allied / "INSTALL" / "REDALERT.MIX",
    "allied/MAIN.MIX": args.allied / "MAIN.MIX",
    "soviet/MAIN.MIX": args.soviet / "MAIN.MIX",
}
for path in sources.values():
    if not path.is_file():
        parser.error(f"missing original CD file: {path}")
if digest(args.allied / "INSTALL" / "REDALERT.MIX") != digest(
    args.soviet / "INSTALL" / "REDALERT.MIX"
):
    parser.error("Allied and Soviet REDALERT.MIX files differ")
if digest(sources["allied/MAIN.MIX"]) == digest(sources["soviet/MAIN.MIX"]):
    parser.error("Allied and Soviet MAIN.MIX files unexpectedly match")

args.destination.mkdir(parents=True, exist_ok=True)
manifest = {"source": "owner-supplied Red Alert 95 Allied and Soviet CDs", "files": {}}
for name, source in sources.items():
    target = args.destination / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest["files"][name] = {"bytes": target.stat().st_size, "sha256": digest(target)}
(args.destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
