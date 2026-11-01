#!/usr/bin/env python3
"""Adversarial readback of a retained real graphical process, never a timing mock."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

from run_graphical_campaign import cohort_summaries, read_json, reduce_trace


def verify(path: Path) -> dict:
    original = read_json(path)
    summary = reduce_trace(original)
    controls = []

    def rejects(name, mutation):
        altered = copy.deepcopy(original)
        mutation(altered)
        try:
            reduce_trace(altered)
        except (ValueError, KeyError, TypeError, StopIteration):
            controls.append(name)
            return
        raise RuntimeError("reader accepted corrupt evidence: " + name)

    def first(document, kind):
        return next(event for event in document["events"] if event["event"] == kind)

    rejects("headless", lambda d: d.update(display="headless"))
    rejects("unknown-arm", lambda d: d.update(arm="unknown"))
    rejects("unknown-candidate", lambda d: d.update(candidate="E"))
    rejects("runtime-hash-missing", lambda d: d.update(runtime_sha256=""))
    rejects("sequence-gap", lambda d: d["events"][0].update(event_sequence=2))
    rejects("nonfinite-clock", lambda d: d["events"][0].update(usec=float("nan")))
    rejects("truncated", lambda d: d.update(dropped=1))
    rejects("engine-failed", lambda d: d.update(failures=1))
    rejects("counter-erased", lambda d: d["counts"].update(refresh=0))
    rejects("counter-kind-missing", lambda d: d["counts"].pop("refresh"))
    rejects("reset-full-missing", lambda d: first(d, "native_end").update(complete_full=False))
    rejects("generation-missing", lambda d: [e.update(generation=1) for e in d["events"] if e["event"] == "native_end"])
    rejects("operation-identity", lambda d: first(d, "patch_end").update(serial=-1))
    rejects("negative-consumer-duration", lambda d: first(d, "patch_end").update(usec=0))
    rejects("negative-native-duration", lambda d: first(d, "native_end").update(duration_usec=-1))
    rejects("native-call-three", lambda d: first(d, "native_end").update(call=3))
    rejects("native-call-unpaired", lambda d: first(d, "native_begin").update(refresh=-1))
    rejects("publication-missing", lambda d: first(d, "owner_end").update(refresh=-1))
    rejects("CPU-native-parity", lambda d: d.update(final_cpu_native_equal=False))
    rejects("texture-CPU-parity", lambda d: d.update(final_texture_image_equal=False))
    rejects("wrong-owner", lambda d: d.update(owner_script="res://wrong.gd"))
    rejects("tail-not-drained", lambda d: d.update(tail_drained=False))
    rejects("tail-in-flight-only", lambda d: first(d, "tail_caught_up").update(owner_count=0))
    rejects("tail-revision-lag", lambda d: first(d, "tail_caught_up").update(simulation_revision=-1))
    rejects("frame-population", lambda d: d["frame_usec"].pop())
    rejects("frame-duration", lambda d: first(d, "frame_end").update(duration_usec=-1))
    rejects("under-applied-workload", lambda d: d.update(post_reset_cells_correct=59))
    rejects("refused-workload", lambda d: d.update(accepted_pulses=119))
    ack_kind = "ack_issue" if original["arm"] == "N" else "ack_withheld"
    rejects("ack-before-upload", lambda d: first(d, ack_kind).update(usec=0))
    if any(e["event"] == "forced_retry" for e in original["events"]):
        rejects("overflow-cause-missing", lambda d: [e.update(byte_overflow=False) for e in d["events"] if e["event"] == "dirty_onto_full"])
    if any(e["event"] == "ack_clear" for e in original["events"]):
        rejects("ack-clear-without-cover", lambda d: first(d, "ack_clear").update(ack_serial=-1))
    # A valid receipt followed by an engine cleanup crash remains failed evidence.
    row = {"candidate": original["candidate"], "arm": original["arm"],
           "exit": 1, "summary": summary}
    key = original["candidate"] + "-" + original["arm"]
    if cohort_summaries([row])[key]["successful_processes"] != 0:
        raise RuntimeError("failed process entered successful cohort aggregation")
    controls.append("cleanup-crash-excluded-from-success-cohort")
    return {"status": "passed", "positive": "retained actual graphical trace", "path": str(path),
            "candidate": original["candidate"], "arm": original["arm"], "negative_controls": controls}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipts", nargs="+", type=Path)
    args = parser.parse_args()
    print(json.dumps([verify(path) for path in args.receipts], indent=2))


if __name__ == "__main__":
    main()
