---
title: Agent-painter three-family foundation and hosted training handoff
status: Current
document-kind: guide
scope: Opt-in experimental compiler v2, native pilot admission, CPU checkpoint proof and four future model lanes; no production provider promotion
canonical-for: [agent-painter-foundation, agent-painter-corpus, agent-painter-hosted-training]
last-reviewed: 2026-11-13
related-documents: [../systems/workbench-direct-art-batches.md, ../systems/workbench-art-providers.md, wb-art-paint-integrated-candidate.md, ../reference/status-and-roadmap.md]
---

# Agent-painter foundation

The owner-authorized shared foundation for
[issue #568](https://github.com/techrote/cybersand/issues/568) starts from accepted
`ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`, including merged #564/#565.
It selectively adapts [frozen #567](https://github.com/techrote/cybersand/pull/567)
at `bac120981fdd9aecaab0dc8368c421fa390cc269` and
[NeuroRunner TRAIN-001](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/TRAIN_001_CPU_LORA.md).
The exact source-to-destination map is
[SALVAGE.json](../../experiments/agent_painter/SALVAGE.json).
This experimental feature remains **Draft/HOLD**. Actual attempted sources,
CI outcomes, original failure logs, artifact hashes and completion checkpoints
are recorded in issue #568 and the linked Draft PR, rather than inferred from
the presence of these scripts.

## Frozen common interfaces

| Consumer | Interface and authority |
| --- | --- |
| Model output | [program.schema.json](../../experiments/agent_painter/program.schema.json), `version=2`; one strict JSON object, no unknown fields, duplicate keys, repair or commentary |
| Compiler | [compiler.py](../../experiments/agent_painter/compiler.py) `compile_program(program, *, seed, focus, material, allowed_materials, max_operations, max_cell_work)`; host fields remain separate from model JSON |
| Proposal | `cybersand.agent-painter.compiled/2`: exact ordered native rectangle operations, canonical program/operation hashes, compiler hash, host context, semantic witnesses, `proposal_only=true` |
| Native application | Existing [Art planner/executor/worker](../systems/workbench-direct-art-batches.md); authoritative stored cells, material/focus/protection checks, revision fences, Stop and shared history remain native-host decisions |
| Positive corpus | `corpus/admitted-corpus.json` plus separate TRAIN/DEVELOPMENT/FINAL JSONL; each admitted row binds program, operations, source/runtime, actual changed cells, native receipt, readback and original PNG |
| Trainer | [training/common.py](../../experiments/agent_painter/training/common.py) `load_training_corpus`; verifies files and recompiles exact TRAIN programs, never reads FINAL targets |
| Checkpoint | Atomic `checkpoint-NNNNNN/`: adapter safetensors, exact file inventory, optimizer/scheduler/RNG/sample-cursor state, source/model/data/recipe receipts; weights-only-safe state readback |
| Provider | [bridge.py](../../experiments/agent_painter/bridge.py), loopback alias `cybersand-agent-painter-v2`; strict raw completion is recompiled against captured current host scope, returning a proposal only |

Schema/compiler changes require a new version and corpus re-admission. Do not
silently reuse old receipts after changing geometry. Independent future model
Draft PRs should pin the same qualified shared-foundation commit, rather than
stacking on peer model branches.

## New drawing semantics and bounds

Greeble programs compose separated machine panels with vents, grilles, insets,
plating, ribs and fasteners. Panel sizes, densities, borders and deliberate
negative space are parameters. Host-seeded detail placement creates bounded
variation without switching structural split membership.

Pipework uses explicit orthogonal node/edge graphs. Endpoints and junctions are
derived from node degrees; the declared loop count and uniform diameter are
checked before compilation. Optional fitted collars are generated along the
edges. The native readback verifier
checks physical connected components, centerline coverage, cross-section diameter
and enclosed loops. Undeclared crossings and overlapping ambiguous segments are
refused; pipes of different diameter need a separately versioned transition
contract, rather than silently receiving inconsistent width.

Architecture uses axis-aligned walls, floors, platforms, supports, stairs and explicit
openings, with declared room/route geometry. Its optional traversal requirement
means a continuous route with the requested square cell clearance in the actual
material field. This proves geometric clearance only: gravity, climbing, jumping,
actor dynamics and a human gameplay trial remain distinct evaluations.

The design grid is 96 by 96. Host focus is 96..512 cells per dimension; pilot
native execution uses 96 by 96 and Hard Wall 58. Compilation defaults to at most
512 operations and 100,000 unique cell visits, with bounded 12-component input.
All emitted coordinates are integers. Materials and physics are unchanged.
The model cannot supply its own seed, focus, permission list or execution budget.

## Pilot, split custody and owner gallery

The pilot contains **15 whole structural groups**, five per family, with fixed
host seeds 104729 and 130363: **30 native cases**. Per family, two groups are TRAIN, two
are DEVELOPMENT, and one is FINAL. This gives 12 TRAIN, 12 DEVELOPMENT and six
FINAL cases. Seeds are replay variants, not independent structures.

The visible side-by-side HTML gallery contains **24 actual native paintings**:
four distinct designs per family, each at both fixed seeds. It embeds the
original Godot PNG bytes and links their request/program/native provenance.
The six FINAL cases receive mechanical native admission but are excluded from
the gallery, model training, development feedback and candidate selection.
"Sealed" means this procedural exclusion, not secret data or encryption: all
corpora are public/synthetic. Shared primitives remain shared; this small pilot
does not establish broad generalization or artistic quality.

Native qualification mounts the current Workbench and feeds its actual Art
planner, executor and simulation worker. It compares full material readback with
an independent rectangle oracle and reconstructs the write prefix from actual
before/after receipts. It retains initial and repeated executions, original
material-ID/display PNGs, source/runtime hashes, protection/focus/material/Stop
gates and shared history/save/reopen representatives. A plan, test double or
requested-cell count cannot supply positive admission.

The displayed PNGs are **Godot native-material readback visualizations**, not
AI illustrations and not desktop framebuffer screenshots. This distinction is
also embedded in the gallery. Owner visual acceptance remains separate from
objective native and topology checks.

## Reproduce qualification and CPU training

[agent-painter-qualification.yml](../../.github/workflows/agent-painter-qualification.yml)
runs inexpensive contracts for relevant PR updates. An explicit change to
[qualification-request.json](../../experiments/agent_painter/qualification-request.json)
on the dedicated branch, or manual workflow dispatch, requests the bounded
native/CPU campaign. The workflow runs on ordinary GitHub-hosted `ubuntu-24.04`.
It rebuilds pinned godot-cpp and the current native source, verifies official
Godot 4.7 and accepted Rapier hashes, then executes the 30-case pilot and existing
Art stored-material, cancellation, shared Undo/Redo and combined-authoring tests.

The source-built native entry point is:

```sh
python3 experiments/agent_painter/native/runtime.py stamp --source-sha "$GITHUB_SHA" --output evidence/native-build.json
python3 experiments/agent_painter/native/run.py --godot "$GODOT_BIN" --runtime-manifest evidence/native-build.json --source-sha "$GITHUB_SHA" --output evidence/native
```

Only the producer calls `stamp` immediately after a successful source build;
the manifest is custody evidence, not proof of compilation by itself. Consumers
verify exact source inputs, runtime bytes and dependencies. A separate
`--development` mode permits local retained-runtime debugging, labels local
deltas and **cannot admit training rows or claim source-built qualification**.

[agent-painter-train.yml](../../.github/workflows/agent-painter-train.yml) is a
reusable `workflow_call` and manually dispatched entry point. It installs its
own exact CPU Python dependency set, downloads a public source-pinned model on
the runner, and consumes the admitted artifact. Inputs freeze source SHA,
corpus artifact/run, output name, bounded step target and optional checkpoint.
`resume-run-id` selects a checkpoint from a different run than `corpus-run-id`;
when omitted it falls back to the corpus run, then the current run. Thus a worker
can retain a frozen corpus from run A while continuing a checkpoint from run B.
The environment receipt records both resolved artifact origins.
Ordinary pushes do not launch training. No owner Windows machine, worker-local
filesystem, model secret or GPU is required.

The foundation proof trains SmolLM2 through two actual optimizer updates,
saves full checkpoints, then uses a **separate fresh runner** to resume checkpoint
one and reproduce update two. The comparison requires exact configuration,
sample cursor, RNG and scheduler identity; floating tensors use declared
`atol=1e-6`, `rtol=1e-5`, report maximum differences and separately report
bitwise equality. The base model must remain unchanged. This tiny proof is
not a useful painter, a quality comparison, or a four-model training campaign.

The hosted recipe fixes generic ATen CPU dispatch and oneMKL's `COMPATIBLE`
branch before PyTorch loads, uses one fixed CPU thread with dynamic threading
disabled, and disables oneDNN while retaining full FP32 precision. Effective
math settings, their implementation hash and PyTorch build identity are bound
to checkpoints; physical host identity is recorded separately. This addresses
observed differences between hosted CPU platforms without relaxing the tensor
tolerances. The comparator scans all tensors, including after a failed element.
See the [training handoff](../../experiments/agent_painter/training/README.md)
for settings and primary numerical-reproducibility references.

Every failure retains original logs. Successful runs publish source-bound,
checksummed research assets through an immutable prerelease tag; ordinary
Actions copies retain 90 days. Never overwrite a frozen checkpoint or release.

## Future model-worker handoff

| Lane | Consume now | Implement or qualify in its independent Draft PR |
| --- | --- | --- |
| SmolLM2-135M-Instruct | Exact pin `12fd25f77366fa6b3b4b768ec3050bf629380bac`, admitted TRAIN, CPU optimizer/resume/inference implementation | Useful bounded training, frozen raw DEVELOPMENT baseline/candidate comparison, native replay of original model output |
| void.1 | Exact pin `9c2be5087772867d45961abd11f6b35110617563`, reviewed strict byte tokenizer, explicit non-chat framing/EOS258, Qwen3 projection whitelist and model-specific hosted receipts | Useful bounded byte-model training and first-pass native evaluation; retain the 2048-token budget without truncation |
| Sprocket-500M root Instruct | Exact pin `eb157d4ddddc4619e661d4a2426bb2dd000fc668`, root Jinja/EOS5, 182-module whitelist and model-specific hosted receipts | Useful bounded Instruct training and native evaluation; `chat/` remains a different checkpoint |
| LFM2.5-VL-450M | Exact official pin `fc6221ca597f3315e4f82fc2df606783267b34ba`, reviewed license/official processor, actual multimodal class, 92 exact language-side LoRA paths and hosted receipts | Text-only Art training with frozen vision encoder/connector; later image conditioning is separate |

Each profile now has a distinct reviewed loader and framing contract. Their
source-pinned two-update/checkpoint/fresh-VM proofs use
[agent-painter-profiles.yml](../../.github/workflows/agent-painter-profiles.yml)
and retain the native corpus identity from qualified source
`633920373a3d406a2ede61ce4137c324f76be23b` separately from newer trainer source.
Code presence does not establish a passed preflight: issue #568 records the
executed run, model receipt, checkpoint comparison and remaining blockers.
The full proposed 60-request/five-formulation candidate benchmark is future
evaluation work; this pilot freezes teachers and structural partitions before
candidate training, without falsely labeling 24 teacher images as 60 model trials.

The optional loopback bridge runs on a qualified POSIX host with Context None,
Image off and Turns 1. It requires host-enabled rectangle drawing and material58,
owns a bounded process group, and kills descendants on Stop/disconnect/deadline
or parent exit. The donor's Windows process attachment race is not imported;
Windows inference spawning fails before starting a process. This does not
change the native application's existing Windows Stop or provider behavior.

The 2026-11-13 owner follow-up separately authorizes four model schedules plus
shepherd and reviewer. Smol starts from its qualified source; the other model
schedules are enabled only after actual hosted preflight. One worker may manage
two independent Actions VMs, one model process per VM, with unique experiment
leases. The owner did not request two models sharing one runner. Full-scale
training, optional 2B judge/authority experiments, Codespaces benchmarking,
default-provider change and merge remain outside the bounded preflight.
