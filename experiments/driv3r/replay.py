"""Replay original acknowledged decisions through another actual native World."""
from __future__ import annotations

from pathlib import Path

from .contracts import Refusal, digest, operation_visits
from .controller import validate_episode, write_json
from .native import verify_observation


def replay_episode(record: dict, native, original_native_directory: Path, output: Path) -> dict:
    """Replays materials/actions, not neural inference or full simulation history."""
    output.mkdir(parents=True, exist_ok=False)
    offline = validate_episode(record)
    # A partial cancellation is timing-dependent. Replaying the entire selected
    # operation would silently add its unacknowledged suffix. Keep that original
    # failure, and refuse this bounded replay mode before resetting any World.
    if any(step["host_status"] != "applied" and step["native_response"] is not None and
           step["native_response"]["receipt"]["actual_changed_cells"] > 0 for step in record["steps"]):
        raise Refusal("Partial native prefix replay is unsupported in Stage A")
    verify_observation(original_native_directory, record["initial_native"])
    verify_observation(original_native_directory, record["final_native"])
    if record["stop_receipt"]["observation"] != record["final_native"] or not record["final_native"]["retired"]:
        raise Refusal("Final Stop observation identity mismatch")
    reset = native.reset(record["fixture"])
    current = reset["observation"]
    if reset["status"] != "completed" or current["world_material_sha256"] != record["initial_native"]["world_material_sha256"]:
        raise Refusal("Replay initial native fixture differs")
    rows = []
    for step in record["steps"]:
        verify_observation(original_native_directory, step["before_native"]["observation"])
        if current["world_material_sha256"] != step["before_native"]["observation"]["world_material_sha256"]:
            raise Refusal("Replay starts an action from a different native state")
        if step["host_status"] != "applied":
            rows.append({"step": step["step"], "original_status": step["host_status"], "native_mutation": False})
            continue
        original = step["native_response"]
        verify_observation(original_native_directory, original["observation"])
        action = step["selected_action"]
        cells = operation_visits(action["operations"])
        replayed = native.apply(action["operations"], expected_generation=current["generation"],
                                expected_revision=current["revision"], expected_tick=current["tick"],
                                action_id=action["id"], cell_budget=cells)
        current = replayed["observation"]
        passed = (replayed["status"] == "completed" and replayed["receipt"]["readback_matches"]
                  and current["world_material_sha256"] == original["observation"]["world_material_sha256"]
                  and replayed["receipt"]["actual_changed_cells"] == original["receipt"]["actual_changed_cells"])
        row = {"step": step["step"], "action_id": action["id"], "original_record_sha256": step["record_sha256"],
               "native_response": replayed, "passed": passed, "native_mutation": True}
        rows.append(row)
        write_json(output/f"step-{step['step']:03d}.json", row)
        if not passed:
            raise Refusal("Original selected action failed native material replay")
    stopped = native.stop("replay complete")
    final_equal = stopped["observation"]["world_material_sha256"] == record["final_native"]["world_material_sha256"]
    result = {"passed": final_equal, "episode_id": record["episode_id"], "offline": offline,
              "original_episode_sha256": digest(record), "steps": rows, "final_native": stopped,
              "claim": "Original chosen actions replayed through real native World; material equality, not repeated inference or full physics replay"}
    write_json(output/"replay.json", result)
    if not final_equal:
        raise Refusal("Replay final native material differs")
    return result
