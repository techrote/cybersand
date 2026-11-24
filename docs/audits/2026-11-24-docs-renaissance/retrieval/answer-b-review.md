# Specialist B saved-context applicability review

All eleven saved post-pass1 questions and their actual top-five contexts were read. Answers were limited to those contexts before comparison with accepted source. This is an agent/editor review, not paid model evaluation or an automatic guarantee of downstream answers. B authored some current user pages; A independently reviews B claims, while C owns retrieval and this frozen input.

Results: **9 sufficient for the bounded question, 2 partial, 0 wrong-context-only cases**. DR02 requires abstention on its missing exact godot-cpp subclaim. DR01 contains a transient invalid Materials Lab wrapper command at rank4; its primary source-only answer is correct, and the page was corrected after the snapshot. These repairs do not rewrite the frozen result.

| ID | Applicability | Finding |
|---|---|---|
| DR01 | partial | Correct answer at ranks1/5, but rank4 captured an interim invalid extra-argument example for launch-desktop.cmd. The PowerShell wrapper accepts only Godot, Editor and PrintIdentityOnly, so do not copy that command. Source page corrected after this snapshot. |
| DR02 | partial | No retrieved top-five context states the bindings commit. Rank1 discusses build scripts without its required exact revision. Do not fill the missing value from model memory. |
| DR12 | sufficient | Rank2 carries old Draft/candidate metadata although the tool/control text is accepted current behavior. This metadata was corrected after the saved snapshot. |
| DR13 | sufficient | Current question answered directly at rank1. Ranks2/4 contain unrelated dated inference material and stale unmerged metadata. Rank5 names obsolete history_result rather than current native_history_action; corrected contract removes this contamination. |
| DR15 | sufficient | Canonical save page is absent, but the central negative answer and session boundary are supported. Do not turn the high-level denial into a claim about every native checkpoint format. |
| DR22 | sufficient | Rank2 directly answers. Historical scanline results and linked-segment export wording in lower-ranked provider excerpts are unrelated/obsolete and must not be generalized. They are reconciled in the current file. |
| DR23 | sufficient | Rank1 stale unmerged scope conflicts with acceptance wording, but current session-only behavior is explicit and corroborated by ranks2/4. Metadata now corrected. |
| DR24 | sufficient | No retrieved source grants blanket safety to raw/exported JSONL. Rank2 linked-segment details are stale but do not change the privacy warning. |
| DR25 | sufficient | Top result is standalone controls, but its scope plus rank4 explicitly preserve the ordinary-Workbench boundary. |
| DR34 | sufficient | The answer preserves approved intent instead of treating current absence as permanent rejection. Do not substitute real-world offline elapsed time for game time. |
| DR35 | sufficient | Do not infer a physical NVIDIA acceptance result from a script or retained package. Lower-rank owner procedure is an instruction to perform evaluation, not a result. |

## Bounded answers and source check

### DR01

I cloned CyberSand on Windows. Must I have C:/kybersand and dev.cmd before I can open the Workbench?

No. A source-only checkout supplies launch-desktop.cmd; dev.cmd and C:/kybersand belong to the separate companion workspace. Materialize the runtime and use the exact pinned Godot. Launch the project through its checked wrapper and choose the Workbench.

Source check: `tools/launch_desktop.ps1::param`, `godot/project.godot`.

### DR02

Can I use any Godot 4 build, and which godot-cpp version matches the native library?

Use the exact Godot 4.7.stable.official.5b4e0cb0f target, not an arbitrary Godot4 build. These retrieved excerpts do not state the exact godot-cpp commit; read the native dependency lock or canonical dependency table before answering that part.

Source check: `third_party/godot-runtime.lock.json`, `third_party/native-toolchain.lock.json`.

### DR12

How do I paint, erase, fill and undo in a first Workbench session?

Open the Workbench, pause, choose Paint and use Brush(B), Eraser(E/right-drag), Fill(G) and Ctrl+Z Undo. Precise shapes, Fill and history need paused state; focused text fields retain keys. Wait for native completion and stop/settle active Art before shared Undo. Simulation invalidates unsafe construction history.

Source check: `godot/scripts/workbench_paint_editor_controller.gd::key_input`, `godot/scripts/workbench_paint_editor_controller.gd::_live_brush_input`.

### DR13

An Art batch returned queued=true. May I say the cells have been applied and displayed?

