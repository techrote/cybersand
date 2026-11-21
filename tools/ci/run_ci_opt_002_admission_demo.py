#!/usr/bin/env python3
"""Proof-only experiment: time real canonical rejection, not application success.

Both arms run on the same immutable proof checkout. Only the ordering of exact
run blocks extracted from the two recorded Documentation workflows differs.
No sleeps, generated durations, skipped native suites or publication occur.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
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
import time

import yaml

BASELINE = "0f0161af337d6d0cee8fa961a9667aff570a75b0"
CANDIDATE = "68e0261466fc275a095360c63ed6f67311ecc0f6"
BRANCH = "ci/ci-opt-002-admission-proof-20261121"
WORKFLOW = ".github/workflows/documentation.yml"
START = "Retain machine-readable workflow inventory"
STOP = "Validate dependency pins and published runtime provenance"
CONDITION = "github.event_name != 'pull_request' || github.event.pull_request.draft == false"
STALE_INPUT = "godot/native_extension/cyber_world_generator.cpp"
RUNTIME = "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
DOC = "docs/operations/github-development-and-release.md"
STALE_BYTES = b"\n// CI-OPT-002 paired stale-source rejection proof.\n"
CHECK = 'timeout "$(python3 tools/ci/execution_policy.py seconds operation_seconds)" python3 tools/ci/check_repository.py --require-materialized'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True, timeout=60).strip()


def workflow_plan(root: Path) -> dict:
    raw = {key: git(root, "show", revision + ":" + WORKFLOW)
           for key, revision in (("before", BASELINE), ("after", CANDIDATE))}
    parsed = {key: yaml.safe_load(value) for key, value in raw.items()}
    inventories = {key: value["jobs"]["consistency"].pop("steps") for key, value in parsed.items()}
    if parsed["before"] != parsed["after"]:
        raise ValueError("Workflow or job metadata changed; ordering-only experiment refused")
    by_name = {key: {step["name"]: step for step in steps} for key, steps in inventories.items()}
    if any(len(steps) != 22 or len(by_name[key]) != 22 for key, steps in inventories.items()):
        raise ValueError("Unexpected or duplicate Documentation step inventory")
    if by_name["before"] != by_name["after"]:
        raise ValueError("Commands, conditions or other step definitions differ")
    if by_name["before"][STOP].get("if") != CONDITION or by_name["before"][STOP]["run"] != CHECK:
        raise ValueError("Canonical provenance command or Draft condition changed")
    moved = {"Validate current documentation", STOP}
    unchanged = [[step["name"] for step in inventories[key] if step["name"] not in moved]
                 for key in ("before", "after")]
    if unchanged[0] != unchanged[1]:
        raise ValueError("An unrelated step was reordered")
    selected = {}
    for arm, steps in inventories.items():
        names = [step["name"] for step in steps]
        selected[arm] = steps[names.index(START) + 1:names.index(STOP) + 1]
        for step in selected[arm]:
            if "run" not in step or step.get("if", CONDITION) != CONDITION:
                raise ValueError("Unexpected action or conditional in measured interval")
    if [len(selected[arm]) for arm in ("before", "after")] != [7, 2]:
        raise ValueError("Unexpected before/after measured step counts")
    return {"workflow_text": raw, "selected": selected, "unchanged_step_count": 22,
            "step_inventory_sha256": sha(json.dumps(by_name["before"], sort_keys=True).encode())}


class Proof:
    def __init__(self, args):
        self.args = args
        self.root = args.root.resolve()
        self.out = args.output.resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.deadline = time.monotonic() + args.max_seconds
        self.child = None
        self.report = {"schema": "ci-opt-002-admission-proof-v1", "arm": args.arm,
                       "status": "incomplete", "application_qualification": "not-claimed",
                       "measurement_scope": "post-inventory command interval to actual stale-source refusal; excludes checkout, LFS, preparation and controls",
                       "started_utc": utc(), "baseline_commit": BASELINE, "candidate_commit": CANDIDATE,
                       "run_id": os.environ.get("GITHUB_RUN_ID"), "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
                       "source_sha": args.expect_sha, "ref": os.environ.get("GITHUB_REF"),
                       "python": sys.version, "platform": platform.platform(),
                       "runner_os": os.environ.get("RUNNER_OS"), "runner_arch": os.environ.get("RUNNER_ARCH"),
                       "steps": [], "negative_controls": []}
        self.save()

    def save(self):
        temporary = self.out / "report.tmp"
        temporary.write_text(json.dumps(self.report, indent=2, sort_keys=True) + "\n")
        temporary.replace(self.out / "report.json")

    def stop_child(self):
        if self.child is not None and self.child.poll() is None:
            os.killpg(self.child.pid, signal.SIGTERM)
            try:
                self.child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(self.child.pid, signal.SIGKILL)
                self.child.wait(timeout=10)

    def run(self, name: str, command: str, phase: str, condition: str | None = None) -> dict:
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Proof budget exhausted; no qualifying comparison is claimed")
        filename = f"{len(self.report['steps']):02d}-{re.sub('[^a-z0-9]+', '-', name.lower()).strip('-')}.log"
        row = {"name": name, "command": command, "phase": phase, "original_if": condition,
               "condition_evaluated": True, "started_utc": utc(), "start_monotonic_ns": time.monotonic_ns(),
               "complete": False, "log": filename}
        self.report["steps"].append(row)
        self.save()
        print(f"BEGIN {phase}: {name}", flush=True)
        try:
            with (self.out / filename).open("wb") as log:
                self.child = subprocess.Popen(["bash", "--noprofile", "--norc", "-e", "-o", "pipefail", "-c", command],
                                              cwd=self.root, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                row["exit_code"] = self.child.wait(timeout=remaining)
                row["complete"] = True
        finally:
            self.stop_child()
            self.child = None
            row["end_monotonic_ns"] = time.monotonic_ns()
            row["elapsed_seconds"] = (row["end_monotonic_ns"] - row["start_monotonic_ns"]) / 1e9
            row["finished_utc"] = utc()
            row["log_sha256"] = sha((self.out / filename).read_bytes())
            self.save()
        print(f"END {phase}: {name}: exit={row['exit_code']} seconds={row['elapsed_seconds']:.6f}", flush=True)
        return row

    def canonical_result(self, row: dict) -> dict:
        return json.loads((self.out / row["log"]).read_text())

    def require_positive(self, name: str):
        row = self.run(name, CHECK, "positive-control")
        result = self.canonical_result(row)
        if row["exit_code"] != 0 or result.get("status") != "passed":
            raise ValueError("Unmutated source failed the original canonical materialized-runtime checker")
        return row

    @contextmanager
    def mutate(self, relative: str, suffix: bytes | None):
        path = self.root / relative
        original = path.read_bytes()
        mode = path.stat().st_mode
        original_hash = sha(original)
        mutation = {"path": relative, "original_sha256": original_hash,
                    "mutation": "remove" if suffix is None else "append exact bytes",
                    "appended_hex": suffix.hex() if suffix is not None else None}
        try:
            if suffix is None:
                path.unlink()
            else:
                path.write_bytes(original + suffix)
            mutation["mutated_sha256"] = sha(path.read_bytes()) if path.exists() else None
            yield mutation
        finally:
            path.write_bytes(original)
            path.chmod(mode)
            if sha(path.read_bytes()) != original_hash:
                raise ValueError("Exact original bytes were not restored: " + relative)
            mutation["restored_sha256"] = original_hash
            self.save()

    def execute(self):
        if not re.fullmatch(r"[0-9a-f]{40}", self.args.expect_sha):
            raise ValueError("Malformed requested source identity")
        if git(self.root, "rev-parse", "HEAD") != self.args.expect_sha:
            raise ValueError("Checkout does not match the immutable requested source")
        if os.environ.get("GITHUB_EVENT_NAME") != "push" or os.environ.get("GITHUB_REF") != "refs/heads/" + BRANCH:
            raise ValueError("This proof is admitted only on its dedicated push branch")
        if not all(re.fullmatch(r"[1-9][0-9]*", os.environ.get(key, "")) for key in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")):
            raise ValueError("Missing run or attempt identity")
        for ancestor, descendant in ((BASELINE, CANDIDATE), (CANDIDATE, self.args.expect_sha)):
            git(self.root, "merge-base", "--is-ancestor", ancestor, descendant)
        if git(self.root, "status", "--porcelain", "--untracked-files=no"):
            raise ValueError("Initial tracked source is dirty")
        plan = workflow_plan(self.root)
        self.report.update({"source_tree": git(self.root, "rev-parse", "HEAD^{tree}"),
                            "unchanged_step_count": plan["unchanged_step_count"],
                            "step_inventory_sha256": plan["step_inventory_sha256"],
                            "selected_step_names": [step["name"] for step in plan["selected"][self.args.arm]],
                            "harness_sha256": sha(Path(__file__).read_bytes())})
        for arm, text in plan["workflow_text"].items():
            (self.out / (arm + "-documentation.yml")).write_text(text + "\n")
        inputs = {}
        for name in ("runtime-provenance.json", "runtime-provenance.linux.json"):
            manifest_path = self.root / "godot/addons/cybersand_native" / name
            manifest = json.loads(manifest_path.read_text())
            if STALE_INPUT not in manifest["source_inputs"]:
                raise ValueError("Chosen stale input is absent from a platform's manifest")
            inputs[name] = {"manifest_sha256": sha(manifest_path.read_bytes()),
                            "source_inputs": manifest["source_inputs"],
                            "artifact": manifest["artifact"],
                            "materialized_artifact_sha256": sha((self.root / manifest["artifact"]).read_bytes())}
        (self.out / "original-source-and-runtime-inputs.json").write_text(json.dumps(inputs, indent=2, sort_keys=True) + "\n")
        self.require_positive("Original canonical materialized-runtime admission")
        controls = [
            ("stale manifested source", STALE_INPUT, STALE_BYTES, "requires rebuild for source input: " + STALE_INPUT),
            ("missing runtime", RUNTIME, None, "current provenance check failed:"),
            ("corrupt runtime bytes", RUNTIME, b"CI-OPT-002-corruption-control\x00", "bytes differ from published provenance"),
            ("invalid documentation link", DOC, b"\n[CI-OPT-002 adverse link](ci-opt-002-deliberately-missing.md)\n", "ci-opt-002-deliberately-missing.md"),
        ]
        for name, relative, suffix, expected in controls:
            with self.mutate(relative, suffix) as mutation:
                row = self.run(name, CHECK, "negative-control")
                result = self.canonical_result(row)
                if row["exit_code"] == 0 or result.get("status") != "failed" or not any(expected in error for error in result.get("errors", [])):
                    raise ValueError("Canonical negative control did not produce its specific expected refusal: " + name)
                self.report["negative_controls"].append({"name": name, "mutation": mutation,
                                                         "exit_code": row["exit_code"], "expected_error": expected,
                                                         "observed_errors": result["errors"]})
        self.require_positive("Canonical admission after restoring every adverse control")
        with self.mutate(STALE_INPUT, STALE_BYTES) as mutation:
            self.report["timed_mutation"] = mutation
            self.report["timed_start_monotonic_ns"] = time.monotonic_ns()
            for step in plan["selected"][self.args.arm]:
                row = self.run(step["name"], step["run"], "timed-original-step", step.get("if"))
                if step["name"] == STOP:
                    result = self.canonical_result(row)
                    expected = "requires rebuild for source input: " + STALE_INPUT
                    if row["exit_code"] == 0 or result.get("status") != "failed" or not any(expected in error for error in result.get("errors", [])):
                        raise ValueError("Original provenance command did not genuinely reject the stale source")
                    self.report["under_test_exit_code"] = row["exit_code"]
                    self.report["under_test_qualification"] = "failed-as-expected-stale-source"
                    self.report["timed_end_monotonic_ns"] = row["end_monotonic_ns"]
                    self.report["seconds_to_expected_refusal"] = (row["end_monotonic_ns"] - self.report["timed_start_monotonic_ns"]) / 1e9
                elif row["exit_code"] != 0:
                    raise ValueError("A genuine predecessor failed; no comparable timing result: " + step["name"])
        if git(self.root, "status", "--porcelain", "--untracked-files=no"):
            raise ValueError("Proof did not restore a clean tracked checkout")
        self.require_positive("Final restored source remains canonically admissible")
        self.report["status"] = "expected-refusal-proved"
        self.report["finished_utc"] = utc()
        self.report["limitations"] = [
            "This is a measured negative-admission comparison, not successful CI or application qualification.",
            "Two separate hosted workers may differ in CPU and queue time; job metadata must supply full setup, queue and runner-minute accounting.",
            "Positive/control reads precede both timing arms; no compiler cache is restored by this workflow.",
            "The expensive before arm executes original preceding commands; the after arm reaches the same genuine refusal earlier.",
        ]
        self.report["artifact_files_sha256"] = {str(path.relative_to(self.out)): sha(path.read_bytes())
                                                 for path in sorted(self.out.rglob("*"))
                                                 if path.is_file() and path.name not in ("report.json", "report.tmp")}
        self.save()
        print(json.dumps({key: self.report[key] for key in ("status", "under_test_qualification", "under_test_exit_code", "seconds_to_expected_refusal")}), flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--arm", choices=("before", "after"), required=True)
    parser.add_argument("--expect-sha", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-seconds", type=int, default=13200)
    parser.add_argument("--validate-plan-only", action="store_true")
    args = parser.parse_args()
    if args.validate_plan_only:
        plan = workflow_plan(args.root.resolve())
        print(json.dumps({"unchanged_step_count": plan["unchanged_step_count"], "step_inventory_sha256": plan["step_inventory_sha256"],
                          "selected": {arm: [step["name"] for step in steps] for arm, steps in plan["selected"].items()}}, indent=2))
        return 0
    if not 300 <= args.max_seconds <= 13200:
        raise ValueError("Proof budget must be bounded between 300 and 13200 seconds")
    proof = Proof(args)
    def interrupted(signum, _frame):
        raise InterruptedError(f"Proof interrupted by signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        proof.execute()
        return 0
    except (Exception, KeyboardInterrupt) as error:
        proof.report["status"] = "failed-or-incomplete-proof"
        proof.report["error"] = str(error)
        proof.report["finished_utc"] = utc()
        proof.stop_child()
        proof.save()
        print("PROOF FAILED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
