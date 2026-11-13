# WB-ART-SLM-001: actual local training

This directory implements a bounded completion-only LoRA trainer, strict model inference, declared baselines and checkpoint verification. It is a new experiment; it neither reuses nor promotes adapters from earlier NeuroRunner lanes.

## Model lineup

`model_profiles.json` fixes full official revisions and separates Sprocket Instruct from its `chat/` checkpoint. The first CPU bootstrap uses **LiquidAI/LFM2.5-350M**. LFM3-1.7B remains a separate planned GPU candidate, not an alias for the executed model. SmolLM2-135M-Instruct is the smallest independent reference, with 360M optional. A profile is executable configuration, not evidence that the model has been trained or evaluated; only run receipts establish that.

The primary sources are the exact revision URLs in the profiles. Base-model licenses are downloaded and copied beside each adapter. No model weights, optimizer states or environment directories belong in git.

## Environment and model download

The tested bootstrap runtime is Python 3.12, CPU PyTorch, Transformers and PEFT. `requirements.lock` records the exact installed environment. For CPU installation, install the recorded `torch` build using the official CPU wheel index, then install the remaining locked packages from PyPI; do not accidentally install CUDA wheels on a CPU worker. Example with `uv`:

```bash
uv venv /path/to/private/runtime/venv
uv pip install --python /path/to/private/runtime/venv/bin/python --index-url https://download.pytorch.org/whl/cpu torch==2.15.0+cpu
uv pip install --python /path/to/private/runtime/venv/bin/python -r requirements.lock --extra-index-url https://download.pytorch.org/whl/cpu --index-strategy unsafe-best-match
/path/to/private/runtime/venv/bin/python download_model.py --profile lfm2_5_350m --output /path/to/private/models/lfm350
```

The downloader resolves the pinned commit, selects the exact root/subfolder variant, downloads trainable safetensors plus tokenizer/config/license files, and writes checksums. LFM3 custom architecture code is only executed when the operator explicitly supplies `--trust-remote-code` against the locally pinned snapshot. The bootstrap uses no such custom-code switch.

## Corpus admission and token handling

Only admitted `train.jsonl` and `dev.jsonl` are accepted. Every row must have the correct split, native qualification, successful receipt, matching operation hash, no outside-focus violations, positive acknowledgement and explicit visual-review admission. The trainer verifies exact split-file hashes, admission/manifest/compiler identity and disjoint structural group IDs. `final.jsonl` is not read by the trainer.

`system_prompt.txt` defines a compact schema without providing the reference theme-to-motif mapping. Both untuned and adapted models receive that identical system prompt and their official pinned chat template, with `enable_thinking=False`. The trainer checks full prompt/completion token boundaries, masks the prompt, preserves completion EOS even when PAD equals EOS, rejects oversized examples, and never truncates a target. There is one unpadded sequence per microbatch; `--accumulation` controls the effective optimizer batch.

## Bounded training and resume

Run from this directory, substituting private absolute model/run paths:

```bash
python train_lora.py --train ../corpus/train.jsonl --dev ../corpus/dev.jsonl --admission ../corpus/admission.json --corpus-manifest ../corpus/manifest.json --compiler ../controls/pattern_compiler.py --model /path/to/private/models/lfm350 --model-id LiquidAI/LFM2.5-350M --revision 9921cd4d82c0e3986887aa4b376f9446729ef8a3 --output /path/to/private/runs/lfm-stage1 --steps 26 --checkpoint-every 25 --eval-count 24 --max-seconds 1800 --threads 3
```

`--steps` is the total global target including resumed steps. `--max-seconds` bounds optimizer work with a checkpoint margin; baseline/final evaluation and model loading are separate measured costs, so an external hourly worker must reserve time for them. SIGTERM requests a clean stop after the current optimizer step. A shared file lock serializes model training in a common run-parent directory. CPU uses FP32; CUDA checks native BF16 support and otherwise uses FP16 with a saved scaler. Actual linear module names are inspected before constructing LoRA. Only LoRA-owned parameters may be trainable, and all frozen base bytes are hashed before and after training.

