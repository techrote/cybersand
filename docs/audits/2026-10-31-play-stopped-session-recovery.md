---
title: PLAY stopped composed-session recovery and launcher cancellation
status: Current
document-kind: audit
scope: Focused production recovery from a reproduced native failure, five-rig Linux LIFE007 and three-order LIFE008 local evidence; resulting-head hosted and manual qualification remain pending
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../operations/local-build-and-validation.md, 2026-10-29-play-life005-native-failure-recovery.md, 2026-10-31-play-input011-authority-transitions.md, 2026-10-31-execution-watchdog-modernization.md]
---

# Stopped composed-session recovery — 2026-10-31

## Status and selected scope

An actual native failure in the composed Play host left the visible Restart
action disabled. Bypassing that disabled button called ordinary construction
against the same failed worker and left a prepared candidate pending. The
focused correction lets an explicit Restart retire the failed host and rebuild
the **accepted** session through a fresh exclusive owner. Returning to the
launcher cancels that recovery, including the deferred scene-replacement
boundary.

The correction is committed at
`35b7008e62d726a50067497c046c33bdbd3729df`, tree
`1c3ad2e6157b0360d06c60bd2229424f563b9dca`, on local branch
`codex/play-stopped-session-recovery-20261031`. Its base is the reviewed local
watchdog source `6c0df8369ed79f777b993694087d26781c20d216`, tree
`1d3c5cfa415884bf48bfead416049dcb3722b339`. The base's production bytes match
the accepted Main behavior at reconciliation. Neither the watchdog parent nor
this child is represented here as merged or qualified on its resulting hosted
head.

