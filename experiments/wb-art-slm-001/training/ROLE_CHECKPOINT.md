# WB-ART-SLM-001 — Training role checkpoint (2026-11-13)

**Owned branch:** `codex/wb-art-slm-training`  
**Pre-checkpoint source head:** `649649c718eefbf653e328a0dc4875e98f50f00e`  
**Integrator's last read checkpoint:** `codex/wb-art-slm-001` at `fc7d8b9114d3b19c8e3037dc9ceabd242f955904`.  
**Shared state/plan/registry:** untouched; Integration owns them. Draft PR #567 remains Draft/HOLD.

## Completed this run

- Recovered all four archived files from the owner's Library using their exact saved filenames; independently verified all four whole-file SHA-256 and byte counts against `ARTIFACTS.json`. The frozen adapter carries LFM2.5-350M revision `9921cd4d82c0e3986887aa4b376f9446729ef8a3`, rank 16, alpha 32 and eight actual LoRA linear targets.
- Inspected the full step-400 continuation ZIP: 10/10 required archived checkpoint files matched its SHA-256 inventory; `receipt.json` reports step/cursor/history 400/400/400. Inspected the original exact 25→26 continuation comparison in the evidence ZIP (13 checks recorded PASS). This **verifies recovery and recorded continuation evidence**, not a newly executed model restore.
- Implemented an **opt-in** `keyword-replay-v1` training sampler, integrated it into the current LoRA trainer with preflight, exact policy/source fingerprints and resume identity checks. `shuffled-v1` remains the default and preserves the old ordering algorithm. Mixed-policy resume is rejected before a base model is loaded.
- Executed an offline audit against the restored, admitted 1,152-row corpus SHA-256 `972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66`. For the first 400 samples, literal-word coverage rises from **6/12 themes (six samples)** to **12/12 themes (36 samples; three each)**. Distinct rows fall 400→376 and structural groups 72→70. This is an **exposure change**, not measured model accuracy.
- Ran five curriculum unit tests on the actual corpus and synthetic adverse inputs: **5/5 PASS** in the local Python environment; `python -m py_compile` of the new source passed. No base model was loaded, no optimizer steps were taken, and no native/Windows/Godot/visual qualification is claimed.

## Evidence, limits and next dependency

See `training/curriculum_exposure_audit.json` for the deterministic original-vs-new first-400 selection hashes, counts and fixed seed; `training/test_curriculum.py` reproduces those counts. The original step-400 adapter remains frozen at SHA-256 `02b9263e543eb464e6b58f1f74960c98d5aec4ec117baddfcf22b4d5dd4c84b2`. Its recorded fixed-development results remain **22/24 admitted, 19/24 exact motif/layout, 13/24 full programs**, with unchanged coral numeric and ribs/veins keyword failures.

**No local model training was launched:** only the saved adapter/full resume/corpus/evidence were available; the pinned frozen base weights and the original Transformers/PEFT runtime were not available in this session. This source-only audit cannot establish an improved model. Also, the existing trainer's `--max-seconds` currently limits the optimizer loop rather than guaranteeing a strict whole-process deadline; the running job has a parent file lock and per-output heartbeat, but a durable cross-run role lease remains to be hardened **before launching the next heavy job**.

**Next owned milestone:** first harden the shared durable lease and whole-process deadline/resume cleanup; restore and verify the exact pinned base/runtime on one authorized host; then execute **one**, and only one, fresh 400-step `keyword-replay-v1` candidate against the same train and 24-development/twelve-keyword benchmarks. Reconcile strict raw success, theme/primary motif, ordered geometry, coral numeric validity, no regression, throughput/RSS and independently replayable native fixture IDs. Do not use the untouched final set for feedback. For a family comparison, first establish matched fine-tuning budgets for Sprocket-500M root Instruct and SmolLM2-135M, not zero-shot vs tuned scores.

The latest #564/#565 remain independently owned Draft upstream work; no native successor was imported or downgraded here. No NeuroRunner files, material laws, physics defaults, native harnesses, PR states or other schedules were changed.

---

## Continuation: enforced local training lease and whole-process deadline

**Published source head:** pending immutable commit from this checkpoint write; preceding
implementation/documents commit a2269b5933cb1075545e0125aef91ff8e7e56d01.
**Integrator consumed training predecessor:** 729343a22e300128d77bb3cfd4475411fef36f15.
**Integrator branch observed:** 1fe52bbda9c656a38e9617326d23fbf7fb2f6730.
Only training-owned files changed. #567 and shared state/registry were untouched.

### Implemented and exercised

1. Added job_guard.py: the parent owns the same OS FileLock as direct train_lora
   launches; durable role lease records PID/child, random token, heartbeat,
   fingerprint and state. The supervised child verifies real parent/token/output
   before bypassing its redundant lock. This retains direct-trainer lock safety.
