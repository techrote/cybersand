# Bounded CyberSand pattern compiler

This is an implemented, standard-library-only geometry compiler. It produces
canonical local-coordinate Art JSON for the existing CyberSand executor. It
does not mutate a World, authorize cells, synthesize native receipts, or prove
that a rendered output has passed artistic acceptance.

## API and command line

`pattern_compiler.py` exports `THEMES`, `MOTIFS`, `CompilerError`,
`make_program(theme, variant_id=0, modifiers=None)`, `validate_program(program)`,
`structural_signature(program)`, `compile_program(program, width, height, seed,
material=58)`, and `compile_with_report(...)`.

`compile_program` returns an ordered list of native geometry operations.
`compile_with_report` also returns compiler/program identity, focus dimensions,
host seed/material, shape count and estimated cell work. A failure raises
`CompilerError`; it does not return a usable partial prefix.

```sh
python3 controls/pattern_compiler.py --theme roots --seed 17 --width 96 --height 96 --out roots.operations.json
python3 controls/pattern_compiler.py --theme strata --variant 4 --modifier open --seed 19 --report
python3 -m unittest discover -s controls -p 'test_*.py' -v
```

The host must use a temporary file followed by an atomic rename if it saves a
new compiled plan into a path currently consumed by another process. CLI output
is a recipe, not evidence that CyberSand applied it.

## Version 1 program

The exact schema is `pattern_program.schema.json`. One example is:

```json
{"version":1,"theme":"roots","layers":[{"motif":"branch","density":0.57,"scale":0.63,"width":0.58,"angle":0,"layout":"center"}]}
```

Each program has one to four layers, and each layer selects a generic motif,
normalized density/scale/stroke controls, an angle in degrees, and a layout.
Density governs primitive/branch abundance; scale affects motif size or spacing
according to the named motif; width becomes a bounded integer cell width. Angle
rotates within each admitted layout region. It may clip at that region's boundary.
The `theme` label is provenance: **the actual motif program drives geometry**.
Changing the theme string alone does not force the corresponding geometry. An
evaluator must measure theme/program/result agreement independently.

Supported motifs are branch, fan, network, threads, bands, ridges, facets, cells,
maze, blocks, orthogonal, and ribs. They can be combined independently of the
reference theme templates. No generated code, arbitrary recursion or external
resources are accepted.

Layouts are center (full inset field), offset (smaller upper/left mass), split
(a generated left half plus exact horizontal reflection), and border (four
disjoint edge strips preserving a large central void). Split reflections use
`x -> width - 1 - x` on native coordinates; they do not rely on statistically
similar left/right random samples.

## Reference templates and data splits

`make_program` is an explicit deterministic teacher/baseline, not a learned
model. Each of twelve themes has eight nominal template IDs: four layouts with
one motif, then those four layouts with an additional companion motif. Without
modifiers this yields 96 distinct theme-plus-ordered-motif/layout signatures.

Modifiers are sparse, dense, open, twisted, thick, thin, and symmetric. Some
modifiers deliberately alter the structural template: open selects border;
symmetric selects exact split on every layer. Consequently **nominal variant
IDs are not safe split keys**. Group by `structural_signature(program)` after
modifiers and before paraphrase/seed expansion. For simultaneous open/symmetric,
the explicit symmetric layout takes precedence and retains its central gap;
it does not promise the larger border-layout hole. Conflicting sparse/dense or
thick/thin and duplicate/unknown modifiers are rejected.

These are template/layout holdouts, not unseen-primitive or unrestricted drawing
generalization. All conditions use the same compiler. The model's useful
contribution must be measured on language, controls and composition.

## Host bounds and native contract

The host supplies integer width/height (16..512), a seed (0..2^63-1), and the
verified initial material 0 or 58. The model program cannot supply those fields.
Operations are canonical integer rectangles, lines, polylines, filled polygons
and discs. Rectangle endpoints are inclusive. Stroke endpoints are inset to
keep their rounded-width envelope inside the local focus. Degenerate polygons
are discarded. Exact duplicate operations are removed without changing the
remaining operation order.

