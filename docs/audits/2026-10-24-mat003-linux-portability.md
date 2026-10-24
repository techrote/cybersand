---
title: MAT-003 new specimen Linux portability and Windows readback comparison
status: Current
document-kind: audit
scope: GitHub-hosted untimed portability of new optional-tail and capture-touch fixtures, preserved setup refusal and exact archived-data comparison; no benchmark or whole-programme acceptance
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-optional-neutral-results.md, ../research/mat003-capture-phase-handoff.md, ../operations/mat003-overnight-campaign.md]
---

# Linux portability of the new specimens — 2026-10-24

## Actual execution

**GitHub-reported, logs and raw archive inspected:**
[run 40054292111](https://github.com/techrote/cybersand/actions/runs/40054292111),
job **120753709077**, succeeded at source
`7a8e984604db2f089105f65a68b58a4fc2456376`. It executed the
[v2 registered profile](../../tools/experiments/mat003_optional/linux-registration-v2.json)
on GitHub-hosted Ubuntu 24.04 x86-64 with actual **G++13.3.0 / BFD2.42**.
Compiler/linker and runtime-library hashes, package versions, actual platform,
Python and source identities are retained in the
[summary](mat003-overnight-2026-10-24/linux-summary.json).

All **six builds / 54 cases** passed with empty diagnostic streams:

| Specimen | Normal + ASan/UBSan cases | Assertions | Scope |
|---|---:|---:|---|
| Optional neutral tails | 48 | 88,475,076 | Absent/unread/clustered/dispersed arrays and exact logical reference |
| Native capture-touch | 6 | 3,630 | Nine external-edit checkpoints and following-tick recoveries in each case |

Linux uses leak detection and fail-fast address/undefined sanitizers, with
explicit non-PIE sanitized builds. Windows used its separately registered Clang
profile with leak detection disabled. Neither profile is race-detector evidence.
The Linux profile supplies timeout/output bounds; it makes no per-process RSS
acceptance claim. No simulation timing, throughput or performance comparison is
collected by either profile.

## Archived-data comparison

The new [Linux archive reader](../../tools/experiments/mat003_optional/verify_linux.py)
checked the complete inventory and seals, exact frozen Git source snapshot,
all six binaries, the literal unused-capture overlay, ordered compiler/linker/
case commands and every stdout/receipt binding. It then compared against the
separately retained Windows records:

- all 48 optional cases match the exact logical operation projection, nonzero
  population, read/write counts, tail allocation accounting and assertion counts;
- all six native cases match the nine support/content/clock observations,
  nine recoveries and 513 native ticks.

This is executed portability evidence for these two new specimens only. It is
not all-carrier Linux/Windows equivalence, World-sidecar integration, restoration,
Wasm/Godot qualification or independent acceptance of the author's implementation.
The explicit result class remains **author validation pending independent review**.

Full artifact [12544682549](https://github.com/techrote/cybersand/actions/runs/40054292111/artifacts/12544682549):
**5,567,399 bytes**, SHA-256
`6d3f2850d1d30d359e4e137e911af93b75c66c4d856f0cf42768e13c6e39efbc`,
recorded expiry **2027-01-22T02:28:14Z**. The ZIP was downloaded, hash-checked and
retained locally with its complete extracted source/binaries/receipts. Nothing
was recollected during readback.

Reproduce the read-only comparison with the original Windows summary files:

```text
python -B tools/experiments/mat003_optional/verify_linux.py <linux-evidence> --source-commit 7a8e984604db2f089105f65a68b58a4fc2456376 --windows-optional docs/audits/mat003-overnight-2026-10-24/optional-summary.json --windows-touch docs/audits/mat003-overnight-2026-10-24/touch-summary.json
```

## Preserved first setup failure

The original [run 40053969822](https://github.com/techrote/cybersand/actions/runs/40053969822)
under v1 failed before compiling: GCC returned the bare name `ld`; the collector
incorrectly resolved it relative to the source checkout. **Zero candidate builds
or cases ran.** Failure artifact **12544099734**, 2,993 bytes, SHA-256
`6a61919c9b3fba2650ed028d9ef75ce6746d34f309899b590d4d5482f52f14ba`,
remains intact and was also retained locally.

The v2 registration preceded the source correction. It resolves bare names
through PATH, forces the checked BFD search directory, records actual library
inputs, and retains failed command receipts. The replacement started from the
first build and ran the complete matrix once. The branch-push trigger is limited
to relevant source changes, so later evidence/documentation-only commits do not
silently repeat the scientific collection. Routine CI provider policy remains
GitHub-hosted; its checker passed after the workflow change.