2. Complete input/candidate fingerprints cover absolute train/dev/admission/
   corpus-manifest/compiler bytes, exact local model snapshot and verified
   download_receipt.json, model ID/revision, source/trainer/template files,
   pinned numerical Python/package platform and resume inventory. Duplicate
   attempts on an unchanged fingerprint are refused across output directories.
   Base model checksum mismatches and source-tree output paths fail closed.
3. A supervised child has a maximum 3,300-second whole-process interval, with
   configurable 300-second default soft-stop/save margin. POSIX sends SIGTERM
   to the separate process group then SIGKILL if necessary; Windows control
   break/terminate is implemented but untested. The wrapper verifies the
   published checkpoint's entire inventory and separates completed target
   steps from a valid but incomplete resumed checkpoint.
4. train_lora.py now uses a shared helper for guarded/unguarded locking; its
   existing first-pass model scoring, true supervised EOS, checkpoint contents,
   and historical shuffled-v1 default are unchanged.
5. Offline subprocess qualification: 10/10 unittest methods PASS, Linux
   Python 3.13.5, real FileLock and fake worker (no model weights). Cases include
   successful complete checkpoint/lease, duplicate attempt rejection, graceful
   SIGTERM with checkpoint, force-kill of SIGTERM-ignoring child, direct-job lock
   overlap rejection, corrupt base-file refusal, forged token rejection,
   model identity mismatch, duplicate flags/relative paths and invalid margins.

**Exact committed blobs:** job_guard.py
0c65fb6614e8436a6afcc80fc09008a09ac3d5aa; test_job_guard.py
ae856841741619fefe106d61967650920d28d754; train_lora.py
cdbbd9f02081fd5646ef13ca3ca4e549e2b95b58; training README
967d0ee3f1d78c4a951642bbf677550ecec6ef7a.
The full test command was
python -m unittest -v test_job_guard.py (plus Python source compilation).
Tests run in a separate temporary local directory with synthetic model and
checkpoint files; they do **not** demonstrate real LoRA training, official-model
loads, Windows Ctrl+Break, production/native Art or adapter accuracy.

### Next dependency-ready work

Recover the pinned LFM2.5 base and exact CPU Transformers/PEFT runtime on an
authorized reachable machine, **inspect the one designated private run parent
and existing role lease first**, and launch at most one *new* 400-step
keyword-replay-v1 run using the guarded entrypoint. Do not relaunch the
original frozen shuffled-v1 step-400 candidate. Verify fully hashed resume,
throughput, RSS, and raw dev/keyword predictions; independently export accepted
unrepaired programs to native replay. One remaining guard follow-on: bring
standalone heavy evaluate_model.py under the same process deadline/role lease;
until then explicitly serialize it and do not claim it is covered by the
training supervisor.

Neither the frozen scoreboard (22/24, 19/24, 13/24), exact 25→26 resume proof,
word failures nor the final holdout were changed. No new training, inference,
native World, GPU, Windows or graphical campaign was executed in this
continuation. The original step-400 adapter and all four user archives remain
preserved. **No measured model-quality gain is claimed.**


---

## Continuation: strict separate-model evaluation under the one shared role lease

