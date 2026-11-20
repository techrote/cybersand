---
title: GENTEK-80-INTEGRATION-001 source reconciliation and qualification
status: Draft
document-kind: research
scope: Candidate integration of repaired 72 CLASSIC and eight showcase Genteks on accepted main; no merge or platform acceptance claim
canonical-for: []
last-reviewed: 2026-11-20
related-documents: [../systems/architectural-generator.md, gentek-classic-001.md, ../operations/gentek-showcase-integration-001.md, ../operations/architectural-generator-playtest.md]
---

# GENTEK-80-INTEGRATION-001

**Draft / HOLD integration candidate.** This source reconciliation combines the
owner-authoritative repaired CLASSIC implementation with the eight existing
advanced showcase implementations and six deliberate review repairs, using the accepted Architectural Generator
entry point. No merge, Ready promotion, auto-merge or Windows owner acceptance
is implied by this document.

The delivery set contains **80 distinct Genteks: 72 CLASSIC and eight showcases**.
The 13 previously accepted built-in styles remain available, giving 93 selectable
presets in total. The native catalogue has 91 explicit module/version entries:
80 new v1 Genteks plus 11 retained native module/version identities. These are
different inventories; none is silently substituted for another.

## Exact starting sources and authority

| Source | Exact immutable commit | Authority in this candidate |
| --- | --- | --- |
| Accepted main | `de109d0131641d6adc8d25bb9ced7ca3d4991105` | Base for the fresh integration branch |
| Repaired CLASSIC #624 | `e27ff75758ef51c7b7c8b4d8a7093343cc2ecede` | Authoritative base for all 72 CLASSIC samplers and the four completed repair areas; six subsequent review repairs are explicitly recorded below |
| Showcase integration #671 | `eb786d97a769f4fed9f5d52bb0b50dd60f0ee16f` | Principal source for all eight advanced showcase samplers and integrated registrations |
| Historical CLASSIC parent | `615828b28337f85e4663e03ba479616db4ddf764` | Read-only comparison source for original showcases; superseded for the CLASSIC implementation |

The accepted-main commit is already an ancestor of repaired #624. The integration
therefore imports the scoped main-to-#624 delta and then reconciles the
frozen-parent-to-#671 delta. It does not merge donor branch histories or copy the
older showcase copy of CLASSIC over the repaired authoritative implementation.

## Donor-by-donor reconciliation

Every added path from each individual showcase donor already exists in #671 with
an identical Git blob identity. The shared requirements file appears in multiple
donors; there are 550 unique added donor files overall. No additional individual
donor implementation import was needed.

| Donor | Module | Fresh exact donor HEAD | Added paths identical in #671 | Additional donor import |
| --- | --- | --- | ---: | --- |
| #663 | `megatruss_station` | `2d3da36566de5dfa60a82aa642525961c90a6672` | 50/50 | None |
| #664 | `cathedral_megaframe` | `f99583cde1db2abd8384cc89eb7bda3151bbe726` | 29/29 | None |
| #665 | `seeded_typology_megablock` | `d366894c005208887a6e5ae238d7cdb1983e0a02` | 86/86 | None |
| #666 | `metabolist_spine` | `ef42af3d2f4210b1b53cfdc0e7d7bf77ff863304` | 86/86 | None |
| #667 | `interlaced_viaduct` | `965729b5b2773587d0c40e836b8f2848b1026e8b` | 58/58 | None |
| #668 | `rosework_gatehouse` | `b01c300ac64993693e8b66f1b523e3f9dfa3baf1` | 57/57 | None |
| #669 | `interlock_brutalism` | `ca8aba9c638d1c63d79bd3335a55f9ca55d81d49` | 95/95 | None |
| #670 | `suspended_arcology` | `01425a9a1aab6e01b88266a58b8b738ded38a28e` | 94/94 | None |

The [machine-readable inventory](../images/gentek-80/source-reconciliation.json)
records each preset's exact Git blob, SHA-256, native definition/class, donor,
material roles and geometry defaults. Historical source-specific PNGs and
qualification receipts remain attributed to their original source commits;
they are not relabelled as new integrated-source execution evidence.

