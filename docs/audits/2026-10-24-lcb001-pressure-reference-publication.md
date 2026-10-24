---
title: LCB-001 pressure_flow_v1 reference — implementation and publication evidence
status: Current
document-kind: evidence
scope: Dated evidence for the #200 pressure_flow_v1/reference implementation on claude/lcb001-pressure-reference — source identities, toolchains, commands, native and Godot results, mutation checks, characterization, failed attempts and corrections, runtime publication and remaining gaps
canonical-for: [lcb001-pressure-reference-evidence]
last-reviewed: 2026-10-24
related-documents: [../architecture/pressure-flow-v1.md, 2026-10-24-issue-200-policy-foundation.md, ../architecture/lcb-pressure-inertial-handoff.md]
---

# LCB-001 pressure_flow_v1 reference — implementation and publication evidence

## Identity

| Item | Value |
|---|---|
| Base | `origin/main` `3e9f0e6dcbfdb9c122c8c555dac43e7b4d926e5f` (PR #243) |
| Branch | `claude/lcb001-pressure-reference` |
| Publisher preparation | PR #244's eight commits (`da97e5b`…`97232e4`) cherry-picked unchanged, ending at `9961759` (21 publisher unit tests pass) |
| Native implementation | `db256f8` (native pressure family), `4a5652a` (GDExtension, regressions) |
| Owner authority | 2026-10-24 owner instruction authorizing the bounded LCB implementation, including the previously held pressure reference and inertial work; no default change, no generic #12 Stage 4, no carrier migration |
| Issue state | #200 had been auto-closed at 07:01:20Z by the #239 merge (negated "does not close" parsed as a keyword); reopened 2026-10-24 with an explanatory comment |

Runtime identities for the published Linux/Windows libraries are recorded in
[Runtime publication](#runtime-publication) when the scoped publisher runs.

## What was implemented

See the canonical [pressure_flow_v1 design](../architecture/pressure-flow-v1.md).
In brief: running-build admission of Water × `pressure_flow_v1/reference` only;
solver-owned per-cell sidecars; a serial gas-topology pass with label-overlap
identity and exact ledgers; an immutable head snapshot with lid interpolation and
state-only remote wake; the phased kernel; the versioned physical-state hash; CYPS
v1 persistence; GDExtension inspection, receipt and persistence bridge.

## Local validation (2026-10-24, Windows 11 Pro 10.0.26300 x86_64)

Tools: GCC 16.2.0 (MSYS2 UCRT64) for native tests and the harness; the pinned
LLVM-MinGW 20260826 (Clang 23.1.0, UCRT; Windows-host zip `ae601f4e…06c3`,
checked against the release API digest) with godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496` (archive `f55d1cd5…dad8`, ledger
`8a2fb6cd…`) and SCons 4.10.1 for a **local, non-release** GDExtension; Godot
`4.7.stable.official.5b4e0cb0f` headless. The local DLL is not a published
runtime and its hash is not a release identity (`mktemp` partial names make
builds non-bit-reproducible, as for the repository's own builds).

| Check | Command | Result |
|---|---|---|
| Native suite | `g++ -std=c++20 -O1 … test_world.cpp test_liquid_solver_policy.cpp test_lcb_pressure.cpp && ./tests` | **107/107 pass** (13 new `LCB-001 pressure` cases) |
| LCB tool tests | `python -m unittest discover -s tools/lcb -p "test_*.py"` | 120 pass |
| Policy artifacts | `derive_capability_matrix.py --check`, `policy_contract.py --check`, `native_policy_artifacts.py --check` | match; 47 vector cases, **no acceptance/refusal/detail change** (identity words only) |
| Publisher unit tests | `python -m unittest discover -s tools/ci -p test_lcb001_pressure_reference_runtime_publication.py` | 21 pass |
| Candidate regression | `test_lcb_pressure_reference.gd` (local DLL `89d984f1…eeb37`) | `LCB_PRESSURE_REFERENCE: 1932 assertions; 0 failures`, all 12 sections true, 23 s; log has no `ERROR:`/skip text |
| Publisher controls | the eight control cases plus `test_liquid_policy_worker.gd` | all pass after the two stale-assumption fixes below |

### Mutation checks (native, scratch copies)

| Mutation | Detected by |
|---|---|
| split remainder to the last region | `gas split` (110/112) |
| `move_cell` without the sidecar swap | `quantity, motion and worker parity` (t1) |
| merge amount from volume instead of the sum | `gas unequal merge` (220) |
| gas table omitted from the physical hash | `physical hash and exact persistence` (gas-only change) |
| outgoing flux keeps the stale stored velocity | `quantity, motion and worker parity` (front) |
| radius-2 sample through a closed face | `walls and body masks block head` — **initially undetected**; the test then gained a resting barrier-side pool check and now fails the mutation |

## Characterization (screens, not admission)

Retained original pre-repair characterization (source through `a5b5322`):
`native/bench/lcb_pressure_characterisation.cpp`, registered geometries rebuilt
from the scenario definitions, 1 worker, quantity checked every 50 ticks. The
harness reproduces the registered Current controls exactly (fronts 67/70/71,
retained 0.839/0.841/0.851, two-limb difference 120).

| Screen | Threshold | Current | pressure reference |
|---|---|---|---|
| depth response t240 | ≥ 1.5 | 1.06 | 1.68 |
| depth-48/96/160 front t240 | depth-160 ≥ 213 | 67/70/71 | 130/220/219 |
| depth-48/96/160 retained t1800 | depth-160 ≤ 0.50 | 0.839/0.841/0.851 | 0.619/0.435/0.369 |
| vented two-limb difference | ≤ 12 rows at t2400 | 120 | 100 (t300), 64 (t600), 0 (t1200), −7 (t2400); ≤ 12 from t1038 |
| narrow passage | ≤ 60 rows at t2400 | 120 | 42 |
| sealed two-limb | ±2 rows of the isothermal law | 120 (no motion) | difference 29 at t2400; gas exact (1152, 6912; ids 1, 2); 4.9 rows from the law, still settling |

## Failed attempts and corrections (retained)

1. **Water-born voids became atmospheric gas.** First sealed-headspace run:
   compartment ids churned to ~19 000 and the left headspace grew from 1152 to
   1450. Cause: an Empty region with no prior label was always created at
   atmospheric amount, including voids opened inside Water. Fix: kernel-vacated
   cells carry `kVacuumLabel`; a vacuum-only region is not a compartment.
2. **Overfill accumulated in lidded passages.** Left limb fell 65 rows while the
   right rose 25 (≈1 900 cells hidden as overfill). Cause: overfill relayed up a
   saturated column by halves (diffusive). Fix: whole-column relay with the
   receiver not epoch-marked.
3. **Overfill compressibility (1 row per unit) rejected.** It stopped passage
   flow (two-limb difference stuck at 111). Retained as the declared parameter
   `kOverfillStiffnessRows = 0`.
4. **Interior voids from lateral flux.** A saturated source could empty into a
   neighbour's overfill. Fix: a source with Water directly above keeps one unit.
5. **Gain/damping sweep.** Damping 250/256 with gain 24 saturated the face:
   fronts 158/162/164, response 1.04. Swept gains 1–24 and retains 254–256 plus
   constant friction 1–2: friction slowed the passage (two-limb 11–33 rows at
   t4000); gain 3 without damping met every dam screen. The chosen values are
   Proposed, not frozen.
6. **Fixture-driven gas parameters.** With p_atm = 128 rows and a 30/255 start
   band, the registered split's integer remainder (110/108 vs 112/111) produced a
   1.2-row gauge difference that would move the U-trap and change the registered
   volumes. p_atm = 32 and a 128/255 start band keep it exactly at rest; the
   surface skin keeps resting surfaces flat despite the larger band.
7. **Persistence volume check.** Restore first required each compartment volume
   to equal its labelled-cell count; kernels move labels after tick entry, so the
   check was wrong and was replaced by bound checks.
8. **Stale test assumptions.** `test_liquid_solver_policy.gd` and
   `test_liquid_policy_worker.gd` expected Water × pressure reference to be
   refused; they now use `pressure cached` (still refused), keeping 12 refusal
   cases.

## Runtime publication

**Attempt 1 (request_sequence 1, source `fd37a0a`, run 40095281125): failed.**
Admission and both builds passed; the Linux execution step failed before any
case ran. The retained Linux runtime (`libcybersand_native.linux.x86_64.so`)
imports `std::__cxx11::basic_string::_M_replace_cold@GLIBCXX_3.4.31`, above the
published Linux runtime floor (`GLIBCXX_3.4.30`, `tools/check_linux_runtime_floor.sh`).
Cause: the new GDExtension run-receipt code concatenated `std::string&& +
std::string&&`, which GCC 13 inlines as a front insertion. Correction: append-only
assembly through `liquid_policy_detail::concat` in the receipt, the physical-state
import error and the CYPS refusal text. Local check (GCC 16, `-O3`, godot-cpp
headers): `nm` finds `_M_replace_cold` once in the old `cyber_native_cell_world.cpp`
object and in no rebuilt GDExtension or World object. Republication uses
request_sequence 2.

**Attempt 2 (request_sequence 2, source `a5b532203d5b86064ed119e2654042e5ccd5ee19`,
[run 40096220163](https://github.com/techrote/cybersand/actions/runs/40096220163)):
passed on 2026-10-24.** The Linux build and execution, Windows cross-build,
actual Windows execution and lease-checked publication all succeeded. The bot
advanced the branch to recoverable checkpoint
`97a76aa89f645477b1864ae77864f43e330ca9ea`, changing only the two libraries and
their two provenance manifests. The publication lease is complete.

| Published target | Bytes | SHA-256 |
|---|---:|---|
| Windows x86_64 | 4,347,392 | `d607ac3981a73c4bbd60a344ffa87584565df2b9156d852e4586c3246d820cd3` |
| Linux x86_64 | 3,745,672 | `4413cf5ff7d988f3ebcd39d57fb8fe0aa8a8ffa4eb17305f02d5c559e60fe34f` |

The manifests record canonical source tree
`e028c238566964b0130624eeae816852c22341cc`, exact source inputs and toolchains.
Linux used GCC 13.3.0 / binutils 2.42 on GitHub-hosted Ubuntu 24.04 and passed
the declared Linux runtime-floor check. Windows used the pinned LLVM-MinGW
20260826 / Clang 23.1.0 cross-toolchain and executed with Windows Godot 4.7 on
GitHub-hosted Windows 2022. Both used pinned godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1.

On each target, the publisher ran project import followed by the nine mandatory
liquid-policy, MicroScenario, LCB and Water Feel cases with a 180-second limit
per case. `test_lcb_pressure_reference.gd` reported **1932 assertions, 0 failures,
all 12 sections true** on both OSes (Linux about 39 seconds; Windows about 24
seconds). The other controls completed without skips or errors. Retained
artifacts are `lcb001-pressure-reference-runtime-linux-40096220163` and
`lcb001-pressure-reference-runtime-windows-40096220163`; their `validation.json`
SHA-256 values are respectively
`5ded2401bef5caabe14fb60b9da9388321097a0d6ec78949b014d585032b5ef6` and
`709fce3f1f12d3b31c4eec762b3ba4b6423c5cd579e7c8e171c122a38dad9d19`.

Takeover verification used `gh run view 40096220163 --log`, a clean fast-forward
of the existing pressure-reference worktree, and `Get-FileHash -Algorithm SHA256`
on both materialized LFS payloads. Both bytes/size identities match the manifests.
The root checkout's unrelated material edits and other worktrees were preserved.
This evidence-only checkpoint updates this record and the roadmap publication
status; subsystem behavior, ownership, interfaces, invariants, configuration,
ADRs, controls and retrieval destinations are unchanged.

**Final acceptance remains separate:** [PR #245](https://github.com/techrote/cybersand/pull/245)
must leave draft and pass Documentation/provenance, Native, the complete Linux
and Windows GDExtension/Godot matrix and the applicable #49 apparatus at its
final head. Their exact-head results and review/merge receipt belong to the PR
description and Checks. Publication alone does not establish those gates,
graphical acceptance, Web/WASM execution or owner feel.

## Takeover review corrections (2026-10-24)

Independent review of published checkpoint `97a76aa` found the following
correctness defects before ready-for-review acceptance. Attempt 2 remains valid
evidence for its exact source and focused cases, but cannot accept these repaired
native inputs: another source-matched publication is required.

| Finding | Reproduction and correction |
|---|---|
| Gas topology depended on allocation history around a body mask | A divider crossing an unallocated interior chunk produced one gas compartment; allocating that chunk first produced two. Serial topology preparation now materializes mask-bearing chunks through the existing bounded capacity/quarantine path before applying the uniform-Empty-node shortcut. The regression compares sparse and resident layouts for three ticks, exact volumes/amounts 231 and 210, and equal complete physical hashes. |
| Whole-cell lateral fast path opened an interior Water void | Full-speed lateral flow below a paused deep Water column returned before the retain-one-unit guard. The fast path now uses that guard too; a public-API 1/4-worker regression checks the retained source, updated outgoing velocity and exact quantity. |
| CYPS and the complete physical hash omitted settings that change physics | A Mercury-viscosity override restored as the default and diverged on the first tick while its initial physical hash agreed. Both the viscosity override and powder-exchange suppression now participate in the physical hash and experimental CYPS v1 payload; the regression checks restored settings, byte round-trip and 20-tick continuation with a different worker count. |
| A checksummed inconsistent gas ledger was admitted | Restore checked only `amount_live` against the gas table. It now also checks the complete conservation equation with overflow rejection; rechecksummed contradictory and overflowing source sums are refused. |
| Different simulation windows shared a run receipt | Equal window flags hid different selected rectangles. The receipt now binds the actual region and physics-changing diagnostic settings; its Godot regression compares two different rectangles. |
| Incremental Make builds missed pressure include edits | `CORE_HEADERS` now includes `native/src/*.inc`, so changes to the two pressure implementation fragments invalidate dependent native targets. |
| Partial pressure transfers lost coherence | Source Water coherence 12 became 11 at the source but 0 at a partially filled receiver; Current retained 11. Transfers now propagate maximum coherence, captured before source retirement; regressions cover partial gravity, source emptying and overfill relief into Empty. |
| Surface skin and relief bypassed material coupling | With a configured carrying profile, Current's 96-unit surface transfer carried Sand while the pressure path left it behind. All successful direct quantity transfers now call the material hook exactly once with actual mass; the regression checks Sand tuple 17/23 and temperature 777, exact Water quantity 128 and 1/4-worker execution. |
| Same-material reaction products and pressure-only edits bypassed lifecycle rules | Water + ToxicSludge produced Water with the old flow 1024. Explicit product writes now reset family state (flow 0), while ordinary coherence writes retain it. Identical-visible `set`/`set_cell_state` also witness pressure-only reset changes through dirty/wake/discovery publication. |

The experimental, unfrozen CYPS v1 encoding gains three physics-option bytes
after `maximum_explosion_radius` (powder-exchange suppression u8 and Mercury
viscosity i16). No accepted durable save-format or historical runtime record is
rewritten. This repair checkpoint updates the canonical pressure design and
interface contract alongside this record; policy admission, material catalogue,
default physics, user controls, ADR decisions and retrieval destinations do not
change. The source-derived capability, policy/vector/native-artifact, scenario
registry and physics-contract checks still agree without regeneration.

The standalone worktree initially failed local documentation/repository checks
because five companion-workspace expected-fact sources were absent. An isolated
real source worktree under `C:/Users/_/.codex/tmp/lcb245-validation/workspace/source`
with companion commit `6a58311982941b75f46e22109a0829e5acb83c7e` reproduced the
CI layout. At published `97a76aa` plus the publication evidence/roadmap delta,
documentation and materialized repository checks passed (18/18 runtime payloads),
as did 18 retained M11 records / 28 historical source hashes, eight validation
failure contracts, LFS fsck and whitespace. Retrieval retained all 32 frozen and
121 challenge routes in the top five; source review remains separate from those
lexical scores. Raw local commands and identities are retained in that temporary
layout's `initial-receipt.json` parent record. This initial pass predates the
native repairs and does not attest their runtime identity.

Live issue headers #200/#201/#202/#212 were reconciled with the canonical
2026-10-24 bounded implementation authorization while preserving their original
backlog contracts and historical comments. They remain open. After #245 passes,
the owner's continuation order is remaining shared #200 contract first, then
#201/#202/#212 in parallel where interfaces/write sets permit, then #203.

**Repair validation before republication:** the complete native suite passed
**107/107** on the integrated delta over `97a76aa`, using cached pinned
LLVM-MinGW 20260826 / Clang 23.1.0 on Windows. Source hashes captured before and
after execution were identical. Exact compiler command, source delta, input
ledger and test output are retained under
`C:/Users/_/.codex/tmp/review245-integrated-native-final/`; executable SHA-256
`dbd1eb0f2cea3724c7f810a517e305f532e1978ad0afd954fe22a0c740a07779`,
input-ledger SHA-256
`271487478a097ec35392beee3ec84c26e679b196b1dda88f1367a79b8849936c8`.
The focused pressure suite also passed 13/13. LCB Python tests passed 120/120,
publisher guards 21/21, provider policy and `git diff --check` passed. Independent
boundary review found no further actionable defects in its reviewed scope.
Native sanitizer/TSan and the new Godot receipt assertion still require the
hosted gates. Publisher request sequence 3 requests corrected source-matched
Linux/Windows artifacts; the prior published hashes remain historical identities.

**Attempt 3 (request_sequence 3, source `1a1c32ca00060657930dd93e00ef02d450b1781f`,
[run 40100041024](https://github.com/techrote/cybersand/actions/runs/40100041024)):
deliberately cancelled before publication.** Admission passed; both builds were
cancelled after the material-hook review reproduced lost coherence. No runtime
commit was published. That review also identified the missing material-coupling
and same-material product/reset witnesses above. The completed repair is requested
with sequence 4; the branch lease from attempt 3 is no longer active.

The final integrated material-hook repair passed **107/107** native tests
(36.495 seconds including compile/run, pinned Clang 23.1.0 Windows host), with
identical native input hashes before/after execution, plus 13/13 focused pressure
cases. Evidence is retained in
`C:/Users/_/.codex/tmp/review245-material-hooks-native-final/`; executable SHA-256
`0f784affe16d61cb82fc184cba29c31115143e27c72653269d850233244b78fa`,
input-ledger SHA-256
`a7a8d0aef611493eb44e5c5e081d4de95ce03f7f69adb085be1417c495bb4475`.
Independent cross-review of both repair write sets and the targeted material
stage audit reported no remaining actionable findings. Capability/native policy
artifacts, scenario registry and physics contracts still match their sources;
`git diff --check` and provider policy pass. Hosted runtime and final acceptance
gates remain separate.

## Corrected publication and final-source characterization

**Attempt 4 (request_sequence 4, source
`349d59359a45ebbe4f92af879945b43b591d412a`,
[run 40100666514](https://github.com/techrote/cybersand/actions/runs/40100666514)):
passed on 2026-10-24.** Linux build/runtime-floor/execution, Windows cross-build
and actual execution, and final source/provenance lease verification all passed.
The bot published only the two libraries and two manifests at recoverable
checkpoint `101758d59e7d493fb43c9c4cdc7fbde24279614f`.

| Target | Bytes | SHA-256 |
|---|---:|---|
| Windows x86_64 | 4,352,512 | `813bfbb42f0bc9c21488aca44df2a3477e47db594b3521885ea2fed39ea07f0a` |
| Linux x86_64 | 3,749,776 | `3bfe1679c6d0201203fcf99b6f53d7f50875a530611776787131d7dc1d5098c2` |

Both manifests bind source tree `7f5a0e36d3f7da1c3e50cd118259f9714993f01d`.
Materialized payload hashes were independently checked with `Get-FileHash` after
a clean fast-forward. Both targets ran import and all nine mandatory cases with
the same pinned tools and per-case limits as attempt 2. The updated candidate
regression reported **1933 assertions, 0 failures, all 12 sections true** on each
OS. Retained Linux/Windows `validation.json` hashes are respectively
`cd0b386d97074b95b3a4ce085dd922087c7d394b4384e4abced44915a2e03142` and
`88dc29474d5be711ff52a1fcad43cee3f1164d22caf9c518dbea54ecd4711286`.
This is focused execution of exact source-matched development runtimes; the
full ready-PR matrix remains a separate acceptance gate.

The final characterization executable was built from `git archive 349d593 native`
in an isolated directory with MSVC 19.38.33145.0 x64,
`/std:c++20 /EHsc /O2`. Command: `characterisation.exe all 1`, timeout 1800 s,
one worker, dam horizon 1800, head horizon 2400. Execution on 2026-10-24
14:03:30–14:13:00 UTC completed in 569.506 s, exit 0, empty stderr, no timeout.

| Screen | Current | Final pressure reference |
|---|---|---|
| fronts at t240, depths 48/96/160 | 67/70/71 | 130/221/220 |
| depth response | 1.06 | 1.69 |
| retained at t1800, depths 48/96/160 | 0.839/0.841/0.851 | 0.619/0.437/0.371 |
| vented gap at t2400 | 120 | −9; first within ±12 at t1026, subsequent maximum 12 |
| narrow gap at t2400 | 120 | 43 |
| sealed at t2400 | gap 120 | levels 152/175, gap 23; unsettled, no sealed-law acceptance |

All twelve runs preserved exact quantity. The final sealed gas records
`(amount, volume, gauge)` are `(1152, 3831, −5706)` and `(6912, 4933, 3273)`.
The earlier source's 4.9-row residual is historical and is not reused for this
source. An intermediate `1a1c32c` run produced identical physical metrics and gas
records; its earlier output remains preserved separately.

Raw identity, compiler/build log, runtime output, empty stderr and comparison
are retained under
`C:/Users/_/AppData/Local/Temp/codex-pressure-review/characterisation-349d593/`.
Source archive SHA-256
`f63c0a386d404b9913e379562ba92a27f89fe7f8daf5d3e85ca01cf9c8424d60`;
executable SHA-256
`8980188eb29ca596df1f750efc25c01a7bcf21e77c8003968648c648d15f41ec`;
runtime-log SHA-256
`fe2c4d7c70f6209b7c986fb3b2ab8e9046133b2a2f7e01563a29bf0edea45096`.

Canonical pressure design, handoff and roadmap metrics were updated together,
with the actual run-receipt region/diagnostic fields synchronized in the policy
interface description. Historical measurements, failures and artifact hashes
are retained. Final exact-head CI, independent review and merge disposition are
recorded in PR #245's description/Checks to avoid changing source for its own
acceptance receipt. Remaining shared #200 work is still open; the stale capability
matrix headline about only default execution is a known identity-metadata gap
for that next checkpoint, while its qualified candidate rows and native applied
readback identify this executable pressure reference.

The final evidence/documentation delta over published `101758d` passed the
isolated pinned-companion validation layout again: documentation 111 pages / 217
claims / 2594 links with zero errors or warnings, materialized repository
provenance (18/18 runtimes), 18 retained M11 records / 28 historical hashes,
eight validation failure-contract tests, LFS fsck and whitespace. Frozen
retrieval retained 32/32 top-five routes (MRR 0.7953); challenge retrieval
retained 121/121 (MRR 0.8742). These lexical results do not establish answer
sufficiency. No native input changed after the published source.

## Native CI aggregate-timeout correction

The ready-PR Native run
[`40101949681`](https://github.com/techrote/cybersand/actions/runs/40101949681)
at head `48fb275` was cancelled by its **45-minute job limit**, not an assertion
or sanitizer diagnostic. The native job ran from 14:19:13 to 15:04:27 UTC on
2026-10-24. Behavioral tests, CLI/generation checks, ASan/UBSan, the sanitized
settled-regions build and soliding sanitizer regressions passed. The latter
finished at 15:02:47; the deadline interrupted TSan at 15:04:25, and the final
shared-library/benchmark step did not run. Neither incomplete gate is credited.
ASan execution retained its declared `detect_leaks=0` scope.

The aggregate job budget is increased to 90 minutes while retaining every
existing test, sanitizer setting and per-command timeout. Native source inputs,
published runtime bytes and provenance are unchanged. CI-provider policy and its
six tests pass locally; the complete required non-draft matrix must pass again
at the updated PR head before merge. Exact new run identities and their completed
outcomes are recorded in PR #245's description and Checks.

## Gaps (open)

- #200: W-CY (whole-cell Water `cellular_yield_v1`), `water-normalize-v1` and
  `normalization_required`; the remaining #202 constructors; a frozen run
  receipt schema (the GDExtension receipt hash exists); the oracle has no build
  profile for this running build (native tests check it directly).
- Sanitizer/TSan require the final Native CI gate; Linux headless execution passed
  in the scoped publisher above, with the complete Godot matrix still separate.
- Web/WASM: not built or run.
- Reference cost is O(resident cells) per tick (#201 owns caching/dormancy).

## Exact-head acceptance and merge

PR #245 merged on 2026-10-24 as
`03785c3dcaa5c82df000eeca1471bd6ec698be00`, after all applicable non-draft
gates passed at final head `e48c5aa5f9871fc997434f226284ed638613177f`:

- [Documentation/provenance 40105553880](https://github.com/techrote/cybersand/actions/runs/40105553880): pass.
- [Native 40105553858](https://github.com/techrote/cybersand/actions/runs/40105553858): pass in 50m29s, including normal, ASan/UBSan and TSan execution of all 107 tests, generation/CLI and soliding checks, shared-library build and final benchmark. ASan retains its declared `detect_leaks=0` scope.
- [GDExtension/Godot 40105553817](https://github.com/techrote/cybersand/actions/runs/40105553817): both builds, all 128 applicable Windows headless cases, four Linux shards with 140 unique cases exactly once plus four imports, and the aggregate pass. Actual rendered Linux cases are included.
- [#49 apparatus 40105553843](https://github.com/techrote/cybersand/actions/runs/40105553843): pass.

The tested synthetic merge `35bc821479108d5c694d1ad143462f2b374ecca1`, final
head and actual main merge all have tree
`31518a3838808227715aa7b81f6cfc7cae7b775d`. Windows execution reported empty
errors/source drift and used the published `813bfbb4…` runtime; Linux used
`3bfe1679…`. Independent native/boundary and material-stage reviews found no
remaining actionable issue. No skipped draft/scope result supplies acceptance.

Complete Native logs and actual Windows/Linux receipts are retained under the
pressure worktree's ignored `build/takeover-245/e48-*` paths. The Native log
SHA-256 is `7fcadd27e9fdc53fb0fd8fa3d51746e3d075b86b35c333014e55b3b173511d0c`;
the Windows execution receipt hashes to
`abf5073f21649be0c862482e84f4e809307fb0d0ca833aea3f56de48207b6005`.

The main checkpoint was fetched and the source worktree fast-forwarded cleanly.
Superseded draft #244 was closed. The completed pressure publisher workflow,
helper, unittest and source-bound request are removed in the focused residual
#200 successor checkpoint, with their original implementation recoverable at
`48fb275`. This retirement is part of that successor branch, not an assertion
that the files have already disappeared from the recorded main merge. A new
native delta requires a freshly scoped publisher and fresh matched runtimes.
Issue #200 remains open for its separate residual acceptance.
