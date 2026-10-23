---
title: MAT-003PREPASS proposed GEN-006 persistence and generation handoff
status: Planned
document-kind: design
scope: Proposed semantic continuation and reconciliation contracts; no production codec, eviction, migration or GEN-006 acceptance
canonical-for: [mat003-prepass-gen006-handoff]
keywords: [MAT-003PREPASS, GEN-006, persistence, continuation, tombstone, epoch, schema, baseline, same-value edit]
last-reviewed: 2026-10-22
related-documents: [mat-003prepass-state-inventory.md, mat-003prepass-epoch-consumers.md, ../reference/level-saves-and-replay.md, ../systems/procedural-world-generation.md, ../systems/procedural-semantic-planes.md, ../architecture/data-ownership-and-lifetimes.md]
---

# Proposed GEN-006 handoff

## Decision and source boundary

**2026-10-23 continuation:** [S2P/WCLEAR/C128](mat003-continuation.md#c128-feasibility-and-gen-006-consequences) adds access, clear-frequency and 128-total-bit feasibility questions. Its neutral high64 has no authoritative material schema. No ABI, padding, raw epoch or future-state meaning is added to this proposed durable contract.

**Planned proposal from MAT-003PREPASS / [#204](https://github.com/techrote/cybersand/issues/204):**
give [GEN-006 / #194](https://github.com/techrote/cybersand/issues/194) a versioned
semantic persistence boundary independent of the selected in-memory carrier.
Retain the production 64-bit layout while the experiments continue. A favorable
72/80-bit storage result would require a separate implementation decision; it
does not require GEN-006 to serialize 9/10/16-byte C++ objects.

The source audit is pinned to `da5112c066416346d6fe3984d4161cd162611e50` in the
[state inventory](mat-003prepass-state-inventory.md). Current generation prepares
material proposals and admits absent chunks, while CYSD1 restores finite demo
levels. Neither supplies live sparse-world continuation or mutation reconciliation.
This document is a proposed contract to review, not an implemented file format.

The inventory also identifies the separately saved pressure/air prototype at
`7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09` on
`claude/water-pressure-prototype`. Its patches target `620826f` plus an archived
perf working tree; they have not been applied to the assessed production source.
That available experiment supplies concrete additional state requirements, while
any newer owner-local deltas remain unavailable. No saved benchmark claim is
treated here as new execution or production acceptance.

## Separate identities with separate responsibilities

| Identity | Proposed meaning and validation |
|---|---|
| Storage envelope version | Exact framing, byte order, bounded lengths/counts and integrity coverage. Never native structs, alignment padding or `sizeof(size_t)` encoding. |
| Material catalogue identity | Stable IDs plus catalogue revision/content digest. Existing material meanings cannot silently move to new IDs. The current accepted ID domain stays 0–131 except 10. |
| Material-state schema | Versioned meaning/range/default of each authoritative field, including material IDs embedded in Cloner/Rocket state. A byte container is not a semantic validator. |
| Solver/configuration identity | Exact kernel/rule version, Water precision/coherence/rest policy, interaction/transport policies, adhesion, scheduler geometry, clock semantics and other future-affecting options. |
| Recipe / generator identity | Recipe schema, canonical recipe digest, seed, algorithm/module/semantic-plane revisions and exact generation coordinates. |
| Baseline identity | Immutable old generated proposal or a recoverable generator+recipe that reproduces it exactly. Required for three-way reconciliation; separate from current recipe. |
| Durable world identity | Identifies the saved world across sessions. A newly loaded session receives a fresh runtime admission identity. |
| Chunk incarnation / mutation version | Distinguishes replacement/eviction/reload and later edits even when coordinates and bytes repeat. Checked on save/generation/reconcile commit receipts. |
| Owner request / publication identity | Binds asynchronous completion to the exact current world/session/chunk/version and expected task. Stale results refuse without modifying the current state. |

**The update epoch is none of these identities.** It is a wrapping scheduling and
support stamp. Actor session epochs, discovery world incarnations, generation
receipts and render publication serials already have distinct owners. Sharing an
integer field or reusing the cell counter across these responsibilities is rejected.

## Proposed semantic records and validation

A candidate envelope should carry declared signed chunk coordinates and geometry,
the identity tuple above, explicit feature flags, bounded record counts/lengths,
and an integrity digest over the canonical header plus all authoritative payloads.
Coordinates, products and lengths must be checked for overflow before allocation
or conversion. Compression must have a bounded decompressed size. Duplicate cell
keys, duplicate optional-field IDs, malformed ordering and overlapping records
must be rejected or resolved by a single explicitly versioned rule.

A useful initial **logical record** is material-u16, state_a-u16, state_b-u8 and
temperature-i16, with a separately specified scheduling-state record. These are
field domains, not a selected seven-byte on-disk format. Material-u16 preserves
storage-comparison capacity; it does not admit IDs outside the current catalogue.
Default values may be omitted only when the schema gives an exact equivalent
initialization under the recorded configuration. Signed temperature must have a
defined encoding; narrowing a future high-a state to CYSD1's byte is a refusal,
not a migration.

Every optional authoritative field needs its own type/schema version, bounded
scope/count, logical owner, default/absence meaning and operation rules. Declare
whether ownership follows cell identity, coordinate, chunk, material or solver.
Declare copy/move/swap, split/merge, conversion, reset, reclamation and allocation
failure before activating the field. Preserve authoritative extension state or
reject the record. Unknown mandatory state may never be silently skipped;
unknown presentation-only annotations may be ignored only under that explicit
classification.

Validate the entire candidate before retiring an old owner. A failed import or
migration keeps the original stored record and active world intact. A migration
must name source/destination schemas, deterministic conversion/default rules,
conservation or declared source/sink consequences, and downgrade/refusal behavior.
The first schema should reject unimplemented migrations. Version pinning and
explicit refusal are more useful than a fabricated compatibility promise.

## Persist, reconstruct or refuse

| State class | Proposed disposition | Required proof / boundary |
|---|---|---|
| Material identity, compact semantic state, nondefault temperature | Persist exact supported logical values | Preserve nonzero Empty state too unless an explicit schema rejects it. Whole-cell and partial-Water temperature rules differ. |
| Immutable material/policy/recipe configuration | Persist identities plus available validated content | A hash alone is insufficient when the old content cannot be recovered. |
| Global attempted/completed tick and each active plane's clock | Persist for continuation | Coordinate/tick random streams and cadence must continue at the declared phase; do not restart at zero. |
| Activity, quiet counts, pending interaction deadlines, requested/applied interest state | Persist, or reconstruct under a separately qualified equivalent rule | Wake-all or resetting deadlines can change opportunity timing and support behavior. Re-entry retains no-catch-up policy. |
| Per-cell scheduling/support state | Persist a versioned semantic classification or apply a proved rebase | Raw epoch width is not the durable schema. No reconstruction rule is accepted by this document. |
| Saved pressure prototype's Water flow/overfill and Empty air amount | Unsupported by the initial production record; separately version, persist or refuse if this solver is ever admitted | These are cross-tick semantic payload, including state on Empty cells. Never fold them into the epoch or silently omit them through a content hash. |
| Saved pressure prototype's head scratch and pocket history | Head scratch is a reconstruction candidate; history needs persistence or a separate equivalence proof | Exact prepass coverage, obstacles, phase, policy, prior offsets and optional damping volume affect future work. No reconstruction is qualified here. |
| Accepted pending explosions / owner commands | Persist exact ordered work with delivery identity, or drain before capture | A receipt must prevent a second application after reload. Cancellation needs an explicit owner outcome. |
| Tick-local jobs, mutable views and partial effects | Unsupported capture point | Capture at a completed healthy tick boundary after workers join. Quarantined partial worlds refuse export. |
| Render textures, visual condition, relief/parallax | Reconstruct | Retire old leases; publish a fresh complete projection after admission. Preserve authoritative cells, not stale display bytes. |
| Pure generated preview cache | Reconstruct from exact immutable identity | Preview cache eviction is independent of live World eviction. |
| Unmodified generated baseline | Reconstruct only when exact generator+recipe remains available and admitted | Store baseline bytes or pin if regeneration cannot be guaranteed. Never substitute a new recipe under the old identity. |
| Same-value edits and explicit Empty edits | Persist edit intent / tombstone | Content equality with a baseline does not mean absence of user intent. |
| Finite fixtures / emitters | Persist owner lifecycle and counters, not merely recipe | Fired counts, cleanup status, active/retired state and target-plane phase prevent duplicate/revived sources. |
| Pending interlayer observations/routes | Persist exactly-once identity or drain/refuse | Source/target features, revisions, plane ticks, serial and consumed state must all remain consistent. |
| Transient masks / body contact projection | Reconstruct from matching authoritative body state at the defined boundary | Cell-only save cannot imply physical-owner continuation; pin affected chunks until an admitted body handoff exists. |
| New momentum/pressure/soliding state without a codec | Unsupported; pin or explicitly refuse eviction | “Optional” in memory does not mean disposable when authoritative and allocated. |
| Failed-world latch / partial-tick state | Refuse ordinary continuation capture | Diagnostic dumps remain diagnostic; validated fresh replacement is a separate operation. |

This allows GEN-006 to stage a conservative admission matrix: pristine supported
generated content can regenerate; edited or dynamic content needs its qualified
semantic record; content with unknown authoritative state remains resident or
returns a named refusal. No silent reset/defaulting is permitted to make a chunk
evictable.

### Saved pressure prototype: mandatory extension review

The [pinned v5 masks](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/patches/prototype-v5-vs-perf.diff#L1197-L1256)
put Water's signed8 lateral flow at bits 40–47 and unsigned8 overfill mass at
48–55; [air-state code](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto_b.inc#L388-L542)
uses bits 40–55 for an unsigned16 air amount on enclosed Empty cells. These
fields are material-dependent alternatives in the same region, not three
simultaneous cell fields. The production tuple material/a/b/temperature cannot
represent them. A future solver-specific extension must identify the meaning,
default, validation, units and lifecycle of each variant, independently of its
in-memory bit placement.

The registered E16 placement at 48–63 overlaps overfill and the upper air byte.
Preserving 40 material/state bits, 16 prototype bits and epoch16 requires at
least **72 logical bits**, or an explicitly different representation/sidecar.
C64E16 cannot retain all those inline widths. This is a capacity constraint;
it neither adopts the prototype nor makes raw 72-bit carriers a save format.
Any field remapping requires a schema/version decision rather than copying the
saved patch's masks into another carrier.

The saved algorithm's air amount is redundantly stored in resident Empty cells,
and equal amounts act as claim/history keys; they are not durable pocket IDs.
Movement/conversion may overwrite or clear those tags. Prepass pressure is
derived from the present geometry and amount, but previous pressure offsets
drive waking, and previous smooth volume drives optional damping. Thus “rebuild
the head field” does not establish equivalent continuation for the whole solver.
Current save/hash/render adapters do not carry all these semantics. A loader
must reject an unsupported pressure/air extension even if every visible material
fits the baseline catalogue.

Before admission, resolve this explicit unknown register: reconcile the archived
two-patch base and any newer local source; validate all effective environment
parameters; specify Empty-only chunk retention and air-tag reset/move/split/merge
rules; distinguish amount from stable topology identity; prove head/history
reconstruction or persist them; specify scratch bounds and allocation refusal;
and define a completed-phase capture plus conditional recipient-epoch behavior.
The [state inventory](mat-003prepass-state-inventory.md#available-saved-pressure-prototype-a-separate-state-contract)
supplies exact source sites and default ranges. Until those decisions are
implemented and qualified, pin/refuse such states. No prototype continuation is
accepted by this handoff.

## Epoch restoration requires a support-phase contract

Current [`granular_support_at`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L1331-L1361)
uses whether a cell was stamped in the current epoch, with a special fresh-world
tick-zero case. Moves/swaps, Water partial transfers, event writes, transport and
ordinary update suppression consume related predicates. Replacing every stamp
with zero while resetting the World counter can change both first-update
admission and between-tick support queries.
The [epoch consumer audit](mat-003prepass-epoch-consumers.md) is the detailed
source-site and test-obligation map for reviewing any restoration proposal.

The [isolated S1 World checkpoint](../audits/2026-10-22-mat003-world-correctness.md)
adds actual typed counters, uninterrupted ticks, support predicates, wake/event
records and ownership/refusal fixtures. Those observations compare live Worlds
without eviction or restore. They do not establish a valid rebase or a durable
continuation format; all-arm correctness evidence and continuation acceptance
remain separate claims.

One design candidate is to capture each relevant cell's **written-in-current-
epoch predicate**, then rebase equal/non-equal stamps into a fresh scheduling
cycle while preserving global tick, pending work and observation phase. This is
only a candidate: it needs a reviewed proof covering every epoch consumer,
external writes between ticks, long sleepers, interest re-entry, wrap and failed
replacement. The same-value setter's no-op behavior also needs coverage. A
short reload fixture or matching visible materials cannot prove it.

Until that proof and actual-World tests exist, GEN-006 must either use a pinned
same-solver full scheduling record at a defined phase or refuse continuation
for affected states. The proposed codec may describe such fields now, but their
acceptance remains gated. Widening the epoch only changes the wrap horizon; it
does not create a durable chunk incarnation or make this lifecycle problem vanish.

## Reconciliation preserves edits and old baselines

Use an explicit three-way input: **old generated baseline, current authoritative
state plus edit intent, new generated baseline**. Preserve the old recipe/content
identity used for the chunk, even after the active recipe advances. If the old
baseline is unavailable, return `baseline_unavailable`, retain current content
and pin/queue explicit resolution. Guessing the baseline from current bytes is
not a valid fallback.

Mutation receipts must distinguish “unchanged generated value” from “the owner
explicitly wrote the same value.” `World::set` currently returns on same-material
writes, and `write_cell` returns on identical tuples, so content dirtiness alone
cannot record that intent. A later GEN-006 implementation needs an owner-level
edit record with expected chunk incarnation/version, explicit touched coordinates
and operation provenance. That is separate from per-tick movement and scheduling
stamps. An Empty tombstone preserves a deliberate deletion even if a new recipe
would fill the coordinate; absence of a record means no edit, not deletion.

Conflict policy should be named and deterministic, with candidate reports before
publication. Do not label every reaction or moved cell as pristine generation;
simulation mutations need their own baseline/continuation treatment. For partial
reconciliation, allocate/stage complete accepted output and receipts before
retiring old state. Capacity refusal, stale completion and unknown schema leave
the current world and outstanding evidence unchanged.

## Clock, fixture and cross-boundary handoff

Current interest exclusion pauses ordinary selected work without elapsed-time
catch-up. Preserve global tick phase and retained deadlines; elapsed wall time
cannot be converted into fabricated fluid movement, burn progress or emitter
bursts. A sleeping chunk can still receive explicit external events or neighbor
writes, so “asleep” alone is not an eviction-safety proof.

For generated semantic planes, persist the admitted bundle identity and each
fixture's fired/cleaned/retired/active state, plus relevant transition and event
consumption receipts. Plane tick, rate and pause state are separate; background
must remain unticked. Deepworks' per-source `_fired` counts are not recoverable
from final material occupancy because native reactions can consume the emitted
reagents. Restoring only the recipe would restart finite sources incorrectly.

Current native material updates cross prepared chunk/core boundaries directly;
there is no general durable boundary-transfer queue. GEN-006 must define whether
neighbor-dependent chunks are pinned together, have bounded halos, or use a new
explicit pending-work protocol. Any new protocol needs ordered delivery,
source/destination incarnation checks, conservation, capacity/backpressure,
exactly-once application and pause rules. Merely serializing a pointer or an
in-flight job is rejected. Existing signed-coordinate overflow and capacity
admission rules remain mandatory.

## Compatibility matrix

| Consumer | Current compatibility | Proposed prepass/GEN-006 consequence |
|---|---|---|
| Native material APIs | Material enum byte; raw carrier material mask16; a accessor16/b8 | Experimental storage can preserve these capacities. Wider material catalogue requires a separate full path review. |
| State-carried IDs | Cloner/Rocket store IDs in b8 | New IDs above 255 cannot use these records unchanged. |
| Runtime Water policy | mass3–8, coherence0–12; FreeMass | Record exact policy. Extra storage is neutral until separately admitted physics defines it. |
| Saved Water pressure/air prototype | Separate archived solver at 7ef2aac; 16 spare bits carry flow/overfill or Empty air, with World-owned scratch/history | Require a distinct admitted solver/schema and complete extension records; current material/a/b records and an overlapping E16 placement cannot preserve it. |
| Transport profiles | Schema1 fixed legacy 81-entry tables with bounds-safe defaults for later materials | Preserve profile identity and default semantics; do not expand arrays implicitly. |
| Native hashes | Epoch/config/activity dependent `state_hash`; content-only hash omits Empty-at-ambient state | New semantic records and separately compared scheduling predicates are required; version the digest schema. |
| CYSD1 | Fixed 1024², five bytes/cell, selected demo metadata; no continuation | Preserve legacy import as level reconstruction. Use a distinct new envelope for sparse continuation; reject unrepresentable legacy export. |
| Render bridge / snapshots | Immutable RG8 material+derived condition, separately owned leases | Rebuild projection and publish fresh generations; never use RG8 as authoritative checkpoint state. |
| Generator proposals/cache | Material proposals under immutable recipe/module/algorithm identity | Old baseline must remain available. Cache/job results need session+incarnation+mutation admission receipts. |
| Depth / semantic fixtures | Four Worlds, independent clocks, finite lifecycle registries and explicit routes | Save owner state atomically across the admitted bundle or refuse a partial continuation. |
| Soliding/body/actor ownership | Separate bounded owners, incarnations and incomplete general continuation | Pin/refuse until a separate handoff is supported; cell codec alone cannot transfer ownership. |
| Runtime provenance | Exact source/toolchain/extension/platform evidence separate from document state | Experimental carrier tests do not qualify a new GDExtension, Web build or production save. |

## Required decisions before GEN-006 freezes a schema

Settle logical field domains and version identities; completed-tick capture and
failure boundaries; same-value edit/tombstone policy; old-baseline availability;
optional-field ownership and refusal; clock/pause/deadline restoration; and
exactly-once fixture/boundary-work rules. Document which classes can evict and
which are pinned. These decisions are required even if 64-bit storage is retained.

Keep epoch rebase and whole-engine equivalence explicitly gated. Full benchmark
ranking is not a prerequisite to defining layout-independent semantic records.
A production epoch/layout migration, catalogue widening, new phase conservation,
pressure/momentum solver or generic velocity field each needs a separately scoped
implementation and rollback/acceptance gates.

MAT-003 material appearance, catalogue authoring, reaction tuning and generator
palette/recipe improvements can follow GEN-006 if they declare their catalogue,
state/solver/recipe changes and compatible migrations. Any behavior introducing
new authoritative history or ownership must first satisfy the field and
continuation contract. No experimental capacity arm is a universal payload
reservation for those future features.

## Subsequent MAT-003 schema proposal

The [state-schema proposal](mat003-state-schema-proposal.md) and [ADR-015](../decisions/ADR-015-material-state-schema-and-carrier-gates.md) add Planned logical extension/epoch capacity accounting and adoption gates. They do not freeze a GEN-006 codec, assign pressure/air semantics or replace this canonical durable contract. No implementation changes follow from the shortlist.
