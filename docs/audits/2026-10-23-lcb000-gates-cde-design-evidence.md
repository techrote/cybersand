---
title: LCB-000 Gates C, D and E design evidence
status: Current
document-kind: evidence
scope: Dated identities, executed Current-default fixture runs and gate ledger for the LCB-000 Gate C/D/E design submission and LCB-003 preparation; no solver family beyond Current executed
canonical-for: [lcb-000-gates-cde-evidence]
last-reviewed: 2026-10-23
related-documents: [../architecture/liquid-solver-family-policy.md, ../operations/lcb-water-comparison-and-fixtures.md, ../operations/lcb-manual-comparison-ux.md]
---

# LCB-000 Gates C, D and E design evidence

## Summary

This checkpoint submits three LCB-000
([#213](https://github.com/techrote/cybersand/issues/213)) gate artifacts and
LCB-003 ([#202](https://github.com/techrote/cybersand/issues/202)) preparation:

| Gate | Artifact | Status |
|---|---|---|
| C | Gate C [policy/API specification](../architecture/liquid-solver-family-policy.md) and source-derived [capability matrix](../reference/liquid-solver-capability-matrix.json) | submitted for review |
| D | Gate D [Water comparison contract](../operations/lcb-water-comparison-and-fixtures.md) | submitted for review |
| E | Gate E fixtures: two frozen MicroScenario definitions, an [arm manifest](../reference/lcb-fixture-manifest.json) and a regression ([test](../../godot/tests/test_lcb_fixture_manifests.gd)) | submitted for review |
| (#202) | [Manual UX flow](../operations/lcb-manual-comparison-ux.md) | design only |

**No native physics kernel, Cell layout, solver, default or UI was changed.**
The only executed physics is unchanged Current native liquids.

## Identities

- **Source:** `main` `9012425e3bba62aa1fefb15ea5d7306f196b8da2`; branch
  `claude/lcb000-comparison-design`.
- **Matrix inputs** (LF-normalized SHA-256):
  - `material.hpp` `3e40f970e3205853a43643b4163041935ccd64d8a018d35a7473c3f95a1d0375`;
  - `interaction_rules.hpp` `aaffab99ddc7413f82a77de69b9d97aea37bd8cf46211b867ed303a6776448a5`;
  - derived matrix `626e64fa871debedf33d8dd583d4026593c03487f5ec7687b8fcc47e6f5ee041`.
- **Fixture files** (LF SHA-256):
  - Dam Break `7c7c13125fcbf4e6f07317efa2190656840417c8ce328820adb7dfea7ba9f78e`;
  - mixed `ffdafafaa0cff8dfe81123a872f111ce63f8687f0a951a9040f2df67dda0709c`.
- **Canonical definition hashes** (from `CyberMicroScenarioContract.parse`):
  - Dam Break `494a017b0c7c9afed6923c84608f6fbd913b7040cf40e92fb18392f2d11119bf`;
  - mixed `208d488fbc3a218d61ab4468bd6fb31ddcdfde4cc44d5b2f43061dcd6f2036cc`.
- **Runner and host** (LF SHA-256):
  - `run_microscenario.gd` `1912d047…5be11`;
  - `microscenario_host.gd` `4bb2c74d…53745`;
  - `microscenario_contract.gd` `6c15e65b…14540`.
- **Runtime:**
  - Godot `4.7.stable.official.5b4e0cb0f` from `C:\Godot47`;
  - retained Windows GDExtension SHA-256
    `e6d9ec7d0847287c4c6b1acaffd52dc2807fe43e9dccfc36123ffa117fb6045f`;
  - its `runtime-provenance.json` build commit is `2f7f65bf…` with zero native
    build-input mismatches against this checkout;
  - `git diff 2f7f65bf..9012425 -- native/src native/include godot/native_extension`
    is empty, so the runtime is native-source-matched.
- **Platform:** local Windows 11 workstation. This is **not** CI, Linux or Web
  evidence.

## Executed runs (2026-10-23)

**Command form:** `Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/run_microscenario.gd -- --definition=<abs json> --ticks=N --workers=W --output=<file> --source-sha=9012425…`.
**Timeout:** 900 s per run.

The runner is native-only: no character, Rapier or rendering.

| Run | Ticks | Workers | Outcome | Final content / state hash | Report SHA-256 |
|---|---:|---:|---|---|---|
| Dam Break | 1800 | 1 | complete | `163e4c93b98320a8` / `140af7ed71e7d2e5` | `f73a5deb…1a49` |
| Dam Break | 1800 | 4 | complete | identical | `ed2f72b9…7898` |
| Mixed M0 | 900 | 1 | complete | `d43b52e8bbaf9176` / `7bdf182aa1cecd70` | `4fb293b4…4c82` |
| Mixed M0 | 900 | 4 | complete | identical | `71b19088…3c55` |

- **Parity.** Every observation is identical between 1 and 4 workers. The
  observation values are tabulated in the
  [fixture contract](../operations/lcb-water-comparison-and-fixtures.md) and
  the [arm manifest](../reference/lcb-fixture-manifest.json).
- **Timing.** Native tick p50/p95 was Dam Break 10.41/13.98 ms (w1) and
  6.95/8.51 ms (w4), and mixed 22.72/28.07 ms (w1) and 8.19/10.34 ms (w4).
  These are local characterization only, not performance evidence.
- **Retention.** Raw reports are not committed. Their hashes are above, and
  the commands reproduce them.
- **Prior attempt kept on record.** The first attempt was refused by the
  contract with "Observation area budget exceeded". The regions were tightened,
  and the Dam Break end wall was raised to full height so splash cannot leave
  the measured container, **before** any physics result existed.

**Focused regression.**
`Godot_v4.7-stable_win64_console.exe --headless --path godot --script res://tests/test_lcb_fixture_manifests.gd`
gave **26 assertions, 0 failures**, exit 0. It checks:

- contract admission and the pinned definition hashes;
- fixed reference execution, with no player/body/tools;
- default Water semantics and Baseline transport;
- the initial-state proofs: Dam Break 7,833,600; mixed 6,838,080 Water,
  26,880 Oil, 26,880 Brine, 64 Salt;
- the measured Current prefix at ticks 30/60;
- the exact Salt reaction ledger by tick 30;
- 1/4-worker equality.

This is local Windows evidence. CI Linux execution follows on the PR.

**Matrix derivation.**
`python tools/lcb/derive_capability_matrix.py --check` reports
"capability matrix matches source": 132 descriptors, 11 liquid rows and 120
non-liquid descriptors refused.

## What was *not* executed

- Any `pressure_flow_v1`, `inertial_cellular_v1` or Water `cellular_yield_v1`
  arm. These do not exist; the dam companions, M1/M1-alt, M2 and M2b are
  registered as proposed and blocked.
- **Three families in one World.** M0 runs **two** families. The three-family
  requirement remains open on #212.
- Full-host or interactive runs, Rapier or body coupling, rendering, Web,
  Linux, or packaged builds.
- The depth-ladder dam variants and the comparison stations (#202).

## Gate ledger

| Gate | State on 2026-10-23 | Evidence / blocker |
|---|---|---|
| A — #95/#45 reconciliation | **Submitted, not accepted** | [PR #214](https://github.com/techrote/cybersand/pull/214) (exact-head Documentation green, unmerged) |
| B — state/storage handoff | **Not satisfied**; owned by [#204](https://github.com/techrote/cybersand/issues/204) | draft PRs #208/#211; S2A timing admitted but not executed |
| C — family policy/compatibility | **Submitted for review** | this checkpoint; the per-family state rows are input to B, not a schema freeze |
| D — Water four-model contract | **Owner decision recorded (YES); contract submitted** | normalization rule `water-normalize-v1` proposed |
| E — Dam Break and mixed fixtures | **Fixtures registered; Current-default controls measured** | candidate arms unexecuted by design |

**Integrated LCB-000 decision: NOT PASS (BLOCKED).** Gates A and B lack
accepted evidence, and C–E are submissions awaiting review. LCB-001 pressure
porting and state/schema freeze remain blocked. Under #213, isolated read-only
preparation, policy/API and UI design may continue.

## Addendum — corrections after independent review (2026-10-23)

The [independent admission review (PR #216)](https://github.com/techrote/cybersand/pull/216)
reviewed head `6fc0e25` and returned Gates C, D and E as **BLOCKED** for
focused corrections. The record above is unchanged. These corrections were
added afterwards:

- **Gate C:**
  - Material hooks are separated from motion at the real dispatch points.
  - Canonical policy hashing now includes `capability_matrix_digest`,
    complete sorted assignments and typed parameter blocks, plus a separate run
    receipt hash.
  - New refusal codes: `malformed_policy`, `unknown_parameter`,
    `not_selectable`, `normalization_required`.
  - Readback now reports the applied family and normalization, with
    source/binary/catalogue identity.
  - Tick-zero reconstruction wording added; CYSD1 imports are not
    continuation.
  - State/quantity boundary rules added.
  - Matrix provenance split into source facts versus reviewed design. Toxic
    Sludge M1-alt is not selectable.
- **Gate D:**
  - `water-normalize-v1` now rounds up when `2·m ≥ maximum()`, so 128/255 goes
    up and 127/255 goes down.
  - Each conversion records per-cell signed deltas, deterministic ordering and
    a receipt hash, and is booked as a setup-only source/sink.
  - Coherence is honoured by every arm (or refused); adhesion is declared not
    applicable to whole-cell arms.
- **Gate E:**
  - The protected definitions and hashes are unchanged.
  - Stronger signed reaction-ledger checks are applied outside the definition.
  - Dam Break `complete` is labelled an accounting criterion only.
  - The surge, gas and physics acceptance extensions are delivered in the
    stacked LCB physics prepass.

Gates C, D and E remain **submitted for review**, and LCB-000 is not PASS.

## Addendum — Gate C wire/hash correction 2 (2026-10-23)

Responds to [re-review finding 1](https://github.com/techrote/cybersand/pull/226#issuecomment-6362824493)
(re-reviewed head `ca6fb7c`). The first correction is retained above as history.
Its three-array transport could not carry `catalogue_digest` or
`capability_matrix_digest`, so the claim that "every hashed component crosses the
wire" was false at that head.

- The single flat `int32` request envelope now carries magic, envelope version,
  policy version, both digests as eight big-endian words each, assignments, and
  family and material blocks. See
  [request envelope and canonical hash](../architecture/liquid-solver-family-policy.md#request-envelope-and-canonical-hash-gate-c-correction-2-2026-10-23).
- The exact packed-word to canonical-byte conversion is specified:
  - u16/u8 narrowing after range checks;
  - word versus byte lengths (4·L);
  - strictly ascending unique owners;
  - complete normalized assignments;
  - request code 0 normalized away.
- Validation precedence is total, and stale digests are checked before catalogue
  interpretation.
- `capability_matrix_digest` hashes the generated matrix file, so it binds the
  reviewed classifications as well as the source-fact digests.
- Standalone executable oracle: `tools/lcb/policy_contract.py`, with 46
  registered cases and a session transcript in
  `docs/reference/liquid-policy-wire-vectors.json`, plus 14 unit tests in
  `tools/lcb/test_policy_contract.py`. Both now run in the Documentation
  workflow.

**Evidence class: executed contract model.** Local commands, Windows, Python
3.12, 1-minute bound each:

```text
python tools/lcb/policy_contract.py --check                                → "policy wire vectors match the oracle"
python -m unittest discover -s tools/lcb -p test_policy_contract.py        → Ran 14 tests, OK
```

This does **not** implement a native policy, C API, GDExtension method, Web
bridge, World or solver. The parameter-block schemas in the oracle are
illustrative and freeze nothing. The vector build with all families available
is hypothetical. Gate C stays **submitted for re-review**, and LCB-000 is not
PASS.
