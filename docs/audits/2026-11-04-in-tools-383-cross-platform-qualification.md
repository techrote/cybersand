---
title: PR 383 metered Liquid Drain cross-platform qualification checkpoint
status: Current
document-kind: evidence
scope: Fresh frozen-head Linux native and headless Godot/Rapier execution, Windows identity and owner procedure, hosted sequencing and evidence custody; no integration or physical-device acceptance
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/in-tools-metered-drain.md, 2026-11-04-in-tools-361a-metered-drain.md, in-tools-383-qualification-2026-11-04/windows-owner-playtest.md]
---

# PR #383 — metered Liquid Drain qualification checkpoint

**Disposition: available Linux execution PASS; Windows execution and physical
input UNTESTED; final hosted #383 qualification DEFERRED. No platform-blocking
source defect was reproduced. This does not establish that Windows is free of
defects. Keep #383 draft and #361 open.**

This task freshly executes the existing metered U10 implementation. It changes
no production source, native ABI/solver, test, fixture, runtime, dependency or
workflow. It does not merge, change #383's implementation branch, modify
#379/#370 or authorize valves/nozzles. This record and its evidence live on the
separate `audit/in-tools-383-qualification-20261104` branch, based directly on
the tested implementation head.

The [evidence index](in-tools-383-qualification-2026-11-04/evidence-index.json)
binds the retained records by byte count and SHA-256. Original process logs,
external execution wrappers and the failed preparation/reader attempts are
retained in the separate downloadable packet; logs and toolchains are not
committed to the source repository.

## Source, runtime and execution authority

| Field | Exact identity |
|---|---|
| Freshly executed PR #383 commit | `73b10f9b800e72f358f22f470e57a4531002c168` |
| Freshly executed tree | `31c5a9a4b986820985658d3ed2228ebe9008828a` |
| Earlier measured implementation | `f4878302fd66975468dd307a94bb035529af5ecd`, tree `b5743bdb4b7a6c3e8fc6c1f8d331aa08ce21b719` |
| Accepted main, rechecked 14:32 UTC | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Separate #379 head | `1aaab324a9bccbaa7f868798dbb4f9fd9b4a7718`; Ready for review, unmerged |
| Local host | Ubuntu 24.04.3 LTS, Linux x86-64, kernel 6.18.57, glibc 2.39 |
| Native test compiler | GCC/G++ 13.3.0, Ubuntu `13.3.0-6ubuntu2~24.04` |
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Godot executable SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Official Linux archive SHA-256 | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`, 75,664,355 bytes |
| Fresh native standalone executable SHA-256 | `0fd0d0008eefa143f8441952919390826ea3e1c0688af078d26190b8b4e43bb4` |
| Linux CyberSand extension SHA-256 | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45`, 4,222,424 bytes |
| Linux Rapier SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`, 117,275,416 bytes |
| Windows CyberSand DLL SHA-256 | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a`, 4,824,064 bytes; identity only, not executed here |
| Windows Rapier DLL SHA-256 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`, 9,987,072 bytes; identity only, not executed here |

All **80** current native production inputs match both platform provenance
manifests. The retained extension's source/build commit is
`a7ee10f251f647a16dec8a1d7f18c4f299100cba`; its source tree is
`aed6d7acfca8778af691955142c677bdfc2ed781`. Linux build provenance specifies
GCC 13.3, Ubuntu 24.04, SCons 4.10.1 and godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`. Windows provenance records
LLVM-MinGW 20260826 UCRT / Clang 23.1.0; this is the dependency's historical build
toolchain, not a Windows compiler executed by this task. Rapier is addon v0.35.2 /
rapier2d 0.35.1 with its qualified cooperative BVH backport. No rebuild or runtime
publication is needed by the unchanged native source observed at this head.

The fresh application run records **1,109 inputs** before and after execution,
including every one of the prior 754 source/runtime inputs. All match and remain
unchanged. The native compiler's separate **55-input** census matches canonical
Git blobs. All **18 LFS payloads** were materialized and checked against committed
SHA-256/size, including the unexecuted Windows DLLs. Runtime identity and execution
remain separate claims. Full hashes are in
[host-source-before.json](in-tools-383-qualification-2026-11-04/host-source-before.json).

Representative production hashes:

