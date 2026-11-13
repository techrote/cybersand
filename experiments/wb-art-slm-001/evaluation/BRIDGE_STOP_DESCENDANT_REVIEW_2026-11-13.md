# WB-ART-SLM-001 — independent bridge Stop descendant-lifetime review

Date: 2026-11-13. Role: Independent Evaluation. Branch: `codex/wb-art-slm-evaluation`.
Source reviewed: combined Draft #567, `codex/wb-art-slm-001` at `87cf3b087ee76f1f575266f8110956849b46ad5b`; Integration-owned `integration/local_art_bridge.py` Git blob `481475d5b2377713ee42e5454ddb9a9fd3fad48f`. No bridge production source was changed by Evaluation.

## Finding — cancellation may leave a descendant alive (POSIX)

The bridge launches inference with `start_new_session=True`. On cancellation it sends SIGTERM to that process group, then `wait()`s **only for the immediate Popen process**. If that parent exits on SIGTERM while a descendant ignores SIGTERM, `wait()` succeeds and the kill branch is not executed. Likewise an already-exited parent makes `_stop_owned_process` return immediately without checking descendants.

This is a **process-lifetime invariant gap**, not evidence of a native Art write. A returning HTTP error still carries no geometry; native epochs, Stop and revisions remain separately authoritative. It does mean that the documented claim that canceled inference cannot leave group workers behind is too strong for a child-spawning inference wrapper. Actual step-400 `infer.py` with a loaded model, Windows process trees and a native World have not been exercised in this review.

## Measured bounded diagnostic

Added `audit_bridge_stop_descendants.py`: it dynamically loads the actual integration module in a combined checkout, pins its Git blob optionally, starts a synthetic inference process spawning a SIGTERM-ignoring descendant, triggers the real bridge cancellation callback after a ready marker, checks for a deliberately delayed file-side effect, and unconditionally SIGKILLs its owned POSIX group in a `finally` block. No native API, model, network port, production material or source is altered. The synthetic file marker is not a native cell receipt.

The Evaluation branch deliberately does not contain Integration-owned `local_art_bridge.py`. Therefore **the exact full module was read from GitHub but not executed locally**. On Linux, I executed the probe against a faithful extracted copy of the exact `_run_owned_inference` and `_stop_owned_process` logic from blob `481475d5`. The probe measured `cancel_refusal=true`, `late_descendant_write=true`, and `stop_descendant_invariant_passed=false`. This result is **reproduction of the reviewed implementation logic**, not an exact-source or end-to-end bridge execution claim.

Added `test_audit_bridge_stop_descendants.py`: **3/3 local tests PASS in 4.174 seconds**. Its negative fixture detects the surviving child; its independently repaired control kills the process group after the parent exits and avoids the delayed file write; the third test verifies Git blob source-identity hashing. Controls do not require weights or Godot.

## Reproduction after Integration intake

From the combined repository source, with Python 3.12 on POSIX:

```sh
python -m unittest discover -s experiments/wb-art-slm-001/evaluation -p 'test_audit_bridge_stop_descendants.py' -v
python experiments/wb-art-slm-001/evaluation/audit_bridge_stop_descendants.py \
  --bridge experiments/wb-art-slm-001/integration/local_art_bridge.py \
  --expected-git-blob 481475d5b2377713ee42e5454ddb9a9fd3fad48f \
  --out /tmp/slm-independent-stop-descendant.json
```

If Integration changes the bridge source, use the new recorded blob and preserve the original result. The executable audit returns JSON for both FAIL and PASS; treat `stop_descendant_invariant_passed=false` as **HOLD**, not a passing acceptance gate. Preserve failures. Run the exact-source module and record its output before accepting a fix. This diagnostic is intentionally not tied into other workers' CI or made a blocker for unrelated edits by Evaluation.

## Recommended narrowly owned correction

Integration owns the code. On POSIX, send TERM to the owned process group; after bounded grace, send KILL to that group **even when the direct process has exited**. Reap the parent and fence the request after cancellation. Validate cancellation before, during and after an acknowledged prefix, including an inference subprocess with a descendant ignoring TERM and a late-file sentinel; report whether any delayed Art **suffix** reaches the native executor separately. On Windows use a tested owned process-tree/Job Object strategy rather than assuming `Popen.terminate()` kills children. Do not modify model, compiler, corpus, host permissions, material laws or the native Art safety layer to mask this issue.

## Frozen denominators and decision

Historical Linux model gallery: 36 original requests, 34 first-pass admitted/native request yield (94.4%), 68/68 admitted native seed replays, 32/36 symbolically correct label+primary motif. Two malformed coral completions and distinct ribs/veins semantic failures remain. The previous 31/34 exploratory near-pixel-cluster result and blinded images remain unchanged. No training, native replay, Windows, human recognition, or final-set evaluation here.

**GO:** independent source-reading diagnosis, local source-equivalent reproduction, reusable full-module diagnostic, model-free test controls.

**HOLD:** bridge process descendant Stop invariant pending exact-source combined run and Integration remediation; all WB-ART-SLM production/native/Windows/human acceptance gates. #564 and #565 remain Draft/HOLD; main `63f8b1ba6559906fe85f3ad0269aa296e4141d67` preserves #563. No inference or native runtime was requalified.
