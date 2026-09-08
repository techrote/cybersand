# 2026-09-08 structural rewrite retrieval evaluation

**Dated development evaluation; excluded from default current-answer retrieval.**
The rewritten corpus supplies sufficient top-five context for all 32 frozen
development questions, compared with 19 before rewriting. This is evidence for
the declared lexical configuration and reviewed questions; it does not certify
an embedding system, generated answers, or unseen questions.

## Scope and inputs

The [32 questions and source-backed expected facts](../reference/retrieval-questions.json)
were frozen before the structural rewrite. Their IDs and query texts are
unchanged. All 44 baseline files match pre-rewrite source checkpoint
`126175cfc4dd1fb8659212f62b9b517bac54d8c2` after newline normalization;
43 also match its Git blob bytes exactly. Raw snapshot hashes are retained.
The final run covers the rewritten working-tree documents on that source history;
its 47 document hashes are recorded in the
[portable JSON](2026-09-08-retrieval-evaluation.json). Future edits require a new run.

Baseline selection used the frozen focused-directory policy plus README/AGENTS
navigation. Historical audit directories and uppercase legacy routes were excluded.
Final selection uses the [explicit corpus manifest](../reference/retrieval-corpus.json):
canonical answer documents are selected, while navigation and dated records are
excluded. A canonical page can still contain explicitly qualified historical
evidence. Corpus selection, metadata, structure and wording changed together;
this comparison does not isolate their individual effects.

## Method and review rubric

The [stdlib evaluator](../../tools/docs/retrieval_eval.py) splits at Markdown
headings outside code fences, caps each body at 420 whitespace-separated words,
uses no overlap, and attaches available title, path, heading ancestry, kind,
status, scope, canonical topics and review date. BM25 uses `k1=1.2`, `b=0.75`,
the tool's fixed tokenization/stopwords, and the top five chunks. Query tokens
are sorted before summation; ties use path, heading and chunk part. There is no
stemming, query expansion, embedding, reranker, or answer-generation call.

Canonical hit@1/@5 means any chunk from an expected canonical route appears by
that rank. MRR@5 averages reciprocal first canonical rank, counting misses as zero.
These are route metrics, not answer correctness. For example, baseline Q01
found the handover first but did not supply actual identity/recovery facts;
baseline Q13 missed its canonical route while another passage supplied the answer.

The Codex evaluation agent reviewed all five contexts against every question's
source-backed facts. **Sufficient** requires all material facts and their
status/platform qualifications in the retrieved text. **Partial** provides some
but omits a material fact; **insufficient** omits the main answer. A link alone
does not supply its destination's facts. The final review reread every changed
context and retained the completed review of unchanged contexts. This was a
collaborating, source-informed model review, not a blind independent human grade.

## Results

| Measure | Before rewrite | Final rewrite |
|---|---:|---:|
| Selected Markdown documents | 44 | 47 |
| Heading/body chunks | 676 | 247 |
| Canonical hit@1 | 17/32 (53.1%) | 23/32 (71.9%) |
| Canonical hit@5 | 27/32 (84.4%) | 32/32 (100%) |
| MRR@5 | 0.6333 | 0.8385 |
| Sufficient top-five answer context | 19/32 (59.4%) | 32/32 (100%) |
| Partial / insufficient context | 10 / 3 | 0 / 0 |
| Observed misleading historical substitution | 0 | 0 |

The last row has a narrow meaning: no reviewed context explicitly promoted a
historical platform result into a fresh current-platform pass. Historical passages
still sometimes rank, including a clearly scoped upstream study for the crate
question. This is not a guarantee about how another answer generator uses them.

The first stable rewritten candidate reached 31/32 route hits and only 22/32
sufficient answers. Review exposed missing nearby qualifications about recovery,
worker APIs, Web order, bounded crate displacement, packed bridge limits, save
omissions, tile geometry, sparse-world limits, allocation scope and Water shimmer.
Editors repaired canonical direct answers and natural concept headings, preserving
old anchors. Questions were not rewritten to match rankings. These iterations
make this an openly tuned development set, not a held-out benchmark.

