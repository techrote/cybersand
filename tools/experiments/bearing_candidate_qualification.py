"""Mandatory custody/neutrality guards for the frozen bearing experiment.

These checks implement already registered prerequisites. They do not define or
change an efficacy outcome, threshold, candidate, or physical intervention.
"""
from __future__ import annotations

import ast
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess

from granular_bearing_analysis import neutral


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def conserved_counts(expected, actual, water_material=None):
    """Water may redistribute quantity into more carriers; other matter cannot."""
    if len(expected) != len(actual):
        return False
    ignored = {0, water_material} if water_material is not None else set()
    return all(a == b for i, (a, b) in enumerate(zip(expected, actual)) if i not in ignored)


def physical_gaps_complete(frame):
    # Apply the addendum to every predicted hit, even when other boundaries
    # already have current-pose support. Hover still uses its registered total
    # current_support==0 condition; missing observations cannot qualify safety.
    for ray in frame.get("bearing", {}).get("admissions", []):
        selected = ray["selected"]
        if selected >= 0 and ray["steps"][selected][2] > 0 and ray["geometric_lower"] is None:
            raise ValueError("positive-offset support has unknown physical gap; safety unqualified")


def custody(directory):
    directory = Path(directory)
    receipt = read(directory / "receipt.json")
    acquisition = read(directory / "acquisition.json")
    population = read(directory / "population-manifest.json")
    trajectory = read(directory / "trajectory.json")
    required = {"acquisition.json", "population-manifest.json", "trajectory.json"}
    for part in population["parts"]:
        required.update((part["path"], part["path"].replace("capsules-", "replay-")))
    hashes = receipt.get("artifact_sha256", {})
    if not required.issubset(hashes):
        raise ValueError("unsealed required acquisition artifact")
    for name, expected in hashes.items():
        if sha(directory / name) != expected:
            raise ValueError("frozen acquisition artifact changed: " + name)
    if not receipt.get("ok") or not acquisition["complete"]:
        raise ValueError("qualified complete acquisition required")
    counters = acquisition["native_counters"]
    count = population["attempts"]
    if (counters["dropped"] or counters["relocation_refused"] or
            counters["attempts"] != count or receipt["attempts"] != count or
            receipt["replay_matches"] != count):
        raise ValueError("capture/replay accounting failure")
    matched = 0
    for part in population["parts"]:
        report = read(directory / part["path"].replace("capsules-", "replay-"))
        if (not report["ok"] or report["mutation_failures"] or
                report["matched"] != part["capsules"] or
                report["input_sha256"] != part["sha256"] or
                hashes[part["path"]] != part["sha256"] or
                report["source_revision"] != receipt["source"] or
                report["candidate"] != receipt["candidate"]):
            raise ValueError("unqualified replay part")
        matched += report["matched"]
    if matched != count:
        raise ValueError("incomplete replay population")
    frames = trajectory["frames"]
    if len(frames) != 600 or [f["tick"] for f in frames] != list(range(600)):
        raise ValueError("complete ordered600-frame record required")
    expected = frames[0]["stored_counts"]
    mass = frames[0]["stored_water_mass"]
    arm = acquisition["fixture"]["name"]
    water = acquisition["fixture"]["bank_material"] if arm == "water" else None
    for f in frames:
        physical_gaps_complete(f)
        if arm == "excavation" and f["tick"] == 300:
            expected = acquisition["excavation"]["after_counts"]
            mass = acquisition["excavation"]["after_water"]
        if not conserved_counts(expected, f["stored_counts"], water):
            raise ValueError("material conservation failure, including nonWater carriers")
        if any(f[key] != mass for key in ("stored_water_mass", "pre_water_mass", "post_water_mass")):
            raise ValueError("authoritative quantity conservation failure")
    return receipt, acquisition, population, trajectory


def identity(receipt):
    keys = ("source", "tree", "runtime", "compiled_inputs", "source_inputs", "successful_build_receipt_sha256")
    return json.dumps({k: receipt[k] for k in keys}, sort_keys=True)


def paired(root, mode, arm):
    paths = [Path(root) / (mode + "-" + arm + "-" + details) for details in ("on", "off")]
    if not all((p / "receipt.json").is_file() for p in paths):
        raise ValueError("mandatory qualified diagnostic-on/off pair missing")
    a, b = [custody(p) for p in paths]
    for (receipt, acquisition, population, trajectory), details in zip((a, b), (True, False)):
        if (receipt["candidate"] != mode or receipt["arm"] != arm or
                receipt["details"] != ("on" if details else "off") or
                acquisition["candidate"] != mode or acquisition["fixture"]["name"] != arm or
                acquisition["details"] != details or trajectory["details"] != details or
                population["candidate"] != mode):
            raise ValueError("candidate/fixture/details identity mismatch")
    if identity(a[0]) != identity(b[0]):
        raise ValueError("paired source/runtime/input identity mismatch")
    if not neutral(a[3], b[3]):
        raise ValueError("diagnostic-on/off physical drift")
    extra = ("stored_water_mass", "pre_water_mass", "post_water_mass", "candidate_metrics")
    if any(x[k] != y[k] for x, y in zip(a[3]["frames"], b[3]["frames"]) for k in extra):
        raise ValueError("diagnostic-on/off quantity/work drift")
    if (a[2]["events"] != b[2]["events"] or
            a[2]["event_multiplicities"] != b[2]["event_multiplicities"]):
        raise ValueError("diagnostic-on/off capsule population drift")
    return {"pass": True, "source": a[0]["source"], "runtime": a[0]["runtime"],
            "attempts_each": a[2]["attempts"], "frames_each": 600,
            "exact_capsule_parts_equal": a[2]["parts"] == b[2]["parts"],
            "raw_part_equality_note": "Descriptive stronger evidence; volatile owner provenance need not define physical equivalence.",
            "conservation_failures": 0,
            "receipt_sha256": {details: sha(p / "receipt.json") for p, details in zip(paths, ("on", "off"))}}


