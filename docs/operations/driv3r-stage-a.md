---
title: S1-2B-DRIV3R Stage A decision-controller foundation
status: Current
document-kind: guide
scope: Draft branch candidate for resident d1 decision inference and bounded native Workbench episodes; execution results remain separately source-qualified
canonical-for: [driv3r-stage-a, driv3r-decision-controller, driv3r-native-qualification]
last-reviewed: 2026-11-14
related-documents: [agent-painter-foundation.md, ../systems/workbench-direct-art-batches.md, ../architecture/shared-workbench-authoring-data.md, current-and-historical-validation.md, ../reference/status-and-roadmap.md]
---

# S1-2B-DRIV3R Stage A

**Current candidate, Draft/HOLD:** the owner authorized the bounded Stage A
implementation for [issue #570](https://github.com/techrote/cybersand/issues/570)
on 14 November 2026. This guide describes source contracts and reproduction;
it does not assert that acceptance gates have passed. The exact tested source,
original failed attempts, actual model decisions, native receipts, performance
and gate dispositions belong to the Stage A execution report and issue ledger.
The implementation must remain Draft until a separate owner decision.

**Subsequent Owner direction:** Stage B and a conditional modest Stage C were
explicitly authorized after the qualified Stage A checkpoint. The
[Stage B guide](driv3r-stage-b.md) owns that continuation and its usefulness gate;
the Stage A boundary below records the earlier checkpoint, not a prohibition on
that later explicit instruction.

## Source ownership and reuse

The candidate starts from shared [Draft #569](https://github.com/techrote/cybersand/pull/569)
at `2a565df45efc568eb96a2166e0b77f299e289625`, which contains accepted
`main` at `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742` and its merged Workbench
and Materials Lab. Its independent branch is `research/570-driv3r-stage-a`.
Recheck the live base and head before continuing; these are starting identities,
not a claim that subsequent source changes were already qualified.

[Issue #568](https://github.com/techrote/cybersand/issues/568) retains its four
generative painter lanes and optional action-veto investigation. DRIV3R instead
uses d1 as the controller selecting its own next host-proposed action. It does
not own those lanes, their training leases or their source files. Historical
#567 and #531-derived branches remain read-only references.

The unchanged [shared compiler](../../experiments/agent_painter/compiler.py)
expands the fuzzy demonstration's version-2 architecture primitives into exact
bounded rectangles. The existing Workbench Art planner, executor and simulation
worker retain native write authority, protection, acknowledgement and stored
material semantics. The shared
[runtime verifier](../../experiments/agent_painter/native/runtime.py) supplies
source-build, native-library, Godot and Rapier custody. DRIV3R adds its own
source inventory rather than rewriting those contracts.

## Observation, candidates and decision contract

The versioned interface is `cybersand.driv3r/1` in
[contracts.py](../../experiments/driv3r/contracts.py). The episode order is
observation, candidate generation, question construction, model decision, host
validation, native action and next observation.

| Responsibility | Source and behavior |
|---|---|
| Observation provider | [providers.py](../../experiments/driv3r/providers.py) records objective/subgoal, World generation/revision/tick and material hashes, fixed host focus/material, vehicle position, bounded local material crop, exact host geometry metrics, history, remaining budgets and preceding acknowledgement. |
| Candidate provider | The direct provider enumerates legal one-cell cardinal movements plus STOP. The fuzzy provider enumerates host-compiled operation/profile pairs at three graph nodes, plus SKIP and STOP. The model does not choose arbitrary coordinates, material IDs or permission fields. |
| Decision provider | [controller.py](../../experiments/driv3r/controller.py) constructs one named holistic `choice` question. Its result binds candidate ID, full distribution, reported confidence, original response, model/backend identities, latency and observation/candidate hashes. |
| Action executor | The host re-observes native state after inference, refuses stale or retired state, checks legality and remaining budgets, then submits only the selected held candidate through existing Art authority. A model answer alone never means cells changed. |
| Episode controller | The host owns decision/cell/wall-time bounds, ordering, STOP/cancellation and terminal status. Only consistent native acknowledgement advances the vehicle or executed graph node. An explicit SKIP advances the graph without painting. |

Named questions in the same `system_one` request assess the same supplied state.
They do not consume one another's answers. Stage A uses one holistic question;
multi-pass planning and learned hierarchy are Deferred.

Candidate ordering is recorded and hashed. Reordering cannot turn an index into
a different control: decisions select stable IDs. Native identity is checked
again at admission because the World could change while inference is pending.
The host retains invalid answers, timeout outcomes and poor legal choices; it
does not substitute an oracle action to improve the model's result.

## Resident d1 backend and question semantics

[backend.py](../../experiments/driv3r/backend.py) owns a persistent POSIX
`llama-server` process bound to loopback, with an ephemeral API key, one inference
slot and CPU-only execution. Requests use `/v1/systemone`, not chat completions.
The process remains resident across episode decisions. Startup, request and
shutdown have finite deadlines; cancellation or timeout retires the instance
and its owned process group rather than admitting a late answer.

The immutable identities and original-source links are in
[pins.json](../../experiments/driv3r/pins.json):

| Component | Pinned identity |
|---|---|
| Official quantized checkpoint | `LiquidAI/d1-2B-GGUF` revision `4a181094d1b6addfaa3a0956f78e7ab2aa406a0c`, file `d1-2B-Q8_0.gguf` |
| Actual Q8 weight bytes | 1,846,240,576 bytes; SHA-256 `073313d92b53b0ac8193db6e906cb3c78a98183d244b15b7b8f5426115c6738c` |
| Resident runtime | Official llama.cpp `b11960` / `v0.8.0`, commit `8642541b255bfb5dc39cd351a178be09013a55d6`; archive and extracted executable/library hashes are pinned separately |
| Reference semantics | Official `LiquidAI/d1-2B` revision `652f920e544ea37f81e4b0ce89b81d4ed0da90b1`; inspecting reference code does not establish reference-model execution or probability parity |
| License custody | Model acquisition retains the original LFM Open License v1.0; runtime acquisition retains the original MIT license. |

The Stage A adapter accepts only ordinary single-choice questions. It rejects
unknown fields, including `multiple`, before sending them to llama.cpp; the
pinned runtime does not independently reject every unsupported advanced flag.
Answers carry a named choice, confidence and candidate probabilities, with
`output_tokens: 0`. The adapter validates the complete distribution, candidate
set and selected argmax. Reported confidence is not presumed to be calibrated
for authoring quality.

Q4_K_M is separately identified as an optional unqualified alternative. It is
not silently substituted for Q8. Reference Transformers inference is optional;
any comparison must keep exact backend and checkpoint identities distinct.

## Actual native session and evidence

[native.py](../../experiments/driv3r/native.py) connects to
[run_driv3r_stage_a.gd](../../godot/tests/run_driv3r_stage_a.gd), which mounts the
existing Workbench in one headless Godot process. Atomic local files carry
ordered requests and responses; they are an isolated local harness, not a
replacement public transport or authoring UI.

The native World is 512 by 512; the authorized painting focus is 96 by 96 with
material58. Deterministic wall/obstacle fixtures retain protected material and a
protected rectangle. Direct drive moves its host cursor one cell at a time and
draws the destination cell. The fuzzy graph offers a platform, extension and
support with discrete thin/thick or short/long profiles compiled by #568.

The harness supplies original full-World material bytes, focus readback,
before/after hashes, native chunk receipts and material-derived PNGs. Python
independently checks crop/full-World equality, actual changed-cell counts and
receipt reconstruction. The proposed operation count and model confidence do
not replace these readbacks. PNGs visualize native stored material; they are
not graphical framebuffer screenshots or generated illustrations.

The deterministic geometric baseline uses the same initial fixture, legal
candidates and budgets as direct drive. Its decisions remain separately named
non-model evidence. Completing a graph after SKIP operations demonstrates graph
termination only; it does not establish that the requested structure was drawn
or that the model has useful artistic behavior.

The episode journal retains the original observation, candidates, decision,
host acceptance/refusal, native response and outcome for each step. Offline
record validation and fresh native replay are separate checks. Replay must
execute the recorded choices through the same host/native authority and compare
original material states; reading a saved JSON success flag is insufficient.

An explicit reset may open a new episode after an earlier Stop. Its prior
cancellation fence is cleared by the host before request publication under the
cancellation lock. Native dispatch never clears cancellation: a later fence must
refuse fixture admission, preserving the existing generation and material bytes.
The real regression freezes Godot across this publication boundary to make the
race reproducible. Cancellation after fixture admission is recorded as an actual
interrupted reset, without claiming that already admitted work never occurred.

## Reproduce the bounded qualification

Cheap offline tests do not acquire model weights or start native processes:

```sh
python3 -m unittest discover -s experiments/driv3r/tests -p 'test_*.py' -v
```

Explicit acquisition verifies the model revision, weight bytes, runtime archive,
extracted libraries and licenses before creating a reusable runtime manifest:

```sh
python3 -m experiments.driv3r.backend acquire --runtime-dir /tmp/driv3r-runtime --evidence /tmp/driv3r-acquisition --timeout-seconds 1200
```

The independent [Stage A workflow](../../.github/workflows/driv3r-stage-a.yml)
runs heavy work only on manual dispatch or a deliberate change to its exact
`experiments/driv3r/qualification-request.json` on the dedicated branch.
Ordinary PR updates run offline tests. The strict request freezes Stage A,
foundation, accepted base, Q8 identity and prohibitions on training, schedules
and production-default changes. No #568 workflow or training lease is changed.

[ci_stage_a.sh](../../experiments/driv3r/ci_stage_a.sh) builds current native source
using the existing pinned dependencies, stamps that build, verifies official
Godot4.7/Rapier and invokes the isolated qualification entry point. Source
custody additionally includes every DRIV3R input. A retained source-compatible
binary may be used for explicitly labeled local diagnostics; it is not relabeled
as a fresh qualified build.

The execution report must distinguish A1 infrastructure ownership, A2 genuine
inference, A3 resident hosting, A4 reusable controller, A5 native direct drive,
A6 native fuzzy tools, A7 bounded cancellation/refusal and A8 replay/provenance.
Each gate is PASS, FAIL, PARTIAL or BLOCKED with original supporting evidence.
None passes merely because code exists or an Actions job is green.

The [provenance helper](../../experiments/driv3r/provenance.py) preserves immutable
source/tree and input hashes, validates explicit requests, and creates a
readback-verified evidence ZIP and integrity manifest. Failed attempts retain
their original files. Successful campaign publication is a research prerelease,
not a production release, merge or independent acceptance decision.

## Continuation boundary and documentation map

Stage A ends after the small inference/native demonstrations and safety,
replay, resource and cleanup qualification. Direct-drive feasibility and
fuzzy-tool feasibility must be reported separately using actual outcomes and
cold/warm CPU measurements. Windows, graphical Codespaces, reference probability
parity and broad authoring quality are not established by Linux headless tests.

At the Stage A checkpoint, Stage B microtask research and Stage C expansion
required further Owner direction. The later [Stage B continuation](driv3r-stage-b.md)
records that explicit authorization and the conditional C gate. Model training,
scheduled workers and production integration still require further Owner direction.
The shared native authority and model-hosting code should retain one integration
owner while independent future policies, fixtures and evaluations use versioned
interfaces. Do not close #570 or advance the Draft automatically.

| Documentation obligation | Disposition |
|---|---|
| Controller/interface/lifetime/capacity | This guide owns the opt-in contract; executable limits and pins remain in the linked source files. |
| Shared native and authoring authority | Existing Art, authoring and #568 guides remain canonical and unchanged. No new native production API or material law is introduced. |
| Defaults, user controls and platform | No production launch control or default changes; this is an explicitly invoked Linux/POSIX harness. |
| Current status and navigation | Documentation index, roadmap, handover and retrieval index link this candidate without asserting completed gates. |
| Retrieval | The explicit corpus includes this guide; additive DRIV3R questions are separate from the unchanged frozen questions. |
| Actual evidence and owner decision | The source-qualified Stage A report and #570 ledger own execution results, failure history, measured costs and the next-stage checkpoint. |