The complete plan is preflighted against at most 2,048 shapes and 131,072
estimated cell-work units; callers may lower these limits. The estimate is a
conservative geometric work bound, **not a native receipt, changed-cell count,
save-size prediction, or guarantee that shared Undo history has spare capacity**.
Polygons use bounding-box area; thick paths use a conservative swept-envelope
bound. The native executor must still enforce its current canvas, protected
region/body masks, source material policy, epoch/revision, Stop, history and
persistence capacities. This module cannot widen those permissions.

For a pinned compiler, program, focus and seed, canonical operations are
reproducible across fresh Python processes. The generator uses separate seeded
substreams per layer/region. Reproducibility of the actual World and image still
requires matching native source/runtime and starting state.

## Verification boundary

`test_pattern_compiler.py` checks all 12 themes × 8 templates × five pilot
sizes/aspects, process-restart determinism, seeded variation, exact reflection,
large central void preservation, density direction, host budgets, material
authority and malformed/unhashable/non-finite/huge numeric values. Those checks
are compiler tests. Native replay, readback, Save/Undo/Stop and actual renders
are separate qualification evidence produced by the experiment's native harness.

## Opt-in coral spread candidate — compiler 1.1 (13 November 2026)

`pattern_compiler_v11.py` is a **separately identified, non-default candidate**
addressing an observed visual defect: v1 coral/fan colonies all originate from
roughly the lowest 28% of the field, crowding the bottom and leaving the upper
field empty. The candidate distributes fan-colony origins on an aspect-aware
row/column grid across the admitted field. Narrow border regions use a
proportionate grid while the original border clipping retains the empty center.
All other motif generation, source permissions, seed/focus/material ownership,
budget bounds and native authorization remain delegated to frozen v1.

The wrapper first hashes its sibling `pattern_compiler.py` and refuses a
different source than the **admitted v1 SHA-256**
`a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb`.
It loads that source in a **private module**, not the shared Python module, and
only replaces the `fan` generator. It retains v1 seeded substreams for every
motif; non-fan geometry is required to be exactly identical. Compiler reports
carry `wb-art-slm-001/1.1.0-coral-spread` plus the parent source hash.

From repository root:

```sh
python3 experiments/wb-art-slm-001/controls/pattern_compiler_v11.py \
  --theme coral --variant 0 --width 96 --height 96 --seed 17 --report
python3 -m unittest discover -s experiments/wb-art-slm-001/controls \
  -p 'test_pattern_compiler*.py' -v
```

**Qualification status: candidate only.** The six added regression methods
check the frozen source, non-fan parity, upper/lower origin coverage, 80
variant/size/seed combinations, local bounds and budgets, border holes, exact
split reflection and repeatability across processes. Local syntax compilation
passed, and an isolated fan-algorithm smoke on a 96×96 region produced source
stem Y positions 18, 22, 50, 54 and 85; this is **not** full compiler or
native execution. The full regressions require the exact v1 source checkout,
and actual current-source native before/after replay, readback, Undo/Redo and
save/reopen remain pending. No new native receipt or human acceptance is claimed.

The step-400 LFM adapter and Integration's opt-in content-JSON bridge pin the
**original** compiler file digest. They must continue using v1 until an
explicitly versioned adapter/receipt contract and new qualified native
gallery admit v1.1. Do not change an admitted corpus geometry hash, silently
repoint the provider alias, rewrite old native evidence or treat a Python
geometry metric as an artistic recognition score. Pair v1 and v1.1 in fresh
identically seeded native Worlds, with case IDs at most 38 characters (for
example `c10-coral-s17` / `c11-coral-s17`), and retain original-prediction
aliases if matching any model examples.

### Matched native replay handoff

A bounded fixture builder is included so Evaluation can compare the same
**eight coral structural templates at two identical seeds** under v1 and v1.1
without guessing saved-start names. It produces **32 uniquely named cases
and 16 reference-ID alias pairs**:

```sh
python3 experiments/wb-art-slm-001/controls/make_v11_native_pairs.py \
  --out /private/new-coral-pairs.json
```

