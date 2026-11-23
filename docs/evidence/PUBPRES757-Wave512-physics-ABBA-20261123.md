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