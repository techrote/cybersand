---
experiment: WB-ART-SLM-001
title: CyberSand themed pattern controller
date: 2026-11-13
status: Planned
implementation_status: No implementation or training run claimed by this plan
evaluation_status: Proposed targets; no new measured results
primary_repository: techrote/cybersand
reference_repository: techrote/neurounner
integration_branch: codex/wb-art-slm-001
---

# CyberSand themed pattern controller

## Purpose and contents

Build a small local language model that turns a modest vocabulary into varied, recognizable CyberSand structures. The first useful experience is selecting an area, entering a word such as `roots`, `strata` or `labyrinth`, and receiving a randomized pattern that consistently belongs to that family. Modifiers such as `sparse`, `dense`, `open` and `twisted` should make predictable changes. Specific object drawing is outside the initial objective.

Five hourly workers will develop the control contract, create executed training examples, prepare and run bounded fine-tuning, independently evaluate results, and integrate the work. They are development roles, not five simultaneous training jobs. This document is the reviewed implementation plan; every performance figure below is either an attributed historical observation or an explicitly proposed target.

Contents:

- **Product scope** — defines the first usable result and what the model must contribute.
- **Sources and repository boundaries** — identifies reusable NeuroRunner concepts and CyberSand dependencies.
- **Control architecture** — separates compact model programs, deterministic geometry and native execution.
- **Pattern vocabulary** — specifies twelve families and the initial four-family pilot.
- **Corpus and curriculum** — creates execution-grounded examples without leaking template families.
- **Model and training** — selects a primary model and a bounded, resumable local training recipe.
- **Evaluation and acceptance** — measures syntax, native behavior, theme recognition and diversity separately.
- **Five worker responsibilities** — assigns ownership, handoffs and concrete first deliverables.
- **Scheduling and coordination** — prevents overlapping writes, repeated training and procedural churn.
- **Phases and exit deliverables** — provides dependency-based milestones rather than promised completion dates.
- **Review changes** — records the weaknesses found in the provisional plan and the resulting fixes.
- **Source references** — collects the primary evidence used to design the work.

## Product scope

The first deliverable is a usable seeded pattern controller with an inspectable gallery, followed by evidence that fine-tuning adds value. One model and one multitask adapter should cover all twelve themes. Separate adapters per theme are unnecessary until measured interference justifies them.

A deterministic dictionary can already map twelve exact words to twelve generators. Therefore the fine-tune should earn its place through better paraphrase handling, modifier fidelity, composition of familiar elements in unfamiliar combinations, or short valid primitive plans. It does not need to outperform a perfect dictionary on literal keyword lookup. Keep the deterministic implementation as a useful baseline and fallback even if a model candidate adds little.

The user-facing operation is bounded: selected focus area, theme, optional modifiers, explicit seed, apply through the existing Workbench, then ordinary Undo/Redo and persistence. An optional program inspection must not become a mandatory new drawing ceremony. Randomness belongs to the host and compiler. Record the seed and all source identities so the same admitted program can reproduce its geometry under the same compiler version. Model sampling itself need not be bit-identical across devices; retain the actual program that produced the result.

Start with static structures using the existing agent-art material envelope. The reviewed implementation uses Empty and Hard Wall, currently identified as 0 and 58; verify these against the live source and runtime before generating data. Other painting palettes may exist without being qualified for this controller. Multi-material generation can follow a successful first release, with its own material and persistence tests.

## Sources and repository boundaries

NeuroRunner main was inspected at `40543403f05de7ecacdca84ad7d651e5c5997cea`. Its useful precedents are narrow LoRA specialization, assistant-only supervision, complete checkpoint/resume, family-disjoint evaluation, independent criticism, and durable raw-before-derived evidence. TRAIN-001 showed rapid schema adaptation but explicitly retained semantic failures. TRAIN-003 improved a synthetic mechanical compiler using 896 examples and disjoint mechanism families; its own report limits those results to shared deterministic prompt grammar and a lexical/structural evaluator. Neither result proves CyberSand drawing competence. [N1][N2][N3]

