---
title: ObjectShard M4 completion recovery ledger
status: Current
document-kind: audit
scope: Incremental source reconciliation, original evidence recovery, bounded corrective engineering and owner evaluator qualification
canonical-for: []
last-reviewed: 2026-11-25
related-documents: [2026-11-24-objectshard-m4-source-recovery.md, 2026-11-24-objectshard-m4-completion-negative-results.md, 2026-11-24-objectshard-m4-render-decision.md, ../research/objectshard-m4-workbench.md, ../operations/objectshard-workbench-playtest.md]
---

# ObjectShard M4 completion recovery ledger

**Recovery in progress; qualification incomplete; Draft/HOLD.** This ledger
records OBJECTSHARD-M4-COMPLETION-RECOVERY-001. Physical Windows 11/NVIDIA
performance acceptance remains HOLD. It grants no merge, Ready, auto-merge,
production-default activation or unqualified runtime-publication authority.

## Intake source and recovered environment

Live GitHub inspection on 25 November 2026 confirmed PR #754 remains open and
Draft on `integration/objectshard-m4-mainline-20261122`, with source
`f5b7ac7e651356c9f6d5657dfb0cb9d60111be81` and tree
`fcbb55a7c80a9d1a887e4e0336491e07c3ae01db`. Accepted main remains
`00cdb02f103265b6dc5224c68283e9a0c8cb449f`. No later candidate work was
overwritten. The prior local integration `66365c4c20b4331c004810b4235893315a623525`
has that exact tree. Its original checkout and native, gameplay and qualification
worktrees are accessible and preserved without alteration.

Three previously untracked final findings were recovered: the unfinished
completion qualification audit and the native and Windows-native independent
reviews. Their original pending statements describe the stalled checkpoint;
they are not current terminal outcomes. Recovery uses isolated worktrees from
the published candidate. The prior workspace is nearly full; new work uses a
separate filesystem without deleting prior evidence.

## Original campaign classification

| Evidence | Recovered result | Current applicability |
| --- | --- | --- |
| Run 45473059187, native job 138725897119 | PASS; original archive independently rehashed, 96,500 native assertions, 192 World cases, 231 material tests, 64 contract tests, 74/74 limits | Original f5b7 source only; exact unchanged-input comparison required for reuse |
| Run 45473059187, Windows native job 138725897873 | PASS; cross-built DLL, later actual Windows execution is separate | Original 117 native input manifest and toolchain identities retained |
| Run 45473059187, Linux job 138725897840 | FAIL at pinned Godot archive acquisition, HTTP 403; Workbench cases skipped | Infrastructure failure, not demonstrated application failure |
| Run 45473059187, Windows job 138728620324 | FAIL overall; 38 primary and 27 subsequent cases passed; actual shipped launcher passed; extracted replay executed zero cases | Application positives retained; failed aggregate and absent final evaluator delivery remain failures |
| Run 45457037610 | FAIL overall; native and Windows cross-build passed; Linux and Windows Workbench jobs failed | Superseded source 0f013ba4826730cce64bd37cf9ca95f7dcaab603; no successor qualification inferred |
| Run 45435990124 | FAIL overall; Windows cross-build passed; native, Linux and Windows Workbench jobs failed | Superseded source f4a2176f1f7688273956c2f25821488c227e90f3; historical failures retained |

Original Windows artifact 14961723648 is **33,235,453 bytes**, SHA-256
`3f35d18a7e54ce8327d0b6f63dc57cf3e035380e7b87714c612dd0370f3650d7`.
The delivery specialist downloaded and independently verified its bytes. It
contains original reports, logs and generated caches, not the owner evaluator
ZIP: the evaluator upload step was skipped after replay failed.

Original native artifact 14959327733 is **135,239,647 bytes**, SHA-256
`1629687935c7a1b13fb86c231527ed29e7de13f944e7d933eac82d243b3307cd`.
Independent recovery verified 129 sanitizer and 95 benchmark inputs against
the original archive and published-equivalent tree. Peak requested allocation
was 6,280,328 bytes against the unchanged 6,291,456-byte limit; this is not RSS.

## Reproduced delivery boundary and planned correction

The original Windows replay failed looking for
`Workbench (1)/godot/addons/cybersand_native/runtime-provenance.json`.
Source and original reports show the packager intentionally relocates retained
production provenance to `retained-runtime-provenance.reference.json`, while
the qualifier assumes every tracked Godot JSON retains its original name.
Candidate-native provenance remains a separate source-bound manifest. The
correction must authenticate the explicit relocation against original source
bytes, require the reference, forbid active production provenance in the
evaluator, and retain candidate/runtime and payload verification. Missing,
incorrect, stale, tampered and externally substituted inputs must fail.

Linux acquisition must use the approved pinned Godot release asset with
bounded retry and the existing archive digest. No version, integrity or
provider-policy weakening is admitted.

## Parallel ownership and lead responsibilities

- Native specialist: independently recover original native and Windows-native
  reviews, verify source applicability, challenge ownership/conservation and
  lifecycle, and cross-review delivery corrections.
- Workbench specialist: recover rendered/headless profiles, run controlled
  scene comparisons, inspect ordinary controls and make diagnostics optional.
- Delivery specialist: original Windows/Linux log and archive custody,
  provenance relocation repair, adversarial package tests and pinned engine
  acquisition repair.
- Technical lead: source reconciliation, this durable ledger, integration,
  campaign admission, final packet and explicit owner acceptance boundary.

Ordinary evaluator launch currently enables event recording unconditionally.
The requested correction makes recording optional while tests explicitly opt
in. No physics steps, chemistry, bodies, barriers or required coverage may be
removed to improve reported performance. A material-revision-only snapshot
cache remains rejected because scheduling state can change independently.

## CI coordination and next executable action

PR #771 is still unqualified Draft/HOLD. Issue #761's migration handoff permits
coordination and non-mutating adapter review, not an unrelated helper import.
Its original Actor runtime publication failure and later recovery remain
separate evidence. No PUBPRES, Equipment, Actor Compose or RAMCACHE branch is
imported by this recovery.

The existing ObjectShard completion workflow supports a marker-gated push on
the principal candidate branch. After focused repairs, local verification and
independent review, freeze exact source/tree and use that existing qualification
entry point. Preserve all required native, Linux, Windows, graphical and
extracted-package cases. Do not dispatch duplicate campaigns or cancel other
programmes. Any source movement during qualification must be reconciled and
recorded before accepting a result.

Next: reproduce the provenance mismatch in a bounded fixture, repair its
contract, verify negative cases, complete the diagnostics change and then
qualify the integrated source. No replacement campaign has been launched at
this checkpoint.
