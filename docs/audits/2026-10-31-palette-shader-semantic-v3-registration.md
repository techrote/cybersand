---
title: Palette shader semantic qualification v3 and actual GPU input controls
status: Current
document-kind: audit
scope: Versioned shader apparatus correction; original failures retained; fresh published-source Windows and Linux qualification required
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [2026-10-31-palette-shader-qualification-registration.md, 2026-10-31-palette-shader-integration.md, ../systems/material-appearance-and-rendering.md, ../operations/current-and-historical-validation.md]
---

# Palette shader semantic qualification v3 — 2026-10-31

## Two retained v2 failures

The original qualification registration and its source-bound artifacts remain
historical evidence. Hosted run
[`41242820430`](https://github.com/techrote/cybersand/actions/runs/41242820430)
on source `8d38284340a6ad1263f9631b8f18f2a48519701e` failed the final
cross-backend finished-image gate. Its Windows fixture had obtained encoded HDR
instructions through `ImageTexture.get_image()`. The GLES readback path clipped
flair values above one before the fixture reused them. The CPU image extraction
recorded in the [preceding audit](2026-10-31-palette-shader-qualification-registration.md)
preserved the production upload behavior and corrected that fixture input defect.

The corrected source `19ddd366392fe017d0c2edf9a382d1a99b1870a9`, tree
`19a3af6c1fb4b921e56d1655b389a91fe294559b`, ran all six cohorts in hosted run
[`41247269016`](https://github.com/techrote/cybersand/actions/runs/41247269016).
All six individual cohort jobs passed. The exact hosted native/ANGLE pair still
fails the unchanged v2 finished-image criterion: 11 of 2,304 incoming powder
pixels differ by more than `2/255`, with maximum RGBA difference
`0.3009393513202667`. Midpoint differences occur at the same 11 locations and
reach `0.15134277939796448`. All outgoing-base pixels remain within the original
tolerance, with maximum `0.0019608139991760254`, and all alpha channels agree.

On each backend, all three blend-one frames are byte-identical to that backend's
retained full-current endpoint. The full-current endpoints already contain the
same 11 differences. All 24 hosted Linux images and their 24 PNGs are also
byte-identical to the fresh exact-source local Linux proof. These observations
separate procedural finish differences from the bounded interpolation law;
they do not turn either v2 failure into a passing result.
An unchanged independent v2 reducer over all six authenticated artifacts also
passes the cohort checks and fails at that original cross-backend pixel gate.
Its private extraction avoids unrelated local workspace-copy temporary files;
the earlier strict inventory refusals and those extra files remain preserved.

## Observed operation attribution and its limits

The [production shader](../../godot/shaders/material_palette.gdshader) explicitly
limits its arithmetic hash stability statement to one GPU. Its powder finish
uses hash thresholds for specks, pits and glints, and a coarse hash sampled in
two-by-two cell blocks. The measured RGB differences uniquely match the
following existing source operations within the original `2/255` tolerance.
The largest residual after applying the indicated operation is below `0.001898`.

| Observed source operation | Pixel locations | Count |
|---|---|---:|
| Add glint RGB `(0.30, 0.28, 0.22)` | `(57,0)` | 1 |
| Add/remove speck RGB `(0.13, 0.12, 0.09)` | `(17,6)`, `(58,25)` | 2 |
| Apply/remove pit factor `0.68` | `(16,6)`, `(55,28)`, `(46,30)`, `(27,32)` | 4 |
| Coarse-hash wrap, adding `0.24 × registered base RGB` | `(10,30)`, `(11,30)`, `(10,31)`, `(11,31)` | 4 |

This is attribution by observed operation signatures, not captured compiler
intermediate values or disassembly. Numerical hash instability is the
source-supported inference; no particular fused instruction is established.
Khronos [GLSL ES 3.00 revision 6](https://registry.khronos.org/OpenGL/specs/es/3.0/GLSL_ES_Specification_3.00.pdf),
sections 4.6 and 5.11, describes limits on reproducibility across independently
compiled expressions and permitted arithmetic evaluation. The
[ES 3.20 precise qualifier discussion](https://registry.khronos.org/OpenGL/specs/es/3.2/GLSL_ES_Specification_3.20.html#the-precise-qualifier)
also explains why combined and separate arithmetic can differ. These primary
references support the absence of a portable finished-image identity guarantee;
they do not prove the instruction sequence used in this run.

Retained evidence under `shader-qualification-evidence/hosted-41247269016/`:

| Evidence | SHA-256 |
|---|---|
| `corrected-hosted-backend-pair.json` | `9a56790bbf213b5cc8169a5da09490dece977711241c24bae168bc1c16069856` |
| `corrected-powder-residual-attribution.json` | `851f3058f9de79e3631a5c1bfef32f6c594a42537b5db1a7c877dca169b2cc2f` |
| `corrected-pixel-diagnostic.png` | `ad0c1b68e91296b05f359fe1a7c4ac70445f1297fcb903165db28cb9a491ba3d` |
| `independent-original-v2-private-extraction.json` | `7ba5d5b006064ee6499f25204590773df2ab57b9f2d32b23fecde4dcdc0397eb` |

## Registered v3 acceptance contract

The v3 fixture preserves all original 24 image captures in their original order,
132 outgoing slots, conditions `0/128/255`, blends `0/0.5/1`, camera shift `(3,2)`,
palette/program edit recipe, presentation time and `2/255` tolerance. Production
shader and script bytes are unchanged. There are still six cohorts, 19 fixture
processes, six imports and eight real Main lifetimes. No case or child allowance
is shortened; the two new data draws fit inside the existing oracle case.

Acceptance requires the positive outgoing CPU-base oracle, each backend's
base/midpoint/full-current equations and camera overlap, plus the independent
actual-GPU-input controls below. Cross-backend outgoing-base comparison remains
a hard positive gate at `2/255`. The separate native full-path atlas still
requires all 16 raw/PNG pairs to match the accepted baseline exactly. All source,
actual backend/compiler, process retirement, cache lineage and Main lifetime
checks remain mandatory.

The full nine-frame native/ANGLE finished-image comparison is retained in
`finished_image_diagnostic`, including its original threshold, per-frame maximum,
pixel count and explicit passed/failed status. It is a diagnostic in v3, whose
hard semantic predicates are stated above. There is no accepted outlier count,
pixel exclusion list, new tolerance or production-hash change. The fixture and
suite schemas are versioned; old v2 artifacts cannot qualify without newly
executed GPU input controls, and their old failed verdicts remain failed.

## Independent actual GPU program proof

The fixture retains canonical and edited CPU program bytes. The reader pins the
canonical 8,192-byte, four-by-256 RGBAH image independently to SHA-256
`6ab9c18f2f2993eda7c552b86a28d639a70fb03e0ffdfb2ae070da5c587bb60d`, reconstructs
the registered edit recipe, and requires exact edited bytes. Sand and Water
retain flair tags 33 and 29; the maximum registered tag is 50.

Each of the 21 production draws records the actual `material_program_lut`
object and RID before and after rendering. After all original 24 captures, the
positive data shader samples the exact texture retained from a production
material binding. It expands the four-by-256 RGBA program into 16-by-256 scalar
pixels: all 4,096 channels are observed as opaque RGB scalars, with only flair
alpha divided by 64. All values then fit in `[0,1]`, avoiding the lossy HDR
readback problem and alpha compositing ambiguity. The independent reader checks
every scalar against the registered instructions at the original tolerance.
The probe shader source is pinned to SHA-256
`9a21543c0cdf2105bf8350a94e7526547eed3a71f3062cee85370601f313e93e`.

A second, actually rendered data probe uses an explicitly separate duplicate
texture whose flair alphas are clamped to one. It never serves as the positive
production texture. Its complete GPU output must match the independently
reconstructed clamped recipe, and the unchanged positive comparator must reject
it, including both Sand and Water anchors. Arbitrary bad output is not a passing
negative control. Shared/substituted RIDs, missing or reordered probes, altered
CPU bytes with rehashed metadata and incomplete scalar inventories are rejected.
This closes the input defect that endpoint self-reference alone could absorb.

## Focused local validation and remaining gate

The local candidate completed 35 portable controls normally and under Python
`-O`, including coherent endpoints with clamped GPU inputs, rehashed canonical
and edited bytes, binding substitution, missing/reordered data, arbitrary
negative output and retained failed finished-image diagnostics. Existing
outgoing colour, midpoint, final endpoint, camera and byte-custody negatives
remain active.

The actual Linux candidate probe completed 1,274 assertions with zero failures.
Its 4,096 positive GPU scalars match exactly; the actual negative control also
matches its clamped recipe exactly. Positive comparison rejects that negative
with maximum error `0.765625`, including Sand `0.5` and Water `0.4375`. All 48
original raw/PNG files remain byte-identical to the exact published-source
`19ddd366` Linux proof. The local run explicitly records an uncommitted candidate
identity, and is not published-source acceptance.

Local review evidence is under
`shader-qualification-evidence/semantic-v3-local-attempt1/`; its
`review-receipt.json` SHA-256 is
`d1d4ec0a19da4d53726686118514938ebc80c5a6116c92c2e204ec5f8a0a7b7e`.
Independent source review and normal/optimized portable controls found no
blocker. A second reviewer independently reread the actual frame artifacts,
confirmed all 48 original files remained exact, and used private copies to show
that coherent endpoints with clamped positive inputs, fake unclamped negatives,
rehashed canonical bytes and substituted bound RIDs are rejected. That review
receipt, `semantic-v3-independent-review/readback.json`, has SHA-256
`ab3326f9fc6f29a91a09f70c8cb47f155896c7c238949a8dc23923cd2bf3bffd`.
Fresh source-matched Windows ANGLE and Linux execution of all six cohorts and
the v3 reducer remain required after publication. Whole-process and
request-to-readback timings remain observations, never compiler-only FXC time or
a universal performance/physical-device claim.
