from pathlib import Path
import csv, json, hashlib, math, statistics
import numpy as np

p = Path(__file__).resolve().parent
read = lambda f: json.loads((p / f).read_bytes())
d = read("workbench-metrics.json")
q = read("sync.json")
packed = read("pose-samples.json")
tr = {
    "rows": [
        [*row[:6], [packed["poses"][j] for j in row[6]]] for row in packed["rows"]
    ],
    "shapes": packed["shapes"],
}
canonical = json.dumps(
    tr, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False
).encode()
assert hashlib.sha256(canonical).hexdigest() == packed["canonical_original_sha256"]
proc = read("physical-process.json")
assert (
    proc["engine_windows_exit"] == proc["collector_exit"] == 0
    and len(q) == 16
    and d["checks"] >= 100
    and not d["failures"]
)
pid, w, h, freq = map(int, (p / "ready.txt").read_text().split())
lo = max(a - s * freq / 1e6 - freq / 1e6 for _, _, a, b, s in q)
hi = min(b - s * freq / 1e6 + freq / 1e6 for _, _, a, b, s in q)
assert lo <= hi and (hi - lo) / freq < 0.04
origin = d["observation_start_usec"]
start = (hi + lo) / 2 + origin * freq / 1e6
elapsed = d["elapsed_usec"] / 1e6
assert (
    d["source_commit"] == proc["source"]
    and elapsed >= 60
    and d["body_count_min"] == d["body_count_max"] == 8
)
rows = [
    {k: int(v) for k, v in r.items()}
    for r in csv.DictReader((p / "visible.csv").open())
]
raw = [r for r in rows if r["phase"] == 2 and r["desktop_qpc"] > 0]
static = [r for r in rows if r["phase"] == 1 and r["changed_pixels"] >= 0]
assert static and max(r["changed_pixels"] for r in static) == 0
timestamps = [r["desktop_qpc"] for r in raw if r["changed_pixels"] > 0]
area = w * h
crop = np.array(d["static_visible_control"]["world_rect"], dtype=float)
lower = crop[:2] + 2
upper = crop[:2] + crop[2:] - 2
zoom = np.array([w, h]) / crop[2:]
shape_points = {}
for k, sh in tr["shapes"].items():
    ids = np.asarray(sh["occupied"])
    shape_points[k] = np.column_stack(
        [ids % sh["width"] + 0.5, ids // sh["width"] + 0.5]
    )


def transformed(key, pose):
    c = math.cos(pose[4])
    s = math.sin(pose[4])
    return shape_points[key] @ np.array([[c, s], [-s, c]]) + np.array(pose[2:4])


def interior(a):
    return ((a >= lower) & (a < upper)).all(axis=1)


samples = tr["rows"]
segments = []
prev = {}
for row in samples:
    assert len(row[6]) == 8
    now = {obj[0]: (obj, transformed(obj[0], obj)) for obj in row[6]}
    motions = {}
    if prev:
        for key, (obj, pp) in prev.items():
            if key not in now:
                continue
            obj1, p1 = now[key]
            assert obj1[1] == obj[1]
            mask = interior(pp) & interior(p1)
            if np.any(mask):
                motions[key] = float(
                    np.linalg.norm((p1[mask] - pp[mask]) * zoom, axis=1).max()
                )
        segments.append(
            (
                (last[0] - origin) / 1e6,
                (row[1] - origin) / 1e6,
                motions,
                last[2],
                row[2],
                last[4],
                row[4],
            )
        )
    prev = now
    last = row
motion_amplitudes = {}
references = {}
for row in samples:
    k = int((row[0] - origin) / 1e6)
    m = motion_amplitudes.setdefault(k, {})
    if (row[1] - origin) / 1e6 >= k + 1:
        continue
    for body in row[6]:
        key = body[0]
        points = transformed(key, body)
        entry = (k, key)
        if entry not in references:
            references[entry] = points
            continue
        earliest = references[entry]
        common = interior(earliest) & interior(points)
        if common.any():
            m[key] = max(
                m.get(key, 0.0),
                float(
                    np.linalg.norm(
                        (points[common] - earliest[common]) * zoom, axis=1
                    ).max()
                ),
            )
bins = []
for k in range(math.ceil(elapsed)):
    end = min(k + 1, elapsed)
    if end <= k:
        continue
    valid = [
        r
        for r in raw
        if k <= (r["desktop_qpc"] - start) / freq < end and r["changed_pixels"] >= 0
    ]
    bin_segments = [s for s in segments if s[0] >= k and s[1] < end]
    motion = {}
    for _, _, changes, *_ in bin_segments:
        for key, n in changes.items():
            motion[key] = motion.get(key, 0.0) + n
    bins.append(
        {
            "start_s": k,
            "duration_s": end - k,
            "samples": len(valid),
            "changed": sum(r["changed_pixels"] > 0 for r in valid),
            "above_half_percent": sum(
                r["changed_pixels"] > area * 0.005 for r in valid
            ),
            "accumulated": sum(r["accumulated"] > 1 for r in valid),
            "moving_body_count": sum(n > 0.001 for n in motion.values()),
            "material_motion_over_one_pixel_count": sum(
                n >= 1.0 for n in motion_amplitudes.get(k, {}).values()
            ),
            "max_in_crop_cell_displacement_from_first_pose_px": max(
                motion_amplitudes.get(k, {}).values(), default=0.0
            ),
            "native_tick_delta": sum(s[4] - s[3] for s in bin_segments),
        }
    )


def qv(v):
    return (
        {str(q): float(np.percentile(v, q)) for q in (0, 25, 50, 75, 95, 100)}
        if v
        else {}
    )


def groups(which, metric):
    taken = [b for b in bins if b["duration_s"] == 1.0 and which(b)]
    runs = []
    seq = []
    for b in bins:
        if b in taken and b[metric] < 10:
            seq.append(b["start_s"])
        else:
            if seq:
                runs.append(seq)
            seq = []
    if seq:
        runs.append(seq)
    return {
        "eligible_windows": len(taken),
        "windows_below_ten": sum(b[metric] < 10 for b in taken),
        "max_consecutive_below_ten": max(map(len, runs), default=0),
        "window_rates": qv([b[metric] for b in taken]),
    }


any_rows = [r for r in raw if r["changed_pixels"] >= 0]
gaps = [
    ("startup", start, timestamps[0]),
    *[("between_changes", a, b) for a, b in zip(timestamps, timestamps[1:])],
    ("ending", timestamps[-1], start + freq * elapsed),
]


def gap_info(gap):
    kind, a, b = gap
    # Entire sampled transform pair must fall inside the gap at both extremal clock offsets.
    ga = (a - lo) / freq - origin / 1e6
    gb = (b - hi) / freq - origin / 1e6
    ss = [s for s in segments if s[0] > ga and s[1] < gb]
    maximums = {}
    for _, _, motion, *_ in ss:
        for key, n in motion.items():
            maximums[key] = max(n, maximums.get(key, 0.0))
    return {
        "kind": kind,
        "start_s": (a - start) / freq,
        "duration_s": (b - a) / freq,
        "strictly_interior_sample_pairs": len(ss),
        "unambiguous_moving_bodies": sum(n > 0.001 for n in maximums.values()),
        "max_adjacent_in_crop_displacement_px": max(maximums.values(), default=0.0),
        "native_delta": sum(s[4] - s[3] for s in ss),
        "physics_step_delta": sum(s[6] - s[5] for s in ss),
        "duplicate_outputs": sum(
            a < r["desktop_qpc"] < b and r["changed_pixels"] == 0 for r in raw
        ),
        "merged_outputs": sum(
            a < r["desktop_qpc"] < b and r["accumulated"] > 1 for r in raw
        ),
    }


longest_gaps = [
    gap_info(g) for g in sorted(gaps, key=lambda x: x[2] - x[1], reverse=True)[:30]
]
motion_gap = next(
    (
        v
        for g in sorted(gaps, key=lambda x: x[2] - x[1], reverse=True)
        if (v := gap_info(g))["unambiguous_moving_bodies"] > 0
    ),
    None,
)
out = {
    "motion_measure": "Matching occupied cell centers at least two world cells inside crop. Moving uses adjacent transforms. One-pixel amplitude uses maximum displacement of any matching cell from first pose in that one-second bin.",
    "longest_gap_with_certain_in_crop_motion": motion_gap,
    "source": d["source_commit"],
    "candidate_artifact": 15176676582,
    "runtime_sha256": "78a5481193d6379ce8f36689aedc521f3b0d79fd17a2a88815f5c49e737bdce9",
    "test_checks": d["checks"],
    "pid": pid,
    "elapsed_s": elapsed,
    "physical_control": {
        "paused_pairs": len(static),
        "paused_changed": 0,
        "invalid_or_occluded": sum(r["changed_pixels"] == -2 for r in rows),
        "accumulated_multi": sum(r["accumulated"] > 1 for r in rows),
        "clock_uncertainty_ms": (hi - lo) * 1000 / freq,
        "observed_poses": len(samples),
        "client_crop": d["static_visible_control"]["client_rect"],
        "world_crop": crop.tolist(),
    },
    "ticks_s": d["semantic_ticks_per_wall_second"],
    "native_ticks": d["completed_semantic_ticks"],
    "rapier_steps": d["actual_physics_steps"],
    "changed_crops_s": len(timestamps) / elapsed,
    "half_percent_changed_crops_s": sum(r["changed_pixels"] > area * 0.005 for r in raw)
    / elapsed,
    "full_windows_any_in_crop_motion": groups(
        lambda b: b["moving_body_count"] > 0, "changed"
    ),
    "full_windows_material_motion_ge_1px": groups(
        lambda b: b["material_motion_over_one_pixel_count"] > 0, "changed"
    ),
    "full_windows_all_eight_ge_1px": groups(
        lambda b: b["material_motion_over_one_pixel_count"] == 8, "changed"
    ),
    "full_windows_any_motion_half_percent_crop": groups(
        lambda b: b["moving_body_count"] > 0, "above_half_percent"
    ),
    "startup": gap_info(gaps[0]),
    "longest_gaps": longest_gaps,
    "bins": bins,
    "hashes": {
        n: hashlib.sha256((p / n).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        for n in ("visible.csv", "sync.json", "physical-process.json")
    },
}
expected = read("results.json")
expected["hashes"] = expected.pop("retained_input_normalized_sha256")
assert out == expected, "Reconstructed motion/co-timed visible receipt differs"
print(
    "Verified all 60 full one-second windows, startup, final settling, crop counters and eight-body identities."
)