Borrow those methods without importing the experimental NCA architecture, custom tokenizers, population-scale training, or historical scientific gate machinery. The NCR-001 frozen lanes and their `train_authorized=false` state remain untouched. The older Scheduswarm dispatcher is not being restarted or reconfigured. This is a fresh CyberSand experiment with new source, data, model and evaluation identities. [N4]

Proposed home: `experiments/wb-art-slm-001/` in `techrote/cybersand`. The initial integration branch contains the plan and coordination files. Production integration should be limited to the existing agent-art/local-model seam where a concrete capability is missing. NeuroRunner remains a read-only reference.

The CyberSand dependency must be checked afresh. At 01:37 London time on 13 November, main is `63f8b1ba6559906fe85f3ad0269aa296e4141d67`, including both #562 and the newly merged #563. Agent-art #564 remains Draft at `6319ab1d94d85d01c9cdb44d973a92d224bfa9aa`; combined #565 is Draft at `88ba76f023e933b52d15f272263077e091bc9656`, containing #562 and that #564 head but predating #563. Its current qualification is still running, so this plan claims no complete qualification of that head. The plan branch starts from current main and must retain its newer capability consumer. Consume a compatible upstream combined successor when available; do not redo #565's integration, take ownership of its #563 join, or adopt unrelated camera work. An earlier pinned #565 runtime may support a separately identified pilot in its own worktree, without being represented as current-main qualification. Preserve shared manual/agent history. [C1][C2][C5]

Before any native dataset run, record full source SHA, tree SHA, runtime/build hash, tool-schema hash, material map, compiler version and relevant qualification evidence. A later upstream change requires a contract diff and affected regressions. A newer branch head is not automatically qualified because an older build passed.

## Control architecture

Use this sequence:

1. The host resolves focus bounds, permitted materials, seed, user options and available transaction budget.
2. The model emits one compact JSON pattern program against a versioned schema.
3. A deterministic validator checks types, bounds, allowed primitives, expansion depth, operation count and cost.
4. A deterministic compiler expands the program into the existing agent-art drawing representation.
5. The existing Workbench executor streams bounded batches through its authoritative native worker and returns acknowledgements.
6. Readback and a real CyberSand render establish the result; history and persistence are tested separately.

The initial model target is the pattern-program schema. The native tool JSON is a compiled artifact. Do not mix these formats in training without an explicit task discriminator. The MVP uses the existing content-JSON local bridge and is accurately described as structured control. It is not a claim that the current client already supports a model's native `tool_calls` envelope.

LFM3's native function format differs from the pythonic convention used by LFM2.5. A native tool envelope is a later compatibility change requiring explicit serializer/parser and transport tests. The application contract must not silently change with the model family. [L1][L2]

The grammar may include bounded repeat, branch, mirror, jitter and motif composition. Start with roughly 4–12 motifs per program and a provisional 256–512 token output budget. Measure fully serialized examples, including schema and recovery context: shorten the representation or deliberately increase the cap where necessary, and never silently truncate a training target. Permit only registered declarative operations; never execute arbitrary model-generated Python, GDScript or shell code. All baselines use the same grammar and compiler. The model cannot assign canonical trace IDs, expand its own limits, select credentials or alter host state outside the admitted operation.

Preflight the complete program before executing its first batch. Expansion must terminate within explicit depth, primitive, cell and wall-time budgets. Validate both the symbolic program and its expanded native plan. An invalid or oversized program is a rejected proposal, not a partially executed success. Preserve the original output and any later repair as separate records.

Respect focus boundaries and protected/native body masks using current source semantics. Use stored-material acknowledgements correctly rather than treating transient masks as permanent paint. Reuse existing revision fencing, stale-observation handling, idempotency, Stop and native receipts where available. In uncertain transport outcomes, inspect the receipt/readback before retrying; never duplicate a drawing operation merely because a response timed out.

