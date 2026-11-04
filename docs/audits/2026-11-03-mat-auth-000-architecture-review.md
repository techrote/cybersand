---
title: MAT-AUTH-000 independent architecture review and current-main reconciliation
status: Current
document-kind: evidence
scope: Dated source inspection, proposed architecture corrections, compatibility hazards and implementation admission boundaries for draft PR 357; no physics qualification or owner adoption
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../architecture/material-authoring-catalogue-plan.md, ../systems/materials-and-rule-kernels.md, ../systems/intermaterial-interactions.md, ../architecture/liquid-solver-family-policy.md, ../operations/documentation-maintenance.md]
---

# MAT-AUTH-000 independent architecture review — 2026-11-03

**Recommendation: ACCEPT WITH CORRECTIONS.** The six independent classifications,
build-time JSON/Python authoring and retention of bounded native kernels are
appropriate. The corrected proposal narrows the first #353 checkpoint to
shadow generation with an independent compatibility oracle. Exact values alone
cannot establish compatibility with existing policy/save identities or the
different GDScript fallback. Architecture adoption and implementation admission
remain owner decisions; [PR #357](https://github.com/techrote/cybersand/pull/357)
stays draft and unmerged.

This is source inspection and documentation validation. It reports no new
physics defect reproduction, solver benchmark, graphical acceptance or gameplay
qualification. Source-level inconsistencies and future extension hazards are
labelled separately from demonstrated runtime failures.

## Contents

1. [Source authority](#1-source-authority) — fixed main, original intake, PR and experimental branch identities.
2. [Verified catalogue facts](#2-verified-catalogue-facts) — counts, semantic memberships and current source distinctions.
3. [Required corrections](#3-required-corrections) — byte identities, backend parity, state effects and specialized authority.
4. [Classification and consumer review](#4-classification-and-consumer-review) — six-axis examples and generated versus retained consumers.
5. [Compiler and minimum migration](#5-compiler-and-minimum-migration) — deterministic schema contract and smallest safe #353 boundary.
6. [Dependencies and successor gates](#6-dependencies-and-successor-gates) — current owners, sequencing and acceptance obligations.
7. [Source and implementation cost](#7-source-and-implementation-cost) — exact static quantities and explicitly unmeasured costs.
8. [Validation and independent review](#8-validation-and-independent-review) — document checks, retrieval evidence and review disposition.
9. [Owner decision boundary](#9-owner-decision-boundary) — decisions required before implementation or new semantics.

## 1. Source authority

| Identity | Fixed value and meaning |
|---|---|
| Original architecture intake | `a8f08a67fea3c58f6df7473cbae1831334fcc04e`, inspected 2 November; preserved historical source |
| Original PR #357 head | `fc7f74768bb3d24fb7e913615f6774dbff321f91`, one proposed document; draft on `docs/mat-auth-catalogue-plan-20261102` |
| Accepted main reviewed now | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`, revalidated from live GitHub on 3 November |
| Accepted-main tree | `48f3ab7332b0dfddfb699b251f7e114453b1f3d4` |
| Local current-main reconciliation | `b25b27ab9eb275cac71f968a87e704e0e8571b47`, non-rewriting merge of accepted main into the existing PR history; before review edits its only difference from main was the original proposed document |
| Companion documentation | `6a58311982941b75f46e22109a0829e5acb83c7e`, the same pin used by Documentation CI |

The original proposal's sections 1–10 are retained verbatim. A visible wrapper
and new section 11 distinguish the corrected proposal from the frozen intake.
The original PR commit remains an ancestor; no source snapshot or negative
evidence is rewritten. Accepted-main changes since intake include PLAY recovery,
PACE004 apparatus, the LCB reassessment and Linux display setup. The material
headers, `material_rules.cpp`, `world.cpp`, quantity/state/transport contracts
and `cell_world.gd` inspected here retain the same source bytes across those
two main snapshots. This does not make the commits or their runtime evidence
interchangeable.

Live related heads at review intake:

| Work | Head | Status and ownership boundary |
|---|---|---|
| [Water phase #162](https://github.com/techrote/cybersand/pull/162) | `19f7ff43ecc494185226d1fff07dc21ef4a220fb` | Open, unmerged, not draft; partial quantity/phase/quench remains candidate work |
| [Paired materials #358](https://github.com/techrote/cybersand/pull/358) | `ffee6cd0f052fbe9a44fed08d9d99b3565a19205` | Draft, unmerged; new material forms and curing remain experimental |
| [SOL-DETACH #347](https://github.com/techrote/cybersand/pull/347) | `3ac7701f013452c94a8c08b0746e1b13523e7234` | Draft, unmerged; structural lifecycle and conservative contact/displacement |
| [LCB-FEEL #370](https://github.com/techrote/cybersand/pull/370) | `9a7436aa3d078a4efa190bc442e61aa0dc91c065` | Draft, unmerged; active comparison/preflight/host work |
| [Y1/GCR #343](https://github.com/techrote/cybersand/pull/343) | `2aff460c60f36c0f209b67fe682d0f8b9e5e0f83` | Draft, unmerged; generic contact experiment, not production adoption |
| [GCR rest/flyer #351](https://github.com/techrote/cybersand/pull/351) | `8ce36b0e41c9292ab0b1f02cf7789450082a67b5` | Draft, unmerged; separate experimental contact/rest/flyer work |

These are dated observations, not branch locks. Revalidate before any successor
writes. PR #358's exact candidate assigns StoneWall132, SaltWall133, CoalWall134,
DryBinder135, ActivatedBinder136 and BinderCrust137. Its chemical-parent routing
uses distinct IDs and specialized behavior; it is not an identity alias or
automatic family inheritance. It also proposes interaction profile3 and quantity
schema2 with20 specialized slots. Main remains profile2/schema1/19 slots.
No candidate data is imported into this review branch.

## 2. Verified catalogue facts

Source authority is [`material.hpp`](../../native/include/cybersand/material.hpp),
[`material_rules.cpp`](../../native/src/material_rules.cpp),
[`interaction_rules.hpp`](../../native/include/cybersand/interaction_rules.hpp)
and the actual [`World`](../../native/src/world.cpp), not names or categories.

| Property at reviewed main | Exact value |
|---|---:|
| Allocated slots / highest ID | 132 /131 |
| Valid / nonempty paintable entries | 131 /130; invalid10, Empty0 |
| Broad phases | Empty1, Solid104 including invalid10, Powder9, Liquid11, Gas4, Agent3 |
| Default FreeMass / CellularYield descriptors | 1 /10 |
| Compact pairs | 56:14 oracle +42 building |
| Specialized provenance records | 19 |
| Semantic families / memberships | 7 /33 |
| Currently authored generic layers | 0 |
| Hard-surface / granular-support members | 101 /9 |
| Pair participants / participants with `RuleKernel::None` | 41 /26 |

The seven explicit family membership counts are combustible20, conductive1,
reactive-base-glass1, hot-source3, aqueous2, biological3 and special-agent3.
The hard set is exactly IDs38–131 plus Wall, Cloner, Wood, Ice, Metal, Concrete
and Glass. The nine support members are Sand, Stone, Dust, Seed, Salt, Sodium,
Gunpowder, Coal and Rust. These happen to be all current powders; the capability
is an explicit switch, not phase inheritance.

**Current source risk, not a present collision failure:** both native and
GDScript hard predicates extend their upper range through `LAST_MATERIAL`.
Appending a non-hard material while retaining that predicate would make it
hard. A generated map must preserve all256 current byte-ID answers, including
invalid IDs, before any runtime switch. The proposed ID132 test must be
fixture-local because #358 already uses that experimental identity.

**Current distinctions:** semantic hot-source contains Fire/Lava/MoltenGlass;
`is_hot()` additionally contains Spark. MoltenGlass's cooling-reset predicate
uses the narrower three. This requires a scope decision, not automatic membership
repair. `is_timber()` recognizes Wood/OakTimber, so a combustible browse-labelled
wood does not automatically acquire Fungus/Mite substrate behavior.

The refreshed [liquid policy contract](../architecture/liquid-solver-family-policy.md)
and `LiquidPolicyBuild::running()` establish current admission: Water supports
FM, CY, PF(reference/cached/cached_dormant) and IN; Brine supports CY/IN; the
other nine liquids support CY only. Descriptor flow labels describe defaults,
not all applied per-World policy choices. Old branch-only/Planned paragraphs in
historical LCB records do not supersede this inspected current source.

## 3. Required corrections

### C1 — Preserve source-byte and positional compatibility

[`catalogue_digest`](../../tools/lcb/policy_contract.py) hashes domain, paths,
lengths and complete LF-normalized bytes of the material and interaction headers.
The capability matrix embeds source hashes and its own notes/classifications.
At reviewed main the catalogue digest is
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`
and capability digest is
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`.

[`LiquidPolicyDecoder`](../../native/include/cybersand/liquid_solver_policy.hpp)
refuses stale identities before catalogue interpretation.
[`world_pressure.inc`](../../native/src/world_pressure.inc) includes policy
identity in physical hashes, stores the envelope in CYPS and re-admits it during
restore. [`LiquidRunReceipt`](../../native/include/cybersand/liquid_run_receipt.hpp)
also carries those identities. Thus a formatting-only header rewrite can change
receipt/hash bytes and save admission. This is a source-established compatibility
path; the review did not execute a restore failure.

[`derive_capability_matrix.py`](../../tools/lcb/derive_capability_matrix.py)
regex-parses literal enum/descriptor/pair source. Moving data into includes can
break that dependency. Initial shadow generation must leave the inputs and
existing generated policy artifacts unchanged; a production cutover requires
byte-identical legacy output or an independently approved identity transition.
Never weaken a stale-identity guard or reuse an old digest for changed inputs.

[`world_quantity.inc`](../../native/src/world_quantity.inc) serializes positional
pair/kernel arrays and maps kernels to their first specialized-record match.
[`quantity_ledger.hpp`](../../native/include/cybersand/quantity_ledger.hpp)
fixes schema1,56 pair slots,19 kernel slots,256 material slots and6 quantity kinds.
Preserve both pair and specialized order/indices. Alphabetical sorting is not
compatible merely because stable rule names remain present.

### C2 — Preserve each backend, not an invented universal mirror

Native Slush density1080 differs from fallback1100; fallback also implements
a narrower movable/cellular-liquid set and separate Water rules. Sources:
`material.hpp`, [`cell_world.gd`](../../godot/scripts/cell_world.gd) and the
[granular contract](../systems/granular-interaction-policy.md). These are verified
source differences; no new physical defect was demonstrated. Generate shared
facts and explicit backend-qualified overrides, or retain a hand-maintained
consumer. Do not change fallback density/movement to satisfy a single schema.

All132 native RGBA tuples match the132 literal `BASE_RGBA8` entries in
[`material_appearance_lut.gd`](../../godot/scripts/material_appearance_lut.gd).
That supports shared color authorship, not pixel parity after moving Godot
HSV/float/half-float calculations to Python. Enum alias `Gas=Smoke`, native
slug names and UI display strings also remain distinct namespaces; the enum
alias is not proof that every current string parser accepts the label Gas.

### C3 — Specify actual endpoint state and quantity effects

World's compact-pair stage uses four-tick chemistry, seeded neighbour ordering,
one shared probability roll and the first selected contact. It writes target
then source; `roll <= threshold` makes threshold0 a1/256 opportunity, not disabled.
Water product `state_a` comes from `water_experiment_policy.maximum()`; other
products use descriptor defaults. `write_cell` records gross source/sink changes,
resets pressure state and retires IN state for products even at the same ID,
but leaves coordinate temperature storage intact. If identity, compact state
and sidecars already match, it can return unchanged without epoch/dirty mutation;
the selected pair event is still booked. Body-mask/write refusal remains part
of that path. Sources: `World::update_cell`, `write_cell` and
[`test_quantity_ledger.cpp`](../../native/tests/test_quantity_ledger.cpp).

The existing fixture deliberately records Water17 + ToxicSludge consuming17
and producing510 Water quantity. Preserving that legacy result does not call
the reaction conservative. #160/#162 own their separate bounded phase-quantity
correction. A generic `replace_with_defaults` label must retain these exact
state-domain rules; a same-ID output must never imply `keep_existing`.

### C4 — Retain executable specialized mechanisms and dynamic liveness

The19 specialized records are provenance descriptions, not an exhaustive kernel
language. Oil burning and Dust ignition are examples of World paths without
dedicated corresponding specialized rows. Preserving those rows alone cannot
prove complete runtime parity; retaining all executable kernel code is the
initial mechanical-migration boundary.

`rule_is_active` depends on state for Combustible, Metal, Plant and Fungus and
is false for `RuleKernel::None`. Twenty-six inert pair targets are still valid
because an active partner can initiate. A compiler must not require every
participant to tick or make inert materials awake. Resolver inspection cannot
assert World activity, masks or due opportunities it did not observe.

MoltenGlass quiet-block cooling and generic yielding-liquid early stochastic
returns justify controlled reproducers. No such new reproducer ran here. Mutual
MoltenGlass cooling reset is a distinct thermal-law question; current Water-CY
already retains legal future lateral opportunities across misses. Reuse existing
coalesced wake mechanisms before requiring the illustrative `KernelOutcome`
refactor. No always-awake workaround follows from this review.

### C5 — Keep parameter ownership and semantic conflict rules explicit

[`transport_profiles.gd`](../../godot/scripts/transport_profiles.gd) owns pickup/
packing on the grain target, permeability on the liquid regardless of initiator,
and other fields on the directed source. It resolves schema→family→material→pair,
forbids pair-level lateral overrides, requires symmetric permeability and rejects
overlapping directed/symmetric pairs. Do not replace this with one scalar per
material. Water-CY viscosity, Mercury's diagnostic viscosity and IN radius3
are additional applied-policy distinctions.

Overlapping semantic memberships are valid. Overlapping effective assignments
need an explicit unique owner/override or a compile-time conflict. Current
layer precedence is100/200/300/400/500 with zero authored layers; existing
syntactic selector checks alone do not prove that differently named overlapping
families cannot intersect. Future validation must test finite selector
intersections, orientation, field and context; unresolved intersections fail.
No input-array order becomes silent precedence.

## 4. Classification and consumer review

The classification proposal is accepted as a design direction with explicit
cross-references rather than inheritance. Stable identity binds references;
browse groups aid discovery; capabilities name predicates; behavior names
native consumers/state; semantic families select interactions; appearance
programmes describe rendering. None of the last five reassigns identity.

| Example | Required independent distinctions |
|---|---|
| Construction materials | A construction tag does not imply hard support, structural detachment or GCR acceptance; current explicit hard members happen to include all81–131 |
| Copper/WroughtIron | Metal browse category does not grant base-Metal charging or Acid+Metal compact products; broad Acid corrosion remains a different path |
| Wood/building woods | Combustion, hard terrain, timber substrate and displayed wood grain are separate facts |
| Reactive liquids | Selected solver, actual viscosity consumer, quantity/state contract and chemical contact are independent of Liquid phase |
| Base/themed glass | Base-Glass membership, individual authored thermal pairs, inert behavior and appearance are distinct |
| Stone/powders | Stone is a Powder and support member, not hard terrain; packing/bracing state affects behavior; Plant/Fungus are Solid without becoming hard |

| Consumer | Proposed first-stage disposition |
|---|---|
| `material.hpp`, `material_rules.cpp` | Freeze all15 descriptor fields, enum ordinals, invalid-ID behavior, density exchange and capability outputs; generate shadow comparisons |
| `interaction_rules.hpp`, `world.cpp`, `world_quantity.inc` | Preserve rule/slot/provenance order and hand-coded execution; inventory state effects outside generic records |
| [`c_api.h`](../../native/include/cybersand/c_api.h), [`c_api.cpp`](../../native/src/c_api.cpp) | Reuse existing material-info v1–v4 APIs; preserve ABI field widths/layout/reserved values |
| [`cyber_demo_bridge.hpp`](../../godot/native_extension/cyber_demo_bridge.hpp) | Reuse current interaction catalogue/resolver inspection and the separate C API material info; specialized records explicitly say `evaluated=false` |
| `cell_world.gd`, [`interaction_policy.gd`](../../godot/scripts/interaction_policy.gd) | Shared IDs may be generated after parity; fallback numeric/movement/Water contracts remain distinct |
| [`main.gd`](../../godot/scripts/main.gd) picker | Preserve display strings, material ordering, paint slots and shortcut mappings; no metadata edit silently changes input behavior |
| [`material_appearance.hpp`](../../native/include/cybersand/material_appearance.hpp), LUT and shaders | Preserve native Water/condition projection and shader algorithms; initially generate only supported literal metadata |
| [`transport_policy.hpp`](../../native/include/cybersand/transport_policy.hpp), transport resolver | Retain81-entry v1 shape, exact defaults/directions/bounds/hash; no automatic resize to132 |
| LCB derivation, wire vectors, catalogue and receipts | Preserve existing source extraction, generation order, version and refusal semantics |
| [`demo_save_codec.gd`](../../godot/scripts/demo_save_codec.gd), [`demo_snapshot.hpp`](../../native/include/cybersand/demo_snapshot.hpp) | Preserve CYSD1 logical five-byte tuples and ID validation; no full replay claim |
| CYPS, optional temperature/pressure/IN state | Preserve policy admission, positional quantity ledgers and state-domain contracts; Cell-layout equality alone is insufficient |
| Published Windows/Linux runtimes | Native input changes require source-matched artifact qualification; documentation/shadow metadata does not reattest old execution |

## 5. Compiler and minimum migration

The [corrected canonical proposal](../architecture/material-authoring-catalogue-plan.md#11-current-main-review-and-implementation-admission--2026-11-03)
owns the detailed contract. Its minimum #353-A result is strict versioned JSON,
a Python-stdlib compiler, deterministic inspection/shadow metadata, an independent
old-source oracle and negative validation cases. Runtime authority and existing
generated policy data stay unchanged. One registry plus a small number of
definition/provenance files is enough; the illustrative directory hierarchy is
not an obligation to create a schema framework.

Required compiler details include duplicate-key/unknown-field/version rejection,
integer bounds before narrowing, booleans excluded from integer fields, non-finite
number rejection, explicit alias resolution, stable legacy slots and file/JSON
pointer diagnostics. Deterministic source generation requires stable ordering,
escaping, UTF-8/LF and no environment/time/path dependence. `--check` is read-only;
failed validation publishes nothing; unchanged bytes are not rewritten. Native
binary reproducibility is a separate claim from generated-text equality.

The oracle must come from preserved pre-generator consumers or independently
reviewed extraction, not from the new compiler's own output. Compare all132
slots and all256 byte-ID predicate results; preserve all56 pair and19 specialized
slots. Enumerate65,536 ordered byte-ID pairs and all256 rolls where applicable,
including matched/rejected orientation and threshold boundaries. A full
all-pair/all-roll Cartesian comparison is16,777,216 evaluations if chosen;
that is a proposed gate count, not work executed by this review.

Conditional #353-B may switch one constant consumer after exact parity. Keep
the hashed headers' complete bytes and literal parser-compatible form. If a
cleaner output cannot do that, stop at shadow validation and request a separate
identity-transition design; do not require a physics change to fit the schema.
Retain old outputs and source/compiler manifests for per-consumer rollback.
If an admitted later schema/identity transition makes new data unreadable by
the old build, rollback must state that limitation and its versioned recovery
path; a source revert alone is not a data migration.

## 6. Dependencies and successor gates

Live issue review confirms #29 and #158 closed; #30, #160, #131, #204,
#200–#203, #212 and #352–#356 remain open. These states do not erase landed
INT-000, MAT-001 or LCB capabilities. [#367](https://github.com/techrote/cybersand/pull/367)
merged the current LCB reassessment; #370 is its active comparison successor.
[#364](https://github.com/techrote/cybersand/issues/364) keeps SOL contact recovery
separate from generic #83/#343 GCR adoption.

| Stage | Minimum acceptance and sequencing |
|---|---|
| #353 | Owner-admitted shadow metadata/compiler and independently frozen oracle first; exact IDs/aliases/descriptors/capabilities/families/indices/shared colors; precise invalid/conflict diagnostics; deterministic outputs; current LCB checks unchanged. Production cutover is a distinct review, with actual affected native/adapter gates and source-matched runtimes if native inputs change |
| #354 | Preserve existing MAT-001/Ice and Water-CY fixes; reproduce each remaining hypothesis on fixed source with quiet3/1024 and active-neighbour controls, phases/translations, seams, masks, reset and pause/re-entry; actual one/four-worker evidence; blocked/inert controls remain sleep-capable. Thermal law and stochastic rest changes require explicit decisions. Defer/no-go is valid |
| #355 | Preserve all legacy pair outputs, shared rolls, ordering, sidecar/temperature/no-op state and gross ledger values; test competing Acid/specialized paths and orientation/conflict cases. New effects stay synthetic until separately admitted. Reconcile #162/#358 rather than duplicating their state/quantity work |
| #356 | Read-only inspection may follow accepted #353 metadata. Editing waits for an actual native consumer, relevant #355 API and any relevant #354 disposition. Validate/refuse/reconstruct at the established owner boundary; failed edits preserve the old World/profile/source. Verify real desktop behavior and only applicable Web scope; no invented effective sliders or unobserved resolver reasons |

Keep the bounded chain #353 → (#354 and #355, serializing conflicting writes)
→ #356. Read-only source/reproduction preparation can run independently, but
changes to `world.cpp`, `world.hpp`, `world_quantity.inc`, material headers and
dependent identity artifacts need one integration owner. #358 touches catalogue,
appearance and curing; #162 touches quantity/reactions; #347 touches World,
pressure/contact and adapters; #343/#351 touch generic contact/bridge paths;
#370 and TEST-UX own shared host/panel work. Current hard/granular flags grant
neither structural ownership nor generic contact qualification.

## 7. Source and implementation cost

Source bytes below are exact at reviewed main. Static layout observations used
a metadata-only C++20 probe with Ubuntu g++13.3.0 on Linux x86_64, `-O2`, including
current headers and `material_rules.cpp`; it does not instantiate or tick World.
These observations exclude pointed-to strings, linker placement and enclosing
allocations. They are not resident memory, GPU residency or performance results.

| Item | Exact source/static quantity |
|---|---:|
| `material.hpp` / `interaction_rules.hpp` | 29,262 /73,581 source bytes |
| `material_appearance.hpp` / `material_appearance_lut.gd` | 8,354 /22,597 source bytes |
| `liquid_policy_catalogue.hpp` | 3,430 source bytes |
| `MaterialDefinition` /132-entry table | 40 /5,280 bytes on probed ABI |
| Pair record /56-entry table | 88 /4,928 bytes on probed ABI |
| Specialized record /19-entry table | 96 /1,824 bytes on probed ABI |
| Family record /7-entry table | 40 /280 bytes on probed ABI |
| Membership record /33-entry table | 24 /792 bytes on probed ABI |
| Derived partner sets /participant array | 8,192 /256 bytes on probed ABI |
| Material ID /Cell carrier | 1 /8 bytes; Cell alignment8 |
| `state_a` accessor /descriptor initial value | 16 /8 bits |
| Transport pairs /six-byte pair payload | 6,561 /39,366 bytes |
| `TransportPolicy` | 39,529 bytes on probed ABI |
| Packed transport v1 | 39,529 int32 words =158,116 bytes before container framing |
| Palette64×256 RGBA8 /program4×256 RGBA16F | 65,536 /8,192 raw texel bytes |
| CYSD1 world payload | 1024×1024×5 =5,242,880 bytes, separate from Cell layout |

### Reproduce the static inspection

Save the following probe outside the repository as `material_static_audit.cpp`.
At the reviewed source, compile and run with the command below (a 60-second run
guard for metadata inspection; no World code is linked):

```sh
c++ -std=c++20 -O2 -I native/include /tmp/material_static_audit.cpp native/src/material_rules.cpp -o /tmp/material_static_audit
timeout 60 /tmp/material_static_audit
```

```cpp
#include "cybersand/material.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/transport_policy.hpp"
#include "cybersand/precision_storage.hpp"
#include <iostream>
#include <map>
#include <string_view>

int main() {
  using namespace cybersand;
  unsigned valid = 0, paintable = 0, hard = 0, granular = 0, free_mass = 0, yield = 0;
  std::array<unsigned, 6> phases{};
  std::array<unsigned, 27> kernels{};
  for (std::size_t i = 0; i < kMaterialDefinitions.size(); ++i) {
    const auto& d = kMaterialDefinitions[i];
    ++phases[static_cast<unsigned>(d.state)];
    ++kernels[static_cast<unsigned>(d.kernel)];
    valid += d.valid;
    paintable += d.valid && i != 0;
    hard += MaterialRules::is_hard_surface(static_cast<Material>(i));
    granular += MaterialRules::supports_granular_load(static_cast<Material>(i));
    free_mass += d.lateral_flow == LateralFlowMode::FreeMass;
    yield += d.lateral_flow == LateralFlowMode::CellularYield;
  }
  std::cout << "slots=" << kMaterialDefinitions.size() << " valid=" << valid << " paintable=" << paintable
    << " hard=" << hard << " granular=" << granular << " free_mass=" << free_mass << " yield=" << yield << '\n';
  std::cout << "phases:"; for (auto n : phases) std::cout << ' ' << n; std::cout << '\n';
  std::cout << "kernels:"; for (auto n : kernels) std::cout << ' ' << n; std::cout << '\n';
  std::map<std::string_view, unsigned> families;
  for (const auto& m : kSemanticFamilyMemberships) ++families[m.family_id];
  for (const auto& [f, n] : families) std::cout << f << '=' << n << '\n';
  std::cout << "descriptor_size=" << sizeof(MaterialDefinition) << " table=" << sizeof(kMaterialDefinitions)
    << " pair_record=" << sizeof(PairInteractionRule) << " pair_table=" << sizeof(kPairInteractionRules)
    << " mechanism_record=" << sizeof(SpecializedInteractionRule) << " mechanism_table=" << sizeof(kSpecializedInteractionRules)
    << " membership_record=" << sizeof(SemanticFamilyMembership) << " membership_table=" << sizeof(kSemanticFamilyMemberships)
    << " family_record=" << sizeof(SemanticFamilyDefinition) << " family_table=" << sizeof(kSemanticFamilies)
    << " partner_sets=" << sizeof(InteractionRules::build_partner_sets())
    << " participants=" << sizeof(InteractionRules::build_participants())
    << " transport_struct=" << sizeof(TransportPolicy) << " transport_packed_int32_count=" << TransportPolicy::packed_size
    << " cell=" << sizeof(detail::PrecisionStorage) << '\n';
  unsigned pair_participants=0, no_kernel_participants=0;
  for (unsigned i=0; i<256; ++i) {
    const auto m=static_cast<Material>(i);
    if (InteractionRules::has_pair_rule(m)) {
      ++pair_participants;
      no_kernel_participants += material_definition(m).kernel==RuleKernel::None;
    }
  }
  std::cout << "pair_participants=" << pair_participants << " inert_pair_participants=" << no_kernel_participants << '\n';
  std::cout << "pair_count=" << kPairInteractionRules.size() << " frozen=" << kCurrentOraclePairRuleCount
    << " mechanisms=" << kSpecializedInteractionRules.size() << " families=" << kSemanticFamilies.size()
    << " memberships=" << kSemanticFamilyMemberships.size() << " layers=" << kInteractionLayerDefinitions.size() << '\n';
}
```

### Implementation cost assessment

The partner sets already avoid scanning56 rules for nonreacting neighbours.
The compiler should emit fixed tables and retain this fast rejection. No
tick-time parsing, string lookup, family traversal, allocation or per-cell
metadata is needed. A proposed256-entry byte capability column would contain
256 scalar bytes, but its actual linked cost and lookup performance are unmeasured.

| Cost/risk | Assessment and required control |
|---|---|
| Build complexity | One stdlib compiler plus explicit drift check is sufficient initially. Reuse existing LCB generators; avoid parallel competing schema/identity pipelines |
| Generated readability | Stable keys/legacy slots and external source maps support review; keep code-generation banners outside byte-frozen files |
| Material addition | Select a supported native contract, allocate an approved stable ID, declare independent capabilities/state/appearance and optional rules, then validate/rebuild. A browse tag never admits behavior |
| Validation quality | Strict types/bounds and two-origin conflict errors are required; actual authoring usability remains untested |
| Compile/incremental rebuild | Duration, include fan-out cost and generator speed are unmeasured. Do not rewrite unchanged files; split presentation from native outputs |
| Source metadata size | Existing source sizes above are measured. Proposed JSON/source-map size is unmeasured; avoid redundant dense pair authoring |
| Runtime storage/tick cost | Static component sizes above are known; linked size, cache effects, resident memory and tick cost are unmeasured. A shadow-only stage adds no production tick path |
| CI/documentation maintenance | Add deterministic/negative/parity checks when implementation is admitted; retain existing provenance, M11 and retrieval ownership. Broader physics CI is not justified by this documentation edit |
| Schema/rollback | Version authoring separately from runtime/save identities; preserve old inputs and outputs. Any future incompatibility needs an explicit migration/refusal and rollback contract |

## 8. Validation and independent review

The original PR-head documentation check failed because its new focused page
was absent from `retrieval-corpus.json`. The first source-only local invocation
also lacked pinned companion paths; those environmental omissions were resolved
using the exact Documentation-CI companion snapshot, not fabricated files or
weakened checks. Main then passed docs and repository identity checks.

Baseline retrieval at reviewed main is frozen32:19 hit@1,32 hit@5,MRR0.7536;
challenge157:123 hit@1,156 hit@5,MRR0.8712. Existing challenge LCB03 has no
canonical hit in the top5. That prior miss must not be silently presented as
a new regression or a green answer. Supplementary MAT-AUTH questions are
separate from both existing sets.

### Executed local gates

The reviewed documentation delta is on reconciliation commit `b25b27ab` over
the pinned main above. Commands ran on Linux x86_64 with Python 3.12.14 and
Git 2.51.1; bounded rechecks used a 60-second command timeout. The metadata-only
probe used the compiler and source printed in section7. These are separate
evidence types, with no World tick, physics, graphical or benchmark execution.

| Gate | Command or comparison | Result |
|---|---|---|
| Documentation/retrieval manifest | `python3 tools/ci/check_docs.py` | PASS;118 documents,3,538 local links,668 heading anchors,32 frozen question references |
| Current repository identity | `python3 tools/ci/check_repository.py` | PASS; all18 runtime entries are validated committed LFS pointers locally, not materialized/executed libraries |
| Historical M11 | `python3 tools/ci/check_m11_consistency.py` | PASS;18 retained records and28 source hashes at immutable `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`; no current runtime claim |
| Capability derivation | `python3 tools/lcb/derive_capability_matrix.py --check` | PASS; existing source-derived matrix unchanged |
| Liquid policy wire identity | `python3 tools/lcb/policy_contract.py --check` | PASS; vectors match existing oracle |
| Native policy artifacts | `python3 tools/lcb/native_policy_artifacts.py --check` | PASS; artifacts match sources, no regeneration |
| Normalization contract | `python3 tools/lcb/water_normalization_contract.py --check` | PASS;8 independent canonical vectors |
| Receipt contract | `python3 tools/lcb/liquid_run_receipt_contract.py --check` | PASS;7 independent complete vectors |
| New plan and audit links | Focused local-link/anchor walk using the existing checker parser, including the audit excluded from default corpus | PASS;68 links and23 anchors; external network links are not counted as local-link validation |
| Whitespace/scope/history | `git diff --check`; path comparison against accepted main; original-section byte comparison | PASS; only `docs/**` changes, original sections1–10 preserved; native/GDScript/CI/generated/runtime inputs unchanged |

The first M11 check lazily fetched historical Git blobs from the complete-history
clone; the bounded branch recheck passed after those objects were available.
No historical hashes were changed. Final committed-head checks and hosted run
identity are attached to the PR publication record, so this in-tree report does
not claim knowledge of its own future commit hash or a hosted result in advance.

### Retrieval outcomes and limits

Executed `python3 tools/docs/retrieval_eval.py --output <report.json>` and the
same evaluator with `--queries docs/reference/retrieval-challenges.json` and
`--queries docs/reference/retrieval-questions-mat-auth.json`. The final corpus
has118 documents and1,574 heading chunks. Existing fixture files were unchanged.

| Set | Before review hit@1 /hit@5 /MRR | Revised result | Answer qualification |
|---|---|---|---|
| Frozen32 |19/32 /32/32 /0.7536 | Identical; no rank changes | Existing lexical baseline, not a new answer-truth score |
| Challenge157 |123/157 /156/157 /0.8712 |124/157 /156/157 /0.8739 | MS05 shifts rank3→4 and GEN25 rank2→1; pre-existing LCB03 top5 miss remains |
| New MAT-AUTH10 | First draft6/10 /9/10 /0.7500 |7/10 /10/10 /0.8500 | Separate read-only expected-fact review: nine sufficient across top5; Q09 partial |

The new question wording stayed unchanged while two useful document sections
were made independently retrievable: family/preset conflicts and Materials Lab
effective inspection. Q03's complete Slush/backend answer is at rank3; its
historical top1 canonical hit alone is insufficient. Q09's top5 excerpts omit
rollback and concrete production-cutover gates that are present in section11's
successor table. This is an explicit retrieval limitation, not missing design,
and the10/10 canonical-route score is not claimed as10/10 complete answers.

Supplementary fixture SHA-256:
`b43d0741e0129653582ac78eb733d12ccbf32a74f1ff70d4ad51ac0bcb9f5b6a`.
Reviewed plan SHA-256:
`694d7785364395781e3723adb0a36720a3760bee819b1a40ba1ead668e675b5f`.

### Independent read-only review

Two independent technical reviewers inspected fixed-current-main source and
the revised design: one focused on runtime/material/state/liveness contracts,
the other on compiler/mirror/identity/cost contracts. Both returned **PASS** on
the substantive corrected design with no required corrections remaining.
The compiler reviewer identified a low-severity wording distinction between
C API material info and bridge interaction inspection; the consumer table above
now states that distinction. A separate dependency/retrieval reviewer confirmed
active ownership and the nine-complete/one-partial expected-fact result.

These reviews are not owner architecture adoption, implementation permission,
runtime acceptance or merge approval. A final read-only frozen-checkpoint check
and exact-head publication receipts belong to the PR conversation.

## 9. Owner decision boundary

**Recommended decision:** adopt the corrected six-axis design and admit a
separately assigned #353-A shadow compiler. Keep #353 open if only that narrowed
checkpoint is delivered, unless the owner explicitly changes its completion
scope. Require a separate cutover decision when exact-byte compatibility cannot
be achieved. This permits useful authoring progress without new material physics.

The owner has not yet adopted this architecture or authorized implementation.
Future decisions remain: Spark semantic-family scope; same-ID preservation and
quantity-aware effects; MoltenGlass cooling law; yielding-liquid retry/rest law;
runtime-editable fields with real consumers; production IDs/paired-material
integration; any transport/catalogue/CYPS identity transition. Preserve current
semantics and experimental identities until their respective decisions.

No generated catalogue, native/GDScript definitions, Cell/save/ABI layout,
reaction kernel, scheduler, material tuning or runtime payload changed in this
review. PR #357 remains **draft and unmerged** at the owner decision boundary.
