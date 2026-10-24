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

## Gaps (open)

- #200: W-CY (whole-cell Water `cellular_yield_v1`), `water-normalize-v1` and
  `normalization_required`; the remaining #202 constructors; a frozen run
  receipt schema (the GDExtension receipt hash exists); the oracle has no build
  profile for this running build (native tests check it directly).
- Sanitizer/TSan require the final Native CI gate; Linux headless execution passed
  in the scoped publisher above, with the complete Godot matrix still separate.
- Web/WASM: not built or run.
- Reference cost is O(resident cells) per tick (#201 owns caching/dormancy).