## Per-question comparison

Rank is the first expected canonical route among five chunks; answer grades use
the complete retrieved context. The JSON includes all expected facts, source
references, top-five paths/headings/part identities, context hashes, supporting
ranks and individual review reasons for both runs.

| ID | Frozen question | Canonical rank before → after | Context grade before → after |
|---|---|---|---|
| Q01 | Which exact local version do we have, and can I recover its uncommitted changes? | 1 → 1 | insufficient → sufficient |
| Q02 | Who is allowed to mutate the cells, and can a worker touch a Godot object? | 5 → 1 | sufficient → sufficient |
| Q03 | Does enabling browser threads let drawing continue while the simulation tick is still running? | 2 → 2 | sufficient → sufficient |
| Q04 | What CPU counts does Auto choose in compatibility and threaded Web builds? | 1 → 2 | sufficient → sufficient |
| Q05 | Are body physics, the player, and cellular updates ordered the same on desktop and Web? | 1 → 1 | sufficient → sufficient |
| Q06 | What happens to play when a native simulation tick fails? | miss → 1 | insufficient → sufficient |
| Q07 | Are we using Rapier or Godot physics, which version, and who advances it? | 1 → 1 | sufficient → sufficient |
| Q08 | When a crate moves across sand, do we erase its old pixels and put them back? | miss → 2 | partial → sufficient |
| Q09 | What prevents terrain contacts and sand coupling from pushing a body twice? | 5 → 1 | sufficient → sufficient |
| Q10 | What exactly crosses the rigid body bridge, and how many bodies can it handle? | 1 → 1 | partial → sufficient |
| Q11 | If importing a level gives the exact same save string, will the next tick replay exactly too? | 1 → 1 | sufficient → sufficient |
| Q12 | What is inside a CYSD1 file, and can it save an arbitrary sparse world? | 5 → 1 | sufficient → sufficient |
| Q13 | Can saving the level alter anything, and does a bad import damage the running world? | miss → 1 | sufficient → sufficient |
| Q14 | Do matching state hashes prove complete deterministic replay, including bodies and future inputs? | 1 → 1 | sufficient → sufficient |
| Q15 | Can the renderer read live cells or reuse a patch buffer before upload finishes? | 4 → 2 | sufficient → sufficient |
| Q16 | If all snapshot slots are still in use or a patch is too large, is dirty data lost? | 1 → 1 | sufficient → sufficient |
| Q17 | Dirty rectangles are small, so are we uploading only those pixels to the GPU? | 3 → 2 | sufficient → sufficient |
| Q18 | Are simulation tiles double buffered, and how are writes into a neighboring tile made safe? | miss → 1 | partial → sufficient |
| Q19 | Is the world really limited to 1024 pixels or twice the camera size? | 2 → 1 | partial → sufficient |
| Q20 | What happens if I enqueue too many explosions or run out of reserved simulation space? | miss → 1 | insufficient → sufficient |
| Q21 | Does native Water move twenty-four cells per update, and what does viscosity mean? | 1 → 1 | sufficient → sufficient |
| Q22 | How do calm water emission and the adhesion toggle differ? | 1 → 1 | sufficient → sufficient |
| Q23 | How should I tell whether a shimmering pool is a fluid bug or just its shader? | 1 → 1 | sufficient → sufficient |
| Q24 | Can we approximate interactions to keep frame times stable, and is strict mode available now? | 1 → 3 | sufficient → sufficient |
| Q25 | Can we move authoritative materials to GPU compute, or author their rules in arbitrary JavaScript? | 1 → 1 | partial → sufficient |
| Q26 | Do SimulationCore and GameplayBridge already exist as reusable implementation modules? | 1 → 3 | sufficient → sufficient |
| Q27 | What smoke, pressure and heat simulation actually runs today? | 1 → 1 | partial → sufficient |
| Q28 | Which exact tools should I build with, and can I share the native and Web bindings checkout? | 1 → 1 | partial → sufficient |
| Q29 | If an export checksum passes or build-info names the base commit, is the browser build proven current? | 3 → 3 | sufficient → sufficient |
| Q30 | Do the old sanitizer results and current Windows fixtures prove Linux, Firefox and Safari work? | 1 → 1 | partial → sufficient |
| Q31 | Why is the old consistency check red, and should I update its hashes to make the release pass? | 4 → 3 | partial → sufficient |
| Q32 | After changing physics ownership, which documentation and evidence must I update before a checkpoint? | 2 → 1 | partial → sufficient |

