---
title: MAT-003 PR 238 reader and fixture review corrections
status: Current
document-kind: audit
scope: Closure of the in-chat PR238 comparison, publication and coordinate-refusal findings; preserved evidence and explicit draft integration hold
canonical-for: []
last-reviewed: 2026-10-24
related-documents: [../operations/mat003-overnight-campaign.md, ../research/mat003-remaining-acceptance.md, 2026-10-24-mat003-overnight-results.md]
---

# PR #238 review corrections — 2026-10-24

## Disposition and source boundary

**Author corrections complete; keep [#238](https://github.com/techrote/cybersand/pull/238)
draft. Independent acceptance and integration remain open.** Both supplied reviews
examined `10bab295213c9f7249b9b75276b9fe6126eea1d1`; GitHub intake confirmed that
head, parent #235 `145b22599f0667bf29a37303d7f3915c690b68b2` and main
`1002b9201006b572180a12cbc4c3b21fc234e8fa`. Work used the clean isolated
`codex/mat003-overnight-requalification` checkout. The unrelated dirty primary
checkout was preserved. No native production source, Godot, solver, carrier,
dependency, runtime library or default changed.

The [machine correction evidence](mat003-review-2026-10-24/verification.json)
records source hashes, unchanged publication identities, baseline/repaired
readback outcomes, fixture source snapshots and the additional raw evidence seal.
The coordinate regression was registered at `f960fc3` **before** its source fix.
The original 152-case v4 readback was not repeated or reclassified. Its nine reader
modules, registration, original authority/result/inventory, every overnight JSON
record and complete original raw packet remain byte-unchanged.

Preservation checks compare retained Git blobs and exact raw archives separately
from pre-existing Windows CRLF materialization. Six old JSON working files have
CRLF where Git stores LF; no file was rewritten to normalize that difference.
Both identities are recorded. The additional correction-only raw ZIP is
1,785,074 bytes, SHA-256
`2d314a1b4b4105c644941e1320fa2dd3a92bd18b2a18a79e627d92ff42afcf98`;
it is separate from the original 315,513,840-byte packet, whose
`a361495c25d0f52d31be9bb1b1e615a961e3df66d405764840df344b23b39336`
seal still matches. Neither binary archive is committed.

## Findings and changes

| Review finding | Correction and validation | Disposition |
|---|---|---|
| Integration gate | Retain draft and #235 base. Reconcile the unmerged parent stack against current main before ready-for-review; require fresh applicable exact-head Documentation/provenance, Native and Godot/runtime checks. Draft skips are not passes. | **OPEN integration gate**, not claimed closed by reader tests |
| Branch-only workflows lack a retained purpose | Retire the three spent one-shot launchers from active `.github/workflows`; retain their exact YAML in [historical-workflows](../../tools/experiments/mat003_optional/historical-workflows/) and collected Git revisions. New collections require new registrations. | **CLOSED as historical apparatus**; no reusable CI claim |
| Synthetic test does not check published v4 | [test_published_revision.py](../../tools/experiments/mat003_correctness/test_published_revision.py) checks the actual registration's external byte seal, collected tree, exact eight original historical reader hashes, nine revised historical hashes and unchanged running revised modules. CI fetches full history and runs it. | **CLOSED static publication gap** |
| Unpinned Windows comparators (P2) | [comparison_contract.py](../../tools/experiments/mat003_optional/comparison_contract.py) authenticates the complete canonical JSON of either the original Windows result or the immutable published summary. Supplied values cannot select their own expected hash. Both readers reject a substituted comparator even when its forged result agrees with a resealed archive. | **CLOSED** |
| Incomplete Wasm semantic records (P2) | Require exactly 25 optional fields or nine touch fields before comparing. Missing `logical_hash` / `observations` and extra fields reject; every required field is covered by small contracts. | **CLOSED** |
| Partial Linux comparison (P2) | Compare every result field, including `logical_hash`, allocations, refusals, scheduled cores and configured workers. Linux has no ABI exceptions. Wasm requires and separately checks its two ABI fields: owner size72 and pointer capacity four bytes per resident owner; all other fields compare exactly. | **CLOSED** |
| Invalid same-index operations and reclaim (P3) | [fixture.cpp](../../tools/experiments/mat003_optional/fixture.cpp) checks both cell coordinates before move/split no-ops, and chunk bounds before reclaim. [test_bounds.cpp](../../tools/experiments/mat003_optional/test_bounds.cpp) exercises size/max-size, invalid source/destination, valid no-ops, exactly one refusal and unchanged logical state/read/write/allocation/reclaim accounting. | **CLOSED in corrected experimental fixture** |

The external-seal check proves the published authorization bytes were retained.
It cannot independently authenticate the registration's private-chat reference.
The validation class therefore remains `author-validation-pending-independent-review`.

## Reproduced failures and repaired archived-data checks

The new [resealed mutation harness](../../tools/experiments/mat003_optional/test_portability_mutations.py)
was first run against the old readers. Linux accepted nine of ten malicious
packets; missing touch observations raised an unstructured `KeyError`. Wasm
accepted the two missing-field cases and both comparator substitutions; its extra
field raised `KeyError`. This reproduces the substantive review findings.

The repaired readers pass the unchanged **54-case Linux** archive (48 optional,
six touch) and **27-case Wasm** archive (24 optional, three touch). Each rejects
all ten resealed mutations with `ValueError`: missing optional hash, missing touch
observations, extra field, changed logical hash, refusals, allocations, scheduled
cores, worker count and the two matching-but-substituted Windows comparators.
Every altered packet updates stdout, command receipt, result and complete
inventory seals. The existing eight Wasm negative archives still reject.

The unchanged Windows optional 48-case and touch six-case packets also pass their
source-qualified original archive readers. The comparator pins cover all evidence
metadata and cases, not just a few result fields. Canonical SHA-256 permits JSON
whitespace changes while preserving complete values and types. Separate static
tests pin the published summary byte identities:

| Windows record | Original result byte SHA-256 | Published summary byte SHA-256 |
|---|---|---|
| Optional | `ebd2823b9bc36111d31ea5fed9bb332ab9b54575b7b77c0a8227181d60be442b` | `8c559c9975bc8535227eecf86d502d736bcc2fba0bf6d0b5c53a7f860bbd1c1d` |
| Touch | `5294da277b1b8ae2a3774a8ba441476ff4efdc3c2dd74e9e77a962238705cc78` | `e49d594235142005cc75be87d8108edae6fab151848737b41fd6a10603e93e18` |

## Execution commands, limits and evidence classes

**Executed locally, Windows x86-64 / Python3.12.10:** publication test one method,
comparison contracts four methods (including every required field), existing
reader-revision six methods and existing verifier-contract one method (34 named
contracts, including the independent decoder crosscheck). Each focused Python
command uses a 120-second collection timeout; the historical Git publication
subprocesses have individual 15-second limits.

```text
python -B tools/experiments/mat003_correctness/test_published_revision.py
python -B tools/experiments/mat003_optional/test_comparison_contract.py
python -B tools/experiments/mat003_correctness/test_verifier_revision.py
python -B tools/experiments/mat003_correctness/test_verifier_contracts.py
```

**Post-hoc archived-data execution, no candidate rerun:** these commands use the
original immutable raw roots. Their first local runs had no outer watchdog;
completed outputs and input/output seals are retained separately from collection
timings. Replace the two readers by `test_portability_mutations.py` plus
`--platform linux` or `--platform wasm` to execute the ten resealed negative cases.
The mutation command has the same source/comparator arguments. The existing Wasm
negative command is `test_verify_wasm.py` with the Wasm reader's same arguments.

```text
python -B tools/experiments/mat003_optional/verify_linux.py <linux-v2> --source-commit 7a8e984604db2f089105f65a68b58a4fc2456376 --windows-optional docs/audits/mat003-overnight-2026-10-24/optional-summary.json --windows-touch docs/audits/mat003-overnight-2026-10-24/touch-summary.json
python -B tools/experiments/mat003_optional/verify_wasm.py <wasm-v4>/cases --source-commit bed110c726312acbf625d4a1c232ec5178022c69 --windows-optional docs/audits/mat003-overnight-2026-10-24/optional-summary.json --windows-touch docs/audits/mat003-overnight-2026-10-24/touch-summary.json
python -B tools/experiments/mat003_optional/verify.py <optional-v1> --source-commit 571c0f65ebaa3d369c42829c2c6a55999b9f1c9c --registration-sha256 1490b71662ce3fc35fa678ec1893bdaac7150fe6b97ec4579ee29d1aaf0b6985
python -B tools/experiments/mat003_touch/verify.py <touch-v3> --source-commit d6c0166ff416e7fa061919f37d18f12e841122e9 --registration-sha256 8ec1518c5dd9cbd83958e97a2adaa6deaf6ca1cede3333523674e547df190855 --compiler-sha256 bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690
```

**New focused native fixture execution:** the old fixture failed the new
coordinate-refusal test, exit1 (`one explicit coordinate refusal`). After repair,
four Windows builds/cases (tail8/16 × normal/ASan+UBSan) pass, **32 assertions and
14 explicit coordinate refusals per case**, with empty diagnostics. Compiler
Clang23.1.0 SHA-256 is
`bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690`.
The [new registration](../../tools/experiments/mat003_optional/bounds-registration.json)
sets compile120s, case30s, aggregate600s, concurrency1, no timing. Windows leak
detection is disabled; no race-detector or Wasm execution is claimed. The first
collector setup lacked a transitive include and failed before any candidate case;
its complete failure is preserved as `review-bounds-v1`. The corrected source
snapshot includes all native headers and is preserved as `review-bounds-v2`.

```text
python -B tools/experiments/mat003_optional/run_bounds.py --compiler <sealed-clang++.exe> --output <new-review-bounds-directory>
```

**GitHub-reported evidence:** fresh exact-head run IDs and decoded-log results are
recorded in PR #238's description/Checks after publication. The active verifier
workflow includes GCC13 Linux normal/ASan+UBSan coordinate checks and static
publication/comparison tests. It does not replay the large local archives.
Native/Godot draft skips do not satisfy the integration gate.

**Characterization/static checks:** preservation hashes, full historical source
maps and workflow retention are distinct from runtime qualification. The small
comparison unit cases are contract tests. New archives were not collected for
Linux/Wasm optional-tail science, and there are no benchmark measurements.

## Documentation and remaining boundaries

Canonical campaign, remaining acceptance, handover, roadmap, index and local
validation routes now point here. Existing corpus routes already include the
campaign/matrix; frozen retrieval questions and prior challenge objects remain
unchanged. Mandatory documentation, M11, materialized provenance, CI-provider,
retrieval and diff checks are recorded in the machine correction evidence.

All required local checks passed: documentation structure, M11 historical
integrity, materialized current repository provenance, CI-provider policy and
both working/parent-base diff checks. Frozen retrieval hit@5 remains32/32;
supplementary hit@5 is138/139, retaining the known C09 miss. New MATREV01 ranks1;
manual review of its canonical section confirms comparator/schema, retired
launcher and independent/integration qualifiers. All138 prior challenge objects
and the frozen32 question bytes remain unchanged.

Ownership/lifetime, interfaces, physical state semantics, capacity configuration,
ADR-015, user controls and production build/runtime pins are unaffected: only
experimental readers, a three-guard fixture repair, focused tests and CI launch
lifecycle changed. No #204 completion, production storage selection, persistence
schema freeze, native restore qualification, #200 implementation, #212 work or
merge follows from this checkpoint.
