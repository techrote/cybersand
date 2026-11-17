#!/usr/bin/env python3
"""Independent raw-evidence audit. Does not import the producer or view images.

The digest implementation follows the public serialized protocol. Geometry,
counts, source identity and actual join paths are independently recomputed from
retained native arrays; no generator or meshing code is executed by this audit.
"""
from __future__ import annotations
import argparse
from collections import Counter, deque
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct
import time

MASK = (1 << 64) - 1
OFFSET = 14695981039346656037
PRIME = 1099511628211
KINDS = {"FRAMEWEAVER": 0, "MOSAIC": 1, "RECEPTOR": 2}
FAMILIES = {"frame": 0, "brace": 1, "surface": 2, "passage": 3}
STATUSES = {"complete": 0, "blocked": 1, "exhausted": 2, "unsat": 3, "invalid": 4, "damaged": 5}
GROUP_COUNTS = {"frameweaver_solo":20,"mosaic_solo":15,"receptor_solo":10,"frameweaver_mosaic":25,"frameweaver_receptor":15,"mosaic_receptor":10,"pathological":5}


class Hash:
    def __init__(self): self.value = OFFSET
    def word(self, n):
        n = int(n) & MASK
        v = self.value
        for _ in range(8):
            v = ((v ^ (n & 255)) * PRIME) & MASK
            n >>= 8
        self.value = v
    def string(self, s):
        b = s.encode("utf-8")
        self.word(len(b))
        for c in b: self.value = ((self.value ^ c) * PRIME) & MASK
    def point(self, p):
        self.word(p[0]); self.word(p[1])
    def floating(self, n): self.word(struct.unpack("<Q", struct.pack("<d", n))[0])
    def words(self, values, size=False):
        if size: self.word(len(values))
        for v in values: self.word(v)
    def offer(self, a):
        self.word(a["id"]); self.word(a["instance"])
        for k in ("a", "b", "facing"): self.point(a[k])
        self.word(FAMILIES[a["family"]]); self.word(a["required"])
        self.floating(a["strength"]); self.string(a["tag"])
    def soft(self, a):
        self.point(a["point"]); self.point(a["direction"])
        self.floating(a["strength"]); self.string(a["preference"])
    def hex(self): return f"{self.value:016x}"


def mix(v):
    v = (v + 0x9e3779b97f4a7c15) & MASK
    v = ((v ^ (v >> 30)) * 0xbf58476d1ce4e5b9) & MASK
    v = ((v ^ (v >> 27)) * 0x94d049bb133111eb) & MASK
    return v ^ (v >> 31)


def request_digest(q):
    h = Hash()
    h.word(KINDS[q["gentek"]]); h.word(q["version"])
    h.string(q["definition"]); h.string(q["source"])
    h.word(q["seed"]); h.string(q["fixture"])
    h.word(q["width"]); h.word(q["height"]); h.point(q["origin"])
    for vals in (q["eligible"], q["protected"], q["transition"], q["neighbors"]["protected"], q["neighbors"]["transition"]): h.words(vals, True)
    for k in ("context", "neighbor_cells"): h.words(q[k], True)
    h.word(len(q["activation"]))
    for p in q["activation"]: h.point(p)
    h.word(len(q["neighbors"]["hard"]))
    for a in q["neighbors"]["hard"]: h.offer(a)
    h.word(len(q["neighbors"]["soft"]))
    for a in q["neighbors"]["soft"]: h.soft(a)
    h.string(q["profile"]["name"])
    for k in ("variation", "irregularity", "clutter", "destruction", "branching", "environment_affinity", "cohesion"): h.floating(q["profile"][k])
    for k in ("instances", "frontier", "candidates", "connectors_per_instance", "affordances", "cohesion_patches", "cohesion_cells_per_patch", "work", "solver_work", "bytes"): h.word(q["limits"][k])
    return h.hex()


