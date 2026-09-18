---
title: Water H-gate synthesis — bulk flow, precision and presentation
status: Current
document-kind: evidence
scope: Human Water Feel evidence from shallow-pool, irregular-bed, corrected steps, constriction, connected-pools and fast-dump; programme disposition for #18/#26
canonical-for: [water-h-gate-2026-09-18]
last-reviewed: 2026-09-18
related-documents: [2026-09-12-issue-19-water-feel-lab.md, ../operations/water-feel-lab-experiment.md, ../operations/architecture-programme-water-feel-addendum.md, ../systems/water-design.md, ../systems/material-appearance-and-rendering.md]
---

# Water H-gate synthesis — 2026-09-18

## Executive conclusion

The H work has produced a stable programme-level conclusion even though it has **not**
selected a production Water bit budget.

The dominant perceptual defect is no longer best described as mass precision. Deep
or spatially extended Water redistributes laterally too weakly/slowly. It can retain
free-surface slopes, cliffs and terraces for thousands of ticks, drain with a
granular-like angle of repose, detach visually from walls, and form locally stable
steps that do not read as liquid. The same implementation can look substantially
more convincing when the Water becomes shallow, especially in thin edge dribbles.

The leading mechanism hypothesis is therefore a missing or inadequate **head/depth
dependent lateral drive / bounded leveling mechanism**. Current Water gravity and
same-row local mass equalization do not explicitly increase lateral drive because a
cell sits underneath a deeper Water column. A separate bounded horizontal
leveling-horizon hypothesis is also justified by the communicating-pools evidence.

This is a #26 problem first. It is **not yet evidence that #18 compact directional
history is required**. #18 remains open and must not be closed or treated as
admitted implementation merely because H found poor bulk flow.

Presentation remains a separate problem. Four-level oriented reconstruction is not
sufficient by itself, and every tested mass width still needs stronger rendering
reconstruction to become visually acceptable. Rendering can hide quantization and
reconstruct a smoother interface after bulk motion is credible; it cannot repair
incorrect discharge, leveling or mass transport.

## Evidence boundary and provenance

All formal semantic arms used coherence 12, four-level oriented presentation and
seed 0 unless noted. The authoritative Windows development runtime in the retained
sessions is the validated #19 runtime, source checkpoint
`3ef4923abb011c5451be0f2ba477d8a3bffb0ee3`, DLL SHA-256
`ce0b252171a7931317068eda62ec1ec773632d760f85f0ebb594af44d197a138`.

The corrected-steps and later sessions share the same H-apparatus fingerprints.
The H capture work itself is still in draft PR #25 and is not a production
migration. Raw ZIPs are intentionally not committed here because they total
hundreds of MiB; their names, sizes and SHA-256 identities are retained in
`2026-09-18-water-h-gate-evidence.json`.

## Human results by scenario

| Scenario | Blind result / useful observation | Disposition |
|---|---|---|
| shallow-pool | mass3 Marginal/rank3; mass5 Marginal/rank2; mass8 Marginal/rank2. 3-bit: irregular blunt sawblade; 5-bit: missing/speckled surface; 8-bit: coarse regular sawtooth. | Precision affects surface quality, but no arm is visually satisfactory. |
| irregular-bed | Formal observations describe all arms as close; best notes say “nice flow, bit slow”; worst says “kinda sluggish but barely different”. The supplied observation subset does not retain the reveal mapping, so do not use it for a bit-budget ranking. | First strong shared-sluggishness signal; led directly to #26. |
| corrected steps | Reveal A=3, B=5, C=8. mass3 Reject/rank3; mass5 Marginal/rank2; mass8 Acceptable/rank1. Owner: shallow Water and rapid edge dribbles look convincing; deeper Water feels slow/stuck/hesitant. | Strong depth dependence. 8-bit best here, but shared deep-flow defect dominates. |
| constriction | Reveal A=3, B=5, C=8. mass3 Marginal/rank1; mass5 Reject/rank2; mass8 Reject/rank3. Persistent free-surface wedge is roughly 42–43 degrees in representative sequence frames. | Clean evidence that more bits do not monotonically improve feel while bulk flow is wrong. Strong granular-like slump defect. |
| connected-pools | Reveal A=3, B=5, C=8. mass3 Reject/rank3; mass5 Marginal/rank2; mass8 Marginal/rank1. All arms retain multi-degree free-surface slopes long after connection; B/C still about 3.4 degrees around tick 4200 in the retained analysis. | Cleanest equilibrium/leveling evidence: higher precision does not solve the leveling defect. |
| fast-dump | Reveal A=3, B=5, C=8. Formal archive contains B Marginal/rank2 and C Reject/rank3; no canonical A observation capture, so do not invent a complete ranking. Owner annotations identify impossible wall-gap/contact loss, unacceptable mid-surface terraces, and occasional “tumbling” edge randomness; a supplied mockup shows the desired smoother coherent draining profile. | Structural evidence, not a complete formal rank set. The tumbling instability is potentially useful inspiration, not accepted behavior. |

## Cross-scenario interpretation

### 1. The primary defect is bulk lateral relaxation / leveling

The repeated symptoms are mutually consistent:

- deep bodies retain steep slopes instead of rapidly flattening;
- communicating pools fail to level convincingly;
- constricted discharge resembles granular slumping;
- deep Water can feel hesitant while shallow edge dribbles feel lively;
- stable terraces or middle steps appear in a free surface;
- wall-adjacent gaps/contact loss can appear in high-flow geometry.

