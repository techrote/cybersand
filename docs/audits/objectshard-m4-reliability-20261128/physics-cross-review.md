# Physical review of throughput integration

Reviewer: physics specialist A, 28 November 2026. Reviewed throughput source
`f25b1aaa2`, COM consumer `a3b596e0a`, and fixture revisions `4fc372422` and
`b0b3d777c`. This is a focused ownership, material and physical-time review;
the integrated release campaign remains an independent gate.

## Disposition

No unresolved physical-correctness blocker was found in these changes. The
bounded optimisation removes repeated presentation construction and delayed
receipt observation while retaining every applied-pose acknowledgement,
independent native pose proof, geometry barrier and final semantic completion.

## Reviewed contracts

| Contract | Review finding |
|---|---|
| Main callback admission | `main.gd::_physics_process` polls already admitted work before its readiness gate. New actor forces/controller work remain after exact `acquire_interval` and run once for one newly admitted physical interval. |
| Native pose authority | `CyberObjectShardLab::advance_native` obtains actual `m4_owner_readback` BodyView poses after successful native application. Compact coordinates are not copied from the caller. Availability, quarantine, pause, truncation and exact active-body count gate completeness. |
| Compact consumption | `_poll_once` accepts compact frames only for a non-final pending motion command with the named complete proof contract. `_valid_motion_receipt` still checks every accepted identity/serial and semantic tick; `_native_pose_echo_matches` separately checks every actual pose, velocity, body/geometry generation and sleeping value. |
| Ordered leased service | `_m4_service_leased_segments` processes only the ordered `accept_motion` prefix under an existing lease. Full completion and other commands return to the ordinary owner turn. The fast path neither ticks material nor consumes actor/equipment work. |
| Final actor/equipment packet | `complete_motion` retains the exact captured Main packet and request/effect cutoff, performs the original native coupling preparation, and releases one semantic tick only after the physical interval's native ACKs. Later requests cannot attach themselves to the earlier interval. |
| Failure and final publication | Failed, unapplied, legacy, incomplete and final-segment receipts retain full native frames. Main refusal still holds an unprovable state; no corrective teleport, ACK skip or repeated step was introduced. |
| COM-domain lifetime | `accept_motion` contact work does not add owned Cargo/Product. Sand's intermediate pass only records fences. Actual lodging, chemistry and products occur during semantic completion before geometry/domain synchronisation and the next lease. Thus intermediate compact frames cannot conceal a changed motion bound. |
| Resources and scheduling | Main rendezvous retains its elapsed budget. Permit retry handles only `OwnerBusy` and revalidates exact state each time before any new force application. Queue capacities and body budgets remain bounded; the native echo is bounded by the existing owner readback capacity. |

## Fixture changes preserve their adversarial premises

The updated fragment/lifecycle fixtures stop waiting to observe a fleeting
`Ready` phase while Play immediately admits the next interval. They instead
observe actual attachment or body reservation and then call the existing Pause
barrier. That barrier still requires `physics_ready`, coherent native/physical
and displayed publication, no pending moving-cell mutation, no legacy brush
work and no newer unconsumed owner frame. `_stable` retains those same checks.
The old final geometry/coherence assertion has therefore not been removed.

Receipt-delay tests now disable both Main idle and physical callbacks. Disabling
only idle callbacks no longer withholds receipt delivery because the new
physical callback legitimately consumes it. The native owner and child pointer
input still run, preserving the actual asynchronous mutation/publication
challenge and its existing input fence assertions.

The equipment-delay fixture now proves the final immutable packet was actually
admitted with the expected request ID and remains pending while the worker's
leased idle counter advances. Requiring repeated ordinary publications would
test the redundant work deliberately eliminated by this change. Physical,
native and actor clocks, captured request cutoff, cancellation and eventual
material effects retain their original independent assertions.

The throughput specialist reports 151 checks for delayed receipts, copied
foreign/corrupt proof controls, paused Step, Pause with a queued brush, actual
native refusal, Restore and shutdown. The presentation specialist independently
closed the earlier Held-midlease concern with 208 checks on a real pending
motion receipt, retained full-canvas camera pan/resize and Restore retirement.
Those specialists retain their own executable fixtures and detailed evidence;
their counts are not presented as a separate rerun by this reviewer.

## Physics acceptance summary

The final physics correction demonstrates natural high-spin fragments and
ordinary 26-to-1 endpoint erosion without motion-envelope halt. Tight and
padded/off-origin storage produce the same occupied world trajectory to within
0.0000612 cells. Every actual segment receives its native ACK and exact pose
echo; inventory and the single semantic clock survive the collisions.

Mass, inertia, COM and geometry identity remain native authorities. Geometry
replacement retains the physical owner and its established momentum handling.
Excessive COM translation, corner travel, large-body angular displacement,
unresolvable turns, nonfinite state, unsupported ownership combinations and
exhausted bounded work still refuse safely. The correction does not promise
unbounded impulses or arbitrary fragment counts.

The original owner barrel jump remains unreproduced. Settled, repeated distant
collider replacement, fresh-load no-cut, initially paused cut and early cut
controls found no unrelated upward impulse. An ordinary Structures-disabled
reference falls to the same floor contact. The evaluator must retain this
physical owner check and diagnostic export if it recurs. Remaining support can
validly hold a facade after a partial cut.

## Later scaling experiments

Preserve the stable carrier identity, installed geometry acknowledgement,
independent native pose proof and single semantic clock seams. Current empty
storage still consumes scan and memory budgets even though it no longer
distorts physical admission. Measure occupied-mask/domain caching, batched
per-body motion proofs and sleeping-region work before raising body budgets.
Any later storage compaction or lightweight debris representation must preserve
the tested storage-invariant trajectory and curved Sand/Water contact semantics.
These are subsequent experiments, not missing parts of this bounded repair.