## Separate supplementary challenges

Two [source-discovered challenges](../reference/retrieval-challenges.json) were
added during the audit and are scored separately: failed ticks may retain
partial progress, and offscreen phased cells may sleep without re-entry wake
while SerialInPlace ignores region filtering. Both have canonical hit@1 and
sufficient top-five context (2/2). They are not held out and have no claimed
before/after improvement. Their expected facts and reviewed passages are in
the JSON; [dated diagnostics](2026-09-08-foundation-diagnostics.md) preserve
the source-built evidence. Retrieving a defect does not mean it was repaired.

## Fixture corrections and reproducibility

Provisional destination names were replaced with the actual canonical paths for
source identity, saves/replay, validation evidence, local builds and maintenance.
Existing baseline route aliases remain; these changes did not change baseline
ranks. Q20's initial blanket no-hot-allocation expectation was corrected to an
**Approved** requirement with **Current** evidence limited to prepared fixtures;
lazy coordinator preparation can allocate chunk/temperature storage. The same
corrected fixture is used for both final runs. During initial fixture preparation,
guessed source filenames/symbols were replaced with inspected existing names.
The full correction log is embedded in the JSON. No query ID or text changed.

Both final runs use evaluator SHA-256
`a68ebed677cdd2916b18dfc065fe59245c4690707f2d6083e07d108a7b523e59`
and fixture SHA-256
`83f981b1992e62cc7627b44bb640b4f0f8ee01bfccb1dd64eebc27ec7f193094`.
The final manifest SHA-256 is
`f380474c97955bdae96ddc113d4e190108dcfb859a424e47ec4f81b7acb7e0a2`.
Raw hashes include line endings; scoring normalizes Markdown newlines, so a Git
LF checkout can reproduce scores while differing from captured CRLF file hashes.

From the source repository, create an ignored output directory and run:

```text
python tools/ci/check_docs.py
python tools/docs/retrieval_eval.py --output <existing-output-directory>/retrieval.json
python tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output <existing-output-directory>/challenges.json
```

For the baseline, use a separate read-only checkout/export of `126175c` and pass
its source root with `--root`; keep the current evaluator and corrected fixture.
The raw local snapshot and complete contexts are retained under
`C:/kybersand/validation/local/rag-rewrite-20260908/`, outside source history.
The portable JSON carries corpus/context identities and per-question assessments;
it does not embed every raw context or replace the source history.

Checks passed on Windows x64/Python 3.12.14: syntax checks for both tools;
identical baseline and final rankings, scores, contexts and input hashes under
Python hash seeds 1 and 777; frozen-question/baseline-content comparison; and
structural checks for 47 canonical documents, 8 navigation entry points,
81 unique topic owners, 680 local links,
26 anchors and 32 questions. An isolated checker smoke accepted a valid fixture
and rejected duplicate ownership, a missing file and a missing anchor.
These checks do not fetch external URLs or attest executable source semantics.
Simulation tests and historical failing gates retain their own
[evidence scope](../reference/validation-evidence.md).

## Readiness and next evaluation

The hierarchy is ready for bounded foundational work with explicit source,
status and evidence routes. No reviewed development question remains unanswered
by the final top-five context. Remaining simulation policy/correctness issues
are intentionally documented in the [roadmap](../reference/status-and-roadmap.md).

Keep this set as a development regression and apply the
[maintenance checklist](../operations/documentation-maintenance.md). Next freeze
an unseen question set and evaluate the actual chosen production retriever and
generated answers, including source/status attribution, multi-hop questions,
negative questions and paraphrases. That work is necessary before making broader
RAG quality claims; another wholesale prose rewrite is not supported by this result.
