"""Strict observation -> question -> decision -> native receipt episode owner."""
from __future__ import annotations

from copy import deepcopy
import json
import os
from pathlib import Path
import threading
import time

from . import PROTOCOL
from .contracts import (Refusal, canonical, digest, integer, finite, validate_candidates,
                        validate_decision, validate_operations, operation_visits, TERMINAL_STATUSES)
from .providers import observation, permitted, world_identity


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as file:
        json.dump(value, file, indent=2, sort_keys=True, allow_nan=False)
        file.write("\n")


def decision_record(observed: dict, candidates: list[dict], *, choice=None, probabilities=None,
                    confidence=None, status="ok", latency_seconds=0, model_identity=None,
                    backend_identity=None, raw=None, error=None) -> dict:
    return {"protocol": PROTOCOL, "question_id": "next_action", "candidate_id": choice,
            "probabilities": probabilities, "confidence": confidence, "status": status,
            "state_sha256": digest(observed), "candidate_set_sha256": digest(candidates),
            "latency_seconds": latency_seconds, "model_identity": model_identity,
            "backend_identity": backend_identity, "raw": raw, "error": error}


class D1Policy:
    """One holistic choice. Named questions do not consume each other's answers."""
    name = "d1-q8-holistic-v1"

    def __init__(self, backend):
        self.backend = backend

    @staticmethod
    def request(observed: dict, candidates: list[dict]) -> dict:
        validate_candidates(candidates, observed)
        # The model receives local materials and bounded host metrics, not World bytes.
        state = canonical({"observation": observed, "candidate_effects": [
            {"id": c["id"], "description": c["label"], "profile": c["profile"],
             "effects": {k: v for k, v in c["predicted"].items() if k != "program"}}
            for c in candidates]}).decode()
        questions = {"next_action": {"type": "choice", "instructions":
            "Which single candidate best satisfies the objective and active subgoal in this state? "
            "Choose STOP only when finished or no useful action remains. Treat the candidate IDs as labels.",
            "criteria": {c["id"]: c["label"] for c in candidates}}}
        return {"state": state, "questions": questions}

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float,
               cancel_event: threading.Event) -> dict:
        from .backend import parse_choice_response
        request = self.request(observed, candidates)
        raw = self.backend.decide(request["state"], request["questions"], timeout_seconds=timeout_seconds, cancel_event=cancel_event)
        status, error = raw["status"], raw.get("error")
        parsed = {}
        if status == "ok":
            try:
                parsed = parse_choice_response(raw["raw_response"], "next_action", [c["id"] for c in candidates])
            except (ValueError, KeyError, TypeError) as exc:
                status, error = "invalid_decision", str(exc)
        return decision_record(observed, candidates, choice=parsed.get("candidate_id"),
                               probabilities=parsed.get("probabilities"), confidence=parsed.get("confidence"),
                               status=status, latency_seconds=raw["latency_seconds"],
                               model_identity=raw["model_identity"], backend_identity=raw["backend_identity"],
                               raw=raw, error=error)


class GeometricBaseline:
    """Conventional one-step oracle on the same direct-drive candidates/budgets."""
    name = "deterministic-geometric-baseline-v1"

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float,
               cancel_event: threading.Event) -> dict:
        started = time.monotonic()
        validate_candidates(candidates, observed)
        movement = [c for c in candidates if c["kind"] == "movement"]
        if observed["cursor"] == observed["target"] or not movement:
            choice = "STOP"
        else:
            choice = min(movement, key=lambda c: (c["predicted"]["offset_error"],
                         c["predicted"]["retrace"], c["predicted"]["goal_distance"], c["id"]))["id"]
        probabilities = {c["id"]: float(c["id"] == choice) for c in candidates}
        return decision_record(observed, candidates, choice=choice, probabilities=probabilities, confidence=1.0,
                               latency_seconds=time.monotonic()-started,
                               model_identity={"kind": "deterministic_non_model_baseline"},
                               backend_identity={"implementation": self.name}, raw={"oracle_choice": choice})


