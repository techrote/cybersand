---
title: EXPLORE-001 independent integration QA checkpoint
status: Current
document-kind: evidence
scope: Read-only source reviews, reproduced preview defect, corrected qualification plan and guarded Windows candidate delivery
canonical-for: []
last-reviewed: 2026-11-08
related-documents: [../systems/explore001-generated-playable-maps.md, ../operations/explore001-desktop-playtest.md, ../operations/current-and-historical-validation.md]
---

# EXPLORE-001 integration QA — 8 November 2026

**Draft / HOLD. No Ready or merge authority is inferred.** Main was fetched and
remains `1f82dac1cebc9b38a319153354e4bcc774289417`; incoming PR #542 head was
`f51e55bda786bde7d571320a7caa1a078f2d3f7d`. This checkpoint is a local delta
from that recoverable source, subsequently identifiable by the commit containing
this record. Original repository `C:/khybersand`, branch
`mat/material-fidelity-pass-2`, HEAD `620826f59fbe248f93a45c45e786a7297f2e5288`,
has unrelated modified native/material source and DLL plus untracked work. It was
left untouched. Review and correction used a separate detached checkout at
`C:/Users/_/.codex/worktrees/explore001-qa-20261108/khybersand`.

## Independent source findings

Three separate read-only reviewers examined native authority, Godot persistence,
and cross-PR/CI integration. They made no edits or qualification claims from
source presence alone.

