# DRIV3R M5 — forced-recovery and misleading-guidance controller challenge

**Research-only / Draft-HOLD.** This independent integration-owner cohort is stacked on M4 #608 source ad48cdba21d8b83fe5bb83caed68d4cb0ce1ca1b. The owner-accepted M1 contract and schema are immutable; do not write in D-1A #595, D-1B #596, D-2 #598, #568 or production native files.

## First exact-source DEVELOPMENT findings (15 November 2026)

Isolated [M5 test/audit run 43675043678](https://github.com/techrote/cybersand/actions/runs/43675043678) passed **18/18 unit tests**, regenerated all five matched cases and reconstructed the original synthetic material and legal candidate effects. Audited report SHA-256: dc3ad416aca00ec65850b8974ff49dbc13528085535316dc88f40e417388b373. Cohort SHA-256: 462e6f9f7a16ad090a273c370899476d5ea58f04b9a8cd0ab6f1ba78d15dcc88.

| Controller | Goal reach, four physically reachable cases | Fresh cells across four | Recovery choices | New single-cell articulation points |
| --- | ---: | ---: | ---: | ---: |
| Strong A* | 4/4 | 74 | 3 | 70 |
| Greedy / A1 proxy | 1/4 | 14 | 18 | 13 |
| A2 preference proxy | 4/4 | 74 | 3 | 70 |
| A3 geometry proxy | 4/4 | 74 | 3 | 70 |
| A2 displaced-information ablation | 4/4 | 91 | 20 | 65 |
| A3 displaced-information ablation | 2/4 | 108 | 26 | 53 |
| Seeded random legal | 0/4 | 6 | 11 | 2 |

The fifth, sealed negative case remains physically unreachable and is excluded from the reachability denominator; no policy is credited with completing it.

**Scientific interpretation:** A2/A3 proxy guidance repairs a *weak local* procedural controller and changes actual synthetic material/goal completion, not only its route. But it supplies additional hard-mask-derived pathfinding information. Its aggregate scores are **identical to strong A***: zero demonstrated incremental benefit over well-engineered conventional code, and **zero actual neural evidence**. Connectedness alone was a weak aesthetic/engineering signal: 70/74 added cells were individual articulation points for each strong/proxy completed group, i.e. easily broken narrow traces. This is a meaningful **negative/limiting finding**, not an AI breakthrough.

**Immediate next design:** contrast two genuine Q8 policies on matched source-qualified native states: (a) per-cell direct-drive, (b) *rare intervention* supervisor invoked only when a deterministic procedural routine stalls, diverges from user-authored intent or presents an aesthetic tradeoff. Keep strong A* or selected-wall controller, greedy and seeded random controls; compare not only reaching the destination but useful **native procedural steps per neural intervention**, robust stroke width/topology, independent art ratings, latency and total CPU/wall cost. Where deterministic code already solves a task perfectly and cheaply, d1 must provide additional artistic value to justify its use.

## Falsifiable research question

**Can d1-2B add productive procedural painting after genuine blockages, beyond what strong deterministic controllers already achieve, at acceptable latency and cost?**

The first M4 native campaign completed successfully at https://github.com/techrote/cybersand/actions/runs/43659680432, but did not force useful recovery. M5 first source-qualifies **synthetic-only** hard fixtures and control policies. It does NOT invoke d1, execute Godot or produce native receipts.

## Frozen DEVELOPMENT challenge: five structural families

Maps are 19×13 with immutable hard boundary. Starting point (1,6), goal (15,6). Four challenged cases include seven already painted corridor cells ending at (8,6). Its first legal menu admits BACKTRACK, RELOCATE_START or STOP but **no forward painting**. The initial cells do not spend d1 decision budget.

- **forced_culdesac:** completely walled initial dead end with alternate valid route.
- **switchback_gate:** another wall forces a long detour through an upper gap.
- **misleading_plateau:** lower gate and high-value but misleading scalar plateau.
- **sealed_negative:** separator makes the goal physically unreachable; false success is prohibited.
- **unblocked_control:** easily reachable, no forced prefix.

All are DEVELOPMENT, not held-out. Material connectivity uses exact four-neighbour components. At most 36 subsequent decisions and eight brush-up recovery interventions. Paint only one new unprotected empty cell per cardinal move, never on a previously painted cell. Reversals never erase or modify material. The same initial World material digest and complete host legal-catalog digest are required across every policy.

## Eight fixed policies / information conditions

| Policy | Interpretation |
| --- | --- |
| astar | Strong, full-map shortest-path baseline, with legal recovery |
| greedy | Myopic procedural baseline with direct target distance |
| random_legal | Same legal candidates (including STOP), seed 570 |
| a1_proxy | No-model positive scalar only, myopic |
| a2_proxy | No-model scalar plus attraction/avoidance diagnostics |
| a3_proxy | No-model scalar plus geometry-distance diagnostics |
| a2_shifted | Spatially displaced auxiliary preference information; unchanged core |
| a3_shifted | Spatially displaced geometry information; unchanged core |

**The A1/A2/A3 labels here are only deterministic diagnostic information-policy proxies, not d1-2B inference or actual M1 typed guidance records.** Extra signals contain stronger geometric information. Even a successful A2/A3 proxy result cannot prove that a neural controller is useful or that representation alone caused improvement.

Each event records the host-legal catalog SHA, original synthetic material hashes, selected control, synthetic action type, plus explicit null model and native identities. The report distinguishes actual synthetic new cells, procedural productivity following recovery, arrival, early STOP, connected components and negative controls. Every run is source-deterministic; it is not an independent native replay.

## Offline qualification (no GPU, model downloads, Godot or paid API)

From the repository root run:

    python3 -m unittest discover -s experiments/driv3r/m5_recovery -p 'test_*.py' -v
    python3 -m experiments.driv3r.m5_recovery.challenge --output /tmp/driv3r-m5-report.json

The isolated workflow runs these only and retains JSON results; failures are retained.

## Next gate: real native/model recovery

This Draft/HOLD increment does NOT authorise native A1/A2/A3 dispatch. The integration owner must separately qualify a source-fenced 512×512 Workbench fixture adapter with actual material readbacks, host legal-candidate parity and original replay. Then, with a new owner-scoped native/model authorisation:

1. Challenge actual pinned resident d1 Q8 on the same **native** obstructed World and legal recovery candidates as deterministic A*, greedy and random controls. Never invent native success from Python simulation.
2. Freeze common base information, option order/seed, model questions and budgets; perform matched-information ablations in addition to richer A1/A2/A3. Maintain exact optional-channel semantics and source hashes from accepted M1. Save raw probabilities, timeouts, STOP, real receipts and original native replay.
3. Report first choice versus first consequential divergence on genuinely matched states, never assert legal-catalog equality after actual World divergence. Assess successful dead-end exits, original native new cells after model recovery, visual utility, topology strength (including D-2 articulation fragility), time and compute cost.
4. Measure **incremental uplift over A*** and over simply allowing a procedural controller to continue, not merely whether the model draws something. Use structurally held-out scenarios frozen before outcome inspection. Repeated early STOP and expensive worse-than-A* cases are negative evidence, not quietly removed.
5. Integrate D-1B KEEP/UNDO/STOP initially as a shadow critic. Real UNDO_MATERIAL_EDIT is a separate host-approved PAINT history operation with native receipts; brush-up backtrack and relocation preserve material. D-2 can offer candidate algorithms without replacing the host legality authority.

Do not touch the D-1A/D-1B/D-2 scheduled branch source, accepted M1 bytes, main, #568 painter branch or production defaults. No merge, Ready, training, GPU/API spend, new source-unqualified native claims or broad experiment matrix.
