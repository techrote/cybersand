---
title: Ordinary workbench freed-object material consumer transitions
status: Current
document-kind: audit
scope: Two reviewed non-identity consumer transitions for archived aggregate custody; no physics or material identity change
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../architecture/workbench-freed-objects.md, ../operations/material-catalogue-shadow.md, 2026-11-06-sol-workbench-material-transition.md]
---

# Ordinary workbench freed-object material consumer transitions

Owner direction authorizes ordinary cutting on Draft
[#466](https://github.com/techrote/cybersand/pull/466), retaining physics.
Source commit `ca9a8287e29ad36c07ae6b5b76c5d6221c389ef8` contains the following
complete protected-file delta from admitted source
`89c7b5931dd18601b72c5ce0f77186eaac16cbc1`:

| Consumer | Previously admitted LF SHA-256 | New LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `b0a8ad4b20b46fa005bbf7f594e3e96a40d8d5920a258e69d7c8c218262a77a1` | `ce67b7cc999d4163cb7c92f8089174a216f95e7129749b71fcc62a14545279dd` |
| `native/src/world_pressure.inc` | `75c9897aa0eec69900d2e37d69a83b513d7c8ae2894d95e41a09cc0493195079` | `9818ed10332a03eef99b53fba7a7e91448e792414541048ada1927f1ba168c48` |

World clear additionally releases the archived workbench custody store. The two
existing physical hash/CYPS guards additionally refuse archived active objects
after the pending transaction returns to Idle. These changes prevent omission
of authority that the physical codec cannot encode. They provide no active
restoration and change no protected movement, pressure, chemistry, thermal,
quantity, material identity or contact arithmetic.

The separate read-only `freed_native_contract` reviewer compared the exact
committed delta, independently reproduced these LF hashes, checked reachability
with `git merge-base --is-ancestor` (exit0), and gave scoped technical PASS for
these two per-file transitions, subject to ordinary compatibility and provenance
gates. Source review does not qualify the runtime or overall feature.

Retain all seven previous transitions, the frozen compatibility lock and every
catalogue/capability/policy identity. Add these two reachable, commit-bound steps;
do not squash or cherry-pick away admission ancestry. Headers, the discovery
include and native extension also require full rebuilt-runtime inventories.
Old evidence, failures and platform qualifications remain unchanged. Actual
execution belongs in the dated freed-object qualification dossier; this record
alone makes no physical clearance, CPU, supported-platform or integration claim.
