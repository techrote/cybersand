# PressureFlow #201 — active gas-component certificate admission (7 November 2026)

Status: **IMPLEMENTED EXPERIMENT; NOT PERFORMANCE-QUALIFIED; NO MERGE**. Isolated branch `agent/pf201-selective-gas-cache-20261107`; base accepted main `81bbd5ff5cf366159e2b8a630609359c13560080` (#405 included). Do not conflate this work with open #504/#505/#515/#522.

## Bounded root-cause assessment

1. `prepare_pressure_tick()` executes reference gas topology every tick unless the derived cache is complete and the previous reference pass reached a *global* fixed point. `cache->gas_dirty = gas_enabled && !gas_fixed_point`.
2. `resolve_gas_topology()` computes `gas_fixed_point` only when global identity/topology, final labels and resident allocation all remain unchanged. Active workbench scenes can legitimately change these; forcing `gas_dirty` is **correct** for the authoritative operator.
3. Previously `rebuild_pressure_gas_cache(stamp)` was unconditionally gated by global `gas_fixed_point`. This prevented it from *building any sealed-compartment certificates*, including unrelated unchanged components, during continuous global churn.
4. Existing `prepare_pressure_gas_cache()` already applies dirty-chunk + one-chunk bounds and invalidates IDs with missing live compartments. `replay_pressure_gas_region()` validates the complete member list, old volume, anchor, cell material, old label, transient mask and collision with visit stamps before stamping. Stale proofs fail closed to a complete uncached restart before any identity reduction. These mechanisms remain the safety boundary.
5. `#505` real Windows app profiling observed ~983,040 seed/relabel cells and ~125,047 BFS cells per gas tick, one global reference operator, zero component replays. `#515` reported a ~2.17% real workbench native-tick benefit from #504, versus +14.10% synthetic native-only (with a negative #505 half-scale application result). **These are historical observations, not results for this candidate.**

## Candidate algorithm

- Admit an independently stable *sealed positive-ID* component from a completed reference pass even if another region changed. Existing region-level proof still requires exactly one live overlap, exact old/new ID, volume and anchor, all-resident membership, no new/atmosphere cells and bounded storage.
- Keep existing valid component certificates across subsequent active global passes, rather than rescanning the entire resident World to reconstruct the same member list each tick; conservatively invalidate on a dirty-chunk bound or missing live ID.
- If all components are invalidated, disable cache replay so the pooled seed prepass remains available. If no component is eligible, avoid the full-world member-building scan. A global fixed-point pass can still refresh certificates.
- Leave the global reference seed census, BFS fallback, compartment identity/history reduction, final relabel and `gas_dirty` decision unchanged. No material, gas law, default Water, capacity, CYPS, physical hash or World worker ownership change. Cache state remains derived and disposable. Bump pressure-optimization *execution* identity to v5; retain physical-state hash5/C2048 semantics.
- This is a proof-admission and amortisation experiment, **not a guaranteed CPU improvement**. Full serial seed prepass when a component cache is usable may outweigh saved BFS. A native replay must quantify that tradeoff before integration.

## Tests / acceptance contract

- Native regression `test_active_gas_component_certificates`: continuous remote room topology edits from first tick; reference/cached/cached_dormant exact gas compartment table and full physical hash with 1/4-worker configurations; measured global reference passes with positive component replay; subsequent edit in the certified room invalidates its proof. Existing split/merge, mask, chunk, stale label, capacity/budget and save/restore tests remain mandatory.
- Exact-input full-size native replay: export actual authored `stress_canvas` geometry, scripted fixed eight-body masks, jet and wall/erase tape; compare **every per-tick physical hash, complete quantity digest and gas identity/history** against pinned main, including 1/4 workers and camera movement. Intentionally **do not require BFS/cache work counters to match**, since that would prohibit the optimization.
- Real application A/B: source-build baseline and candidate native GDExtension on one Linux host, run original authored **2048×1024 stress-canvas**, eight live Rapier barrels, C2048 `cached_dormant` with gas, ballistic face/spray/jet, repeated hard edits, 24+240 native ticks, B-C-C-B. Preserve exact runtime hashes and raw receipts. This provides wall-time/throughput evidence, **not deterministic Rapier input equality**.
- Hold for independent source-matched Windows 59-material/eight-barrel CPU-stage profile (#505), gas-stage process CPU and complete native tick CPU, enough repeated BCCB samples to resolve variance, and Windows/Linux native+Godot+sanitizer/TSan exact-head CI and GDExtension publication. Check C1024/C2048 and gas-off/FreeMass/Inertial controls. Keep production native binaries and main untouched.
- **Performance go/no-go:** real workbench must show a persistent worthwhile CPU improvement, gas-stage improvement and no other mode regression. If benefit is negligible/negative, simplify or reject this candidate; never merge a merely correct but slower cache. MAT-AUTH has no protected-source edit in this branch; do not modify the locked `world_pressure.inc` or `world.cpp` without a separately reviewed, commit-bound transition.

## Outstanding

Native and Godot workflows must run at the **candidate exact head**. Pending independent review, measured stage CPU/performance verdict, source-matched publication and explicit merge authority. This record does not claim these gates passed.
