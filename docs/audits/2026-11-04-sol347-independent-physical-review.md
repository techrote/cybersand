---
title: SOL347 independent physical-blocker and integration review
status: Current
document-kind: evidence
scope: Independent source and evidence review of draft PR347, one isolated numerical diagnostic, and a proposed bounded repair/replay specification; no production implementation or integration acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL347 independent physical-blocker and integration review

**Disposition: REPAIR FIRST — confirmed bounded numerical energy-evaluation defect.**
The aggregate-specific planner can reject a valid approaching contact because its
kinetic-energy calculation loses precision before comparing against the existing
tolerance. Repairing that evaluation is a defensible small #364 task. It is **not
established as the cause of the live burial**, and does not repair the independent
baseline cost failure. Synchronized contact replay remains necessary.

**Production integration remains inadmissible.** Keep #347 draft/unmerged and
#281/#12 open. #365 remains blocked. No contact coefficient, force law, production
default, protected-source lock, GCR branch or implementation source was changed
by this review.

Review method: isolated detached source worktrees; independent lifecycle,
cost/evidence and GCR reviews; direct GitHub identity/status verification; a
separately registered pure-planner diagnostic outside the source worktrees.
The only newly executed engine code was the unchanged planner in an empty Godot
project. No native/Rapier physical trial or broad CI campaign was dispatched.
The report and reproducibility packet are a separate documentation-only draft
based on main `7ef4856e`, not a modification of #347.

## Contents

