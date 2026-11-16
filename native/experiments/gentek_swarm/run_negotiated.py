#!/usr/bin/env python3
"""Build and qualify isolated SWARM-002 with freshly rebuilt frozen SWARM-001 controls."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import tarfile
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
HARNESS = Path("native/experiments/gentek_swarm")
PREDECESSOR = "345ecc3ef939523f247b3eb192aa7502bd4d83ca"
DONORS = (
    Path("native/src/generation_spatial.cpp"),
    Path("native/include/cybersand/material.hpp"),
    Path("native/include/cybersand/generation_spatial.hpp"),
    Path("native/include/cybersand/generation_numeric.hpp"),
)
REQUESTS = ("request", "left_request", "right_request")
RESULTS = ("result", "left", "right", "initial_left", "initial_right", "clipped_left", "clipped_right")


def now():
    return datetime.now(timezone.utc).isoformat()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def fingerprint(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *map(str, args)], text=True, timeout=30).strip()


def source_inputs(root=ROOT):
    directory = root / HARNESS
    paths = sorted(path for path in directory.iterdir()
                   if path.is_file() and (path.suffix in (".cpp", ".hpp", ".py") or path.name == "Makefile"))
    paths.extend(root / path for path in DONORS)
    return {str(path.relative_to(root)): fingerprint(path) for path in paths}


def normalized_control(document, expected_source):
    """Normalize only enumerated source-dependent schema-1 identity fields.

    Material digests, arrays, graphs, masks, solver work, statuses and every
    other behavioral field remain exact. A definition's algorithm/version
    prefix also remains exact; only its final compiled-input SHA-256 changes.
    """
    if document.get("schema") != 1 or document.get("type") not in ("single", "pair"):
        raise ValueError("Unexpected legacy control schema/type")
    out = dict(document)
    if "digest" in out:
        out["digest"] = "<source-dependent>"
    for owner in REQUESTS + RESULTS:
        if owner not in document:
            continue
        item = dict(document[owner])
        if item.get("source") != expected_source:
            raise ValueError(f"{owner}: source {item.get('source')!r} != {expected_source!r}")
        item["source"] = "<source-dependent>"
        definition = item.get("definition", "")
        prefix, separator, suffix = definition.rpartition(".")
        if not separator or not re.fullmatch(r"[0-9a-f]{64}", suffix):
            raise ValueError(f"{owner}: missing compiled definition SHA-256")
        item["definition"] = prefix + ".<compiled-input-sha256>"
        if owner in RESULTS:
            for key in ("request_digest", "digest"):
                if key in item:
                    item[key] = "<source-dependent>"
        out[owner] = item
    return out


def first_mismatch(a, b, path="$", depth=0):
    if type(a) is not type(b):
        return path + ": JSON type differs"
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return path + ": keys differ: " + repr(sorted(set(a) ^ set(b)))
        for key in sorted(a):
            if a[key] != b[key]:
                return first_mismatch(a[key], b[key], path + "/" + key, depth + 1)
    elif isinstance(a, list):
        if len(a) != len(b):
            return f"{path}: length {len(a)} != {len(b)}"
        for i, (left, right) in enumerate(zip(a, b)):
            if left != right or type(left) is not type(right):
                return first_mismatch(left, right, f"{path}/{i}", depth + 1)
    elif a != b:
        return f"{path}: {str(a)[:100]!r} != {str(b)[:100]!r}"
    return None


def compare_controls(old, new, identity, output):
    started = time.monotonic()
    names = lambda directory: {path.name for path in directory.glob("*.json")
                               if path.name.startswith(("single_", "pair_", "failure_"))}
    old_names, new_names = names(old), names(new)
    report = {
        "check": "complete frozen SWARM-001 behavioral regression",
        "timestamp_utc": now(), "predecessor": PREDECESSOR, "candidate_identity": identity,
        "normalization": "Only source/request_digest/digest identity fields at schema-1 request/result roots; definition final compiled-input SHA-256 only. All other fields exact.",
        "expected_cases": 171, "cases": [], "errors": [],
    }
    if len(old_names) != 171 or old_names != new_names:
        report["errors"].append({"old_count": len(old_names), "new_count": len(new_names),
                                 "missing": sorted(old_names - new_names), "unexpected": sorted(new_names - old_names)})
    for name in sorted(old_names & new_names):
        record = {"file": name, "predecessor_raw_sha256": fingerprint(old / name),
                  "candidate_raw_sha256": fingerprint(new / name)}
        try:
            before = normalized_control(json.loads((old / name).read_text()), PREDECESSOR)
            after = normalized_control(json.loads((new / name).read_text()), identity)
            record["predecessor_behavior_sha256"] = hashlib.sha256(canonical(before)).hexdigest()
            record["candidate_behavior_sha256"] = hashlib.sha256(canonical(after)).hexdigest()
            record["equal"] = record["predecessor_behavior_sha256"] == record["candidate_behavior_sha256"]
            if not record["equal"]:
                record["first_mismatch"] = first_mismatch(before, after)
                report["errors"].append({"file": name, "first_mismatch": record["first_mismatch"]})
        except (ValueError, KeyError, TypeError) as error:
            record["equal"] = False
            record["error"] = str(error)
            report["errors"].append({"file": name, "error": str(error)})
        report["cases"].append(record)
    report["cases_compared"] = len(report["cases"])
    report["exact_matches"] = sum(case["equal"] for case in report["cases"])
    report["elapsed_seconds"] = round(time.monotonic() - started, 3)
    report["result"] = "FAIL" if report["errors"] else "PASS"
    output.write_text(json.dumps(report, indent=2) + "\n")
    if report["errors"]:
        raise RuntimeError(f"Frozen-control regression failed; see {output}")
    return {key: report[key] for key in ("result", "cases_compared", "exact_matches", "elapsed_seconds")}


def unpack_source(archive, destination):
    """Extract the named Git archive without links or path escape."""
    destination.mkdir()
    with tarfile.open(archive) as source:
        for member in source:
            target = (destination / member.name).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise ValueError("Predecessor archive path escapes its fresh directory")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                stream = source.extractfile(member)
                if stream is None:
                    raise ValueError("Missing predecessor archive member content")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(stream.read())
            else:
                raise ValueError("Predecessor source archive contains a non-file/link entry")


class CommandCancelled(Exception):
    """A supervising runner sent SIGTERM while this command was active."""


def stop_command_group(process, grace_seconds=5):
    """Stop only the launched command group, allowing a nested runner to forward cancellation."""
    if grace_seconds:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=grace_seconds)
        except subprocess.TimeoutExpired:
            pass
    # Also kill surviving same-group children if their leader exited on TERM.
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="Fresh, empty evidence directory outside the repository")
    parser.add_argument("--build", type=Path, default=Path("/tmp/gentek-negotiated-build"),
                        help="Parent for a fresh source-fingerprinted build and predecessor checkout")
    parser.add_argument("--sanitize", action="store_true", help="Run both focused suites under ASan and UBSan; no leak pass claimed")
    parser.add_argument("--quick", action="store_true", help="Six negotiated visual cases; legacy controls remain the full 171 cases")
    parser.add_argument("--allow-dirty", action="store_true", help="Label a development iteration explicitly; never clean-HEAD qualification")
    args = parser.parse_args()
    out, build_parent = args.out.resolve(), args.build.resolve()
    if out.is_relative_to(ROOT) or build_parent.is_relative_to(ROOT):
        parser.error("Generated evidence, extracted sources and binaries must remain outside the repository")
    if build_parent.is_relative_to(out) or out.is_relative_to(build_parent):
        parser.error("Evidence and build directories must be separate trees")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        parser.error("Evidence destination must be empty; retained cases from different runs cannot mix")
    source, tree = git("rev-parse", "HEAD"), git("rev-parse", "HEAD^{tree}")
    dirty = git("status", "--porcelain")
    if dirty and not args.allow_dirty:
        parser.error("Clean-source qualification requires a clean checkout; use --allow-dirty only for development")
    inputs = source_inputs()
    source_digest = hashlib.sha256(canonical(inputs)).hexdigest()
    identity = source + ("+dirty-" + source_digest[:12] if dirty else "")
    out.mkdir(parents=True, exist_ok=True)
    build_parent.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix=source_digest[:16] + "-", dir=build_parent))
    predecessor_root, predecessor_build = build / "predecessor-source", build / "predecessor-build"
    controls, predecessor_controls = out / "controls", out / "predecessor-controls"
    manifest = {
        "programme": "GENTEK-SWARM-002", "started_utc": now(),
        "scope": "isolated native research; Draft/HOLD; no Workbench, production registration, Viaduct or runtime publication",
        "source_commit": source, "source_tree": tree, "execution_identity": identity,
        "predecessor_commit": PREDECESSOR, "clean_source": not bool(dirty),
        "branch": git("branch", "--show-current"), "dirty_status": dirty,
        "source_inputs": inputs, "source_input_fingerprint": source_digest,
        "fresh_build_directory": str(build), "platform": platform.platform(),
        "machine": platform.machine(), "python": sys.version, "quick": args.quick,
        "sanitizers_requested": args.sanitize,
        "leak_sanitizer": "disabled; no leak-check pass claimed (ptrace-host limitation)",
        "expected_negotiated_cases": 6 if args.quick else 72,
        "expected_legacy_control_cases": 171, "commands": [], "result": "RUNNING",
    }

    def save_manifest():
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    def execute(label, command, timeout, cwd=ROOT):
        argv = list(map(str, command))
        print(f"[{label}] {' '.join(argv)}", flush=True)
        log = out / (label + ".log")
        receipt = {"label": label, "argv": argv, "cwd": str(cwd), "timeout_seconds": timeout,
                   "started_utc": now(), "log": log.name}
        started = time.monotonic()
        env = os.environ.copy()
        env["ASAN_OPTIONS"] = "detect_leaks=0:halt_on_error=1"
        env["UBSAN_OPTIONS"] = "halt_on_error=1"
        error = None
        process = None
        cancelled = waiting = False
        prior_sigterm = signal.getsignal(signal.SIGTERM)

        def cancel_command(_signal, _frame):
            nonlocal cancelled
            cancelled = True
            # Do not interrupt Popen before it returns the child's identity.
            # The pending flag is checked immediately after that assignment.
            if process is not None:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if waiting:
                raise CommandCancelled()

        signal.signal(signal.SIGTERM, cancel_command)
        try:
            with log.open("w") as stream:
                try:
                    if cancelled:
                        raise CommandCancelled()
                    process = subprocess.Popen(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                                               env=env, start_new_session=True)
                    waiting = True
                    if cancelled:
                        raise CommandCancelled()
                    receipt["exit_code"] = process.wait(timeout=timeout)
                    receipt["outcome"] = "PASS" if process.returncode == 0 else "FAIL"
                except CommandCancelled:
                    waiting = False
                    if process is not None:
                        # The outer runner is granting this supervisor a short
                        # grace period. Its compiler/test group must stop now.
                        stop_command_group(process, grace_seconds=0)
                    receipt["exit_code"] = process.returncode if process is not None else None
                    receipt["outcome"] = "CANCELLED"
                    receipt["cancellation_signal"] = "SIGTERM"
                    error = f"{label} cancelled by supervising runner"
                except subprocess.TimeoutExpired:
                    waiting = False
                    stop_command_group(process)
                    receipt["exit_code"] = process.returncode
                    receipt["outcome"] = "TIMEOUT"
                    receipt["termination_grace_seconds"] = 5
                    error = f"{label} exceeded its {timeout}s deadline"
                finally:
                    waiting = False
        except Exception as exception:
            receipt["outcome"] = "ERROR"
            receipt["error"] = str(exception)
            error = f"{label}: {exception}"
        finally:
            if cancelled:
                receipt["outcome"] = "CANCELLED"
                receipt["cancellation_signal"] = "SIGTERM"
                error = f"{label} cancelled by supervising runner"
            signal.signal(signal.SIGTERM, prior_sigterm)
            receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
            receipt["finished_utc"] = now()
            receipt["log_sha256"] = fingerprint(log) if log.exists() else None
            manifest["commands"].append(receipt)
            save_manifest()
        print(f"[{label}] {receipt['outcome']} seconds={receipt['elapsed_seconds']}", flush=True)
        if receipt["outcome"] != "PASS":
            raise RuntimeError(error or f"{label} failed; retained log: {log}")
        return receipt

    try:
        manifest["predecessor_tree"] = git("rev-parse", PREDECESSOR + "^{tree}")
        execute("predecessor-ancestry", ["git", "merge-base", "--is-ancestor", PREDECESSOR, source], 30)
        execute("compiler", [os.environ.get("CXX", "g++"), "--version"], 30)
        manifest["compiler"] = (out / "compiler.log").read_text().splitlines()[0]
        manifest["tracked_paths_changed_since_predecessor"] = git("diff", "--name-only", PREDECESSOR, "--").splitlines()
        execute("build", ["make", "-C", HERE, f"BUILD={build}", "all"], 600)
        execute("native-sw001-tests", [build / "test_gentek_swarm"], 180)
        execute("native-negotiated-tests", [build / "test_gentek_negotiated"], 240)
        if args.sanitize:
            execute("sanitizer-build", ["make", "-C", HERE, f"BUILD={build}",
                                        build / "test_gentek_swarm_sanitized", build / "test_gentek_negotiated_sanitized"], 600)
            execute("sanitizer-sw001-tests", [build / "test_gentek_swarm_sanitized"], 300)
            execute("sanitizer-negotiated-tests", [build / "test_gentek_negotiated_sanitized"], 300)
        execute("native-sw001-controls", [build / "gentek_swarm", controls, identity], 240)

        archive = build / "predecessor-source.tar"
        execute("predecessor-archive", ["git", "archive", "--format=tar", "--output", archive,
                                        PREDECESSOR, "--", HARNESS, *DONORS], 60)
        manifest["predecessor_archive_sha256"] = fingerprint(archive)
        unpack_source(archive, predecessor_root)
        manifest["predecessor_source_inputs"] = source_inputs(predecessor_root)
        manifest["predecessor_source_input_fingerprint"] = hashlib.sha256(canonical(manifest["predecessor_source_inputs"])).hexdigest()
        execute("predecessor-build", ["make", "-C", predecessor_root / HARNESS,
                                      f"BUILD={predecessor_build}", predecessor_build / "gentek_swarm"], 300)
        execute("predecessor-controls", [predecessor_build / "gentek_swarm", predecessor_controls, PREDECESSOR], 240)
        print("[control-regression] comparing all 171 frozen cases", flush=True)
        manifest["control_regression"] = compare_controls(predecessor_controls, controls, identity,
                                                          out / "control-regression.json")
        print("[control-regression] PASS: 171 exact behavioral matches", flush=True)

        command = [build / "gentek_negotiated", out, identity]
        if args.quick:
            command.append("quick")
        execute("native-negotiated-evidence", command, 300)
        cases = sorted(out.glob("negotiated_*.json"))
        if len(cases) != manifest["expected_negotiated_cases"]:
            raise RuntimeError(f"Expected {manifest['expected_negotiated_cases']} negotiated raw cases; observed {len(cases)}")
        for path in cases:
            case = json.loads(path.read_text())
            if case.get("predecessor") != PREDECESSOR or case.get("frame_request", {}).get("source") != identity:
                raise RuntimeError(f"Wrong source/predecessor identity in {path.name}")
        manifest["negotiated_raw_cases"] = len(cases)
        execute("control-gallery", [sys.executable, HERE / "gallery.py", controls], 240)
        execute("negotiated-gallery", [sys.executable, HERE / "negotiated_gallery.py", out], 300)
        manifest["negotiated_summary"] = json.loads((out / "negotiated_summary.json").read_text())

        if git("rev-parse", "HEAD") != source or git("rev-parse", "HEAD^{tree}") != tree or source_inputs() != inputs:
            raise RuntimeError("Source changed during execution; retained outputs do not qualify this source")
        if source_inputs(predecessor_root) != manifest["predecessor_source_inputs"]:
            raise RuntimeError("Extracted frozen source changed during control qualification")
        if not dirty and git("status", "--porcelain"):
            raise RuntimeError("Clean checkout became dirty during qualification")
        manifest["source_custody_revalidated"] = True
        manifest["result"] = "PASS"
    except Exception as error:
        manifest["result"] = "FAIL"
        manifest["error"] = str(error)
        raise
    finally:
        manifest["finished_utc"] = now()
        binary_names = ("gentek_swarm", "test_gentek_swarm", "gentek_negotiated", "test_gentek_negotiated",
                        "test_gentek_swarm_sanitized", "test_gentek_negotiated_sanitized")
        manifest["binaries"] = {name: fingerprint(build / name) for name in binary_names if (build / name).is_file()}
        if (predecessor_build / "gentek_swarm").is_file():
            manifest["binaries"]["predecessor/gentek_swarm"] = fingerprint(predecessor_build / "gentek_swarm")
        inventory = {str(path.relative_to(out)): fingerprint(path) for path in sorted(out.rglob("*"))
                     if path.is_file() and path.name not in ("manifest.json", "sha256sums.txt")}
        (out / "sha256sums.txt").write_text("".join(f"{sha}  {name}\n" for name, sha in inventory.items()))
        manifest["artifact_inventory"] = {"path": "sha256sums.txt", "sha256": fingerprint(out / "sha256sums.txt"), "files": len(inventory)}
        save_manifest()
    print(f"Retained evidence: {out / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
