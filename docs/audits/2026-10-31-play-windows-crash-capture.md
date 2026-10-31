---
title: PLAY Windows post-summary exception capture apparatus
status: Current
document-kind: audit
scope: Opt-in unchanged-fixture Windows debugger diagnostic, retained original failure, exact source and process evidence, and unexecuted hosted qualification
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../operations/local-build-and-validation.md, ../operations/github-development-and-release.md, ../operations/current-and-historical-validation.md, 2026-10-31-play-ui007-desktop-readiness.md, 2026-10-25-lcb003-desktop-native-default-host.md]
---

# Windows exception capture — 2026-10-31

## Original blocking result and narrow purpose

PR #319 source `aa74448bad7ec77e5f152d9179a417ce76430009`, tree
`3e11e03480e5e584c623db6fb71bc2e259887519`, failed ordinary Windows execution
in [run41175131563, attempt1](https://github.com/techrote/cybersand/actions/runs/41175131563).
The tested merge was `f3e19d110e7d2ed2f85bdc300315585677bd3b0f`, with the
same tree. Shard3's unchanged `test_liquid_desktop_default_host` printed
`LIQUID_DESKTOP_DEFAULT_HOST: 86 assertions; 0 failures`, then exited
`3221225477` (`0xC0000005`) after18.658s. Its180-second process limit did not
expire. There was no retained exception dump or stack. The assertion footer
does not make this process a pass.

The original shard3 artifact is340,185bytes with SHA-256
`27be12f043ef4adc2d1d7a541282ee60c63a79d57f9cc0af5a2486386dfe05cc`.
The same unchanged fixture exited0 with86/0 in earlier #317 run41173057199
(18.581s) and #318 run41173563745 (18.766s). These observations preserve
source and run identity; they neither dismiss the new failure nor prove its
cause. The [earlier default-host audit](2026-10-25-lcb003-desktop-native-default-host.md)
also retains this post-summary symptom and failed teardown experiments.

Existing ordinary timeout diagnostics begin near the process deadline and
capture a live hang without an exception parameter. They could not capture
this early crash. This package adds a separate, opt-in diagnostic workflow.
All `godot`, `native`, `third_party`, `tools/ci` and ordinary Godot workflow
bytes must remain identical to the #319 source above. The source fence is
checked before execution and again from retained Git objects offline. No
fixture teardown, production lifetime, shader, solver or ordinary CI gate is
changed. Scheduswarm remains paused.

## Debugger ownership and unchanged failure semantics

`windows_crash_debugger.cpp` launches the prescribed console executable with
`DEBUG_PROCESS`, observing its engine child from creation. It records actual
process IDs, module loads/unloads, exception code/address/thread/chance,
continuations and original exits. Only the initial loader breakpoint is
handled. Other exceptions are forwarded using `DBG_EXCEPTION_NOT_HANDLED`;
the application receives first chance, and unhandled second chance retains
Windows termination semantics.

Every first-chance access violation and every second-chance exception gets
an external dump helper while the debug event holds the target stopped.
The helper copies the actual stopped x64 context and exception record, then
calls `MiniDumpWriteDump` with local exception pointers and
`ClientPointers=FALSE`. The raw nested-record address is retained separately;
the dump does not chase a foreign nested exception pointer. Dumps use only
`MiniDumpNormal | MiniDumpWithThreadInfo`, not full memory. The reader limits
each dump to64MiB and requires the actual exception, thread, stack and module
streams. It cross-checks exception code, flags, parameters, address, thread
and registers against the native event and raw SDK context.

The helper receives atomic creation-time membership in a kill-on-close job.
Its budget reserves time for termination and observed exit. A failed or
unjoined helper makes the diagnostic fail; it cannot be counted as a
successful capture. The broker's debug ownership terminates remaining
debuggees if the broker dies. Windows automatically closes the event-owned
process/thread handles when their exit events are continued; DLL file handles
are closed explicitly.

| Boundary | Contract |
|---|---|
| Original project import |240s, unchanged |
| Original fixture process |180s, unchanged; debugger time consumes this budget |
| Each normal diagnostic control |15s |
| Hung-target negative |500ms deadline against a20s control sleep |
| Dump helper |At most15s and the remaining original process budget, including context/file/dump work and bounded join |
| Hung-writer negative |1s capture budget against a20s helper sleep; requires terminated/joined helper and explicit diagnostic failure74 |
| MSVC compile and version probe |15s per operation |
| Evidence bounds |At most8 captures and20,000 debug events |

The Python outer watchdog allows only3s to observe/clean up a broker that
exceeded its original deadline. An outer timeout, late process completion,
missing continuation/exit, missing dump, failed dump helper or digest mismatch
is failure. This cleanup allowance cannot turn late work into a pass. OS
scheduling and synchronous event logging are not claimed to have a hard
real-time guarantee; their time still consumes the original process bound.

## Controls and original-artifact verification

The tiny C executable is compiled with the installed x64 MSVC toolchain.
Compiler identity, `/Bv` output, exact source/binary hashes, commands, PDBs and
build logs are retained. Controls run before the engine import or real fixture:

1. Normal exit0 with no fault capture.
2. A handled first-chance access violation with one capture and exit0.
3. An unhandled access violation with first/second-chance captures and exact
   `0xC0000005` exit.
4. The same unhandled exception in a child, proving descendant ownership and
   preservation of the child's nonzero exit.
5. The bounded hung-target negative.
6. The bounded hung-dump-writer negative with observed helper destruction.

The access-violation controls use `RaiseException`: they are **injected Windows
exception controls**, not genuine bad-memory accesses and not reproductions of
the Godot defect. A failed preflight stops before the one prescribed fixture
attempt. There is no retry loop, and workflow rerun attempts are refused.

The source artifact retains the exact candidate and original-base commit
objects, all tree objects and every scoped source blob in a Git pack. Git
object IDs authenticate commit/tree membership. Selected native/Rapier working
hashes and sizes must match their committed LFS pointers. Native source inputs
and both retained Rapier provenance manifests are rechecked; the selected
Windows DLLs are the accepted source-matched binaries. The official Godot
4.7 archive has its existing SHA-512 pin, plus explicit GUI/console byte pins.
Generated engine binaries are excluded from the uploaded artifact; their
official archive identity and observed loaded-file hashes remain recorded.

The root debuggee must be the commanded pinned executable. All descendant
executables must belong to the expected control or Godot image inventory.
Each actual Godot engine process must load both selected native/Rapier DLLs
with the pinned bytes. The v2 correction below captures their file identities
while the debug event is stopped and admits the documented exact import-only
shadow paths. Module basenames cannot silently resolve to another directory.
The reader reconstructs active module bases from load/unload
events at each capture and joins the dump's fault-time module list to that
process. It does not attribute a fault to a union of historical DLL loads.

The original manifest covers source objects, raw logs, process/event receipts,
compiled controls, dumps and reduced results. Offline verification recomputes
all file hashes, rejects missing/extra evidence, repeats source/provenance
checks and recomputes every process/control result. A zero fixture exit still
requires the unchanged86/0 footer and strict error/skip checks. A nonzero exit
or timeout remains `observed_process_failure`, even if assertions completed.
A fully retained earlier crash before the footer is also failure; the reader
can authenticate its diagnostic evidence without calling the fixture passed.
Only `no_process_failure_observed` returns0, and every report explicitly keeps
the original #319 failure blocking. Debugger execution is not ordinary-gate
qualification and cannot independently clear it.

Before any debugger child starts, the driver removes known credential-bearing
environment variables and credential-bearing proxy URLs. It records names
only, never their values. Ordinary OS/toolchain environment inputs remain.
This is a deliberate known-name filter, not a claim that arbitrary unknown
application data is scrubbed from a stack dump.

## Reproduction and current validation boundary

Use a clean checkout of the reviewed diagnostic commit, materialize the
accepted Windows native/Rapier LFS objects, enter the installed x64 MSVC
developer environment, and obtain the pinned official Godot archive. On an
actual Windows x64 host:

```text
python tools/play/run_windows_crash_capture.py --expected-source-sha <full-commit-sha> --godot-archive <Godot_v4.7-stable_win64.exe.zip> --output <new-evidence-directory>
```

The dedicated workflow performs these steps on GitHub-hosted `windows-2022`.
It uploads originals even on failure. It does not retry ordinary CI or change
the production source. For read-only verification of extracted originals on
Windows or Linux:

```text
python tools/play/run_windows_crash_capture.py --expected-source-sha <same-full-commit-sha> --verify <original-campaign-directory>
python tools/play/test_windows_crash_contract.py
python -O tools/play/test_windows_crash_contract.py
```

The local portable contracts cover synthetic dump structures, intended
negative controls, process ownership/continuations, stale module bases,
substituted executable/runtime bytes, deadlines, manifests and real temporary
Git object packs. These are reader/provenance controls. **No local Windows
compile, debugger execution or actual crash capture is claimed in this
implementation checkpoint.** Fresh hosted compile/control/fixture results
and independent original-artifact review are mandatory next evidence.

The initial local checkpoint passed 43 portable tests normally and under `python -O`, plus
provider policy, documentation, retained M11 integrity and pointer-aware
repository identity. Offline inspection authenticates the accepted native
80-input provenance and both Rapier manifests. Runtime payload execution is
not part of those checks. The unchanged retrieval corpus scores32/32 frozen
questions and153/154 challenge routes; the existing `LCB03` miss remains
explicit, and this dated audit adds no corpus reranking claim.

The source review corrected an asynchronous-helper termination gap before
publication and added the hung-writer control. The first reader also lacked
executable/runtime enforcement and unload continuity; those source findings
were corrected before hosted execution. No original runtime failure was
overwritten or rerun to conceal a failed attempt.

## First hosted failure and v2 correction

Draft #321 published the same implementation tree as local source
`02f3b4bcb373b84ca727cb5a9ad3a6535169fe5d` under GitHub head
`88c633490851223deb02eae9fe04c56e9951a2de`, tree
`aee4ab8bbc45b938da822254bdd8134786ba99dc`.
[Run 41178685606 attempt 1](https://github.com/techrote/cybersand/actions/runs/41178685606)
failed in portable preflight: 43 methods ran, 42 passed and
`ManifestTests.test_exact_original_manifest_passes` raised one error. Its
synthetic `raw.log` used platform-default text newline translation but expected
18 bytes. Windows emitted CRLF; the real manifest verifier correctly rejected
the resulting mismatch. Optimized tests, runtime materialization, SDK builds,
actual controls, editor import and the Godot fixture were all unexecuted.

The original artifact 13034435611 is 2,209 bytes, SHA-256
`9350a2d6f0a450ea080769476271159405d59fdcdbc64081343223baacc6d061`.
Its API identity, ZIP CRC, source/tree files, original test log and provider
result were independently verified and retained with the original job log.
The failed run is not retried or relabelled.

The synthetic fixture now writes explicit LF **bytes**. Real artifact hashing
still uses exact original bytes. An additional control accepts an authentic
CRLF artifact only with its original CRLF hash/size, and rejects later LF
normalization.

Independent source reconciliation also found the existing
[Windows editor shadow observation](2026-10-25-lcb003-qualified-host-observation.md#controlled-standalone-and-editor-observation):
the pinned editor loads `~cybersand_native.windows.x86_64.dll` even when
`reloadable=false`. The initial diagnostic assumed original DLL paths and
hashed module files after process exit. That assumption was unexecuted in the
failed attempt, but would refuse the real editor import and could lose a
deleted shadow file. It is corrected before the next source-qualified attempt.

The v2 broker hashes only the control executable, pinned console/GUI images
and original or exact `~`-prefixed native/Rapier names. It holds the native
CREATE_PROCESS/LOAD_DLL event and its file handle until a bounded external
helper finishes. The shared helper launcher supplies the same creation-time
job ownership, 15-second/remaining-case budget, termination reserve and observed
join used by the hung-writer control. At most 16 files, each at
most 256 MiB, may be hashed in one process attempt; reads use 64 KiB buffers.
Unrelated OS modules retain their paths, bases and load/unload events with an
explicit unhashed classification. There is no unbounded post-exit module scan.

SHA-256 uses Windows CNG. The retained 64-byte record contains volume serial,
the 128-bit `FILE_ID_INFO` identity, exact size and digest. The broker compares
the helper-opened file's identity and size with the still-held debug-event
file handle; the portable reader independently repeats that binary/JSON join.
The 128-bit ID avoids an unqualified 64-bit file-index assumption on ReFS.
These are file-at-load observations; mapped-memory hashing is not claimed.

Only the exact prescribed `--headless --path <project> --editor --quit`
import command admits the `~` file in the original runtime directory, and its
bytes must still equal the committed runtime pin. The standalone fixture
requires the original paths. Wrong directories, extra prefixes, substituted
bytes, mismatched file IDs, missing raw records, expired hash budgets and
unjoined helpers fail. The schema is `play-windows-crash-v2`; source-bound v1
history remains available at its original commit. Local portable coverage is
now 51 methods, including these shadow/file-ID/byte-substitution controls.

Windows SDK compilation, actual hash/control behavior and the original Godot
fixture remain unqualified until a fresh exact-head hosted run completes.

## Platform basis and limitations

Microsoft documents that [debug events suspend target threads until continued](https://learn.microsoft.com/en-us/windows/win32/debug/debugging-events)
and that [`DBG_EXCEPTION_NOT_HANDLED`](https://learn.microsoft.com/en-us/windows/win32/api/debugapi/nf-debugapi-continuedebugevent)
preserves exception-handler/termination processing. It recommends an external
process for [`MiniDumpWriteDump`](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump)
and requires a non-null exception parameter to include exception information.
[`ClientPointers=FALSE`](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/ns-minidumpapiset-minidump_exception_information)
describes debugger-local exception pointers. [Creation-time job-list attributes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute)
and an observed wait after [asynchronous `TerminateProcess`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-terminateprocess)
provide helper ownership and explicit completion evidence.

The hash helper uses documented [CNG incremental hashing](https://learn.microsoft.com/en-us/windows/win32/api/bcrypt/nf-bcrypt-bcrypthashdata)
and the 128-bit [file identity information](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_id_info)
to compare its opened file with the debugger's original file handle. An
unavailable file identity remains failure, not an inferred successful binding.

[WER LocalDumps](https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps)
does not support applications that implement their own custom crash reporting,
so WER registry configuration alone is insufficient assurance of a fault
stream. This audit does not assert a particular Godot custom-handler root
cause. Starting under a debugger can itself affect application timing or
handler behavior. A clean diagnostic run means only that this one prescribed
debugger attempt did not observe a process failure; it is not a repair,
ordinary Windows qualification, graphical test, hardware test or human-play
acceptance. Symbol availability may limit stack naming even when raw registers,
stack bytes and module identities are retained.
