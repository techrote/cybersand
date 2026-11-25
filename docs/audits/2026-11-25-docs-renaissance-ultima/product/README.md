---
title: ULTIMA product and graphical qualification
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Product manual review, actual Linux native GUI tasks, source-scoped storage faults and independent context review
last-reviewed: 2026-11-25
---

# Product documentation and graphical qualification

Specialist B began with [independent reader observations](independent-intake.md)
before reading the other lanes' patch proposals. The existing README, portal
and task manuals remain the product front door. This lane corrected observed
workflow friction, repaired three misleading runtime labels and a recorder
storage defect, and exercised actual Workbench tasks. This packet is evidence
for the Draft/HOLD candidate, not owner acceptance or merge authority.

## Evidence index and coverage

- [Document coverage](coverage.json): **51 distinct documents**, comprising
  **44 full-text semantic reviews** and **7 selected-section reviews**. Each row
  identifies actual depth, reviewed bytes, source locators and execution limits.
  A full-text read is not a claim that every numerical sentence was experimentally
  reproduced. Other lanes own the remaining canonical corpus.
- [Capture manifest](captures.json): ten actual native-window screenshots, with
  source identity, bytes and SHA-256. These are evidence images, not concept art.
- [Independent persistence reproduction](persistence-independent.json): B's
  separate before/after execution of A's ordinary-save correction.
- [Real permission-denied UI receipt](final-permission-ui.json) and
  [integrated launch log](final-workbench.log.txt).
- Display-backed architecture [author](architecture-display-author.json) and
  [fresh-process reopen](architecture-display-reopen.json) receipts.
- [Actual retrieved-context audit](context-applicability-81817f84.json): 24
  additive questions, 120 supplied passages, with individual judgments.
- [Source 162b8097 method-v1 context audit](context-applicability-162b8097.json):
  separate final-checkpoint passage identities, changed-body review and
  explicit source-follow results; the earlier receipt remains intact.
- [Source 67245ba5 method-v2 context audit](context-applicability-67245ba5.json):
  independently re-adjudicated changed context sets before the later
  accepted-main tooling integration.
- [Independent capture source review and execution](capture-review/review.json)
  and [raw six-case Linux report](capture-review/report.json), with refusal logs.
- Recorder [before](recorder/before.json), [unit result](recorder/unit-after.json)
  and [OS result](recorder/os-after.json), plus retained original reproduction
  inputs and child logs. The [first harness result](recorder/rejected-first-harness-report.json)
  remains failed: it inspected frame 000000 although the writer starts at 000001.
  Correcting that fixture did not change the production writer.

## Source, runtime and environment

The first interactive process used predecessor
`20170bd6259498c3d2774ab274567febb043fc1d`. A separate integrated process used
`a83c6988f33499632d813d58dadd2b6f64c68941`, exported to the child as
`CYBERSAND_SOURCE_REVISION`. Later storage and documentation changes retain their
own test/input identities; this GUI process is not relabelled as a different
final source.

| Component | Exact identity |
|---|---|
| Engine | `4.7.stable.official.5b4e0cb0f` |
| Executable SHA-256 | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Linux native extension SHA-256 | `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7` |
| Rapier2D | v0.35.2; SHA-256 `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Desktop | Linux X11, 1366×1024 |
| Graphics | Mesa 25.0.7, OpenGL Compatibility, llvmpipe LLVM 19.1.7 software rendering |
| Audio | Dummy; no usable physical audio device |

All 18 tracked LFS payloads were materialized and the repository provenance check
passed after pinned companion source inputs became available. The installed
unqualified default Godot 4.7.2 was not used. VSync was unsupported by this driver.
These are actual interactive native windows and source-matched simulation, not
physical Windows/NVIDIA playfeel, a browser mockup or a performance acceptance.

The profile was disposable. `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and
`XDG_CACHE_HOME` pointed to separate task directories. After the normal project
import, the integrated launch was:

```sh
export CYBERSAND_SOURCE_REVISION="$(git rev-parse HEAD)"
"$CYBERSAND_GODOT" --audio-driver Dummy --rendering-method gl_compatibility --path godot --resolution 1366x1024 --position 0,0 -- --workbench
```

## Actual interactive task matrix

