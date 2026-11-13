# CyberSand pattern-controller bootstrap

A small model chooses a compact pattern program. A deterministic compiler turns
that program and a host seed into bounded Art geometry. CyberSand's existing
native planner/executor remains responsible for cell writes, protection, Stop,
acknowledgements, shared history and persistence.

The initial vocabulary is **roots, coral, veins, mycelium, strata, dunes,
crystals, honeycomb, labyrinth, ruins, circuitry and ribs**. The reference
controller already supports these twelve literal words, plus density, stroke,
twist, symmetry, an open center and companion layers. Learning is evaluated on
paraphrases and combinations, rather than being credited for a dictionary lookup.

The completed bootstrap includes a genuine **400-step LFM2.5-350M LoRA**,
1,536 admitted corpus records and a **260-image native atlas**. The adapter
accepted 22/24 sampled development requests; all 34 accepted development and
keyword programs passed native replay at two seeds. Detailed semantic failures
and the production HOLD remain explicit in the report.

## Start here

| Deliverable | Location |
| --- | --- |
| Actual results, limits and source identities | [Bootstrap report](BOOTSTRAP_REPORT.md) |
| Native images and interactive local atlas | [Gallery](gallery/README.md), [self-contained atlas](gallery/native_atlas.html) |
| Bounded compiler and strict schema | [Controls](controls/README.md) |
| Corpus generation and native admission | [Corpus](corpus/README.md) |
| Training, inference, model lineup and resume | [Training](training/README.md) |
| Native replay and independent receipt verification | [Evaluation](evaluation/README.md) |
| Reviewed plan and five hourly role contracts | [Plan](PLAN.md), [workers](AUTOMATIONS.json) |
| Saved adapter, checkpoint, corpus and evidence identities | [Artifacts](ARTIFACTS.json) |
| Opt-in real-adapter / existing Art provider route and protocol tests | [Local bridge and launch instructions](integration/README.md), [source](integration/local_art_bridge.py) |
| Exact integration dependency board and source pins | [Dependencies](integration/DEPENDENCIES.json) |
| Current durable handoff | [Integration state](integration-state.json) |

## Opt-in local model-to-Art route

The additive [loopback bridge](integration/README.md) now exposes the pinned step-400
LFM adapter through the existing LM Studio-mode Chat Completions Art provider as
**content JSON**, rather than changing the current provider or model API. It
strictly checks a complete admitted program, compiled Art batch and host-captured
focus/material/tool permissions, returning no operations for a failed proposal.
The bridge protocol passed **4/4 focused tests** with mock model output and a real
local HTTP exchange. This is not a fresh actual-model, native World, graphical
or Windows qualification; **Draft/HOLD** remains. A compatible #564/#565 native
Workbench successor and independent integration review are prerequisites for a
qualified user-facing package. The four recorded adapter/resume/corpus/evidence
archives were recovered from the owner's saved files and their bytes and SHA-256
verified on 13 November 2026, not merely listed in the manifest.

## Make a seeded reference pattern

From the repository root, using Python 3.12 or a compatible Python 3 runtime:

```bash
python experiments/wb-art-slm-001/controls/pattern_compiler.py \
  --theme labyrinth --variant 4 --modifier dense \
  --width 96 --height 96 --seed 73 --out labyrinth-art.json
```

This produces the canonical local-coordinate Art JSON array. It is a reference
recipe, not a model prediction. The same word and program with another seed
produce related geometry. `--report` adds program/source identities and bounded
work estimates; it does not claim native execution.

Use the [training instructions](training/README.md) for the adapter inference
CLI, which preserves raw output, requires strict complete JSON, verifies model
and adapter identity, and compiles only an admitted program. No hidden keyword
repair or fallback is counted as model success. Runtime execution remains a
separate explicit step through the native harness or the current Workbench.

## Qualification boundary

The bootstrap native pilot uses exact source
`90719c72b9fcf90593fb7878354051ad601b47fd` and Godot
`4.7.stable.official.5b4e0cb0f`. It exercises the mounted Art planner/executor and
native cell authority in an isolated Linux headless process. The displayed
images are material-readback visualizations, with original cell files and
receipts retained. They are not screenshots of a qualified Windows interface.

The experiment source branch starts from accepted main
`63f8b1ba6559906fe85f3ad0269aa296e4141d67`, preserving the newer #563 capability
consumer. The older Art-bearing runtime is used only for this separately pinned
pilot; it is not substituted for current-main or Windows qualification. No
production defaults, physics/material laws or existing model aliases change.

Host material choices are currently verified Empty 0 and Hard Wall 58. The
native worker's 4,096-cell chunk is not an artwork limit. Compiler preflight,
native receipts, history and save/reopen checks remain separate evidence.

## Development handoff

The five schedules retain distinct Integration, Controls, Corpus, Training and
Evaluation ownership, with one shared integration branch and one combined Draft
PR. They should consume this implemented checkpoint and its measured failures,
not regenerate a plan or launch another identical training run. Existing
NeuroRunner NCR experiments and unrelated schedules remain untouched.

Model/checkpoint binaries and bulk raw native evidence are distributed in the
bootstrap artifact bundle, with exact hashes in the report. Base model weights
are obtained from their pinned official repositories; they are not redistributed
in ordinary Git. The compiler and corpus are independently usable if the model
does not yet meet the proposed acceptance gates.
