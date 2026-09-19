---
title: Issue 27 recovery and implementation selection
status: Current
document-kind: evidence
scope: Recovery record for the duplicate MS-000 implementations created on 2026-09-19
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [2026-09-19-issue-27-microscenarios.md, ../operations/microscenarios.md, ../operations/microscenarios-programme.md]
---

# Issue 27 recovery and implementation selection

## What went wrong

Issue #27 was implemented twice from the same main checkpoint
`781a2d7cb5d5a66bf1cff8fc6654e0ab708e419c`.

The first implementation was published as PR #36 from
`codex/issue-27-microscenarios-harness`. During the subsequent validation/recovery
work, the already-published implementation was not treated as the sole active
implementation. A second implementation was independently completed on
`codex/issue-27-ms000-validated` and published as draft PR #40.

This was a coordination/state-tracking failure, not repository corruption. Main was
not modified, neither branch overwrote the other, and draft research PRs #25/#33
were not changed. Both implementations retained the isolated #24 launcher-focus
prerequisite, but they define incompatible GDScript schemas/classes
(`micro_scenario_*.gd` versus `microscenario_*.gd`) and must not be merged together.

## Recovery decision

PR #40 is the retained implementation. PR #36 is superseded rather than merged.

The selection is based on implementation and evidence scope, not chronology:

- stricter contract validation, including explicit observation/condition limits and
  normalized parsed-number handling;
- an explicit scenario provenance/identity helper;
- two generic proving fixtures (unequal-head Water and Sand support release);
- broader ownership, capacity, persistence and build/run documentation;
- explicit fixed interest/cadence/adhesion handling at the scenario boundary;
- stronger failure-path and transaction tests, including invalid replacement before
  World mutation and native failed-world quarantine;
- 6,471 harness assertions plus 52 controller/input assertions in the retained local
  evidence, in addition to the existing native and Godot suites;
- publication integrity tied to the exact tested tree and per-file SHA-256 manifest.

No code from PR #36 is being mechanically combined into PR #40. Any future useful
idea from the closed alternative must be re-reviewed against the retained contract
rather than copied across by filename or class name.

## Cleanup and preservation

The recovery keeps the following evidence boundaries:

- PR #40 / `codex/issue-27-ms000-validated`: retained implementation and merge candidate.
- PR #36 / `codex/issue-27-microscenarios-harness`: closed historical alternative.
- PR #34 / `codex/issue-24-focus-fix`: retained until the selected #27 branch lands,
  then closed as superseded because the same prerequisite is present in #40.
- PRs #25 and #33: untouched research branches.
- main: unchanged until the selected PR passes its own final CI and is merged.

Temporary transfer/workbench artifacts are not present in the retained product diff.
Historical comments and audit records are preserved; they are not rewritten to imply
that the two implementations were one continuous tested tree.

## Acceptance rule after recovery

Only PR #40's source, audit and CI may support closure of #27. PR #36's passing CI
remains useful historical evidence about that alternative but cannot be used to waive
a missing #40 gate.

Before merge, require the selected head to have successful documentation/provenance,
native/sanitizer, and Linux/Windows extension CI. Actual browser/WebAssembly and
Windows runtime execution remain explicit evidence gaps unless separately performed;
cross-compilation is not relabeled as runtime acceptance.

After merge, verify the selected commit landed on main, close #27 only if its
acceptance criteria remain satisfied within the documented platform scope, and close
#24/PR #34 as superseded by the landed prerequisite.
