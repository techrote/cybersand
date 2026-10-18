---
title: MAT-001 persistent material reaction progress
status: Current
document-kind: evidence
scope: Reproduced native compact-pair and Ice sleep starvation, body-mask center wake repair, and bounded implementation validation for issue 158
canonical-for: [mat-001-material-reaction-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/activity-dirty-regions-and-waking.md, ../systems/intermaterial-interactions.md, ../reference/status-and-roadmap.md]
---

# MAT-001 persistent material reaction progress — 2026-10-18

## Authority and scope

The owner clarified that the all-four-builds problem resolved after restarting
the computer, then requested investigation **and fixes** for more game-like,
realistic and consistent material behavior. [Issue #158](https://github.com/techrote/cybersand/issues/158)
owns this bounded implementation under `mat/persistent-reaction-progress`.
The starting source is main `23227bc4d660b516306f111b7a7e4398208afa5d`.
Live ownership inspection found no competing native World/test owner: open
PR #148 touches player/GDScript and documentation, while Stage-3B #66-#68 had
no active implementation branch at intake.

This repair addresses persistent compact-pair and Ice contact opportunities, plus
the body-mask wake gap exposed by their lifecycle tests. It does not tune reaction
products/probabilities, add chemistry, change Water transport or select a #45
successor. Other specialized lifecycle kernels and broad owner gameplay acceptance
remain outside this evidence.

## Reproduced Current defects

The pristine starting World source was compiled with GCC 13.3.0 on Ubuntu 24.04
x86_64. Enclosed two-cell fixtures prevent movement from hiding the contact. The
diagnostic awake control changes only `sleep_after_quiet_ticks` from 3 to 1024;
an independent control places sealed Smoke in the same block without contact.
The fixture horizon is 512 ticks, with deterministic default material state and
coordinate/tick randomness.

| Fixture | Ordinary quiet3 before repair | Awake control |
|---|---|---|
| Ice `(8,8)` beside Water `(9,8)` | No freeze through tick 512; block asleep | First freeze at tick 21; unrelated Smoke also allows tick 21 |
| Lava `(8,8)` beside Water `(9,8)` | No quench through tick 512; block asleep | Quench at tick 4 |
| Ice at x=31, x=127 or x=-1 with Water to its right, y=8 | Each remains unreacted through tick 512 | First freezes at ticks 28, 106 and 42 respectively |

The retained regression initially fails on pristine source at the first quiet1
Lava/Water opportunity, tick 4. After adding reaction deadlines, the first three
regression groups pass but mask/unmask recovery fails. Independent inspection
shows why: `wake_cell_neighborhood` intentionally excludes its center because
ordinary writes already wake that block. Mask insertion/removal had no corresponding
center wake, so removing an interior mask left its stored cells asleep.

## Implementation decisions

`World::schedule_pending_reaction_wake` inspects at most the existing eight visible
neighbors of an admitted unchanged source. It uses the current sparse resolver
with a possible probability roll to detect eligible pair contact, then schedules
the next original four-tick contact lane. Ice schedules the next four-tick thermal
lane for a hot contact, otherwise the sixteen-tick Water-freezing sample.
The shared phase calculation is unchanged; all new deadlines are strictly future.

The post-kernel source epoch check includes successful neighbor-only work, which
can leave another pending contact while the source block sleeps at quiet1. Ordinary
source writes/motion already retain activity through their existing effects.
The existing earliest per-block deadline, bounded worker effects and coordinator
reconciliation remain authoritative. The helper creates no material writes,
render dirtiness, movement counts, per-cell allocation or global scan.

Mask insertion/removal now explicitly wakes its own resident block with
`keep_cell_active` before the existing neighbor wake and mask witness. It changes
no stored material/epoch or rendering payload. The current coupling rebuilds even
stationary masks, so touched interior body blocks are now woken on those rebuilds;
this is local to the existing mask footprint. A diff-based stationary-mask
optimization would be a separate measured change.

Removing a reaction partner does not cancel the shared deadline: another source
or transport lane may own it. One outstanding wake can retire through ordinary
re-evaluation. Region exclusion preserves pending work, re-entry does not replay
missed opportunities, body masks remain contact authority, clear discards prior
World state, and failed worlds retain their existing quarantine.

## Validation checkpoint

The compiled candidate is the starting source plus the following exact native
delta (SHA-256 of LF-normalized file bytes):

| Input | SHA-256 |
|---|---|
| `native/src/world.cpp` | `b455cadfb94fdc7ecc3e737a9e0f825c2beb8bcdd44a404d86c87b53eeeeb019` |
| `native/include/cybersand/world.hpp` | `ed879a1cf89404b0381ea4d599f01fe6ad0024e456d21f155e5a4314d3edd1dd` |
| `native/tests/test_world.cpp` | `6c1ebe190553ee8163bbcad0ac98333b417b94db8dd2ff4c13918d47c7af65e2` |

Executed on Ubuntu 24.04 x86_64 with GCC 13.3.0:

| Command/check | Result and scope |
|---|---|
| Focused C++20 `-O1` wrapper over the seven retained regression groups | Pass: quiet1/3 and awake/unrelated-activity controls, sampled misses, signed/block/core/chunk boundaries, actual one/four-worker parity, idle controls, exclusion/re-entry, masks, neighbor-only success, partner removal and clear |
| `make build/tests`; `timeout 15m ./build/tests` | Pass: all 70 native tests, including seven new groups |
| `make build/test_stage3b_sparse_activity_deadline`; executable with 5m timeout | Pass: existing sparse activity/deadline integration contracts |
| `make build/test_settled_world_discovery`; executable with 5m timeout | Pass: existing World/discovery integration contracts |
| `python3 tools/ci/check_docs.py` | Pass after restoring the exact pinned companion docs used by CI; 78 corpus documents, 133 canonical claims, 1288 local links, zero errors/warnings |
| `python3 tools/ci/check_m11_consistency.py` | Pass: 18 retained records and 28 audited source hashes against immutable M11 revision `05ea45fda7bdd7b0150eb86c4922c202e89e08f4` |
| Frozen retrieval evaluation | 32/32 top-five canonical hits, 23/32 top-one, MRR 0.8438; the frozen questions are unchanged |
| Supplementary retrieval evaluation | 36/36 top-five canonical hits, 24/36 top-one, MRR 0.8134; new MAT01/MAT02 both rank their canonical document first |

The first local documentation attempt lacked five unique companion files (six
references) from pinned commit `6a58311982941b75f46e22109a0829e5acb83c7e`.
Materializing their authentic blobs resolved that setup failure without changing
questions or checkers. Retrieval is a lexical route check: MAT01's direct-answer
subsection ranks second behind the same page's family table; MAT02's direct
activity answer ranks first. Manual review confirms the repaired scope and limits
are present.

The initial ASan/UBSan binary run with `detect_leaks=1` ends with LeakSanitizer's
unsupported-ptrace fatal error in this environment. It is not recorded as a
sanitizer pass. The normal CI-compatible `detect_leaks=0` ASan/UBSan run passes
locally. The initial reproduced failures above remain part of the record.
Independent read-only review found no blocking issue in deadline ownership,
probability/phase preservation, source-epoch admission or the center-mask repair.

The guarded GitHub-hosted publication run
`39096686972` rebuilt both runtimes from frozen implementation commit
`aae015058f907e15b0781ff7fbd3ebd55e4d990e` and matching source tree
`85521fb73a9eb587f843bc64c120503ac2118f36`, using godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1,
Linux GCC 13.3.0/binutils 2.42 and Windows LLVM-MinGW 20260826 UCRT Clang 23.1.0.
The exact rebuilt Linux GDExtension passed the full 70-test native suite, Godot
import, native render-bridge, native edge/contact and MicroScenario native
observation checks before publication. The publication commit is
`cf3ec221d006d42e35bb52a5511536da9a0a3e7c`.

The retained Linux SO is 1,630,856 bytes, SHA-256
`43e747137249041d56a522dbe0ec35219082ea555e1ec1cbdd40971c6a58db9c`;
the retained Windows DLL is 2,099,712 bytes, SHA-256
`61e4ad3a0288c1479098a78c36f64efda6764beacbece917532751f4eb39ffe7`.
Linux ABI-floor and materialized repository/LFS validation pass. Windows PE
cross-build inspection passes, but Windows execution was not performed.

After publication, marking PR #159 ready for review triggered the normal
ready-scope classifiers, but the expensive Native and GDExtension jobs were
skipped on that specific event despite native source in the pull request. This
documentation synchronization therefore deliberately triggers the ordinary
`synchronize` path for the final exact-head Native/GDExtension checks rather than
treating those skips as acceptance.

Remaining integration gates are final exact-head Documentation/provenance, Native,
GDExtension/Godot and the applicable issue49 Water apparatus v2 campaign. A
Windows cross-build is not Windows execution; headless correctness is not owner
graphical-feel acceptance.

## Documentation and compatibility map

| Surface | Disposition |
|---|---|
| Material cadence and activity/sleep contracts | Updated for exact repaired scope and existing deadline lifecycle |
| Generic body coupling | Center-block wake on actual mask changes documented; no new body force or displacement policy |
| INT-000 | Scheduler/contact baseline changes; authored schema/profile, rules, products and probabilities unchanged |
| Roadmap, handover and owner intent | F04 qualified by this bounded repair; restart resolution and implementation request recorded |
| Retrieval routes | Canonical material/activity pages remain in the current corpus; dated evidence stays separately routed |
| Public ABI, save layout, controls, dependency pins and capacity configuration | Unchanged; only a private World helper is added |
| Water transport, reaction accounting, failed-world and interest contracts | Preserved; existing regression/apparatus gates remain applicable |
| Historical evidence and M11 identities | Preserved; current libraries require new truthful provenance |

