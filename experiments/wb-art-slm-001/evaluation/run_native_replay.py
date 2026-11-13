#!/usr/bin/env python3
"""Source-pinned native replay, custody checks and bounded subprocess ownership.

Requires a private CyberSand checkout, its exact published Linux runtime/Rapier,
and official Godot 4.7. No network, inference, image synthesis or production edits.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

SOURCE = "90719c72b9fcf90593fb7878354051ad601b47fd"
NATIVE_SHA256 = "3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd"
RAPIER_SHA256 = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"
GODOT_VERSION = "4.7.stable.official.5b4e0cb0f"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_cases(path: Path) -> list[dict]:
    document = json.loads(path.read_text())
    cases = document.get("cases") if isinstance(document, dict) else document
    if not isinstance(cases, list) or not 1 <= len(cases) <= 1024:
        raise ValueError("A manifest must contain 1–1024 cases")
    seen = set()
    for case in cases:
        if not isinstance(case, dict):
            raise ValueError("Each case must be an object")
        identifier = case.get("id", "")
        if not isinstance(identifier, str) or not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", identifier) or identifier in seen:
            raise ValueError("Unique safe case IDs of 1–64 characters are required")
        seen.add(identifier)
        for key in ("width", "height"):
            if type(case.get(key)) is not int or not 1 <= case[key] <= 512:
                raise ValueError(f"{identifier}: {key} must be 1–512")
        if not isinstance(case.get("operations"), list) or not 1 <= len(case["operations"]) <= 2048:
            raise ValueError(f"{identifier}: 1–2048 bounded operations required")
        for op in case["operations"]:
            if not isinstance(op, dict) or type(op.get("material")) is not int or op["material"] not in (0, 58):
                raise ValueError(f"{identifier}: pilot destination materials limited to Empty/Hard Wall")
        digest = hashlib.sha256(json.dumps(case["operations"],sort_keys=True,separators=(",", ":"),allow_nan=False).encode()).hexdigest()
        if case.get("operations_sha256", digest) != digest:
            raise ValueError(f"{identifier}: declared operations digest is incorrect")
        case["operations_sha256"] = digest
    return cases


def check_runtime(runtime: Path, godot: Path) -> dict:
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=runtime, text=True).strip()
    if head != SOURCE:
        raise ValueError(f"This pilot requires exact runtime source {SOURCE}; found {head}")
    native = runtime / "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
    rapier = runtime / "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
    provenance = runtime / "godot/addons/cybersand_native/bin/runtime-provenance.linux.json"
    manifest = json.loads(provenance.read_text())
    if sha256(native) != NATIVE_SHA256 or sha256(rapier) != RAPIER_SHA256:
        raise ValueError("Native or Rapier bytes do not match the qualified artifact pins")
    if manifest.get("source_commit") != SOURCE or manifest.get("sha256") != NATIVE_SHA256:
        raise ValueError("Published runtime provenance does not match this source and binary")
    checked = {}
    for name, expected in {**manifest["source_inputs"], **manifest["build_inputs"]}.items():
        data = (runtime / name).read_bytes().replace(b"\r\n", b"\n")
        actual = hashlib.sha256(data).hexdigest()
        if actual != expected:
            raise ValueError(f"Consumed source differs from published artifact: {name}")
        checked[name] = actual
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    if version != GODOT_VERSION:
        raise ValueError(f"Expected official Godot {GODOT_VERSION}, got {version}")
    return {"source_commit": head, "native_sha256": sha256(native), "rapier_sha256": sha256(rapier),
            "godot_version": version, "godot_sha256": sha256(godot), "provenance_sha256": sha256(provenance),
            "source_hashes": checked, "runtime_publication": manifest["workflow_run"],
            "artifact_id": 13999396092}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--cases", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), default=1)
    parser.add_argument("--history", choices=("each", "per-theme"), default="per-theme")
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args()
    runtime, godot, cases_path, output = (p.resolve() for p in (args.runtime, args.godot, args.cases, args.output))
    cases = read_cases(cases_path)
    custody = check_runtime(runtime, godot)
    output.mkdir(parents=True, exist_ok=False)
    harness = Path(__file__).with_name("native_replay.gd")
    tag = hashlib.sha256(str(output).encode()).hexdigest()[:12]
    target = runtime / f"godot/tests/_slm_native_replay_{tag}.gd"
    if target.exists():
        raise ValueError("Private harness destination already exists; inspect prior invocation first")
    shutil.copyfile(harness, target)
    (output / "input-cases.json").write_text(json.dumps({"cases": cases}, indent=2)+"\n")
    custody.update({"harness_sha256": sha256(harness), "input_manifest_sha256": sha256(cases_path),
                    "normalized_manifest_sha256": sha256(output/"input-cases.json"), "workers": args.workers,
                    "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),
                    "claim": "Pinned Linux headless native-material pilot; no current-main, Windows, graphical or human acceptance"})
    (output / "runtime-custody.json").write_text(json.dumps(custody, indent=2)+"\n")
    env = os.environ.copy()
    env.update(SB_NATIVE_CASES=str(output/"input-cases.json"), SB_NATIVE_OUTPUT=str(output),
               SB_NATIVE_WORKERS=str(args.workers), SB_NATIVE_HISTORY=args.history, XDG_DATA_HOME=str(output/"profile/data"),
               XDG_CONFIG_HOME=str(output/"profile/config"), XDG_CACHE_HOME=str(output/"profile/cache"))
    command = [str(godot), "--headless", "--path", str(runtime/"godot"), "--script", "tests/"+target.name]
    result = {"command": command, "timeout_seconds": args.timeout, "exit_code": None, "timed_out": False}
    start = time.monotonic()
    try:
        with (output/"engine.log").open("w") as log:
            try:
                process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
                result["exit_code"] = process.returncode
            except subprocess.TimeoutExpired:
                result["timed_out"] = True
        after = check_runtime(runtime, godot)
        result["runtime_unchanged"] = all(after[k] == custody[k] for k in after)
        result["harness_unchanged"] = sha256(target) == custody["harness_sha256"]
        result["input_unchanged"] = sha256(output/"input-cases.json") == custody["normalized_manifest_sha256"]
    finally:
        target.unlink(missing_ok=True)
        target.with_suffix(".gd.uid").unlink(missing_ok=True)
        result["elapsed_seconds"] = round(time.monotonic()-start,3)
        (output/"process-result.json").write_text(json.dumps(result, indent=2)+"\n")
    summary_path=output/"native-summary.json"
    passed = result["exit_code"] == 0 and all(result.get(k) for k in ("runtime_unchanged","harness_unchanged","input_unchanged"))
    if summary_path.exists():
        summary=json.loads(summary_path.read_text())
        passed = passed and summary.get("passed") is True and summary.get("cases_completed") == len(cases)
        normalized=[]
        for case in summary.get("cases",[]):
            image_path=output/case["png"]
            native_bytes=output/case["raw_materials"]
            normalized.append({"id":case["id"],"success":bool(case["passed"]),
                               "operations_sha256":case.get("operations_sha256", ""),
                               "image_sha256":sha256(image_path),"readback_sha256":sha256(native_bytes),
                               "outside_focus_violations":case["outside_area_cells"],
                               "unexpected_material_cells":case["unexpected_material_cells"],
                               "acknowledged_cells":case["terminal"]["checked"],
                               "changed_cells":case["terminal"]["changed"],
                               "filled_cells":case["filled_cells"],
                               "history_and_reopen_checked":case.get("history_and_reopen_checked",False),
                               "png":case["png"],"raw_materials":case["raw_materials"]})
        normalized_report={"runtime":{k:custody[k] for k in ("source_commit","native_sha256","godot_version")},
                           "qualification":custody["claim"],"passed":passed,"cases":normalized}
        (output/"admission-receipts.json").write_text(json.dumps(normalized_report,indent=2)+"\n")
    else:
        passed=False
    print(json.dumps({"passed": passed, "output": str(output), **result},indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(f"Native replay refused: {exc}",file=sys.stderr)
        raise SystemExit(2)