The file embeds each exact program hash and canonical operation hash, refuses an
existing output path and records short IDs satisfying the frozen native harness'
38-character requirement. It is **not a native receipt**; pass it to the
existing pinned replay harness, verify all global gates, compare native material
readbacks and inspect both image sets before acceptance. The pairing is for
deterministic *reference* programs, not new model predictions. For model
predictions, separately preserve the original raw completion-to-ID alias map.


### Original native coral occupancy — independently quantified (13 November, second Controls checkpoint)

The first Controls checkpoint introduced the non-default v1.1 spread algorithm but
did not execute it natively. To replace a qualitative claim with a reproducible
**measured baseline**, this checkpoint recovered the 29,081,943-byte preserved
`wb_art_slm_001_native_and_model_evidence.zip` from the owner Library; verified
the bundle SHA-256 `d2f8b16f081b7c371afd2eadf1468bc6941cb2a7a83ee349a11d667257f9cfa9`;
extracted original `native/teacher-evidence.zip`, digest
`2381736839bfca8ad6b4563a1c77698140438ef39ee8f0a6529f23cae4f1f62b`;
and examined 16 original v1 coral native World material readbacks: variants
0–7 at seeds 17 and 73. The new
[`audit_coral_native.py`](audit_coral_native.py) checks the exact parent
archive, all 15 native global gates, source/library pins, actual engine summary,
operation hashes, native crop and PNG hashes, acknowledged cells and changed-cell
counts. It reads real stored material ID 58 rather than rendering an approximate
Python pattern. It refuses tampered archives and only writes a new report.

**Observed result:** all **six** single-layer center/offset/split reference cases
(variants 0, 1, 2, each at two seeds) have **zero Hard Wall cells in the top
third** of their 96×96 World crop. Including the four intentional border layouts
and the companion motif cases, the mean share of all material-58 cells situated
in that top third is **0.104738** across all 16 cases. Border examples
intentionally occupy the top edge; their higher upper-field fractions are
preserved rather than excluded post hoc.
The auditable case-by-case counts and artifact identities are in
[`coral_native_v1_baseline.json`](coral_native_v1_baseline.json).
The full per-case readback hashes, vertical coverage and operation hashes are
reproducible from the exact archived evidence using the auditor.

To reproduce with the owner's separately saved archive, in a private directory:

```sh
unzip -p /private/wb_art_slm_001_native_and_model_evidence.zip \
  native/teacher-evidence.zip > /private/teacher-evidence.zip
python3 experiments/wb-art-slm-001/controls/audit_coral_native.py \
  --teacher-zip /private/teacher-evidence.zip \
  --out /private/new-coral-native-v1-report.json
WB_ART_SLM_TEACHER_ARCHIVE=/private/teacher-evidence.zip \
  python3 -m unittest discover -s experiments/wb-art-slm-001/controls \
  -p 'test_audit_coral_native.py' -v
```

**Executed locally:** the three focused tests passed against the recovered
actual archive, including the forged-evidence refusal. The auditor and test
files were also syntax-compiled. This is a *new native evidence analysis* of
original v1, **not a new native execution** of v1.1, current main or Windows.

The paired native fixture now explicitly records
`"required_native_history_mode": "each"`. Use
`--history each` when executing the 32 paired cases: the native runner's
default `per-theme` probes Undo/Redo/save/reopen for only the first coral
case, which would fail to independently qualify the v1.1 half of each pair.
Run fresh identically seeded Worlds with the same compatible native build;
verify receipts and image/readback equality where expected, inspect v1.1
gallery outputs, and retain all failures. Until that happens, the baseline
documents an actual defect, **not an established v1.1 improvement**.


## Strict native v1/v1.1 paired admission — 13 November 2026

`audit_v11_native_pairs.py` is the **fail-closed post-run auditor** for the
32-case `make_v11_native_pairs.py` fixture. It does not draw pixels,
synthesize World readbacks, or confer success on a compiler-only result.
First run the unmodified native replay with `--history each`; then run the
independent `evaluation/verify_native_replay.py` against its entire output
directory. Only a globally passing `verified-admission-receipts.json` can
enter the pair auditor.

