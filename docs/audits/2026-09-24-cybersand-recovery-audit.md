---
title: CyberSand CI and Stage-3B recovery final audit
status: Current
document-kind: evidence
scope: Final REC-008 audit for the 2026-09-20 through 2026-09-22 CI/provider and Stage-3B #65 disruption
canonical-for: [cybersand-recovery-2026-09]
last-reviewed: 2026-09-24
related-documents: [../operations/github-development-and-release.md, ../operations/current-and-historical-validation.md, ../operations/soliding-stage3b-production-plan.md, ../reference/status-and-roadmap.md, ../reference/validation-evidence.md, ../operations/development-claims-remediation-programme.md]
---

# CyberSand CI and Stage-3B recovery final audit

## Scope and authority

This is the dated REC-008 / issue #117 closure audit for parent REC-000 / #109.
It reconciles the CI/provider disruption, Stage-3B #65 recovery, #94/PR #105
quarantine/reconstruction, branch hygiene and current documentation routing. It
does **not** reopen simulation semantics, select a Water architecture, admit Stage 4,
or complete the separate development-claims remediation programme #79.

Authority inspected for this audit:

- pre-REC-008 main:
  `0405cdfe35a855e8287215a71d1165e3107fd1d6`, REC-007 / PR #124;
- #65 accepted merge:
  `cdf0a0874d4732c41273e10d921bcd5feaac3e3c`;
- #65 accepted PR head:
  `2fa4d2270662a0e60985b52253a7e9de8bf737ff`;
- frozen #65 native/test source:
  `8dfa779a561374a5693556f50def3e9666783a98`;
- #94/PR #105 recovered source:
  `66a2935e1001737e63ecb03fd21050f7d433bda7`;
- #94/PR #105 current recovered head at the audit:
  `0f17cd36a6e1fa65176a11d1fe2f695dca06ba12`.

The REC-008 PR is documentation/audit/retrieval work only. Its final merge SHA and
exact-head Documentation/provenance result belong in the #117/#109 completion
record so this dated audit does not invent evidence that did not yet exist when its
text was written.

## Recovery chronology and findings

### 1. CI restoration and the pre-recovery lineage

PR #107 (`ci/draft-pr-cost-guard`) merged as
`63b33eda47c7e159b97d4fa14f2487477d804e93`.
PR #108 then restored routine validation to GitHub-hosted runners and merged as
`20337053911d28f985a3211b5cd7c8f70fd4d9b5`.

This restoration intentionally displaced the earlier external-provider experiment.
No broad reset or force rewrite was used by the REC programme. Later recovery work
preserved useful simulation changes while removing obsolete CI/provider overlap.

### 2. GitHub artifact 403 incident — REC-001 / #110

GDExtension run `35627733817` on exact main
`20337053911d28f985a3211b5cd7c8f70fd4d9b5` built Linux and Windows
successfully. On attempt 1:

- shard 1 job `106430030907` failed during `actions/download-artifact` with
  HTTP 403 before regression execution;
- shard 0 job `106430100017` found the same artifact identity and then received
  the same intermediary 403;
- shards 2 and 3 restored the identical artifact and passed.

Only the failed jobs were rerun once. Attempt-2 shard 0
`106737127729` and shard 1 `106737127342` restored and verified the unchanged
artifact, ran their regressions and passed; aggregate job `106738063940` passed.

Disposition: **intermittent GitHub artifact-service/intermediary failure**, not a
persistent CyberSand workflow, permission, artifact-identity or simulation defect.
No retry framework or unrelated workflow rewrite was justified.

### 3. #65 reconstruction repair and the ABA/reclamation liveness defect

PR #106 initially contained both real #65 work and stale CI/provider overlap.
Recovery reconciled it onto #108/main, removed obsolete CircleCI/Sengi/Avrea
routing, and repaired the #65 scheduler/capacity invariants instead of weakening
tests.

The reclamation-forensics ABA fixture previously stalled with:

- one inactive cleanup-pending subscriber with one live dependency;
- two region-reclaim entries;
- a reclaimable region at the reclaim-queue head;
- a live source-cleanup chain;
- no seed or staged-child cleanup;
- a healthy visible replacement region.

The queue objects themselves were valid. The defect was scheduler-side: an
ordinary Seeking build could exhaust its search, reset to Idle and return zero from
`service_active_build_one()`; because `advance()` had already taken the
active-build branch, it could then return zero without servicing actionable
cleanup.

