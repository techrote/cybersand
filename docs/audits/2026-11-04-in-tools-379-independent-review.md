---
title: IN-TOOLS 379 independent admission and retrieval review
status: Current
document-kind: evidence
scope: Independent documentation and test-only correction of PR 379, reproduced retrieval and native evidence, exact-source custody, integration recommendation and separate Liquid Drain handover; no gameplay implementation or owner merge approval
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-in-tools-admission.md, ../architecture/in-tools-gameplay-admission.md, ../operations/in-tools-fixtures-and-playtest.md, ../systems/actor-usables.md, ../operations/current-and-historical-validation.md]
---

# IN-TOOLS 379 independent admission and retrieval review

## Decision and authorization boundary

This is a preparation-only review of [PR #379](https://github.com/techrote/cybersand/pull/379).
**Independent corrected-source review: ACCEPTED, with no unresolved blocking
source findings.** Recommend owner approval of this preparation package after
the final frozen-head local/hosted ledger is complete. The
[independent disposition](in-tools-379-review-2026-11-04/independent-review.json)
records the separately performed source, test and packet checks. Its architecture
is suitable for bounded future implementation; that is not implementation or
merge permission. The assignment explicitly withholds advance
merge approval. Leave the PR open and [#361](https://github.com/techrote/cybersand/issues/361)
open; no production liquid command, equipment implementation, native momentum
input, default change or gameplay acceptance is supplied by this review.

The [original audit](2026-11-04-in-tools-admission.md), original native packet,
query registrations and source locks remain unchanged historical evidence.
The new [retrieval record](in-tools-379-review-2026-11-04/retrieval-review.json)
retains the original regression as well as its correction. Green predecessor
checks are not assigned to a different head.

## Recovered authority and integration plan

| Authority | Inspected identity |
|---|---|
| Accepted main | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` |
| Accepted-main tree | `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Published original #379 | `24d0e612ae986edbdc48e5b94f52315d9c3d8421` |
| Published original tree | `9a59169d74b74cef9bcb89d50c6a7c362136bbfd` |
| Pinned unmerged #370 | `fbe82bcab8f821aac442c2bf59eb57b279717873` |
| Unimported #358 material branch | `7383946a3ed384966e9e5fb72553fc267f9aacb7` |
| Companion documentation | `6a58311982941b75f46e22109a0829e5acb83c7e` |

A fresh repository and separate review worktrees preserve the original branch
and other agents' checkouts. Root AGENTS, development handover, README/index,
roadmap, ownership, provenance and relevant native/application contracts were
read. No descendant AGENTS was present. The
[intake record](in-tools-379-review-2026-11-04/intake.json) records live metadata,
original hosted checks and the absence of owner approval or existing PR reviews.

At intake main had not advanced, so no merge/rebase or source-lock refresh was
needed. Corrections are additive descendants of the published #379 commit.
Before publication and any later integration, compare live main and the remote
#379 head again. If either moves, inspect the actual changed inputs and reconcile
additive documentation deliberately. A production/source-lock mismatch requires
a new admission decision, not regeneration of the 25-input lock. Do not import
#361-A work, #358 materials or #370's active host/recorder. #347/#364 retain
mask/contact ownership; #353-B retains production catalogue-consumer migration.

## Independent findings and corrections

Findings refer to the original published source. They are qualification/tooling
defects, not demonstrated defects in the production liquid solver.

| Finding | Severity | Original exact source | Correction and verification |
|---|---|---|---|
| E1: a zero-exit compiler could leave a previous executable available for execution | High | [runner compilation/execution](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/tools/lcb/run_in_tools_native.py#L296-L318) | Retire the previous output before compilation. A successful compiler exit without a fresh executable fails closed. Preserve the failing regression and corrected control. |
| E2: native quantity checks reconciled the incremental ledger against itself | Medium | [quantity/conservation helpers](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/native/tests/test_in_tools_361_contract.cpp#L31-L39) and [flow checks](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/native/tests/test_in_tools_361_contract.cpp#L179-L191) | Independently scan all stored cells in the registered resident domain, compare quantities and material counts, and enforce exact barrier/escape geometry. Deliberate ledger/count/position/domain corruptions must fail. |
| E3: physical-hash parity did not establish IN diagnostic-ledger parity | Medium | [pair reduction](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/native/tests/test_in_tools_361_contract.cpp#L226-L234) | Compare separate per-tick IN ledger traces between workers 1/4 and the original/restored continuation. The original audit already disclosed this limitation; its historical result is not relabelled. |
| E4: ambiguous JSON and incomplete/duplicated plan content could pass copied-contract validation | Medium | [plan validation](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/tools/lcb/in_tools_contract.py#L102-L171) and [JSON loading](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/tools/lcb/in_tools_contract.py#L332-L350) | Reject duplicate object keys/nonfinite constants, vacuous schedules and incomplete/duplicated registration coverage. Original fixture bytes and source locks remain intact. |
| E5: refused out-of-domain footprints were subtracted from finite-World capacity, while fictitious external liquid could pass | Medium | [copied local/full-World capacity check](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/tools/lcb/in_tools_contract.py#L305-L319) | Count only the footprint's intersection with the complete observed World. Require copied out-of-domain cells to be Empty and unmasked. Preserve two false-rejection failures and the false-acceptance control. |
| R1: Planned ordinary-equipment prose displaced a Current canonical answer | Medium | [original Planned usable subsection](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/docs/architecture/in-tools-gameplay-admission.md#ordinary-usable-contract) | Replace duplicated Current lifetime prose with links to its actual owners; retain the distinct Planned metering requirements. USABLE02 returns to rank 5. |
| R2: Current usable contract opened with Planned content and had a weak physical-equipment heading | Low | [original actor-usable page](https://github.com/techrote/cybersand/blob/24d0e612ae986edbdc48e5b94f52315d9c3d8421/docs/systems/actor-usables.md#physical-actions-and-copied-feedback) | Move the Planned notice to its own subsection and give the existing Current equipment content a descriptive heading. ACT14 returns to rank 1. |

The architecture reviewer independently traced whole-cell Water, separate Brine
counts, construction-only normalization, immutable policy/radius, motion bounds,
external-write state retirement, body masks, worker cancellation and copied
readback. No blocking architecture contradiction was confirmed. Public
`quantity_ledger()` validates its aggregates without an independent test-side
census; native save serialization's internal validation does not replace the
new independent oracle. Automated-agent review is not owner approval or a
separate human/account PR approval.

## Retrieval reproduction and disposition

| Unchanged cohort | Accepted main top 1 / top 5 | Original #379 top 1 / top 5 | Corrected top 1 / top 5 |
|---|---|---|---|
| Frozen 32 | 19 / 32 | 19 / 32 | 19 / 32 |
| Existing 157 | 124 / 156 | 123 / 155 | 124 / 156 |
| New #361 six | Not registered | 2 / 6 | 2 / 6 |

| Question | Accepted main canonical rank | Original #379 | Corrected |
|---|---:|---:|---:|
| USABLE02 | 5 | Outside top five | 5 |
| ACT14 | 1 | 2 | 1 |
| LCB08 | 2 | 3 | 3 |

USABLE02's unchanged expected canonical destinations are
`reference/interfaces-and-message-contracts.md` or
`architecture/data-ownership-and-lifetimes.md`; they are not actor-usables.md.
The latter remains the Current subsystem owner. The new architecture now links
the Current equipment interface/cancellation contract and owns only its Planned
U10 extension. Query text, expected canonical paths, evaluator, stemming,
thresholds and historical results were not modified. The repair also leaves the
corpus manifest unchanged.

Every challenge rank now agrees with accepted main except LCB08's disclosed
2→3 shift. It remains a Current canonical top-five hit. Existing LCB03 remains
the original miss. Existing-cohort MRR@5 is 0.8723 versus main 0.8734 and original
PR 0.8678. This remaining rank shift is acceptable for the preparation package:
all requested hit targets are restored, no additional question loses its
canonical hit, and the relevant quantity qualifiers remain present. No further
keyword tuning or evaluator change is used to erase that residual.

The committed retrieval record includes complete rank lists, scored top-five
results for all three focused questions, rendered-chunk and input hashes,
separate first-repair iteration and expected-fact review. It qualifies a lexical
development cohort, not arbitrary queries or semantic answer correctness.

## Native evidence and remaining gameplay limits

The [independent original-head reproduction](in-tools-379-review-2026-11-04/original-native-reproduction.json)
passes the original 8,761,999 repeated assertions, 16 flow pairs/32 arms and 224
ticks per arm, including actual four-worker claimants. All 56 recorded inputs
match the original published packet, whose SHA-256 remains
`8e4bc9932c06b30c89c01d7f107d739c6db26fb9bae8060201fe82ab77d2a276`.
That reproduction establishes reproducibility, not completeness of its original
oracles. Compiler/executable/source/runner hashes are unchanged across the run.

The [corrected v2 execution](in-tools-379-review-2026-11-04/native-qualification-v2.json)
passes all 16 pairs/32 arms and 215,237,704 repeated assertions. Most additional
assertions are repeated cell census checks, not independent scenarios. All
configured-four arms observed four claimants; separate physical and IN ledger
trace comparisons pass. Compilation/run exit 0, and all four custody guards
(inputs, runner, compiler and executable) remain true. The packet binds native
source commit `4e6af91c61b8778d3c6e80d23ad0c7329935f03a` and all 56 compiled
inputs. Later copied-contract and documentation changes do not change those
native inputs. The final published-head rerun is a separate PR-ledger record.

| Corrected native identity | SHA-256 |
|---|---|
| V2 qualification packet | `5344e9dc8459c2ddfd89c2e4bc0e7770d99c15ce922db4f96fb9d964d3109ae2` |
| Native test | `393ffb1b1e9782a89345ea8e19ed755238d815af57671eade3dd834009137e27` |
| Runner | `f6a04bbba8eec3fb888c524e0bf5856beae3a5ddb92599d270c84c397a4801f4` |
| Executable | `6ed6dbbadbed344ccb9c051a553c329990b64a46dc070338df894d6a8c646193` |

GCC 13.3 on Linux compiled in 25.457 seconds and executed in 97.830 seconds,
within unchanged 600-second compile/run bounds. These are instrumented wall
times, not a cost comparison. Original source packet and failure history remain
intact.

The corrected result schema is `in-tools-native-primitives-v2`; historical v1
packets remain evidence under their original runner. V2 independently checks the
393,216 cells in all 24 registered resident chunks at completed ticks
0, 8, 24, 32, 64 and 224 in each arm, then both original and restored Worlds at
232. A new chunk is a domain failure. Census checks exact Wall positions,
liquid confinement, allowed materials, stored Water mass and separate material
populations. Five negative controls cover wrong Water totals, wrong cell counts,
escaped liquid, a removed barrier and an extra chunk. Physical-state traces and
IN diagnostic-ledger traces are separate comparisons.

The field `first_reservoir_depletion_tick` replaces the misleading
`first_flow_tick` name in v2. It remains a reservoir-census onset observation.

| Evidence | Established scope | Not established |
|---|---|---|
| Actual production World primitives | Linux native ingress/removal, masks, barriers, quantity, workers and state continuation | Shipped Godot extension execution, Windows or main-thread Rapier gameplay |
| Complete resident-domain census | Exact inventory and positions at registered checkpoints, with no extra resident chunks | A per-tick full-domain scan or a flux instrument |
| Physical and IN diagnostic parity | Separate worker traces and native restore continuation | Equipment, command queues, actor input or body-graph replay |
| Native close/reopen composition | Empty-only closure and continued primitive state | Authenticated applied gameplay-command receipts |
| Empty-intake control | Second immediate removal has zero effect | Full reservoir exhaustion or a production finite-budget controller |
| Eight-tank width-four edit | 32 primitive targets | Proposed 16-target application-command bound |
| Synthetic proposal tests | Discrimination of malformed/stale/inconsistent supplied copies | Authentication of native receipts or actual gameplay actions |

No fluid physics, tolerance, native production file, fixture geometry, source
lock or old result is changed to pass the stronger oracle. Instrumented times
include census, hashes and assertions and are not performance measurements.

## Validation, provenance and exact-head gates

The [original local validation](in-tools-379-review-2026-11-04/original-validation.json)
records documentation, materialized repository provenance, retained M11,
six-plan/25-current-input/nine-comparison-input checks, 15 existing policy tests,
policy/capability/normalization/receipt/scenario checks, LFS and whitespace.
The initial documentation attempt failed on six references to five absent
companion files. Their exact pinned bytes were restored, recorded in
[companion inputs](in-tools-379-review-2026-11-04/companion-inputs.json), and the
unchanged checks then passed. No expected fact or historical hash was weakened.

All 18 existing runtime payloads are materialized and checked against their
committed LFS identities and provenance. This is identity validation, not new
runtime execution. The material catalogue's 27 protected-source lock, compiler,
99 adversarial tests and standalone native metadata parity also pass on the
unchanged production inputs; no consumer migration is performed.

The corrected focused Python suite passes 58 tests (38 proposal, 20 runner).
The original 49-test suite
passed before new adversarial regressions exposed the gaps. Each meaningful
before-fix failure and its corrected control is retained with exact commands,
source hashes and log digests in the
[correction record](in-tools-379-review-2026-11-04/evidence-tool-corrections.json);
none is converted into a historical pass. The first intermediate regression-only
test snapshot was not separately hashed at failure time; that custody limit is
explicit, while original implementation hashes, failure output and replayable
corrected tests are retained. That reviewer's pre-execution native statuses are
superseded only by the separate source-bound v2 run above. These
copied-contract tests still report `native_receipt_authenticated=false` and
`gameplay_qualified=false`.

The resulting-head local/hosted ledger and independent final disposition are
recorded in PR #379. The required documentation consistency and source-scope
advisory are separate from future gameplay gates. The advisory is report-only.
Draft-suppressed Native/GDExtension/Water/shader execution is **skipped**, not
passed. The Documentation workflow's materialized-runtime provenance step is
also skipped in draft state; the materialized local check is reported separately.
An eventual implementation PR needs its applicable real platform/host gates.

## Durable handover to the separate Liquid Drain agent

Start the independently authorized #361-A implementation from freshly verified
accepted source. This review neither imports nor edits that agent's work.
Preserve the preparation's original identities as historical evidence and
coordinate shared Main/worker readback with #370 and current PLAY owners.

- Extend physical U10 through its existing equipment identity, action stream,
  worker-exclusive owner and cancellation mutex. Keep current ordinary U10
  defaults/charge/cooldown and locomotion separation intact.
- Meter actual copied before/after stored Water units or separate Brine cells
  in one bounded owner interval. IN Water is a whole cell at actual precision;
  partial FM Water is its actual stored amount. Do not infer dose from slot
  count, a void writer, self-reported digest or a construction receipt.
- Use a distinct opt-in request profile/version and the proposed 16-target
  bound. Register finite per-run removal budget; selection cannot refill it.
  Admit current generation/epoch/instance/sequence/lease/completed-tick values.
- Normal empty, blocked, unsupported, exhausted, stale and cancelled results
  preserve authoritative state and spend no new effect budget. Qualify the
  already-extracted-request cancellation race and duplicate consumption.
  Unexpected partial execution is a terminal owner fault with actual partial
  accounting, never a clean refusal or automatic retry.
- Keep Rapier/main-thread body ownership and current masks. Qualify actual
  Windows/Linux Godot physical-actor behavior, pause/focus/reset/reconstruction,
  equipment charge/cooldown and unchanged Current FM behavior before acceptance.
  Preserve native receipts as native facts and label host-authored tool results
  honestly; this package does not provide a native-issued edit receipt.
- Defer reversible ports and finite geometric sources until that slice passes.
  A later source has zero fresh motion. Strong atomic edits, momentum input,
  adapter/shared-coupling changes or upward spray require their separate
  authorization. Keep #361 open after preparation integration.

**Record progress and stop at owner integration approval.** A later approved
merge still requires a final live base/head check and a source-matched main-tree
verification; do not infer permission from this audit or green checks.
