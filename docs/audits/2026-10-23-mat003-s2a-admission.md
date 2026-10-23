---
title: MAT-003PREPASS S2A apparatus qualification and paired-timing admission
status: Current
document-kind: evidence
scope: S2A timing apparatus admission and first incomplete timing dispatch; no valid S2A performance result
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../operations/mat-003-s2f-feasibility.md, ../operations/mat-003prepass-registration.md, 2026-10-23-mat003-s2f-full-and-twins.md, 2026-10-22-mat003-world-correctness.md]
---

# MAT-003PREPASS S2A admission — 2026-10-23

## Disposition

The exact **224-process S2A primary paired timing schedule is admitted but has
not been executed**.

Admission occurred only after:

1. the full 24-context source-control S2F qualification;
2. independently validated observed/observer-off candidate twins;
3. a separate preregistration of all 16 S2A contrasts, seven alternating AB/BA
   fresh-process pairs per contrast, statistical reduction, inputs, toolchain,
   budgets and stop rules;
4. hosted construction of the timing-capable observer-off binaries;
5. untimed qualification of every arm/anchor context used by S2A; and
6. an independent artifact readback.

Atomic admission commit
`e40cc0d060f4a26ead664ad5c6787a7aafd53cfe` simultaneously changed
`registration.json` to version 4 / `admitted-paired-timing` and replaced the
automatic apparatus workflow with a **manual `workflow_dispatch` timing gate**.
No S2A timed workflow run was created by that commit.

## Registration chronology

- `c5f810ff69dc28901d4d5e266706b34f30d50f8b`: registration v1 froze the
  16 contrasts, seven AB/BA pair orders, 224 primary processes, 120 warmup ticks,
  256 sample ticks, seed 204, active-512-w4 / quiet-2048-w1 anchors and bounded
  process budgets while timing remained unadmitted.
- `6200b3b09ebdc7a7d5007a5a75a50fad75303751`: v2 bound the immutable S1
  native baseline `da5112c066416346d6fe3984d4161cd162611e50` before execution.
- `cb19f5458c24823e6dbc22446f4af3e44d9bdfbc`: v3 froze the primary statistic
  before execution: per-process mean `tick_ns` over all 256 sample ticks,
  seven B/A pair ratios, median/min/max/MAD, and nearest-rank p50/p95/p99.
- `e40cc0d060f4a26ead664ad5c6787a7aafd53cfe`: v4 admitted only the exact
  primary S2A schedule after the hosted apparatus/readback gate below.

The measurement executable source was frozen before apparatus qualification.
The same sealed observer-off binary supports both `--mode qualify` and
`--mode measure`; qualification does not call the timing clocks or emit timing
arrays. The later timing runner is fail-closed unless registration v4 is present
and all admitted artifact/source hashes match.

## Preserved first apparatus attempt

