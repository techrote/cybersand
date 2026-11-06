#!/usr/bin/env python3
"""Adversarial readback of original HS-PKT workload receipts.

This is an execution completeness/identity verifier, *not* a speedup threshold.
It independently examines every arm and refuses a green result if any hard
packet, actor, gas, ballistic, or source/runtime identity assertion is missing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ARMS = ("A-control", "B-candidate", "B2-candidate", "A2-control")
CANVASES = ("my-canvas", "stress-canvas")
SCHEMA = "hs-pkt-active-workbench-v1"
RAPIER_SHA = "566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a"


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError(reason)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(root: Path, control: str, candidate: str) -> dict:
    manifest = root / "native-binary.sha256"
    require(manifest.is_file(), "original built runtime hash record absent")
    hashes = {}
    for line in manifest.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        require(len(parts) == 2 and len(parts[0]) == 64, "invalid native hash record")
        if parts[1].endswith("hs-control.so"):
            hashes["control"] = parts[0]
        elif parts[1].endswith("hs-candidate.so"):
            hashes["candidate"] = parts[0]
        else:
            raise ValueError(f"unrecognized build artifact in manifest: {parts[1]}")
    require(set(hashes) == {"control", "candidate"}, "missing parent/candidate build hash")
    require(hashes["control"] != hashes["candidate"], "different source arms reused same binary")

    identities = {"control": control, "candidate": candidate}
    output = []
    raw_log_hashes = {}
    for arm in ARMS:
        side = "control" if "control" in arm else "candidate"
        path = root / f"{arm}.log"
        require(path.is_file(), f"{arm}: missing original Godot execution log")
        raw_log_hashes[arm] = digest(path)
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        require(not any("HS_ACTIVE_PROFILE_FAILURES " in line for line in lines),
                f"{arm}: source process reported failed assertions")
        require(any("HS_ACTIVE_PROFILE_COMPLETE 2/2 workload canvases qualified" in line
                    for line in lines), f"{arm}: no complete-workload marker")
        reports = []
        for line in lines:
            marker = "HS_ACTIVE_PROFILE "
            if marker not in line:
                continue
            payload = line.split(marker, 1)[1].strip()
            if not payload.startswith("{"):
                continue
            reports.append(json.loads(payload))
        require(len(reports) == 2, f"{arm}: expected two full workload reports, got {len(reports)}")
        require([r.get("canvas") for r in reports] == list(CANVASES),
                f"{arm}: missing, duplicated or out-of-order canvas")
        for r in reports:
            canvas = r["canvas"]
            where = f"{arm}/{canvas}"
            require(r.get("schema") == SCHEMA, f"{where}: unknown workload schema")
            require(r.get("source_sha") == identities[side], f"{where}: source mismatch")
            runtime = r.get("runtime", {})
            require(runtime.get("os") == "Linux", f"{where}: wrong OS")
            require(runtime.get("native_sha256") == hashes[side],
                    f"{where}: actual loaded DLL differs from independently built artifact")
            require(runtime.get("rapier_sha256") == RAPIER_SHA,
                    f"{where}: Rapier differs from selected runtime pin")
            require(r.get("requested_sample_ticks") == 240 and r.get("warmup_ticks") == 24,
                    f"{where}: unequal workload duration")
            require(r.get("observed_snapshots", 0) >= 100,
                    f"{where}: incomplete worker observations")
            require(r.get("accepted_edit_requests", 0) >= 45,
                    f"{where}: too few accepted hard/erase brush edits")
            require(r.get("observed_hard_revision_changes", 0) >= 35,
                    f"{where}: edits did not produce sufficient actual native hard revisions")
            require(r.get("packet", {}).get("samples", 0) >= 40,
                    f"{where}: insufficient executed collider packet measurements")
            require(r.get("actors_requested", 0) >= 2
                    and r.get("actual_actor_steps", 0) > 20
                    and r.get("observed_actor_samples", 0) > 20,
                    f"{where}: real Rapier actor coupling not evidenced")
            pressure = r.get("pressure", {})
            require(pressure.get("family") == "pressure_flow_v1"
                    and pressure.get("variant") == "cached_dormant"
                    and pressure.get("gas_enabled") is True
                    and pressure.get("policy_hash"),
                    f"{where}: actual applied PressureFlow gas variant not established")
            require(r.get("ballistic_enabled") is True and r.get("spray_enabled") is True
                    and r.get("jet_enabled") is True,
                    f"{where}: opt-in ballistic Water + spray/jet not applied")
            ledger = r.get("ballistic_ledger", {})
            require(ledger.get("launched_parcels", 0) + ledger.get("injected_parcels", 0) > 0,
                    f"{where}: no actual native ballistic launches or injections")
            for key in ("packet", "simulation", "render_exchange", "snapshot_publication"):
                measurement = r.get(key, {})
                require(measurement.get("samples", 0) >= (40 if key == "packet" else 1)
                        and measurement.get("mean_ms", -1) >= 0.0
                        and measurement.get("p50_ms", -1) >= 0.0
                        and measurement.get("p95_ms", -1) >= 0.0,
                        f"{where}: malformed executed {key} distribution")
            output.append({"arm": arm, **r})

    # A and B are the same hardware/toolchain, not cherry-picked hosts.
    hosts = {(
        p["runtime"]["cpu"], p["runtime"]["godot"], p["runtime"]["rapier_sha256"]
    ) for p in output}
    require(len(hosts) == 1, "arm hardware, Godot or Rapier runtime identity drift")

    comparisons = []
    for canvas in CANVASES:
        controls = [r for r in output if r["canvas"] == canvas and "control" in r["arm"]]
        candidates = [r for r in output if r["canvas"] == canvas and "candidate" in r["arm"]]
        require(len(controls) == len(candidates) == 2,
                f"{canvas}: A/B/B/A is not complete")
        control_median = sum(r["packet"]["p50_ms"] for r in controls) / 2.0
        candidate_median = sum(r["packet"]["p50_ms"] for r in candidates) / 2.0
        comparisons.append({
            "canvas": canvas,
            "control_packet_median_ms": control_median,
            "candidate_packet_median_ms": candidate_median,
            "packet_median_speedup": (control_median / candidate_median if candidate_median > 0 else None),
            "control_packet_samples": [r["packet"]["samples"] for r in controls],
            "candidate_packet_samples": [r["packet"]["samples"] for r in candidates],
            "control_simulation_p50_ms": [r["simulation"]["p50_ms"] for r in controls],
            "candidate_simulation_p50_ms": [r["simulation"]["p50_ms"] for r in candidates],
        })
    return {
        "schema": "hs-pkt-active-abba-v1",
        "status": "passed",
        "scope": "candidate/nonrelease; native source arms unchanged; Godot diagnostic overlay identical",
        "control_sha": control,
        "candidate_sha": candidate,
        "runtime_sha256": hashes,
        "raw_log_sha256": raw_log_hashes,
        "comparisons": comparisons,
        "profiles": output,
        "release_provenance_qualified": False,
        "integration_merge_authorized": False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--control", required=True)
    parser.add_argument("--candidate", required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        record = read(root, args.control, args.candidate)
    except Exception as error:
        (root / "active-readback-failure.txt").write_text(
            f"{type(error).__name__}: {error}\n", encoding="utf-8"
        )
        raise
    (root / "active-abba-verified.json").write_text(
        json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    for result in record["comparisons"]:
        print("HS_ACTIVE_ABBA_COMPARE " + json.dumps(result, sort_keys=True))
    print("HS_ACTIVE_ABBA_VERIFIED 8/8 source-pinned traces and all workload gates")


if __name__ == "__main__":
    main()
