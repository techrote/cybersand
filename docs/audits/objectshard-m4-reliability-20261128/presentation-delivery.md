---
title: ObjectShard M4 reliability convergence — presentation and delivery evidence
status: Historical record
document-kind: audit
scope: 28 November candidate rendering repairs, staged graphical evidence, owner route and portable evaluator qualification
canonical-for: []
last-reviewed: 2026-11-28
related-documents: [../../research/objectshard-m4-workbench.md, ../../operations/objectshard-workbench-playtest.md, physics.md]
---

# Presentation and evaluator qualification

**Current disposition: corrective implementation in progress; Draft/HOLD.**
This packet records source-bound evidence as it completes. A passing renderer
fixture is not physical-owner acceptance or qualification of a later native
build. The final candidate and portable evaluator remain subject to the
combined campaign and clean extracted execution.

## Confirmed causes and bounded corrections

| Observed problem | Confirmed source mechanism | Correction |
| --- | --- | --- |
| Camera anomalies after protective Held | `object_shard_m4_runtime.poll()` exits before its overlay redraw when Held, while the ordinary terrain camera continues changing. Retained CanvasItem draw commands therefore retain the old transform. | Overlay synchronizes view independently, including Held/paused operation, against the actual terrain shader's camera/extent/content uniforms. Material publication and physical time do not change. |
| Structural pixels outside the World image | Original overlay clips the complete World control, although terrain uses an aspect-fitted content rectangle inside it. | A content clip with the identical terrain rectangle contains a camera transform and bounded per-body sprites. |
| Flat detached brick/timber | Original overlay samples native base RGBA palette bytes, bypassing the ordinary material LUT/program, neighborhood relief and structured finishes. | Native supplies the existing ordinary RG8 `project_visual_state` projection; one shared shader variant reuses ordinary finish functions. Sampling remains anchored to captured material coordinates through body rotation. Empty carriers are transparent, and ordinary actor/background decoration stays with its original owner. |
| Rapidly oscillating status | Principal status directly prints low-level `runtime.phase`. | Group normal phases as Running, distinguish Paused/Pausing, debounce rebuilding, expose sustained native waits, and put an actionable Held reason first in the two-line status. Raw phases remain in the tooltip and JSON diagnostics. |
| Paused publication stalls after protected/no-op Erase | The native facade counted an accepted unchanged Empty edit as a mutation. Its revision advanced without changed World bytes or a new render serial, leaving valid display/owner fences unable to meet. | The final native facade repair uses the coordinator's actual World material revision to detect changes; protected ownership and presentation fences remain intact. The new flag-free brush-revision fixture verifies no-op/protected edits and genuine material/condition changes. |

The native RG8 snapshot is immutable and cached by material revision alongside
existing copied carrier channels. Shader parameters and texture allocations
are reused for stable owners; pose-only publications do not upload material
textures. No live Rapier transform or mutable worker storage is sampled by the
presentation. The shader's ordinary default branch remains unchanged. The
existing 16-body admission limit bounds visual nodes; no per-cell nodes or new
render/simulation owner are introduced.

Exact detached appearance can legitimately expose new edges where a structure
has separated from neighboring terrain. No new Strata optical integration,
interpolation, buoyancy or fluid-resistance architecture is claimed.

Native `Registry::prepare_fragment` stores child capture bounds at parent bounds
plus a local crop offset; `Coordinator::capture_fragment` rotates that offset
into the child's physical pose. Parent bounds remain stable on ordinary geometry
edits. The renderer uses capture origin plus local pixel for finish coordinates,
so recropping does not restart brick/wood pattern phase. The expanded paired
framebuffer fixture exercises a two-cell cut, a cropped child and quarter-turn
rotation. Its first-use timings draw the ordinary shader alone before creating
the detached variant, distinguishing their setup/first-frame costs without
calling capture latency a steady-state frame cost.

## Early source-bound renderer smoke

Implementation commit `e702b6029de3387cc83d0c4f5c0efd9bb95bd895` was integrated
as application `60a71358de549877d65d0bcac08ef6e8bb1573c0`, tree
`570492828ca43c8be38a9bce91eeda015cd25c88`. The explicit
`[objectshard-m4-presentation]` marker arms only two literal hosted-runner
presentation jobs in the existing workflow. It cannot publish runtimes and
does not arm the full native campaign.

