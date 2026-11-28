---
title: ObjectShard M3 continuous-play owner evaluation
status: Planned
document-kind: guide
scope: Source-bound experimental worker and Rapier rehearsal, continuous material input, diagnostics and Windows evaluator procedure
canonical-for: [objectshard-m3-owner-playtest]
last-reviewed: 2026-11-27
related-documents: [objectshard-lab-playtest.md, ../research/objectshard-m3-preflight.md, github-development-and-release.md, local-build-and-validation.md]
---

# ObjectShard M3 continuous-play evaluation

This opt-in evaluator runs **one real native World on an exclusive worker and
real Rapier physics on the main thread**. It provides continuous painting,
cutting, detachment, collision, settling and further editing. It remains a
separate-World integration rehearsal. Selecting its experimental launcher entry
does not attach ObjectShards to an already-running ordinary Workbench World.
Production defaults are unchanged and the PR stack remains **Draft / HOLD**.

## Start the delivered Windows evaluator

Extract the entire ZIP into a new writable directory. Run **Verify ObjectShard
Lab.cmd**, then **Open ObjectShard M3 Preflight.cmd**. The launchers verify the
sealed manifest, import the included source project and start the bundled Godot
4.7 runtime. No compiler or external DLL replacement is needed. Keep **Open
ObjectShard Lab.cmd** available for the preserved synchronous 001R control.

The full project's feature launcher also offers the experimental ObjectShard
entry; `--objectshard-m3` selects the same rehearsal. The package manifest binds
the source commit/tree, exact native candidate, Godot, selected Rapier, launcher,
scripts and guide. Do not modify verified files or overlay an older evaluator.
A launcher failure is evidence: retain its console message and package identity.
A successful verifier checks custody, not physical gameplay acceptance.

## First continuous loop

1. Leave **A · Ordinary detachment** selected and click **Resume**.
2. Left-drag **Erase** through the Wood support, or click **Cut lower support**.
   These are ordinary native material edits. There is no scripted rigid-body
   motion or special cut-to-physics operation.
3. Observe the structure detach and become a real Rapier body. It must disappear
   from ordinary World ownership exactly once, then fall, collide and settle.
4. Keep painting Wood, Sand or Water in the World while it moves. The semantic
   clock must continue while input is queued. Capacity and stale-target refusals
   appear explicitly; retained commands wait instead of silently vanishing.
5. Erase or inspect a moving structural cell. A cut retains the exact observed
   owner, cell, incarnation, geometry and pose identity. If that target changes
   before dispatch, the edit is refused with `TargetChanged`; make a fresh
   stroke. Painting replacement material into moving inventory is not admitted.
6. After natural sleep, click **Erode resting cell**. This removes one real
   structural cell through the same owner-aware route. It neither applies an
   impulse nor freezes the body. Continue watching for a violent late twitch.
7. Use **Pause**, **Single step**, **Resume**, **Reset** and another scenario.
   A previously admitted interval finishes coherently. Reset explicitly disposes
   the old owner before constructing another World, including when the canvas
   dimensions change.

**F2** returns to the feature launcher only after the worker disposes its native
session and main releases the physics bodies. The screen stays present during
that handoff. Repeated F2 is harmless; closing the window during the handoff
requests process exit instead. A pending Reset does not open another World after
navigation begins. If shutdown enters an explicit Held state, export evidence
and retry F2 or window close; the owner remains retained until disposal succeeds.
The launcher regains its previous window-close policy after the handoff.

**PASS:** the loop continues without duplicate material, stale colliders,
unexplained inventory loss, unintended motion bursts or a stopped advertised
clock. Legitimate component/body/geometry capacity refusal is distinct from a
fault. Ordinary small settling drift is distinct from the original violent
late rotation. Export the evidence when the distinction is unclear.

## Tools and compact configuration

Left-drag selects **Erase**, **Wood**, **Sand**, **Water**, **Fire**, **Ignite** or
**Inspect**. Right-click always inspects the actual current owner. Fast drags use
the existing four-connected cut path. Native inspection reports the material,
state, temperature and moving-cell identity; display colour is not the authority.

