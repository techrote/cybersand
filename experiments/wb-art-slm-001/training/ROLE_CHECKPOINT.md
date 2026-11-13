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
