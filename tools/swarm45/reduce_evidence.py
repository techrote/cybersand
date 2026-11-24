"""Recompute scoped native and graphical admission from original child evidence.

Summary booleans are conclusions to compare, never substitutes for the named
process receipts, original logs, native documents, material planes or PNGs.
"""
from __future__ import annotations

import ast
import hashlib
import json
import math
from pathlib import Path
import re
import struct

import runtime_custody as custody
from shared import (HEADLESS_CASES, graphical_processes, historical_refresh_errors, input_report_errors,
                    legacy, load, ui_report_errors)

TRANSPORT = {
    "v1-v2-request": "native/experiments/gentek_swarm/test_reciprocal_io.py",
    "v3-request": "tools/swarm005/test_v3_request.py",
    "v4-request": "tools/swarm006/test_v4_request.py",
}


def evidence_file(directory: Path, records: dict, name: str) -> Path:
    """Every consumed original must be named in the outer integrity inventory."""
    custody.require(isinstance(records, dict) and name in records, "Original evidence is not inventoried: " + name)
    custody.verify_inventory(directory, {name: records[name]})
    return directory / name


def document(directory: Path, records: dict, name: str) -> dict:
    path = evidence_file(directory, records, name)
    value = legacy.read_report(path)
    custody.require(bool(value), "Missing/malformed original JSON object: " + name)
    return value


def completed_process(directory: Path, records: dict, row: dict, relative: str, timeout: int) -> str:
    """Join a summary row to its unchanged process receipt and actual log."""
    original = document(directory, records, relative + "-process.json")
    custody.require(original == row, "Summary differs from original process receipt: " + relative)
    custody.require(row.get("passed") is True and type(row.get("returncode")) is int and row["returncode"] == 0
                    and row.get("timed_out") is False and row.get("child_reaped") is True
                    and row.get("timeout_seconds") == timeout and row.get("validation_errors", []) == []
                    and row.get("errors", []) == [] and row.get("error") in (None, "")
                    and type(row.get("process_id")) is int and row["process_id"] > 0
                    and type(row.get("wall_seconds")) in (int, float) and math.isfinite(row["wall_seconds"])
                    and row["wall_seconds"] >= 0,
                    "Original child did not complete successfully: " + relative)
    log = evidence_file(directory, records, relative + ".log")
    custody.require(row.get("log_sha256") == custody.sha(log), "Process receipt names a different original log: " + relative)
    text = log.read_text(encoding="utf-8", errors="replace")
    custody.require(not legacy.ERRORS.search(text), "Original child log contains engine/script errors: " + relative)
    return text


def json_marker(text: str, marker: str) -> dict:
    try:
        rows = [json.loads(line[len(marker):]) for line in text.splitlines() if line.startswith(marker)]
    except ValueError as error:
        raise ValueError("Malformed original marker: " + marker) from error
    custody.require(len(rows) == 1 and isinstance(rows[0], dict), "Missing/duplicate original marker: " + marker)
    return rows[0]


def ui_process_report(directory: Path, records: dict, row: dict, text: str,
                      relative: str, report_hash: bool = True) -> dict:
    """Join byte-original UI evidence without accepting a wrapper PID alias.

    A matching report and stdout marker alone do not prove that their reported
    process is the launched child. Keep exact PID equality on both platforms.
    Split the diagnostics so an absent parent/child witness cannot be mistaken
    for a path representation problem or corrected by relabelling old reports.
    """
    original = document(directory, records, relative + ".json")
    if report_hash:
        custody.require(row.get("report_sha256") == custody.sha(directory / (relative + ".json")),
                        "Original UI report hash differs from process receipt: " + relative)
    custody.require(row.get("process_id") == original.get("process_id"),
                    "Original UI process identity differs from report (wrapper/child evidence is not interchangeable): " + relative)
    custody.require(json_marker(text, "SWARM004_WORKBENCH ") == original,
                    "Original UI report differs from its unique original log marker: " + relative)
    return original


def command_path(value: object) -> str:
    custody.require(isinstance(value, str) and bool(value), "Missing original process command path")
    return value.replace("\\", "/")


def script_hash(receipt: dict, relative: str) -> str:
    """The verified current checkout supplies the producer's exact test bytes."""
    path = custody.ROOT / relative
    custody.require(receipt.get("build_inputs_sha256", {}).get(relative) == custody.canonical(path),
                    "Runtime receipt does not bind the executed test source: " + relative)
    return custody.sha(path)


def transport_request(name: str, compact: int, supported: int, v4) -> str:
    """V3 uses the same retained profiles/territory as the V4 paired control."""
    lines = v4.request(name, False, True).splitlines()
    if compact or supported:
        lines[5] = f"{compact} {supported}"
    else:
        lines[0] = "SWARM004 1"
        del lines[4:6]
    return "\n".join(lines) + "\n"