Do not promise unlimited atomic undo. Admit each recipe within the actual save/history envelope and verify the resulting transaction behavior. Current source observations to recheck include a 4,096-cell chunk size, history limits of 32 parts / 1,048,576 retained cells / 262,144 cells per part, and persistence limits of 32,768 stamps / 1 MiB per current record. These values are implementation guardrails, not universal artistic limits; the chunk size is not the maximum size of an artwork. Compute the applicable minimum budget and reject or simplify before mutation. Do not raise shared limits just to pass this experiment.

Test cancellation before execution, during a batch and after an acknowledged partial sequence. Report exactly what remained, what was reversed, and whether it is saved. The host must enforce these guarantees for malformed and adversarial programs as well as sensible model output.

## Pattern vocabulary

These names describe geometric families, not promises to draw recognizable individual objects:

| Word | Intended structure | Useful variation |
|---|---|---|
| roots | Tapering branching networks | Branch angles, depth, clustering, gaps |
| coral | Clustered porous growth | Fan shapes, lobes, branching density |
| veins | Connected irregular channels | Thickness hierarchy, loops, tributaries |
| mycelium | Fine interwoven networks | Junction density, filament length, patches |
| strata | Layered bands and faults | Band width, offsets, waviness, erosion gaps |
| dunes | Repeated asymmetric ridges | Spacing, crest height, interruption, slope |
| crystals | Faceted angular clusters | Orientation, size distribution, growth axes |
| honeycomb | Cellular chambers | Cell size, irregularity, missing walls, density |
| labyrinth | Chambers and winding passages | Connectivity, corridor width, loops, dead ends |
| ruins | Broken structured arrangements | Fragmentation, offsets, voids, repeated bays |
| circuitry | Orthogonal branching routes | Junctions, parallel paths, spacing, blocks |
| ribs | Repeated supports around a direction | Curvature, spacing, taper, symmetry |

Begin with roots, strata, labyrinth and circuitry because they expose substantially different topology. Produce eight seeded native examples per family: a 32-image inspection gallery. Then expand to all twelve families with sixteen examples each: 192 actual renders. Gallery labels include command, seed, program, source manifest and receipt link; theme-blind evaluation receives unlabelled versions.

Keep the foreground crisp and genuinely two-dimensional. Pattern variety should arise from geometry and composition rather than captions, background effects or small random pixel noise. Modifiers need measurable interpretations: `open` preserves larger voids; `dense` changes occupancy within safe bounds; `twisted` changes orientation/curvature where the family supports it. Reject unsupported combinations clearly instead of producing a generic fallback and calling it success.

## Corpus and curriculum

Create a small working pilot before scaling. Only execute against a pinned runtime contract. A positive training record must have a valid program, successful native execution and a result that meets its declared theme/modifier intent. Teacher confidence or valid JSON alone is insufficient.

Each record preserves exact input messages, schema version, host context, raw model/teacher output, normalized program if any, compiler output, seed, native acknowledgements, readback, render identity, source hashes and review labels. The host assigns immutable IDs and lineage. Keep failures and repairs; remove secrets and private user content from public evidence. Store bulk renders and checkpoints in a suitable durable artifact store, with searchable manifests and hashes in Git. Expiring Actions artifacts are not the sole archive. [N5][N6]

The proposed first training corpus is 1,200–2,400 accepted traces plus approximately 300 targeted error/recovery examples. These are planning ranges, not quotas that justify repetitive expansion. Begin smaller if the pilot reveals a schema or compiler problem. Grow only against observed gaps, using theme balance and coverage of sparse/dense/open/twisted requests, focus sizes, border conditions, empty/occupied areas and modest compositions.

