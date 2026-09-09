---
title: Granular interaction and sampled player policy
status: Current
document-kind: contract
scope: Versioned material capability and bounded player support; cell exchange is a separate implementation checkpoint
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
32 by 32 cells. Mode 0 checks full-volume enclosure, 1 samples powder at feet,
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

## What is the exchange checkpoint?

**Planned in the second issue #10 change:** reject density-only powder/powder
reordering; retain void-driven fall/avalanche; explicitly classify liquid/powder
pairs and gate Mercury independently of viscosity, with bounded wake scheduling.
The issue #9 [dated baseline](../audits/2026-09-09-physics-characterisation.md)
remains the historical comparison. Current exchange remains that baseline until
the separate exchange change lands. Versioned support thresholds are scoped
gameplay settings, not a claim that proposed barrel tolerances are accepted.

Source: [policy](../../native/include/cybersand/interaction_policy.hpp),
[native queries](../../native/src/world.cpp),
[adapter](../../godot/native_extension/cyber_native_cell_world.cpp),
[character](../../godot/scripts/sampled_character.gd),
[shared probe](../../godot/scripts/interaction_policy_probe.gd).
