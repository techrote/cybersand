---
title: SOL copied-bin mean/extrema admission repair
status: Experimental
document-kind: evidence
scope: Dependent copied-value GCR input-safety repair, not physical clearance
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL copied-Bin tangent mean/extrema repair — 5 November 2026

**DRAFT / HOLD; no default-promotion or merge.** Refs #441 (A01 independent review), #444, #433, #429, #411, #364 and #281. Independent, isolated child of **#441 frozen head `3eb07e6616798dda49083858e5549aec4c8d0cd7`** (header `a25710443f16e96a0ff02d8a4c0e7f734ca466f2`). Current accepted main intake `ba9cbc89029be88b812af59b19e5c59829bbcd90`. #441, #444 and #429 owner branches were **not** edited.

## Deterministic defect

A real two-contact `Bin::add()` product has count=2, tangent minimum=0, mean=0.5, maximum=1, second moment=0.5. Modifying only a copied mean to 101 or -100 leaves the old #441 preflight green but forces quadrature into a single-node fallback, returning a nonzero accepted impulse rather than refusing impossible copied geometry. The independent #441 review already registered this A01 defect; the new test also checks singleton out-of-range means. This is an input-domain issue, **not evidence of corrupt live producers**.

## Narrow repair

After existing finite normal/geometry/statistics checks and before calculating capacity/contact nodes, enforce `min - tol <= mean <= max + tol`, where `tol = 8 * DBL_EPSILON * max(1, |min|, |mean|, |max|)`. This tolerates possible accumulated binary64 roundoff while rejecting materially inconsistent copied moments; it does not modify `Bin::add()`, quadrature, response impulses for valid Bins, kinetic/passivity guards, normals, capacities, LA-Selective, material ownership/IDs, or detachment logic. **Tolerance factor is provisional and requires independent review**.

## Linux exact-file evidence, original failure retained

- #441 exact original header `a25710443f16e96a0ff02d8a4c0e7f734ca466f2`: regression **RED — 8/8 new invalid-policy checks fail**, 12 valid controls pass; GCC 14.2 / Clang 17, C++20 O2 strict warnings.
- Candidate exact header blob `ce97fa104126404eed32b749873e0d4e36a6b56a`, enhanced regression blob `0861e0ab12e2fef50274c731b0c84a78ff0aab9f`: **GREEN — 40 invalid clean refusals, 12 controls, 0 failures** per compiler (32 inherited invalid checks + 8 new).
- Existing #433 Body checks **30 invalid / 4 controls PASS**; unchanged valid-domain differential **120,000 cases per compiler, identical full-Result hash `b1349b7c934248a2`** on parent and candidate. No sampled nonfinite/passivity problems.
- GCC and Clang ASan/UBSan on new focused regression PASS (LeakSanitizer disabled). These are copied-value results; **no Windows or World/Rapier result is inferred from Linux**.

The branch-scoped workflow `.github/workflows/sol-bin-mean-range.yml` executes source-hash-locked baseline RED / child GREEN under Linux GCC and Clang and genuine Windows-2022/MSVC. **The mere presence of workflow does not constitute execution**; inspect exact-head run/jobs before claiming Windows qualification. Generic Native, GDExtension/Godot, the unchanged 520-member chamber, material conservation/owner graph, CPU cost and real penetration clearance remain untested on this child.

## Handover

Review the roundoff bound and producer arithmetic independently. If accepted, reconcile this focused change into sole #441 owner lane, then restack and requalify #444. Compose on latest qualified #429 only after solving its mixed-body physics regression; do not merge this dependent child into main merely because the input-domain regression passes.
