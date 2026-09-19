---
title: Issue #26 post-merge review and apparatus qualification
status: Current
document-kind: evidence
scope: Independent post-merge review of issue #26 experimental validity, apparatus limitations and required corrective gate before issue #45
canonical-for: [issue-26-post-merge-review]
last-reviewed: 2026-09-19
related-documents: [2026-09-19-issue-26-registration.md, 2026-09-19-issue-26-water-leveling.md, ../systems/water-design.md, ../operations/architecture-programme.md, ../reference/status-and-roadmap.md]
---

# Issue #26 post-merge review — 2026-09-19

## Disposition

Issue #26 remains **closed / completed Outcome B** for the exact experiment it ran.

The review independently checked the merged PR #41 apparatus, retained baseline and
candidate evidence, workflow validation and successor instructions. The two tested
radius-2 candidates remain legitimate negative results:

- the head-scaled local-drive candidate did not meet its registered bulk/head gates;
- the bounded same-row horizon candidate did not meet its registered bulk/head gates;
- neither candidate justified the preregistered combined arm;
- rejected candidate semantics were removed before merge;
- Current production Water semantics were unchanged.

The review therefore does **not** reopen #26, resurrect either candidate or weaken
their rejection.

However, the retained `water_issue26` apparatus is **not approved as the acceptance
oracle for #45**. Confirmed metric/fixture/evidence defects allow false acceptance or
over-interpretation in successor work. Issue #49 owns the bounded correction and is
a hard prerequisite before #45 freezes numeric thresholds, implements a candidate,
or accepts/rejects a head-transmission mechanism using this apparatus.

## Evidence recheck

The retained baseline and candidate archives were reprocessed independently.

Across the frozen baseline, candidate-bearing control reruns and both candidate
runs, the recorded evidence supports:

- exact sampled closed-Water quantity for the registered runs;
- expected 1/4-worker authoritative sample parity;
- zero recorded post-setup owned allocations;
- unchanged communicating-pool head error for both candidates;
- unchanged historical unequal-head fixture error for both candidates;
- failure of both candidates against the frozen required benefit gates.

Thus the negative result is not merely a documentation assertion.

## Confirmed apparatus defects

### Equilibrium / settling false-pass

The v1 surface metric excludes dry columns from its contour. A mass-conserving
state can therefore concentrate all Water into a subset of columns while reporting
a nearly flat surface among only the wet columns. An entirely empty ROI also yields
a nominal zero spread.

The v1 sustained-threshold logic latches a pass after five sampled successes and
does not revoke it if later samples fail. Unreached thresholds are encoded as
numeric zero, which can contaminate ordinary reductions as if zero meant immediate
success.

These defects do not overturn the two candidate rejections: the candidates already
fail independent primary head/communicating gates. They do prevent v1 from serving
as a trustworthy future acceptance system.

### Historical unequal-head fixture topology

The fixture named `unequal-head-u-tube` leaves the central section open above the
lower connecting passage, producing a third open compartment. It is useful retained
evidence for an unequal-head communicating system, but it is not the clean two-limb
U-tube described in the #26 audit and successor instructions.

Do not alter the historical fixture while retaining its old reference identity.
#49 must version it and add a new clean two-limb fixture with a roofed connecting
passage and a mass/geometry-derived common-level reference.

### Performance interpretation

The reported whole-run p95 values pool startup/active and sleeping ticks. When a
candidate changes how long a fixture remains active, the p95 can move across the
active/sleep mixture boundary and greatly exaggerate the apparent per-active-tick
ratio.

The horizon candidate still performs materially more useless work without reducing
the communicating-head error. The qualified conclusion is increased transient and
total work with no head benefit, not a demonstrated persistent ~600x active-tick
cost.

Future evidence must separate startup/active cost, time/work to quiescence,
sleeping cost and total run cost.

### Surface-defect proxies

The v1 hill/terrace/contact values are sampled diagnostic proxies, not complete
implementations of the declared lifetime and rendered/authoritative contract:

- dry columns are absent from the contour;
- terrace counting can classify a monotonic stepped slope as many terraces;
- the wall-gap proxy is not conditioned on whether fixture geometry/time actually
  requires wall contact;
- 60-tick sampling cannot establish high-frequency shimmer;
- native authority metrics do not establish rendered acceptance.

Historical values remain useful with these limitations stated.

### Evidence-runner durability

The v1 Python runner permits reuse/overwrite of an existing output directory,
uses Python `assert` for evidence-critical checks, and does not guarantee a
structured retained record for every timeout/nonzero/malformed case before abort.

No corruption of the retained #26 archives was found. The weakness is prospective:
#45 must not rely on this runner as-is for durable acceptance evidence.

## Documentation / platform corrections

PR #41 final validation provided:

- a Windows x86_64 **cross-build** of the GDExtension;
- Linux x86_64 GDExtension build and actual Godot runtime/ABI regression;
- native C++ validation including sanitizers and TSan;
- documentation/provenance validation.

It did **not** provide fresh Windows Godot runtime execution. Future records must
not describe it as Windows runtime regression.

Draft PR #33 remains historical H evidence rather than a merged current record.
#26 consumed its H conclusions/identities as an input while preserving source
identity; #49 must make that provenance boundary explicit rather than leaving the
old preregistration condition ambiguous.

## Required corrective successor

[#49](https://github.com/techrote/cybersand/issues/49) is the bounded corrective
work item.

It must, before #45 implementation/acceptance:

1. freeze a correction registration;
2. add adversarial regressions for dry-column concentration, empty ROI,
   transient-pass-then-regress and censored reductions;
3. version corrected equilibrium metrics and represent `not_reached` explicitly;
4. preserve the historical three-compartment fixture and add a clean two-limb
   unequal-head control with a fresh Current-Water baseline;
5. separate active/startup/sleep/total performance evidence;
6. harden evidence output against overwrite and unrecorded failures;
7. qualify surface proxies and add the successor measurements actually needed;
8. synchronize #45/#18/#14/MicroScenarios/RAG instructions.

## Ordering after review

The affected Water architecture path is:

`#49 apparatus correction -> #45 saturated-head architecture disposition -> directional-reference reassessment -> #18 G-M admission/no-go -> #20/G-B if justified -> G-final`.

#28/#29 remain independently runnable under the MicroScenarios programme. Only
Water-dependent provisional evidence affected by a later accepted semantic change
requires targeted revalidation.

## Historical preservation rule

Do not edit old #26 artifacts, hashes, candidate SHAs or numerical result files to
make them look as if they were generated by corrected apparatus. New metric schema,
fixture geometry or reduction rules require new version identifiers and a new
source-matched control baseline.

The post-merge review qualifies interpretation; it does not rewrite the historical
experiment.
