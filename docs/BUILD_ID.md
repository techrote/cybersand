---
title: Build identity
status: Current
scope: Exact m9 checkpoint identifier, source hashes, validation results, GPU cost envelope, and known limits
keywords: [build ID, SHA-256, GPU flair, neighbour relief, dual-radius bloom, 1920x1080, debug stats, RG8, Windows x86_64]
related-documents: [README.md, systems/themed-construction-materials.md, systems/material-appearance-and-rendering.md, reference/status-and-roadmap.md]
last-reviewed: 2026-08-28
implementation-state: Exact source metadata for m9-gpu-flair42-relief-bloom-fhd-win64-2026-08-28; m8 simulation/native binaries are retained while 42 GPU flair classes, neighbour-derived relief, dual-radius bloom, F3 stats visibility, and 1920x1080 output are bundled.
---

# Build identity

## At a glance

- **Current**: build identity is `m9-gpu-flair42-relief-bloom-fhd-win64-2026-08-28`.
- **Current**: bundled Linux and Windows x86_64 builds select native phased World through a `godot-cpp` GDExtension.
- **Current**: authoritative cells remain four bytes; no RGB, HSV, or variation seed was added to simulation storage.
- **Current**: native publication projects dirty RG8 material/condition patches into copied Godot value arrays.
- **Current**: a 64×256 palette atlas and four-texel-per-material program LUT derive appearance on the GPU.
- **Current**: 43 construction IDs extend the catalogue through 80; 41 are inert radius-zero hard surfaces and Oak Timber/Thatch reuse bounded combustion.
- **Current**: 42 analytic flair classes reuse program texel 3 alpha without another simulation byte, program texel, or palette row.
- **Current**: powders, Smoke, Steam, Foam, organics, Ice, reactive liquids, Mercury, charged Metal, and Cloner now have specialized bounded GPU programs.
- **Current**: four-neighbour RG8 reads derive structural bevels, liquid lips, and contact shadows through an alias of the existing world texture; no image/upload was added.
- **Current**: stable coordinate texture never uses authoritative epochs or frame-random noise; bounded glint/sheens/neon use presentation time only.
- **Current**: primary motion remains full rate; secondary lifecycle, chemistry, thermal, growth/capture, smoke-cull, and ambient-ignition work uses spatially staggered lanes.
- **Current**: Smoke starts with lifetime 240, thins faster in dense clouds, cannot ignite, and projects lifetime into the existing RG8 condition channel.
- **Current**: 64×64 hard-terrain packets reduce the indivisible collider rebuild area to one quarter of m7's 128×128 packet.
- **Current**: rough/hammered metal sparkle is removed; smooth manufactured metals glint, and most liquids animate existing arithmetic bands without extra texture samples.
- **Current**: HDR emission feeds a thirteen-position half-resolution source and thirteen-tap dual-radius composite; `G` disables both the overlay and its render updates.
- **Current**: `F3` hides/restores the debug readout and skips status string construction while hidden; default output is 1920×1080.
- **Current**: 39 native tests, ASan/UBSan, TSan, 42-class LUT, presentation controls, dirty bridge, and a 180-frame scene smoke pass on Godot 4.7 Linux x86_64.
- **Current**, platform partial: the Windows DLL is cross-built and structurally validated but has not been launched in Windows Godot here.
- **Planned**: true GPU texture-subregion submission and an artist-facing appearance-graph compiler.

## Search anchors

current build ID, source hash, dirty RG8, material appearance LUT, GPU flair, neighbour relief, dual-radius bloom, F3 stats, 1920x1080, Windows native bridge

## Identity

- Build: `m9-gpu-flair42-relief-bloom-fhd-win64-2026-08-28`
- Date: 2026-08-28 UTC
- Native language level: C++20
- Godot runtime tested: `4.7.stable.official.5b4e0cb0f`, Linux x86_64
- Windows native target: PE32+ x86-64, MinGW-w64 GCC 13 POSIX threading, statically linked GCC/C++/thread runtimes
- Godot Rapier Physics: official 2D single v0.35.2
- `godot-cpp`: v10/master snapshot generated for Godot API 4.7; exact upstream commit is not pinned
- Sandspiel reference commit: `dc77827b36adc5c04ea063515de4173ce28dbf2c`
- Sandspiel Studio reference commit: `b78f89ec908192bb689af31ef83c3ec2ee46c74b`
- AuraLite Powder reference commit: `34f889873765201d2912185a1f680aa75ed69b8a`
- Third-party notices are retained in `THIRD_PARTY_NOTICES.md` and addon directories.

