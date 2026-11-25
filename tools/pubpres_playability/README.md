# PUBPRES-PLAYABILITY-001 measurement v3

This apparatus compares actual native Workbench and Rapier progression. It does
not select an application default or authorize promotion. All outcomes remain
Draft/HOLD until the source, platform and owner evidence support a decision.
The historical `tools/pubpres_integration/` campaign, overlays and hashes are
unchanged.

The current prospective `campaign.json` uses `pubpres_same_frame_gameplay.gd`
and `results_same_frame.py`. Primary C explicitly enables the default-off
same-frame continuation; `--same-frame-calibration` compares the same exact C
OFF/ON/ON/OFF in Safe rendering. M/I advertise no continuation capability.
All source/runtime, workload, capture limits, Water and equal-step body/move
requirements remain. Each completed continuation must spend one genuine withheld
callback in its original process frame, with one nonblocking mailbox observation
and unchanged owner/World/terrain/input identity. Attempt and completion are
distinct events; a first-N cutoff counts actual step completion even when the
enclosing attempt observation finishes later.

`campaign-development-01-v2.json` is the exact original registration, SHA-256
`d44ba75d49c708de409633659caadeb9f284c69623c649296342ec5c89ef1286`.
Its v2 observer and reducer are preserved, and `--campaign` selects that old
protocol explicitly. No old receipt is silently read as v3. The new protocol
rejects Separate: its original full-Workbench failures are retained, with small
native-independent engine/material probes used for diagnosis instead.

## Source and runtime custody

`campaign.json` pins accepted main `846fe0533b3170e7b01f690518da49fc40cc24d1`
and the qualified PUBPRES reference
`8503ec19e4d620e125dc6df2c5c6571b1256cb92`. The candidate is the supplied exact
checkout HEAD. Every final source arm needs its own newly built runtime directory
from `tools/pubpres_playability_build/build_runtime.py`, containing
`PUBPRES-RUNTIME.json` and the named DLL/SO. The runner checks the exact commit and
tree, complete native source set, canonical source hashes, build script, runtime
hash and size, and equality of compiler and godot-cpp identity across arms.
An old native library is never relabelled as another source's build.

A pristine Windows owner package uses `--archive-manifest` with an explicit
`--expected-candidate` full SHA from the handoff. This calls the package's full
inventory, native closure, Rapier, engine and provenance verifier. Source roots,
engine and campaign must be the exact declared paths. It records verified archive
custody, without claiming that an extracted package is a live Git checkout. Do
not mix external `--runtime-*` overrides into this mode. Evidence output must
remain outside the pristine payload.

Only disposable project copies receive the explicitly recorded common test
overlay and matching experimental runtime. The production runtime and provenance
files in each source checkout remain unchanged. Reusing an output folder is
refused. All failed process logs, receipts and projects are retained.

The final runner rejects dirty or untracked source inputs. `--development`
explicitly labels an exploratory run and allows a shorter registered order or
staging-pool override. It may use each source's separately verified retained
runtime manifest when new runtime directories are omitted. That fallback is
unavailable for final campaigns and still rejects stale source/native pairs.

## Registered workloads

All actors are real Needle instances. All primary cases request four native
workers and report actual task participation; requested capacity is not a claim
that four workers participated in every native phase. The app renders a
1600 × 900 window, requests VSync off, caps presentation at 60 FPS and retains
the existing fixed 1/60-second Rapier step. Each capture lasts at least 10 seconds
and 144 completed Rapier steps, with a 90-second capture cap and a 240-second
setup cap.

The reader independently enforces these declared bounds. A delayed callback that
returns after90 seconds leaves an incomplete capture and retained raw evidence;
there is no added scheduling tolerance or truncation that manufactures success.
Every step used by the144-step oracle must be inside the capture interval.

