#!/usr/bin/env python3
"""Validate original proxy traces, including incomplete calls at a process timeout.

This validates instrumentation custody only. It never turns a diagnostic timeout
into a workload pass, asserts graphical readiness, or reconstructs missing logs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def digest(path: Path) -> dict:
    data = path.read_bytes()
    return {"file": path.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def inspect(directory: Path, manifest: dict, preflight: bool = False) -> dict:
    traces = sorted(directory.glob("d3d-trace-*.jsonl"))
    require(bool(traces), "no original trace: proxy interception is unproven")
    results = []
    for path in traces:
        raw = path.read_bytes()
        require(raw.endswith(b"\n"), f"partial final trace line in {path.name}; retain original and investigate")
        events = [json.loads(line) for line in raw.splitlines()]
        require(not any(event["event"] == "compile_capture_limit" for event in events), "compiler capture limit reached")
        require(events and events[0]["event"] == "identity", f"missing first identity in {path.name}")
        identity = events[0]
        pid = identity["pid"]
        require(path.name == f"d3d-trace-{pid}.jsonl", "PID/file mismatch")
        require(all(event["pid"] == pid for event in events), "foreign PID in trace")
        indices = [event["event_index"] for event in events]
        require(len(set(indices)) == len(indices) and set(indices) == set(range(1, len(indices) + 1)), "missing/duplicate event indices")
        require(identity["system_sha256"] == identity["expected_system_sha256"] == manifest["system_original"]["sha256"], "System32 original SHA mismatch")
        require(identity["proxy_sha256"] == manifest["proxy"]["sha256"], "loaded proxy SHA mismatch")
        normalize = lambda value: value.replace("/", "\\").casefold()
        require(normalize(identity["system_module"]) == normalize(manifest["system_original"]["path"]), "actual System32 path mismatch")
        require(normalize(identity["system_module"]) != normalize(identity["proxy_module"]), "proxy/original paths not distinct")
        require(identity["exports_forwarded"] == len(manifest["system_original"]["exports"]), "forwarded export count mismatch")
        base = identity["system_module_base"]
        for name in ("d3dcompile_address", "d3dcompile2_address"):
            require(base <= identity[name] < base + manifest["system_original"]["image_size"], f"{name} is outside authentic System32 image")
        begins, ends = {}, {}
        for event in events:
            kind = event["event"]
            if kind == "compile_begin":
                require(event["call"] not in begins, "duplicate compiler begin")
                begins[event["call"]] = event
            elif kind == "compile_end":
                require(event["call"] not in ends, "duplicate compiler end")
                ends[event["call"]] = event
        require(bool(begins), "no intercepted compile calls: no shader attribution")
        require(set(ends).issubset(begins), "compiler end without retained begin")
        unwrapped = sorted({event["name"] for event in events if event["event"] == "forward_export_first_use"
                            and (event["name"].startswith("D3DCompile") or event["name"] == "D3DAssemble")})
        require(not unwrapped, "unwrapped compiler API observed; source attribution incomplete")
        calls = []
        for call, begin in sorted(begins.items()):
            if not preflight:
                require(begin["include_pointer_present"] is False, "include callback bytes not retained; standalone HLSL attribution incomplete")
            require(not begin["defines_truncated"], "truncated compiler macro list")
            for name in ("source_name", "entry", "target"):
                require(begin[name] is None or not begin[name]["truncated"], "truncated compiler input metadata")
            for macro in begin["defines"]:
                require(not macro["name"]["truncated"] and (macro["definition"] is None or not macro["definition"]["truncated"]), "truncated macro")
            files = []
            end = ends.get(call)
            for event in (begin, end or {}):
                for field in ("source", "secondary", "bytecode", "messages"):
                    if field not in event:
                        continue
                    record = event[field]
                    require(record["complete"] is True, f"incomplete {field} for call {call}")
                    name = record["file"]
                    require(Path(name).name == name and name.startswith(f"d3d-{pid}-{call}-"), "source filename path/PID/call mismatch")
                    receipt = digest(directory / name)
                    require(receipt["bytes"] == record["bytes"] == record["written"], f"{field} byte count mismatch")
                    receipt["kind"] = field
                    files.append(receipt)
            source = (directory / begin["source"]["file"]).read_bytes()
            if end:
                require(end["tid"] == begin["tid"], "compiler end thread mismatch")
                require(end["call_end_qpc"] >= end["call_start_qpc"] >= begin["begin_qpc"], "non-monotonic call timing")
                require(end["logging_errors"] == end["dropped_events"] == end["skipped_captures"] == 0, "trace reports instrumentation loss")
            calls.append({"call": call, "tid": begin["tid"], "api": begin["api"], "target": begin["target"],
                          "entry": begin["entry"], "flags1": begin["flags1"], "flags2": begin["flags2"],
                          "defines": begin["defines"], "include_pointer_present": begin["include_pointer_present"],
                          "has_palette_material_colour_identifier": b"material_colour" in source,
                          "has_palette_flair_identifier": b"apply_material_flair" in source,
                          "completed": end is not None, "wall_s": end.get("wall_s") if end else None,
                          "thread_cpu_s": end.get("thread_cpu_s") if end else None,
                          "hresult": end.get("hresult") if end else None, "files": files})
        if preflight:
            require(len(begins) == len(ends) == 3, "preflight must retain all three complete compiler calls")
            require({begin["api"] for begin in begins.values()} == {"D3DCompile", "D3DCompile2"}, "preflight missing API coverage")
            require(any(event["event"] == "forward_export_first_use" and event["name"] == "D3DDisassemble" for event in events), "generic export thunk not exercised")
        results.append({"trace": digest(path), "pid": pid, "identity": identity, "event_count": len(events),
                        "calls": calls, "open_call_ids": sorted(set(begins) - set(ends)),
                        "limits": "Observed API forwarding only; no assertion that all process compiler activity passed through this proxy. An open call is not a completed compile or graphical success."})
    return {"scope": "NONQUALIFYING original D3D trace custody and observed call readback", "instrumentation_valid": True,
            "preflight": preflight, "processes": results}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--preflight", action="store_true")
    args = parser.parse_args()
    require(not args.output.exists(), "readback output must be new; do not overwrite prior evidence")
    report = inspect(args.directory, json.loads(args.manifest.read_text()), args.preflight)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"instrumentation_valid": True, "processes": len(report["processes"]),
                      "open_calls": sum(len(process["open_call_ids"]) for process in report["processes"])}))


if __name__ == "__main__":
    main()
