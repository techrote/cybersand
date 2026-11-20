---
title: WB-ACTOR-COMPOSE-001 source and qualification record
status: Current
document-kind: evidence
scope: Dated implementation, donor requalification, runtime custody, failures and platform evidence for issue589
canonical-for: []
last-reviewed: 2026-11-20
related-documents: [../systems/workbench-actor-composition.md, ../operations/workbench-actor-composition.md, ../architecture/shared-workbench-authoring-data.md, ../operations/local-build-and-validation.md]
---

# WB-ACTOR-COMPOSE-001 source and qualification record

## Source and acceptance boundary

The owner explicitly authorized implementation beyond the original planning-only
boundary of [issue #589](https://github.com/techrote/cybersand/issues/589).
The branch is `feat/workbench-actor-composition-589`, created from freshly fetched
accepted main **`de109d0131641d6adc8d25bb9ced7ca3d4991105`**. No donor branch was
merged. Delivery remains **Draft/HOLD**; neither merge, Ready promotion nor
auto-merge is authorized. The system and owner guides describe the candidate,
not accepted-main availability or universal rig playfeel.

The final source commit, hosted run, package identity and independent verdict
are recorded below after their actual execution. Intermediate successes do not
stand in for final source-matched platform qualification.

## Current source and historical investigation

The current inventory covered sampled ACT-001/002, physical ACT-004/005,
Player Playground, the eight-flyer fleet, 4LY teacher/controller, physical
Thunderbowl, local Thunderbowl policies and issued-observation contracts.
The primary integration gap was capability admission plus one-body-per-actor
Workbench mapping. Existing producer takeover, resource, equipment and script
mechanisms were retained.

| Read-only donor | Inspected head | Independently reused or rejected |
|---|---|---|
| PR #402 | `80bae8847fc2428a213f8b0e5e1c8fcd7e1b80ff` | Catalogue/profile and bounded authored-option ideas; no broad merge or old acceptance claims |
| PR #409 | `6bdab8ef59e1d7b9771718ebe07dd799c1e06ed3` | Per-part custody, capability/presentation and prepared-transform mechanisms; current Setup-v2 and prepared-owner contracts take precedence |

The narrow `force_update_transform()` before freezing/capturing a prepared body
was requalified against an actual one-float32-ULP retained-angle failure. Exact
pose equality remains enforced. Native field players, old schema variants and
donor acceptance instructions were not imported. Nearby publication, presentation,
camera, Workbench and water branches remain independent; no renderer/camera
coordinator or material-law changes were introduced.

## Implemented ownership boundaries

The [canonical contract](../systems/workbench-actor-composition.md) owns the full
capability matrix and interface. This integration uses the existing native World,
main-thread Rapier session, prepared adoption, physical scripts/usable scripts,
fleet controller, player rigs, 4LY teacher and leased policy envelope. New adapters
are capability admission, copied local decisions, per-instance UI/schema and
multipart bridge indexing. The native change raises the bounded Workbench
response-body storage from eight to64 while logical actor slots remain eight
and occupancy proxies remain64.

The saved Mixed Actor Workshop contains Midge/human, Runner/scripted Brick
Stamper, Crawler/scripted Powder Vacuum, Skimmer/scripted Water Lance,
Stuntbuggy/policy fixture and a passive barrel: six actors,24 prepared bodies.
Live handoff preserves pose, momentum, resources and equipment. Authored
Reset/replacement/equipment Apply may restart state and are explicitly separate.

## Local execution and retained negative evidence

All reported Godot executions use **4.7.stable.official.5b4e0cb0f**. The host's
unrelated installed4.7.2 was not substituted. Linux and Windows Rapier retain the
accepted pinned patched0.35.2 addon /0.35.1 core. Native input ledgers cover all95
files. The pinned Linux build passes the retained ABI floor (bundle GLIBC2.34,
GLIBCXX3.4.30, CXXABI1.3.9). A preliminary GCC14 binary and a contaminated
GLIBC2.38 attempt were rejected for final publication; no pin was relaxed.

Intermediate actual-source results before the final campaign include:

| Execution | Observed result and scope |
|---|---|
| Actor catalogue author / fresh-process reopen |422/424 assertions, zero failures; old Setup-v2, generated and material-baseline round trips plus59-model admission |
| Session control |79 assertions, zero failures; independently issued actions, stale replies, takeover and pure steering reuse |
| Real native/Rapier composition |317 assertions, zero failures;300 native and Rapier ticks, real motion/tools,64-body admission and65-body refusal |
| Ordinary Workbench author / fresh-process reopen |98/14 assertions, zero failures; six-actor authored replay, human/script handoff, painting, paused Step and live replacement |
| Prepared owner |49 assertions, zero failures; retained rotated parts across real frames plus deliberate one-ULP mutation refusal |
| ACT-004 cancellation adversary |15 assertions, zero failures; a competing cancellation crosses the final native-write boundary safely |
| Existing session / script / fleet / input / Art native |113/57/88/26/146 assertions, zero failures in their respective local runs |

Counts above describe those intermediate runs, not a fabricated single suite.
The final platform runner records exact completion receipts independently.

Negative evidence was retained outside source in qualification logs. Initial
mixed replacement failed strict retained-pose equality until deferred transform
canonicalization was repaired. Full-catalogue toolbar popups caused bad click
selection; compact fleet/placed-model toolbar lists and a family-filtered detailed
browser repaired the interaction. An old pilot test assumed inspection/placement
must change control and was revised to explicitly exercise the intended independent
pilot behavior. Review also found deferred UI intent surviving failed preparation
and an ACT-004 admission/apply cancellation race; both receive focused regressions.

## Reproduction and platform campaign

Use the repository's pinned dependencies and source-provenance checks. Each
test has its own bounded process watchdog and retained original log. The
branch-scoped workflow
[`workbench-actor-composition.yml`](../../.github/workflows/workbench-actor-composition.yml)
builds both pinned native candidates, records source/input/byte custody, then
uses the same source in Linux and Windows Godot. Its
[`runner`](../../tools/ci/run_workbench_actor_qualification.py) executes focused
existing and new regressions, fresh-process authored reopen and actual graphical
framebuffer capture. A copied Windows package is then exercised outside Git.

Local commands use the pinned Godot executable with `--headless --path godot
--script res://tests/<fixture>.gd`, isolated `XDG_DATA_HOME`, and a240-second
outer bound for the larger integration campaign. New fixture names are
`test_workbench_actor_catalog`, `test_workbench_actor_composition_session`,
`test_workbench_actor_composition_native`, `test_workbench_actor_composition`,
and `test_physical_actor_effect_cancellation`. The integration fixture's reopen
mode runs in a distinct process against the preceding saved authored file.

The performance fixture `measure_workbench_actor_composition.gd` measures
1024×512 and2048×1024 material canvases: no actors, a human flyer, one script,
heterogeneous scripts, mixed producers and active equipment. It records actual
native/Rapier progression, frame quantiles, copied observation and decision costs,
publication times, static memory, paused editing and resumption. Baseline mode
uses the same geometry and no-actor/flyer cases on the untouched accepted-main
worktree. Final comparison values belong in the completed evidence section.

Local GUI attempts failed because no usable X11/Wayland display was available;
standard userland Xvfb could not establish listening sockets. Headless execution
is not graphical playfeel acceptance. Hosted actual framebuffer captures and
Windows installed-package results are separate required evidence. Manual owner
assessment remains the [practical acceptance procedure](../operations/workbench-actor-composition.md).

## Final qualification and review

Pending execution at this source checkpoint: final coherent committed-source
platform campaign, graphical PNG gallery, portable Windows package, quiet
baseline performance comparison and independent complete-source verdict.
Failures must be repaired or recorded here with their exact reproduction before
handoff. The PR remains Draft/HOLD regardless of automated test success.

The expanded147-check integration adds same-frame pointer movement/release,
custom-item hand-back and prior-source retirement across new authored starts.
Its first execution stalled after240 physics ticks when opening the composition
inspector and was interrupted (exit130). The unchanged sequence with additional
wait-state diagnostics then passed147/147 in20.399seconds. This single rerun
does not explain or close the intermittent stall; repeated reproduction and
native/Rapier fence inspection remain required before handoff.

### Lifecycle failure identified and repaired

The next repeat reproduced the failure with native tick12 while Rapier reached858.
An explicit same-frame Pause→Play then reproduced the exact first refusal at
Rapier tick13: `cancelled_generation`, `frame_admitted=false`. The worker revoked
equipment immediately, but the actor session previously observed pause only in a
later physics callback. The previous completed sample still satisfied main's
wait fence, allowing Rapier to advance against stale native publication.

The repair synchronously suspends/resumes the existing session at both Workbench
pause edges and during fallible preparation/rollback, publishes fresh neutral
authority before resumed stepping, and stops the coupled owner on a missing or
refused physical frame. The visible error blocks Play and Step until explicit
Reset/Restore preparation. Ordinary refused policy/tool actions still admit
their coherent physical frame and do not take this fault path. Pending Step is
cleared, so fault recovery stays reachable. No cancellation check was weakened.

A separate sleeping-body adversary reproduced an equipment mount/mask mismatch:
the active-only cache could precede the direct body pose used for native masks.
The same fixture failed2/323 before the repair and passed323/323 after using
current Rapier RID transforms for equipment parts. Deliberately forged mount
geometry still refuses. No additional physics owner or tolerance was introduced.

The strengthened ordinary-host run then passed **171 assertions**, with all15
coupled intervals within one native/Rapier tick. It verifies a real neutral
physics input sample before actual human D consumption, actual pointer
press/motion/release within one process frame, running prepared refusal with
unchanged old RIDs/pose/momentum/resources, and an intentional generation fault
that blocks Play/Step and recovers through Reset. The only body-frame refusal in
that run was the deliberately induced fault. This supersedes the earlier weak
long-phase assertion that required merely one native tick during many Rapier steps.

The supplied Crawler spawn also moved from x342 above sand to x300 on the solid
approach. Native granular support does not fabricate the Rapier contact that its
traction requires. The exact six-actor focused probe measured480/480 coupled
steps and60.73cells of horizontal patrol after settling,397 supported ticks of420,
and63 legitimate tool material changes. Ordinary Workbench confirmed61.48cells
of horizontal travel and actual support; the full cast produced641 legitimate
changed cells. Controller algorithms, material laws and observation semantics
remain unchanged. Original failures and the source-matched corrective runs are
retained separately.

### Initial quiet performance comparison

The first sequential accepted-main/candidate runs used the same pinned engine,
geometry, 12-tick warmup, five-second samples and60-frame cap in this Linux
container (nine visible logical CPUs). Both were headless. All12 candidate cases
progressed; both equipment cases retained paused Rapier state during painting and
resumed successfully. No inference/model service was running. These short samples
are observations, not a statistical equivalence claim.

| Canvas / case | Main native ticks/s | Candidate native / Rapier ticks/s | Main / candidate frame p95 ms |
|---|---:|---:|---:|
|1024×512, empty |60.00|59.99 / no bodies|16.875 /17.694|
|1024×512, human flyer |60.01|56.04 /56.04|17.198 /22.721|
|2048×1024, empty |60.00|60.04 / no bodies|17.064 /17.222|
|2048×1024, human flyer |58.92|57.52 /57.52|17.226 /19.538|
|2048×1024, one script |Not supported on main|59.46 /59.46|— /18.212|
|2048×1024, heterogeneous scripts |Not supported on main|58.49 /58.49|— /21.109|
|2048×1024, mixed producers |Not supported on main|58.41 /58.41|— /20.539|
|2048×1024, active equipment |Not supported on main|54.17 /53.97|— /25.583|

This records an **observed flyer-control regression in the first sample**, pending
repeat controls and investigation; it must not be described as no regression.
The1024 equipment sample also had one174.658ms frame. Candidate native publication
p95 ranged0.533–1.058ms. Controller decisions across the whole five-second
equipment sample took21.329ms (1024) /19.915ms (2048); copied observations for all
equipment actors had p95 of4.074ms /0.811ms respectively. Headless results do not
measure GPU presentation. The full candidate process peaked at488,360KiB RSS
versus476,620KiB for the smaller four-case baseline campaign; these different
workload sets are explicitly not a like-for-like memory regression claim.
