---
title: Render publication investigation on frozen main
status: Current
document-kind: audit
scope: Instrumented desktop reproduction and opt-in E and R experiments; draft investigation, no production selection
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../reference/status-and-roadmap.md, ../operations/local-build-and-validation.md]
---

# Render publication investigation on frozen main

## Source and concurrent ownership

The starting source is `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, tree
`ad800ebd5c876f6d1ecd080a6dc3f02918b21870`, fetched from `origin/main` on
2026-10-31. Branch `codex/render-publication-abc-20261031` uses the separate
worktree `C:/Users/_/.codex/worktrees/render-publication-abc/khybersand`.
The dirty `C:/khybersand` material branch was preserved. No subsequent main or
other investigation commits are consumed. Resolve A/B/C checkpoints from this
branch's commit history; no merge is authorized.

The open-PR audit found production render-copy ownership in #290 (head
`ddf812f34c533f654f1488b9115eb0256305a288`) and publisher/host successors
#295/#298/#301, plus integration prepass #333 (head `21d44e43`). PLAY shader
#310/#326/#331 and recovery #308/#332 also affect the wider host. Their metadata
was inspected; their commits and implementations were not imported. R here is
an independent test-only differential experiment. Cross-branch integration
belongs to a subsequent pass.

The onboarding/identity guides retain the historical `C:/kybersand/source`
layout. That differs from this host's inspected Git root; the actual paths above
govern this run. Historical identities and the separate companion records were
not rewritten to make them describe this checkout.

All 18 required LFS objects were materialized. Each graphical campaign verifies
all 80 canonical native source inputs against the inherited runtime manifest,
the actual runtime hash, and before/after script identities. Generated imports,
UIDs, builds, logs, archives and local runtime replacements are excluded from
commits. The separate historical companion inputs were materialized outside
source from workspace checkpoint `a15e06ca6f37750b66b89936424e0d018b203f7b`.

## Historical evidence, not current performance

Frozen #283 remains untouched at `254235ec4c3d58782bba44b478caca86bf57c856`.
Read-only archaeology verified these frozen receipts under
`docs/audits/sol281-2026-10-28/` in that commit:

| Receipt | Git blob | Qualified historical scope |
|---|---|---|
| render-ack-control-receipt.json | `08c10cce7008c75c3df5cfb227c90794a97b24bf` | Full 2,097,152-byte RG8 baseline plus dirty caused byte-only retries; CPU ACK Linux93/93, Windows101/124; 23 Windows clears |
| render-coalescing-candidate-receipt.json | `6ce5c72279b6333fb7989c6d8c9af603229a5419` | Original latest-only qualification failed and remains failed |
| render-coalescing-gate-correction-receipt.json | `f83e16ed788b3c0080e5479183c7777ae6a0ff39` | Monotonic owner counters corrected causal counting |
| render-root-cause-comparison-receipt.json | `5286fe02660e7c16e0887d50fcc005fae266ee5c` | R extraction win; whole-run retry gate failed with intentionally unacknowledged startup |
| render-followup-comparison-receipt.json | `77349143dbcfa77574ac95c320baa0624497655a` | E qualified headless CPU-ACK median p95 .037ms Linux/.048ms Windows, no baseline drops |

Frozen E's predicate was less strict than this task's complete-frame/generation/
channel contract. Frozen R also formed an overflowing exclusive endpoint at
INT64_MAX. Neither implementation is imported. None of these historical timings
qualifies current graphical upload, GPU completion or frame pacing.

## Stage A apparatus and interpretation

The real `main.tscn` retains ordinary `_process`, validation, patch application,
two ImageTextures, shader/presentation setup, texture update and upload-dependent
ACK. Only test subclasses record events or withhold ACK. The workload is paused
to exclude physical/simulation-policy changes: 120 radius-zero alternating
Sand/Water emissions over 240 process frames, with ordinary accepted reset at
frame120. Fresh processes run N (normal ACK) and W (withheld after successful
upload); ordering alternates by repeat. Emissions can be batched by owner pacing,
so counts and trajectories must be interpreted through event identities rather
than assumed equal refresh denominators.

Windows uses pinned Godot4.7 `5b4e0cb0f`, native OpenGL/NVIDIA TITAN RTX. Linux
uses the same pinned version under WSLg/X11 with Mesa llvmpipe; this is a real
graphical software renderer, not a discrete Linux GPU. The retained Linux engine
archive matches lock SHA256 `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The direct official download returned HTTP403; the already cached exact pinned
archive was verified instead. Audio is explicitly Dummy in qualified campaigns.

