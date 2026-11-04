---
title: MAT-AUTH-002 recovery independent scientific and source review
status: Current
document-kind: evidence
scope: Independent review of recovered Phase A apparatus, current native source, latest hosted Linux raw observations and the proposed bounded deadline correction; no production authorization
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat354-findings.md, 2026-11-04-mat354-correction-admission.md, 2026-11-04-mat354-recovery-qualification.md]
---

# MAT-AUTH-002 recovery independent scientific and source review

## Verdict

**Scientific findings and the proposed correction boundary are supported.** The
recovered source contains no production scheduler, material-law, default or
compatibility-lock change. H1 is a demonstrated omission of cold MoltenGlass
cooling work; H2 is the existing neighbor-identity heating law; H3 is documented
sleep-dependent resting behavior whose production policy should remain unchanged
pending a separate decision. This review does not authorize a production fix,
claim owner gameplay acceptance, close #354 or approve a merge.

Reviewed apparatus commit: `1a06a0d88d295ed99983e7b1f6149b9fff84f1b3`.
Reviewed tree: `b1991936cd998e0c0f6caed04d6fc06150e0a559`.
Accepted production baseline: `7ef4856e225a2cc2a6e5c36ca33a2dab40e123f1`.
The fresh raw review used the Linux artifact from focused hosted run
[41817101140](https://github.com/techrote/cybersand/actions/runs/41817101140),
campaign receipt SHA-256
`b9f49386b96a09f70ce8cc6028f695e13512e04d4e6ccac90db27e24f1ca2820`.
Its case data was independently inspected; this review did not merely accept the
campaign's status field or the prior prose report.

## Independent checks performed

The review inspected the real `World` implementation, its active-block and
phase scheduling, `update_cell`, `schedule_pending_reaction_wake`, the generic
yielding-liquid path, Water-CY's separate retained-retry path, the native probe,
the scientific reader, the registered fixtures and the historical liquid-rest
contract. The probe includes production `world.cpp` once and uses the existing
friend for copied observations between ticks. Its reference random calculation
is diagnostic; actual movement and scheduling come from the real native World.

- The compatibility checker independently passed all **27 protected sources**
  with `production_cutover=false` and legacy baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`.
- The native source/include, bindings, Godot scripts and material compatibility
  tools have no delta from accepted main in the reviewed commit. `world.cpp`
  SHA-256 is `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`.
- All **38 actual compiler dependency inputs** in the fresh Linux receipt were
  authenticated byte for byte against blobs at the recorded source commit.
- All **1,104 case stdout/stderr streams** were authenticated against their
  recorded lengths and SHA-256 identities before reading results.
- All **552 cases and 88,384 rows** were checked for contiguous owner steps,
  complete horizon, native success/quantity status, actual phase-job totals,
  independently calculated thermal phase and deterministic random identity.
- **21,484 singleton thermal transitions** were checked directly against the
  inspected native law: thermal-lane heat reset to 180, cold decrement/conversion,
  and no off-lane thermal change when the source executed.
- **13,214 admitted generic-liquid draws** were checked against the descriptor
  threshold and actual direct/diagonal rejection, lateral-probe and move counters.
  No speculative random byte was treated as an executed draw.
- Independently derived physical argument groups yielded **261 matching complete
  worker/repeat trajectories**. The **48 generic awake/busy comparisons** also
  matched their complete traced subject tuples. Every one of the **eight**
  distributed cases with capacity four recorded four actual task claimants.

The machine-readable companion records these independently recomputed facts.
The separate CI evidence audit owns Windows artifact authentication, cross-OS
parity and workflow status; the present raw scientific review does not substitute
for that audit or requalify unavailable historical raw data.

## Causal findings

| Mechanism | Independently observed and source-supported result | Disposition |
|---|---|---|
| H1: isolated cold MoltenGlass | Quiet3 stops actual visits after ticks 3/4/5/6 for phases 0/1/2/3. The first omitted valid cooling lanes are ticks 4/5/6/7, with no job or subject execution. Quiet1024 and separated active controls convert at ticks 720/717/718/719 respectively. | Confirmed scheduler omission; a narrow existing-deadline correction is a supported next proposal. |
| H2: touching MoltenGlass | Pair and small-pool countdowns visibly reset from 7 to 180. Awake pair, 3×3 pool and 12×12 pool execute 1,536, 6,912 and 110,592 aggregate subject entries respectively through 768 ticks while retaining their material counts and representative state. | Existing thermal law. Infinite retention is a source-derived fixed-point inference, not infinite execution. |
| H3: generic yielding liquids | Paste/Slush/Brine/Mercury primary witnesses execute three failed draws then rest at quiet3. Awake controls first move at 19/7/4/6. Historical source and documentation already distinguish this from Water-CY's stronger mandatory-retry policy. | Preserve legacy behavior; a different retry policy needs separate admission and its own versioned trajectory evidence. |

The apparatus correctly distinguishes configured worker count from actual
claimants, traversal from admitted kernels, prospective random bytes from
consumed draws, and singleton counters from whole-World pool/distributed totals.
It records that a sleeping block can still be scanned when another block selects
the same core, so block flags alone are not used to prove starvation.

One interpretation qualifier should remain explicit: **preserving legacy rest
is not proof that the owner desires every material's late resting behavior.**
The historical Brine row leaves desired late rest as a future requirement, and
the historical study does not establish a constitutive heap/stress law. The H3
label therefore denotes the existing-policy boundary, not new gameplay approval.
This qualifier does not change the recommendation to preserve production.

## Proposed repair review

The helper-only proposal is consistent with the inspected source and does not
need a generalized scheduler framework. It must use the exact visible-neighbor
predicate **Fire/Lava/MoltenGlass**, not `is_hot()` because that also includes
Spark. Retain the strictly future existing period-four, stream-192 lane while a
cold countdown must decrement/convert or a hot countdown differs from 180.
Hot cells already at 180 may sleep.

The memo correctly preserves source-epoch checks, mask authority, region pause
without catch-up, worker-owned effect collection and owner-side barrier
publication. Shared deadlines must coalesce by minimum; removing one source
must not cancel another cell's obligation. One stale block wake may retire by
reevaluation without a per-cell allocation or full-world scan. Mixed sources,
Ice/compact obligations, state zero, hot sub-180/hot-180 cases and source/partner
visibility transitions remain successor acceptance cases, not tests of a fix
that has already been implemented.

The fix will add finite work and may also admit additional ordinary movement
opportunities for cold MoltenGlass while it remains eligible. Existing nearly
every-tick awake references are appropriately a cost/trajectory comparison,
not proof of only 180 total visits or a measured post-fix overhead. The proposed
scope preserves the generic Paste/Slush/Brine/Mercury policies.

## Publication and evidence boundary

Complete durable evidence publication and correct stale live summaries before
calling Phase A delivered. Keep missing or failed historical evidence visibly
qualified, retain the prior failed raw identities and conclusions, and distinguish
fresh verified replacement runs from recovery of their original bytes. The
report and PR should point to an authenticatable source-qualified packet rather
than an unfinished transport index. Exact final documentation/provenance checks
remain the integration owner's responsibility.

With those publication obligations handled, this review identifies **no
remaining scientific blocker to Phase A handover**. Keep PR #377 draft/unmerged
and #354 open. Production source changes and the #371 compatibility transition
remain a separately authorized task.
