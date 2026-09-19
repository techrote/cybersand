---
title: Issue 12 Phase 0 reuse audit, 2026-09-19
status: Current
document-kind: evidence
scope: Exhaustive PR 23 changed-file disposition against de332ea; retained Phase 0 control, successor boundaries and integration blockers
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../architecture/rigid-body-and-cellular-coupling.md, ../operations/architecture-programme.md, ../operations/microscenarios-programme.md]
---

# Issue 12 Phase 0 reuse audit

## Decision and exact inputs

**Dated source inspection:** retain PR #23 as the immutable Phase 0 control and
build the incremental successor from current main. Do not merge its 79-file
change wholesale or claim its observer is a scalable discovery substrate.
No implementation, dependency, runtime, experimental control or old evidence was
ported by this audit. This is the Stage 1 control-retention disposition permitted
by the [current issue #12 programme](https://github.com/techrote/cybersand/issues/12).
It does not satisfy subsequent lifecycle, discovery, acceleration or dynamics gates.

| Input | Exact identity |
|---|---|
| Current-main review baseline | `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173` |
| PR #23 Phase 0 tip | `0b96ce2a2fd5f68560575d4c4db8b0ea2f3b3758` |
| PR/current-main merge-base | `3b1747a493d6ffb01661dcf4111f1b32ae89dbac` |
| Phase 0 integrated main/#11 baseline | `f32faa93cbaaef08f7eb8cf9d5e445e9113db73c` |
| Phase 0 implementation | `185c48a4d048075540d6aabfe25ea17f143a4f67` |
| Separately accepted #11 repair | `d5f0de687283ec366ed4ff33160a274e2a35ddc6` |
| Audit branch/worktree | `codex/issue-12-incremental-foundation`; `C:/kybersand/worktrees/issue-12-incremental-foundation` |
| Preserved Phase 0 branch/worktree | `codex/issue-12-soliding`; `C:/kybersand/worktrees/issue-12-soliding` |

The worktree was clean at intake. The 79 paths below are exactly
`git diff --name-only 3b1747a 0b96ce2`, not a tip-to-tip patch that would also
remove current-main additions. Main's MicroScenario apparatus and guards must
remain present. No #26 or #27 worktree/ref/source/control is changed by this
inspection; their experiment identities remain owned by their own evidence.
Current main includes MS-000 source while concurrent work may have later state;
this document claims only the pinned baseline above.

Read inputs included workspace/source AGENTS, local development, handover,
README/index, roadmap, source recovery, documentation maintenance, canonical
ownership/coupling and programme material; the live #12 body; PR #23 body, head,
checks and scope review; retained ADR-012, audits, tests, benchmark, native owner,
World hooks, adapters and probe coordinators. Historical records are read from
`0b96ce2:path` and remain recoverable even where absent from current main.

## Material findings before reuse

1. **Main does not contain the accepted #11 repair.** All five PR-modified native
   core/adapter paths and the #11 fallback/policy/test paths still equal the PR
   merge-base at `de332ea`. Phase 0 merged #11 separately before soliding. Its
   stored-source dispatch and masked-source skip, barrier/body-aware ejection,
   persistent bearing/correction and paused-active granular support rejection
   cannot be silently imported as discovery infrastructure. Discovery can remain
   read-only and baseline-neutral without those physics changes. Any later
   support-dependent integration must reconcile this actual source/evidence gap
   and run #11 acceptance against the chosen source. Issue closure or old merged
   branch text is insufficient.
2. **Whole-file replacement regresses #27.** Current-main
   `web_demo_controller.gd` contains the shared MicroScenario host, lifecycle,
   interest, before/after-tick calls, capture and tool/save guards. The old file
   would remove them. Twelve shared documentation files also diverged. Preserve
   current routes and graft only deliberately admitted opt-in probe entry points.
3. **The observer is bounded, but repeatedly scans.** `Observer::observe` visits
   the entire registered patch plus a two-cell halo every observation: 1296
   witness cells for 32x32. Rebuild performs bounded face flood-fill and row-run
   geometry for that patch; it is not a dirty queue or resumable cross-block
   discovery. `Candidate::id` is seed+1 within a patch, not a scalable stable
   region ID. Its global mask witness safely catches ABA but invalidates rest
   for unrelated mask changes. Material-only connectivity is insufficient to
   claim state-sensitive successor components. `eligible()` also combines rest,
   support, packing and Wall/RedBrick cohesion; successor summary/stationary/
   dynamic eligibility must be separate axes.
4. **Session fences are useful, fixture ownership is not a registry.** Exact
   seven-integer tokens, nonwrapping incarnation/transition/topology counters,
   bounded tuple payload and destinations, sole-owner commit, precommit cancel
   and postcommit quarantine are reusable obligations. The private 128x128
   World, one slot, 224 tuple entries, authored Wall rectangles, event rejection,
   whole-space exclusion, diagnostic full-region census and no persistence are
   specifically Phase 0. Production worker/main-thread rendezvous, region
   split/merge and event handling require new reviewed contracts.
5. **The dynamic proof does not show free rotation or fracture.**
   `soliding_dynamic_probe.gd::shape_body` selects `BODY_MODE_RIGID_LINEAR`.
   `run` explicitly sets a quarter-turn transform before gravity/contact. It
   demonstrates Rapier translation/fall/contact and reversal of externally
   arranged quarter-turn rectangles, not off-centre torque, free angular motion
   or coherent child fragments. Declared rectangle inertia and native reversal
   energy bounds remain useful; the current programme's macro-dynamics/fracture
   requirements remain independent future gates.
6. **Cell-carrier qualifications must identify their source.** Phase 0 correctly
   identifies the inherited `detail::PrecisionStorage` carrier as eight bytes
   with default mass8/coherence12. Main uses that carrier too, while some older
   prose/comments say four bytes. This is a source/documentation discrepancy,
   not permission to change #26 controls, precision semantics or historical
   source claims. A successor correction must be dated and scope-specific.

## Exhaustive changed-file disposition

Codes: **U** = reusable unchanged; **A** = reusable only after current-main or
successor-contract adaptation; **H** = historical evidence/test only;
**O** = obsolete/conflicting for this successor and not to port. The code is the
file's primary disposition, not a claim that all its hunks share one purpose.
There is no unconditionally reusable whole runtime file at this checkpoint:
its missing dependencies or fixture-level assumptions require review/adaptation.
The exact tuple equality and integer quarter-turn bijection can be reused as
algorithms, but their containing files are A. H records remain byte-for-byte
recoverable at Phase 0; they are not rewritten as current evidence.

Blob relation: **absent** = absent from current main; **base** = main equals the
PR merge-base blob; **diverged** = main differs from both base and Phase 0.
No changed-file blob already equals the Phase 0 tip on pinned main.

| Path | Code | Main relation | Precise reuse/adaptation boundary |
|---|---|---|---|
| `.codex/agents/issue12-deputy-sol-high.toml` | O | absent | Historical orchestration profile; use active session agents/instructions. |
| `.codex/agents/issue12-reviewer-terra-high.toml` | O | absent | Historical model/effort profile, not implementation dependency. |
| `.codex/agents/issue12-reviewer-terra-max.toml` | O | absent | Historical review configuration, retained with old branch. |
| `.codex/agents/issue12-reviewer-terra-xhigh.toml` | O | absent | Historical review configuration, retained with old branch. |
| `.codex/agents/issue12-worker-high.toml` | O | absent | Historical worker profile; no successor source role. |
| `.codex/agents/issue12-worker-xhigh.toml` | O | absent | Historical worker profile; no successor source role. |
| `.codex/agents/issue12-worker.toml` | O | absent | Historical worker profile; no successor source role. |
| `.codex/agents/issue18-worker.toml` | O | absent | Other experiment's agent configuration; outside #12 substrate. |
| `.codex/agents/issue19-reviewer-terra-max.toml` | O | absent | Other experiment's review configuration; outside #12 substrate. |
| `.codex/agents/issue19-reviewer-terra-xhigh.toml` | O | absent | Other experiment's review configuration; outside #12 substrate. |
| `.codex/agents/issue19-verifier-xhigh.toml` | O | absent | Other experiment's verifier configuration; outside #12 substrate. |
| `.codex/agents/issue19-worker-high.toml` | O | absent | Other experiment's worker configuration; outside #12 substrate. |
| `.codex/agents/issue19-worker-xhigh.toml` | O | absent | Other experiment's worker configuration; outside #12 substrate. |
| `.codex/agents/issue19-worker.toml` | O | absent | Other experiment's worker configuration; outside #12 substrate. |
| `Makefile` | A | base | Reuse focused ordinary/ASan/UBSan/TSan wiring pattern only for admitted successor suites; old 130-case observer is not its acceptance. |
| `docs/README.md` | A | diverged | Add successor navigation while retaining current MicroScenario routes; no old full replacement. |
| `docs/architecture/data-ownership-and-lifetimes.md` | A | diverged | Preserve native authority/immutable MS-000 value contracts; distinguish Phase 0 private Session from proposed scalable owners. |
| `docs/architecture/rigid-body-and-cellular-coupling.md` | A | base | Carry sole-contact-owner and fenced transfer obligations; qualify unmerged #11 and isolated proof. |
| `docs/audits/2026-09-12-issue-11-reconciliation.md` | H | absent | Preserve dated #11 source/closure reconciliation; not current-main acceptance. |
| `docs/audits/2026-09-12-issue-9-10-reconciliation.md` | H | absent | Preserve dated prerequisite reconciliation; no need to port to implement discovery. |
| `docs/audits/2026-09-13-issue-11-repair.md` | H | absent | Accepted repair evidence applies to d5f0de6, not de332ea. |
| `docs/audits/2026-09-13-issue-12-integration.md` | H | absent | Preserve eleven old-main/#11 conflict resolutions and combined baseline identity. |
| `docs/audits/2026-09-13-issue-12-soliding.md` | H | absent | Preserve complete Phase 0 positives, negatives, limits and failed attempts; no updated timing labels. |
| `docs/audits/issue-12-2026-09-13/evidence.json` | H | absent | Keep all 14 artifact identities, browser/review data and six benchmark rows unchanged. |
| `docs/decisions/ADR-007-rigid-body-cellular-coupling.md` | A | base | Reuse explicit scoped exception link; ordinary ownership must not imply per-tick erase/restore. |
| `docs/decisions/ADR-011-granular-interaction-policy.md` | A | base | Old #11 repair qualification needs source-specific wording; no new cohesion policy here. |
| `docs/decisions/ADR-012-bounded-soliding-ownership.md` | H | absent | Preserve approved isolated Phase 0 contract; successor lifecycle must explicitly distinguish extensions. |
| `docs/operations/architecture-programme-prompts/cell-layout.md` | A | base | Date carrier/#11 qualification for exact current source; preserve experiment identity and scope. |
| `docs/operations/architecture-programme-prompts/compact-motion.md` | A | base | Retain independent motion gates; old #11 qualification is not current-main behavior. |
| `docs/operations/architecture-programme-prompts/decision-review.md` | A | base | Preserve staged G-final authority and qualify retained G-R evidence without closing #12. |
| `docs/operations/architecture-programme-prompts/fractional-presentation.md` | A | base | Only source-scoped qualification is reusable; no new dependency on full soliding programme. |
| `docs/operations/architecture-programme-prompts/liquid-characterization.md` | A | base | Preserve original control identity and dated carrier qualification. |
| `docs/operations/architecture-programme-prompts/soliding-supplement.md` | A | base | Rewrite future order against live #12; bounded prototype is Phase 0 and #11 is not merged into main. |
| `docs/operations/architecture-programme-prompts/sparse-motion.md` | A | base | Preserve separate energetic-motion admission; no generalized transfer from near-rest proof. |
| `docs/operations/architecture-programme-prompts/state-precision.md` | A | base | Do not reinterpret #17/#19/#26 source-matched control; retain date and source distinctions. |
| `docs/operations/architecture-programme-source-ledger.md` | A | base | Link retained Phase 0 evidence with pinned inputs, not old integrated-baseline Current claims. |
| `docs/operations/architecture-programme.md` | A | diverged | Keep current MicroScenario graph and separate scientific gates; add expanded #12 stage disposition. |
| `docs/operations/configuration-and-capacity-budgets.md` | A | diverged | Preserve MS-000 bounds; old one-slot/patch capacities are Phase 0, not scalable budget choices. |
| `docs/operations/cybersand-codex-development-handover.md` | A | diverged | Preserve current work order and add exact successor/control identities and remaining gates. |
| `docs/operations/local-build-and-validation.md` | A | diverged | Reuse focused validation concept while retaining MicroScenario harness instructions and current platforms. |
| `docs/operations/physics-characterisation.md` | A | base | #11 core fixture/run commands are reusable only against their matching coupling source. |
| `docs/operations/soliding-experiment.md` | H | absent | Retain preregistered Phase 0 screen and disposition; author successor measurement contract separately. |
| `docs/operations/source-checkpoint-and-recovery.md` | A | base | Add successor recoverable identity; never substitute old tested runtime hashes. |
| `docs/reference/architecture-programme-questions.json` | A | base | Keep old bounded G-R question as historical scope; new lifecycle/discovery questions need current destinations. |
| `docs/reference/configuration-reference.md` | A | base | Do not present old observer thresholds/capacities as measured world-scale policy. |
| `docs/reference/interfaces-and-message-contracts.md` | A | diverged | Retain current MS-000 contract; Phase 0 diagnostic token/wrapper is not production worker queue protocol. |
| `docs/reference/invariants.md` | A | base | Reuse exact owner/conservation/refusal invariants; distinguish implemented discovery from later handoff. |
| `docs/reference/level-saves-and-replay.md` | A | diverged | Preserve current controlled-scenario capture/save guards; no aggregate continuation schema exists. |
| `docs/reference/retrieval-corpus.json` | A | diverged | Retain existing corpus; route current contracts and explicitly scope/exclude historical evidence. |
| `docs/reference/retrieval-index.md` | A | diverged | Add focused successor routes without replacing MS-000 or material owners. |
| `docs/reference/status-and-roadmap.md` | A | diverged | Replace prototype-as-endpoint implication with live #12 staged programme; preserve other work. |
| `docs/reference/validation-evidence.md` | A | diverged | Append source/platform-specific successor outcomes; never overwrite Phase 0 or #27 results. |
| `docs/systems/granular-interaction-policy.md` | A | base | Keep current physical owner; old #11 acceptance is pinned repair evidence, not discovery semantics. |
| `godot/native_extension/cyber_native_cell_world.cpp` | A | base | Separate old #11 bearing/ejection/result changes from opt-in observer API; neither is needed for read-only native substrate. |
| `godot/native_extension/cyber_native_cell_world.hpp` | A | base | Split #11 observation fields/signatures from diagnostic Observer lifetime; avoid broad adapter port. |
| `godot/native_extension/cyber_soliding_session.hpp` | A | absent | Main-thread/virgin guard and integer-token pattern reusable; one-slot wrapper stays historical until runtime handoff gate. |
| `godot/native_extension/register_types.cpp` | A | base | Register a Session only if that explicitly admitted adapter is integrated and artifacts rebuilt. |
| `godot/scripts/cell_world.gd` | A | base | Entire delta is inherited fallback #11 bearing/ejection work, not soliding substrate; separate source-matched owner change. |
| `godot/scripts/interaction_policy.gd` | A | base | Inherited support stability/exclusion repair needs separate physics acceptance; do not infer cohesion. |
| `godot/scripts/physics_characterisation.gd` | A | base | Reuse #11 acceptance fixtures/metrics only with matched repair, not as a discovery performance control. |
| `godot/scripts/soliding_dynamic_probe.gd` | A | absent | Reuse confirmed-commit topology switch, RID checks and no-step gate; RIGID_LINEAR/manual quarter-turn is not macro-rotation proof. |
| `godot/scripts/soliding_probe.gd` | A | absent | Reuse exact isolated partition/excavation assertions; no production duplicate collider or granular support claim. |
| `godot/scripts/web_demo_controller.gd` | A | diverged | Only opt-in probe dispatch may be grafted later; retain every current MS-000 lifecycle/input/save guard. |
| `godot/tests/soliding_async_worker.gd` | A | absent | Owner-only observer sampling pattern reusable; current worker/MS-000 lifecycle and observation cadence require renewed tests. |
| `godot/tests/test_cell_world.gd` | A | base | Inherited #11 fallback regression changes belong with that separately reviewed repair. |
| `godot/tests/test_physics_instrumentation.gd` | A | base | Inherited #11 barrier/bearing assertions need matching adapter/source semantics. |
| `godot/tests/test_soliding.gd` | A | absent | Reuse stationary Rapier proof as a future adapter regression; not native discovery acceptance. |
| `godot/tests/test_soliding_async.gd` | A | absent | Reuse exclusive-owner test intent; proves stationary observation, not asynchronous dynamic handoff. |
| `godot/tests/test_soliding_dynamic.gd` | A | absent | Reuse backend/thread/refusal checks when Session is integrated; require fresh current-source runtime. |
| `native/bench/soliding_benchmark.cpp` | A | absent | Keep paired baseline/off/on method; replace tiny fixed patch workload with preregistered ordinary-sleep/current-main scale and churn controls. |
| `native/include/cybersand/soliding.hpp` | A | absent | Reuse face topology/exact row coverage and refusal ideas; replace full witness scan, patch-local IDs and conflated eligibility. |
| `native/include/cybersand/soliding_session.hpp` | A | absent | Reuse sole-owner phase/token/tuple obligations; one-slot private World is not scalable registry or worker protocol. |
| `native/include/cybersand/world.hpp` | A | base | Add minimal opt-in discovery witnesses independently; avoid importing Session friendship and #11 signatures without admission. |
| `native/src/world.cpp` | A | base | Separate mutation/activity/mask ABA witnesses from #11 solver delta and appended Session; local bounded discovery needs new design. |
| `native/tests/test_soliding.cpp` | A | absent | Adapt geometry, holes/seams, negative coordinates, ABA/exclusion/failure/worker-control cases to successor; old 32x32 cap tests remain Phase 0. |
| `native/tests/test_soliding_session.cpp` | A | absent | Preserve exact mapped tuple, stale/cancel/full/failed-world/quarantine tests as future handoff obligations; current metadata tests do not certify transfers. |
| `native/tests/test_world.cpp` | A | base | Inherited #11 masked-source/paused-granular regressions must accompany separately chosen physics repair. |
| `tools/physics/run.py` | A | base | Inherited #11 groups/acceptance reductions remain source-matched support tooling. |
| `tools/web/run_browser_probe.mjs` | A | base | Optional result-element selector is a reusable utility when new browser probes exist; not necessary for native-only substrate. |

## Reusable proof obligations and successor tests

The following are reusable requirements; their old passes are not new passes.

| Retained proof | Successor acceptance needed before claiming it |
|---|---|
| Face adjacency, holes, seams, diagonal separation, necks | Incremental components crossing blocks/chunks; explicit material/state keys; completed publication only, independent of traversal budget. |
| Payload/heat/state and mask ABA reset rest | Local monotonic witnesses at every relevant mutation path, including change-and-restore, support halo, body mask and region transitions; overflow refuses. |
| No observer perturbation of content hash/move counts | Current ordinary sleep versus feature-disabled and enabled successor with exact per-tick content/work comparisons, workers 1/4 where required. |
| Patch/component/member/shape saturation refuses | Bounded queue, scratch, tracked-region and continuation capacity; deferred work cannot publish partial candidates or lose dirty invalidation. |
| Same-tick/gap/excluded/failed-world earns no rest | Tick-boundary health/inclusion accounting, explicit pending events and re-entry; sleep is not cohesion. |
| Exact state/temperature quarter-turn reversal | Stage 6/7 current-source transfer tests before adopting material ownership changes; keep canonical Empty heat refusal and destination preflight. |
| Stale/duplicate ACK, incarnation ABA, cancellation | Nonwrapping scalable handles, retained IDs/generations and deterministic request/result ordering tested independently of Rapier. |
| Postcommit quarantine with both possible owners | Refusal leaves old owner valid; unexpected postcommit failure retains committed owner with both solvers/publication fenced. |
| Stationary asynchronous owner test | Current desktop immutable exchange and worker rendezvous tests; old async observer alone does not prove dynamic handoff. |
| Real Windows/two-Web Rapier cycles | Fresh artifacts, exact inputs and actual platform execution; Linux floor and publication gates must pass independently. |

Retained dynamic tests reject unsupported events, hot/blocked destinations,
energetic/nonaligned reversal and out-of-region masks. These refusals remain
valuable. They must not be deleted to make a generalized controller appear ready.
New macro-dynamics work must add actual free rotation, off-centre force/torque,
linear/angular state, coherent fracture children, loose-material disposition and
explicit momentum/energy accounting. No missing historical cellular velocity may
be reconstructed by guessing.

## Performance evidence and control choice

The Phase 0 audit reports seven rotated baseline/off/on process triplets per
idle/active fixture, 120 warmup plus 1800 samples, on Ryzen 5 2600X. Baseline was
`f32faa93`, not current main. Median per-run p95: idle baseline/off/on
0.2/0.2/57.1 microseconds; active 73.8/73.3/135.8 microseconds. Observer-only median
cost was 55.0/59.3 microseconds. This is **negative acceleration evidence** for
that small fixture: about 85% p95 overhead under activity. Preserve it.

The observer's 60872 bytes and Session's 116008 bytes exclude World heap and
Rapier resources. Instrumented zero `new/new[]` is not zero total allocation;
it excludes malloc/aligned/Godot/Rapier paths. The old benchmark has one 128-square
fixture, a 32-square observer and a forced local Sand edit, not world-scale region
coverage, amortized break-even or large active-world cost.

The successor must measure unchanged `de332ea` ordinary sleep first, then compile
and compare an opt-in disabled path and enabled incremental bookkeeping against
that control. Record source/delta/executable/compiler/fixture/profile/workers,
resident area, activity distribution, edit/churn rate, inspection work, queue and
scratch high-water/refusal, dirty-to-classified latency, candidate churn/false
invalidations, region-size distribution, memory and wake/rebuild amplification.
Substantial timings need exclusive CPU availability on the local Ryzen 2600X;
concurrent builds/test jobs invalidate an uncontended timing claim. Preserve raw
failed, negative and noisy samples. A working discovery substrate may add cost;
it is not a performance improvement until the later acceleration bake-off proves
net benefit against ordinary sleep. No intuitive size/rest threshold is admitted.

## Verified Linux and provenance blockers

Read-only GitHub checks were refreshed on 2026-09-19 for PR head `0b96ce2`.
Both retained native and Windows jobs succeeded; both Linux and consistency jobs
failed. The most recent failing logs were inspected, not inferred from labels:

- [Linux run 34769350051](https://github.com/techrote/cybersand/actions/runs/34769350051)
  reports `Unexpected Linux bundle GLIBC floor: 2.35 (expected 2.34)`;
  CyberSand extension 2.35, Rapier2D 2.34. The floor check precedes Godot runtime
  regressions, so that job does not establish Linux Godot acceptance. The
  [independent scope review](https://github.com/techrote/cybersand/pull/23#issuecomment-5652356226)
  identifies `hypot@GLIBC_2.35` and the three Session `std::hypot` sites. Its narrow
  suggested replacement is a bounded Euclidean norm based on `sqrt(x*x+y*y)`.
  This is a candidate repair, not a proven fix: rebuild with pinned Linux inputs,
  inspect imports and require the unchanged <=2.34 gate and runtime tests.
- [Consistency run 34769350077](https://github.com/techrote/cybersand/actions/runs/34769350077)
  has zero documentation errors but ten stale source-input provenance errors:
  each of Windows/Linux reports the adapter cpp/hpp, registration cpp, World hpp
  and World cpp. Its follow-on artifact upload also fails because earlier
  failure prevented retrieval output. This is distinct from Phase 0's local
  nested-worktree path failures and its 18 local repository-check errors.
- `runtime-provenance.json` and `runtime-provenance.linux.json` still describe
  #19-era artifacts on PR #23. If native/adapter changes are integrated, publish
  fresh source-matched Windows/Linux extension bytes, complete source-input
  manifests and LFS identities after final source changes; run strict materialized
  repository checks. Do not copy an artifact from another experiment, relabel
  hashes, weaken the GLIBC floor or treat a compile as runtime provenance.

The old review's recommendation to close #12 after prototype repair is superseded
by the live 2026-09-19 issue reclassification. Its ownership review and integration
failures remain valid dated evidence. Keeping the old control unmerged avoids
claiming those blockers fixed; successor publication acquires its own gates as
soon as relevant runtime inputs change.

## Audit validation and next boundary

This audit performs source/history/CI inspection only; it makes no fresh native,
Godot, Web, Linux, conservation or performance pass claim. Validation checks the
79-row path map against Git's exact change set and current blob relations, checks
no duplicate/missing rows, and runs `git diff --check` for this file. Whole
checkpoint documentation/retrieval/runtime checks remain the coordinating
implementation checkpoint's responsibility.

Next dependency-ready work is a reviewed scalable lifecycle/eligibility table
with focused metadata transition tests, followed by bounded incremental discovery
and its measurement contract. Keep cells as sole material authority throughout
that substrate. Stationary acceleration, material compaction, runtime Rapier
promotion, momentum/torque/rotation, fracture and persistence remain separately
gated. The retained Phase 0 branch provides a recoverable test/control source for
those later stages; none of its successful bounded results closes the programme.
