# WB-ART-SLM-001 bootstrap evidence

Date: 13 November 2026. This checkpoint implements the bounded compiler, an
executed corpus, an actual 400-step LoRA adapter, exact resume evidence and a
260-image native reference/model gallery. **The bootstrap is complete; production
promotion remains HOLD.** Source is in [Draft PR #567](https://github.com/techrote/cybersand/pull/567).

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

The executed candidate is **LiquidAI/LFM2.5-350M**, pinned at
`9921cd4d82c0e3986887aa4b376f9446729ef8a3`. The run loaded 354,483,968 frozen
base parameters and trained 5,996,544 LoRA parameters through **400 updates**.
It used CPU FP32, three threads, rank 16, alpha 32, dropout 0.05, learning rate
0.0005 and completion-only supervision. No paid compute or reachable GPU was
used. Torch 2.15.0+cpu, Transformers 5.22.2, PEFT 0.21.2 and Accelerate 1.15.0
are recorded in the checkpoint.

The run consumed 400 shuffled training examples, 124,078 input tokens and
27,447 supervised target tokens. Cumulative training-step time was 1,132.69
seconds; the final continuation process including its evaluation took 1,253.90
seconds. That process resumed at step 26, so its wall time is not the complete
bootstrap duration. Final peak RSS was 4,100,440 KiB, approximately **3.91 GiB**.
The complete frozen-base digest was unchanged.

The fresh-process 25→26 continuation matched the uninterrupted result exactly
for adapter and optimizer tensors, scheduler/scaler, Python/NumPy/Torch RNG,
sample cursor, loss and gradient norm. This proves the tested continuation in
the pinned runtime; it does not promise cross-hardware bitwise equality. The
full step-400 resume archive includes optimizer, RNG and cursor state, rather
than adapter weights alone.

Raw final adapter SHA-256:
`02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2`.

### Measured quality

Every result below uses greedy unconstrained generation, strict JSON, the
compiler schema and completion termination. No repair or reference fallback
receives model credit. Development selection was fixed by SHA-256 ID within
each theme, round-robin across themes; 24 requests cover two per theme. This is
a small development sample, not the untouched final assessment.

| Measurement | Untuned LFM, 24 development requests | Step-400 LFM, same 24 | Step-400 LFM, 12 literal words |
| --- | ---: | ---: | ---: |
| Strict accepted program | 0/24 | **22/24** | **12/12** |
| Correct declared theme | 0/24 | 22/24 | 11/12 |
| Correct primary motif | 0/24 | 22/24 | 11/12 |
| Correct theme and primary motif together | 0/24 | 22/24 | **10/12** |
| Exact ordered motif/layout structure | 0/24 | 19/24 | 11/12 |
| Exact full reference program | 0/24 | 13/24 | 8/12 |

The two development failures are coral responses with invalid leading-zero
numeric literals (`0595931`, `031`, `05959`). Their full raw completions remain
in the evidence and were never executed. On literal words, `veins` declares the
right word but chooses `orthogonal` geometry; `ribs` chooses rib geometry but
incorrectly labels the program `ruins`. Native execution does not make these
semantic mistakes correct.

The literal words are a training-vocabulary sanity check, not unseen test
prompts. Only six of the twelve literal rows occurred in the first 400 shuffled
examples. The `ribs` row occurs at step 648 and `veins` at step 1,075; longer
training requests for both themes were seen. This supports a curriculum
hypothesis, not a causal conclusion. A new candidate should guarantee early
exposure to all twelve existing training rows. It must not add held-out coral
split/composition targets to training. Constrained decoding is a separately
reported experiment and does not solve semantic routing by itself.

The trained development run generated 1,567 tokens in 118.68 seconds, about
4.95 seconds per request on this CPU. The untuned run generated 4,792 tokens in
317.88 seconds. These are generation timings with different response lengths,
not controlled throughput or complete Workbench interaction latency. A fresh
standalone `infer.py` call for `roots`, seed 73, generated 49 tokens and 31 Art
operations; its program and operations exactly match the frozen native case.

### Sprocket and other tiny-model baselines

| Candidate | State | Same fixed 12 development IDs: accepted |
| --- | --- | ---: |
| LFM2.5-350M | Unadapted baseline executed | 0/12 |
| LFM2.5-350M + this LoRA | 400 updates executed | **11/12** |
| SmolLM2-135M-Instruct | Unadapted baseline executed | 0/12 |
| Sprocket-500M root Instruct | Unadapted baseline executed | 0/12 |
| Sprocket-500M `chat/` checkpoint | Separate pinned profile; not executed | — |
| SmolLM2-360M-Instruct | Optional pinned profile; not executed | — |
| LFM3-1.7B | Pinned larger accelerator candidate; not executed | — |

The matched subset contains one request per theme. Official model-specific
chat templates, the same system prompt, greedy unconstrained decoding, a
256-new-token cap and CPU FP32 were used. This is a custom-protocol baseline
comparison with one adapted model, **not a ranking of equally fine-tuned model
families**. Sprocket root Instruct and its Chat subfolder remain separate
identities. The workers should compare adaptation under matched example/token
and compute budgets before choosing a winner. The exact pins are in
[model_profiles.json](training/model_profiles.json).

## Native replay of model output

| Cohort | Original requests | Accepted programs | Two-seed native passes |
| --- | ---: | ---: | ---: |
| Development sample | 24 | 22 | 44/44 |
| Literal-word sanity | 12 | 12 | 24/24 |
| Total | 36 | 34 | **68/68** |

Each raw model completion is bound to its program, independently recompiled
operation list, adapter identity, host seed and native receipt. This chain
passed 408 additional checks. The model packet passed 1,398 engine assertions,
329,761 independent native receipt/readback checks and all 15 global gates.
Zero out-of-focus changes and zero unexpected material IDs were observed.
Twelve theme representatives passed exact Undo/Redo/save/reopen.

All 34 accepted programs have different outputs at seeds 17 and 73. There are
66 distinct readbacks across the 68 cases; cross-request overlaps are retained.
The model-native result is 34/36 accepted-and-executed original requests, not
68 independent successful requests. Only 32/36 also match both the expected
symbolic theme label and primary motif. The final 192 examples remain untouched
by model evaluation.

The first native attempt is retained as failed: its long evidence IDs exceeded
the Workbench saved-name length limit after adding `slm-pilot-`. The retry uses
aliases of at most 38 characters with an original-ID map. It changes no model
completion, program, compiler operation or runtime source. The first draw's
readback and PNG exactly match between attempts.

The assistant inspected all 68 model images, and the atlas now contains all
192 teacher images plus these 68 replays. Wrong labels and motifs are flagged.
The same coral crowding, narrow-border compression and sparse canvas use remain
quality work. This is provisional inspection, not blind human acceptance.
The image bytes and embedded atlas data were checked; JavaScript syntax passed.
An optional browser rendering probe was blocked by the environment's IPC socket
restriction, so interactive browser execution is not claimed.

## Reusable artifacts and worker handoff

[ARTIFACTS.json](ARTIFACTS.json) records the exact filenames, byte sizes, hashes
and extraction roles for four saved archives: inference adapter, full resume
checkpoint, executed corpus, and native/model evaluation evidence. The evidence
archive includes the original native runtime artifact so expiring CI downloads
are not the only recovery route. Base-model weights are fetched by the pinned
training downloader; they are not duplicated into the adapter ZIP.

The [training README](training/README.md) gives download, inference, evaluation
and resume commands. The delivered CLI converts text to a strict pattern program
and an Art batch. Actual Workbench execution has been demonstrated by the native
harness. A live UI provider binding on current main is still a Controls and
Integration task; the default application provider has not been replaced.

The NeuroRunner ideas carried into this separate experiment are bounded
completion-only LoRA, typed controller output, a controlled curriculum,
immutable candidate identity, full-state resume, independent evidence and
explicit promotion gates. Its frozen NCR experiments, flags and heldouts remain
unchanged.

The five workers have concrete follow-ups:

| Worker | First useful work |
| --- | --- |
| Integration | Maintain one combined Draft #567; consume role checkpoints and qualify the current-main seam while preserving accepted capability changes. |
| Controls | Improve weak morphology and bind the strict compiler to the current Workbench provider with host focus/protection/Stop authority intact. |
| Corpus | Add only justified admitted training variation; ensure all twelve literal rows get early exposure and retain structural split boundaries. |
| Training | Run one bounded curriculum candidate, retain the frozen step-400 reference, then adapt Sprocket/Smol under matched budgets. |
| Evaluation | Replay exact new outputs, keep request denominators and semantic failures, and qualify current-main/Windows plus human recognition separately. |

Only one Training owner may use the shared backend. Each worker reads current
state, uses a durable lease, saves a checkpoint before its whole-process deadline,
and stops on unchanged evidence. Later user pauses and unrelated tasks are
preserved. The registry records the existing hourly offsets and final state.

**Promotion remains HOLD.** The 22/24 development acceptance rate is 91.7%, below
the plan's 95% first-pass target, and the small sample cannot establish a stable
population rate. The 98% native request-yield target, current-main and Windows compatibility,
UI provider binding, final-set assessment and blind/human thematic acceptance
remain open. Windows qualification should use the owner's confirmed executable
`C:\Godot_v4.7-stable_win64_console.exe`. No Ready transition or merge is requested
by this bootstrap.