The correction adds a final **bounded cleanup fallback** before `advance()` may
report zero work. The same focused repair sequence also preserved retained
per-ticket bounded traversal/fairness, fail-closed manifest/source exhaustion,
resource-generation retry gating, exact reverse-index wake ownership and corrected
dependency-capacity accounting.

Frozen native/test source became
`8dfa779a561374a5693556f50def3e9666783a98`. Focused GitHub-hosted
`make soliding-test` run `35654164638` passed after temporary diagnostics were
removed.

### 4. Sanitizer compile-time bottleneck — REC-002 / #111

Native run `35654798534` was not a sanitizer finding. Its 10-minute combined
`make soliding-sanitize` step expired while GCC was still compiling
`test_settled_regions_sanitized`; the binary never ran.

REC-002 measured:

- current-main sanitized settled-regions compile: about 2m17s;
- recovered #65 exact-head isolated compile: 10m29.63s;
- peak RSS: about 8,020,220 kB / 7.65 GiB;
- unchanged GCC 13 ASan+UBSan flags.

The correction kept sanitizer coverage and compiler flags intact. Native CI first
performs a bounded 20-minute isolated build of the expensive sanitized binary and
then runs the existing 10-minute complete `soliding-sanitize` target, which
reuses that up-to-date binary.

Native run `35726233890`, job `106740434625`, then passed:

- ordinary native and soliding tests;
- Stage-3B preregistration apparatus;
- general ASan+UBSan;
- all eight dedicated soliding ASan+UBSan executables;
- TSan with 62 tests;
- shared-library build;
- native benchmark execution.

No #65 native/test semantic change was made by REC-002.

### 5. Source-matched runtime publication — REC-004 / #113

Validated workflow/docs head:
`2cef97763579bb3cee645d15a22d254c3210410b`, tree
`f03efb6d5768ae39a30f633c863c8400b27f825a`.

Linux publication reused the exact runtime artifact exercised by GDExtension run
`35726233644`, artifact ID `10693674907`. Retained Linux runtime:

- path `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`;
- SHA-256
  `35319c915dd6f309c94b9388c2929931817a2cb511afba2cb004b36a93e5b8f7`;
- 1,612,480 bytes.

Windows was rebuilt in publication run `35731243531` with pinned
godot-cpp/SCons/LLVM-MinGW inputs. Retained Windows runtime:

- path `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`;
- SHA-256
  `79d9f586c4097efc7757a3b0960b47a4f6ed8535f068e16e575e406fea99dbd2`;
- 2,090,496 bytes.

Publication run `35731243531` passed
`check_repository.py --require-materialized`, `git lfs fsck`, byte/manifest
verification and verified LFS push. The Linux bytes are runtime-tested. The
Windows DLL is **cross-build evidence only**; no Windows execution is claimed.

### 6. Final #65 acceptance and landed-main verification — REC-005 / #114

Final PR #106 head:
`2fa4d2270662a0e60985b52253a7e9de8bf737ff`.

Exact-head owner-context matrix:

- Documentation/provenance `35732818172` — success;
- Water apparatus v2 `35732816499` — success;
- Native `35732816547` — success;
- GDExtension/Godot `35732816733` — success.

PR #106 merged as
`cdf0a0874d4732c41273e10d921bcd5feaac3e3c` with parents:

1. prior main `20337053911d28f985a3211b5cd7c8f70fd4d9b5`;
2. accepted head `2fa4d2270662a0e60985b52253a7e9de8bf737ff`.

Landed-main matrix:

- Documentation/provenance `35735467304` — success;
- Water apparatus `35735467111` — success;
- Native `35735467244` — success;
- GDExtension/Godot `35735467359` — success.

#65 was closed immediately after merge, before the landed-main matrix had finished.
That ordering was premature relative to REC-005, although the complete pre-merge
exact-head matrix was already green. The landed-main evidence subsequently passed.
The actual chronology is retained rather than rewritten.

Final #65 state:

| Dimension | State |
|---|---|
| Implemented | Yes — accepted PR head identified above |
| Integrated | Yes — merge `cdf0a087...` |
| Verified | Yes — exact-head and landed-main required matrices green |
| Accepted | Yes for #65's stated bounded reconstruction/reclamation/fairness acceptance; this is not Stage-3B or Stage-4 parent admission |
| Dispositioned | #66 -> #67 -> #68 -> #70 remains; Stage 4 blocked |

### 7. #94 / PR #105 recovery — REC-006 / #115

Historical polluted #105 head:
`df7d73894bf362383996dca6a33caa57af7febaf`.

