#!/usr/bin/env python3
"""Build a symbolized, pinned control or patched Rapier experiment (never publish)."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tomllib
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "third_party/rapier-bvh-build.lock.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(args, cwd, env=None, timeout=2400):
    print("+", subprocess.list2cmdline([str(a) for a in args]), flush=True)
    subprocess.run([str(a) for a in args], cwd=cwd, env=env, check=True, timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=("control", "patched"), required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    patch = ROOT / lock["patch"]
    if digest(patch) != lock["patch_sha256"]:
        raise RuntimeError("Candidate patch differs from its lock")
    workspace, output = args.workspace.resolve(), args.output.resolve()
    workspace.mkdir(parents=True, exist_ok=False)
    output.mkdir(parents=True, exist_ok=True)
    source, crate = workspace / "addon", workspace / "rapier2d"
    run(["git", "init", source], workspace)
    run(["git", "remote", "add", "origin", lock["addon_repository"]], source)
    run(["git", "fetch", "--depth=1", "origin", lock["addon_commit"]], source)
    run(["git", "checkout", "--detach", "FETCH_HEAD"], source)
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip()
    if actual != lock["addon_commit"]:
        raise RuntimeError("Wrong addon source")
    archive = workspace / "rapier.crate"
    with urllib.request.urlopen(lock["crate_url"], timeout=60) as response:
        archive.write_bytes(response.read())
    if digest(archive) != lock["crate_sha256"]:
        raise RuntimeError("Wrong crate archive")
    with tarfile.open(archive) as bundle:
        bundle.extractall(workspace / "crate", filter="data")
    shutil.move(workspace / "crate" / "rapier2d-0.35.1", crate)
    join = crate / "src/pipeline/physics_pipeline/mod.rs"
    if digest(join) != lock["base_join_source_sha256"]:
        raise RuntimeError("Wrong original join source")
    original = join.read_text(encoding="utf-8")
    run(["git", "init"], crate)
    run(["git", "apply", "--check", patch], crate)
    run(["git", "apply", patch], crate)
    patched = join.read_text(encoding="utf-8")
    # git apply follows checkout EOL policy; make candidate source identity
    # identical on Windows and Linux before hashing or compiling.
    join.write_text(patched, encoding="utf-8", newline="\n")
    if digest(join) != lock["patched_join_source_sha256"]:
        raise RuntimeError("Patched join differs from its canonical LF source hash")
    helper_start = patched.index("// CYBERSAND_BVH_JOIN_BEGIN")
    helper_end = patched.index("// CYBERSAND_BVH_JOIN_END")
    helper = patched[helper_start:helper_end]
    tests = patched[patched.index("#[cfg(all(test, feature = \"parallel\"))]"):patched.index("mod quarantine;")]
    if args.variant == "control":
        join.write_text(original, encoding="utf-8", newline="\n")
        helper = '#[cfg(feature = "parallel")]\nfn receive_deferred_bvh<T>(rx: std::sync::mpsc::Receiver<T>) -> T { rx.recv().expect("the deferred BVH optimization task died") }\n'
    upstream_lock = (source / "Cargo.lock").read_text(encoding="utf-8")
    if hashlib.sha256(upstream_lock.encode()).hexdigest() != lock["upstream_cargo_lock_sha256"]:
        raise RuntimeError("Wrong upstream Cargo.lock")
    upstream_packages = tomllib.loads(upstream_lock)["package"]
    # A path override changes only the rapier2d source identity, never a version.
    block = next(b for b in upstream_lock.split("[[package]]") if '\nname = "rapier2d"\n' in b)
    changed = re.sub(r'^(source|checksum) = .*\n', '', block, flags=re.MULTILINE)
    resolved_lock = upstream_lock.replace(block, changed)
    (source / "Cargo.lock").write_text(resolved_lock, encoding="utf-8", newline="\n")
    with (source / "Cargo.toml").open("a", encoding="utf-8") as stream:
        stream.write('\n[patch.crates-io]\nrapier2d = { path = ' + json.dumps(crate.as_posix()) + ' }\n')
    env = os.environ.copy()
    env.update(lock["release_overrides"])
    env["GDRUST_GODOT_BIN"] = str(args.godot.resolve())
    env["CARGO_BUILD_JOBS"] = "2"
    toolchain = "+" + lock["rust_toolchain"]
    run(["cargo", toolchain, "fetch", "--locked"], source, env)
    # Compile the exact helper and its regression tests in a minimal harness.
    # All harness registry versions/checksums must match the upstream Cargo.lock.
    harness = workspace / "join-regression"
    harness.mkdir()
    (harness / "src").mkdir()
    (harness / "src/lib.rs").write_text(helper + tests, encoding="utf-8")
    (harness / "Cargo.toml").write_text('[package]\nname="cybersand-bvh-regression"\nversion="0.0.0"\nedition="2024"\n[features]\ndefault=["parallel"]\nparallel=[]\n[dependencies]\nrayon="=1.12.0"\n', encoding="utf-8")
    run(["cargo", toolchain, "generate-lockfile", "--offline"], harness, env)
    harness_lock = tomllib.loads((harness / "Cargo.lock").read_text(encoding="utf-8"))
    for package in harness_lock["package"]:
        if "source" in package and package not in upstream_packages:
            raise RuntimeError("Regression harness drifted from upstream dependency lock: " + package["name"])
    regression = subprocess.run(["cargo", toolchain, "test", "--locked", "--", "--nocapture"], cwd=harness, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
    (output / "join-regression.log").write_text(regression.stdout, encoding="utf-8")
    print(regression.stdout, flush=True)
    expected = 124 if args.variant == "control" else 0
    if regression.returncode != expected or (expected == 124 and "CYBERSAND_BVH_CONTROL_STALLED" not in regression.stdout):
        raise RuntimeError(f"Unexpected join regression outcome: {regression.returncode}, expected {expected}")
    run(["cargo", toolchain, "build", "--locked", "--release", "--features", ",".join(lock["features"])], source, env)
    if (source / "Cargo.lock").read_text(encoding="utf-8") != resolved_lock:
        raise RuntimeError("Addon dependency lock changed during compilation")
    windows = sys.platform == "win32"
    filename = "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if windows else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    binary = source / "target/release" / ("godot_rapier.dll" if windows else "libgodot_rapier.so")
    shutil.copy2(binary, output / filename)
    if windows:
        shutil.copy2(source / "target/release/godot_rapier.pdb", output / "godot_rapier.pdb")
    shutil.copy2(source / "Cargo.lock", output / "Cargo.lock")
    manifest = {"schema_version": 1, "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "variant": args.variant, "platform": "windows" if windows else "linux", "build_inputs": lock,
                "build_lock_sha256": digest(LOCK), "upstream_cargo_lock_sha256": hashlib.sha256(upstream_lock.encode()).hexdigest(),
                "resolved_cargo_lock_sha256": digest(source / "Cargo.lock"), "join_source_sha256": digest(join),
                "godot_version": subprocess.check_output([str(args.godot), "--version"], text=True, timeout=30).strip(),
                "rustc": subprocess.check_output(["rustc", toolchain, "-Vv"], text=True),
                "join_regression_exit": regression.returncode,
                "artifacts": {p.name: digest(p) for p in output.iterdir() if p.is_file()}}
    (output / "rapier-build.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
