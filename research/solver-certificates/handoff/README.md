# B3 — source-typed handoff certificates (experimental research)

**Date:** 2026-11-09  
**Repository baseline:** `techrote/cybersand` accepted `main` `d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (merged #542); no production source edited.  
**Status:** RESEARCH ONLY. No accepted solver selection, physics law, momentum theorem, speedup or runtime qualification.  
**Scope owner:** `research/solver-certificates/handoff/**` only.  
**Run:** `python3 -m unittest discover -s research/solver-certificates/handoff -v` (standard library only).

## Falsifiable claim and boundary

**Claim.** In the *single-authority abstract state machine* in `handoff_contract.py`, for any finite sequence of accepted Water ownership transfers that obey the specified preconditions, each payload portion has one authoritative representation, the exact sum of all Water quantities is unchanged, and a duplicated or expired command does not repeat a transfer. Granular and Rapier records remain separate physical authorities and interact through observations, not by silently converting their mass to Water or to cells. This is a theorem about the defined abstract model, **not** about the actual Godot/native implementation.

**Falsifier:** a programmatically constructible sequence of admitted intents where a successful commit changes Water total, produces two owners for the same token/portion, accepts a wrong body/sample/revision/epoch, or a refusal mutates its source-bound model identity. Also challenge source replacement with the same revision, malformed velocities, capacity overflow, sidecar changes and crash/restore semantics. The model explicitly lacks crash durability and cannot qualify restart.

### Proof sketch (induction)

Let `I(S)` assert (1) all identities in a state's dictionary are unique and nonempty; (2) each Water identity has exactly one owner in {FreeMass, PressureFlow, IN, ballistic}; (3) `sum Water(amount + PF overfill) + external_consumed = initial_water + external_produced`; and (4) IN holds only whole Water cells. Initial states satisfying `World.start` meet `I` by construction. An accepted full transfer replaces the sole source record with one destination record of equal amount and a new owner. An accepted partial transfer (only FM/PF/non-IN) reduces source amount by `q` and adds one fresh suffixed identity of `q`; `q>0`, `q<src.amount`, and destination is not already present. PF overfill sources refuse. Consequently the Water sum is unchanged. Granular and Rapier are never eligible source/target for Water transfer. Failed guards leave all records unchanged; duplicate replay returns a receipt without mutation; commits require a matching generation/epoch, source revision/amount/owner and contact witness tied to `(epoch, body, sample, payload)` at the exclusive fence. Thus `I(S')` holds. A candidate state is validated **before** authoritative record swap. This is a finite inductive argument over abstract transitions. It does not prove the runtime's real command ownership or crash atomicity.

## Source-grounded constraints (not invented runtime capabilities)

- [Current liquid policy](../../../docs/architecture/liquid-solver-family-policy.md) selects a liquid solver per *material at World creation*, immutable within that World. Dynamically choosing bulk representation per contact would require a new opted-in, independently admitted contract; this research does **not** implement it.
- [Current liquid lifecycle](../../../docs/architecture/liquid-state-transition-matrix.md) requires family-owned state to follow the cell and be retired without duplication, every write to wake/invalidate relevant state, and future-affecting state in versioned physical hash. The research model's SHA-256 identity is **not** CyberSand `physical_hash`.
- [Ballistic Water experiment](../../../docs/architecture/ballistic-water-v1.md) and [#406](https://github.com/techrote/cybersand/pull/406): bounded parcel owner, exact mass quantum transfers, Water PF pressurized-source refusal, CY/IN whole-cell source and IN deposit, serial parcel pass, saved ledger, q256 signed-vertical parcels. `IN-B1` is opt-in; ordinary IN v1 disallows negative vertical velocity. This model tests that option with an explicit flag; it does not implement real q256→q16 conversion, velocity saturation or body force.
- [Rapier coupling](../../../docs/architecture/rigid-body-and-cellular-coupling.md): native World owns material; Rapier owns its bodies on Godot main thread; bounded observations do not assert energy or momentum conservation. Contact samples must not be used as a second material authority. [#474](https://github.com/techrote/cybersand/pull/474) opt-in lockstep is separately source-qualified and has a fallback after 500ms; this research model does not strengthen its real production guarantees.
- [#470](https://github.com/techrote/cybersand/pull/470), [#471](https://github.com/techrote/cybersand/pull/471) and [#522](https://github.com/techrote/cybersand/pull/522) have already supplied independent current-main optimization work. Do not reframe them as this proof's results or reimplement them.

## Single bounded experiment

Scenario: a Rapier body (ID 7) contacts bulk Water at native sample 42; signed upward q256 ballistic launch transfers 256 Water units into a parcel, then reintegrates into IN. Without the separately opted-in signed vertical IN-B1 law, upward reentry refuses unchanged. With that option explicitly admitted in the abstract model, it commits, and granular and Rapier authorities retain their identities. The impulse tag is **not proof of force/momentum conservation**: the before/after `sum(q*v_q256)` is recorded, and status remains `UNVERIFIED_INPUT_DECLARED` even with a tag. The abstraction intentionally does not supply the real interface for contact impulse, deposition capacity, masked terrain, PF gas or full save/restore.

Independent negative controls: PF overfill source refuses, fractional IN ingress refuses, Water-to-Rapier/Granular conversion refuses, stale/no-fence/duplicate/token mismatch refuses, missing contact and forged `(body,payload,sample)` association refuses, malformed velocity refuses unchanged. A 256-member family of partial launches and returns tests deterministic quantity identity; that finite sample does not constitute a proof of actual runtime correctness.

### Qualification and performance cost

`python3 -m unittest discover ... -v`: **18/18 PASS** on local Python 3.13.5. `python3 -m compileall`: **PASS**. No native/Godot/Windows execution, no actual physics hashes or end-to-end FPS measurements. These are **deterministic model-oracle** results only.

Same local host, isolated Python model, five repeats × 60 alternating FM↔ballistic transfers; median microseconds/transfer: **20.21** with 16 unrelated granular records; **139.02** with 256; **1,024.75** with 2,048. This reference code intentionally copies the dictionary and scans whole state for model invariant checks. **It is O(N), not production-fast.** Report no CyberSand speedup and do not copy the current implementation into the hot path.

A *hypothetical production* receipt core could instead perform O(1) bounded map lookups, generation/epoch/lease checks, delta inventory bookkeeping, plus O(changed-cells) updates to activity/physical-hash dependencies; that proposal is not verified. For a budget of 200 transfers × 14 local guards: ~2,800 simple checks, ≤400 dictionary lookups and ≤200 journal entries **before** native boundary/collider/solver/caching expenses. Real time and memory require B4 profiling and an unchanged-law full-host correctness oracle.

## Independent review / next increment

1. B4: try adversarial counterexamples in model and real replay; validate whether any sufficient one-writer handshake can be mapped to actual #406/CYPS4 receipts under real worker/actor ownership. Benchmark *total* impact, not a made-up per-cell micro-speedup.
2. B2: connect contact witness generation/epoch and influence-region invalidation, especially stale body samples and long-range PF pressure/gas dependency. A copied witness without state/solver revision is not a safe skip certificate.
3. B5: decide whether a minimal opt-in **prepare/commit/reject** interface is useful for *one* actual gameplay scenario; retain original immutable per-material policy unless a separate physical-law/architecture decision authorizes a new representation transfer.

**Open blockers:** no source-qualified production transition API for arbitrary FM/PF/IN switches; no tested reentry capacity/location/wall conditions; no controlled momentum conversion/impulse units; no independently verified crash-atomic persistence or cross-platform execution; model one-writer assumption requires actual worker fence. All remain `UNVERIFIED`. No production or physics default changes are proposed.

## 2026-11-09 second bounded experiment — World-bound signed-IN admission

**Exact parent:** B3 Draft PR #555 `cee5f39954736687b23bd4d31602bb160d41326f`, on accepted main `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
**Pre-registered falsifier:** an unsigned/default abstract World accepts a negative-vertical-velocity transfer into IN merely because the untrusted `Intent.allow_signed_inertial` boolean is true. This is a *source-typed admission* counterexample, not a mass-conservation counterexample or evidence that native World accepts the transfer.

**Observed static model bug (before this correction):** `commit` checked only the request flag. It never checked an applied World capability. Thus `World.start(3,[Record("w", FREE_MASS,256)])` and an `Intent` targeting IN with `next_velocity_q256=(16,-8)` and `allow_signed_inertial=True` passed its signed-IN guard despite the model having no signed-IN World declaration. Exact integer quantity remained 256, masking the incorrect law admission.

**Corrective research law (conditional):** for every finite transfer sequence through this model, a committed request with `target=IN` and `vy<0` entails **both** `intent.allow_signed_inertial` and `world.signed_inertial_world_enabled`, provided World construction is the sole authority for the latter and no unmodelled mutations occur. This follows by the added guard before candidate construction; accepted commit copies the option into its successor World. The condition is checked *before* mutation. All other previously admitted transfers retain their original test contracts. The option participates in the model identity digest and rejects non-boolean initial values.

**Source-critical bound:** on accepted main `d4b18e7f`, native `WorldConfig::inertial_signed_vertical` defaults false, the constructor requires a valid applied IN material assignment, and `World::impart_inertial_velocity` refuses negative `dvy` when its signed parameter is disabled (see `native/include/cybersand/world.hpp`, `native/src/world.cpp`, `native/src/world_inertial.inc`). The actual World is *not* reconfigured by this model. A bare model boolean is not a cryptographic attestation, actual native receipt, physical-state hash, applied material-policy proof, or proof that dynamic FM→IN is admissible. The model cannot yet bind `World` creation policy, material family, generation, CYPS extension identity and source-built runtime in a production-reusable certificate. Any unknown or untrusted native readback must refuse.

**Independent controls:** default World + caller flag must refuse, explicitly opt-in research World + caller flag may commit, opt-in World without caller flag must refuse, malformed World option must refuse at construction; no momentum correctness or runtime cost claim. B4 and B5 should challenge the missing authenticated-native-policy seam before considering an opt-in consumer. No default switch, production edits, native campaign, or physics admission.


**Executed independent 12-case negative-control truth table:** CPython 3.13.5, local, command
\`python3 research/solver-certificates/handoff/signed_policy_negative_control.py\`: 12/12 PASS, including the one minimal legacy-positive/revised-negative request. Local exact Git blob \`35c172712440f1ca223d62f911e827ea4c245317\` matched the file fetched from the Draft branch after publication. This **executes only the standalone predicate oracle**, not the full \`handoff_contract.py\` / \`test_handoff_contract.py\` suite or a CyberSand native build. The published authored suite now defines 20 tests, but the two new integration-level tests remain **UNEXECUTED** in this run; hosted CI and independent review must not treat the 12-case oracle as suite qualification.

**Cost boundary:** the additional World capability check is one boolean read per attempted *negative-vy IN admission* in the reference model; the publication does not alter any native per-cell loop or benchmark total-tick cost. An actual native binding would require a trusted applied-World-policy receipt and measured overhead with physical-hash parity, not a caller-provided boolean.
