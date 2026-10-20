---
title: Deepworks full-map exhibition implementation and validation
status: Current
document-kind: audit
scope: 2026-10-20 single 1024-square four-plane exhibition, native material apparatus and Linux rendered validation
canonical-for: []
last-reviewed: 2026-10-20
related-documents: [../operations/deepworks-exhibition.md, ../systems/depth-layers-and-parallax.md, ../systems/building-material-catalogue.md, ../reference/validation-evidence.md]
---

# Deepworks — the exhibition below

## Later reaction-evidence correction — 2026-10-20

The [PR #185 completion audit](2026-10-20-deepworks-pr185-completion.md)
invalidates this checkpoint's native-reaction pass. Its retained local log and
both hosted platforms contain two script errors that omitted eight A1 flow
assertions. The old 626-plus-one summary and `verified` flags are not accepted
reaction evidence. Restored checks exposed a blocked rear Stone feed, repaired
without changing native material rules or weakening the transport oracle.
The original JSON, observations, images and hashes remain historical; use the
completion audit for corrected reaction, UI and final hosted acceptance.

## Request, source and recovery boundary

The owner requested one **1024 × 1024 total-size map**, many themed areas and
physics/chemical exhibition setups, complete Depth Lab quality multilayer
coverage, foreground and background scripted material activity, and small
decorative details. The reference inputs were [Grey Area 51, PR #184](https://github.com/techrote/cybersand/pull/184),
[Blacksite Nine, PR #175](https://github.com/techrote/cybersand/pull/175) and
[Neon Reliquary descent, PR #167](https://github.com/techrote/cybersand/pull/167).
The explicitly required [new materials, PR #179](https://github.com/techrote/cybersand/pull/179)
were read before apparatus construction, together with the accepted native rules
and the canonical themed-construction material contract.

The implementation branch is `scene/deepworks-exhibition-1024`, based on verified
merged main **`fc015a77d3b851fef4ea7734923bcdb3762a19a5`**, tree
`75dad6c487b508602fff9bacb200814a1fde682f`. PR #179 was already merged; its
accepted head was `1937e5f6e8793a8d86b9d332512b0dcc308b7fc8`. PR #184 was still
a draft reference, so none of its unmerged source is required by this scene.
The working source is an isolated checkout under
`/workspace/scratch/4a1b7cbb1f67/cybersand`; no existing user edits were replaced.

The [evidence manifest](2026-10-20-deepworks-exhibition-evidence.json) binds the
base revision plus changed executable files, recipe, material runtimes, tested
commands and retained images. Local implementation commit
`c001acef145830124496da67064932565f9acea7` is the recoverable executable-source
checkpoint; the subsequent review commit adds the pixel gate, documentation
and rendered evidence. The initial local clone contained incomplete
historical Git objects; a full `git fetch --refetch --no-tags` from its existing
origin repaired those objects, and the subsequent connectivity check passed.
This repair changed no working source. All 18 required LFS payloads were
materialized; native libraries, dependency pins and historical attestations
remain unchanged.

The command-line push had no GitHub credential helper. Publication therefore
uses the connected GitHub object API. Published implementation commit
[`4f40308f9d62dffd6640971e0fb30cc3c456220c`](https://github.com/techrote/cybersand/commit/4f40308f9d62dffd6640971e0fb30cc3c456220c)
has tree `3bfd6f3608c81dc03f1106ef709b25d7052cc394`, exactly matching local
`c001ace`. The differing commit identities record publication metadata, not a
source reconstruction. Every uploaded image is verified against its local Git
blob identity; the complete review tree is compared before the new branch is
published. The PR records the final remote head and hosted-check status.

## Implemented exhibition

There are sixteen 256-square districts in a four-by-four layout. Their **shared
extent is 1024 × 1024**, with 24 actual foreground openings across orthogonal
district seams. Each of the four native planes covers that complete extent:

| Plane | Ownership and role | Configured rate |
|---|---|---:|
| `play` | Foreground architecture and sixteen native exhibit vessels | 30 Hz |
| `scripted` | Independent rear machinery and sixteen native exhibit vessels | 20 Hz |
| `effects` | Locally contained native atmosphere with sources and drains | 15 Hz |
| `background` | Complete distant material architecture, cached and frozen | 0 Hz |

The 32 primary exhibits cover granular transport, Metal charge, snow thawing,
halite dissolution, brine evaporation, corrosion, acid/stone conversion,
clay/adobe firing, glass remelting and quenching, thermite/magnesium ignition,
lime casting, erosion, combustion, polymer/wax reclamation, sludge purification,
plant/fungus growth and separated liquids. All 51 new material IDs 81–131 survive
in the final foreground, including isolated specimen niches and themed fittings.
The canonical [scene guide](../operations/deepworks-exhibition.md) owns the
district catalogue and controls.

Sources install **reactants**, immediately before their target world's native
tick. Native kernels produce the advertised results. Finite chemical feeds
leave products available for inspection; repeating atmospheric sources have
bounded local drains. Event definitions are validated before replacing any
world. The scheduler bounds event count, rectangle area, timing and aggregate
per-layer writes, and rejects frozen-background sources, unsupported effects
materials, invalid IDs and out-of-district rectangles. Reset invalidates prior
sources, queued edits and publication generations.

Acid-contact containment is actual Wall. Decorative Brass/Copper panels do not
substitute for the actual Metal electrodes. Fungus uses its actual Wood/Oak
Timber substrates. Thermite and magnesium demonstrations show the native hot
material conversions; no new pressure or explosion model is implied.

The dedicated free-camera scene reuses the isolated Depth Lab owner. It has
overview, sixteen district stops, separate foreground/rear close-ups, guided
tour, five depth modes, layer toggles and native painting on either chemical
plane. It starts paused. Reset restores the whole complex while preserving the
selected viewpoint. The tour changes camera every fourteen running seconds;
later stops can contain already-evolved products, so Reset then Run replays a
selected room. This host does not attach the ordinary sandbox's player/actor
session or its asynchronous desktop owner.

## Shared depth changes and review findings

The native backing was already 1024-square, but Depth Lab rendering and authored
interest were fixed to 640 × 360. Runtime, compositor and material surfaces now
accept dimensions from 8 through 1024 on each axis, including nonsquare worlds.
Their original 640 × 360 defaults remain. Camera extents and pointer inverses
use the configured authored dimensions. MAT-002 glass, timber and hard surfaces
receive appropriate relief categories. A publication from an older reset
generation is rejected before it can change the receiving surface.

The final implementation incorporates findings from independent material,
architecture and depth reviews:

- A Brine evaporator's original pilot missed its settled feed. Moving the
  pilot below the settled surface made the native Salt/Steam conversion visible
  and restored the full-map reaction test.
- Near-INT32_MAX `Rect2i` coordinates could overflow an enclosure check.
  Widened scalar bounds now precede rectangle arithmetic, with explicit
  rejection/atomicity controls.
- Publication failures could be followed by a success/status update. Host
  publication now returns a result that stops reset, step, paint and frame
  paths; a fault also freezes presentation animation.
- The first guide capture exposed a wrapped-text minimum-size feedback loop
  that expanded the header over the map. Fixed single-line header labels and
  shrink-centred controls resolve it; both geometry and actual-pixel checks
  cover the guide's visibility.
- Original atmospheric risers were hidden behind a foreground divider. They
  were relocated to the clear right-side galleries. Air visibility is checked
  against rendered pixels, excluding their static Wall containment.
- Dark Glass across broad distant voids produced distracting diagonal glazing.
  Matte Heat-Shield Tile, Carbon Fibre and selected Charred Timber now supply
  those shadows; real windows retain glass. The Reliquary's Slate-backed arch
  separates pale reactive specimens from the distant masonry.

## Local validation and rendered evidence

Execution uses Linux x86_64, Godot **4.7.stable.official.5b4e0cb0f**, the accepted
MAT-002 native extension, and retained Rapier 0.35.2. Native planes use one
worker each. Rendered checks use Xvfb and Mesa llvmpipe with Compatibility
OpenGL and Dummy audio. Focused tests have timeouts up to 180 seconds; the complete
capture has a separate, recorded budget. Exact executable/library hashes,
commands, individual outcomes and source deltas are in the evidence manifest.

| Gate | Accepted local result |
|---|---|
| Full map, passage, authoring capacity and source programme | 304 assertions, zero failures |
| Camera, painting, reset, tour, pause and guide controls | 196 assertions, zero failures |
| Launcher destinations and F2 return | 35 assertions, zero failures |
| Direct `--deepworks`, launcher return and subsequent sandbox | Passed |
| Full-map native reactions | 32 exhibits, 360 ticks per active plane; 626 simulation assertions plus one evidence-write check, zero failures |
| Parameterized depth dimensions | 541 checks, zero failures |
| Retained depth runtime / lab | 83 / 17 checks, zero failures |
| Depth compositor including stale-generation rejection | 19 checks, zero failures |
| Actual far-corner pixels and new-material relief | 32 checks, zero failures |
| Retained material-surface pixel oracle | Zero failures |
| Full-map rendered layer contributions and guide visibility | 173 checks, zero failures and zero artifact errors; 127.594 seconds within 175-second budget |
| Documentation and current provenance | Passed; 93 documents, 178 canonical claims, 1,905 local links and all 18 materialized runtimes |
| Historical M11 integrity | Passed; 18 records and 28 historical hashes |
| Retrieval canonical top-five | Frozen 32/32; prior supplementary 77/77; two new questions 2/2 |

Reaction checks use copied native packets from the **complete composed map**.
They require advertised products to be absent both initially and from source
inputs. Transport must reach away from its nozzles; combustion must consume
fuel; purification must remove authored Toxic Sludge; fungus must grow beyond
all injected Fungus while consuming its real timber substrate. This prevents
static decoration or a source painting a claimed product from passing as a
chemical observation.

The retained [atlas](../images/deepworks/deepworks-atlas.png) is an actual
2048-square rendering of the 1024-square map at two screen pixels per cell.
Sixteen 512-square crops are exact regions of that atlas. The
[guide view](../images/deepworks/deepworks-guide.png), individual plane images,
selected close-ups and post-reaction views come from the actual scene and
material compositor. Their recipe identity and image hashes are retained.
All 34 image dimensions and hashes match the capture manifest; the sixteen
atlas crops also match the corresponding unmodified pixel regions exactly.

The full-map pixel gate measures visible rear and far-layer contributions in
every district against matched hidden-layer images. Rear contributions range
from 6,181 to 9,989 pixels per district; far architecture contributes 25,192 to
33,161. It then advances only atmosphere and observes each district's automatic
source at its first native pulse, excluding Empty and static Wall cells from
the pixel witness. Every source has four or six visibly different native air
pixels. The foreground, rear and far native ticks remain zero during that air
check. Headers are 84 pixels high at both tested guide sizes, and more than
99.6% of the map area changes against the all-hidden baseline.

Earlier unsuccessful attempts remain recorded: initial class-name collision,
unwritable default user-data path, headless inverse-transform mismatch, a
render attempt with ALSA errors, a stopped X server during capture, and the
guide/riser presentation defects described above. Those attempts are excluded
from accepted run counts. The final graphical runs use Dummy audio; Xvfb's
unsupported V-Sync warning is distinguished from engine/script errors.
The first documentation check also found five missing companion-workspace
inputs referenced by the unchanged frozen questions. The exact retained files
were recovered from the accepted PR #179 workspace and verified byte-for-byte;
the evidence manifest records their paths and hashes. No frozen question,
historical artifact or checker was weakened to make that check pass.

## Documentation checklist and acceptance limits

| Contract area | Change or disposition |
|---|---|
| User controls, exhibit catalogue, source replay | Canonical Deepworks guide, launcher and README routes |
| Depth subsystem, ownership/lifetime and interface invariants | Configured dimensions, exclusive four-world ownership, immutable publication and stale-generation guard |
| Configuration and capacity | Authored dimensions, layer rates and explicit source budgets |
| Materials and native ABI | Existing accepted rules reused; no new material IDs, kernel changes or native interface changes |
| ADRs and programme order | No decision, provider, physics acceptance or programme dependency changes |
| Roadmap, build/test guide and RAG | Current scope, discovered graphical tests, corpus/index routes and supplementary questions updated |
| Historical records and artifacts | Preserved; this audit supplies new Linux source-matched evidence |

The frozen 32 retrieval questions are preserved. New scene/dimension questions
are disclosed separately from that frozen set; wording affected by the old
fixed-size and fixed-render-test-count assumptions is reconciled explicitly.
Lexical retrieval results establish the tested documentation routes, not
unseen semantic retrieval quality.
Frozen top-one retrieval is 21/32, with MRR@5 0.7953. The combined supplementary
set has 62/79 top-one, 79/79 top-five and MRR@5 0.8728; both new questions rank
first. The existing DEP01 and TEST03 expected facts are the only previous
supplementary facts updated; existing queries and the frozen 32-question bytes
are unchanged. Documentation and repository checks report no errors or warnings.

This is Linux native/rendered scene evidence. No new Windows/macOS execution,
browser/WebAssembly export, hardware-GPU, target-PC frame-budget or actor
traversal acceptance is claimed. Changed material publication still uploads
complete RG8 backing images; frozen architecture uses the existing cache and
one-shot bake. Independent layer clocks retain the bounded catch-up policy.
Exact-head GitHub-hosted checks are a separate publication/merge gate; this
scene task does not merge the branch into main.