| Cohort | Default cases | Order and scope |
|---|---|---|
| Historical Wave reference | 512² Free/Follow, 2048² Free/Follow, 2048 × 1024 Follow | M–I–C–C–I–M; one round, all reference parameters, no spill or ballistic transport |
| Other Water families | FreeMass 512² Free and 2048² Follow; PressureFlow cached/dormant 512² Follow; CellularYield 512² Follow | M–I–C–C–I–M; actual native policy admission and readback required |
| Input correctness control | Wave 512² Follow with neutral commands | M–I–C–C–I–M; a distinct control, not a replacement for the active tape |
| Current owner gameplay Water | Wave 2048² Follow with exact main846f gameplay defaults | M–C–C–M; two rounds, native spill and ballistic transport; all current profile knobs checked |

The current owner gameplay profile cannot be expressed by unchanged `8503`.
That source lacks `gameplay_water_options` and seven required native readback
fields: `parameters.deep_gain`, `parameters.floor_gain`,
`parameters.flux_smoothing`, `spill.deep_draw`, `spill.sheet_rate`,
`spill.coyote_ticks`, and `spill.full_face`. An untimed native compatibility
preflight records this refusal. It does not launch an unsupported timed arm or
substitute zeroes. The complete actual native Water configuration is retained in
each receipt. Original `8503` NVIDIA timings describe the older cohort and are
not directly comparable to the current owner gameplay default.

`--extended` also includes landscape Free and large PressureFlow/CellularYield
controls. `--case ID` selects an explicitly registered subset. A selected subset
must be reported as that subset, not as the complete matrix.

## Input and observation semantics

The primary input mode remains `repeated_callback`, preserving the historical
held-input refresh at each source's ordinary physics callback. Every attempted
command is recorded, with actual acceptance/refusal counters, source sequence,
physical tick and lease deadline. The ordinary lease is six completed physical
ticks; it is not a wall-clock TTL. Command counts can differ with source cadence,
so the apparatus does not pretend the full admitted command streams are equal.
All eleven tape transitions must still occur at their exact completed-step
indices, and full first-144-step body trajectories and admitted moves are hashed.
Raw requested tape values and actual accepted Vector2 values remain separate.
Each completed step must match the preceding accepted action, sequence and
six-tick deadline, so eleven transition records cannot substitute for the full
admission stream. Float32 round-trip comparison preserves Vector2 representation
without inventing an input tolerance. Before/after actor rosters and per-step RID
links bind the real Needle RigidBody2D to its Rapier owner; empty bodies,
nonfinite poses, changed ownership and missing observer durations fail closed.
Every same-source pair must agree on those equal-step outcomes before causal
timing attribution. A divergent pair remains a retained failed experiment. The
summary also discloses every cross-source pair, exact law/profile identity and
command counts. Historical main/reference changes can legitimately alter a
trajectory; a shared initial workload does not prove equal physical outcomes,
and a cross-source speed delta is a whole-source comparison until a same-source
intervention isolates its cause.

`--input-equivalence` runs a separate C-only repeated/once/once/repeated control.
Once-per-step input may not replace the primary policy unless equal-step body and
admitted-move parity is demonstrated. This diagnostic does not alter source input
leases, action semantics or ordinary owner controls.

The full observer uses bounded arrays, at most 30,000 events per owner and
30,000 command attempts. Overflow fails the capture. JSON, PNG and full material
readbacks occur after timing. Native capture observes the existing return value
and the actual `force_full` argument; it makes no extra native query and copies
no material plane. Native status codes are retained as codes rather than guessed
causes. No renderer, native step, physics admission or authority fence is replaced.
Full captures require actual Main/physics callbacks, worker snapshots, native
capture returns, material uploads and draw callbacks. PNG signatures, chunk CRCs
and dimensions are verified as well as file hashes. An absent metric remains
null; an unobserved byte count or duration is never substituted with zero.

`--observer-calibration` runs C-only full/reduced/reduced/full. Reduced observation
disables detailed Main/worker traces and task-participation sampling, while
retaining completed-step/body, command and compact genuine-callback/continuation
oracles. This v3 definition requires fresh calibration; the revealed v2 result
is not an overhead bound for the new apparatus. It is not an uninstrumented
owner run. Report the measured difference; do not subtract an assumed overhead
or silently adjust primary results.

