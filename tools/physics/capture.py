"""Capture local source deltas and rebuilt runtime identities outside the repo.

Run before standalone/browser/async measurements and after the final checkpoint.
Batch runners also capture per-batch input hashes. This does not certify an old
export's embedded source label or update published runtime provenance.
"""
import argparse
import json
import shutil
import subprocess
from pathlib import Path
from run import ROOT, identity, git, sha

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("output", type=Path)
args = p.parse_args()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
paths = [ROOT / "build/physics_characterisation.exe", ROOT / "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
         ROOT / "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
         Path("C:/Godot47/Godot_v4.7-stable_win64_console.exe")]
for profile in ("web", "web-threaded"):
    paths += [v for v in (ROOT / "build" / profile).glob("*") if v.is_file()]
manifest = identity(paths)
extra = ["godot/project.godot", "godot/scenes/main.tscn", "godot/third_party/rapier2d.lock.json",
         "tools/build_web.py", "godot/native_extension/SConstruct", "tools/build_native.py"]
manifest["additional_inputs"] = {p: sha(ROOT / p) for p in extra if (ROOT / p).is_file()}
manifest["python_freeze"] = subprocess.check_output([__import__("sys").executable, "-m", "pip", "freeze"], text=True)
manifest["compiler"] = subprocess.check_output([str(ROOT.parent / ".local/llvm-mingw-20260826-ucrt-x86_64/bin/clang++.exe"), "--version"], text=True)
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
    if relative.startswith(("native/", "godot/scripts/", "godot/tests/", "godot/native_extension/")):
        target = out / "changed-source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
print(json.dumps({"output": str(out), "head": manifest["head"], "source_sha256": manifest["source_sha256"]}))
