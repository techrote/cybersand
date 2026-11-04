#!/usr/bin/env python3
"""Read-only verification of the published PR383 successor evidence packet.

Requires Python 3.11+ and a Git checkout containing authenticated publication
implementation f2f673e4. Measured e11b452f need not be a reachable Git object: its
archived raw commit bytes are verified before the identical published tree is
used for source lookup. Execution remains attributed to e11b452f, never relabeled
to the metadata-recreated implementation or its publication descendant.
Example, from the checkout: python3 docs/audits/in-tools-383-successor-2026-11-04/check-published.py --repo .
The default packet directory is beside this script. No compiler, engine, tests,
repository Python modules, remote services or original absolute paths are used.
Raw logs/executables are not part of the published packet: their recorded
identities and the immutable independent raw-artifact review are cross-checked,
but this checker cannot itself reauthenticate absent raw bytes or rerun tests.
Optional --raw-task-root authenticates original copy bytes and whitespace-only
packet transformations; full raw-log checking remains check-raw-cohort.py.
"""
from __future__ import annotations

import argparse
import base64
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

SOURCE = "e11b452f1e90a8a014ab4d721b7c65724a508597"
TREE = "22a35293c7373ea4583b78121778b00ecdf6eeee"
BASE_SOURCE = "73b10f9b800e72f358f22f470e57a4531002c168"
AUTHENTICATED_IMPLEMENTATION = "f2f673e4a961207347dd8708dce7d6b63788a432"
UNPUBLISHED_ADDENDUM = "7b35d05bc846328fd66f710f797de4db99ebd582"
UNPUBLISHED_TREE = "5b4913da6e7e107e059b8e0d0182f4af34859a18"
UNPUBLISHED_READBACK_SHA256 = "2c0985bf593d3cf324d6430d3db9c2f8de37e97162aa8d78ec2ef4206d61272a"
REVIEWED_DIFF = "7efaf09d3af616090fc63820905bfc2e279b51e5b7d1d9c78e610303e2ac1b9e"
ACCOUNTING = "material-work-units-v1"
PROVENANCE = "host-local-native-observation-v1"
CASES = [
    "test_physical_metered_desktop", "test_physical_metered_drain",
    "test_physical_metered_equipment", "test_physical_usables_runtime",
    "test_physical_usables_admission", "test_physical_usables_desktop",
    "test_usables", "test_physical_usable_equipment",
    "test_physical_usable_lifecycle", "test_physical_actor_session",
    "test_actor_rig_session", "test_tick_failure_regression",
    "test_liquid_solver_policy", "test_liquid_physical_preparation",
    "test_liquid_water_reference_body",
]
PROFILES = ["water-in-3", "water-in-8", "water-fm-3", "water-fm-8",
            "brine-cy-8", "brine-in-8", "water-cy-3", "water-cy-8"]
CHANGED_PATHS = [
    "docs/operations/in-tools-metered-drain.md",
    "docs/reference/configuration-reference.md",
    "docs/reference/interfaces-and-message-contracts.md",
    "godot/scripts/metered_liquid_drain.gd",
    "godot/scripts/physical_usable_runtime.gd",
    "godot/tests/test_physical_metered_drain.gd",
    "native/tests/test_metered_liquid_drain.cpp",
    "tools/lcb/run_metered_drain_native.py",
    "tools/lcb/test_metered_drain_native.py",
]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def exact_int(value: object, label: str, low: int = 0, high: int = (1 << 64) - 1) -> int:
    require(type(value) is int and low <= value <= high, label + ": invalid integer")
    return value


def parse_json(raw: str) -> object:
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "duplicate JSON key: " + key)
            result[key] = value
        return result

    def invalid(value):
        raise ValueError("nonfinite JSON constant: " + value)

    return json.loads(raw, object_pairs_hook=pairs, parse_constant=invalid)


INDEPENDENT_REVIEW_SHA256 = "7a4f546d6d42cd9ce089d8c4886c2ac614acc6edf1bef2f516257a5460dd51c7"
AUDIT_DIR = "docs/audits/in-tools-383-successor-2026-11-04"
ALLOWED_ADDENDUM = {
    "docs/audits/2026-11-04-in-tools-383-successor-correction.md",
    "docs/operations/in-tools-metered-drain.md",
    "docs/operations/cybersand-codex-development-handover.md",
}
LFS_POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")


def without_json_whitespace(raw: bytes) -> bytes:
    """Remove only ASCII JSON whitespace outside strings; preserve all tokens."""
    quoted = escaped = False
    result = bytearray()
    for char in raw:
        if quoted:
            result.append(char)
            if escaped:
                escaped = False
            elif char == 92:
                escaped = True
            elif char == 34:
                quoted = False
        elif char == 34:
            quoted = True
            result.append(char)
        elif char not in b" \t\r\n":
            result.append(char)
    require(not quoted and not escaped, "unterminated JSON string")
    return bytes(result)


