#!/usr/bin/env python3
"""RENDER-ACK-001: offline cause reducer for opt-in main/worker JSONL.

Observations are timestamped with Godot's common monotonic microsecond clock.
This is transport diagnosis, not a GPU/scanout benchmark. No files are modified.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import statistics
import tempfile
from typing import Any


def read_trace(path: Path) -> list[dict[str, Any]]:
    events = []
    with path.open(encoding="utf-8") as file:
        for line_number, raw in enumerate(file, 1):
            if not raw.strip():
                continue
            try:
                row = json.loads(raw)
            except (ValueError, TypeError) as exc:
                raise ValueError(f"{path}:{line_number}: malformed JSON: {exc}") from exc
            if (not isinstance(row, dict) or type(row.get("at_usec")) is not int
                    or row["at_usec"] < 0 or not isinstance(row.get("event"), str)
                    or row.get("source") not in ("worker", "main")):
                raise ValueError(f"{path}:{line_number}: malformed trace event")
            events.append(row)
    if not any(row["event"] == "trace_started" for row in events):
        raise ValueError("Trace startup header missing; cannot attribute this session")
    return sorted(events, key=lambda row: (row["at_usec"], row.get("sequence", 0)))


def stats(values: list[int]) -> dict[str, Any]:
    if not values:
        return {"count": 0}
    values = sorted(values)
    return {
        "count": len(values),
        "median_usec": statistics.median(values),
        "p95_usec": values[(95 * len(values) + 99) // 100 - 1],
        "maximum_usec": values[-1],
    }


def analyze(events: list[dict[str, Any]]) -> dict[str, Any]:
    full = Counter()
    native_status = Counter()
    capacity = Counter()
    full_causes = []
    escalation = []
    ack_arrivals: list[dict] = []
    main_receives: dict[int, dict] = {}
    main_acks: dict[int, dict] = {}
    worker_acks: dict[int, dict] = {}
    lags = []
    upload_durations: dict[str, list[int]] = {"full": [], "partial": []}
    uploaded: Counter = Counter()
    last_ack: dict | None = None
    discarded = 0
    for row in events:
        kind = row["event"]
        if kind == "trace_ring_evicted":
            discarded += int(row.get("evicted_since_last_flush", 0))
        elif kind == "ack_arrived" and row.get("advanced"):
            last_ack = row
            ack_arrivals.append(row)
            worker_acks[int(row["serial"])] = row
        elif kind == "ack_latched":
            lags.append(int(row.get("latch_delay_usec", 0)))
        elif kind == "main_render_received":
            main_receives[int(row["render_serial"])] = row
        elif kind == "main_ack_issued":
            main_acks[int(row["render_serial"])] = row
        elif kind == "main_upload_completed":
            if row.get("accepted"):
                group = "full" if row.get("full") else "partial"
                uploaded[group] += 1
                upload_durations[group].append(int(row["upload_duration_usec"]))
        elif kind == "native_snapshot":
            reason = str(row.get("reason", "missing"))
            native_status[str(row.get("native_status", "missing"))] += 1
            if row.get("full"):
                full[reason] += 1
                full_causes.append({
                    "at_usec": row["at_usec"],
                    "reason": reason,
                    "native_status": row.get("native_status"),
                    "requested_full": row.get("requested_full"),
                    "rectangles": row.get("native_rectangles"),
                    "bytes": row.get("native_bytes"),
                    "pending_bytes_before": row.get("pending_bytes_before"),
                })
        elif kind == "pending_capacity_escalation":
            reason = str(row.get("reason", "missing"))
            capacity[reason] += 1
            escalation.append({
                "at_usec": row["at_usec"],
                "strict_trigger": reason,
                "pending_rectangles": row.get("pending_rectangles"),
                "rectangle_limit": row.get("rectangle_limit"),
                "pending_bytes": row.get("pending_bytes"),
                "byte_limit": row.get("byte_limit"),
                "pending_age_usec": row.get("pending_age_usec"),
                "pending_serial": row.get("pending_serial"),
                "acknowledged_serial": row.get("acknowledged_serial"),
                "last_ack_serial": last_ack.get("serial") if last_ack else None,
                "last_ack_age_usec": row["at_usec"] - last_ack["at_usec"]
                    if last_ack else None,
            })
    ack_handoff = []
    for serial, issued in main_acks.items():
        arrived = worker_acks.get(serial)
        received = main_receives.get(serial)
        if arrived and received:
            ack_handoff.append(max(0, arrived["at_usec"] - issued["at_usec"]))
    return {
        "schema": "render-ack-feedback-analysis-v1",
        "scope": "Instrumented ACK/worker/native exchange; no physical-GPU transfer or scanout attribution",
        "complete_custody": discarded == 0,
        "trace_evicted_events": discarded,
        "trace_started": next(row for row in events if row["event"] == "trace_started"),
        "event_count": len(events),
        "native_status_counts": dict(native_status),
        "native_full_reason_counts": dict(full),
        "native_full_events": full_causes,
        "worker_pending_escalation_counts": dict(capacity),
        "worker_pending_escalations": escalation,
        "main_accepted_upload_counts": dict(uploaded),
        "main_upload_duration_usec": {kind: stats(values) for kind, values in upload_durations.items()},
        "worker_ack_latch_delay_usec": stats(lags),
        "main_ack_call_to_worker_receipt_usec": stats(ack_handoff),
        "worker_ack_arrival_count": len(ack_arrivals),
        "main_ack_count": len(main_acks),
        "limitations": [
            "A pending-capacity event proves its strict threshold and unacknowledged backlog, not which component caused a delay.",
            "Native status 3 means native exchange CapacityExceeded; status 2 is Backpressure; neither is a worker ACK-limit event.",
            "Pending bytes can include earlier full-plane packets; a high byte count alone does not mean a sparse delta.",
            "Events are opt-in and impose overhead; compare architecture/timing in separate instrumentation-free runs.",
            "The worker trace ring is finite; trace_ring_evicted makes this report nonexhaustive.",
        ],
    }


def self_test() -> None:
    sample = [
        {"at_usec": 1, "source": "main", "event": "trace_started", "schema": "render-ack-feedback-v1"},
        {"at_usec": 10, "source": "main", "event": "main_render_received", "render_serial": 4},
        {"at_usec": 20, "source": "main", "event": "main_upload_completed", "render_serial": 4,
         "accepted": True, "full": False, "upload_duration_usec": 10},
        {"at_usec": 21, "source": "main", "event": "main_ack_issued", "render_serial": 4},
        {"at_usec": 22, "source": "worker", "event": "ack_arrived", "serial": 4, "advanced": True},
        {"at_usec": 24, "source": "worker", "event": "ack_latched", "serial": 4, "latch_delay_usec": 2},
        {"at_usec": 30, "source": "worker", "event": "pending_capacity_escalation",
         "reason": "pending_rectangles", "pending_rectangles": 257, "rectangle_limit": 256,
         "pending_bytes": 1024, "byte_limit": 2048, "pending_age_usec": 10000,
         "pending_serial": 261, "acknowledged_serial": 4},
        {"at_usec": 35, "source": "worker", "event": "native_snapshot",
         "reason": "pending_capacity_escalation", "native_status": 0,
         "full": True, "requested_full": True, "native_bytes": 2048},
        {"at_usec": 40, "source": "worker", "event": "native_snapshot",
         "reason": "native_capacity_exceeded", "native_status": 3,
         "full": True, "requested_full": False, "native_bytes": 2048},
        {"at_usec": 50, "source": "main", "event": "main_upload_completed", "render_serial": 261,
         "accepted": True, "full": True, "upload_duration_usec": 500},
    ]
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "sample.jsonl"
        path.write_text("\n".join(json.dumps(row) for row in sample) + "\n", encoding="utf-8")
        report = analyze(read_trace(path))
        assert report["complete_custody"]
        assert report["worker_pending_escalation_counts"] == {"pending_rectangles": 1}
        assert report["native_full_reason_counts"] == {
            "pending_capacity_escalation": 1, "native_capacity_exceeded": 1}
        assert report["worker_pending_escalations"][0]["last_ack_serial"] == 4
        assert report["main_upload_duration_usec"]["partial"]["median_usec"] == 10
        assert report["main_upload_duration_usec"]["full"]["median_usec"] == 500
        assert report["main_ack_call_to_worker_receipt_usec"]["median_usec"] == 1
        path.write_text(path.read_text(encoding="utf-8") + "{broken\n", encoding="utf-8")
        try:
            read_trace(path)
        except ValueError:
            pass
        else:
            raise AssertionError("malformed evidence silently accepted")
    print("RENDER-ACK-001 analyzer self-test PASS")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", nargs="?", type=Path, help="user://render-ack-*.jsonl materialized path")
    parser.add_argument("--output", type=Path, help="new JSON reduction path; refuses overwrite")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.trace is None:
        parser.error("TRACE required unless --self-test")
    report = analyze(read_trace(args.trace))
    payload = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        if args.output.exists():
            parser.error("Refusing to overwrite existing analysis")
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")


if __name__ == "__main__":
    main()
