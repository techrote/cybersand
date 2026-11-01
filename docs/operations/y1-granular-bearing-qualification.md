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

**AWAITING OWNER GAMEPLAY ACCEPTANCE.** No automated observation supplies a human
preference or acceptance. #83/REM-004 remains open. A passing technical subset
cannot promote Y1 to production default; that is a separate owner decision.
The qualification PR stays draft and unmerged until explicit owner direction.
