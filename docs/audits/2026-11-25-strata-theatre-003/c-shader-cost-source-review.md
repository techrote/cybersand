# Specialist C — independent shader-cost experiment source review

**Disposition: no blocking source or observation-contract issue found. This is admission of an isolated research protocol, not graphical, performance or application acceptance.** The final application's enabled-optics performance failures remain in force while this experiment runs.

## Reviewed identities and scope

The external observer is commit `c1b13096da9dbbe1c3c45f9ee4c48fa009e6f14e`, tree `250a63d1e4fa968c3420b18106df6415da0648bc`. It observes immutable application `fd0830abcfadd9ae19162e5677943bb131223e59`, tree `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`, through a separately checked-out project. The [machine-readable source review](c-shader-cost-source-review.json) retains the reviewed file hashes and test command.

I reviewed the external GDScript driver, graphical wrapper, A1 shader, strict Python reader, adverse controls, two-platform workflow, prospective registration and inherited application `_progression_sample` boundary. I reran the published revision's eleven adverse controls using `python3 tools/ci/test_strata3_shader_cost.py`; all passed. The reported 15-window, 2,823-check headless diagnostic is explicitly nongraphical and is not substituted for the forthcoming hosted results.

## Observation and custody findings

The A1 shader skips downstream arithmetic only when both the nearest source alpha and already-filtered alpha are exactly zero. It leaves the required filtering before that condition, introduces no epsilon, and preserves nonempty coverage and the literal Classic branch. Exact output remains a testable hypothesis. Dense coverage may gain nothing, and branch divergence could cost time.

The strict graphical admission first requires the unchanged renderer test to pass with each shader. It retains all 18 original captures and all 109 assertions, decodes every PNG, and requires exact RGBA equality, including alpha and the historically sensitive partial-opacity Classic wipe. A mismatch stops the expensive native timing stage. Synthetic graphical equality does not alone establish correctness across all native scenes; the subsequent six same-repeat native world-image comparisons provide a separate real-Workbench witness.

The native driver sets the cached shader code before each fresh scene admission. Its `_settle_focus` extension records actual configuration, loaded shader hash, all four native hashes, camera, actor and unresampled framebuffer before the inherited six paused warm callbacks and timing. No image or native material readback is added inside the timed sample. Each of fifteen registered windows retains all 90 callbacks, completed Rapier steps, actual native publication witnesses and raw interval populations. Shader compilation, reload, paused capture and warmup costs stay outside the per-window rate comparison, but inside the separately labelled whole-process resource observation.

Classic, Architectural-original, Architectural-A1, Clarity-original and Clarity-A1 all use Balanced quality, in three forward/reverse/forward repeats. Exact initial native state, camera and actor are required across all windows; configurations are matched within each original/A1 profile pair. The reader requires the actual shader identity and statistics profile, stable native ownership, zero timed native captures and decorative uploads, bounded three-material processing, unchanged Play processing authority and teardown. A fresh Classic sample must have no optical material or uniform-update work.

The original criteria remain native and Rapier median rates at least 90% of this run's Classic baseline, and median physical p95 at most `max(1.20 × Classic p95, Classic p95 + 10ms)`. The 45-second admission target remains unchanged. Same-profile A1/original median native, Rapier and p95 ratios and three per-repeat rate ratios are also reported. A valid negative performance result remains admitted evidence; it does not become an infrastructure failure or disappear from the population.

Source custody binds both checkouts independently, exact runtime/native identities, external files, actual process commands and retained outputs. The Linux native fallback follows three bounded LFS attempts and reads only two fixed committed native paths. It derives their expected OID and size from the pinned application's LFS pointers, bounds the stream, checks exact SHA256 and size, then replaces the destination atomically. It does not accept a different runtime merely because the batch service failed. The reader rejects escaped or symlinked evidence paths and checks process/log/resource identities.

## Resolved review comments and remaining limits

Before publication I requested an exact `statistics.profile` check and explicit A1-versus-same-profile comparisons. Both are present in the reviewed source, including a wrong-profile adverse case. The eleven controls also reject missing steps, changed camera/native state, altered source/shader identities, timed readback intrusion, alpha-only pixel changes and command-path substitution, while retaining a slow candidate as valid negative research.

One registration sentence broadly says the external wrapper restores the original cached shader at the end. More precisely, the progression driver restores it; the standalone graphical wrapper terminates its isolated test process. Neither edits the application file or shares a surviving shader resource with another process. This wording distinction does not invalidate the observation boundary.

Whole-process CPU and sampled RSS include setup, compilation, reloads, readbacks and retained observer records. They are not per-profile GPU measurements or proof of indefinite leak freedom. Three sequential repeats do not establish statistical independence. Hosted llvmpipe and ANGLE results cannot establish physical Windows 11/NVIDIA performance. Any successful candidate would still require explicit application adoption and qualification under a new source identity; no result may be relabelled as the frozen evaluator's execution.

The independent final Linux [performance HOLD](c-performance-review-linux.md), [five-minute sustained results](c-sustained-v2-review.md) and original admission failures remain valid. Draft/HOLD remains appropriate pending actual experiment results, any later qualified application change, and owner adjudication.
