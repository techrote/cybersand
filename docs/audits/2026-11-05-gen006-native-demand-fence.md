---
title: GEN-006 native demand/session fence control
status: Planned
document-kind: audit
scope: Experimental native generator and World admission; no production streaming or persistence
---

# GEN-006 #194: native demand/session fence preflight (2026-11-05)

**Scope:** Independent experiment only; do not merge or mark Ready. The accepted-main parent is \`ba9cbc89029be88b812af59b19e5c59829bbcd90\`. No production World, generator, material catalogue, C ABI, Godot, scheduler, actor, liquid or save-code changes.

## Why the experiment is necessary

The Current \`World::install_generated_chunk\` is correctly **strictly fresh-only**. It does not prove that an asynchronous proposal belongs to the newly reset World or a newly requested recipe: those are responsibilities of the future GEN-006 host owner. GEN-001/002 \`Generator::accepts\` verifies a recipe-bound material/coordinate receipt but is not a session or one-use demand token. Existing #415 covers synthetic durable save/ACK and #422 covers actual native material-only restore/whole-World continuation; neither executes a real generator-to-native-world reset admission boundary.

## Experiment and admission boundaries

The new isolated \`native/tests/test_gen006_demand_fence.cpp\` creates two actual compiled generators with the same signed chunk \`(-1,0)\` and distinct explicit material/revision proposals. On a fresh native World, bare admission of the previous session's valid material span succeeds, **by existing API contract**: it cannot identify the active host session. The test then runs a separate test-only \`FencedOwner\` which binds session, per-request identity, generator fingerprint, chunk coordinates and one-use consumption. It refuses prior-world results, earlier same-session cancelled jobs, mismatched generator revisions, a mutated valid-material cell with stale receipt, and a mismatched signed-coordinate result. Only the current receipt can install into the native World. A fresh control World compares physical state, quantity ledger and tick outcome for three subsequent native ticks in each 1/4 configured-worker cohort.

Do **not** misconstrue this as a production vulnerability, a streaming manager, actor pin enforcement, a native 4-worker participation proof, an implementation of general source authentication or a persistence solution. The FencedOwner is a synthetic host-boundary model exercising genuine native generator and World operations. There is no eviction/reload, async thread race, signed overflow stress, elapsed-time catchup, disk crash test or recipe reconciliation.

## Reproduction and release gates

Run from the exact PR branch via the branch-specific hosted GitHub Actions workflow \`.github/workflows/gen006-native-demand-fence.yml\`. It compiles real \`native/src/world.cpp\` and the ordinary generator implementation with GCC 13/C++20 on Ubuntu 24.04, checks CI provider policy, then executes the 1/4 worker configuration controls. Original source SHA/tree, compiler, build log and execution output are retained even if the run fails.

**Initial status:** test/CI execution pending, not a passed result. A CI failure must remain recorded, corrected on a later exact head with a separate result, not rewritten as passing. Draft-state Native/Godot skips do not constitute successful qualification. Windows, native Windows gameplay, cross-plane owner handoff, H1 historical MoltenGlass compatibility (#398), storage and save schema are untested.

## Recommended next decision

Admit a minimal *owner-side* demand identity and cancellation/refusal contract (not an automatic native installer rewrite), including recipe/source identity, nonreusable World session, job incarnation, signed chunk and one-use receipts. Gate selective restore/eviction on the separately reviewed #230 state domain and #398 historical-save decision. Preserve source- and runtime-specific negative evidence. Do not treat synthetic success as GEN-006 completion.
