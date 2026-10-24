---
title: Issue 234 physical regression hang repair and qualification
status: Current
document-kind: evidence
scope: Native stack readback, cooperative deferred-BVH join repair, independent watchdogs and exact-source 600-attempt acceptance
canonical-for: [issue-234-physical-hang-repair-evidence]
last-reviewed: 2026-10-24
related-documents: [2026-10-24-issue-233-physical-regression-timeouts.md, 2026-10-24-physical-actor-bvh-validation.md, ../operations/testing-validation-and-replay.md, ../decisions/ADR-009-rapier-2d-rigid-body-backend.md]
---

# Issue #234 physical regression hang repair — 2026-10-24

## Intake, ownership and retained evidence

**Qualification pending at this implementation checkpoint.** The owner requested
native stacks, identification/repair of the hang, a bounded watchdog and the full
600-attempt hosted qualification without retries or increasing the 180-second
physical-case timeout. Issue #234 remains open until that deliverable is admitted.

The untouched primary source root `C:/khybersand` remains on
`mat/material-fidelity-pass-2`, HEAD `620826f59fbe248f93a45c45e786a7297f2e5288`,
with the owner's unrelated native/material delta and local DLL. The #233 evidence
checkout at `C:/Users/_/.codex/worktrees/issue233-diagnostics/khybersand` remains
at evidence merge `3e9f0e6dcbfdb9c122c8c555dac43e7b4d926e5f`; its raw cache is
preserved. The new managed repair checkout is
`C:/Users/_/.codex/worktrees/issue234-hang/khybersand`.

Current `main` at intake is `03785c3dcaa5c82df000eeca1471bd6ec698be00`, after
independent LCB PR #245. Its native runtime and source identity are newer than
#233's control. Physical fixtures, bridge and original Rapier bytes did not
change in that main advance. No native C++/extension, LCB implementation or
material behavior is changed by this repair integration. Active LCB publication
consumers only learn the new selected Rapier checksums; the retired branch-scoped
publication workflows/helpers from PR #242 remain deleted.