## Repairs and shared-path decisions

| Area | Reconciliation |
| --- | --- |
| Suspended Deck | Retain #624's `fy >= wall` hanger start. Both full-width hangers now touch the carrier deck; signed-origin and repeated-bay regressions remain. |
| Rib Vault | Retain #624's slope-dependent rib stroke, including matching glazing clearance. The eight dimension/thickness cases, cardinal-connectivity proof, unchanged 80×80 defaults and independent shaft-cut regressions remain. |
| Native catalogue and registration | Preserve all 72 repaired v1 definitions and add each showcase v1 once. Schema 4 remains required; the original module versions remain registered. |
| Godot project contract | Preserve #624's independent expected-ID/schema inventory and extend it by eight explicit showcase IDs. Reject missing, duplicate and unexpected module/version entries; expect 91 native entries. |
| Native regression oracle | Retain independent repaired-#624 receipts, then separately prove the six intentional review repairs against frozen before/after native snapshots. The other 66 CLASSIC streams remain exact. |
| Gallery tests | Retain both repair witnesses and the 80-style/mixed-showcase gallery cases. |
| Documentation registration | Preserve every current-main/#624 retrieval route and add the nine new showcase exclusions. The combined excluded list has 133 entries at reconciliation. Preserve the main Wave documentation section alongside the added Gentek section. |
| Makefile and CI inventory | Retain accepted-main rules; add seven focused showcase targets and sanitizer targets. Cathedral remains in the main generation suite. Extend the exact dry-run inventory from nine to sixteen binaries without changing the original nine flags/order; thirteen adverse-control tests pass. |
| Compiler-cache tooling | The recorded #667 reuse defect requires the integration's dedicated compiler-identity repair and renewed cross-compiler parity evidence. Historical green results alone do not close it. |

Actual overlapping delta paths were `Makefile`, `docs/README.md`,
`docs/reference/retrieval-corpus.json`, `docs/reference/retrieval-index.md`,
`docs/reference/status-and-roadmap.md`,
`godot/tests/test_architectural_generator.gd`,
`godot/tests/test_architectural_project_contract.gd`,
`native/src/generation_architecture_classic.inc`, and
`native/tests/test_world_generation.cpp`. Three-way application exposed textual
conflicts in the documentation README/retrieval manifest and the three test
files; all were reconciled explicitly.

### Independent repaired-CLASSIC oracle

The [oracle receipt](../images/gentek-80/classic-repaired-oracle.json) binds 67
separately extracted native files to repaired #624 and the retained
[driver](../images/gentek-80/classic-repaired-oracle.cpp). GCC 14.2.0 executed the
existing 72-module, four-chunk corpus with uint16 little-endian FNV-1a material
digests. The source was isolated from the integration worktree.

- Repaired authoritative source: `e27ff75758ef51c7b7c8b4d8a7093343cc2ecede`.
- Independently measured combined digest: `0x05f6a65ee35bd721`.
- Historical pre-repair digest: `0x4a92810d575d9201`.
- All 72 per-module digests, exact input hashes and driver/executable hashes are
  retained in the receipt.

The original combined digest was intentionally invalidated by the Suspended
Deck contact repair. This was the integration's repaired-source equality gate
before the subsequent review repairs described below. The receipt remains
historical and unchanged. The separate Arched Viaduct v1/v2 hashes remain unchanged.

The first integrated native run also rejected Megablock's embedded pre-repair
full-map oracle. A second [independent recapture](../images/gentek-80/megablock-repaired-parent-oracle.json)
executed all 148 original profiles against isolated repaired #624. Exactly 146
profiles were unchanged; only the two Suspended Deck profiles differed. Their
new FNV values are `0x795689b7e65d92d9` and `0x16a99ea301c8d325`. The test now checks
those independently captured values at initial reconciliation. Both the initial
rejection and that repair remain recorded. The later reviewed geometry changes
use their own differential receipt and retain every original test profile.

### Intentional review repairs and differential admission

