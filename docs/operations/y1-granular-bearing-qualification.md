---
title: Y1 granular bearing envelope qualification and owner review
status: Current
document-kind: guide
scope: Bounded fresh-main B0/Y1 qualification apparatus and source-matched playable owner review; no production selection
canonical-for: [y1-granular-envelope-qualification]
last-reviewed: 2026-11-01
related-documents: [../architecture/rigid-body-and-cellular-coupling.md, physics-characterisation.md, development-claims-remediation-programme.md, ../audits/2026-11-01-y1-production-envelope.md]
---

# Y1 granular bearing envelope qualification and owner review

## What is selected and what remains experimental?

**Current default B0** uses the existing yield multiplier `0.18`. **Current
diagnostic candidate Y1** substitutes `1.0` at that one multiplication in
`CyberNativeCellWorld::accumulate_granular_bearing`. It requires fresh
`diagnostic_reset` construction with both string options
`bearing_candidate: "Y1"` and
`bearing_experiment: "Y1-ENVELOPE-2026-11-01"`. Explicit B0 is also accepted.
Invalid/missing tokens, unknown modes and wrong types refuse without replacing
the current World. Default diagnostic construction and ordinary demo reset
restore B0. There is no ordinary gameplay selector or persisted Y1 policy.

The interpreted fallback retains B0; Y1 is a native-only experiment. No new
support predicate, geometry, capacity, correction, ejection, torque or friction
law is selected. The [coupling contract](../architecture/rigid-body-and-cellular-coupling.md)
owns the response and ownership semantics. The exposed downward samples retain
capacity2/sample and global20 cap, the original arrest term and low-speed
correction. No A2 lookahead is present.

**Measured technical status (2026-11-01):** the full matrix executed on Windows11
Pro x86_64; Linux has separate focused host/core qualification. Y1 improves
peak penetration by at least20% in19/21 eligible primary rows, but heavy/thin
high-speed clearance and creep fail registered bounds. Real delayed snapshots
at ages3–5 let both candidates reach the deep hard floor. Scalar bearing also
lacks granular torque under asymmetric support. These findings block broad
production promotion; B0 remains default. The subsequent owner comparison
positively prefers Y1 and describes remaining visible issues as minor; that
judgement does not turn the registered technical failures into passes.
The [dated audit](../audits/2026-11-01-y1-production-envelope.md) retains exact
numbers, source/runtime identities, recurrence, performance triggers and limits.

## How is the physical envelope registered and acquired?

[Protocol](../audits/y1-envelope-2026-11-01/protocol.json) was committed before
candidate results at `ca1fab5f`. It contains 44 synchronous paired cases and
three paired real-worker cases. Each synchronous case uses one native worker,
fixed1/60 stepping, at most two bodies and1800 samples. Mass0.5/1/2,
half/current/double geometry, upright/45/90-degree orientation, initially
rotating edge contact, deep/shallow/edge/slope/loose beds, Sand/Salt,
excavation/collapse, lateral motion, spaced/crowded bodies, region re-entry,
hard terrain and Water are separate strata. Density-scaled mass is not an
established convention for this rectangle fixture; it is not added as a second
matrix. Signed-coordinate World coverage remains an existing native regression;
the finite Godot adapter uses positive coordinates and one seam/re-entry case.

The batch runner and playable review share
`godot/tests/support/y1_envelope_fixture.gd`. The fixture stores planned initial
centres before yielding to scene setup, then explicitly resets the manual
Rapier space from those centres. It assigns entry velocity/spin once.
One packed sample follows each intended main-thread step. Instrumented
observations remain copied values; material edits have an explicit quantity
ledger. The asynchronous arm uses the production `CyberSimulationWorker`
mailbox/cadence/publication and consumes snapshots every three physics frames.
A [pre-acquisition clarification](../audits/y1-envelope-2026-11-01/async-delivery-amendment.json)
retains one real immutable snapshot between consume boundaries, so delivery
actually ages while main continues its ordinary step/sample boundary.
It does not fabricate sample ages or read a live World from the main thread.
Its bounded observer reads values under the exclusive worker owner; live
Rapier access stays on main.

On a prepared Windows build from the exact source:

```text
python tools/experiments/run_y1_envelope.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --project build/godot --output build/campaign-corrected
python tools/experiments/y1_envelope_analysis.py --protocol docs/audits/y1-envelope-2026-11-01/protocol.json --input build/campaign-corrected --output build/y1-envelope-result.json
```

