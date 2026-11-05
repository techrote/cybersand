# SOL safety composition successor — 5 November 2026

Status: **DRAFT / exact-current-#429 restack / qualification in progress / no production admission**.

This branch is rebuilt directly on authoritative #429 `275ce1ee692739b35f400adcf9532f7e89284cfb`. The earlier safety PRs were cut from #429 at merge-base `dfc2833eab5b8e3f81e2f2798b0066562ed41e0b`; #452 is 25 commits behind final #429. Their source trees are evidence/patch inputs only, not this composition's base.

## Source custody

- Intake main: `ba9cbc89029be88b812af59b19e5c59829bbcd90`.
- Authoritative live physics source and this branch parent: #429 `275ce1ee692739b35f400adcf9532f7e89284cfb`.
- Patch inputs: #433 `bbbc423344ca1d72764557ddacba690b75ea04d7`, #441 `3eb07e6616798dda49083858e5549aec4c8d0cd7`, #452 `14b0f1d0c9a30d4ccd919b3dad91f46031912e39`, #444 `79f791fb484d738592a629bb8c0457e9ffa40df5`.
- #429 physics/default/live-trajectory ownership is unchanged.

The composed header retains #433 finite/representable Body preflight, #441 occupied-Bin validity, #452 tangent mean/extrema invariant and #444 derived contact-geometry/final nonfinite clean refusal.

## Tolerance review

The live producer is `project(...)->Bin::add(...)` in `workbench_granular_coupling.inc`. Relevant supplied body coordinates are preflight-bounded to +/-1e6 and geometry to 128; actual World contacts originate inside the finite workbench extent (up to 2048 cells). `Bin::add` uses Welford mean accumulation plus min/max.

The provisional #452 allowance remains `8 * epsilon * max(1, |min|, |mean|, |max|)` pending execution. The producer regression exercises the projected live-domain path plus separately labelled +/-1e6 copied-value arithmetic stress on GCC, Clang and MSVC. Do not tighten from inspection alone.

## Experimental evidence decisions

- **#427:** implementation rejected as duplicate; predicate is equivalent to #433. Preserve malformed-domain evidence. Recommendation after successor acceptance: **CLOSE AS SUPERSEDED**.
- **#438:** executable 120,000-case valid-input differential and real MSVC procedure adopted. Recommendation: **KEEP AS EVIDENCE** until this successor has accepted equivalent execution, then supersede with the run linked.
- **#413:** competing normalizer rejected; unique passivity counterexample retained. Recommendation: **HOLD FOR RECONCILIATION**.
- **#418:** recursive/historical fallback rejected absent a demonstrated #429 requirement; relevant #429 authored mixed-body evidence reports zero native passive rejections. Recommendation: **HOLD FOR RECONCILIATION**.
- **#423:** extra result field/fallback provenance implementation rejected absent a live consumer need; property evidence retained. Recommendation: **HOLD FOR RECONCILIATION**.
- **#450:** exact three-face/252,720-case witness adopted test-only, including 28,428 any-face worsenings; two-solve runtime selector rejected. Recommendation: **KEEP AS EVIDENCE** until real mixed-body capture has a durable successor.

## Qualification contract

The dedicated workflow compares **final #429 parent** with the composed candidate for Body RED/GREEN, the complete 120,000 valid-input differential and response-only CPU cost. It also reproduces #441 mean-range RED and #452 derived-geometry RED. Candidate optimized GCC/Clang, actual Windows/MSVC and ASan/UBSan are required.

Draft-skipped generic Native/GDExtension jobs are not passes. Candidate-built Native World/Godot/Rapier execution, material ownership/quantity checks and first mixed-body divergence capture remain required.

## Physical blocker

#429 remains physically blocked: strict clearance still fails, and shared barrel/Kestrel/scooper regresses endpoint motion under ActiveNormal001 despite improved sampled overlap. Existing replay locates first native-wrench differences at scooper step 2, barrel step 30 and Kestrel step 32, but does not export contact-bin inputs. A diagnostic-only follow-up on this PR must capture contact bins, passive impulse/torque, actual application and resultant Rapier motion without changing response policy.