class CancelledExecution(Refusal):
    pass


class ExpiredExecution(Refusal):
    pass


def execute_candidate(native, action: dict, observed: dict, *, remaining_cells: int,
                      cancel_event: threading.Event, deadline: float) -> dict:
    """Re-read native state after inference, then admit only the held host action."""
    def remaining():
        if cancel_event.is_set():
            raise CancelledExecution("Cancelled at native admission boundary")
        seconds = deadline-time.monotonic()
        if seconds <= 0.001:
            raise ExpiredExecution("Episode expired at native admission boundary")
        return min(60.0, seconds)

    current_response = native.observe(timeout=remaining(), cancel_event=cancel_event)
    remaining()
    if current_response["status"] != "completed":
        raise Refusal("Native observation refused")
    current = current_response["observation"]
    if current["retired"] or world_identity(current) != observed["world"]:
        raise Refusal("Native source became stale or retired during decision")
    cells = validate_operations(action["operations"], observed["permissions"]["focus"], 58)
    if not all(permitted(current, x, y) for x, y in cells):
        raise Refusal("Host candidate intersects protected/native-ineligible cells")
    expected = sum(current["materials"][y*96+x] != 58 for x, y in cells)
    if expected > remaining_cells:
        raise Refusal("Candidate exceeds remaining changed-cell budget")
    receipt = native.apply(action["operations"], expected_generation=current["generation"],
                           expected_revision=current["revision"], expected_tick=current["tick"],
                           action_id=action["id"], cell_budget=operation_visits(action["operations"]),
                           timeout=remaining(), cancel_event=cancel_event)
    details = receipt.get("receipt", {})
    after = receipt.get("observation", {})
    actual = sum(a != b for a, b in zip(current["materials"], after.get("materials", []), strict=True))
    prefix_legal = all(a == b or ((i % 96, i // 96) in cells and b == 58)
                       for i, (a, b) in enumerate(zip(current["materials"], after["materials"], strict=True)))
    # We do not repair or infer a native success from the model's choice.
    receipt["controller_expected_changed_cells"] = expected
    receipt["controller_prefix_consistent"] = (prefix_legal and details.get("readback_matches") is True
                                                and details.get("actual_changed_cells") == actual and actual <= expected)
    receipt["controller_consistent"] = (receipt["status"] == "completed" and
        receipt["controller_prefix_consistent"] and details.get("actual_changed_cells") == expected and
        details.get("expected_changed_cells") == expected)
    return receipt


class EpisodeController:
    def __init__(self, *, max_decisions=8, max_changed_cells=1024, max_wall_seconds=300,
                 request_seconds=60):
        self.max_decisions = integer(max_decisions, 1, 64, "maximum decisions")
        self.max_changed_cells = integer(max_changed_cells, 1, 4096, "maximum changed cells")
        self.max_wall_seconds = finite(max_wall_seconds, 0.001, 3600, "episode wall deadline")
        self.request_seconds = finite(request_seconds, 0.001, 600, "request deadline")

    def run(self, *, native, provider, policy, episode_id: str, output: Path,
            cancel_event: threading.Event | None = None) -> dict:
        output.mkdir(parents=True, exist_ok=False)
        cancel_event = cancel_event or threading.Event()
        started = time.monotonic()
        deadline = started+self.max_wall_seconds
        steps, changed, previous_ack = [], 0, None
        status, reason = "budget_exhausted", "Maximum decisions reached"
        initial, final, stop_receipt = None, None, None
        journal = output / "journal.jsonl"

        def retain(row):
            row["previous_record_sha256"] = steps[-1]["record_sha256"] if steps else None
            row["record_sha256"] = digest(row)
            with journal.open("ab") as file:
                file.write(canonical(row)+b"\n")
                file.flush()
                os.fsync(file.fileno())
            steps.append(row)

        try:
            reset = native.reset(provider.fixture, timeout=min(60.0, self.max_wall_seconds), cancel_event=cancel_event)
            if reset["status"] != "completed":
                raise Refusal("Native fixture reset refused")
            initial = reset["observation"]
            for step in range(self.max_decisions):
                if cancel_event.is_set():
                    status, reason = "cancelled", "Owner cancellation before decision"
                    break
                if provider.complete():
                    status, reason = "success", "Host-observed task/graph terminal reached"
                    break
                remaining = deadline-time.monotonic()
                if remaining <= 0 or changed >= self.max_changed_cells:
                    status, reason = "budget_exhausted", "Wall-time or actual changed-cell budget exhausted"
                    break
                response = native.observe(timeout=min(60.0, remaining), cancel_event=cancel_event)
                if response["status"] != "completed":
                    raise Refusal("Native observation refused")
                if cancel_event.is_set():
                    status, reason = "cancelled", "Cancelled during native observation"
                    break
                remaining = deadline-time.monotonic()
                if remaining <= 0:
                    status, reason = "budget_exhausted", "Episode expired during observation"
                    break
                state = response["observation"]
                obs = observation(state, provider, episode_id=episode_id, step=step,
                                  decisions_remaining=self.max_decisions-step,
                                  changed_cells_remaining=self.max_changed_cells-changed,
                                  wall_seconds_remaining=remaining, previous_ack=previous_ack)
                candidates = provider.candidates(state, obs)
                row = {"step": step, "observation": obs, "candidates": candidates,
                       "before_native": response, "decision": None, "selected_action": None,
                       "host_status": "pending", "native_response": None, "decision_requested": False}
                if len(candidates) == 1 and candidates[0]["kind"] == "stop":
                    status, reason = "stop", "Host has no legal non-STOP candidate; no model request made"
                    row["selected_action"] = deepcopy(candidates[0])
                    row["host_status"] = "host_forced_stop"
                    retain(row)
                    break
                try:
                    row["decision_requested"] = True
                    answer = policy.decide(deepcopy(obs), deepcopy(candidates),
                        timeout_seconds=min(self.request_seconds, remaining), cancel_event=cancel_event)
                    row["decision"] = answer
                    # A late valid answer is still not authority to paint.
                    if cancel_event.is_set() or answer.get("status") == "cancelled":
                        status, reason = "cancelled", "Decision cancelled or returned after cancellation"
                        row["host_status"] = "cancelled"
                        retain(row)
                        break
                    if time.monotonic() >= deadline:
                        status, reason = "budget_exhausted", "Decision returned after episode deadline"
                        row["host_status"] = "deadline_refused"
                        retain(row)
                        break
                    if answer.get("status") not in ("ok",):
                        status = "invalid_decision" if answer.get("status") in ("invalid_request", "invalid_decision") else "model_failure"
                        reason = str(answer.get("error") or answer.get("status"))
                        row["host_status"] = status
                        retain(row)
                        break
                    action = validate_decision(answer, obs, candidates)
                    row["selected_action"] = deepcopy(action)
                except (Refusal, ValueError, KeyError, TypeError) as exc:
                    status, reason = "invalid_decision", str(exc)
                    row["host_status"] = "invalid_decision"
                    retain(row)
                    break
                except Exception as exc:
                    status, reason = "model_failure", f"{type(exc).__name__}: {exc}"
                    row["host_status"] = "model_failure"
                    retain(row)
                    break
                if action["kind"] == "stop":
                    status, reason = "stop", "Policy selected explicit STOP"
                    row["host_status"] = "stopped"
                    retain(row)
                    break
                if action["kind"] == "skip":
                    provider.accept(action)
                    row["host_status"] = "skipped"
                    retain(row)
                    continue
                try:
                    # Cancellation is checked again at the native call boundary.
                    if cancel_event.is_set():
                        status, reason = "cancelled", "Cancelled before native admission"
                        row["host_status"] = "cancelled"
                        retain(row)
                        break
                    applied = execute_candidate(native, action, obs, remaining_cells=self.max_changed_cells-changed,
                                                cancel_event=cancel_event, deadline=deadline)
                    row["native_response"] = applied
                    acknowledged = applied["receipt"]["actual_changed_cells"]
                    # Even a cancelled/refused suffix can leave an acknowledged prefix.
                    # Preserve those cells without pretending the requested action completed.
                    changed += acknowledged
                    if not applied["controller_consistent"]:
                        status = "cancelled" if cancel_event.is_set() or applied["status"] == "cancelled" else "native_refusal"
                        reason = "Native action did not complete; original acknowledged prefix retained"
                        row["host_status"] = status
                        retain(row)
                        break
                    previous_ack = {"action_id": action["id"], "actual_changed_cells": acknowledged,
                                    "receipt_sha256": digest(applied["receipt"]),
                                    "world_material_sha256": applied["observation"]["world_material_sha256"]}
                    provider.accept(action)
                    row["host_status"] = "applied"
                    retain(row)
                except (CancelledExecution, ExpiredExecution) as exc:
                    status = "cancelled" if isinstance(exc, CancelledExecution) else "budget_exhausted"
                    reason = str(exc)
                    row["host_status"] = status
                    retain(row)
                    break
                except (Refusal, ValueError, RuntimeError, KeyError, TypeError) as exc:
                    status, reason = "native_refusal", str(exc)
                    row["host_status"] = "native_refusal"
                    retain(row)
                    break
            if provider.complete() and status == "budget_exhausted":
                status, reason = "success", "Host-observed task/graph terminal reached"
        except Exception as exc:
            status = "cancelled" if cancel_event.is_set() else "native_refusal"
            reason = f"{type(exc).__name__}: {exc}"
        finally:
            try:
                stop_receipt = native.stop(status)
                final = stop_receipt.get("observation")
            except Exception as exc:
                reason += f"; native Stop failed: {type(exc).__name__}: {exc}"
                status = "native_refusal"
        assert status in TERMINAL_STATUSES
        result = {"protocol": PROTOCOL, "episode_id": episode_id, "mode": provider.mode,
                  "fixture": provider.fixture, "policy": policy.name, "terminal_status": status, "reason": reason,
                  "limits": {"max_decisions": self.max_decisions, "max_changed_cells": self.max_changed_cells,
                             "max_wall_seconds": self.max_wall_seconds, "request_seconds": self.request_seconds},
                  "initial_native": initial, "steps": steps, "final_native": final, "stop_receipt": stop_receipt,
                  "decisions": sum(s["decision_requested"] for s in steps), "iterations": len(steps),
                  "native_actions": sum(s["host_status"] == "applied" for s in steps),
                  "native_attempts": sum(s["native_response"] is not None for s in steps),
                  "partial_native_actions": sum(s["native_response"] is not None and s["host_status"] != "applied" and
                                                s["native_response"]["receipt"]["actual_changed_cells"] > 0 for s in steps),
                  "actual_changed_cells": changed, "elapsed_seconds": time.monotonic()-started,
                  "final_cursor": provider.cursor, "task_complete": provider.complete(),
                  "completion_kind": "geometric_target_reached" if provider.mode == "direct" else "graph_terminal_only",
                  "claim": "Original policy decisions and actual native material readback; no hidden action repair"}
        write_json(output / "episode.json", result)
        return result


def validate_episode(record: dict) -> dict:
    """Offline custody/decision validation; it does not claim native replay."""
    if record["protocol"] != PROTOCOL or record["terminal_status"] not in TERMINAL_STATUSES:
        raise Refusal("Invalid episode protocol/terminal status")
    if record["decisions"] != sum(s.get("decision_requested", True) for s in record["steps"]) or len(record["steps"]) > record["limits"]["max_decisions"]:
        raise Refusal("Episode decision budget/count mismatch")
    previous = None
    state = record["initial_native"]
    applied = 0
    actions = 0
    for index, step in enumerate(record["steps"]):
        row = deepcopy(step)
        expected = row.pop("record_sha256")
        if digest(row) != expected or row["previous_record_sha256"] != previous:
            raise Refusal("Episode hash chain mismatch")
        previous = expected
        if row["step"] != index or row["observation"]["step"] != index:
            raise Refusal("Episode steps are reordered")
        before = row["before_native"]["observation"]
        if world_identity(before) != row["observation"]["world"] or world_identity(before) != world_identity(state):
            raise Refusal("Episode native observation chain mismatch")
        if row["host_status"] in ("applied", "skipped", "stopped") or row["native_response"] is not None:
            selected = validate_decision(row["decision"], row["observation"], row["candidates"])
            if selected != row["selected_action"]:
                raise Refusal("Executed action differs from chosen host candidate")
            answer_identity = row["decision"]["model_identity"]
            answer_raw = row["decision"].get("raw") or {}
            is_model = (bool(answer_identity.get("repository")) or answer_identity.get("kind") == "model"
                        or ("request" in answer_raw and "raw_response" in answer_raw))
            if is_model or record["policy"] == D1Policy.name or record["policy"].startswith("d1-q8-stage-b-"):
                from .backend import parse_choice_response
                from .stage_b.representation import request_for_policy
                answer = row["decision"]
                raw = answer["raw"]
                request = (D1Policy.request(row["observation"], row["candidates"]) if record["policy"] == D1Policy.name
                           else request_for_policy(record["policy"], row["observation"], row["candidates"]))
                if (raw["status"] != "ok" or raw["request"] != request
                        or raw["model_identity"] != answer["model_identity"] or raw["backend_identity"] != answer["backend_identity"]):
                    raise Refusal("Original model request or identity mismatch")
                parsed = parse_choice_response(raw["raw_response"], "next_action", [c["id"] for c in row["candidates"]])
                if any(answer[k] != parsed[k] for k in ("candidate_id", "confidence", "probabilities")):
                    raise Refusal("Recorded decision differs from original typed model output")
            if row["native_response"] is not None:
                result = row["native_response"]
                if not result.get("controller_prefix_consistent", result["controller_consistent"]) or not result["receipt"]["readback_matches"]:
                    raise Refusal("Episode contains unverified native application")
                predicted = before["materials"].copy()
                for x, y in validate_operations(selected["operations"], row["observation"]["permissions"]["focus"], 58):
                    if not permitted(before, x, y):
                        raise Refusal("Recorded action is outside host authority")
                    predicted[y*96+x] = 58
                state = result["observation"]
                count = sum(a != b for a, b in zip(before["materials"], state["materials"], strict=True))
                full_action = row["host_status"] == "applied"
                allowed_prefix = all(b == a or b == p for a, b, p in zip(before["materials"], state["materials"], predicted, strict=True))
                if (full_action and predicted != state["materials"]) or not allowed_prefix or count != result["receipt"]["actual_changed_cells"]:
                    raise Refusal("Original native readback differs from selected operations")
                # Real native receipts bind full-World before/after hashes. Unit doubles
                # are explicitly identified and do not qualify this native boundary.
                if "before_world_sha256" in result["receipt"] and (
                        result["receipt"]["before_world_sha256"] != before["world_material_sha256"] or
                        result["receipt"]["after_world_sha256"] != state["world_material_sha256"]):
                    raise Refusal("Native full-World receipt hashes disagree")
                applied += count
                actions += int(full_action)
    if applied != record["actual_changed_cells"] or actions != record["native_actions"] or applied > record["limits"]["max_changed_cells"]:
        raise Refusal("Episode changed-cell total mismatch")
    attempts = sum(step["native_response"] is not None for step in record["steps"])
    partials = sum(step["native_response"] is not None and step["host_status"] != "applied" and
                   step["native_response"]["receipt"]["actual_changed_cells"] > 0 for step in record["steps"])
    if attempts != record.get("native_attempts", attempts) or partials != record.get("partial_native_actions", partials):
        raise Refusal("Episode native attempt/prefix count mismatch")
    if record["final_native"] and state and record["final_native"]["world_material_sha256"] != state["world_material_sha256"]:
        raise Refusal("Native Stop changed World materials")
    return {"passed": True, "steps": len(record["steps"]), "actual_changed_cells": applied,
            "record_sha256": digest(record), "claim": "Offline record verification, not native replay"}
