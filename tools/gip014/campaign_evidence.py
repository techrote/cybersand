"""Independent observation-derived coverage and bounded campaign comparison.

Coverage is earned by acknowledged actual observations, never by the size of the
available menu. Material adjacency is not a claim that a chemical reaction ran;
an actor model/zone is not a claim of successful navigation.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import math
import re
import statistics

from verify_transcript import bounded, canonical, digest, integer

DIMENSIONS = ("action", "action_transition", "state_transition", "material_interaction", "tool_material",
              "actor_environment", "lifecycle", "boundary_refusal", "outcome")
MAX_KEYS = 2048
EDIT_ACTIONS = {"brush", "erase", "rectangle", "outline", "line", "paste", "fill", "undo", "redo", "stroke", "live_stroke", "interrupt_stroke"}
PAINT_TOOLS = {"brush": "Brush", "rectangle": "Rectangle", "outline": "Outline", "line": "Line", "stroke": "Brush", "fill": "Fill"}
UNKNOWN = "unknown"
STATE_SCHEMA = "cybersand-goblin-state-v2"
LEGACY_STATE_SCHEMA = "cybersand-goblin-state-v1"
UNSUPPORTED_STATE_SCHEMA = "cybersand-goblin-state-unsupported"


def projection_version(value: dict) -> int:
    """Exact legacy keys, explicit current version, no future-version credit."""
    if "adapter_version" not in value:
        return 1
    version = value["adapter_version"]
    if bounded(version, 1, 2):
        return 1
    if bounded(version, 3, 3):
        return 2
    return 0


def observed(value: dict) -> bool:
    if projection_version(value) == 0:
        return False
    native = value.get("native", {})
    return value.get("mounted") is True and isinstance(native, dict) and bounded(native.get("generation"), 0, 2147483647) and bounded(native.get("tick"), 0, 2147483647)


def number(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def zone(position, extent) -> str:
    if not isinstance(position, list) or len(position) != 2 or not isinstance(extent, list) or len(extent) != 2 or not all(number(v) for v in [*position, *extent]):
        return UNKNOWN
    x, y = position
    w, h = extent
    if x < 0 or y < 0 or x >= w or y >= h:
        return "outside"
    if min(x, y) < 16 or x >= w - 16 or y >= h - 16:
        return "edge"
    return "zone_%d_%d" % (min(3, max(0, int(x / max(1.0, w / 4.0)))), min(3, max(0, int(y / max(1.0, h / 4.0)))))


def progression(before, after):
    a, b = before.get("native", {}), after.get("native", {})
    if not all(bounded(v.get("generation"), 0, 2147483647) for v in (a, b)):
        return UNKNOWN
    if a["generation"] != b["generation"]:
        return "world_replaced"
    if not all(bounded(v.get("tick"), 0, 2147483647) for v in (a, b)):
        return UNKNOWN
    return "advanced" if b["tick"] > a["tick"] else ("unchanged" if b["tick"] == a["tick"] else "regressed")


def probe_summary(probe, native):
    unknown = {"available": False, "scope": "unobserved"}
    if not isinstance(probe, dict) or probe.get("current") is not True or probe.get("evidence_kind") != "actual_native_material_capture":
        return unknown
    if any(not bounded(probe.get(k), 0, 2147483647) or probe[k] != native.get(k) for k in ("generation", "revision", "tick")):
        return unknown
    region, counts = probe.get("region"), probe.get("counts")
    if not isinstance(region, list) or len(region) != 4 or not all(bounded(v, 0, 4096) for v in region) or not isinstance(counts, dict) or not 1 <= len(counts) <= 128:
        return unknown
    area = region[2] * region[3]
    if not 1 <= area <= 4096:
        return unknown
    total, occupied, ids = 0, 0, []
    for key, count in counts.items():
        if not isinstance(key, str) or re.fullmatch(r"[+-]?\d+", key) is None or not bounded(int(key), 0, 65535) or not bounded(count, 1, 4096):
            return unknown
        total += int(count)
        if int(key) != 0:
            occupied += int(count)
        ids.append(str(int(key)))
    if total != area:
        return unknown
    fraction = occupied / total
    return {"available": True, "scope": "captured_region_only", "materials": sorted(ids),
            "occupancy": "empty" if occupied == 0 else ("trace" if fraction < 0.05 else ("sparse" if fraction < 0.25 else ("mixed" if fraction < 0.75 else "dense")))}


def godot_scalar(value):
    if type(value) is bool:
        return "true" if value else "false"
    return str(int(value)) if type(value) is float and value.is_integer() else str(value)


def state(value):
    version = projection_version(value)
    if version == 0:
        return {"schema": UNSUPPORTED_STATE_SCHEMA, "reason": "unsupported_adapter_version"}
    def truth(obj, key):
        return obj[key] if type(obj.get(key)) is bool else UNKNOWN
    def pair(obj, low=1, high=4096):
        return [int(v) for v in obj] if isinstance(obj, list) and len(obj) == 2 and all(bounded(v, low, high) for v in obj) else UNKNOWN
    def area(obj, rectangle=False):
        if not isinstance(obj, list) or len(obj) != (4 if rectangle else 2) or not all(bounded(v, 0, 4096) for v in obj[-2:]):
            return UNKNOWN
        size = obj[-2] * obj[-1]
        return "none" if size == 0 else ("small" if size <= 64 else ("medium" if size <= 1024 else "large"))
    def role(key):
        if key not in value:
            return UNKNOWN
        if int(value[key]) <= 0:
            return "none"
        return next((str(a.get("model", UNKNOWN))[:64] for a in value.get("actors", []) if a.get("observed") is True and a.get("id") == value[key]), "selected_unobserved")
    native, camera = value.get("native", {}), value.get("camera", {})
    actors = value.get("actors", [])
    origin = camera.get("origin")
    coarse = [min(64, max(-64, math.floor(v / 64.0))) for v in origin] if isinstance(origin, list) and len(origin) == 2 and all(number(v) for v in origin) else UNKNOWN
    tick = native.get("tick")
    zero_phase = "authored_start" if version == 1 else "zero_tick"
    phase = UNKNOWN if not bounded(tick, 0, 2147483647) else (zero_phase if tick == 0 else ("early" if tick < 32 else ("developing" if tick < 256 else "sustained")))
    observed_actors = [a for a in actors[:8] if isinstance(a, dict) and a.get("observed") is True]
    return {"schema": LEGACY_STATE_SCHEMA if version == 1 else STATE_SCHEMA, "fixture": str(value.get("fixture_id", UNKNOWN))[:80],
            "world_size": pair(value.get("world_size")), "paused": truth(value, "paused"), "tool": str(value.get("tool", UNKNOWN))[:64],
            "material": value.get("material", UNKNOWN), "brush_radius": value.get("brush_radius", UNKNOWN),
            "native_busy": truth(native, "busy"), "native_failed": truth(native, "failed"), "progress_phase": phase,
            "history": [truth(value, "undo_available"), truth(value, "redo_available")],
            "selection": area(value.get("selection"), True), "clipboard": area(value.get("clipboard_size")),
            "actor_models": sorted(str(a.get("model", UNKNOWN))[:64] for a in observed_actors),
            "actor_zones": sorted(str(a.get("model", UNKNOWN))[:64] + ":" + zone(a.get("position"), value.get("world_size")) for a in observed_actors),
            "actor_controls": sorted(str(a.get("model", UNKNOWN))[:64] + ":" + godot_scalar(a.get("authored_control", {}).get("source", UNKNOWN)) + ":" + godot_scalar(a.get("authored_control", {}).get("enabled", UNKNOWN)) + ":" + godot_scalar(a.get("authored_control", {}).get("usable_index", UNKNOWN)) for a in observed_actors),
            "actor_capabilities": sorted(str(a.get("model", UNKNOWN))[:64] + ":" + c[:64] for a in observed_actors for c in a.get("capabilities", {}).get("capabilities", [])[:16] if isinstance(c, str)),
            "actor_count": len(actors) if "actors" in value else UNKNOWN, "selected": role("selected_actor"), "pilot": role("pilot_actor"),
            "saved": bool(str(value["saved_authored_digest"])) if "saved_authored_digest" in value else UNKNOWN,
            "camera_origin": coarse, "camera_size": pair(camera.get("size")), "details_open": truth(value, "details_open"),
            "material_sample": probe_summary(value.get("material_probe", {}), native),
            "response_mode": value.get("configuration", {}).get("response", UNKNOWN), "camera_mode": camera.get("mode", UNKNOWN),
            "preview_active": truth(value.get("paint_preview", {}), "dragging"),
            "source_present": bool(value.get("source", {}).get("authored", [])) if "source" in value else UNKNOWN}


def valid_capture(capture, native):
    if not isinstance(capture, dict) or "error" in capture or capture.get("source_matches") is not True:
        return False
    before, after, admission, receipt = (capture.get(k) for k in ("source_before", "source_after", "admission", "native_receipt"))
    cells, region = capture.get("materials"), capture.get("region")
    if not all(isinstance(v, dict) for v in (before, after, admission, receipt)) or not isinstance(cells, list) or not 1 <= len(cells) <= 4096 or not isinstance(region, list) or len(region) != 4:
        return False
    if before != after or admission.get("status") != "queued" or receipt.get("status") != "completed" or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld":
        return False
    if not bounded(admission.get("operation_id"), 0, 2147483647) or admission["operation_id"] != receipt.get("operation_id"):
        return False
    if any(not bounded(before.get(k), 0, 2147483647) or before[k] != receipt.get(k) or native.get(k) != before[k] for k in ("generation", "revision", "tick")):
        return False
    return receipt.get("observed_generation") == before["generation"] and before.get("paused") is True and before.get("failed") is False and all(bounded(v, 0, 4096) for v in region) and min(region[2:]) > 0 and region[2] * region[3] == len(cells) and all(bounded(v, 0, 65535) for v in cells)


def coverage(tape: dict) -> dict:
    counts = {key: Counter() for key in DIMENSIONS}
    actions, variants, refusals, totals, saturated = set(), set(), set(), Counter(), set()
    previous = ""
    def add(dim, key):
        if key not in counts[dim] and len(counts[dim]) >= MAX_KEYS:
            saturated.add(dim)
            return
        counts[dim][key] += 1
    for row in tape.get("steps", []):
        action, before, after = row["action"], row["before"], row["after"]
        name, status, admission = action["id"], row["status"], row["admission"]
        factual = observed(before) and observed(after)
        accepted = admission.get("accepted") is True or admission.get("status") in ("queued", "accepted")
        totals["attempted_records"] += 1
        if status == "refused":
            totals["refused_actions"] += 1
            if factual:
                refusals.add(digest({"id": name, "args": action["args"]}))
                add("boundary_refusal", name + ":" + str(row.get("classification", "unclassified")) + ":" + hashlib.sha256(str(row.get("error", ""))[:200].encode()).hexdigest())
        if not factual:
            totals["records_without_native_observation"] += 1
        if not accepted or not factual or status not in ("completed", "partial"):
            previous = ""
            continue
        totals["admitted_observed_actions"] += 1
        first, last = digest(state(before)), digest(state(after))
        add("state_transition", first + ">" + name + ":" + status + ">" + last)
        actions.add(first + ":" + name)
        variants.add(digest({"id": name, "args": action["args"]}))
        if status == "completed":
            totals["completed_admitted_actions"] += 1
            add("action", name)
            if previous:
                add("action_transition", previous + ">" + name)
            previous = name
        else:
            totals["partial_admitted_actions"] += 1
            previous = ""
        old_capture, new_capture = row.get("capture_before", {}), row.get("capture_after", {})
        if valid_capture(new_capture, after.get("native", {})):
            cells, width = new_capture["materials"], int(new_capture["region"][2])
            contacts = set()
            for index, material in enumerate(cells):
                if material == 0:
                    continue
                for neighbor in (index + 1 if (index + 1) % width else -1, index + width):
                    if 0 <= neighbor < len(cells) and cells[neighbor] not in (0, material):
                        contacts.add("adjacent:%d+%d" % (min(material, cells[neighbor]), max(material, cells[neighbor])))
            for contact in contacts:
                add("material_interaction", contact)
            if name in EDIT_ACTIONS and row.get("native_receipt", {}).get("status") == "completed":
                if status == "completed" and name in PAINT_TOOLS and after.get("tool") == PAINT_TOOLS[name] and bounded(before.get("material"), 0, 65535) and bounded(after.get("material"), 0, 65535) and before["material"] == after["material"]:
                    add("tool_material", after["tool"] + ":" + str(int(after["material"])))
                if valid_capture(old_capture, before.get("native", {})) and old_capture["region"] == new_capture["region"]:
                    for changed in {"edit:%d>%d" % (a, b) for a, b in zip(old_capture["materials"], cells) if a != b}:
                        add("material_interaction", changed)
        for actor in after.get("actors", [])[:8]:
            if actor.get("observed") is True:
                place = zone(actor.get("position"), after.get("world_size"))
                if place != UNKNOWN:
                    role = "pilot" if actor.get("id") == after.get("pilot_actor") else "unpiloted"
                    add("actor_environment", str(actor.get("model", ""))[:64] + ":" + str(after.get("fixture_id", ""))[:80] + ":" + place + ":" + role)
        if progression(before, after) == "world_replaced":
            add("lifecycle", "native_world_replacement")
        if "scene_identity" in before and "scene_identity" in after and before["scene_identity"] != after["scene_identity"]:
            add("lifecycle", "authored_identity_change")
        if type(before.get("paused")) is bool and type(after.get("paused")) is bool and before["paused"] != after["paused"]:
            add("lifecycle", "pause_to_play" if before["paused"] else "play_to_pause")
        if "actors" in before and "actors" in after:
            if len(before["actors"]) < len(after["actors"]):
                add("lifecycle", "actor_added")
            if len(before["actors"]) > len(after["actors"]):
                add("lifecycle", "actor_retired")
        if "pilot_actor" in before and "pilot_actor" in after and before["pilot_actor"] != after["pilot_actor"]:
            add("lifecycle", "control_transfer")
        if "saved_authored_digest" in before and "saved_authored_digest" in after and before["saved_authored_digest"] != after["saved_authored_digest"]:
            add("lifecycle", "authored_save_changed")
        receipt = row.get("native_receipt", {})
        changed = receipt.get("changed")
        change_bucket = UNKNOWN if not bounded(changed, 0, 16777216) else ("none" if changed == 0 else ("small" if changed <= 16 else ("medium" if changed <= 256 else "large")))
        add("outcome", digest({"action": name, "status": status, "classification": row.get("classification", ""),
                              "receipt_kind": receipt.get("kind", "none"), "changed": change_bucket,
                              "progression": progression(before, after), "failed_assertions": sorted(str(c.get("id", ""))[:120] for c in row.get("assertions", []) if c.get("status") == "fail")}))
    for key in ("attempted_records", "admitted_observed_actions", "completed_admitted_actions", "partial_admitted_actions", "refused_actions", "records_without_native_observation"):
        totals.setdefault(key, 0)
    result = {"schema": "cybersand-goblin-independent-coverage-v1", **totals, "unique": {k: len(v) for k, v in counts.items()},
              "keys": {k: sorted(v) for k, v in counts.items()}, "state_action_pairs": min(MAX_KEYS, len(actions)),
              "parameter_variants": min(MAX_KEYS, len(variants)), "refused_parameter_variants": min(MAX_KEYS, len(refusals)),
              "saturated_dimensions": sorted(saturated)}
    recorded = tape.get("policy_summary", {}).get("coverage", {})
    result["recorded_coverage_present"] = bool(recorded)
    result["recorded_count_mismatches"] = [k for k in totals if recorded and recorded.get(k) != result[k]]
    result["recorded_dimension_mismatches"] = [k for k in DIMENSIONS if recorded and recorded.get("unique", {}).get(k) != result["unique"][k]]
    return result


def compare(episodes: list[dict], plan: dict) -> dict:
    groups = {}
    for entry in episodes:
        key = entry["episode"]["cohort"] + "/" + entry["episode"]["policy"]
        group = groups.setdefault(key, {"episodes": 0, "attempted_budget_completed_episodes": 0, "attempted_actions": 0, "admitted_actions": 0,
                                       "completed_actions": 0, "partial_actions": 0, "refusals": 0, "process_status": Counter(),
                                       "keys": {dim: set() for dim in DIMENSIONS}, "wall": [], "memory": [], "state_per_episode": [], "oracle_failures": 0})
        group["episodes"] += 1
        group["attempted_budget_completed_episodes"] += int(entry["status"] == "pass")
        group["process_status"][entry["status"]] += 1
        if "elapsed_seconds" in entry.get("process", {}):
            group["wall"].append(entry["process"]["elapsed_seconds"])
        if "peak_tree_rss_bytes" in entry.get("process", {}):
            group["memory"].append(entry["process"]["peak_tree_rss_bytes"])
        values = entry.get("coverage", {})
        for target, source in (("attempted_actions", "attempted_records"), ("admitted_actions", "admitted_observed_actions"), ("completed_actions", "completed_admitted_actions"), ("partial_actions", "partial_admitted_actions"), ("refusals", "refused_actions")):
            group[target] += values.get(source, 0)
        group["oracle_failures"] += len(entry.get("summary", {}).get("failures", []))
        for dim in DIMENSIONS:
            group["keys"][dim].update(values.get("keys", {}).get(dim, []))
        if "state_transition" in values.get("unique", {}):
            group["state_per_episode"].append(values["unique"]["state_transition"])
    for group in groups.values():
        group["unique_observed_coverage"] = {dim: len(keys) for dim, keys in group.pop("keys").items()}
        wall = group.pop("wall")
        group["observed_wall_measurements"] = len(wall)
        group["wall_seconds"] = round(sum(wall), 3) if wall else None
        group["median_episode_seconds"] = round(statistics.median(wall), 3) if wall else None
        memory, transitions = group.pop("memory"), group.pop("state_per_episode")
        group["observed_coverage_measurements"] = len(transitions)
        group["peak_tree_rss_bytes"] = max(memory) if memory else None
        group["median_unique_state_transitions_per_episode"] = statistics.median(transitions) if transitions else None
        group["process_status"] = dict(group["process_status"])
    return {"schema": "cybersand-goblin-campaign-comparison-v1", "source_commit": plan["provenance"]["source_commit"],
            "source_tree": plan["provenance"]["source_tree"], "plan_sha256": plan["plan_sha256"], "planned_episodes": len(plan["episodes"]),
            "observed_episodes": len(episodes), "complete_episodes": sum(e["status"] == "pass" for e in episodes),
            "estimand": "Latest attempted result per immutable episode ID; complete means attempted budget reached, not every action admitted",
            "incomplete_episodes": [e["episode"]["id"] for e in episodes if e["status"] != "pass"], "groups": groups,
            "confirmed_production_defects": [], "confirmation_scope": "No automatic promotion of oracle failure to production defect",
            "material_scope": "captured-region adjacency and edit transformation, not inferred reaction success",
            "actor_scope": "observed model, fixture, spatial zone and pilot role, not route completion",
            "resume_contract": "Queue resumes pending fresh episodes; no asynchronous physical checkpoint replay"}