def verify_commit_bytes(raw: bytes, expected: str, tree: str, parent: str, label: str) -> str:
    """Authenticate a Git commit object, not merely a JSON metadata claim."""
    object_bytes = b"commit " + str(len(raw)).encode("ascii") + b"\0" + raw
    require(hashlib.sha1(object_bytes).hexdigest() == expected, label + ": Git commit SHA-1 differs")
    header, separator, _message = raw.partition(b"\n\n")
    require(separator == b"\n\n", label + ": malformed commit headers")
    lines = header.split(b"\n")
    require([line for line in lines if line.startswith(b"tree ")] == [b"tree " + tree.encode("ascii")],
            label + ": tree header differs")
    require([line for line in lines if line.startswith(b"parent ")] == [b"parent " + parent.encode("ascii")],
            label + ": sole parent differs")
    return sha_bytes(raw)


def authenticate_transport(transport: dict, git) -> dict:
    for key, expected, tree, parent in [
        ("measured_source", SOURCE, TREE, BASE_SOURCE),
        ("unpublished_local_addendum", UNPUBLISHED_ADDENDUM, UNPUBLISHED_TREE, SOURCE),
    ]:
        row = transport[key]
        require((row["commit"], row["tree"], row["parent"]) == (expected, tree, parent),
                "transport archived identity differs: " + key)
        require(type(row["raw_commit_base64"]) is str, "archived commit bytes must be base64 text")
        raw = base64.b64decode(row["raw_commit_base64"], validate=True)
        require(verify_commit_bytes(raw, expected, tree, parent, key) == row["raw_commit_sha256"],
                "archived commit SHA-256 differs: " + key)
    prior = transport["unpublished_local_addendum"]["final_head_readback"]
    require(type(prior) is dict, "prior local readback must be an exact parsed JSON object")
    reconstructed = (json.dumps(prior, indent=2, sort_keys=True) + "\n").encode()
    require(sha_bytes(reconstructed) == UNPUBLISHED_READBACK_SHA256,
            "prior unpublished local head readback changed")
    require((prior["final_commit"], prior["final_tree"], prior["sole_parent_measured_commit"])
            == (UNPUBLISHED_ADDENDUM, UNPUBLISHED_TREE, SOURCE), "prior local head identity differs")
    implementation = transport["authenticated_implementation"]
    require((implementation["commit"], implementation["tree"], implementation["parent"])
            == (AUTHENTICATED_IMPLEMENTATION, TREE, BASE_SOURCE), "authenticated publication implementation differs")
    require(git("cat-file", "-t", AUTHENTICATED_IMPLEMENTATION).strip() == b"commit",
            "authenticated implementation is not a commit object")
    published_raw = git("cat-file", "commit", AUTHENTICATED_IMPLEMENTATION)
    published_raw_sha256 = verify_commit_bytes(published_raw, AUTHENTICATED_IMPLEMENTATION, TREE, BASE_SOURCE,
                                               "authenticated implementation")
    require(git("rev-parse", AUTHENTICATED_IMPLEMENTATION + "^{tree}").decode().strip() == TREE,
            "authenticated source tree differs from actually measured tree")
    publication = transport["publication"]
    require(publication["mode"] == "authenticated GitHub Git Data API; expected-head nonforce branch update"
            and publication["execution_reassigned"] is False
            and publication["expected_remote_head"] == BASE_SOURCE and publication["force"] is False,
            "publication contract would reassign execution or weaken the branch guard")
    return {
        "measured_execution_commit": SOURCE, "measured_source_tree": TREE,
        "measured_raw_commit_sha256": transport["measured_source"]["raw_commit_sha256"],
        "unpublished_local_addendum": UNPUBLISHED_ADDENDUM,
        "unpublished_local_tree": UNPUBLISHED_TREE,
        "unpublished_raw_commit_sha256": transport["unpublished_local_addendum"]["raw_commit_sha256"],
        "unpublished_readback_sha256": UNPUBLISHED_READBACK_SHA256,
        "source_lookup_commit": AUTHENTICATED_IMPLEMENTATION,
        "source_lookup_raw_commit_sha256": published_raw_sha256,
        "source_lookup_tree": TREE, "source_lookup_sole_parent": BASE_SOURCE,
        "execution_reassigned": False,
        "scope": "Archived actual execution commit authenticated; published implementation has identical complete Git tree and original parent. Metadata-recreated publication is source-equivalent only, not a new execution cohort.",
    }