REC-006 reconstructed the proof directly from recovered main. Clean source:
`66a2935e1001737e63ecb03fd21050f7d433bda7`; current recovered PR head:
`0f17cd36a6e1fa65176a11d1fe2f695dca06ba12`.

Stale CircleCI/external-provider workflow changes and stale pre-recovery runtimes
were discarded. Exact reconstructed source passed Native run `35744170902` and
GDExtension/Godot run `35744170918`; the WEX-004 fixture executed with
`ok:true`. Fresh source-matched retained runtimes/provenance were published in
run `35746514892`.

PR #105 remains:

- open;
- draft;
- bounded non-production research;
- the sole active owner for this proof;
- pending #94's separate evidence/disposition review.

Recovery validation is **not** authority to merge or adopt a production atmosphere
mechanism.

### 8. REC-007 CI/provider/cost guardrails

REC-007 completed on
`0405cdfe35a855e8287215a71d1165e3107fd1d6`.

The active provider checker rejects:

- `.circleci/config.yml`;
- active Avrea/Sengi/CircleCI routing tokens;
- `*_RUNNER` indirection;
- non-literal/non-GitHub-hosted `runs-on` labels.

Draft PRs suppress expensive Native/GDExtension/Water work. Ready-for-review uses
a small scope gate so policy/docs-only changes do not launch the expensive matrix.
Implementation/source changes still require the applicable exact-head gates.
Source-sensitive runtime provenance remains fail-closed.

Final policy PR #124 demonstrated the intended behavior; post-merge
Documentation/provenance run `35751825085` passed.

REC-007 does **not** replace #86. #86 remains the owner for durable
multidimensional completion, implementation ownership/handoff and
validation-precondition receipts.

## Remote repository state

At the 2026-09-24 REC-008 inspection:

- repository visibility reported by GitHub metadata: **public**;
- default branch: `main`;
- `main.protected=false`;
- repository rulesets: none;
- active routine CI: GitHub-hosted;
- no REC-008 implementation branch existed before
  `recovery/rec-008-final-audit` claimed ownership.

