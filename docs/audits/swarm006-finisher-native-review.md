---
title: SWARM-006 successor native repair and independent Workbench source review
status: Current
document-kind: audit
scope: Dated successor development evidence for bounded native failure finalization and independent Workbench source review; no frozen holdout requalification or platform acceptance
canonical-for: []
last-reviewed: 2026-11-21
related-documents: [../systems/gentek-negotiated-recovery.md, ../operations/swarm006-integration-finisher.md, ../operations/swarm006-workbench-playtest.md]
---

# SWARM-006 successor native repair and Workbench review

This records development evidence on integration commit
`5722f254144fb8bf84a94fa2881e8860c9512316` plus the explicit successor source
changes below. It is not an exact published-HEAD, Windows, NVIDIA, owner-World,
or unseen-holdout qualification. The original donors and scientific results
remain frozen; the successor remains subject to Draft/HOLD gates in the
[integration runbook](../operations/swarm006-integration-finisher.md).

## Reproduced defect and retained failed repair

The native author reproduced all four revealed failures using `foreign_solid`,
`industrial_gui`, seeds `1997581108` and `1376230570`, and `recovery@3` / `@4`.
In each original result, round 3 exhausted MOSAIC receiver work after provisional
mutation. The rejected `proposed_mosaic` retained nested `Complete` and a stale
material digest: `f5bd81d62686f53e` versus actual `1a17166b98c6915e`, or
`9673f8e2bcfd407e` versus actual `94696be794caaf9e`, respectively. Outer
`Exhausted`, denied Apply, empty final composition, and the selected preceding
plan were already fail closed. This was a serialized history defect, not an
observed unauthorized construction.

The first successor attempt, definition
`35e178bd6231965bf801477c8edb4d85625bcdbcd6e0b619752e6a1ccba4543e`,
passed its strict tests but **failed independent science review**: its empty
unexecuted proposal retained six copied receiver receipts referring to missing
proposal parts in each case. The [independent finding](swarm006-finisher/first-repair-failure.json),
raw outputs, exact intermediate source bytes, and development receipts remain
retained. The final delta clears only those unattached proposal receipts and
captures withdrawal-attempt metadata before cleanup can invalidate its iterator.
The previous selected snapshot keeps its own receipts.

## Final bounded repair

Only [mosaic_recovery.cpp](../../native/experiments/gentek_swarm/mosaic_recovery.cpp)
and [swarm006_recovery_tests.cpp](../../native/experiments/gentek_swarm/swarm006_recovery_tests.cpp)
change in the native lane. The compiled definition is
`72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0`.

Before a receiver mutation or withdrawal, the proposal must reserve its existing
finalization charge:

`12 × material-plane cells + 64 × instances + 32 × hard ports`.

This is unspent capacity within the existing MOSAIC generator allowance. Search
debits cannot consume it. Finalization charges the actual cost once to the same
generator, wrapper, recovery, and raster-work accounts. There is no additional
work grant or uncharged finalization. Withdrawal reserves the pre-withdrawal
bound until its material, part, and port updates finish, then releases only the
unused reserve. Accepted candidate work is never refunded.

| Exit family | Retained proposal and charge |
|---|---|
| Invalid input, admission refusal, cancellation, or exhaustion before any admitted mutation | Explicit empty failed proposal, truthful nested status/reason, no proposal receipts, no finalization charge. Already charged search/attempt work stays charged. |
| Search/candidate-reserve failure or cancellation after an admitted mutation | Truthful failed snapshot, finalized once using the protected allowance; cached material/structural metadata describe the actual retained proposal. |
| Invalid rollback or reservation state after mutation | The same funded failure-finalization path; the coordinator keeps the previous accepted selection. |
| Successful modified proposal | One normal finalization using the same formula and existing ceiling. |
| Finalization itself produces unusable geometry | Retain that finalized invalid result; no second finalization or charge. |
| Successful unmodified proposal | Retain the unchanged native result; no new raster finalization. |

Cleanup after a cancellation signal consumes only its already admitted reserve
and does not resume search or authorize Apply. A defensive invariant throws if
an internal path tries to finalize an unfunded snapshot. Existing dimensions,
part/port caps, grammar, alternative order, options, authority, and aggregate
ceilings remain unchanged. Reserving cleanup can refuse a low-budget attempt
earlier and therefore change its attempt history or endpoint. Successor replay
must measure that effect; this repair is not evidence of general endpoint parity.

The four final development replays now refuse before their first round-3
mutation with `budget_exhaustion: native receiver snapshot finalization`.
Their empty proposal has nested `Exhausted`, zero receipts, and zero cached
digests. Both selected native plans remain unchanged. The
[independent four-case review](swarm006-finisher/second-repair-four-case-review.json)
passes all four raw responses, including 17 serialized digest checks per case,
receiver/host/edit-history checks, and the four-account work sum. It does not
reinterpret the old failed bytes as passing evidence.

## Development validation and custody

