"""Literal accounting of copied bridge values; never imports a simulation API.

Rapier stepping is an observed boundary, not reconstructed force integration.
Vector2 storage/addition uses the pinned single-precision runtime's float32.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
CAMPAIGN = ROOT / "docs/audits/granular-bearing-candidates-2026-11-01/campaign"
EPSILON_SQUARED = 0.000001
MAX_CORRECTION_AGE = 1


def f32(value):
    return struct.unpack("f", struct.pack("f", value))[0]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8", newline="\n")


def account(frame, following=None):
    """Return residuals and literal handoff, using only retained copied values."""
    details = frame["application_details"]
    if len(details) != 1:
        raise ValueError("one accepted mass-one body application required")
    d = details[0]
    before = d["before"]
    correction = d["requested_correction"] if d["age"] <= MAX_CORRECTION_AGE else [0, 0]
    active = f32(f32(correction[0]**2) + f32(correction[1]**2)) > EPSILON_SQUARED
    applied = correction if active else [0, 0]
    corrected = list(before)
    for axis in range(2):
        corrected[axis] = f32(before[axis] + applied[axis])
        if active and applied[axis] != 0 and before[3+axis] * applied[axis] < 0:
            corrected[3+axis] = 0.0
    scale = 1 / (1 + d["age"] * 0.25)
    impulse = [f32(x * scale) for x in d["requested_impulse"]]
    outgoing = list(corrected)
    if f32(f32(impulse[0]**2) + f32(impulse[1]**2)) > EPSILON_SQUARED:
        for axis in range(2):
            outgoing[3+axis] = f32(corrected[3+axis] + impulse[axis])  # retained mass=1
    def residual(a, b):
        return max(abs(x-y) for x, y in zip(a, b))
    residuals = {
        "post_rapier_to_application": residual(frame["after_step"], before),
        "applied_correction": residual(applied, d["applied_correction"]),
        "correction_age_suppressed": float(d["correction_age_suppressed"] != (d["age"] > MAX_CORRECTION_AGE)),
        "age_scale": abs(scale - d["impulse_age_scale"]),
        "after_correction": residual(corrected, d["after_correction"]),
        "after_impulse": residual(outgoing, d["after_impulse"]),
        "post_application": residual(outgoing, frame["after_application"]),
        "result_impulse": residual(d["requested_impulse"], frame["requested_results"][1:3]),
        "result_correction": residual(d["requested_correction"], frame["requested_results"][3:5]),
    }
    if following is not None:
        residuals["next_pre_rapier"] = residual(frame["after_application"], following["before_step"])
    return {
        "tick": frame["tick"], "candidate": frame["candidate"], "before_step": frame["before_step"],
        "after_step": frame["after_step"], "requested_correction": d["requested_correction"],
        "applied_correction": d["applied_correction"], "after_correction": d["after_correction"],
        "requested_impulse": d["requested_impulse"], "age": d["age"], "age_scale": scale,
        "after_impulse": d["after_impulse"], "after_application": frame["after_application"],
        "next_before_step": following["before_step"] if following else None,
        "next_after_step": following["after_step"] if following else None,
        "next_boundary_missing": following is None,
        "pre_overlap": frame["geometry"]["pre_overlap"],
        "post_ejection_overlap": frame["geometry"]["post_ejection_overlap"],
        "post_tick_overlap": frame["geometry"]["post_tick_overlap_at_packed_pose"],
        "raw_support": frame["bearing"]["raw_support"],
        "bearing": {k: frame["bearing"][k] for k in ("arrest", "yield", "capacity", "bearing_y")},
        "zeroed_components": [i for i in range(2) if active and applied[i] * before[3+i] < 0],
        "unrounded_position_residual": max(abs(d["after_correction"][i] - (before[i]+applied[i])) for i in range(2)),
        "residuals": residuals,
    }


def oracle(directory=CAMPAIGN / "Y1-speed90-on"):
    directory = Path(directory)
    trajectory = directory / "trajectory.json"
    frames = json.loads(trajectory.read_text())["frames"]
    rows = [account(frames[i], frames[i+1] if i+1 < len(frames) else None)
            for i in list(range(300, 322)) + list(range(580, 600))]
    maximum = {k: max(r["residuals"].get(k, 0) for r in rows) for k in rows[0]["residuals"]}
    populations = {name: dict(Counter(str(r[field][4]) for r in rows)) for name, field in
                   (("incoming_vy", "after_step"), ("after_zeroing_vy", "after_correction"), ("outgoing_vy", "after_impulse"))}
    pairs = []
    for start, stop in ((300, 320), (580, 598)):
        for i in range(start, stop+1, 2):
            pair = frames[i:i+2]
            pairs.append({"ticks": [i, i+1], "incoming_vy": [f["after_step"][4] for f in pair],
                          "after_zeroing_vy": [f["application_details"][0]["after_correction"][4] for f in pair],
                          "outgoing_vy": [f["after_application"][4] for f in pair]})
    return {"schema": 1, "stage": "A", "parent_head": "064a3306dc3a87c3a88172003e42c8e426cb73e1",
            "measured_source": "39d91671c1d0bb7978a29460f14419cd1b37a252",
            "trajectory_sha256": sha(trajectory), "receipt_sha256": sha(directory / "receipt.json"),
            "scope": "Copied mass-one bridge accounting only; Rapier transitions observed, no inferred forces.",
            "rounding": "float32 Vector2 sums/products; no fitted coefficient or expected cycle velocities",
            "tolerance": 0, "maximum_residuals": maximum,
            "maximum_unrounded_position_residual": max(r["unrounded_position_residual"] for r in rows),
            "pass": all(v == 0 for v in maximum.values()), "populations": populations, "pairs": pairs, "rows": rows,
            "missing_observation": "PR341 ends at599: next600 pre/post Rapier unavailable; no value inferred. Sample598->599 closes."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = oracle()
    write(args.output, result)
    print(json.dumps({k: result[k] for k in ("pass", "tolerance", "maximum_residuals", "maximum_unrounded_position_residual", "populations")}))
    raise SystemExit(0 if result["pass"] else 1)
