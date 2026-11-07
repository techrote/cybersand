---
title: WB-AGENT #527 acknowledged native Step and Stop checkpoint
status: Planned
document-kind: evidence
scope: WB-AGENT-002 isolated Step/Stop adapter; not yet integrated four-tool agent control
related-documents: [../systems/shared-workbench-agent-authoring.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/status-and-roadmap.md]
last-reviewed: 2026-11-07
---

# WB-AGENT #527 — existing shared-workbench native Step and Stop

## Qualified current behavior and isolated change

Accepted source baseline at inspection: main `81bbd5ff5cf366159e2b8a630609359c13560080` (tree `b623242a18058492b6c9ae039509374cc6e42863`). Continue the **same experimental Draft PR #530**, not a new PR or a production physics edit.

The main shared workbench already has a **human** `shared_workbench.step_once()` queue, `step_requested` / `step_pending` and post-native `workbench_step_serial` publication through its main-thread Rapier and exclusive native World owner. The new independent `godot/scripts/workbench_agent_step_sequence.gd` drives exactly one **already existing** step at a time, compares copied native completed ticks against their original identity, and waits for a matching published serial and paused owner before driving the next step. It does not create a World, scheduler, rollback, host dispatcher or model API.

`step(host,workbench,ticks,timeout_ms)` requires a paused owner with no pending step/edit or World failure, strict integer ticks 1..120 and bounded wait. A returned completed receipt contains requested/completed steps, before/after completed native tick, World generation, last native-backed step serial, reason and paused state. The public `request_stop()` prevents any further *not-yet-issued* steps; a previously issued step runs to its existing completion boundary, and Stop observes its actual ACK rather than cancelling its queue flag. `retire()` permanently fences the old object against delayed task/scene callbacks. Timeouts, identity changes, failures and ambiguous outcomes are explicit and cannot cause an automatic retry. This is an **isolated runnable driver**, not yet the fourth tool integrated with #526's authoritative session, so it cannot by itself grant agent authoring authority or prove human queued-intent protection.

No source under `simulation_worker.gd`, `workbench_authoring_session.gd`, `main.gd`, native physics/materials or GEN-006 was edited. #526 remains exclusive owner of the authoritative native observer and edits until a tested serialized source/write-set handoff. #528 retains panel/API integration.

## Real Godot/native acceptance and retained failure

The independent hosted workflow `.github/workflows/wb-agent-527-step.yml` checks out exact PR SHA, uses existing locked official Godot 4.7, current pinned Linux native/Rapier GDExtensions and actual shared workbench, executes on GitHub-hosted Ubuntu 24.04 with Xvfb/OpenGL, and retains source tree, dependency hashes, original runtime logs and a viewport screenshot when available. Reproduction:

```sh
godot --headless --path godot --editor --import --quit
xvfb-run --auto-servernum --server-args='-screen 0 1920x1080x24 -nolisten tcp' \
  godot --path godot --rendering-method gl_compatibility \
  --script res://tests/test_workbench_agent_step_sequence.gd
```

