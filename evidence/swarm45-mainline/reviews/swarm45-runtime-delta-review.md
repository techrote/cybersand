# Independent SWARM004/005 runtime-loader and provenance-gate delta review

Date: 2026-11-21 UTC. Reviewer: `/root/swarm45_native_review`, independent of the implementation agents. Repository: `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline`, branch `integration/swarm004-005-mainline-20261121`. Review state is an uncommitted integration worktree over HEAD `0f0161af337d6d0cee8fa961a9667aff570a75b0`, not a final committed-source or hosted acceptance review.

## Verdict

**GO for the reviewed loader and ordinary provenance-gate source delta. No unresolved confirmed P1/P2 findings.** One confirmed P2 was reported during review and the author repaired it; the exact repair and its regression test were independently checked below. Native source remains byte-identical to the earlier native GO checkpoint.

This verdict does not declare the ordinary checkout ship-ready: the actual worktree still lacks the two OS-specific runtime manifests, and the live provenance gate correctly rejects that incomplete publication. The final eight-path publication, exact frozen-commit review, hosted Linux/Windows gates, extracted package gates, and physical owner acceptance remain separate.

The prior report `/workspace/scratch/038267c40e11/swarm45-native-review.md` is preserved unchanged, SHA-256 `88e21f4483030f90fb72a277b9ae28333df01d2d5dd0e1f96d3d089da0117d33`. This is a separate checkpoint. No repository source, donor, or SWARM006 files were modified by this reviewer.

## Loader and protocol review

Reviewed `workbench_reciprocal_panel.gd` runtime selection and the new `test_workbench_reciprocal_runtime.gd` fixture against the earlier panel checkpoint. The packaged path chooses `swarm004-runtime.<lowercase OS>.json`, with the correct `.exe` suffix on Windows. Legacy `swarm004-runtime.json` is consulted only when the platform-specific file is absent. A present malformed, stale, wrong-platform, or wrong-definition binding is rejected; it cannot fall back to an otherwise valid legacy binding. The executable path is constructed by the loader rather than taken from arbitrary manifest content.

`_checked_runtime` requires a nonempty source identifier, a 64-character expected SHA-256, an existing executable file, and exact file SHA agreement. Optional platform and native-definition fields are checked when present. This preserves the legacy and explicitly supplied environment bindings while allowing the stronger published platform bindings. The protocol definition pin is unchanged by this loader delta and matches the current native definition. No decoder, request budget, material, actor, or Apply authority is broadened by this change.

The already-reviewed stale-authority behavior is retained: `generate()` retires the previous proposal before runtime admission, so a rejected new binary binding cannot retain an applicable old preview. The generic runtime fixture uses inert temporary files and does not execute native code or mutate a World.

All 12 files in the producer's final `godot-source-snapshot.json` were independently hashed against both the current repository Godot tree and the isolated tested Godot project. All match. The loader fixture has 12 passing assertions; the packaged controls result has 32 passing assertions and three completed native requests. The Workbench producer reports that this packaged controls invocation cleared the explicit runtime environment and supplied the correct Linux-specific binding beside a deliberately stale legacy manifest. The result text was inspected; this reviewer did not repeat the Godot invocation or independently observe the process environment.

## Ordinary provenance gate and repository integration

Reviewed the complete new `check_swarm_runtime.py`, its seven final unit tests, the additions to `check_repository.py`, the validation-contract imports, and the two targeted `.gitattributes` rules. The source gate:

- Recomputes the current native definition and its complete per-input inventory, and requires the exact Workbench admission pin.
- Requires both exact OS-specific manifests, the programme/schema/platform/artifact binding, a full source identifier, a SHA-256, a positive integer byte length, and exact current native input custody.
- Distinguishes a matching Git LFS pointer from materialized executable bytes; `--require-materialized` rejects the pointer form.
- Checks materialized bytes and the Linux ELF64/x86-64 or Windows PE/x86-64 target header without launching a generator or historical corpus.
- Retains Unix execute-permission enforcement for the Linux payload on hosts that expose Unix mode bits.

