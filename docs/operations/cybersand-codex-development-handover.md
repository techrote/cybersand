# CyberSand M11 — Codex Development Handover

```yaml
document-status: Current
document-purpose: Operational handover for continued human- and Codex-assisted development
authoritative-baseline: Audited CyberSand M11
last-reviewed: 2026-08-29
audience:
  - project owner
  - Codex development agents
  - maintainers and reviewers
```

## 1. How to use this document

Read this before asking a new Codex task to modify CyberSand. It complements the repository's RAG-optimised documentation; it does not replace `README.md`, `AGENTS.md`, `docs/`, `docs/decisions/`, build manifests, or validation records.

This handover preserves decisions and preferences that emerged during conversational development and could otherwise be easy to lose. When it conflicts with executable source or a newer approved ADR, investigate rather than silently choosing one account. The audited M11 source is the implementation baseline.

Claims in this document use these meanings:

- **Current** — implemented or verified in audited M11.
- **Approved** — agreed direction; implementation may be partial.
- **Planned** — desired next work, not a current guarantee.
- **Deferred** — deliberately postponed.
- **Rejected** — considered and intentionally not pursued.
- **Owner preference** — a product or workflow preference that should guide trade-offs.

## 2. Authoritative baseline and identity

Only the completed, re-audited M11 workspace is an acceptable development source. Never initialise work from the older M6 archive or copy M6 files over M11. Older milestone archives are historical evidence and rollback material only.

Known audited M11 identity:

| Item | Value | Status |
|---|---|---|
| M11 source commit | `05ea45fda7bdd7b0150eb86c4922c202e89e08f4` | Current audited source identity |
| Render-race-fix parent | `c644b235fbcb5e085802918c0d6cebec118b6405` | Historical identity |
| Race-fix patch SHA-256 | `f46101539bfcd86b017c01a738377d647da85894ca81f4a68dec35032ea6e28a` | Provenance evidence |
| Race-fix stable patch ID | `50aae8…` | Provenance evidence; consult the full manifest before exact comparison |
| Compatibility ID | `cse-m11__setup-v2__godot-4.7.5b4e0cb0f__rapier2d-0.35.2__godotcpp-101ae380__gdapi-4.7` | Current |
| Godot | `4.7.stable.official.5b4e0cb0f` | Exact pin |
| `godot-cpp` | commit `101ae38034304346a46ea9ea84ae156d3e860496` | Exact pin |
| Godot Rapier Physics 2D | `0.35.2` | Exact pin |
| Audited M11 validation | 34 passed, 0 failed, 0 timed out, 1 inconclusive, 0 skipped | Historical audited result |
| Inconclusive item | LeakSanitizer could not operate under the hosted `/proc` restrictions; ASan without leak detection and TSan passed | Environment limitation, not a pass or failure |

The private GitHub migration was reported complete by the project owner. The prepared migration history previously identified a repository HEAD of `edd582124b62cfc4bd86682a44526867c206caf2`, while the annotated audited-M11 tag dereferenced to the source commit above. Treat those as handoff evidence, not a substitute for checking the actual remote.

At the beginning of every fresh task, run read-only checks and record:

```bash
git remote -v
git status --short --branch
git rev-parse HEAD
git tag --points-at HEAD
git show --no-patch --decorate --oneline
git lfs ls-files
```

Confirm the current branch, remote privacy, audited tag, Git LFS availability, and whether CI has advanced since this handover. Do not claim a remote commit, CI result, Windows runtime result, or clean-clone result without observing it.

## 3. First 30 minutes in a fresh Codex task

1. Open the private `cybersand` repository as the task workspace and confirm it is M11-derived using the identities above.
2. Read `AGENTS.md`, the root `README.md`, the documentation index, `docs/status-and-roadmap.md`, relevant files under `docs/decisions/`, and the validation/build instructions before editing.
3. Inspect `git status`; preserve unrelated owner changes. Never clean, reset, or replace a dirty tree merely to simplify the task.
4. Fetch Git LFS objects if the checkout reports pointer files. The migration was prepared with 18 LFS-managed runtime binaries; verify the present count rather than assuming it is unchanged.
5. Identify the narrowest applicable tests before modifying code. Add an explicit timeout to any runtime or headless Godot command.
6. State whether the request changes native simulation, the Godot adapter/presentation layer, the Rapier adapter, shaders, packaging, documentation, or more than one boundary.
7. Preserve the current RAG hierarchy and status vocabulary. Update the relevant status/ADR material when behavior or architectural commitments change.
8. Make a focused checkpoint commit after validation. Do not publish, tag, release, or change repository visibility unless the owner explicitly asks.

