---
title: PLAY INPUT011 immediate ordinary UI and focus revocation
status: Current
document-kind: audit
scope: Candidate shared-course input-authority correction, actual-host Linux failure and five-rig regressions; no device, OS-focus, graphical or promotion acceptance
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md, 2026-10-31-play-input010-pause-transitions.md]
---

# INPUT011: immediate ordinary UI and focus revocation

## Reconciliation and exact ownership

The live [#268](https://github.com/techrote/cybersand/issues/268) contract retains
input ownership across focus/modal transitions and stale-edge cancellation.
Accepted INPUT010 already handles P/Escape, selected gamepad Start and explicit
Play-panel resume. This package corrects ordinary paths outside those handlers.

Accepted main at reconciliation was
`afa8185c8dc57405ef54765a6cdf71cb7bfbf6e4`, tree
`6ec0ca07a9f49c4c3039b52c87d15414582c31e5`. This isolated branch starts from
the reviewed but unmerged UI007 candidate
`b255bd83d24c8656724f5f067b6e3ecd80f88bbb`, tree
`8b19ba953d3d73cd06017270074dfe8a47a94518`. Neither that base nor this package
is asserted to have completed its resulting-head hosted gates.

Production ownership is limited to
[`main.gd`](../../godot/scripts/main.gd)'s existing actor/tuning/GUI/window
admission paths and
[`microscenario_panel.gd`](../../godot/scripts/microscenario_panel.gd)'s one
Pause/resume callback. They use the accepted
`cancel_playable_course_input` / `toggle_playable_course_pause` APIs.
The actual native owner, World, actor session and main-thread Rapier remain
unchanged. No independent command FIFO or simulation owner is introduced.

Held #308's failed-SetP recovery, open-selector F2 and LIFE006–008 ownership is
untouched. Shader/cache/decomposition work, held #310 and frozen #312/#316 remain
outside this work. Scheduswarm stays paused.

## Actual defect and failing-before evidence

Before a physics callback, admit a Space press/release followed by held movement.
Opening and closing the actor picker only set the rearm flag; it did not clear
the authoritative command or pending edge FIFO. The next publisher returned
while the key was held, but the existing actor session still consumed that
command and its queued primary press. Replacing the command with a neutral
sample would also preserve the ordered old press/release queue.

The tuning panel had only a visibility toggle. The MicroScenario Pause/resume
button directly assigned `host.paused` and bypassed INPUT010's central setter.
Rapid GUI focus acquisition/release and window-focus notifications similarly
had no immediate cancellation path in shared Main.

Source `7de9eee795a47497d796561728f821a02781b48d`, tree
`721d2539989301b1e15b69f3e570c881ef4b771d`, adds only the new fixture and five
wrappers to unchanged b255 production. Its original Acrobat run uses actual
`main.tscn`, native construction, one production worker and automatic Rapier.
It exits **1**, with **125 assertions / 21 failures**, in 3.335112 seconds
(2.031022-second fixture; 51,817-microsecond joined teardown).

All five transition paths preserve **two old edges and the old generation**
with no intervening Main or physical callback. The next completed actual Rapier
step applies `primary=true` and the held movement. Twenty failures concern
those missing immediate/physical-step guarantees. The twenty-first records that
old production has no new cancellation call for the matched negative seam to
intercept; it is not a timeout or missing-runtime failure.

The original result SHA-256 is
`0f7be469c431f004abd5b2adbbb0cd521bd1865232f0aec329cb4144795cdb64`;
stdout SHA-256 is
`04e50613b7315df2168fa7803ff9b88ce6f166f9712cf2980a132d8b7970e126`.
Original logs, process receipts and before/after input hashes are retained in
`qualification-input011/baseline-acrobat/`. The preceding 240-second-bounded
headless import succeeded in 4.529364 seconds. It is not graphical warmup.

## Correction and regression semantics

- Actor picker and Player / Environment Tuning opening revoke course authority
  synchronously through the existing API.
- Root-viewport GUI focus acquisition does the same. Focus release alone never
  rearms a held control.
- Main's ordinary `NOTIFICATION_WM_WINDOW_FOCUS_OUT` handling revokes immediately,
  even if focus returns before the next callback.
- The visible MicroScenario Pause/resume button uses the accepted course pause
  handler while a shared course is active. Its non-course legacy toggle remains.

Every path preserves the same worker, session, bridge, run, actor epoch and
World generation. Cancellation advances the existing control generation,
clears old edges/leases and retains the existing native-equipment cancellation
signal. No native operation or new sampling loop is added to input callbacks.

The [fixture](../../godot/tests/play_input011_authority_case.gd) invokes actual
production toggle handlers, the existing Button's pressed signal, a real
LineEdit focus acquisition/release and the production Node notification dispatcher.
**Window-focus predicates/notifications are synthetic.** No OS manager delivery
or physical device qualification follows. The test records that the full
open/close pair occurs before any Main/physics callback can poll the context.

For each positive transition, at least three later completed Rapier steps must
remain neutral with no admitted old action while the key stays held. A retained,
still-in-lease old observation must fail specifically for
`observation_not_issued`. After neutral release and repress, actual admission
and copied applied movement must agree on sequence/generation in completed
physical steps. That recovery uses the exact production transition generation,
without additional test cancellation.

A matched negative bypasses only the cancellation call while retaining the real
actor-picker handler, native owner and automatic callbacks. Its first completed
Rapier step must actually apply the stale primary edge; the oracle requires
`stale_input_applied`. Cleanup is explicit and restricted to the negative or a
failed old-production control.

## Committed-source Linux execution

The initial correction `36ec3160ec583086c976c4768e98fd553bc1217f` passes the
unchanged Acrobat fixture, 130/0, in 3.474191 seconds. A subsequent strengthening
removes test cleanup from successful recovery and binds fresh input to the
production transition generation.

Exact strengthened source
`513ae1be594a791177a671fa9523257334657f4b`, tree
`3babc2c004bb05118bf1459e03383b0de1ca5b28`, passes:

| Rig | Assertions / failures | Fixture seconds | Process seconds | Teardown microseconds |
|---|---:|---:|---:|---:|
| Stunt Buggy | 145 / 0 | 2.033783 | 3.373277 | 53,528 |
| Trials Bike | 145 / 0 | 1.994090 | 3.374009 | 42,351 |
| Acrobat | 145 / 0 | 2.042675 | 3.274062 | 52,950 |
| Arcade Lander | 145 / 0 | 2.024138 | 3.375431 | 41,186 |
| Jet Barrel | 145 / 0 | 2.009998 | 3.373299 | 56,094 |

This is **725 assertions / zero failures**, 25 corrected production transitions,
five actual cancellation-bypass negatives and five joined real host lifetimes.
Each run records 42 completed physical steps across neutral/held/fresh phases,
33 bounded waits and one first-Main acknowledgment. First-Main intervals are
258,196–274,677 microseconds. These are semantic regression measurements on a
potentially contended local host, not representative pacing or displayed FPS.

All tracked execution inputs were unchanged before/after every process.
Generated editor metadata remains separately identified in the retained Git
status; it is not committed or labelled authored source. Native/runtime/solver
and protected scientific inputs are unchanged from b255.

Pinned runtime:

| Component | Identity |
|---|---|
| Godot | `4.7.stable.official.5b4e0cb0f` |
| Godot executable SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Native Linux library SHA-256 | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` |
| Rapier Linux 0.35.2 SHA-256 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Fixture SHA-256 | `92c43aca823484910c987ba9db0b788e04ed46623928e334b1ba194bd5ed0903` |
| Main SHA-256 | `95f95bd4a57687dd4e9986c1705821881e2af85eb358a1859543bafd27503d1f` |
| MicroScenario panel SHA-256 | `60a30f1ff401bd3a2548c1c629d6e27be8a1af815c06cabe5bf0b48f316db2f3` |

## Independent raw readback and preserved test correction

[`verify_play_input011.py`](../../tools/ci/verify_play_input011.py) executes no
engine. It checks the original process exit/status/deadline and sole raw result,
binds runtime-read script hashes to the declared Git revision, and independently
reconstructs all transition, callback, ownership, edge, generation, completed
step, native-progress and recovery claims. Signed Godot ObjectIDs remain valid;
a newer checkout does not relabel historical execution bytes.

All five retained results pass the reducer and **20 reason-specific trace
mutations plus five process-evidence negatives**, normally and with Python
optimization. The controls reject retained old input, missing physical
completion, neutral-only recovery, expired authority, missing or duplicate
transitions, interrupted callback gaps, wrong source, no native progress,
incorrect bypass reasons, unjoined owners, false physical claims and
post-summary nonzero/timeout/incomplete processes.

The actual retained synchronous controller also reuses the MicroScenario panel.
Its [legacy regression](../../godot/tests/test_play_input011_legacy_pause.gd)
checks the same real Button's fallback behavior in the ordinary Godot scene.
The first oracle at `66f271f4489d74b7f200b7ed33ac689f8bfdf8a4` incorrectly
assumed that controller lacked Main's course predicate; it inherits Main.
Original **8/1**, exit1, remains a test-assumption failure in
`qualification-input011/legacy-before-guard/`. Both pause/resume operations
already succeeded. No production guard or semantics change was justified.

Corrected oracle `f8c9396c6cc8654a5a55d681328adbd64d1ff9a2` checks that the
actual owner is outside the shared-course route and passes **8/0** in 2.070441
seconds. This is legacy Godot-controller compatibility, not browser/Web export
qualification. The five-rig production and fixture bytes remain identical to
513ae1b. Later reducer/audit commits do not relabel the earlier engine runs.

Four unchanged neighboring regressions also execute at f8c9396 through the
existing ordinary process runner, each under its original 180-second bound:

| Existing case | Assertions / failures | Process seconds |
|---|---:|---:|
| INPUT010 Acrobat | 103 / 0 | 4.108 |
| UI005 session selection | 90 / 0 | 13.328 |
| MicroScenario controllers | 55 / 0 | 4.919 |
| UI007 Acrobat | 59 / 0 | 5.511 |

All four original process records are passed with exit zero, no skipped or
diagnostic error, and identical tracked input hashes before/after execution.
The **307/0** assertion total checks the already accepted pause route, ordinary
selection, shared legacy panel and candidate presentation/navigation together.
It is focused Linux compatibility evidence, not the complete ordinary matrix.
Original logs and process rows are retained in
`qualification-input011/unchanged-regressions/`.

Documentation, current repository integrity, retained M11 integrity and
GitHub-hosted-provider policy checks pass. The unchanged retrieval corpus
finds all **32/32** canonical routes within the top five (19 at rank one).
That lexical result does not establish answer sufficiency. These source-only
receipts are retained under `qualification-input011/source-checks/`; the
parent integration still owns canonical documentation and its resulting-head
checks.

## Reproduction and integration boundary

From a source-matched, materialized checkout and the pinned executable:

```bash
timeout 240s /path/to/Godot_v4.7-stable_linux.x86_64 \
  --headless --path godot --editor --quit --log-file /outside-checkout/import.log
CYBERSAND_SOURCE_REVISION=$(git rev-parse HEAD) \
  timeout 180s /path/to/Godot_v4.7-stable_linux.x86_64 \
  --headless --path godot --script res://tests/test_play_input011_acrobat.gd \
  --log-file /outside-checkout/acrobat.log
```

Retain stdout and the original process receipt. Repeat the distinct registered
rig cases, not a failed unchanged case to obtain green. The source-matched
parent process runner owns platform/runtime provenance and complete coverage.
Offline readback takes the original stdout log and process JSON:

```bash
python3 tools/ci/verify_play_input011.py \
  --log /outside-checkout/acrobat.stdout.log \
  --process-json /outside-checkout/acrobat.process.json \
  --source FULL_40_CHARACTER_EXECUTED_SOURCE_SHA --rig acrobat --self-test \
  --output /outside-checkout/new-readback.json
```

The existing bounds remain **30s first Main acknowledgment, 15s operations and
teardown, 150s whole fixture, 180s process, 240s import**. Root owns ordinary
registration, canonical routing, full resulting-head hosted gates, independent
final review and guarded integration. No local success is full qualification,
and #268/#269/#270/#263 remain open for their actual remaining requirements.

## LIFE010 integration and focused-button correction

The independent integration starts from local LIFE010 commit
`9edbec0e1b6680191de8d853e6e31b883fa3eaf8`, tree
`202dff82709b4f7a2c05adc23a0e5fd766a7dca0`, identical to published #323
`480f896d8bedf128e798ee0c6221782064fad8d9`. Original INPUT011 final source
`887842a56e144edb5c7636afef71f9ceb228868c` and every earlier artifact above
remain retained. Cherry-picking this package is not resulting-head qualification.

Independent source review found one additional explicit-button defect. The
MicroScenario button used `toggle_playable_course_pause`, whose keyboard/UI
ownership guard correctly refuses a shortcut while the Seed LineEdit owns
focus. That same guard incorrectly refused the visible explicit button.
The button has `FOCUS_NONE`, so clicking it does not release the text owner.

The v2 actual-host fixture adds that combined sequence to the original five
transitions. With two pending edges admitted, it acquires real Seed focus,
presses the existing button, checks that the keyboard toggle still refuses,
presses the button again and releases focus before any Main/physics callback.
It then requires completed neutral held-input steps, lease-valid old-authority
refusal and fresh applied input on the production transition generation.
This is an additional concrete UI ownership interaction, not a real OS-focus
or physical-device claim.

Failing-before integration source
`f4feb81d9e50a2042f8a5954d096f189e79d98af`, tree
`382640fae737e966a229c04bc07f9e0e4b95f524`, preserves the old button handler.
Its actual Acrobat process exits **1**, with **171 assertions / two failures**,
in 3.439 seconds (2.150799-second fixture, 40,030-microsecond joined teardown).
Seed focus remains owned, the keyboard toggle correctly refuses, and both
button clicks leave `paused=false`. Control generation advances from eight
to nine for focus acquisition, then remains nine through the button clicks.
Both failures identify explicit-button admission/setter absence. The original
log SHA256 is
`f6d8d8aebf7d8695063bd275032cc350ff366b06a8da9cab68c47622493f3c64`,
retained in `qualification-input011-integration/focused-button-before/`.
Its preceding bounded import passes; all 962 captured inputs stay unchanged.

The one-line production correction calls
`set_playable_course_paused(not host.paused)` for the explicit course UI button.
It leaves Main's keyboard/gamepad context-gated toggle byte-identical to
887842a, and retains the non-course legacy branch. Intermediate source
`428993b6089adf30dd9c0fbb3c1b3926d741bd69` passes Acrobat 171/0 through the
new parent gate. That separate result is retained in `fixed-acrobat/`.

### Mandatory common parent readback

The ordinary runner now factors LIFE010's existing mechanism into an explicit
`ReadbackContract`. LIFE010's public entry points and tests remain. INPUT011
registers exactly the five rig wrappers; its legacy-controller test retains
ordinary execution. A subsequent fixture can register its own verifier and
dependencies without another process runner.

For INPUT011 the parent retains the exact raw log payload, canonical verifier
identity, consumed scripts, rig wrapper and shared-host helper, and before/after
process/log/result/source digests. A successful engine footer cannot override a
failed, missing, malformed, late, mutated or mismatched readback. The parent
requires six production transitions, one actual bypass negative, at least 21
held and 21 fresh completed steps, all 23 trace controls and all five process
controls. The existing 15-second readback budget covers identity checks,
execution and validation together. Windows `INPUT_SCOPES` includes the verifier.

Independent review caught an initial parent-only overconstraint: requiring
exactly 21 samples could reject a valid trace when multiple physics callbacks
complete before `process_frame` resumes. The parent now retains the fixture's
existing minimum and the verifier's complete per-step checks and 512-record
cap. Explicit 22-sample positive and 20-sample negative controls establish this
alignment; no operation or acceptance deadline changes.

### Frozen integrated Linux execution

Exact executable source **`796eb58f0b78a9e3cc549bd95ab9136942da96ec`** passes
the actual ordinary runner, including mandatory source-bound parent readback:

| Rig | Assertions / failures | Process seconds | Fixture seconds | Readback seconds | Teardown microseconds |
|---|---:|---:|---:|---:|---:|
| Stunt Buggy | 171 / 0 | 3.615 | 2.199885 | 0.184451 | 62,065 |
| Trials Bike | 171 / 0 | 3.438 | 2.150357 | 0.182476 | 58,138 |
| Acrobat | 171 / 0 | 3.623 | 2.115547 | 0.183612 | 52,061 |
| Arcade Lander | 171 / 0 | 3.515 | 2.158273 | 0.183774 | 38,852 |
| Jet Barrel | 171 / 0 | 3.708 | 2.277952 | 0.182991 | 48,017 |

This is **855/0**, thirty positive production transitions, five real bypass
negatives and five joined host lifetimes. Each fixture records at least 49
completed physical samples and 38 bounded waits. The actual legacy-controller
button fallback separately passes **8/0** in 1.836 seconds. All original
processes exit zero, all parent readbacks pass, and all 962 tracked execution
inputs remain unchanged before/after each case. Original directories are
`qualification-input011-integration/final-<rig>/` and `final-legacy_pause/`.
Runtime binary identities and physical/graphical scope remain as recorded above.

The complete parent-runner unit suite reports **73 passed / zero failed** and
one explicitly skipped Windows-only process/thread observation on Linux. That
skip is not Windows evidence. The 48 focused old/new readback controls all pass.
Later documentation or integration commits do not relabel these engine results.
Full resulting-head hosted gates and independent final review remain required;
no local result supplies graphical, device, OS delivery or human acceptance.
