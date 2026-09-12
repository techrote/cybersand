---
title: Issue 12 parsimonious multi-agent execution overlay
status: Planned
published-status: Planned
current-status: Planned
implementation-status: Planned
notes: Task-specific orchestration overlay for reversible-soliding research; does not replace issue #12, its programme supplement, accepted ADRs or source evidence.
document-kind: runbook
scope: Efficient Astra/Sol/Spark/Terra orchestration for issue #12 without unnecessary child cold starts
canonical-for: []
last-reviewed: 2026-09-12
related-documents: [agent-orchestration.md, physics-characterisation-plan.md, ../decisions/ADR-007-rigid-body-cellular-coupling.md]
---

# Issue 12 parsimonious multi-agent execution overlay

This overlay changes **how** issue #12 is executed, not what #12 is allowed to claim.
The live issue, its architecture-programme supplement, current source, accepted ADRs
and dated evidence remain authoritative for technical scope and gates.

The objective is to keep Astra's context focused on architecture and decisions while
avoiding repeated cold-start hydration of children. A configured model role is
available capacity, not a mandatory stage.

## Default execution shape

Use Astra High as the master on standard serving. Do not automatically enable Fast
serving.

The expected minimal path is:

```text
Astra: intake, source/evidence reconstruction, package design
  -> one reusable Spark child: Stage A diagnostics and related bounded repairs
  -> same Spark child where practical: Stage B stationary-proxy work
  -> one batched Terra xHigh review of the stable A/B integration if consequential
  -> Astra: draft ownership ADR
  -> one fresh Sol High deputy: independent ADR/state-machine challenge
  -> Astra: adjudicate and finalize ADR + Stage D admission
  -> one reusable Spark xHigh child if Stage E is admitted
  -> one Terra Max review of the stable Stage E integration
  -> Astra adjudication, bounded repair through the same Spark child, delta re-review
```

This is a target shape, not a quota. Omit a child whenever Astra can complete the
work safely and cheaply itself. Add a child only when the spawn gate in
`agent-orchestration.md` is satisfied.

## Context-loading policy

Do not give every child #8/#9/#10/#11/#12/#14 plus all ADRs by default.

Astra reconstructs the programme and prepares compact packets. Children receive only
the primary context needed for their package, plus links/paths to widen scope if a
specific uncertainty appears.

For example, a Stage A diagnostic packet should normally contain:

- exact diagnostic objective;
- relevant `World` symbols/files;
- candidate/rest definitions already frozen by Astra;
- required counters and bounded work policy;
- specific retained fixtures/evidence routes;
- intended write set;
- tests and acceptance conditions;
- explicit instruction to stop if support/ownership architecture would need changing.

It should not include the full ownership-ADR history merely because later stages may
need it.

The Sol deputy is the deliberate exception: at the ADR gate it receives the relevant
primary architecture/ownership evidence broadly enough to challenge Astra's design
independently. Terra receives the frozen contract plus stable diff and surrounding
source needed to test implementation compliance, not the whole programme narrative.

## Child reuse policy

Prefer continuing the same Spark child across closely related implementation and
repair work when its prior context remains correct.

Stage A -> Stage B may reuse one Spark High child if:

- Stage B builds directly on Stage A's implementation;
- the frozen architecture has not changed materially;
- the child's context is still accurate;
- reuse avoids duplicate repository/source discovery.

If Stage B changes the contract substantially, start a fresh child instead of carrying
misleading assumptions forward.

Stage E should normally use a fresh Spark xHigh child because the ownership ADR and
transition semantics create a materially different, higher-risk contract.

After Terra review, send accepted findings as a compact delta repair packet to the
same implementation child where possible. Re-review only the changed risk surface
plus necessary integration context; do not reload the full issue unless required.

## Stage A: diagnostics

Astra should perform the source/evidence intake itself and freeze the diagnostic
question before spawning implementation.

Default delegation:

- one Spark High child for candidate/rest/connectivity/occupancy/mutation/support
  telemetry and bounded dirty-region fixtures;