The connector cannot install the missing owner-side branch ruleset. The exact
minimal rule is maintained in
[repository development and release](../operations/github-development-and-release.md#main-branch-protection-exact-owner-action).
This remains an explicit owner action after recovery closure.

## Branch hygiene inventory

REC-008 **does not delete branches**. It records current heads and conservative
dispositions so deletion can be a separate owner-confirmed action.

| Branch / head | Classification | REC-008 disposition |
|---|---|---|
| `avrea/convert-09ccaeffecbe` / `2a3058a...` | Closed unmerged PR #37; obsolete Avrea conversion | Safe-to-delete candidate after owner confirmation; SHA/PR retained here |
| `avrea/convert-6905f97e81b2` / `7e6d029e...` | Obsolete Avrea conversion; no active owner found | Safe-to-delete candidate after owner confirmation |
| `avrea/convert-b12ea4f16103` / `a815f10b...` | Obsolete Avrea conversion; no active owner found | Safe-to-delete candidate after owner confirmation |
| `avrea/convert-df472865011b` / `978d8301...` | Obsolete Avrea conversion; no active owner found | Safe-to-delete candidate after owner confirmation |
| `bench/weekend-slim-avrea-2026-09-19` / `a983b553...` | Benchmark/history referenced by retained audit | Retain as evidence/history |
| `ci/gdextension-linux-shards-stage-a` / `a0461f38...` | PR #48 merged; functionality represented in later main | Safe-to-delete candidate after owner confirmation |
| `ci/sengi-defaults` / `3b74b49c...` | PR #52 merged historically; provider policy later superseded | Safe-to-delete candidate after owner confirmation |
| `ci/sengi-benchmark-run` / `abcff9b7...` | Benchmark/debug branch without a resolved PR association in this audit | Unknown/evidence — retain |
| `circleci/pilot-issue61` / `f3310171...` | Provider pilot without a resolved PR association in this audit | Unknown/evidence — retain |
| `ci/circleci-windows-gdext` / `acfaabcf...` | PR #99 merged historically, superseded by #108/REC-007 | Safe-to-delete candidate after owner confirmation |
| `ci/circleci-windows-cutover` / `3b889bd7...` | PR #100 merged historically, superseded by #108/REC-007 | Safe-to-delete candidate after owner confirmation |
| `ci/draft-pr-cost-guard` / `b9639229...` | PR #107 merged; final guard evolved through REC-007 | Safe-to-delete candidate after owner confirmation |
| `ci/restore-github-hosted-runners` / `718ed741...` | PR #108 merged; recovery authority preserved on main | Safe-to-delete candidate after owner confirmation |
| `codex/ci-worker-parity-shard-fix` / `2b8a41bb...` | PR #75 merged; head is contained by main | Safe-to-delete candidate after owner confirmation |
| `codex/issue-65-stage3b-exact-reconstruction` / `2fa4d227...` | PR #106 merged and fully verified | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-ci-guardrails` / `563e278a...` | PR #118 closed unmerged; superseded | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-ci-guardrails-final` / `c849e163...` | PR #119/#121 closed unmerged iterations; superseded | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-validation-scope` / `9baea5c6...` | PR #120 merged | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-validation-scope-fix` / `3a8d0f96...` | PR #122 merged | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-ready-scope` / `4d952cd5...` | PR #123 merged | Safe-to-delete candidate after owner confirmation |
| `recovery/rec-007-policy-final` / `c9bba994...` | PR #124 merged | Safe-to-delete candidate after owner confirmation |
| `recovery/issue-94-wex004-clean` / `66a2935e...` | Clean recovered source feeding still-open PR #105 | Retain while #94/#105 is active |
| `codex/issue-94-wex004-decompression-proof` / `0f17cd36...` | Active PR #105 owner | Active owner — retain |

The inventory intentionally avoids treating every old `codex/*` feature branch
as recovery debris. Unrelated open research/feature branches remain outside this
cleanup classification.

## Current routing after recovery

### Stage 3B

#56-#65 and #69 are complete. #65 is no longer the blocker.
The next sequence is:

`#66 -> #67 -> #68 -> #70 -> parent Stage-3B admission decision`.

#70 executes the preregistered campaign and produces the exit packet. It does not
self-admit Stage 3B. Stage 4 remains blocked.

### Development-claims remediation

The separate #79 programme remains open. In particular:

- #81/#83 own generic body/granular reconstruction and broader acceptance;
- #82 owns broad player/granular acceptance;
- #84 owns formal Water H capture integrity;
- #85 owns remaining current-truth/platform/counter reconciliation;
- #86 owns closure/implementation-ownership/validation-premise controls;
- #87 is the independent final remediation re-audit.

Recovery closure must not be read as completion of those issues.

### Water extension

#94/PR #105 is recovered but still draft. #95 remains the later WEX synthesis /
routing decision. No production Water pressure solver is selected by this recovery.

## Final REC-000 closure review

| Question | Answer |
|---|---|
| What is the authoritative baseline inspected by REC-008? | Pre-REC-008 main `0405cdfe35a855e8287215a71d1165e3107fd1d6`; the audit PR merge becomes the later authoritative main and is recorded in issue completion. |
| Are required baseline gates green? | Yes for the recovered baseline: Documentation/provenance `35751825085` passed; #65's required exact-head and landed-main matrices are green. REC-008 itself must pass its documentation/provenance gate before merge. |
| What exact #65 source landed? | Frozen native/test source `8dfa779a...`; accepted PR head `2fa4d227...`; merged as `cdf0a087...`. |
| Are retained runtimes source-matched? | Yes. Linux is the exact tested artifact; Windows is source-matched pinned cross-build evidence only. |
| Is #65 closed for genuine acceptance rather than convenience? | Its original bounded acceptance is now supported by exact-head and landed-main evidence. The issue was closed too early in chronology, and that fact remains recorded. |
| What is #94/#105 status? | Reconstructed, validated, source-matched, open draft research; no production/merge disposition yet. |
| Are external provider configurations absent from active main? | Yes; REC-007 machine-checkably enforces GitHub-hosted active routing. |
| Is main protected? | No. `main.protected=false`, no ruleset. Owner action remains explicit. |
| Which branches remain intentionally? | Historical benchmark/unknown-evidence branches plus active #94/#105 recovery/source branches; no branches are deleted by REC-008. |
| Which risks remain open? | Main protection owner action; #79/#81-#87 remediation; Stage-3B #66-#70; #94/#95 Water research; broader platform/replay/Web obligations already owned elsewhere. |

## REC-008 disposition

The recovery programme can close once the REC-008 documentation-only PR passes its
required exact-head Documentation/provenance checks, merges, and the landed main
identity is recorded on #117/#109.

That closure means the **2026-09-20 through 2026-09-22 recovery incident is
resolved and documented**. It does not claim:

- Stage 3B or Stage 4 admission;
- completion of #79 remediation;
- owner installation of main protection;
- Windows runtime execution for the #65 retained DLL;
- production adoption of WEX-004;
- deletion of historical/recovery branches.
