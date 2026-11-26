---
status: Current
date: 2026-11-26
scope: Independent source and adverse-control review; actual cold Windows execution pending
---

# Independent review — cold first shipped Windows command observer

## Disposition and identities

Specialist A finds no remaining concrete source blocker in the external cold
observer at `84064baeff871c61a36b4374d93c22fca697c3d9`, tree
`f705751c327caef94b2d753b9411fdb0cd7144b2`. I independently ran its **21 adverse
controls successfully** after reviewing the implementation and workflow. This
qualifies the source review and controls only. The exact package request was
still deliberately unarmed at this review; no cold Windows result is inferred.

| Reviewed input | SHA-256 |
|---|---|
| `tools/ci/strata3_cold_launcher.py` | `df8d28df8e97392feec75f9d15f6b515af5325deb9cb4f0662a02fa60288edc6` |
| `tools/ci/test_strata3_cold_launcher.py` | `2c483680d633a232f4fc98a39bc6b009cc751ec682acb5802f714caee577e7eb` |
| `.github/workflows/strata-theatre-003-cold-launch.yml` | `c1556d13382c61f69ec94c5846e6e8f85bc532f7ed24b0d4a75229a5a70d486e` |
| Unarmed `tools/ci/strata3-cold-launch-request.json` | `0416e3d745c1fbabd3b78f337d3edee87f0295e64d0664e28e81178940257d5c` |

Application `fd0830abcfadd9ae19162e5677943bb131223e59` remains unchanged. Arming
the exact package request will produce a separate observer identity. Its actual
run and original evidence must be recorded under that identity, without
relabeling this source review as an execution result.

## First-launch boundary and custody

The workflow runs Python controls, authenticates one requested artifact and
downloads its exact package before extraction. It performs no Godot version
probe, editor bootstrap or application harness invocation. The observer verifies
the ZIP SHA/length, original manifest identity and complete payload. It validates
original decoded ZIP names before any truncation/normalization, rejects ambiguous
paths, duplicate case-folded names, links and pre-existing runtime caches, and
extracts into a previously absent path containing spaces.

The first application operation is the unchanged shipped `Open Workbench.cmd`.
Only the frozen package's static `verify(..., pristine=True)` precedes it. The
observer rechecks payload bytes and absence of `.godot`/`userdata` immediately
before the command. The command's own headless import remains part of the cold
command boundary. The second stage is the ordinary graphical shared Workbench;
no custom graphical test script substitutes for it. Actual CMD quoting includes
the ordinary spaced package path, Compatibility/OpenGL3 arguments and a bounded
180-callback exit request. The whole process has a 180-second watchdog.

Exact source/tree, imported frozen verifier bytes, launcher bytes, both runtime
executables and original payload hashes remain bound to the receipt. Every
original file must remain exact after execution. Newly generated caches,
userdata and admitted sidecars are separately inventoried; they do not excuse
changes to shipped files. The strict reader checks both original and nested
evidence inventory entries rather than ignoring repeated receipt basenames.

## Process identity, timing and shutdown

The observer binds the actual CMD image, two ordered shipped console executable
stages and their corresponding bundled GUI engine children by PID, process
creation identity, full image path and parent lifetime. It retains query handles
through process exit and obtains creation/exit times from those handles. The
root process FILETIME is constrained against the actual invocation's wall clock;
the registered process tree must fit inside the observed launcher lifetime.
Every retained process must have exited successfully. Unrelated process images,
parents, overlapping stages, live engines and unbounded lifetimes are rejected.

The first console lifetime includes cold import startup and teardown. The second
includes ordinary Workbench startup, execution and teardown. Neither is a native
scene-admission duration, pure import CPU time or input-to-photon measurement.
CPU is retained observed process-tree user/kernel time; memory is sampled
simultaneous process RSS. Missing short-lived required process witnesses reject
the evidence rather than inventing durations from log timestamps.

The log must contain both exact Godot headers, one actual graphical Compatibility
backend, no script/engine error, and one native ordinary-Workbench admission for
the frozen source, 2048-square extent, positive generation, nonzero worker
identity and Strata disabled. This is a startup/shutdown boundary; it does not
claim human interaction or new graphical scene qualification.

## Concrete issue found and repaired

In `fc06e427`, `Popen` preceded observer initialization and exception cleanup
required a non-null reader. A reader or process-tree constructor failure after
starting CMD could leave that launched tree running. I reported this concrete
failure path to C and root.

The reviewed `84064bae` correction constructs query APIs before `Popen`; any
later process-tree initialization failure attempts bounded cleanup of the owned
process. Cleanup exceptions are retained while final query handles are closed
and process/resource/lifetime receipts are written. The strict reader rejects
any cleanup errors. Two focused mocked controls verify that a query-constructor
failure starts no child, and a later tree-constructor failure invokes cleanup,
retains its error and still closes handles. I inspected the correction and
reran all 21 controls successfully. The observer remains independent of the
application and its shipped launcher.

## Remaining acceptance boundary

The actual source-bound cold run is still required after the real package
identity is armed. Any timeout, missing process witness, payload mutation,
script error or incomplete shutdown must remain a failed annex. This check does
not erase earlier 45-second scene-admission failures, the enabled-optics
performance hold, or pending physical Windows 11/NVIDIA and artistic owner
acceptance. Application and package remain Draft/HOLD.