## 4. Product intent and definition of success

CyberSand is intended to become a reusable, high-performance pixel-material simulation engine rather than a one-off Godot scene. Its first visible proving ground is a 1024×1024 material laboratory with enough material variety and visual quality to construct pseudo-realistic medieval villages and castles, and cyberpunk chemical factories and alleyways.

The owner values, in roughly this order:

- stable interactive frame pacing and a convincing illusion at runtime;
- rich, meaningful cross-material behavior;
- a reusable engine architecture that can later support other projects;
- visual flair that exploits available GPU headroom without increasing CPU↔GPU traffic unnecessarily;
- observable, bounded degradation under load instead of catastrophic stalls;
- strict replay and validation modes for engineering confidence;
- reversible checkpoints and clear provenance.

The owner is acting primarily as product architect and evaluator; Codex is expected to implement, test, document, and surface trade-offs. Do not require the owner to rediscover low-level build knowledge, but pause for genuinely material product, ownership, licensing, authentication, or destructive decisions.

## 5. Architectural invariants — do not regress

### 5.1 Native simulation owns simulation truth

**Current.** The native C++ simulation is authoritative. Godot owns presentation, input, UI, and adapters. Worker threads must not call Godot APIs or manipulate scene-tree objects.

The simulation advances on fixed ticks. Rendering and simulation are independently paced; render delta must not become simulation time. Worker completion does not transfer ownership casually: data crossing threads must have an explicit immutable lifetime or an explicit ownership handoff.

### 5.2 Keep the reusable core independent

**Approved.** CyberSand/Cybervox core contracts should remain engine-owned. Rapier is the sole current rigid-body backend, but Rapier types and assumptions must not leak into the public simulation contract. Keep Godot/GDExtension, physics backends, and game-specific presentation behind adapters.

Avoid fixed scene-tree paths, game-specific material rules in generic schedulers, fixed world sizes in public contracts, and public APIs expressed in raw Rapier or Godot types.

### 5.3 Data-oriented, local, bounded work

**Current.** The native path uses sparse 128×128 chunks, 32×32 activity blocks, four parity phases, persistent worker threads, and dirty RG8 render data. Hot buffers are bounded and reused; capacity and high-water behavior should be explicit and observable.

Prefer descriptors, compact state, kernels, spatial locality, and active-only work. Avoid allocations in the world tick and avoid work proportional to the whole world when activity is sparse.

### 5.4 Designs already rejected

Do not reintroduce these without a new evidence-backed ADR:

- per-cell locks;
- one thread or class hierarchy per material;
- full-world double buffering as the normal update model;
- rendering from mutable simulation storage;
- hidden tick-time allocation;
- an unbounded scheduler with mixed ownership;
- tying simulation progress to render cadence;
- GPU authority over local terrain/material occupancy in the current architecture;
- broad local 2×2 voxel coarsening that breaks full-resolution topology.

## 6. Determinism and approximation: the crucial nuance

The owner does **not** require perfect runtime determinism. A stable, plausible illusion at 60 FPS is more valuable than calculating every possible interaction on every fixed tick. It is acceptable to miss or defer a bounded percentage of secondary interactions.

At the same time, strict validation and replay must remain exact. Never use thread timing as a hidden random input. Approximation should be explicit, reversible, and derived from stable coordinate/material/tick hashes where randomness is needed.

Use fidelity tiers:

- local/high-interest occupancy and collision: full resolution and high cadence;
- active material interactions: interest-weighted cadence and bounded budgets;
- slow secondary fields: coarser or lower-frequency updates;
- distant areas: sleep, defer, or use conserved aggregates;
- strict validation: exact schedule with approximations disabled.

Good candidates for probabilistic or time-sliced processing include slow ignition and growth, corrosion, freezing, decomposition, distant gases, pressure, visual spray/debris, and sampling equivalent contact pairs.

Do not approximate away:

- local solid occupancy and collision;
- closed-boundary conservation guarantees;
- ownership, synchronization, or capacity checks;
- accepted explosion or mutation commands;
- barriers in a way that permits penetration;
- material by deleting it silently when it should be conserved.

