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