For recovery supervision, put the rejected request or tool error in context and supervise the correct next action. Do not label an invalid call as a successful assistant target. Include explicit budget refusal, stale observation, malformed program, unsupported material, cancellation and uncertain-receipt cases. Generic no-ops do not count as successful pattern generation.

Assign train/development/final groups before seed expansion. Group by structural template family, composition family, source lineage and transformations; nearby seeds or translated versions must not cross splits. New seeds from the same template are useful variation but do not prove generalization. Reserve genuinely different compositions and morphological variants, while ensuring each requested theme remains represented in the intended evaluation task.

Use development results for repairs. The evaluator owns the final manifest and releases final results only after the candidate is frozen. Final prompts, programs and per-case feedback must not feed training; if a failed final case is used for repair, retire that set into development and establish a fresh final assessment. This is a practical data boundary, not a claim that a public repository creates access-control secrecy.

Curriculum order: exact keywords and simple programs; modifiers and spatial constraints; short compositions; then bounded failure recovery. Maintain examples from earlier stages during correction to detect regression. Prefer a targeted corpus correction over broad hyperparameter sweeps. NeuroRunner's failure-weighted curriculum experience supports this priority, without guaranteeing transfer to visual patterns. [N7]

## Model and training

Primary candidate: **LiquidAI/LFM3-1.7B**, a text model of approximately 1.73B parameters. Challenger: **LiquidAI/LFM2.5-350M** once the primary pipeline works, or as a documented switch if LFM3 encounters a reproducible compatibility or latency blocker. This is one bounded comparison, not an architecture sweep. Resolve and pin exact weight, tokenizer and chat-template revisions, check their licenses and training/runtime support, and record those identities before execution. Neither model is qualified for this task merely by appearing in this plan. [L1][L2]

Use concise JSON supervision and the identical prompt/template path at training and inference. LFM3 thinking behavior must be tested rather than assumed disabled: request `enable_thinking=false`, constrain decoding to the admitted JSON grammar where supported, impose output-token and wall-time limits, and reject reasoning-only, truncated or mixed reasoning/program responses. Record raw unconstrained behavior separately. Do not use a cleanup parser to conceal that the model failed its output contract.

Use the official LFM3 TRL fine-tuning cookbook as the initial compatibility reference. Proposed LoRA starting point: rank 16, alpha 32, dropout 0.05, completion-only loss. Inspect actual module names and trainable parameter counts; the cookbook's attention/projection and feed-forward targets include q/k/v/o, in/out and w1/w2/w3 naming patterns. Do not reuse a transformer-only target list blindly. [L3]

Proposed local recipe: sequence length 1,024, batch size one, accumulation eight, gradient checkpointing where compatible, and FP16 with loss scaling on the user's previously discussed Titan RTX 24 GB. Do not assume BF16 or a particular FlashAttention kernel is supported. These are starting settings, not a measured fit claim. Verify attention masks, tool/program delimiters, terminal tokens and completion-only target labels by inspecting supervised token spans. Mask prompts, observations, tool results and padding, while retaining the real assistant end-of-turn/EOS. When pad and EOS share an ID, mask using positions/attention rather than deleting every occurrence of that ID. A custom template does not automatically support an assistant-only mask flag.

The first physical smoke can begin on a small executed four-theme pilot before the twelve-theme corpus is complete: at most 25 optimizer steps, followed by a fresh-process checkpoint restore and continuation. Save adapter weights, optimizer/scaler state, scheduler state if used, Python/Torch/CUDA RNG state, sampler/sample cursor, global step, corpus manifest and complete environment identities. Compare interrupted versus uninterrupted continuation within documented numeric tolerances. Confirm finite loss, meaningful adapter gradients, unchanged frozen base weights, and useful generated output after reload. A declining loss alone is not an acceptance result.

