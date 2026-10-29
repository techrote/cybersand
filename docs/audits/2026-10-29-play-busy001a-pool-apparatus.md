---
title: PLAY-BUSY-001A bounded native-pool job-gate apparatus
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Test-only pool/gate mechanics; not World-phase or desktop busy-shutdown acceptance
related-documents: [../architecture/simulation-tick-and-threading.md, ../architecture/data-ownership-and-lifetimes.md, ../systems/player-control-playground.md, ../operations/github-development-and-release.md]
---

# PLAY-BUSY-001A — executable gate apparatus

## Source and strict boundary

Base: accepted main `aac0feb65e2268b74975892ce1df81e04e1a7e40`.
This change adds test-only files and one read-only, bounded GitHub workflow.
No existing native source, runtime/LFS, solver policy/default, production
worker/Main, specialist fixture or release request changes.

The runner extracts the **literal PersistentWorkerPool class** from current
`native/src/world.cpp` into a generated test header, without editing its body.
The independently inspected base file has Git blob
`6987e9d05564cb11294d7704514df2f811a26c48`; the selected class, including final
newline and LF-normalized checkout endings, has SHA-256
`6e0b106df73926d94db07ce5c4fea1764f4cc1d883d6a0d1e98c242c6d68a25d` (3,902 bytes).
A missing/duplicate marker, truncation or changed class refuses execution.
The generated namespace/include wrapper is disclosed and hashed.
The class is not a rewritten pool model; the *tasks and stop request are tests*.

**Not exercised:** World::simulation_tick dispatch, its scheduling phases,
material kernels, actual CyberSimulationWorker stop fence, Godot Main input or
render progress, Rapier lifetime, host resource retirement, or a shipped runtime.
The result explicitly sets these host-scope claims false. This preparation
must not be used to close #269/#270 or replace actual busy-host qualification.

## Gate contract and actual local tests

The bounded gate has fixed 64-task/thread storage, epoch/phase/generation
identity, distinct actual callback thread observations, a steady-clock deadline
(up to five seconds), one-shot release and retained timeout disposition.
It owns no World/pool/Godot/Rapier objects and never uses their mutexes.
Wrong/stale tickets cannot release a current phase. A claim cannot complete
while still waiting; rearm requires all expected tasks complete. Duplicate
claims/completions, unsupported one-task/one-worker overlap and invalid bounds
are refused. The caller must retain the gate/context until all dispatches join.

Eight positive dispatches alternate two/four real pool threads, each dispatching
eight tasks. At least two callbacks must be observed held before a **test-only**
stop marker; the dispatch must still be outstanding. A separate helper releases
only the gate, then tasks finish, dispatch returns, actual pool destruction
joins its threads, the dispatcher joins, and the test context retires. Ordered
claim/test-stop/release/drain sequence numbers and real participation/checksum
are required. Ordinary one/four-worker unblocked controls preserve every task.
An intentional no-helper case must expire and remain marked timed_out; it is a
negative safety-control result, never a positive shutdown observation.

Local Linux runs completed **169 assertions / zero failures each** under
GCC ordinary, Clang ASan+UBSan and GCC TSan. ASan used detect_leaks=1 and
halt_on_error=1; UBSan/TSan used halt_on_error=1. These are three executions of
one 169-assertion apparatus, not 507 unique tests or whole-engine sanitizer
qualification. Eight extraction/refusal Python tests also passed. Exact compiler
versions, executable hashes and original logs are in the retained session bundle.

Local runs used an explicitly declared source-excerpt mode: the freshly read
class was materialized locally and checked against the class pin. They did not
use a complete local repository clone or compile the full World translation
unit. Hosted mode forbids excerpt mode, requires explicit exact Git HEAD,
checks clean relevant inputs, and emits source tree/full World blob and SHA-256
alongside generated-header, driver, gate, compiler, binary and log hashes.
The hosted Windows and Linux outcomes are **pending, not assumed** here.

## Integration still required

After this apparatus is reviewed, integrate the gate at a real selected World
phase through a test-only owner-controlled hook, with immutable phase/epoch/job
receipts. Prove the actual Main callback/input/presentation paths progress while
at least two real phase jobs remain held; then enter the **production** stop
fence before helper release and prove all required owners retire in legal order.
Run ordinary unblocked controls and real Windows/Linux Godot with source-matched
native builds; preserve all failures and coordinate the separate runtime
publication lane. The gate must never inspect or mutate a live World from Main.

The existing #290/#295/#298 native-copy/publication work is untouched.
Current pool source extraction does not validate a future integration patch,
replace native/Godot matrices, claim physical-device/focus or human feel, or
relax the open release gates. The workflow compiles only this short apparatus,
with read-only permissions, no LFS materialization, no publication and no retry.
