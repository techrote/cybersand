---
title: INV-004 — bounded MicroScenario per-frame copy cost discrimination
status: Current
document-kind: evidence
scope: Source-pinned Main/Workbench UI hot-path inspection and a synthetic Godot copy-cost apparatus; no production changes or measured gameplay-speed claim
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../operations/profiling-observability-and-performance.md, ../systems/material-appearance-and-rendering.md]
---

# INV-004 — MicroScenario per-frame copy cost discrimination (5 November 2026)

## Source custody and question

- Baseline accepted main: `ba9cbc89029be88b812af59b19e5c59829bbcd90`, merged at 2026-11-05 02:00:57 UTC.
- `godot/scripts/main.gd` baseline blob: `791ef440efd6edb206c6f1be33989cb62e9213b2`.
- `godot/scripts/microscenario_panel.gd` baseline blob: `010eecde9754ea786cdeeaf800cca0f29ded4245`.
- `godot/scripts/microscenario_workbench.gd` baseline blob: `2014230bf06c12c6a084b359229cbd0682313dfb`.
- Existing independent graphical work: [PR #403](https://github.com/techrote/cybersand/pull/403), **draft and not integrated** at this checkpoint. Its reported 1.4–4.6 ms `Main._process` observation is a separate local Windows workload; no attribution of any portion of that time to this particular path is justified.
- Existing Windows Godot shutdown causal A/B: [PR #401](https://github.com/techrote/cybersand/pull/401), independently owned. This experiment does not attempt to explain or repair `0xC0000005`.

The bounded question is whether `Main` spends nontrivial per-render-frame CPU time copying MicroScenario data which only changes on completed worker publications, before any proposal to alter Main, native World, shader or worker. This is **one hypothesis**, not a demonstrated bottleneck.

## Source-verified control flow (no timing claim)

1. `main.gd:1881–1884`: for non-shared-workbench sessions, every `_process(delta)` calls `_refresh_microscenario_controls()` regardless of scenario activity.
2. `main.gd:1025–1029`: `_refresh_microscenario_controls()` immediately calls `microscenario_panel.refresh(tower_context)` whenever the panel exists.
3. `microscenario_panel.gd:116–118`: `refresh` unconditionally calls `workbench.refresh(context)` even if the modal liquid panel is closed.
4. `microscenario_workbench.gd:181–183`: `refresh` calls `context.get("microscenario", {}).duplicate(true)` before determining whether a schema-2 scenario is enabled or its UI may be shown. Thus the call site is **one deep-copy attempt per applicable rendered frame**; actual copied content varies with the scenario.
5. **Correction, verified against the actual source on 2026-11-05:** `microscenario_workbench.gd:191–205` calls `overlay.queue_redraw()` only inside `if hash != _shown_hash` (definition-hash change). The earlier statement that it redraws on *every* refresh was wrong. Region overlay repaint cost is **not** an independently established per-refresh bottleneck. The unconditional workbench `duplicate(true)` at line 182 remains source-verified; neither this correction nor the synthetic copy benchmarks attributes real frame-time delay.
6. `main.gd:2872` assigns `tower_context = snapshot.lab_context` only upon consumption of a new worker snapshot, but a second distinct synchronous Web controller also uses the MicroScenario panel. A future cache keyed to desktop snapshot identity **cannot** simply be imposed on Web without a separate identity/freshness contract.

This inspection establishes a repeated allocation/copy opportunity, not a proven amount of time, retained allocation, frame-time reduction or semantic safety of caching. In particular, `Main`'s **shared workbench** branch skips `_refresh_microscenario_controls`; observations measured solely there are not evidence for this path.

## Executable, strictly diagnostic probe

`godot/tests/performance/test_microscenario_refresh_copy_cost.gd` benchmarks the isolated dictionary clone expression under a deterministic synthetic scenario corpus with 0, 64, 256 nested observations and owner-publication strides 1 and 4. It alternates the current **copy every render frame** arm and a deliberately **counterfactual** copy-on-new-publication arm. Its exact artificial readback checksum must match between arms; 800 frames per case, three repetitions; bounded memory and execution.

Example supported command from repository root with an installed matching Godot 4.7 binary:

```sh
godot --headless --path godot --script res://tests/performance/test_microscenario_refresh_copy_cost.gd
```

It prints `INV154_MICROSCENARIO_COPY_PROBE` JSON with engine version, OS, observation count, publication stride, arm, elapsed microseconds, copy counts, digest, repetition and failure count. No game or native runtime is accessed. Its intentional expected copy counts are 800/current arm and 800/stride/counterfactual arm; these are **fixture invariants, not measured performance wins**.

### Actual Windows-hosted synthetic experiment (2026-11-05)

The standalone experiment **executed successfully** in [GitHub-hosted Windows Actions run 41994416705](https://github.com/techrote/cybersand/actions/runs/41994416705) against exact **executed source commit** `94a5b713377b812c21a14c05751c8460f245231b`. It used Windows Server 2022 hosted runner, official **Godot 4.7 stable** (`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`) from the official verified SHA-512-pinned Windows ZIP, and a separate minimal synthetic Godot project. The experimental script blob was `a2a1d571305c38dff2b32f4c75f634b15e792b9e`. The raw engine stdout and structured 36 rows plus engine/source identities are retained as [artifact 13399063622](https://github.com/techrote/cybersand/actions/runs/41994416705/artifacts/13399063622), scheduled to expire after 30 days. **36 rows / 0 parity failures**; clone counts and independent-readback checks passed. The host GPU/driver were irrelevant to this headless synthetic CPU measurement and no actual framebuffer was rendered.

Median total elapsed time for **800 synthetic update iterations**, from 3 independently executed repetitions (units are **microseconds**, not a measured real-game frame time):

| Nested observations | Publication stride | Every-frame clone | Once-per-publication clone |
| ---: | ---: | ---: | ---: |
| 0 | 1 | 1,973 | 2,215 |
| 0 | 4 | 1,773 | 730 |
| 64 | 1 | 66,225 | 65,754 |
| 64 | 4 | 64,596 | 16,456 |
| 256 | 1 | 261,259 | 266,937 |
| 256 | 4 | 277,191 | 70,165 |

At 256 synthetic observations with publication once per four render-frame iterations, the raw every-frame times were `[299117,277191,275897]` µs and the hypothetical publication-only times were `[77367,66202,70165]` µs, a roughly 3.95x **isolated copy-loop time ratio**. At stride one, both arms copy the same amount and no advantage was observed. This strong stride dependence is expected from the *synthetic* contract: **800 versus 200 deep-copy operations**. It does **not** demonstrate a 4x faster CyberSand, production memory reduction, improved FPS, or safe real gameplay cache.

The original first Windows [run 41994278217](https://github.com/techrote/cybersand/actions/runs/41994278217) **failed** after successful download/verification because the harness extracted only the Godot console executable, which requires its GUI companion beside it. The unaltered original failure log and [artifact 13398744342](https://github.com/techrote/cybersand/actions/runs/41994278217/artifacts/13398744342) are retained. The correction extracted both validated members; no production source, benchmark assertions or test input was weakened.

**Limitations:** no real `Main` graphical or input/render profiling, no native World/GDExtension or Rapier runtime in this standalone test, no Windows end-user GPU cohort, no Linux comparison, no claim of cold ANGLE startup or exit-crash repair. Any later documentation-only head differs from the **executed** source SHA above while preserving the tested synthetic script; exact-head qualified gameplay claims would require fresh dedicated execution.

### Follow-up: source-bounded observation/inspection envelope (2026-11-05)

**New source-custody correction to the original interpretation:** Current
[`microscenario_contract.gd`](../../godot/scripts/microscenario_contract.gd)
declares `MAX_OBSERVATIONS = 24` (blob `999e127240bf81bd0c2928b0062bf9e8f9e007e1`).
The original **64/256 synthetic observations** are **outside** a validated
MicroScenario's observation population. Retain their 36 passing results as a
stress test of `duplicate(true)` only, **not** as demonstrated representative
Main-scenario payload sizes. Conversely
[`microscenario_host.gd`](../../godot/scripts/microscenario_host.gd)
(blob `93491fd2d2f0e38d98ea6b8722d8cc466cad7417`) generates
`_interaction_inspection` for unordered pairs of actual material IDs
(`m(m+1)/2` including identical pairs) and includes it in `summary()` as
`interaction_inspection.duplicate(true)`. Unlike the observations array,
this can grow beyond 24 entries; actual cardinality depends on the admitted
scenario and material composition. Neither population was sampled from real
running Main in this investigation.

**Second executed test:** A new isolated script
[`test_microscenario_copy_envelope.gd`](../../godot/tests/performance/test_microscenario_copy_envelope.gd)
(blob `3c58a4571efc0ca8c2e8c417c16c0c90bd599142`) models
0/24 synthetic observations and 1/8/24 material identities, yielding
1/36/300 synthetic pair-inspection entries; all observation populations
respect the current source maximum. The nested inspection record **shape is
illustrative** and is not a native adapter serialization. The script runs
800 iterations per case, 3 repeats, alternating arm order at publication
strides 1 and 4. It checks every-frame vs once-on-publication readback
checksums, exact clone counts, and a **deliberate in-place mutation negative
control**, which must *not* have checksum parity if a future cache assumes
immutability without a proven owner revision contract.

- Exact **executed** SHA:
  `fc1968cae96dfdca6b5dd953b7dd0c3461e6cdf7`; pinned accepted base
  `ba9cbc89029be88b812af59b19e5c59829bbcd90`. The workflow validates
  the contract limit and inspection-source expression before running.
- [GitHub-hosted Windows 2022 run 42001073608](https://github.com/techrote/cybersand/actions/runs/42001073608):
  **SUCCESS**, official SHA-512-verified Godot 4.7 stable (engine hash
  `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`) in a
  minimal **headless** GDScript project; **39 pairs / 78 raw rows /
  0 unexpected parity or clone-count failures**. Independent archival:
  [artifact 13403025613](https://github.com/techrote/cybersand/actions/runs/42001073608/artifacts/13403025613),
  with source identity, raw stdout, baseline-probe JSON and envelope JSON.
  Linux/GPU, real Main/Rapier/native execution, loaded worker participation,
  user-host performance and real publication cadence were **not exercised**.

Median **elapsed time for all 800 artificial iterations** (three repeats;
units below in milliseconds, **not** measured real-game frame time):

| Observations | Synthetic material IDs | Pair-inspection records | Publication stride | Current every-frame clone | Hypothetical on-publication |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1 | 1 | 1 | 3.637 | 3.608 |
| 24 | 1 | 1 | 4 | 28.964 | 7.917 |
| 24 | 8 | 36 | 1 | 58.286 | 58.591 |
| 24 | 8 | 36 | 4 | 58.694 | 14.979 |
| 24 | 24 | 300 | 1 | 320.337 | 322.229 |
| 24 | 24 | 300 | 4 | 308.078 | 76.957 |

In the 24-observation/8-material sample, the current every-frame branch
costs approximately **0.0734 ms per synthetic iteration**; at 24 materials
and 300 pair inspections it costs **0.385 ms**. These are stand-alone
dictionary-copy loop averages on the hosted Windows CPU, **not actual
`Main._process` timings**. With stride 1, no material reduction was
demonstrated. The stride-4 improvement is almost entirely explained by 800
vs 200 copies. It does **not** justify a cache or establish a real
desktop performance fix.

**Important negative control:** with 24 observations, 8 materials and
one **deliberate in-place nested change** between nominal publications,
the per-frame arm digest was `685803` versus `684603` for
once-on-publication (identical across 3 repetitions).
This is an intentionally constructed aliasing counterexample, **not**
proof that the current asynchronous desktop owner mutates this field in
place. It establishes that optimization requires proving every relevant
desktop/Web ownership and revision path, rather than inferring safety
from synthetic identical reads.

**Disposition:** New evidence narrows the likely cost domain and corrects
the earlier 64/256-observation extrapolation. The actionable next
discriminator remains a **real Main** timestamped phase breakdown and
source-custodied actual per-scenario snapshot frequency/serialized
payload sizes, preferably on the target Windows graphical GPU cohort.
No production cache, semantic change, or merge authorization follows.

## Admission / next discrimination

1. The Windows Godot 4.7 synthetic probe has now run and its positive/negative source-bound results are retained above. A Linux synthetic cohort is still absent. Determine whether the copied real scenario payload and publication cadence actually produce meaningful Main CPU cost on a real graphical host before changing any production source.
2. If material, use an **isolated temporary host instrument** or source-qualified benchmark branch to time the real `workbench.refresh` subphases in both a running and paused MicroScenario, with unchanged actual content, snapshot publication rate, camera and UI. Do not infer end-to-end fps from the synthetic fixture.
3. Only then propose a guarded optimization. Any cache must preserve desktop and Web refresh, same-definition reset, captured observations, modal/hide state and the bounded-run step acknowledgment. The current `godot/tests/test_microscenario_workbench.gd` and `test_microscenario_workbench_lifecycle.gd` cover important behavior and must pass unchanged, alongside real-host tests.
4. Do not modify `main.gd`, `physical_actor_overlay.gd`, shader or native worker while #409/#402/#403/other owners hold adjacent active work. No production speedup, fix, merge or owner disposition is claimed here.

**Disposition:** DIAGNOSTIC APPARATUS ONLY. This is a new controlled cost discriminator and precise source-derived hypothesis, not a finished performance optimization. Preserve negative data and stop before production integration.


## Third bounded discrimination: real Workbench Control execution (5 November 2026)

The previous Windows results measured **standalone Dictionary.duplicate(true)** only. A new
isolated apparatus `godot/tests/performance/test_microscenario_workbench_refresh_cost.gd`
now exercises the **actual source-byte-identical** `CyberMicroScenarioWorkbench.refresh()`
and compares it to a direct deep-copy control, using a minimal real Godot Control
tree with six source-bounded synthetic payload/visibility combinations:

- 0 observations / 1 material active; 24 observations / 8 and 24 materials active;
- 24 observations / 24 materials but inactive, pending-guarded or HUD-hidden.
- 300 inspection-pair records at the 24-material limit; no native-generated records.

The Windows workflow copies `microscenario_workbench.gd` and
`microscenario_comparison.gd` byte-for-byte into a scratch project and records
their SHA-256s. **Only** the separate scratch MicroScenario contract/identity
objects are synthetic; the runtime and UI `refresh()` method under test are
unchanged. Its self-checking cases verify guarded visibility, overlay suppression,
deep-copy non-aliasing, observation/inspection retention and matching readback
checksums against the direct-copy arm. Each arm has three repetitions of 64
refreshes, interleaved to reduce monotonic timing bias. The primary readout is
**elapsed CPU-loop time**, not Main frame time or graphical throughput.

A first Windows hosted experiment was preserved as
[run 42009471611](https://github.com/techrote/cybersand/actions/runs/42009471611):
the first two original standalone probes passed, but the new experiment failed
before execution because the scratch project's unregistered `class_name`
was used as a type annotation in the *diagnostic driver*. No production script
or physics input was changed to repair the driver. Subsequent execution remains
source/head-specific; a successful continuation must not relabel the original failure.

This remains a headless Windows **presentation-control** study, not a fully
constructed `Main`, not a Windows GPU/ANGLE run, not native/Rapier participation,
and not a runtime implementation change. Even a large real-Control-vs-copy
delta only prioritizes later real-Main profiling; it cannot authorize caching
mutable snapshots or claim an FPS win.


### Windows execution and bounded conclusion (2026-11-05)

The **real workbench refresh apparatus now passed** on GitHub-hosted Windows
Server 2022 with SHA-512-pinned official Godot 4.7 (headless, standalone
presentation Control tree). Exactly executed commit
`e8addd9b68f3d9baa3fab4e70f6e397e85851537`, tree
`4c461cbfdead8078e2364918034aa4d4ed86a0f0`, test driver blob
`9cbaf288253b0d2880d3b9c25fe586b1ca52cff5`.
[Windows workflow run 42011245061](https://github.com/techrote/cybersand/actions/runs/42011245061)
**SUCCESS**, [raw output and source custody artifact 13407825426](https://github.com/techrote/cybersand/actions/runs/42011245061/artifacts/13407825426).
The two original copy tests ran unchanged and passed. The new **real Control**
driver reported 6 cases × 3 repetitions × 2 interleaved arms = **36 rows,
0 contract/parity failures**, with non-aliasing, visibility and guard controls.

Three-run medians below are elapsed milliseconds for **64** refreshes, not a
single displayed-frame time. The direct-copy arm is a control, **not** a
candidate production implementation.

| Synthetic condition | Actual `Workbench.refresh()` | Direct `duplicate(true)` |
| --- | ---: | ---: |
| Active; 0 observations, 1 material, 1 pair | 0.850 | 0.430 |
| Active; 24 observations, 8 materials, 36 pairs | 7.433 | 6.933 |
| Active; 24 observations, 24 materials, 300 pairs | 36.391 | 36.730 |
| Inactive but retained 24/24 payload | 36.700 | 37.048 |
| Guarded but retained 24/24 payload | 34.799 | 35.386 |
| HUD hidden but retained 24/24 payload | 36.294 | 34.965 |

**Causal discrimination:** At the 24-material synthetic payload the unmodified
Workbench's total refresh time is essentially indistinguishable from the
dictionary-copy control at this measurement precision. The actual presentation
controls do not demonstrate a large *additional* repeated cost. The method
copies the payload **before** the active/guard/HUD checks, so intentionally
retaining the same 300-pair payload in disabled/guarded/hidden synthetic cases
does not remove most copy cost. For the 36-pair synthetic case, median full
refresh is about 0.116 ms per call; for 300 pairs, about 0.569 ms. These
values are **runner-specific source-control loop times**, not measured
`Main._process` time, user FPS or GPU frame latency.

The results strengthen the **hypothesis that payload copying dominates this
particular standalone UI path**, but cannot establish (1) how many material
pairs and observations occur in real user sessions, (2) whether inactive real
owners retain such a payload, (3) actual publication cadence, or (4) the
effect of altering snapshot ownership. No caching, Main edit or production
optimization is authorized.

**Negative attempts preserved**:
[42009471611](https://github.com/techrote/cybersand/actions/runs/42009471611)
failed due an unregistered standalone driver type;
[42010784561](https://github.com/techrote/cybersand/actions/runs/42010784561)
failed because isolated `class_name` registry was not imported. The
[final passed workflow](https://github.com/techrote/cybersand/actions/runs/42011245061)
pre-imports only its minimal scratch project, without modifying the copied
production workbench. Superseded intermediate diagnostic attempts were
cancelled rather than treated as passing execution.

**Next bounded test:** instrument non-shared-workbench `Main._process`
on a real Windows graphical host, capture actual owner-derived MicroScenario
inspection cardinality and snapshot cadence, and timestamp the existing
`microscenario_panel.refresh` slice in context of Main/native/Rapier.
Compare ordinary/paused/hidden sessions and control for CPU overhead and
native snapshot frequency. The native renderer/GPU, Web and shutdown routes
remain separately owned and unqualified by this report.

### CI scope

The diagnostic Windows execution is source-qualified to the exact SHA above.
The initial documentation/provenance check for that SHA failed **only on
workflow scheduling policy**: unconditional `cancel-in-progress: true` could
discard an explicitly requested manual workflow run. This is a real CI policy
failure, not a passing check, and must be corrected with dispatch-isolated,
non-cancelling manual groups and a fresh exact-head provenance run.
The expensive Native and GDExtension jobs were skipped by Draft policy;
they are not source-qualified implementation passes.
