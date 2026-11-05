---
title: Workbench per-flyer controls and options qualification
status: Current
document-kind: evidence
scope: Desktop per-model keyboard profiles, bounded movement/source overrides and cosmetic thruster display; draft qualification, no contact-law change
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../systems/player-control-playground.md, ../reference/configuration-reference.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md]
---

# Workbench flyer options — 5 November 2026

The owner requested saved per-flyer controls, Kestrel side-thruster inversion,
movement and source multipliers, number keys released for future painting/usables,
and visible thruster graphics. The new PR remains Draft and unmerged. This does
not reopen sleep, response-law, native material or detached-terrain implementation.

## Source and ownership

Fresh fetched main is `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree
`3af18f50e6094776263119623b64a1b2f4ca0ab2`, the accepted PR #394 merge.
The isolated branch is `codex/flyer-options-20261105`, worktree
`C:/Users/_/.codex/worktrees/flyer-options-20261105/khybersand`. The dirty
`C:/khybersand` MAT checkout and retained owner packages are preserved.
The PR commit and compact [qualification summary](flyer-options-20261105.json)
identify the recoverable implementation and tested file hashes; local raw logs
remain under `build/flyer-*` rather than entering the retrieval corpus.

Active PR inspection found separate native selective-arrival/SOL evidence (#400),
physical retention (#399), LiquidDrain (#383), MAT naming (#384), SOL (#393/#347)
and material (#395) lanes. This branch owns only desktop copied configuration,
input, authored-flyer override application, bounded sources and presentation.
It changes no World, adapter, worker, Rapier contact response or native input.

`flyer_preferences.gd` owns a bounded, versioned private value file, with no scene,
Fleet or Rig dependency and no mutable GDScript static state. `flyer_options_panel.gd`
edits a private copy. `shared_workbench.gd` submits its existing prepared-owner
transaction and persists the model profile only after the installed acknowledgement.
Failure to save is visible and retains the accepted session settings. Main-thread
input continues through the existing observation-relative, cancellable action lease.
Opening options pauses/cancels input; closing re-arms only after held keys release.
Rapier and native cells retain their established authority and lifetime contracts.

The existing six workbench comparison values are retained. Advanced multipliers
operate on copied authored values and retain actuator/physics safety caps. Named
starting setups migrate version 2 to version 3 with neutral customization;
explicit instance tuning outranks private preferences. Keyboard bindings remain
private rather than entering map files. Existing instances keep their tuning.
First visits to unsaved models retain the six accepted comparison values during
replacement; saved model profiles supply subsequent defaults. Authored JSON and
definition hashes are unchanged.

Sources retain a finite owner queue, six-tick cadence and path/mask checks.
Rates use deterministic fractional pulses and at most eight candidate cells per
nozzle, three nozzles per body, eight bodies, 64 trace steps per candidate and
1024 occupancy reads per body. Empty endpoints alone admit cells; extra requested
amount can be refused. Only existing authored dispenser ports can choose another
registered material; real thruster Fire remains Fire. Cosmetic cyan/blue exhaust
uses admitted actuator telemetry, at most 160 grid pixels per body, and creates
no native material. Compound Scooper draws one effect per physical body.

## Runtime and qualification boundaries

Tests use actual Windows 11 and WSL Ubuntu 24.04 Godot
`4.7.stable.official.5b4e0cb0f`, Rapier addon 0.35.2/core 0.35.1, deterministic
single-worker host fixtures and isolated test preference paths. The unchanged
84 native inputs match runtime build source
`acce570e667c7e2cc3ef83ab451e7dff262006a9`.
Retained Windows DLL SHA-256 is
`cb675a4cde4317608bb892437af9b9f2b7cddf6a7289a6a028500efab19aae9d`;
Linux SO is `a09a4a60cb54c8f1ca5c339d5ef8c3e230b53fc931b845690211ca33b5dac588`.
No native rebuild or historical runtime-provenance rewrite is needed for this
GDScript-only branch. Materialized dependency/LFS bytes remain required.

Focused checks cover bounded/corrupt/future-version profiles and atomic saving,
fresh-process reopening, neutral behavior of all eight flyers, each multiplier,
Kestrel inversion, admission of source rates/materials, exact Water quantities,
blocked rays and masks, compound exhaust, and actual framebuffer effects. Host
integration covers real Main, native World and Rapier: modal input cancellation,
reserved keys, acknowledged settings, busy-toggle protection, saved model return,
legacy explicit settings and invalid response/budget refusal. The existing twelve
workbench cases run separately on each OS. Commands, process limits, hashes,
counts, diagnostic checks and final-head results are in the compact summary.

Graphical controls are inspected from all three real Linux X11/llvmpipe tabs;
exhaust is exercised on Windows ANGLE/NVIDIA and Linux X11/llvmpipe. These are
render/host controls, not new subjective gameplay acceptance. Human assessment of
new custom combinations, physical keyboard layout/focus behavior, gamepads and
Web remains open. Keyboard bindings are configurable; gamepad mapping retains its
existing controls. Number keys are reserved, not newly implemented paint slots.
No claim is made that arbitrary 64× tuning preserves the default gameplay feel.

## Retained failures

The first existing canvas attempt exposed an invalid `popup_hide` signal on
ConfirmationDialog (a Window). That process was explicitly stopped after the
diagnostic and is not counted as passing. The repair observes visibility changes.
The first UI writer failed three assertions: applying every SpinBox re-read stale
text, and a 0.05 step with a 0.01 minimum quantized neutral 1.0 to 1.01. Only the
focused numeric editor has its text committed before saving; comparison fields use 0.01 increments. The
failed profile and original logs remain local. Corrected Windows writer/reopen
tests pass without diagnostic output.

The first graphical Linux invocation lacked `xvfb-run` (exit 127). Installing the
OS Xvfb/xauth tools changes no project pin or native input. A subsequent real
render run passed all 38 assertions but emitted ALSA device errors and a dummy
fallback warning; it is not a clean host pass. The separately retained clean
repeat explicitly selects the Dummy audio driver, removing audio errors but
retaining a VSync capability warning. Explicit `--disable-vsync` and direct WSLg
X11 also retain that warning. Earlier emission logs contain it too: their receipt
checked errors, not all warnings, so they must not be called warning-clean.
All 124 Linux pixel assertions pass, while its final clean-diagnostic rendering
gate remains unfulfilled. Windows actual rendering is clean. Linux headless host
qualification is separate. No assertion or diagnostic gate is weakened; logs
and receipts retain these distinct outcomes.

The optional broad MAT tooling suite was first invoked from Windows without a
C++ compiler command or symlink privilege: 118 tests ran with eight failures and
16 errors. That environment result is retained, not a material-parity pass.
The source compiler and protected-material compatibility checks pass. The separate
Linux tooling suite ran 77 tests with two setup errors because Linux Git could
not resolve this Windows worktree's `C:/` metadata pointer. That optional tooling
cohort remains unqualified on this machine; no tooling source was changed to
work around it. A GDScript shadow-checker invocation missing its four required
artifact arguments exited 2 with usage text; it did not execute a parity test.

## Reproduction and owner review

From the committed tree, import with pinned Godot and run
`--headless --path godot --script res://tests/test_flyer_preferences.gd`,
`test_flyer_tuning.gd`, `test_flyer_emission.gd`, and the actual-render
`test_flyer_exhaust_render.gd` (the latter without `--headless`). Run
`test_flyer_options_ui.gd` first with an empty `CYBERSAND_FLYER_UI_PROFILE` path,
then in a fresh process with `CYBERSAND_FLYER_UI_REOPEN=1` and the same path.
Use `CYBERSAND_TEST_ARTIFACT_DIR` to isolate all host-case files from human settings.
The exact commands and timeouts used are in the result receipts.

Build the Windows review directory with `tools/package_workbench_review.py` from
the committed source. In the shared workbench select a flyer and **Flyer options…**.
Try Kestrel inversion, bind primary thrust to another nonreserved key, and save.
Compare neutral movement before adjusting one multiplier. Toggle cosmetic exhaust
with real Fire off; then test small Fire/source amounts away from existing cells.
Switch flyer and return, then close/reopen to verify the model profile. Use **[**
and **]** to cycle models, **Tab** to cycle existing bodies, and **P** to pause.
Existing owner acceptance of LA-SA/contact feel is preserved as historical evidence;
this new controls PR has no merge authorization.
