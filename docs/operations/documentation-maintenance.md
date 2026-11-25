---
title: Documentation maintenance and retrieval contract
status: Current
document-kind: guide
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-11-25
related-documents: [../reference/retrieval-index.md, ../reference/validation-evidence.md, source-checkpoint-and-recovery.md, microscenarios-programme.md]
---

# Documentation maintenance and retrieval contract

## What makes a page independently retrievable?

Every focused page has one clear purpose and frontmatter with `title`, `status`,
`document-kind`, `scope`, `canonical-for`, `last-reviewed`, and `related-documents`.
Use ISO dates and inline lists. `canonical-for` contains unique topic identifiers;
another page may summarize and link that topic but must not become a second owner.
Use informative headings, short source-backed paragraphs and explicit platform
names. Keep constants at their canonical configuration/API home.

The default corpus is the explicit [retrieval manifest](../reference/retrieval-corpus.json).
It selects contracts, design decisions, guides and references. Navigation pages
route readers; historical records require an explicit historical question and are
excluded from default answers. Evidence, research packets and Draft records also remain outside ordinary answer selection unless their material is deliberately reconciled into a canonical current contract. When chunking, attach title, scope, status, date,
canonical topics and heading path to **every** chunk. A whole-page status alone
does not make a mixed Current/Planned subsection safe to retrieve.

| Claim label | Meaning |
|---|---|
| **Current** | Inspected executable source/configuration; runtime outcomes additionally require dated artifact/platform evidence |
| **Approved** | Accepted requirement or direction; implementation may be partial |
| **Planned** | Intended future work, not implemented or validated merely by being listed |
| **Deferred** | Deliberately postponed with the applicable scope stated |
| **Rejected** | Considered and intentionally declined; not silently reopened |

Frontmatter `Approved design` is the existing checker-compatible alias for
Approved. `Ambiguous` marks unresolved evidence or intent, not approval. A page's
status describes its purpose; label conflicting or future claims individually.
Source establishes present behavior; ADRs establish accepted direction. If they
disagree, record both and the missing decision before changing implementation.

## Current selection, fallback and historical authority

Authority and retrieval selection are separate. Keep the supported authority
values `current-documentation`, `owner-confirmed-intent` and
`historical-non-authoritative`; this programme adds no new authority category.
Every chunk preserves an explicit `owner-confirmed-intent` declaration. That
source can establish approved direction, but its inclusion in current retrieval
does not turn desired behavior into delivered implementation or task permission.
The flat metadata field `retrieval: explicit-only` marks a current-path research
or execution packet that is deliberately outside ordinary answers. Omitted
`retrieval`, or explicit `retrieval: default`, permits current selection subject
to the manifest and authority checks. It does not mean the claims are approved
implementation or verified runtime behavior.

The default [manifest](../reference/retrieval-corpus.json) is authoritative for
selection. Its excluded focused packets also carry `retrieval: explicit-only`
so the missing-manifest fallback preserves that boundary. The evaluator refuses
explicit-only, navigation, evidence, research and Draft documents in a default
manifest and in direct default chunking. Fallback discovers the focused architecture, systems, operations,
reference, decisions, research and tools directories plus `MATERIAL_LAB.md`, then
excludes navigation, evidence, research, Draft and explicit-only packets. It validates authority first, so
an excluded packet cannot hide malformed authority or a copied historical tag.

The supported flat parser accepts quoted/padded field names and ordinary quoted
selection values. All duplicate source keys, malformed frontmatter delimiters,
unsupported selection/document-kind/status syntax and stale caller metadata fail
closed before ingestion. A copied Historical/Superseded/Archived status retains
historical authority even outside archive paths; it cannot become a current
instruction by losing its authority tag. A second document-kind cannot override
an earlier exclusion. This is not a guarantee for arbitrary YAML anchors, tags or
complex keys. [Current-selection tests](../../tools/ci/test_current_retrieval_selection.py)
exercise manifest, fallback and direct chunking, including real-corpus equality;
the original [historical tests](../../tools/ci/test_historical_retrieval.py) remain
separate and unchanged.

Explicit `--historical` retrieval still requires the isolated historical manifest
and puts `historical-non-authoritative` plus a non-current instruction warning on
every chunk. Existing `retrieval: explicit-history-only` archive metadata retains
its own accepted scope; it is not parsed as a new current selection value. No link
expansion imports audits into default context. Direct agent instructions must
observe the same boundary rather than recursively loading every historical link.

The local evaluator reads no persistent cache. Selection policy is now
`historical-isolation-v4`; external indexes must rebuild with the current
selection rules and per-chunk authority envelope before claiming equivalent
containment. This repository cannot attest an unseen external cache, vector
index or assistant prompt assembly.

## Source-bound reference adapter and safe index rebuild

