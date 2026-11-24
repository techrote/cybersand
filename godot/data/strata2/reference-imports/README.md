# Exact reference artwork crops — Draft import proposals

These two small PNGs preserve exact RGB pixels from the public SANDMAPS originals at repository commit `99a166e7fcae45eb22be1740e9f33f62faccbcc7`. The originals are **opaque RGB images**. Dark space and architectural openings in their pictures are not native alpha, depth assignments or collision authority.

The separate `.mask.png` files are explicit manually selected architectural regions. Their white opaque rectangles include pixels; transparent pixels exclude them. Both examples leave substantial interior regions untouched. The masks express a proposed authoring choice and remain visible in the import preview.

| Input | Original crop `(x, y, width, height)` | Proposed mapped cells | Mask-excluded cells | Unmapped colours explicitly skipped |
| --- | --- | ---: | ---: | ---: |
| Asteroid service gallery | `1180, 384, 384, 320` | 19,552 | 103,156 | 172 |
| Rocket hangar frame | `368, 112, 512, 320` | 27,582 | 133,732 | 2,526 |

The fixed example settings use the **scripted** plane, origin `(128, 128)`, exact scale `1`, unchanged orientation, overlay/no-write alpha policy, threshold `128`, six explicitly listed palette colours, maximum Euclidean RGB distance `64`, and **Skip and report** for unmapped pixels. Neither input requests an Empty-cell write. Changing the unknown-colour policy to Refuse correctly refuses both proposals.

Each `.provenance.json` preserves the full original source URL, commit, original SHA-256, original resolution, selected crop, exact crop-pixel digest, mask recipe and digest, palette decisions, complete counts and an independently computed proposed material-byte digest. Original source files remain unmodified; they are not duplicated in this small evaluator fixture bundle. These images are input evidence, **not native output captures**.

The Workbench still performs source inspection, bounded preview against the actual target plane, explicit approval, native application and independent readback. Loading a sample alone performs no native write. A native result is qualified only by that separate execution; these fixture files do not certify source-visual fidelity, physical stability, structural connections or actor traversal.

Reproduce from unchanged downloaded originals with:

```sh
python3 tools/strata2_prepare_reference_imports.py --originals /path/to/originals
python3 tools/strata2_prepare_reference_imports.py --originals /path/to/originals --check
```

The generator rejects a different original source digest and never resamples the selected pixel grid. The test `godot/tests/test_strata_reference_imports.gd` checks the actual Godot PNG decoder and native material catalogue against independently generated proposal bytes, plus honest unknown-colour refusal. Its scope is input and zero-write proposal fidelity; the graphical Workbench qualification supplies the native output evidence.