**Configuration** consolidates collision-shape/centre-of-mass/pocket overlays,
scenario seed, external Fire, receipt work and the delayed-receipt diagnostic. The seed applies
on the next Reset. Collision friction, damping, body slots, geometry capacity,
material laws and the admitted motion envelope retain the qualified settings.
The evaluator does not expose unqualified values as successful tuning ranges.

Continuous progression gives each completed displayed tick an input admission
window before the next interval starts. Pointer commands enter the host before
that scheduling step, so a fresh visible moving cell can be cut while the game
keeps running. Older in-flight witnesses still refuse explicitly; they are never
silently retargeted onto a newer pose.

**Receipt work** offers 0, 4, 8 and 12 ms soft loop budgets. The opt-in M3
rehearsal starts at 8 ms. Choose 0 ms for the polling control or 4 ms to
reproduce the original continuous-play test. The loop consumes worker
receipts within the current callback and checks its budget between complete
handlers. A handler already running can take it over the selected budget.
Deferred receipt notifications stay off in all four modes.
Actual pump duration and the enclosing frame callback remain visible in the
export. A positive throughput comparison does not establish real-time 60 Hz
simulation or target GPU frame rate.

**External Fire burner** repeatedly requests a visible band of genuine Fire.
The worker checks that each target is still Empty immediately before its native
edit; an occupied cell is refused rather than overwritten. Accepted fixture
Fire is counted separately from chemistry products. This supports sustained
external heating without changing ordinary Wood's weak self-sustaining burning
law. The manual Fire brush remains ordinary intentional World painting.

**Hold worker receipts** is a protocol diagnostic. Physics waits at its pending
applied acknowledgement, and the view retains the last coherent publication.
The UI and export controls remain usable. Release the hold before the 15-second
receipt deadline to continue. Once that deadline expires, the explicit Held
state retains ownership and requires Reset or Stop; releasing the checkbox
alone does not resume the retired operation. Deliberately holding a receipt
does not demonstrate physical rest or good throughput.

## Preserved scenes

All eleven 001R scenes are available in the worker screen and remain available
in the synchronous Lab. Additional fixtures are authored using bounded ordered
native edits before continuous progression begins.

| Scene | Native canvas | Main observation |
| --- | --- | --- |
| A — Ordinary detachment | 192 × 128 | Live support cut, transfer, fall and continued edits. |
| B — Burning Wood tree | 192 × 128 | Existing burn state survives transfer and continuing chemistry. |
| C — Water and Sand exchange | 192 × 128 | Real pocket capture, legitimate Sand bypass and Water exposure. |
| D — Three reacting structures | 192 × 128 | Separate owners, material changes and physical contacts. |
| E — Perforated crown | 192 × 128 | Holes and exact geometry survive detachment. |
| F — Long settling control | 192 × 128 | Natural rest, then one-cell erosion and continued play. |
| G — Main structure and offcuts | 192 × 128 | Large-component admission ahead of competing tiny fragments. |
| H — Irregular branching | 256 × 160 | Diagonal cuts and deliberate negative space. |
| I — Diagonal / multi-support cuts | 256 × 160 | One surviving genuine support preserves anchoring. |
| J — Sustained external flame | 256 × 160 | Genuine external Fire, Smoke and selected native ignition. |
| K — Extended play canvas | 320 × 192 | Repeated edits, three structures and asymmetric ledges. |

For the priority experiment, pause before cutting several supports, let pending
input drain, then Resume. This makes simultaneous eligibility explicit. A tiny
body already admitted before the main cut remains an actual material owner; it
is not silently deleted to create a slot.

In the Sand pocket experiment, most Sand may bypass the narrow accepted aperture
and reach the floor. Inspect the carried cell and cargo accounting to identify
real capture. Water remains World-owned when accepted exposure extinguishes
Wood. Internal fluid transport and unlimited cargo are not advertised.

## Diagnostics and incident export

The panel reports native/published clocks, candidate sizes and refusal reasons,
occupied slots, queued input, worker requests, physics segments, active/sleeping
bodies, geometry revisions, mass, centre of mass, chemistry accounting and
publication age. Its elapsed tick-rate display includes pauses; it is not an FPS
claim. A sleeping body and a body waiting at a receipt barrier are different
states.

