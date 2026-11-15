# DRIV3R WORMBENCH — Q4 performance and untuned SLMworm shadow cohort

**Separate Draft/HOLD study, stacked on #611.** Original Q8 native worm evidence was qualified at commit 313b836b3c9ce2c60e4659e3763df140f84347a6, Actions run 43678354515. This branch does not edit #611, D-2 #598, M1, shared native/backend/provider defaults, or the active WORM-001 #612 / #568 painter-training lanes.

## First gate: actual local CPU inference on 72 ORIGINAL native observations

Four untuned original GGUF models each receive 36 free and 36 soft original Q8 observation states. All original legal candidate IDs, states, original responses and provenance derive from native artifacts 14147579972 and 14147233975. reference.py independently rejects wrong source, missing turns, illegal actions, invalid original answers or a frozen SHA mismatch.

- d1-2B Q4_K_M: same official LiquidAI/d1-2B-GGUF revision and the exact optional_q4 SHA in existing CyberSand pins.json; same pinned llama.cpp b11960 System One endpoint.
- LFMworm: original LiquidAI/LFM2.5-350M-GGUF Q4_K_M.
- Smolworm: original tensorblock/SmolLM2-135M-Instruct-GGUF Q4_K_M, derived from HuggingFaceTB SmolLM2.
- Sprocketworm: original kandivault/sprocket-500m *instruct* GGUF q4_k_m; NOT the chat build or a fine-tuned #568 painter.

For each external SLM model resolve one exact upstream repository commit BEFORE download, acquire only the named GGUF at that immutable commit, check the published SHA where available, record actual SHA/bytes, source and runtime identity, and retain failures. The LFM candidate has an independent predeclared SHA. Do not claim an unset or incorrect hash is qualified.

System One returns probabilities and zero generated tokens. The other three models use generative chat completion and must output one exact offered legal action ID; any unknown, verbose or malformed answer is recorded INVALID and never reaches native code. These API behaviours differ, so report latency and token usage separately rather than asserting equivalence. Assess q4 first-choice concordance and total-variation distance against original Q8 at the SAME state, plus SLM validity, variability and response latency.

No choice in this experiment changes a native World. After the first model choice divergence, the remaining Q8 observations are counterfactual fixed shadow states, NOT authentic model rollouts. No aesthetic performance claims follow from this test.

## Resource and later research gates

Only a push changing the exact qualification-request.json file on this research branch authorizes inference. Pull requests run cheap tests only. At most two CPU-only GitHub Actions runners are concurrent; 72 saved questions per model, 65-second request deadline, 75-minute model-job limit. Original Q8 artifacts are immutable, and new outputs receive source-linked artifacts.

Later source-authorised native experiments may test 128 turns, several seeds, two resident models per 4-vCPU runner, and eventual 16x2 / 32x2 throughput. NONE of that scaling, native painting, training, paid API/GPU, default-provider change, material Undo or merging is authorized by this first shadow qualification. PR remains Draft/HOLD.
