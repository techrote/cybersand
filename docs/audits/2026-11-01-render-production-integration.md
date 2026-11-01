---
title: Conditional retained-baseline qualification after accepted R
status: Current
document-kind: audit
scope: Preserved strict E candidate versus accepted production R, incremental benefit, source-matched qualification and owner approval boundary
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md, ../operations/current-and-historical-validation.md]
---

# Conditional retained-baseline qualification after accepted R

## Current source authority and decision boundary

The owner's latest continuation explicitly resumes E qualification after R merged.
Accepted main is `809fd30dfac0c5e127302997075be9c4b279e5aa`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`. Its live branch/merge identity was
reverified before comparison and that exact object was fetched. It has the same
tree as the previously selected R candidate `6fff6cf6b75ecfa224bb4e9c0cd341d2453f79e1`.
The preserved E candidate is `c0875748fc59c896b3461b5836105250a597229a`, tree
`bf35826babe5b5e33a5497df2a50588522f3ac79`, directly above that R candidate.
No later main is silently selected. The subsequent documentation delta does not
change the measured worker, native source, tests, dependencies or runtime bytes.

**CONDITIONAL: retain E as an experimental proposal. The Linux comparison does
not justify enabling E by default.** It establishes a substantial reduction in
retry feedback under deliberately delayed/withheld ACKs, with measurable consumer
cost, but no retry-elimination opportunity in ordinary Auto PLAY or the 250 ms
consumer condition. Three pairs on llvmpipe are not desktop GPU or human pacing
qualification. [PR #345](https://github.com/techrote/cybersand/pull/345) remains
draft. No E merge or production-default change is authorized without explicit
owner approval; AI review is not that approval.

## Original intake and ownership reconciliation

The original intake froze main `25ce0731d89b9540c2d95cfa8bae321c37e6e118`, tree
`26bac27fb535f15e594dc62df8eac183d7b75fea`. Main was fetched once for selection;
later movement does not silently rebase the candidate. The isolated E branch is
`codex/render-retention-production-20261101`. Native R remains owned by existing
[PR #344](https://github.com/techrote/cybersand/pull/344), branch
`codex/render-copy-production-20261101`, source
`6fff6cf6b75ecfa224bb4e9c0cd341d2453f79e1`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`. No duplicate R implementation is added.
The E-only comparison commit `e62dcf5f` is retained on the frozen main. After
the external R merge described below, the production E branch is explicitly
stacked on the already-selected R `6fff6cf6` source. This is not a refetch or a
silent move to a newer main. Only the E delta is proposed above R; the existing
R observation seams are preserved. Thus production E is the intended combined
path. The E-only pre-R checkpoint is preserved historical work and is not an arm
of the subsequent paired production-R comparison.

