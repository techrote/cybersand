#!/usr/bin/env python3
"""Admit only known Godot-import rewrites of tracked Rapier .import metadata.

The application and GDScript sources must remain byte-identical to HEAD. Every
allowed importer delta is recorded before reverting it in this isolated CI
checkout; all unrelated changes fail the exact-source custody gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ALLOWED = {
    "godot/addons/godot-rapier2d/Radial2D.svg.import",
    "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
    "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
    "godot/addons/godot-rapier2d/logo_square_2d.png.import",
}

def git(*args):
    return subprocess.check_output(["git", *args])

def statuses():
    raw = git("status", "--porcelain=v1", "-z", "--untracked-files=no")
    entries = [s.decode("utf-8") for s in raw.split(b"\0") if s]
    return [(s[:2], s[3:]) for s in entries]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    args=parser.parse_args()
    changed=statuses()
    unexpected=[(status,path) for status,path in changed if status!=" M" or path not in ALLOWED]
    record={"status_before":[{"status":s,"path":p} for s,p in changed],
            "unexpected":unexpected, "restored":[]}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    if not unexpected:
        for status,path in changed:
            local=Path(path)
            actual=local.read_bytes()
            original=git("show","HEAD:"+path)
            if actual.replace(b"\r\n", b"\n") != original.replace(b"\r\n", b"\n"):
                unexpected.append((status,path))
                continue
            record["restored"].append({
                "path":path,
                "imported_sha256":hashlib.sha256(actual).hexdigest(),
                "committed_sha256":hashlib.sha256(git("show","HEAD:"+path)).hexdigest()})
        if changed and not unexpected:
            subprocess.run(["git","restore","--worktree","--",*[p for _,p in changed]],check=True)
    record["status_after"]=[{"status":s,"path":p} for s,p in statuses()]
    record["passed"]=not unexpected and not record["status_after"]
    args.out.write_text(json.dumps(record,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    if not record["passed"]:
        raise SystemExit("Unexpected or surviving tracked source change: "+repr(record))
    print("Gentek2048 importer metadata custody PASS; allowed files restored:",len(changed))

if __name__=="__main__":
    main()
