# WB-ART-SLM-001 bootstrap evidence

Date: 13 November 2026. This checkpoint implements the bounded compiler, an
executed corpus, a qualified native teacher gallery and the actual local training
pipeline. **The bounded adapter run is in progress at this source checkpoint.**
No completed-adapter or production qualification is inferred from that state.

## Implemented controller

The strict version-1 program schema has a theme plus one to four generic motif
layers. Each layer chooses motif, density, scale, width, angle and layout.
The host owns seed, focus dimensions, material and expansion budgets. The
compiler emits canonical local-coordinate rectangle, line, polyline, polygon
and disc operations for the existing Art planner/executor.

Twelve reference words work: roots, coral, veins, mycelium, strata, dunes,
crystals, honeycomb, labyrinth, ruins, circuitry and ribs. The compiler includes
true mirrored split layouts and border layouts with an empty center. It refuses
unknown fields, nonfinite or enormous numeric inputs, unsupported materials and
over-budget expansion before returning a partial plan.

Compiler source SHA-256:
`a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb`.
Twelve compiler regressions passed, including 480 theme/template/focus-size
combinations, fresh-process determinism, seed variation, density direction,
reflection, central voids and adversarial refusals.

## Executed corpus

| Split | Text examples | Structural groups |
| --- | ---: | ---: |
| Training | 1,152 | 72 |
| Development | 192 | 12 |
| Final assessment | 192 | 12 |

There are 768 distinct exact program/seed targets, each with two prompt forms.
An additional 96 seeds complete the 192-image teacher atlas, for 864 native cases.
All 1,536 text examples were admitted after successful native replay and explicit
representative visual review. The admission manifest records exact train/dev/final
hashes; zero cases were silently dropped. Final examples remain outside model
training and development evaluation.

Groups use actual theme and ordered motif/layout signatures, rather than nominal
variant IDs. Independent review found no cross-split structural, canonical
program, operation-hash or normalized-prompt collisions. This is a limited
template/layout holdout: all compiler primitives are shared. Seed counts and
text paraphrases are not independent unseen structural families.

The admission implementation now recomputes the completion-to-program-to-geometry
chain, validates host context and exact source/corpus hashes, and requires all
global native gates. Every visually reviewed group representative needs its own
successful matching native receipt. Fifteen corpus tests include deliberate
tampering, false native success, missing representative evidence, zero-work
results and leakage; all passed.

The actual pinned LFM tokenizer was checked against all candidate targets:
maximum sequence length 348 tokens, maximum supervised target 87 tokens, exact
prompt/completion boundaries and one supervised EOS per target. PAD=EOS does not
remove the real completion terminator. No training target is silently truncated.

## Native gallery and qualification

| Measurement | Executed result |
| --- | ---: |
| Native teacher cases | 864 / 864 passed |
| Curated atlas images | 192 |
| Engine assertions in full campaign | 14,288 passed |
| Independent native receipt/readback assertions | 4,572,506 passed |
| Acknowledged native cell visits | 1,518,630 |
| Actual changed cells, summed over fresh Worlds | 1,170,966 |
| Out-of-focus changed cells | 0 observed |
| Unexpected material cells | 0 observed |
| Full-campaign Undo/Redo/save/reopen representatives | 12 / 12 |
| Repeated pilot cases with exact operation/readback/PNG equality | 32 / 32 |
| Evidence-reader adverse controls | 14 / 14 passed |
| Packet-merge controls | 3 / 3 passed |

The original mounted Art suite passed 145 checks. The initial 32-case pilot
passed 1,234 engine assertions, with Undo/Redo/save/reopen on every case. The
full campaign ran as three independent one-worker packets, each completing in
approximately 451–453 seconds. The independent reducer reconstructs cells from
actual native before/after rows and compares them with separate full-world
capture hashes, raw material crops and both numeric and display PNGs. Protection,
Stop/no-late-write, process completion and source/runtime/input custody are
global admission gates.

