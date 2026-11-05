#!/usr/bin/env python3
"""Create an ignored full raw/source/runtime review packet, never a release."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser(__doc__);parser.add_argument("output",type=Path);args=parser.parse_args()
    assert not args.output.exists();args.output.mkdir(parents=True)
    source=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT).decode().strip()
    manifest=json.loads((ROOT/"docs/audits/sol-chamber-20261105/manifest.json").read_text(encoding="utf-8"))
    snapshot=args.output/"source-snapshot.zip"
    subprocess.run(["git","archive","--format=zip","-o",str(snapshot.resolve()),source],cwd=ROOT,check=True,timeout=120)
    patch=args.output/"dependent.patch";patch.write_bytes(subprocess.check_output(["git","diff","--binary","a38098b1",source],cwd=ROOT))
    runtime=ROOT/"build/la-physical/runtimes";build=json.loads((runtime/"receipt.json").read_text(encoding="utf-8"))
    packet=args.output/("sol-chamber-001-"+source[:8]+"-review.zip")
    with zipfile.ZipFile(packet,"x",compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as archive:
        archive.write(snapshot,"source-snapshot.zip");archive.write(patch,"dependent.patch")
        for item in manifest["local_raw_files"]:
            path=(ROOT/item["path"]).resolve();assert path.is_relative_to(ROOT)
            assert path.stat().st_size==item["bytes"] and sha(path)==item["sha256"],item["path"]
            archive.write(path,"raw/"+item["path"].replace("\\","/"))
        for folder in [ROOT/"build/sol-chamber-validation",ROOT/"build/sol-chamber-sealing"]:
            for path in folder.glob("*"):
                if path.is_file() and path.suffix in [".json",".log"]:archive.write(path,"review-commands/"+folder.name+"/"+path.name)
        archive.write(runtime/"receipt.json","runtime-overrides/receipt.json")
        for name,digest in build["outputs"].items():
            path=runtime/name;assert sha(path)==digest;archive.write(path,"runtime-overrides/"+name)
        instructions="Unpack source-snapshot.zip into source/. Raw files are under raw/.\nRun: python source/tools/experiments/sol_chamber_review_packet.py raw --verify-only\nFor full independent reduction omit --verify-only and select a fresh --output.\nSource/physics identities, failed/interrupted attempts and runtime hashes remain separate.\nThis is a review packet, not a product release or original SOL admission.\n"
        archive.writestr("REVIEW.txt",instructions)
    with zipfile.ZipFile(packet) as archive:assert archive.testzip() is None
    result=dict(source_snapshot=source,physics_source=manifest["execution_source"],packet=str(packet.resolve()),bytes=packet.stat().st_size,sha256=sha(packet),source_archive_bytes=snapshot.stat().st_size,source_archive_sha256=sha(snapshot),dependent_patch_sha256=sha(patch),raw_files=len(manifest["local_raw_files"]),status="LOCAL_FULL_PACKET; separate independent audit pending; no publication/merge")
    (args.output/"packet.json").write_bytes((json.dumps(result,indent=2)+"\n").encode());print(json.dumps(result,indent=2))

if __name__=="__main__":main()
