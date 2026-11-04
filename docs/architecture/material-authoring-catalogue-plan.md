---
title: Canonical material catalogue and interaction authoring — adopted Planned baseline
document-kind: design
canonical-for: [material-authoring-v1-programme-proposal]
status: Planned
scope: Owner-adopted Planned material-authoring baseline; section 14 records the draft 353-B Main-label consumer and post-377 admission, section 15 retains accepted Phase A and its production boundary; sections 1–13 preserve historical proposal, review, adoption and A-only integration
last-reviewed: 2026-11-04
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, ../systems/building-material-catalogue.md, ../systems/themed-construction-materials.md, ../systems/granular-interaction-policy.md, ../systems/flow-transport-and-profiles.md, item-authored-material-programs.md, liquid-state-transition-matrix.md, ../operations/documentation-maintenance.md]
---

# Canonical material catalogue and interaction authoring — adopted Planned baseline

**Owner-adopted Planned baseline; accepted #353-A and #354 Phase A, with one
separately assigned draft #353-B consumer — 2026-11-04.** Documentation #357 and
A-only implementation #371 are merged. [#371's final ledger](https://github.com/techrote/cybersand/pull/371#issuecomment-6620789829)
records accepted A-only main `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`.
[#377](https://github.com/techrote/cybersand/pull/377) subsequently merged the
tests/tooling/evidence-only liveness investigation as `0103de80`; the
[Phase A boundary](#15-material-liveness-phase-a-and-production-admission--2026-11-04)
preserves its findings and separately pending production correction.
[Section 14](#14-bounded-main-display-name-consumer-and-proof-transition--2026-11-04)
records the owner-assigned generated Main labels, scoped current proofs and
apparatus source transition. Its post-#377 reconciliation changes only the
accepted B executable baseline to `0103de80`; the display oracle and 27-owner
authority stay frozen. Fresh independent admission review must precede Ready.
No #384 merge or other production consumer migration is authorized.

The [current-main admission correction](#11-current-main-review-and-implementation-admission--2026-11-03)
and [source-qualified review](../audits/2026-11-03-mat-auth-000-architecture-review.md)
retain the technical design and its evidence. Sections 1–10 retain the original
2 November text from PR #357 at `fc7f74768bb3d24fb7e913615f6774dbff321f91`.
Sections 11–13 preserve the later review, documentation-adoption and A-only
integration boundaries, including their original assignment statements.
Their source identities and evidence remain historical even where reverified;
section 14 owns the draft Main-label admission and section 15 retains accepted
Phase A's separate production boundary. The broader migration, H1 correction
and #355/#356 remain separately gated. The [#371 ledger](https://github.com/techrote/cybersand/pull/371)
owns its final-head, merge and post-merge receipts.

**Status: Planned broader migration; one implemented labels-only candidate.**
The new Main presentation authority changes no native or fallback material
physics, policy, save or transport semantics. It activates no inheritance system,
default rebalance, new material ID or runtime editing. Metadata equality and
source checks alone do not establish actual UI or gameplay acceptance.

**Source intake:** [`a8f08a67fea3c58f6df7473cbae1831334fcc04e`](https://github.com/techrote/cybersand/commit/a8f08a67fea3c58f6df7473cbae1831334fcc04e) on `main`, inspected 2026-11-02. Recheck live `main`, source/runtime identities, active branches, and the latest owner decision before each implementation stage. Evidence categories below distinguish source inspection, retained prior characterisation, proposed tests, and proposed semantics.

**Tracking:** [MAT-AUTH-000 #352](https://github.com/techrote/cybersand/issues/352), [MAT-AUTH-001 #353](https://github.com/techrote/cybersand/issues/353), [MAT-AUTH-002 #354](https://github.com/techrote/cybersand/issues/354), [MAT-AUTH-003 #355](https://github.com/techrote/cybersand/issues/355), [MAT-AUTH-004 #356](https://github.com/techrote/cybersand/issues/356).

## Contents

1. [Authority and preserved substrate](#1-authority-and-preserved-substrate) — what already exists, and what the programme may not overwrite.
2. [Source findings and fault hypotheses](#2-source-findings-and-fault-hypotheses) — exact observations, ownership and required reproductions.
3. [Orthogonal material classification](#3-orthogonal-material-classification) — browsing, physics, semantics and presentation stay independent.
4. [Canonical source model and compiler](#4-canonical-source-model-and-compiler) — source layout, generated outputs and hard validation.
5. [Interaction effects and effective parameters](#5-interaction-effects-and-effective-parameters) — explicit endpoint semantics, threshold representation and real kernel consumers.
6. [Scheduling and liveness qualification](#6-scheduling-and-liveness-qualification) — bounded wake obligations and gameplay-decision gates.
7. [Identity, compatibility and resource budgets](#7-identity-compatibility-and-resource-budgets) — do not change saves, cells, runtime authority or replay claims accidentally.
8. [Materials Lab authoring workflow](#8-materials-lab-authoring-workflow) — usable editing without fake live sliders or fallback claims.
9. [Issue dependency and acceptance plan](#9-issue-dependency-and-acceptance-plan) — finite steps, qualification, rollback and write-set separation.
10. [Decisions held for explicit disposition](#10-decisions-held-for-explicit-disposition) — questions to resolve with evidence rather than guesswork.
11. [Current-main review and implementation admission](#11-current-main-review-and-implementation-admission--2026-11-03) — corrected compatibility boundary, minimum compiler slice and owner decisions.
12. [Owner adoption and shadow-compiler handover](#12-owner-adoption-and-shadow-compiler-handover--2026-11-04) — documentation-only approval, separate implementation assignment and preserved compatibility gates.
13. [Bounded compatibility tooling and adopted-main reconciliation](#13-bounded-compatibility-tooling-and-adopted-main-reconciliation--2026-11-04) — implemented shadow foundation, source-preserving integration and separate consumer-migration gates.
14. [Bounded Main display-name consumer and proof transition](#14-bounded-main-display-name-consumer-and-proof-transition--2026-11-04) — the separately assigned labels-only candidate, scoped current proof and draft review boundary.
15. [Material liveness Phase A and production admission](#15-material-liveness-phase-a-and-production-admission--2026-11-04) — merged foundation, three distinct findings and separately pending scheduler implementation.

## 1. Authority and preserved substrate

The existing native model is useful and should be retained: immutable `kMaterialDefinitions`, bounded `RuleKernel` execution, no material-owned threads or per-cell objects, byte-sized material identity, stored `state_a/state_b` and epoch, deterministic contact and movement, sparse explicit reaction tables, per-World liquid family policies, versioned source identity, and the Materials Laboratory/MicroScenario corpus.

| Source-derived property | Value at intake | Authority |
|---|---:|---|
| Material slots | 132, indices 0–131 | [`material.hpp`](../../native/include/cybersand/material.hpp) |
| Valid entries / non-empty paintable entries | 131 / 130 | Same; ID 10 reserved invalid, ID 0 Empty |
| Broad phase states | Empty 1, Solid 104 (including invalid 10), Powder 9, Liquid 11, Gas 4, Agent 3 | Same |
| FreeMass / CellularYield liquid descriptors | 1 / 10 | Same (selected opt-in family may differ from default) |
| Current authored compact pair rules | 56 = 14 oracle + 42 building | [`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp) |
| Specialised interaction metadata entries | 19 | Same |
| Explicit semantic families / membership records | 7 / 33 | Same |
| Authored default/adjustment/context layers actually active | 0 | Same |
| Hard surfaces in current `is_hard_surface` | 101 | [`material_rules.cpp`](../../native/src/material_rules.cpp) |
| Native `state_a` storage accessor | 16 bits; descriptor initial value is `uint8` | [`precision_storage.hpp`](../../native/include/cybersand/precision_storage.hpp) and `material.hpp` |

These are **compiled source claims**, not freshly executed physical or graphical acceptance claims. `RuleKernel::None` is a valid deliberately inert behaviour, not a missing implementation. `MaterialState` describes broad phase; it does **not** by itself define hard collision, powder support, liquid solver applicability, electrical conduction or reaction inheritance.

**Existing ownership that remains in force:**

- [INT-000 #29](https://github.com/techrote/cybersand/issues/29) has landed the sparse interaction/provenance substrate. [#30](https://github.com/techrote/cybersand/issues/30) is its open MicroScenarios programme tracker. This proposal is an authoring/consistency follow-on, not an INT-000 reimplementation.
- [MAT-001 #158](https://github.com/techrote/cybersand/issues/158) owns the accepted persistent compact-pair/Ice wake repair. Do not replace its semantics or treat historical contacts as fresh defects.
- [#160](https://github.com/techrote/cybersand/issues/160) / [PR #162](https://github.com/techrote/cybersand/pull/162) own the candidate Water/Steam/Ice partial-quantity and hot-material cumulative-quench correction. Their **current merge status and source** must be checked at every affected step.
- [#200](https://github.com/techrote/cybersand/issues/200), [#202](https://github.com/techrote/cybersand/issues/202), [#203](https://github.com/techrote/cybersand/issues/203) and [#212](https://github.com/techrote/cybersand/issues/212) own liquid-family, variant, application and publication requirements. [#204](https://github.com/techrote/cybersand/issues/204) owns Cell-carrier experiments; [#12](https://github.com/techrote/cybersand/issues/12) owns soliding/Rapier transitions.
- [#131](https://github.com/techrote/cybersand/issues/131) owns general testbench ergonomics. This programme owns **material-specific inspection and authoring**, while consuming its UI conventions.

## 2. Source findings and fault hypotheses

| Finding | Classification | Source/effect | Required action |
|---|---|---|---|
| Hard-terrain classification uses IDs `38..kLastMaterial` | **Current source risk** | [`MaterialRules::is_hard_surface`](../../native/src/material_rules.cpp) would classify a future appended non-hard ID as hard if `kLastMaterial` advances | Generate an explicit capability map; freeze identical outcomes for current 101 hard members |
| Transport schema v1 addresses only IDs 0–80 | **Current compatibility boundary** | [`TransportPolicy`](../../native/include/cybersand/transport_policy.hpp) returns fixed defaults for later IDs | Preserve v1 byte format, advertise fallback; separately version any extension |
| Semantic `hot-source` omits Spark but runtime `is_hot` includes Spark | **Current metadata/predicate inconsistency** | [`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp) vs [`world.cpp`](../../native/src/world.cpp) | Audit intentional scope; correct metadata or context predicate only with approved tests |
| Lava/Acid/Oil movement ignores generic descriptor viscosity gating | **Current behaviour, recognised in prior characterisation** | Specialised [`world.cpp`](../../native/src/world.cpp) paths vs descriptor `viscosity_index` | Do not expose these as effective editable viscosity sliders; retune only via an admitted policy |
| Same-material pair products reset state; Water products can be initialised full | **Current documented semantics and quantity sources/sinks** | `World` pair writes plus [quantity ledger](../../native/tests/test_quantity_ledger.cpp) | Preserve in legacy policy; add explicit endpoint effect kinds and truthful accounting. Coordinate #160/#162 |
| Isolated MoltenGlass cooling may become stranded across quiet block sleep | **Source-derived hypothesis; fresh native proof missing** | Four-tick thermal lane vs ordinary three-quiet-tick threshold | Controlled actual-World default/high-quiet/active-neighbour reproduction before change |
| Adjacent MoltenGlass resets cooling to 180 | **Current source behaviour; intended law unresolved** | `RuleKernel::MoltenGlass` hot-neighbour condition | Distinct thermal-model/feel decision, not a scheduling fix |
| Yielding-liquid failed mobility draw returns before retry/deadline retention | **Current source condition; retained prior sleep sensitivity** | `flow_as_yielding_liquid`; [issue-15 coverage](../audits/2026-09-11-issue-15-coverage.md) | Reproduce source-matched resting/eligible cases; any changed trajectories require versioned acceptance |
| Pair rules need a scheduled active initiator | **Current execution constraint** | Pre-kernel chemistry is reached through active World cells | Validate generated participants/initiator or document explicit non-running rule |
| Native descriptors, appearance LUT, picker and GDScript fallback are separately maintained | **Current duplication risk** | [material contract](../systems/materials-and-rule-kernels.md) | Generate shared facts; never falsely claim fallback native-rule parity |

A source-review finding is not a runtime pass. In particular, the proposed cooling and stochastic-retry reproducers are **not** evidence that changing those laws will improve game feel, performance or scheduler correctness on the actual native host.

## 3. Orthogonal material classification

**Decision proposed:** no single inheritance hierarchy should control all simulation fields. Use six independent dimensions.

| Dimension | Example | Effects |
|---|---|---|
| Stable identity | `cybersand:wood` ↔ frozen byte 7 | Save/content references and compatibility |
| Browse category and tags | `Organics / Wood`, `construction`, `timber` | Search/picker only; can belong to many filtered collections |
| Physical capabilities | `hard_surface`, `granular_support`, density target exchange | Native collision/transport predicates; explicit flags |
| Behaviour preset and state contract | `legacy.wood.v1`, current `Combustible` kernel | Only tested native mechanism and valid parameter consumers |
| Semantic interaction membership | `int.family.combustible-kernel`, `aqueous-contact` | Rule selectors, not inferred from colour/name/category |
| Appearance programme | RGBA, flair, projection, procedural finish | Godot shader/display only; never physics or per-cell extra paint by implication |

**Proposed browse taxonomy:** Natural media (powders, liquids, vapours, ice), Organics/life (woods/fibres, plants/fungi, agents), Construction (masonry, earth/clay, concrete, roofing), Metals (base, alloys, fabricated, weathered), Glass/ceramic/crystal, Polymers/composites, Reactive/energetic, Devices/special.

Browsing taxonomy is deliberately **not** mechanical inheritance. Wrought Iron and Copper do not automatically gain base-Metal charge; Chemical Glass does not automatically gain base-Glass phase reactions; building woods do not automatically become Fungus/Mite timber substrates. Even two visually identical materials may have different native capabilities.

Overlapping semantic families are allowed. If a future authored family sets an effective parameter that overlaps another, compilation must require a unique explicit override or fail with the conflicting source locations—not rely on array insertion order.

## 4. Canonical source model and compiler

**Proposed authoring tree** (final names/schema require #352 review):

```text
materials/
  schema/material-v1.schema.json
  registry/identities.json
  definitions/{legacy,reactive,construction,building}/*.json
  behaviours/presets.json
  interactions/{families,pairs,specialized}.json
  appearances/{recipes,overrides}.json
  browse/{categories,tags}.json
tools/materials/compile_catalogue.py
tools/materials/test_catalogue.py
```

Prefer simple JSON plus a deterministic Python-stdlib compiler in v1, because the current repo already maintains portable Python CI tools. Using several author-friendly source files is acceptable **only if** they compile to one validated immutable effective catalogue. The canonical source should contain identity, type, constraints, owned parameters, family memberships, aliases and status. Free-form comments in JSON may be replaced with dedicated `description` fields or adjacent documentation.

**Illustrative proposed material record** (not executable today):

```json
{
  "schema_version": 1,
  "key": "cybersand:wood",
  "id": 7,
  "display": {"name": "Wood", "category": "Organics/Wood", "tags": ["timber"]},
  "physical": {"phase": "Solid", "density_rank": 720, "hard_surface": true,
               "granular_support": false},
  "behaviour": {"preset": "legacy.wood.v1"},
  "appearance": {"rgba8": [116, 78, 48, 255], "recipe": "timber.v1"}
}
```

**Generated outputs** should include `material.hpp` descriptors/identity, explicit native capability lookup, compact sparse interaction table/partner sets, stable GDScript IDs and names, picker/browse metadata, RGBA and flair arrays, condition projection and versioned source-derived catalogue manifest. Keep expensive shader algorithms and native kernel implementations hand-coded initially; generate their *metadata*, not a new universal interpreter.

**Hard validator gates:**

- Stable, non-reused byte IDs; slot 10 remains invalid; `Gas` is a label alias for Smoke=4, not another material ID; reserve/unallocated slots fail cleanly.
- Unique keys, names and aliases; valid family references, endpoint/product IDs, kernel enum, radius, state width/meaning, type ranges and support matrix.
- Family overlap, duplicate pair, conflicting ordered/unordered matches, cross-rule precedence, invalid supersession, invalid probability representations, uninitiable pair-only definitions and unsupported optional-state contracts fail with understandable source location.
- Generate a baseline exact-value oracle from the pinned Current source before replacing hand-authored tables. `--check` regenerates without modifying the tree and fails on drift. Generated files are deterministic, diffable and compatible with repository documentation policies.
- Current 132-slot catalogue, all 56 rule identities/indexes/roll cases and 19 specialised mechanisms are identical after the migration. Synthetic new non-hard powder at ID 132 is a compiler-only fixture—not a shipped byte-ID addition—to prove future IDs are not auto-collision-hard.

**Intentionally not implemented in v1:** a runtime DSL, hot-loop schema evaluation, user scripts, dynamic pack ID reassignment, or a per-cell behaviour object.

## 5. Interaction effects and effective parameters

### Endpoint effect language

Today, a selected pair writes both products using their new material's initial state. This includes same-identity outputs; it is not implicit preservation. The proposed authoring effect model must therefore distinguish:

| Proposed effect | Explicit semantics | Default compatibility |
|---|---|---|
| `replace_with_defaults` | Replace material identity/state with descriptor-initialised product; retire incompatible optional solver state | Maps **all existing** pair rules to this effect initially |
| `keep_existing` | Preserve selected participant's identity and allowed state/quantity (with defined epoch/mutation semantics) | **Not** automatically selected for same-material outputs |
| `set_state` | Narrow, validated update to declared state register | Synthetic tests first; never write undeclared register bits |
| Named quantity-aware effect | Explicit product, consumed/produced quantity and permitted carry/overshoot | **Existing #160/#162 owns its source branch and acceptance**, not this programme |
| `disabled` | No rule selected by author intent | Distinct from old threshold 0, which still succeeds on 1 of 256 rolls |

Keep the Current probability rule `roll <= stored_threshold`, so the probability of a single eligible opportunity is `(threshold+1)/256`. Preserve the shared roll and first-selected-contact scheduling/order in the compatibility profile. A new inspector can display `matched`, `roll_failed`, `not_due`, `source_inactive`, `masked`, or `conflict` **only if the relevant layer actually observes that reason**. Resolver-only code cannot claim World-level facts it has not checked.

### Effective parameter contract

`MaterialDefinition.viscosity_index` is a **declared** value; effective motion depends on kernel and any allowed construction-time profiles. Every proposed editable parameter needs:

- stable key; declared and effective values; units and validated limits;
- owning source/preset/override and identity/version of the applied policy;
- **actual consuming kernel/helper** and supported platform/solver;
- status `effective`, `unused_by_selected_kernel`, `unsupported`, `planned` or `source_edit_required`;
- change class: appearance preview, compile/rebuild, or validated restart-time policy;
- revalidation tags, state/quantity impact and save/physical-hash implications.

In v1, **do not** present Lava/Acid/Oil descriptor viscosity as an effective freely editable native slider while their specialised paths bypass that value. An inspector can truthfully display the descriptor and an applicability warning. Similarly, do not infer real-world density units from `density`: it is a gameplay comparison value.

## 6. Scheduling and liveness qualification

The existing World kernel has one authoritative tick/owner and spatially staggered deterministic lanes. The desired extension is an explicit result such as:

```text
KernelOutcome {
    state_changed;
    retained_next_eligible_tick?;
    waiting_reason; // cadence, stochastic_retry, intrinsic_countdown, blocked, ...
    mechanism_id;
}
```

This describes a **proposed scheduling interface**, not a new return type already implemented. Bounded deadline retention must use the existing activity-block mechanism; no new per-cell queue, extra per-cell allocations or fake dirty writes. A quiet/ineligible block may sleep.

Before implementation, run retained real-`World` fixtures at default quiet=3 and deliberately extended quiet=1024 (plus an always-active neighbour control), across all relevant temporal phases, positions/translations, 1/4 actual worker execution, source/target changed/unchanged, body masks, region pause/re-entry, reset and core/chunk edges.

Distinguish:
1. **Missing due opportunity** (potential scheduler correction);
2. **Stochastic mobility discarded by sleeping** (may be intentional legacy resting approximation);
3. **MoltenGlass mutually maintaining temperature** (distinct proposed thermal law decision);
4. **Valid blocked/rest state** (should not cause endless reevaluation).

A fix to category (1) should not silently implement new rules for (2) or (3). Any changed trajectory, rate or pool lifetime requires versioned optional experiments, independent source-matched evidence and owner gameplay acceptance before changing defaults. Keep all MAT-001, Water and unrelated liquid controls as negative tests.

## 7. Identity, compatibility and resource budgets

**Hard invariants:** existing byte IDs, reserved 10, material products, default C64/E8 Cell/storage contract, `state_a/state_b` meaning, full-physical state hash/version, current save/level formats, generic World ownership, native/Godot worker separation, source-matched runtime publication, LCB policy compatibility and non-kinetic interaction ownership.

Avoid conflating four independent identities:

- **Material registry identity:** stable authored content keys and numeric ID table.
- **Compiled catalogue/effective policy identity:** exact schema, resolved parameters, families, interactions, generator version.
- **Source/runtime/artifact identity:** commit, build/dependencies, native library bytes and platform.
- **World state identity:** actual active material cells, state, auxiliary solver state, schedule, mutable quantities.

The current transport schema v1 has 81 material entries and six pair settings for every old 81×81 slot; extension must be schema-versioned rather than silently changing that profile's serialized shape. Later material defaults need explicit acknowledgement in the inspector.

The initial generator is **build-time**. A later approved immutable per-World tuning overlay can be admitted at a validate → reconstruct same setup → atomic owner swap boundary; a malformed policy leaves the previous World untouched. Never mutate the global compiled descriptor table during worker execution. Current GDScript fallback uses only a subset of native behaviours: generated IDs do not establish native-fallback chemistry parity.

No unmeasured compile-time or runtime performance claims. Benchmark generated lookup and table size against Current; maintain bounded hot-path cost.

## 8. Materials Lab authoring workflow

The initial browser/inspector belongs in the current Materials Laboratory and coordinates with the existing TEST-UX owner, not a new gameplay host or general editor framework.

| User action | Required v1 experience |
|---|---|
| Find material | Category and multi-tag filter; search ID/key/name/phase/kernel/capabilities/partners |
| Inspect exact physics | Declared vs effective density, movement, flow, hard/granular flags, state, radius and selected kernel |
| Inspect interactions | Stable matched rule, orientation, threshold and exact chance, endpoint effect, actually observed failure reasons and owning execution stage |
| Inspect appearance | Base RGBA, variation, shader flair/recipe, visual state source, emission and fallback status |
| Tweak a parameter | Apply only if an actual owner accepts it; otherwise warn compile/rebuild required; no fake live sliders |
| Add a material | Copy a supported preset → new stable ID/key → explicit capabilities/appearance → optional rules → validate/generate → rebuilt preview |
| Reject candidate | Clear field/path/reason; previous World/profile and canonical source remain unchanged |
| Export/import | Deterministic, versioned profile/manifest with source/runtime/solver identity and compatibility decision |

No dynamic runtime material creation is implied: v1 can add source-level materials using generated tables. A safe editor can later be an authoring front end for those manifests; broad runtime GUID registries and hot reload remain **Deferred**.

## 9. Issue dependency and acceptance plan

```text
#352 MAT-AUTH-000  architecture, frozen baseline and owner dispositions
       |
       v
#353 MAT-AUTH-001  canonical schema, generated explicit capabilities,
       |           mirror parity and backward compatibility
       |
       +-----> #354 MAT-AUTH-002  isolate/repair scheduler-liveness,
       |                         with physical-law changes separately gated
       |
       +-----> #355 MAT-AUTH-003  endpoint effects + resolver diagnosis
       |                         (coordinate world.cpp writer with #354)
       |                          |
       +--------------------------+
                                  v
                       #356 MAT-AUTH-004  catalogue search, effective
                                          inspector and safe authored workflow
```

### Per-stage acceptance

| Issue | Bounded result | Required proof |
|---|---|---|
| [#352](https://github.com/techrote/cybersand/issues/352) | Proposed design and source-linked compatibility contract | Real source/owner inventory, frozen baseline, decision points and documented non-goals; **no production implementation** |
| [#353](https://github.com/techrote/cybersand/issues/353) | Canonical authored catalogue and exact source mirror generator | All IDs/descriptors, 56 pairs, 19 mechanisms, 7 families / 33 memberships and visual data match. 256×256 pair checks; deterministic generation; fake ID132 negative case |
| [#354](https://github.com/techrote/cybersand/issues/354) | Controlled liveness corrections or documented no-go disposition | Default/awake/active-neighbour native reproductions, narrow scheduler wake proof, workload/worker parity; optional gameplay profiles gated |
| [#355](https://github.com/techrote/cybersand/issues/355) | Explicit endpoint effects and truthful eligibility inspection | Legacy 56-pair results unchanged, orientation/roll boundaries/ledger equivalence, synthetic new-effect validation, Acid priority checks |
| [#356](https://github.com/techrote/cybersand/issues/356) | Practical source-authoring and effective material inspector | Search, applicability warnings, safe restart/refusal, synthetic new-material workflow, actual desktop test and scope-appropriate Web checks |

**Gates:** Each implementation writer checks current `main`, previous accepted exact-head tests, active PRs and actual World/Godot ownership. No merged candidate from a stale source-only summary. Before ready/merge, run affected Documentation/provenance, Native + sanitizers, actual GDExtension/Godot and focused Water/LCB suites; publish source-matched runtimes where changed native behaviour requires them. Retain actual failures and identify unexecuted Windows graphical, Web/browser or manual feel acceptance. Draft PRs are appropriate during iteration; no automatic merges.

**Write-set contention:** #354 and #355 may share `native/src/world.cpp`; their research can proceed in parallel but source writes, reconciliation and final merge should be serialized. #356 should consume accepted inspection APIs rather than invent a second World observer.

**Rollback:** Source-generated catalogue #353 must be independently revertible without losing old IDs, data or fixtures. Changed physics in #354/#355 is a separately versioned policy/disposition, not entangled with mechanical generated-table parity. If validation proves unresolved source/ABI/behaviour differences, leave implementation draft and report a blocker; do not relax oracle comparisons.

## 10. Decisions held for explicit disposition

- Is the registered `hot-source` family deliberately narrower than `is_hot` with respect to Spark, or a documentation/membership bug? Confirm use cases before changing semantics.
- Should MoltenGlass neighbours count as perpetually hot? If not, register a specific cooling model, explicit target and before/after fixture with no claim of global heat conservation.
- Should the existing quiet-dependent whole-cell viscous-liquid rest remain a desired gameplay yield approximation? Distinguish stochastic retry scheduling from an intentionally bounded rest/yield law.
- When should a same-ID product preserve state? **Current default is full replacement**. Every exception needs an endpoint-effect contract and separate quantity/source-sink ledger; #160/#162 remains a separate owner.
- Which parameters can actually be changed without compiling a new native module? Mark all others source-edit-required; never silently report that a slider worked.
- Can authoring fully rely on `constexpr` built output until demand justifies runtime user packs? **Proposed yes**; runtime GUID migration is not admitted here.
- Does any new material require widening beyond a byte? The current registry does not: IDs 132–255 are still unallocated, subject to further reservations. Any future widening belongs to an explicit storage/save/adapters decision, not this chain.

**This page is the planning contract, not the Current runtime catalogue.** Exact ongoing material numbers and behaviour remain owned by [materials-and-rule-kernels](../systems/materials-and-rule-kernels.md), [intermaterial-interactions](../systems/intermaterial-interactions.md), and their source files. Do not add a second competing Current source of truth.

## 11. Current-main review and implementation admission — 2026-11-03

**Historical review and adoption-only update.** The assignment holds below
belong to those dated decisions. [Section 13](#13-bounded-compatibility-tooling-and-adopted-main-reconciliation--2026-11-04)
records the subsequently implemented #353-A candidate and its separately
authorized integration; production cutover remains held. Technical requirements
and original evidence below are preserved.

**Dated status correction, 2026-11-04:** the owner has adopted the corrected
design as Planned and authorized documentation integration. The 3 November
review text below is preserved; its adoption hold is superseded by
[section 12](#12-owner-adoption-and-shadow-compiler-handover--2026-11-04).
#353-A implementation and production consumer replacement remain unstarted and
require separate assignment and their own qualification.

**Planned correction; owner decision pending.** Review of accepted main
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15` confirms the original material counts
and supports the six orthogonal classifications. It also establishes compatibility
hazards that the first proposal did not specify sufficiently. This section
governs the *recommended* next implementation scope; it does not itself grant it.
The [dated review](../audits/2026-11-03-mat-auth-000-architecture-review.md)
records source identities, consumer inventory, evidence and independent review.

### Accepted direction and explicit field ownership

Retain stable IDs, presentation-only categories/tags, explicit physical
capabilities, named native behaviour/state contracts, explicit semantic family
memberships and independent appearance programmes. Construction, metal, wood,
glass or liquid labels never imply conduction, hardness, combustion, biological
substrate, quantity semantics or solver eligibility. Membership can overlap;
membership itself supplies **no physical parameter defaults in the first slice**.

An effective field has a qualified owner: native descriptor, selected solver
policy, transport pair policy, fallback-specific implementation or presentation.
Record its actual consumer, units, integer/encoding limits, applicability,
origin, change boundary and state effects. Material density is a comparison rank;
native `uint16_t` storage does not turn it into calibrated physical density.
World Water-CY viscosity, Mercury's diagnostic override and IN's radius-3
admission cannot be inferred from the base descriptor alone.

### Conflicting material families and behaviour presets

For future preset defaults, use one versioned behaviour preset plus explicit
material overrides with declared ownership. Reject overlapping owners unless
the schema names a unique authorized override. No mixin traversal, file order,
array order or display category resolves a conflict. Semantic interaction layers
retain the existing fixed precedence and conflict validation; #353 authors no
new active layers. Transport keeps its own directed-source, grain-target and
liquid-owned parameter rules and refusal checks. A universal per-material
effective-value merge must not replace those distinct resolvers.

Validate finite selector intersections as well as duplicate selector text:
overlapping families, orientations or contexts with unresolved equal-precedence
assignments fail with both origins. Overlapping membership alone remains valid.

### Identity compatibility is stronger than descriptor equality

**Current:** [`catalogue_digest`](../../tools/lcb/policy_contract.py) hashes
LF-normalized paths and complete bytes of `material.hpp` and
`interaction_rules.hpp`. [`derive_capability_matrix.py`](../../tools/lcb/derive_capability_matrix.py)
also parses their literal enum/table shapes. Formatting, generated banners,
includes or row reordering can change admitted policy/receipt identities or
break derivation while preserving C++ values. CYPS restoration re-admits its
stored policy against the running catalogue; a mismatch is an actual refusal
boundary. Preserve these guards and the existing generation order in the
[policy contract](liquid-solver-family-policy.md#regenerating-identity-after-a-material-or-rule-edit).

Preserve both pair and specialized-record indices. The
[`quantity ledger`](../../native/include/cybersand/quantity_ledger.hpp) has
schema 1, 56 pair slots and 19 kernel slots; `quantity_kernel_rule` selects the
first matching specialized-record slot and the codec serializes arrays in that
order. Stable names alone do not preserve positional accounting. Explicit
`legacy_slot` values may preserve that order without making input-file order a
hidden semantic rule.

**Required:** freeze each consumer's existing output independently. Native Slush
density is 1080; the GDScript fallback uses 1100. This is a source-level difference,
not a newly reproduced physics defect. Preserve it as an explicit backend
override or leave that fallback consumer hand-maintained. Shared IDs/names and
the verified common RGBA tuples may share authorship; shared metadata is not
fallback movement/chemistry parity. Never silently normalize either backend.

### Minimum #353 slice: compile metadata alongside unchanged runtime authority

**Proposed #353-A admission** is a small JSON/Python-stdlib compiler and independent
frozen source oracle. It does not need the entire illustrative directory tree.
Start with an identity registry, material records, explicit capability/family
records and one consumer/provenance manifest; split files only for reviewability.
Represent all 15 descriptor fields, alias identity, existing capability results,
ordered pair/specialized records, backend exceptions and supported appearance
facts. The short Wood example in section 4 is illustrative, not a complete
lossless record or a schema acceptance fixture.

Generate a deterministic inspection manifest and shadow C++/GDScript metadata
in a separate candidate output directory. Compare them against independent
source-derived facts and existing consumers. Production includes, kernels,
fallback functions, policies, receipts, saves, shader algorithms and current
generated artifacts remain untouched in this first checkpoint. Canonical
authorship is *proposed/shadow* until a consumer switches; do not create two
simultaneously authoritative catalogues.

**Conditional #353-B cutover:** migrate one constant consumer at a time only after
exact parity and file ownership are reviewed. Digest-bound headers must retain
their complete LF bytes and the current parser-compatible literal form. If that
is impractical, stop at A and request a separately specified identity transition;
do not regenerate away stale-policy refusals or relax comparisons. #353 remains
open until its full accepted scope is delivered or the owner explicitly accepts
the narrower checkpoint. A shadow demonstrator does not silently complete the
original broad generator issue.

The generator contract must include:

- Explicit source schema, generator and output-manifest versions; immutable
  numeric IDs and namespaced keys; stable aliases such as `Gas` → `Smoke` at ID4.
  Display labels are non-authoritative. Alias/key collisions are errors; a label
  collision must be disambiguated by key, never resolve material identity.
- Unknown-field, duplicate-object-key, invalid-reference, alias-cycle and
  out-of-range rejection. Integer fields reject booleans and lossy numeric
  coercion. Existing byte values, enum numbers, `uint16_t` density and state
  register widths remain exact; future non-integer fields need their own
  canonical encoding contract before admission.
- Errors identify file plus JSON pointer and both origins of a conflict;
  syntax errors additionally include parser line/column. Unsupported schema
  versions, non-finite numbers and invalid optional-state contracts fail before
  any output swap. Keep existing Godot appearance expressions/float calculations
  unchanged until their literal/precision contract and parity are reviewed.
- Stable ordering by identity and explicit legacy slot, deterministic escaping,
  UTF-8/LF bytes and final newline; no timestamps, absolute paths, locale or
  directory-enumeration order in generated content. Two clean output roots and
  permuted authoring-file discovery must produce byte-identical outputs.
- Complete validation before replacing output files, no partial publication on
  failure, and `--check` that does not write. Retain last accepted outputs,
  source/schema/compiler identities and actionable drift diagnostics. Do not
  rewrite unchanged output files and thereby force unnecessary rebuilds.
- Compile-time fixed arrays/bitsets and initialization-time policy validation;
  no tick-time JSON, strings, family search, maps, allocation, per-cell objects
  or added state. Keep the existing partner-bitset fast rejection and bounded
  sparse resolver. Treat host-side authoring source maps separately from native
  hot-path metadata. No performance benefit is claimed without measurement.

IDs 0–131 and invalid10 stay unchanged. Draft #358 has experimental claims on
132–137; these are **not production Current reservations or accepted materials**.
Record those branch-qualified claims so a source author does not reuse them
accidentally. The ID132 non-hard-powder test in the original issues is valid only
inside an explicitly isolated synthetic registry, with no generated production
output, save, receipt or experiment export. It must not overwrite #358's
experimental StoneWall132 identity. New production ID allocation still requires
an explicit integration decision.

### Legacy endpoints and scheduling must remain executable contracts

For #355, section 5's `replace_with_defaults` is only shorthand for the actual
legacy World path, **not** a generic reset of every field. Freeze:

- Four-tick contact cadence, neighbour/random-stream order, one shared roll,
  `roll <= threshold` and target-then-source writes; threshold0 means 1/256,
  while a disabled rule is a distinct future declaration.
- Water product quantity from the active World policy maximum, other products'
  descriptor-initialized state and the existing pressure/IN state retirement.
  Same-ID products do not automatically preserve quantity or solver state.
- Existing optional temperature retention, body-mask/refusal behavior, no-op
  epoch/dirty semantics and gross produced/consumed plus pair-event accounting.
  A selected event can be recorded even when the write returns unchanged.
- Existing specialized thermal, Acid, ignition, electrical and lifecycle paths
  remain hand-coded; their catalogue records describe them without replacing
  execution. #160/#162 retain ownership of their unmerged quantity correction.

New `keep_existing`, `set_state` or quantity-aware effects require explicit field,
sidecar, temperature, event, mutation and quantity-ledger contracts plus separate
owner admission before use in production. Their design or synthetic tests do
not authorize applying them to legacy same-material products.

For #354, static metadata describes a kernel's obligations, not whether a cell
is due, masked, active or waiting now. Preserve inert `RuleKernel::None` reaction
targets: 26 of the 41 pair participants use that kernel and can be acted on by an
active partner. A compiler must not reject or activate them merely for being
inert. Reproduce MoltenGlass quiet-block cooling and yielding-liquid failed-roll
retry hypotheses against fixed source before proposing any scheduler repair.
Mutual MoltenGlass heating and desired viscous rest are separate gameplay-law
decisions. Section 6's `KernelOutcome` is illustrative; first prefer the smallest
repair using existing coalesced activity wakes. No blanket always-awake policy.

### Materials Lab effective inspection and editing

**Planned #356:** catalogue descriptors alone cannot supply effective viscosity
controls or runtime reaction status. Reuse the material-info v1–v4 native C API,
the native bridge's interaction catalogue/inspection, and the applied liquid
policy readback. Report the selected backend and solver beside each value.
Lava, Acid and Oil bypass descriptor viscosity in specialized movement, so that
declared field is read-only or explicitly unused there. Water-CY consumes its
versioned material-block viscosity; generic yielding liquids use descriptor
viscosity except for Mercury's diagnostic override. A descriptor-only radius
display must also distinguish IN's applied radius-3 geometry.

An interaction resolver sees matches and rolls, not the live World's sleep,
mask or due-opportunity state. Existing specialized inspection explicitly marks
records `evaluated=false`. Show unsupported/unobserved status rather than
inventing reasons. A future World observation must be produced by its real owner
and preserve the bounded copied-observation contract.

Source-edit-required fields can be exported as validated authoring changes for
rebuild; existing construction-policy fields can be edited only through their
actual validated restart/preparation API. A slider is enabled only when a
consumer, owner and applied readback exist. Failed validation or reconstruction
preserves the old source/profile/World, and a successful preview does not claim
that a production policy was changed. Read-only inspection can precede new
reaction semantics; editing cannot bypass #355 or relevant #354 dispositions.

### Successor gates and owner decisions

**Historical adoption-only assignment boundary, 2026-11-04:** architecture adoption is recorded
in [section 12](#12-owner-adoption-and-shadow-compiler-handover--2026-11-04), but
no implementation stage below has been assigned by that decision. The retained
3 November table and final recommendation describe their technical gates.

| Stage | Admission and required proof | Stop/rollback boundary |
|---|---|---|
| #353-A | Owner adopts this narrowed scope; freeze source and per-consumer oracle, validate all IDs/descriptors/families/indices/capabilities, synthetic conflicts and deterministic outputs; preserve current LCB derivation/wire/receipt checks | Shadow outputs only; a mismatch is evidence, not a reason to update the oracle |
| #353-B | Separate cutover review; exact consumer bytes/values, both orientations and all 256 rolls over the byte-ID pair domain, capability/invalid-ID checks, backend-qualified mirrors, source-matched native/adapter gates when runtime inputs change | Revert one consumer and its generated route as a unit; identity transition held if old envelopes would be refused |
| #354 | Admitted reproducible liveness case, quiet3/1024 and active-neighbour controls, phase/translation/boundary/mask/region/restart coverage and actual one/four-worker comparison | Preserve historical failures; no-go/defer is valid; gameplay-law change requires separate approval |
| #355 | Legacy endpoint/ledger/state/no-op/precedence parity; Acid priority controls; explicit conflict diagnostics; new effects isolated and separately admitted | Serialize shared World/quantity edits after #354 or its explicit disposition; no implicit same-ID preservation |
| #356 | Read-only browser/inspector can follow accepted #353 metadata; effect editing waits for #355 and any relevant #354 disposition; show actual backend/solver/parameter consumer and compile/restart boundary | Failed import/apply retains old source/profile/World; resolver-only inspection never invents live sleep/mask/eligibility reasons |

Assign one integration writer for `world.cpp`, `world_quantity.inc`, material
headers and their generated identities; #354/#355 writes must serialize when
they overlap. Coordinate affected files with #358, SOL-DETACH #347, generic GCR
#83/#343 and LCB-FEEL #370. Inspector work reuses #131 and existing native
material/interaction APIs. A read-only inspector need not wait for an unrelated
liveness repair, and it must not advertise editing support before a real consumer
exists. Revalidate all active branch heads before implementation.

**Decisions for the owner:** adopt the corrected architecture and explicitly
admit only #353-A; choose whether a later byte-identical cutover is sufficient or
authorize a separately reviewed identity migration; disposition the Spark family
scope, same-ID/quantity exceptions, MoltenGlass thermal law and viscous retry/rest
law only if their bounded successors present evidence. Preserve current behavior
and backend differences until each such decision. This review grants none of
those semantic changes and does not merge #357.

## 12. Owner adoption and shadow-compiler handover — 2026-11-04

**Historical documentation-adoption decision, preserved.** #357 subsequently
merged with its [final and post-merge checks](https://github.com/techrote/cybersand/pull/357#issuecomment-6619591556).
The implementation-assignment statements below describe that documentation task;
they do not describe the separately implemented #371 candidate. [Section 13](#13-bounded-compatibility-tooling-and-adopted-main-reconciliation--2026-11-04)
records its current A-only scope and guarded integration.

**Approved direction, retained Planned status.** The owner explicitly authorized
adopting this corrected architecture and merging only the documentation after
final checks. The [recorded decision](https://github.com/techrote/cybersand/pull/357#issuecomment-6619407158)
supersedes the earlier adoption hold. It does not assign #353-A or any later
implementation. Current native and GDScript definitions remain authoritative;
no material behavior, default, Cell layout, transport, quantity, save, policy,
receipt identity or runtime binary changes follow from accepting the plan.

The [#353-A handover](https://github.com/techrote/cybersand/issues/353#issuecomment-6619162661)
defines the next separately assigned task: strict versioned JSON, a Python-stdlib
compiler, deterministic shadow outputs/source maps, an independent pre-generator
source/backend oracle, strict and adversarial validation, read-only `--check`,
unchanged-output preservation and no partial publication after validation failure.
The architecture-adoption prerequisite is now satisfied; the implementation
assignment remains outstanding. Broad #353 and parent #352 remain open.

The first implementation compares all existing identities/descriptors, all 256
byte-ID predicate outcomes, semantic families, ordered compact/specialized rules,
relevant ordering/threshold/orientation/no-op semantics, original source bytes and
known-answer tests. It must preserve backend differences and complete material/
interaction header-byte identities. Semantic equality does not establish source-byte
compatibility. Production consumer cutover requires its own exact-byte review or
an explicitly authorized identity transition, with rollback and appropriate gates.

At adoption intake, accepted main was `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`
and the reviewed proposal was `9b776d109e7843fb9b2d25239f9d088181309aa1`.
The [integration ledger](https://github.com/techrote/cybersand/pull/357)
owns final-head, merge and post-merge documentation results. The earlier
[readiness checkpoint](https://github.com/techrote/cybersand/pull/357#issuecomment-6619191972)
preserves its actual tested tree, draft-state provenance skip and retrieval limits;
its green runs are not claims about a later edited head. Ready-state and post-merge
Documentation checks must validate materialized runtime identity; this does not
require Native/GDExtension/gameplay execution for a documentation-only change.

Before implementing A, independently recapture newly accepted main and active
file ownership. PR #358's IDs132–137 remain experimental at this decision; if
that work lands first, baseline the accepted result instead of importing its
unmerged candidate. Keep #353 → (#354 and #355, serializing overlapping writes)
→ #356. Identity transition, production ID allocation, Spark membership, endpoint/
quantity exceptions, MoltenGlass thermal law, viscous retry/rest and runtime
editing remain separate decisions. This adoption grants no new material physics
or automatic inheritance.

## 13. Bounded compatibility tooling and adopted-main reconciliation — 2026-11-04

**Historical integration assignment.** #371 subsequently merged at `7ef4856e`.
The following qualification and unstarted-successor statements retain their
original scope; section 14 records the separate Main-label candidate and section
15 retains the accepted #354 investigation boundary.

**Current shadow implementation; guarded integration under qualification.**
The owner separately requested implementation of the review corrections and
compatibility mitigations. [PR #371](https://github.com/techrote/cybersand/pull/371)
already implements **#353-A**: strict versioned JSON, a deterministic stdlib
compiler, unconsumed C++/GDScript metadata, explicit capability maps, an independent
compiled native oracle and immutable-source compatibility guards. The
[shadow compiler guide](../operations/material-catalogue-shadow.md) owns usage.
This supersedes the earlier unstarted-assignment statements for A only; the
documentation adoption itself did not implement or authorize production changes.

Reconciliation preserves original implementation
`6d3737594beb39e83e555f66f2e81184a4bdbf77` in ancestry and merges accepted
main `3da7e7be4a6af4c85e03a7d8a0ed57229e5db33d` without rewriting either
history. The original implementation parent
`9b776d109e7843fb9b2d25239f9d088181309aa1` and frozen legacy compatibility
baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` remain distinct identities.
The 27-source compatibility lock is not refreshed to accept a changed owner;
any authenticated-source drift requires a separately reviewed transition.

The owner authorizes a guarded #371 merge only after the reconciled tree targets
accepted main, passes its resulting-head checks and independent review, contains
only A's authorized delta and has no unresolved correctness or ownership blocker.
Until then it remains draft and unmerged. Its PR ledger records exact source,
tree, hosted jobs, artifacts, reviewer disposition and any eventual merge and
post-merge evidence. Original [implementation qualification](../audits/2026-11-04-mat-auth-353a-compatibility.md)
and the historical Documentation run41749294625 do not qualify an edited head.

Production material/kernel/fallback/state/transport/save inputs and existing
generated policy artifacts remain authoritative and unchanged. Native Slush1080
and fallback1100 retain their backend-specific meanings. Synthetic powder132 is
an isolated compiler fixture; #358's experimental132–137 are not integrated or
allocated by this checkpoint. No current production code consumes shadow output.

Broad #353 and parent #352 remain open. #353-B needs a separate, minimal consumer
migration admission review, beginning with a consumer whose switch can preserve
runtime semantics and identity-bearing source. #354 still needs source-qualified
liveness reproduction; #355 separately owns endpoint/state/quantity effects;
#356 requires accepted metadata and actual consumers before enabling editing.
Serialize shared World and quantity writes, and preserve active #358/#347/#370
and other owners. A-only integration grants no material rebalance, new physical
law, production ID, runtime pack, hot reload or later implementation stage.

## 14. Bounded Main display-name consumer and proof transition — 2026-11-04

**Current candidate implementation, separately authorized by the owner.** This
assignment admits exactly one production consumer:
`godot/scripts/main.gd::material_name(material_id: int) -> String`. The
[canonical tool guide](../operations/material-catalogue-shadow.md#bounded-main-display-name-authority--2026-11-04)
owns implementation details and commands; the
[dated B evidence](../audits/2026-11-04-mat-auth353b-display-names.md) owns the
original source, runtime and artifact qualification. The later
[#374 reconciliation record](../audits/2026-11-04-mat-auth384-current-main-reconciliation.md)
keeps its evidence historical. The [post-#377 record](../audits/2026-11-04-mat-auth384-post377-reconciliation.md)
records the later accepted-main admission and fresh proof. The deliverable stays a draft PR for
independent admission review, before Ready, with no merge, issue closure or
import of other active branches.

The labels-only generator validates the entire unchanged canonical catalogue
and a small independent presentation schema. It preserves all existing display
returns, including five exact overrides, ID0's `empty` and the unknown-ID
format for reserved10 and signed/large integers. A preloaded static table with
bounded indexing replaces the old Main table; all public callers remain on the
same method. Picker membership/order, semantic-family grouping, cycling,
secondary material behavior, Worldgen, transport v1, shaders and saves have no
cutover. The original compiler, catalogue, four full-shadow artifacts and native
production owners stay unchanged. The accepted #374 benchmark and #377
liveness probe remain research apparatus through the source-admission transition
below; #377 adds no production behavior or material authority.

This admission also authorizes current schema-v2 compatibility/native/shadow
receipts that separately identify unchanged native runtime authority, complete
unconsumed native-shadow parity and migrated UI-label authority. A distinct
mandatory B consumer report must qualify actual application behavior. Native
metadata compilation and Godot shadow parsing cannot satisfy that report.
Historical schema-v1 receipts/readers remain authenticatable through their dated
paths and retained source; a v1 result is not current B acceptance.

The original 27-owner lock remains authenticated against
`0fd4af5987e77db4da3e37c757cf2c0917ae9e15`, with unchanged catalogue/capability
digests and stale-policy refusal. The old display-output oracle independently
remains at `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree
`36ce5a01e754a141c321f41cac7f1c6b6059c371`.

**Historical #374 reconciliation:** accepted main advanced to
`01f9b7c8e382ca6bdbaf0bf70c7847adc12fe0bc`, tree
`4cf99921dc2b33233c3a254f4b6f27ed7cb0f204`, after the original `bbed081b`
independent review. Its added `native/bench/lcb201_pressure_idle_cost.cpp`
correctly fails the original B path-set guard, although the protected owners,
material domain and old Main/CellWorld source remain unchanged. That separate
B admission authenticated accepted native/Godot executable and routing
sources against `01f9b7c8`. The benchmark's accepted bytes are included in that
inventory; there is no benchmark exemption or permission for unknown files.
The [three-baseline contract](../operations/material-catalogue-shadow.md#current-main-b-admission-after-374--2026-11-04)
keeps this change separate from the historical display oracle and immutable A
lock. The allowed consumer delta remains only the Main preload/method,
generated labels resource and apparatus dependency entry.

**Current post-#377 reconciliation:** accepted main is
`0103de80d11304388868f89f7b26c672ad6100ad`, tree
`0ba07dc799afca43716bbab966f48266fa924718`. Its single new executable-inventory
entry is `native/tests/material_liveness_probe.cpp`; the existing 16-suffix
policy excludes the new JSON fixture as test data. Accepted inventory grows
660→661 and the reconciled candidate has 662 entries, including generated labels.
The probe's accepted Git bytes must be authenticated, with no test-file or
filename exemption. Main, the generated labels and the one apparatus source-list
entry remain the only approved production consumer deviations. The
[current three-baseline contract](../operations/material-catalogue-shadow.md#current-main-b-admission-after-377--2026-11-04)
keeps `0103de80` admission separate from frozen `0fd4af59` compatibility and
historical `7ef4856e` display output. The earlier `c6d1603f` / `01f9b7c8`
independent GO remains historical and does not approve this new head.

Extra, renamed and indirect consumers remain refused. Later integrations
touching the B inventory, including another Main writer such as #370, require
a reviewed transition and new source-qualified evidence; they do not authorize
refreshing either frozen authority. The reconciled candidate requires fresh
actual four-stage B proof and separate native/shadow receipts. It stops before
Ready for a strictly read-only **GO TO READY / CONDITIONAL / NO-GO** admission
review. Ready-state runtime/provenance gates, Web export/package loading,
startup/lookup measurements and final independent integration review remain
pending; the original `bbed081b` audit does not approve the new head.

The independent legacy-name fixture comes from actual accepted Main/CellWorld
Git source before the consumer changes. It covers every byte-domain ID and
signed 64-bit edge cases, with actual old/candidate Main and inherited Web
controller checks, UI/export surfaces, poisoned-label routing, drift/missing
output, source-fingerprint and rollback controls. Running the inherited Web
controller in desktop Godot is not browser/Wasm execution.

Adding the generated resource to `microscenario_identity.gd::SOURCES` deliberately
changes current apparatus source hashes. Previous captures retain their original
source sets and mixed-source refusal remains in force. Binary identities are
measured from actual artifacts; source equality alone is not binary equality.
The accepted #374 benchmark and #377 probe belong to the complete B inventory,
not the narrower MicroScenario `SOURCES` list; their admission does not change
that apparatus list.
Rollback restores the consumer, generated dependency and matching proof boundary
together, without save or World conversion.

The domain remains 132 slots with invalid10; native Slush density 1080 and fallback density 1100
remain separate. #358's unmerged experimental 132–137 are not accepted here.
If accepted main expands the material domain, stop for a new scope decision.
Broad #353/#352 remain open; other consumers, liveness/endpoint semantics and
#356 editing require their separate assignments.

<a id="14-material-liveness-phase-a-and-production-admission--2026-11-04"></a>

## 15. Material liveness Phase A and production admission — 2026-11-04

**Accepted Phase A integration — 4 November 2026, 18:14:18 UTC.**
[#377](https://github.com/techrote/cybersand/pull/377) merged as
`0103de80d11304388868f89f7b26c672ad6100ad`, with accepted tree
`0ba07dc799afca43716bbab966f48266fa924718`. The integration preserves tests,
tooling, CI, documentation and original evidence only. H1 remains unrepaired;
#354 and #352 remain open. Neither this acceptance nor the separate draft
Main-label candidate in section 14 authorizes a production liveness correction.
The #377 ledger owns its exact-head qualification and independent final review.

**Historical Phase A admission, preserved below.** Its earlier draft/unmerged
hold was superseded by the separate guarded integration and completed merge.
The technical boundaries, findings and source-qualified failures still apply;
its old hold is not the current status of #377. The old section-14 anchor remains
available for links in the untouched accepted investigation documents.

**Current foundation; bounded investigation only.** Accepted main
`7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` includes merged #371. The shadow
compiler remains unconsumed by production; legacy native/fallback definitions
and the 27-source compatibility lock remain authoritative and unchanged.
The owner separately admits #354 Phase A tests, tooling, evidence and a draft
PR. No production scheduler, thermal-law or generic retry change is admitted.

| Mechanism | Phase A disposition | Next boundary |
|---|---|---|
| H1 isolated MoltenGlass cooling | Actual World controls demonstrate loss of a valid cooling opportunity after sleep | Recommend a narrowly scoped existing-block-deadline correction; implementation authorization pending |
| H2 touching MoltenGlass retention | Executed neighboring heat resets the countdown to 180 under the current law | Preserve Current; any different pool lifetime needs an owner-admitted thermal experiment |
| H3 generic CellularYield retry suppression | Current-source reproduction preserves the documented legacy resting approximation | Preserve Current; different trajectories need a separately versioned policy, not an assumed perpetual retry |

The [investigation guide](../operations/material-liveness-investigation.md) owns
reproduction; the [findings](../audits/2026-11-04-mat354-findings.md) retain exact
source/executable identities, independent review, failed attempts and platform
limits. The [correction memo](../audits/2026-11-04-mat354-correction-admission.md)
targets the earliest eligible existing block deadline, with hot-at-180 and inert rest,
shared obligations, masks, region pause, worker ownership and bounded work
preserved. It does not introduce the illustrative section 6 `KernelOutcome` API.

A future edit to protected `native/src/world.cpp` requires explicit owner
authorization, a separately reviewed compatibility transition and appropriate
runtime rebuild/publication/provenance. Updating expected hashes cannot replace
that review. Keep #354 open and its Phase A PR draft/unmerged. #353-B migration,
#355 reaction effects and #358/#347/#370/#373/#201 and Water phase/quantity work
retain separate ownership; serialize any later shared production writes.