[Run 39871650103](https://github.com/techrote/cybersand/actions/runs/39871650103)
is retained as a failed independent-readback attempt. Its collector successfully
built **17/17** timing-capable binaries and ran **25/25** untimed qualifiers, but
the verifier rejected before reading cases because it still expected
`registration_version == 2` after the pre-execution statistics amendment had
advanced the frozen registration to v3.

Artifact
[12467345034](https://github.com/techrote/cybersand/actions/runs/39871650103/artifacts/12467345034)
was retained with digest
`sha256:643a8cea33686d6a3c71037a55df80720ffb0b6d78d3c2e23dabe4d36521c902`.
It is **not** the admitted apparatus artifact.

The correction in
`26b324979517755a2c59282cd7daeab459517539` changed verifier logic only:
it accepted registration v3 and stopped treating the intentionally different
E8/E16 derived clear lists as a cross-representation semantic-equality field.
Per-case clear expectations remained independently checked.

## Qualified apparatus

[Run 39872073828](https://github.com/techrote/cybersand/actions/runs/39872073828)
passed on branch head
`26b324979517755a2c59282cd7daeab459517539`, with hosted PR checkout
`65a11780ca34406de05a795acf2a2172278f7bd2`.

The collector and independent verifier established:

- **17 sealed timing-capable observer-off binaries**;
- **25/25** required arm/anchor untimed qualification processes;
- **940 retained files** independently hash/readback checked;
- **25/25** qualifier cases independently checked;
- no qualifier timing arrays and no timing admission during the run;
- source-matched semantic/work/input/Water-ledger behavior in each registered
  anchor;
- per-case E8 clear derivation `[256]` and E16 no-clear `[]` for the
  120+256 horizon;
- exact sealed binary identity before qualification.

The admitted artifact is
[12466348465](https://github.com/techrote/cybersand/actions/runs/39872073828/artifacts/12466348465),
6,964,923 bytes, GitHub artifact digest
`sha256:ef0720eeca60dbe4daa7a05eaa5d792dbcb5138875e5d37f564fe6579b8d9a4a`,
recorded to expire **2026-11-21 23:31:08 UTC**.

Published admission identities:

| Input/evidence | SHA-256 |
| --- | --- |
| preregistration v3 | `6d6fcca136af925ce57b95561d30feddb128ccb82f25750418404387c32d86b5` |
| `fixture.cpp` | `bbc9e3c5ae26fd8b44a1caf14317a543b0afc2e3d5467cb42382da25aa8729f3` |
| `measure.py` | `a374b1f3f8fc839bc13ed03410143a80b790ce3180cf0c6f584c2e46d7aabdf7` |
| `verify_measurement.py` | `2ff91978067e35544731d5c33537f3c87c062f2abf091d586cfc68d1e933d479` |
| apparatus `run.json` | `cd4bf5096f023788fc65702e18d1643fe8f36ee0433474c65dd75eff0b58a3a4` |
| `sealed-binaries.json` | `b40659b95268ed887ee8181a46cd9b1d09e8e4937f39ee825dd460cd957c914f` |
| independent readback | `9db6991150ecc23215cfe15072e0b0dc38e562990532d1e55f8cc72ec1930759` |

After artifact expiry, or if any admitted runner/fixture identity changes, S2A
timing returns to held status until a new apparatus qualification and explicit
admission amendment are recorded.

## Exact admitted timing scope

Only these primary measurements are admitted:

- 8 active-512-w4 E8 physical/layout contrasts:
  source→word, word→padded64, and word→each packed/aligned/split C72/C80 arm;
- 8 quiet-2048-w1 within-representation E8→E16 contrasts:
  word64, padded64, packed72/80, aligned72/80 and split72/80;
- seven fresh-process pairs per contrast, in exact order
  `AB, BA, AB, BA, AB, BA, AB`;
- two processes per pair, for **16 × 7 × 2 = 224 processes**;
- seed 204, 120 warmup ticks, 256 timed ticks;
- GCC 13.3.0 / GNU ld 2.42 / registered `-O2 -DNDEBUG` flags;
- input handling timed separately and excluded from `tick_ns`;
- startup reported separately;
- primary pair ratio = B mean-tick / A mean-tick over all 256 registered ticks;
- raw per-tick samples plus nearest-rank p50/p95/p99/max retained;
- exact artifact 12466348465 binaries only.

The admitted workflow is manual only. It downloads artifact 12466348465 by
fixed run/artifact identity, verifies the admitted hashes, executes the literal
224-process schedule sequentially and runs an independent readback before
retaining any timing artifact.

## Still not admitted / not concluded

S2A admission is not a carrier winner and does not admit:

- S2B's proposed 322-process full-grid timing;
- wide-epoch clear-latency calibration or an amortized long-run E16 maintenance
  conclusion;
- a fixed-memory equivalence conclusion;
- Windows, Wasm or Godot performance;
- E24/E32;
- production carrier migration or GEN-006 persistence/streaming.

E8 samples include the registered natural clear at completed tick 256. E16
samples do not naturally clear in the 376-tick total horizon. That asymmetry is
deliberate and explicitly bounded: S2A may measure the registered short-horizon
contrast, but final epoch-width selection still requires separately measured
wide-epoch clear latency.

## First dispatched S2A campaign: preserved transport failure

The first manually dispatched timing campaign,
[run 39875052969](https://github.com/techrote/cybersand/actions/runs/39875052969),
checked out `c50d01fea636dc97cdec081e6225e936bcf9742f` and succeeded at
all registration, runner/fixture hash, exact apparatus download, ZIP digest and
three apparatus evidence hash checks. It failed before any timing sample at
**process 001/224**, `A01-source-word-e8`, pair 0, arm A,
`C64-E8-source`: the subprocess launcher received
`[Errno 13] Permission denied` on the sealed executable after
`actions/download-artifact` extraction. No paired contrast completed and
there is **no valid S2A performance observation**.

- Raw **incomplete**, non-admitted timing artifact:
  [12468335746](https://github.com/techrote/cybersand/actions/runs/39875052969/artifacts/12468335746),
  3,891 bytes, `sha256:fe25368f702485c03a4b0bd5298cc301681704ced804abf9cbdd6084e3578d67`;
  retains `run.json`, empty process stdout, first-process stderr, and failed
  independent readback. Expiry recorded as 2026-11-21 23:57:06 UTC.
- The measurement runner correctly recorded `status=incomplete`,
  attempted-process count 1 and completed-contrast count 0, and stopped;
  the independent verifier rejected the incomplete collection with zero
  independently checked processes.
- No process was replaced, omitted, silently retried, or counted as a valid
  paired measurement. This failed run **must remain incomplete**.

A narrowly scoped **artifact-transport executable-mode correction** was made
to `.github/workflows/mat003-s2a.yml` on the S2A PR branch
(commit `561761700d7de2dfb83b8dc1f58a94bc66d21188`), mirrored to the
default branch (commit `b6222d7c961caea2a4304377929d47cd76af235a`).
After verifying the exact downloaded admitted apparatus evidence, the workflow
identifies all **17/17** registered binary paths from `sealed-binaries.json`,
checks each file's SHA-256, restores only the user-executable mode bit, and
checks executability and every SHA-256 again. No binary bytes, compiled
candidate, compiler flags, runner/fixture/verifier sources, apparatus
identities, registered contrasts, process order, sample protocol or budget
were changed. This operation is not a rebuild or substitute apparatus.

Any subsequent execution must be a **new, complete, independently verified
224-process run from process 1**, never a selective rerun of the failed
process, and must preserve the failed run and raw artifact separately.
The original admission contract, including deliberate E8/E16 clear asymmetry
and all held scopes, remains unchanged. This transport fix alone does not
supply performance evidence or authorize a carrier selection.