Each checkpoint contains the adapter, tokenizer, inference contract, base-model license, optimizer, scheduler, scaler, all RNG states, deterministic sampler cursor, global step, loss history and checksummed inventory. Resume verifies the inventory **before** loading state and rejects changed data, model, template, training settings, numerical runtime or a non-increasing step target. Checkpoints are atomically published and never overwritten.

To test exact continuation, let the initial process run uninterrupted through step 26 while saving step 25, then start a fresh process with `--resume .../checkpoint-000025 --steps 26 --output /different/private/run --skip-baseline --skip-final-eval`. Compare its step-26 checkpoint with the uninterrupted one:

```bash
python verify_resume.py --uninterrupted /path/to/first/checkpoint-000026 --resumed /path/to/replay/checkpoint-000026 --output /path/to/private/resume-verification.json
```

This compares adapter tensors, optimizer/scheduler/scaler, RNG states, cursor, step, loss and gradient norm. Exact continuation is only claimed if the executed comparison passes in that pinned runtime; it is not a cross-hardware guarantee.

## Opt-in balanced keyword replay — 13 November 2026

The frozen CPU FP32 step-400 LFM adapter and its exact 25→26 resume proof are
preserved. A **new**, non-default sampler `--curriculum keyword-replay-v1` is
implemented in `curriculum.py`, with a separate input-bound exposure audit in
`curriculum_exposure_audit.json`. It changes **training sample order only**,
not the target programs, train/dev/final split, compiler, host seed or Art
execution. The original `shuffled-v1` permutation remains the default and is
checked against the bootstrap's exact sampling algorithm.

The new schedule presents one admitted literal-word row for each of the twelve
themes in its first twelve examples, then replays one word every sixteen
subsequent samples while filling the other positions from a deterministic
epoch-specific shuffle of nonkeyword **train** rows. Its epoch length is
unchanged (1,152 samples); replay deliberately displaces some unique samples.
It rejects missing/duplicate keyword rows and any dev/final split contamination.
The global sample cursor and seed/epoch reconstruct the exact order on resume.

On the **actual admitted 1,152-row corpus** (SHA-256
`972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66`),
with seed 731 and the first 400 samples:

| Measure | Frozen shuffled-v1 | New keyword-replay-v1 |
| --- | ---: | ---: |
| Literal-word themes encountered | 6/12 | 12/12 |
| Literal-word samples | 6 | 36 (3 per theme) |
| Distinct example IDs | 400 | 376 |
| Structural training groups represented | 72 | 70 |
| Minimum/maximum requests per theme | 24–39 | 27–41 |

This is an **executed sampler/corpus audit**, not new LoRA adaptation, a
model-family ranking, native execution or evidence of greater recognition.
The tradeoff (24 fewer distinct examples and two fewer training groups within
400 samples) must be monitored against the fixed development benchmark.

Only a genuinely fresh private output directory may use the new policy. It
pins the policy, sampler-source SHA-256, trainer-source SHA-256 and existing
corpus/model/template/compiler identities in full checkpoints. Attempting to
resume the original `shuffled-v1` checkpoint with the new policy is rejected.
To run the **next authorized local** CPU study with the exact accepted
model/corpus inputs already restored, add:

```bash
--curriculum keyword-replay-v1 --steps 400 --skip-baseline \
--max-seconds 1950 --checkpoint-every 25
```

to the existing `train_lora.py` invocation; supply an unused private
`--output` directory, observe its shared parent lock and external
whole-process deadline, and save full checkpoints outside Git. **No such
training job was launched at this checkpoint**: this runtime has the archived
step-400 adapter, full resume state and admitted corpus, but not the pinned
frozen base model or the bootstrap's Transformers/PEFT runtime. Do not
automatically retry unchanged inputs hourly.

Before treating the candidate as an improvement, compare both programs on the
**same fixed 24 development IDs** and all twelve literal words with identical
prompt/template/compiler/greedy decoding, token cap, seed and output budgets.
Report raw JSON, first-pass EOS acceptance, theme, primary motif, ordered
motif/layout, full-program target, native replay and blind visual recognition
separately. In particular examine prior `veins`→orthogonal,
`ribs`→ruins and the two malformed coral decimal responses. The untouched
final assessment is not a repair set. Fair Sprocket/SmolLM2 comparisons will
also require matched fine-tuning budgets; their zero-shot baselines are not
equal-training comparisons.

