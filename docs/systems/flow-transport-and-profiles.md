---
title: Motion-driven transport and tuning profiles
status: Current
document-kind: contract
scope: Versioned profile resolution, compact native tables and opt-in flow experiments
canonical-for: [transport-tuning-profiles, motion-driven-grain-transport]
last-reviewed: 2026-11-24
related-documents: [granular-interaction-policy.md, water-design.md, ../operations/experiment-tower.md]
---

# Transport profiles

These construction-time cellular transport controls are separate from the
ordinary player Wave tuning profile. Current Wave construction explicitly
**refuses a configured custom transport policy**; it does not silently consume
or ignore these fields. FreeMass, PF and IN callers have their own admitted
operator and geometry contracts. See [Water Lab](../operations/workbench-water-lab.md)
and the [family policy](../architecture/liquid-solver-family-policy.md) before
combining settings. The refusal is in
[`World::validate_wave_flow_config`](../../native/src/world_wave.inc).

## How are profiles resolved and applied?

**Current:** `CyberTransportProfiles` accepts version 1 JSON separately from
CYSD1, at most 64 KiB, with name, families, materials and pairs. Unknown keys,
fractional/nonfinite numbers, overlapping pairs, invalid IDs, malformed shapes
and unsupported versions are rejected. Baseline, Gentle transport and Threshold
erosion are protected constructors returning fresh copies; editing or saving
creates a user copy. Saved JSON uses `user://transport-profile.json`; the panel
also accepts pasted JSON and offers copy/export.

Resolution is schema defaults, family defaults, material adjustments, then sparse
pair overrides. Resistance belongs to the target grain; permeability belongs to
the liquid in either initiating direction. Mixing and carrying are directed source
settings. Pairs declare directed or symmetric; permeability overrides must be
symmetric, and lateral sampling/cadence remain material settings. The editor shows
effective values and origins. Only Water→Sand/Dust/Rust can enable carrying in
schema v1; other liquids remain disabled pending screening. Mercury retains
period 30 and disabled carrying.

Apply and restart validates before sending a copied candidate to the desktop
worker, or before the synchronous Web call. `CyberDemoBridge::build_tuned_world`
validates a fixed 39,529-int packet, constructs cells and render exchange, then
performs no-throw ownership swaps. Rejection preserves the old world/profile.
Jobs never parse JSON or mutate tables. Ordinary demo construction restores
production Baseline; lab reset retains the successfully applied profile. CYSD1
remains a level save, without tuning or complete replay state.

Resolved identity is SHA-256 of the lowercase hexadecimal representation of the
packed 32-bit integer bytes (little endian on Windows/Wasm). It includes version,
81 sampling values, 81 cadence values and 81×81 six-value pair records (IDs
0–80; later building IDs use defaults through bounds-safe accessors) in
source-major order. Native `state_hash` includes configuration; `content_hash`
continues to describe cells independently of the selected profile.

Source and runtime artifact identity are required alongside profile identity.
The [2026-09-10 Water relaxation change](../audits/2026-09-10-water-leveling.md)
keeps schema-1 values/hashes but increases lateral mass movement and optional
erosion pickups. Earlier Water traces and sampling measurements retain their
dated solver identity.

## What are the controls and units?

| Setting | Range and meaning |
|---|---|
| mixing | 0..255 fraction of successful powder-motion opportunities; 0 disables |
| carrying | 0..255 multiplier of successful Water mass transport, divided by 255 |
| pickup | 0..255 disturbance-unit threshold for a grain |
| packing | 0..32 additional disturbance units per occupied neighbour |
| erosion | 0 loose exposed grains; 1 permits exposed packed grains above threshold |
| permeability | 1..60 ticks, symmetric liquid/powder density-exchange eligibility |
| horizontal | 2 existing lateral candidates or 1 deterministic sampled candidate |
| cadence | 1..60 ticks between lateral opportunities, independent of strength |

