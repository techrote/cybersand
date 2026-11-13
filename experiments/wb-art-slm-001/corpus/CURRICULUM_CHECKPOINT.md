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


## Second corpus checkpoint — theme/phrasing balance and genuine replay

**13 November 2026, after the archived source was re-materialized.** This is
additive on the corpus role branch; v1 ordering and the frozen step-400 model
remain unchanged. The original saved archive SHA-256
`2d2de250731eeea825339e89f752ab8ebc65f3a929daa2c692120d985566948a`
was reverified, along with all three admitted split hashes and the grouped
manifest digest. Development and final files were **hash-checked only**; no
final outputs or evaluator thresholds were accessed.

### Measured bug: global phrasing balance hid theme-level imbalance

The checked-in v1 candidate was globally 200/200 p0/p1 at 400 rows but
**coral/ribs were 33 p0 to 1 p1**, while **veins/mycelium were 1 p0 to
33 p1**. This is deterministic parity coupling of the twelve-theme round-robin,
not a model error. Other themes had the same ~32/1 imbalance. It is a concrete
training-data presentation defect: the first 400 samples presented essentially
one of the two original prompt forms for each theme.

Independently replaying Training's currently published
`keyword-replay-v1` sampler against the exact admitted train corpus
(seed 731, epoch 0, 400 **sample draws**, accumulation 1) gave **36 literal-word
draws, 322 distinct native traces, 70/72 groups, theme exposure 27–41, and
216/184 p0/p1**. Its 376 unique row indices should not be mislabeled
376 distinct native traces. These are sampling measurements, not training
results, and Training continues to own its sampler.

### Implemented new corpus-only v2 candidate

`build_balanced_replay.py` is a deterministic, opt-in alternative. It imports
the **original archived** admitted train data through the v1 loader and
rechecks its source/native bindings, then changes only ordering/selection.
It produces a 1,152-row exact-once balanced corpus, plus a separate
**400-draw diagnostic** that repeats each of the 12 literal words twice
after the initial 12. This is not a full-epoch training policy.

| Actual first-400 exposure | v1 ordering | Training keyword-replay-v1 | Corpus v2 replay diagnostic |
| --- | ---: | ---: | ---: |
| Literal-word draws | 12 | 36 | **36 (3 per theme)** |
| Distinct native traces | 400 | 322 | **376** |
| Structural groups | 72 / 72 | 70 / 72 | **72 / 72** |
| Theme balance | 33–34 | 27–41 | **33–34** |
| Global prompt phrasing p0/p1 | 200 / 200 | 216 / 184 | **200 / 200** |
| Per-theme phrasing | as skewed as 33/1 | variable | **16–17 per form** |

Twenty-four deliberately duplicated draws replace 24 otherwise distinct
source-admitted examples within the comparison window. They are **not new
positives, new independent structures or new native executions**. This
exposure comparison does not establish model accuracy, visual recognition
or production readiness.

The companion immutable
`curriculum_theme_phrase_replay_v2.json` pins the exact train/dev/final
custody digests and compiler, and the source v1, balanced order, balanced JSONL,
400-draw IDs and original row-index digests. A corpus regression suite
`test_balanced_replay.py` checks parity, trace/group coverage, word replay,
input refusal and exact archive-manifest regeneration; missing archive data
causes an explicit SKIP, not a fictitious native PASS.

Independent local prototype validation on the recovered archive passed
source split/manifest digest checks and exact balanced/replay hashes:

- Balanced order SHA-256:
  `8c4e1be31766926173eb8427a380b204cd14a0397d978700e5cb8223dc000915`
- Balanced JSONL SHA-256:
  `f6a2a03d6ed16c35dadd370bd070f1181cd9d0fc3c3450db69af8874c42b73da`
- Replay first-400 row-index SHA-256:
  `1e6492b13613622679850b22dfe85bec348d856eb29b5d2b5dedd8256db733ec`

Reproduce from the archived corpus extracted outside Git:

```bash
python experiments/wb-art-slm-001/corpus/build_balanced_replay.py \
  --corpus-dir /absolute/path/to/extracted/corpus \
  --out /absolute/path/outside/git/balanced-replay
WB_ART_SLM_CORPUS_DIR=/absolute/path/to/extracted/corpus \
  python -m unittest discover -s experiments/wb-art-slm-001/corpus \
  -p 'test_balanced_replay.py'
```

**Training handoff:** Neither the v1 ordered file nor this v2 first-400 replay
file automatically affects the existing trainer. Training may adopt a **new,
separately versioned sampler** only after checking this manifest's source
identities and ensuring an equal-draw, equal-optimizer-step comparison with
full checkpoint/resume. Do not rewrite an existing checkpoint policy or
implicitly increase a 400-step budget. The 400-draw design applies directly
only when gradient accumulation is 1; otherwise translate the sample cursor.

**Qualification:** no new training, current-main or Windows native execution,
visual review, material-law change, final-set evaluation or production promotion.
The pilot receipts remain at the distinct frozen Linux native source; #564/#565
remain external source owners. Draft/HOLD stays unchanged.
