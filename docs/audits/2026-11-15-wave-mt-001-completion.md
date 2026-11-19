---
title: WAVE-MT-001 PR 618 completion and qualification ledger
status: Current
document-kind: evidence
scope: 15 November 2026 independent PR 618 completion; source repairs, protected-source transitions, experimental Godot integration, pinned runtime publication, native benchmark method and exact-head acceptance custody
canonical-for: []
last-reviewed: 2026-11-15
related-documents: [../architecture/wave-flow-v1.md, ../operations/wave-flow-evaluation.md, ../operations/github-development-and-release.md, ../operations/ci-execution-and-performance.md]
---

# WAVE-MT-001 PR #618 completion

This record belongs to [PR #618](https://github.com/techrote/cybersand/pull/618)
on `codex/wave-mt-001-parallel-20261115`. The original Claude PR #617 remains
separate and is not modified. The owner authorizes implementation, repairs,
source-matched builds, repeated CI execution and Ready-for-Review activation.
Merge, auto-merge and production Water-default promotion are not authorized.

Run-specific results, exact HEAD/tree identities, retained artifact links and
the final independent Astra verdict are recorded in the PR's qualification
ledger. A workflow definition or local predecessor pass is not a final-head
pass. This source record describes the concrete changes and acceptance method;
it does not substitute for that live run ledger.

## Source custody

| Reference | Verified starting commit |
|---|---|
| Accepted main | `018bd09503d7f079ddac52e225c2f7daf8d678bf` |
| Independent reconciliation checkpoint | `5e8ff8391f58516c18ea640986b6c4a49e0f8257` |
| Claude PR #617, inspected read-only | `50d60c5d4e69c193f74306553ff33c9341922be7` |

The [original audit](2026-11-15-wave-mt-001-wave-flow.md) remains unchanged.
Its Windows timings and review are historical results for the original source;
they are not reused as proof for this candidate.

## Repaired contracts

- One-unit transfers and pending nonzero flux keep the relevant region awake;
  deterministic seam, thin-film and falling-drop regressions exercise this.
- Selected simulation regions own complete selected cores. Excluded cores and
  faces freeze; reentry resumes retained state. Native tests compare 1/2/4/6
  workers, negative coordinates, edits and moving masks with fixed seeds.
- Complete physical identity is version 6 and includes retained flux, round,
  configuration and sparse scheduling metadata. Physical save format 0 and
  explicit save/restore refusal prevent silent loss of continuation state.
- Additive versioned C construction and uint16 mass readback preserve the old
  ABI. The old uint8 getter saturates; tests use actual overfilled cells.
- Receiver capacity arithmetic cannot underflow, sealed overfill is bounded,
  metered external removal preserves full mass, edits retire stale face flux,
  and unrepresentable coordinate halos refuse before mutation.
- Water population accounting, neighbouring material wakes, symmetric damping
  and adhesion settings have explicit regression coverage.
- Water-owned pair chemistry, coherence and lighter-fluid exchange remain
  intentional experimental limitations. Nonzero coherent writes and custom
  transport profiles refuse. Other materials retain their initiating kernels.

The native default-off path and registered policy families remain unchanged.
The experiment remains a `WorldConfig::wave_flow` override of the FreeMass
Water carrier; no catalogue identity or production policy family is added.

## Linux ABI diagnosis

The original `alignas(64) WaveHalf` raised the containing Wave allocation's
alignment. ELF symbol inspection of the original executable confirmed aligned
`operator new` and `operator delete` imports requiring `CXXABI_1.3.11`.
Ordinarily aligned storage with 64 trailing padding bytes separates the useful
per-worker counters without invoking that allocator. The runtime-floor checker
is unchanged: the actual pinned runtime must still pass the existing GLIBC,
GLIBCXX and `CXXABI_1.3.9` checks. Local development uses GCC 14.2/ld 2.44 and
does not establish the pinned build's floor; hosted builds use the repository's
approved GCC 13.3/ld 2.42 and LLVM-MinGW 20260826 inputs.

## Godot and packaged execution

The desktop feature launcher and `--wave-flow` route construct a real native
Wave World. The [guide](../operations/wave-flow-evaluation.md) describes the ten
fixtures, comparison solvers, native/Rapier rates, substeps, worker readback,
quantity and memory diagnostics. The moving barrel and Needle reuse the actual
Rapier bridge and authored actor paths. Copied render values remain separate
from mutable native authority; native pool workers call no Godot APIs.

`godot/tests/test_wave_flow.gd` requires all nine completion sections:
native configuration, mass readback, region pause, state identity, save refusal,
solver comparison, fixtures, real Rapier contact and real Needle contact.
The publisher rejects missing/false/malformed/duplicate completion, failures,
skips, nonzero exit, source changes and log digest mismatch. Existing liquid
policy, pressure reference and PressureFlow/Rapier controls execute alongside it.
All ordinary discovered Godot shards remain separately required.

The Windows package contains pinned Godot 4.7, the source-built native DLL,
pinned Rapier, applicable verified VC runtime files and notices, committed
game/fixture source, the guide, native/source provenance and a SHA-256 file
manifest. `Test It.cmd` imports and launches the Wave evaluator without local
developer paths. The workflow extracts the final ZIP into a separate directory,
verifies its complete payload, then executes import, the strict Wave suite and
launcher startup on Windows. Actual physical GPU and human gameplay acceptance
remain separate from automated headless execution.

## Benchmark method and retained negatives

The hosted Windows matrix measures complete `World::tick()` calls with one
fresh process per row. Four scene groups run in parallel; every size, law,
worker count and repeat for one scene stays on the same host/compiler/build.
Each group's source, executable and hardware identity is retained separately;
comparative timings are never pooled across those hosts. It covers 256²,
1024² and 2048²; dam, repeated wave disturbance, disconnected sparse reservoirs
and idle pools; FreeMass, Inertial, PressureFlow cached/dormant, and Wave substeps
1 and 3; requested workers 1/2/4/6; two repeats, 30 warm-up ticks and 180 measured
ticks (240 warm-up for idle). The active-wave measurement includes repeated
disturbances at ticks 91 and 181, after its warm-up disturbance at tick 1.
The original proposed 60-tick window would have ended before either measured
disturbance; the pre-activation coverage audit corrected it before the full
campaign. Every measured law uses the same allocation
instrumentation and quantity/ledger closure checks.

Raw CSV, per-row JSONL, executable/source/tree/compiler/machine identities,
allocation counts and bytes, steady storage, actual participants and
median/p95/p99/max complete-tick times are retained in the Actions artifact.
Phase timings include only the measurement window. The runner fails on malformed
or missing rows, timeout, nonzero exit, mass/accounting mismatch or source
mutation. It preserves failed rows and logs instead of dropping negative results.
The reducer reports matched ratios; targets are evaluated from actual output.

A separate same-host default-off control compiles a byte-identical, common-API
FreeMass harness against exact accepted main
`018bd09503d7f079ddac52e225c2f7daf8d678bf` and the candidate, with identical
g++-13 settings. It runs 256² and 1024² dams, 2048² disconnected basins and a
2048² idle pool, workers 1/4, three alternating baseline/candidate repeats:
48 fresh processes. It retains complete-tick percentiles, quantity and state
identity, participants, source/harness/executable/compiler/machine identities,
raw rows and failures. Equality of legacy behavior is checked separately from
the observed timing ratios; no new arbitrary performance threshold creates a
pass. Rolling historical CI timings and the older PressureFlow baseline are
not substituted for this current-main comparison.
Both matched performance campaigns are scoped to non-Draft PR #618 or an
explicit manual dispatch. Routine Linux sanitizer/correctness and Windows
native regression jobs remain active for applicable ordinary changes; this
dated baseline and the large matrix do not become mandatory work for every
unrelated future native edit.

The local 20-row 256² apparatus smoke used deliberately short eight-tick
measurement windows with concurrent development work. All rows passed quantity
closure and measured zero tick allocations. It validates apparatus operation,
not performance targets or parallel speedup. The complete hosted matrix is the
candidate evidence for performance.

## Publication and exact-head acceptance

`tools/ci/wave_mt_runtime_publication.py` privately composes the established
shared-contract publisher. It retains source/Git/LFS/input-ledger, target-OS,
binary architecture, log-integrity, exact branch-lease and four-file staging
guards. An explicit versioned request on the owned branch arms builds. The
workflow cannot modify Claude's branch or main. The single-parent append and
exact source lease reject a branch that changes while builds run.

The publication job waits for the native normal, ASan/UBSan and TSan suites,
both target-OS focused regressions, Linux ABI checks, and extracted Windows
package qualification. Its only committed paths are the two native binaries
and their two provenance manifests. The original shared publisher and runtime
floor policy remain unchanged.

The resulting PR HEAD then requires Documentation/provenance and protected
source checks, the complete native aggregate/sanitizer families, Linux and
Windows source-built GDExtension plus all discovered Godot shards and coverage
reducers, applicable Water/PressureFlow/inertial/architecture gates, and the new
Wave suite and matched Windows matrix. Draft skips and classifier-only results
do not satisfy execution. Any later native change invalidates affected binaries;
every later HEAD requires its own applicable CI conclusions.

Only after those checks are green is a separate explicitly selected Astra
reviewer commissioned against the frozen HEAD/tree, accepted main, complete
diff, actual logs, raw timings and artifact provenance. Blocking findings require
repair, requalification and renewed independent review. The final PR remains
unmerged for the owner.

## Protected-source transition records

Each reviewed transition below authenticates its retained source commit and
exact LF hashes. The immutable baseline catalogue lock is not edited. The
transition chain requires retaining the named commits, so eventual integration
must use a merge commit rather than squash or rebase.


### PR #618 source checkpoint

Reviewed source commit: `1e7fac9eb909b982c961f34eefe7859430728de8`, tree
`0d33bdc063d3c05aeca1941ab004ba894de5dbc0`. The implementation review compared
these three protected consumers with accepted main. Wave-owned construction,
transport, wake and physical-state additions are conditional on the opt-in
World; catalogue IDs, definitions, digest inputs and admitted production
policy/physical formats are unchanged. The shared receiver-capacity expression
now returns zero when already full; all legal legacy receivers retain the same
capacity. No immutable lock or historical transition is rewritten.

The reviewed `world_quantity.inc` addition changes only the number of Water
cells after conservative bulk transport; it cannot create a quantity source
or sink. `world_pressure.inc` changes only Wave's versioned complete-state
identity and explicit unsupported continuation refusal. `world.cpp` wires the
conditional side state, bulk passes, wakes, edits and validated carrier bounds.

Local execution at this checkpoint includes the expanded 22-case optimized
native suite (build and execution passed with identical before/after input
digest `4b4bd578807f3d5e94aa837758690ad319d9b00692faba98d778d3ea4e5087a5`),
the Godot 4.7 development fixture suite (4,981 assertions, zero failures), the unchanged Linux runtime-floor check, three publisher/package
adversarial tests, thirty inherited publisher guards, documentation/M11 and
retrieval checks. Later exact-source adapter, sanitizer, target-OS, complete legacy-family
and exact-head CI results remain separately identified in the PR ledger.
The first local ASan/UBSan execution passed all 21 predecessor cases but failed
at LeakSanitizer shutdown because this local environment runs under ptrace;
that process is recorded as failed, and hosted leak checking is not disabled.
The source review authenticates this bounded transition; it does not waive
those runtime gates or assert merge approval. PR #618 is the tracking issue
for these three transition entries.

| Protected path | Previously admitted LF SHA-256 | Reviewed LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `36f928740f554cde7542bc16e8ef897317ea51f3897af665ff6bb7f9e1ca812b` | `9600f625792929db95481f45cca2233716df921ff5001a052d0839de043ff384` |
| `native/src/world_pressure.inc` | `899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec` | `a545d153f0f68c930837c59be449ac455b3fd35f36e268f21cffbfc940cb6da9` |
| `native/src/world_quantity.inc` | `d9e6835d092193e4976c728d90121c6dee4b421337e056b5fc3c74975491af6e` | `1dc5ac99aacb1bac6a41edb0aa7479ed4dbef2b493e1d26b02e185aaff9c3e1d` |


## Retained publication attempt 1 and repair

Source `9f1a9c866f488f3c0dff430b1e6dcddcccf3d899`, tree
`1ef30afc063b8ef720fb5cf97c8266cd78bc080a`, ran in
[publication attempt 43735033954](https://github.com/techrote/cybersand/actions/runs/43735033954).
All 22 native cases passed in normal, ASan/UBSan (with leak checking) and TSan.
Both pinned runtime builds succeeded; the actual Linux runtime passed the
unchanged floor, including CXXABI 1.3.9. Each target OS passed the unchanged
liquid policy (642 assertions), PressureFlow reference (1,934 assertions) and
PressureFlow/Rapier (3,589 assertions) controls.

The new Wave coherence-refusal assertion exposed an uncaught native exception
in `water_experiment_fill_rect`; the sibling `emit_disc`/`paint_disc` path had
the same missing preflight. Linux and Windows Wave execution failed, and the
publisher correctly withheld validated manifests, the package and the runtime
append. The first failure is retained; it is not a successful publication.

The repair adds explicit pre-mutation checks at the two public live emitters.
The original failing assertion remains; two new assertions require unchanged
complete state and render revision after rejected disc/paint emission. This
changes the adapter's runtime inputs and therefore requests fresh builds of
both targets. The Wave native law and protected-source hashes are unchanged.
The benchmark reducer also now refuses interrupted/truncated campaigns whose
planned/completed/retained row counts disagree; its nine contract tests pass.

## Retained publication attempt 2 and package repair

Source `148b7b5f8b14989f6edb99225bae1814dfea2c49`, tree
`8d9284cd31ef8586f41907df7fe48ddcbdf88353`, ran in
[publication attempt 43735958089](https://github.com/techrote/cybersand/actions/runs/43735958089).
All 22 native cases again passed in normal, ASan/UBSan (including leak checking)
and TSan. Both pinned builds and the unchanged Linux ABI floor passed. Both
actual target OSes passed Wave's 4,986 assertions and all nine required sections,
plus the three unchanged legacy controls.

The extracted Windows package passed import, the same 4,986-assertion Wave
suite, and the delivered `Test It.cmd` startup with the required evaluation
marker. The final payload-custody check then correctly rejected an input
rewrite: Godot regenerated the tracked Rapier `Radial2D.svg.import` sidecar.
This attempt therefore failed, and no runtime append or qualified owner ZIP
was published. Functional startup alone did not satisfy package integrity.

The package repair removes only the reviewed, reproducible Rapier import
sidecars from the active delivered project before its final manifest is made.
Their original identities remain recorded; authored image assets, UID files,
scripts and binaries retain complete byte checks. The initial extracted
inventory must still exactly match its manifest, and every delivered byte must
remain unchanged after execution. Generated import output is never admitted as
trusted delivered source. Focused guards cover omitted metadata, retained
authored files, unexpected payload changes and post-execution corruption.
Pinned Godot 4.7 import/readback experiments also confirmed identical decoded
pixel hashes, dimensions and formats for all four images with and without the
sidecars. The ZIP now includes the verified target-OS runtime provenance,
toolchain record, execution report and original five focused logs. Eleven
publication/package guard tests pass, alongside the thirty unchanged shared
publisher guards; hosted execution of the new package remains required.

## Retained publication attempt 3 and archive portability repair

Source `4127c6926f84dacb8d841ffeedc11d5d6d30c0eb`, tree
`04fbc787c89b1ed3e44a22a850ebd196eee61e46`, ran in
[publication attempt 43739210349](https://github.com/techrote/cybersand/actions/runs/43739210349).
All three 22-case native modes passed. Windows passed the four focused runtime
suites and admitted the validated runtime provenance for packaging, but the
new sidecar fingerprint guard rejected the inherited archive before package
execution. No qualified ZIP or runtime append was published.

The cause was archive text conversion, not an authored import-setting change.
An actual `git archive` reproduction with `core.autocrlf=true` and
`core.eol=crlf` produced the same logical Rapier metadata with 44 CRLF lines
(1,118 bytes); explicit false/LF settings produced the reviewed 1,074 bytes
and the original SHA-256. Reading raw Git blobs in the original unit fixture
had not exercised archive conversion.

The Wave wrapper now scopes canonical text settings to the inherited packager
process and preserves explicit `.gitattributes` line-ending declarations.
It also skips archive-time LFS smudging; the shared packager still reads and
verifies the already materialized required target payloads explicitly. The four reviewed
sidecar fingerprints remain byte-exact. New regressions exercise a real Git
archive under inherited Windows-style conversion and verify authored files,
explicit CRLF attributes and LFS handling. The shared Explore packager and
native source remain unchanged.
Thirteen focused package/publication guards pass after this repair, including
the real archive regression. The final Windows matrix uses four independently
recorded 120-row scene groups; final acceptance also checks their complete
480-row Cartesian coverage. No comparison group is split across hosts.

## 2026-11-15: retained full qualification attempts and artifact isolation repair

The subsequent [runtime publication run 43740816006](https://github.com/techrote/cybersand/actions/runs/43740816006)
succeeded from builder `e76f2a5c4e313f9cb01fa4196968327204fb39e6`.
Its source-matched native, target-OS, ABI-floor and extracted-package execution
records were retained. The resulting candidate
`67f769d281ce369e424cf4aa0ef6f3beebf7c3c3`, tree
`665a48a4249d0ea2b271024c34d91cab2c103870`, then entered complete PR
qualification. Ordinary PR jobs used merge-test commit
`3e88a8dc6ab972c5db57d282560629967241537c`, whose tree exactly matches that
candidate. These identities describe the retained attempts below; they do not
qualify the next source candidate.

### Godot attempt 1: dependency download reset

[GDExtension run 43742182904, attempt 1](https://github.com/techrote/cybersand/actions/runs/43742182904/attempts/1)
failed before Linux regression shard 10 could execute its tests. The
[shard setup log](https://github.com/techrote/cybersand/actions/runs/43742182904/job/132905844688)
records `curl` exit 56 at `2026-11-15T18:09:30Z`: receipt of the pinned Godot
archive was interrupted by a connection reset. The existing `--retry 3`
invocation did not retry that observed error. The
[Linux coverage reducer](https://github.com/techrote/cybersand/actions/runs/43742182904/job/132908291415)
then rejected the incomplete execution. This was a failed qualification
attempt; successful sibling shards did not satisfy the missing shard.

The failed setup ZIP, original job log, rejected coverage receipt and log,
complete attempt snapshot and artifact inventory are retained as historical
failure evidence. They are not substituted for a later complete execution.

### Godot attempt 2: all test shards passed, aggregate rejected stale evidence

The same candidate was rerun in
[run 43742182904, attempt 2](https://github.com/techrote/cybersand/actions/runs/43742182904/attempts/2).
All 23 Linux regression shard jobs and all 22 Windows headless regression shard
jobs succeeded, including the new Wave contract, real-body/Needle and graphical
execution. The workflow still failed:
the [Linux coverage reducer](https://github.com/techrote/cybersand/actions/runs/43742182904/job/132914396644)
correctly rejected a `run_attempt` identity mismatch.

The Linux shard artifact names included the run ID but omitted the attempt.
The reducer's download selection chose the numerically larger of two artifacts
named `linux-godot-shard-11-43742182904`. The retained API metadata and the
embedded `godot-regressions/shard-11/timings.json` establish the reversal:

| Artifact ID | Creation time, UTC | Embedded execution attempt | Reducer selection |
|---|---|---|---|
| `14174380870` | `2026-11-15T18:11:45Z` | `1` | Selected stale artifact |
| `14174033548` | `2026-11-15T18:32:11Z` | `2` | Required current artifact |

Both shard reports completed successfully and bind the same source/tree, but
they belong to different executions. Numeric artifact-ID order did not prove
creation-time order or current-attempt membership. The reducer retained its
attempt check and refused the mixed evidence. Neither a green shard nor an
independent reconstruction of the correct artifact collection changes that
hosted rejection into a passed workflow.

All 56 original attempt-2 artifact ZIPs, their API-bound custody manifest,
the failed reducer log/receipt and the two shard-11 identity proofs are retained.
Archive custody passed; complete qualification failed. No passing attempt-2
verification summary or independent final Astra verdict was issued.

### Repair and remaining qualification

The next source candidate binds previously unscoped GDExtension artifact upload
names and matching named/pattern downloads to both `github.run_id` and
`github.run_attempt`. This covers the Linux runtime, both regression shard
families, build timings, Windows coverage and timing-reducer consumers; already
scoped plan, native-candidate, ART and Linux-coverage artifacts retain their
scope. A missing current-attempt artifact must remain a failure. The repair
does not select a predecessor by numeric ID or relax embedded source, attempt,
coverage or integrity checks.

The two Linux Godot downloads also gain bounded retry of the observed reset
class with `--retry-all-errors`, retaining the dependency preparation timeout,
archive SHA-256 and engine-version checks. The Windows Wave workflow's ancillary
`HEAD^{tree}` query receives explicit CMD quoting. These are CI execution and
provenance repairs; native solver behavior, the protected-source transition
hashes above and Claude's separate PR #617 remain unchanged.

The new CI source requires fresh source-matched publication and complete
qualification of its resulting exact HEAD/tree. Those builds, package
re-execution, all applicable native/Godot/Water/control gates and the later
independent Astra review are **pending** at this entry. Prior native,
sanitizer, benchmark and target-OS successes remain attributed to their recorded
source; they are not reported as future passes. Merge and auto-merge remain
unauthorized.

## 2026-11-15: Claude review, rest and identity repair

Claude (Fable 5.2) took PR #618 over at `bf16ca69ddf4b7b9a8daaa6a6cd4409e0e68aab4`,
tree `487cab300e1c9e679b6d469c5a095953bbfb9a13`, and reviewed the solver source
rather than the ledger. Every final-head workflow of that commit had passed or
was still running its benchmark matrix. Two defects were found that those gates
could not see, and both are repaired here. This changes native source, so the
runtimes, package and every source-sensitive gate of the predecessor head are
invalidated and must be earned again by the resulting head.

### Finding 1: disturbed Water never came to rest

**Observed on `bf16ca69` (local Windows, MSVC 19.38 `/O2`, 512² box, 4 workers,
20,000 ticks, one round per tick).** `first asleep` is the first tick on which
no Wave chunk was solved.

| Scene | First asleep | Still solved at tick 20,000 | Lateral units moved, ticks 18,001-20,000 | Cost at tick 20,000 |
|---|---:|---:|---:|---:|
| Level pool, never touched | 31 | 0 chunks | 0 | 0.001 ms |
| Same pool after one splash | never | 10 chunks | 23,071,362 | 1.31 ms |
| Dam break | never | 7 chunks | 12,963,852 | 1.01 ms |
| Three terraces | never | 14 chunks | 5,894,214 | 1.37 ms |
| Six separate basins | never | 6 chunks | 6,211,018 | 0.62 ms |

Only the never-touched pool slept, and that is the pool the benchmark's `idle`
scene measures. Its near-zero cost was real but did not describe Water that had
ever moved. The original #617 source had the same permanent motion; its 30-tick
sleep threshold hid it by stopping Water that was still moving, which the #618
liveness repair (correctly) removed.

**Cause.** A sample of column totals on consecutive ticks showed adjacent
columns trading about 25 units every few ticks with all 32 responding rows of a
face carrying the same flux (about 0.43 unit per round each). Each row rounded
that flux to whole units with an independent random threshold: about ±2.8 units
of noise per face per round. The law damps flux by only 1/128 per round, so
every wavelength rings about eight times above the noise that feeds it.

**Repair (law version 2).** Described in the
[design reference](../architecture/wave-flow-v1.md#coming-to-rest): evenly
spread rounding, a hard-damped calm band, a rest rule for level faces, direct
levelling of films, and the per-cell law's residual-film rule (a supported cell
keeps its film wherever it pours). No stored state is added.

**Result (same machine, same scenes, repaired source).**

| Scene | First asleep, 1 round per tick | First asleep, 3 rounds per tick |
|---|---:|---:|
| Pool after one splash, 512² | 1,141 | 401 |
| Six separate basins, 512² | 1,971 | 678 |
| Dam break, 512² | about 14,000 (still levelling until then) | 4,330 |
| Pool 1, 2, 3, 5, 8, 16, 33, 64 cells deep after a splash | 7,683 / 5,457 / 4,106 / 3,057 / 2,318 / 1,686 / 1,178 / 1,137 | not run |
| Pool after one splash, 1024² | 1,278 | not run |
| Three terraces, 512² | not within 60,000 (net drainage continues) | not run |

After rest the cost is the `idle` cost (0.001-0.002 ms a tick at 512²) and
nothing moves. Quantity was exact in every run.

**What it costs.**

- Interference, same probe scene: constructive ratio 1.93 (was 2.06, ideal 2),
  destructive peak ratio 0.25 (was 0.22, ideal 0), RMS superposition error
  0.074 (was 0.094), RMS cancellation error 0.044 (was 0.103), speed 0.499
  cells a tick (was 0.505). The dam, U-tube, waterfall and body scenes agree
  with the predecessor to about 1%.
- Complete ticks while Water is moving are unchanged within run-to-run noise
  (eight matrix rows at 1024² and 2048², one run each, local).
- Rested neighbouring columns may differ by one unit. Ripples below roughly 3%
  of a cell end quickly. Films carry no waves.

**Negative results kept.**

- Evenly spread rounding alone cut the permanent motion about 2.5 times
  (23.1 to 9.0 million units per 2,000 ticks in the splashed pool) and did not
  end it: the remaining rounding error still rings at the solver's damping.
- Constant friction on every flux did reach rest at 16 or 32 sub-units a round
  (not at 8), but it removes energy from real waves all through their cycle: a
  0.2-cell wave would be gone in about 160 ticks. Rejected for the calm band,
  which a real wave only crosses near its turning points.
- A stick threshold below the calm band's equilibrium flux (256 against 512)
  left sheets two to four cells deep ringing by a few units for ever: a
  two-unit step could build more flux than the rest rule would discard.
- Thin sheets still drain slowly. In the terraces scene the top ledge was
  losing exactly one unit a tick at tick 30,000. With the earlier destination-
  keyed film rule the same scene came to rest only at tick 139,821. Water that
  is still draining is, correctly, still solved; this is a speed limit of the
  law, not a liveness defect, and it is listed under Limits.

### Finding 2: `state_hash()` ignored retained momentum

The versioned physical identity (6) bound the retained flux; the legacy
`World::state_hash()`, which the C API and the Godot adapter expose as the state
hash, did not. Two Wave Worlds with equal cells and different flux, or with
different rounds per tick, shared it and then diverged. `state_hash()` of a
Wave World now also binds law version, rounds per tick, round counter and the
per-chunk solver state. Worlds without Wave Flow execute no new code and keep
their historical values.

### Regressions

Three native cases were added (25 in total). Each fails on `bf16ca69` with the
defect it names and passes on the repaired source:

| Case | Failure on `bf16ca69` |
|---|---|
| `disturbed water reaches exact rest` (depths 1, 3, 12, 48; rest is level to one unit, holds no flux, and solving it again changes nothing) | `depth 1: disturbed Water was still being solved after 9000 ticks` |
| `films level and rest` | `a film with a hump never came to rest` |
| `state hash binds retained momentum` (two Worlds differing only in where a body sat for one tick) | `equal cells with different retained flux share one state hash` |

In the first case the rest ticks are 2,009, 1,664, 1,403 and 1,105 for the
four depths, identical for one and four workers; the budgets are 9,000 to 4,000.

### Reviewed and not changed

- Strip ownership, the three barriers, the same-function-on-both-sides apply
  pass and the region freeze were re-read against the source. No race,
  conservation hole or worker-count dependence was found.
- Water-owned pair reactions remain an intentional limit of the experiment. A
  bounded way to restore them without the per-cell cost (strips collect Water
  cells that touch a reactive material; the owner runs the shared reaction
  stage on them in coordinate order) was prototyped on the superseded #617
  branch and is not part of this PR.
- A one-to-three-unit cell at a ledge edge still cannot pour (a quarter of it
  rounds to zero). It is at rest, not stalled work.

### Protected-source transition for this repair

Reviewed source commit: `d3c2cacdf1c083b1c1bf0bfd0ed0e14690a48fe2`. Of the protected consumers only
`native/src/world.cpp` changes, by three lines: at the end of
`World::state_hash()` it calls `hash_wave_state`, which returns immediately for
a World without Wave Flow. The solver changes themselves are in
`native/src/world_wave.inc` and `native/include/cybersand/wave_flow.hpp`, which
are not protected consumers. `world_pressure.inc` and `world_quantity.inc` keep
the hashes admitted above. The immutable lock and every earlier transition are
unchanged; this entry extends the chain, so integration still needs a merge
commit that retains the named commits.

| Protected path | Previously admitted LF SHA-256 | Reviewed LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `9600f625792929db95481f45cca2233716df921ff5001a052d0839de043ff384` | `09a34956642a203ae9b725875f0773001ab70bc22b478a904588604c7de866c1` |

### Evidence level

The measurements above are local, single-machine development results. They
justify the repair; they are not the qualification of the resulting head.
Hosted native, sanitizer, target-OS, package and matched-benchmark results for
that head are recorded in the PR ledger. The hosted `idle` scene still measures
a pool that was never disturbed; rest after disturbance is asserted by the
native regression above, not by the benchmark matrix.

## 2026-11-15: law 2 threshold and rounding clarification

The implementation-team source review following the rest and identity repair
found two statements above that were stronger than the actual numerical law.
This section corrects those statements without rewriting the retained local
observations or changing law version 2 arithmetic. It is not the final
independent Astra acceptance review.

### Supported films use a threshold, not a guaranteed minimum

The earlier phrase "a supported cell keeps its film wherever it pours" is too
strong. The 24-unit adhesion amount gates supported outflow using the mass at
the start of the apply pass. Each face independently computes its transfer
from that same donor. Two-sided outflow can therefore take a donor below the
threshold; later outflow then stops. This agrees with the existing per-cell
Water rule's threshold semantics. It does not establish a hard 24-unit floor.

An actual native `World` probe at
`b5b7b1a010e97cd1994b18ced7ee20660e837366`, built with local GCC 14.2, exercised
both rows below on solid support, with donor centres at x=63 and x=127 and
workers 1 and 4. Every tick retained the exact total Water quantity.

| Initial supported row | After one tick | Total Water | Result after disabling adhesion |
|---|---|---:|---|
| `[1, 25, 1]` | `[2, 23, 2]` | 27 | `[9, 9, 9]` |
| `[1, 32, 1]` | `[9, 16, 9]` | 34 | `[11, 12, 11]` |

All eight combinations reached sleep at tick 32. Pausing outside the region
and returning woke them, and solving them again left their content unchanged.
Disabling adhesion woke the residues and allowed further levelling to the
values shown. Complete physical hashes matched across worker counts. No
conservation, carrier overflow or false-rest defect was reproduced. The first
scratch probe had an invalid chunk-capacity configuration and refused before
executing a tick; that failed setup and the corrected execution are retained
separately in the review evidence.

**Design choice.** Preserve the existing threshold law and document it
accurately. A strict residual minimum would require sharing a donor budget
between both outgoing faces and would change the experimental transport law.
There is no correctness reason for that change in these reproductions.
Reversing this choice would require a versioned numerical change, new
cross-face ownership/conservation tests and renewed physical/performance
qualification. Supported adhesion residue may remain uneven by more than one
unit; the one-unit levelness result above belongs to the rested pool fixtures,
not every legal supported film.

The new native case `supported film uses an adhesion threshold` exercises both
rows and seams, exact quantity, zero retained flux at rest, pause/re-entry,
adhesion-disable wake/levelling and worker-count continuation identity. The
standalone Wave suite now registers 26 cases. No existing assertion or
conservation threshold is weakened.

### Additive rounding has a time-average guarantee

The earlier statement that rows of a face move their exact rounded aggregate
in every round is also too strong. A source-expression evaluation with x=0,
rows y=0 through 31 and a fixed flux of 512 sub-units per row gives an ideal
aggregate of four whole units. Across all 4096 round phases, the actual
aggregate ranges from one to seven units and averages exactly four. This
small arithmetic witness is not a native performance or fluid experiment.

The corrected contract is exact average transfer for a constant flux over the
full threshold phase cycle. Reduced sampling noise in a changing fluid is an
observed result of the retained development experiments, not a theorem that
every column transfers its rounded total in each round. Comments and the
current design reference now state that scope, and no rounding expression is
changed.

### Requalification boundary

These changes add a native regression and correct comments and current
documentation. The protected `world.cpp` bytes remain at the reviewed
`09a34956642a203ae9b725875f0773001ab70bc22b478a904588604c7de866c1`
transition; no protected-source record is rewritten. Native input bytes still
change, so publication request 7 rebuilds both runtimes and the Windows
evaluation package. The prior publication and any predecessor CI results are
retained as intermediate evidence and cannot qualify the resulting final
HEAD. Complete hosted qualification and the fresh independent Astra review
remain required at that final source identity.


## 2026-11-15: independent Astra distant-mask overflow repair

The fresh, explicitly selected `gpt-6-astra` review of
`da577a6cdbad608d08487fa5f3e3ec49ed955ec4` returned **BLOCK** on
`ASTRA-618-001` after that exact candidate had passed its complete automated
matrix and retained evidence readbacks. The reviewed tree was
`51d323ef85b4fb18b96ccdeea05d005f89bcb799`. The original report, specialist
reproduction and principal reviewer's independent execution are preserved.
Those automated passes and publication 7 remain evidence for the blocked
source; they do not qualify this repair.

### Confirmed failure and repair

`World::wave_column_task` subtracted the transient mask origin from the strip
origin in signed int64 before applying `std::clamp`. A legal Water cell at
y = -5,000,000,000,000,000,000 and a legal occupied 2-by-2 mask at
y = +5,000,000,000,000,000,000 overflowed on the first tick under GCC UBSan.
Both setup operations were admitted. The whole-chunk halo admission bounds
individual coordinates; it cannot bound the distance between unrelated valid
origins. The x membership expression also formed a potentially overflowing
mask endpoint. The existing generic mask accessors already used safe unsigned
relative distances.

The repair adds `wave_clip_mask_axis`, used for both axes. Signed ordering
selects the direction, unsigned subtraction represents the full nonnegative
distance, and each returned local index is bounded by the strip's int32 span
before narrowing. The helper never forms a global endpoint. This preserves
normal mask geometry and supports accepted masks whose mathematical endpoint
exceeds int64 while only representable occupied cells are accessed. The
existing clean-half skip, strip ownership, barriers and law version 2 remain
unchanged. The helper adds no allocation or shared mutable state.

The repaired `native/src/world_wave.inc` SHA-256 is
`8c5af5633fd9093360f5be353ae3b0c0bcbeb1464a4497cc4e459b20ba6c6fa9`.
The adjacent selected-core clipping and chunk-local halo calculations were
inspected; no second concrete clipping defect was established. This is not a
claim of exhaustive validation of all generic geometry.

### Regression and evidence scope

Three source-registered World cases extend the standalone suite from 26 to 29:

- `distant positive masks preserve Wave transport`;
- `distant negative masks preserve Wave transport`;
- `mask overlap at signed bounds preserves bodies`.

They cover both opposite-sign distant orderings in x and y, comparison with
unmasked Water transport, actual near-limit body support, first/last/outside
mask columns, mathematical endpoint overflow, quantity and healthy continuation,
and equivalent one/four-worker physical identity. Full physical hashes compare
worlds with equivalent mask state; unmasked controls compare local Water cells,
flux and quantity instead. Ordinary-coordinate masks and selected-region
semantics retain their existing regressions. No assertion is weakened.

An actual C++ extraction of the new helper passed 109,480 boundary/random cases
against arbitrary-precision interval arithmetic under GCC C++20 with
`-O2 -Wall -Wextra -Werror -fsanitize=undefined
-fno-sanitize-recover=undefined`, seed `0x618001`, exit 0 and empty diagnostics.
The source hash was unchanged during the run. Some helper cases deliberately
exceed the narrower World admission range; they prove arithmetic behavior, not
public World admission. The proof, raw inputs/output, compile command and
receipt are retained separately from World regression execution.

The complete original Astra review remains immutable, including its first
invalid-reserve scratch setup and corrected successful defect reproduction.
Local old-source red controls and repaired World execution have their own
source/compiler/command/result receipts in the PR evidence. All three new
regressions fail on the frozen reviewed source under UBSan with their respective
signed-overflow diagnostics. On the repaired source, the same three cases and
the complete 29-case optimized normal suite pass; the full suite took 120.709
seconds with unchanged source/executable hashes and empty stderr. The new test
source SHA-256 is
`508e7b6ad56e4ec2c340ef530fb6823caa647ab966393a602cfad5d2e3939f3a`.
These local results do not substitute for the complete hosted sanitizer matrix
or final-HEAD qualification. The first review
also corrected a report claim: the negative wave probe establishes an inverted
trough arrival, not an explicit reflection assertion. The 120 Hz Godot check
verifies clock settings; it does not establish sustained actor contacts at
every unequal native/Rapier rate. Neither limitation is hidden by the repair.

### Documentation and renewed qualification

The current mask contract is updated in the existing Wave architecture page.
Its ownership, interface, capacity, policy/default and dependency routes are
unchanged, so no new canonical page or programme ordering is introduced. A new
boundary-contract retrieval question is retained separately from the unchanged
32-question frozen evaluation. It retrieves the correct mask section at rank 1;
manual readback also checks the existing halo-admission qualification. The
frozen lexical evaluation yields 19/32 canonical hits at 1 and 30/32 at 5;
these are retrieval measurements, not automatic answer-correctness claims.

The protected `world.cpp` bytes remain at the reviewed
`09a34956642a203ae9b725875f0773001ab70bc22b478a904588604c7de866c1`
transition. No compatibility record or historical hash is rewritten. Publication
request 8 rebuilds both source-sensitive runtimes and the Windows evaluation
package. All invalidated exact-HEAD gates and a fresh independent Astra review
are required after that publication. Wave remains opt-in/default off, Claude's
separate PR #617 is untouched, and no merge or auto-merge is authorized.
