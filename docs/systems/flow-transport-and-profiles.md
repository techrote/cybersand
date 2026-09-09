---
title: Motion-driven transport and tuning profiles
status: Current
document-kind: contract
scope: Versioned profile resolution, compact native tables and opt-in flow experiments
canonical-for: [transport-tuning-profiles, motion-driven-grain-transport]
last-reviewed: 2026-09-09
related-documents: [granular-interaction-policy.md, water-design.md, ../operations/experiment-tower.md]
---

# Transport profiles

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
81 sampling values, 81 cadence values and 81×81 six-value pair records in
source-major order. Native `state_hash` includes configuration; `content_hash`
continues to describe cells independently of the selected profile.

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

**Planned next checkpoint:** successful-motion hooks and horizontal sampling
consume the experimental controls. At the infrastructure checkpoint only pair
permeability is applied; profile round trips do not establish new physics.

## What are the ownership and storage bounds?

`TransportPair` is exactly six bytes: 6561 records, two 81-byte arrays and the
configured flag form fixed construction configuration (about 39 KiB). No per-cell
field, hot-loop allocation, material thread or new rule radius is added at this
checkpoint. Godot authoring dictionaries are outside tick-time allocation claims.
Desktop handoff serials remain monotonic when a replacement native snapshot
exchange restarts its own serials, preventing stale acknowledgements from
discarding a fresh full-world image.

Sources: [resolver](../../godot/scripts/transport_profiles.gd),
[editor](../../godot/scripts/transport_profile_panel.gd),
[table](../../native/include/cybersand/transport_policy.hpp),
[installation](../../godot/native_extension/cyber_demo_bridge.hpp).
