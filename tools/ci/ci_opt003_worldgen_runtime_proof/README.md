# CI-OPT-003: bounded complete-worldgen proof

This branch is a disposable measurement lane, with no PR or intended merge. It
adds only the seven proof/controller files. The fixed baseline is
`cd32ed95b1c3da1d5e8bbecc8020f68e13fe1d55`; the repaired candidate is
`19023b4016facfda2b13b9a1503742e4a9fe1982`. Its exact source must be independently
reviewed before publication.
The superseded `28ec075afab840cf6fbb35190a7b1915808904f3` candidate is excluded:
its grouped output could lose flushed hung-peer diagnostics during termination.

## Predeclared measurement

Run once, in one Ubuntu 24.04 job. Execute the complete baseline worldgen family,
then the complete candidate family on the same worker. Each arm starts from its
own clean fixed-source worktree with no build directory. Do not restore compiled
artifacts, add compiler/shell instrumentation wrappers, retry tests, reduce case
counts or increase the original concurrency. Both arms use literal `gcc-13` and
`g++-13`. Cold means absent build outputs; it does not claim a reset OS page cache.
The baseline-first order is fixed rather than selected after observing results.

The original `run_native_family.sh` executes all three original commands:

1. Sanitized physics characterization: original native compilation, all 154 CLI
   invocations, and the original material/accounting assertions.
2. Normal worldgen: all 28 compilation/link commands, seven showcase suites and
   the nine ordered principal suites.
3. Sanitized worldgen: all 28 compilation/link commands, seven showcase suites
   and the nine ordered principal suites, with the original ASan/UBSan settings.

Each arm uses its own original planner and command owner. Physics has 10,200
seconds, each worldgen target has 3,600 seconds, and the complete family has
18,120 seconds. Neither arm's allowances are shortened. The hosted job has a
360-minute cap, which is less than the sum of both worst-case allowances. A cap
hit is incomplete failure and cannot support admission.

## Original evidence and strict offline verification

The controller captures source/tree/Makefile and canonical source fingerprints
before and after execution, compiler binary hashes/version/target, worker and
image identity, proof SHA, run and attempt. Only after the proof pre-snapshot
runs, the family shell exports `GITHUB_SHA` to that arm's actual source SHA. The
next capture step retains the proof commit environment; only its original shard
recorder subprocess receives the arm SHA. This keeps new showcase headers bound
to the executed source without misidentifying the proof controller itself.

The original full-source recorder must have no errors. Original run.log, both
exit files, every command receipt/log/performance row, the original build
inventory, every physics JSONL/stderr/result, binary digests and the candidate's
14 raw showcase logs are retained. Raw source output paths are uploaded under
`always()`, so capture failure does not hide partial files. Binaries are not
uploaded. Hard host termination may prevent upload; missing evidence fails.

The offline reader loads each arm's original verifier, planner, build-inventory
checker and physics tests from immutable Git blobs, never artifact-supplied code.
It checks exact context, original command argv/watchdogs, natural successful
completion, original byte hashes, source snapshots, ordered child-log custody
and the top-level run log. It separately parses every real compiler command and
all 7+9 actual execution markers in each worldgen command, checks the raw forced
build inventory and compares source-derived compilation/test/watchdog contracts.

For physics, it requires the exact 154-name manifest and original ordered argv,
watchdogs and output hashes. It reapplies the original scientific assertions to
the retained outputs offline without launching any native executable. The
candidate's 14 durable logs require exact source/run/attempt/binary headers and
nonempty original output through the candidate's canonical reducer. The two
arms may differ in the added diagnostic retention obligation, not in scientific
cases or instrumentation.

Run against a downloaded artifact and a repository containing the fixed Git
objects, taking the expected proof/run/attempt identities from GitHub:

```sh
python3 tools/ci/ci_opt003_worldgen_runtime_proof/compare_pair.py \
  --repository /path/to/repository --directory /path/to/family-artifact \
  --suite worldgen --run-id RUN_ID --run-attempt 1 \
  --proof-sha EXACT_PROOF_COMMIT --output /path/to/reviewed-comparison.json
```

Reader controls use explicitly synthetic receipts and outputs. They test reader
rejection behavior and are never evidence of native execution:

```sh
python3 tools/ci/ci_opt003_worldgen_runtime_proof/test_compare_pair.py \
  --repository /path/to/repository
```

## Scope and stopping rule

A successful comparison qualifies only the complete paired-family measurement.
It never marks all Native checks, platform qualification or routine CI complete.
The production PR's real applicable required checks remain mandatory. Report the
one-pair observed difference, all three command times, first completed functional
command and worker identities. Obtain actual hosted job runner-minutes and
queue/setup/artifact overhead separately from run metadata. Do not infer a
percentile or reliable population speedup from this single ordered pair, and do
not repeat an inconclusive or failed experiment merely to select a favorable
sample. Merge admission still requires independent safety/performance review.