[Run 46091912379](https://github.com/techrote/cybersand/actions/runs/46091912379)
uses pinned Godot `4.7.stable.official.5b4e0cb0f`. Project loading uses the
committed historical native runtime; all new visual inputs in this early lane
are explicitly synthetic immutable publications. This is not a native build
pass for changed source.

| Early gate | Actual disposition |
| --- | --- |
| Local pinned 4.7 import and existing palette compiler guard | PASS; 27 shader-structure assertions. |
| Linux OpenGL/Mesa actual renderer | PASS; import 9.684 s, texture-incarnation test 11 checks / 1.567 s, new material/view test 19 checks / 6.478 s. |
| Windows ANGLE/D3D11 | PASS; import 12.433 s, texture-incarnation 11 checks / 4.133 s, material/view 19 checks / 89.700 s (includes shader compilation). |

The new actual-framebuffer test compares occupied pixels to an independent
ordinary-terrain render of the same copied material/condition data, requiring
residual at most 2/255. It covers the initial detached view, a quarter-turn
rotation, material edit, retained-publication pan/zoom and letterboxing, empty
holes and retirement. It requires substantial textured pixel/color diversity,
so flat rendering cannot pass solely through broad equality. Source-era RGBA
texture-incarnation coverage remains intact. Raw framebuffer captures are
retained in the run artifact; selected [ordinary](presentation-smoke/ordinary-materials.png),
[detached](presentation-smoke/detached-materials.png), and
[rotated](presentation-smoke/rotated-materials.png) views were visually inspected.

The independently downloaded Linux artifact is
[15241082679](https://github.com/techrote/cybersand/actions/runs/46091912379/artifacts/15241082679),
39,074 bytes, SHA-256
`0523dbad33a4c5dba70eac61f2874c0f88c591304943648fd0934ef9f30b8eb1`.
Its complete [summary](presentation-smoke/linux-summary.json) records the
loaded historical native build `efe3bc19c68a9b9e292821ef28b735caec538915` and
Linux binary SHA-256
`5fdf1e8f60f7fd93090ce4d924544c5f7aa9393e565af6b85a4e15e73d63ba20`.

The independently downloaded Windows artifact is
[15241034380](https://github.com/techrote/cybersand/actions/runs/46091912379/artifacts/15241034380),
38,117 bytes, SHA-256
`9ce460d503f8b9c8d92dde4adb7ccca38bfbc5c5618ec5a9febf57499357cb39`.
Its [complete summary](presentation-smoke/windows-summary.json) records actual
ANGLE execution. The 89.700-second whole test includes first-use shader
compilation and captures; it is not per-frame cost or physical monitor FPS.
Both explicit smoke jobs passed, and every full native/publication job was
correctly skipped. No native result is inferred from that run.

Local actual rendering was unavailable because no Xvfb executable was present
and Xorg could not open an allowed local display socket. Headless parser or
transform checks are therefore not reported as local framebuffer passes.

The mounted local camera follow-up additionally checks a restored authored
canvas while still paused before its first native tick: old owned visuals are
absent and camera navigation remains usable. Its status explicitly says
**Paused · Play to start structures**. This is inspectability evidence, not a
claim that the fresh structural transaction is already physics-ready. The
expanded source fixtures require fresh source-bound hosted qualification;
the early 19-check renderer result above remains scoped to its earlier source.

The combined local A+B+C mounted follow-up passes **208 checks** with no
incoherent callback observations ([complete development receipt](presentation-smoke/local-mounted-held-lease.json)).
It adds a 1,024-cell World viewed initially through a 160×128 crop, then injects
Held while an actual visible falling tower has an admitted motion lease and a
pending native pose receipt. Camera navigation reaches a remote, boundary-anchored
marker outside the former view and survives resize. Both terrain and overlay
adopt the requested camera; the complete retained 1,024² image bytes, material
publication, semantic tick and lease remain unchanged. Restore start retires
the lease and all former owner visuals. Thus the worker's leased idle path does
not starve retained-camera inspection for the currently supported whole-canvas
representation. This is local headless source/code integration evidence; the
receipt records its development binary/toolchain scope and does not replace
the registered graphical source and extracted-package executions.

## Expanded renderer result and protected-source gate

The two renderer jobs in first combined
[run 46094371247](https://github.com/techrote/cybersand/actions/runs/46094371247)
at `0acc8a8b82b0fbaf14631277c309943988410062` pass **28 material/view checks**,
11 texture-incarnation checks and the existing 27 shader guards on both Linux
and Windows. The added paired framebuffers cover cropped fragment storage
origins and rotation ([detached](presentation-smoke/detached-fragment-cut.png),
[rotated](presentation-smoke/rotated-fragment-cut.png)).

| Independently downloaded renderer artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [Linux 15243360492](https://github.com/techrote/cybersand/actions/runs/46094371247/artifacts/15243360492) | 51,469 | `967f9fd0f3c580694f78b26be9fde3035447024381b2885b62e14cec195c0d8c` |
| [Windows 15243225792](https://github.com/techrote/cybersand/actions/runs/46094371247/artifacts/15243225792) | 50,458 | `86fae706f2f7698b7e7b4b134183035c1aeed9e38b990df9e477afef1c544d44` |

The complete [Linux](presentation-smoke/expanded-linux-summary.json) and
[Windows](presentation-smoke/expanded-windows-summary.json) summaries separate
initial ordinary drawing from subsequent detached-variant creation. First
capture elapsed time is respectively 3.495/1.596 seconds on Linux and
44.710/38.808 seconds on hosted Windows software ANGLE. Setup is separately
recorded; capture latency includes any compilation, frame wait, readback and
PNG I/O. The Windows result establishes an additional cold first-use risk,
not a TITAN RTX or steady-state performance claim.

The bounded response is opt-in admission-time preparation: show **Preparing
structure materials…** in a normal UI frame, then draw a two-pixel offscreen Wood/Empty
Sprite with the exact shared body shader in a temporary SubViewport. The
temporary viewport retires before readiness. The shader resource is retained
once per application process across scene replacement. No native owner, body,
material or clock is created or mutated by this preparation; existing Pause
state remains unchanged and no new physical interval or cutting is admitted
before readiness. Ordinary Structures-disabled launches remain lazy. Headless
execution explicitly records that no graphical preparation occurred. The new
actual-renderer preparation fixture and mounted camera observation require
fresh hosted source-bound evidence; their presence alone is not a pass.

That campaign's sanitizer job **failed before native tests** at the protected
material-shader byte guard. The [reviewed source transition](../2026-11-28-objectshard-material-shader-transition.md)
preserves the immutable lock and authenticates the exact public source.
Independent preprocessing establishes byte-identical complete ordinary shader
programmes in both default and bounded-crossfade modes. Only the explicit
ObjectShard macro adds behaviour. This repair requires the next source-bound
campaign; the failed first campaign is not a native qualification pass.

## Risk-driven combined coverage

| Risk | Qualification route |
| --- | --- |
| Ordinary Tower collapse, independent reference barrel | Existing ordinary Workbench completion plus new `test_object_shard_m4_remote_barrel`; natural contact and remote support-cut scopes remain distinct from the unreconstructed owner sequence. |
| Low-inertia angular fragment / bounded refusal | New actual Rapier `test_object_shard_fragment_motion`, actual native-ACK `test_object_shard_m4_small_fragment_chain`, native contact/coordinator coverage and A's source-matched integration witnesses. |
| Moving cut, fragmentation, geometry/mass and explicit settle | Existing completion, fragment/reabsorption, lifecycle/adverse/fuzz tests and independent material accounting. |
| Paused native brush no-op versus genuine mutation | New flag-free `test_object_shard_m4_brush_revision` executes headlessly and with the actual renderer in source/extracted replay, requiring truthful World/frame/upload identity without a forced-refresh repair. |
| Combustion, Water extinguishing and Sand lodging | Existing long-burn and registered `test_object_shard_lab` exchange witness execute in source and extracted payload: actual Sand enters Cargo with exact World+Cargo quantity, and Water extinguishes the same surviving Wood incarnation. Mixed profiles separately prove relocation. |
| Semantic throughput and body cohorts | Matched B controls plus existing disabled/zero-body, Tower, stress, paused, recorded/unrecorded profile routes; headless/render callback/physical acceptance scopes stay separate. |
| Active/paused/Held pan, zoom, resize | New mounted `test_object_shard_m4_camera_lifecycle`, including an active lease, cropped initial view, far pan on a 1,024 World and actual Restore. Graphical in source render and pristine extracted Windows replay. Injected Held is an inspection fixture, not reproduction of the owner's original sequence. |
| Native RG8 and detached finish | Mounted native camera lifecycle checks exact material bytes plus synthetic actual-framebuffer parity fixture on Linux and Windows. |
| Restore and scene replacement | Mounted camera lifecycle, existing World transition/lifecycle tests; source-generation guards and visual retirement preserved. |
| Authored Save and actual fresh-process reopen | Existing Workbench completion and separate `m4_fresh_authored_reopen`, with file/source/process identity joining. Live inventory persistence remains explicitly refused. |
| Ordinary painting, actors, equipment, Water and disabled operation | Existing focused owner regressions and ordinary Workbench regression list remain registered. |
| Actual shipped archive | Existing package verifier, four-path shipped CMD replay, provenance/payload refusal controls, pristine extracted source-matched replay, plus new actual material and camera cases. |
| Accepted Strata baseline, if available before freeze | Reconcile only accepted main; preserve ordinary mode and explicitly refuse unsupported simultaneous ownership rather than adopting unfinished optical code. |

The source and extracted campaign registrar includes the new A physics
fixtures, B's admitted-receipt scheduling fixture, mounted camera lifecycle and
real-rendered material presentation. Source profile lanes additionally run the
six-second matched disabled/empty/tower/eight-body/sleeping cohorts and Tower
recording pair, with source, clocks, body populations and exact-ACK validation.
These add coverage; no original registered case or assertion is removed.
The brush-revision fixture additionally establishes a real detached Tower's
short fall, natural sleeping rest and a nonmutating collision query against
remaining native stumps while semantic time continues. It is a representative
supported-rest case, not a reconstruction of the owner's stationary facade.
Its real-renderer registration uses the existing graphical path; the natural
120-tick rest predicate uses the established shared operation watchdog rather
than an exploratory 15-second local override. Tick/contact/rest assertions and
all global watchdog values are unchanged.

## Portable delivery route and remaining gates

The first explicit preparation smoke, [run 46096195855](https://github.com/techrote/cybersand/actions/runs/46096195855)
at source `bd97c2599eb86958ee8e8d9c8e6ee5c6935edb9b`, correctly refused readiness
on both actual renderers: its requested one-row target did not produce an image
of that size. Shader compilation and temporary viewport retirement completed,
but this is a **failed preparation qualification**. Existing material parity,
texture identity and shader guards passed. The bounded repair uses a 2×2
target, records actual target/image dimensions and retains the positive Wood
colour/alpha plus transparent Empty assertions. Linux artifact `15243552307`
and Windows artifact `15243632042` preserve the failed receipts; the repair
requires a new actual-renderer execution.
The downloaded artifact hashes and full failed preparation receipts are
retained as [Linux](presentation-smoke/warmup-failed-linux.json) and
[Windows](presentation-smoke/warmup-failed-windows.json). The final-COM local
[camera replay](presentation-smoke/local-final-com-camera.json) passed 210
checks, including the active-lease Held crop/resize case and explicit headless
preparation admission. Its local compiler drift and non-graphical scope remain
recorded separately from hosted qualification.

The existing fixture operation watchdog is 300 seconds. The shipped-launch
qualifier defaults to 300 seconds, but the established workflow explicitly
supplies the shared 1,200-second graphical allowance to each CMD process. The earlier
software Windows cold ordinary/body captures totalled about 84 seconds. No
watchdog has been enlarged for this change: final clean extracted launches
must complete under the established deadlines, including their actual cold
preparation. These are watchdogs, not performance acceptance thresholds.

The second preparation [run 46096628357](https://github.com/techrote/cybersand/actions/runs/46096628357)
at source `19485bbb5e474f0d4d90c40617a36b3120552f5b` established an actual
2×2 rendered target, opaque Wood `(0.270588, 0.2, 0.152941, 1)` and transparent
Empty on Linux; preparation reached ready and retired its viewport in 1.733
seconds. Its subsequent synthetic body fixture failed because its clipped
overlay had zero size. Both downloaded body PNGs were entirely transparent.
The fixture now supplies the same explicit view-sized overlay as the existing
parity fixture and production layout, and records sampled output pixels. Its
opaque/transparent assertions remain unchanged. This second failed fixture is
not a completed warm-up qualification and requires another actual execution.

The corrected [run 46096895793](https://github.com/techrote/cybersand/actions/runs/46096895793)
**passed both actual renderer jobs** at application
`e6fe40cacb57cb170057f46d9287b365a01495ee`, tree
`c785c750bc141db8d117c90b2cd358f80b452efe`. Each platform passed 13 preparation
and shared-shader reuse checks, 28 material parity/crop/rotation checks, 11
texture identity checks and 27 shader guards. The independently downloaded
[Linux receipt](presentation-smoke/warmup-passed-linux.json) and
[Windows receipt](presentation-smoke/warmup-passed-windows.json) retain complete
source, historical runtime and artifact identities.

| Actual renderer | Preparation through positive draw and retirement | First visible body capture | Replacement body capture |
| --- | ---: | ---: | ---: |
| Linux OpenGL/Mesa | 1.721 s | 12.8 ms | 6.2 ms |
| Windows ANGLE software adapter | 43.458 s | 820.9 ms | 15.5 ms |

These measurements include frame waits and readback, and body captures include
PNG output. They demonstrate moving the substantial additional cold shader
work to explicit preparation; the remaining first visible capture cost is
reported, not claimed eliminated. Both later bodies reuse the exact prepared
Shader resource, and their positive opaque/transparent framebuffers are
identical. The [Windows first body](presentation-smoke/windows-prepared-first-body.png)
was visually inspected. Headless timing and physical display performance are
not inferred from these synthetic visual fixtures. Actual Workbench UI,
native material projection and clean extracted launch remain combined gates.

The first combined [run 46094371247](https://github.com/techrote/cybersand/actions/runs/46094371247)
finished with the material compatibility refusal recorded above and the same
two failed historical timing assertions on Linux and Windows:
`test_object_shard_m4_fragment_reabsorption` and
`test_object_shard_m4_equipment_completion`, among 62 headless cases each.
The subsequent B fixture repairs establish durable attachment/Pause and an
actual delayed-receipt interval under both Main pumps; they retain the geometry
and equipment contracts. Source graphical and package steps were skipped in
that first failed campaign. A new combined run must qualify the final source.

The established `[objectshard-m4-publish]` path source-leases the current
principal branch, builds fresh Linux/Windows native extensions, verifies both
build/runtime receipts and publishes exactly the two binaries plus their two
provenance manifests. Its final jobs depend on the native, Linux and Windows
campaigns. The historical branch runtime remains an explicitly stale retained
pair until that guarded transaction completes; arbitrary donor DLLs are never
adopted.

The Windows producer packages the complete ordinary Workbench, pinned Godot,
Rapier, redistributable dependencies, source-bound native manifest, payload
hashes, verification tooling, optional diagnostics and the current owner guide.
`Open Workbench.cmd` remains the normal entry and selects the Tower with ANGLE.
It creates the inner archive, extracts it to clean paths with spaces,
parentheses, Unicode and nested directories, executes the shipped launcher and
refuses tampered payloads/ledgers. A separate replay runs tests from the actual
extracted payload, not the build checkout.

**Pending at this checkpoint:** combined native/Windows qualification, final
application/native tuple, exact final inner archive bytes/hash, extracted
launcher/replay results and physical owner evaluation. The [owner guide](../../operations/objectshard-workbench-playtest.md)
contains the precise eight-check route and visible results. This packet will be
updated with actual terminal results; no pending result is a passing gate.
