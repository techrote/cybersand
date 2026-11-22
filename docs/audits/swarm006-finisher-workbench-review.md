---
title: SWARM-006 successor Workbench qualification and independent native review
status: Current
document-kind: audit
scope: Dated development evidence for actual Workbench inspector and transaction regressions, plus independent source review of native failure finalization; no graphical platform or research acceptance
canonical-for: []
last-reviewed: 2026-11-21
related-documents: [../systems/gentek-negotiated-recovery.md, ../architecture/experimental-workbench-authoring-patch.md, ../operations/swarm006-integration-finisher.md, swarm006-finisher-native-review.md]
---

# SWARM-006 Workbench qualification and independent native review

The final successor development source passed the focused Workbench checks
below. Independent review found no remaining blocker in the native finalization
reserve or empty-refusal receipt cleanup. These are development results on
integration commit `5722f254144fb8bf84a94fa2881e8860c9512316` plus explicit
successor changes. Draft/HOLD, exact published-source platform qualification,
and owner acceptance remain governed by the
[integration runbook](../operations/swarm006-integration-finisher.md).

## Workbench repairs and actual control coverage

The integrated inspector repair uses the selected item's position: index zero
means final composition (`-1`), and each later index maps to native round
`index - 1`. Godot's `OptionButton.add_item` treats a negative ID as automatic
assignment, so an item ID cannot serve as that sentinel. The successor retains
this mapping and exercises it with deliberately unrelated positive item IDs in
the mounted Workbench.

The [panel](../../godot/scripts/workbench_reciprocal_panel.gd) now retires old
Apply authority before checking a fresh runtime manifest. A shared reset clears
the old preview, native document, inspector text and prepared proposal, selects
the final item, and disables empty controls. It replaces dictionaries rather
than clearing a dictionary still captured by a decoder thread. Source changes,
failed positive child processes, decode failures and corrupt saved evidence
cannot leave a usable stale proposal. Cell picking checks the floating-point
image rectangle before converting coordinates to integers, and ignores
non-primary buttons; fractional letterbox coordinates cannot select edge cells.

The [actual-control helper](../../godot/tests/support/workbench_reciprocal_inspector_checks.gd)
emits the mounted round/layer and preview input signals. For final composition
and every provisional round, it compares every Materials texture byte with the
corresponding native plane and checks picked materials and part provenance.
Joints and Unresolved additionally check marker pixels at native evidence
coordinates. Revisions and Clearance check correct final-only enablement and
successful rendering; they do not have separate full pixel oracles. Independent
native review caught an initial test-oracle alpha mismatch; the expected
Materials alpha is now explicitly 255, matching the renderer.

The [protocol](../../godot/scripts/workbench_reciprocal_protocol.gd) requires
current definition
`72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0`
for new authority. The original donor SWARM-006 definition remains explicitly
inspectable as historical V4/schema-6 evidence, with no current generation
authority. The controls regression generates actual V1, V2, V3 and V4 native
responses and checks the same round/pixel/pick behavior for each.

## Final development execution and retained evidence

The final tests used official Godot 4.7, the integrated GDExtension, pinned
Rapier, and immutable development CLI SHA-256
`1ccd7c579dc247fbc8ccee66ff4b47085974f713506aa7bac7daefb5449d07d1`.
The CLI source label is
`5722f254144fb8bf84a94fa2881e8860c9512316+successor-native-v2`.
The local native build uses GCC 14.2/binutils 2.44, which is explicit drift from
the pinned hosted toolchain. All executions here used Linux headless mode.

Paths in this table are relative to the retained
`swarm006-evidence/workbench-dev` evidence packet.

