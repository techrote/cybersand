---
title: Strata Theatre in the Shared Workbench
status: Current
document-kind: contract
scope: Opt-in four-plane authored composition, native import and construction, presentation-only atmosphere, ownership and versioned persistence
canonical-for: [workbench-strata-composition, workbench-strata-ownership, workbench-strata-persistence]
last-reviewed: 2026-11-28
related-documents: [strata-authoring.md, strata-environments.md, depth-layers-and-parallax.md, ../architecture/shared-workbench-authoring-data.md, ../operations/strata-workbench-evaluation.md, ../decisions/2026-11-14-owner-authoring-intent.md]
---

# Strata Theatre in the Shared Workbench

## Scope and disposition

The owner-accepted **STRATA-THEATRE-003** integration adds [optical presentation and the Strata Optics Lab](strata-optics.md) without changing the four-plane native ownership described here. Its explicit optical edit upgrades an authored document to v3; older documents retain Classic. The following Strata 002 ancestry and evidence remain independently preserved. The [combined integration guide](../operations/ramcache-strata-integration.md) owns final-main and evaluator qualification.

**Preserved predecessor:** STRATA-THEATRE-002 in
[PR #776](https://github.com/techrote/cybersand/pull/776) extends the immutable
[#769 predecessor](https://github.com/techrote/cybersand/pull/769), whose archival
head is `80623d039aa49bc0c1d84a9206d89812ffa99ea6`. Accepted main
`00cdb02f103265b6dc5224c68283e9a0c8cb449f` is retained in its ancestry. This
candidate adds reviewed local PNG/native import, reusable parts and finite
layered construction, bounded visual atmosphere and five native environments.
The [native authoring contract](strata-authoring.md) and
[environment contract](strata-environments.md) define those extensions. On 28 November 2026 the owner accepted optional Strata functionality on physical
Windows 11/NVIDIA hardware and authorized current-main reconciliation and merge.
Default activation remains excluded, and final combined-source qualification is
separate from the owner-tested predecessor.

The **Strata Theatre…** action in ordinary Shared Workbench opens its composition
panel. The default presentation, camera, simulation worker and render-publication
path remain unchanged until this option is enabled. Standalone Strata, Semantic
Depth and Deepworks remain separate tools with their earlier capabilities.

Source establishes implemented behavior. The
[successor decision packet](../audits/2026-11-24-strata-theatre-002/decision-packet.md) and the
[evaluation guide](../operations/strata-workbench-evaluation.md) distinguish
source review, native tests, actual graphical platform execution and physical
Windows 11/NVIDIA owner acceptance. Workflow existence is not platform evidence.

## Ownership and integration seam

The implementation choice was to adapt the existing presentation mechanisms at
the ordinary host boundary. Mounting `depth_lab.gd` would bring its independent
play owner and prototype controls with it. A new shared renderer or camera would
overlap the accepted-main/PUBPRES seam unnecessarily. The narrow adapter reuses
the depth compositor's transform math and native material surfaces, while a
three-plane owner adapts the existing runtime's private-candidate, copied-packet
and atomic-adoption pattern without acquiring Play.

| Recovered source | Reused mechanism and deliberate boundary |
| --- | --- |
| `depth_lab.gd` | Layer selection and presentation semantics informed the ordinary panel; the standalone host is never mounted |
| `semantic_depth_demo.gd`, `semantic_plane_runtime.gd` | Four explicit plane identities and separate owner/publication identities; no second semantic play World |
| `depth_layer_runtime.gd` | Candidate validation, generation/token fencing, copied publications and retirement pattern; historical clocks/events are not adopted |
| `depth_compositor.gd`, `depth_layer_surface.gd` | Reversible layer transforms and native material texture/shader composition; existing standalone defaults are retained |
| `shared_workbench.gd`, existing paint editor and native executor | Existing Play admission, camera, material semantics, actor ownership, Undo and named-save architecture |

The accepted GEN-005/semantic-plane examples and atlas compositions remain
available in their existing tools. The five successor examples use the same
admitted material palette and explicit native geometry. Their curated parts and
two source-pinned raster crops do not adopt an unaccepted Gold nomination or
regenerate a map corpus. Accepted GEN-007 and GEN-008 play sources remain
compatible through their existing owned baselines.

| Plane | Authoritative owner | Simulation and physics | Presentation source |
| --- | --- | --- | --- |
| `play` | Existing Workbench simulation worker and existing physical actor session | Ordinary configured native simulation and play-only Rapier actors | Existing play TextureRect, current/previous textures and shader parameters |
| `scripted` | One exclusive `WorkbenchLayerOwner` native World | Static authored materials; no actors or ticks | Validated copied RG8 publication |
| `effects` | One exclusive `WorkbenchLayerOwner` native World | Static atmospheric materials; no actors or ticks | Validated copied RG8 publication |
| `background` | One exclusive `WorkbenchLayerOwner` native World | Static distant materials; no actors or ticks | Validated copied RG8 publication |

`godot/scripts/depth/workbench_strata_controller.gd` is the narrow ordinary-host
adapter. It does not instantiate `depth_lab.gd`, the old synchronous four-World
host, another play World, a simulation thread, a physics space or a camera.
`workbench_layer_owner.gd` stages and owns exactly the three decorative Worlds.
Their schema rejects nonzero rates and nonstatic clocks. The `scripted` name is
retained for plane identity; it does not imply a scripting/event engine here.

`workbench_strata_presentation.gd` reuses the depth compositor's reversible
transform functions and `depth_layer_surface.gd` material surfaces. The latter
accepts an explicit backing extent for Workbench, preserving its existing 1024²
default for old callers. Workbench extent is 512–2048 cells per axis in multiples
of 64, including rectangular canvases. No scaling or truncation of authored
material data is hidden in the adapter.

The existing play drawable and actor overlays stay in the existing host. While
enabled, a private material derives its program from the accepted palette shader:
its copied LUT makes Empty transparent, and a validated final-fragment opacity
uniform hides or fades Play after material and sampled-actor shading. This is
necessary because the existing palette output does not consume Control alpha.
The shared shader file is unchanged. A second small private program scales the
existing additive Play glow's final RGB by the same opacity, so hidden emissive
Play cells leave no halo. The host's glow enable flag and viewport update policy
stay unchanged. Unknown insertion seams are refused during preparation, and
diagnostics retain source/variant hashes. One current derived program per kind
is cached; a staged replacement resolves the original sources instead of
wrapping an earlier Strata variant again.

The host's normal shader alias continues receiving current texture, actor and
camera updates. Disable restores both exact original material/program pairs and
host aliases with the current frame parameters. No second play upload, render ACK, worker scheduling policy or
global clock is introduced. PUBPRES #566/#609/#682/#757/#767 remains independently
owned and unimported. A future accepted presentation change needs qualification
at this adapter seam, not adoption of Strata's historical prototype clocks.

## Presentation and input policy

**Stack** composes the visible planes with bounded parallax and haze. **Flat**
inspects only the selected plane. Solo filters visibility further. Disable
returns to ordinary play presentation and ordinary play editing; it retains the
authored decorative layouts and settings for later enable and Save.
The saved layered Play lock/visibility/solo settings apply again on enable; they
do not restrict the ordinary play editor while Strata is off. Camera position
and zoom retain the ordinary Workbench lifecycle and are not serialized by the
layer envelope; built-in examples open in Overview after positive admission.

The selected plane is shown in both the composition panel and the ordinary paint
toolbar. Hidden, zero-opacity, locked or solo/flat-excluded planes receive no
material edits. A visible locked plane can be copied. Play depth stays zero so
the camera and actor/collision correspondence cannot diverge. Opacity is a visual
setting; transparent decoration never acquires physical collision authority.

The adapter derives view origin, extent and content rectangle from the accepted
Workbench camera. Its forward and inverse transformations use the same
world-centred parallax expression. Input uses actual local Control coordinates,
the view's letterboxed content rectangle and the same camera flooring as ordinary
play. Outside-canvas endpoints cancel a gesture; no edit is clamped into a
different plane merely because projected layers overlap. Pan/zoom remains owned
by Workbench. Layer or view-setting changes cancel an unfinished gesture.

Play uses the existing paint editor and native execution path. The three static
planes reuse its shape rasterizers and `workbench_paint_editor_executor.gd` for
native validation, authoritative before/after material readback and bounded
application. Supported tools are Brush, Eraser, Line, Rectangle, Outline and
Select/Copy/Paste. Fill remains a Play tool and is explicitly refused on a
decorative plane. Paste includes Empty and is refused as a whole if out of
bounds. Each decorative gesture/copy/paste admits at most 16,384 cells; each
brush gesture admits at most 1,024 sampled points and radius 0–24. Existing
native protected-boundary and material-ID checks remain authoritative.

## History and material state

Play Undo/Redo remains the existing manual/agent history with its normal native
source fences and simulation invalidation. A layer selection or presentation
toggle does not clear it. Each decorative plane retains up to 32 independent
static material edits. Undo/Redo affects that plane alone, advances its authored
revision and publishes only its changed material image. Changing selection,
opacity, depth, visibility or camera does not reconstruct a World.

Decorative document revisions identify authored material changes. Play continues
to use its existing authored source and worker generation/revision/tick; the
controller exposes those live values in diagnostics. The Play plane record's
preserved schema revision is metadata, not a live material counter or publication
fence. Save binds Play through `starting_setup` and `play_source`, with the complete
envelope checksum, rather than treating that metadata as its material authority.

Decorative planes do not evolve, so their recorded layout and native material
state remain aligned. This is not permission to reverse an evolved simulation.
Future independent simulation would need an explicit history/continuation
contract; unsupported clock fields are currently rejected.

Flatten retains its accepted GEN-008 meaning: a material-only play baseline
and explicit play-history replacement. It never merges the four visual planes.
While layered editing is enabled, select an editable Play plane before invoking
Flatten or Play-only Art authoring. Those actions refuse a hidden, locked or
non-Play edit target instead of silently acting on another plane's history.
Restore start reconstructs the existing play authored source while retaining
the decorative composition. An acknowledged ordinary new/loaded nonlayered
start clears its old decorative composition; a rejected replacement retains it.

## Candidate admission and failure containment

Preparation validates the complete versioned document, plane order/identity,
dimensions, material layouts, bounded construction work and all settings before
creating candidate native Worlds. All three initial copied packets and material
surfaces are prepared before requesting a play replacement. The old composition
remains active during this preparation.

The controller uses the ordinary `apply`/`installed` acknowledgement seam. Only
the positive native play installation adopts the already prepared decorative
Worlds and presentation. A refused play preparation cancels the decorative token
and frees its private resources. Cancellation, stale candidate tokens and
shutdown retire candidate ownership. There is at most one candidate composition.

Every decorative packet carries plane ID, owner identity, scene generation,
authored revision, extent and publication serial. The presentation adapter binds
these identities separately and rejects foreign owners, stale generation or
revision, duplicate/out-of-order serials and malformed/out-of-bounds bytes before
changing pixels. Caller-owned copies cannot mutate a retained packet cache.

A partial native decorative failure quarantines that plane and does not reset,
advance or otherwise mutate Play. Ordinary validation refusal retains a usable
unchanged plane. Partial native failure is not a successful authored edit. A
committed edit whose display publication fails is explicitly reported as committed
with stale pixels; Save retains the actual authored revision and further edits
wait for explicit reopen. The retained authored source remains available for explicit
reconstruction; no cross-plane material transfer or automatic event forwarding
is implemented. Native decorative material and animated visual motifs are separate categories.
Presentation-only haze, steam, rain, dust, beacons and machinery do not claim
native mass, hazards, physical lighting or transfer into the playable World.

## Persistent-area boundary

Strata and RAMCACHE are available from the same application but use separate
admitted hosts. The persistent-area host retains one continued Play World and an
exact authoring envelope. Strata's three static native decorative Worlds and
CYSSTRAT settings have no supported persistence codec in that profile. The
ordinary **Strata Theatre…** action visibly refuses there without creating a
Strata controller; direct controller preparation, load, enable, optics and Save
also refuse before creating native decorative candidates or modifying the
acknowledged manifest. Disabling layered presentation is not a way to smuggle a
retained layered document into that envelope.

Exit through the normal durable **Launcher** action, then open ordinary
Workbench to author Strata. Ordinary persistent painting, area travel, Save all,
reopen and recovery retain their original owner and storage contracts. The
combined boundary regression exercises refusal followed by real native edits,
area travel, durable Save and fresh-process readback.

## Versioned authored persistence

`workbench_layer_document.gd` adds a distinct `CYSSTRAT` envelope at the ordinary
named-start path. Load sniffs it before the unchanged Setup-v2, generated-start
and GEN-008 readers. Older nonlayered files keep their original readers.

| Envelope section | Meaning and limit |
| --- | --- |
| 52-byte header | Eight-byte magic, explicit version 1, 2 or 3, manifest/payload lengths, SHA-256 over both sections |
| UTF-8 JSON manifest, at most 8 MiB | Exact version-specific keys; unchanged starting Setup, four explicit plane records and presentation settings, identified play source; v2 adds authored atmosphere and operation provenance; v3 adds a complete validated optical configuration |
| Optional play payload, at most 8 MiB | Existing copied generated material bytes or exact GEN-008 uint16 material baseline bytes |
| Decorative layout | At most 32,768 existing material rectangles and 16,777,216 construction cell writes per plane |

V1 retains its original meaning, strict fields and encoding behavior. Explicit
upgrade to v2 supplies disabled empty atmosphere and empty authoring provenance.
V2 preserves numeric settings with full floating-point JSON precision; canonical
integer identities and floating visual parameters round-trip exactly. Unsupported
versions or unknown fields are refused, never silently discarded. No legacy
Setup, GEN-008 or RAMCACHE format is rewritten.

The scene declares `content_domain: authored-material-layout`. It persists all
four authored material layouts, settings and revisions, including when layered
presentation is disabled. Save does not silently sample evolved play cells,
discard Undo or flatten anything. To retain evolved play occupancy, use explicit
GEN-008 Flatten, then Save. Exact multi-World physical continuation, actor
velocities, native transient state and Undo stacks are not serialized.

Checksums, strict known-key/type validation, supported material IDs, exact plane
order, section lengths and source provenance are checked before adoption.
Unknown fields and unsupported state domains/clocks are refused. Write uses a
validated temporary file and the existing native same-directory atomic replace
operation; it does not delete the destination first. Process/I/O failure handling
does not claim filesystem power-loss durability. RAMCACHE formats, area streaming
and physical continuation formats remain unchanged and unconsumed.

For a generated play baseline, this envelope retains the exact previously
admitted native material bytes and their original recipe/provenance rather than
regenerating the recipe in a new process. This deliberately makes the saved
composition an authored-layout artifact. Its stored provenance identifies the
original generation; it is not a fresh qualification of today's generator.
Native ID/hash/extent admission still applies. The existing nonlayered
generated-start reader keeps its recipe regeneration behavior.

Model-assisted Art batches remain play-only in their existing subsystem. This
successor's all-plane authoring refers to explicit human native proposals and tools
in the Strata adapter; it does not authorize a provider to mutate decorative
Worlds. Read-only #770 schema compatibility is a bounded layer adapter, not a
qualification or absorption of the separate architecture application.

## Native authoring and visual motion extensions

The Import and Compose tabs use copied observations from the selected native
plane. Review occurs before writes. Owner approval binds source bytes, masks,
material permissions, plane ownership, native revision and authored Setup serial.
Operations execute through existing native authority in at most 4096-cell
chunks. Per-stage readback checks the complete region, including no-write cells.
Play preflight runs its existing history admission over that exact chunk sequence.
Stop retains and reports the acknowledged prefix; cross-plane atomicity is not
claimed. History remains a 32-entry window per plane, with displacement warnings.

Atmosphere is a child of the existing decorative drawable. It inherits the same
transform, clipping, opacity and visibility. Six bounded motif kinds share at
most twelve regions and 384 motifs; a plane has no recurring effect callback
when excluded, disabled or paused. Geometry, native clocks, actor authority and
material history are unchanged. Seeds and settings are authored and saved;
visual phase is transient and starts fresh on reopen. The existing three native
decorative Worlds remain static, paused and zero Hz. Optional native decorative
dynamics are not delivered in this candidate.

## Cost boundary and qualification

No Strata owner, surface or per-frame callback exists on default startup. Opening
the panel is lazy; the first composition setting change, enabling, or explicit
layered load prepares its native planes. Static planes never tick and never request recurring native
publications. A dirty admitted plane uploads its complete RG8 backing once; a
2048² upload is 8 MiB. Frozen material surfaces bake when an admitted changed
publication becomes visible. Camera/parallax changes reuse those surfaces.

Cached resources remain bounded while disabled so toggles preserve edits. Three
additional Worlds and three RG8/RGBA presentation surfaces are real memory costs;
staging a replacement temporarily retains both old and candidate resources.
Callback measurements, allocation accounting and software-renderer frame
intervals are separately labelled. None establishes physical GPU FPS or smooth
owner interaction. Source-bound graphical qualification, pristine Windows
package execution and owner Windows/NVIDIA evaluation remain distinct gates.
