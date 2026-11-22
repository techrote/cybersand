# CI-OPT-003 — reproduce the evidence review

These instructions recheck the original measured evidence. They do not launch a new scientific workload, call a provider API, rebuild production binaries or substitute for the recorded hosted qualification.

## Inputs and trust

Use the repository's Git history and the privately supplied `CyberSand_CI_OPT_003_original_evidence.zip`. The outer ZIP SHA256 is `c4acd79239032db6c01b9a9484a48958bd3a9ac16ddc56938862304b6c5fce8d`. Its manifest lists eight nested original GitHub ZIPs and their full digests; the same public metadata is in `original-artifact-manifest.json`.

Obtain the canonical readers from their frozen Git commits, and the supplemental auditor from this evidence commit. Do not execute code supplied inside downloaded artifacts. Python 3, Git and GNU Make are needed for offline contract reconstruction. A Linux environment or WSL is suitable; this procedure is not evidence of physical Windows acceptance.

The repository must contain these immutable commits:

| Role | Commit |
| --- | --- |
| Initial accepted main | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| Soliding candidate / worldgen baseline | `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55` |
| Final worldgen candidate | `19023b4016facfda2b13b9a1503742e4a9fe1982` |
| Soliding proof and reader | `fd4921ace2c4f97f06c70b887778b2366d7a9f0f` |
| Worldgen proof and reader | `cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147` |

Fetch any missing commit from `https://github.com/techrote/cybersand.git`. Extract each proof's `tools/ci/ci_opt003_*_proof/` directory from its exact Git commit into a separate temporary directory, preserving the directory contents together. The readers import their accompanying `common.py`; copying only the entry point is insufficient.

Extract each nested original ZIP into a separate fresh directory. Its `proof.json`, `baseline/` and `candidate/` must be direct children of the directory passed below. The original producer's `comparison.json` is not an admission authority. Write all new readbacks outside those extraction directories.

## Accepted soliding comparisons

Use artifact `14730300616.zip` for `soliding-normal`, and `14731021438.zip` for `soliding-asan`. The reader's SHA256 is `ab0be75fd3cd58d0af24a2bd44b9dff392bbb6c73ab8729217b53c40dd6a573a`.

Run both configurations with the corresponding artifact directory:

```sh
python3 /path/to/frozen-soliding/tools/ci/ci_opt003_soliding_proof/compare_pair.py \
  --repository /path/to/cybersand \
  --directory /path/to/extracted-14730300616 \
  --suite soliding-normal --run-id 44961498877 --run-attempt 1 \
  --proof-sha fd4921ace2c4f97f06c70b887778b2366d7a9f0f \
  --output /path/to/new-readbacks/soliding-normal.json

python3 /path/to/frozen-soliding/tools/ci/ci_opt003_soliding_proof/compare_pair.py \
  --repository /path/to/cybersand \
  --directory /path/to/extracted-14731021438 \
  --suite soliding-asan --run-id 44961498877 --run-attempt 1 \
  --proof-sha fd4921ace2c4f97f06c70b887778b2366d7a9f0f \
  --output /path/to/new-readbacks/soliding-asan.json
```

The original reported family times are normal `190.811701 → 108.006146` seconds and sanitized `1285.232141 → 809.250157` seconds. Exact source, command, watchdog, binary, test-order and output checks must pass before using those measurements.

## Accepted whole-worldgen comparison

Use artifact `14732380696.zip`. Both the canonical reader and the mandatory supplemental replay auditor must pass against the same unchanged extraction. The canonical reader SHA256 is `6579cc7476996764cb21b4bfabd90bd3948d55c5e1d1c7c29b10e3c31c06a7a5`; the supplement's SHA256 is `540c4f5490529ec61f767736be8c23bc3451b0e1f383ec9ad5b0e7ce10e69c7a`.

```sh
python3 /path/to/frozen-worldgen/tools/ci/ci_opt003_worldgen_runtime_proof/compare_pair.py \
  --repository /path/to/cybersand \
  --directory /path/to/extracted-14732380696 \
  --suite worldgen --run-id 44963259696 --run-attempt 1 \
  --proof-sha cc22fb8ffbba2a7c18a0bc1c0ad60413ad5c3147 \
  --output /path/to/new-readbacks/worldgen.json

python3 /path/to/evidence/performance/audit_showcase_replay.py \
  --repository /path/to/cybersand \
  --directory /path/to/extracted-14732380696 \
  --run-id 44963259696 --run-attempt 1 \
  --output /path/to/new-readbacks/worldgen-replay.json
```

The canonical reader verifies the full family and reapplies the original physics assertions to recorded outputs. The supplement additionally requires all fourteen complete raw showcase payloads to match their unique source-derived replay groups. Neither reader alone replaces the other. The admitted family times are `1748.640266792 → 1232.409097826` seconds.

Record extraction hashes before and after review if independently checking custody. The original review verified that all 680 extracted worldgen files remained byte-identical.

## Rejected experiment and complete CI

PR #721's producer summary was insufficiently strict. Its result remains Draft/HOLD for insufficient measured value even though its corrected strict reader passes the original artifacts. Use `performance/first-candidate-final-verdict.md` and the independently reviewed reader recorded there; do not turn its old `comparison.json` into an approval.

The paired readers qualify their specific measurements only. Full PR and merged-main qualification are recorded separately in `integration-source-map.json`, the cohort summaries, independent reviews and linked GitHub runs. For final main's GDExtension retry, require attempt 2 artifacts and both coverage reducers at exact source `662df51cd8409a52332fa7ef15d06d8ab8945aed`. Retain failed attempt 1 in time and resource accounting.


## Final merged-main platform receipts

The separate `CyberSand_CI_OPT_003_postmerge_evidence.zip` has SHA256 `826c66f04d0f1738919b2ddb7d45e3620c69fdc1bee146088c1f333e0d0ac455`. Its manifest identifies seven unchanged originals; it does not replace the controlled-pair archive above.

For the platform receipt check, make a temporary copy of this evidence directory. Put nested original artifact `14733406653.zip` at `reviews/gde-main-coverage/windows-coverage-44967549040-2.zip` and extract its unchanged contents into the adjacent `windows/` directory. Similarly put artifact `14733112711.zip` at `reviews/gde-main-coverage/linux-coverage-44967549040-2.zip` and extract into `linux/`. The repository evidence supplies the original artifact metadata, terminal job/run records and independently derived expected source inventory in that same review area.

Run `python3 /path/to/copied-evidence/reviews/check_gde_main_coverage.py`. It checks exact original ZIP hashes, both coverage receipts, every job outcome and all thirty retained play-readback seals, then writes its new readback outside the extracted directories. The hosted production reducers performed the original raw shard-log verification. This offline receipt check does not replay every shard locally or execute scientific tests.
