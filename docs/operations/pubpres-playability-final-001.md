---
title: PUBPRES physical playability successor
status: Current
document-kind: runbook
scope: Isolated continuation of frozen 757; candidate architecture, exact evidence custody and unfulfilled physical acceptance
canonical-for: [pubpres-playability-final-001]
last-reviewed: 2026-11-24
related-documents: [pubpres-completion-001.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/simulation-tick-and-threading.md]
---

# PUBPRES-PLAYABILITY-FINAL-001

This mission continues programme [#717](https://github.com/techrote/cybersand/issues/717)
from frozen [#757](https://github.com/techrote/cybersand/pull/757), source
`c90dbc46e1f57f28e06b1f4205b83467335ff657`. Accepted main at intake remains
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`. The isolated successor branch is
`codex/pubpres-playability-final-001-20261124`, [Draft #767](https://github.com/techrote/cybersand/pull/767).
Frozen predecessors, their negative
results and unrelated programmes retain their ownership. **Draft/HOLD: no merge,
Ready, automatic default promotion or release.**

## Objective and established constraints

Actual completed Rapier steps, responsive ordinary Workbench interaction, and
coherent material/pose delivery determine success. Upload call duration, render
FPS, callback counts and green artifact jobs do not establish playability.

The recovered 22-job campaign `45078090513` improved Windows current-Wave2048
throughput relative to accepted main by roughly 29–31%, while retaining severe
physical stalls and regressing the Wave512 reference. Target publication and the
corrected Early/Combined comparison `45105890195` are verified negative controls;
neither is repeated as a new hypothesis. The original red Combined workflow and
its detached `bda07360cc0873d2ec182caa23c61a3ab9167c5e` evidence audit remain distinct.
The [predecessor handover](pubpres-completion-001.md) retains exact prior results.

## Candidate architecture

The default full-image publisher retains two ImageTextures. The explicit
`CYBERSAND_DIAG_FULL_IMAGE_SLOTS=3` experiment adds exactly one bounded spare.
It updates that spare before rotating the current/previous pair. No draw samples
its own destination, no mutable input is retained, and current/previous histories
retain their exact bytes and revision ordering. One intervening publication is
**not** a GPU fence or guarantee of nonblocking driver work. Hardware allocation
and scanout are unobserved. Invalid resource ownership reconstructs the exact
full-history fallback before acknowledgment.

The native repair computes tight bounds around actually occupied body-mask cells
once under the exclusive World owner. Wave columns outside those bounds skip
obstacle lookups whose result must be zero. The configured mask remains unchanged
for dry/clean classification; material turns, water accounting, coupling and
actual body samples retain their original semantics. The
[native architecture record](../audits/2026-11-24-pubpres-playability-final/native-architecture.md)
documents the proof, alternatives and independent frozen/candidate controls.
Terrain revision alone cannot license stale body-sample reuse: native occupancy,
coupling feedback and equipment geometry belong to the actual sample. No extra
Rapier steps, fabricated callback credit, skipped material turns or stale-sample
admission are introduced.

The separate engine lane recovers the original #609 Godot 4.7 EGL context-handoff
patch and independently qualified engine identity. Clearing the cached window on
context release repairs a source-located Separate/ANGLE startup defect. It does
not establish physical NVIDIA behavior or a performance gain. Stock official4.7
and the patched engine remain separately identified; original Safe defaults and
Separate failures are preserved.

## Comparison and evidence contract

[Prospective registration](../../tools/pubpres_final/registration.json) defines
serial, same-host source D/C/C/D and slot 2/3/3/2 comparisons. D is frozen #757;
each source receives an independent native build with matching compiler and
godot-cpp inputs. Wave512 Follow and current-Wave2048 Follow are primary; medium,
landscape, PressureFlow and FreeMass cases provide scoped confirmation. A separate
sustained capture retains the full interval, including later tails.

The frozen V3 native, terrain, input, completed-step, body and current-GPU
oracles remain unchanged. New tests add source-bound slot treatment, fixed
resource ownership, exact first current/previous GPU reads and dense-to-sparse
reuse. Supplementary clocks explicitly distinguish application command admission
from device-input latency and post-draw delivery from scanout.

The first development checkpoint is **unqualified** until actual platform
execution finishes. Source review and headless checks are not GPU acceptance.
Local native development uses GCC14.2; hosted qualification retains pinned GCC13.3
and LLVM-MinGW23.1.0. The local workspace refuses Unix sockets, so its attempted
owned Xvfb startup is retained as an environment failure and graphical execution
uses the repository's GitHub-hosted policy. No acceptance condition is relaxed.

## Delivery and owner gate

The first source-frozen run [45430704276](https://github.com/techrote/cybersand/actions/runs/45430704276)
built both independent platform pairs and executed twelve correctness outcomes
per platform. The original run failed because the independent checker required
positive ObjectIDs; Godot RefCounted textures legitimately use negative signed
64-bit identities. All actual image histories matched. The
[separate corrected replay](../audits/2026-11-24-pubpres-playability-final/object-id-replay.md)
passes unchanged original receipts without rewriting that failed run. Timing
comparisons were correctly withheld. The
[development inventory](../audits/2026-11-24-pubpres-playability-final/development-01-inventory.json)
binds every archive and runtime. The
[decision packet](../audits/2026-11-24-pubpres-playability-final/decision-packet.md)
retains the causal account and unresolved selection.

The selected final source requires an ordinary interactive Windows evaluator,
exact runtime and per-file manifest, executed extraction/launch/authoring/reopen,
ergonomic result collection, and a short owner test procedure. Those deliverables
remain pending at this initial implementation checkpoint. Physical Windows11 /
NVIDIA Follow, controls, paint, multiple actors, material trails and sustained
playability remain separate owner acceptance requirements.
