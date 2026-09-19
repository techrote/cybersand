---
title: Issue 12 Stage 3 Spark packet D - integrated measurement campaign
status: Planned
document-kind: runbook
scope: GPT-5.3-Codex-Spark benchmark/reduction package for whole-system Stage-3 overhead after producer/connectivity integration; no optimization claims without evidence
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [soliding-stage3-freeze.md, soliding-measurement.md, ../audits/2026-09-19-issue-12-foundation.md]
---

# Spark packet D: integrated Stage-3 measurement

## Entry gate

Run after Producer + Connectivity are integrated, focused correctness passes, and
the independent verifier has no unresolved correctness blocker.

Use the exact integrated source as candidate. Preserve PR #43's frozen ordinary
sleep evidence as historical control; where source-matched timing is required,
build a fresh candidate/control pair under the preregistered comparison procedure
rather than pretending old wall-clock timings are a perfect paired experiment.

Do not modify material semantics or acceleration behavior.

## Ownership

Prefer benchmark/reduction/evidence files:

- new focused native benchmark(s);
- `tools/experiments/` runner/reducer/tests;
- dated issue-12 evidence under `docs/audits/issue-12-...`;
- measurement-contract updates required by actual instrumentation.

Avoid core World/connectivity implementation unless the parent explicitly assigns
a tiny instrumentation seam.

## Required workload matrix

Include, at minimum:

- quiet Wall/RedBrick 512/1024/2048 equivalents;
- local-edit stable solid;
- granular rest;
- granular release positive behavior control;
- large multi-tile connected solid crossing chunk seams;
- ring/hole and seam-rich geometry;
- sparse local edits on a very large stable world;
- repeated bridge add/remove causing split/merge;
- body-mask locality churn;
- pending-event/deadline activity;
- exclusion/re-entry;
- churn-heavy negative control where discovery should lag/refuse without harming World.

Use workers1/4 at minimum. Preserve translations/negative boundaries where relevant.
All timing children are sequential on the Ryzen 2600X when owner reserves the host.

## Separate cost accounting

Measure producer, journal and connectivity costs separately where possible:

- producer notification count/time by reason;
- activity metadata/subtile feed work;
- tile registration/index cost;
- cells/tiles inspected;
- tile queue high-water;
- connectivity local-component work;
- boundary comparisons;
- region traversal/restarts;
- invalidation fanout;
- capacity/refusal;
- region count/area distribution;
- memory bytes by structure;
- dirty-to-tile and dirty-to-region complete latency;
- local edit wake/rebuild amplification.

Retain World TickStats and ordinary/epoch-clear separation from the existing
measurement contract.

Do not report zero discovery cost for Current; mark those counters N/A.

## Integrity/provenance

Freeze before timing:

- source commit/tree and local delta;
- compiler/tool hashes;
- executable hash;
- World config/capacities;
- fixture/seed/translation/workers;
- candidate feature flags/budgets;
- exact process schedule;
- hardware/power/contender snapshot.

Retain every timeout/nonzero/malformed/outlier. Reducers are read-only and refuse
overwrite. Add corruption tests for missing/duplicate/unregistered/mismatched
attempts.

## Interpretation

Stage 3 does **not** require a speedup. It requires a credible bounded cost model.

Report:

- where read-only discovery overhead is negligible/material/significant;
- startup versus steady maintenance;
- region size/churn scaling;
- capacity breakpoints;
- whether producer metadata passes or connectivity dominate;
- whether quiet-world epoch cost still dominates independently of discovery;
- whether any >15% paired p95 or >1ms epoch-clear review trigger is crossed.

Do not tune thresholds to manufacture a win.

Stage 4 may use this evidence to select bake-off candidates and break-even questions,
but this packet does not implement Stage 4.

## Completion

Return exact raw/reduced evidence identity, commands, failures, limitations and a
plain statement of what Stage-3 exit checklist items the measurements satisfy or
leave open.
