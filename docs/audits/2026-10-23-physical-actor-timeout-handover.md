---
title: Physical actor timeout investigation handover
status: Current
document-kind: audit
scope: Paused investigation checkpoint, captured hosted failures and unvalidated Rapier candidate
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-physical-actor-timeouts.md, ../operations/cybersand-codex-development-handover.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# Physical actor timeout investigation handover

## Stop state and recoverable checkpoint

The owner requested a repository handover and a break on 2026-10-23. Investigation
is paused at this record; no further experiments or monitoring automation are
scheduled. [PR #236](https://github.com/techrote/cybersand/pull/236) remains **draft**.
Diagnostics and a fast external watchdog are implemented. **The root cause is not
confirmed, the candidate repair is not compiled, and no runtime physics repair
has been published.** Do not promote this PR on the strength of ordinary suite
passes.

- Source base: fetched main `1f9336388f11be39abaae340a781a5eef52115d4`.
- Branch: `codex/physical-actor-timeouts`.
- Worktree: `C:/Users/_/.codex/worktrees/physical-actor-hangs/khybersand`.
- Last implementation/runtime-tested checkpoint:
  `c01c11e7e1ac85a5a81ad92c52516ac5fc8c26b0`. The subsequent commit containing
  this handover preserves the text-only candidate and curated reports. Resolve
  its identity with `git log -1 --format=%H -- docs/audits/2026-10-23-physical-actor-timeout-handover.md`.
- The original dirty `C:/khybersand`, branch `mat/material-fidelity-pass-2` at
  `620826f`, remains untouched. LCB #215/#217/#226 and MAT-003PREPASS are outside
  scope. No native source, dependency version or committed runtime binary changed.

Read the [investigation audit](2026-10-23-physical-actor-timeouts.md) and
[runner/stress guide](../operations/local-build-and-validation.md#physical-actor-timeout-investigation)
before resuming. The release guide still requires exact-head evidence after any
eventual repair and ready-for-review transition.

## Completed hosted experiments

Observed complete at **2026-10-23 20:22:47 UTC**. Every campaign below contains
50 independent trials per test per OS (300 experiments), without retries or skips.
These campaigns precede any root-cause repair. Different watchdog termination
times mean the two samples are not a controlled repair comparison.

| Campaign / source | Windows arena | Windows rigs | Windows course | Linux each test |
|---|---:|---:|---:|---:|
| [40009601466](https://github.com/techrote/cybersand/actions/runs/40009601466), `e7580113202b5e1897a95bd1708c11741308e2d8` | 1/50 timeout (2%) | 6/50 (12%) | 1/50 (2%) | 0/50 |
| [40014516069](https://github.com/techrote/cybersand/actions/runs/40014516069), `c01c11e7e1ac85a5a81ad92c52516ac5fc8c26b0` | 3/50 timeout (6%) | 8/50 (16%) | 0/50 | 0/50 |

Both campaigns correctly concluded **failure**. All remaining trials passed.
Committed copies of the hosted aggregate artifacts are
[baseline](physical-actor-timeouts-2026-10-23/hosted-baseline-frequency.json) and
[watchdog capture](physical-actor-timeouts-2026-10-23/hosted-watchdog-frequency.json).
The latter includes native/Rapier/Godot runtime identities; the former aggregate
predates that schema enhancement, so use its underlying batch manifests for
runtime provenance. Hosted artifacts have 30-day retention; preserve raw captures
before expiration if the investigation continues later.

Baseline markers ended in `step` for all eight failures. Main/engine CPU stopped
advancing after about 6-24 seconds of fixture progress; snapshots at 150 seconds
showed waiting threads. Baseline minidumps failed because of a PowerShell `$args`
pipeline-scope bug. That capture bug was fixed and locally verified before the
second campaign.

The second campaign uses an independent Python watchdog: snapshot at 30 idle
seconds, fail at 45 idle seconds, retaining the 180-second outer deadline.
It captured valid wrapper **and engine** minidumps. Its last markers were arena
`configure` (1), arena `step` (2), rigs `step` (7), rigs `setup_complete` (1).
Markers batch every 120 steps: the last marker does not prove the stalled call
was inside the named operation. A subsequent step may block before the next marker.

| Other completed gate | Source | Result and limit |
|---|---|---|
| [Documentation 40013567728](https://github.com/techrote/cybersand/actions/runs/40013567728) | `c01c11e` | Success |
| [Native 40013633624](https://github.com/techrote/cybersand/actions/runs/40013633624) | `c01c11e` | Success; manual readiness-scope job deliberately skipped |
| [GDExtension 40013637471](https://github.com/techrote/cybersand/actions/runs/40013637471) | `c01c11e` | Success: Windows build/headless, Linux build/four shards/aggregate; optional serial-equivalence scope not requested |

These attest the stated source, not the subsequent handover commit or a future
repair. Full-suite success and repeated stress failure coexist at the same head.
All previously dispatched runs are now complete; none were cancelled for the break.

## Local evidence and implemented guard

The earlier audit records 150 instrumented local Windows passes and a full local
Windows baseline of 121/121 applicable headless tests at `77c8b0e`. The separate
[uninstrumented local comparison](physical-actor-timeouts-2026-10-23/uninstrumented-local-summary.json)
also passed 50/50 per test using the original fixture bytes from main. Five
isolated project copies each ran ten trials with two-logical-CPU process affinity
on a Ryzen 5 5600X / Windows 11 host. Neither local experiment reproduced the
hosted hang, establishes a fix, or overrides the hosted failures.

The guard is runner-side so a frozen Godot main loop cannot disable it. Marker
changes renew liveness; unrelated stdout cannot. Startup and quit stalls are
bounded. Cases still fail as timeouts. Capture failure cannot turn a failure into
a pass. The shared runner retains ordinary 180-second deadlines and existing
import/profile bounds. There are no added retries, skips or flaky annotations.
Production physics settings and assertions remain unchanged.

Before this handover, 48 focused Python runner/monitor/summary tests and six
provider-policy tests passed. Documentation, M11 historical consistency,
materialized repository provenance, CI provider policy, frozen and supplementary
retrieval evaluation, and whitespace checks passed at the implementation
checkpoint. The frozen retrieval set retained 32/32 hit@5, 21/32 hit@1, MRR .7953;
the new supplementary `CI-HANG-01` route ranked its canonical guide second.

At this handover checkpoint, `check_docs`, `check_m11_consistency`,
`check_repository --require-materialized`, `check_ci_provider_policy`, both
retrieval evaluations and `git diff --check` passed again. Frozen metrics remain
unchanged; supplementary retrieval is 116/116 hit@5 and `CI-HANG-01` now ranks
its canonical guide first. This is documentation/provenance validation, not
execution of the uncompiled candidate or final repaired runtime acceptance.

## Root-cause candidate, not accepted diagnosis

Primary upstream reports describe a closely matching Rapier parallel deferred-BVH
join hang: [Rapier #1008](https://github.com/dimforge/rapier/issues/1008) and
[Godot Rapier #640](https://github.com/appsinacup/godot-rapier-physics/issues/640).
Our addon v0.35.2 pins rapier2d **0.35.1**. Its pipeline spawns deferred BVH work
into Rayon, then waits with a blocking channel receive from inside the pool.
That is a plausible worker-starvation point. The reports and waiting thread
snapshots do **not** establish that our failures share this cause, or prove a
lost wakeup.

Text-only proposed work is preserved in
[the candidate patch](../../third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch)
and [candidate build inputs](../../third_party/rapier-bvh-build.lock.json).
Neither is consumed by the build or active runtime. The patch proposes helping
queued Rayon work while awaiting the same deferred result, retaining a blocking
receive outside a pool. It includes a proposed deterministic two-worker
starvation regression, outside-pool receive and disconnected-producer checks.
**None has been compiled or run.** Rust version/features/debug-symbol overrides
in that JSON are proposed build inputs, not an accepted new dependency policy.
Review API compatibility, semantics, idle CPU behavior and test determinism before
using it. Do not mistake the candidate comments for a confirmed root-cause claim.

Pinned upstream checkout in ignored `build/rapier-source` is addon tag v0.35.2,
commit `172c66f5a88bf1164c2b8cf2d775ed889edefd75`. The extracted verified crate is
under `build/rust-crates/rapier2d-0.35.1`; its SHA-256 is recorded in the candidate
manifest. No build-producer workflow or patched runtime has been created.

## Captures, tooling and recovery details

Ignored local evidence resides in this managed worktree; it is deliberately not
committed as logs, dumps, toolchains or generated imports:

- `build/hosted-baseline/windows-0` through `windows-4`: first campaign batches.
- `build/hosted-capture/windows-0` and `windows-3`: downloaded second-campaign
  batches. Other batches remain downloadable from run 40014516069.
- `build/actor-engine-stacks.txt`, `build/actor-raw-stacks.txt`: offline inspection
  of batch 3 arena iteration 1, engine **1796.dmp**, wrapper **4856.dmp**.
  Select engine PID from `process.txt`; the larger dump may be the wrapper.
- `build/dump_reader.cpp` and `.exe`: small offline reader using the existing
  Windows `System32/dbgeng.dll`. Built with the existing w64devkit g++ using
  `-std=c++20 -O2 -static -lole32`. Existing debugger library installation was
  sufficient; no SDK installation is required to read the dump.
- `build/actor-hang-stacks.txt` is the initially inspected wrapper, not engine
  evidence. `build/actor-reconstructed-main.txt` contains experimental register
  reconstruction and must not be treated as a reliable unwind.
- `build/local-batch-*`, `local-project-*`, `local_campaign.py` and corresponding
  `original-*` / `original_campaign.py` retain local trials. The full Windows gate
  is under `build/full-windows-baseline-head`; guard smoke under `build/watchdog-smoke`.

Current stack unwinding is limited by Server 2022 system-image/symbol mismatch on
the local Windows 11 host and stripped official Rapier/Godot DLLs. Raw stack memory
and module/thread metadata are present, but a trustworthy source-level Rapier
frame is still missing. A Windows SDK layout bootstrapper attempt was rejected
by automatic tool policy with reason "blocked by policy"; it was not executed.
The existing DbgEng reader was the successful alternative. Do not repeat that
rejected bootstrapper action. Matching system symbols/images or a symbolized
same-source control build may resolve the unwind limitation.

Local Godot is `C:/Godot47/Godot_v4.7-stable_win64_console.exe`, version
`4.7.stable.official.5b4e0cb0f`, hash-verified against the official archive.
The native Windows DLL remains `e6d9ec7d0847287c4c6b1acaffd52dc2807fe43e9dccfc36123ffa117fb6045f`;
Rapier remains `4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`.
Generated `.gd.uid` files and four import-descriptor line-ending deltas remain
local only. Do not stage them. Documentation checks use pinned companion support
files staged beside this managed source checkout from companion
`6a58311982941b75f46e22109a0829e5acb83c7e`; these are outside this source repository.

## Resume sequence and outstanding acceptance

1. Preserve remaining hosted artifacts, inspect valid engine dumps and establish
   the actual blocking call/worker topology. Distinguish Rapier joins, native
   pool destruction, session waits and engine quit before choosing a repair.
2. Review and compile the candidate, if evidence supports it. Run its deterministic
   regression against both original blocking control and cooperative candidate.
   Build control/patched addons from identical pinned inputs with useful symbols;
   keep parallel solver, physics values and all other dependency inputs stable.
3. Run paired hosted Windows/Linux stress campaigns, at least 50 trials per
   suspect test per OS. A control reproduction and zero patched timeouts are
   required evidence; guard-only fast failure is not a repair.
4. If accepted, publish source-matched runtime LFS artifacts and complete patch,
   license/hash/provenance and platform qualifiers. Preserve historical hashes.
   Do not raise deadlines above 240 seconds, introduce retries/skips, label tests
   flaky, or change native/default physics beyond the causal repair.
5. Repeat the full Godot regression set and all repository/documentation/provider/
   retrieval checks, complete the dated before/after audit, then move the draft
   PR to ready only with exact-head Documentation/provenance, Native and applicable
   GDExtension evidence. There is no zero-timeout repaired campaign yet.

The existing registered GDExtension manual dispatch input
`physical_actor_stress=true` invokes the branch-local stress workflow. Direct
dispatch of a newly added workflow returned 404 because it was not registered on
main. Keep literal GitHub-hosted runner labels and run the provider-policy checker
for any workflow changes. No owner-approved provider migration exists.
