---
title: MAT-003 overnight author packet and complete archived Windows readback
status: Current
document-kind: audit
scope: Complete v4 archived-data verification, new untimed storage and capture evidence, preserved failures and bounded handoff; independent acceptance and full issue-204 completion remain open
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../operations/mat003-overnight-campaign.md, ../research/mat003-remaining-acceptance.md, 2026-10-24-mat003-overnight-intake.md, 2026-10-24-mat003-optional-neutral-results.md, 2026-10-24-mat003-linux-portability.md, 2026-10-24-mat003-wasm-portability.md]
---

# Overnight author packet — 2026-10-24

## Outcome and authority

**Scoped author packet complete; independent acceptance pending. #204 remains
open. Retain production C64-E8.** The one authorized v4 archived Windows readback
finished at **05:09:40 UTC**, exit zero, empty stderr, with **all 152 cases and all
96 cross-arm comparisons verified**. No native candidate was re-executed by that
readback. Its machine result explicitly retains `performance_accepted: false` and
`validation_class: author-validation-pending-independent-review`.

The [remaining acceptance matrix](../research/mat003-remaining-acceptance.md)
records the still-open independent, platform, performance and integration gates.
This packet does not close #204, choose a production carrier, freeze schema/ABI,
implement GEN-006, reopen #213 or start #212. Claude separately owns the authorized
#200 foundation. No new benchmark timing was collected during this campaign.

The task began at 01:46 UTC under an eight-hour maximum ending at 09:46 UTC.
The scoped queue completed within that window. Further primary timings remain
unexecuted because an uncontended window with the separate Claude build work
was not established.

## Complete Windows archive verification

The [v4 registration](mat003-overnight-2026-10-24/readback-registration-v4.json)
is sealed by SHA-256
`b7d44256b4dc585f80afdd559f51fbd0d24a75d11aaf19fafdf64c56b54e07a4`.
All nine actual reader modules remain frozen at
`610325422fc0cec496cf098990c40d5d4c292411`. The
[result and receipt](mat003-overnight-2026-10-24/readback-summary.json) bind their
individual seals, original authority/result/inventory controls, complete coverage
and the final process outcome.

The complete run exercised 34 named reader contracts: 32 rejection fixtures,
the mixed-aged/unaged positive fixture and the 704-record independent decoder
crosscheck. It then verified every registered case and cross-arm comparison.
The case inventory comprises 16 storage, 48 small, 16 refusal, eight natural and
64 resident cases. The eight frozen map IDs are K64/K72/K80/D128 at E8/E16;
this is the registered R16 campaign, not the separate 17-arm S0/S1 programme.

Separate archive cardinality/size characterization agrees with registration:

| Retained data | Count |
|---|---:|
| Full cell endpoints | 992 |
| Metadata-only endpoints | 8,192 |
| All metadata endpoints | 9,184 |
| Cell records | 1,164,967,936 |
| `cells.bin` bytes | 14,853,341,184 |
| Tick rows | 1,180,224 |
| Storage operations / refusal attempts | 1,048,576 / 4,096 |

The size/count characterization is not semantic acceptance by itself. The final
reader result supplies the separate completed semantic verification. Original
archive SHA-256 remains
`5c658fb6a5df41e36e539a442d739d4316e4cfbc8a2460da31ac850bceb0e948`,
97,897,664 bytes. Original execution controls, binaries, source snapshots,
registrations and the earlier reader refusal are unchanged.

The active readback limit was the original 21,600-second aggregate less
1,800.187 seconds already spent collecting, with a 19,800-second outer watchdog,
2 GiB reader RSS ceiling and concurrency one. The process receipt records
11,852.203 elapsed watchdog seconds. These are resource guards, not simulation
performance measurements. Windows Python 3.12.10 and the original psutil 7.0.0
module hashes were used.

The actual argument vector is retained in the packet's `attempt-v4.json`.
Equivalent recorded command shape, requiring the original Git history and
source/runtime identities:

