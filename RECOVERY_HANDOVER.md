# PUBPRES-PLAYABILITY-003 — live engineering handover

**Updated: 2026-11-22. Status: implementation in progress, Draft/HOLD.**

This is the durable recovery entry for the owner-authorized third playability
mission. It continues the frozen PUBPRES-001 source; it does not reopen the
historical programme from scratch. No merge, Ready promotion, auto-merge or
ordinary-default promotion is authorized. Physical Windows/NVIDIA acceptance
remains the owner's gate.

## Exact custody

| Role | Identity |
| --- | --- |
| Repository | `techrote/cybersand` |
| Programme | [#717](https://github.com/techrote/cybersand/issues/717) |
| Successor branch | `experiment/pubpres-playability-003` |
| Preserved donor | [Draft #719](https://github.com/techrote/cybersand/pull/719), `d316c281e0abb575eb6302afc12ec44f211460ba` |
| Donor tree | `7a57dc0873dd161abe165f3a60e14e64886d04a8` |
| Historical qualified integration | `8503ec19e4d620e125dc6df2c5c6571b1256cb92` |
| Historical integration branch | [#682](https://github.com/techrote/cybersand/pull/682), preserved |
| Accepted main at recovery | `662df51cd8409a52332fa7ef15d06d8ab8945aed` |
| First bounded package repair | Published `11e8c397f6ec8e1e963df7948a7916724f371923`, same tree as local `94864ca351532ca35c7248b1248dd868b9eb1c09` |
| Successor PR | [Draft/HOLD #740](https://github.com/techrote/cybersand/pull/740) |

Use `git rev-parse HEAD HEAD^{tree}` for the current log's exact source and tree.
The successor PR/checkpoint comments record each published commit. Main must be
refreshed again at integration and final qualification; this recovery observation
is not a future-main assertion. Complete PUBPRES branch search returned only the
historical integration and original playability branch, with its continuation
cursor exhausted. No published PUBPRES-002 successor was found.

## Preserved evidence and findings

The original 102 Actions ZIPs, 4,713,670,355 bytes, are already preserved in the
owner's recovery archive. Do not redownload or rearchive the entire collection.
The [original catalogue](https://github.com/techrote/cybersand/pull/719#issuecomment-7073300459),
[supplementary catalogue](https://github.com/techrote/cybersand/pull/719#issuecomment-7073473330)
and [post-disconnection audit](https://github.com/techrote/cybersand/issues/717#issuecomment-7074353296)
retain the original identities and negative results. The prior recovered
`RECOVERY_HANDOVER.md` was read completely; its 7,502-byte record and reconstructed
source subset remain historical, separate from this complete Git checkout.

Original final run `44963596029` ended with 42 successful jobs, two failures and
two skips. Its representative Wave2048 same-frame continuation did not establish
a gain: the two Windows ON arms retained 105 sample, 43 terrain and seven mailbox
refusals, with zero successful continuations. The narrower Wave512 gain does not
qualify large-canvas playability. Safe/reachable history failures and Windows
Separate/ANGLE access violation remain strict negatives. Installed author/Save/
fresh-process reconstruction passed OFF and ON, while pristine-package reopening
failed its import-descriptor custody check; these are distinct results.

The science lane recovered only nine relevant original archives and verified
their bytes against the original GitHub SHA-256 values. Full independent hashing
of all 102 original archives remains a separate, lower-priority integrity task.

## First correction and tests

Original Windows run copies proved that `Radial2D.svg.import` changed only from
1,118 bytes with 44 CRLF endings to the exact 1,074-byte committed LF descriptor.
The first repair pins `.import` to LF and explicitly makes historical M/I archive
exports canonical where their original attributes did not specify an EOL. It
keeps descriptor hashing, immutable pristine payloads, forged-manifest rejection,
runtime identity and unexpected-file refusals. It does not bless arbitrary
post-import changes or rewrite an original package.

| Executed gate | Result / scope |
| --- | --- |
| Frozen measurement helpers | PASS, 28 tests at exact donor |
| Frozen Windows package helpers | PASS, 27 tests at exact donor |
| Frozen build/display helpers | PASS, 26 tests in complete donor checkout |
| Corrected package helpers | PASS, 29 tests, including actual Git archive EOL and changed-descriptor refusal |
| Minimal pinned Godot 4.7 import | Exact committed LF descriptor remained unchanged |
| Source-matched frozen Linux native build | PASS: 5,168,408 bytes; SHA-256 `a842d77977644ea330d826710ac7cf50a7b1150f0e8b65a27101e481e73b06ae`; exact donor/tree and 105 native inputs recorded; local GCC 14.2 scope |
| Independent retained-trace audit | PASS: 32 arms, eight ABBA cohorts, 12 adversarial reducer tests; unchanged original validator and three independent timing-window reductions agree |
| Focused frozen native/Rapier baseline | PASS: fresh import plus eight test processes, including publication OFF/ON, real same-frame native/Rapier execution, pacing, manual steps and owner deadlines |
| Additive producer/Main trace | PASS: real Workbench trace ON/OFF, bounded ownership, late-native-failure/terrain publication and same-frame integration; explicit development delta and unchanged native input closure |
| Safe/eager full graphical history | PASS on hosted Linux successor `0fc3adc48b7e25c39a2211989169c1e43d46639f`, including all camera phases; frozen camera fixture remains FAIL |
| Actual Windows pristine import/startup/Save/reopen | Pending execution |
| New Wave2048 performance improvement | First native-only correction reduces mean column phase by 7.93% in balanced D0/C1/C1/D0; graphical sustained playability NOT ESTABLISHED |

Local development compiler is GCC 14.2, whereas final hosted qualification must
use its declared pinned platform compiler. Local comparisons must use the same
toolchain and record the explicit toolchain-drift allowance. No local result may
be relabelled as a pinned hosted build.

The independent old-trace audit is retained under
[`tools/pubpres003/evidence/recovered-frozen-d316`](tools/pubpres003/evidence/recovered-frozen-d316/retained-trace-audit.md).
Current-gameplay Linux native tick medians were 176–185 ms, versus 22–23 ms for
the different historical one-round/no-spill fixture. Packet readiness also
preceded Rapier execution by roughly 67–78 ms at the median. Both native
computation and downstream delay need causal investigation; these observations
are not a successor performance claim.

Checkpoint documentation checks: historical M11 integrity PASS (18 records,
28 hashes), diff whitespace PASS, retrieval 30/32 routes (known Q19/Q32 misses).
After materializing the five exact retained companion fixtures, documentation
PASS covers 147 documents, 276 claims, 4,163 links and 32 questions. Repository
provenance still correctly refuses stale retained adapter runtime receipts;
final matching runtime publication is pending. Neither refusal was weakened.
Build-specific receipts identify the fresh experimental runtime separately.
Final-source graphical and real Windows gates remain pending. Private Xorg and
existing-desktop attempts could not execute a real renderer in this environment;
the dedicated bounded hosted workflow is the selected path.

The [local authority archive](tools/pubpres003/evidence/checkpoint-02/local-native-authority.json)
binds immutable original process logs, receipts, the explicit application/native
identity clarification and local-to-published tree mapping. The producer
receipt's original `source_tree` field identified the native donor while its
`source` named the test application; its preserved correction sidecar separates
those identities. The original receipt is not rewritten.

An additional strict review found that the original camera test exited zero
after a script error on an unconstructed lazy Art panel: six root-stretch and
twelve moving-Follow phases were absent. That original result is FAIL, not a
camera qualification. The successor fixture invokes the ordinary Art action and
requires every phase; no pixel/history assertion is relaxed. The exact frozen
fixture remains untouched and the new hosted runner will retain its failure.

## Causal instrumentation checkpoint

Main observes each existing mailbox call once, including returned packet and
requested sample identities, current owner, native completion, first handoff,
terrain check/queue/budget and entry to the existing physical transaction. The
worker records sample acceptance, worker latch, coupling preparation/results and
completion of native getters before healthy publication. Ordinary Main tracing
defaults off. Captures are bounded; unknown identities remain unknown. No new
mailbox poll, terrain allowance, callback, accumulated time credit or solver step
is granted. `transaction_entry` is not final native-response admission: the
existing response validation and genuine Rapier completion remain mandatory.

The dedicated `pubpres003-focus.yml` request runs frozen and successor Safe/eager
checks, three genuine frozen gameplay baselines and one explicitly diagnostic
current-gameplay causal capture sequentially. Its payload hash excludes only the
request file; pinned compiler/engine/native/Rapier source identities remain
required. The original 176-arm campaign and registrations are unchanged.

## First native correction and independent repair loop

The first retained native correction removes redundant writes to already-invalid
Wave column metadata inside each worker-owned strip. It changes neither the
Water law nor the number of cells, substeps, callbacks or native work allowances.
The two half-chunk clean flags are ordinary distinct `bool` memory locations;
column dry flags are distinct bytes. Existing phase barriers and ownership are
unchanged. Repeated invalidation stores were causing avoidable shared-cache-line
traffic. The source delta is seven added and two removed lines in
`native/src/world_wave.inc` (original implementation commit `4215a9b2b3681b11a0115fc896c23fbde3d6ed6f`).

The balanced four-worker current-gameplay native diagnostic retained spill,
parcels, ballistic transport and two Wave rounds. Fixed-first-144 column means
were 58.996 / 57.682 / 52.201 / 60.355 ms for D0/C1/C1/D0: pair means
59.675 to 54.942 ms, a 7.93% reduction. This is a modest native-only result, not
evidence of a playable graphical candidate. Every capture correctly fails the
graphical validator because it is headless. All native/actor/sample/terrain/input/
Water oracles passed. The [balanced report](tools/pubpres003/evidence/native-column-abba01/REPORT.md)
retains per-run tails, exact binaries, source identities, variation and raw-capture
archive custody. No tail quantiles are averaged into an invented population.

A new live current-gameplay native regression checks 24 exact full physical-state
hashes across one, two, four and eight workers, with a negative origin, partial
viewport interruption, independently scanned Water plus parcel inventory, real
ballistic launches and actual worker participation. D0 and C1 match every
checkpoint. [Original logs, receipts and archive](tools/pubpres003/evidence/native-invalidation-2026-11-22/README.md)
retain both positive and failed development records without rewriting receipts.
The archive is 252,532 bytes, SHA-256
`9a8ca36dcf6ac42e7c7fec322fc297a3ca2b3e489181beee394be595f292976c`.

A second experiment grouped both half-column tasks on one worker. It preserved
all physical-state checkpoints but slowed the fixed-144 column mean from an
adjacent C1 control's 60.891 ms to 72.435 ms (18.96% worse). It is rejected and
is not integrated. The native lane is profiling gather, settle, support, head,
depth and scatter within the dominant column phase before another correction.

Independent qualification review found a real gap in the new capture runner:
a valid smaller workload could satisfy the old generic receipt predicate while
being the wrong requested arm. The correction binds exact source, nonce, fixture,
renderer, thread mode, camera, workers, Water law/profile/variant and input mode,
and requires complete ordered cohorts with identical apparatus. The reviewer
independently reproduced the original hole and verified the repair against the
original trace and 25 mismatch/order/hardware cases. See
[the preserved finding and delta review](tools/pubpres003/evidence/science-review/).
Existing raw captures are not rewritten: captures produced by the earlier runner
must pass the corrected post-hoc binding check before any qualification claim.

## Hosted baseline and delivery checkpoint

[Run 44991036789](https://github.com/techrote/cybersand/actions/runs/44991036789)
tests exact source `0fc3adc48b7e25c39a2211989169c1e43d46639f` (tree
`98f0a5c54f44ea6d837b3b6a2c0b04fdcaa502d4`), before the C1 native correction.
Independent pinned frozen and successor Linux builds passed. Successor Safe/eager
pixel-history and complete camera tests passed. The original frozen camera
fixture failed as expected and remains a strict negative. Three frozen gameplay
captures and one successor current-gameplay causal capture completed; independent
post-hoc workload binding and temporal reduction are in progress. Windows build,
pristine import, actual author/Save/fresh-process reopen and package tamper gates
follow sequentially. This development baseline is not the final owner evaluator.

The original Linux artifact is 85,709,448 bytes, SHA-256
`e45c0f882bec0e41b648002538e5de0289135d41b32ac4dc0d8a16da77257166`,
GitHub artifact `14742083432`. It was downloaded and independently hashed.

Final evaluator support now has an explicit additive v3 manifest carrying four
independently built M/I/F/C applications; F is pinned to the exact donor commit
and tree. The owner comparison is F versus C, Safe/eager by default. All four
compiler/dependency identities must match; 39 package tests pass, including a
coherent but mismatched fourth toolchain refusal. Historical v2 packages retain
their existing verification. Actual Windows execution of the v3 package and
one-click active Wave2048/Save/reopen scenario remains pending final publication.

Accepted main was refreshed and merged as published two-parent commit
`62020af419e3e23dfabd1d22379fac2c1bbf0eec`, tree
`ac761a025da188291c2c0a3a8570d25f2fe9629b`. Its parents are successor
`282bba75d4864cc4b48733ceb8d2f2a144bc3f0e` and accepted main
`662df51cd8409a52332fa7ef15d06d8ab8945aed`. Application/native/material/example
subtrees are byte-identical before and after integration; the accepted changes
are CI and documentation. The accepted soliding reuse suite passes 12 tests and
worldgen build inventory passes 21. The [source mapping](tools/pubpres003/evidence/mainline-reconciliation.json)
also proves accepted main's application subtrees equal the frozen registration's
historical M, without rewriting that registration or relabelling its receipts.
All final-source executable builds and qualification remain required.

The one-click F/C evaluator scenario uses ordinary Apply, pilot selection,
Follow, Play, Save and fresh-process Load of a genuine current-gameplay
Wave2048 World. Forty-two package tests pass. Two real development Godot
processes prove four completed native/Rapier steps per startup and preservation
of an ordinary brush edit across Save/reopen. This headless result is explicitly
not graphical or sustained-play acceptance. The new v3 Windows scenario remains
pending actual hosted execution. The earlier v2 Windows development package has
built and passed its hosted corruption/process-ownership controls; pristine
import/startup/reopen is running.

## Active ownership and next work

Three specialists work in separate branches rooted in the donor:

| Owner | Branch | Source responsibility |
| --- | --- | --- |
| Native/physics | `work/pubpres003-native` | Worker/snapshot, native adapter, causal producer timing, native authority tests |
| Renderer/Windows | `work/pubpres003-renderer` | Renderer helpers/tests, package/export/reopen, pinned graphical dependencies |
| Performance science | `work/pubpres003-science` | Additive trace audit/reduction, matched workload runner, original evidence and causal interpretation |
| Lead integrator | `experiment/pubpres-playability-003` | `main.gd`, workflows, cross-stream integration, current-main reconciliation and publication |

Do not concurrently edit `main.gd`. Keep original v2/v3 experiment evidence and
registrations immutable; new instrumentation/reducers must identify their own
scope. Preserve actual callback credits and fixed Rapier steps, exact
World/session/epoch/sample/terrain/actor/input fences, native failure quarantine,
bounded queues, work allowances and all distinct Water laws.

Immediate sequence:

1. Finish the exact-source Safe/eager/Rapier baseline and reproduce active
   Wave2048 with real participating workers and actors.
2. Correlate existing healthy native handoff timestamps with additional bounded
   mailbox-observation, terrain-install and final-admission spans. Distinguish
   native computation from delivery, observation and callback/render delay.
3. Implement the smallest causal correction, verify authority and compare
   source-matched OFF/ON/ON/OFF before any broad campaign.
4. Continue justified repairs if the demanding workload still freezes. Include
   current Wave spill/ballistic gameplay, stationary camera and non-Wave controls.
5. Reconcile then-current accepted main after a measured gain, rebuild exact
   final-source runtimes, run Linux/Windows and sustained-play qualification,
   independent review, and deliver the new evaluator with simple owner trials.

Heavy compilation, archive processing and graphical timing must not overlap in
a purported controlled local performance comparison. Shared CI must remain
bounded; do not restart the original 176-arm campaign before a credible repair.

Checkpoint after recovery/baseline, instrumentation, first causal correction,
targeted comparison, accepted-main integration and final qualification. Preserve
each failed result and executable identity; never update a historical receipt
after code changes. This file must be updated with actual outcomes at each
checkpoint so another agent can continue from GitHub without ephemeral state.
