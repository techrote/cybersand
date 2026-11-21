# Independent SWARM45 package archive review 003

**Verdict: GO for the four-file archive-producer repair to enter the next freeze and hosted qualification. No confirmed unresolved P1/P2 finding in this delta.** This is not a passing hosted Windows package lifecycle result or merge admission. The separately reported historical-receipt inspection defect is outside this review.

Reviewer: `/root/swarm45_publication_review`. No repository edits, commits, workflow requests or remote actions were performed.

## Independently verified cause

I inspected the four-file diff and the retained minimal import diagnosis. I independently reconstructed both archive variants directly from committed source `10fe808ac7f6a4b9c07f7d168763b41957359e57`, then compared the resulting bytes with the retained post-import files and every hash in `swarm45-import-line-ending-diagnosis/comparison.json`.

All **8 before/after records match exactly**. For each of the four Rapier import sidecars, the old Windows-style archive contains CRLF while the retained editor result is LF. Removing only CR from CRLF produces bytes exactly equal to both the editor result and the original committed Git blob. The canonical archive already contains those exact bytes and remains byte-identical after import.

| Rapier sidecar | Old archive bytes | After import / canonical bytes | CRLF sequences removed |
|---|---:|---:|---:|
| `Radial2D.svg.import` | 1,118 | 1,074 | 44 |
| `logo_square_2d.png.import` | 1,008 | 968 | 40 |
| `icons/Fluid2D.svg.import` | 1,121 | 1,077 | 44 |
| `icons/StateManager2D.svg.import` | 1,113 | 1,070 | 43 |

The retained logs identify Godot `4.7.stable.official.5b4e0cb0f` and show both four-asset import passes completing. This is a Windows-style Git archive reproduced with a **Linux editor**, as the diagnosis explicitly states. It is not represented as local Windows execution or a substitute for the next hosted Windows lifecycle gate.

## Repair and preserved contracts

`committed_archive()` supplies `core.autocrlf=false` and `core.eol=lf` only to the child `git archive` command. It does not mutate local/global Git configuration. Explicit per-file attributes remain authoritative. The ordinary Windows evaluator producer and isolated SWARM source stage both use this helper.

The repair retains every sidecar, asset and authored import setting. It does not normalize a sealed package after hashing, omit mutable files from its manifest, suppress integrity failures or weaken source/runtime checks. I confirmed the custody helper, shared project/package verifier, SWARM package identity wrapper, publication candidate verifier and publisher are unchanged from the r2 execution source.

Existing consumers retain the same archive path inventory, source-built adapter replacement, platform filtering, exact LFS payload checks, launchers and package manifests. Explicit CRLF scripts remain CRLF; binary bytes remain exact. The stage test changes only its mocked archive call to the new shared producer.

## Independent tests and exact source

I independently ran both package tests (**2 passed**) and the complete SWARM45 helper suite (**25 passed**). The new real-Git regression reproduces the old raw-hash mismatch, proves the canonical result, and verifies unchanged archive inventory, explicit CRLF attributes, binary bytes and local Git settings. Existing cross-platform package and source-stage regressions still pass.

All four actual source-file hashes match `swarm45-package-archive-review-checkpoint.json`. The independent machine-readable review retains those hashes, all eight reconstructed byte comparisons and test outcomes:

`swarm45-publication-review-evidence/package-archive-causality-review.json`

SHA-256: `afddbc545577831fd648ba08868792d7790d7cdfb1873745891a4c8e24ba85dc`.

The next hosted run must establish that the sealed Windows evaluator survives graphical execution and subsequent accepted-main smoke preflight with unchanged exact package bytes. Earlier partial successes remain separate evidence; this review does not convert them into an aggregate pass.
