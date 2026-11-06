#!/usr/bin/env python3
"""GEN-006 #194 experimental bundle publication using real native CYPS bytes.
Single local rename only; NOT a production format or power-cut proof.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile

MAGIC = b"GEN006-NATIVE-EXPERIMENT-V1\n"
LIMIT = 16 * 1024 * 1024

def need(ok, msg):
    if not ok:
        raise AssertionError(msg)

def call(exe, mode, path, receipt, workers, water, expected=0):
    p = subprocess.run([str(exe), mode, str(path), str(receipt),
                        str(workers), str(water)],
                       capture_output=True, text=True, timeout=120)
    need(p.returncode == expected,
         f"{mode} exit={p.returncode}, expected={expected}: {p.stdout} {p.stderr}")
    return (p.stdout + p.stderr).strip()

def pack(raw, receipt):
    need(0 < len(raw) < LIMIT, "native CYPS length unbounded")
    need(0 < len(receipt) < 2048, "receipt length unbounded")
    metadata = json.dumps({"sha256": hashlib.sha256(raw).hexdigest(),
                           "receipt": receipt.decode("ascii").strip()},
                          sort_keys=True, separators=(",", ":")).encode()
    return MAGIC + struct.pack("<II", len(metadata), len(raw)) + metadata + raw

def unpack(bundle):
    need(bundle.startswith(MAGIC), "bundle magic missing")
    pos = len(MAGIC)
    need(len(bundle) >= pos + 8, "bundle header truncated")
    ml, nl = struct.unpack("<II", bundle[pos:pos+8])
    need(0 < ml < 2048 and 0 < nl < LIMIT, "bundle bounds refused")
    need(len(bundle) == pos + 8 + ml + nl, "bundle length mismatch")
    metadata = json.loads(bundle[pos+8:pos+8+ml])
    raw = bundle[pos+8+ml:]
    need(hashlib.sha256(raw).hexdigest() == metadata["sha256"], "bundle digest mismatch")
    return raw, (metadata["receipt"] + "\n").encode("ascii")

def review(exe, root, d, workers, water):
    raw, receipt = unpack(root.read_bytes())
    rpath = d / "review.txt"
    bpath = d / "review.cyps"
    rpath.write_bytes(receipt)
    bpath.write_bytes(raw)
    return call(exe, "check", bpath, rpath, workers, water)

def cohort(exe, root, d, workers):
    path = d / "candidate.cyps"
    receipt = d / "candidate.txt"
    initial_log = call(exe, "emit", path, receipt, workers, 17)
    staged = d / "staged-bundle"
    staged.write_bytes(pack(path.read_bytes(), receipt.read_bytes()))
    os.replace(staged, root)
    initial_restart = review(exe, root, d, workers, 17)
    initial_digest = hashlib.sha256(root.read_bytes()).hexdigest()
    # Real child-process _Exit(17) after staged bytes and receipt close,
    # but strictly before the root publication operation.
    crashed = call(exe, "emit-crash", path, receipt, workers, 19, expected=17)
    need(hashlib.sha256(root.read_bytes()).hexdigest() == initial_digest,
         "crashed native producer changed existing root")
    surviving_restart = review(exe, root, d, workers, 17)
    bundle = root.read_bytes()
    for broken in (bundle[:-1], bundle[:-1] + bytes([bundle[-1] ^ 1])):
        try:
            unpack(broken)
        except (AssertionError, ValueError, KeyError, UnicodeError):
            pass
        else:
            raise AssertionError("corrupt envelope accepted")
    raw, original_receipt = unpack(bundle)
    bad_path = d / "truncated.cyps"
    bad_path.write_bytes(raw[:-1])
    bad_receipt = d / "corrupt-receipt.txt"
    bad_receipt.write_bytes(original_receipt)
    native_refusal = call(exe, "check", bad_path, bad_receipt,
                          workers, 17, expected=13)
    # Same-length corruption gets past the receipt-length guard into the actual
    # World::restore_physical_state() decoder. Never count predecoder rejection
    # as proof that the native CYPS checksum refused malformed state.
    byte_index = len(raw) // 2
    bitflip = bytearray(raw)
    bitflip[byte_index] ^= 0x80
    bad_path.write_bytes(bitflip)
    native_decoder_refusal = call(exe, "check", bad_path, bad_receipt,
                                  workers, 17, expected=13)
    need("native length/receipt mismatch" not in native_decoder_refusal,
         "corrupted CYPS was refused only by the length guard")
    updated_log = call(exe, "emit", path, receipt, workers, 19)
    staged.write_bytes(pack(path.read_bytes(), receipt.read_bytes()))
    os.replace(staged, root)
    updated_restart = review(exe, root, d, workers, 19)
    need(hashlib.sha256(root.read_bytes()).hexdigest() != initial_digest,
         "revision 2 identical to old checkpoint")
    return {"configured_workers": workers, "initial_native": initial_log,
            "initial_restart": initial_restart, "native_crash": crashed,
            "old_root_after_crash": surviving_restart,
            "truncated_native_refusal": native_refusal,
            "same_length_native_decoder_refusal": native_decoder_refusal,
            "new_native": updated_log, "updated_restart": updated_restart,
            "old_root_sha256": initial_digest,
            "new_root_sha256": hashlib.sha256(root.read_bytes()).hexdigest(),
            "result": "PASS"}


def review_event(exe, root, d, workers, water):
    raw, receipt = unpack(root.read_bytes())
    rpath = d / "review-event.txt"
    bpath = d / "review-event.cyps"
    rpath.write_bytes(receipt)
    bpath.write_bytes(raw)
    output = call(exe, "check-event", bpath, rpath, workers, water)
    need('"executed_once":true' in output and '"continuation_ticks":6' in output
         and '"result":"PASS"' in output,
         "native event completion receipt missing or invalid")
    return output

def event_cohort(exe, root, d, workers):
    path = d / "event-candidate.cyps"
    receipt = d / "event-candidate.txt"
    old_emit = call(exe, "emit-event", path, receipt, workers, 17)
    need('"pending_events":1' in old_emit, "native producer omitted pending event")
    staged = d / "event-staged-bundle"
    staged.write_bytes(pack(path.read_bytes(), receipt.read_bytes()))
    os.replace(staged, root)
    old_restart = review_event(exe, root, d, workers, 17)
    old_digest = hashlib.sha256(root.read_bytes()).hexdigest()

    # An independent native child writes Water19 + the same pending signed-seam
    # event, exits 17, and never publishes. Old root must still execute once.
    crash = call(exe, "emit-event-crash", path, receipt, workers, 19, expected=17)
    need(hashlib.sha256(root.read_bytes()).hexdigest() == old_digest,
         "prepublication native event crash changed acknowledged root")
    survived = review_event(exe, root, d, workers, 17)

    # Same-length native CYPS corruption, not an envelope-length refusal.
    old_raw, old_receipt = unpack(root.read_bytes())
    bad = bytearray(old_raw)
    bad[len(bad)//2] ^= 0x40
    bad_path = d / "event-corrupt.cyps"
    bad_path.write_bytes(bad)
    bad_receipt = d / "event-corrupt-receipt.txt"
    bad_receipt.write_bytes(old_receipt)
    refused = call(exe, "check-event", bad_path, bad_receipt, workers, 17,
                   expected=13)
    need("GEN006_NATIVE_RESTART_REFUSED" in refused and
         "event native length/receipt mismatch" not in refused,
         "corrupt native event record was not refused by native decoder")

    updated_emit = call(exe, "emit-event", path, receipt, workers, 19)
    staged.write_bytes(pack(path.read_bytes(), receipt.read_bytes()))
    os.replace(staged, root)
    new_restart = review_event(exe, root, d, workers, 19)
    new_digest = hashlib.sha256(root.read_bytes()).hexdigest()
    need(new_digest != old_digest, "event revision root did not change")
    return {"configured_workers": workers, "old_emit": old_emit,
            "old_restart": old_restart, "crashed_writer": crash,
            "old_root_after_crash": survived,
            "corrupted_native_refusal": refused,
            "new_emit": updated_emit, "new_restart": new_restart,
            "old_root_sha256": old_digest, "new_root_sha256": new_digest,
            "pending_executed_once": True, "continuation_ticks": 6,
            "signed_chunk_seam": True, "result": "PASS"}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--native", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    exe = Path(args.native).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    cohorts = []
    for workers in (1, 4):
        with tempfile.TemporaryDirectory(prefix="gen006-native-restart-") as temp:
            d = Path(temp)
            cohorts.append(cohort(exe, d / "root.bundle", d, workers))
    event_cohorts = []
    for workers in (1, 4):
        with tempfile.TemporaryDirectory(prefix="gen006-native-events-") as temp:
            d = Path(temp)
            event_cohorts.append(event_cohort(exe, d / "root.bundle", d, workers))
    doc = {"status": "EXPERIMENTAL", "host": os.name, "cohorts": cohorts,
           "event_cohorts": event_cohorts, "limit_bytes": LIMIT,
           "power_cut_durability_tested": False,
           "selective_eviction_tested": False}
    (out / "native-restart-witness.json").write_text(json.dumps(doc, indent=2) + "\n")
    print("GEN006_NATIVE_PROCESS_RESTART_PASS cohorts=2")
    print(json.dumps(doc, sort_keys=True))

if __name__ == "__main__":
    main()
