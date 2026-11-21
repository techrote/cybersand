# SWARM004/005 committed-source review receipt

Date: 2026-11-21 UTC. Independent reviewer: `/root/swarm45_native_review`. PR: #715. Repository: `/workspace/scratch/038267c40e11/cybersand-swarm45-mainline`.

**Checkpoint PASS for source identity and the narrow build-recipe delta described below. No unresolved confirmed P1/P2 findings in this reviewed scope. The earlier native/protocol and runtime-loader source-review conclusions carry forward to this frozen source. This receipt does not grant final merge, publication, Ready, scientific promotion, or physical owner acceptance.**

## Exact commits and request

| Identity | Verified value |
|---|---|
| Frozen source commit | `a08c0e77601c9451ece3a15248d4255164911d5f` |
| Frozen source Git tree | `2caadc63dbf22b056fc5147b55ef57079b270324` |
| Merge parents | Accepted main `0f0161af337d6d0cee8fa961a9667aff570a75b0`; frozen donor `580ff82f285b7aeda8fb4a2a0d034425f0d0401d` |
| Qualification request commit | `9b688aed1f06f031f983c27f50d1f17821446e43` |
| Request Git tree | `5d048be7dc3248dd2e0ecd8e13ac1eca7c8b7a77` |
| Request JSON SHA-256 | `fa5102b7e8345ff4deb6b2cf899eb9e71084d39459d83b973318858d6bdf6504` |
| Native definition, recomputed from 43 committed inputs | `fe62e15412459c22c6f81e479fa1ff2917d7359d747581c9891b83fbf2f75618` |

The request commit has the frozen source as its sole parent and adds only `.github/swarm45-mainline-request.json`. Its action is `qualify-mainline`; it pins the exact source above, accepted main, frozen donor identities, and matching native definition. There is no native, Godot, build, or protocol delta between these two commits. The reviewed current checkout has the request commit as HEAD, no tracked changes, and only the existing untracked evidence directory.

## Previous checkpoints and Godot snapshot

Both earlier report files are unchanged:

| Preserved report | SHA-256 |
|---|---|
| `swarm45-native-review.md` | `88e21f4483030f90fb72a277b9ae28333df01d2d5dd0e1f96d3d089da0117d33` |
| `swarm45-runtime-delta-review.md` | `dfcd78b0380d2621e0f331b5c4c0e04ebbae78d2a0a41ed5373e78a12b84ac20` |

The parent reports these complete preflight reviews were published under the agent-review label in PR comments `7069012502` and `7069012733`; this checkpoint verifies the local report bytes, not the remote comment text.

All **12 files** in `swarm45-workbench-preflight/godot-source-snapshot.json` match the committed bytes in both frozen source and request commit, and the working checkout. Snapshot SHA-256: `8fb1fc222bc8acccc91b5199e4f460bf065d654c0e54e077f8cbf573f29586e2`. The panel hash from the first report is intentionally superseded by the already-reviewed loader hash in the second report.

Across the two reports' latest applicable source hashes plus the final Godot snapshot, **25 of 26 distinct files are unchanged**. The sole additional difference is the Makefile hook reviewed below. Both native repair files, final loader/protocol, runtime regression fixture, ordinary provenance gate, replay drivers, and retained adapters match their applicable preflight reviews. The three retained native adapter files remain byte-for-byte equal to donor `580ff82f285b7aeda8fb4a2a0d034425f0d0401d`.

## Makefile delta and build provenance

`Makefile.reciprocal` changed from SHA-256 `cbf0807518fc30513d73a2754627b04fddaa629d5ca153f6ed7653bcd1633285` to `3f8d7676cc0a5f74db8c936c4618af708c304200c5a1a286f68dd4a1fc9a490c`. Removing exactly the single added line `FLAGS += $(CPPFLAGS)` from the committed bytes reconstructs the earlier reviewed hash. No other recipe change exists relative to that checkpoint.

I independently inspected the caller in `tools/swarm45/build_runtime.py`. On Linux it passes `CPPFLAGS=-D_GLIBCXX_USE_CXX11_ABI=0` to the complete reciprocal object set used by the strict CLI/tests/replay and the separately built sanitized tests. Compilation recipes consistently include `FLAGS`; no reciprocal object is compiled through an unaffected parallel rule. The GDExtension is built by its separate existing script before this standalone make invocation, and Windows receives no new CPPFLAGS argument. Commands and the flag are recorded in build/toolchain receipts.

The stated basis is preserving the existing Linux runtime ABI ceiling for the standalone JSON/text process. This source review confirms the flag's scope and custody; it does not establish the resulting ELF imports or execute the newly flagged binaries. The committed Linux floor gate checks both adapter and CLI, with ceilings GLIBC 2.34, GLIBCXX 3.4.30, and CXXABI 1.3.9, and publication requires that gate's pass. Actual frozen-source hosted evidence must establish compliance. The prior local GCC14 diagnostic binaries and sanitizer run are not relabeled as execution of this hosted flag configuration.

## Selected committed file hashes

| Repository-relative file | SHA-256 at both commits |
|---|---|
| `native/experiments/gentek_swarm/reciprocal_mosaic.cpp` | `94a38e05026e6f16b84d1ba2e506775f4159e21424c958e4886e4981cc65579d` |
| `native/experiments/gentek_swarm/swarm005_research_tests.cpp` | `c7226cae0f92858dad52ff8e285eee22b40274e7c1a01d45d7e840fd3a4861b1` |
| `native/experiments/gentek_swarm/Makefile.reciprocal` | `3f8d7676cc0a5f74db8c936c4618af708c304200c5a1a286f68dd4a1fc9a490c` |
| `godot/scripts/workbench_reciprocal_panel.gd` | `1a689a37522aee8ff36118a2d12704f89ea7425c522826608e1123f6676f7d80` |
| `godot/scripts/workbench_reciprocal_protocol.gd` | `5bfe67fe0e3b4587e584bd45f5e7a003ad796ed319a54ba420b8e760c9cf1694` |
| `godot/tests/test_workbench_reciprocal_runtime.gd` | `8b9ae251e675a59d7f768d0f86d31573e6a77a92904471407009323ad7b2378a` |
| `tools/ci/check_swarm_runtime.py` | `c626f2a0856125326c74fdfdb3b284ed543d391b95ae8518b093f2341f4a5f57` |
| `tools/ci/test_swarm_runtime.py` | `6bd65924c42e3766f1dd20a7f0fcb2961a70ee01b789da8c4c8bc97bd0443760` |

The complete 26-file comparison, exact report hashes, commit/tree identities, request JSON, donor-equality results, and reviewed Makefile delta are retained in `swarm45-committed-source-review-inputs.json`, SHA-256 `e48af26c9fb809a7aa9134ff7d4b0cb1b281c1b54f9b92ab9bf290f933b0d9ba`.

## Evidence and admission boundary

This receipt used read-only Git object extraction, SHA-256 comparison, source inspection, and native-definition recomputation. It did not rerun the native corpus, change repository source, or modify earlier reports. The CI/publication reviewer separately owns their 32-file review; I did not duplicate or broaden that review here.

Scoped run `44947666723` was reported active by the parent at the handoff. No hosted result, artifact, Linux ABI-floor measurement, Windows execution, extracted evaluator result, or runtime publication is claimed passed in this receipt. Full applicable CI and exact-source platform receipts must be reviewed when complete. Physical owner acceptance remains separate, and the candidate remains **Draft/HOLD** pending its admission gates.
