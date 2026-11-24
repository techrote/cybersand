---
title: Current validation and retained M11 integrity
status: Current
document-kind: guide
scope: Separate current source/runtime qualification from immutable historical M11 evidence and actual platform acceptance
canonical-for: [current-validation-gates, m11-retention-policy]
last-reviewed: 2026-11-24
related-documents: [local-build-and-validation.md, github-development-and-release.md, testing-validation-and-replay.md, ../reference/validation-evidence.md]
---

# Current validation and retained M11 integrity

Run the gate that answers the question you actually have. A historical hash check
proves preservation; a current source/runtime check proves identity; execution
proves only the cases and platform actually exercised.

| Question | Check | It does not establish |
|---|---|---|
| Are current links, metadata and canonical routes coherent? | `python3 tools/ci/check_docs.py` | Source semantics, external URL reachability or correct answers |
| Do retained runtime/provenance inputs match this source? | `python3 tools/ci/check_repository.py` | Runtime execution or usable bytes when only LFS pointers are present |
| Are all required runtime payloads materialized and identified? | Add `--require-materialized` | Platform behavior or physical playfeel |
| Are original M11 evidence records intact? | `python3 tools/ci/check_m11_consistency.py` | Equality between current source and historical source |
| Which behavior actually ran? | Applicable native/Godot/browser/graphical harness | Other sources, platforms, fixtures or owner acceptance |
| Can an agent answer correctly from retrieval? | Saved contexts plus independent source-grounded review | Correctness inferred from ranking scores alone |

## Why did the old consistency check report hash mismatches?

Later source and runtime bytes legitimately differ from M11. An unresolved LFS
pointer also differs from a materialized library. Neither comparison alone proves
corruption of the historical evidence. **Rejected:** rewriting M11 hashes or
suppressing integrity errors to make current builds look accepted.

[check_m11_consistency.py](../../tools/ci/check_m11_consistency.py) verifies the
28 original [BUILD_ID](../BUILD_ID.md) source hashes against Git blobs at audited
commit `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`, and the retained records against
[their immutable manifest](../audits/m11-retention.json). Text comparison uses
canonical Git LF bytes. Missing historical objects fail the check: a shallow
checkout must obtain the required history before claiming historical integrity.
The original tag and hashes remain unchanged.

`--compare-working-tree` explicitly asks for the strict legacy comparison.
Expected current-versus-M11 differences can produce a nonzero result; report it
as diagnostic drift, separately from the historical-integrity and current-runtime
gates. The [original reconciliation](../audits/2026-09-08-validation-reconciliation.md)
preserves the failure and why those checks were separated.

## What validates current source and runtime identity?

[check_repository.py](../../tools/ci/check_repository.py) checks documentation,
approved pins, notices/bootstrap inputs, committed LFS identities and the native
Windows/Linux source-input manifests. Each
[Windows](../../godot/addons/cybersand_native/runtime-provenance.json) and
[Linux](../../godot/addons/cybersand_native/runtime-provenance.linux.json)
manifest binds library SHA-256/size to canonical input hashes and dated execution
provenance. The selected Rapier override has its own lock and provenance.

If a native or binding source input changes, an old binary can fail identity
before any test runs. That is an admission failure, not a newly observed physics
regression. Build and qualify the matching artifact under its guarded publication
contract; changing a JSON hash is not a substitute. A documentation-only change
that leaves the entire native/build input set unchanged does not itself require
new native binaries.

The default local check can validate an LFS pointer's committed identity while
reporting missing payloads. `--require-materialized` requires actual bytes for all
required runtimes and checks their hash/size. A source ZIP or clone containing
pointers is not a runnable evaluator. Other platforms are not qualified by the
Windows/Linux manifests or by a successful LFS operation.

## Which build and CI gates use each policy?

Native build scripts enforce the pinned dependency revision and applicable
compiler/source checks. Exact M11 output-byte reproduction is an explicit
`CYBERSAND_VERIFY_M11_OUTPUT=1` mode. The local toolchain-drift override does not
bypass an explicitly requested historical-output check; it also does not create
a reproducible-release attestation for the current build.

The accepted [GDExtension workflow](../../.github/workflows/gdextension.yml)
builds source-bound runtimes and executes planned Linux/Windows cases. Its Windows
helper can receive a candidate artifact, or separately validate a retained runtime.
Current workflow inputs define which path actually ran. Cross-compilation,
Windows headless execution, Linux graphical output, browser execution and physical
Windows/NVIDIA acceptance remain distinct. See the
[test-selection guide](testing-validation-and-replay.md#ci-execution-sharding).

Documentation CI also checks the retained historical record and retrieval
contracts. Some frozen retrieval fixtures reference the pinned companion workspace;
a standalone source checkout without those files must report that boundary,
not rewrite the frozen questions or invent missing evidence. Historical hash
reconciliation does not settle Web producer/consumer, template or browser gaps.

## Run and record the checks

From the source root, with Python and the required Git history/companion inputs:

```sh
python3 tools/ci/check_docs.py
python3 tools/ci/check_repository.py
python3 tools/ci/check_m11_consistency.py
python3 -m unittest discover -s tools/ci -p test_validation_contracts.py
python3 -m unittest discover -s tools/ci -p test_historical_retrieval.py
python3 -m unittest discover -s tools/ci -p test_current_retrieval_selection.py
python3 tools/docs/retrieval_eval.py --output build/retrieval-frozen.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output build/retrieval-challenges.json
git diff --check
```

Create the ignored output directory before commands that write there. Run actual
retrieval on the relevant additive suite and inspect saved contexts separately.
Record command, source/dirty state, artifacts, platform, elapsed outcome and
limitations. Preserve PASS, FAIL, BLOCKED, SKIP and NOT RUN distinctly; a skipped
Draft gate or an old-head result is never a current runtime pass.

## Recovery and older checkpoint records

The [#65 recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md),
[player playground checkpoint](../audits/2026-10-20-player-control-playground.md)
and previous source-pinned guide retain their exact old hashes, counts, failures
and platform scopes. They remain evidence for their recorded source. A later
source needs its own applicable qualification; original failures and release hashes
must survive documentation updates.

## Earlier checkpoint detail

<a id="65-recovery-era-retained-runtime-checkpoint--2026-09-22"></a>

The [source-pinned previous guide](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/current-and-historical-validation.md)
preserves older source identities, publication transcripts and original procedures.
They are dated evidence, not a fresh source lease or permission to act.
