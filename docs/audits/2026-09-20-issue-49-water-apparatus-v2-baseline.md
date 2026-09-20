---
title: Issue #49 Water successor apparatus v2 Current-Water baseline
status: Current
document-kind: evidence
scope: Corrected successor apparatus implementation and source-matched Current-Water control evidence
canonical-for: [issue-49-water-apparatus-v2-baseline]
last-reviewed: 2026-09-20
related-documents: [2026-09-20-issue-49-water-apparatus-v2-registration.md, 2026-09-19-issue-26-post-merge-review.md, 2026-09-19-issue-26-water-leveling.md, ../systems/water-design.md, ../operations/development-claims-remediation-programme.md, ../operations/water-hybrid-pressure-extension-programme.md]
---

# Issue #49 Water successor apparatus v2 Current-Water baseline

## Scope and immutable history

Issue #49 is a bounded apparatus/evidence correction. This evidence does **not**
change production Water semantics, reopen #26, or re-evaluate the two rejected #26
candidate mechanisms.

Historical apparatus-v1 source, the historical `unequal-head-u-tube` identity,
#26 artifacts/hashes/numerical results and Outcome-B disposition remain unchanged.
The historical fixture remains qualified as the three-compartment communicating
reservoir it actually is. The corrected apparatus uses new v2 identities and a new
clean two-limb fixture rather than silently mutating that archive.

The correction contract was frozen first in
[the v2 registration](2026-09-20-issue-49-water-apparatus-v2-registration.md),
commit `2c9b03e8dbaf3121c2adeab01b36dc6617bd9431`, before metric/fixture/runner
behaviour changed.

## Source, runtime and artifact identity

The final apparatus-source proving run for PR #104 was GitHub Actions run
`35536086473` on 2026-09-20.

- PR branch head under test:
  `f9f568be8fc88d979f1db7efc0793cf87c6bb870`.
- GitHub pull-request synthetic merge HEAD actually executed:
  `9db77a06bcf3d1410f4a30ff8e3c2f79508ee8c0`, merging that head into base
  `195a7ce1de3c891a1650e593896fb74ee46a74df`.
- Runner schema: `water-evidence-runner-v2`.
- Apparatus schema: `water-apparatus-v2`.
- Fixture schema: `water-fixtures-v2`.
- Metric schema: `water-equilibrium-v2`.
- Platform: `Linux-6.14.0-1017-azure-x86_64-with-glibc2.39`.
- Compiler: GCC/G++ 13.3.0 on Ubuntu 24.04 runner image.
- Python: 3.12.3.
- Manifest `source_sha256`:
  `251ddd53dbe05f9fee7fafe4e5225b8a36caadb79346cfbe042fb27ba0b8e26f`.
- Built `water_issue49` executable SHA-256:
  `43bf8a7f8a62628ffdb070524f0e911d366fc3bb9fbd73af25484d1803a39692`.
- Retained artifact: `issue49-water-v2-35536086473`, artifact ID
  `10613591045`, ZIP digest
  `sha256:23b7b4fd333dc3a07cb636932e360e912126a117b06612b395aeeed558530f4c`.

This is fresh **Linux runtime** evidence. It is not Windows runtime evidence.
PR #41's historical Windows result remains a Windows cross-build, while its
Linux runtime evidence remains a separate category. Draft PR #33 remains
historical H evidence and did not merge.

## Validation before the campaign

The same exact source run established:

- 13 adversarial apparatus/runner tests under normal Python;
- the same 13 tests under `python -O`, demonstrating that evidence-critical
  validation is not removable Python `assert` logic;
- ASan+UBSan compile and runtime smoke of the clean
  `unequal-head-two-limb-v2` fixture;
- explicit regressions demonstrating the old empty/dry false-flat behaviour and
  old latched sustained-pass behaviour before checking the corrected contract;
- non-empty-output refusal;
- retained nonzero-exit, malformed-output and timeout dispositions;
- completion accounting that rejects a duplicated attempt standing in for a
  missing registered case.

No acceptance threshold was changed after observing the corrected results.

## Registered Current-Water matrix and accounting

The campaign executed the preregistered matrix against production Water unchanged:

- 10 scenario families;
- shifts `-65, 0, 63`;
- normal and mirrored variants;
- 1 and 4 workers;
- 120 registered executions in total.

The completion manifest reports:

- registered: 120;
- accounted: 120;
- dispositions: 120 success;
- missing cases: 0;
- unexpected cases: 0;
- duplicate attempts: 0;
- complete accounting: true.

