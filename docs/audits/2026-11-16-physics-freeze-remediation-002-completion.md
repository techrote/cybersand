---
title: Workbench freeze remediation completion follow-up
status: Historical evidence
document-kind: audit
scope: Source-bound continuation from3da6; controlled desktop renderer overlap and publication ownership, without physical acceptance or merge authority
canonical-for: []
last-reviewed: 2026-11-17
related-documents: [2026-11-16-physics-freeze-remediation-002.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, ../operations/camera-stack-coherence-acceptance.md]
---

# Physics-freeze remediation completion follow-up

## Revalidated starting point

PR609 remained open Draft at `3da6ea884a4c9157c6689f7ed1baabc8935f78cd`,
tree `ecfc80a81bb4b842d9663c5a0fee322ebfd51190`. Accepted main remained
`018bd09503d7f079ddac52e225c2f7daf8d678bf`. All four dependent PRs remained
Draft/HOLD, unmerged and without auto-merge. The prior exact-source application
run43909363577 was successful but did not meet the freeze target. The original
c1ad control and previous negative measurements remain in the preceding audit.
Native/Rapier compiler inputs and runtime hashes remain unchanged. Official
Godot4.7 was the starting engine; the subsequent source-pinned Windows EGL
repair is documented below. No physics law, fixed timestep or feedback-age
protection is relaxed.

