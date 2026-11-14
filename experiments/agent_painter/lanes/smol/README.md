# Smol painter: first bounded DEVELOPMENT iteration

## Separate source-d8 checkpoint128 diagnosis — 14 November 2026

The earlier [full-state continuation](https://github.com/techrote/cybersand/actions/runs/43522585277)
completed optimizer updates 17–128 using the **original exact trainer source**
`d8e2a7759c361f3e50660e301b9ad5a0208685c4`; it is **not** the
independent fresh120 trainer/native producer. The dedicated lane-owned
[read-only comparison](https://github.com/techrote/cybersand/actions/runs/43535795817)
was admitted at orchestration source
`1a349d9d115fbf789b7f28c80c2c4b7b2f65545a`. It consumed the existing
checkpoint-000128 from run43522585277 and the original 633 native-admitted
DEVELOPMENT manifest unchanged. The runner performed no optimizer updates,
native Art operations or FINAL access.

The result is **execution PASS, useful painting FAIL**. On **six distinct
language prompts, twelve deterministic seed views**, untuned base had
**0/6 true EOS, 0/6 strict JSON, 0/6 compiler-accepted prompts**.
The 128-step adapter had **6/6 true EOS, 6/6 strict JSON,
1/6 compiler-accepted prompts, 2/12 compiler-accepted seed views**.
The latter are two compilations of **one** raw Pipework completion, not two
independent paintings; native execution was not attempted. The generated
five-cell-diameter T graph is exactly three endpoints and one branch,
not the requested three upward branches/five endpoints. The separate fresh120
comparison used a different trainer source and 1024 rather than 512
generation-token budget; do not describe these as a controlled step-count A/B.

Original first-pass refusals are preserved: both Greebles structures invent
detail names outside v2; one Architecture request invents the `tower` kind and
wrong requirements, the other invents ` chamber`; the closed-loop Pipework
request reuses the tee and invents a `closed` requirement. The accepted manifold
request remains a semantically incorrect TRAIN tee. No candidate freeze or
model-native quality claim follows from this evaluation.

**Source/evidence custody:** [workflow and one-shot request](../../../../.github/workflows/agent-painter-smol-c128-evaluate.yml),
[artifact #14089354253](https://github.com/techrote/cybersand/actions/runs/43535795817/artifacts/14089354253),
artifact ZIP SHA-256 `cca74539cd94fd9284ac1d6b6841b308f33810f51bf08d68b25c9f8fa6a5597a`,
and [environment artifact #14089129245](https://github.com/techrote/cybersand/actions/runs/43535795817/artifacts/14089129245).
The original downloaded evaluation ZIP passed CRC and SHA verification. Exact
trainer, frozen native corpus and new evaluation source identities are separate;
published comparisons and both original checkpoint candidates remain unchanged.

**Next research:** coordinate a new common, structurally diverse,
positively native-admitted TRAIN corpus with the shepherd. Re-evaluate all
four model lanes against fixed independent structural groups, and retain raw
rejection evidence; do not expand source-d8 training by blindly replaying
its six original TRAIN structures.


## Executed first candidate and publication repair

The original producer source is
`fef6654ecd0828f765af1a13d2d10469013a3ea6`,
[run 43522896533](https://github.com/techrote/cybersand/actions/runs/43522896533).
It completed 120 real optimizer updates, with atomic checkpoint readback at
steps 40, 80 and 120. The candidate emitted true EOS for all six DEVELOPMENT
requests, complete JSON for five, and one compiler-accepted program at both host
seeds. The untuned arm accepted zero. The accepted pipe program changes the
TRAIN T-network's diameter from five to three but retains one upward branch and
three endpoints; it does not fulfill the requested three-branch manifold with
five endpoints. These are protocol results, not useful-painter qualification.

Both independent hosted jobs report the generic hostname `runnervm8axu0`.
Their authoritative GitHub runner IDs differ: baseline `1000115344`, candidate
`1000115378`. The original package's hostname-uniqueness predicate therefore
rejects valid separate assignments. The repair binds original job IDs, runner
IDs, run/attempt, source and original environment receipts. Hostnames remain
descriptive metadata.

`agent-painter-smol-publication.yml` consumes the explicit
`publication-request.json` to recover completed original artifacts. It installs
its own hosted CPU tensor-readback environment, verifies GitHub artifact ZIP
size/SHA/CRC and every extracted member, and rechecks original checkpoints,
native material receipts, PNGs and gallery. It never instantiates a model or
reruns native drawing. A clean checkout of the original producer supplies the
original source inventory; the new publisher's source/tree/run are recorded
separately. The original training/native source is never relabelled. The native
workflow uses the same authoritative assignment collection for future direct
publication. Read the actual run and release receipts for completion status.

The hosted repair at `e02bfb5d30972d8a1a84f30af7d485f13bb55fc7`,
[run 43527715072](https://github.com/techrote/cybersand/actions/runs/43527715072),
passed all evidence/package checks, then GitHub refused release creation with
HTTP 403, `Resource not accessible by integration`. The subsequent explicit
publication request uses Actions artifact delivery with read-only repository
permissions. `smol-release-*` contains the complete verified bundle;
`smol-gallery-*` is a small owner-inspection download with the standalone HTML
and native ZIP. `PUBLICATION.json` records the earlier permission failure and
the 90-day retention period. No public release is claimed for this iteration.

This lane consumes the shared foundation at
`2a565df45efc568eb96a2166e0b77f299e289625`, the original native-admitted corpus at
`633920373a3d406a2ede61ce4137c324f76be23b`, and the exact public
`HuggingFaceTB/SmolLM2-135M-Instruct` revision
`12fd25f77366fa6b3b4b768ec3050bf629380bac`. The lane scripts do not change the
shared compiler, model profile, corpus partitions, native application authority
or historical PR #567. Executed Actions artifacts, not this README, establish
training or model quality results.

The recurring worker's first 16-step pilot is preserved at
`d8e2a7759c361f3e50660e301b9ad5a0208685c4`, with
[Actions run 43520836201](https://github.com/techrote/cybersand/actions/runs/43520836201).
Its original `pilot-request.json` and `agent-painter-smol.yml` remain unchanged.
The baseline/native comparison is a separate bounded experiment in the same
[Draft PR #573](https://github.com/techrote/cybersand/pull/573). Its candidate starts
fresh from the pinned model. It does not relabel the pilot checkpoint as an exact
continuation under different source.

## Hosted training and evaluation

The lane workflow installs the locked CPU environment and downloads both the
model and native corpus on each GitHub-hosted VM. Baseline and candidate use
separate VMs, with one model process and one portable CPU thread per VM. The
entry points refuse accidental local model execution and require a clean tracked
checkout matching `--source-sha`.

```bash
python experiments/agent_painter/lanes/smol/train.py \
  --source-sha "$GITHUB_SHA" --model "$MODEL" --corpus "$CORPUS" \
  --output evidence/candidate/training \
  --steps 120 --checkpoint-every 40 --max-seconds 1200

python experiments/agent_painter/lanes/smol/evaluate_native.py \
  --source-sha "$GITHUB_SHA" --arm baseline --model "$MODEL" --corpus "$CORPUS" \
  --output evidence/baseline/evaluation --max-new-tokens 1024 --max-seconds 1200

python experiments/agent_painter/lanes/smol/evaluate_native.py \
  --source-sha "$GITHUB_SHA" --arm candidate --model "$MODEL" --corpus "$CORPUS" \
  --checkpoint "$ACTUAL_CHECKPOINT" --output evidence/candidate/evaluation \
  --max-new-tokens 1024 --max-seconds 1200
```

`train.py` is a thin wrapper around the unchanged shared optimizer implementation.
It fixes seed 568, maximum sequence 2048, FP32 and one thread; the shared recipe
uses LoRA rank 8, alpha 16, dropout 0.05 and AdamW learning rate 0.0005. The wrapper
bounds the global step target to 120 and the checkpoint interval to 40. The shared
trainer verifies actual gradients, optimizer updates, changed adapter bytes,
unchanged frozen base bytes, and exact serialized checkpoint readback.

The deadline is a limit, not a promise of 120 updates. Exit 0 means the requested
global target completed; exit 2 means a real partial checkpoint was saved. Read
`summary.json` and resolve its `checkpoint` basename under the training output.
Never assume `checkpoint-000120` exists. `lane-receipt.json` records the requested
budget and actual result alongside the unchanged shared receipts. Optional
`--resume` retains the shared exact source/model/data/numerical/configuration
checks and counts the target as total global steps, not additional updates.

## Frozen DEVELOPMENT custody and comparison

`contracts.py` pins the admitted corpus manifest, source, compiler, TRAIN and
DEVELOPMENT hashes. The development loader reads only the manifest and DEVELOPMENT
rows and their native PNG/readback/receipt evidence. It independently checks
teacher recompilation, positive original receipts, exact material readback and
structure. The trainer opens TRAIN through the original shared loader. Neither
entry point opens FINAL targets or FINAL images.

There are **12 DEVELOPMENT seed views, six structural groups and six distinct
prompts**. Each prompt has host seeds 104729 and 130363. Host seeds, focus and
material are never inserted into model messages. A single actual greedy first
pass is reused for the two identical prompt views and then compiled separately
for each host seed. This is six model generations, not twelve independent model
generations. Every view remains in the denominator, including timeout,
unattempted, missing EOS, invalid JSON, schema and compiler refusals.

Both arms use the exact same system text, upstream chat template, frozen user
prompt, model snapshot, compiler, portable numerical recipe and generation
settings. Candidate inference verifies the checkpoint inventory and saved
source/model/files/corpus/TRAIN/compiler/trainer/system/template/numerical/recipe
configuration before loading the adapter. No teacher answer enters model input.
There is no output repair, repeated sampling, retry, fallback or best-of filter.
Partial emitted token IDs survive generation exceptions; a total generation
deadline stops remaining work and records its unattempted rows explicitly.

## Artifact interface

| Path | Contract |
| --- | --- |
| `evaluation.json` | All 12 cases, six generation records, source/model/checkpoint/corpus identities, shared comparison identity, numerical and runner receipts, actual denominators and counts |
| `evaluation-start.json`, `evaluation-progress.json` | Recoverable identity and completed raw-case evidence if execution fails before final reduction |
| `cases/<id>/completion.txt` | Exact decoded content; only a unique terminal EOS is removed for JSON parsing |
| `cases/<id>/raw-output.json` | Full output token IDs, EOS ID, raw decoded text with special tokens, strict JSON/schema/compile verdict and refusal reasons |
| `cases/<id>/receipt.json` | Frozen request/host metadata, generation reuse and attempt status, verdict, source-bound evaluation identity and file hashes |
| `cases/<id>/program.json`, `compiled.json` | Present only after strict first-pass EOS/JSON/schema and bounded compilation all accept |
| `accepted-candidates.json` | Native replay input with actual generated family and frozen requested family kept separately; may contain zero examples |

Case `paths` map `completion`, `raw_output`, `receipt`, and accepted-only `program`
and `compiled` to relative paths. `sha256` uses matching keys. The per-case receipt
omits only its own hash to avoid self-reference; `evaluation.json` adds that hash.
Its accepted-candidates hash binds the exact native handoff. Native tooling must
independently verify these records, reparse raw output and recompile before replay.

Strict acceptance and requested-family agreement are separate fields and counts.
A valid program for the wrong family can be replayed transparently but is not a
family-following success. Structural checks prove the generated program's own
declared constraints; they do not establish fulfillment of the requested layout.
Compiler output and inference receipts never claim native execution or visual
quality. Only subsequent original native receipts, material readbacks and PNGs
can establish actual drawing evidence.

## Model-free checks

```bash
python3 -m unittest discover \
  -s experiments/agent_painter/lanes/smol/tests -p 'test_*.py' -v
```

Focused tests cover strict refusals, host authority, wrong-family accounting,
all-view retention at deadline, raw partial streams, adapter-arm CLI constraints
and bounded training defaults. These checks are not model training or inference.

## Native replay and owner inspection

The lane's `ci_native.sh` reuses the source-qualified foundation build procedure:
the pinned Godot C++ bindings, current native extension, ABI check, accepted
Rapier bytes and exact Godot executable. It stamps the current checked-out source
and retains build logs and the actual built ELF. It then calls `native_replay.py`
with both evaluation directories and the original corpus. The shared Godot Art
harness is unchanged. Accepted programs are applied and replayed in actual native
Worlds; protection and Stop probes also run when every proposal is rejected.
Undo/Redo and save/reopen checks cover the families actually represented by
accepted programs. Seven retained Workbench/Art regression suites run separately.

`native_replay.py` independently verifies raw-output custody, true EOS, strict
JSON, bounded recompilation, frozen host fields and every refusal before native
execution. Its `model-native-summary.json` distinguishes model acceptance,
requested-family agreement and actual native success. `native_gallery.py`
rechecks the complete packet and embeds unchanged original Godot material-readback
PNGs in `gallery/index.html`. This is a self-contained visual comparison, with
all 24 arm/seed views retained. Rejected views have no replacement image.

`package.py` reads back every real adapter/optimizer checkpoint without executing
a model, revalidates native cells and the gallery, checks the two distinct hosted
VM identities and all seven retained regression results, and writes immutable
research ZIPs, a standalone HTML gallery, `MANIFEST.json` and `SHA256SUMS.txt`.
The original corpus keeps its source633 identity; the new model execution and
native replay use the new exact source. Successful evidence publication can
include zero model drawings and does not promote painter quality.

## Run ownership and continuation

`.github/workflows/agent-painter-smol-native.yml` runs from an explicit change to this
lane's `run-request.json` on `codex/agent-painter-smol-568`, or manual workflow
dispatch when available. Ordinary documentation/code edits do not launch model
training. The first request fixes the budgets above; changing a budget requires
an explicit reviewed lane change. Artifacts include the full source, Actions run
ID and attempt. The workflow serializes requests on this branch, permits at most
two simultaneous model VMs, and never cancels an in-flight request automatically.
This comparison serializes its own two model arms, reserving the other model
slot for the recurring worker's independently owned source-d8 continuation.
Its first request also waits for the retained 16-step DEVELOPMENT diagnosis
run43521489545 to complete before opening the two model slots. A ten-minute
waiting limit refuses new work if that predecessor remains active.

The active owner decisions and execution lease live in
[issue #568](https://github.com/techrote/cybersand/issues/568). The
[schedule authorization](https://github.com/techrote/cybersand/issues/568#issuecomment-6865551592)
and [completed shared preflight handoff](https://github.com/techrote/cybersand/issues/568#issuecomment-6866246866)
supersede the earlier foundation-stage prohibition on schedules. The independent
SMOL Draft PR consumes the source2a common API and original source633 native
admission; peer-profile adapters remain owned by foundation PR #569. Keep this lane Draft/HOLD,
adopt an existing useful in-flight job, and record actual results before the next
bounded candidate. Cross-source checkpoint loading is a new candidate stage, not
an exact continuation claim. No FINAL targets, historical evidence or peer lane
branches are changed.

Once a useful candidate is frozen, a later worker may compare fresh-from-parent
training with training continued from a copy of that candidate on two separate
VMs. Such a changed-data/source stage needs its own explicit request, checkpoint
identity and optimizer policy. Preserve the original candidate and all failed
attempts; do not treat a schedule wake-up as a reason to duplicate active work.

## Retained scheduled-worker pilot evidence


Exact training source: `d8e2a7759c361f3e50660e301b9ad5a0208685c4`, [complete hosted run 43520836201](https://github.com/techrote/cybersand/actions/runs/43520836201) **PASS**. All 16 actual optimizer updates completed with finite nonzero gradients and immutable per-step checkpoints. Their summed optimizer-step wall times were approximately **72.78 seconds**, excluding package/model download and publication; first/last losses were **2.28699 / 1.03290** on *different TRAIN examples* and do not establish quality gain. The run produced a **437,723,944-byte** checkpoint artifact, [#14082459727](https://github.com/techrote/cybersand/actions/runs/43520836201/artifacts/14082459727), ZIP SHA-256 `6728e642655cf82aa7507f3a34d2b0a672e4a6df8e54e8c457cee4ae8f36f9ad`; environment artifact [#14082524601](https://github.com/techrote/cybersand/actions/runs/43520836201/artifacts/14082524601) is separately retained. The final model adapter hash is `d6329fd5ab350dd274b18ffb318cd5014c5d75b115e37f21e329346aadacda5a`.

The bounded **128-token** first-pass greeble probe emitted **no EOS**, failed strict JSON admission and generated **no native operations**. This is a genuine unsuccessful model-output result, not a successful drawing. The output-token cap is insufficient as a general semantic quality benchmark; no denominator is repaired.

The separately opt-in [DEVELOPMENT evaluation workflow](../../../../.github/workflows/agent-painter-smol-development.yml) checks an immutable run/adapter/corpus request and runs [evaluate.py](evaluate.py) on one new CPU VM. It compares raw untuned-base and tuned outputs using up to **512 newly generated tokens per distinct language prompt**, only reading DEVELOPMENT rows, reusing actual generation bytes for seed variants, preserving all raw failures and reporting compiled proposals as *non-native*. Evaluation source, training source and admitted-native source remain distinct. The current request is [evaluation-request.json](evaluation-request.json); consult its exact Actions run before claiming comparison results.
