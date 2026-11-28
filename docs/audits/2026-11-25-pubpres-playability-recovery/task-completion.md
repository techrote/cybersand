# Default-off actual-task pool completion

Disposition: **implemented candidate; native World/application/performance
qualification pending.** The mechanism was registered in commit
`62942b479` before its implementation or execution. The existing native stage
diagnostic motivates investigating pool synchronization; it does not establish
that idle-worker acknowledgement caused the measured native intervals.

## Ownership and completion contract

The production `PersistentWorkerPool` has moved into a private source header so
the lifetime test instantiates the real class. The original all-worker dispatch
algorithm remains the control. Both modes record completed real dispatches/tasks
on the exclusive owner after their barrier returns; neither counter grants a
native or Rapier step.

The new default-off path claims a task number, function and current context under
the existing mutex. A worker without a real claim cannot retain context. Each
task finishes every context/data/statistics access and automatic destructor
before reacquiring the mutex and decrementing the unfinished count. The caller
waits for zero under that same mutex. A delayed thread can claim only currently
published work, so context can retire without an acknowledgement from a thread
that borrowed nothing. There is no extra worker, unbounded queue, tick-time
allocation, per-cell synchronization or changed solver work.

`cybersand/pubpres_task_completion_barrier` is a strict boolean captured during
native adapter construction. Prepared Worlds clone it from the actual owner;
diagnostic rebuilds retain that captured choice. The active native
`get_wave_flow_status().task_completion` reports schema, actual mode and completed
counts even for non-Wave Worlds. One-worker mode is a truthful no-dispatch
fallback, never evidence that the treatment ran. The opt-in liquid run receipt
records the execution-policy difference; default-off receipt bytes retain their
previous identity. Physical state and save identities exclude this execution
choice just as they exclude worker count.

## Executed component scope

The production-class lifetime fixture passed **495 checks** in normal, scoped
AddressSanitizer/UndefinedBehaviorSanitizer and ThreadSanitizer builds on the
local Linux GCC host. Three idle workers are held before acquiring any pool
lock while one worker completes 192 batches and the caller immediately destroys
their heap contexts. Zero-work gaps and 128 later batches test current-generation
claims after the delayed workers arrive. Another controlled final task proves
its callback/destructor writes finish before owner completion. The original
control still waits for delayed acknowledgement. Participant masks and repeated
construction/retirement are checked.

The first address/undefined invocation's default LeakSanitizer exit failed
because this execution environment reports unsupported ptrace. The original
message is retained. An explicit `ASAN_OPTIONS=detect_leaks=0` rerun passed the
address/undefined checks. This does not establish leak freedom. TSan executed
and passed; it was not skipped or relabelled.

Specialist B independently reviewed both the production lifetime edge and the
adversarial tests. The review found no source blocker: all callback access ends
before decrement, owner and workers use the same mutex, late idle workers do
not carry retired context and participant writes precede completion. The review
explicitly requires actual native World parity and refuses to infer gameplay or
performance from this component result.

## Remaining qualification

`test_task_completion_world.cpp` is a new scoped semantic fixture for FreeMass,
Wave with ballistic Water, all three PressureFlow variants, Sand/other material
interaction, body occupancy/contact responses, repeated edits and region
pause/re-entry. It compares every actual tick's content, state, complete physical
hash, quantity ledger, scheduled/visited work and body response across one/four
workers and both completion modes. The mounted native fixture additionally
checks strict selector refusal, immutable readback, prepared-owner propagation,
actual execution counts and equal real material publication. These fixtures are
written but not yet reported executed at this checkpoint.

The registered `task-completion-abba` runner uses the same newly built native
binary in all four arms, explicit0/1/1/0 mode, stock Safe engine, frozen physical
reader and exact actor/input parity. It rejects missing, reset, coerced, zero or
mislabeled native task/dispatch observations. Every candidate must actually run
the selected pool. Resulting-source builds and qualified runtime provenance are
mandatory; the retained original4bde runtime cannot execute this native change.
The original sample-idle treatment remains unselected and off.
