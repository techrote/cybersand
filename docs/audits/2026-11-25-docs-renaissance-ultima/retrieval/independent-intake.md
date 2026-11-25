# Specialist C independent intake

Source inspected: #774 20170bd6259498c3d2774ab274567febb043fc1d; `AGENTS.md`, `tools/docs/retrieval_eval.py`, `tools/docs/retrieval_policy.py`. Written before reading A/B conclusions or proposed patches.

The lexical evaluator is small, deterministic and uncached; the current implementation is a reference development evaluator, not evidence of deployed production RAG. It scores the full rendered envelope equally with body terms, so repeated authority/title/path tokens and duplicate sections can compete with primary records. Evaluation identifies canonical paths, not required facts or answer correctness. Frozen evaluator/scoring must remain a separate baseline.

Initial hypotheses requiring reproduction: (1) chunk-level BM25 lets many chunks from one document consume top-k, reducing source diversity for multi-source questions; (2) manifest/fallback equality only holds when metadata declarations accurately mark excluded sources; evidence/research kinds are presently admitted unless explicitly excluded; (3) frontmatter duplicates outside three selected keys and non-exact closing delimiters may create ambiguous authority/claims; (4) default authority inference does not inspect contradictory Historical status; (5) a persistent index adapter does not currently exist, so cache safety is unqualified rather than proven defective. These are questions, not final findings.

No recommendations from the previous closure have been adopted as conclusions. Next: reproduce all five frozen reports, inspect exact misses and passage contents, test policy negative controls, measure evidence bytes and Git blob cost, and compare small generalizable retrieval improvements against unchanged original scoring.