| Final-definition check | Observed result | Evidence |
|---|---|---|
| Protocol and historical-definition refusal | 212 assertions, zero failures | `protocol-v2.log` |
| Actual Workbench V1–V4 controls and native inspector | 280 assertions, zero failures | `controls-v2.log`, `final-controls-tests.json` |
| Industrial recovery ON: generate, inspect, Apply, Undo, regenerate, Save, source/evidence refusals | 271 assertions, zero failures; native Apply allowed, 5 joints, 5,832 constructed cells | `ui-v2-attempt3-swarm006_industrial_on/evaluate.json` |
| Separate-process reopen of the saved construction and evidence | 67 assertions, zero failures | `ui-v2-attempt3-swarm006_industrial_on/reopen.json` |
| Industrial recovery OFF: blocked native preview and inspector | 103 assertions, zero failures; Apply denied | `ui-v2-attempt3-swarm006_industrial_off/evaluate.json` |
| Independent raw-plane and native-response readback | Pass | `independent-final-v2-readback.json`, `readback_workbench_native_v2.py` |

The initial, regenerated and reopened inspector receipts all pass their six
predicates and cover native rounds `[-1, 0, 1, 2, -1]`; the negative initial
preview does too. The positive workflow proves refusal of a changed World,
corrupt saved evidence, a failed child returning positive bytes, a pre-existing
job directory and a changed runtime manifest. Refusals preserve native World
and authoring history. Saved evidence inspection restores final selection but
does not create fresh Apply authority.

Independent readback compares each full 2,048 × 2,048 material plane
(8,388,608 bytes): preview and Undo equal the baseline, while Apply,
regeneration, Save and fresh-process reopen equal the expected construction.
A separately reconstructed overlay of the raw native result's 5,832 nonzero
cells matches that expected plane. Recipe, native receipt, proposal digest and
CLI/source identity also match across the two distinct process IDs.

Failed attempts remain retained. Attempt 1 exposed a test synchronization gap:
the changed-World probe waited for the panel but not the ordinary brush queue;
the native capture correctly refused while that queue was busy. The test now
waits for native paint completion. Attempt 2 contains the subsequent GDScript
continuation parse error. Their raw logs and exact test source snapshots remain
under `failed-ui-attempt1-source`, `failed-ui-attempt2-source` and the earlier
`ui-v2-*` evidence directories. They are not counted as passing runs.

Final production source SHA-256 values are
`f14d6be1bb14687272dd9c8d1474a408db44e4efded7385cb9c306403995cd61`
for the panel and
`2681ddbc986c3728b8a0ff670c39a20affe00d6ad3104409a391fa0e35d5e186`
for the protocol. `ui-v2-attempt3-tests.json` records the exact test/helper
hashes, commands, timeouts, process outcomes and CLI identity.

## Independent review of the native successor

The Workbench author did not author or edit the native repair. The reviewed
[mosaic_recovery.cpp](../../native/experiments/gentek_swarm/mosaic_recovery.cpp)
SHA-256 is
`ec9dbe6dd227b7b376763961c51b12b94ff7cb143f43e4999d3a6e2eec678850`;
the reviewed [recovery tests](../../native/experiments/gentek_swarm/swarm006_recovery_tests.cpp)
SHA-256 is
`f099a2841fdb78f5bbadfd418719a7ec04f7bf7cebfed776a85fcf3d2418ffc9`.

The reserve protects the existing finalization cost
`12 × cells + 64 × instances + 32 × hard ports` before native mutation.
Search debits preserve that allowance; subtraction short-circuits before
underflow. Finalization charges the actual cost exactly once to the existing
generator/wrapper/recovery/raster accounts. Withdrawal keeps the
pre-withdrawal bound until edits finish, then releases only unused reserve.
There is no work refund, larger ceiling, grammar change or new authority.
Existing input dimensions and part/port bounds keep the cost arithmetic finite.

An unfunded proposal before mutation now has an explicit empty failed header.
A failure after admitted mutation uses its reserved allowance to finalize the
truthful failed snapshot. The coordinator retains the selected preceding plans
when a proposal is exhausted or cancelled. The changed function remains behind
negotiated recovery; V1–V3 entry paths are unchanged. Reserving cleanup can
cause earlier refusal and different histories at tight budgets, so endpoint
parity is not inferred.