def transport_native(value: dict, source: str, definition: str, width: int, height: int, request: str) -> None:
    custody.require(value.get("source") == source and value.get("type") == "reciprocal_assembly"
                    and value.get("status") in ("complete", "blocked", "unsat", "exhausted", "oscillation")
                    and type(value.get("can_apply")) is bool, "Raw transport native source/status/authority is invalid")
    lines = request.splitlines()
    parameters = dict(zip(("variation", "irregularity", "clutter", "destruction", "branching", "environment_affinity", "cohesion"),
                          map(float, lines[3].split()[:7])))
    profile = {"name": lines[2], **parameters}
    for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
        item = value.get("input", {}).get(owner, {})
        custody.require(item.get("source") == source and item.get("definition") == prefix + definition
                        and item.get("width") == width and item.get("height") == height
                        and item.get("seed") == 605 and item.get("origin") == [0, 0] and item.get("profile") == profile,
                        "Raw transport native input definition/source/extent changed: " + owner)
    cells = value.get("cells")
    obligations = value.get("obligations")
    custody.require(isinstance(cells, list) and len(cells) in (0, width * height)
                    and all(type(cell) is int and 0 <= cell <= 65535 for cell in cells)
                    and isinstance(value.get("joints"), list) and isinstance(obligations, list)
                    and all(isinstance(item, dict) and item.get("state") in ("FOREIGN_JOINED", "STILL_REQUIRED") for item in obligations),
                    "Raw transport native cells/obligations are malformed")
    closure = legacy.closure_outcome(value.get("status"), value.get("metrics"))
    if value["can_apply"]:
        custody.require(value["status"] == "complete" and len(cells) == width * height and closure == {"closure_evaluated": True, "remaining": 0}
                        and all(item["state"] == "FOREIGN_JOINED" and item.get("foreign_joined") is True for item in obligations),
                        "Raw transport Apply lacks complete native foreign closure")