The 43 current native inputs recompute to definition `fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618`. The source inventory and definition ordering agree with the previously reviewed native Makefile/custody construction. LF normalization agrees with the repository's text attributes.

The ordinary repository gate now collects the SWARM gate errors and includes exactly the two new CLI paths in its committed-LFS identity check. The `.gitattributes` delta contains those two explicit paths; it does not apply an expansive executable wildcard. The `SwarmRuntimeTests` import brings the focused regression suite into the ordinary validation-contract suite. The later `SwarmPackageTests` import is also present; package qualification implementation is outside this narrow review.

This is an identity/rebuild gate. A manifest cannot itself prove that a compiler produced a binary from a source commit, and these checks make no such execution claim; the source build custody and hosted qualification establish that separate evidence.

## Resolved P2: Unix execute bits on a Windows checkout

The initially reviewed gate (`check_swarm_runtime.py` SHA-256 `fdfb0f9b486c5967d4e91ae569c042ecf70b7c9eb396dc66b24793a1d9772f87`) unconditionally required `st_mode & 0o111` for the Linux artifact, even while the checker ran on native Windows. The extensionless Linux payload does not gain meaningful Unix execute bits on Windows; Python's `chmod()` controls only the Windows read-only flag. Thus an otherwise valid fully materialized Windows checkout and the positive test fixture could be rejected. The Ubuntu-hosted passing tests could not establish Windows host portability.