| Workflow | Observed outcome | Source/evidence scope |
|---|---|---|
| First launch | Ordinary Workbench opened paused, Observer/no human pilot, 2048-square canvas and visible controls; launch reached `SHARED_WORKBENCH_LAUNCH_READY`. | Predecessor and integrated processes. |
| New scene and painting | Main palette displayed Reinforced Concrete/58. Line created a floor and two walls with 2563/1773/1773 changed cells; Sand Brush changed 6054 cells. | Original actual gestures; manual label corrected. |
| Selection/Copy/Paste/Fill | Integrated selection copied 20001 native cells including Empty; paste acknowledged all 20001. Water Fill changed 6054 cells. Undo restored Sand and Redo returned Water, each acknowledging 6054. | [Integrated paint/history capture](captures/final-paint-history.png). |
| Ordinary Save and evolution | Original named save was 1738 bytes. Sand visibly settled; Restore rebuilt authored floating Sand. Overview recovered content hidden by the reset Free camera. | [Original authored reload](captures/reloaded-authored.png); this is authored reconstruction, not physical continuation. |
| Candidate same-name Save | Integrated save committed 4595 bytes. Actual directory mode 0500 then caused explicit UI refusal and left all 4595 old bytes/hash unchanged. Restoring 0700 allowed retry 5578 bytes and valid JSON. | [Refusal image](captures/final-save-refusal.png), [byte/digest receipt](final-permission-ui.json). Disposable data only. |
| Candidate ordinary reopen | F2 ended the session; a new Workbench loaded the successful retry. Overview showed the Water-filled original and pasted Sand. | Fresh scene/session in the same process; not described as process restart. |
| Direct JSON | Guide rectangle/disc example acknowledged 8633 checked/changed and 0 refused. Invalid `{bad` produced an explicit parse error and preserved prior content. Art still uses legacy Hard wall/58 wording. | [Actual Art receipt](captures/art-direct-completed.png); zero provider/model calls. |
| Generated preview/cancel | Original cancellation left stale Preparing text. Integrated Start/Stop displayed `Preview cancelled. The installed World is unchanged.` and `No installable material proposal.`; Install disabled and old world retained. | [Before](captures/cancelled-preview.png), [after](captures/final-cancelled-preview.png). |
| Generated install/edit/save | Three-style1024-square native proposal reported 64 receipts/136685 nonempty cells. Explicit Install replaced the scene; a 452-cell Sand edit was saved. | [Original verified preview](captures/architecture-preview.png); observed 17.10 seconds is this host's sample, not a latency guarantee. |
| Generated reopen | Integrated Load displayed **Embedded saved recipe**, reconstructed the saved proposal, required explicit Install and retained the 452-cell edit. CtrlS acknowledged generated-save success. | [Corrected recipe label](captures/final-embedded-recipe.png); actual rebuilt preview 16.11 seconds. Separate automated fresh-process reopen 22/0 below. |
| Flatten | Actual confirmation reported the 1024-square 2 MiB material baseline. Live scene stayed visible, old operation history was discarded, and a saved flattened start loaded from a fresh blank session without rerunning the generator. | Original source-matched native material writer; no exact physical continuation claim. |
| Water Lab | Five tabs and requested/applied Wave controls were visible. Two Crests 512-square loaded; Play/Pause visibly changed/stopped the scene. | Representative controls, not all hydrodynamic claims qualified. |
| Materials Lab | Water+Salt, seed 2, 120 ticks/1 worker completed 120/120 in its isolated native world; observed Water 329/Brine 134/Salt 6381 from Water 384/Salt 6448. | Standalone experiment; no claim of live Workbench audition or chemical calibration. |
| Actors and equipment | Actor Composition placed Midge #1 in a disposable session. Integrated Physical Thunderbowl displayed 46 rigs; four default actors advanced to tick 655 and paused with equipment cancellation. | [Thunderbowl capture](captures/final-thunderbowl.png); not all 46 rigs manually tested. |
| Showcase | Integrated Deepworks showed 16 districts/4 worlds/32 exhibits. A1 Customs of Dust opened; native Sand/Dust visibly fell and formed heaps; Pause stopped it and the rear-layer checkbox changed presentation. | [Deepworks capture](captures/final-deepworks.png); representative showcase, not 32-exhibit quantitative acceptance. |

## Implemented findings and review

