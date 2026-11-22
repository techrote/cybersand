---
title: Workbench playability evaluation
status: Current
document-kind: guide
scope: PUBPRES-PLAYABILITY-001 Draft/HOLD source changes, registered desktop measurements, Windows evaluation and unpassed acceptance gates
canonical-for: [pubpres-playability-evaluation]
last-reviewed: 2026-11-21
related-documents: [pubpres-integration-evaluation.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/simulation-tick-and-threading.md, ../decisions/ADR-003-godot-bridge-and-immutable-snapshots.md, current-and-historical-validation.md, github-development-and-release.md]
---

# Workbench playability evaluation

**Draft/HOLD, reviewed 2026-11-21.** PUBPRES-PLAYABILITY-001 is tracked in
[#717](https://github.com/techrote/cybersand/issues/717) and
[Draft PR #719](https://github.com/techrote/cybersand/pull/719). It adds a bounded,
opt-in staging-allocation change, diagnostic adapter readback, a default-off
same-frame physics continuation, a versioned registered measurement campaign
and an independently assembled Windows evaluator. **No new
graphical playability improvement is established.** The first source-matched
[development campaign](https://github.com/techrote/cybersand/actions/runs/44956244125)
at `a7074ab1bb4fede30d75a7924b4a5bfb7ea963d1` contains valid Windows
software-renderer progression comparisons with negative results, actual queued
GPU-pixel failures, and failed Linux process qualification. Its original results
remain unchanged. Final Linux/Windows qualification and physical Windows/NVIDIA
acceptance remain pending. The source-matched renderer-only run at `0940114ddf8ef65b1f7b088dc5812776a1c02e25`
reproduces engine and history failures without native simulation and verifies
private-display cleanup on its eight Linux arms; it does not qualify full gameplay.
Keep Draft/HOLD: Ready, merge and default promotion are not authorized.

The preceding [PUBPRES-INTEGRATION-001 evaluation](pubpres-integration-evaluation.md)
and [Draft PR #682](https://github.com/techrote/cybersand/pull/682) retain their
original experiments and failures. This successor does not relabel that evidence.
Use #717/#719 for the final frozen candidate identity, review reports, original
artifacts, commands, failures and per-platform results; a branch name is not a
runtime identity.

## Which sources are compared?

| Identity | Frozen source and role |
| --- | --- |
| M: accepted main | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| I: qualified integration reference | `8503ec19e4d620e125dc6df2c5c6571b1256cb92` |
| Preserved #682 head at discovery | `4302ba2058c1bdac1c3fc54540c078dfc9147573`; source reconciliation, not a fresh performance qualification |
| C: this successor | Exact clean candidate SHA supplied at campaign/package freeze and recorded in every new receipt |

**Current apparatus:** every final M/I/C arm requires its own newly built native
runtime for its exact source, with matching compiler and godot-cpp identities.
The [build driver](../../tools/pubpres_playability_build/build_runtime.py) records
the complete native input set, source/tree, build script, driver, log and binary
hashes in `PUBPRES-RUNTIME.json`; it sets `production_runtime_promotion=false`.
The [runner](../../tools/pubpres_playability/run_campaign.py) verifies those
inputs and rejects dirty source, stale native pairs and reused output folders.
Only disposable project copies receive the registered observer overlay and
experimental runtime. Production runtime provenance remains unchanged.

## What changes in staging allocation?

**Current, default OFF:** only
`CYBERSAND_DIAG_MATERIAL_POOL_POLICY=reachable` enables the new pool selection.
Absent or unrecognized values retain `eager`. In
[`blit_material_publisher.gd`](../../godot/scripts/blit_material_publisher.gd),
`_required_staging_capacities()` and `_required_history_staging_capacities()`
omit only allocations that the existing `_submit()` selector cannot use:
differently shaped atlases whose area is at least the actual image area always
select the exact full-image pool instead. An exact-shape full-image alias and
its cursor are retained. The receipt reports `staging_pool_policy`.

Setup still preallocates the complete reachable resource set. The change adds
no lazy gameplay allocation, eviction or new publication fallback. The same
immutable queued inputs, staging slots, logical texture identities, formats,
old/current material histories and ACK ownership remain required. The validator
checks the complete required class set, including inactive pools; an omitted or
forged required class is a refusal.

| Canvas, RG8 and three staging slots | Source-derived logical texture bytes removed |
| --- | ---: |
| 2048 × 2048 square | 0 |
| 2048 × 1024 landscape | 0 |
| 2048 × 1536 admitted Workbench canvas | 25,165,824 |

These are allocation arithmetic, **not measured GPU residency, process RSS or
playability gains**. In particular, the two original large benchmark shapes
save nothing. The primary registered M/I/C campaign keeps C on `eager`; the
reachable-pool comparison is an explicit separate control. Source ownership,
native health, World/session/generation/revision, terrain and exact body-sample
admission remain governed by the linked bridge and lifetime contracts.

## What does the same-frame continuation experiment change?

**Implemented experiment, default OFF; performance unqualified.** Setting
`CYBERSAND_DIAG_SAME_FRAME_CONTINUATION=1` lets Main attempt one continuation
of an actual physics callback that was withheld solely for its awaited native
body sample. The attempt runs at the start of Main's process callback, before
snapshot consumption and presentation. It reads the existing physics mailbox
once with `try_lock`; contention or missing readiness spends the permit without
waiting. The existing fixed-time rendezvous and render-overlap controls are
mutually exclusive with this experiment. Ordinary launch remains unchanged.

The [one-shot permit](../../godot/scripts/workbench_same_frame_continuation.gd)
stores the real callback/frame, body sample, World generation, owner/session,
actor and manual-step counters, installed native terrain revision and bounded
input sequence/generation/lease counters. Another real physics callback replaces
the permit; another process frame expires it. Pause/resume, cancellation,
takeover, prepared replacement, changed terrain, owner retirement, a changed
physical step or changed input refuse it. Owner object identities use canonical
decimal strings because Godot's RefCounted IDs occupy the signed 64-bit range.

An admitted continuation uses the same Main-owned inactive Rapier space and
the same native-response validation, actor advance, fixed-delta step, completion
and body-publication transaction as an ordinary callback. It creates no engine
callback, accumulated time debt, native tick, input refresh or additional terrain
installation allowance. It does not add a wait for rendering or native work.
Every response remains subject to the unchanged native body/wrench/history
validator. A failed attempt is retained as a failure, not physical progress.
The existing session transaction still performs legitimate scripted/policy input
and lease expiry. The new observation corpus uses a human Needle; its unchanged
post-step input proof must not be generalized to other producers.

The prospective
[v3 observer](../../godot/tests/pubpres_same_frame_gameplay.gd) and
[v3 reducer](../../tools/pubpres_playability/results_same_frame.py) preserve the
original v2 files and receipts. Both full and reduced v3 observation retain real
callback identities; continuation attempts have a distinct event type. Every
completed step must spend one unique callback, and every deferred step must use
the same frame, exact sample/World/terrain and unchanged admitted input. The
first-144-step body and move oracles, native Water ledger, capture limits and
source/runtime checks still apply. Native publication age uses the first matching
healthy packet. Physical execution clocks and engine callback clocks remain
distinct. Neither hosted software rendering nor a headless guard test establishes
physical Windows/NVIDIA playability acceptance.

The focused tests are
[`test_workbench_same_frame_continuation.gd`](../../godot/tests/test_workbench_same_frame_continuation.gd),
[`test_workbench_same_frame_integration.gd`](../../godot/tests/test_workbench_same_frame_integration.gd)
and [`test_results_same_frame.py`](../../tools/pubpres_playability/test_results_same_frame.py).
The real integration fixture delays delivery of an already genuine native packet;
its result is admission/lifecycle evidence, not a gameplay performance comparison.
Exact frozen-candidate graphical ABBA and independent review remain required.

The current [v3 registration](../../tools/pubpres_playability/campaign.json)
explicitly selects continuation ON for primary C and OFF/ON/ON/OFF for six
same-source controls. Application and owner-launch defaults remain OFF.
The [frozen development-01 v2 registration](../../tools/pubpres_playability/campaign-development-01-v2.json)
retains SHA-256 `d44ba75d49c708de409633659caadeb9f284c69623c649296342ec5c89ef1286`.
The old observer/reducer keep their original meaning. V3 reduced observation
retains compact callback-credit evidence and requires its own overhead control.
At an exact time or first-N-step cutoff, continuation completions use the actual
Rapier step timestamp, separately from completed/censored attempt observations.
An independent reviewer found and repaired that endpoint-count distinction
before any v3 graphical campaign; old evidence was not recalculated.

## What remains from the native experiment?

**Rejected:** the four-column locality prototype at
`90c126a1aba9b8f28b9b0b5eafd7ce77eddb08ef` produced inconsistent complete-tick
ABBA results and a small-fixture regression. It was explicitly reverted in
`d621cc9f1`; differential correctness did not establish a useful speed gain.
The delivered `native/` tree is identical to frozen main846f, tree
`e6946f5c5d47eddd6118696b124470737cdd385e`. There is no selected native Water
optimization.

**Current adapter diagnostic, default OFF:** boolean ProjectSetting
`cybersand/pubpres_wave_column_probe`, captured before World creation, exposes
existing cumulative prepare/column/flux/apply/merge/launch counters and retained
storage through `CyberNativeCellWorld::get_wave_flow_status()`. Its
`PUBPRES-WAVE-COLUMNS-V1` readback declares `experimental_column_tiles=false`
and `column_slots=1`. It adds no per-cell clock, native task or simulation
authority. Enabling retired `cybersand/experimental_wave_column_tiles` or using
malformed non-boolean settings refuses initialization. See the
[adapter](../../godot/native_extension/cyber_native_cell_world.cpp).
Primary timing keeps the probe OFF; OFF/ON/ON/OFF is a separate overhead control.

Independent review found and repaired two adapter initialization/recovery
defects at `573be3512e388900f93eff48c4c86490597e0df7`: missing-World Wave status
now retains the explicit native failure, and successful diagnostic reset stages
a missing render exchange before committing the replacement World. Recovery
must again publish real edited material; it cannot report a healthy World with
no material exchange.

## Registered playability workloads

**Current apparatus; partial development execution, final campaign pending:**
[`campaign.json`](../../tools/pubpres_playability/campaign.json) owns the v2
registration, fixture/profile/overlay hashes and exact controls. The
[measurement guide](../../tools/pubpres_playability/README.md) owns commands.
The original v1 campaign, overlays and evidence remain unchanged.

| Cohort | Cases and fresh-process order |
| --- | --- |
| Historical Wave reference | Five cases: 512² Free/Follow, 2048² Free/Follow and 2048 × 1024 Follow; M–I–C–C–I–M; one round, no spill or ballistic transport |
| Other Water families | Four cases: FreeMass 512² Free and 2048² Follow, PressureFlow cached/dormant 512² Follow, CellularYield 512² Follow; M–I–C–C–I–M |
| Neutral input | Wave 512² Follow; M–I–C–C–I–M |
| Current main846f gameplay Wave | One 2048² Follow case; M–C–C–M; two rounds, spill and ballistic transport, every registered native parameter checked |

The ten historical cases and one current gameplay case are distinct workloads.
Unchanged I cannot express the current gameplay profile: it lacks the
`gameplay_water_options` API and seven required readback fields. An **untimed
compatibility refusal** retains that limitation; it is not replaced by guessed
zeroes or an unsupported timed I arm. Extended landscape Free and large
PressureFlow/CellularYield cases are separately selectable; a subset is not the
complete matrix.

Every primary capture uses the actual native World and Needle/Rapier owner,
requests four native workers, and records actual task participation. The window
is 1600 × 900, VSync is requested off, presentation is capped at 60 FPS, and the
existing Rapier step remains 1/60 second. Capture requires both ten elapsed
seconds and 144 completed physical steps, with a 90-second capture cap and
240-second setup cap. Requested workers and delivered callbacks cannot stand
in for actual native participation or completed Rapier steps.

## Input, observer and render-thread controls

The primary `repeated_callback` policy preserves ordinary held-input refresh.
Every attempted command and actual admission/refusal is recorded with sequence,
completed physical tick and six-completed-tick lease deadline. All eleven tape
transitions must occur at their registered steps. The accepted Vector2 action is
retained separately from the raw tape; each completed step must match its actual
preceding accepted sequence, lease deadline and move. Real `RigidBody2D` roster
and Rapier RID ownership are checked before/after and for each step.
Full first-144-step body
trajectories and admitted moves are compared for each same-source pair before
causal timing attribution. Cross-source outcomes and command counts are
disclosed: equal initial workload does not guarantee equal physical outcomes
across distinct source versions.

| Separate candidate-only diagnostic | Registered order and interpretation |
| --- | --- |
| Input equivalence | Repeated/once/once/repeated; once-per-step cannot replace primary input without equal-step body and admitted-move parity |
| Observer overhead | Full/reduced/reduced/full; v3 reduced observation retains callback-credit and body/command oracles and is not uninstrumented |
| Render owner | Original v2 Safe/Separate/Separate/Safe registration preserved; retired from v3 after engine failures, with independent renderer probes retained |
| Native stage readback | OFF/ON/ON/OFF; primary C stays OFF because dictionary packing occurs before the physics mailbox |
| Same-frame continuation | V3 OFF/ON/ON/OFF; Safe only, same source/runtime and unchanged first-144 body/move oracles |

The six registered v3 continuation controls cover small and large Wave, current
gameplay Wave, PressureFlow, FreeMass and CellularYield. Keep source, native
workload and input fixed within each control. No measured overhead is silently
subtracted, and different render modes are never pooled as identical controls.
Ordinary launch defaults remain unchanged.

The [v3 gameplay observer](../../godot/tests/pubpres_same_frame_gameplay.gd)
bounds Main/worker traces and command attempts at 30,000 each; overflow fails
capture. Full material readback, PNG and JSON output occur outside timing.
Native capture records the actual `force_full` argument and returned status
without an additional native query. Missing historical clocks or disabled
probe fields remain null. Full observation requires actual Main, physics,
native-completion/capture, worker-snapshot, upload and draw channels.

## Isolated render diagnostics

**Current diagnostic tooling; executed at source `0940114`:** the
[isolated renderer probes](../../tools/pubpres_render_probes/README.md) run
before native builds with the exact pinned engine and no GDExtension. Four
Linux font controls or two Windows empty-scene controls are followed by four
R8 material cases on each platform: Safe reachable slots 2/3 and Separate
reachable slots 2/1. Linux owns and joins its private display; Windows uses
its hosted desktop. Every actual Godot child has a 60-second bound plus owned
cleanup. All ordinary failed arms are retained before aggregate nonzero;
cancellation or uncertain ownership records the remaining arms as not run.

The material project keeps exact a707 publisher/shader/fixture copies and the
original first current/previous full-byte oracle. Only post-burst observations
add staging-layer, repeated and later-frame readback. Later correct bytes cannot
erase a first-read failure. Source, engine, script, receipt PID, nonce and empty
loaded-extension identity are joined. These native-independent diagnostics are
separate from pacing and do not establish a gameplay improvement, native or
package acceptance, physical NVIDIA qualification or Separate promotion.
The [focused retrieval questions](../reference/retrieval-questions-pubpres-render-probes.json)
are additive to the unchanged general and earlier mission questions.

The [renderer-only campaign](https://github.com/techrote/cybersand/actions/runs/44962312107)
attempted every registered arm. Linux Safe/text, Separate/empty and
Separate/text-with-mipmaps completed; ordinary Separate/text reproduced the
Image-upload crash. Both Safe material controls passed. Separate/two-slot
material history failed its original first-read oracle; Separate/one-slot passed.
On Windows, all three Safe controls passed; all three Separate/ANGLE controls
failed before script receipts, including the empty scene. These results narrow
the engine/lifetime hypotheses but do not prove a full-Workbench repair or
erase the original intermittent Safe queued-pixel failure. All original logs,
receipts and raw byte arrays remain retained. Hosted renderers are not NVIDIA.

## What do the timing and memory receipts establish?

The [v3 reducer](../../tools/pubpres_playability/results_same_frame.py) retains first-ten-second,
first-144-step and whole-capture windows, quantiles, maxima and consecutive gaps.
It separates native completion, the first healthy mailbox, callback/real Rapier
completion, material age and publication calls. Packet joins include World
generation, native tick, body sample and terrain revision; republishing a status
does not reset the first healthy packet's age. Failed, partial, timed-out and
divergent arms remain visible. At most the first real step may consume the
recorded pre-capture native tick/sample -1. A final early-mailbox step may precede
its full-snapshot hook; that single possible trailing observation gap is
disclosed with unavailable age left null. Neither exception relaxes the
90-second capture cap or supplies an invented zero-age receipt.

`upload_return_to_next_delivered_draw_callback_ms` measures a **delivered
software callback**. Especially under Separate rendering, `frame_post_draw`
does not identify which upload completed, GPU completion or display scanout.
Stage wall time alone cannot separate CPU execution, driver waiting and OS
descheduling. Faster upload calls or frequent callbacks do not prove playable
progression.

Process memory is sampled every 250 ms: Windows working set/commit through
`GetProcessMemoryInfo`, Linux through `/proc`. The sampled PID must match the
actual Godot receipt PID. Windows virtual size remains unavailable. Each arm
uses isolated user-data/cache directories; driver-global caches remain
uncontrolled and ordering is balanced.

The independently reread original `1f04f2ad` Windows ANGLE/WARP traces contain
roughly 751 ms first-healthy-mailbox-to-Rapier maxima. They establish late
delivery after mailbox availability, not a unique GPU cause or a physical
NVIDIA result. The requested original `8503` NVIDIA raw archive was not located;
its timing claims remain report-level. The earlier `6a6a7060` TITAN RTX upload
is a different source, one-worker, non-Wave experiment. Keep all three scopes
separate and consult the preserved #682 evidence through the preceding evaluation.

## Windows verification, isolated profiles and reopen

**Current tooling; first archive built, final package qualification pending:** the
[Windows evaluator guide](../../tools/pubpres_playability_windows/README.md)
provides the exact PowerShell commands and controls. Its new package is named
`CyberSand-PUBPRES-PLAYABILITY-001-<candidate first 12 SHA characters>-Windows.zip`.
The launcher accepts the inner ZIP or a GitHub artifact wrapper containing
exactly one matching package and adjacent checksum. It requires the full
expected candidate SHA, verifies the archive and every payload file, and
refuses extra files, stale destinations, ambiguous packages and mismatched
source/runtime identities. A renamed old evaluator is not a valid package.

M/I/C contain separately built native libraries. Verification covers source
closure, native receipts/build inputs, Godot, retained Rapier provenance,
required VC runtime and notices. The original production receipt is retained as
historical data and cannot authenticate the new library. Registered archive
measurements verify this full manifest and the exact declared roots; an extracted
package is not represented as a live Git checkout.
The retained production libraries remain stale for the changed adapter; new
experimental receipts do not waive that provenance gap or authorize promotion.

The ordinary graphical launcher opens the real Main scene. `-Source` selects
Main/Integration/Candidate; Candidate, Eager, Safe and native `opengl3` are its
defaults. Reachable pools are candidate-only; Separate is an explicit comparison,
and `opengl3_angle` identifies a different renderer. Each fresh run copies the
source and owns a new profile outside pristine `Payload`. `-ReopenRun` reuses
that same profile after verifying application/native sources against the
pristine package; explicit selectors must agree with the original run.

Readiness and PID/memory receipts establish installed-World startup only.
Actual movement/contact, camera, pause/resume, painting, Apply/Undo, regenerate,
Save start, close/reopen and native material-plane comparison still require
their own evidence. Preserve the run profile, launch records and all failed
child, cancellation/timeout, stale-folder and corruption results.

## Evidence available and remaining gates

| Evidence as of 2026-11-21 | Scope and outcome |
| --- | --- |
| Native source comparison | Delivered `native/` equals main846f; four-column experiment remains reverted |
| Repaired adapter regression | 222 local headless checks passed against source `573be351`, with final test bytes from `1c949532`; Linux/GCC 14.2 toolchain drift explicitly recorded |
| Actual queued GPU staging histories at a707 | All 23 ordinary history cases pass internally; queued Separate slots 2/3 have eight current-plane mismatches, and Safe reachable R8/slots 2 has one. Previous planes match. Original failed first reads remain failures; no later await/read substitutes for them |
| Logical allocation model | Confirms the bounded source arithmetic above; no RSS/residency or frame-rate result |
| Windows Wave512 Follow MICCIM at a707 | Six admitted processes; first-144 body/move hashes match. Mean rates M 11.414, I 9.636, C 9.248 steps/s. C is 18.98% below M and 4.03% below I in these two repeats; C maximum physical gaps are 817.639/821.692 ms despite approximately 1.6 ms median upload calls |
| Windows observation/input/probe controls at a707 | Full/reduced, repeated/once and native-probe OFF/ON controls retain matched physical outcomes. Small or negative timing differences are reported without subtracting an assumed diagnostic overhead |
| Actual Separate renderer controls at a707 | Windows ANGLE fails at GLAD startup; Linux full-Workbench Separate fails inside the engine Image upload path. These are distinct failures, not zero-throughput samples or physical NVIDIA evidence |
| Linux process qualification at a707 | Original xvfb-run invocations leave owned descendants. Their internally complete captures remain process-invalid. A private, bounded display owner has independently reviewed process-only repairs; hosted X11/Godot evidence is still required |
| Windows evaluator at a707 | Newly built archive and all 3,492 payload hashes verified. Unsafe-path test helper shadowed its actual input, so the package gate failed and later graphical gates were skipped. The source-only correction preserves the validator; original failure is not reclassified |
| Final measurement/build/package tooling | New source-matched final campaign, complete Windows source/installed graphical qualification and owner exercise remain pending |
| Owner physical Windows/NVIDIA | Pending; software rendering, metadata checks and headless tests cannot supply this acceptance |

The adapter check covers copied counters, 24-tick ON/OFF neutrality, a closed
Water basin and invalid-initialization recovery. It does not establish all Water
families, spill/ballistic gameplay, general parallel determinism or human feel.
The queued GPU failures require a causal repair and new complete history
qualification. Isolated prospective font/context/material probes distinguish
engine startup, mutable atlas uploads, stage contents, blit execution and
readback; a diagnostic probe cannot replace the unchanged full pixel oracle.

The [scoped workflow](../../.github/workflows/pubpres-playability.yml) and
[measurement guide](../../tools/pubpres_playability/README.md) route prospective
source-matched execution. Freeze source, registration and overlays before final
runs; retain every failure and the declared case coverage. Full current
source/runtime provenance remains a separate gate: the retained production
libraries are stale for the new adapter, so the ordinary repository check must
report that gap. An experimental build receipt does not waive it or authorize
rewriting historical provenance.

Documentation checks use `tools/ci/check_docs.py`,
`tools/ci/check_m11_consistency.py`, `tools/ci/check_repository.py` and
`tools/docs/retrieval_eval.py`. The separate
[PUBPRES playability retrieval questions](../reference/retrieval-questions-pubpres-playability.json)
are additive; the frozen general questions and historical corpora remain intact.
