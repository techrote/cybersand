---
title: ObjectShard M0–M2 implementation and qualification
status: Planned
document-kind: research
scope: Implemented Draft/HOLD branch candidate with separately identified source and runtime evidence; not accepted main, fracture, persistence or owner physical acceptance
canonical-for: [objectshard-runtime, objectshard-ownership, objectshard-qualification]
last-reviewed: 2026-11-22
related-documents: [../operations/objectshard-lab-playtest.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/materials-and-rule-kernels.md]
---

# OBJECTSHARD-001 — compact moving material domains

**001R finisher qualified as a Draft/HOLD evaluation candidate, 22 November 2026.**
The [final finisher record](../audits/2026-11-22-objectshard-001r-final-qualification.md)
binds native/host source `514d76fb...`, corrected Windows package source
`28be5a4a...`, actual Linux/Windows qualification, independent review and the
verified delivered ZIP. It repairs component-admission starvation, late
resting-body rotation, repeated-edit ownership, bounded motion progression and
diagnostic/capture deficiencies. Ordinary Workbench defaults are unchanged.

The [forensic checkpoint](../audits/2026-11-22-objectshard-001r-forensics.md)
preserves the original owner exports and controlled negative results. The
[implementation checkpoint](../audits/2026-11-22-objectshard-001r-repairs.md)
explains resumable component census, size/age admission, source-owned moving
cuts, native-applied Rapier segments and one-opportunity external Fire contact.
The [native performance record](../audits/2026-11-22-objectshard-001r-native-performance.md)
retains the original M2 10/74 timing failures and the repaired finisher's earlier
14/74 memory failures. Final same-host source passes 74/74; no general frame-rate
improvement is claimed. M3 executable preparation and owner physical acceptance
remain separately qualified gates.

Status: M0–M2 implemented and delivered as staged Draft/HOLD research, with an
exact-source Windows evaluator. The [final acceptance record](../audits/2026-11-22-objectshard-final-acceptance.md)
distinguishes passing platform qualification, the retained native timing failure,
and outstanding owner physical acceptance. No production default changes, merge,
Ready promotion or release occurred. The implemented slice is chemically active,
mutable, nonfracturing rigid aggregates with bounded material exchange.

## Source and ownership

Fresh implementation base: `30e1cddd3d678456df10f52f7a2fb2210a9daaad`.
This is accepted main after CI-only #722. Its native/Godot production inputs
match the planning baseline `846fe0533b3170e7b01f690518da49fc40cc24d1`.

Donors #347 (`1598115c9065239cc1eaec11e99077274b457be1`), #283
(`254235ec4c3d58782bba44b478caca86bf57c856`) and #393
(`e4c2649e82d943554f4dc6a0634336770cda08f6`) remain historical evidence.
No donor branch was merged or copied over current shared files. The historical
520-cell RedBrick tree proved motion, not continuing chemistry. Its later
supported-Sand clearance failures remain failures under their original criteria.

Protected concurrent branches: SWARM #715/#716, CI #718, PUBPRES #719 and
`exp/gen006-persistent-areas-001-20261121`. The new Lab has its own facade,
scene, session and Rapier adapter; it does not modify their worker/rendering
or persistence implementations. Ordinary native Water remains opt-in for
Wave/ballistic; ordinary Godot gameplay keeps its existing Wave/spill/ballistic
selection. This independent bounded Lab explicitly selects SerialInPlace.

