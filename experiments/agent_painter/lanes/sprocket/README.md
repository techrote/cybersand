# Sprocket root Instruct lane

**Current implementation:** model-specific adapter and local source/tokenizer/meta
preflight, prepared on 2026-11-13. Real optimizer, checkpoint and fresh-runner
continuation qualification must come from the shared hosted workflow receipts.
The local checks below do not establish training or painter quality.

## Pinned upstream contract

Use only `kandivault/sprocket-500m` at
`eb157d4ddddc4619e661d4a2426bb2dd000fc668`, with an empty subfolder.
The [pinned model card](https://huggingface.co/kandivault/sprocket-500m/blob/eb157d4ddddc4619e661d4a2426bb2dd000fc668/README.md)
identifies the root `model.safetensors` as the Instruct export; the separate
`chat/` checkpoint has different weights. The root
[export record](https://huggingface.co/kandivault/sprocket-500m/blob/eb157d4ddddc4619e661d4a2426bb2dd000fc668/export_provenance.json)
records `checkpoints/500m_sft_final.pt`, iteration 1192. The same pinned model card
declares Apache-2.0; the root snapshot does not contain a separate LICENSE file.
The reviewed metadata and framing files are all byte-bound in `profile.json`.

The [root configuration](https://huggingface.co/kandivault/sprocket-500m/blob/eb157d4ddddc4619e661d4a2426bb2dd000fc668/config.json)
uses built-in `LlamaForCausalLM`, 26 layers, hidden width 1280, intermediate width
3584, 20 attention heads and 4 KV heads, a 32,000-entry vocabulary, tied
embeddings and a 2048-token context. No remote code is needed. The downloader
must retain only root allowlisted files and verify every required SHA-256,
including the root weights:
`1a9fd1066f3f0873c4f5ae99b75beab3b0721100f45b036f9e255611b220d864`.

The [actual root Jinja template](https://huggingface.co/kandivault/sprocket-500m/blob/eb157d4ddddc4619e661d4a2426bb2dd000fc668/chat_template.jinja)
supports system, user and assistant messages. The adapter uses that file through
`apply_chat_template` and verifies its exact hash and rendered token prefix.
The training prefix is a system message, then a user message, each ended with
`<|end|>`, followed by `<|assistant|>`. The completion is the complete canonical
program JSON followed by one `<|end|>`. EOS is 5; PAD is 1; BOS is 0 and is not
inserted. PAD remains distinct from EOS. Literal control tokens in message
content are refused. Inference uses exactly the same prefix as training.

`encode_row` reuses the audited shared completion-only encoder, then requires an
exact prompt boundary, exact full target byte roundtrip, no control tokens in
content, and one final supervised EOS. Over-budget examples fail without
truncation. `encode_prompt` also refuses a prefix that consumes the whole model
context. The shared strict completion validator owns generated JSON/EOS
acceptance; the lane supplies no repair, chat substitution or fallback model.

## Local preflight actually executed

The small upstream files were downloaded at the full revision and hashed.
The weight SHA-256 and 1,002,207,984-byte size were checked against the
[pinned Hugging Face LFS metadata](https://huggingface.co/api/models/kandivault/sprocket-500m/revision/eb157d4ddddc4619e661d4a2426bb2dd000fc668?blobs=true).
A bounded HTTP range read inspected only the 26,864-byte safetensors header:
236 tensors, 501,090,560 stored parameters, all BF16. **No full model-weight
download, inference or optimizer execution occurred locally.** The hosted
downloader still has to hash the complete weight bytes before model loading.

The real tokenizer inspected all twelve positively native-admitted TRAIN rows
from source `633920373a3d406a2ede61ce4137c324f76be23b`. The shared admission loader
verified their source/runtime/compiler, receipts, readbacks and original PNG
hashes. No FINAL target or image was opened. Both host seeds (104729 and 130363)
have the same token counts within each structural group:

| TRAIN structure | Prefix tokens | JSON plus EOS tokens | Complete tokens |
| --- | ---: | ---: | ---: |
| Greebles service cluster | 70 | 216 | 286 |
| Greebles switchboard stack | 66 | 216 | 282 |
| Pipework two-elbow route | 77 | 112 | 189 |
| Pipework tee distribution | 73 | 112 | 185 |
| Architecture paired doorway rooms | 78 | 167 | 245 |
| Architecture stair and landing hall | 84 | 189 | 273 |

All twelve preserve the exact inference prefix, complete JSON bytes and one
supervised EOS. The architecture and PEFT adapter were instantiated only on the
meta device for shape inspection, using the shared pinned environment
(PyTorch 2.15.0+cpu, Transformers 5.22.2 and PEFT 0.21.2). The allowed targets are
`q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, and `down_proj`
inside each of the 26 language layers: exactly 182 modules. At rank 8 this yields
364 trainable tensors and 4,739,072 parameters. Embeddings, output head, norms
and every base weight remain frozen. Runtime validation checks every module
name, tensor shape, trainable name and the frozen parameter count, and rejects
meta tensors as training inputs.

FP32 base parameter storage is 2,004,362,240 bytes. Rank-8 adapter parameters,
their gradients and Adam's two FP32 moments add 75,825,152 bytes. These are tensor
storage calculations, not peak-RSS measurements: activation storage, libraries,
mapped source tensors, serialization/readback and allocator overhead remain
additional. The nine required snapshot files total 1,004,491,500 bytes; runner
provisioning must separately provide space for its installed environment and
immutable checkpoints. Actual elapsed time, peak RSS and continuation errors
belong in the hosted receipts.

## Re-run the focused preflight

The tests accept a directory containing the exact root small files or the
complete shared-downloader snapshot. They never load model weight tensors and
never perform a forward pass. With an environment provisioned from the shared
`training/requirements.lock`:

```sh
python experiments/agent_painter/lanes/sprocket/test_adapter.py \
  --model /tmp/sprocket-root \
  --corpus evidence/native/corpus --meta -v
```

Without `--model`, only dependency-free import/profile guards run; tokenizer and
meta checks report explicit skips. Without `--corpus`, native TRAIN verification
reports a skip. A skipped check is not a qualification result. The full command
exercises modified-template/EOS refusal, special-token injection refusal,
Unicode framing, complete-budget rejection, all admitted TRAIN rows, the actual
meta LoRA inventory, exact PEFT/module recipe guards and refusal of accidentally
trainable base weights.

## Shared trainer handoff

`adapter.py` is Torch-free until model/meta functions are called. The common
trainer must establish its one-thread portable FP32 CPU profile before importing
Torch, verify the whole public model snapshot, and bind this adapter, profile and
framing identity into checkpoints. `load_base`, `encode_row`, `encode_prompt`,
`validate_trainable` and `set_training_mode` are the lane entry points. The shared
trainer owns LoRA construction, finite loss/gradient checks, real AdamW updates,
frozen-base fingerprints, checkpoint serialization/readback and exact-config
fresh-runner resume. The lane pins rank 8, alpha 16, dropout 0.05, bias `none`,
`CAUSAL_LM`, with no saved non-LoRA modules, DoRA, RS-LoRA or per-module rank/alpha
overrides. A different recipe requires an explicit lane change and new run
identity; it cannot silently continue these checkpoints.

The next required execution is the bounded rank-8 two-step proof followed by a
separate hosted runner resuming checkpoint 1 to step 2. Keep the base/data/code/
numerical recipe identical for that comparison. Wider training, development
quality evaluation and corpus expansion belong to the later Sprocket worker;
the root checkpoint, native authority and sealed FINAL partition stay fixed.
