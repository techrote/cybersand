# CyberSand CI-OPT-003 — final engineering evidence

**Two independently qualified CI improvements were manually merged into main.** [PR #722](https://github.com/techrote/cybersand/pull/722) removes duplicate soliding compilation; [PR #723](https://github.com/techrote/cybersand/pull/723) runs independent worldgen showcases within the existing Make concurrency limit. The controlled complete-worldgen family saved **8m36.231s / 29.52% in one same-worker pair**, with its original scientific work preserved.

**Final main `662df51cd8409a52332fa7ef15d06d8ab8945aed` is qualified.** Native and the complete Linux/Windows attempt-2 retry passed. Final coverage gates completed in 36m36s; all applicable jobs, including advisory timing, completed in 37m02s. Total consumption was 295.0667 unweighted runner-minutes, including the 19.7167-minute failed checkout attempt. This recovered cohort is not a clean performance comparison.

This is the evidence branch for [programme #706](https://github.com/techrote/cybersand/issues/706), not an implementation branch or a request to merge historical evidence into production. No auto-merge was enabled. Original hosted artifacts and source identities remain distinct from synthetic infrastructure controls.

## Delivered source

| PR | Exact implementation HEAD | Final disposition |
| --- | --- | --- |
| #722 | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` | Manually merged as `30e1cddd3d678456df10f52f7a2fb2210a9daaad` |
| #723 | `19023b4016facfda2b13b9a1503742e4a9fe1982` | Manually merged as `662df51cd8409a52332fa7ef15d06d8ab8945aed` |
| #721 | `506dfc8c343c5d24fe26e89a9542cf985c52853e` | Draft/HOLD; compiler-order experiment failed the useful-value gate |

Accepted main tree is `39b658c5de9c5e541312b5190bd5d8ba797c6bed`. Both actual merge trees exactly match their source-qualified PR checkout trees. [integration-source-map.json](integration-source-map.json) records commits, trees, admission reviews, tested merge checkouts, runs, attempt identities and dispositions. [final-source-scope.json](final-source-scope.json) records every changed Git blob and SHA256; all 17 combined changes are CI/build tooling or documentation.

## Read the results

- [ENGINEERING_REPORT.md](ENGINEERING_REPORT.md): complete delivery, measurements, uncertainty, failure repairs, final CI, next bottlenecks and rollback.
- [OFFLINE_REVIEW.md](OFFLINE_REVIEW.md): exact commands to recheck original proof artifacts without rerunning scientific workloads.
- [Soliding performance verdict](performance/soliding-final-performance-verdict.md): independent GO; normal 190.811701 → 108.006146s, ASan/UBSan 1285.232141 → 809.250157s.
- [Worldgen performance verdict](performance/worldgen-runtime-final-performance-verdict.md): independent GO; complete family 1748.640267 → 1232.409098s.
- [Final post-merge analysis](performance/postmerge-final-performance.md): full main-source cohort accounting, failed attempt cost, worker variability and the next measured floor.
- [Final review dispositions](final-review-dispositions.json): no outstanding threads on either delivered PR; P2 diagnostic-custody repair independently verified before resolution.

The pairs were predeclared, cold baseline-then-candidate executions on the same worker within each configuration. They are not population percentiles or a measured 29.52% improvement in complete routine CI. No repeated campaign selected a favorable sample. Full PR and main cohorts retain all applicable jobs, queueing and recovery overhead in their elapsed times.

## Preserved obligations and failure behavior

[contract-soliding.json](contract-soliding.json) and [contract-worldgen-runtime.json](contract-worldgen-runtime.json) provide machine-readable before/after inventories. The worldgen contract SHA256 is `0e5e0b310191ca472788f6f7e7ca21413e577d3591835a136409fce59e811bf6`; all referenced supporting inventories are under [contract-worldgen-runtime/](contract-worldgen-runtime/).

Native retains six families, twenty outer command obligations and 192 core cases in each original normal/ASan/TSan configuration. Each worldgen mode retains all 28 compiler/link commands and 16 program executions; physics retains all 154 invocations. Soliding retains all eight executables and original test order while removing thirty duplicate core compilations per mode. Platform plans retain 338 Linux and 315 Windows cases across 24/23 shards, including graphical, Water/Wave, Gentek and save/reopen obligations where applicable. Compiler/sanitizer flags, watchdogs, required contexts and source/run/attempt binding remain intact. Both published manifests and their 105 source-input hashes are unchanged.

Fresh non-author runtime review reproduced a P2: grouped Make output could discard a hung peer's flushed diagnostics at watchdog termination. Repaired source `19023b4` writes source/run/attempt/binary-bound raw logs before replay. Two independent reviewers repeated actual Make/watchdog timeout and SIGINT controls; both streams survive, the peer is reaped, the principal tail does not run and incomplete execution fails. Successful final Native evidence contains all fourteen exact raw showcase logs. [The thread](https://github.com/techrote/cybersand/pull/723#discussion_r4655537208) was resolved only after independent delta and hosted evidence.

Evidence consumers also received adversarial review. The rejected compiler-order proof is evaluated only through its corrected strict reader. Worldgen requires both the frozen canonical reader and the independently repaired complete-replay supplement. Malformed synthetic artifacts remain distinct from scientific execution evidence.

## Original artifacts and reproducibility

[original-artifact-manifest.json](original-artifact-manifest.json) records original run IDs, attempts, artifact digests and reader identities. The privately supplied `CyberSand_CI_OPT_003_original_evidence.zip` preserves eight original ZIPs unchanged; its SHA256 is `c4acd79239032db6c01b9a9484a48958bd3a9ac16ddc56938862304b6c5fce8d`. This selected archive is not a backup of every platform artifact. The separate `CyberSand_CI_OPT_003_postmerge_evidence.zip` preserves seven original post-merge Native/coverage archives; its SHA256 is `826c66f04d0f1738919b2ddb7d45e3620c69fdc1bee146088c1f333e0d0ac455`. See [its exact manifest](postmerge-original-artifact-manifest.json).

- Soliding proof: [run 44961498877](https://github.com/techrote/cybersand/actions/runs/44961498877), frozen commit `fd4921ace2c4f97f06c70b887778b2366d7a9f0f`. Normal artifact 14730300616 has full SHA256 `350a46cfd441cd24920829231a05ffb6c6a60614c7c6aeea198fb9d36e19d413`.
- Worldgen proof: [run 44963259696](https://github.com/techrote/cybersand/actions/runs/44963259696), frozen commit `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147`, artifact 14732380696.
- Final main Native: [run 44967548870](https://github.com/techrote/cybersand/actions/runs/44967548870), attempt 1 at `662df51`.
- Final main Linux/Windows: [run 44967549040](https://github.com/techrote/cybersand/actions/runs/44967549040), complete attempt 2 at `662df51`. Failed attempt 1 was a planner checkout network timeout and remains in resource and latency accounting.

## Boundaries and owner status

#714 remains preserved. #708 and #718 remain untouched Draft/HOLD, and #721's low-value experiment remains Draft/HOLD. No unrelated feature branch, production algorithm, scientific fixture, runtime binary or gameplay default changed. Programme #706 stays open.

Actual hosted Linux/Windows qualification is recorded separately from physical Windows 11 desktop/UI acceptance, which was **NOT RUN**. The changes concern CI/build infrastructure and introduce no new physical gameplay acceptance claim. Reverse-order, independently qualified reverts of the two merge commits are the rollback procedure; no rollback was executed.
