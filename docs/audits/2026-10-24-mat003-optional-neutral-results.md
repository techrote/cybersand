---
title: MAT-003 optional neutral-tail ownership and array-accounting results
status: Current
document-kind: audit
scope: Untimed Windows isolated-storage author validation of optional one/two-byte tails; no native World, solver or performance acceptance
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../operations/mat003-overnight-campaign.md, 2026-10-24-mat003-overnight-intake.md]
---

# Optional neutral tails — 2026-10-24

## Registration, execution and evidence

The [registration](../../tools/experiments/mat003_optional/registration.json) was
committed at `9162e69` before candidate code or execution. Fixture source froze
at `3d5022d`; the collector and complete build/case input froze at
`571c0f65ebaa3d369c42829c2c6a55999b9f1c9c`. The
[machine summary](mat003-overnight-2026-10-24/optional-summary.json) retains the
full source and artifact identities.

**Author validation PASS; independent acceptance pending.** All four Windows
Clang 23.1.0 normal / ASan+UBSan binaries built without diagnostics before the
first case. All **48/48** registered cases exited zero with empty stderr and
**88,475,076** correctness/reference assertions. The separate evidence reader
checked all source seals against frozen Git content, all command streams,
binary/case identities, the complete matrix and array accounting. Clustered and
dispersed populations match the same logical operation projection in normal and
sanitized execution. No tick timer or benchmark was used.

Environment: Windows, Python 3.12.10, retained `psutil==7.0.0`, LLVM-MinGW
20260826 / Clang 23.1.0, explicit retained LLD. Compiler, linker, binary, source,
registration and output hashes are in the summary. Normal flags are C++20/O2,
sanitized flags C++20/O1 with address/undefined sanitizers; both use warnings as
errors. Windows leak detection is disabled; this is not race-detector coverage.

The collector permits one process at a time, 180 seconds per build, 120 seconds
per case, 2 GiB sampled process-tree RSS and 3,600 seconds aggregate. Wall/RSS
receipts enforce operational limits; they are not performance observations.
The raw source snapshots retain their actual compiler-input bytes, including
Windows line endings; the readback separately checks canonical Git text identity.

Complete raw archive retained outside Git:
`C:/Users/_/mat003-overnight-20261024/optional-v1-evidence.zip`, **533,723 bytes**,
SHA-256 `6a8bdef1af348df36cd28c3e694218057fee934e0a8735514b8722c0bd0caa7e`.
It contains four binaries, 53 command receipts/streams, frozen inputs, all case
records and inventory plus the separate readback. Local retention is not a hosted
artifact or independent runtime qualification.

## What was exercised

The unchanged production `PrecisionStorage` supplies the eight-byte base carrier
in an isolated fixture. Full opaque base bits are compared exactly against a
dense logical reference; the fixture does not validate every raw pattern as a
legal material state. One-byte/two-byte neutral payloads live in optional
chunk-owned arrays, giving 72/80 logical bits without a contiguous 9/10-byte claim.

The fixture covers explicit allocation preflight, deduplication, quota/coordinate/
width refusals, injected second-allocation failure with complete rollback,
high-tail bits, copy/move/swap, synthetic neutral split/merge with exact totals,
replacement, zero-only reclamation and reset. Mutating field operations perform
no implicit allocation. All allocation occurs at the explicit quiescent preflight.
This establishes prototype storage behavior, not authoritative native lifecycle
integration or useful pressure/momentum semantics.

At each of 512², 1024² and 2048² resident scales, the four states are:

- **Absent:** no tail owners; a default read returns zero without allocating.
- **Allocated-unread:** two zero-filled owners, no consumer payload read/write.
- **Accessed-clustered:** the registered logical payload stream occupies the
  first chunk, with two tail chunks reserved.
- **Accessed-dispersed:** the same logical stream is spread over every resident
  chunk. Ownership count and array cost grow even at the same nonzero population.

Both accessed modes execute the same deterministic 8,192-operation stream after
initializing 8,192 logical cells. Exact dense-reference checks cover the entire
resident cell population after the stream.

## Observed array accounting at 2048²

All rows retain **33,554,432 base-array bytes** and **2,048 pointer-vector bytes**
on the tested x86-64 ABI. The dense eager-tail arithmetic is 4,194,304 bytes for
8-bit tails or 8,388,608 bytes for 16-bit tails at this fixed cell count.

| Tail | State | Allocated chunk owners | Actual tail-array bytes | Nonzero logical payloads |
|---|---|---:|---:|---:|
| 8 bit | absent | 0 | 0 | 0 |
| 8 bit | allocated-unread | 2 | 32,768 | 0 |
| 8 bit | accessed-clustered | 2 | 32,768 | 6,257 |
| 8 bit | accessed-dispersed | 256 | 4,194,304 | 6,257 |
| 16 bit | absent | 0 | 0 | 0 |
| 16 bit | allocated-unread | 2 | 65,536 | 0 |
| 16 bit | accessed-clustered | 2 | 65,536 | 5,983 |
| 16 bit | accessed-dispersed | 256 | 8,388,608 | 5,983 |

The source/summary also reports actual element/base alignment, owner-object size
and vector capacities. Array bytes exclude allocator bookkeeping, temporary
preflight staging, the dense test oracle, snapshots and whole-process overhead.
Do not add these figures to an existing aggregate resident counter or infer
whole-process savings, fixed-memory performance or cache behavior.

## Reproduction

Use a fresh output directory and the compiler hash from the summary;
check out the frozen collection revision above before reproducing its exact
inputs. A collection from a later revision is a separate source-qualified record.

```text
python -B tools/experiments/mat003_optional/run.py --compiler <clang++> --expected-compiler-sha256 <sealed-hash> --output <new-external-directory>
python -B tools/experiments/mat003_optional/verify.py <evidence-directory> --source-commit <summary-source-commit> --registration-sha256 <summary-registration-hash>
```

The collector requires retained psutil 7.0.0. Exact ordered commands, environment,
timeouts and receipts are in the raw archive. The separate verifier can be run
with ordinary Python and Git from a checkout containing the frozen source commit.
Existing dense split-storage, carrier, epoch and runtime experiments are unchanged.

## Separate Linux follow-up

The [Linux portability record](2026-10-24-mat003-linux-portability.md) adds
actual GCC13.3 normal/sanitized execution and complete archived-data comparison
to these Windows results. All 48 logical/accounting outcomes agree. The Windows
archive above remains unchanged. A stricter separate reader additionally rejects
six resealed negative datasets (missing case, wrong binary, changed flags,
accessed-unread state, false array bytes and timing relabel), reproducible with
`python -B tools/experiments/mat003_optional/test_verify.py <original-evidence>`.
