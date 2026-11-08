#!/usr/bin/env python3
"""Real external-client qualifier for a pre-existing native workbench service.

Run this on the client host, not in the Godot/native container. This uses the
existing client.py CLI in fresh child processes and only the five supported
workbench commands. It cannot create a World or change host authorization.
No credentials are included in the output or transcript.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from qualify_live import Driver, changed_pixels, digest, generation_of, native_result, require


def uncredentialed_http(base: str, method: str, path: str, body: bytes | None = None) -> int:
    request = Request(base + path, method=method, data=body)
    try:
        with urlopen(request, timeout=8) as response:
            return response.status
    except HTTPError as error:
        return error.code


def frame_from_receipt(driver: Driver, receipt: dict, label: str, output: Path) -> Path:
    frame = receipt.get("receipt", {}).get("frame", {})
    require(frame.get("status") == "original_post_draw", label + ": no original frame")
    relative = frame.get("path")
    checksum = frame.get("sha256")
    require(isinstance(relative, str) and relative.startswith("frames/"),
            label + ": invalid frame path")
    return driver.frame(label, relative.removeprefix("frames/"), checksum, output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="http://127.0.0.1:8765")
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--startup-deadline", type=float, default=300.0)
    args = parser.parse_args()
    from client import validate_base
    args.base = validate_base(args.base)
    port = int(args.base.rsplit(":", 1)[1])
    output = args.output.resolve()
    require(not output.exists() or not any(output.iterdir()),
            "Output directory must be empty; do not overwrite original evidence")
    output.mkdir(parents=True, exist_ok=True)
    (output / "frames").mkdir()
    token = args.token_file.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="wb-external-wrong-bearer-") as temporary:
        wrong = Path(temporary) / "wrong-bearer"
        wrong.write_text(secrets.token_urlsafe(48) + "\n", encoding="utf-8")
        os.chmod(wrong, 0o600)
        driver = Driver(output, token, wrong, port, 330)
        require(uncredentialed_http(args.base, "GET", "/v1/session") == 401,
                "missing bearer unexpectedly accessed session")
        require(uncredentialed_http(args.base, "GET", "/v1/frames/001-observe.png") == 401,
                "missing bearer unexpectedly accessed original PNG")
        require(uncredentialed_http(
            args.base, "POST", "/v1/commands",
            b'{"tool":"observe","args":{}}') == 401,
            "missing bearer unexpectedly submitted command")
        wrong_code, wrong_doc = driver.run_client(
            "wrong-bearer-rejected", "session", wrong_token=True
        )
        require(wrong_code != 0 and wrong_doc.get("error") == "bearer_authentication_required",
                "wrong bearer unexpectedly authenticated")

        deadline = time.monotonic() + args.startup_deadline
        start = None
        while time.monotonic() < deadline:
            code, state = driver.run_client("ready-poll", "session", record=False)
            if code == 0 and state.get("phase") == "ready":
                start = state
                break
            if code == 0 and state.get("phase") == "unconfirmed":
                raise AssertionError("host session unconfirmed before authorization")
            time.sleep(0.3)
        require(start is not None and start.get("native_generation") is not None,
                "native authority did not publish a ready World generation")
        sid = start["session_id"]
        generation = start["native_generation"]
        genid = start["generation_id"]

        observation = driver.call(
            "observe-first", "observe", sid, "req-ext-observe001",
            {"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"})
        native_first = native_result(observation)
        require(native_first.get("status") == "observed", "no first native observation")
        image_first = frame_from_receipt(
            driver, observation, "frame-first", output / "frames" / "first.png")

        prepared = driver.call(
            "prepare-first", "prepare_edit", sid, "req-ext-prepare001",
            {"observation_id":native_first["observation_id"],
             "operations":[{"shape":"rectangle","x0":30,"y0":30,"x1":32,"y1":32,
                            "material":58}]})
        proposal = native_result(prepared)["proposal_id"]
        applied = driver.call("apply-first", "apply_edit", sid, "req-ext-apply001",
                              {"proposal_id":proposal})
        require(native_result(applied).get("status") == "applied",
                "original native edit unacknowledged")
        before_duplicate = driver.run_client("status-before-duplicate", "session")[1]
        duplicate = driver.call("duplicate-same-id", "apply_edit", sid, "req-ext-apply001",
                                {"proposal_id":proposal})
        after_duplicate = driver.run_client("status-after-duplicate", "session")[1]
        require(duplicate["receipt"] == applied["receipt"] and
                before_duplicate["commands_submitted"] == after_duplicate["commands_submitted"],
                "duplicate native mutation was enqueued")

        no_wait = driver.call(
            "disconnect-after-submit", "observe", sid, "req-ext-reconnect001",
            {"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"},
            no_wait=True)
        require(no_wait.get("state") == "pending", "disconnect control not pending")
        # The original submitting subprocess is gone. Query from another.
        after = driver.request("reconnect-observation", "req-ext-reconnect001")
        native_after = native_result(after)
        image_after = frame_from_receipt(
            driver, after, "frame-after-apply", output / "frames" / "after.png")
        changed1 = changed_pixels(image_first, image_after)
        require(changed1 > 0, "native apply had no rendered framebuffer delta")
        counts = native_after.get("native_counts", {})
        walls = int(counts.get("58", counts.get(58, -1)))
        require(walls == 9, "native receipt does not verify nine authored walls")

        # Choose a second edit based on the returned first-edit native count.
        # This removes one of nine previously confirmed Hard Wall cells.
        revised = driver.call(
            "prepare-revision", "prepare_edit", sid, "req-ext-prepare002",
            {"observation_id":native_after["observation_id"],
             "operations":[{"shape":"rectangle","x0":31,"y0":31,"x1":31,"y1":31,
                            "material":0}]})
        second = driver.call(
            "apply-revision", "apply_edit", sid, "req-ext-apply002",
            {"proposal_id":native_result(revised)["proposal_id"]})
        require(native_result(second).get("status") == "applied",
                "native revision unacknowledged")
        check = driver.call(
            "observe-revision", "observe", sid, "req-ext-observe002",
            {"region":{"x":28,"y":28,"width":8,"height":8},"detail":"cells"})
        image_revision = frame_from_receipt(
            driver, check, "frame-revision", output / "frames" / "revision.png")
        native_revision = native_result(check)
        changed2 = changed_pixels(image_after, image_revision)
        require(changed2 > 0, "second edit caused no rendered change")
        counts2 = native_revision.get("native_counts", {})
        require(int(counts2.get("58", counts2.get(58, -1))) == 8,
                "second native edit did not leave eight walls")

        stepped = driver.call("step-four", "step", sid, "req-ext-step0001", {"ticks":4})
        step_native = native_result(stepped)
        require(step_native.get("status") == "completed" and
                step_native.get("completed") == 4, "native Step incomplete")
        image_step = frame_from_receipt(
            driver, stepped, "frame-step", output / "frames" / "step.png")
        generation_set = {generation_of(native_first),
                          generation_of(native_after), generation_of(native_revision),
                          generation_of(step_native.get("observation", {}))}
        generation_set.discard(None)
        require(len(generation_set) == 1 and generation in generation_set,
                "native World changed across the external client iterations")
        snapshot = driver.run_client("session-before-stop", "session")[1]
        require(snapshot.get("session_id") == sid
                and snapshot.get("generation_id") == genid
                and snapshot.get("completed_native_ticks_total") == 4,
                "persistent session or native tick accounting changed")
        stopped = driver.call("stop-native", "stop", sid, "req-ext-stop0001", {})
        require(native_result(stopped).get("status") == "stopped",
                "native owner did not acknowledge retirement")
        # The service serves a finite terminal status window after Stop. 409
        # is an explicit refusal; a failed TCP connection is not accepted here.
        late_code, late = driver.run_client(
            "late-mutation-refused", "call", "apply_edit", "--session", sid,
            "--request-id", "req-ext-lateapply",
            "--args", json.dumps({"proposal_id":proposal},
                                 separators=(",", ":")), "--no-wait")
        require(late_code != 0 and
                late.get("error") in (
                    "stop_already_queued", "session_not_accepting_commands"),
                "late mutation lacked an explicit HTTP refusal")

        artifact_index = {}
        for item in sorted(output.rglob("*")):
            if item.is_file() and item.name != "qualification.json":
                artifact_index[str(item.relative_to(output))] = {
                    "bytes": item.stat().st_size, "sha256": digest(item)
                }
        report = {
            "schema_version":1, "result":"passed",
            "access_mode":"separate_client_process_over_loopback_forwarding",
            "actual_codespace_tunnel_tested": False,
            "native_generation":generation, "transport_session_id":sid,
            "generation_id":genid, "native_ticks_completed":4,
            "duplicate_mutation_prevented":True,
            "missing_bearer_401":True, "wrong_bearer_401":True,
            "missing_bearer_png_401":True,
            "missing_bearer_command_401":True,
            "reconnect_same_session":True,
            "confirmed_walls_first":walls, "confirmed_walls_second":8,
            "changed_frame_pixels_first":changed1,
            "changed_frame_pixels_revision":changed2,
            "late_mutation_http_refused":True,
            "original_frame_paths":[str(p.relative_to(output))
                                    for p in (image_first,image_after,image_revision,image_step)],
            "artifacts":artifact_index
        }
        (output / "client-transcripts.json").write_text(
            json.dumps(driver.transcripts, indent=2) + "\n", encoding="utf-8")
        (output / "qualification.json").write_text(
            json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k:v for k,v in report.items() if k not in ("artifacts",)},
                         sort_keys=True))
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
