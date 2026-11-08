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
