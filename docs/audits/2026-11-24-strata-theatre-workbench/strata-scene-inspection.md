# Independent authored scene geometry inspection

**Scope:** read-only Python mask inspection of the three native reference scene documents at candidate `99d3d9ef8cbf112e13979e6d64ed3113b4ec55fc`, application tree `21d47b1ca2210ad61cfeac8997019586f8e0d639`. The scene bytes also match the later harness-only source. Exact file and mask hashes, component bounds, material counts and the inspection-script hash are retained in `strata-scene-inspection.json`.

All **3,074 authored rectangles** across the twelve planes are positive integer rectangles inside the protected one-cell canvas rim. Each scene is 1024×768. Ordered rectangle replay preserves the material ID per cell; ratios exclude the rim. All three authored Midge spawn footprints are Empty.

| Scene | Empty play interior | Spawn-connected share of Empty cells | Nearest material clearance from the unrotated 4×3 Midge hull | Conservative 5×5-clear centre component |
|---|---:|---:|---:|---:|
| Assembly Hall | 88.4541% | 26.7163% | 61.1658 cells | 177,893 cells; x44–979, y396–707 |
| Arcology Transit Spine | 89.9106% | 91.4791% | 61.5000 cells | 629,663 cells; x3–1020, y3–715 |
| Condensate Grotto | 76.8485% | 100.0000% | 80.6923 cells | 585,838 cells; x3–1020, y43–710 |

The Assembly Hall spawn occupies an enclosed lower hall. Its point-empty component spans x42–981/y394–709 and contains 185,001 cells. This is useful, substantial flight space despite the disconnected exterior/upper chamber: sweeping the unrotated Midge along x64→960 at y624 crosses no material and retains at least 20 cells of clearance; a connected central rise from (500,624) to (500,418) retains at least 16.0078 cells. The source should be described as a lower-hall traversal scene, not a fully connected map. No scene change is indicated by this inspection.

The authored play geometry provides legible horizontal ledges: industrial hazard-marked decks and a floor, two arcology tiers with separated spans, and three hazard-marked cavern platforms between irregular surfaces. The automated support inventory requires at least twelve authored Empty cells overhead and sixty-four cells of exposed width. It describes visual geometry, not proven walking or jumping routes.

**Limits:** this is not native World readback, physical simulation, material evolution or actual actor traversal. Every nonempty play cell, including Water, blocks the geometric mask. Connectivity uses four-neighbour cells, and the 5×5 erosion is a conservative centre-space probe. Hull clearance uses the source-authored, unrotated Midge rectangle; steering, contact response, rotation, momentum and other actors are untested by this method. Decorative planes never enter the play mask. Their local-coordinate overlap values do not establish rendered visibility after parallax, opacity and camera transforms. Actual Godot and owner interaction gates remain separate.
