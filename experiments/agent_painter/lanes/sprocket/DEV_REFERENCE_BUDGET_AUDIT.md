# SPROCKET original DEVELOPMENT teacher-reference token audit — source-only design

**Status (2026-11-15 UTC):** Explicit one-time hosted read-only experiment requested on existing sole Draft/HOLD PR #576. A workflow definition or queued job is **not** a completed result. Before inspecting evidence, the result is **UNQUALIFIED/PENDING**.

## Question

The model's first real step-96 raw DEVELOPMENT six-request evaluation produced 5/6 terminal EOS5, 5/6 strict JSON, only 1/6 compiler-valid programs, and **0/6 request-conforming native model paintings**. Does the existing greedy 512-new-token limit have enough representational capacity to emit the six *original canonical teacher reference* JSON programs, including genuine upstream terminal EOS5? This audit does **not** assume the answer or train/retry/generate new completions. It makes no inference about general artistic skill or the unfinished DEV60 suite.

## Frozen source and contract

- Model: **root Instruct only** `kandivault/sprocket-500m@eb157d4ddddc4619e661d4a2426bb2dd000fc668`, exact root upstream Jinja / EOS5 PAD1 BOS0, **no inserted BOS**, no remote code, no `chat/` substitution.
- Qualified original baseline adapter git blob: `1a6b928c80890e2d79fe4ab90e8d84e8c77c363c`; unchanged baseline profile with reviewed small-file hashes, no model weights. The executable trainer/adapter comes from frozen shared source `11ba1f1915362d3d127edfbe37fe9e30c57eb8b9`. Neither training objective nor LoRA is modified.
- Original native corpus source `633920373a3d406a2ede61ce4137c324f76be23b`, GitHub run `43506373969`, original ZIP artifact `14076703326`, opaque ZIP SHA256 `50a9ad9b255b2a57180edf5558ca2b47dab9affd9ef9d2438f9011d648f81f39`, admitted manifest SHA256 `2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc`.
- A **single** original DEVELOPMENT manifest is used: six distinct whole structures, two seed views each. Six language requests are the denominator, **not** 12 independent examples. Original native receipt/readback/PNG members for DEVELOPMENT are individually hash-checked against the admission record. Only partition names/group IDs from the sealed FINAL are visible in global metadata; no FINAL target, image, ZIP CRC or native material is decompressed.
- Completion = immutable `common.canonical(row["program"])`; the original source-qualified SPROCKET adapter calls its authentic `encode_row` to verify prompt framing, complete JSON supervision, EOS5 and exact no-truncation loss mask, then counts **only the six independent completion token lengths**. Full 2048-token sequence budget is separately checked.

## Honest disposition and follow-up

A completed hosted result will report all six family/group-specific prefix/completion lengths, exact manifest/template/model/source identities, archive custody, positive checks and failure receipts. **6/6 fitting 512 would rule out canonical teacher reference length as the *sole* explanation of step96's poor raw validity**, but not explain why the network does not generate appropriate targets. A failure to fit would justify a bounded evaluation-cap proposal, not silent label trimming. In either case, inference/native painting/generalization quality remains **0 newly measured**, the expanded 60-request/five-formulation suite is **not frozen**, and TRAIN admission remains the shepherd's shared decision.

The workflow runs on one ordinary GitHub-hosted Ubuntu CPU VM with a hard 35-minute job timeout; it downloads public pinned **tokenizer/config small files only**, and always uploads partial/failure receipts. No GPU/Codespaces/owner Windows PC, inference, optimizer step, new native Art execution, model version freeze, model promotion, Ready conversion, merge or FINAL tuning. The opt-in request is one-time, not an hourly training cadence.
