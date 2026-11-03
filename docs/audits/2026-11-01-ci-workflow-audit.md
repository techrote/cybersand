---
title: Repository-wide CI scheduling audit
status: Current
document-kind: evidence
scope: All 24 active GitHub Actions workflows, scheduling changes, retained scientific boundaries and actionable follow-ups
canonical-for: [ci-workflow-audit-2026-11-01]
last-reviewed: 2026-11-01
related-documents: [2026-11-01-ci-scheduling-qualification.md, ../operations/ci-execution-and-performance.md, ../operations/github-development-and-release.md]
---

# Repository-wide CI scheduling audit — 2026-11-01

This audit starts from main `15b3a4012b9d5998e808fb371792dd7a71398507` and
examines every file in `.github/workflows/`, its triggers, matrices, admission,
timeouts, preparation, artifacts and aggregate failure paths. **Current source
findings** below are distinct from measured execution. The
[qualification record](2026-11-01-ci-scheduling-qualification.md) owns exact
tested source, complete hosted job data, the historical comparison and review.
Historical [run #1711](https://github.com/techrote/cybersand/actions/runs/41250780110)
is evidence for its own source and attempt, not an immutable current inventory.
The [execution contract](../operations/ci-execution-and-performance.md) owns
scheduler and watchdog semantics.

“Fixed” identifies an implemented source change, not a claim that every optional
scientific campaign was rerun. “Acceptable” identifies a deliberate bounded
configuration. “Deferred” includes a concrete follow-up; it does not excuse a
failed required gate. Severity describes the finding, not an assertion of a
measured incident where only source evidence exists.

## Complete workflow inventory

| Workflow / component | Finding | Severity | Evidence | Expected impact | Resolution |
|---|---|---|---|---|---|
| [GDExtension](../../.github/workflows/gdextension.yml) / planner | Confirmed: generous individual watchdogs were added together as scheduling costs; both generated matrices had no parallelism cap. Same-ref non-cancelling workflow grouping blocked newer runs. | High | Planner source; fully paginated #1711 comparison in qualification record. | Substantially fewer jobs and repeated preparations; maximum eight active regression jobs per OS per run; obsolete PR work cancelled. | **Fixed**: expected-cost partitioning, independent aggregate admission boundary, complete coverage readers, eight per matrix and separate PR/manual/main groups. |
| [Documentation](../../.github/workflows/documentation.yml) | Confirmed: obsolete PR checks could block their replacements. Universal no-path-filter check is intentional. | Medium | `docs-${github.ref}` with cancellation disabled at baseline. | Latest PR source receives the required check sooner; one-job workload remains. | **Fixed**: PR supersession; manual/main evidence preserved. Added repository-wide scheduling check and inventory. |
| [Native](../../.github/workflows/native.yml) | Six distinct sanitizer/test families already bounded at six. Confirmed: old ref-only cancellation also cancelled explicitly requested manual/main runs. | Medium | Six-family dynamic plan; stable `native` exact-source aggregate; `cancel-in-progress: true` at baseline. | Preserve six-family coverage and useful concurrency; protect requested qualification. | **Fixed** concurrency; **Acceptable** six-job matrix and fail-fast disabled. No dependency-based exemption introduced. |
| [Native scope advisory](../../.github/workflows/native-scope-advisory.yml) | Advisory is one independent report, never a skip authorization. Manual immutable-base reports shared an unconditional cancellation group. | Low | `native_skip_authorized=false`, explicit `base_sha`, original source receipts. | Preserve requested comparison while superseding ordinary PR advice. | **Fixed** concurrency; **Acceptable** separate lightweight report. |
| [Water apparatus v2](../../.github/workflows/issue49-water-apparatus.yml) | Confirmed: 60-minute parent was shorter than 2+2+10+5+50 minutes of existing child allowances; manual runs could be cancelled. | Medium | Literal command limits; path-scoped, draft-gated single job. | Avoid parent termination before unchanged children and artifact capture can complete. | **Fixed**: 90-minute parent and PR-only supersession. Scientific apparatus, samples and thresholds unchanged. |
| [Physical actor stress](../../.github/workflows/physical-actor-stress.yml) | Retained trials capped at five per OS, paired matrices uncapped; 30-minute Linux build parent contained 35+20-minute build commands. | High | Five batches on each OS; paired variants execute on the same host; source YAML. | At most three trial jobs per OS; preserves all batches and paired-host comparability; build/evidence headroom. | **Fixed**: all trial matrices capped at three, frequency reduction at two, build parent 100 minutes. Retained and paired jobs are mutually exclusive. |
| [Physical timeout stress](../../.github/workflows/physical-timeout-stress.yml) | Confirmed: two uncapped 2-mode × 5-batch matrices could use 20 slots. A 40-minute build parent contained 55 minutes of build commands. Same-source manual requests could replace pending requests. | High | Literal matrix; frozen full source SHA; `stress-gate` accounts for 600 cases. | Six concurrent trials total per run, unchanged 20 jobs/600 cases; independent requested attempts. | **Fixed**: three per OS, 90-minute build parent, run-specific concurrency group. |
| [Rapier BVH builds](../../.github/workflows/rapier-bvh-build.yml) | Two control/candidate variants on each OS are inherently bounded at four total; workflow is itself a retained runtime source input. | Low | Literal two-entry matrices; provenance manifests and `test_validation_contracts.py`. | No current fan-out pathology; changing workflow bytes would require new runtime provenance/qualification. | **Acceptable** unchanged producer. Checker permits only this static two-per-OS exception; growing a matrix requires an explicit budget. |
| [PLAY BUSY001A](../../.github/workflows/play-busy001a-pool.yml) | Three Linux sanitizer arms plus one Windows arm; unconditional cancellation could discard manual apparatus evidence. | Medium | Narrow historical branch trigger and exact source extraction. | At most two Linux arms plus one Windows; preserve independently requested runs. | **Fixed**: Linux cap two, run-specific non-cancelling groups. Fixed scientific gate delays remain. |
| [PLAY BUSY001B](../../.github/workflows/play-busy001b-host.yml) | Confirmed: each 25-minute build parent contained 35+20-minute builds plus preparation. Manual source-pinned runs could be cancelled. | Medium | Literal build limits; separate Windows execution; instrumented real-host evidence. | Preserve full child allowances and evidence; at most two build jobs followed by Windows execution. | **Fixed**: both build parents 90 minutes and run-specific groups. Inner scientific apparatus limits unchanged. |
| [PLAY desktop packet](../../.github/workflows/play-desktop-packet.yml) | One preflight plus two OS jobs; shared exact-source group could replace repeated pending requests. No desktop human acceptance is inferred. | Medium | Derived packet budgets and independent readers; source/runtime manifests. | Preserve original manual packet requests; three jobs remain. | **Fixed**: run-specific groups. **Acceptable** derived complete parent budgets and per-OS evidence. |
| [PLAY LIFE009](../../.github/workflows/play-life009.yml) | Two OS jobs restricted to the named historical PR branch or manual dispatch; same-source pending requests could be replaced. The underlying campaign also rejects protected source changes since `0bf28d57`, including current main. | Low | Job branch `if`; `run_life009_campaign.py` fixed `BASE`/`PROTECTED` admission. Current ordinary regression programme separately discovers all five cases. | Preserve historical manual evidence; this campaign cannot qualify arbitrary current-main source. | **Fixed** run-specific groups; **Deferred** retirement/generalization with an explicit campaign recharter. Preserve the source guard; complete current GDExtension/readback remains required. |
| [MAT003 C128 timing](../../.github/workflows/mat003-c128-timing.yml) | One manual-only formal campaign; intentional single-campaign group. Workflow hash and original artifact are registered inputs. | Low | Owner receipt binds exact source and registration; first-attempt-only guard. | No matrix explosion; changing concurrency changes admitted apparatus identity. | **Acceptable** frozen campaign. Future admission must explicitly choose pending-request queue semantics. |
| [MAT003 S2A](../../.github/workflows/mat003-s2a.yml) | One manual campaign executes 224 registered processes on the intended host sequence; immutable artifact ID can expire. | Medium | Sealed 17-arm binary hashes and original run ID; independent reader. | Serial schedule preserves comparability; unavailable evidence must fail visibly. | **Acceptable** registered sequence; **Deferred** durable artifact retention under a new disposition, never replace frozen artifacts silently. |
| [MAT003 S2P timing](../../.github/workflows/mat003-s2p-timing.yml) | One manual-only campaign, registered workflow hash, 100-minute parent and explicit acquisition/readback/timing windows. | Low | Authenticated owner/source receipt and retained original failures. | Bounded one-slot experiment; no speculative cross-workflow consolidation. | **Acceptable** frozen campaign; queue caveat below. |
| [MAT003 WCLEAR timing](../../.github/workflows/mat003-wclear-timing.yml) | One manual-only campaign, registered workflow hash and 210-minute parent for separately bounded 125-minute sampling. | Low | Immutable registration/artifact, exact frozen reader and authority. | Preserves intentional long sampling and diagnostic headroom. | **Acceptable** frozen campaign; queue caveat below. |
| [LCB001 publication](../../.github/workflows/lcb001-shared-contract-runtime-publication.yml) | Six declared jobs, exact historical branch and explicit request admission; no generic regression fan-out. Short legacy parents can undercut complete preparation/execution allowances. | Medium | Branch lease and request schema; 55-minute build and 25-minute Windows parents. | No routine-main load. Consolidating publishers would change write authority and source identity. | **Deferred**: retire accepted publisher or requalify its complete parent arithmetic before a new request. Keep original manifests. |
| [LCB002 publication](../../.github/workflows/lcb002-pressure-variants-runtime-publication.yml) | Same bounded publication topology; distinct variant authority and exact branch. Legacy timeout arithmetic remains. | Medium | Named source branch, request, runtime source-inputs, atomic publication lease. | No broad duplicate routine work; preserve authority isolation. | **Deferred** retirement/requalification before reuse. |
| [LCB003 publication](../../.github/workflows/lcb003-application-host-runtime-publication.yml) | Same bounded topology; source-only publisher modifications are guarded separately from arming. Legacy build parent is shorter than setup plus 55-minute children. | Medium | `armed` output, exact integration branch, artifact identities and four-path lease append. | Correctness requires source-matched build, runtime and append; no cache shortcut authorized. | **Deferred** retirement/requalification before reuse. |
| [LCB005 Brine publication](../../.github/workflows/lcb005-inertial-runtime-publication.yml) | Separate profile/branch/authority; six declarations but independent build width only two. | Medium | Private profile/request and atomic lease; inherited legacy timeouts. | Preserve separation from Water and historical publication evidence. | **Deferred** timeout/retirement review before any reactivation. |
| [LCB005 Water publication](../../.github/workflows/lcb005-water-inertial-runtime-publication.yml) | Independent Water authority and already-published request sequences; old source-specific jobs should not become generic CI. | Medium | Exact Water branch/profile and request sequence; retained manifests. | No normal main/PR expansion; reusing a historical request is not new-source validation. | **Deferred** retirement/requalification; no request or manifest rewritten. |
| [Web demonstrator](../../.github/workflows/web-demo.yml) | Confirmed pre-existing broken producer/consumer design: fixed old toolchain run, 4.0.11 Emscripten versus builder's 4.0.20, compile-only/native-test argument conflict. | High | Existing canonical CI contradiction ledger; literal artifact run ID and builder flags. | A single job can waste setup and cannot establish current Web runtime acceptance. | **Fixed** manual cancellation isolation only. **Deferred** source-pinned Web toolchain/export repair and actual browser qualification under issue #3. |
| [Web toolchain](../../.github/workflows/web-toolchain.yml) | One manual/historical-branch producer; seven-day artifact retention cannot sustain a permanently pinned consumer. | High | `retention-days: 7`; Web demo fixed `run-id: 34034700056`. | Expired inputs predictably block consumer; no fan-out issue. | **Deferred** joint producer/consumer repair with immutable toolchain manifest, durable retention, provenance and target execution. |
| [Release hashes](../../.github/workflows/release-hashes.yml) | Confirmed: 15-minute parent allowed exactly three 5-minute checks and no checkout/LFS/upload reserve. One job per tag/manual request. | Medium | Explicit timeout calls, full LFS integrity and retained historical checks. | Avoid parent termination before independent hash publication. | **Fixed**: 30-minute parent; all checks, pinned companion and evidence remain. |
| Shared pinned Actions | Hosted runs report Node.js 20 action metadata being executed under Node.js 24 compatibility. No failure observed in this qualification. | Low | Original hosted job annotations for pinned checkout/upload actions. | Future compatibility risk; no measured queue benefit from changing pins. | **Deferred**: reviewed immutable action upgrades with focused workflow/provenance qualification, especially frozen producers. |

## Capacity, trigger and evidence decisions

The selected routine regression caps are eight Windows plus eight Linux slots.
Native retains six separate families. Documentation, advisory and Water normally
use one each; build/preflight/reduction jobs use additional slots at different
stages. A conservative sum of these visible classes is about 27 slots including
two builds, leaving room under the owner-reported 40 standard hosted slots for
one ordinary source validation alongside modest independent work. This is a
planning envelope, **not a global cap or guaranteed reservation**. Two PRs, a
manual qualification, other repositories and conditional extra workflows can
exceed 40. Stress campaigns now limit their trials to six slots per run, but
operators should still launch them separately from full qualification when
measuring queue effects. No repository-wide lock was added.

Routine push triggers target main, so ordinary feature-branch pushes do not
duplicate their PR validations. Post-merge main is a distinct exact source and
its evidence remains useful. Native/GDExtension draft and paths-ignore policies
remain; workflow-only changes therefore require explicit manual hosted
qualification. The universal documentation check remains unfiltered. No passing
result is transplanted between commit, PR merge ref or run attempt. No fail-fast,
missing-artifact or independent coverage check is relaxed to shorten the queue.

PR groups include workflow, event and PR number and cancel obsolete automatic
attempts. Manual and main runs use run IDs; each requested source remains
independent. Preserving a cancelled PR's already-uploaded evidence does not make
that run complete. Source-pinned PLAY and timeout campaigns use non-cancelling
run IDs for every request. The Web demonstrator only supersedes automatic pushes.
The MAT registered groups are intentionally unchanged: the conventional
concurrency group is not a durable FIFO queue, and repeated pending requests may
be replaced. A future registered campaign must either admit a durable queue
policy or issue one request at a time. See GitHub's
[concurrency behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
and [hosted limits](https://docs.github.com/en/actions/reference/limits).

## Preparation, caching and follow-ups

Fewer GDExtension jobs reduce repeated checkout, selected LFS downloads, Python
setup, pinned Godot acquisition/import and artifact initialization. The
qualification record separates these from useful process execution. Linux
display package preparation is separately hardened against the historical
mirror failures, and repeated Windows harness controls run once per workflow
instead of once per regression shard. Assertions and every discovered fixture
still execute under the same independent evidence readers.

No cross-PR mutable build, import or shader cache is introduced. Those caches
could change the measured cold/warm state, mix runtime provenance or permit an
untrusted producer to populate a privileged consumer. A useful next cache trial
would store only hash-verified immutable engine archives and pinned godot-cpp
products, keying OS/architecture/compiler/toolchain/source inputs and rechecking
the manifest after restore. Measure hit rate and setup savings first; never
reuse application runtime evidence merely because the cache key matched.

Prioritized remaining work is (1) repair Web toolchain producer/consumer and
execute browser coverage, (2) retire or explicitly requalify the five historic
LCB publishers, (3) provide durable retention/disposition for frozen MAT inputs,
and (4) continue comparable scheduling telemetry before increasing parallelism
or introducing cache-backed setup consolidation. No source/runtime hashes,
scientific sample sizes, native physics or renderer inputs changed in this audit.

## Reproduction and local checks

```sh
python -m pip install --require-hashes -r tools/requirements-ci-audit.txt
python tools/ci/check_ci_scheduling_policy.py --output build/ci-workflow-inventory.json
python tools/ci/test_ci_scheduling_policy.py
python tools/ci/check_ci_provider_policy.py
python tools/ci/test_physical_stress_contract.py
python tools/ci/test_rapier_pair.py
python tools/ci/test_native_shards.py
```

The inventory uses a real YAML parser with duplicate-key rejection and preserves
Actions' `on` key. It reports every trigger/filter, job condition/dependency,
timeout, reusable call, workflow/job concurrency and matrix cap. Literal
Cartesian/include/exclude matrices are counted; dynamic expressions are
explicitly unresolved, and reused workflows are identified rather than counted
as one runner. Counts precede conditional admission. The policy check rejects
uncapped matrices, over-budget caps, fail-fast evidence suppression, accidental
manual cancellation and routine ref-group regressions. Actionlint independently
checks workflow syntax and expressions in the qualification record.

Local Windows validation covers source policy, inventory, stress contract and
paired readback tests. One pre-existing Native fixture wrote platform-dependent
newlines while asserting the hash of LF bytes; its test input now uses explicit
bytes, preserving the verifier's raw-byte semantics. The full hosted result and
remaining platform qualifications belong to the linked qualification record.