| Input | SHA-256 |
|---|---|
| `native/src/world.cpp` | `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` |
| `godot/scripts/metered_liquid_drain.gd` | `b77d6f67a1bc39eb98050e661f2814278a2d84a6bf1a77c5fd518c41e14abfde` |
| `godot/scripts/physical_usable_runtime.gd` | `37f4ee6979119a9e74e6d5d1545b2e015a0aa0303c3d2636f6bc184bef720348` |
| `godot/scripts/simulation_worker.gd` | `d6c21869afc6509518e89405179bc547d07e1bd24627159f46b47f5d6a6008eb` |
| `godot/scripts/main.gd` | `1d0e8037a9e112e525172137ec5f20502cda9089620c8699852486b613a2eeeb` |

The Godot fixture hashes are
`50a5ce0f6fc6d61add58e307e40cf3570849b354a5d61edc9ed8413e254aae12`
for `in-tools.physical-metered-drain.v1` and
`f1f9a606172b7d123f90b3d41c56adcc4e33e770c7da249fd331bd7cd5032d0b`
for `in-tools.physical-metered-desktop.v1`. Each raw packet carries its own
fixture identity. Applied policy hashes, radius, state precision, construction
receipt, native object/generation, completed ticks and captured physical frame
are retained per applicable observation. They are not interchangeable fields.

## Gate ledger

In this table **UNTESTED** means no execution evidence exists from this task;
**SKIPPED** describes an observed hosted job/step; **DEFERRED** is the intentional
future gate disposition. **BLOCKED** applies to the final integration decision,
not to an inferred operating-system defect.

| Platform / host | Gate | Result | Runtime identity and limit |
|---|---|---|---|
| Linux native-only | Fresh primitive/guarded C++ driver | **PASS** | Standalone `0fd0d000…`; 30 cases, 14,023,753 repeated assertions |
| Linux Python | Native parser/output-custody controls | **PASS** | 23 tests; synthetic parsing and fresh-output custody, not native execution |
| Linux headless Godot | Import and 15 scoped suites | **PASS** | Native `0f60213c…`, Rapier `566e68ae…`; 12,026 counted assertions plus separate uncounted genuine failed-tick suite |
| Linux headless native owner | Actual production helper/runtime/worker controls | **PASS** | 1,614 assertions; fixture-authored frames/masks, genuine native World |
| Linux headless equipment/Rapier | Equipment/session/UI outcome handling | **PASS** | 99 assertions; copied native outcomes are deliberately synthetic |
| Linux headless Main/Rapier | PLAY admission, controlled drain, lifecycle and body/wall route | **PASS** | 148 assertions; synthetic M/P input and explicit aim/focus seam |
| Windows native-only | Standalone driver | **UNTESTED** | No Windows host/compiler execution available |
| Windows headless Godot/Rapier | New metered implementation | **UNTESTED** | DLL identities above verified; no Windows process launched |
| Linux and Windows rendered desktop | Visible UI, rendered pacing, window manager | **UNTESTED** | No physical desktop/display execution; no Xvfb available in this host |
| Linux and Windows physical devices | Mouse, keyboard, gamepad and owner feel | **UNTESTED** | Executable Windows procedure supplied; no human/device evidence invented |
| Local provenance | Current docs, 18 materialized payloads and native source mapping | **PASS** | Existing repository checker; pinned companion inputs restored outside source checkout |
| Local historical integrity | M11 | **PASS** | 28 historical hashes / 18 records; not current runtime acceptance |
| Hosted #383 Documentation | Assigned run 41833090400 | **PASS** | Documentation result only |
| Hosted #383 materialized provenance | Step in run 41833090400 | **SKIPPED** | Draft skip remains unexecuted |
| Hosted #383 Native | Run 41833090231 | **SKIPPED** | No execution pass |
| Hosted #383 GDExtension/Godot | Run 41833090642 | **SKIPPED** | No Windows/Linux execution pass |
| Hosted #383 shader | Run 41833090317 | **SKIPPED** | No shader execution claim |
| Hosted #383 final reconciled matrix | Post-#379 final head | **DEFERRED** | No dispatch, rerun, ready transition or provider change made |
| Hosted standalone metered native driver | Exact-source 30-case execution | **DEFERRED** | Not registered in generic Native; needs an admitted exact-source route |
| Final ready/merge decision | Integration gate | **BLOCKED** | #379 integration, reconciled-source review/qualification and owner gates remain |

