# WB-ART-SLM-001 — Corpus checkpoint: literal-first replay curriculum

**13 November 2026.** Corpus-owned work only, on codex/wb-art-slm-corpus.
This is a **new, opt-in ordering of the existing admitted training records**, not
a new positive corpus, a trainer change, a native qualification, or an improved
model score. The frozen 400-step candidate and its original sample order remain
unchanged. Integration alone may import this into combined Draft PR #567.

## Recovered evidence and custody

The original wb_art_slm_001_executed_corpus.zip was recovered from the owner's
saved Library artifacts. Exact original size **2,311,486 bytes**, SHA-256
2d2de250731eeea825339e89f752ab8ebc65f3a929daa2c692120d985566948a.
This is the actual executed corpus, not a new generator invocation. The code
requires its train/dev/final.jsonl, native_cases.json, manifest.json and
admission.json on disk; the large files remain outside ordinary Git.

The generator verifies byte digests of all three split files and the original
grouped manifest against the admission receipt; only TRAIN rows are parsed for
curriculum selection. Final rows are not opened or inspected, and development
prompts are not repurposed as training targets. For every training record it
verifies the literal completion against its program SHA, recomputes the
**actual ordered motif/layout structural signature after modifiers**, and
checks the source-identified successful native receipt, positive acknowledgement,
protection/masked-cell outcomes, and material ID. It independently rehashes the
archived native input operation list and matches program, exact host context,
geometry and receipt across both prompt phrasings.

This re-verifies **archived operation and receipt custody**, not the original
global Stop/history/save/reopen assertions and not fresh native execution.
No program, seed, geometry, native output or original receipt is changed; a
changed program would need fresh pinned native re-execution and global gates
before positive admission. The archived pilot is Linux headless at
90719c72b9fcf90593fb7878354051ad601b47fd, not current main or Windows.

## Actual measured ordering

| Measurement | Frozen step-400 order | Proposed deterministic first 400 |
| --- | ---: | ---: |
| Exact one-word training rows exposed | 6/12 | **12/12 by step 12** |
| Training themes represented | 12 | **12, 33–34 each** |
| Distinct native traces | Not claimed here | **400/400** |
| Structural groups | Not claimed here | **72/72 training groups** |
| Plain/enriched prompt phrasings | Not claimed here | **200/200** |
| Coral multi-layer compositions | Not claimed here | **18** |

The first 576 records expose each original training native trace once; the
remaining 576 are alternate phrasings of those same traces. Seed replicas,
two prompt phrasings and different native executions are not counted as new
independent families. Source shapes stay in their original split.

The sequence prioritizes existing TRAIN coral compositions (not held-out
coral split requests), veins' network motif and ribs' correct theme.
Observed malformed coral JSON and two literal-word semantic failures are
preserved by ID/digest in development_failure_inventory.json. No invalid model
output is relabelled a training success; no fabricated recovery turns.

Immutable order identities:
- Source train SHA-256: 972826e1af15a6babaff6e68e4c57d790c0c060a2befe050b4156c5f8ee05f66
- Ordered row IDs SHA-256: 8b0781624039e5b401d88f8440934bb6b8b14c8935181387678493e3fbb3351a
- Ordered JSONL SHA-256: ce9022b06303d90a3faf0533f75f7771ffe9f337271967d8f10101664c542ec5
- Compiler SHA-256: a259392c25643109cefbfc360e491a72731e4082e58b0ae8337c5c9a8023aadb

Use curriculum_literal_replay_v1.json as the exact small manifest. It contains
the original dev/final custody hashes, first-12 IDs and all first-400 balance
measurements. Reproduce the byte-identical sequence from the saved archive:

    python experiments/wb-art-slm-001/corpus/build_curriculum.py --out /absolute/path/outside/git/curriculum

The output ordered_train.jsonl is a **candidate input to a separately named**
training run, not to the frozen baseline. Training must opt its sampler into
the documented order instead of shuffling it away, and use its own role lease,
full checkpoint/resume and bounded deadline. An unused manifest changes
**zero model weights** and demonstrates **zero model-score gain**.

## Regressions and boundaries

The recovered archive passed four corpus-specific tests locally: two
deterministic/balance and cardinality tests, exact golden-manifest reproducibility
(including all 576 archived operation bindings), and corrupted-train-byte
custody rejection. Run:

    python -m unittest discover -s experiments/wb-art-slm-001/corpus -p 'test_curriculum.py'

Without the materialized archive, only two synthetic ordering tests execute;
the archive-dependent tests SKIP, which is not native evidence validation.

No compiler, provider, UI, physics law, material default, build system, final
assessment, evaluation threshold, Integration registry or another role's files
were changed. Current accepted main and #564/#565 remain external owners;
NeuroRunner stays read-only.

**Handoff:** Training should run one separately identified bounded A/B against
the unchanged step-400 baseline and the fixed DEVELOPMENT requests, reporting
literal-word sanity separately. Evaluation should independently inspect raw
malformed/semantic failures and native-replay any newly admitted model output.
Integration can consume this role branch only after checking the exact head
and source/compiler pins. Production remains Draft/HOLD.
