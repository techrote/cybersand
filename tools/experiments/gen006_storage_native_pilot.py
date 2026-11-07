#!/usr/bin/env python3
"""G6J1 real-native, frozen-tick CYPS checkpoint/replay pilot.

Experimental only. Executes the pinned #486 native streaming-slice binary in
separate OS processes, not a Python World mock. The G6J1 journal remains OUTSIDE
the live owner; native editing still uses its original full-checkpoint path.
A hard-exited journal-writer child and newly launched native World processes
prove acknowledged storage recovery plus exact source-matched replay. This does
NOT prove native-owner crash durability under a journal-integrated controller,
30Hz throughput, simulation-tick continuation or power-loss persistence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import time

from gen006_storage_journal import Identity, Journal, Mutation, recover, replay_checked

CHUNK = (-1, -3)
COMMANDS = (
    ("dig 5 5", 2, 5, 5, 0, 0),
    ("wall 18 31", 1, 18, 31, 0, 0),
    ("wall 17 30", 1, 17, 30, 0, 0),
    ("wall 19 30", 1, 19, 30, 0, 0),
    ("watertemp 18 30 17 417", 4, 18, 30, 17, 417),
)
STATUS = re.compile(
    r"^  chunk=\(-1,-3\) gen=(\d+) physical_hash=(\d+) ticks=(\d+)\b",
    re.MULTILINE,
)
ACK = re.compile(
    r"^GEN006_EDIT_DURABLE_ACK chunk=\(-1,-3\) local=\((\d+),(\d+)\) "
    r"generation=(\d+) physical_hash=(\d+) native_tick=(\d+) file_published=1$",
    re.MULTILINE,
)


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def native_record(root: Path) -> Path:
    return root / "chunk_x-1_y-3.g6s"


def run_native(exe: Path, root: Path, work: Path, commands: list[str],
               workers: int, label: str) -> tuple[str, bytes]:
    root.mkdir(parents=True, exist_ok=True)
    script = work / (label + ".commands.txt")
    script.write_text("focus -1 -3\n" + "\n".join(commands) +
                      "\nstatus\ninspect 5 5\ninspect 18 30\nquit\n",
                      encoding="utf-8")
    proc = subprocess.run([str(exe), "--batch", str(root), str(script), str(workers)],
                          capture_output=True, text=True, errors="replace",
                          timeout=90, check=False)
    (work / (label + ".stdout.txt")).write_text(proc.stdout, encoding="utf-8")
    (work / (label + ".stderr.txt")).write_text(proc.stderr, encoding="utf-8")
    require(proc.returncode == 0 and "REFUSED " not in proc.stderr,
            label + " native failure: " + proc.stderr[-2500:])
    require("SAVE_ALL resident=" in proc.stdout, label + " native save missing")
    record = native_record(root)
    require(record.is_file(), label + " native CYPS carrier missing")
    return proc.stdout, record.read_bytes()


def status(output: str) -> tuple[int, int, int]:
    matches = STATUS.findall(output)
    require(len(matches) == 1, "missing/ambiguous actual native status")
    return tuple(map(int, matches[0]))


def native_cyps(record: bytes) -> tuple[int, bytes]:
    # Actual #486 G6SLICE1 outer carrier; only CYPS is journalled as baseline.
    # Reject a changed/incompatible envelope rather than mislabel bytes as CYPS.
    require(len(record) >= 68 + 512 and record[:8] == b"G6SLICE1",
            "G6J_NATIVE_OUTER_SCHEMA_REFUSED")
    require(struct.unpack_from("<I", record, 8)[0] == 1 and
            struct.unpack_from("<q", record, 12)[0] == CHUNK[0] and
            struct.unpack_from("<q", record, 20)[0] == CHUNK[1],
            "G6J_NATIVE_OUTER_IDENTITY_REFUSED")
    generation = struct.unpack_from("<Q", record, 44)[0]
    mask_len, native_len = struct.unpack_from("<II", record, 52)
    require(mask_len == 512 and 0 < native_len <= 2_097_152 and
            len(record) == 68 + mask_len + native_len,
            "G6J_NATIVE_OUTER_LENGTH_REFUSED")
    cyps = record[68 + mask_len:]
    require(cyps.startswith(b"CYPS"), "G6J_NOT_A_NATIVE_CYPS_CHECKPOINT")
    return generation, cyps


def writer_child(meta: Path) -> None:
    info = json.loads(meta.read_text(encoding="utf-8"))
    p = Path(info["work"])
    ident = Identity(*info["identity"])
    journal = Journal.create(p / "edits.g6j", ident,
                             (p / "native-base.cyps").read_bytes())
    for x in info["edits"]:
        mutation = Mutation(*x)
        journal.append(mutation, journal.state.generation)
    # No destructor, final save, atexit or orderly writer shutdown.
    os._exit(0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True, type=Path)
    ap.add_argument("--root", required=True, type=Path)
    ap.add_argument("--workers", required=True, type=int, choices=(1, 4))
    ap.add_argument("--native-sha", required=True)
    args = ap.parse_args()
    exe = args.exe.resolve(strict=True)
    work = args.root.resolve()
    require(not work.exists(), "G6J_NATIVE_PILOT_REQUIRES_FRESH_WORKROOT")
    work.mkdir(parents=True)
    base_root = work / "base"
    original, base_record = run_native(exe, base_root, work, [], args.workers, "base")
    base_generation, cyps = native_cyps(base_record)
    generation, base_hash, tick = status(original)
    require(base_generation == generation and tick == 0,
            "G6J_NATIVE_PILOT_BASE_NOT_FROZEN")
    (work / "native-base.cyps").write_bytes(cyps)
    (work / "native-base.g6s").write_bytes(base_record)

    # Obtain real native edit receipts without advancing World::tick().
    stage = work / "stage"
    stage.mkdir()
    shutil.copy2(work / "native-base.g6s", native_record(stage))
    commands = [row[0] for row in COMMANDS]
    staged, final_record = run_native(exe, stage, work, commands,
                                      args.workers, "staged-native")
    acknowledgments = [tuple(map(int, row)) for row in ACK.findall(staged)]
    require(len(acknowledgments) == len(COMMANDS),
            "G6J_NATIVE_ACK_COUNT_REFUSED")
    edits = []
    for i, (command, kind, x, y, amount, temp) in enumerate(COMMANDS):
        ax, ay, gen, physical_hash, edit_tick = acknowledgments[i]
        require((ax, ay) == (x, y) and gen == base_generation + i + 1 and
                edit_tick == tick, "G6J_NATIVE_ACK_IDENTITY_OR_TICK_REFUSED")
        edits.append(Mutation(kind, x, y, amount, temp, gen, edit_tick, physical_hash))
    require("intent=1" in staged and "liquid=17 temp=417 intent=1" in staged,
            "G6J_NATIVE_WATER_OR_EMPTY_REFUSED")
    require(status(staged) == (edits[-1].generation, edits[-1].physical_hash, tick),
            "G6J_NATIVE_FINAL_STATE_REFUSED")

    # Kill the external journal-writer process after REAL native hashes are
    # durably appended; the native process used above exited normally.
    identity = Identity(CHUNK[0], CHUNK[1], 0x63A19D170006,
                        base_generation, tick, base_hash)
    meta = {"work": str(work), "identity": list(identity.__dict__.values()),
            "edits": [list(x.__dict__.values()) for x in edits]}
    metadata = work / "writer-input.json"
    metadata.write_text(json.dumps(meta), encoding="utf-8")
    child = subprocess.run([sys.executable, str(Path(__file__).resolve()),
                            "--journal-child", str(metadata)],
                           capture_output=True, text=True, timeout=30, check=False)
    require(child.returncode == 0, "G6J_ABRUPT_WRITER_CHILD_FAILED " + child.stderr)
    recovered = recover(work / "edits.g6j")
    require(recovered.identity == identity and recovered.checkpoint == cyps and
            recovered.edits == tuple(edits) and not recovered.torn_tail,
            "G6J_ABRUPT_WRITER_RECOVERY_REFUSED")

    # replay_checked calls the actual separately launched native World binary
    # for EACH cumulative prefix, never mutating a live World or trusting a
    # synthetic hash oracle. The initial #486 G6SLICE1 carrier binds the native
    # CYPS checkpoint, recipe, player Empty mask and real coordinate.
    observed_hash = [base_hash]
    stage_records = []
    prefix: list[str] = []

    def apply(edit: Mutation) -> bool:
        prefix.append(COMMANDS[len(prefix)][0])
        slot = work / ("native-replay-" + str(len(prefix)))
        slot.mkdir()
        shutil.copy2(work / "native-base.g6s", native_record(slot))
        out, blob = run_native(exe, slot, work, prefix, args.workers,
                               "replay-" + str(len(prefix)))
        receipts = [tuple(map(int, row)) for row in ACK.findall(out)]
        require(len(receipts) == len(prefix),
                "G6J_NATIVE_REPLAY_ACK_COUNT_REFUSED")
        for j, receipt in enumerate(receipts):
            require(receipt == (edits[j].x, edits[j].y,
                                edits[j].generation, edits[j].physical_hash, tick),
                    "G6J_NATIVE_REPLAY_RECEIPT_DRIFT")
        require(status(out) == (edit.generation, edit.physical_hash, tick),
                "G6J_NATIVE_REPLAY_STATUS_DRIFT")
        observed_hash[0] = status(out)[1]
        stage_records.append(blob)
        return True

    replay_checked(recovered, apply, lambda: observed_hash[0])
    require(stage_records[-1] == final_record,
            "G6J_NATIVE_REPLAY_FULL_CYPS_CARRIER_MISMATCH")
    require(native_cyps(stage_records[-1])[1] ==
            native_cyps(final_record)[1],
            "G6J_NATIVE_REPLAY_PHYSICAL_BYTES_MISMATCH")
    # Real native-generated payload comparison, not disk syscall, native tick,
    # end-to-end ACK latency or production write-amplification measurement.
    # Each of the five complete native G6SLICE1 files is from an actual
    # source-matched World after the corresponding durable edit. G6J1 stores
    # the original CYPS payload once plus 48 bytes per edit.
    native_full_payload = sum(len(blob) for blob in stage_records)
    journal_payload = (work / "edits.g6j").stat().st_size
    require(native_full_payload > 0 and
            journal_payload == 64 + len(cyps) + len(edits) * 48,
            "G6J_NATIVE_STORAGE_PAYLOAD_ACCOUNTING_REFUSED")
    print("GEN006_G6J1_REAL_NATIVE_PAYLOAD full_checkpoint_bytes={}"
          " journal_baseline_plus_edits_bytes={}"
          " journal_percent_of_full={:.2f}"
          " no_latency_or_tick_speedup_claim=1".format(
              native_full_payload, journal_payload,
              100.0 * journal_payload / native_full_payload))
    require(Journal.open(work / "edits.g6j", *CHUNK, identity.incarnation)
            .state.generation == edits[-1].generation,
            "G6J_RECOVERED_JOURNAL_NOT_REOPENABLE")
    print("GEN006_G6J1_NATIVE_CYPS_REPLAY_PASS"
          " workers={} native_sha={} child_hard_exit=1"
          " real_native_processes={} frozen_tick={} journaled_edits={}"
          " final_generation={} final_physical_hash={} Water17=17"
          " temperature417=417 Empty_intent=1".format(
              args.workers, args.native_sha, 2 + len(COMMANDS),
              tick, len(edits), edits[-1].generation, edits[-1].physical_hash))
    print("GEN006_G6J1_LIMITS journal_not_controller_integrated=1"
          " no_native_owner_crash_test=1 no_continuous_tick=1"
          " no_production_speedup_claim=1")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--journal-child":
        writer_child(Path(sys.argv[2]))
    else:
        try:
            raise SystemExit(main())
        except (AssertionError, ValueError, OSError, subprocess.SubprocessError) as exc:
            print("GEN006_G6J1_NATIVE_PILOT_FAIL " + str(exc), file=sys.stderr)
            raise SystemExit(1)