This selects the existing stopped-session production slice and original
LIFE007/LIFE008 controls from the preserved, unmerged
[#308](https://github.com/techrote/cybersand/pull/308) source
`2443a78378d649df588efeac9db7c54084473329`. The held branch is unchanged.
The port reconciles the current Main and navigation additions and replaces the
old test deadline literals with the shared execution policy. It extracts seven
needed helper methods into a focused support script; it does not import the
broad LIFE006 or PACE003 campaign. Historical #308 failures retain their
original meaning.

The work addresses the session-reconstruction and navigation behavior in
[#268](https://github.com/techrote/cybersand/issues/268). It does not reopen the
closed [#269](https://github.com/techrote/cybersand/issues/269) lifecycle work or
claim release acceptance under
[#270](https://github.com/techrote/cybersand/issues/270). Protected INPUT011,
LIFE009, LIFE010 and LIFE011 fixture bytes are unchanged.

## Original failure, retained separately

The original diagnostic executes the actual `main.tscn` on unmodified base
production. It supplies `cybersand/native_active_core_capacity=1` only while
the first host and native adapter construct, then restores the prior setting
before that host enters the tree. A composed Stunt Buggy course reaches actual
native construction and Rapier terrain installation before Resume encounters
the real native error `active scheduling-core capacity exhausted`.

The failed packet reports attempted tick 1, completed tick 0 and failure count
1. The visible selector disables Restart, Resume and Build and says:
`Reset the failed World through its original recovery route first.` Calling
`restart_applied()` directly retains the same Main and failed worker, with a
nonempty pending apply and an actual pending physical candidate. Teardown joins
the original worker. This is an observed recovery-path defect, not a synthetic
failure return or an execution timeout.

The diagnostic exits **1**, with **7 assertions / 1 failure**, in
**2.972616644 seconds**. Its original log, receipt and diagnostic source remain
in `build/play-recovery-validation/original-gap/`; the diagnostic script was
moved out of the discovered test directory before the correction commit.

| Original evidence | SHA-256 |
|---|---|
| `original-gap/process.log` | `3aa5097aba49aa598cc7fd715c853d4f86c137a98050d928415b53398a294d7f` |
| `original-gap/probe_play_stopped_restart.gd` | `ba621e1bec0be26eda6c556a427b14e4d6e001868cad25a0b3c422b054e9ca96` |
| Base `godot/scripts/main.gd` | `95f95bd4a57687dd4e9986c1705821881e2af85eb358a1859543bafd27503d1f` |
| Base `godot/scripts/feature_navigation.gd` | `17da6bec36ab3bfc35643e357b68e08f94dd36f42f9b7f5d98585231c69a051a` |
| Base `godot/scripts/playable_session_panel.gd` | `4c9e66a5ff83193ada1dc80f0489639c104e110451ba724c7b66a06402dea197` |

Passing corrected runs do not replace or relabel this original failure.

## Production behavior and ownership

The production delta is limited to
[`main.gd`](../../godot/scripts/main.gd),
[`feature_navigation.gd`](../../godot/scripts/feature_navigation.gd) and
[`playable_session_panel.gd`](../../godot/scripts/playable_session_panel.gd).
The native healthy-World guard remains unchanged. There is no new native API,
worker scheduler, physics owner or solver behavior.

An explicit Restart of a failed, accepted composed mechanical session copies
the accepted recipe, mode, solver policy/setup, rig, options, player/environment
profile and owner quality settings into a recovery envelope. The accepted mode
comes from the completed worker context; an unaccepted pending Inspect request
cannot replace it. Repeated Restart requests latch a single deferred reload.

Reload retires the whole old Main, including its accepted and pending Rapier
graphs, and joins the exclusive native worker. Fresh Main construction consumes
the copied envelope once and restores it through normal admission. The rebuilt
session is paused at tick zero with no old command, button or lap history.
Ordinary healthy reconstruction uses the same actor configuration, extracted
into a helper shared with the recovery path.

F2 and visible launcher navigation cancel a queued Restart and clear the
envelope. Cancellation also works after old Main has left the tree but before
SceneTree installs the pending new Main. The selector's PopupPanel owns a
separate input viewport, so its `window_input` forwards F2 to the same navigation
owner. A specific reload error remains visible and allows an explicit retry.

The tests prove recovery after removal of the construction-time fault. They do
not claim that reconstructing a host cures a persistently invalid capacity
configuration.

## Focused regression controls

[`test_play_life007_failed_session_restart.gd`](../../godot/tests/test_play_life007_failed_session_restart.gd)
preserves the original five-rig sequence and **151 assertions**. Each rig uses
an actual capacity failure and verifies the frozen native/Rapier/presentation
boundary. Recovery must preserve the exact accepted recipe, including an extra
static decoration, and accepted settings despite pending form changes. Three
of the five cases include an actual pending candidate that must retire with
the accepted graph. Old worker and adapter references must become invalid;
the fresh owner must make real native and Rapier progress. An old admitted
typed packet must fail at the fresh run fence even when local counters recur.

One LIFE007 case **synthetically sets the reload-error presentation state** to
test its visible text and explicit retry. An actual engine loader refusal is
not injected. That limitation is retained in the raw result.

[`test_play_life008_recovery_navigation.gd`](../../godot/tests/test_play_life008_recovery_navigation.gd)
preserves **62 assertions** over three deterministic event orderings:

- Restart, then F2 before deferred reload.
- F2, then Restart in the same turn.
- Deferred reload, then F2 while no current scene exists and the replacement is
  pending.

All three begin from an actual failed native host and a real pending candidate.
They require old accepted/pending graphs to retire, the immutable failed packet
to stay unchanged, and subsequent manual Play entry to inherit no recovery
envelope or build. Six observed Main-ready events have a maximum of **one**
started exclusive worker. The third ordering observes the actual no-current-
scene boundary and the already joined previous owner. These are automated
Viewport input events and button signals, not physical keyboard or OS-focus
qualification.

The focused
[`play_stopped_session_recovery_case.gd`](../../godot/tests/play_stopped_session_recovery_case.gd)
support script reuses the accepted LIFE001 host apparatus and the seven needed
LIFE006 helper operations. No deterministic sample counts, callback counts,
rig order, construction inputs or assertion conditions are relaxed. Whole
fixtures use `complex_fixture_seconds=3600`, ordinary waits use
`operation_seconds=300`, and first/replacement Main acknowledgment uses
`main_ack_seconds=600`. A predicate becoming true only after its deadline still
fails. The existing external runner gives each selected complex case 3940
seconds, derived from the shared policy, with scale 1.

## Exact committed-source Linux execution

The existing `tools/ci/run_godot_regressions.py::run_case()` executes the five
selected cases at exact commit `35b7008e62d726a50067497c046c33bdbd3729df`.
Each command uses the pinned Godot executable with
`--headless --path godot --script res://tests/<case>.gd`. The recorded command
arrays contain the actual absolute paths. All tracked execution inputs are
unchanged afterward, and every process completes naturally with exit zero.
There is no diagnostic error, skipped check or timeout.

| Case | Assertions / failures | Process seconds | Exit |
|---|---:|---:|---:|
| LIFE007 failed-session Restart | 151 / 0 | 16.772 | 0 |
| LIFE008 recovery navigation | 62 / 0 | 7.336 | 0 |
| Default liquid desktop host | 86 / 0 | 15.723 | 0 |
| UI005 session selection | 90 / 0 | 13.661 | 0 |
| Protected INPUT011 Jet Barrel | 171 / 0 | 4.019 | 0 |

The INPUT011 independent correctness reader also passes in **0.240864 seconds**
under its 300-second operation allowance. It reads the original raw packet,
engine log and engine-process receipt and binds its source inputs to the new
Main hash without changing the protected fixture.

The preceding working-overlay LIFE007 and LIFE008 runs also pass, 151/0 and
62/0, in 15.658 and 6.957 seconds. They remain separately labelled under
`build/play-recovery-validation/working-correction/`; the table above refers
only to the later committed-source cohort.

### Runtime and source identity

| Component | Identity |
|---|---|
| Godot version | `4.7.stable.official.5b4e0cb0f` |
| Official Linux Godot archive SHA-256 | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| CyberSand Linux library SHA-256 | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` |
| Rapier Linux 0.35.2 SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Execution policy JSON SHA-256 | `9eaec2e6318073bff7cfbac209d2d959a751b85ffd63cb94c147e9be237516dc` |
| Corrected Main SHA-256 | `aa3d464ac176615c9a190257b7a8d5f14abf252138cada3dcc85a2642e86ba68` |
| Corrected navigation SHA-256 | `fb8357f636d918762852fa804df55275046c2d38f47bd52888a6d77cda68694c` |
| Corrected selector SHA-256 | `49ef302fbbc9696478817c1acd0c1b67c2fdfc7abb72473168e68f07808d5456` |

### Retained raw evidence

The complete committed-source cohort is retained under
`build/play-recovery-validation/exact-35b7008e/`. `local-validation.json`
contains exact commands, source/runtime hashes, policy identity and original
process results; `performance.jsonl` records advisory timing observations.

| Original file | SHA-256 |
|---|---|
| `local-validation.json` | `ad1dab4966c9bca160246dd95c0d6c1707ca652910bf329c9ba434aaf75dbf39` |
| `test_play_life007_failed_session_restart.log` | `b56618beec6f47356fab604323bc4e487c25c373fc7e53ef7cf861828e840586` |
| `test_play_life008_recovery_navigation.log` | `0a4b38a47adb8988ce8968dafa708bfbb76323c77e6652f3aa7fd1631ae7b3c9` |
| `test_liquid_desktop_default_host.log` | `6553e1b230a20d8a3fd7caae2421acab1eee9c42e70c8c8be7f0411e9514461c` |
| `test_play_ui005_session_selection.log` | `ea77019e94930263b3d307498f87de2081ed5f65fb59691996ec5caf2bc0c370` |
| `test_play_input011_jetbarrel.log` | `94f86abdbf6dba73d8a04b48ab48ad3230cc2b49ea31beea6499b025a09041f4` |
| INPUT011 independent `verified.json` | `6133b4980863afc3a70a3597de383444303e58efe6a60f05a70af721d2e6e84b` |

The two new test scripts are automatically discoverable on Linux and Windows.
Resulting-head hosted execution, Windows behavior, physical device and gamepad
reconnect, OS focus delivery, displayed pacing and human feel remain separate
qualification. No local process duration in this audit is an FPS or gameplay
latency claim. The original failed run, the held #308 campaign and this local
correction cohort remain distinct evidence.

## Current-main reconciliation — 2026-11-02

The owner authorizes completion and a guarded merge of #332 only after all
resulting-source gates pass. Live source authority was refreshed before edits:

| Role | Commit | Tree |
|---|---|---|
| Accepted main | `a8f08a67fea3c58f6df7473cbae1831334fcc04e` | `4bfc2fbdda3704dfbf386235e54d2fe525ca32bc` |
| Final accepted shader #331 | `c24e69ad6310a8c3153c1ab9b680f7c84eb84b20` | `4bfc2fbdda3704dfbf386235e54d2fe525ca32bc` |
| Original recovery #332 | `4752aac3a300ae65da1c578609283c875b8448f8` | `41c0d18589ec5cc8911edcbdc73434556c99dc89` |
| Shared historical base | `6f8f13f0b3c41d156cbb04f5715e5c2651986dfc` | `3d945d358827adeb2600afda4ab7313a291d4c23` |
| Preserved downstream #334 | `4f3decc242633fb621d76b7529ef87b420dbd87a` | `667522c3acb72fcf5b3e40b85a68761c60949ddf` |

The main/recovery and shader/recovery merge bases both equal `6f8f13f0`.
The downstream/recovery merge base is `4752aac3`. The original recovery-only
seven-file patch is 906 additions and 11 deletions; it applies cleanly to current
main, with the same stable patch ID
`a8c32c78593f939cbe8bd637ae7de35c6df4cf7d`. The retained original patch SHA-256 is
`7482e22472ca89d1e0984b18005343bab3529ebff1f7db0b75543034a5797807`.
Its production and fixture hunks are preserved; this new audit section and
canonical documentation are additive. Main's later R rendering seams, worker,
native runtimes, accepted palette initialization, shader and all current
workflow files are retained from accepted main.

Independent source review found no recovery ownership defect. It checked copied
accepted state, pending-mode exclusion, accepted/pending graph retirement,
exclusive worker join, repeated Restart, PopupPanel/root F2, visible launcher
navigation and the pending-scene boundary. SceneTree can instantiate a pending
replacement before removing old Main; the required boundary is retirement of
the old owner before the replacement starts its simulation worker.

### Windows helper-control failure and correction

Original shader run
[41250780073](https://github.com/techrote/cybersand/actions/runs/41250780073)
has six successful jobs and two failed jobs. Windows visual shard 1's portable
preparation runs the 13 helper controls normally successfully, then fails its
optimized-Python run only at `elapsed_seconds >= 0.03`, observing
`0.017978699999957826`. The preceding termination, joined, nonnatural-completion
and nonzero-return assertions passed. Actual ANGLE execution is skipped;
missing `manifest.json` and the final complete-cohort rejection are downstream
consequences. This is not evidence of a shader-pixel regression.

The runner used CPython 3.12.10. Its pinned
[subprocess implementation](https://github.com/python/cpython/blob/v3.12.10/Lib/subprocess.py)
derives Windows pipe-reader thread join time from `monotonic` after reader-thread
startup. Its [clock implementation](https://github.com/python/cpython/blob/v3.12.10/Python/pytime.c)
uses `GetTickCount64` for Windows monotonic and `QueryPerformanceCounter` for
`perf_counter`. Crossing a coarse monotonic tick can reduce the requested join
wait relative to the separate elapsed clock. The exact original tick phase was
not recorded, so this scheduling explanation is an inference. The
[Windows lock implementation](https://github.com/python/cpython/blob/v3.12.10/Python/thread_nt.h)
does not justify attributing the observation specifically to an early kernel wait.

Only `tools/play/test_palette_windows_compiler.py` changes. The real-child
control verifies one actual Popen command/PID, a live owned child at kill,
observed timeout/kill/completed-communicate ordering, a nonzero matching return
code and closed streams before test cleanup. A spawn-budget-exhaustion path is
checked against the same elapsed clock. Elapsed time remains finite nonnegative
telemetry; the 30-ms capture and one-second cleanup allowances are unchanged.
No production helper, shader, policy or workflow change is needed.

Independent review identified and rejected a first-revision weakness: a mutant
passing `min(remaining, 0.001)` could satisfy lifecycle observations. A separate
deterministic early-expiry control now requires the exact remaining requested
capture allowance and cleanup grace. The mutant fails. Existing identity,
malformed-reply, helper-failure, cleanup-error, natural-completion and unobserved-
join controls remain. All 14 controls pass normally and with Python `-O` in
independent Linux execution. Final test-file SHA-256 is
`fce0fcf964206dda438d5ca3f9fd22dd3ce4b61024d9ec18d919c69e3f9108ce`.
These local portable controls are not actual Windows/ANGLE qualification.

### Complete applicable qualification and evidence boundaries

Historical Godot run
[41250780110](https://github.com/techrote/cybersand/actions/runs/41250780110)
has 162 fully paginated job records: 155 success, five failure and two expected
skips. Linux shards 18, 30, 56 and 75 fail their 15-minute software-display
installation step after mirror retries, before regressions start. The fifth
failure is the strict Linux coverage reducer's missing-original-shard rejection.
Actual checkout source is merge `6f5e48883f476041ef5beb71870b86956bd35e01`,
distinct from the API's PR head `4752aac3`. Both original failures are retained.

Current main's reduced scheduler and display preparation are inherited unchanged.
The recovery candidate discovers 250 Linux cases in 20 shards and 236 Windows
cases in 19 shards. It adds only LIFE007 and LIFE008, without changing old case
flags, watchdogs, weights or display eligibility. Both OSes retain five cases
each of LIFE009/LIFE010/LIFE011, all six INPUT011 cases including legacy Pause,
UI005 and the default desktop host. Full coverage should account for 486 cases,
39 imports, 525 sealed logs and 30 protected PLAY readbacks.

Five workflows apply: Documentation/provenance, Native C++ (six families,
165 current source-derived primary cases), GDExtension/Godot, actual-backend
palette qualification (six cohorts, 19 processes and eight Main lifetimes), and
the informational Native scope advisory. Water apparatus and manual desktop
packet paths are unchanged. The old frozen standalone LIFE009 campaign is not a
current-main gate; its five ordinary cases remain mandatory on both platforms.

The published candidate SHA/tree, actual merge-checkout SHA/tree, exact-head
workflow links/counts, original-artifact independent readback, guarded merge and
post-merge identities are recorded in the
[PR #332 completion ledger](https://github.com/techrote/cybersand/pull/332).
At this source checkpoint those execution gates remain required, not presumed
passed. A passing predecessor cannot qualify a new commit. The original failure,
historical successful cohorts, portable control results and resulting-head runs
retain separate source identities.

Documentation changes update the canonical player-control contract and its index,
roadmap, handover and supplementary retrieval question. Existing native/thread
ownership, typed message layouts, capacity constants and ADRs do not change.
All 156 earlier supplementary question objects and the frozen 32-question set
remain intact. The new recovery question is reported separately.

Downstream #334's head, test apparatus and evidence remain untouched. Its next
agent must reconcile its own delta from historical recovery `4752aac3` onto the
accepted #332 merge; ancestry must not be inferred from tree equality or a
squash merge. Physical display cadence, hardware/gamepad reconnection, OS focus
and subjective responsiveness remain separate acceptance areas.
