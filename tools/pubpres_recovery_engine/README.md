# PUBPRES atomic application/draw admission — recovery experiment

Disposition: default-off development component. Application, actual graphical first
reads, lifecycle, resulting-source builds and matched performance must qualify it
before architecture selection. The original three-patch bounded component and its
qualified Windows payload remain unchanged in `tools/pubpres_final_frame_budget`.

## Why a fourth patch is necessary

The application stages coherent canvas/shader state before Main flushes its message
queue. A `frame_pre_draw` callback that refuses only its journal cannot prevent those
already-staged pixels from drawing. The recovery prototype reproduced that defect
with an intervening camera/policy transition: old picking history accompanied new
pixels. This patch moves refusal to the engine's actual draw-admission boundary.

## Required transaction

The explicit engine arm is `CYBERSAND_ENGINE_RENDER_LOOKAHEAD=0` or `4`. Only these
arms advertise RenderingServer metadata `cybersand_actual_submission_v2` with
`schema=cybersand-actual-submission-v2` and `engine_owned_admission=true`. Ordinary
applications without the enabled v1 application handshake preserve their draw path.

The live v1 handshake retains strict schema, boolean, signed nonzero owner ID,
40-character source revision, current process frame and actual connected callable
checks. An immutable staged candidate becomes ready only after its queued canvas
work has flushed. Before any draw serial, signal, draw counter or allowance change,
the engine directly calls the live owner's
`_commit_workbench_presentation_submission(true)`.

The application first validates every candidate fence and preconstructs a typed,
read-only receipt. It then commits bookkeeping without external callbacks or any
subsequent refusal branch and returns the receipt. Its exact fields are `accepted`,
`owner_instance`, `submission_serial`, `candidate_serial`, `process_frame`,
`submitted_usec` and `source_revision`. Owner/source/frame must match the captured
handshake, counters must increase for a continuing owner, and the positive timestamp
cannot exceed the current engine clock. Contract faults are separately counted.
The subsequent genuine `frame_pre_draw` signal may notify read-only observers.

A refused candidate suppresses the whole draw: no pre/post signal, draw serial,
frame-drawn counter, completion credit or presentation journal increment. The
original render queue barrier still drains staged commands. The next candidate
supersedes their state. Refused elapsed render time is retained in a scalar and
consumed once at the next admitted draw, separately from the original bounded
look-ahead carry. Manual draws drain the actual queue in both registered arms.

## Preserved invariants and evidence

The original limit remains four deferred producer opportunities per outstanding
actual render-owner draw. The next turn takes the original barrier. Only an actual
returned render draw publishes CPU completion. No callback or timestamp constitutes
GPU completion, compositor delivery, scanout or physical-step credit. Real material,
Rapier, input and Main processing paths are unchanged by the engine patch.

`pubpres-engine-frame-budget-v2` retains the original fields and adds application
source, admission faults, rejected opportunities and exact rejected-time accounting.
Every actual draw row also binds owner, application submission, candidate and
application clock. The bounded trace retains its original fixed row capacity;
refusal retains no new command queue or unbounded candidate/resource collection.

`admission_clock.h` is compiled independently with the unchanged original budget
helper. Its adversarial test checks refusal cannot replenish draw allowance or
invent completion, and that deferred plus rejected time is consumed exactly once.
The live graphical gate must additionally exercise stale candidates, before-flush
manual attempts, duplicate callbacks, owner retirement, normal lifecycle and the
first actual framebuffer read. A journal-only or headless pass is insufficient.

The four-patch source stack and the final combined diff have distinct pinned
identities. Build and payload derivation preserve every frozen compiler, dependency,
public API, PE and runtime-loading gate. A rebuilt engine is required: the previous
qualified bounded binary cannot supply atomic admission.