Independent review and the rendered campaign exposed six remaining structural
or glazing defects. These are intentional integration changes on top of the
authoritative repaired #624 source, rather than an unnoticed replacement with
the older showcase copy. All 66 other CLASSIC class bodies are unchanged. The
original Suspended Deck hanger contacts, Rib Vault slope/clearance fix,
catalogue/CI registration and documentation registration remain preserved.

| Gentek | Review defect | Scoped repair and preserved intent |
| --- | --- | --- |
| Ring Pier | The diamond floated between the two decks. | Add centred stems outside the diamond. Preserve every original ring/accent cell and the entire central void. |
| Tripod Frame | Repeated tripods had isolated tiers and steep thin legs could separate by a cell. | Join the feet with a lower transfer deck, add a short upper neck and use a slope-aware leg stroke. Retain the compact crown and three splayed legs. |
| Cascade Terrace | Staggered downstands missed the next terrace, leaving disconnected groups. | Add a continuous rear core after the original deck/downstand branches. Preserve every original cell and the stepped leading edges. |
| Scalloped Vault | Thin steep quadratic scallops had real gaps between column bands. | Widen only where the adjacent quadratic rise requires contact. Preserve all original structure and the repeated scalloped silhouette. |
| Suspended Deck | The lower glass rectangle was isolated from the structure. | Add thin jambs and a frame outside the existing glass rectangle, attached to the supported lower deck. Every original glass and structural cell remains unchanged. |
| Buttress Wall | The central light slot floated between the buttresses. | Add thin framing outside the unchanged pane and carry the jambs to the base. No glass overlays a solid pillar. |

The new [differential oracle receipt](../images/gentek-80/classic-review-repair-oracle.json),
[black-box native capture driver](../images/gentek-80/classic-review-repair-oracle.cpp),
[independent checker](../images/gentek-80/classic-review-repair-check.py) and
[complete compressed raw captures](../images/gentek-80/classic-review-repair-captures.zip)
record both source snapshots. The baseline uses the original 67 extracted e27
inputs; the candidate uses 74 inputs with the six repairs and already reconciled
showcases. Its CLASSIC include SHA-256 is
`ae2ce0a5540619d3d81dfb6f6d075d11c13822d36d8e2848047adcf238937c6a`.
The recorded HEAD at capture is expressly a pre-repair commit with a native
delta; the receipt does not mislabel that HEAD as containing these changes.

Independent GCC 14.2 execution established:

- Exactly six of the 72 original material streams changed; the other 66 remain
  identical to repaired #624. The new combined FNV-1a is `0xe0aec65cb4c2b5f1`.
  Both prior digests and all old/new per-module values remain in their receipts.
- Exactly ten of Megablock's 148 full-map profiles changed. Only those ten
  literals were updated; the other 138 and all original profile definitions remain.
  Disabling windows preserves the original Suspended Deck and Buttress Wall maps.
- All 192 contact cases passed: six styles, eight admitted dimension/thickness
  combinations, two signed origins and windows on/off, each spanning two bays
  and two floors. Every original occupied cell remains occupied and every glass
  cell retains its exact material. All final structures are cardinally connected;
  148 baseline cases had multiple components. The corpus includes 256×16 and
  16×256 bays/floors with one-cell walls.
- The independent three-profile native corpus retains exact bytes for all
  unchanged modules, including Arched Viaduct v1/v2. Repaired styles retain recipe
  fingerprints and fixed pre/post material SHA-256 values. All six showcase
  qualifiers use this narrow comparison; none changes its parent to the candidate
  or skips repaired styles. Rosework's distinct 100/119/55/119 material palette
  has its own independent pre/post capture; the other five use 58/62/121/65.
  Both existing 72/74 snapshot encodings remain explicit. Sixteen adverse controls reject unreviewed changes,
  wrong repaired output, wrong baseline, reverted repairs and stale native hashes.
  The four qualifier source-integrity suites pass 36 tests, including altered
  repair-oracle rejection.

The independent checker compares raw material maps and connectivity; it does
not reproduce the sampler formulas. The new contact tests and full native suite
must still pass on the final qualified source. Earlier green execution remains
attributed to its original input identities.

