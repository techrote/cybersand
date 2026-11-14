#!/usr/bin/env python3
"""GEN-006 #194: cross-OS transfer of actual native whole-World CYPS bytes.

Experimental diagnostic, NOT an admitted serializer, eviction path, or power-cut test.
The native producer/checker is test_gen006_native_restart.cpp; this code only
transports opaque bytes and refuses malformed provenance/transfer records.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

LIMIT = 16 * 1024 * 1024
WORLD_CPP = "aed1bb10e480493397f5c5eac8ba2336f495b9f9"
WORLD_HPP = "bb2f6e33dd1ad8e4a2b2aec7b34ccfb8229b6cb3"
# Test-only whole-World snapshots, never selective eviction.
CASES = ((1, 17, "normal"), (4, 19, "normal"),
         (1, 17, "event"), (4, 19, "event"))


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def git(*args):
    return subprocess.check_output(["git", *args], text=True, timeout=30).strip()


def source_receipt():
    receipt = {
        "commit": git("rev-parse", "HEAD"),
        "tree": git("rev-parse", "HEAD^{tree}"),
        "world_cpp_blob": git("hash-object", "native/src/world.cpp"),
        "world_hpp_blob": git("hash-object", "native/include/cybersand/world.hpp"),
        "native_probe_blob": git("hash-object", "native/tests/test_gen006_native_restart.cpp"),
        "driver_blob": git("hash-object", "tools/experiments/gen006_cross_os_probe.py"),
        "os": os.name, "platform": platform.platform(), "python": sys.version,
    }
    need(receipt["commit"] == os.environ.get("GITHUB_SHA", receipt["commit"]),
         "checkout does not match workflow commit")
    need(receipt["world_cpp_blob"] == WORLD_CPP and
         receipt["world_hpp_blob"] == WORLD_HPP,
         "native World source contract changed: diagnostic needs reevaluation")
    return receipt


def digest(data):
    return hashlib.sha256(data).hexdigest()


def run_native(exe, mode, snapshot, receipt, workers, water):
    result = subprocess.run([str(exe), mode, str(snapshot), str(receipt),
                             str(workers), str(water)],
                            capture_output=True, text=True, timeout=150)
    return {"exit": result.returncode,
            "stdout": result.stdout[-5000:], "stderr": result.stderr[-5000:]}


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def cohort_tag(workers, kind):
    return f"w{workers}" + ("-event" if kind == "event" else "")


def decode_receipt(data, workers, water, kind):
    need(0 < len(data) < 2048, "receipt byte bound refused")
    fields = data.decode("ascii").strip().split()
    if kind == "normal":
        need(len(fields) == 6 and all(x.isdecimal() for x in fields),
             "malformed ordinary native receipt")
        offset = 0
    else:
        need(kind == "event" and len(fields) == 7 and
             fields[0] == "GEN006_EVENT_V1" and
             all(x.isdecimal() for x in fields[1:]),
             "malformed native pending-event receipt")
        offset = 1
    actual = int(fields[5 + offset])
    # Ordinary distributed fixture must participate in >1 jobs when configured 4.
    # The seam event runs on one actually selected core even with four configured.
    minimum = 2 if workers == 4 and kind == "normal" else 1
    need(int(fields[offset]) == workers and
         int(fields[1 + offset]) == water and
         int(fields[4 + offset]) > 0 and
         minimum <= actual <= workers,
         "native cohort identity/actual worker participation refused")
    return actual, int(fields[4 + offset])

def produce(exe, out, witness, compare_root=None):
    out.mkdir(parents=True, exist_ok=True)
    report = {"phase": "produce", "source": source_receipt(),
              "scope": "experimental whole-World CYPS2 cross-OS event continuation",
              "cases": []}
    try:
        for workers, water, kind in CASES:
            tag = cohort_tag(workers, kind)
            raw_path, receipt_path = out / f"{tag}.cyps", out / f"{tag}.txt"
            mode = "emit-event" if kind == "event" else "emit"
            run = run_native(exe, mode, raw_path, receipt_path, workers, water)
            entry = {"workers": workers, "water": water, "kind": kind, "native": run}
            report["cases"].append(entry)
            need(run["exit"] == 0, f"native {kind} emit failed: {run}")
            raw, rec = raw_path.read_bytes(), receipt_path.read_bytes()
            need(0 < len(raw) < LIMIT, "native payload byte bound refused")
            observed, size = decode_receipt(rec, workers, water, kind)
            need(size == len(raw), "native receipt/payload mismatch")
            entry.update({"bytes": len(raw), "sha256": digest(raw),
                          "receipt_sha256": digest(rec),
                          "observed_workers": observed})
        if compare_root is not None:
            validate_manifest(compare_root, report["source"])
            comparisons = []
            for workers, water, kind in CASES:
                tag = cohort_tag(workers, kind)
                ours = (out / f"{tag}.cyps").read_bytes()
                theirs = (compare_root / f"{tag}.cyps").read_bytes()
                comparisons.append({"tag": tag, "byte_identical": ours == theirs,
                                    "local_sha256": digest(ours),
                                    "peer_sha256": digest(theirs)})
            report["cross_os_producer_bytes"] = comparisons
            need(all(x["byte_identical"] for x in comparisons),
                 "cross-OS native producer bytes diverged")
        report["result"] = "PASS"
    finally:
        write_json(witness, report)
        write_json(out / "manifest.json", report)
    print("GEN006_NATIVE_CROSS_OS_PRODUCE_PASS", report["source"]["os"])

def validate_manifest(root, source):
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    need(manifest["phase"] == "produce" and manifest["result"] == "PASS",
         "incomplete producer evidence")
    origin = manifest["source"]
    need(origin["os"] != source["os"] and
         {origin["os"], source["os"]} == {"nt", "posix"},
         "not a genuine Windows/Linux transfer")
    for key in ("commit", "tree", "world_cpp_blob", "world_hpp_blob",
                "native_probe_blob", "driver_blob"):
        need(origin[key] == source[key], f"cross-OS source mismatch: {key}")
    need(len(manifest["cases"]) == len(CASES), "cohort count mismatch")
    for i, (workers, water, kind) in enumerate(CASES):
        entry = manifest["cases"][i]
        need(entry["workers"] == workers and entry["water"] == water and
             entry["kind"] == kind, "cohort order/identity mismatch")
        tag = cohort_tag(workers, kind)
        raw = (root / f"{tag}.cyps").read_bytes()
        rec = (root / f"{tag}.txt").read_bytes()
        need(0 < len(raw) < LIMIT and len(raw) == entry["bytes"] and
             digest(raw) == entry["sha256"] and
             digest(rec) == entry["receipt_sha256"],
             "transferred file integrity refused")
        observed, size = decode_receipt(rec, workers, water, kind)
        need(observed == entry["observed_workers"] and size == len(raw),
             "transferred native cohort receipt refused")
    return manifest

def consume(exe, root, out, witness):
    out.mkdir(parents=True, exist_ok=True)
    source = source_receipt()
    report = {"phase": "consume", "source": source, "cases": [],
              "scope": "cross-OS native pending-event/ordinary restore; no eviction"}
    try:
        manifest = validate_manifest(root, source)
        report["producer_source"] = manifest["source"]
        for workers, water, kind in CASES:
            tag = cohort_tag(workers, kind)
            raw_path, rec_path = root / f"{tag}.cyps", root / f"{tag}.txt"
            mode = "check-event" if kind == "event" else "check"
            good = run_native(exe, mode, raw_path, rec_path, workers, water)
            entry = {"workers": workers, "water": water, "kind": kind,
                     "native_cross_os_check": good}
            report["cases"].append(entry)
            raw = raw_path.read_bytes()
            broken_path = out / f"{tag}-corrupt.cyps"
            damaged = bytearray(raw)
            damaged[len(damaged) // 2] ^= 0x80
            broken_path.write_bytes(damaged)
            corrupted = run_native(exe, mode, broken_path, rec_path, workers, water)
            entry["same_length_corruption_check"] = corrupted
            ticks = 6 if kind == "event" else 3
            event_proof = (kind != "event" or
                           ('"pending_events":1' in good["stdout"] and
                            '"executed_once":true' in good["stdout"] and
                            '"interest_reentries":1' in good["stdout"]))
            entry["result"] = ("PASS" if good["exit"] == 0 and
                               f'"continuation_ticks":{ticks}' in good["stdout"] and
                               event_proof and corrupted["exit"] == 13 and
                               "integrity digest mismatch" in corrupted["stderr"]
                               else "FAIL")
        need(all(e["result"] == "PASS" for e in report["cases"]),
             "cross-OS native event/continuation or native decoder refusal failed")
        report["result"] = "PASS"
    finally:
        write_json(witness, report)
    print("GEN006_NATIVE_CROSS_OS_CONSUME_PASS", source["os"])

def main():
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=("produce", "consume"))
    p.add_argument("--native", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--input")
    p.add_argument("--compare-input", help="opposite-OS originals for byte parity")
    args = p.parse_args()
    exe = Path(args.native).resolve()
    out = Path(args.out).resolve()
    need(exe.is_file(), "native executable missing")
    if args.mode == "produce":
        produce(exe, out / "producer", out / "witness.json",
                Path(args.compare_input).resolve() if args.compare_input else None)
    else:
        need(args.input is not None, "cross-OS input root required")
        consume(exe, Path(args.input).resolve(), out, out / "witness.json")


if __name__ == "__main__":
    main()
