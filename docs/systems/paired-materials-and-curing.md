---
title: Paired wall and loose materials, finite curing and shell laboratory
status: Current
document-kind: contract
scope: Current experimental branch source for six appended native materials, shared chemistry, finite Water activation and a desktop shell lab; runtime qualification and owner acceptance remain separate
canonical-for: [paired-materials-and-curing, paired-wall-chemistry, finite-binder-curing, paired-material-shell-lab]
last-reviewed: 2026-11-03
related-documents: [materials-and-rule-kernels.md, intermaterial-interactions.md, ../operations/paired-materials-registration.md, ../operations/paired-wall-loose-materials-plan.md, ../architecture/rigid-body-and-cellular-coupling.md, ../architecture/liquid-prepared-setup-and-receipts.md]
---

# Paired wall and loose materials, finite curing and shell laboratory

**Current experimental branch source:** PAIR-CURE-001 appends three wall forms
and a separate finite-curing binder family. It starts from main
`89020b9eb6d540383a5bb64b58dcd29a87592c32`, under the committed
[registration](../operations/paired-materials-registration.md). This page states
the source contract; a playable scene or source inspection does not establish
platform qualification or owner gameplay acceptance. The feature stays unmerged.

## Which materials are paired, and what does the wall form change?

| ID | Material | Physical form and chemistry |
|---:|---|---|
| 132 | Stone Wall | Hard, immobile form of existing granular Stone13; density2400 |
| 133 | Salt Wall | Hard, immobile form of existing granular Salt23; density2160 |
| 134 | Coal Wall | Hard, immobile form of existing granular Coal27; density1300 |
| 135 | Dry Binder | New granular powder, density1600; requires a qualifying consumed Water dose |
| 136 | Activated Binder | Internal damp granular form, density1800; finite countdown and retained bound quantity |
| 137 | Binder Crust | Hard, immobile cured product, density2000; never an activation donor |

Activated Binder retains its original density1800, movable Powder state,
downward motion and target-side density-exchange opt-in. Existing
`MaterialRules::can_density_exchange` already rejects Powder↔Powder exchange
before comparing densities. The proposed wet-state exchange opt-out was
therefore retracted; it is not part of this implementation. The separately
registered [surface-depth gate](../audits/paired-materials-2026-11-03/admission-a1.json)
remains additional qualification rather than evidence for a changed motion law.

All old IDs0..131, including reserved invalid10, remain in place. The catalogue
has138 slots and137 valid IDs including Empty. The old hard range38..131 is
explicitly bounded at Heat Shield Tile; the appended powders are not accidentally
classified as hard. Walls132..134 and crust137 are hard and non-granular. Both
binder powders135/136 explicitly support granular load. These are capabilities,
not a reinterpretation of numeric density as collision or cohesion.

Native immutable helpers in [material.hpp](../../native/include/cybersand/material.hpp)
declare the three admitted chemical parents and loose/wall counterparts. Only
the interaction contact resolver and explicit shared Coal state use the chemical
parent. Movement, density exchange, hard extraction and kernel dispatch use the
actual form descriptor. There is no general alias of all themed building names
to a base material and no separate wall reaction owner.

Stone Wall retains Stone's broad Acid-neighborhood susceptibility. Salt Wall
inherits both Water+Salt dissolution and Salt+PackedSnow contact consequences.
Coal Wall shares Coal ignition, extinguishing, burn countdown and emissions,
remaining a wall through surviving burn-state writes; its terminal Dust14
product is ordinary movable Dust. Equivalent exposed contacts share chemistry;
bulk outcomes may differ because immobile walls and grains expose and mix
differently. Real gas/liquid/residue products do not acquire invented wall forms.
The narrow preservation of a surviving paired endpoint does not alter legacy
same-product state initialization.

`CyberDemoBridge.inspect_interaction_profile()` returns copied
`material_count` and `material_catalogue` values: IDs, names, state, density,
movability, hard/granular capabilities, chemical parent, both counterparts,
paired-wall flag, kernel, write radius and default state bytes. These values are
inspection data, not mutable descriptor authority. Current interaction profile3
and `int.pass.pair-cure-001` retain the old56 compact rule IDs/indexes and add
one specialized finite-binder provenance entry.

## How does finite Water activation stop instead of spreading forever?

Dry Binder probes at most8 Moore neighbors during an eligible update and consumes
at most one **full normalized Water cell with zero pressure overfill**. The Water
cell becomes Empty through the existing native write owner. The binder becomes
Activated Binder with countdown180 in stateA and the consumed Water quantity in
stateB. Supported3..8-bit precision gives a full quantity7..255, which fits the
existing byte. This is an explicit chemical sink/retained product, not a new
Water transport, pressure, viscosity or partial-debit law.