The auditor enforces exact 32/16 fixture and alias coverage; source/native
hash pins; unchanged run input/custody, process and native receipt hashes; all
15 original global native gates; identical paired program/seed; separate
compiler and operation identities; per-case native completion and
Undo/Redo/save/reopen checks (rather than one per theme); bounded/canonical
local evidence paths; native readback and PNG hashes; material 0/58 and
filled-cell closure. It reports each case's **actual stored-material**
top/middle/bottom cell counts and upper-third share, with 16 paired deltas.
A positive spatial delta is *not* automatic visual or human admission.

From repository root, using a separately pinned qualified Workbench runtime,
an exact `v11-pairs.json` created without overwriting past inputs, and the
**source-matched** native runner/verifier:

```sh
python3 experiments/wb-art-slm-001/controls/make_v11_native_pairs.py --out v11-pairs.json
# Execute through the pinned native replay runner with --history each.
# Independently verify the whole native output before the following command:
python3 experiments/wb-art-slm-001/controls/audit_v11_native_pairs.py \
  --pairs v11-pairs.json --native /path/to/verified-native-output \
  --source-sha EXACT_40_HEX --native-sha EXACT_64_HEX \
  --out native-v11-spatial-result.json
python3 -m unittest discover -s experiments/wb-art-slm-001/controls \
  -p 'test_audit_v11_native_pairs.py' -v
```

The original `evaluation/run_native_replay.py` and verifier are still pinned to
the historical Linux pilot; they cannot be relabelled to qualify current main
or Windows. A compatible independently qualified #564/#565 successor requires
source-matched runner/verifier custody from Integration/Evaluation.

