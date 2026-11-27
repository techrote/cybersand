---
title: SWARM-006 successor independent platform and publication source review
status: Current
document-kind: audit
scope: Dated independent review of successor build, package custody and qualification gates; hosted execution and physical owner acceptance remain separate
canonical-for: []
last-reviewed: 2026-11-21
related-documents: [../operations/swarm006-integration-finisher.md, swarm006-finisher-science-review.md, swarm006-finisher-workbench-review.md]
---

# SWARM-006 successor platform and publication review

An independent platform reviewer inspected the integration successor on
`integration/gentek-swarm-006-finisher-20261121`. The reviewer did not author its
native implementation, Workbench changes, workflow, packaging, or qualification
tools. This is a **source and focused evidence-gate review**, not a claim that a
Windows job, extracted evaluator, physical NVIDIA installation, or owner World
has already passed.

The review started from local integration commit
`5722f254144fb8bf84a94fa2881e8860c9512316` plus the explicit uncommitted successor
changes. The native definition supplied for the source freeze was
`72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0`.
Exact published commit, Actions run, executed binary hashes and final independent
artifact review belong in the successor PR's qualification ledger. The
[integration runbook](../operations/swarm006-integration-finisher.md) retains
Draft/HOLD and the separate accepted-main reconciliation gate.

## Reviewed custody and execution path

The new [qualification workflow](../../.github/workflows/swarm006-finisher-qualification.yml)
uses standard GitHub-hosted Ubuntu and Windows runners. Its push trigger is
restricted to the successor branch and a dedicated request-file change. It does
not merge, promote Ready, mutate main, publish ordinary runtime defaults, or edit
another mission's workflows. Compilation and Windows consumption use the same
Actions run; native source inputs, commit/tree, and executable hashes are verified
again in the consumer. A copied hash manifest alone is not the build evidence.

The reviewed build path pins Godot 4.7, godot-cpp, SCons, LLVM-MinGW and the retained
Rapier runtime. The GNU/Linux and Windows native adapters are compiled from the
checked-out integration source. The native recovery CLI and lifecycle fixture are
separately compiled and included in the Windows custody receipt. Native test
failure, command failure, wrong source, and dependency hash mismatch stop the
relevant qualification path. The sanitizer job explicitly enables ASan, UBSan and
leak detection; the local ptrace limitation cannot stand in for that hosted gate.
The Windows consumer also executes the existing V3 and V4 transport and malformed
request suites against its actual Windows CLI before packaging. Each native test
command has an explicit failing-exit guard; V4 carries the exact target source.
Their outputs enter the Windows evidence artifact.

The existing [package constructor](../../tools/package_explore001_candidate.py)
reads the committed Git tree, substitutes the separately attested candidate DLL,
materializes required pinned runtime bytes, and records the original retained
runtime provenance as a reference. The [SWARM-006 packager](../../tools/swarm006/package_owner.py)
adds the attested CLI and its runtime manifest, clears inherited CLI override
variables in the owner launcher, and recalculates the complete package inventory.
Its successor README now comes from the committed integration guide. Editor
imports, an untracked inspector helper, or working-tree documentation cannot enter
the archived source silently.

The [seal and validation code](../../tools/swarm006/seal_owner.py) binds the exact
source, archive, separate sidecar, generated launcher, manifest and every packaged
file. Unsafe paths, missing or extra files, duplicate names, changed bytes,
unbounded package size, and inconsistent native manifests are refused. A new
archive cannot overwrite a previous sealed evaluator.

The owner launcher is exercised through seven actual Windows cases, including
direct and nested archives, stale destination, corrupt archive, incorrect or
missing sidecar, and the real PowerShell-to-CMD-to-Godot graphical dispatch. That
dispatch observes the owned process tree, exact command, visible responsive
Workbench, startup marker, nonblank original capture and post-boot executable
identity. It is separate from actual authoring qualification.

The source and freshly extracted package each execute
[qualify_workbench.py](../../tools/swarm006/qualify_workbench.py). The package path
uses its own project, scripts, engine, native adapter and generator. The runner
requires actual Windows graphics, completed assertions, native material planes,
distinct author/reopen processes, retained raw responses and original PNGs.
Negative proposals remain negative previews; they do not borrow Apply or Save
qualification from positive cases. Final inspector images and source/round
receipts are mandatory. Independent scientific review additionally exposed a
report-versus-raw-native metadata gap. The corrected gate binds native status,
diagnostics, work, material count, complete round coverage and derived witness
fields. A rehashed contradictory native record now fails semantically; the
scientific reviewer also checked the retained actual positive and negative
records. Checking that JSON files merely exist does not satisfy this gate.

## Findings and bounded repairs