Allow one admitted training process on one reachable authorized accelerator. Its lease covers GPU-heavy evaluation as well, with a heartbeat and recorded job/process identity. The first real candidate has a maximum 60-minute training-process budget with time reserved for a clean checkpoint; checkpoints and deadlines prevent an hourly wake-up from restarting it. Extend only after measured throughput, memory and development results justify a recorded next experiment. Avoid an unbounded hyperparameter search. No paid cloud services or hosted GitHub Actions training are authorized by this plan; Actions are for focused build/test work under the repository's existing policy.

No reachable GPU has been established in the current task environment. The trainer's first deliverable, if that remains true, is an executable Windows/WSL2 handoff with dependency pins, exact input manifests, resume support and measured preflight checks. State the missing connection once and continue useful offline work. Do not invent a successful CPU fallback or imply that scheduling makes the Titan remotely accessible. Any Godot launcher must accept an explicit path; the user's confirmed console default is `C:\Godot_v4.7-stable_win64_console.exe`. Publish concrete commands only after their scripts exist and are verified.

Deployment starts with the validated training/runtime format. GGUF conversion, adapter merging or quantization creates a new candidate identity requiring the same relevant tool, language and visual checks. Do not assume quality parity after quantization.

## Evaluation and acceptance

Compare three conditions with matched focus areas, seeds, grammar, compiler, native runtime and budgets:

- Deterministic keyword/parameter controller.
- Untuned primary model using the same constrained backend.
- Fine-tuned primary model using that backend.

Report raw unconstrained output separately from constrained output. Also separate model success from parser repair, compiler intervention and host refusal. A useful release can retain the deterministic controller when the fine-tune fails to add value; do not manufacture a model victory.

Proposed initial targets:

| Dimension | Initial target and interpretation |
|---|---|
| Raw schema validity | At least 95% on a fixed diagnostic suite; no silent repair |
| Constrained schema validity | At least 99%; report rejection/truncation and denominator |
| Native execution | At least 98% of valid positive benchmark requests produce the intended bounded edit; include malformed/rejected model outputs in the denominator and report admitted-only yield separately |
| Host integrity | Zero out-of-focus/protected writes; all budget and material restrictions enforced |
| Transaction behavior | Required Stop, Undo/Redo and save/reopen scenarios pass with readback evidence |
| Theme recognition | Pilot target at least 13/16 per theme, approximately 80%; inspection evidence only |
| Modifier behavior | Correct directional effects and constraint fidelity against explicit annotations |
| Diversity | Distinct structural variants without loss of theme; no single hash-based threshold |
| Learned value | Measurable benefit on paraphrases, modifiers, unfamiliar compositions or planning |

The sixteen-image theme pilot is too small for strong reliability claims. Before a stronger release statement, target at least fifty outputs per theme drawn from several held-out structural/template groups. Report both output counts and independent group counts, with group-aware uncertainty and a per-theme confusion matrix; fifty correlated seeds are not fifty independent structures. This expanded benchmark is a milestone assessment, not a prerequisite for showing the useful pilot to the owner. Blind raters should see actual unlabelled renders without theme names or identifying filenames. Use an independent model critic as a screening aid, with owner review of representative and confusing cases; an automatic judge is not equivalent to owner acceptance. Correct refusals, safe cancellation and recovery are separate tasks, never excuses for integrity violations or empty positive drawings.

Diversity checks should include duplicates after relevant translation/scale normalization, topology and motif variation, occupancy, component/channel structure, and paired visual inspection. Metrics are descriptive: connectivity is desirable for some patterns and inappropriate for others. A one-pixel change must not turn a repeated template into a supposedly novel result.

Include adverse cases: smallest/largest admitted focus, boundary contact, protected overlap, interruption, stale revision, retry after uncertain acknowledgement, invalid material, oversized repeat and malformed output. Verify saved/reopened state and history at the exact candidate source. Report latency, peak memory and tokens alongside quality; no desktop performance promise exists until measured on the deployment machine.

## Five worker responsibilities