The primary candidate also keeps the optional native stage readback OFF. Its
new dictionary is constructed before the physics mailbox, so enabling it only on
the candidate would add an asymmetric observation cost. A separate
`--native-probe-calibration` runs C-only OFF–ON–ON–OFF, retaining identical input
and common observers. Native stage fields remain null for the primary comparison;
the diagnostic records existing counters and its measured overhead separately.

## Timing interpretation

The reducer preserves first-10-second, first-144-step and whole-capture windows.
Quantiles use linear interpolation at `(n-1)*q`; maxima and consecutive frame
gaps remain visible. It separates native completion rate, completed Rapier rate,
physical gaps, native completion-to-healthy-mailbox, first healthy mailbox-to-
callback/step, material age, publication calls, and following draw-callback
delivery. The first healthy packet is joined by World generation, native tick,
body sample and required terrain revision. Repeated status publication does not
reset its queue age. Missing legacy clocks and native probe fields remain null.

A valid complete capture can contain zero or one completed step in its first
ten seconds. Keep those severe-stall negatives: prefix throughput is the actual
count divided by ten, between-step gaps are unavailable when fewer than two
steps occur, and observed no-step prefix/suffix durations are reported separately.
The complete capture still requires the registered 144 steps within 90 seconds.
The first step may consume the recorded pre-capture native tick with body
sample−1; this single bootstrap exception is explicitly counted. A final early
physics mailbox may be consumed before its full-snapshot observer hook returns;
at most that final hook gap is disclosed, and its age remains unavailable. Every
later consumed native completion must otherwise be observed and accepted.

Physics-only I/C packets deliberately retain render generation0. Their physical
owner comes from `physics_world_generation`; only legacy M, whose snapshot type
lacks that property, uses `render_world_generation`. A present but invalid
physics generation never falls back to rendering. The initial no-completion
clock sentinel−1 is preserved in `native_completed_source_usec` and normalized
to null for timing. Later capable-source clocks must be positive and bound to
the same native World/body sample. Legacy clocks remain unavailable, and the
native completion observation's body sample must match the consumed step.

`frame_post_draw` is a delivered software callback. Particularly under Separate
rendering, the next delivered callback does not identify the upload that caused
it and does not measure GPU completion or scanout. The metric is explicitly named
`upload_return_to_next_delivered_draw_callback_ms`. Stage wall times cannot
independently distinguish CPU work, driver waiting and OS descheduling.

Under the retained v2 registration, `--thread-calibration` runs one candidate and workload in
Safe–Separate–Separate–Safe order, keeping source and native inputs fixed.
Every arm checks its requested and actual rendering owner. Different thread modes
are compared only as the declared treatment; they are never pooled as matching
controls. Ordinary launch/render defaults remain unchanged.
V3 explicitly retires that full-Workbench engine control. Its same-source
`--same-frame-calibration` uses OFF/ON/ON/OFF and Safe rendering instead.
The registered cases are Wave512 Follow, historical Wave2048 Follow, current
gameplay Wave2048 Follow, Pressure512 Follow, FreeMass2048 Follow and
Cellular512 Follow. Observer/input diagnostics remain restricted to Wave512
Follow and the native readback diagnostic to historical Wave2048 Follow.
The runner reads and enforces each registered order and eligible case set.
An explicit development label is required to try a different diagnostic case;
it is not a qualified registered comparison.

Windows working set and commit are sampled with `GetProcessMemoryInfo` every
250 ms; Linux uses `/proc`. Memory is accepted only when the sampled PID matches
the actual Godot receipt PID. Use the direct Windows Godot executable, not a
console shim or launcher. Windows virtual size is unavailable and remains null.
Both platforms receive isolated per-arm user-data/cache profiles. Driver-global
caches are uncontrolled and ordering is balanced.

## Running

After freezing all source and overlay hashes, the complete registered matrix is:

