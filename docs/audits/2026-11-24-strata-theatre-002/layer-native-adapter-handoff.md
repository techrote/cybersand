# STRATA-THEATRE-002 — layer-native adapter handoff

**Draft/HOLD, 24 November 2026.** This is a source-pinned integration handoff for
WORLD-STEER and DOCS-RENAISSANCE, not authority to enable provider writes, absorb an
active branch, merge Strata, or promote any native content. It describes application
freeze `934cc0c0eef70dad528155e9a92eebe25e2757eb`, tree
`0c30ea3eaea61c5091c23b984837f29d7b7c828e`. The [decision packet](decision-packet.md)
records its actual platform/package evidence and any subsequent documentation-only
closure. Source defines the current callable contract. Active WORLD-STEER M6–M7
PR #777, its #770 foundation and DOCS-RENAISSANCE #774 remain separate owners.

## Ownership boundary

The ordinary Play worker, native World, paint editor, Rapier actor session, camera
and renderer retain their existing owners. Strata holds copied Play observations
and uses the existing editor's owned operation token and original ACK. One
separate Strata layer owner owns the three static decorative Worlds. A native
plan or raster mapper receives neither a World reference nor actor authority.

Current targets are exactly `play`, `scripted`, `effects`, and `background`.
Play import/capture requires paused Play and explicit selection. Decorative
native construction is static. Hidden, zero-opacity, locked, Solo-excluded and
Flat-excluded targets refuse edits. The shipped layered presets target only the
three decorative planes; ordinary Art remains Play-only. Future conversational
or architectural producers must keep explicit owner selection, copied native
preview and approval. No provider/model transport is added by this handoff.

## Ordinary Workbench entry points

The controller in `godot/scripts/depth/workbench_strata_controller.gd` forwards
these operations to `workbench_strata_authoring.gd`. The controller already
drives bounded progress; a caller must not create another simulation/process
scheduler or consume the Play worker's result slot.

| Method | Result and authority |
| --- | --- |
| `authoring_inspect_source(path)` | Bounded read-only local PNG/native-module inspection; returns `ok`, `kind`, `extent`, source digest and source preview; creates no decorative owner |
| `preview_import(path, options)` | Starts copied conversion and actual-target preview; never authorizes native writes |
| `preview_module(id, options)` | Shipped/harvested native part proposal; exact grid transform, optional explicit role mapping, repeat count/step |
| `preview_composition(id, {origin:[x,y]})` | Finite shipped plane-local stages at a common design anchor; independently reviewed visual settings remain separate |
| `authoring_state()` | Busy/ready/terminal status, current approval token, stage progress, before/after projections, explicit no-write/changed counts, history warnings and native receipts |
| `approve_plan(token)` | Revalidates the exact current reviewed proposal; only this call admits the subsequent bounded native write sequence |
| `stop_authoring()` | Cancels preparation or the unstarted suffix; a pending native operation must acknowledge before the terminal prefix is reported |
| `apply_composition_settings(token)` | Separate exact visual-settings approval after all native stages complete; changes no geometry/history and can refuse if context changed |
| `harvest_module(plane, region, title)` | Bounded read-only native capture and a reusable exact module; Empty defaults to no-write |
| `export_module(id, path)` | Validated native JSON through the established atomic file-replacement service |
| `module_catalogue()`, `composition_catalogue()`, `import_fixture_catalogue()` | Current shipped/harvested choices and explicit sample mapping options |

Ready Import summaries derive the plane and `[x,y,width,height]` from the exact
single reviewed stage. A top-level conversion alias is not an authoritative
region. A multi-stage proposal requires the explicit Compose stage list; no
invented union rectangle may substitute for those independently targeted regions.
Current graphical receipts retain the raw backend message and the entire UI
message after its documented edge-whitespace trimming, together with the exact
approval token and source-fixture-derived region.

Raster `options` are `plane`, `crop:[x,y,w,h]`, `origin:[x,y]`, integer `scale`,
`transform`, `alpha_mode`, `alpha_threshold`, `palette`, `color_distance`,
`unmapped`, and optional `mask_path`. Each palette row is
`{rgb:[r,g,b], material:id, role:string}`. Supported transforms are `identity`,
`mirror_x`, `mirror_y`, `rotate_90`, `rotate_180`, and `rotate_270`.

