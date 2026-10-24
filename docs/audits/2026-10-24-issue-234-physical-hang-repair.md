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

**Repair admitted; registered qualification complete.** The owner requested
native stacks, identification/repair of the hang, a bounded watchdog and the full
600-attempt hosted qualification without retries or increasing the 180-second
physical-case timeout. PR #236 is merged after exact-head ordinary admission.
The complete campaign passed independent readback. Issue disposition follows
admission of this final evidence update; no issue was closed by the repair merge.

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
3. The legacy 300-attempt producer declares explicit JSON host/batch/variant and
   the reducer requires five distinct batches per OS, matching artifact paths and
   the expected variant. Copying batch zero over batch four remains rejected even
   when apparent outcome totals are 50/50. Filename counts alone are insufficient.

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
Historical log fallback also recognizes the new typed watchdog timeout line;
it cannot infer that a truncated 45-second idle failure passed or was a measured
180-second execution. JSON measured timing remains preferred.

## Local integration checks

The final **143 focused Python tests** passed: runner/sharding 25, Windows runner 16,
process monitor 7, native diagnostics 7, progress watchdog 8, #233 timeout
diagnostics 5, exhaustive stress contracts 12, timing history 9, legacy stress
13, paired qualification 12, same-host runner 4, candidate identity 5, validation
contracts 14 and provider-policy tests 6. The actual-Godot internal observer and
blocked-main capture probes above also passed. The materialized repository check
passed against the committed repair tree, with all eighteen payloads materialized.
Its earlier pre-commit check reported the two intentionally changed Rapier LFS
identities relative to old HEAD; that intermediate mismatch was not admission.

The initial integrated checkpoint is `597e5b5f865cb20ba512a8d64b151c8971d945fd`;
its initial focused suite contained 137 passing checks. Its exact-head
Documentation/provenance run `40124313363` passed; Windows import
and all three default physical suspects passed locally with zero tested-input
drift (5.598 / 13.057 / 18.984 / 11.578 s). Final explicit batch/variant review
required a follow-up revision. Ready-event Native `40124497117`, Godot
`40124497247` and Water `40124497148` were cancelled as superseded; no cancellation
or draft skip is accepted as final admission. Their original records remain.
The follow-up focused suites total **143 tests**, adding explicit-scope negatives
and typed-watchdog historical timing coverage. Fresh exact-head hosted gates
remain required after that revision.

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

## Exact-head ordinary admission and repair merge

Final PR #236 head is `330ded5aa0937b4a46ea0b5f270583a8e0375931`.
The current-main parent remained `03785c3dcaa5c82df000eeca1471bd6ec698be00`.
GitHub executed synthetic checkout `bb84068378765e3874840e19507666c6a7a1e5df`,
whose parents are those main/head commits and whose tree
`873db3c3e75c8a4d60bc09e05316aa99e9143f05` equals the PR head tree.
Local and REST comparisons against actual main agree on 81 changed files.
Cached PR metadata still reported an older base and 169 files; actual merge
parents, source receipts and tree identity establish the tested result.

