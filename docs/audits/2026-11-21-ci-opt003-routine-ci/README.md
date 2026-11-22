# CI-OPT-003 routine CI accelerator — engineering evidence

This branch retains source-bound evidence for [programme #706](https://github.com/techrote/cybersand/issues/706). It is not an implementation branch or a request to merge historical evidence into production. Original hosted artifacts remain in their GitHub Actions runs; these records identify their digests and independently verified contents. Synthetic failure controls are distinct from scientific execution.

## Delivery checkpoint — 22 November 2026

**PR #722 has been independently qualified and manually merged.** The worldgen improvement is still being qualified. No auto-merge is enabled.

| Candidate | Exact HEAD | Disposition |
| --- | --- | --- |
| [#721 — compiler ordering](https://github.com/techrote/cybersand/pull/721) | `506dfc8c343c5d24fe26e89a9542cf985c52853e` | Draft/HOLD: safety passed, but only about15s summed target saving; experiment stopped |
| [#722 — soliding object reuse](https://github.com/techrote/cybersand/pull/722) | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` | Manually merged as `30e1cddd3d678456df10f52f7a2fb2210a9daaad`; post-merge checks running |
| [#723 — showcase concurrency](https://github.com/techrote/cybersand/pull/723) | `19023b4016facfda2b13b9a1503742e4a9fe1982` | Final source, inventory and repaired diagnostic custody independently reviewed; full hosted CI passed; controlled proof pending |

The #722 merge tree `062f8ec0df0e9f1cb548c11860968301cad0ae16` exactly matches its candidate and tested merge checkout `da63e0f3d5a189a67acdc2e1bc47b87d8a946ae5`. [Source/failure review6008792911](https://github.com/techrote/cybersand/pull/722#pullrequestreview-6008792911), separate independent performance GO and [manual admission review6009060691](https://github.com/techrote/cybersand/pull/722#pullrequestreview-6009060691) preceded the merge.

#723 was retargeted to accepted main without changing HEAD. Its baseline cd32 and accepted main30e1 have identical trees. A fresh Git merge-tree calculation produces exactly `39b658c5de9c5e541312b5190bd5d8ba797c6bed`, also the tree of tested checkout `5c56bce96881291c57cea6575e1f4d5fb89485cc`. `integration-source-map.json` records each identity separately.

## Accepted measured improvement

One cold baseline-then-candidate pair per complete soliding family used the unchanged production runner, original watchdogs and all commands/tests.

| Complete workload | Baseline | Candidate | Observed pair saving |
| --- | ---: | ---: | ---: |
| Soliding normal |190.811701s|108.006146s|82.805556s /43.40%|
| Soliding ASan/UBSan |1285.232141s|809.250157s|475.981984s /37.03%|

The component savings sum to558.787540s, or9.3131 runner-minutes. This is not a whole-CI wall-time percentage or population estimate. The modes used different hosts; within each pair the worker/compiler was identical. OS caches may be warmer for the second arm despite cold build directories.

The change removes30 duplicate core translation-unit compilations per mode:44 become14. All8 executables and ordered tests remain. The unchanged large sanitizer build took578.848→584.298s, while the deduplicated remainder fell703.565→222.702s. The approximately8GiB high-memory compilation stays serial. There is no cross-run artifact or test-result cache.

The separate full #722 Ready-state cohort passed76 executed jobs in30m52s, using290.8167 unweighted runner-minutes. Worldgen remained critical; this cohort establishes complete qualification, not overall speedup. First complete Native family arrived at2m10. Earlier Wave feedback is unrelated. See `performance/soliding-final-performance-verdict.md` for worker identities, original records and uncertainty.

## Runtime improvement under qualification

#723 retains all7 showcases and9 principal tests per normal/sanitized mode. Showcases share the original Make two-job limit with compilation. It does not import #721's rejected ordering change.

Fresh review reproduced a P2 in initial candidate28ec075: grouped Make output could lose a hung peer's flushed diagnostics when the watchdog killed Make. Source19023 writes both streams into source/run/attempt/binary-bound files before replay. Timeout and SIGINT controls retain those bytes, stop the principal tail, reap the peer and record incomplete failure. Successful Native evidence requires all14 raw logs. Compiler/sanitizer flags, scientific inputs and watchdogs remain intact.

Independent scientific/runtime and CI/failure delta reviews pass. Superseded source28ec075 and cancelled runs are not qualification. The full final cohort passed78 executed jobs in30m09s, using285.4167 unweighted runner-minutes. Its two extra jobs versus B are cheap Ready-scope checks, not scientific cases. The Native workflow waited7m26 behind a superseded run; that delay remains included. Its worldgen family completed in1241.791111s with all14 raw logs retained. This is final-source safety qualification, not causal performance evidence. The single complete-worldgen pair is still pending; its baseline finished and candidate began at00:14:07 UTC.

## Qualification and artifact identities

- [#721 Native44959001079](https://github.com/techrote/cybersand/actions/runs/44959001079) and [worldgen proof44959131042](https://github.com/techrote/cybersand/actions/runs/44959131042). Normal235.386537→228.906391s and sanitized1180.636648→1172.141137s show insufficient value. No additional campaign.
- [#722 Native44960371733](https://github.com/techrote/cybersand/actions/runs/44960371733), [Linux/Windows44960371856](https://github.com/techrote/cybersand/actions/runs/44960371856), [soliding proof44961498877](https://github.com/techrote/cybersand/actions/runs/44961498877).
- Frozen soliding proof `fd4921ace2c4f97f06c70b887778b2366d7a9f0f`. Normal artifact14730300616 ZIP SHA256 `350a46cfd441cd24920829231a05ffb6c6aeea198fb9d36e19d413`; sanitized artifact14731021438 ZIP SHA256 `3cd95df73c231f7b305f8b8c724f460528625a56cce0836c4fe7685d8d5d54b3`.
- Post-merge #722 [Native44964966221](https://github.com/techrote/cybersand/actions/runs/44964966221) and [Linux/Windows44964966242](https://github.com/techrote/cybersand/actions/runs/44964966242) are running. Push and Ready-state PR event scopes differ; compare their elapsed times only with that distinction explicit.
- Final #723 [Native44963101962](https://github.com/techrote/cybersand/actions/runs/44963101962), [Linux/Windows44963102007](https://github.com/techrote/cybersand/actions/runs/44963102007), and [whole-worldgen proof44963259696](https://github.com/techrote/cybersand/actions/runs/44963259696). Frozen proof `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147`.

Independent malformed-evidence controls found weaknesses in the first proof comparator and the worldgen raw-log/replay coupling. The first proof is admitted only by its corrected, independently reviewed strict reader. The frozen worldgen producer stays unchanged; its offline supplement requires complete source-derived replay groups. No malformed synthetic artifact is a claim of a production runtime failure. No original summary alone is an admission authority.

## Preserved obligations and next work

Platform plans retain338 Linux and315 Windows cases across24/23 shards, including existing graphical, Water/Wave, Gentek and save/reopen obligations where applicable. Native retains6 families,20 commands and the192-case core registry in its original configurations. Machine inventories preserve exact test names, compiler flags, watchdogs, status contexts and source inputs. No production algorithm, scientific fixture, gameplay default, published runtime binary or provenance manifest changed.

`contract-soliding.json` contains B's full inventory. `contract-worldgen-runtime.json` contains the corrected cd32→19023 comparison, separating inherited B work from C. Its hash is `0e5e0b310191ca472788f6f7e7ca21413e577d3591835a136409fce59e811bf6`; independent inventory review found no P1/P2/P3. All92 workflow inventories and both published manifests with105 source inputs were checked. Reports and actual boundary controls are under `reviews/` and `native/`.

`performance/gde-followup.md` identifies real dependency compilation and platform shard execution as the next likely limits. A bounded dependency compiler-parallelism experiment ranks ahead of a more complex cross-run cache. No additional hosted campaign has been started. The existing supersession issue is recorded separately; no unreviewed cancellation change is bundled into these candidates.

#714 remains preserved. #708/#718 remain untouched Draft/HOLD. Programme #706 stays open. Reverse-order reverts of accepted CI increments, each with fresh qualification, are the rollback strategy. B-only rollback would be a reviewable `git revert -m 1 30e1cddd3d678456df10f52f7a2fb2210a9daaad` on a dedicated branch; it has not been executed.
