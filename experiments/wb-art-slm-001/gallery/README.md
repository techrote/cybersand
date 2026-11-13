# Qualified native pattern gallery

Open **[native_atlas.html](native_atlas.html)** after downloading it. This one
HTML file embeds the original native PNGs and supports theme, source, layout and
seed filters without a server or network. Click an image to obtain its original
96×96 PNG. Every tile exposes the exact program and native receipt identities.

![Twelve reference words, actual native material readback](native_reference_12.png)

The completed bootstrap atlas contains **260 images**: 192 reference renders and 68 model replays. The reference section covers twelve themes × eight
structural templates × two seeds. They were selected from the **864/864 passing
native teacher cases**. All 192 native readbacks differ, and the repeated
32-case pilot reproduced its operation hashes, raw material bytes and PNGs
exactly. Those numbers measure execution and reproducibility; image uniqueness
does not establish artistic merit.

## Actual trained model section

![Twelve exact model requests, including semantic errors](native_model_keywords_12.png)

The frozen 400-step LFM2.5-350M adapter produced 22/24 accepted development programs
and 12/12 accepted literal-word programs. Every accepted program was replayed at
host seeds 17 and 73: **68/68 native cases passed**. These are 34 accepted requests,
not 68 independent language requests. The two invalid coral JSON completions were
never repaired or executed. `veins` uses an incorrect orthogonal motif; `ribs`
uses rib geometry but declares the wrong theme label. Both errors are visible
and remain failures of the requested semantic contract.

All 34 programs produced different readbacks between the two seeds. There are
66 distinct readbacks across 68 cases; cross-request overlap is retained. The
assistant inspected all 68 images in two complete contact sheets. This is
provisional visual inspection, not a blind recognition or human aesthetic score.
See [model_visual_review.json](model_visual_review.json).

The independent model packet passed 1,398 engine assertions, 329,761 native
receipt checks and 408 raw-completion-to-compiler binding checks. Twelve theme
representatives passed exact Undo/Redo/save/reopen. Its first attempt is retained
as failed because long evidence IDs exceeded the 48-character saved-start name
limit. The retry uses short aliases, preserves the original ID mapping, and does
not change or repair any model program. Frozen harness case IDs must be at most
38 characters because the save name adds `slm-pilot-`.

## What "qualified" means here

Every gallery case was drawn through the existing mounted Art planner/executor
into an actual paused native CyberSand World. Independent reconstruction from
the native before/after receipts matches the separate native capture, cropped
material file and PNG pixels. Full-world scans observed zero writes outside the
requested focus and zero unexpected materials. Global source/input/runtime
custody, protection and Stop checks passed. Exact Undo/Redo/save/reopen was
checked on one representative per theme in the full campaign and on all 32
cases in the initial pilot.

Source: `90719c72b9fcf90593fb7878354051ad601b47fd`. Engine:
`4.7.stable.official.5b4e0cb0f`. Native library SHA-256:
`3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd`.
This is a **pinned Linux headless native-material pilot**, not current-main,
Windows, graphical framebuffer or human aesthetic acceptance.

The images show native material IDs through a fixed dark/ivory display palette,
using Godot `Image`. The source PNGs are preserved unchanged. Contact sheets use
nearest-neighbor enlargement only; no generated illustration substitutes for a
native result. The model section is labeled separately and flags wrong theme labels, primary motifs and requested layouts. Its request denominators retain the two rejected coral responses, which have no native image.

## Visual review and known weaknesses

The assistant viewed all 192 images in three complete contact sheets. Family
motifs and layout changes are visible, but this is provisional inspection rather
than a blind recognition score. Coral defaults crowd the bottom of the canvas.
Narrow border strips compress several motifs, especially crystals, dunes and
ribs. Companion layers sometimes remain decorative framing instead of an
integrated composition. These observations are recorded in
[`corpus/visual_review.json`](../corpus/visual_review.json) as explicit next work;
they have not been converted into a fabricated human acceptance rate.

## Rebuild from archived native evidence

`build_gallery.py` only assembles verified native PNGs. It rejects a failed
packet, mixed runtime identities, invalid cases, changed operation digests and
changed image bytes. It never paints compiler geometry itself.

```bash
python experiments/wb-art-slm-001/gallery/build_gallery.py \
  --config /absolute/path/gallery-build-config.json \
  --out /absolute/path/gallery
```

The configuration contains a `batches` array. Each item names `kind`, `cases`
(the exact native input JSON), `artifacts` (native output directory), `receipts`
(globally verified receipt JSON), and optional `select` case IDs and `model`. Model batches also supply `assessments`, a list of original prediction JSON files. Each case carries `prediction_id`; the builder verifies that the original completion equals the replayed program before displaying its semantic assessment.
The builder emits the multi-file atlas, the self-contained atlas and a manifest.
The source repository keeps the self-contained atlas, compact manifest and
contact sheet; the evidence archive preserves original files and raw native
materials.
