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
