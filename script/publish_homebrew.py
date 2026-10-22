#!/usr/bin/env python3
"""Prepare a tap cask and manifest from an already published, checksummed DMG."""
import argparse
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("version")
parser.add_argument("build", type=int)
parser.add_argument("--tap-dir", type=Path, default=Path("build/homebrew-tap"))
args = parser.parse_args()
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version) or args.build <= 0:
    parser.error("A numeric major.minor.patch version and positive build number are required")
tap = args.tap_dir.resolve()
if subprocess.check_output(["git", "-C", str(tap), "status", "--porcelain"], text=True).strip():
    parser.error("Tap checkout must be clean before preparing a release")
release = json.loads(subprocess.check_output([
    "gh", "release", "view", f"v{args.version}", "--repo", "squazaryu/T-DuoBar",
    "--json", "assets,isDraft",
], text=True))
if release["isDraft"]:
    parser.error("The GitHub release is still a draft")
name = f"T-DuoBar-{args.version}.dmg"
asset = next((item for item in release["assets"] if item["name"] == name), None)
expected_url = f"https://github.com/squazaryu/T-DuoBar/releases/download/v{args.version}/{name}"
if not asset or asset["state"] != "uploaded" or asset["url"] != expected_url:
    parser.error("Expected published DMG asset is missing")
digest = asset.get("digest", "")
if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
    parser.error("GitHub has not supplied a valid SHA-256 digest for the uploaded DMG")
cask = tap / "Casks/t-duobar.rb"
text, version_count = re.subn(r'^  version "[^"]+"$', f'  version "{args.version},{args.build}"', cask.read_text(), flags=re.M)
text, hash_count = re.subn(r'^  sha256 "[^"]+"$', f'  sha256 "{digest[7:]}"', text, flags=re.M)
if version_count != 1 or hash_count != 1:
    parser.error("Cask must contain exactly one version and one SHA-256 field")
cask.write_text(text)
(tap / "updates/t-duobar.json").write_text(json.dumps({"schema": 1, "version": args.version, "build": args.build}, indent=2) + "\n")
print(f"Prepared {args.version} (build {args.build}), SHA-256 verified by GitHub")
print(f"Review and commit Casks/t-duobar.rb and updates/t-duobar.json together in {tap}")