The distinction between **no write** and **Empty** must survive every producer.
Overlay alpha below threshold does nothing to a destination. Replacement mode
explicitly proposes Empty, subject to the same bounds and protection. An excluded
external mask pixel always remains no-write. Native import retains its own exact
mask, full grid and IDs; raster palette, crop resampling and external PNG masks
do not reinterpret native geometry.

This raster selection-mask rule is distinct from a native module's write mask.
Native mask0 defaults to no-write, but explicit native `empty_mode:"clear"` can
request Empty there. Native mask1 with material0 already means an Empty write.
All requested clears remain subject to bounds, native protection and clearance.

Native part options use `plane`, `origin`, optional `transform`, role `palette`,
`empty_mode:"preserve"|"clear"`, `count:1..16` and exact signed `step:[x,y]`.
The part's `origin` is the transformed grid's top-left, not its declared interior
anchor. `Module.compile` also returns the transformed world anchor for consumers
that need it. A composition's origin is its shared design anchor, added to each
explicit stage/placement offset. No attachment solver is implied.

## Pure native interchange and finite-plan contracts

`strata_native_module.gd` exposes `validate(raw, admitted)`,
`read_json(bytes, admitted)`, `create(...)`, `compile(...)` and the narrow
`from_architecture(raw, source_sha256, admitted)` reader. New masked modules use
`cybersand-strata-module-v1`: uint16 little-endian row-major cells and an equally
shaped byte mask, with source and content hashes. Mask zero requires stored
material zero but means no write; mask one with material zero means an explicit
Empty operation. Preserve that distinction when harvesting or converting parts.

The #770 reader is pinned to application
`fe2395c7060dae736dc2e5dc8d1e4e050b2d2e52`. It accepts the supported frozen native
module shape while retaining that donor's 512-side limit. Required unresolved
attachment constraints refuse. It does not import #770's live planner, make a
Gold nomination owner-adopted, or claim load-bearing analysis.

`strata_construction_plan.gd` provides:

```gdscript
Plan.from_module(validated_module, explicit_plane, placement_options, copied_plane_state)
Plan.from_composition(raw_composition, shared_anchor, validated_modules, copied_plane_states, admitted_ids)
Plan.compile(raw_plan, admitted_ids)
```

A `cybersand-strata-plan-v1` contains exact scene/source identities, validated
modules and ordered stages. Each stage declares `id`, `plane`, `region`,
`expected_revision`, earlier `depends_on`, `allowed_materials`,
`protected_regions` and exact placements. Each placement binds `module_id`,
`module_sha256`, `origin`, `transform`, role `palette` and `empty_mode`.
Compilation does no native writes. It refuses unknown fields, missing dependencies,
overlapping same-stage placements, unsupported materials or out-of-region writes.

Executable concrete examples are already shipped:

- `godot/data/strata2/modules/rear-truss-bay.json` and seven other native parts.
- `godot/data/strata2/compositions/factory-service-bay.json`,
  `reactor-service-arch.json` and `inhabited-skybridge.json`.
- `godot/data/strata2/imports/alpha-cutout.png`, its exact native equivalent,
  explicit mask and fixture manifest.
- `godot/data/strata2/reference-imports/*.fixture.json` and their independent
  original-art/crop/mask/proposed-geometry provenance. These are proposed mappings,
  not accepted native art merely because source artwork exists.

Future typed producers can prepare the same pure contracts. Exposing a new live
Workbench producer route still requires a reviewed adapter; this handoff does
not authorize calling private methods to bypass owner selection or approval.

## Host/session protocol and bounded outcomes

`strata_construction_session.gd` has `begin(host, plan, admitted_ids)`, `step()`,
`state()`, `approve(token)`, `stop()` and copied `projections()`. The host supplies
`authoring_plane_state`, `authoring_capture`, `authoring_apply`, `authoring_poll`,
`authoring_flush`, `authoring_record`, and optional existing-authority
`authoring_preflight`. Immediate receipts and pending operation IDs are explicit.

Every current plane state and copied observation is fenced by `scene_id`,
`owner_id`, `generation`, `revision`, `authored_serial` and `permission_sha256`.
The extra authored serial matters: a no-op saved stamp can change authored history
without changing native cells. Captures must identify their exact tile and
original owner/revision; writes also carry exact expected-before materials. The
host may never replace the original ACK's revision with a later observed one.

