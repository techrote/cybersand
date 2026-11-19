---
title: Waterwall stack review and remediation — 2026-11-18
status: Current
document-kind: audit
scope: Dated review findings, focused repairs and qualification status for PR 672 above unchanged PRs 661 and 631; no merge or default promotion
last-reviewed: 2026-11-19
related-documents: [../architecture/wave-flow-v1.md, ../architecture/ballistic-water-v1.md, ../operations/workbench-water-lab.md, ../reference/status-and-roadmap.md]
---

# Waterwall stack review and remediation

This is dated evidence, not an instruction to merge or promote the experiment.
The owner authorized posting the review and carrying out the fixes. The
[posted review](https://github.com/techrote/cybersand/pull/672#pullrequestreview-5966969922)
contains five reproduced P2 findings. Repairs are confined to the combined
#672 candidate; parent #661 and #631 branches remain unchanged. Merge stays
**HOLD**, with Wave and spill opt-in and their defaults unchanged.
Wave is the primary solver under evaluation; PressureFlow coverage here is
fallback compatibility, not a new optimization or selection priority.

## Reviewed source identity

| Source | Reviewed identity |
|---|---|
| #672, `claude/wave-waterwall-001` | `efbf8c846cffd6f2042918cb38c3da0f6aa9c047` |
| #672 source tree | `6093288db8f6f706d8d3e19e16f496cfedab4c88` |
| #661, `experiment/waterlab-631-consolidated-ui` | `f61937ec0f554f77275c5d0316e9b95e5a6c9457` |
| #631, `astra/wave-mt-001-669-finisher` | `edf42998ab5cb55a3ce916ead270c9b696033ab0` |
| Accepted main | `018bd09503d7f079ddac52e225c2f7daf8d678bf` |
| Local remediation branch | `fix/waterwall-review-20261118`, based on the #672 head above |

The retained implementation is
[`f952717b1ca6432d3e17c5340b31b1df1822a1b5`](https://github.com/techrote/cybersand/commit/f952717b1ca6432d3e17c5340b31b1df1822a1b5),
tree `b2ea42275cd137f0a57a35168407786ad0143b6c`. Publication request 15
follows it with documentation/request changes; the tested native and Godot
sources are unchanged. Published Linux/Windows runtime identities and resulting-
head CI are pending at this source-freeze checkpoint. Their completed results
belong in the [PR #672 ledger](https://github.com/techrote/cybersand/pull/672).
Earlier green runs qualify only their recorded source.

## Findings and repair contracts

| Finding | Reproduction on the reviewed source | Required repair and regression |
|---|---|---|
| Diagonal ballistic entry into wet Water bypasses corner walls | Four cardinal walls surround `(11,11)`, which holds 100 units. A 100-unit parcel injected diagonally from `(10,10)` raises the enclosed cell to 200 units in one tick; the dry control stays dry. Reproduced with spill off/on and 1/4 workers. The prior diagonal test ignored refused injections and never established live parcels. | `world_ballistic.inc` must apply the corner barrier to both free and wet destinations. The regression must require successful injections, observe actual flight, cover wet/dry destinations and preserve total quantity. |
| Water Lab Apply misses focused numeric text | Type 80 over a field's 32, then click Apply: native readback remains 32. Explicitly applying the field produces 80. The field belongs to the child Window while `_commit_field` queried the parent viewport. | Action helpers pass their own viewport to `SharedWorkbench._commit_field`; commit the focused SpinBox text before collecting the request. Exercise typed keyboard text and a button click with native readback, including moved controls. |
| Selecting Water's law restores an obsolete whole-liquid policy | Accept Brine's Inertial assignment while Wave is active, then select only Water FreeMass: Brine silently returns to the cached CellularYield assignment. | Native `liquid_policy_restore_assignment` restores only Water's remembered assignment and material block over the current policy. Current other-liquid assignments/material blocks and active shared-family values, including defaults, survive. Restore a remembered family block only when that family is dormant. GDScript does not parse the policy wire format. |
| Optional launch reaction bypasses Body push | Two otherwise identical native Wave+ballistic worlds, spill off, Body push 0 and droplet gain 0: Reaction 0 gives zero body impulse; Reaction 4 gives `(-2.00507, 2.231522)`. Both have 44 parcels and 306000 total Water units. | Scale the optional impact-spray launch reaction by Wave's Body push. Its existing launched-quantity share is applied exactly once. Compare reaction off/on at Body push 0/128/256, include a partial donor and non-Wave control, and verify unchanged Water quantity/state for the isolated force comparison. |
| Automatic spill overflows before ballistic coordinate admission | A fresh GCC 14.2 UBSan build with a 10×10 Water block at `x = 1 << 56`, floor and left wall exits on the first tick: signed overflow at `72057594037927946 * 256`. | Check both spawn-cell coordinates against the admitted ballistic domain before multiplication and the cell-centre offset. A refused launch keeps its Water with the grid owner and retains grid fallback. Exercise positive/negative extreme coordinates and ordinary in-domain launches under sanitizers. |

The final finding is an extreme native coordinate-boundary defect. It does not
establish the cause of the original underwater surface-crest crash. The existing
exception quarantine and first-error diagnostics remain relevant independently.

Independent follow-up reproduced the same overflow in legacy **Face release**
with Wave on and Waterwall spill off. A ten-cell column with two open side cells
launches one 255-unit parcel at ordinary coordinates, but positive/negative
`1 << 56` on either axis failed under UBSan before admission. Both paths now use
`BallisticWaterConfig::spawn_cell_center_q`. Waterwall spill counts refusal and
retains its next-tick fallback; Face release preserves its existing invalid-
request skip and ordinary grid simulation without changing its capacity-only
refusal counter. The regression covers both paths, twelve coordinate cases and
workers 1/4: **48 combinations**.

The first corner repair also redirected merges between connected Water cells,
which failed one of the four historical stream-draw-zero pins. The final guard
only blocks a wet destination when both axis neighbours are Solid, Body or
Outside. Connected Water retains its previous merge priority. All four pins
remain unchanged, and the sealed wet/dry regression passes. No numerical-law,
hash-layout or persistence version was changed.

## Qualification ledger

The following commands describe the distinct gates. A pending entry is not a
claimed run. Local execution uses Linux x86_64; the desktop dependency pin is
Godot `4.7.stable.official.5b4e0cb0f` and godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`. The local compiler is GCC 14.2
using the existing local toolchain-drift override, separate from the pinned CI
builds. The rebuilt local runtime SHA-256 is
`02f1257a3f99023da707d790bf871a99ecc7861a0c76e3895b8eb4ffe451ea7f`.
It was used only for testing, then the published binary was restored before
staging; no local binary or fabricated provenance is committed.

| Gate | Command or retained mechanism | Result at this checkpoint |
|---|---|---|
| Waterwall publisher guards | `python3 tools/ci/test_wave_waterwall_runtime_publication.py` | Pass: 6 tests on the repair working tree |
| Inherited Wave publisher guards | `python3 tools/ci/test_wave_mt_runtime_publication.py` | Pass: 17 tests on the repair working tree |
| Focused diagonal regression | UBSan `test_wave_spill --filter 'wet and dry corners'` | Fails on reviewed source; passes after repair, 32 mode/wetness/direction/worker combinations |
| Focused spawn boundary regression | UBSan `test_wave_spill --filter 'automatic spill bounds'` | Signed overflow reproduced before repair in both automatic paths; passes after repair, 48 path/coordinate/worker combinations |
| Native Wave and body boundaries | `make -B -j2 wave-flow-test wave-body-boundary-test` | Pass: Wave 31/31; boundaries 50 runs / 6,000 ticks, zero failures and exact worker checkpoint parity |
| Complete spill suite under UBSan | The standalone compiler command below, then the complete binary | Pass: 26/26; all twelve original Wave-law and four historical spill pins unchanged |
| Address/undefined behavior sanitizers | `make wave-flow-sanitize wave-spill-sanitize wave-body-boundary-sanitize` | Pending |
| ThreadSanitizer | `make wave-flow-thread-sanitize wave-spill-thread-sanitize wave-body-boundary-thread-sanitize` | Pending |
| Actual Workbench and native reaction | Source-matched Godot execution of `test_workbench_wave.gd` and `test_workbench_wave_spill.gd` | Pass: 1,244 Wave assertions and 618 spill checks; all required sections true, no failures or ERROR lines |
| Failure and canvas controls | `test_failed_world_status_survives.gd`, `test_workbench_failure_containment.gd`, `test_workbench_canvas.gd` | Pass: 215 / 77 / 196 checks; all exit 0, no ERROR lines |
| Documentation structure | `python3 tools/ci/check_docs.py` | Pass after materializing the pinned companion references; no errors or warnings |
| Repository/runtime provenance | `python3 tools/ci/check_repository.py` | Correctly requires source-matched publication for five changed native inputs in each platform manifest |
| Immutable M11 evidence | `python3 tools/ci/check_m11_consistency.py` | Pass: 18 historical records and 28 source hashes; no current runtime acceptance implied |
| Frozen retrieval evaluation | `python3 tools/docs/retrieval_eval.py --output /tmp/waterwall-review-retrieval.json` | Completed: 32 questions, hit@1 19/32, hit@5 30/32, MRR@5 0.7292; lexical routing only |
| Whitespace | `git diff --check` | Pass on the repair working tree |
| Linux and Windows publication | `.github/workflows/wave-waterwall-runtime-publication.yml` on the retained repair source | Pending |
| Independent follow-up source review | Separate reviewer of combined diff, then narrowed corner/shared coordinate helper | No remaining blocking finding; independently reproduced the additional Face-release overflow before repair |
| Full resulting-head CI | PR #672 checks and review ledger | Pending publication |

The Body push regression accounts for 104 of the spill checks. Against the
reviewed runtime it failed exactly the two intended assertions: push 0 did not
suppress reaction and push 128 did not halve it. Both now pass, with identical
Water/parcel state and exact quantity accounting across force-only comparisons.

Local native reproduction (the baseline run substitutes an immutable copy of
the reviewed native sources; the same regression source is compiled):

```bash
g++ -std=c++20 -O1 -g -pthread \
  -fsanitize=undefined -fno-sanitize-recover=undefined -Inative/include \
  native/src/world.cpp native/src/material_rules.cpp \
  native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
  native/src/render_snapshot.cpp native/src/c_api.cpp \
  native/tests/test_wave_spill.cpp -o /tmp/test_wave_spill_review
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 /tmp/test_wave_spill_review
```

Each local Godot case uses the official 4.7 executable with
`--headless --path godot --script res://tests/CASE.gd`, a 600-second process
timeout and the source-matched local runtime above. The five cases completed
naturally; their execution times were approximately 49, 10, 1, 6 and 51 seconds.
These are functional checks, not isolated performance measurements.

The Waterwall publisher now requires the `native_body_push_reaction` section in
the unique passing spill summary. Its unit test rejects both a missing section
and a false section. Existing admission, conservation, generic-ballistic,
Workbench and failure-containment sections remain mandatory. The native workflow
runs the complete Make targets; it does not pin the spill suite to its previous
24-case count. No execution or source-matching gate is bypassed.

The initially missing companion sources were `SOURCE-PROVENANCE.json`,
`docs/WEB_THREADING.md`, `tools/dev.py` (referenced twice),
`docs/LOCAL_DEVELOPMENT.md` and `validation/browser-results.json`, all outside
this source checkout. They were materialized from the CI-pinned companion
commit `6a58311982941b75f46e22109a0829e5acb83c7e`; no placeholder facts were added.
Repository provenance
correctly requires rebuilds for `cyber_demo_bridge.hpp`,
`water_spray_coupling.inc`, `ballistic_water.hpp`, `world_ballistic.inc` and
`world_wave.inc`; the old runtime manifests were not edited to conceal that.

## Compatibility and documentation scope

The intended native edits (`ballistic_water.hpp`, `world_ballistic.inc`, `world_wave.inc`,
`water_spray_coupling.inc` and `cyber_demo_bridge.hpp`) are not protected paths in
`tools/material_catalogue/compatibility.py::SOURCE_ROLES`. They need no invented
reviewed-source transition; the guard rejects transitions for unprotected paths.
If integration changes a protected file, preserve its source commit, append a
transition from the last admitted hash to that commit's actual blob hash, and
record the path, both hashes and retained source commit in committed evidence.
The immutable compatibility lock is unchanged.

| Canonical page | Updated claim |
|---|---|
| `architecture/ballistic-water-v1.md` | Wave wet/dry corner barrier, checked automatic launch conversion and quantity-aware reaction scaling |
| `architecture/wave-flow-v1.md` | Spill coordinate refusal and fallback, all Wave body-force paths, later-review evidence route |
| `operations/workbench-water-lab.md` | Focused field commitment, current non-Water policy preservation and scope of the later native repairs |
| `reference/status-and-roadmap.md` | Current repair checkpoint, unchanged parents and outstanding qualification |
| `operations/cybersand-codex-development-handover.md` | Operational handoff for this candidate and separate owner acceptance |

No retrieval topic or canonical ownership changes. Existing routes still lead to
the same current reference and guide pages; this audit remains historical-only
retrieval evidence.

## Cross-window follow-up — 2026-11-19

[Publication request 15](https://github.com/techrote/cybersand/actions/runs/44425280197)
completed **9/9 jobs**, and bot commit
`88558bddb54fc5ade66d55abeab2efb75acd123f` appended only the two runtimes and
their two manifests to source `71a00ea727bbe282454afb55070daaf82ecea55f`.
Normal, ASan/UBSan and TSan each passed Wave 31/31, spill 26/26 and 50 boundary
runs / 6,000 ticks with matching metrics. Linux and Windows passed all ten
import/headless records; Linux rendered Wave/Workbench checks and the extracted
Windows package also passed. Independent readback verified both runtimes,
95 native inputs, 852 build inputs, reports and log hashes.

A final cross-window probe then found a regression in the first focus repair.
With Water Lab already open, typing main X = 350 without Enter and clicking its
child **Nozzle at X/Y** action could still use the previously committed X. Godot
retains each viewport's focused field. Committing only the child discarded the
original helper's main-field commitment. The old parent-commit control used the
typed coordinate, establishing the cause.

The two-file correction is
[`6179f1f93e29aa730398093c650f22f256ede3b9`](https://github.com/techrote/cybersand/commit/6179f1f93e29aa730398093c650f22f256ede3b9),
tree `540038e161eae1a2597d1b659c23c30d9f8ed986`. It commits the clicked child
first and the main viewport second when they differ; default/main callers visit
their viewport once. The regression leaves **both main X and child supply**
pending, uses actual mouse/character input, reads the worker-owned nozzle
position, and checks actual emitted native Water at the intended coordinate
and not the stale coordinate. It restores the authored fixture afterward.

The new regression failed exactly two of 237 assertions before correction:
accepted nozzle position and actual Water placement. After correction, the
full Workbench Wave suite passed **1,259 assertions**, all twelve sections,
**35 native ticks**, exit 0 and no ERROR lines. Workbench spill also passed
**618 checks**, all seven sections and no errors. The native local runtime
remained `02f1257a3f99023da707d790bf871a99ecc7861a0c76e3895b8eb4ffe451ea7f`.
The after-run log SHA-256 is
`c7350b6bc52923e828470e114b6785dbe367f115b6af26e7b3c22bb716af7ccf`.
Independent review found no remaining blocker in this correction.

No native source changed in this follow-up. Request 15 remains valid evidence
for its recorded source, but its UI/package results are **predecessor evidence**.
Publication request **16** binds the corrected scripts and extended regression;
its resulting runtime/package and final-head CI results belong in the PR ledger.

## Remaining acceptance

After implementation, freeze the repaired source, complete the required native
and source-matched desktop checks, publish through the existing guarded lane,
and record resulting-head CI and an independent follow-up review. Physical
Windows/NVIDIA evaluation and the original surface-crest crash reproduction are
separate from these targeted regressions. This record grants no Ready, merge,
auto-merge or default-promotion decision.
