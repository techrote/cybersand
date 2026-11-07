---
title: PressureFlow C2048 explicit capacity profile implementation
status: Current
document-kind: evidence
scope: Isolated Draft implementation from main 4c2c9732; opt-in C2048 native World profile with versioned physical identity and persistence; no production adoption or merge
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/pressure-flow-v1.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/configuration-and-capacity-budgets.md, ../reference/invariants.md]
---

# PF-C2048 — explicit capacity profile (experimental)

## Authority and scope

This implementation starts from accepted main `4c2c97323d862afdd3ec6730017127cc8e4ec05c`. [Research PR #475](https://github.com/techrote/cybersand/pull/475) remains Draft and unmerged. Its [exact-head research execution](https://github.com/techrote/cybersand/actions/runs/42315143662) and [independent review](https://github.com/techrote/cybersand/pull/475#pullrequestreview-5808937803) support C2048 as the smallest *candidate* capacity sufficient for the observed initial demo census (1,175 compartments) and 300/900-tick stress-canvas peak (1,314).

**No production selection, default change, physics-law change or merge is authorized here.** This branch implements the owner-requested isolated C2048 candidate, without the research branch's compile-time `CYBERSAND_PF_GAS_CAPACITY` macro. Current default remains **C1024**, and default Water remains FreeMass.

The native `WorldConfig::pressure_gas_compartment_capacity` parameter admits only **1024** or **2048**; C2048 is valid only if Water actually selects a **gas-enabled PressureFlowV1** family. Unknown values and non-PF/gas-disabled requests fail at construction, before a World is exposed. This is a construction-time explicit profile, **not** an extension of the v1 liquid policy wire family parameter block, a live-resize feature or a general Godot UI option.

## Bounded storage and topology

At construction, the World-owned pressure table and scratch reservations use the applied per-World ceiling. The cache component reservation and bounded-cache fallback share that ceiling; the workbench inheritance path checks destination capacity and sizes its separate preparation-time coverage vector from the source live table. The default C1024 path retains the same reservation counts. All gas creation, split, initial-admission and CYPS decoder checks use the applied ceiling; all exceed-capacity operations still fail explicitly and quarantine the World.

Fixed, independent limits are unchanged: `kCompartmentVolumeLimit = 16384` (atmospheric classification), `kRegionCapacity = 65535` (16-bit region marks), `kOverlapCapacity = 8192`, `kChunkNodeCapacity = 1024`, `kHistoryCapacity = 64`, eight ancestry slots, the monotonic 32-bit gas ID domain and the physical pressure/Water laws. No implicit dropping, merging or vacuum conversion of small pockets.

## Identity and save-compatibility decision

- **C1024** remains byte-identical in the existing physical hash streams (2/3/4), CYPS2/3/4 envelope and native applied-receipt encoding. Historical golden vectors and refusal fixtures remain untouched.
- **C2048** is explicitly new **physical hash version 5 and CYPS5**, independent of whether inertial/ballistic features are also configured. CYPS5 retains the CYPS4 extension envelope and sets bit 3 for this profile, then stores a v1 capacity-contract version and 2048 (u16 each) before other optional extension payloads. The typed native receipt appends the domain `cybersand-pressure-gas-capacity-v1`, contract version and capacity **only** for C2048. The normal policy hash/catalogue capability digests are unchanged; distinguish the *applied World capacity* using the versioned native receipt/physical identity, not the v1 policy envelope alone.
- **Restore fails closed.** A CYPS5 file requires a receiving `WorldConfig` explicitly requesting C2048. A legacy CYPS2/3/4 file requires a receiving C1024 configuration. There is **no implicit capacity upgrade or downgrade**: upgrading a legacy save requires a separately specified migration/reconstruction contract. High-capacity saves cannot be silently opened by the old decoder.
- Runtime/GDExtension policy-parameter readback uses the actual applied capacity when an applied World is available; predicted policy-only readback stays at 1024. The Godot prepared bridge now accepts a strictly checked integer `pressure_gas_compartment_capacity` option (1024 or 2048), only with an applied gas-enabled PF policy. The ordinary default/demo option is 1024. Workbench developer options can explicitly forward 2048, and a retained workbench refuses capacity switching until a fresh session is prepared. `inspect_gas_compartments()` reports the applied capacity. **An experimental workbench 'PF 2048' checkbox now stages the opt-in for the next fresh Apply/Build; it defaults off, cannot switch a retained World in place, and is not a production default.** The separate native-default session still requires an explicit host setup value. Source-matched Godot/Windows acceptance and native runtime publication remain required. End-to-end Godot/Windows test, UI adoption, and source-matched GDExtension artifact publication remain required.

## Tests and admission gates

The implementation extends the native pressure setup-capacity regression with C2048-only tests: invalid/nonpressure/gas-disabled profile refusal; 2048 exact-bound preflight and tick; 2049 typed refusal and quarantined tick; CYPS5 exact round trip and hash; C1024 receiver refusal for CYPS5; C2048 receiver refusal for legacy CYPS2; differentiated native receipt facts; the actual masked native-default demo under all three PressureFlow variants (1175 complete initial pockets). The original C1024 1024/1025, mask, 16384/16385 atmosphere, unseeded, and historical test expectations remain unchanged.

Branch-scoped GitHub-hosted native execution uses GCC 13 on Ubuntu and records source SHA, compiler, run logs, boundary results and artifacts. **Do not promote this Draft or merge until** independently checked exact-head Native/Godot/Windows and sanitizer results; the canonical MAT-AUTH per-file reviewed transitions for any changed protected World/policy source; updated canonical configuration/invariants/retrieval docs and any required registered host fixture successor; strict review of C2048+gas/ballistic interactions and actual 1/4 worker participation; explicit owner final approval. Do not self-approve the MAT-AUTH chain or bypass source locks.

## Decision checkpoint

After qualification, the owner may approve an explicitly requested C2048 user-facing execution profile, retain C1024 only, or request further research. The experiments do not justify 4096 as a silent default. This branch is an implementation candidate, not a published runtime.