Baseline uses mixing/carrying 0, pickup 64, packing 8, erosion 0, horizontal 2,
cadence 1, permeability 1 except Mercury 30. Experimental templates set powder
mixing 96 and Water→Sand/Dust/Rust carrying 255; Threshold erosion sets erosion 1
for these pairs. These are initial opt-in experiment values, not calibrated shear
or a replacement gameplay default.

## How does actual motion drive mixing and erosion?

**Current:** after a successful powder fall into Empty, `World::mix_after_motion`
may exchange it with an unlike exposed neighbouring powder, using a real void
above or below the candidate as loose-flow evidence and at most five occupied
neighbours. The source must actually have fallen vertically; activity flags and
update epochs cannot initiate mixing. The displaced candidate must not already
have been written this tick. Density eligibility remains a separate path and
still excludes every powder/powder pair. Identical powder grains are not shuffled.

Lateral Water movement/transfer may pick up the grain below its source. At least
64 successfully transported normalized mass units are required. Water mass is
first normalized through its applied precision policy to the schema's 0–255
scale; effective disturbance is `normalized_mass * carrying / 255`. It must reach both 64 and `pickup + occupied * packing`.
The eight-neighbour occupancy counts hard surfaces and support-capable grains.
Gentle rejects occupancy at least four; erosion permits it above threshold. A
coordinate-stable four-tick lane bounds pickup to at most one per source on that
lane. There is no stored disturbance, delayed transport debt or probability that
can gradually eat a resting bed. Once flow stops, pickup stops immediately.

Both paths use the existing whole-cell conservative swap, preserving material,
the two material-state fields and temperature, including Water fill. Current
Cell storage has a 16-bit state-A field; “two state fields” is not a four-byte
Cell-layout prescription. The local helper checks reads within two cells of its
source; each caller must account for the complete motion/transport footprint.
The diagonal path includes the vacated/intermediate source, checks occupancy
and body masks, and cannot bypass a wall by checking only its destination.
Braced Stone remains excluded. PF and IN call the same helper at their own
motion boundaries; IN tracks the translated footprint and requires read3/write2
geometry. These profile values do not grant a larger domain or bypass that
[operator contract](../architecture/inertial-cellular-v1.md).

Telemetry kinds 8 and 9 count powder mixing and grain transport separately from
Empty movement, density swaps and conversions. Kind 11 counts new neighbour
reads. Existing histogram bounds/overflow apply; disabled hooks make no new
neighbour probes. No extra wake or per-cell motion field is introduced.
Horizontal sampling caps the existing lateral candidates at one; the first
direction uses the existing deterministic rule. Water and yielding liquids
previously attempted up to two; Oil, Acid and Lava already attempt at most one,
so setting two does not invent additional movement. Gravity and diagonal falling
are unchanged. Cadence 1..60 gates only lateral movement using coordinate-stable
phases and the existing earliest per-block wake deadline, without catch-up.
This can wake quiet blocked liquid at later eligible times; it is not a guaranteed
sleep or performance improvement. Chemistry/lifecycle cadence is untouched.
Telemetry kind 10 counts eligible lateral candidate probes (target byte is a
placeholder, not the encountered material); kind 4 counts Water mass units
transferred, not transfer calls. Sampling never multiplies carrying strength. See [dated results](../audits/2026-09-09-issue-13-transport.md); visual
acceptance and production performance are not implied by native counters.

## What are the ownership and storage bounds?

`TransportPair` is exactly six bytes: 6561 records, two 81-byte arrays and the
configured flag form fixed construction configuration (about 39 KiB). No per-cell
field, hot-loop allocation, material thread or enlarged rule radius is added.
Two World booleans cache whether any mixing/carrying pair is enabled.
Godot authoring dictionaries are outside tick-time allocation claims.
Desktop handoff serials remain monotonic when a replacement native snapshot
exchange restarts its own serials, preventing stale acknowledgements from
discarding a fresh full-world image.

Sources: [resolver](../../godot/scripts/transport_profiles.gd),
[editor](../../godot/scripts/transport_profile_panel.gd),
[table](../../native/include/cybersand/transport_policy.hpp),
[`World::mix_after_motion`](../../native/src/world.cpp),
[installation](../../godot/native_extension/cyber_demo_bridge.hpp).