The five curriculum unit tests cover legacy-order equivalence, balanced
replays, deterministic cursor restoration, exact corpus exposure and failure
of invalid split/keyword inputs. Run
`python -m unittest -v test_curriculum.py` from `training/`, alongside the
existing training guards. A future model run must still respect a
whole-process budget with saving/evaluation margin and a single shared
role lease.


## Whole-process supervisor and durable role lease — 13 November 2026

For the **next** authorized model-training run, use **job_guard.py** instead of
launching a direct unbounded training process. This is a local supervisor, **not**
a GitHub Actions model-training workflow. It holds the same nonblocking OS
wb-art-slm-training.lock as direct trainer invocations, plus a durable
wb-art-slm-training.role-lease.json containing supervisor/child process IDs,
a role token and heartbeat. The child can bypass its own lock only when its
real parent and token match that active role lease. All candidate outputs
must be direct children of **one designated private run parent**
outside the source tree; do not evade the lease by choosing another parent.

The supervisor fingerprints complete trainer arguments (excluding the
private output path), exact train/dev/admission/manifest/compiler bytes,
model snapshot bytes and pinned download receipt, template/source code,
numerical package environment and resume inventory if supplied. It refuses
altered base bytes, mismatched official model identity, duplicated arguments,
non-absolute private paths and **any unchanged previously attempted
fingerprint**, including after a crash. A new output name is not a retrain
authorization. A resumed run requires a valid different checkpoint identity;
changing inputs/fingerprints by itself does not authorize unrequested training.

Example **only after the original pinned base/runtime are genuinely available**
on one authorized local machine; every path below is private and absolute:

    python job_guard.py --run-parent /private/wb-runs \
      --wall-seconds 3300 --save-margin-seconds 300 -- \
      --train /private/corpus/train.jsonl \
      --dev /private/corpus/dev.jsonl \
      --admission /private/corpus/admission.json \
      --corpus-manifest /private/corpus/manifest.json \
      --compiler /source/experiments/wb-art-slm-001/controls/pattern_compiler.py \
      --model /private/models/lfm350 \
      --model-id LiquidAI/LFM2.5-350M \
      --revision 9921cd4d82c0e3986887aa4b376f9446729ef8a3 \
      --output /private/wb-runs/lfm-keyword-replay-400 \
      --curriculum keyword-replay-v1 --steps 400 \
      --checkpoint-every 25 --max-seconds 1950 \
      --skip-baseline --skip-final-eval --threads 3

The whole child process, including model load, optimizer, checkpoint and any
in-process evaluation, receives at most **3,300 seconds**. At 3,000 seconds,
the parent sends graceful SIGTERM (Windows console break where supported);
at the hard deadline it terminates the child process group. A clean checkpoint
is *attempted*, not guaranteed if a step or filesystem hangs.
The parent validates the saved checkpoint inventory and reports completed,
stopped_early, deadline_killed or failed honestly. An early-stop checkpoint
cannot be counted as a completed 400-step candidate. The wrapper writes private
guard_start.json and guard_result.json evidence beside the model output.
No step-400 bootstrap files are overwritten.

For this CPU study the example skips in-process final evaluation to preserve
checkpoint headroom. The separate heavy evaluator is now **fail-closed behind the
same supervisor**: direct `evaluate_model.py` execution refuses to load a model.
It shares the training run-parent lock, parent/PID-bound random-token lease, duplicate
fingerprint denial and 3,300-second maximum process deadline. The supervisor
hashes all base files, adapter files, receipt, compiler, dev/admission/manifest,
source, template and runtime both before and after evaluation. Missing/truncated
raw predictions, mismatched counts, changed input bytes or partial output are
not scored as completed. A deadline stop preserves any raw partial records but
never converts them into accepted predictions. This does **not** qualify model
quality, native replay or a real Windows process-tree termination.

Use an **unused** output child of the same designated private run parent for
each authorized suite. The following command is illustrative and requires the
actual pinned model, adapter, admitted corpus and runtime to be present:

