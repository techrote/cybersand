---
title: Combined Gentek Windows Workbench evaluation
status: Current
document-kind: guide
scope: Draft PR 673 source-matched Windows evaluation package and eight-showcase owner walkthrough
canonical-for: [gentek-combined-workbench-evaluation]
last-reviewed: 2026-11-17
related-documents: [architectural-generator-playtest.md, gentek-showcase-integration-001.md, ../systems/architectural-generator.md]
---

# Combined Gentek Workbench evaluation

This candidate brings the **80 CLASSIC/showcase Genteks** from
[integration #671](https://github.com/techrote/cybersand/pull/671) into the ordinary
Workbench Architectural Generator on
[combined Draft #673](https://github.com/techrote/cybersand/pull/673).
The established presets remain available alongside them. **Draft / HOLD — owner
evaluation only; not approved for merge.**

The package's generated identity block at the top of `READ-ME.md` gives its exact
source commit, tree, build run, Godot version and native DLL hash.
`candidate-manifest.json` contains the complete per-file SHA-256 inventory and
build/platform metadata. `source-built-candidate-provenance.json` binds the native
DLL to its exact compiled source inputs. The ZIP filename contains the first
twelve characters of the source commit; its adjacent `.zip.sha256` file gives
the complete archive digest.

## Launch and find the eight showcases

Extract the whole ZIP into a new directory and double-click **Open Workbench.cmd**.
Keep the bundled files together. The launcher imports the packaged project once
as needed, then opens Workbench using the bundled Godot 4.7 runtime. No compiler,
build tools or separately installed Godot executable are required.

Open **New from generator… → Architectural Generator…**. The existing five style
cards contain the catalogue. Select the following names in their ordinary style
choosers:

| Display name | Native module |
| --- | --- |
| Megatruss Station | `megatruss_station` |
| Cathedral Megaframe | `cathedral_megaframe` |
| Seeded Typology Megablock | `seeded_typology_megablock` |
| Metabolist Spine | `metabolist_spine` |
| Interlaced Viaduct | `interlaced_viaduct` |
| Rosework Gatehouse | `rosework_gatehouse` |
| Interlock Brutalism | `interlock_brutalism` |
| Suspended Arcology | `suspended_arcology` |

All eight use module version **1**. Their selectors are part of the same
Architectural Generator interface as the existing catalogue. The isolated SWARM
FRAMEWEAVER, MOSAIC and RECEPTOR research programs are not Workbench style modules.

## Suggested individual evaluation

1. Start at **512 × 512**, enable one style slot, select **Cathedral Megaframe**
   and give it **100%** share. Disable the other slots. Use seed **161803** and
   turn automatic tunnels off so the underlying structure is easy to inspect.
2. Click **Generate preview**. Inspect the material output, then click
   **Install into workbench**. This replaces the current canvas; save valued
   existing work first.
3. Reopen the Architectural Generator. Change one exposed dimension, such as
   room/bay size or floor height, within its admitted range. Regenerate and
   inspect the difference. Compare the existing global aperture switches where
   applicable. A preset's material IDs and deterioration are retained with the
   style and shown in its description tooltip; this evaluation adds no separate
   editor for those fields.
4. Change the seed to **271828**, regenerate, then return to **161803** with the
   original controls. The original recipe should reconstruct the same materials.
5. Repeat with the other seven showcase names. Try a 1024-square canvas after the
   initial smoke checks if you want to inspect larger structures.

The long catalogue still uses the existing selector. No new browser or permanent
Workbench panel is introduced. Use **Stop preview** to cancel generation;
installation remains a separate explicit action after successful completion.

## Compose two different five-style maps

For a structural mixture, enable all five slots and select **Cathedral Megaframe,
Megatruss Station, Seeded Typology Megablock, Interlaced Viaduct and Suspended
Arcology**. Click **Equal shares** for 20% each, choose a seed and generate.
**Show style-zone overlay** identifies each occupied style zone separately.

For a contrasting mixture, select **Metabolist Spine, Rosework Gatehouse,
Interlock Brutalism, Seeded Typology Megablock and Suspended Arcology**. Keep five
distinct choices and use shares totalling 100%. Try another seed or a signed
negative origin through the existing controls.

Zone allocation includes empty space within a style region; shares do not measure
the amount of solid wall material. Existing transitions may clip structures or
look abrupt. Successful generation and correct style identities do not imply
seamless architecture or guaranteed navigable connections.

## Save, exit completely and reopen

Save both forms of work to evaluate the complete authoring path:

1. In Architectural Generator, use **Save…** to preserve the selected
   styles, versions, shares, seed, geometry, materials, apertures and deterioration.
2. Generate and **Install into workbench**. Keep simulation paused and add an
   obvious painted stroke plus a small erased patch. Wait for each edit to finish.
3. In the Workbench paint controls, enter a distinctive name and click **Save start
   [Ctrl+S]**. This records the generated baseline and ordered authored edits.
4. Exit every Godot window completely. Launch **Open Workbench.cmd** again.
5. Enter the saved start's name and choose **Load start**. Wait for reconstruction,
   review its preview and install if prompted. Check the original generated map
   and both edits.
6. Reopen Architectural Generator and use **Load…** to restore the saved
   authoring controls. Verify all five identities and values, then regenerate.

The project file preserves the authoring configuration. The named start preserves
the embedded native generation recipe and authored map edits. These saves describe
an authored starting map; they are not arbitrary snapshots of evolved physics.

## Qualification and known limits

The branch-scoped qualification workflow builds a fresh Windows GDExtension,
runs the focused main architectural and seven standalone showcase native suites,
validates project/schema contracts, and renders the 80 CLASSIC/showcase native
outputs plus two advanced five-style mixtures. It packages the committed source,
verifies a pristine ZIP extraction, and exercises the advanced catalogue through
graphical Workbench authoring and independent fresh-process reopening of that
extracted package. Job success and retained receipts determine what actually ran;
the presence of a ZIP alone does not establish a pass.

Automated graphical execution uses a **GitHub-hosted Windows Server VM**, with its
exact Windows build and graphics identity retained in the evidence. It is not a
physical Windows 11 session. **Physical Windows 11 usability and owner aesthetic
acceptance remain separate outstanding checks.** No merge, Ready promotion,
auto-merge, SWARM production integration, material-physics change or renderer
change is authorized by this evaluation.

The workflow retains the runnable ZIP, SHA-256, compact package identity, complete
native PNG output and graphical/process receipts as GitHub Actions artifacts.
Representative images and the final disposition belong in PR #673's conversation.
The build logs retain the exact pinned native build commands. The frozen source
relationship remains #624 → #671 → #673; #625 is the unchanged research baseline.

## Report a failure

Include the source commit from the top of `READ-ME.md`, ZIP name, Windows version,
display scaling and whether the failure happened at launch, selection, preview,
install, paint, save or fresh reopen. Attach the saved project JSON and, when
relevant, the named-start file. Record the seed and a screenshot of the controls
and visible error. Report whether repeating the same steps in a fresh process
reproduces the fault. The package inventory and retained run link allow the
reported executable and native library to be matched to the tested source.
