---
title: GEN-008 native material Flatten qualification
status: Current
document-kind: evidence
scope: Dated source boundaries, preimplementation failure, local native and persistence evidence, and exact-source Windows/Linux acceptance routing for issue 548
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [../architecture/shared-workbench-authoring-data.md, ../operations/gen008-flatten-qualification.md, ../reference/level-saves-and-replay.md]
---

# GEN-008 native material Flatten qualification

## Ownership and authoritative scope

The task begins on accepted main `ac0d9fb944cb5a81369d03c0c3bc5eab50ab6742`
(tree `05d2960d569719cdc85b44228950eb14fa0d4c66`), including merged #564/#565.
[Issue #548](https://github.com/techrote/cybersand/issues/548)'s 11 November revised
specification is authoritative. The old World-replacement, actor-respawn,
tick-zero, 8-bit and Undo-Flatten proposal is withdrawn. The implementation
branch is `feat/gen008-flatten-material-baseline`; keep its sole PR Draft/HOLD.
No merge or Ready promotion is authorized. Independent #566 camera and #569
experimental training sources are not imported.

The [canonical authoring contract](../architecture/shared-workbench-authoring-data.md#flatten-and-storage-compatibility)
owns current semantics, native ownership, generation fencing, format and limits.
The [qualification runbook](../operations/gen008-flatten-qualification.md)
owns reproducible commands and the Windows Owner acceptance procedure. Original
Actions artifacts and the PR ledger identify each executed source, tree, runtime,
platform result, checksum, measured cost and any failed campaign. A dispatch or a
Draft-skipped check is never a completed test.

## Initial failing controls

Before implementation, `test_workbench_flatten.gd` reflected the unchanged
Shared Workbench at `ac0d9fb944cb` and failed all three checks for missing
`request_flatten`, `is_flatten_pending`, `get_flatten_status`. The final red run
used official Godot 4.7 and materialized accepted native/Rapier dependencies,
exited 1, and had no unrelated script errors. An earlier unmounted-UI version
emitted cleanup leaks; that original failed log was retained and the reflection
fixture corrected before recording the clean negative.

The new native regression also failed against that starting implementation:
`native/tests/test_material_baseline.cpp` could not include the absent
`cybersand/material_baseline.hpp`. The standalone format test first refused the
absent module, then the absent native validation method after the script was
introduced. The initial LFS-pointer warning attempt is retained separately from
the hydrated native control.

## Local native and format checkpoint

Local iteration uses official Godot `4.7.stable.official.5b4e0cb0f`, exact
`godot-cpp` revision `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1
with wheel SHA-256
`bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126`.
Local GCC 14.2 is an explicitly labeled toolchain drift from pinned hosted
GCC 13; these results do not replace final Linux/Windows release qualification.
The local O3 extension SHA-256 is
`b9cd7267159d635b697d5752267801ebeaa233b1d5839b016f55d7ebf40d789c`
(4,478,648 bytes). The checkpoint native source/build input hashes are retained
in the local original `native-local-identity.json`.

Native tests cover every supported ID, Empty, row/final-cell boundaries, masked
fractional Water, temperature and state lanes, detached buffer ownership, bad
lengths/dimensions/capacity, reserved/wide IDs, in-progress ticks and failed World
refusal. A real Water-to-Ice transformation is captured; capture preserves full
physical-state hash, tick, masks and quantities, and the same World ticks again.
`native/src/world.cpp`, material laws, catalogue, live cell storage, camera and
shader sources are unchanged.

| Full resident native plane | Exact bytes | Native copy | Native validation |
|---|---:|---:|---:|
| 512² | 524,288 | 1.259 ms | 0.206 ms |
| 1024² | 2,097,152 | 8.124 ms | 0.826 ms |
| 2048² | 8,388,608 | 21.225 ms | 3.499 ms |

Native test process peak RSS was 86,164 KiB. These are fixture measurements,
not complete Workbench memory or graphical response claims. An earlier sparse
resident measurement remains a separate historical log.

The native-backed standalone format suite passed **87 checks**, including exact
bytes, unsupported versions, checksum-valid bad metadata/IDs, truncation,
corruption, incomplete staging, atomic replacement failure, old-reader routing,
ordered Empty overlays and packed-array alias mutation. Full script time was
1.100 seconds, peak RSS 157,216 KiB.

| Plane | Detached staging | Save | Read/validate | Complete file bytes |
|---|---:|---:|---:|---:|
| 512² | 2.848 ms | 4.846 ms | 5.215 ms | 525,042 |
| 1024² | 11.615 ms | 21.262 ms | 25.560 ms | 2,097,911 |
| 2048² | 49.200 ms | 93.605 ms | 97.585 ms | 8,389,367 |

ASan/UBSan passed locally with only LeakSanitizer disabled. The original enabled
LeakSanitizer run failed at shutdown because this executor uses ptrace; the
failure is retained, not relabeled. Hosted sanitizer execution retains leak
detection. Full Workbench capture, adoption, future edits, actor identity,
fresh-process loading and graphical responsiveness are separately measured by
the source-matched qualification runner, including process RSS per phase.

## Review findings and repairs

GDScript packed-array assignment can share a mutable array. Staging now uses an
explicit detached copy, and the prepared packet separately detaches its payload;
regressions mutate old receipt/packet aliases and require the baseline to remain
unchanged. No native World memory is ever borrowed.

Paused Flatten intentionally leaves native generation, revision and tick intact.
A separate authoring generation therefore fences old PAINT requests, while
existing agent epochs fence late chunks/model responses. Successful adoption
also retires the provider's pending-run UI state. Old construction/Undo history
is discarded only after complete staging and final lease validation; refusal or
Cancel retains the existing authored state and saved starts.

Independent integration review found that failed-owner **Reset / R** still
carried only the Setup-v2 recipe through the old recovery envelope. After
Flatten that would lose the baseline. Reset now refuses this unsupported
recipe-only recovery path for generated/material starts, as Restore already
does; the original authored state remains intact. A later review found that Save
still inherited the general failed-owner refusal, leaving an unsaved retained
baseline without that recovery route. The correction and its separate required
native-fault/fresh-process gate are recorded below.

The first complete fresh-process oracle found a real integration defect:
`microscenario_host.gd` forwarded generated terrain but omitted the standalone
material-baseline packet. The saved file plus its three ordered edits exactly
matched the independent expected plane, while the installed native plane was
entirely Empty. The missing forwarding seam is repaired and included in source
custody. The corrected 512-square run passed **193 author checks and 42
fresh-process checks**, including complete native-array equality, subsequent
editing, Restore and actual owner-thread shutdown before adoption. Failed
iterations and the observed/expected raw planes are retained separately.

The accepted legacy history fixture also passed in separate author/reopen
processes: **1,884 author checks and 1,920 reopen checks** for Setup-v2 and
generated-start-v1, including detailed history beyond 4,096 rectangles. PAINT
executor validation passed 21 checks after the added authoring-generation fence.

A local graphical diagnostic used the actual Workbench buttons in official
Godot 4.7: generated a 1024-square GEN-007 map, painted Sand, ran simulation,
confirmed Flatten while playing, observed the 2,097,152-byte success status,
paused and painted another 197-cell stroke, then explicitly saved. After fully
terminating that Godot process, a new process loaded the baseline directly
without the generator dialog. The settled pre-Flatten Sand and subsequent mark
returned; another 197-cell brush edit, Undo and Redo succeeded visibly. This
development-machine interaction is separate from the source-frozen hosted
graphical receipts and from Owner acceptance on the physical Windows PC.

Real local Save-fault controls target an existing valid named start. A 65,536-byte
Linux file-size limit causes a partial write and explicit refusal while the old
file remains byte-identical. A separate process is actually killed by SIGXFSZ
during writing; the observed partial temporary is ignored, the previous named
file remains intact and a normal retry succeeds. Hosted Windows must separately
prove refusal/recovery when the existing target is locked against replacement.

The capture receipt distinguishes native copying, native capture including
hashing, the complete GDScript/native call boundary, and the main-thread
worker-result handoff. The last measurement alone is not cross-language capture
cost. Full-plane scans stay bounded; no borrowed World buffer is exposed.

### Windows replacement correction after the first campaign

The first hosted campaign started at source
`99c4b482e4ada19838f24539640ee9e901ad3e17`, tree
`e6c92ca26d525082b3b10b4e70683c6acb44cf37`, run `43516454193`. Its native
ASan/UBSan and 231-test Linux catalogue results passed, but it is preliminary
evidence rather than final acceptance.

Review of the pinned [Godot 4.7 Windows implementation](https://github.com/godotengine/godot/blob/4.7-stable/drivers/windows/dir_access_windows.cpp)
found that ordinary `DirAccess.rename` removes an existing destination before
attempting the move. The first baseline writer had reused that operation, leaving
a Windows failure window. A locked destination cannot expose this gap because its
deletion is refused immediately. The stronger control locks the completed source
temporary against moving while leaving the existing destination unlocked.

The baseline writer now uses a narrow native same-directory replacement primitive:
Windows `MoveFileExW` with replacement/write-through and no copy fallback, POSIX
`rename`, and no pre-deletion. The normal writer remains responsible for complete
staging, byte-count/integrity validation and temporary cleanup. The regression
requires both source and previous destination to survive a refused replacement,
then verifies successful replacement after the lock is released. Unicode paths,
missing-source refusal and successful overwrites are also checked. Legacy formats
and their existing writers are outside this scoped correction.

The final Linux/Windows campaign must rebuild and execute the corrected source;
the first campaign's build or execution results cannot qualify this change.

The local corrected extension is 4,493,160 bytes with SHA-256
`b4f0a70d92bb4626ac1e582cc2438a0ec24934d18b4dbb05b1892f025aa69deb`.
It passes **102/102** native-backed format/atomic-save checks, including an actual
Unicode user-data directory and paths longer than 260 characters. The focused mounted 512² Workbench passes **193**
authoring checks and **42** checks in a separate fresh reopen process; real Linux
partial-write and process-termination faults preserve the previous named save.
This is local diagnostic evidence with the same explicitly recorded compiler
drift, not a substitute for the successor hosted campaign.

The initial atomic-replacement publisher admission passed **13** guards, including nine adversarial
locked-source receipt mutations. The Windows runner retains the actual complete
source and old destination before/refusal bytes and the successful retry's bytes;
publication independently hashes those files against the original child logs.
The native helper is listed in all three existing extension build source lists
(Linux, Windows and Web); the Web edit only preserves link compatibility and
does not claim additional Web qualification.

### Settled authored Save after native owner quarantine

The second campaign ran source
`529c5df85193363f7e67d5153590157da15dc908`, tree
`f3326887dd24f374a3173585b15f678a18b5e5b6`, run `43520857816`. Its original
native contract and ASan/UBSan artifacts passed with the target's default leak
detection enabled. The original Linux catalogue reports **231/231 tests**, no
skips, failures or errors, in 474.226 seconds. Source/tree identities and artifact
digests were read back independently. The native artifact SHA-256 is
`6cdfafa587f54b08da5540fe40c708397156d1f617e2df85c69c744f91e97031`;
the Linux catalogue artifact SHA-256 is
`bb7bcb7e9a9e343b57ffc6ae50c4a0ecdf430ac5b18ed656df3920db585482ff`.
These results remain evidence for that exact source and its atomic replacement
helper. The campaign is preliminary for final acceptance because it predates the
following Save admission correction.

The previous `save_setup` entry used the ordinary editing `busy()` gate, which
includes native-owner failure. That correctly prevented editing but also refused
writing an otherwise settled retained authored document. The correction introduces
Save-specific admission. It retains pending prepared/step/Flatten guards, worker
edit/receipt slots, agent/manual queues and the PAINT editor's partial-history Save
hold. It repeats these checks after polling agent completions. Only the failed-owner
condition is excluded; general editing admission remains unchanged.

The final admission rule additionally refuses any four-field legacy disc recipe
after owner failure. These intended brush instructions lack individual native
acknowledgement; their execution cannot be established from a quarantined owner.
This is a conservative refusal even when an older instruction may have executed.
The complete authored document and valid saves are preserved. Healthy Save and
legacy readers are unchanged; retained material baselines with acknowledged
five-field PAINT/Art overlays remain eligible under the other Save fences.

The existing format writers persist retained authored data without reading the
failed native World. A successful Save leaves the owner quarantined and directs
the user to completely exit, restart and Load. Flatten and unsafe recipe-only
Reset/Restore refuse with the same recovery guidance. This allows an acknowledged
flattened baseline that was never saved before the fault to be retained without
claiming recovery of runtime physics or unacknowledged edits.

The required new gate causes an actual native capacity failure after Flatten and
acknowledged edits. It must prove that Save leaves the failed owner untouched,
then terminate that process and reopen the saved start in a fresh process for a
complete native material-plane comparison and continued authoring. The two
processes join the source, runtime and delivered-package qualification inventory;
synthetic fault/receipt checks cannot substitute for them.

The final focused local pair passed **53 author checks and 44 fresh-process
checks** using official Godot 4.7, Linux headless execution and the corrected
extension `b4f0a70d92bb4626ac1e582cc2438a0ec24934d18b4dbb05b1892f025aa69deb`.
The real owner recorded exactly one scheduling-core capacity failure on attempted
tick one. Save preserved that owner's instance, generation, Rapier session and
three history entries. All ten admission/failure controls passed, including the
unconfirmed legacy recipe refusal. Pre-fault native cells, independently expected
cells, saved reconstruction and fresh-process native cells each contain 524,288
bytes with SHA-256
`c3c3539252b1fc959405f6d4421fea004808158b20abfa99b7e933c2e07e4fb7`.
Manual/agent edits and two Undo/two Redo operations continued after Load. Measured
Save was 15.499 ms; the Load transaction within a fresh process was 1,202.785 ms
on this local fixture. That transaction timing excludes Godot startup.

The superseding original logs are `owner-failure-final-local/author.log`
(SHA-256 `76c22eee07be9cb24d29bc3b51c786b67df630eac476d6eb18db67a6867f62d0`)
and `owner-failure-final-local/reopen.log`
(`f78bff39bd5b8b7f21ed6ab0e2517bfa606406adb0d9871127664dd43a9d8ac2`).
Both receipts bind `shared_workbench.gd` to
`1dc55ceca214483cf52f8adf0a6a2e470cd676e2db8776391edeca800c586c37` and
`test_workbench_flatten_owner_failure.gd` to
`eee94613fedb853ce5a99ed680cd09823258595b9d90022d5c9d1baf32b56d50`.
This is local diagnostic evidence with the recorded compiler drift. Final
acceptance still requires a successor source-bound graphical Linux/Windows
campaign that includes this correction and the new evidence.

### Windows qualification defects found in original artifacts

The original Windows execution from run `43520857816` failed the locked-source
control. The fixture opened the completed temporary source with desired access
zero and read/write sharing. Native replacement then succeeded, consumed the
source and replaced the old destination. This control had not established the
sharing denial it claimed, so its failure is retained and cannot qualify source-lock
failure atomicity. The native replacement helper is unchanged by this correction.

Microsoft's [MS-FSA sharing-access algorithm](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fsa/8c0e3f4f-0729-49f4-a14d-7f7add593819)
includes an existing open in these sharing checks only when its granted access
includes data read/execute, data write/append or delete. The corrected fixture
holds `GENERIC_READ` with read/write sharing and no delete sharing. Before calling
the production helper, nonmutating `OPEN_EXISTING` probes require source `DELETE`
access to fail with Windows error **32**, while the old destination allows that
access. These probes request neither deletion nor delete-on-close. Original probe
receipts are retained and verified with the unchanged requirements for exact
source/destination byte preservation, same-source retry and source consumption
only after successful replacement.

The same original-artifact review rejected the approximately **4.86 MiB** Windows
memory observations: the sampler followed Godot's console launcher rather than
the engine process that owned the World. Those observations are not valid engine
RSS/working-set evidence. `MeasuredRunner` now invokes the sibling
`Godot_v4.7-stable_win64.exe` directly from the same pinned archive, retains the
requested and actual executable paths, and records the actual executable SHA-256.
Native-backed normal/recovery receipts must report the measured PID. Publication
also binds the engine hash to the pinned validation record; delivered-copy checks
bind it to the package's own engine inventory. No source instrumentation or
product simulation behavior is changed by this measurement correction.

The next candidate before these fixture corrections was source
`b55b0418400100d9317acc57f24e0e63b3f80cf9`, tree
`46dc0ba711d30ccd648cdd317b16310e5b29d4ca`, run `43524245266`. Its original native
contract and ASan/UBSan execution passed with leak detection enabled. Its complete
Linux catalogue passed **231/231 tests**, with no skips, failures or errors, in
478.429 seconds. All 92 native source inputs and 852 build inputs matched the
frozen Git blobs. The native artifact SHA-256 is
`23b43d562b63c9913af9ba641c1350cde73da606f915228abd2599c7f194756c`;
the catalogue artifact SHA-256 is
`5ece5274b89233bff5c67d7cbe0e98ba3bc16224bc7a5c1869fc13dab7c1f52d`.
These remain source-specific successes. Its Linux runtime execution was still
pending at this documentation checkpoint, and its inherited Windows fixture
defects prevent this campaign from establishing final acceptance.

Publication request sequence **4** requires a successor full campaign. Windows
first runs a separate bounded 512² diagnostic, retaining its original artifact,
to expose platform storage/memory failures before the longer retained suites.
The complete twelve-record Flatten source and delivered-copy gates remain
unchanged in scope. A diagnostic success cannot replace the full matrix, and no
corrected Windows pass is claimed at this checkpoint.

## Hosted acceptance and remaining authority

The dedicated qualification workflow reuses the accepted MAT-AUTH/Workbench
publisher, complete source/installed regressions and package custody checks.
Both actual target OS runs must pass the complete native-backed Flatten matrix
at 512², 1024², 2048² and a separate four-worker case; all required phases,
checksums, native array witnesses, fresh-process identities, graphical images,
performance and process-memory records are independently read back. The additional
genuine native-fault Save/reopen pair is mandatory on both platforms and in the
delivered-copy smoke. An exact
four-path, leased runtime/provenance publication precedes the final independent
Documentation, Native, GDExtension/Godot and relevant Palette gates.

The original artifacts and sole PR's live ledger are the completion authority.
This file records the initial source-local evidence and tested design decisions;
it does not claim a hosted campaign has passed merely because it was configured.
Owner graphical acceptance on the physical Windows PC remains distinct from
all automated and hosted graphical tests. A technical GO never authorizes merge.
