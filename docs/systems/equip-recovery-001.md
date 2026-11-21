# EQUIP-RECOVERY-001 — BS-001 selective recovery register

Status: **Draft/HOLD, qualification in progress.** This document is a source-recovery register, not evidence of acceptance or Windows playability.

- Accepted base: `846fe0533b3170e7b01f690518da49fc40cc24d1` (2026-11-21).
- Donor: BS-001 PR #561, source `efbb0bd420b667c446d48fe32f6d5b93bb40a9c3` (historically merged into feature branch, not accepted main).
- No donor global-default changes, historical CI publication jobs, binary runtimes, provenance assertions or fixture-hash weakening have been imported.
- Existing Water/PressureFlow/Wave Flow implementations remain authoritative. The opt-in `ballistic_solids` World configuration defaults to **off** and requires ballistic Water when enabled.
- Recovered native owner: `ballistic_solids.hpp`, `world_ballistic_solids.inc`, World tick/render/persistence/ledger hooks, opt-in preparedness and GDExtension functions.
- Recovered reusable kinetic core: `workbench_kinetic_mask.gd`, `kinetic_usables.gd`, U33–U45 catalogue definitions. New equipment uses the existing `CyberUsableRuntime` command path.
- No player input handlers, key maps, flyer loadouts, flight physics or recoil calibration were changed.
- Historical launcher/collector/conveyor equipment apparatus and kinetic/solids Workbench labs have **not yet been restored**. Their donor code is not compatible with newer Workbench panel and Wave Flow revisions without additional integration.
- Runtime DLL/SO and Windows evaluation builds have **not** been republished from this branch. Do not describe old donor builds as source matched.
- Independent final-delta review is **outstanding**.

## Distinguishing operation contracts

Shooters are admitted **external material injection** through the native bounded ballistic owners (Water through its parcel owner; eligible non-Water materials through the new whole-cell owner). Kinetic manipulation tools **transfer existing cells** into flight through `launch_water_parcel` or `launch_solid_parcel`; they do not fabricate material. Runtime refusals are returned as string statuses. Both families require the appropriate explicitly enabled World owner.

## Handoff exclusions

The later FLYER-CONTROL-001 programme owns named player actions, bindings, repeated/held modes, flyer loadouts, masses/gravity/thrust/torque, recoil/handling and Workbench control windows. None of these are an implicit part of this recovery.
