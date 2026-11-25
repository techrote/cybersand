---
title: ULTIMA product and graphical qualification
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Source-grounded manual corrections, genuine Linux software-rendered Workbench tasks and independent persistence review
last-reviewed: 2026-11-25
---

# Product documentation and graphical qualification

Specialist B began with [independent reader observations](independent-intake.md)
before reading other lanes' patch proposals. The existing README, portal and
task-oriented manuals are useful and are retained. This lane corrects observed
workflow friction and misleading feedback, with narrow source changes where
appropriate. This is test evidence, not owner acceptance or merge authority.

## Exact environment and scope

The interactive process was launched from predecessor
`20170bd6259498c3d2774ab274567febb043fc1d` using Godot
`4.7.stable.official.5b4e0cb0f`, executable SHA-256
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The Linux native extension SHA-256 is
`a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7`;
Rapier2D v0.35.2 is
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.
All 18 tracked LFS payloads were materialized and the repository provenance
check passed after the pinned companion source inputs became available.

The permitted Linux desktop used X11, Mesa 25.0.7, OpenGL Compatibility and
llvmpipe LLVM 19.1.7 software rendering at a 1366×1024 window. Audio fell back to
Dummy; the environment reported no usable ALSA device and unsupported VSync.
These are real interactive native windows and source-matched simulation, not
static concept renders, browser mockups, physical Windows/NVIDIA acceptance,
performance measurements or evidence that every feature works.

The launch used a fresh disposable profile, with `XDG_DATA_HOME`,
`XDG_CONFIG_HOME` and `XDG_CACHE_HOME` set to separate task directories, then:

```sh
"$CYBERSAND_GODOT" --headless --path godot --editor --import --quit
"$CYBERSAND_GODOT" --path godot --resolution 1366x1024 --position 0,0 -- --workbench
```

The installed default `godot` executable was 4.7.2 and was deliberately not used
for this project qualification. Screenshots below are lossless native-window
captures; their sizes and digests are in [the capture manifest](captures.json).

## Observed user tasks

| Task | Actual observation | Evidence scope |
|---|---|---|
| First launch | Ordinary Development workbench opened paused with Observer/no human pilot, 2048-square canvas and visible controls. | Interactive Linux process; launch log reached `SHARED_WORKBENCH_LAUNCH_READY`. |
| Container construction | Main Paint picker showed `Reinforced Concrete · 58`; Line created floor and side walls. Native completion reported 2563, 1773 and 1773 changed cells. Sand Brush reported 6054 changed cells. | Actual gestures and terminal native receipts; tutorial label corrected. |
| Undo/Redo | Undo removed the Sand patch; Redo returned it, each reporting 6054 cells. | Paused construction only. |
| Ordinary Save | `ultima-container` saved successfully; file was 1738 bytes, SHA-256 `50d7b9a5139d5cfff0290adf1c95af36a4704f0c740e738bf4f109b58667c6d7`. | Isolated disposable profile, predecessor writer. |
| Simulation and Restore | Sand visibly fell to the floor; the UI cleared construction history after source evolution. Restore rebuilt the authored floating patch. Free camera initially hid it; Overview revealed it. | Visible reconstruction, not exact physical continuation. |
| Fresh-session ordinary reload | F2 ended the session; a new Workbench loaded `ultima-container`. Overview showed the authored container and Sand. | [Reload screenshot](captures/reloaded-authored.png). |
| Direct JSON | The guide's rectangle/disc example completed: 8633 checked, 8633 changed, 0 refused. Art's picker still said `Hard wall (58)`. | [Actual Art receipt](captures/art-direct-completed.png); no provider call. |
| Invalid Direct JSON | `{bad` produced an explicit JSON parse error and left the prior shape visible. | Actual UI refusal, no model evaluation. |
| Architectural preview and cancellation | Default three-style 1024-square preview was started and stopped. Installed scene stayed unchanged and Install disabled, but the composition label falsely retained `Preparing a new native material proposal.` | [Before-fix screenshot](captures/cancelled-preview.png); repaired by this candidate. |
| Architectural preview/install/edit/save | Complete preview reported 64 receipts, 136685 nonempty cells and 17.10 seconds to preview. Explicit Install replaced the scene. A 452-cell Sand Brush edit completed; `ultima-generated` saved. | [Verified preview](captures/architecture-preview.png); generated scene used the ordinary native Workbench. |
| Generated reopen | New Workbench opened the saved-recipe verification dialog and began reconstructing; explicit Install remained required. | Final graphical installation/reload and candidate follow-up are recorded separately when completed. |

## Corrections and independent review

| ID | Priority | Finding and implemented response |
|---|---|---|
| B-ULT-01 | P2 | First-session material name did not match the actual main Paint palette. Tutorial now names Reinforced Concrete/58 and Art guide explains its separate legacy Hard wall/58 label. |
| B-ULT-02 | P2 | Load/Restore could appear to lose offscreen construction after resetting Free camera. First-session and saving manuals now provide the observed Overview recovery step. |
| B-ULT-03 | P2 | Cancelled native preview retained an active preparation message. `_cancel_preview` now says `No installable material proposal.` Existing discovery and architecture tests exercise cancellation and retained-preview recovery. |
| B-ULT-04 | P2 | Saved architectural reconstruction displays the selector's default `gen007-deepworks` label while using the embedded recipe. Correct native recipe verification remains in place; the misleading selector is under follow-up review. |

The cancellation patch is `523de8e5`. The focused headless discovery regression
passed **27 checks / 0 failures**. An initial headless run of the existing
architecture `author` phase completed all 62 checks but **failed four viewport-fit
assertions**. Its own form assertions require a 1280-pixel display-backed run;
that failed attempt is retained in [the log](architecture-headless-attempt.log.txt),
not represented as a pass. The actual native install/save/cancel/recovery checks
completed. A display-backed rerun is a separate result.

B independently executed A's original public-writer child before and after
`6fec5da5`, using the same engine, native library and real Linux
`RLIMIT_FSIZE=128` fault. Before: success was returned after truncating the old
475-byte JSON to 128 bytes, and reload failed. After: explicit refusal, identical
old-file SHA-256 and valid 475-byte reload. [Independent before/after receipts](persistence-independent.json)
retain source and child identities. B reviewed the helper and three callers;
the candidate manuals distinguish replacement safety from fsync/power-loss
durability, concurrent editing and exact physical continuation. The
[technical lane report](../technical/persistence-design-and-results.md) owns the
full injected/OS fault matrix and platform-specific contract.

The build guide now brings engine, godot-cpp and API pins into the first-launch
route, puts copyable bounded validation commands together, and explains the
C-header syntax-only probe. Status retains the historical bounded LCB-000
admission without granting old execution instructions. Equipment sections route
locally to #724's unmerged status. Four preservation links now target immutable
predecessor content so compact delivery does not break custody routes.

## Remaining qualification boundary

Physical Windows/NVIDIA playfeel and locked-destination Windows behavior require
their own execution environment. Provider/model requests were not run: Direct
JSON supplied the available non-generative Art exercise without introducing
credentials or paid calls. This report does not convert a skipped, headless,
source-only or software-rendered case into physical owner acceptance.

The integrated candidate still needs its final exact-source graphical readback,
rendered documentation review and independent cross-lane adjudication. This
checkpoint intentionally preserves those outstanding tasks instead of claiming
mission completion from the observations above.
