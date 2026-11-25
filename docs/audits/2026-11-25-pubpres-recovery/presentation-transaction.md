# Actual presentation submission recovery

## Resulting-source 1290 checkpoint — graphical PASS, comparison HOLD

The principal PR published application and driver
`1290c31dc262cdc6d31e9d53bde80fe3527585d7`, tree
`7ef7e76c8d6fdf59dabd4669da5ca2688b2cfe37`. All three resulting-source
graphical transaction configurations passed the unchanged **98 checks**:

| Configuration | Actual CPU draw submissions/completions | Deferred opportunities | Admission faults |
| --- | ---: | ---: | ---: |
| Safe0 | 125 / 125 | 0 | 0 |
| Separate0 | 192 / 192 | 0 | 0 |
| Separate4 | 180 / 180 | 535, at most four per draw | 0 |

The engine is the separately recorded Linux development build
`674a6324d6a3c83eb195418a68a72e98ea82d984f2ff72521a33bc2d9dd32745`.
The original retained C native binary remains
`e550846d9e7656ffd6cc90dfa0db4b3a17e1dbe2908e8e89f5869076d3233b74`.
The additive input-equivalence binder checked all **113 native/build inputs**
against original build source `4bde032f27e90e6e974b3ddc123264afa8fa5012`;
this is unchanged runtime reuse, not a new native build at 1290.

All eight stale/manual-draw framebuffer refusals and four UI fallback/lifecycle
rows passed. Each renderer performed the independently checked first actual
framebuffer read. Deferred and rejected render time was conserved, and every
admitted CPU draw completed. This establishes the scoped local transaction
foundation; it does not establish GPU completion, physical scanout, Windows
qualification, Water composition correctness or a physical-progression benefit.

The [original archive](presentation-development/atomic1290/originals.tar.gz)
and [byte manifest](presentation-development/atomic1290/manifest.json) retain
all three direct receipts, engine traces, launch records, first-read PNGs and
stdout. The archive also preserves the subsequent failed stock observer
calibration, including raw physical events, actual presentation observations,
CPU/memory records, import/source custody and its untouched failed summary.
Every archived file was read back and checked against its original SHA-256.

### Original comparison failure: direct-part metadata contract

The prospective Water-off stock observer off/on/on/off calibration started
under an exclusive local CPU/graphics window. The first local enclosure exited
before application execution because Xorg display96 had an existing lock. The
lock was left untouched; a fresh enclosure used display95. This infrastructure
refusal has no application or performance result.

The second enclosure executed all four Wave512 arms. Both observer-on arms
were correctly refused by the unchanged frozen geometry reader with:
`Direct submitted geometry differs from its source branch`.
The new Water integration had added `physical_body_index` to direct simple
parts. The frozen direct-part contract deliberately expects that field to be
absent, represented by observer value `overlay_body_slot == -1`; the original
receipts instead contain the actual body slot `0`. Their selected/submitted
matrices, collider dimensions, actor identity and real body RID agree, but that
does not turn the failed original contract into a pass.

The lead selected a narrow application repair: retain the original direct-part
metadata contract and use a separate `water_body_index` only for Water
composition association. Compound parts retain their existing
`physical_body_index` meaning. The frozen geometry oracle remains unchanged.
This repair is subsequent source and is **not qualified by the 1290 receipts**.

The campaign was stopped once the repeated mismatch was established. Its first
large-world arm was canceled through the existing owned-process cleanup and
has no complete capture. The original four-arm calibration is incomplete for
qualification because the two observer-on arms were refused. No bounded
comparison was started, no observer overhead was accepted, and no architecture
selection or performance improvement is claimed. Corrected resulting source
must repeat the graphical gates and complete both observer controls before the
registered six-arm experiment.

## Development checkpoint — HOLD

This continues #767 at `f4089809c7294336db26cf576b0ac3c57fc54775`.
The first implementation separates immutable preparation from submitted
bookkeeping and adds a late Main-owned preparation callback before the normal
message flush. Visible pose/Follow/fairness state, camera intent and cache-cost
accounting are copied privately while preparing. Only an admitted candidate
consumes the replacement state. Picking and continuous pointer aim use the last
submitted mapping. The experiment is default-off through
`CYBERSAND_DIAG_ACTUAL_SUBMISSION=1`; no ordinary default is promoted.

The candidate retains one bounded frame, replacing its predecessor. Its exact
fence includes Main/worker/physical owner, World extent/generation, bridge
session/epoch, actual completed physical identity, member RIDs/generations and
copied poses/rectangles, current/previous uploaded material identities and RIDs,
policy, selected actor, requested camera/viewport and pause/replacement/step
lifecycle. Preparation never admits additional material or Rapier work.

### Independent blocker found before selection

