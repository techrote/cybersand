# PUBPRES #757 — independent physics-publication isolation (23 November 2026)

**Decision: REPAIR/HOLD. Neither Target publication nor combined physics-mailbox publication has established a repeatable end-to-end physical improvement. No production change selected.**

## Original graphical Windows evidence

- [Full/Target/Target/Full Wave512 run 45100037351](https://github.com/techrote/cybersand/actions/runs/45100037351) **completed SUCCESS** with 144 authentic Rapier steps per arm and an original-trace, source/physics/body/current-GPU independent reduction. Target publication drops CPU backend-submit p95 from about **227 ms to 0.7 ms**, but makes real completion tails and rate materially **worse**: Full rates **12.647, 12.699** real steps/s, Target **10.165, 10.890**; Full worst gap **239.427, 244.781 ms**, Target **706.968, 670.785 ms**. Target has **11 gaps >500 ms** across its two arms versus zero for Full. This is a negative physics result. Earlier Wave2048 Full/Target/Target/Full remains negative too.
- To determine whether the physics delivery policy, not upload strategy, had independent gain, [early/combined/combined/early Wave512 run 45104078108](https://github.com/techrote/cybersand/actions/runs/45104078108) executed **four real hosted Windows 2022 / Godot 4.7 Safe-ANGLE graphical arms** using *unchanged* frozen C application/native/Rapier source `c90dbc46e1f57f28e06b1f4205b83467335ff657`, Full material, coherent presentation, continuation OFF, exact same workload/host, and independently verified effective early/combined/combined/early selectors.
- **Explicitly failed campaign registration:** the original reducer expects `physics=early` for each frozen-C arm, while my detached experiment wrapper initially supplied `combined` without updating the per-arm *expected* `physics` field. Original reducer rejected arms 1 and 2 with `Requested selector differs: CYBERSAND_DIAG_PHYSICS_PUBLICATION`; the workflow is correctly **FAILURE, not a passing campaign**. All four original raw `receipt.json` independently say `complete:true`, no application failures. The original raw [artifact 14786678570](https://github.com/techrote/cybersand/actions/runs/45104078108/artifacts/14786678570) is preserved, ZIP CRC checked, SHA-256 `ba75d63427caed1e004038aac1d33c1a87eaadfc828516b27dc9f87a422cd21e`.
- A separate independent **raw-only diagnostic** (not a substituted registration result) rechecked all four source/fixture/CPU/display/renderer identities; requested and live physics selectors; raw trace hashes; 144 consecutively numbered *real* Rapier steps from 144 distinct original physics callbacks per arm; identical rigid-body trajectories and admitted-input histories at equal steps; current GPU history parity. Previous history is **not** verified in these four arms.

| Actual first 144 | Early 0 | Combined 1 | Combined 2 | Early 3 |
|---|---:|---:|---:|---:|
| Real Rapier steps/s | 11.437 | 11.412 | 11.070 | 11.474 |
| Real physical gap p95 (ms) | 275.591 | 275.923 | 271.603 | 273.573 |
| Real physical gap p99 (ms) | 279.388 | 280.777 | 277.168 | 278.650 |
| Real maximum gap (ms) | 280.940 | 281.539 | 280.204 | 279.284 |
| Gaps >250 ms | 37 | 33 | 33 | 38 |
| Gaps >500 ms | 0 | 0 | 0 | 0 |
| Full backend submit p95 (ms) | 266.208 | 267.691 | 262.461 | 266.420 |

**No combined advantage established:** both combined rates are lower than both early controls; p95/p99 split, and the combined maximum gap is slightly higher. This is a *raw diagnostic negative*, **not** a registered performance PASS or source promotion.

## Engineering change scope

I corrected the **single isolated harness issue** by binding `physics=setting` to each per-arm expected selector, on detached evidence branch at [commit 7b902bb](https://github.com/techrote/cybersand/commit/7b902bbad41a619cea075a43f164efe816d7bec7). The original frozen application, native binary, physics coordinator, production selectors and canonical PR #757 **remain unchanged**. Given the complete raw evidence is already negative, **no wasteful repeat hosted Windows run** was made solely to turn a rejected diagnostic into a green workflow.

**Disposition:** keep Full material and early physics as configured; #757 remains Draft/HOLD and retains negative counterexamples. Future work needs a particular source-located renderer/physics-wakeup hypothesis, not broad further CI churn. Physical Windows 11/NVIDIA owner acceptance, actual GPU completion/scanout and source-exact production native LFS custody remain unproven. No merge or Ready promotion.

## 23 November verification addendum — corrected Windows campaign and full mode-aware receipt replay

The owner explicitly requested that the physics-publication result be **verified rather than left as a failed harness experiment**. We executed an additional [real hosted Windows Safe/ANGLE graphical campaign, run 45105890195](https://github.com/techrote/cybersand/actions/runs/45105890195) from evidence-only workflow SHA `53ad974603f4ae89e9a1c1bd19e9e2fcefbed83e`, while **testing the unchanged frozen C application/source-built Windows native runtime** `c90dbc46e1f57f28e06b1f4205b83467335ff657`.

- All four original 512² Follow / four-worker, Wave reference, Full-material Windows application processes completed normally. The new initial wrapper preflight passed for **early/combined/combined/early**, with expected, requested and active runtime selectors matching. Native/engine/Rapier custody checks passed.
- The **unmodified original V3 reducer again rejected the two Combined arms**, this time at `Native/physics clock missing, negative or later than its consumed step`. This is a treatment-specific measurement-contract issue: `combined` does not publish a distinct early physics mailbox, and every Combined step correctly retains `physics_handoff_source_usec=physics_handoff_usec=0`. Early steps retain positive actual handoff timestamps. Neither value is a GPU fence.
- The hosted workflow remains **FAILURE**. The [original artifact 14787448688](https://github.com/techrote/cybersand/actions/runs/45105890195/artifacts/14787448688) is fully preserved, ZIP CRC valid, **SHA-256 `a5494806d0e0590b6778fb2d64f6aee495a2acb94949e30c3c7769cdb90af459`**. No failed arm, output or original trace is rewritten to make CI green.

### Controlled independent replay — **VALIDATED**

A separate offline adversarial replay used the **byte-exact frozen c90 V3 reducer** (`tools/pubpres_playability/results_same_frame.py`, SHA-256 `896126129f035e4ed39f776d6514f562ff0e6815d6ba1132d8f2a685982a3be2`; Git blob `6a733192d42951b11f790cb37f9226b4fa3def7e`) with just **one exact, mode-aware predicate** changed in memory:

Allow a zero `physics_handoff_usec` only when its copied source clock is **also exactly zero** and BOTH before/after effective runtime **and** requested physics mode are `combined`. Preserve the existing positive/ordered completed native clock, World/session/body/sample, healthy terrain, genuine Rapier callback credit, actor and input trajectory, Water ledger, current GPU history, framebuffer and trace-hash gates. **No timestamp, accepted sample or other original evidence byte was modified.** The offline replay did not duplicate the optional on-disk project/engine-hash checks, which were qualified by the original hosted source-custody lane.

All **four full original V3 per-arm reductions now passed** this sole legitimate mode-specific exception. The first 144 authentic body trajectories all share SHA-256 `07410910f5d2dc49194bf1bba37d7a34c7846c687d4cfd6c2d848f6ac04a4ffc`; accepted moves all share `986183b4f06a36a76279b3f6c4d9f196c4fa34d5c4dfaa887e34f52303851726`.

| Actual first-144 Rapier outcome | Early 0 | Combined 1 | Combined 2 | Early 3 |
| --- | ---: | ---: | ---: | ---: |
| Actual completed steps/s | 11.433 | 11.149 | 10.694 | 10.875 |
| Physical gap p95, ms | 274.724 | 277.625 | 277.178 | 279.223 |
| Physical gap p99, ms | 291.313 | 282.672 | 284.135 | 282.925 |
| Maximum real inter-step gap, ms | 424.824 | **537.394** | 285.732 | 288.365 |

**Independent direction: NOT_ESTABLISHED.** Both combined rates fail the declared all-C-better rule, the p95/p99 directions are mixed and one Combined maximum exceeds the worse Early maximum.

### Adversarial test of the exceptional rule

To ensure that accepting an *absent* combined-mode mailbox is not a backdoor for fabricated progress, we ran ten separate synthetic modifications of **copies** of the original Windows receipts/event streams (rehashing the synthetic trace and matching copied receipt to test semantics beyond a mere hash failure). All **10/10 were rejected**: zero Early handoff; negative or future Combined handoff; missing native completion; double callback credit; wrong hard terrain revision; GPU-current corruption; runtime selector relabel; wrong World generation; and dropped authentic Rapier completion. No original GitHub artifact was touched. The reproducible, tested verifier scripts, pinned V2/V3 reducers, results and fault-test report are available in the owner's conversation artifact `PUBPRES757-Wave512-Physics-Verified-Negative-20261123.zip`.

One auxiliary `WRAPPER-PREFLIGHT.json` output contains a literal trailing `\\n` suffix instead of a newline; its individual JSON validity is not claimed. The hosted preflight command passed, and original mode, native/Rapier/material traces independently verify its intended assertions. The original sidecar is left unchanged and the anomaly disclosed.

**Final status:** Experimental measurement semantics and the original real physical outcomes are now **verified**, but the candidate has **no performance repair**. Normal source-sensitive production runtime CI, exact-source retained native LFS provenance and the owner's physical Windows 11/NVIDIA and GPU scanout acceptance remain open. Preserve Full image publication, early physics defaults and Draft/HOLD PR #757; no merge/Ready/default promotion.