def validate_transport(directory: Path, records: dict, receipt: dict, version: str, log: str) -> None:
    """Reparse every fixed request/native response and derive the original rows."""
    v4 = load("swarm456_transport_original_cases", "tools/swarm006/test_v4_request.py")
    folder = directory / version
    source = "swarm005-v3-source-matched-regression" if version == "v3" else receipt["source_commit"]
    expected_files, rows = {"summary.json"}, []

    def execute(label: str, request: str, width: int, height: int, valid: bool = True) -> dict:
        path = evidence_file(directory, records, version + "/" + label + ".txt")
        custody.require(path.read_text(encoding="utf-8") == request, "Original fixed transport request changed: " + label)
        expected_files.add(label + ".txt")
        child_log = None
        if version == "v4":
            child_log = evidence_file(directory, records, version + "/" + label + ".log").read_text(encoding="utf-8")
            expected_files.add(label + ".log")
        if not valid:
            custody.require(not (folder / (label + ".json")).exists(), "Malformed transport request produced native output: " + label)
            if child_log is not None:
                refusal = ("unexpected trailing reciprocal request tokens" if label == "trailing"
                           else "reciprocal integer outside its declared range")
                custody.require(child_log == refusal + "\n", "Original transport child log lacks the exact request refusal: " + label)
            return {}
        value = document(directory, records, version + "/" + label + ".json")
        expected_files.add(label + ".json")
        transport_native(value, source, receipt["native_definition_sha256"], width, height, request)
        if child_log is not None:
            completion = f"RECIPROCAL_REQUEST status={value['status']} joints={len(value['joints'])} apply={int(value['can_apply'])}\n"
            custody.require(child_log == completion, "Original transport child log differs from native completion: " + label)
        return value

    if version == "v3":
        found = {}
        for name in ("viaduct_like", "irregular_megastructure"):
            width, height, _parameters = v4.CASES[name]
            for compact, supported in ((0, 0), (1, 0), (0, 1), (1, 1)):
                label = f"{name}-cap{compact}-receptor{supported}"
                value = execute(label, transport_request(name, compact, supported, v4), width, height)
                options = value["input"].get("options", {})
                remaining = value.get("metrics", {}).get("still_required")
                custody.require(value.get("schema") == 5 and options.get("compact_native_termination") is bool(compact)
                                and options.get("supported_native_receptors") is bool(supported)
                                and options.get("rounds") == 2 and options.get("shared_ownership") is True
                                and type(remaining) is int and value["can_apply"] == (value["status"] == "complete" and remaining == 0),
                                "Raw V3 paired native options/closure differ: " + label)
                row = {"profile": name, "compact": compact, "supported": supported, "status": value["status"],
                       "can_apply": value["can_apply"], "still_required": remaining, "joints": len(value["joints"]),
                       "native_material_cells": sum(cell != 0 for cell in value["cells"])}
                rows.append(row); found[name, compact, supported] = row
        custody.require(found["irregular_megastructure", 0, 0]["status"] == "blocked"
                        and found["irregular_megastructure", 1, 0]["can_apply"] is True
                        and found["irregular_megastructure", 1, 1]["can_apply"] is True
                        and found["viaduct_like", 1, 1]["status"] == "blocked", "Original V3 paired controls changed")
        reference = transport_request("irregular_megastructure", 1, 1, v4).splitlines()
        for name in ("bad_bool", "swarm005_wrong_version", "swarm004_wrong_version", "trailing"):
            invalid = reference.copy()
            if name == "bad_bool": invalid[5] = "2 1"
            elif name == "swarm005_wrong_version": invalid[0] = "SWARM005 2"
            elif name == "swarm004_wrong_version": invalid[0] = "SWARM004 3"
            else: invalid.append("9999")
            execute(name, "\n".join(invalid) + "\n", 192, 112, False)
        summary = rows
    else:
        for name, (width, height, _parameters) in v4.CASES.items():
            values = {}
            for label, recovery, old in (("v3", False, True), ("v4-off", False, False), ("v4-on", True, False), ("v4-replay", True, False)):
                value = execute(name + "-" + label, v4.request(name, recovery, old), width, height)
                options = value["input"].get("options", {})
                custody.require(options.get("compact_native_termination") is True and options.get("supported_native_receptors") is True
                                and options.get("rounds") == 2 and options.get("shared_ownership") is True, "Raw V4 options changed")
                bounds = {"frame_work": 2000000, "mosaic_work": 2000000, "solver_work": 4000000, "shared_work": 2000000}
                metrics = value.get("metrics", {})
                custody.require(all(type(metrics.get(field)) is int and 0 <= metrics[field] <= limit for field, limit in bounds.items())
                                and sum(metrics[field] for field in bounds) <= 10000000, "Raw V4 charged work exceeded fixed bounds")
                if value["can_apply"]:
                    custody.require(all(item.get("local_terminated") is False for item in value["obligations"]), "Raw V4 Apply reused local termination")
                values[label] = value
            off, candidate = values["v4-off"], values["v4-on"]
            custody.require(off == values["v3"] and off.get("schema") == 5 and candidate == values["v4-replay"]
                            and candidate.get("schema") == 6 and candidate.get("programme") == "GENTEK-SWARM-006"
                            and candidate.get("identity") == "gentek_swarm_006_negotiated_recovery_v1"
                            and candidate["input"]["options"].get("negotiated_recovery") is True
                            and candidate["input"]["options"].get("recovery_offers") is True,
                            "Raw V4 OFF equivalence, recovery identity or exact replay failed")
            rounds = candidate.get("rounds")
            custody.require(isinstance(rounds, list) and all(isinstance(row, dict)
                            and isinstance(row.get("recovery_frontier"), list) and len(row["recovery_frontier"]) <= 8
                            and isinstance(row.get("mosaic_recovery_receipts"), list) and len(row["mosaic_recovery_receipts"]) <= 8
                            and isinstance(row.get("recovery_attempts"), list) and len(row["recovery_attempts"]) <= 520
                            and type(row.get("recovery_work")) is int and 0 <= row["recovery_work"] <= 2000000 for row in rounds),
                            "Raw V4 recovery bounds differ")
            for label, value in (("off", off), ("on", candidate)):
                plane = b"".join(cell.to_bytes(2, "little") for cell in value["cells"])
                closure = legacy.closure_outcome(value["status"], value["metrics"])
                import hashlib
                rows.append({"case": name, "recovery": label, "status": value["status"], "can_apply": value["can_apply"],
                    "stop_reason": value["stop_reason"], "native_cells": sum(cell != 0 for cell in value["cells"]),
                    "joints": len(value["joints"]), "obligations": len(value["obligations"]),
                    "closure_evaluated": closure["closure_evaluated"], "unresolved": closure["remaining"],
                    "retained_obligation_unresolved": sum(item["state"] == "STILL_REQUIRED" for item in value["obligations"]),
                    "material_sha256": hashlib.sha256(plane).hexdigest(), "metrics": value["metrics"]})
        for label, header, flags in (("wrong_version", "SWARM006 3", "1 1 1"), ("wrong_family", "SWARM005 4", "1 1 1"),
                                      ("bad_bool", "SWARM006 4", "1 1 2"), ("missing_bool", "SWARM006 4", "1 1"),
                                      ("trailing", "SWARM006 4", "1 1 1")):
            lines = v4.request("industrial", True).splitlines(); lines[0], lines[5] = header, flags
            if label == "trailing": lines.append("999")
            execute(label, "\n".join(lines) + "\n", 192, 112, False)
        summary = {"source": source, "synthetic_blank_world": True, "owner_nvidia_acceptance": "pending", "rows": rows}
    path = evidence_file(directory, records, version + "/summary.json")
    custody.require(json.loads(path.read_bytes()) == summary
                    and [json.loads(line) for line in log.splitlines() if line.startswith("{")] == rows,
                    "Transport summary/original stdout differs from complete native raw reduction: " + version)
    custody.require({path.relative_to(folder).as_posix() for path in folder.rglob("*") if path.is_file()} == expected_files,
                    "Transport raw request/result/refusal inventory differs: " + version)