The first campaigns (`A-Windows`, `A-Linux`) retain useful mechanism evidence but
have qualified timeline precision: ACK clear reread shared ACK, native duration
included post-call diagnostic getters, and retrieval was timestamped too late.
Independent AI review identified these issues. A2 preserves the exact latched
ACK, timestamps native return before getters and logs retrieval separately from
later consumption. Its reader checks owner event/counter agreement, every retry
cause, paired operation identities, post-upload ACK, W suppression and full
replacement at both generations. AI review is not independent human approval.

Raw receipts, original logs and PNG frame witnesses are retained under
`C:/Users/_/.codex/tmp/render-publication-abc/`; curated JSON receipts below bind
their hashes and exact source/local delta. Original A Linux logs include audio
fallback errors; those runs are not promoted to clean qualification.

Commands (1200s per graphical process, plus bounded terminate/kill cleanup):

```text
python tools/experiments/render_publication_campaign.py --engine C:/Godot47/Godot_v4.7-stable_win64_console.exe --output <fresh-directory>
wsl --cd <worktree-linux-path> python3 tools/experiments/render_publication_campaign.py --engine /home/i/cybersand-play-auto004-tools/Godot_v4.7-stable_linux.x86_64 --output <fresh-directory>
```

Normal-consumer retry incidence is an instrumented-fixture observation; the
trace mutex and shared host load perturb scheduling. The old full+dirty overflow
mechanism is reproduced; Stage B is therefore admitted as an opt-in experiment.
The precise qualified A2 values and example timelines are retained in the
machine receipt. Neither a paused narrow fixture nor `frame_post_draw` is human
PLAY acceptance or GPU-fence timing.

Corrected [Stage-A receipt](render-publication-2026-10-31/stage-a.json), three
fresh processes per arm/platform:

| Platform | N retries/refreshes | W retries/refreshes |
|---|---:|---:|
| Windows native OpenGL/NVIDIA | 10/363 (2.75%) | 357/363 (98.35%) |
| Linux WSLg/X11 llvmpipe | 83/253 (32.81%) | 162/168 (96.43%) |

Every characterised retry is a Published dirty first packet behind a retained
full frame, followed by byte-only overflow and a forced full second call.
Rectangle overflow and native backpressure are absent in these retry causes.
The two complete baseline publications per run are startup and accepted reset.
N clears often prevent the loop; W retains the baseline deliberately. The
Linux/Windows rate difference cannot be assigned to OS alone: renderer and
scheduling differ. A2 Windows and Linux campaigns partly overlapped on the same
machine; subsequent same-platform comparisons must be read with that caveat.

## Documentation change matrix

The bridge contract owns diagnostic/current-policy qualifiers; this audit owns
dated results/failures. Documentation index, roadmap, validation ledger and
retrieval routes point there. Ownership/lifetimes, interfaces, invariants,
configuration budgets and ADR003 were inspected: no mutable World access,
wire-layout, default budget, user control or production policy changes are
selected. Local build instructions retain pinned tools; experimental standalone
commands are recorded with each stage here. The frozen retrieval evaluation is
preserved; supplemental investigation questions are separate.

## Validation and remaining gates

At intake, documentation/repository checks failed on the five absent companion
paths (six question references), while historical M11 passed18 records/28 hashes.
Restoring the historical companion files outside source made documentation pass.
Baseline lexical evaluation: hit@1 19/32, hit@5 32/32, MRR .7536; semantic answer
sufficiency still needs source review. The bounded trace control passed5 checks.
Stage-specific and final-head evidence are recorded separately as work proceeds.