def latency(values):
    if not values:
        return {"count": 0, "p50": None, "p95": None, "max": None}
    return {"count": len(values), "p50": statistics.median(values),
            "p95": sorted(values)[math.ceil(.95 * len(values)) - 1], "max": max(values)}


def metric_bodies(source):
    """Ignore locations/comments, retain every measured helper and decision law."""
    return {node.name: hashlib.sha256(ast.dump(node, include_attributes=False).encode()).hexdigest()
            for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name != "campaign"}


def frozen_definitions(receipt):
    root = Path(__file__).resolve().parents[2]
    relative = "tools/experiments/bearing_candidate_analysis.py"
    command = ["git", "-C", str(root), "show", receipt["source"] + ":" + relative]
    original = subprocess.check_output(command, timeout=30)
    if hashlib.sha256(original).hexdigest() != receipt["source_inputs"][relative]:
        raise ValueError("frozen metric source custody mismatch")
    old, current = metric_bodies(original.decode("utf-8")), metric_bodies((root/relative).read_text(encoding="utf-8"))
    if old != current:
        raise ValueError("post-acquisition metric/threshold helper change")
    protocol = "docs/audits/granular-bearing-candidates-2026-11-01/protocol.json"
    registered = subprocess.check_output(["git", "-C", str(root), "show", "69076bf2:" + protocol], timeout=30)
    if hashlib.sha256(registered).hexdigest() != receipt["source_inputs"][protocol] or registered != (root/protocol).read_bytes():
        raise ValueError("preregistration drift")
    return {"measured_source": receipt["source"], "registration": "69076bf2",
            "protocol_sha256": hashlib.sha256(registered).hexdigest(), "unchanged_metric_bodies": old,
            "meaning": "All original metric/decision helper ASTs and preregistration bytes unchanged; campaign adds prerequisite enforcement only."}


def descriptive_work(directory):
    frames = read(Path(directory) / "trajectory.json")["frames"]
    metrics = [f["candidate_metrics"] for f in frames]
    result = {key: {"total": sum(m[key] for m in metrics), "maximum_per_body_sample": max(m[key] for m in metrics)}
              for key in ("boundaries", "cell_tests", "predicate_queries", "extra_cells")}
    result["callback_usec_all"] = latency([f["coupling_usec"] for f in frames])
    result["callback_usec_bearing_active"] = latency([f["coupling_usec"] for f in frames if f["bearing"]["bearing_y"]])
    # Descriptive repeated-boundary acceleration. The frozen within-application
    # artificial-lift gate remains in bearing_candidate_analysis.settling.
    streak = maximum = 0
    for previous, f in zip(frames, frames[1:]):
        flag = (f["body_input"][7] < 0 and previous["body_input"][7] < 0 and
                f["candidate_metrics"]["current_support"] == 0 and
                f["after_application"][4] < previous["after_application"][4] - .05)
        streak = streak + 1 if flag else 0
        maximum = max(maximum, streak)
    result["descriptive_unsupported_net_upward_acceleration_longest"] = maximum
    return result


def qualify(root):
    result = {"schema": 1, "pairs": {}, "work": {},
              "validator_sha256": sha(__file__),
              "classification_module_sha256": sha(Path(__file__).with_name("bearing_candidate_analysis.py"))}
    identities = set()
    for mode in ("B0", "Y1", "A2"):
        for arm in ("speed0", "speed30", "speed90", "excavation", "hard", "water"):
            key = mode + "-" + arm
            result["pairs"][key] = paired(root, mode, arm)
            result["work"][key] = descriptive_work(Path(root) / (key + "-on"))
            identities.add(identity(read(Path(root) / (key + "-on") / "receipt.json")))
    if len(identities) != 1:
        raise ValueError("entire campaign requires exact common source/runtime/inputs")
    result["frozen_definitions"] = frozen_definitions(read(Path(root)/"B0-speed0-on"/"receipt.json"))
    result["pass"] = True
    result["meaning"] = "Registered custody, all36 captures/replays, all18 on/off pairs and material prerequisites; efficacy/safety thresholds unchanged."
    return result
