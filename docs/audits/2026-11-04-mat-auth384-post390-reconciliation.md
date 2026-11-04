---
title: MAT-AUTH-001 B post-390 accepted-main reconciliation
status: Current
document-kind: record
scope: Bounded PR 384 admission after the accepted worker interest-ownership fix; source preservation, hostile controls and exact-published-head Draft qualification
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [../operations/material-catalogue-shadow.md, ../architecture/material-authoring-catalogue-plan.md, 2026-11-04-mat-auth384-post377-reconciliation.md, 2026-11-04-lcb201-region-flip.md, ../reference/validation-evidence.md]
---

# MAT-AUTH-001 B post-390 accepted-main reconciliation

**Current reconciliation contract; STOP BEFORE READY.** The owner authorizes an
ancestry-preserving merge of accepted #390/main into the existing #384 branch,
the exact executable-admission update, bounded regression tests, fresh local
qualification and normal Draft hosted checks. The endpoint is open, Draft and
unmerged, with a new independent read-only admission review required. No Ready
transition, self-approval, merge, issue closure, Native exemption, authority
refresh or additional consumer/physics feature is authorized.

This record describes the source transition and its required evidence. The
[#384 ledger](https://github.com/techrote/cybersand/pull/384) and new portable
handoff identify the actual published commit/tree and executed results. Raw
logs, stage reports, hosted artifacts and final receipts remain outside tracked
source so recording them does not change the qualified head. A prior result is
never relabelled as qualification of the commit containing this document.

## Authenticated source pair and ancestry

The initial live GitHub and local Git reads agree:

| Role | Commit | Tree |
|---|---|---|
| Previous #384 open Draft head | `87418298e95def37ec86b83c543c2aa2d1d7c398` | `a594b07890022113cbcd0d78cda4943eff68a9b8` |
| Previous accepted main / initial merge base | `0103de80d11304388868f89f7b26c672ad6100ad` | `0ba07dc799afca43716bbab966f48266fa924718` |
| Accepted #390 merge / new main | `751edc0b495dc85484ad5509a7c95f863651c76b` | `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6` |
| Accepted #390 implementation | `9a9e63a0091f3a64e038892e651d0591d135241a` | `f6c022240ceb89ec31e9dd34c257e6981000a8ee` |

At intake main has no later commit. Accepted main's ordered parents are
`0103de80d11304388868f89f7b26c672ad6100ad`, then
`9a9e63a0091f3a64e038892e651d0591d135241a`. The new candidate's merge must
retain previous #384 as first parent and accepted main as second parent;
its resulting merge base with accepted main must be that accepted commit.
The isolated existing-branch checkout uses an ordinary non-squash merge.
Git merged both shared navigation documents automatically with **no conflicts**.
Their final wording preserves valid chronological information from both lanes.

The complete incoming delta is independently enumerated from Git:

| Path | Status | Treatment |
|---|---|---|
| `godot/scripts/simulation_worker.gd` | Modified | Exact accepted bytes; fixed-interest ownership fix |
| `godot/tests/lcb201_pressure_host_case.gd` | Added | Exact accepted bytes; actual host apparatus |
| `godot/tests/test_simulation_worker_interest_ownership.gd` | Added | Exact accepted bytes; ownership and quiet-pool controls |
| `docs/architecture/pressure-optimization.md` | Modified | Exact accepted explanation retained |
| `docs/architecture/simulation-tick-and-threading.md` | Modified | Exact accepted ordering contract retained |
| `docs/audits/2026-11-04-lcb201-region-flip.md` | Added | Exact original acceptance evidence retained |
| `docs/reference/retrieval-index.md` | Modified | Semantic union with current B routes |
| `docs/reference/status-and-roadmap.md` | Modified | Semantic union with current B status |

The new handoff must list the complete candidate delta against accepted main
and against previous #384, including Git blobs, byte lengths and SHA-256s.
Beyond the accepted merge, the bounded changes are B baseline/tree constants,
focused guard tests, current-source documentation and revision-sensitive
retrieval expectations. Main's migration, generated resource, original shadow
machinery, historical oracle, protected owners and earlier audits stay intact.
No unpublished/Draft #358/#347/#370/#162 source is imported.

## Exact worker preservation and separate behavioral proof

The accepted executable bytes are:

| Accepted file | Git blob | SHA-256 |
|---|---|---|
| `godot/scripts/simulation_worker.gd` | `ff5ddf9026476c52717650e747f367bb1f6bd5e5` | `6b1c27ff4e0013db58436079834ceae2c26589a752ee166462437c9aff2dbdbf` |
| `godot/tests/lcb201_pressure_host_case.gd` | `31a213fb6edeff23a403de8309e45262c75768d4` | `420ffd9afb23f7b7cd0198c4de4671e92c391f3ac170d681bb7ebd3f848f5532` |
| `godot/tests/test_simulation_worker_interest_ownership.gd` | `b422610c5119fef79ea5309e0bdd4ac00953149e` | `aaf52310f6d73fd3fb469996eea4938334b0fed96da23a888562e54b24766d2d` |

`CyberSimulationWorker.apply_world_execution_settings` skips the camera
window/region writes only when an active fixed-interest scenario owns them.
Cadence, adhesion and interest center still apply; scenario `apply_interest()`
then writes the fixed region. Non-fixed-interest operation retains normal camera
window behavior. The helper's invocation and ordering in `_worker_loop` remain
exactly accepted. No native invalidation policy or solver optimization changes.

Run both accepted tests on the new source with authenticated Godot and native
runtime inputs. Preserve mock/ownership assertions separately from real native
execution. The accepted quiet-pool control expects zero cache index rebuilds
over sixteen quiet ticks with scenario ownership versus sixteen with the old
ordering. The historical result is a reproduction target, not fresh evidence.
Any actual-host runs must disclose profile, fixture, worker count, timing
configuration, runtime identities and complete output; timings are observations,
not new optimization acceptance. Missing prerequisites must be named rather
than replacing native execution with inheritance or a static-source claim.

## Three authorities and executable admission

| Authority | Source | Rule |
|---|---|---|
| Frozen compatibility | `0fd4af5987e77db4da3e37c757cf2c0917ae9e15` | Original 27-owner raw/LF identities, lock and full catalogue/shadows remain unchanged |
| Historical display output | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`, tree `36ce5a01e754a141c321f41cac7f1c6b6059c371` | Independent original 277-case Main/CellWorld oracle remains unchanged |
| Current B executable admission | `751edc0b495dc85484ad5509a7c95f863651c76b`, tree `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6` | Exact closed native/Godot source inventory advances to accepted main |

The independently reconstructed inventories contain 661 old-main entries,
663 accepted-main entries and 662 prior-candidate entries; the reconciled
candidate contains 664. Only two executable paths are added by accepted #390,
and only the worker's existing blob changes. The candidate adds the existing
generated labels resource and retains exactly the already approved Main and
MicroScenario identity deviations relative to accepted main. Counts are measured
outputs, not an admission bypass or a rule admitting arbitrary same-count files.

The sixteen suffixes remain `.gd`, `.tscn`, `.tres`, `.godot`, `.gdshader`,
`.gdextension`, `.cfg`, `.h`, `.hh`, `.hpp`, `.hxx`, `.c`, `.cc`, `.cpp`, `.cxx`,
and `.inc`, under the unchanged `godot`/`native` roots. Test files are ordinary
executables under these rules. Preserve exact path sets, Git tree authentication,
normalized byte hashes, symlink refusal and the one-consumer transformation.
Only the two current-main identity constants and explanatory comments change
in the guard implementation; its protection logic is preserved.

The old post-#377 guard was executed before its constants changed. It refused
the two new test paths as extra executables with process exit 1. Retain that
original refusal. Fresh focused negatives must record expected/actual results
and intended diagnostics for stale baseline/tree, wrong SHA, missing/tampered/
renamed/copied tests, changed worker under old admission, additional executable,
indirect/duplicate consumer, corrupted producer/receipt/inventory, retargeted
frozen authorities and excluded-path/extension attempts. A runner that ignores a
hostile fixture is not a refusal result. Exact accepted additions and the
separate approved B delta must positively pass.

`simulation_worker.gd` was already in the narrower MicroScenario `SOURCES`
list; its changed bytes alter current apparatus fingerprints. The new tests
enter only the complete B admission inventory. The generated labels remain the
same single B resource-list addition. Old source maps and comparisons keep
their original identities and ineligibility rules. A source match never
substitutes for measurement of the actual loaded artifact.

## Fresh published-source qualification and custody

Execute compatibility and all protected-owner checks; compiler determinism;
historical edge-ID oracle; presentation validation; static consumer admission;
focused and complete material-catalogue tests; compiled native pure-query parity;
and separate GDScript shadow parity/receipt checks. Preserve the 132-slot domain,
reserved invalid10, direct names, building labels, signed/int64 fallbacks,
picker/transport boundaries and unconsumed full-shadow material semantics.

Run the established actual Godot four-stage B harness at the resulting source:

| Stage | Required observation |
|---|---|
| Legacy | Historical Main/identity and absent B resource preserve old output |
| Candidate | Reconciled actual Main and inherited Web-controller methods preserve intended output |
| Poison | Changing only generated `sand` to `SAND` makes the real consumer process fail for the intended observations |
| Rollback | Historical Main/identity/resource state and outputs are restored |

Retain all original stage reports, source maps/fingerprints, Godot/archive
identities, commands/environment, import/probe streams and exit codes, assertion
counts, source-restoration checks and hashes. Previous 5857/5861/5861/5861
assertion counts and 0/0/49/0 failures remain historical comparison data. Actual
new-source counts must be measured and any difference explained. Static parsing
or a Python simulation cannot replace actual Linux controller execution.
Compiled native parity, GDScript shadow parity, actual entire application,
browser/Wasm, Windows and rendered-pixel acceptance remain distinct scopes.

Also execute documentation/M11/repository/LFS/materialization checks, source
policy, workflow/CI policy, retrieval and whitespace/determinism gates. Frozen32
and challenge157 wording remains unchanged. Only revision-sensitive B04/05/06,
A01 and MAT-AUTH01 facts/metadata advance; their queries/routes stay unchanged.
Keep historical LCB03 and partial MAT-AUTH01 limitations unless fresh evidence
resolves them; a lexical canonical hit does not prove complete answer coverage.

Publish non-forcibly on the existing branch. Authenticate remote SHA and
complete tree, accepted-main ancestry and clean source. If publication changes
commit identity, retain preliminary receipts separately and freshly qualify the
actual published identity. Every ledger entry needs exact argv, timeout, source,
tool versions, exit code, output lengths and hashes. Preserve failed attempts.

Normal Draft Documentation/provenance and source-scope advisory require terminal
run/job/attempt metadata, every relevant step, complete raw logs and original
artifact bytes/digests. Record the actually checked-out SHA. If it is a synthetic
merge, authenticate both ordered parents and complete-tree equality with the
published candidate. An advisory with `native_skip_authorized=false` grants no
exemption. Draft-skipped Native/sanitizer/GDExtension/palette/Web and hosted
materialized-provenance work remain unexecuted, not PASS. Do not dispatch or
transition Ready to bypass these rules.

Prior packets remain immutable: the post-#377 evidence ZIP has SHA-256
`908e6b9e457fa91a5da02d7f970ae7f4677442c1d824c887c0d03601c5f98e02`;
its source is `87418298` / `0103de80`, not this new pair. The older independent
GO applies only to `c6d1603f` / `01f9b7c8`. Authenticate accessible packet members
and producer identities, retain original bytes, and state any missing evidence.

The new archive must include a manifest for every other member, all source
proofs/inventories, original local and hosted outputs, runtime/dependency
provenance and clearly labelled historical references. Its final hash, member
count and verified manifest belong to the external handoff and PR ledger.

## Independent admission and stop boundary

Recheck live main, #384 head/state and source identity before publication and
handoff. Unexpected conflicting drift or a hard qualification failure stops
completion; do not weaken source locks or carry a stale PASS to a repaired head.
Keep #353/#352/#354 and all other PRs unchanged.

The implementation owner and helpers do not issue independent admission.
A new, separate, strictly read-only reviewer must decide **GO TO READY /
CONDITIONAL / NO-GO** against the exact new source pair. Only a later separately
authorized agent may transition Ready and perform its full provenance/runtime
matrix; that future admission still is not merge authorization.

Successful owner disposition: **HANDOFF — POST-#390 RECONCILED CANDIDATE; NEW
EXACT-HEAD INDEPENDENT ADMISSION REVIEW REQUIRED**. Otherwise report the precise
blocker and actual executed/unexecuted gates, with #384 still Draft and unmerged.
