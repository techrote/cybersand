---
title: AMBIENT-001 implementation and qualification ledger
status: Current
document-kind: reference
scope: Opt-in ambient actor implementation, exact-source evidence and unresolved qualification
canonical-for: [ambient-001-evidence]
last-reviewed: 2026-11-24
---

# AMBIENT-001 mission ledger

## Intake and authority

The owner authorizes an opt-in modular procedural NPC implementation on accepted
main, a single coherent Draft/HOLD PR, focused qualification and a portable
Windows evaluator where exact runtime reuse and delivery are available. No merge,
Ready transition, product default promotion or motor tuning is authorized.

- Accepted source: `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
- Working branch: `feature/ambient-001-20261124`.
- Actor Compose #762: `47e87cb84cf302b4e283cfc7e8f884e01b7b4c73`, Draft,
  unmerged and explicitly not owner accepted at intake. Read-only reference.
- Accepted capacity: eight logical actors, eight prepared parts per actor and
  64 native proxies/response bodies. Larger draft capacities are excluded.
- Retained native runtime source: `c53fd6f9d3d0f2b3f39396c7e605654f65c17299`.
  Both platform source-input ledgers match accepted main with zero differences.
  This is reuse eligibility, not new script or physical Windows qualification.
- Linux native SHA-256:
  `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`.
- Windows native SHA-256:
  `668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e`.

## Write boundaries

The lead owns narrow changes to the accepted actor catalogue, controller adapter,
session scheduler, actor panel, authored setup and shared Workbench/host hooks,
plus documentation routes and delivery tooling. The native World, Rapier bridge,
physics motors, material laws, independent candidate branches and publisher
infrastructure remain outside this implementation write set.

| Lane | Owned new paths | Review rotation |
|---|---|---|
| A | `godot/scripts/ambient/ambient_engine.gd`, `ambient_modules.gd`, engine tests and behaviour ledger | B reviews engine/state contracts |
| B | `godot/scripts/ambient/ambient_perception.gd`, `ambient_actuator.gd`, perception/physical fixtures and perception ledger | C reviews sensing/actuation |
| C | `godot/scripts/ambient/ambient_profile.gd`, `ambient_profile_editor.gd`, `ambient_examples.gd`, presets, examples, authoring tests and authoring ledger | A reviews profile/editor semantics |
| Lead | Shared integration paths, integration tests, canonical docs and packaging | Specialists review integrated source |

## Design choices

The visible **Procedural NPC / Ambient** controller uses the existing `policy`
producer and an additional `ambient` policy adapter. An optional versioned
`control.ambient` block stores the authored profile. Existing Human, Scripted,
Policy and Passive sources retain their meaning. Keeping the same producer
preserves issued observation, sequence, generation, lease and freshness checks.
Changing this choice later would require only a new authored-source mapping,
not a replacement motor or command format.

The environment consumer reads copied native material-ID publications. These
bytes are material identity, not displayed framebuffer colours. No module owns
a native World, physics object or authority to set position or velocity.

## Development implementation checkpoint — 24 November 2026

The implementation is functional in the actual ordinary Workbench, with eleven
reusable modules, six composed personality profiles, five native authored scenes,
capability-aware ground/wheel/4LY adapters and the per-actor staged editor. The
controller remains an opt-in local policy adapter. No native input, material law,
Rapier bridge, movement motor or equipment catalogue was changed.

The following are **development-source** results, before the final committed
qualification freeze. They establish narrower functionality; final exact-source
campaign and package receipts must supersede them for delivery. The specialist
ledgers retain their source hashes, commands and limits.

| Executed scope | Observed result |
|---|---|
| Pure engine, all eleven modules | 877 checks, no failures; independent per-module seed streams, hostile numeric/profile inputs, thresholds, timers, reset and deterministic repeated streams |
| Independent copied-value integration | 214 checks, no failures; perception→engine→actuator, mutation isolation, no-hit wall sentinel and module independence |
| Real bridge clock and authority | 21 checks, no failures; ten actual fixed Rapier steps produce 1/6 second regardless of requested callback delta, pause/handoff fences preserved |
| Native material perception and composed decisions | 130 checks, no failures; genuine native Oil relocation reverses steering and native Water enter/hold/release/reentry follows hysteresis |
| Actual Rapier ledge geometry | 15 checks, no failures; inside-wall queries are unavailable, distinct from a real empty drop or canvas clipping |
| Actual mounted editor | 46 checks, no failures; valid/invalid Apply, stale replacement, inspection, save/reopen, minimum/default window layout and flight effort explanation |
| Matched native/Rapier locomotion | 306 checks, no failures; three controllers × three rigs, each 240 native and 240 physical steps, 40 admitted commands per actor, zero refusals |
| Ordinary Workbench gameplay | 43 checks, no failures; live Water brush changes priority, ten-second ledge latch pauses and releases, handoff resets intent, eight actors run and deletion retires the session |
| All five ordinary examples | 121 checks, no failures; each 240 native and 240 actual Rapier steps, twenty actor instances with forty admitted decisions each and no refusals/faults |
| Existing actor catalogue | 415 checks, no failures; 59 model identities and the existing 24-body workshop remain admitted |

In the ordinary eight-actor settlement development run, all eight actors received
15 commands over 90 physical steps without a rejection. The shared 1024×512
material cache occupied 1,048,576 bytes; its one baseline ingest took 1,336 μs on
this shared host. These are measurements with instrumentation and shared-machine
contention, not release limits. Godot's static-memory counter is not total native
process RSS. The [sensor ledger](perception-ledger.md) and its compact evidence
retain controlled comparison metrics and limitations.

The matched fixture does **not** establish superior route finding: the accepted
scripted ground controllers approached the first fixed Oil point closer in that
short fixture. Ambient ground actors reacted to observed Water; the flyer did
not observe in-range Water there, so its Water avoidance is not claimed from
that run. Native material motion also changes observed target distance. Actual
body travel, requested direction and changing material targets are reported
separately.

## Independent review and repaired findings

| Finding | Resolution |
|---|---|
| Correlated seed and actor IDs could cancel under XOR | Stable separate-field seed mixing, with correlated-seed regression |
| Requested delta could exaggerate gameplay time | Count actual completed fixed Rapier steps; callback-only and large-delta regressions |
| A later old render callback could make a newer stale sensor appear fresh | Ingest the newest physics publication before decisions; monotonic owner serial/tick/revision guards |
| Different ledge modules could inherit one merged lookahead | Per-module bounded rays, with shared results only for identical parameters |
| A probe originating inside a taller block could look like a drop | Owner ray reports inside/non-support collision as unavailable |
| The existing 30-cell no-hit value could become a false obstruction | Wall threshold is strictly below that sentinel; independent regression |
| Editor inspection read the authored block instead of live diagnostics | Read copied controller diagnostics without issuing an observation |
| Same-ID World replacement could leave a stale editor transaction | Bind the draft to run and epoch as well as actor/profile identity |
| Minimum profile-window size clipped Apply and inspection | Scrollable content with real Control-layout checks at 740×480 and 1020×760 |
| The initial walkway demo did not reach its drop in four seconds | Move only the authored crawler spawn from x350 to x410 on its existing deck; actual retreat begins at physical tick31 and remains latched after four seconds |
| Delivery could trust a summary without its original receipts | Hash and verify original process logs, process receipts and rich reports; verify copied project, runtimes and exact source again before packaging |

Implementers were reviewed by other specialists. The [behaviour](behaviour-ledger.md),
[perception](perception-ledger.md) and [authoring](authoring-ledger.md) ledgers
record the rotation and individual execution scopes. Delivery verifiers have
independent temporary-file refusal tests in
[`test_ambient_delivery.py`](../../../tools/ci/test_ambient_delivery.py).

## Environment failures and remaining delivery gates

Three early ordinary-host attempts ended with process exit137 under shared host
memory pressure. One had completed the material phase and was waiting on an
incorrectly placed ledge probe; no incomplete attempt was counted as a pass.
Only this mission's temporary caches and checkout were relocated. The accepted
bounded recovery path then avoided allocating an unrelated default2048 canvas
before the test fixture; product startup was not changed. The completed ordinary
campaign passed in 32.922 seconds. A separate first example-harness attempt
waited for a physical session on an intentionally empty canvas; the harness was
corrected to wait for native acknowledgement and require an actor owner only
after loading an actor scene.

Local graphical execution is blocked: Xvfb cannot create a local display socket
under the executor's permissions, and the supplied desktop control runtime is
unavailable. No headless image or node-layout check is labelled as a rendered
screenshot. The dedicated Windows workflow uses the accepted actual ANGLE
backend, captures all five scenes plus the overlay and editor, and keeps
displayed-publication identities distinct from current physics values.

The portable evaluator tooling reuses authenticated official Godot 4.7 and the
unchanged source-matched Windows DLL. A complete committed-source campaign,
actual Windows execution, pristine extraction and graphical launch remain
delivery gates until their real receipts exist. Physical Windows/NVIDIA
playfeel and ambient believability remain owner judgements. No merge, Ready
transition or product-wide default promotion is authorized.

## Source preservation and fresh qualification

The implementation checkpoint is published in
[Draft/HOLD PR #775](https://github.com/techrote/cybersand/pull/775) at
`c63cea9ef10d21f264c9a235437f7fd40acb1072`. Every uploaded Git blob and the
complete tree were checked against the local committed checkpoint; both trees
are `5ef8fdf3009b4df72c3d1c5880166e36d6e72658`. The connected GitHub app supplied
the authenticated write path because command-line Git had no write credentials.

An executor recovery cleared the temporary `/dev/shm` area after a frozen-source
Godot import was killed. The source checkout, committed reduced measurements and
authenticated on-disk runtimes survived. Earlier raw reports stored only there
are no longer available. Their observed development results above are retained
as historical findings, but cannot substitute for original receipts in the final
package. The killed import completed no credited test cases. Fresh campaigns
now retain all logs, process receipts and reports on disk.

Independent review also found that Git normalized the trajectory CSV from CRLF
to LF while its reduced-evidence custody file still hashed the CRLF bytes. The
writer now explicitly emits LF and the custody entry hashes the actual committed
CSV. All 370 rows and 27 columns are unchanged; original run and source identities
remain intact. All four retained reduced-output hashes were rechecked.

The extended same-rig comparison uses three fresh 512×256 native Worlds and
separate Rapier spaces, identical initial material bytes and physical state,
the same Runner, authored actor identity and seed, and 300 decisions over 1,800
completed native and Rapier steps per arm. A development run completed 2,877
checks without failure. Idle Mechanic selected scheduled rest on 129 of 300
decisions, completed two five-second rest intervals and resumed nonzero intent
and normalized action. Oil Moth, Shy Crawler and Idle Mechanic travelled 443.9,
271.0 and 201.2 cells respectively; this is accumulated physical path, not net
progress or a quality ranking. Oil Moth also stalled near the inaccessible cup
on 64 of 299 measured intervals, a preserved limitation. This newly added
fixture is included in the sixteen-case final committed-source campaign; its
development run is not labelled clean-commit qualification.

## First frozen platform campaign and capture repair

At exact source `f80aab91d31ce5e753eb6056d679100d83c7b7e7`, tree
`6bafffb712441a5c03dd0b12368ac19cff374a34`, all sixteen cases passed with
5,959 assertions on both Linux and actual Windows. Both complete campaigns
passed before/after source and runtime custody. Linux took 192.615 seconds;
the Windows campaign took 151.391 seconds on its hosted runner. Independent
reviews rehashed 1,115 source inputs, 837 loaded-project inputs and the original
receipts. These timings are host observations, not platform performance claims.

Windows run
[45470109757](https://github.com/techrote/cybersand/actions/runs/45470109757)
then produced all twelve requested actual ANGLE images and completed all five
scene phases at 120 physical and at least 119 native ticks. However, the process
logged a WASAPI device-initialization error before automatically falling back to
silent audio. Although its exit code was zero and the capture fixture reported
no assertion failures, the strict process-error gate correctly rejected it.
The original failure is retained in artifact `14956927074`; package construction
and pristine execution were not credited or attempted by that run. The observed
renderer was Microsoft Basic Render Driver, not physical NVIDIA hardware.

The narrow repair explicitly selects Godot's `Dummy` audio driver for the
graphical qualification subprocess, matching an existing accepted Windows
qualification convention. Error rejection and actual renderer/source checks
remain intact. Gameplay, profiles, motors, runtimes and the ordinary interactive
launcher are unchanged. A second source-bound campaign is requested because
the capture runner itself is part of the qualified input set. Audio playback and
physical owner playfeel remain outside this capture qualification.

## Second frozen campaign and generated shader metadata

Source `38177d57d7d5dc99763f5366668890c4f53a15e6`, tree
`f00fa44682bb46318b4505700e04fee1484a0b17`, again completed all sixteen Linux
cases and 5,959 assertions with passed custody in 194.996 seconds. The independent
review confirms that every Godot input and loaded project input is identical to
the first freeze; only qualification tooling, its request marker and this ledger
changed.

Windows run
[45472012444](https://github.com/techrote/cybersand/actions/runs/45472012444)
completed its full headless campaign, actual source graphical capture, evaluator
build, pristine extraction verification, extracted gameplay/save/reopen, extracted
graphical capture and ordinary launcher. Its final post-launch integrity check
then rejected `godot/shaders/depth_composite.gdshader.uid`. The verifier already
admitted generated script UID sidecars tied to original inputs but omitted the
equivalent shader metadata. The run remains an overall failed delivery gate;
its original evidence artifact is `14957578782`, and no evaluator artifact was
published from it.

The narrow correction permits a generated `.gdshader.uid` only when its exact
corresponding `.gdshader` is an original manifest input whose bytes still pass
the existing hash check. Pristine extraction still requires the exact original
file set. Unknown shader metadata, injected shaders or scripts, and changed
original inputs remain refused; independent temporary-file tests cover these
conditions. No gameplay, shader source, native runtime, motor or launcher is
changed. The next Windows campaign qualifies the complete current source and
portable archive. The completed Linux campaign is retained with an explicit
unchanged-gameplay-input comparison instead of repeating its gameplay cases for
this package-verifier-only change.

## Final disposition — verified evaluator, Draft/HOLD

The qualified implementation is
`f4f94631d61d492554627949497e727b26043ccb`, tree
`02f22944e9de8874f97e7acdc28990e3e0c35d10`.
[Windows run 45475439737](https://github.com/techrote/cybersand/actions/runs/45475439737)
passed every step, including both previously failing delivery gates. The
complete machine-readable result and independent reviews are retained in
[`evidence/final/final-qualification.json`](evidence/final/final-qualification.json).
This closing ledger/receipt update changes documentation only; the evaluator
and execution receipts remain pinned to the implementation commit above.

| Final gate | Verified result |
|---|---|
| Windows source qualification | Sixteen cases, 5,959 assertions, zero failures; full source/runtime custody passed |
| Source Windows graphical execution | All five ordinary examples progressed; twelve actual images, including the editor and perception overlay |
| Pristine extracted gameplay/save/reopen | Five cases, 1,548 assertions, zero failures; the extracted project matches the qualified inputs |
| Extracted Windows graphical execution | A second complete five-example, twelve-image pass |
| Ordinary portable launcher | `SHARED_WORKBENCH_LAUNCH_READY`, zero exit and no error diagnostics |
| Pristine and post-launch inventory | All 1,172 original payload files match their manifest hashes; only declared generated metadata/userdata are mutable afterward |
| Independent archive audit | All 1,173 ZIP members safely and uniquely named, all payload hashes/CRC verified; exact engine/runtime/source and embedded qualification linkage |
| Delivery refusal tests | Forty-one independent methods passed, including missing/changed receipts and shader UID/source-injection boundaries |
| Linux gameplay | Sixteen cases and 5,959 assertions at `38177d57`; all 835 Godot inputs, 837 loaded project inputs and runtimes are unchanged at the final implementation, proven by the source bridge |

The actual Windows captures are 1028×578 and use ANGLE with Microsoft Basic
Render Driver. Both source and extracted sets have matched displayed actor and
material-publication identities. They establish real hosted Windows rendering;
physical Windows/NVIDIA playfeel and ambient believability remain owner
judgements. No native runtime, motor, material law, equipment implementation or
accepted host capacity was changed or promoted.

The evaluator is
`CyberSand-AMBIENT-001-Windows-f4f94631d61d.zip`, 95,212,785 bytes, SHA-256
`8324c9390565b8c1f5106f0d8ee40e5286f0bd718403b1626ac09f31b7a396ec`.
The [verified evaluator artifact](https://github.com/techrote/cybersand/actions/runs/45475439737/artifacts/14959278583)
and [original Windows evidence artifact](https://github.com/techrote/cybersand/actions/runs/45475439737/artifacts/14958974304)
retain their separate API download digests. The first two failed delivery runs
remain historical failures; neither is substituted for this completed gate.

The same-rig thirty-second comparisons preserve two complete five-second rests
and resumptions for Idle Mechanic, Shy Crawler's Water avoidance, and Oil Moth's
prolonged obstruction at an inaccessible cup. Rest is neutral intention rather
than frozen physics, nearest observed material is not guaranteed nearest material,
and the short scripted ground baseline approached the initial fixed Oil point
more closely. These results do not establish global navigation or aesthetic
superiority. The experimental feature remains opt-in, **Draft/HOLD**, unmerged
and awaiting owner acceptance.