def review_published(repo: Path, packet: Path, candidate: str, raw_task: Path | None) -> dict:
    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", *args], cwd=repo, timeout=60)

    source_lookup = None

    def blob(path: str, ref: str | None = None) -> bytes:
        require(source_lookup is not None, "source lookup attempted before transport authentication")
        if ref is None:
            ref = source_lookup
        require(not PurePosixPath(path).is_absolute() and ".." not in PurePosixPath(path).parts,
                "source input is not repository-relative: " + path)
        return git("show", (":" if ref == "INDEX" else ref + ":") + path)

    def read(name: str):
        return parse_json((packet / name).read_text())

    def allowed(path: str) -> bool:
        return path in ALLOWED_ADDENDUM or path.startswith(AUDIT_DIR + "/")

    transport_identity = authenticate_transport(read("transport-identity.json"), git)
    source_lookup = transport_identity["source_lookup_commit"]
    require(sha_bytes(git("diff", "--binary", BASE_SOURCE, source_lookup)) == REVIEWED_DIFF,
            "authenticated source correction differs from measured reviewed delta")
    require(git("diff", "--name-only", BASE_SOURCE, source_lookup).decode().splitlines() == CHANGED_PATHS,
            "authenticated source path inventory differs")
    if candidate == "INDEX":
        candidate_tree = None
        candidate_changes = git("diff", "--cached", "--name-only", source_lookup).decode().splitlines()
    else:
        require(subprocess.run(["git", "merge-base", "--is-ancestor", source_lookup, candidate], cwd=repo,
                               timeout=60, capture_output=True).returncode == 0,
                "candidate is not an authenticated implementation descendant")
        lineage = git("rev-list", "--parents", source_lookup + ".." + candidate).decode().splitlines()
        require(all(len(row.split()) == 2 for row in lineage), "publication candidate introduces a merge")
        candidate_tree = git("rev-parse", candidate + "^{tree}").decode().strip()
        candidate_changes = git("diff", "--name-only", source_lookup, candidate).decode().splitlines()
    worktree_changes = git("diff", "--name-only", source_lookup).decode().splitlines()
    require(all(allowed(path) for path in candidate_changes + worktree_changes),
            "candidate or tracked worktree changes measured production/test/fixture/runner/runtime inputs")

    index = read("evidence-index.json")
    require((index["measured_source_commit"], index["measured_source_tree"]) == (SOURCE, TREE), "index source differs")
    members = index["records"]
    require(type(members) is dict and "evidence-index.json" not in members, "invalid self-referential member index")
    for name, row in members.items():
        require(not PurePosixPath(name).is_absolute(), "absolute indexed path")
        path = (packet / name).resolve()
        require(path.is_relative_to(repo) and path != (packet / "evidence-index.json").resolve(), "indexed path escapes repository or refers to index")
        require(path.is_file() and digest(path) == row["sha256"]
                and path.stat().st_size == exact_int(row["bytes"], "indexed size"), "indexed bytes differ: " + name)
    present = {str(p.relative_to(packet)) for p in packet.rglob("*") if p.is_file() and p.name != "evidence-index.json"}
    require(present == {name for name in members if not name.startswith("../")}, "packet files are missing from or added outside index")
    require(digest(packet / "independent-review.json") == INDEPENDENT_REVIEW_SHA256, "original independent raw-artifact review changed")
    independent = read("independent-review.json")
    require(independent["source_commit"] == SOURCE and independent["source_tree"] == TREE
            and independent["status"] == "PASS_WITH_EXPLICIT_SCOPE", "independent measured review differs")
    require(independent["a02"]["aggregate_all_native_call_cap_claimed"] is False, "A02 contract expanded")
    custody = read("custody.json")
    raw_verified = []
    for name, row in custody["published_copies"].items():
        path = packet / name
        compacted = "original_sha256" in row
        expected = row["published_sha256"] if compacted else row["sha256"]
        expected_size = row["published_bytes"] if compacted else row["bytes"]
        require(digest(path) == expected and path.stat().st_size == expected_size, "copy identity differs: " + name)
        original_hash = row["original_sha256"] if compacted else expected
        if name == "independent-review.json":
            require(original_hash == INDEPENDENT_REVIEW_SHA256, "independent review copy changed")
        elif name == "check-raw-cohort.py":
            require(original_hash == independent["checker_sha256"], "original raw checker changed")
        else:
            require(independent["artifacts"][row["original"]]["sha256"] == original_hash,
                    "copy is not from the independently reviewed raw cohort: " + name)
        if raw_task is not None:
            original = (raw_task / row["original"]).resolve()
            require(original.is_relative_to(raw_task) and digest(original) == original_hash, "original artifact identity differs: " + name)
            if compacted:
                raw = original.read_bytes()
                parse_json(raw.decode())
                require(original.stat().st_size == row["original_bytes"], "original packet size differs")
                require(path.read_bytes() == without_json_whitespace(raw) + b"\n", "packet transformation changed tokens: " + name)
            else:
                require(original.read_bytes() == path.read_bytes(), "exact-copy bytes differ: " + name)
            raw_verified.append(name)

    input_cache = {}
    materialized, unavailable_payloads = set(), set()

    def source_input(path: str, expected: str) -> None:
        if path in input_cache:
            require(input_cache[path] == expected, "conflicting source inventory for " + path)
            return
        raw = blob(path)
        require(blob(path, candidate) == raw, "candidate measured input differs: " + path)
        local = repo / path
        pointer = LFS_POINTER.fullmatch(raw)
        if pointer:
            require(pointer[1].decode() == expected, "source LFS object differs: " + path)
            if local.is_file() and local.read_bytes() != raw:
                require(digest(local) == expected and local.stat().st_size == int(pointer[2]), "materialized LFS bytes differ: " + path)
                materialized.add(path)
            else:
                unavailable_payloads.add(path)
        else:
            require(sha_bytes(raw) == expected, "measured source hash differs: " + path)
            require(local.is_file() and digest(local) == expected, "working source input differs: " + path)
        input_cache[path] = expected

    n = read("native-qualification.json")
    require(n["status"] == "pass" and n["compile_exit"] == n["run_exit"] == 0
            and n["inputs_unchanged"] is True and n["executable_unchanged"] is True
            and n["native_status"] == "", "native completion/custody record did not pass")
    require((n["git_commit"], n["git_tree"]) == (SOURCE, TREE), "native source identity differs")
    require(n["input_sha256"] == n["input_sha256_after"], "native before/after inputs differ")
    for name, expected in n["input_sha256"].items():
        source_input(name, expected)
    source_input("tools/lcb/run_metered_drain_native.py", n["runner_sha256"])
    native_packet = n["results"]
    require(native_packet["status"] == "pass" and native_packet["scope"] == "native-core-only"
            and native_packet["production_application_executed"] is False, "native scope differs")
    native_rows = native_packet["cases"]
    require(len(native_rows) == 30 and len({r["case_id"] for r in native_rows}) == 30, "native case census differs")
    worker_rows = [r for r in native_rows if r["case_id"].startswith("workers.")]
    require({r["case_id"] for r in worker_rows} == {"workers." + p for p in PROFILES}, "registered native claimant arms differ")
    for row in worker_rows:
        require(exact_int(row["workers1_observed"], "one claimant") == 1
                and exact_int(row["workers4_observed"], "four claimants") == 4, "A01 exact typed claimant predicate failed")
        require(row["ticks_per_arm"] == 64 and row["physical_hash_parity"] is True
                and row["inertial_ledger_parity"] is True and exact_int(row["phase_jobs_workers4"], "phase jobs", 1) > 0,
                "native phase/parity proof differs")
        require(row["initial_quantity"] - row["removed_quantity"] == row["remaining_quantity"], "native quantity residual")
    require(native_packet["assertions"] == independent["a01"]["repeated_assertions"], "native census assertion total differs")
    parser_wrapper = read("parser-controls.json")
    pc = parser_wrapper["final"]
    require((pc["source_commit"], pc["source_tree"]) == (SOURCE, TREE)
            and pc["returncode"] == 0 and pc["inputs_unchanged"] is True, "final parser controls failed or source differs")
    for name, expected in pc["source_sha256"].items():
        source_input(name, expected)
    for name, expected in pc["logs"].items():
        require(independent["artifacts"]["parser-e11b452f-01/" + name]["sha256"] == expected, "parser recorded raw-log identity differs")
    require(parser_wrapper["final_summary"]["tests"] == independent["a01"]["parser_tests"]
            and parser_wrapper["final_summary"]["status"] == "PASS", "parser test census differs")
    negative = parser_wrapper["historical_negative_control"]
    require(negative["head"] == BASE_SOURCE and negative["exit_code"] == 1
            and negative["source_sha256"] == negative["source_sha256_after"], "historical expected-failure control changed")
    require(parser_wrapper["negative_control_summary"]["failed_subtests"] == 16, "historical negative-control census differs")
    if raw_task is not None:
        require(pc == parse_json((raw_task / "parser-e11b452f-01/record.json").read_text()), "wrapped final parser record differs from original")

    before, after, processes = (read(name) for name in ["host-source-identity.json", "host-after.json", "host-qualification.json"])
    for record in (before, after, processes):
        require((record["source_commit"], record["source_tree"]) == (SOURCE, TREE), "host source identity differs")
    require(before["initial_git_status"] == "" and after["source_drift"] == after["runtime_drift"] == [], "host source/runtime drift")
    require(len(before["source_inputs"]) == before["source_inputs_count"] == after["source_inputs_count"], "host input census differs")
    for name, expected in before["source_inputs"].items():
        source_input(name, expected)
    require(before["godot_sha256"] == after["godot_sha256"] == independent["host"]["godot_sha256"], "Godot identity differs")
    require(digest(packet / "run-host-successor.py") == before["harness_sha256"], "execution harness differs")
    source_input("tools/ci/run_godot_regressions.py", before["runner_sha256"])
    require(before["selected_cases"] == CASES, "host planned cases differ")
    runtime_summary = []
    for name, row in before["runtime_provenance"].items():
        source_input(name, row["manifest_sha256"])
        manifest = parse_json(blob(name).decode())
        source_input(row["artifact"], row["expected_sha256"])
        require(row["actual_file_sha256"] == row["expected_sha256"] and row["materialized"] is True,
                "execution runtime was not recorded as materialized")
        for name, expected in manifest["source_inputs"].items():
            source_input(name, expected)
        if "cybersand_native" in row["artifact"]:
            require(len(manifest["source_inputs"]) == before["native_input_count"] == 80, "native runtime input census differs")
        runtime_summary.append({"artifact": row["artifact"], "sha256": row["expected_sha256"],
                                "execution_claim": row["execution_claim"]})
    payloads = custody["runtime_materialization"]
    require(len(payloads) == 18, "runtime materialization census differs")
    for row in payloads:
        source_input(row["path"], row["sha256"])
        pointer = LFS_POINTER.fullmatch(blob(row["path"]))
        require(pointer is not None and int(pointer[2]) == row["size"], "runtime materialized size differs from Git LFS pointer")
    for name, expected in independent["protected_production_trees_unchanged"].items():
        require(git("rev-parse", source_lookup + ":" + name).decode().strip() == expected, "protected measured tree differs")
        if candidate != "INDEX":
            require(git("rev-parse", candidate + ":" + name).decode().strip() == expected, "protected candidate tree differs")

    require(processes["status"] == "passed" and processes["source_inputs_unchanged"] is True
            and processes["runtime_bytes_unchanged"] is True, "host process cohort not complete")
    require([row["name"] for row in processes["results"]] == ["import", *CASES], "host actual process census differs")
    counts = {}
    for row in processes["results"]:
        name = row["name"]
        require(row["status"] == "passed" and row["returncode"] == 0 and row["natural_completion"] is True,
                "host process not naturally successful: " + name)
        require(not row["diagnostic_error"] and not row["skip_messages"] and row["timeout_kind"] is None
                and row["timeout_diagnostic_error"] is None and row["capture_error"] is None
                and row["launch_error"] is None, "host error/skip/timeout: " + name)
        for log, expected in [(row["log"], row["log_sha256"]), (name + "-runner.log", row["runner_log_sha256"])]:
            require(independent["artifacts"]["host-e11b452f-01/" + log]["sha256"] == expected,
                    "host original raw-log identity differs: " + log)
        footer = "\n".join(row["footer_lines"])
        observed = {int(v) for v in re.findall(r"(?:assertions|checks)\s*=\s*(\d+)", footer, re.I)}
        observed |= {int(v) for v in re.findall(r"(\d+)\s+(?:assertions|checks)\b", footer, re.I)}
        if name in ("import", "test_tick_failure_regression"):
            require(not observed, "uncounted process interpreted as numerical assertions")
            if name == "test_tick_failure_regression":
                require("Tick failure regression: passed" in footer, "native failed-tick completion footer missing")
        else:
            require(len(observed) == 1, "missing/ambiguous retained assertion footer: " + name)
            counts[name] = observed.pop()
    require(sum(counts.values()) == independent["host"]["counted_assertions"], "host counted assertion total differs")
    app, desktop = read("metered-drain-native-host.json"), read("metered-drain-desktop-host.json")
    require(app["failures"] == desktop["failures"] == 0, "host packet failures")
    require(app["checks"] + 1 == counts["test_physical_metered_drain"]
            and desktop["assertions"] + 1 == counts["test_physical_metered_desktop"], "final packet-write assertion accounting differs")
    source_input("godot/tests/fixtures/in-tools-metered-drain.v1.json", app["fixture_sha256"])
    source_input("godot/tests/fixtures/in-tools-metered-desktop.v1.json", desktop["fixture_sha256"])

    def check_receipt(receipt: dict) -> str:
        if "metered_drain" not in receipt:
            return "ordinary-v1"
        outcome = receipt["metered_drain"]
        require(outcome["provenance"] == PROVENANCE and outcome["read_accounting"] == ACCOUNTING,
                "metered provenance/accounting contract mismatch")
        exact_int(outcome["reads_used"], "metered reads", 0, 2048)
        attempts = exact_int(outcome["writes_attempted"], "metered attempted writes", 0, 16)
        transitions = outcome["transitions"]
        require(len(transitions) == attempts, "attempt/transition census differs")
        water = brine = verified = 0
        for transition in transitions:
            if transition["verified_removed"] is True:
                verified += 1
                prior, post = transition["before"], transition["after"]
                require(post["ok"] is True and post["material"] == post["state_a"] == post["state_b"] == post["transient_body_id"] == 0,
                        "verified removal has invalid copied native post-state")
                require(prior["material"] == outcome["requested_material"], "verified removal used wrong material")
                require((prior["x"], prior["y"], prior["completed_tick"]) == (post["x"], post["y"], post["completed_tick"]),
                        "verified transition location/tick changed")
                if prior["material"] == 3:
                    water += exact_int(prior["state_a"], "actual Water quantity", 1, 255)
                else:
                    require(prior["material"] == 24, "unsupported verified material")
                    brine += 1
        require(outcome["water_units_removed"] == water and outcome["brine_cells_removed"] == brine
                and outcome["sink_debit"] == water + brine, "copied verified transition sum does not close")
        require(outcome["budget_before"] - outcome["sink_debit"] == outcome["remaining_budget"], "permission stock residual")
        require(receipt["changed_cells"] == verified, "verified changed-cell count differs")
        status = outcome["status"]
        if status == "applied":
            require(receipt["accepted"] is True and outcome["quantity_complete"] is True and verified == attempts > 0,
                    "applied result is incomplete")
            require(outcome["charge_cost"] == 0.85 and receipt["cooldown"] == 0.1, "accepted activation resources differ")
        elif status == "refused":
            require(receipt["accepted"] is False and attempts == 0 and water + brine == 0
                    and outcome["charge_cost"] == 0.0, "normal refusal edited/debited material")
        else:
            require(status == "fault" and outcome["quantity_complete"] is False and receipt["accepted"] is False,
                    "unexpected result was not retained as incomplete fault")
        return status

    command_status = Counter(check_receipt(row["receipt"]) for row in app["commands"])
    quantity_rows = [row for row in app["rows"] if row["case"] == "quantity-and-shutoff"]
    require(len(quantity_rows) == 16, "registered one/four application quantity-arm census mismatch")
    pairs = defaultdict(dict)
    quantity_summary = []
    for row in quantity_rows:
        check_receipt(row["command"])
        outcome = row["command"]["metered_drain"]
        unit = "water" if row["material"] == 3 else "brine"
        require(row["initial"][unit] - outcome["sink_debit"] == row["final"][unit], "application independent census residual")
        require(row["initial"]["walls"] == row["final"]["walls"], "application barriers changed")
        transport = row["transport_observations"]
        require(len(transport) == 8 and [t["completed_tick"] for t in transport] == list(range(1, 9)), "post-shutoff tick coverage differs")
        require(all(t["quantity"] == row["final"] for t in transport), "post-shutoff quantity changed")
        observed = max(t["actual_phase_claimants"] for t in transport)
        require(observed == row["actual_claimants_max"] and 1 <= observed <= row["configured_workers"], "application claimant scope invalid")
        key = (row["material"], row["family"], row["bits"], row["fractional"])
        require(row["configured_workers"] not in pairs[key], "duplicate configured-worker application arm")
        pairs[key][row["configured_workers"]] = row
        quantity_summary.append({"material": row["material"], "family": row["family"], "bits": row["bits"],
                                 "fractional": row["fractional"], "workers": row["configured_workers"],
                                 "observed_claimants": observed, "initial": row["initial"][unit],
                                 "sink": outcome["sink_debit"], "final": row["final"][unit], "unit": unit})
    for pair in pairs.values():
        require(set(pair) == {1, 4} and pair[1]["physical_hash"] == pair[4]["physical_hash"], "application one/four physical parity mismatch")

    # Independently recompute every new A02 trace formula and the boundary pair.
    work = {row["case"].removeprefix("material-work-"): row for row in app["rows"] if row["case"].startswith("material-work-")}
    require(set(work) == {"full-q255", "exact-capacity", "one-unit-short", "fractional-freemass", "empty-intake",
                          "supercover-corner", "exhausted-stock", "injected-post-copy-fault"}, "A02 registered path census differs")
    work_summary = []
    for name, row in work.items():
        status = check_receipt(row["receipt"])
        trace = row["trace"]
        outcome = row["receipt"]["metered_drain"]
        p, post, erases = trace["preflight_inspections"], trace["post_inspections"], trace["erase_attempts"]
        points = [tuple(point) for point in trace["unique_preflight_points"]]
        require(len(points) == len(set(points)) == p, "A02 preflight cache inspection mismatch")
        helper = p + post + 10 * trace["apply_refreshes"] + 6 * trace["pre_identity_checks"] + 8 * trace["post_identity_checks"]
        require(helper == row["derived_helper_units"] == outcome["reads_used"], "A02 independent helper formula mismatch")
        require(erases == post == outcome["writes_attempted"], "A02 erases lack fresh forwarded post-read")
        require(len(trace["post_readbacks"]) == post, "A02 recorded post-read count differs")
        require(all(r["ok"] is True and r["material"] == 0 for r in trace["post_readbacks"]), "A02 forwarded post-read did not see real native Empty")
        clearance = row["source_clearance_units_from_parent_counter"]
        require(row["command_material_work_units"] == clearance + helper, "A02 parent/helper accounting residual")
        total = row["prior_material_work_units"] + clearance + helper + row["optional_observation_units"]
        require(total == row["final_shared_material_work_units"] <= 2048 and row["final_shared_writes"] <= 128, "A02 shared budget overrun")
        if trace["first_write"]:
            first = trace["first_write"]
            require(first["terminal"] is True and first["status"] == "fault" and first["reason"] == "interrupted_execution"
                    and first["preflight_complete"] is True and first["writes_attempted"] == 1, "A02 first writer preceded quarantine/preflight")
            require(first["material_work_units_before_write"] == 10 + p + 6 and first["observed_pre_identity_checks"] == 1,
                    "A02 first writer identity reservation mismatch")
            require(first["reads_available"] - first["material_work_units_before_write"] >= first["planned_targets"] + 8
                    and first["writes_available"] >= first["planned_targets"], "A02 first writer had insufficient reserved capacity")
            for stock in ("water_units_remaining", "water_units_removed", "brine_cells_remaining", "brine_cells_removed"):
                require(first["stock_before"][stock] == row["context_before"][stock], "A02 stock debited before first write")
        removed = row["initial"]["water"] - row["final"]["water"]
        if status == "applied":
            require(removed == outcome["sink_debit"], "A02 accepted census residual")
        elif status == "refused":
            require(row["initial"] == row["final"] and row["physical_hash_before"] == row["physical_hash_after"]
                    and erases == 0, "A02 refusal changed actual native state")
        work_summary.append({"case": name, "status": status, "reason": outcome["reason"], "preflight_inspections": p,
                             "post_inspections": post, "erase_attempts": erases, "helper_units": helper,
                             "source_units": clearance, "prior_units": row["prior_material_work_units"],
                             "optional_units": row["optional_observation_units"], "shared_units": total,
                             "actual_water_removed": removed, "verified_sink": outcome["sink_debit"],
                             "unverified_water_difference": removed - outcome["sink_debit"]})
    normal, exact, short, fault = (work[k] for k in ["full-q255", "exact-capacity", "one-unit-short", "injected-post-copy-fault"])
    expected_prior = 2048 - normal["source_clearance_units_from_parent_counter"] - normal["derived_helper_units"]
    require(exact["prior_material_work_units"] == expected_prior and short["prior_material_work_units"] == expected_prior + 1,
            "A02 boundary was not derived from observed normal operation")
    require(exact["receipt"]["accepted"] is True and exact["trace"]["erase_attempts"] == 16
            and exact["final_shared_material_work_units"] == 2048, "A02 exact boundary did not complete")
    require(short["receipt"]["accepted"] is False and short["receipt"]["reason"] == "read_capacity"
            and short["trace"]["erase_attempts"] == 0 and short["trace"]["first_write"] == {}
            and short["context_after"]["terminal"] is False
            and short["receipt"]["charge"] == 100.0 and short["receipt"]["cooldown"] == 0.0,
            "A02 one-unit-short refusal contract failed")
    for row in (exact, short):
        require(row["optional_observation_units"] == 0 and row["optional_patch_empty"] is True, "A02 optional observation escaped bound")
    require(fault["receipt"]["metered_drain"]["quantity_complete"] is False
            and fault["context_after"]["terminal"] is True
            and fault["initial"]["water"] - fault["final"]["water"] == 255
            and fault["receipt"]["metered_drain"]["sink_debit"] == 0
            and fault["trace"]["erase_attempts"] == fault["trace_after_blocked_retry"]["erase_attempts"] == 1
            and fault["optional_observation_attempted"] is False, "A02 uncertain post-edit fault was normalised or retried")
    corner = work["supercover-corner"]
    require(corner["corner_blocker"] in corner["trace"]["unique_preflight_points"]
            and [105, 89] not in corner["trace"]["unique_preflight_points"]
            and corner["receipt"]["reason"] == "wrong_material", "A02 actual corner refusal witness missing")
    failure = next(row for row in app["rows"] if row["case"] == "actual-native-capacity-failure")
    require(failure["attempted_tick"] == 1 and failure["completed_tick"] == 0
            and "capacity" in failure["native_error"], "genuine native failed-tick control missing")

    # Main's observed asynchronous quantities are reduced from this run only.
    desktop_quantities = []
    for row in desktop["reports"]:
        if "water_units_final" not in row:
            continue
        unit = "brine" if row["case"] == "brine-in-main" else "water"
        final = row["brine_cells_final"] if unit == "brine" else row["water_units_final"]
        ordinary = row["ordinary_control_sink_from_joined_censuses"]
        require(row["initial"] - row["sink_debit"] - ordinary == final, "desktop actual quantity residual: " + row["case"])
        desktop_quantities.append({"case": row["case"], "initial": row["initial"], "metered_sink": row["sink_debit"],
                                   "ordinary_joined_census_difference": ordinary, "final": final, "unit": unit, "tick": row["native_tick"]})
    protected = next(row for row in desktop["reports"] if row["case"] == "actual-rapier-protected-source-positions")
    require(protected["after_tick"] > protected["before_tick"] and len(protected["before_cells"]) == len(protected["after_cells"]) == 6,
            "desktop body witnesses lack advancing native tick/six cells")
    before_cells = {(c["x"], c["y"]): c for c in protected["before_cells"]}
    after_cells = {(c["x"], c["y"]): c for c in protected["after_cells"]}
    require(set(before_cells) == set(after_cells) and len(before_cells) == 6, "desktop body witness coordinates differ")
    for point, prior in before_cells.items():
        post = after_cells[point]
        require({k: v for k, v in prior.items() if k != "completed_tick"}
                == {k: v for k, v in post.items() if k != "completed_tick"}, "desktop protected stored values/mask changed")
        require(prior["material"] == 3 and prior["state_a"] == 255 and prior["transient_body_id"] == 1,
                "desktop body witness is not full Water beneath actual mask")

    require(dict(command_status) == independent["host"]["command_status_counts"], "command status census differs from independent raw reduction")
    require(work_summary == independent["a02"]["instrumented_paths"], "material-work reduction differs from independent raw reduction")
    require(desktop_quantities == independent["host"]["desktop_quantities"], "desktop reduction differs from independent raw reduction")
    return {
        "schema": "pr383-successor-transport-published-packet-check-v1",
        "status": "PASS_WITH_EXPLICIT_SCOPE",
        "source_commit": SOURCE, "source_tree": TREE,
        "transport_authentication": transport_identity,
        "source_lookup_commit": source_lookup, "execution_reassigned": False,
        "candidate": candidate, "candidate_tree": candidate_tree,
        "candidate_changes_from_measured_source": candidate_changes,
        "tracked_worktree_changes_from_measured_source": worktree_changes,
        "index_members_verified": len(members),
        "source_inputs_verified": len(before["source_inputs"]),
        "native_compiled_inputs_verified": len(n["input_sha256"]),
        "runtime_payload_git_identities_verified": len(payloads),
        "materialized_payloads_currently_rehashed": sorted(materialized),
        "payload_bytes_not_available_here": sorted(unavailable_payloads),
        "independent_raw_review_sha256": INDEPENDENT_REVIEW_SHA256,
        "native_cases": len(native_rows), "native_repeated_assertions": native_packet["assertions"],
        "native_exact_four_claimant_arms": len(worker_rows),
        "parser_tests_recorded": parser_wrapper["final_summary"]["tests"],
        "host_suite_count": len(CASES), "host_counted_assertions_from_retained_footers": sum(counts.values()),
        "host_counts": counts, "command_status_counts": dict(command_status),
        "a02_accounting": ACCOUNTING, "aggregate_all_native_call_cap_claimed": False,
        "material_work_paths": work_summary, "desktop_quantities": desktop_quantities,
        "original_copy_bytes_authenticated_here": raw_verified,
        "original_packet_token_transform_verified_here": raw_task is not None,
        "limitations": [
            "Read-only evidence reduction; no tests, engine or compiler executed by this checker.",
            "Execution belongs to archived e11b452f; authenticated implementation and publication descendants are qualified by explicit complete-tree/input equivalence only.",
            "Raw process logs, executable/toolchain bytes and original raw packet files are outside the published packet; their hashes and the immutable prior independent raw-artifact review are retained.",
            "Without --raw-task-root, original whitespace transformation cannot be re-derived here; this checker verifies published hashes, retained original hashes and the documented census/accounting reductions from included observations.",
            "Retained completion footers are authenticated records; absent raw logs cannot be independently rescanned for diagnostics here.",
            "Unmaterialized Git LFS payload identities are checked from pointers; absent runtime bytes are listed explicitly, never treated as freshly hashed.",
            "No all-native-call/all-getter 2048 cap; prior-used boundary units are a synthetic counter seed.",
            "Windows, physical-device input, actual window focus, rendered pacing and resulting-main integration remain NOT RUN."
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--packet-dir", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--candidate", default="HEAD", help="Descendant of authenticated implementation to compare to measured tree; INDEX reads the staged candidate")
    parser.add_argument("--raw-task-root", type=Path, help="Optional retained execution root for exact-copy and packet-token authentication")
    args = parser.parse_args()
    print(json.dumps(review_published(args.repo.resolve(), args.packet_dir.resolve(), args.candidate,
                                      args.raw_task_root.resolve() if args.raw_task_root else None), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
