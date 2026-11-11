---
title: Materials Lab completion, runtime publication and platform qualification
status: Current
document-kind: audit
scope: Owner-requested continuation of Draft PR 562; additive Lab diagnostics, source-matched runtime publication and automated platform acceptance; human acceptance and production catalogue cutover are separate
canonical-for: [materials-lab-completion-evidence]
last-reviewed: 2026-11-11
related-documents: [2026-11-11-materials-lab-v1.md, ../operations/materials-lab-authoring.md, ../architecture/material-authoring-catalogue-plan.md, ../operations/local-build-and-validation.md]
---

# Materials Lab completion

The owner cannot run the candidate now and requested completion of the remaining
work. This continuation closes implementation and automated qualification work
without claiming human acceptance. Draft PR [#562](https://github.com/techrote/cybersand/pull/562)
remains unmerged; Ready promotion, auto-merge and production material installation
are not part of this assignment. MoltenGlass H1 remains excluded.

## Intake and retained evidence

Accepted main is `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. The intake branch is
`codex/materials-lab-v1-20261111` at
`f684dcffb18614dd9557e85d3c811abcb28cf325`. The
[preceding audit](2026-11-11-materials-lab-v1.md) retains its actual native,
sanitizer, graphical and hosted results, including the completed 202-test suite.
Those results remain qualified to their recorded source, not automatically to
the new source below.

The earlier manually dispatched
[Godot run 43100826964](https://github.com/techrote/cybersand/actions/runs/43100826964)
tested `55c25abf93328cc4d47f1a50941ee418c04d949a`. Both platform builds passed,
but the run failed. Windows shard 4 could not compile the Lab World because its
staged native paths were absent. Observed Linux shard failures followed successful
case execution and detected missing Lab entries in the tracked portable class
cache. The subsequent path-inventory/compiler-argument and portable-cache fixes
are already ancestors of the intake. Their presence does not relabel the failed
run as passing; fresh actual platform execution is required.

## Source and platform boundaries

The Lab's native observer is a cold-path, copied-value API on its exclusive test
owner. It must not change World updates, kernels, masks, scheduling, material IDs,
saved state or shared Workbench ownership. Resolver inspection at a supplied
roll must distinguish available eligibility facts from unobserved scheduling and
competing mechanisms.

Runtime publication follows the existing branch-scoped publisher contract:
an explicit source-bound request, exact branch lease, newly built Linux and
Windows artifacts, actual target-platform test receipts, and a guarded four-path
LFS/provenance append. Historical provenance cannot be relabelled or rewritten as
new execution. Candidate packaging must retain the immutable source history
needed by authoring validation, without copying machine configuration or secrets.

The separately owned #353-B generated-capability consumer is reviewed in its own
worktree and [Draft #563](https://github.com/techrote/cybersand/pull/563), stacked
on #562. It is not installed in #562 by this publication. Existing
display-name consumer work in #384 retains its ownership.

## Implemented completion work

The contact inspector copies native stored/visible cells, A/B state, raw thermal
storage, body masks, source-core scheduling windows and compiled resolver facts
from its exclusive paused MicroScenario owner. Source/target selection and role
swapping are mounted in the existing Native test tab. A supplied probability roll
is kept separate from actual native scheduling; per-cell sleeping, wake deadlines,
epochs and competing mechanisms remain explicitly unobserved.

The Windows authoring process owner creates each child suspended, assigns a
private kill-on-close Job Object, then resumes its initial thread. This closes
the orphan-descendant gap after a driver exits, including descendants with
redirected pipes. POSIX retains process-group ownership and now also retires
redirected descendants after successful driver exit. Four actual portable
fixtures cover timeout, cancellation, inherited pipes and redirected descendants;
they execute on both platforms without replacing native Windows acceptance with
mocked taskkill calls.

The runtime publisher requires the complete discovered catalogue suite, all
seven selected actual native/Godot Lab/Workbench cases, Linux and Windows
graphical UI/World receipts, and a freshly exercised self-contained Windows
package. It retains failure artifacts, checks source/branch custody and publishes
only the two runtime binaries and two provenance manifests. A final narrowly
scoped job requests the unchanged manual documentation, Native, GDExtension and
palette workflows on the exact publication child. Accepted dispatch is recorded
separately from downstream completion. No general Draft gate is disabled.

The package reconstructs clean Git history from a self-contained bundle and
includes Godot, Python, Git for Windows, the tested C++ compiler and their notices.
It copies no originating Git configuration, remotes, hooks or untracked files.
Actual package execution takes place in a disposable path containing spaces with
only the included authoring prerequisites on PATH. The file manifest binds the
source, runtime, dependencies and qualification artifacts.

## Qualification ledger

Fresh local native-core qualification used GCC 14.2 on Linux, the unchanged
production native source inventory, and the existing Makefile targets:

| Command | Result | Elapsed |
|---|---|---|
| `make -j2 build/tests build/tests_sanitized` | Both existing build targets current | Build log retained |
| `./build/tests` | 192 passed | 329.597 s |
| `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/tests_sanitized` | 192 passed; no ASan/UBSan error | 345.778 s |
| `PYTHONPATH=tools/material_catalogue python3 -m unittest -v test_process_owner test_lab.LabTests.test_timeout_and_cancel_kill_real_child_descendants test_lab.LabTests.test_process_output_limit_is_enforced_for_a_real_child` | Six actual process-lifetime/output controls passed | 7.220 s |
| `python3 tools/ci/check_docs.py` | Passed, no errors/warnings | Local |
| `python3 tools/ci/check_m11_consistency.py` | 18 historical records / 28 source hashes pass | Historical integrity only |
| Materials Lab retrieval fixture | 10/10 canonical routes rank 1 | Lexical routing, not runtime acceptance |

The native inventory was hashed before and after both core executions and
remained unchanged. Leak detection was disabled for this local sanitizer run;
there is no TSAN or Windows claim in these results. The rebuilt local inspection
extension uses a declared development-toolchain override; the hosted publisher
must independently use the pinned release build path.

The final frozen native contact test passes **116 assertions**. Actual Linux X11
captures pass **123 contact assertions** and **196 full mounted UI assertions** at
1680×1050 with Godot 4.7 and Mesa llvmpipe. The actual service and compiled World
UI checks also pass (87 and 201 respectively). Their local development extension
SHA-256 is `22f39a70915f4eb00636b0d85a6cd640f22dd70884965b4e8acbb026d5d0ba1c`;
the pre-existing retained runtime was restored after execution.

[Contact screenshot](materials-lab-completion-20261111/09-native-contact-inspector.png),
[contact readback](materials-lab-completion-20261111/contact-readback.json),
[contact capture manifest](materials-lab-completion-20261111/contact-capture-manifest.json),
[retained-Salt World screenshot](materials-lab-completion-20261111/08-kept-salt-world.png),
[native World receipt](materials-lab-completion-20261111/effects-ui-world-receipt.json),
and [its source/display manifest](materials-lab-completion-20261111/effects-ui-capture-manifest.json)
retain actual graphics alongside native facts. The
[core qualification record](materials-lab-completion-20261111/completion-core-qualification.json)
binds both full core runs to their source inventory and log hashes.

The first new full catalogue run executed206 tests, with205 passing and one
source-custody refusal: `material_lab_experiment.gd` changed during the native
pair-product test while the inert-source diagnostic fix was applied. The
[original failed log](materials-lab-completion-20261111/completion-catalogue-attempt1-suite.log)
and [attempt record](materials-lab-completion-20261111/completion-catalogue-attempt1-qualification.json)
remain preserved. A frozen-source rerun follows; this failed attempt is not
relabeled as passing.

The publisher's focused guard suites pass **7 + 5 + 30** tests, including
complete native-suite admission, graphical receipt custody, clean package
history and branch/dispatch race controls. Pinned actionlint1.7.12 and the
54-workflow scheduling/provider checks pass. Automated mocks in these guard
suites qualify refusal logic only; they do not replace target-platform execution.

Additional platform qualification is in progress. Resulting source,
commands, receipts, artifact identities, failed attempts and remaining limits
will be recorded here and in the PR conversation before handover. Human
acceptance remains unperformed.
