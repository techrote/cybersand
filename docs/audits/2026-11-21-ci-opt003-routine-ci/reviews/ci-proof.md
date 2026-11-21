# CI-OPT-003 independent workflow and proof review

## Verdict

**Production CI contract GO; original proof comparator HOLD.** No confirmed
P1/P2 defect was found in the implementation's CI admission, required contexts,
watchdog or source/provenance contracts. One **P2 evidence-consumer defect** was
reproduced in the separate proof branch's comparator. Its retained results must
be reread by the stricter offline reducer before they support a merge decision.

This review does not establish a runtime speedup. Final-source hosted required
checks and the performance judgment remain separate gates.

## Reviewed identities and boundaries

- Accepted base: `846fe0533b3170e7b01f690518da49fc40cc24d1`.
- Implementation: `506dfc8c343c5d24fe26e89a9542cf985c52853e`, PR #721.
- Proof-only source: `371b9aef07e75cf99e20417884402a22a9ad58da`.
- Proof run: <https://github.com/techrote/cybersand/actions/runs/44959131042>.
- Independent read-only worktree: `/workspace/scratch/a3adba76fa99/ci003-proof-review`.

The implementation changes only Makefile prerequisite scheduling, a GNU Make
graph regression, and documentation. A direct Git comparison confirms that
`native.yml`, `gdextension.yml`, all six families and twenty outer commands,
`native_execution_policy.py`, `run_native_family.sh`, `verify_native_shards.py`,
the shared watchdog policy, native source and scientific fixtures are unchanged.
No new result cache, early-green context or publication path is introduced.

The proof workflow is restricted to its named research branch, has contents-read
permission, uses GitHub-hosted Ubuntu 24.04, bounds the matrix to two jobs, retains
independent failure outcomes, and runs each original/candidate target sequentially
on the same worker. Both source trees are immutable pinned commits. Preparation
checks exact input equality and invokes the original build-inventory checker.
Each profiled target remains under the unchanged 3,600-second command watchdog;
the 180-minute job budget includes both targets and preparation/capture headroom.
Failed preparation or comparison cannot make the job green. Artifact capture
runs even after failure. The proof never updates production required checks.

## P2 — comparison accepts incomplete or inconsistent raw command evidence

**Location:** `tools/ci/ci_opt003_proof/compare_profiles.py`, function `inspect`,
lines 18–24 and 32–33; comparison at lines 60–62.

`profile.json.verified_inventory` is compared between arms, while
`command-index.json` is checked only for successful statuses, 28 compiler rows,
two heavy compiler rows, and a concurrency bound. The comparator does not bind
actual compiler arguments or required test-shell receipts to the canonical
inventory, the summary or the individual raw receipt files.

Actual synthetic negative readbacks returned exit 0 and `status=passed` after:

1. Removing **every test/shell receipt** from the command index while keeping its
   profile summary unchanged.
2. Replacing a compiler argument list with an unrelated `-O0` build.
3. Replacing all command working directories with a different source/run path.

Reproductions are retained in `proof-negative/` beside this review. Their timing
values are deliberately synthetic reducer fixtures; they are not native/runtime
or performance evidence.

The producer `profile_make.py` already verifies the original compiler and test
inventory before creating its summary. The defect is therefore in **independent
artifact readback**, not evidence that the running hosted workloads omitted
tests. It does not require rerunning valid long jobs merely to repair the reader.
The original proof branch and all artifacts remain immutable.

## Correction prepared under the integration owner's instruction

`strict_worldgen_pair.py` is a separate offline readback implementation. It
ignores the original `comparison.json` and does not modify downloaded artifacts.
It checks:

- Exact baseline/candidate commit, Git tree, Makefile hash and clean-source state.
- Frozen instrumentation hashes and the unchanged canonical source inventory.
- All 28 actual compiler/link argument lists against that inventory.
- The actual seven-showcase shell loop and nine subsequent test shell records,
  in order, with successful natural completion.
- Equality of raw per-command files, command index and profile summary; missing,
  duplicate, partial, signaled, wrong-source and inconsistent rows are refused.
- The original watchdog policy, source/run/attempt/job and worker identity,
  natural completion, timeout state, and original command-log SHA-256.
- Exact Make stdout and final profile summary inside the watchdog log, plus
  timestamped-line consistency.
- Same-worker/compiler pairing, sequential arms and at most two live compilers.

It reports compiler interval unions, test interval unions, compiler CPU totals,
per-child RSS and heavy-compiler overlap separately. Shell/compiler parent-child
resource duplication is not counted twice. Compiler and test unions can overlap;
they must not be summed as disjoint phases. RSS is not claimed as aggregate memory.

**18 synthetic adversarial reader tests PASS**, including the three reproduced
defects, missing raw evidence, changed flags, signaled/incomplete commands,
timeouts, failed original commands, stale run attempts, corrupted original logs,
wrong source, inconsistent summaries, changed policy and a different worker.

Reducer SHA-256:
`ee58321a5cfab2b27edd7f1ac6383a85e8244cd7496c784facc1690127295eb8`.

Test SHA-256:
`f2a96654dbf742043ee65857b7867ae8fba774eb569aaa0d564fd4714a2dc519`.

Because this reviewer authored the offline correction after reporting the flaw,
a different reviewer should inspect it before its final result is admitted.
The physical hosted artifacts were still being produced at this checkpoint;
no strict final readback has yet been claimed.

Example invocation:

```sh
python3 strict_worldgen_pair.py \
  --directory /path/to/extracted/worldgen-sanitize \
  --source-repository /workspace/scratch/a3adba76fa99/ci003-proof-review \
  --target worldgen-sanitize --run-id 44959131042 --run-attempt 1 \
  --output /path/outside/artifact/strict-worldgen-sanitize.json
```

## Other independent checks

- Active CI provider policy: PASS.
- Complete workflow scheduling inventory: 93 workflows, zero policy errors.
- Unchanged native watchdog regressions: **21 PASS**.
- Actual transparent-wrapper process probes preserved compiler exits **0, 17,
  124**, shell exit **19**, and SIGTERM **−15** with a failed receipt and no live
  test child. These are process-control probes with synthetic payloads, not
  scientific test results.
- Review worktree remains clean. No remote source, branch or PR state was changed.

## Admission disposition

The production candidate may continue exact-source qualification. Do not use the
original proof comparator's green result alone. Independently review the strict
reader, replay complete immutable artifacts, verify their GitHub ZIP digests,
then combine that readback with the full source-matched required-check results
and honest performance accounting. A single same-worker pair is an observation,
not a percentile or population estimate.