The best current hypothesis is that local lateral transfer lacks enough information
about hydrostatic head or the larger-scale surface-level difference. This does not
imply a Navier-Stokes solver or a global pressure field. A bounded gameplay
approximation may be sufficient.

### 2. Two bounded candidate families are justified

After automated baseline characterization, #26 should compare at least:

1. **Head-scaled local drive.** A bounded local proxy for Water above/depth/head
   increases lateral redistribution strength or cadence where a deep body should
   push outward more strongly.
2. **Bounded leveling horizon.** A limited horizontal surface/leveling lookahead
   or relaxation horizon allows extended Water to respond to a nearby lower
   potential instead of relying only on adjacent same-row mass imbalance.

These should be tested separately before combining them. The second mechanism
should not be described as literal surface tension: its purpose is faster bounded
level equalization, while physical surface tension resists surface-area creation.

### 3. Do not select the mass-bit budget yet

The evidence is not monotonic:

- 8-bit is preferred in corrected steps and connected-pools;
- 3-bit is clearly poor in several surface-quality tests;
- 3-bit nevertheless ranked best in constriction while all arms retained the
  common bulk-flow defect.

That reversal is strong evidence that current flow semantics interact with
quantization strongly enough to confound a final bit-budget decision.

Keep 8-bit as the numerical/control oracle. Treat 3-bit as a weak candidate because
it repeatedly exposes visible quantization and behavioral deficits, but do not turn
that into a final architecture ban. Retest a practical set such as 4/5/6/8 after
bulk-flow and presentation improvements. If 5 or 6 becomes perceptually equivalent
after those fixes, reclaimed state bits remain valuable for later Water semantics.

### 4. Presentation precision is independent from simulation precision

No tested mass width produces an acceptable raw/free-surface appearance everywhere.
The later rendering pass should therefore be allowed to reconstruct a smoother
continuous interface from authoritative state:

- sub-cell/partial coverage;
- local surface reconstruction and normals;
- temporal interpolation;
- thin-film continuity and droplet shaping;
- contact-aware treatment at walls/outlets;
- optional cosmetic local breakup/ripple cues.

The fast-dump “tumbling” glitch is worth preserving as a reference for the kind of
local asymmetric breakup that can make flow lively, but the bug itself must not be
made normative. First identify its cause; then, if desirable, reproduce the useful
visual characteristic under a controlled bounded rule or presentation effect.

Rendering must not be used to conceal incorrect mass transport. Bulk discharge,
leveling, conservation and settling remain authoritative simulation questions.

## #26 next engineering campaign

Before changing semantics, register automated controls using the current source-matched
Water path. Minimum useful fixtures:

1. shallow / medium / deep reservoirs with identical outlets;
2. communicating pools with a fixed initial level difference;
3. constriction/nozzle;
4. fast dump;
5. one shallow/ledge control where current Water already looks relatively good.

Primary metrics should include:

- early discharge versus head;
- lateral COM/range;
- free-surface slope decay;
- level-difference half-life;
- cliff/terrace lifetime;
- time to stable equilibrium;
- exact Water quantity;
- work/visits and p50/p95/p99 tick cost.

Candidate changes must preserve exact closed Water mass, deterministic expected
worker behavior, stable equilibrium, bounded writes/work, scheduler/activity
contracts and protected granular/material policies. Reject candidates that merely
replace sluggishness with crawling, oscillation or excessive over-fluidity.

After a bounded candidate passes the automated screen, re-run a small H set rather
than repeating the full campaign.

## #18 disposition — explicitly remain open

**Do not close #18.**

The H campaign has established a concrete unmet Water-motion problem, but the
strongest evidence currently points to **head/leveling response**, which is distinct
from #18's question of persistent directional memory.

#18 should remain open while #26 characterizes and, if possible, repairs the
head/leveling deficit. Then:

- if horizontal/diagonal injection still loses useful directional motion after the
  #26 correction, register that residual as #18's concrete target and run the
  compact-history experiment;
- if the apparent directional-persistence deficit disappears once bulk leveling is
  corrected, record an H-backed #18 no-go rather than implementing history merely
  because state bits are available.

No #18 implementation is admitted by this report.

## H apparatus / recording limitations

The frame-sequence recorder is useful as tick-indexed supplemental evidence, not as
a literal 60-fps video oracle. Early steps capture reduced simulation throughput to
about 56 Hz and saved only about 21–22 PNG/s. Later constriction,
connected-pools and fast-dump sessions kept simulation near 60 ticks/s while saving
roughly 23–25 PNG/s; many intermediate render-snapshot serials were therefore not
written as images.

Consequently:

- use simulation tick/serial metadata when comparing motion;
- make subjective feel judgements during normal-speed unrecorded/replayed runs;
- treat recorded sequences as supplemental geometry/time evidence;
- do not infer 60 captured visual frames per second from the 60 Hz target.

The constriction archive also contains a later reblind used only to recover C
imagery after reveal. Its mapping is identical to the canonical blind set, but its
camera framing differs; that recovered C sequence is supplemental and must not be
misrepresented as part of the original blind judgement set.

## Programme conclusion

The H gate has done its job: it prevented a premature state-budget decision and
identified the larger problem that must be solved first.

The current decision is:

1. **retain mass8 as numerical/control reference; select no production mass width;**
2. **move engineering attention to #26 head/leveling characterization;**
3. **keep #18 open but held until the residual directional-memory question is
   isolated after #26;**
4. **treat presentation reconstruction as a required later layer, not a substitute
   for correct bulk motion;**
5. **use only a small focused H recheck after bounded semantic candidates pass
   automated evidence gates.**

This is a synthesis/report checkpoint, not a closure of #18, #26 or the architecture
programme.