An approved direction is to extend the slower cadence already used for fire interactions to most pixel↔hard-body and inter-material interactions, and to distribute a logical tick's secondary work across multiple bounded processing passes. This is a performance direction, not permission to weaken safety validation or thread ownership.

## 7. Current simulation and rendering shape

The preferred runtime owner is `CyberSimulationWorker`, which drives an asynchronous fixed-rate simulation and prefers `CyberNativeCellWorld`; a GDScript fallback remains important and is covered by regression checks.

The 1024² lab uses dirty RG8 CPU image patches, but `ImageTexture.update()` still uploads the full 2,097,152-byte texture. Therefore the remaining render bridge bottleneck is not necessarily patch construction—it is the lack of a true GPU subregion update. When profiling, distinguish native step time, patch generation/copy time, and the eventual texture upload.

The earlier 65 ms Godot “process time” spikes were not evidence of GPU saturation. GPU utilization was negligible, while the main process was consuming CPU. Large tick age, active cell/block count, scheduler work, and texture/bridge activity must be correlated before blaming pixel fill count. A dense, mostly non-interacting world ran for an extended period; interaction mix and bridge lifetime were more diagnostic than fill alone.

Historical hosted dense-512 benchmark evidence, useful only as a comparison point:

| Workers | Step time | Replay result |
|---:|---:|---|
| 1 | 12.87 ms | Identical hash |
| 4 | 5.05 ms | Identical hash |
| 8 | 3.74 ms | Identical hash |

The world tick reported zero allocations in that benchmark. Re-measure on the current machine before using these as targets.

## 8. Render-patch race: a non-negotiable regression guard

M11 includes a critical fix for intermittent Godot signal-11 crashes. The observed signature was:

```text
apply_render_patches_to_image(): Expected Image data size of 85x128x2
(RedGreen without mipmaps) = 21760 bytes, got 0 bytes instead.
```

The GDScript stack passed through `apply_render_patches_to_image`, `upload_texture_patches`, `consume_worker_snapshot`, and `_process`. The crash could occur after minutes or during heavy material spam; high fill count alone did not reproduce it reliably.

The required invariant is:

- render patches are backed by immutable snapshot-owned payloads;
- payload dimensions, format, expected byte count, and actual byte count are validated before constructing an `Image` or blitting;
- zero-length, malformed, stale, or full-refresh-rejected payloads are discarded safely;
- acknowledgement occurs only after successful consumption;
- no producer may clear, resize, recycle, or mutate a payload still observable by the consumer.

Do not “optimise” this by reusing a buffer whose lifetime is not provably exclusive. Keep focused regression tests for malformed/zero-byte payloads, delayed consumers, full refreshes, and repeated publish/consume cycles.

## 9. Water and other behavior that should not be accidentally polished away

Water's fast fronts, airborne spray, and capillary-like slope film are intentional features liked by the owner. Do not remove them simply because they look less viscous or more energetic than a conventional falling-sand implementation.

Current Water behavior uses write-once destinations, a bottom-up vacancy rule with alternating rows, flow direction, up to 24 cells of contiguous lateral flow, and up to 256 cells of edge lookahead. Earlier short lateral budgets caused unrealistic piles. Viscosity, resting yield, and adhesion should remain separate concepts.

The `C` comparison mode represents calm/coherent Water. The `T` comparison disables the unsupported lateral bridge/film behavior. If these controls change, update both on-screen help and material-lab documentation.

Smoke requirements from the design conversation:

- Smoke should not burn or host Fire.
- Excessive Smoke should be culled with a slow, foam-like collapsing-bubble/dissipation effect.
- Dissipation should take much longer than Foam's collapse, preserving the impression of lingering volume.
- The culling mechanism should be bounded and should not turn the entire smoke field into a per-tick CPU scan.

Foam's collapsing-bubble effect is a positive visual reference and should be retained.

Fire and slow interactions should use scheduled/budgeted cadence where possible. M11 also corrected a Fire chunk-count issue (256 expected chunks in the relevant path) and corrected fallback Water behavior; keep these covered.

## 10. Material and visual direction recovered from conversation