| Severity | Finding and exact incoming source | Disposition |
| --- | --- | --- |
| P1 | `workbench_generator_dialog.gd::_stop`, incoming line 179, failed to reset `_next_chunk`. A second same-size chunk preview skipped all chunks and accepted empty materials; a larger preview omitted initial chunks and a smaller one stalled. A saved bad preview could not regenerate correctly. | Runtime reproduced on Windows with a new exact material/receipt regression: 39 checks, 2 failures, 14,523 ms. Reset cursor on retirement; repeat, partial cancellation, larger/smaller and fresh-process reconstruction regressions added. |
| P2 | `test_explore001_reopen_diagnostic.gd`, incoming line 24, required a named map created by a different process, but ordinary CI independently discovers/shards all `test_*.gd`. Its diagnostic success also admitted mismatches. | Retired the temporary diagnostic and duplicate admission probe; original source is recoverable at incoming head. Retired hardcoded old-DLL replay workflow; kept source-built Linux/Windows qualification. |
| P2 | Production Windows regression loaded the retained DLL despite a changed prepared-native header. | Reproduced in [initial full GDExtension run](https://github.com/techrote/cybersand/actions/runs/42473543881), shard 0 job `128709886024`: 0/5 assigned cases, explicit source-input rebuild refusal. Same-run freshly built DLL now has a separate candidate manifest consumed by Windows shards and their independent coverage reducer. Retained provenance is unchanged. |

The native reviewer otherwise found existing exclusive-worker ownership,
prepared-World token/revision/lifetime fences and refusal preservation intact.
Rapier remains main-thread owned; only copied values cross owners. Native
`stored_material` remains the construction oracle; Water's render dithering is
separate. GEN source global-to-local mapping, source fingerprints and material
catalogue compatibility are retained. No material law or native code changes in
this correction. No other source-proven P0/P1 was identified in the bounded review.

## Source transition for Integration

The following heads were independently read, including patches and recent
comments. They remain separate Draft candidates, without an authorized ownership
transfer into EXPLORE.

| PR | Head | Overlap and required future seam |
| --- | --- | --- |
| #402 | `80bae8847fc2428a213f8b0e5e1c8fcd7e1b80ff` | Conflicts with main; flyer options/Setup-v3. Direct `shared_workbench.gd`, `main.gd` and retrieval overlap. Preserve options only after native ACK. |
| #409 | `6bdab8ef59e1d7b9771718ebe07dd799c1e06ed3` | Stacked on #402, not main; roster/equipment/Setup-v4 and physical capacity changes. Requires explicit generated-manifest schema migration/backward tests. |
| #529 | `8f07084aeb4c8fbda5caf371ad791848c120fedf` | Native agent-authoring owner; released narrow lifetime repair already consumed by #531. |
| #530 | `f55ca2b044b0130fd503864c2b82fc1e6bcae8a9` | Step/Stop release consumed by #531; no direct EXPLORE product-file overlap. |
| #531 | `a3492d28e1e4016af646ed0aef53218c19925d3c` | Direct product overlap only `shared_workbench.gd`. Keep both UI mounts and retire active agent tasks before confirmed generated install/restore/load changes World generation. Preview/cancel must not mutate World. Preserve human-paint/Play–Pause fences and opt-in signed +512 scope separately from GEN global coordinates. |

Newer #534 is docs-only; #484/#540 are qualification-only; experimental #486's
sharded World is outside EXPLORE. None authorizes copying an active owner's file.
Main has not advanced, so no main merge is needed. Keep #542 isolated. After
Integration selects an admitted source, reconcile these specific seams on one
controlled source branch, then rebuild and rerun its exact-head matrix. Do not
overwrite either controller or blindly cherry-pick an unfinished stack.

## Evidence and qualification limits

Original Windows source-built 55/55 + separate-process 18/18 and Linux rendered
58/58 + 19/19, legacy Workbench164/164 and GEN-007606/606 remain historical
source-qualified results. The [Linux closeout](https://github.com/techrote/cybersand/pull/542#issuecomment-6720510588)
preserves the original sequence-only X11 failure and corrected controls. It is
not rewritten as a core-physics defect or a pass on this corrective delta.

Local Windows controls used exact Godot `4.7.stable.official.5b4e0cb0f`, pinned
Rapier0.35.2 and source-built native DLL SHA-256
`c915245c73680ec5cc7999c14e095696137a4a5fd0c00aa817c0b87c322d2788`
from source `d02cf28e4e58fab6e270558d08d7abe2e5c43985`. Git comparison confirms
native inputs are identical to incoming head and this correction; only scripts,
tests, CI and documentation change. This is explicit native-source equivalence,
not a claim that an old retained production DLL implements changed C++.

The cursor-only correction passed60/60 locally in18,034ms. Expanded Windows
headless coverage including a real2048² generated prepared-World installation
passed68/68 in35,999ms and a separate process with four corrupt saved identities
and repeated chunk reconstruction passed24/24 in13,550ms. The subsequent final
test additions and exact-head hosted qualification remain separately recorded
on PR #542; do not infer their outcome from these intermediate counts.
The final local test delta passed73/73 headless in37,912ms and76/76 under
actual Windows OpenGL3.3/NVIDIA TITAN RTX rendering in66,820ms, retaining three
original framebuffer PNGs. Automated graphics is not a human acceptance verdict.
Observed preview time was0.69s512²,2.79s1024²,11.11s2048² on this Windows host.
Copied material buffers were262,144/1,048,576/4,194,304 bytes and preview RGBA
buffers1,048,576/4,194,304/16,777,216 bytes. Those are only buffer sizes; old and
prepared native Worlds, staging structures and rendering add substantial memory.
Per-process/tree timing and peak-memory evidence belongs with hosted/local logs.

Exact source51526e6d local replay passed73/73 (39,457ms fixture time) and a
separate process passed24/24 (14,068ms). The Windows PowerShell sampler retained
the console wrapper and its directly owned Godot engine: peak sampled working
set811,917,312bytes for the combined fixture including2048², and455,106,560bytes
for reopen, with nominal100ms sampling. This is observed residency, not a total
allocation bound. Source/tree, DLL/Rapier and raw-log SHA-256 accompany the local
receipts. No native input differs from the rebuilt d02cf28e library.

The first full source51526e6d GDExtension run
[42474912481](https://github.com/techrote/cybersand/actions/runs/42474912481)
failed budget preflight before regression execution: two new Windows candidate
steps lacked explicit allowances. The follow-up changes only workflow/documents:
allocate5minutes each for artifact download and verification, reduce the
now-Rapier-only materialization allowance from20 to10minutes, retain the existing
70minute total setup reserve. `test_godot_job_plan.py`11/11, provider/scheduling
and pinned actionlint then passed. This failed run is not a runtime pass; final
exact-head full matrices and candidate build are dispatched again.

Local raw logs and negative controls are retained outside the source checkout in
`../evidence/`; full hosted runs retain source/tree, compiler/dependency/build
logs, binary hashes, original process outputs and rendered captures as Actions
artifacts. The initial production Native run is
[42473531945](https://github.com/techrote/cybersand/actions/runs/42473531945).
Both production workflows permit manual dispatch while the PR stays Draft.
Skipped Draft/conditional jobs are never passes.

`check_repository.py` still reports stale **published retained** Windows/Linux
native provenance for the prepared-header change. A separately attested candidate
does not satisfy that publication gate. No historical hashes are rewritten and
no candidate is silently committed as a production runtime. This remains a merge
blocker until the normal source-matched runtime publication is performed.

## Candidate delivery and documentation checklist

The Windows source-built workflow packages the committed project, sibling
GEN profiles, official pinned Godot4.7 GUI/console executables, source-built DLL,
pinned Rapier, license/notices, candidate provenance and per-payload SHA-256
manifest. It tests a copy of that packaged project in two Godot processes and
retains the pristine bundle for90days. The existing Shared Workbench launcher
entry remains `-- --workbench`; the bundle needs no Git/Python installation.
See the [manual playtest](../operations/explore001-desktop-playtest.md).
Hosted headless execution and automated graphics do not constitute human
Windows traversal/camera acceptance.

Canonical source behavior/limits and test commands are updated in the
[generated-map contract](../systems/explore001-generated-playable-maps.md);
ownership/interfaces/invariants and material laws are unchanged. The local build
guide records explicit Windows candidate custody; roadmap, documentation index,
retrieval route, corpus and additive questions distinguish this Draft candidate
from accepted main. No ADR or configuration default changes are required.
The documentation, M11 historical integrity, repository/current provenance,
retrieval and focused Python/Godot tests are run with their individual outcomes
retained; a failed publication gate is reported separately from source and
candidate runtime execution. Final disposition and exact workflow/artifact links
are appended to PR #542 without promoting or merging it.

## Capacity and first-open layout correction — 2026-11-08

Incoming source is `50ff2ac18685fb19a3d47608e6a65d9b8e29c813`, after actual
retained runtime publication from `4713545c` (run42479952567). The earlier
publication-blocked results above remain historical. Both published libraries
match the unchanged87 native source inputs; Windows DLL SHA-256 is
`e4e0f9e9bc23c8bfa1ded4247a3a507ffcf6f11835c656608f54fa0b3e7fc67d`.
This correction changes only Godot dialog layout, tests and documentation;
native ownership, interfaces, material laws, dependencies and save schema do not
change. No new ADR, capacity value or runtime publication is required for these
script changes. Current-source repository validation passes locally.

The incoming early-capacity test executed in actual Windows Godot4.7 with that
source-matched DLL:74/74 PASS. The expanded test covers512²/chunk8 and
2048²/chunk32 (4096 receipts), positive and negative unaligned512²/chunk16
(1089 receipts), refusal before buffers/queue/receipts and unchanged installed
World/physical epoch. The existing aligned2048²/chunk64 native installation is
the positive1024-receipt boundary. Expanded first process77/77 and a separate
fresh process24/24 passed locally, with retained original outputs.

Fresh-process graphical reproduction confirms the owner-reported layout defect:
before the first container layout, the incoming dialog opened720×4875 inside a
1280×720 embedded viewport; reopening was720×610. The negative fixture recorded
9 checks/1 failure and an original framebuffer. This is an actual Godot4.7
runtime observation, independent of the upstream issue cited in the PR review.

The correction puts the content VBox inside a ScrollContainer, keeps inherited
OK/Cancel outside it, and routes new/saved/refusal reopening through one bounded
popup method. Native bounds use the owner's screen usable rect; embedded bounds
use the viewport. Parent resize updates the bound. No new generation request or
World mutation occurs during layout changes.

Six standalone graphical cases exercise first new/saved opening, reopening,
parent resize and deliberately short dialog/content scrolling. Windows local
OpenGL3.3/NVIDIA TITAN RTX execution passed19/19 per process including two frame
captures,114/114 total. Initial corrected embedded geometry is720×610 at both
tested parent sizes; embedded resize to1100×500 bounds the dialog height to436.
Native cases use the actual screen usable rect, not an emulated720p display.
High-DPI transitions and human exploratory feel remain separately unqualified.

Raw negative/corrected logs and PNGs are retained outside Git at
`../evidence/layout-capacity/`; commands use pinned
`C:/Godot47/Godot_v4.7-stable_win64_console.exe`, graphical `_render` fixtures
and the generated-workbench/fresh-process script with existing gameplay fixture
watchdogs. CI additionally applies the repository's outer process bounds.
The exact final commit is identified by the PR
qualification ledger. Linux/current-head hosted outcomes are not inferred from
these local results; rerun the scoped and full Godot/Palette gates after freeze.

The generated-map contract and manual playtest are the canonical updated homes.
Existing ownership/ADR/configuration/roadmap routes remain valid; no dependency
order or source-owner transition changes. Additive retrieval questions cover
early receipt admission and first-open button accessibility without altering
the frozen32. Docs, M11, current repository, retrieval and whitespace checks are
run separately, retaining original failures and explicit platform qualifiers.

The first exact6119f917 full Godot matrix passes, but scoped rendered Linux
run42497292424 fails its existing300second2048² preview wait while colour work
is still progressing (2,859,008/4,194,304 cells). The raw first failure remains
in `../evidence/layout-capacity/linux-scoped-first-failure/` and its Actions
artifact. That is not a passed rendered2048² scenario. Only that largest-preview
test phase now consumes the existing named `graphical_case_seconds` allowance
(1200seconds), within the retained outer fixture bound. Production scheduling,
capacity, native code and the policy's numeric values are unchanged. A corrected
rendered execution must finish with the material/receipt/install assertions;
increasing the test allowance alone supplies no runtime or performance pass.
