---
title: Architectural Generator owner evaluation
status: Current
document-kind: guide
scope: Windows owner walkthrough for the source-matched Phase A and B candidate
canonical-for: [architectural-generator-owner-evaluation]
last-reviewed: 2026-11-14
related-documents: [../systems/architectural-generator.md, ../systems/explore001-generated-playable-maps.md, explore001-desktop-playtest.md]
---

# Architectural Generator — owner walkthrough

This is a **Draft/HOLD evaluation candidate**. Extract the complete Windows
package, then double-click **Open Workbench.cmd**. The package manifest records
its source commit and file hashes. Keep all bundled files together. The launcher
uses the bundled Godot/native runtime; no source compilation or manual JSON
editing is required for the ordinary workflow.

## Make the three-style map

1. Open **New from generator… → Architectural Generator…**.
2. Leave size at **1024 × 1024**, planning blocks at **64 cells**, and the three
   style shares at **45 / 30 / 25**. Set seed **161803**.
3. Turn **Automatic tunnels off**, **Automatic windows off**, and leave
   **Automatic doors on**. Click **Generate native preview**.
4. Inspect the material preview and optionally enable **Show style-zone overlay**.
   The legend must report 115 / 77 / 64 blocks, or 44.921875% / 30.078125% / 25%.
   These are zone areas including empty rooms, not amounts of wall material.
5. Open the Architectural Generator again. In the Habitation tab change bay size
   or floor height, select seed **271828**, and change shares to **40 / 35 / 25**.
   Generate another complete preview. Then try seed **314159** with the original
   shares. Layout and native room/maze detail should vary deterministically.

Industrial Service uses small maze rooms; Habitation uses larger regular floors
and bays; Overgrown / Ruined Construction uses larger interrupted architecture.
Zone edges may clip rooms. With automatic tunnels off, no connectivity of the
whole cropped map is promised. The generator supplies an editable starting map.

## Compare the independent controls

Keep the same seed, shares and dimensions when comparing a switch. Change just
one switch, regenerate, and inspect the corresponding feature:

| Change | Expected visible difference |
| --- | --- |
| Tunnels on/off | Shared macro passages cut across style boundaries only when enabled. Explicit authored routes in expert recipes remain independent. |
| Windows on/off | Arcology glass and window apertures become structural wall material when disabled. Service shafts and doors remain independently controlled. |
| Doors on/off | Vault and Arcology automatic door apertures become continuous walls when disabled. Keep tunnels off to inspect this without network cuts through the same walls. |
| Room/bay or floor dimensions | Fixed room spacing or floor separation changes across that style. |
| Shaft width 0 / nonzero | Arcology service shaft is disabled / enabled at the chosen fixed width. |

The per-style form identifies inactive Vault dimensions. Vault room sizes must
divide the map extent; 16, 32, 64 and 128 are convenient for both offered sizes.
Native validation may reject contradictory dimensions or unsupported materials.
A doorway is an empty material aperture, not an interactive door object.

## Install, paint, save and reopen

1. Click **Install into workbench** only after reviewing the completed preview.
   This explicitly replaces the current map, so save valued existing work first.
2. Keep the simulation paused. Paint an obvious rectangle or stroke in one
   material, then erase through a nearby wall. Verify both changes in the native
   Workbench view.
3. Expand **Details**, enter a distinct name and click **Save named start**.
4. Exit Godot completely. Start **Open Workbench.cmd** in a new process, enter
   the saved name and choose **Load start**.
5. Wait for reconstruction and source verification. The same generated baseline
   and the ordered paint/erase edits should reappear.

Saved maps embed the resolved native recipe. They do not require the original
style file or project JSON. They preserve an authored starting map and edits,
not an arbitrary evolved simulation state.

## Exercise recovery and custom styles

After accepting a preview, try shares that do not total 100% or a door too wide
for its floor. The error must identify the configuration problem. Use **Restore
previous preview** to recover the previous verified candidate and its settings.
Start a new preview and press **Stop preview**; the installed map must remain
intact. Changing controls must disable Install until regeneration or explicit
restoration.

Use **Save project…** and **Load project…** to retain the authoring controls.
**Import style JSON…** supports a validated declarative custom style in one slot.
The package/source examples under `examples/worldgen/architectural/` include
`custom-masonry-court.style.json`; its preset explicitly disables windows, so it
overrides the inherited global window setting. Other built-ins inherit global
apertures. Expert ordinary native recipe JSON remains available through
**Choose profile file…** in the parent generator dialog.

## Owner acceptance record

Record the package source SHA, Windows version, display scaling, renderer and
the exact seed/configuration for any fault. Check the first dialog at your normal
window size, the three toggle comparisons, visibly different style geometry,
coverage legend, regeneration, Stop/recovery, installation, real painting,
erasure and fresh-process reopen. Automated material captures do not establish
Windows graphical quality or human usability acceptance. Keep the PR Draft/HOLD
until the owner decides on integration.
