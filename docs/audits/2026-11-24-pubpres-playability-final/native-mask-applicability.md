# Separate native mask-applicability arm

Status: **Draft / HOLD; unselected native experiment.** This arm follows the
unconditional derived-Empty cache at `fa34fc2129125d77a5255c95bfa82af91eff05a5`.
It does not replace, rerun or qualify the original 24-process screen. Its
worker-participation refusal, Wave512 and zero-body adverse results, and drifting
large controls remain in the preceding audit and independently reproduced review.

## Causal question and exact boundary

The original clean/dry optimization already avoids settled Empty material when
no configured transient-body mask crosses a column. The new Empty certificate
addresses the different case where the allocated mask coverage deliberately
keeps those original columns awake. Maintaining that extra certificate on every
unmasked column cannot enable a useful additional skip there, but does add
bookkeeping. The preceding screen made that cost plausible; its host drift does
not establish a clean causal estimate.

`World::wave_column_task` now intersects the same configured mask X/Y bounds
with its actual owned half strip once per task. The true specialization retains
the existing Empty certificate; the false specialization compiles its per-column
maintenance out. There is no canvas-size threshold, body-count threshold,
synthetic tick credit or change to the allocated-mask semantics.

Before the false specialization runs, every owned half explicitly retires any
old certificate. This includes partial selections and groups longer than the
64-entry fast-path arrays. A returning mask must therefore certify the actual
stored cells anew. The existing positive Water-write path still invalidates a
true certificate, but avoids a redundant false store when already invalid.
The true specialization likewise avoids only redundant false stores.

All original dry marks, clean marks, gather values, vertical settling, heads,
depth classes, flux retirement, retained paused faces, prior-flux copying and
scatter semantics are unchanged. The full semantic checksum remains unchanged.
This arm does not contain the separately discussed zero-carry settle shortcut.

## Correctness and independent challenge

The existing 153-checkpoint lifecycle adversaries are unchanged. An additional
24-tick case removes a live mask, writes Water/Oil/Sand/Wall into formerly Empty
storage, selects a partial region, edits paused material, restores a mask, then
narrows and expands its configured region. The full 177-checkpoint sequence
records physical/state/content hashes, Water and ballistic quantities, body
contact count and both contact impulses.

The exact new fixture was independently compiled against the frozen fa34 source
and the applicability source. Both builds enable
`CYBERSAND_WAVE_VERIFY_EMPTY_DERIVED`, which checks actual stored material and
weight/meta before reuse and after certification even under `NDEBUG`. All four
control/candidate processes at one/four workers produced identical complete
checkpoint arrays; same-worker stdout is byte identical. The applicability
diagnostic binaries also passed all 34 Wave tests, 47 spill tests and the
50-run/6,000-tick body-boundary parity suite. These are local GCC 14.2 development
checks; they do not substitute for the pinned hosted toolchain or sanitizer gate.

The initial candidate link failed because the shared volume ran out of space.
Its original command, UTC bounds, nonzero exit and log remain in the correctness
receipt. After storage recovery, a serial build reused six native objects and
successfully linked all four diagnostic executables. No failure is counted as a
pass. Compiler identity, all source hashes, issued commands, original output and
binary hashes are in `native-mask-applicability-correctness.json`.

Independent source review found no mutation, ownership or cache-lifetime blocker.
It required the explicit mask-off invalidation, partial/tall-group fallback and
the new mask-return lifecycle sequence, all present here. Independent artifact
and timing review is retained separately when available.

## Prospective bounded comparison

The separate source-exact screen uses the unchanged benchmark SHA-256
`0ee16b0592fd2be58543020c258dab23801e4b89318469bf0e94b1b393a6a2f8`:

| Arm | Native source | Purpose |
| --- | --- | --- |
| A | `27a08efb4a78186c0e2b19176576752e2503b998` | Original occupied-bounds control |
| B | `fa34fc2129125d77a5255c95bfa82af91eff05a5` | Unconditional Empty certificate |
| C | This separately frozen applicability commit | Same cache with task-level applicability |

Each of current Wave512/one body, Wave2048/zero bodies and Wave2048/one body runs
**A/B/C/C/B/A**, with 72 ticks and four requested/observed material workers per
process. The existing independently built A and B executables are retained;
C is independently built with identical compiler, flags and benchmark bytes.
All 18 original process results remain visible, including adverse tails or a
registered refusal. No failed cohort is silently replaced.

The added CPU witness is Linux `RUSAGE_CHILDREN`, sampled immediately before
launch and after reaping the one owned native process. Worker threads are
included. No child is launched between measured intervals, so consecutive
end/start counters must agree. CPU covers the complete process, including setup
and semantic checks outside the native tick clocks. It is neither a per-tick CPU
estimate nor a Godot clock join. Actual PID, exact executable path/hash and
whole-process wall duration are retained; that wall duration must contain the
sum of native tick durations.

The unchanged native reader independently reconstructs each tick and phase
statistic from the raw arrays. The new reader compares every full checkpoint,
Water and parcel sequence, requires all four observed workers, verifies the
fixed benchmark and three source roles, and refuses any retained process
failure. Three reader tests include adversarial CPU/source/process custody
mutations and the preserved observed-three-workers refusal.

