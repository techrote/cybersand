---
status: Planned
date: 2026-11-26
scope: External source-pinned qualification annex; frozen application unchanged
---

# Strata 003 — cold first shipped Windows command

## Registered boundary

The frozen application is `fd0830abcfadd9ae19162e5677943bb131223e59`, tree
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`. This external observer is a separate
commit and workflow. It must consume an already built evaluator with exact
original GitHub run/artifact ID, name, inner ZIP byte count/SHA-256 and manifest
SHA-256. The request is deliberately **unarmed** until those real identities
exist. It cannot execute with guessed or placeholder identities.

The original package workflow verifies a pristine extraction and runs its full
native qualification suite before executing `Open Workbench.cmd`. That proves
the actual command on unchanged package bytes with prepared generated state.
This annex closes the narrower cold first-command gap on a second, new
extraction. It does not replace or relabel any earlier result.

## Exact execution order

1. Authenticate artifact metadata and verify the exact shipped ZIP and complete
   manifest payload. Check out the frozen application only for its existing
   static package verifier. No Godot executable is run for version discovery.
2. Extract into an absent folder whose name contains spaces. Prove exact initial
   payload bytes, with neither `godot/.godot` nor `userdata` present.
3. Run the unchanged frozen static `verify(..., pristine=True)`. Prove again that
   it did not alter the extraction or create runtime state.
4. Execute the untouched shipped `Open Workbench.cmd` through actual Windows
   `cmd.exe /d /s /c`. This is the first Godot invocation in that extraction. The
   command itself performs its existing headless editor import, then starts the
   ordinary graphical Workbench. Arguments are audio Dummy, Compatibility
   OpenGL3, and `--quit-after 180`. The whole command retains a 180-second
   watchdog; timeout/failure is a rejection, with owned descendants cleaned up.
5. Require a single real Workbench admission from the frozen source and ordinary
   shared Workbench script: positive native generation, opaque nonzero signed
   worker identity, default 2048×2048 extent and Strata disabled. Retain the actual
   graphical backend, both official Godot startup headers, process exit and
   bounded shutdown. No diagnostic scene is substituted for ordinary startup.
6. Rehash every original shipped file and rerun the frozen static verifier.
   Existing authored files, including existing import/UID sidecars, must remain
   exact. New cache/userdata and new importer sidecars for existing shipped
   resource files are recorded separately; they are never an integrity exemption
   for an original file.

## Measurements and custody

The frozen half-second process-tree sampler supplies actual PID/start-time
identities, user+kernel CPU counters and sampled simultaneous RSS. Query-only
Win32 handles are additionally retained for observed processes until shutdown.
Their `GetProcessTimes` creation/exit values and actual full executable paths
bind the two sequential shipped console stages and their actual bundled Godot
children. The first console stage's lifetime is **cold import command lifetime**,
including startup and teardown. It is neither pure import CPU time nor scene
admission latency. The second is ordinary Workbench command lifetime. Missing
required process witnesses reject the timing evidence; the observer does not
invent a duration from nearby log lines. All observed descendants must have
exited successfully. Cleanup checks identities before terminating only owned
processes after a failure.

The artifact retains original CMD logs, resource samples, held-handle lifetimes,
request, authenticated artifact metadata, original manifest, initial/final
payload inventories, generated-state hashes, external observer source and hashes,
frozen verifier hashes, and the complete receipt. The large original evaluator
ZIP stays in its original package artifact and is supplied separately when
re-reading. The cold reader validates exact ZIP/payload custody and the cold
receipts without claiming to rerun the embedded full nine-scene suite. The full
frozen static verifier actually runs on Windows both before and after the CMD;
the independent cold receipt reader is portable across hosts.

This is a source-bound hosted Windows startup, cold import and shutdown check.
It makes no new native progression, ordinary interaction, input-to-photon,
physical Windows 11/NVIDIA, or owner artistic acceptance claim. Existing optical
performance failures and the 45-second scene-admission target remain unchanged.
The package and application remain Draft/HOLD.

## Preparation validation

The initial external source passed twenty-one focused adverse controls, Python
compilation, `actionlint`, the repository's GitHub-hosted provider policy and
`git diff --check`. These are source/reader checks, not Windows execution.
The documentation checker reported six missing expected-fact sources outside
this isolated worktree (`../../SOURCE-PROVENANCE.json`, companion documentation,
development tooling and browser results); it did not report a malformed new
document. Those absent companion-workspace inputs are retained as a limitation,
not silently replaced or counted as a passing documentation campaign.

Independent lead/A/B source review closed raw ZIP filename normalization,
nested receipt inventory, process-clock and constructor-failure cleanup gaps
before hosted execution. The cleanup control proves that observer initialization
failure cannot silently leave the newly launched owner command unhandled, and
that cleanup errors still retain a rejected receipt and close query handles.

## Read-only API basis

The observer uses Microsoft's documented [full process image path query](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-queryfullprocessimagenamew),
[process creation and exit times](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes),
and [process exit code](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getexitcodeprocess).
An open process handle remains valid after termination until closed, permitting
actual completed lifetime observations without changing the child application.