def material_digest(r):
    h = Hash(); h.word(r["width"]); h.word(r["height"])
    h.words(r["cells"])
    return h.hex()


def semantic_digest(r):
    h = Hash()
    h.word(int(r["request_digest"], 16)); h.word(int(r["material_digest"], 16)); h.string(r["implementation"])
    h.word(STATUSES[r["status"]]); h.string(r["termination"])
    for k in ("work", "candidates", "solver_work"): h.word(r[k] or 0)
    for role, owner in zip(r["roles"], r["provenance"]): h.word(role); h.word(owner)
    for p in r["instances"]:
        h.word(p["id"]); h.string(p["kind"]); h.point(p["origin"])
        h.word(p["orientation"]); h.word(p["structural"]); h.word(p["damaged"]); h.string(p["reason"])
        for c in p["cells"]: h.point(c)
    for c in r["connectors"]:
        h.word(c["id"]); h.word(c["instance"]); h.word(FAMILIES[c["family"]])
        for k in ("a", "b", "facing"): h.point(c[k])
        for k in ("required", "fulfilled", "counterpart"): h.word(c[k])
        h.string(c["state"])
    for a in r["attachments"]:
        h.word(a["instance"]); h.point(a["point"]); h.point(a["target"])
        h.string(a["kind"]); h.string(a["reason"])
    for a in r["boundary"]["hard"]: h.offer(a)
    for a in r["boundary"]["soft"]: h.soft(a)
    for k in ("protected", "transition"): h.words(r["boundary"][k], True)
    h.word(r["backtracks"])
    for section in ("metrics", "rejected"):
        for k, v in sorted(r[section].items()): h.string(k); h.word(v)
    for n in r["notes"]: h.string(n)
    return h.hex()


def components(cells, width, height):
    remaining = {i for i, c in enumerate(cells) if c}
    count = 0
    while remaining:
        count += 1; todo = [remaining.pop()]
        while todo:
            i = todo.pop(); x, y = i % width, i // width
            for j, inside in ((i - 1, x > 0), (i + 1, x + 1 < width), (i - width, y > 0), (i + width, y + 1 < height)):
                if inside and j in remaining: remaining.remove(j); todo.append(j)
    return count


def line(a, b):
    p = list(a); out = [tuple(p)]
    dx, dy = abs(b[0] - p[0]), abs(b[1] - p[1])
    sx, sy = (1 if p[0] < b[0] else -1), (1 if p[1] < b[1] else -1)
    ix = iy = 0
    while ix < dx or iy < dy:
        if ix < dx and (iy == dy or (1 + 2 * ix) * dy <= (1 + 2 * iy) * dx): p[0] += sx; ix += 1
        else: p[1] += sy; iy += 1
        out.append(tuple(p))
    return out


