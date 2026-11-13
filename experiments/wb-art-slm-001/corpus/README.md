# Executed pattern-program corpus

This bootstrap contains 1,536 reference text examples, covering all twelve
themes. A text example is not a new independently rendered scene: two prompt
forms share each of 768 exact program/seed traces. Another 96 seeds make the
192-image teacher gallery. There are 864 native cases in total.

| Split | Examples | Structural groups |
| --- | ---: | ---: |
| Training | 1,152 | 72 |
| Development | 192 | 12 |
| Final assessment | 192 | 12 |

Groups use the actual theme and ordered motif/layout signature. Each theme
holds out one single-layer and one composed layout; the held-out layout rotates
across themes. Exact programs and normalized prompts cannot cross splits. The
twelve literal theme words belong to training. This tests a limited ability to
combine familiar motifs and layouts; it does not demonstrate learning an unseen
morphology. New seeds are not counted as independent templates.

Eight modifier settings cover default, sparse, dense, thin, thick, twisted,
sparse/thin and dense/twisted. Symmetry and an open center are represented by
the split and border layouts. The six numerical fields in a program are
supervised as compact JSON, while seed, focus, material and execution authority
stay with the host. The corpus is synthetic and uses no private user material.

## Obtain the executed data

The complete data is delivered as `wb_art_slm_001_executed_corpus.zip`. Extract its
`corpus/` contents into this directory before using the training commands. The
archive includes the exact admitted train/dev/final files, native inputs and
per-file hashes. The source repository keeps the generator and compact identities;
bulk generated data stays in the artifact.

## Reproduce and admit

```bash
python experiments/wb-art-slm-001/corpus/build_corpus.py build
python -m unittest discover -s experiments/wb-art-slm-001/corpus -p 'test_*.py'
```

`build` creates `candidates.jsonl`, the grouped manifest and native replay input
files. It sets `native_qualified: false` on every candidate. It cannot create an
executed positive training file by itself.

After the native harness has produced its receipts and a reviewer has actually
viewed representative native images, admission is explicit:

```bash
python experiments/wb-art-slm-001/corpus/build_corpus.py admit \
  --receipts /absolute/path/normalized_receipts.json \
  --review /absolute/path/visual_review.json
```

Each admitted example must match the exact compiled-operation SHA256, have a
successful source-identified native receipt, nonzero acknowledgement, no
out-of-focus writes, and image/readback hashes. Every accepted structural group
requires an inspected representative. Uninspected modifier variants retain the
weaker `template-group-pilot-admitted` label; that is not per-image aesthetic
approval. `--allow-partial` is only for an explicitly counted first pilot. Raw
candidates, failures and excluded IDs remain available.

`admission.json` binds the actual train/dev/final file hashes to the receipts
and visual review. Final examples are not fed to training or development. Once
final results inform a repair, that final set must be retired into development
and a fresh final set created. The initial bootstrap deliberately contains no
fabricated recovery conversations; later recovery examples should come from
observed errors with the correct next action, not invalid targets labeled as
success.

The large deterministic `native_cases.json` and `gallery_cases.json` files can
be regenerated; they need not be committed to ordinary Git. The compact corpus
and manifests preserve their full hashes. Bulk native artifacts and model
checkpoints are distributed with the bootstrap artifact bundle.
