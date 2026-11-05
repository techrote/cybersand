---
title: SOL live copied-contact-bin domain refusal
status: Experimental
document-kind: evidence
scope: Opt-in GCR/LA-Selective copied input safety on dependent draft; not original SOL clearance
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL live copied-contact-bin domain guard — 5 November 2026

**Draft / HOLD.** Refs #429, #433, #438, #364, #281 and #411.

## Source and ownership

Accepted main intake: `ba9cbc89029be88b812af59b19e5c59829bbcd90`.
Owning live policy PR #429 at inspection: `275ce1ee692739b35f400adcf9532f7e89284cfb`; its production header remains blob `c9af2c0aac1efb1ac271897d2c29120c8c81566c` from its earlier execution head.
Isolated parent #433: `bbbc423344ca1d72764557ddacba690b75ea04d7`, header blob `847c948c8f408e177077ff36f7c7ba8594750446`.
New copied-bin guard header blob: `a25710443f16e96a0ff02d8a4c0e7f734ca466f2`; committed regression blob `bfae617a46b9a0e69d6999fdcf40da0fc8e2f815`.

No existing owner branch was modified. This dependent branch changes the header used for value-only and opt-in live normal policies, one deterministic regression, this note, and branch-only qualification CI. It neither enables the experiment by default nor modifies native World, ownership, active material routing, Rapier, or the original SOL response implementation.

## Reproduced defect / implementation

#433 validates copied **Body** input fields, but nonempty copied **Bin** structures can still supply NaN/Inf normals or position sums directly to quadrature and lever-arm arithmetic. The final passivity rejection zeros the applied impulse while leaving `raw_impulse`/raw torque nonfinite. Other malformed bins (zero/unnormalized normal, impossible radius/variance, or reversed tangent bounds) may return an apparently accepted response, so the late energy check is insufficient as an input-domain gate.

Before contact allocation, the new guard refuses nonempty bins with:
- Nonfinite position sums or normals (or nonunit normal squared length outside `1 ± 1e-6`, consistent with the unit face normal produced by projection).
- Nonfinite or negative maximum radius, nonfinite tangent statistics, negative second moment, or reversed tangent min/max.
- Null entries continue to be refused exactly as before. Empty bins retain their previous skip behavior.

Refusal is clean and atomic at the copied solver input boundary: `passive_rejected=true`, `scale=0`, and default-zero impulse, raw observations, energy, capacity, nodes and update counters. The four-pass response, friction and capacity equations, valid-input energy guard and both normal policies are unchanged. The rule is not a general finite-overflow guarantee for arbitrary gigantic **otherwise finite** inputs and is not a runtime authorization for stale/native invalid geometry.

## Exact-file local red/green

Tested with Linux GCC and Clang, C++20 `-O2 -Wall -Wextra -Werror -pedantic`. The committed regression was executed against the byte-identical parent and candidate header blobs:

| Source / compiler | 32 malformed checks | 6 valid controls |
| --- | --- | --- |
| #433 parent / GCC | **32 fail** (expected RED) | 6 pass |
| #433 parent / Clang | **32 fail** (expected RED) | 6 pass |
| Candidate / GCC | **32 clean refusals** | 6 pass |
| Candidate / Clang | **32 clean refusals** | 6 pass |

Additional retained unmodified `sol_live_valid_parity_probe.cpp` from dependent #438 exercised **120,000 valid copied-body/bin inputs per compiler** (Original and ActiveNormal001). Candidate and parent have equal all-Result fingerprints (`b1349b7c934248a2` on each Linux compiler); all runs reported zero nonfinite outputs or passivity violations in this sampled valid domain. Candidate preserved #433's separately committed Body-domain regression: 30 invalid clean refusals and four valid controls per Linux compiler.

GCC ASan/UBSan on the candidate's 32+6 bin regression and 120,000-case valid parity passed locally with LeakSanitizer explicitly disabled. Clang ASan/UBSan bin regression passed locally; Clang sanitized full parity did not complete in the bounded local attempt and is **not claimed as passed**.

Branch-scoped CI `.github/workflows/sol-live-bin-domain.yml` requests **actual Windows-2022/MSVC** and Linux source-locked red/green jobs. **CI creation is not test execution**; inspect run artifacts and exact head after PR opening. Full native/Godot/Rapier 520-member chamber, material conservation, original SOL clearance and CPU cost are not qualified by copied-value tests.

## Decision and next gate

**Keep Draft / HOLD.** The improvement closes a reproducible malformed-input safety defect but does not fix persistent embedded Sand or the observed mixed-body motion regression in #429. Request exact-head hosted Linux and actual MSVC evidence, independent source review and real World/Rapier physical comparison before any admission; do not merge or promote active-normal by default.
