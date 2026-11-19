---
title: Waterwall discharge, crest flight and slosh evaluation
status: Current
document-kind: audit
scope: Windows and WSL research evidence for the opt-in Wave Waterwall 002 Draft/HOLD candidate
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../architecture/ballistic-water-v1.md, ../operations/workbench-water-lab.md]
---

# Waterwall 002 evaluation, 19 November 2026

Draft/HOLD [PR 676](https://github.com/techrote/cybersand/pull/676) starts at
`5c415245b6ccf45168a60f0afb5e3626618795b7`, the final reviewed head of [PR 672](https://github.com/techrote/cybersand/pull/672).
The owner's 1024² generated start has SHA-256 `925096d1e9984b855b5465309ef12869a47e29052e0cabd5a25788a051b77107`.
The GEN-007 terrain has SHA-256 `9b8b4ef6339c4d922c499dd3240198209a8a3cfcca9f9fd49cf1b6fa918f91f5`.
The 166-stamp input used by the native harness has SHA-256 `c2dee3e3562b1369fdab0f3874716539704e5eae5a29951f262a0efc599b2a4e`.
Every map run starts with 3,052,350 units across all reservoirs. The historical lower-reservoir probe
is the half-open rectangle `440,540,192,102` and starts with 5,928 full-cell equivalents.

## Protected source review

The chunk constructor reserves a previous-flux field when smoothing is enabled.
The Wave physical hash incorporates the selected nonzero parameters and the live crest flight counters.
Neither change affects the material catalogue or an authored material transition.

| Protected source | Previous LF SHA-256 | Current LF SHA-256 | Source-first commit |
|---|---|---|---|
| `native/src/world.cpp` | `80e05f673b3d6ba35daa7c741805aa272f149e7742d162c94c8c0bd9bdbc1e83` | `fef05d7f0318f0a54948144ee22f30721555a567ac3963309c927b60fbfb0cf0` | `d876bd57897dd421b720e73d15d7c89a830b4896` |
| `native/src/world_pressure.inc` | `c5d639212290c9a4faee47f86a3cfe5bf664a5a51d241d4b5c9c1cdb985b6105` | `bce02406c837967e95206ea6f6e93145b2b327a1d42e3e6e29da9d3507603d03` | `d876bd57897dd421b720e73d15d7c89a830b4896` |
| `native/src/world_pressure.inc` (Workbench Apply) | `bce02406c837967e95206ea6f6e93145b2b327a1d42e3e6e29da9d3507603d03` | `0e012c7f2944cf8d5f9d8aa383e8635bbbd313d26fc5079160a02d5f4e1e3a0f` | `d4df71fc6bc1bf6267270a4c1445207a02716317` |