## Rendering checkpoint

The native bridge now publishes material ID plus one read-only visual-condition
byte selected per material from `state_a`, `state_b`, or zero. Ordinary changed
frames copy accumulated dirty rectangles rather than the complete world. The
worker retains unacknowledged deltas and replaces excessive pending data with a
bounded complete recovery packet.

Godot patches a persistent RG8 CPU image, then ping-pongs two textures for
presentation-only temporal smoothing. The palette shader selects stable
coordinate-hashed variants and executes bounded condition plus flair programs.
The reserved final-program alpha now selects one of 42 analytic finishes. A
common four-neighbour stage reads a named alias of the current RG8 texture for
pixel relief. A half-resolution thirteen-position emission source and a
thirteen-tap filtered composite produce wide HDR glow without one `Light2D` per
cell or another render target.

The current `ImageTexture.update(image)` still submits the complete
1024×1024 RG8 backing image after a changed render publication. Patch KiB in the
status overlay measures bridge payload, not GPU upload bytes.

## Executed validation

| Validation | Result | Notes |
|---|---|---|
| Native behavioral/catalogue suite | Pass | 39/39, including Smoke lifetime/Fire exclusion, staggered contact windows, IDs 38–80, hard surfaces, and C API |
| ASan+UBSan | Pass, leak detection disabled | 39/39; hosted `/proc` restrictions still prevent LeakSanitizer |
| TSan | Pass | 39/39 with `halt_on_error=1` |
| Native Linux x86_64 GDExtension | Retained/pass | Bit-identical m8 binary loaded by every Godot regression; native source did not change |
| Native Windows x86_64 GDExtension | Retained/structural | Bit-identical m8 PE32+ x86-64 DLL; native source did not change |
| Appearance LUT regression | Pass | 81 rows, 42 flair classes, specialized gas/foam/reactive/metal mappings, 1920×1080, and 256 hard packets |
| Presentation controls regression | Pass | Actual main scene hides/restores stats with F3 and exposes all four 1920×1080 project settings |
| Focused RenderBridge regression | Pass | Full recovery: 2,097,152 bytes; radius-one Water edit: 18 bytes in one patch |
| Complete-scene smoke | Pass | Main scene and both material shaders ran headlessly for 180 frames without reported error |
| m7/m8 native benchmark comparison | Directional improvement | Five interleaved dense eight-worker runs: median m7 7.06 ms, m8 5.91 ms; ranges overlap under hosted contention |
| GDScript fallback interaction suite | Inherited known failure | Newborn Smoke displacement passes; wide-Water leveling still fails identically in m7 and m8 |
| GPU cost accounting | Source-bounded; timing unavailable | +4 common neighbour reads; emission 9→13 low-resolution positions; composite 1→13 filtered taps; no new publication bytes/image |
| Manual visual/GPU/collider profile | Partial user evidence only | Target GPU timing/visual pass and m9 Windows collider reprofile remain required |
| Windows Godot runtime | Not executed | Hosted validation environment is Linux |

## Key source hashes

