---
title: ULTIMA authored-save persistence correction and qualification
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Candidate implementation and independently reproduced storage failures; no merge or physical acceptance authority
last-reviewed: 2026-11-25
---

# Authored-save persistence: implementation and evidence

**The predecessor's inherited save limitation is a reproducible software defect.**
An unmodified ordinary `Setup.write_named` call at predecessor
`20170bd6259498c3d2774ab274567febb043fc1d` reported success after replacing a valid
475-byte save with 128 bytes of invalid JSON. The test used actual Linux
`RLIMIT_FSIZE=128` with `SIGXFSZ` ignored, exact Godot
`4.7.stable.official.5b4e0cb0f`, the materialized source-matched native runtime,
and a disposable application profile. This was not an injected return value.

The [before receipt](before-buffered-flush.json) records both digests, the empty
error and failed reload. The [reproduction child](before-save-reproduction.gd.txt)
calls the real public writer. The prior closure correctly said it had not run
fault injection or observed data loss; this mission supplies new evidence.

## Independently identified failure mechanisms

| Finding | Observed or traced failure | Correction |
|---|---|---|
| A-ULT-01 / LIMIT-03 | Pinned Windows `DirAccess.rename_absolute` removes an existing destination before `MoveFileW`; a subsequent failure can lose the previous file. This old mechanism is source-confirmed; new-source Windows lock tests are independently verified below. | Reuse the existing native same-directory replacement primitive in all three affected writers. |
| A-ULT-02 / LIMIT-03 | Pinned Godot `flush()` discards `fflush` errors and `close()` exposes no `fclose` result. A buffered short write can leave `get_error()==OK`; the real Linux reproduction silently committed truncated bytes. | Check `store_buffer`, flush state and closed-file readback. Require exact length and exact bytes before native replacement. |
| A-ULT-03 / LIMIT-03 | Generated/project errors claimed atomic replacement or prior-file preservation without the required mechanism. | Shared refusal says this save did not replace the previous file; failed cleanup additionally identifies retained staging. Success is emitted only after native commit. |

