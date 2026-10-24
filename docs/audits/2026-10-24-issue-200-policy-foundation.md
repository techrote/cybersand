---
title: LCB-001 #200 policy foundation evidence
status: Current
document-kind: evidence
scope: Author evidence packet for the bounded #200 liquid solver policy foundation — source identities, executed native/Godot/CI results, contract reconciliation and explicit gaps; no solver, defaults or schema/ABI change
canonical-for: [issue-200-policy-foundation-evidence]
last-reviewed: 2026-10-24
related-documents: [../architecture/liquid-solver-family-policy.md, ../reference/status-and-roadmap.md, ../reference/liquid-policy-wire-vectors.json]
---

# LCB-001 #200 policy foundation evidence — 2026-10-24

## Authority and scope

On 2026-10-24 the owner lifted the #200 hold **for this bounded foundation only**:
immutable, versioned per-World/per-material policy validation and canonical
identity, effective native readback and a bounded construction/adapter path. The
pressure backend, #212, every other solver port, C64-E8 changes, spare-bit
assignment, speculative solver payloads, durable schema/ABI freeze, default changes
and Rapier forces remain outside it. All 90 candidate arms stay blocked. The #204
experiment task was neither awaited nor consumed. Contracts consumed: the
[family policy](../architecture/liquid-solver-family-policy.md), the
[state-transition matrix](../architecture/liquid-state-transition-matrix.md) and the
[implementation handoff](../architecture/lcb-pressure-inertial-handoff.md), as
accepted at the #213 closure.

## Source identity

