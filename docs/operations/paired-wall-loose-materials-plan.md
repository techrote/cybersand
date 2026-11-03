---
title: Paired wall and loose materials with finite curing
status: Planned
document-kind: design
scope: Implementation sequence and admission gates for authored load-bearing material shells, shared chemistry and finite local curing; no native implementation or qualification claim
canonical-for: [paired-wall-loose-materials-plan]
last-reviewed: 2026-11-03
related-documents: [microscenarios-programme.md, ../systems/intermaterial-interactions.md, ../systems/materials-and-rule-kernels.md, ../architecture/rigid-body-and-cellular-coupling.md, ../architecture/soliding-lifecycle.md, gcr-rest-registration.md]
---

# Paired wall and loose materials with finite curing

## Decision and implementation boundary

**Planned:** give a small set of substances separately authored loose and wall
forms. The wall form supplies normal hard-terrain collision until its cells are
destroyed or converted. Breaking a shell exposes the ordinary loose material
inside. This is level composition using existing cellular and Rapier ownership,
not a claim that powder itself has become a stable rigid floor.

This page specifies the future implementation and its admission tests. It does
not implement materials, change Cement, promote a GCR candidate, add sleep, or
claim successful runtime qualification. The accompanying flyer-control work is
separate. PR #351 remains unmerged; this material work needs its own focused
implementation checkpoint after the registration below is committed.

**Approved direction from the owner:** the feature concerns granular solids as a
category, rather than special treatment for yellow Sand. Preserve the playable
lightweight flyers and the actual payload-derived mass of detached structures.
Shells are useful authored guarantees alongside granular response; they do not
close the remaining granular rest, friction, correction or torque questions.

## Current source and ownership

The inspected source checkpoint is
`f6cd386824013e1498af37493aff78198f2786ff`, on
`codex/gcr-rest-comparison-20261102`. Source statements below describe that
checkpoint; no new material runtime was built or tested for this plan.

