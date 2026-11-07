---
title: Shared workbench Stage-1 agent authoring contract
status: Approved design
document-kind: contract
scope: Opt-in human plus agent authoring in the existing shared desktop workbench, WB-AGENT-000 to 003
canonical-for: [shared-workbench-agent-authoring, shared-workbench-agent-tool-contract]
keywords: [WB-AGENT, authoring, observe, prepare_edit, apply_edit, step, native receipts, human intervention, Sand hopper]
last-reviewed: 2026-11-07
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../systems/player-control-playground.md, ../reference/level-saves-and-replay.md, ../reference/interfaces-and-message-contracts.md]
---

# Shared workbench Stage-1 agent authoring contract

## Source status: what works now and what is only Approved?

**Approved / implementation in progress (7 November 2026).** The owner-approved
scope is [#525](https://github.com/techrote/cybersand/issues/525); execution
order is [#526](https://github.com/techrote/cybersand/issues/526) ->
[#527](https://github.com/techrote/cybersand/issues/527) ->
[#528](https://github.com/techrote/cybersand/issues/528). This is NOT GEN-006
world streaming, GEN-007 procedural authoring or a new game client.

Inspected accepted main `81bbd5ff5cf366159e2b8a630609359c13560080`
already exposes manual shared-workbench paint, named authored starts, identified
immutable worker snapshots and an acknowledged single-step sequence.
`shared_workbench.gd::paint` / `simulation_worker.gd::queue_emit_cells` establish
queue admission, **not** verified native application. Nothing in accepted main
proves an agent may author and inspect or that an OpenAI model has run.

**New isolated #526 source checkpoint (not accepted main):**
`godot/scripts/workbench_agent_footprint.gd` supplies a *pure* deterministic
integer-cell footprint compiler. It returns `validated_geometry` or
`refused`; it does NOT read/mutate the native World, retain prepared proposal
identity, take a framebuffer, validate current native material filters, or issue
an `applied` receipt. The focused source test is
`godot/tests/test_workbench_agent_footprint.gd`.
This checkpoint is source-only until exact-head Godot qualification is run.
Do not promote the stage from Approved to Current on the strength of this helper.

## Approved four-tool contract

| Tool | Approved result | Invariant |
|---|---|---|
| `observe(region?, detail)` | Matched real post-render framebuffer, bounded native material IDs/counts/palette, task/world/revisions/tick/render identity | Never infer a material ID from pixels; if the two publications cannot be matched, return pending/unavailable |
| `prepare_edit(observation_id, operations)` | Exact footprint and changed/excluded/conflict counts, opaque bounded proposal | No World mutation, protect task scope and actual native IDs |
| `apply_edit(proposal_id)` | Exclusive-worker native readback and retained result receipt | Revalidate source identity + intervening manual queued intent at consume time; queue accepted is NOT applied |
| `step(ticks)` | Actually acknowledged 1-120 paused ticks, completed count, before/after tick, matched fresh observation | Must remain paused, bounded and interruptible at tick boundary |

Exactly one active task, one prepared proposal and one outstanding mutation.
Each edit contains at most eight primitives and 4096 **distinct** world cells.
Each bounded native observation contains at most 4096 cells. All tighter existing
engine capacities still apply. Duplicated apply of a consumed proposal returns
its retained original receipt and NEVER replays a native mutation; once bounded
retention can no longer guarantee this, refuse new work before eviction.

A proposal binds task/session, world generation, task/scope revision, native
authoring/terrain revision, completed tick and render publication. Invalidate
for manual mutation, reset/new canvas, load/restore, changed task or material
scope, source/settings/World-owner transitions and stale queued intent. Merely
moving the camera does not stale world-coordinate geometry.

Worker statuses are `proposed`, `queued`, `applied`, `refused`,
`error`, `unconfirmed`. Validation refusal is an unchanged-world outcome.
Unknown or partially applied native results are explicitly unconfirmed/error,
retain bounded receipts where possible and follow existing quarantine;
there is no fabricated rollback, implicit retry or universal undo.

## #526 candidate integer operation geometry

The isolated pure compiler currently accepts an array of literal Dictionaries
with these exact fields; the session's final authoritative schema and JSON
serialization remain to be admitted by #526 before other workers depend on them.

- `{"shape":"disc","x":1150,"y":100,"radius":3,"material":58}`
- `{"shape":"line","x0":1150,"y0":100,"x1":1170,"y1":103,"material":58}`
- `{"shape":"rectangle","x0":1150,"y0":100,"x1":1170,"y1":103,"material":0}`

Each may contain optional integer `replace_only_material` from a trusted
native palette. Disc means every integer center-offset satisfying
`dx*dx + dy*dy <= radius*radius`; line means one-cell Bresenham; rectangle
uses inclusive endpoints, row-major (y then x). Preserve operation order and
overlapping rasters, because a later replace-only filter must inspect the
**new current native ID** after any earlier operation. Do not collapse
these into last-wins cells before native consumption. A single radius-36 disc
has 4053 integer cells; radius 37 has 4293, exceeding the bounded edit.

Coordinates are actual finite World coordinates (valid x/y can exceed 1024).
All primitive fields are checked as integers; no clipping, truncation,
silent coordinate normalization or arbitrary new fields. The pure compiler
rejects any geometry touching scope exterior or protected rectangles, unknown
replacement materials, unknown filter IDs or over-capacity footprints.
A *trusted caller* must supply native palette IDs, permitted replacements,
authorized region and protected regions. The future worker must additionally
check the actual native cell material and replacement eligibility; the helper
alone does NOT protect Sand from an Empty replacement. Authoring protection
does not arrest natural Sand/Water physics.

The native owner must perform prepare-time current-cell inspection, then recheck
the full material/geometry/scope/revisions after claiming the serialized consume
boundary. Compute exact changed/excluded counts and actual readback there;
no main-thread World pointers and no unverified brush queue receipts.

## #527 step/Stop and fixed reference control

The #527 worker owns `step`, interruption, lifecycle regressions and the
first deterministic real-native Sand-hopper acceptance. Build a small closed
hopper with **32 real Sand cells**, a shifted catchment and a protected wall
motif in the existing workbench; agent may add/erase Hard Wall and Empty
within scope but may not replace/manufacture Sand. Freeze the positive control,
both original/revised destination layouts and **TOTAL** trial tick budget
before live agent trials. A 120-step per-call cap does not authorize unlimited
total steps. Failed reference control is HOLD, not permission to tune physics.

While a proposal waits, a human edit and revised destination must invalidate
the old proposal without resetting completed work. Stop ACK follows the
current bounded worker operation/tick; delayed network callbacks are fenced.
Named-start save/reopen preserves accepted *authored construction*, not arbitrary
evolved physics state.

## #528 panel and real acceptance boundary

The #528 worker owns a small opt-in in-client panel with task/region/model,
allowed material and protection overlays, Start/Stop, proposal preview and
accurate activity. It must consume the **same** #526/#527 dispatcher.
Nonblocking application-owned OpenAI Responses requests use four strict tools,
serial dispatch (`parallel_tool_calls: false`), finite budgets, configured
vision-capable model and credentials outside source/saves/logs. The worker,
native pool and UI render loop must not wait synchronously on HTTP.

The parent maintains three distinct acceptance outcomes: (1) engineering
source-matched native/Godot tests, (2) **three predeclared actual API** Sand-hopper
trials, max one repair cycle per attempt and all attempts preserved, and
(3) the owner's own Windows graphical verdict on preview/intervention/recovery.
No paid API key in CI and no fake-provider result counts as a live model run.
If credentials or desktop are unavailable, mark live/human HOLD, not PASS.

## Validation and engineering handoff

Focused pure geometry runner, from a checkout with Godot 4 installed:

```sh
godot --headless --path godot --script res://tests/test_workbench_agent_footprint.gd
```

**7 Nov 2026 execution status:** NOT RUN in this preparation environment
(no Godot executable or container access to GitHub source). Source was
submitted as a separate Draft candidate, not installed into the client;
no native/desktop/Windows pass, exact compiled runtime identity or practical
agent outcome is claimed.

Before accepting #526, run source-exact docs/provenance/M11/retrieval,
applicable native and Godot tests, manual-intervention race/readback,
real matched framebuffer and agent-disabled regressions. Attach exact commit,
tree, native/Godot runtime hashes, OS, test command and raw failed/passed
evidence to the PR; admit official source and iterate the handoff to #527/#528.
The remaining docs navigation/retrieval/roadmap synchronization must be
completed before marking the implementation merged/accepted.
