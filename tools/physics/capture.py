"""Capture local source deltas and rebuilt runtime identities outside the repo.

Run before standalone/browser/async measurements and after the final checkpoint.
Batch runners also capture per-batch input hashes. This does not certify an old
export's embedded source label or update published runtime provenance.
"""
import argparse
import json
import shutil
import subprocess
import os
from pathlib import Path
from run import ROOT, identity, git, sha
from runtime_identity import default_godot, desktop_runtime, fresh_output, verify_unchanged

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("output", type=Path)
p.add_argument("--godot", type=Path, default=default_godot())
p.add_argument("--cxx", default=str(ROOT.parent / ".local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe") if os.name == "nt" else "c++")
args = p.parse_args()
out = fresh_output(args.output)
paths, runtime = desktop_runtime(ROOT, args.godot)
optional = [ROOT / "build" / (name + (".exe" if os.name == "nt" else ""))
            for name in ("transport_sampling", "transport_characterisation", "physics_characterisation")]
paths.extend(path for path in optional if path.is_file())
for profile in ("web", "web-threaded"):
    paths += [v for v in (ROOT / "build" / profile).glob("*") if v.is_file()]
manifest = identity(paths)
manifest["runtime_selection"] = runtime
manifest["optional_cli_missing"] = [str(path) for path in optional if not path.is_file()]
extra = ["godot/project.godot", "godot/main.tscn", "godot/web_main.tscn", "godot/third_party/rapier2d.lock.json",
         "tools/build_web.py", "godot/native_extension/SConstruct", "tools/build_native.py"]
manifest["additional_inputs"] = {p: sha(ROOT / p) for p in extra if (ROOT / p).is_file()}
manifest["python_freeze"] = subprocess.check_output([__import__("sys").executable, "-m", "pip", "freeze"], text=True, timeout=30)
compiler = shutil.which(args.cxx) or args.cxx
manifest["compiler_command"] = [str(compiler), "--version"]
manifest["compiler_sha256"] = sha(compiler)
manifest["compiler"] = subprocess.check_output(manifest["compiler_command"], text=True, timeout=15)
manifest["source_note"] = "Actual HEAD plus recorded local deltas. Web build-info acquisition label is not this source identity."
(out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
patch = subprocess.check_output(["git", "-C", str(ROOT), "diff", "--binary", "HEAD", "--", ".", ":(exclude)godot/addons/cybersand_native/bin/*"])
(out / "tracked-source.patch").write_bytes(patch)
for relative in git("ls-files", "--others", "--exclude-standard").splitlines():
    if relative.startswith(("native/", "godot/", "tools/physics/")):
        target = out / "untracked-source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
for relative in git("diff", "HEAD", "--name-only").splitlines():
    if relative.startswith(("native/", "godot/scripts/", "godot/tests/", "godot/native_extension/")) and (ROOT / relative).is_file():
        target = out / "changed-source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
verification = {"artifacts": verify_unchanged(manifest["artifacts"]),
                "descriptors": verify_unchanged(runtime["descriptors"]),
                "engine_lock": verify_unchanged(runtime["engine_lock"]),
                "scope": "unchanged configured artifact bytes after metadata capture; no fixture executed"}
(out / "runtime-verification.json").write_text(json.dumps(verification, indent=2), encoding="utf-8")
print(json.dumps({"output": str(out), "head": manifest["head"], "source_sha256": manifest["source_sha256"]}))
