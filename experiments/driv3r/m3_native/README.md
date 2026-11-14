# DRIV3R M3 — single real Workbench observation/action/recovery smoke

**Owner authorisation:** M3 bounded native integration qualification, starting with *one* real World observe → paint → brush-up recover → readback cycle, before any long-horizon expansion. The approved M1 contract stays byte-for-byte frozen: source `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`; schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`. M2 composite source is separately Draft/HOLD. **This is not merge, Ready promotion, production/editor integration, or formal A1/A2/A3 study authorisation.**

## Scope and exact authority

- Reuse the existing source-qualified Godot `godot/tests/run_driv3r_stage_a.gd`, `experiments/driv3r/native.py` adapter, native C++ `CyberNativeCellWorld`, #568 real Workbench authority and its 512×512 World/96×96 focus fixtures. Do not alter their accepted implementation or represent v1's variable-size schema as qualified variable-size native support.
- One **deterministic host-selected** action from a finite legal set (`MOVE_DOWN_ONE`, `STOP`): paint cell (12,25) with material 58 after a fresh native observation from `wall-v1`. Recheck the original native epoch/generation, native receipts, changed-cell count 1 and full original/after material readback and material PNG.
- Immediately **BACKTRACK_CURSOR** with the brush up, from (12,25) to previously saved (12,24), in the **host-owned logical cursor**. Reobserve actual native material after rewind; the painted cell must remain and both full World/crop material hashes must be unchanged across backtrack. **No claim of native-simulated pointer travel or native material Undo** is made by this logical operation.
- Exercise one stale-epoch refusal, explicit host STOP and late-action refusal with zero changed material. End the session and verify process reap/cleanup.
- A second fresh native World process replays the **recorded original Art operation** (not an inferred reconstruction) and must reproduce identical final full native World material SHA and one-cell delta.
- Emit true D-COMMON v1 `guidance`, `observation`, `action`, `reversal`, `provenance` event records, separate mandatory scalar `u16le` guidance (optional channels empty for A1 smoke), origin/versioned semantics, source SHA, checksum-bound native JSON receipt, full World material bytes, material-derived PNGs, independent replay result and cross-record source/byte checks using unchanged accepted M1 `verify.py`. Audit first-pass failures and any partial output without upgrading them to acceptance.

## Limits and dispatch

- **One native forward editing operation**, **one cursor-only recovery**, one independent exact native replay; at most two native Godot sessions (original and replay). The independent replay is not a second research episode. There is no d1 inference, model/weights download, native material Undo, graphical frame capture or GPU/API inference.
- Native source-build uses the exact existing Stage A Godot/Godot-cpp/Rapier/compiler/native library pins and source matching. All processing remains on the declared GitHub-hosted `ubuntu-24.04` runner, with bounded deadlines and no secrets. No force merges, mutable model downloads, scheduled jobs or repeated experiments.
- The new workflow runs **cheap-only** checks for PRs; the costly native job is gated on an explicit branch-only `qualification-request.json` push. No broad `on: push` of code changes can accidentally trigger native build. Failures are retained as original evidence via `always()` artifacts.
- After a clean source-matched M3 first-cycle PASS, report acceptance **only of this one-cycle native integration boundary** and identify the next bounded native Undo/relocation/guidance-channel or multi-decision qualification gate. Do not claim full M3 long-horizon readiness, model-superiority, A1/A2/A3 model results or Stage C graphical acceptance.

## Preparatory gate

1. Commit source and offline tests on the isolated `research/570-d-m3-native-smoke` branch, open an independent Draft/HOLD PR based on M2. Preflight must establish syntax, model-free bounds and M1 schema custody.
2. Create one explicit, SHA-bound `qualification-request.json` on that exact branch to trigger one source-built native qualifying execution; recheck original result before any subsequent repair-triggered qualification.
3. Review the complete native output: startup/generation, original before/action/after material bytes, validated real native receipts, logic cursor backtrack and material preservation, host Stop/cancel, independent second native replay, paths/hashes, cleanup, final D-COMMON schema conformance. Do not confuse synthetic vs actual material images vs framebuffer images.
4. Retain Draft/HOLD; no merges, Ready, campaigns or production changes. Report PASS/PARTIAL/FAIL and next owner decision with exact source, workflow run and original artifacts.
