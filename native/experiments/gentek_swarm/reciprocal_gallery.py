#!/usr/bin/env python3
"""Audit and render exact SWARM-004 native arrays, retaining every failed case.

These images are native catalogue swatches, never Godot framebuffer or physical
stability evidence. Ownership/revision/joint overlays are explicitly diagnostic.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import gzip
import hashlib
import html
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw
from gallery import BG, FG, MUTED, ROOT as NATIVE_ROOT, font, overlays, raster

MATERIAL_STATES = re.findall(r'\{"[^\"]+", MaterialState::(\w+)',
                            (NATIVE_ROOT / "native/include/cybersand/material.hpp").read_text())
if len(MATERIAL_STATES) != 132:
    raise RuntimeError("Expected exact unchanged native material catalogue states")
SOLID_MATERIALS = {index for index, state in enumerate(MATERIAL_STATES) if state == "Solid" and index != 10}

OWNERS = {0: BG, 1: (94, 159, 220), 2: (188, 132, 83), 3: (107, 112, 122)}
CSS = """body{font:15px system-ui;background:#101720;color:#dfe6ef;margin:2rem auto;max-width:1600px;padding:0 1rem}
a{color:#75d6c5}table{border-collapse:collapse;width:100%;font-size:13px}th,td{border:1px solid #334251;padding:.45rem;text-align:left}
th{background:#243140}img{max-width:100%;height:auto}article,section{background:#18232e;padding:1rem;margin:1.2rem 0;border-radius:8px}
code{overflow-wrap:anywhere}small,.muted{color:#9bafc1}.fail{color:#ffab9c}.pass{color:#89d6b5}h1,h2,h3{line-height:1.2}
input{font:inherit;padding:.6rem;width:min(95%,700px);background:#243140;border:1px solid #56687a;color:white}
details{margin:1rem 0}pre{white-space:pre-wrap;overflow-wrap:anywhere} .tablewrap{overflow-x:auto}"""


def wrapped(text, face, width):
    lines, line = [], ""
    for word in str(text).split():
        candidate = (line + " " + word).strip()
        if face.getlength(candidate) <= width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = ""
            for char in word:
                if face.getlength(line + char) > width and line:
                    lines.append(line)
                    line = ""
                line += char
    return lines + ([line] if line else [])


def panel(image, title, subtitle):
    width = image.width + 24
    title_lines, subtitle_lines = wrapped(title, font(17), width - 26), wrapped(subtitle, font(12), width - 26)
    header = 22 * len(title_lines) + 17 * len(subtitle_lines) + 22
    canvas = Image.new("RGB", (width, image.height + header + 12), (20, 27, 36))
    draw = ImageDraw.Draw(canvas)
    y = 9
    for text in title_lines:
        draw.text((13, y), text, fill=FG, font=font(17))
        y += 22
    for text in subtitle_lines:
        draw.text((13, y), text, fill=MUTED, font=font(12))
        y += 17
    canvas.paste(image, (12, header))
    canvas.info["native_canvas_top"] = header
    return canvas


def row(panels, title, subtitle):
    common_top = max(p.info.get("native_canvas_top", 0) for p in panels)
    aligned = []
    for image in panels:
        old_top = image.info.get("native_canvas_top", common_top)
        if old_top < common_top:
            adjusted = Image.new("RGB", (image.width, image.height + common_top - old_top), (20, 27, 36))
            adjusted.paste(image.crop((0, 0, image.width, old_top)), (0, 0))
            adjusted.paste(image.crop((0, old_top, image.width, image.height)), (0, common_top))
            aligned.append(adjusted)
        else:
            aligned.append(image)
    panels = aligned
    width = sum(p.width for p in panels) + 16 * (len(panels) + 1)
    titles, subtitles = wrapped(title, font(23), width - 36), wrapped(subtitle, font(14), width - 36)
    header = len(titles) * 30 + len(subtitles) * 20 + 32
    canvas = Image.new("RGB", (width, max(p.height for p in panels) + header + 18), BG)
    draw = ImageDraw.Draw(canvas)
    y = 13
    for text in titles:
        draw.text((18, y), text, fill=FG, font=font(23))
        y += 30
    for text in subtitles:
        draw.text((18, y), text, fill=MUTED, font=font(14))
        y += 20
    x = 16
    for image in panels:
        canvas.paste(image, (x, header))
        x += image.width + 16
    return canvas


def read_record(root, relative, storage):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError("record escaped the evidence directory")
    compressed = path.with_name(path.name + ".gz")
    if path.is_file():
        data = path.read_bytes()
    elif compressed.is_file():
        if compressed.stat().st_size > 64 * 1024 * 1024:
            raise ValueError("compressed case exceeds its finite envelope")
        with gzip.open(compressed, "rb") as source:
            data = source.read(64 * 1024 * 1024 + 1)
    else:
        raise FileNotFoundError(relative)
    if len(data) > 64 * 1024 * 1024:
        raise ValueError("native case exceeds its finite serialized envelope")
    receipt = storage.get(relative)
    if receipt and hashlib.sha256(data).hexdigest() != receipt["raw_sha256"]:
        raise ValueError("raw native evidence hash mismatch: " + relative)
    return json.loads(data), hashlib.sha256(data).hexdigest()


def request_for(document):
    if document.get("schema") == 5:
        return document["input"]["frame"]
    if document.get("schema") == 6:
        return document["request"]
    candidate = document.get("candidate", document)
    return candidate["frame_request"]


def lookup(document, view):
    value = document
    for name in view.split("."):
        value = value[name]
    return value


def combined_round(document, round_record):
    q = document["input"]["frame"]
    n = q["width"] * q["height"]
    context = q.get("context") or [0] * n
    frame = round_record["frame"]["result"]["cells"]
    mosaic = round_record["mosaic"]["result"]["cells"]
    return [(frame[i] if i < len(frame) else 0) or (mosaic[i] if i < len(mosaic) else 0) or context[i] for i in range(n)]


def display_cells(document):
    if document.get("cells"):
        return document["cells"], "final native damage derivative" if document.get("damage_derivative") else "final native proposal"
    if document.get("rounds"):
        return combined_round(document, document["rounds"][-1]), "last retained proposal; no commit output"
    q = document["input"]["frame"]
    return q.get("context") or [0] * (q["width"] * q["height"]), "no native proposal completed"


def audit_composition(document, source):
    errors = []
    checks = 0

    def require(condition, message):
        nonlocal checks
        checks += 1
        if not condition and len(errors) < 80:
            errors.append(message)

    require(document.get("schema") == 5 and document.get("type") == "reciprocal_assembly", "wrong native schema")
    require(document.get("source") == source, "composition source identity mismatch")
    q = document["input"]["frame"]
    mq = document["input"]["mosaic"]
    width, height = q["width"], q["height"]
    count = width * height
    require(0 < width <= 256 and 0 < height <= 128, "canvas exceeds registered native bounds")
    require(mq["width"] == width and mq["height"] == height and mq["seed"] == q["seed"], "peer geometry/seed mismatch")
    protected = q.get("protected") or [0] * count
    context = q.get("context") or [0] * count
    shared = document["input"]["shared_zone"]
    require(len(protected) == len(context) == len(shared) == count, "input mask length mismatch")
    frame_changes = mosaic_changes = frame_footprints = mosaic_footprints = 0
    previous = None
    for round_record in document["rounds"]:
        bearings = round_record.get("mosaic_bearing_replacements", [])
        if not document["input"]["options"].get("native_mosaic_bearing", False):
            require(not bearings and round_record.get("mosaic_bearing_work", 0) == 0, "disabled bearing hypothesis changed cells/work")
        require(round_record.get("mosaic_bearing_work", 0) <= round_record.get("mosaic_proposal_work", 0), "bearing work omitted from aggregate proposal debit")
        bearing_points = set()
        proposed_mosaic = round_record.get("proposed_mosaic", {})
        for replacement in bearings:
            point = replacement["point"]
            valid_point = len(point) == 2 and 0 <= point[0] < width and 0 <= point[1] < height
            require(valid_point and tuple(point) not in bearing_points, "duplicate or invalid native bearing point")
            bearing_points.add(tuple(point))
            require(replacement["before"] == 13 and replacement["after"] == 38 and replacement["rule"] == "swarm004/mosaic_native_bearing_v1", "unauthored native bearing material/rule")
            if valid_point and len(proposed_mosaic.get("cells", [])) == count:
                i = point[1] * width + point[0]
                require(proposed_mosaic["cells"][i] == 38 and proposed_mosaic["provenance"][i] == replacement["instance"], "native bearing receipt differs from proposed own material/part")
                part = next((part for part in proposed_mosaic["instances"] if part["id"] == replacement["instance"]), None)
                require(part is not None and replacement["rule"] in part["reason"], "bearing material rule absent from native part provenance")
        owners = [round_record["frame"]["result"], round_record["mosaic"]["result"]]
        lengths_ok = all(len(result.get("cells", [])) == count and len(result.get("roles", [])) == count and
                         len(result.get("provenance", [])) == count for result in owners)
        accepted = round_record.get("frame_accepted", False) and round_record.get("mosaic_accepted", False)
        require(lengths_ok or not accepted, f"round {round_record['number']} accepted partial native arrays")
        if not lengths_ok:
            continue
        frame, mosaic = owners
        for index, (a, b) in enumerate(zip(frame["cells"], mosaic["cells"])):
            require(not (a and b), f"round {round_record['number']} owner overlap at {index}")
            if a or b:
                require(not protected[index] and not context[index], f"round {round_record['number']} protected/context overwrite at {index}")
                owner_request = q if a else mq
                eligible = owner_request.get("eligible")
                permitted = not eligible or eligible[index] or (document["input"]["options"]["shared_ownership"] and shared[index])
                require(permitted, f"round {round_record['number']} territory escape at {index}")
        for result in owners:
            instances = {instance["id"]: instance for instance in result["instances"]}
            require(len(instances) == len(result["instances"]), "duplicate instance identity")
            for index, material in enumerate(result["cells"]):
                require(isinstance(material, int) and 0 <= material < 132 and material != 10, "invalid native material ID")
                if material:
                    require(result["provenance"][index] in instances, "native material has no authored part")
                    require(result["roles"][index] != 0, "native material has empty structural role")
        if previous is not None:
            before_frame = previous["frame"]["result"]["cells"]
            before_mosaic = previous["mosaic"]["result"]["cells"]
            if len(before_frame) == len(before_mosaic) == count:
                changed_frame = sum(a != b for a, b in zip(before_frame, frame["cells"]))
                changed_mosaic = sum(a != b for a, b in zip(before_mosaic, mosaic["cells"]))
                footprint_frame = sum(bool(a) != bool(b) for a, b in zip(before_frame, frame["cells"]))
                footprint_mosaic = sum(bool(a) != bool(b) for a, b in zip(before_mosaic, mosaic["cells"]))
                require(changed_frame == round_record["frame_changed"], "FRAME changed-cell receipt mismatch")
                require(changed_mosaic == round_record["mosaic_changed"], "MOSAIC changed-cell receipt mismatch")
                require(footprint_frame == round_record["frame_footprint_changed"], "FRAME changed-footprint receipt mismatch")
                require(footprint_mosaic == round_record["mosaic_footprint_changed"], "MOSAIC changed-footprint receipt mismatch")
                frame_changes += changed_frame > 0
                mosaic_changes += changed_mosaic > 0
                frame_footprints += footprint_frame > 0
                mosaic_footprints += footprint_mosaic > 0
                if not round_record["frame_accepted"]:
                    require(frame["cells"] == before_frame, "rejected FRAME revision escaped rollback")
                if not round_record["mosaic_accepted"]:
                    require(mosaic["cells"] == before_mosaic, "rejected MOSAIC revision escaped rollback")
        previous = round_record
    damage = document.get("damage_derivative")
    if damage:
        require(previous is not None, "damage derivative has no intact accepted predecessor")
        require(q["profile"]["destruction"] > 0 or mq["profile"]["destruction"] > 0, "unrequested damage derivative")
        require(damage["work"] > 0, "damage derivative lacks separate accounted work")
        if previous:
            for owner in ("frame", "mosaic"):
                before = previous[owner]["result"]
                after = damage[owner]["result"]
                lengths_ok = all(len(value.get(field, [])) == count for value in (before, after) for field in ("cells", "roles", "provenance"))
                require(lengths_ok, "damage derivative has partial native arrays")
                require(after["seed"] == before["seed"] and after["source"] == before["source"], "damage changed native source/seed")
                if lengths_ok:
                    material_changes = sum(a != b for a, b in zip(before["cells"], after["cells"]))
                    footprint_changes = sum(bool(a) != bool(b) for a, b in zip(before["cells"], after["cells"]))
                    require(damage[owner + "_changed"] == material_changes, "damage material change receipt mismatch")
                    require(damage[owner + "_footprint_changed"] == footprint_changes, "damage occupied footprint receipt mismatch")
                    for i, (a, b) in enumerate(zip(before["cells"], after["cells"])):
                        require(b == a or b == 0, "damage derivative added or replaced material")
                        if b:
                            require(after["roles"][i] == before["roles"][i] and after["provenance"][i] == before["provenance"][i], "damage rewrote surviving structural identity")
                        else:
                            require(after["roles"][i] == after["provenance"][i] == 0, "removed damage cell retains owner/role")
            require(damage["mosaic"]["categories"] == previous["mosaic"]["categories"], "damage changed accepted categorical assignment")
    final = document.get("cells", [])
    require(len(final) in (0, count), "partial final native output")
    obligations = document.get("obligations", [])
    joint_connectors = [joint["connector"] for joint in document.get("joints", [])]
    require(len(joint_connectors) == len(set(joint_connectors)), "one connector used by multiple foreign joints")
    if final:
        require(len(document["ledger"]) == count, "final native ownership ledger has wrong size")
        require(previous is not None, "final output lacks accepted proposal history")
        if previous:
            final_proposals = damage or previous
            frame, mosaic = final_proposals["frame"]["result"], final_proposals["mosaic"]["result"]
            for index, (material, entry) in enumerate(zip(final, document["ledger"])):
                require(len(entry) == 6, "malformed cell provenance tuple")
                if len(entry) != 6:
                    continue
                owner, instance, rule, first, last, mask = entry
                require(0 <= owner <= 3 and 0 <= rule < len(document["rules"]), "invalid owner or rule provenance")
                require(first <= last <= 4 and mask < 32, "invalid revision history bound")
                expected = context[index] if owner == 3 else frame["cells"][index] if owner == 1 else mosaic["cells"][index] if owner == 2 else 0
                require(material == expected, "final material differs from its sole owning native proposal")
                if material:
                    require(owner != 0, "material with empty owner")
                    if owner in (1, 2):
                        require(instance == (frame if owner == 1 else mosaic)["provenance"][index], "final instance provenance mismatch")
                else:
                    require(owner == instance == rule == first == last == mask == 0, "empty final material retains an ownership/revision claim")
            original = document["original_frame"]["result"]["connectors"]
            required = {connector["id"] for connector in original if connector["required"] and not connector["fulfilled"]}
            originals = [receipt for receipt in obligations if receipt.get("origin") == "original_frame"]
            require(required == {receipt["connector"] for receipt in originals}, "original required obligations deleted or invented")
            fulfilled_originals = {connector["id"]: connector for connector in original if connector["required"] and connector["fulfilled"]}
            fulfilled_final = {connector["id"] for connector in frame["connectors"] if connector["fulfilled"]}
            expected_damage_lost = set(fulfilled_originals) - fulfilled_final if damage else set()
            damage_lost = [receipt for receipt in obligations if receipt.get("origin") == "damage_lost_internal"]
            require(expected_damage_lost == {receipt["connector"] for receipt in damage_lost}, "damage-revoked required obligations deleted or invented")
            require(document.get("metrics", {}).get("damage_lost_required", 0) == len(expected_damage_lost), "damage-revoked required obligation metric mismatch")
            require(len({receipt["connector"] for receipt in obligations}) == len(obligations), "duplicate obligation identity")
            for receipt in obligations:
                origin = receipt.get("origin")
                require(origin in ("original_frame", "new_assembly", "damage_lost_internal"), "unidentified hard obligation origin")
                if origin == "damage_lost_internal":
                    original_connector = fulfilled_originals.get(receipt["connector"])
                    require(bool(damage) and original_connector is not None, "damage-revoked obligation lacks an original fulfilled required socket")
                    if original_connector:
                        require(receipt["instance"] == original_connector["instance"] and receipt["original"] == original_connector["a"] and
                                receipt["facing"] == original_connector["facing"], "damage-revoked obligation changed original source identity")
                    require(receipt["slot"] == 0 and not receipt["local_terminated"], "damage-revoked internal obligation invented a foreign slot or local ending")
                    witnessed = False
                else:
                    witnessed = receipt["connector"] in joint_connectors if origin == "original_frame" else any(
                        joint["slot"] == receipt["slot"] and joint["frame_face"] == receipt["original"] and
                        joint["normal"] == receipt["facing"] and joint["frame_instance"] == receipt["instance"]
                        for joint in document.get("joints", []))
                require(receipt["foreign_joined"] == witnessed, "required closure lacks native joint witness")
                require(receipt["state"] == ("FOREIGN_JOINED" if receipt["foreign_joined"] else "STILL_REQUIRED"), "local termination falsely fulfilled foreign obligation")
            used_targets = set()
            for joint in document.get("joints", []):
                path = joint["path"]
                require(len(path) >= 2 and path[0] == joint["root"] and path[-1] == joint["masonry_face"], "joint path endpoints disagree")
                normal = joint["normal"]
                require(abs(normal[0]) + abs(normal[1]) == 1, "non-cardinal mechanical facing")
                face, receiver = joint["frame_face"], joint["masonry_face"]
                require([receiver[0] - face[0], receiver[1] - face[1]] == normal, "native faces are not exactly adjacent and opposed")
                require(tuple(receiver) not in used_targets, "native receiver reused by multiple joints")
                used_targets.add(tuple(receiver))
                for step, point in enumerate(path):
                    x, y = point
                    inside = 0 <= x < width and 0 <= y < height
                    require(inside, "joint path escaped native canvas")
                    if inside:
                        index = y * width + x
                        require(final[index] in SOLID_MATERIALS and not protected[index], "joint path crosses non-solid, empty or protected native material")
                        expected_owner = 2 if step == len(path) - 1 else 1
                        require(document["ledger"][index][0] == expected_owner, "joint path lacks correct native owner")
                    if step:
                        require(abs(x - path[step-1][0]) + abs(y - path[step-1][1]) == 1, "joint material path disconnected")
                matching = []
                for offer in mosaic["boundary"]["hard"]:
                    if offer["instance"] != joint["mosaic_instance"] or offer["facing"] != [-normal[0], -normal[1]] or offer["family"] != joint["family"]:
                        continue
                    a, b = offer["a"], offer["b"]
                    if min(a[0], b[0]) <= receiver[0] <= max(a[0], b[0]) and min(a[1], b[1]) <= receiver[1] <= max(a[1], b[1]):
                        matching.append(offer)
                require(bool(matching), "joint has no exact typed native masonry receptor")
    metrics = document.get("metrics", {})
    for key, ceiling in (("frame_work", 2_000_000), ("mosaic_work", 2_000_000), ("solver_work", 4_000_000), ("shared_work", 2_000_000), ("total_charged_work", 10_000_000)):
        require(metrics.get(key, 0) <= ceiling, "registered resource ceiling exceeded: " + key)
    require(metrics.get("coordinator_created_cells", 0) == 0, "coordinator manufactured architecture")
    if "both_genteks_revised" in metrics:
        require(bool(metrics["both_genteks_revised"]) == bool(frame_footprints and mosaic_footprints), "two-sided native footprint revision claim unsupported")
    unresolved = sum(not receipt["foreign_joined"] for receipt in obligations) if final else None
    if document["can_apply"]:
        require(bool(final) and unresolved == 0 and document["status"] == "complete" and document["input"]["options"]["final_validation"], "unqualified partial/diagnostic proposal is Apply-authorized")
    return {"result": "FAIL" if errors else "PASS", "checks": checks, "errors": errors,
            "frame_changed_rounds": frame_changes, "mosaic_changed_rounds": mosaic_changes,
            "frame_footprint_changed_rounds": frame_footprints, "mosaic_footprint_changed_rounds": mosaic_footprints,
            "both_revised": bool(frame_footprints and mosaic_footprints), "still_required": unresolved}


def audit_matched_control(document, candidate, source):
    """Audit a fresh conditional rerun without treating it as candidate work."""
    errors, checks = [], 0

    def require(condition, message):
        nonlocal checks
        checks += 1
        if not condition and len(errors) < 80:
            errors.append(message)

    require(document.get("schema") == 6 and document.get("type") == "matched_final_frame_no_offer", "wrong matched control schema")
    require(document.get("source") == source, "matched control source differs")
    require(document.get("control_only") and document.get("offered_slots") == [] and not document.get("can_apply"), "control changed candidate scope or offers")
    final = candidate["rounds"][-1]
    request, accepted = document["request"], document["accepted_request"]
    count = request["width"] * request["height"]
    require(accepted == final["mosaic_request"], "matched control did not retain exact accepted MOSAIC request")
    for key in ("gentek", "seed", "source", "width", "height", "origin", "profile", "activation", "eligible", "protected", "transition", "context"):
        require(request[key] == accepted[key], "matched control altered accepted request field: " + key)
    require(request["neighbors"]["protected"] == accepted["neighbors"]["protected"], "matched control altered accepted neighbor protection")
    require(document["frame"] == final["frame"]["result"], "matched control does not retain exact final FRAME geometry/ports")
    require(request["neighbor_cells"] == document["frame"]["cells"], "matched control omitted final FRAME native context")
    require(request["neighbors"]["hard"] == document["frame"]["boundary"]["hard"], "matched control altered final FRAME typed ports")
    require(document["candidate_mosaic"] == final["mosaic"], "matched control comparison differs from accepted MOSAIC")
    require(document["shared_zone"] == candidate["input"]["shared_zone"], "matched control shared zone changed")
    frame_delta = sum(a != b for a, b in zip(candidate["rounds"][0]["frame"]["result"]["cells"], document["frame"]["cells"]))
    require(frame_delta > 0 and frame_delta == document["frame_changed_from_initial_cells"], "unmatched or inaccurate final FRAME change receipt")
    work = document["work"]
    require(work["preparation"] + work["generator"] <= 2_000_000 and work["solver_debit"] <= 4_000_000, "matched control exceeded independent budget")
    require(work["total"] == work["preparation"] + work["generator"] + work["solver_debit"], "matched control work receipt sum differs")
    debit = sum(attempt["work"] if attempt["work_observed"] else attempt["work_limit"] if attempt["attempted"] else 0
                for attempt in document["mosaic"]["attempts"])
    require(debit == work["solver_debit"], "matched control failed-solve debit missing")
    cells = document["mosaic"]["result"]["cells"]
    before = final["mosaic"]["result"]["cells"]
    material_diff_available = len(cells) == len(before) == count
    require(document["material_diff_available"] == material_diff_available, "matched control diff availability claim wrong")
    if material_diff_available:
        expected = [(i, a, b) for i, (a, b) in enumerate(zip(before, cells)) if a != b]
        actual = [(change["cell"], change["before"], change["after"]) for change in document["material_changes"]]
        require(expected == actual, "matched no-offer material diff differs from native arrays")
        for i, material in enumerate(cells):
            if material:
                require(0 < material < 132 and material != 10, "invalid matched native material ID")
                require(request["eligible"][i] and not request["protected"][i] and not request["context"][i] and
                        not request["neighbor_cells"][i] and not request["neighbors"]["protected"][i], "matched no-offer material escaped exact accepted geometry")
    categories, prior = document["mosaic"]["categories"], final["mosaic"]["categories"]
    category_diff_available = bool(categories) and len(categories) == len(prior)
    require(document["category_diff_available"] == category_diff_available, "matched control category diff availability claim wrong")
    if category_diff_available:
        expected = [(i, a, b) for i, (a, b) in enumerate(zip(prior, categories)) if a != b]
        require(expected == [(change["tile"], change["before"], change["after"]) for change in document["category_changes"]], "matched no-offer category diff differs")
    return {"result": "FAIL" if errors else "PASS", "checks": checks, "errors": errors,
            "material_diff_available": material_diff_available,
            "material_changes": len(document["material_changes"]) if material_diff_available else None,
            "category_changes": len(document["category_changes"]) if category_diff_available else None}


def enlarged(image):
    return image.resize((image.width * 2, image.height * 2), Image.Resampling.NEAREST)


def round_image(document, policy):
    q = document["input"]["frame"]
    panels = []
    for round_record in document["rounds"]:
        cells = combined_round(document, round_record)
        panels.append(panel(enlarged(raster(cells, q)), f"Round {round_record['number']}",
            f"FRAME occupied Δ{round_record['frame_footprint_changed']} / MOSAIC occupied Δ{round_record['mosaic_footprint_changed']}; material IDs Δ{round_record['frame_changed']} / {round_record['mosaic_changed']}"))
    damage = document.get("damage_derivative")
    if damage:
        cells = combined_round(document, damage)
        panels.append(panel(enlarged(raster(cells, q)), "Separate damage derivative",
                            f"Removed FRAME {damage['frame_footprint_changed']} / MOSAIC {damage['mosaic_footprint_changed']} cells; never a negotiation round"))
    if not panels:
        cells, caption = display_cells(document)
        panels = [panel(enlarged(raster(cells, q)), document["status"], caption)]
    return row(panels, policy + " · native material cells", f"{q['fixture']} / {q['profile']['name']} / seed {q['seed']} · {document['status']} · no physics claim · source {document['source']}")


def declined_image(document, policy):
    q = document["input"]["frame"]
    count = q["width"] * q["height"]
    context = q.get("context") or [0] * count
    panels = []
    for round_record in document["rounds"]:
        for gentek in ("frame", "mosaic"):
            proposed = round_record.get("proposed_" + gentek, {}).get("cells", [])
            accepted = round_record[gentek]["result"]["cells"]
            if len(proposed) == count and proposed != accepted:
                # Isolate the proposing owner's cells; overlapping rejected
                # claims must not be hidden by a painter's owner priority.
                cells = [cell or context[i] for i, cell in enumerate(proposed)]
                panels.append(panel(enlarged(raster(cells, q)), f"Round {round_record['number']} · proposed {gentek.upper()}",
                                    "Declined / rolled back; other Gentek omitted"))
    return row(panels, policy + " · retained declined native proposals", "Exact proposed arrays; these cells were not accepted · source " + document["source"]) if panels else None


def diagnostic_image(document, mode):
    q = document["input"]["frame"]
    cells, caption = display_cells(document)
    image = raster(cells, q, mode="transition")
    if mode == "joints" and document["rounds"]:
        last = document.get("damage_derivative") or document["rounds"][-1]
        seams = [{"joined": True, "cells": joint["path"], "a": joint["root"], "b": joint["masonry_face"]} for joint in document["joints"]]
        image = overlays(image, [q, document["input"]["mosaic"]], [last["frame"]["result"], last["mosaic"]["result"]], seams, scale=2)
        return panel(image, "Typed receptors / qualified paths", f"{len(document['joints'])} joints · protected space hatched")
    if document.get("ledger"):
        data = []
        for material, ledger in zip(cells, document["ledger"]):
            owner, _instance, _rule, _first, last, mask = ledger
            colour = OWNERS.get(owner, (255, 0, 255))
            if mode == "revisions" and material and owner in (1, 2):
                colour = (65 + last * 43, 180 - last * 23, 90 + 19 * mask.bit_count())
            data.append(colour)
        image.putdata(data)
    return panel(enlarged(image), "Ownership diagnostic" if mode == "owners" else "Accepted revision diagnostic",
                 "Blue FRAME / brown MOSAIC / gray environment" if mode == "owners" else "Colour = last changed round; raw ledger retains history")


def raw_link(root, file, prefix=""):
    return prefix + file + (".gz" if (root / (file + ".gz")).is_file() else "")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    campaign = json.loads((root / "campaign.json").read_text())
    causal_path = root / "causal/causal_summary.json"
    causal_summary = json.loads(causal_path.read_text()) if causal_path.is_file() else None
    if causal_summary:
        if (causal_summary.get("result") != "PASS" or causal_summary.get("source") != campaign["source"] or
                causal_summary.get("lane") != campaign["lane"]):
            raise ValueError("causal controls do not match the passing native campaign source/lane")
        causal_totals = causal_summary["policy_totals"]
        if (set(causal_totals) != set(campaign["registered_policies"]) or
                any(counts.get("cases") != campaign["expected_cases_per_policy"] for counts in causal_totals.values())):
            raise ValueError("causal controls lack complete registered policy/case coverage")
        identities = {(r["policy"], r["fixture"], r["profile"], r["seed"]) for r in causal_summary["records"]}
        if (len(identities) != len(causal_summary["records"]) or
                len(identities) != sum(c.get("nominal_both", 0) for c in causal_totals.values())):
            raise ValueError("causal controls have duplicate or missing nominal both-revision records")
    storage = json.loads((root / "storage.json").read_text()).get("records", {}) if (root / "storage.json").is_file() else {}
    images, pages = root / "images", root / "cases"
    images.mkdir(exist_ok=True)
    pages.mkdir(exist_ok=True)
    grouped = defaultdict(list)
    for record in campaign["records"]:
        grouped[record["case"]].append(record)
    policy_rows, audit_rows, comparisons, case_cards = [], [], [], []
    totals = defaultdict(Counter)
    expected_matched = Counter()
    checks = 0
    for case_id, records in sorted(grouped.items()):
        documents, hashes = {}, {}
        by_policy = {record["policy"]: record for record in records}
        case_html = [f"<!doctype html><meta charset='utf-8'><title>{html.escape(case_id)}</title><style>{CSS}</style>",
            f"<a href='../index.html'>All cases</a><h1>{html.escape(case_id)}</h1>",
            "<p>Exact native material arrays. Ownership, revision and joint views are diagnostics. These are not Workbench screenshots or physical support certificates.</p>"]
        for record in records:
            file = record["file"]
            if file not in documents:
                documents[file], hashes[file] = read_record(root, file, storage)
            document = documents[file]
            record = {**record, "joint_semantics": "current SWARM-004 native Solid receptor/facing/material-path validation" if document.get("schema") == 5 else
                      "not evaluated; independent no-offer control" if document.get("schema") == 6 else
                      "frozen legacy reported joint/slot count; not certified by the current Solid-bearing validator"}
            policy = record["policy"]
            totals[policy]["cases"] += 1
            totals[policy][record["status"]] += 1
            if document.get("schema") == 5:
                totals[policy]["qualified_joints"] += record["joints"]
                totals[policy]["native_candidate"] = 1
            elif document.get("schema") != 6:
                totals[policy]["reported_legacy_joints"] += record["joints"]
                totals[policy]["legacy_control"] = 1
            totals[policy]["reported_work"] += record["work"]
            if document.get("schema") == 6:
                parent = by_policy.get(document["candidate_policy"])
                if parent is None:
                    raise ValueError("Matched FRAME control lacks its candidate record: " + file)
                if parent["file"] not in documents:
                    documents[parent["file"]], hashes[parent["file"]] = read_record(root, parent["file"], storage)
                candidate = documents[parent["file"]]
                audit = audit_matched_control(document, candidate, campaign["source"])
                checks += audit["checks"]
                audit_rows.append({"file": file, "case": case_id, "policy": policy, **audit})
                totals[policy]["audit_failures"] += audit["result"] != "PASS"
                policy_rows.append({**record, "native_both_revised": False, "audit": audit["result"], "raw_sha256": hashes[file]})
                comparison_name = case_id + "__" + policy + ".png"
                q = request_for(document)
                control_cells = document["cells"] or [a or b for a, b in zip(document["frame"]["cells"], q["context"])]
                candidate_cells, _ = display_cells(candidate)
                row([panel(enlarged(raster(candidate_cells, q)), "Accepted candidate", document["candidate_policy"]),
                     panel(enlarged(raster(control_cells, q)), "Exact final FRAME / no slots", document["status"])],
                    "Matched final-FRAME native control", "Separate bounded control work; failed native solves retained; no joint or Apply claim · source " + document["source"]).save(images / comparison_name)
                case_html += [f"<section><h2>{html.escape(policy)} · {html.escape(document['status'])}</h2>",
                    f"<p>Control only: identical accepted eligibility, protection, shared zone and seed; final FRAME cells and ports; empty slots. Material differences: {audit['material_changes']}; category differences: {audit['category_changes']}. Audit: {audit['result']}.</p>",
                    f"<p>{html.escape(document['reason'])}</p><a href='../images/{comparison_name}'><img loading='lazy' src='../images/{comparison_name}' alt='Same final FRAME no-offer control'></a>",
                    f"<a href='{html.escape(raw_link(root, file, '../'))}'>Full control arrays, accepted masks and separate work receipts</a></section>"]
                comparisons.append({"case": case_id, "policy": document["candidate_policy"],
                    "control": "matched_final_frame_no_offer", "control_status": document["status"],
                    "material_changes": audit["material_changes"], "category_changes": audit["category_changes"],
                    "control_only_work": document["work"]["total"], "audit": audit["result"]})
                continue
            if document.get("schema") != 5:
                policy_rows.append({**record, "native_both_revised": False, "audit": "legacy-control; native suites separately qualify", "raw_sha256": hashes[file]})
                continue
            audit = audit_composition(document, campaign["source"])
            if bool(record["closure_evaluated"]) != (audit["still_required"] is not None):
                audit["result"] = "FAIL"
                audit["errors"].append("campaign closure availability differs from the final native ledger")
            # An early refused proposal has no final closure evaluation. Keep
            # null in exported comparisons instead of converting absence to 0.
            record = {**record, "still_required": audit["still_required"]}
            if document["rounds"] and document["rounds"][0]["frame"]["result"]["cells"] != document["rounds"][-1]["frame"]["result"]["cells"]:
                matched_policy = "matched_final_frame__" + policy
                expected_matched[matched_policy] += 1
                audit["checks"] += 1
                if matched_policy not in by_policy:
                    audit["result"] = "FAIL"
                    audit["errors"].append("changed FRAME lacks its exact final-FRAME no-offer control")
            checks += audit["checks"]
            audit_rows.append({"file": file, "case": case_id, "policy": policy, **audit})
            totals[policy]["both_revised"] += audit["both_revised"]
            totals[policy]["both_revised_with_joint"] += audit["both_revised"] and bool(document["joints"])
            totals[policy]["apply_authorized"] += document["can_apply"]
            if audit["still_required"] is not None:
                totals[policy]["still_required_on_final_proposals"] += audit["still_required"]
                totals[policy]["final_proposals"] += 1
            else:
                totals[policy]["closure_not_evaluated"] += 1
            totals[policy]["audit_failures"] += audit["result"] != "PASS"
            policy_rows.append({**record, "native_both_revised": audit["both_revised"], "audit": audit["result"], "raw_sha256": hashes[file]})
            filename = case_id + "__" + policy
            round_file = filename + "__rounds.png"
            round_image(document, policy).save(images / round_file)
            declined = declined_image(document, policy)
            declined_html = ""
            if declined:
                declined_file = filename + "__declined.png"
                declined.save(images / declined_file)
                declined_html = f"<details><summary>Retained declined native proposals</summary><a href='../images/{declined_file}'><img loading='lazy' src='../images/{declined_file}' alt='Declined native geometry, isolated by proposing owner'></a></details>"
            diagnostics = row([diagnostic_image(document, kind) for kind in ("owners", "revisions", "joints")],
                policy + " · diagnostic views", "Diagnostic colours are separate from the exact native palette above · source " + document["source"])
            diagnostic_file = filename + "__diagnostics.png"
            diagnostics.save(images / diagnostic_file)
            case_html += [f"<section><h2>{html.escape(policy)} · {html.escape(document['status'])}</h2>",
                f"<p>{html.escape(document['reason'])}</p><p>Stop: {html.escape(document['stop_reason'])}; Apply authorized: {document['can_apply']}; joints: {len(document['joints'])}; both revised: {audit['both_revised']}; audit: {audit['result']}.</p>",
                f"<a href='../images/{round_file}'><img loading='lazy' src='../images/{round_file}' alt='Exact native proposal sequence'></a>",
                f"<details><summary>Ownership, revision and joint diagnostics</summary><a href='../images/{diagnostic_file}'><img loading='lazy' src='../images/{diagnostic_file}' alt='Native ownership and joint diagnostics'></a></details>",
                declined_html,
                f"<a href='{html.escape(raw_link(root, file, '../'))}'>Complete native JSON and receipts</a><br><small>Raw SHA-256 {hashes[file]}</small>",
                "<details><summary>Round decisions and retained failures</summary><pre>" + html.escape(json.dumps([
                    {"round": r["number"], "reason": r["reason"], "frame_accepted": r["frame_accepted"],
                     "mosaic_accepted": r["mosaic_accepted"], "mosaic_proposal_reason": r.get("mosaic_proposal_reason", ""),
                     "frame_footprint_changed": r["frame_footprint_changed"], "mosaic_footprint_changed": r["mosaic_footprint_changed"],
                     "frame_material_changed": r["frame_changed"], "mosaic_material_changed": r["mosaic_changed"],
                     "frame_rejections": r["frame"]["rejections"]} for r in document["rounds"]], indent=2)) + "</pre></details></section>"]
            baseline = by_policy.get("E8")
            if baseline:
                comparisons.append({"case": case_id, "policy": policy, "candidate_composition_status": record["status"],
                    "E8_mosaic_solver_status": baseline["status"], "candidate_qualified_joints": record["joints"],
                    "E8_legacy_reported_joints": baseline["joints"], "candidate_still_required": audit["still_required"],
                    "E8_legacy_still_required": baseline["still_required"], "both_revised": audit["both_revised"],
                    "note": "FRAME/shared geometry and joint-certification contracts differ. Historical counts are retained but no numerical joint-gain claim is inferred."})
            for reference_policy in ("no_negotiation", "reciprocal_1"):
                reference = by_policy.get(reference_policy)
                if reference is None or policy == reference_policy:
                    continue
                if reference["file"] not in documents:
                    documents[reference["file"]], hashes[reference["file"]] = read_record(root, reference["file"], storage)
                reference_document = documents[reference["file"]]
                same_initial_frame = bool(document["rounds"] and reference_document["rounds"] and
                    document["rounds"][0]["frame"]["result"]["cells"] and
                    document["rounds"][0]["frame"]["result"]["cells"] == reference_document["rounds"][0]["frame"]["result"]["cells"])
                initial_masks_matched = all(document["input"][owner]["eligible"] == reference_document["input"][owner]["eligible"] for owner in ("frame", "mosaic")) and \
                    document["input"]["shared_zone"] == reference_document["input"]["shared_zone"] and \
                    document["input"]["options"]["shared_ownership"] == reference_document["input"]["options"]["shared_ownership"]
                comparisons.append({"case": case_id, "policy": policy, "reference_policy": reference_policy,
                    "candidate_status": record["status"], "reference_status": reference["status"],
                    "candidate_qualified_joints": record["joints"], "reference_qualified_joints": reference["joints"],
                    "qualified_joint_delta": record["joints"] - reference["joints"],
                    "candidate_still_required": audit["still_required"],
                    "reference_still_required": reference["still_required"] if reference["closure_evaluated"] else None,
                    "both_revised": audit["both_revised"], "same_final_joint_contract": policy != "validation_off_diagnostic",
                    "initial_frame_matched": same_initial_frame, "initial_masks_matched": initial_masks_matched,
                    "note": "Same registered fixture/profile/seed; actual initial geometry/mask equality and validator compatibility are reported. Failed cases retained."})
        comparison_policies = list(dict.fromkeys(["E8", "no_negotiation", "reciprocal_1", campaign.get("selected_policy") or "reciprocal_2"]))
        overview = []
        for policy in comparison_policies:
            record = by_policy.get(policy)
            if not record:
                continue
            document = documents[record["file"]]
            q = request_for(document)
            if document.get("schema") == 5:
                cells, caption = display_cells(document)
            else:
                cells, caption = lookup(document, record["view"]), "frozen implementation control"
            overview.append(panel(enlarged(raster(cells, q)), policy + " · " + record["status"], caption))
        if overview:
            overview_file = case_id + "__controls.png"
            row(overview, case_id, "Same seed/profile/fixture · retained negative outcomes · exact native palette · source " + campaign["source"]).save(images / overview_file)
            case_html.insert(4, f"<a href='../images/{overview_file}'><img src='../images/{overview_file}' alt='Same-seed native controls'></a>")
        (pages / (case_id + ".html")).write_text("\n".join(case_html))
        case_cards.append(f"<li data-case='{html.escape(case_id)}'><a href='cases/{case_id}.html'>{html.escape(case_id)}</a></li>")
    expected = campaign["expected_cases_per_policy"]
    missing = {policy: counts["cases"] for policy, counts in totals.items()
               if counts["cases"] != (expected_matched[policy] if policy.startswith("matched_final_frame__") else expected)}
    for policy, count in expected_matched.items():
        if totals[policy]["cases"] != count:
            missing[policy] = totals[policy]["cases"]
    for policy in [*campaign["registered_policies"], "A", "B", "C", "cap4", "E8", "E8_hard_only"]:
        if policy not in totals:
            missing[policy] = 0
    failed = [row for row in audit_rows if row["result"] != "PASS"]
    summary = {"schema": 1, "programme": "GENTEK-SWARM-004", "source": campaign["source"], "lane": campaign["lane"],
        "matched_cases": len(grouped), "expected_cases_per_policy": expected, "policy_totals": {p: dict(c) for p, c in totals.items()},
        "expected_final_frame_controls": dict(expected_matched),
        "causal_policy_totals": causal_summary["policy_totals"] if causal_summary else None,
        "audit": {"result": "FAIL" if failed or missing or campaign["result"] != "PASS" else "PASS", "checks": checks,
                  "failed_cases": len(failed), "missing_or_incomplete_policies": missing, "native_campaign_result": campaign["result"]},
        "scope": "Exact native material and provenance evidence; no physics, Godot or Windows acceptance",
        "comparison_limit": "E8 comparisons change FRAME/shared geometry; no attribution to solver improvement. Failed cases remain counted. Both revised is nominal occupied-footprint change; offer causality requires separately matched no-offer and frozen-peer controls. Unevaluated closure is unknown, never zero."}
    (root / "reciprocal_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    (root / "reciprocal_audit.json").write_text(json.dumps({"summary": summary["audit"], "cases": audit_rows}, indent=2) + "\n")
    (root / "reciprocal_comparisons.json").write_text(json.dumps(comparisons, indent=2) + "\n")
    if policy_rows:
        with (root / "reciprocal_metrics.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(policy_rows[0]))
            writer.writeheader()
            writer.writerows(policy_rows)
    table = "<table><thead><tr><th>Policy</th><th>Cases</th><th>Complete</th><th>Blocked</th><th>UNSAT</th><th>Exhausted</th><th>Nominal both revised</th><th>Nominal both + joint</th><th>Causal both + joint</th><th>Causal Apply</th><th>Closure evaluated</th><th>Closure unknown</th><th>Legacy reported joints</th><th>SWARM-004 qualified joints</th><th>Apply</th><th>Audit errors</th></tr></thead><tbody>"
    for policy, counts in totals.items():
        causal_counts = causal_summary["policy_totals"].get(policy) if causal_summary else None
        values = [policy, counts["cases"], counts["complete"], counts["blocked"], counts["unsat"], counts["exhausted"],
                  counts["both_revised"], counts["both_revised_with_joint"],
                  causal_counts.get("causal_both_with_joint", 0) if causal_counts is not None else "—",
                  causal_counts.get("causal_complete", 0) if causal_counts is not None else "—",
                  counts["final_proposals"] if counts["native_candidate"] else "—",
                  counts["closure_not_evaluated"] if counts["native_candidate"] else "—",
                  counts["reported_legacy_joints"] if counts["legacy_control"] else "—",
                  counts["qualified_joints"] if counts["native_candidate"] else "—", counts["apply_authorized"], counts["audit_failures"]]
        table += "<tr>" + "".join(f"<td>{html.escape(str(value))}</td>" for value in values) + "</tr>"
    table += "</tbody></table>"
    page = f"<!doctype html><meta charset='utf-8'><title>SWARM-004 native evidence</title><style>{CSS}</style><h1>SWARM-004 · reciprocal native evidence</h1>"
    page += f"<p>Draft / HOLD · {html.escape(campaign['lane'])} · audit {summary['audit']['result']} · source <code>{html.escape(campaign['source'])}</code></p>"
    page += "<p>Original material-cell arrays rendered with the unchanged native material catalogue. Diagnostic ownership and joint views are labelled separately. No physical stability or Workbench acceptance is inferred.</p>"
    page += "<p>Complete MOSAIC and complete foreign-obligation closure are different. Legacy control complete counts describe their native solver status; SWARM-004 complete includes its composition gates. Every failure stays in the comparison.</p>"
    page += "<p>Frozen legacy joint counts and current SWARM-004 qualified joints use different contracts. The latter require native Solid materials at the receiver and along the witnessed path; the original Stone13 bands are Powder. Historical values remain exact, and are shown separately.</p>"
    page += "<p>Nominal both revised means both Genteks changed their occupied-cell footprints in accepted rounds. It does not establish that offers caused those changes: preserved masks can also change the result. Causal claims require matched-mask no-offer and frozen-peer controls. Material-only substitutions never establish occupied-footprint revision. Early refusals without a final closure ledger have unknown closure, not zero requirements.</p>"
    if causal_summary:
        page += "<p><a href='causal/causal_summary.json'>Both-direction counterfactual controls and raw native array paths</a>. Their work is independently budgeted and excluded from candidate totals. Unavailable controls remain explicit.</p>"
    page += "<div class='tablewrap'>" + table + "</div><p><a href='reciprocal_metrics.csv'>Metrics CSV</a> · <a href='reciprocal_summary.json'>Summary</a> · <a href='reciprocal_audit.json'>Direct native array audit</a> · <a href='reciprocal_comparisons.json'>All control comparisons</a> · <a href='campaign.json'>Native campaign</a></p>"
    page += "<h2>Every matched case</h2><input id='filter' placeholder='Filter fixture, profile or seed'><ul id='cases'>" + "".join(case_cards) + "</ul>"
    page += "<script>document.getElementById('filter').addEventListener('input',e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('#cases li').forEach(x=>x.hidden=!x.dataset.case.toLowerCase().includes(q));});</script>"
    (root / "index.html").write_text(page)
    print(json.dumps(summary, indent=2))
    return 1 if summary["audit"]["result"] != "PASS" else 0


if __name__ == "__main__":
    raise SystemExit(main())
