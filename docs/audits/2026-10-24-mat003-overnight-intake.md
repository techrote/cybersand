---
title: MAT-003 overnight intake and reader-provenance correction
status: Current
document-kind: audit
scope: Existing evidence inventory, revised-reader provenance defect and bounded overnight author validation; no production migration or new solver
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../operations/mat003-overnight-campaign.md, 2026-10-23-mat003-readback-verifier-repair.md]
---

# MAT-003 overnight intake — 2026-10-24

The owner authorized an autonomous #204 campaign at 01:46 UTC, with an eight-hour
maximum, a reviewable PR, no merging and no #212. The separate Claude task owns
the #200 foundation. Benchmark timing must avoid competing Claude builds.

Fresh main is `1002b9201006b572180a12cbc4c3b21fc234e8fa` after #237. The primary
checkout remains `mat/material-fidelity-pass-2` at `620826f5`, with unrelated
native/DLL and untracked work preserved. Inspection found six open, unmerged
#204-related PRs; the campaign therefore reuses their evidence rather than
rebuilding their apparatus from main. The isolated work branch stacks on #235
head `145b22599f0667bf29a37303d7f3915c690b68b2`, without editing that branch.

## Existing work and outstanding gates

| Work | Existing evidence | Treatment |
|---|---|---|
| S0 storage and S1 native correctness, 17 representations, natural 131,080-tick E16 rollover | [#208](https://github.com/techrote/cybersand/pull/208) | Preserve Linux scope, sanitizer results and worker/natural-rollover limits; do not repeat merely to fill time. |
| S2F/twins and 224-process S2A primary timings | [#211](https://github.com/techrote/cybersand/pull/211) | Preserve accepted source-qualified results; short E16 no-clear horizons do not settle long-run maintenance. |
| Packed diagnosis, WCLEAR, C128 and 152-case Windows collection | [#221](https://github.com/techrote/cybersand/pull/221) | Windows semantic readback remains refused; completed collection and integrity alone are not correctness acceptance. |
| Carrier-neutral GEN-006 field/lifecycle proposal and codec tests | [#230](https://github.com/techrote/cybersand/pull/230) | Existing proposed handoff; inspect and address concrete gaps without duplicating or adopting the schema. |
| Independent evidence synthesis and conditional carrier recommendation | [#231](https://github.com/techrote/cybersand/pull/231) | Existing review input; production C64-E8 remains the retained baseline. |
| Revised sleep/exclusion reader and 34 focused contracts | [#235](https://github.com/techrote/cybersand/pull/235) | Predicate repair reviewed; provenance incompatibility below prevents the proposed full readback. |

## Concrete provenance defect

At #235 head, `provenance.py::verify_provenance` still hashes eight running
reader modules against the **original execution authority's** source hashes.
That authority correctly records the original reader. #235 changes `readback.py`,
`world_oracle.py` and `negative.py`, so the repaired reader necessarily fails
`independent verifier source identity mismatch` before reaching the repaired
resident check. The v3 registration documents new reader hashes but is not
consumed by this provenance path. No full v3 readback was launched to reproduce
this statically certain refusal.

The correction retains the default original-reader check and adds an explicit,
externally sealed reader-revision path. It binds all original reader hashes,
the exact authority/result/inventory controls and collected source identity,
and all nine current reader modules including the new revision validator.
Original source snapshots, generated copies, commands, binaries, monitors,
receipts and every semantic check remain verified under their original seals.
Neither the collected authority nor an evidence member is rewritten.

Revised-reader output is explicitly **author-validation-pending-independent-review**.
Passing it cannot self-certify Windows acceptance. New regression contracts
reject evidence substitution, missing/extra/changed reader modules, changed
original seals, execution expansion and false independent-acceptance labels.
The inherited 34 resident/decoder contracts also pass locally on Python 3.12.10.

## Execution boundary

Only a newly frozen registration can launch one complete readback of the existing
archive. It must preserve the old refusal, archive and v2/v3 registrations, use
new output paths, retain stdout/stderr/result seals, and stop on any mismatch.
No compiler, candidate binary or timing path is needed for that readback.
The campaign's operational plan owns the remaining queue and stop rules.