The local results below identify immutable working-source bookends over3da6,
not a claim that the3da6 commit already contains this follow-up. Final committed
source, exact-head Linux/Windows jobs and package checksums belong to the
[PR609 delivery ledger](https://github.com/techrote/cybersand/pull/609).

## Publication ownership and bounded transfer repair

The preallocated128-tile rectangular class uses16 by8 tiles. At2048² RG8,
65–128 changed tiles submit4MiB instead of8MiB. The22 texture RIDs represent
79,659,013 nominal bytes with the normal three-resource ring,12,582,912 bytes
more than the previous design. The123-tile fixture uses eight exact copy runs
and2,015,232 destination pixels instead of a whole4,194,304-pixel copy.
Full-size updates/fallback remain available; there is no production GPU readback
or per-publication allocation of staging textures. Exact GPU histories, NPOT
edges and stable resource identities passed the expanded1,838-check fixture.
Some isolated copy-fixture timings regressed; reduced bytes are not a claim
that all publication or gameplay tails improve.

Queued RenderingServer calls may retain the Image object. Four full-material
create/update sites now submit immutable Image snapshots. The deterministic
separate-render negative had10 real history failures in111 assertions; the
fixed source passed111/0 and Safe83/0. The earlier111/11 attempt included two
watchdog failures and nine history failures and is retained separately.

Actual Main initially crashed in both separate-off and separate-fixed16 before
any usable timing. Disassembly placed the assertion in GLES texture upload's
empty COW data access, but did not identify the particular texture. The supported
startup `gui/theme/default_font_generate_mipmaps=true` selects the engine's
copied-atlas path. Changing only that setting in the exact crashing project
allowed both full144-step captures to finish. This is a workaround observation,
not proof of the crashing RID. Safe99/0 and Separate197/0 font tests verified
actual nearest-filtered UI pixels and queued atlas ownership. Review added
CPU-to-GPU and exact-reference assertions; the amended test must pass the final
source-specific gates. Mipmap generation adds CPU work and texture storage.

A31-file/15-producer inventory found the same persistent-Image hazard in the
shared Depth surface reachable through F2. Its two create/update calls now also
submit immutable snapshots. Original Separate71/4 exposed four wrong
intermediate GPU images despite correct final images; fixed Separate71/0 and
Safe67/0 preserved all final appearance pixels. No Web, WORM/DRIV3R, Wave Flow
or generator implementation was changed. The Web-only producer is outside the
qualified desktop navigation path; a global renderer-default change would need
separate consideration.

## Scheduling cause and bounded implementation

Pinned engine source shows that Main runs a batch of scheduled physics callbacks
before its unconditional RenderingServer queue synchronization. Without a
rendezvous, the first Rapier step can publish its native sample and the remaining
catch-up callbacks immediately return while that sample is pending. A long
render interval then delays the next admission even when native work completed
much earlier. This is avoidable admission latency, distinct from native tick
computation, terrain work or Rapier solver work.

A fixed16.667ms wait increased completed-step averages but worsened physical
p95 and frame cadence in both Safe and Separate trials. It remains an explicitly
selected rejected-performance control, not a normal default.

The renderer-aware policy queues at most one native Semaphore marker in the
first actual callback of a process frame. A bound Variant retains the Semaphore
until the native-only render callback returns, including owner retirement.
Later already scheduled catch-up callbacks may wait for the exact native sample
only while the marker is pending, sharing one66,667µs deadline with250µs polls.
Marker consumption is latched; backlog refuses new queue growth. Safe rendering
adds no such wait. All ordinary owner, epoch, session, generation, feedback and
complete-terrain gates are repeated before a fixed1/60 Rapier step.

This uses otherwise outstanding renderer work; it does not create callbacks,
physics time debt, speculative physics or extrapolated poses. Godot still
synchronizes each Main iteration, so graphics and physical callbacks are not
fully independent. A marker certifies earlier RenderingServer calls returned,
not GPU completion, scanout or a displayed frame identity. Separate-thread
post-draw delivery is explicitly unassociated with Main's current frame.
Requested deadlines are cooperative; OS descheduling can exceed wall bounds.

## Focused matched local trial

All arms used the same774-file project, official engine, native libraries,
2048² Needle geometry,11-entry completed-step tape, Fire ON/OFF at0/60,
Auto0 workers (resolved capacity4), strict native wait/wake, normal window,
startup VSync and identical observer configuration. Linux used X11 and
Mesa25.0.7 llvmpipe on the available EPYC9V74 host. Timings are wall elapsed,
including possible waits and descheduling; no isolated CPU/GPU attribution or
physical NVIDIA acceptance follows.

The matched common prefix is144 actual completions,143 gaps. Columns are
achieved rates and milliseconds, never configured FPS:

| Mode | Native/s | Rapier/s | Main/s | Gap median | p95 | p99 | Maximum | Gaps≥100ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| safe-off | 7.449 | 7.454 | 7.448 | 128.075 | 161.165 | 172.685 | 175.179 | 143 |
| separate-off | 8.373 | 8.380 | 8.430 | 117.084 | 144.907 | 149.779 | 157.337 | 143 |
| separate-overlap | 29.685 | 29.759 | 8.070 | 23.926 | 70.567 | 90.832 | 98.188 | 0 |

Every recorded body position/orientation/linear velocity and native/terrain
association is exact across the144 shared steps. Main frame p95 worsened from
143.404ms in Separate-off to153.336ms in overlap; maximum178.046ms in Safe,
154.144ms in Separate-off and175.256ms in overlap. Graphics remain constrained
by software rendering. Native completion-to-admission median fell from95.557ms
in Separate-off to3.322ms in overlap, p95122.929→48.747ms.

The unchanged capture requires both ten wall seconds and144 completions.
Overlap therefore recorded322 actual steps, including178 extra steps beyond
the common prefix. Its complete321-gap distribution still had zero≥100ms,
p9566.432ms and maximum98.188ms, with31.859 completed steps/s. Those extra
states are preserved but have no matching control states and are not included
in the equivalence claim. The full trace contains221 successful waits;95 are
inside the shared prefix. All join unique actual admissions. Its85 recorded
markers are distinct and all latch, queue-growth and deadline checks pass.
Most natural waits reach the cap while rendering remains pending; controlled
queue tests separately exercise completion during a wait. The277.937ms first
marker observation includes delayed Main observation and is not render duration.

Source bookends for the three-arm capture:

- `godot/scripts/main.gd`: `06adf8af8217f1ff86a70f911fe6229125bd7a171af26d729e1bd806e1124ae5`.
- `godot/scripts/workbench_native_rendezvous.gd`: `300743e3ea0a4b2baa9b4bed812eefdbc3f6a99a08d78258ee39d6badac3495f`.
- `godot/scripts/blit_material_publisher.gd`: `dda4a78e1ad4e056af46eb717b0b5305c50ad5f2ded647dec06f4ec2b05674b8`.
- `godot/project.godot`: `4fa79b6bb6a2796893f15e63c41a6e1838140d96ebe31fbb48731b1db83b65ca`.

Raw trace SHA256 and complete file/engine/native/harness ledgers are in
`render-overlap-development/summary.json`; the stricter read-only reduction
retains all whole-capture statistics without rewriting that original report.
Independent raw review is `render-overlap-three-mode-review.json` plus its
full-capture addendum and the scheduling engineer's `actual-main-review.json`.

## Failed attempts and qualification boundary

Retained negatives include the original queued-material and Depth history
failures, both full Main separate-render crashes, the fixed16 frame/tail
regressions, the original font-test scope before its oracle amendment, and
two26/1 marker-lifetime oracle attempts caused by test-owned VM temporaries.
The corrected ownership-scope test passed26/0 Safe and34/0 actual Separate;
all original source/logs remain. The actual Main fixed16 integration passed113
checks; that fixture alone does not qualify the overlap policy.

The follow-up adds actual GPU/history/font/Depth gates, finite authoritative
state validation, marker/admission checks, reverse-order Linux/Windows comparison
and installed-package checks. Successful engineering gates must be attached to
the final exact source. No local result alone promotes a default or grants
physical acceptance. **PHYSICAL HOLD** remains mandatory until the owner tests
the delivered source on physical Windows11/NVIDIA. All four PRs stay Draft/HOLD
and unmerged; no auto-merge or Ready promotion is authorized by this record.

## Exact-source desktop probe and Windows engine prerequisite

The controlled probe at `ce9fd2f64aa3b83ab84496ff56d38436d08e3b20`
(tree `9b8038b168786cccf49b5d2d78db8d1b9f947d98`) ran in
[Actions43967236615](https://github.com/techrote/cybersand/actions/runs/43967236615).
Linux completed its actual graphical gates and forward/reverse six-arm comparison.
The two matched overlap arms achieved19.263/19.302 Rapier steps/s versus
7.375/7.499 in Safe/off. Their p95 gaps were99.129/110.582ms, maxima113.875/140.185ms,
and7/12 of143 gaps were at least100ms, compared with143 in each Safe/off arm.
These repeats retain recurrent long intervals; the earlier zero100ms result
does not generalize. All common144 recorded physical states and associations
were equivalent. These are hosted software-renderer observations.

Windows failed before application startup in every Separate graphical case:
`Error initializing GLAD` in `RasterizerGLES3`, followed by process exit
`0xC0000005`. Safe font103 and Depth67 checks passed. No Windows Separate timing
was produced. Its original failed artifact is14277727023, SHA256
`864d4da159a7fe3bb7734b094d7b499ac20d7a521bdb72711dd0fdf4c57abb43`.
The earlier92243239 checkpoint's source preflight failure is separately retained:
two PowerShell Git blobs had CRLF instead of canonical LF; ce9f corrects only
that normalization relative to9224.

Two independent inspections of pinned Godot4.7 source
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` found an EGL ownership defect.
`EGLManager::release_current()` unbinds the current context but retains its
`current_window` cache. The new rendering owner then calls
`window_make_current(MAIN_WINDOW_ID)`, whose same-window shortcut skips the
required EGL bind. This establishes a source mechanism consistent with the
observed startup failure; a real rebuilt Windows execution remains necessary.

The source-owned engine trial adds exactly one cache invalidation after release,
matching the existing WGL pattern. It does not add GL calls, private hooks,
another ANGLE DLL, application physics changes or speculative collision behavior.
Patch `third_party/patches/godot-egl-current-window.patch` has SHA256
`29a74947a3128ed93eeea0c6ab7274d10f45c194627fb516d7db6b511413e9a1`;
the resulting EGL source hash is
`9faf74aa030f0b11b59f82bc0eca1373c781cef9372a2f9ba43c576f8869321e`.
An extracted-source real-thread/mocked-EGL regression reproduces14 checks/6
failures on the original and14/0 on the patch. The mock is not an actual driver
qualification and deliberately retains existing EGL failure semantics.

The dedicated Windows2022 build workflow authenticates upstream source, the
ordered patch, SCons, static ANGLE chromium/7219 and AccessKit0.21.2 before use.
It builds an explicitly named custom Godot4.7 GUI executable and console wrapper,
checks their import closure and compares the complete public extension API with
official4.7, allowing only the declared version-label fields to differ. All
application/native/Rapier tests and matched performance arms use the same built
engine. D3D12 is explicitly disabled in this build; Vulkan, native OpenGL, static
ANGLE and application modules remain enabled. This is not a reproduction of the
official binary. The existing retained native/Rapier source and build ledgers
remain unchanged and require actual loading/execution with this engine.

The separate-render Engine Lab test also exposed native-subwindow GLX errors
on Linux despite its81 functional assertions completing. That run is not a pass.
Native popup lifecycle, VSync controls, actual rendering and package launch paths
remain integration gates; neither this source repair nor the faster Linux
physics results authorize a Windows default before those gates complete.

The first custom-engine build at `106c845a087e3e309cedac5cbdb76cc7e0db625e`
compiled successfully in2315.8seconds in
[Actions43972621937](https://github.com/techrote/cybersand/actions/runs/43972621937),
then failed the import-classification gate before version, public API or
application execution. The GUI import table contained the inbox Windows Runtime
`combase.dll`, which the initial explicit system-DLL list omitted. Microsoft
documents that DLL for
[RoGetActivationFactory](https://learn.microsoft.com/windows/win32/api/roapi/nf-roapi-rogetactivationfactory)
on Windows8/Server2012 and later. The repair adds only `combase`; unknown imports
and external CRT dependencies remain rejected, with the exact executable/DLL
mapping now included in the failure message. It does not change engine source,
build flags or dependency archives. The failed evidence artifact14282916594
has SHA256`c549d9bf36ce4291772704ff9a5af43cd31781440e0665e0855485fa09153868`.
Its `complete:false` receipt remains a failure. Subsequent incomplete build
outputs are separately quarantined for inspection and cannot satisfy the
complete-provenance restoration gate.

## Desktop integration and final decision boundary

The local reverse timing capture exposed one native rendezvous `ready` decision
9microseconds beyond its deadline. The helper now samples the monotonic clock
at the return decision and converts an expired ready result to a timeout,
removing its snapshot. The regression passes57 checks, including minus1, zero
and plus9microsecond boundaries in both fixed16 and render-overlap modes.
Preemption after that final clock sample remains possible; this is not a hard
real-time scheduler. Native associations, terrain requirements and the fixed
physical timestep are unchanged.

Separate rendering also requires explicit ownership at the two Lab windows.
The shared policy embeds Engine Lab and Materials Lab in the existing root
surface in Separate mode and retains native windows in Safe mode. Its owned
binding compensates only the Lab's parent stretch, enforces the existing
minimum content size, and refuses an undersized parent with a resize message.
It does not modify root stretch, native pixel mapping or the presentation
coordinator. Embedded Lab controls and their reused dropdowns disable local
font oversampling; the copied default-font mipmap path remains enabled.
VSync requests dispatch the bound native setter through the rendering owner,
without a synchronous Main/render lock inversion or a GDScript rendering-thread
callback. The rejected synchronous native-window proposal remains unapplied.

The integrated working-source Linux run completed54 cases with51 passes. It
passed actual Engine Lab112/164 checks in Safe/Separate modes and Materials
Lab88/131, including composed markers, measured pixel input, font scale,
resize/refusal/reopen and the configured dropdowns. Both graphical PAINT phases
passed66/12 checks. Material tile/history, immutable queued images, default
font, Depth, native rendezvous, overlap lifetime and physical pacing gates
passed. The local X11 driver's unsupported VSync warning remains a limitation;
Windows qualification requires requested/reported Disabled/Enabled values and
rejects an EGL setter failure warning.

That run is retained as failed, with unchanged source/runtime fingerprints.
The headless PAINT runner incorrectly requested framebuffer capture and awaited
a draw signal unavailable in headless mode; its author timed out and its
dependent fresh reopen then lacked a save. Restricting that environment setting
to graphical cases produced64/12 passing headless assertions in12.44seconds.
The third failure was the old pixel fixture's unassociated post-draw capture
under Separate rendering; its pixel assertions are retained while the capture
ordering is qualified separately. These are working-source results, not an
exact-commit or Windows acceptance receipt.

The pixel fixture's original Separate run failed100 of339 assertions. Ordering
only its primary uniform capture reduced that to four failures in the other
PAINT/root capture paths; that intermediate attempt also remains failed.
The final test-only helper crosses a scene iteration boundary, retains normal
waits, then queues an explicit draw immediately before synchronous readback.
This covers all five correctness capture sites without changing any pixel
oracle, camera input, shader, negative control or comparative timing loop.
Actual Safe and Separate runs then passed339/0 each, with zero and128 explicit
correctness draws respectively. Their source/runtime fingerprints were stable.
The comparative timing metadata explicitly describes Main-delivered signal
intervals without exact Separate draw identity; those intervals do not establish
render throughput. A separately interrupted invocation produced no application
case and is not counted as a pass.

The remaining local integration campaign passed architectural generation/UI,
ordinary and multistyle author/reopen, retained generator/material regressions,
Flatten with fresh reopen and owner-failure recovery, and combined authoring
at one and four native workers. Its source/runtime fingerprints stayed equal
before and after all three campaigns. These results supplement the focused
runtime changes; the required final exact-HEAD hosted campaign is still distinct.

Delivery uses a distinct custom-engine artifact lock and preserves the engine
build source/run separately from the final application Git archive. The
ordinary launcher selects Separate/automatic material publication/early native
publication/render overlap. Explicit controls isolate full texture submission,
renderer ownership and overlap; the integrated publication control selects
Safe/full/combined/off. Both retain native wait/wake and fixed physical laws.
The real PowerShell5.1 runner records achieved physical progression and labels
its statistics as whole captures, including additional completed steps. Exact
common-prefix timing belongs to the source-matched CI reducer. Separate
Main-delivered post-draw notifications are not reported as a measured draw rate.
Fresh extraction, the actual command launchers, Test It, final exact-source
Linux/Windows CI and independent raw-evidence review remain required gates.

## Authenticated engine pin and exact-source comparison checkpoint

On2026-11-17, the rebuilt engine in
[Actions43980022228](https://github.com/techrote/cybersand/actions/runs/43980022228)
passed compilation, explicit PE dependency classification, version execution
and comparison of the public extension API against official Godot4.7. Only the
build/full-name header fields differ in the API JSON; both extension interface
files match exactly. This qualifies the build/API boundary, not gameplay or
hardware smoothness. The application gates in that run execute its build source
`4e84820baa021f96c3c1957fb125786fb7ab5e6a`, separately from the later application.

The authenticated
[engine payload14284768334](https://github.com/techrote/cybersand/actions/runs/43980022228/artifacts/14284768334)
has archive SHA256
`34dfdf5769828dc4ae876550864b4c80c3acd5bc960944ce8631d9bf900421be`
and build-provenance SHA256
`a4be0fa432c77240c49e28ab53cc30b4cb97f898a0064e747e03f445ac04751c`.
Its version is `4.7.stable.cybersand_egl_handoff.5b4e0cb0f`. The GUI executable
has SHA256 `d6a1e5795205eb7968131df55f39916af112f716ec419fce5f97ccb48990fd45`;
the console wrapper has SHA256
`6f642c28780409295c0001f3919d14a9f71485a602c533a1c0335df5819d1030`.
The evaluation lock pins the archive and provenance. A fresh local restore
verified the exact files, hashes, patch, upstream source, current builder and
lock, API receipt, imports and shipped notices. The12 adversarial provenance
tests pass. The final Windows package must retain this engine-build identity
alongside its distinct application source/tree identity.

The committed application checkpoint
`9083b953f1aad34a44d35a9ade867d75c6500537`, tree
`865da3d6b9c2e9e4c14b6c5a31a29c7bbb4ed9c8`, contains the23 independently
reviewed application, regression and delivery changes over the engine-build
checkpoint. Its focused Follow comparison uses the original
`c1ad4910a07422b37d63df270bac337863ae7b2f` control, the same official Linux
engine,2048-square Needle geometry, normal coupling and the same11-entry input
tape. Control selects Safe/full/combined/off; candidate selects
Separate/automatic/early/render-overlap. The common observer settings suppress
new callback/publication events in both arms; additive rendezvous events remain
charged to the candidate. This single ordered AB run does not establish
reverse-order repeatability or Windows/NVIDIA performance.

| Shared physical steps1–144 | Control | Candidate |
| --- | ---: | ---: |
| Rapier completions/s | 7.902 | 31.698 |
| Native completions/s | 7.902 | 31.636 |
| Main submissions/s | 7.905 | 8.391 |
| Physical gap median / p95 / p99, ms | 125.557 / 143.700 / 152.904 | 22.797 / 71.456 / 93.340 |
| Maximum physical gap, ms | 180.424 | 99.719 |
| Gaps at least50 /100 /250 /1000ms, of143 | 143 /143 /0 /0 | 21 /0 /0 /0 |
| Native completion to admission median / p95, ms | 105.705 /125.198 | 2.817 /46.955 |
| Main submission gap p95, ms | 140.148 | 152.462 |
| Material-publication elapsed median / p95, ms | 1.695 /2.039 | 2.247 /19.812 |

All144 shared authoritative body states, velocities, native associations,
owners, fixed-step clocks, input indices and hard-terrain shape counts match
exactly. The candidate completes195 additional physical steps outside that
equal-work comparison. No physical/native completion is missing or duplicated;
neither observer drops records. All142 control and86 whole-candidate uploads
join publication metadata, Main acknowledgement and exact worker acknowledgement.
The candidate also has248 superseded graphical publications and four publications
beyond the last upload at trace close. Two internal render-packet serial gaps do
not represent missing native completions or graphical publication records.

All516 overlap events across88 marker identities pass the recorded identity,
latch, shared-deadline and callback-index checks. All248 ready decisions occur
before the recorded deadline and join one admission each;105 fall within the
shared prefix. The75 sleeping timeouts retain a maximum5.482ms deadline
overshoot. Reduced physical gaps therefore coexist with worse Main submission
and upload tails; this is not a general frame-smoothness pass. The earlier
hosted Linux repetitions with7/12 gaps at least100ms remain adverse evidence.

The independent committed-source guard has SHA256
`cbcb8dbe47d18b2602282e5c0b08e3a1879978fb15387bb30d504e98d5740c1f`.
The independently reproduced raw comparison review has SHA256
`04f0850bf8a0a1878683127efb13a5b9a4bc286ec4f23acaf38c6b0205c600c0`.
They clear this composition for final qualification, without substituting for
the exact final source's Linux/Windows campaign or the owner's physical gate.

The first integrated attempt at `37306928c9ee2ae21cfd9505e9ffc8f2e34bd5c9`
retains two preparation failures. In
[Actions43986532696](https://github.com/techrote/cybersand/actions/runs/43986532696),
the Windows provenance test reached a missing proof file instead of rejecting
its adversarial backslash filename: Python's `ZipInfo` normalizes Windows
separators both while creating and reading members. The fixture now emits and
checks the exact original filename, and restoration rejects any normalized
alias before extraction. NUL and repeated directory-separator cases are also
rejected. All13 local tests pass, including simulated Windows normalization;
actual Windows execution remains a rerun gate. This failed job never restored
the engine, built a package or executed the application. Its artifact14284874407
has SHA256 `d6234d5fbaa7b742d16a86a3cb55a3bc74d7cd79c9d4eadc4bdfd1667ebf881e`.

The documentation job in
[Actions43986540460](https://github.com/techrote/cybersand/actions/runs/43986540460)
also rejected missing explicit `max-parallel` fields in the two singleton
native-rendezvous probe matrices. Each now declares1; parsed workflow comparison
confirms no other scheduling or case change. The10 policy tests and inventory
check over all70 workflows pass. These repairs change no engine binary,
application runtime, physical contract or measured workload. The original
failed jobs remain retained; a new source-bound campaign must qualify the repair.
