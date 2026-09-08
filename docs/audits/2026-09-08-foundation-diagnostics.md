---
title: Foundational diagnostic observations
status: Current
document-kind: evidence
scope: Dated Windows source-built probes of interest re-entry and partial tick failure at native implementation checkpoint 126175c
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [../reference/validation-evidence.md, ../systems/world-storage-and-interest-region.md, ../architecture/simulation-tick-and-threading.md]
---

# Foundational diagnostic observations

**Historical evidence for the tested implementation, 2026-09-08.** These probes
establish narrow observed defects; they do not define approved fixes or broad
platform acceptance. Native source is unchanged from
`126175cfc4dd1fb8659212f62b9b517bac54d8c2`; documentation was being rewritten.

Both used Windows 11 x86_64, LLVM-MinGW 20260826/UCRT Clang 23.1.0, C++20 `-O0 -g3`.
Compilation was bounded to 60 seconds and each run to 10 seconds; both recorded
compile/run exits 0. Runtime PATH included the toolchain's DLL directory. The
first interest-probe launch lacked that PATH and failed before execution; the
recorded rerun corrected it. This setup error is separate from the reproduced defect.

## Interest-region exit and re-entry

[Diagnostic source](foundation-diagnostics-2026-09-08/interest_probe.cpp.txt)
places Sand at (400,32), excludes its cores, allows active blocks to sleep, then
restores the region. Re-entry schedules 0 cores and the Sand remains stationary.
A neighboring cell write wakes it and the next tick moves it down.
SerialInPlace advances the same excluded Sand because it does not use the phased
region filter. See [current contract](../systems/world-storage-and-interest-region.md#interest-filtering-and-re-entry).

## Capacity failure after tick entry

[Diagnostic source](foundation-diagnostics-2026-09-08/tick_failure_probe.cpp.txt)
sets one worker, active-core capacity 1 and event capacity 1. With no event,
planning throws after tick 0 becomes 1: `content_hash` is unchanged, `state_hash` differs.
With a radius 1 explosion accepted first, planning still throws, but center Wall
has become Fire and its neighbor Wall becomes Empty. The event queue has drained,
shown by successful new enqueue into its capacity-one slot after failure.
There is no restoration of pre-tick state. See [failure contract](../architecture/simulation-tick-and-threading.md#what-happens-when-a-tick-fails-or-overloads).

## Reproduce and interpret

The [curated evidence JSON](foundation-diagnostics-2026-09-08/evidence.json)
contains dates, input hashes, compiler/configuration, executable hashes and raw
local evidence locations. Preserved `.cpp.txt` files are documentation artifacts;
copy a selected probe to an external temporary `.cpp` path before compiling.
From the source root, with the recorded toolchain on PATH:

```text
clang++ -std=c++20 -O0 -g3 -Inative/include native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp <probe.cpp> -o <probe.exe>
```

Apply 60-second compile and 10-second execution timeouts with the host runner.
No tests ran against Godot, Rapier or Web in these diagnostics. A redundant
independent tick probe agreed, but is not counted as an additional acceptance
result. The [roadmap](../reference/status-and-roadmap.md) keeps intended failure
and activation policies open for the next implementation checkpoint.
