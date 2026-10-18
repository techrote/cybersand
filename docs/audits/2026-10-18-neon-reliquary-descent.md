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
[`scene/neon-reliquary-demo`](https://github.com/techrote/cybersand/tree/scene/neon-reliquary-demo)
in `techrote/cybersand`. The complete set was published as implementation commit
[`b950e62af685509ce91f940156a50e44a3a9c950`](https://github.com/techrote/cybersand/commit/b950e62af685509ce91f940156a50e44a3a9c950).
Its file tree **`86acb21102411374d696641753ea8493eb160c30`** exactly matches the
reviewed local implementation checkpoint **`004b1b73297c137db963329c3bde9d93f3ad55f2`**.

The command-line push could not authenticate because no Git credential was
available in the execution environment. The connected GitHub integration
published the same files and images, with every binary blob and the complete
tree checked against the local Git identities before branch creation. A fresh
fetch then confirmed the published tree. This changes commit metadata, so the
remote commit SHA differs from the local checkpoint. The original local history
is preserved under `scene/neon-reliquary-local-checkpoint`; the working scene
branch follows the published history. A documentation-only follow-up records
this publication without changing the validated implementation.

No merge into main is performed by this scene task. Applicable exact-head GitHub
integration results belong to the published review and are required before a
later merge; local passes are not substitutes for them.


## Integration with updated main

During publication, main advanced to **`a532daa70140aac163e5501051fe5afa1bcf377f`**
with ACT-001 actor prototypes from PR165. The published feature parent was
**`7021c49aa90a91128f1f0a15d8ba048450fdca67`**. PR167 consequently reported a
controller/documentation conflict. This follow-up integrates that main revision
into the scene branch; it does not merge the scene PR into main.

The merge preserves both controller lifecycles, all 64 portable class-cache
registrations, both scene retrieval questions, all three actor challenges and
both evidence histories. Desktop showcase requests now wait while the actor
selector owns input or an actor reset is awaiting acknowledgement. An optional
host method keeps this desktop condition out of the synchronous Web controller.
The actor launcher and panel participate in F8 clean-view visibility, and the
actor modal suppresses the world brush preview. Accepted MicroScenario setup
continues to clear ordinary actor ownership through the existing owner protocol.

The combined source passes **13 focused fixtures**: the four-district regression
now has **200 assertions**, the unchanged Neon regression has **89**, the three
ACT fixtures pass **12,293 / 626 / 157**, and all eight shared-controller fixtures
pass again. The eight new showcase assertions exercise actual modal admission,
pending actor installation, acknowledged runner creation, subsequent actor
clearing and HUD visibility. The first extended-test attempt had a GDScript
multiline-lambda parse error; adding parentheses to that test's boolean return
resolved it. Only that fixture required a retry. Its final run and the twelve
prior passes share identical production source and runtime identities.

Five fresh 1920 × 1080 Neon captures from the combined controller were reviewed
at paused tick zero. No actor launcher, popup, unexpected actor overlay or script
or renderer error appeared. The ordinary sampled player remains visible on its
landing. The same non-failing software V-Sync warning is retained. These checks
use the same pinned Linux engine, native library and Rapier identities recorded
above; all 30 native source inputs still match. The original twenty district
screenshots and earlier four-palette pixel evidence are preserved under their
original source scope, rather than relabelled as new integrated captures.

Post-integration documentation and provenance checks pass: **80 documents, 139
canonical claims, 1,368 local links**, all 18 required runtime files materialized,
and the same 18 historical M11 records / 28 source hashes. Retrieval hit@5 is
**32/32** for frozen questions and **41/41** for the combined challenges. SCENE01
and SCENE02 rank the scene guide first; ACT01/02/03 reach their canonical document
at ranks 2/1/1. The appended integration manifest records the commands, source
hashes, final and diagnosed results, and rendered review. Exact published-head
GitHub integration checks remain attached to PR167 and are required before a
later merge into main.


### Published integration review

The combined integration was published at
**`163fac04704a580d7339b1641f291e339075da11`**, tree
**`a0c3191c34cb6b8578569c27bf90146fa143e9bd`**. A fresh fetch verified the exact
local index/tree and both merge parents; the local branch then matched the
remote with a clean working tree. PR167 is open, ready for review and free of
merge conflicts. Its Documentation/provenance run **39111796032** passed.

The ready-for-review Native and GDExtension workflow wrappers reported success,
but inspecting their individual jobs showed that only the scope classifiers ran;
the runtime jobs were skipped. Both inherited scope writers append a literal
backslash-n to `GITHUB_OUTPUT`, so the resulting value does not match the exact
`true` required by their downstream conditions. These wrapper successes are not
recorded as native or Godot execution passes. This documentation-only publication
follow-up is pushed while the PR is ready, requesting the existing ordinary
`synchronize` validation path. It changes no scene source, test, runtime, workflow
or gate. Applicable exact-head execution remains pending in PR167 until the
actual jobs complete.
