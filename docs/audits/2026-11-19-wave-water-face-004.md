---
title: Full-face Water release and sharkfin wave investigation
status: Current
document-kind: audit
scope: Draft owner evaluation on the generated waterwall and painted ramp
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../architecture/ballistic-water-v1.md, ../operations/workbench-water-lab.md, 2026-11-19-wave-water-ramp-003.md]
---

# Full-face Water release and sharkfin waves

The owner circled an exposed vertical reservoir edge on the 1,024 × 1,024 generated waterwall and five abrupt changes in the Water profile on the painted 2,048 × 2,048 ramp. The latter extent matches the saved canvas and prior raw measurement receipt. The previous evaluation package's qualification table mislabeled it as 1,024 × 1,024. Both inputs are the original local files. The wall has 166 Water stamps and verified generated terrain SHA-256 `9b8b4ef6339c4d922c499dd3240198209a8a3cfcca9f9fd49cf1b6fa918f91f5`. The ramp has 635 edits and file SHA-256 `7aba8a47c926cc1911bc4ee519179c595b686692d5c78db8f103b8b62d311acb`.

## Comparison

The reference is the [previous gameplay build](2026-11-19-wave-water-ramp-003.md) at `ebebd1fdf405cea298f5677ba853e0bbc8a77ddb`. Its two-round Wave setting enables spill, blobs, crest flight and ballistic release. With Sheet rate 64, the hybrid law selects the upper two cell-equivalents of head for a throw. Deeper exposed rows can pour through the grid. A separate control uses the same previous law at fall speed 3 to measure the effect of opening the entire face.

## Why the wall sprayed only at the top

With the old sheet law, a 96-row waterwall at fall speed 3 produced two launch rows beside open air, and none behind an already full falling curtain. In the full-face fixture all 96 heights launched through air and also through a filled falling curtain. The dry-face case threw 9,207 units and sent 2,973 through the grid. A 640-row wall with 24 available slots exercises the bounded selection separately. Scarce slots have to be shared across the wall.

The new mode retains the existing parcel owner and pool. The per-face throw uses at most half the donor's available Water, capped at half an ordinary full cell. The grid contribution is limited both by the remainder of the donor half after the throw and by half the receiving room. With the current Sheet rate of 64, one quarter of the face allowance is reserved for the sheet when it has room. An unselected throw leaves its Water in the donor. The raw switch is zero. To reverse the change in a gameplay session, clear **Full face** and Apply.

A reviewer found that using the tick's available slots to decide the pressure next to a wet curtain could pull 16 units back into a half-full lip when the pool was full, even though neither comparison could launch. The corrected rule uses the configured law independently of free slots. With the same remote parcel, the impact probe held 128/255 units in lip/curtain in both cases. Tests cover selected-region pause and re-entry, wet diagonal and straight barriers, full falling curtains, partial donors with two open faces, a 65,535-unit donor, bounded nominations, scarce slots, worker parity and identity with the new settings off. The full-face native checkpoint is `c6a785cb5`. It changes no protected source.

## Diagnosing the sharkfins

Registration against the painted brick floor put the five orange marks near world x=440, 483, 554, 706 and 822. A fall-3, crest-only replay around tick 580 matched the supplied still's visible surface within about 1.6 cells on average across 812 columns. This is a matched replay. The exact original tick and motion history are unavailable from the still.

At one marked location the replay crest advanced right from x473 to x495 over ticks 572–584. Another moved from x544 to x568. Net Water passed downhill through all five marked cross-sections during the measured window. An upstream ripple also occurred elsewhere. From ticks 468 to 492 it moved left from x406 to x360, while 101,511 net Water units crossed x406 to the right. A neighboring crest moved right over the same interval. The apparent direction of a steep face is therefore insufficient to identify either crest travel or Water transport.

The deep dark cuts also appear in the native stored Water. At tick 580 near x485, rows in that column held 2–19 of the usual 255 units while their neighbors held at least 127. Two wet faces could each move as much as 127 units outward from that column. Simply reducing Pool feed to 64 reduced these cuts, but the level-ground front at tick 64 lost more than a third of its reach. The selected independent Deep pool feed limit applies the smaller allowance only beside a sufficiently deep responding stack. Zero disables the limit. It changes no storage, scheduling pass, or parcel budget. Further profile measurements, capture receipts, timing and runtime qualification are linked from the draft PR and this [evaluation record](wave-water-face-004-2026-11-19/evaluation.md).

## Ready-for-review validation, 20 November

The first full run on `7286f516c` exposed two failures. The Workbench tried to read a null receipt when native preparation refused a malformed liquid policy. The deferred-paint regression stopped after 38 checks on Linux, and its Windows shard also failed. Separately, the flight presentation test reported a blank trainer capture. The corrected ramp dependency tests the receipt before reading the Water family and samples the submitted gameplay image for visible pixels. The existing paint refusal, scene and render expectations still apply. [Linux deferred-paint case](https://github.com/techrote/cybersand/actions/runs/44761302750/job/136379520053) · [Windows deferred-paint case](https://github.com/techrote/cybersand/actions/runs/44761302750/job/136377089625) · [Linux flight render case](https://github.com/techrote/cybersand/actions/runs/44761302750/job/136379516949)
