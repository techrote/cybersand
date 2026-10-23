---
title: MAT-003 bounded correctness-only qualification plan
status: Planned
document-kind: design
scope: Future bounded neutral-state correctness qualification proposal; no harness implementation, execution or new timing authority
canonical-for: [mat003-bounded-correctness-plan]
last-reviewed: 2026-10-23
related-documents: [mat003-concrete-owner-offer.md, mat003-state-schema-proposal.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md]
---

# MAT-003 bounded correctness-only plan

## Authority and entry gates

Prepared at owner request after budget acceptance; **plan only**. No implementation, build, test execution or timing campaign starts here. Budgets are Approved design qualification targets, not achieved limits. R16-T1, the new physical map and carrier/epoch adoption remain conditional. The source intake is `20c2249d498abe14f3c48f7925e2883d79bb98ea`; preserve all accepted source/artifacts/statistics and PR211/221 draft state.

Before future execution, obtain separate authority to build an isolated apparatus, review exact candidate mappings and source identity, freeze the case matrix/fixtures/verifier/binaries/budgets and tool/platform receipts, and independently review apparatus readback. Any gate failure blocks the relevant suite. No existing campaign is rerun to fill gaps; applicable evidence is reused by exact identity. This is not a timing registration.

## Scope and candidate contracts

Prepare three isolated candidate layouts: safe compact C72, safe compact C80 and DUAL64, each E8/E16, plus C64-word E8/E16 controls: eight arm contracts. These are intended contracts, not currently implemented new layouts. E8 preserves its reviewed mapping; any changed E16/R16 map needs explicit map review first. The proposed contiguous map in the owner offer is not approved merely by inclusion here.

Exercise an **opaque neutral16 test payload**, with no Water mass/history meaning or feedback. For arms whose frozen map has fewer than16 free bits (C64-E16), nonzero R16 writes must refuse before changing a record; supported smaller raw fields may be tested separately. Matching a payload capacity does not qualify R16-T1 semantics. C64 controls retain current semantic domains; high raw state roundtrip does not widen public validity.

Retain full high64 neutral preservation probes for DUAL64 so neutral16 tests cannot hide corruption above it. Whole moves/swaps copy complete records, partial setters preserve unrelated bits, declared replacement resets follow the frozen schema, and clear preserves non-epoch state. Temperature, nonzero Empty, high state_a boundaries, Water source/sink ledgers, granular support and scheduling predicates remain independent checks. No signed overflow, aliasing violations, mutable snapshots or per-cell physics objects are introduced.

## Bounded future matrix

| Suite | Exact bounds | Maximum process count |
|---|---|---:|
| Storage/oracle boundaries | Eight arms × normal and ASan/UBSan; deterministic65536-operation schedule per process, independent byte/field oracle; max1024 live test records |16|
| Small real-World equivalence | Eight arms × Serial1/Phased1/Phased4 × normal/sanitized;256² residency,2048 completed ticks, bounded boundary/material/temperature fixtures |48|
| Feasible natural E16 check | Four E16 contracts × normal/sanitized;128² residency, Serial1,65540 completed ticks, first natural clear65536; deterministic small input schedule |8|
| Resident clear and reentry | Four E16 contracts × sides512/2048 × sleeping/excluded or active-window/excluded × Phased1/Phased4 × normal/sanitized;255 setup ticks, prepared real clear, matched non-clear reference and4 reentry ticks |64|
| Admission/refusal/lifecycle | Eight arms × normal/sanitized; max4 resident chunks,256 attempted operations covering invalid fields, capacity, pause/reentry, construction and failed-world outcomes |16|
| Total per platform | No subsets may claim completion of the whole platform matrix |152|

The matrix is152 processes per native platform,304 for both Linux and Windows. Validate sanitizer/runtime availability before freezing platform builds; unsupported sanitizer execution blocks that platform disposition rather than silently omitting cases.

Matched clear/reference Worlds run sequentially in one correctness process, never simultaneously as an unbudgeted pair. They are not independent performance replicates. Each large case uses at most one8-record endpoint set: before/prepared/post/reentry records for each role; stream and losslessly compress outside simulation. Small/natural suites retain full records at declared checkpoints and per-tick work/ledger receipts, not a full-world snapshot every tick. Freeze checkpoint identities before execution. Worker4 participation must be demonstrated by observed active fixtures; the natural one-chunk Serial case supplies no worker4 claim.

Reuse accepted full S1 E16 two-wrap evidence where source remains applicable. New mappings still need their own feasible natural first-clear check; modular counter storage tests cover multiple wraps. Prepared events must independently match natural first-clear semantics and exact current-stamp predicates. If restoration equivalence cannot be proved, refuse that arm/suite rather than infer success from low-cost isolated clearing. No E24/E32,4096², natural wide long-run claim or new physical solver is in scope.

## Resource and stop bounds

Bound builds to32 compiler invocations per platform (16 storage and16 reusable World binaries for eight normal/sanitized arm contracts). Freeze a maximum180seconds per compile,300seconds per storage/small/refusal case,600seconds per natural/large case and6hours aggregate wall budget per platform (12hours for both), with one process at a time. Wall time is a harness watchdog only; record no tick latency/startup/input timing samples, ratios or performance rankings. An aggregate budget stop is incomplete, not permission to drop cases. No automatic retries, selective reruns or missing-evidence reconstruction.

Cap retained raw uncompressed semantic output at64GiB for the full matrix and require enough local/artifact capacity before starting; preserve complete streams and hashes. Freeze actual byte/record ceilings for each fixture before execution; exceeding a ceiling records failure and retains emitted evidence. No selective compression or omission of failed states. Build outputs, snapshots and logs stay outside Git.

The proposed harness RSS ceiling is2GiB per normal process and3GiB per sanitized process, including oracle/retention buffers and sanitizer overhead. These are future harness safety budgets, not replacements for the owner's512MiB cellular/2GiB application targets. Account actual engine-owned allocations separately from harness/sanitizer costs. An overrun refuses suite completion; any revised apparatus budget requires explicit review before a replacement attempt. Correctness resource receipts cannot certify a rendered application or p95/p99/tick budgets.

## Independent readback and exit

Use pinned Linux and Windows native toolchains for intended platform correctness; record source/local delta, generated map/header hashes, compiler/linker/version, binary seals before execution, flags, fixture seed, workers and exact invocation. Keep accepted controls unchanged and overlays isolated. Independent verification must parse retained records rather than trust collector summaries, compare all representable semantic fields against controls/oracle, validate refusals leave the relevant admission state unchanged, and distinguish partially mutated failed ticks from atomic external record refusal. Verify ledgers, temperature, high lanes, source/sink accounting, stamps/support, jobs and actual workers separately.

Frozen baseline/source changes or mismatched build/case/order/inventory/hash, nonzero exit, sanitizer finding, stderr diagnostic, timeout, missing state or failed natural/prepared equivalence blocks completion. Retain all failures. Partial suite findings may be reported with their exact scope, never as full qualification. Keep observer-off/observed twins a future performance prerequisite; correctness instrumentation is not a measured observer-off speed result.

Exit artifact: complete immutable152-process-per-platform evidence, independent readback and explicit arm/suite dispositions, with gaps and platform limits. These would qualify only the frozen neutral-state mappings/invariants. R16-T1 requires separate owner semantic approval and solver-programme reconciliation before tests of its authoritative amounts, transfers, conversion yields or feedback. Numeric memory/latency compliance needs separately authorized future apparatus; no benchmark is launched here. Adoption/merge authority remains separate, and both PRs stay draft.
