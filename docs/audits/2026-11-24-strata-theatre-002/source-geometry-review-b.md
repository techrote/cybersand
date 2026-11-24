# Scene geometry and authoring review — specialist B

This is a source geometry inspection by the scene author using a separate recipe parser, not a substitute for specialist C's independent native, actor and framebuffer qualification. The inspector does not call the generator, instantiate Worlds or render substitute images. Its exact per-file digests, final predicted LE16 cell hashes, occupancy and route results are retained in [source-geometry-review-b.json](source-geometry-review-b.json). Reproduce with `tools/strata2_inspect_scene_geometry.py --output /path/to/report.json`.

## Findings

| Native scene | Play occupied | Four-plane native union | Background cells exposed through nearer opaque geometry | Clear square radius at declared spawn |
| --- | ---: | ---: | ---: | ---: |
| Orbital terminal | 10.98% | 28.79% | 191,939 | 100 cells |
| Rain arcology | 13.83% | 48.12% | 239,153 | 66 cells |
| Industrial underworks | 15.36% | 32.61% | 76,297 | 83 cells |
| Abyss foundry | 35.27% | 57.48% | 193,395 | 72 cells |
| Vertical transfer spine | 15.21% | 41.12% | 242,109 | 89 cells |

These are untransformed opaque occupancy measurements. They deliberately omit parallax, opacity, material appearance, haze, live effects and physical motion. They establish that the native layouts have substantial distinct voids and distant material visible through nearer layouts under that comparison control. They do not establish the actual composited appearance.

All five scenes have four distinct final material arrays, stay within their protected native borders and preserve their declared 69 × 69 inclusive-cell swept route envelopes (radius 34). The two 2048 × 1024 landscapes retain long horizontal corridors; the underworks and abyss retain central vertical space; the portrait has a continuous vertical route. The generator's original support-leg/low-ledge conflicts were corrected before source delivery. No final route result is inferred from a thumbnail or scene label.

The orbital scene has the sparsest physical silhouette and the widest full-width route. Its principal visual risk is insufficient distant contrast, which must be judged from native captures. The arcology deliberately has denser rear architecture, while more than half the combined native canvas remains unoccupied. Its rain and sign strength require actual display review to avoid a busy silhouette.

The underworks uses hollow machinery, not filled reactor rectangles. Its small distant exposed area is intentional for a service interior, but the depth difference must remain visible through reactor apertures. The abyss has the largest physical occupancy because ceiling, floor and side geology occupy much of the perimeter. Its central route remains clear; rear rocks must be checked for visually merging with physical rock. The portrait demonstrates repeated parts at a large vertical scale; native detail and camera fit must be checked separately from overview scale.

The proposed routes are for a normal ordinary actor. Square clearances do not prove rotation clearance, successful control, high-speed readability, physical support or full-route completion. Specialist C's bounded actuation probe must state the actual completed distance and ticks; owner interaction remains a separate gate.

## Cross-lane findings and repairs

- B's root-presenter source review confirmed the existing decorative TextureRect child seam, inherited opacity, native-coordinate scaling, ancestor clipping and hidden/Solo processing control. Actual alpha/occlusion pixels remained a hosted gate.
- B found the JSON integer/float palette-membership defect through all three packaged compositions. A repaired the generic module codec, and the library normalizes parsed known integer-valued fields. Real JSON roundtrip coverage was added. Eight native modules and their six exact transforms passed value-contract checks with the actual retained native material catalogue.
- B found that a failed new UI preview could potentially re-enable a previous approval token if UI revision was advanced before the service accepted a new preview. C and root invalidated failed preview retries; the ordinary native workflow exercised the negative.
- B corrected the proposed mask wording: the importer uses nonzero alpha **and** RGB mean at least 128. C's controls now describe dark as well as transparent exclusions.
- B identified ordinary Play shader TIME as a confound in atmosphere OFF/ON and hidden-plane leakage screenshots. C is freezing and restoring that borrowed presentation parameter during matched witnesses, retaining actual effect motion as the changed variable.
- B requested atmosphere OFF during isolated native-plane captures and precise magnification labels for details. Source art and material-ID proposal colours must not be counted as native production frames.

## Preserved native diagnostic

[local-reference-native-first-diagnostic](local-reference-native-first-diagnostic/) contains the original report, process log, command and provenance note from the first real-reference Workbench run. Both references produced complete matching native material readback, unchanged full Play/nonselected-plane hashes and unchanged actor/owner identities. A real Stop retained exactly the first 4,096 acknowledged cells; the independent whole-target prefix projection and per-chunk Undo matched.

That run is explicitly a **diagnostic**, because root confirmed concurrent application edits near its start. Its two reported failures were the asteroid fixture's 49-character save name and the resulting failed reopen; the existing limit is 48. The test prefix was shortened without weakening the product limit. The frozen-source rerun below supplies a separate passing receipt. Original failures and source uncertainty are retained rather than relabelled as PASS.

## Frozen native reference execution

[local-reference-native-b02e35250](local-reference-native-b02e35250/) retains the complete command, runtime identities, output and report for application `b02e352508013ceb985e11d745f0d300389321bb`, tree `d7ffc24d5609acebdcfcf37844c8f7020e57f34f`. The preflight required clean application inputs; the postflight records the identical HEAD and no application diff. Exact Godot 4.7, native and Rapier bytes are identified in both command and process receipts.

**326 checks passed with zero failures.** Both source-pinned reference imports used the ordinary Workbench, explicit masks, selected crops and the admitted native edit queue. Whole-target native arrays matched independent masked projections. Whole Play and both nonselected decorative arrays, ordinary worker, world generation and actor body identities were unchanged. The rocket Stop trial retained exactly one acknowledged 4,096-cell prefix; per-chunk Undo restored its prior authored layout before a new approved full placement completed. Exact save/decode retained geometry and source provenance.

The asteroid crop mapped 19,552 cells in five acknowledged chunks; preview took 1.50 seconds and application plus readback 2.23 seconds. The explicitly selected 448 × 320 rocket qualification crop mapped 24,251 cells in six chunks; preview took 1.75 seconds and application plus readback 2.09 seconds. These are single local headless observations, including test work, with no promised interactive latency or physical GPU implication. Both original gallery files are opaque RGB; their source cutouts are explicit authored masks, not invented image alpha. The synthetic RGBA fixture is a separate alpha witness.

This is real native ordinary Workbench execution with headless display. It does not supply framebuffer, fresh-process interactive reopening, owner GPU appearance or subjective performance acceptance. Hosted Linux, Windows and extracted-package gates remain separately attributed to their own source-bound campaigns.