## Complete 80-entry provenance catalogue

Every row uses native module version 1 under recipe schema 4. `CLASSIC #624`
means the repaired source above; `+ review repair` identifies the six deliberate
changes just described; `Showcase #671 ← #N` means the principal
aggregation with the original donor identity preserved. All 80 standalone style
dictionaries exactly match their corresponding parsed built-in preset dictionaries.
Both routes use the ordinary Architectural Generator project compiler.

| Name | Stable module identity | Authority | Standalone style |
| --- | --- | --- | --- |
| A-Frame Hall | `a_frame_hall` | CLASSIC #624 | [a-frame-hall](../../examples/worldgen/architectural/a-frame-hall.style.json) |
| Barrel Arcade | `barrel_arcade` | CLASSIC #624 | [barrel-arcade](../../examples/worldgen/architectural/barrel-arcade.style.json) |
| Basilica | `basilica` | CLASSIC #624 | [basilica](../../examples/worldgen/architectural/basilica.style.json) |
| Bowstring Truss | `bowstring_truss` | CLASSIC #624 | [bowstring-truss](../../examples/worldgen/architectural/bowstring-truss.style.json) |
| Bridgehouse | `bridgehouse` | CLASSIC #624 | [bridgehouse](../../examples/worldgen/architectural/bridgehouse.style.json) |
| Butterfly Hall | `butterfly_hall` | CLASSIC #624 | [butterfly-hall](../../examples/worldgen/architectural/butterfly-hall.style.json) |
| Buttress Crown | `buttress_crown` | CLASSIC #624 | [buttress-crown](../../examples/worldgen/architectural/buttress-crown.style.json) |
| Buttress Wall | `buttress_wall` | CLASSIC #624 + review repair | [buttress-wall](../../examples/worldgen/architectural/buttress-wall.style.json) |
| Cable Gallery | `cable_gallery` | CLASSIC #624 | [cable-gallery](../../examples/worldgen/architectural/cable-gallery.style.json) |
| Cantilever Spine | `cantilever_spine` | CLASSIC #624 | [cantilever-spine](../../examples/worldgen/architectural/cantilever-spine.style.json) |
| Cascade Terrace | `cascade_terrace` | CLASSIC #624 + review repair | [cascade-terrace](../../examples/worldgen/architectural/cascade-terrace.style.json) |
| Chain Vault | `chain_vault` | CLASSIC #624 | [chain-vault](../../examples/worldgen/architectural/chain-vault.style.json) |
| Chevron Hall | `chevron_hall` | CLASSIC #624 | [chevron-hall](../../examples/worldgen/architectural/chevron-hall.style.json) |
| Clerestory Hall | `clerestory_hall` | CLASSIC #624 | [clerestory-hall](../../examples/worldgen/architectural/clerestory-hall.style.json) |
| Colonnade | `colonnade` | CLASSIC #624 | [colonnade](../../examples/worldgen/architectural/colonnade.style.json) |
| Corbel Arcade | `corbel_arcade` | CLASSIC #624 | [corbel-arcade](../../examples/worldgen/architectural/corbel-arcade.style.json) |
| Cranked Beam | `cranked_beam` | CLASSIC #624 | [cranked-beam](../../examples/worldgen/architectural/cranked-beam.style.json) |
| Crenellated Bridge | `crenellated_bridge` | CLASSIC #624 | [crenellated-bridge](../../examples/worldgen/architectural/crenellated-bridge.style.json) |
| Crossbeam Stack | `crossbeam_stack` | CLASSIC #624 | [crossbeam-stack](../../examples/worldgen/architectural/crossbeam-stack.style.json) |
| Crown Bridge | `crown_bridge` | CLASSIC #624 | [crown-bridge](../../examples/worldgen/architectural/crown-bridge.style.json) |
| Diamond Truss | `diamond_truss` | CLASSIC #624 | [diamond-truss](../../examples/worldgen/architectural/diamond-truss.style.json) |
| Double Cantilever | `double_cantilever` | CLASSIC #624 | [double-cantilever](../../examples/worldgen/architectural/double-cantilever.style.json) |
| Drum Vault | `drum_vault` | CLASSIC #624 | [drum-vault](../../examples/worldgen/architectural/drum-vault.style.json) |
| Fan Truss | `fan_truss` | CLASSIC #624 | [fan-truss](../../examples/worldgen/architectural/fan-truss.style.json) |
| Flying Buttress | `flying_buttress` | CLASSIC #624 | [flying-buttress](../../examples/worldgen/architectural/flying-buttress.style.json) |
| Folded Plate Hall | `folded_plate_hall` | CLASSIC #624 | [folded-plate-hall](../../examples/worldgen/architectural/folded-plate-hall.style.json) |
| Forked Gantry | `forked_gantry` | CLASSIC #624 | [forked-gantry](../../examples/worldgen/architectural/forked-gantry.style.json) |
| Hanging Arcade | `hanging_arcade` | CLASSIC #624 | [hanging-arcade](../../examples/worldgen/architectural/hanging-arcade.style.json) |
| Harp Bridge | `harp_bridge` | CLASSIC #624 | [harp-bridge](../../examples/worldgen/architectural/harp-bridge.style.json) |
| Hourglass Pier | `hourglass_pier` | CLASSIC #624 | [hourglass-pier](../../examples/worldgen/architectural/hourglass-pier.style.json) |
| Inverted Arch | `inverted_arch` | CLASSIC #624 | [inverted-arch](../../examples/worldgen/architectural/inverted-arch.style.json) |
| Inverted Trestle | `inverted_trestle` | CLASSIC #624 | [inverted-trestle](../../examples/worldgen/architectural/inverted-trestle.style.json) |
| Kingpost Frame | `kingpost_frame` | CLASSIC #624 | [kingpost-frame](../../examples/worldgen/architectural/kingpost-frame.style.json) |
| Ladder Bridge | `ladder_bridge` | CLASSIC #624 | [ladder-bridge](../../examples/worldgen/architectural/ladder-bridge.style.json) |
| Lantern Tower | `lantern_tower` | CLASSIC #624 | [lantern-tower](../../examples/worldgen/architectural/lantern-tower.style.json) |
| Lattice Tower | `lattice_tower` | CLASSIC #624 | [lattice-tower](../../examples/worldgen/architectural/lattice-tower.style.json) |
| Lenticular Bridge | `lenticular_bridge` | CLASSIC #624 | [lenticular-bridge](../../examples/worldgen/architectural/lenticular-bridge.style.json) |
| Monopod Tower | `monopod_tower` | CLASSIC #624 | [monopod-tower](../../examples/worldgen/architectural/monopod-tower.style.json) |
| Mushroom Deck | `mushroom_deck` | CLASSIC #624 | [mushroom-deck](../../examples/worldgen/architectural/mushroom-deck.style.json) |
| Nested Arcade | `nested_arcade` | CLASSIC #624 | [nested-arcade](../../examples/worldgen/architectural/nested-arcade.style.json) |
| Offset Arcade | `offset_arcade` | CLASSIC #624 | [offset-arcade](../../examples/worldgen/architectural/offset-arcade.style.json) |
| Pointed Arcade | `pointed_arcade` | CLASSIC #624 | [pointed-arcade](../../examples/worldgen/architectural/pointed-arcade.style.json) |
| Portal Frame | `portal_frame` | CLASSIC #624 | [portal-frame](../../examples/worldgen/architectural/portal-frame.style.json) |
| Pratt Truss | `pratt_truss` | CLASSIC #624 | [pratt-truss](../../examples/worldgen/architectural/pratt-truss.style.json) |
| Pyramidal Frame | `pyramidal_frame` | CLASSIC #624 | [pyramidal-frame](../../examples/worldgen/architectural/pyramidal-frame.style.json) |
| Queenpost Frame | `queenpost_frame` | CLASSIC #624 | [queenpost-frame](../../examples/worldgen/architectural/queenpost-frame.style.json) |
| Radial Stay Bridge | `radial_stay_bridge` | CLASSIC #624 | [radial-stay-bridge](../../examples/worldgen/architectural/radial-stay-bridge.style.json) |
| Rib Vault | `rib_vault` | CLASSIC #624 | [rib-vault](../../examples/worldgen/architectural/rib-vault.style.json) |
| Ring Pier | `ring_pier` | CLASSIC #624 + review repair | [ring-pier](../../examples/worldgen/architectural/ring-pier.style.json) |
| Sawtooth Gallery | `sawtooth_gallery` | CLASSIC #624 | [sawtooth-gallery](../../examples/worldgen/architectural/sawtooth-gallery.style.json) |
| Scalloped Vault | `scalloped_vault` | CLASSIC #624 + review repair | [scalloped-vault](../../examples/worldgen/architectural/scalloped-vault.style.json) |
| Shelf Stack | `shelf_stack` | CLASSIC #624 | [shelf-stack](../../examples/worldgen/architectural/shelf-stack.style.json) |
| Space Frame | `space_frame` | CLASSIC #624 | [space-frame](../../examples/worldgen/architectural/space-frame.style.json) |
| Spine Arcade | `spine_arcade` | CLASSIC #624 | [spine-arcade](../../examples/worldgen/architectural/spine-arcade.style.json) |
| Split Pier | `split_pier` | CLASSIC #624 | [split-pier](../../examples/worldgen/architectural/split-pier.style.json) |
| Stacked Arcade | `stacked_arcade` | CLASSIC #624 | [stacked-arcade](../../examples/worldgen/architectural/stacked-arcade.style.json) |
| Staggered Balcony | `staggered_balcony` | CLASSIC #624 | [staggered-balcony](../../examples/worldgen/architectural/staggered-balcony.style.json) |
| Steel Trestle | `trestle` | CLASSIC #624 | [steel-trestle](../../examples/worldgen/architectural/steel-trestle.style.json) |
| Stepped Aqueduct | `stepped_aqueduct` | CLASSIC #624 | [stepped-aqueduct](../../examples/worldgen/architectural/stepped-aqueduct.style.json) |
| Stepped Buttress | `stepped_buttress` | CLASSIC #624 | [stepped-buttress](../../examples/worldgen/architectural/stepped-buttress.style.json) |
| Suspended Deck | `suspended_deck` | CLASSIC #624 + review repair | [suspended-deck](../../examples/worldgen/architectural/suspended-deck.style.json) |
| Suspension Pylon | `suspension_pylon` | CLASSIC #624 | [suspension-pylon](../../examples/worldgen/architectural/suspension-pylon.style.json) |
| Tripod Frame | `tripod_frame` | CLASSIC #624 + review repair | [tripod-frame](../../examples/worldgen/architectural/tripod-frame.style.json) |
| Triptych Arcade | `triptych_arcade` | CLASSIC #624 | [triptych-arcade](../../examples/worldgen/architectural/triptych-arcade.style.json) |
| Twin Mast Bridge | `twin_mast_bridge` | CLASSIC #624 | [twin-mast-bridge](../../examples/worldgen/architectural/twin-mast-bridge.style.json) |
| Vierendeel Frame | `vierendeel_frame` | CLASSIC #624 | [vierendeel-frame](../../examples/worldgen/architectural/vierendeel-frame.style.json) |
| Warren Truss | `warren_truss` | CLASSIC #624 | [warren-truss](../../examples/worldgen/architectural/warren-truss.style.json) |
| Wedge Gallery | `wedge_gallery` | CLASSIC #624 | [wedge-gallery](../../examples/worldgen/architectural/wedge-gallery.style.json) |
| Yoke Bridge | `yoke_bridge` | CLASSIC #624 | [yoke-bridge](../../examples/worldgen/architectural/yoke-bridge.style.json) |
| Ziggurat Arcade | `ziggurat_arcade` | CLASSIC #624 | [ziggurat-arcade](../../examples/worldgen/architectural/ziggurat-arcade.style.json) |
| Zigzag Bridge | `zigzag_bridge` | CLASSIC #624 | [zigzag-bridge](../../examples/worldgen/architectural/zigzag-bridge.style.json) |
| Zigzag Pier | `zigzag_pier` | CLASSIC #624 | [zigzag-pier](../../examples/worldgen/architectural/zigzag-pier.style.json) |
| Cathedral Megaframe | `cathedral_megaframe` | Showcase #671 ← #664 | [cathedral-megaframe](../../examples/worldgen/architectural/cathedral-megaframe.style.json) |
| Interlaced Viaduct | `interlaced_viaduct` | Showcase #671 ← #667 | [interlaced-viaduct](../../examples/worldgen/architectural/interlaced-viaduct.style.json) |
| Interlock Brutalism | `interlock_brutalism` | Showcase #671 ← #669 | [interlock-brutalism](../../examples/worldgen/architectural/interlock-brutalism.style.json) |
| Megatruss Station | `megatruss_station` | Showcase #671 ← #663 | [megatruss-station](../../examples/worldgen/architectural/megatruss-station.style.json) |
| Metabolist Spine | `metabolist_spine` | Showcase #671 ← #666 | [metabolist-spine](../../examples/worldgen/architectural/metabolist-spine.style.json) |
| Rosework Gatehouse | `rosework_gatehouse` | Showcase #671 ← #668 | [rosework-gatehouse](../../examples/worldgen/architectural/rosework-gatehouse.style.json) |
| Seeded Typology Megablock | `seeded_typology_megablock` | Showcase #671 ← #665 | [seeded-typology-megablock](../../examples/worldgen/architectural/seeded-typology-megablock.style.json) |
| Suspended Arcology | `suspended_arcology` | Showcase #671 ← #670 | [suspended-arcology](../../examples/worldgen/architectural/suspended-arcology.style.json) |

