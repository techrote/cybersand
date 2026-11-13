# WB-ART-SLM-001 — independent Windows Job boundary and gallery freeze

Date: 13 November 2026. Scope: Evaluation role only. **Disposition: HOLD** for unconditional Windows process-lifetime safety and every real-model/native/desktop acceptance gate.

## Exact evidence reviewed

- Combined Draft [#567](https://github.com/techrote/cybersand/pull/567), source head `a9f8425cc38e5b3b52b24272fb760c296843d661`; Integration bridge `integration/local_art_bridge.py` Git blob **`e9df6e22a279868fd5e99e62650725fba5756fbe`** (descended from `6a0e6a4a`).
- Hosted Windows [run 43408236500](https://github.com/techrote/cybersand/actions/runs/43408236500): **3/3 new Win32 job tests PASS and 9/9 existing bridge tests PASS**. The **overall workflow failed** in a separate Training-owned offline test step. No false all-green claim.
- The checked source's `_run_owned_inference` calls `subprocess.Popen` **before** `_WindowsOwnedProcessJob(process)`, with no suspended-start/atomic Job attribute. This ordering is confirmed against the pinned GitHub file. `CreateJobObjectW`, `SetInformationJobObject` class 9, `0x2000` KILL_ON_JOB_CLOSE, `AssignProcessToJobObject`, `TerminateJobObject` and `CloseHandle` are present.

## Independent findings and claim boundary

1. **Pre-attachment descendant escape: unresolved.** The child's code can run and spawn an independent descendant during the Popen-to-Assign interval. Assigning the immediate parent afterward does **not** retroactively attach a previously created descendant. A successful Job assignment is not proof of complete lifetime ownership from initial process creation.
2. **Assignment-refusal cleanup: unresolved.** When Job assignment raises, the bridge refuses Art output and calls `_stop_owned_process`, whose Windows path terminates only the direct child. Any descendant created before refusal can live on. The original `test_job_assignment_refusal_produces_no_batch` asserts the delayed marker is absent **immediately**, not after its programmed delay.
3. **Immediate-parent-exit scenario: limited GO.** The hosted test waits for a descendant to start and verifies an already-attached Job closes after the wrapper exits and suppresses a late marker. This covers children that inherit the assigned Job, not pre-attachment descendants.
4. **Win32 ABI and nested Jobs: limited GO.** The declared `LARGE_INTEGER`/DWORD/SIZE_T/IO counters and extended-limits shape, information class 9 and kill-on-close flag are consistent with conventional Win32 definitions. Actual size/offset and nested-job behavior are only evidenced for the tested hosted Windows environment; no independent Windows desktop or x86 audit occurred. On other restricted/nonnestable Jobs, assignment can fail. Refusal is correct for Art, not sufficient to prove orphan-free process cleanup.
5. **Handle lifetime: partially guarded.** `close()` calls `TerminateJobObject` and then `CloseHandle` in `finally`; constructor's failed setup closes its own handle. API BOOL results of `TerminateJobObject`/`CloseHandle` are not checked. The code relies on last-handle-to-Job closure, while its Popen parent handle is independently reaped.
6. **Late effects are not native Art receipts.** Existing Stop/disconnect/HTTP checks refuse an Art batch. A descendant synthetic-file write is a process lifetime violation; it does not show that a stale native World write or HTTP Art suffix was accepted. Real adapter inference, native interleaving/Undo/Redo/save, current-source Godot, Windows desktop and human acceptance remain entirely separate.

## Implemented independent diagnostic

[Source-bound Win32 attachment diagnostic](audit_windows_job_boundary.py), code Git blob **`8d45a081f79ce5b5cba7fb43c0bd0e5127d3e388`**, loaded only from a pin-matched real bridge source. It deterministically widens the attachment window **before** calling the actual Win32 Job constructor, verifies a spawned descendant's delayed synthetic side-effect, separately injects Job-assignment refusal, observes refusal/Job closure, and emits structured GO/HOLD.

- Standard-library Python compilation: **PASS locally**.
- Source-hash/AST static controls including wrong-hash refusal: **PASS locally against an isolated representative source fixture**; the exact GitHub combined source ordering was independently read and checked.
- **Independent live Windows execution: NOT RUN** in this session. No claimed observed Windows escaping process; treat the source-level risk as unresolved pending this exact source-bound adversarial diagnostic on Windows.
- From combined source root on Windows, invoke `py -3 experiments/wb-art-slm-001/evaluation/audit_windows_job_boundary.py --bridge experiments/wb-art-slm-001/integration/local_art_bridge.py --expected-blob e9df6e22a279868fd5e99e62650725fba5756fbe --out C:\\temp\\windows-job-independent.json`.
- The diagnostic returns **nonzero/HOLD** if a delayed synthetic descendant write is observed. Source mismatch also refuses. It uses no real model, GPU, native World or paid compute.

**Recommended Integration-owned fix:** create and assign the child to a preconfigured Job *before any inference code executes* (e.g., supported `STARTUPINFOEX` job-list attribute, or a correctly handled suspended-process/retained-primary-thread assignment-and-resume path). Merely calling Job assignment faster is not a proof. Preserve refusal-only HTTP behavior, no stale Art, strict host permissions and exact handle cleanup. Do not modify Integration files from Evaluation.

## Frozen next-gallery request cohort

[Development gallery 60 prompts](gallery60_development_frozen.json) was published **before any new-candidate raw predictions**. Git blob **`0d15d6b51387f01ca4a981c1a33896cfc531ff63`**, SHA-256 **`6b183b4679a108c9c7268c50be7d0758fa255b668e4a902087391b692d2deff5`**.

- **12 themes × five request forms** (literal, paraphrase, modifier, composition, semantic contrast) = **60 independent requests** with distinct IDs at most 38 characters.
- Paired hosts: 96×96 area, Hard Wall 58, seeds **17 and 73**, same compiler/decoding limits across frozen step-400 and next separately named candidate. Seed replicas are not extra requests. At most 120 native material images *per model* and exact two-model seed/ID comparisons; malformed outputs stay failed/no-image.
- The frozen 24 DEVELOPMENT/12 keyword scorecard is a separate regression cohort; reserved FINAL remains sequestered. This manifest claims **no model inference, no new native render, no model quality gain and no human recognition**.

**Next:** Training executes a single lease-owned retrained candidate and publishes immutable first-pass outputs for the 60 frozen requests; Evaluation then replays genuine native material captures and produces a blinded same-seed baseline/candidate gallery. Integration separately resolves pre-assignment process ownership and qualifies the correct Windows/native source. All remain Draft/HOLD; no merge, defaults or unrelated branches changed.
