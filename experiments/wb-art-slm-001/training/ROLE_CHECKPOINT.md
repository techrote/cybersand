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
