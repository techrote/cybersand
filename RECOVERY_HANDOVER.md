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
| Safe/eager full graphical history | Pending hosted execution |
| Actual Windows pristine import/startup/Save/reopen | Pending execution |
| New Wave2048 performance improvement | NOT ESTABLISHED |

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
Required graphical and real Windows gates remain pending. Private Xorg and
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
