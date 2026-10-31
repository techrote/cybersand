# Execution watchdog modernization — 2026-10-31

## Baseline and owner decision

The live baseline was main `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, tree
`ad800ebd5c876f6d1ecd080a6dc3f02918b21870`. Original attempt-1 post-merge runs
[Docs 41204873388](https://github.com/techrote/cybersand/actions/runs/41204873388),
[Native scope 41204873081](https://github.com/techrote/cybersand/actions/runs/41204873081),
[Native 41204873121](https://github.com/techrote/cybersand/actions/runs/41204873121)
and [Godot 41204873192](https://github.com/techrote/cybersand/actions/runs/41204873192)
were complete and successful. #269 was already closed; #268/#270/#263 remained
open. Source heads of #324 and #325 were ancestors of accepted main, so both
redundant stacked PRs were closed administratively without duplicate merges.

The owner explicitly superseded historical 30/180/240/15/150-second execution
restrictions and the shader deferral. The [current execution policy](../operations/ci-execution-and-performance.md)
owns the new contract. #326 integration is now an active separate production
work package. Scheduswarm remains paused, with ownership recorded on
[#305](https://github.com/techrote/cybersand/issues/305#issuecomment-6548109639).
No physical device, human feel or release acceptance follows from this change.

## Focused implementation and review scope

The change shares named watchdogs among Godot helpers, Python runners/readers,
native command wrappers and hosted parent planners. It retains existing sample
windows, physics/native inputs and sanitizer environments. It adds complete
parent-budget proofs, source-bound original receipts, strict owned teardown,
mandatory Linux union verification and nonblocking comparable performance
history. No production C++, native binary or runtime manifest changes occur.

The former conditional Linux serial-migration lane was skipped on accepted
post-merge run 41204873192. Its obsolete four-shard assumption is replaced with a
mandatory independent exact-source/unique-coverage reader for all current Linux
cases. This changes the qualification apparatus, not the discovered fixture
inventory. Original Windows coverage and the stable Native/Linux aggregate
requirements remain. Failed ready-scope classification now forces a failed
required aggregate rather than a green-looking skipped gate.

Independent agents reviewed the Native command inventory, the 154-operation
bounded dispatcher and the performance collector. Root and independent review
also found and corrected rapid detached-child ownership, inconsistent local
`/proc` identity, integer JSON PID keys and malformed optional history metadata.
The first unsuccessful local controls remain separate evidence; they were not
relabeled as success. The final tested source and hosted gate run identities
belong in the resulting PR and #305 ledger, not in a self-referential source hash.

## Actual local controls and limits

Godot's shared policy controls passed 97 assertions at the default scale and
again at scale 2. Actual local Godot runs exercised desktop-default behavior,
LIFE001, LIFE003, LIFE009, INPUT010, INPUT011, LIFE010, LIFE011, UI007, legacy
pause, tick-failure and lifecycle fixtures. Native process controls use real
short Python children; they do not replace the original full Native suite.

The focused Python checks cover fast/slow/late-failing/hung/teardown execution,
original receipt preservation, exact platform sharding, independent PLAY source
readbacks, all native commands and process arguments, scientific assertion order,
strict Linux/Windows coverage, source attribution and adverse history inputs.
Local GDScript runtime evidence uses pinned Godot 4.7 with retained Linux native
and Rapier bytes. These results establish local apparatus behavior; complete
hosted original suites and independent source review remain acceptance gates.

## Diagnostic investigation remains separate

The original Windows crash at `aa74448` is still unexplained. The first repaired
strict diagnostic [run 41235058997](https://github.com/techrote/cybersand/actions/runs/41235058997)
at #329 source `2be6d0a388d1c4dfb607df04ac59dca7a9879ac6` failed before the
fixture. `cl.exe`, `link.exe` and `conhost.exe` exited zero by 7.446 seconds, but
the owned `vctip.exe` child remained alive. Termination was requested at 290.001
seconds, preserving ten seconds for cleanup; VCTIP exited 124 and the Job joined
empty at 290.102 seconds. The receipt correctly records failure and zero fixture
attempts. Actual 20-second slow success and delayed exit-19 controls passed their
respective contracts. The 33 sealed artifact entries were independently verified.

Artifact 13055585103 is 6,604,663 bytes, SHA-256
`6473233612d17000653554eca5c8b5b3551adfcedb8853fd7d1a407ba2faf95f`.
The original 15-second failed campaign and this 300-second successor retain their
own identities. A declared diagnostic-only toolchain successor is a separate
experiment; it must preserve the original game fixture/runtime, strict descendant
join and late-exit accounting. This watchdog PR does not claim to cure a game
access violation by extending time limits.
