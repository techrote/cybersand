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
