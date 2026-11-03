---
title: Paired materials and finite curing registration
status: Approved design
document-kind: design
scope: Preregistered bounded native material implementation, shell apparatus and admission decisions; execution results are separate
canonical-for: [paired-materials-registration]
last-reviewed: 2026-11-03
related-documents: [paired-wall-loose-materials-plan.md, microscenarios-programme.md, ../systems/intermaterial-interactions.md, ../systems/materials-and-rule-kernels.md]
---

# Paired materials and finite curing registration

The owner authorizes implementation and qualification, preserving existing Cement
and keeping the PR unmerged. Fresh starting main is
`89020b9eb6d540383a5bb64b58dcd29a87592c32`, tree
`79de02472a653a4315149bc5e1970a512e6d74b6`, fetched November3. The feature is
isolated on `codex/paired-materials-20261103`. The unrelated dirty checkout at
`C:/khybersand` is preserved. The earlier flyer/GCR PR351 remains draft and is
read-only evidence/input here, not a prerequisite for changing production material
rules. Main's stopped-PLAY recovery and accepted render/shader paths are retained.

INT-000 infrastructure is already landed according to the canonical programme;
old issue29 implementation-gate wording is historical. New chemistry stays in
that native resolver/kernel owner. Active PR357 is a documentation-only catalogue
proposal with no runtime write owner: this implementation does not introduce its
compiler, DSL or generalized material authoring system. Its old132-slot baseline
and synthetic ID132 do not reserve a production ID. Draft detachment/GCR work
does not transfer its source or acceptance claims into this branch.

## Frozen feature

- Append Stone Wall132, Salt Wall133 and Coal Wall134. Old0..131 IDs,
  descriptors, reactions and hard/granular memberships remain identical.
  Existing hard range38..131 is bounded explicitly; only the new walls/crust
  are additionally hard. Chemistry maps the three admitted wall participants
  to their parents only for contact resolution and explicit shared Coal state.
  Products retain a surviving wall form only for these admitted paired inputs;
  real conversion products stay ordinary materials. Existing56 rule IDs,
  precedence, probability semantics and pair ledger slots stay stable.
- Append Dry Binder135 and Activated Binder136 as granular powders, and Binder
  Crust137 as hard terrain. Both powders use one new finite-binder kernel.
  Dry activation probes at most8 Moore neighbors, consumes at most1 qualifying
  full normalized Water cell and records that cell's quantity in stateB.
  Partial Water and pressure-overfilled Water refuse activation without mutation.
  This full-cell admission supports current solver families without adding a
  Water transport/debit law. Supported mass precision is3..8bits; the selected
  full quantity7..255 fits stateB. The lab uses8bits.
- Activated Binder counts down180 native cell updates, preserving bound
  quantity, then becomes crust. No Water, Air, Concrete, crust, age or activated
  neighbor can activate another dry cell without a fresh consumed dose.
  Activated cells authored with zero bound quantity cannot manufacture a cure.
  Cured cells never donate activation. There is no spent-binder recycling,
  structural fracture, load damage, sleep or contact-law retuning in this pass.
- Append one specialized interaction provenance entry and version the current
  interaction profile. The quantity kernel slots grow19→20, with nested quantity
  schema1→2 to prevent implicit-length payload misinterpretation. Old rule/slot
  indexes stay fixed. Unsupported old physical payloads reject explicitly;
  historical artifacts and hashes are not rewritten. CYSD1 already carries IDs,
  stateA/stateB and temperature; prove this boundary instead of inventing replay.
- The playable shell lab uses current-main synchronous native/Rapier ownership,
  existing actor controls and terrain synchronization. It is not a GCR-LA or
  rest acceptance comparison. Include all-loose, intact and breached matching
  shells, a bounded roof-breach control, a separate collider-release fixture
  with an air gap, finite Water dose/removal, and free painting. No chemistry
  is implemented in UI. The lab refuses stale native and fallback runtimes.

## Registered population and decisions

The accompanying [protocol](../audits/paired-materials-2026-11-03/protocol.json)
freezes parameters and run limits. Candidate execution starts after this
registration is committed. Use native one-worker controls first, then4workers
and chunk/cell edges. Host checks use real Windows and Linux Godot4.7/Rapier.

1. Compare all old material descriptors and capability memberships and the old
   pair oracle against starting main. Exercise wall/parent source/target roles,
   probability boundaries and derived partner-cache/scan agreement. Coal wall
   must stay hard through ignition/countdown/extinguishing until a genuine Dust
   product; Stone wall keeps Stone's broad Acid susceptibility.
2. Measure no dose,1/2 doses, dose removal, partial/overfilled refusal, isolated
   activation, Concrete/crust/activated-neighbor negatives, state persistence,
   mask/chunk/capacity boundaries and minimum quiet-sleep configuration.
   Exactly close free Water plus bound stateB in a closed fixture; external
   edits/removals have separate explicit ledgers. Test FreeMass/CY/IN/pressure.
3. Preserve Cement case/descriptor/provenance and compare dated starting-main
   versus candidate deterministic traces for Air/Water/Brine/Concrete contexts.
   Run existing native core/quantity/interaction and sanitizer controls.
4. In the actual host, require native hard revision admitted before the next
   synchronous Rapier step and zero pending terrain work. A short collision ray
   must hit the intact patch and miss its removed patch; total shape count is
   not a retirement metric. Observe body descent over a bounded window with
   an8..12-cell air gap so powder cannot hide a stale collider. Repeat a seam
   breach, reaction conversion, reset and retired command/pause/focus/teardown.
5. Correctness is exact: no unexplained Water/bound quantity, overwrite, hidden
   body restore or duplicate response. Cure activation beyond supplied doses is
   exactly zero. Old-cell semantics and Cement differential failures block
   admission. A failed new family narrows/rejects that family; never retune
   unrelated powder laws to hide it.
6. Work is bounded by existing per-cell scheduling and8-probe/2-write activation.
   Benchmark a fixed populated patch against main, reporting native tick
   p50/p95/p99/max and activation count. Investigate median/p95 cost exceeding
   1.25× control plus0.25ms; concurrent host timings do not establish gameplay
   frame-time acceptance. Existing terrain sync's all-chunk drain is reported
   separately and makes no new real-time guarantee.

Publish source-matched Windows/Linux native artifacts with current input maps,
hashes, pins and licenses; do not reuse the GCR SDK as a material build. New
fallback painting must refuse unsupported IDs. Preserve actual failures and
report unavailable platform/scientific gates. Technical checks and owner gameplay
acceptance remain separate. A draft PR and owner-review instructions are the
handoff; merging and REM-004 completion are not authorized.
