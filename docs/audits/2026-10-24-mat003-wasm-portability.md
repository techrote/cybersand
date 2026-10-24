---
title: MAT-003 standalone Wasm32 and Node specimen portability
status: Current
document-kind: audit
scope: Registered untimed optional-tail and native capture probes under Wasm32 and Node, preserved failed profiles and desktop archived-data comparison; no Godot or browser acceptance
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [2026-10-24-mat003-linux-portability.md, ../research/mat003-capture-phase-handoff.md, ../operations/mat003-overnight-campaign.md]
---

# Standalone Wasm32/Node portability — 2026-10-24

## Execution and evidence class

**GitHub-reported, logs and downloaded raw archive inspected:**
[run 40057478164](https://github.com/techrote/cybersand/actions/runs/40057478164),
job **120763547691**, passed at
`bed110c726312acbf625d4a1c232ec5178022c69`. Three JS/Wasm builds executed
**24 optional-tail cases / 44,237,538 assertions** and **three native capture-touch
cases / 1,815 assertions** under SDK **Node v22.16.0**. Cases are normal builds;
no Wasm sanitizer, Godot or browser execution occurred.

The [v4 registration](../../tools/experiments/mat003_optional/wasm-registration-v4.json)
preceded the collector correction. It fixes 256 MiB linear memory with growth
disabled, explicit 2 MiB main and pthread stacks, assertions and stack-overflow
checks. All three builds precede cases. Build/case/aggregate bounds are
300/120/1,200 seconds, concurrency one, output 64 MiB and workflow 35 minutes.
Elapsed receipts enforce watchdogs; they are not benchmark observations.

This uses the **Current `tools/build_web.py` Emscripten 4.0.20 version**, with SDK
Git source `e4fe26ef59168ff44f4c23c466e497bf60b3411e` and release build
`c387d7a7e9537d0041d2c3ae71b7538cc978104e`. The historical M11 Web workflow,
dependency locks and production source are unchanged. The profile retains the
actual two SDK/Node archive hashes, four tool hashes, 336 system-library hashes
and 217 license notices. Their receipts are in the
[summary](mat003-overnight-2026-10-24/wasm-summary.json); hashes observed by this
collector are not an independent supply-chain attestation.

## Read-only reconciliation

The [archive reader](../../tools/experiments/mat003_optional/verify_wasm.py)
verified complete inventory/seals, exact Git source, all JS/Wasm assets,
the injected Wasm32 pointer assertion, registered one-literal compiled-source
overlay, ordered compilation/case commands, stream bindings and every case.
It compared all logical results with the corresponding Windows normal builds:

- optional operation projections, logical hashes, population, ownership,
  accesses, refusal counts and assertions match exactly;
- all three native modes match every support/content/clock observation,
  recoveries, ticks and assertion count.

The explicit ABI differences are observed, not imported from x86-64:
`sizeof(Store)` is **72** rather than 96, and the pointer array uses four bytes
per resident owner rather than eight. Cell size/alignment remains 8/8. At 2048,
the 256-entry pointer array is 1,024 bytes; base and tail arrays match desktop.
These are specimen array/object sizes, not whole-process memory or speed.

Eight resealed negative archives are refused: omitted case, changed compile
flags, missing Wasm asset, false target ABI, false pointer accounting, changed
logical result, runtime diagnostic and timing relabel. Reproduce with the same
arguments using `test_verify_wasm.py` instead of `verify_wasm.py`:

```text
python -B tools/experiments/mat003_optional/verify_wasm.py <wasm-artifact>/cases --source-commit bed110c726312acbf625d4a1c232ec5178022c69 --windows-optional docs/audits/mat003-overnight-2026-10-24/optional-summary.json --windows-touch docs/audits/mat003-overnight-2026-10-24/touch-summary.json
```

The full [artifact 12545853090](https://github.com/techrote/cybersand/actions/runs/40057478164/artifacts/12545853090)
is **1,338,983 bytes**, SHA-256
`47577991af44504a5b9a0ef4a057754a0ef74a3f8ff7809e1d76e73bcacee0b6`,
expiry **2027-01-22T03:14:20Z**. It is also preserved outside Git locally.
The result remains **author validation pending independent review**. This is
standalone specimen portability, not all-carrier or application acceptance.

## Failed profiles preserved

No failed attempt was selectively retried or overwritten. Each successor
registration preceded its changed collector/profile and restarted the full
matrix. All raw ZIPs are downloaded and retained with the successful profile.

| Profile / run | Actual disposition | Artifact / SHA-256 |
|---|---|---|
| v1 / [40056514214](https://github.com/techrote/cybersand/actions/runs/40056514214) | Version query refused SDK informational sanity-check stderr; no builds/cases | 12545975932, 3,354 bytes; `284c467acc40e2efd342e01d5f0f2b74a73fb94606ba6d0d7a786a71188d0721` |
| v2 / [40056816910](https://github.com/techrote/cybersand/actions/runs/40056816910) | First build refused incompatible growth-only MAXIMUM_MEMORY option under Werror; no binaries/cases | 12545418604, 825,463 bytes; `699d16cf6640f23ee0cb5577f39a5ec6bba01547a0c973a9ddc926bf7801552d` |
| v3 / [40057062844](https://github.com/techrote/cybersand/actions/runs/40057062844) | All 24 optional cases passed; first native touch case trapped with memory access out of bounds. No profile PASS | 12545372918, 1,215,800 bytes; `d68bb710a4ff5f360a93c8fb3c2bcf9600c27acb3a08fbd4d45d4c65c9fa3225` |

The v4 guarded stack profile passes, but the v3 trap's root cause is not proven.
Do not generalize that result into a production stack requirement or a repaired
Web defect. Action-runtime deprecation notices in workflow logs are separate
from the specimen command stderr streams, which passed the registered checks.
