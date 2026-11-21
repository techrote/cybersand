---
title: SWARM-004 reciprocal Workbench native transaction
status: Current
document-kind: contract
scope: SWARM-004 Draft/HOLD native retained-patch interface and experimental controller; qualification is separately evidenced
canonical-for: [swarm004-workbench-native-transaction, swarm004-experimental-controller]
last-reviewed: 2026-11-20
related-documents: [shared-workbench-authoring-data.md, liquid-prepared-setup-and-receipts.md, ../operations/swarm004-workbench-playtest.md, ../operations/swarm006-workbench-playtest.md]
---

# SWARM-004 reciprocal Workbench native transaction

Status: SWARM-004 experimental interface; Draft/HOLD. The normal Shared
Workbench transaction, native World, materials, simulation limits, and saved
starting-map formats remain the authorities.

## Atomic Apply and inverse Undo

The FRAMEWEAVER × MOSAIC reciprocal composition generator supplies a finite proposal with its structural and
revision ledger. Shared Workbench captures the paused native material plane,
stages one authored history operation, and submits an exact construction patch.
The cellular owner runs the existing prepared retained-World transaction:

1. Copy the source's stored material, state and thermal lanes into private
   canonical setup tuples.
2. Validate patch schema, source generation/revision/tick, exact original
   material, finite capacities, protected points and physical masks.
3. Apply the patch only to those private tuples. Prepare the native successor,
   retain existing liquid inventory, and check its fresh physical masks.
4. Return a prepared token and receipt while the installed World is unchanged.
5. At commit, the existing generation/revision/full-physical-hash and execution
   fences must still match. Swap the prepared World once. A token is single-use.
6. Shared Workbench adopts the staged history only after successful native
   acknowledgement. Refusal or cancellation discards the candidate.

The ordinary `paint_editor.commit_cells()` sliced executor has partial-write
semantics; experimental assembly Apply uses the prepared transaction. The patch
has no live cell pointer, separate World cell store, renderer substitution or
per-tick execution language.

## Exact request

`main.workbench_apply` has one trailing optional `authoring_patch` dictionary.
It is forwarded as `workbench_authoring_patch` through the MicroScenario host to
`CyberDemoBridge.prepare_liquid_world`.

| Field | Exact type and meaning |
| --- | --- |
| `schema` | Integer `1` |
| `operation` | String `build` or `remove` |
| `native_generation` | Nonnegative integer from the native material capture |
| `revision` | Nonnegative integer from the same capture |
| `tick` | Nonnegative integer from the same capture |
| `extent` | `Vector2i`, equal to the installed finite Workbench canvas |
| `cells` | `PackedInt32Array` of unique row-major `(x,y,after_material)` triples |
| `before` | `PackedInt32Array` with one expected original material per cell |
| `protected` | `PackedInt32Array` of unique row-major `(x,y)` points |
| `proposal_sha256` | String of exactly 64 lowercase hexadecimal characters |

Unknown fields, coercions, duplicate points and unsorted inputs are refused.
The patch contains 1..262144 cells; the protected set contains at most 262144
points. Coordinates must fit the existing native canvas. Native extent limits
remain 256..2048 in multiples of 64; the existing authoring UI can impose a
narrower lower bound. Material IDs are validated before narrowing.

`build` requires every original cell to be native Empty and every target to be a
supported hard-surface material or native Stone (ID 13), which the unchanged
MOSAIC grammar authors. Stone retains its production Powder behavior; admission
does not certify physical stability. `remove` requires every original cell to
match that exact admitted material being removed, with Empty as target.
The generator's approved protected set cannot intersect the patch. Source and
prepared physical masks independently refuse overlap.

The caller must select retained preparation, keep the same extent, liquid
policy, transport/Water semantics, solver options, scheduling/resource settings,
response and execution policy, and provide no alternative terrain rectangles,
Water fills, baseline or generated-grid payload. Normalization and inventory
conversion are unavailable for this transaction. Main additionally requires a
paused World and uses accepted Water settings through `apply_staged_water=false`.

## Capture and history integration

The existing worker capture API provides a copied snapshot with native fences:

```gdscript
var token = simulation_worker.material_capture_request(worker_generation, capacity)
var snapshot = simulation_worker.material_capture_poll(token)
simulation_worker.material_capture_finish(token, false)
```

The final `false` releases the snapshot without adopting a new starting-map
baseline. A composition preview must retain the worker and authoring generation
fences as well as the native fences, invalidate when its controls or source
change, and release all workers/captures on cancel, timeout and exit.