Raw logs, requests, native responses, source hashes, and JSON receipts are in the
retained `swarm006-evidence/native-dev` evidence root. Relative packet locations
below identify those files; binaries and raw logs are not committed as source.
The immutable development CLI is `v2-cli/gentek_reciprocal`, SHA-256
`1ccd7c579dc247fbc8ccee66ff4b47085974f713506aa7bac7daefb5449d07d1`.
Its label is `5722f254144fb8bf84a94fa2881e8860c9512316+successor-native-v2`.

| Check | Observed result | Receipt or log |
|---|---|---|
| Strict C++20, warnings as errors, reciprocal test target | All eight suites pass; recovery has 19 groups / 870 assertions | `strict-v2/receipt.json`, `native.log` |
| Focused ASan/UBSan recovery target | 19 groups / 870 assertions pass; input source hashes unchanged throughout build/test | `sanitized-v2/receipt.json`, `build.log`, `test.log` |
| Unchanged SWARM-006 Python runner tests | 21 pass, including deliberate header-only refusal and tamper checks | `strict/runner.log` |
| Six legacy suites using exactly the unchanged legacy Makefile source inventory | All compile, link, and pass: base 21 groups, negotiated 8, admission 7, native admission 24, solver 17, resilience 6 | `legacy-v2/receipt.json` and per-suite logs |
| Maximum-dimension stress, three profiles × six controls | 18/18 retained; all deny Apply; source/binary custody revalidated | `stress-v2/manifest.json` |
| Six owner-sized synthetic fixtures × five refusal controls | 30/30 retained; six Cancelled, 24 Exhausted; all deny Apply; custody revalidated | `resource-controls-v2/manifest.json` |
| Exact four revealed failures and reverse invocation in native tests | All pass; separate independent raw-history review also passes | `post-repair-v2-four-cases/receipt.json` and linked review |

The strict command was
`make -C native/experiments/gentek_swarm -f Makefile.reciprocal BUILD=/tmp/swarm006-native-dev-v2 -j2 test`.
The sanitizer build used the same Makefile with
`BUILD=/tmp/swarm006-native-dev-sanitized-v2 SANITIZE=1` and target
`/tmp/swarm006-native-dev-sanitized-v2/test_swarm006_recovery`.
Execution used `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1` and
`UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`.
The earlier attempt recorded LeakSanitizer's explicit ptrace incompatibility;
local leak checking is unqualified. Its source-changing sanitizer attempt is
also retained as nonqualifying. Hosted leak checking remains a separate gate.

The stress controls hit the memory bound before cancellation or the individual
work limits, so those 18 executions establish bounded memory refusal only. The
30 owner-sized controls exercise pre-cancellation and separate FRAME, MOSAIC,
solver, and memory refusals. Neither set proves mid-flight cancellation after
mutation. That cleanup path was independently source-inspected; deterministic
runtime regression covers pre-cancel, exact allowance, one-unit-short allowance,
late search exhaustion after real mutation, and withdrawal exhaustion.

No legacy build-file change was necessary. Its existing objects resolve the
current FRAMEWEAVER dependency on the MOSAIC source receiver probe. The frozen
runner already contains donor `a757ed4`'s deliberate memory-header correction;
it, the registered analyzer, corpus, and experiment harness were not changed.

## Independent source reviews

The Workbench author and science reviewer independently reviewed the native
reserve and receipt-cleanup deltas. They found no remaining source blocker in
funding, exit handling, selected-plan retention, or unchanged V1–V3 entry paths.
The science review found the intermediate dangling-receipt failure above before
the final delta was accepted for evidence qualification.

Conversely, the native author independently inspected the Workbench changes in
[the panel](../../godot/scripts/workbench_reciprocal_panel.gd),
[inspector checks](../../godot/tests/support/workbench_reciprocal_inspector_checks.gd),
[controls regression](../../godot/tests/test_workbench_reciprocal_controls.gd),
and [SWARM-006 lifecycle test](../../godot/tests/test_workbench_swarm006_ui.gd).
There was no blocking source finding. Actual dropdown selection maps final to
`-1` and provisional items by position, with arbitrary item IDs tested. Reset
replaces captured dictionaries, clears stale texture/inspector controls and
Apply authority, and source-manifest refusal retires an earlier positive preview.
Cell picking checks floating-point image bounds before flooring, including
negative fractional letterbox coordinates and non-primary buttons.

The regression helper derives expected pixels from native material planes,
checks actual texture bytes and part provenance for each round, and checks final
joint/unresolved markers at native coordinates. One nonblocking oracle defect
was reported: it initially copied palette alpha although the inspector renders
opaque material cells. The Workbench author corrected the expected alpha to
255. This is independent source review only; graphical execution and packaging
receipts belong to the separate Workbench/platform qualification.

## Remaining claim limits

Diagnostic granularity remains **PARTIAL**: compound native refusal reasons were
not split or tuned. Full revealed successor replay, exact published-source CI,
Windows pristine-stage/native/pixel/pick predicates, and actual owner acceptance
remain separate obligations. The four revealed cases are robustness regression
inputs. They do not become unseen evidence, change the preregistered two-round
primary comparison, or remove the frozen negative result.
