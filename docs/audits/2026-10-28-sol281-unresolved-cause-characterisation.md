---
title: SOL-DETACH-001 unresolved cellular-coupling cause characterisation
status: Current
document-kind: audit
scope: Source 756ae488 exact Linux/Windows result-schema extension and live dense-bank cause partition; no ejection-policy change
canonical-for: [sol281-unresolved-cause-evidence]
last-reviewed: 2026-10-28
related-documents: [../systems/solid-detachment.md, 2026-10-27-sol281-compound-cellular-coupling.md, sol281-2026-10-28/unresolved-cause-receipt.json]
---

# SOL-DETACH-001 unresolved-cause characterisation — 2026-10-28

## Exact source and bounded change

This record qualifies source `756ae4882d346a1439244189c76eda8496070229`, tree `cf50b83207d28d63fef7b4a6562c87af99b6bb41`, in draft PR #283.
It follows the initial compound-coupling proof at `41dc25ca` and does not qualify
production main, runtime publication or completion of issue #281.

The rigid-body result record grows from nine to twelve float fields while keeping
all original offsets `0..8` unchanged. Three diagnostic-only counters are appended:

1. immovable material encountered inside the swept proxy;
2. no reachable empty destination within the existing bounded ejection search;
3. an authoritative relocation refusal after a destination was selected.

Native C++ and the GDScript fallback reset and publish the same counters. The
Rapier consumer continues to read only the stable prefix. No search radius,
probe order, path rule, displacement impulse, material law, liquid solver or
aggregate admission rule changes in this slice.

## Protocol characterisation

`godot/tests/test_solid_detachment_unresolved_diagnostics.gd` executes the native
and fallback owners against three controlled cases: successful Sand displacement,
immovable Plant refusal and an intentionally saturated Sand search region. Both
Linux and Windows pass **43 checks / zero failures** with result stride 12.

The successful case reports one displacement and no refusal. The immovable case
reports exactly one immovable refusal. The saturated case reports exactly one
no-target refusal. In every case the cause sum equals the existing aggregate
unresolved count and body/sample identities remain at their original offsets.
Relocation refusal is observable but was not artificially induced after a valid
single-owner destination; it remains zero in all controlled and live cases.

## Actual Linux and Windows compound fixture

[Run 40611249935](https://github.com/techrote/cybersand/actions/runs/40611249935) checks out
exact source, builds source-matched native extensions and executes Godot 4.7 with
Rapier2D 0.35.2 on Ubuntu 24.04 and Windows Server 2022.

| Gate | Linux | Windows |
|---|---:|---:|
| Focused native ownership | 8 groups / 13,074 checks | source-matched DLL plus actual engine execution |
| Tree motion | 21 / 0 failures | 21 / 0 |
| Rollback/failure paths | 20 / 0 | 20 / 0 |
| Session replacement | 296 checks / 18 cycles / 0 | 296 / 18 / 0 |
| Cause-protocol characterisation | **43 / 0** | **43 / 0** |
| Compound Sand/Water coupling | **36 / 0** | **36 / 0** |

The six exact proxies still preserve both registered holes, exact mass 520,
Sand/Water quantity conservation and real contact/displacement feedback.

| Live cumulative counter | Linux | Windows |
|---|---:|---:|
| State publications | 361 | 361 |
| Accepted result snapshots | 211 | 254 |
| Result records | 1,260 | 1,440 |
| Contacts | 8,787 | 6,977 |
| Successful displacements | 35 | 40 |
| **Unresolved total** | **1,557** | **1,501** |
| Immovable | 0 | 0 |
| **No reachable target** | **1,557** | **1,501** |
| Relocation refused | 0 | 0 |
| Unclassified | 0 | 0 |
| Displacement attempts | 1,592 | 1,541 |
| Attempt-level unresolved proportion | 97.8015% | 97.4043% |
| Impulse applications | 519 | 490 |
| Correction applications | 0 | 29 |
| Stale results | 0 | 0 |
| Maximum rotation | 1.116291 rad | 1.126803 rad |
| Maximum translation | 32.757469 cells | 32.675995 cells |

Therefore the dense-bank fixture's unresolved events are not immovable-material
collisions, stale records or failed authoritative writes. They are exhausted
searches for a reachable empty cell within the retained eight-step additional-
distance bound and nine tangent probes.

These are cumulative attempts, not unique material cells. Accepted async sample
counts and repeated contact with the same crowded region affect raw totals, so
the earlier `41dc25ca` counts and the two host totals are not deterministic
cross-run regression metrics. The within-run cause partition and proportion are
the qualified observations. The high proportion is a retained production limit,
not a success criterion.

## Artifacts and author readback

- Exact-source artifact `12783461612`, ZIP SHA-256
  `6329b202eae195ff5ff7219a83c4f4ae2b2bf4ef9ef355d2a37cce7bb6e23e97`;
  archived source SHA-256
  `09cc0259dfa3e1578513377da969d2c5a81223ad48e942e3907621bb92800473`.
- Linux execution artifact `12782857748`, ZIP SHA-256
  `40cd07bc1ad2d9d148b5a93855a4a5a311aa58f69e22a383272fb9abf5a4273e`;
  runtime SHA-256
  `626ca18ee6e5498692e856195d964faec43968987a6c5adf48af181ae364c236`.
- Windows build artifact `12783142627`, ZIP SHA-256
  `27736a44af94144665563c240f77ff23ec1c9fd6238aae05019e89858a7e0573`.
- Windows execution artifact `12783387800`, ZIP SHA-256
  `e51222022a72285758390ae78e43234069b1aeb25983ed27b890ff27833017eb`;
  runtime SHA-256
  `3a1bb93cca3166ba611db2b1ad867560d7b150e90c2fe6113108e527b627bada`.

The Windows manifest contains 548 inputs. All match the exact source archive;
92 checkout files with pure line-ending differences were restored to canonical
Git bytes before execution and rechecked afterwards. Every reported Windows log
hash and both execution ZIP CRC sets were independently rechecked after download.
This is author reduction, not independent review.

## Preserved failures and remaining gate

Run `40610603466` stopped at a staged-patch checksum mismatch before applying
source. Runs `40611067788` and `40611163555` constructed the intended final tree
but their workflow tokens lacked workflow-file write permission. The exact commit
object was subsequently published by an authenticated fast-forward ref update.
None of those assembly/publication failures is counted as qualification.

The next bounded engineering step is a preregistered ejection-search experiment:
compare distance/tangent or flow-aware destination policies against the same
cause counters, conservation checks, frame cost and hole-preserving geometry.
Reactive Wood/bark, heterogeneous bonds, aggregate chemistry, multiple aggregates,
dynamic desoliding/fracture, persistence/residency, normal-application admission,
formal runtime publication and independent/full review remain open.
