# Completed-sample owner idle candidate — 25 November 2026

**Default-off / performance unselected / Draft-HOLD.** This candidate addresses
avoidable owner work while Main cannot advance. It does not claim that removing
status publication will repair render rendezvous or make Workbench playable.

## Mechanism and authority

The normal Workbench sample fence admits one native material turn for an actual
body sample. After that turn completes, repeating the worker loop cannot perform
another required material turn until Main submits a fresh sample. The prior
worker nevertheless rebuilds its complete copied status dictionaries at its
16.7 ms timer cadence. This candidate waits on the same copied owner controls,
with a maximum250 ms status heartbeat, only while the actual prepared and
completed body samples match and the native result is healthy/valid.

New body samples, pause, settings, edits, actor/World retirement, pending
publication ACK/resync, view origins and tracing changes interrupt or bypass the
wait. A native revision awaiting its render deadline shortens that wait. The
worker publishes its actual completion before waiting. No additional Rapier
step, stale body reuse, suppressed native material tick, material coalescing,
changed upload/history policy, or fabricated physical credit is introduced.
No-body worlds, paused authoring and timer-only sample-wake-disabled modes retain
the original cadence. The explicit selector is
`CYBERSAND_DIAG_WORKBENCH_SAMPLE_IDLE=1`; omitted/other values keep it off.

The prospective [registration](../../../tools/pubpres_recovery/sample_idle_registration.json)
requires same-source/runtime serial0/1/1/0 comparisons on Wave512 and current
Wave2048, unchanged complete V3 physical gates, actual treatment execution,
material/pose freshness, and the existing strict physical direction rule.
`tools/pubpres_final/run_comparison.py --mode sample-idle-abba --presentation-observer`
uses that registration. It refuses no-op treatment arms, nonzero control waits,
coerced counters, changed selectors and claimed physical credit. These extra
counters are only evidence that the wait actually ran.

## Executed correctness

The [retained lifecycle packet](sample-idle-lifecycle.json) binds the original
source base `f4089809c7294336db26cf576b0ac3c57fc54775`, exact changed source/fixture
hashes and original source-matched native C runtime from run45477483707. No
native input changed. The qualification runtime is the original GCC13.3 build;
a separate disclosed GCC14.2 development build was also completed but supplies
none of these qualification outcomes.

The production worker/Main/native/Rapier fixture passed **58 checks headless**
and **58 checks with actual graphical Xorg/llvmpipe execution** on pinned official
Godot4.7. It covers deliberately held Main with a genuinely completed final
sample, bounded status heartbeat, immutable image bytes, actual Main upload/ACK,
resync, material edit and due render publication, origin/trace wakes, pause,
ordinary paint, resume with fresh actual Rapier samples, no-body evolution,
World replacement, and joined stop/mailbox retirement. Five adversarial reader
tests and the seven existing final-contract tests also pass.

The first live fixture was wrong: snapshot `completed==offered` could identify
an old snapshot while Main had already issued a newer body sample. Its five
failed assertions remain preserved. The repaired fixture additionally joins the
completion to Main's `_workbench_wait_sample` before checking stopped native
progression. No production semantics were changed for this oracle repair.

Specialist B independently reviewed the helper and loop invocation and found no
correctness blocker. The two mutex reads per250µs poll remain overhead, so their
cost and any actual gameplay benefit must be measured. The graphical lifecycle
fixture is not a comparative performance pass or physical owner acceptance.

## Completed matched graphical comparison

The same-source Linux graphical 0/1/1/0 comparison completed all eight arms on
application and driver `0bd275a36669a18217f7861372bbf54a837af750`, tree
`2999f6f1188f9c17b2b70fcf673bfa615e2cbc6b`. Both workloads are
**NOT_ESTABLISHED / UNSELECTED** under the prospectively registered direction
rule. The selector remains off. Every original frozen V3 physical correctness
gate passed; every candidate actually entered the completed-sample wait and
every control reported zero waits. Equal-step body trajectories and admitted
movement hashes matched all four arms in each workload.