def validate_native(directory: Path, value: dict, receipt: dict) -> None:
    from native_checks import marker_valid
    import linux_floor

    records = value["files_sha256"]
    modes = ("strict", "sanitized") if receipt["platform"] == "linux" else ("strict",)
    expected = [(mode, name) for mode in modes for name in custody.NATIVE_TESTS]
    rows = value["results"]
    custody.require([row.get("case") for row in rows] == [mode + "-" + name for mode, name in expected] + list(TRANSPORT),
                    "Native ordered strict/sanitizer/request inventory is incomplete")
    custody.require(value.get("strict_tests") == list(custody.NATIVE_TESTS)
                    and value.get("sanitizers") == (["address", "undefined"] if receipt["platform"] == "linux" else []),
                    "Native declared suite/sanitizer scope changed")
    for row, (mode, name) in zip(rows, expected):
        text = completed_process(directory, records, row, row["case"], 180)
        binary = custody.names(receipt["platform"])["tests"][list(custody.NATIVE_TESTS).index(name)]
        relative = binary if mode == "strict" else "sanitized/" + binary
        command = row.get("command")
        custody.require(row.get("mode") == mode and row.get("binary_sha256") == receipt["files"][relative]["sha256"]
                        and isinstance(command, list) and len(command) == 1
                        and command_path(command[0]).endswith("/" + relative)
                        and (mode == "sanitized" or "/sanitized/" not in command_path(command[0]))
                        and marker_valid(name, text), "Native binary, mode or complete suite marker changed: " + row["case"])
    for row, (label, script) in zip(rows[len(expected):], TRANSPORT.items()):
        text = completed_process(directory, records, row, label, 180)
        command = row.get("command", [])
        expected_tail = ["--binary", None, "-v"] if label == "v1-v2-request" else ["--exe", None, "--output", None]
        if label == "v4-request":
            expected_tail += ["--source", receipt["source_commit"]]
        custody.require(len(command) == 2 + len(expected_tail) and command_path(command[1]).endswith("/" + script)
                        and all(expected is None or actual == expected for actual, expected in zip(command[2:], expected_tail))
                        and command_path(command[3]).endswith("/" + receipt["cli"])
                        and row.get("binary_sha256") == receipt["files"][receipt["cli"]]["sha256"]
                        and row.get("test_script_sha256") == script_hash(receipt, script),
                        "Transport command/source/CLI binding changed: " + label)
        if label == "v1-v2-request":
            syntax = ast.parse((custody.ROOT / script).read_bytes())
            tests = [(group.name, method.name) for group in syntax.body if isinstance(group, ast.ClassDef)
                     for method in group.body if isinstance(method, ast.FunctionDef) and method.name.startswith("test_")]
            custody.require(len(re.findall(r"^Ran " + str(len(tests)) + r" tests in .+$", text, re.MULTILINE)) == 1
                            and len(re.findall(r"^OK$", text, re.MULTILINE)) == 1 and "skipped" not in text.lower(),
                            "V1/V2 real-binary tests were missing, skipped or failed")
            for group, name in tests:
                pattern = r"^" + re.escape(name) + r" \((?:__main__\.)?" + re.escape(group + "." + name) + r"\) \.\.\. ok$"
                custody.require(len(re.findall(pattern, text, re.MULTILINE)) == 1, "Missing original V1/V2 test completion: " + name)
        else:
            marker = ("PASS SWARM005_V3_NATIVE_SHARED: eight paired native cases and four denied malformed requests"
                      if label == "v3-request" else "PASS SWARM006_V4_NATIVE: four paired controls, exact replay, five malformed-request refusals")
            custody.require(text.splitlines().count(marker) == 1, "Missing complete original transport marker: " + label)
            validate_transport(directory, records, receipt, "v3" if label == "v3-request" else "v4", text)
    if receipt["platform"] == "linux":
        floor = document(directory, records, "linux-runtime-floor.json")
        custody.require(value.get("linux_runtime_floor") == floor and floor.get("passed") is True
                        and floor.get("errors") == []
                        and floor.get("ceilings") == {key: ".".join(map(str, limit)) for key, limit in linux_floor.CEILINGS.items()}
                        and [row.get("file") for row in floor.get("binaries", [])] == [receipt["extension"], receipt["cli"]],
                        "Linux runtime floor original inventory/receipt differs")
        for row in floor["binaries"]:
            name = row["file"] + ".objdump-T.log"
            table = evidence_file(directory, records, name)
            custody.require(row.get("symbol_table") == name and row.get("symbol_table_sha256") == custody.sha(table)
                            and row.get("sha256") == receipt["files"][row["file"]]["sha256"] and row.get("passed") is True
                            and row.get("maximum_imported_versions") == linux_floor.symbol_versions(table.read_text(encoding="utf-8")),
                            "Linux original symbol evidence failed: " + row["file"])


