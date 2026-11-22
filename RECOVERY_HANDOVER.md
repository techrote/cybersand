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
| First bounded package repair | `94864ca351532ca35c7248b1248dd868b9eb1c09` |

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
| Safe/eager full graphical history and Rapier baseline | Pending execution |
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
The standalone checkout documentation gate currently reports missing companion
workspace fixtures; the repository provenance gate additionally rejects retained
adapter runtime receipts whose source is stale. Neither refusal is waived or
reported as final-source qualification. Build-specific receipts identify the
fresh experimental runtime separately. Required graphical and real Windows
gates remain pending. A private Xorg attempt failed before Godot because this
environment refused display listener sockets; an existing permitted desktop is
being investigated, with hosted graphical testing as the fallback.

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