```bash
python job_guard.py --run-parent /private/wb-runs \
  --wall-seconds 3300 --save-margin-seconds 300 \
  --worker-script ./evaluate_model.py -- \
  --model /private/models/lfm350 \
  --adapter /private/wb-runs/lfm-keyword-replay-400/checkpoint-000400/adapter \
  --dev /private/corpus/dev.jsonl \
  --admission /private/corpus/admission.json \
  --corpus-manifest /private/corpus/manifest.json \
  --compiler /source/experiments/wb-art-slm-001/controls/pattern_compiler.py \
  --output /private/wb-runs/lfm-replay-dev24 \
  --suite dev --eval-count 24 --max-new-tokens 256 --threads 3
```

Run `--suite keywords` in a different output directory after inspecting the
first result; all twelve words are training-word diagnostics, not final holdout.
All listed data/model/output paths must be absolute. Only Training may launch
this heavy evaluation, and **only one shared parent** may be used. The guard
writes `guard_start.json`, `guard_result.json` and a durable
`wb-art-slm-training.role-lease.json`; successful raw evidence includes the
observed request count, strictly counted first-pass acceptances, prediction
and summary SHA-256 hashes and explicit `native_execution=false` and
`visual_acceptance=false`. Failed and partial attempts remain in the
duplicate-attempt ledger rather than being retried at each hourly check.

**Qualification:** The preceding training-only supervisor passed **10/10**
offline Linux/Python 3.13.5 subprocess tests, including real lease handshakes,
cross-process locking, duplicate refusal and soft/hard deadlines. The new
evaluation guard adds **10 dedicated synthetic test methods** for complete
receipts, raw/summary mismatch, partial evidence, changed adapter bytes,
post-run custody drift, cross-role lock, duplicate attempts, unleased CLI
refusal and deadline termination. Seven isolated helper checks were
successfully run on a locally recreated helper (not the complete published
supervisor); the combined 20-test exact-source subprocess suite still requires
execution. Run
`python -m unittest -v test_job_guard.py test_evaluation_guard.py` from this
directory before authorizing real training or evaluation. No LoRA optimizer,
real base-model evaluation, GPU, native World, Windows or human visual pass is
claimed from these mock tests.
Real Windows process-group stopping and large-model checkpoint-save timing
remain unqualified.

## Separate baselines and development evaluation

`baseline_keyword.py` declares its simple behavior: one literal theme word selects the fixed centered reference recipe; modifier/layout language is ignored. It separately records the twelve exact-word compiler sanity cases. It never impersonates model output.

The untuned base and LoRA use the same deterministic balanced development IDs, greedy unconstrained decoding, and token limit. Reports separate JSON validity, compiler validity, complete first-pass acceptance with EOS, theme-field correctness, primary motif correctness, exact motif/layout sequence and exact reference program. Theme-field correctness alone says nothing about visual theme quality. A prediction becomes a native replay candidate only after strict JSON validation, schema/budget checks and EOS. No grammar constraint, substring extraction, JSON repair or keyword fallback is applied.

`evaluate_model.py` runs an independent pinned base without creating or training an adapter. Supply `--adapter` to evaluate a saved adapter. Its default `--suite dev` uses the same balanced development selection; `--suite keywords` separately checks the twelve exact theme words and labels them as training-word sanity cases, never as a held-out test. SmolLM and Sprocket baseline processes should run sequentially after unloading the previous model so the small worker's memory is bounded.

`export_native_cases.py` converts accepted model output into replay cases with prompt, raw completion, program and operation hashes. Native replay, focus/source protection, history/readback, storage and visual review remain the native harness's responsibility; the trainer never claims these checks merely because JSON compiled.

## Strict inference

```bash
python infer.py --model /path/to/private/models/lfm350 --adapter /path/to/checkpoint/adapter --prompt roots --seed 73 --width 96 --height 96 --output /path/to/new/inference-result
```

The inference CLI verifies the exact base files, model revision, adapter contract, template and compiler hash. It loads the trained adapter, applies the same system prompt, emits the raw completion and receipt, and writes `program.json`, `compile_report.json` and `art_batch.json` only if the output passes. The host seed controls deterministic geometry variation. This CLI saves a plan; it does not mutate CyberSand. Existing native executor validation and user authorization still govern execution.

## Evidence and limitations