Build the current Windows/Linux extensions using the
[pinned build guide](local-build-and-validation.md). The acquisition runner
authenticates its local Windows build receipt and copied GDScript inputs before
running sequential bounded processes. It refuses an existing output directory.
Logs, failures, deterministic repeats, instrumentation-off controls and timing
repeats remain separate. The reduced comparison never treats repeated ejection
attempts as independent efficacy observations. Default `test_y1_envelope.gd`
runs selector/support/control regressions; acquisition needs explicit arguments.

The protocol fixes credible-rest, clearance, rebound, hover, release, lateral and
performance criteria. Technical failures are retained by mechanism. Scalar
vertical central impulse has no granular torque term: asymmetric support may
expose a **distinct REM-004 mechanism gap** without justifying vertical-law
tuning. Changing thresholds or coefficients after observing results requires a
new registration. Current results and limitations belong in the
[dated audit](../audits/2026-11-01-y1-production-envelope.md).

## How does the owner compare the playable cases?

After source-matched publication, run from this checkout:

```text
python tools/experiments/run_y1_review.py --identity-only
python tools/experiments/run_y1_review.py
```

An isolated source-matched build project can be selected with
`--project build/godot`. Override `--godot` for the pinned engine's actual path.
The launcher authenticates native source inputs, runtime bytes, review project
scripts/scenes/shaders and exact Godot version before opening the scene. It
prints the actual checkout SHA, native source/runtime identity, engine hash and
protocol hash. The review surface also displays the scenario, candidate,
tick, physics backend, source and runtime identity.

Choose a scenario and B0/Y1, then **Reset** (R). Selection applies only through
fresh native World and Rapier-space construction. **Space** pauses/resumes;
**Left/Right** uses existing bounded horizontal control; **E** excavates the bed.
Support-change cases also apply their registered edit at tick600. The scene
pauses at1800 samples. Compare gentle placement, moderate/hard drop,
light/heavy, sideways/angled bodies, shallow support, edge, slope, excavation
and lateral cases. Red polygons use the actual rectangle transform and size;
native stored material supplies the displayed bed.

Record the owner's actual answers to these questions with the printed identity:

- Does Y1 materially improve tunnelling/sinking through Sand?
- Does impact feel too rigid or floor-like?
- Is post-impact withdrawal/settling latency visible or objectionable?
- Are light bodies too strongly supported or heavy bodies still too weakly supported?
- Are lateral motion and rotation/edge support credible?
- Does excavation/support loss look natural?
- Is there an obvious new gameplay regression?

The [initial owner review](../audits/2026-11-01-y1-production-envelope.md#actual-owner-review-and-pause-repair--2026-11-01)
and [subsequent B0 comparison](../audits/2026-11-01-y1-production-envelope.md#subsequent-b0-comparison-and-pixel-presentation--2026-11-01)
are recorded against `ac3839e`. After reviewing both sets, the owner calls Y1
a **definite improvement** and describes remaining issues as **minor**, possibly
mitigated through presentation. Heavy/angled/edge/excavation/lateral behavior is
mostly shared with B0, with some B0 bounce/restlessness worse. The comparison
supersedes interpreting the earlier Y1-only objections as overall rejection.
Engineering disposition remains **ADVANCE WITH REFINEMENT REQUIRED** for the
registered physical failures, with **DISTINCT MECHANISM GAP** for shared
granular torque and tangential contact. The positive owner preference does not
select a production default or authorize merge.

The review-only **body presentation** menu applies immediately without reset:

- **Vector diagnostic · original** retains the initial display for comparison.
- **Cell grid · one-cell inner outline** rasterizes the actual rotated rectangle
  at material-cell centres, with a dark inner border one cell deep.
- **Cell grid · fill only** uses that same grid without the border.

Both grid modes composite into the copied material image before nearest-filtered
enlargement. Rapier pose, native cells, velocities, physics samples and tick are
unchanged; no smoothing, collision snap or angular law is added. Pause first,
switch display, then resume to compare perceived restlessness. Test anchor-90,
angle-45-30 and mass-2-90 first; use edge/slide to distinguish silhouette shimmer
from actual missing rotation or tangential response. Pixel coverage still changes
when the real pose crosses a cell boundary. Improved perceived motion remains a
hypothesis for owner review, not a measured fix or production renderer choice.

The review-only Space shortcut consumes press, repeat and release before GUI
controls; only the initial press toggles. This fixes the observed focused-button
release conflict. Relaunch an existing review process to load the repair.

**Owner comparative preference: Y1.** Full-envelope acceptance/default selection
remains outstanding; #83/REM-004 stays open. The qualification PR remains draft
and unmerged, with explicit owner mergedown authorization required.
