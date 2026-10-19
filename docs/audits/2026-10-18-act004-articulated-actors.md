---
title: ACT-004 articulated roster and scripted control evidence
status: Current
document-kind: evidence
scope: Dated 41-actor Rapier implementation, shared leased control, usable effects, native capacity, desktop integration and source-matched runtime validation; target-PC feel and Web remain separate
canonical-for: [act-004-articulated-actor-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/physical-actor-rigs.md, ../systems/thunderbowl-control-reference.md, ../operations/physical-actor-programme.md, ../architecture/simulation-tick-and-threading.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# ACT-004 articulated actors — 2026-10-18

## Authority and source identity

The owner requested completion of [ACT-004 / issue #178](https://github.com/techrote/cybersand/issues/178),
including articulated Rapier rigs for every existing actor, another dozen where
practical, and substantial scripted examples for all of them. The owner's
subsequent physical direction explicitly allows bounded gameplay assistance,
approximate joints and controlled flex/play; it does not require finite gyro
momentum bookkeeping. The preserved [owner observations](2026-10-18-owner-actor-observations.md)
remain useful tuning context.

The recovered implementation and this completion work begin at main
`b31a897b485a1913a67a02a39fb271495bacf027`, after the exploratory actor selector
integration. [PR #181](https://github.com/techrote/cybersand/pull/181) owns branch
`codex/act004-complete-41-rigs`. Its frozen implementation commit is
`d897cac257f90ff37b16ae5bc5c65de85c6465ee`, tree
`a81823da7b038ba25e3b93e7748a47c20fb95988`; all 62 changed source/document blobs
were checked against the local export before publication. Initial local tests
used the base plus this working delta, not the base commit alone. Complete
native/build input maps are retained by the source-matched runtime publication
manifests. Historical sampled actor,
M11, Water and soliding evidence is not relabelled as ACT-004 validation.

The [physical actor contract](../systems/physical-actor-rigs.md) owns current
mechanisms and control. This record distinguishes local execution, fresh runtime
builds, hosted publication and final integration; a successful earlier copy does
not establish a later source-sensitive gate.

## Delivered roster and demonstration scope

All **29 existing identities** in Sets A, B, F, Y, U and V have physical
definitions. **SetX adds twelve:** Monowheel, Inchworm, Pendulum, Rocker,
Hammerhead, Rocketblade, Tandem, Tricopter, Tiltrotor, Heavylift, Needlejet and
Gyrosled. Every supplied rig contains two through seven actual Rapier bodies;
the contract admits at most eight including held objects. Collider dimensions,
mass, offsets, joints and rendered polygons share the authored definition.

The 41 entries each supply a configured local feedback demonstration through
`physical_actor_script.gd`. Scripts observe copied poses, contacts, local rays,
velocity, resource and attachments, then submit the same leased action envelope
as a human or external policy. They do not write transforms, assign locomotion
velocity, access mutable cells or replenish resources directly.

The demonstrations include contact gait and patrol recovery, coiled leap/release,
aimed excavation, hover clearance, recoverable rotor flight, independently
pulsed Duet thrust, rope take-up/pumping/release, sustained winching and suspended
payload swing feedback. The [catalogue and producer suites](../../godot/tests/test_physical_actor_catalog.gd)
check all entries, while [actual Rapier fixtures](../../godot/tests/test_physical_actor_rigs.gd)
require sustained motion and real relative joint motion. These are local
demonstrations and useful control baselines, not global route planners or a
neural/model service.

Desktop F5 selects physical actors in the sandbox, Blacksite Nine and all four
showcase districts. Applying or resetting an actor retires the old joint/body
graph and installs a new epoch for the selected reset. An initial terrain fence
keeps the assembly suspended until matching native acknowledgement and current
colliders are installed, even if Play was requested immediately. Physical
Thunderbowl v2 provides a separate synchronous native/Rapier manoeuvre lab;
sampled Thunderbowl v1 retains its own semantics.

## Ownership, capacities and usable boundary

Native C++ remains the only cellular authority. Rapier bodies and joints remain
main-thread owned. The existing transient body bridge increases from 16 to
**64 parts**, supporting at most eight eight-part actors; complete assemblies
are checked before spawning. Native validation rejects invalid IDs, serials,
nonfinite/invalid dimensions and masses before raster conversion. The body mask
and bounded response arrays preserve flattened part identity, including a
released held object.

The version-2 physical command binds run, actor, epoch, monotonic sequence and an
actually issued observation. Its lease expires from the observed simulation
tick. Cancellation clears armed charge, rope, temporary grip and pending action
without generating a charged release or erasing momentum. It invalidates issued
observations and signals the desktop worker to revoke that actor's queued and
already-copied effects before admission. Other actors keep their own authority.

Mounted Sand deposition, cutters, an off-centre recoiling launcher and articulated
held tools exercise aim limits, cooldown, clearance, recoil, release and bounded
reattachment. Rocketjumper requests a Fire centre/Gunpowder ring in permitted
empty cells. Native-world-owned effect consumption reports actual changes and
protects Wall, foreign body masks, world bounds and noneditable materials. The
effect ingress trusts the session's actor-to-body mapping; external policies
cannot supply coordinates or body IDs. Desktop effects are generated before a
Rapier step and may meet its subsequent body mask; the synchronous arena consumes
them before its step. That timing is explicit in the
[interface contract](../reference/interfaces-and-message-contracts.md#physical-actor-control-and-effects).

The usable substrate and authored tools do not establish a 32-item functional
inventory, general ballistic projectiles or arbitrary material processors. Generic
granular response remains with #83, reversible soliding with #12, and Water
successor acceptance remains independently gated.

## Review findings and repairs

| Finding | Repair and discriminating check |
|---|---|
| Pouncer fins and Skatesail hinges received zero deployment because an absent gait phase multiplied their targets by zero | Derive deployment orientation from outboard geometry or an explicit ±1 override; actual Rapier angle checks observe fin/sail deployment |
| Vector/Astra and Pulse/Luna travelled with almost rigid pod assemblies | Bounded gimbal motor demand follows movement/trim; every rig must now demonstrate meaningful relative rotary or slide motion |
| Vertical bouncing or a backward shove could falsely count as route progress | Signed route progress, intentional vertical-mechanism exceptions and a reset progress window on reversal; Runner must escape a real impassable wall |
| Floor-start Swinger paid out slack and could release during a tiny upward twitch | Ground-start attachment takes up slack until eight cells of lift, then resumes its pumping/release window; airborne release and Winchbug hauling retain their distinct behavior |
| Heavylift did not use its actual payload motion | Read connected payload pose/velocity, derive swing angle/rate and apply bounded acceleration reduction/correction; detached or invalid payload data falls back safely |
| Released objects could keep collision exemptions after cancellation or lease expiry | Advance passive collision-grace aging before authority admission; verify collision restoration against every other part and preserved velocity |
| A fresh post-cancel view retained stale charge, rope, grip and motor targets | Immediately republish cleared lifecycle state from existing physics samples, without stepping physics |
| Worker effects copied before cancellation could outlive their command | Session notification advances per-actor worker generations; integration checks both queued and already-copied requests and preserves another actor's requests |
| Immediate Play could step a new actor before hard terrain existed | Require matching native epoch/revision and an empty initial collider queue; integration checks stale epoch, queued terrain, unchanged pre-ready tick/pose and first admitted step |
| A new epoch or same-epoch map replacement could reuse cached old geometry within the terrain refresh interval, including equal revision numbers | Bind the cache to the physical epoch, refresh on full/reset publication and invalidate on scenario replacement; production-loop tests cover changed/equal revisions, ordinary reset and stopped-worker reuse |
| Faulted rigs could report an active lease and accept a command they would never execute | Preserve fault suspension, report zero lease, refuse `actor_fault`, stop issuing authority and cancel the actor's existing input/effects |
| A full pending effect queue silently dropped a suffix of new requests | Atomically admit or refuse the incoming batch; retain older queued work, publish copied counters/last outcome and keep actual-cell receipts separate |

Initial full-roster endurance exposed three real failures: effectively inert
Vector/Pulse pods and insufficient Swinger climb. Those initial failures are
preserved as failed local results; the successful consolidated rerun follows the
repairs above and retains the stronger acceptance checks.

## Local runtime and dependency identities

Fresh Linux and Windows extensions were built from the canonical native source
delta. The complete native-source SHA-256-map digest is
`95d1e03c5655906cb4cb35b506e69da4b1e63e7de7eddc1dda01cd8656c9571e`.
The changed production native inputs are:

| Input | SHA-256 of LF source bytes |
|---|---|
| `native/include/cybersand/world.hpp` | `f126bb6f74f912e5614f1998ec0efd7fd8375c3c19d120853718f45ac848f461` |
| `native/src/world.cpp` | `0a32fe69a6d2ff804ff053ac520a8138a7aaf89538d914b10a356dd9ce61d211` |
| `godot/native_extension/cyber_native_cell_world.hpp` | `0daa96c1fe0b8d40890914cbba4c7cc489b1113d166624cb4ec2090086c786f6` |
| `godot/native_extension/cyber_native_cell_world.cpp` | `0f4a88b43ebb1e3e281fa7a98f25aacc29f150fbdb2aacbf67216689d1d7e7f5` |

Pinned inputs were Godot `4.7.stable.official.5b4e0cb0f`, Rapier2D `0.35.2`,
godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, SCons `4.10.1`, GCC/G++
`13.3.0`, binutils `2.42`, and LLVM-MinGW `20260826` UCRT/Clang `23.1.0`.
The Godot ZIP SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`;
the MinGW archive SHA-256 is
`cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65`.

| Fresh local artifact | Bytes | SHA-256 | Scope |
|---|---:|---|---|
| Linux x86_64 extension | 2,116,384 | `1f53ebe4f7f944105c09b4b33d9185405ed88cfc75e867d7acdc275326852a1a` | Executed by the local Godot checks below |
| Windows x86_64 extension | 2,586,624 | `4336bba07c2984436420ddebecf087be7cc2b269dee2bb877b734c70df4e48a0` | Fresh cross-build and PE/import inspection; no Windows execution |

The Linux runtime-floor check passed: the extension requires at most GLIBC 2.32,
GLIBCXX 3.4.30 and CXXABI 1.3.9; retained Rapier raises the bundle GLIBC floor to
2.34. The Linux godot-cpp archive matches the retained historical archive hash;
this is not a claim of current application-runtime equality to M11.

An initial Godot import failed under the environment's inaccessible default XDG
locations and blocked editor loopback sockets. Successful imports used writable
scratch XDG locations and the approved execution context. A truncated old Godot
archive was rejected and replaced by the exact hash-verified pinned download.

## Executed local checks

Focused Godot commands use the pinned executable with
`--headless --path godot --script res://tests/<name>.gd`, with a 180-second
per-runner limit unless the hosted publisher states its separate 240-second
limit. They reject diagnostic errors as well as nonzero exit status. The fresh
native build above was installed before the consolidated runs.

| Check | Consolidated result and scope |
|---|---|
| `test_physical_actor_catalog.gd` | 5,538 assertions, zero failures; all 41 definitions and configured producers |
| `test_physical_actor_script.gd` | 57 assertions, zero failures; route progress, recovery, resource/charge, flight, rope and payload feedback |
| `test_physical_actor_actuation.gd` | 86 assertions, zero failures; real fin/gimbal motion, cancellation lifecycle and collision-grace restoration |
| `test_physical_actor_session.gd` | 109 assertions, zero failures; issued-view identity, producer/lease validation, consumed edges, fault refusal and cancellation |
| `test_physical_actor_effect_admission.gd` | 32 assertions, zero failures; actual mutex-owned queue saturation, atomic refusal, independent body publication, copied telemetry and lifecycle fences |
| `test_physical_actor_rigs.gd` | All 41 rigs × 1,200 ticks, zero failures; sustained progress, actual articulation, stability, endstops, energy and recovery; 16.114 seconds |
| `test_physical_actor_arena.gd` | 742 assertions, zero failures; all 41 × 240 native/Rapier ticks, actual travel/effects and eight largest assemblies totalling 56 parts; 7.437 seconds |
| `test_physical_actor_integration.gd` | 354 assertions, zero failures; every desktop selection, reset/ownership/terrain fence/cache identity, cancellation and 120 live ticks each for Vector, Jolt and Ripper; 14.251 seconds |
| Native capacity and effect fixtures | `test_act004_body_capacity.gd` and `test_physical_actor_effects.gd` passed with the fresh native runtime, including actual 64-part masks and fallback bounds |
| Complete discovered Godot suite | Import plus all 90 cases passed with zero diagnostic errors or timeouts; 802.775 seconds; all 269 implementation/test files match the frozen source commit |
| Fresh `make test` | Passed core native, soliding and world-generation suites and the C header check at the default 8 MiB stack; 71 core cases; 164.45 seconds |
| `make sanitize` with `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1` | Passed all 71 core cases; 134.4 seconds; establishes ASan/UBSan, not leak-freedom |
| `make thread-sanitize` | Passed all 71 core cases; 182.6 seconds including build/run; no race diagnostics |

The real rope fixture measured 24.47 cells of climb for Swinger, 28.17 for
Lineshank and 44.57 for Winchbug. Runner retreated approximately 60.69 cells from
the impassable-wall fixture. Both Vector/Pulse pod assemblies measured about
0.095 radians of joint motion, with about 0.001 cell peak anchor error in their
focused runs. Pouncer fins moved from +0.125/−0.125 to −0.425/+0.425 radians;
Skatesail hinges exceeded 0.5/0.4 radians. These fixture measurements describe
mechanism execution; they are not target-PC frame-time or subjective feel gates.

The first native run exposed an existing Stage3B parity fixture exceeding the
default 8 MiB stack: disassembly showed more than 10.3 MiB of local fixture
storage. That same executable passed with 64 MiB. The completion change moves
only the large test fixture owners to heap storage while retaining constructors
and all assertions. Its freshly compiled executable passed at the recorded
8,388,608-byte stack limit in 0.415 seconds, followed by the full passing native
suite at that default limit.
The first leak-enabled sanitizer run failed because LeakSanitizer could not
inspect `/proc` under process restrictions. The subsequent ASan/UBSan invocation
uses the repository CI's explicit no-leak-inspection policy; that environmental
failure remains distinct from the passing memory/undefined-behavior checks.
The sanitizer commands explicitly use a 64 MiB stack; the freshly compiled
storage fixture and full debug suite pass with the default 8 MiB stack.

The first full Godot pass exposed two historical async test-worker overrides
whose signatures lacked the new copied body epoch. Both helpers now forward that
value. The final discovered suite, including queue-admission coverage, passed
import and all 90 cases in 802.775 seconds. Its longest cases were WEX001 water-body
baseline at 129.396 seconds and microscenarios at 102.873 seconds, both within
their 180-second limits. Before/after comparison found no implementation/test or
Linux-runtime drift. All 269 implementation/test files map to frozen source
`d897cac257f90ff37b16ae5bc5c65de85c6465ee`; their SHA-256 ledger digest is
`c71a0a8fe58554ad118426d68e5c530c7a984182dde9a731aca7bb8413e77e66`.
All 37 native source inputs still match the local runtime builds. Import produced
only the new queue-admission test's untracked UID; it did not change tracked
bootstrap files or project configuration.

Documentation validation passes 90 canonical documents/170 claims with no
errors or warnings. Historical M11 integrity passes 18 retained records and 28
source hashes after materializing missing public Git objects. Frozen retrieval
routes hit all 32 canonical answers within the search bound; the challenge set
hits 68 of 69, with the existing C09 miss retained. All new ACT12–ACT15 routes
rank first. Retrieval ranks are not proof of answer correctness or a historical
quality-improvement claim.

## Publication and acceptance gates

The one-shot GitHub-hosted publisher was the immediate workflow-only child
`1d69b971fdacf524e1b56cb7fc836229e328b0ac` of the frozen implementation. Its
[publication run](https://github.com/techrote/cybersand/actions/runs/39174696657)
passed preflight, both pinned builds and publication. Linux passed 71 native core
tests, import and all thirteen scoped Godot runners, including the 354-assertion
integration fixture. Windows passed cross-build and PE/import inspection.

The published runtime commit
[`43bbe43e45f5885e563a67d781fba39726df34f8`](https://github.com/techrote/cybersand/commit/43bbe43e45f5885e563a67d781fba39726df34f8)
is the direct child of the installation commit. It changes exactly five paths:
the two LFS runtime payloads, their two provenance manifests and removal of the
publisher workflow. The unchanged branch lease and all frozen source bytes were
verified before its push. Both platforms record the same 37 native inputs and
53 build/test inputs.

| Published hosted artifact | Bytes | SHA-256 |
|---|---:|---|
| Linux x86_64 extension | 2,116,392 | `5bdc55e7f355004fc8a6468234b0d018d3919339ebfe47faca9997de3af17847` |
| Windows x86_64 extension | 2,586,624 | `ff417eaa63182818e5f924b9240a57868192da6cf629577f467dd9363105588d` |

The committed LFS pointers, manifests and hosted build logs agree on those hashes
and sizes. The materialized repository/provenance gate, Linux runtime floor and
LFS integrity check passed before publication. The hosted binaries differ from
the local builds tabulated above; local full-suite execution and hosted scoped
execution retain their respective runtime identities. The
[Linux manifest](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
and [Windows manifest](../../godot/addons/cybersand_native/runtime-provenance.json)
retain source maps, dependency pins, log hashes and explicit validation scopes.
Windows execution is absent from both local and hosted publication evidence.

Runtime publication is separate from ordinary ready-for-review Native,
GDExtension/Godot, Documentation/provenance and applicable scoped Water gates.
A draft skip or local pass is not exact-head hosted acceptance. PR #181 records
the final exact-head gate URLs and merge disposition before issue completion.
Windows interactive execution, Web actor migration, target-PC performance and
owner playfeel acceptance have not been performed by these local headless checks.