Specialists A and C independently identified a real flaw in the first
application-only prototype: rejecting bookkeeping at `frame_pre_draw` cannot
cancel canvas/shader commands that were already staged before the message flush.
An actual draw could therefore display the rejected candidate while picking
retained the preceding mapping. Late process ordering alone does not close this
gap: a deferred message can still mutate a relevant identity after preparation.
The prototype is **not qualified or selected**, including where its initial
journal tests pass. Its original results remain below.

The required repair is actual engine-owned admission after the message flush
and before allocating a draw serial, emitting draw signals or incrementing
`frames_drawn`. A refusal must conserve render time and perform no draw. The
live callback must return the actual immutable acceptance identity; a metadata
flag alone cannot grant acceptance. This changes the bounded component contract
and requires new engine builds/qualification. The old Windows engine component
and its successful build remain preserved as earlier evidence.

## Original local execution

These are local deltas over the base above; each original receipt includes
SHA-256 of its actual Main, coordinator and driver. They do not attest that
the unmodified base contains the new implementation.

- Godot 4.7 stable Linux: `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
- Recovered source-matched native C: `e550846d9e7656ffd6cc90dfa0db4b3a17e1dbe2908e8e89f5869076d3233b74`.
- Actual Xorg desktop and Mesa llvmpipe, Compatibility/OpenGL, ordinary mounted
  Workbench with two Needles and a 512-square Wave basin. This is hosted-style
  software graphical execution, not physical Windows/NVIDIA acceptance.

The [first failed receipt](presentation-development/01-original-failed.json)
passed 38 of 40 checks. The original driver re-enabled rendering before the
current idle iteration finished, allowing a genuine draw immediately and
another on the following iteration; its expected one-draw delta was wrong.
The correction finishes all four no-draw producer iterations before resuming
one draw. No production scheduling behavior was changed for this correction.

The first framebuffer oracle also confused physical window pixels and the
render-target pixels returned by the viewport. The
[second original failure](presentation-development/02-viewport-oracle-failed.json)
retains the incorrect screen-inverse-only correction. For the actual
canvas-items stretch, the correct conversion is the viewport stretch transform
times the inverse screen transform. This preserves window letterbox offsets
and does not scale framebuffer pixels twice. The sampled Needle interior also
avoids its center marking and pilot ring; the expected color remains the
production part color darkened by 0.18, independently calculated.

The [third receipt](presentation-development/03-journal-prototype.json) passes
all 40 checks including the first framebuffer read, five candidate replacements,
four no-draw process opportunities, duplicate actual draw observations, stale
camera/material/policy/pause journal refusal, submitted picking/aim, ordinary
Step/Play/Pause/Follow, real native/Rapier progression, paint and authored
restore. **These checks did not test the stale-candidate framebuffer failure**
identified in independent review. Their pass therefore grants no whole
transaction correctness or bounded-engine integration claim.

## Native idle peer review

The presentation specialist independently read the native specialist's new
`_wait_for_completed_workbench_sample` and its production bottom-loop call.
It only waits after publication for a completed, valid, nonpaused actor sample
under the explicitly selected sample-wake policy. Fresh samples, owner control,
ACK, trace/view/identity changes and a due material capture interrupt the wait.
No-body, failed/refused, paused and timer-paced cases retain their original path.
The original exclusive owner performs all actual material work after waking;
there is no extra sample or physical credit. No source-correctness blocker was
found in that scoped review. Two mutex observations per 250-microsecond poll
remain a cost, and physical benefit requires the independently registered
ordinary graphical comparisons; source review is not performance acceptance.

## Remaining work at this checkpoint

Implement and independently review atomic engine/application draw admission;
exercise actual framebuffer refusal and last-submitted picking under deferred
mutation; qualify first reads and lifecycle with the new engine; join its draw
receipt to exact application submissions; then execute matched 0/4/4/0 with
the separate stock Safe reference. All performance and owner acceptance gates
remain open. No merge, Ready promotion or default change is authorized.

## Atomic-admission implementation checkpoint — not yet graphically qualified

The stale-draw defect was then [reproduced graphically](presentation-development/04-stale-pixels-original.json)
at exact prototype `df480e6d29118e0512303e26f10efc2249d02370`, using the
[retained diagnostic](presentation-development/stale-pixel-reproduction.gd).
A prepared 32-cell camera shift changed the framebuffer even though a subsequent
policy mutation caused journal rejection. Picking retained mapping origin
`(-429,-262)` while the drawn candidate used `(-572,-262)`. The receipt preserves
both distinct original pixel digests and actual source hashes. This is executable
negative evidence, not only a review inference.

The successor application requires engine capability
`cybersand_actual_submission_v2`, schema `cybersand-actual-submission-v2`, with
strict boolean `engine_owned_admission:true`. Stock engines refuse this opt-in
and retain their ordinary path; no journal-only transaction is selected there.
The original v1 immutable handshake now becomes ready only after an exact-serial
deferred marker behind every staged canvas redraw has run. Superseded markers
cannot certify a replacement. This also refuses manual `force_draw` before Main
has flushed the candidate's actual canvas commands.

The new engine calls `_commit_workbench_presentation_submission(true)` after
the message flush and before draw admission. The callback validates the complete
fence and returns a preconstructed, typed, immutable receipt containing owner,
source, candidate/submission serials, process frame and submission clock. An empty
receipt refuses the entire draw. The normal connected callback, invoked with its
default `false` argument, only emits the already-accepted observation signal and
trace. No external observer runs between the direct commit and return. The lead's
engine patch owns actual draw veto, serial/counter preservation, real-queue drains,
and conservation of refused rendering time; the old engine binary cannot qualify
this revised application contract.

An invalid/missing actor receipt does not prevent UI rendering: it prepares an
empty actor overlay as before. Transaction readiness means a complete staged
value with its flush marker, not `frame.valid` (which describes actor-mask proof).
Source identity refusal is separate. No performance benefit is claimed.

The revised graphical fixture retains its versioned schema and adds exact
before/after framebuffer SHA-256 under stale owner, material, policy, camera,
pause and genuine physical-completion stimuli. The completion stimulus invokes
the normal production physics callback with all native/terrain/sample gates
unchanged; it must complete exactly one real session and manual Rapier step.
Manual draw before flush is separately challenged. Refusal must emit no draw or
submission signal and retain the actual framebuffer/mapping. Separate-renderer
first reads wait for actual submission identity, then use an explicit untimed
queue barrier and notification-drain marker; a delayed `frame_post_draw` cannot
stand in for a current submission. These barriers never enter performance runs.

The [frozen default-off temporal suite](presentation-development/05-default-off-temporal.json)
passed all 573 checks and 63 observations on the stock engine and matched native
runtime at `df480e6d`. This preserves the original default path but is not a pass
for the new atomic path. The revised source parses with official Godot 4.7; actual
v2 engine graphical, resulting-source and Windows qualification remain open at
this checkpoint.

## Pointer reconstruction and startup refusal checkpoint

Independent lead review found a second correctness seam: a pointer event is
localized using the **current** Control and viewport transform. If a transform
changes after the last draw, multiplying that new-local coordinate by the old
submitted screen transform selects the wrong physical pixel. The repaired path
reconstructs the physical screen point with the current transform, then applies
the last submitted camera inverse and its submitted content bounds. Continuous
pointer aim uses the same rule. An armed transaction with no submitted mapping
refuses picking and returns no aim direction rather than using future camera
intent. The graphical fixture now rotates, scales and translates the Control,
constructs event-local coordinates for one fixed physical pixel, and checks that
cell and continuous-world picks remain stable while the refused framebuffer and
submission stay unchanged. This new row is **not yet executed** at this checkpoint.

The coordinator also refuses initial opt-in when `CYBERSAND_SOURCE_REVISION` is
missing or malformed. It publishes no enabled handshake and reports
`source_identity_invalid`; ordinary Workbench drawing remains available. This
avoids permanently freezing all UI draws for a configuration that cannot ever
produce a source-bound candidate. A source change after preparation continues to
refuse that candidate. The native graphical fixture now includes initial invalid
source refusal, actual ordinary fallback draws, cleanup and fresh valid restart.

The first attempted atomic Linux fixture did **not** execute its script. The
local development engine was built with `disable_path_overrides=yes`: `--path`
was rejected, a CWD launch looked for the project beside the executable, and an
executable-adjacent launch silently discarded `--script` in the engine's existing
startup code. That third attempt ran the ordinary scene, without a transaction
fixture. None supplies v2 qualification. Original logs are preserved losslessly
as gzip with hashes in `presentation-development/06-atomic-template-launch-rejections.json`.
The lead will rebuild with path overrides enabled after the registered native
comparison's quiet window. The same attempted launch exposed missing-metadata
log spam in the new engine, independently reported for a `has_meta` guard.

The prospective fixture additionally exercises a real physical-owner close,
mapless picking refusal, an admitted safe empty-overlay UI draw, and ordinary
Restore creating a new physical owner and actual actor submissions. A separate
missing actor-receipt candidate must draw its safe UI and omit unauthorised actor
geometry; the following genuine receipt must restore the overlay. Receipt
`fallback_ui` rows record actual draw/submission deltas, actor validity/part
counts, initial source refusal and renewed owner identities. Every refusal row
now records measured mapping and journal values rather than expected constants.
These are independent adversarial requirements, not timing relaxations.

## Default-off camera regression execution

The unchanged `test_native_pixel_camera.gd` passed **1705 checks** at
`ba52babd3acf425b46ff3c9bdae960d8b2870055`, official stock Godot 4.7 Linux and
recovered native C `e550846d…`. The [original receipt](presentation-development/07-stock-native-camera.json)
contains exact source/runtime hashes, actual native readback for brush/line/fill,
clipboard and chunk-boundary gestures, six viewport/stretch observations,
wheel in/out drift checks, and twelve genuine completed moving-Follow steps.
This run was **headless with the transaction disabled**. It preserves ordinary
camera/authoring behavior after pointer reconstruction changes; it does not
qualify the atomic graphical path or assert framebuffer/display acceptance.

## Complete-flush manual admission and preparation cost

A candidate's deferred marker establishes ordering behind its staged redraws,
but does not establish that the enclosing Main message flush has returned:
later/nested deferred redraws may still be queued. Independent presentation
review therefore requested an engine check of the real Main message queue's
`is_flushing()` state before its direct application admission. An armed manual
draw inside that flush must refuse the whole draw, retain rendering time, and
leave its immutable candidate ready for the normal draw after the flush. The
prospective fixture adds `manual_during_flush` as an eighth refusal case. It runs
a deferred manual draw after the marker, observes readiness, demands no draw,
history, signal or framebuffer change, then demands the same candidate's first
actual changed framebuffer after the complete flush. This closes a gap in the
marker alone; prior development engine hashes do not attest this guard.

The opt-in path now measures total, maximum and last actual preparation CPU
microseconds, sample count and last candidate serial. The two added clock reads
cover private copies, guard resolution, camera/Canvas/shader staging, restoration
and immutable fence capture. Costs include superseded candidates and grant no
physical, presentation or fairness credit. There is no hot-path file I/O or new
measurement ring. This exposes preparation overhead omitted by resolver-only
timing; comparisons still require matched observer controls. A specific causal
hypothesis for the first registered engine0/4 campaign is that all four deferred
Main opportunities may be spent before the next legitimate physics deadline.
That must be established from actual clocks/callbacks, not inferred from a larger
process-frame count. No pacing change is silently included in that comparison.

The fixture now emits an early source/script-hash execution marker and directly
records its executable SHA-256, process id, actual inline/Separate renderer
ownership and requested engine allowance, so a launch or engine mismatch cannot
be mistaken for application qualification.

## Actual atomic graphical integration — three controls pass

At exact integrated application/fixture source
`f8e0fb7cd4c770a31ecb43dd0161717d21cbf17b`, all **98 checks** passed under
custom Safe0, Separate0 and Separate4. The actual Linux development executable
SHA-256 is `674a6324d6a3c83eb195418a68a72e98ea82d984f2ff72521a33bc2d9dd32745`;
recovered native C is `e550846d…`, with Rapier `566e68ae…`. The corrected build
permits real script dispatch and contains the missing-metadata and complete-flush
guards. Each log has the early exact source/script execution marker.

The [original raw evidence manifest](presentation-development/atomic02/manifest.json)
binds full receipts, process/Xorg logs, engine traces, launch custody and actual
first-read PNGs. Safe0, Separate0 and Separate4 respectively recorded
**196, 182 and 137 genuine draw submissions and CPU render completions**.
Admission and completion faults were zero. Separate4 actually exercised
**403 deferred opportunities**, with maximum **4** before a real draw, and
conserved its elapsed rendering time with no pending carry at shutdown.

All three executed the eight discriminating refusal cases: pre-marker manual,
ready-marker manual inside the Main flush, owner, camera, policy, material,
pause and a genuine post-prepare native/Rapier completion. Every refused case
retained identical before/after framebuffer SHA-256 and submitted mapping, with
zero pre/post-draw signals and zero submission notifications. The midflush case
then drew the same candidate only after the complete flush. Superseded candidates,
four real no-draw producer turns, immutable snapshots, transformed input picking,
first actor-color reads, normal Step/Play/Pause/Follow, painting and Restore passed.

The four fallback cases also passed: invalid initial source left ordinary native
UI drawing; invalid actor provenance admitted a real empty-overlay UI frame;
actual physical-owner retirement refused mapless picking while retaining a safe
UI draw; ordinary Restore created a different owner and valid actual actor draws.
The first Safe0 framebuffer was independently viewed and showed the ordinary
Workbench UI/font and both expected Needles at their submitted positions.

These are **Linux developmental graphical correctness gates**, not a Windows
runtime/package gate, sustained playability result or comparative performance
improvement. Untimed setup/correctness still observed maximum Separate queue
sync calls of approximately **675ms (0)** and **971ms (4)**; those adverse values
remain in the raw traces. The next decision must come from the prospectively
matched physical progression campaign, with stock Safe and observer controls.
