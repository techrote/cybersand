---
title: Canonical material catalogue and interaction authoring — proposed programme
document-kind: design
canonical-for: [material-authoring-v1-programme-proposal]
status: Planned
scope: Proposed source-of-truth registry, explicit material capabilities, sparse interaction authoring, kernel liveness proof, safe effective-parameter inspection and finite implementation chain
last-reviewed: 2026-11-02
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, ../systems/building-material-catalogue.md, ../systems/themed-construction-materials.md, ../systems/granular-interaction-policy.md, ../systems/flow-transport-and-profiles.md, item-authored-material-programs.md, liquid-state-transition-matrix.md, ../operations/documentation-maintenance.md]
---

# Canonical material catalogue and interaction authoring — proposed programme

**Status: Planned, not implemented or gameplay-qualified.** The owner requested a documented short implementation chain on 2026-11-02. This document captures the proposed architectural disposition; it does **not** activate a new material inheritance system, reinterpret historical evidence, or authorise default material rebalancing.

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
