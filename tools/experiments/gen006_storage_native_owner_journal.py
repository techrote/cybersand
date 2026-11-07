#!/usr/bin/env python3
"""G6J1 opt-in frozen-tick native-owner storage adapter and hard-crash qualification.

A generated, source-pinned copy of #486's real C++ service emits STAGED
(non-durable) receipts without per-edit full-CYPS publication. This *isolated*
Python owner serializes requests, validates the native receipt, fsyncs a G6J1
mutation record, and only then returns its own durable ACK. On any ambiguity,
the native owner is killed; it is never allowed to serve further requests.
The tested domain is a single frozen-tick (-1,-3) shard and five native edits.
This is not a production Godot controller, general fluid tick replay, power-loss
proof, or proof that the expensive per-edit World clone has been eliminated.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from gen006_storage_journal import Identity, Journal, Mutation, recover, replay_checked
from gen006_storage_native_owner_control import (
    READY, percentile_nearest, send_request, wait_file,
)
from gen006_storage_native_pilot import (
    ACK, CHUNK, COMMANDS, native_cyps, native_record, require, run_native, status,
)

SOURCE_BLOB = "c172bb0d9b82e31b97a6a002990d3f084e308d2f"
STAGED = re.compile(
    r"^GEN006_EDIT_UNDURABLE_STAGE chunk=\(-1,-3\) local=\((\d+),(\d+)\) "
    r"generation=(\d+) physical_hash=(\d+) native_tick=(\d+) file_published=0$",
    re.MULTILINE,
)
# One Hz is intentionally the slowest native service tick setting. Every
# receipt must still prove tick 0; elapsed-time assumptions are NOT sufficient.
EXPERIMENT_TICK_HZ = 1


def prepare_staging_source(source: Path, destination: Path) -> str:
    """A three-anchor copy-only adaptation; never change #486 or native physics."""
    raw = source.read_bytes()
    blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    require(blob == SOURCE_BLOB, "G6J_STAGED_SOURCE_UNPINNED")
    text = raw.decode("utf-8")
    replacements = (
        ("persist(c, staged); // synchronous file flush, replace and POSIX dir sync",
         "// G6J1 scratch service: outer serialized owner alone decides durability."),
        ("GEN006_EDIT_DURABLE_ACK chunk=(", "GEN006_EDIT_UNDURABLE_STAGE chunk=("),
        ("file_published=1\\n", "file_published=0\\n"),
    )
    for old, new in replacements:
        require(text.count(old) == 1, "G6J_STAGE_ANCHOR_CHANGED")
        text = text.replace(old, new)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text, encoding="utf-8")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def serve(exe: Path, root: Path, ipc: Path, workers: int):
    root.mkdir(parents=True)
    ipc.mkdir(parents=True)
    proc = subprocess.Popen(
        [str(exe), "--serve", str(root), str(ipc),
         str(workers), str(EXPERIMENT_TICK_HZ)],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace",
    )
    try:
        ready = wait_file(ipc / "ready.txt", proc, time.monotonic() + 75)
        m = READY.search(ready)
        require(m is not None and
                (int(m[1]), int(m[2]), int(m[3])) ==
                (proc.pid, workers, EXPERIMENT_TICK_HZ),
                "G6J_STAGE_OWNER_READY_REFUSED")
    except BaseException:
        proc.kill()
        proc.communicate(timeout=15)
        raise
    return proc


def retire(proc: subprocess.Popen, work: Path, label: str) -> None:
    if proc.poll() is None:
        proc.kill()  # no quit, no save_all, no graceful checkpoint
    out, err = proc.communicate(timeout=20)
    (work / (label + ".stdout.txt")).write_text(out, encoding="utf-8")
    (work / (label + ".stderr.txt")).write_text(err, encoding="utf-8")


