# LFM2.5-VL CPU dose experiment — first trained-candidate follow-on

**Draft/HOLD**. The 16-update checkpoint in [run 43521497210](https://github.com/techrote/cybersand/actions/runs/43521497210) is a real optimizer proof, not a useful-painter freeze. First matched DEVELOPMENT run [43522779375](https://github.com/techrote/cybersand/actions/runs/43522779375) used two seed rows per identical prompt and did not bind the candidate's global step/source in its evaluator. Its raw artifacts remain immutable and are diagnostic only: six independent prompts, 12 seed views, untuned **0/6** valid JSON and tuned **1/6** valid JSON, **0/6** schema-admitted programs for either arm. The original uploader overcounted these as 12 independent model calls per arm. Reviewer's findings: [PR #575](https://github.com/techrote/cybersand/pull/575#issuecomment-6866950472).

The corrected evaluator executes exactly six distinct first-pass calls per arm, reuses raw output across the two host-owned seed views, and independently recompiles accepted programs at each seed. It reports both six-request and 12-view denominators, checks the pinned training source **a8284c90050499cc1bf5c33dd0992741891c146b**, checkpoint **global step 16**, sample cursor, complete history and original native admission. Six new pure-source contract tests pass on a GitHub-hosted CPU runner. [Corrected matched DEVELOPMENT run 43529485853](https://github.com/techrote/cybersand/actions/runs/43529485853) is a new source-matched diagnosis; do not promote the superseded results.

## Bounded new-stage dose comparison

The explicit, fixed `campaign-request.json` authorizes **two independent ordinary CPU GitHub Actions VMs** running **one model process each**. Both start *fresh* from the same pinned full LFM2.5-VL-450M parent, train on the same 12 originally native-admitted TRAIN rows, use unchanged rank8/AdamW/FP32 numerical and frozen vision/projector contracts, and preserve the same original compiler/native corpus identity. Arms differ deliberately in budget: **48 vs 120 global optimizer updates**, with checkpoints every 16 vs 40 steps. A two-VM matrix avoids duplicated orchestration and isolates outputs/checkpoints. Neither arm resumes or overwrites the 16-step pilot. Job deadlines and failure artifacts are explicit.

The workflow waits for corrected evaluation's confirmed success before opening training VMs, avoiding excessive simultaneous model load. It installs the exact model/dependencies from scratch on each hosted runner, performs a genuine TRAIN-only optimizer, records full atomic checkpoint readbacks, resource receipts and one unrepaired original first-pass probe. It does **not** self-label candidates useful, invoke native Art or open FINAL. These two dose levels are a syntax-learning experiment rather than a fresh-versus-continued-vN paired comparison (which requires a useful frozen vN).

The existing shared bounded workflow and model adapter remain unchanged; the pilot's original training source/checkpoint and historical #567 are untouched. A later candidate must pass the common DEVELOPMENT suite and **actual native acknowledgement/material readback/original PNG**, plus structure-specific qualitative assessment. Additional native-admitted structural TRAIN diversity is to be coordinated with the shepherd; overfitting this tiny initial corpus remains a serious risk.


## 14 November 2026: source-only completion and promotion gate

After the source-qualified real fresh48/fresh120 CPU campaigns, strict DEVELOPMENT and
corrected native replay, both candidates remain **not useful**: each accepted
only one of six independent language requests, and the four genuinely executed
native seed views are T pipes rather than the requested five-endpoint manifold.
The corrected native run is
[43547938574](https://github.com/techrote/cybersand/actions/runs/43547938574);
native material application and independent verifier pass are distinct from
**0/4 request-conforming native views**. Historical producer/evaluator/native
sources and artifacts are immutable. No further training on the unchanged six
TRAIN structural groups is justified.

The original bounded CPU dose workflow now invokes lane-owned
`campaign_gate.py` **after** the shared trainer and **before** its single
post-training inference probe. It requires the exact 48/120 fresh optimizer
step/cursor/history sequence; completed status; the actual source/run identity;
official complete model revision; original native-admitted TRAIN corpus identity;
portable FP32 numerics; frozen-base/changed-adapter receipts; full checkpoint
file-inventory hash verification; and no FINAL/native/quality promotion claim.
A partial checkpoint is retained by `upload-artifact: if: always()`, but it
cannot be labelled a completed candidate. This gate is scoped to the original
12-row dose request and intentionally **must be versioned for any new corpus,
fresh/warm pair or new checkpoint target**. It is not a training-quality test
or a retroactive modification of the historical completed jobs.

`test_campaign_gate.py` exercises successful 48/120 fixtures and independent
failure cases for partial/stale/model/corpus/numerical/run/history/gradient/
resume/quality claims; it also checks the required workflow ordering. The
[model-free hosted guard run 43553331689](https://github.com/techrote/cybersand/actions/runs/43553331689)
completed SUCCESS with source tests and CI-provider-policy validation, without
downloading model weights, training, inference, native painting or FINAL access.
All source remains confined to the existing Draft/HOLD LFM branch. The next
productive model-quality action depends on shepherd/reviewer approval of
structurally new, positively native-admitted TRAIN examples and a shared
frozen expanded DEVELOPMENT suite.

## 14 November 2026 — full historical TRAIN cycle and aggregate guard

The lane's original fresh48/fresh120 completion gate additionally checks that
all 12 unique native-admitted TRAIN **seed rows** occur in the exact
`config.sample_order` round-robin sequence for every optimizer event. These
represent only six independent structures, not 12 independent designs. A
correct step count or a self-consistent forged history repeating one row does
not satisfy the gate. It also cross-checks loss-bearing and sequence-token
totals, prompt/completion byte totals, first/last loss values and finite
optimizer-step durations against the original checkpoint history and progress
log. Model-free adversarial tests cover sampler omissions/duplication,
reordered examples, missing bytes and incorrect aggregate values.

This source-only safeguard remains bound to the existing 12-TRAIN-row
fresh48/fresh120 campaign. Any novel curriculum, model-numerical recipe or
fresh-versus-continued experiment needs its own versioned contract and fresh
hosted qualification. This does not imply more optimizer updates, native
painting, unseen FINAL access or a useful painter candidate.

## 14 November 2026 — frozen TRAIN/compiler and complete-model custody (P3)

The historical `fresh48`/`fresh120` promotion gate now checks **more than
self-consistent training receipts**: `config.train_sha256` must equal the original
native-admitted TRAIN split
`5cb437db0663d15496adced3c255c32a5a274d99a69dd6113938b2dbc15ddbb1`,
and `config.compiler_sha256` the admitted compiler
`4d8559805df1ff5f3f23277a7bca98e47fa8feb53337aa79e8546d0bb89132f6`.
It also binds the exact **12 original individual seed-row IDs and their sampler
order**, independently recovered from the two original hosted training job logs
[48-step job 132245201791](https://github.com/techrote/cybersand/actions/runs/43529993326/job/132245201791)
and [120-step job 132245201772](https://github.com/techrote/cybersand/actions/runs/43529993326/job/132245201772).
Both logs show the same 12-row ordered cycle, repeated 4 or 10 times. These
remain only **six distinct structural TRAIN groups**.

The gate checks the official complete multimodal model's nine root-file SHA-256
identities in both declared profile and actual downloader receipt, loader name,
LFM1.0 license notice, reviewed 92 language target paths/LoRA count and
frozen CPU/training hyperparameters. The existing downloader and shared
trainer retain responsibility for hashing **actual downloaded bytes and
performing optimizer updates**: model-free tests use synthetic receipts and
are not an independent downloaded-weight, checkpoint or training proof.

[Hosted source-only 10-test gate qualification](https://github.com/techrote/cybersand/actions/runs/43563409930)
completed SUCCESS at source `a958909c87c53dcab4b7c8722123bf003cdca3c4`
with 10/10 Python unittest methods, including explicit collusion against
split/compiler/model hashes, synthetic rows, changing the original order,
altered license/LoRA metadata, broken model downloader receipts and changed
training hyperparameters. The preceding intermediate run
[43563374086](https://github.com/techrote/cybersand/actions/runs/43563374086)
failed because the corresponding test fixtures had not yet been updated; it
remains failure evidence and is not relabelled.

This is only a **historical-dose-specific completion integrity repair**, not a
training, inference or native-painting result, and no model-quality claim or
new freeze follows. Structurally new native-admitted TRAIN groups require a
**new versioned campaign contract**, rather than bypassing the original frozen
identities. The next justified model-training step remains dependent on the
shepherd/reviewer-controlled, disjoint structural curriculum expansion and
shared DEVELOPMENT suite.

### Exact 92-path language-only and EOS framing follow-up

The gate's completed-model identity now also refuses a substituted LoRA target
expression, any mismatch in the **full exact set of 92 qualified language
projections** (rather than only their count), an altered EOS token (official
assistant EOS = 7), and enabling images/tools inside the original
text-only fine-tuning profile. The target set is derived explicitly from
16 language layers (48 FFN targets, 24 attention targets and 20 convolution
targets); no vision/projector LoRA target is admitted. This is still **a
source-only future-checkpoint guard**, not a newly trained adapter or proof
of physically unchanged vision/projector tensors. Positive tensor-byte
preservation remains owned by the original shared trainer and checkpoint
verification. New synthetic negative tests cover each added refusal.
