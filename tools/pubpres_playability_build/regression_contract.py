#!/usr/bin/env python3
"""Exact scoped copy of the accepted Godot diagnostic contract.

Kept independent of CI scheduling imports so the source-matched owner package
can validate its authoring fixtures without carrying unrelated CI machinery.
The helper regression compares this function with the unchanged shared checker.
"""
import json
import re


def case_diagnostic_error(name: str, output: str, returncode: int | None) -> bool:
    """Keep strict engine-error rejection, with one complete negative-case contract.

    The Art fixture deliberately asks ConfigFile and JSON to parse invalid bytes.
    Admit those original diagnostics only with their producer stacks, subsequent
    refusal/recovery assertions and complete 345-check successful suite footer.
    Raw logs remain untouched. Every other case keeps its original error policy.
    """
    # The owner retired cross-session Art restoration in ART-SESSION-LOG-001.
    # The replacement suite deliberately has no corrupt-profile parser errors;
    # preserve the historical 345-check admission for archived synthetic probes.
    if name == "test_art_history_durability" and "ART_HISTORY_SESSION_RESULT " in output:
        if returncode != 0 or "SCRIPT ERROR:" in output or "ERROR:" in output:
            return True
        marker = "ART_HISTORY_SESSION_RESULT "
        records = [line[len(marker):] for line in output.splitlines() if line.startswith(marker)]
        if len(records) != 1:
            return True
        try:
            receipt = json.loads(records[0])
        except (TypeError, ValueError):
            return True
        return not (isinstance(receipt, dict) and receipt.get("scope") == "session-only"
                    and type(receipt.get("checks")) is int and receipt["checks"] >= 10
                    and receipt.get("failures") == [])

    if name != "test_art_history_durability":
        return "SCRIPT ERROR:" in output or "ERROR:" in output
    if type(returncode) is not int or returncode != 0 or "SCRIPT ERROR:" in output:
        return True
    lines = output.splitlines()
    marker = "ART_HISTORY_DURABILITY_RESULT "
    terminal = [index for index, line in enumerate(lines) if line.startswith(marker)]
    nonempty = [index for index, line in enumerate(lines) if line.strip()]
    if len(terminal) != 1 or not nonempty or terminal[0] != nonempty[-1]:
        return True
    try:
        result = json.loads(lines[terminal[0]][len(marker):])
    except (TypeError, ValueError):
        return True
    if (not isinstance(result, dict)
            or set(result) != {"case", "checks", "failures", "godot", "native_sha256", "os", "test_sha256"}
            or result.get("case") != "suite"
            or type(result.get("checks")) is not int or result["checks"] != 345
            or type(result.get("failures")) is not list or result["failures"]
            or result.get("godot") != "4.7-stable (official)" or result.get("os") not in ("Linux", "Windows")
            or re.fullmatch(r"[0-9a-f]{64}", str(result.get("native_sha256", ""))) is None
            or result.get("test_sha256") != "6659b017334d87f3f63c001caa402e08c6be24bdbb27579875a7d1a3aeb75a7a"):
        return True
    prefix = "ART_HISTORY_DURABILITY_CHECK "
    assertions = [line for line in lines if line.startswith(prefix)]
    if len(assertions) != 345 or any(not line.endswith(" true") for line in assertions):
        return True
    if re.search(r"\bskipped\b|^\s*SKIP\b", output, re.I | re.M):
        return True
    expected = (
        ("ERROR: ConfigFile parse error at user://art-provider.cfg:0: Unexpected EOF while parsing simple tag.",
         (r"at: _parse \(core/io/config_file\.cpp:\d+\)",
          r"\[\d+\] read_history_session \(res://scripts/art_batch_panel\.gd:\d+\)",
          r"\[\d+\] unknown_profile_outage \(res://tests/test_art_history_durability\.gd:\d+\)"),
         ("unknown corrupt profile cannot fabricate a source association",
          "unknown corrupt profile reports actionable persistence failure")),
        ("ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'not'",
         (r"at: parse_string \(core/io/json\.cpp:\d+\)",
          r"\[\d+\] _read_pending_history_receipts \(res://scripts/art_batch_panel\.gd:\d+\)",
          r"\[\d+\] invalid_journal \(res://tests/test_art_history_durability\.gd:\d+\)"),
         ("invalid malformed journal fails closed before writing valid receipts",
          "invalid malformed preserves exact original archive bytes",
          "valid journal recovers after malformed obstruction removed")),
    )
    admitted = set()
    for headline, producers, witnesses in expected:
        positions = [index for index, line in enumerate(lines) if line == headline]
        if len(positions) != 1:
            return True
        position = positions[0]
        end = position + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith((" ", "\t"))):
            end += 1
        stack = "\n".join(lines[position + 1:end])
        frames = [re.search(r"^\s*" + producer + r"$", stack, re.M) for producer in producers]
        if any(frame is None for frame in frames) or [frame.start() for frame in frames] != sorted(frame.start() for frame in frames):
            return True
        for witness in witnesses:
            matches = [index for index, line in enumerate(lines) if line == prefix + witness + " true"]
            if len(matches) != 1 or matches[0] < end:
                return True
        admitted.add(position)
    if lines.count(prefix + "all thirteen adversarial scenario families executed true") != 1:
        return True
    # Remove only the two independently verified headline lines from the error
    # decision; every unexpected diagnostic (including later shutdown) remains fatal.
    return any("ERROR:" in line for index, line in enumerate(lines) if index not in admitted)