The material library should support both natural/medieval construction and industrial/cyberpunk scenes. Static solids deserve particular depth: multiple stone, brick, mortar, plaster, timber, roofing, earth, masonry, concrete, manufactured panel, pipe, glass, corroded metal, painted metal, hazard-marked, chemical-stained, and emissive industrial variants should read distinctly at pixel scale.

The desired visual strategy is predominantly GPU-side:

- palette/LUT-driven surface variation;
- condition-byte effects such as wetness, heat, corrosion, charring, contamination, and emission;
- slightly stronger contrast in textures and LUTs than the earlier baseline;
- GPU-derived highlights, gradients, edge treatment, shimmer, glow, and temporal motion;
- minimal new CPU work and minimal additional RAM↔GPU communication.

Specific preferences:

- remove sparkle from rough/raw metals;
- use restrained sparkle or glints on smooth, polished, coated, or manufactured materials;
- preserve Oil's wave pattern—the owner specifically liked it;
- if performant, translate or animate that pattern entirely in the shader and develop related, material-specific motion for most liquids;
- do not give every liquid the identical effect: vary speed, scale, directionality, distortion, viscosity cues, and highlight response;
- use GPU time and existing material/condition data before adding per-cell CPU state solely for appearance;
- avoid visual techniques that require frequent new texture uploads or CPU-generated animation frames.

The important separation is: simulation material state remains CPU-authoritative, while presentation may derive rich transient detail from stable IDs, coordinates, condition bytes, time, and neighboring texture samples.

Useful thematic interaction families include Smoke, Fire, Foam, Water, Oil, Lava, Acid, Metal, Spark, Molten Glass, Brine, and Steam. New materials should create meaningful pairings across families rather than merely adding palette swaps. Inspiration from Sandspiel, Noita, and AuraLite is welcome, but adaptations must fit CyberSand's bounded data-oriented architecture; do not copy a GDScript “species object per material” design.

## 11. Rigid bodies and pixel contact

Rigid bodies use a separate occupancy mask and a packed immutable bridge into the simulation, with bounded sweep and reconciliation. Keep that separation: a body is not just another mutable cell species.

Known behavioral concerns include barrels or similar bodies feeling too bouncy, vibrating on hard surfaces, and occasionally crossing one-pixel floors. Planned improvements may include more general shapes and selective CCD/swept contact, but they must remain behind the engine-owned adapter contract.

Do not solve penetration by making all interactions globally expensive. First preserve exact local collision topology; then use targeted continuous/swept checks, stable resting thresholds, contact damping, bounded reconciliation, and interest-aware cadence for secondary material/body chemistry.

## 12. UX and material-lab expectations

The lab is the project's behavioral and presentation proving ground, not disposable demo code. Preserve resize/aspect/mouse-coordinate alignment.

Expected controls at the handover baseline include:

| Control | Purpose |
|---|---|
| Mouse | Emit or erase material |
| `1`–`6` | Quick material slots: Sand, Water, Wall, Smoke, Paste, Slush |
| `Q` / `E` or Page Up / Page Down | Cycle materials; `Q`/`E` supports tenkeyless keyboards |
| `V` | Logical/debug views |
| `B` | Simulation margin display/control |
| `L` | Windowed interest versus whole-world simulation |
| `C` | Calm/coherent Water comparison |
| `T` | Unsupported lateral film/bridge comparison |
| `K` | Temporal render/display snapshot cadence or smoothing; do not document it as a simulation-accuracy switch unless implementation changes |
| `H` | Publication/render rate comparison (30/45/60 while simulation remains 60 Hz) |
| `G` | Glow |
| `F3` | Toggle debug statistics readout |
| `P` / `R` | Pause / reset |

The output target was increased to 1920×1080. Verify project settings, presentation checks, aspect behavior, and input mapping together when touching window or viewport code.

Materials were deliberately prioritised before world streaming. Streaming, world serialization, and broad world-scale systems are deferred until the material/interaction foundation is compelling and stable.

## 13. Profiling and observability expectations

Retain or improve metrics for:

- tick age and step time;
- planning, tile/kernel, merge, commit, and snapshot phases;
- active/scanned cells, chunks, and blocks;
- worker count, jobs, phases, and scheduler caps;
- allocations and capacity high-water marks;
- dirty patch count and bytes;
- bridge time, upload time, and rejected payload count;
- rigid-body contacts, displacement, and unresolved contacts;
- replay hash and strict-mode identity;
- overruns and accumulated backlog.

