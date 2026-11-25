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
