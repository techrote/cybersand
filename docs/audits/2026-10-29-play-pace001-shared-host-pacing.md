---
title: PLAY-PACE-001 shared-host pacing candidate
status: Planned
document-kind: evidence
scope: Corrected source candidate for fixed-configuration pacing; previous exact-source hosted evidence preserved without promotion
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, ../PERFORMANCE.md, ../operations/local-build-and-validation.md]
---

# PLAY-PACE-001 shared-host pacing candidate

## Status and source identity

This is a **corrected source candidate**, not accepted performance evidence or
release qualification. The previous measurement implementation executed on
both hosted OSes, but its per-publication ages must not be described as
continuous retained-frame ages. The corrected source requires fresh exact-head
CI and independent artifact review. This branch starts from accepted `main`
`aac0feb65e2268b74975892ce1df81e04e1a7e40`, tree
`a2ddee9e54a570d56e6e9b68285281c1921b8f0f`.

The candidate adds one shared Godot test helper and five automatically discovered
rig wrappers. It changes no native source, GDExtension runtime, material law,
solver-family admission/default, gameplay owner, Rapier ownership, CI policy or
specialist fixture. This avoids overlapping the separate source-sensitive native
copy work in PRs #290/#295.

## Historical hosted execution and bounded correction — 2026-10-29