The [local reference adapter](../../tools/docs/knowledge_retrieval.py) is a
separate proposed retrieval method. The frozen lexical evaluator remains intact.
The adapter applies BM25 with explicit heading/title fields, one passage per
document and at most one additional route to an already admitted primary
owner-intent record linked from the best document. It does not use query IDs,
expected answers, target-path rules, embeddings or a provider model. Source routes
do not automatically ingest linked audits or archives.

```sh
python tools/docs/knowledge_retrieval.py --query "Who owns live physics objects while native workers run?"
python tools/docs/knowledge_retrieval.py --query "What does the owner intend for authored worlds?" --cache /tmp/cybersand-current-index.json
python tools/docs/knowledge_retrieval.py --historical --query "What did the earlier stored Cell experiment measure?"
```

On Windows choose a temporary path such as `$env:TEMP/cybersand-current-index.json`
in PowerShell. The optional JSON snapshot is a reproducible local context cache,
not a production vector database or a promised speed optimization. Every use
rehydrates selected documents from source, checks complete current metadata,
compares manifest/helper/document and linked-code digests, and validates every
cached chunk. Source changes, removal, renaming, a new exclusion or historical
mode change rebuild the snapshot and remove formerly admitted text. Malformed
current authority fails closed instead of serving an old cache. Explicit history
uses a distinct identity and preserves its envelope. Cache files belong outside
tracked source.

All current answer paths—manifest, fallback, direct chunking and the adapter—
require complete metadata and a valid review date. Navigation and explicitly
excluded packets cannot become answers through missing fields; explicit archive
retrieval retains its non-authoritative envelope even for unlabelled originals.
The unit fixtures now declare valid current metadata; the five frozen query sets
and lexical scoring code remain unchanged. All scalar/list ambiguity, authority,
selection, kind and status fields are checked by the shared policy.

A consumer can query, inspect the supplied routes, and explicitly follow one
linked source with `--source <exact-repository-path>` on the same `--query` call.
Every query also rechecks source identity on an already-live adapter instance.
A changed or removed source invalidates that instance before any passage is
returned; create a fresh instance to rebuild. Source-following refuses stale or altered contexts,
unlinked targets, path escape, historical access without opt-in and unselected
Markdown answer pages. It returns source bytes and digests with a separate
inspection-only scope. Source inspection does not establish implementation
acceptance, owner authorization or a passed runtime test. A consumer must still
interpret source, status and unresolved decisions; this tool does not fabricate
an answer when no owner decision exists.

```sh
python -m unittest discover -s tools/ci -p test_knowledge_retrieval.py
python tools/docs/knowledge_retrieval.py --queries docs/reference/retrieval-questions.json --output /tmp/cybersand-reference-evaluation.json
```

Compare the proposed method and unchanged baseline separately on frozen and
independent holdout questions. Review actual supplied contexts, source-following
steps and safe abstentions independently; rank improvement alone is not evidence
of generative-model or production-agent accuracy. No external deployment, paid
provider or model execution is implied by this reference adapter.


## Does an old Approved instruction authorize restoring a runtime?

A September audit or earlier execution packet retains its original source,
date and scope even if it says **Approved**, **Current**, or tells an agent to
restore a runtime. Historical evidence does not authorize that action today.
Ordinary retrieval excludes historical paths; an explicitly requested historical
chunk carries a non-authoritative envelope. A quoted old instruction inside a
current programme page must also state its dated applicability locally.