def owner_case(exe: Path, base: bytes, baseline: Identity, root: Path,
               work: Path, workers: int, staged: bool):
    """Execute a live native owner; expose an ACK only after the chosen barrier."""
    label = "journal-stage" if staged else "full-checkpoint-control"
    live = root / "world"
    ipc = root / "ipc"
    live.mkdir(parents=True)
    native_record(live).write_bytes(base)
    proc = serve(exe, live, ipc, workers)
    journal = None
    receipts = []
    timings = []
    acknowledged = []
    try:
        first, _ = send_request(ipc, proc, 1, "focus -1 -3\nstatus")
        require(status(first) ==
                (baseline.generation, baseline.physical_hash, baseline.tick),
                "G6J_STAGE_INITIAL_NATIVE_SOURCE_DRIFT")
        if staged:
            # The baseline includes G6SLICE1 recipe identity, CYPS and explicit
            # player Empty mask; publication is durable before any outer ACK.
            journal = Journal.create(root / "owner-edits.g6j", baseline, base)
        for i, (command, kind, x, y, amount, temp) in enumerate(COMMANDS):
            start = time.perf_counter_ns()
            response, _ = send_request(ipc, proc, i + 2, command + "\nstatus")
            matches = (STAGED if staged else ACK).findall(response)
            require(len(matches) == 1, "G6J_STAGE_NATIVE_RECEIPT_MISSING")
            lx, ly, gen, physical_hash, native_tick = map(int, matches[0])
            require((lx, ly) == (x, y) and
                    gen == baseline.generation + i + 1 and
                    native_tick == baseline.tick and
                    status(response) == (gen, physical_hash, native_tick),
                    "G6J_STAGE_NATIVE_FROZEN_EPOCH_REFUSED")
            if staged:
                # Refuse if the staged native process has independently
                # published a complete CYPS checkpoint. We require its
                # *unsaved* live World to be the journal's mutation source.
                require(native_record(live).read_bytes() == base,
                        "G6J_STAGE_UNEXPECTED_NATIVE_FULL_CHECKPOINT")
                edit = Mutation(kind, x, y, amount, temp,
                                gen, native_tick, physical_hash)
                require(journal is not None, "G6J_STAGE_JOURNAL_MISSING")
                journal.append(edit, journal.state.generation)
                # Re-read the actual durable record, not merely in-memory state.
                verified = recover(journal.path)
                require(not verified.torn_tail and verified.edits[-1] == edit and
                        verified.generation == gen,
                        "G6J_STAGE_POST_FSYNC_RECOVERY_REFUSED")
            else:
                record = native_record(live).read_bytes()
                record_generation, _ = native_cyps(record)
                require(record_generation == gen,
                        "G6J_CONTROL_POST_ACK_NATIVE_RECORD_REFUSED")
            elapsed = (time.perf_counter_ns() - start) / 1_000_000
            receipts.append((lx, ly, gen, physical_hash, native_tick))
            timings.append(elapsed)
            # This is the ONLY client-visible ACK in staged mode; source
            # native response is explicitly UNdurable until the journal sync.
            acknowledged.append({
                "generation": gen, "tick": native_tick,
                "physical_hash": physical_hash, "outer_ack_after_fsync": staged,
            })
        require(len(receipts) == len(COMMANDS),
                "G6J_STAGE_ACK_COUNT_REFUSED")
        require(staged is False or native_record(live).read_bytes() == base,
                "G6J_STAGE_NATIVE_CHECKPOINT_AMPLIFICATION")
    finally:
        retire(proc, work, label + "-killed")
    require(proc.returncode != 0 and
            not (ipc / "stopped.txt").exists(),
            "G6J_STAGE_OWNER_NOT_HARD_KILLED")
    result = {
        "pid": proc.pid, "returncode": proc.returncode,
        "native_receipts": receipts, "acknowledgments": acknowledged,
        "ack_ipc_through_fsync_ms": timings,
        "p50_ms": percentile_nearest(timings, 0.50),
        "p95_ms": percentile_nearest(timings, 0.95),
        "p99_ms": percentile_nearest(timings, 0.99),
        "staged": staged, "native_file_after_crash_sha256":
            hashlib.sha256(native_record(live).read_bytes()).hexdigest(),
    }
    if staged:
        require(journal is not None and
                recover(journal.path).generation == receipts[-1][2],
                "G6J_STAGE_RECOVERY_AFTER_OWNER_KILL_REFUSED")
    return result, journal


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--original-exe", type=Path, required=True)
    parser.add_argument("--staged-exe", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), required=True)
    parser.add_argument("--native-sha", required=True)
    args = parser.parse_args()
    work = args.root.resolve()
    require(not work.exists(), "G6J_STAGE_WORKROOT_MUST_BE_FRESH")
    work.mkdir(parents=True)
    original = args.original_exe.resolve(strict=True)
    staged_exe = args.staged_exe.resolve(strict=True)
    baseline_out, base = run_native(original, work / "baseline", work,
                                    [], args.workers, "frozen-base")
    base_generation, _ = native_cyps(base)
    gen, h, tick = status(baseline_out)
    require(base_generation == gen and tick == 0,
            "G6J_STAGE_NATIVE_BASELINE_NOT_FROZEN")
    # The host owns session/incarnation, recipe and stage disposition.
    # A new native process is never allowed to reuse the previous identity.
    incarnation = int.from_bytes(os.urandom(8), "little") or 1
    identity = Identity(CHUNK[0], CHUNK[1], incarnation, gen, tick, h)
    staged_result, journal = owner_case(
        staged_exe, base, identity, work / "stage", work, args.workers, True)
    require(journal is not None, "G6J_STAGE_JOURNAL_ABSENT")
    control_result, _ = owner_case(
        original, base, identity, work / "control", work, args.workers, False)
    require(staged_result["native_receipts"] == control_result["native_receipts"],
            "G6J_STAGE_FULL_CONTROL_NATIVE_RECEIPT_DIVERGENCE")
    recovered = recover(journal.path)
    require(recovered.checkpoint == base and
            recovered.identity == identity and
            len(recovered.edits) == len(COMMANDS) and not recovered.torn_tail,
            "G6J_STAGE_JOURNAL_NOT_SELF_CONTAINED")

    # The original full-checkpoint is deliberately unavailable to the
    # recovery processes. Native replay must start ONLY with journal content.
    source_file = native_record(work / "stage" / "world")
    require(source_file.read_bytes() == base, "G6J_STAGE_FULL_RECORD_CHANGED")
    source_file.unlink()
    observed = [h]
    replay_records = []
    for idx, edit in enumerate(recovered.edits):
        require((edit.kind, edit.x, edit.y, edit.amount, edit.temperature) ==
                COMMANDS[idx][1:], "G6J_STAGE_NATIVE_COMMAND_IDENTITY_REFUSED")

    def apply(edit: Mutation) -> bool:
        count = len(replay_records) + 1
        path = work / ("replay-" + str(count))
        path.mkdir()
        native_record(path).write_bytes(recovered.checkpoint)
        output, restored = run_native(original, path, work,
                                      [x[0] for x in COMMANDS[:count]],
                                      args.workers, "native-replay-" + str(count))
        rows = [tuple(map(int, row)) for row in ACK.findall(output)]
        require(rows == staged_result["native_receipts"][:count],
                "G6J_STAGE_REPLAY_NATIVE_RECEIPT_MISMATCH")
        require(status(output) == (edit.generation, edit.physical_hash, tick),
                "G6J_STAGE_REPLAY_NATIVE_STATE_MISMATCH")
        observed[0] = edit.physical_hash
        replay_records.append(restored)
        return True

    replay_checked(recovered, apply, lambda: observed[0])
    control_bytes = native_record(work / "control" / "world").read_bytes()
    require(replay_records[-1] == control_bytes,
            "G6J_STAGE_REPLAY_FULL_CARRIER_CONTROL_DRIFT")
    restored_out, restored_bytes = run_native(
        original, work / "post-restart", work, [], args.workers, "fresh-restart")
    # The fresh process above starts a fresh generated World. Now independently
    # re-open the recovered carrier in a second new native process.
    restore_dir = work / "verified-restart"
    restore_dir.mkdir()
    native_record(restore_dir).write_bytes(replay_records[-1])
    restored_out, restored_bytes = run_native(
        original, restore_dir, work, [], args.workers, "verified-restart")
    require(restored_bytes == replay_records[-1] and
            status(restored_out) ==
            (recovered.generation, recovered.edits[-1].physical_hash, tick) and
            "liquid=17 temp=417 intent=1" in restored_out and
            "local=(5,5)" in restored_out,
            "G6J_STAGE_FRESH_NATIVE_RESTART_REFUSED")

    full_total = sum(len(row) for row in replay_records)
    journal_bytes = journal.path.stat().st_size
    require(journal_bytes == 64 + len(base) + 48 * len(COMMANDS),
            "G6J_STAGE_JOURNAL_VOLUME_REFUSED")
    receipt = {
        "native_reference_sha": args.native_sha,
        "source_blob": SOURCE_BLOB,
        "workers": args.workers,
        "native_tick_hz": EXPERIMENT_TICK_HZ,
        "scope": "single frozen-tick shard, no production persistence adoption",
        "journal_integrated_external_serialized_owner": True,
        "native_owner_hard_killed": True,
        "native_full_per_edit_publication_suppressed": True,
        "native_clone_per_edit_still_present": True,
        "journal_durable_before_outer_ack": True,
        "native_source_bytes_after_stage": len(base),
        "total_full_checkpoint_payload": full_total,
        "journal_payload_bytes": journal_bytes,
        "stage": staged_result, "control": control_result,
        "filesystem_physical_bytes_measured": False,
        "native_tick_cpu_measured": False,
        "power_loss_claim": False,
        "general_dynamic_simulation_supported": False,
    }
    (work / "journal-native-owner-report.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("GEN006_G6J1_STAGED_NATIVE_OWNER_CRASH_PASS"
          " workers={} native_sha={} hard_killed=1"
          " journal_ack_generations={} frozen_tick={}"
          " native_replay=PASS restored_Water17=17 Empty_intent=1"
          " full_checkpoint_bytes={} journal_bytes={}"
          " staged_p50_ms={:.3f} control_p50_ms={:.3f}"
          " no_30hz_or_power_loss_claim=1".format(
              args.workers, args.native_sha, len(recovered.edits), tick,
              full_total, journal_bytes,
              staged_result["p50_ms"], control_result["p50_ms"]))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as exc:
        import sys
        print("GEN006_G6J1_STAGED_OWNER_FAIL " + str(exc), file=sys.stderr)
        raise SystemExit(1)