Historical [#290](https://github.com/techrote/cybersand/pull/290),
[#301](https://github.com/techrote/cybersand/pull/301) and
[#333](https://github.com/techrote/cybersand/pull/333) retain their original
branches and evidence. Their corrected World blob is
`a6afd8cad4264ac2eca0362d14711158e3606760`, also the exact R production World blob.
No historical experiment stack or unrelated material/physical/shader worktree
is merged wholesale. Original worktrees were inspected read-only and preserved.

The task explicitly forbids merging. Another session marked #344 ready under
an earlier R-only acceptance scope during intake. This pass added a no-merge
qualification hold without changing its source. The GitHub connector rejected
conversion back to draft with a permission error. Subsequent read-only API
reconciliation found that `techrote` merged it at 2026-11-01 13:31:41 UTC, merge
commit `809fd30dfac0c5e127302997075be9c4b279e5aa`, whose tree is exactly the
selected R tree above. This execution issued no merge command. The external
merge cannot be represented as an unmerged review candidate or as completion of
the broader hardware/interactive gates. Its original acceptance text is retained
with a dated clarification; no duplicate R PR or automatic revert is created.

## Verified investigation evidence

[PR #335](https://github.com/techrote/cybersand/pull/335) is retained unchanged at
`902fc5b518855911c1b6761a7165573843e567ed`, branch
`codex/render-publication-abc-20261031`; its frozen baseline is
`adaaa37ae35ffcdaa961b80353be3a23b805c0cc`. The evidence document and curated
receipts were read from that exact Git object. Frozen #283 remains historical
evidence at `254235ec4c3d58782bba44b478caca86bf57c856`.

The original Windows paths are not mounted on this Linux executor. The separately
available raw archive was obtained and verified: 13,614,573 bytes, 526 members,
ZIP CRC pass, SHA-256
`cc6d3254bac3c86765ee21e924e2d7fcfec4b3917b2a56ec9ca527d2829e944c`.
This authenticates the supplied archive; it does not claim those Windows paths
or diagnostic binaries are currently available here.

The retained-full-plus-dirty byte-overflow mechanism remains in frozen main.
R's completed hosted paused comparison has normal Control 6/605 retries and R
1/605; withheld ACK gives 595/605 for both. Therefore the earlier R-only judgment
“E NOT NEEDED” is a narrower provisional selection, not proof that R removes
retention feedback. The latest owner instruction requires an incremental-benefit
decision after R; persistence alone does not authorize production admission.
E addresses retry frequency; R addresses legitimate native
full-copy cost. Neither observation establishes hardware frame pacing.

## Branch-current E implementation

The ordinary worker admits exactly one complete current-generation baseline
exemption: its own full-frame byte extent and one six-integer rectangle record.
All subsequent dirty bytes and records count against the unchanged 2,097,152-byte
and 256-record budgets. Exact limits pass; one-over requests existing full
recovery before append. RG8 pending retention is therefore at most 4,194,304
bytes and 257 records. Consumer-held immutable generations and total process
memory are separate from this worker-pending bound.

The baseline remains until a normal valid covering ACK or explicit existing full
recovery replaces the pending publication. No early/synthetic ACK, baseline
drop/rebase, coalescing, serial weakening or new publication policy is introduced.
Current World generation, channels, exact dimensions and contiguous metadata
are mandatory. Invalid/ambiguous state gets no exemption. New-generation dirty
bytes cannot append to an old baseline. Rejected data cannot certify a new
render revision; a required full recovery remains armed until actual validated
full pixels arrive. The legacy `snapshot.cells` keeps exactly the last complete
frame, while immutable patch arrays carry its dirty suffix.

The new retained-baseline regression uses monotonic test-subclass owner counters.
It covers byte/record boundaries, stale/latest/previous-generation ACKs,
reset/replacement, malformed types/metadata/channels, rejected upload/no ACK,
real native reconstruction, published immutability and ordinary tail catch-up.
Existing handoff/Tower synthetic packets are corrected to exercise their real
ownership/serial purpose with honest protocol envelopes. No production trace
counter, clock, observer or per-cell instrumentation is added by E.

Independent review identified a defensive full-recovery hole: retiring an older
ACK could erase the recovery requirement before an incomplete full response.
The correction keeps ACK retirement independent from recovery and requires a
validated complete response before certification. The failure and correction
are retained in the source-bound evidence, rather than inferred from #335's
earlier successful suite. The native adapter currently honors the force request;
this is an adverse-protocol guard, not a claimed observed normal-native failure.

## Source-matched native artifacts

Both baseline manifests bind all 80 baseline native inputs exactly. E changes
GDScript only and follows the explicit reuse rule in the build guide. The E-only
comparison retains baseline libraries; the stacked production E retains R's
published libraries. Its new
script execution requires fresh qualification, not rewritten historical build
ledgers. All 18 required LFS objects were materialized and `git lfs fsck` passed.

| Path scope | Linux SHA-256 | Windows SHA-256 |
|---|---|---|
| Frozen main / E-only comparison | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` | `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb` |
| R / stacked production E+R | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` |

R's canonical [publication run 41301725876](https://github.com/techrote/cybersand/actions/runs/41301725876)
built source `a7ee10f251f647a16dec8a1d7f18c4f299100cba`; publication commit
`c405db68310042089b8bf4aa51c3ea7622312606` appends only two LFS pointers and
two provenance manifests. Actual R libraries are Linux 4,222,424 bytes and
Windows 4,824,064 bytes. All 80 native inputs still match R's tested final head.
The six mismatches in #335 came from its diagnostic native changes; no such
diagnostic source or binary is promoted here. Historical manifests remain intact.

## Native and graphical qualification

Fresh current-R debug and release oracle executions each pass 153,284 assertions,
231 regions, 8,338,180 compared bytes, 42 nonmutation receipts and 18 refusal
checks. The independent scalar getter oracle stays test-only. Fresh Linux
benchmarks use GCC 13.3, `-O3 -DNDEBUG` or `-O0 -g3`, three processes per
implementation/configuration and 41 measured samples per case. All 12 processes,
108 case records and 4,428 measured equality pairs pass. Dense full-frame release
p50/p95/max is Control 31.7566/37.0440/58.8442 ms versus R
1.66373/2.21350/3.39989 ms; debug is 510.464/572.328/707.097 versus
14.6881/17.4570/22.7346 ms. Sparse/absent/dirty-region distributions and every
sample are retained separately. These are shared-executor CPU timings, not GPU
profiling, an exact hash-lookup cost fraction or Windows timing evidence.

The final comparison below supersedes the earlier four-arm plan. It uses only
accepted production R and identical R plus E. Historical pre-R/E-only diagnostic
runs remain preserved and are not used to infer incremental benefit.

## Paired R versus R+E graphical evidence

The [curated per-process results](render-retention-2026-11-01/linux-paired-summary.json)
retain all 36 Linux executions, p50/p95/p99/max distributions, raw artifact hashes,
source/harness identities and failed exposure dispositions. The independent
reduction authenticated 12 reports and 18 pairs with zero custody errors:
15 pairs qualified, while three original 50 ms pairs failed the intended
slow-consumer exposure. All 36 engine processes completed with zero runtime
assertion failures and final native/CPU/texture equality. The six exposure
failures remain failures; an engine exit of zero alone is not qualification.

### Apparatus and execution scope

The exact five-file opt-in harness is
[`215a023290d40160792769ab4da0b28183178374`](https://github.com/techrote/cybersand/commit/215a023290d40160792769ab4da0b28183178374),
tree `6e12633bbdcb8f7f3cd59ef48b180fe7d3f70a87`. It adds only test/qualification
files above accepted R. All three paired repeats use 240 measured frames, the
ordinary project Auto setting (request zero, observed native pool capacity four),
and arm order R→ER, ER→R, R→ER. One graphical process runs at a time; there are no
concurrent local compiler or Godot workloads during the measured batches.

The real Main scene and consumer execute native/Rapier Jet Barrel PLAY, a fixed
sequence of 120 accepted radius-zero Sand/Water edits, midpoint ordinary reset
and World replacement, then the retained late-marker tail drain. Native and
Rapier clocks must advance before and after reset. No controller input is
scripted; this is an active built-in gameplay workload under gravity, not a
human play session. Commands and frame counts match, but elapsed time and native
tick counts can differ between arms; evolving simulation trajectories are not
asserted equal across separate processes.

Normal ACK uses the ordinary successful-upload path. D queues only real upload
ACKs for at least 100,000 microseconds in a bounded 256-entry test ring, retaining
their original serials. W deliberately withholds them. No early/synthetic ACK,
forced tail refresh or consumer repair after owner join is allowed. Final
native bytes are read only after ordinary consumer catch-up and owner join;
that oracle is never uploaded or acknowledged. Rejected-upload/no-ACK behavior
is additionally covered by the focused production consumer regression.

Godot is the pinned `4.7.stable.official.5b4e0cb0f`, executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`,
archive SHA-256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The backend is X11/OpenGL Compatibility through Mesa llvmpipe in Xvfb, with
`LIBGL_ALWAYS_SOFTWARE=1`, `LP_NUM_THREADS=2`, `GALLIVM_PERF=nopt`, a 960×540
window and a shared warmed host profile. Every case uses a fresh process and
authenticates source before/after, actual library bytes, engine, renderer and PID.
These are new executions of the canonical source-matched R library built by
run 41301725876, not a claim of a new native build at c087.

The original 50 ms admission interval never delayed consumption in any of its
six processes. After retaining that failure, one fixed 250 ms supplement was
registered and sealed at
[`f73b3bced3525cf0f99745fc17189ee81ee24c2e`](https://github.com/techrote/cybersand/commit/f73b3bced3525cf0f99745fc17189ee81ee24c2e),
tree `272d072b57cdea9a62b37184f553717fbae8b3f2`. Only cadence admission and the
reader's measured-window exposure check change; worker/consumer observations,
mutation sequence, reset, tail and correctness oracles are unchanged. The six
new processes record 177–185 delayed-consumer events each during measurement.
This is a minimum admission interval, not a promised presentation frequency.

### Mechanism and incremental benefit

Counts below sum the three independent repetitions. Timing populations are
kept per process; counts are not pooled latency samples.

| Cohort | R retries / refreshes | R+E retries / refreshes | Full extractions R / R+E | Exchanged native MiB R / R+E |
|---|---:|---:|---:|---:|
| Paused, normal ACK | 0 / 366 | 0 / 366 | 6 / 6 | 12.001 / 12.001 |
| PLAY, normal ACK | 0 / 1,808 | 0 / 1,659 | 9 / 9 | 21.328 / 21.539 |
| PLAY, ACK delayed at least 100 ms | 1,356 / 1,795 | 10 / 1,679 | 1,365 / 19 | 2,733.808 / 41.473 |
| PLAY, ACK withheld | 1,783 / 1,792 | 9 / 1,655 | 1,792 / 18 | 3,587.681 / 39.341 |
| PLAY, 250 ms consumer, normal ACK | 0 / 1,689 | 0 / 1,808 | 9 / 9 | 21.411 / 21.828 |

The ordinary and 250 ms cohorts have **zero nonempty dirty append attempts onto
an observed complete retained baseline in both arms**. Their timing differences
therefore do not demonstrate a benefit from E's exemption. D/W actually expose
that mechanism. E's remaining stress retries are legitimate dirty-record-budget
recoveries; reducing them to zero by weakening the budget would be incorrect.

The following values are the median of three process-level p95 values, in
milliseconds. The JSON preserves every individual process p50/p95/p99/max and
sample count. No population confidence interval or statistical significance is
claimed from three pairs on one shared executor.

| Active cohort | Worker publication R / R+E | Main CPU patch R / R+E | Texture.update CPU R / R+E | Frame interval R / R+E |
|---|---:|---:|---:|---:|
| Normal ACK | 2.970 / 2.692 | 0.174 / 0.155 | 0.380 / 0.364 | 84.885 / 82.386 |
| Delayed ACK | 5.874 / 3.418 | 1.188 / 1.394 | 0.351 / 0.348 | 82.397 / 81.056 |
| Withheld ACK | 6.044 / 3.066 | 1.162 / 1.376 | 0.366 / 0.328 | 81.470 / 79.676 |
| 250 ms consumer | 2.849 / 3.227 | 0.396 / 0.522 | 0.313 / 0.386 | 79.607 / 87.832 |

D worker p95 improves in all three pairs (5.366–6.196 ms for R versus
3.178–3.424 ms for R+E), but Main patch p95 worsens in all three, by
8.4%, 31.6% and 13.6%. W also transfers more retained-patch work to Main in two
of the three pairs. The slower-consumer measurements have mixed signs and worse
median worker/frame p95 for E, without any avoided retry. First-frame and reset
outliers are retained, including frame maxima over one second on this software
backend; startup host/PLAY installation is separately identified. These data
do not justify an interactive smoothness or GPU-completion claim.

### ACKs, freshness and memory

Ordinary covering ACKs retire all three active baselines per process in both
arms. D's actual queue-to-issue p95 is roughly 151–161 ms because the release is
polled at ordinary Main cadence. With advancing serials, a delayed ACK can be
stale when observed and need not clear the latest publication. Recorded stale
and non-clearing counts are owner observations, not counts of uniquely lost ACKs.
Covering-clear latency has long/mixed tails and is retained separately from
issue-to-first-observation latency. W has no issued ACKs and right-censors its
final retained baseline instead of fabricating a retirement.

E's accepted full baseline can survive about 4.2–5.5 seconds under D/W while
dirty patches keep pixels current. Baseline age alone is not visible-state age.
Successful new-upload handoff upper-bound p95 stays near 31–34 ms in the active
normal/D/W runs. Status-only snapshots do not reset the age of an older render
payload. Submission ages use exact generation/render/snapshot identities and
the worker publication visibility bracket, not a GPU timestamp. The 250 ms
consumer has wider/mixed freshness results, retained in the per-process record.

Measured E pending high-water under ACK pressure is 2,433,768–2,529,804 bytes
with at most 257 rectangles, below the strict 4,194,304-byte/257-record bound.
Full threshold/one-over preflight refusals and immutable publication are covered
by the 195-assertion suite. Pending, published and legacy lengths are separate
logical arrays; they cannot be summed as uniquely allocated heap storage because
of sharing/copy-on-write and retained consumer generations.

Godot tracked-allocator peak in ordinary active runs is 130,815,580 bytes for R
and 131,140,318 bytes for E. Under stress R rises to 134–139 million bytes while
E remains near 131 million. These include the opt-in trace: R produces many more
events when it retries, so the whole difference cannot be attributed to production
allocation savings. Godot's tracked allocation bytes exclude untracked native
allocations. Observed process RSS includes resident native allocations in its
aggregate but cannot attribute them; it is mixed, sampled at 2 Hz, and may
include later trace serialization. Neither measurement supplies allocation
counts or GPU/driver allocation accounting. Sampled RSS does not guarantee the
final process-lifetime peak.

## Windows qualification failure

The separately sealed paired Windows workflow is
[`82f7b982a2fc466960a75fba96873e0a8233070b`](https://github.com/techrote/cybersand/commit/82f7b982a2fc466960a75fba96873e0a8233070b),
tree `244950ee5f4c3f3207f4e1c76fbc5a1d7d56be41`, a one-file child of c087.
Its actual workflow bytes match SHA-256
`cd25a79b2e6f4af1d629097b9dc089301ab3d8c304f770ecaee62e85219f24e0`.
[Run 41317775947](https://github.com/techrote/cybersand/actions/runs/41317775947)
used three ordinary Windows 2022 hosted VMs with counterbalanced arm order.
Native/engine identity and clean imports passed. The reader suite discovered
15 controls: 13 passed and two POSIX-specific controls were skipped on Windows.

All three first paused/N admissions timed out at the unchanged 1,200-second
watchdog; process-tree cleanup completed at about 1,210 seconds without cleanup
errors. Two attempted R first and one attempted E first. No fresh graphical
receipt was produced; the second admissions and all 30 measured processes
remained unstarted. The [failure manifest](render-retention-2026-11-01/windows-admission-failures.json)
records actual process/library/source custody and all three ZIP digests, which
were verified after download. It is not a Windows benchmark result.

The actual backend automatically fell back to ANGLE 2.1.1 (`aaebda1c5a40`),
OpenGL ES 3.0 over Direct3D11, Microsoft Basic Render Driver
`D3D11-10.0.20348.5756`. Inventory reports Microsoft Hyper-V Video and no NVIDIA
device. Source remained unchanged after each failure. Logs show engine/backend
and Rapier initialization but no final receipt or script error; they do not
identify the exact internal stall. A shader-compiler, presentation or E-specific
root cause is therefore not claimed. Explicitly selecting ANGLE would repeat
the backend already observed, not resolve a proven configuration error.

The real Win32 memory observer worked on the owned runtime PIDs; each retained
2,402 samples and roughly 1.13 GB observed peak working set before timeout.
That validates memory collection, not graphical correctness or responsiveness.
The failure blocks Windows graphical comparison in this available environment.
An accessible hardware-backed Windows/NVIDIA desktop is still needed for the
registered paired workloads, actual renderer identification and separately
measured GPU completion/presentation behavior. No dependency pin, shader,
renderer policy, watchdog or CI provider is weakened to obtain a pass.

## Current external acceptance boundaries

This executor has no `/dev/dri` or NVIDIA GPU device and no native Windows
desktop. X11/llvmpipe graphical evidence can establish actual texture-path byte
correctness but cannot satisfy hardware GPU completion/presentation qualification.
GitHub-hosted Windows headless execution is separate from physical desktop
evidence. Required hardware completion latency and interactive presentation must
be measured on an accessible hardware-backed desktop with the final source and
matching runtime identities; CPU `Texture.update` timing/readback alone is not
that evidence. No approval or ready-state claim is inferred from AI review.

## Documentation and validation checklist

Canonical changes cover the bridge behavior, retained ownership, unchanged wire
layout, invariant register and byte/rectangle capacities. The build guide adds
the discovered regression and source-matched reuse boundary. Roadmap/index and
supplementary retrieval questions route to the canonical bridge. Existing corpus
entries already cover those homes; historical audits are not silently inserted
as current behavior. ADR-003, native APIs, Web behavior, user controls, toolchain
pins, licenses and runner/provider policy require no change.

Baseline local Documentation/provenance initially failed on two unavailable
companion records; they were restored from the same pinned companion commit as
CI (`6a58311982941b75f46e22109a0829e5acb83c7e`) outside source. Original failure
outputs are retained. The completed documentation checkpoint passes 117
documents/231 canonical claims, strict repository validation with all 18 runtime
files materialized, and historical M11 integrity for 18 records/28 hashes.
Neither the native ledgers nor historical hashes were rewritten.

Frozen retrieval changes from accepted R's 19/32 hit@1 and 32/32 hit@5 to
20/32 and 32/32. Supplementary retrieval is 121/157 at rank 1 and 156/157 within
rank 5. All 156 pre-existing question objects remain unchanged; the new E
question reaches a canonical capacity contract at rank 2. Its retrieved top-five
contracts cover exact qualification, independent dirty budgets, ordinary ACK
versus outstanding recovery, and the distinction between pending storage and
total process memory. This is lexical retrieval evaluation, not answer proof.
The inherited LCB03 rank-five miss also exists at accepted R; ACT14 moves from
rank 1 to rank 2. These mixed results are retained rather than tuned away by
altering the frozen questions or expected destinations.

At implementation head c087, the 195-assertion E suite and eight scoped
handoff/Tower/generation/native-bridge/tick-failure/PLAY lifecycle cases passed
with the actual source-matched Linux runtime. The reviewed recovery correction
retains its earlier 46-failure adverse execution and the subsequent zero-failure
result. The opt-in graphical reader has 15 passing Linux controls. Independent
Linux evidence review rechecked 864 distributions and 3,158 retry causes with
zero mismatches; it recommends conditional ACK-delay resilience, not the
registered ordinary-Auto GO.

The final documentation-inclusive head and its local/hosted receipts are linked
from [draft #345](https://github.com/techrote/cybersand/pull/345), separately from
the measured c087 source. The exact runtime/test/provenance delta is checked
before treating those measurements as applicable. Required local commands are
`check_docs.py`, `check_m11_consistency.py`, `check_repository.py --require-materialized`,
both retrieval evaluations and `git diff --check`, plus the focused runtime
suite. Hosted manual dispatch preserves the six unchanged canonical workflows:
Native, GDExtension/Godot, Documentation/provenance, Current-Water apparatus-v2,
PLAY desktop identity packet and report-only native scope advice. A successful
dispatcher, an automatic draft skip or an old-head green is not a passed gate.
AI technical review does not authorize ready state, production adoption or merge.
