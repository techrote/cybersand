"""Immutable original Stage C source, request and research asset custody."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

from experiments.driv3r.provenance import ROOT, source_identity as inherited
from experiments.driv3r.stage_b.provenance import ACCEPTED_STAGE_A

STAGE_B_SOURCE = "2ea0f09c8fbbead7386f47232b0a61cff59bdfdc"
STAGE_B_RELEASE_SHA256 = "17b22a80463594575ea28cb688a5b5ab155366b1127d09c3198aef853cae3ce6"
CASE_PATH = "experiments/driv3r/stage_c/cases.json"
REQUEST_PATH = "experiments/driv3r/stage_c/qualification-request.json"
REQUIRED = (CASE_PATH,REQUEST_PATH,"experiments/driv3r/stage_c/qualify.py",
            "experiments/driv3r/stage_c/provenance.py",
            "experiments/driv3r/ci_stage_c.sh",".github/workflows/driv3r-stage-c.yml",
            "godot/tests/run_driv3r_stage_a.gd","experiments/driv3r/native.py")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def expected_request(root: Path = ROOT) -> dict:
    return {"schema":"driv3r-stage-c-request-v1","sequence":3,
            "stage_b_source":STAGE_B_SOURCE,
            "stage_b_release_sha256":STAGE_B_RELEASE_SHA256,
            "frozen_case_sha256":sha((root/CASE_PATH).read_bytes()),"draft_hold":True}


def validate_request(root: Path = ROOT) -> dict:
    data = json.loads((root/REQUEST_PATH).read_text(encoding="utf-8"))
    if data != expected_request(root):
        raise ValueError("Stage C exact request or frozen fixture changed")
    return data


def source(source_sha: str, root: Path = ROOT) -> dict:
    if subprocess.check_output(["git","rev-parse","HEAD"],cwd=root,text=True).strip() != source_sha:
        raise ValueError("Source SHA differs from checkout")
    if subprocess.run(["git","merge-base","--is-ancestor",STAGE_B_SOURCE,source_sha],
                      cwd=root).returncode:
        raise ValueError("Stage C source does not descend from frozen Stage B")
    data = inherited(source_sha,root)
    # Stage A's immutable source scope deliberately did not know about the
    # future Stage C workflow. Extend custody here, without altering Stage A
    # or Stage B's previously qualified inventory/implementation.
    inputs = dict(data["source_inputs"])
    new_workflow = ".github/workflows/driv3r-stage-c.yml"
    current = (root/new_workflow).read_bytes()
    committed = subprocess.check_output(["git","show","HEAD:"+new_workflow],cwd=root)
    if current != committed:
        raise ValueError("Stage C workflow differs from committed source")
    inputs[new_workflow] = sha(current.replace(b"\r\n",b"\n"))
    if any(path not in inputs for path in REQUIRED):
        raise ValueError("Stage C source inputs omitted from extended immutable custody")
    extended_sha = sha(json.dumps(inputs,sort_keys=True,separators=(",",":")).encode("utf-8"))
    return {**data,"schema":"driv3r-stage-c-source-custody-v1",
            "source_inputs":dict(sorted(inputs.items())),
            "source_inputs_sha256":extended_sha,
            "stage_c_workflow_sha256":inputs[new_workflow],
            "stage_b_source":STAGE_B_SOURCE,"stage_a_source":ACCEPTED_STAGE_A,
            "frozen_case_sha256":sha((root/CASE_PATH).read_bytes()),
            "frozen_request":validate_request(root)}


def verify_stage_b_release(path: Path) -> dict:
    if sha(path.read_bytes()) != STAGE_B_RELEASE_SHA256:
        raise ValueError("Prerequisite Stage B release ZIP hash mismatch")
    with zipfile.ZipFile(path) as archive:
        corrupt=archive.testzip()
        if corrupt is not None: raise ValueError("Stage B archive corrupted: "+corrupt)
        summary=json.loads(archive.read("execution/summary.json"))
        if not (summary.get("source_sha")==STAGE_B_SOURCE and
                summary.get("infrastructure_passed") is True and
                summary.get("campaign_complete") is True and
                summary.get("result")=="GO_TO_BOUNDED_STAGE_C" and
                summary["usefulness"]["proceed_to_modest_stage_c"] is True):
            raise ValueError("Stage B original evidence does not satisfy conditional C")
        return {"schema":"driv3r-stage-c-stage-b-admission-v1",
                "stage_b_source":STAGE_B_SOURCE,"archive_sha256":STAGE_B_RELEASE_SHA256,
                "decision":"GO_TO_BOUNDED_STAGE_C", "original_infrastructure_passed":True}


def package(directory: Path, output: Path, source_sha: str) -> dict:
    output.mkdir(parents=True,exist_ok=False)
    diagnostic = {}
    try:
        execution=json.loads((directory/"execution/summary.json").read_text())
        bootstrap=json.loads((directory/"qualification-exit.json").read_text())
        diagnostic={"execution":execution.get("result"),"failure":execution.get("failure")}
        eligible=(execution.get("schema")=="driv3r-stage-c-summary-v1" and
                  execution.get("source_sha")==source_sha and
                  execution.get("source_tree") and
                  execution.get("campaign_complete") is True and
                  execution.get("infrastructure_passed") is True and
                  execution.get("draft_hold") is True and
                  execution.get("result")=="QUALIFIED_RESEARCH_HANDOFF" and
                  bootstrap.get("source_sha")==source_sha and
                  bootstrap.get("exit_code")==0 and
                  bootstrap.get("log_capture_exit_code")==0 and
                  len(execution.get("episodes",[]))==6 and
                  len(execution.get("replays",[]))==6 and
                  all(r.get("passed") for r in execution["replays"]) and
                  len(execution.get("frames",[]))==6)
    except (ValueError, KeyError, OSError):
        eligible=False
    paths=sorted(p for p in directory.rglob("*") if p.is_file() and not p.is_symlink())
    if not paths:
        raise ValueError("No Stage C evidence to retain")
    inventory={str(p.relative_to(directory)):{"sha256":sha(p.read_bytes()),"size":p.stat().st_size}
               for p in paths}
    name=f"driv3r-stage-c-{source_sha[:12]}.zip"
    destination=output/name
    with zipfile.ZipFile(destination,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=True) as zipout:
        for p in paths:
            zipout.write(p,str(p.relative_to(directory)))
        zipout.writestr("INVENTORY.json",json.dumps(inventory,sort_keys=True,indent=2)+"\n")
    with zipfile.ZipFile(destination) as zipin:
        if zipin.testzip() is not None:raise ValueError("Stage C archive CRC failed")
        if len(zipin.namelist()) != len(paths)+1:raise ValueError("Archive inventory cardinality mismatch")
        for name_in, rec in inventory.items():
            info=zipin.getinfo(name_in)
            if info.file_size!=rec["size"] or sha(zipin.read(name_in))!=rec["sha256"]:
                raise ValueError("Stage C zip material differs from original: "+name_in)
    digest=sha(destination.read_bytes())
    manifest={"schema":"driv3r-stage-c-publication-v1","source_sha":source_sha,
              "stage_b_source":STAGE_B_SOURCE,"stage_b_release_sha256":STAGE_B_RELEASE_SHA256,
              "draft_hold":True,"publication_eligible":bool(eligible),
              "publication_is_acceptance":False,"file_count":len(paths),
              "archive":name,"sha256":digest,"bytes":destination.stat().st_size,
              "diagnostic":diagnostic}
    (output/"MANIFEST.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    (output/"SHA256SUMS.txt").write_text(digest+"  "+name+"\n")
    return manifest


def main():
    parser=argparse.ArgumentParser()
    sub=parser.add_subparsers(dest="mode",required=True)
    for mode in ("source","request"):
        p=sub.add_parser(mode);p.add_argument("--source-sha",required=True);p.add_argument("--output",required=True,type=Path)
    p=sub.add_parser("admit-b");p.add_argument("--archive",required=True,type=Path);p.add_argument("--output",required=True,type=Path)
    p=sub.add_parser("package");p.add_argument("--directory",required=True,type=Path);p.add_argument("--output",required=True,type=Path);p.add_argument("--source-sha",required=True)
    args=parser.parse_args()
    if args.mode=="source":result=source(args.source_sha)
    elif args.mode=="request":
        source(args.source_sha)
        result={"schema":"driv3r-stage-c-exact-request-v1","source_sha":args.source_sha,
                "request":validate_request()}
    elif args.mode=="admit-b":result=verify_stage_b_release(args.archive)
    else:result=package(args.directory,args.output,args.source_sha)
    if args.mode!="package":
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    else:print(json.dumps(result,sort_keys=True))


if __name__=="__main__":
    main()
