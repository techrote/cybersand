---
title: Granular interaction and sampled player policy
status: Current
document-kind: contract
scope: Version 1 material capability, sampled player support, pair exchange and deterministic permeability wakes
canonical-for: [granular-support-policy, granular-pair-policy, sampled-player-collision]
keywords: [powder, packing, player, Dust, Mercury, permeability, enclosure, side resistance]
last-reviewed: 2026-09-09
related-documents: [materials-and-rule-kernels.md, ../architecture/rigid-body-and-cellular-coupling.md, ../operations/physics-characterisation.md]
---

# Granular interaction and sampled player policy

## Which powders support the player?

**Current:** `MaterialRules::supports_granular_load` explicitly includes Sand,
Stone, Dust, Seed, Salt, Sodium, Gunpowder, Coal and Rust. Density and hard-surface
identity are independent. The native owner queries `World::granular_support_at`;
the interpreted owner mirrors it in `CyberInteractionPolicy`. No Rapier collider,
body bearing force or material ownership transfer is introduced.

`InteractionPolicy` version 1 is immutable construction configuration. Downward
support counts a 3 by 3 neighbourhood at x-1..x+1, y..y+2, including the contact
cell. At least eight of nine samples must be hard terrain or support-capable
powder that did not move/change in the last cellular tick. The contact itself
must be a stable powder. Setup at tick zero permits immediate queries. This is
local packing, not proof of connectivity to the world floor. A thick distant
unsupported structure can temporarily satisfy the local approximation; cells
continue to fall and invalidate it as motion reaches the neighbourhood.

Side/upward resistance additionally requires all nine samples in the centred
3 by 3 neighbourhood. Loose grains and unsupported one-cell films therefore
do not become invisible walls. Hard terrain and the current body mask always
block. Excavation removes support on the next owner query, without cached
colliders or a sleep prerequisite. The bounded probe does not certify arbitrary
granular load paths or supply barrel bearing; those remain issue #11.

## How does the sampled character move and recover?

`character_box_collides(origin, size, mode)` accepts finite positive boxes up to
32 by 32 physical cells (up to 33 by 33 raster cells at fractional origins).
Mode 0 checks full-volume enclosure, 1 samples powder at feet,
2 at sides, and 3 at the head; every mode checks hard occupancy throughout the
volume. Malformed/out-of-world boxes fail closed. `box_collides` is mode 0.
The old material-only fallback helper now identifies hard surfaces only.

`CyberSampledCharacter` uses at most one-cell movement increments, a one-cell
grounded step-up, and clamps each simulation delta to 0..0.1 seconds. Before
movement, enclosure recovery searches at most 128 axis candidates within 32
cells, nearest first and upward/left/right/down at equal distance. It moves only
the sampled character, never erases cells or moves a Rapier body. When no clear
candidate exists, velocity is zero and `recovery_blocked` is explicit. Diagonal
escape, crush damage, barrel pushing and carrying are not implemented.

Native queries run only under the serialized World owner, outside kernels;
the read neighbourhood does not enlarge native job write domains. Desktop and
Web retain their different character/cell order. Fallback uses the same query
geometry and material capability, but its narrower cellular rules remain a
separate semantic reference, not native Water/reaction parity.

## How do pairs exchange, and how does Mercury keep progressing?

**Current version 1:** `MaterialRules::can_density_exchange` rejects every ordered
powder/powder pair. Grains rearrange by falling into real Empty cells, including
eligible downward diagonals. There is no density-driven exchange even in loose
powder; void movement supplies yield and avalanche. Existing Stone vertical-only
movement and native intact/granular bracing remain distinct.

The complete native liquid/powder classification uses the nine powder capabilities
above and these liquid IDs. It applies to either initiating endpoint before any
swap; density direction/target permission are still prerequisites.

| Liquid | Powder interaction after density eligibility |
|---|---|
| Water, Lava, Acid, Paste, Slush, Brine, Cement, Toxic Sludge, Molten Glass | One opportunity each simulated tick |
| Oil | Oil cannot initiate downward powder displacement; denser powder may settle through Oil |
| Mercury | One opportunity each 30 simulated ticks, independently of viscosity |

Native `World::exchange_permitted` also rejects displacement of an intact braced
Stone endpoint; explosion-created granular Stone (`state_b=1`) can yield. On an
eligible liquid/powder opportunity, a destination already written in that tick
cannot be reused. All downward/diagonal alternatives share the same modulo lane;
trying three directions cannot multiply the rate. Non-powder gas/liquid rules,
Water-to-Empty/Water mass transfer, lateral viscosity and chemistry retain their
own paths. Chemistry runs before the relevant transport and may change which
material pair remains; Seed germination and Water reactions are explicit examples.

Mercury uses `tick_index % period == 0`, with no random roll, coordinate-dependent
cooldown reset or accumulated debt. Empty movement is tested before this gate and
retains full speed. A denied eligible interaction stores the earliest due tick
in its source activity block. The ordinary metadata pass wakes due included
blocks; waiting blocks can sleep. Exclusion retains the deadline without motion.
Re-entry evaluates the present lane once, then waits for the next lane if needed;
it never replays missed moves. Failed-world quarantine still prevents tick entry;
clear/replacement abandons the deadline with its owning block.

The metadata adds one 64-bit deadline per native block (eight additional bytes in
the tested layout), with no new queue, allocation, full-world cell scan or worker
API call. Block ownership is unchanged. `state_hash` includes policy version,
thresholds, period and pending deadlines. This improves this state's identity;
CYSD1 still does not provide full replay continuation.

Fallback mirrors all nine powders, Mercury density/viscosity, empty movement,
powder-pair exclusion and the 30-tick lane. Its fixed deadline array wakes only
due included blocks and resets per-cell quiet counters within those blocks.
It has discrete Water, retained Slush density 1100, fewer liquid/reaction kernels
and no native Stone fracture-state representation. Other native-only liquids and
chemistry remain outside fallback parity. Gas displacement remains independent.

## Why these versioned settings?

[ADR-011](../decisions/ADR-011-granular-interaction-policy.md) selects version 1:
8/9 downward samples, 9/9 side samples and period 30. Diagnostic fresh construction
accepts `support_cells` 1..9 and `mercury_period` 1..60; invalid values preserve the
current adapter world. Normal reset restores defaults; no gameplay slider or
unsynchronized live change is introduced. The periods are ticks: 30 is 0.5 seconds
at the fixture's 60 Hz, and a different caller tick rate changes elapsed-time speed.

Source: [policy](../../native/include/cybersand/interaction_policy.hpp),
[native rules and queries](../../native/src/world.cpp),
[adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[character](../../godot/scripts/sampled_character.gd),
[shared probe](../../godot/scripts/interaction_policy_probe.gd).


## Versioned transport profile checkpoint

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The tower can author profiles; experimental motion hooks follow separately.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.
