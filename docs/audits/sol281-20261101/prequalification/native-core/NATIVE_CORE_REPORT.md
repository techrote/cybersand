# SOL-DETACH-001 native implementation and adapter review

## Implemented source

Base: current-main `809fd30dfac0c5e127302997075be9c4b279e5aa`; archive source: `254235ec4c3d58782bba44b478caca86bf57c856`. Files are uncommitted in the principal implementer's shared branch. No remote operations or commits were performed by this agent.

The frozen native ownership core was selectively ported: `solid_detachment.hpp`, `world_solid_detachment.inc`, required World declarations/mutation fences, two persistence/hash guards, and the focused native test. Historical rendering experiments were removed from the imported test; production main render-copy implementation was left unchanged.

Two bounded core improvements are included:

- Ambient Sand and Current FreeMass Water adjacent to the cohesive source stay native and do not create structural bonds. Hot, masked, unknown, unsupported and reactive neighbours continue to refuse. The populated fixture proves intact anchoring and exact 520-cell transfer/rollback while preserving all surrounding tuples.
- Acknowledgement now requires the entire compound proxy-ID interval to fit the native 64-ID contact registry before native ownership transfers. The bridge's own preflight remains required.

The new native conservative transaction uses a fixed request of 2–5 exact captured cell tuples. It preflights cardinal adjacency, no duplicate coordinates, resident/included cells, exact source mask, unmasked destinations, expected tick, optional active aggregate token/body generation, allowed Sand/FreeMass Water, a canonical ambient Empty terminal, and every required thermal field before any move. It then propagates the vacancy backwards with ordinary `move_cell` bookkeeping. Each parcel moves exactly one cardinal cell. No force, torque, search radius or Rapier motion is implemented here. Source coordinates are restricted to the existing external material-field envelope of ±1,000,000,000.

Supported refusals have zero writes and zero moves. A logically unexpected exception in the preflighted no-allocation commit quarantines the World and is not retryable. The actual adapter must propagate that fatal state; an invariant failure is not a successful atomic refusal.

## Local executed qualification

| Executable | Groups | Checks | Result |
|---|---:|---:|---|
| `test_solid_detachment` | 9 | 19,338 | Pass |
| `test_solid_detachment_sanitized` | 9 | 19,338 | Pass, ASan/UBSan |
| `test_conservative_displacement` | 6 | 281 | Pass |
| `test_conservative_displacement_sanitized` | 6 | 281 | Pass, ASan/UBSan |

Compiler: GCC 13.3.0 Ubuntu 24.04. Sanitizer environment: `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1`, `UBSAN_OPTIONS=halt_on_error=1`. Exact source input, binary and log hashes are in `receipt.json`; all four targets were verified current by `make -q` exit 0. Normal/sanitizer logs are retained beside the receipt. Existing conversion warnings are retained in build logs.

The tests cover actual native World operations, not mocks of those operations. Bridge receipts in native detachment tests remain synthetic. These results do not establish actual Godot/Rapier, Windows, rendered performance, physical feel or whole-milestone acceptance.

The three new mass-property checks use an independent analytic rectangle-lamina oracle: a 29×13 canopy minus one square, a 4×25 trunk and an 11×4 branch. Exact relative COM is `(3293/130, 175/8)` and polar inertia is `109907693/1560` for 520 unit cells.

A first test attempted complete physical-state hash comparison immediately after CYPS restore and failed because the established format deliberately excludes host-owned body masks. The fixture was corrected to reconstruct the independent host mask before comparing the full live state. The failed attempt and cause are preserved in `initial-displacement-harness-failure.txt`; production source was not changed to make that assertion pass.

## Independent adapter review

This agent authored the native core and transaction, but independently reviewed the principal implementer's adapter source.

1. **Fixed:** replay treated false from `set_cell_state` as failure even for a canonical Empty no-op. Parent changed reconstruction to verify exact material/state/temperature tuples and masks.
2. **Fixed:** source ownership previously trusted only the first-writer center mask. Parent added full-square foreign-body overlap refusal, retaining own compound proxy membership as one aggregate owner.
3. **Fixed:** narrowing huge finite JSON values into Vector2 could produce nonfinite geometry and SAT comparisons could fail open. Parent now validates narrowed fields and fails closed on nonfinite SAT gap.
4. **Outstanding in last inspected snapshot:** replay allows non-Water state_a up to 65,535 and Water state beyond current maximum/coherence, then calls throwing `World::set_cell_state` without a surrounding catch. Initial tuple validation and/or catch is required so malformed diagnostic input returns refusal instead of allowing a C++ exception to escape a bound Godot method. This was reported directly to the parent.
5. **Required host dependency:** per-contact reaction remains the existing shared coupling reaction, including on repeated/stale displacement refusal. Correctness depends on exact-sample feedback consumption. The new actual-body compound-response fixture explicitly exercises duplicate proxy, stale sample and repeated sample across publications without repeated torque; parent owns execution and final disposition.

The reviewed search uses fixed arrays and a four-element insertion sort, with no hidden heap allocation in search or commit. It retains nonrearward cardinal steps and positive terminal progress. Full destination-square clearance against every current body protects each one-cell move; the swept volume between two cardinal-adjacent squares is their union. The source's existing body overlap is permitted only for the owning aggregate; additional foreign source geometry is refused.

## Remaining integration work owned by principal

- Execute actual-host and source-matched platform qualification, graphical checks and final repository gates.
- Add the two new sanitized test executables to the existing native-family prebuild inventory if using the existing soliding CI family, so compile time is not hidden in the case execution budget.
- Preserve explicit limits: one configured inert homogeneous aggregate, no generic reactive Wood/fracture/restoration/persistence or production gameplay admission; native transaction correctness does not prove effectiveness in packed geometry.
- Retain negative archived displacement experiments and source provenance. No frozen branch was changed.
