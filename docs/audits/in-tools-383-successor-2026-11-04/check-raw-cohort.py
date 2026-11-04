#!/usr/bin/env python3
"""Read-only independent reduction of PR383's e11b452f execution cohort.

Reads source Git objects, materialized runtimes and original output packets/logs.
No engine/compiler/tests are executed. The only optional write is a new JSON
review file beneath this checker's own directory; existing output is refused.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

SOURCE = "e11b452f1e90a8a014ab4d721b7c65724a508597"
TREE = "22a35293c7373ea4583b78121778b00ecdf6eeee"
BASE_SOURCE = "73b10f9b800e72f358f22f470e57a4531002c168"
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


def review(task: Path) -> dict:
    source = task / "source"
    host = task / "host-e11b452f-01"
    native = task / "native-e11b452f-01"
    parser = task / "parser-e11b452f-01"
    artifacts = {}

    def artifact(path: Path, expected: str | None = None) -> str:
        actual = digest(path)
        if expected is not None:
            require(actual == expected, "artifact hash mismatch: " + str(path))
        try:
            name = str(path.relative_to(task))
        except ValueError:
            name = str(path)
        artifacts[name] = {"sha256": actual, "bytes": path.stat().st_size}
        return actual

    def read(path: Path):
        artifact(path)
        return parse_json(path.read_text())

    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", *args], cwd=source, timeout=60)

    def blob(path: str, ref: str = SOURCE) -> bytes:
        return git("show", ref + ":" + path)

    def source_input(path: str, expected: str) -> None:
        actual_path = (source / path).resolve()
        require(digest(actual_path) == expected, "current input differs: " + path)
        if path.startswith("../"):
            return
        raw = blob(path)
        pointer = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n", raw)
        if pointer:
            require(pointer[1].decode() == expected and int(pointer[2]) == actual_path.stat().st_size,
                    "materialized input differs from committed LFS identity: " + path)
        else:
            require(sha_bytes(raw) == expected, "input differs from committed source: " + path)

    require(git("rev-parse", SOURCE + "^{tree}").decode().strip() == TREE, "measured tree mismatch")
    require(git("rev-parse", SOURCE + "^").decode().strip() == BASE_SOURCE, "unexpected implementation parent")
    require(sha_bytes(git("diff", "--binary", BASE_SOURCE, SOURCE)) == REVIEWED_DIFF, "executed delta differs from source review")
    changes = git("diff", "--name-only", BASE_SOURCE, SOURCE).decode().splitlines()
    require(changes == CHANGED_PATHS, "unexpected implementation changes")
    unchanged_trees = {}
    for scope in ["native/include", "native/src", "godot/native_extension", "materials", "third_party", "godot/third_party"]:
        old = git("rev-parse", BASE_SOURCE + ":" + scope).decode().strip()
        new = git("rev-parse", SOURCE + ":" + scope).decode().strip()
        require(old == new, "protected production scope changed: " + scope)
        unchanged_trees[scope] = new

    # Compiler, executable, complete native output and the eight actual claimant rows.
    n = read(native / "record.json")
    require(n["status"] == "pass" and n["compile_exit"] == n["run_exit"] == 0, "native run did not pass")
    require((n["git_commit"], n["git_tree"]) == (SOURCE, TREE), "native source identity mismatch")
    require(n["native_status"] == "" and n["inputs_unchanged"] and n["executable_unchanged"], "native source/executable custody failed")
    require(n["input_sha256"] == n["input_sha256_after"], "native before/after inputs differ")
    for path, expected in n["input_sha256"].items():
        source_input(path, expected)
    artifact(Path(n["compiler"]), n["compiler_sha256"])
    require(n["run_command"] == [str(native / "metered_drain")], "unexpected native execution path")
    artifact(native / "metered_drain", n["executable_sha256"])
    require(n["compile_command"][-2:] == ["-o", str(native / "metered_drain")], "compiler output differs from executed binary")
    require(n["compile_command"][0] == n["compiler"], "compiler command mismatch")
    source_input("tools/lcb/run_metered_drain_native.py", n["runner_sha256"])
    for name, expected in n["log_sha256"].items():
        artifact(native / name, expected)
    native_packet = parse_json((native / "run.stdout.log").read_text())
    require(native_packet == n["results"], "native raw output differs from retained result")
    require(native_packet["status"] == "pass" and native_packet["scope"] == "native-core-only"
            and native_packet["production_application_executed"] is False, "native packet scope mismatch")
    native_rows = native_packet["cases"]
    require(len(native_rows) == 30 and len({r["case_id"] for r in native_rows}) == 30, "native registered case census mismatch")
    worker_rows = [r for r in native_rows if r["case_id"].startswith("workers.")]
    require({r["case_id"] for r in worker_rows} == {"workers." + p for p in PROFILES}, "native worker profile coverage mismatch")
    for row in worker_rows:
        require(exact_int(row["workers1_observed"], "one claimant") == 1
                and exact_int(row["workers4_observed"], "four claimants") == 4,
                "native registered claimant proof is not exactly one/four")
        require(row["ticks_per_arm"] == 64 and row["physical_hash_parity"] is True
                and row["inertial_ledger_parity"] is True and row["phase_jobs_workers4"] > 0,
                "native worker parity/phase coverage failed")
        require(row["initial_quantity"] - row["removed_quantity"] == row["remaining_quantity"], "native flow quantity residual")

    # Parser execution is synthetic evidence and remains separately labelled.
    pc = read(parser / "record.json")
    require((pc["source_commit"], pc["source_tree"]) == (SOURCE, TREE), "parser source mismatch")
    require(pc["returncode"] == 0 and pc["inputs_unchanged"], "parser controls failed")
    for name, expected in pc["source_sha256"].items():
        source_input(name, expected)
    for name, expected in pc["logs"].items():
        artifact(parser / name, expected)
    parser_log = (parser / "stderr.log").read_text()
    match = re.search(r"Ran (\d+) tests? in", parser_log)
    require(match is not None and parser_log.rstrip().endswith("OK"), "parser unittest completion missing")
    for name in ["test_valid_synthetic_shape", "test_two_claimants_cannot_qualify_four_worker_arm",
                 "test_three_claimants_cannot_qualify_four_worker_arm", "test_missing_claimant_count",
                 "test_boolean_claimant_count", "test_fractional_claimant_count",
                 "test_integer_valued_floating_claimant_count"]:
        require(re.search(r"^" + name + r" .* \.\.\. ok$", parser_log, re.M) is not None, "parser control missing: " + name)

    # Exact current-source and platform identities, independently rehashed.
    before = read(host / "identity-before.json")
    after = read(host / "identity-after.json")
    processes = read(host / "processes.json")
    for record in (before, after, processes):
        require((record["source_commit"], record["source_tree"]) == (SOURCE, TREE), "host source identity mismatch")
    require(before["initial_git_status"] == "", "host did not start from clean committed source")
    require(before["source_inputs_count"] == len(before["source_inputs"]) == after["source_inputs_count"], "host input counts differ")
    require(after["source_drift"] == after["runtime_drift"] == [], "host before/after source drift")
    for name, expected in before["source_inputs"].items():
        source_input(name, expected)
    artifact(Path(before["godot_path"]), before["godot_sha256"])
    require(before["godot_sha256"] == after["godot_sha256"], "Godot executable changed")
    artifact(task / "run-host-successor.py", before["harness_sha256"])
    source_input("tools/ci/run_godot_regressions.py", before["runner_sha256"])
    require(before["selected_cases"] == CASES, "scoped host case plan differs")
    require(before["isolation_environment"]["CYBERSAND_SOURCE_REVISION"] == SOURCE, "host environment source mismatch")
    require(before["isolation_environment"]["XDG_DATA_HOME"] == str(host / "xdg-data"), "host evidence root differs")
    runtime_summary = []
    for name, row in before["runtime_provenance"].items():
        manifest = read(source / name)
        require(digest(source / name) == row["manifest_sha256"], "runtime manifest differs")
        artifact(source / row["artifact"], row["expected_sha256"])
        require((source / row["artifact"]).stat().st_size == row["expected_size"], "runtime size differs")
        require(row["actual_file_sha256"] == row["expected_sha256"] and row["materialized"] is True, "runtime not authenticated materialized bytes")
        for path, expected in manifest["source_inputs"].items():
            source_input(path, expected)
        if "cybersand_native" in name:
            require(len(manifest["source_inputs"]) == before["native_input_count"] == 80, "native runtime source inventory mismatch")
        runtime_summary.append({"manifest": name, "artifact": row["artifact"], "sha256": row["expected_sha256"],
                                "source_inputs": len(manifest["source_inputs"]), "build_commit": row.get("build_commit"),
                                "execution_claim": row["execution_claim"]})
    payloads = read(task / "runtime-materialization.json")
    require(len(payloads) == 18, "materialized runtime census differs")
    for row in payloads:
        artifact(source / row["path"], row["sha256"])
        require((source / row["path"]).stat().st_size == row["size"], "materialized runtime size mismatch")
        source_input(row["path"], row["sha256"])

    # Inspect raw stdout, not only the aggregate's status flags.
    require(processes["status"] == "passed" and processes["source_inputs_unchanged"]
            and processes["runtime_bytes_unchanged"], "host cohort incomplete or failed")
    require([r["name"] for r in processes["results"]] == ["import", *CASES], "host actual process census differs")
    suites = []
    assertions = 0
    counts = {}
    for row in processes["results"]:
        name = row["name"]
        require(row["status"] == "passed" and row["returncode"] == 0 and row["natural_completion"] is True,
                "host did not naturally pass: " + name)
        require(not row["diagnostic_error"] and not row["skip_messages"] and row["timeout_kind"] is None
                and row["timeout_diagnostic_error"] is None and row["capture_error"] is None,
                "host skipped/errored/timed out: " + name)
        artifact(host / row["log"], row["log_sha256"])
        artifact(host / (name + "-runner.log"), row["runner_log_sha256"])
        raw = (host / row["log"]).read_text()
        require("SCRIPT ERROR:" not in raw and "ERROR:" not in raw
                and re.search(r"\bskipped\b|^\s*SKIP\b", raw, re.I | re.M) is None,
                "raw host diagnostic invalidates pass: " + name)
        require(row["command"][0] == before["godot_path"]
                and str(source / "godot") in row["command"], "host executed a different runtime/checkout")
        observed = {int(v) for v in re.findall(r"(?:assertions|checks)\s*=\s*(\d+)", raw, re.I)}
        observed |= {int(v) for v in re.findall(r"(\d+)\s+(?:assertions|checks)\b", raw, re.I)}
        if name in ("import", "test_tick_failure_regression"):
            require(not observed, "unexpected numeric assertion interpretation: " + name)
            count = None
            if name == "test_tick_failure_regression":
                require("Tick failure regression: passed" in raw, "genuine failure regression footer missing")
        else:
            require(len(observed) == 1, "ambiguous/missing numeric assertion footer: " + name)
            count = observed.pop()
            assertions += count
            counts[name] = count
        suites.append({"name": name, "assertions": count, "seconds": row["seconds"], "returncode": row["returncode"]})

    packet_root = host / "xdg-data/godot/app_userdata/Cyber Sand Reference Sandbox"
    app = read(packet_root / "metered-drain-native-host.json")
    desktop = read(packet_root / "metered-drain-desktop-host.json")
    require(app["failures"] == desktop["failures"] == 0, "application packet failures")
    require(app["checks"] + 1 == counts["test_physical_metered_drain"], "native-host final packet-write assertion mismatch")
    require(desktop["assertions"] + 1 == counts["test_physical_metered_desktop"], "desktop final packet-write assertion mismatch")
    for packet, name in [(app, "godot/tests/fixtures/in-tools-metered-drain.v1.json"),
                         (desktop, "godot/tests/fixtures/in-tools-metered-desktop.v1.json")]:
        source_input(name, packet["fixture_sha256"])

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

    return {
        "schema": "pr383-successor-independent-execution-review-v1", "reviewed_utc": datetime.now(timezone.utc).isoformat(),
        "status": "PASS_WITH_EXPLICIT_SCOPE", "reviewer": "custody_review subagent; no implementation authorship; no account approval",
        "source_commit": SOURCE, "source_tree": TREE, "source_parent": BASE_SOURCE, "reviewed_diff_sha256": REVIEWED_DIFF,
        "changed_paths": changes, "protected_production_trees_unchanged": unchanged_trees,
        "a01": {"disposition": "corrected and freshly executed", "registered_native_cases": len(native_rows),
                "repeated_assertions": native_packet["assertions"], "assertion_scope": "predominantly repeated census assertions, not independent experiments",
                "worker_rows": worker_rows, "compiler_sha256": n["compiler_sha256"], "executable_sha256": n["executable_sha256"],
                "native_input_count": len(n["input_sha256"]), "parser_tests": int(match[1]), "parser_scope": pc["scope"]},
        "a02": {"disposition": "properly limited material-work contract; instrumented capacity/refusal/fault evidence verified",
                "read_accounting": ACCOUNTING, "aggregate_all_native_call_cap_claimed": False,
                "instrumented_paths": work_summary, "exact_fit_prior_units": expected_prior,
                "synthetic_prior_use": "counter seed; not previously executed native calls",
                "source_clearance_scope": "contribution from parent counter, with source call-path inspection; no independent all-getter census",
                "fault_scope": "actual native erase and forwarded post-inspection, then deliberately corrupted copied result"},
        "host": {"suites": suites, "suite_count": len(CASES), "process_count_including_import": len(suites),
                 "counted_assertions": assertions, "uncounted_suite": "test_tick_failure_regression",
                 "input_count": len(before["source_inputs"]), "native_runtime_input_count": before["native_input_count"],
                 "runtime_payloads_materialized": len(payloads), "runtimes": runtime_summary,
                 "godot_version": before["godot_version"], "godot_sha256": before["godot_sha256"],
                 "native_host_packet_rows": len(app["rows"]), "native_host_commands": len(app["commands"]),
                 "command_status_counts": dict(command_status), "quantity_arms": quantity_summary,
                 "packet_write_assertion_difference": "Each of the two packet files excludes its final successful writable assertion; footer is packet count + 1",
                 "desktop_quantities": desktop_quantities,
                 "protected_body_witnesses": {"before_tick": protected["before_tick"], "after_tick": protected["after_tick"], "cells": 6}},
        "historical_evidence": "f4878302, 73b10f9b and c83984c0 remain separate immutable cohorts; none reassigned",
        "limitations": ["Windows execution NOT RUN", "Physical input and real window focus NOT RUN", "Rendered pacing and human acceptance NOT RUN",
                        "No hosted workflow dispatch or resulting-main qualification", "No all-native-call/all-getter 2048 cap claimed",
                        "Headless Main input is synthetic; native-host physical frames/masks include fixture-authored values",
                        "Equipment suite uses real Rapier with synthetic copied outcomes", "No mapped-module attestation invented",
                        "Ready/merge/approval/auto-merge/parent closure remain unauthorized"],
        "artifacts": artifacts, "checker_sha256": digest(Path(__file__)),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-root", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.output:
        require(args.output.resolve().parent == Path(__file__).resolve().parent, "review output must stay beside this checker")
        require(not args.output.exists(), "existing review output is immutable")
    result = review(args.task_root.resolve())
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        with args.output.open("x") as handle:
            handle.write(encoded)
    print(json.dumps({"status": result["status"], "source_commit": SOURCE, "host_assertions": result["host"]["counted_assertions"],
                      "native_assertions": result["a01"]["repeated_assertions"], "commands": result["host"]["command_status_counts"],
                      "output": str(args.output) if args.output else None}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
