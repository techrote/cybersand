# B2-REGION-010 — fixed-point *effect* closure and stationary-contact falsifier

**10 November 2026. RESEARCH-ONLY / Draft / HOLD for native adoption.** No new CyberSand solver, runtime speed claim, source/authority change, or default/physics alteration.

## Baseline, ownership and preregistration

- Accepted main at source inspection: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. Pre-edit B2 Draft [#556](https://github.com/techrote/cybersand/pull/556) head `f138874f2626c5d34f692ed4196fa460be56331e`. Preregistered [falsifier](https://github.com/techrote/cybersand/pull/556#issuecomment-6760814253) **before writing** the new checker.
- Reviewed live `AGENTS.md`, development handover, `docs/architecture/pressure-optimization.md`, `pressure-flow-v1.md`, current B2 `sparse_fence.py`, #201 and #362, merged #470/#471/#522/#406/#474, and Draft B3 #555/B4 #554/gas #533. Current B2's existing *pure value-output* fixed-point theorem remains valid within its stated assumptions; this experiment challenges **generalisation to a side-effect-emitting stage**.
- Only `research/solver-certificates/invalidation/effect_closure_probe.py` and this report are new. No production or other worker files touched.
- The exact locally executed checker bytes have SHA-256 `9f59d63ead6a8505e8adcd50e2c81be8348065f2604eaf733b5d5021f8a1af4e`. Git blob identity `a0f6406d1729c92c399362a66fce32a0a64e0030` was independently confirmed from the published GitHub file at committed head `7423aebd9cbb012ff426e3fc7a6a686fa950e3fa`. Run from any Python 3.10+ checkout with `python3 research/solver-certificates/invalidation/effect_closure_probe.py`.

## Decisive falsifier: state invariance is not effect invariance

Consider a synchronous 3×3 research grid with all Rock except Water at flat index 4, and an immutable external body mask at index 7 immediately below that Water. The material remains Water in both phases. The declared toy stage emits an **externally observable signed effect**, `(site=4, impulse=+2)` on even phase and `(4,-3)` on odd phase. Neither the cell nor body mask changes.

A deliberately unsound state-only certificate proves the entire tile fixed and skips all 9 evaluations. On the very first tick **cached material equals the full oracle at all nine sites, but its emitted-effect ledger is empty while the full oracle returns `((4,+2),)`**. On the next tick the true effect is `((4,-3),)`. The corrected certificate refuses to sleep the Water/contact tile, preserving both signed emissions and value state. This is *not* a claim that B2's existing `sparse_fence.py` violates its own pure-stage grammar. It is a falsifier of any inference `same physical cells => all physical obligations unchanged`.

This distinction is directly relevant to **accepted-main PressureFlow**: [the canonical pressure optimisation contract](../../../docs/architecture/pressure-optimization.md) says stationary failed gravity/diagonal probes can produce body contacts and signed impulses even with no material motion. Its actual dormant Water motion certificate therefore rejects any body mask in a **5×5 stencil**, and skipping does not exempt chemistry, gas resolution, quantity, wake checks or other stages. The toy's `+2/-3` effects and one-cell radius are deliberately *not* native impulse magnitudes or production dependencies.

## Conditional effect-closure theorem (infinite finite-grid family)

Let `S` be a finite cell state and `G` all external/global dependencies. For each admitted phase `p` and cell `i`, suppose a deterministic, pure synchronous source stage returns a pair

\[
F_{p,i}(S,G)=(S'_i,E_i)
\]

where `E_i` is a **complete** ordered or canonically ordered externally visible effect record and `0` is the no-effect value. Every read is inside the declared finite halo `D(i)` or in `G`; producers authenticate and own *all* writes and changes to `G`; no further stage reads mutable partially committed outputs.

**Law:** A tile `T` can omit this stage's evaluation if, for every `i in T` and each admitted phase, a valid certificate proves `F_{p,i}(S,G)=(S_i,0)`, and every source read in its union of `D(i)` and the relevant `G` remains unchanged since proof. All producer edits (including A→B→A), dynamic body masks and previous-stage writes invalidate affected read closures before use; unbounded/unknown effects invalidate globally. On restoration, discard derived certificates. An incomplete producer barrier is **BLOCKED**, not a license to evaluate stale input.

**Proof sketch:** At a complete owner barrier, the full and cached operators see identical admitted pre-stage `(S,G)`. For active sites both compute the same `F`. For retained sites, the unchanged complete dependencies guarantee the certified pair `(S_i,0)` is still the true pair in the current phase, so copying `S_i` and emitting no event is observationally identical. Since both sets partition the finite grid, next material state and the combined canonically ordered effect ledger are equal. Producer/writer and halo invalidation preserve the premise by induction for any finite trace. This is standard dependency-closure reasoning over **all positive finite grid sizes and trace lengths**, not a new native collision theorem, not a proof for nonlocal gas without explicit global fallback, and not valid if an unmodelled emission or main-thread effect exists.

A hypothetical consumer's typed rule is `VALUE_FIXED_AND_EFFECTS_EMPTY`, not `VALUE_FIXED`. When full side-effect inventory, continuation/source identity, signed contact provenance, gas ancestry or external actor custody is missing, return **UNKNOWN=>RECOMPUTE** at a complete barrier. Never use this as a generic whole-tick or whole-chunk skip; it can attach only to a separately admitted, narrowly skippable stage.

## Executed deterministic experiment

**Exact-source local CPython execution**, not native/Windows/Godot/worker runtime: the standalone checker ran successfully and asserted full equality of *material state including tick/body/pressure* and **ordered signed effect ledgers** after each of 64 opportunities for each of three finite grids and 1/4 **sequential logical shards**. This is 384 exact per-opportunity comparisons, including one real toy rollback per trace at opportunity 40 to an opportunity-17 snapshot, body arrival/departure, cross-tile and reaction reads, pressure changes, edit/erase, circular explosion, A→B→A same-site writes and `UNKNOWN` global invalidation. The independent full oracle evaluates every cell and does not import the existing B2 sparse implementation. Total 18 signed emitted events per run were preserved. The short 3×3 negative control is separate.

| Grid | Logical shards | Full calls | Evaluated | Avoided | Probe + halo + roster scans | False-positive revocations / total | Abstract cost / full |
|---|---:|---:|---:|---:|---:|---:|---:|
| 5×5 | 1 | 1,600 | 567 | 64.56% | 1,083 + 293 + 256 | 50 / 60 | 2,199 / 1,600 = **1.37×** |
| 5×5 | 4 | 1,600 | 567 | 64.56% | 1,083 + 293 + 1,024 | 50 / 60 | 2,967 / 1,600 = **1.85×** |
| 8×6 | 1 | 3,072 | 822 | 73.24% | 1,631 + 408 + 384 | 67 / 76 | 3,245 / 3,072 = **1.06×** |
| 8×6 | 4 | 3,072 | 822 | 73.24% | 1,631 + 408 + 1,536 | 67 / 76 | 4,397 / 3,072 = **1.43×** |
| 16×12 | 1 | 12,288 | 1,962 | 84.03% | 4,503 + 543 + 1,536 | 206 / 214 | 8,544 / 12,288 = **0.70×** |
| 16×12 | 4 | 12,288 | 1,962 | 84.03% | 4,503 + 543 + 6,144 | 206 / 214 | 13,152 / 12,288 = **1.07×** |

Each stage adds one rule-call count for evaluated cells; certificate probes, halo-index visits and logical roster scans are *naively equally weighted abstract work units*. This is **not a CPU cycle/time, native tick, RAM or allocation benchmark**. The four-logical-shard variant scans the complete tile list once *per shard*, explaining its model cost regression despite high skip ratios. Crucially, this checker **also performs O(WH) per-tick material copies and full changed-cell comparisons**, which the table **does not price at all**; it is an oracle-oriented research probe, not a sparse production implementation. Offline false-positive diagnostic probes (707/1,141/3,410 per 5×5/8×6/16×12 run) are excluded from online cost. A false-positive revocation means the instantaneous effect-aware predicate still holds after input mutation; invalidation remains mandatory because original provenance/read assumptions changed. There were seven `UNKNOWN` or pressure-triggered global fallback events and one rollback per run.

Existing B2's **3.089× high-churn abstract-work regression remains valid negative evidence** for the previous sparse model and is not replaced or reinterpreted by these new figures. No native profile, 1/4 real worker participation, physical hash, pressure/gas/quantity ledger, source-qualified p50/p95, RSS/allocations or ABBA performance result was obtained.

## Handoff and HOLD conditions

- **B4:** independently execute the exact published checker, try dropping the effect-empty predicate, altering event order/sign, changing body mask without a witnessed producer and reconstructing after rollback. Treat the surprising 4-logical-shard roster-scan regression as an *abstract implementation cost only*. No live speed acceptance.
- **B5:** require **complete effect semantics and stage-scoped proof** in any proposed compositional certificate: `(value invariant, signed effects empty, complete inputs, authenticated continuation, complete producer barrier)`; otherwise `UNKNOWN=>RECOMPUTE` or `BLOCKED`. This complements B3's separately demonstrated rollback/external-Rapier effect-custody gap; it does not solve it.
- **Owner decision if future native consumer proposed:** identify an already skippable stage and its complete effect inventory; preserve existing 5×5 contact exclusion, mandatory pressure/gas/quantity work, MAT-AUTH, World/Rapier ownership, physical hashes, worker fence and default law. Require exact-head source-matched real native A/B/B/A and physical parity, with positive total-cost evidence before any opt-in implementation.

**Decision:** GO for a precise conditional effect-closure law and demonstrated state-only falsifier in an independent research model. HOLD for unreviewed research integration and all native gameplay, physics and performance uses. Historical acceptance and production sources untouched.
