---
title: Physical actor deferred BVH blocking-call confirmation and paired validation
status: Current
document-kind: audit
scope: Captured blocking call, paired qualification and source-matched Windows/Linux x86_64 runtime backport selection
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-23-physical-actor-timeout-handover.md, 2026-10-23-physical-actor-timeouts.md, ../operations/local-build-and-validation.md, ../decisions/ADR-009-rapier-2d-rigid-body-backend.md]
---

# Physical actor deferred BVH confirmation and paired validation

## Resume identity and scope

The owner resumed [draft PR #236](https://github.com/techrote/cybersand/pull/236)
from handover commit `3e0f01e2b829bde1a357a79637bab15bf3de430d` on 2026-10-24.
The existing `codex/physical-actor-timeouts` managed worktree remains the source
checkout. Original dirty material work and LCB #215/#217/#226 / MAT-003PREPASS
remain untouched. At resume, the experiment had not published a runtime or changed
default selected binaries. The subsequent qualified desktop selection is recorded
below. Native physics, solver parameters, pool size and assertions remain unchanged.
The PR stays draft through remaining full-suite validation.

## Confirmed captured blocking call

The valid engine dump from hosted run
[40014516069](https://github.com/techrote/cybersand/actions/runs/40014516069),
Windows batch 3, arena iteration 1, PID 1796, can now be unwound reliably using
the exact Server 2022 `ntdll.dll` / `KERNELBASE.dll` images and PDBs retrieved
from Microsoft's public symbol server. This resolves the previous local Windows
11 image mismatch; no SDK installer was used. The original wrapper dump is not
used to infer engine behavior.

The [curated frame attribution](physical-actor-timeouts-2026-10-23/confirmed-dump-frames.json)
records the dump hash, module base, frame RVAs, full mangled symbol names and
byte-comparison lengths. The official v0.35.2 static archive SHA-256 is
`c4b69859e1792a245787300b48ad434faa7240882c0d3645441469073626a155`.
Its COFF function sections recover names for the stripped retained DLL: every
non-relocation byte of each attributed function matches the DLL. Unmatched
frames are explicitly retained by RVA rather than assigned guessed names.

| Thread | Captured wait |
|---|---|
| Main 2724 | `LockLatch::wait_and_reset`, under the addon's `PhysicsWorld::step` / Rayon install |
| Rapier worker 4620 | `Thread::park` → `Channel<DeferredBvhOptimize>::recv` → `PhysicsPipeline::join_deferred_bvh_optimize` → `PhysicsPipeline::step_inner` |
| Other Rapier worker 4304 | Parked in the Rayon scheduler; no deferred-BVH producer is running |

This **confirms the blocking call** anticipated by
[upstream Rapier #1008](https://github.com/dimforge/rapier/issues/1008).
The waiting topology does not itself prove the exact scheduler race or a lost
wakeup. Native World worker joins, session acknowledgement waits and quit are
not the active blocking path in this captured arena failure.

Local raw output: `build/actor-matched-stacks.txt`; Microsoft images/PDBs:
`build/dump-symbols`; archive: `build/static-rapier-2d-single.zip`. The portable
[COFF mapping tool](../../tools/ci/map_rapier_coff_frames.py) accepts the extracted
Windows static `.a`, retained DLL, output JSON and frame RVAs. These ignored
binary artifacts and logs are not committed. The retained Windows DLL SHA-256
still matches the handover.

## Paired experiment registration

Three additional valid engine dumps (arena batch 0 iteration 6, rigs batch 3
iterations 3 and 7) confirm the identical deferred-BVH receive, outer install
latch and idle-other-worker topology. Their
[hashes and recovered RVAs](physical-actor-timeouts-2026-10-23/additional-confirmed-dumps.json)
retain each independent capture. Batch 0 required its own exact system images;
using the batch 3 images failed timestamp validation and was not counted.

Initial paired build run
[40053106474](https://github.com/techrote/cybersand/actions/runs/40053106474)
at `18f6105736fb5a0a37e96c5220857f21ed0630e2` compiled both Linux variants and
passed the expected helper controls. It exposed a provenance preflight error:
the registered patched source hash came from Windows CRLF output of `git apply`,
while Linux produced LF. The LF hash is
`0a63cf10ae1111c4fa3c22d945d505918f36d1165b8176e130573d5259f9a973`.
The corrected builder writes canonical LF before checking, hashing or compiling;
the candidate code is unchanged. Preserve this initial run as an apparatus
failure, not a complete paired acceptance campaign. The corrected campaign is
independent and retains the same strict per-trial oracles.

The corrected campaign is
[40053639095](https://github.com/techrote/cybersand/actions/runs/40053639095)
at source `4c2bb37` (full identity in its build manifests). All four addon builds
completed successfully; each blocking helper control exited 124 with the named
sentinel, and each patched helper passed three tests. At that initial observation
the same-head application trials and full local Windows suite were still in
progress. Their completed results are recorded below.

A control timeout in the first campaign's Windows batch 0, rigs iteration 6
(`gemini`, last step marker 34320), also yielded a valid engine dump. The
[matching-DLL/PDB analysis](physical-actor-timeouts-2026-10-23/symbolized-control-dump.json)
directly names the BVH receive, outer install latch and other worker's
`rayon_core::sleep::Sleep::sleep` / `wait_until_cold` frames. This independently
corroborates the earlier COFF attribution. It is supplemental Windows evidence,
not acceptance of the incomplete first paired campaign. Full raw debugger output
is retained locally in `build/paired-control-symbolized-stacks.txt`.

**Planned execution at this checkpoint:** the registered GDExtension workflow's
manual `physical_actor_stress=true` plus `rapier_bvh_pair=true` calls the isolated
paired build/stress lane. Both OS builds use the same addon commit, original
Cargo.lock dependency versions, exact Rust 1.98.0, Godot 4.7 API, features and
symbol-retention settings. The control restores the original crate join bytes;
the candidate changes only the deferred join and adds its test module. The
build lock records the exact original/patched join and patch hashes.

The minimal Rust harness compiles the exact helper/test text from the patch.
Its deterministic two-worker starvation control is expected to stop with exit
124 and the named sentinel within ten seconds; patched execution must pass.
Harness registry packages must match the pinned addon Cargo.lock. This tests
cooperative progress when another worker is occupied, separately from the
intermittent idle-worker topology in the captured application.

Then each variant runs 50 independent arena, rig and course trials on each of
GitHub-hosted Windows 2022 and Ubuntu 24.04. Every failed trial remains failed;
control stress failures can make the workflow red and are not retried or skipped.
Each variant has a separate strict frequency summary. Require complete paired
scope, control reproduction and zero patched timeouts before accepting a repair.
The ordinary retained-runtime validation remains strict by default; only the
explicit experimental stress option accepts a same-head build manifest, while
preserving native source/runtime verification. Candidate DLLs/SOs are temporary
job artifacts, never silently substituted into committed runtime provenance.

The build guide owns invocation, and this audit owns the dated results. Thread
ownership, native interfaces/capacities, actor controls and fixture numerical
semantics are unchanged. ADR-009's retained dependency selection is not superseded
by an experimental build. Final full-suite and exact-head gates remain required.

## Completed separate-host samples and strengthened protocol

The first sample's [control frequencies](physical-actor-timeouts-2026-10-23/initial-pair-control-frequency.json)
are Windows arena 4/50, rigs 6/50 and course 2/50 timeouts; Linux control passed
50/50 per test. Its [Windows candidate sample](physical-actor-timeouts-2026-10-23/initial-pair-patched-frequency.json)
passed 50/50 per test, while Linux candidate preflight failed because of the
already recorded EOL hash error. The first sample remains incomplete overall.

The [complete corrected sample](physical-actor-timeouts-2026-10-23/corrected-pair-inconclusive.json)
at `4c2bb37` passed 50/50 per test/OS **for both variants**. The paired gate
correctly failed with `Control did not reproduce a timeout`. Zero candidate
failures are retained, but this cohort alone cannot meet the registered causal
comparison criterion. The Windows control executable `.text` section is identical
across the two samples: SHA-256
`23abe93825d2fe5501f975a663d76043c6fe8e7950fe251ecd2998aafed5a809`.
This is evidence of cohort/scheduling sensitivity, not proof of its exact cause.

Here **corrected** means the provenance preflight's LF/CRLF handling was corrected;
**control** still means the original blocking receive, and **patched** means the
cooperative join. The candidate's zero-timeout result is the desired outcome.
The later control's zero-timeout result makes that cohort inconclusive as a
standalone comparison, but does not invalidate either cohort's candidate passes
or the earlier Windows comparison (12/150 control timeouts versus 0/150 patched).
The [code/input equivalence record](physical-actor-timeouts-2026-10-23/paired-windows-code-equivalence.json)
also verifies identical candidate executable `.text` across these two campaigns,
and identical Godot, native and example Git subtrees. Whole DLLs remain distinct
artifacts; matching code is not a claim that every byte or scheduling outcome
matches. The incomplete first campaign remains qualified by its Linux apparatus
failure, while its completed Windows comparison remains valid platform evidence.

**Registered next experiment before execution:** both variants now run on the
same GitHub-hosted machine in each batch, using separate complete source copies.
Every test pair alternates control-first / candidate-first by iteration and
batch. Each OS still has five batches of ten independent trials per test and
variant, preserving all 600 trial outcomes without retries. CPU model, logical
and physical core counts, host/batch identity, exact fixture hashes and pair
order are recorded. A host with fewer than two physical cores fails preflight
instead of silently testing only Rapier's inline path. No physics/thread-count
override is introduced. The qualification checker additionally requires matching
host/hardware/fixtures and the registered balanced order. This is a new controlled
experiment; it does not erase the inconclusive or failed earlier samples.

The registered same-host campaign was dispatched as
[40056501226](https://github.com/techrote/cybersand/actions/runs/40056501226)
from exact source `96dcb2ab6e35c9104726b2a541d1c2fbb298eecb`. It is in progress
at this checkpoint. It strengthens the aggregate evidence; the already observed
Windows control failures and candidate passes do not depend on reproducing a
new control failure in every future cohort. Keep the campaign's own registered
qualification result distinct from that aggregate interpretation.

## Full local candidate Windows scope

The [complete-repository candidate suite](physical-actor-timeouts-2026-10-23/patched-full-windows.json)
passed import plus **121/121** applicable Windows headless tests at source
`4c2bb37`, with no timeout, skip or copied-input drift. The manifest records exact
Godot/native/Rapier identities, the orchestration hash, source/local-delta scope,
raw report hash and every case result. Rendered cases remain Linux-owned.

An earlier [invalid project-only copy](physical-actor-timeouts-2026-10-23/invalid-local-full-apparatus.json)
lacked repository-level `examples/worldgen` JSON fixtures. It recorded five actual
test failures and was stopped after 58 cases. Its outcomes and raw report remain
preserved; it is excluded from full-suite qualification. The complete repository
experiment reran the whole scope with unchanged assertions and deadlines, and
passed those generation/launcher cases as well as the rest of the suite.

## Completed same-host qualification and desktop selection

[40056501226](https://github.com/techrote/cybersand/actions/runs/40056501226)
completed all **600 independent trials** at exact source
`96dcb2ab6e35c9104726b2a541d1c2fbb298eecb`. Its
**paired-qualification job passed** with no qualification errors; patched frequency
also passed. The overall workflow remains **failed** because six control trials
and the strict control-frequency job failed. Expected control failures are not
converted to passes, retried or skipped.

| Platform/test | Blocking control timeouts | Cooperative candidate timeouts |
|---|---:|---:|
| Windows arena | 2/50 (4%) | 0/50 |
| Windows rigs | 4/50 (8%) | 0/50 |
| Windows usable course | 0/50 | 0/50 |
| Linux arena | 0/50 | 0/50 |
| Linux rigs | 0/50 | 0/50 |
| Linux usable course | 0/50 | 0/50 |

The [complete qualification and batch receipts](physical-actor-timeouts-2026-10-23/same-host-pair.json)
retain build/runtime identities, raw-report hashes, all six timeout records,
CPU/core counts, fixture identity hashes and matching host/batch records. Each
host exposes two physical cores/four logical processors; CPU families include
AMD EPYC 7763/9V45 and Intel Xeon Platinum 8573C. All twenty variant reports
completed with empty input-drift lists. Alternating pair order and matching
hardware/fixtures passed the registered checker. Timeout phases were arena
`configure` twice and rigs `setup_complete` twice / `step` twice. The independent
watchdog captured at 30 seconds of idle and failed at 45 seconds of idle; the
ordinary 180-second case limit was retained.

A [new matching-PDB engine capture](physical-actor-timeouts-2026-10-23/same-host-control-dump.json)
from control Windows batch 0, rigs iteration 5, PID 7788, confirms the same
`join_deferred_bvh_optimize` → channel receive → parked worker. The main thread
waits in `LockLatch::wait_and_reset`; the other Rapier worker sleeps in Rayon.
Exact Microsoft images/PDBs and the current control's matching private PDB were
used without forced mismatched symbols. Unrelated unavailable system-module
warnings do not affect these attributed stacks. Raw output is retained locally
as `build/same-host-control-symbolized-stacks.txt`.

**Root cause and selected repair:** a Rayon worker blocks in the synchronous
deferred-BVH receive instead of helping work queued in its pool. The caller then
waits for that worker; the captures directly establish this blocking call and
idle-worker topology. The backport polls the receive while yielding to queued
Rayon work, preserves outside-pool receive behavior and still fails on a
disconnected producer. The deterministic two-worker control stalls with exit
124 within ten seconds on both OSes; the exact patched helper passes all three
checks. The precise scheduler race that originally stranded the task remains
unproven; this repair does not claim a general Rayon scheduler fix.

The paired application comparison, repeated matching captures and deterministic
progress regression support selecting the minimal backport for Windows/Linux
x86_64. Across the three campaigns, completed candidate trials total **750 with
zero failures/timeouts** (450 Windows, 300 Linux), retaining the first campaign's
Linux preflight exclusion and the second campaign's inconclusive control sample.
The [updated binary/input comparison](physical-actor-timeouts-2026-10-23/paired-windows-code-equivalence.json)
records all three sources: Windows code/data sections match, and entire PE bytes
match after excluding the explicitly listed timestamps/checksum and declared
debug payloads. Actual DLL/PDB hashes remain distinct. The Linux candidate
artifact is byte-identical in the complete second and third campaigns.

**Selected exact tested artifacts**, with no stripping or rebuild after stress:

| Platform | SHA-256 | Bytes |
|---|---|---:|
| Windows x86_64 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` | 9987072 |
| Linux x86_64 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` | 117275416 |

The [runtime lock](../../godot/third_party/rapier2d.lock.json) selects their new
per-platform manifests while preserving the original v0.35.2 release archive
and all other architecture/Web hashes. The immutable build-time candidate lock
is retained as a build input; subsequent selection is expressed in the runtime
lock rather than rewriting that historical status. Both artifacts use addon
commit `172c66f5a88bf1164c2b8cf2d775ed889edefd75`, rapier2d 0.35.1 with its verified
crate hash, original dependency versions and Rust 1.98.0. The MIT addon and
Apache-2.0 Rapier notices remain retained and the modification is identified.

| Documentation/checklist area | Disposition |
|---|---|
| Dependency/ADR/provenance | ADR-009, runtime lock, manifests, notices and runbook record the two desktop overrides; source-input or artifact drift fails repository and Windows preflight checks |
| Ownership/interfaces/invariants | Main-thread Godot/Rapier ownership, immutable native payloads and native cell authority unchanged; no C++ source or engine-facing interface changes |
| Configuration/capacity/user controls | No solver, worker-count, material, actor, capacity or user-control changes |
| Build/test tooling | Active consumers use selected hashes; complete stress scope and strict failures retained; validation-contract negatives reject stale patch/toolchain/engine/dependency identity and mismatched libraries |
| Routes/retrieval/status | Build guide, handover, roadmap, validation ledger, indexes and supplementary CI-HANG-01 expectations reconciled; frozen 32 questions preserved |
| Historical/contradictory claims | Prior failed/inconclusive/invalid-apparatus evidence retained; the runbook's stale unresolved-LFS wording is corrected against actual materialization evidence |

**Remaining at the publication checkpoint:** full applicable hosted regression,
Native and exact-head Documentation/provenance acceptance. PR #236 remains draft
through these checks. Their final source/run receipts are recorded in the PR so
that recording a check result does not change the checked source revision.

Local selection checks passed: **140 Python tests** (62 focused runner/stress/
identity tests, 14 validation contracts, six provider-policy tests and 58 existing
runtime-publication consumer tests), documentation metadata/links, historical M11
integrity (18 records/28 hashes), provider policy and whitespace. Frozen retrieval
is 32/32 hit@5, 21/32 hit@1, MRR 0.7953; supplementary is 116/116 hit@5, with
CI-HANG-01's canonical build guide at rank 2. The retrieved guide retains the
strict oracles, selected platform scope and separate final-gate qualifier. Raw
local logs/reports are under ignored `build/bvh-publication-checks`. Repository
materialization/provenance is checked again after committing the new LFS identity.

## Integration with independently advanced main

The repair/runtime selection checkpoint is `023fc13f1d5c0f66339a9737d52d685a06262077`.
Its exact-head Documentation/provenance run
[40059321942](https://github.com/techrote/cybersand/actions/runs/40059321942)
passed, and GDExtension run
[40059325026](https://github.com/techrote/cybersand/actions/runs/40059325026)
passed both builds and all four Linux shards/aggregate while the Windows full
suite was still running at this observation. Native run
[40059323590](https://github.com/techrote/cybersand/actions/runs/40059323590)
was still in progress. These runs retain their actual final outcomes separately.

Meanwhile, main advanced to `1002b9201006b572180a12cbc4c3b21fc234e8fa` with the
independently merged #215/#217/#226 stack and #237 status reconciliation. GitHub
reported a conflict in the shared supplementary retrieval fixture. Integrating
that existing main snapshot preserves all incoming LCB implementation, fixtures,
contracts and records unchanged. Explicit diff checks against main cover
`tools/lcb`, LCB Godot tests/fixtures and LCB/liquid policy documents; none carry
a timeout-branch modification. No LCB or MAT successor work is selected here.

The sole manual merge resolution combines both additive retrieval questions and
metadata: every question object from both parents is retained unchanged, giving
117 supplementary queries. Other shared documentation and the runner catalog
merge normally. Main's four new ordinary LCB validation cases increase discovery
to **125 Windows headless / 137 Linux cases**, including the same 12 Linux
rendered cases. Earlier 121/133 results retain their original source scope.

The selected Rapier artifact bytes and all four registered build inputs remain
unchanged; native C++/extension source is also unchanged. The integrated source
requires fresh exact-head full validation, kept separate from the completed
causal stress comparison. PR #236 remains draft through that validation, and its
current body records the resulting source/run receipts without altering the
checked revision.

Integrated local checks passed all 140 tooling tests again, current repository
provenance/materialization, provider policy, documentation and historical M11
integrity. The merged corpus has 110 documents; frozen retrieval remains 32/32
hit@5, 21/32 hit@1, MRR 0.7953, while all 117 supplementary questions hit@5
(MRR 0.8806). The source diff against the incoming main has no native, LCB or MAT
implementation changes. The integration commit is the recoverable checkpoint
for fresh full-scope hosted validation; earlier running validations can be
superseded by that new source head, with cancellation recorded rather than
counted as a pass or silently retried.