```text
python -B tools/experiments/mat003_correctness/readback.py --evidence <original-Windows-archive-root> --authority-sha256 fb1abb3b574cb5a35d7f7f535a176ccac884f9e770cc045cbcad76b9d263cdd5 --verification-output <new-external-root> --verifier-revision docs/audits/mat003-overnight-2026-10-24/readback-registration-v4.json --verifier-revision-sha256 b7d44256b4dc585f80afdd559f51fbd0d24a75d11aaf19fafdf64c56b54e07a4
```

This records the completed one-shot execution; it does not turn this spent
registration into an unlimited rerun authority or independent acceptance.

## Evidence classes and new results

| Class | Actual result | Practical boundary |
|---|---|---|
| Locally executed archived-data verification | Complete 152-case / 96-comparison result above | Author validation; historical candidate processes were not rerun |
| Locally executed Windows specimens | Optional tails: four normal/sanitized builds, 48 cases, 88,475,076 assertions. Capture-touch: six cases, 3,630 assertions | Standalone neutral arrays and actual Current-World capture probe; no restore or World-sidecar implementation |
| GitHub-reported Linux execution; logs/raw inspected | Six normal/sanitized builds, 54 cases; exact Windows logical/accounting outcomes | GCC 13.3 / BFD 2.42; [source and archive record](2026-10-24-mat003-linux-portability.md) |
| GitHub-reported Wasm32/Node execution; logs/raw inspected | 24 optional and three capture cases; exact Windows normal outcomes | Emscripten 4.0.20 / Node 22.16.0, normal builds only; [record](2026-10-24-mat003-wasm-portability.md) |
| GitHub-reported new-platform S0 execution; logs/raw inspected | Unchanged 17-arm storage fixture, 49,775,273 assertions, exact accepted Linux lossless records | Synthetic epoch primitive; no native World E16 rollover, Godot/browser or sanitizer qualification on Wasm |
| Contract model | 13,960 projections, 1,745,000 length-three traces, 2,177,760 checks | Widths two/three and full-resident-clear assumptions; no native restore proof |
| Characterization/preservation | Archive counts, array/ABI observations and byte seals | Not throughput, whole-process memory savings or a production winner |
| Blocked/unexecuted | New primary timings, broader S2B, full application/platform matrix, native restore and independent final acceptance | No omission is a PASS; details remain in the acceptance matrix |

The source-qualified capture counterexample is concrete: a post-tick genuine
edit followed by restoration of the original content restores the content hash,
while support remains false until the next native tick. The
[capture-phase handoff](../research/mat003-capture-phase-handoff.md) therefore
proposes preserving the actual current-epoch predicate at a versioned owner
capture boundary, including already-applied external writes.

At 2048 squared, the optional-tail fixture observes the same nonzero payload
population at clustered/dispersed coordinates, but allocates two versus all 256
tail owners. Eight-bit tails occupy 32,768 versus 4,194,304 bytes; sixteen-bit
tails occupy 65,536 versus 8,388,608 bytes. These are array observations excluding
allocator, oracle, scratch and application overhead. On Wasm, packed carriers
remain 9/10 bytes while aligned carriers remain 16 bytes; pointer/descriptor
costs are reported separately. No speed or fixed-memory winner follows.

## Preserved failures and source identities

The intake main is `1002b9201006b572180a12cbc4c3b21fc234e8fa`; all 31 native
control inputs match the original `da5112c` baseline. The author branch stacks
on #235 at `145b22599f0667bf29a37303d7f3915c690b68b2`, reusing #208/#211/#221;
#230/#231 are separate handoff/review inputs. The raw packet checkpoint is
`7a340f0d1e3fe585399882f2704d979c693a3840`. Later changes publish this report and
navigation; scientific input revisions remain those recorded in each summary.

The original seven accepted Linux archives were freshly downloaded and retained,
198,325,960 bytes in total, all matching their existing hashes. The original
Windows collection and refusal are also preserved. New failed attempts remain:

- Windows capture v2: first build refused the known unused `this` capture;
  zero cases. V3 permits only the registered literal removal in generated copies.
- Linux v1: bare `ld` name was incorrectly resolved; zero builds/cases. V2
  preregistered the PATH resolution correction and restarted the full matrix.
- Wasm v1/v2/v3: SDK version-info refusal, incompatible growth-only flag, and
  a native touch trap respectively. V4 uses an explicitly guarded stack profile;
  the v3 trap's root cause is not proven.

