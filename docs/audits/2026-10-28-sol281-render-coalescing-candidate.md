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

## Addendum: failed 7d716a5f qualification and deterministic gate correction (28 October 2026)

This section adds to the snapshot above; it does not rewrite it.

### Readback of 7d716a5f

[Run 40762646166](https://github.com/techrote/cybersand/actions/runs/40762646166)
on `7d716a5f` (tree `41b85c9e`) **failed** on both actual hosts. `source` and
`windows-build` passed. `linux-rapier` and `windows-rapier` each failed the
single assertion *opt-in live native stream coalesces an actual full-plus-dirty
packet* in the `0 1 1` cohort, with `render_coalesced_packets: 0` and
`render_pending_full_before_samples: 0` on both OSes. The 32/32 unit test,
motion, failure-path, lifecycle, unresolved, ejection-policy, default and
CPU-ACK cohorts passed before it. The B=289 `compound-extended` cohort never
ran for that source on either OS. `7d716a5f` is therefore **not qualified**;
[run 40762379333](https://github.com/techrote/cybersand/actions/runs/40762379333)
qualifies only `6927ace3`.

### Causes found by review

An AI-generated [review of #283](https://github.com/techrote/cybersand/pull/283#pullrequestreview-5689919617),
posted from the owner's account and **not** an independent human approval,
reproduced the failure on Windows 11 with Godot 4.7-stable `5b4e0cb0f` and the
CI-built `7d716a5f` DLL (SHA-256 `2068ee83bba326f7cb503eac1a3c5cfc68dedf722c9cd0d6c9666e03e83238dc`,
equal to its manifest):

1. **Racy gate.** With CPU ACK, the stream usually leaves the retained-full
   state once the first full frame is acknowledged. Whether a *sampled*
   snapshot is coalesced therefore depends on timing; 1 of 3 local runs failed.
   The counter was a per-snapshot bool read through latest-only
   `take_latest_snapshot()` in a 360-sample window, so it sampled rather than
   counted.
2. **Unbounded overlay work.** Preflight bounded each rectangle by the input
   size but not their sum. 64 aliased rectangles over one 65,536-byte input
   were admitted: 4,194,304 per-byte writes, about 106 ms median for one
   publication.
3. **Vacuous refusal tests.** The legacy fallback appends in place to the
   retained array, which aliased the test's shared full frame. After the first
   refusal, every later case was refused for the wrong reason (baseline size).
   With the x-bound and World-generation guards deleted, the 32-check test
   still passed 32/32.

Mechanism evidence (local, headless, three processes per arm): never-ACKed +
coalescing coalesced every sampled refresh with zero forced-full retries.
Render-refresh p95 was 0.46–0.51 ms, against 17.9–18.9 ms for the never-ACKed
control.

### Correction source 819c6677

Executable source [`819c6677e26fcdabe961097f855bd06fd5609917`](https://github.com/techrote/cybersand/commit/819c6677e26fcdabe961097f855bd06fd5609917)
(tree `276726e015f801886622ec68386f9a83e929c41a`) changes only GDScript diagnostics, tests and the scoped
workflow:

- `CyberSimulationWorker` publishes monotonic worker-lifetime totals on every
  snapshot: `snapshot_render_refresh_total`,
  `snapshot_render_dirty_onto_full_total`, `snapshot_render_coalesced_total`,
  `snapshot_render_forced_full_retry_total` and
  `snapshot_render_ack_clear_total`. ACK clears count only clears that
  released retained bytes.
- `_try_coalesce_native_render_dirty` refuses when the summed rectangle
  overlay exceeds 65,536 bytes.
- `test_solid_detachment_coupling.gd` (still 68 checks per arm) asserts counts,
  not samples:
  - opt-out never coalesces;
  - every unacknowledged, uncoalesced dirty packet onto a retained full frame
    forces exactly one retry;
  - the **unacknowledged opt-in arm (`0 0 1`) must coalesce every such packet
    with zero retries**.
  The CPU-ACK arm (`0 1 1`) is observational.
- `test_solid_detachment_render_ack.gd` grows from 32 to 39 checks:
  - each refusal gets a fresh retained frame and asserts the exact legacy
    post-state;
  - an aggregate-cap refusal;
  - exact 64-rectangle, 65,536-byte and overlay-cap admission;
  - a copy-not-in-place check;
  - a three-packet differential oracle against the legacy full+append image.
  Mutation checks: deleting the aggregate cap, the x bound, the generation
  guard or the copy each fails at least one check.
- New `test_solid_detachment_render_coalescing_owner.gd` (17 checks) runs a
  real native RG8 worker on a paused World with workers 1 and 4:
  - a stale ACK cannot clear a coalesced frame;
  - an exact ACK restores dirty-only publication;
  - a reset never coalesces onto the old generation.
- The workflow gates five fresh `0 0 1` processes per OS, plus census
  assertions for every cohort.

Coalescing remains disabled by default. There is no change to native C++,
material or liquid law, ejection policy, coupling geometry, body ABI, cell
ownership or main-thread Rapier ownership.

Local pre-push evidence, 2026-10-28 (Windows 11, Godot 4.7-stable `5b4e0cb0f`,
headless). Evidence type: native runtime. The CI-built `7d716a5f` DLL (SHA-256
above) is valid for this source because `native/` and
`godot/native_extension/` are unchanged. Commands used 120 s (unit/owner) and
240 s (cohort) timeouts. Results:

- `test_solid_detachment_render_ack.gd`: 39/39.
- `test_solid_detachment_render_coalescing_owner.gd`: 17/17. Each worker count
  (1 and 4) reported 3 coalesced = 3 dirty-onto-full, 0 retries and 1
  byte-releasing ACK clear.
- `test_solid_detachment_coupling.gd`, policy A=81 unless noted, 68/68 for
  every cohort. Census counts are worker totals:

| cohort (args) | refreshes | dirty onto full | coalesced | forced-full retries | render-refresh p95 ms |
|---|---|---|---|---|---|
| default `0 0 0` | 226 | 224 | 0 | 224 | 22.1 |
| CPU-ACK `0 1 0` | 196 | 118 | 0 | 118 | 19.6 |
| gate `0 0 1` ×5 | 166–193 | = coalesced | 164, 172, 183, 190, 191 | 0 | 0.51–0.67 |
| observed `0 1 1` | 188 | 68 | 68 | 0 | 0.047 |
| B=289 `1` | 274 | 272 | 0 | 272 | 20.5 |

  In the observed `0 1 1` cohort, the old sampled counter reported 0 coalesced
  snapshots while the worker coalesced 68 packets.
- `test_render_world_generation.gd` 23/23; `test_render_patch_handoff_regression.gd` passed.

There is no Linux local run.

### Source-matched scoped result for 819c6677

[Run 40776168081](https://github.com/techrote/cybersand/actions/runs/40776168081)
on exactly `819c6677` (tree `276726e0`) **passed all four jobs**: `source`,
`windows-build`, `linux-rapier` and `windows-rapier`. Evidence type: native
and actual Godot 4.7/Rapier headless runtime.

Identities:
- Source archive SHA-256 `4895bb21…0aa6` (recomputed locally).
- Windows DLL SHA-256 `bc8d51f5…02fc`; all 552 manifest inputs re-hashed after
  EOL-only restoration.
- Linux runtime SHA-256 `244b0270…85bb`.
- All four artifact ZIP digests are recorded in the
  [successor receipt](sol281-2026-10-28/render-coalescing-gate-correction-receipt.json).

Results, the same on both OSes:
- Linux focused native: 13,074 checks.
- Unit 39/39 and owner 17/17. Each worker count (1 and 4) reported
  3 coalesced = 3 dirty-onto-full and 0 retries.
- Motion 21, failure paths 20, lifecycle 296, unresolved 43.
- Every compound cohort 68/68 with 520 members and 6 proxies.

Worker census totals:

| cohort | Linux dirty-onto-full / coalesced / retries | Windows dirty-onto-full / coalesced / retries |
|---|---|---|
| default `0 0 0` | 216 / 0 / 216 | 225 / 0 / 225 |
| CPU-ACK `0 1 0` | 228 / 0 / 228 (1 ACK clear) | 213 / 0 / 213 (27 ACK clears) |
| **gate `0 0 1` ×5** | **200, 174, 204, 199, 167 — all coalesced, 0 retries** | **182, 153, 181, 170, 178 — all coalesced, 0 retries** |
| observed `0 1 1` | 75 / 75 / 0 (102 ACK clears) | 70 / 70 / 0 (125 ACK clears) |
| B=289 `1` | 227 / 0 / 227 | 243 / 0 / 243 |

Render-refresh p95 by cohort:

| cohort | Linux | Windows |
|---|---|---|
| default `0 0 0` | 40.1 ms | 23.1 ms |
| gate `0 0 1` | 0.15–0.16 ms | 0.36–0.39 ms |
| observed `0 1 1` | 0.037 ms | 0.028 ms |

What the counts newly establish:
- Without coalescing, the CPU-ACK stream stays locked in the forced-full
  retry state on Linux.
- With coalescing, the same stream recovers to ACK-cleared dirty publication.
  The sampled counter of `7d716a5f` could not show this.

**Qualification scope:** this qualifies `819c6677` for the scoped SOL281
Linux + actual-Windows headless matrix only.

Explicit gaps:
- The Windows build is not byte-reproducible. Unchanged native inputs produced
  DLL `bc8d51f5…` here and `2068ee83…` for `7d716a5f`.
- Main-thread upload cost and interactive GPU pacing are unmeasured.
- Root-cause alternatives (run-based `copy_render_cells`, partial ACK of the
  full baseline) have not been compared.

There is no ready-PR matrix, independent human review or default change.
B=289 remains NO-GO, and every physical gate remains open.