| Applicable ordinary gate | Exact-head run | Result |
|---|---|---|
| Documentation/provenance/provider | [40125121759](https://github.com/techrote/cybersand/actions/runs/40125121759), ready-event [40125433656](https://github.com/techrote/cybersand/actions/runs/40125433656) | Passed; explicit hosted-provider policy and six policy tests |
| Native | [40125433657](https://github.com/techrote/cybersand/actions/runs/40125433657) | Passed; 107/107 normal, 107/107 ASan/UBSan, 107/107 TSan |
| GDExtension/Godot | [40125433675](https://github.com/techrote/cybersand/actions/runs/40125433675), attempt 1 | Both builds, Windows, all four Linux shards, aggregate and timing gates passed |
| Scoped Water apparatus | [40125433654](https://github.com/techrote/cybersand/actions/runs/40125433654) | Passed; 120/120 apparatus outcomes |

The independently read full Native log also confirms procedural-generation and
soliding regressions/sanitizers, the shared-library build and 120-tick benchmark.
No failed-test record, sanitizer finding or unexpected nonzero job exit was found.
Its SHA-256 is `bf9f4a9aba978b6b89f422c4926048636c57b2341bba59f9eef7085a833f87de`.
The retained physics-CLI artifact contains 154 invocations, including 48 expected
invalid-input exits, with all 308 stream hashes verified. Expected invalid inputs
remain negative controls rather than physical-test failures or retries.

| Ordinary Godot scope | Cases | Imports | Pass/timeout/other |
|---|---:|---:|---|
| Windows headless | 128 | 1 | 129/0/0 process records |
| Linux shards 0/1/2/3 | 34/35/36/35 = 140 | 4 | 144/0/0 process records |

All 273 ordinary process records passed; Linux ran all twelve rendered fixtures.
Windows retained-log hashes match its execution receipt, with empty final source
drift. Linux native was freshly built at the synthetic checkout and has actual
SHA-256 `3bfe1679c6d0201203fcf99b6f53d7f50875a530611776787131d7dc1d5098c2`;
the native and Rapier bytes match the published build artifact. The selected
Windows/Linux Rapier, Windows retained native and pinned Godot identities are
listed above. These are distinct source and build identities, not a claim that
the retained Windows DLL was rebuilt at this PR head.

Actual hosted internal-watchdog probes observed expiry at 55 ms on Windows and
50 ms on Linux while main remained blocked until 1,000 ms. Both checked sticky
failure and joining. Their expected negative child results are separate from the
273 passing ordinary process records and from physical stress sample counts.

The independent ordinary reader reproduces all 45 physical-family observations
and hosted distribution rows exactly: Linux 23, Windows 22, all passed. Each
ordinary suspect stratum has N=1, so median/p95/maximum are equal:

| OS | Arena (s) | Rigs (s) | Usable course (s) | Timeout frequency per suspect |
|---|---:|---:|---:|---|
| Windows | 19.615 | 29.249 | 17.489 | 0/1 |
| Linux | 16.644 | 13.171 | 16.744 | 0/1 |

Every suspect retained the 180-second case limit and completed its original
teardown marker and structured quit heartbeat. The ordinary observations remain
separate from the stress denominator. Curated ordinary receipts and timing
records live in [issue-234](issue-234/ordinary-admission.json).

[Final admission comment](https://github.com/techrote/cybersand/pull/236#issuecomment-6389079361)
records the exact checks and independent readback. Normal merge policy admitted
PR #236 as `13b8e631f3e8fbaa2176ed41afc02c434b11e558`, with the same parents/tree
as the tested synthetic checkout. All three P2 review threads were resolved.
This merge deliberately left #234/#232 open for the registered qualification.

## Registered final qualification and documentation checklist

The final campaign remains five batches × ten repeats × three default suspect
fixtures × Windows/Linux × serial/three-process parallel: **600 physical attempts
plus 20 preflights**. It must run from the merged/default-branch
`physical-timeout-stress.yml` at one immutable admitted repair commit, with no
automatic retries, skipped cases, raised 180-second limit or successful-batch
combination across incomplete campaigns. Every failure remains retained. Exact
current-head ordinary Documentation/provenance/provider, Native, Windows Godot,
Linux build and all Linux shards passed before merge.

The default-branch workflow was dispatched at `2026-10-24T20:20:49Z` as
[run 40129364630](https://github.com/techrote/cybersand/actions/runs/40129364630),
attempt 1, with `source_sha=13b8e631f3e8fbaa2176ed41afc02c434b11e558`.
This is the admitted repair merge; no later source was substituted. Exact command:

```text
gh workflow run physical-timeout-stress.yml --repo techrote/cybersand --ref main -f source_sha=13b8e631f3e8fbaa2176ed41afc02c434b11e558
```

The complete campaign is **600/600 physical passes, 0/600 timeouts, zero other
failures/skips/missing attempts, plus 20/20 import preflights**. All 20 distinct
OS/mode/batch scopes, exact source/run/attempt and actual runtime identities pass
independent verification. This is one campaign, attempt 1, without a case retry,
skipped attempt, reduced N or raised physical timeout.

The independent gate job [120982397776](https://github.com/techrote/cybersand/actions/runs/40129364630/job/120982397776)
passed with `errors=[]`; artifact `12574999528` retains its disposition. Its 600
individual observations exactly equal both independent raw and timing readers,
not merely their aggregate totals. All 22 downloaded ZIP digests match GitHub's
service digests; all extracted member hashes match the retained inventories.
All 620 full logs identify pinned Godot, and all 600 per-attempt checkpoint JSON
records equal their batch receipts. Every physical execution has its original
final teardown marker, structured quit heartbeat and successful completion.

No new timeout was reproduced, and no preemptive diagnostic capture directory,
debugger refusal or incomplete capture was produced. All capture/launch/timeout
error fields remain null or false. There is no new physical hang stack to infer
from this passing campaign; the retained earlier engine dumps support the repair.

The fresh frozen Linux runtime is artifact `12574457859`, build job
`120977574420`, exact source `13b8e631f3e8fbaa2176ed41afc02c434b11e558`.
Its ZIP SHA-256 is `ce3be63881f82b42a03c5c37dcd1fa35c9f3054c6f9769733b7f0d2e7e97e51f`.
Actual native/Rapier bytes are `3bfe1679…` / `566e68ae…`, matching the full hashes
above. Windows uses `813bfbb4…` / `b54e54bd…`. All batch summaries and raw banners
identify `4.7.stable.official.5b4e0cb0f`. The source workflow's successful archive
verification steps bind the official Godot download; a per-attempt executable
hash is not invented where the producer only records version/runtime identities.

### Complete distributions

Times are seconds. `N/P/T/O` means executed/pass/timeout/other failure; imports
are excluded. Exact Decimal medians retain half-millisecond ties; hosted display
rounding can differ by 0.001 seconds without any observation difference.

| OS | Mode | Test | N/P/T/O | Timeout frequency | Median | p95 | Maximum |
|---|---|---|---|---|---:|---:|---:|
| Linux | Serial | Actor arena | 50/50/0/0 | 0/50 | 10.4935 | 17.012 | 17.040 |
| Linux | Serial | Actor rigs | 50/50/0/0 | 0/50 | 13.3115 | 23.894 | 24.195 |
| Linux | Serial | Usable course | 50/50/0/0 | 0/50 | 10.3905 | 16.644 | 16.746 |
| Linux | Three-process parallel | Actor arena | 50/50/0/0 | 0/50 | 24.0230 | 25.060 | 25.311 |
| Linux | Three-process parallel | Actor rigs | 50/50/0/0 | 0/50 | 29.8295 | 30.724 | 30.809 |
| Linux | Three-process parallel | Usable course | 50/50/0/0 | 0/50 | 24.2455 | 25.503 | 25.800 |
| Windows | Serial | Actor arena | 50/50/0/0 | 0/50 | 18.7750 | 19.814 | 20.363 |
| Windows | Serial | Actor rigs | 50/50/0/0 | 0/50 | 29.0750 | 30.038 | 30.584 |
| Windows | Serial | Usable course | 50/50/0/0 | 0/50 | 17.0605 | 17.767 | 18.147 |
| Windows | Three-process parallel | Actor arena | 50/50/0/0 | 0/50 | 26.7395 | 27.899 | 28.389 |
| Windows | Three-process parallel | Actor rigs | 50/50/0/0 | 0/50 | 35.7530 | 36.859 | 37.799 |
| Windows | Three-process parallel | Usable course | 50/50/0/0 | 0/50 | 25.3710 | 27.323 | 27.777 |

Portable [600 observations](issue-234/stress-observations.csv),
[twelve distributions](issue-234/stress-distributions.csv),
[twenty batches](issue-234/stress-batches.csv),
[22 artifact receipts](issue-234/stress-artifacts.csv),
[runtime/source verification](issue-234/stress-runtime-identities.json),
[full evidence inventory](issue-234/stress-evidence-inventory.json) and
[independent statistics receipt](issue-234/statistics-review.json) retain exact
job/artifact/member paths and original raw-file hashes. Curated CSV/JSON text uses
canonical UTF-8/LF bytes; its declared checksums match Git blob text, while raw
archive/log/checkpoint hashes retain their original bytes without normalization.

The complete ignored raw cache is
`C:/Users/_/.codex/worktrees/issue234-hang/khybersand/build/issue234-stress-40129364630`;
the independent full readback is `build/issue234-raw-final-600/raw-stress-review.json`.
It is deliberately retained alongside the #233 and earlier PR #236 raw caches.
Original Actions batch artifacts have 30-day retention, frozen Linux runtime
seven days, and gate audit 90 days; downloaded evidence is not replaced on expiry.

## Retained timing cohorts and measurement limits

These cohorts remain separate source-bound records. A later pass does not replace
an earlier timeout, a cancelled source revision is not admission, and a local
probe is not an additional hosted physical stress attempt.

| Cohort | Retained accounting and route |
|---|---|
| Historical ordinary CI selected in #233 | [284 observations](issue-233/historical-observations.csv): Windows 165, Linux 119; 279 passes and five timeouts (four Windows, one Linux). [Per-source distributions](issue-233/historical-source-distributions.csv) retain each checkout and original/rerun identity. This selected cohort is not an unbiased failure-rate estimate. |
| #233 ordinary instrumentation/admission/post-merge | [135 passing physical-family observations](issue-233/ordinary-observations.csv), from runs 40074769682, 40079743080 and 40082881910; exact checkout/build identities and [per-run distributions](issue-233/ordinary-distributions.csv) stay unchanged. |
| #233 registered baseline | Run 40082890839/1 at `4348516aba4c8e7036370d73afc14e86a19ea6a2`: 600 physical = 589 passes + 11 Windows timeouts, 20 passing preflights. [All twelve distributions](issue-233/stress-distributions.csv) and [every timeout](issue-233/stress-timeouts.csv) remain retained. |
| Earlier PR #236 investigation and comparisons | The [earlier validation ledger](2026-10-24-physical-actor-bvh-validation.md) retains original captures, invalid/partial apparatus, run 40053106474, inconclusive run 40053639095, same-host run 40056501226 and published-default run 40061137057. The paired campaigns' 750 completed candidate trials and the separate 300 published-default trials retain their own scopes and controls; none enters the new 600 denominator. |
| Current ordinary admission | Run 40125433675/1 at synthetic checkout `bb84068378765e3874840e19507666c6a7a1e5df`: [45 passing physical-family observations](issue-234/ordinary-observations.csv), separate Windows/Linux [N=1 per-test distributions](issue-234/ordinary-distributions.csv). Full-suite accounting remains 268 cases + five imports. |
| Preceding-main ordinary execution | Run 40109504699/1 at `03785c3dcaa5c82df000eeca1471bd6ec698be00`: 267/268 cases passed, one WEX timeout, five imports passed. All 45 physical-family observations passed. The failure remains in the complete adjacent-case CSV, outside the registered suspect sample. |
| Repair-merge ordinary execution | Run 40129347402/1 at `13b8e631f3e8fbaa2176ed41afc02c434b11e558`: 268/268 cases and five imports passed, including all 45 physical-family observations. This additional ordinary cohort does not enlarge stress N. |
| Current registered qualification | Run 40129364630/1, immutable repair merge `13b8e631f3e8fbaa2176ed41afc02c434b11e558`: 600/600 physical passes, 20/20 imports, zero timeout/other/missing. All twelve distributions and every raw receipt are linked above. |

Timing uses runner-measured wall time, rounded to milliseconds, with exact Decimal
median and nearest-rank p95 (rank 48 of 50 for each stress stratum). Timeout
frequency counts actual failed attempts, not diagnostic samples. Historical
180-second observations keep their original measurement/known-duration caveats.
The new 30-second idle capture, 45-second idle failure and 120-second internal
whole-fixture guard change detection, not the 180-second outer deadline. An idle
failure's `seconds` is elapsed process time when the threshold is observed, not
necessarily 45 seconds after launch; `diagnostic_seconds` separately records
capture cancellation, pre-kill snapshot and cleanup. An internal guard error is
also a failure even if its result category is not `timeout`.

Windows/Linux build identities, compiler/runtime hashes, host allocation, run
order and observation overhead differ across historical cohorts. Before/after
frequencies are descriptive; use the retained paired control for its registered
within-host comparison rather than claiming all changes in elapsed time came
from this patch. Coarse physical ticks and cumulative heartbeat `steps` are
different units. No exact blocked tick or stack is inferred from a phase alone.

## Mechanism classification and remaining uncertainty

### Adjacent ordinary runs retained without causal reassignment

Inspection of default-branch execution also recovered the immediately preceding
ordinary run [40109504699](https://github.com/techrote/cybersand/actions/runs/40109504699)
at main `03785c3dcaa5c82df000eeca1471bd6ec698be00`, and the automatic repair-merge
run [40129347402](https://github.com/techrote/cybersand/actions/runs/40129347402)
at `13b8e631f3e8fbaa2176ed41afc02c434b11e558`. These are separate cohorts, not
additional campaign attempts or substitutes for the exact-head PR admission.

The preceding run passed all 128 Windows cases and 139/140 Linux cases. Its sole
Godot failure was **`test_wex001_water_body_baseline`, 180.001 seconds**, outside
the three registered suspects and physical-family timing subset. Full log and
pre-kill process snapshot remain retained. Thirteen completed `PHYSICS_RESULT`
records end at P1/workers 4/tick 600; this is prior completed context. Source order
declares P2 next, but no captured marker establishes that it started. The sampled
main thread was `Rsl` with no wait channel, other threads mostly in futex waits;
`gdb not installed` was explicit, and no native stack was captured. This evidence
does not identify a blocked phase or justify assigning the Rapier join mechanism.

WEX subsequently passed in 143.354 seconds in PR admission and 160.984 seconds in
the repair-merge ordinary run. Those later passes preserve, rather than replace,
the original timeout. No Water/LCB/GEN behavior or timeout was changed to address
this adjacent observation under #234.

The 160.984-second passing WEX execution also crossed the ordinary runner's
150-second preemptive-capture threshold. Its capture started at 150.000151
seconds and completed in 0.202 seconds, with no capture error or diagnostic
failure; the test returned zero. The snapshot sampled the main thread as `Rsl`,
worker futex waits and a timer wait. It explicitly records unavailable GDB and
ten refused `/proc` stack reads. This is a healthy long-running control outside
the physical stress cohort, not a reproduced actor hang or a native-stack
attribution. Its full capture files and hashes are retained in the adjacent CI
receipt, artifact `12574263099`. The statement that the 600-attempt campaign
produced no captures applies to that campaign alone.

Preceding-main Native [40109504739](https://github.com/techrote/cybersand/actions/runs/40109504739)
also failed: the ten-minute `make soliding-sanitize` command hit exit 124 while
compiling `build/test_stage3b_sparse_activity_deadline_sanitized`. Normal and
ASan/UBSan suites had passed 107/107; TSan and shared/benchmark were skipped after
that build failure. This is a sanitizer **build-command** timeout, not a captured
Godot/Rapier test stall. The failing log remains retained and no automatic rerun
or unrelated code correction was used to hide it. Current-head PR Native passed
its complete matrix independently. Automatic repair-merge Native
[40129347322](https://github.com/techrote/cybersand/actions/runs/40129347322),
attempt 1 at `13b8e631f3e8fbaa2176ed41afc02c434b11e558`, also passed:
107/107 normal, 107/107 ASan/UBSan and 107/107 TSan, all seventeen command groups,
generation/soliding sanitizers, shared build and the 120-tick benchmark. Full-log
independent review found no failed test, sanitizer runtime finding or unexpected
nonzero exit. Its 157,516-byte log has SHA-256
`7ff95997ca3cbb4596e197fc020bd796c3956726247e479c4e0b72fff88df7b4`.
These additional checks and the original failure retain separate source scopes
in the adjacent execution receipts.

The two adjacent Godot cohorts retain [all 536 case observations](issue-234/ordinary-adjacent-observations.csv),
[per-run/OS/test distributions](issue-234/ordinary-adjacent-distributions.csv),
[ten job/import accounting receipts](issue-234/ordinary-adjacent-case-accounting.csv)
and [independent timing review](issue-234/ordinary-adjacent-review.json).
Totals are 535 passes, one timeout, zero other failures and ten passing imports;
the physical-family flags identify 90/90 passing subset observations without
hiding the WEX failure. [Adjacent CI review](issue-234/adjacent-ci-review.json)
retains the separate ordinary source/runtime identities, Native build failure,
post-merge checks and original raw-log/snapshot hashes. The initial 45 admission
records and the 600 stress records remain unchanged and separately scoped.

### Captured mechanism and qualified repair

The #233 population of normal passes no slower than 37.221 seconds followed by
179.992–180.003-second timeouts supports an intermittent stall population, rather
than a continuous load tail. The later native captures locate an actual parked
receive under the physics-step completion latch. Normal serial/parallel timing
differences can still reflect load; that does not explain the retained abrupt
full-timeout population on its own.

| Candidate | Classification supported by retained evidence | Scope/limit |
|---|---|---|
| Rapier/manual-step deferred-BVH receive | **Supported** | Official-DLL byte-matched stacks, separate matching-PDB control capture, and the deterministic queued-producer regression locate and reproduce the blocking join. Cooperative receiving addresses that path. The exact scheduler event that stranded work is unproven. |
| Async CyberSand cellular World worker as a necessary common cause | **Contradicted** | Pure-Rapier rigs constructs no cellular World; the captured join belongs to Rapier's Rayon work. This does not classify every historical native interaction. |
| Final fixture teardown/engine quit as the captured stall locus | **Contradicted** | The retained native stepping captures and #233 roster markers precede final teardown/quit. Earlier lifetime effects or other unstacked historical events remain not distinguishable. |

The captures do not establish that every old actor/usable/flight timeout shares
this mechanism. Higher-level session logic and wall-clock/frame timing are not
identified as the captured blocked call; possible timing triggers of a scheduler
race remain not distinguishable. The historical Linux usable-course timeout has
no matching native stack and is not retroactively assigned the Windows mechanism.

Process parallelism and worker counts remain distinct: the registered campaign
varies one versus three concurrent Godot processes. Source inspection finds
arena/course cellular Worlds configured with `workers=1` and advanced
synchronously, while rigs constructs no cellular World. CyberSand native worker
count is not manipulated. The deterministic two-worker **Rapier/Rayon helper**
regression is a separate progress proof, not a native-cellular-worker experiment
or a factor in the 600-attempt process-parallelism campaign.

Historical Windows serial 3/150 versus parallel 8/150 contains five clustered,
unrandomized hosted batches per mode; it does not establish co-tenancy dependence,
and serial reproductions show three processes are unnecessary. Historical failures
occurred on both OSes; #233's Windows 11/300 versus Linux 0/300 did not erase the
earlier Linux failure. Fresh campaign frequencies must be read with these limits.

Fresh frequencies are Windows 0/300 and Linux 0/300; each OS has serial 0/150 and
parallel 0/150. Parallel/serial median ratios are descriptively 1.23–1.49 on Windows
and 2.24–2.33 on Linux, but no timeout-frequency difference was reproduced. Five
clustered hosted batches and uncontrolled host allocation do not establish a
co-tenancy mechanism. Native worker-count dependence remains unanswered.

The passing population spans 9.452–37.799 seconds, far from the unchanged
180-second outer deadline. This negative reproduction does not turn historical
hangs into smooth slowness or prove that all possible stalls are eliminated.
Repeated native captures, the progress regression, the earlier paired comparison
and this complete operational qualification support the scoped cooperative-join
repair. The exact scheduler trigger, the cause of the unstacked historical Linux
event and untested platform/worker-count generalizations remain unproven.

Canonical ownership: ADR-009/runtime locks/provenance/notices own the scoped
dependency selection; the test guide owns deadline/failure semantics; build guide
owns commands/artifacts; roadmap/handover/index route to this evidence. The #233
baseline, prior #236 captured/paired evidence and this final acceptance remain
separate dated scopes. Native authority/lifetimes, public interfaces, capacity,
gameplay controls and unrelated LCB/MAT/GEN behavior are unchanged. Current-main
retrieval objects, including its updated LCB expectations, are preserved; the
prior CI-HANG-01 route is additive. Frozen retrieval questions remain unchanged.

### Documentation-update checklist mapping

| Changed or reviewed claim | Canonical owner / disposition |
|---|---|
| Selected desktop dependency and reproducible backport | [ADR-009](../decisions/ADR-009-rapier-2d-rigid-body-backend.md), [Rapier runtime lock](../../godot/third_party/rapier2d.lock.json), [build lock](../../third_party/rapier-bvh-build.lock.json), platform provenance and notices retain original release and exact selected inputs. |
| Ownership, lifetime and interfaces | [Threading contract](../architecture/simulation-tick-and-threading.md) and [coupling contract](../architecture/rigid-body-and-cellular-coupling.md) reviewed; native authority and public interfaces are unchanged. The test guide documents the private observer lifetime, copied context and bounded join. |
| Deadlines, errors, progress, capacity and controls | [Test guide](../operations/testing-validation-and-replay.md) owns the 180-second outer limit, 30/45-second idle thresholds, 120-second fixture observer, sticky failure and no-retry/skip oracle. No solver, pool, workload, assertion, gameplay control or capacity is changed. |
| Build, runtime artifacts and hosted execution | [Build guide](../operations/local-build-and-validation.md), [Rapier runbook](../operations/rapier-2d-migration-runbook.md) and source workflows retain exact commands/inputs. [Provider/merge policy](../operations/github-development-and-release.md) is preserved; its checker and six focused tests pass. |
| Status, platform scope and recovery routes | [Handover](../operations/cybersand-codex-development-handover.md), [roadmap](../reference/status-and-roadmap.md), [validation ledger](../reference/validation-evidence.md) and [index](../README.md) route to this source-bound record and its limits. The admitted repair merge is the recoverable implementation checkpoint; final evidence admission is recorded in its PR and issue completion receipt. |
| Retrieval and reverse links | [Retrieval index](../reference/retrieval-index.md), [corpus manifest](../reference/retrieval-corpus.json) and supplementary TEST04/CI-HANG-01 facts distinguish outer/idle limits and separate campaigns. Frozen questions/query wording and unrelated LCB expectations are preserved. |
| Historical integrity and failures | #233, earlier #236 experiments, invalid captures/apparatus, cancellations and reruns retain their dated source/result scopes. M11 checks the retained historical revision rather than rewriting hashes to current files. |

Final evidence editing is based on admitted merge
`13b8e631f3e8fbaa2176ed41afc02c434b11e558`, local branch
`codex/issue234-qualification`, with a documentation/structured-evidence-only
delta. Independent combined-diff review found no implementation, runtime, raw-log
or binary change and no blocker. It rehashed all 22 original stress ZIPs,
cross-checked 620 inventory records/600 checkpoints, every manual table row and
curated CSV checksum against canonical Git-LF bytes. Required LFS state remains
all eighteen payloads materialized; the pinned companion fixture revision is
`6a58311982941b75f46e22109a0829e5acb83c7e`.

The following local final checks pass:

```text
python tools/ci/check_docs.py
python tools/ci/check_m11_consistency.py
python tools/ci/check_repository.py --require-materialized
python tools/ci/check_ci_provider_policy.py
python tools/docs/retrieval_eval.py --output build/issue234-independent-statistics/retrieval-frozen-final.json
python tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output build/issue234-independent-statistics/retrieval-challenges-final.json
git diff --check HEAD
```

Documentation reports 111 documents, 2,643 links and zero errors/warnings.
Historical M11 integrity remains 18 records/28 hashes; current materialized
provenance and hosted-provider policy pass. Frozen retrieval remains hit@1 21/32,
hit@5 32/32 and MRR 0.7937. The separately scoped 122-question challenge set is
hit@1 94/122, hit@5 122/122 and MRR 0.8657; TEST04 ranks 1 and CI-HANG-01 ranks 3.
Only those two supplementary fact objects changed; frozen questions and all query
wording remain unchanged. These are lexical development metrics, not proof of
deployed semantic retrieval quality.

The evidence PR's final exact-head hosted Documentation/provenance result and
merge identity belong to its admission/issue-completion receipts. This avoids
mislabeling an older documentation check as validation of a later evidence edit.

Final hosted evidence admission and issue disposition are recorded in the
evidence PR and issue-completion receipts after this source checkpoint.
Repair implementation, ordinary admission, complete registered campaign, full
independent readback and all twelve timing/frequency strata are complete.
