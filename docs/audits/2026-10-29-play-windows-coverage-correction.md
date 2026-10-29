---
title: PLAY Windows coverage source-authority and skipped-job correction
status: Current
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Locally tested CI-evidence checker correction; no gameplay or release promotion
related-documents: [2026-10-29-play-pace002-constructed-policy.md, ../operations/github-development-and-release.md, ../systems/player-control-playground.md]
---

# PLAY Windows coverage correction — 29 October 2026

## Source and observed failure

Review base is PR #299 `7842f7bec0d0c084f6310a19e59f243f2afa2e2c`,
tree `d4b4c9778bdaea411d509a3a9718bb3c3ca82ca7`; accepted main is
`aac0feb65e2268b74975892ce1df81e04e1a7e40`.

[Godot run 40954448081](https://github.com/techrote/cybersand/actions/runs/40954448081)
completed both actual Windows shards successfully, jobs 123730768430 and
123730768580. However, `windows sharded execution coverage` job123741451794
was **SKIPPED**. The dependent chain contains intentionally skipped
`ready_scope`; the coverage condition lacked the explicit `always()` used by
other aggregate gates. GitHub documents skip propagation through dependent
jobs and the explicit override in its
[job dependency contract](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs).
A workflow success therefore did not establish execution of the new coverage
checker. The successor changes only that condition to
`always() && needs.windows-regression.result == 'success'`; draft/stress/source
scope, Windows matrix, permissions, all job/step/case timeouts and tests are unchanged.

A separate local adversarial execution of the exact old verifier Git blob
`af6ddcf8f200bbb1ed6352278add8088d5463751` (SHA-256
`ee36bd6b0515a4e71c671ce891e294b66646d4fd160f859f35fd9855ff69a4af`)
returned **passed** for two mutually consistent shard reports that omitted a
third source-required case and supplied no runtime manifests or identities.
This is a reproduced synthetic false positive, **not evidence that the real
Windows jobs omitted tests**. The old checker treated the reports' common
inventory as authority and accepted mutually absent identity fields.

## Correction and local tests

The CLI now derives its contract from its exact checkout: Git HEAD/tree,
source-discovered applicable and explicitly graphical cases, deterministic
per-shard plans, original case flags/deadlines, committed runtime manifest,
complete native input map and current source hashes, committed LFS object
identities, pinned Godot version/archive digest and tracked-input inventory.
It does not download or republish a native binary. Each original shard must
match this external contract. Archived runtime-manifest bytes and every raw
log are hash-verified; nonexistent identities, coordinated inventory omissions,
changed commands/deadlines, nonzero exits and symlink/path escapes refuse.
The output schema is `windows-godot-sharded-coverage-v2`.

**Local Python 3.13.5:** 28/28 unit tests passed, including six temporary-Git
source-contract tests. Those six use explicit fixture discovery/runtime
providers, not a full engine checkout. The artifact verifier also accepted the
real retained Windows pair below using independently reconstructed expected
plans and source/runtime pins. Python AST/compile checks passed; YAML parsing
and semantic comparison prove exactly one workflow-condition change.
The first local prototype exposed a parameter-shadowing error; it was fixed
before publication, and the original failed local output is retained in the
session evidence bundle. No local Godot/native execution or whole-repository
documentation check is claimed.

The prior duplicate-case test had retained the wrong log hash and could fail
before reaching coverage validation. Its replacement correctly reseals the
modified log and demands refusal at the source-derived plan check.
Existing source-specific budgets are preserved: most cases use180 seconds,
import240, selected development cases420, and profiles1200. Earlier shorthand
calling all per-case budgets180 seconds was inaccurate; this change does not
increase any existing budget or change those pre-existing exceptions.

## Actual Windows artifact readback at the earlier source

Downloaded original artifacts from run40954448081 attempt1:

| Artifact | Original ZIP SHA-256 | Members |
| --- | --- | ---: |
| 12934237375, Windows shard0 | `b577714c6c72366b2cb6dfe98f8bd6e807c510e610af5ad331aa2ebc8f38bdcd` | 98 |
| 12934172205, Windows shard1 | `cfac6fd1ca00196021046783b5f298d6775501824157434049799fa28e3e5ec6` | 98 |

Both ZIPs match the Actions digest, pass CRC and have unique safe member paths.
Both original reports are completed/pass,95 cases each, and independently
reconstructed coverage is **190 distinct applicable cases exactly once** with
**192 verified original test-log hashes**, including two import preflights.
Actual checkout `6beff8685e127fd46bd8bc6732363c7e2c426235` has authenticated Git
parents [aac0feb65e22,7842f7bec0d0] and the identical literal-head tree d4b4c977.
The archived runtime manifest matches current committed blob
`0b8eb7213a83cb22f1169579412f3f4fb4aa87b9`.

Expectation derivation used the original source9803 complete discovery plan
(not its incomplete execution) plus the independently verified no-Godot-test
source delta to7842 and the current source-pinned manifest/tree. It did not
use the two new reports' common inventory as its sole oracle. This was a
local artifact reduction, not execution of the new CLI against a complete
local repository clone.

All five Windows PACE002 rigs report98 assertions/zero failures and four
positive-receipt policy windows:20 windows,490/0 assertions. All60 Windows
raw timing distributions were recomputed without discrepancies. The Windows
shards completed in1220.985 and1213.234 seconds respectively. These timings
characterize this hosted test campaign, not desktop gameplay FPS.

## Retained limits and acceptance gate

Original run40942029061's 40-minute monolithic Windows timeout remains FAILED;
the later successful sharded campaign does not erase it. Source7842's
SKIPPED coverage job is not a passed invocation. Corrected-head hosted
coverage execution, original artifacts and final source review remain required.
No production/native/runtime/material/default/Rapier/worker changes occur.
No merge, slow-native UI, outstanding-native-job shutdown, physical-device,
human-feel or #263/#270 release acceptance follows from this correction.