Two processes per arm/cohort cannot establish sustained ordinary Workbench
playability. No Rapier, input, pose freshness or presented-frame improvement is
claimed from this screen. Host stationarity remains unproven even during an
explicitly quiet local interval.

## Original 18-process result

The exact applicability source is
`3e027cdb71ec97a6719fbd3580f552d500349075`, tree
`e7d4b47900ed6f178c7cf0e9e4ed083bd2542cb2`. Its independently compiled O3
executable SHA-256 is
`a39aa0a831f97f0eda3291079a292c13851f8014f52d38fbbccc36a34bf4cf5b`.
The serial screen ran from 2026-11-24 18:12:52 to 18:15:12 UTC. Root and both
peer lanes suspended executable validation during that interval.

Every process exited zero with empty stderr. All 18 processes observed four
workers, and each cohort's complete semantic checkpoints, Water and launched
parcel quantities match exactly across all six executions. Raw tick and phase
statistics independently reconstruct. The registered reducer therefore passes
its validity checks; this is not a broad performance or playability pass.

Native values below are **mean / p95 / maximum milliseconds**. CPU is the total
kernel user-plus-system seconds for the complete benchmark child. Wall is the
complete process wall time, including setup and semantic checks.

| Cohort | Arm/order | Native mean / p95 / max ms | Whole child CPU s | Whole process wall s |
| --- | --- | --- | --- | --- |
| 512, one body | A1 | 19.980 / 41.124 / 51.141 | 1.779 | 1.761 |
| 512, one body | B1 | 20.898 / 46.637 / 109.905 | 1.720 | 1.771 |
| 512, one body | C1 | 17.827 / 35.920 / 50.572 | 1.634 | 1.538 |
| 512, one body | C2 | 17.924 / 32.830 / 40.587 | 1.634 | 1.555 |
| 512, one body | B2 | 18.366 / 39.481 / 51.860 | 1.679 | 1.661 |
| 512, one body | A2 | 22.050 / 35.113 / 57.368 | 1.779 | 1.864 |
| 2048, zero bodies | A1 | 179.272 / 299.880 / 3306.393 | 21.341 | 16.275 |
| 2048, zero bodies | B1 | 86.417 / 125.972 / 188.524 | 16.743 | 8.735 |
| 2048, zero bodies | C1 | 81.240 / 113.155 / 123.884 | 16.040 | 8.332 |
| 2048, zero bodies | C2 | 79.312 / 116.414 / 232.690 | 15.859 | 7.978 |
| 2048, zero bodies | B2 | 102.385 / 182.840 / 203.537 | 20.213 | 10.405 |
| 2048, zero bodies | A2 | 79.463 / 109.741 / 191.240 | 16.715 | 8.060 |
| 2048, one body | A1 | 154.245 / 210.445 / 264.360 | 28.676 | 13.576 |
| 2048, one body | B1 | 108.329 / 154.672 / 194.237 | 20.279 | 10.231 |
| 2048, one body | C1 | 109.449 / 139.586 / 155.241 | 19.706 | 10.357 |
| 2048, one body | C2 | 115.931 / 160.463 / 178.417 | 20.049 | 11.268 |
| 2048, one body | B2 | 123.570 / 191.265 / 247.842 | 21.337 | 11.805 |
| 2048, one body | A2 | 141.119 / 183.640 / 251.370 | 28.487 | 12.636 |

| Comparison | Wave512 one body | Wave2048 zero bodies | Wave2048 one body |
| --- | --- | --- | --- |
| C vs A paired mean change | −14.94% | −37.95% | −23.69% |
| C vs A whole-child CPU change | −8.14% | −16.18% | −30.45% |
| C vs B paired mean change | −8.95% | −14.96% | −2.81% |
| C vs B whole-child CPU change | −3.84% | −13.68% | −4.47% |

Only Wave2048/one body C versus A has both candidate processes below both
controls for all five native timing statistics. The 512 and zero-body tails
remain mixed. The zero-body A1 contains a retained **3.306-second tick** and
differs substantially from A2 in both wall and CPU totals; this prevents treating
the apparent 37.95% mean difference as a stable source effect. The preceding
24-run negative screen remains part of the decision and is not superseded.

Accumulated CPU divided by whole-process wall time ranges from approximately
0.96–1.06 cores at 512, 1.31–2.07 for zero-body 2048, and 1.78–2.26 for one-body
2048. This is a scope-correct utilization observation, not a direct scheduler or
descheduling diagnosis. Subtracting total multithread CPU from elapsed wall time
would be invalid. No host-stationarity claim is made.

The remaining native column phase in C's one-body 2048 processes averages
63.94/67.26 ms out of total ticks of 109.45/115.93 ms. That is still the largest
measured native phase. The independently reviewed zero-carry column-segment law
is therefore the next separate candidate; its downstream heads, refill and flux
work must remain exact. All original process output, source/binary identities,
CPU brackets and reader output are retained in
`native-mask-applicability-receipts.json` and
`native-mask-applicability-screen.json`.
