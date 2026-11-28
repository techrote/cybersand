---
title: Persistent area RAM cache evaluation
document-kind: runbook
status: Current
canonical-for: [persistent-area-ramcache-owner-evaluation]
scope: Opt-in GEN-006 profile, native residency, deferred saving, prefetch and Windows owner observations
keywords: [GEN-006, RAM cache, hot World, asynchronous save, prefetch, Windows]
related-documents: [../systems/persistent-area-residency.md, persistent-areas-evaluation.md, ../audits/2026-11-22-gen006-ramcache.md]
last-reviewed: 2026-11-27
---

# Persistent area RAM cache evaluation

The three-area profile in [#745](https://github.com/techrote/cybersand/pull/745) extends the persistent areas in [#725](https://github.com/techrote/cybersand/pull/725).
The [original qualification](../audits/2026-11-22-gen006-ramcache.md) records its source and platform results.
The [integration record](../audits/2026-11-27-persistent-area-world-integration.md) covers the combined Workbench. Physical playfeel remains an owner assessment.

## Launch and configure

Extract the whole ZIP into a writable folder. Double-click **Open Persistent Areas.cmd**.
The package includes pinned Godot 4.7, the native DLL and Rapier. The integrated launcher stores the three areas in
`workbench/userdata/persistent-profile`. The standalone RAMCACHE evaluator uses `userdata/persistent-profile`.
Keep each evaluator with its profile. Opening a profile from an incompatible native runtime produces a refusal.
Open **RAM cache…**. Initial session settings: 512 MiB, strict durability, background saving on, prefetch off.
Read the notice before selecting **Allow travel before disk saving finishes**, then **Apply cache settings**.
A crash can lose unacknowledged RAM-only changes. The dialog also offers bounded custom budgets,
**Evict inactive safely**, **Save all areas**, **Prepare destination** and **Export diagnostics**.

## Independent indicators

HOT means an instantiated native World; WARM means validated continuation bytes needing restoration;
COLD needs a disk read and restoration. Prepared state still needs final active-owner admission.
Debt means unpaid native ticks, even for HOT areas. Dirty, saving and durably saved are independent states:
an older captured generation can finish saving while newer edits remain dirty.
Cache accounting includes native/growth, warm/authoring and speculative reservations. Essential publication
has separate bounded headroom. Process RSS also includes Godot, renderer, stacks and allocator retention.
A too-small budget pins the mandatory active World and visibly reports the excess.
The window shows HOT/WARM lookup counters and COLD misses, last observed native
container-capacity estimates, measured encoded checkpoint/authoring bytes, growth
headroom and preparation/publication reservations. Hover the summary for their scope:
lookups can include catch-up and later cancellation/refusal, so they are not successful
arrival counts. These values do not measure total process RSS or working set; the
external evaluation report measures those separately.

If a destination's publication fails after its simulation completed, validated WARM state can retain those
completed ticks while the source remains HOT. Strict mode still requires saving before activation. Retry may
read and validate storage to resolve a lost acknowledgement; it preserves the retained World and does not repeat
its simulation. The standalone evaluator supplies **Run Automated Smoke.cmd** for the original cache-disabled path
and **Run RAM Cache Smoke.cmd** for cache, deferred saving and predictive preparation.

## Owner scenarios

1. **Hot return:** Pause A, enable deferred travel and disable background saving/prefetch for measurement.
   Travel A → B → C → A → B → A. Zero-debt HOT returns should show no checkpoint read, native restoration,
   source reconstruction or synchronous flush. First/debt-bearing visits do different work.
2. **Living state:** Paint a marker and erase timber in A; run native fire. Edit B's gate and observe Water/Sand.
   Edit C and optionally Flatten its authored baseline. Return and verify destructive edits, native transformations,
   independent cameras and the flattened start. Dynamic continuation remains separate from the authored start.
3. **Pressure:** Save all, evict inactive entries and revisit WARM/COLD targets. Reduce Custom MiB and inspect
   protected dirty state, admission refusal/fallback. Restore 512 MiB. Disable retention to exercise the cold path.
4. **Deferred saving:** Enable background saving; edit/play and travel while watching dirty/saving/durable status.
   Save all and wait for acknowledgement, close normally, reopen and revisit A/B/C. Old ACKs must not overwrite RAM.
5. **Prediction:** Enable preparation. Hover an area button, move the camera toward a declared exit, or choose
   Prepare destination. Wait for inactive HOT readiness; travel and verify the prepared handle is reused.
6. **Reversal:** Indicate B, then C, then travel to B. Repeat A → B → A → B. Obsolete work must cancel/yield
   or remain safely reusable without replacing active authority, losing completed ticks or blocking hot travel.
7. **Ordinary Workbench:** Launch **Open Workbench.cmd** separately and exercise normal physics, editing and solvers.

## Time, durability and recovery

Game/Area/Debt count completed native ticks; shutdown time adds none. Simulate Ahead pays debt before future time.
Cancellation retains actual completed work and visible debt. Native ticks are indivisible; capture/restoration
add separately measured latency. Save all waits for dirty areas and their matching global clock to become durable.
Normal exit attempts that boundary and reports refusal if it cannot finish. A forced kill before publication may
lose newer RAM-only work; a lost ACK after publication is resolved by manifest validation on reopen. Corruption
never regenerates an edited seed. A failed native tick remains quarantined, not a checkpoint or successful Save.
Ordinary **Save start** keeps its authored-start meaning, distinct from the persistent profile.

If an advancement times out, use **Retry** to resolve its exact native completion. Verified partial work stays
accounted even if cancellation or a later release acknowledgement takes time. Existing debt does not become
new game time. An unresolved interval blocks another Save/travel/exit; do not interpret that refusal as lost
progress. A known failed active result can release its request while the World remains quarantined. Use the
explicit recoverable-area Save and disclosed recovery close controls to preserve healthy areas in that case.

## Automated smoke and evidence

The standalone evaluator's **Run RAM Cache Smoke.cmd** executes real graphical hot/warm travel, edits, fire, pressure, prefetch,
write-behind and a genuinely new-process reopen in a separate smoke profile. Its short sample count is functional
smoke; source-bound qualification retains the statistical campaign. **Run Automated Smoke.cmd** retains donor tests.
Export diagnostics for clocks, cache state, operations, native work, I/O and refusals. After a failure, preserve
the visible message and run **Capture Failure Evidence.cmd**. It creates a local ZIP with saves/logs,
package/runtime identity and Windows/graphics-driver information. Add a screenshot and exact control sequence.
It sends nothing automatically.

Only actor-free 512 × 512 Current/FreeMass CYPS2 continuation is admitted. Live Rapier bodies/controllers,
host equipment/sources, unpersisted queues, Wave/PressureFlow/inertial/ballistic domains, cross-area flux,
general selective chunk eviction and universal profile migration remain unsupported. Prediction uses the
editor/camera over the declared A/B/C graph, not a persistent player actor. Broader GEN-006 #194 remains unfinished.