The original exact source `cf0affeb32815bb9d70d6a25a69c9ad7c5a6caf3`
completed attempt-1 [Documentation 40835649578](https://github.com/techrote/cybersand/actions/runs/40835649578),
[Native 40835649569](https://github.com/techrote/cybersand/actions/runs/40835649569)
and [Windows/Linux Godot 40835649611](https://github.com/techrote/cybersand/actions/runs/40835649611),
all **SUCCESS**. Direct job-log parsing found five real `PLAY_PACE001_RESULT`
records for each OS, each **16 assertions / zero failures**, with at least
120 completed native ticks, at least 120 completed Rapier steps, joined owner
and retired physical session. Hosted Linux completed native rates were
**59.71–59.96 Hz**, Windows **59.48–59.91 Hz**; the runs are headless,
brief (~2-second measurement windows) and not rendered or interactive FPS.
The workflow retains Windows and four Linux shard artifacts; these original
artifacts and results belong solely to that exact source and have not been
claimed as a fully hash-audited independent acceptance package here.

[Independent source/data finding](https://github.com/techrote/cybersand/pull/296#pullrequestreview-5694646247):
original `_sample_snapshot()` returned when the publication serial stayed
unchanged. As a result its `snapshot_age_ms` and `render_snapshot_age_ms`
arrays cover only **120–121 first-observed worker publications per rig**,
whereas Main executed **290–292 process callbacks** per rig. The former
are valid *first-observed publication ages*, but not continuous ages of the
retained last-committed presentation. Their reported render age p95 of
approximately **1.80–1.83 seconds** is not, by itself, a render defect:
an unchanged static packet may legitimately age.

The corrected helper (first committed at `24000c3122e0ad786584c1e6ccd55dc855c63390`)
preserves old publication samples and adds two new frame-corresponding
retained-age series, sampled on **every** measured Main `_process` callback,
including when no new worker publication arrives. Missing timestamps cannot
silently contribute fabricated zero ages: the test checks that both series
have one valid sample for each measured Main callback, and checks that
callbacks with no new publication were actually observed. Raw series and
percentiles are emitted separately. These checks are **not passed evidence**
until the corrected source executes on Windows and Linux.

No baseline result or later correction here establishes attributed mutex wait,
interactive device responsiveness, slow-native phase-job progress, native-busy
shutdown or human feel; issue #270 stays open.

## Question

For each accepted mechanical SetP rig on the exact authored
`playground/player-course`, what distributions are observed for:

- Main process and physics callback intervals and callback duration;
- completed native and main-thread Rapier rates over the same wall interval;
- immutable worker-publication and retained render-packet age;
- full `consume_worker_snapshot()` callback duration;
- worker step and snapshot-copy duration from source-bound publications;
- snapshot coalescing, scheduler jobs/phases, worker capacity and overruns?

The result is descriptive. No timing threshold is converted into a pass/fail
criterion.

## Fixture

`godot/tests/play_pace001_shared_host_case.gd` constructs the real
`main.tscn`, existing `CyberSimulationWorker`, authored course and one actual
main-thread Rapier SetP session. The five wrappers select:

1. `stuntbuggy`;
2. `trialsbike`;
3. `acrobat`;
4. `arcadelander`;
5. `jetbarrel`.

Each fresh process:

1. admits the course through the ordinary MicroScenario selector;
2. constructs the human rig through the ordinary F5 SetP API;
3. waits for actor, terrain and neutral-input readiness;
4. retains actor epoch, World generation, course recipe hash and applied liquid
   policy/receipt;
5. samples until at least 120 completed native ticks and 120 completed Rapier
   steps, under held W+D input, one D→A reversal and periodic real Space
   press/release edges delivered through `Input.parse_input_event`;
6. emits one `PLAY_PACE001_RESULT` JSON line containing summaries and raw arrays;
7. closes the actual scene and requires the exclusive worker to join and the
   Rapier session to retire.

The harness subclasses Main only for observation. `super._process`,
`super._physics_process` and `super.consume_worker_snapshot` execute unchanged.
No World reference, mutable cell storage or Rapier object crosses to the
simulation worker or native pool.

## Measurement definitions

- **Process/physics interval:** wall time between successive actual callback
  entries while measurement is active.
- **Callback duration:** wall time around the unchanged inherited callback.
- **First-observed snapshot age (`snapshot_age_ms`):** callback completion time
  minus the copied snapshot's `published_usec`, sampled only when a new worker
  publication serial is first observed on Main.
- **First-observed render age (`render_snapshot_age_ms`):** callback completion
  time minus the immutable render packet's `render_generated_usec`, on those
  same newly observed worker publications.
- **Retained snapshot age (`retained_snapshot_age_ms`):** callback completion
  time minus the current copied snapshot's `published_usec`, **every measured
  Main process callback**, even without a new publication.
- **Retained render age (`retained_render_age_ms`):** callback completion time
  minus the last-committed render packet's `render_generated_usec`, **every
  measured Main process callback**. Static packets can legitimately age.
- **Snapshot consume callback:** total inherited
  `consume_worker_snapshot()` duration, including its ordinary presentation
  work. It is **not** an isolated mutex-wait measurement.
- **Native/Rapier completed Hz:** completed tick/step delta divided by the same
  measured wall interval.
- **Coalesced native ticks:** positive completed-tick gaps between worker
  publications. This does not imply loss of authoritative native ticks.

Raw values remain in the result line for independent reduction. Reported
scheduler job/phase maxima and configured worker capacity do not establish
concurrent execution or causal speedup.

## Assertions

The candidate asserts only fixture integrity and bounded completion:

- both native and Rapier clocks reach the 120-tick target;
- process, physics, first-observed snapshot-age, worker-step and consume
  distributions are populated;
- retained snapshot/render ages have one valid timestamped sample per measured
  Main callback, including a directly observed callback without a new worker
  publication;
- actor epoch, World generation, selected rig, authored map, liquid policy and
  construction receipt remain unchanged;
- the worker does not enter failure quarantine;
- scene exit joins the worker and retires Rapier.

There is no FPS, latency, p95/p99, snapshot-age or worker-count acceptance
threshold.

## Explicit exclusions

This candidate does **not** establish:

- interactive or rendered desktop FPS;
- human-perceived control/camera/contact quality;
- physical gamepad, device disconnect/reconnect or complete focus behavior;
- isolated main-thread mutex wait attribution;
- a deliberately slow native tick;
- shutdown while native phase jobs are demonstrably outstanding;
- pool-thread creation, simultaneous execution or per-worker utilization;
- ordinary Linux desktop equivalence from a hosted/headless result;
- Web behavior;
- #266, #268, #269, #270 or parent #263 completion.

The operator checklist in issue #270 remains unexecuted. The next distinct
lifecycle slice still needs source-bound slow-native progress and resource
retirement during directly observed outstanding native phase jobs, coordinated
with current native-source ownership.

## Corrected-head data readback and portable policy identity — 2026-10-29

The previous corrected candidate `6373b4eb33f32fcef5998c8b7c7a7d35cb05dd52`
completed attempt-1 [Documentation 40847434093](https://github.com/techrote/cybersand/actions/runs/40847434093),
[Native 40847434095](https://github.com/techrote/cybersand/actions/runs/40847434095)
and [Windows/Linux Godot 40847434392](https://github.com/techrote/cybersand/actions/runs/40847434392)
as **SUCCESS**. Direct Windows/four Linux shard job-log reduction found all ten
PLAY_PACE001_RESULT records: five SetP rigs per OS, **18 assertions / zero
failures each**, at least 120 native and 120 Rapier steps, successful owner join
and Rapier retirement. The independent [exact-head Windows/Linux raw reduction
review](https://github.com/techrote/cybersand/pull/296#pullrequestreview-5696828293)
recomputed 110 complete raw timing distributions without percentile/count
discrepancies. Linux native completion was 59.73–59.96 Hz, Windows
59.50–59.90 Hz; Windows retained Main-visible snapshot age p95 was
17.33–18.45 ms, Linux 16.70–17.17 ms. These are hosted, headless, short,
non-interactive baselines, not rendered desktop FPS. The associated artifact
ZIPs exist, but their original bytes/digests have not been independently
verified in that review; old-head results remain bound to their exact source.

The entire native liquid receipt is **platform-qualified**:
`godot/native_extension/cyber_native_cell_world.cpp` includes the literal
`platform=windows/linux` in `liquid_policy_receipt()`. The original
`liquid_policy_sha256 = SHA256(JSON.stringify(policy))` therefore differs
across the two OSes (Windows `053bcbaf…`, Linux `c0f59d3f…`) without proving
a different material policy. The current bounded test change **retains** that
platform-qualified JSON digest and exports the source-native `policy_hash`,
platform, admission, catalogue digest and capability-matrix digest as separate
readback fields. A new assertion requires the three 64-hex-character native
identity/digest fields to be present. This permits later same-source,
cross-OS matching on the actual native policy identity rather than a complete
platform-qualified JSON serialization. It does **not** promote any solver,
change defaults or prove policy reconstruction. All ten preceding records
have the SHA256 of `{}` as their typed construction receipt, so a positive
per-material admission/rebuild gate still requires its own actual fixture.

**Source boundary:** this new additive metadata/assertion change has not
executed at its new Git head. The successful `6373b4eb` workflows and the
18-assertion runs are historical now; this new head expects 19 assertions
per rig and requires fresh Windows/Linux/Native/Documentation qualification
and final independent source/artifact review before any merge.

## Required qualification

Before any acceptance or merge claim:

1. run exact-head Documentation/provenance, Native and Windows/Linux
   GDExtension/Godot workflows;
2. verify five `PLAY_PACE001_RESULT` records per OS with zero fixture failures,
   original raw logs and exact tested checkout/tree/runtime identities;
3. retain any parse, timeout, import, runtime or measurement failure without
   retry masking;
4. independently review source, artifacts and reductions;
5. reconcile the result into #266/#270 and canonical performance/player docs
   only at its actual evidence scope.

No local Godot, native build or documentation checker is claimed for the
correction. The original hosted source execution above remains historical
and does not qualify this new helper/head. New exact-head hosted execution,
raw-artifact reduction and independent acceptance review are still required.
