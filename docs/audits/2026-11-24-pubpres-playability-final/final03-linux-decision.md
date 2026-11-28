---
title: PUBPRES final03 Linux independent qualification and decision
status: Historical
document-kind: audit
scope: Source-exact Linux03 raw-evidence replay, physical progression, observer calibration, ordinary mixed workloads and unresolved presentation limits
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [historical-evidence.md, development02-causal-intervals.md, final03-linux/physical-tables.md]
---

# Final03 Linux independent qualification and decision

**The retained Linux job passes its correctness and custody gates, and the large
Wave source comparison supports a real physical progression improvement in this
cohort. It does not establish completion of the playability programme.** The
Wave512 reference has no repeatable improvement, ordinary large-canvas progress
remains far below 60 completed fixed steps per second, the 30/60 Hz publication
deadline arms suppress no uploads in these captures, and the eight-actor scenes
expose withheld presentation that visible-pose percentiles alone would conceal.
All results remain Draft/HOLD.

## Contents

- **Evidence and identities:** immutable application, runtime, engine and artifact identities, with complete independent replay scope.
- **Physical progression:** all primary control arms, absolute tail burden and the sustained large-canvas capture.
- **Confirmation workloads:** small, medium, landscape and alternate material-law results without selection of favorable runs.
- **Observer calibration and cost:** explicit off/on controls, actual process CPU/RSS and the limits of submitted-pose measurements.
- **Material deadlines:** retained negative controls and proof that this host did not exercise upload coalescing.
- **Ordinary eight-actor workloads:** actual input, painting, collision and terrain witnesses, plus withheld-pose limitations.
- **Causal interpretation:** what the recovered older stage clocks already answer and the narrow diagnostic still justified.
- **Reproduction and disposition:** exact readers, original outcomes and remaining acceptance obligations.

## Evidence and identities

The source is the third development checkpoint,
`c2f8a73d34448bc1496ecd84bca02f0812c80d27`, tree
`351b947a50ce054361660eba9379006122527547`. The frozen D control remains
`c90dbc46e1f57f28e06b1f4205b83467335ff657`. This is a whole-source comparison;
the measured change is not attributed to a single native optimization.