| ID | Priority | Concrete correction and evidence |
|---|---|---|
| B-ULT-01 | P2 | First-session main palette name corrected to Reinforced Concrete/58; Art's distinct legacy label explained. Source and actual UI agree. |
| B-ULT-02 | P2 | Save/Restore/Load instructions now include Overview when reset camera placement hides authored content. Reproduced in actual ordinary reload. |
| B-ULT-03 | P2 | Cancelled native preview no longer retains a Preparing message. Runtime commit 523de8e5; source reviewed by A, discovery regression and integrated GUI passed. |
| B-ULT-04 | P2 | Saved-recipe reconstruction now identifies **Embedded saved recipe** instead of the unrelated default picker choice; selecting a catalogue profile explicitly leaves embedded mode. Commit 584874f6, A independently executed 29 checks/0 failures; integrated GUI confirms label. |
| B-ULT-05 | P2 | Physical Thunderbowl header derives 46 from its actual picker catalogue instead of stale 41. Commit 14c0b26d; A independently checked the catalogue owner, and integrated GUI confirms 46. |
| B-ULT-06 | P2 | Combined authoring guide's stale palette/save/UI limitations corrected; legacy Water export clearly marked revealed engineering metadata that can expose hidden mapping and overwrite its fixed file. Owner-not-planned formal-study work was not reopened. Commit 12936181, A source review approved. |
| B-ULT-07 | P1 | Gameplay recorder could report success for 128 bytes of an intended 1024-byte frame and invalid truncated JSON. Candidate 56117d19 verifies complete closed frame bytes, refuses existing/unsafe session names, preflights native capability and transactionally replaces only the manifest. Local 94-check suite and real Linux fault/normal cases pass. A independently approved the state transitions, executed all 94 checks and both real Linux cases, and inspected retained frame bytes and the unchanged initial manifest; its receipt is in technical commit c0a1c6be. |
| Cross-lane capture defect | P1 | Full manual/source reading exposed the same unchecked capture writer in Main and native MicroScenario CLI. A reproduced both and implemented the shared transaction. B corrected the two canonical capture descriptions, independently reviewed acknowledgement/commit order and executed all six real Linux caller cases at 63e8f753. Prior valid bytes and retained results survived both faults; normal retry succeeded. Windows remains separately qualified. |

B also independently reproduced A's ordinary-save defect with real
`RLIMIT_FSIZE=128`: before, success after 475→128 byte corruption and invalid JSON;
after, explicit refusal and identical 475-byte old file. The
[technical report](../technical/persistence-design-and-results.md) owns all
three save callers, staged-failure boundaries and platform-specific results.
No manual wording is substituted for the runtime fix.

The recorder's storage change is a per-file contract. A frame count advances
only after all requested constituent files verify. A failed final manifest keeps
the initial valid `recording` disposition and surfaces failure. Partial files can
remain in the failed session and must not be treated as a complete recording.
Disk mode explicitly requires native replacement before any output creation;
in-memory mode remains independent. No whole-recording atomicity, fsync,
power-loss durability, hostile-directory race defense or zero-overhead promise
was added. Fresh Windows lock results belong to the integrated hosted receipt;
the local Linux result does not establish them.

## Focused tests and retained negatives

| Qualification | Actual result | Scope |
|---|---|---|
| Generator discovery | 29 checks, 0 failures; A independently repeated | Headless pinned runtime; captions, explicit profile choice and cancellation state. |
| Architecture author | 73 checks, 0 failures | Real X11 display, original integrated B source and normal frame scheduling. |
| Architecture fresh-process reopen | 22 checks, 0 failures; natural exit 0 | Source a83c6988, 17.77 seconds, 64 native receipts, two saved edits, matching recipe/material hashes. [Receipt](architecture-display-reopen.json). |
| Initial headless architecture attempt | 62 checks, 4 failures | Viewport-fit assertions failed without required 1280-pixel display. [Original log](architecture-headless-attempt.log.txt) retained; not called a pass. |
| Physical catalogue | 6267 checks, 0 failures | 46 definitions and scoped source invariants; distinct from the limited manual GUI sample. |
| Recorder unit regression | 94 checks, 0 failures; natural exit 0 | Missing capability, in-memory mode, unsafe names, existing sessions, partial frame, final-manifest refusal and existing timing/queue behavior. |
| Recorder real Linux OS matrix | 2 cases passed | Normal frame 1024 bytes/complete; actual 128 byte file-size limit produces failed status/written 0/unchanged valid initial manifest. |
| Independent MicroScenario capture matrix | 6 cases passed; natural exit 0 | Controller and native CLI normal replacement, real buffered-tail file-size limit and directory-permission refusal. Exact prior digests/decoded values retained, no false acknowledgement, retry and relative path with spaces passed. |
| Documentation checker in B worktree |Failed on one cross-lane link | A's technical report was absent in the isolated B branch; root integration owns the complete final documentation gate. No new local route error was reported. |

The OS recorder runner also implements a Windows target-sharing-lock case:
lock a valid initial manifest without delete sharing, write a complete frame,
and require failed finalization plus unchanged prior manifest. The receipt
records natural completion and rejects engine/script/native-load errors even
when a result marker appears. Do not call this executed on Windows until the
separate actual Windows receipt passes.

## Retrieval and independent cross-review

B inspected the **actual** proposed contexts at 81817f84 for DR01–12 and DR25–36:
**22 sufficient, 2 partial, 0 wholly wrong-context**,120 passages. DR04 lacked focused
validation/C-header detail in its first-pass passages; DR08 lacked the full
Wave-versus-ballistic distinction. C then exercised explicit source-following
through a retrieved canonical link. B judged those returned source documents
sufficient for the missing facts, separately from the original first-pass score.
The two full-document reads cost 92564 bytes and 48613 bytes respectively; this is
not a free improvement or an executed model decision. Reviewers were not blind,
and B had authored some manual corrections. No generative answers were run.

