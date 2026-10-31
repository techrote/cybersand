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

The [v5 LLVM successor](#diagnostic-only-clang-cl-and-lld-successor--v5)
below supersedes the compiler configuration of the retained v4 attempt.
It preserves the original production/fixture source and every prior failure.
Local portable controls are complete; resulting-source Windows execution is
still required. No successful new engine execution or crash repair is asserted.

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

## Second original failure and owned build correction

The first v2 attempt used GitHub head
`70c1586dd04bdc786c08c081b766402e7792d73d`, tree
`76270686e4007cc76acc97845efe240bf989e1d3`, identical to local corrected
source `8c6e65681caa48ff512e8c3d706d3d827aeaf1bb`.
[Run 41180173514 attempt 1](https://github.com/techrote/cybersand/actions/runs/41180173514)
passed all 51 portable methods normally and under `python -O` in 6.832 and
6.463 seconds respectively. The selected runtime materialization and source
proof passed. The debugger compilation then exceeded its unchanged 15-second
bound. Its log records MSVC 19.44.35229 compiler passes and the input filename,
without a compiler diagnostic or a completed object/executable. The cause of
the compilation timeout is unproven.

Original artifact 13034244321 is 2,236,529 bytes, SHA-256
`b32a65717c03221aee0e58687a4a057e457e6844fdcd1eb7b8b94846fdbb4f3f`.
Independent readback verified its API size/digest, ZIP CRC, complete four-file
campaign manifest, exact commit/tree/Git pack with 792 scoped inputs, 80 native
source inputs and both selected runtime identities. The source pack is
2,161,027 bytes, SHA-256
`9dd6507ab40aeeb5e7035760bf4fc4088f52c8f60130213dc342ad5f2328c8cc`.
The C control build, actual controls, engine archive/version verification,
editor import and Godot fixture were all unexecuted. The campaign retains
`fixture_attempts=0`, `completed=false` and its original failure classification.

This failure exposed a separate apparatus defect: the Python build function
wrote its compiler/source receipt only after `subprocess.run` returned, so
`TimeoutExpired` bypassed the receipt. It also did not explicitly own compiler
descendants. The correction preserves a source/compiler/command identity in an
exclusive `launch.json` **before** process creation, and records build progress
and final failure in `tools/build.json` even when an operation fails.

The narrow `windows_build_process.py` helper uses the Windows Job API directly,
so establishing build ownership requires no precompiled diagnostic executable.
The compiler starts suspended with creation-time job membership and a restricted
inherited handle list. The job kills remaining descendants when its last owned
handle closes. Successful cleanup additionally requires observed process exits
and empty job accounting; closing a job alone is never recorded as a joined
operation. The unchanged 15-second operation reserves 1.5 seconds for
termination and observed cleanup. This may stop incomplete compilation earlier;
it does not provide extra compiler time.

At most 32 processes and 160 observations are retained per operation. Samples
record actual process IDs, creation times, executable paths, cumulative job and
process CPU time, observed exits and raw log byte progress. `/showIncludes`
retains compiler include progress in the original log. These opt-in observations
are outside all gameplay/frame paths. They do not diagnose the original compile
timeout or the earlier Godot access violation by inference.

Sampling at no more than 10 Hz may miss a short-lived child's identity and exit.
Job accounting supplies containment and final empty-job evidence; retained
process handles supply identities and exit codes only for observed children.
The campaign receipt states this limitation. The actual ownership controls
require their deliberately long-lived child to be observed and joined.

Before SDK compilation, three actual Windows Python controls must complete:
normal parent/child exit, preserved exit 19, and a parent that exits zero while
its child remains alive until bounded job termination. The last control requires
the observed child to exit 124 and the job to be completely joined within its
3-second control operation. Portable deadline models and raw-evidence adversaries
are separate: 54 crash/campaign methods and 14 ownership methods pass locally,
normally and under optimization. Actual Windows execution of the new helper
remains pending. The campaign schema is now `play-windows-crash-campaign-v3`;
the debugger event schema remains v2 and the C/C++ source is unchanged.

Both earlier failed runs retain their original commits and artifacts. There is
no unchanged-source retry, build cache, prebuilt compiler output, deadline
expansion, shader change or production-fixture change in this correction.

## Original v3 ownership-control refusal and explicit console policy

[Run 41193165592 attempt 1](https://github.com/techrote/cybersand/actions/runs/41193165592)
executed diagnostic head `fd723a6dd8c7b76e2c211fef28f937f5c5b277d1`, tree
`2b0db90e52b26c9ed156a1b427a59e038251ef6d`. All 54 crash/campaign and 14
owned-build portable methods passed normally and with optimized Python. The
first actual Windows ownership control then failed its exact two-process oracle.

The original raw Job samples show root Python PID 196, child Python PID 6904 and
`C:\\Windows\\System32\\conhost.exe` PID 2640. All three were observed and exited
zero; the complete job was joined in 0.509983 seconds. The control nevertheless
requires exactly two processes, so its original campaign is failed. Its message
was `Build child was not observed inside its owned job`; the child was observed,
but the combined predicate rejected the third process. SDK compilation, the
remaining ownership controls, exception controls, import and gameplay fixture
did not run. `fixture_attempts` remains zero.

The original artifact 13039083064 contains 2,254,075 bytes, SHA-256
`90d9a8b183cc391e562ad32d2fbd9133dd9bc05227cc06aa96a9bfbabd903fd8`.
Independent original readback authenticated API size/digest, ZIP CRC and every
entry, the sealed manifest, Git source pack, selected runtime chains and raw
Job evidence. Receipt SHA-256:
`d2f0de1e4bee01d37793d4d792a255487161d01f6a0143f0a9cf495b877565ad`.

The narrow correction gives the deliberately spawned Python control child the
explicit `subprocess.CREATE_NO_WINDOW` flag already used for its parent. Windows
documents this flag as running a console application without a console window.
The exact two-process inventory, actual observed child identity/exit, complete
join and all original bounds remain mandatory. This does not allow extra
processes or change the compiler, debugger, engine or gameplay launches.

Two new portable regressions execute the generated command with a mocked launch
to inspect its actual flags and verify that a third process still fails the
control. Those tests are command/oracle checks, not Windows execution. Fresh
Windows ownership, compiler, exception and fixture evidence is still required.
The original v3 campaign and every preceding failed source remain unchanged;
no earlier result is relabelled and no deadline is extended.

## Retained four-process refusal and detached-console correction

[Run 41193933850 attempt 1](https://github.com/techrote/cybersand/actions/runs/41193933850)
executed diagnostic head `400105c16e6ede0dd13b3ec0418ab4379f82824f`, tree
`1dd52cf2e1319cc3a83fda08f83a850f50286ad9`. Local source
`3c9219947e59a0b36e3c2b2b062a2980514eb7f8` has that same tree. The explicit
child `CREATE_NO_WINDOW` correction above did not satisfy the actual Windows
inventory. The first ownership control again failed before SDK compilation,
exception controls, import or the unchanged gameplay fixture.

The original samples contain root Python PID 6996, console host PID 7680,
child Python PID 7068 and console host PID 6712. All four were observed and
exited zero. The operation completed in 0.809659 seconds, with an empty-job
sample at 0.809508 seconds. Thus creation-time containment and complete join
were observed, but the exact two-process control failed. The generic operation
receipt's `status: passed` is not a successful campaign result. The original
25-byte process log contains only `OWNED_PARENT_CHILD 7068`; the child execution
marker is absent. No native access-violation cause is inferred from this
apparatus failure.

The retained original ZIP contains 2,255,973 bytes, SHA-256
`85d68f3979e5381f07fbb4b61aa87d7fb2e22d16d19fd1bf2b93f2c1093fc399`.
Independent readback authenticated its CRC, the unchanged launch/log/sample/
result bytes and the original strict refusal. The read-only classification
receipt has SHA-256
`dbc2d53f5b6487d73f126e9f71eb320425ff0c05c080f7941c49390c6398d2e6`.
The failed campaign, earlier three-process failure and all earlier original
sources remain retained with their original status.

Microsoft's [console creation contract](https://learn.microsoft.com/en-us/windows/console/creation-of-a-console)
distinguishes a detached process with no attached console from merely hiding
a window. Its [terminal implementation description](https://github.com/microsoft/terminal/blob/main/doc/specs/%23492%20-%20Default%20Terminal/spec.md)
explicitly describes a windowless console host under `CREATE_NO_WINDOW`.
The bounded correction therefore replaces that flag with `DETACHED_PROCESS`
for both the owned root and deliberately spawned Python child. It preserves
the root's suspended creation, Unicode environment, extended startup,
creation-time Job list, restricted inherited-handle list and explicit standard
handles. [Job inheritance](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)
remains unchanged; no breakaway or new-console flag is added.

The child now explicitly redirects stdin, stdout and stderr to its parent's
already selected handles with `close_fds=True`, following the
[Python standard-handle contract](https://docs.python.org/3.12/library/subprocess.html).
Both child controls require one matching `OWNED_CHILD` marker as well as one
parent-reported PID, the actual observed child, exact two-process accounting,
expected exit and complete join. Either marker may appear first. Missing,
duplicate or mismatched child markers fail; an extra process now reports the
precise inventory failure before marker checks. No console-host process is
filtered out of accounting.

The root creation policy is shared with this opt-in diagnostic's SDK compiler
commands. Their next actual Windows qualification must therefore consume the
same corrected helper. The C/C++ debugger and control sources, workflow,
production host, native/runtime inputs and ordinary validation gates are
unchanged. The original 15-second build/normal-control and 3-second orphan
operation bounds, cleanup reserve, 10 Hz sampling, 160-sample and 32-process
caps, child delays and failure propagation remain intact. No engine launch,
compiler invocation or actual Windows run occurred during this local correction.

The new portable regressions were first run against the original implementation
plus only the test delta: 21 methods produced seven expected assertion failures
across six methods. These expose both old launch flags, three missing marker
checks and the old combined error for three/four-process inventories. That
failed log is retained with SHA-256
`04051d26ff532de653952a15038355a41deb8f528a73bdbe2b6d2670a252df3a`.
The corrected executable bytes pass all 54 crash/campaign and 21 owned-build
methods normally and under `python -O`. The root launch test executes the real
assembly against a mocked Win32 API to inspect the Job/handle/flag contract;
the child test executes the generated command against a mocked subprocess.
These are portable construction/reducer results, not proof of a two-process
Windows execution. Fresh resulting-head hosted controls, SDK builds, exception
controls and the single unchanged fixture attempt remain required.

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

The build owner uses the documented
[job process inventory](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_process_id_list),
[job accounting](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_accounting_information)
and [process CPU time](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes)
APIs. A requested termination has no assumed completion time; failure to observe
the complete join within the fixed operation budget remains failed evidence.

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

## Owner-authorized watchdogs and retained compiler failure — v4

The 31 October 2026 owner handoff explicitly replaces obsolete short execution
budgets with generous watchdogs. This successor starts from original #321 head
`b890069877c7b197cf21ddf96cd00128ccbf09ad`, tree
`40ba7d568d3991f3e5394a1a2ab5da4b8649cd50`. Its diagnostic source is separate
from current-main timeout/shader integration: `godot`, `native`, `third_party`,
`tools/ci` and the ordinary Godot workflow remain byte-identical to original
failed source `aa74448bad7ec77e5f152d9179a417ce76430009`. Importing current main
would invalidate that original-source equality check. The historical fixture's
two internal 20-second waits also remain exact; current-main qualification owns
their independent modernization. This explicit reproduction exception must not
be mistaken for the current production CI policy.

### Original compiler refusal, independently read back

[Run 41196344488, attempt 1](https://github.com/techrote/cybersand/actions/runs/41196344488)
ran the above b890 source. Artifact `13041371268` contains 6,378,256 bytes with
SHA-256 `553f66d9d5c5f611d31a827d51a71c923da65843c538f0fef3d0ac541215a503`.
The ZIP CRC, all 25 sealed campaign entries, original owned-build receipts and
original ownership controls were independently checked with the **b890 readers**.
The actual normal parent/child, nonzero-exit and orphan-hang controls passed
their respective positive/negative oracles. Their observed wall times were
0.507788, 0.104820 and 2.419895 seconds; all three jobs were joined.

The diagnostic compiler was MSVC `14.44.35207`, `HostX64/x64/cl.exe`, 677,776
bytes, SHA-256 `fe251ef50a1545b1b0835ee17b1e785459712b38d79e45b5c1d3d28970a36619`.
The raw compiler job recorded four processes. `cl.exe`, `link.exe` and the
observed console host exited zero. `vctip.exe` remained alive until the owner
requested job termination at 13.590305 seconds, retaining its observed exit124.
The complete job was joined at 13.691117 seconds. The 15-second operation
reserved its last 1.5 seconds for cleanup, so the compiler operation correctly
remained failed even though its root exited zero. The game fixture was never
reached: `fixture_attempts` is zero.

Microsoft's [BuildXL MSVC tool definition](https://github.com/microsoft/BuildXL/blob/main/Public/Sdk/Experimental/Msvc/VisualCpp/visualCpp.dsc)
identifies VCTIP as a possible surviving compiler child used for telemetry.
That does not prove this particular child would finish naturally after 15
seconds. This successor allows the actual contained job to demonstrate its
result. It does not ignore, detach, rename or globally terminate a process,
modify compiler binaries, or infer a successful join from the root's exit.
No undocumented telemetry environment key is assumed to prevent child creation.

### Versioned execution policy and unchanged ownership

[`windows_crash_policy.py`](../../tools/play/windows_crash_policy.py) is the
single policy source for this original-source apparatus. Both execution and
offline reduction import it. The exact policy is retained in `campaign.json`;
compiler `/D` arguments select the same capture/case bounds in the C++ broker,
whose source refuses compilation without those explicit definitions. The
campaign, broker and owned-build schemas advance to v4, v3 and v2 respectively.
Older evidence continues to require its original source readers.

| Operation | v4 watchdog |
|---|---:|
| Owned SDK compilation, Git evidence operations, engine version probe | 300 seconds |
| Each ordinary exception-control process | 300 seconds |
| Required module hash and dump helper | 300 seconds, capped by remaining parent time |
| Godot import | 1,200 seconds |
| Original standalone complex fixture process | 3,600 seconds |
| Hosted job / diagnostic stage | 180 / 150 minutes |
| Owned-operation cleanup reserve | Up to 10 seconds within its existing watchdog |
| Outer broker cleanup observation | 10 seconds, then bounded termination/join observation |

The deliberately hung ownership, debuggee and dump-writer controls retain
their separate 3-second, 500-millisecond and 1-second injected boundaries.
The dump-writer control's parent stays 15 seconds. These are explicit adverse
controls, not implicit normal-workload limits. The materialization stage gets
20 minutes; the whole-job ceiling covers it plus the sequential diagnostic
stage and artifact collection. No elapsed performance target is introduced.

The former fixed 160-sample cap would still cut off a 300-second operation
near 16 seconds. Sample capacity now derives from the prescribed watchdog and
10-Hz interval with four samples of headroom; portable verification derives
the same bound. Every raw sample, observed process image, creation time, CPU
time, exit code, log size and final empty-job state remains retained. The
32-process limit, creation-time Job/handle membership, no-breakaway policy,
nonzero-exit propagation and strict observed join requirements are unchanged.
An unjoined process, late exit or watchdog termination cannot pass.

### Qualification of the successor

The Windows campaign adds an actual 20-second child that exits zero and an
actual 20-second child that exits19. Each requires the child execution marker,
exact two-process accounting, observed child identity, full natural join and
wall time beyond the former 15-second limit; the latter must retain both
nonzero exits and its failed operation status while satisfying the negative
control oracle. Existing normal/nonzero/orphan controls remain mandatory.

Local portable qualification passes **27 owned-build tests and 57
crash/artifact tests**, normally and under `python -O`. The additions exercise
30-second successful and late-failing modeled operations beyond both old
limits, a full 300-second modeled hang with observed termination/join,
invalid/nonfinite bounds, slow command execution/exit propagation, false
fast-execution receipts, late-child failure, capture/hash completion beyond
15 seconds, unjoined hash refusal and resealed policy substitution.
These virtual-clock and mock-Win32 controls do not claim actual Windows
execution. The provider-policy check and whitespace check also pass.
Historical M11 integrity passes. Local documentation/repository checks retain
the same six absent companion-workspace expected-fact inputs (source provenance,
Web threading, development wrapper/guide and browser results); these are
reported as failures, not dismissed as successful checks. No protected source
or runtime/provenance manifest was changed to address them.

Fresh exact-source hosted ownership controls, SDK builds, debugger controls,
import and the one original fixture attempt remain required. If VCTIP still
does not leave its owned job before the generous watchdog, that attempt must
retain the complete partial evidence and remain failed; no basename exception
is authorized. A later successful diagnostic will mean only that one exact
debugger attempt observed no process failure. It cannot establish the cause
or repair of original access violation `0xC0000005` in run41175131563.

## Diagnostic-only clang-cl and lld successor — v5

The owner authorized a change to the diagnostic toolchain after the generous
MSVC attempt still failed before reaching the game. This successor starts at
#329 head 2be6d0a388d1c4dfb607df04ac59dca7a9879ac6, tree
e24efbbb1bd4888f7011e36f2cfed92d635706fe. The original production, native,
runtime, fixture and ordinary-CI source fence remains unchanged. The C++ broker
and C exception-control source also remain byte-identical to that v4 attempt.
Only their compiler/linker configuration, custody readers, tests, policy
envelope and dedicated workflow change.

### Preserved 300-second MSVC failure

[Run 41235058997, attempt 1](https://github.com/techrote/cybersand/actions/runs/41235058997),
job 124636953307, retained artifact 13055585103: 6,604,663 bytes, SHA-256
6473233612d17000653554eca5c8b5b3551adfcedb8853fd7d1a407ba2faf95f.
Independent readback verified the ZIP CRC, all 33 sealed entries, 795 scoped
source inputs, all 15 source-matched Python reader files, native/Rapier
provenance, all five actual ownership controls and the original failed build
reduction. The full v4 campaign reader correctly rejects the incomplete
campaign. No old receipt, process status, timeout or manifest was rewritten.

The same pinned MSVC binary recorded cl.exe PID 724, link.exe PID 4396 and
conhost.exe PID 6364 exiting zero by 7.446344 seconds. Its vctip.exe descendant,
PID 2080 with creation identity 134379491098269622, was first observed at
3.019958 seconds and remained the only live owned process after compilation.
The owner requested termination at 290.001062 seconds, reserving the last
10 seconds of the existing 300-second operation. VCTIP exited 124 and the job
was joined at 290.102039 seconds. The completed executable/PDB do not turn
this operation into a pass. The retained fixture-attempt count is zero.

Normal child and nonzero controls completed in 0.508659 and 0.104513 seconds.
The deliberate orphan was terminated and joined in 2.415143 seconds.
The 20-second natural-success and late-exit-19 controls completed in
20.092628 and 20.102585 seconds, with their exact positive/negative outcomes.
These actual observations validate the enlarged ownership-control path;
they provide no game, import or debugger exception-capture result.

Microsoft documents [VSCEIP registry opt-out](https://learn.microsoft.com/en-us/visualstudio/ide/visual-studio-experience-improvement-program)
for optional diagnostic data, without promising zero helper creation or a
bounded VCTIP lifetime. Its [BuildXL implementation](https://github.com/microsoft/BuildXL/blob/aab9f814e31aa8a05607bbc4f051e44eb6e2afc7/Public/Src/FrontEnd/Ninja/NinjaPipConstructor.cs)
also recognizes the long-lived compiler child. Neither source establishes an
invocation-local switch satisfying this apparatus's strict natural-join
contract. The owner selected a separately declared LLVM diagnostic build;
no registry opt-out, hidden compiler flag, process-name exception, tool
deletion, prewarmed helper or global process termination is introduced.

### Exact LLVM identity and build custody

GitHub's [Windows-2022 inventory](https://github.com/actions/runner-images/blob/4da2307112a0fad2fd2ecaca8ba7d08683b8c581/images/windows/Windows2022-Readme.md)
lists LLVM 20.1.8. The source selects the existing fixed paths under
C:\Program Files\LLVM\bin and refuses a missing or different installation.
It does not search PATH or silently switch compiler families. The pins below
were derived by extracting only the two executable members from the
[official LLVM 20.1.8 installer](https://github.com/llvm/llvm-project/releases/tag/llvmorg-20.1.8),
after checking its published release-asset size and SHA-256. The installer
was inspected locally, not executed or committed.

| Official file | Bytes | SHA-256 |
|---|---:|---|
| LLVM-20.1.8-win64.exe | 385,658,654 | 3197846a2b19063687dd56e93e34cd941e3548d907f23a6131571321bdf9fe7b |
| bin/clang-cl.exe | 101,879,296 | 51ace51d190c6f09af277bb8d6354b3fb2fd8495cae3d80dcb1c36c2d1a816d4 |
| bin/lld-link.exe | 67,509,760 | 6590ac0122cd5e11fcd05cc9cd5b7ad01cb89961487b9b81c4330fb59abcb5d9 |

The existing x64 developer-shell setup supplies Windows SDK and static CRT
headers/libraries. Their selected environment paths and versions are retained
as context; they are not claimed to be a newly content-pinned SDK distribution.
The two LLVM executables are size/hash checked before work and after each
owned operation; observed identities, including a mismatch, are retained.
Separate version probes must report release 20.1.8 and the
compiler's x86_64-pc-windows-msvc target. Their original logs, identities,
process samples and observed exits are retained.

Each tool is compiled to a retained object with clang-cl /c, then linked by an
explicit lld-link invocation in its own owned job. There is no driver-selected
MSVC linker fallback. Compiler warnings remain errors, optimization stays
disabled, /Z7 CodeView and /MT static CRT stay explicit, and lld emits full
PDBs with warnings treated as errors. LLVM documents the
[clang-cl interface](https://clang.llvm.org/docs/UsersManual.html#clang-cl)
and [Windows lld/PDB support](https://lld.llvm.org/windows_support.html).
The new compiler disables automatic default config files and removes only
compiler-flag/config override environment names from its private build
environment; the original game environment is preserved.

Build schema v2 binds each compile phase to its canonical source and pinned
toolchain, and each link phase to the exact retained object bytes as well.
The object, executable and PDB identities are independently checked offline.
Campaign schema v5 requires both owned version probes and both compile/link
phases for each of the two diagnostic tools. All original debugger controls
remain mandatory, including normal exit, handled access violation, unhandled
fault, child fault, hung target and hung dump writer. Their real Windows
execution must qualify the new compiler before the original game is attempted.

The unchanged owned-build v2 format retains its honest 10-Hz observation
scope. New LLVM phase/version acceptance adds a stricter cross-check:
the final Job total-process count must equal the number of distinct observed
exits. A short-lived unobserved child therefore fails the LLVM phase even if
the generic historical reducer can establish an empty job. Every observed
exit must be zero, every job must join naturally, and any timeout, termination,
late exit, nonzero child or missing final ownership observation still fails.
The MSVC failures keep their original readers and original failed status.

### Watchdogs and qualification limits

Every owned operation remains bounded by 300 seconds, including its existing
cleanup reserve. The additional two LLVM version probes and explicit separate
compile/link phases require a larger sequential envelope, not a larger
per-operation limit. Policy v2 records a 180-minute diagnostic stage and
270-minute hosted job; the workflow includes 45 minutes for sequential
dependency materialization and headroom for source/readback/artifact work.
Import, original fixture, dump/hash work and all injected adverse-control
deadlines remain unchanged from v4.
The executed v4 workflow had a 240-minute job and 45-minute materialization
stage; its policy still declared a 180-minute job and its older narrative
retained a 20-minute materialization stage.
Those original records remain intact; v5 aligns its policy and workflow.

Portable validation passes 32 ownership/build tests and 64 crash/artifact
tests, normally and with Python assertions disabled. Provider, documentation,
current repository identity, historical M11 and whitespace checks pass.
Retrieval keeps 32/32 canonical top-five hits, 19 top-one hits and MRR 0.7536;
these lexical scores do not establish answer correctness. The repository
identity check explicitly reports unmaterialized runtime pointers here.
Added controls reject same-size compiler/linker substitution, wrong
release/target, ambient compiler-flag overrides, version-probe failure,
unobserved short-lived child exits, MSVC linker fallback, missing link phase,
failed linker after compiler success, altered objects/PDBs and historical
v4 receipts presented as v5. These are reducer, filesystem and mock-operation
checks; they are not Windows compilation or runtime evidence.

The exact resulting source must still pass its first hosted Windows attempt:
all ownership controls, pinned LLVM probes/builds, debugger controls, import
and one original fixture execution. Any compilation incompatibility or
different installed LLVM identity remains a visible failure with preserved
partial evidence. A later successful diagnostic cannot identify the cause
of the original 0xC0000005 by itself, repair it, or qualify current-main
gameplay/shader integration.