All 120 results conserved Water mass and reported zero post-setup allocations.
The 60 one-worker/four-worker pairs matched the runner's authoritative
non-timing parity projection; any mismatch would have converted the four-worker
case to a validation failure rather than a successful disposition.

These are apparatus-execution successes, not claims that Current Water satisfies
the physical equalisation targets.

## Corrected equilibrium results

The v2 reducer retains `reached`, `not_reached` and
`invalid_coverage` categorically. Censored observations are not numeric zero,
and sustained acceptance is the preregistered five-sample suffix ending at the
final registered sample.

For the six one-worker shift/mirror views used by the summary:

| Fixture | Half-life disposition | <=1-cell disposition | Notes |
|---|---:|---:|---|
| `calm-settling` | 6/6 reached; median sustained tick 3360 | 6/6 reached; median sustained tick 3360 | full required surface coverage |
| `communicating-pools` | 6/6 `not_reached` | 6/6 `not_reached` | both 42-column limb ROIs remained fully covered |
| `unequal-head-communicating-reservoir-v2` | 6/6 `not_reached` | 6/6 `not_reached` | separately named v2 reproduction of the historical three-compartment geometry |
| `unequal-head-two-limb-v2` | 6/6 `not_reached` | 6/6 `not_reached` | new clean roofed-passage two-limb control |

The clean two-limb fixture derives its common-level target from conserved mass and
registered geometry: `common_level_target_milli = 40474` (surface coordinate
40.474 cells in the fixture coordinate system). At tick 4800 its six one-worker
final limb differences were:

`23580, 24420, 23793, 24207, 23655, 24345` milli-cells.

Thus the corrected apparatus records Current Water as **not reaching** either
the preregistered half-life or <=1-cell target in this bounded clean control. It
does not encode that negative observation as zero or as a pass.

A representative unshifted/unmirrored one-worker case ended with left/right means
`28535` and `52328` milli-cells, a `23793` milli-cell difference. Both limb
ROIs retained full 19/19 wet-column coverage.

## Fixture-appropriate surface evidence

The clean two-limb and communicating fixtures retain left and right contours
separately. The roofed connecting passage is not interpreted as a continuous open
free surface.

At the final sample all six clean two-limb one-worker views had:

- 19/19 wet columns in each limb;
- zero slope-adjusted discrete-terrace steps in the left limb;
- zero slope-adjusted discrete-terrace steps in the right limb.

The successor data still retains the full diagnostic contour where useful, but
free-surface defect classification for communicating geometries is explicitly
scoped to the separate limb surfaces. Historical hill/terrace/contact values
remain sampled proxies. The v2 60-tick cadence does not claim to establish
high-frequency shimmer between samples.

Wall-contact applicability is derived from actual near-wall/contact probe rows
for the relevant fixture/sample rather than from scenario name or elapsed time
alone.

## Phase-separated performance evidence

Timing is platform-specific evidence from this Linux run; it is not a portable
performance guarantee.

For the six one-worker clean two-limb views:

- median active-tick p95: `317.664 us`;
- median final-quiescent-suffix p95: `0.531 us`;
- median whole-run tick time: `229006.348 us`;
- first final-quiescent tick ranged from 761 through 773.

For `calm-settling`, all six cases remained active through the registered
3600-tick horizon. Consequently the quiescent p95 is correctly recorded as
`null` with zero sampled quiescent cases, not as a success-valued `0 us`.

The evidence retains setup, active, time-to-quiescence, final-quiescent and total
phases separately. Historical v1 whole-run timing remains historical and is not
rewritten as though it had this phase split.

## Provenance and interpretation

This v2 baseline corrects the successor apparatus; it does not retroactively
change what #26 measured.

- #26 remains Outcome B for its two exact candidates.
- Apparatus v1 remains qualified historical evidence and cannot govern successor
  acceptance.
- PR #41 supplied a Windows cross-build, not fresh Windows runtime execution.
- Linux runtime evidence remains distinct from that cross-build.
- Draft PR #33 remained historical H evidence and did not merge.
- Production Water semantics are unchanged by #49.
- The clean two-limb negative control is evidence about Current Water under this
  preregistered bounded fixture, not permission to implement #45 or #18.

## Downstream routing

The corrected #49 control is consumed by the live WEX route:

`#49 corrected apparatus + available WEX evidence -> #95 synthesis -> #45 proceed/narrow/recharter/defer/no-go -> directional-reference reassessment -> #18`.

#91 remains already-landed characterization context and is not reproduced here.
#49 is the corrective owner for REM findings F06-F11; #87 later independently
checks the landed repair during remediation exit audit.

The source-matched evidence in this document satisfies the #49 apparatus-side
input to #95. It does **not** select a #45 implementation or make one inevitable.
