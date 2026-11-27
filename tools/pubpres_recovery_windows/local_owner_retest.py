"""Package an exact committed local owner retest over the preserved 00478 Windows delivery."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

import package_windows as package

ROOT = package.ROOT
base = package.base
sys.path.insert(0, str(ROOT / "tools/pubpres_final_recovery"))
from retained_runtime import make_binding, BINDING

ORIGINAL = "00478f29b9abaccb1e358137e8a9a48894c1690b"
ARCHIVE_SHA = "79abd9beb457a79b0735fbb78e962d72bebacf6ce01ca91200e323197bccc990"
MANIFEST_SHA = "5ffd095397ac17017835320138b19b770e596ae063d5b372cefcaee09e12a9a5"

def prepare_import(payload, record, commit):
    """Run the pinned editor once. Ship only relocatable runtime resources."""
    engine = payload / record["engine"]["gui"]["path"]
    with tempfile.TemporaryDirectory(prefix="PUBPRES prepare imports ") as temp:
        scratch = Path(temp)
        project = scratch / "godot"
        shutil.copytree(payload / record["sources"]["C"]["project"], project)
        shutil.copyfile(payload / record["owner_observer"], project / "tests/pubpres_playability_owner_start.gd")
        profile = scratch / "profile"
        profile.mkdir()
        env = {k:v for k,v in os.environ.items() if not k.startswith("CYBERSAND_")}
        for key in ("APPDATA","LOCALAPPDATA","XDG_DATA_HOME","XDG_CONFIG_HOME","XDG_CACHE_HOME"):
            env[key] = str(profile / key)
        result = subprocess.run([str(engine),"--headless","--editor","--path",str(project),"--import","--quit",
                                 "--audio-driver","Dummy"],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                                creationflags=subprocess.CREATE_NO_WINDOW,timeout=300)
        package.need(result.returncode == 0 and b"ERROR:" not in result.stdout,
                     "Local headless import failed: "+result.stdout[-3000:].decode(errors="replace"))
        cache = project / ".godot"
        resources = [cache / n for n in ("extension_list.cfg","global_script_class_cache.cfg","uid_cache.bin")]
        resources.extend(p for p in (cache / "imported").glob("*.ctex") if not p.name.endswith(".editor.ctex"))
        package.need(3 < len(resources) <= 256, "Missing runtime import textures or unexpected growth")
        files = {}
        for resource in resources:
            name = resource.relative_to(cache).as_posix()
            data = resource.read_bytes()
            package.need(0 < len(data) <= 10*1024**2 and str(scratch).lower().encode() not in data.lower()
                         and scratch.as_posix().lower().encode() not in data.lower(), "Nonportable runtime cache: "+name)
            target = payload / "qualification/runtime-import" / name
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(data)
            files[name] = package.digest(target)
    return {"source_commit":commit,"engine_sha256":package.digest(engine),"files":files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-archive", type=Path, required=True)
    parser.add_argument("--original-runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    need = package.need
    commit = base.git(ROOT, "rev-parse", "HEAD")
    tree = base.git(ROOT, "rev-parse", "HEAD^{tree}")
    need(commit != ORIGINAL and not base.git(ROOT, "status", "--porcelain", "--untracked-files=normal"),
         "Use a clean exact resulting application checkout")
    base.git(ROOT, "merge-base", "--is-ancestor", ORIGINAL, commit)
    need(package.digest(args.original_archive) == ARCHIVE_SHA, "Original qualified Windows archive differs")
    binding = make_binding(ROOT, {"source_commit":commit, "source_tree":tree},
                           args.original_runtime.resolve(), target_platform="windows")
    need(binding["original_build"]["source_commit"] == ORIGINAL, "Original Windows native build differs")
    dest = args.output.resolve()
    dest.mkdir(parents=True, exist_ok=False)
    name = f"CyberSand-LOCAL-OWNER-RETEST-{commit[:12]}-Windows.zip"
    payload = dest / "Workbench"
    with zipfile.ZipFile(args.original_archive) as original:
        original.extractall(payload)
    manifest = payload / package.MANIFEST
    need(package.digest(manifest) == MANIFEST_SHA, "Original Windows manifest differs")
    record = json.loads(manifest.read_bytes())
    need(base.file_hashes(payload) == record["files_sha256"], "Original package inventory differs")
    need(record["recovery_selection"] == package.recovery_policy.selection(), "Retest changed the selected policy")
    need(record["sources"]["C"]["native"]["sha256"] == binding["binary_sha256"], "Retained DLL bytes differ")
    # Keep original derived native receipts, paired DLL and package-only resource copies.
    # Compile inputs and build policy are checked by make_binding. Refuse other binary changes.
    preserved = {base.NATIVE, "godot/addons/cybersand_native/runtime-provenance.json",
                 "godot/addons/cybersand_native/runtime-provenance.linux.json"}
    roots = ["godot", package.TOOLS, package.LEGACY, "tools/pubpres_playability_build"]
    unchanged = ["examples/worldgen", "materials", "third_party", "tools/pubpres_final/registration.json",
                 "tools/ci/restore_workbench_godot.py", "tools/ci/build_workbench_godot.py"]
    need(not base.git(ROOT, "diff", "--name-only", ORIGINAL, commit, "--", *unchanged),
         "A staged recipe, dependency, registration or engine changed; extend qualification")
    touched = {}
    for entry in base.git(ROOT, "diff", "--name-status", "--no-renames", ORIGINAL, commit, "--", *roots).splitlines():
        status, path = entry.split("\t")
        if path in preserved:
            continue
        need(Path(path).suffix.lower() in {".gd",".uid",".gdshader",".tscn",".tres",".cfg",".godot",".py",".ps1",".md",".json"},
             "Review changed local package input: "+path)
        member = ("sources/C/" if path.startswith("godot/") else "") + path
        target = payload / base.safe_name(member)
        if status == "D":
            target.unlink()
            touched[member] = None
        else:
            need(status in {"M","A"}, "Unrecognized source change")
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(base.lfs_bytes(ROOT, commit, path, base.committed(ROOT,commit,path)))
            touched[member] = package.digest(target)
    # All changed application files and tools above are the exact committed Git bytes.
    source = record["sources"]["C"]
    source.update(source_commit=commit, source_tree=tree, parents=base.git(ROOT,"show","-s","--format=%P",commit).split(),
                  source_projection="Exact committed application with the input-equivalent retained 00478 Windows native build.")
    for filename, scene in record["owner_commands"].items():
        (payload / filename).write_bytes(package.command(commit,scene))
    for filename, cfg in record["comparison_commands"].items():
        (payload / filename).write_bytes(package.command(commit,cfg["scene"],mode=cfg["mode"]))
    (payload / "Collect Results.cmd").write_bytes(package.command(commit,collector=True))
    (payload / package.recovery_policy.FALLBACK_COMMAND).write_bytes(package.command(commit,mode="Fallback"))
    (payload / package.recovery_policy.DONOR_COMMAND).write_bytes(package.command(commit,mode="Fallback",donor=True))
    package.write_json(payload / "qualification" / BINDING, binding)
    record["local_import"] = prepare_import(payload, record, commit)
    scope = "Local owner retest. The original Windows qualification applies to 00478f29. This application requires new owner evaluation."
    (payload/"READ-ME.md").write_text("# Local Windows Workbench retest\n\n"+scope+"\n\n"+
                                      (payload / package.TOOLS / "README.md").read_text(encoding="utf-8"),encoding="utf-8")
    record.update(schema="pubpres-local-owner-retest-v1",candidate_commit=commit,package_filename=name,scope=scope,
                  historical_archive_sha256=ARCHIVE_SHA,changed_committed_files=touched)
    record["files_sha256"] = base.file_hashes(payload)
    record["file_count"] = len(record["files_sha256"])
    package.write_json(manifest,record)
    digest = package.digest(manifest)
    (payload / (package.MANIFEST+".sha256")).write_text(f"{digest}  {package.MANIFEST}\n",encoding="ascii")
    shell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    subprocess.run([str(shell), "-NoProfile", "-ExecutionPolicy","Bypass","-File",str(payload/record["owner_launcher"]),
                    "-Action","Verify","-PackageRoot",str(payload),"-ExpectedCandidate",commit],check=True,timeout=600,
                   env={**os.environ,"PSModulePath":str(shell.parent/"Modules")})
    archive = dest/name
    with zipfile.ZipFile(archive,"x",zipfile.ZIP_DEFLATED,compresslevel=6) as out:
        for member in sorted([*record["files_sha256"],package.MANIFEST,package.MANIFEST+".sha256"]):
            out.write(payload/member,member)
    with zipfile.ZipFile(archive) as out:
        need(out.testzip() is None,"Local retest ZIP CRC failure")
    checksum = package.digest(archive)
    Path(str(archive)+".sha256").write_text(f"{checksum}  {name}\n",encoding="ascii")
    print(f"{archive}\nSHA-256 {checksum}")


if __name__ == "__main__":
    main()
