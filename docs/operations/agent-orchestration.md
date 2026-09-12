---
title: Agent orchestration and subagent efficiency
status: Current
document-kind: guide
scope: Repository-wide rules for multi-agent coding, review, delegation, context handoffs, concurrency and model-role selection
canonical-for: [agent-orchestration, subagent-efficiency]
last-reviewed: 2026-09-12
related-documents: [cybersand-codex-development-handover.md, documentation-maintenance.md, ../reference/status-and-roadmap.md]
---

# Agent orchestration and subagent efficiency

CyberSand uses subagents selectively. Multi-agent execution is primarily a tool for
wall-clock parallelism, context isolation, specialist implementation and independent
error detection. It is not assumed to reduce aggregate token use: every fresh child
has a context/bootstrap cost. The default is therefore **the minimum number of agents
needed to gain a concrete advantage**.

## Spawn gate

Do not spawn an agent merely because a configured role exists. Before every spawn,
the parent should identify at least one material benefit that justifies cold-start
cost:

- genuine parallel work with a proven independent dependency path;
- specialist implementation that would otherwise pollute or consume a stronger
  master's context;
- useful model-family diversity for consequential code review;
- independent architectural reasoning where disagreement is valuable;
- context isolation for a large implementation/debugging trace.

Keep a task in the parent when it is small, serial, already well understood, or would
require a child to reload more context than the unique work justifies.

A configured lineup is a toolbox, not an execution checklist.

## Compact handoff packets

Give each child the narrowest sufficient primary context. Do not ask ordinary
implementation/review children to reconstruct the whole programme unless their role
actually requires it.

A bounded handoff should normally contain:

- package ID and one-sentence objective;
- frozen decisions and interfaces;
- exact relevant files/symbols or primary-evidence routes;
- bounded intended write set, or an explicit read-only scope;
- named invariants and failure semantics;
- acceptance tests/oracles and evidence to retain;
- explicit non-goals;
- escalation conditions that stop the child instead of letting it redesign scope.

Prefer links/paths to authoritative primary evidence over duplicated narrative. Add
small excerpts or normalized facts when they prevent unnecessary rediscovery, but do
not replace consequential primary evidence with a lossy lower-tier summary.

Sol/Astra architectural deputies may need broader primary context than Spark
implementation or Terra code-review children. That extra context must be justified by
the question they are answering.

## Reuse before respawn

When the same package needs a repair, follow-up measurement or re-review, prefer
continuing the existing appropriate child conversation if the environment supports
it. Supply the delta since its last stable state instead of hydrating a fresh child
with the same background again.

Spawn a fresh child when independence itself is valuable, the prior context has become
misleading, a different model family is deliberately required, or the task is genuinely
unrelated.

For example, a Terra reviewer that already reviewed package A should normally receive
the accepted repair diff for re-review rather than restarting the entire evidence
load. A fresh Terra instance is preferable when an independent second opinion is the
purpose.

## Parallelism discipline

Parallelism optimizes wall-clock time, not token count. Use it only when the saved
critical-path time is worth the duplicated bootstrap/tool work.

The repository default is at most **two concurrent write-capable implementation
children** for one task. Before parallelizing writers, prove:

- disjoint write sets;
- frozen shared interfaces;
- no dependency on the other child's result or decision;
- no concurrent edits to a shared registry, schema, generated file, build manifest,
  central fixture, documentation authority or integration point;
- an explicit stop/escalation rule if the frozen interface proves insufficient.

Different directories alone do not prove independence.

The parent owns shared-interface and integration edits. If overlap appears, stop one
path and serialize rather than allowing children to negotiate architecture implicitly.

Do not run overlapping performance/benchmark campaigns when they could contend for
the same machine resources and invalidate timing evidence, even if their source edits
are independent.

## Review batching and stable inputs

Do not reflexively spawn one reviewer per micro-patch. When several compatible,
independent packages form one integration wave, first integrate and run their local
oracles, then review the **stable combined diff** if that preserves the ability to
attribute failures.

Use a separate review earlier when a package is individually high risk or later work
would compound an error.

A reviewer must not certify a moving target. Implementation and independent review of
the same changing diff are serial. Tests and other read-only validation may run in
parallel when their inputs are stable.

For consequential implementation, prefer model-family diversity:

- Spark implements a frozen contract quickly;
- Terra reviews the actual stable diff against that contract;
- Sol checks whether the contract itself remains technically sound;
- Astra adjudicates the hardest programme/architecture decisions when assigned.

Terra review findings are evidence, not authority. A stronger parent/deputy must
adjudicate any finding that could change architecture, ownership, experiment validity
or a programme gate before it becomes a repair instruction.

## Model and effort policy

Repository defaults:

- **Astra:** hardest architecture, programme synthesis and consequential adjudication.
- **Sol:** trusted architecture/deputy reasoning, consequential investigation and
  review of whether the requested contract is correct.
- **Spark Medium/High/xHigh:** bounded implementation and debugging. High is the
  default for substantive coding; xHigh is for conservation, ownership, concurrency,
  lifecycle and difficult regressions.
- **Terra High/xHigh/Max:** primarily read-only review or narrowly extractive analysis.
  Do not let a Terra-only conclusion create architecture or programme authority.
- **Luna:** only where a hidden error is inconsequential or the complete output will
  receive human review.

**Never use Low effort for CyberSand orchestration.**

Do not automatically enable Fast/priority serving for Luna, Terra, Sol or Astra.
Standard serving is the default. Spark's native low-latency path plus selective
parallelism is preferred over assuming an additional Fast-serving mechanism.

Independent verification may justify stepping a master down one axis for a later,
frozen implementation task, but only when architecture and acceptance are already
settled, strong objective oracles exist, and a separate reviewer sees the actual diff.
Do not lower both model tier and reasoning effort at once. Architecture, experiment
admission, ownership design, ambiguous evidence interpretation and final programme
gates remain strong-master work.

## Strong-model context economy

Optimize for useful strong-model context, not merely aggregate token totals.
Astra/Sol should spend their context on architecture, evidence interpretation and
integration rather than routine implementation traces that Spark can own safely.

At the same time, do not save master context by inserting lossy summaries between the
master and consequential evidence. For architecture/gate decisions, provide primary
sources directly or use subordinate work as an index/navigation aid whose material
claims are independently checked.

Before spawning a child, ask:

1. What unique work will this child do?
2. What is the minimum primary context required?
3. Can an existing child be continued instead?
4. Can related review be batched after integration?
5. Does parallelism actually shorten the critical path?
6. Would the parent complete this more cheaply and safely without delegation?

If those questions do not produce a clear benefit, do not spawn.

## Evidence recording

For multi-agent work, retain enough orchestration evidence to reproduce the reasoning
boundary without logging private chain-of-thought:

- package/dependency DAG where nontrivial;
- worker/reviewer role and effort used;
- compact handoff contract or durable equivalent;
- serial/parallel decision and write-set proof where parallel writers were used;
- reviewer findings and parent dispositions for material issues;
- tests/commands and source/artifact identities required by the normal repository
  evidence policy.

Do not preserve verbose agent chatter merely to prove that delegation occurred. Keep
records focused on contracts, evidence, decisions and reproducible outcomes.