**Original RED**: [run 42380206307](https://github.com/techrote/cybersand/actions/runs/42380206307) at source `e80a4d8ce327d29b6c18f1a73a732ffc0c478b93` correctly found an error in this new Step driver. The native single-tick worker briefly publishes an unpaused transient even though the host stays paused. Treating the transient as human Play stopped a 120-step request after **106** completed steps; the reported unconfirmed outcome and original native tick 115 were retained. Corrected only in the new driver: require host pause authority throughout, and a *matching paused native publication* for the final tick ACK. No production physics change.

**GREEN**: [source-matched run 42380748835](https://github.com/techrote/cybersand/actions/runs/42380748835) at `1798dce584fda390da63d3c8d865da7a8810c78e` passed **19/19 assertions** on real native-phased World / Godot 4.7. Actual completed tick 0→128 comprised one acknowledged agent step, three more, one independent human step, a Stop at the **third** native ACK of a requested ten, and 120 further native ACKs; the World remained paused and did not run a 129th tick. Strict invalid counts refused without ticks, concurrent human step blocked agent admission, Stop no longer accepted extra steps, and cleanup stopped leaking the driver's callback reference cycle. [Original Linux logs and dependency SHA artifacts](https://github.com/techrote/cybersand/actions/runs/42380748835/artifacts/13577915922).

A later source checkpoint adds a regression for permanent task-retirement fencing and records an original graphical viewport PNG. Its own exact-head run must pass before those additional claims are promoted from **test implementation** to **qualified behavior**. A screenshot is *visual* evidence; #526 independently owns the native/render identity join. Do not mislabel a graphical CI screenshot as Windows owner acceptance.

Configured worker request shown as `0` means **Auto**, not measured parallel worker participation. Linux focused Godot execution reuses pinned LFS native binaries; general Native/GDExtension jobs intentionally remain Draft-skipped. Windows actual desktop and owner-human verdict are not qualified.

## Frozen Sand-hopper registration (unchanged)

Existing original `native/tests/fixtures/wb_agent_sand_hopper_v1.tsv` is retained with its genuine **30/32 RED**, two grains stranded. Versioned v2 [literal frozen manifest](https://github.com/techrote/cybersand/blob/f08b8ea35aa46106c04772cb2d65ea4de1ede928/native/tests/fixtures/wb_agent_sand_hopper_v2.tsv) SHA-256 `549a1db2520bcfb35f068f46b62320d7325d6297037ca2faf23c3b488d80347c` fixes just the anti-stranding ramp and already passes real C++ native `World` under 1 and 4 configured workers, actual observed participation max 1. The Normal catchment is x=10..22 / y=29..39; Revised is x=-31..-19 / y=29..39, 32 original Sand, 17 protected walls, no Sand writing, Hard Wall/Empty-only construction. The immutable **TOTAL budget is 480 actually completed native ticks per trial**; `step(120)` is only a per-call limit. See [independent native control](https://github.com/techrote/cybersand/actions/runs/42376683011).

## Open contracts and admission limits

The v1 #526 authoring contract is available on [Draft #529](https://github.com/techrote/cybersand/pull/529), with a real tested owner/viewport checkpoint; however, **exclusive write-set coordination remains outstanding** before the shared session/worker are modified or stacked with this branch. Request for precise ownership and source handoff: [#529 comment](https://github.com/techrote/cybersand/pull/529#issuecomment-6707985048). The full observe → prepare_edit → apply_edit → step transcript, Stop during an in-flight apply, manual task revision, saved authored-start reopen on the integrated branch, Windows graphical evidence and live API/owner-human tests remain **HOLD**.

#527 must integrate with #526's worker-serialized receipt and #528's exact four-tool transport, not invent a second authoring dispatcher. Do not merge/mark Ready, modify production defaults or close parent #525 on this partial control. Keep engineering/native, actual live API and human acceptance as separate gates.


## 7 November 2026 — independent actual four-tool composition and Stop at native tick boundary

The existing #527 Draft was extended **in-place** (no replacement PR) with
`godot/scripts/workbench_agent_four_tool_bridge.gd`,
`godot/tests/test_workbench_agent_four_tool_join.gd`, and
`.github/workflows/wb-agent-527-join.yml`. The source-locked CI workflow
checks out the exact #530 commit, fetches the exact #526 authoring foundation
`eab1f59418023012f79637806d20b07f23c1ebe0`, and makes a **temporary
uncommitted merge** from common accepted main
`81bbd5ff5cf366159e2b8a630609359c13560080` **only inside the Actions
worktree**. It records both SHA/tree identities and the composed tree, then
loads pinned real native/Rapier GDExtensions and Godot 4.7 OpenGL under
GitHub-hosted Ubuntu Xvfb. Neither live Draft #529 nor production native
physics is edited. The CI composed tree is **not a published integration
commit**, production merge or independent Windows qualification.

The strict fourth tool accepts only `{"ticks": integer 1..120}` and refuses
malformed, float, extra-key, zero and excess input without native ticks.
The bridge serializes all four tools through #526's single authoritative
worker-backed dispatcher for observe/prepare/apply and #527's existing
acknowledged shared-workbench one-tick path for Step. It refuses Step when a
prepared proposal is unconsumed, maintains exclusive busy state, revokes
new agent work on human Stop and emits `stop_acknowledged` only after
#526's actual native worker has retired the task. In-flight single ticks
reach their native completion boundary; no hidden scheduler, second World,
physics-default edit or task reset was added. A revised destination/task
requires a new bridge instance and fresh host authorization.

The following original red tests were retained instead of silently
discarded or rewriting the frozen fixture:

- [RED composed four-tool run 42382468988](https://github.com/techrote/cybersand/actions/runs/42382468988):
  the upstream worker increments its manual-intent revision once when the
  **agent's own** single-step is admitted through `queue_lab(step)`.
  The initial #527 code treated that attributable increment as a manual
  brush conflict and refused after 1/4 native steps. Fixed strictly in
  the #527 Step driver: exactly one revision increment **per acknowledged
  native single step** is expected, and additional user intent still
  refuses any further agent ticks.
- [RED genuine post-step render-join 42382685260](https://github.com/techrote/cybersand/actions/runs/42382685260):
  native 0→4 completed with applied nine-cell authored Wall, but a later
  native `observe` returned `pending:
  matching_post_draw_frame_not_available` even after the bounded
  wait. The same happened to a newly authorized revised task. The
  intact #526 render-identity guard correctly *refused* mismatched/stale
  pixels; it did not fabricate a current image. The exact #526 protected
  host/render repair was requested on
  [#529](https://github.com/techrote/cybersand/pull/529#issuecomment-6708371725).
  **This gate remains HOLD**, not an accepted observation.
- [GREEN four-tool native composition 42383013246](https://github.com/techrote/cybersand/actions/runs/42383013246):
  18/18 real Godot/native assertions, exact 0→4 completed ticks and native
  Stop/retirement ACK; the post-step and revised-task image join explicitly
  remained HOLD, with matching original screenshots, native/runtime receipts
  and both source identities archived in
  [artifact 13578127320](https://github.com/techrote/cybersand/actions/runs/42383013246/artifacts/13578127320).

**Latest completed exact-head checkpoint before this audit update**:
Draft #530 commit `6d9f965f8ad02de8c15d8f853b1b9d257a9fb5f8`
(tree `594108f45ad06e75544111ed62064e26ced6d99c`),
composed with the same pinned #526 source:
[PASS real four-tool composed Godot/OpenGL workflow 42383223291](https://github.com/techrote/cybersand/actions/runs/42383223291),
[original retained execution/source evidence 13578576962](https://github.com/techrote/cybersand/actions/runs/42383223291/artifacts/13578576962).
**19 assertions, zero failures** on the actual native-phased World:
host-authorized model-visible observe → prepare rectangle → apply
**9 verified Hard Wall cells** and named-start record → exact 4
native Step ACKs (completed tick **0→4**) → an additional
`step({"ticks":10})` interrupted by human Stop at its **second**
actual native ACK (completed tick **4→6**) → genuine worker
`retire_task` → Stop ACK → late apply refused → fresh revised-task
authorization. **No seventh native tick**, no synthetic native receipt.
The original post-draw image before the initial Step was matched;
post-step/revised-task frame joins stayed **honest HOLD**, with the exact
`matching_post_draw_frame_not_available` negative result separately retained.
Worker request `0` means Auto, not observed multithread participation.

At this same code head, the independently executed actual native
32-Sand v2 reference control, isolated Godot Step/Stop, docs/provenance and
native source-scope advisory **all PASS**. Standard production Native/
GDExtension, actual Windows desktop, complete end-to-end 32-Sand tool-driven
construction, API/live 3-trial validation and owner-human acceptance
remain **skipped/not executed**. The original v1 failure, v2 fixture
and 480-total-step allowance are unchanged. **Draft only; no merge/Ready.**

The minimum separate #526 dependency for full fourth-tool completion is a
source-matched post-step native/render publication whose paused completed-tick
identity can be joined to a genuine post-draw framebuffer, preserving
explicit refusal of stale images. After that isolated source owner publishes
qualified handoff, re-run this same composed regression, then integrate the
actual #526 and #527 APIs in dependency order under exclusive write-set
ownership. Do not treat this source-independent composition as a real live
OpenAI task or as frozen Sand-hopper *agent* success.
