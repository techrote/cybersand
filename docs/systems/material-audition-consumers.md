---
title: Scene-local material audition consumers
status: Current
document-kind: contract
scope: Draft MAT-AUDITION-LIVE-001 native property applicability, transaction authority, reversibility and reconciliation boundaries
canonical-for: [scene-local-material-audition-consumers, scene-local-material-profile-native-contract]
last-reviewed: 2026-11-24
related-documents: [materials-and-rule-kernels.md, intermaterial-interactions.md, ../operations/materials-lab-authoring.md, ../architecture/material-authoring-catalogue-plan.md, ../architecture/data-ownership-and-lifetimes.md]
---

# Scene-local material audition consumers

## Current candidate and authority

**Current source on the Draft MAT-AUDITION-LIVE-001 candidate; not an accepted
production-default change.** This contract extends the accepted Materials Lab
and existing native Worlds for [issue #587](https://github.com/techrote/cybersand/issues/587).
Intake is accepted main `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
The retained catalogue, descriptor and interaction identities remain the authority
for defaults. The existing isolated candidate compiler and comparison Worlds
remain useful and separate from the new current-scene mechanism.

The profile is **one World's numeric configuration**. It cannot allocate a
material ID, change a kernel, replace cells, rebuild a World, rewrite the catalogue,
change another World or reset simulation time. Current-scene edits take effect
only after the exclusive simulation owner acknowledges a transaction between
ticks. The first admitted consumers are generic directional cell exchange,
generic whole-cell lateral mobility and existing compact-pair selection.

Native ownership is in [material_audition.hpp](../../native/include/cybersand/material_audition.hpp),
[world_material_audition.inc](../../native/src/world_material_audition.inc),
and the three call-site seams in [world.cpp](../../native/src/world.cpp).
The authoritative declarations remain
[material.hpp](../../native/include/cybersand/material.hpp) and
[interaction_rules.hpp](../../native/include/cybersand/interaction_rules.hpp).
Neither source is modified by the feature. A descriptor readback is a declaration;
the new World readback plus its capability restrictions identifies the active
consumer value.

## Capability map

The mode labels have precise meanings. **Live audition** uses the same World at
its next serialized owner boundary. **Paused transition** is the same transaction
while simulation is paused; pausing does not admit additional properties.
**Isolated comparison** runs an external candidate/reference World or descriptor
probe and cannot qualify the currently played World. **Rebuild/restart** uses an
existing explicitly disruptive reconstruction path. **Unsupported current-scene**
and **descriptive metadata** remain inspectable without a live slider.

### Descriptor and capability consumers

| Declared property | Actual native consumer and cadence | Applicability and derived state | Candidate mode |
|---|---|---|---|
| Density | `World::try_move` calls the World-owned density comparison before a cell swap, per movement operation | Numeric exchange rank for the 24 admitted movable materials below. Source direction, target permission, Oil/powder veto, powder/powder veto and exchange policy stay canonical. A changed value wakes relevant activity blocks once. | **Live audition** for this named consumer, integer 1..65535 |
| Density in inertial movement | `World::update_inertial`, in `world_inertial.inc`, calls the canonical `MaterialRules::can_density_exchange` directly | IN has a separate direct movement consumer. The generic exchange overlay does not retune its own motion. Generic cells can still compare against an IN material as their target. | **Unsupported current-scene** for the IN-owned consumer; explicit reconciliation seam |
| Density in PressureFlow top boundaries | `compute_pressure_heads` sums known non-Water liquid descriptor density in `world_pressure.inc` | Pressure head caches and their invalidation remain owned by PressureFlow; the exchange overlay does not change these values. Water quantity is the Water weight in that computation. | **Unsupported current-scene** for pressure boundary weight |
| Density in body reaction | `record_transient_contact` clamps the descriptor value; Wave body press also reads canonical Water density | Rapier/body impulse and Wave push values remain unchanged. No body mass or force promise is attached to exchange density. | **Unsupported current-scene** for body response |
| Viscosity index, generic liquid | `flow_as_yielding_liquid` reads `material_audition_effective_viscosity` per lateral attempt, after vertical/diagonal attempts | Paste, Slush, Brine, Cement, Toxic Sludge, Mercury and Molten Glass only; no derived numeric cache. It controls the byte mobility gate `(256-index)/256`, not gravity or arbitrary fluid viscosity. | **Live audition**, integer 0..255, subject to current solver admission |
| Viscosity index under IN | IN uses its own immutable policy damping and bypasses the generic gate | `material_audition_viscosity_available` is false for an IN-assigned material. An otherwise valid Brine descriptor edit is refused in that World. | **Unsupported current-scene**; existing solver-policy reconstruction remains separate |
| Mercury diagnostic viscosity | Existing `WorldConfig::physics_diagnostics.mercury_viscosity`, fixed at construction, precedes the generic descriptor | The new profile refuses a Mercury viscosity entry while that diagnostic owns the consumer, including an entry equal to the diagnostic value. Readback reports the diagnostic value. | **Rebuild/restart** to change diagnostic owner; no competing live authority |
| Water descriptor viscosity | `MaterialRules::apply_lateral_viscosity` scales FreeMass transfer; Water-CY has its own policy parameter; Wave and IN own different motion | These solver families are not interchangeable. The generic descriptor profile does not alter Water viscosity. | **Unsupported current-scene** here; existing Water policy selection is **rebuild/restart** |
| Lava, Acid and Oil descriptor viscosity | Their specialized movement paths bypass the descriptor mobility gate | A visible descriptor does not make an effective runtime control. | **Unsupported**, preserving the Lab's existing explanation |
| Base RGBA | Canonical descriptors feed `World::copy_rgba`; the production presentation additionally uses the independent palette/appearance projection/shader | Native preview color is not proof that the Workbench shader consumes a changed color. Renderer coordination is intentionally not added. | Existing **isolated comparison**; no new live visual control |
| Visual-state projection and appearance recipe | `project_visual_state`, native appearance tables, GDScript lookup and material palette shader | State encodings and renderer consumers must agree; changing one table is insufficient. | Existing descriptor/projection probe where admitted; **unsupported current-scene** |
| Hard-surface capability | Generated immutable four-word map consumed by `MaterialRules::is_hard_surface` | Collider masks, invalidation and body occupancy depend on this identity. The accepted #563 map remains unchanged. | Existing isolated descriptor probe; **unsupported current-scene** |
| Granular-support capability | Generated immutable four-word map consumed by `supports_granular_load` and sampled support admission | Actor and granular support policy stays canonical. Density is not a substitute for this capability. | Existing isolated descriptor probe; **unsupported current-scene** |
| Material state | Density eligibility, pressure-boundary interpretation, ballistic occupancy and other native family predicates | This is a semantic classification with several consumers; no general live conversion is admitted. | Template-held in Lab; **unsupported current-scene** |
| Kernel | Per-cell dispatch in `World::update_rule_kernel`; `rule_is_active` determines eligibility | Stored state meaning, movement, chemistry and lifecycle differ across kernels. | Template-held; source rebuild and separately admitted semantics required |
| Initial state A/B | Cell construction, explicit painting, emissions and reaction product initialization; current cells retain their stored values | Changing a declaration would not retroactively edit every existing cell. Water state is quantity-sensitive and solver-owned. | Template-held; **unsupported current-scene** |
| Maximum write radius | Validated against execution geometry in the World constructor | Worker write-domain admission is construction-time and safety-critical. | **Rebuild/restart** plus separately admitted kernel; not a slider |
| Density motion and accepts exchange | Canonical direction/target admission in native comparisons | Numeric profile values cannot bypass these permissions. | Template-held; **unsupported current-scene** |
| Lateral-flow mode | Family dispatch/query and viscosity/transfer helpers | Solver and quantity semantics are not changed by editing a label. | Template-held; **unsupported current-scene** |
| Valid/current-rule-available | ID validation, writes and `rule_is_active` | Reserved slot10 remains invalid; source/generator/parser compatibility stays protected. | **Unsupported current-scene** |
| Movable | Declared descriptor metadata and authoring admission, not a generic dispatch instruction | Native motion remains kernel-specific. Flipping a descriptor flag is not a new movement implementation. | **Descriptive metadata** for this mission |
| Name, category and browse tags | Catalogue inspection, search and presentation | Names and grouping do not grant thermal/chemical family membership or physics. Stable native declaration bytes remain compatibility inputs. | **Descriptive metadata**; candidate labels are not production renames |
| Material ID | Byte cell identity, serializers, policy arrays, products, palette and compatibility digests | Allocated0..131 with invalid10; no new allocation or remapping. | **Unsupported** |

The admitted generic exchange IDs are **2, 3, 4, 6, 8, 12, 13, 14, 16, 19,
20, 21, 22, 23, 24, 25, 26, 27, 29, 30, 32, 33, 36, 37**. These are Sand,
Water, Smoke, Fire, Lava, Acid, Stone, Dust, Oil, Seed, Paste, Slush, Steam, Salt,
Brine, Sodium, Gunpowder, Coal, Rust, Cement, Toxic Sludge, Mercury, Molten Glass
and Foam. The capability is derived by `material_audition_supports_density` from
valid, current, movable, exchange-accepting descriptors with a density direction.

The generic viscosity IDs are **20, 21, 24, 30, 32, 33, 36**. Admission is
World-specific, using `material_audition_viscosity_available`, rather than merely
copying this list into the UI. Existing generic liquid rest after failed rolls
is preserved. This feature does not repair the separate #354 thermal/sleep
programme or make all liquids perpetually active.

### Reaction consumers and witnesses

All **56 existing authored compact-pair slots** have immutable role-preserving
participants/products and a candidate probability threshold in the fixed
0..255 representation. The inclusive rule is `roll <= threshold`: **0 means
1/256, and 255 means 256/256**. There is no newly invented disabled sentinel.
The World profile cannot change the match mode, participant identity, product,
slot, stable rule ID, channel, state effect, quantity effect or specialized
mechanism. Existing isolated effect-v2 experiments remain isolated.

On a configured reaction path, the canonical cached resolver obtains the
authored first match at roll0. The World then applies only that slot's effective
threshold to the actual deterministic byte roll. Product orientation still
comes from `MaterialRules::pair_reaction`. Unchanged reaction configuration
uses the original resolver path directly. Pair scheduling, neighbour order,
random salts, role-specific default initialization and quantity ledger writes
remain in `World::update_rule_kernel`.

`material_audition_probability_available(slot)` requires at least one potential
native initiator in the current World. **Wave suppresses Water's per-cell
kernel**. Water plus an inert Raw Clay/Gypsum-like endpoint therefore has no
compact-pair initiator, and its live threshold is refused. Salt is active and
can initiate against Wave Water, so Water+Salt remains available. State-dependent
eligibility, body masks, selected simulation region, contact, temporal lane and
competing specialized mechanisms still determine whether a particular pair
actually executes. Availability is not an execution witness.

The native tests corroborate actual reaction execution using both stored
role-specific products and `quantity_ledger().pair_events[slot]`. Authored
metadata or resolver inspection with a supplied roll is only predicted
selection. A lower probability for an Acid pair does not disable Acid's broad
corrosion path; Fire, thermal and other specialized consumers remain distinct.

## Transaction, lifetime and reversibility

The native request supplies **expected World identity**, **expected prior
configuration revision** and a **complete replacement profile**. The host owns
the session identity, intent ordering, cancellation and main-thread feedback;
the native World independently validates its generated identity and revision.
An old request cannot configure a replacement or cleared scene. World moves
transfer the identity and zero the moved-from token. `clear()` obtains a fresh
token and returns configuration to accepted defaults.

The native profile has schema version1, a bounded ASCII `profile_id`, fixed
arrays of integer overrides and an internal inherit sentinel. External parsers
must reject unknown fields, duplicate rows/properties, fractional values,
out-of-range IDs, booleans masquerading as integers and malformed schema before
narrowing to the native arrays. A profile is not an arbitrary partial patch:
omitted entries inherit accepted defaults, which makes replacement and reverting
well-defined. Names/descriptions and persistence provenance belong in the
validated outer preset envelope, not the tick-time table.

Validation, candidate allocation and capacity checks finish before publication.
The exclusive owner swaps one prepared table between ticks. Workers see one
unchanging profile for their entire dispatch. No string lookup, mutex,
allocation or full-world scan is added to per-cell consumers. A rejected
transaction retains the old table, revision, cells and scheduling. Native
outcomes include wrong World, stale revision, failed World, active tick,
unsupported property, invalid value/schema/identity, revision exhaustion,
allocation failure and scan capacity refusal.

A behavior-changing transaction scans **resident nonempty chunks once**, capped
at **16 Mi cells**, to wake existing activity blocks holding affected materials
or changed reaction endpoints, plus immediate block-boundary neighbours. It
does not allocate chunks, redraw unchanged cells or keep all liquids awake.
Wake granularity is the existing activity block, so nearby cells in that block
may receive an ordinary visit. Remote unrelated blocks are not woken. Scan and
woken-block counts are returned. Reapplying equivalent effective values records
a new revision but performs no scan/wake. Named profiles that explicitly spell
accepted defaults retain the exact default physics path and physical identity.

**Revert restores configuration, not simulation.** Reacted or moved cells,
temperatures, elapsed ticks and reaction event history are retained. Reset to
accepted defaults follows the same transaction. Restoring complete physical
state, when supported elsewhere, is a separate operation and is not claimed by
the Lab's configuration history.

## Persistence, identity and reconciliation seams

Named material profiles retain their supported values, schema, native
compatibility/source identity and authoring provenance independently from
canonical defaults. The native `behavior_hash` binds effective density,
viscosity and threshold arrays; profile names and revision counters are not
physical values. Source identity remains necessary because this bounded hash
is not a proof of cross-version consumer compatibility.

Default and equivalent-default Worlds preserve their existing physical hash
versions and serialized bytes. A nondefault profile reports **physical hash
version7**, including its effective arrays before the existing physical-state
stream. The current CYPS formats do not retain these arrays: their format
version is0 for such a World, and `save_physical_state` explicitly refuses.
This prevents a seemingly complete checkpoint from silently losing active
configuration. Exporting a profile is supported separately. Ordinary authored
scene material saves do not thereby become complete simulation continuations;
the host must describe exactly whether a profile accompanies its scene format.

RAMCACHE/persistent-area owners can later carry a validated profile envelope,
source compatibility and fresh transaction admission alongside their state.
No stale World/session token should be persisted as an authority token. A
future lossless CYPS extension must explicitly encode the profile and receive
its own versioned replay and corruption qualification. This mission does not
implement that extension or absorb an active persistence branch.

The exact protected write seams are the three `world.cpp` consumer calls,
World construction/clear identity hooks and the nondefault physical hash/save
guards in `world_pressure.inc`. New configuration code is isolated in
`world_material_audition.inc`. PUBPRES owns scheduling and publication, ObjectShard
owns occupancy/material bodies, and Water families retain their solver code.
Any reconciliation with their active branches must preserve those ownerships.
The immutable compatibility lock and descriptor/pair bytes are unchanged.
Protected-source review/transition authentication is recorded separately after
the source is frozen and independently reviewed; a green check is not obtained
by refreshing the lock.

## Qualification boundaries

[test_material_audition.cpp](../../native/tests/test_material_audition.cpp)
contains actual World witnesses, exhaustive byte-domain default/unrelated-query
comparisons, independent-World isolation, exact equivalent-default continuing
hash/save comparison, invalid and stale transaction attacks, moved/cleared World
retirement, revision exhaustion, scan capacity refusal, solver applicability,
native reversion and explicit save refusal. Targets are
`make material-audition-test`, `make material-audition-sanitize` and
`make material-audition-thread-sanitize`.

The viscosity fixture covers all seven admitted materials at indices0,128,255
in the same96 enclosed horizontal bays for one tick, repeated with1 and4 native
workers. Gravity and diagonal paths are blocked; curing/cooling lifetimes do
not expire in that one-tick window. This witnesses lateral movement through
the viscosity consumer rather than inferring its effect from readback alone.

For every56 authored pair slots, resolver checks cover both endpoint
orientations and all256 rolls at thresholds0,31,255, including role-specific
products and the unchanged rule identity. Separate actual World fixtures put
each pair in32 enclosed contacts for4 ticks at thresholds0 and255, in both
spatial orientations. These inspect native pair-event ledgers: they are
execution evidence, not predicted eligibility. Later product kernels may
change cells after a reaction, so per-slot event evidence and endpoint-role
resolver checks are deliberately reported separately. The Water/Salt fixture
also corroborates actual events with stored Brine products at three settings.

Tests in source describe required checks; they are not themselves a claim that
every platform or sanitizer has passed. Exact-source receipts in the mission
decision packet distinguish Linux native runs, hosted Windows execution,
graphical interaction, extracted-package execution and physical owner acceptance.
No native assertion count establishes Windows/NVIDIA feel or permits Ready,
automatic merging or default promotion. The implementation remains **Draft/HOLD**.
