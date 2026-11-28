# Independent ObjectShard performance review

## Verdict

No new Class A/B runtime finding or substantive statistical reporting error was
identified in this performance-methodology scope. The final native complete
performance gate remains **FAILED: ten limits among 74**. This is a documented
qualification gap, not a successful gate and not proof of a runtime correctness
defect. Both source-bound Linux and Windows actual-Lab performance matrices pass
their registered headless/rendered budgets. Windows 11/NVIDIA physical acceptance
remains unrecorded.

Reviewed runtime: `8f55a4e61b7cbb34a594f5e07e7d81d49aa58945`.
No runtime source, tests, budgets, GitHub record or qualification campaign was
changed. This audit recomputed existing evidence rather than rerunning workloads.

## Independent checks

- Recomputed all **2,560 p50/p95/p99/maximum statistics** from the complete retained
  actual-Godot sample streams: four profiles, eight workloads each, 1,200 frames
  per workload, 38,400 frames total. All declarations match; no omitted or altered
  sample was needed for a pass.
- Independently reapplied **272 Lab limits**: Windows 56 headless + 80 rendered;
  Linux 56 headless + 80 rendered. Zero failures. Each profile also records
  719 functional assertions and zero failures.
- Independently reapplied both native 74-limit matrices. The earlier source has
  zero failures. The repaired source has nine p95 failures and the perforated
  maximum failure, exactly as reported. Both have 4,237,384 functional assertions
  and zero failures. Allocation, memory and geometry-age gates pass.
- Rebound all **92 captured native inputs** to the final runtime commit's Git
  blobs: zero mismatches. The capture's older HEAD is preserved in the ledger;
  exact input binding, rather than a branch label, establishes source identity.
- Verified both retained executable hashes used by the bounded matched control.
  Its four cases are one cohort, not an independent full-matrix qualification.
- Reviewed timing and allocation instrumentation, the registered prequalification
  budgets, and the reproducible complete-tree miniature-World patch.

## Measurement scope

`frame_usec` measures the Lab owner-thread advance, including native work,
material snapshots and Rapier stepping. It excludes separately measured
presentation. Presentation intervals include real scheduling/draw completion;
render upload and presentation counters measure elapsed submission, not GPU-only
work. Native-only frames include actual Coordinator work and synthetic pose/ACK
receipts; they are not actual Rapier measurements. Inclusive occupancy includes
contacts/relocation. Component percentiles cannot be added into a frame estimate.

Construction and editing/setup are separate from steady frames. The native
construction sample count is only three; its displayed tail statistics are
explicitly descriptive. Headless Lab cases create new sessions, while rendered
cases reset a retained native coordinator; these are not matched cold/warm
construction cohorts. Native lifetime maxima persist through rendered resets and
must be interpreted as campaign maxima, not attributed to whichever case appears
last. Per-frame component deltas remain correctly measured.

All four final profiles have maximum geometry age zero. Blocked output retains
bounded material inventory with supported lifecycle; a long product age is not
silently described as successful delivery. The native allocation probe measures
requested C++ allocation bytes and zero steady allocations, not RSS or all
Godot/Rapier/GPU allocation churn.

Memory precision: maximum sampled accounted **live** storage is 4,295,098 bytes;
accounted **retained/peak** storage reaches 4,302,938 bytes. Neither is complete
process residency. The final report's lower-bound wording is correct. Any numeric
headline should preserve this distinction.

## Architecture comparison

The supplementary complete-tree experiment is narrow but fair for its declared
purpose: 550 Wood cells, 30×45 local area, equivalent semantic/random anchors,
actual Fire delivery, and exact local/external tuple equality every tick. It uses
a tuned 8-cell-chunk `SerialInPlace` miniature World, not the default phased World.
The common external World is timed separately, and both candidates have zero
steady allocations. Compact storage uses 60,666 requested bytes versus 91,412;
the miniature World is faster in this sparse fixture (p95 3.322 versus 12.820
microseconds). The reports preserve that result and do not extrapolate the
single-cell memory ratio or claim universal compact-runtime speed superiority.
The experiment remains bound to earlier source `1bb6185...`.

## Remaining qualification gap

The final native full matrix retains empty-Lab p95 3.536 ms, three-reacting p95
5.760 ms and perforated maximum 64.605 ms against unchanged 2/10/50 ms
p95/p99/maximum limits. One later old/new control showed no sampled slowdown in
empty and three-reacting workloads. It is compatible with transient shared-host
influence, but does not establish the exact cause, statistical equivalence or the
other seven cases. CPU pressure controls were unavailable. Do not replace the
failed full-matrix result with the control or the separately passing hosted Lab.

A future controlled qualification or explicit owner assessment of the gap may
inform production integration. Repeating the same broad campaign solely to seek
a green result is not recommended. Draft/HOLD delivery and the final report are
truthful with this gap and the target-PC acceptance status retained.

The machine-readable review is `recomputed-performance-review.json` alongside
this file; it contains raw evidence hashes, complete reconstructed summaries,
all failed native limits, budget hashes and the reviewed document hashes.