The [scope advisory](https://github.com/techrote/cybersand/actions/runs/41833090216/job/126584970470)
is report-only. Its original packet says `candidate_native_execution_needed=true`,
`native_skip_authorized=false`, `candidate_exemption_kind=none` and
`ADVISORY_ONLY_NO_GATE_CHANGE`. It identifies synthetic merge commit
`a636e914468916b917f682f4947eec67a715f0fc`, whose tree equals the assigned
`31c5a9a4…` tree. A green advisory cannot replace runtime execution.

## Exact commands and replay boundary

These are the actual local paths. Native compilation and parser execution used
the clean detached source checkout, not the evidence branch:

```sh
cd /workspace/scratch/c14abf8ba238/cybersand-383
python3 tools/lcb/run_metered_drain_native.py --output-dir /workspace/scratch/c14abf8ba238/qualification-383/native/attempt-1
python3 -m unittest discover -s tools/lcb -p test_metered_drain_native.py -v
python3 /workspace/scratch/c14abf8ba238/qualification-383/run_host_qualification.py
```

The external harness delegates every engine process to unchanged
`tools/ci/run_godot_regressions.py::run_case`, retaining the registered watchdogs,
error/skip detection and natural-completion checks. Its complete source, original
logs and isolation environment are retained with the downloadable packet;
[run-host-qualification.py](in-tools-383-qualification-2026-11-04/run-host-qualification.py)
is a byte-identical copy. It invokes this import followed by the 15 scripts named
in `host-source-before.json::selected_cases`; every complete command and timeout
is in `host-processes.json::results`:

```sh
/workspace/scratch/c14abf8ba238/qualification-383/deps/Godot_v4.7-stable_linux.x86_64 --headless --path /workspace/scratch/c14abf8ba238/cybersand-383/godot --editor --import
# Individual case command shape; use each recorded res://tests/test_*.gd path:
/workspace/scratch/c14abf8ba238/qualification-383/deps/Godot_v4.7-stable_linux.x86_64 --headless --path /workspace/scratch/c14abf8ba238/cybersand-383/godot --script res://tests/test_physical_metered_drain.gd
python3 /workspace/scratch/c14abf8ba238/qualification-383/reduce_host_evidence.py --host-dir /workspace/scratch/c14abf8ba238/qualification-383/host-attempt-4 --output /workspace/scratch/c14abf8ba238/qualification-383/host-reduction.json
python3 tools/ci/check_repository.py --require-materialized --json /workspace/scratch/c14abf8ba238/qualification-383/repository-validation.json
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_docs.py
python3 tools/docs/retrieval_eval.py --output /workspace/scratch/c14abf8ba238/qualification-383/retrieval-frozen.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output /workspace/scratch/c14abf8ba238/qualification-383/retrieval-challenges.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-questions-in-tools-361a.json --output /workspace/scratch/c14abf8ba238/qualification-383/retrieval-in-tools.json
```

Replay requires a separate clean checkout of the full executed SHA, correctly
materialized pinned runtimes, the official Godot archive and a **new** output
directory. Relocate the external harness's path constants for another machine
and record its new hash; never overwrite an earlier attempt or treat a standalone
zero engine exit as equivalent to the runner's error/skip checks. For Windows,
use the separately supplied owner procedure and the Windows runner, not these
Linux binary paths. The documentation check also runs on the evidence worktree;
added audit records do not enter the unchanged canonical retrieval corpus.

## Fresh native quantity and worker results

The unchanged standalone driver freshly compiles and runs in 25.53 / 4.24 seconds.
These instrumented totals include extensive assertions and inventory work;
they are not production command/tick timing. Each arm executes 40 accepted
operations and 64 ticks per worker configuration. Every one-worker arm observes
one claimant and every four-worker arm observes four. Physical hashes and the
separate 65-sample IN diagnostic-ledger traces agree.

| Native arm | Initial | Explicit sink | Remaining | Unit |
|---|---:|---:|---:|---|
| IN Water Q7 | 9,072 | 3,052 | 6,020 | Water units |
| IN Water Q255 | 330,480 | 111,180 | 219,300 | Water units |
| FreeMass Water Q7 | 9,072 | 4,464 | 4,608 | Water units |
| FreeMass Water Q255 | 330,480 | 163,200 | 167,280 | Water units |
| CY Water Q7 | 9,072 | 4,438 | 4,634 | Water units |
| CY Water Q255 | 330,480 | 161,670 | 168,810 | Water units |
| CY Brine | 1,296 | 638 | 658 | Brine cells |
| IN Brine | 1,296 | 436 | 860 | Brine cells |

Every residual is zero. The independent 131,072-cell/eight-chunk census checks
exact wall and forbidden coordinates at ticks 0, 8, 20, 32 and 64. Five deliberately
corrupted geometry/domain/inventory controls reject. Post-shutoff transport
continues without another sink debit. Separate one/16-cell controls exercise
fractional FreeMass at Q7/Q255, state-byte-independent Brine accounting, raw
under-mask erasure as a hazard and guarded refusal. Save/restore continuation
and native momentum retirement remain distinct checks.

The direct-core fixture has no equipment charge/cooldown or native command
receipt. Its output serializes aggregate arm rows; per-command closure checks
execute inside the driver. Full details are in
[native-summary.json](in-tools-383-qualification-2026-11-04/native-summary.json)
and [native-qualification.json](in-tools-383-qualification-2026-11-04/native-qualification.json).

## Fresh application quantities, refusals and faults

The application run executes from 14:15:17 to 14:17:38 UTC. All 15 processes
finish naturally with exit zero, no script/runtime error or skip. Their original
logs are hash-bound in [host-processes.json](in-tools-383-qualification-2026-11-04/host-processes.json).
The packet counts 1,613/147 precede the final successful packet-write assertion;
the process footers correctly count 1,614/148. This explains the one-count
difference without changing evidence or thresholds.

The native-backed runtime fixture checks 16 quantity arms and 52 other controls.
The same eight axes run at one and four configured workers; observed claimants
are **1 and 2**, respectively. The 312-cell fixture has insufficient concurrent
work to establish four-claimant application execution. It does not borrow that
claim from the larger native tank.

| Runtime fixture arm | Initial | Removed by one 16-cell pulse | Remaining source | Remaining allowance |
|---|---:|---:|---:|---:|
| IN/FreeMass whole Water Q7 | 2,184 | 112 | 2,072 | 112 units |
| IN/FreeMass/CY whole Water Q255 | 79,560 | 4,080 | 75,480 | 4,080 units |
| Fractional FreeMass Q255, 63 units/cell | 19,656 | 1,008 | 18,648 | 7,152 units |
| CY/IN Brine | 312 | 16 | 296 | 16 cells |

The Godot fractional and CY Water arms above are Q255. Additional Q7 fractional
and CY controls are direct-core native tests, not claims of those same Godot
combinations. Each accepted runtime fixture pulse costs 0.85 charge and starts
0.10 seconds cooldown. Eight post-shutoff native ticks preserve the expected
stored quantity and exact positional protections. Source and sink are separate
from the finite permission stock.

The 69 recorded command controls comprise **27 applied metered outcomes,
37 refused metered outcomes, two injected fault outcomes and three v1 controls**
(ordinary U10 and rejected legacy version). An independent reader sums verified
native transitions and checks each observed sink debit, requested bound,
before/remaining allowance, owner identity and available completed-tick fields.
The [reduction](in-tools-383-qualification-2026-11-04/host-reduction.json) retains
compact per-command records; the original
[native-host packet](in-tools-383-qualification-2026-11-04/metered-drain-native-host.json)
retains complete copied transitions, construction receipts and applied policies.

Refusals cover Empty/wrong material, PF-containing policy, unsupported request,
bounds, body mask, hard occlusion, stale native World/generation, equipment and
control identity, duplicate sequence, cancelled/expired lease, low charge,
cooldown, invalid budgets, exhausted stock, capacity and unavailable World.
They write no cells and debit no sink or activation charge. Ordinary simulation
time can still recharge charge or age an existing cooldown. The fractional-IN
Godot guard deliberately corrupts copied preflight data; it is not presented as
a genuine fractional live IN construction. The native fractional-ingress
admission controls are separately executed.

The real native capacity control reports `active scheduling-core capacity
exhausted`, attempted tick 1 and completed tick 0. A drain then refuses, and
explicit reconstruction recovers. The separate failed-tick regression also
passes without a numerical assertion footer.

Two deliberately injected post-write/readback faults preserve their negative
results:

| Fault injection | Actual removal by independent census | Verified sink debit | Quantity complete | Outcome |
|---|---:|---:|---|---|
| Skip the second native erase | 255 Water units | 255 | false | Terminal; two writes attempted; no retry |
| Invalidate post-write copied readback | 255 Water units | 0 | false | Terminal; one write attempted; actual/verified difference remains explicit |

The second row has an intentional unverified 255-unit difference; it is not
included among the zero-residual accepted windows. No successful activation
charge or cooldown is fabricated. The worker remains quarantined across
stop/start and session reset, refuses legacy lab mutation, and accepts recovery
only through explicit fresh reconstruction. This is host fault/quarantine
evidence around real native writes, not a claim of spontaneous native corruption
or a genuine native failed tick. Healthy restart separately preserves physical
ownership and requires fresh control authority.

## Real Main/Rapier route and performance limits

Main instantiates the real native owner, prepared construction and Rapier bodies.
The unmodified PLAY smoke proves physical-owner/policy/F5 admission; it makes no
liquid-removal claim. The controlled registered Main variation proves actual
removal with synthetic M input and fixed aim/focus seams. Mouse click traversal,
gamepad-only equipment triggering and real window focus were not executed.

| Main endpoint | Initial | Registered metered sink | Final | Completed tick |
|---|---:|---:|---:|---:|
| IN Water, two eight-cell held pulses | 538,560 units | 4,080 units | 534,480 units | 92 |
| Fresh IN reset, one pulse | 538,560 units | 2,040 units | 536,520 units | 16 |
| IN Brine, one pulse | 2,112 cells | 8 cells | 2,104 cells | 17 |
| Current FreeMass, actual partial cells | 538,560 units | 1,893 units | 536,667 units | 18 |
| Actual hard-wall refusal | 538,560 units | 0 | 538,560 units | 64 |
| Actual actor-body obstruction | 554,880 units | 0 | 554,880 units | 68 |

These Main observations configured four native workers. The first IN endpoint
observed one actual phase claimant; subsequent reset, Brine, FreeMass and barrier
endpoints observed two. The IN Water policy digest is
`71fd2aa0ae758c5e64a2fcb4931be021be6af9da798107ca2779428bb643cb7b`,
with radius 3 and 8-bit Water. The first two rows retain World wrapper object ID
`-9223371964897294742` but generation changes from 3 to 4; completed ticks are
92 and 16. Object identity, native generation, initial construction receipt,
applied policy and command-local observation are recorded separately.

Ordinary U10 is measured separately between joined-owner endpoints: 538,560 to
537,999 Water units, a **561-unit** difference. Its ordinary v1 result records
changed cells and activation resources; its experimental metered sink remains
zero. This is not a native per-command quantity receipt. Earlier FreeMass
1,561-unit and ordinary 1,572-unit results remain attached to their earlier
ticks. Variable asynchronous reach into fractional cells is not a conservation
defect when the actual source/sink closure is exact.

The wall case refuses at real Rapier muzzle clearance before native dispatch.
The body case preserves six actual masked stored Water cells, each with
`state_a=255` and `transient_body_id=1`: `(100,106)` and `(97,107)` through
`(101,107)`, between completed native ticks 63 and 68. The original packet
retains both endpoints and the owner-local source refusal. Exact wall coordinates
and forbidden-side scans accompany every joined census; equal Wall counts alone
are not the protection proof. The
[desktop packet](in-tools-383-qualification-2026-11-04/metered-drain-desktop-host.json)
retains actual construction, policy, object/generation and pose observations.

| Exploratory local measure | Samples | Minimum | Median | Maximum |
|---|---:|---:|---:|---:|
| Full owner command work | 16 | 5.545 ms | 6.894 ms | 10.353 ms |
| Metered helper subsection | 16 | 4.887 ms | 5.954 ms | 7.182 ms |
| Subsequent native tick cost | 128 | 0.270 ms | 0.583 ms | 2.493 ms |

These instrumented container samples are distinct measurements. They exclude
rendered pacing and cannot establish a frame-time budget, target-PC performance,
four-core utilization or a simultaneous CPU participation percentage.

## Evidence custody, preparation failures and independent readback

All tested production/fixture inputs and Linux runtime bytes remain unchanged.
The checkout was clean at engine startup. Godot generated one class cache and
407 resource UID files during import; their identities were recorded and the
generated outputs preserved outside the source checkout after execution. Only
that derived tracked cache was restored. The final source checkout is clean at
the original SHA/tree; no production/test source was repaired or rewritten.

Three pre-engine setup attempts were blocked: leftover LFS download temporaries;
a historical payload census compared with 16 still-unmaterialized LFS pointers;
and the index stat state after verified cache materialization. All stopped
before Godot execution. The final run followed complete 18-payload staging,
LFS canonicalization with unchanged Git tree and a clean-start fence. The
standalone native run began clean; its ending snapshot disclosed two download
temporaries from concurrent runtime preparation, while all 55 compiled inputs
remained byte-identical. These observations are retained rather than erased.

The first external packet reader also failed because it incorrectly required
completed-tick metadata to be identical at ticks 63 and 68. The corrected reader
separately requires tick advancement and exact equality of the six coordinates,
material/quantity/mask and every other stored-cell field. Original reader and
failure log are retained. Neither application source nor fixture was changed,
and no engine rerun was needed for that evidence-reader correction.

A separate agent independently reviewed scope, source/runtime hashes, original
logs, footers, every packet quantity and the clean final checkout. Its
[completed readback](in-tools-383-qualification-2026-11-04/completed-host-review.json)
is **PASS**, with 12,026 counted assertions and no custody/closure finding.
This is independent qualification readback, not the separately assigned complete
production audit, a separate GitHub-account approval or owner merge permission.

Fresh retrieval retains 32/32 canonical top-five hits for the frozen questions,
156/157 for existing challenges (124 rank one; existing `LCB03` miss retained),
and 4/4 rank-one IN-TOOLS hits. These lexical results are not runtime acceptance
or proof of answer correctness. Full result hashes and the passing documentation
checker are in
[documentation-validation.json](in-tools-383-qualification-2026-11-04/documentation-validation.json).

## Windows owner procedure and integration prerequisites

The [Windows checklist](in-tools-383-qualification-2026-11-04/windows-owner-playtest.md)
and [PowerShell entry point](in-tools-383-qualification-2026-11-04/Invoke-PR383OwnerPlaytest.ps1)
reuse the existing `tools/play/create_manual_packet.py` and generated launcher.
They verify frozen source/runtime identity and open the existing application.
All human rows start **UNTESTED**. No Windows execution or PowerShell execution
is claimed by this Linux task.

In actual PLAY, select a physical owner, Water inertial and radius 3; build/resume;
F5 → Liquid Drain → Metered Water v1 → 50% power → Equip only. At Q255, initial
permission is 8,160 Water units. An unobstructed eight-cell half-power pulse can
remove 2,040 units; actual smaller eligible footprints must use measured values.
At that power, one precision pulse has a three-cell/765-unit upper bound. The
invariant within one generation is `sink + remaining allowance = 8160`; Brine's
separate invariant is `sink + remaining allowance = 32 cells`. Refusal increments
sink by zero. The UI permission ledger alone is not a full native source census.

Exercise physical mouse/M, hold/release, right-click precision, actual focus
loss, F5 blocking, pause/resume, rapid tap, deselection, depletion and R reset.
Record native generation and actual displayed stock. Only a verified fresh
generation may refill. Existing gamepad input controls player movement/actions;
this source has no gamepad-only metered equipment trigger. Use mouse/M for the
tool while testing controller movement and disconnect/rearm, and label that route.

At the final 14:32 UTC source check, [#379's owner ledger](https://github.com/techrote/cybersand/pull/379#issuecomment-6632657584)
has completed applicable hosted gates, remains Ready/unmerged and requires
explicit owner integration approval. Its retained v2 finished-image diagnostic
FAIL is separate from its registered v3 gate passes. Those results qualify #379,
not this implementation. The new independent #383 production audit had no
public GitHub review/thread disposition at intake; coordination and its final
source-qualified findings remain required.

The next integration owner must:

1. Obtain the separately required #379 integration decision and verify accepted
   main after any authorized merge; this task grants no merge permission.
2. Consume the independent #383 production audit and preserve this frozen packet.
3. Reconcile #383 onto the accepted main in its designated writer lane, reviewing
   documentation/admission and protected source-inventory overlaps. Do not reuse
   this head's measurements for changed bytes.
4. Verify source/runtime/LFS identity and rerun every affected focused gate at the
   resulting head; rebuild/publish only if a newly admitted native delta requires it.
5. Select one final reviewed head and run the required Ready-state hosted
   Documentation/materialized provenance, Native, Windows/Linux Godot and other
   applicable gates, without overlapping equivalent expensive matrices.
6. Supply actual Windows standalone metered-native execution through a registered
   exact-source route. Generic Native and Godot discovery do not execute that
   standalone driver by themselves.
7. Complete and record the owner physical-input/rendered acceptance or explicitly
   retain the relevant acceptance hold; obtain the final owner decision.

No full #361-A completion, PR merge, parent closure or successor implementation
is claimed. Record this qualification checkpoint and stop.
