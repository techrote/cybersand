---
title: EXPLORE-001 generated playable starting maps
status: Current
document-kind: contract
scope: GEN-007 final play plane to existing prepared finite shared-workbench World
keywords: [EXPLORE-001, GEN-007, playable, workbench, native, map, save, reopen]
canonical-for: [generated-playable-map-admission, generated-playable-map-persistence]
last-reviewed: 2026-11-25
related-documents: [generation-workbench-2.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md]
---

# EXPLORE-001 — GEN-007 → Playable Workbench

**Current accepted implementation:** #542 merged on 9 November 2026 at
`d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. Native generated play planes can be
previewed, explicitly installed, painted, saved as authored starts and reopened
in the ordinary Shared Workbench. The [desktop walkthrough](../operations/explore001-desktop-playtest.md)
owns the practical sequence; [saving](../operations/workbench-saving.md) separates
authored reconstruction from exact evolved state.

The [8 November integration QA](../audits/2026-11-08-explore001-integration-qa.md)
retains its original candidate source/runtime and independent-review evidence.
Its repeated-preview cursor correction is in accepted source. Later catalogue,
painting and Flatten integrations do not inherit that old package's validation,
and a current source checkout still needs its matching native runtime. Merged
implementation does not prove physical owner playfeel or every export platform.

## Architectural project extension — 2026-11-14

The [Architectural Generator](architectural-generator.md) adds a focused panel
inside **New from generator**, using this same preview/install and generated-start
v1 persistence boundary. Its embedded project compiles to a schema-4 native recipe
with exact style quotas and versioned modules. No manifest migration or external
preset dependency is introduced. An invalid/cancelled replacement now retains one
prior verified preview; **Restore previous preview** explicitly restores its
matching settings before installation can resume. The [owner guide](../operations/architectural-generator-playtest.md)
provides toggle, three-style and fresh-process paint/reopen checks.

## Ordinary workbench workflow

### Standalone profile discovery repair — 2026-11-11

Current accepted packaging copies every canonical top-level JSON recipe from
`examples/worldgen` inside `godot/authoring/worldgen` as well. The existing dialog
prefers `res://authoring/worldgen`, then the checkout's sibling directory, and
deduplicates filenames. Launch working directory and Git metadata are irrelevant.
The package manifest records the exact recipe names and SHA-256 values. Missing
required GEN-007 recipes fail packaging. This is a byte-exact packaging copy,
not another authoring catalogue or profile browser.

With neither directory present/readable, Preview is disabled and the dialog
identifies the searched paths, complete-package reinstall and **Choose profile
file…** recovery. Missing or invalid selected files report their actual paths.
The chooser and saved embedded-recipe reconstruction remain available.

The original Stage-2 Windows incident was not diagnosed by inspecting the
owner's inaccessible installation; its historical cause remains limited to the
recorded evidence. The known failing configuration is retained as a fresh
non-Git fixture with both recipe directories absent. Actual discovery is tested
against the package inventory; a separate full-Workbench regression selects a
discovered Deepworks recipe, generates native terrain, paints two materials,
saves and reopens in another process. Windows graphical and source-built results
retain their original qualification scope; a dialog-instantiation pass alone
does not establish those outcomes.

Tests: `test_workbench_generator_discovery.gd`,
`test_workbench_generator_installed.gd` (`WB_GENERATOR_REOPEN=1` for the second
process), and `python3 tools/ci/test_workbench_profile_packaging.py`.

### Authoring and reopen