Actual run metrics, checkpoint checksums, baseline/adapter predictions, native cases and training receipts are retained outside git and delivered as separate artifacts. Repository reports should summarize those receipts rather than manufacture a successful run. The initial task teaches a small pattern-program language; it does not establish object drawing, arbitrary tool use, unseen motif synthesis or production readiness. Training/dev/final groups separate theme/motif/layout arrangements, while primitives are shared. Use the sequestered final split once a candidate and its selection rules are frozen.

Run the small guard suite with `python -m unittest discover -s . -p 'test_*.py'`. It addresses the concrete failure modes of unqualified data, held-out split access, family leakage, ordered evaluation bias and repaired/nonstandard JSON acceptance. The real tokenizer preflight and actual checkpoint continuation provide the training-specific verification.


## Strict native replay export and original-ID aliases — 13 November 2026

`export_native_cases.py` now bounds every exported `case.id` to **38 safe
ASCII characters**, because the frozen native replay harness prefixes
`slm-pilot-` and the Workbench save-name limit is 48. Short safe IDs remain
readable. Long/unsafe original prediction IDs receive a deterministic
SHA-256-derived alias; `case_id_aliases` maps every replay ID back to its
unaltered original prediction ID, original candidate name and seed.
Collisions and duplicate original IDs fail closed.

Only rows with explicit first-pass acceptance, valid JSON/program and an
emitted EOS are eligible. Their original completion bytes and symbolic
program are not repaired. Both requested host seeds must compile before
either is added for a request; rejected or unterminated requests remain in
`excluded_predictions` and the request-level `counts` denominator. Existing
output files are never overwritten. This changes **fixture export only**;
native Art remains the drawing authority.

**Executed qualification:** `python -m unittest -v test_export_native_cases.py`
passed 9/9 model-free tests on local Python, covering long Unicode IDs,
38-character custody, original-ID aliases, EOS rejection, malformed coral-like
JSON, duplicate IDs/seeds, immutable completions and two-seed atomicity.
Recovered the exact saved `wb_art_slm_001_native_and_model_evidence.zip`
with verified archive SHA-256 `d2f8b16f081b7c371afd2eadf1468bc6941cb2a7a83ee349a11d667257f9cfa9`.
Re-exported its actual 24 development and 12 keyword prediction records
against the **archived original compiled reports**, not a newly executed
compiler. The measured export is 22/24 development, 12/12 keyword strict
requests, 68/68 uniquely bounded native IDs, 22 deterministic aliases and
68/68 operation digests/raw completions exactly matching archived model-native
cases. The two malformed coral development requests remain rejected.
See `native_export_frozen_audit.json` for exact inner-archive and evidence hashes.

This audit is an **offline replay-fixture transformation check**. It cannot
claim a new raw-model gain, independent compiler execution, native runtime
qualification, current-main/Windows acceptance or visual recognition.
Next, run the current exact-source combined 20-method train/eval supervisor
suite and, when an authorized pinned compute host is available, perform the
one guarded balanced-keyword training candidate and fresh native replay.

## Independent raw evaluation custody — 13 November 2026

A new, **Training-only opt-in** evidence guard now checks more than reported
summary counts. The model evaluator records whether EOS was **last** in the
generated token sequence (distinct from whether EOS appeared anywhere).
Its supervised completion receipt is refused when the raw JSON, duplicate
fields, terminal-EOS assertion, compiler acceptance, generated Art operation
count or theme/primary motif/ordered layout/full-target flags disagree.

The evaluator separately recompiles **the unmodified raw program** with the
exact pinned pattern compiler at 96×96 and the recorded seed. It recomputes
the fixed balanced development or twelve-keyword selection from the pinned
development input/compiler, and binds each prediction to the exact ordered
ID, prompt, structural group, theme, expected completion and seed. Failing
raw requests remain in the denominator; no repair, reference substitution or
native-success credit is permitted. Source/template/compiler/model/adapter
fingerprints and the shared training/evaluation role lease remain enforced.

The preserved [archived raw-program audit](archived_raw_program_audit.json)
was executed on newly recovered, whole-file-SHA-verified bootstrap archives,
not on synthetic substitute predictions. The archived 24 development and
12 exact-word raw completions were independently strictly parsed and
compiled using archived compiler SHA-256
`a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb`,
with exact reference ID ordering and independent motif/layout scoring.
All **36/36 source identities and 36/36 sets of saved raw/compiled/semantic
claims agreed**. This reproduces 22/24 development and 12/12 keyword
strictly compiled programs, with both malformed coral numbers and the
veins/ribs routing errors retained.