**Published training source head before this checkpoint:** `9ea8246cc3bdd0fea5ac3df70b42e0873893280b`.
**Integration checkpoint consumed before work:** `b26bdb2d7fb556dee1ae40104b5cd4425ff7f20e` (one combined Draft #567, still HOLD).
**Main accepted source:** `63f8b1ba6559906fe85f3ad0269aa296e4141d67`.
**Upstream owner branches observed:** #564 `6319ab1d94d85d01c9cdb44d973a92d224bfa9aa` Draft; #565 `d66499ec3409fb657875fca7dbd0f234cf28ca49` Draft.
None was modified, imported, promoted or mistaken for Windows release qualification.

### Dependency-ready implementation

The existing supervised `job_guard.py` now dispatches `evaluate_model.py`
through the **same** private run-parent OS file lock and durable role lease as
LoRA training. Its whole-process deadline remains 3..3,300 seconds, with an
early termination margin and an enforceable final stop. Direct evaluator CLI
execution refuses without a matching parent/token/lease, before model load.
Child-PID binding also now rejects reuse of the lease by another child.

New `evaluation_guard.py` verifies fully pinned official base model contents,
download receipt, revision, adapter contents and adapter-vs-base/compiler
contract, exact development/admission/manifest/compiler bytes,
prompt/template/source bytes, flags and numerical environment. It rejects
unknown evaluation arguments, relative private paths, corrupted or
incomplete model snapshots, changed adapter identity, and repeated identical
attempts under a different output name. **All** input/source bytes are
re-fingerprinted after child exit; midflight mutation invalidates the run.

A `completed` evaluation requires all three unmodified raw artifacts:
`run_config.json`, `predictions.json`, `summary.json`, with matching
summary/record metrics, unique IDs, correct requested suite and complete
request denominator (balanced development count or 12 exact words). The guard
records the original raw-predictions and summary SHA-256, true first-pass
accepted count, and explicit `native_execution=false` /
`visual_acceptance=false`. Missing, truncated or inconsistent output is
`incomplete`, not a neural success; post-run changed inputs are `failed`.
Partial results remain available as diagnostic evidence, never repaired.

An opt-in command and explicit caveats are in the Training README.
**Only training-owned files** were changed. Source code and tests are Git
text; no adapter/checkpoint/binary archive was added to Git. Original
step-400 weights and the 25→26 resume record remain frozen.

### Validation and qualification scope

- **7/7 local Python 3.13.5 helper checks passed**, on an isolated locally
  recreated helper and synthetic files: stable/changed fingerprints, base
  corruption/deletion, consistent raw receipts, missing records and
  inconsistent counts/EOS metrics. These are *helper-level*, not exact-source
  supervised end-to-end process tests.
- **10 new model-free supervised evaluation test methods are published** in
  `test_evaluation_guard.py`: clean completion; partial and inconsistent
  receipts; cross-role locking; duplicate-attempt denial; midflight adapter
  mutation; source/adapter custody; forced deadline; unleased CLI denial; invalid
  arguments. They require an exact-source run before claiming PASS.
- The **previously executed 10/10** training-only mock subprocess tests
  predate these changes; a new combined `python -m unittest -v
  test_job_guard.py test_evaluation_guard.py` run remains required.
- The published branch's source files were read back by Git blob identity:
  `job_guard.py` `696997da4a07bd1b7b63992a163fd89b435f42d3`;
  `evaluate_model.py` `90affe8faf41b1cfaa6924107dddaab4e82d31b3`;
  `evaluation_guard.py` `4f3af43feeacfdcc806cf71675d0fbb12180e217`;
  `test_evaluation_guard.py` `6f29ea129b0d238ff72974b347222c042241c727`.

**Not executed:** real LFM/Sprocket/Smol model inference, additional optimizer
steps, native CyberSand replay, any GPU, Windows or graphic owner acceptance.
The pinned private base/runtime and active private run-parent/lease were not
available to this worker. A published guard is not a quality improvement and
does not change the frozen 22/24 development, 19/24 motif/layout, 13/24 full
target and known coral/ribs/veins failures.

### Next owned action

First run the combined 20-method model-free test suite on the exact training
head (Integration may also independently consume and test the training-only
paths). Then inspect the designated private run-parent lease on an authorized
machine, restore/verify the exact pinned base and runtime, and run **one** new
balanced-keyword candidate, never the original 400-step training again. Use the
guarded evaluator for a fixed 24-development and twelve-word comparison and
export only strict unmodified accepted predictions with all failures retained.
Sprocket root Instruct and Smol135 need matched training budgets before any
family ranking. Do not use the final 192 cases for this repair loop.


### Final evidence-custody correction to this continuation

The separate evaluator's `completed` receipt was strengthened again to bind
`run_config.json` to the exact official `model_id` / 40-character revision,
root-vs-chat profile/subfolder, compiler/admission/development SHA-256, actual
adapter safetensors SHA-256, token cap and declared greedy/no-repair decoding.
The model/adapter/corpus also receive the independent full pre/post fingerprint
check described above. The offline fake evaluator now publishes these identity
fields and retains dedicated receipt-mismatch/adapter-tamper regressions.
The development-hash parentheses typo introduced during this tightening was
caught in local Python parsing and corrected on the published branch before
handoff (commit `855a7fadb1ef84292bfb1c52a47063fdf2854db1`).

The latest **isolated local helper implementation** was compiled and **7/7
synthetic helper checks passed** on Python 3.13.5, including both the tightened
valid receipt and rejected inconsistent receipts. This does not substitute for
the combined **20-method exact-source** process-test execution, which has not
yet been run. The previous file blob references above remain historical:
updated `evaluation_guard.py` is
`61a0984a2086bf1ab1400897bb440c559644fbd9`, and updated
`test_evaluation_guard.py` is
`b91e4f69c6c0016aea67dd5bee1d07e87e9c4245`.
README was revised to describe the random, parent/PID-bound token without
mischaracterizing it as a signature.

**Training branch pre-final-checkpoint head:** `06d61926d28615ab63725c683e8db1dfb8c1a2fc`.
Only Training files changed. No heavyweight job was launched, and the
combined owner-facing PR remains Draft/HOLD without modification.