| Item | Value |
|---|---|
| Base | main `1002b9201006b572180a12cbc4c3b21fc234e8fa` (merge of #237), fetched fresh |
| Worktree / branch | isolated `.claude/worktrees/issue-200-policy-foundation`, `claude/issue-200-policy-foundation` |
| Implementation commit | `457ab64449f2715c60ab6318739655cbc40b42df` |
| Landed | [#239](https://github.com/techrote/cybersand/pull/239) merged 2026-10-24 07:01:19Z as `1e032e492cafb232e604baf6e2b823b13d779aa8`; tree `4519bb25…` equals reviewed head `cc01899` |
| Primary checkout | `mat/material-fidelity-pass-2` with unrelated uncommitted changes; untouched |
| Generated identity | `catalogue_digest` `82b5ab9a…fdbad3`, `capability_matrix_digest` `d31e434b…fc4e45` (full values in the generated header and vector file) |

Later commits on the branch (runtime publication, documentation) are listed in
[CI and publication](#ci-and-publication).

## Audit result (construction, validation, dispatch, readback)

| Path | Before | After |
|---|---|---|
| `WorldConfig` / `World::World` | Water and transport policies validated; no liquid policy | `liquid_solver_policy` admitted by re-validating its normalized envelope against the running build before World-owned storage is allocated; `LiquidPolicyRefused` otherwise |
| Dispatch | `RuleKernel` switch; family implied by descriptor | Unchanged. No family dispatch exists, and unqualified mappings cannot reach a World |
| C API | No policy | Experimental default/validate/create/readback/hash functions |
| `CyberDemoBridge` constructors | Copied the live config | Explicit defaults in `build_world`, `build_tuned_world`, `build_water_feel_world` and CYSD1 `import_level`; `build_liquid_policy_world` takes a request |
| `CyberNativeCellWorld` | Water readback only | `get_liquid_solver_policy()` receipt plus committed-session generation; `reset_demo_world` uses explicit defaults |
| MicroScenario host / desktop worker | No request | Optional `liquid_policy` (null keeps defaults); worker forwards the native receipt in `lab_context` |

Routine choices made within the contract:

- the decoder is build-parametric, so contract-test builds replay the vectors;
- detail strings match the oracle;
- `session_generation` counts committed World replacements;
- the native receipt omits `source_revision`/`native_binary_sha256`, which are host identity.

**Contract defect reconciled.** The oracle's `today` build qualified per family
and would have admitted Water × `cellular_yield_v1`, a mapping with no
implementation. The oracle now qualifies per material × family cell. The appended
vector `water_cellular_yield_today` expects `family_unavailable`. All 46 earlier
cases, the session transcript and the build identity were compared before and
after: no change.

## Executed native validation (Windows, local)

Host: Windows 11 Pro 10.0.26300 x64; MSVC 19.38.33145 (VS 2022 Build Tools 17.14);
`/std:c++20 /EHsc /W4 /Od /Zi`; the same six core sources as
`build_windows_msvc.bat`; tests run from the worktree root. No explicit timeout;
durations measured.

| Build | Tests | Result | Duration | `tests.exe` SHA-256 |
|---|---|---|---|---|
| Baseline main `1002b92` | `test_world.cpp` | **84/84 passed** | 121.2 s | `97c1076e…a4db3b` |
| Candidate `457ab64` | `test_world.cpp` + `test_liquid_solver_policy.cpp` | **93/93 passed** | 136.5 s | `5f775727…4fec1e8` |

Build warnings: the five pre-existing MSVC warnings only; none in new code.

The nine new tests:

1. **SHA-256** — NIST answers, including one million `a`.
2. **Identity** — the embedded catalogue and capability digests equal SHA-256
   recomputed from the LF-normalized source files and the matrix JSON at run time.
3. **Descriptors** — the catalogue's eleven liquids and default families equal
   `MaterialRules` (state/`LateralFlowMode`).
4. **Wire vectors** — all **47** oracle vectors (11 accepted, 36 refused). Exact
   acceptance, refusal code, material, detail, `policy_hash`, canonical bytes and
   normalized envelope; normalized round trip; int32 transport equivalence.
5. **Session transcript** — the generation and readback hash after each step.
6. **Running-build sweep** — all 121 non-default material × family × variant cells
   are refused with the matrix-predicted code; explicit, all-code-0 and implicit
   defaults are identical. Water × CY gives the exact `family_unavailable` detail.
7. **World admission** — a Water-inertial policy that a contract build accepted
   is refused by `World::World` (`family_unavailable`, material 3).
8. **Default behaviour** — a mixed fixture (Water, Oil, Brine, Sand, Mercury, Lava,
   Salt) runs 160 ticks. An implicit-default World, an explicit-decoded-default
   World and an explicit-default **four-worker** World keep identical
   `state_hash`/`content_hash` every tick. Water mass3/coherence0 does not change
   the policy hash.
9. **C API transaction** — size queries, default/validate, create success, and
   stale/rejected/truncated/invalid-config refusals with an untouched existing
   World, readback words/hash, an independent second World, and the
   undersized-struct guard.

Python contract checks (Python 3.12.10, each under one second):

| Command | Result |
|---|---|
| `policy_contract.py --check` | PASS |
| `test_policy_contract.py` | **15/15** |
| `derive_capability_matrix.py --check` | PASS |
| `native_policy_artifacts.py --check` | PASS |
| `test_lcb001_runtime_publication.py` | **17/17** |
| `check_ci_provider_policy.py` | PASS |

## Godot validation

The local Godot 4.7 console executable
(SHA-256 `d8055fb8…c34161c`) imported the worktree project. It parse-checked
`test_liquid_solver_policy.gd`, `microscenario_host.gd` and `simulation_worker.gd`
(exit 0) against the then-committed, pre-change runtime. That is a parse check,
not execution. No local godot-cpp toolchain exists, so the GDExtension is built
and executed only by GitHub-hosted CI (below).

`test_liquid_solver_policy.gd` covers, through the real adapter and MicroScenario
host on the protected `lcb.dam.water.freemass.reference.v1` definition:

- the validation receipt and code-0 normalization;
- the installed readback;
- 12 refusals (NC-1, NC-2 and the other matrix classes, stale digest, truncated
  and empty envelopes, and a non-packed type). Each must keep tick, state/content
  hash, Water integer, definition hash, receipt and generation;
- continuation after the refusals and an independent second World;
- implicit-versus-explicit-default and four-worker Dam Break hash parity at five
  checkpoints over 40 ticks;
- CYSD1 export/import on defaults (NC-10) and a refused corrupt import.

## CI and publication

**Branch commits:**

| Commit | Content |
|---|---|
| `457ab64` | Implementation |
| `0235c91` | Documentation |
| `04bd222` | GLIBCXX fix |
| `059e316` | Publisher bot runtime commit |

**Failed first publication.** [Run 40053166064](https://github.com/techrote/cybersand/actions/runs/40053166064)
built `457ab64`. Windows built and passed every case, but the Linux job failed
`tools/check_linux_runtime_floor.sh` with "Unexpected CyberSand GLIBCXX
requirement: 3.4.31 (expected 3.4.30)". Nothing was published. Cause: GCC 13
inlines `literal + std::string&&` as a front insertion that imports
`basic_string::_M_replace_cold@GLIBCXX_3.4.31`. Fix `04bd222` assembles refusal
text append-only. The detail strings are byte-identical: the local candidate
rebuilt at `04bd222` passed **93/93** native tests in 127.5 s
(`tests.exe` `d00f3bf8…d38caa6`).

**Passing publication.** [Run 40054064436](https://github.com/techrote/cybersand/actions/runs/40054064436)
built `04bd222` on GitHub-hosted runners:

- toolchains: Ubuntu 24.04 g++-13 and LLVM-MinGW 20260826 UCRT;
- godot-cpp `101ae380`, SCons 4.10.1;
- execution: Windows on `windows-2022`, Linux on Ubuntu 24.04, both with the
  pinned Godot 4.7 and Rapier.

Both passed the runtime floor, import and all eight focused cases. Then the
publisher fast-forwarded `059e316`, which changes only the four runtime and
provenance paths.

| Platform | Runtime SHA-256 | Size | Validation report SHA-256 |
|---|---|---|---|
| Windows x86_64 | `b8ec750e12fad191f73d864a76428a10b540945659640e9b226c9a2c1bac06fb` | 4,049,408 | `be4e1f542ab289d6…` |
| Linux x86_64 | `2495cedc12de07be3738a76b41ea352e5dff8309d167ea89f7fc430ae89765cf` | 3,525,584 | `3d49bfd8aaac4902…` |

Identical summaries on both OSes:

| Case | Result |
|---|---|
| `LIQUID_SOLVER_POLICY` | **236/0**; all five helper sections, 12 refusals, 5 parity checkpoints |
| `MICROSCENARIOS` | **8855/0** |
| `MICROSCENARIO_CONTROLLERS` | **55/0** |
| LCB physics | **174/0** (unchanged from the landed baseline) |
| LCB negative | **74/0** (unchanged) |
| LCB manifests | **26/0** (unchanged) |
| LCB catalogue | **774/0**, 27 scenarios |
| `WATER_FEEL_INTEGRATION` | 24 policy cases + 70 scenario builds, `default_hash=7c40afe52c6e0e37` |

**Local exact-runtime execution.** The published Windows DLL (verified SHA-256
above) ran under local Godot 4.7 on Windows 11:

| Case | Result | Time |
|---|---|---|
| `test_liquid_solver_policy` | **236/0** | 5 s |
| `test_lcb_negative_contracts` | **74/0** | 4 s |
| `test_microscenarios` | **8855/0** | 104 s |

**Provenance.** At `059e316`, `python tools/ci/check_repository.py
--require-materialized` reported 18 runtime files materialized, none
unmaterialized, and no provenance error. The only errors were the six
companion-workspace expected-fact paths that Documentation CI supplies from the
pinned companion commit `6a583119`. `check_docs.py` passes under that companion
layout.

| Check | Result |
|---|---|
| `check_m11_consistency.py` | PASS |
| Frozen 32-question retrieval | unchanged: 21/32 at 1, 32/32 at 5, MRR 0.7953 |
| 117 supplementary challenges | 94/117 at 1, 117/117 at 5, MRR 0.8849 (LCB02 rank 1) |

**Failed first ready-PR Native run.** Ready-for-review head `a035133` ran
Native [run 40055347840](https://github.com/techrote/cybersand/actions/runs/40055347840).
The UBSan step stopped at `native/src/c_api.cpp:67`: "null pointer passed as
argument 2". `fill_liquid_refusal` passed an empty `std::string_view` (null data)
to `memcpy` on the accepted path. MSVC did not detect it. The fix guards
zero-length copies, and the C API test now also requires an accepted request to
clear a stale detail. Because `c_api.cpp` is a provenance-bound runtime input,
both runtimes were republished from the fixed source `c86a34c`.

**Republication.** [Run 40056996111](https://github.com/techrote/cybersand/actions/runs/40056996111)
passed the floor, import and the same eight cases on both OSes, with summaries
identical to run 40054064436. It then fast-forwarded `3510642`.

| Platform | Runtime SHA-256 | Size | Validation report SHA-256 |
|---|---|---|---|
| Windows x86_64 | `2d4e92d56566fa40306c5c1a7a4f1e39996c310000466aceb784de88c0abeab9` | 4,049,408 | `5bac2413c0bb140b…` |
| Linux x86_64 | `2495cedc12de07be3738a76b41ea352e5dff8309d167ea89f7fc430ae89765cf` (unchanged) | 3,525,584 | `841213a282f580c1…` |

These supersede the first-publication hashes above for the current head. GitHub
starts no workflows for the publisher's `GITHUB_TOKEN` push, so this record is the
author commit that triggers the exact-head gates on top of the published runtimes.

The exact-head Documentation, Native and GDExtension/Godot gates for the
ready-for-review head are recorded in the PR evidence comment, not here, so that
recording them does not change the head.

## Independent review follow-up

**Astra** found no defects. Astra's threaded worker probe passed 15/0 and covers
the previously untested worker `liquid_policy` forward.

**Luna** found no blockers. Each finding was addressed:

| Finding | Response |
|---|---|
| Should-fix: `cybersand_default_config_v2` could let `std::bad_alloc` escape the C ABI (default `WorldConfig` copies the policy) | Now wrapped; an allocation failure returns an all-zero config (`struct_size` 0), which every v2 consumer refuses. Documented in `c_api.h` |
| Should-fix: material authors had no regeneration route | New [regeneration sequence](../architecture/liquid-solver-family-policy.md#regenerating-identity-after-a-material-or-rule-edit), linked from the building-material and materials/rule-kernels guides |
| Nit: "before any World allocation" was too broad | Now "before any World-owned storage is allocated", in source and docs |
| Nit: constructor inventory | Now lists the default C API constructors and the `demo::` helpers |
| Question: fallback host versus oracle | Documented as a deliberate difference: there is no fallback decoder, so the host refuses even an explicit default |

The `c_api.h`, `c_api.cpp` and `world.cpp` changes in `c8f14c7` are runtime
source inputs, so both runtimes were republished again. Local MSVC run: 93/93 in
120 s (`tests.exe` `92ad46da…121ff61d`).

[Run 40066828015](https://github.com/techrote/cybersand/actions/runs/40066828015)
passed the floor, import and the same eight cases on both OSes, with summaries
identical to the earlier publications. It fast-forwarded `a309c44`. These
identities supersede both earlier tables:

| Platform | Runtime SHA-256 | Size | Validation report SHA-256 |
|---|---|---|---|
| Windows x86_64 | `b13805bf1a0bb3452493c6990b212575787f638c30be22613a5cc03b78933d30` | 4,049,408 | `145449114aecef27…` |
| Linux x86_64 | `2495cedc12de07be3738a76b41ea352e5dff8309d167ea89f7fc430ae89765cf` (unchanged) | 3,525,584 | `c90303c78593613c…` |

## Follow-up regressions (stacked on #239)

Branch `claude/issue-200-foundation-followups` closes the two remaining test
gaps. It was first stacked on #239 head `cc01899`, then rebased onto landed main
`1e032e4`. Neither file is a runtime source input, so
the published runtimes and their provenance are unchanged.

**Threaded worker forwarding.**
[`test_liquid_policy_worker.gd`](../../godot/tests/test_liquid_policy_worker.gd)
drives the real threaded `CyberSimulationWorker` (`start_worker`, `queue_lab`,
`take_latest_snapshot`) on the protected Dam Break definition. It covers:

- the initial receipt;
- an explicit default request forwarded through `scenario_reset.liquid_policy`
  and read back normalized with a new generation;
- consumer mutation of a published receipt that never reaches a later snapshot;
- three refusals (Water × pressure, Oil × inertial, a non-packed request), each
  with the request unapplied, a visible status, and an unchanged receipt,
  generation and MicroScenario;
- the code-0 request and the no-request path, each committing a refreshed
  receipt.

Local result with the published Windows DLL: **29/0** in 2 s.
Mutation check: making the worker drop `liquid_policy` gives **10 failures**.

**C API allocation fault injection.** `test_liquid_policy_c_api_allocation_failures`
(in `test_liquid_solver_policy.cpp`) replaces `operator new` with a thread-local
probe, following `test_generation_fields.cpp`. It fails the 0th, 1st, …
allocation in turn until a run completes, for each entry point:

| Entry point | Required outcome on every injected failure |
|---|---|
| `cybersand_default_config_v2` | An all-zero config, refused by `cybersand_world_create_v2` |
| `cybersand_liquid_policy_validate_v1` | `CONSTRUCTION_FAILED` |
| `cybersand_world_create_with_liquid_policy_v1` | No World, and `CONSTRUCTION_FAILED` |
| `cybersand_world_liquid_policy_v1` | `CYBERSAND_SIZE_ERROR` |

Local MSVC result: 10/10 LCB-001 tests. Mutation check: removing the `try`/`catch`
from `cybersand_default_config_v2` fails the test with an escaping
`bad allocation`.

The first ready-PR Native run on #240,
[40075499009](https://github.com/techrote/cybersand/actions/runs/40075499009),
failed in GCC's plain behavioural suite with "default config changed after
failures". The defect was in the test, not the C API: it compared
`cybersand_config_v2` values with `memcmp`. The struct has unspecified padding at
bytes 36–40 and 92–96, which MSVC happened to leave equal. The test now compares
field by field; locally 94/94 in 131 s.

**Publisher decision.** `lcb001-runtime-publication.yml` is retained, as the
GEN-005 and GEN-007 publishers were. Its jobs run only for
`refs/heads/claude/issue-200-policy-foundation`. That branch still exists at
`cc01899` after the merge, and nothing further is pushed to it; the workflow
becomes fully inert once the branch is deleted. Removing it would gain nothing but
churn.

**Post-merge reconciliation.** #239 merged on 2026-10-24 at 07:01:19Z as
`1e032e492cafb232e604baf6e2b823b13d779aa8`. Its tree `4519bb25…` equals reviewed
head `cc01899`. Post-merge push runs at that commit, first attempt each:

| Workflow | Run | Result |
|---|---|---|
| Native C++ validation | [40072499987](https://github.com/techrote/cybersand/actions/runs/40072499987) | success: `native`, 93 tests in the plain, ASan+UBSan and TSan builds |
| GDExtension/Godot | [40072499990](https://github.com/techrote/cybersand/actions/runs/40072499990) | success: Linux build, shards 0–3 and aggregate; Windows build and headless regression |
| Documentation and provenance | [40072499986](https://github.com/techrote/cybersand/actions/runs/40072499986) | success: `consistency` |
| Issue 49 Water apparatus v2 | [40072499994](https://github.com/techrote/cybersand/actions/runs/40072499994) | success: `apparatus` |

The roadmap now records the foundation as Current on main.

## Explicit gaps

- Not implemented:
  - the run receipt hash;
  - normalization and `normalization_required` (NC-3 stays blocked);
  - `water_semantics_incompatible` and `capacity_refused` (unreachable with
    defaults);
  - a versioned physical-state hash (no family state exists);
  - the remaining #202 constructors (generation previews, depth/exhibition
    planes, physical arenas, player modes, Web controller, Water reset), which
    run defaults without a request;
  - a GDScript fallback decoder.
- Two Worlds with *different* applied policies cannot coexist yet, because only
  defaults are admitted. Independence is shown by separate receipts, generations
  and refusal isolation.
- The threaded worker forward and the C API allocation-failure paths are no
  longer gaps; the [follow-up regressions](#follow-up-regressions-stacked-on-239)
  cover them.
- Web/WASM is not built or run. The policy code is the same source; Web execution
  remains unverified.
- `source_revision`/`native_binary_sha256` are not in the native receipt.
- No candidate arm, pressure/inertial/W-CY kernel, Rapier force, Cell/schema
  change or default change was made or executed.

Issue-state correction (2026-10-24): GitHub automatically closed #200 at
07:01:20Z when #239 merged, because it parsed the PR body's negated phrase "does
not close #200" as a closing directive. Later inspection identified this
premature transition, and #200 was reopened on 2026-10-24 with an explanatory
comment. That automatic transition supplies no completion evidence. The gaps
above were the open #200 scope at this checkpoint; the subsequent pressure
reference, which adds a versioned physical-state hash and an experimental
run-receipt hash, is recorded separately in the
[pressure reference evidence](2026-10-24-lcb001-pressure-reference-publication.md).