def graphical_command(row: dict, script: str | None, graphical: bool) -> None:
    command = row.get("command", [])
    custody.require(isinstance(command, list) and all(isinstance(item, str) for item in command)
                    and "--path" in command and ("--headless" not in command) is graphical,
                    "Graphical/headless original process command changed")
    if script is None:
        custody.require(command[-3:] == ["--headless", "--editor", "--quit"], "Original import command changed")
    else:
        custody.require(command[-2:] == ["--script", "res://" + script], "Original test script command changed")


def native_patch_identity(before: bytes, after: bytes, extent: list, native: dict,
                          recipe: dict, operation: str) -> dict:
    """Reconstruct the native v1 patch digest from full readbacks and raw guards.

    Encoding is defined by workbench_authoring_patch.hpp::stage and
    water_normalization.hpp::CanonicalHash: fixed-width little-endian integers,
    row-major changed cells, then the original protected coordinates.
    """
    custody.require(extent in ([512, 512], [2048, 2048]) and all(type(n) is int for n in extent)
                    and len(before) == len(after) == extent[0] * extent[1] * 2,
                    "Native receipt lacks complete source/installed material planes")
    frame = native.get("input", {}).get("frame", {})
    width, height, origin = frame.get("width"), frame.get("height"), frame.get("origin")
    custody.require(type(width) is int and type(height) is int and width > 0 and height > 0
                    and isinstance(origin, list) and len(origin) == 2 and all(type(n) is int for n in origin)
                    and 0 <= origin[0] <= extent[0] - width and 0 <= origin[1] <= extent[1] - height
                    and recipe.get("size") == [width, height] and recipe.get("origin") == origin,
                    "Native receipt crop differs from its original native recipe")
    protected, cells, ledger = frame.get("protected"), native.get("cells"), native.get("ledger")
    custody.require(all(isinstance(value, list) and len(value) == width * height for value in (protected, cells, ledger))
                    and all(type(value) is int and value in (0, 1) for value in protected)
                    and operation in ("build", "remove"), "Native receipt original patch/guard arrays are malformed")
    expected, guards = [], []
    for index, (material, owner) in enumerate(zip(cells, ledger)):
        x, y = origin[0] + index % width, origin[1] + index // width
        custody.require(type(material) is int and 0 <= material <= 255 and isinstance(owner, list)
                        and len(owner) == 6 and type(owner[0]) is int and 0 <= owner[0] <= 3,
                        "Native receipt original cell ownership is malformed")
        if protected[index]:
            guards.append((x, y))
        if owner[0] in (1, 2):
            custody.require(material != 0 and not protected[index], "Native receipt construction intersects original protection")
            expected.append((x, y, 0, material) if operation == "build" else (x, y, material, 0))
    changed = [(index % extent[0], index // extent[0], old[0], new[0])
               for index, (old, new) in enumerate(zip(struct.iter_unpack("<H", before), struct.iter_unpack("<H", after)))
               if old != new]
    custody.require(changed == expected and 0 < len(changed) <= 262144 and len(guards) <= 262144,
                    "Native receipt patch differs from actual source/installed material changes")
    tag = b"cybersand-workbench-authoring-patch-v1"
    digest = hashlib.sha256(struct.pack("<I", len(tag)) + tag)
    digest.update(struct.pack("<BIIQ", 1 if operation == "build" else 2, *extent, len(changed)))
    for cell in changed:
        digest.update(struct.pack("<iiBB", *cell))
    digest.update(struct.pack("<Q", len(guards)))
    for point in guards:
        digest.update(struct.pack("<ii", *point))
    return {"changed_cells": len(changed), "protected_cells": len(guards), "patch_sha256": digest.hexdigest()}


def validate_native_transactions(directory: Path, name: str, reports: dict, runtime: dict) -> None:
    """Bind acknowledgements to independent captures, full native planes and the saved receipt."""
    primary = reports.get("create", reports.get("evaluate", {}))
    transactions = primary.get("native_transactions")
    custody.require(isinstance(transactions, dict) and set(transactions) == {"first_apply", "undo", "reapply"}
                    and reports.get("reopen", {}).get("native_transactions") == {},
                    "Native receipt lacks the three original transaction witnesses or fresh read-only Reopen")
    recipe = primary["native_recipe"]
    extent = recipe.get("world_extent", [512, 512])
    numeric = ("schema", "changed_cells", "protected_cells", "source_native_generation", "source_revision", "source_tick")
    fields = {*numeric, "operation", "proposal_sha256", "patch_sha256", "semantics"}
    previous_installed = None
    for label, operation, before_stage, after_stage, native_stage in (
            ("first_apply", "build", "baseline", "applied", "initial"),
            ("undo", "remove", "applied", "undone", "initial"),
            ("reapply", "build", "undone", "regenerated", "regenerated")):
        witness = transactions[label]
        custody.require(isinstance(witness, dict) and set(witness) == {
            "operation", "source_capture", "installed_capture", "receipt", "source_material_sha256", "installed_material_sha256"}
            and witness.get("operation") == operation, "Native transaction witness is incomplete: " + label)
        capture, installed, receipt = witness["source_capture"], witness["installed_capture"], witness["receipt"]
        for value in (capture, installed):
            custody.require(isinstance(value, dict) and set(value) == {"native_generation", "revision", "tick", "extent"}
                            and value.get("extent") == extent and all(type(n) is int for n in value["extent"])
                            and all(type(value.get(key)) is int and 0 <= value[key] <= 2**63 - 1
                                    for key in ("native_generation", "revision", "tick")),
                            "Native transaction lacks its independent source/installed capture: " + label)
        custody.require(installed["native_generation"] > capture["native_generation"]
                        and (previous_installed is None or capture == previous_installed),
                        "Native transaction captures do not form the actual installed generation sequence: " + label)
        previous_installed = installed
        custody.require(isinstance(receipt, dict) and set(receipt) == fields
                        and all(type(receipt.get(key)) is int for key in numeric)
                        and receipt.get("schema") == 1 and receipt.get("operation") == operation
                        and receipt.get("semantics") == "retained-native-transaction-v1"
                        and all(receipt.get("source_" + key) == capture[key] for key in ("native_generation", "revision", "tick")),
                        "Native receipt schema, semantics or captured source identity differs: " + label)
        before_path, after_path = (directory / (stage + "-native.le16") for stage in (before_stage, after_stage))
        before, after = before_path.read_bytes(), after_path.read_bytes()
        custody.require(witness["source_material_sha256"] == hashlib.sha256(before).hexdigest()
                        and witness["installed_material_sha256"] == hashlib.sha256(after).hexdigest(),
                        "Native transaction capture differs from original readback: " + label)
        native_path = directory / (native_stage + "-result.json")
        custody.require(receipt.get("proposal_sha256") == custody.sha(native_path),
                        "Native receipt proposal differs from original native output: " + label)
        derived = native_patch_identity(before, after, extent, legacy.read_report(native_path), recipe, operation)
        custody.require(all(receipt.get(key) == value for key, value in derived.items()),
                        "Native receipt count, protection or patch digest differs from native readback: " + label)
    final = transactions["reapply"]["receipt"]
    custody.require(primary.get("native_receipt") == reports["reopen"].get("native_receipt") == final,
                    "Terminal and reopened native receipts differ from the actual reapply acknowledgement")
    map_name = (name + "-synthetic-eval" if legacy.EXAMPLES[name].get("evaluate") else
                "swarm005-v3-irregular-evaluation" if name == "swarm005_irregular" else "swarm004-interactive-evaluation")
    profile = "roaming/Godot" if runtime["platform"] == "windows" else "data/godot"
    map_path = directory / "profile" / profile / "app_userdata/Cyber Sand Reference Sandbox/workbench" / ("setup-" + map_name + ".json")
    sidecar_path, evidence_path = Path(str(map_path) + ".swarm004.json"), Path(str(map_path) + ".swarm004-evidence.json")
    custody.require(all(path.is_file() and not path.is_symlink() for path in (map_path, sidecar_path, evidence_path)),
                    "Original authored map, native receipt or saved native evidence is absent")
    saved = {key: custody.sha(path) for key, path in (
        ("map_sha256", map_path), ("sidecar_sha256", sidecar_path), ("evidence_sha256", evidence_path))}
    custody.require(primary.get("saved_artifacts") == reports["reopen"].get("saved_artifacts") == saved,
                    "Original saved files differ from Create/fresh-Reopen process witnesses")
    sidecar = legacy.read_report(sidecar_path)
    custody.require(type(sidecar.get("schema")) is int and sidecar["schema"] == 1
                    and sidecar.get("status") == "accepted_native_material_architecture"
                    and sidecar.get("native_receipt") == final and type(sidecar.get("cell_count")) is int
                    and sidecar["cell_count"] == final["changed_cells"]
                    and sidecar.get("authoring_territory") == {"layout": recipe.get("layout"), "border": recipe.get("border")}
                    and sidecar.get("map_sha256") == custody.sha(map_path)
                    and sidecar.get("proposal_sha256") == sidecar.get("evidence_sha256") == final["proposal_sha256"] == custody.sha(evidence_path)
                    and sidecar.get("request_sha256") == custody.sha(directory / "regenerated-request.txt")
                    and sidecar.get("native_source") == runtime["source_commit"]
                    and sidecar.get("cli_sha256") == runtime["files"][runtime["cli"]]["sha256"],
                    "Original saved native receipt differs from the acknowledged transaction, source or map")


def validate_example(directory: Path, name: str, reports: dict, receipt: dict, test_sha: str) -> dict:
    """Apply unchanged native/inspector/plane/PNG validators to original reports."""
    source, cli_sha = receipt["source_commit"], receipt["files"][receipt["cli"]]["sha256"]
    for mode, report in reports.items():
        errors = ui_report_errors(report, mode, name, source, cli_sha, test_sha, receipt["platform"])
        if name == "transaction" and mode == "reopen":
            errors.extend(historical_refresh_errors(directory, report, receipt))
        custody.require(not errors, "Original UI report failed: " + name + "/" + mode + ": " + "; ".join(errors))
    specification = legacy.EXAMPLES[name]
    primary = reports.get("create", reports.get("evaluate", reports.get("blocked", {})))
    negative = specification.get("negative") or (specification.get("evaluate") and primary.get("native_can_apply") is False)
    recomputed = legacy.blocked_evidence(directory, primary) if negative else legacy.example_evidence(directory, reports)
    custody.require(recomputed.get("passed") is True and recomputed.get("validation_errors") == [],
                    "Original native planes/inspector/screenshots failed: " + name + ": " + "; ".join(recomputed.get("validation_errors", [])))
    if negative:
        custody.require(primary.get("native_transactions") == {} and primary.get("saved_artifacts") == {}
                        and primary.get("native_receipt") == {} and primary.get("applied") is False,
                        "Negative native outcome claims a transaction, saved result or Apply acknowledgement")
    else:
        validate_native_transactions(directory, name, reports, receipt)
    outcome = {key: primary.get(key) for key in ("native_status", "native_reason", "native_stop_reason", "native_can_apply",
               "material_count", "joint_count", "obligation_count", "reciprocal_witness", "native_work", "native_evidence_sha256")}
    outcome.update(legacy.closure_outcome(primary.get("native_status"), primary.get("native_work")))
    return {"scope": specification["scope"], **recomputed, "passed": True, "native_outcome": outcome}


def validate_graphical(directory: Path, value: dict, receipt: dict) -> None:
    records, rows, platform = value["files_sha256"], value["results"], receipt["platform"]
    identity = document(directory, records, "source-runtime-identity.json")
    required = {"schema", "programme", "qualification_programme", "source_commit", "source_tree", "platform", "godot_version",
                "godot_sha256", "native_adapter_sha256", "runtime_manifest_sha256", "build_context", "graphical_required",
                "package", "package_zip_sha256", "execution_layout", "fixed_examples"}
    custody.require(set(identity) == required and all(value.get(key) == item for key, item in identity.items())
                    and identity.get("godot_version") == legacy.VERSION
                    and identity.get("native_adapter_sha256") == receipt["files"][receipt["extension"]]["sha256"]
                    and legacy.SHA256.fullmatch(str(identity.get("godot_sha256", "")))
                    and identity.get("fixed_examples") == {name: legacy.expected_recipe(name) for name in legacy.EXAMPLES},
                    "Original graphical source/runtime/engine identity differs from summary")
    layout = identity.get("execution_layout", {}).get("files_sha256", {})
    custody.require(layout.get("godot/tools/" + receipt["cli"]) == receipt["files"][receipt["cli"]]["sha256"]
                    and layout.get("godot/addons/cybersand_native/bin/" + receipt["extension"])
                    == receipt["files"][receipt["extension"]]["sha256"], "Installed graphical runtime identity is incomplete")
    for script in (legacy.UI_SCRIPT, legacy.INPUT_SCRIPT, "tests/test_workbench_authoring_patch.gd",
                   *("tests/" + script for _name, script, _marker, _timeout in HEADLESS_CASES)):
        custody.require(layout.get("godot/" + script) == script_hash(receipt, "godot/" + script),
                        "Installed test script differs from verified source: " + script)
    by_case = {(row.get("case"), row.get("example")): row for row in rows}
    custody.require(len(by_case) == len(rows), "Duplicate graphical process rows")

    def process(case: str, folder: str, timeout: int, script: str | None, graphical: bool, example: str | None = None):
        row = by_case.get((case, example))
        custody.require(isinstance(row, dict), "Missing graphical original child: " + folder + "/" + case)
        text = completed_process(directory, records, row, folder + "/" + case, timeout)
        graphical_command(row, script, graphical)
        return row, text

    process("import", "headless", 180, None, False)
    _row, text = process("native-adapter", "headless", 180, "tests/test_workbench_authoring_patch.gd", False)
    adapter = document(directory, records, "headless/native-adapter.json")
    custody.require(not legacy.assertion_errors(adapter) and adapter.get("passed") is True
                    and adapter.get("platform") == {"linux": "Linux", "windows": "Windows"}[platform]
                    and adapter.get("engine") == "4.7-stable (official)"
                    and adapter.get("test_script_sha256") == layout["godot/tests/test_workbench_authoring_patch.gd"]
                    and adapter.get("native_runtime", {}).get("current_file_sha256") == receipt["files"][receipt["extension"]]["sha256"]
                    and adapter.get("native_runtime", {}).get("current_file_size") == receipt["files"][receipt["extension"]]["bytes"]
                    and text.splitlines().count("WORKBENCH_AUTHORING_PATCH: " + str(adapter["checks"]) + " assertions, 0 failures") == 1,
                    "Original native adapter assertion/runtime evidence failed")
    for name, script, marker, timeout in HEADLESS_CASES:
        _row, text = process(name, "headless", timeout, "tests/" + script, False)
        errors = legacy.marker_errors(directory / "headless" / (name + ".log"), marker, name == "controller-mechanical")
        custody.require(not errors, "Original headless marker failed: " + name + ": " + "; ".join(errors))
        if name == "controls-native":
            evidence = json_marker(text, marker).get("inspector_evidence", {})
            custody.require(set(evidence) == {"V1", "V2", "V3", "V4"}, "Controls omit an original inspector protocol")
            for version, report in evidence.items():
                custody.require(not legacy.inspector_errors({"inspector_evidence": {"reopened": report}}, "reopen", receipt["source_commit"]),
                                "Original control inspector failed: " + version)
    _row, text = process("input-integrity", "input-integrity", 180, legacy.INPUT_SCRIPT, True)
    inputs = document(directory, records, "input-integrity/input-integrity.json")
    custody.require(json_marker(text, "SWARM006_INPUT_INTEGRITY ") == inputs, "Input original log/report disagree")
    errors = input_report_errors(directory / "input-integrity", inputs, receipt["source_commit"],
                                 receipt["files"][receipt["cli"]]["sha256"], layout["godot/" + legacy.INPUT_SCRIPT], platform)
    custody.require(not errors, "Original input evidence failed: " + "; ".join(errors))
    examples = {}
    for name, specification in legacy.EXAMPLES.items():
        modes = ["blocked"] if specification.get("negative") else (["evaluate"] if specification.get("evaluate") else ["create", "reopen"])
        reports = {}
        for mode in modes:
            row, text = process(mode, name, 420, legacy.UI_SCRIPT, True, name)
            original = ui_process_report(directory, records, row, text, name + "/" + mode)
            reports[mode] = original
            if mode == "evaluate" and original.get("native_can_apply") is True:
                modes.append("reopen")
        examples[name] = validate_example(directory / name, name, reports, receipt, layout["godot/" + legacy.UI_SCRIPT])
    row, text = process("lifecycle", "lifecycle", 300, legacy.UI_SCRIPT, True)
    lifecycle = ui_process_report(directory, records, row, text, "lifecycle/lifecycle", report_hash=False)
    custody.require(row.get("fixture_sha256") == receipt["files"][receipt["fixture"]]["sha256"],
                    "Original lifecycle fixture identity differs")
    errors = ui_report_errors(lifecycle, "lifecycle", "transaction", receipt["source_commit"],
                             receipt["files"][receipt["cli"]]["sha256"], layout["godot/" + legacy.UI_SCRIPT], platform)
    custody.require(not errors, "Original lifecycle assertions failed: " + "; ".join(errors))
    expected = graphical_processes(examples)
    custody.require(value.get("examples") == examples and [(row.get("case"), row.get("example")) for row in rows] == expected
                    and value.get("expected_processes") == [list(pair) for pair in expected],
                    "Graphical summary differs from independently reduced original example/process evidence")
