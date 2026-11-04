#!/usr/bin/env python3
"""Frozen-head local qualification; delegates process execution to repository runner.

This external harness does not edit the checkout or substitute platform evidence.
"""
from __future__ import annotations
import contextlib
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent / "cybersand-383"
OUT = BASE / "host-attempt-4"
GODOT_SOURCE = Path("/workspace/scratch/b45094545f38/deps/godot-4.7/Godot_v4.7-stable_linux.x86_64")
GODOT_ARCHIVE = GODOT_SOURCE.with_suffix(GODOT_SOURCE.suffix + ".zip")
GODOT = BASE / "deps" / GODOT_SOURCE.name
SOURCE = "73b10f9b800e72f358f22f470e57a4531002c168"
TREE = "31c5a9a4b986820985658d3ed2228ebe9008828a"
EXPECTED_GODOT = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()

def write(name: str, data: object) -> None:
    (OUT / name).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")

def source_snapshot() -> dict[str, str]:
    baseline = json.loads((ROOT / "docs/audits/in-tools-361a-2026-11-04/host-source-identity.json").read_text())
    paths = set(baseline["source_inputs"])
    suffixes = {".gd", ".tscn", ".tres", ".gdshader", ".glsl", ".json", ".py", ".cpp", ".hpp", ".h", ".c", ".inc", ".cfg", ".gdextension", ".sh", ".yml"}
    for relative in git("ls-files", "native", "godot", "tools", "third_party", ".github").splitlines():
        if Path(relative).suffix in suffixes and not relative.startswith("godot/.godot/"):
            paths.add(relative)
    return {relative: sha(ROOT / relative) for relative in sorted(paths)}