```sh
python3 tools/pubpres_playability/run_campaign.py \
  --main /work/main-846f --integration /work/reference-8503 --candidate /work/candidate \
  --runtime-M /work/runtime-M --runtime-I /work/runtime-I --runtime-C /work/runtime-C \
  --engine /work/Godot --render-thread safe --output /work/evidence-final-safe
```

Use the same command under Windows with `python` and Windows paths; optionally
select `--driver opengl3_angle` only when that renderer is the declared target.
Never equate hosted ANGLE/WARP or Linux llvmpipe qualification with owner NVIDIA
acceptance. The final campaign may also be run with `--render-thread separate` in
a separate new output folder, preserving all matching arm identities.

For a pristine owner package at `C:\\PUBPRES`, the equivalent command is:

```powershell
python C:\PUBPRES\tools\pubpres_playability\run_campaign.py `
  --archive-manifest C:\PUBPRES\PUBPRES-PLAYABILITY-MANIFEST.json `
  --expected-candidate FULL_CANDIDATE_SHA_FROM_HANDOFF `
  --main C:\PUBPRES\sources\M --integration C:\PUBPRES\sources\I `
  --candidate C:\PUBPRES\sources\C `
  --campaign C:\PUBPRES\tools\pubpres_playability\campaign.json `
  --engine C:\PUBPRES\Godot_v4.7-stable_win64.exe `
  --render-thread safe --output C:\PUBPRES-Evidence\final-safe
```

This command requires Python 3.11 or later. The ordinary graphical owner launcher
is separate; archive measurements use the same source-matched v2 Python reader.

A bounded development diagnostic adds:

```sh
--development --case wave_2048_follow --thread-calibration
```

For observer calibration use `--case wave_512_follow --observer-calibration`.
For input equivalence use `--case wave_512_follow --input-equivalence`.
For native readback calibration use
`--case wave_2048_follow --native-probe-calibration`.
All four registered diagnostics can run without `--development` on exact clean
sources and newly built runtimes. Omitting `--case` selects that diagnostic's
declared case set. Linux `.py` display wrappers use Python; an executable
`xvfb-run` uses its own interpreter with `-a -s '-screen 0 1920x1080x24'`.
The independent reducer can reprocess a raw receipt without running Godot:

```sh
python3 tools/pubpres_playability/results.py /work/case/receipt.json \
  --campaign tools/pubpres_playability/campaign.json --arm C
```

Reducer-boundary and runtime-custody tests:

```sh
python3 tools/pubpres_playability/test_results.py
```

After importing each exact source project, a headless source-backed packet test
uses the real production publication method on I/C and actual legacy snapshot
type on M:

```sh
Godot --headless --audio-driver Dummy --path /work/project \
  --script res://tests/pubpres_playability_compatibility.gd -- \
  --mailbox-test --receipt=/work/mailbox-identity.json
```

The test supplies declared fixture owner IDs and clock values. It checks the
initial sentinel, physics-only render generation0, positive completion fields
and refusal to substitute a render owner for an invalid physics owner. It does
not run native progression, render a frame or qualify physical performance.

Linux development run44956244125 retained successful application captures as
failed process qualifications because its `xvfb-run` wrapper left descendants
for the outer owner to retire. Those originals are not requalified. The next
source checkpoint uses `tools/pubpres_playability_build/owned_xvfb.py` as the
explicit display wrapper: each invocation still has a fresh1920×1080×24 X server,
with a private authorization file and TCP disabled. It waits for that exact
server to exit before the wrapper exits; application descendants remain subject
to the original strict refusal. Each arm retains `display-owner.json`, wrapper
and receipt hashes, display/server PID, application status and confirmed server
join. The native work, input, capture bounds and render selectors are unchanged.
Its process-only tests and separate actual X11 connection gate do not qualify
Godot rendering. No new local graphical result is claimed.

The retired four-column native search remains separate negative development
evidence. This delivery harness explicitly refuses an enabled request. The only
new native stage probe is OFF by default and reports existing counters when the
candidate arm explicitly enables it; it grants no simulation authority.

No captured completion, faster GPU call, valid hash or passing test by itself
establishes playable progression, Ready status or owner acceptance.
