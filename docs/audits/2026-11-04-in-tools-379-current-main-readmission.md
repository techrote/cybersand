---
title: IN-TOOLS 379 current-main source re-admission
status: Current
document-kind: evidence
scope: Owner-authorized bounded source re-admission of the accepted 390 interest-ownership correction, ancestry-preserving documentation reconciliation and required fresh qualification; original fixtures and evidence retained, no gameplay or merge approval
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-in-tools-379-independent-review.md, 2026-11-04-lcb201-region-flip.md, ../architecture/in-tools-gameplay-admission.md, ../operations/in-tools-fixtures-and-playtest.md, ../operations/current-and-historical-validation.md]
---

# IN-TOOLS 379 current-main source re-admission

## Authorization and source identity

The [continuation stop](https://github.com/techrote/cybersand/pull/379#issuecomment-6640850821)
correctly found that accepted main had changed one of the 25 inspected inputs.
The owner then explicitly authorized bounded source re-admission, reconciliation
and resulting-head qualification, still **stopping before merge**. PR #379 stays
Ready; #361 stays open. #383 and #370 remain separately owned and unimported.
This is no authorization for new production gameplay or physics changes.

| Identity | Commit / tree |
|---|---|
| Original corrected #379 | `1aaab324a9bccbaa7f868798dbb4f9fd9b4a7718` / `7f1a7a0bfaaf416374b9532fdc62fbb5ccc9463e` |
| Original accepted source | `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1` / `36ce5a01e754a141c321f41cac7f1c6b6059c371` |
| Admitted current main | `751edc0b495dc85484ad5509a7c95f863651c76b` / `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6` |
| Accepted worker change | #390 source `9a9e63a0091f3a64e038892e651d0591d135241a` |
| Immutable #370 comparison | `fbe82bcab8f821aac442c2bf59eb57b279717873`, all nine original inputs |

The source transition is solely `godot/scripts/simulation_worker.gd`:

- Before SHA-256: `7facdb0cd1a59a039fb78c22298b7422f656f733082228ea178d7917234a2dd0`.
- After SHA-256: `6b1c27ff4e0013db58436079834ceae2c26589a752ee166462437c9aff2dbdbf`.

The original [six-plan registration](../../godot/tests/fixtures/lcb/in_tools/in-tools-admission.v1.json)
remains byte-identical, SHA-256
`8e5e12a5cbaf0ccf554f07dfc49ea17757112445bf23d6dc144154b6165b735a`.
Original audits, native packets, corrected census, runner, 58 focused tests,
retrieval queries and old source locks are retained. Historic green results
are not reassigned to the new candidate.

## The reviewed interest-ownership change

**Current source:** `CyberSimulationWorker.apply_world_execution_settings` skips
the transient camera window flag and region writes while an active scenario owns
fixed interest. Cadence, adhesion and interest-centre writes remain in order;
the scenario still applies its region afterwards. Ordinary interest keeps the
previous five-write sequence. The final fixed scenario region is preserved.

This is an interest-ownership correction, not a claim of universal performance-only
equivalence. `World::set_simulation_region` can cold the derived pressure cache
and begin/reconcile inclusion requests when optional settled discovery is enabled.
Avoiding transient region changes avoids those transitions too. The default has
settled discovery disabled. Native production sources, runtime payloads, quantity laws,
command fences and the original corrected native oracle are unchanged.

Both pinned seeds declare fixed interest `[16,16,992,272]`, fixed execution,
cadence disabled and adhesion enabled. All registered ports, intakes, sources
and guides fit inside that region. The complete observed domain remains
`[0,0,1024,1024]`; interest is not a conservation boundary. A future compiled
host definition must bind its actual settings and new definition identity. No
compiled or executed version of the six Planned host fixtures is asserted here.

All valve schedules, occupied-closure refusals, width variants, finite sink/source
budgets, zero-new-motion and stopped-window requirements remain unchanged. The
usable fixture remains an Exploratory physical-actor/equipment plan with its
original generation, cancellation, charge and cooldown obligations. Actor-free
controlled scenario execution cannot substitute for that usable route.

## Explicit successor admission without exemptions

The [separate source-admission record](../../godot/tests/fixtures/lcb/in_tools/in-tools-source-admission.2026-11-04.json)
contains the complete 25-path effective map and one reviewed before/after
transition. [Its checker](../../tools/lcb/in_tools_source_admission.py) authenticates
the frozen original plan's exact bytes, exact accepted commit/tree, candidate
ancestry, every accepted-main and claimed-HEAD Git input, every working input
and all nine pinned #370 inputs. Restored working files cannot conceal changed
committed inputs behind a misleading HEAD identity.
It rejects removed/added locks, a second change, altered original fixtures,
unreviewed successor identities and missing Git objects. No path is exempted.
The derived view exists only in memory; the v1 plan is never rewritten.

The original `source_check` remains unchanged and correctly refuses the new
worker. Use the explicit successor command in the [runbook](../operations/in-tools-fixtures-and-playtest.md).
Both interfaces retain `gameplay_qualified=false`; the successor also explicitly
reports `runtime_qualified=false` and `native_receipt_authenticated=false`.

One CLI failure-order correction parses a supplied proposal's JSON before source
checking. In the unreconciled test invocation, the valid source refusal masked
the duplicate-key negative and caused one of the original 58 tests to fail.
Parsing first restores that diagnostic. A well-formed proposal still cannot
bypass source equality. No receipt predicate or original test assertion changed;
the failing intermediate observation is retained outside Git with qualification.

## Reconciliation and validation boundaries

The normal merge retains both old #379 and admitted main in ancestry. Five
documentation conflicts combine both additions in the handover, retrieval corpus,
retrieval index, roadmap and validation ledger. The README merges automatically.
Newer #377 material-liveness and #374/#390 PressureFlow content is preserved;
USABLE02/ACT14 keep their canonical destinations and Current actor-usables remains
distinct from Planned IN-TOOLS. Historical LCB03/LCB08 observations remain dated.

Documentation CI now executes successor admission and all focused IN-TOOLS tests,
retains their evidence, and evaluates IN-TOOLS plus the existing material-liveness
and MAT-AUTH retrieval cohorts. This adds enforcement; it changes no runner
provider, acceptance threshold or expensive-matrix eligibility. The source-scope
advisory still grants no native exemption.

Required fresh gates are current documentation/checkers, all 18 materialized
runtime identities, frozen/challenge/IN-TOOLS and affected material retrieval,
the original 38+20 focused tests plus admission adversaries, material compatibility
and native metadata parity, the dedicated native census/diagnostic-parity campaign,
hosted Native/sanitizers, Linux/Windows Godot and shader v3. The #390 interest test
must actually execute on both Godot platforms. The new MAT354 workflow is scoped
to its unchanged probe/fixture/tools/workflow paths and is not independently
dispatched by this documentation reconciliation.

**Execution status belongs to the [live PR ledger](https://github.com/techrote/cybersand/pull/379).**
This committed registration does not predeclare those gates passed. The final
record must bind actual head/tree, test-merge parents, runtime/executable hashes,
real job steps, retained failures and an independent review of the final candidate.
No merge, parent closure, #383 transition, physical-device or human-feel acceptance
is supplied here. The retained shader-v2 diagnostic remains FAIL under the existing
registered v3 classification; no threshold or classification is changed.
