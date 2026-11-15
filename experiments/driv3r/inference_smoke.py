"""Frozen Stage A Experiment A; model errors remain observations, never repairs."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import statistics

from experiments.driv3r.backend import parse_choice_response


MOVES = {"UP": "Move one cell up: y decreases by 1.",
         "DOWN": "Move one cell down: y increases by 1.",
         "LEFT": "Move one cell left: x decreases by 1.",
         "RIGHT": "Move one cell right: x increases by 1."}
CASES = (
    {"id": "right", "target": [4, 3], "oracle": "RIGHT"},
    {"id": "left", "target": [2, 3], "oracle": "LEFT"},
    {"id": "up", "target": [3, 2], "oracle": "UP"},
    {"id": "down", "target": [3, 4], "oracle": "DOWN"},
)
TOOL_QUESTION = {"type": "choice", "instructions": "Select the operation that serves the stated bridge objective.",
                 "criteria": {"ADD_WALL_SHORT": "Paint a short vertical wall.",
                              "ADD_BRIDGE_SHORT": "Paint a short horizontal bridge joining the platforms.",
                              "ADD_DETAIL": "Paint a decorative dot.", "STOP": "Finish without painting."}}


def _percentile(values, q):
    if not values:
        return None
    values = sorted(values)
    pos = (len(values)-1)*q
    lo = int(pos)
    hi = min(lo+1, len(values)-1)
    return values[lo] + (values[hi]-values[lo])*(pos-lo)


def is_pinned_capacity_refusal(record: dict, batch_size: int) -> bool:
    """b11960 reports oversized noncausal batches as server_error/500, not 400."""
    if record.get("status") != "model_failure" or record.get("http_status") != 500:
        return False
    raw = record.get("raw_response")
    if type(raw) is not dict or set(raw) != {"error"}:
        return False
    error = raw["error"]
    if type(error) is not dict or set(error) != {"code", "message", "type"}:
        return False
    if type(error["code"]) is not int or error["code"] != 500 or error["type"] != "server_error" or type(error["message"]) is not str:
        return False
    match = re.fullmatch(r"input \(([0-9]+) tokens\) is too large to process\. increase the physical batch size \(current batch size: ([0-9]+)\)", error["message"])
    return match is not None and int(match[1]) > batch_size and int(match[2]) == batch_size


def run_inference_smoke(backend, output: Path) -> dict:
    """Use the caller's already-resident instance; leave it available for native loops."""
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    frozen = {"schema_version": 1, "qualification_set_revision": 2, "cases": CASES, "move_criteria": MOVES,
              "tool_question": TOOL_QUESTION, "orderings": [list(MOVES), list(reversed(MOVES))],
              "repeated_warm_case": "right", "request_deadline_seconds": 60,
              "capacity_probe": {"state": " x"*6000, "expected_http_status": 500,
                                 "expected_error_type": "server_error", "batch_size": 2048,
                                 "recovery_case": "right"}}
    encoded = json.dumps(frozen, sort_keys=True, separators=(",", ":")).encode()
    (output/"frozen-inputs.json").write_text(json.dumps(frozen, indent=2)+"\n")
    outcomes = []

    def decide(case_id, state, questions, oracles=None):
        record = backend.decide(state, questions, timeout_seconds=60)
        parsed = {}
        error = None
        if record["status"] == "ok":
            try:
                parsed = {name: parse_choice_response(record["raw_response"], name, q["criteria"])
                          for name, q in questions.items()}
            except ValueError as exc:
                error = str(exc)
        outcome = {"case_id": case_id, "record": record, "parsed": parsed,
                   "oracle": oracles, "oracle_correct": None, "parse_error": error}
        if oracles is not None and record["status"] == "ok" and error is None:
            outcome["oracle_correct"] = {name: parsed[name]["candidate_id"] == target
                                         for name, target in oracles.items()}
        outcomes.append(outcome)
        (output/f"{case_id}.json").write_text(json.dumps(outcome, indent=2)+"\n")
        return outcome

    for case in CASES:
        for order in ("forward", "reverse"):
            options = dict(MOVES if order == "forward" else reversed(list(MOVES.items())))
            state = (f"The cursor is at x=3, y=3. The target is at x={case['target'][0]}, "
                     f"y={case['target'][1]}. All four neighboring cells are empty. "
                     "Move one cell toward the target. Coordinates increase rightward and downward.")
            q = {"move": {"type": "choice", "instructions": "Which single movement reaches the target?",
                          "criteria": options}}
            decide(case["id"]+"-"+order, state, q, {"move": case["oracle"]})
    first = outcomes[0]["record"]["request"]
    decide("right-repeated-warm", first["state"], first["questions"], {"move": "RIGHT"})
    bridge_state = ("Objective: connect the two existing platforms with one short horizontal bridge. "
                    "A four-cell horizontal gap separates the platforms. No bridge has been painted.")
    decide("fuzzy-choice", bridge_state, {"tool": TOOL_QUESTION}, {"tool": "ADD_BRIDGE_SHORT"})
    # Two independent named questions about the identical original state. The
    # tool question is NOT asked about the result of the movement question.
    decide("same-state-two-named", first["state"]+"\n"+bridge_state,
           {"move": first["questions"]["move"], "tool": TOOL_QUESTION},
           {"move": "RIGHT", "tool": "ADD_BRIDGE_SHORT"})

    invalid = backend.decide("malformed local choice", {"move": {"type":"choice", "multiple":True,
                             "instructions":"select", "criteria":MOVES}}, timeout_seconds=10)
    malformed = backend.probe_raw({"state":"deliberately missing questions", "questions":{}}, timeout_seconds=10)
    # This remains below the byte limit but exceeds the frozen 4096-token
    # context/2048-token batch. b11960 reports this as HTTP500 server_error.
    overflow = backend.probe_raw({"state":" x"*6000, "questions":first["questions"]}, timeout_seconds=10)
    capacity_refused = is_pinned_capacity_refusal(overflow, backend.batch_size)
    recovery = decide("post-capacity-recovery", first["state"], first["questions"], {"move":"RIGHT"})
    (output/"local-refusal.json").write_text(json.dumps(invalid, indent=2)+"\n")
    (output/"raw-endpoint-refusal.json").write_text(json.dumps(malformed, indent=2)+"\n")
    (output/"context-overflow-refusal.json").write_text(json.dumps(overflow, indent=2)+"\n")
    good = all(o["record"]["status"] == "ok" and o["parse_error"] is None for o in outcomes)
    pids = sorted({o["record"]["pid"] for o in outcomes})
    oracle_results = [v for o in outcomes for v in (o["oracle_correct"] or {}).values()]
    oracle_count = sum(len(o["oracle"] or {}) for o in outcomes)
    warm = [o["record"]["latency_seconds"] for o in outcomes[1:] if o["record"]["status"] == "ok"]
    summary = {"schema_version": 1, "kind": "actual_d1_inference", "frozen_input_sha256": hashlib.sha256(encoded).hexdigest(),
               "status": "PASS" if good and len(pids)==1 and invalid["status"]=="invalid_request" and malformed.get("http_status")==400 and capacity_refused else "FAIL",
               "pids": pids, "session_id": backend.session_id, "requests": len(outcomes),
               "valid_requests": sum(o["record"]["status"] == "ok" and o["parse_error"] is None for o in outcomes),
               "oracle_correct": sum(oracle_results), "oracle_count": oracle_count,
               "oracle_answered": len(oracle_results),
               "oracle_accuracy": sum(oracle_results)/oracle_count if oracle_count else None,
               "oracle_meaning": "Objective direction/bridge matches only; accuracy is reported, not repaired or an infrastructure gate.",
               "first_decision_seconds": outcomes[0]["record"]["latency_seconds"],
               "warm_p50_seconds": statistics.median(warm) if warm else None,
               "warm_p95_seconds": _percentile(warm, 0.95),
               "warm_requests_per_second": len(warm)/sum(warm) if warm else None,
               "percentile_method": "linear interpolation between sorted observations",
               "startup_load_seconds": (backend.startup_record or {}).get("load_seconds"),
               "original_records": [o["record"]["evidence_path"] for o in outcomes],
               "local_refusal_status": invalid["status"], "raw_refusal_http_status": malformed.get("http_status"),
               "context_overflow_http_status": overflow.get("http_status"),
               "context_overflow_refused": capacity_refused,
               "context_overflow_raw_error": overflow.get("raw_response"),
               "post_capacity_recovery_status": recovery["record"]["status"],
               "backend_limitation": "Pinned llama.cpp reports oversized batches as HTTP500 server_error; this is not a clean HTTP400 client refusal."}
    (output/"summary.json").write_text(json.dumps(summary, indent=2)+"\n")
    return summary
