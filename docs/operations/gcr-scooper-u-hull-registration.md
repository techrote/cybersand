---
title: Scooper U-hull and corner-reserve comparison
status: Approved design
document-kind: design
scope: Geometry-only U-shaped scoop authoring and bounded static/dynamic comparison; response and material laws unchanged
canonical-for: [gcr-scooper-u-hull-comparison]
last-reviewed: 2026-11-04
related-documents: [gcr-scooper-leak-registration.md, ../systems/granular-review-flight-fleet.md, ../architecture/compound-granular-coupling.md]
---

# GCR-UHULL-003 — registered before shape changes or new results

The owner reports improvement with remaining apparent seam leakage and requests
a simpler U hull with inside-corner fill. Treat seams as a hypothesis: an
occupied proxy-ID boundary is not necessarily a hole in the Boolean mask union.
The existing entry-side repair also falls back for rotation and trajectories
crossing another proxy, so a geometrically sealed joint can still expose a
dynamic transport limitation. Do not call all loss a seam hole.

Start from PR387 source350a9814fe50609b8eb664a8896fb9e3d5e69dd0 in isolated
codex/gcr-scooper-u-hull-20261104. Fresh main is
01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc, tree
4cf99921dc2b33233c3a254f4b6f27ed7cb0f204. Since7ef4856e, PR374 adds pressure
idle-cost research/docs and a native bench, with no production native/Godot or
dependency input change. Retain the reviewed runtime/control branch to isolate
geometry; do not import unrelated evidence. Native89 and SDKs compiled3df1279f
remain matched. Dirty earlier review checkouts, active games, seven old flyers
and the independently owned PR347 payload path are preserved. All PRs stay
unmerged; no sleep, response-law, search/friction/load or material change.

## Frozen candidate and mass properties

Replace only Scooper's description/hull with five nonoverlapping raw rectangles:

| Part | x | y | width | height |
| --- | --- | --- | --- | --- |
| Floor | -15 | 0 | 33 | 4 |
| Left wall | -15 | -8 | 3 | 8 |
| Right wall | 15 | -8 | 3 | 8 |
| Left inside corner | -12 | -3 | 2 | 3 |
| Right inside corner | 13 | -3 | 2 | 3 |

The U has outer33×12 bounds, four-cell floor, three-cell walls and two small
corner reserves adjoining them. The floor is continuous across the full width.
These blocks widen the barrier near each inside corner; they do not eliminate
every decomposition seam or justify overlapping colliders. Existing area/COM/I
and native admission deliberately reject positive-area overlap; retain that
authority rather than double-counting mass/capacity to hide leakage.

Keep actual mass0.18 and every flight/motor/material/capability value unchanged.
Uniform area is192, raw COM(3/2,9/32), inertia253851/10240=24.79013671875.
The original85-area stepped hull's actual I22.099868512110724 remains a named
historical fixture. New I is reported, not replaced with the old value. At the
existing alpha cap48 the new I requires1189.9265625 torque, below existing1200;
this is arithmetic/source evidence, not human feel acceptance.

## Static and live population

Use an explicit frozen original profile and the candidate profile. Both use the
same native SDK, one physical owner/mass/budget, commands and material laws.
Align each profile's geometric cavity centre to worldX512 and floor top to
worldY250, deriving the actual COM spawn from raw geometry. Seed exactly16
native grains at(504,249),16×1, verify they are clear of BOTH initial hulls, and
record exact poses/COM/I rather than assume identical COM or masked writes.
Original cavity is[-12,-4,24,6], floor index0, left wall1, no closed right wall,
raw rim-5. U observation cavity is[-12,-8,27,8], with corner fills excluded by
actual union membership; conservative core[-10,-8,23,8], side indices1/2,
floor index0 and rim-8. Record inside material, transient pose overlap, persistent
below-floor/side occupancy and over-rim departure separately. No grain IDs,
inventory, reattachment, extra simulation ticks or material restoration.

Per profile and OS, run twelve450-tick cases: stationary; full rise; boosted
rise; strafe right/left; diagonal up-right/up-left; deliberate left/right tip;
full-rise LA and event-off controls; and selective up-right diagonal with Dust14.
All other cases use Sand2 and selective arrivals. Ticks0..119 neutral hover,
120..239 the specified move or Q/E tip,240..329 brake/return level,330..449
neutral. Commands are the existing controller actions/ports. This is48 captures
across two profiles and two OSs, not a Cartesian material/force sweep.

Static masks: each profile at angles0,pi/4,pi/2 and eight phases
(0,0),(.25,.25),(.5,.5),(.75,.75),(.25,.75),(.75,.25),(.5,0),(0,.5).
Compare native Boolean occupancy with the actual copied rectangle union;
proxy-ID differences alone are not holes. Observe four- and eight-neighbour
cavity/exterior connectivity with a virtual rim cap in the analysis graph only,
never a native lid. Report exact/boundary-sensitive discrepancies and actual
paths. This is96 pose/profile/OS observations; static closure alone cannot prove
dynamic ejection/rotation closure.

## Gates and handoff

Preserve exact quantities, native authority, one body/COM/I/budget, finite/bounded
work, hard/Water and old seven-flyer controls. Freeze the old shape in historical
fixtures; adapt tests that wrongly assume the active Scooper always has six
parts without rewriting past evidence. Existing historical carry apparatus must
retain its old profile/classification rather than silently relabel U observations
with its old open-nose and floor thresholds.

Report geometry, supported samples, actual motion/torque, observed side/rim
loss, occupancy discrepancies, relocation/work and owner-step timing by case.
No numerical retention threshold is invented after observing results. If the U
reduces loss, offer a source-labelled playable room and retain any remaining
rotational/transport gap. If losses persist despite closed masks, characterize
that mechanism rather than adding arbitrary overlapping shapes or tuning laws.
Owner gameplay judgement remains required and all PRs remain draft/unmerged.
