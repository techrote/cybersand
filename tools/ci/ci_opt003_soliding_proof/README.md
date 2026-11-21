# CI-OPT-003: bounded soliding proof

This branch is a disposable measurement lane, with no PR or intended merge. It
adds only this controller and its workflow. The production candidate is PR #722
at `cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55`; the fixed baseline is
`846fe0533b3170e7b01f690518da49fc40cc24d1`.

## Predeclared measurement

Run once, with two Ubuntu 24.04 jobs: one complete `soliding-normal` pair and one
complete `soliding-asan` pair. Each job executes baseline then candidate on the
same worker. Each arm starts with a separate clean fixed-source worktree and no
build directory. There are no restored artifacts, compiler wrappers, retries,
test reductions, compiler flag changes, new inner parallelism or provider changes.
Literal `gcc-13` and `g++-13` retain the canonical compiler setting.

The actual unchanged `run_native_family.sh` performs all four normal commands or
all three ASan commands, including the separately timed settled-regions build.
The actual unchanged `run_timed_command.py` owns both each command and the whole
family. The original planner allows 15,160 seconds per normal arm and 11,520 per
ASan arm. Neither allowance is shortened. The hosted job has a 360-minute cap;
the sum of two worst-case allowances exceeds this cap, so a pathological pair
may be cut off and remain incomplete. No result from such a job is admissible.

## Evidence and admission

Before and after each arm, the controller re-reads the complete source identity
and canonical fingerprints from the original source, along with compiler binary
hashes, versions, target, worker, image, run and attempt. The original full-source
`verify_native_shards.py record` captures the shard. Its errors must be empty.
Original run.log, both exit-code files, all command logs/receipts/performance
rows, Stage3B JSON, source snapshots and binary digests are retained. Binaries
are not uploaded. The artifact step runs on failure and reads original source
output paths directly, preserving partial receipts even if capture fails. A hard
host termination can prevent upload; missing evidence remains failure.

`compare_pair.py` is an offline reader. It requires the exact proof SHA, run and
attempt from GitHub and a repository containing the fixed Git objects. It loads
canonical validation functions from the original immutable Git blobs, not from
artifact files. It rechecks all hashes, original command argv, planner watchdogs,
source contexts, natural successful completion, serial command order, nested
log concatenation and all eight actual test command lines in source order. It
requires both source-bound Stage3B files for normal runs and complete binary
digest inventories. Raw evidence, not a precomputed profile summary, determines
acceptance.

Run after downloading one family artifact:

```sh
python3 tools/ci/ci_opt003_soliding_proof/compare_pair.py \
  --repository /path/to/repository --directory /path/to/family-artifact \
  --suite soliding-normal --run-id RUN_ID --run-attempt 1 \
  --proof-sha EXACT_PROOF_COMMIT --output /path/to/reviewed-comparison.json
```

The offline consumer's positive/negative controls use explicitly synthetic
receipts. They verify the consumer and are never execution evidence:

```sh
python3 tools/ci/ci_opt003_soliding_proof/test_compare_pair.py \
  --repository /path/to/repository
```

This proof qualifies only each paired family measurement. It is never the final
required Native check, Linux/Windows qualification or routine-CI completion.
The candidate's real applicable checks remain mandatory and unchanged. Report
the one-pair observed difference, command times, first complete functional
command and worker identities. Obtain actual hosted job runner-minutes and
queue/setup/artifact overhead independently from the run metadata. Do not infer
a percentile or reliable population speedup from one ordered pair. Do not rerun
failed/inconclusive pairs merely to select a favorable result.
