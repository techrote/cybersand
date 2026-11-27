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

The [consolidated Workbench checkpoint](../audits/2026-11-27-pubpres-definitive.md) records the accepted-main join, World input transition and ordinary interaction changes.

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

A second, still unselected native candidate retains a derived certificate for
complete chunk halves whose actual material is Empty and weight/meta storage is
zero. It omits only redundant gather/scatter, preserving all settle, flux, apply
and original dry/clean decisions. Diagnostic assertions and 153 every-tick
cross-source/cross-worker lifecycle checkpoints pass, as do full Wave, spill and
body-boundary suites. Its first native timing screen contains adverse small and
no-body cases, substantial host drift and one control with insufficient observed
worker participation. The
[retained native screen](../audits/2026-11-24-pubpres-playability-final/native-empty-derived-screen.json)
does not select a winner; the next ordinary source comparison tests this arm.

The separate engine lane recovered the original #609 Godot 4.7 EGL context-handoff
patch and its exact engine identity. Clearing the cached window repairs the
Separate/ANGLE GLAD startup defect, but the second campaign exposed a later
ordinary Workbench crash on an empty `CowData` byte buffer. Mutable font-image
publication is the source-supported repair hypothesis; runtime confirmation is
pending. Its four Separate timing arms produced no valid gameplay receipt. A
distinct engine arm snapshots font Images at all ten publication boundaries
while preserving alpha, mipmaps, glyph layout and public APIs. Compilation,
framebuffer parity and ordinary
startup must pass before its timing can count. Neither engine's hosted ANGLE
behavior establishes physical NVIDIA behavior. Original Safe defaults and all
failed controls are preserved.

The default-off material deadline experiment accepts only 30 or 60 Hz. It holds
one immutable cumulative packet, replaces it without extending an outstanding
deadline, and acknowledges only an actual accepted upload. Owner retirement,
World replacement, failure and teardown cancel pending work. Independent
22-boundary/8-history byte and authority checks precede ordinary off/30/60
timing. The original physical mailbox, terrain admission and Rapier step gates
remain authoritative. A new submitted-pose/CPU observer is separately calibrated
before its measurements are used in comparisons.

A separate default-off [completed-step material experiment](../audits/2026-11-24-pubpres-playability-final/completion-count-architecture.md)
omits an accepted Full2 transaction until two real completed steps beyond the
last actual upload or a first-offer scheduled deadline. It preserves one
cumulative packet, ordinary paint priority and exact accepted histories/ACKs.
It cannot stack with the 30/60 Hz policy. Its local authority tests pass;
graphical correctness, physical benefit and freshness remain unqualified.
The [prospective count measurement contract](../audits/2026-11-24-pubpres-playability-final/completion-count-measurement.md)
adds exact seven-pair/14-boundary GPU/ACK reconstruction, source-bound ordinary
count0 controls and same-source0/2/2/0 comparisons. Actual deferred replacement
and independently joined two-completion eligibility must be observed. Count-only,
simultaneous count/deadline and deadline-only cases remain distinct; hidden and
censored presentation episodes accompany visible-pose freshness.

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

The successor remains **unqualified for final playability**. Completed platform
captures and their negative results are described below. Source review and
headless checks are not GPU acceptance.
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

The second run [45436083078](https://github.com/techrote/cybersand/actions/runs/45436083078)
executed source `515fce2862dd87d8dd01935bdf7bd1736e645901`. Both platforms passed
twelve correctness processes. All sixteen Linux source/slot captures passed
independent raw reduction and complete physical/GPU replay after correcting an
extent assumption in the added slot checker; the original workflow remains red.
The Linux large-canvas source comparison supports a relative gain, but still
contains 150–270 ms physical gaps. Wave512 and three-slot comparisons do not
establish repeatable improvements. The
[second decision packet](../audits/2026-11-24-pubpres-playability-final/development02-independent-decision.md)
retains all controls and limits. All sixteen Windows source/slot captures now
also pass complete frozen-gate replay and a separate independent peer check.
Their [Windows decision](../audits/2026-11-24-pubpres-playability-final/development02-windows-independent-decision.md)
establishes no repeatable source gain and retains the substantially adverse
three-slot results. The Windows current-Wave2048 candidate still reaches
770–774 ms maximum gaps. Complete evidence validity does not imply playability.

The second extracted Windows evaluator passed ten included launches and actual native
authoring, Save and fresh-process reopen. Its optional recovered Separate engine
crashed, so the collector was never reached and that package remains unqualified.
The third stock-engine package subsequently passed every included launcher,
extraction, source/runtime refusal, persistence and collector gate with its own
exact manifest. Its [independent custody and owner procedure](../audits/2026-11-24-pubpres-playability-final/final03-evaluator-and-native.md)
identify all nine actual hosted launches, native authoring208 checks, fresh
reopen65 checks and the complete collected evidence. Hosted ANGLE qualification
does not establish normal native OpenGL/WGL or physical NVIDIA behavior. The
separate font engine remains a research artifact until its startup, image,
ordinary gameplay and evaluator gates pass.

Final source selection and complete comparative graphical qualification remain
required. The third source's native normal/scoped ASan/UBSan tests and exact
evaluator manifest are now independently retained. Physical Windows 11/NVIDIA Follow, controls, paint, multiple actors,
material trails and sustained playability remain separate owner acceptance
requirements. No hosted software-renderer result resolves them.

The expanded third campaign
[45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606) is
running exact candidate `c2f8a73d34448bc1496ecd84bca02f0812c80d27`, tree
`351b947a50ce054361660eba9379006122527547`. Both independent native build jobs
passed, and their four source/runtime closures were separately checked against
all 105 native inputs, actual binary bytes, build logs and pinned dependencies.
The [runtime inventory](../audits/2026-11-24-pubpres-playability-final/final03-native-runtime-inventory.json)
binds that completed result. Linux graphical execution and stock Windows
evaluator execution passed; Windows graphical comparisons are still active.
The complete native normal/scoped ASan/UBSan run passed. The custom engine build
passed, but the original renderer job rejected a valid combined-patch context
alignment before any font or startup process. The
[corrected reader and source replay](../audits/2026-11-24-pubpres-playability-final/font-engine-patch-reader.md)
preserve that failure and the exact retained engine. A separately registered
[new-execution qualifier](../../tools/pubpres_final_requalification/README.md)
reuses fixed c2 application/native/engine identities with a new committed driver;
it cannot grant runtime credit until its actual processes execute. The campaign's
`final` registration phase does not mean the candidate passed final acceptance.