def main() -> int:
    OUT.mkdir(exist_ok=False)
    assert git("rev-parse", "HEAD") == SOURCE
    assert git("rev-parse", "HEAD^{tree}") == TREE
    assert git("status", "--porcelain=v1", "--untracked-files=all") == "", "initial checkout must be clean"
    sys.path.insert(0, str(ROOT / "tools/ci"))
    import run_godot_regressions as runner
    import run_windows_godot_regressions as windows_contract
    import check_repository

    baseline = json.loads((ROOT / "docs/audits/in-tools-361a-2026-11-04/host-source-identity.json").read_text())
    before = source_snapshot()
    baseline_drift = [p for p, digest in baseline["source_inputs"].items() if before[p] != digest]
    assert not baseline_drift, baseline_drift
    manifest_paths = [
        "godot/addons/cybersand_native/runtime-provenance.linux.json",
        "godot/addons/cybersand_native/runtime-provenance.json",
        "godot/addons/godot-rapier2d/runtime-provenance.linux.json",
        "godot/addons/godot-rapier2d/runtime-provenance.windows.json",
    ]
    manifests = {}
    native_inputs = windows_contract.native_input_paths(ROOT)
    for relative in manifest_paths:
        document = json.loads((ROOT / relative).read_text())
        assert not check_repository.verify_runtime(ROOT, document), relative
        if "cybersand_native" in relative:
            assert set(document["source_inputs"]) == native_inputs
        payload = ROOT / document["artifact"]
        committed = subprocess.check_output(["git", "show", SOURCE + ":" + document["artifact"]], cwd=ROOT, timeout=60)
        pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", committed)
        assert pointer and pointer[1].decode() == document["sha256"] and int(pointer[2]) == document["size"]
        materialized = not payload.read_bytes().startswith(b"version https://git-lfs.github.com/spec/v1")
        if relative.endswith("linux.json"):
            assert materialized and payload.read_bytes()[:4] == b"\x7fELF"
        manifests[relative] = {
            "manifest_sha256": sha(ROOT / relative), "artifact": document["artifact"],
            "expected_sha256": document["sha256"], "expected_size": document["size"],
            "actual_file_sha256": sha(payload), "materialized": materialized,
            "source_inputs_count": len(document["source_inputs"]), "source_inputs_match": True,
            "source_commit": document.get("source_commit"), "build_commit": document.get("build_commit"),
            "source_tree": document.get("source_tree"), "toolchain": document.get("toolchain"),
            "execution_claim": "local Linux headless qualification" if relative.endswith("linux.json") else "UNTESTED; identity only",
        }
    assert not check_repository.verify_rapier_overrides(ROOT, json.loads((ROOT / "godot/third_party/rapier2d.lock.json").read_text()))
    lock = json.loads((ROOT / "third_party/godot-runtime.lock.json").read_text())
    assert GODOT_ARCHIVE.stat().st_size == lock["editor"]["size"] and sha(GODOT_ARCHIVE) == lock["editor"]["sha256"]
    assert sha(GODOT_SOURCE) == EXPECTED_GODOT
    GODOT.parent.mkdir(exist_ok=True)
    shutil.copy2(GODOT_SOURCE, GODOT)
    assert sha(GODOT) == EXPECTED_GODOT
    version = subprocess.check_output([str(GODOT), "--version"], text=True, timeout=30).strip()
    assert version == lock["godot_version"]
    env = dict(os.environ)
    env.update({"CYBERSAND_SOURCE_REVISION": SOURCE, "XDG_DATA_HOME": str(OUT / "xdg-data"),
                "XDG_CONFIG_HOME": str(OUT / "xdg-config"), "XDG_CACHE_HOME": str(OUT / "xdg-cache"),
                "GODOT_SILENCE_ROOT_WARNING": "1"})
    names = [row["name"] for row in json.loads((ROOT / "docs/audits/in-tools-361a-2026-11-04/host-qualification.json").read_text())["results"]]
    all_cases = {case.name: case for case in runner.discover_cases()}
    cases = [all_cases[name] for name in names]
    identity = {
        "schema": "in-tools-383-local-source-custody-v1", "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "source_commit": SOURCE, "source_tree": TREE, "initial_git_status": "",
        "platform": platform.platform(), "uname": list(platform.uname()), "os_release": Path("/etc/os-release").read_text(),
        "python": sys.version, "compiler": subprocess.check_output(["g++", "--version"], text=True).splitlines()[0],
        "godot_path": str(GODOT), "godot_version": version, "godot_sha256": sha(GODOT),
        "godot_archive_sha256": sha(GODOT_ARCHIVE), "godot_archive_bytes": GODOT_ARCHIVE.stat().st_size,
        "harness_sha256": sha(Path(__file__)), "runner_sha256": sha(ROOT / "tools/ci/run_godot_regressions.py"),
        "source_inputs": before, "source_inputs_count": len(before),
        "prior_implementation_commit": baseline["source_sha"], "prior_754_source_inputs_unchanged": not baseline_drift,
        "runtime_provenance": manifests, "native_input_count": len(native_inputs),
        "selected_cases": names, "execution_policy": runner.execution_policy.identity(),
        "isolation_environment": {k: env[k] for k in ("CYBERSAND_SOURCE_REVISION", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME")},
        "physical_device_input": "UNTESTED", "rendered_desktop": "UNTESTED", "windows_execution": "UNTESTED",
    }
    write("identity-before.json", identity)
    report = {"schema": "in-tools-383-local-host-processes-v1", "source_commit": SOURCE, "source_tree": TREE,
              "scope": "15 scoped headless Linux tests; source-matched native and Rapier; synthetic input", "results": [], "status": "running"}
    write("processes.json", report)
    import_case = runner.Case("import", ("--editor", "--import"), runner.execution_policy.watchdog_seconds("godot_import_seconds"), 3.0)
    failed_any = False
    for case in [import_case, *cases]:
        print("START " + case.name, flush=True)
        with (OUT / (case.name + "-runner.log")).open("w") as runner_log, contextlib.redirect_stdout(runner_log):
            record, failed = runner.run_case(str(GODOT), case, OUT, "preflight" if case.name == "import" else "case", env=env)
        log_text = (OUT / record["log"]).read_text()
        record["footer_lines"] = [line for line in log_text.splitlines() if re.search(r"assertions|RESULT |regression:|checks=", line, re.I)][-8:]
        record["runner_log_sha256"] = sha(OUT / (case.name + "-runner.log"))
        report["results"].append(record)
        failed_any = failed_any or failed
        write("processes.json", report)
        print(json.dumps({"name": case.name, "status": record["status"], "seconds": record["seconds"], "exit": record["returncode"], "footers": record["footer_lines"]}), flush=True)
        if case.name == "import" and failed:
            report["blocked_cases"] = names
            break
    after = source_snapshot()
    drift = [p for p, h in before.items() if after.get(p) != h]
    runtime_drift = [m["artifact"] for m in manifests.values() if sha(ROOT / m["artifact"]) != m["actual_file_sha256"]]
    status_after = git("status", "--porcelain=v1", "--untracked-files=all")
    write("identity-after.json", {"finished_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "source_commit": git("rev-parse", "HEAD"),
          "source_tree": git("rev-parse", "HEAD^{tree}"), "git_status": status_after,
          "source_inputs_count": len(after), "source_drift": drift, "runtime_drift": runtime_drift, "godot_sha256": sha(GODOT)})
    report["source_inputs_unchanged"] = not drift
    report["runtime_bytes_unchanged"] = not runtime_drift
    report["post_import_git_status"] = status_after
    report["status"] = "failed" if failed_any or drift or runtime_drift else "passed"
    write("processes.json", report)
    print("HOST_QUALIFICATION " + report["status"], flush=True)
    return int(report["status"] != "passed")

if __name__ == "__main__":
    raise SystemExit(main())
