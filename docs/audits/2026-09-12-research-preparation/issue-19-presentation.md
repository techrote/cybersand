# #19: fractional-presentation research and precomputed references

**Synthetic geometry and arithmetic evidence, not a renderer implementation.** Repository authority is [R3–R6](primary-sources.md); external geometric context is [S1–S3](primary-sources.md).

## Four levels must be defined before comparing them

The registered proposal interprets the request as four **nonempty** geometric coverages: 1/4, 1/2, 3/4 and 1, with Empty separately zero. This interpretation remains subject to the #19 contract review; the code does not amend the issue. Three mappings were compared: nearest including zero, nearest clamped to a minimum positive quarter, and ceiling. Identical simulation data feeds each comparison.

For mass8, nearest quarter coverage hides 31 positive states. Positive-preserving nearest hides none, but its worst absolute area error is 251/1020, approximately 0.246078 of a cell. A quantity 1/255 receives area 1/4, a 63.75× multiplier. Ceiling also retains every positive quantity and produces a systematic upward area bias. The full 18-row table retains the analogous results at mass3..8. “No disappearing droplets” and “unbiased area” are different requirements; no quantizer wins merely by satisfying one.

A continuous opacity compensation or a special tiny-drop glyph could be evaluated as an additional presentation policy, but must not silently replace a four-level geometric requirement. The strict diagnostic view should still expose the original quantity. None of these choices alters collision, mass conservation or the simulated droplet lifetime.

## A normalized condition byte is sufficient for the proposed widths

Current `project_visual_state` takes byte state_a/state_b and selects raw state_a for Water. Merely using raw value 7 for a full mass3 cell would not represent full occupancy to a renderer expecting 0..255. This is an integration hazard established by source inspection, not an observed bug in a feature that has not been implemented.

The proposed Water-specific projection is `condition = Q(m/M,255)`. The existing mass8 case remains identity. Across all 504 legal values for mass3..8, exact nearest decoding back to the known lattice gives the original integer. This is expected because the byte lattice has at least as many states as each tested source lattice. The three four-level quantizers also agreed in all 1,512 direct-versus-byte-projected comparisons. Independent C++ and Python summaries match byte for byte.

This result is scoped to the tested 2^b-1 maxima and mappings. It is not a universal double-rounding theorem for arbitrary maxima, does not cover mass10, and never authorizes reading presentation back into authority. Projection must be Water-specific: other materials' state_a/state_b meanings are unchanged. The packet's world generation and semantic identity still matter across reset.

## Oriented area reconstruction: the useful part of PLIC

Basilisk's geometric documentation describes a straight interface cutting a unit cell and an intercept determined by a supplied normal and fraction [S1]. This study uses an independently written polygon clipper and bisection reference, not copied upstream implementation and not a proposed 60-iteration fragment shader.

Sixteen normals at 22.5-degree intervals and four positive coverage levels produce 64 intercept entries. Area and complementary-area checks pass to a worst absolute error of 1.11e-16. The SVG atlas shows top, underside, side and diagonal cuts; it is explicitly labelled a synthetic construction. The precomputed table is useful for validating a cheaper bounded shader or a small proposed orientation LUT, but choosing 16 discrete directions is not an approved runtime design.

The normal is still missing information. The same fraction can correspond to opposite interfaces, an isolated centred droplet, a sheet or a concavity. Neighbor fractions provide a heuristic, not a unique reconstruction of the underlying topology. Test weak gradients, symmetric stencils, isolated cells and solid-adjacent cells explicitly. A 3x3 normal estimate should use a defined Water/air/solid classification, not accidentally treat every non-Water material as air. Prefer deterministic gravity/isolated-droplet fallbacks over inheriting an arbitrary previous direction without declaring new presentation state.

## Raster sampling can dominate geometric accuracy

The registered sample matrix contains 576 cases: 64 shapes, three grids 1x/4x/8x and three subpixel phases 0.125/0.5/0.875. These are point-sample grids inside one logical cell, not measured Godot display resolutions or GPU MSAA settings. Worst absolute errors relative to geometric area are 0.75, 0.125 and 0.09375 respectively. The larger grids help this sample set, but are not a guarantee of zero temporal aliasing.

At one device pixel per logical cell, a binary shape mask has only a single inside/outside sample. More precise geometry cannot make that binary sample display four stable area values. Actual coverage-aware antialiasing, a clearly defined alpha policy, or increased sampling must therefore be assessed at the intended zoom. Keep world-space anchoring, phase changes and camera movement in the validation fixture. Do not extrapolate from a clean zoomed-in screenshot to the normal play view.

For #19 implementation, freeze authoritative snapshots and compare top/underside/side/diagonal boundaries, thin streams, single-cell droplets, concavities, close barriers and positive/negative seams. Then hold presentation fixed while comparing semantic candidates. Changing both at once would confound Water feel with different visibility or silhouette rules.

## Existing bridge costs and shader boundaries

The inspected bridge still applies CPU dirty patches to a full backing Image, then updates the full 1024x1024 RG8 texture. That is 2,097,152 bytes per changed publication at this size, not a measured GPU transfer duration. At 60 such publications per second the nominal submitted payload is 120 MiB/s, before driver/copy effects; it is a conditional arithmetic rate, not an observed cadence. The official ImageTexture documentation distinguishes update from reallocating set_image [S2]. Smaller dirty rectangles alone do not establish partial GPU upload support.

Material IDs and condition bytes are data, not albedo. Godot documents separate sampler filtering and color-source hints [S3]. Audit the actual data sampler for nearest/integer-appropriate fetch and disabled unwanted color conversion; do not linearly interpolate IDs and accidentally select a different material. Any neighbor stencil must remain within copied immutable presentation data. No mutable World read, extra authoritative normal field, new per-cell object, GPU authority or solver change is justified by this research.

GPU timing, actual screenshots, temporal behavior, interface-normal quality and browser compatibility remain unmeasured here. The half-plane reference is a correctness aid, not a performance claim or visual acceptance certificate.
