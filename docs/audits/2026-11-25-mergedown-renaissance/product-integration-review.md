# Product integration review — MERGEDOWN-RENAISSANCE-001

Specialist A, 25 November 2026. This dated record supports the lead's integration
ledger. It does not grant merge authority or physical owner acceptance. The
machine-readable [product inventory](product-inventory.json) and
[advanced conflict map](advanced-conflict-map.json) retain the exact inputs.

## Source and ancestry

The intake accepted main was `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.
During this review the lead merged #736 and #758, producing accepted main
`be87b18b30506ccead610c7035ae1ffa8e65a347`.

| Candidate | Exact intake head | Ancestry and disposition |
| --- | --- | --- |
| #772 Goblin 001 | `d4484bd5b488cb419bfaa94f1e69be8128734405` | Ready; six applicable current PR workflows succeeded. Incorporates #778 as a genuine second parent. Authorised opt-in foundation; resulting-source gate remains separate. |
| #775 AMBIENT-001 | `d0af9b6015c27417fddd67f79afdcf656a609571` | Ready; seven applicable current PR workflows succeeded. Incorporates #778 as a genuine second parent. Authorised opt-in foundation; resulting-source gate remains separate. |
| #781 Goblin 002 | `36d82cae75e5fd8dad11646663248de8003f5bf9` | Exactly 23 commits ahead of #772, zero behind; merge base is d4484bd5. Draft/HOLD remains. |
| #779 AMBIENT-002 | `957190050ea6b32b47523234e508c7690a2abba9` | Exactly 24 commits ahead of #775, zero behind; targets the #775 branch. Draft/HOLD remains. |

Use ancestry-preserving merge commits for both foundations. After #775 lands,
retarget #779 to main and reconcile against the actual accepted main. Retargeting
does not qualify its resulting application or satisfy its owner's playfeel gate.
Goblin 002 retains four bounded long-horizon Linux timeouts; neither historical
evidence sealing nor a later documentation success changes those results.

The local diagnostic application is
`2a077fa9861b6be53ad41d85a350fe2f94b2b83d`. It joins the genuine #775 head,
infrastructure candidate `e85b1f73d5649158bc628834d169917d5d60ff16` and the genuine
#772 head, preserving all ancestry. The infrastructure candidate itself includes
accepted main be87b18b, #771 and #778. The only manual union resolution retained
both the four AMBIENT historical retrieval exclusions and #758's Gentek owner
acceptance exclusion. No production algorithm was changed. This local diagnostic
identity is not represented as accepted main or as a remotely qualified PR head.

## Foundation source and ownership review

Goblin 001 adds an alternate `godot/goblin/goblin.tscn`, developer scripts, tests,
launchers and qualification tooling. It changes no existing production Godot
script, main scene, project startup configuration or native input. Ordinary
startup cannot instantiate its controller, memory, fixtures or developer panel.

AMBIENT-001 modifies the ordinary actor host deliberately. Its pure decision
engine receives copied values and returns normalized actions through the existing
issued-observation, producer, generation, sequence and lease boundary. It never
receives a mutable native World, RID, Rapier space or body setter. Native cells,
physics, motors, equipment and the actor host's eight-slot capacity are unchanged.
The physical-session clock counts completed Rapier fixed steps; pause consumes no
ambient simulation time. Live profile preparation occurs before retiring the
current producer, and invalid configurations preserve the current owner.

Material perception is an immutable-publication consumer. It allocates its CPU
material image only for an enabled ambient policy with material requests. Epoch,
World generation, native revision, publication serial and freshness checks remain
separate from actor ticks. The editor and overlay are instantiated only through
explicit UI actions. There are no new native Worlds, native workers, network
calls or automatic policy activation in an ordinary non-ambient scene.

Small bounded idle bookkeeping remains: the session constructs pure adapters,
updates its completed-step clock and scans at most eight actor definitions in
existing callbacks. This is not a zero-allocation or zero-instruction claim.
Both product and adversarial source reviews identified this limitation and found
no material defect warranting a speculative refactor of the qualified foundation.
The expensive cache, native copying, spatial queries and actor decisions remain
gated by explicit opt-in.

Native code, GDExtension sources, committed runtimes and third-party pins are
byte-identical between AMBIENT head d0af9b60 and intake main. The diagnostic union
changes none of AMBIENT's production scripts or native inputs. Its additional
Goblin scene is isolated until explicitly launched. Reusing retained runtimes is
therefore a source-verified reuse, not a new native build or publication.

## Actual local qualification

The official Linux Godot archive was acquired through the pinned direct release
route. Its 75,664,355 bytes match SHA-256
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The extracted executable matches
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`
and reports `4.7.stable.official.5b4e0cb0f`. The system's different 4.7.2 executable
was not used for qualification. Native and Rapier LFS bytes were materialized and
checked against the unchanged manifests.

