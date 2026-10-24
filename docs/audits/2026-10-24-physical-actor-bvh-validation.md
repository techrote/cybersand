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