| Worker | Schedule | Owned branch and surfaces | First concrete deliverable |
|---|---|---|---|
| Steward/integrator | Hourly at :02 | `codex/wb-art-slm-001`; shared plan, admission/state manifest and integration | Fresh source/runtime dependency audit, bounded milestones and shared handoff contract |
| Controls/compiler | Hourly at :12 | `codex/wb-art-slm-controls`; `controls/`, namespaced tests, coordinated production seam | Versioned schema, deterministic compiler, budget validator and native trace recorder |
| Corpus/foundry | Hourly at :22 | `codex/wb-art-slm-corpus`; `corpus/` and namespaced generation/tests | Four-family specifications and first 32 actual native renders with lineage |
| Trainer | Hourly at :32 | `codex/wb-art-slm-training`; `training/` and namespaced training/tests | Model/template pins, runnable environment and smoke/resume package or physical result |
| Evaluator | Hourly at :42 | `codex/wb-art-slm-evaluation`; `evaluation/` and namespaced assessment/tests | Matched baseline harness, split audit, independent gallery and rejection diagnostics |

Schedules use Europe/London. Minute offsets reduce simultaneous starts but do not establish dependency order or guarantee earlier tasks have finished. Every role reads fresh remote heads, the shared manifest, its previous checkpoint and relevant upstream evidence before acting.

Role outputs live beneath `experiments/wb-art-slm-001/`. Each role owns its own status JSON; the steward alone updates the shared state/admission manifest and integration branch. A durable remote commit with exact object identities is the handoff, not an uncommitted scratch file or a chat assertion. Worker identifiers and exact saved prompts belong in `AUTOMATIONS.json` after scheduling.

The controls worker owns execution correctness, not aesthetic curation. The corpus worker owns development examples, not final-test selection. The trainer cannot grade its own candidate into acceptance. The evaluator can request corrections but does not write final-test answers into the corpus. The steward resolves cross-role work and integrates only reviewed, dependency-ready changes.

## Scheduling and coordination

Create exactly five hourly tasks. Use stable role branches and at most one combined Draft PR once substantive code exists. Do not create hourly issues or PRs. Preserve other active branches, PR ownership and runtime workstreams. No automatic merge to main or Ready-for-review promotion is part of this plan.

Before a write, re-read the remote head and use a lease/compare-and-swap check. Never force-overwrite a sibling's changes. Integrations are serialized. Independent implementation may overlap, but shared native sessions, candidate admission and accelerator use need explicit single-owner leases with recoverable expiry and recorded process identity. A stale lease is investigated before reuse, not deleted speculatively.

On each wake-up, complete the largest useful dependency-ready unit within bounded execution time. If inputs and dependencies are unchanged, return a concise no-change result. Do not repeat documentation polishing, rerun passing campaigns without a concrete risk, re-download unchanged models unnecessarily, or start the same training candidate twice. Recover partial data and checkpoints by verified identity rather than regenerating the whole campaign.

Each meaningful handoff includes changed source SHA, input identities, actual commands/results, output manifest, unresolved failure and next dependency. Label states clearly: planned, implemented, executed, passed, failed, or blocked. An offline test, a native execution and an aesthetic judgment are different evidence classes.

The steward may adjust only these five saved prompts within the authorized objective. It cannot create successor schedules, expand into unrelated research, commission paid resources, merge main or reconfigure the historical NeuroRunner dispatcher. If infrastructure is missing, record the exact dependency once and advance independent work rather than producing an hourly spending or access loop.

## Phases and exit deliverables

