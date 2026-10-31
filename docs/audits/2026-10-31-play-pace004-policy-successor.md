---
title: PACE004 execution-policy successor and original inventory reconciliation
status: Planned
document-kind: audit
scope: Source-bound PACE004 successor apparatus; preserved original Windows and Linux evidence; new hosted qualification pending
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/current-and-historical-validation.md, ../operations/github-development-and-release.md]
---

# PACE004 execution-policy successor

## Disposition and dependencies

This package reconciles the scoped PACE004 apparatus from
[PR #320](https://github.com/techrote/cybersand/pull/320), source
`0744d267d1c37e4fc0b648e9f58e29ed3bec0c47`, with the accepted timeout and shader
integration. It does not merge the old branch wholesale. Its source-development
base is accepted main `adaaa37ae35ffcdaa961b80353be3a23b805c0cc`; its final
execution baseline must be the exact accepted timeout-plus-shader commit supplied
through `--baseline-source`. The source branch is
`codex/play-pace004-policy-20261031`.

The apparatus depends on the shared execution-policy JSON/GDScript/Python helper,
the updated generic Godot process runner and lifecycle helper, and the source-bound
palette selector integrated by shader commit
`88ed5ce3fc17673a8a1541c00f6ad3195961d971`. Those dependencies are owned and
integrated separately. No production shader, Main, simulation-worker, native,
solver, dependency-pin or generic runner changes are included here. Accepted
main already contains the production snapshot observer and UI readiness support
used by the original PACE004 source.

**Current local evidence** qualifies the portable reader controls, pure retention
buffer and GDScript parsing described below. **Planned hosted evidence** is the
complete 72-case registered successor campaign. A parser check, a local buffer
unit test, original headless evidence and forced shader-source selection do not
satisfy that campaign's actual rendered-host requirements.

## Original evidence and the count contradiction

The retained source and [run 41192641443](https://github.com/techrote/cybersand/actions/runs/41192641443)
register 14 ordinary headless cases and 16 active/idle workload cases per OS.
There is no separate standard-versus-sampled instrumentation switch. Both the
ordinary and active cohorts already contain their registered observers.

An intermediate handoff described 60 headless cases **per OS** by inferring an
extra instrumentation arm. Inspection of the original source and the raw
`campaign.json`, `readback.json` and case traces disproves that inference:
**60 is the combined Windows-plus-Linux headless count**. The original prose and
source are preserved in history; this successor does not invent duplicate arms
to match that handoff.

| Original cohort | Actual cases | Assertions | Individual key events | Applied positive presses | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Linux ordinary | 14 | 1,442 | 560 | 196 | Passed |
| Linux active/idle | 16 | 1,680 | 640 | 224 | Passed |
| Windows ordinary | 14 | 1,442 | 560 | 196 | Passed |
| Windows active/idle | 16 | 1,680 | 640 | 224 | Passed |
| Combined headless | 60 | 6,244 | 2,400 | 840 | Passed at original source only |
| Linux graphical | 1 attempted of 6 registered | 10 | 0 | 0 | Failed; 2 failed assertions |

The 840 count was independently recomputed from all 60 raw traces: each has 40
individual event rows and 14 pressed events in the original reader's applied
outcome inventory. The original readbacks validate the applied observations;
this count does not turn a requested event into a new application receipt.

The original graphical case is `acrobat`, one worker, Current policy. Its
original log contains a footer even though the old runner checked process pass
before extracting it, leaving `result` absent in the campaign row. That footer
records 10 assertions, two failures, no input events, `worker_joined=true` and
one retired session. The failed assertions are Main construction acknowledgement
and the original 30-second acknowledgement deadline. The wrapper exited 1 after
57.641 seconds; it did not hit the 180-second outer process timeout. The old
runner then stopped the graphical loop. Its five unexecuted configurations stay
unexecuted historical evidence.

All five original downloaded ZIP sizes and SHA-256 values match the authenticated
GitHub artifact metadata; ZIP CRC checks pass. Every sealed campaign member was
independently hashed from the original ZIP. Copies of all ZIPs, selected raw
reports and count/failure reconciliation receipts are retained outside Git under
`pace004-evidence/original41192641443/`.

| Original artifact | Artifact ID | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| Linux ordinary | 13040060919 | 84,440,603 | `7670a80577f839aafac6e281a2f9e5e17bf8f3cad024f25b0f7d0f101911b253` |
| Windows active/idle | 13040001579 | 87,733,261 | `fa1bf071113529c82672883fb0aeefcae81e92eee92b9375a54cb85cad2d89cb` |
| Windows ordinary | 13039822067 | 84,310,155 | `a36b2b7eb1d425a268830360f3a372f87499ac5b135b4b0f1f1801f971c360d3` |
| Linux active/idle | 13039102860 | 88,010,243 | `03ccb6f61c134ce764cbc1d5c920b7d77a5dfef1f49860aa1b0d8ee47c1c6410` |
| Linux graphical | 13039047490 | 76,825,316 | `601d3ba8b9472b832bafb3dda94964fc6a62e9139a6a6ecc1127930885e49263` |

The original graphical case log SHA-256 is
`58adf2f80af317d2f567c0c6f8d9134bbbbb8874f101da2cffe91222bc73f359`.
Original source, baseline `0bf28d5760aed989a79386de03ef4fc6171fef42`, and run ID
remain explicit historical constants in the successor reader. Historical results
are neither relabelled as new source nor rerun through a changed schema to turn
failures into passes.

## Frozen experiment and execution allowances

The input tape and `brush_rain_v1` recipe keep their scientific settings:

- The loaded gameplay sample targets 15,000,000 microseconds. The original reader's
  15–30 second validity envelope is unchanged.
- The two 3,000,000-microsecond analogue holds, other authored observation holds,
  40 individual input events and their original expected admission/cancellation
  sequence are unchanged.
- Active and idle controls keep 150 pulses at 100,000-microsecond spacing, two
  registered 8-cell-square brush footprints, original materials/locations, zero
  priming, original pulse lateness and activity thresholds. A missed or late pulse
  remains an invalid workload; increasing a watchdog does not stretch the recipe.
- One-worker and Auto policy arms retain their original meaning. There is no
  synchronous-reference arm, so the campaign cannot establish sync-versus-async
  equivalence or a speedup.
- Original observer work outside the measured window still runs; only retention
  of its copied records changes. Snapshot-mutex sampling keeps its original
  fixture boundaries. Native and Rapier remain owned by the original worker and
  Main respectively; no tick or physics callback is invoked manually.

Execution allowances now come from the separately committed
`godot/tests/support/ci_execution_policy.json`. At policy scale 1, Main
acknowledgement receives 600 seconds, ordinary operations 300 seconds, and the
whole complex fixture 3,600 seconds. The enclosing process receives
3,600 + 300 cleanup + 30 diagnostic + 10 termination = **3,940 seconds**.
Headless import receives 1,200 seconds. Slow elapsed time is reported as evidence;
completion, receipt validity and unchanged scientific inputs decide acceptance.

Every campaign receipt binds the policy digest, schema, scale and effective
values. Every Godot footer carries the corresponding policy identity; booleans
cannot substitute for numeric values. The independent reader derives expected
allowances from the checked-out source policy, rather than trusting an artifact
that nominates a more permissive deadline.

## Bounded pre-window retention and complete measurement inventory

The original worker appended publication receipts throughout cold startup into a
12,000-row array. With longer legitimate setup allowances, startup could consume
that evidence capacity before the 15-second measurement began.

`play_pace004_capture_buffer.gd` retains exactly the latest actual pre-window
boundary packet while the measurement has not started. Main publishes the start
and end timestamps under the existing worker mutex; the owner remains the only
writer of the copied native/publication arrays. After the start, every measured
publication is retained in serial order under the existing explicit 12,000-row
capacity, including the one actual boundary packet. A native completion before
the end whose packet is published just afterward retains its real publication
receipt as well. An ordinary after-window completion is not added.

Main reads owner arrays only after `stop_worker()` has joined. The result records
startup count, retained boundary/window counts, post-window count, capacity,
overflow and the read-after-join boundary. The independent reader still requires
serial continuity, exact native-completion inventory, matching Main-consumed
snapshots, monotonic source generations and actual publication timestamps. It
rejects missing rows or overflow; it never manufactures boundary receipts or
fills a gap from Main's summaries. This successor adds test-observer mutex work
to read the gate timestamps, so its instrumented timing must retain its source
identity when compared with the old observer.

## Versioned accepted-source fence and renderer identity

The old hard-coded baseline is not compatible with accepted main: it predates
accepted workflow changes, and shader integration changes production source.
The successor requires an explicit full 40-character `--baseline-source` commit.
Execution verifies that it is a Git ancestor of the executed source. The sealed
artifact contains the exact baseline commit object, full tree inventory and
bounded original commit-object ancestry path. Offline verification rehashes these
Git objects, reconstructs the tree identity and independently walks the parent
path to the baseline.

Protected scope is all of `godot`, `native`, `third_party`, `tools/ci`,
`tools/play` and `.github/workflows`, excluding only the explicit PACE apparatus
allowlist and portable Godot import cache. Changes to production, shader, shared
policy, generic runner or another fixture/workflow fail the fence. Documentation
is outside the execution fence. The caller must supply an accepted baseline;
a cryptographically intact archive alone does not make an arbitrary commit an
accepted project decision.

The original complete source tar, source/commit/tree checks, execution-input
hashes, before/after source/runtime checks, exact LFS pointers, actual runtime
bytes and committed native/Rapier provenance checks remain required. The final
reader also binds palette source and variant hashes to the authenticated source
archive. Native/headless cases require `full_crossfade`; real Windows graphical
cases explicitly request `opengl3_angle`, verify the actual Windows display and
ANGLE driver, and require `angle_bounded_crossfade`. Linux graphical cases verify
X11 and `opengl3`. A forced bounded shader on a Linux native driver is not Windows
ANGLE evidence.

## Failure continuation and exact hosted inventory

The successor extracts and preserves an original footer before checking whether
the process passed. An assertion failure can therefore retain a valid cleanup
receipt. Starting the next case requires all of the following: the footer's
source, nonce, fixture/probe hashes, actual engine hash and policy match; the
process completed naturally; the owner joined; exactly one session retired; and
both reported engine and wrapper PIDs are observed absent or exited. Missing
footers, timeout termination, still-active or unobservable PIDs stop the shard.

This is a read-only process-exit observation plus fixture retirement proof. It
claims no unobserved descendant inventory and sends no signal to an unrelated
PID. Failed cases keep their original errors and cannot make a shard pass just
because cleanup succeeded. Failed, incomplete and positive artifacts all upload.

| Successor cohort per OS | Configurations | Cases | Scale-1 shards |
| --- | --- | ---: | ---: |
| Ordinary headless | Five rigs × one/Auto Current; Acrobat and Jetbarrel × one/Auto pressure | 14 | 7 |
| Active/idle headless | Acrobat and Jetbarrel × one/Auto × Current/pressure × active/idle | 16 | 8 |
| Graphical | Acrobat and Jetbarrel × one/Auto Current; Jetbarrel × one/Auto pressure | 6 | 3 |
| Per OS total | Original registered configuration union | 36 | 18 |
| Windows plus Linux | 60 headless and 12 graphical | 72 | 36 |

The dedicated workflow uses literal GitHub-hosted `ubuntu-24.04` and
`windows-2022` labels, exact source checkout, draft suppression, `fail-fast:false`
and pinned actions. Each scale-1 shard contains two cases, without duplicate
sampled arms. Its derived suite allowance is:

`2 × 3,940 + 1,200 import + 600 aggregate headroom = 9,680 seconds`, rounded to
162 minutes. Dependencies receive two independent 1,200-second allowances plus
one aggregate 300-second setup allowance and 10 seconds of curl termination
headroom: 2,710 seconds, rounded to 46 minutes. The combined 12,390 seconds round
to a **210-minute parent job**, below the hosted 360-minute ceiling. No child is
silently cut to fit an old 180-minute parent. An explicitly enlarged policy scale
can select one case per shard while preserving the same 72-case union; if even
that cannot fit the hosted ceiling, planning fails rather than reducing a case's
allowance.

Ubuntu's [current runner-image inventory](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
lists Xvfb. Each graphical Linux job verifies actual Xvfb, xauth and Mesa
prerequisites; it does not insert an unbudgeted package-install stage. Xvfb starts
with TCP disabled. Engine and extension identities are verified by the campaign
before measurement. Windows uses the real ANGLE backend.

The final independent job downloads all original shard artifacts, verifies each
sealed source/runtime/log/pixel inventory and requires the exact 72-case union.
An absent, duplicate, foreign-source, failed or incomplete shard cannot satisfy
that job. There is no claim of physical input devices, scanout FPS, human feel,
shader visual equivalence or synchronous-reference performance.

## Local validation and remaining gates

At the local source delta above, pinned Linux Godot is
`4.7.stable.official.5b4e0cb0f`, binary SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

| Validation | Actual result | Scope |
| --- | --- | --- |
| Original input/source/pixel contract controls | 61 passed in normal Python and 61 in `python -O` | Portable adverse controls |
| Original active-workload contract controls | 30 passed in normal Python and 30 in `python -O` | Portable workload controls |
| New execution/source/cleanup/shard controls | 38 passed in normal Python and 38 in `python -O` | Portable successor controls, including real read-only observation of the test Python PID |
| Pinned Godot retention buffer test | 9 assertions, 0 failures, exit 0 | Pure buffer: 24,000 startup publications, exact boundary/window serials, late completion and explicit measured overflow |
| Full input-tape parser check | Exit 0 | `--headless --check-only`; exact untracked selector dependency from shader `88ed5ce3`; no pacing execution |
| Workflow structure | YAML and embedded Python parsed; CI provider policy passed | Static configuration only |
| Current repository/documentation checks | Passed; existing corpus 116 documents, 228 claims | Canonical successor routing is owned by the integration change |
| Historical M11 consistency | 18 records and 28 hashes passed | Historical integrity only |
| Existing retrieval evaluation | 32/32 canonical hits in top five; 19 at rank one | Retrieval reachability, not runtime or answer correctness |

The source delta was tested with local copies of shared policy files, which are
not included in this package's commit. Logs and original process receipts remain
outside Git under `pace004-evidence/successor-local/`. A committed integrated
source and accepted baseline are required before the runner permits a campaign.
No new local or hosted PACE004 real-host success is claimed in this audit.

Before acceptance, execute and independently read back all registered headless
and graphical cases on that exact integrated source; retain actual engine,
renderer, worker, snapshot, cache and source identities. Route those dated
artifacts through the canonical project status and retrieval documents, owned by
the integration change. Keep every original and successor failure. Any scientific
workload failure requires investigation at the registered settings; it is not
fixed by stretching pulses, shortening the sample or adding duplicate arms.


## Pre-publication independent review correction

The initial local successor `8bde97a15622ac448439b5bda1f7be6035b97608`
counted engine execution and dependency stages but did not completely reserve
independent readback, source metadata, cleanup, artifact sealing and workflow
setup/upload. Its 210-minute parent calculation above is superseded; it is not
the policy used for the published successor. The original local source and
control results remain recoverable.

The corrected scale-one two-case shard gives each original process 3,940
seconds and independently reserves 240 seconds for the complete shared
diagnostic/termination path plus a 300-second readback and retirement operation. Source preflight, cached
telemetry source identity and source postflight each receive 300 seconds.
Import receipt collection, final readback and artifact sealing have separate
300-second operations. Case directories and nonces are prepared within the
preflight clock. Including import and 600 seconds of headroom, the execution
step receives 12,800 seconds, rounded up to 214 minutes. Dependencies receive 46 minutes,
the separate retained readback six minutes, checkout/Python/Windows setup up
to 15 minutes, and upload ten minutes. All 291 rounded sequential minutes fit
inside a 300-minute hosted parent.

The final inventory job reserves all 36 independent source and raw-evidence
readbacks at 300 seconds each, plus headroom, for a 190-minute readback step.
Its checkout, Python setup, artifact retrieval, required-job gate and upload
bring the parent to 280 minutes. Every admitted plan/Linux/Windows job must
succeed; a skipped or failed prerequisite cannot become a passing aggregate.
Original CI artifacts use 90-day retention.

Git, archive and version queries within preflight/postflight consume one
shared operation clock rather than a fresh 300 seconds per subprocess.
Nested readers inherit the earlier deadline. Pure readback that returns after
its allowance is rejected. Policy scales are checked against the complete
rounded stage inventory: scale 1.25 retains all 72 original cases within the
hosted ceiling; scale 1.3 requires splitting the final readback, and scale 2
cannot fit even a complete single-case job. These configurations fail
planning explicitly rather than shortening scientific windows or silently
omitting coverage.

The independent reader now checks the complete original import and case
command, including engine/project paths, native versus ANGLE driver, script,
rig, worker policy, solver policy and workload. It rejects extra flags,
substituted version probes, changed host roots, nonfinite or boolean timing,
and symlinked evidence ancestors. Original host paths remain in the evidence;
the reader never rewrites them to its own checkout. Process completion time
is separate from the bounded diagnostic/bookkeeping observation allowance.

These changes do not alter the 15-second observation window, three-second
holds, 150 by 100-millisecond input pulses, rig mechanics, native worker
counts, solver presets, original failed attempt, or the 60-headless plus
12-graphical registered case union. They add no synchronous-reference arm
and provide no physical-device or human acceptance result.

## Actual Linux terrain-removal control failure and focused correction

The retained graphical attempt at source
`57d3fa72d02e30bf67c8c269c39a5398f357b670`, tree
`1911ca046eafbf5e46b30d4ff1b332601a354373`, uses protected baseline
`fed68ef8d691b5646e874a79c7651eee1339e9d3`. The actual Linux Xvfb/llvmpipe
run is retained in
`pace004-evidence/local-57d3fa72-linux-graphical-attempt2/campaign/`.
Both original engine cases complete naturally with exit zero and 115 assertions
without a fixture failure: Acrobat/one-worker/Current in 32.404 seconds and
Jet Barrel/Auto/Current in 27.504 seconds. The independent graphical reader
correctly refuses both with `Terrain pixels absent or indistinguishable from
animation noise`. The campaign remains failed; a clean engine exit does not
override the independent pixel oracle.

Inspection of the original PNGs shows terrain still present in the supposed
removal frame. Recomputing the unchanged reader's sampling and threshold gives:

| Original case | Actor interior pixels | Actor removal changed | Terrain samples | Unchanged terrain noise | Terrain removal changed |
|---|---:|---:|---:|---:|---:|
| Acrobat / one worker / Current | 1,325 | 1,325 | 55,111 | 0 | 0 |
| Jet Barrel / Auto / Current | 1,570 | 1,570 | 55,092 | 1 | 1 |

Jet Barrel's `without_terrain.png` and `restored.png` are byte-identical,
SHA-256 `3df6b0aab341edf3c5baef4c4ef1f61a6aae5bf2f611d0f61dedf9b0a168d901`.
The original manifest SHA-256 is
`36083dfb0e990b0e096ba6071aaec5ae4d623eef5f3b3aef452771f41800e6dd`;
the campaign JSON SHA-256 is
`1b3e7cebf2220b8112871fe576ea5301a3441bebb629374d6d60b546bf699137`.
These originals are preserved without mutation or retrospective promotion.

The fixture's control set `World.self_modulate.a` to zero. The production
palette fragment assigns its authored colour to `COLOR`, so that control did
not remove the terrain draw. This is a failed apparatus intervention, not
evidence of missing terrain in the production frame. Actor removal already
works and its original control remains unchanged.

The focused fixture correction temporarily clears `TextureRect.texture` and
then restores the identical resource. Godot 4.7's
[TextureRect draw implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/gui/texture_rect.cpp)
returns without issuing its own draw when the texture is null. The actual
World node uses `EXPAND_IGNORE_SIZE` and a fixed minimum height, so its
intrinsic size does not depend on this texture. The fixture additionally
asserts the unchanged world rectangle and the actor overlay's continued
parentage and visible-in-tree state during removal and restoration. It restores
the original texture even if the removal draw wait fails. Hiding the parent
would hide its actor child and is not used.

Only this post-gameplay diagnostic intervention and its explicit guards change.
The five-frame inventory, two-draw waits, original pixel oracle and all thresholds
remain unchanged, as do production shaders, native state, real physics, input
events, sampling windows and fixture workloads. This source correction still
requires a fresh two-case graphical execution and independent readback before
it can supply passing evidence. No Windows or displayed-pacing qualification
is inferred from source review.

## Fresh local graphical verification of the corrected control

A new, separately numbered execution at source
`b94a943947a6dc3b75664a4a0cc2476959fae159`, tree
`d13772b3aad3ac8e804ec7597d69717f7297af23`, passes both original graphical
cases and a fresh independent sealed readback. It uses the same protected
baseline `fed68ef8d691b5646e874a79c7651eee1339e9d3`; it is not evidence that
the later integrated recovery baseline or the complete hosted inventory has
already passed. The original failed `57d3fa72` campaign remains failed.

The new evidence is retained at
`pace004-evidence/local-b94a9439-linux-graphical-attempt1/`. The source and both
selected platform runtime hashes are unchanged before and after execution.
The actual engine is `4.7.stable.official.5b4e0cb0f`, native OpenGL through
Xvfb and llvmpipe, on an AMD EPYC 9V74 Linux host. The engine reports nine
logical processors. The native library SHA-256 is
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`;
Rapier is `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
The Godot archive SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.

| Measurement | Acrobat / one worker / Current | Jet Barrel / Auto / Current |
|---|---:|---:|
| Original engine process, natural exit zero | 35.878 s | 28.785 s |
| Fixture assertions / failures | 120 / 0 | 120 / 0 |
| Accounted events: applied / cancelled / refused | 29 / 6 / 5 | 29 / 6 / 5 |
| Main construction acknowledgement | 9.180100 s | 3.221923 s |
| Native completed ticks in the registered window | 901 | 904 |
| Native completed frequency | 60.026 Hz | 60.019 Hz |
| Rapier completed frequency | 59.892 Hz | 59.953 Hz |
| Configured worker capacity / maximum actual participation | 1 / 1 | 4 / 3 |
| Input-to-applied-step latency, median / p95 / maximum | 70.030 / 81.131 / 85.291 ms | 66.270 / 82.285 / 82.365 ms |
| Draw submission interval, median / p95 / p99 | 74.957 / 91.066 / 111.398 ms | 70.575 / 87.636 / 95.784 ms |
| Draw submissions in the 15-second window | 197 | 209 |
| Actor pixels changed by removal / sampled actor pixels | 1,329 / 1,329 | 1,570 / 1,570 |
| Terrain pixels changed by removal / unchanged-frame noise | 7,884 / 0 | 2,789 / 0 |

The Auto case's mean actual participation is 1.0033; capacity four does not
mean four workers performed every tick. Both cases join their real worker,
retire one session, and leave the observed engine/wrapper PID absent. Neither
has a refused render snapshot. Actor restoration noise is zero in both cases.
Visual inspection confirms terrain disappears while the actor remains visible
in the corrected removal frame.

These are descriptive measurements of a shared software-rendering environment.
The roughly 13–14 submissions per second are a visible pacing limitation of
this observed cohort, not evidence of acceptable physical desktop performance.
`displayed_fps` remains null. No physical scanout, keyboard/gamepad hardware,
human responsiveness, synchronous-reference comparison, Windows result or
complete 72-case result is inferred.

The immutable campaign manifest SHA-256 is
`a8413c22f8de25595b969c765d3ebf4acb2e7f57a704e00e9234f1529f189843`;
the original campaign JSON is
`03d5a8702261048cba13c9ef607f23a66770f37392e58fb312407a707c309763`.
The separate successful independent readback is
`36d007facc7895cb623789fb2c84a4410ea7343abf7eb4523f681ecb37cd73df`.
It is outside the sealed original campaign and does not rewrite its files.

The prepared integration is based on the exact protected recovery source
`02454f3aa6a6130d375727d1aa28113772f658e4`, tree
`cf8607853b25dc04a61125a9f46dd89a299c14cf`, including the reviewed HDR program
input correction from shader source `19ddd366`. Only the registered PACE004
apparatus and this audit are added. All 60 headless and 12 graphical cases,
their source-bound independent readbacks, the final exact-inventory reducer,
and the applicable full regression workflows remain required on that source
before guarded acceptance.


## Published d08 graphical evidence and v3 source composition

Published source `d08e61013c2fefbf6238d50174b81655e80f1eb8`, tree
`9b95e643d756f531db045e28272fa86bdeb97665`, completed all six local graphical
cases on the preceding protected recovery baseline `02454f3a`. All three
separately launched shards passed and their independent sealed readbacks
confirmed all 87 original campaign files unchanged. The
[complete compact receipt](play-pace004-2026-10-31/local-d08e6101-six-graphical.json)
is retained byte-for-byte, SHA-256
`d58e0122eaf9cdd912557250a88a66aaac228536c64da9f7eaf7bcc063111f0f`.
The initial preparation refusal occurred before any engine launch and remains
separate from the three successful executions.

Together the six cases record 720 assertions with zero failures and 240
individually accounted input events. The actual cohort is X11/OpenGL3 with
llvmpipe LLVM 20.1.2, 256 bits, on a shared AMD EPYC 9V74 host reporting nine
logical processors. Both selected runtime hashes, protected production inputs
and source identities remain unchanged; every process completes naturally and
all actor-removal, terrain-removal, restoration and safe-cleanup controls pass.
This is automated graphical evidence, not a physical device or human result.

Current-policy native throughput is approximately 59.96–60.01 completed ticks
per second. The pressure-policy cases record approximately 52.87 with one
worker and 46.33 with Auto; Rapier remains approximately 59.64–60.06 completed
steps per second across the six cases. Those pressure-policy observations
remain visible performance limitations of this shared software-rendering
cohort. They are not compared against Avrea or the earlier b94 measurements.
Draw submission is recorded separately; displayed FPS remains null.

The complete local evidence archive is
`pace004-d08e6101-six-linux-graphical-cases.tar.gz`, 266,720,364 bytes,
SHA-256 `12e54eec090239610a28fe7fbf66034ddb2eb48c26623cf2d61ab1455e45ec65`;
its 365 members were individually verified against the retained manifest.
The original hosted d08 attempt is
[run 41247752557](https://github.com/techrote/cybersand/actions/runs/41247752557),
attempt 1; partial completed shards are not a full inventory qualification.

The successor now inherits exact recovery source
`4752aac3a300ae65da1c578609283c875b8448f8`, tree
`41c0d18589ec5cc8911edcbdc73434556c99dc89`, through an ancestry-preserving merge.
That baseline incorporates the separately reviewed
[shader semantic/input v3 apparatus](2026-10-31-palette-shader-semantic-v3-registration.md)
from `6f8f13f0`. No PACE004 apparatus, gameplay production code, input tape,
scientific window, runtime or execution allowance changes in this composition.
The six local d08 cases retain their actual source identity; they are not
relabeled as successor executions. Fresh complete 60-headless/12-graphical
hosted qualification and applicable full source-matched regressions remain
required for the successor before guarded acceptance.