No. queued is admission; executing means a worker has claimed a chunk. Wait for actual native receipts to report changed/unchanged/excluded/refused cells and any partial prefix. Neither queued nor a native applied count alone proves that a presented frame displayed the result.

Source check: `godot/scripts/simulation_worker.gd::_consume_art`, `godot/scripts/art_batch_executor.gd`, `godot/scripts/art_batch_panel.gd::history_edited`.

### DR15

Does ordinary Save restore the exact next tick, moving actors, solver queues and private Art conversation?

No. Ordinary Save is an authored-start reconstruction, not a complete evolved physical checkpoint. The provided contexts explicitly exclude last-tick continuation and restored Undo/Art session history; Art begins empty in a new game session. They do not give the full serialized-field inventory, so exact queue/actor-state details should be checked in the save contract.

Source check: `godot/scripts/shared_workbench.gd::save_setup`, `godot/scripts/workbench_setup.gd`, `godot/scripts/art_batch_panel.gd::_ensure_history_loaded`.

### DR22

Does hiding the Art window mean its request was stopped?

No. Closing the Art window hides it and keeps the Workbench session. Use Stop to cancel HTTP/capture and future turns and request native retirement; an executing slice may finish and report partial changed cells. Wait for receipts and other authoring work to settle before history actions.

Source check: `godot/scripts/art_batch_panel.gd::_ready`, `godot/scripts/art_batch_panel.gd::stop_all`.

### DR23

After accepted ART-SESSION-LOG-001, are yesterday’s Art conversation messages automatically restored on the next game launch?

No. Every new Workbench session starts with an empty Art conversation. Hiding/reopening within the same session keeps it, but new Send does not attach old archives. Nonsecret preferences may persist; older logs remain on disk for deliberate diagnosis.

Source check: `godot/scripts/art_batch_panel.gd::_ensure_history_loaded`, `godot/scripts/art_batch_panel.gd::save_profile`, `godot/tests/test_art_session_log.gd`.

### DR24

Which Art diagnostics can I attach to a public bug report without leaking prompts or credentials?

Attach a minimal synthetic reproduction with source/runtime identity, platform, steps, expected/actual result and a manually inspected/redacted error or receipt extract. Do not attach entire Art archives by default. Automatic credential redaction does not make prompts, model replies, images or arbitrary private text safe to publish.

Source check: `godot/scripts/art_provider.gd`, `godot/scripts/art_batch_panel.gd`.

### DR25

Can I paint all four Strata Theatre planes in the ordinary Shared Workbench on main?

No. Accepted Strata Theatre is a separate opt-in layered host; ordinary Workbench integration is a candidate. In the standalone host, the background remains immutable even if selected as a paint target. Its controls and layered presentation do not grant four-plane Workbench authoring.

Source check: `godot/scripts/feature_launcher.gd`, `godot/scripts/depth/depth_layer_runtime.gd`, `godot/scripts/shared_workbench.gd`.

### DR34

Are persistent areas, RAMCACHE and exact off-screen catch-up already part of ordinary accepted Workbench saves?

No. Persistent areas and bounded game-time catch-up are approved direction and separately scoped unmerged work. Current interest-region re-entry restores eligibility rather than elapsed-time catch-up; ordinary authored saves do not include a residency/cache manager or exact off-screen continuation.

Source check: `docs/decisions/2026-11-14-owner-authoring-intent.md`, `godot/scripts/workbench_setup.gd`, `docs/reference/status-and-roadmap.md`.

### DR35

Can I use the World Art viewer and large PNG captures without treating its dimensions as native playable World capacity?

Yes, within the standalone art adapter/export limits. Art input supports up to16384cells per side and16777216cells total; interactive full PNG uses50million output pixels, while explicit streamed capture allows100million and65536per output axis. These rendering limits do not qualify playable World size, physics, traversal or save/import compatibility.

Source check: `godot/tools/world_art_grid.gd`, `godot/tools/world_art_full_export.gd`, `tools/world_art_capture_support.py`, `tools/world_art_stream_png.py`.

## Follow-up

Rerun the contexts after the final document reconciliation. Check DR01 removes the invalid wrapper example and DR02 retrieves the exact dependency identity or maintains explicit abstention. Provider/PAINT stale Draft metadata and linked-archive/history_result contamination have been corrected in current files and need post-change retrieval, not a relabelled pass1 result. DR15 demonstrates that canonical-ranking misses and answer failure are different: its high-level negative is supported, but no detailed serializer inventory can be invented.