Primary platform references: [Python os.chmod documentation](https://docs.python.org/3/library/os.html#os.chmod) and [CPython Windows attribute-to-mode implementation](https://github.com/python/cpython/blob/main/Python/fileutils.c). This was a source-level portability finding, not a claimed observed Windows run.

The author repaired the condition to require Unix mode bits only when `os.name != "nt"`. The new regression supplies a materialized Linux artifact with mode `0644` and patches only the subject module's OS namespace to Windows semantics, leaving pathlib's actual host untouched; the complete gate passes. The existing missing-permission assertion still runs on Unix, while missing-manifest refusal remains asserted on all hosts. Independent final focused execution: **7 tests PASS**. No binary/source/hash/target check is weakened by this host-specific permission repair.

I also inspected the publisher's narrow complementary checks: it sets the Linux destination to `0755` and `check_index()` independently requires Git mode `100755` for the published Linux CLI. This examination covers that mode-preservation check only, not the complete publication workflow. **P2 closed.**

## Exact reviewed file hashes

SHA-256 values below were captured before and after the independent final seven-test run; all remained stable.

| Repository-relative file | SHA-256 |
|---|---|
| `.gitattributes` | `34caa3afce71d2f9ca3feb50bc0150d2e03fe363d01dd83751bf6eef6be2826d` |
| `tools/ci/check_swarm_runtime.py` | `c626f2a0856125326c74fdfdb3b284ed543d391b95ae8518b093f2341f4a5f57` |
| `tools/ci/test_swarm_runtime.py` | `6bd65924c42e3766f1dd20a7f0fcb2961a70ee01b789da8c4c8bc97bd0443760` |
| `tools/ci/check_repository.py` | `e4ebfd2e6faca4ea9a12785be8afb60a5c5479edcd555ddf436c3081a4302e03` |
| `tools/ci/test_validation_contracts.py` | `59ccfd7901a519c8930423df65a3bf77c2139b074fe9487f974fb5afc9883bf0` |
| `godot/scripts/workbench_reciprocal_panel.gd` | `1a689a37522aee8ff36118a2d12704f89ea7425c522826608e1123f6676f7d80` |
| `godot/scripts/workbench_reciprocal_protocol.gd` | `5bfe67fe0e3b4587e584bd45f5e7a003ad796ed319a54ba420b8e760c9cf1694` |
| `godot/tests/test_workbench_reciprocal_runtime.gd` | `8b9ae251e675a59d7f768d0f86d31573e6a77a92904471407009323ad7b2378a` |
| `native/experiments/gentek_swarm/reciprocal_mosaic.cpp` | `94a38e05026e6f16b84d1ba2e506775f4159e21424c958e4886e4981cc65579d` |
| `native/experiments/gentek_swarm/swarm005_research_tests.cpp` | `c7226cae0f92858dad52ff8e285eee22b40274e7c1a01d45d7e840fd3a4861b1` |
| `tools/swarm45/publish_runtime.py` | `92525565195b014ad276729de0c6901cfdb9b4bb22b226970e5b9a0530139aa7` |

The two native hashes and definition match the prior GO report exactly. The prior native ASan-address and UBSan pass remains valid for those bytes; leak detection was disabled (`detect_leaks=0`) and no leak coverage is claimed.

## Examined evidence

| Evidence | Result | SHA-256 |
|---|---|---|
| `swarm45-workbench-preflight/godot-source-snapshot.json` | 12/12 hashes match current source and tested project | `8fb1fc222bc8acccc91b5199e4f460bf065d654c0e54e077f8cbf573f29586e2` |
| `swarm45-workbench-preflight/test_workbench_reciprocal_runtime.log` | 12 checks PASS; inert files, no native/World execution | `0fa432a28acf68725c65ce23d671b36e9e75b4cf4b815ccc99d33b9ebdd1ee51` |
| `swarm45-workbench-preflight/swarm45_reciprocal_controls-packaged.log` | 32 checks PASS; real native requests; no Apply/reciprocal acceptance claim | `f3fb3ecba04550e45d2516c24021628b9ee3d032b566deb95478808a3c37306a` |
| `swarm45-runtime-review-helper-tests-final.log` | Independently run final 7 Python runtime tests PASS, exit 0 | `dcedfcd82c70508389f045fe2a44db24c2a38f0ddc9e48fd6f86cbee1d5de4ed` |
| `cybersand-swarm45-mainline/evidence/swarm45-local/validation-contracts-final.log` | Author's final combined 41 tests PASS, 0.221 seconds | `b72eb2e55da6268cc5b29f2ccded22569430d4022ba1b407631b8a10041e34cb` |
| `swarm45-runtime-review-current-gate.json` | Expected refusal: both published OS manifests absent | `1c19c3cef936183c9e1e8895a135fecc1c88dcfb77f2e9cb025834632e6d2811` |
| `swarm45-runtime-review-helper-tests.log` | Preserved pre-repair independent Linux 6-test PASS; does not cover Windows semantics | `aaf9ac17691aed131bc6d2cd915e2660d0ec4cec97036485d35e1566fd25b81a` |
| `cybersand-swarm45-mainline/evidence/swarm45-local/validation-contracts.log` | Preserved earlier 39-test result; superseded for current combined imports | `3aadbc29304f6ff32e2d9b699d8a32274ea1cd590c39fd3382ebdbe027669467` |

Evidence paths are relative to `/workspace/scratch/038267c40e11`. The final focused command was `python3 -B -m unittest discover -s tools/ci -p test_swarm_runtime.py -v`, with a 30-second subprocess timeout; it completed in 0.017 seconds. `git diff --check` was clean. No broad native or historical corpus was rerun by this reviewer for the loader-only delta.

## Limits and next review boundary

The Godot evidence is local Linux/headless on exact Godot `4.7.stable.official.5b4e0cb0f`, with the earlier documented GCC14 diagnostic adapter build. It is not hosted platform acceptance. The Windows-permission regression models Windows semantics; it is not native Windows execution. The current live gate cannot pass until the intended eight-path runtime publication is installed and validated; the missing manifests are recorded as an expected unfinished publication boundary, not treated as a source-code defect.

Final review should bind the exact committed integration HEAD, both built CLI/runtime provenance pairs, the final hosted qualification artifacts, and the final published LFS identities. Physical owner evaluation and reciprocal science acceptance remain separate from source integrity and UI protocol tests. This delta leaves the earlier native/protocol GO intact and closes the sole P2 found in this scope.