Seven **synthetic contract** tests passed locally on Python 3 (structural
fixture, tampered readback, mutated input, missing Stop gate, history omission,
bad source identity and path traversal). These are not executed native cases.
The compiler's version-1.1 candidate passed 6/6 focused tests, alongside
12/12 frozen v1 tests, in the Integration offline Linux CI run
[43369954009](https://github.com/techrote/cybersand/actions/runs/43369954009)
on 13 November; that overall run nevertheless **failed** in the separate
Training job-guard suite because `filelock` was not installed. No claim that
the complete run passed is made.

**HOLD:** No new v1.1 native paired run, per-case readback, Windows qualification
or reviewed visual improvement has been established. Step-400 inference and
the existing opt-in bridge remain pinned to admitted v1 geometry.


### Raw native receipt-chain verification — 13 November 2026

The 32-case pair auditor now replays every original native before/after cell
receipt against a fresh 512×512 byte-valued World, rather than accepting a
positive independent-verifier JSON without checking the raw event chain. It
requires complete zero-tick CyberNativeCellWorld receipts, an internally
continuous material transition, exact native changed/checked/unchanged
counters, captured full-World SHA-256, and an exact stored 96×96 material crop.
A forged passing-looking verifier/summary with missing or contradictory raw
rows is refused. This *does not replace* the independent verifier's protection,
Stop, PNG or history gates and is not cryptographic attestation of a native run.

Four additional synthetic adversarial regression methods now cover absent raw
receipts, falsified before-state, falsified whole-World hash and falsified
changed-cell count, even when the corresponding recorded file digest is
recomputed. The previous positive synthetic fixture now contains complete,
consistent one-cell receipts and captures. Synthetic tests are contracts,
**not actual Godot World evidence**. The new code has not yet run through
source-matched CI. A local two-position byte-order/crop reconstruction smoke
passed; complete Python/CI/native qualification is still pending. The unchanged
v1.1 compiler identity and adapter remain unpromoted.


### Receipt diagnostic and four-phase native history custody — 13 November 2026, 08:12 UTC

The 06:12 test-execution status above is retained as a historical checkpoint.
[Current Controls checkpoint](CHECKPOINT_2026-11-13-0812.md) records the later
exact-source result: the crop-tamper test was corrected to assert the actual
fail-closed `stored native crop disagrees with receipt chain` diagnostic; all
**11 original synthetic auditor tests passed** locally.

The post-run auditor additionally checks all four ordered full-World native
capture witnesses emitted by the frozen `--history each` replay protocol:
draw material hash, empty Undo hash, restored Redo hash, identical save/reopen
hash. Each witness must carry the native backend, completed status and
512×512 region. The complete suite now has **13/13 passing synthetic contract
tests** on source-identical Python 3.13.5, including forged Undo and missing
reopen captures. The v1/v1.1 paired native run is still **not executed** and
no native, Windows or visual improvement is claimed.


### Draw/history chronology gate — 13 November 2026, next Controls checkpoint

The [ordered-receipt checkpoint](CHECKPOINT_2026-11-13-0912.md) strengthens the
synthetic native evidence auditor further. In the frozen replay harness,
completed draw receipts precede the full-World draw capture and subsequent
Undo, Redo and save/reopen captures. The auditor now rejects any history
capture preceding the first draw receipt, and any additional draw receipt
after the first history capture—even if the attacker recomputes JSONL hashes.
Two new adversarial tests cover both reorderings. **15 methods are defined**;
the previous 13/13 passing source is qualified separately. The two new tests
have only isolated ordering smoke verification, not an exact-source combined
CI run or actual native replay. The opt-in v1.1 compiler and historical v1
program/operation hashes remain unchanged; native and Windows acceptance stay
HOLD.


### Complete native-case stream order — 13 November 2026

[Controls case-order checkpoint](CHECKPOINT_2026-11-13-CASE-ORDER.md) adds a
further admission invariant drawn directly from the frozen replay harness:
mandatory protection and Stop events precede the pattern cases, which execute
one-by-one in manifest order. The auditor refuses an unregistered case,
an invariant emitted after the first pattern case, a reversed invariant
prefix, or a later pattern-case block moved before an earlier one. Previously
admitted per-case history and raw material checks remain unchanged.

Five added synthetic test methods include positive invariant-prefix coverage;
**20 methods are defined** overall. Seven isolated order-logic smoke checks
passed, but the new complete source suite, true v1/v1.1 native execution and
visual/Windows assessment still require independent qualification. The
11-test error-diagnostic repair is already accepted by Integration's later
green model-free CI; it must not be reintroduced.

### Rooted coral v1.2 (experimental; compiler-only preview)

[New 13 November checkpoint](CHECKPOINT_2026-11-13-ROOTED-CORAL-V12.md) records an executed visual design comparison. The earlier v1.1 spread distributes coral colonies vertically but may fragment continuous reef silhouettes. The separate **non-default** `pattern_compiler_v12.py` preserves its original fan-colony strokes and adds a bounded, same-region spanning/rooting skeleton. Frozen v1 corpus and source, existing v1.1 source, training adapter and Workbench provider defaults are unchanged.

Locally executed source-identical v1.2 code/tests passed **6/6 Python 3.13.5 compiler regressions**. A new `make_v12_native_triplets.py` generated **48 immutable-input native cases** (v1/v1.1/v1.2 × eight coral variants × two seeds), SHA-256 `a24eb4ce7e9ddf6949afe3a46d2778e1e216b00d5f5726fca12c73bd7a332a4e`. On an appropriate source-compatible native checkout, run:

```sh
cd experiments/wb-art-slm-001/controls
python -m unittest test_pattern_compiler_v12 -v
python make_v12_native_triplets.py --out /private/new/native-coral-48.json --aliases-out /private/new/coral-48-aliases.json
# From the parent experiment root (as appropriate to the exact runner):
python ../evaluation/run_native_replay.py --runtime /private/pinned-native-checkout --godot /private/pinned-Godot-4.7 --cases /private/new/native-coral-48.json --output /private/new/coral-48-world --workers 1 --history each --timeout 2400
```

The output is a **replay input**, not a native receipt or rendered World. Only the original v1 material captures have actually been recovered and verified in this checkpoint. v1.1/v1.2 side-by-side compiler previews are approximate and must not be substituted for genuine native tests, blinded quality review or current-main/Windows qualification. Native v1.1/v1.2 and trained-model performance remain HOLD.
