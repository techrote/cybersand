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


---

## Continuation: native model-prediction export, immutable aliases and archived replay audit

**Observed source before work:** main `63f8b1ba6559906fe85f3ad0269aa296e4141d67`;
Integration `codex/wb-art-slm-001` `5b32671cd283fdb8159f4cb67267fd65742fc6ef`
(one Draft #567, HOLD); Training `c594d154b141ba5c450199311c4a790402eb7c02`.
The #564/#565 owner branches remained independently Draft at their recorded
heads `6319ab1d` / `d66499ec`; no source or qualification was imported.

**Owned implementation:** `export_native_cases.py` now produces bounded,
unique safe native replay case IDs (<=38 chars), preserving readable legacy IDs
where possible and using deterministic SHA-256 aliases otherwise. It publishes
an exact `case_id_aliases` mapping to each unmodified original prediction ID,
full candidate ID and seed. Duplicate source IDs or host seeds are rejected;
each request's full two-seed compile succeeds or it is entirely excluded.
Exporter requires explicit raw first-pass acceptance, JSON/program validity
and EOS; it never repairs completions or writes over existing fixtures.
Request/case denominators and excluded raw IDs are explicit.

**Evidence:** 9/9 Python model-free tests passed locally; exact test and
exporter Git blobs `6e03d5a0cf23771585dd990c1d989f466e3352dd` /
`a61070c1953c4931c20d8c69f86aad53c4b734e6`.
Recovered the recorded saved native/model evidence ZIP and verified
SHA-256 `d2f8b16f081b7c371afd2eadf1468bc6941cb2a7a83ee349a11d667257f9cfa9`.
Its nested model-evidence ZIP is
`48c6b8d536c74de3191f39564c0e304cfa4216d022d09ff035586ccd2b997a4f`.
Using the archived compiled reports as fixed lookup receipts, the original
24 dev + 12 keyword *actual model predictions* yielded 22/24 + 12/12
strict eligible requests, **68 distinct <=38-char replay IDs, 22 aliased,
68/68 archived operations SHA-256 and exact raw completion matches**.
The two coral numerical failures remain in the 36-request denominator.
Audit custody, hashes and limits: `native_export_frozen_audit.json`.

**Qualification limits:** Model-free unit tests and an archived-output lookup,
not actual fresh compiler execution or native World replay. No new LoRA steps,
base-model inference, accelerator, current-main/Windows runtime or human blind
image judgment were executed. Frozen 400-step model metrics and 25→26 resume
proof remain unchanged. Only Training-owned paths were changed; no combined
PR update, production default or other role's files were touched.

**Handoff:** Integration can import the four training-owned files
(`export_native_cases.py`, `test_export_native_cases.py`,
`native_export_frozen_audit.json`, `README.md`) plus this checkpoint
by exact blob identity into the existing Draft #567. Model-free CI should
execute `test_export_native_cases.py` alongside the combined 20 supervised
train/eval methods. Independently rerun the emitted 68-case fixture through
a compatible qualified current-source native Workbench before claiming new
engine acceptance. A fresh balanced-replay model is still blocked on an
authorized local pinned model/runtime/role lease; do not restart the frozen
step-400 candidate or score archived replay as fresh model quality.

---

## Continuation: independent raw program, fixed-cohort and terminal-EOS custody (13 Nov)

**Training source before this milestone:** `c53f8ef052b7f20a9cf7e4de7d2b50530bfa11f1`.  
**Main observed:** `63f8b1ba6559906fe85f3ad0269aa296e4141d67` including #563.  
**Integration observed:** `87cf3b087ee76f1f575266f8110956849b46ad5b`, combined Draft #567 HOLD.  
**Upstream source ownership:** #564 and #565 remain distinct Draft branches; no native successor was incorporated in Training.

### Owned code completed

- `train_lora.py` now records actual last-token `eos_terminated`,
  separately from `eos_emitted`; first-pass model acceptance consumes the
  last-token value, with no raw repairs.
- `evaluation_guard.py` rechecks raw strict JSON, per-record boolean and
  terminal-state consistency, actual compiler-valid programs/Art operation
  counts under the pinned compiler at recorded 96×96 seed, and independently
  recomputed reference theme, primary motif, ordered motif/layout and full
  program scores. It verifies exact fixed balanced dev/keyword request order
  and unmodified ID/prompt/group/seed/expected completion; summaries alone
  cannot approve a fabricated candidate.
- `test_evaluation_guard.py` now supplies synthetically generated valid raw
  completions and source-matched compiler geometry; four new adverse methods
  cover raw/tokens, compiler receipts, and identity/target tampering.
- `archived_raw_program_audit.json` is a small retained results manifest, not
  a new model candidate. No shared source/plan/registry, other roles, production
  defaults, frozen adapter, base model or native physics source changed.

### Executed archived-model qualification

Recovered all four original user-Library archives by exact filename and
independently checked their original byte counts, all whole-file SHA-256
hashes in `ARTIFACTS.json` and ZIP CRC integrity (zero errors).
The historical source compiler in the nested model evidence archive exactly
matched SHA-256 `a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb`.

In a local Python 3 offline replay, the actual archived 24 development and
12 one-word raw model responses were parsed with duplicate/nonfinite refusal,
recompiled from their original unmodified text, compared to the admitted
reference cohort/order and re-scored for declared theme, primary motif,
ordered motif/layout and exact target. **36/36 input identities matched,
36/36 model record/metric sets matched, zero discrepancies**. Recomputed
development: 22/24 JSON-valid/compiler-valid, 22 correct themes/motifs,
19 exact ordered structures and 13 full targets. Keywords: 12/12 compiled,
11 correct themes, 11 correct motifs and 8 full targets.
The two invalid coral decimals, veins orthogonal motif and ribs mislabel remain
failures. Source archives/individual prediction hashes are recorded in
`archived_raw_program_audit.json`.

This is a **new independent audit of archived actual predictions**, not
new model inference, optimizer work, native World replay or human thematic
acceptance. Critically, all 36 historical records omit terminal EOS *position*,
so the new guard must not retroactively mark terminal EOS independently proven.
Their historical first-pass flags remain as originally recorded. Three isolated
synthetic raw-helper unittest methods ran locally and passed (including ten
negative tampering controls); no exact-source combined 24-method supervised
train/eval suite was executed in this runtime, nor current-main/Windows/GPU.

### Dependencies and next owned action

The Integration worker may consume only Training-owned changes by exact
file blob identity. Its first obligation is to run the full exact-source
offline suite, including the newly strengthened raw guard, before describing
it as validated; the existing GitHub offline smoke can do this without model
weights or hosted training. After that, restore the pinned base/runtime on one
authorized host, inspect the private run-parent lease, and execute only one
new keyword-replay 400-step candidate against the frozen 24 development IDs
and twelve words. Preserve untouched final assessment and all failed raw
requests. Compare Sprocket-500M root Instruct and Smol135 only under matched
fine-tuning budgets. No Ready/merge or native/Windows promotion.


---

## Continuation: fail-closed full-resume, model inventory, post-run custody and orphan lease (13 Nov)

**Read before edit:** accepted main `63f8b1ba6559906fe85f3ad0269aa296e4141d67`
(including #563), Integration branch `a6d5a015bcabfa1601624988b7a4600111b968f8`
with single Draft/HOLD #567, and independently owned Draft #564/#565 heads
`6319ab1d94d85d01c9cdb44d973a92d224bfa9aa` /
`d66499ec3409fb657875fca7dbd0f234cf28ca49`.
Training branch started at `e36fbd72b22ab9cf76ad2a03f8f3d827a28872ff`,
which was already imported by Integration's fifth intake. No shared-source,
owner-branch, NeuroRunner, runtime or schedule changes were made.

### Implemented on Training branch only

1. `job_guard.build_fingerprint` now refuses an official base-model snapshot
   missing any file recorded in its receipt; prior validation only checked
   files still present. Existing hash mismatch refusal is preserved.
2. A `--resume` attempt now invokes the existing full `verify_checkpoint`
   inventory/size/SHA-256 validation **before launching the worker**, and
   fingerprints every optimizer/RNG/adapter/receipt byte, not only the manifest.
   Frozen original 25→26 and step-400 archives remain untouched.
3. After training child exit, all model/data/source/resume inputs are independently
   fingerprinted again. A clean-exit checkpoint from mutated input is retained
   for audit but marked `failed`, never accepted as a reproducible candidate.
4. An existing unreadable, invalid, or nonterminal durable role lease blocks a new job even
   if the kernel file lock is released. This prevents a supervisor crash from
   silently authorizing a second worker while the first child survives. The
   same lease is shared with heavy evaluation; manual orphan reconciliation is
   required, not automatic deletion.
5. `test_job_guard.py` gained five additional methods: missing model file,
   post-run model/corpus mutation (two subcases), mutated full-resume payload,
   active orphaned lease, and corrupt lease. Published suite now declares
   **15 Training + 14 Evaluation = 29 model-free methods**, not a PASS count.

**Published implementation commits:** `6116e3af05e8a612da81be96da6030a053c02225`,
`d036e1e13c4e0aad9751d2dd15402cdc94c42db7`,
`8183bb43477383e9dbd1776294385342a65f743d`,
`9f1e16fd5ba4a9dca51d68e18031c208774c70cc`,
`c74382ab39bdd7827661484f8dd49cfe0ae21dd9`.
Exact implementation/test Git blobs before this checkpoint:
`job_guard.py` `a7aa3dcdba0c5292fd37250803c6fbe673639c9b` and
`test_job_guard.py` `6061e956cfb9cfa9cc9793e7d65d73c9c844bc9a`.

**Qualification:** GitHub readback confirmed published file blobs and test
method discovery. The expanded suite has not been executed on exact source
in this worker's environment; no local clone, pinned base/runtime or private
role lease was available. Do **not** claim 29 PASS, no model-quality improvement
is established, and Windows/natively mounted Art/current #565 remain HOLD.
The historical 400-step scores (22/24 strict development, 19/24 ordered
motif/layout, 13/24 full targets; exact words 12/12 strict with ribs/veins
semantic errors) remain unchanged. The two coral malformed decimals remain
raw failures, and final assessment remains sequestered.

**Next:** Integration may import these exact two code/test blobs plus Training
documentation on the existing Draft #567 and execute
`python -m unittest -v test_job_guard.py test_evaluation_guard.py` in the
policy-compliant offline-smoke environment. Training must inspect the real
private run-parent/lease, restore the exact pinned base and original numerical
environment, then execute at most one new 400-step balanced-keyword candidate.
No duplicate old training, paid/hosted training, defaults, unrelated merges,
Ready, or release promotion.


---

## Continuation: POSIX descendant process-lifetime fencing (13 November 2026)

**Source checked before edits:** accepted main
`63f8b1ba6559906fe85f3ad0269aa296e4141d67` (includes #563);
Training-owned parent `253608f6a02cde620cce16287c98d1d590355763`;
Integration Draft #567 `8e7d3638afb9dad39287c07355c1849acee6dc88` (its
offline-smoke and independent role-intake jobs were both green at review);
#564 `6319ab1d` and #565 `d66499ec` remain distinct Draft source
owners. The new Training changes are NOT in that combined CI run.

**Concrete defect:** `job_guard.notify_child` skipped all process signals
when `proc.poll()` found the direct child exited, and `run` marked its
lease terminal after reaping only that child. A child-spawning training or
evaluation wrapper can exit while another member of its dedicated POSIX
process group continues running, including after Stop. This is a
process-lifetime/duplicate-job risk, not evidence of a native World write.
The same *class* of process-lifetime defect was independently found and
repaired in Integration's HTTP bridge, but the Training supervisor is
separately owned and needed its own correction.

**Owned implementation:**
- `job_guard.py`: removed direct-parent `poll()` gating of POSIX
  process-group signals; the Windows direct-child branch is unchanged.
  Introduced `fence_owned_process_group`: TERM, bounded 150-ms grace,
  then unconditional KILL to the known isolated process group. Invoked
  in `run`'s `finally` after parent success, soft Stop, hard deadline
  or worker exception, before publishing terminal result/lease.
- `test_job_guard.py`: a controlled fake worker spawns a same-session,
  SIGTERM-resistant descendant which reports readiness and attempts a
  deliberately delayed file write. Two Linux-only tests assert no late
  write after (1) a clean parent exit and (2) soft Stop. The tests use
  temporary private paths and no model/optimizer/native input.
- `README.md`: recorded scope, limitations and exact test boundary.
  No shared files, production behavior, physics, model weights,
  corpus/FINAL split, Training sampler or other role files changed.

**GitHub source publication:**
- implementation `c47b0329ab0409ca0e623c0e30729fb0a662ac64`
  (`job_guard.py` blob `67e9f1c38eb7845f4dc089d7ae34f38038a842c6`);
- new regression fixtures `bd413c3a286c6c1b568932c3747d50c61b709da8`
  (`test_job_guard.py` blob `b9a058b2bc6cee8ad8f9827854e5662a19f2361b`).

**Executed validation:** a local, synthetic Linux/Python process-group
reproduction of the same TERM/grace/KILL mechanics passed both normal-exit
and SIGTERM-parent-exit cases, with `late_write=False`. Its temporary
script was *behavior-equivalent*, not the exact repository supervisor.
GitHub readback verified both published source blob identities and new
test definitions. The branch-local 17 Training + 14 Evaluation methods
are **defined but have not been executed on exact source**; do not
relabel the earlier combined CI green run as this change's qualification.
No new neural prediction, optimizer step, model score, native replay,
Windows process-tree qualification, graphical or human acceptance exists.
Descendants that escape the owned POSIX session require a separate solution.

**Next:** Integration may import the changed Training-owned files by
exact blob and run full offline CI, including the 31-method train/eval
supervisor suite. Independently verify Windows process-tree termination
before promising reliable Windows Stop. Once a pinned model environment
and the private run-parent lease can actually be inspected, run at most
one separately identified balanced-keyword candidate, preserving all
frozen original raw failures and benchmark denominators. Draft #567
remains HOLD; no Ready, merge or production default changes.


---

## Follow-up — exact-source CI NameError repaired (13 Nov 2026)

**Trigger and exact upstream evidence.** Integration Draft #567 Actions run [43407805432](https://github.com/techrote/cybersand/actions/runs/43407805432) at combined head `22741283b6e7984d7fd8ebe0c93211e9fe2e9507` failed the Training-only step: **15/17 tests passed; two ERROR**. The two new native-independent POSIX process-descendant tests call `time.sleep(1.5)` but the file lacked top-level `import time`; the `time` imported inside the synthetic worker source string does not define a name in the test module. This is a test harness NameError, not a demonstrated process-fencing failure or pass.

**Narrow correction.** Training-owned `test_job_guard.py` gained exactly one standard-library import after `import textwrap`; no assertion, child-process behavior, deadline, runtime default, guard, lease or production file changed.

- Old Training head: `0aee867ef5f3a09184980d84eb7c40472a5cfad7`.
- Correction commit: [`11a476d19d4d1d137d3ecc50cf8bfc02e0984a72`](https://github.com/techrote/cybersand/commit/11a476d19d4d1d137d3ecc50cf8bfc02e0984a72).
- Exact old test Git blob: `b9a058b2bc6cee8ad8f9827854e5662a19f2361b`.
- Exact fixed test Git blob: `c9f88caf568e70463f7b097b83452ff2bc18fe34`.
- GitHub readback and byte-for-byte old/new comparison confirm precisely that one added import and both original descendant tests present. This is **published-source/diff verification, NOT a 17/17 execution result**.

**Executable qualification handoff.** The available environment cannot clone GitHub (DNS unavailable) and contains no exact-source checkout of the Training `job_guard.py` + test suite; consequently this run does **not** claim local 17/17 or combined 31/31. Integration should import only the corrected test blob with the expected previous blob, then execute:

```bash
python -m pip install --no-deps filelock==4.2.4
python -m unittest discover -s experiments/wb-art-slm-001/training -p 'test_job_guard.py' -v
python -m unittest discover -s experiments/wb-art-slm-001/training -p 'test_evaluation_guard.py' -v
```

Require the full exact-head [WB-ART-SLM offline workflow](https://github.com/techrote/cybersand/actions/workflows/wb-art-slm-001-smoke.yml) green, not merely successful collection or the separate independent job; preserve both adversarial tests and native/Windows qualifications as separate gates.

**Model-run preparation and remaining real blocker.** The four original user-saved archives were actually materialized in a private working directory, their sizes and SHA-256 matched the pinned `ARTIFACTS.json` identities, and adapter/resume and native/model evidence contents were inspected (frozen LFM2.5-350M step400, official base revision `9921cd4d82c0e3986887aa4b376f9446729ef8a3`). The present environment lacks the **pinned base-model snapshot** and `transformers` / `peft` runtime; no active private training run-parent/lease can be inspected here. No model training or inference was started, and no model-quality improvement is claimed. Corpus owns `failure_contrast_replay_v5.json` at `6195f180`, but the currently published Training `curriculum.py` advertises only `shuffled-v1` and `keyword-replay-v1`; a verified v5 original-index consumer must be made available before representing a training run as v5. This is a concrete execution blocker, not a reason to add generic safety infrastructure.

**Next priority:** Integration imports the one-line correction and validates the 17-job/14-eval suites; Training secures the permitted pinned base/runtime and intact private lease, consumes v5 manifest without touching Corpus owner files, then trains one new separately identified, full-resume-capable 400-step candidate. Retain the original 24 DEV and 12 keywords for raw first-pass scoring and hand all accepted/rejected cases to the actual native gallery owner. **Draft/HOLD**; no changes to Integration, #564/#565, NeuroRunner, model weights, production defaults or schedules.
