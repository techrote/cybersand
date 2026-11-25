---
title: ObjectShard M4 native recovery and independent source review
status: Historical
document-kind: audit
scope: Independent recovery of unchanged native qualification, bounded sanitizer replay and source review; no overall campaign or physical performance acceptance
last-reviewed: 2026-11-25
related-documents: [2026-11-24-objectshard-m4-source-recovery.md, 2026-11-24-objectshard-m4-world-transition.md, ../research/objectshard-m4-workbench.md]
---

# ObjectShard M4 native recovery and independent source review

**Native evidence recovered and independently verified.** No new native defect
requiring an implementation change was established in this review. This is a
scoped conclusion about the existing source and the witnesses below. It is not
an overall M4 qualification result or physical Windows/NVIDIA acceptance.

## Recovery campaign long-burn observation correction

The Windows Workbench job in recovery run **45517975210 attempt 1** failed its
long-burn case. That failure remains a failure. The
[clock review](objectshard-m4-recovery-20261125/long-burn-clock-review.json)
preserves the exact raw-log hash and original terminal observations.

The test read semantic time and geometry from the current copied native frame,
but read the burning cell from the earlier displayed publication. Native tick
514 already showed eight remaining structural cells and geometry revision 2;
the displayed cell still showed the preceding Wood state until the real Rapier
geometry acknowledgement. At tick 515 the displayed cell became Air. The
native deletion was therefore witnessed at 480 elapsed ticks, while the test
incorrectly labelled the retained display using a later native clock. All
2,084 observed display identities remained coherent.

The correction is confined to the long-burn fixture. One immutable native
frame supplies both the chemistry cell and its tick. A separate display sample
retains its own cell, tick and publication sequence. The strict **240 native
opportunities / at most 480 native ticks** assertion is unchanged. New checks
join native and displayed ignition state, then require delivered Air with the
same native cell and publication sequence after the ordinary Pause barrier.
Native chemistry, physical stepping, publication policy and displayed tool
targeting are unchanged. Specialist B independently approved this distinction.

The corrected script parsed during two local Linux attempts, but neither
attempt completed: both ended with SIGKILL around 60 seconds during authored
World installation or replacement, without a completion footer. One omitted
the registered explicit M4 opt-in; the second used the correct flags. Their
commands and log hashes are retained as unsuccessful local attempts, not
qualification. Corrected hosted execution is still required.

