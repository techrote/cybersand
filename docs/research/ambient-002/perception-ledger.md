---
title: AMBIENT-002 embodied perception and physical experiment ledger
status: Planned
document-kind: research
scope: B lane implementation, bounded local observations, physical campaign registration and retained limits
last-reviewed: 2026-11-25
related-documents: [mission-ledger.md, ../../systems/ambient-actors.md, ../ambient-001/perception-ledger.md]
---

# AMBIENT-002 embodied perception and physical experiment ledger

## Checkpoint: source candidate, execution pending

The lane starts from predecessor branch head
d0af9b6015c27417fddd67f79afdcf656a609571. The qualified AMBIENT-001
application f4f94631d61d492554627949497e727b26043ccb and its evaluator are
untouched. The local executor became unavailable during intake, before edits.
The implementation is therefore constructed as immutable Git objects through
the repository connector. No local execution or graphical pass is claimed.

The lead owns final integration into a new Draft/HOLD successor and source-bound
hosted qualification. This document records candidate source contracts; only
dated receipts may upgrade an execution claim.

## Implemented candidate observation changes

V1 profiles retain the four-cell material lattice. V2 profiles opt into
spacing_cells (requested coarse resolution 1–4), near_radius_cells (0–16),
and refine_boundaries. All material reads share one 4,096-site cap per decision.
A dense near-field disk finds thin cells that the old lattice misses. A bounded
5-by-5 patch around each observed material and four immediate neighbors refine
the nearest sample and a local estimated boundary normal/tangent.

When the requested coarse radius/resolution would exceed the cap, the effective
spacing is explicitly increased. The algorithm keeps spatially uniform coarse
coverage instead of silently truncating toward a raster corner. It reports
requested/effective resolution, actual reads, refinement/near-field reads,
coverage completeness, and unavailable/stale/incomplete states. Remote thin
features between coarse sites can still be missed. A material boundary is local
evidence and supplies no passage or global reachability proof.

The physical rig offers two optional ground or eight optional two-axis terrain
rays, with at most 32 cells of clearance measured from a conservative attached
hull extent. These are separate from the existing motor sensing allowance.
A canvas-clipped empty ray is unknown, never certified free space. These center
rays are not a swept-volume planner. Ground alternatives remain horizontal.

Peer sensing accepts copied owner observations with the same run, epoch and
physical tick. It examines at most 32 candidates and returns the nearest seven,
retaining the authoritative eight-actor host limit. The larger input budget is
an explicit future compatibility seam, not permission to instantiate more
actors. Copied velocities have their own availability. Authored tags produce
affinity -1/0/+1, with avoidance winning a conflicting preference. Invalid,
stale, disappeared and truncated candidates make coverage incomplete.

## Integration interface

The session calls Perception.settings(profile) and supplies the result under
context.perception. An empty dictionary selects the unchanged V1 sampler.
Perception.wants_navigation(profile) recognizes enabled steer_obstacles and
withdraw_obstruction; only these modules request the optional terrain fan.

PhysicalActorRig.ambient_navigation_observation(32.0, canvas_extent, vertical)
returns navigation.directions containing direction, available, hit,
clearance_cells, maximum_distance_cells, normal and bounded source geometry.
The session passes this copied dictionary, validated regions, authored relations
and the World generation to observe. A new World generation is exposed to the
memory owner; unavailable identity remains -1 rather than an invented generation.

Material target boundary is a copied dictionary with available, position,
normal, tangent, checked_neighbors and source. boundary_normal and
boundary_tangent aliases are supplied only when observed. Generic enabled
module material_id/radius parameters now register sensing requests without
depending on a closed list of module names.

## Registered qualification

The new test_ambient2_spatial.gd contains:

- Thin near-field detection and an explicitly retained remote-thin-feature miss.
- Complete local absence versus incomplete sampled non-observation.
- Fresh/stale/unavailable publication handling and generation replacement.
- Budget coarsening, malformed setting refusal and generic module requests.
- Peer tags, affinity conflicts, disappearance, stale identity, velocity absence,
  copy isolation, nearest selection and a finite future candidate seam.
- Actual Rapier wall, free direction, two/eight-ray and canvas-clipping checks.
- Separate 1/4/8-query population cost microbenchmarks for V1 and V2 sampling.

The microbenchmark counts logical sensor queries, not physically instantiated
actors. It must not be used to claim larger actor capacity. The physical campaign
will independently identify at least 100 actual actor episodes across matched
baseline, stateful, memory, drive/personality and social ablations; register
initial-state equality and actual native/Rapier completion before reducing it.
Thirty-second, two-minute and sustained horizons are separate arms. Negative
behavioural findings remain results, not fixture failures to optimize away.

Report environment: CYBERSAND_AMBIENT2_SPATIAL_REPORT.
Terminal completion marker: AMBIENT2_SPATIAL.
Run with the pinned Godot and source-matched native/Rapier runtime.