The first repair retained copied receiver receipts on an empty refused plane.
Independent science review found this defect after the initial source review;
that source review did not establish receipt consistency. The final delta
clears those unattached proposal receipts while preserving prior selected
snapshots, and captures withdrawal metadata before cleanup can invalidate the
iterator. New regressions cover the pre-withdrawal refusal and the four
revealed failures. Both failed and corrected native attempts remain retained.

Independent readback rehashed all four corrected raw responses, checked 72
nested material digests or empty headers (including original FRAME core), and
verified unchanged selected plans, empty refused proposal/receipt consistency,
four-account work totals and existing caps. The native author's retained
strict-eight-suite and focused ASan/UBSan receipts also pass; those executions
were reviewed rather than rerun by this reviewer. The new source/runtime
evidence supports the bounded repair. Mid-flight cancellation cleanup remains
source-inspected; deterministic cancellation coverage is pre-admission.

## Claim limits

These checks exercise real mounted Workbench controls, native transactions and
persisted material bytes. Headless texture checks are not visible desktop
captures. Four new inspector screenshot requirements are present in the
graphical qualification path, but this evidence does not satisfy Windows,
NVIDIA, pristine installed-package or owner visual gates. Earlier adapter and
controller runs (127 and 33 assertions) preceded the final native definition
and are supporting development evidence only.

No owner World or unseen cohort was tested in this lane. The Industrial ON
construction is a transaction/inspector fixture; its report retains
`reciprocal_programme_acceptance = false` and owner acceptance pending. The
four native cases are revealed robustness regressions. Existing scientific
negative findings, preregistered primary comparison and diagnostic granularity
limits remain in force.

## Evidence-checker addendum

Independent science review found a separate Python consumer gap: a report could
claim Complete, eight joints and one inspected round while its correctly hashed
native JSON contained Blocked, no joints and three rounds. The original checker
bound artifact bytes, source and Apply permission without comparing that
metadata. Rehashed contradiction tests reproduced the false pass before repair;
`qualifier-semantic-before.log` retains those failures.

The [corrected checker](../../tools/swarm006/qualify_workbench.py) derives status,
diagnostics, work metadata, material/joint/obligation counts, foreign closure
counts and per-owner occupancy changes from the retained native arrays. Each
initial and regenerated inspector stage must cover exactly those raw rounds.
Reopen is additionally bound to the hash-verified regenerated document saved by
the create/evaluate process. Malformed structures produce explicit failures.
This checks evidence consistency; physical joint authority remains with C++ and
Protocol. Empty exhausted obligation arrays retain the existing UI witness
formula, while the Python summary records `closure_evaluated: false` and
`remaining: null`. Native Apply requires Complete and evaluated zero remaining
requirements. Native joints and original foreign obligations remain separate
counts, including valid zero-original-obligation fixtures.

All **21 adversarial qualifier tests pass**, including recomputed-hash status,
joint, obligation, footprint and round-count substitutions, malformed data,
and reopened metadata/count mismatches. The unchanged actual ON initial,
regenerated and reopened evidence, and OFF initial evidence, pass the corrected
semantic checks. `qualifier-semantic-real-v2.json` records their unchanged report
hashes and explicitly keeps Windows automated qualification false; the only UI
report gate failure is the expected headless/Linux platform restriction, and
graphical capture requirements remain unsatisfied. Independent science review
confirmed the contradiction now fails and the actual metadata remains valid.

Final checker SHA-256 is
`52e69a858ab9857236dbec93acf0023b78f67f0513c7138a985c32e63df178e8`;
its [tests](../../tools/swarm006/test_qualify_workbench.py) are
`595daecad702f75d60127930c4cf53edf9d65da668c33ddfa6863106eb12ec03`.
The final unit log is `qualifier-semantic-final.log`; the retained real-evidence
readback script is `check_qualifier_semantics.py`, both in the same Workbench
development packet. No Godot or native source changed for this repair.
