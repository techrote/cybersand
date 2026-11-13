# Hosted CPU training handoff

This is the common runner entry point for issue #568. The foundation proof runs
two real SmolLM2 optimizer steps, serializes checkpoints after steps 1 and 2,
then resumes checkpoint 1 to step 2 on a **different hosted runner**. It is an
optimizer/custody proof, not a useful painter or a full training campaign.
Only executed workflow artifacts establish that the proof passed.

## Frozen inputs and contracts

- `../program.schema.json` and `../compiler.py`: version-2 three-family program
  syntax and strict deterministic native-operation compilation. A model never
  supplies the host seed, selected focus, material whitelist or work budget.
- `../native/run.py`: produces `corpus/admitted-corpus.json` and the three split
  JSONL files only after actual current-source native application and independent
  receipt/readback/image verification pass.
- `common.load_training_corpus`: opens **TRAIN targets only**. It checks the
  admission/source/compiler/runtime identities, all partition group metadata,
  TRAIN file hash, original native PNG/readback/receipt hashes, exact recompilation,
  actual native receipt binding and independent stored-cell structural checks.
  It does not read `final.jsonl` or any FINAL target/evidence file.
- `model_profiles.json`: exact upstream revisions for all four future lanes.
  `smol` has an implemented loader. `void`, root `sprocket`, and `lfm25_vl`
  deliberately refuse execution until their own worker adds and qualifies the
  model-specific loader/tokenizer/LoRA preflight. There is no generic fallback,
  assumed chat template, `chat/` substitution or implicit remote-code execution.
- `requirements.lock`: the exact successful #567 CPU stack, carried unchanged.
  Every Actions VM creates its own environment, installs CPU PyTorch and the
  pinned package set, executes `pip check`, and records `pip freeze`.
- `download_model.py`: public, ungated full-revision root download, safetensors
  only, upstream license/architecture checks and exact expected weight/config/
  tokenizer hashes. Hugging Face receives no credential; remote code is disabled.

The pilot contains 12 TRAIN rows, 12 DEVELOPMENT rows and 6 sealed FINAL rows,
partitioned by whole structural composition rather than seed or paraphrase.
Later workers may expand the corpus through the same native-admission process.
The historical #567 TRAIN/DEV/FINAL corpus and adapter are not consumed or edited.

## Actions entry point

`.github/workflows/agent-painter-train.yml` supports `workflow_call` and explicit
`workflow_dispatch`. This reusable workflow has no push or schedule trigger.
An explicit qualification-request push or manual qualification dispatch invokes
it after native admission succeeds; ordinary PR updates do not train.

| Input | Meaning |
| --- | --- |
| `source-sha` | Exact 40-character source commit checked out and verified |
| `corpus-artifact` | Artifact containing `corpus/admitted-corpus.json` |
| `output-artifact` | Unique experiment output name; also separates job concurrency |
| `profile` | `smol` by default; other lane IDs fail closed until their branch implements model-specific preflight |
| `steps` | Total global optimizer target, including resumed steps; foundation wrapper accepts 1–16 |
| `resume-artifact` | Optional previous training artifact; never modify it |
| `resume-checkpoint` | Directory such as `checkpoint-000001` inside that artifact |
| `corpus-run-id` | Artifact source run; defaults to the current run for reusable calls |

The ordinary `ubuntu-24.04` job is bounded to 45 minutes, with one CPU thread,
a 15-minute model-download timeout, a 20-minute optimizer budget and bounded
SIGTERM/SIGKILL cleanup. Artifact names distinguish independent experiments;
one failed lane cannot cancel another. Uploads run after failures as well as
success. Actions artifacts are retained for 90 days; the qualification workflow
publishes the proof's immutable research assets separately.

To reproduce the scripts in an already prepared runner environment:

```bash
python experiments/agent_painter/training/download_model.py \
  --profile smol --output /tmp/painter-model
python experiments/agent_painter/training/train.py \
  --profile smol --model /tmp/painter-model --corpus evidence/native/corpus \
  --output evidence/fresh --steps 2 --checkpoint-every 1
python experiments/agent_painter/training/train.py \
  --profile smol --model /tmp/painter-model --corpus evidence/native/corpus \
  --output evidence/resumed --resume evidence/fresh/checkpoint-000001 \
  --steps 2 --checkpoint-every 1
python experiments/agent_painter/training/compare_resume.py \
  --fresh evidence/fresh/checkpoint-000002 \
  --resumed evidence/resumed/checkpoint-000002 --output resume-comparison.json
```

Those commands illustrate the interfaces. The actual hosted proof performs the
second training command on a fresh VM, downloads the checkpoint artifact there,
and downloads/verifies the base model again. No worker-local filesystem, Windows
machine, private dataset, Codespace or GPU is a prerequisite.

## What counts as real training

`train.py` performs completion-only cross-entropy through the actual pinned model,
checks finite nonzero LoRA gradients, executes AdamW and the scheduler, verifies
that adapter tensor bytes changed and that **every frozen base parameter byte**
remained unchanged. A zero-step process fails; model-free tests are never labeled
training. Outputs retain sample IDs/order, prompt and completion bytes, complete
sequence and loss-bearing token counts, loss/gradient norm, optimizer steps,
wall/CPU time, peak RSS, source/model/package identities and checkpoint sizes.

