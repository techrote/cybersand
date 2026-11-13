"""Bind a freshly built runtime to immutable source without changing retained pins.

The build job calls ``stamp`` immediately after its source build; consumers call
``verify``. This is artifact custody, not a substitute for the build log.
Adapted from #567 runtime custody and current native_candidate_identity.py.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"
RAPIER_PINS = {
    "Linux": ("libgodot_rapier.linux.x86_64-unknown-linux-gnu.so", "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"),
    "Windows": ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll", "b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7"),
}
SOURCE_SCOPES = ["native/include", "native/src", "godot/native_extension", "godot/scripts",
                 "godot/main.tscn", "godot/project.godot", "godot/tests/run_agent_painter_foundation.gd",
                 "experiments/agent_painter", "tools/build_native_extension.sh",
                 "tools/build_native_extension_windows.sh", "tools/build_pinned_godot_cpp.sh"]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True, timeout=60).strip()


def source_identity(root: Path, source_sha: str) -> dict:
    if not re.fullmatch(r"[a-f0-9]{40}", source_sha) or git(root, "rev-parse", "HEAD") != source_sha:
        raise ValueError("Expected source must be the checked-out full commit SHA")
    git(root, "diff", "--exit-code", "HEAD", "--", *SOURCE_SCOPES)
    suffixes = {".gd", ".tscn", ".godot", ".cpp", ".hpp", ".h", ".inc", ".py", ".json", ".sh"}
    untracked = "\n".join(name for name in git(root, "ls-files", "--others", "--exclude-standard", "--", *SOURCE_SCOPES).splitlines()
                          if Path(name).suffix in suffixes)
    if untracked:
        raise ValueError("Untracked qualification source: " + untracked)
    inputs = {}
    for name in git(root, "ls-files", "--", *SOURCE_SCOPES).splitlines():
        path = root / name
        if path.suffix in suffixes:
            inputs[name] = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
    if len(inputs) < 100:
        raise ValueError("Source inventory incomplete")
    return {"source_sha": source_sha, "source_tree": git(root, "rev-parse", "HEAD^{tree}"),
            "source_inputs": inputs, "source_inputs_sha256": hashlib.sha256(canonical(inputs)).hexdigest()}


def native_path(root: Path) -> Path:
    name = "cybersand_native.windows.x86_64.dll" if platform.system() == "Windows" else "libcybersand_native.linux.x86_64.so"
    return root / "godot/addons/cybersand_native/bin" / name


def stamp(root: Path, source_sha: str, output: Path) -> dict:
    source = source_identity(root, source_sha)
    binary = native_path(root)
    data = binary.read_bytes()
    if len(data) < 100000 or not (data.startswith(b"\x7fELF") or data.startswith(b"MZ")):
        raise ValueError("A materialized native ELF/PE runtime is required")
    manifest = {"schema_version": 1, "kind": "agent-painter-source-build", **source,
                "platform": platform.system(), "native_path": binary.relative_to(root).as_posix(),
                "native_sha256": digest(binary), "native_size": len(data),
                "build_custody": "Same-job source build; consult build logs, not this manifest alone"}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("x", encoding="utf-8") as file:
        json.dump(manifest, file, indent=2, sort_keys=True)
        file.write("\n")
    return manifest


def verify(root: Path, manifest_path: Path, source_sha: str, godot: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    source = source_identity(root, source_sha)
    binary = native_path(root)
    if (manifest.get("kind") != "agent-painter-source-build" or manifest.get("schema_version") != 1
            or manifest.get("platform") != platform.system()
            or any(manifest.get(key) != value for key, value in source.items())
            or manifest.get("native_path") != binary.relative_to(root).as_posix()
            or manifest.get("native_sha256") != digest(binary)
            or manifest.get("native_size") != binary.stat().st_size):
        raise ValueError("Native build/source custody mismatch")
    rapier_name, rapier_hash = RAPIER_PINS[platform.system()]
    rapier = root / "godot/addons/godot-rapier2d/bin" / rapier_name
    if digest(rapier) != rapier_hash:
        raise ValueError("Rapier bytes differ from accepted dependency pin")
    version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
    if version != GODOT_VERSION:
        raise ValueError(f"Expected official Godot {GODOT_VERSION}; found {version}")
    return {**manifest, "runtime_manifest_sha256": digest(manifest_path), "rapier_sha256": rapier_hash,
            "godot_version": version, "godot_sha256": digest(godot)}


def development_runtime(root: Path, source_sha: str, godot: Path) -> dict:
    """Use the retained source-matched binary for local debugging, never admission."""
    if git(root, "rev-parse", "HEAD") != source_sha:
        raise ValueError("Development source head mismatch")
    suffix = "" if platform.system() == "Windows" else ".linux"
    manifest_path = root / ("godot/addons/cybersand_native/runtime-provenance" + suffix + ".json")
    manifest = json.loads(manifest_path.read_text())
    inputs = manifest["source_inputs"]
    for name, expected in inputs.items():
        actual = hashlib.sha256((root / name).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        if actual != expected:
            raise ValueError("Retained runtime does not match native input: " + name)
    binary = native_path(root)
    if digest(binary) != manifest["sha256"]:
        raise ValueError("Retained development runtime hash mismatch")
    rapier_name, rapier_hash = RAPIER_PINS[platform.system()]
    if digest(root / "godot/addons/godot-rapier2d/bin" / rapier_name) != rapier_hash:
        raise ValueError("Development Rapier hash mismatch")
    version = subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip()
    if version != GODOT_VERSION:
        raise ValueError("Development Godot version mismatch")
    # Record dirty/new test/compiler bytes, while preserving the source build's
    # separate identity and restricting this mode to non-admitting diagnostics.
    harness_inputs = {}
    for directory in ("experiments/agent_painter/native", "godot/scripts"):
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and path.suffix in {".py", ".gd", ".json"}:
                harness_inputs[path.relative_to(root).as_posix()] = digest(path)
    for name in ("compiler.py", "recipes.py", "corpus.py", "program.schema.json", "gallery.py"):
        path = root / "experiments/agent_painter" / name
        harness_inputs[path.relative_to(root).as_posix()] = digest(path)
    test = root / "godot/tests/run_agent_painter_foundation.gd"
    harness_inputs[test.relative_to(root).as_posix()] = digest(test)
    return {"schema_version": 1, "source_sha": source_sha, "build_source_sha": manifest["source_commit"],
            "native_sha256": digest(binary), "rapier_sha256": rapier_hash, "godot_version": version,
            "godot_sha256": digest(godot), "runtime_manifest_sha256": digest(manifest_path),
            "native_source_inputs": inputs, "harness_inputs": harness_inputs, "development_only": True}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["stamp", "verify"])
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path)
    args = parser.parse_args()
    if args.command == "verify" and args.godot is None:
        parser.error("verify requires --godot")
    result = stamp(args.root, args.source_sha, args.output) if args.command == "stamp" else verify(
        args.root, args.output, args.source_sha, args.godot)
    print(json.dumps({key: result[key] for key in ("source_sha", "native_sha256", "source_inputs_sha256")}, indent=2))
