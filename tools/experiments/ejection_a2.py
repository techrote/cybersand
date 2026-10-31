"""A2 identities and bounded stratified evidence; frozen B/C semantics are imported.

The complete scientific-input identity deliberately distinguishes exact geometry.
A separate discrete topology signature prevents interpreting pose-only splits as
new cell layouts. Neither identity includes scheduling epochs or owner serials.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import copy
import hashlib
import json
import math
from pathlib import Path
import struct

import ejection_topology as topology
import ejection_push_chain as oracle

BASE = "7e04e8fde1496c5f32d3f83099ec2a6bfb6bb7d6"
SEED = "cybersand-physical-detachment-a2-v1"
EVENT_LIMIT = 8192
STRATUM_SLOTS = 24
PHASES = ("early", "middle", "late")
DEPTHS = ("shallow", "moderate", "deep")
SECTORS = ("right", "down", "left", "up")
REASONS = ("accepted", "bounds", "source_body", "foreign_body", "non_empty",
           "path_hard", "path_foreign", "path_bounds")


def digest(value):
    return topology.canonical_hash(value)


def sign(value):
    return (value > 0) - (value < 0)


def exact(value):
    value = float(value)
    if not math.isfinite(value):
        raise ValueError("nonfinite geometry")
    return (0.0 if value == 0 else value).hex()


def projection(capsule, structural=False):
    grid = topology.Grid(capsule)
    sx, sy = grid.source
    rows = []
    for index, row in enumerate(grid.cells):
        x, y = grid.left + index % grid.width, grid.top + index // grid.width
        body = 0 if row[4] == 0 else 1 if row[4] == grid.body_id else 2
        cell = [x-sx, y-sy, grid.in_world((x, y)), int(row[0]), bool(row[5]), bool(row[6]), body]
        if not structural:
            # Epoch is a scheduling mark, not persistent material state. Empty
            # thermal/payload values never affect B or C scientific outcomes.
            cell += ([int(row[1]), int(row[2]), int(row[3]), int(row[7]),
                      f"{int(row[8], 16) & ((1 << 56)-1):014x}"] if row[0] else [None])
        rows.append(cell)
    result = {"schema": "a2-structural-v1" if structural else "a2-scientific-v1",
              "source": list(grid.source), "world_bounds": list(grid.world_bounds),
              "bounds_relative": [grid.left-sx, grid.top-sy, grid.width, grid.height],
              "search": [capsule["first_distance"], capsule["maximum_distance"], capsule["tangent_probes"]],
              "candidates": [[x-sx, y-sy] for x, y in topology.enumerate_candidates(capsule)],
              "cells": rows, "baseline_target": [int(v) for v in capsule["target"]]}
    if structural:
        result.pop("source")
        result["baseline_target"] = ([int(capsule["target"][0])-sx, int(capsule["target"][1])-sy]
                                     if capsule["target"][0] >= 0 else None)
        # Coarse scientific decisions, not exact angle magnitudes. Endpoint dot
        # signs are essential: the lateral sector extends beyond 90 degrees.
        directions = []
        for x, y in grid.points(ring=True):
            delta = x-sx, y-sy
            if delta == (0, 0):
                directions.append([0, 0, "source", 0])
            else:
                v = topology.void_geometry(grid, (x, y), set(), set())
                directions.append([*delta, v["sector"], sign(v["dot"])])
        result["cell_direction_classes"] = directions
        result["hop_signs"] = [sign(grid.normal[0]*dx+grid.normal[1]*dy) for dx, dy in topology.DIRECTIONS]
    else:
        body, previous = capsule.get("current_body"), capsule.get("previous_body")
        result.update({"normal": [exact(v) for v in grid.normal],
                       "normal_mode": capsule.get("normal_mode", "unknown"),
                       "current_body": [exact(v) for v in body[1:8]] if body else None,
                       "previous_body": {"valid": bool(previous[11]),
                                         "center": [exact(v) for v in previous[1:3]] if previous[11] else None}
                                        if previous else None,
                       "ambient_temperature": int(capsule.get("ambient_temperature", 200)),
                       "storage_policy": capsule.get("storage_policy", "default_cellular_no_pressure_or_inertial_sidecar")})
    return result


def topology_hash(capsule):
    return digest(projection(capsule))


def structural_hash(capsule):
    return digest(projection(capsule, structural=True))


def production_identity(capsule):
    """Independent fingerprint differential against the ORIGINAL native hash."""
    grid = topology.Grid(capsule)
    data = bytearray()
    trace, consulted = [], set()

    def words(*values):
        for v in values:
            data.extend(struct.pack("<Q", int(v) & ((1 << 64)-1)))

    def read(point):
        consulted.add(point)
        valid = grid.in_world(point)
        words(0, point[0]-grid.source[0], point[1]-grid.source[1], valid)
        if not valid:
            return None
        row = grid.row(point)
        words(row[0] == 0, row[5], 0 if row[4] == 0 else 1 if row[4] == grid.body_id else 2)
        return row

    for p in topology.enumerate_candidates(capsule):
        row = read(p)
        reason = "accepted"
        if row is None:
            reason = "bounds"
        elif row[4]:
            reason = "source_body" if row[4] == grid.body_id else "foreign_body"
        elif row[0]:
            reason = "non_empty"
        else:
            dx, dy = p[0]-grid.source[0], p[1]-grid.source[1]
            samples = max(abs(dx), abs(dy))*2
            for sample in range(1, samples):
                q = (grid.source[0]+math.floor(dx*sample/samples+.5),
                     grid.source[1]+math.floor(dy*sample/samples+.5))
                through = read(q)
                if through is None:
                    reason = "path_bounds"
                elif through[4] not in (0, grid.body_id):
                    reason = "path_foreign"
                elif through[5]:
                    reason = "path_hard"
                if reason != "accepted":
                    break
        words(1, p[0]-grid.source[0], p[1]-grid.source[1], REASONS.index(reason))
        trace.append([*p, reason])
        if reason == "accepted":
            break
    target = trace[-1][:2] if trace[-1][2] == "accepted" else [-1, -1]
    return hashlib.sha256(data).hexdigest(), target, trace, consulted


def stratum(capsule):
    tick = int(capsule["tick"])
    if not 0 <= tick < 600:
        raise ValueError("the preregistered acquisition is exactly 600 ticks")
    phase = PHASES[tick // 200]
    depth = DEPTHS[0 if capsule["penetration"] < 1.5 else 1 if capsule["penetration"] < 3 else 2]
    angle = math.atan2(capsule["normal"][1], capsule["normal"][0])
    sector = SECTORS[int(math.floor((angle+math.pi/4)/(math.pi/2))) % 4]
    return "/".join((phase, depth, sector))


class Reservoir:
    """Seeded bottom-k of unique classes PER stratum; no order-based preference."""
    def __init__(self, slots=STRATUM_SLOTS, seed=SEED):
        if slots < 1:
            raise ValueError("positive quota required")
        self.slots, self.seed = slots, seed
        self.members = defaultdict(dict)
        self.seen = defaultdict(set)
        self.events = Counter()
        self.replacements = Counter()
        self.drops = Counter()

    def score(self, key, identity):
        return hashlib.sha256((self.seed+"\0"+key+"\0"+identity).encode()).hexdigest()

    def add(self, key, identity):
        self.events[key] += 1
        if identity in self.seen[key]:
            return
        self.seen[key].add(identity)
        members = self.members[key]
        score = self.score(key, identity)
        if len(members) < self.slots:
            members[identity] = score
        else:
            worst = max(members, key=lambda h: (members[h], h))
            if (score, identity) < (members[worst], worst):
                del members[worst]
                members[identity] = score
                self.replacements[key] += 1
            else:
                self.drops[key] += 1

    def selected(self):
        return set().union(*(set(v) for v in self.members.values())) if self.members else set()

    def report(self):
        out = {}
        for phase in PHASES:
            for depth in DEPTHS:
                for sector in SECTORS:
                    key = "/".join((phase, depth, sector))
                    members = self.members[key]
                    out[key] = {"events": self.events[key], "unique_classes": len(self.seen[key]),
                                "retained": len(members), "replacements": self.replacements[key],
                                "priority_drops": self.drops[key],
                                "score_threshold": max(members.values()) if members else None,
                                "members": sorted(members)}
        return out


def build_corpus(events, acquisition):
    if not acquisition.get("complete") or acquisition["native_counters"]["dropped"] != 0:
        raise ValueError("incomplete acquisition blocks topology interpretation")
    if len(events) > EVENT_LIMIT or len(events) != acquisition["native_counters"]["attempts"]:
        raise ValueError("event bound/accounting mismatch")
    counters = acquisition["native_counters"]
    if acquisition["fixture"]["ticks"] != 600 or not counters["owner_current"] or counters["stream_emitted"] != len(events):
        raise ValueError("acquisition completion/fencing mismatch")
    fence = (counters["capture_instance_id"], counters["capture_reset_generation"])
    if any((c["instance_id"], c["reset_generation"]) != fence for c in events):
        raise ValueError("mixed acquisition incarnation")
    if acquisition["native_counters"]["relocation_refused"]:
        raise ValueError("relocation refusal needs separate diagnosis before B/C")
    reservoir = Reservoir()
    population, multiplicities, event_strata = {}, Counter(), defaultdict(Counter)
    production_to_topology, production_to_structure = defaultdict(set), defaultdict(set)
    pairs, structures = Counter(), set()
    legacy_order, failed, successes = [], 0, 0
    successful_production, successful_structures = set(), set()
    for ordinal, c in enumerate(events, 1):
        if int(c["event_ordinal"]) != ordinal:
            raise ValueError("stream ordinal gap")
        actual, target, trace, _ = production_identity(c)
        if (actual, target, trace) != (c["replay_hash"], c["target"], c["trace"]):
            raise ValueError("production differential mismatch blocks B/C")
        h, s = topology_hash(c), structural_hash(c)
        key = stratum(c)
        if h not in population:
            population[h] = copy.deepcopy(c)
            population[h]["topology_hash"] = h
            population[h]["structural_hash"] = s
        if population[h]["replay_hash"] != actual:
            raise AssertionError("scientific identity omitted a production decision input")
        multiplicities[h] += 1
        event_strata[h][key] += 1
        pairs[(actual, h)] += 1
        structures.add(s)
        if target[0] < 0:
            failed += 1
            production_to_topology[actual].add(h)
            production_to_structure[actual].add(s)
            if actual not in legacy_order:
                legacy_order.append(actual)
            reservoir.add(key, h)
        else:
            successes += 1
            successful_production.add(actual)
            successful_structures.add(s)
    if failed != acquisition["native_counters"]["searched_no_target"] or successes != acquisition["native_counters"]["target_found"]:
        raise ValueError("outcome accounting mismatch")
    selected = reservoir.selected()
    controls = sorted((h for h, c in population.items() if c["target"][0] >= 0),
                      key=lambda h: reservoir.score("success", h))[:16]
    selected.update(controls)
    all_hashes = sorted(population)
    corpus = {"schema_version": 1, "capsules": [population[h] for h in sorted(selected)],
              "identity": "a2-scientific-v1", "sampling_seed": SEED,
              "qualification_required": "native/fallback exact replay before interpreting frozen B/C"}
    census = {"schema_version": 1, "capsules": [population[h] for h in all_hashes],
              "event_multiplicities": dict(multiplicities),
              "event_strata": {h: dict(v) for h, v in event_strata.items()}}
    stats = {"live_attempts": len(events), "no_target_attempts": failed, "target_found": successes,
             "relocation_refused": acquisition["native_counters"]["relocation_refused"],
             "unique_production_failure_classes": len(production_to_topology),
             "unique_production_success_classes": len(successful_production),
             "unique_structural_success_classes": len(successful_structures),
             "unique_joint_production_topology_classes": len(pairs),
             "unique_topology_failure_classes": sum(c["target"][0] < 0 for c in population.values()),
             "unique_topology_success_classes": sum(c["target"][0] >= 0 for c in population.values()),
             "unique_structural_classes_all_outcomes": len(structures),
             "unique_structural_failure_classes": len(set().union(*production_to_structure.values())),
             "identical_under_both_repeat_events": sum(n-1 for n in pairs.values()),
             "production_failure_classes_splitting_topology": sum(len(v)>1 for v in production_to_topology.values()),
             "production_failure_classes_splitting_structure": sum(len(v)>1 for v in production_to_structure.values()),
             "failure_classes_beyond_one_per_production_hash": sum(len(v)-1 for v in production_to_topology.values()),
             "retained_failures": sum(population[h]["target"][0] < 0 for h in selected),
             "retained_successes": len(controls),
             "retained_positive_event_multiplicity": sum(multiplicities[h] for h in controls),
             "stratum_replacements": sum(reservoir.replacements.values()),
             "stratum_priority_drops": sum(reservoir.drops.values()),
             "native_capacity_drops": acquisition["native_counters"]["dropped_capacity"],
             "first_64_search_classes": legacy_order[:64],
             "production_to_topology_counts": {h: len(v) for h, v in sorted(production_to_topology.items())},
             "production_to_structural_counts": {h: len(v) for h, v in sorted(production_to_structure.items())},
             "strata": reservoir.report(), "sampling_scope": "Detailed union is not an unbiased probability sample; complete finite-run census supplies weighted results."}
    return corpus, census, stats


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, separators=(",", ":"), allow_nan=False)+"\n", encoding="utf-8")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--events", type=Path, required=True)
    p.add_argument("--acquisition", type=Path, required=True)
    p.add_argument("--output-directory", type=Path, required=True)
    args = p.parse_args()
    inputs = [args.events, args.acquisition]
    outputs = [args.output_directory/name for name in ("corpus.json", "population.json", "sampling.json")]
    for output in outputs:
        for source in inputs:
            if output.resolve() == source.resolve() or (output.exists() and source.exists() and output.samefile(source)):
                raise ValueError("output cannot overwrite either frozen input")
    originals = [path.read_bytes() for path in inputs]
    events = [json.loads(line) for line in originals[0].splitlines() if line.strip()]
    if len(events) > EVENT_LIMIT:
        raise ValueError("bounded acquisition exceeded8192 events")
    corpus, census, stats = build_corpus(events, json.loads(originals[1]))
    for path, value in zip(outputs, (corpus, census, stats)):
        write_json(path, value)
    if any(path.read_bytes() != original for path, original in zip(inputs, originals)):
        raise AssertionError("frozen input changed")
    print(json.dumps({k:v for k,v in stats.items() if not isinstance(v, (dict,list))}, sort_keys=True))


if __name__ == "__main__":
    main()
