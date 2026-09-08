---
title: Documentation maintenance and retrieval contract
status: Current
document-kind: guide
scope: Required documentation synchronization, canonical ownership, retrieval corpus and evidence workflow
canonical-for: [documentation-update-checklist, rag-schema, retrieval-policy]
last-reviewed: 2026-09-08
related-documents: [../reference/retrieval-index.md, ../reference/validation-evidence.md, source-checkpoint-and-recovery.md]
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
excluded from default answers. When chunking, attach title, scope, status, date,
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
5. **Synchronize routes.** Update the manifest, retrieval question destinations,
   documentation/retrieval indexes and roadmap. Update the handover for operational
   changes and owner-intent reference for new preferences. Preserve old anchors
   that still have useful incoming links or update every caller.
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
