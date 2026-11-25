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
| A-ULT-01 / LIMIT-03 | Pinned Windows `DirAccess.rename_absolute` removes an existing destination before `MoveFileW`; a subsequent failure can lose the previous file. This mechanism is source-confirmed; Windows execution is a separate gate. | Reuse the existing native same-directory replacement primitive in all three affected writers. |
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
   cleanup fails, show its exact remaining path and say it is not a saved start.
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

The [final Linux OS matrix](persistence-linux-final.json), at source
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
The Windows old-source deletion case remains a platform execution task until
its actual hosted receipt is recorded. A source trace alone is not a Windows run.

Independent B/C review and final integrated hosted results belong to the final
mission review ledger. This implementation report does not grant merge, Ready,
runtime release or physical owner acceptance.
