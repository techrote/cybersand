---
title: IN-TOOLS #361-A metered Liquid Drain implementation and qualification
status: Current
document-kind: evidence
scope: Isolated opt-in physical U10 implementation, source-matched native and Linux Godot evidence, independent review, negative controls and untested integration gates; no merge or parent completion
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/in-tools-metered-drain.md, ../systems/actor-usables.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../reference/validation-evidence.md, ../operations/github-development-and-release.md]
---

# IN-TOOLS #361-A implementation and qualification

## Disposition and source authority

**Implementation candidate; full #361-A acceptance remains open.** The existing
physical U10 now has an explicitly selected exact-metered Water/Brine profile,
native-owner quantity/allowance accounting, body/wall preflight and terminal
partial-fault handling. It is actual application source with executable tests,
not an architecture-only delivery. The implementation stays draft; no automatic
merge, parent #361 closure or reversible-valve work is authorized.

Implementation PR: [#383 — opt-in exact-metered physical Liquid Drain](https://github.com/techrote/cybersand/pull/383).
Its PR ledger owns subsequent exact-head hosted checks and integration disposition.

| Authority | Inspected identity |
|---|---|
| Accepted main and branch base | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` |
| Accepted-main tree | `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Original admission #379 | `24d0e612ae986edbdc48e5b94f52315d9c3d8421` |
| Independently corrected #379 inspected during work | `1aaab324a9bccbaa7f868798dbb4f9fd9b4a7718`, still draft/unmerged |
| Unmodified #370 comparison reference | `fbe82bcab8f821aac442c2bf59eb57b279717873` |
| Isolated implementation branch | `feat/in-tools-361a-metered-liquid-drain` |
| Published implementation and measured source | `f4878302fd66975468dd307a94bb035529af5ecd` |
| Published implementation tree | `b5743bdb4b7a6c3e8fc6c1f8d331aa08ce21b719` |

Root AGENTS, handover, ownership/PLAY, policy, preparation/receipt and usable
contracts were read before edits. Existing dirty worktrees were not used for
implementation. The active #347 worker/snapshot and #380 actor arena/rig changes
were inspected without altering either branch. Shared worker edits are limited
to owner-local metered dispatch, cancellation, quarantine and restart. The
coupling, actor rig/arena and snapshot-format files remain unchanged. Main changes
are confined to equipment selection, copied input/cancellation and status.
#370's comparison panel, host, recorder and scientific reducer are unchanged.

The updated #379 review was fetched and read without changing its branch. The
[coordination checkpoint](https://github.com/techrote/cybersand/pull/379#issuecomment-6630205442)
records the distinct implementation owner. Its corrected independent-census,
diagnostic-parity and evidence-custody findings were applied to this task's own
test source. The preparation PR is a reference, not a merge prerequisite.

## Implemented behavior and resource safety

The [current profile guide](../operations/in-tools-metered-drain.md) owns exact
controls and interfaces. F5 offers Ordinary U10, Metered Water v1 and Metered
Brine v1 only on physical U10. The existing chassis, aim, control/action stream,
charge and cooldown remain authoritative. PLAY's existing physical rig/solver
construction supplies fresh IN ownership; the metered UI does not change policy.

Positive operations remove actual resident stored liquid through the existing
native radius-zero Empty edit and then verify copied native transitions. Water
uses actual stored units, Q7/Q255 for whole-cell IN/CY at the tested endpoints,
and fractional stored quantities for FreeMass. Brine is a separate cell count.
Up to 16 targets share the existing read/write limits. Per native generation
and actor slot, 32Q Water units and 32 Brine cells are independent finite removal
allowances; equipment/session churn cannot replenish them.

No native solver, adapter/ABI, material catalogue, default policy, Rapier
coupling or generic soliding change is included. PF-containing Worlds and
legacy/imported IN Worlds without native initial construction identity refuse.
The latter restriction avoids treating arbitrary hidden imported IN diagnostic
histories as preflightable through an API that does not expose all needed
bounded counter state.

Host results explicitly say `host-local-native-observation-v1`. Initial native
construction receipts retain their own provenance. Observations are bound to
the exclusive native owner, applied policy, object/generation, completed tick,
hard-surface revision and captured physical frame. No native per-command receipt
or unavailable native pose revision is invented.

Normal refusal performs no destructive edit and incurs no new effect debit,
charge cost or cooldown. The worker's existing simulation-time recharge/cooldown
aging remains separate. Unexpected faults retain attempted/verified partial
effects, latch terminal before mutation and block subsequent edits/ticks and
healthy publication. Existing clear/prepared reconstruction is the recovery
path; stop/restart alone does not erase the quarantine. No silent repaint or
velocity rollback exists.

## Native primitive qualification

The new standalone driver and strict runner qualify the existing native
primitives. Their test-side preflight is not production GDScript execution.
The clean published implementation run passes **30 registered cases**, with
**14,023,753 repeated assertions**; most are repeated positional inventory
checks, not independent experiments. Compilation uses GCC 13.3 on Linux x86-64.

Each of eight material/policy/precision arms runs 40 bounded accepted operations
and 64 ticks at one and four workers. All configured-four arms actually observed
four phase claimants. Physical hashes and separate 65-sample IN diagnostic-ledger
traces match. Full resident inventories independently scan 131,072 cells/eight
chunks at ticks 0, 8, 20, 32 and 64; exact walls, every forbidden coordinate,
stored quantities and material populations are checked. Five corrupted
inventory/geometry/domain controls fail as intended. Save/restore compares
separate IN ledgers over eight continued ticks.

| Native arm | Initial | Registered sink | Final | Unit |
|---|---:|---:|---:|---|
| IN Water, 3-bit | 9,072 | 3,052 | 6,020 | Water units |
| IN Water, 8-bit | 330,480 | 111,180 | 219,300 | Water units |
| FreeMass Water, 3-bit | 9,072 | 4,464 | 4,608 | Water units |
| FreeMass Water, 8-bit | 330,480 | 163,200 | 167,280 | Water units |
| CY Water, 3-bit | 9,072 | 4,438 | 4,634 | Water units |
| CY Water, 8-bit | 330,480 | 161,670 | 168,810 | Water units |
| CY Brine | 1,296 | 638 | 658 | Brine cells |
| IN Brine | 1,296 | 436 | 860 | Brine cells |

The separate one/16-cell controls include fractional FreeMass at both precisions
and Brine state bytes deliberately unlike Water quantities. Raw-under-mask
erasure is reproduced as a hazard; guarded refusals preserve serialized state,
motion, quantity, residency and resource. Capacity/failed-tick and explicit
reconstruction controls use the real native World.

The runner's **23 reusable unit tests** cover 20 malformed synthetic packets,
one valid synthetic shape and two fresh-output custody controls. A zero-exit
compiler without a newly produced executable cannot pass. These parser inputs
are synthetic and do not authenticate a native execution by themselves.

## Actual Linux application results at the published implementation

The clean `f4878302` snapshot passes **15 scoped Godot tests**, **12,026 counted
assertions**, plus the genuine failed-tick suite whose footer has no numeric
assertion count. Import is clean, tests exit naturally, skip/runtime-error
screening is clean and all 754 copied source inputs remain unchanged. This final
run includes the terminal-lab fence, retained physical-owner restart and exact
masked-source witnesses. The earlier candidate08 passed 11,943 assertions on its
own sealed bytes; its results and subsequent failed iterations remain historical.

| Test scope | Exact `f4878302` result |
|---|---|
| Metered native adapter/physical runtime/worker | 1,614 assertions; 16 quantity arms and 52 other refusal/resource/fault/lifecycle/ownership controls |
| Metered physical equipment/session/panel | 99 assertions with real Rapier and explicitly synthetic copied native outcomes |
| Actual Main/worker/Rapier metered gameplay | 148 assertions; real PLAY/F5 controls and injected M input, headless |
| Ordinary physical runtime/admission/Main and sampled usables | 502 assertions |
| Existing equipment/lifecycle/physical session/sampled rig session | 8,884 assertions |
| Existing liquid policy/physical preparation/Water reference body | 779 assertions; actual native/Rapier reference body |
| Existing genuine native tick-failure regression | PASS; separate uncounted suite |

Controlled runtime geometry begins with 312 selected-liquid cells. Full Water
comparison arms use equivalent geometry and quantity: 2,184 units at Q7 or
79,560 at Q255. Full-power 16-cell pulses remove 112 or 4,080 units. Fractional
FreeMass starts at 19,656 units and removes 1,008 (16 × 63). Brine starts at 312
cells and removes 16. The no-extra-source/no-reaction inventories close after
each accepted operation and the registered shutoff ticks. Current-radius-two
behavior is separately retained; matched-radius controls are not silently
labelled unchanged Current timing.

The small application tank has configured-four capacity but observed at most
two phase claimants. This is reported separately from the larger native
fixture's four observed claimants. Recorded command-owner cost and native tick
cost are separate exploratory measurements; neither establishes graphical
pacing, simultaneous CPU utilization or a production performance budget.

Actual Main closures in this final committed-source run are:

| Real headless Main arm | Initial | Registered sink | Final |
|---|---:|---:|---:|
| IN Water, two eight-cell held pulses | 538,560 units | 4,080 units | 534,480 units |
| Freshly reset IN Water, one pulse | 538,560 units | 2,040 units | 536,520 units |
| IN Brine, one pulse | 2,112 cells | 8 cells | 2,104 cells |
| Current FreeMass, eight actual target cells | 538,560 units | **1,561 units** | 536,999 units |
| Hard-wall refusal | 538,560 units | 0 | 538,560 units |
| Actual actor-body obstruction | 554,880 units | 0 | 554,880 units |
| Ordinary U10, eight changed cells; separate joined-owner endpoint measurement | 538,560 units | **1,572 units** | 536,988 units |

The FreeMass host result is actual partial-cell removal, not eight assumed
255-unit cells. Main's joined-owner census uses authoritative Water observation;
`get_cells` is used only for Brine/material positions because Water presentation
is dithered. Exact wall and forbidden-side positions accompany the totals.
Asynchronous host input timing changes which fractional cells are reached:
candidate08 removed 1,893 units and candidate12 removed 1,594 on their own
recorded ticks. Those earlier measurements are not transplanted into this run.
The ordinary U10 endpoint difference is not a new ordinary per-command receipt;
its version-1 outcome records eight changed cells, charge 99.15 and cooldown 0.10,
while the experimental sink stays zero.

The wall case refuses through the existing Rapier muzzle-clearance owner before
native dispatch; it does not fabricate a native refusal receipt. The under-actor
case records native `source_blocked` / `body_occlusion` with zero transitions,
charge or cooldown cost. Six exact stored Water cells remain at quantity 255 and
body ID 1 from native tick 63 to 69: `(100,106)` and `(97,107)` through `(101,107)`.
The actual equipment pose, native diagnostic and both positional inventories
are retained alongside full source/sink closure.

## Runtime and evidence identity

| Executed dependency | Identity |
|---|---|
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Godot executable SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux native SHA-256 | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` |
| Linux Rapier SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Native runtime source provenance | All 80 recorded native inputs match current production source; retained build/source commit `a7ee10f251f647a16dec8a1d7f18c4f299100cba` |
| Native toolchain provenance | GCC 13.3, Ubuntu 24.04, SCons 4.10.1, godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` |

GDScript changes are qualified by the copied test-source hashes, not by the
older native build commit. All 18 existing runtime payloads were separately
materialized and checked against committed LFS bytes. That identity check does
not imply execution on Windows, Android, macOS or Web.

Development snapshots retain their own base/tree, changed-file hashes, raw
packet/log hashes, fixture hashes, actual construction receipts, session/native
generation identities, commands, timeout and completion/error screening. The
final tests ran on clean published implementation `f4878302`, tree `b5743bdb`.
The later documentation/evidence addendum changes no production, test, fixture,
runner, runtime or dependency bytes; it does not relabel the measured source.
The [evidence index](in-tools-361a-2026-11-04/evidence-index.json) binds every
retained JSON file by byte size and SHA-256. The
[full host source identity](in-tools-361a-2026-11-04/host-source-identity.json)
retains the complete source/runtime input census. Raw logs and toolchains stay
outside source control; their hashes and completion results remain in the records.

| Retained machine evidence | SHA-256 / scope |
|---|---|
| [Host qualification](in-tools-361a-2026-11-04/host-qualification.json) | `31d7ab0b150a90bb6fce4152223f521597e6c901060cd7d238a20021357b0a5a`; all 15 suites, measured controls, native construction and host-local outcomes, failure history |
| [Native qualification](in-tools-361a-2026-11-04/native-qualification.json) | `937ce315348fcbf8c065e0227432839b7c5d0c3828f3eafff3f2863b131f269a`; exact source, compiler/executable and 30 native cases |
| [Native runner controls](in-tools-361a-2026-11-04/native-parser-controls.json) | `174d247532b026aafdb8215579a895f7288f74a0569b6b35e27afa1f508c32fc`; 23 synthetic parser/custody checks |
| [Independent review](in-tools-361a-2026-11-04/independent-review.json) | `34a666e53db8ac6657299a3b1952df6f8a12d86642073ee697890aea2136c737`; accepted for draft source review, no unresolved blocking source findings |
| [Local validation](in-tools-361a-2026-11-04/local-validation.json) | Documentation, all 18 materialized runtimes, M11, LFS, retrieval and preserved initial companion failures |

The native standalone executable SHA-256 is
`8a35fbcc69f867d44cca009697e84f6e477b8bb76d3267389314a4fdb9112695`.
The final compile/run took 24.64/4.03 seconds, including instrumentation; this is
not a production speed claim. Effect command-owner time, helper time and native
tick time are retained separately in host evidence. Graphical pacing is untested.

## Failures, independent review and corrections

| Observed issue | Disposition |
|---|---|
| Initial low-power fixture placed liquid about 0.17 cells beyond shortened reach | Test geometry corrected by one cell; original two failed assertions retained; no range or charge change |
| Saved IN import loses both initial construction receipt and transient-mask registration | Expected refusal assertion corrected to allow earlier `source_blocked`; unavailable IN construction identity is checked independently |
| Metered identity calls undercounted in the effect read reservation | Production correction: reserve 10 setup, 6 preidentity and 8 postidentity units plus inspected cells before editing |
| Early refused outcomes omitted `remaining_budget` | Production correction: copied zero-removal outcome includes remaining allowance; equipment can consume the refusal |
| Faulted `start_worker` could reach character recovery/healthy publication | Production correction: preserve terminal failure through restart and service only explicit reconstruction |
| Non-PLAY metered focus cancellation waited for a physics callback | Production correction: extend the existing immediate focus/UI cancellation hook only to selected metered equipment, including ordinary pause |
| Non-U10 programmatic selection could inherit a stale panel profile | Production correction: clear profile/material for the requested non-U10 item |
| Matching copied outcomes could contain an impossible debit or remaining allowance | Production correction: v2-only pending-budget/initial-stock bounds and supplied before/debit/remaining closure checks; malformed copies do not cause recoil |
| Legacy lab dispatch precedes the normal loop quarantine gate | Production correction: terminal owners reject nonreconstruction release/floor/capture commands before dispatch |
| Healthy worker restart unconditionally enabled the sampled character, suspending the retained physical owner | Production correction: retain sampled-disabled physical mode and avoid sampled spawn recovery; fresh input authority is still required |
| First actual Main test referenced a nonexistent `demo_bridge` member | Test-only correction; strict runtime-error scanning rejected the zero-exit/footer result |
| Ordinary Main diagnostic census API unavailable; reset context read too early | Test-only correction to authoritative Water census and explicit feedback wait; the interrupted failed attempt remains a failure |
| Main wall control expected a native result but ordinary equipment clearance refused first | Test-only correction: qualify the actual local Rapier clearance refusal, unchanged source cells and zero equipment debit |
| Initial under-actor control aimed through exposed cells before the physical joint reached the requested pose | Test-only correction: bind the control to actual settled equipment pose and preserve exact masked stored-cell witnesses; successful exposed-cell removals were not body-mask violations |
| Ordinary control reused a retired input generation after joining the worker | Test-only correction: exercise the normal fresh F5/control boundary after restart; the production stale-command fence remains intact |

Independent automated review covers World ownership, quantities/partial
FreeMass, masks, resources, command freshness/restart, evidence integrity and
ordinary U10 risk. Its source-hashed disposition accepts the reviewed draft
checkpoint without unresolved blocking source findings. Its final exact-source
seal is retained with this evidence. The reviewer authored the standalone native
driver and runner and independently reviewed the production application authored
by the other agents; this is not independent authorship review of its own native
driver, a separate human/account approval or owner integration authorization.

Initial documentation/provenance checks failed on six references to five absent
companion files. The exact `6a583119` companion bytes and recorded SHA-256 values
from #379 were restored outside this source checkout; the unchanged documentation
and all-18-materialized runtime checks then passed. M11 integrity and whitespace
also passed. No historical source hash or checker was weakened.

The first retrieval comparison preserved all 32 frozen and 156/157 existing
challenge top-five hits, and all four additive questions hit their canonical
page at rank one. ACT14 moved 1→2 and USABLE02 improved 5→4. The same descriptive
Current physical-equipment heading adopted in #379 is reconciled here. The
resulting existing cohort returns to 124 top-one and 156 top-five hits, matching
accepted main; ACT14 returns to rank one and USABLE02 remains at rank four.
MRR@5 is 0.8737 versus main 0.8734. Query text, expected destinations, evaluator
and old results are unchanged; lexical rank changes are not a broad answer-quality
claim. The existing LCB03 miss remains disclosed.

## Remaining gates and #361-B handover

| Acceptance row | Disposition |
|---|---|
| Linux native primitive controls | Executed at clean published implementation; PASS |
| Linux native-backed Godot worker/equipment | Executed at clean published implementation; PASS |
| Linux actual Main/Rapier/injected input | Executed headlessly at clean published implementation; PASS |
| Windows native/Godot host | **UNTESTED** |
| Actual physical mouse/keyboard/gamepad and owner feel | **UNTESTED** |
| Rendered desktop pacing and platform-specific UI behavior | **UNTESTED** |
| Exact final-head hosted Documentation/materialized provenance | Pending draft publication and recorded result |
| Applicable hosted Native, GDExtension/Godot, scoped Water and actor gates | Required before any authorized merge; draft skips are not passes |
| Scoped standalone native driver hosted execution | Not yet a registered hosted job; separately required for integration evidence |
| Full #361-A completion / parent #361 closure | Not claimed / not authorized |

There is no production native-source delta requiring a replacement runtime for
this candidate, but current source/runtime identity remains a gate. The draft
must retain unsupported PF and imported-IN restrictions until separate
qualification or a separately authorized minimal native contract closes them.

#361-B must separately admit reversible resident geometry, Empty-only and
unmasked closure, aperture/forbidden-side positional checks, exact accounting,
current body/session ownership and post-mutation fault behavior. Safe restricted
liquid erasure does not prove safe solid insertion or multi-cell closure
atomicity. No solver-law, velocity, pressure, generic coupling or equipment
framework extension is inherited as permission. Record this checkpoint and stop.
