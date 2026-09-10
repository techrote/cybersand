# Architecture programme planning checkpoint

Date: 2026-09-10. Scope: source/conversation synthesis, programme, issue and prompt
authoring only. No production physics implementation, runtime rebuild, deployment,
source push or historical baseline campaign was performed.

## Deliverables and remote verification

[Master programme](../operations/architecture-programme.md) and
[source ledger](../operations/architecture-programme-source-ledger.md) were written
before the issue set. The new issues are:

| Key | Issue / title | Local prompt |
|---|---|---|
| G | [#14](https://github.com/techrote/cybersand/issues/14) Architecture decision: reconcile Cell, liquid and sparse-motion experiment evidence | [Decision review](../operations/architecture-programme-prompts/decision-review.md) |
| C | [#15](https://github.com/techrote/cybersand/issues/15) Architecture experiment: characterize FreeMass and CellularYield from retained evidence | [Characterization](../operations/architecture-programme-prompts/liquid-characterization.md) |
| L | [#16](https://github.com/techrote/cybersand/issues/16) Architecture experiment: isolate Cell layout, packing, sidecar and epoch costs | [Layout](../operations/architecture-programme-prompts/cell-layout.md) |
| P | [#17](https://github.com/techrote/cybersand/issues/17) Architecture experiment: measure liquid state precision at fixed layout and semantics | [Precision](../operations/architecture-programme-prompts/state-precision.md) |
| M | [#18](https://github.com/techrote/cybersand/issues/18) Architecture experiment: compare compact liquid flow memory inline and in sidecars | [Memory](../operations/architecture-programme-prompts/compact-motion.md) |
| V | [#19](https://github.com/techrote/cybersand/issues/19) Architecture experiment: reconstruct fractional liquid interfaces without changing simulation | [Presentation](../operations/architecture-programme-prompts/fractional-presentation.md) |
| B | [#20](https://github.com/techrote/cybersand/issues/20) Architecture experiment: gate and test bounded sparse ballistic material transfer | [Sparse motion](../operations/architecture-programme-prompts/sparse-motion.md) |

Existing #12 is reused with a [self-contained execution supplement](https://github.com/techrote/cybersand/issues/12#issuecomment-5624449535)
and [local prompt](../operations/architecture-programme-prompts/soliding-supplement.md).
Its existing issue body/status was not overwritten or reopened. The seven new
issues retain the related work's convention of no labels or milestone; no new
taxonomy was created. Full prompts are mirrored remotely and #14 also mirrors
the full master. This avoids broken unpublished-source links: the source baseline
and planning artifacts are local, while GitHub main remains older.

Native GitHub dependencies were added and read back:
`17 <- 15,16`; `18 <- 17`; `19 <- 15`; `20 <- 18`; `14 <- 19,20`.
Transitive dependencies preserve the complete programme. Gate entries in #14 can
be reviewed while that issue is open; only its final decision waits for all
admitted results/no-go dispositions. Conditional code admission and #12's staged
prerequisites are explicit in bodies because an issue-level relationship alone
cannot express them.

Open and recently closed related issues were checked before decomposition; the
post-master overlap check was repeated. A CLI argument quoting failure affected
that first repeated listing, not source evidence; it was corrected and the complete
listing read before the six experimental issues were created. #14 had already
been created from the reviewed intake/plan and was the only new item in that
corrected listing. No duplicate experiments or aggregate issue were found/created.

## Source authority and material findings

Intake source: `8f4ffb96e03dc50cb43ab9c84de17ccb44c03774` on
`codex/water-sideways-leveling`; planning branch `codex/architecture-programme`.
The only pre-existing tracked delta was the Windows native DLL, SHA-256
`fc6cb4ee1096219f581bace3df04ee8138e996aaf4c1436f5b2c071ea62dd496`.
Final verification found the same bytes. Companion workspace remains clean.
Remote main at intake was `ab4851e9e6a3ee182aba1a31a8f66d135e87df3a`.

All textual turns of R/W/B were read in sequence, including their shared opening
and later refinements. I's task-reader response truncated at 20,000 characters;
the owner supplied the complete continuation from section 13 through section 30
and Recommended direction. It was incorporated before programme and issue
authoring. The underlying external documents/footage and their web sources were
not retrieved. W's omitted images were not needed to recover the explicit
textual directionality refinement; no claim about unseen pixels was made.

The synthesis preserves ADR-007, separates occupancy from persistent state,
uses current three-quarter Water relaxation, and corrects the epoch-period
approximation using zero-reserved source semantics (first wrap 256/64, repeated
255/63). It distinguishes #13's temporary no-velocity scope from an ADR and
W's proposed conservation flexibility from the still-accepted exact baseline.
I's sparse-before-coherent recommendation is conditional, not an adopted ladder.

One real conflict remains: #11 is closed as completed without linked evidence,
but the local source and retained audits still describe pending bearing,
masked-source feedback and barrier-aware ejection work. #12 support-dependent
integration is held behind a source/evidence gate. This did not prevent clean
decomposition of the independent layout/liquid/presentation experiments; it
must not be hidden by administrative issue status.

## Verification executed for this planning change

Raw directory: `C:/kybersand/validation/local/2026-09-10-architecture-programme/`.
Python: pinned workspace 3.12.14; Windows host, PowerShell and existing GitHub CLI.
Commands ran from `C:/kybersand/source`; ordinary command tool timeout/yield 10s,
all these checks completed without a long-running execution or timeout. Exact
GitHub payloads/readbacks, commands in helper scripts, failed attempts, JSON/log
results and prompt/issue verification are retained there. Credentials were used
through the existing Git credential manager without writing tokens to artifacts.

| Check | Outcome |
|---|---|
| `tools/ci/check_docs.py --json <raw>/docs.json` | Pass: 56 selected documents, 97 canonical claims, 913 local links at the final checkpoint. No missing metadata, local link or authority-key error. |
| `tools/ci/check_m11_consistency.py --json <raw>/m11.json` | Pass, historical integrity only. No current runtime claim and no rewritten hashes. |
| `tools/ci/check_repository.py --json <raw>/repository.json` | Fail: 16 inherited published-provenance/LFS mismatches. Full error list equals the retained Water-follow-up report exactly. This task introduces no new repository failure. |
| `tools/docs/retrieval_eval.py --output <raw>/retrieval-final.json` | Frozen 32: 23 top 1, 32 top 5, MRR 0.8385; unchanged wording and same final scores as prior Water checkpoint. |
| Same evaluator with `--queries docs/reference/retrieval-challenges.json` | Existing 16 challenges: 12 top 1, 16 top 5, MRR 0.8562. |
| Same evaluator with `--queries docs/reference/architecture-programme-questions.json` | New 5 programme questions: 3 top 1, 5 top 5, MRR 0.8. Separate development questions, not unseen test evidence. |
| `verify-plan.py` in raw directory | Pass: exact issue-body equality for seven issues and #12 comment; all seven native dependency edges match; eight prompts each contain 17 required top-level sections covering the request's content; 60 new local links checked; no pending issue placeholders; DLL unchanged. |
| `git diff --check` and changed-source path review | Pass; task changes are documentation only. Existing dirty DLL remains outside the planning commit. |

Initial new retrieval evaluation found only 3/5 canonical top-five routes. Two
focused programme headings clarified occupancy/conservation authority and the
closed-#11 evidence conflict; final evaluation reaches 5/5. Both iterations are
retained. This is disclosed development-set maintenance, not a general retrieval
improvement claim. Manual review of the returned programme/ADR contexts confirms
status, scope and conditional gates; ranking alone is not answer sufficiency.

No native/Godot/browser physics suite was rerun for this documentation-only task.
The master instead names the required focused future comparisons and retained
#9/#10/#13/Water acceptance evidence. Existing 16 provenance failures remain a
publication limitation, not a reason to rebuild runtimes in this planning task.

## Manual final quality review

| User quality items | Review result and location |
|---|---|
| 1–3:all four trajectories, later conclusions, uncertainty | Source-ledger conversation table and claim rows recover every turn and I sections 1–30; provisional preferences, supersession and missing-data limits are explicit. |
| 4–7:Current/ADR/issue-scope/occupancy authority | Master A/B, ledger and every prompt preserve accepted ownership and distinguish temporary restrictions and material state. |
| 8–10:no underlying external-source reanalysis or mandatory ladder/ballistics/bodies | Only recovered I analysis used; B conditional admission; #12 reused; no D0–D5 feature backlog. |
| 11–15:no velocity/unification/width assumption; isolate layout and precision | Master C–E and L/P/M prompts use explicit intermediate controls and neutral acceptance. |
| 16–18:independent geometry, liquid characterization, conservation/baselines | Master A/D/F/G, C/L/P prompts and versioned-current Water references. |
| 19–22:cross-dependencies, reused evidence, gates, negative/ambiguous results | Master E/H/I; native issue edges; no repeated audit; no-go is successful completion. |
| 23–26:master first, no duplicates, self-contained prompts, conditional downstream | Master preceded creation; overlap inventory and #12 supplement; eight prompts mirrored remotely; B and R admission gates. |
| 27–30:bounded/deterministic ownership, no production edits, independent execution, one programme | Every prompt and master G–K; scope/hash verification; one master/decision owner and shared retained baselines. |

The programme does not recommend a final Cell width, liquid solver, universal
motion field or representation ladder. It supplies a controlled way to decide.
