# Submitted presentation and CPU calibration

**Draft / HOLD. Prospective registration; no performance result is implied by this file.**

The final observer now has an explicit optional submitted-pose sidecar. It
connects to `frame_pre_draw`, reads the actual submitted overlay/selected
physical history and Follow state, and records the existing draw notification
after the unchanged primary trace append. It never reads native World, changes
Rapier credit, updates a camera, uploads a texture or ACKs publication. The
original full V3 physical observer and reducer remain intact. The separately
registered eight-actor derivation includes the same supplementary hook.

The helper source is staged and included in the executed source identity even
when disabled. Before/after requested selector receipts must agree with the
arm. Enabled captures require their independently validated sidecar. Disabled
captures must produce no sidecar and report presentation/freshness as absent.
Neither mode claims GPU completion, device input arrival or physical scanout.

The external process CPU sampler runs identically in all new matched arms. Its
ownership/cleanup function is mechanically derived from the retained runner;
its accounting includes the actual Godot process and all its threads over the
observed process-lifetime interval. It includes setup, has its own clock, and
is not relabelled as capture-only CPU. Failed reads, unobserved launch/exit
tails and the maximum sampling gap remain visible.

## Prospective calibration

`tools/pubpres_final/observer_registration.json` registers **off / on / on /
off**, same exact current application/native runtime, original full observer,
Full two-image publication, Early physics, coherent presentation, actual Safe
rendering owner and continuation OFF. Both primary workloads are registered:
the Wave512 reference and current gameplay Wave2048. Each arm retains the
original minimum ten seconds and 144 independently completed Rapier steps,
with the original ninety-second cap. A case may be scheduled separately to
bound hosted work; this does not authorize dropping an adverse case or arm.

Run `run_comparison.py --mode observer-abba --slots 2`, with the same candidate
source/runtime supplied for both source argument pairs and one or both
registered `--case` values. The order supplies its own selector, so
`--presentation-observer` is rejected in calibration mode. Exact source/runtime
custody, native and terrain admission, actual callbacks, actor trajectories,
input outcomes, Water and current GPU history must pass before the calibration
is valid. Every enabled/disabled arm must have the same physical outcome.

The report retains all four physical rates, p50/p95/p99/max gaps, severe counts,
process CPU and callback costs, plus all four on/off cross-arm ratios. It does
not assign an invented acceptable overhead percentage or inherit an older
observer calibration. Failure to establish a stable small effect prevents
cross-generation timing attribution; this does not justify silently subtracting
callback time or discarding slow arms. The owner has supplied no absolute
overhead budget, and a bounded cohort is not a statistical confidence interval.

For new source/slot or renderer comparisons, `--presentation-observer` explicitly
enables the same helper on every arm. Absent that flag, the sidecar stays off.
Mixed eight-actor qualification explicitly requires it. Deadline timing derives
from the same final observer and must separately validate actual source-bound
sidecar evidence; an environment setting alone is insufficient.

Source references: [final observer](../../../tools/pubpres_final/pubpres_final_gameplay.gd),
[supplementary helper and independent validators](../../../tools/pubpres_final_observers/README.md),
[calibration/integration validation](../../../tools/pubpres_final/observer_support.py).
