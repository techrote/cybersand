---
title: Strict delivery native independent review
status: Planned
document-kind: audit
scope: Independent source/runtime comparison and original-byte native replay for the strict-repeat candidate
last-reviewed: 2026-11-25
---

# Strict delivery native review

**The strict-repeat Linux and Windows originals independently reproduce all nine
qualified native scenes with unchanged geometry and native authority.** Both
headless and displayed modes pass the original-byte replay. This completed
review preserves the earlier Windows timing failure under its original source
and artifact identity.

The reviewed source is d503d824aac4128968f7dfba5dccd540c3c07b59, tree
464c60288d5461d61578b000ae68ac029cffb5bd, in
[full campaign 45556633896](https://github.com/techrote/cybersand/actions/runs/45556633896).
The comparator is qualified application bcc92927ce3894a16d5544923cfbf7b1d0339fda,
tree 517164084860a19f18b36cb94f77597eb3220578. The separate 3a Linux pass and
Windows failure remain [source-specific evidence](DELIVERY-NATIVE-INDEPENDENT-REVIEW.md).

## Original artifact and independent method

| Platform | Original Actions evidence | Bytes | Independently recomputed SHA-256 |
| --- | --- | ---: | --- |
| Linux | [14996501724](https://github.com/techrote/cybersand/actions/runs/45556633896/artifacts/14996501724) | 17,155,267 | 7bec2f9d085041466eb1edf7dd6d9d4f6369b9069939ea071eff22a45f2009af |
| Windows | [14997800871](https://github.com/techrote/cybersand/actions/runs/45556633896/artifacts/14997800871) | 12,812,235 | 582fefeb91865e62b96420fedffc31b95bb1ddb7462213638f55447dada73009 |

Specialist B independently refreshed the original Actions metadata, checked
both complete archive identities and all 928 Linux and 1,011 Windows member
CRCs, and ran the unchanged original-byte native verifier against all four
complete native datasets. The verifier has SHA-256
64292c1a48babae89b51e0dfa2c99792c29e9f2f813962294da8fc6d8c4536a9.
It decodes actual diagnostic PNG material values, checks their CRCs and plane
hashes, and replays every original native before/after tuple. It imports no
Art rasterizer or fixture generator and performs no native or model execution.

The [strict-source comparison](strict-delivery-native/reconcile_strict_repeat_native.py)
preserves the previous comparison's assertions, with the exact new source,
artifact names and ledger-only delta. Its Linux and Windows executions each
passed 445 evidence checks with zero failures: 890 independent evidence checks,
separate from the original application-test counts below. The
[execution record](strict-delivery-native/strict-native-execution.json) binds the
commands, verifier, derived outputs and complete artifact metadata. The
[Linux comparison](strict-delivery-native/final-d503-linux-comparison.json) and
[Windows comparison](strict-delivery-native/final-d503-windows-comparison.json)
retain all scene-level identities and receipt totals. No original archive,
image, full cell array or audit log is republished.

## Native observations

| Original native campaign | Terminal checks / failures | Scenes / stages | Readback rows independently replayed | Original native files verified |
| --- | ---: | ---: | ---: | ---: |
| Linux headless | 739 / 0 | 9 / 25 | 377,234 | 55 |
| Linux displayed | 762 / 0 | 9 / 25 | 377,234 | 73 |
| Windows headless | 739 / 0 | 9 / 25 | 377,234 | 55 |
| Windows displayed | 763 / 0 | 9 / 25 | 377,234 | 73 |

Every completed arm records 184,396 acknowledged material transitions and
188,617 checked cells. Repeated addresses across stages remain in these totals;
they are not unique occupied cells. Across the four executions, 1,508,936
readback rows and 256 original native evidence files were independently checked.
Both headless executions used 61 staged and 56 direct chunks. Linux displayed
used 63 staged and 57 direct chunks; Windows displayed used 64 staged and 56
direct chunks. The unchanged test adds two checks per staged receipt and one
per direct receipt. This explains Linux's five-check increase over bcc's
displayed 757 and Windows's one-check decrease from bcc's displayed 764: the
former has two additional staged chunks and one additional direct chunk; the
latter has one fewer direct chunk. No test gate or scene coverage was removed
or loosened.

The nine scenarios, 25 stage predictions, complete initial/final material planes,
protected regions, static-clearance diagnostics and translated direct controls
match bcc. The original saved-Setup reopen assertions are retained. These are
nine distinct deterministic scenes replicated across execution modes; they do
not become additional creative briefs by repetition.

## Separate meanings of source equality

Three evidence boundaries are kept distinct:

- **Git/application inputs:** d503 has different commit/tree identities from
  bcc. The full difference set is the previously reviewed guide, packager and
  packaging-test changes plus one append-only mission-ledger entry. All
  application/Godot native fixtures, workflows, native and material source
  inputs remain unchanged. The d503-versus-3a delta changes only that ledger.
- **Native geometry:** actual stored-material before/after planes and every
  predicted stage plane match bcc. Rendered appearance is not used as material
  authority.
- **Native World identities:** each campaign's generation/revision/tick/
  authoring-generation receipt chain is validated independently, with revision
  increments equal to acknowledged changed cells. The comparison additionally
  verifies each scenario's boundary source_before/source_after dictionaries
  against bcc, and includes those actual boundary dictionaries in the derived
  JSON. Intermediate chunk revisions are not asserted identical across different
  chunk groupings.

Complete recorded Linux and Windows engine/native/Rapier/provenance identities
match bcc, and materialized runtime hashes match the corresponding source LFS identities.
The native fixture itself is byte-identical, SHA-256
88b83bc86b320b10a844a957eaa078b3bea94382b30f1104ca8ba38358a74814.
Standalone executable binaries are not contained in these measurement archives;
the principal portable package has a separate all-payload and pristine-launch
review. This record does not claim a new independent binary rehash from absent
files. The [separate final A custody review](https://github.com/techrote/cybersand/blob/fe3c6b4aa0e5da4ee07c9b70e456d02d94fc83b7/docs/audits/2026-11-25-art-workbench-collaborative-002/provider-independent-evidence/d503-windows-independent-review.md)
records the successful 1,200-file immutable-payload audit, 18 original
application-log joins, nine installed Setups and actual pristine launcher exit
0. B reviewed the auditor's Windows path, original launch-marker and complete
import-descriptor checks before A executed it. That separate audit also records
the final unchanged progress gate passing at 1,367 ms; its original 2,187 ms
failure remains retained.

## Acceptance matrix

| Boundary | Disposition | Practical scope |
| --- | --- | --- |
| Strict-repeat source delta | Pass | One append-only ledger file over 3a; no executable/test/gate change |
| Linux and Windows native construction | Pass | Four complete original modes, exact readback replay and all nine saved-scene tests per mode |
| Geometry and protected constraints | Pass for the named fixture cohort | Actual planes, stage predictions, source policy and direct controls agree |
| Native receipt identities | Pass within each recorded campaign | Exact source chains; boundary equality separately checked |
| Linux and Windows recorded runtime/source custody | Pass | Full identity equality to qualified bcc and matching source pointers |
| Final portable Windows launcher/payload | Pass in the separate A review linked above | A owns original binary and pristine launch custody; this native review does not substitute for it |
| Prior 3a Windows progress limit | Retained failure | 2,187 ms violates unchanged less-than-2,000 ms bound; cause unproven |
| Genuine model creativity/retrieval benefit | Unqualified | Zero genuine inference; deterministic/fixed-proposal evidence only |
| Physical traversal/stability and owner preference | Unqualified | Static material clearance and reviewer judgments have narrower scope |
| Physical Windows/NVIDIA absent-listener acceptance | Owner-pending | Separate original sequence, not replaced by a 404 or hosted startup result |

The [negative/source review](DELIVERY-NEGATIVE-INDEPENDENT-REVIEW.md) preserves
the original 3a failure, unknown active operand, main.image timing scope and
unchanged gate. A later strict pass cannot erase that latency observation or
establish universal timing. The [foundation note](FOUNDATION-SOURCE-RELATIONSHIP.md)
preserves actual session ancestry and separate Batch/Architecture ownership.
All original fixture limitations, refused outcomes and other failed experiments
remain in their existing evidence records. Draft/HOLD remains.