| Phase | Exit evidence | What may proceed next |
|---|---|---|
| Foundation | Pinned dependency manifest, schema, bounded compiler, trace recorder, host rejection tests | Native pattern pilot and model preflight |
| Four-family pilot | 32 actual renders, theme/modifier review, valid receipts and history/persistence probes | Twelve-family expansion, corpus curation and a small LoRA smoke in parallel |
| Vocabulary pilot | 192 actual renders, confusion/collapse analysis, family-group split audit | Initial SFT dataset freeze |
| Training proof | Physical 25-step smoke/resume, or complete runnable handoff with explicit missing hardware | First bounded candidate when accelerator is reachable |
| Candidate comparison | Matched baseline results, corpus/model/runtime hashes, failures and resource measurements | Targeted development repair or final freeze |
| Release candidate | Expanded independent assessment, native Stop/Undo/save checks, deployment-format qualification | Owner evaluation through one Draft PR |

The final delivery comprises source, schema/compiler, twelve-family gallery, curated corpus manifests, reproducible training/resume package, model/adapter identities where produced, benchmark report, and concise Windows acceptance instructions. A useful deterministic controller remains deliverable even if model promotion is HOLD. No calendar completion promise is made before native and training throughput are measured.

## Review changes

The provisional design was revised to address six concrete weaknesses: fixed keywords alone cannot establish learned value; macro selection cannot be called primitive drawing competence; repeated seeds cannot substitute for disjoint structural tests; sixteen examples cannot establish strong per-theme reliability; successful parsing cannot replace native readback; and hourly scheduling cannot establish GPU access.

The resulting plan gives every worker a substantive output, keeps history and native bounds under host authority, makes the deterministic baseline useful, and requires actual CyberSand renders before dataset scale. It preserves NeuroRunner's reproducibility strengths while avoiding a campaign that only accumulates schema tests and evidence paperwork.

## Source references

- [N1 — NeuroRunner README, inspected source](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/README.md)
- [N2 — TRAIN-001 CPU LoRA and resume evidence](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/TRAIN_001_CPU_LORA.md)
- [N3 — TRAIN-003 semantic corpus, results and limitations](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/TRAIN_003_SEMANTIC_COMPILER.md)
- [N4 — Existing NeuroRunner dispatcher and NCR boundaries](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/SCHEDUSWARM.md)
- [N5 — Dataset filing and raw-before-derived contract](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/DATASET_FILING_SYSTEM.md)
- [N6 — Model storage policy](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/MODEL_STORAGE.md)
- [N7 — Village curriculum, independent review and final-test separation](https://github.com/techrote/neurounner/blob/40543403f05de7ecacdca84ad7d651e5c5997cea/docs/VILLAGE_001_CYBERGOBLIN_FOUNDRY.md)
- [C1 — Integrated Workbench PR #564](https://github.com/techrote/cybersand/pull/564)
- [C2 — Combined MAT-AUTH/Workbench PR #565](https://github.com/techrote/cybersand/pull/565)
- [C3 — Source-bound native drawing, protection, history and persistence contract](https://github.com/techrote/cybersand/blob/6319ab1d94d85d01c9cdb44d973a92d224bfa9aa/docs/systems/workbench-direct-art-batches.md)
- [C4 — Source-bound local providers and prior LFM art trials](https://github.com/techrote/cybersand/blob/6319ab1d94d85d01c9cdb44d973a92d224bfa9aa/docs/systems/workbench-art-providers.md)
- [C5 — Main with merged native capability consumer #563](https://github.com/techrote/cybersand/commit/63f8b1ba6559906fe85f3ad0269aa296e4141d67)
- [L1 — Official LFM3-1.7B model card](https://huggingface.co/LiquidAI/LFM3-1.7B)
- [L2 — Official LFM2.5-350M model card](https://huggingface.co/LiquidAI/LFM2.5-350M)
- [L3 — Official LFM3 supervised fine-tuning cookbook](https://github.com/Liquid4All/cookbook/blob/main/finetuning/notebooks/lfm3_sft_with_trl.ipynb)

Repository status and model/runtime compatibility are time-sensitive. Workers must verify current sources and record exact identities rather than treating this dated review as a permanent runtime pin.
