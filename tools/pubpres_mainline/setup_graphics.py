#!/usr/bin/env python3
"""Acquire the exact official engine and bind original native inputs for CI."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
from identity import digest
from retained_runtime import make_binding, BINDING
from run_campaign import source_identity
from run_focus import ENGINE_SHA256


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    platform = "windows" if os.name == "nt" else "linux"
    suffix = "win64.exe" if os.name == "nt" else "linux.x86_64"
    archive = output / ("godot-windows.zip" if os.name == "nt" else "godot-linux.zip")
    subprocess.run(["curl.exe" if os.name == "nt" else "curl", "--fail", "--location", "--retry", "3", "--connect-timeout", "30", "--max-time", "600",
                    "--output", str(archive), "https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_" + suffix + ".zip"], check=True, timeout=900)
    if os.name == "nt":
        sys.path.insert(0, str(ROOT / "tools/ci"))
        from run_windows_godot_regressions import prepare_godot
        wrapper, record = prepare_godot(archive)
        # The historical PUBPRES driver authenticates the actual engine, while
        # the Windows regression wrapper authenticates the console parent too.
        engine = wrapper.parent / "Godot_v4.7-stable_win64.exe"
    else:
        if digest(archive) != "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c":
            raise ValueError("Official Linux Godot archive differs")
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None:
                raise ValueError("Official Linux archive integrity failure")
            bundle.extractall(output / "engine")
        engine = output / "engine/Godot_v4.7-stable_linux.x86_64"
        engine.chmod(0o755)
        wrapper = engine
        record = {"archive_sha256": digest(archive)}
    if digest(engine) != ENGINE_SHA256[platform]:
        raise ValueError("Actual official engine executable differs")
    version = subprocess.check_output([str(wrapper), "--version"], text=True, timeout=30).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Official engine version differs")
    source = source_identity(ROOT)
    original = args.runtime.resolve()
    request = json.loads((ROOT / ".github/pubpres-mainline-run.json").read_bytes())
    runtime_record = json.loads((original / "PUBPRES-RUNTIME.json").read_bytes())
    if request.get("phase") != "build" and runtime_record.get("source_commit") != request.get("runtime_source"):
        raise ValueError("Native build source differs from the exact campaign request")
    bound = output / "bound-runtime"
    shutil.copytree(original, bound)
    binding = make_binding(ROOT, source, original, target_platform=platform)
    (bound / BINDING).write_text(json.dumps(binding, indent=2) + "\n", encoding="utf-8")
    identity = {"source": source, "platform": platform, "engine": str(engine), "wrapper": str(wrapper),
                "engine_sha256": digest(engine), "version": version, "archive": str(archive), "archive_sha256": digest(archive),
                "original_native_receipt_sha256": digest(original / "PUBPRES-RUNTIME.json"),
                "binding_sha256": digest(bound / BINDING), "bound_runtime": str(bound), "official_record": record}
    (output / "GRAPHICS-SETUP.json").write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    if os.environ.get("GITHUB_ENV"):
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
            for key, value in {"GODOT_EXE": engine, "GODOT_CONSOLE": wrapper, "GODOT_ARCHIVE": archive, "BOUND_RUNTIME": bound}.items():
                stream.write(key + "=" + str(value) + "\n")
    print(json.dumps(identity, indent=2))


if __name__ == "__main__":
    main()
