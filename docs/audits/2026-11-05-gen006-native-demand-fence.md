---
title: GEN-006 native demand/session fence control
status: Planned
document-kind: audit
scope: Experimental native generator and World admission; no production streaming or persistence
---

# GEN-006 #194: native demand/session fence preflight (2026-11-05)

**Scope:** Independent experiment only; do not merge or mark Ready. The accepted-main parent is `ba9cbc89029be88b812af59b19e5c59829bbcd90`. No production World, generator, material catalogue, C ABI, Godot, scheduler, actor, liquid or save-code changes.

## Why the experiment is necessary

The Current `World::install_generated_chunk` is correctly **strictly fresh-only**. It does not prove that an asynchronous proposal belongs to the newly reset World or a newly requested recipe: those are responsibilities of the future GEN-006 host owner. GEN-001/002 `Generator::accepts` verifies a recipe-bound material/coordinate receipt but is not a session or one-use demand token. Existing #415 covers synthetic durable save/ACK and #422 covers actual native material-only restore/whole-World continuation; neither executes a real generator-to-native-world reset admission boundary.

## Experiment and admission boundaries

The new isolated `native/tests/test_gen006_demand_fence.cpp` creates two actual compiled generators with the same signed chunk `(-1,0)` and distinct explicit material/revision proposals. On a fresh native World, bare admission of the previous session's valid material span succeeds, **by existing API contract**: it cannot identify the active host session. The test then runs a separate test-only `FencedOwner` which binds session, per-request identity, generator fingerprint, chunk coordinates and one-use consumption. It refuses prior-world results, earlier same-session cancelled jobs, mismatched generator revisions, a mutated valid-material cell with stale receipt, and a mismatched signed-coordinate result. Only the current receipt can install into the native World. A fresh control World compares physical state, quantity ledger and tick outcome for three subsequent native ticks in each 1/4 configured-worker cohort.

Do **not** misconstrue this as a production vulnerability, a streaming manager, actor pin enforcement, a native 4-worker participation proof, an implementation of general source authentication or a persistence solution. The FencedOwner is a synthetic host-boundary model exercising genuine native generator and World operations. There is no eviction/reload, async thread race, signed overflow stress, elapsed-time catchup, disk crash test or recipe reconciliation.

## Reproduction and release gates

Run from the exact PR branch via the branch-specific hosted GitHub Actions workflow `.github/workflows/gen006-native-demand-fence.yml`. It compiles real `native/src/world.cpp` and the ordinary generator implementation with GCC 13/C++20 on Ubuntu 24.04, checks CI provider policy, then executes the 1/4 worker configuration controls. Original source SHA/tree, compiler, build log and execution output are retained even if the run fails.

**Actual executed source:** commit `b922b259ac5c04c9163e90d16586468136785e18`; branch-specific native diagnostic [run 42009294812](https://github.com/techrote/cybersand/actions/runs/42009294812) PASSED on Ubuntu 24.04 / GCC 13.3.0, 52/52 assertions. Per configuration: 26 assertions, bare-native older-recipe proposal admitted as contractually expected, guarded stale/cancelled/invalid deliveries refused, current receipt installed and matched a fresh new-recipe native control for three ticks. Configured workers 1 and 4; **actual observed maximum was 1 in both cohorts** (the small static fixture does not exercise 4-worker participation). Neither Windows nor asynchronous thread/race qualification was executed.

**Preserved original attempts:** earlier head `636c822a577a8c0f292ccfefbaa40a721cc752f0` also passed the diagnostic in [run 42009201371](https://github.com/techrote/cybersand/actions/runs/42009201371). Intermediate head `2fadcb6f91a9772bf971eacc40a596e076b37592` was [cancelled](https://github.com/techrote/cybersand/actions/runs/42009206937), **not a pass**. These are separate source identities and results. A documentation-only follow-on head will require its own exact-head workflow status before its CI can be called passed. The routine expensive Native/Godot suites are skipped under Draft policy, not qualifying passes. No Windows, cross-plane owner handoff, H1 historical MoltenGlass compatibility (#398), storage or save schema was tested.

## Source-contract conclusions

| Boundary | Experiment observation | GEN-006 consumer obligation |
|---|---|---|
| Native generated-span installer | Fresh native World accepted the older recipe's valid span at the same signed coordinate | Treat native shape/material/residency validation as necessary, **not sufficient**, for asynchronous admission |
| `Generator::accepts` | Rejects an old recipe revision, altered material payload and mismatched signed coordinate | Bind the *currently adopted* generator and its exact content/receipt hash to the demand |
| Reset or changed demand | Old host session and cancelled same-session job were refused before any native mutation | Maintain nonreusable owner session + per-demand/job incarnation; verify both immediately before commit |
| Single-use admission | Duplicate previously accepted job was refused at the host, not left to a resident-only check | Consume one-use admission receipt atomically with the owner call |
| Native continuation | Same new-recipe source matched physical-state and quantity-ledger controls for three ticks | This is a minimal sanity control, **not** proof of selective eviction, persistence, or live 4-worker participation |

## Recommended next decision

Admit a minimal *owner-side* demand identity and cancellation/refusal contract (not an automatic native installer rewrite), including recipe/source identity, nonreusable World session, job incarnation, signed chunk and one-use receipts. Gate selective restore/eviction on the separately reviewed #230 state domain and #398 historical-save decision. Preserve source- and runtime-specific negative evidence. Do not treat synthetic success as GEN-006 completion.