| Bound | Current value |
| --- | --- |
| Native masked module | At most 2048 per side, 262,144 cells, 2 MiB JSON |
| PNG | At most 16 MiB and 2048 per side; crop at most 512×512 |
| Raster sampling | Integer scale 1–4; output at most 262,144 cells and 2048 per side |
| Finite plan | At most 16 stages, 32 modules, 262,144 proposed writes, 1,048,576 inspected region cells and 8 MiB |
| Copied capture / mutation | At most 64×64 cells per capture and 4096 cells per existing-owner mutation |
| History | Existing 32-entry per-plane windows; each acknowledged chunk is a history operation. Displaced older chunks are no longer undoable through that window. |
| Provenance | At most 64 historical records, 256 KiB total, 8192 bytes of metadata per record; no silent eviction |

Stop is suffix cancellation, not cross-plane rollback. A later refusal cannot
undo an earlier acknowledged prefix. Missing ACKs stay pending; a 15-second notice
does not invent failure/completion. Only an actual subsequently validated ACK
clears that provisional waiting notice; an invalid owner/revision/result still
refuses. Malformed mutation receipts are failed and
explicitly unverified, never reported as zero-write. Full-stage readback checks
the acknowledged prefix including no-write/protected cells. `completed` and
`committed_stale_pixels` distinguish native completion from publication freshness.

Module geometry checksums use the specified uint16/mask byte encodings. Session
before/projected/actual region checksums use the copied row-major
`PackedInt32Array.to_byte_array()` representation in the qualified Windows/Linux
runtime. Do not compare these different checksum domains as if their encodings
were the same. Retained provenance is operation history; it cannot authorize a
new write, resume a queue or attest later live/evolved geometry.

A stage with no requested writes refuses at compilation. A stage whose requested
materials already match can have zero changed cells, but its explicit chunks
still follow the ordinary owner acknowledgement and history path. Requested,
applied and changed counts are different facts. Every requested chunk needs the
original owner receipt and independent readback before its dependency can complete.

## Shared source seams to reconcile in a future union

Outside `godot/scripts/depth/`, this successor changes only these two application
scripts relative to #769. Reconcile their exact owned operations before a future
combined candidate; do not install another completion consumer.

| Shared script | Strata-owned change and invariant |
| --- | --- |
| `godot/scripts/workbench_paint_editor_controller.gd` | `strata_capture`, `strata_commit`, `strata_stop` and `strata_operation_finished` borrow the ordinary paint queue. The editor remains the sole consumer of the native worker receipt and forwards the original copied acknowledgement with the operation token. Existing history remains authoritative. |
| `godot/scripts/shared_workbench.gd` | Refuse scene replacement while native Strata authoring is pending, and retain existing lazy controller, ordinary Save/Load and Play identity seams. Strata does not gain a second World, worker or actor owner. |

Play preflight applies the exact same sorted 4096-cell partitions to a private
copied authored Setup that the ordinary editor will later acknowledge. Its
`authored_serial` observes the actual copied authored layout; even same-material
ordinary or legacy stamps invalidate an old proposal when history changed.
Consumers must not replace that fence with material-pixel equality alone.

Document v2 owns atmosphere configuration and bounded historical provenance.
It does not replace Play Setup, GEN-008/Flatten or a future RAMCACHE format.
The native module bridge consumes the frozen #770 schema without importing its
planner. Required unresolved attachments remain refused. Ordinary Art continues
to use Play only; a future explicit layer proposal needs its own selected-plane
adapter and source-bound combined qualification.

## Qualification and future reconciliation

The [independent review](reviews/authoring-and-custody-review.md) records the actual
cross-lane findings, repairs and retained negatives. Codec/session copied-value
tests, native ordinary Workbench execution, framebuffer tests, pristine package
execution and physical owner review are separate evidence classes. A later union
with #770/M6-M7 or provider-backed Art needs new source-bound qualification.

The lead's canonical decision packet owns final delivery status, frozen application
identity, hosted jobs, evaluator SHA and physical owner gates. This handoff is
usable read-only by WORLD-STEER and DOCS-RENAISSANCE without editing their branches
or treating this historical packet as current authorization.