**Qualification boundary:** historical outputs lack the newly recorded
`eos_terminated` token-position field (36/36), so the new guard intentionally
cannot retroactively certify their terminal token position. Their original
22/24 and 12/12 first-pass acceptance values remain *historical declarations*,
not a fresh decoder/EOS result. The new model-free regression methods (including malformed non-object evidence) in
`test_evaluation_guard.py` cover altered raw completion, forged EOS, changed
motif flags, mismatched Art operation counts, changed sample IDs, swapped
reference targets and token-cap overflow. Three isolated synthetic checks
of the raw helper passed locally; the **full combined exact-repository
subprocess suite has not been run** on this new branch head. An integration
intake must run it independently before qualifying the change.

The frozen 400-step LFM adapter and exact 25→26 resume proof are untouched.
The next candidate still requires one authorized pinned local base/runtime,
inspection of the designated private role lease and one new keyword-replay
training attempt. No new model, GPU, native/Windows runtime, provider-default
change or promotion is implied by this offline verification.


## Training custody and orphan-lease hardening — 13 November 2026

The local training supervisor now checks the **complete pinned base-model file
inventory**, not just the files still present on disk. A missing official model
file is rejected before model loading. A full-resume attempt independently
verifies **every checkpoint artifact** against `inventory.json` before launch,
and binds each resume artifact's SHA-256 into the supervised run fingerprint.
After child exit, the training guard fingerprints its model, corpus, resume and
source inputs again. A changed or missing input marks the run **failed** even
when an otherwise internally valid checkpoint reached the target step; original
checkpoints and raw evidence remain in place for diagnosis, never credited as
an unchanged first-pass model candidate.

The shared lease also refuses a new attempt if an earlier role lease is
unfinished, missing a known terminal state, or unreadable. The OS file lock by
itself cannot prove an optimizer child died after a supervisor crash. **Do not
simply delete or reset an unfinished lease:** inspect the recorded parent and
child processes, confirm all descendants are stopped, and preserve the prior
run's evidence before a manual recovery. This applies to both training and
heavy evaluation. Terminal attempts retain the existing fingerprint ledger
and duplicate-attempt protection.

Five additional offline regression methods were added to
`test_job_guard.py` (15 Training and 14 Evaluation tests are now discoverable,
29 total); the two mutation modes independently test post-run base and corpus
drift. **Exact-source execution of the expanded 29-method suite is still
pending.** Source publication and test definitions alone do not establish
PASS. No new optimizer step, fresh neural prediction, native replay, GPU or
Windows acceptance was performed for this hardening.


## POSIX process-lifetime fencing for Training — 13 November 2026

The supervised optimizer/evaluator starts its worker in a new POSIX session,
but the original supervisor only watched its immediate child PID. A completed
child or a parent that exits promptly on SIGTERM does **not** prove that another
same-session process has terminated. A signal-resistant descendant could
otherwise perform a late write after `guard_result.json` and the shared lease
reported a terminal job, allowing the next candidate to begin.

The supervisor now sends POSIX process-group signals without short-circuiting
on `Popen.poll()`, and performs a final bounded TERM-to-KILL sweep against its
**owned** process group before writing terminal status and releasing the lease.
This applies after success, graceful Stop, hard deadline or a worker exception.
No material/physics/native Art behavior or model defaults change. A process
that deliberately creates a *different* session and Windows descendant
process trees are **not** covered by this qualification; those require
separate platform-specific ownership and testing.

`test_job_guard.py` adds two Linux-only synthetic subprocess regressions:
a normal parent exit with a SIGTERM-resistant descendant and a soft Stop where
the child survives its parent. Both wait beyond the descendant's delayed-write
deadline and refuse any late output. The focused behavioral-equivalent Linux
process-group probe passed both cases; **the new exact-source regression suite
has not yet run on this branch**. Training now defines 17 synthetic test methods
and Evaluation 14 (31 combined). Do not label those 31 methods PASS solely from
publication. The pinned step-400 adapter and all raw model metrics are unchanged.