| Workload | Arm / selector | Real steps/s | p95 gap, ms | p99 gap, ms | Maximum gap, ms |
|---|---|---:|---:|---:|---:|
| Wave512 | first control / 0 | 22.991 | 55.483 | 74.944 | 142.902 |
| Wave512 | first candidate / 1 | 23.064 | 51.282 | 140.013 | 156.637 |
| Wave512 | second candidate / 1 | 22.552 | 55.929 | 114.297 | 149.615 |
| Wave512 | final control / 0 | 22.329 | 62.383 | 135.256 | 146.959 |
| Gameplay Wave2048 | first control / 0 | 8.826 | 180.396 | 217.243 | 297.245 |
| Gameplay Wave2048 | first candidate / 1 | 8.933 | 174.905 | 193.157 | 285.659 |
| Gameplay Wave2048 | second candidate / 1 | 8.681 | 179.638 | 288.501 | 387.151 |
| Gameplay Wave2048 | final control / 0 | 7.375 | 231.729 | 317.081 | 353.588 |

These are the first 144 genuine completed steps per arm. Wave512 processes
continued to the registered ten-second minimum capture. The second candidate in
each workload was slower than the first control. Wave512 candidate maxima both
exceeded the worse control; the second Wave2048 candidate also exceeded the worse
control maximum. Improvements in some other values do not satisfy selection.
The later large control deteriorated, which is preserved rather than averaged
away. This is a short hosted comparison, not sustained play or physical NVIDIA
acceptance.

The [result packet](sample-idle-local/results.json) retains the complete direction
decisions, exact physical outcome hashes, treatment readback, material/pose ages,
omission counts, CPU accounting, memory and all important source identities.
[Original source custody](sample-idle-local/source-custody.json), each original
application/process/CPU/memory/observer receipt, and the complete
[causal interval reduction](sample-idle-local/causal-intervals.json) are retained
alongside it. The [original-file manifest](sample-idle-local/original-manifest.json)
pins every raw trace, screenshot and process output; final mission artifact
custody must additionally preserve those complete local originals.

## What the recorded clocks establish

The unchanged independent interval reducer replayed all eight original traces
successfully. On Wave512, 88–89% of the ordered inter-step span occurred after
native completion was independently observed and before the successful physical
callback began. Matched native profiler medians were only 2.16–2.50 ms. This
candidate did not substantially remove that Main admission delay.

The large local workload has a different cost distribution: 72.9–76.6% of the
ordered inter-step span preceded the next native completion observation,
20.6–24.2% lay between that observation and the successful callback, and roughly
3% was inside that successful callback. Matched native tick profiler medians
were 95.08 / 99.43 / 93.92 / 118.10 ms in arm order. The largest candidate gap,
387.151 ms, contains 270.191 ms before native observation, 111.126 ms after native
observation and 5.834 ms inside the successful callback. Its independently joined
native profiler value was 267.698 ms.

These are recorded partitions, not inferred native start clocks. The profiler
value is the actual `world_->tick()` elapsed bracket, reported separately; it
does not distinguish execution from descheduling. Accepted Main publication
transactions overlap only 3.08–3.49% of the large ordered inter-step span. This
does not identify GPU, driver, render-owner or counterfactual causality. The
result justifies targeted existing-stage native readback and continued Main
rendezvous investigation, without importing the older Windows causal split into
this Linux software-rendering host.

Whole-process CPU means were 3.31 / 3.24 / 3.26 / 3.22 core-equivalents for
Wave512 and 4.23 / 4.31 / 4.21 / 3.57 for Wave2048. Those intervals include scene
setup and capture. The external CPU samples are not aligned to Godot capture
clocks, so capture-only CPU and per-stage CPU remain unavailable. Native elapsed
time and these process CPU values must not be interchanged.

## Original local ownership failures

The first two attempts failed before a measured arm ran. Their headless import
process exited zero, but the unchanged process owner correctly detected a
surviving child. A focused same-DISPLAY reproduction retained a real adopted
`dbus-launch` zombie: PID 26, parent 10, process group/session 11, start tick
684759, descended from owned Godot PID 11. The Xorg server was a separate sibling.
This was a local desktop-bus autolaunch and reaping issue, not a fabricated
failure of native or graphical simulation.

The controlled environment supplies an explicit unavailable local session-bus
endpoint. The original import and an actual graphical ordinary Workbench process
then passed the same ownership predicates, with no waiver or code change. The
exact same endpoint policy was applied to every measured comparison arm.
Original failed receipts, the PID/stat diagnostic and successful unchanged-owner
validation are retained under `sample-idle-local/original-failures/`. This local
environment control says nothing about the owner's desktop-bus state.