Partial Water, pressure-overfilled Water and Brine do not activate Dry Binder.
Refusal preserves the cells. Activated Binder decrements its own countdown on
eligible updates, remains granular until completion and preserves bound stateB
when it becomes Binder Crust. At60 eligible updates/second,180 updates is about
three seconds; scheduling or paused regions do not promise that wall-clock time.
An authored Activated Binder with zero bound quantity returns to Dry Binder
rather than manufacturing free cure. The normal lab palette offers Dry Binder
and Binder Crust rather than the internal activated form.

Air, age alone, Concrete, existing crust and neighboring Activated Binder cannot
start another dry cell. Removing free Water stops new activation; already
activated cells may finish their original countdown. Cracks need fresh Water
to expose and activate more powder. There is no cure flood fill, donated token,
renewed reservoir, crust catalysis or automatic binder recycling.

**Existing Cement30/Concrete31 behavior is unchanged.** Cement still uses its
existing flowing kernel and Air/Water/Brine/Concrete context. Concrete-neighbor
acceleration in that older material is not reused by finite Binder.

The free-Water quantity ledger records activation as a finite-binder kernel
consumption. Bound stateB is a separate chemical-product quantity. In an admitted
closed fixture, compare free visible Water plus overfill plus retained bound
quantity against the supplied dose; do not count bound quantity as free Water
or conceal intentional external painting/removal. The lab's bounded tray census
exposes free and bound quantities independently.

## What changes in saves, receipts and fallback?

The new specialized kernel appends the twentieth slot (index19) without
renumbering old kernel slots.
Nested quantity-ledger schema2 carries20 kernel entries,56 pair entries, six
source/sink kinds and256 material population slots. Unknown/old quantity schemas
are explicitly refused during physical-state restore; there is no implicit
old19-slot reinterpretation or promised migration. Current receipt vectors and
material-sensitive LCB fingerprints need new source-bound identities. Historical
vectors/hashes keep their original inputs and status.

CYSD1 retains its existing five-byte cell payload: material, stateA, stateB and
temperature. It can carry new IDs and finite-cure state through a matching new
native runtime without a format expansion. CYSD is a reconstructable level,
not complete replay. An older runtime must reject unknown IDs transactionally.

The GDScript fallback refuses IDs132+ at its material write boundary. It does
not simulate native wall chemistry or silently freeze binder powder. The new
desktop lab requires native profile3/catalogue138 and refuses Web, fallback and
older runtimes. New palette/condition rows are presentation-only; all legacy
appearance rows retain their own qualification identity.

## How do I try shell destruction and the curing tray?

The additional surface-depth admission test uses a closed24-cell-deep dry bed and one
16-cell full-Water dose. At360 ticks on workers1/4 it must retain exact free-plus-
bound quantity and binder population, produce no bottom crust, and keep maximum
crust depth within2 cells of the initial exposed surface. Its no-agent and
cured-neighbor controls must also pass. This gate is registered, with final
source-matched execution still required; A0 quantity/isolated-curing evidence
does not establish where crust forms and keeps that limitation.

Use **Paired material lab — break shells, expose powder and try finite curing**
from the desktop feature launcher, or open
[`paired_material_playground.tscn`](../../godot/paired_material_playground.tscn)
with the source-matched native build. F2 returns through current launcher
teardown. The lab uses current-main synchronous material/Rapier ownership and
existing Vector Rush/Barrel Rocket controls; it does not stack the unmerged
GCR-LA/flyer/rest experiment or claim its acceptance.

Choose Stone, Salt or Coal in the family dropdown; this reconstructs the room.
The view shows A all-loose, B intact matching shell and C a matching shell with
a known opening. Fly onto B and choose **Breach intact roof**: the bounded44×4
patch is a real native authoring removal exposing the powder. It is not an
automatic load-damage or actor-force law. Water dissolves Salt Wall, Fire burns
Coal Wall and Acid also attacks Stone Wall through their existing shared paths.

The separate tray offers **Add16 Water cells** and **Remove tray Water**. Dosing
uses only empty/unmasked source cells; occupied positions refuse. Watch the damp
front become crust, remove the remaining free Water and observe that new
activation stops while existing wet cells can finish. Free painting remains
available: LMB paints, RMB erases, wheel adjusts radius1..24, P pauses and R
reconstructs the room. Keys1/2 choose Vector Rush/Barrel Rocket. The receipt
labels source, native profile, response owner and explicit external edits.

Intact shell cells use ordinary Rapier terrain collision. Destruction/conversion
changes native hard revision, then the existing synchronous arena admits terrain
before its next Rapier step. The dedicated release fixture uses an air gap and
a short actual collision ray so granular support cannot disguise a stale shell
collider; shape-count decrease alone is not a retirement metric.

Unsupported severed wall islands may remain static. Coherent detachment,
structural strength, arbitrary fracture, sleeping, friction/load tuning and broad
REM-004 acceptance remain separate work. Gameplay judgement and any unresolved
physical or platform failures belong in the dated qualification handoff.