The original aggregate campaign
[45473059187](https://github.com/techrote/cybersand/actions/runs/45473059187)
remains **failed**. Its native sanitizer and Windows build jobs passed; its
Linux engine acquisition and Windows delivered-package replay failed. A later
repair must qualify its own changed execution inputs.

## Recovered identities and preserved predecessor findings

Published source `f5b7ac7e651356c9f6d5657dfb0cb9d60111be81` and the recovered
local integration `66365c4c20b4331c004810b4235893315a623525` have the same tree,
`fcbb55a7c80a9d1a887e4e0336491e07c3ae01db`. The original native lane is clean at
`89aae6975a4f2fbf5ef7a2db5633a3bf10e6d847`; its implementation is incorporated
in that published source. Original checkouts were inspected without mutation.

Two previously untracked specialist findings were recovered byte for byte:

| Original finding | SHA-256 |
| --- | --- |
| [Native campaign review](objectshard-m4-completion-20261124/hosted-f5b7-native-review.json) | `1e6db54c70ea33ca6a64f2a18fb8cb980cc408ed7f355340947e5bfaacd3f42b` |
| [Windows native cross-review](objectshard-m4-completion-20261124/hosted-f5b7-windows-native-cross-review.json) | `bf5974d35b118a5c2267be4f57748da2efa9ff57daeae1f83d51d3bd8591092b` |

Those files retain their original capture-time statements, including the then
running Windows job. They were not rewritten to imply that the subsequently
failed campaign passed. This dated record and the recovery mission ledger own
the updated terminal interpretation.

## Raw-archive verification and bounded independent replay

The [new recovery report](objectshard-m4-recovery-20261125/native-recovery-review.json)
was produced directly from original artifact **14959327733**, independently of
the recovered specialist summary. The ZIP is **135,239,647 bytes**, SHA-256
`1629687935c7a1b13fb86c231527ed29e7de13f944e7d933eac82d243b3307cd`.
Its 326 members have no duplicate or escaping paths.

The [revalidation program](objectshard-m4-recovery-20261125/review_native_recovery.py)
compares all 129 sanitizer inputs and 95 benchmark inputs against both the
archive's frozen source and published Git content, then against the recovery
checkout. It recalculates both complete input digests, hashes the seven
sanitizer executables and the benchmark, recounts the original raw test output,
and independently applies the registered limits to the raw benchmark JSON.
Every compared input matches.

| Recovered gate | Verified result |
| --- | --- |
| Six ObjectShard ASan/UBSan suites | 96,500 checks; zero failures |
| Ordinary World regression | 192 test cases passed |
| Complete retained native benchmark | 4,276,351 checks; zero failures |
| Registered native budgets | 74 of 74 limits passed; all ten workload identities present |
| Peak requested C++ allocation | 6,280,328 bytes; 11,128 bytes below the 6,291,456-byte limit |
| Steady allocation limit | Zero in every registered integrated and comparison candidate |

The original compiler was GCC 13.3.0. ASan and UBSan were enabled with
`ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`. **Leak detection was disabled.**
Requested allocation bytes are not process RSS. The benchmark's synthetic
poses and acknowledgements do not execute Rapier or establish display rate.

The recovery lane additionally executed the archive's byte-identical
coordinator, storage and admission sanitizer binaries on the current Linux
host, with the same sanitizer environment and a 180-second per-case watchdog.
The [replay receipt](objectshard-m4-recovery-20261125/native-replay.json)
records **42,308 checks, zero failures**: coordinator 5,945; storage 8,271;
admission 28,092. This is a fresh local binary replay, not a new compilation or
a fresh Windows execution. Raw stdout files remain outside the repository;
their hashes and observed assertion counts are recorded in the receipt.

The reproducible archive review command is:

```text
python3 docs/audits/objectshard-m4-recovery-20261125/review_native_recovery.py --archive ORIGINAL_NATIVE_ARTIFACT.zip --source . --output native-recovery-review.json
```

## Physical and ownership source review

Review covered the native coordinator and facade, the ordinary worker's final
interval admission, and Main's segment-completion adapter. These observations
are source review, supported by the indicated already registered witnesses;
they do not replace actual graphical Workbench qualification.

| Contract inspected | Source observation and applicable witness |
| --- | --- |
| Exclusive same-World owner | Attached construction takes the existing World by reference; attached `step()` refuses. `begin_owner_world_tick` and `after_owner_world_tick` require one exact owner tick. Facade methods require the captured owner thread. Coordinator attached-owner tests cover the existing boundaries. |
| World replacement | Every discovered authoritative facade World swap retires the shard facade first. `create_world`, reset, diagnostic replacement, prepared liquid commit and demo install preserve that ordering. Member destruction also destroys the shard facade before World. The coordinator's repeated replacement test checks old receipt retirement. |
| Structural custody | Promotion reserves geometry before World debit. Boundary-rooted support admits severed Wall caps with mixed structural materials. The coordinator test checks a 404-cell detached component and its material-specific debit. |
| Capacity | Sixteen actual attached owners are admitted; the seventeenth component remains in World after refusal. Existing area and shape limits are not raised. |
| Occupancy domains | GCR IDs remain 1–48 and mutable bodies 49–64. Composition validates disjoint ordered domains; deterministic conservative overlap belongs to GCR without material transfer. Refusal preserves the previously installed occupancy. |
| Composition reuse | Reuse requires an unexhausted mutation journal, matching World material revision, a still-current World composition receipt, and an exact immutable roster. The World receipt includes lifetime, completed tick and revision; this is not a material-revision-only cache. |
| Dense material displacement | Every bounded destination is preflighted before material relocation. Search radius and candidate-work limits remain explicit. The original mixed pool and limit-refusal tests preserve complete inventories. A refused already-stepped Rapier segment is held for Restore, not described as physics rewind. |
| Moving-cell edits | Requests compare body generation, geometry and installed geometry revision, accepted pose serial, material revision, cell incarnation and exact payload. Unsupported or stale requests remain terminal refusals. |
| Fragmentation and velocity | Child reservation initially owns no inventory. Commit transfers each payload and private schedule once, then waits for parent geometry installation before activation. Centre-of-mass shifts preserve the rigid velocity field and angular velocity; coordinator assertions check both point velocities and combined momentum. |
| Settlement | Complete payload credit waits for the real freeze receipt. Credit removes the corresponding shard inventory, while the body stays fenced until physical removal and exact terrain receipts. Cancellation after World credit refuses. Duplicate completion cannot credit the same material twice. |
| Final native interval | The worker captures the exact final GCR packet and matching actor requests under its mutex, prepares it while the motion lease is held, and grants exactly one native tick. Newer requests remain queued. Internal lease waits do not invoke the actor/equipment pause path. |
| Publication and quarantine | Main checks the native receipt and exact actual-pose echo before counting segment completion. Missing or refused acknowledgement holds the runtime. Native partial failures quarantine the owner instead of advancing an interval. |

The native source still distinguishes rendered Water projection, raw stored
Water, pressure-held quantity and ballistic parcels. Moving-shard chemistry and
Sand lodging retain the admitted laws; no buoyancy, drag or new feedback law was
introduced. Authored recipe Save/Restore remains distinct from evolved physical
checkpoints. Those boundaries are retained in the [M4 contract](../research/objectshard-m4-workbench.md).

## Independent Windows native identity

The [new static Windows review](objectshard-m4-recovery-20261125/windows-native-recovery-review.json)
rehashes original artifact **14959065759** and its candidate provenance. Its
archive is **2,265,509 bytes**, SHA-256
`467f34bcb7b2c3cfcfbf90d8e4e274c44a5b9817357fc3079e5503f65a104a70`.
All 117 native source hashes and seven separately recorded build-contract
inputs match the original published source.

The native DLL is **6,196,224 bytes**, SHA-256
`9c939287f21b8d5b580b50464271a16b6aa235b6e71183eb434d607cfd966b4a`.
Independent parsing finds the actual PE signature, AMD64 machine `0x8664`,
PE32+ optional header `0x20b`, and the expected
`cybersand_native_library_init` export. Imports are KERNEL32 and UCRT API sets;
no dynamic MinGW/C++ runtime dependency is introduced. This static review does
not execute the DLL and cannot close Windows gameplay or GPU acceptance.

## Disposition and remaining qualification

**APPROVE preservation of the existing native implementation and its recovered,
exact-input native evidence.** No native law or capacity change is needed to
repair the known packaging and Linux acquisition defects. Any later changed
native input must receive the applicable source-bound requalification.

The existing native positives do not close the failing original aggregate
campaign, the successor's ordinary application matrix, pristine extracted
Windows replay, or physical owner performance acceptance. Those remain the
integration and delivery lanes' explicit gates. The final decision must bind
the actual package, producing source, runtime inputs and terminal reports.

## Independent review of the first integrated recovery changes

The [combined source review](objectshard-m4-recovery-20261125/combined-source-review.json)
binds the integrated delivery and optional recording changes to source
`c2e35326ddd615af971019d5a0a357e8ee3e0280` and records SHA-256 hashes for each
changed execution input. The disposition is **APPROVE for qualification**.
It is a code review, not a substitute for the successor's hosted results.

The recording checkbox and independent CLI flag affect only the bounded probe
and its renderer callback. Native control admission, Rapier stepping, geometry,
worker lifetime and completed-interval acknowledgements remain unchanged.
Stopping disconnects the callback while retaining the finished recording;
restarting gives a fresh recording epoch. Runtime cost counters remain active
independently. The new ordinary-control fixture challenges off/on/off/restart,
saved reports and native/worker identity preservation. Actual graphical
execution is required to qualify post-draw observations.

The delivery repair preserves exact committed bytes through one explicit
historical-provenance path mapping and binds replay to the extracted engine.
The historical ledger cannot become the candidate DLL's authority. Source,
tree, build, complete native inputs, size and runtime digest remain checked in
both Python and PowerShell. Independent execution of the twelve focused Python
provenance tests passed; actual PowerShell, shipped CMD and pristine package
execution remain successor gates. The MZ check is header sanity, while the
separate native archive review above parses the actual original PE identity.

Linux acquisition retains the same official engine archive, exact version,
size and digest with bounded retry. Neither that infrastructure repair nor
optional diagnostic recording changes native simulation laws or budgets.

## Evidence-reviewer adversity and earlier native failure

The [reproducible adversarial driver](objectshard-m4-recovery-20261125/challenge_workbench_evidence.py)
challenged the independent Workbench evidence review with thirteen altered
fixtures. Each synthetic ZIP received deliberately repinned metadata so the
test exercised its inner report, source and process boundaries. None of these
synthetic controls is application qualification evidence; the original archive
remained read-only and failed/incomplete in both reviewer versions.

The [before-and-after result](objectshard-m4-recovery-20261125/evidence-reviewer-adversity.json)
records six false passes before correction: omitted required footer, omitted
native input, omitted script input, synchronized unregistered footer schema,
partial inventory and absent inventory. The corrected reviewer at
`b1633d6fd01a2ceb3048c1ec82ea4c401e3d6697` admits **none of the thirteen negative
controls**. Wrong source/tree, changed log or receipt, duplicated footer,
removed registered case and changed launcher receipt also refuse. This
supports using the reviewer with an independently frozen complete inventory;
it does not replace execution of that inventory.

The [earliest native job recovery](objectshard-m4-recovery-20261125/earlier-native-job-recovery.json)
preserves the actual reason job **138593807280**, run **45435990124**, failed.
The original decoded log reports 95,563 sanitizer checks, 192 World tests and
74 benchmark limits passing, then exits with the native-parity output-path
guard: `--output inside the repository must be beneath build/; refusing a source overwrite`.
The workflow had requested `evidence/material-native-parity.json`. Its successor
writes beneath `build/` and copies the result to evidence, preserving the guard.
The aggregate historical job remains **failed**. The log's artifact digest is
recorded as an upload-log observation; that earliest large archive was not
downloaded by this review.

The [additional performance-control source review](objectshard-m4-recovery-20261125/performance-controls-review.json)
approves additive controls at `61213289c` for qualification. Disabled/enabled
controls use the same native recipe, camera and actor, with absent shard
attachment explicitly checked for the disabled case. Their comparison still
includes asymmetric qualification observer cost: enabled controls check
publication coherence every callback and draw, while the disabled fixture
does not install those observers. That difference must remain visible when
interpreting product overhead. Matched light recording on/off profiles share
the same coherence observer policy.

### Extended receipt-schema review

Two further negative controls exposed narrower gaps in that first correction:
the graphical overlay case could omit its receipt, and a profile could present
a synchronized but unregistered receipt schema. The reviewer now derives
literal case/schema pairs from the frozen qualifier's AST, including overlay,
render controls, disabled controls and the retained laboratory. It also derives
the unique Workbench profile schema instead of accepting an arbitrary successful
JSON footer.

The [extended fifteen-case report](objectshard-m4-recovery-20261125/evidence-reviewer-schema-adversity.json)
preserves both intermediate false passes and the corrected result: **zero
accepted negative fixtures**. The real predecessor archive still has integrity
PASS and application failed/incomplete. This is a review-tool correction only;
it changes no application execution input.

An independent reconstruction of the frozen successor inventory finds an exact
ordered match: **42 headless, 31 graphical-report and 16 extracted-package
processes**. The graphical report includes both display-required processes and
repeated headless cases; its process count must not be reported as 31 graphical
tests. The registration is bound to published source
`51903088118d2a04f2dc79dd6fff7c25b226970c`, exact local equivalent
`537ddef6e88eca2a59b8a02816a149601504dc7e`, tree
`a3f3e166f474d8c2a0d882cc9f7bb2adf21d8919`.

### Repeatable Windows native inspection

The [Windows native artifact reviewer](objectshard-m4-recovery-20261125/review_windows_native.py)
is prepared for successor custody checks. It independently verifies the
externally pinned archive, the complete Git-derived native input set, exact
candidate provenance, actual AMD64 PE32+ DLL header, native initialization
export and declared system dependencies. It separately records build-contract
inputs and can compare native input bytes against a predecessor without
claiming that equal native inputs qualify changed application execution.

Its [replay on the recovered original candidate](objectshard-m4-recovery-20261125/original-windows-native-repeatable-review.json)
passes with the same 117 inputs and DLL SHA-256 recorded above. This is static
inspection, not Windows runtime execution. Successor archive bytes and actual
Windows execution remain independently required.

## Frozen recovery source: native DLL, lifecycle coverage and fresh reopening

The new Windows native artifact **14978991924** from run **45517975210 attempt 1**
was independently inspected as actual PE bytes. Its
[static native review](objectshard-m4-recovery-20261125/windows-native-51903088-review.json)
joins the external ZIP digest, candidate provenance, all 117 frozen native
inputs, PE AMD64/PE32+ identity, entrypoint export and system-only import list.
The actual DLL is **6,196,224 bytes**, SHA-256
`d2028642909c1cfda2eb26e6257f8dbeb42689330f77872beaaf3ecc8f6d6d11`.
This hash is the independent native-runtime binding for the eventual evaluator;
it is not interchangeable with the predecessor DLL hash. The build and
application source are `51903088118d2a04f2dc79dd6fff7c25b226970c`, tree
`a3f3e166f474d8c2a0d882cc9f7bb2adf21d8919`. The Windows native job passed; static
review alone is not Workbench execution.

The [physical lifecycle claim map](objectshard-m4-recovery-20261125/physical-lifecycle-claim-map.json)
records 19 claim groups, their exact registered source assertions, 22 source
file hashes and the material limits of each witness. It distinguishes source
coverage from a passing source-exact runtime result. In particular:

| Requirement | Independently verified assertion scope |
| --- | --- |
| Final collider and ownership retirement | Actual Rapier point query sees the last one-cell body before explicit Cut; afterwards its RID and native owning inventory both disappear. This is not a natural whole-building burnout claim. |
| Final GCR and actor request pinning | Completed-sample case holds a newer Main packet until the captured interval; equipment case holds a late second actor request for the next admitted interval. |
| Pause versus internal wait | Explicit user Pause cancels pending usable intent; internal lease wait preserves it while all simulation clocks remain stopped. |
| Water conservation | Complete raw stored-cell census, pressure overfill and independent parcel quantity are distinguished from the material pixels drawn for parcels. |
| Settlement | Native credit, RID retirement and terrain acknowledgement are exercised through the runtime entrypoint used by ordinary tool 7; a separate mounted Settle mouse gesture is not counted. |
| Moving-cell editing | Real mounted Cut input and exact displayed-cell targeting are covered after genuine motion; most precise assertions pause first. Continuous held input during Play is source reviewed rather than a separate registered positive event. |

The fresh-process branch of the existing ordinary `test_workbench_canvas` was
also executed explicitly against an isolated copy of the frozen application.
The [process result](objectshard-m4-recovery-20261125/ordinary-authored-fresh-process.json)
records a natural successful author process with **199 checks** followed by a
separate natural successful reopen process with **23 checks**. Saved JSON bytes
were unchanged across processes. Both used independent user data, the pinned
Godot 4.7 engine, approved Rapier bytes and a sealed Linux native runtime whose
117 inputs match the frozen source. This is **local Linux headless authored
persistence**, not Windows execution or serialization of evolved physical state.

The [compact runtime custody](objectshard-m4-recovery-20261125/local-frozen-runtime-custody-summary.json)
identifies the complete 997-file frozen application map and exact Git archive,
engine/runtime hashes, the older native build source and its legitimate
input-equivalence relation. The
[retained runner](objectshard-m4-recovery-20261125/run_fresh_process_reopen.py)
is unchanged from execution and can be placed beside the described isolated
application and full custody map. Raw process logs and complete file maps remain
in the mission evidence directory with their hashes recorded. The M4-specific
named recipe fresh-process extension, ordinary 1024 start and visible 2048
refusal are separate bounded external observations still pending at this
checkpoint; the claim map does not count the obsolete unregistered scene-refusal
fixture as execution coverage.

Specialist B subsequently replayed the corrected long-burn fixture against its
established frozen-equivalent local Linux application: **233 checks, zero
failures, natural exit 0 in 32.275 seconds**. Native lifetime was exactly
**514 − 34 = 480 ticks**; the final Pause/display handoff completed one additional
already admitted interval, making the total 481. Actual terminal collider and
native inventory retirement also passed. The tested fixture hash is retained in
the clock review. Its successor changes only two derived receipt fields to name
lifetime and post-exhaustion ticks separately. The two earlier SIGKILL attempts
remain unsuccessful observations; this independent positive does not overwrite
them or qualify the forthcoming Windows execution.

## Held-pointer receipt precedes delivered geometry: reproduced product defect

The second recovery Linux Workbench job, at source
`422d131048db573c0abd08bcca25f6b3999e8703`, failed two held-pointer assertions in
the fragment/reabsorption case. Its later fragmentation, conservation and
settlement assertions passed, but the aggregate case and job remain failed.
The original process log is retained in artifact **14981832745**, archive
SHA-256 `fb17e5444456b1495f899fcaef28751d40da90372ce18ec7c78d33c0bce13f90`;
the process log SHA-256 is
`080b4c58229ad5763cd98808d21b0783f593f3fc2f78080f13a50ab24f37d5ba`.

A focused deterministic successor delayed only `Main._process` after the first
actual mounted pointer press. The real child Workbench input process and
exclusive native worker continued. No owner state, frame, receipt, physics pose
or native result was substituted. The callback was restored before every exit.
The fixture-only source is local `c658ea51516804ae920353de20b22a786babeb40`,
equivalent to the lead's `ec6e1ff328511c0b03f1d0c38f1b109885eb438f` test delta;
the product is unchanged from the published `422d1310` source.

The [actual failing reproduction](objectshard-m4-recovery-20261125/held-pointer-delayed-main-before.json)
completed naturally in **8.335 seconds**, with **32 checks and one failure**.
While Main remained delayed, the first Cut returned `Applied`, transaction 2
and geometry revision 2. Both current runtime frame and displayed publication
still had sequence 27 and `next_transaction = 2`. The held-pointer handler then
admitted a second request against that old geometry; the genuine terminal
result was `Refused`. There were two results and no pending request before Main
resumed. All 160 observed World/overlay identities remained coherent: a
coherent earlier publication was insufficient evidence that the completed edit
had reached the display. Native validation refused the stale request safely.

The reproduced defect belongs to ordinary input admission, not native material
mutation. The lead owns the narrowly scoped product repair: require the actual
same-incarnation displayed publication to have advanced beyond the validated
Applied transaction, in addition to the existing geometry/readiness checks.
The strict two-Applied-results requirement is preserved. This negative result
does not count as successful fragmentation or settlement execution.

The lead's correction `22b610dfaa16faf98df691cd0ccbaf9b43aebb50` was independently
reviewed, then replayed as local `a7a0998bbf5e8ffa26ab9a24f8378b081b737d36` with
the **identical fixture SHA-256** and native runtime inputs. The
[matched positive receipt](objectshard-m4-recovery-20261125/held-pointer-delayed-main-after.json)
records **132 checks, zero failures, natural exit 0 in 12.738 seconds**.
During the same delayed callback, the first Applied receipt remained the only
result while both retained publications still had `next_transaction = 2`.
Held tool 5 remained active. After Main resumed, exactly two correct Applied
source-cell cuts completed, release did not replay input, two physical
fragments activated, and surviving Wood was conserved. The unchanged later
case also passed real sleeping contact, native material credit, physical RID
removal and inventory retirement. All **577 display observations** were
coherent. This local positive preserves the baseline failure and requires new
source-exact hosted qualification before candidate admission.

The [independent repair review](objectshard-m4-recovery-20261125/held-pointer-fix-independent-review.json)
records the two changed product script hashes and the full before/after join.
The single latest-edit record is independent of the evictable diagnostic result
ring, admits only authenticated Applied mutations, keeps the maximum transaction
for an unchanged full owner identity, refuses conflicting owners and clears on
retirement. Existing native, physical and publication guards are unchanged.
This witness uses paused precise Cut input and the runtime settlement entrypoint;
it does not silently become a continuous-running Cut or mounted Settle proof.

The explicit mounted Settle gap was then closed by the registered fixture
successor `b9cb38d33748fc2d4a585199e28645fc594b49ee`, executed independently as
local source `7095a2358e3db51e9b175f44c3686bfef4d60909` with the same corrected
product. The [actual mounted-tool receipt](objectshard-m4-recovery-20261125/mounted-settle-local.json)
records **132 checks, zero failures, natural exit 0 in 11.933 seconds**. On the
naturally sleeping plank, ordinary mode 7 press/release advanced exactly one
reabsorption action from 0 to 1 and left a real staged native request with the
physical body still present. The later same-World completion credited the
canvas, retired the RID and native inventory, and retained zero uncredited
inventory cells. All **573 display observations** remained coherent. The
stronger delayed-Main check also requires the left-button held intent to remain
active. This is actual mounted Godot input routing in a local headless process;
physical pointer/monitor acceptance and the new hosted campaign remain separate.

The [runtime custody](objectshard-m4-recovery-20261125/held-pointer-reproduction-runtime.json)
records the exact pinned engine, native and Rapier bytes and all 117 native
input hashes. The older sealed Linux native build is used through explicit
source-input equivalence; no binary provenance was rewritten. The
[exact observed-process runner](objectshard-m4-recovery-20261125/run_held_pointer_reproduction.py)
is retained from execution at `build/recovery-held-pointer/run_case.py`; place
it at that relative path to repeat its recorded invocation. Raw logs and
resource observations remain outside Git with their hashes in the result.

## Existing carrier cache audit

The [cache source review](objectshard-m4-recovery-20261125/carrier-cache-source-review.json)
found no concrete invalidation defect in the existing seven packed carrier
arrays. Their key includes the full native handle and material revision.
Payload, role and incarnation changes advance that revision; due-time-only
scheduling changes do not alter cached fields. Scheduling-sensitive payload
digests, lifecycle, poses, geometry and acknowledgement state are rebuilt for
each snapshot. Fragment children receive a new identity before their first
snapshot, resets advance session identity, and ordinary World replacement
destroys the previous adapter and cache. This is a source audit of the existing
bounded cache, not a proposal to cache a full snapshot by material revision.
