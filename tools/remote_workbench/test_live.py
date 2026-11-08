#!/usr/bin/env python3
"""Actual external-process incremental JSONL acceptance for one Godot/native World.

Run only after pinned Linux Godot, source-built native, and Rapier are installed.
The client subcommands see command ingress and output only, never host authority.
No fake transport or model/API usage is involved.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

import run as runner
import verify

HERE = Path(__file__).resolve().parent
TIMEOUT = 100


def read_events(folder: Path) -> list[dict]:
    path = folder / "results.jsonl"
    if not path.exists():
        return []
    events = []
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        if not line.endswith("\n"):
            break
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            break  # concurrent flush; retry without accepting a partial receipt
    return events


def wait_event(folder: Path, sequence: int | None = None, *, timeout: int = TIMEOUT) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        for event in read_events(folder):
            if (sequence is None and event.get("type") == "authorization"
                    or sequence is not None and event.get("type") == "tool_result"
                    and event.get("seq") == sequence):
                return event
        time.sleep(0.1)
    raise AssertionError(f"Real native response not observed: seq={sequence}, {folder}")


def send(commands: Path, *objects: dict) -> None:
    with commands.open("a", encoding="utf-8") as output:
        for obj in objects:
            output.write(json.dumps(obj, separators=(",", ":")) + "\n")
        output.flush()
        os.fsync(output.fileno())


def tool(seq: int, name: str, args: dict, expected: str | None = None) -> dict:
    command = {"version": 1, "seq": seq, "tool": name, "args": args}
    if expected is not None:
        command["expect_status"] = expected
    return command


def check(receipt: dict, status: str) -> dict:
    assert receipt["status"] == status, (receipt, status)
    return receipt["result"]


def frame(folder: Path, receipt: dict) -> str:
    record = receipt["frame"]
    assert record["status"] == "original_post_draw", record
    path = folder / record["path"]
    assert path.is_file(), path
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    assert sha == record["sha256"], (sha, record)
    return sha


def client_first(commands: Path, evidence: Path, state: Path) -> None:
    send(commands, tool(1, "observe",
                        {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                         "detail": "cells"}, "observed"))
    observed = wait_event(evidence, 1)
    native = check(observed, "observed")
    image_sha = frame(evidence, observed)
    # The next operation is chosen only AFTER actual native data and image
    # have reached this separately launched client process.
    assert native["native_counts"].get("58", 0) == 0, native["native_counts"]
    assert native["identity"]["completed_tick"] == 0
    wall = {"shape": "rectangle", "x0": 30, "y0": 30,
            "x1": 32, "y1": 32, "material": 58}
    send(commands, tool(2, "prepare_edit", {
        "observation_id": native["observation_id"], "operations": [wall]
    }, "proposed"))
    proposed = check(wait_event(evidence, 2), "proposed")
    health = json.loads((evidence / "session-health.json").read_text())
    state.write_text(json.dumps({
        "proposal_id": proposed["proposal_id"],
        "source_generation": native["identity"]["world_generation"],
        "source_revision": native["identity"]["world_revision"],
        "godot_pid": health["godot_pid"],
        "first_frame_sha256": image_sha,
    }, indent=2) + "\n", encoding="utf-8")
    # Simulated abrupt external-client death. Host Godot must remain alive.
    os._exit(37)


def client_second(commands: Path, evidence: Path, state: Path) -> None:
    previous = json.loads(state.read_text())
    send(commands, tool(3, "apply_edit", {"proposal_id": previous["proposal_id"]}, "applied"))
    applied = check(wait_event(evidence, 3), "applied")
    assert applied["confirmed_writes"] == 9 and applied["changed_cells"] == 9, applied
    send(commands, tool(4, "observe",
                        {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                         "detail": "cells"}, "observed"))
    after = wait_event(evidence, 4)
    native = check(after, "observed")
    frame(evidence, after)
    assert native["identity"]["world_generation"] == previous["source_generation"]
    assert native["identity"]["world_revision"] > previous["source_revision"]
    assert native["native_counts"].get("58") == 9, native["native_counts"]
    health = json.loads((evidence / "session-health.json").read_text())
    assert health["godot_pid"] == previous["godot_pid"], health
    # Stale observation ID is authoritatively refused without accepting a mutation.
    send(commands, tool(5, "prepare_edit", {
        "observation_id": "stale-observation-id",
        "operations": [{"shape": "rectangle", "x0": 34, "y0": 30,
                        "x1": 35, "y1": 31, "material": 58}]
    }, "refused"))
    check(wait_event(evidence, 5), "refused")
    # Second revision depends on the newly acknowledged post-edit observation.
    send(commands, tool(6, "prepare_edit", {
        "observation_id": native["observation_id"],
        "operations": [{"shape": "rectangle", "x0": 34, "y0": 30,
                        "x1": 35, "y1": 31, "material": 58}]
    }, "proposed"))
    proposal = check(wait_event(evidence, 6), "proposed")
    send(commands, tool(7, "apply_edit", {"proposal_id": proposal["proposal_id"]}, "applied"))
    updated = check(wait_event(evidence, 7), "applied")
    assert updated["confirmed_writes"] == 4, updated
    send(commands, tool(8, "step", {"ticks": 4}, "completed"))
    step_receipt = wait_event(evidence, 8)
    step = check(step_receipt, "completed")
    frame(evidence, step_receipt)
    assert step["completed"] == 4 and step["after_tick"] == 4
    assert step["observation"]["identity"]["completed_tick"] == 4
    send(commands, tool(9, "observe",
                        {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                         "detail": "cells"}, "observed"))
    after_step = wait_event(evidence, 9)
    final_observation = check(after_step, "observed")
    frame(evidence, after_step)
    assert final_observation["identity"]["world_generation"] == previous["source_generation"]
    assert final_observation["identity"]["completed_tick"] == 4
    assert final_observation["native_counts"].get("58") == 13
    # Buffer Stop + late mutation together to exercise post-Stop native refusal.
    send(commands,
         tool(10, "stop", {}, "stopped"),
         tool(11, "apply_edit", {"proposal_id": proposal["proposal_id"]}, "refused"))
    assert check(wait_event(evidence, 10), "stopped")["no_further_agent_mutations"] is True
    late = check(wait_event(evidence, 11), "refused")
    assert late["reason"] == "task_not_authorized_or_stopping", late


def client_entry() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--client", required=True, choices=("first", "second"))
    parser.add_argument("--commands", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    args = parser.parse_args()
    if args.client == "first":
        client_first(args.commands, args.evidence, args.state)
    else:
        client_second(args.commands, args.evidence, args.state)
    return 0


class NativeSession:
    def __init__(self, root: Path, godot: Path, authorization: Path,
                 xvfb: bool, *, timeout: int = 180, budget: int = 134217728):
        root.mkdir(parents=True)
        self.root = root
        self.evidence = root / "server"
        self.commands = root / "commands.jsonl"
        self.commands.write_text("", encoding="utf-8")
        argv = [sys.executable, str(HERE / "run.py"), "--godot", str(godot),
                "--authorization", str(authorization), "--commands", str(self.commands),
                "--evidence", str(self.evidence), "--live", "--timeout", str(timeout),
                "--evidence-limit-bytes", str(budget)]
        if xvfb:
            argv.append("--xvfb")
        self.log = (root / "launcher.log").open("wb")
        self.process = subprocess.Popen(argv, stdout=self.log, stderr=subprocess.STDOUT)
        initial = wait_event(self.evidence)
        assert initial.get("status") == "authorized", initial

    def close(self, expected_code: int) -> dict:
        try:
            code = self.process.wait(timeout=90)
            assert code == expected_code, (code, (self.root / "launcher.log").read_text())
            result = json.loads((self.evidence / "cleanup-result.json").read_text())
            assert result["owned_processes_exited"] and result["launcher_child_reaped"], result
            return result
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=5)
            self.log.close()


def exercise(godot: Path, auth: Path, root: Path, xvfb: bool) -> dict:
    positive = NativeSession(root / "positive", godot, auth, xvfb, timeout=240)
    state = positive.root / "client-choice.json"
    try:
        cmd = [sys.executable, str(Path(__file__).resolve()), "--client", "first",
               "--commands", str(positive.commands), "--evidence", str(positive.evidence),
               "--state", str(state)]
        first = subprocess.run(cmd, check=False, timeout=90)
        assert first.returncode == 37, first.returncode
        assert positive.process.poll() is None, "Disconnected client retired host session"
        health = json.loads((positive.evidence / "session-health.json").read_text())
        assert health["last_completed_seq"] == 2, health
        second = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--client", "second",
             "--commands", str(positive.commands), "--evidence", str(positive.evidence),
             "--state", str(state)], check=False, timeout=120
        )
        assert second.returncode == 0, second.returncode
        cleanup = positive.close(0)
        accepted = verify.inspect(positive.evidence, roundtrip=False)
        assert accepted["command_receipts"] == 11 and accepted["completed_native_ticks_total"] == 4
        final = json.loads((positive.evidence / "session-health.json").read_text())
        assert final["last_completed_seq"] == 11
        assert final["process_group_exited"] is True
    finally:
        if positive.process.poll() is None:
            positive.process.kill()
            positive.process.wait()
            positive.log.close()

    controls = {}
    for label in ("duplicate", "malformed", "rewrite", "budget", "interrupt"):
        budget = 13 * 1024 * 1024 if label == "budget" else 128 * 1024 * 1024
        run = NativeSession(root / label, godot, auth, xvfb, timeout=150, budget=budget)
        try:
            if label == "duplicate":
                send(run.commands, tool(1, "observe",
                    {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                     "detail": "cells"}, "observed"))
                check(wait_event(run.evidence, 1), "observed")
                send(run.commands, tool(1, "observe", {}, "refused"))
            elif label == "malformed":
                with run.commands.open("a", encoding="utf-8") as out:
                    out.write("{invalid-json}\n")
            elif label == "rewrite":
                send(run.commands, tool(1, "observe",
                    {"region": {"x": 28, "y": 28, "width": 8, "height": 8},
                     "detail": "cells"}, "observed"))
                check(wait_event(run.evidence, 1), "observed")
                run.commands.write_text('{"invalidated":true}\n', encoding="utf-8")
            elif label == "budget":
                send(run.commands, tool(1, "observe", {}, "refused"))
                refused = wait_event(run.evidence, 1)
                assert refused["result"]["reason"] == "session_evidence_budget_exhausted", refused
            elif label == "interrupt":
                run.process.send_signal(signal.SIGINT)
            outcome = run.close(1)
            controls[label] = outcome["reason"]
            if label != "interrupt":
                manifest = json.loads((run.evidence / "manifest.json").read_text())
                assert manifest["result"] == "failed" and manifest["failures"], manifest
        finally:
            if run.process.poll() is None:
                run.process.kill()
                run.process.wait()
                run.log.close()
    # Intentionally shortened *supervisor-only* deadline to fault-inject real
    # Godot/Xvfb process-tree cleanup; production launch policy remains unchanged.
    forced = root / "forced-timeout"
    forced.mkdir()
    forced_commands = forced / "commands.jsonl"
    forced_commands.write_text("", encoding="utf-8")
    forced_evidence = forced / "server"
    forced_evidence.mkdir()
    env = os.environ.copy()
    env["CYBERSAND_SESSION_ID"] = "forced-timeout-native-test"
    env["CYBERSAND_EVIDENCE_LIMIT_BYTES"] = str(128 * 1024 * 1024)
    invocation = runner.build_command(godot, auth, forced_commands,
                                      forced_evidence, True, xvfb, 120)
    with (forced_evidence / "godot.log").open("wb") as log:
        code, reason, cleanup = runner.supervise(
            invocation, env, log, forced_evidence, timeout=3,
            limit=128 * 1024 * 1024,
        )
    runner.atomic_json(forced_evidence / "cleanup-result.json", cleanup)
    assert code == 124 and reason == "timeout" and cleanup["owned_processes_exited"], cleanup
    result = {"status": "real_live_exercised", "positive": accepted,
              "original_pid": json.loads(state.read_text())["godot_pid"],
              "disconnected_client_exit": 37, "negative_controls": controls,
              "native_xvfb_forced_timeout": cleanup}
    (root / "live-qualification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, sort_keys=True))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--authorization", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--xvfb", action="store_true")
    args = parser.parse_args()
    exercise(args.godot.resolve(), args.authorization.resolve(),
             args.evidence.resolve(), args.xvfb)
    return 0


if __name__ == "__main__":
    raise SystemExit(client_entry() if "--client" in sys.argv else main())
