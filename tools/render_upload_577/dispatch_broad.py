#!/usr/bin/env python3
"""Request the existing complete workflows at this owned branch, without Ready."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess

BRANCH = "perf/render-upload-577-finisher-20261116"
REPOSITORY = "techrote/cybersand"
WORKFLOWS = ("documentation.yml", "native.yml", "gdextension.yml", "palette-shader-qualification.yml")


def request_admission(source: str, environment: dict, request: dict) -> None:
    if (not re.fullmatch(r"[0-9a-f]{40}", source) or environment.get("GITHUB_SHA") != source
            or environment.get("GITHUB_REPOSITORY") != REPOSITORY
            or environment.get("GITHUB_REF") != "refs/heads/" + BRANCH
            or environment.get("GITHUB_EVENT_NAME") not in {"push", "workflow_dispatch"}
            or request.get("schema") != 1 or request.get("branch") != BRANCH
            or request.get("dispatch_broad") is not True):
        raise ValueError("Unadmitted source, repository, branch, event or explicit qualification request")


def api(arguments: list[str], payload: dict | None = None) -> str:
    command = ["gh", "api", *arguments]
    if payload is not None:
        command += ["--input", "-"]
    return subprocess.check_output(command, input=json.dumps(payload) if payload is not None else None,
                                   text=True, timeout=90)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    request = json.loads(Path(__file__).with_name("qualification-request.json").read_text())
    request_admission(args.source_sha, dict(os.environ), request)
    report = {"schema": "render-upload-577-broad-dispatch-v1", "source": args.source_sha,
              "branch": BRANCH, "request": request, "complete": False, "dispatches": [],
              "limits": "Dispatch acceptance is not a passing CI result. Each resulting run must prove this exact head."}
    try:
        for workflow in WORKFLOWS:
            ref = json.loads(api([f"repos/{REPOSITORY}/git/ref/heads/{BRANCH}"]))
            if ref["object"]["sha"] != args.source_sha:
                raise ValueError("Owned branch advanced; refusing to dispatch under a stale source label")
            at = datetime.now(timezone.utc).isoformat()
            api(["--method", "POST", f"repos/{REPOSITORY}/actions/workflows/{workflow}/dispatches"],
                {"ref": BRANCH})
            report["dispatches"].append({"workflow": workflow, "requested_utc": at, "expected_head": args.source_sha})
        report["complete"] = True
    finally:
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
