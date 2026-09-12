# Preliminary research and precomputation — 12 September 2026

**Dated research evidence, not a production migration or an issue-completion decision.** Author: OpenAI assistant, on the owner's instruction to undertake useful preliminary work across the issue programme.

## Start here

The source baseline is `d39e31f03f2e39b0022d507b79fbee5c2439436d`, the published #19 Water Feel Lab planning checkpoint. Research code is committed at `f0907126339033f849df40e9525caa66462e744a`. The [root registration](../../../SCRATCHPAD-RESEARCH-2026-09-12.md) predates calculation; the [addendum](registration-addendum.md) predates projection and extended-state checks. This branch is deliberately based on `codex/issue-19-water-feel-lab-sync`, not the older `main`.

| Workstream | Actual output | Decision boundary |
|---|---|---|
| #19 Water policy | Validated standalone configuration, 156 legal vectors, 174,720 exhaustive local mass-pair checks, exact quantization and delay tables | Not runtime World policy or #17 whole-engine correspondence |
| #19 presentation | Three four-level quantizers; 64 orientation/coverage lookup entries; 576 sampling cases; synthetic SVG atlas; C++/Python byte-projection oracle | Not a shader integration, GPU benchmark or visual acceptance |
| #19 lab preparation | Five deterministic geometric recipes, exact initial ledgers, six mass/four coherence counterbalanced orders, separate hidden mapping and coverage manifest | No human observations; not H-ready |
| #18 optional storage | Explicit clustered/independent/dispersed allocation estimates with metadata assumptions | No storage winner, motion implementation or G-M admission |
| #12/#20 ownership | Finite state exploration, reservation/revision/quarantine checks, four retained faulty-protocol traces | Not an implementation proof, concurrency proof, ownership ADR or ballistic admission |
| #14 evidence | Gate map, primary-source notes, integration hazards and bounded next steps | G-final remains open; previous gate decisions are not rewritten |
| #3 / validation | Fresh full-checkout CI, 55 native tests, documentation/M11/retrieval checks and a 14-error runtime-provenance inventory | Existing Godot artifacts are not source-matched; no binary or manifest repair |

**Fresh hosted validation:** 23 research tests and 55 existing native tests passed. Documentation, historical M11 and both retrieval checks passed. The overall job correctly remains red because the retained Windows/Linux Godot runtime artifacts require rebuilding for 14 source-input mismatches. All 18 LFS payloads were present. See [validation](validation.md) for exact source identities and [the API/provenance audit](issue-3-provenance-and-api-audit.md) for the four observed numeric-conversion review points.

## Findings that materially change the next implementation

**Tiny sources need their own accounting.** A separately rounded 1/255-cell input is zero at mass3, mass4, mass5, mass6 and mass7. Repeating that operation does not accumulate a drop. That is input quantization, not later simulation leakage. A reservoir or different emission quantum must be an explicitly versioned policy, not an unnoticed repair.

**Four-level coverage has a visibility cost.** At mass8, nearest quarter coverage hides 31 positive mass values; retaining every positive value gives the smallest quantity a quarter-cell footprint, 63.75 times its normalized area. The study reports both, without selecting a winner or silently modifying what “four visible levels” means.

**The current Water condition projection cannot simply retain raw mass when the lattice changes.** A full mass3 cell has raw value 7, not 255. The proposed Water-only normalized-byte projection preserves all 504 legal states across mass3..8 and produces identical four-level outputs in all 1,512 direct/two-stage comparisons. Independent Python and C++ arithmetic outputs match. No bridge code has been changed.

**Geometrically correct area is not necessarily stable raster coverage.** The continuous half-plane solver's worst error was about 1.11e-16 cell area. The registered point-sampling experiment still produced maximum errors of 0.75, 0.125 and 0.09375 at 1x, 4x and 8x respectively, across the tested phases. These are deliberately synthetic samples, not measured Godot defects.

**Low cell density need not mean low block density.** At independent 1% usage, a 32x32 allocation block is touched with probability 99.9966%. Clustering and allocation granularity must accompany density percentages. The assumed sidecar still uses less payload memory than universal 4-to-8-byte widening here; no performance advantage follows from that calculation.

**Reservation is not ownership.** The finite safe models close at 1,368 and 7,200 states for one and two slots, with no invariant violations. Broken variants yield one-to-five-action counterexamples for early source release, duplicate ownership, dropping on full return, and stale acknowledgement. Their simplicity is intentional: these are reviewable protocol obligations, not proof about the engine.

## Reading routes

[Policy and lab integration](issue-19-policy-and-lab.md) covers the arithmetic, identifiers, recipes and reset contract. [Presentation](issue-19-presentation.md) explains the coverage trade-off, normalized bytes and render-test design. [Storage and admission](issue-18-storage-and-admission.md) gives the allocation model without reopening G-L. [Transfer ownership](issues-12-20-ownership.md) interprets the state graph and its omissions. [Programme next steps](issue-14-evidence-and-next-steps.md) identifies what can proceed and what stays held. [Sources](primary-sources.md) distinguish repository authority from outside research. [Validation](validation.md) separates observed passes, failures and unavailable platforms.

The complete generated bundle is under [the immutable source-identified run](runs/f0907126339033f849df40e9525caa66462e744a/README.md). Its [checks.json](runs/f0907126339033f849df40e9525caa66462e744a/checks.json) records individual command outcomes, rather than treating successful evidence publication as an all-green validation gate.

## Reproduce independently

Run each command separately from the source repository root. Python 3.10+ is sufficient for the standalone studies; no third-party package is required.

```text
python -m unittest discover -s tools/research/issue_preparation -p "test_*.py" -v
```

```text
python tools/research/issue_preparation/precompute.py --out validation/local/issue-preparation-reproduction
```

The resulting directory includes all policy vectors, input ledgers, counterbalanced orders, hidden-key example, geometric/raster tables, SVG, allocation estimates, protocol traces and SHA-256 manifest. It is a local output directory, not a production asset path. Do not run with Python optimization (`-O`), which removes the deliberately exhaustive assertions.

The independent C++ oracle is optional for ordinary reproduction; compiler commands and the exact compared output are documented in the validation record. The temporary CI collector runs only on the named research branch, stages only a new source-SHA evidence directory, uses fast-forward-only publication, and never modifies `main` or release artifacts.
