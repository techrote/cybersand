# Existing-clock native stage attribution

Status: executed diagnostic; no native treatment selected. Application and original
driver are `0bd275a36669a18217f7861372bbf54a837af750`. Native binary
`e550846d9e7656ffd6cc90dfa0db4b3a17e1dbe2908e8e89f5869076d3233b74`
was built by the retained original `4bde032f27e90e6e974b3ddc123264afa8fa5012`
campaign; its entire native/build input closure matches this application.
Official Godot4.7 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.

The registered `tools/pubpres_recovery/run_native_stage_probe.py` changes only
the existing Wave column-probe readback selector. It keeps the original
Wave2048 gameplay scene, full source/observer/physical reader and exact144-step
actor trajectory and admitted-movement comparison. Every completed physical
step joins one same-World/tick/body-sample native stage delta. All144 joins and
all frozen correctness gates passed in both runs. The reader's five independent
adversarial tests passed before execution.

## Results and limits

| Existing elapsed bracket | Quiet mean milliseconds | Contended development mean milliseconds |
| --- | ---: | ---: |
| Entire native World tick | 97.4197 | 115.4490 |
| Wave column | 46.2411 | 49.6888 |
| Wave flux | 16.7811 | 17.2468 |
| Wave apply | 6.3276 | 7.7553 |
| Wave prepare | 0.5917 | 0.7577 |
| Wave merge | 0.0602 | 0.2779 |
| Wave launch | 0.0848 | 0.0666 |
| Outside those Wave stage brackets | 27.3331 | 39.6559 |

The quiet native tick p50 was113.4942ms, p95 155.9606ms, p99 174.7106ms and
maximum217.7668ms. Mean values and medians differ because the scene's amount of
required work changes over the captured real steps. Quiet physical progression
was7.1415steps/s. This is a diagnostic with a changed observer; it is not an
optimization result and must not be compared as an arm of the idle experiment.
The other run was prospectively labelled development during engine compilation.

These are native elapsed brackets, including work and descheduling. The residual
is not a measure of non-Water CPU. No native start timestamp is derived from the
profiler. Whole-process CPU samples include setup and capture; capture-only CPU
cannot be reconstructed from their clocks.

## Next discriminating mechanism

The production pool currently waits for every configured worker to acknowledge
every dispatch, even when a late worker claims no task. Its borrowed context and
global atomic task index require that whole-pool lifetime barrier. Wave performs
multiple pool dispatches in a turn, as do phased material jobs. That source fact
makes a bounded actual-task completion experiment credible, but does not show
that the barrier caused any measured delay. The prospective registration is
`tools/pubpres_recovery/task_completion_registration.json`.

The proposed default-off path couples a task claim and context acquisition under
the existing mutex, then retires the dispatch only after every actual task has
returned. Late idle workers cannot retain a stale context. Required work,
physical semantics, worker count and deterministic region ownership remain
unchanged. Adversarial production-pool lifetime tests, semantic parity,
sanitizers, independent review and source-matched0/1/1/0 progression comparisons
must precede any selection.

## Original evidence

`native-stage-local/` contains the exact results, launch/configuration receipts
and a hash manifest for each full original evidence directory. Full raw event,
presentation, process/resource and graphical evidence remains in the mission
artifact custody. Generated imported-project/profile caches are excluded from
the manifest. Both contended and quiet runs are preserved; neither is discarded
in favor of the faster observation.