On exact original #775 d0af9b60, eight selected existing cases passed 2,222
assertions in 16.809 seconds: engine 877, independent 214, owner clock 21,
authoring save 242, fresh reopen 256, legacy catalogue 415, legacy session 84 and
legacy physical 113. Input custody passed. These are environment and original
foundation observations, not qualification of a later mainline source.
The [retained campaign](evidence/baseline-d0af9b60/qualification.json) preserves
its exact source, engine, runtime, process and per-case identities.

The independently authored [default-OFF probe](probes/default_off.gd) executed the
ordinary native Workbench at diagnostic union 2a077fa9 and passed **68 checks,
zero failures**, in a 6.331-second process. It installed Human, Scripted, External
Policy and Passive producers in one real native World and one actual Rapier
session. Before opt-in, 42 native and physical steps produced zero ambient cache
bytes, zero ingestions, zero query samples and no ambient editor or overlay.
Ordinary scripted commands and a valid externally submitted command remained
usable; passive and uncommanded external actors stayed without automatic drive.

Explicit ambient activation then witnessed an actual 524,288-byte material
publication and a real policy query. Disabling that authored profile and running
further native/physical steps released the cache and stopped further ingestions,
queries and actor commands. Human handback retained the worker, native World
generation, session and every physical body RID. An old ambient command refused;
a fresh human action remained admissible. The [original process result](evidence/default-off-2a077fa9/result.json),
[input identity](evidence/default-off-2a077fa9/identity.json) and
[independent-readable observation](evidence/default-off-2a077fa9/readback.json)
retain this scope. This is headless ownership/isolation evidence, not graphics,
physical Windows/NVIDIA acceptance, a performance benchmark or an all-feature
integration result.

The adversarial specialist independently reviewed all 68 checks and approved the
positive activation witness, continued native/Rapier progress, real external and
human command admission, stale-lease refusal and identity checks. The lead then
approved promotion into the reusable ordinary Godot regression
`test_ambient_default_off_integration.gd`. Isolated source change
`4789756ec6e9b0bb4808733fe4c0e7f5dfa3752c` contains that test and one conservative
30-second provisional cross-platform scheduling hint. It changes no production
behavior and no existing operation or complex-test timeout.

The [promoted exact-source result](evidence/default-off-4789756e/result.json)
passed **68 checks, zero failures**, in 6.439 seconds with before/after source,
native runtime and engine custody equality. Its process log SHA-256 is
`be131ba79cfd753f8cfe58f723f94731d0972ae9ecb4b12fcd72a4b8b12d7870`.
The planner discovers it exactly once: Linux 354 cases/25 shards and Windows
331 cases/24 shards on this diagnostic source. Planner tests passed 12/12;
sharding tests passed 92 with one existing skip. The standard 1.5 scheduling
margin yields a 45-second planning estimate; the detected existing complex
watchdog remains 3,940 seconds. This weight is not a measured Windows duration.
Cherry-pick the isolated test change onto the actual final #775 candidate, then
qualify that resulting source. Neither this diagnostic union nor this test run
is represented as a remote Ready campaign or owner acceptance.

## Advanced overlaps and integration requirements

Every dry run in the [machine map](advanced-conflict-map.json) tests one candidate
against diagnostic base 2a077fa9. Candidates were not indiscriminately combined.
A clean textual production merge says nothing about native runtime compatibility
or the owners' remaining gates.

