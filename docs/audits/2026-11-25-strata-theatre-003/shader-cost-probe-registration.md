# Exact-output optical shader cost experiment — prospective registration

Registered before hosted execution on 2026-11-26. This is an isolated research
branch, not an application update or a waiver of the performance gate.

## Observed problem

The final-source Linux campaign for application
`fd0830abcfadd9ae19162e5677943bb131223e59` completed its functional and native
checks, but its three matched progression repeats failed the separately
registered enabled-optics performance criterion. Median native-rate ratios to
Classic were 0.799483 Architectural, 0.815296 Cinematic Deep Focus, 0.750602
Gameplay Clarity and 0.754460 Diorama High. All four also exceeded the original
physical-interval p95 allowance. These failures remain valid negative evidence.
The disabled Classic path passed its independent matched comparison with the
original qualified Strata002 application. Neither result is physical NVIDIA
acceptance.

The complete original Linux artifact is 15075800269 from run 45721790366, SHA256
`d9ebf833c049af25280fc1af142e6eea59bb5de0f88a7e1a959d055ba4657011`.
The unchanged strict reader admits its complete population; no outlier or
scene-admission result is excluded.

## Hypothesis and bounded implementation

The per-plane shader currently evaluates downstream tone, illumination,
architectural shadow, clarity-mask and actor-reveal arithmetic even where both
the nearest source sample and its already-filtered neighbourhood have exactly
zero alpha. The A1 candidate skips this downstream work only when
`centre.a == 0.0 && low.a == 0.0`. It retains the low-frequency filter, all
nonempty coverage, the literal Classic expression, all uniforms and all resource
ownership. It adds no epsilon, render target, texture, native readback or
simulation operation. The source proof is a hypothesis about exact output,
not a substitute for graphical or performance evidence. Dense coverage may gain
nothing; divergent GPU branches may also cost time.

Original shader SHA256:
`b64c8fe105fb981b56aab38f44cfca2f875ea975792593c11dd9692892a0e8eb`.
A1 candidate SHA256:
`50518cda2c8b9635d4b15b71ade65752fa9f859f447624940c9705acf814995f`.

## Source, renderer and observation boundary

Each hosted job checks out the immutable application commit above separately
from the experiment commit. The application's tree must remain
`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`. Application files are not edited.
An external GDScript wrapper changes only the cached Shader resource's in-memory
code and restores the original code at the end. The exact application, observer
commit/tree, external file hashes, actual loaded shader hash, pinned Godot 4.7,
native binary and Rapier identities are independently recorded and verified.

The two hosts are GitHub's Linux llvmpipe and Windows ANGLE software-rendering
environments. They are useful for bounded comparative evidence and may disagree.
They are not the owner's Windows 11/NVIDIA machine. Graphical execution is
mandatory; headless checks cannot qualify this experiment.

## Exact-output admission before timing

First execute the unchanged frozen application's actual graphical renderer test
with the original shader, then its external override wrapper with A1. Both must
pass all 109 assertions and emit the exact same inventory of 18 PNGs. Decode every
PNG and compare every RGBA byte, including alpha and the haze/partial-opacity
Classic wipe case. Wrong identities, missing captures or any changed byte stop
the run before the more expensive matched progression experiment.

The real Workbench experiment also retains 15 paused, unresampled original
framebuffers. Before each measured window, record all four native plane hashes,
the camera and initial actor pose, the complete optical configuration, the
actual shader hash and the capture time. Independently compare the world RGBA
region for each same-repeat original/A1 pair: Architectural and Gameplay
Clarity, six comparisons. UI/status text is outside that world comparison.
No graphics readback or native material capture enters a timed window.

## Matched physical progression

Use the unchanged application `_progression_sample` observer and native
readability-challenge scene. All five cases use Balanced quality:

| Case | Profile | Shader |
| --- | --- | --- |
| classic-original | Classic | Original |
| architectural-original | Architectural | Original |
| architectural-empty-coverage | Architectural | A1 |
| clarity-original | Gameplay Clarity | Original |
| clarity-empty-coverage | Gameplay Clarity | A1 |

Run three repeats in forward/reverse/forward order, 15 windows total. Each window
starts from a freshly loaded identical native scene and initial actor/camera
state. Shader compilation, source changes, six paused warm callbacks, native
hashes and graphical captures happen before timing. Each measured window
requires 90 callbacks and retains every completed Rapier step, native publication
witness, elapsed time, actual native/Rapier counter delta, callback interval,
physical interval and engine-process observation. A 90-second per-window
watchdog and 1800-second process watchdog bound failure. All repeats are retained.
The capture time is checked against the first actual completion; the observer
does not invent an unavailable exact timer-start timestamp.

Compute medians across the three repetitions, retain each original population
and interval tail, and compare to this run's original Classic population. The
existing criteria remain unchanged:

- Median native and Rapier rates must each be at least 90% of Classic.
- Median physical p95 must be no greater than the larger of 1.20 times Classic's
  median p95 or Classic's median p95 plus 10 milliseconds.
- Scene admission retains the 45-second target, including every failed result.

Also report A1 versus its same-profile original to distinguish an actual cost
improvement from simply meeting or missing the Classic-relative criterion.
Three sequential repeats are not a claim of statistical independence. Native
publications may coalesce; the completed Rapier-hook population provides the
every-step physical interval measurement. Renderer FPS is not substituted.

Whole-process CPU and peak sampled process-tree RSS include startup, shader
tests when applicable, admission, reloads, compilation, readbacks, warmups and
timed windows. Each process has its own receipt. These observations are not
per-profile CPU/GPU timing or proof of leak freedom. No application adoption,
performance acceptance or owner acceptance is automatic from numeric flags.

## Disposition rules

Any pixel, native-state, source-identity or observation failure rejects the
candidate's qualification. A valid observed speed regression or a remaining
performance-gate miss is retained as negative research, not hidden by making
the run an infrastructure failure. If A1 succeeds, adoption still requires an
explicit source-bound application change and appropriate qualification; the
original fd0830ab receipts cannot be relabelled as executing the changed shader.
The existing evaluator campaign remains on fd0830ab throughout this experiment.
All raw originals remain in the Actions artifact and only compact evidence and
selected captures belong in the repository. Draft/HOLD remains in force.
