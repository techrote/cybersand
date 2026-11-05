# SOL active-normal mixed-face response envelope: bounded value-only experiment

Date: 5 November 2026 (UTC). Status: **EXPERIMENTAL / NO PRODUCTION ADMISSION**.
Refs: #429 (active-normal owner), #411 (original compound chamber), #400 (LA-Selective), #364 (persistent Sand penetration), #281 (structural authority). This is a distinct test-only branch at the frozen #429 candidate; it neither changes #429 nor edits any live solver/application/material code. Original physical support/entrapment can be valid.

## Exact source custody

- Accepted main at intake: `ba9cbc89029be88b812af59b19e5c59829bbcd90`.
- Frozen #429 experiment: `275ce1ee692739b35f400adcf9532f7e89284cfb`.
- Original unchanged live solver header blob: `c9af2c0aac1efb1ac271897d2c29120c8c81566c` (also verified by `git hash-object` locally).
- Executed and committed experiment blob: `c1b1f93ec96457afc7dd60ce07d61edc2fc53bb5`; 7,832 bytes.
- New experiment file: `tools/experiments/sol_conservative_face_envelope.cpp`. No source solver, Godot, World, Rapier or native material branch modified.

### Controlled experiment

The same 252,720 deterministic finite copied-value cases as the earlier #429 mixed-face counterexample are independently scored with both `Original` and `ActiveNormal001`. Every active bin is assembled by actual `Bin::add` on square-rectangle faces. Body: mass 10, inertia 20, center of mass (0,0); grid of 9 horizontal speeds × 9 vertical speeds × 5 angular speeds × 3 frictions × 13 face masks × 4 lower-face sample counts × 4 upper-face counts. Budgets remain 20/1/20, and each policy has its **own** `CompoundWorkspace`.

For each individual bin, evaluate post-response centroid velocity `v + ω×(centroid - COM)`, then the inward-normal **positive closing speed** `max(0,-dot(local_velocity,inward_normal))`. Do not mistake this centroid diagnostic for polygon-to-Sand penetration, exact quadrature coverage, material displacement or an applied Rapier trajectory.

Experimental *selection envelope* (test only): compute **both** original and active responses; choose active **only if** at least one populated face improves its closing speed by more than 1e-8 **and no populated face worsens it by more than 1e-8**. Otherwise choose original. This is an expensive two-solve construction, not a production proposal. It is not automatically admissible as a physics fix: it cannot certify cell-space displacement, change of contact membership in the next step, angular momentum of material, active native authority or total system passivity.

### Executed Linux results

GCC 14.2 and Clang 17, C++20 `-O2 -Wall -Wextra -Werror`, 252,720 cases per compiler, source identical; GCC and Clang ASan+UBSan `-O1` execute the same complete domain (LeakSanitizer disabled).

| Finite copied-value diagnostic | Original | Active-normal | Per-face envelope |
|---|---:|---:|---:|
| Aggregate face-centroid closing speed | 363930.90070469544 | 362756.38756134221 | **362134.60881975159** |
| Improves total closing relative to Original (cases) | baseline | 53,802 | 47,470 |
| Worsens total closing (cases) | 0 by definition | 22,096 | 0 |
| Worsens **any** individual face (cases) | 0 by definition | 28,428 | **0** (1e-8 tolerance) |
| Uses ActiveNormal001 (cases) | 0 | 252,720 | 47,470 |
| Solver/passivity refusal or invariant failure (cases) | 0 | 0 | 0 |

The registered three-face witness remains 0.097343073994358431 Original vs 0.28209333091985 Active, despite lower Active rigid-body kinetic energy (68.805431695166178 → 60.839704370783245). The envelope selects Original and does not introduce that worsening in this one step.

The aggregate closing reduction of the envelope relative to Original is **1,796.29188494** (about **0.494%** over this constructed grid), not a measured game improvement. The maximum positive selected-face closing difference is 9.7393504827905335e-17 (floating roundoff). The test demonstrates *feasibility of a value-only postselection bound*, but because 47,470 cases retain a benefit only at the cost of **two complete solver calls**, it is not evidence for a deployable single-pass policy.

Linux sample wall times for the *whole grid including both solver calls, bin creation and classification*, not response-engine benchmarks: GCC 619.9 ms, Clang 674.5 ms; GCC sanitizer 2596.8 ms, Clang sanitizer 1095.4 ms. They cannot be compared to frame budget and do not isolate incremental cost.

### Qualification and remaining gates

- **PASS:** exact local solver/reproducer blobs; Linux GCC/Clang optimized and ASan+UBSan; original two-policy passivity and finite-result checks; 252,720 individual-face selections per compiler.
- **PENDING:** attached branch-specific hosted Windows/MSVC and hosted Linux run. Do not report Windows success before examining actual logs.
- **NOT EXECUTED:** World/Rapier #411 520-member chamber, mixed authored-body incident replication, native ownership transitions, material-ID/amount conservation, Windows Godot/Rapier or general CPU/24-group response budget.
- **Unchanged safety/architecture:** accepted main remains unchanged, production `NormalPolicy::Original` and LA-Selective/default semantics unchanged, #429 stays Draft, original SOL penetration and source composition remain NO-GO.

**Disposition:** Keep this experiment and its parent Draft/HOLD. The next physical step remains the already registered #429 contact-node/batch capture at the first *actual* mixed-body divergence, checking whether centroid-local closing deterioration corresponds to the observed rigid-body/terrain penetration regression. Only after that can a bounded one-pass response candidate be justified. Do not integrate this two-solve oracle merely because it scores better on a synthetic scalar.
