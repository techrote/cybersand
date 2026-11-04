#!/usr/bin/env python3
"""Strict evidence reducer for WATER-CONTACT #362 `water_contact.impact.v1`.

Reads one or more campaign packets (directories written by
godot/tests/run_water_contact_campaign.gd, optionally wrapped by
tools/water_contact/run_campaign.py), checks every registered invariant and
reduces the records to a cross-family discrimination summary.

The reducer never repairs, fills or re-classifies a record: a missing,
duplicate, refused or invariant-violating run is reported as a failure.
Exit status is nonzero when any check fails.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "godot/tests/fixtures/water_contact/water_contact.impact.v1.json"
RECORD_SCHEMA = "water-contact-impact-record-v1"
PROBE_SCHEMA = "water-contact-kinematic-probe-v1"
FLOOR_TOLERANCE = 2.0  # retained WEX-001 characterization tolerance, report-only


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def manifest_digest(path: Path) -> str:
    # Godot hashes the UTF-8 text it read; identical to the file bytes for an
    # LF, BOM-free manifest. CRLF checkouts are normalised to the Git blob form.
    return sha256_bytes(path.read_bytes().replace(b"\r\n", b"\n"))


def expected_runs(manifest: dict, stage: int, workers: list[int]) -> set[tuple[str, str, int]]:
    out = set()
    for case in manifest["cases"]:
        if int(case.get("stage", 2)) > stage:
            continue
        for arm in manifest["arms"]:
            for count in workers:
                out.add((case["id"], arm["id"], count))
    return out


def check_record(record: dict, manifest: dict, digest: str) -> list[str]:
    """Return a list of failures for one dynamic record (empty when valid)."""
    errors: list[str] = []
    tag = f"{record.get('case')}/{record.get('arm')}/w{record.get('workers_configured')}"

    def fail(message: str) -> None:
        errors.append(f"{tag}: {message}")

    if record.get("schema") != RECORD_SCHEMA:
        fail(f"schema {record.get('schema')!r}")
        return errors
    if record.get("manifest_sha256") != digest:
        fail("manifest hash differs from the registered manifest")
    if record.get("error"):
        fail(f"run error: {record.get('error')}")
        return errors
    violations = record.get("violations", [])
    if violations:
        kinds = sorted({v.get("kind") for v in violations})
        fail(f"recorded invariant violations: {kinds}")
    if bool(record.get("ok")) != (not violations and record.get("final", {}).get("completed_ticks") == record.get("horizon")):
        fail("ok flag inconsistent with violations/horizon")

    arms = {arm["id"]: arm for arm in manifest["arms"]}
    cases = {case["id"]: case for case in manifest["cases"]}
    arm = arms.get(record.get("arm"))
    case = cases.get(record.get("case"))
    if arm is None or case is None:
        fail("unregistered case or arm")
        return errors

    identity = record.get("identity", {})
    for key, expected in (("applied_family", arm["family"]), ("applied_variant", arm["variant"]),
                          ("applied_radius", arm["radius"]), ("backend", "native-phased"),
                          ("configured_workers", record.get("workers_configured"))):
        if identity.get(key) != expected:
            fail(f"identity {key}={identity.get(key)!r}, expected {expected!r} (hidden fallback or refusal)")

    runtime = record.get("runtime", {})
    if not runtime.get("runtime_matches_provenance"):
        fail("loaded native runtime bytes do not match recorded provenance")
    if runtime.get("physics_engine_setting") != "Rapier2D" or not runtime.get("rapier_server_class_present"):
        fail("Rapier2D engine not active")

    final = record.get("final", {})
    initial = record.get("initial_water", {})
    if final.get("failed") or final.get("tick_failures"):
        fail("World failed or recorded tick failures")
    if final.get("completed_ticks") != record.get("horizon"):
        fail("completed ticks differ from the registered horizon")
    q0 = initial.get("global", {}).get("quantity")
    if q0 != final.get("global_water", {}).get("quantity"):
        fail(f"global Water quantity {q0} -> {final.get('global_water', {}).get('quantity')}")
    with_water = bool(case.get("water", True)) and int(case.get("depth", 0)) > 0
    expected_q = int(manifest["world"]["basin"]["width"]) * int(case.get("depth", 0)) * 255 if with_water else 0
    if q0 != expected_q or initial.get("interior", {}).get("quantity") != expected_q:
        fail(f"construction quantity {q0} differs from whole-cell expectation {expected_q}")

    reloc = record.get("relocation", {})
    hist = reloc.get("histogram_total", {})
    results = reloc.get("results", {})
    if hist.get("total") != results.get("displaced"):
        fail(f"BodyDisplacement events {hist.get('total')} != coupling displaced {results.get('displaced')}")
    if results.get("destinations_in_roi") != results.get("displaced"):
        fail("relocation destinations outside the observation ROI")
    if hist.get("other_material"):
        fail("non-Water material relocated in a Water-only fixture")
    if results.get("carried_state_mismatches"):
        fail("relocation changed carried stored state")
    if int(results.get("displaced") or 0) > 0 and int(results.get("carried_state_checks") or 0) < 1:
        fail("carried-state check vacuous: relocations occurred but no complete check ran")
    if int(results.get("global_checks", 0)) < 1:
        fail("no complete-World quantity check recorded")

    if arm["family"] == "inertial_cellular_v1":
        inertial = record.get("inertial", {})
        if inertial.get("negative_vy") or inertial.get("destinations_negative_vy"):
            fail("inertial Water held negative vy")
        if with_water and not inertial.get("censuses"):
            fail("no inertial census recorded")
    if arm["family"] != "pressure_flow_v1" and record.get("pressure", {}).get("available", False):
        fail("pressure state reported outside PressureFlow")

    with_body = bool(case.get("body", True))
    if with_body:
        rapier = record.get("rapier", {})
        if rapier.get("manual_steps") != record.get("horizon"):
            fail("Rapier manual steps differ from native ticks")
        if rapier.get("stale_rejected"):
            fail("stale result rejected in an ordinary run")
        mask = record.get("mask", {})
        if mask.get("mismatched_cells") or not mask.get("checks"):
            fail("body mask differs from current-pose rasterization or was not checked")
        if case.get("stale_duplicate_probe"):
            probe = record.get("stale_duplicate_probe", {})
            if probe.get("duplicate_snapshot_applied") != 0 or probe.get("stale_applied") != 0 \
                    or probe.get("stale_rejected") != 1:
                fail(f"duplicate/stale rejection control failed: {probe}")
    else:
        if results.get("displaced") or results.get("contacts"):
            fail("body-free control produced coupling")
    if not with_water and (results.get("displaced") or q0):
        fail("no-Water control contains or relocated Water")
    return errors


def check_probes(packet: dict, manifest: dict, digest: str) -> tuple[list[str], list[dict]]:
    errors: list[str] = []
    rows: list[dict] = []
    if packet.get("manifest_sha256") != digest:
        errors.append("probes: manifest hash differs")
    by_arm: dict[str, list[dict]] = {}
    for probe in packet.get("probes", []):
        if probe.get("schema") != PROBE_SCHEMA:
            errors.append(f"probe schema {probe.get('schema')!r}")
            continue
        by_arm.setdefault(probe["arm"], []).append(probe)
        if not probe.get("ok"):
            errors.append(f"probe {probe['arm']}/{probe.get('probe_id')} failed: {probe.get('error', '')}")
        if probe.get("mode") == "overlap" and probe.get("relocation_rows_up", 0) <= 0:
            errors.append(f"probe {probe['arm']}/{probe.get('probe_id')} did not relocate upward")
        rows.append({k: probe.get(k) for k in ("arm", "probe_id", "mode", "body_velocity", "source", "destination",
                                               "relocation_rows_up", "next_tick_rows_up", "state_before",
                                               "state_after", "state_carried_unchanged", "results", "inertial")})
    expected_modes = {mode["id"] for mode in manifest["kinematic_probe"]["modes"]}
    for arm in manifest["arms"]:
        probes = by_arm.get(arm["id"], [])
        if {p.get("probe_id") for p in probes} != expected_modes:
            errors.append(f"probes {arm['id']}: incomplete mode set")
            continue
        overlap = [p for p in probes if p.get("mode") == "overlap"]
        signatures = {(tuple(p.get("destination", [])), p.get("state_after")) for p in overlap}
        if len(signatures) != 1:
            errors.append(f"probes {arm['id']}: relocation depends on body velocity {sorted(signatures)}")
    return errors, rows


def load_packet(path: Path) -> tuple[list[dict], dict | None, dict | None, list[str]]:
    records: list[dict] = []
    errors: list[str] = []
    probes = None
    wrapper = None
    for file in sorted(path.glob("*.json")):
        try:
            value = json.loads(file.read_text(encoding="utf-8"))
        except ValueError as exc:
            errors.append(f"{file.name}: unreadable JSON: {exc}")
            continue
        if file.name == "kinematic_probes.json":
            probes = value
        elif file.name == "packet.json":
            wrapper = value
        elif file.name in ("index.json", "reduction.json"):
            continue
        elif value.get("schema") == RECORD_SCHEMA:
            records.append(value)
        else:
            errors.append(f"{file.name}: unknown evidence file")
    return records, probes, wrapper, errors


def summarize(record: dict) -> dict:
    reloc = record.get("relocation", {})
    results = reloc.get("results", {})
    hist = reloc.get("histogram_total", {})
    decomposition = record.get("decomposition", {})
    peaks = record.get("peaks", {})
    workers = record.get("workers", {})
    cost = record.get("cost", {})
    return {
        "case": record["case"], "arm": record["arm"], "workers": record["workers_configured"],
        "displaced": results.get("displaced"), "unresolved": results.get("unresolved"),
        "contacts": results.get("contacts"),
        "relocated_up": hist.get("up"), "relocated_lateral": hist.get("lateral"), "relocated_down": hist.get("down"),
        "destinations_above_surface": results.get("destinations_above_surface"),
        "destinations_in_band": results.get("destinations_in_band"),
        "max_destination_height": results.get("max_destination_height"),
        "masked_water_p50": results.get("masked_water_cells", {}).get("p50"),
        "masked_water_max": results.get("masked_water_cells", {}).get("max"),
        "relocation_above_gain": decomposition.get("relocation_above_gain"),
        "solver_above_gain": decomposition.get("solver_above_gain"),
        "solver_above_loss": decomposition.get("solver_above_loss"),
        "relocation_band_gain": decomposition.get("relocation_band_gain"),
        "solver_band_gain": decomposition.get("solver_band_gain"),
        "solver_peak_rises": decomposition.get("solver_peak_rises"),
        "solver_rise_rows": decomposition.get("solver_rise_rows"),
        "relocation_peak_rises": decomposition.get("relocation_peak_rises"),
        "peak_above_quantity": peaks.get("above_quantity"), "peak_above_tick": peaks.get("above_tick"),
        "peak_band_quantity": peaks.get("band_quantity"), "peak_band_tick": peaks.get("band_tick"),
        "peak_height": peaks.get("height"), "peak_height_tick": peaks.get("height_tick"),
        "band_span": peaks.get("band_span"), "band_isolated_max": peaks.get("band_isolated"),
        "band_unsupported_max": peaks.get("band_unsupported"),
        "band_return_tick": record.get("return", {}).get("band_return_tick"),
        "band_return_censored": record.get("return", {}).get("censored"),
        "inertial_max_vy": record.get("inertial", {}).get("max_vy"),
        "inertial_negative_vy": record.get("inertial", {}).get("negative_vy"),
        "pf_max_overfill": record.get("pressure", {}).get("max_overfill"),
        "pf_max_compartments": record.get("pressure", {}).get("max_compartments"),
        "floor_contact_tick": record.get("boundary", {}).get("floor_contact_tick"),
        "max_body_floor_penetration": record.get("boundary", {}).get("max_body_floor_penetration"),
        "max_body_wall_penetration": record.get("boundary", {}).get("max_body_wall_penetration"),
        "native_tick_us_p50": cost.get("native_tick_us", {}).get("p50"),
        "native_tick_us_p95": cost.get("native_tick_us", {}).get("p95"),
        "coupling_us_p50": cost.get("coupling_us", {}).get("p50"),
        "rapier_step_ms_p50": cost.get("rapier_step_ms", {}).get("p50"),
        "participants": workers.get("observed_participant_histogram"),
        "final_physical_state_hash": record.get("final", {}).get("physical_state_hash"),
        "trace_sha256": record.get("trace_sha256"),
    }


def reduce(packets: list[Path], manifest_path: Path, stage: int, workers: list[int]) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    digest = manifest_digest(manifest_path)
    report: dict = {"schema": "water-contact-reduction-v1", "manifest": manifest["experiment_id"],
                    "manifest_sha256": digest, "stage": stage, "workers": workers, "packets": [], "errors": []}
    for path in packets:
        records, probes, wrapper, load_errors = load_packet(path)
        errors = [f"{path.name}: {e}" for e in load_errors]
        seen: dict[tuple[str, str, int], dict] = {}
        for record in records:
            key = (record.get("case"), record.get("arm"), record.get("workers_configured"))
            if key in seen:
                errors.append(f"{path.name}: duplicate run {key}")
                continue
            seen[key] = record
            errors.extend(f"{path.name}: {e}" for e in check_record(record, manifest, digest))
        expected = expected_runs(manifest, stage, workers)
        for key in sorted(expected - set(seen)):
            errors.append(f"{path.name}: missing registered run {key}")
        for key in sorted(set(seen) - expected):
            errors.append(f"{path.name}: unregistered run {key}")
        # Worker parity (I9).
        parity = []
        for (case_id, arm_id, count), record in sorted(seen.items()):
            if count != workers[0] or len(workers) < 2:
                continue
            for other_count in workers[1:]:
                other = seen.get((case_id, arm_id, other_count))
                if other is None:
                    continue
                fields = {}
                for name, getter in (("trace_sha256", lambda r: r.get("trace_sha256")),
                                     ("physical_state_hash", lambda r: r.get("final", {}).get("physical_state_hash")),
                                     ("displaced", lambda r: r.get("relocation", {}).get("results", {}).get("displaced")),
                                     ("unresolved", lambda r: r.get("relocation", {}).get("results", {}).get("unresolved")),
                                     ("contacts", lambda r: r.get("relocation", {}).get("results", {}).get("contacts"))):
                    fields[name] = getter(record) == getter(other)
                same = all(fields.values())
                parity.append({"case": case_id, "arm": arm_id, "workers": [count, other_count], "identical": same,
                               "fields": fields})
                if not same:
                    errors.append(f"{path.name}: worker parity failed {case_id}/{arm_id} {fields}")
                participants = other.get("workers", {}).get("observed_participant_histogram", {})
                if case_id and int(max((int(k) for k in participants), default=0)) < 1:
                    errors.append(f"{path.name}: no task-claiming participant observed {case_id}/{arm_id}")
        probe_rows: list[dict] = []
        if probes is None:
            errors.append(f"{path.name}: kinematic probe packet missing")
        else:
            probe_errors, probe_rows = check_probes(probes, manifest, digest)
            errors.extend(f"{path.name}: {e}" for e in probe_errors)
        floor_flags = [summarize(r) for r in seen.values()
                       if (r.get("boundary", {}).get("max_body_floor_penetration") or 0.0) > FLOOR_TOLERANCE]
        runtime = next(iter(seen.values()), {}).get("runtime", {})
        report["packets"].append({
            "packet": path.name, "wrapper": wrapper, "runtime": runtime, "runs": len(seen),
            "parity": parity, "probes": probe_rows,
            "floor_tolerance_exceeded": [(f["case"], f["arm"], f["workers"], f["max_body_floor_penetration"]) for f in floor_flags],
            "rows": [summarize(r) for _, r in sorted(seen.items())],
            "errors": errors,
        })
        report["errors"].extend(errors)
    report["status"] = "failed" if report["errors"] else "passed"
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packets", nargs="+", type=Path)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--stage", type=int, default=2)
    parser.add_argument("--workers", default="1,4")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    workers = [int(v) for v in args.workers.split(",") if v]
    report = reduce(args.packets, args.manifest, args.stage, workers)
    text = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.write_text(text, encoding="utf-8", newline="\n")
    print(json.dumps({"status": report["status"], "errors": report["errors"][:40],
                      "runs": [p["runs"] for p in report["packets"]]}, indent=2))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
