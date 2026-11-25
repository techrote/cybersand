# Independent reference-import visual review — historical source-2

**Reviewer:** Specialist B (visual/atmosphere). **Status:** Draft/HOLD historical review; no blocking import defect observed. B authored the explicit reference masks; this review is independent of A/C’s import engine, native execution and UI implementation. It is not an independent certification of B’s fixture design.

## Evidence boundary

The inspected images are unmodified original hosted Linux Godot captures from [run 45493745153](https://github.com/techrote/cybersand/actions/runs/45493745153), artifact `14967949955`, application `1a124c0a47cd9f94e07b541e5c451602b8e8e0fd`, tree `8cecb1df9dee26e3b0730e5ddda4824da4a03aaf`. The complete 89,677,038-byte archive was independently checked against SHA-256 `0f2c10d46b1a5da76af436f0517090653211a8375e8adeb46730c2e4835b4b4f`; selected PNG bytes were checked against its original evidence ledger. No capture was edited and no new rendering was performed for this review.

That campaign failed the Orbital exact opaque background source-colour assertion. The two reference-import receipts completed successfully, but this review does not upgrade the failed campaign to PASS or qualify the later source-3 candidate. The JSON companion preserves individual frame hashes and original native receipts.

## Actual source, mask and native output

Both source images at SANDMAPS reference commit `99a166e7fcae45eb22be1740e9f33f62faccbcc7` are opaque RGB illustrations. Each shipped crop preserves the selected original pixels; an explicit authored selection mask decides which source pixels may propose writes. Neither mask is original alpha or inferred authoritative depth. Both graphical trials select Scripted / Rear architecture, origin `(128,128)`, integer scale 1, unchanged transform, Overlay and an alpha threshold of 128. Six explicit colour/material mappings use a distance limit of 64 and skip/report unmatched pixels.

| Actual graphical trial | Exact original crop | Proposed native writes | Mask no-write | Unmapped skip | Explicit Empty |
|---|---:|---:|---:|---:|---:|
| Asteroid service gallery in Orbital | `(1180,384,384,320)` | 19,552 | 103,156 | 172 | 0 |
| Rocket hangar frame in Arcology | `(368,112,512,320)` | 27,582 | 133,732 | 2,526 | 0 |

The Asteroid output shows the selected frame and lower strip as native textured material. The pre-existing X-truss and vertical rear post remain visible inside its central no-write opening. The output therefore demonstrates preservation of destination geometry under an excluded source region; an import aperture does not promise the destination was Empty.

The Rocket output shows the selected upper/left frame and right crane strips. The existing rear facade and illuminated windows remain visible through the large excluded centre. The source’s broad blue interior background and rocket are not silently filled into the target. Its source and mask shapes agree with the visible output.

These are useful structural extractions with a deliberately limited palette. Their native surfaces are more granular than the source illustration and do not reproduce all source shading, colour or depicted objects. The source image is not displayed as a native map. Native readback, rather than visual similarity alone, establishes the writes.

For Asteroid, the actual native result equals the expected `4bd4fff17578b2c080a9ab5f92d8a0d21b4892b51bbc932ddcf65b912e5c93fb`; five native history chunks restore the exact before hash `833d95286d9741eca8d73315a7248a1ed3415a73d0775c726b2f4f6d33f1bd94`. For Rocket, actual equals expected `940c32603d9541daaaed5d518a9eb90c5ae7b5e7898e0dcec69679945f0c3453`; seven chunks restore `3f741156856525756384d90e0596f7436fd539fcdabcd06b32ee68c8333eec0c`. Both receipts preserve identical Play-before/after hashes. These are readings of the original native receipts, not a new native execution by this review.

## Review interface and remaining visual evidence

The actual upper Import captures clearly identify the PNG, explicit mask, Rear architecture target, crop, placement, scale, transform and `Overlay · no write to cutouts`. They also state that PNG has no native authority or automatic layer assignment. Those labels accurately distinguish proposed conversion from native admission.

The source-2 images stop above the lower preview/count/approval area of the scrollable window. They cannot by themselves establish how well a user can compare source, mask and proposed output before approval. Source-3 adds lower ready-review captures; those require their own actual-image inspection. This is an evidence gap in these historical frames, not proof that the controls are absent.

The world HUD in the terminal source-2 native-output frame still reads `Native construction admitted` and discusses queued acknowledgement. The original operation receipt records `completed`. The persistent HUD is an ambiguity in status presentation, not evidence of a failed write; the panel/receipt remains the completion authority.

No dedicated post-Undo reference-import PNG exists in this original artifact. The exact restored hashes above support Undo correctness, but this review does not claim a visually inspected after-Undo frame or substitute a different fixture’s Undo screenshot.

## Owner interpretation

Inspect the explicit source and mask, then compare the actual target and proposed result before approval. A masked-out region keeps existing native cells; use explicit Empty replacement only when actual erasure is intended and the preview admits it. The two opaque references demonstrate explicit-mask extraction; the separate synthetic alpha-bearing fixture demonstrates source-alpha no-write behavior.

Use Solo/Flat inspection to establish the actual Play collision plane. Imported decorative material appearance does not grant actor, collision or mass authority. These hosted stills do not establish physical Windows/NVIDIA appearance, displayed FPS, movement feel, final package execution or owner acceptance.