[Run 45452580606](https://github.com/techrote/cybersand/actions/runs/45452580606)
produced Linux graphical artifact `14954600370`: 131,344,255 ZIP bytes, SHA-256
`afc128e3d90d952b3c801ba489d9ce66db51d10c7420094fb9f2096dbb20da71`.
All 5,463 archive members were CRC/SHA verified by the lead. The independent
readers stream or temporarily extract one arm at a time; they do not execute
Godot or repeat a timing capture.

| Actual Linux component | SHA-256 |
| --- | --- |
| C native runtime, built from c2 | `33d9c39ecfca71c800f538dbf3edbbb85675c0c65be35d6af525f699b7d15dc0` |
| D native runtime, independently built from c90 | `bc5cdbf4832d09f8b14f6ff2ed7cf1e182343d55a3a4ebc4dc1d93894d660d59` |
| Official Godot 4.7 Linux executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Actual loaded Linux Rapier library | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |

The complete replay preserves all 105 committed native input, build-log,
compiler, dependency and runtime predicates for both sources, their matched
toolchain, the entire recorded driver identity, actual process commands and
owned display cleanup. The host reports Intel Xeon 6975P-C and llvmpipe
LLVM 20.1.2 software OpenGL, with actual Safe render ownership. These results
do not establish physical Windows/NVIDIA or WGL behavior.

Two independent layers agree on all **47 timed captures**. The standard-library
physical reader reconstructs genuine Rapier completion credit, unique actual
callback ownership, accepted native body samples, consecutive native ticks,
installed terrain revision, actor/RID ownership and admitted commands. The
separate frozen-code replay preserves the original V3 physical, GPU-history,
material, Water, input and actor gates; it additionally replays the registered
mixed-scene derivation and all source-bound pose/geometry, Follow, CPU and
deadline evidence. It reproduces every registered cohort direction. See the
[physical reduction](final03-linux/final03-linux-independent-physical.json)
and [complete frozen replay](final03-linux/final03-linux-complete-frozen-replay.json).

All **16 successor correctness outcomes** also independently replay. This
includes queued three-slot publication, all 180 transition admissions, Main
fallback/ACK recovery, world replacement, delivery timing, and the two-slot and
three-slot deadline-history transactions. Source/import closure comprises 1,030
staged source files and 1,698 imported entries, with the original two portable
bootstrap exclusions and zero application source mutations. Synthetic scheduling
fixtures record zero Rapier steps and receive no performance credit. The
[correctness replay](final03-linux/final03-linux-independent-correctness.json)
retains each raw process/log hash and independently reconstructed byte proof.
The separate original-safe sustained functional fixture remains separately
identified rather than being counted as one of the 47 V3 timing captures.

## Physical progression

Every comparison below uses the registered first 144 completed Rapier steps,
starting at capture entry. Percentiles describe that run's 143 consecutive
completion gaps; no pooled percentile or mean-of-percentiles replaces them.
The unrounded [47-arm tables](final03-linux/physical-tables.md) and JSON retain
all controls, the first-step startup interval and whole-capture alternatives.

| Workload | Order / source | Real steps/s | p50 gap ms | p95 gap ms | p99 gap ms | Maximum gap ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Wave512 reference | 0-D | 12.1559 | 82.504 | 85.216 | 86.891 | 87.932 |
| Wave512 reference | 1-C | 12.1310 | 82.197 | 84.992 | 86.654 | 87.449 |
| Wave512 reference | 2-C | 12.1214 | 82.285 | 85.634 | 86.701 | 87.775 |
| Wave512 reference | 3-D | 12.2069 | 82.812 | 85.754 | 87.200 | 87.682 |
| Current Wave2048 | 0-D | 5.0944 | 249.128 | 255.871 | 259.104 | 262.643 |
| Current Wave2048 | 1-C | 6.5175 | 148.848 | 231.488 | 234.453 | 239.174 |
| Current Wave2048 | 2-C | 6.2280 | 151.461 | 236.563 | 239.904 | 240.182 |
| Current Wave2048 | 3-D | 4.9897 | 253.547 | 261.712 | 264.707 | 266.160 |

Wave512 uses the historical one-round, spill/ballistic-off reference. Its
registered result is **NOT_ESTABLISHED**. Both candidate rates are slightly
below both controls; the small and mixed tail differences do not satisfy the
registered relative rule. This does not resolve the previously observed Wave512
regression against accepted main.

The current-gameplay Wave2048 fixture uses two Wave rounds, spill and ballistic
transport, Follow and four actual workers. Its registered result is
**SUPPORTED_FOR_THIS_COHORT**: both candidate rates exceed both controls, p95
and p99 are lower, and maximum/severe-gap counts remain within the control
envelope. Across all four C/D rate pairings the increase is approximately
22.3–30.6%. Equal-step body trajectories, admitted moves, Water and terrain
gates remain intact. This is a real completed-step change, not texture submission
or render-FPS credit.

The absolute burden remains substantial. The candidate arms have 140 and 143
of 143 interstep gaps above 100 ms, versus 141 and 143 for D. Their >250 ms
counts are zero versus 63 and 86 for D; no arm has a >500 ms gap here. These
thresholds report exposure, not a newly invented owner acceptance limit. At the
observed fixed delta of 1/60 s, 6.23–6.52 completed steps/s advance only about
0.104–0.109 simulation seconds per wall second.

The separate sustained C Full2 capture completes **495 genuine steps in
60.027 s**, 8.2462 steps/s. Its gap p50/p95/p99/max are
106.782/230.313/235.544/241.561 ms, and all 494 observed interstep gaps exceed
100 ms. The workload evolves through the longer window: its higher whole-run
rate must not replace the matched first-144 comparison. There is no paired
60-second D run in this cohort, so this establishes sustained correctness and
tail burden rather than a sustained relative win.

## Confirmation workloads

The four confirmation cohorts retain D/C/C/D order and the same first-144
window. Full p50/p95/p99/max and counts for every arm are in the timing tables.

| Registered workload | D rates, steps/s | C rates, steps/s | Registered result |
| --- | --- | --- | --- |
| FreeMass2048 Follow | 9.8894 / 9.8790 | 9.9577 / 9.9765 | Supported in this cohort; effect is below 1% |
| Pressure512 Follow | 10.9523 / 10.8490 | 10.9906 / 10.8928 | Not established |
| Wave1024 Follow, four workers | 10.9981 / 10.8353 | 11.2230 / 11.1602 | Supported in this cohort |
| Wave landscape Follow | 10.2985 / 10.3014 | 10.8342 / 10.8755 | Supported in this cohort |

The `wave_1024_follow_4` suffix means **four workers, not four actors**. These
are whole-source, single-host comparisons. FreeMass's small positive direction
does not identify a Wave-specific mechanism or establish a practically meaningful
improvement. Pressure's negative conclusion and all slower controls remain in
the decision packet.

## Observer calibration and cost

The submitted-pose observer received a separate same-C-source/runtime/policy
OFF/ON/ON/OFF calibration. Every arm retains the original full V3 observer and
the same external CPU sampler. The enabled state is actually observed; an OFF
arm has unavailable pose freshness, not a zero age.

| Workload | OFF / ON / ON / OFF real steps/s | All ON/OFF rate ratios | Measured added callbacks |
| --- | --- | --- | --- |
| Wave512 | 12.1619 / 12.1189 / 12.5181 / 12.4546 | 0.9731–1.0293 | 14.896 / 11.364 ms total; p95 0.117 / 0.090 ms per call |
| Current Wave2048 | 6.7569 / 7.2091 / 7.2550 / 6.9485 | 1.0375–1.0737 | 17.948 / 18.513 ms total; p95 0.131 / 0.131 ms per call |

Equal-step physical outcomes agree, but this is not proof of zero overhead.
Host variation and scheduling perturbation can change cadence nonlinearly; a
faster ON run is not evidence that instrumentation improves the game. No owner
overhead budget was registered. All primary comparison arms keep the observer
identical, and no earlier observer's calibration is inherited.

The new pose proof binds selected step clocks to independently completed Rapier
events and reconstructs the actual submitted first collision-derived overlay
part, including node/RID identity and the supported local-transform composition.
Material age joins the latest preceding actual upload and source generation
clock. Unknown pre-capture poses and uploads remain unjoined. This proves the
sampled submitted first-part geometry; it does not observe every pixel, GPU
completion, scanout or device-to-photon latency.

Wave512 C visible-pose completion-age p95 is 5.296/5.496 ms, with maxima
7.569/6.750 ms. Current Wave2048 C p95 is 149.684/153.196 ms, maxima
156.721/157.864 ms; submitted material-age p95 is 230.518/236.854 ms, maxima
266.787/241.901 ms. Each large C arm also has one withheld submission lasting
about 146 ms and one held Follow target. Those observations remain explicit
rather than disappearing into the visible-pose age distribution.

[Process resources](final03-linux/process-resources.json) independently bind
every queried memory PID and kernel RSS high-water maximum to the real owned
process and replayed CPU sidecar. Whole-process sampled CPU includes scene setup
and is not aligned to capture clocks. For the large source arms, C consumes
203.14/207.54 CPU seconds over 64.191/65.685 sampled wall seconds, versus
D 225.61/229.12 over 69.966/71.215 seconds. Mean CPU equivalents are about
3.16 for C and 3.22 for D; these are not capture-only CPU per completed step.
Queried peak RSS is approximately 1,422/1,423 MiB for C and 1,418/1,425 MiB for D.
Wave512 consumes about 2.49–2.52 CPU equivalents and 1,195–1,203 MiB across all
four processes. External sampling read costs, missing RSS queries and the
unobserved process launch/exit tails are separately disclosed.

## Material deadlines

The prospectively registered order is 0/30/60/60/30/0 Hz on the same C source,
runtime, Full2 publication, Early physical handoff and coherent presentation.
The policy's real counters and actual upload serials are independently joined.

| Workload | Real steps/s in registered order | Actual uploads in registered order |
| --- | --- | --- |
| Wave512 | 12.5034 / 12.3660 / 12.2811 / 12.2517 / 12.2897 / 12.1699 | 142 / 142 / 143 / 143 / 140 / 141 |
| Current Wave2048 | 6.6666 / 6.6236 / 6.5827 / 6.8251 / 6.6399 / 6.8591 | 143 / 143 / 143 / 143 / 143 / 143 |

Every enabled arm reports offers = consumptions = accepted uploads, zero replaced
offers and zero pending offers at draw. The observed render/Main cycles already
exceed 16.667 and 33.334 ms, so a newly offered packet is due by the next observed
consumption opportunity. **This cohort removes no redundant Full upload
transaction.** All 0-versus-30, 0-versus-60 and 30-versus-60 relative directions
are NOT_ESTABLISHED. This is retained negative evidence for these deadline arms,
not a test of a hypothetical coalescing treatment that was never activated.

The deadline sidecar's post-draw age can include a retained pre-capture material
plane, whereas the stricter submitted-material age includes only independently
joined in-capture uploads. For example, large-case bootstrap-inclusive maxima
around 830–846 ms and joined in-capture maxima around 241–265 ms have different
clock populations. The packet retains both scopes; neither is silently used as
the other.

## Ordinary eight-actor workloads

Both 60-second captures use the separately registered ordinary scene with eight
actual body owners, seven neutral actors, controlled flight, active Wave fluids,
Follow and ordinary painting. These are not aliases of the frozen single-actor
V3 tape and do not supply a matched treatment comparison.

| Ordinary mixed scene | Actual steps / seconds | Steps/s | Gap p50 / p95 / p99 / max, ms | Paint admission to first matching uploaded CPU material, median / max ms |
| --- | --- | ---: | --- | --- |
| 512 | 704 / 60.067 | 11.7203 | 85.097 / 88.264 / 90.437 / 103.846 | 86.795 / 89.511 |
| 1024 | 650 / 60.002 | 10.8329 | 92.010 / 96.146 / 98.148 / 99.575 | 96.639 / 102.646 |

All actual owner, command lease, accepted native response, Water and installed
terrain gates pass. Each scene has four real ordinary paint admissions and four
independently observed material outcomes. The passive barrel has 31 observed
contact steps, first at step 33 or 53 respectively. Paint-probe cost includes all
eight attempts, including failed searches: 185/222 microseconds total. The
admission-to-next-physical-completion maxima are 85.795/94.768 ms.

These input clocks begin at the ordinary application API, not at a hardware
device. Worker mutation may enter native tick N or N+1 depending on already
running work; the earliest observed revision, serial and tick remain retained.
A later installed terrain revision is an aggregate revision witness, not a
per-brush causal ACK. The two scenes consume about 3.27/3.29 CPU equivalents
including setup, with approximately 1,114/1,157 MiB queried peak RSS.

Visible first-part pose-age p95 is only 8.153/14.773 ms, but maximum visible age
is 177.341/198.955 ms and **1,463 of 5,632 / 1,286 of 5,200 body observations
are withheld**. Visible-only percentiles therefore cannot certify all-actor
presentation freshness. Three 512 actors remain withheld through capture end
for observed episodes of about 37.0–41.4 seconds; four 1024 actors have episodes
of about 24.6–33.3 seconds. These are right-censored observations, not inferred
times of eventual recovery.

An independent join to the real completed body centers and submitted Follow
rectangle finds that most long episodes occur outside the current view, near
the lower canvas boundary. All joined hidden centers remain inside native
extent. There are nevertheless **103 / 64 hidden body observations whose
physical center lies inside the submitted view**, including 4/17 omissions of
the controlled actor. Center inclusion is not a pixel-visibility or full-collider
test, and the long off-view episodes must not be described as proven long
on-screen disappearance. The [position audit](final03-linux/final03-linux-mixed-hidden-positions.json)
retains every slot's counts and reason breakdown.

The recorded `bounded_pose_delta` is the initial swept-safety refusal; later
native/live endpoint re-entry failures need not overwrite it. It cannot alone
diagnose the final cause of persistent hiding. A [35-sample packet](final03-linux/final03-linux-hidden-frame-samples.json)
retains each long episode's preceding visible frame, first hidden frame, first
bounded refusal, midpoint and final frame, with actual physical pose, upload
serial, World, generated clock, worker publication and native-capture interval.
Native-bound and rejected endpoint poses are explicitly unavailable in this
observer. A separate read-only endpoint diagnostic may explain that mechanism,
but cannot retrospectively supply fields missing from these captures. Required
material/pose safety gates are not relaxed to make a hidden actor visible.

## Causal interpretation

The newer captures intentionally disable the full producer causal trace. Their
native-reported elapsed duration is not an exact start clock, so subtraction
cannot reconstruct dispatch, worker wake or native start. The earlier
[Main-publication interval audit](development02-causal-intervals.md) retains
that boundary and unions overlapping transaction intervals.

Before requesting another expensive experiment, the existing Windows c90
current-Wave2048 causal capture from run 45078090513 was re-read. All 144 exact
native/terrain/application/real-completion joins reproduce the unchanged frozen
causal reducer, and all 143 consecutive clock partitions are ordered. Its
[retained stage recovery](final03-linux/historical-c90-causal-stage-recovery.json)
finds:

| Existing c90 stage | p50 ms | p95 ms | Maximum ms |
| --- | ---: | ---: | ---: |
| Admission completed to worker latch | 0.940 | 1.861 | 16.048 |
| Actual native start to completion | 113.199 | 278.407 | 312.781 |
| Native completion to real physical completion | 105.527 | 355.854 | 742.324 |

The same old capture has publication-to-Main-observation maximum 735.813 ms
and actual Main material-consumption call maximum 752.416 ms. This already
establishes that worker admission/wake delay was not the principal cause of
those historical large tails. Native wall time includes descheduling; the
admission-to-latch span includes queue and scheduling effects rather than a
kernel wakeup alone. The observations do not identify a particular GPU driver
operation or prove how much wall time another architecture would save.

The frozen #719 results separately reject treating a later optimistic
continuation as an established solution: most healthy native packets arrived
after Main returned, and the in-callback cases required changed terrain. Neither
the old capture nor those continuation results provide a current-source
Wave512 stage split with matched causal OFF/ON/ON/OFF calibration. A bounded
Windows Wave512 diagnostic using the existing clocks and all original physical
gates is therefore an unanswered experiment. Repeating the broad Wave2048
causal campaign is deferred unless a new treatment changes that boundary or a
specific large-only ambiguity remains. Faster Target publication's historical
failure to improve physical progress remains relevant negative evidence.

## Reproduction and disposition

[INDEX.json](final03-linux/INDEX.json) hashes the copied independent receipts,
resource audit, timing tables and executed readers. Copies preserve the original
report bytes and program hashes. The original hosted ZIP, original successful
Linux job and all earlier red jobs remain unchanged.

The readers accept `--workspace-root` and optional output locations. The
complete replay uses an exact detached c2 reader checkout at
`evidence-c/final03-reader-root`, the retained D/C native runtime directories,
the actual pinned Linux engine and Rapier bytes, and the original archive.
Only `tools` plus the three frozen base fixture scripts are required in that
reader checkout; their Git identities remain c2. Source reconstruction must set
`GIT_LFS_SKIP_SMUDGE=1` for `git archive` to reproduce the captured pointer blobs
for inactive-platform binaries; actual admitted Linux native and Rapier
libraries are then placed explicitly. Allowing local LFS availability to expand
those inactive entries would correctly fail source closure. The original
bootstrap exclusions remain exact rather than allowing arbitrary differences.

The independently justified disposition is:

- Retain the Linux large-Wave, medium-Wave and landscape improvements as
  cohort-specific physical evidence; retain Wave512 and Pressure as not
  established.
- Retain every deadline arm as a negative/no-coalescing control and keep the
  retired three-slot performance results separate from its passing correctness
  evidence.
- Preserve actual step, terrain, native material and publication ownership gates;
  neither hidden poses nor slow rendering authorize fake callback credit,
  invalid-terrain stepping or weakened visual safety.
- Treat submitted-pose/Follow ages, omitted actors, ordinary input latency,
  sustained absolute gaps and process cost as distinct acceptance dimensions.
  A favorable rate direction or green CI alone closes none of them.
- Require source-exact Windows outcomes and physical NVIDIA/WGL owner evaluation,
  including active fluids, flight, painting, mixed actors, save/reopen, visible
  trails and device responsiveness, before any playability acceptance or
  production-default decision.