The reviewers challenged the new
[ordinary Workbench preservation runner](../../tools/swarm006/qualify_preserved_workbench.py)
before source freeze. Three concrete acceptance gaps were repaired by its author:

| Finding | Original behavior | Reviewed correction |
| --- | --- | --- |
| Empty Water section inventory | A report with `real_workbench=true` and no sections could satisfy `all(empty)`. | Require the exact twelve section names and literal `true` for each, with a true real-Workbench flag. Empty, missing, false and integer-valued sections are rejected. |
| Wrong author/reopen phase or fixture scope | Paint author output could be admitted as reopen; Flatten output with the wrong phase, side or worker count was not distinguished. | Bind Paint's reopen selector, Flatten's author/reopen phase, 512 side, one worker and 524,288 bytes; bind Art's one worker and the native architecture phase. |
| Incomplete execution-source identity | Script/native suffixes omitted project settings, scenes and other executed assets; the end check omitted the engine. | Hash the full tracked Godot execution input set, reject tracked edits and unexpected untracked inputs, and recheck the whole inventory and engine at the end. Runtime binary directories remain separately hashed; generated script UID sidecars are the narrow import exception. |

The platform reviewer reproduced the phase/scale acceptance gap and then reran the
same malformed cases after the correction: both were rejected. The corrected
tracked inventory includes `godot/project.godot` and `godot/main.tscn`, and excludes
runtime binary directories from duplicate source accounting. The five focused
preservation-gate tests pass. No production subsystem, native authority, resource
ceiling or owner acceptance threshold was changed to resolve these findings.

## Independent focused checks

| Check executed by this reviewer | Result and scope |
| --- | --- |
| `python3 tools/swarm006/test_qualify_workbench.py` | 21 tests passed after the inspector and raw-native metadata binding repairs; the platform reviewer inspected the delta and reran the suite. |
| `python3 tools/swarm006/test_seal_owner.py` | Four package/custody tests passed. |
| `python3 tools/swarm006/test_owner_dispatch.py` | Fourteen launcher-observation admission tests passed. These are not an actual Windows launch. |
| `python3 tools/swarm006/test_qualify_preserved_workbench.py` | Five corrected preservation-gate tests passed. |
| Pinned actionlint 1.7.12 on the new workflow | Passed with shellcheck and pyflakes disabled, matching repository syntax-check scope. |

Reviewed successor file SHA-256 values at the source-review checkpoint:

| File | SHA-256 |
| --- | --- |
| `swarm006-finisher-qualification.yml` | `e96f11e59bb3a77b85b1b7efe13e557c7a5d4f405c8f7e58d60bd52370f44d92` |
| `qualify_preserved_workbench.py` | `4470b3db5830835e1281f71bf64d0c892f9f2fff330d381db4677385fec3e475` |
| `test_qualify_preserved_workbench.py` | `e3339bae25d7e66ba2cd7aef2f9f22ed677f889a7aa17bb9f5d89c58dbe290e3` |
| `package_owner.py` | `b73d1a6e52c7541b909860f033692e1f401d5f144146629da24d83e0f1d7cc6f` |
| `qualify_workbench.py` | `52e69a858ab9857236dbec93acf0023b78f67f0513c7138a985c32e63df178e8` |
| `test_qualify_workbench.py` | `595daecad702f75d60127930c4cf53edf9d65da668c33ddfa6863106eb12ec03` |

## Disposition and remaining evidence

No platform-source blocker remains in the reviewed build, package and corrected
preservation changes. This disposition does not approve unobserved workflow
results. The final ledger must identify the exact source and tree, build/consumer
run, Linux and leak-check outcomes, source and pristine Windows results, seven
launcher outcomes, package seal, independently verified archive inventory, and
original captures. An artifact retained after failure is explicitly unqualified.
A Windows package artifact alone cannot establish success of separate Linux or
sanitizer jobs.

The separate source-built evaluator does not qualify the old retained production
GDExtension. Its provenance requires renewal for inherited donor header changes;
this mission intentionally leaves those ordinary binaries and manifests alone.
The generic Draft provenance step is skipped, not passed. The candidate's
same-source build and execution receipts are its explicit qualification route.

Hosted Windows ANGLE/software rendering and synthetic Worlds do not establish
physical NVIDIA behavior or repair of missing private owner input. The owner
instructions use explicit `-Archive`, which works for the new finisher-named
Actions wrapper; the older launcher's optional automatic filename discovery is
not the documented route for this successor. No UI expansion is required.

After accepted SWARM-004/005 integration becomes available, source-sensitive
reconciliation must renew affected evidence. Until then the successor's actual
foundation and pending donor-to-main mapping remain explicit. Draft/HOLD, no
merge, no Ready promotion, and subsequent owner acceptance are preserved.
