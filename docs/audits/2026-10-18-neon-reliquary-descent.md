---
title: Four-district Neon Reliquary descent implementation and validation
status: Current
document-kind: audit
scope: 2026-10-18 three lower district tiles, shared navigation, actual Linux rendering and native/controller validation; separate from physics acceptance
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/neon-reliquary-demo.md, ../reference/validation-evidence.md, 2026-10-18-neon-reliquary-demo.md]
---

# Neon Reliquary and the three districts below

## Request and recoverable source boundary

After accepting the visual direction of Neon Reliquary, the owner requested
**Middle Cyberberbia**, **Sewertech Alley** and **Industrial Underswamp** below it,
and explicitly authorized pushing all four to the new branch. This is an
authored scene-content increment with navigation and presentation support.

Accepted main baseline: `ec05d7227885bda59bf72a5889b004296b9a07e5`.
The original Neon implementation is local commit
`14c9f3e4128c76e0580b466a8943a7313a6168b1`, followed by its publication-status
record `813f9e8ca1222e4ea97bf19e4c38399270559acb`. This increment builds on those
commits in **`scene/neon-reliquary-demo`**, in `techrote/cybersand`.
The accompanying [evidence manifest](2026-10-18-neon-reliquary-descent-evidence.json)
binds the tested working source, recipes, runtime and retained images by SHA-256.

The original [local-only checkpoint](2026-10-18-neon-reliquary-demo.md) remains
historical evidence of the earlier automatic publication refusal. The owner's
new explicit push instruction supplies the authorization that was missing then.
Publication of this increment is recorded separately below.

Parallel material/readability and player work remains separate. No native source,
material rule, normal palette/emission/glow shader, dependency pin or retained
runtime library changes in this increment. The original Neon recipe is byte-for-byte
unchanged. No source/runtime attestation is rewritten to accommodate scene code.

## Implemented content and interaction

| Order | District | Visual composition | Rectangles | Authored writes | Materials |
|---|---|---|---:|---:|---:|
| 1 | Neon Reliquary | Suspended cyan heart, monumental arch, ornate service towers and flooded nave | 3,973 | 543,468 | 34 |
| 2 | Middle Cyberberbia | Warm apartment stacks, furnishings, laundry, roof gardens, inhabited bridge and lantern court | 3,721 | 683,781 | 34 |
| 3 | Sewertech Alley | Pipe racks, valves, pump stack, descending glass-fronted sluice, catwalks and mossy culverts | 3,592 | 1,012,489 | 30 |
| 4 | Industrial Underswamp | Leaning still, suspended process vessel, broken gantry, drowned basins and rooted islands | 3,722 | 492,550 | 25 |

Writes count intentional overlapping construction layers. All four retain the
existing 4,096-record, eight-world-area and 1 MiB strict schema-2 limits. Each
defines one 1024 × 1024 native world, a 960 × 540 overview and four distinct
480 × 270 detail views. The five views of each district are composed separately.

The catalogue defines a top-to-bottom order and logical positions `(0,0)` through
`(0,3)`. Above/Below and the district selector load the selected tile's original
paused tick-zero layout. They do not retain another tile's edits or stream an
offscreen world. Above is disabled at the reliquary; Below is disabled at the
underswamp. Viewpoint changes preserve current material edits and native state.
Fresh reset restores only the selected district and its overview.

The native MicroScenario host remains the installation authority. Desktop
selection waits for the existing worker acknowledgement; synchronous Web
selection installs through its existing owner. Accepted title, district index,
camera framing and atmosphere follow the acknowledged definition. Pending or
invalid requests do not advertise a new scene. Both district and viewpoint
popups block painting and require pointer release before a fresh gesture.

The original cyan atmosphere remains at the top. Lower districts add warm
rose/amber, utility teal, and muted swamp green/rust respectively. The same
current-material, previous-transition and player masks protect foreground
rendering for every palette. Native cells and the ordinary material renderer
still own all architecture, water, signs and edit responses.

## Local execution and visual review