1. [Source and runtime authority](#1-source-and-runtime-authority) — Frozen heads, executed sources, artifacts and the limits of this review's verification.
2. [Accepted and unaccepted contracts](#2-accepted-and-unaccepted-contracts) — The bounded transfer works; production lifecycle and convincing contact remain unqualified.
3. [CPU failure classification](#3-cpu-failure-classification) — The one baseline miss is real, with measured workload and consumption amplification.
4. [Penetration, refusal and numerical diagnosis](#4-penetration-refusal-and-numerical-diagnosis) — Endpoint burial, response census, causal limits and the new reproducible defect.
5. [GCR evidence and ownership](#5-gcr-evidence-and-ownership) — Burial improvement, lost loading, selective NO-GO and the compound boundary.
6. [Material-catalogue source guard](#6-material-catalogue-source-guard) — The exact two #347 incompatibilities and the legitimate transition owner.
7. [Minimum repair and decisive experiment](#7-minimum-repair-and-decisive-experiment) — A staged #364 specification with frozen inputs, controls, costs and prospective stop rules.
8. [Integration disposition and stopping point](#8-integration-disposition-and-stopping-point) — Automatic correctness, physical quality, human acceptance and remaining gates.

## 1. Source and runtime authority

All live identities below were rechecked on 4 November 2026. A PR head,
compiled source, acquisition source and runtime-publication child are distinct
authorities.

| Authority | Exact identity | Meaning |
|---|---|---|
| Accepted main | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`; tree `36ce5a01e754a141c321f41cac7f1c6b6059c371` | Contains merged #371 shadow tooling and its immutable-source guard. |
| Reviewed #347 | `5b9b5a982e4638f4609309f996b92825d3dc36e4`; tree `e396ed539370e1a2a95f9ef9eca932a7ec5d6546` | Open, draft, unmerged. Its common ancestor with current main is `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d`; #371 has not been integrated into it. |
| Last compiled/executed #347 source | `749fb8b597ad866f7535f26442e904207c4f7611`; tree `77a7bc2ed4d1f7ab339dd4a16fd082fccf56f0ce` | Owns the current 72-session physical and 23/24 cost results. |
| Qualified runtime/evidence publication | `89d2eb6d280183e495a94b559776dfd8f1cdc196`; tree `2c52766489573a7db8dcba162d17daac4dbe6acc` | Sole parent is executed `749fb8b5`. Publication does not create a new executed physics identity. |
| #371 | Head `d9284cc72a52dc46b5c73f182843d5d0c1602df1`; merge `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` | Merged; production material consumers remain unchanged. |
| Preserved older #347 execution | `2457f5ecb945c60cd5118526f48734e82576ba49` | Its 24/24 cost pass and execution success remain historical; publication failed and it has no qualified publication child. |
| Earlier qualified contact execution | `5944c13079356fedf96da78c78e83b3898379fee` → `3ac7701f013452c94a8c08b0746e1b13523e7234` | Separate retained physical/cost population. Its measurements are not pooled with `749fb8b5`. |
| Frozen archive | `254235ec4c3d58782bba44b478caca86bf57c856` (#283) | Historical; B=289 remains NO-GO, #282/Y1 remain separate. |

Direct workflow reads confirm [41746597077](https://github.com/techrote/cybersand/actions/runs/41746597077)
completed successfully at `749fb8b5`, attempt 1; publication
[41748585125](https://github.com/techrote/cybersand/actions/runs/41748585125)
passed at `89d2eb6d`; documentation
[41751723998](https://github.com/techrote/cybersand/actions/runs/41751723998)
passed at `5b9b5a98`. Those success states do not enforce the independently
calculated 2 ms gate, supply a ready-for-review implementation matrix, or establish
human acceptance. Draft skips remain skips.

### Runtime identities and verification scope

| Runtime for `749fb8b5` | SHA-256 | Bytes |
|---|---|---:|
| Linux native | `5877f1ac8b3e1bc3548d415bbd3890f2b804df4d03f4eef4c961170780b47b3a` | 4,343,064 |
| Windows native | `4c0612b07395089c38696099998f60699a1477d997b95a568d503195a606a6d9` | 4,924,416 |

The recorded host is Godot `4.7.stable.official.5b4e0cb0f`, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, Rapier addon 0.35.2/core 0.35.1.
Rapier runtime hashes are Linux
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`
and Windows
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
These identities must be preserved in a reproduced control.

Independent checks here confirm:

- All 88 native input hashes at the reviewed head match the published native
  manifests. All 1,089 named native/build inputs are unchanged from publication
  to reviewed head by canonical Git identity.
- The executed-source-to-publication non-document delta is the Windows runtime
  pointer and two provenance documents. The Linux runtime pointer was already
  identical. The publication-to-head non-document tree is unchanged.
- Against the original build manifest, the two republished provenance documents
  are expected metadata changes. A CRLF worktree copy of `launch_desktop.ps1`
  matches its canonical Git bytes; it is not source drift.
- The retained qualification JSON hashes to
  `c155f59eae1c85c6ef46118078d82a10912fef786a026c45b30fd35ccfd04315`;
  all 36 entries in the final retained evidence manifest match their byte counts
  and hashes. The independent contact reducer authenticates the four raw reports.
- Native/Rapier binaries were not newly materialized or executed by this review.
  Previous actual-host execution is attributed to its original source-bound
  receipts, not re-claimed as new execution.

The [takeover record](https://github.com/techrote/cybersand/blob/5b9b5a982e4638f4609309f996b92825d3dc36e4/docs/audits/2026-11-03-sol281-takeover.md)
and [runtime qualification](https://github.com/techrote/cybersand/blob/89d2eb6d280183e495a94b559776dfd8f1cdc196/docs/audits/sol281-20261103/hosted/749fb8b597ad866f7535f26442e904207c4f7611/qualification.json)
remain the complete historical execution authority. This review's additional
checks are retained in [the evidence packet](sol347-independent-20261104/manifest.json).

### GCR identity map

| PR | Published head | Physical/feature acquisition | Compiled native source |
|---|---|---|---|
| #368 | `43028e4999c3038d5d83d77140461329f16364d3` | `9a0434915821256d34347d9115961ba4f26d4136` | `181a8257a93f82d64fbeb97e9c413ef52d44f13d` |
| #372 | `23bd83abf64e741764e02a8fa0eb4ca15a50aa24` | `5235cec255f0c2ffde0c2b25f04c8ae656f6b381` | `e2fa9960bdd750562bfca93b141579bfdf8ccdf9` |
| #373 | `22fb5026edda2ea95e620ad4c15b491f4fc115a8` | `b03cd79309c142bef75a7fa0134b5eaf9112881f` | `856c49371b37b3921bf859a67a883336252134ee` |
| #375 | `7c2c5fe3c92137eb6ab55768d3bec6ae4b33db63` | `92fa021ba0cd80a6da2a15b8604a68afdb61c64a` | Unchanged `856c49371b37b3921bf859a67a883336252134ee` |

All four remain draft/unmerged. Their 88 native input hashes and LFS pointer
hashes/sizes were checked against both platform manifests at each head.
[The verification record](sol347-independent-20261104/gcr-input-verification.json)
contains full runtime identities. The GCR physical populations use one
synchronous native worker and 1,800 manual 60 Hz steps. Separate four-worker
mechanical tests do not qualify asynchronous physical behavior.

## 2. Accepted and unaccepted contracts

“Accepted” below means supported for the bounded experimental fixture by source
inspection and retained scoped tests. It does not mean production merge approval.

| Contract | Supported behavior | Remaining boundary |
|---|---|---|
| Support loss | A deliberate native trunk cut triggers local four-connected discovery and genuine release of native terrain. | Not a world-wide automatic structural solver. A refused discovery does not undo the user's intentional cut. |
| Admission/bounds | One homogeneous ambient Wall/RedBrick component in a fully resident/included 64×64 domain; at most 1,024 members; explicit anchors. Unknown boundary, masks, hot/reactive material, pending events and capacities refuse. | Heterogeneous/reactive Wood, general structures, multiple aggregates and world-scale scheduling are not qualified. |
| Material ownership | Prepare/ack copies are evidence; native cells still own matter. Commit revalidates exact tuples, revision/tick/token/masks before native retirement. The aggregate then owns every original material/state/temperature tuple. | Preserved payload is not proof of aggregate thermal evolution, supported persistence or arbitrary lifecycle duration. |
| Collision handoff | Main creates an inactive real body, acknowledges it, commits native retirement, refreshes static terrain, finalizes matching epoch/revision, primes masks, then permits motion. Both clocks are held during the switch. | Native acknowledgements trust the main owner; they do not themselves prove an RID exists. Actual-host checks supply separate evidence. |
| Geometry | Six exact nonoverlapping rectangles preserve all 520 cells and both void controls; mass, COM and inertia derive from membership. | No filled bounding box, per-cell body or alternative fixture may silently replace it. Calibrated no-slip rolling is unproven. |
| Local displacement | Native vacancy transactions preserve parcels through two-to-five-position paths, at most four cardinal moves; fixed depth-four search and per-sample capacity/refusal. | No free vacancy means material stays native. Exact conservation is not a bulk granular resistance or momentum-conservation proof. |
| Samples/ownership | Copied recursively frozen observations; exact revision/epoch/token/generation/snapshot/sample fences; forward identity; at most one-sample age; 0.25-cell corner-drift fence. Main alone mutates Rapier. | Safe stale/refused input provides no useful contact response. A high accepted count can include empty impulse plans. |
| Refused/partial response | Complete preflight before new Sand impulses. Invalid actual readback after application retains consumed identity and possible partial mutation, then latches before another step. Native partial exceptions quarantine. | A post-application failure is never a mutation-free refusal or retryable transaction. The new false-refusal finding is a liveness/response-availability defect, not evidence of material corruption. |
| Rollback/reset | Cancellation retains old authority before commit. Before active motion, destination-checked rollback can restore exact cells. Reset joins the worker and retires the matching body; stale continuations cannot affect a newer session. | Active rollback refuses. Whole-session teardown is not general world recovery. |
| Settle/sleep/save | Sleeping continues to mean aggregate ownership and a Rapier body. Unsupported pending/active aggregate saves and full physical-state hashes refuse. | No automatic safe return to native cells, active restoration, fracture or long-lived save/load has qualified. #365 remains blocked. |

Source authority: [native lifecycle](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/native/src/world_solid_detachment.inc),
[session handoff](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/scripts/solid_detachment_session.gd),
[conservative displacement](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/native/src/world_conservative_displacement.inc),
and [bounded runtime contract](https://github.com/techrote/cybersand/blob/5b9b5a982e4638f4609309f996b92825d3dc36e4/docs/systems/solid-detachment.md).
The retained source-qualified matrix reports 19,338 ownership, 281 displacement
and 6,817 geometry checks per native toolchain, plus actual Linux/Windows host
fences. These scoped passes must not be expanded into the unaccepted column.

## 3. CPU failure classification

The independent reducer reproduces **23/24 passing groups and 12/12 passing
candidate groups**. Each platform/worker/environment/arm group contains three
repeats, and its registered decision uses the largest individual mean.

The failed Windows/four-worker/embedded-Sand **baseline r0** remains:

`(480.685 ms all-attempt owner work + 0.000 ms Sand-response work) / 224 complete consumed observations = 2.145915178571 ms`.

This is **7.295759% over 2 ms**. There were 369 owner attempts and no optional
Sand-response attempts. Neither accepted nor refused candidate impulses cause
this baseline numerator. The baseline still has ordinary coupling, displacement,
observation and Rapier work.

| Same baseline group | r0 | r1 | r2 |
|---|---:|---:|---:|
| Original ms/complete observation | **2.145915 FAIL** | 0.791546 | 0.672707 |
| Owner ms/attempt | 1.302669 | 0.725227 | 0.652653 |
| Owner attempts / complete observations | 369 / 224 | 370 / 339 | 369 / 358 |
| Support probes/attempt | 3,663.976 | 1,215.778 | 1,006.732 |
| Mean contact records/complete observation | 125.339 | 73.997 | 64.930 |

The failed mean factors exactly into **1.302669 ms/attempt × 1.647321
attempts/complete observation**. This is diagnostic algebra, not a replacement
denominator. Its 645,867 geometry probes and 1,352,007 support probes show a
heavier realized workload. Last sampled Sand area is 469.162326 cell², versus
176.684177 and 131.087910 in the other repeats. These physical trajectories
are unmatched; the workload difference does not identify why one buried further.

Within native ticks 2–360, r0 retains 224 observations. Consecutive publication
gaps are one on 88 occasions and two on 135 occasions: **135 unretained
publication slots inside that span**. The full 145 attempt-minus-consumed
difference also contains setup/leading work, so it must not all be labelled
overwritten publications. Latest-value consumption is a measured cost amplifier,
not by itself a broken queue.

### What is and is not identified

**Confirmed classification:** baseline owner-observation workload and consumption
cost overrun. Heavier realized Sand-support/contact work and lower consumption
efficiency are measured contributors. The internal division among geometric
work, value construction, copying/freezing and scheduler preemption is unresolved.
No evidence establishes a four-worker contention defect.

| Cost channel | Existing measurement | Limitation |
|---|---|---|
| Native observation | `steady_clock` around identity/geometry/support plus Godot Dictionary/Array construction | Not pure SAT/clipping time, and not thread CPU time. Only consumed successful observations have retained per-observation detail. |
| Owner callback | Every native observation attempt plus metadata attachment and recursive freezing | Ends before the publication mutex assignment. No all-attempt native subtotal or separate freeze subtotal. |
| Main response | All optional Sand-response attempts, including preflight refusal, application and readback | Zero for failed baseline. Accepted-only time must not replace all-attempt time. |
| Publication/synchronization | Broad main consume/publish segments and end-to-end age | Main synchronization nests response work; adding it to the original numerator double-counts. Lock wait is not isolated. |
| Rapier | Complete bridge step, callbacks and state refresh | Not collision-only time; separately reported from the 2 ms contact criterion. |
| Workers | Configured 1 or 4 | Contact observation is a serial exclusive-owner callback. Actual pool participation is not retained. |

In r0, consumed native-observation time is 209.3049 ms/224. Subtracting that from
480.685 ms does **not** measure freezing: the 271.3801 ms remainder includes
unconsumed native work. Separate recorded r0 costs are Rapier 68.308 ms/360
steps (0.189744 ms/step), main synchronization 40.230 ms/720 segments
(0.055875 ms/segment), observed native simulation 67.9881 ms/224 and observed
normal worker steps 140.765 ms/224. They have different populations and nesting.

The contact `published_usec` stamp is set after native observation but before
freeze/publication; accepted-response latency ends after planning/application/
readback. It is end-to-end age, not isolated publication waiting. Baseline zero
response-latency total does not imply zero publication latency. Elapsed timers
can include preemption; no retained thread-CPU trace apportions it.

[Independent complete reduction](sol347-independent-20261104/cpu-reanalysis-full.json) ·
[Reproducer](sol347-independent-20261104/cpu-reanalyze.py.txt) ·
[Original failed cohort](https://github.com/techrote/cybersand/blob/89d2eb6d280183e495a94b559776dfd8f1cdc196/docs/audits/sol281-20261103/hosted/749fb8b597ad866f7535f26442e904207c4f7611/cohorts/windows/contact-w4/contact-recovery-w4.json) ·
[Owner timer](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/scripts/solid_detachment_worker.gd#L19-L41).

The failure stays retained and the threshold stays 2 ms. A new result may qualify
a successor; it may not erase this repeat or substitute the older 24/24 source.

## 4. Penetration, refusal and numerical diagnosis

### What the physical evidence actually shows

At `749fb8b5`, the candidate maxima reproduce as **4.046731639982 cells**
in packed Sand (Linux/four workers/r2), **2.642792455422 cells** in embedded Sand
(Linux/four workers/r0), and positive sampled-overlap spans of
**5.933745–5.984297 seconds**. Depth is the SAT separating translation for a
native square versus a proxy, not COM descent or a continuous swept-depth bound.

A stronger retained observation is that **all 36 candidate runs still have
positive Sand overlap at their last sample**, at Rapier step 359 or 360.
Final sampled depth is **2.067731–3.828405 cells**, with area
**8.561350–64.720689 cell²**. Of 12,087 complete candidate observations,
12,077 are positive. This is repeated endpoint evidence against a clearance claim,
not proof of continuous overlap at all unobserved steps.

The `embedded_sand` name does not mean Sand was initially written into RedBrick:
the authoring loop skips nonempty native cells. Every candidate's first retained
depth is 0–0.015991 cells. Multi-cell overlap develops during motion. A replay
starting from a deeply buried frame must explicitly label that new replay
initial state rather than attributing it to original authoring.

Material entering available vacancies is legitimate rearrangement. Clearance
caused by conserved material evacuation must be separated from body retreat,
normal impulse resistance, positional correction or deletion. The existing
short vacancy route can exhaust its capacity or find no admissible terminal;
it then preserves material. That success in conservation does not stop burial.

### Response census and causal priorities

| Candidate population | Complete observations | Attempts | Accepted plans | ClearedContact | NonDissipativeResponse | PoseDrift | InvalidGeometryWitness |
|---|---:|---:|---:|---:|---:|---:|---:|
| Embedded | 3,936 | 3,673 | 3,509 | 75 | 89 | 0 | 0 |
| Packed | 4,039 | 3,867 | 3,538 | 207 | 111 | 9 | 2 |
| Mixed | 4,112 | 3,914 | 3,674 | 99 | 132 | 8 | 1 |
| **All 36 runs** | **12,087** | **11,454** | **10,721** | **381** | **332** | **17** | **3** |

No live post-application readback failure or response-energy violation is recorded.
The 633 complete observations without a new optional response exactly match
repeated source-sample counts in every case; they are consistent with the ordinary
duplicate fence, not 633 lost unique contacts. Preserve that fence.

An accepted plan can contain no impulses. Positive impulse sums in every
candidate run prove some exercised response, but the archive cannot split all
10,721 accepts into no-ops and physical applications. `ClearedContact` is a
preflight observation/current-pose result, not an energy violation or blanket
proof of evacuation.

Witness rejection and pose drift occur in packed/mixed cases, **not embedded
responses**. They are useful negative controls but not the demonstrated dominant
embedded cause. `NonDissipativeResponse` happens before RID mutation; it must not
be confused with actual Rapier creating energy.

The source supports several distinct hypotheses:

| Hypothesis | Evidence and needed discriminator |
|---|---|
| Missing force witness despite overlap | An interior Sand square can overlap without crossing an exterior face. Record overlap, supported status, exterior segments and no-segment reason separately. |
| Physically ineffective response | The planner only removes approaching normal velocity. At zero approach it adds nothing and cannot undo existing depth. Four sweeps can leave local residual approach. Test fresh synchronous contact with per-stage velocity and geometry. |
| Continued gravity/contact integration | Ordinary response precedes optional response; Rapier gravity/damping/hard contacts are stepped afterward. Zero publication delay alone need not prevent new entry. Separate all four stages. |
| Observation arrival | Native/main are asynchronously paced. Delay can alter contact availability without a PoseDrift code. Replay identical value inputs and apply fixed delays while retaining all age/pose fences. |
| Numerical plan refusal | A valid frozen-input planner defect is now reproduced below. Its frequency among the 332 live refusals remains unknown because full inputs were not logged. |
| Legitimate separation | Track the exact conservative displacement ledger and native occupancy; cleared material must remain accounted for outside the shape. |

The impulse law for approaching normal velocity `v_n` is
`j = -v_n / (1/M + (r×n)^2/I)`. In exact arithmetic it changes kinetic energy by
`-v_n² / [2(1/M + (r×n)^2/I)]`. It is a dissipative velocity constraint,
not a positional recovery or static support law.

The old 100% flat and 91.188319% off-centre controlled improvements are real
within their registered ≥25% added-overlap gate. That mechanism uses a short,
gravity-free, single-rectangle mass-520 control. It is not the entire live
six-proxy aggregate under gravity. No general live-depth/clearance numerical
limit was preregistered; do not invent a retroactive numerical failure or
interpret the absence of a limit as gameplay acceptance.

[Observer](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/native_extension/solid_contact_adapter.inc#L193-L270) ·
[Planner](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/scripts/solid_contact_response.gd) ·
[Stage ordering](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/scripts/solid_detachment_session.gd#L472-L607) ·
[Historical registration](https://github.com/techrote/cybersand/blob/5b9b5a982e4638f4609309f996b92825d3dc36e4/docs/audits/2026-11-03-sol281-dense-contact-registration.md).

### New confirmed defect: false non-dissipative refusal

The locally prospective protocol
[SOL347-REVIEW-NUMERIC-001](sol347-independent-20261104/planner-numeric/registration.md.txt)
was recorded before execution. It fixes 84 inputs, three identical calls per input,
approaching/separating/stationary controls and a 30-second stop. This was a local
session preregistration, not a claim of an earlier Git-hosted registration.

The unchanged planner SHA-256 is
`d5bebb75d81cf5bc0dce756f7a844f19ad9f145fbd9ca96775ad8f999a061d6d`.
The actual Linux Godot executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The diagnostic retains the exact six rectangles, 520-cell mass, COM and inertia,
and supplies one explicitly synthetic exterior supported-Sand witness.
No native support observation, Rapier body or live aggregate was executed.

**Result: 74 Accepted; 10 NonDissipativeResponse; zero control or replay failures.**
Independent scalar64 evaluation of the planner's actually rounded proposed state
finds eight false refusals relative to the unchanged tolerance: six energy
decreases and two small increases already within the allowed bound.
The other two proposals genuinely exceed the bound after rounding and must
remain refused. Ideal impulse algebra alone is insufficient to accept them.

The defect is in
[`_energy()`](https://github.com/techrote/cybersand/blob/749fb8b597ad866f7535f26442e904207c4f7611/godot/scripts/solid_contact_response.gd#L186-L187):
`Vector2.length_squared()` rounds the translational squared norm at vector
precision before scalar multiplication. Returning a scalar float afterward
cannot recover that precision. The guard then compares a small difference of
large energies at a 1e-8 relative tolerance.

One exact retained case:

| Input/result | Value |
|---|---|
| Six rectangles, x/y/w/h | (44,27,29,5); (44,32,16,1); (61,32,12,1); (44,33,29,7); (50,40,15,4); (50,44,4,21) |
| Mass / analytic inertia | 520 / (109907693÷1560) |
| Source=current pose | Original COM (7453/130,303/8), translated down 0.25; angle zero |
| Witness | Proxy 6, face 2, cell (52,65); point (52.5,65.25); outward normal (0,1); segment [(53,65.25),(52,65.25)]; area/depth 0.25; weight 1 |
| Input velocity / omega | (3,0.4830868542194366455) / 0.1 |
| Rounded proposed next vy / omega | 0.4830783307552337646 / 0.100000303664991… |
| Source-calculated energy change | **+0.00015579134969812003** |
| Unchanged permitted change | **0.0000275294514575117** |
| Scalar64 energy change of the same stored proposed state | **−0.0000016854082787176594** |
| Unmodified outcome | Refused; empty impulse list; no RID mutation |

A second reviewer reconstructed the 520-cell union and both void controls,
checked source/executable hashes and all ten refused cases, and decoded the exact
float64 bit strings. Both source energy values are reproduced bit-for-bit by
binary32 norm arithmetic; scalar64 component products reproduce both reference
energies bit-for-bit. This is not a decimal-JSON artifact.

[Full 84-case result](sol347-independent-20261104/planner-numeric/results.json) ·
[Exact case and binary values](sol347-independent-20261104/planner-numeric/exact_case_replay.json) ·
[Independent arithmetic](sol347-independent-20261104/planner-numeric/scalar_reanalysis.json) ·
[Independent review](sol347-independent-20261104/planner-numeric-independent-review.md.txt).

**Scope:** “stored proposed state” is the planner's numerical state, not actual
post-impulse Rapier readback. This proves a bounded false-refusal defect. It does
not show that any specific live refusal shares that cause, that a repaired plan
will clear the bank, or that all eight final four-sweep outcomes must become
accepted. Later legitimately failing steps must still refuse.

## 5. GCR evidence and ownership

GCR supplies useful experimental counterevidence, **no admissible #347 response
replacement**. Each result retains its own source, fixture, body mass and timing.

| Experiment | Defensible finding | What it does not authorize |
|---|---|---|
| #368 timing / identity setter | Earlier actuation sampling misses the registered late-motion benefit; identity setter is a sham within its tolerance. | Does not rule out #347 asynchronous publication defects. |
| #368 withdrawal cancellation | Gentle entry rises about 0.028→7.520 cells; high entry 6.690→32.553, with much larger overlap. | Do not remove correction as a blanket fix. It retained other original effects and is not a recomputed no-correction law. |
| #368 event-off E0 | Unactuated Sand/Salt descent at tick 900 falls 154.26651→1.072906 cells while both arms are hard-clear. | The intervention jointly removes event J/L, budget charge and provisional velocity before passive recomputation. It does not identify one subcomponent or establish quiet rest. |
| #372 granular event-off | Retains bank benefit; exercised gravity-zero falling-grain control has 14.797510 cells travel / 0.425977 rad angular travel, versus event-off 0/0. | Cannot promote a general contact law that loses the tested grain loading/torque response. |
| #373 selective arrivals | Uses actual preceding-tick native transport witnesses and recovers some loading. | Joint creep/loading/barrel criteria fail; continuous supply cannot replace finite-batch acceptance. |
| #375 burst/stream tools | Repeatable setup, controls, insertion/refusal accounting and same-response replay. | No new efficacy score, human acceptance or reversal of #373's NO-GO. |

For #373, independent compact-record arithmetic reproduces the failures:
Sand/Salt descent 2.073517 exceeds its E-proximity ceiling 1.572906;
Dust improvement 73.690226% misses 75%; finite-batch travel recovery 8.753337%
and angular recovery 21.516304% both miss 25%. The edge operational rebound
9.617020 exceeds 9.297835 cells/s. Its granular prefix passes; that later rebound
is after hard interaction and is not exclusively a granular causal effect.

Continuous-stream headline totals include later hard interaction. The actual
granular-prefix reducer stops at common hard proximity tick 275: translation
recovery is **27.208859%**, angular-travel recovery **176.962445%**, both within
that fixture's registered lower/upper gates. The full-capture 41.69%/97.68%
figures must not be presented as exclusively granular effects. Finite-batch
control events end after tick 39; later travel does not prove continuing static
blocked forcing. Control magnitudes are not calibrated physical momentum targets.

Event-off bank tails still overlap six cells and continue correction. Powered
bank improvement is actuated behavior, separate from unactuated rest.
The summary `ok:true` means capture/reduction validity. Both OS technical records
retain `creep_preserved:false`, `falling_loading_recovered:false` and
`barrel_guards:false`; the summary-level fields remain
`production_acceptance:false` and `owner_acceptance:null`.

Sources: [#368 audit](https://github.com/techrote/cybersand/blob/43028e4999c3038d5d83d77140461329f16364d3/docs/audits/2026-11-03-gcr-causal-tests.md),
[#372 qualification](https://github.com/techrote/cybersand/blob/23bd83abf64e741764e02a8fa0eb4ca15a50aa24/docs/audits/2026-11-04-gcr-granular-event-successor.md),
[#373 registration](https://github.com/techrote/cybersand/blob/22fb5026edda2ea95e620ad4c15b491f4fc115a8/docs/operations/gcr-selective-events-registration.md),
[#373 compact results](https://github.com/techrote/cybersand/blob/22fb5026edda2ea95e620ad4c15b491f4fc115a8/docs/audits/gcr-selective-2026-11-04/qualification-summary.json),
[#375 tools](https://github.com/techrote/cybersand/blob/7c2c5fe3c92137eb6ab55768d3bec6ae4b33db63/docs/audits/2026-11-04-repeatable-powder-review.md).

### Source and physics boundary

#347's aggregate normal response is owned by #281/#347/#364 and its
`solid_contact_adapter.inc` / `solid_contact_response.gd`. It has no
`evaluate_gcr` implementation. GCR's independent-body evaluator combines
event J/L, shared budget, provisional velocities and passive normal/friction/
torque response. Its source explicitly
[refuses event-off or arrival-witness compound preparation](https://github.com/techrote/cybersand/blob/7c2c5fe3c92137eb6ab55768d3bec6ae4b33db63/godot/native_extension/gcr_compound_adapter.inc#L11-L15).
Old compound-control tests therefore do not qualify these responses on #347's
mass-520 compound. Generic body coupling remains #83/REM-004's owner.

Do not import stacked source, change gains, introduce unregistered support or
gravity terms, remove correction, change defaults, or infer equivalent physical
ownership from similar terminology. Any later shared World/adapter/bridge change
needs the responsible integration owner and combined-source qualification.

Full GCR raw captures and failure/final-head logs are hash-bound local archives,
not committed originals accessible here. This review checked source, registration,
compact records and source-lock records; it did not independently rehash those
inaccessible originals. Prior raw-validation claims remain the dated authors'
evidence. The stale “results pending” sentence in the GCR overview does not
override the dated NO-GO audit and machine gates.

## 6. Material-catalogue source guard

The #371 compatibility checker passes on current main with **27 protected
sources** authenticated against `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`.
It independently reconstructs the expected lock from retained Git bytes before
checking current LF-normalized source. Updating a changed file and its hash
cannot silently create a new accepted baseline.

A read-only invocation of the **unchanged main checker**, with #347 as candidate
root and main's lock/baseline repository, fails at `native/src/world.cpp`.
Independent enumeration identifies exactly **two mismatches, 25 matches**:

| Protected file | Frozen LF SHA-256 | #347 LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` | `91cecf308d01ef214f491f3dc1f353f10c9db17a55162b983fc4ecf80e6363e6` |
| `native/src/world_pressure.inc` | `c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b` | `0e6c8b916d9a457fc09d63f496b9acb5b8b61f55c3c09311d8bcf90bbf92b947` |

The first adds native contact-cell availability, lifecycle mutation fences,
reset handling and detachment/displacement inclusion. The second refuses
unsupported aggregate save/hash operations. These are substantive lifecycle
and ownership changes, even though production descriptor/capability headers
remain byte-identical. **Source-lock drift is not automatically a changed
catalogue digest or a need to rewrite existing wire vectors.** The affected
identity contracts must be assessed explicitly.

GCR #373/#375 instead mismatch three protected files: these two plus
`native/src/world_inertial.inc`. That is a separate branch-specific transition,
not permission to carry its deltas into #347.

Legitimate ownership is the existing #347/#364 native/aggregate integration
owner working with the MAT-AUTH compatibility owner, and the save/hash authority
where relevant. A later reviewed transition must:

- Preserve the original `0fd4af59` checkpoint and its evidence.
- Enumerate each exact source change, affected consumers and behavior;
  retain stale-input refusal and unsupported aggregate-save refusal.
- Prove unchanged material IDs/descriptor/capability/policy identities where
  claimed, and explicitly version any identity that really changes.
- Define a narrow successor source-compatibility checkpoint and rollback,
  with independent native/adapter/platform qualification.
- Keep the checker fail-closed for unrelated World/material edits.

This is **not authorization to implement that transition now**, migrate a
production catalogue consumer, refresh hashes, add an exception or disable the
guard. A local arithmetic repair outside the 27-file set does not resolve
#347's pre-existing two-file integration conflict.

[Guard source](https://github.com/techrote/cybersand/blob/7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1/tools/material_catalogue/compatibility.py#L210-L278) ·
[Adopted guard contract](https://github.com/techrote/cybersand/blob/7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1/docs/operations/material-catalogue-shadow.md) ·
[Exact comparison](sol347-independent-20261104/source-lock-comparison.json).

## 7. Minimum repair and decisive experiment

Use the existing #364 owner and branch/worktree policy. Do not start a competing
implementation lane. The following is a prospective specification for later
authorized work; only the unchanged-planner diagnostic above was executed here.

### First: correct the demonstrated numerical evaluation

The minimum defensible repair is aggregate-planner kinetic energy evaluated
from scalar64 products of the **same stored velocity components and omega**.
Preserve the impulse law, four sweeps, geometry, all capacities, 1e-8 planning
bound, 1e-4 actual-readback bound and terminal failure latch.

Retain all 84 original inputs, the exact binary-value reproducer, zero/away
controls and the two genuinely over-bound rounded proposals. Verify correct
first-step decisions and the complete four-sweep outcome; do not require a
whole plan to accept if a later correctly measured step fails. Never replace
measured-state checking with ideal algebra alone.

The actual-readback energy helper also uses a vector squared norm. Review its
measurement consistency under its separate wider tolerance; do not infer an
observed backend defect or casually broaden the repair into shared coupling.
Any shared bridge behavioral change needs its owner and corresponding controls.
This review neither edits nor qualifies such a repair.

### Frozen source and runtime

The unchanged scientific control is exactly `749fb8b5` with the `89d2eb6d`
native/Rapier identities in section 1. `5b9b5a98` may supply the preserved
documentation because its execution inputs match that publication.

Before any new execution, record a full immutable successor commit and exact
test-driver hash; do not invent its future SHA or relabel old measurements.
If only GDScript/test code changes, retain and authenticate all 88 unchanged
native inputs and declare the changed script/driver inventory separately under
the repository's source-provenance rules. If a validator cannot truthfully admit
that inventory, stop and obtain the proper qualification/publication route;
do not weaken it. Any native change requires matching newly built native
artifacts. Native ownership/fences cannot be bypassed to make observation easier.

### Fixed geometry and initial state

Use the authored `embedded_sand` session unchanged:

- Domain (32,16,64,64), anchors (0,67,128,13), deliberate cut (50,65,4,2),
  component seed (51,34); exact six rectangles listed in section 4.
- RedBrick 520 cells, six proxies, void probes (60,32) and (68,50);
  original tuple list/digest preserved. Mass 520, analytic COM (7453/130,303/8),
  analytic inertia 109907693/1560. Record actual backend mass/inertia as well.
- Initial angle and linear/angular velocity zero after release; record actual
  readback before the first integration. Preserve gravity scale 0.094 and
  linear/angular damping 0.04. No manual transform changes after activation.
- Exactly 2,016 ambient Sand cells, zero Water, original walls/floor/intact
  control structure. Verify the initial native tuple and quantity digest.
  A buried-state replay must use a separately captured/labeled state.
- Keep conservative displacement enabled in every arm. Response-off baseline
  means optional Sand resistance off, not removal of ordinary coupling.

The source's diagnostic reset/default random state and actual worker settings
must be captured in the fixture manifest; do not silently substitute a guessed
seed, different gravity context, smaller body or altered grain population.

### Small staged population and stop boundary

Start on the same OS class as the retained cost failure: actual Windows,
configured workers **4 and 1**. Stage one is only the original embedded geometry:
response-off baseline, unchanged candidate and bounded numerical-repair candidate;
two repeats each, 360 physics steps at 1/60 s. That is **12 sessions**, with one
synchronous native/publication/consumption rendezvous per declared physics step.

The unchanged candidate is essential: it separates a numerical effect from a
different sampling schedule. Frozen-value replay is deterministic; closed-loop
baseline/candidate trajectories may diverge and must not be joined as identical
states after intervention.

Only after the capture is complete and the first-stage diagnosis is interpretable,
run the repaired candidate at workers 4 in three distinct arms: ordinary
asynchronous publication with passive telemetry; controlled one-sample delayed
synchronous replay; and controlled synchronous replay withholding delivery at
steps 120–122. Two repeats each means at most **six further sessions**. Compare
the two controlled-delay arms with the stage-one zero-age synchronous control;
do not present ordinary asynchronous and synchronous trajectories as matched.

Delay the complete immutable coupling envelope: matching ordinary results,
contact observation and all enclosing identities together. Delaying only the
contact dictionary would manufacture mismatched provenance. In the one-sample
arm deliver the prior step's envelope once; do not replay it. In the withholding
arm continue producing observations, retain only the newest held envelope,
count each overwritten envelope, deliver that newest unchanged envelope once
at step 123, and resume ordinary one-per-step delivery. Freeze this policy before
running. Record programmed delay and actual logical age separately. Explicit
two-sample-old negative controls must refuse without new RID mutation; never
relabel held observations as fresh or disable age/pose fences.

Stop after these bounded stages and classify. This is not a new full matrix.
A useful repair then needs separate exact-source Linux replication and the
existing packed/embedded/mixed workers 1/4 qualification before integration.
Retain every failed/incomplete run; never rerun until a favourable sample appears.

### Capture that distinguishes the causes

In the synchronous/replay stages, record geometry at all four phases of every
declared physics step: before ordinary response, after ordinary correction/
impulses, after optional Sand response, and after Rapier gravity/damping/hard-
contact integration. Pause the relevant owner at an explicit rendezvous for
geometry calls; main must never read live worker cells. The ordinary asynchronous
arm uses only passive immutable publications and timestamps: intrusive four-phase
rendezvous would change it into a synchronous arm. Its unobserved geometry
intervals remain unobserved and cannot contribute continuous cell-tick claims.

Capture full native material/state/temperature inputs, aggregate tuple ownership,
mask identities, source/current body pose, v/omega, mass/inertia, full contact
segments and support results; tick/revision/epoch/token/generation/sample/snapshot;
every conservative transfer/refusal and ordinary coupling outcome; every planned
and applied J/torque; accepted empty plans, accepted mutating plans, preflight
refusals and post-application failures separately. Include every energy operand
at full precision and actual backend pre/post velocity. Serialize numerical
components explicitly, not display-rounded Vector2 strings.

The original trace omits these fields. It cannot be turned into a complete replay
by interpolation or by inventing cells/velocities. Reconstruct a new capture from
the canonical setup and command sequence. Frozen-value planner replay and complete
coupled state replay are separate products; unsupported aggregate CYPS save is
not a valid shortcut.

Record observation start/end, freeze start/end, publication lock attempt/acquire/
release, consumption, planning, apply and readback timestamps. Capture refused
and overwritten work and actual native-pool participation. Separate thread CPU
where available from the historical elapsed-time criterion. Maintain two explicit
ledgers: primary publication-channel observation/response work and auxiliary
phase-observer/state-serialization work. Auxiliary observations create no extra
denominator credit. Retain legacy counters unchanged; if an instrumented stage
cannot be separated from them, report that contamination rather than subtracting
an estimate. Report auxiliary and all-in elapsed costs, waits and timeouts too.
Stage instrumentation
must be test-only where existing seams permit it; necessary native/shared-source
edits require the actual owner and a new source/runtime identity.

| Result under fixed inputs/schedule | Interpretation |
|---|---|
| Corrected arithmetic changes a frozen refusal but not body clearance | Numerical defect repaired; remaining physics/evidence gap persists. |
| Fresh synchronous contact remains ineffective with valid witness and applied dissipative J | Contact-law/order/convergence limit; latency alone is insufficient. |
| Fresh source has overlap but no eligible segment | Geometric/support admission limit; not a missing publication. |
| Ordinary delivery fails while synchronous succeeds, and fixed delay reproduces failure | Evidence for arrival sensitivity, with the precise failing stage identified; not blanket permission to relax freshness. |
| Depth/area clears through recorded exact material relocation | Legitimate evacuation, distinguished from a body-support law. |
| Invalid/stale identity mutates, readback exceeds bound without latching, or ownership changes incorrectly | Immediate correctness failure; stop before physical interpretation. |

### Prospective thresholds and deadlines

The following new numbers are **proposed engineering screens for the next
registration**, not retroactive criteria for the old asynchronous captures and
not owner gameplay acceptance. Freeze or explicitly revise them **before** new
results; no tuning after seeing outcomes.

| Gate | Prospective criterion |
|---|---|
| Existing correctness | Exact 520 tuples, Sand count, shape/void identity and sole owner at every phase; zero stale/duplicate application or unreported partial mutation. Any mismatch stops. |
| Existing energy | Per planned impulse and complete plan ≤1e-8×max(1,E_before); actual isolated response readback ≤1e-4×max(1,E_before), all finite. Preserve the existing precise implementation's absolute floors. Any actual breach latches/stops. Gravity/damping/hard-contact energy is logged separately. |
| Existing controlled mechanism | Retain ≥25% added-overlap reduction, no larger initial penetration, and original unilateral/rotational controls. Numeric repair must not replace the registered fixture. |
| Fresh delivery | Synchronous arm consumes exactly one complete current observation for each declared step, logical age 0 and unchanged ≤0.25-cell vertex-drift fence. Missing rows make per-step clearance evidence incomplete. |
| Numerical classification | Original false-first-step refusals use accurate stored-state energy; genuinely over-bound controls still refuse. Frozen inputs produce identical ordered outputs on same-host repeat. No tolerance relaxation. |
| New entry/recovery screen | For candidate efficacy in the initially clear synchronous/ordinary authored fixture, maximum Sand depth ≤0.5 cell; no detected Sand overlap by step 300 and throughout steps 301–360. Response-off and deliberately delayed/withheld controls may fail this physical screen without invalidating their capture; all correctness/energy stops still apply to them. Half a cell bounds entry below full-cell burial; the final 60 steps provide a one-second sustained-clearance screen. Failure identifies remaining physical work, not permission to add a force. |
| Hard-boundary safety | Zero positive hard-cell penetration above the existing 1e-9 area filter; no crossing/teleport through floor/walls, source/control structure conserved. Exact-touch and filtered sub-tolerance intersections remain explicitly distinct. |
| Cost | Preserve all attempts in the primary publication owner/response numerator and only complete consumed primary observations in its denominator; retain the ≤2 ms limit. Auxiliary phase observations/serialization receive no denominator credit: publish their measured subtotal and all-in cost separately. If legacy counters are contaminated by inseparable instrumentation, the original gate is unqualified for that arm, not corrected by estimated subtraction. This small set cannot overwrite the retained 23/24 matrix. |
| Delay negative | Over-age/invalid-pose/wrong-identity inputs perform zero new RID mutation; accepted delay ≤1 retains original validation. Compare depth/persistence/energy without selecting only successful responses. |
| Deadlines | Pure frozen-planner diagnostic retains 30 s. New 360-step session: 60 s wall deadline plus existing cleanup policy, with no automatic extension. No progress/owner reply beyond the repository's existing operation watchdog stops sooner. Timeout is incomplete, not a physical pass or proof of CPU failure. |

A new whole-session energy balance must account for gravity, damping, ordinary
coupling, hard collisions and material displacement; the optional response's
nonincrease guarantee is not a claim of global continuum conservation.
No positional-recovery work is admitted by this specification. If the remaining
problem needs a new force or position law, return a physics/ownership decision
with a separate preregistration.

For repeatability require exact tuples, ordering and decision classifications
for frozen-value replay. For same-host synchronous closed-loop repeats, register
absolute tolerance 1e-5 for each position, angle, linear-velocity and angular-
velocity component in its declared cell/radian/second units, plus exact native
tuples and decision order. This is a repeatability screen, not a momentum or
physical-accuracy claim. Ordinary asynchronous runs retain descriptive ranges.
Disclose differences rather than claiming bitwise cross-platform Rapier identity.
Retain stale/replay/token/generation/reset/quarantine, no-vacancy, foreign-mask,
capacity, hot/reactive/residency, holes, unsupported material and invalid-readback
negative controls. They can use the existing focused apparatus; no broad CI
dispatch is authorized by this review.

### Reproducing this review's completed diagnostic

The retained scripts are documentation text, not production imports or CI entries.
Copy the numeric packet to a temporary empty Godot project and remove only the
`.txt` suffix from the saved script/project names. Obtain the original planner
verbatim from `5b9b5a98:godot/scripts/solid_contact_response.gd` as
`response_original.gd` and verify its hash above. Then run the pinned executable:

```text
timeout 30 <pinned-godot> --headless --path <temporary-project> --script res://probe.gd
timeout 30 <pinned-godot> --headless --path <temporary-project> --script res://replay_one.gd
python <temporary-project>/scalar_reanalysis.py
```

Do this in a fresh output directory so retained evidence is not overwritten.
The [original numeric manifest](sol347-independent-20261104/planner-numeric/manifest.original.json)
retains original filenames/hashes; the outer packet manifest maps the
documentation filenames without changing bytes. The original planner itself is
already recoverable from its immutable source commit and is not duplicated here.

For CPU reduction, use a frozen checkout containing the `89d2eb6d` evidence:

```text
python docs/audits/sol347-independent-20261104/cpu-reanalyze.py.txt <frozen-347-checkout> <new-output.json>
```

## 8. Integration disposition and stopping point

| Axis | Review disposition |
|---|---|
| Bounded automatic mechanism/correctness | Support cut, exclusive handoff, exact payload, six-shape motion, negative fences and scoped actual-host execution are supported. The new numerical false refusal requires a bounded repair. |
| CPU | **Failed full-matrix criterion retained**, specifically one baseline group. Candidate-only cost success is accurately reported but insufficient for full-matrix acceptance. |
| Physical gameplay quality | **Unqualified**: acquired multi-cell penetration and positive endpoint overlap persist; numerical refusal, law/order limits and observation arrival need causal separation. |
| GCR transfer | **Not admitted**: distinct source/owner/fixture; event-off loading gap and selective joint NO-GO retained. |
| Current-main compatibility | **Blocked** by two protected-source changes; needs a separately reviewed owner-coordinated transition. |
| Long-term lifecycle | **Unqualified**: sleep retains aggregate authority; active restoration/persistence and general fracture remain outside current proof. |
| Human/graphical acceptance | **Untested**, including representative GPU pacing and perceived contact/rolling. Automated assertions cannot supply it. |
| Merge / issue closure | **Not authorized or justified**. #347 draft/unmerged; #281/#12 open; #365 blocked. |

**Chosen action: REPAIR FIRST — the bounded planner energy-evaluation defect,
then continue #364's synchronized replay under the frozen controls above.**
The evidence-only CPU review would otherwise select CONTINUE #364; the additional
independently checked numerical reproduction supplies a concrete repair target.
It does not establish a universal burial fix or justify any GCR import.

Local documentation, repository/provenance and historical M11 checks pass.
The M11 pass covers 18 retained records and 28 historical hashes, not current
execution. Frozen retrieval remains 19/32 at rank one, 32/32 at rank five
(MRR 0.7536); this is lexical navigation evidence, not semantic acceptance.
The [documentation verification receipt](sol347-independent-20261104/documentation-validation.json)
retains the initial missing-companion-file failure and the exact pinned companion
inputs used to restore the normal check environment. Runtime payloads remain
unmaterialized; no current native/Rapier execution is claimed.

Publication of this review records progress. Stop here: no implementation repair,
new physics law, changed coefficient/default, lock refresh, restoration work,
experimental merge, broad CI campaign or issue closure was performed.
