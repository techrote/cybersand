# ACTOR-RECOVERY-A — Mainline Reconciliation (2026-11-22)

**Status:** Draft/HOLD source-integration input only. Not runtime-qualified or approved for release.

## Authenticated inputs

- Accepted `main`: `00cdb02f103265b6dc5224c68283e9a0c8cb449f` (PR #727 merge, session-only Art JSONL logging).
- Common pre-Art/pre-Actor main: `662df51cd8409a52332fa7ef15d06d8ab8945aed`.
- Frozen Actor Compose PR #742: `3f21688be4bc8a11d9ba008a72b9aeab910bfbde`, tree `f0c1fe80bb6c36aa00bc6820899da30f7c063d8c`.
- Previously qualified application source: `62bb7383bb6fddefc1ee41db9a15cc2de43b37f4`; the frozen donor is its native-publication child.
- Protected material-source transition: `1b5001072cd703488c6c0ba566c71f12b8f21840`; must remain a commit ancestor.
- Original donor CI evidence: https://github.com/techrote/cybersand/actions/runs/45009317469 **is inherited, not validation of this merge**.

## Construction and design choices

Construct a true two-parent Git merge commit: accepted `main` as first parent, frozen Actor Compose donor as second parent. The tree is based on the frozen donor tree, with all 15 non-overlapping changed Art files copied as their **exact current-main Git blobs** (unchanged modes) and `godot/scripts/shared_workbench.gd` resolved explicitly. This retains the authenticated native transition through the second parent. No squash, replay, binary replacement or donor mutation.

The five Art-session source hunks were applied to the actor-bearing script. Four match unchanged donor context; the `_process` hunk overlaps adjacent Actor polling: retain `actor_interaction.poll()` but remove the historical Art retry loop. Remove three vestigial, unreferenced `_unopened_history_*` state declarations. The accepted session-only contract wins over the obsolete PR #742 historical-chat resumption implementation; reversing this would require an explicit new product decision and migration design.

The resulting `shared_workbench.gd` retains: Actor interaction ownership, mounting, tool selection, global/window/world input routing, grab cancellation, playground/capacity/configuration actions, saved-start and Flatten fences, retained assembly pose overrides, plus all accepted Art lazy-panel/session-only behavior. Accepted Art logging remains *in-memory per new game session* and appends audit data to a new JSONL only after actual Art activity.

## File custody

**Exact main-to-candidate Actor change-set:** 73 frozen donor-changed paths plus this dated audit file. Actor part of the change-set (the reconciled `shared_workbench.gd` has an additional Art-history cleanup):

- `.github/workflows/workbench-actor-sandbox.yml`
- `Makefile`
- `docs/README.md`
- `docs/architecture/data-ownership-and-lifetimes.md`
- `docs/architecture/shared-workbench-authoring-data.md`
- `docs/audits/2026-11-22-workbench-actor-sandbox/capacity/README.md`
- `docs/audits/2026-11-22-workbench-actor-sandbox/capacity/native-sanitized-matrix.jsonl`
- `docs/audits/2026-11-22-workbench-actor-sandbox/capacity/native-source-ledger.json`
- `docs/audits/2026-11-22-workbench-actor-sandbox/capacity/provenance.json`
- `docs/audits/2026-11-22-workbench-actor-sandbox/capacity/workbench-matrix.json`
- `docs/audits/2026-11-22-workbench-actor-sandbox/material-source-transition.md`
- `docs/operations/workbench-actor-composition.md`
- `docs/reference/configuration-reference.md`
- `docs/reference/interfaces-and-message-contracts.md`
- `docs/reference/retrieval-index.md`
- `docs/reference/retrieval-questions-workbench-actors.json`
- `docs/reference/status-and-roadmap.md`
- `docs/systems/physical-actor-rigs.md`
- `docs/systems/workbench-actor-composition.md`
- `godot/.godot/global_script_class_cache.cfg`
- `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`
- `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`
- `godot/addons/cybersand_native/runtime-provenance.json`
- `godot/addons/cybersand_native/runtime-provenance.linux.json`
- `godot/native_extension/cyber_demo_bridge.hpp`
- `godot/native_extension/cyber_native_cell_world.cpp`
- `godot/native_extension/cyber_native_cell_world.hpp`
- `godot/native_extension/cyber_prepared_liquid_world.hpp`
- `godot/native_extension/workbench_granular_coupling.inc`
- `godot/scripts/main.gd`
- `godot/scripts/physical_actor_arena.gd`
- `godot/scripts/physical_actor_effects.gd`
- `godot/scripts/physical_actor_overlay.gd`
- `godot/scripts/physical_actor_rig.gd`
- `godot/scripts/physical_actor_session.gd`
- `godot/scripts/physical_usable_runtime.gd`
- `godot/scripts/rigid_body_coupling.gd`
- `godot/scripts/shared_workbench.gd`
- `godot/scripts/simulation_worker.gd`
- `godot/scripts/usable_runtime.gd`
- `godot/scripts/workbench_actor_catalog.gd`
- `godot/scripts/workbench_actor_interaction.gd`
- `godot/scripts/workbench_actor_interaction_overlay.gd`
- `godot/scripts/workbench_actor_manipulator.gd`
- `godot/scripts/workbench_actor_panel.gd`
- `godot/scripts/workbench_actor_sandbox.gd`
- `godot/scripts/workbench_emitter.gd`
- `godot/scripts/workbench_paint_editor_controller.gd`
- `godot/scripts/workbench_physics_bridge.gd`
- `godot/scripts/workbench_sandbox_capacity.gd`
- `godot/scripts/workbench_setup.gd`
- `godot/tests/capture_workbench_actor_sandbox.gd`
- `godot/tests/test_act004_body_capacity.gd`
- `godot/tests/test_physical_actor_effect_admission.gd`
- `godot/tests/test_physical_actor_effects.gd`
- `godot/tests/test_physical_usables_admission.gd`
- `godot/tests/test_physical_usables_runtime.gd`
- `godot/tests/test_workbench_actor_capacity.gd`
- `godot/tests/test_workbench_actor_composition_native.gd`
- `godot/tests/test_workbench_actor_configuration.gd`
- `godot/tests/test_workbench_actor_configuration_native.gd`
- `godot/tests/test_workbench_actor_interaction.gd`
- `godot/tests/test_workbench_actor_manipulation.gd`
- `godot/tests/test_workbench_actor_sandbox.gd`
- `godot/tests/test_workbench_actor_topology.gd`
- `native/include/cybersand/world.hpp`
- `native/src/world.cpp`
- `native/tests/test_workbench_actor_capacity.cpp`
- `native/tests/test_world.cpp`
- `tools/ci/run_workbench_actor_qualification.py`
- `tools/ci/test_workbench_actor_publication.py`
- `tools/ci/workbench_actor_sandbox_receipts.json`
- `tools/material_catalogue/compatibility.py`

**Accepted Art changed files represented in tree (blob-exact except merged shared script):**

- `.github/workflows/art-session-logging.yml` — identical SHA to main
- `docs/audits/2026-11-22-art-session-logging/README.md` — identical SHA to main
- `docs/audits/2026-11-22-art-session-logging/legacy-tests/test_art_history_durability.gd.txt` — identical SHA to main
- `docs/audits/2026-11-22-art-session-logging/legacy-tests/test_art_lazy_traffic.gd.txt` — identical SHA to main
- `docs/audits/2026-11-22-art-session-logging/legacy-tests/test_art_traffic_panel_safety.gd.txt` — identical SHA to main
- `docs/systems/workbench-art-providers.md` — identical SHA to main
- `godot/scripts/art_batch_panel.gd` — identical SHA to main
- `godot/scripts/art_provider.gd` — identical SHA to main
- `godot/scripts/shared_workbench.gd` — reconciled
- `godot/tests/test_art_history_durability.gd` — identical SHA to main
- `godot/tests/test_art_lazy_traffic.gd` — identical SHA to main
- `godot/tests/test_art_manual_audit.gd` — identical SHA to main
- `godot/tests/test_art_session_log.gd` — identical SHA to main
- `godot/tests/test_art_traffic_panel_safety.gd` — identical SHA to main
- `godot/tools/qualify_gentek80_main_integration.gd` — identical SHA to main
- `tools/ci/run_godot_regressions.py` — identical SHA to main

**Excluded Agent B work:** `godot/scripts/workbench_actor_panel.gd` and its focused tests remain **exactly as in frozen PR #742** in this source. Agent B's future corrective commit must be integrated by the principal integrator, with independent conflict review. None of the unrelated Draft PRs #740, #724, #734, #728 or #730 was imported.

## Source-level lifecycle inspection

- Startup: initializes a `no_session` Art context without reading past transcripts; the Actor interaction helper is mounted without creating an Art provider.
- Window open/close: Art constructs lazily; Configuration is a single Actor window; opening either calls `_cancel()` and the main controller cancels live gestures through `cancel_stroke()`.
- Input: globally captures release and Escape for grabs/placement before controls; world actor handling precedes Paint; idle middle-button camera behavior remains.
- Runtime/play: Actor poll coexists with Flatten poll; independent actor processing is delegated to the existing physical session. Paint/Eraser code and panel routing are retained.
- Ownership: prepared placement checks run ID and epoch and validates retained assembly topology; Actor manipulation uses real session-owned native/Rapier proxies. No new native edits from reconciliation.
- Save/restore/Flatten: save and Flatten cancel transient grabs; retained authoring is native-prepared; restore/install of a new world follows donor's validated path. No promise to persist live ragdoll or historical Art chat.
- Shutdown/focus: Workbench shutdown cancels Actor interaction and Flatten. Main window focus-out cancels playable input and invokes Workbench `cancel_stroke`; Actor polling separately rejects stale/focus-lost owners.

These are inspected source paths, **not newly executed runtime scenarios**.

## Executed verification and limitations

- GitHub comparison checked exact source refs and the single-file overlap (16 Art paths, 73 Actor paths), verified 15 Art blob SHA/modes in nontruncated main trees, and confirmed ancestry of `1b5001072cd703488c6c0ba566c71f12b8f21840` within `3f21688be4bc8a11d9ba008a72b9aeab910bfbde`.
- Applied all **5** Art hunks with explicit adjacent-code resolution; **25/25** integration static assertions passed precommit, including absence of obsolete history code and preservation of Actor routes.
- GitHub's Git Data API creates the tree/commit; the local container cannot resolve `github.com` for `git fetch/clone`, and Godot 4.7 is not installed. Consequently **no Godot parsing, native build, live Brush/Eraser, save/reopen or runtime test has been executed on this newly combined source**. Neither original PR #742 nor #727 CI is labeled source-matched for this integration.
- Frozen donor native LFS pointers and provenance remain inherited without regeneration or a new native qualification claim.

After publishing, validate first-parent/second-parent hashes, transition ancestry, main-to-candidate delta, all Art blob identities, and preserved Agent B file blobs. Do not promote Ready or merge.

## Principal integrator handoff

Once Agent B publishes its corrective branch/commit, verify its parent/ref and exact changed paths; apply only its Actor panel and focused-test correction onto this branch (or onto a child of it), retaining the frozen Actor implementation and current Art files. Run Godot 4.7 import/parse, targeted Actor manipulation/configuration, Art session/lazy-panel/traffic, physical ownership, PAINT, persistence/Flatten and native material-guard qualification against that **new combined HEAD**. Publish source-matched Windows binaries only through principal integrator's coordinated build lane; physical owner Windows/NVIDIA playfeel acceptance is a separate release gate.