**Export bug report** writes an incident JSON, flushes the prospective JSONL
trace and opens their directory. Export does not pause ordinary progression.
A protective hold also writes an incident automatically. Include the incident,
the trace path named inside it, the unchanged package manifest and a short
expected-versus-observed description. A screen recording is useful for visual
contact quality. Reports are stored under Godot user data in
`ObjectShardPreflightReports`; the footer shows the exact paths.

Reports retain the exact observed manifest hash/source, native session and
transport generation, selected preset and seed, current/pending operations,
actual physics observations, accounting, input outcomes and timing distributions.
Host p50/p95/p99/max values describe bounded rolling samples with total/retained
counts. UI input-to-host ends at queue admission. CPU texture submission is
separate from the rendered `frame_post_draw` receipt. Nested frame/host stages
must not be added together, and hosted software rendering is not target NVIDIA
performance. Headless execution cannot produce visible-frame timings.

The trace is prospective and bounded to 32 MiB / 100,000 records. Saturation is
explicit and play continues. Event/action windows and timing rings are bounded;
old session traces remain separate when resetting. UI input totals cover the
screen lifetime across resets, while native/host counters identify their own
session. An observation export is not a durable gameplay save.

## Replay and qualification boundaries

`res://tests/replay_object_shard_worker_trace.gd` reissues named material actions,
exact recorded target witnesses and completed semantic ticks through the same
worker/Rapier host. It reconstructs typed vectors and integers from JSON; it does
not remove a stale witness to make a refused action succeed. The qualifier
captures and replays an actual owner-scene sequence. The synchronous Lab replayer
refuses this host family.

This replay checks operation outcomes and completed tick order. It does not
claim cross-platform identical Rapier trajectories, a full hidden native-state
comparison, or reproduction of operating-system scheduling. A checkpoint inside
an incomplete asynchronous physics interval is retained as incident evidence
and refused as a complete replay; its event schedule can become an explicit
adverse test. To request a completed-input reproduction, Pause, allow pending
input and the admitted interval to finish, then Export. Historical owner
observation files are not retroactively called full input recordings.

Native tests, headless actual Godot/Rapier execution, rendered captures,
delivered-ZIP launch tests and physical Windows owner acceptance are separate
gates. The exact-source qualification ledger records which were actually run.
Four extraction-path tests exercise spaces, parentheses, Unicode and nested
folders; an intentionally modified member must fail for its specific hash
mismatch. No after-packaging repairs belong in the owner ZIP.

A trace also refuses standalone replay when a mutation's outcome is unknown,
its footer or checkpoint marks an incomplete prefix, or an exported native
operation is unresolved. Such files remain useful observation evidence.
The ordinary UI's Reset disposes and recreates the native registry; replay maps
only that fresh registry's session namespace while preserving every owner,
generation, pose, geometry, cell and material witness. Direct in-process
`Host.reset` preserves allocator and pose-serial history and explicitly marks
its new trace as requiring the preceding session history. The standalone driver
refuses that trace instead of inventing owner or pose mappings.

## Scope and follow-on integration

The three active-body limit, bounded local material domains and exact geometry
limits remain. Physics intervals retain the four-cell / 0.20-radian segment
bounds and at most sixteen real substeps. Capacity refusal preserves material;
a failed or inconsistent interval is held visibly. Larger fixtures do not imply
that the finisher's narrow default-canvas memory margin scales universally.

This deliverable establishes executable worker/main-thread/material/physics
interfaces and a continuous play-driven development loop. It does not implement
general fracture, recellularisation, arbitrary material cohesion, an internal
fluid solver, durable ObjectShard save/restore or area streaming. Disconnected
islands may remain one compound, labelled `split_pending`.

The ordinary Workbench native coupling roster still requires a separately
versioned mutable-geometry integration; PUBPRES owns its broader scheduling and
renderer succession. The rehearsal's narrow coherent-publication and applied
receipt contract is the integration seam. An experimental feature-launcher
entry is not ordinary Workbench World adoption. Keep the complete ObjectShard
stack Draft/HOLD until owner acceptance and an authorised mergedown satisfy the
production provenance and repository gates.