The separate **162b8097 method-v1** review preserves the same 22 sufficient /
2 partial first-pass result. Of 120 passage bodies, 109 match previously reviewed
bodies exactly; all 10 unique changed bodies were reread, and this artifact's
authority envelopes and source identities were checked. Explicit source-follow
again supplies the missing facts: 93005 bytes for local build and 48842 bytes for
Wave. The local-build source read also exposed a separate generic sanitizer
recipe contradiction, reported to lead and corrected after this checkpoint.
Neither that later correction nor a later retrieval method inherits this
receipt without an input comparison or rerun.

The **67245ba5 method-v2** audit also retains **22 sufficient / 2 partial**.
Nine exact ordered context sets are unchanged; fifteen changed sets were
re-adjudicated and all eight newly supplied passages read. Explicit source-follow
costs 93031 + 48842 bytes and supplies both missing contracts. The layout query
retains the same five passages and canonical rank 3. All three source-bound
receipts remain visible; none claims a generative answer or automatic source
selection.

DR02's supplied passages contain exact dependency pins. DR36 appropriately
abstains from an absent owner decision and supplies an authority route. The
Explore layout primary document moved in rank, but the inspected practical
passages still support a bounded correct next action. A owns DR13–24; the
retrieval lane's final source-bound report owns all 36 combined outcomes.

B independently reviewed A's torque/rotation and Wave catch/grace corrections,
C's maintenance/index/authority explanations, owner Web policy routes, actual
PENV picker label and accepted PLAY-WAIT ancestry, and the physics manifest
portability correction. Lead's compact LCB reader procedure and Tower/Water
readiness boundary were checked separately. Approvals concern the reviewed
source/diff; they do not requalify another programme's runtime or historical
campaign. B also reviewed 26 sealed holdout expectations without exposing them to
C; one ambiguous premise was reported for a separately versioned fact correction.

Late accepted-main drift introduced #758's Windows owner-acceptance tooling at
be87b18b. B fully read its new guide, checked selected verifier/launcher routes,
and corrected the catalogue guide's stale unmerged status in 5f5e9193; C
independently approved that correction. Accepted tooling, a qualified exact ZIP,
and physical owner acceptance remain distinct. This review did not execute the
new Windows harness or reopen a physical gate as passed.

The subsequent accepted CI closure at 5e29b111 adds standalone coordination and
publication-custody tools. B fully read both revised runbooks, checked their
actual workflow caps and selected CLI/source contracts, and independently
reviewed the separately corrected CI case before scoring. The original 32 and
accepted 33 fixture bytes were verified separately. A misleading always-emits
output claim was corrected to the successful-result schema. The
[reader-review receipt](accepted-ci-reader-review.json) retains exact reviewed
hashes; it claims no new hosted campaign, publisher integration or authority.

The late four-profile correction received an independent **16-case Linux**
public-caller run at exact committed input bytes from b698a2b2. Real buffered-tail
limits and permission refusals preserved the previous 3152/4570/373/176-byte files,
which their actual format readers reloaded; normal retries saved the new value.
The [profile review](profiles/independent-review.json) also records fresh real GUI
Worldgen, Transport and Tower Save acknowledgements and permission refusals.
Worldgen and Tower retries cleared their own failure feedback. Materials Lab
export remains public-caller/headless evidence in this pass. No new durable PNG,
natural GUI exit or Windows/physical result is inferred from these observations.

## Exact external boundaries and owner continuation

**Rendered documentation remains blocked.** The connected browser extension
reported that it required an originating browser context. The permitted cloud
fallback could not connect to the local preview (`ERR_CONNECTION_REFUSED`). A
subsequent attempt to inspect that failed tab received an explicit browser
security-policy denial for its resulting URL/protocol. That path was stopped;
no alternative browser surface or raw browser automation was used to bypass the
denial. README/portal/manual markup, routes and image provenance were reviewed,
but there is no fresh desktop/narrow browser rendering pass to claim.

Physical Windows/NVIDIA playfeel, a genuine provider/model creative run and the
recorder's matched recording OFF/ON owner-performance campaign were not available
in this lane. A software-rendered desktop, a headless case, a source review and
Direct JSON are each labelled by their actual evidence class.

On a permitted owner host, use the exact candidate's qualified runtime, an empty
user-data profile and the ordinary Workbench. Repeat the first-session painting,
same-name Save/reopen, generated Load/explicit Install, Restore/Flatten and
Direct JSON steps above. Confirm visible failure feedback with disposable data,
then run the platform storage qualification scripts from the canonical manuals.
Separately render README, portal and first-session/saving manuals at desktop and
narrow widths. Record source/build, OS/GPU, actual result and captures; a pass
must not be inferred from this Linux session or a later evidence-only commit.
