# IN-TOOLS #361 implementation successor — predecessor salvage and authority record

Date: 2026-11-06
Draft PR: #480
Implementation base: `7e2c2fd1aa2759590d63d5dfb53ce9e4c0a76e4b`
Base tree: `9460c007eee2f3864cbb40d63800db3f85c0b858`

This note records source decisions for the real current-main implementation successor.
It does not alter or merge #379, #404 or #383.

## #404 material

Reused/adapted:
- the current-main source-admission architecture;
- the historical #379 provenance and Windows causal discriminator;
- the reviewed minimal-authority principle;
- the #383 read-only salvage assessment.

Corrected rather than copied:
- A01 is now structural. The checker code contains the immutable 17-path authority
  set and roles. The registration record is accepted only after exact set equality.
- The record distinguishes implementation-base blobs from re-admitted implementation
  blobs, so a deliberate feature change is not confused with an unreviewed descendant
  mutation.

Not carried forward:
- #404's preparation-only Current/Planned claims;
- its mutable record-selected 13-path guard;
- the historical assumption that #361 would not modify production authority.

## #383 material

Reused unchanged from its reviewed implementation:
- `godot/scripts/metered_liquid_drain.gd`;
- the deterministic metered-drain fixture and its native quantity/census logic;
- focused metered equipment/runtime qualification concepts.

Reused after adaptation:
- `physical_usable_equipment.gd` and `physical_usable_runtime.gd`: their #383 base
  was byte-identical to the selected implementation base, then generalized to explicit
  v3 leak/nozzle profiles and separate source/sink accounting.
- `actor_prototype_panel.gd`: retained the explicit opt-in pattern and extended it
  to reversible leak and directed IN Water nozzle.
- `physical_actor_session.gd`: only the release/held-state semantics were ported
  onto the newer current-main session.
- `main.gd`: semantics were manually reimplemented against current #406-era source,
  including generic-pause revocation and visible owner readback.

Rejected/obsolete:
- #383's `simulation_worker.gd` patch was not imported. Current main has the
  #406-era `apply_world_execution_settings(...)` topology and later prepared-world
  ownership. The terminal/quarantine behavior was reimplemented against that source.
- no #383 branch merge, rebase, force update or wholesale cherry-pick was performed.

## #406 boundary

The #361 directed source is explicitly ordinary `inertial_cellular_source_v1`
whole-cell Water. Its receipts carry `ballistic_transport=false`; there is no
ballistic fallback. It uses the already-admitted native IN external-velocity law
after whole-cell source admission.

#406 ballistic Water remains a separate opt-in capability and is neither counted as
#361 IN transport nor used to satisfy the #361 source fixture.

## Feature authority

- Metered drain: finite sink budget, native stored-quantity/cell accounting.
- Reversible leak: one-cell authored Wall/Empty aperture; occupied closure refuses
  without overwriting the occupant.
- Directed IN nozzle: finite 32-cell Water stock per native World generation; one
  whole Water cell per accepted source command; exact source-credit ledger.
- Gameplay integration: existing U10 Liquid Drain supplies drain/leak identity;
  existing U02 Water Lance supplies the directed IN nozzle identity. Ordinary
  profiles remain version 1 and unchanged unless explicitly selected.

The complete source authority is registered in
`godot/tests/fixtures/lcb/in_tools/in-tools-361-source-admission.2026-11-06.json`
and independently pinned by `tools/lcb/in_tools_361_source_admission.py`.
