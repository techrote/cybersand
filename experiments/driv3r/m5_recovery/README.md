# DRIV3R M5 — forced-recovery and misleading-guidance controller challenge

**Research-only / Draft-HOLD.** This independent integration-owner cohort is stacked on M4 #608 source ad48cdba21d8b83fe5bb83caed68d4cb0ce1ca1b. The owner-accepted M1 contract and schema are immutable; do not write in D-1A #595, D-1B #596, D-2 #598, #568 or production native files.

## Owner-corrected aim — a slightly deranged line-steering worm brain

The hypothesis is **not** that d1-2B outperforms A*, invents general-purpose pathfinding, or becomes an intelligent art-production supervisor. It is much simpler and more playful:

> Give a little decision brain a pen/brush worm. Let it steer, hesitate, turn, follow things, get distracted, escape corners and occasionally make wonderfully odd lines inside CyberSand.

The host supplies safe, bounded brush/movement choices and executes them; the brain chooses direction and sometimes brush-up recovery. The desired behaviour is *alive-looking, recognisable yet slightly unpredictable line-making*, rather than straight optimal routes. Deterministic controllers are useful references and guardrails, not competitors the worm must defeat. A crooked route, loop, unexpected turn or failed attempt may be interesting output rather than an error, provided material permissions and stop limits are respected.

Success should be evaluated by **watchable evolving strokes**, ability to respond to obstacles and soft steering, controlled variation across seeds/prompts, replayable behaviour, and whether outputs are interesting or useful as weird procedural mark-making. Do not silently optimise away the derangement, force every trial toward a fixed goal, or grade art primarily on A* efficiency, connected components, articulation-point counts or number of completed routes.

M5's existing forced-goal mini-grid and A1/A2/A3 proxy experiments remain **technical plumbing checks**, useful for verifying legal choices, recovery, feedback and simulation provenance. They are not the central hypothesis test. The next genuine experiment is real d1-2B steering a wandering line in native Workbench, with multiple short visual trajectories and a few soft guidance variations.

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

**Engineering interpretation (not the art hypothesis):** The A2/A3 proxy diagnostics allowed a goal-seeking pathfinder to escape certain artificial traps, but the extra hard-mask-derived geometry information was sufficient to explain the result. These synthetic proxy runs contained no d1 inference. Likewise, 70/74 new cells being articulation points describes one-cell line geometry; **that is not automatically a defect for a line-drawing worm**. The figures check the harness and show sensitivity to information, but do not judge the interestingness of worm strokes.

**Immediate next design:** use pinned d1 Q8 to steer a **continuous pen-worm**, choosing among short bounded direction/turn/brush-lift choices. Offer soft guides and obstacles, including corners and a dead end; let it recover or change its mind. Preserve every original line and failure. Show side-by-side material images/trajectories, with seeded random and simple wall-following as references. Score subjective line character and steerability alongside legal actions, progress/stall behaviour and latency. Keep the experiment small and amusing.

## Falsifiable research question

**Can a small d1-2B decision brain drive a CyberSand line-drawing worm that wanders, follows soft hints, gets confused, recovers and produces interesting, slightly deranged strokes?**

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

1. Run an actual pinned resident d1 Q8 as a **direct-drive worm brain** in the source-qualified native Workbench, with host-legal direction/turn/paint/brush-up choices and short bounded sessions. Include a wall, corner and dead end. Never invent native success from Python simulation.
2. Try the same worm with and without a soft drawn guidance field, and vary the seed or instruction to see whether it can be *steered without being on rails*. Keep legal candidate parity and exact M1 channel semantics. Save raw model answers, failures, Stop, actual PAINT receipts and original native replay.
3. Publish visible line traces and native-material images, with notes on turns, tangles, escapes, hesitation, revisits and line character. Preserve reproducibility and actual changed-cell accounting. Track runtime/cost only enough to know whether the experience is practical.
4. Keep A*, greedy and random results as technical controls where helpful, **not the target to beat**. An inefficient but intriguing stroke may be a good worm result. The aesthetic question is whether model choices make the line entertaining and steerable; repeated trivial loops, refusal to paint and total lack of user influence remain problems.
5. Explore D-1B's KEEP/UNDO/STOP only if it creates appealing hesitation or self-correction; don't turn it into an optimisation judge. Real UNDO_MATERIAL_EDIT remains a host-owned PAINT history action requiring receipts. D-2 can contribute procedural texture/shape tricks without replacing the worm's steering choices.

Do not touch the D-1A/D-1B/D-2 scheduled branch source, accepted M1 bytes, main, #568 painter branch or production defaults. No merge, Ready, training, GPU/API spend, new source-unqualified native claims or broad experiment matrix.