class Audit:
    def __init__(self):
        self.counts = Counter(); self.case = ""
    def check(self, condition, message, amount=1):
        self.counts["assertions"] += amount
        if not condition: raise AssertionError(f"{self.case}: {message}")
    def result(self, q, r, label):
        self.counts["result_records"] += 1
        self.counts["statuses_" + r["status"]] += 1
        self.check(r["source"] == q["source"] and r["definition"] == q["definition"], label + " identity")
        self.check(r["gentek"] == q["gentek"] and r["seed"] == q["seed"], label + " request-kind/seed")
        self.check(r["width"] == q["width"] and r["height"] == q["height"], label + " dimensions")
        self.check(r["status"] != "invalid", label + " invalid result")
        w, h = r["width"], r["height"]; n = w * h
        for k in ("eligible", "protected", "transition", "context", "neighbor_cells"):
            self.check(len(q[k]) in (0, n), label + " request array " + k)
        for k in ("protected", "transition"): self.check(len(q["neighbors"][k]) in (0, n), label + " foreign mask " + k)
        for k in ("cells", "roles", "provenance"): self.check(len(r[k]) in (0, n), label + " result array " + k)
        self.check(len(r["cells"]) == len(r["roles"]) == len(r["provenance"]), label + " parallel array lengths")
        self.check(r["work"] <= q["limits"]["work"] and r["candidates"] <= q["limits"]["candidates"], label + " generator budget")
        self.check(len(r["instances"]) <= q["limits"]["instances"], label + " instance limit")
        self.check(all(len(r["boundary"][k]) <= q["limits"]["affordances"] for k in ("hard", "soft")), label + " affordance limits")
        per_instance = Counter(c["instance"] for c in r["connectors"])
        self.check(all(v <= q["limits"]["connectors_per_instance"] for v in per_instance.values()), label + " connector limits")
        m = r["metrics"]
        if m.get("solver_attempted") and not m.get("solver_work_observed"):
            self.check(r["solver_work"] is None, label + " missing solver work fabricated")
            self.check(r["status"] in ("unsat", "exhausted"), label + " unobserved solver outcome")
            self.check(m["solver_work_upper_bound"] == q["limits"]["solver_work"], label + " solver upper bound")
            self.check(not any(r["cells"]), label + " failed solver rasterized partial assignment")
        else: self.check(r["solver_work"] is not None and r["solver_work"] <= q["limits"]["solver_work"], label + " observed solver budget")
        self.check(r["backtracks"] == -1, label + " fabricated backtracking metric")
        if not r["cells"]:
            self.check(r["status"] == "exhausted" and "capacity:" in r["termination"], label + " missing arrays without early capacity refusal")
            self.check(all(r[k] == "0000000000000000" for k in ("request_digest", "material_digest", "digest")), label + " early refusal digest semantics")
            self.counts["capacity_refusals_no_material_arrays"] += 1
            return
        self.check(request_digest(q) == r["request_digest"], label + " request digest")
        self.check(material_digest(r) == r["material_digest"], label + " material digest")
        self.check(semantic_digest(r) == r["digest"], label + " semantic digest")
        self.counts["material_digests"] += 1; self.counts["semantic_digests"] += 1; self.counts["request_digests"] += 1
        owners = {p["id"]: p for p in r["instances"]}
        self.check(len(owners) == len(r["instances"]), label + " duplicate instances")
        connector_ids = [c["id"] for c in r["connectors"]]
        self.check(len(set(connector_ids)) == len(connector_ids), label + " duplicate connector ids")
        boundary_ids = [a["id"] for a in r["boundary"]["hard"]]
        self.check(len(set(boundary_ids)) == len(boundary_ids), label + " duplicate hard offer ids")
        protected = overlaps = occupied = cohesion = structural = transition = eligible = 0
        for i, (material, role, owner) in enumerate(zip(r["cells"], r["roles"], r["provenance"])):
            forbidden_protected = bool(q["protected"] and q["protected"][i]) or bool(q["neighbors"]["protected"] and q["neighbors"]["protected"][i])
            allowed = not forbidden_protected and (not q["eligible"] or q["eligible"][i]) and (not q["context"] or not q["context"][i]) and (not q["neighbor_cells"] or not q["neighbor_cells"][i])
            eligible += bool(allowed)
            self.check(material in range(132) and material != 10, label + " illegal material ID", 1)
            if material:
                occupied += 1; protected += forbidden_protected; overlaps += not allowed
                self.check(not r["boundary"]["protected"][i], label + " material in own exported protected geometry")
                self.check(role in range(1, 6) and owner in owners, label + " material lacks valid role/owner")
                self.check(not (role == 4 and owners[owner]["structural"]), label + " structural cohesion")
                cohesion += role == 4; structural += role in (1, 2, 5); transition += bool(q["transition"] and q["transition"][i])
            else: self.check(role == 0 and owner == 0, label + " empty cell has fabricated provenance")
        self.check(protected == r["protected_violations"] == 0, label + " protected geometry")
        self.check(overlaps == r["illegal_overlaps"] == 0, label + " admitted geometry")
        mandatory = [c for c in r["connectors"] if c["required"]]
        optional = [c for c in r["connectors"] if not c["required"]]
        facts = {"occupied_cells": occupied, "eligible_cells": eligible, "empty_eligible_cells": eligible - occupied,
                 "connected_material_components": components(r["cells"], w, h), "structural_cells": structural,
                 "cohesion_cells": cohesion, "transition_cells": transition, "instances": len(r["instances"]),
                 "mandatory_connectors": len(mandatory), "fulfilled_mandatory_connectors": sum(c["fulfilled"] for c in mandatory),
                 "optional_connectors": len(optional), "fulfilled_optional_connectors": sum(c["fulfilled"] for c in optional),
                 "environment_attachments": sum(not a["kind"].startswith("lost-") and "environment" in a["kind"] for a in r["attachments"])}
        for k, v in facts.items(): self.check(m[k] == v, label + " metric " + k)
        self.check(r["unresolved_joints"] == len(mandatory) - facts["fulfilled_mandatory_connectors"], label + " mandatory unresolved")
        for c in r["connectors"]:
            self.check(c["instance"] in owners, label + " connector without owner")
            if c["state"] in ("lost", "clipped"): self.check(not c["fulfilled"], label + " severed connector marked fulfilled")
        self.counts["native_cells"] += n

    def pair(self, p):
        ql, qr = p["left_request"], p["right_request"]
        w, h = ql["width"], ql["height"]; n = w * h
        self.check(ql["source"] == qr["source"] and ql["seed"] == qr["seed"], "pair source/seed")
        self.check(ql["context"] == qr["context"] and ql["protected"] == qr["protected"] and ql["transition"] == qr["transition"], "pair shared fixture masks")
        self.check(ql["neighbor_cells"] == p["initial_right"]["cells"] and qr["neighbor_cells"] == p["initial_left"]["cells"], "frozen foreign material snapshot")
        self.check(ql["neighbors"] == p["initial_right"]["boundary"] and qr["neighbors"] == p["initial_left"]["boundary"], "frozen foreign boundary snapshot")
        self.check(len(p["side"]) == n and set(p["side"]) == {0, 1}, "pair side shape")
        for si, (side, q) in enumerate((("left", ql), ("right", qr))):
            self.check(all(bool(e) == (p["side"][i] == si and 3 <= i % w < w-3 and 3 <= i // w < h-3) for i,e in enumerate(q["eligible"])), "fixture side eligibility")
            self.result(q, p[side], side)
            base = copy.deepcopy(q); base["neighbors"] = {"hard": [], "soft": [], "protected": [], "transition": []}; base["neighbor_cells"] = []
            for prefix in ("initial_", "clipped_"): self.result(base, p[prefix + side], prefix + side)
            for i, cell in enumerate(p["initial_" + side]["cells"]):
                self.check(not (cell or not q["transition"][i]) or p[side]["cells"][i] == cell, "frozen architecture changed")
        f = mix(w * 65536 + h)
        for i, side in enumerate(p["side"]):
            f = mix(f ^ mix(i) ^ side ^ (ql["protected"][i] << 8) ^ (ql["context"][i] << 16) ^ (ql["transition"][i] << 24))
        self.check(f"{f:016x}" == p["fixture_digest"], "fixture digest")
        for prefix in ("", "initial_", "clipped_"):
            a, b = p[prefix + "left"]["cells"], p[prefix + "right"]["cells"]
            cells = p[prefix + "cells"]
            self.check(len(cells) == n, "composite array shape")
            for i in range(n):
                av, bv = (a[i] if a else 0), (b[i] if b else 0)
                self.check(not (av and bv) and not ((av or bv) and ql["context"][i]), prefix + "overlap")
                self.check(cells[i] == (bv or av or ql["context"][i]), prefix + "composite")
        self.check(p["conflicts"] == p["protected_violations"] == 0, "pair hard violation count")
        self.check(not any(c and ql["protected"][i] for i, c in enumerate(p["cells"])), "pair corridor occupied")
        offers = [{a["id"]: a for a in p[side]["boundary"]["hard"]} for side in ("left", "right")]
        used = [set(), set()]; used_points = set(); bridge_cells = set(); joined = bridges = adjacent = 0
        for seam in p["seams"]:
            if not seam["joined"]:
                self.check(not seam["cells"], "rejected seam has committed path")
                self.check(bool(seam["reason"]), "rejected seam without reason")
                continue
            joined += 1; self.counts["joined_paths"] += 1
            path = [tuple(x) for x in seam["cells"]]
            self.check(2 <= len(path) <= 32 and len(set(path)) == len(path), "bounded simple seam")
            self.check(path[0] == tuple(seam["a"]) and path[-1] == tuple(seam["b"]), "seam endpoints")
            self.check(all(abs(a[0]-b[0])+abs(a[1]-b[1]) == 1 for a,b in zip(path,path[1:])), "seam material path disconnected")
            chosen = []
            for ix, side, key, endpoint, outward in ((0,"left","left_affordance",path[0],path[1]),(1,"right","right_affordance",path[-1],path[-2])):
                aid = seam[key]; self.check(aid in offers[ix] and aid not in used[ix], "offer missing/reused")
                used[ix].add(aid); a = offers[ix][aid]; chosen.append(a)
                self.check(endpoint not in used_points, "endpoint reused"); used_points.add(endpoint)
                self.check(endpoint in line(a["a"],a["b"]), "seam endpoint outside exact offer")
                facing = tuple(a["facing"])
                self.check(facing == (0,0) or (outward[0]-endpoint[0],outward[1]-endpoint[1]) == facing, "wrong socket exit/entry")
                i = endpoint[1] * w + endpoint[0]; r = p[side]
                self.check(r["cells"][i] != 0 and r["roles"][i] not in (0,3,4), "endpoint lacks structural native material")
                matches = [c for c in r["connectors"] if all(c[k] == a[k] for k in ("instance","family","a","b","facing"))]
                self.check(len(matches) <= 1 and (not a["required"] or len(matches) == 1), "required receipt missing/ambiguous")
                for c in matches: self.check(c["fulfilled"] and c["state"] == "joined-foreign", "exact connector not fulfilled")
                if a["required"]: self.counts["required_seam_receipts"] += 1
                self.check(any(t["kind"] == "foreign-typed-joint" and t["instance"] == a["instance"] and tuple(t["point"]) == endpoint and tuple(t["target"]) == path[-1 if ix == 0 else 0] for t in r["attachments"]), "material join lacks attachment receipt")
            families = [a["family"] for a in chosen]
            self.check("passage" not in families and families != ["brace","brace"], "incompatible families joined")
            for pi, (x,y) in enumerate(path):
                self.check(0 <= x < w and 0 <= y < h, "path outside canvas"); i = y*w+x
                self.check(ql["transition"][i] and not ql["protected"][i] and not ql["context"][i], "path violates fixture envelope")
                self.check(all(not p[side]["boundary"]["protected"][i] for side in ("left","right")), "path violates exported aperture")
                self.check(p["cells"][i] != 0, "claimed seam has material gap")
                if pi not in (0,len(path)-1):
                    owner = "left" if p["side"][i] == 0 else "right"; r = p[owner]
                    instance = next((z for z in r["instances"] if z["id"] == r["provenance"][i]), None)
                    self.check(r["roles"][i] == 5 and instance is not None and instance["kind"] == "typed-seam-joint", "bridge not separated from native architecture")
                    self.check([x,y] in instance["cells"], "bridge footprint missing")
                    self.check(i not in bridge_cells, "bridge interior reused"); bridge_cells.add(i)
            if len(path)>2: bridges += 1
            else: adjacent += 1
        self.check(bridges == p["bridges"] and adjacent == p["typed_contacts"] and len(bridge_cells) == p["bridge_cells"], "seam aggregate count")
        self.check(joined <= 12 and p["work"] <= 2_000_000, "shared work/joint limit")
        residual = sum(aid not in used[ix] and ql["transition"][a["a"][1]*w+a["a"][0]] for ix, group in enumerate(offers) for aid,a in group.items())
        self.check(residual == p["unresolved_seams"], "unused transition offers hidden")
        ld, rd = int(p["left"]["digest"],16), int(p["right"]["digest"],16)
        rotate = ((rd << 17) | (rd >> 47)) & MASK
        pd = mix(ld ^ rotate ^ f ^ p["work"] ^ p["bridges"] ^ p["unresolved_seams"] ^ mix(p["typed_contacts"]) ^ mix(p["bridge_cells"]))
        self.check(f"{pd:016x}" == p["digest"], "pair semantic digest")
        self.counts["pair_digests"] += 1; self.counts["bridge_cells"] += len(bridge_cells)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("registration", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    start = time.monotonic(); audit = Audit()
    registration = json.loads(args.registration.read_text())
    producer_manifest = args.evidence / "manifest.json"
    producer = json.loads(producer_manifest.read_text()) if producer_manifest.exists() else None
    ids = [x["case_id"] for x in registration["cases"]]
    audit.check(len(ids) == len(set(ids)) == 100, "registration cardinality")
    audit.check(Counter(x["group"] for x in registration["cases"]) == GROUP_COUNTS, "allocation")
    files = {}
    for case in registration["cases"]:
        cid = case["case_id"]; audit.case = cid
        # Bind the canonical raw directory explicitly: rendered case_records
        # intentionally reuse case IDs but are derived facts, not native input.
        path = args.evidence / "native" / (cid + ".json")
        audit.check(path.is_file(), "registered native raw case missing")
        data = json.loads(path.read_text()); files[cid] = hashlib.sha256(path.read_bytes()).hexdigest()
        q = data["request"] if data["type"] == "single" else data["left_request"]
        for field in ("fixture", "seed"):
            audit.check(q[field] == case[field], "manifest " + field)
        audit.check(q["gentek"] == case["kind"] and q["profile"]["name"] == case["profile"], "manifest kind/profile")
        audit.check([q["width"],q["height"]] == case["dimensions"] and q["origin"] == case["origin"], "manifest dimensions/origin")
        for k,v in case["overrides"].items():
            if k == "environment_affinity": audit.check(q["profile"][k] == v, "registered environment affinity")
            elif k == "empty_eligible": audit.check(not v or not any(q["eligible"]), "registered empty eligibility")
            else: audit.check(q["limits"][k.removeprefix("max_")] == v, "registered " + k)
        if producer:
            audit.check(q["source"] == producer["source_commit"], "compiled source HEAD")
            audit.check(q["definition"].endswith("."+producer["compiled_definition_fingerprint"]), "compiled definition fingerprint")
        if data["type"] == "single": audit.result(q, data["result"], "single")
        else:
            audit.check(data["right_request"]["gentek"] == case["right_kind"], "manifest right kind")
            audit.pair(data)
        audit.counts["cases"] += 1
        print(cid + " PASS", flush=True)
    result = {"result":"PASS", "independent":True, "audit_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "registration_sha256":hashlib.sha256(args.registration.read_bytes()).hexdigest(),
              "finished_utc":datetime.now(timezone.utc).isoformat(), "elapsed_seconds":round(time.monotonic()-start,3),
              "counts":dict(sorted(audit.counts.items())), "case_sha256":files,
              "limitations":["No physical support or traversal claim; component counts are descriptive.",
                             "Capacity refusal has no allocated material array; zero digests are retained as native failure semantics.",
                             "Semantic hash verifies serialization integrity; geometry and joint assertions are independent additional checks."]}
    args.out.write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result["counts"],sort_keys=True), flush=True)


if __name__ == "__main__": main()