Accepted CI-only main `662df51cd8409a52332fa7ef15d06d8ab8945aed` was reconciled
into the M0 branch without changing the production material inputs. The staged
ancestry is [M0 #726](https://github.com/techrote/cybersand/pull/726), head
`28fa42a5ad05d49fee96d1bba7252aaf36abf331`, then
[M1 #728](https://github.com/techrote/cybersand/pull/728), head
`1b85782a15565bad7e4dae28755b17d630daaf46`, then the M2 child branch
`experiment/objectshard-001-m2-20261122`. Each stage is Draft/HOLD. No branch
has been merged or promoted Ready. The final M2 qualification receipt must name
its own exact commit; the earlier stage hashes do not qualify later changes.

## Executable stage boundaries

| Stage | Behavior | Recorded qualification boundary |
| --- | --- | --- |
| M0 | Compact inventory, ordinary-mutation discovery, exact promotion, actual collider switch and Rapier motion | Native and actual Linux iteration executed; independent scoped review passed |
| M1 | Shared combustion, material products, mutable geometry and sleeping-body chemistry | Native scheduler and actual Linux Rapier Lab executed; exact results below |
| M2 | Authentic output, physical Sand lodging, historical Water exposure, Windows evaluator | Implemented in the M2 child; final source-bound Linux/Windows campaign recorded separately from local iteration |

## Native contract

`object_shard.hpp/.cpp` owns bounded row-major storage by bounding-box area,
structural/product/cargo roles, cell incarnations and deadlines, exact rectangle
geometry, connectivity and declared unit-cell mass properties. The local lattice
origin never changes as material erodes. Products do not create rigid shapes;
cargo contributes declared mass separately from cohesion.

`object_shard_coordinator.hpp/.cpp` is one exclusive owner for World and the
registry. The first implementation runs synchronously under the isolated Lab
owner; it creates no per-shard World or worker thread. Godot main alone owns RIDs
and manually steps an inactive private Rapier space.

`object_shard_mutation.hpp` is one bounded opt-in Lab journal, not one World
field per shard. Ordinary writes, movement, thermal/state changes and merged
worker reports update payload witnesses. Material changes also enqueue deduped
topology seeds. Full components either fit the discovery/storage bounds or are
refused; one erase can discover multiple disconnected components. Wood and
RedBrick cohere only with their own material; Wall is an explicit scenery anchor.
Sand adjacency is not a bond.

Promotion closes Lab mutation admission and pauses both semantic and physics
clocks. It captures exact payloads and witnesses after a healthy returned tick;
main reserves a real frozen body; native commits; main installs exact affected
terrain chunks and returns content receipts; native applies occupancy; main
activates the body and acknowledges activation. Chemistry cannot run at
`ReadyToActivate`. A queued terrain update is never an installed-content receipt.

Before commit, cancellation preserves World inventory. After unexpected partial
progress, only actually debited cells belong to the quarantined shard; undebited
cells remain World-owned. Transaction sequences never restart on reset. Detailed
receipt eviction never authorizes replay. Control receipts have reserved storage
independent of product carriers.

Geometry uses independently bounded exact rectangle covers rather than an
eight-shape assumption. Revision receipts bind occupied geometry and mass/COM/
inertia carrier identity. Disconnected islands will remain an explicitly
nonfracturing compound with `split_pending`; this is not fracture simulation.

## Shared chemistry seam

`material_lifecycle.hpp` extracts the existing Wood, Fire and Smoke decisions;
World retains rule ordering, traversal, transport, activity and accounting.
Wood uses `state_b` on its two-tick lane, emits real Fire with `state_a=32`, and
does not convert directly to Smoke. Fire expiry produces Smoke. Motion must not
change the logical random-coordinate anchor. Internal world-up gas transport is
not implied by retained product lifecycle support.

The original and extracted World wrappers were compared on immutable source
fixtures: **4,472 assertions, zero differences**, including serial/phased lanes,
tuples, products, temperature, accounting, signed coordinates and epoch wrap.
This baseline also passed in the final combined-source hosted native campaign.

## M0 evidence and repaired findings

Storage/contact qualification: 8,045 and 44,727 checks with zero failures,
including sanitizer delta checks and zero measured steady storage allocations.
Repaired coordinator suite: 969 checks, zero failures. Independent partial-debit
fault injection: 229 checks, zero failures, throwing before/after debits 1, 4
and 9. The coordinator translation unit used UBSan; this is not a claim that
every World translation unit had sanitizer instrumentation.

Independent review repaired dropped neighbour discovery, stale reset cancellation,
partial-debit double ownership, pose/mask mismatch on refusal, coarse occupancy
overlap refusal, journal clear history and extreme-coordinate overflow. The
reviewed M0 coordinator SHA256 is
`34660ca23df135d45e06d30bb527d2cb71840fb1bc25938f326ba3298ef58053`.
Independent review manifest SHA256:
`e13ed952f5a15222736e9c390faf9fc119cb6d2042562e978fe7b9afc4149334`.
There is no unresolved Class A/B finding in that early protocol scope; final
combined source requires another independent review.

Actual local Godot iteration uses installed **4.7.2**, not the final pinned4.7
Windows acceptance runtime. The source-built extension and selected Rapier
execute real reservation, mass/shape readback, fall, impact and rotation. The
ordinary scenario contains570 Wood cells, erases44 through normal edits and
promotes526. No old native extension is reused. Full result/source manifests
are retained with qualification artifacts; local timings are not target-PC
performance or physical owner acceptance.

The final M0 iteration passed55 integration checks across120 actual Rapier
steps, tipped1.68452 radians and reached deepest occupied geometry109.99316
against the floor at110. The separate revisioned bridge passed28 checks;
package verifier adversarial fixtures passed8. These results establish the
local M0 mechanism, not M1/M2 or Windows completion.

## Delivery constraints

See [ObjectShard Lab playtest](../operations/objectshard-lab-playtest.md).
The final evaluator must bind committed source, native DLL, selected Rapier,
pinned Windows Godot, scenario identities and complete file inventory. Missing
or stale binaries must fail verification. Windows automation, rendered evidence
and owner Windows11/NVIDIA physical acceptance are separate statuses.

Unsupported scope remains explicit: arbitrary material admission, fractional
quantity transfers, Wave/pressure/inertial/ballistic sidecar transfer, general
internal transport, consuming Acid reactions, fracture and durable persistence.

## M1 executable checkpoint

The registry scheduler now invokes the shared Wood/Fire/Smoke lifecycle
decisions on the native semantic clock. It processes only due carriers, starts
strictly after capture/birth, retains the original logical coordinate anchor
through movement and does not depend on Rapier sleeping. Dormant Wood retains
a deadline and is explicitly awakened by admitted ignition. The canonical
`MaterialRules::pair_reaction` resolver is reused; none of the admitted local
material pairs is a consuming pair, and newly introduced unsupported pairs
fail closed instead of silently acquiring cross-domain authority.

Products occupy actual local carriers. Wood emits Fire32 into an Empty
neighbour; blocked Fire can transition to Smoke under shard ownership. Smoke
has its own lifetime/crowding lane; no local gas transport is claimed. The
same occupied product cannot also be duplicated in an outbox. Erosion changes
exact occupied geometry and mass; disconnected islands remain an explicit
`split_pending` compound while chemistry continues. Losing the final skeleton
retains a draining product domain independently of body retirement.

Native M1 qualification: **59,281 checks, zero failures** (storage8,125,
contact44,727, coordinator1,957, original World oracle4,472). The frozen native
input digest is `b3ad04377b1cca02bf1711fba33504546dc9c7bf2b00b9369fedfaa738bc4782`.
It covers pre-transfer World burn, sleeping/moving logical-anchor continuity,
retained Fire32→Smoke, final-skeleton draining and burning perforation beyond
eight exact shapes. Native ACK fixtures do not substitute for Rapier tests.

Actual Godot4.7.2 M1 iteration passed154 checks: Rapier was observed sleeping
while the same Wood countdown progressed237→227 over20semantic ticks; three
real retained Fire products were born, retained Fire→Smoke was observed and
an81-shape perforated body activated. The iteration extension SHA256 is
`4e3e18891d2b2f9c3d97e150bebc28778b13084dde3babfcc79fcad21f1137b5`.
The initial enclosed-ignition fixture's two failures are retained; moving
ignition to the genuine exposed crown edge repaired the fixture without
changing chemistry. M1 output remains disabled: World Fire/Smoke created
before transfer is not evidence of shard emission.

These checkpoints are intentionally distinct from the later M2 candidate,
whose outgoing/incoming transfers and Windows package require fresh execution.

## M2 ownership and exchange

The M2 coordinator owns World and all registry inventories under one exclusive
Lab owner. The public bridge copies observations and explicit receipts; it never
exposes mutable cell storage. The ordinary Workbench worker and immutable
Workbench compound adapter are unchanged. The new revisioned adapter replaces
complete exact geometry between manual Rapier steps, binds material/geometry
revision, generation, mass, COM and inertia, and acknowledges actual installation.
One native owner identity is independent of the number of compound rectangles.

Every conservative exchange validates a monotonic transaction, session, shard
generation, cell incarnation, body generation, applied geometry, pose serial,
capability version and exact accepted tuple. It reserves local/World capacity
before debiting inventory. A bounded receipt ring returns prior outcomes, while
the retired sequence watermark prevents evicted transactions from executing
again. Unexpected partial progress retains the actual sole owner in quarantine;
expected stale, capacity, unsupported and destination refusals are nonmutating.

**Authentic output:** Wood creates Fire32 in a real local product carrier. The
outbox is a proposal referencing that carrier, not another material copy. At an
admitted transformed destination the coordinator transfers the exact Fire tuple
into a resident Empty World cell. World then executes its ordinary Fire→Smoke
lifecycle and world-up movement. Blocked products remain occupied and execute
only their supported retained lifecycle; no failed delivery deletes inventory.
The declaration does not promise internal gas transport.

**Physical Sand ingress:** baseline whole-cell Sand may lodge through an open
one-to-three-cell-wide pocket. Structural side walls, the full supporting floor
and a clear column to the local top define the aperture. Current pose and the
bounded actual pose sweep must admit entry through that aperture. State and
temperature transfer once; carried Sand is inspectable and visible, contributes
declared unit-cell mass and occupancy, and does not create a structural bond.
The Lab's C fixture uses a three-cell opening so ordinary small rigid-body
rotation does not make the demonstration depend on perfect lattice alignment.

Invalid side-entry history is retained until the complete aperture column is
observably clear. History sampling runs before any cargo mutation and even when
the transfer budget is zero or exhausted. Mechanical overlap relocation excludes
all pocket capture columns, including temporarily occupied ones; it cannot
manufacture a later valid-looking ingress by moving Sand through a solid wall.
This is distinct from ordinary World material movement through a real opening.

**External Water exposure:** before overlap relocation, a bounded pose sweep
captures actual World-owned Water adjacent to a shard Wood cell. The historical
fact binds incarnation, geometry/sample identity, semantic interval and expiry.
It is consumed once at that Wood's next admitted two-tick opportunity, even if
Water has departed. It grants no World debit or write. Wave flux, Water quantity,
pressure/gas and inertial state remain World-owned. Replaced Wood cannot inherit
another cell's accepted exposure.

The admitted per-step motion envelope is at most four cells of translation and
0.20 radians, with bounded contact sampling at half-cell spacing, maximum corner
travel eight cells and at most32 samples. Unsupported movement or contact-history
overflow is visible and fails safely. This is not arbitrary-speed chemical CCD.

## Capability and lifecycle boundary

| Capability | M2 declaration |
| --- | --- |
| Structural admission | Wood and separately admitted inert RedBrick; like-material cohesion; explicit Wall anchors |
| Surface chemical contact | Selected non-consuming World Water extinction of burning shard Wood |
| Selected reactions/lifecycle | Canonical pair resolver; shared Wood combustion, Fire expiry, Smoke lifetime/crowding; no arbitrary Plant admission |
| Emission | Exact whole-cell Fire/Smoke; retained cargo release when draining and physically admitted |
| Ingestion | Baseline whole-cell Sand through a validated bounded lodging pocket |
| Momentum/state | Exact material tuple and temperature; declared carried-mass policy, not general solver momentum transfer |
| Fractional quantity / solver sidecars | Unsupported; Wave, PressureFlow, Inertial Cellular and ballistic sidecars remain World-owned |
| Internal transport | Unsupported; retained products have selected lifecycle, not a rotating gas or granular solver |
| Persistence / fracture | Unsupported; controlled in-session reset and draining are implemented |

The local lattice origin and random-coordinate anchor remain stable under
motion and erosion. Disconnected structural islands set `split_pending` and
continue reacting as one explicitly nonfracturing compound. Losing the last
structural cell retires the body without deleting products or cargo. The draining
owner retains its last validated pose as a release/inspection anchor; a retired
RID is not an inventory destructor. Bounded blocked inventory remains visible.

Per-material population accounting separates initial/authored creation and
destruction, World tick changes, shard chemical transitions, conservative
promotions/transfers and explicit whole-session reset disposal. Water quanta are
reported separately. This is not universal stoichiometric mass conservation.

## Qualification, measurement and retained failures

The first local M2 Godot4.7.2 attempt retained three failures: the one-cell Sand
opening did not admit real grains under ordinary small rotation, and Fire
re-ignition delayed the chosen geometry observation. The fixture changed to a
three-cell opening and includes one genuinely near-consumed Wood cell alongside
the long-burning cell. No chemistry rule or unsupported decorative effect was
introduced to make the test pass.

The repaired local M2 iteration passed359 checks. At tick34, five World Sand
grains became four World grains plus one carried grain with its tuple and
temperature. Water extinguished the same Wood incarnation224→0 without a Water
debit. Sleeping Wood progressed237→227, geometry changed, five real products
were created and two Fire deliveries reached World. Three independent bodies
created eight products and delivered four Fire carriers by tick94. This iteration
used extension SHA256
`adb5fb9b90cbed1c2a688e75d0566cdebca5964a6cf570aa616f2766dfcc779a`.
It predates the final ingress hardening and is not final-source Windows evidence.

After those repairs, the source-matched local M2c Godot4.7.2 iteration passed
**373 checks, zero failures**, including moved→consumed→body-retired domains
whose retained products remain at the actual final pose for both rendering and
inspection. Its extension SHA256 is
`36c04d20a1ae713466342b26454eb73f13e79f93ac9ec29c20df4d62c67584ef`.
The corrected native catalogue has60,432 applicable checks with zero failures,
plus192 unchanged World test cases. The separate final review executed350
adversarial checks with zero failures. Exact inputs, sanitizer scope and remaining
hosted gates are recorded in the [local qualification checkpoint](../audits/2026-11-22-objectshard-m2-local-qualification.md).

Independent review subsequently reproduced side-entry laundering, transfer-
budget history loss and overlap-relocation laundering. The failed probes and
their source identities remain retained; focused repairs added persistent
aperture history, a two-pass history/proposal schedule and relocation exclusions.
Final evidence must execute those probes against the repaired source. Separate
before/after-debit fault injection covers exact ownership, tuple, temperature,
receipt replay and reset after exceptional partial progress.

A fresh reviewer rebuilt the immutable original World wrapper and the extracted
wrapper independently: all20 JSON fixture records were byte-identical, including
the author's16 fixtures and four new serial/phased, signed-origin burn/expiry/
epoch-wrap fixtures. The unchanged full World suite passed192 test cases with
zero failures. Neither result is a claim about Windows or full-game acceptance.

`tools/objectshard/run_native_tests.py` retains immutable input snapshots,
compiler commands, bounded process logs and summaries. Its normal and sanitizer
results are distinct; LeakSanitizer is explicitly disabled where unavailable.
`run_benchmarks.py` records construction separately from steady state, exact
allocation counters, p50/p95/p99/max and every failure. The fair serial miniature-
World probe shares the same admitted payload, semantic clock, actual output and
external World. Its reported scope must not be extrapolated to untested payloads.

Native and actual-Godot budgets were registered before final qualification in
`tools/objectshard/native_budgets.json` and `lab_budgets.json`. Native p95≤2ms,
p99≤10ms and max≤50ms apply to the recorded development host, with no steady
C++ allocation and bounded retained bytes. The Lab targets owner-thread p95≤
16.667ms, with separate tail, promotion, geometry and software-renderer allowances.
Elapsed owner-thread time is not process CPU time; requested C++ bytes are not
RSS. Occupancy includes contact/relocation, and presentation includes submission;
nested counters must not be added as disjoint work. Target Windows11/NVIDIA
physical acceptance remains an owner action.

## Reproduce the source-bound candidate

The dedicated `ObjectShard requested source-bound Lab qualification` workflow
runs only for an explicit ObjectShard milestone marker or dispatch on an
ObjectShard branch. It uses hosted Linux and Windows runners, exact checked-out
SHA, pinned engine/toolchains, selected Rapier hashes and immutable input ledgers.
It neither publishes production runtimes nor cancels another campaign. Its
scoped results do not replace mandatory merge gates.

Linux builds and seals the exact extension before actual Godot tests and renders.
Windows consumes a source-verified DLL candidate, executes the Lab, packages the
exact project/runtime/dependencies, then replays that delivered package. Missing
native receipts, ambiguous custody or modified delivered scripts are refusals.
Partial failure logs remain artifacts. See the [owner procedure](../operations/objectshard-lab-playtest.md)
for the verified launcher, scenarios, inspection and result export.

## First hosted campaign and portability repair

Campaign [44972695658](https://github.com/techrote/cybersand/actions/runs/44972695658)
executed source `1bb6185be05f5ef838543a0e13c81428b751d969`. Actual Windows Godot4.7,
all ten ANGLE-rendered PNGs, the headless/rendered performance matrices and
delivered-package replay passed. Those results remain attached to that source.
The Linux native sanitizer tests and extension compilation passed, but the
unchanged runtime-floor gate correctly rejected the new `hypot@GLIBC_2.35`
dependency against the selected GLIBC2.34 floor. No Linux actual-Godot pass is
inferred from compilation.

The subsequent narrow repair replaces five contact magnitude calls with a
finite scaled-square-root helper, following the repository's existing portable
numeric pattern. It preserves bounds and meaningful tiny/subnormal components.
The affected normal and ASan/UBSan suites each passed49,055 checks, including
1,220 new numerical checks; the applicable ObjectShard catalogue is61,652.
An independent 100-digit reference comparison passed4,006 pairs, with at most
two ULP observed error. Deliberately pathological diagonal boundary inputs can
differ from `hypot` by less than9e-16; this is not bit-identical floating-point
math, and it is far below the existing1e-9 contact padding. Full rebuilt ELF
floor verification and fresh Linux/Windows execution passed in the final
campaign recorded below.

Visual review of the first Windows PNGs confirmed actual rotated shapes,
burning material/products, consumed holes, carried Sand and retained draining
products. It also found stale scenario-selection and inspection presentation.
The repaired scene keeps the dropdown and overlay state synchronized, clears
obsolete inspection on reset, and places material/owner/state/temperature before
the exact JSON. The capture now inspects the extinguished Wood instead of stale
Sand. Added actual-scene assertions raise the integrated inventory to379 checks;
the rebuilt final runtime executed all of them on Linux and Windows.

## Final source-bound delivery

Runtime source `8f55a4e61b7cbb34a594f5e07e7d81d49aa58945`, tree
`a0e3478c293908247bc5cdaab9497fc290a374c6`, passed all three jobs in
[campaign 44974395620](https://github.com/techrote/cybersand/actions/runs/44974395620).
Hosted native ASan/UBSan executed **61,652 checks / 0 failures**. Actual pinned
Godot 4.7 on each platform passed **379 Lab checks / 0** and **28 bridge checks /
0**, both existing Rapier/Materials Lab regression scripts, ten rendered
captures and eight-workload headless/rendered profiles. The delivered Windows
package replay repeated the Lab, bridge and existing regressions successfully.

The [Windows owner evaluator](https://github.com/techrote/cybersand/actions/runs/44974395620/artifacts/14735176557)
contains the exact source-built DLL, pinned GUI/console engines, selected Rapier,
dependencies, licences, source, manifest and verified launchers. The owner can
extract it and run **Open ObjectShard Lab.cmd** without rebuilding anything.
Automated Windows and software-rendered evidence do not establish physical
Windows 11/NVIDIA acceptance.

Final Windows rendered owner-thread p95 is 2.258 ms empty and 3.552 ms for three
reacting shards; the longest profile frame is 6.592 ms. Linux equivalents are
1.911/2.994 ms and 5.584 ms. Both platforms pass their registered Lab budgets.
The separate final native development-host matrix nevertheless retains **10/74
failed timing limits**. Its single bounded matched control passed, but does not
replace that complete failed result. The [performance delta](../audits/2026-11-22-objectshard-portable-math-performance-delta.md)
and [full-tree mini-World comparison](../audits/2026-11-22-objectshard-native-performance.md)
preserve exact sources, failures, allocations and the observed tradeoffs.

The [final acceptance record](../audits/2026-11-22-objectshard-final-acceptance.md)
contains source/ancestry, capability boundaries, independent findings and repairs,
runtime/package identities, measurements, visual review and owner actions.
The ordinary repository runtime-provenance gate remains unsatisfied because
production binaries were deliberately not published. The evaluator is separate
from strict four-path publication. All three PRs remain Draft/HOLD; no merge,
Ready promotion, auto-merge or release occurred.