Prepare the single history stamp and its bounded exact-cell rectangles before
requesting installation. Keep the applied authoring history until acknowledgement.
After acknowledgement the existing v2 starting-map and baseline serializers can
save the committed material architecture. The composition ledger must bind its
accepted revision to the acknowledgement; a proposed ledger is not an installed
one. An inverse removal uses a fresh native capture and exact expected IDs.

This transaction has the existing retained replacement lifecycle: successful
installation starts one fresh native generation at tick zero. It retains native
stored quantities according to that path's inventory contract. Undo removes the
authored structure and preserves current unaffected material quantities; it is
not a rollback of simulated time, actor history or all prior simulation state.

## Receipt and claims

The prepared and installed receipt contains `workbench_authoring_patch` with
schema, operation, exact changed/protected counts, source fences,
`proposal_sha256`, `patch_sha256`, and semantics
`retained-native-transaction-v1`.

The native patch hash binds operation, canvas size, ordered coordinates, original
and target IDs, and protected coordinates. The proposal hash binds the caller's
claimed proposal identity. Structural rules, owner/revision provenance,
socket-facing constraints and path-qualified joints belong to the separately
qualified native composition interface and its ledger. The material adapter
receipt alone establishes no structural-stability claim.

## Focused qualification

```sh
make workbench-authoring-patch-test
make workbench-authoring-patch-sanitize
godot --headless --path godot --script res://tests/test_workbench_authoring_patch.gd
```

Build and load the new source-matched extension before running the Godot test.
The optional `WB_AUTHORING_PATCH_REPORT` environment variable records its full
JSON report and loaded-library observation. New C++ patch/test code is checked
with C++20 and strict warnings including `-Werror`; unchanged simulation
translation units retain their established Makefile warning policy. The
sanitizer target uses AddressSanitizer and UndefinedBehaviorSanitizer. Environments
that prohibit LeakSanitizer process tracing must record that limitation and may
run the same instrumented binary with `ASAN_OPTIONS=detect_leaks=0`.

The native suite checks exact whole-plane prepared geometry and thermal values,
retained fractional Water, inverse removal, bounded maximum/over-limit inputs,
foreign/protected/body collisions, canonical order, invalid IDs and source
immutability. The Godot suite exercises real preparation, receipt, discard,
stale-source commit refusal, successful single-use commit, inverse removal and
physical configuration guards. Interactive Apply/Undo/Save/close/fresh-process
reopen and the packaged Windows path require separate Main/Workbench evidence.

## Experimental controller

`workbench_reciprocal_panel.gd` is lazily mounted by the single
`Reciprocal assembly…` Shared Workbench entry. It captures a copied native
material plane, prepares the finite text request on a worker, launches one
source-bound native CLI child and validates its bounded JSON evidence on a
worker. There is no generation on panel creation. Controls or source changes
retire the preview. One 30-second deadline covers capture, request preparation,
native generation and evidence validation. Cancellation reaps the child through
Godot's pinned OS API and joins the bounded preparation/decoding worker.

The transport caps the crop at 256×128, input at 2 MiB and output at 32 MiB.
The visible ownership selector provides a vertical split, a horizontal split,
or a centred FRAME rectangle spanning the middle half of each crop dimension,
with MOSAIC around it. The optional clear border is 0..16 cells. These are general
territory masks, independent of seed and Gentek geometry. Shared reach is 0..13
cardinal steps from either facing interface cell, matching the native boundary
distance convention; zero disables shared ownership. The two exclusive ordinary
territories meet in that bounded shared zone. Typed
ownership, exact source materials, masks, seed, all seven controls, activation
locations and negotiation options must match the output evidence. Native
`can_apply` remains necessary; the controller additionally refuses incomplete
ownership and unresolved mandatory obligations. It never changes that flag.
The decoder also binds the exact compiled Gentek definition fingerprints, names,
version, authoring fixture, original resource ceilings, fixed architectural
switches and initially empty neighbor records. A different native definition
requires explicit interface requalification; a source label or successful child
exit does not admit a different grammar or increased budget. Transport fixtures
and mutations of freshly generated native records exercise these refusals.

The shared controls retain their original defaults and V1 request bytes.
Optional independent FRAMEWEAVER and MOSAIC overrides each carry the same seven
normalized controls, with decoration and destruction still independent. The
bounded text transport accepts V1 unchanged; V2 carries FRAME controls plus the
existing optional-negotiation flag, then MOSAIC controls plus an explicit shared
ownership flag, before the existing activation/mask records. It changes no
generator implementation, material law or native resource ceiling.

