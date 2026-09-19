---
title: Weekend hosted-runner routing benchmark
status: Current
document-kind: audit
scope: Temporary 2026-09-19 to 2026-09-21 GitHub ubuntu-slim versus Avrea 1-vCPU routing experiment
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../operations/github-development-and-release.md, ../operations/local-build-and-validation.md]
---

# Weekend hosted-runner routing benchmark

## Purpose and source checkpoint

This temporary experiment measures real CyberSand CI job classes on GitHub
ubuntu-slim (1 vCPU) and Avrea avrea-ubuntu-24.04-1-vcpu before assigning the
short-job lane permanently. It starts from main
d6a616eafdbbda56a691256fd48e463ffdad58de, where sustained Linux
GDExtension, Native and Web work is already routed to Sengi and Avrea remains
available for latency-sensitive and wide-runner work.

This experiment does **not** change the required CI source of truth, required
checks, physics semantics, build pins, or the current Sengi-default routing
decision for sustained work.

## Temporary matrix

.github/workflows/runner-weekend-benchmark.yml shadows four representative
job classes across both providers:

| Workload | Why included | j1 / j2 meaning |
|---|---|---|
| latency-probe | Measures the micro-job / gate-like pickup floor | Two independent repeats; SCons is not involved |
| docs-consistency | Current short real repository/provenance job | Two independent repeats; SCons is not involved |
| historical-regression-shard0 | Deterministic real Godot regression around the short/medium crossover | Two independent repeats; SCons is not involved |
| gdextension-linux-build | Real pinned SCons compile workload | Actual SCONS_JOBS=1 and SCONS_JOBS=2 |

Each workload runs on both ubuntu-slim and Avrea 1-vCPU. Matrix failures are
non-gating (continue-on-error) and do not replace or satisfy normal CI.

The full Native, Web demonstrator and Web-toolchain jobs are deliberately not
quadrupled. They are sustained/heavy lanes already assigned to Sengi and are poor
fits for the short-runner routing question. Release-hash publication is
tag/manual-only rather than a naturally sampled weekend job. The existing tiny
GDExtension regression gate is represented by the latency probe instead of
duplicating its upstream dependency graph.

## Measurement contract

Each shadow job retains a seven-day artifact containing metadata.json,
runner.txt, and stages.tsv, plus workload evidence where applicable.
Records include:

- provider and requested runner label;
- workflow event, source SHA/ref, run ID and attempt;
- first-step timestamp and acquisition delay from workflow creation;
- actual runner identity, OS/architecture, nproc and available tool identities;
- workload identity and whether the j1/j2 value was applied to SCons or is
  only a repeat number;
- explicit cold/no-Actions-cache classification;
- measured setup/workload stages where the workload exposes them;
- measured benchmark wall time and job status at finalization.

The experiment intentionally avoids an Actions cache so provider comparisons do
not silently become cache-placement comparisons. Network downloads and checkout
remain part of real-world wall time; measured build/workload stages allow them
to be separated from the core workload where practical.

## Interpretation

Do not route individual invocations dynamically from their current contents or
runtime. After the weekend, group results by **job class** and compare median plus
P75/P95 acquisition and wall time. Use the same historical-job classification
approach used for vCPU selection.

For gdextension-linux-build, compare j1 and j2 independently on each
single-vCPU provider. For the other three workloads, the two matrix values are
replicates and must not be interpreted as SCons parallelism.

The provisional policy under test is:

- GitHub hosted only for genuinely tiny classes where its pickup advantage is
  worth the paid hosted-runner premium;
- Avrea 1-vCPU for short latency-sensitive work above that micro tier;
- Sengi 2/4/8-vCPU as the normal sustained-CI default;
- Avrea 16/32-vCPU where wide parallelism is materially useful.

No exact crossover is accepted until the retained weekend evidence is reduced.

## Expiry and cleanup

The active window ends at **2026-09-21 05:00 UTC (06:00 Europe/London)**.
Every benchmark matrix job checks that deadline before performing workload work.
A scheduled expiry job runs immediately afterward and disables the benchmark
workflow through the GitHub Actions API. This gives the campaign both a data-plane
deadline and a control-plane stop, so the 16-way shadow matrix cannot silently
become permanent CI.

After reduction, remove the temporary workflow rather than repurposing it as a
runtime classifier. Preserve this audit and any final reduced results as dated
evidence.