Chat rendering must preserve the exact prompt prefix. A possible BPE token at
the first answer byte is supervised; the completion must include the true EOS.
An over-budget example fails instead of being truncated. The sampler is a fixed
balanced family interleave, recorded in the run contract. TRAIN-only program
learning and optional DEVELOPMENT diagnosis remain distinct.

Each checkpoint is written to a new temporary directory, contains safe-serialized
adapter weights plus optimizer, scheduler, Python/Torch RNG, global step, sample
cursor and immutable run configuration, and receives a complete byte inventory.
It is read back and compared exactly before atomic publication. Loading uses
`torch.load(..., weights_only=True)`; no unrestricted checkpoint pickle is loaded.
Resume refuses changed model, corpus, compiler, training code, parameters,
package versions or sampler order. All restored state is compared before the
first continuation update. Existing output/checkpoint paths are never overwritten.

`compare_resume.py` requires exact sampler, RNG, scheduler, configuration and
base-byte identity. It compares adapter/optimizer floating-point tensors with
declared `atol=1e-6`, `rtol=1e-5`, reporting maximum absolute differences and
whether they were also bitwise identical. This is evidence for the executed
continuation, not a general promise of bitwise equality across CPU hardware.

The hosted proof fixes its CPU math choices before importing PyTorch:
`ATEN_CPU_CAPABILITY=default`, `MKL_CBWR=COMPATIBLE`, fixed one-thread MKL/OpenMP,
and disabled dynamic threading. The trainer disables oneDNN, requests highest
FP32 matmul precision, and records the effective numerical profile, its source
hash and the PyTorch build identity in checkpoint configuration. Conflicting
settings or late initialization are refused. Physical CPU identity stays in the
runner environment receipts, outside the configuration that must match across
different hosts. A faster numerical profile requires separate qualification and
cannot silently resume checkpoints from this recipe.

These choices follow Intel's [compatible-CPU CNR guidance](https://www.intel.com/content/www/us/en/docs/onemkl/developer-reference-c/2026-2/getting-started-with-conditional-numerical.html)
and [fixed-thread requirements](https://www.intel.com/content/www/us/en/docs/onemkl/developer-reference-c/2026-2/reproducibility-conditions.html).
PyTorch's [numerical accuracy guidance](https://docs.pytorch.org/docs/2.15/notes/numerical_accuracy.html)
still requires measuring actual continuation differences. The original
`atol=1e-6`, `rtol=1e-5` gates remain unchanged; the comparator visits every tensor
even after a failure so its reported maximum is complete.

SIGINT/SIGTERM requests a stop at the next optimizer boundary. If the job has
completed at least one new update, it preserves a checkpoint; a job stopped
before its first new update fails without claiming training. An unfinished
target returns nonzero. The Actions outer process timeout enforces a hard bound
even if model work stalls.

## Strict inference and the opt-in bridge

```bash
python experiments/agent_painter/training/infer.py \
  --model /tmp/painter-model --checkpoint evidence/fresh/checkpoint-000002 \
  --prompt 'Draw a connected pipe manifold with three branches.' \
  --output evidence/proposal-001 --seed 17 --width 96 --height 96 --material 58
```

One greedy first pass produces `completion.txt`, `raw-output.json`, `receipt.json`
and `art_batch.json`. No retry, JSON repair, keyword routing or fabricated drawing
is allowed. A true terminating EOS is required; other special tokens remain in
the decoded text and fail strict parsing. Compiler refusal produces an empty
operation list with `accepted=false`. Every receipt binds the original request,
host seed/focus/material, model revision, adapter/compiler hashes and raw output.
It explicitly states `native_execution=false` and makes no visual-quality claim.

The optional loopback `../bridge.py` revalidates these bindings and recompiles
the unchanged program. It only proposes current Art operations. The existing
native Workbench retains permissions, protection, Stop, application
acknowledgements, Undo/Redo and persistence authority.

## Future model worker handoff

| Lane | Implement/qualify next |
| --- | --- |
| VOID | Review the pinned ByteTokenizer code and byte framing, verify 2,048-byte/token budget and EOS, then qualify actual LoRA targets, CPU updates and full-state resume |
| SMOL | Consume the proven loader/native TRAIN contract; create its independent Draft PR, improve new three-family data, train a bounded candidate and preserve first-pass DEVELOPMENT outputs |
| SPROCKET | Consume **root Instruct** at the pinned revision; qualify its actual framing/EOS and module whitelist before enabling its profile; `chat/` remains a different checkpoint |
| LFM2.5-VL | Review its pinned `lfm1.0` license and official processor, qualify the actual multimodal loader with frozen vision encoder and explicit language-side LoRA; text-only Art comes first |

New model workers own model-specific code and independent run names. Shared schema,
compiler, split/admission and receipt changes require an intentional shared
foundation update. Frozen adapter continuation and fresh-from-parent comparison
must use copies and separate output paths. This foundation implements exact full
optimizer-state resume; the later fresh-versus-warm-weight comparison must reset
both optimizers as specified in issue #568 and remain separately labeled.

LFM3 shadow judging, d1 authority A/B, full model campaigns, Codespaces performance
sweeps and schedules remain outside this foundation proof.