Disabling negotiated territory sharing retains both Genteks' original interface
transition masks while zeroing the permitted `shared_zone`, matching the native
`fixed_territory` control. Setting interface reach to zero is a different recipe.
The decoder verifies the two profiles independently, checks zero shared ownership
against the retained transition band, and records both controls in saved evidence.
The canvas and `Interface band` layer show retained hints in amber; `Shared zone`
shows only territory that native arbitration may share.

`Sockets / receptors` displays the native connector and boundary records for
each provisional proposal, or final accepted native records plus authored
assembly socket contracts. Required, optional and locally terminable contracts
have distinct colors; cell inspection reports owner, family, facing, native
status and counterpart. Accepted assembly certificates never appear on an earlier
rejected proposal. These diagnostics do not establish an additional qualified
joint, traversal path or physical support certificate. Bounded record counts,
coordinates, flags and obligation kinds are validated before rendering.

The controller stages exact history with the existing history helper. Shared
Workbench accepts the retained patch only while that controller attests the
same pending candidate and patch. Undo retains its own cells, protected set,
proposal identity and history fences, so a later preview cannot change the
inverse. Saved evidence is read on explicit request, independently hash-bound
to the ordinary saved map, and is inspection-only.
The optional receipt retains the visible layout and clear-border settings so a
reopened evidence view checks the same exclusive masks as the original request.

The native output keeps negotiation rounds intact when destruction is enabled.
Its separate `damage_derivative` holds damaged native snapshots and work;
surviving cells keep their negotiation ledger and removed cells have no final
owner. The UI's final preview and Apply use the top-level final native cells.
Provisional ownership/part overlays use their own proposal arrays; final joint,
clearance and accepted-history overlays are not mislabeled as earlier proposals.

## Integration decision

The Workbench stage is based on accepted main, with the frozen native research
programme integrated explicitly as a dependency. When accepted main advances,
its Water authority and configuration fields are retained. SWARM-004 adds only
the retained material-patch adapter; it does not change Water, production
materials, physics, rendering, the existing Gentek catalogue or Art lifetime.
The two PRs and their owner package remain Draft/HOLD.

The pinned Windows compiler receives the explicit compatibility include
`-include cstdlib` for the reciprocal CLI. Frozen donor fixture code uses
`std::abs` without declaring that standard header; the GCC build obtains it
transitively while LLVM-MinGW/libc++ does not. The compatibility flag preserves
the donor files byte-for-byte, retains strict warnings and changes no resource
ceiling. The Windows toolchain receipt records the flag and binary hash.

Windows qualification can be initiated by explicit dispatch or a separate
request-only commit on `experiment/gentek-swarm-004-workbench`. The latter matches
only `.github/swarm004-windows-request.json`; a bounded Git-history guard rejects
source changes between the declared frozen ancestor and execution HEAD, including
reverted changes. Both jobs verify the same request receipt and qualify the
execution HEAD. The [owner guide](../operations/swarm004-workbench-playtest.md#qualification-and-reporting)
documents the exact request contract. This adds no job credentials, write
permissions, provider change, production default or automatic source publication.

The [owner guide](../operations/swarm004-workbench-playtest.md) describes the
interactive controls and exact evidence requirements. Windows graphical results
must be supplied by a source-qualified run; the guide itself is not evidence
that a run has succeeded.

## SWARM-006 successor transport and custody

The separately staged GENTEK-SWARM-006 integration adds an explicit default-OFF
bounded recovery switch. ON emits `SWARM006 4`: V3's independent FRAME/MOSAIC
profile controls plus a third experimental flag. OFF retains the old V1/V2/V3
transport choice and meaning. The native ON response uses schema6 and its own
`gentek_swarm_006_negotiated_recovery_v1` identity. No UI component constructs
material paths or changes native source obligations.

The inspector admits bounded alternative-attempt, frontier and native receptor
receipt arrays and displays the native stopping reason, remaining hard
obligations and aggregate charged work. Reservations remain distinct from
qualified native joints. The existing material renderer, ownership ledger,
atomic native patch, Undo and persistence path supply the same authority.
Historical SWARM-004/005 definition hashes are allowed only for saved-evidence
inspection; newly generated proposals must match the current frozen definition.

`tools/swarm006/` and `swarm006-workbench-windows.yml` are separately versioned
successors. They preserve the earlier qualification machinery and evidence.
The owner ZIP, `.sha256` sidecar and PowerShell launcher are generated from the
exact source-built package. The launcher binds the entire manifest, generator,
Windows GDExtension and launch contents, and supports GitHub's nested artifact
without guessing a SWARM-004/005 archive name. Source and pristine-package
Windows graphical tests remain distinct from physical owner NVIDIA acceptance.
See the [SWARM-006 owner guide](../operations/swarm006-workbench-playtest.md) for
finite controls, honest negative-result reporting and qualification scope.