Interpret the profiler causally. A full scene may be cheap if interactions settle; fewer pixels can be expensive if many materials continuously react, wake neighbors, generate body contacts, or invalidate render regions. CPU process spikes plus negligible GPU use generally suggest simulation/scheduling/bridge work, main-thread waits, or buffer handling—not shader cost.

Every new approximation or budget must expose enough telemetry to show when it activates and what it drops or defers.

## 14. Validation contract

Before claiming completion, run the feasible narrow tests first and the documented complete suite when the task warrants it. Use explicit per-command and overall timeouts; a silent or hung Godot process must not be allowed to run indefinitely.

The M11 suite historically covered:

- native unit and integration tests;
- ASan/UBSan and TSan paths;
- compile-only native checks;
- render-bridge regressions;
- material/LUT and material-flair regressions;
- 1920×1080 presentation checks;
- full-scene shader smoke tests;
- Godot headless startup/shutdown;
- Rapier preflight;
- global GDScript class and extension registration;
- archive, manifest, and restore tooling.

For any failure or inconclusive result, record the exact command, timeout, environment, scene/input/configuration, stdout/stderr, log path, exit status, and reproduction result. Continue independent tests when safe. Never edit tests or runtime code merely to hide an audit failure.

Environment limitations must remain explicit:

- the hosted M11 audit could not conclude LeakSanitizer because of `/proc` restrictions;
- Windows DLL format/import checks are not Windows runtime validation;
- headless shader checks are not interactive visual approval;
- migration-era workflow presence is not proof that current GitHub Actions passed;
- a local checkout is not proof of clean-clone reproducibility unless a clean reconstruction was actually tested.

Replay is the engineering oracle. Runtime may use bounded approximations, but strict mode should keep hashes stable across supported worker counts and schedules.

## 15. Change protocol for Codex

For each substantial change:

1. State the observed problem and its evidence.
2. Identify which architectural boundary owns the fix.
3. State the invariant that must remain true.
4. Separate current behavior from proposed behavior.
5. Prefer the smallest reversible implementation.
6. Add or update focused regression coverage.
7. Run bounded validation with timeouts and report limitations.
8. Update the relevant RAG page and ADR/status claim.
9. Review `git diff`, generated files, LFS pointers, and secrets before committing.
10. Commit with a focused message; push only within the owner's requested scope.

Do not perform destructive cleanup, rewrite validated implementation for aesthetics, silently update dependencies, or regenerate large assets unless the task requires it. Never commit credentials, tokens, cookies, crash dumps, machine paths, disposable caches, or private user data.

If a process appears stalled, stop starting new tests. Inspect process state, completed commands, working-tree changes, and retained artifacts; report before terminating or rerunning broad suites.

## 16. Repository, dependencies, and distribution

The private Git repository should contain source, assets, tests, documentation, scripts, configuration, dependency locks/pins, build metadata, licences/attribution, and reproducibility records. Generated caches, local build directories, editor imports, crash dumps, temporary audits, logs, credentials, and machine-specific state should stay excluded.

Large runtime binaries belong in Git LFS only where repository policy already tracks them. Installers, export templates, and third-party archives should be embedded only when redistribution is permitted; otherwise preserve version, origin URL, licence status, SHA-256, and restore instructions.

The eventual public project licence has not been selected. That does not block private development, but it is a required owner decision before public release or third-party distribution. Preserve all third-party notices regardless.

Do not silently float dependency versions. Changes to Godot, `godot-cpp`, Rapier, compiler ABI floors, or extension APIs require an explicit compatibility update, clean rebuild evidence, manifest updates, and relevant platform validation.

## 17. Documentation maintenance

Preserve the existing RAG-oriented hierarchy, including `docs/decisions`. Do not replace it with a generic wiki or a single giant README.

When implementation changes, audit all affected **Current**, **Approved**, **Planned**, **Deferred**, and **Rejected** claims. Contradictory status labels are defects. Keep exact identifiers and search anchors near the concepts they describe: simulation ownership, render bridge, Water flow, approximation tiers, Rapier adapter, dependency pins, validation status, archive compatibility, and known limitations.

This handover itself should live in the repository at a stable operations/onboarding path such as:

```text
docs/operations/codex-development-handover.md
```