Before changing a runtime, inspect the present checkout and active task, then
follow [current source validation](current-and-historical-validation.md) and the
[source-matched publication contract](github-development-and-release.md#source-matched-runtime-publication).
Preserve the old receipt; do not edit an old hash, resume an old branch assignment
or substitute an earlier pass for current source and publication custody.

## Documentation-update checklist

Apply this at every implementation checkpoint, including tuning-only changes.

1. **Identify the actual inputs.** Record source Git root/HEAD/branch/status,
   relevant LFS objects and dirty paths; name a recoverable checkpoint. Preserve
   user work. Use [source checkpoint guidance](source-checkpoint-and-recovery.md).
2. **Map changed claims.** Search symbols, old values, aliases and reverse links.
   Review the affected subsystem, ownership/lifetime, interface layout, invariants,
   configuration/capacity, ADR, roadmap, build/test guide and user controls.
   A change matrix should name each affected page or explain why it is unaffected.
3. **Edit canonical homes first.** Attach source path plus symbol to important
   Current claims; use stable named sections for cross-links. Explain native,
   desktop, Web and fallback differences wherever they change the answer.
4. **Reconcile statuses and uncertainty.** Distinguish code from Approved intent.
   Record partial enforcement, failures, missing tests and decisions precisely.
   An observed defect must not become a promised invariant by omission.
5. **Synchronize routes and execution order.** Update the manifest, retrieval
   question destinations, documentation/retrieval indexes and roadmap. Update the
   handover for operational changes and owner-intent reference for new preferences.
   When a dependency/order/scope decision changes, update its canonical programme
   graph and all affected GitHub issue mirrors/comments in the same checkpoint;
   issue numbers and creation dates are never an ordering authority. Preserve old
   anchors that still have useful incoming links or update every caller.
6. **Record evidence separately.** Include date, command, timeout, OS/architecture,
   tool/dependency versions, fixture/configuration/profile/worker count, source
   revision plus dirty-file identity, artifact hashes and actual outcome. Identify
   whether evidence is inspection, compile, checksum, HTTP, native runtime,
   browser runtime or visual acceptance. Name exactly what was compared: level
   bytes, content/state hash, conservation, body tolerance or full replay.
7. **Preserve history.** Keep past results, failures, inconclusive runs and release
   hashes intact. Add a new evidence record and scope/link the old one. Never
   update historical hashes to make a new revision look validated.
8. **Check structure and retrieval.** Run the commands below. Inspect answers to
   affected natural questions for factual completeness and wrong-status/platform
   substitution, not only keyword hits. Add questions for newly discovered gaps;
   report them separately from a previously frozen evaluation set.
9. **Review the final diff and checkpoint.** Verify implementation scope, generated
   files and history preservation. Commit the authorized change locally with its
   validation report. State unresolved contradictions and readiness limits.

## Checks and evaluation interpretation

From the source root:

```text
python tools/ci/check_docs.py
python tools/ci/check_repository.py
python tools/ci/check_m11_consistency.py
python -m unittest discover -s tools/ci -p test_historical_retrieval.py
python -m unittest discover -s tools/ci -p test_current_retrieval_selection.py
python -m unittest discover -s tools/ci -p test_knowledge_retrieval.py
python tools/docs/retrieval_eval.py --output <local-output.json>
git diff --check
```

[check_docs.py](../../tools/ci/check_docs.py) checks metadata, unique ownership,
corpus coverage, local links/anchors and frozen question references. It cannot
validate source semantics, external sites or runtime claims. The M11 checker
verifies immutable records against the audited Git revision. Current provenance
and explicit strict historical comparison are [separate gates](current-and-historical-validation.md);
report integrity failures and current-file drift with their distinct scope.

[retrieval_eval.py](../../tools/docs/retrieval_eval.py) evaluates deterministic
heading chunks with BM25 against the [frozen questions](../reference/retrieval-questions.json).
Report hit@1/hit@5 and rank metrics with manual expected-fact sufficiency. A
canonical hit alone can still omit a crucial qualifier. This is a development-set
lexical baseline, not proof about an embedding model, a deployed vector database,
or unseen questions. Keep fixture wording stable during before/after comparisons;
disclose corrected expectations and iterations. Add independent future questions
before the next implementation checkpoint to avoid tuning only to this set.

## Updating documentation when a programme is accepted

Refresh accepted main and the principal live record before editing status. The
[current-state register](../reference/status-and-roadmap.md) owns the dated
programme snapshot; keep acceptance facts there instead of copying an active PR
ledger into every guide. The README presents durable capabilities and links to
current manuals, not a queue of Draft candidates.

| Accepted change area | Reconcile these canonical reader paths |
|---|---|
| Publication/progression or renderer/camera | Ownership/threading and rendering references, player controls, troubleshooting, validation interpretation |
| ObjectShard or actor/equipment behavior | Body/cell coupling, actor composition and usable contracts, player tutorials, save boundaries |
| Art providers/UI/lifetime | Provider/direct-batch contracts, Art user guide, cancellation/privacy and any actual setup labels |
| Architectural catalogue or SWARM | Generator contract, architectural walkthrough, terminology/limits and examples; only then README capability text |
| Batch/model orchestration or Gremlin | Accepted host/action/receipt contract, user/developer entry points and honest prototype/runtime boundary |
| Materials Lab audition | Declared/effective and candidate states, Lab user workflow, production-source boundaries |
| Strata Theatre integration | Layer ownership, current Workbench controls and persistence; retain standalone demonstration identity |
| Persistent areas/RAMCACHE | Authored-save versus physical-state contract, residency/catch-up and failure semantics, user recovery guide |
| CI engineering/publication | Accepted build/release/CI policy and exact-source procedures; preserve required case coverage and historical measurements |
| PAINT/history | Operation limits, partial receipts, Undo/Redo, protection and end-to-end tutorial |

For each update: inspect source, record the acceptance basis and remaining physical
limits, revise the canonical contract first, then the current-state register,
user guide, navigation, corpus and affected additive questions. Preserve old
captured evidence and frozen question sets. Rerun structure, containment, ranking
and a small source-grounded answer audit; explicitly distinguish the three
results. Update the asset manifest if an image's feature/source scope changes.
A changed status or screenshot caption must not imply tests that never ran.
