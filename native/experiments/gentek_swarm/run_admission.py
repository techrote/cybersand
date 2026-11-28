#!/usr/bin/env python3
"""Qualify the bounded optional-offer experiment and frozen B/C controls."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from run_negotiated import (DONORS, HARNESS, HERE, ROOT, CommandCancelled, canonical, fingerprint,
                            git, normalized_control, now, source_inputs, stop_command_group, unpack_source)

FROZEN_C = "21617b14253cc6dcf35a83ded558565c8db517f5"


def normalized_negotiated(document, expected_source):
    """Enumerate source-dependent identity fields; retain all behavioral fields."""
    if document.get("schema") != 2 or document.get("type") != "negotiated":
        raise ValueError("Unexpected frozen C schema/type")

    def item(value, result=False):
        value = dict(value)
        if value.get("source") != expected_source:
            raise ValueError(f"Unexpected source {value.get('source')!r}")
        value["source"] = "<source-dependent>"
        prefix, separator, suffix = value["definition"].rpartition(".")
        if not separator or not re.fullmatch(r"[0-9a-f]{64}", suffix):
            raise ValueError("Missing compiled definition suffix")
        value["definition"] = prefix + ".<compiled-input-sha256>"
        if result:
            value["request_digest"] = "<source-dependent>"
            value["digest"] = "<source-dependent>"
        return value

    out = dict(document)
    out["digest"] = "<source-dependent>"
    out["control"] = normalized_control(document["control"], expected_source)
    for key in ("frame_request", "mosaic_request", "residual_request"):
        out[key] = item(document[key])
    out["frame"] = dict(document["frame"])
    for key in ("core", "result"):
        out["frame"][key] = item(document["frame"][key], True)
    for key in ("mosaic", "no_offers"):
        out[key] = dict(document[key])
        out[key]["result"] = item(document[key]["result"], True)
    for key in ("final_frame", "final_mosaic", "residual"):
        out[key] = item(document[key], True)
    return out


def compare_c(old, new, expected_new_source, destination):
    names = lambda path: {p.name for p in path.glob("negotiated_*.json")
                          if p.name != "negotiated_summary.json"}
    old_names, new_names = names(old), names(new)
    report = {
        "check": "Frozen qualified SWARM-002 full-offer behavioral regression",
        "frozen_source": FROZEN_C, "candidate_source": expected_new_source,
        "normalization": "Only enumerated source identity, request/result digests and final compiled-definition SHA-256 suffix. Every material, graph, domain, attempt, work and failure field remains exact.",
        "cases": [], "errors": [], "started_utc": now(),
    }
    if old_names != new_names or len(old_names) != 72:
        report["errors"].append({"old_cases": len(old_names), "new_cases": len(new_names),
                                  "missing": sorted(old_names - new_names),
                                  "unexpected": sorted(new_names - old_names)})
    for name in sorted(old_names & new_names):
        before = json.loads((old / name).read_text())
        after = json.loads((new / name).read_text())
        a = hashlib.sha256(canonical(normalized_negotiated(before, FROZEN_C))).hexdigest()
        b = hashlib.sha256(canonical(normalized_negotiated(after, expected_new_source))).hexdigest()
        record = {"file": name, "equal": a == b, "frozen_behavior_sha256": a,
                  "current_behavior_sha256": b, "frozen_raw_sha256": fingerprint(old / name),
                  "current_raw_sha256": fingerprint(new / name)}
        report["cases"].append(record)
        if a != b:
            report["errors"].append({"file": name, "error": "Behavioral fields differ"})
    report["cases_compared"] = len(report["cases"])
    report["exact_matches"] = sum(r["equal"] for r in report["cases"])
    report["result"] = "FAIL" if report["errors"] else "PASS"
    report["finished_utc"] = now()
    destination.write_text(json.dumps(report, indent=2) + "\n")
    if report["errors"]:
        raise RuntimeError(f"Frozen C regression failed; retained {destination}")
    return {k: report[k] for k in ("result", "cases_compared", "exact_matches")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    if out.is_relative_to(ROOT):
        parser.error("Evidence must remain outside the source repository")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error("Use a fresh evidence directory")
    source, tree, dirty = git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}"), git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        parser.error("Final qualification requires a clean checkout")
    inputs = source_inputs()
    source_hash = hashlib.sha256(canonical(inputs)).hexdigest()
    identity = source + ("+dirty-" + source_hash[:12] if dirty else "")
    out.mkdir(parents=True, exist_ok=True)
    controls = out / "control-qualification"
    manifest = {
        "programme": "GENTEK-SWARM-002 optional-offer admission",
        "source_commit": source, "source_tree": tree, "execution_identity": identity,
        "frozen_c_commit": FROZEN_C, "branch": git("branch", "--show-current"),
        "clean_source": not bool(dirty), "dirty_status": dirty,
        "source_inputs": inputs, "source_input_fingerprint": source_hash,
        "primary_optional_caps": [1, 2, 4], "hard_only_diagnostic_cap": 0,
        "primary_cases_per_cap": 36,
        "leave_one_out_rule": "Every optional slot in each original full-C MOSAIC failure; no adaptive subset search",
        "budget_rule": "Primary request ceilings unchanged; ranking/selection debits the original shared allowance. Lower-only 2M diagnostics are separate from primary results.",
        "sanitizers_requested": args.sanitize,
        "leak_check": "not claimed; disabled under host instrumentation",
        "commands": [], "started_utc": now(), "result": "RUNNING",
    }
    build = None

    def save():
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    def execute(label, command, timeout):
        argv = list(map(str, command))
        print(f"[{label}] {' '.join(argv)}", flush=True)
        receipt = {"label": label, "argv": argv, "cwd": str(ROOT),
                   "timeout_seconds": timeout, "started_utc": now(), "log": label + ".log"}
        log = out / receipt["log"]
        start = time.monotonic()
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
        env["UBSAN_OPTIONS"] = "halt_on_error=1"
        process = None
        cancelled = waiting = False
        prior_sigterm = signal.getsignal(signal.SIGTERM)

        def cancel_command(_signal, _frame):
            nonlocal cancelled
            cancelled = True
            if waiting:
                raise CommandCancelled()

        signal.signal(signal.SIGTERM, cancel_command)
        try:
            with log.open("w") as stream:
                try:
                    if cancelled:
                        raise CommandCancelled()
                    process = subprocess.Popen(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                               env=env, start_new_session=True)
                    waiting = True
                    if cancelled:
                        raise CommandCancelled()
                    process.wait(timeout=timeout)
                    receipt["outcome"] = "PASS" if process.returncode == 0 else "FAIL"
                except CommandCancelled:
                    waiting = False
                    if process is not None:
                        stop_command_group(process)
                    receipt["outcome"] = "CANCELLED"
                    receipt["cancellation_signal"] = "SIGTERM"
                    receipt["termination_grace_seconds"] = 5
                except subprocess.TimeoutExpired:
                    waiting = False
                    # The control subrunner has its own command groups. TERM
                    # gives it time to stop/reap those groups and retain receipts.
                    stop_command_group(process)
                    receipt["outcome"] = "TIMEOUT"
                    receipt["termination_grace_seconds"] = 5
                finally:
                    waiting = False
                receipt["exit_code"] = process.returncode if process is not None else None
        except Exception as error:
            receipt.update(outcome="ERROR", error=str(error))
        finally:
            if cancelled:
                receipt["outcome"] = "CANCELLED"
                receipt["cancellation_signal"] = "SIGTERM"
            signal.signal(signal.SIGTERM, prior_sigterm)
            receipt.update(elapsed_seconds=round(time.monotonic() - start, 3), finished_utc=now(),
                           log_sha256=fingerprint(log) if log.is_file() else None)
            manifest["commands"].append(receipt)
            save()
        print(f"[{label}] {receipt['outcome']} seconds={receipt['elapsed_seconds']}", flush=True)
        if receipt["outcome"] != "PASS":
            raise RuntimeError(f"{label}: {receipt['outcome']}; see {log}")

    try:
        execute("frozen-c-ancestry", ["git", "merge-base", "--is-ancestor", FROZEN_C, source], 30)
        command = [sys.executable, HERE / "run_negotiated.py", "--out", controls]
        if args.sanitize:
            command.append("--sanitize")
        if args.allow_dirty:
            command.append("--allow-dirty")
        execute("existing-control-qualification", command, 1800)
        previous = json.loads((controls / "manifest.json").read_text())
        if previous["result"] != "PASS" or previous["execution_identity"] != identity:
            raise RuntimeError("Control qualification identity/outcome mismatch")
        manifest["control_qualification"] = {
            "manifest": "control-qualification/manifest.json",
            "sha256": fingerprint(controls / "manifest.json"),
            "result": previous["result"], "swarm001_regression": previous["control_regression"],
        }
        build = Path(previous["fresh_build_directory"])
        manifest["fresh_build_directory"] = str(build)
        execute("admission-build", ["make", "-C", HERE, f"BUILD={build}", "admission"], 600)
        execute("admission-tests", [build / "test_gentek_admission"], 600)
        if args.sanitize:
            execute("admission-sanitizer-build", ["make", "-C", HERE, f"BUILD={build}",
                                                   build / "test_gentek_admission_sanitized"], 600)
            execute("admission-sanitizer-tests", [build / "test_gentek_admission_sanitized"], 600)

        archive, frozen_root = build / "frozen-c-source.tar", build / "frozen-c-source"
        frozen_build, frozen_cases = build / "frozen-c-build", out / "frozen-c"
        execute("frozen-c-archive", ["git", "archive", "--format=tar", "--output", archive,
                                     FROZEN_C, "--", HARNESS, *DONORS], 60)
        manifest["frozen_c_archive_sha256"] = fingerprint(archive)
        unpack_source(archive, frozen_root)
        manifest["frozen_c_inputs"] = source_inputs(frozen_root)
        execute("frozen-c-build", ["make", "-C", frozen_root / HARNESS, f"BUILD={frozen_build}",
                                   frozen_build / "gentek_negotiated"], 300)
        execute("frozen-c-evidence", [frozen_build / "gentek_negotiated", frozen_cases, FROZEN_C], 300)
        print("[frozen-c-regression] comparing all 72 original negotiated cases", flush=True)
        manifest["frozen_c_regression"] = compare_c(frozen_cases, controls, identity,
                                                   out / "frozen-c-regression.json")
        print("[frozen-c-regression] PASS: 72 exact behavioral matches", flush=True)
        execute("admission-evidence", [build / "gentek_admission", out, identity], 600)
        execute("admission-gallery", [sys.executable, HERE / "admission_gallery.py", out], 600)
        manifest["summary"] = json.loads((out / "admission_summary.json").read_text())
        if manifest["summary"]["registered_cap_cases"] != 144 or manifest["summary"]["primary_policy_cases"] != 108:
            raise RuntimeError("Incomplete registered admission corpus")
        if git("rev-parse", "HEAD") != source or git("rev-parse", "HEAD^{tree}") != tree or source_inputs() != inputs:
            raise RuntimeError("Source changed during qualification")
        if source_inputs(frozen_root) != manifest["frozen_c_inputs"]:
            raise RuntimeError("Frozen C source changed during qualification")
        if not dirty and git("status", "--porcelain"):
            raise RuntimeError("Clean source became dirty during qualification")
        manifest["source_custody_revalidated"] = True
        manifest["result"] = "PASS"
    except Exception as error:
        manifest.update(result="FAIL", error=str(error))
        raise
    finally:
        manifest["finished_utc"] = now()
        if build:
            manifest["binaries"] = {name: fingerprint(build / name) for name in
                                    ("gentek_admission", "test_gentek_admission", "test_gentek_admission_sanitized")
                                    if (build / name).is_file()}
            frozen_binary = build / "frozen-c-build" / "gentek_negotiated"
            if frozen_binary.is_file():
                manifest["binaries"]["frozen-c/gentek_negotiated"] = fingerprint(frozen_binary)
        inventory = {p.relative_to(out).as_posix(): fingerprint(p) for p in sorted(out.rglob("*"))
                     if p.is_file() and p not in (out / "manifest.json", out / "sha256sums.txt")}
        (out / "sha256sums.txt").write_text("".join(f"{sha}  {name}\n" for name, sha in inventory.items()))
        manifest["artifact_inventory"] = {"path": "sha256sums.txt", "sha256": fingerprint(out / "sha256sums.txt"),
                                          "files": len(inventory)}
        save()
    print(f"Retained evidence: {out / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
