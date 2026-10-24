---
title: Physical actor deferred BVH blocking-call confirmation and paired validation
status: Current
document-kind: audit
scope: Windows dump attribution and paired Rapier control/candidate experiments; no published runtime repair yet
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
remain untouched. This experiment does not publish a runtime or change native
physics, solver parameters, pool size, default selected binaries or assertions.
The PR stays draft until the repair is proven.

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
