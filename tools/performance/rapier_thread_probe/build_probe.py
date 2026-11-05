"""Build a test-only Win32 counter extension against the exact tested engine.

Generated ABI header, API dump, DLL and descriptor are local outputs.
This builds no production source and links no CyberSand or Rapier library.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--cc", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    out = root / "build/rapier-thread-probe"
    out.mkdir(parents=True, exist_ok=True)
    engine = args.engine.resolve()
    compiler_path = args.cc or shutil.which("gcc") or next((p for p in (
        Path("C:/msys64/mingw64/bin/gcc.exe"),
        Path("C:/Users/_/.codex/cm009-native-tools/w64devkit/bin/gcc.exe")) if p.is_file()), None)
    if not compiler_path:
        raise RuntimeError("No diagnostic C compiler; pass --cc")
    cc = Path(compiler_path).resolve()
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=30).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        raise RuntimeError("Probe requires pinned engine, got " + version)
    for option in ("--dump-gdextension-interface", "--dump-extension-api"):
        subprocess.run([str(engine), "--headless", option], cwd=out, check=True, timeout=45)
    api = json.loads((out / "extension_api.json").read_text(encoding="utf-8"))
    packed = next(x for x in api["builtin_classes"] if x["name"] == "PackedInt64Array")
    resize = next(x for x in packed["methods"] if x["name"] == "resize")
    if resize["hash"] != 848867239:
        raise RuntimeError("Unexpected PackedInt64Array ABI")
    sizes = next(x for x in api["builtin_class_sizes"] if x["build_configuration"] == "float_64")
    if any(x["size"] > 32 for x in sizes["sizes"] if x["name"] in ("StringName", "PackedInt64Array")):
        raise RuntimeError("Unexpected ABI storage size")
    source = Path(__file__).with_name("thread_probe.c")
    dll = out / "rapier_thread_probe.windows.x86_64.dll"
    command = [str(cc), "-O2", "-Wall", "-Wextra", "-std=c11", "-shared", "-static-libgcc",
               "-I", str(out), str(source), "-o", str(dll)]
    compiler = subprocess.check_output([str(cc), "--version"], text=True, timeout=30)
    run = subprocess.run(command, capture_output=True, text=True, timeout=90)
    (out / "build.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    run.check_returncode()
    target = root / "godot/tests/performance/rapier_thread_probe"
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dll, target / dll.name)
    descriptor = target / "rapier_thread_probe.gdextension"
    descriptor.write_text('[configuration]\nentry_symbol = "rapier_thread_probe_init"\n'
                          'compatibility_minimum = "4.7"\nreloadable = false\n\n'
                          '[libraries]\nwindows.debug.x86_64 = "./' + dll.name + '"\n'
                          'windows.release.x86_64 = "./' + dll.name + '"\n', encoding="utf-8")
    paths = [engine, source, out / "gdextension_interface.h", out / "extension_api.json", dll, descriptor]
    identity = {"schema": "rapier-thread-probe-build-v1", "engine_version": version,
                "compiler": compiler, "command": command,
                "files": {str(p): {"sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
                                    "size": p.stat().st_size} for p in paths}}
    (out / "build-identity.json").write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(identity, indent=2))


if __name__ == "__main__":
    main()