1. Launch the desktop feature launcher and choose **Development workbench**
   (or use the launcher's `--workbench` argument). There is no new game scene.
2. Click **New from generator…**. Choose the native GEN-007 JSON profile
   (`gen007-deepworks` is initially selected), deterministic integer seed,
   global source X/Y and a finite 512², 1024² or, where the native recipe and
   capacity admit it, 2048² local canvas.
3. Click **Generate preview**. The dialog uses the native generator, not an
   image-to-rectangle rasterizer. The progress text identifies generated native
   cells, chunk count or semantic-plane work. Only the native final **play**
   material plane enters the simulation. The other semantic planes remain
   authoring-only; scripts/fixtures/effects are not activated.
4. Inspect the material preview; **Install into workbench** confirms replacement.
   The existing starting map is preserved if generation, source checking or
   native preparation refuses. Save any unsaved current work *before* confirming
   a replacement. Close the dialog to cancel its incremental generation.
   The first popup and saved-load popup are bounded to the embedded viewport
   or native screen usable area. On smaller windows the content scrolls;
   **Install** and **Keep current map** remain outside the scrolling content.
5. Use **Place model / Place at X/Y**, the existing **Pilot** selector, **Play /
   Pause**, **Step**, free/follow/overview camera, **Brush**, and left/right
   painting/erasure. A saved start records actor spawn and the authored ordered
   brush marks, not the live evolved native state.
6. In the painting row, enter a valid name and click **Save start [Ctrl+S]**.
   The versioned generated-map manifest is saved to
   `user://workbench/setup-<name>.json`; a new name keeps an earlier start as a
   separate save. **ULTIMA candidate:** after payload validation, the shared
   writer checks the closed staging file's exact bytes before native replacement.
   A refused replacement preserves the old destination under the verified I/O
   failure model. The accepted predecessor's Godot-only writer lacks that
   guarantee. [Save-file replacement](../architecture/shared-workbench-authoring-data.md#save-file-replacement-and-failure-handling)
   owns the candidate boundary, recovery feedback and durability limits.
7. Close Godot. Start it in a **new process**, select Shared Workbench, enter
   that name and click **Load start**. The same dialog re-generates the original
   native play-plane with the saved exact recipe and verifies all source identities
   and material SHA-256. Confirm **Install into workbench** after that preview is
   ready to install the stored actors, liquid settings, ordered manual erasures
   and overpainting. It refuses incompatible revisions
   or different generated bytes **without altering the old World**.

### Coordinate/authority contract

Native GEN-007 samples in its original global coordinates. The accepted
`Rect2i(global_origin, local_extent)` is copied into the destination's
`[0,width) × [0,height)` finite World in row-major order. The native source
region must be contained within a declared semantic-plane plan when semantic
planes are present. No signed-finite-frame experiment from WB-AGENT is imported.

The GDScript dialog owns **copied proposal bytes**, a material colour preview
and source receipts, never a mutable World. The workbench sends the copied
play-plane to the **same** `CyberDemoBridge::prepare_liquid_world` via a
typed `workbench_generated` extension. Its preparation checks source-grid
length, material validity, SHA-256, dimensions, origin, receipts and ordered
edits, then applies the established material initial-state/Water rules. The
native prepared World is independently read back to match the proposed material
map before existing host/worker acknowledgment and Rapier adoption. Original
World, physics owner and actor graph are not swapped on a native refusal.

A dense generated map is **never** converted into the legacy 4096 construction
rectangles. The version-2 Setup is nested into an independent generated-start v1 manifest.
Its accepted optional actor/equipment and authoring extensions are defined by
the [shared authoring contract](../architecture/shared-workbench-authoring-data.md);
the manifest does not silently migrate to a separate setup-v3/v4 format. The generated baseline is immutable
on save; manual edits are an additional sequential authoring layer. A generated
map's **initial** material map and edits are reproducible; an evolved simulation
mid-tick is deliberately not serialized.

### Explicit first-version limits

- Finite dimension 512, 1024 or 2048 on each side (square maps in the dialog);
  nonnegative destination coordinates, bounded global source range.
- Current Workbench setup allows up to **32,768** ordered starting stamps or
  construction rectangles, subject to the 1 MiB envelope and native capability
  readback. The ordinary non-Workbench MicroScenario bound remains 4096.
  Generated baseline detail is **not** converted into those records. Native
  replay work is separately bounded to the smaller of 64×canvas cells and
  32,000,000 attempted cells. Refusal preserves the prior document.
  [Flatten / Bake History](../operations/workbench-saving.md) can explicitly
  replace construction history with a stored material baseline; it is not
  automatic compaction or exact physical-state capture.
- Source recipe document ≤1 MiB; saved manifest ≤1 MiB. Neither manifest
  includes the original million-cell material array.
- Native semantic planes other than `play` do not become physical materials.
  Routine generator creation requires no editing JSON; custom files can be
  selected with **Choose profile file…**.
- Setup-v2 names without generated manifest `format` retain their old reader.
  Material-baseline-v1 has its own reader. Old #402/#409 branch-format proposals
  are not additional current readers merely because the issue numbers appear
  in earlier integration notes.
- A 2048² chunk profile requires up to 1024 receipts at aligned 64-cell chunks;
  region/profile capacity still applies. Deepworks' declared semantic plan is
  1024², so a 2048² request is refused while preserving the installed map.
  Chunked previews now preflight the *exact* global source-chunk count, including
  unaligned origins, against the saved-map provenance limit of 1024 receipts.
  For example, a 512² request at eight-cell chunks needs 4096 receipts and is
  refused before allocating preview bytes or generating any source chunks;
  the installed native World remains unchanged. A 2048² aligned region at
  64-cell chunks fits exactly 1024 receipts, but still needs its normal
  native, memory and source admission checks.
  Source material storage is one byte per cell (4 MiB at 2048²) and the preview
  is four bytes per cell (16 MiB); prepared/old Worlds and other staging memory
  coexist. Those buffer bounds are not a total-memory or responsiveness claim.

<a id="qualification-commands-run-against-a-source-matched-rebuilt-native-runtime"></a>

## Qualification commands (run against a **source-matched** native runtime)

Run from the selected current source with the exact pinned Godot, godot-cpp
and Rapier identities and a source-matched materialized or rebuilt native
extension. Follow [local validation](../operations/local-build-and-validation.md)
for isolated profiles, import and provenance checks. An old candidate branch is
not required to use the accepted feature. A library whose source-input hashes
do not match cannot qualify these native interfaces. Use the same disposable
profile for both processes of a save/reopen pair, separate from valued saves.

Linux (in a suitable graphical environment):

```bash
godot --path godot --script res://tests/test_explore001_generated_workbench.gd
CYBERSAND_EXPLORE_REOPEN=1 godot --path godot --script res://tests/test_explore001_generated_workbench.gd
godot --headless --path godot --script res://tests/test_workbench_canvas.gd
godot --headless --path godot --script res://tests/test_worldgen_planes.gd
```

PowerShell (replace the executable with the pinned Godot 4.7 console binary):

```powershell
$godot = 'C:\\path\\to\\Godot_v4.7-stable_win64_console.exe'
& $godot --path .\\godot --script res://tests/test_explore001_generated_workbench.gd
$env:CYBERSAND_EXPLORE_REOPEN='1'
& $godot --path .\\godot --script res://tests/test_explore001_generated_workbench.gd
Remove-Item Env:\\CYBERSAND_EXPLORE_REOPEN
& $godot --path .\\godot -- --workbench
```

The first test process writes the named map to Godot's `user://` directory.
The second checks reconstruction from the fresh process, after engine teardown.
For original renderer frames, set `CYBERSAND_EXPLORE_CAPTURE` to an output
directory. Keep that directory, native logs, runtime hashes and source commit
with the PR evidence. The script performs direct play-plane readback, actual
shared-owner installation, native ticks, a selected flyer, brush/erase,
native failure refusals and save/reopen. A human desktop session must separately
check movement feel, camera, collisions and physical traversal.

The ordinary regression planner discovers the self-contained generated-map test;
the source-built qualification workflows additionally execute its fresh-process
phase using `CYBERSAND_EXPLORE_REOPEN=1`. Temporary admission/reopen diagnostics
and old-artifact Windows replay have been retired; their source and first-failure
logs remain historical evidence. The Windows source-built workflow retains a
pristine desktop bundle with `Open Workbench.cmd` and a complete payload manifest.

The six `test_explore001_dialog*_render.gd` cases are independent fresh-process
graphical regressions for embedded/native first-open geometry, 1280×720 and
1920×1080 parent windows, first saved-load opening, resizing and content scrolling.
They check both action buttons and retain original frames. Native windows use
the real display's usable bounds; a smaller parent is not a simulated smaller
physical monitor. These are geometry tests, not human camera/traversal acceptance.

## Protected-source integration

The owner-approved [shared authoring data and convergence contract](../architecture/shared-workbench-authoring-data.md)
owns the common boundary. #542 is merged; its old one-task Ready authorization,
merge hold and lists of then-active branches are preserved in the
[source-pinned previous contract](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/systems/explore001-generated-playable-maps.md).
They do not authorize today's PR or keep this accepted feature permanently Draft.

Generated-map admission uses the prepared native constructor and shared host.
It does not grant a separate signed-frame adapter, live agent access to World,
arbitrary new material schema or import of an unmerged candidate. Consult the
[current register](../reference/status-and-roadmap.md) for active ownership and
[source leases/release procedure](../operations/github-development-and-release.md)
before publishing a later change. Skipped native/Godot jobs remain a qualification
limit, never a passing result.
