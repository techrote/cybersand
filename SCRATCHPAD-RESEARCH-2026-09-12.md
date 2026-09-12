# Preliminary research — 12 September 2026

This is preparation, not production implementation or architecture approval.

## Intake

Research branch: `codex/research-preparation-2026-09-12`.
Base: `d39e31f03f2e39b0022d507b79fbee5c2439436d`, the published issue-19 Water Feel Lab documentation checkpoint. The older `main` branch is not the experimental control.

The revised issue #19 governs Water presentation and human-test preparation. G-C, G-L and G-P are complete. G-final remains open. Issue #18 still needs a measured directional-persistence target; issue #20 implementation remains blocked; dynamic issue #12 still needs an ownership decision and support evidence.

## Preregistered offline work

Before executing calculations, register these bounds:

- Issue #19: mass widths 3 through 8; coherent duration 0 through 12; exact rational half-up input quantization; film threshold 48/255; normalized rest tolerance 1/255 and separately named literal-one tolerance. Enumerate all byte-normalized inputs and legal mass pairs. Check arithmetic, not whole-engine behavior.
- Issue #19: compare four nonempty coverage levels proposed as 1/4, 1/2, 3/4 and 1, with Empty separately zero. Compare nearest, positive-preserving nearest and ceiling. Test up to sixteen interface normals with polygon clipping and 1x, 4x and 8x sampling. Report approximation errors without choosing a presentation winner.
- Issue #19: prepare one validated policy format, separate simulation and presentation identities, deterministic scenario specifications and counterbalanced candidate schedules. Do not conduct a human preference study.
- Issue #18: calculate optional-storage cost for clustered and dispersed use with fixed 128-square chunks and 32-square activity blocks. Include stated metadata assumptions. Do not claim engine performance or admit flow-history implementation.
- Issues #20 and #12: explore a finite abstract transfer model with at most two material units and two slots. Check reservation, stale acknowledgements, cancellation, full destinations and failed-world handling. Retain counterexamples to deliberately incorrect protocols. This is design testing, not a motion implementation or proof about the engine.
- Issue #14: assemble source references, decision boundaries, primary-source research and the smallest useful next experiments.

All assertions and comparison rules above precede the calculations. Generated compact tables may be committed; raw logs, builds and caches must not be committed. No issue closure, upstream merge, production migration or gate approval is part of this task.

## Environment limits

GitHub source reads are pinned to the stated checkpoint. This environment cannot inspect the active Windows workspace, loaded DLL, Godot application or target GPU. Direct Git transport failed DNS resolution. Standalone calculations must not be described as engine, desktop or Web validation. Repository-wide checks require a full checkout and their absence must remain explicit.

## Publication

Place reusable tools in `tools/research/issue_preparation/` and dated evidence in `docs/audits/2026-09-12-research-preparation/`. Add links here after those files exist. Keep research outside ordinary Current documentation answers.

## Completed work and updated validation evidence

The preceding registration is preserved from commit `aaa811ea6e0a76811999ee95eb93312b78bf7a74`. The [dated addendum](docs/audits/2026-09-12-research-preparation/registration-addendum.md) registered projection and extended finite-state checks before they ran. Results are collected in [PR #21](https://github.com/techrote/cybersand/pull/21); this is a research-only proposal against the published #19 planning branch, not a merge into older `main`.

**Start with the [research overview](docs/audits/2026-09-12-research-preparation/README.md).** The following focused notes and executable references are complete:

| Area | Evidence and next-use route |
|---|---|
| Water policy and apparatus | [Arithmetic, validated identities, five geometric recipes and reset obligations](docs/audits/2026-09-12-research-preparation/issue-19-policy-and-lab.md) |
| Fractional presentation | [Quantizer trade-offs, normalized-byte oracle, interface geometry and raster limitations](docs/audits/2026-09-12-research-preparation/issue-19-presentation.md) |
| Optional state | [Clustered/dispersed allocation estimates and the still-required motion admission](docs/audits/2026-09-12-research-preparation/issue-18-storage-and-admission.md) |
| Representation handoff | [Finite ownership checks, four faulty-protocol traces and unmodeled obligations](docs/audits/2026-09-12-research-preparation/issues-12-20-ownership.md) |
| Programme sequence | [Gates, evidence boundaries and the next #19 implementation slice](docs/audits/2026-09-12-research-preparation/issue-14-evidence-and-next-steps.md) |
| Provenance and API audit | [Four observed conversion warnings and artifact-rebuild boundaries](docs/audits/2026-09-12-research-preparation/issue-3-provenance-and-api-audit.md) |
| Research sources | [Pinned repository contracts and six primary-source research topics](docs/audits/2026-09-12-research-preparation/primary-sources.md) |
| Executed validation | [Passes, failures, commands, artifact identities and platform limits](docs/audits/2026-09-12-research-preparation/validation.md) |

The local full-checkout limitation was resolved through a branch-scoped hosted run, not by claiming access to the owner's machine. Tested research source `f0907126339033f849df40e9525caa66462e744a` passed 23 standalone research tests, two byte-identical precomputation runs, independent C++/Python parity, and the existing 55-test native suite. Documentation, historical M11 and both retrieval evaluations passed. The overall job correctly failed its runtime-provenance gate: 14 source-input mismatches require existing Windows/Linux Godot artifacts to be rebuilt. All 18 required LFS payloads were present.

The [immutable generated run](docs/audits/2026-09-12-research-preparation/runs/f0907126339033f849df40e9525caa66462e744a/README.md) includes vectors, recipes, numerical tables, the synthetic atlas, state-graph results, source/data hashes and individual check outcomes. Evidence publication was committed as `45d1754096f873511fc7b2f09de3a4bae487d1e2`. The source for reproduction is [the standalone tool directory](tools/research/issue_preparation).

No production native/Godot source, shader, saved-world format, dependency pin, retained runtime binary or runtime manifest was modified. No issue is closed or gate passed by this task. The actual Water Feel Lab, #17 whole-engine policy correspondence, desktop/Web rendering and human evaluation remain implementation/acceptance work, now supported by concrete preparation instead of assumed behavior.
