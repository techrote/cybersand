---
title: PR 472 PressureFlow run repair — unadmitted protected-source transition proposal
status: Proposed
document-kind: audit
scope: Source-pinned technical proposal only; independent MAT-AUTH review/admission expressly outstanding
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-04-mat-auth-reviewed-transitions.md, 2026-11-04-lcb201-world-pressure-transition.md, 2026-11-06-pf-run-head-repair-draft.md, ../operations/material-catalogue-shadow.md]
---

# Draft PR #472: proposed `world_pressure.inc` reviewed transition

**Status: UNADMITTED. Do not add this to `REVIEWED_TRANSITIONS`, change a frozen compatibility lock, call the transition reviewed, mark PR ready, or merge.** Independent read-only technical assessment and owner admission have not occurred.

| Required field | Proposal |
|---|---|
| Repository / Draft PR | `techrote/cybersand`, [#472](https://github.com/techrote/cybersand/pull/472) |
| Stacked parent / base branch | #406, `claude/water-ballistic-hybrid`, pinned `4a80af2a891332176a3912a235582d77d076a185` |
| Protected path / role | `native/src/world_pressure.inc`; policy admission, physical hash and CYPS restoration |
| Previously admitted LF SHA-256 | `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca` |
| Candidate LF SHA-256 | `bbc33dbc6b12404de06db2dda5a16b90a7d787f4d183ed06ad9b5751b631f360` |
| Candidate source commit containing those path bytes | `05cc48394c1a82bc08bef7fbdecaaf50ca18dad4` |
| Execution identity | `kPressureOptimizationExecutionVersion = 5`, independently refreshed cached/dormant identity goldens |
| Frozen baseline and compatibility locks | **Unchanged; no admission entry added** |
| Technical decision at authoring | **REVIEW REQUIRED**, not admitted or production qualified |

## Observed exact protected-source delta

A source diff against the pinned #406 parent shows **188 inserted and 26 removed lines in the protected path**, with all eleven hunks in `World::prepare_pressure_tick()` or `World::compute_pressure_heads()`. The diff introduces dirty-Y closure preflight, bounded selected-run and row candidate accounting, selective complete-run base-head repair, counters, and a nonresident-Y-gap chain reset consistent with the preflight. It does not edit `physical_state_hash`, `liquid_comparison_hash`, policy admission/decode, CYPS serialization/restore functions, or material definitions. That scoped diff is **not by itself proof** of unchanged physical behaviour.

The new gap-boundary test in `native/tests/test_workbench_pressure_heads.cpp` and the A/B/C reference/cached/forced-fallback differential matrix exercise source semantics but are not an independent MAT-AUTH role review. Historical and newly executed native tests must be distinguished from the still missing source-matched Godot runtime and named canvas measures.

## Independent admission requirements

1. A separate **read-only** MAT-AUTH reviewer must inspect the pinned parent and the exact candidate source, distinguish execution-only changes from possible material/consumer authority, and independently validate source LF identities, ancestry and branch reachability.
2. The reviewer must verify no changes to material ID/order, pair-query semantics, solver family/policy admission, physical-state hashes, CYPS data restoration, or any production consumer's material interpretation. Evaluate fallback/re-entry, base-head status, gas, wake, masks and scheduling with source-matched tests and any defects or performance regressions explicitly disclosed.
3. Only after an affirmative independent acceptance and owner admission may a separate authorized integration change add a code-pinned reviewed transition entry with `path`, `from_lf_sha256`, `to_lf_sha256`, `source_commit`, this `record` path, `issue` and `pr`. That operation must satisfy the existing authenticated-chain guard, keep all identity inputs and frozen locks untouched, and be verified at the resulting head. A descendant or squash may require a separately assessed reachability/commit identity.
4. Re-run exact-head `python3 tools/material_catalogue/compatibility.py --check`, material shadow parity and full Documentation/provenance workflow **only after** legitimate admission. Until then failure is the correct protection result.

## Negative qualification evidence affecting admission

The pinned-parent/GCC 13 native host-scale comparison ([Actions #42301636450](https://github.com/techrote/cybersand/actions/runs/42301636450)) demonstrates severe **2.3–2.5x slower** active cached/dormant total ticks in 1024² moving-mask, gas and churn profiles for source `6c40b58f52f1151fac133fd696ecd41d5655ddca`. The candidate spent ~18.1 ms in preflight and ~19.6 ms in subsequent column/row work per churn tick with no fallback; the full region was probed and rewritten. The subsequent gap correctness repair does not yet have completed corresponding workbench measurements. This is a technical **NO-GO signal** for the current optimization, independent of the protected-source admission mechanism. **Do not admit/publish an exact but slower design on the basis of correctness tests alone.**

The official [Documentation/provenance check](https://github.com/techrote/cybersand/actions/runs/42305345227) on branch head `d5d12dab375e3375ea4c9b3238994865b0225278` reported the exact target mismatch above. This is an expected, retained failure; do not suppress it.
