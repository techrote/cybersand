---
title: GEN-006 persistent authored areas qualification
document-kind: evidence
status: Current
canonical-for: []
scope: Exact-source candidate qualification and independent review for GEN-006 #591; no general #194 completion or owner NVIDIA acceptance
keywords: [GEN-006, qualification, persistent areas, native continuation, crash recovery, Windows]
related-documents: [../systems/persistent-authored-areas.md, ../decisions/ADR-015-persistent-authored-areas.md]
last-reviewed: 2026-11-22
---

# GEN-006 persistent authored areas qualification

**Draft/HOLD.** This is the scoped three-area milestone approved in
[#591](https://github.com/techrote/cybersand/issues/591), not completion of the
broader [GEN-006 programme](https://github.com/techrote/cybersand/issues/194).
Physical Windows 11/NVIDIA owner acceptance remains unperformed.

## Source and qualification boundary

Accepted main was revalidated at `846fe0533b3170e7b01f690518da49fc40cc24d1`.
Its delta from the brief's `0f0161af337d6d0cee8fa961a9667aff570a75b0` is accepted
#714's documentation-only CI admission change. During final qualification, accepted
main advanced to `30e1cddd3d678456df10f52f7a2fb2210a9daaad` through #722
(CI-OPT-003 soliding compilation reuse). Its nine-path CI/Makefile/documentation
delta was integrated mechanically after qualified runtime publication. Main
then advanced to `662df51cd8409a52332fa7ef15d06d8ab8945aed` through accepted #723
(CI-OPT-003 bounded worldgen showcase scheduling). Its thirteen-path
CI/Makefile/documentation delta was also integrated mechanically. All three
roadmap additions were retained. Other active missions' branches and historical
evidence were not modified.

The renewed qualification source is
`1ceac7e3d4d9e9f6b24833ced340286a4a15d01e`, tree
`2ec8d34741ff48451a102fee1d1b5ff70a50d31a`, on
`exp/gen006-persistent-areas-001-20261121`.
[Dedicated qualification run 44963401260](https://github.com/techrote/cybersand/actions/runs/44963401260)
uses pinned source builds and the same explicit process matrix on Linux and
Windows. Subsequent runtime publication and final evidence commits must be
identified separately from the executed source; no earlier run is relabelled.

The final run passed all admitted native, Linux/Windows application, extracted
Windows evaluator and publication gates. Publication commit
`6bd6f1df03b37413931558ed32a53e80d8d22203` has exactly the executed source as its
parent and changes only the two native runtime files and two provenance files.
Both published LFS hashes and provenance blobs match the downloaded originals.

| Gate | Result and exact scope |
| --- | --- |
| Native continuation and independent-process restore | PASS; fixed tick/slice/worker comparison and atomic refusals; 13 independent original-evidence checks |
| Targeted ASan/UBSan native execution | PASS; same continuation fixture, no sanitizer failure |
| Linux Godot 4.7 application campaign | PASS; all 28 mandatory process labels plus import, actual graphical travel/edit/reopen and four deliberate process kills; 197 independent checks |
| Windows Godot 4.7 application campaign | PASS; same 29 process-result matrix and actual OS storage/recovery; 197 independent checks |
| Windows PowerShell 5 smoke guards | PASS; 13 actual-script stub cases plus four helper probes; 56 independent checks, shell scope only |
| Extracted Windows evaluator | PASS; graphical write PID 5524 / 290 JSON assertions, fresh reopen PID 8156 / 122 assertions, zero failures |
| Ordinary packaged Workbench launcher | PASS; PID 1540, 97 checks, native generation 2 and 15 completed native ticks |
| Original package bytes and dependencies | PASS; 1,270 payload hashes, 1,140 canonical source files, five x64 PE files and 69 declared import edges; no missing non-system dependency |
| Three-area saved identities and clock | PASS; all native/authoring/session identities retained after new-process reopen, all area and global frontiers at tick 260 in the portable smoke |
| Practical few-seconds transition target | NOT MET; measured latency and cold-package stall below |
| Physical Windows 11/NVIDIA owner acceptance | PENDING; hosted Windows used Microsoft Basic Render Driver through ANGLE |

The deliberately killed processes remain forced-termination rows followed by
successful new-process recovery, not ordinary exit-zero passes. JSON assertion
counts precede the final successful evidence-write assertion, so final stdout
has one more check. Independent byte review verified ten retained current/previous
manifests and their 30 native-payload references. Original package hashes pass
both before and after execution from an extracted path containing spaces.

| Retained artifact | SHA-256 |
| --- | --- |
| Windows native DLL, 6,736,384 bytes | `408283d6a5cf4db3830a20b971eb614f17161890bf268c63c405bdc2d219479f` |
| Linux native SO, 5,433,032 bytes | `1198c1a252cba4ae9ee14371f7b386f685155438bd3556b8640f04f9253ea977` |
| Windows evaluator ZIP, 101,117,366 bytes | `9081895fc6c0451cccbb3c31608f681749ebc663d539bcbc4de8addd31aa5ebc` |
| Final independent platform review JSON | `8e49121529ec8fd99e3e5974adb1dccce6d207bd3af1c2aee7c951b44e9fe673` |

The engine is pinned Godot `4.7.stable.official.5b4e0cb0f`. Linux uses the pinned
GCC 13.3 build; Windows uses LLVM-MinGW 20260826 UCRT / clang 23.1.0. Original
build logs, the 109 actual native input hashes per platform, runtime bytes,
engine/Rapier/toolchain identities and source/build/qualification ledgers are
retained in the run artifacts and detached evidence archive. Standalone native
test executable bytes were not retained by the hosted artifact; their recorded
hashes are external references, not independently recomputed binary evidence.

Independent accepted-main integration review verified that no product GDScript,
native source, extension build script, compiler/toolchain/dependency pin or
actual extension compiler command changed. After #722, the merged Makefile
SHA-256 was `31639c4d3e5e4962f059e3a1cb0ea9d029b3758f2de618a9d5b7a8e1992419df`.
After #723 it is `2e44322f7ea2ed0d56a8a280f2dca77699d56ce613c32c3f95a15ec7194f8490`.
All four persistent-area normal/sanitizer build/run dry-run commands remain
byte-identical to the executed source. The extension builders do not consume
this Makefile. Focused soliding and worldgen scheduling/inventory/custody
checks are separate from the product's retained native and graphical execution.

The Makefile nevertheless belongs to the broader qualification custody ledger.
Receipts and the unchanged evaluator therefore remain bound to `1ceac7e3`, not
the final integrated Git tree. Focused post-merge CI, publication/custody,
documentation, materialized-runtime provenance and retrieval checks establish
the integration boundary; they do not manufacture a later graphical campaign.
The final PR and detached delivery manifest record the final integrated HEAD.
Ordinary expensive Draft-suppressed gates are not reported as PASS, and a later
Ready/merge admission requires the repository's then-current applicable gates.

## Demonstrated state and temporal contract

One 512 × 512 actor-free Current/FreeMass area is active, with at most one private
prepared candidate during a transition. A is Industrial fire, B is Waterworks,
and C is Foundry gallery. Inactive authority is retained as full CYPS2
continuation plus the supported authoring/camera envelope. These are changing
native Worlds, not snapshots reconstructed from material IDs or seeds.

| Area | Original authored-source SHA-256 |
| --- | --- |
| A — Industrial fire | `1aa944a13ac05cba84e975a8699efdbf1e4126abeab2048e83f578d380c3693c` |
| B — Waterworks | `d49359be37c287adbc0dab237366b65b468d06099a5777ed278b65504f07553a` |
| C — Foundry gallery | `862193f3ef54fb8783acefb6d287d10bf2236faa9b90b38acd54a512baf23a52` |

The original validated construction definition remains separate from edited
native continuation and host observations. Capture retains material, explicit
Empty edits, temperature, activity/deadlines, supported solver quantities,
clocks, epochs, native events and quantity ledgers. Live host actors, Rapier
bodies/controllers, host emitters/equipment and unsupported solver domains
refuse at the owner/native boundary. The editor/camera is the traveller.

Game time credits completed native work. Each area's accounted frontier prevents
repeating an interval. Catch-up pays existing debt; Ahead first pays debt and
then credits only completed future ticks. An operation admits at most 600 ticks
and checks a three-second stepping budget between slices, each limited to 32
ticks and 100 ms between complete native ticks. Capture, storage, restoration
and an indivisible tick can add latency. Remaining future requests and existing
elapsed debt have different meanings and are shown separately.

The native alternative-strategy experiment refuses coarse skipping with zero
time credit. A sleeping scene at tick 20 reacts at tick 21; an epoch boundary at
256 changes full continuation while a simpler quiescent projection is unchanged.
There is no admitted certificate permitting the proposed skip. Exact bounded
stepping is therefore the selected strategy; no approximate solver is described
as exact or as having completed unperformed time.

## Native and process proof

The pinned native fixture progressed from tick 37 to 325 with slice sizes 1, 8
and 32 and configured workers 1 and 4, observing four workers. Full canonical
CYPS bytes and native quantity ledgers matched. The final physical hash was
`8f295356db4b2698`; an independent process reached the same result. Address and
undefined-behaviour sanitizer execution passed the same targeted native fixture.

Storage process tests use actual new PIDs and forced termination. A kill after
immutable staging restores revision 2/tick 10; a kill after manifest publication
restores revision 3/tick 13. Concurrent profile ownership refuses and releases
on process death. Old valid Worlds and authoring state remain available after
invalid native preparation or refused replacement. Corruption, incompatible
versions, stale fences and uncertain publication acknowledgements do not cause
seed reconstruction.

Crash recovery promises the last durably published checkpoint. Unacknowledged
active edits or ticks after it can be lost if the process dies before successful
publication; this implementation has no always-on edit journal. Ordinary
operation failures preserve the live World, while successful Save, travel and
bounded progression establish the durable boundary. Process-crash/I/O evidence
does not establish universal hardware power-loss or whole-application durability.

Independent additional actual Main/native execution at
`c4f7e9e2a87e5fab793c55d0e226b1d444c3fa07` closed the nonzero-debt restart case.
Its complete tracked `godot` and `native` trees are identical to the renewed
qualification source; that earlier execution is retained under its original
source identity. The final rerun used the exact qualified GCC13.3
Linux artifact (`1198c1a252cba4ae9ee14371f7b386f685155438bd3556b8640f04f9253ea977`),
pinned Godot 4.7, and headless actual Main. The original adversarial GDScript was
unchanged; source, native inputs, build ledger and runtime custody were verified
before and after. This additional fixture is not a Windows or graphical claim:

| Boundary | PID | Global game tick | A tick | B tick | C tick | B debt |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Partial checkpoint durably published, then SIGKILL | 7 | 900 | 900 | 96 | 0 | 804 |
| Genuinely new process validates retained state | 112 | 900 | 900 | 96 | 0 | 804 |
| B resumes exactly its remaining work | 112 | 900 | 900 | 900 | 0 | 0 |
| Final saved profile after visiting all three areas | 112 | 900 | 900 | 900 | 600 | 0 |

C's remaining 300 ticks were still explicit. B executed exactly 804 additional
ticks in contiguous slices and matched a separate uninterrupted tick-zero to
900 reference byte-for-byte: native SHA-256
`6eb89e1c113a1e2ff010f293af493f0e7be52fd18c460e91c672978a09f5fede`,
physical hash `9e8d67bbef97d843`. Destructive edits and real Wall markers survived
in every area. Final stdout reported 963 checks and zero failures; the JSON
receipt has 962 because its final successful write is counted afterward. The
first external harness's post-exit diagnostic access failed strict log checking;
its negative evidence was retained and the complete clean scenario was rerun.

## Independent review and repair

Native/persistence specialists and two wholly independent integrated reviewers
examined ownership, full state, integrity, time, UX, platform execution and
provenance. Confirmed repairs included nonzero-tick witness handling, source
body-dependency fencing, mutation ingress during capture, host event-cursor
admission, a stop race, duplicate preparation, ambiguous publication recovery,
and a capture completing after the controller deadline.

The last ownership defect was reproduced with an actual 31.5-second native-owner
capture delay against the production 30-second deadline. The repair retains the
exact unresolved token and operation, quarantines uncertain completion, and
acknowledges cleanup before enabling another mutation. Independent delta runs
passed 76 checks for late capture/commit and uncertain publication, followed by
41 checks for recovery followed by another unsaved edit and timeout. No confirmed
P1/P2 remains open in that reviewed integrity scope.

An independent clock model passed 14,992 checks over 2,500 deterministic active,
catch-up, Ahead, partial, replay and rebase operations. Independent platform work
repaired source-custody, process-ID, portable timeout arguments and PowerShell
receipt checks. Observation-only measurement review corrected cleanup-only
`owner_recovered` so it cannot masquerade as a completed Save. Thirteen adversarial
analysis-consumer checks cover deduplication, fault exclusion, truncated history,
changed evidence and wrong downloaded runtime bytes.

## Retained Windows failure and narrow tooling repair

The first pinned campaign, run 44955779630 at source
`c4f7e9e2a87e5fab793c55d0e226b1d444c3fa07`, passed native/sanitizer and Linux
qualification. Its Windows campaign recorded 29 functional process passes but
failed the final source-custody guard. Publication and packaging were correctly
withheld. The old observer did not retain its final differing identity, so that
historical mismatch cannot be identified conclusively and the run remains failed.

An isolated real Godot import with a Windows-style CRLF checkout reproduced a
matching failure mechanism: four tracked Rapier import descriptors were re-saved
with LF, while all 816 source hashes and their canonical HEAD contents remained
unchanged. The repair admits only these four tracked, canonically identical
working-copy rewrites, checks Git structural equality, and includes their hashes
in the source/publication contracts. Other source, staged, semantic, deletion,
rename and symlink changes continue to refuse.

The renewed runner retains full after-import and after-campaign observations,
including missing or changed binaries and source paths; the publisher verifies
the original file against embedded evidence and the actual source/runtime
identities. Twenty focused checks and thirty independent attacks passed before
renewal: ten actual Git cases, eleven rehashed original/embedded publication
attacks and nine filesystem forensic cases. This repair changes qualification
tooling, the explicit request and this audit; the complete tracked Godot/native
trees are unchanged.

The second pinned campaign, run 44959367569 at source
`f94e0ecbb9e4d7395ec343b6899426731e75ba79`, passed native, sanitizer and both
complete application campaigns, including the repaired custody observations.
Its extracted owner evaluator nevertheless failed: Windows PowerShell 5 treated
Godot's benign OpenGL-to-ANGLE warning on standard error as a terminating
NativeCommandError. File verification and PE dependency closure passed, but
portable execution and publication did not; its original failed ZIP is retained
under that outcome.

The packaging-only repair preserves native standard-error text without treating
the stream itself as failure. Null/nonzero exit status, Godot error markers,
missing or invalid graphical receipts and a reused write/reopen process ID still
refuse. Log-write errors remain terminating. An early Windows PowerShell 5.1 gate
executes the actual packaged script with native stub processes in thirteen
cases, plus four probes of the actual parsed invocation helper. These are shell
regressions, not CyberSand simulation evidence. The final extracted evaluator
subsequently passed real graphical write/reopen and ordinary Workbench execution.
Partial smoke output is now retained even after refusal. No Godot/native source
or persistence-format change accompanies this repair.

## Measured performance and resource outcome

**The few-seconds end-to-end transition target is NOT MET.** The final original
receipts were analysed without rerunning or altering product source. The
following are labelled completed travel operations, not Save/Ahead/bootstrap or
fault-injection timings. At these small sample sizes, nearest-rank p95 equals
the observed worst; this is not a reliable tail-latency guarantee.

| Process | Travel n | Median seconds | p95 / worst seconds | Actual native ticks/step-second | Whole-fixture max frame gap ms | Peak process MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Linux write-w1 | 6 | 5.487 | 6.282 | 128.36 | 4521.480 | 868.2 |
| Linux reopen-w1 | 3 | 4.702 | 4.814 | no native work | 4153.675 | 826.6 |
| Linux write-w4 | 6 | 5.238 | 5.906 | 206.39 | 356.870 | 664.4 |
| Linux reopen-w4 | 3 | 4.649 | 4.761 | no native work | 276.575 | 659.3 |
| Windows write-w1 | 6 | 16.085 | 18.148 | 77.03 | 1466.406 | 646.7 |
| Windows reopen-w1 | 3 | 15.251 | 15.664 | no native work | 1464.136 | 649.1 |
| Windows write-w4 | 6 | 16.133 | 17.517 | 153.28 | 1447.020 | 646.9 |
| Windows reopen-w4 | 3 | 15.314 | 15.409 | no native work | 1441.567 | 649.1 |

The separate extracted Windows evaluator measured 16.372 s median / 18.017 s
worst travel, a 65.295 s first open and a **40.743 s maximum main-frame gap**.
Its reopen measured 18.976 s to open and 15.441 s median / 15.455 s worst travel.
The scalar frame maximum has no timestamp or operation attribution. Shader,
import, resize, storage or capture cannot be asserted as its cause. This
unexplained cold-package stall is an explicit owner-evaluation limitation.

Actual measured native work in the four write cases was respectively 893 ticks
in 6,957,038 microseconds, 1,164 in 5,639,902, 772 in 10,022,635 and 962 in
6,275,906. These are successful native slices across area operations, not the
global game clock and not elapsed I/O/render/wait time. Interactive worker-1/4
cases have different accumulated game time and workloads; their rates are not
a controlled speedup result. Exact worker equivalence belongs to the fixed-tick
native fixture. Already-accounted reopen visits performed zero catch-up ticks.

| Successful-call median | Owner capture ms | Native capture subset ms | Durable acknowledgement ms | Prepared restore ms |
| --- | ---: | ---: | ---: | ---: |
| Linux write-w1 | 86.746 | 60.275 | 1080.958 | 773.549 |
| Linux write-w4 | 82.142 | 60.510 | 1041.276 | 734.151 |
| Windows write-w1 | 244.610 | 121.611 | 3330.766 | 2290.579 |
| Windows write-w4 | 252.814 | 143.538 | 3320.698 | 2333.266 |

Each write receipt has 26 successful capture calls, 47 durable calls and 14
prepared restore calls, mixing normal and recovery operations. Durability time
includes preparation, owner-fence checking and commit acknowledgement; it is
not pure filesystem flush cost. Native capture is included in owner capture.
Prepared restore excludes file read/validation and final adoption.

One/two/three-area bootstrap retained encoded state of 4.672 / 9.343 / 14.016 MiB,
with one live native World and 5.634 MiB current native cell capacity throughout.
Representative worker-4 process RSS was 534.445 / 560.852 / 566.438 MiB on Linux
and 543.141 / 551.172 / 556.512 MiB on Windows. These transient samples include
engine, rendering and serialization allocations; the differences are not a
measurement of isolated per-inactive-area heap ownership. Native cell capacity
is not the complete native heap. Inactive areas ultimately reside in serialized
checkpoints, not three continuously resident simulations.

All six ordinary post-travel inventories per write case retained three referenced
checkpoints, five tracked profile files and 14,704,452 bytes, rather than growing
with each visit. Final current/previous generations can retain an additional
checkpoint; this is bounded checkpoint storage, with no edit journal. Whole
process CPU averaged 2.54 / 2.68 logical-core equivalents on Linux and 3.78 / 3.78
on Windows. In the worker-4 observed active-play interval it was 2.33 / 3.61,
and in the complete catch-up operation 2.84 / 3.83. These include render/driver
and I/O work; active intervals use Play/Pause requests, not exact pause ACKs.

## Measurement interpretation and limits

Travel percentiles use labelled completed travel operations, excluding bootstrap,
Save, Ahead, cancellation and deliberate failures. Native throughput pairs actual
slice ticks with their measured native stepping microseconds. Waiting elapsed
time is not productive simulation throughput. Repeated terminal records for one
operation are cumulative; only its latest relevant terminal is counted.

Capture and durability arrays describe successful calls. Native capture time is
a subset of capture time and is not added twice. Prepared-restoration time
excludes earlier file reading/validation and final adoption; full operation time
is the end-to-end measure. Whole-process CPU includes Godot/native/render/driver
threads. Whole-fixture maximum main-thread gaps include resizing and fault cases.

One/two/three-area bootstrap samples measure actual retained encoded payload,
native cell capacity and process RSS. They do not establish marginal per-area
host heap allocation. Inactive areas do not retain independent live native Worlds.
Post-travel inventories measure bounded checkpoint growth; this implementation
does not introduce an edit journal. Exit/close are outside the operation metric
snapshot, although functional durable exit is tested.

## Owner evaluation and remaining programme

Use the source-matched Windows ZIP and the
[owner evaluation guide](../operations/persistent-areas-evaluation.md). It provides
separate persistent/ordinary Workbench launchers, isolated profiles, graphical
write/reopen smoke and failure capture. Profiles bind their exact native runtime;
copying them across another build/platform is refused rather than implicitly
migrated. Preserve the evaluator with its profile.

This milestone does not implement arbitrary actor/Rapier persistence, Wave or
unsupported solver continuation, background cross-area flux, arbitrary selective
chunk eviction, universal recipe reconciliation or an infinite shared World.
Normal production defaults remain unchanged. Physical Windows 11/NVIDIA display
and playfeel acceptance requires the owner's execution.

The next observed engineering boundary is lower end-to-end travel latency,
especially repeated validation/publication and preparation on zero-debt returns.
Optimize that bounded path while preserving complete-state checks, publication
fences, crash recovery and old-World retention, then qualify p50/p95 and frame gaps
on the owner's target hardware. This is more directly supported by the measured
cost than expanding to arbitrary streaming at this milestone.