Readback discovered existing, unmerged [PR #236](https://github.com/techrote/cybersand/pull/236),
head `8ff66b7cbc9e7bb71d84ea16fc5974ce2241b68a`, on
`codex/physical-actor-timeouts`. It already contains captured native evidence,
the cooperative receive patch and qualified Windows/Linux desktop artifacts.
It was open, rather than rejected or merged. This task continues that PR from
local `codex/issue234-hang`, integrating current main and #233's admitted runner,
markers and exhaustive campaign. The old PR worktree is read-only evidence.
Earlier PR #236 CI and 300-attempt stress results retain their own source scope;
they cannot admit this integrated head or replace the required 600 attempts.

#233's [source-bound baseline](2026-10-24-issue-233-physical-regression-timeouts.md)
remains 600 attempts at `4348516aba4c8e7036370d73afc14e86a19ea6a2`:
589 passes, eleven Windows roster timeouts, zero other/missing attempts and
twenty passing preflights. All historical failures and reruns remain unchanged.
Those eleven had no native stack; their common phase/binary does not alone prove
that every one had the mechanism captured below.

## Native blocking path and repair

The original valid engine dump from hosted run `40014516069`, Windows batch 3,
arena iteration 1, PID 1796, has SHA-256
`9c645a918de634d76fa1ebf41018c6aa84bb312fa8f01fcf1ce7ade7620ef7b6`.
Fresh bounded offline readback independently unwound it with system images
matching the captured timestamp, image size and CodeView identity and the exact
official Rapier DLL, not a rebuilt library's incompatible PDB. A second unwind
with an empty symbol directory and no PDBs reproduces all nineteen distinct
Rapier frame RVAs exactly. System-image PE checksums and one public system PDB's
age differ from the capture; the inventory exposes these values. Unsupported
nearest-export OS labels are not used as named causal frames. The retained
official Windows DLL is
`4e26ffa78ec2aaff434c4a70cd2ec85288b10ba5237912c35f204cb1e6ed2180`,
the same bytes used by #233. Exact official static archive SHA-256 is
`c4b69859e1792a245787300b48ad434faa7240882c0d3645441469073626a155`.

| Thread | Actual captured blocking path |
|---|---|
| Main 2724 | OS wait → byte-matched `std` condvar wait (`0x77b7b3`) → Rayon `LockLatch::wait_and_reset` (`0x77097e`) → `PhysicsWorld::step` (`0x2034d0`) |
| Worker 4620 | OS wait → `std::thread::Thread::park` (`0x77d0d1`) → channel `recv` (`0x673358`) → `PhysicsPipeline::join_deferred_bvh_optimize` (`0x6ac57d`) → `step_inner` (`0x68ade7`) → Rayon job execution (`0x2e2669`) |
| Other Rapier worker | Parked in the scheduler; no active deferred producer observed |

COFF attribution compares all function-section bytes except explicitly listed
relocation fields against the official DLL. Unverified frames retain their
addresses and are not assigned guessed names. Prior additional real engine dumps
and the matching-PDB same-host control capture remain in the
[earlier validation record](2026-10-24-physical-actor-bvh-validation.md).
The portable [fresh stack readback](issue-234/official-stack-readback.json)
retains the exact dump/library/archive, reader/mapper and output hashes, commands,
verified frames and excluded incomplete parser attempt. Its captured native
runtime is the historical `2f7f65bf…` build, not #233's or current-main's native
binary. The captured cumulative `steps` marker is not a roster physical tick.
The active wait is within Rapier's deferred-BVH receive under a Rayon install
latch. This establishes the blocking site, not the exact lost-wakeup or scheduler
race, and not the mechanism of every uninstrumented historical event.

The scoped backport replaces the blocking receive inside a Rayon worker with
`try_recv` and `rayon::yield_now`, allowing that worker to execute queued work
while waiting. An idle worker yields its OS time slice. Outside a Rayon pool,
the original blocking receive remains; a disconnected producer still fails.
No pool-size, solver, physics parameter, actuation/assertion or cellular rule
change is used to conceal the stall. The deterministic two-worker regression
occupies the other worker and queues the producer: blocking control stalls at
the ten-second test guard, while the cooperative helper completes and preserves
the received value. Separate tests retain outside-pool and disconnected behavior.

The immutable [build lock](../../third_party/rapier-bvh-build.lock.json),
[patch](../../third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch) and
per-platform provenance retain addon commit
`172c66f5a88bf1164c2b8cf2d775ed889edefd75`, crate 0.35.1, Rust 1.98.0 and
the original dependency features. The build-lock's historical candidate label
is preserved as a hashed input; selected desktop overrides live in the runtime
lock. Other architectures and Web retain the original artifacts.

| Selected runtime | SHA-256 / source |
|---|---|
| Windows Rapier | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows native | `813bfbb42f0bc9c21488aca44df2a3477e47db594b3521885ea2fed39ea07f0a` |
| Retained Linux native | `3bfe1679c6d0201203fcf99b6f53d7f50875a530611776787131d7dc1d5098c2` |
| Retained native build/source | `349d59359a45ebbe4f92af879945b43b591d412a` |
| Godot | `4.7.stable.official.5b4e0cb0f` |

The retained native source-input ledgers match the integrated native source;
no native behavior is edited. Fresh Linux CI/stress builds retain their actual
output hashes separately, rather than relabelling a retained artifact.

## Independent bounded failure guards

The three suspect fixtures retain every #233 `REGRESSION_PROGRESS` marker and
their default physical workload. Coarse sequence heartbeats are added through
the shared fixture helper; physical/world/bridge call counts remain unchanged.

The independent Python process monitor captures native evidence after 30 seconds
without meaningful main-thread progress and fails at 45 seconds idle. A fixture
message does not reset the clock merely by changing its timestamp. The ordinary
outer per-case deadline remains 180 seconds. This monitor runs outside Godot's
blocked main thread and VM; it latches timeout failure, captures before kill and
cleans the process tree even when diagnostics fail. Snapshot commands are
file-backed, capped and limited to twelve seconds; the separate capture process
has a thirty-second total bound and explicit completed/incomplete state.
Windows uses system DbgHelp minidumps plus actual process/thread data. Linux
retains process/session/thread wait channels, explicit proc read errors and a
bounded GDB attempt/refusal. Installed LLDB smoke probes captured stacks but
unexpectedly ended the attached target on detach, so live LLDB is not adopted.

An internal fixture `RefCounted` observer uses a separate Godot `Thread`, monotonic
time and a private short-held mutex. Its 120-second whole-fixture deadline emits
a bounded sticky `ERROR: REGRESSION_WATCHDOG` with copied context. It calls no
SceneTree/World/Rapier APIs and never kills the process before evidence capture.
Completion racing expiry remains failure. Stop polling is bounded, and a thread
is joined only after it exits. Initialization before arming and engine quit after
disarming remain under the independent outer monitor. The observer itself does
not forcibly interrupt a permanently blocked native call.

Actual pinned-Godot tests demonstrate the observer firing at 53 ms while main
remained synchronously blocked until 1,000 ms, then retaining nonzero failure and
joining. The healthy probe passes. A separate integrated blocked-main monitor
probe used **test-only** 3/10-second capture/idle limits: timeout at 10.286 s,
0.711 s diagnostics/cleanup, capture completed in 1.527 s and obtained both wrapper
and engine minidumps before kill. Both processes were absent afterward. These are
apparatus regressions, not physical Rapier reproductions. CI runs the real
internal-observer probes on both pinned Windows and Linux Godot.

## Acceptance-tooling review corrections

Three outstanding P2 comments on PR #236 are corrected with focused negatives:

1. The legacy paired reducer requires the declared same-host protocol for every
   report, matching host/hardware/fixture/order, and the final input-verification
   receipt. Omitting every protocol field can no longer bypass pairing checks.
2. The same-host runner retains `completed=false` until preflights and final
   fixture/runtime hashing finish. A crash or drift after the thirtieth case
   preserves the trial inventory without publishing accepted completion.
3. The legacy 300-attempt reducer requires five distinct batch identities per OS;
   a duplicate file cannot replace a missing batch while preserving totals.

Legacy phase reduction also accepts both admitted marker formats without calling
dictionary methods on #233's text marker. These fixes do not rewrite old reports
or turn old failed/inconclusive/invalid-apparatus cohorts into new passes.
Independent follow-up review also requires valid run/attempt identities, one
cohort across both variants, CLI binding to declared source/run/attempt and a
successful preflight receipt. The original mixed-run and failed-preflight
counterexamples now fail while valid baseline fixtures pass. New strict receipt
requirements are not retroactively manufactured in historical reports.
The fresh acceptance uses #233's separate exhaustive 600-attempt reducer, binding
every batch to exact source, run ID, attempt and runtime identities.

## Local integration checks

All **137 focused Python tests** passed: runner/sharding 25, Windows runner 16,
process monitor 7, native diagnostics 7, progress watchdog 8, #233 timeout
diagnostics 5, exhaustive stress contracts 12, timing history 8, legacy stress
10, paired qualification 10, same-host runner 4, candidate identity 5, validation
contracts 14 and provider-policy tests 6. The actual-Godot internal observer and
blocked-main capture probes above also passed. The materialized repository check
at the pre-commit merge delta reports only the two intentionally changed Rapier
LFS identities relative to old HEAD; it must pass against the committed tree
before admission. All eighteen payloads are materialized.

Documentation/link metadata, provider policy, M11 historical integrity
(18 records/28 hashes) and whitespace checks passed. Frozen lexical retrieval
remains hit@1 21/32 and hit@5 32/32, with MRR 0.7937 (previous #233 checkpoint
0.7953); the unchanged current-main questions plus additive CI-HANG-01 yield
96/122 hit@1, 122/122 hit@5 and MRR 0.8753. These are lexical development metrics,
not a semantic retrieval-quality claim. Current LCB01 expected-fact updates are
preserved rather than overwritten by the older PR branch.

The separate unmodified local control at source `3e9f0e6…`, official Rapier
`4e26ffa7…` and native `b13805bf…` passed 30 physical attempts plus one import:
arena median/p95/max 14.7835/16.701/16.701 s, rigs 20.9365/22.722/22.722 s and
course 13.8515/15.943/15.943 s, each 0/10 timeouts. This is a negative local
reproduction, not the hosted acceptance campaign. The local six-worker Rapier
pool differs from hosted topology. Source inspection and a disposable process
probe show that narrowing affinity does not change the addon's physical-core
count; no imaginary project-setting or two-worker override was used.

## Registered final qualification and documentation checklist

The final campaign remains five batches × ten repeats × three default suspect
fixtures × Windows/Linux × serial/three-process parallel: **600 physical attempts
plus 20 preflights**. It must run from the merged/default-branch
`physical-timeout-stress.yml` at one immutable admitted repair commit, with no
automatic retries, skipped cases, raised 180-second limit or successful-batch
combination across incomplete campaigns. Every failure remains retained. Exact
current-head ordinary Documentation/provenance/provider, Native, Windows Godot,
Linux build and all Linux shards are prerequisites to merge.

Canonical ownership: ADR-009/runtime locks/provenance/notices own the scoped
dependency selection; the test guide owns deadline/failure semantics; build guide
owns commands/artifacts; roadmap/handover/index route to this evidence. The #233
baseline, prior #236 captured/paired evidence and this final acceptance remain
separate dated scopes. Native authority/lifetimes, public interfaces, capacity,
gameplay controls and unrelated LCB/MAT/GEN behavior are unchanged. Current-main
retrieval objects, including its updated LCB expectations, are preserved; the
prior CI-HANG-01 route is additive. Frozen retrieval questions remain unchanged.

**Pending:** final local checks, committed integration identity, exact-head hosted
admission, repair merge identity, complete fresh campaign and independent raw
readback, all twelve timing/frequency strata, final limitations and issue closure.