The teacher gallery has 192 distinct raw readbacks. This is a reproducibility
and diversity diagnostic, not an artistic score. The assistant viewed all 192
images. Coral defaults crowd the lower canvas; narrow border strips compress
several motifs; companion layers can be decorative framing. These limitations
are preserved in the visual-review file. No blind human recognition rate or
human aesthetic acceptance is claimed.

The images are produced by Godot from actual native stored material IDs. They
are material-readback visualizations, not desktop screenshots. Original PNGs
are retained; contact sheets only enlarge them with nearest-neighbor sampling.
The self-contained [native atlas](gallery/native_atlas.html) embeds image bytes
with verified hashes and preserves per-case program and receipt metadata.

## Source and platform identity

| Component | Identity |
| --- | --- |
| Experiment branch base | `63f8b1ba6559906fe85f3ad0269aa296e4141d67` |
| Isolated native pilot source | `90719c72b9fcf90593fb7878354051ad601b47fd` |
| Native library SHA-256 | `3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd` |
| Rapier library SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Official Godot ZIP SHA-256 | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Native publication run / artifact | `43334477644` / `13999396092` |
| Original runtime artifact ZIP SHA-256 | `6ca3266605d06e4cb0773eb105ab27442219baf23eec4d9a15468bc0091c398a` |

The older Art-bearing runtime is a separately pinned Linux headless pilot. It
does not qualify accepted main's newer capability consumer, Windows, graphical
framebuffer presentation, production physics or human acceptance. The experiment
source retains accepted main; it does not merge the old runtime source over it.
No existing model alias, material law, production default or NeuroRunner NCR
experiment is changed.

One strengthened evidence-reader attempt was rejected because it compared the
different Godot CLI and Engine API version strings literally. The failed reader
result is retained. Its corrected successor checks both exact forms separately;
the native execution did not fail.

## Actual model run and comparison

The executed first candidate is **LiquidAI/LFM2.5-350M**, pinned at
`9921cd4d82c0e3986887aa4b376f9446729ef8a3`. CPU FP32 preflight loaded
354,483,968 base parameters and generated a simple JSON response. No reachable
GPU was established. The actual run uses 5,996,544 LoRA parameters, rank 16,
alpha 32, dropout 0.05, completion-only supervision and three CPU threads.

The untuned baseline completed 24 fixed, balanced development requests, two per
theme, using greedy unconstrained decoding and no repair. It produced **0/24
strict JSON programs**, with 4,792 output tokens in 317.88 seconds. This is a
measurement of this prompt/schema/backend, not a general model capability claim.
The literal-keyword reference is a separate declared baseline, not a replacement
for failed model output.

The first training segment completed 26 steps and preserved a step 25 full
checkpoint. The fresh-process 25→26 continuation matched the uninterrupted result
exactly for adapter and optimizer tensors, scheduler/scaler, Python/NumPy/Torch
RNG, sample cursor, loss and gradient norm. Frozen base bytes remained unchanged.
Peak RSS was approximately 3.64 GiB. The bounded continuation toward 400 steps is
running at roughly 2.6–2.9 seconds per example on three CPU threads; its quality
results are still pending.

The lineup includes separately pinned Sprocket-500M root Instruct and Chat,
SmolLM2-135M-Instruct, optional SmolLM2-360M-Instruct, and the larger LFM3-1.7B
accelerator candidate. Profiles and downloads are distinguished from executed
comparisons; an LFM adapter cannot establish a family ranking against untuned
Sprocket or SmolLM. See [training](training/README.md) for actual commands.

## Continuing work

The next checkpoint records the actual adapter, exact resume evidence, matched
development/keyword predictions and native replays of accepted model output.
The five hourly workers consume the implemented source and artifacts, preserving
user pauses and one Training owner. They should improve measured failures,
qualify the current-main/Windows seam and compare model adaptation under matched
budgets. They must not turn native teacher success into a model or production
acceptance claim, restart unchanged training, or rewrite earlier failed evidence.
