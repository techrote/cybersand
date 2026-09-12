# Validation and provenance — 12 September 2026

**Observed results, including failures. This is not an all-green release or #19 acceptance certificate.**

## Tested identities and durable evidence

The selected engine baseline is `d39e31f03f2e39b0022d507b79fbee5c2439436d`. Standalone research and its collector were tested at `f0907126339033f849df40e9525caa66462e744a`. GitHub Actions run [34688377205](https://github.com/techrote/cybersand/actions/runs/34688377205), attempt 1, job `103539259547`, completed collection and published evidence in commit `45d1754096f873511fc7b2f09de3a4bae487d1e2` at 10:27:32 UTC. Its overall conclusion is **failure**, because the final reporting step preserves the failed runtime-provenance gate rather than masking it.

The complete [per-command results](runs/f0907126339033f849df40e9525caa66462e744a/checks.json), [generated summary](runs/f0907126339033f849df40e9525caa66462e744a/data/summary.json) and [source/data checksums](runs/f0907126339033f849df40e9525caa66462e744a/data/manifest.json) are committed, not merely ephemeral logs. Each attempted command records its arguments, timeout, exit status, output-tail evidence and full-log SHA-256. The manifest identifies individual research sources and generated files; it does not pretend to identify a Godot runtime build.

The hosted environment was Ubuntu 24.04, kernel `Linux-6.17.0-1022-azure-x86_64-with-glibc2.39`, Python 3.12.3 and GCC/G++ 13.3.0. Source was checked out at the exact tested SHA with complete history and materialized LFS dependencies. The companion workspace used the existing documentation-workflow pin `6a58311982941b75f46e22109a0829e5acb83c7e`.

## What passed

| Check | Observed result | Scope |
|---|---|---|
| Standalone research unit tests | 23 tests passed | Configuration/refusal, arithmetic, geometry, recipes, orders and abstract ownership checks |
| Registered precomputation | All assertions passed | 174,720 local pair cases; 156 policy vectors; quantization/countdown tables; geometric and protocol studies |
| Independent repeat | Complete generated file maps byte-identical | Same source, same hosted environment; not cross-platform floating-point identity |
| C++ projection oracle | Strict-warning C++20 build and execution passed; output byte-identical to Python CSV | 504 legal states and 1,512 coverage comparisons, not the native render bridge |
| Documentation structure | Passed: 60 documents, 101 canonical claims, 977 local links, 45 anchors, 32 questions | Existing corpus at the tested source checkpoint; no semantic certification |
| Historical M11 integrity | Passed: 18 retained records and 28 source hashes | Audited historical revision `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, not current artifact acceptance |
| Validation failure contracts | 8 tests passed | Existing checker regressions |
| Frozen retrieval questions | All 32 found a canonical route within the evaluation's search depth; 22 at rank 1; MRR 0.8229 | Retrieval ranking, not answer correctness |
| Challenge retrieval questions | All 16 found a canonical route within the evaluation's search depth; 12 at rank 1; MRR 0.8646 | Retrieval ranking, not answer correctness |
| Native C API header | C11 syntax check passed | Existing public header |
| Native C++ build and suite | Build succeeded; 55 tests passed | Existing native controls on the selected source baseline, not a new runtime #19 policy |
| Whitespace | `git diff --check` passed against the selected base | Research source checkpoint before the explanatory report commit |

The native suite includes Water conservation/leveling, boundaries, worker parity, interest re-entry, failed-world quarantine, immutable snapshots and C API controls. It is valuable fresh Linux evidence, but the independently tested Python policy has not been installed into `World::tick`. The two groups of tests must not be added together and described as 78 new engine tests.

## What failed, and why it remains visible

`python3 tools/ci/check_repository.py --require-materialized` returned exit code 1. All **18 required runtime payloads were materialized**, with no missing LFS files. Its errors were **14 source-input provenance mismatches**: the same seven inputs require a rebuild for each existing Windows and Linux x86_64 Godot 4.7 artifact.

```text
godot/native_extension/cyber_demo_bridge.hpp
godot/native_extension/cyber_native_cell_world.cpp
godot/native_extension/cyber_native_cell_world.hpp
native/include/cybersand/material_rules.hpp
native/include/cybersand/world.hpp
native/src/material_rules.cpp
native/src/world.cpp
```

This research adds no changes to those production inputs or to the retained runtime manifests. A freshly compiled native test executable is not a replacement GDExtension library. Existing Windows/Linux Godot artifacts cannot be declared source-matched simply because the native suite passes. Rebuild and attest affected artifacts in the normal release workflow; do not rewrite historical hashes or relax the checker to obtain a green result. The focused [provenance and API follow-up](issue-3-provenance-and-api-audit.md) records actionable boundaries.

## Commands and binary identities

From the repository root, run these as separate commands:

```text
python -m unittest discover -s tools/research/issue_preparation -p "test_*.py" -v
```

```text
python tools/research/issue_preparation/precompute.py --out validation/local/issue-preparation-reproduction
```

```text
g++-13 -std=c++20 -O2 -Wall -Wextra -Werror -pedantic tools/research/issue_preparation/projection_oracle.cpp -o validation/local/projection_oracle
```

Create the output directory before the optional C++ build. Run the resulting executable and compare its CSV with the generated `projection.csv`. On Windows use an available C++20 compiler and its corresponding executable name; that platform was not exercised here.

The hosted collector separately ran `make c-header-check`, `make build/tests` and `./build/tests`, plus the documentation, M11, repository, validation-contract and two retrieval checks listed in `checks.json`. It retained timeouts and every observed exit status. No measured engine speedup is inferred from command duration.

| Hosted binary | SHA-256 |
|---|---|
| Existing native test suite | `7ba1ab679c2da53bda83323e956222b59773e4cdc0b855bb9e1b46e929219fdf` |
| Independent projection oracle | `3c9e863e12f92bf900e31268f251d142557a389c894074781f308a9db8f44bbd` |

Raw logs and the small oracle executable were retained separately in Actions artifact `10296760645`, `research-preparation-34688377205-1`, SHA-256 `8e405900450054e9ddeaf2a4d70dbcd24ee70f740fd72484bc9d96ed5b2495bf`. That artifact expires on 26 September 2026; the curated results, traces, checksums and failed-gate evidence remain in Git.

## Harness correction and remaining gaps

The first local unit-test attempt expected a 1/255 input to become one mass7 unit. That expectation was wrong: `127/255 < 1/2`, so exact nearest rounding gives zero. The test expectation was corrected, not the quantizer. The failure was recorded before the [registration addendum](registration-addendum.md); the failed local log is retained outside committed source. Subsequent local checks and the hosted 23-test suite pass. This was a harness-expectation error, not an engine defect or a discarded candidate-negative result.

The initial environment could not use direct Git transport or inspect the owner's Windows workspace. The branch-scoped hosted run resolved the full-checkout/native-test limitation; it did **not** resolve access to the active Windows DLL, Godot application, browser, GPU or human Water preference.

Windows execution, Godot integration, Web browser execution, target-GPU timings, actual shader screenshots, human trials and ASan/UBSan/TSan were not run in this task. The descriptive reports were added after the tested research-source checkpoint; their links and correspondence were reviewed separately. New PR jobs, if any, have their own source identities and must not be silently substituted for this run. No issue closure, H-ready declaration, G-M/G-B admission or G-final approval follows from evidence publication.
