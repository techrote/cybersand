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
