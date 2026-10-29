---
title: PLAY-PACE-002 constructed-policy gameplay measurement candidate
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Unexecuted five-rig measurement candidate using positive native liquid-construction receipts
related-documents: [../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# PLAY-PACE-002 — constructed-policy gameplay windows

## Status and source

**Unexecuted candidate. No timing result, runtime acceptance or merge claim.**
Base: accepted `main` `aac0feb65e2268b74975892ce1df81e04e1a7e40`, tree
`a2ddee9e54a570d56e6e9b68285281c1921b8f0f`.

This is a separate lane from unmerged pacing #296 and mutex attribution #297.
It inherits accepted `play_life002_solver_case.gd` (Git blob
`0e46307d1cab673eccb06939cc1f42efb205348c`) and its LIFE001 helper; neither
existing file changes. Six new Godot files and this audit are the entire change.
No dependency on either unmerged measurement helper is introduced.

The initial PACE001 observations used `current_defaults_only` and an empty
construction receipt. LIFE002 already proves positive construction, reset and
refusal boundaries, but its short progression checks do not measure gameplay
for a longer interval under the constructed policy. This candidate joins those
existing capabilities without changing material laws or acceptance thresholds.

## Fixed protocol

Each automatically discovered wrapper starts one real `main.tscn` host for one
of `stuntbuggy`, `trialsbike`, `acrobat`, `arcadelander` or `jetbarrel`.
The accepted LIFE002 paths install `playground/player-course` through the
ordinary selector and the actual human SetP actor through the ordinary API.

Two construction selections are exercised, in fixed order:

1. Water `pressure_flow_v1/reference` through the panel's exploratory session
   and preset 2 (the non-default family arm).
2. Explicit reconstruction of Water `freemass_v1/reference` through preset 0
   (the constructed reference baseline, not a claim that FreeMass is non-default).

For each family, unchanged LIFE002 reconstruction, reset and refusal logic
calls the overridden `exercise_live_owner` twice. Each call records a fixed
**10-second wall-time** window after acknowledged actor/terrain/native identity
and neutral-input rearm:

- after positive construction;
- after a policy-retaining reset, the controlled actor-route refusal and the
  unsupported Oil/pressure-flow native capability refusal.

There are four intended windows per rig, twenty per operating system. These
are repeated stages in the same process, **not independent process replicates**
and not a randomized causal comparison between solvers. Solver order is fixed.
The existing refusal code verifies the staged graph retires and the accepted
World, actor, policy and receipt survive. It is inherited, not weakened or
replaced by a synthetic refusal.

A fixed input sequence alternates horizontal direction every 120 completed
Rapier steps, pulses W for the first 30 of each 120 steps, and delivers a quick
primary press/release at each observed 60-step boundary. A frame that jumps
across boundaries emits at most one tap and records the actual observed tick;
it does not flood catch-up commands. The inherited first quick-edge assertion
is retained. This is scripted synthetic keyboard input through the real
Viewport handler, not physical-controller or natural-course-traversal evidence.

## Measurements and provenance

Before sampling, require a nonempty native `applied_run` receipt, exploratory
intent, equal policy hashes, explicit requested/applied Water family and
reference variant. `eligible_for_full_matched_evidence` must remain false.
Default-only metadata or a hash of an empty dictionary is insufficient.

`PLAY_PACE002_WINDOW` includes the complete applied policy and construction
receipt, actor/World/session identity, exact course-recipe hash, actual input
event tape, observed completed native/Rapier deltas and rates, and raw arrays:

- Main callback durations;
- complete inter-callback intervals (N minus one, no partial first interval);
- retained worker snapshot age on **every** measured Main callback;
- retained render-packet age, with -1 explicitly denoting no generated packet;
- observed snapshot serial and native tick at each callback.

The first three timing arrays also have independently reproducible count, mean,
nearest-rank p50/p95/p99 and maximum. Render-packet age is retained raw only:
aging of an unchanged packet must not be called a rendering stall or FPS.
Per-frame snapshots must retain the same actor/World, native policy hash and
positive construction-receipt hash. End-of-window checks also compare full
policy/receipt values and the authored course. No live native World is read
from Main. Production Main callbacks run through `super._process` unchanged.

`PLAY_PACE002_RESULT` follows joined teardown and includes platform/Godot/display,
helper and inherited-LIFE002 file SHA-256, completed window/reconstruction/reset/
refusal counts and inherited worker/Rapier retirement checks. Original CI
identity and Windows execution manifests must bind these outputs to the actual
checkout/tree/native/Rapier binaries; printed fields alone are not trusted
provenance. Window records are printed before teardown so a later failure does
not silently discard measured data. A hard process timeout can still prevent
a final record and must remain a failed/incomplete execution.

## Bounded assertions, not performance acceptance

Each window has a 30-second apparatus deadline around the requested 10-second
sample. Main must yield back to the test and both clocks must advance. No
600-tick or 60-Hz target is required, and no timing quantile is a pass threshold.
The normal external per-case watchdog is not modified. A stalled Main thread
cannot be timed out by its own coroutine; the external harness remains needed.

Raw sample-count correspondence, stable identities, delivered commands, no
native quarantine, four completed windows, two reconstructions, two resets,
two controlled refusals, two native refusals, worker join and Rapier retirement
must all hold. A missing/empty receipt or incomplete window is not a skip or
fallback to defaults.

## Qualification still required

No local Godot parser/import/runtime, native build or repository-wide checks
were available during candidate preparation. Local checks cover file structure
and source-contract consistency only, not GDScript execution.

Before acceptance: exact-final-head Documentation/provenance, applicable Native
and Windows/Linux Godot; all five rig results plus twenty window records per OS;
original ZIP/log/hash verification; independent reduction and source review;
source-matched runtime reconciliation. Preserve every import, timeout, policy,
identity, input or runtime failure without automatic retry masking. Do not
change the source merely to restate historical results or transfer a prior-head
pass to a changed executable.

This is still a bounded, normally headless, roughly forty-second scripted
campaign per rig, not sustained rendered desktop qualification, a full session,
causal solver benchmarking or general performance acceptance. It does not hold
native phase jobs or prove busy-shutdown resource ordering, slow-native UI
responsiveness, all Main wait attribution, integrated rules selection, physical
devices/focus or human feel. The existing native-copy/runtime publication lane
#290/#295/#298 is untouched. #263/#266/#268/#269/#270 remain open.
