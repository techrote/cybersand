# DRIV3R-WORM-001 — the slightly deranged line-steering worm brain

**Owner hypothesis:** "creation of a slightly deranged line steering worm brain, nothing fancy really."

This native research pilot gives one resident pinned LiquidAI/d1-2B Q8 decision model a little material-58 brush worm. Its job is to **choose a legal direction and make curious, steerable lines**, not reach a goal, optimise A*, solve topology or become an art supervisor.

[PR #610](https://github.com/techrote/cybersand/pull/610) is the independent synthetic-development preflight; this native branch is stacked on it, but does not edit the M5 offline benchmark, frozen M1 source/schema, D-1A/B/D-2 research branches, shared native code, or painter lanes.

## Two real worm trials

Both modes use the **same original source-built 512×512 Workbench World**, fixed 96×96 focus, start cursor (12,24), seed 570, host-protected rectangles and the same legal movement engine inherited from real-native M4. They differ only in the non-authoritative scalar information:

- **free**: the full scalar tile is zero — completely neutral. No target.
- **soft**: a gently curved, positive-valued scent ribbon. The model can follow it, ignore it, turn, backtrack or stop. It is never a permission mask or a compulsory trajectory.

At every step the host offers cardinal one-cell material additions to native-empty/unprotected cells plus STOP, and when eligible, brush-up BACKTRACK or RELOCATE_START. The actual Q8 System One *single-choice* output selects a candidate ID; there is **no free-form coordinate generation and no invented brush motion**. The model prompt asks for an odd, watchable wandering line, including turns, hesitation and interesting mistakes, with a small deterministic whim that is **identical across both modes**. Candidate presentation order is deterministically shuffled by turn and identical across modes; legal-catalog SHA is guidance-independent.

A worm may STOP early. That is evidence about the brain and must not be replaced with synthetic turns. There are **max 36 model decisions, 36 actual native one-cell writes, eight logical brush-up recoveries**, bounded Q8 request and overall time, and source-fenced native Stop/cancellation/cleanup. This remains an exploratory first session, not a multi-seed proof of controllability.

## Real material and visible artifacts

- Every actual paint calls the current source-built PAINT/Art native Workbench, verifies exactly one changed material-58 cell and its original receipt, and records the full native material World byte hashes.
- BACKTRACK and RELOCATE are brush-up logical cursor operations. They leave native material unchanged. This pilot does **not** silently use material Undo, drawing macros, automatic A*, or host-procedural continuation.
- Raw System One Q8 response, selected candidate, eligible catalog, presentation order, original observation and receipt are persisted for each turn.
- A separate fresh native Godot Workbench process replays the **original model-selected material edits** and must reproduce the identical full-World material hash.
- Source-bound D-COMMON M1 observations, guidance, actions, reversals and provenance are validated together; original failures, early STOP and evidence-laundering attempts are never converted into a success.
- Each successful original run produces `gallery/native-material.png` (full original 96-cell crop), `gallery/worm-closeup.png`, and `gallery/worm-motion.gif` reconstructed solely from actual model choices and genuine native stored-material readbacks. This is **not framebuffer capture**. There is no AI-generated fake gallery.

## First run and safe gates

1. Cheap PR CI only: compile the new Python package, test legal options and M1 guidance, verify neutral/soft information isolation, exercise original-event aggregation and derived-gallery checks, and run frozen M1/M4 regressions.
2. An explicit request-file push on `research/570-wormbrain-native-pilot` first fetches and checks the original successful M4 Q8/native comparison artifact [43659680432](https://github.com/techrote/cybersand/actions/runs/43659680432), then dispatches only **two** source-checked local Q8/native model jobs in parallel, free and soft.
3. Compare only actual matched first native inputs, decisions and original material effects. Downloaded original artifacts include full visual trails, receipt bundles, native replay and model/process cleanup. Mark any absent/failed arm **INCOMPLETE**, no synthetic substitution.
4. Inspect the two real worm trajectories and decide whether to run more seeds or introduce optional curved-step macro controls and true host-approved pen-up movements. Do not prematurely optimise the worm into an A* algorithm.

No training, paid external model API, production-provider changes, Ready promotion or merge. Native CPU/Godot/GitHub runner execution is explicitly limited to this owner-requested pilot. Legacy Stage C visual quality acceptance is not implied. All failure/cost evidence is retained.