Add it to the documentation index and `AGENTS.md` reading order, but retain this document's role as a bridge to—not a replacement for—the more focused RAG pages.

## 18. Autonomous decisions versus owner decisions

Codex may normally proceed with focused implementation, tests, documentation, non-destructive diagnostics, and commits on the requested task branch.

Pause for the owner when work requires:

- changing repository visibility or ownership;
- selecting a public licence or redistribution policy;
- destructive history or workspace operations;
- publishing a release or contacting external parties;
- authentication or new credentials;
- a product choice that materially changes the simulation's feel;
- removing a liked behavior such as Water spray/film, Foam collapse, or Oil waves;
- choosing between conflicting M11 sources or audit identities;
- broad dependency upgrades or an architectural reversal.

When uncertain, present concrete evidence and the smallest set of mutually exclusive choices.

## 19. Near-term opportunities and deferred work

These are directions, not claims of completed implementation:

- true GPU subregion texture uploads to eliminate full-texture RG8 updates;
- shader-only liquid motion and material-specific highlights;
- richer GPU-derived condition effects and static-solid palettes;
- broader budgeted inter-material and pixel↔body passes;
- bounded slow Smoke collapse/dissipation without Fire hosting;
- rigid-body resting stability and targeted one-pixel-floor CCD;
- conserved distant aggregates after local material behavior is mature;
- world streaming and serialization later.

GPU authority for terrain/material simulation, GPU wind/pressure authority, and broad spatial coarsening remain deferred. GPU-derived visual wind, heat haze, lighting, distant gas appearance, spray, and debris are much safer experimentation areas.

## 20. Common traps

- **Starting from an archive because it is convenient:** only the GitHub M11-derived repository is authoritative now.
- **Calling runtime approximation nondeterministic and therefore untestable:** keep strict replay exact; make runtime sampling stable and explicit.
- **Treating a Godot process-time spike as GPU cost:** inspect simulation, bridge, upload, waits, and backlog independently.
- **Reusing patch buffers too aggressively:** immutable payload lifetime is a crash-safety invariant.
- **Making all materials run all reactions every tick:** use bounded cadence and passes for secondary effects.
- **Optimising Water into a generic liquid:** preserve the liked fast/spray/film behavior and tune other liquids separately.
- **Using headless success as visual approval:** shaders can compile while the result still looks wrong.
- **Equating PE/import inspection with Windows runtime validation:** record the platform gap.
- **Adding visual state on the CPU when a shader can derive it:** exploit GPU headroom and avoid new upload channels.
- **Cleaning a dirty worktree automatically:** user work is not disposable.

## 21. Starter prompt for a new Codex task

Use or adapt this prompt after opening the private repository:

> Work from the current private CyberSand repository only. Read `AGENTS.md`, the documentation index, `docs/operations/codex-development-handover.md`, the relevant RAG pages, and applicable ADRs before editing. Confirm the checkout descends from audited M11, report HEAD/tag/status/LFS state, and preserve unrelated changes. Treat native C++ as simulation authority, Godot as presentation/adapter code, Rapier as a replaceable backend, and immutable render-patch payload lifetime as a crash-safety invariant. Runtime may use explicit bounded approximation, while strict validation/replay remains exact. Implement the requested change narrowly, update focused tests and documentation status claims, run commands with timeouts, and report every untested platform or visual gap without implying it passed.

## 22. Final handover checklist

- [ ] Current checkout and remote are verified rather than assumed.
- [ ] Audited M11 ancestry and dependency pins match.
- [ ] LFS objects are materialised, not pointer text.
- [ ] Relevant RAG pages and ADRs were read.
- [ ] Current/Approved/Planned/Deferred/Rejected are not conflated.
- [ ] Native/Godot/Rapier ownership boundaries are preserved.
- [ ] Render-patch payload lifetime and validation are preserved.
- [ ] Runtime approximation remains explicit, bounded, reversible, and strict-mode compatible.
- [ ] Liked Water, Foam, Oil, and material-flair behavior is not accidentally removed.
- [ ] New visual work prefers GPU derivation over CPU state and uploads.
- [ ] Tests use timeouts and limitations are reported honestly.
- [ ] Docs, provenance, licences, hashes, and dependency pins remain current.
- [ ] No credentials, caches, logs, dumps, or machine-specific files are committed.

