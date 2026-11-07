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

**Isolated #526 Draft [PR #529](https://github.com/techrote/cybersand/pull/529), not accepted main:**
The pure `workbench_agent_footprint.gd` compiler validates bounded
integer geometry; `workbench_authoring_session.gd` now calls the actual
`material_at` and `emit_disc` native methods from the existing
`simulation_worker.gd` owner request loop. A separate
`workbench_authoring_render_join.gd` matches real framebuffer capture
**after** post-draw publication; it returns `pending` when no exact
world-revision/generation/tick/upload match exists. A
`workbench_authoring_start_commit.gd` adapter stages the existing
named-start representation and records it only after an actual readback.

This is real isolated **implementation source**, now exercised against pinned
Godot 4.7 and published native/Rapier libraries in GitHub-hosted Linux/Xvfb
Mesa GL. The four focused scripts passed 124 assertions on 7 November 2026;
this does **not** establish Windows qualification, independent review, final
UI/client integration, live agent trials or human acceptance. Accepted main
still has none of this #526 code. Native-only `native_observed` is **not**
a matched visual `observed`; the render join is mandatory for that claim.

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

## #526 versioned local worker contract (Draft source, focused Linux execution PASS)

**Queue-admission hardening (Draft #529):** Before copying an untrusted
Dictionary into the mutex-owned command queue,
`workbench_authoring_envelope.gd::valid` now checks exact action-specific
fields, a versioned envelope, bounded identifier lengths, at most eight
small primitive dictionaries, at most 32 protection rectangles and at most
two allowlisted material entries. Unknown/nested payloads, unsupported shapes
and non-integer coordinates are refused at admission (`-1`), before
`duplicate(true)`. The gate does not replace exclusive-owner native
validation, nor does acceptance of an envelope mean an edit was applied.
`godot/tests/test_workbench_authoring_envelope.gd` covers its permitted and
malformed inputs; 20/20 assertions passed with pinned Godot 4.7 in the
[7 November 2026 focused Linux CI](https://github.com/techrote/cybersand/actions/runs/42379815975).

The main/UI owner sends a **Godot Dictionary** to
`CyberSimulationWorker.queue_agent_authoring_command(command)`, which
returns a positive monotonic request serial or `-1` for refused admission.
Every request contains integer `schema_version: 1` and a string `action`.
`latest_agent_authoring_result(previous_serial)` returns a copied Dictionary
with `schema_version: 1`, `request_serial`, status and bounded typed values;
this atomically acknowledges its one retained result. A second request may
not overwrite an unconsumed result. No World pointer leaves the owner.

The first request is a trusted host-only `authorize_task` with
`task_id: String` (nonempty, <=128 chars), `scope: Rect2i`,
`protected: Array[Rect2i]` (<=32), `allowed_materials: Array[int]`
from **0 Empty / 58 Hard Wall**. Model calls cannot extend this authority.
The exclusive owner retains exactly one active task per World generation.
A second `authorize_task` on the **same live World** now returns
`refused: task_already_authorized` without replacing scope/protection,
allowlist, observation or a prepared proposal. An explicit host-only
`retire_task` ACK is required before authorizing a successor; a genuinely
new World generation retires stale task authority without retaining an
old proposal. This closes the cross-host task-takeover path and is
regressed by synthetic fault and actual native/host owner tests.
Source-cell allowlist also restricts changes to IDs **0 and 58**;
Sand ID 2 is never directly editable, regardless of replacement filter.

The three candidate owner actions are:

- `observe`: optional `region: Rect2i` (defaults to the task
  scope, but still must fit <=4096 cells), wholly within authorized scope;
  `detail: "cells" | "counts"` defaults to `"cells"`. Returns `native_observed` with row-major actual
  `native_material_ids: Array[int]` (empty for counts-only detail),
  native counts, the task and
  `observation_id`, plus `identity` containing World generation,
  native revision, completed tick and manual-intent revision. Its
  `image_status` is `awaiting_matched_framebuffer`; the main-thread
  `RenderJoin.join_after_draw` separately converts that to `observed`
  with PNG bytes and full render identity, or returns `pending`.
  After successful post-draw capture, the trusted host sends internal
  `confirm_observation_frame` with the same observation ID and render
  identity. The owner checks exact native generation/revision/tick and
  its mutex-latched acknowledged render serial; **prepare refuses** until
  this confirmation succeeds. This internal action is not model-accessible.
- `prepare_edit`: `observation_id: String`,
  `operations: Array[Dictionary]`, fields below. Returns `proposed`,
  `proposal_id`, identity, exact owner-read `footprint` rows
  `{x,y,before,after}`, final distinct changed count, and operation
  filter-exclusion count. It does **not** mutate. It rejects any
  unauthorized actual native source material even with a filter.
- `apply_edit`: `proposal_id: String`. Before any native write, the
  owner rereads every original cell and checks generation/tick/revision
  and queued-manual-intent. It then applies the ordered native
  zero-radius placements and verifies their actual `material_at` values.
  `applied` includes immutable `readback` with actual IDs,
  `identity_before` / `identity_after`, issued/confirmed writes,
  changed/excluded/distinct counts. A repeated consumed proposal returns
  that exact retained receipt, even after task retirement, never
  another native emission. Bounded 64 receipts; further work refuses
  before dedup evidence could be lost. Unexpected partial/readback
  mismatch is `unconfirmed` and quarantines further authoring.

Also available: host-only `retire_task` (does not erase history).
A manual brush, queued level/source event, pause transition or settings
change increments the worker-side manual-intent serial. While a native
authoring request is in flight, a competing human brush admission refuses,
rather than overtaking a readback. Host task-authoring source commits
must call `StartCommit.stage` before native `apply_edit`, then
`StartCommit.commit` only after an `applied` receipt and unchanged human
construction/manual-intent; they do not automatically save files. The
Panel/API worker must implement this handshake, including honest
`unconfirmed` if authored-start recording itself becomes unavailable.

These are typed **Godot owner adapter values**, not directly JSON-serializable
wire objects: `Rect2i` becomes an exact JSON integer
`{x,y,width,height}` object only at the future #528 API boundary.
The model sees exactly the four tools named in #525, **not**
`authorize_task`, `retire_task` or unrestricted native APIs.
The fourth `step` tool and Stop ACK remain exclusively owned by #527.
`schema_version: 1` is the supported owner-request boundary; future
incompatible contracts must use a new version.

## #526 candidate integer operation geometry

The isolated pure compiler and actual native-owner prepare path accept
arrays of literal Dictionaries with these exact integer fields. Full
#528 strict Responses JSON declarations are a separate downstream adapter.

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

The Draft owner-side code now performs current-cell read, prepare-time
counts and exclusive consume-time revision/manual-queue/reread fencing.
This is subject to source-matched test and independent review. No main-thread
World pointers, queue-only success receipts or native screenshot inference
are permitted. The existing named-start representation is staged and validated
separately before actual application and committed only after readback.

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

Focused execution targets, from a source-matched checkout with built
Godot 4/GDExtension:

```sh
godot --headless --path godot --script res://tests/test_workbench_agent_footprint.gd
godot --headless --path godot --script res://tests/test_workbench_authoring_envelope.gd
godot --headless --path godot --script res://tests/test_workbench_agent_failures.gd
godot --headless --path godot --script res://tests/test_workbench_agent_owner.gd
```

The fault-injection script uses a synthetic refusal to exercise partial
readback/quarantine/dedup semantics; it is **not** evidence that the native
solver behaves identically. The final test uses the real existing shared
workbench, worker thread,
native `material_at` / `emit_disc`, post-draw image, Sand protection,
deliberate manual-queued-intervention race, retained duplicate receipt and
named authored-start reopen, not a model/native mock.

**7 November 2026 execution checkpoint:** exact source `de036d3ac435df7ba355072932b34d5457bd9080` on existing Draft #529
(base accepted main `81bbd5ff5cf366159e2b8a630609359c13560080`).
GitHub-hosted Ubuntu 24.04, authenticated official Godot
`4.7.stable.official.5b4e0cb0f`, source-pinned Linux native GDExtension
and Rapier binaries: **focused [run 42379815975](https://github.com/techrote/cybersand/actions/runs/42379815975) PASS**.
- Pure integer footprint: **24/24**; bounded command envelope: **20/20**;
  fault-injected partial native readback/retained dedup/quarantine: **12/12**
  (synthetic failure test, not native-failure evidence).
- Real native/worker shared workbench with Linux Xvfb Mesa OpenGL: **68/68**.
  Native material IDs/counts, prepared no-write, ordered disc/line/rectangle,
  exact real native readback, protection, queued human brush conflict, duplicate
  receipt, authored-start save/reopen and matching post-draw framebuffer were
  exercised. The original PNG and paired native/render identities were
  preserved under [source-matched workflow artifact](https://github.com/techrote/cybersand/actions/runs/42379815975/artifacts/13576899035).
- Latest exact-head [documentation/provenance run](https://github.com/techrote/cybersand/actions/runs/42379815920) **PASS** and
  [native source-scope advisory](https://github.com/techrote/cybersand/actions/runs/42379815947) **PASS**.
  Repository-wide Native C++ and GDExtension matrix remain **SKIPPED** by Draft
  policy, not passed. Linux-only source/library reuse is not an exact-head
  rebuilt binary and does not establish Windows, broader regressions, independent
  review, human desktop acceptance or a working live OpenAI client.

## #526 paused-step render-publication correction (7 November 2026)

The existing worker's render exchange is **revision-driven** in ordinary
play. After a legitimate acknowledged paused `step` on an unchanged Empty
canvas, the native `tick_index` advances without a changed material revision:
an `observe` for the new tick must **not** be matched to an old framebuffer.
In Draft #529, host `_observe` detects this identity mismatch and requests
**one** bounded read-only `request_render_full_refresh()` through the
existing native-owner publishing path. The original post-draw `RenderJoin`
and worker ACK still check exact World generation, native revision, completed
tick, render publication serial and manual-intent identity. Missing, stale or
unacknowledged frames remain `pending`; there is no synthetic PNG,
physical tick, forced material revision or weakened provenance.

At code HEAD `cff5dcc59ea089bc52f65b0c23448eb4d31bab61`, exact-source
[Linux/Xvfb real native/Godot 4.7 CI](https://github.com/techrote/cybersand/actions/runs/42385630723)
**PASS**: 24 pure raster + 20 envelope + 12 synthetic failure and **111
real native/host assertions = 167/167**. The new regression performs
four independent paused real-native single steps on a 2048-square Empty
workbench, requires exactly four ACKed completed ticks and a genuinely new
post-draw PNG/render identity at the final tick, then verifies a deliberately
stale native-tick identity still refuses to join. Its [original retained
framebuffer and native receipts](https://github.com/techrote/cybersand/actions/runs/42385630723/artifacts/13579199046)
are evidence for this narrow Linux gate, **not** independent review,
Windows, a rebuilt exact-head native runtime, live API trials or a merged
feature. Current #526 source tests now also cover this #527-identified
composition blocker; full four-tool Step/Stop remains owned by #527.

## #526 main-thread host dispatcher (isolated Draft)

`godot/scripts/workbench_authoring_host.gd` is the **working non-HTTP
main-thread bridge** to the existing paused Godot simulation owner, not a new
World, physics loop or duplicate UI. Bind it once with
`bridge.bind(main)` on the existing shared workbench. A privileged human/UI
controller calls `await bridge.authorize_task(task_id, Rect2i, protected, [0,58])`
and later `await bridge.retire_task()`; these methods are **not model tools**.

Only `await bridge.call_tool("observe", args)`,
`await bridge.call_tool("prepare_edit", args)` and
`await bridge.call_tool("apply_edit", args)` are exposed by #526. `step`
is **not** implemented there: #527 owns its stopped/acknowledged native
step lifecycle. Requests travel as copied bounded values through the
existing `CyberSimulationWorker.queue_agent_authoring_command()`, with a
unique owner serial and a real owner result; they never hand a World or
mutable proposal to model/UI code. The bridge serializes a **complete**
tool call, including the asynchronous GPU render join and owner-side
confirmation, not merely each queue submission.

The bridge accepts strict Responses JSON rectangle objects with exact integer
`x,y,width,height`, or an already-validated Godot `Rect2i`. The required
model-visible `region:null` means the authorized task scope. A nullable
`replace_only_material:null` becomes **absence of the filter**, never
native material ID 0. Floats, unknown tool arguments, overflowed world
coordinates, malformed operations and unauthorized host-only commands refuse.
Observe returns the actual copied post-draw PNG and matched native IDs,
counts, palette, generation/revision/tick and render serial. The host confirms
the matched framebuffer with the owner **after capture**; pending/unconfirmed
receipts never impersonate observed image/native evidence.

On prepare, the bridge stages the exact worker-proposed footprint against
the existing named-start representation **before** native application. If
that history cannot represent the change, it refuses the prospective apply
without modifying the World. On apply, the existing worker executes and
readback-verifies the native mutation; the host commits the staged start only
after a verified receipt. A mismatch after native application returns
`unconfirmed` and quarantines the host instead of pretending rollback or
retry. Duplicate consumed proposal IDs replay retained original receipts.
A timeout or ambiguous native result likewise must never be retried
blindly. Human brush admission, manual revision and generation fences are
still enforced by the worker at exclusive consume, not by UI optimism.

The focused real-Godot owner regression now covers this **host JSON ->
native IDs/frame -> typed owner request -> authored-start commit** route,
strict float refusal, duplicate idempotence and queued human intent conflict
in addition to the direct native-owner controls. This is an **isolated Draft
engineering slice**, not a mounted #528 panel, a complete #527 Step/Stop,
an exact-head rebuilt Windows DLL/so or accepted live/human testing.

For the downstream #527 and #528 owners, the **versioned proposed strict
model-visible four-tool JSON declarations** are in
[`wb-agent-model-tools-v1.json`](../reference/wb-agent-model-tools-v1.json).
The three #526 internal worker actions and host-side strict JSON-to-Godot
translation are exercised. #528 still exclusively owns actual panel/network
wiring, strict Responses tool dispatch, PNG transport and model-facing error
presentation; it must consume this actual source-locked bridge rather than
invent a second World/controller. `step`/Stop remain #527. No consumer may
treat the declaration file or this isolated host bridge as an already mounted
four-tool API in production.

Before accepting #526, run source-exact docs/provenance/M11/retrieval,
applicable native and Godot tests, manual-intervention race/readback,
real matched framebuffer and agent-disabled regressions. Attach exact commit,
tree, native/Godot runtime hashes, OS, test command and raw failed/passed
evidence to the PR; admit official source and iterate the handoff to #527/#528.
Docs index, roadmap, handover and retrieval-manifest routes have been
updated on the Draft branch. Their CI/retrieval checks must still pass
against the exact final head before acceptance.