Stage A checkpoint: `6b19d33a778f604f38150d14a6a3484dbf520a32`, tree
`fbc4457af28e99559018940971a3228cb7ea80f0`. The continuing investigation is
[draft PR335](https://github.com/techrote/cybersand/pull/335), left unmerged.

## Stage B strict E experiment

**Current test-only candidate:** E is selected only with `--candidate=E` by the
diagnostic harness. Ordinary worker construction and limits are unchanged.
An exact full-world frame qualifies only with matching owner/render generation,
channels1/2, exactly one complete tightly packed full rectangle and exact byte
extent. A tag preserves its original baseline serial. Dirty data is independently
validated, contiguous and charged against the original 2,097,152-byte/256-record
budget after subtracting exactly that baseline and its single metadata record.
Malformed/failed/unknown envelopes and generation/channel mismatches receive no
exemption. All known native full-copy statuses remain valid: a complete forced
copy can accompany NoChanges, Backpressure or CapacityExceeded, including native
serial0; worker serials remain positive and monotonic.

To enforce the requested **transient** pending bound, a dirty preflight retains
the existing data unchanged when an append would exceed its budget, and latches
the ordinary second forced-full recovery. Only a valid replacement full packet
replaces the retained buffer; no baseline drop, rebase or coalescing is used.
Ordinary valid ACK remains the only non-recovery clear. The legacy `cells` cache
keeps its last complete frame, as in ordinary dirty transport; rendering applies
`render_patch_*`. Native hard-surface snapshots remain the collider source.

Parent executed the exact native E oracle on Windows and Linux: **62 assertions,
zero failures each**. It covers exact/one-over bytes and rectangles, retained
baseline/immutable publication, stale/latest/previous-generation ACKs, accepted
reset, malformed metadata/payload/envelopes, channel denial, actual production
rejected-upload/no-ACK/full-request behavior, real native reconstruction parity,
existing full recovery and pending bound. Earlier scratch54/0 and initial
mutable-pending oracle failure remain retained. Independent review added failed
envelope negatives; the first B-E-Windows graphical run predates that correction
and is supplementary, not the final candidate qualification.

The [Stage-B receipt](render-publication-2026-10-31/stage-b.json) binds **24 fresh
graphical processes** (three N and three W per candidate/platform). B3 campaigns
ran sequentially on the same machine, keeping the same narrow workload and exact
source. All final CPU Images match a fresh native full snapshot after worker
join; all final texture readbacks match those CPU bytes. No rejection, trace
truncation, failed owner or generation/reset failure occurred. Source manifests
and all80 inherited native inputs match before and after each campaign.

| Platform / arm | Control retries/refreshes | E retries/refreshes | Control full publications/refreshes | E full publications/refreshes |
|---|---:|---:|---:|---:|
| Windows N | 7/363 | 0/363 | 13/363 | 6/363 |
| Windows W | 357/363 | 0/363 | 363/363 | 6/363 |
| Linux N | 79/242 | 0/341 | 85/242 | 6/341 |
| Linux W | 166/172 | 0/325 | 172/172 | 6/325 |

The differing Linux denominators reflect owner service/packet batching under a
fixed process-frame emission schedule; they are not matched tick trajectories.
All E W runs retain actual dirty-on-full events. Maximum E pending retention is
2,097,272 bytes, below the 4,194,304-byte RG8 bound; exact budget tests exercise
the bound itself. Control's transient overflow is retained in its high-water.

Median of three per-process p95 values (milliseconds; these are not pooled p95s):

| Platform / arm / mode | Combined native call | Worker publication | Main CPU patch excluding validation | Texture.update CPU call | Frame interval |
|---|---:|---:|---:|---:|---:|
| Windows N control / E | .018 / .019 | .437 / .444 | .026 / .026 | .308 / .335 | 16.777 / 16.794 |
| Windows W control / E | 16.861 / .019 | 19.934 / .993 | 1.535 / 1.615 | .396 / .378 | 16.765 / 16.795 |
| Linux N control / E | 57.139 / .063 | 62.415 / .825 | 1.082 / .027 | .730 / .802 | 16.195 / 16.249 |
| Linux W control / E | 69.862 / .049 | 77.511 / 1.689 | 1.221 / 1.356 | .651 / .681 | 17.436 / 17.612 |

E removes the measured feedback loop without transferring equivalent CPU cost to
the consumer in this fixture. W still replays its retained full image plus an
increasing dirty suffix: the modest patch-cost increase is retained, and whole
backing texture uploads continue. Initial/reset full copies remain in tail
latencies. Windows N's low baseline incidence leaves little p95 change. Frame
intervals show no demonstrated improvement; GPU execution/fence timing and
representative active PLAY remain unmeasured. Do not infer universal prevalence,
production acceptance or an FPS gain.

The reader now checks both directions of event/counter agreement, native call
pairs/durations, exact operation identities, generation replacement, candidate
selection, final parity and E capacity. Actual retained traces pass17 adverse
control mutations for control-N and16 for E-W, including ACK-before-upload,
missing overflow cause, malformed call/publication, parity failure and capacity.
All raw original logs, intermediate B/B2 attempts and hashes remain outside Git.

Stage B checkpoint: `8b8fc3dac4a3fb8d1375ae402bd1fa0d3c1b25a8`, tree
`75826aaecde04d37d1a091e5c2241e3670a879b1`.

## Stage C independent native extraction

**Current test-build APIs only:** `CYBERSAND_RENDER_COPY_EXPERIMENT` compiles
`World::copy_render_cells_by_run` and a separate counted original counterpart.
Ordinary `copy_render_cells` and every native adapter/exchange call remain on the
original path. R resolves one address/chunk per contiguous row run, reads stored
tuples directly and uses the same `project_visual_state` and actual Water policy.
Absent runs fill exact Empty/zero projection bytes. Width-counted traversal
supports valid inclusive INT64 endpoints without exclusive-end overflow. This
does not extend the API to coordinate ranges whose addressed cells overflow.

The [Stage-C receipt](render-publication-2026-10-31/stage-c.json) binds current
HEAD8b8 plus the exact native local delta, compiler versions, command argv,
executables and all logs. Parent decisively executed the strengthened oracle in
five builds: Windows LLVM23.1.4 debug/release, Linux GCC13.3 debug/release, and
Linux ASan+UBSan. **All pass10,225,432 assertions across265 regions.** Neither
implementation changes revision, material/state/quantity hashes, exact dirty
bounds, activity, chunk allocation or subsequent deterministic simulation twins.
Tuple setters are verified rather than silently accepting setup refusal.

Coverage includes complete1024² RG8 frames, small/large/padded/crossing regions,
sparse/dense/absent storage, negative offsets, valid INT64 endpoints, zero-sized
axes, invalid layout/buffer refusals, all practical material IDs with byte-state
edges and each byte-lane value, every Water mass for bits3..8 and coherence0..12,
and three seeded random-state Worlds plus random regions. The non-Water256² state
Cartesian product is not exhaustively enumerated. R is byte-identical throughout.

Benchmarks use repository-supported `-O0 -g3` and `-O3 -DNDEBUG -flto` modes;
Windows LLVM additionally needs `-fuse-ld=lld`. Each case has three warmups and31
paired samples with alternating order, outside worker/ACK/upload machinery.
Complete arrays and p50/p95/max for full frames and representative dirty regions
are in the receipt. These are paired warm distributions, not cold-start or31
fresh-process measurements. All four benchmark processes pass byte/nonmutation
checks. Parent ran them sequentially, without overlapping builds on this branch.

Full-frame p50 (milliseconds):

| Host / mode | Sparse original → R | Dense original → R | Dense speedup |
|---|---:|---:|---:|
| Windows debug | 144.720 → 2.219 | 183.181 → 12.174 | 15.05× |
| Windows release | 8.582 → .202 | 14.088 → 1.049 | 13.43× |
| Linux debug | 230.594 → 2.449 | 378.250 → 12.765 | 29.63× |
| Linux release | 16.057 → .206 | 23.300 → .976 | 23.88× |

Source-level logical address calculations/chunk lookups fall from3,145,728 to
8,192 per full frame (128-cell chunks), a384× reduction. Resident material/state
reads and visual projections are recorded separately; absent-run fill skips
projections. These are logical counts from a separate diagnostic implementation,
not hardware counters; an optimizing compiler may combine ordinary operations.
Speedup includes locality, direct reads and absent fill, so it does not quantify
the fraction of wall time solely spent in hash lookup.

R is independently useful for initial/reset/full-recovery extraction even when
E removes feedback retries. Its implementation is small and differential evidence
supports later production review, but existing #290 owns that integration. No
ordinary render call is changed here. R does not fix ACK retention/overflow.

Preserved C failures: the early worker's first oracle reached8,395,040 checks and
160 matching regions before its16-cell-chunk simulation fixture exhausted touched
capacity with a64-cell scheduling core; matching fixture geometry corrected it.
The early Windows LTO build required explicit LLD selection. Prior8,462,697/162
passes belong to the earlier oracle, not the strengthened current one. The
positive smoke JSONL/binaries remain in the ignored build directory. The two
early failures were tool-output-only: no original stdout/stderr files, complete
failing-source manifest or failing executable hash were captured, and the test
binary was overwritten. Exact commands/errors were later transcribed into
`stage-c-preflight-failures-transcribed.json` under the raw root (SHA256
`98a7d9c11985e87c7baef1d00ba9274b45cc1a90800b70c6b203e686ac990028`).
That receipt states its custody limits; it is not an original process log or a
fully source-bound failed-run qualification. Current qualified campaigns have
their separate complete receipts.

Example standalone commands (1200s per compile/test/benchmark process):

```text
python tools/experiments/render_copy_isolation_campaign.py --compiler "C:/Program Files/LLVM/bin/clang++.exe" --mode release --output <fresh-directory>
wsl --cd <worktree-linux-path> python3 tools/experiments/render_copy_isolation_campaign.py --compiler /usr/bin/g++ --mode debug --output <fresh-directory>
```

Final exact-head qualification and handover remain pending at the Stage-C checkpoint.

Stage C checkpoint: `0babe8702f1ca7d92e83f8a9236c33ca020f9010`, tree
`e102dcf6cfd6154f508b68aaa6e9b1187fa267a4`.

## Final source-matched native attribution apparatus

The final diagnostic build adds `CYBERSAND_RENDER_PUBLICATION_DIAGNOSTIC` around
adapter-only clocks for exchange publication, full buffer preparation, original
full extraction, dirty packing and total adapter time. Godot's monotonic clock
shares the worker/main timeline. Native pool workers do not call it. Default
compilation excludes the code and extra dictionary; R is not enabled by this
flag. An explicit local runtime manifest authenticates all80 source inputs and
the actual installed test binary; published provenance/LFS pointers stay intact.

This closes a measurement gap in A/B's combined native-call timing. Residual
adapter time still includes dictionary/array metadata and diagnostic overhead;
it is not a pure isolated marshalling measurement. New local pinned builds and
their final graphical/focused evidence are recorded below after execution.

## Final qualification and preserved tail failure

Exact final runtime/fixture code checkpoint:
`cc3b5e82bbebea71a10ff5495434c90ff5a95c33`, tree
`1a0962252aeb495e1b558c84bc01a1009bf3781b`. Local native binaries were built
from committed `64e2f4e71bf4c0b6145bd573dbb5d81bdd9309a6`; all80 native inputs
are byte-identical at the final fixture checkpoint and are authenticated again
before/after each campaign. Windows DLL SHA256 starts `4f538ea0`; Linux SO starts
`805151d4`. Full identities, commands and hashes are in the
[final qualification receipt](render-publication-2026-10-31/final-qualification.json)
and [final graphical receipt](render-publication-2026-10-31/final-graphical.json).
Only the render-publication diagnostic flag is enabled; R remains unselected.

The first final Linux E/W2 process is deliberately retained as a **failed run**:
JSON SHA256 `d1b755f48e1768d757781985a134013036e2a698b8597940992b4022758dfd2e`.
Its final CPU image matched its GPU texture but not the stopped native World.
The trace showed render revision120 while native revision121 had been changed
only14.314ms after the previous extraction, inside the ordinary16.667ms cadence.
Joining the worker does not force publication. This was premature comparison of
different revisions, not demonstrated E byte loss. No failed artifact was edited
or promoted to a passing run.

The corrected harness stops emitting after its240-frame window, then lets normal
Main consumption/worker cadence continue. It safely reads monotonic owner-end
counts, requires two additional completions and generation2 with equal immutable
render/simulation revisions, then disables processing and joins without another
await. It requests no full refresh and issues no artificial ACK. Strict native/
CPU/texture parity remains required after join. A deterministic cadence oracle
reproduces deferred publication and ordinary catch-up; the final E suite has
**72 assertions, zero failures on each OS**. The tail has its own event boundary
and elapsed time. Refresh ratios and native/worker/upload percentiles include
startup, reset and ordinary drain; the240 frame intervals exclude the drain.
Tail event counts can straddle an adapter call and are not a separate matched
call population.

Final2 reran the complete24-process graphical matrix on that corrected source:

| Platform | Control N retries/refreshes | Control W | E N | E W |
|---|---:|---:|---:|---:|
| Windows native OpenGL/NVIDIA | 4/363 (1.10%) | 357/363 (98.35%) | 0/363 | 0/363 |
| Linux WSLg/X11 llvmpipe | 79/224 (35.27%) | 163/169 (96.45%) | 0/269 | 0/273 |

All24 complete normally with no rejected snapshot, truncated trace, failed owner,
generation error or parity mismatch. Each E process has exactly two full
publications (startup/reset); its largest pending payload is2,097,272 bytes.
Every control retry remains Published-dirty → retained-full → **byte-only**
overflow → second forced full. Independent AI readback recomputed every summary
and checked all raw/log/PNG hashes. This is not independent human approval.

Median of per-process p95, final instrumented runs (milliseconds):

| Platform / arm, control → E | Combined native call | Worker publication | Main CPU patch | Texture.update CPU call |240-frame interval |
|---|---:|---:|---:|---:|---:|
| Windows N | .019 → .017 | .367 → .364 | .020 → .020 | .243 → .242 | 16.738 → 16.741 |
| Windows W | 16.444 → .019 | 19.747 → .795 | 1.481 → 1.482 | .223 → .210 | 16.746 → 16.748 |
| Linux N | 52.628 → .049 | 54.164 → .906 | .887 → .026 | .573 → .597 | 13.088 → 12.509 |
| Linux W | 54.898 → .056 | 57.075 → 1.462 | .907 → .861 | .590 → .556 | 13.533 → 12.938 |

E eliminates the feedback CPU cost without equivalent main-thread transfer in
this workload. Main still replays retained full+dirty under W and uploads the
entire backing texture. The normal Windows p95 scarcely changes because retries
are rare there. ACK-issue→clear p95 among successful clears is mixed: Windows
14.598→9.294ms, Linux14.899→19.182ms. Stale/censored ACK populations differ;
there is no blanket scheduling/ACK-latency improvement claim. W has no issued ACK
or clear latency. Full p50/p95/p99/max distributions, returned bytes/refresh,
publication ratios, capacity and phase counters remain in the machine receipt.

Native timing closes the cost attribution question: in control W, the median
per-full-packet **full-copy scope / total C++ adapter scope** is98.167% Windows
and99.760% Linux. Exchange publication and remaining adapter work are small in
these retries. This fraction is not a hash-lookup fraction or total-frame share.
After E, snapshot copying/worker construction and main image/texture work dominate
the small dirty exchanges; legitimate initial/reset full extraction remains.

## One complete causal timeline

Final2 Windows N0, generation2, refresh127. Times are milliseconds relative to
owner entry at Godot monotonic4,225,387us; diagnostic event overhead is included.
Native call start/end use the explicitly captured outer-call timestamps.

| Relative time | Event |
|---:|---|
| -.731 | Main retrieves retained full publication62 |
| -.535 | Main begins CPU patch application for62 |
| .008 | Worker latches ACK61 against pending62; it cannot clear |
| .019–.028 | First native dirty call returns two bytes |
| .490 | Dirty append advances pending63 to2,097,154 bytes; rectangles do not overflow |
| .511–17.921 | Second native call forces a complete full copy |
| .538 | Main finishes CPU patch62 |
| .548–.742 | Main calls Texture.update for62 |
| .758 / .767 | Upload succeeds; Main issues valid ACK62 during the forced copy |
| 18.033 | Full recovery replaces pending with serial64,2,097,152 bytes |
| 18.100–18.183 | Publication64 becomes visible within the recorded publication bracket |
| 18.282 | Worker observes ACK62 against pending64; no clear |
| 32.608 | Main retrieves64; another dirty/forced-full cycle follows |
| 68.274 | A covering ACK66 finally clears retained serial66 and releases2,097,152 bytes |

Correct consumption/ACK can therefore lose the race to publication advancement.
The newer PLAY/lifecycle/generation work in frozen main preserves replacement
fencing but has not removed this mechanism. Changes in observed incidence cannot
be causally attributed to PLAY alone: source, workload and renderer differ from
the historical campaign.

## Final validation and integration handover

Nine focused real-native Godot processes per OS pass: bounded trace, patch
handoff, native render bridge, native/fallback world generations, E72, physics
async, failed-tick quarantine/reset, ten-cycle real Main LIFE001 Jet Barrel and
prepared-shutdown LIFE003 Jet Barrel. LIFE001 passes233 assertions/10 joined
workers per OS; LIFE003 passes30. All original outputs/hashes are retained.
The five native R oracle binaries were freshly executed after verifying every
compiled input equals current source: each again passes10,225,432 checks/265
regions. Uninstrumented ordinary native render leases, dirty rectangles and C
API/RGBA groups also pass. One optional native invocation used an unmatched
`bulk` test filter; that no-tests failure is retained beside corrected named
invocations. It is not a code-regression pass.

Readback adverse controls pass20 mutations for control-N and19 for E-W on both
OSes; runtime-manifest controls reject five wrong-library/roster/source/byte
variants on each OS. Frozen retrieval stays hit@1=19/32, hit@5=32/32, MRR.7536;
the separate two render questions both hit their canonical bridge at rank1.
Independent AI code and evidence reviews found no remaining actionable blocker
on the final runtime/fixture code. Semantic review confirms that retrieval must
retain test-only, platform and GPU-completion qualifiers.

**Publication gate remains open:** final documentation/M11/retrieval/whitespace
checks are separate from current published-runtime provenance. The deliberately
unchanged inherited LFS runtimes have three changed source inputs per OS
(`world.hpp`, `world.cpp`, `cyber_native_cell_world.cpp`); the strict repository
checker must report those six rebuild/provenance mismatches after restoring the
original binaries. Local rebuilt diagnostic runtime proof does not waive that
gate or authorize publishing diagnostic binaries. No source-bound publisher
request is reused, no published manifest/hash is rewritten, and no ready-PR/full
release matrix or merge is claimed. A later integration must reconcile the
advanced main and existing #290 ownership, then qualify/publish the resulting
production source under its proper request.

Recommended next production work is a separately reviewed strict E retention
policy, preserving this complete-frame/type/generation validation and bounded
preflight, with active PLAY/ANGLE/target-device pacing before a default change.
R remains an independent extraction improvement to reconcile through #290's
existing owner. Its large isolated win plus measured extraction dominance
supports an initial/reset/recovery benefit, but this branch intentionally never
measures ordinary publication with R enabled. Neither candidate supersedes the
other. Do not pursue baseline dropping/rebasing, coalescing complexity, early ACK,
weaker fencing or unrelated physical/shader changes as part of this repair.

Remaining hypotheses are representative active-world prevalence, GPU completion
and queueing, ANGLE/cold-cache behavior, human frame pacing and whole-process
memory under retained consumer lifetimes. The paused deterministic fixture,
native warm-copy benchmark and final readback do not answer those. Host activity
outside this branch was not controlled; small timing differences and frame-rate
gains are not accepted causal findings.

The tested local binaries remain under the raw root as `final-native-Windows.dll`
and `final-native-Linux.so`, with their source-bound manifest JSON files. To rerun
on this host, temporarily copy the selected diagnostic binary into its declared
`godot/addons/cybersand_native/bin` path, pass that platform's manifest with
`--runtime-manifest` and require `--require-native-stages`, then restore the
retained `inherited-*` binary after testing. The driver refuses wrong-platform,
subset, changed-source or wrong-byte manifests. This is an explicit diagnostic
procedure, not a published-runtime installation or production selection.

The local raw-evidence archive is
`C:/Users/_/.codex/tmp/render-publication-abc-20261031-evidence.zip`:
13,614,573 bytes,526 members, SHA256
`cc6d3254bac3c86765ee21e924e2d7fcfec4b3917b2a56ec9ca527d2829e944c`.
It contains raw events, original reports/logs/PNG witnesses, reproducibility
helpers and explicitly labelled failure transcriptions. It excludes compiled
binaries, toolchains/caches and post-commit canonical gate outputs. Curated
receipts are committed; the archive and local diagnostic binaries are not.