| File | SHA-256 |
|---|---|
| `native/include/cybersand/material.hpp` | `de1bbbccb812d49151c34831196a7e38d5ee97d2045c9b29c197b11553ed126a` |
| `native/include/cybersand/material_rules.hpp` | `4c9e74a00d732bf624c57936a0e03de47195929830d1ff5923107df18188beac` |
| `native/include/cybersand/material_appearance.hpp` | `323078293cd572ac8cb1282cb57c4298644010d04d0504617637049d639351c7` |
| `native/include/cybersand/world.hpp` | `17272a5f35547cea6ac7a976ebefc6219bfdc56eeb964035e5172011859c1b02` |
| `native/src/material_rules.cpp` | `193ba45b403c1b95cf505a9e4a0679637af117bdc002cad7f3169f7179f4b7c7` |
| `native/src/world.cpp` | `3c6212cfc2755b600f690f2cb8485f78a48198e17358f620af55299179f01634` |
| `native/tests/test_world.cpp` | `6bb3aba5d5d96c6846546d3ef37047d3bfc7d6de1b76befc7ecc55eef1e9c401` |
| `native/src/render_snapshot.cpp` | `b905363461d4aa31ffbeb94bd6717993597b9da23b5ea5d8fc717a56662dbf04` |
| `godot/native_extension/cyber_native_cell_world.hpp` | `c474438ddf93ad366bf1c35523722e335a7fd89710b90e1ec6a67a01a80add35` |
| `godot/native_extension/cyber_native_cell_world.cpp` | `15b996ee0beb2418f27f3c3e40c6d37d901d81670c0dc7c5d0ead3ffb2614f5f` |
| `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so` | `5dba08fa93a1b23d19bc5071f8cf2da4731bb1e03471003e5780134e3d40f608` |
| `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll` | `6bccce10c04b3fda2e75f7199c4ff8ceb22de0c8378a5c0aa1a0a84976c4c117` |
| `godot/scripts/simulation_worker.gd` | `79c3270825a033c8fdb12843183d0caa24de5f9d9ca54ae85d463da959bf4b68` |
| `godot/scripts/simulation_snapshot.gd` | `b64e737273fe9361b07235eff80b1a242d1e04993925337eb1300770e99ad2a2` |
| `godot/scripts/cell_world.gd` | `8e7778312402a51f7c195b4e5682499b017cf1599e2ee3120cfc931302ee7add` |
| `godot/scripts/material_appearance_lut.gd` | `93b6e43d03d13892b8f28256b76085b7ee9daa07582ea2f6a483f9b52b0d1fce` |
| `godot/scripts/main.gd` | `9a7bf97b401003d0a6c6960eef0cb0c586098f12a4a00da0e1fb38da6794bf8c` |
| `godot/scripts/rapier_physics_bridge.gd` | `f35ff545d817c363913f6f4bc01e838f130abcce023ca143d8edd191b04194b9` |
| `godot/shaders/material_palette.gdshader` | `7a11b70e6b94fba4d3d377378c31debef3d26562b64b78066f5a9893e72053ea` |
| `godot/shaders/material_emission.gdshader` | `3b1148cdb99113bd172f1cb64e7d6c48ad86c33980739c571111aab479b15668` |
| `godot/shaders/glow_composite.gdshader` | `0685d7df435b76860facfde0bd604e9cfa2e1dbce8a86ae4063b7def67accccf` |
| `godot/tests/test_native_render_bridge_regression.gd` | `48244b821dfa5eee6014792954aa30ee0ea1c7dd557618d1c65d5c7190dfe317` |
| `godot/tests/test_material_appearance_lut.gd` | `9cd404a3f3350ac7b2586cd08d4b52c650c24f01bd2652fb3d84743060297bbe` |
| `godot/tests/test_presentation_controls.gd` | `bf31bce110146e677529d1f4c2167ddc902752e8aed6a718cbe226c3c85e282e` |
| `godot/project.godot` | `d6c35ab2fafb716f9030a0d108d7c6ea827549e615f9cbfd64b478363b01ad5e` |
| `godot/main.tscn` | `0afbf458f7d7a5df9c906d28d0bcef714010fef9d7021c12b8783c654f302067` |

## Known limits

- Windows x86_64 requires an actual Windows Godot runtime launch.
- Architectures other than Linux/Windows x86_64 use the GDScript fallback and R8 rendering.
- GPU texture submission is still a full 2 MiB RG8 update for each changed render publication.
- Creating one temporary Godot `Image` per dirty patch is functional, not yet allocation-profiled.
- Appearance profiles/flair mappings are compiled from hardcoded GDScript rows; no graph asset, editor, orientation field, overlay layer, or hot reload exists.
- Only one condition byte is projected per cell. Future optional fields need explicit bounded projection rules rather than direct exposure.
- Flair/glow quality, HDR behavior, neighbour-sampling cost, mixed-branch cost, and flicker accessibility have not been visually profiled on target hardware.
- Rigid-body coupling remains rectangular and approximate. Collider packet granularity changed, but the reported target-Windows peak has not yet been remeasured.
- The exact `godot-cpp` upstream commit must be pinned before reproducible release builds.

## Related decisions

- [Material appearance and rendering](systems/material-appearance-and-rendering.md)
- [Themed construction materials](systems/themed-construction-materials.md)
- [Rendering and gameplay bridges](architecture/rendering-and-gameplay-bridges.md)
- [Status and roadmap](reference/status-and-roadmap.md)
- [Testing and replay](operations/testing-validation-and-replay.md)
- [ADR-003](decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
