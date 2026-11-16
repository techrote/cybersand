# TINY GAME POLICY TRAINER — synthetic M0 (Draft/HOLD)

This is a runnable **model-side research harness only** under the scheduler's
`experiments/driv3r/training/tiny_policy/**` ownership. It **does not execute
CyberSand or use native material readbacks**, does not alter gameplay/provider
source, and is **not SmolLM2, d1 or Sprocket training**. Results are not an
admitted original native TRAIN/FINAL corpus or native 128-turn qualification.

## Contract and authority

- 96×96 source-generated world; host supplies the finite, **cardinal Stage-A
  direct-drive action vocabulary** `UP DOWN LEFT RIGHT STOP`. Source reference:
  CyberSand `research/570-driv3r-stage-a@6067ea31adb8f3dfc76867676fc504078f5e9526`,
  `experiments/driv3r/contracts.py`; this **does not claim compatibility with
  the separate W0 SPROCKET action vocabulary**.
- Host rejects moves intersecting blocked/protected/out-of-bounds cells. Explicit
  STOP always legal; 96 actions maximum, no native writes, no inference-service
  permissions. Each action has original per-step before/after state hashes,
  feature hash, exact legal string array and receipt; replay reconstructs
  world bytes and fails closed if any field differs.
- Observation: three 7×7 binary local planes (walls, previous paint,
  protection), heading one-hot, family one-hot, bounded progress/geometry scalars:
  **162 float32** values. Unmodelled game dynamics and material species are
  deliberately excluded. Painting is host-owned and remains a single-cell line.
- Three synthetic families: Greebles, Pipework, Architecture. The teachers are
  small, imperfect deterministic/seeded geometric controllers, **not stronger
  pretrained model responses or native evidence**. An architectural label does
  not guarantee an architectural drawing. Distinct styles and failures remain
  in the gallery.

## Actual performed baseline

```bash
PYTHONPATH=. python -m unittest experiments.driv3r.training.tiny_policy.test_core -v
PYTHONPATH=. python -m experiments.driv3r.training.tiny_policy.train --out /absolute/new/evidence-directory --epochs 7
```

Requires Python 3.11+, NumPy, Pillow and CPU PyTorch. Output directory must not
exist. `train.py` runs actual AdamW updates with masked categorical cross
entropy on three competing *from-scratch small heads*: linear, two-layer MLP
and spatial CNN. It writes **real checkpoint files, split/hash identities,
source pixel PNGs, JSON rollouts, one contact sheet, and exact legal receipts**
into the selected **external** evidence directory, never Git history.

The original M0 execution used 50 **TRAIN** seeds / 10 **DEV** seeds / eight
**EVAL** seeds, with three family-labelled rows per world and 96 teacher steps
per row. Seed-group isolation is exact at the complete-world level. EVAL is
repeatedly inspected research evaluation, **not sealed FINAL**. Original W0
training and other native experiments are disjoint evidence domains even if
some descriptions resemble each other.

Every learned model gets exactly the same generated TRAIN/DEV/EVAL examples,
legal masks, optimizer family and epoch budget. Compared closed-loop against
teacher, random-legal and deterministic wall-following on identical obstacle
seeds/action budgets. Always show held-out teacher agreement **and** unique
cells, retraces, traversed-edge branch nodes, same-world family footprint IoU,
STOP and original drawings. Training agreement is not artistic usefulness.

## Explicit pretrained-model boundary / next gate

This M0 **has not loaded or trained any 20M–300M pretrained LLM**. It is an
actual tiny-head training and host-mask smoke, not a fabricated SmolLM2 result.
The next, separate CPU-only cohort should compare source-pinned
`HuggingFaceTB/SmolLM2-135M-Instruct`, `facebook/opt-125m` and
`EleutherAI/pythia-160m` using identical observations, partitions and legal
options, with measured weight-load, cold/warm latency and real forward receipts.
Stage first as frozen-backbone decision-head training and include an untrained
backbone/head control; require separate evidence before LoRA and any inference
promotion. **Pin exact model revisions, tokenizer identities and licenses at
acquisition**; no dynamic `main` or vague model-family claims. Bound runner
resource/time budgets and retain every failed acquisition/training attempt.
Only write model weights, optimizer checkpoints and galleries into immutable
GitHub Actions artifacts when a hosted cohort is deliberately launched; this
source-only PR contains none of those binary outputs.

## Known negative findings / failure examples

A high imitation accuracy can coexist with very weak spatial composition.
The wall baseline is deliberately family-invariant. The linear head commonly
collapses to similar paths across theme labels. A 96-cell limit ensures finite
execution but does not mean early STOP/generalization is proven. Typical
synthetic worm output is a short scribble or a straight wall-following path,
not recognizable artwork or a production-quality CyberSand game policy.