Each changed profile was registered before its changed source/collection. No
failed matrix was relabelled, selectively resumed or overwritten. Compiler,
linker, SDK, library, source, binary and artifact hashes and license notices are
retained in the profile records and raw archives.

## Validation and documentation checkpoint

Twenty local validation command groups passed at the source checkpoints recorded
in the packet: documentation; materialized repository provenance; historical M11;
provider policy; reader/revision contracts; optional, capture, Linux and Wasm
archive readers; resealed negatives; inherited S0 contracts; retrieval and diff
checks. The post-collection readers reject six optional-tail, six capture, eight
Wasm and four S0-storage alterations. Historical M11 verifies 18 records and
28 source hashes at `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`; it is not a
current runtime gate. Final report/retrieval checks are recorded separately in
the [publication validation](mat003-overnight-2026-10-24/publication-validation.json).

At checkpoint `7a340f0`, Documentation run **40059401205** and reader-contract
run **40059401171** pass, with logs retained. Native **40059401206**, Godot
**40059401172** and the CI runtime-provenance step are **draft-skipped**. Those
skips are not passes. Local materialized provenance is separate. The final PR
head and its fresh checks are identified in the PR description.

The canonical documentation checklist maps this experimental change as follows:

| Obligation | Source of truth / disposition |
|---|---|
| State/storage and compatibility | Existing state inventory and semantic handoff retained; new remaining-acceptance and capture documents qualify the added evidence |
| Ownership/lifetime and interfaces | Native/Godot production interfaces unchanged; standalone reservation/refusal and proposed capture ownership documented |
| Invariants and capacities | Full-resident clear, quarantine and epoch/identity separation retained; each new profile owns explicit capacities/limits |
| ADR and roadmap | ADR-015 remains Planned; roadmap reports author verification and keeps #204 open |
| Build, validation and controls | Exact source/tool/command identities recorded; no product controls/defaults changed; draft skips and platform gaps explicit |
| Retrieval and history | Frozen 32-question bytes and all 134 prior supplementary objects preserved; MATON01–04 and canonical routes added; original audits untouched |

An intermediate JSON rewrite changed older retrieval text encoding. The
preservation check caught it; the parent text was restored before publication.
That intermediate retrieval output remains labelled as superseded in the raw
packet. No original question expectation or historical experiment hash is changed.

Final lexical retrieval finds the canonical route in the top five for **32/32
frozen** and **137/138 supplementary** questions. C09 remains the existing
supplementary miss. The four new questions route at ranks 3/1/3/1. These are
retrieval-route observations, not a claim that every retrieved answer is correct.

## Raw packet and bounded handoff

Self-contained raw archive inputs, reader source/output, failures, commands,
checkpoints, contract-model result and CI logs are retained outside Git:

`C:/Users/_/mat003-overnight-20261024/mat003-overnight-author-packet-20261024.zip`

**315,513,840 bytes**, SHA-256
`a361495c25d0f52d31be9bb1b1e615a961e3df66d405764840df344b23b39336`.
Its 179 members include 17 sealed input ZIPs. The
[bundle seal](mat003-overnight-2026-10-24/raw-bundle-seal.json) records the manifest
hash. Local retention is not a hosted artifact or independent runtime acceptance;
individual hosted artifacts and their expiry dates remain linked in the reports.

| Decision | Disposition |
|---|---|
| Retain | Production C64-E8 and reversible bounded optional-state contracts |
| Defer | Secondary epochs/lazy clearing, broader timings, all-platform application acceptance and production carrier selection |
| Reject | Clock/content-only reconstruction of the capture predicate; using cell epoch as durable job/incarnation identity; selecting a winner from array arithmetic |
| Propose separately | Any native sidecar integration, continuation implementation or structural migration that later reviewed requirements actually need |

Independent review must assess the reader-revision provenance boundary, complete
result, new lifecycle/refusal evidence and capture-phase argument. Parent-stack
reconciliation with current main and fresh applicable checks remain necessary
before integration. Keep the PR draft and unmerged. Nothing in this packet admits
#212, a pressure/inertial port, schema freeze, defaults changes or Rapier forces.
