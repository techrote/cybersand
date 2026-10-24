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

## Gaps (open)

- #200: W-CY (whole-cell Water `cellular_yield_v1`), `water-normalize-v1` and
  `normalization_required`; the remaining #202 constructors; a frozen run
  receipt schema (the GDExtension receipt hash exists); the oracle has no build
  profile for this running build (native tests check it directly).
- Sanitizer/TSan and Linux execution run only in CI.
- Web/WASM: not built or run.
- Reference cost is O(resident cells) per tick (#201 owns caching/dormancy).