- Medium only if the package is genuinely mechanical and local;
- no Terra review by default for trivial instrumentation;
- Terra xHigh only if diagnostics alter scheduler/activity/region semantics or other
  consequential cross-cutting behavior.

Do not spawn Sol for Stage A unless intake reveals an actual architecture conflict.

## Stage B: stationary proxies

Prefer reusing the Stage A Spark child when the proxy implementation is a direct
extension and the contract remains stable.

Do not split proxy work into multiple writers merely because parallel capacity exists.
Use two Spark writers only when Astra can prove a meaningful critical-path win with
truly disjoint write sets and frozen shared interfaces.

Batch Stage A+B into one Terra xHigh review once the integration is stable when this
preserves defect attribution. Review earlier only if later work would compound a
high-risk defect.

## Stage C: ownership ADR

Astra owns the first ADR/state-machine draft from primary evidence.

Use **one fresh Sol High deputy** for an independent challenge after the draft is
coherent enough to critique. The packet should include the proposed state table plus
the primary ownership/coupling/failure evidence needed to falsify it.

Do not spawn multiple Sol deputies by default. A second independent Sol pass is
justified only if the first review exposes a genuinely unresolved architecture fork
or if the competing options remain materially close after Astra's adjudication.

Terra does not review the ADR as architectural authority.

## Stage D: admission

Astra performs the dynamic-prototype admission decision itself.

Do not spawn a child merely to restate the gate. Use retained evidence and the
finalized ADR. Spawn Sol only if a new architecture ambiguity appears that was not
covered by the ADR challenge.

A blocked/deferred result is legitimate completion of the gate.

## Stage E: bounded dynamic prototype

If admitted, start one fresh Spark xHigh child with a compact frozen transition
contract. Keep that child for implementation, accepted repair work and focused
follow-up tests while its context remains valid.

Do not pre-spawn Medium/High/xHigh variants. Select exactly one implementation tier
for the package. Add a second writer only if Astra proves an independent package whose
parallel completion materially shortens the critical path.

Use Terra Max once the consequential Stage E integration is stable. Give it:

- frozen ownership/transition contract;
- actual diff;
- relevant neighboring source;
- named conservation/capacity/failure/threading invariants;
- tests and known limitations.

Astra adjudicates findings. Accepted implementation defects return to the same Spark
xHigh child as a delta repair packet. Reuse the same Terra Max reviewer for repair
re-review unless an independent second opinion is specifically valuable.

Use Sol again only if a Terra finding or runtime result suggests the **contract** may
be wrong rather than merely its implementation.

## Review and validation batching

Prefer one review per stable risk-bearing integration wave, not one reviewer per
commit.

A normal issue #12 sequence should therefore need approximately:

- zero or one Terra review across Stage A/B;
- one Sol architectural review at Stage C;
- one Terra Max review at Stage E if admitted;
- optional delta re-review after accepted repairs.

This is not a hard count. It is the default against which extra spawns must justify
their context cost.

Run objective tests/validation as soon as useful, but avoid overlapping benchmark
campaigns with #19 or other local work when machine contention could invalidate
performance evidence.

## Parallelism

The default is serial within #12 unless an actual dependency DAG exposes independent
work. Two concurrent Spark writers are permitted only under the repository-wide
parallelism proof.

Read-only work may overlap when its input is stable. For example, Astra can inspect
unrelated evidence while Spark runs, or prepare the next compact packet. Terra must
not review a diff that Spark is still changing.

## Completion evidence

Record enough orchestration evidence to explain the result without preserving agent
chatter:

- package IDs and compact contracts;
- child reuse versus fresh-spawn choices where material;
- any parallelism proof;
- model/effort used for consequential packages;
- Terra findings and Astra dispositions;
- Sol ADR findings and Astra dispositions;
- exact tests/evidence required by the normal #12 programme.

A large number of spawned agents is not evidence of diligence. Fewer agents with
well-scoped contracts, preserved context and independent review at the actual risk
boundaries is the preferred execution pattern.
