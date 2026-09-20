---
title: Issue #49 Water successor apparatus v2 correction registration
status: Current
document-kind: evidence
scope: Frozen pre-implementation contract for the corrected successor Water experiment apparatus
canonical-for: [issue-49-water-apparatus-v2-registration]
last-reviewed: 2026-09-20
related-documents: [2026-09-19-issue-26-registration.md, 2026-09-19-issue-26-water-leveling.md, 2026-09-19-issue-26-post-merge-review.md, ../systems/water-design.md, ../operations/development-claims-remediation-programme.md]
---

# Issue #49 Water successor apparatus v2 correction registration

## Status and source identity

This registration freezes the corrected successor-apparatus contract **before**
metric, fixture or runner behaviour changes.

Implementation branch base: `195a7ce1de3c891a1650e593896fb74ee46a74df`.

Issue #49 is a bounded apparatus/evidence correction. Production Water semantics
are held unchanged. Historical #26 apparatus-v1 source, fixture identities,
artifacts, candidate commits, hashes, numerical results and Outcome-B disposition
remain historical evidence and are not rewritten by this work.

Downstream routing at registration is:

`#49 corrected apparatus + available WEX evidence -> #95 synthesis -> #45 disposition -> directional-reference reassessment -> #18`.

#91 is already-landed characterization evidence and is consumed only as context.
#49 also owns REM findings F06-F11; #87 later verifies the landed repair.

## Version identities

The successor apparatus uses explicit new identities rather than mutating v1:

- apparatus schema: `water-apparatus-v2`;
- fixture schema: `water-fixtures-v2`;
- metric schema: `water-equilibrium-v2`;
- runner schema: `water-evidence-runner-v2`;
- historical three-compartment fixture remains `unequal-head-u-tube` under
  apparatus v1 and is described as an unequal-head communicating-reservoir fixture;
- successor clean two-limb fixture is `unequal-head-two-limb-v2`.

No v1 output is re-labelled as v2 evidence.

## Equilibrium and coverage contract

A surface/equilibrium observation is valid only when its fixture-declared
measurement ROI has the preregistered wet coverage required by that fixture.

Every v2 surface observation records:

- ROI column count;
- wet-column count;
- dry-column count;
- wet coverage as a rational count and derived fraction;
- the extracted per-column contour, retaining an explicit dry marker;
- slope, spread and mean only as measurements over a **valid** observation.

For an ROI that requires all columns wet, any dry column makes equilibrium
invalid. An entirely dry ROI is invalid and can never produce a nominal flat
surface. Fixtures permitted to contain deliberately dry columns must state the
required wet-column set or minimum coverage explicitly in their spec.

For communicating-head fixtures each declared limb ROI must independently meet
its required coverage before a level difference is valid.

## Common-level target for the clean two-limb fixture

The v2 clean unequal-head fixture has two vertical limbs separated above a roofed
lower connecting passage. Its communicating measurement domains are the two limb
ROIs only; the connecting passage is not an open third reservoir.

The fixture manifest records:

- limb horizontal extents and equal cross-sectional widths;
- floor/reference elevation;
- initial Water mass in each limb and the roofed passage;
- total initial Water mass;
- expected wet columns for each limb;
- the mass/geometry-derived common-level target.

For equal-width limbs, the common free-surface target is derived from the total
Water volume remaining after the fixed passage volume, divided by the combined
limb width. The implementation records the integer/rational derivation and the
quantization tolerance imposed by mass8 representation; it does not tune the
target from observed settling results.

## Reached, censored and sustained semantics

Reached-time values are nullable observations, never sentinel numeric zero.

A threshold result is one of:

- `reached`: a tick value satisfying the frozen sustained rule;
- `not_reached`: explicit censoring at the registered horizon;
- `invalid_coverage`: the threshold cannot be evaluated because required wet
  coverage is absent.

First crossing may be reported diagnostically but does not constitute sustained
acceptance.

The sustained rule is a **passing suffix of five consecutive 60-tick samples
ending at the final registered sample**. A transient five-sample pass followed by
later regression is therefore `not_reached` for sustained acceptance. This
definition is fixed before corrected results are observed.

Reducers keep censoring categorical. Medians/ordinary numeric summaries use only
reached values and report reached/censored/invalid counts alongside the statistic;
they never coerce `not_reached` or invalid observations to zero.

## Surface-defect evidence contract

