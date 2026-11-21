#!/usr/bin/env python3
"""Real native GEN-006 acknowledged-edit crash/restart qualification.

Uses two genuinely separate compiled C++ --serve processes. Immediately kills
the first process AFTER the returned edit ACK but WITHOUT a quit/save_all or
eviction. The second process must reload the persisted native World, Water17,
temperature417, player Empty tombstone and monotonic edit generation.

Intentionally bounded to this opt-in, single-owner sharded-World prototype.
No hardware power-cut, concurrent save writer, pending physics or cross-shard
transfer is claimed as qualified.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys

from gen006_surface_owner_containment import NativeService, require


def cell(response: str, local: tuple[int, int]) -> str:
    prefix = "CELL chunk=(-1,-3) local=({},{})".format(*local)
    matches = [line for line in response.splitlines()
               if line.startswith(prefix)]
    require(len(matches) == 1, "missing/duplicate actual native cell " + prefix)
    return matches[0]


def resident_line(response: str) -> str:
    matches = [line for line in response.splitlines()
               if line.startswith("  chunk=(-1,-3) gen=")]
    require(len(matches) == 1, "signed native residency missing")
    return matches[0]


def digest(path: Path) -> str:
    require(path.is_file() and path.stat().st_size > 1024,
            "acknowledged native CYPS record absent on disk: " + str(path))
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--logs", type=Path, required=True)
    parser.add_argument("--workers", type=int, choices=(1, 4), required=True)
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    root = args.root.resolve()
    logs = args.logs.resolve()
    require(not root.exists() and not logs.exists(),
            "GEN006_ACK_RESTART_REQUIRES_FRESH_ROOTS")
    logs.mkdir(parents=True)
    owner: NativeService | None = None

    try:
        owner = NativeService(exe, root, logs, "acked-before-kill", args.workers)
        first_pid = owner.pid
        response = owner.request(
            "focus -1 -3\n"
            "dig 5 5\n"             # explicit Empty tombstone, including if empty
            "wall 18 31\nwall 17 30\nwall 19 30\n"
            "watertemp 18 30 17 417\n"
            "inspect 5 5\ninspect 18 30\nstatus"
        )
        require("REFUSED " not in response, "native edit unexpectedly refused")
        acks = [line for line in response.splitlines()
                if line.startswith("GEN006_EDIT_DURABLE_ACK ")]
        require(len(acks) == 5,
                "all five edits must have individually published receipts")
        generations: list[int] = []
        for line in acks:
            require("chunk=(-1,-3)" in line and "file_published=1" in line,
                    "ACK lacks correct native chunk or completed disk publication")
            match = re.search(r"\bgeneration=(\d+)\b", line)
            require(match is not None, "native mutation-generation ACK missing")
            generations.append(int(match.group(1)))
        require(generations == list(range(generations[0], generations[0] + 5)),
                "mutation generations not monotonic on successive accepted edits")
        require("intent=1" in cell(response, (5, 5)),
                "Empty intent not acknowledged in native memory")
        water_before = cell(response, (18, 30))
        require("liquid=17 temp=417 intent=1" in water_before,
                "native Water17/temp417 not present at the edit ACK")
        live_line = resident_line(response)
        require("gen={}".format(generations[-1]) in live_line,
                "latest generation not committed to live resident")
        record = root / "chunk_x-1_y-3.g6s"
        persisted_sha = digest(record)

        # The critical negative control: NO quit, NO save_all, NO LRU eviction.
        # This is a real operating-system process kill after a complete
        # file-published ACK, not a modelled or synthetic crash.
        owner.close()
        owner = None
        require(not (logs / "acked-before-kill-ipc" / "stopped.txt").exists(),
                "abrupt-kill case accidentally performed graceful save_all")
        require(digest(record) == persisted_sha,
                "record changed without a live native owner")

        owner = NativeService(exe, root, logs, "restore-after-kill", args.workers)
        require(owner.pid != first_pid,
                "restart reused old native process identity unexpectedly")
        restored = owner.request("focus -1 -3\ninspect 5 5\n"
                                 "inspect 18 30\nstatus")
        require("REFUSED " not in restored and "RELOAD x=-1 y=-3" in restored,
                "actual native checkpoint was not reloaded")
        require("intent=1" in cell(restored, (5, 5)),
                "abrupt native death lost acknowledged Empty tombstone")
        water_after = cell(restored, (18, 30))
        require("liquid=17 temp=417 intent=1" in water_after,
                "abrupt native death lost acknowledged Water17/temperature")
        require("gen={}".format(generations[-1]) in resident_line(restored),
                "saved mutation generation did not survive process restart")
        require(digest(record) == persisted_sha,
                "record unexpectedly rewritten before graceful shutdown")
        owner.stop()
        owner = None

        print("GEN006_EDIT_CRASH_RESTART_PASS"
              " configured_workers={}".format(args.workers)
              + " actual_native_processes=2"
              + " acknowledged_edits=5"
              + " final_generation={}".format(generations[-1])
              + " Water17=17 temperature=417 Empty_intent=1"
              + " disk_record_sha256=" + persisted_sha
              + " kill_without_quit=1"
              + " restored_native_world=1")
        return 0
    finally:
        if owner is not None:
            owner.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as exc:
        print("GEN006_EDIT_CRASH_RESTART_FAIL " + str(exc), file=sys.stderr)
        raise SystemExit(1)