| Candidate | Mechanical conflicts | Architectural next action |
| --- | --- | --- |
| #781 Goblin 002 | Documentation README | Preserve #772 ancestry, the 512/1024-action timeout evidence and default-OFF isolation. Resource and long-horizon completion remain limits. |
| #779 AMBIENT-002 | Retrieval corpus | Preserve #775 ancestry; retarget after its actual merge. Qualify group handoff, spatial memory and ordinary producers on the resulting source; keep the actual eight-actor limit. |
| #777 Architecture M6–M7 | Documentation README and roadmap | Preserve #720/#770 ancestry; native mutation remains serialized through the existing PAINT/history executor. Owner architecture preference and actual combined Art route remain distinct. |
| #780 Collaborative Art | Roadmap | Preserve the single Art provider/credential/audit owner. Implement the production host mount for Architecture; a fixture-level bridge is not that mount. |
| #776 Strata Theatre | Documentation README and retrieval corpus | Preserve four-plane ownership and the PAINT controller's sole Play receipt consumer. Retain the failed 45-second scene-admission target; reconcile PUBPRES later at its accepted source. |
| #754 ObjectShard M4 | Main and Shared Workbench process callbacks, plus ownership/build/roadmap/retrieval docs | Order body/native handoff, snapshot consumption, drawing and copied perception deliberately. Source changes require compatible rebuilt native runtimes. Owner physical/performance gate remains. |
| #762 Actor Compose | Physical session, Shared Workbench, actor panel | Preserve the single actor owner, live manipulation/lease suspension and AMBIENT data. Resolve optional population ceilings and sensing cost explicitly; rebuild/qualify native union. |
| #729 SWARM | GDE workflow, planner regression and docs | Preserve #778's scalable inventory/reducer guards alongside SWARM's source-specific routes. Reconcile native publication/CLI identities rather than choosing newer binaries. Owner populated-map acceptance remains. |
| #768 Material Audition | Shared Workbench demo-completion block and docs | Preserve both explicit demo routes, per-World profile identity, native-owner activation and configuration-only Revert. Native combined-source publication and owner gate remain. |

The common source owners are Main, SimulationWorker, Shared Workbench, actor
session/rig/catalogue/panel, authored setup and the PAINT controller. The map
records 32 shared production paths, including native headers, `world.cpp`,
GDExtension adapters and binary/provenance paths. Overlaps fall into different
classes: duplicate identical #778 CI repair; additive UI/demo code; conflicting
ownership/lifecycle transitions; optional capacity semantics; and incompatible
native binaries. They must not be treated as one text-resolution problem.

Actor Compose #762 exposes optional ceilings of 4,096 logical actors, bodies and
proxies while retaining default 8/64/64 budgets. AMBIENT's published perception
contract assumes eight actors and at most seven neighbours. Its producer loops
over all peers before the sensor truncates the copied list. Accepting the larger
host therefore requires a stated sensor admission/budget policy and measured
population behavior; a MAX_ACTORS conflict resolution alone is insufficient.
Manipulation additionally suspends producer drive and revokes commands. Tests
must establish that grab/release, pause, handback and profile replacement preserve
the intended ephemeral state and cannot revive a stale policy lease.

The final Art/Architecture handoff is concrete but still bounded: Art d503d824
supplies `bind_owner`, guarded `dispatch` and scoped `cancel`. The isolated
04ca3624 probe over Architecture 17c6b5b3 passed 115 Linux headless checks, two
real loopback HTTP exchanges, native stage receipts, Stop and exact Undo, with
zero ordinary Art paint consumers and zero genuine model inference. The five
Art closure files match the final Art evaluator source. The production host
configuration/UI mount and combined Windows qualification are not delivered by
that probe. Preserve Art's sole completion consumer and Architecture's fresh
preview/approval/StageSession authority when implementing that mount.

ObjectShard's source head changes native inputs but, relative to intake main,
does not change committed `godot/addons` runtime/provenance paths. Its independently
qualified evaluator remains valid at its own recorded source and runtime. A
mainline union needs its own runtime publication; unchanged mainline LFS pointers
cannot be relabelled as a rebuilt M4 application.

## Outstanding work and protected gates

Complete the sequential infrastructure wave, preserve the exact Goblin foundation
merge, then create and qualify the resulting AMBIENT candidate with the reusable
isolation regression. Re-run the meaningful combined paths after source movement;
original isolated passes are supporting evidence only. C owns the independent
final runtime review. Physical owner acceptance remains outstanding for both
newly integrated opt-in foundations even when their code is accepted on main.

Do not alter PUBPRES #767 or Docs ULTIMA #783. Main/actor/snapshot changes affect
PUBPRES's eventual union; its frozen comparison sources and negative results stay
unchanged. ULTIMA already carries the exact #778 donor and should receive the
new accepted-main identities through the lead's coordination record.

Keep advanced feature owner gates intact. Existing source-bound Windows packages
remain the owner queue until a coherent combined evaluator is separately built
and qualified. No public release, real-model trial or physical acceptance was
performed by this review.
