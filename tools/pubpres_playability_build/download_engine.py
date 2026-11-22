#!/usr/bin/env python3
"""Fetch the pinned official Godot runtime into a new directory."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Dependency output must be new")
    if args.platform == "linux":
        pin = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())["editor"]
        name, algorithm, expected = pin["filename"], "sha256", pin["sha256"]
        members = ["Godot_v4.7-stable_linux.x86_64"]
    else:
        sys.path.insert(0, str(ROOT / "tools/ci"))
        from run_windows_godot_regressions import GODOT_SHA512
        name, algorithm, expected = "Godot_v4.7-stable_win64.exe.zip", "sha512", GODOT_SHA512
        members = ["Godot_v4.7-stable_win64.exe", "Godot_v4.7-stable_win64_console.exe"]
    output.mkdir(parents=True)
    archive = output / name
    url = "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/" + name
    with urllib.request.urlopen(url, timeout=300) as source, archive.open("xb") as target:
        shutil.copyfileobj(source, target)
    with archive.open("rb") as stream:
        actual = hashlib.file_digest(stream, algorithm).hexdigest()
    if actual != expected:
        raise ValueError("Pinned official Godot archive differs")
    files = {}
    with zipfile.ZipFile(archive) as container:
        if container.testzip() is not None or set(container.namelist()) != set(members):
            raise ValueError("Unexpected official engine ZIP contents")
        for member in members:
            with container.open(member) as source, (output / member).open("xb") as target:
                shutil.copyfileobj(source, target)
            if os.name != "nt":
                (output / member).chmod(0o755)
            files[member] = hashlib.sha256((output / member).read_bytes()).hexdigest()
    executable = output / members[-1]
    version = subprocess.check_output([str(executable), "--version"], text=True, timeout=45).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Engine version differs")
    (output / "ENGINE.json").write_text(json.dumps({"url": url, "archive": name,
        "algorithm": algorithm, "digest": actual, "files_sha256": files, "version": version}, indent=2) + "\n")
    print(executable)


if __name__ == "__main__":
    main()
