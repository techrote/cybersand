---
title: AMBIENT-001 profile authoring and example qualification
status: Current
document-kind: evidence
scope: Draft profile schema, ordinary Workbench editor, authored examples, independent review and bounded qualification
last-reviewed: 2026-11-24
---

# AMBIENT-001 authoring lane

This ledger describes the opt-in Draft/HOLD implementation on accepted main
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`, with the uncommitted AMBIENT-001
source delta. It does not accept Actor Compose #762, raise the accepted eight
logical actor capacity, or claim physical Windows/NVIDIA playfeel. The mission
ledger records the final recoverable source checkpoint and delivery disposition.

## Owned source and authoring contract

This lane owns the new `godot/scripts/ambient/ambient_profile.gd`,
`ambient_profile_editor.gd`, `ambient_examples.gd`,
`godot/data/ambient/profiles.json`, the five
`godot/examples/workbench/ambient-*.json` authored starts, focused authoring/editor
tests, the optional graphical capture helper and this ledger. The lead owns the
narrow shared Workbench, actor catalogue, session and controller integration.

The profile schema has exact version-1 keys `version`, `id`, `name`,
`description`, `seed`, `shared_seed` and `modules`. Each module has exact keys
`id`, `type`, `enabled`, `priority`, `weight` and `params`. Unknown keys and
modules, duplicate instance IDs, nonfinite numbers, incorrect numeric types,
unknown material IDs and incompatible enabled modules are refused. Cross-field
checks require approach distance and hysteresis to fit within the observation
radius; avoidance entry/exit and home/boundary release thresholds must be ordered.
At most sixteen modules and eight distinct material IDs are authored per profile.

`validate()` returns an explanatory error without changing input. `canonicalize()`
returns an independent copy only after validation; JSON integer values become
integers after admission. Module metadata comes from the engine's
`module_specs()`, so the GUI and runtime share defaults, units, ranges and
capability requirements. The accepted native material IDs are 1–131 excluding
reserved slot 10; Empty is not a material preference target. The live picker
additionally reads the native material catalogue. Oil is 16 and Water is 3.

An optional authored `control.ambient` block accompanies the existing policy
producer with discriminator `policy: "ambient"`. The block remains present
during a human handoff. Ordinary authored persistence stores profile values and
actor assignment, not timers, RNG state, evolved material, current momentum or
physical continuation. Applying a profile resets its private runtime intent.
Independent seeds mix each stable authored actor ID by default. Explicit shared
seed mode omits that ID; differing observations can still produce different actions.

## Practical editor

**Actor Composition… → Behaviour profile…** opens a lazy staged window for the
inspected actor. Opening, choosing a module or refreshing diagnostics does not
issue an observation, reset control authority or consume randomness. The window
remains bound to that actor when another actor is inspected elsewhere.

The window offers preset selection, duplicate-to-customize, profile name and ID,
description, seed and explicit shared-seed choice. Modules can be added, removed,
enabled, disabled and reordered. Parameters use metadata-driven spinboxes or
checkboxes with units, ranges and descriptions; material fields show native
catalogue names and numeric IDs. The current release assigns one actor at a time;
group assignment is not implemented. Reusing the same authored profile manually
retains independent RNG streams unless shared seed is enabled.

**Apply profile to this actor** validates and waits for the ordinary live
controller setter's acknowledgement. A refusal retains the prior valid authored
configuration. **Revert staged edits** reloads the currently admitted profile.
Apply also compares the baseline profile, actor model/hash and bound session
run/epoch. It refuses an external edit or a replaced World even when the new
World contains the same actor ID, model and profile. Pause can renew control
generation without invalidating an otherwise current editor transaction.

Ground actors initially stage Oil Moth; a supported 4LY flight actor stages
Drifting Flyer, avoiding an invalid ground ledge rule. An enabled incompatible
module remains visible in the draft with an explanatory refusal until disabled
or removed. The live inspector reads copied `diagnostics.ambient` and
`diagnostics.environment`, showing chosen intent, candidates and inactive reasons,
override duration, nearby observed material and decision cost. Its 5 Hz refresh
does not participate in the decision cadence. The optional perception overlay is
off by default and reads the same copied diagnostics.

## Readable profiles and genuine examples

All six presets live in the readable JSON catalogue and use the same eleven
implemented module types. Preset names create no additional physical abilities.

| Profile | Distinguishing authored preferences |
| --- | --- |
| Oil Moth | Slow wandering, Oil within 50 cells with a 10-cell standoff, stronger Water avoidance and ten-second ground ledge retreat. |
| Shy Crawler | Lower roaming pace, early Water avoidance, small allowed drop and a persistent ten-second retreat. |
| Curious Surveyor | Faster local wandering, Oil investigation/dwell, occasional rest, home return and obstruction recovery. |
| Idle Mechanic | Short home radius, long periodic rest, slow activity and gentle separation. |
| Drifting Flyer | Existing 4LY flight, preferred altitude near its authored home, loose home return, crowd separation and boundary avoidance. |
| Social Roamer | Follow nearby compatible actors at a preferred separation, stronger short-range crowd avoidance and ordinary safety modules. |

The five example recipes produce ordinary version-2 Workbench starts. Their
checked-in JSON representations use real accepted actor definition hashes and
native material rectangles. Scene construction uses no alternative World or
physical owner, framebuffer interpretation, artificial animation or movement
assignment. Current scenes are 1024 by 512 cells.

| Example | Cast and physical scene |
| --- | --- |
| `ambient-oil-water` | Runner, Crawler and Monowheel beside real Oil/Water basins under steel service structures. |
| `ambient-ledge-walkway` | Two ground actors on a broken raised gantry, distinct from canvas edges, with a lower safety floor. |
| `ambient-industrial-yard` | Four ground inhabitants and one 4LY flyer among real draining Oil/Water reservoirs, platforms and crates. |
| `ambient-settlement` | Eight actors, six personalities and three locomotion families at the accepted host capacity. |
| `ambient-flight` | Two existing 4LY rigs in an open hangar with actual architecture, material and altitude preferences. |

## Owner walkthrough

1. Open **Shared Workbench**, then **Actor Composition…**. Choose **Oil / Water
   preference garden** under **Ambient examples** and press **Load scene**. Wait
   for native and physical admission. The normal starts remain paused and ambient
   remains opt-in outside these explicit examples.
2. Press **Play / Pause [P]** and observe the inhabitants. In the main toolbar,
   choose **Paint**, select Oil or Water and paint near an actor. Radius is in
   world cells. The default material preference example is an inclusive 50-cell
   circle sampled on the admitted four-cell grid, so a single unsampled cell can
   remain unobserved. Material alone does not imply a traversable route.
3. In **Actor Composition…**, choose the **Runner** under **Inspect**, then open
   **Behaviour profile…**. Inspection leaves its producer active. The controller
   selector also offers **Procedural NPC / Ambient** for supported actors.
4. Choose **Oil Moth**, press **Duplicate to customize**, give the profile a name
   and an independent seed, then select **Seek material**. Change its native
   material selection, radius, standoff or pace. Add **Rest**, reorder it or
   disable it to compare the same component vocabulary. Changes remain staged.
5. Press **Apply profile to this actor** and read the acknowledgement or refusal.
   Save the garden start if you want to keep those edits. To observe a physical
   ledge trigger, load **Ten-second retreat walkway**, inspect its **Crawler**
   using **Shy Crawler**, and open **Behaviour profile…**. Select **Avoid ledge**,
   change its duration from 10 to another admitted number of simulation seconds,
   and apply it to this actor. Press **Play / Pause [P]** to observe the retreat.
   The live inspector distinguishes chosen intent,
   observed target and remaining time from actual physical travel. Pause freezes
   gameplay timers. The **Perception overlay** is optional.
6. Close the editor, choose **Pilot inspected** to take control, then **Hand back**
   to restart its procedural controller from the retained authored profile.
   Selection alone never pilots an actor. Save under a new name with
   **Save start [Ctrl+S]**, then **Load start** to reopen. The exact admitted
   profile and assignment return; ephemeral intentions and RNG restart from
   their authored seeds and physical actors return to their authored starts.

## Focused execution evidence

The initial qualification uses pinned official Godot
`4.7.stable.official.5b4e0cb0f`, executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`,
on Linux. The retained native binary is
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`,
with its source-input inventory verified against accepted main by the lead.
No native runtime or Rapier source was changed by this lane. Actual Workbench
tests set `cybersand/native_worker_threads` to one before instantiating the host.
These local results precede the final source freeze and must be rerun or bound
to the final checkpoint in the mission packet.

| Case | Observed result | Scope |
| --- | --- | --- |
| `test_ambient_authoring.gd --save ambient-001-authoring-test` | 242 checks passed | Six presets, five examples, twenty total actors across fixtures, actual native material catalogue, strict schema, legacy controller compatibility and ordinary save. |
| Separate process `test_ambient_authoring.gd --reopen ambient-001-authoring-test` | 256 checks passed | Exact admitted profiles, module order, seeds and per-actor assignments survive fresh-process reopen. Invalid save preserves the previous file bytes. |
| `test_ambient_profile_editor.gd` | 46 checks passed, 7.587 seconds | Actual main scene, native prepared owner, Rapier session and mounted editor; paused authoring, real acknowledgements, reachable default/minimum window layouts and explicit 4LY effort explanation on a 512-cell fixture. |
| Independent `test_ambient_perception.gd` | 130 checks passed, 2.08 seconds | Sibling sensor/actuator implementation independently executed, including actual native Oil relocation, Water hysteresis and resulting core/actuator decisions; fixed copied actor pose in that phase. |
| Independent `test_ambient_native_motion.gd` | 305 checks passed, 7.01 seconds | Real native/Rapier Runner, Monowheel and 4LY Trainer, matched ambient/scripted/random campaigns, 240 ticks and forty decisions each. A later platform-artifact identity assertion adds one check without changing fixture behaviour. |
| `test_ambient_examples_native.gd` | 121 checks passed, 67.391 seconds | All five ordinary scenes loaded through the actual Workbench, each with 240 completed native ticks and Rapier manual steps. Twenty actor instances across scenes each admitted forty commands with no refusals or faults. |
| Independent `test_ambient_engine.gd` | 877 checks passed | Pure module/state/arbitration review; separate 2,400-decision, eight-actor benchmark observed 185.24 µs per decision on this run. |

The editor test covers staging without mutation, seed and module edits, actual
Apply, invalid profile preservation, read-only inspector, selection without
retargeting, external-edit conflict, Revert, pilot/handback, a compatible flyer
default, unsupported ground-module refusal, same-ID World replacement refusal,
explicit rebinding and the normal Save route. Graphical layout evidence is a
separate opt-in helper, `capture_ambient_examples.gd`; it refuses headless
framebuffer claims and records native/physical ticks with every actual image.

The retained Xvfb binary was found, but graphical capture is currently blocked
before Godot starts: this execution environment refuses local socket creation
with `EPERM`, and Xvfb cannot establish its display listener. No graphical image
or layout approval is claimed from that attempt. A follow-up editor regression
checks actual Control allocation and minimum sizes in headless mode; those
measurements remain node-layout evidence, not rendered image evidence. After
shared memory pressure killed unrelated default-2048 startup allocations, the
editor and capture helpers use the accepted authored recovery path to prepare
their initial 512-cell fixture. Product startup and owner preparation are unchanged.

The allocation probe found an actual small-window defect: the original
740×480 minimum clipped Apply and the live inspector because the content needed
more height. A vertical outer scroll container now keeps the controls reachable.
The actual-owner test confirms default 1020×760 allocation and the scrolled
740×480 allocation, where Apply begins at y=280 and the 115-pixel inspector
begins at y=353. The earlier 40-check, 8.158-second editor receipt and the original
failed layout measurement remain retained alongside the 46-check repair receipt.

The all-scenes fixture uses the existing **Load scene** route and records
read-only per-actor pose paths, command admission, idle decisions, sign changes,
observed material targets and stalled active intervals. It asserts genuine
preparation, progression and healthy authority, with no aesthetic or routing
threshold. The arena's Oil Moth reduced nearest-observed Oil distance from
37.90 to 10.49 cells; Shy Crawler selected Water avoidance in twelve decisions.
The industrial scene's native revision advanced from 246 to 489 and its crawler
selected Water avoidance in eighteen decisions. That crawler still encountered
nearby flowing Water: avoidance does not make it immune or guarantee clearance.
Static basins legitimately retained the same native material revision while
physical time advanced.

The first four-second walkway observation produced no ledge trigger because its
cautious crawler began 76 cells from the gap and travelled only nine horizontal
cells. The authored spawn was moved from x=350 to x=410 on the same actual deck,
whose edge is x=426. No module, motor or material rule changed. In the repeated
all-scenes run, physical tick 31 triggered a leftward retreat with 10.0 seconds
remaining. At tick 235 it still had 6.6 seconds remaining, with actual x movement
from 410.09 to 387.61. The lead's separate full-host fixture qualifies the full
ten-second duration, pause and release. The previous no-trigger scene observation
is retained. An earlier harness attempt also retained its log: it incorrectly
required a physical actor session for the deliberately empty initial canvas and
was interrupted before testing; the guard now requires the actor owner only
after an actor example is admitted.

Graphical capture metadata separates current copied physical poses from the
body frame actually bound to displayed material. Each image records the uploaded
generation, render serial and material revision; the separate rendered actor
frame records its session, epoch, sample tick, native tick, revision and World
generation when available. Startup fallback is explicit. Captures also record
source revision, executable hash and actual renderer method, driver and vendor.
The graphical gate must execute these captures before they count as image evidence.

Logs are retained in the mission evidence directory, including earlier failed
attempts. Initial authoring harness failures used stringified JSON equality
across integer/float decoding and a zero character replaced by Godot before
validation. The fixtures were corrected to compare parsed admitted values and
use an actual retained control character. No failures were erased or relabeled.

## Independent review and resolved findings

The behaviour implementer independently reviewed this lane and found four
issues, all repaired before the 40-check editor result: the inspector read the
authored profile instead of live diagnostics; an editor transaction lacked
session run/epoch binding; preflight validation omitted locomotion capabilities;
and the weight tooltip described only steering although zero weight also
disables an override. Tests exercise the repaired identity and refusal paths.

A later capability review found that 4LY accepts Pace through its strict `move`
command, with no separate Effort action channel. The perception lane added an
explicit capability flag. The editor now disables and greys that field for
4LY and explains that its authored value is retained for ground/wheel reuse.
Neither the physical flight motor nor the profile's pace is rescaled.

This lane independently reviewed the engine. An unavailable support sample
failed to break continuous-safe ledge rearming; the implementer repaired it and
added a regression. Multiple ledge module reaches initially shared a maximum
sample; the lead and perception lane now supply deduplicated, exact per-module
owner rays. Follow/crowd metadata initially exceeded the sensor's 96-cell extent;
metadata and cross-threshold validation were corrected.

This lane also inspected perception and actuation source, patch ownership and
the native motion fixture. Material identity is copied raw L8/RG8 numeric data;
the visual-state byte and final display colours are unused. Full baselines and
all patch geometries are validated before mutation. Wrong epoch/generation,
missing baseline, malformed coverage and stale revisions produce unavailable
observations. The worker's render packet accumulates unacknowledged patches, so
a skipped snapshot serial is not itself evidence of missed material changes.
The lead ingests before the renderer acknowledges a packet. Native render IDs
include projected native ballistic material; they do not provide exact stored
cell occupancy alone. Sparse nearest-observed semantics are explicit.

The value actuator writes only legitimate normalized actions. Ground control
uses accepted horizontal feedback, wheel control retains its existing motor,
and 4LY uses the existing desired-velocity `move` interface. It has no position
or velocity-setting authority. Existing motors still own contacts, resources,
thrust and braking. Live motion comparison reports are independently reviewed
separately; different procedural and random generators must not be described as
using an identical RNG stream merely because fixtures and budgets match.

## Windows evaluator reuse investigation

The accepted `tools/package_workbench_landscape_review.py` independently pins
the official Godot 4.7 Windows executable hashes. Read-only retained executable
bytes in the workspace match those constants exactly:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `Godot_v4.7-stable_win64.exe` | 178485256 | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |
| `Godot_v4.7-stable_win64_console.exe` | 198152 | `d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c` |

The original retained package manifest also identifies the official version and
archive SHA-512
`41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9`.
The archive itself was not present in this lane's search. A separate modified
engine and independent candidate native libraries in that workspace are not
part of AMBIENT-001. Executable-byte verification is reuse evidence, not a new
Windows launch receipt. Packaging, exact final source identity, pristine
extraction and Windows execution remain owned by the lead's delivery gate.