Runtime: Linux x86_64, Godot **`4.7.stable.official.5b4e0cb0f`**;
one native worker in focused tests and captures. Godot archive SHA-256:
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
Linux native library SHA-256:
`43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c`.
Rapier 0.35.2 Linux library SHA-256:
`147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.
All 30 retained native source inputs match their provenance manifest.

Rendered views use the normal desktop controller and native publication pipeline
with Godot Compatibility/OpenGL 4.5, Mesa `25.2.8-0ubuntu0.24.04.2`,
llvmpipe LLVM 20.1.2 under Xvfb. All twenty 1920 × 1080 PNGs were rendered at
paused tick zero. The [scene guide](../operations/neon-reliquary-demo.md) presents
the lower-tile overviews and links every detail. The new image directory preserves
the original checkpoint's screenshots and hashes.

The residential review checked the furnished room rhythm, readable shop signs,
bridge silhouette and open lantern court. The sewer review checked its central
stepped watercourse against the dense side machinery. The swamp review checked
the large asymmetrical vessel/still silhouettes, open cavern and smaller rooted
islands. These are actual material renderings, with no generated concept images.
The final swamp pass removes disconnected glass dashes from the pools and adds
an irregular mineral/moss bank below the gantry. Its five views were recaptured
and the complete four-district regression was repeated on the refined recipe.
The visible district controls were also rendered and inspected at 1280 × 720;
both navigation rows fit, and the title/selector agree with the accepted scene.

The final four-district fixture passes **192 assertions with zero failures**,
including 120 native ticks for each new tile, strict construction, exact reset,
rejected replacement, accepted navigation, endpoints and pointer editing. The
original Neon regression passes 89 assertions with zero failures and 120 native
ticks. Eight existing shared-controller regressions also pass, covering the
MicroScenario host, Web menu, player representations/environment, selectable
fixtures, brush ownership, Water controller and render-patch handoff. The real
pixel oracle passes for all four backdrop palettes, including solid/liquid
occupancy, sampled player, previous-cell transitions, erase and fresh paint.

### Diagnosed attempts

- The first all-tile capture found that the prior local Xvfb display had ended.
  Restarting that display resolved the launch failure; the same pinned Godot
  runtime then captured all twenty views without script or shader errors.
- The first original-Neon and new-district runs exposed an untyped empty-array
  return from the registry's unknown-ID viewpoint path. An explicit
  `Array[Dictionary]` fallback fixes that path. The original 89-assertion fixture
  then passed with no runtime diagnostics. The eight already-passing unrelated
  regressions were not repeated for this isolated fallback correction.
- A fresh-erase positive control in the new popup fixture initially injected
  logical coordinates as screen coordinates. The 1920 × 1080 viewport was
  stretched into a 1600 × 900 test window, putting the synthetic pointer outside
  the world. Applying the viewport screen transform fixes the input fixture;
  the behavioral assertions were retained.
- The same positive control exposed a headless-observation mismatch: desktop
  owner revision and the accepted CPU render image changed after erase, while
  the dummy renderer's `ImageTexture.get_image()` retained stale pixels. The new
  test reads the main-thread CPU image assembled from accepted render patches;
  it neither queries the worker's world nor weakens the exact byte comparisons.

The software display's unsupported V-Sync warning does not indicate a scene
failure. Raw local logs retain the failed attempts; the evidence manifest records
their diagnoses alongside the final results.

Final documentation/provenance checks pass without errors or warnings: 79 corpus
documents, 137 canonical claims, 1,337 local links and all 18 required runtime
files materialized. Historical M11 separately passes 18 records and 28 source
hashes against `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`. Retrieval canonical
hit@5 is **32/32** on the frozen questions and **38/38** on the independent
challenge set; both `SCENE01` and `SCENE02` route to the scene guide at rank one.
The CI-provider policy and `git diff --check` also pass.

## Reproduction

With the exact pinned runtime and materialized native libraries:

```sh
timeout 180 godot --headless --path godot \
  --script res://tests/test_showcase_tiles.gd
timeout 180 godot --headless --path godot \
  --script res://tests/test_neon_reliquary.gd
timeout 90 godot --path godot --rendering-method gl_compatibility \
  --script res://tests/test_showcase_backdrop_render.gd
timeout 240 godot --path godot --rendering-method gl_compatibility \
  --resolution 1920x1080 --max-fps 30 \
  --script res://tools/capture_neon_reliquary.gd -- \
  --all-tiles --capture-dir=/absolute/output/directory
```

The pixel check and capture need a rendering display. The headless test executes
both controller implementations on Linux; it is not browser/WebAssembly execution.
The existing CI regression discovery includes every `test_*.gd`, so the new
four-district test requires no workflow change. The pixel oracle explicitly
reports its headless skip rather than claiming a rendered result in headless CI.

## Documentation map and scope

The [scene guide](../operations/neon-reliquary-demo.md) owns district order,
opening/navigation/reset semantics, art direction, authoring and capture. README,
Material Lab, the corpus/retrieval index, configuration, appearance, MicroScenario
programme/contract, roadmap and handover route to it. The independent `SCENE02`
retrieval challenge covers district order, original-layout replacement and
viewpoint edit preservation. Frozen retrieval questions remain unchanged.

Native ownership, transport, Water8/coherence12, material semantics, capacity
limits and architectural decisions remain unchanged. The scenes have no bodies,
events, observations or objectives. This increment supplies no new Water,
traversal, body-coupling, performance or broad gameplay acceptance.

Local execution establishes Linux native/controller and software-rendered scene
evidence. It does not establish new Windows execution, browser execution or
physical-GPU performance. The owner accepted the original visual direction;
automated checks do not infer their acceptance of the three new compositions.

## Publication

The owner explicitly authorized pushing the complete four-tile set to
`scene/neon-reliquary-demo` in `techrote/cybersand`. This local implementation
checkpoint is prepared for that push. No merge is performed by this scene task.
Applicable exact-head GitHub integration results belong to the published review
and are required before a later merge; local passes are not substitutes for them.