Historical v1 hill, terrace and wall-contact values remain labelled sampled
proxies.

V2 retains the per-sample contour and wet/dry coverage needed to distinguish:

- a broad monotonic slope from discrete terrace shelves;
- local hill/nipple residuals from global slope;
- fixture-required wall contact from geometry where no contact is expected.

Terrace classification operates on residuals after the declared linear slope is
accounted for, so a smooth monotonic incline is not counted merely as a staircase
because adjacent columns differ.

The native sample cadence remains 60 ticks for this bounded apparatus. V2 therefore
reports **sample-to-sample classification turnover only** and makes no claim that
it measures high-frequency shimmer between samples. Rendered acceptance is
separate and is not introduced by #49.

## Performance phase accounting

Timing output is separated into:

1. startup/setup identity, reported separately from `World::tick()`;
2. active ticks: ticks with nonzero measured simulation work;
3. time/work to the first final quiescent suffix where available;
4. quiescent/sleeping ticks after that point;
5. total tick cost.

For active and quiescent tick sets, v2 records count, total, p50, p95, p99 and max.
Whole-run totals remain available but are never described as persistent active
cost. Historical v1 timing values are retained with their existing provenance and
qualified interpretation.

## Evidence-runner disposition contract

The v2 runner refuses a non-empty destination by default. A deliberate fresh
destination is required for an authoritative campaign.

Every registered attempt has a durable structured execution record containing:

- case identity and exact command;
- source/executable/config/platform/worker identities;
- start/completion disposition;
- timeout, nonzero exit, malformed output or validation error details when present;
- stdout/stderr paths where applicable.

The runner must continue accounting for later registered cases after an individual
case failure where execution remains possible. Prior records must not be lost.

A completion manifest is emitted only when every registered case has one accounted
disposition. A campaign with failures may be complete as an accounting exercise
but is not a successful baseline; the manifest records success/failure counts
explicitly.

Evidence-critical validation uses explicit checks/exceptions, not Python
`assert`, so `python -O` cannot remove the contract.

## Baseline matrix

The authoritative v2 Current-Water control matrix is frozen as:

- shifts: `-65, 0, 63`;
- mirrors: normal and mirrored;
- workers: 1 and 4;
- horizons and scenario geometry inherited from the corresponding v1 fixture
  definitions unless this registration defines a versioned successor fixture;
- the new `unequal-head-two-limb-v2` uses a 4,800-tick horizon;
- sample period: 60 ticks;
- production Water policy unchanged;
- observer/debug features off except registered diagnostics;
- capacity prepared before ticking; post-setup allocation remains a hard failure.

Worker parity compares authoritative samples and deterministic work counters while
excluding host-noise timing fields.

The successor campaign includes all retained v1 scenario families under v2
measurement semantics plus the clean two-limb fixture. The historical v1
`unequal-head-u-tube` result is not regenerated or replaced as if it were v2.

## Adversarial regression set

Before accepting the successor apparatus, focused tests must prove:

- dry-column concentration cannot pass equilibrium;
- a completely empty ROI is invalid, not flat;
- a transient five-sample pass followed by regression is not sustained;
- reached plus `not_reached` observations reduce without treating censoring as zero;
- a non-empty output destination is refused by default;
- malformed JSON/output is retained as a failed attempt;
- nonzero child exit is retained;
- timeout is retained;
- completion accounting names every registered attempt.

## Provenance corrections

The successor record must state explicitly:

- PR #41 supplied a Windows **cross-build**, not fresh Windows runtime execution;
- Linux runtime evidence is distinct from that cross-build;
- draft PR #33 remained historical H evidence and did not merge;
- #26 consumed/reconciled only the historical evidence explicitly named by its
  registration/landed records;
- #26 remains Outcome B for its exact candidates;
- apparatus v1 cannot govern successor acceptance;
- this v2 Current-Water control is the apparatus contribution consumed by #95
  before #45 selects or rejects a successor mechanism.

## Completion gate

The registration is immutable except for a clearly labelled post-run addendum
containing source-matched v2 baseline identities/results. Acceptance thresholds
defined above are not relaxed or reinterpreted after seeing corrected outputs.

#49 is complete only after the versioned implementation, adversarial regressions,
fresh Current-Water campaign, worker parity/conservation/boundedness evidence,
runner durability checks, documentation/retrieval reconciliation, required CI,
merge verification on authoritative `main`, and issue/downstream reconciliation.