## Materials, runtime inputs and concurrency boundary

The accepted material enum has the same Git blob identity as the historical
showcase parent. Every material ID used by all 80 standalone presets exists in
that accepted catalogue; exact role/name/ID mappings are retained in the source
inventory. This static identity check does not replace actual native admission
or runtime execution with the accepted materials.

The existing native build includes `world_generation.cpp`, which includes the
new sampler `.inc` files and the Megablock programme header. Make's source/header
input list already includes native `.inc`/`.hpp` files. The candidate-provenance
collector also includes those extensions and refuses untracked native inputs.
Existing retained native binaries cannot expose the new registrations; the
candidate needs source-matched Linux/Windows builds and their own publication
or package manifests.

No SWARM branch or experimental self-assembly/negotiation/CORPUS implementation
is part of the imported deltas. The showcases use ordinary `ArchitectureForm`,
module registrations, accepted material IDs and the schema-4 compiler. No new
research dependency requires importing SWARM.

The scoped source import leaves `shared_workbench.gd`, `main.gd`, physical actor
and Rapier code, native World/material/solver implementation, material publication
and camera presentation unchanged. The integration consumes the accepted
Architectural Generator entry point; concurrent actor/presentation missions
retain ownership of their shared infrastructure.

## Qualification interpretation

Source reconciliation and donor equality establish custody, not admission.
New execution must report its actual source commit or uncommitted delta,
compiler, runtime, platform, test failures/skips and image hashes. The final
candidate requires native and Godot contracts, the 80-style gallery campaign,
ordinary Workbench lifecycle tests, source-matched Windows package execution,
applicable CI and independent review. Historical donor passes do not qualify the
new final HEAD. Physical Windows/GPU and owner aesthetic acceptance remain
separate from automated native or headless results.


### Reusable native campaign

`python3 tools/ci/run_gentek80_native.py --compiler g++-13 --output build/gentek80-native-campaign --include-worldgen`

This Linux runner builds all nine ordinary generation tests and seven focused
showcase tests into a fresh private directory, then executes each suite once.
It retains the actual compiler/tool identities, native input hashes, command
logs, timeouts, failures and source-change checks. `--sanitize` executes the
same registered inventory with AddressSanitizer/UndefinedBehaviorSanitizer.
`--output` must be a new directory; a previous failed run is never overwritten.
The existing Make targets still execute all sixteen suites for ordinary callers.
The workflow should choose one of these complete routes rather than duplicating
the same native execution.