Upstream source is pinned to Godot stable commit
[`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`](https://github.com/godotengine/godot/commit/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88):
[Windows rename](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/windows/dir_access_windows.cpp),
[Unix write/flush/close](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/unix/file_access_unix.cpp),
[Windows write/flush/close](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/drivers/windows/file_access_windows.cpp).
Their exact blobs and independent preimplementation observations are in
[the observation register](independent-observations.json).

## Scope, format compatibility and logical-save boundaries

| Entry point and on-disk format | Whole logical save | Dependent data and recovery boundary |
|---|---|---|
| `Setup.write_named`, Setup-v2 JSON | One `user://workbench/setup-<name>.json`; validated actors/equipment, authored edits and controls are embedded. | Packaged actor definitions and the source-matched runtime are application dependencies. This save creates no companion files. |
| `Generated.write_named`, generated-start-v1 JSON | The same single named path, containing resolved generation recipe, provenance and `starting_setup`. | Material cells are regenerated and source-identity checked on reopen; they are not a separately replaced companion. Original external recipe/style files are unnecessary. Explicit installation still follows preview verification. |
| `ArchitecturalGenerator.save_project`, project JSON | One selected project file containing complete selected/custom presets and controls. | Import copies the selected preset into the project. The existing UI test deletes the external preset before reloading the saved project successfully. No companion update is required. |
| `MaterialBaseline.write_named`, material-baseline-v1 | One container: header/checksum, JSON manifest and complete uint16 plane. | The stronger existing native-backed writer remains unchanged. A fresh tail-write fault test and its full 102-check regression retain its separate guarantee. |

All three authored-start readers still share the original named path and sniff
the format in `SharedWorkbench.load_setup`: material baseline, generated start,
then ordinary setup. No format version or serialization content changed. A
same-name format transition replaces one whole file. There is no multi-file
commit window in these formats; adding a multi-file transaction framework would
not repair an existing logical-save requirement.

Source locations:
[`shared_workbench.gd`](../../../../godot/scripts/shared_workbench.gd),
[`workbench_setup.gd`](../../../../godot/scripts/workbench_setup.gd),
[`workbench_generated_map.gd`](../../../../godot/scripts/workbench_generated_map.gd),
[`architectural_generator_dialog.gd`](../../../../godot/scripts/architectural_generator_dialog.gd),
[`architectural_generator_project.gd`](../../../../godot/scripts/architectural_generator_project.gd),
[`workbench_material_baseline.gd`](../../../../godot/scripts/workbench_material_baseline.gd).

## Implemented transaction

Each owning format keeps its existing name, payload and size validation. It then
calls [`workbench_file_transaction.gd`](../../../../godot/scripts/workbench_file_transaction.gd):

1. Resolve a bounded absolute file target and require the existing native
   replacement capability. An old/missing native runtime fails closed before I/O.
2. Select an unused 128-bit random sibling staging name, with at most eight
   collision attempts. Existing regular files, directories and dangling links
   count as occupied names.
3. Write the bounded payload, flush and close. Refuse any reported failure.
4. Reopen the closed staging file and compare its exact length and bytes with
   the validated payload. This step detects buffered flush/close failures that
   the Godot error field does not expose.
5. Commit through unchanged
   `CyberDemoBridge.replace_material_baseline_file`. The native implementation
   validates absolute sibling paths, distinct regular non-link endpoints and
   distinct file identities. It uses POSIX `rename` or Windows
   `MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH)`; it does not explicitly delete
   the previous file or fall back to copying across volumes.
6. On refusal, remove only this operation's staging file when possible. If
   cleanup fails, show its exact remaining path and say it is not a committed file.
   A later save ignores old staging files and does not promote or delete them.

The helper's testable I/O object is constructor-level dependency injection.
Production callers never read fault-injection environment variables or activate
test behavior. Only test scripts wait for the OS-fault harness.

## Verified failure model and limits

The contract covers ordinary application I/O failures and complete-file
replacement on the tested filesystem. POSIX same-volume rename supplies atomic
name replacement. The Windows implementation avoids Godot's explicit delete gap;
actual sharing-lock execution is recorded separately by the Windows runner.

This is **not power-loss durability**. There is no general file-fsync/directory-
sync contract, no storage-controller guarantee and no tested sudden power cut.
Reopening and comparing a file proves observed bytes, not persistence to media.
Windows `WRITE_THROUGH` does not establish every durability guarantee.

Workbench writes are synchronous on their owner thread. Separate processes use
separate staging files and complete commits are last-writer-wins; there is no
cross-process edit conflict detector. The tested concurrent case verifies that
two writers publish a complete document, never a mixed payload.

Staging uses `exists` followed by `FileAccess.open`, not `O_EXCL`. The 128-bit
random name protects against accidental collision; the design does **not**
claim protection against a malicious process that can mutate the same directory
between checks or rewrite a staged file after verification. Final and staging
endpoint links are rejected at native replacement, and pre-existing staging
links are not opened. Ancestor-directory reparse/race attacks, hostile storage
and cross-process tampering are outside this application-local failure model.
No such stronger security guarantee is added to the manuals.

A process killed before native commit leaves the previous complete file and an
ignored temporary file. The harness verifies this exact boundary and a normal
retry; it does not call this a crash/power-loss acceptance test. A process killed
after commit may lose its UI acknowledgement while the complete new file exists;
the user should reopen the named save to determine its contents.

## Executed qualification

The exact integrated checkpoint
`bfa40c84964b10b8bc15b2d836ce93d389f20836` (tree
`6f7e761d64db191d0bc94f3568440ca017274047`) passed the non-publishing
[Linux and Windows hosted workflow](https://github.com/techrote/cybersand/actions/runs/45697930828).
The [independent archive readback](hosted-independent-review.json) verifies all
three archive digests/CRCs, every recorded normal-process log digest and all
57 public-writer result records directly against their archived log lines.
This readback is an independent review of actual hosted execution, not a new run.

| Platform and observed scope | Fault matrix | Normal functional regression |
|---|---|---|
| GitHub Linux x86-64, glibc2.39 | 13 cases; 84 focused checks. Real file-size limit, directory permissions, post-staging rename refusal, process kill/retry and concurrent complete writes. | Nine workflows plus import, all natural exit 0, no skipped cases. |
| GitHub Windows Server 2022, build 20348 | 10 cases; 75 focused checks. Actual destination locks for all three writers, staging lock with unlocked destination, process termination/retry and concurrent complete writes. POSIX symlink checks are excluded. | The same nine workflows plus import, all natural exit 0, no skipped cases. |

The normal-workflow assertion counts on **that checkpoint** are material
baseline 102, architectural project 61, generator discovery 27, painting 1884 and
fresh-process reopen 1920, canvas 199 and reopen 23, generated authoring 77 and
reopen 24; all report zero failures. Later UI fixtures retain their own source
identities and results instead of being attributed to this earlier hosted run.

On Windows, delete-access probes for all locked targets return error 32; actual
replacement refuses with error 5, and old material 2/project seed 123 bytes remain
loadable. After unlocking, retries store material 14/seed 456. The stronger
negative control locks only the complete staging file and leaves the existing
destination unlocked. Native replacement then returns error 32, retains the old
46-byte file and its digest, and honestly reports retained staging. Removing
the lock permits a successful retry. This directly exercises the point at
which a delete-then-move strategy could lose the old file.

Both platform input maps contain 4,215 tracked paths. Their 417 differing
working-file digests are independently proved to be LF/CRLF checkout conversion
of the exact Git blobs; the remaining 3,798 digests match. The separate map
digests preserve the actual tested bytes. All 18 LFS objects are materialized;
identity verification remains distinct from runtime execution. The Windows
native DLL SHA-256 is
`668f2dd094fca611a97c2b6aa38c4cd072179fe9cf591e53578ef57c7db1625e`.
No hosted result here claims a physical NVIDIA host or power-loss durability.

The earlier [final Linux OS matrix](persistence-linux-final.json), at source
`fb0ebc9e`, has **13 passed cases** and **84 focused checks**, including three-format fresh-process save/reload, three real limited
write refusals, three permission-denied refusals, real native rename refusal,
forced precommit process termination/retry and concurrent complete replacement.
Every failed replacement retains the old digest and a loadable old document.
The native rename refusal deliberately removes write access only after closed
staging verification; cleanup fails too, and its retained-file message is checked.

The [latest focused test](persistence-focused-latest.json) passes **84 checks**.
Ten injected fault boundaries cover capability, staging creation, partial write,
silent truncation, same-length corruption, flush, close, readback, replacement and
cleanup. Actual native cases cover normal replacement, Unicode new files,
missing directories, directory collisions, final symlinks and pre-existing
staging symlinks. Injected close/flush failures are explicitly synthetic; the
Linux size limit is a real OS failure.

The [material-baseline comparison](material-baseline-tail-fault.json) limits
the real file to eight bytes short of its complete size. Its unchanged writer
refuses, retains the old digest and reloads the old material plane. Existing
regression observations and runtime input digests are recorded in the
[regression report](persistence-regressions.json). The earlier
[initial matrix](persistence-linux-initial.json) is preserved separately and is
not relabelled as a later source run. Final integrated normal-workflow execution
retains its own natural-exit receipts. The final fault matrix also asserts the
intended replacement values (material 14 and project seed 456), beyond changed
digests and successful parsing.

Linux engine SHA-256:
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Materialized native SHA-256:
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`.
Native source and the material-baseline writer have not changed in this fix.

## Additional authored-profile defect: A-ULT-12

The final writer-perimeter audit found four more user-facing paths that opened
their final destination directly and acknowledged unchecked buffered writes.
The [before receipt](profile-save-before.json) uses the actual public methods,
native configuration and format readers on unchanged source. Every tested method
body is byte-identical to its predecessor `20170bd6` body. All four real Linux
resource-limit failures reported success and destroyed a valid earlier file:

| Public writer | Previous valid bytes | Actual resource limit / resulting bytes | Old acknowledgement after corruption |
|---|---:|---:|---|
| Generation Workbench `save_profile` | 3,152 | 128 | `Saved accepted revision 1` and `true` |
| Materials Lab `export_test` | 4,570 | 4,224 | `Saved reproducible test case` |
| Transport `save_copy` | 373 | 128 | `User copy saved` |
| Tower controller `water_lab_save_profile` | 176 | 128 | `true`; its button discarded the result |

These are fresh P1 authored-data-loss reproductions, with isolated disposable
profiles and `SIGXFSZ` ignored. The larger Materials Lab case deliberately places
the failure in its final buffered segment. Each truncated result fails its
actual format reader; this is more than a generic JSON or source-pattern check.

Correction `b698a2b2447ece2076bfa83ac56093f34487450f` routes the four writers
through the unchanged shared transaction. It preserves their existing paths,
JSON fields, naming, native configuration and Save-versus-Apply contracts:

| Contract | Admission and complete-file budget | State and acknowledgement |
|---|---|---|
| Accepted generation recipe | Existing accepted revision; complete encoded JSON at most 1 MiB | Failure reaches both status labels and leaves the accepted recipe/preview unchanged. A successful retry clears this save's previous error. |
| Materials Lab experiment envelope | Existing active, source-bound native experiment; complete encoded envelope at most 1 MiB, matching its reader | Reproducible experiment success appears only after commit. The native experiment does not advance. Candidate presets and compiled bundles retain their separate Python backend. |
| Transport user copy | Existing schema/range validation; at most 64 KiB | Failure retains editor and draft. Success adopts the saved user copy. Neither outcome invokes Apply or changes the running owner. |
| Tower Water policy | Existing available, validated, unblinded policy; canonical JSON revalidated and at most 64 KiB | The existing **Save Water policy** button shows a dedicated result label. Save does not write to the unrelated MicroScenario error field or change blind-study admission. |

Each is one complete JSON document, with no companion-file commit. The helper's
native requirement fails closed before creating staging; no unsafe fallback was
added for an old/missing runtime. The desktop Web-controller class was exercised
on native Linux by an existing regression, which does not establish a browser
filesystem guarantee. Tower observation export and Art traffic/history remain
distinct owning paths; this correction makes no claim about their storage.

The [Linux caller matrix](profile-save-linux.json) passes **16 cases**: normal
replacement, invalid admission, actual buffered-tail resource failure and real
directory-permission denial for each writer. All refusals preserve the old
digest, length and loaded seed/mixing value `7`; successful retries load `8`.
The Tower case emits the real button signal and checks its label. Stale unrelated
`.tmp` files remain unchanged. B and C separately executed the same 16-case
matrix; both independently approved the complete source and caller harness.

The [existing normal regressions](profile-save-regressions.json) pass with
natural zero exits: Generation Workbench **226 assertions**, Materials Lab
**141 assertions**, the complete Transport preset/roundtrip/inheritance suite,
and the Water controller's **10 deterministic exit-receipt cases** plus its
desktop/Web-controller blind lifecycle. The local test process began on an
earlier evidence commit with the implementation present; every one of its
14 recorded qualification inputs was subsequently checked byte-for-byte against
`b698a2b2`. The receipts distinguish that input equality from the earlier HEAD.

```bash
python tools/ci/run_profile_save_qualification.py \
  --godot /absolute/path/to/pinned-godot \
  --project godot \
  --evidence /absolute/path/to/new-profile-evidence
```

On Windows this runner selects **12 cases**, using actual destination sharing
locks in place of the two Linux-only OS faults. Those new caller cases require
their own integrated hosted receipt; earlier authored-save Windows results do
not qualify these later changes. The unchanged shared helper retains its
separate deterministic I/O-boundary matrix. No power-loss, hostile filesystem
tampering, physical-owner or whole-project transaction guarantee is inferred.

The [compressed raw bundle](profile-save-raw.json.gz) preserves the actual
children, command scripts, logs, initial discovery and four-writer reproduction
without multiplying text in the current corpus. It is gzip-compressed JSON;
each `files` entry contains the original UTF-8 `text` and its SHA-256. Decoding
and re-encoding each entry reproduces the recorded bytes. The original bundle
is 168,233 uncompressed bytes / 20,312 compressed bytes and is non-authoritative
audit evidence.

## Additional capture defect: A-ULT-11

Fresh review found the same buffered-write weakness in
`Main._write_microscenario_capture` and `tests/run_microscenario.gd`. The
[actual before reproduction](microscenario-capture-before.json) distinguishes
two failure sizes. At `RLIMIT_FSIZE=128`, the controller reported success after
replacing a valid **851-byte** report with **128 invalid JSON bytes**. The CLI's
larger write correctly refused that early limit. Moving the actual limit into
its final buffered segment, to **12,416 bytes**, instead replaced a valid
**14,205-byte** report with invalid truncated JSON while the CLI printed
`MICROSCENARIO_RESULT` and exited zero. This was a second reproduced P1
evidence-loss defect, not an inference from the authored-save result.

Commit `fcec6b70` routes both callers through the same verified transaction.
JSON fields, output names and existing report-size policy remain unchanged;
relative CLI outputs still resolve from the selected project directory. The
controller updates its retained capture and clipboard only after commit. A
refusal preserves the previously acknowledged result and exposes the helper's
failure message; a successful retry clears the prior capture error. Existing
fixed-name `.tmp` files are neither consumed nor deleted by the new writer.

The [exact-commit Linux matrix](microscenario-capture-linux.json) passes all
**six cases**: normal replacement, actual buffered-tail resource failure and
actual directory-permission refusal for each public caller. Every refusal
checks the old length, digest and decoded value; every retry checks the intended
new value. A controller acknowledgement spy verifies that refusal produces no
acknowledgement. Normal CLI replacement also exercises a relative output path
containing spaces. The [normal regressions](microscenario-capture-regressions.json)
pass **84 shared-helper checks**, **38 MicroScenario Workbench assertions** and
**27 reference-pack UI assertions**, with natural zero exits. These are
headless functional tests; the synchronous compatibility controller exercised
by the Workbench test is not an actual browser run.

```bash
python tools/ci/run_microscenario_capture_qualification.py \
  --godot /absolute/path/to/pinned-godot \
  --project godot \
  --evidence /absolute/path/to/new-capture-evidence
```

On Windows this runner uses actual destination sharing locks for both callers
and records four cases. The local receipt above is Linux-only; exact integrated
Windows execution belongs to its separate hosted receipt. The expanded
non-publishing package gate requires that additional Windows matrix before
creating an evaluator, so the earlier `bfa40c84` qualification alone cannot
qualify this later source. No native primitive, physics law or storage format
was changed, and no crash/power-loss durability is claimed.

## Reproduction and independent acceptance

Run in a source checkout with materialized, source-matched native/Rapier assets:

```bash
python tools/ci/run_workbench_save_qualification.py \
  --godot /absolute/path/to/pinned-godot \
  --project godot \
  --evidence build/workbench-save-qualification
```

The runner validates the exact Godot version, records executable/native digests
and all changed-source input hashes, and isolates application data in a fresh
profile. On Windows the same command runs actual destination and source sharing-
lock cases. The source-lock case leaves the destination unlocked: a delete-then-
move implementation would lose it, so this is the critical native negative
control. Linux permissions require a non-root account, as on the executed host
and ordinary GitHub Linux runners.

For the before reproduction, use the same tiny child with the immutable
predecessor checkout and disposable `XDG_DATA_HOME`. Run `SAVE_PHASE=prepare`
normally; run `SAVE_PHASE=refusal` in a Python child with
`resource.setrlimit(resource.RLIMIT_FSIZE, (128, 128))` and
`signal.signal(signal.SIGXFSZ, signal.SIG_IGN)` in `preexec_fn`.
The old Windows Godot delete-then-move implementation is source-traced; it was
not executed as an old-source control. The new-source hosted lock controls above
were actually executed. These evidence classes are deliberately separate.

To independently verify downloaded hosted archives against the retained receipt:

```bash
python docs/audits/2026-11-25-docs-renaissance-ultima/technical/verify_hosted_archives.py \
  --archives /absolute/path/to/downloaded-archives \
  --repository . --output /absolute/path/to/readback.json
```

Independent B/C review and final integrated hosted results belong to the final
mission review ledger. This implementation report does not grant merge, Ready,
runtime release or physical owner acceptance.

## Technical review coverage and additional corrections

The [coverage receipt](technical-review-coverage.json) records 24 complete
canonical-document reads, 9,136 lines and 37 selected source files. Each document
has its exact digest, review depth and a consequential contract summary. All 24
document bytes matched the integrated candidate when the receipt was written.
This count describes complete semantic reads and targeted source checks; it is
not a count of individually executed claims or rerun historical physics studies.

| Finding | Corrected contract | Independent reviewer |
|---|---|---|
| A-ULT-05 | Workbench torque, current-centre-of-mass correction and main-thread Rapier ownership differ from the ordinary torque-free body packet. | B inspected native wrench creation and bridge application. |
| A-ULT-06 | Accepted native World can run the optional settled-discovery observer; actual soliding body handoff remains separately gated. | C inspected World initialization and completed-tick integration. |
| A-ULT-07 | Both ordinary brush queues independently cap admission at eight commands; coalescence or admission is not application. | C read both queue implementations. |
| A-ULT-08 | Falling Wave water passes a ballistic parcel only with catch disabled or during its four-tick grace; older caught parcels can merge. | B checked the exact cell-classification branch. |
| A-ULT-09 | Accepted pressure/IN integration, bounded capacities and actual physical hash/export versions replace stale candidate and fixed-version prose. | C reviewed source and preserved numerical-recipe scope. |
| A-ULT-10 | Ballistic quantity uses schema 2; Workbench preparation derives bounds from its canvas; accepted normalization and pressure-cache behavior are distinguished from old work orders. | C checked codecs, limits, current cache calls and accepted merge ancestry. |
| A-ULT-11 | Main and CLI MicroScenario captures no longer acknowledge buffered short writes or replace a valid capture with truncated JSON. | C independently ran all six real Linux cases. |

B's separately implemented gameplay-recorder correction received
[independent A source review and execution](recorder-independent-review.json):
94 unit assertions, normal recording and real Linux file-size refusal passed.
The refused frame remained partial and was not counted complete; the original
valid recording manifest remained intact. This is per-file verification and
manifest replacement, with no claim of a whole-recording transaction.
[Additional cross-review receipts](additional-cross-review-receipts.json)
cover C's actual-platform physics provenance repair and bounded source/status
corrections in the other lanes. The
[package review](package-independent-review.json) includes all 40 executed
admission/integrity tests after the recorder and capture requirements were added.

The [final DR13–24 applicability review](context-applicability-final.json)
assesses all 60 actual supplied passages at source `162b8097`, whose complete
retrieval identity equals functional checkpoint `dd5fdd9d`. Eleven questions are
sufficient in the first five passages. DR20 remains partial there because the
pending Equipment recovery record is missing; an actually executed, explicit
source-follow to the linked status register supplies it. That second step is
reported separately. Four intermediate contexts contained a stale save-writer
paragraph; the corrected final contexts were read and verified. No generative
model answer score or autonomous source-following result is claimed.

## Expanded diagnostic writer correction: A-ULT-13

The [fresh diagnostic reproduction](diagnostic-storage-before.json) called the
actual physics-characterisation, prototype Thunderbowl and physical Thunderbowl
CLIs against disposable one-tick fixtures. All three returned successful process
completion after a real Linux buffered-tail write failure replaced a valid
report with truncated, invalid JSON:

| Actual caller | Previous complete bytes | Failed output bytes | Original acknowledgement |
|---|---:|---:|---|
| Physics characterisation | 3,883 | 128 | `PHYSICS_RESULT` reported success; exit 0 |
| Prototype Thunderbowl | 71,579 | 69,760 | Successful report marker; exit 0 |
| Physical Thunderbowl | 9,063 | 8,320 | Successful report JSON; exit 0 |

Commit `e6796b8e226d061b415195a1993737832e7c38c6` applies the existing verified
single-file transaction to those report writers. The existing report formats,
controller logic and scientific recipes are unchanged. The callers now expose
the storage refusal and exit unsuccessfully. Relative output paths containing
spaces remain supported. An empty in-memory output route still avoids disk I/O.
The [original three-writer Linux matrix](diagnostic-storage-linux-original3.json)
passed nine cases: normal replacement, actual file-size failure and actual
directory-permission refusal for each caller. Failed writes retained the exact
previous digest and seed 7; retries loaded seed 8.

Accepted-main drift added the optional Goblin foundation. The lead independently
reproduced the same false-success failure in its guarded fixed audit writer and
corrected that function in `34ae4faa`. A reviewed the unchanged fixed-path
allowlist, real profile marker/containment checks, formatted envelope and builder
budgets. The [extended integrated matrix](diagnostic-storage-linux-with-goblin.json)
passed 12 cases; C independently repeated all 12. Its Goblin probe invokes the
fixed `TRANSCRIPT_PATH` writer under a genuinely admitted disposable profile and
also proves wrong-path and wrong-profile refusal. The payload identifies itself
as a storage fixture. It is not an actual campaign transcript, replay acceptance
or a transaction over all campaign files.

The [three normal diagnostic regressions](diagnostic-storage-regressions.json)
also completed naturally: physics instrumentation, Thunderbowl arena (621
assertions) and Thunderbowl controllers (712 assertions). These runs do not
re-establish a historical physics or performance campaign. Final Windows fault
coverage remains a separate eight-case hosted gate; Linux execution does not
close that platform obligation.

## Art preference and retained-journal correction: A-ULT-14 and A-ULT-15

The [actual pre-fix Art probe](art-panel-storage-before.json) demonstrated two
further false acknowledgements on root source `b4257547`: `_save_settings`
replaced a valid 1,108-byte configuration with 128 corrupt bytes while returning
success, and `_persist_history_receipt` admitted a new 128-byte corrupt record.
The latter left the previous 1,528-byte record intact but falsely marked the new
item as saved. Both used a real Linux file-size limit and nonsecret synthetic
inputs. No provider request or native editing operation was executed. The
initial off-tree probe leaked UI objects during teardown; its complete logs are
retained and are not counted as passing runtime qualification.

Commit `73da90d5b1b7f907b7e30510762c8b7f4488d20d` changes only the required
storage boundaries. Preferences use `ConfigFile.encode_to_text()` and the shared
verified replacement with the existing 1 MiB profile bound. A failed save leaves
the disk configuration intact; live controls can retain their new values. A
successful retry clears only the matching prior save error. The retained journal
writer keeps its short `pending-<UUID>.partial` sibling name, preserving its
Windows pathname behavior. It checks `store_buffer`, closes the file, invokes the
shared exact-byte verifier and then uses its unchanged native replacement. It
assigns the item's file/order fields only after that succeeds. Identity, schema,
frozen-turn, capacity and quota admission remain intact.

**The journal helper is a retained private recovery/testing surface.** Current
Art construction starts with an empty live conversation; `history_edited()`
appends native-action information to that session's log. This fix does not enable
automatic old-history restoration or create a new user recovery workflow. No
real completed native edit was reported lost by the synthetic reproduction.

The [expanded Linux Art matrix](art-panel-storage-linux.json) passed 13 cases,
including the original six export/append/new-event cases. New checks cover
preferences and the private journal under real file-size and permission failures,
duplicate receipt refusal, exact previous bytes, recovery retries, typed/Unicode
configuration roundtrip, schema-1 loading, schema-2 frozen projections/order,
unchanged receipt clock on refusal, preserved admission/size guards and staging
cleanup. C independently ran all 13; B reviewed source and user-facing semantics.
The [normal regressions](art-panel-storage-regressions.json) retained the original
278 passing Art assertions and added the unchanged 122-assertion receipt-identity
suite: 400 assertions across six naturally completed processes.

The [source binding](art-panel-storage-source-binding.json) records the exact
input hashes and implemented function bodies. The final commit also changes one
inactive legacy error phrase from “durable journal” to “verified journal file”;
that wording is the only panel-file difference from these local run inputs.
Both implemented function bodies, the child and runner are byte-identical. The
final integrated qualification must still run on its own source checkpoint.
The Windows plan contains nine cases: the original five, normal/locked-target
preferences, normal journal publication and duplicate-record admission refusal.
A new immutable receipt has no old destination to lock; the duplicate case is
not represented as a Windows replacement failure.

## Remaining writer perimeter and evidence custody

The [one-to-one lane register](lane-findings-register.json) retains every
`A-ULT-01` through `A-ULT-15` identity, reviewer and evidence route. Expanded
callers remain explicitly pending final integrated platform receipts at this
snapshot. The [remaining-writer dispositions](remaining-writer-dispositions.json)
record source-grounded boundaries that were not silently treated as fixed:

- Materials Lab job requests and cancellation markers are transient IPC. Their
  guarded response/cancellation contract does not admit a truncated request as a
  compiled/tested candidate. This was source inspection, not new OS fault testing.
- Physical-flight development outputs already close and compare the complete
  serialized bytes and refuse a mismatch. They are replaceable run artifacts;
  the mechanism does not preserve a previous run when an output directory is
  reused. Independent qualification uses a separate retained run directory.
- The optional Web local-slot writer still has the old buffered-write/rename
  pattern. No browser failure-safety qualification or desktop-helper port is
  claimed. Its future experiment is an explicit owner boundary under
  [issue #3's closure](https://github.com/techrote/cybersand/issues/3#issuecomment-5593128559),
  with an executable follow-up in the register. The best-effort Web benchmark
  cache is separate from the in-memory/UI/stdout result and does not acknowledge
  a successful file save.

The [additional independent reviews](storage-perimeter-independent-reviews.json)
cover B's Tower export correction (six independently executed Linux cases), Art
manuals, the lead's Goblin fixed writer and the lead's bounded LFS acquisition
retry helper (nine executed negative controls). B's separate X11 clipboard
observations are not attributed to A's headless Tower run.

The [raw custody manifest](diagnostic-and-art-raw-custody.json) describes a
51,065-byte compressed packet containing 131 exact text files (533,968 bytes
before compression). Every extracted entry was rehashed. It preserves the
diagnostic/Art reproductions, unique corrupt outputs, actual logs, relevant
fixtures and failed harness attempts. The sole failed expanded Art run was
correctly rejected because its cleanup tried to list a nonexistent journal
directory; the exact earlier child and all failed results remain reconstructible.
These failures were corrected before the successful 13-case run. No owner data,
credentials, binary duplication or external artifact relocation is involved.
