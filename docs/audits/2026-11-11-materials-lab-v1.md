---
title: Materials Lab v1 source and platform qualification
status: Current
document-kind: evidence
scope: Local Linux native, compiler, Godot UI and graphical qualification; Windows execution and human acceptance remain unperformed; no production candidate activation
canonical-for: []
last-reviewed: 2026-11-11
related-documents: [../operations/materials-lab-authoring.md, ../operations/material-catalogue-shadow.md, ../operations/material-liveness-investigation.md, ../MATERIAL_LAB.md]
---

# Materials Lab v1 qualification — 11 November 2026

The implemented desktop slice supports native inspection, structured source
candidates, reusable presets, compiled reaction diagnostics and controlled
existing-material simulations. The [runbook](../operations/materials-lab-authoring.md)
owns launch instructions and the compact manual evaluation checklist.
This record distinguishes executed Linux evidence from pending Windows and
human acceptance; it does not close all of #352–356.
Published as [Draft PR #562](https://github.com/techrote/cybersand/pull/562).
No Ready promotion, merge or auto-merge is authorized by this checkpoint.

The [review continuation](#review-continuation-and-compiled-candidate-worlds)
records the later fixes and actual candidate World execution. Sections before
that continuation retain the initial published checkpoint `1415b094` and its
then-current scope; the subsequent source/test identities are listed separately.

## Source custody and publication

| Identity | Exact value |
|---|---|
| Accepted main baseline | `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` |
| Baseline tree | `5654b867620fa97ad7ef873533e65ca7a3ae314c` |
| Implementation branch | `codex/materials-lab-v1-20261111` |
| Tested final local product/test commit | `dc2d74625c9e73781a64e93514297edbefc445a9` |
| Published equivalent product/test commit | `a440f01ea56c07ddfc583263f9ffabc1298c35ca` |
| Shared final product/test tree | `fbea9eced2d26f5d1f1474ff9516b005d834bbed` |

Terminal Git push lacked authentication. The authorized GitHub connector
published the same four successive blob/tree contents with different commit
metadata. The [publication map](materials-lab-v1/publication-tree-equivalence.json)
records every local/public commit pair and its identical tree, including native
and backend, UI, CI qualification and final product/test corrections.
Receipts retain their actual execution-time local revisions; their source-file
hashes bind the tested inputs. They have not been relabelled as remote runs.

## Connected implementation and boundaries

- The launcher and Shared Workbench mount the real Materials Lab scene. Native
  descriptors, capabilities, interaction profiles and copied policy receipts
  supply the inspector; shadow and GDScript fallback data stay labelled.
- The existing canonical compiler consumes edited candidate definitions.
  Density, RGBA, hard/granular capability and visual-state projection are
  supported. Descriptor viscosity is admitted only for YieldingLiquid, Cement
  and MoltenGlass templates. Kernel, state defaults and movement contracts remain
  template-bound; unsupported changes fail with a field path and explanation.
- Sparse reaction editing preserves 56 slots, priority and positional products.
  Version-1 endpoint effects admit only `replace_with_defaults`. Threshold T
  retains `(T + 1) / 256`; zero is not disabled. `keep_existing`, state-setting,
  arbitrary new slots and rules with no admitted active initiator are rejected.
- Draft, validated candidate and compiled/tested are distinct states. No
  candidate becomes runtime-active. Production retains 132 slots and invalid
  reserved ID 10; synthetic non-hard powder 132 is isolated compiler input.
- The C++ probe consumes generated descriptors/capabilities/appearance and the
  actual native sparse resolver. It enumerates 256 rolls in both orientations
  of each rule. It reports product descriptor initial bytes; it does not execute
  World endpoint initialization, candidate movement, sleep or quantity ledgers.
- Native experiments reuse `MicroScenarioHost` and an independent native World
  with existing material identities. Counts, stored state, quantities, hashes
  and acknowledged policy are authoritative. Per-cell scheduler eligibility is
  unavailable; images alone are not transformation evidence.

Independent review corrected reverse ordered-rule handling, inactive initiator
admission, compile-time source drift, Brine's inertial viscosity explanation,
stale visible success reports, experiment source custody and bundle diagnostic
forwarding. Experiment source/runtime file fingerprints are retained around
construction and checked before saving, capture or reference comparison. These
are observed file fingerprints, not independent mapped-module attestation.

This division provides working authoring and native feedback without migrating
production consumers. No physics defaults, saved-world identities, compatibility
lock, retained binaries or runtime provenance were changed. Ownership of current
#560/#553/#561/#544 work was checked before shared-source integration. #395 owns
the separate MoltenGlass H1 repair; mutual heating and generic yielding rest stay
unchanged here.

## Executed local qualification

Host: Linux; GCC 14.2 and GNU ld 2.44. The local GDExtension build explicitly used
the existing `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` development override. It is not
a pinned-compiler or bit-identical release build. Godot
`4.7.stable.official.5b4e0cb0f`, godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1 pins were retained.
The executed Linux native library SHA-256 was
`5c0b84f8719c7c5165849d8f1993a0375db58c8a1fbdcfff4ffc730b6e458269`.

| Executed check | Result |
|---|---|
| Core `build/tests` | 192 passed |
| Core `build/tests_sanitized`, ASan/UBSan | 192 passed, leak detection disabled |
| `python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py' -v` | 147 passed, including 29 Lab backend tests |
| `compiler.py --check`, `compatibility.py --check`, `check_native_parity.py` | Passed; generated parity and immutable guards retained |
| `test_material_lab_catalogue.gd` | 1,348 assertions passed |
| `test_material_lab_experiment.gd` | 111 assertions passed |
| `test_material_lab_ui.gd` | 100 assertions passed; real Python/C++ and native World paths |
| `capture_material_lab.gd`, real X11 display | 19 assertions passed; six viewport PNGs |
| Existing feature launcher / Materials Lab regressions | 43 / 233 assertions passed |
| Existing Workbench lifecycle / canvas / input regressions | 15 / 164 / 24 assertions passed |
| CI sharding / Windows runner / Linux reducer / Windows reducer tests | 88 / 22 / 12 / 46 tests; one existing Windows-only skip |
| CI job-plan / provider-policy unit tests | 11 / 6 passed |
| `check_ci_provider_policy.py`, changed runner Python compilation, `git diff --check` | Passed |

Core and compiler logs remain local under `build/materials-lab/`; durable source
candidate and graphical receipts are linked below. An initial LeakSanitizer
attempt failed under tracing and its failure log was retained locally. Successful
ASan/UBSan runs explicitly used `ASAN_OPTIONS=detect_leaks=0`; this is not leak
qualification. The CI skip is the existing actual-Windows thread snapshot test,
which cannot run on Linux. These focused checks are not an all-platform CI pass.

Representative reproduction commands after building the matching extension:

```sh
make build/tests build/tests_sanitized
./build/tests
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/tests_sanitized
python3 tools/material_catalogue/compiler.py --check
python3 tools/material_catalogue/compatibility.py --check
python3 tools/material_catalogue/check_native_parity.py --output build/materials-lab/native-parity.json
godot --headless --path godot --script res://tests/test_material_lab_ui.gd
godot --path godot --script res://tests/capture_material_lab.gd -- --output=/absolute/external/capture --source=TESTED_COMMIT
```

## Reusable examples and durable evidence

The [native candidate receipts](materials-lab-v1/native-candidate-receipts.json)
retain compiler, sanitizer options, source/generated/executable hashes and native
readback: powder 132 passed 114,809 probe assertions; zero-threshold quench passed
114,807. Powder density 1337, RGBA 17/91/203/255, hard=false and granular=true
round-trip with digest
`c2e7859cf568cd9d138c6444a9f26242cc1538be9b283977e6a24dc59ba5c24c`.
Quench threshold zero selects one roll per orientation and yields 510 changed
resolver outcomes against production. Both receipts state `runtime_active=false`.

The [graphical receipt](materials-lab-v1/graphical-capture-receipt.json) binds
the actual loaded UI scripts, engine/display, candidate receipts and native
experiment. Salt 23 plus Water 3 at seed 2 and 120 ticks converts a 384-cell
Salt dose and some Water into 768 Brine cells, with Water remaining in the bay;
a clean reconstruction matches native readback.
The isolated test's CellularYield policy is acknowledged by its native owner.
Six real viewport captures are retained:
[Water](../images/materials-lab-v1/01-inspector-water.png),
[Slush](../images/materials-lab-v1/02-inspector-slush.png),
[compiled powder](../images/materials-lab-v1/03-candidate-compiled-powder.png),
[threshold-zero reaction](../images/materials-lab-v1/04-candidate-reaction-threshold-zero.png),
[native result](../images/materials-lab-v1/05-native-salt-water-result.png) and
[applied policy](../images/materials-lab-v1/06-inspector-applied-cy-policy.png).

## Windows and remaining publication gates

**Windows execution: NOT_RUN.** Terminal `gh` was unauthenticated; there was no
originating connected-browser context, and the cloud GitHub page showed Sign in
without a Run workflow action. The GitHub connector exposed no dispatch method.
No sign-in or Ready transition was requested. Linux rendering, Python tests of
Windows custody logic and compilation support do not establish Windows execution.

The existing workflow now retains complete Git history for both regression
hosts. Windows uses its existing Python 3.12 setup and installed MinGW
`C:\mingw64\bin\g++.exe` for candidate compilation. Both hosts retain compiler
and catalogue source inputs; Linux also checks terminal source drift and its
reducer verifies the inventory. Provider, schedules and test thresholds are intact.
An eventual Windows headless pass still requires separate graphical/human review.

The documentation checker initially lacked five companion-repository files.
They were materialized outside this repository at the exact pinned companion
commit `6a58311982941b75f46e22109a0829e5acb83c7e`; no checker rule was weakened.
Final local documentation qualification:

| Command | Result |
|---|---|
| `python3 tools/ci/check_docs.py` | Passed, no errors/warnings |
| `python3 tools/ci/check_m11_consistency.py` | Passed; 28 retained historical source hashes checked |
| `python3 tools/docs/retrieval_eval.py --output build/materials-lab/retrieval-final.json` | Frozen32: 31/32 canonical hits, MRR 0.7318; identical to accepted-main baseline |
| Same evaluator with `--queries docs/reference/retrieval-challenges.json` | 163/164 hits; unchanged hit coverage, MRR 0.8785 baseline → 0.8778 candidate |
| Same evaluator with `--queries docs/reference/retrieval-questions-materials-lab.json` | All six new questions rank first |
| `python3 tools/ci/check_repository.py` | **Blocked:** retained Windows and Linux runtime provenance requires rebuilding for `godot/native_extension/cyber_demo_bridge.hpp` |

The frozen/challenge question bytes are identical to main, and their existing
misses were preserved rather than changing thresholds or expected sources.
The small challenge ranking change is reported explicitly; retrieval hit counts
are not proof of answer correctness. The repository provenance failure is an
integration gate: the local source-built library was tested separately, and
retained production binaries/provenance were restored and left unchanged.
Publishing source-matched supported-platform runtimes remains required before
integration. Final published head and hosted check state belong to the
[Draft PR ledger](https://github.com/techrote/cybersand/pull/562).

## Next three engineering steps

1. Execute the existing hosted workflow on the Draft branch, retain original
   Windows receipts, then perform the runbook's compact graphical/human review.
2. Qualify a separate #353-B authoritative candidate consumer with explicit
   identity, persistence, quantity and deterministic one/four-worker comparisons.
3. Extend #355 only after specifying endpoint state/quantity contracts; add
   owner-authoritative scheduling diagnostics while leaving #395's H1 repair
   with its existing owner.

## Review continuation and compiled candidate Worlds

This section records the owner's subsequent **review, fix/improve and continue**
assignment. The earlier sections retain the initial checkpoint's results and
limitations. The new bounded World backend supersedes the initial lack of
candidate movement/quantity execution; production activation remains absent.

| Identity | Review continuation |
|---|---|
| Accepted main, rechecked | `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` |
| Previous published Lab head | `1415b09450b941394c721aaf3a1da7a2cd90474d` |
| Published implementation increment | `87c7893fc5e722a71123a1a70768c6e5218a869f` |
| Published final product/test commit | `6df43c999e5dcf64651f156316afa5f2cd5aab24` |
| Equivalent tested local commit | `35cdcd9fa86eec3fa1f2ab132e28c3e5d90a3d1c` |
| Identical product/test tree | `fe288e4ce40db2d8abdd4829915982c4921492b9` |
| Native World input digest, 90 files | `8b7ccabdd586bab8ea767bd3bf8f1e9c9af9c66c0b7a708362b3ab01b8985344` |

The [publication map](materials-lab-v1/publication-tree-equivalence.json) adds
both exact local/public tree pairs. The prior development GDExtension remains
source-matched: this continuation changes no bridge or production native file.
Its Linux SHA256 remains
`5c0b84f8719c7c5165849d8f1993a0375db58c8a1fbdcfff4ffc730b6e458269`.
The retained production binary/provenance is not relabelled.

### Reproduced defects and fixes

- Compilation custody previously began after validation/toolchain selection.
  A temporary-tree regression changed protected Water density in that gap and
  reproduced a false compiled/tested result. Custody now begins before validation,
  covers all protected sources, and closes with source and compatibility checks.
- Reaction comparison formerly visited only candidate pairs. Replacing Lava/Water
  with Sand/Water missed removed-pair outcomes. The unique directed union now
  reports **1,024** changed queries and includes old/new deterministic examples.
  Opposite ordered pairs and self-pairs are counted once.
- Edited products retained legacy accounting descriptions. Generated candidate
  descriptions now identify their actual products and unqualified context.
- CLI response aliases could overwrite an imported/exported preset or a bundle.
  Preflight rejects those aliases, including symlink aliases, before work begins.
- The service could join an unbounded Python process when closing. Nonblocking
  process polling, cancellation markers, process-tree cleanup, output/response
  limits and a total desktop deadline now produce explicit unsuccessful results.
- Imported native cases left seed/duration/workers/policy controls stale; the
  restored owner and controls now agree. Successful authoring jobs also preserve
  the selected sparse slot. Browsing a different rule retires its old displayed result.
- Reference replay blocked the UI for the whole window. It now advances one
  tick per frame, reports progress and supports Pause. A cheap native tick accessor
  avoids a full stored-cell scan on every source-run frame.
- Completed candidate World jobs now retire stale candidate/recipe results and
  release the controls. Actual graphical review additionally corrected the tab
  label, browser selection and read-only report contrast.

### Actual candidate World implementation

`world_candidate.py` stages untouched native source for the reference and the
same source with two compiler-backed table adapters for the candidate. No
repository native source is patched. The probe calls actual `demo::construct`,
`World::tick`, stored-cell accessors, quantity ledger and physical-state codec.
It records source/staged/generated/executable hashes and rejects source/stage drift.

The mounted **Candidate test** view submits structured placement, partner, seed,
1–600 ticks and 1/4 workers through the existing asynchronous authoring service.
It displays initial/final reference and candidate grids, stored cells/state/
temperature, counts, hashes, quantities and qualification checks. Its previews
use compiled RGBA and native stored-cell readback, not the application shader.

Each compiled backend performs fresh repeat, one/four-worker and same-build
save/restore continuation checks with complete quantity accounting. An unchanged
candidate must equal the untouched reference. Persistence uses the canonical
physical hash plus exact content/cells/registers/temperature/ticks/ledger; the
historical hash remains visible. The one-tick static case demonstrates native
restore's inactive quiet-counter normalization, which is not a physics or
persistence change. Fresh repeats and worker comparisons retain every hash.

The probe reuses Lab bay geometry, not exact mounted-host configuration. Raw
native default transport, finite capacities, interest and actual worker participation
are explicit in its receipt. No mounted-host hash parity, per-cell deadline
inspection, cross-build persistence or production activation is inferred.

Existing-ID density/RGBA, admitted viscosity and legacy sparse-pair edits execute.
Synthetic132, capability and visual-projection changes remain descriptor-only.
Their unsupported World application is rejected. The preset, generated definitions,
source-staged reference/candidate and receipt export to a fresh external directory;
executables and saved Worlds are omitted.

### Native observations and retained evidence

For Sand density500, RGBA17/91/203/255, seed2, 120 ticks:

| Observation | Untouched reference | Compiled candidate |
|---|---:|---:|
| Sand cells below reservoir surface | 369 | 0 |
| Native Water quantity | 1,644,240 | 1,644,240 |
| Observed workers in configured1 / configured4 runs | 1 / 4 | 1 / 4 |
| Repeat, worker, persistence and quantity checks | All passed | All passed |
| Physical-state hash | `766e92a1f6e27fbe` | `37cbe64cb45b7217` |

The separate Salt/Water product edit produces actual Stone and pair/quantity
ledger events, with zero Brine in the candidate while the reference produces
Brine. Both are reusable versioned fixtures:
[low-density Sand](../../materials/catalogue/fixtures/lab-low-density-sand-world-v1.json)
(digest `42d1220b338a715290bcc6c1ac3b9b8bc577332568e476dba221812ae94e12c0`)
and [Salt-to-Stone](../../materials/catalogue/fixtures/lab-salt-stone-world-v1.json)
(digest `5b0fdec9292f7c522c6f09b54fb65e19b5734037d5233ee0a3b927d5eeeaaec8`).
Both strict imports match the definitions used by native acceptance.

Durable evidence:

- [Real desktop comparison PNG](../images/materials-lab-v1/07-candidate-world-density.png).
- [Graphical source/display manifest](materials-lab-v1/world-capture-manifest.json).
- [Displayed native World receipt](materials-lab-v1/world-ui-receipt.json).
- [ASan/UBSan World receipt](materials-lab-v1/world-sanitizer-receipt.json).
- [Changed-pair sanitizer receipt](materials-lab-v1/reaction-review-sanitizer-receipt.json).

### Executed continuation checks

Linux, pinned Godot4.7, GCC14.2 and the existing explicit development toolchain
qualification apply. No production native input changed; the earlier full192
native and192 sanitizer executions retain their original checkpoint, rather than
being claimed as new executions here.

| Command / scope | Result |
|---|---|
| `python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py' -v` | **168 passed**, 251.364s; includes40 Lab tests and10 World-backend tests |
| Focused `test_world_candidate.py` | **10 passed**, 168.370s; four real compiled acceptance cases plus admission/staging/custody adversaries |
| `test_material_lab_ui.gd` | **115 assertions passed**, actual mounted UI/Python/C++/Workbench |
| `test_material_lab_experiment.gd` | **131 assertions passed**, actual native owner/import/replay |
| `test_material_lab_service.gd` | **42 checks passed**, real process failure/cancellation/timeout/close |
| Displayed `test_material_lab_world.gd -- --capture-output=...` | **63 checks passed**, X11/Mesa llvmpipe, actual1680×1050 viewport; two real compile/test jobs including a stale-recipe race |
| `compile_world_test(candidate, sanitize=True)` | ASan+UBSan passed, 97.002s; reference and authored World both execute |
| Changed-partner `compile_test(candidate, sanitize=True)` | ASan+UBSan passed;1,024 changed native queries |
| Compiler `--check`, compatibility `--check`, independent native parity | Passed;27 protected sources; production cutover false |
| Documentation structure and retained M11 | Passed; no documentation errors/warnings;28 historical source hashes preserved |
| Frozen retrieval32 / Lab questions7 |31/32 canonical hits, MRR0.7318; Lab7/7 at rank1 |
| Challenge retrieval164 |163/164 hits, MRR0.8827; initial checkpoint163/164, MRR0.8778 |
| `check_repository.py` | Blocked only by the existing Windows/Linux runtime-provenance rebuild requirement for `cyber_demo_bridge.hpp` |

The new material-physics comparison initially displaced an apparatus A/B route
in lexical retrieval. A source-backed cross-link and scope explanation in the
canonical MicroScenario guide restores that route and distinguishes the two
workflows. Frozen/challenge queries and evaluator thresholds are unchanged.

Hosted [Documentation and provenance run42942631586](https://github.com/techrote/cybersand/actions/runs/42942631586)
passed on the final product/test commit `6df43c99`; the source-scope advisory also
passed. Native/GDExtension/shader workflows were skipped under the retained Draft
policy. Their execution is not inferred from this success. Final documentation-head
check results belong to the PR ledger.

ASan uses `detect_leaks=0:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1`; leak qualification is not claimed. Windows
compilation, cancellation cleanup and actual graphical execution remain **NOT_RUN**.
The desktop's five-minute job bound can reject a slower build before the backend's
individual compile limits expire; cancellation is explicit, not a partial pass.

Historical failed attempts are preserved in local logs: a Godot-array numeric
type assertion initially compared parsed float bytes against integer literals
(native values were exactly correct), an initial graphical pass exposed the
unlabelled tab, and one final Xorg attempt found an occupied display. The fixed
assertion checks integer bytes, the final UI label/selection are verified, and
a fresh display produced the successful final capture. No native physics, test
threshold, compatibility lock or CI scheduling rule was altered to obtain a pass.

Production runtime publication, actual Windows execution/human acceptance,
#353-B installation, new endpoint effects and #395's H1 gates remain separate.
The PR stays Draft; broad #352–356 remain open.
