# SOL #418 fallback provenance qualification — 2026-11-05

**Scope:** isolated test/telemetry continuation stacked on open Draft #418, exact parent `15a78545498fb0a179cebb57680aac48cc773122`; recorded current `main` `ba9cbc89029be88b812af59b19e5c59829bbcd90`. Separate #421 copied-value active-normal research remains untouched.

## Problem

#418 safely retries the historic normal solver when an opt-in normalized proposal passes through a *finite but energy-increasing* candidate path. Before this change, the returned `Result` was indistinguishable from an accepted normalized response. This prevents any later live A/B from attributing observed contact/CPU outcomes to the experimental response versus a hidden baseline fallback.

## Change

- Add `Result::historical_fallback_used`, default false, set true **only** after actually retrying the original solver, regardless of whether the historical solver subsequently refuses.
- Preserve the exact original candidate energy threshold, rejection semantics, capacity, iterations, impulses and default response. The additional flag occupies existing padding: `sizeof(Result)` remains 184 bytes, `offsetof(passive_rejected)` remains 176 (GCC x86-64).
- Add a nine-assertion source-matched witness showing the fallback's impulse, torque, and final energy are **bit-equal** to the default response; repeat and accepted/noncontact/preflight controls.
- Add a fixed-seed four-domain synthetic stress sweep with passivity, finite-state, candidate-only-refusal, fallback labeling and exact-output invariants.

## Executed source-specific local Linux C++ tests

Compile from repository root:

```sh
for CXX in g++ clang++; do
  for f in sol_active_normal_weight sol_active_normal_fallback sol_active_normal_differential sol_active_normal_fallback_gate sol_active_normal_fallback_properties; do
    $CXX -std=c++20 -O2 -Wall -Wextra -Werror -pedantic -I native/include tools/experiments/$f.cpp -o /tmp/$f
    /tmp/$f
  done
done
```

- GCC 14.2 and Clang 17: original five controls PASS, #418 five-check fallback witness PASS, original 300,000-case differential PASS (0 candidate-only refusals), new nine-assertion provenance test PASS.
- GCC and Clang full **1,000,000** synthetic properties each PASS: baseline refusals **19**, candidate refusals **8**, candidate-only **0**, baseline-only **11**, fallback flag occurrences **27**, fallback mismatch **0**, default incorrectly flagged **0**, nonfinite responses **0**, energy violations **0**. The random distributions are synthetic and not gameplay occurrence estimates.
- GCC AddressSanitizer+UBSan: provenance witness PASS. Additional shortened 4,000-case property run PASS (0 violations); does not replace full sanitizer coverage.
- Extreme-domain 1,000,000-case exploratory local run: zero candidate-only refusals where baseline energy was finite. Not added to the repository because it includes physically unrealistic scale ranges and is not an admission fixture.
- Source blob identities: header `33a80df91d0205d947e5d80a7c2930801362d6dc`; provenance fixture `920dc9a578d87e3ffb8f90d0c4bf764fd848f684`; property fixture `aa675129a968d923f3c8d462f67652800ab0fec8`.

## Admission and limitation

**DRAFT / HOLD / DO NOT MERGE.** The change is observability only, no live caller currently opts into #418's normalized solve. No native World/actual Rapier or #411 520-cell chamber A/B was executed; no original SOL ownership, material accounting, Windows MSVC, independent review, full native build or live performance cost was qualified.

**Next:** with a separately reviewed and explicitly opt-in live adapter, record `historical_fallback_used` alongside candidate impulse/torque, penetration, contact energy, material conservation and per-stage CPU cost on unchanged #411 chambers. Preserve valid entrapment and do not infer that a stationary rigid body is a defect.
