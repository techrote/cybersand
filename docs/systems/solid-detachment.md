---
title: Experimental native solid detachment and Rapier tree laboratory
status: Current
document-kind: contract
scope: Branch-local dry inert one-aggregate handoff, exact compound cellular coupling, session lifetime fences and scoped Linux/Windows Rapier proof; not production soliding
canonical-for: [solid-detachment-runtime, solid-detachment-lab]
last-reviewed: 2026-10-28
related-documents: [../operations/soliding-structural-detachment-programme.md, ../architecture/soliding-lifecycle.md, ../architecture/rigid-body-and-cellular-coupling.md, ../architecture/simulation-tick-and-threading.md, ../audits/2026-10-27-sol281-native-tree.md, ../audits/2026-10-27-sol281-compound-cellular-coupling.md, ../audits/2026-10-28-sol281-unresolved-cause-characterisation.md, ../audits/2026-10-28-sol281-ejection-search-preregistration.md, ../audits/2026-10-28-sol281-ejection-search-ab-result.md]
---

# Experimental native solid detachment

## Implemented scope and source identity

**Current on the implementation branch, not accepted production main.**
[Issue #281](https://github.com/techrote/cybersand/issues/281) has a bounded
actual-native-cell → live Rapier handoff and an inspectable tree-shaped fixture
in [draft PR #283](https://github.com/techrote/cybersand/pull/283), stacked on
[#282](https://github.com/techrote/cybersand/pull/282).

The initial native/Linux-Rapier proof remains tied to
`741bc0775c190be98e2f5d23da3d47dd354fef99` and its
[dated evidence](../audits/2026-10-27-sol281-native-tree.md).
The later session-lifetime repair and actual Windows engine qualification are
bound to **`4d40a59ef33ea9b24c9275dfe2dd7f0f90128913`**, tree
`9292a338bbf321e0f080aae410924e12fe34a6f3`, with a separate
[continuation receipt](../audits/sol281-2026-10-27/lifecycle-receipt.json).
That repair changes the GDScript session, adds a lifecycle test and a scoped
read-only qualification workflow; **native C++ and material laws are unchanged**.
Older missing-Windows statements in the first audit retain their historical
source scope; the current scoped platform result is below. The issue stays open.

The fixture starts as **real RedBrick native cells**, not a pre-authored body.
An actual trunk cut identifies 520 unsupported cells; those exact cells become
one native-owned aggregate, represented by six exact compound rectangles in a
new Rapier body. Main-thread gravity/contact generates rotation and horizontal
movement without scripted per-frame transforms. The cut stump, floor and nearby
control structure remain native. An intact tree refuses as `Anchored`.

This demonstrates the primary mechanical direction, not general reactive Wood,
bark/leaf cohesion or unrestricted terrain dynamics. No ordinary gameplay mode
or material policy automatically enables the feature.

## Newer experimental render microstage attribution — source d441a8a5

The opt-in diagnostic branch has a source-matched [render exchange and
copy attribution audit](../audits/2026-10-28-sol281-render-exchange-microstages.md)
and [machine receipt](../audits/sol281-2026-10-28/render-exchange-microstages-receipt.json).
The headless laboratory's unacknowledged render stream triggers two native
exchange calls on every sampled refresh; this is a **fixture-specific cost and
consumer-lifecycle limitation**, not accepted normal-render FPS or a change in
native ownership, mass, holes, material laws, or async worker/Rapier partition.
Scoped Linux and Windows hosts passed 1,414 assertions each on exact executable
source `d441a8a593f001d944d5f0691eab63d7614023c5`. The prior 289-probe B ejection candidate remains NO-GO;
safe material relocation and normal frame pacing are unqualified.

## Exact compound cellular coupling — source 41dc25ca

**Current on the implementation branch, not accepted production main.** Source
`41dc25ca060ecb07cef15c1640feeb9f6cce1eb4` reuses the existing native
rectangular rigid-body coupling for the detached aggregate without publishing a
filled tree bounding box. Each of the six exact non-overlapping geometry
rectangles becomes one stable native proxy record; all proxy observations are
reduced back to the single Rapier aggregate. Proxy mass sums to the exact 520
native members. The original one-cell crown opening and a larger empty region
inside the overall AABB remain unoccupied in native readback.

The main-thread session publishes every proxy's current and previous transform,
point velocity and a shared sample serial through the existing immutable body
state packet. The native owner performs its pre-existing swept occupancy,
ejection, contact, displacement and unresolved accounting per proxy. Copied
results are combined into one linear impulse, angular impulse and bounded
position correction for the actual Rapier body. A result with an old sample
serial is refused; activation remains frozen until the first proxy publication
is acknowledged. This adds no per-cell Rapier bodies and no second cellular
integrator.

`godot/tests/test_solid_detachment_coupling.gd` exercises actual Sand and Water
around the moving compound structure. On both hosted Linux and Windows, all 32
checks pass: crown/trunk samples are occupied, both declared holes are empty,
Sand is supported/displaced by the moving crown, Water traverses the open region,
material quantities remain conserved, proxy count equals shape count, and
contact/displacement feedback reaches the single body. The exact-source
[evidence record](../audits/2026-10-27-sol281-compound-cellular-coupling.md)
contains platform counters, hashes and limitations.

Source `756ae4882d346a1439244189c76eda8496070229` appends three diagnostic-only cause counters after the
original nine result fields, preserving every previous offset. Native and
fallback protocol cases pass 43 checks per host; the compound fixture now passes
36 checks per host. The [exact-source cause record](../audits/2026-10-28-sol281-unresolved-cause-characterisation.md)
contains the partition, artifacts and limitations.

In run 40611249935, every live unresolved attempt was an exhausted bounded ejection
search: **1,557/1,557 on Linux and 1,501/1,501 on Windows**. Immovable,
relocation-refused and unclassified counts were zero. Successful displacements
were 35 and 40 respectively, giving attempt-level unresolved proportions of
97.8015% and 97.4043%. These are cumulative repeated attempts under async pacing,
not unique cells or deterministic cross-run totals. No ejection rule changed.
The result proves cause attribution, not acceptable production resolution rate,
performance tuning or universal material coupling.

## Diagnostic-only bounded search A/B — unqualified candidate

A preregistered [2026-10-28 ejection-search experiment](../audits/2026-10-28-sol281-ejection-search-preregistration.md)
retains the baseline nine-distance by nine-tangent (81-candidate) search
**unaltered as the default**. An explicit diagnostic construction argument
`{"ejection_policy":1}` selects an additional deterministic bounded
208-candidate tail **only after all baseline candidates have failed**.
The native `get_ejection_policy()` returns the applied selector, and
the fallback diagnostic value is `body_ejection_policy`. The ordinary
demo-world reset selects 0. This is not a live config, regular-gameplay
setting, inherited liquid parameter, persisted aggregate schema or permission
to alter authoritative cell ownership. Actual scoped [Linux/Windows source-matched A/B evidence](../audits/2026-10-28-sol281-ejection-search-ab-result.md)
at `2d623e1034075f26b5443997781a267f16eeee85` passed test integrity
but **failed the preregistered 20 percentage-point reduction threshold**:
only 0.4302 pp on Linux and 0.6119 pp on Windows. Policy B is a negative,
unpromoted diagnostic candidate. The measured p95 main-thread step alone
does not qualify native worker cost or frame pacing; independent review
and full ordinary CI remain open.

The opt-in experiment uses the same empty-target, hole/foreign-mask
and hard-contact path checks, and it preserves the same exact relocation
commit/refusal, reaction impulse and copied result ABI. The controlled
native/fallback diagnostic cases and actual paired six-proxy Rapier fixtures
are distinct acceptance gates. Any future recorded measurements must bind
an executed source SHA, runtime hash, platform and sample count. Unresolved
events are counted as attempts, not unique cells. Nothing in this experiment
admits reactive Wood, aggregate fracture or production soliding.

## Native owner, shape and transaction contract

Implementation: `native/include/cybersand/solid_detachment.hpp`,
`native/src/world_solid_detachment.inc`, and the guarded methods in
`native/include/cybersand/world.hpp` / `native/src/world.cpp`.

| Boundary | Implemented limit or meaning |
|---|---|
| Activation | Explicit `World::configure_solid_detachment`; disabled with no store allocation otherwise |
| Aggregate count | One experimental aggregate per configured World |
| Discovery domain | At most 64×64 resident cells; no implicit chunk creation |
| Payload | At most 1,024 exact material/state-A/state-B/temperature members |
| Shapes | At most 256 exact rectangles; default admission limit 128 |
| Material eligibility | Homogeneous ambient-temperature Wall or RedBrick; pressure/inertial Worlds refused |
| Support | Explicit anchor rectangle, face-connected candidate, closed local boundary; unknown/excluded scope refuses |
| Geometry | Exact non-overlapping horizontal runs with identical-span vertical merging; holes are not filled |
| Mass/inertia | Homogeneous unit-cell masses, derived COM and summed unit-square moment of inertia |
| Identity | Nonwrapping World incarnation + transaction sequence; body generation and terrain revision bound to receipt |
| Serialization | An outstanding or active aggregate explicitly refuses existing physical-state save/hash formats that would omit its payload |

`Prepared` and `Acknowledged` copies are **evidence**, not a second material
owner. Cells stay authoritative until all member/source checks pass.
`Committed` moves payload ownership into the native aggregate store and retires
source cells. `Active` is reached only after a main-thread collision receipt
matches the current committed terrain revision and body identity.

While Prepared/Acknowledged/Committed/Restored/Quarantined, ordinary native
mutation and ticking are fenced. Read-only material/render/terrain extraction
remains available to complete collision repair. Admission reserves revision
headroom for both commit and an inactive-body rollback. A rollback returns cells
but remains fenced until static-terrain repair is acknowledged. Unexpected
partial failure preserves diagnostic ownership accounting and quarantines the
World; it does not silently retry or activate a body.

**Native receipts alone are not proof of a live RID.** The native tests use
synthetic receipts to check native invariants. The separate real-host tests
construct and inspect actual Rapier bodies/shapes and exercise the same protocol.

## Existing asynchronous host and collision handoff

`godot/native_extension/solid_detachment_adapter.inc` exposes only copied typed
values through a **diagnostic-only** facade. Tokens/digests/revisions use exact
decimal strings rather than lossy floating-point identifiers.

`godot/scripts/solid_detachment_worker.gd` subclasses the existing
`CyberSimulationWorker`, reusing its pacing loop, native World and snapshot
exchange. The shared worker recognizes a representation fence so ordinary
paused-loop configuration and body-mask refresh cannot mutate a staged source.
The special lane introduces no alternate cellular integrator or second native
clock. Main-thread consumers never read its live native World after thread start.

`godot/scripts/solid_detachment_session.gd` owns the main-thread sequence:

1. Perform the actual native cut and acquire an exact prepared payload.
2. Construct a frozen, noncolliding `RigidBody2D` and exact rectangle shapes.
3. Acknowledge those reserved objects; commit native source retirement.
4. Install the copied post-commit static terrain through the existing
   `CyberRapierPhysicsBridge` and finish its pending collider work.
5. Activate the compound body while physics stepping remains held; finalize
   the exact terrain/body receipt on the native owner.
6. Resume independently paced cells and ordinary main-thread Rapier stepping.

No Rapier step is permitted during a partial handoff. Failed final receipts can
restore the native source and static collision while the body remains inactive.
Session teardown joins the native owner before retiring its Rapier space/body;
old transaction tokens cannot revive a new session's payload.

## Session replacement and awaited-continuation ownership

**Current on source 4d40a59e:** native transaction tokens do not alone protect a
GDScript coroutine that resumes after `close()`/`open()` has replaced its owner.
Each awaited configure, body preparation, acknowledge, commit, cancel, finalize,
rollback, rollback-repair and inspection continuation now validates **both the
captured session generation and exact worker identity** before touching shared
session state or issuing another command.

Command polling retains the original worker and SceneTree. A retired command
returns `SessionRetired` without releasing a newer request's lock. Body creation
also retains the exact body/viewport across its frame yield. Local reply values
are assigned to shared receipts only after lifetime validation. Inspection cannot
restore the old pause state onto a new owner. Full close clears copied payload,
source/commit/final receipts and operation flags; request serials remain monotonic.
An overlapping release is refused throughout the whole release operation,
including the body-creation frame yield. Failure pauses the actual worker frame
state as well as main-thread physics. None of this adds material coupling.

**Retained negative:** a deterministic continuation barrier after a real native
inspection reply, followed by a real owner replacement, failed two assertions on
the original session source: the old inspection unpaused the replacement and
returned an accepted stale result. This is a test-controlled interleaving, not a
claim about its frequency in normal play. The before/after log hashes and original
session blob are retained in the continuation receipt.

`godot/tests/test_solid_detachment_lifecycle.gd` performs **18 actual host
replacement cycles / 296 checks** at nine boundaries with configured worker
counts 1 and 4. These use real native Worlds, actual Rapier resources and real
replies; a test subclass controls only the continuation barrier. Each replacement
must remain intact/healthy and then successfully detach its own tree. The normal
Godot test discovery includes this new suite automatically; it is not only a
one-off CI test.

## Source-qualified continuation results — 2026-10-27

[Scoped run 40597011137](https://github.com/techrote/cybersand/actions/runs/40597011137)
checks out exact source **4d40a59e**, builds an experimental Windows DLL with
pinned LLVM-MinGW 20260826/Clang 23.1.0 and godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, then actually executes on
**Windows Server 2022 x86_64** with Godot 4.7 and Rapier2D 0.35.2.
This is now **Windows Godot/Rapier execution**, not only a C++ cross-build.

| Suite | Actual Windows hosted result | Actual Linux local result |
|---|---|---|
| Native-to-Rapier motion, 600 physics steps | 21 checks, zero failures | 21 checks, zero failures |
| Inactive rollback, collision repair and reset | 20 checks, zero failures | 20 checks, zero failures |
| Awaited-session replacement | 296 checks, 18 cycles, zero failures | 296 checks, 18 cycles, zero failures; two fresh processes |
| Focused native ownership | Previous 741bc077 Windows result retained, not rerun by this workflow | Fresh 8 groups / 13,074 checks, zero failures |

The Windows DLL SHA-256 is
`bf8e79d1d82a17562a7a2e30914027f75dc1a0e41569ea87eef7fecdf48d0004`.
All **546 declared native/adapter/script/test/build-script inputs** matched the
build manifest and canonical Git bytes before execution and were rechecked after.
Windows checkout changed line endings on 92 files: the harness first verifies
the authenticated Git blob matches the build hash, permits only a pure line-ending
difference, restores those exact Git bytes and then repeats byte-exact checks.
It does not accept arbitrary drift or weaken source equality.

The prior [run 40595407030](https://github.com/techrote/cybersand/actions/runs/40595407030)
built successfully but **failed before Godot execution** at the source check for
`generation_grammar_adapter.inc`; that failure remains preserved. The corrected
build and execution archives were downloaded, ZIP hashes/CRCs checked, and every
reported execution-log hash, exit code and required result revalidated.
Artifact IDs, expiry dates and SHA-256 identities are in the continuation receipt.

The local Linux continuation uses a freshly compiled **GCC14.2 experimental
runtime with the explicit toolchain-drift override**. It is supplementary actual
engine proof, not a new pinned Linux release publication. Its runtime hash remains
`73d667f0a2c21d5ab3d9db37b66257bd006d35d10d857e65aae6c5beced21c0a`.
Recorded Windows/Linux motion samples and extrema match for this fixture;
that is not proof of universal cross-platform replay or identical frame timing.
Neither these scoped tests nor a draft documentation green replaces independent
review, the full ready-PR matrices, formal runtime publication or owner feel.

## Dry-fixture limitations that must remain visible

**Not implemented/admitted:** reactive aggregate Wood/heat/chemistry;
mixed-material bonds; arbitrary fracture; rotated dynamic desoliding; aggregate
saves/streaming; multiple simultaneous aggregates; full normal-app admission;
formal source-matched release runtime publication and Web support.

The current compound coupling is deliberately one dry homogeneous aggregate and
six exact rectangular proxies. It proves holes, Sand/Water contact and quantity
conservation in a registered fixture, but not arbitrary contour decomposition,
zero unresolved interactions, deep-liquid pressure behaviour, all granular
materials, multiple aggregates or representative production cost. Proxy-level
feedback is reduced into one body; it is not yet an independently qualified
general compound-body interface for every actor. The opt-in native feature does
not itself prevent a future caller from constructing unsupported surrounding
material; the diagnostic host and workload boundary remain part of qualification.

`rollback_solid_detachment` is only cancellation of an **inactive staged body**.
It is not safe arbitrary body-to-cells desoliding. An activated body remains an
aggregate and may sleep in Rapier. No automatic weld-back claim follows.

## Running the inspected laboratory

Use a native extension built from the **same implementation source**. The
unchanged checked-in main/runtime libraries do not expose this branch's new API;
the laboratory fails rather than substituting GDScript or a prefab.

After the pinned build procedure in
[local build and validation](../operations/local-build-and-validation.md):

```text
godot --path godot res://solid_detachment_lab.tscn
```

**Space:** cut the real trunk and request detachment. **P:** pause/resume.
**R:** join/close and rebuild the complete session. **Escape:** exit.
The display identifies native tick, Rapier tick, angle and the dry inert scope.
Static pixels are drawn from copied native render snapshots; the moving payload
is the exact original member set transformed by actual Rapier state.

The authored clear-fall fixture places its unrelated control tree to the left;
a retained earlier right-side-neighbour fixture blocked further toppling. That
negative is documented, not erased or relabelled as successful free motion.

## Reproducible validation and acceptance limits

```text
make solid-detachment-test
make solid-detachment-sanitize
godot --headless --path godot --editor --import --quit
godot --headless --path godot --script res://tests/test_solid_detachment.gd -- /absolute/path/rapier.json
godot --headless --path godot --script res://tests/test_solid_detachment_failures.gd
godot --headless --path godot --script res://tests/test_solid_detachment_lifecycle.gd
godot --headless --path godot --script res://tests/test_solid_detachment_coupling.gd -- /absolute/path/coupling.json
```

The native executable is integrated into `soliding-test`. Its allocation-failure
control, capacity/unknown/thermal/mask/event/exclusion refusals, exact payload and
shape coverage, source ABA, revision exhaustion, reset and configured workers
1/4 checks do not establish general threaded performance or body physics.
The three Godot suites separately exercise actual async native transfer, real
Rapier motion, source/contact fences, inactive rollback and session replacement.
Numerical pass is not owner feel approval. No independent review or full release
gate is claimed by this page; consult the source-qualified receipts before using
any result. #281 and parent #12 remain open.

## Observational topology census at executed source dabe2b30

The [separately preregistered no-target topology census](../audits/2026-10-28-sol281-ejection-topology-census.md)
is an **opt-in, native-owner diagnostic** on draft PR #283, not a new ejection
policy. Fresh diagnostic construction accepts the boolean
`{"ejection_topology":true}`, default false, with a strict 17×17 local
stored-Empty/unmasked scan after a bounded ejection search has already
failed. Only the first 16 failed searches per owner preparation are
classified; later events remain explicit capacity skips. Ordinary demo reset
disables the probe; 12-float result records and the original 81-candidate
default stay unchanged.

On exact source `dabe2b30966e952ebadb84ab7f482d49ca500bb9`, the scoped
Linux/Windows actual-host tests each pass 943 checks. Of 7,257 cumulative
failed native-owner ejection attempts across four A/B runs, **7,256** had a
nearby empty/unmasked void reachable under the **permissive** existing
straight-path test, and one had only blocked direct paths. There were no
capacity skips and no local no-void cases. Such a path can cross movable
material or head **behind** the outward normal: this proves neither
physical admissibility nor a viable new displacement strategy.

The [source and cadence audit](../audits/2026-10-28-sol281-ejection-topology-census.md)
records 549/549 matched build-input hashes, actual native/Rapier conservation
and hole tests, and sampled worker costs. Linux snapshot-publication copy
p95 was approximately 51 ms and worker overrun counters 88/111 in this
headless fixture, an unresolved full-loop performance gate. **B remains
NO-GO** under its prior preregistered efficacy criterion; neither this
census nor passing scoped tests promotes production soliding.

## Strict empty-only local route diagnostic: newer experimental source

On [frozen preregistration 2026-10-28](https://github.com/techrote/cybersand/pull/283#issuecomment-6466395909), the follow-up executable source `b68074d715e04f3a2e37613239d5322fd1f3d1ee` added an **independent, non-mutating** native-owner classification to the existing opt-in `ejection_topology` census. The current controlled-fixture repair head is `ecacca3e701489d58a13793c038968d36f16bb03`. These are experimental PR sources, **not accepted production main**.

For the first **16** no-target contacts in an owner preparation, a fixed-size **17×17** scan uses four-connected, stored-`Empty` and **all-transient-masks-absent** cells, starting at an adjacent empty cell. The 289-slot stack arrays (visited flags and queue) have no tick-time heap allocation. A visited void is classified using the **actual contact outward normal**; the event bins are exclusive under forward > lateral > rear > none. The copied diagnostic values are `empty_connected_forward`, `empty_connected_lateral`, `empty_connected_rear`, `empty_connected_none` and the cross-category `weak_direct_without_empty_route`. The earlier three permissive bins and capacity accounting are retained independently; both bin partitions must equal `classified`. This addition does **not** change displacement search/target/commit, ownership, world state, 12-field body-result ABI, masks, aggregate bodies, liquid policy or Rapier timing/ownership.

**Interpretation limit:** even an empty-connected forward void does not establish a safe continuous trajectory or a mass-conserving material chain: it may be reached only via a winding lateral detour. A `none` result establishes no *local four-connected empty-only* escape inside radius 8, not global confinement. The soft-crossing permissive path is deliberately not a relocation permit.

An initial actual Linux scoped execution at [run 40671639353](https://github.com/techrote/cybersand/actions/runs/40671639353) found **controlled test errors**: the test read masked public occupancy rather than the stored native snapshot under an active proxy, and a rear test void opened into a lateral region. Those negative results remain recorded. Repairs `a37df69f`, `e09c497b` and `ecacca3e` correct fixture isolation and read back stored authority. The [repaired-source Linux/Windows actual-host qualification run](https://github.com/techrote/cybersand/actions/runs/40672040365) must pass and have its logs and runtime/source identity independently checked before any qualification assertion. **At this documentation checkpoint it is pending, not passed**. See the [dated audit addendum](../audits/2026-10-28-sol281-ejection-topology-census.md). The prior 289-candidate search policy B remains **NO-GO**; full worker/publication cost, physically safe movement, reactive materials, fracture/desoliding, persistence, normal gameplay and final PR gates remain open.

## Source-qualified empty-only route result — 2026-10-28, *scoped diagnostic only*

A later [fully executed Linux/Windows actual-host run 40672040365](https://github.com/techrote/cybersand/actions/runs/40672040365) **passed all four scoped jobs** for the repaired executable source `ecacca3e701489d58a13793c038968d36f16bb03` / Git tree `94842a127df278655eb049383c52b7e61036a5b1`. Both OS targets passed **1,394 checks each**, including 924 controlled topology/ejection assertions, 45 checks per real six-proxy compound A/B host, motion/failure/lifecycle/diagnostic checks, exact Sand and Water conservation and stable result ABI. Independently rehashed source archive: **549/549 manifest inputs match** the exact source; Linux and Windows runtime identities and verified ZIP/report/check log hashes are in the [machine-readable qualification receipt](../audits/sol281-2026-10-28/strict-empty-route-receipt.json).

| Executed host | Native no-target events | Strict four-neighbour Empty path **absent** | Strict forward | Strict lateral | Strict rear |
|---|---:|---:|---:|---:|---:|
| Linux A (81 probes) | 2,247 | 2,247 | 0 | 0 | 0 |
| Linux B (289 probes, opt-in) | 773 | 772 | 0 | 1 | 0 |
| Windows A (81 probes) | 3,486 | 3,296 | 1 | 0 | 189 |
| Windows B (289 probes, opt-in) | 1,578 | 1,577 | 0 | 0 | 1 |

Across the **four distinct asynchronous samples**, 7,892 of 8,084 failed-search events had no locally connected stored-Empty/unmasked route, while 7,891 still appeared to have a *permissive* straight route. This strongly rejects the naive idea that almost every nearby visible void is a usable direct ejection destination; it **does not demonstrate** that an empty-only route is necessary for every physically safe *material-shifting* displacement. Sampling and async trajectories differ across platforms and policies; these totals are descriptive, not a paired efficacy comparison.

**Still unresolved:** Linux `snapshot_copy_time_ms` p95 was ~40.2 ms with 66/73 worker overruns (A/B); Windows ~13.9 ms with 0/0 overruns. Source inspection shows this timer ends **before** the entire snapshot object is assembled: it measures worker render/terrain preparation, not complete worker-loop publication or interactive frame cost. Headless physics-frame p95 was ~20.7 ms across arms. These are **not** a 60 FPS production qualification. The earlier 289-probe policy B remains NO-GO and is not promoted; physically admissible, bounded, conservative chain movement and end-to-end publication/pacing require separate preregistration, rigorous source-matched experiments and independent review. Keep #281 open and PR #283 draft.

## Experimental worker publication-stage timing — not yet qualified

The [2026-10-28 preregistered observational timing candidate](https://github.com/techrote/cybersand/pull/283#issuecomment-6466960679) adds copied scalar fields `snapshot_assembly_time_ms` and `snapshot_publish_total_time_ms` to `CyberSimulationSnapshot`, alongside the existing unmodified `snapshot_copy_time_ms`. The base worker samples (a) existing render/terrain preparation to the pre-assembly point, (b) snapshot object/copy/metadata assembly to just before publication, and (c) total preparation from entry to just before publication. Shared latest-only conformance reports all three distributions and rejects non-finite, negative or non-monotonic samples. **This paragraph is a source implementation description, not a tested runtime result.**

The total deliberately **excludes the final mutex handoff, derived SOL281 reply, worker sleep/scheduling, main-thread Rapier/render and interactive frame time**. It is not true end-to-end worker-loop or 60 FPS acceptance. Previous Linux ~40 ms render/terrain p95 and the B=289 physical search NO-GO stand as historical results. The new candidate must pass exact-source Linux/Windows Godot/Rapier CI and runtime artifact checks before any numbers or assurance are promoted. Reactive Wood, dynamic rest/desoliding, multiple aggregates, persistence, production policy and formal review remain open.

## Source-qualified snapshot preparation timing — 2026-10-28, scoped only

The *subsequent* [exact-source `9c97dc09` Linux/Windows Godot/Rapier run](https://github.com/techrote/cybersand/actions/runs/40675020082) passed **all four scoped jobs and 1,400 assertions per platform**, including the 48-check-per-policy exact compound Sand/Water fixtures. Native C++ adds 13,074 focused Linux checks. The [preregistered snapshot stage implementation](https://github.com/techrote/cybersand/pull/283#issuecomment-6466960679) passed zero-invalid-sample, same sample-count and pre-mutex-total monotonicity checks. The new pre-mutex publication preparation p95 was Linux **52.378/52.407 ms**, Windows **22.845/23.161 ms** across diagnostic A/B moving-tree hosts; assembly only **0.291/0.280 ms** and **0.270/0.267 ms**. See [complete dated addendum](../audits/2026-10-28-sol281-ejection-topology-census.md#addendum--preregistered-snapshot-publication-stage-attribution-source-9c97dc09-2026-10-28) and [machine receipt](../audits/sol281-2026-10-28/snapshot-publication-stages-receipt.json) for all counts and source/runtime ZIP hashes.

This is a **negative frame-cost concern** and a finer measurement boundary, not an optimization or production frame-rate acceptance: the timing **still excludes** worker sleep/scheduling, final snapshot mutex handoff, the specialized worker's reply, main-thread Rapier/render, and interactive frame delivery. The source-matched Windows build manifest's 549 paths and eight host log hashes were separately verified; default liquid/physics and no-target ejection behavior did not change. Diagnostic B remains a prior NO-GO. Full ready-PR, physical relocation, reactive Wood, fracture/desoliding, persistence and independent review remain open.

## Source-qualified worker render versus terrain attribution — 2026-10-28

The [independently archived `9725885d` source-matched real Linux/Windows run](https://github.com/techrote/cybersand/actions/runs/40694663350) passes four scoped jobs and **1,406 assertions on each OS** (51 real compound assertions for each 81-probe A and diagnostic-only 289-probe B). New worker-only immutable scalar stage timings partition the existing pre-assembly `snapshot_copy_time_ms` into render/patch preparation and hard-surface preparation; branch flags distinguish refresh calls from idle publications. No physics or policy changed.

Across the A/B fixture histories, render-stage p95 is **30.751/31.154 ms Linux** and **24.420/24.437 ms Windows**, while the hard-surface stage p95 is only **0.001–0.002 ms**; there are **zero hard-surface refresh branches** in the sampled moving-tree windows. This identifies the expensive *render-stage boundary*, **not** an individual memcpy or native source cost. [Dedicated dated audit](../audits/2026-10-28-sol281-render-terrain-stage-attribution.md) and [SHA-verified execution receipt](../audits/sol281-2026-10-28/render-terrain-stage-receipt.json) retain all exact source, artifact, platform and prior red-run details. In particular, the initial `39aa2e4d` run **failed** because its workflow still asserted 48 rather than 51 despite zero failures from the expanded host tests; `9725885d` fixed only that harness contract.

The existing pre-mutex total, final mutex handoff, native tick loop, main-thread Rapier/render and true interactive frame pacing remain distinct; **no 60 FPS result or material-conserving new ejection behavior** is established. The 289-probe B efficacy experiment stays **NO-GO**. #281 open, #283 draft, no independent/full ready-PR admission.
