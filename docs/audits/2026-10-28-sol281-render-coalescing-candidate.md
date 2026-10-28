---
title: SOL281 bounded render-full and dirty-patch coalescing experiment
status: Current
document-kind: audit
scope: Exact-source preregistered draft-only render worker candidate, qualification in progress; no physical-policy or GPU-performance acceptance
canonical-for: [sol281-render-coalescing-candidate-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-28-sol281-render-ack-consumer-control.md, sol281-2026-10-28/render-coalescing-candidate-receipt.json]
---

# SOL281 retained full + native dirty render coalescing (28 October 2026)

## Frozen source, provenance and causal premise

Issue [#281](https://github.com/techrote/cybersand/issues/281) and
[PR #283](https://github.com/techrote/cybersand/pull/283) remain open/draft,
stacked on still-draft #282; neither is merged or qualified for gameplay.

Frozen successful predecessor executable
[`5531ac7d47141e040a368c0057be640cbf0e3721`](https://github.com/techrote/cybersand/commit/5531ac7d47141e040a368c0057be640cbf0e3721)
and docs-only head `88154d0e49c71e5839b94b9691596b2e63e287c9`
passed [four-job scoped Linux and actual-Windows run 40758417713](https://github.com/techrote/cybersand/actions/runs/40758417713)
(1,519 assertions per OS, zero failures) and
[final-head docs run 40759938408](https://github.com/techrote/cybersand/actions/runs/40759938408).
The [causal packet census](2026-10-28-sol281-render-ack-consumer-control.md)
found every sampled second native call was caused by a retained 2,097,152-byte
full RG8 snapshot plus a newly appended dirty patch crossing the existing
worker pending-byte guard. It was not native backpressure, rectangle count
or native packet capacity. CPU-consumed/ACKed control streams did **not**
establish a p95 speedup or representative GPU frame pacing.

Before editing the new candidate, the
[preregistration was published](https://github.com/techrote/cybersand/pull/283#issuecomment-6479596107).
There were two implementation commits:
1. [`6927ace31c4a4d9acfea9f16baa744c5c6783cf1`](https://github.com/techrote/cybersand/commit/6927ace31c4a4d9acfea9f16baa744c5c6783cf1)
   (tree `14a17c301a1ff60d20e46bfec0ebd5880af77c24`): bounded worker copy-on-write
   candidate, 32 direct payload/assertion checks instead of 17, workflow checks.
2. [`7d716a5f62bfdf6a9a9a6ed90f923f4ca418539e`](https://github.com/techrote/cybersand/commit/7d716a5f62bfdf6a9a9a6ed90f923f4ca418539e)
   (tree `41b85c9e121388df9fe803211af06a176e6bd07c`): new immutable one-/two-call coalescence census,
   opt-in session argument, actual Linux/Windows Rapier fourth cohort,
   68 live compound assertions per arm instead of 66.

**The second source is not qualified by the first source's CI.** The
intended current-source [scoped host run 40762646166](https://github.com/techrote/cybersand/actions/runs/40762646166)
and [documentation/provenance run 40762653884](https://github.com/techrote/cybersand/actions/runs/40762653884)
were still executing/queued at record creation. First-source
[scoped run 40762379333](https://github.com/techrote/cybersand/actions/runs/40762379333)
and [docs run 40762388082](https://github.com/techrote/cybersand/actions/runs/40762388082)
are separately source-bound; the first-source docs job passed, but that
does not transfer to the newer source or this documentation successor.
No assertion count, source-manifest hash or runtime identity is claimed
as passed for the new candidate until host artifacts are inspected.

## Exact algorithm and limits (experimental, disabled by default)

The existing `CyberSimulationWorker` is still the sole owner of
pending render packets. A new `_experimental_render_full_coalescing`
bool is **false by default** and only assigned to the SOL281 worker
before its thread starts. The worker receives exactly the same native
packets, calls the same native World, and owns no Rapier bodies or RIDs.

On a dirty native packet only, it checks status `Published`, nonzero
serial, World generation and channel equality. A pending baseline must
consist of precisely one full-world 1024×1024 rectangle, offset zero,
row pitch `1024 * channels`, exactly one complete RG8/R8 frame and
no later appended metadata. The incoming input is restricted to at
most 64 rectangles and 65,536 dirty payload bytes, including full
preflight of all x/y/width/height/offset/row strides. All checks finish
before bytes are changed; then the worker duplicates the full frame
and overlays dirty pixels in source rectangle order. The original
full rectangle is retained and existing monotonic render serial and
immutable payload-generation counters advance. The copy is at most
2,097,152 RG8 bytes; because the implementation touches each admitted
rectangle, total pixel writes require measurement and a strict
aggregate-work cap before production promotion.

When not enabled, not eligible, malformed or oversized, the old append
and forced-full capacity behavior runs. Coalescing does not implicitly
ACK, modify actual source materials, change `take_render_snapshot` in
the native core, alter Water or material construction, change probe
policy, affect collision geometry, or cross the Rapier owner boundary.

## Qualification tests and observations

The 32 scripted CPU-byte conformance assertions on the first implementation
exercise overlap precedence, corner/edge pixels, old immutable publication,
strict CPU consumer, serial and generation, disabled default, status,
64KiB/64-rectangle limits, out-of-bounds, bad pitch and channels.
The two additional compound assertions per arm require default-off
to produce zero coalesced packets, or explicit opt-in to observe at
least one live merge. The fourth controlled A=81 host cohort enables
both CPU-image consume/ACK and coalescing. Existing three cohorts
remain unchanged: A=81 unacknowledged, A=81 CPU-consumed, B=289
unacknowledged. Under actual Linux and Windows Godot/Rapier, validate
the real 520-cell native tree, six proxy rectangles and both holes,
Sand104 and Water mass1020, deterministic finite worker bounds,
12-field result ABI, source/epoch fences and no stale owner results.

**No new measured runtime performance or successful actual-host
acceptance is established at this audit snapshot.** The initial Linux
and Windows source-matched workflow runs are tracked in the receipt.
A reference stream can still require two native exchanges for other
reasons; no faster average, tail latency or interactive 60 FPS is
assumed. Earlier failed and negative trials remain valid and have
not been overwritten. The 289-probe physical ejection candidate
remains NO-GO; safe admissible mass-conserving material relocation
and reactive Wood/fracture/desoliding/restoration/persistence are
unresolved. Independent review, full ready-PR gates, normal gameplay
render delivery and actual GPU pacing are also not qualified.

## Go/no-go boundary

Do not admit the coalescing candidate unless source-matched tests
demonstrate correct full+dirty material bytes and refusal behavior
on both actual OS hosts, coupled native/Rapier invariants, explicit
allocation/work bound and no regressions. No hosted headless speed
distribution alone can qualify interactive 60 FPS, and no render
result promotes physical B=289. Historical source and negative
evidence remain immutable.