| Current fact | Source and consequence |
|---|---|
| Native cells own material identity and state; Godot owns presentation and input. | [Materials and rule kernels](../systems/materials-and-rule-kernels.md). A shell must be real native material, not a visual overlay or erased/restored body. |
| INT-000 owns non-kinetic reaction semantics. Movement, granular response and Rapier are separate owners. | [Interaction contract](../systems/intermaterial-interactions.md), under the [MicroScenarios programme](microscenarios-programme.md). Extend that substrate and its provenance rather than introduce a shell reaction resolver. |
| Hard cells become static Rapier rectangles; cellular hard-contact response is disabled. | [Rigid/cellular ownership](../architecture/rigid-body-and-cellular-coupling.md#who-resolves-hard-terrain-and-thin-floors). Hard shells use this existing owner. |
| Granular load capability is explicit, not inferred from density or name. Stone is currently granular; Concrete is hard. | [`MaterialRules::supports_granular_load` and `is_hard_surface`](../../native/src/material_rules.cpp), [`MaterialDefinition`](../../native/include/cybersand/material.hpp). “Dense” here means a bonded form, not a magic increase of density. |
| Hard classification currently includes every ID from LimestoneBlock through `kLastMaterial`. | [`is_hard_surface`](../../native/src/material_rules.cpp). Appending a loose precursor and advancing `kLastMaterial` would incorrectly make it hard unless this range assumption is replaced or bounded explicitly. |
| Some existing building cells already convert to loose material. | [`kPairInteractionRules`](../../native/include/cybersand/interaction_rules.hpp): RammedEarth + Water yields Sand; Sandbag + Fire yields Sand; RockSaltBlock + Water yields Salt and Brine; GypsumBoard + Fire yields Dust. These are individual laws, not a complete shared-chemistry pairing system. |
| Existing themed construction materials do not automatically inherit all base Metal/Glass semantics. | [Explicit semantic families](../systems/intermaterial-interactions.md#explicit-semantic-families). Pairing must be a deliberate versioned change, not an alias inferred from appearance. |
| Current Cement cures next to air, Water/Brine or Concrete; neighboring Concrete accelerates cure. | [`RuleKernel::Cement`](../../native/src/world.cpp), with INT-000 provenance in [`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp). It does not consume a finite Water activation budget and is unsuitable as the unchanged model for non-propagating wet crust. |
| Explosions erase an inner disk; their outer collapse special case converts Wall to Stone. | [`World::apply_pending_explosions`](../../native/src/world.cpp). They do not currently turn every hard material into its matching powder. |

**Deferred:** unsupported islands falling as coherent rigid objects, arbitrary
fracture, structural strength, automatic load-induced crumbling, healing and
body-to-cell restoration. Those need the [#12 soliding lifecycle](../architecture/soliding-lifecycle.md).
A severed wall island may remain static in this first feature. The lab must say
so visibly. A hole can be made by a cell conversion/removal without adding a
per-cell damage or hit-point tracker.

## Substance and form contract

**Planned design:** retain distinct public material IDs for the two forms and add
an explicit native, immutable substance/form descriptor. Each pair declares its
chemical parent, loose counterpart and hard-surface capability. This mapping is
authoritative data within the existing material/INT-000 substrate; Godot receives
values for labels and inspection rather than independently deciding chemistry.

Shared chemistry means matched reaction channels, probabilities, lifecycle
conditions and products at an equivalent exposed contact. It does not promise
identical bulk outcomes: an immobile shell and mobile grains expose different
surface area, mix differently and receive different contacts.

Do not pass a chemical alias to movement, density exchange, granular sampling,
hard-terrain extraction, electrical transport or the entire rule-kernel dispatch.
In particular, a Coal wall may reuse Coal combustion chemistry while remaining
immobile. The current Combustible kernel combines context and state work; its
chemical transition must be separated from movement only as far as the paired
fixture proves necessary. There remains one authoritative transition path.

Every inherited or overridden reaction needs an explicit product-form policy:

- An unchanged participant keeps its original form and valid state. A neighbor
  reacting with a shell must not silently turn every contacted shell cell loose.
- A genuine chemical conversion uses the authored product form. Gas, liquid,
  soluble products and loose residue remain their ordinary products unless an
  explicit rule selects a new hard product.
- Mechanical breakage is a separate, local wall-to-loose transition of the same
  substance. It does not stand in for dissolution, burning or corrosion.
- No generic “preserve wall” rule may turn Smoke, Brine or Dust into an invented
  hard version. No generic “use parent product” rule may accidentally change a
  surviving wall participant into loose powder.
- Source/target roles, rule priority, probability boundary and channel provenance
  remain explicit. The pair partner cache must include every admitted wall
  participant and agree with the authoritative resolver.

The first registration should admit these three candidate families, with names
and values finalized before implementation results:

| Proposed family | Initial forms | Purpose and required decision |
|---|---|---|
| Stone | Existing loose Stone; new Stone Wall | Inert hard/loose control and physical shell. Reuse current Stone chemistry exactly; do not invent an acid or heat reaction merely to demonstrate one. |
| Salt | Existing Salt; new Salt Wall | Soluble shell. Inherit the loose Salt dissolution law and explicit Brine/remaining-Water products. Do not silently reuse RockSaltBlock's different transition as equivalence. |
| Coal | Existing Coal; new Coal Wall | Combustible shell. Preserve Coal ignition/burn state and authored residues while suppressing loose movement in the wall form. Declare exactly when burning cells cease to be hard. |

These are proposed names and a bounded starting population, not accepted tuning.
Existing RockSaltBlock, Sandbag, RammedEarth and other building materials keep
their current IDs and laws. Extending the pairing list later requires explicit
family admission; it must not be implicit for all 132 current IDs.

## Finite curing prototypes

**Planned:** start with one separately named water-activated binder family, rather
than changing current Cement/Concrete. Proposed palette entries are Dry Binder,
Activated Binder and Binder Crust. Dry Binder is loose; Activated Binder carries
only its own finite activation/cure state; Binder Crust is hard terrain. Colors
may progress from dry powder to damp darker rim to solid crust so that the
surface growth reads clearly at integer pixel scale.

The water-activation accounting is a mandatory design gate before implementation:
select a fixed, documented Water quantity debit per activated binder cell, using
the existing native Water quantity ledger. The debit and chemical product/retained
water accounting must close exactly. Water cannot simply be erased as one
whole-cell pair product, and remaining Water cannot be recreated at full quantity.
No pressure or transport law is introduced by this contact reaction.

If that debit cannot be expressed safely in the existing bounded contact path,
the first prototype must instead use a separately named finite Curing Agent with
explicit whole-cell accounting. It must be labeled as that material, not Water,
and the water-reactive version remains unimplemented. This choice and the ledger
units must be frozen in the registration, not selected after seeing results.

The activation/cure invariants are:

1. Only an explicit supplied agent can activate a previously dry cell. Each
   activation consumes a declared nonrenewing quantity or token from that agent.
2. Activation is local with an explicit bounded neighborhood and write set. No
   flood fill, region scan, hidden reservoir, or unbounded growth queue is allowed.
3. An activated cell can complete only its own finite countdown/conversion. It
   cannot donate activation to another dry cell.
4. New crust is inert as an activator. Neighboring crust, air, age alone or the
   visual damp color cannot start another cell's cure.
5. Removing the supplied agent stops new activation. Already activated cells may
   finish, with their remaining budget fully visible in state/accounting.
6. Breaking a finished crust does not replenish activation. Loose residue, if
   supplied, is spent binder rather than automatically fresh Dry Binder.

Surface-limited agent exposure should therefore make a finite rim around a loose
interior. A newly opened crack admits fresh agent only if the player supplies it.
The owner’s “first few seconds” is a presentation target to test; the exact cure
cadence, thickness and amount are preregistered candidate values, not claims here.

A second, optional prototype is a two-part Sealing Resin + Hardener producing a
distinct Seal Crust. Both inputs have finite local consumption, and the cured
product is never a catalyst. It offers an authored crust independent of Water.
Admit it only after the first family passes; do not expand the initial experiment
into a general construction chemistry system. Heat-only self-spreading cure and
copying Cement's Concrete-neighbor activation are out of scope.

## Implementation sequence and write set

All steps below are **Planned**. Fetch current main again before source changes,
inspect active #29/INT-000, #12 and coupling write sets, and record the actual
starting SHA/tree, exact dependency pins and native runtime identities. Reconcile
with their owners before editing the shared World path. This plan's source SHA
is an inspection reference, not a request to stack future work on this branch.

| Step | Owned changes | Exit gate |
|---|---|---|
| 0. Registration | New compact scenario manifest and decision criteria; source/ownership ledger; selected IDs/names, chemistry matrix and cure ledger. | Commit before candidate execution. Record current controls and retain failures. |
| 1. Capabilities and identity | [`material.hpp`](../../native/include/cybersand/material.hpp), [`material_rules.hpp`](../../native/include/cybersand/material_rules.hpp), [`material_rules.cpp`](../../native/src/material_rules.cpp). Replace the open-ended hard-ID range assumption with explicit reviewed capability data; append IDs without renumbering existing entries. | Every existing ID retains hard/granular classification and current behavior; every new loose/agent ID is non-hard; every wall/crust ID is hard and non-granular. |
| 2. Shared chemistry | [`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp), necessary narrow [`world.cpp`](../../native/src/world.cpp) kernel separation. Reuse INT-000 selection, product effects, source/context provenance and derived partner sets. | Matched wall/loose channel fixtures pass; no duplicate effects or movement inheritance; old material oracle remains unchanged. |
| 3. Local break and collider lifetime | Native authoritative conversion/removal through existing bounded world commands; inspect [`cyber_native_cell_world.cpp`](../../godot/native_extension/cyber_native_cell_world.cpp), [`simulation_worker.gd`](../../godot/scripts/simulation_worker.gd), [`rapier_physics_bridge.gd`](../../godot/scripts/rapier_physics_bridge.gd). Change adapters only if the existing contract cannot express the event. | Native hard revision, snapshot consumption and Rapier retirement/rebuild are observed. No ghost support, duplicated contact response, or early collider destruction before native commit. |
| 4. Finite curing | Explicit new descriptors and INT-000 context/lifecycle entries; narrow World implementation and quantity-ledger integration if admitted. | Agent/activation/product ledger closes; agent removal and no-agent controls stop the front; current Cement fixtures remain unchanged. |
| 5. Presentation and lab | [`cell_world.gd`](../../godot/scripts/cell_world.gd) ID/fallback boundary, [`material_appearance.hpp`](../../native/include/cybersand/material_appearance.hpp), [`material_appearance_lut.gd`](../../godot/scripts/material_appearance_lut.gd), picker metadata and a small dedicated scene/host linked from [`gcr_fleet_playground.gd`](../../godot/scripts/gcr_fleet_playground.gd). | Full material painting and existing flyer controls remain usable; explicit shell/binder labels and source receipt; no UI code implements chemistry. |
| 6. Qualification and handoff | Native/host regressions, compact receipts and canonical documentation/retrieval updates. | Technical gates and playable review are distinct; draft PR remains unmerged pending owner acceptance. |

Prefer a narrow reuse of current authoritative paint/explosion commands for the
first hole test. A separate wall-to-loose break operation is needed only to
demonstrate retained rubble. It must declare its selected cells, conversion
products, state initialization and capacity refusal; it must not become a new
hidden force/relocation path. Collisions and applied actor thrust do not
automatically destroy walls in this feature.

## IDs, saves, ABI and runtime provenance

**Planned requirements:**

- Allocate appended IDs after the actual current `kLastMaterial`; check the
  one-byte limit and every fixed-size material table, lookup, shader/palette,
  `LAST_MATERIAL` mirror, picker, serialized fixture and capability derivation.
  Reserve no IDs from this document before reconciliation with current main.
- Define each state byte's meaning, initialization, saturation, conversion/reset
  behavior and serialization. A cure token/countdown must not borrow a byte that
  a reused burn or liquid kernel interprets differently.
- Keep the C/C++ cell layout and public ABI unchanged if the admitted design fits
  existing fields. Any extra state or exported function needs an explicit ABI
  review; it is not implied by adding materials. Native adapter descriptor and
  interaction-profile inspection must reveal the new IDs/forms and rule identity.
- [`CYSD1`](../../godot/scripts/demo_save_codec.gd) is a reconstructable level, not
  a full runtime replay. Prove save/load preserves new IDs and cure state at its
  actual supported boundary. Do not promise a new save version is unnecessary
  until native export/import and metadata validation are inspected. Old runtimes
  must reject unknown IDs safely rather than reinterpret them; no existing ID is
  repurposed. Serialized test replay records agent inputs and source/catalogue ID.
- The Godot fallback currently implements a narrower law set. Either implement
  the admitted feature with explicit parity tests there, or refuse/disable this
  lab and these painting entries without a matching native runtime. A fallback
  that silently renders the new loose material as static is unacceptable.
- Material descriptors and reactions are native production inputs. Build and
  publish source-matched Windows/Linux libraries according to repository policy;
  record source SHA, native input fingerprint, runtime hashes, backend and platform.
  Do not reuse the pre-feature GCR runtime as proof of material implementation.
- Regenerate the interaction inventory/provenance and affected derived capability
  data, including LCB fingerprints when their inputs change. Version a changed
  interaction profile/tuning pass; never edit historical oracle hashes or old
  qualification receipts to match the new catalogue.

## Preregistered qualification population

Freeze geometry, support thickness, body mass/inertia, gravity, GCR response and
budget, actuation cap, contact opportunities, seeds, timeout and observation
windows before candidate results. Retain the known ordinary hard-wall floor and
all-loose material controls. Use synchronous one-worker native fixtures first,
then worker/edge parity and a small real asynchronous host set. Latency must use
the existing owner handoff, not fabricated age fields.

| Registered arm | Comparison and required observations |
|---|---|
| Capability/oracle | All old materials and new forms: hard/granular membership, density/movement opt-ins, stable IDs, original reaction outcomes and derived pair-cache equivalence. |
| Shared chemistry | Exposed Stone, Salt and Coal contacts in both forms; reactant/role reversal, successful and failed probability rolls, repeated contact, state transitions and products. Test same contact opportunity directly; separately report surface/mixing differences in a bulk shell. |
| Three-bay shell fixture | Identical contained powder geometry: A all loose; B intact matching shell; C same shell with a known bounded breach. Use a stationary load, gentle drop and modest controlled lateral push. Deep floor placement and receipts must reveal any hard-floor contribution. |
| Destruction/release | Authoritative hole removal, same-substance wall-to-loose break if admitted, Salt dissolution and Coal burn-through. Record before/after native cells, material accounting, hard revisions, collider shapes, body support and first unsupported motion. Partial holes and chunk-seam openings must not leave phantom support. |
| Re-entry | Exposed powder remains ordinary granular material; body can enter the new opening and interact with it. Newly authored replacement wall cells rebuild collision under the same contract. No material teleport, body erase/restore, or second bearing owner. |
| Finite curing | No agent, measured finite dose, larger measured dose, removal mid-cure, already-cured neighbor only, isolated activated cell, shell crack with/without fresh dose, world/chunk edges and capacity refusal. Count dry/activated/crust/spent states and agent/product quantities. |
| Host lifetime | Actual asynchronous painting, chemical conversion and destruction while a body contacts the shell; stale/duplicate samples and failed/refused native work preserve the existing quarantine/rollback contracts. |
| Controls | Existing Cement, Water quantity/state, ordinary hard terrain, granular ejection/conservation, REM-002/REM-003 support and GCR material-freshness controls remain independently reported. |

Preregister these decisions before implementation, rather than inventing a score
afterward:

1. **Correctness is exact:** zero unexplained cell/Water/agent quantity change;
   every destructive event has an explicit product/removal ledger; old oracle,
   save identity and owner/lifetime regressions pass.
2. **Hard support and release are owner-specific:** intact shells use Rapier hard
   contact with zero granular bearing attributed to wall cells. A removed hard
   patch must cease supporting by the documented collider admission/rebuild
   boundary. Record and gate its actual worst-case latency; do not assert that
   the current soft terrain rebuild budget already guarantees a next-tick update.
3. **Finite cure is bounded:** total activated cells cannot exceed the registered
   finite supply bound. With no agent left, additional activation is exactly
   zero; existing activations finish only within their original budget. Cured
   neighbors alone activate zero cells. Agent-derived quantities close exactly.
4. **Performance is bounded:** declare probe/writes per interaction, queue and
   chunk capacities, refusal behavior and tick/host p50/p95/p99/max acceptance
   thresholds from the current control budget before candidate runs. Measure
   terrain rebuild bursts separately from reaction time. No hot allocation,
   whole-world scan or unsupported end-to-end timing claim.
5. **Gameplay acceptance is explicit:** an intact shell feels like normal authored
   floor; breaking it visibly exposes loose material and admits the actor;
   finite curing reads as a rim rather than an autonomous flood. Record the
   owner's verdict and unsupported behavior, including static severed islands.

Failure of a family narrows or rejects that family; it does not justify changing
all powder response laws. A failed Water ledger defers Water activation rather
than weakening conservation. A failed collider-release gate blocks the playable
feature even if its pixels look correct.

## Playable review and documentation handoff

**Planned lab:** a compact annex in the large flyer/material-painting playground,
with the three clearly labeled bays and a separate curing tray. Reset restores
the exact initial map. A local control makes a known breach; ordinary Acid/Fire
painting then demonstrates admitted chemical destruction. The tray allows one
measured dose and removal of the source so the stopped front is visible. Display
actual native source/runtime identity, material catalogue/profile and the fixed
body/response settings. Keep free painting available for exploratory play while
separating its receipt from the registered run.

At implementation checkpoint, update the canonical material and interaction
contracts, hard-terrain interface/lifetime contract if changed, appearance/picker
controls, save compatibility, roadmap qualifiers and this plan's status together.
Route the focused plan from the documentation index and retrieval manifest and
add questions for shared chemistry, wall destruction, finite cure, and the
current Cement distinction. Preserve existing historical evidence and failures.

Run the appropriate native and sanitizer material/interaction/quantity tests,
candidate shell/cure fixtures, Godot/GDExtension host and save/fallback checks,
hard-collider destruction/lifetime tests, scoped GCR/support controls, and both
source-matched platform runtimes. Then run `check_docs.py`,
`check_m11_consistency.py`, `check_repository.py`, retrieval evaluation and
`git diff --check`. Record unavailable gates explicitly; a document or playable
preview is not proof that the native mechanism passed.

The handoff is a focused draft PR with compact manifests/summaries and selected
traces, an exact-head qualification record, clear unsupported envelope and owner
review instructions. Keep it unmerged. No sleep, friction retuning, global
structural collapse or REM-004 completion follows from this plan.
