---
title: SWARM-006 bounded recovery Windows owner evaluation
status: Current
document-kind: guide
scope: Experimental source-bound Workbench transport, actual Windows GUI qualification and separate owner NVIDIA exercises
canonical-for: [swarm006-workbench-owner-evaluation]
last-reviewed: 2026-11-21
related-documents: [swarm005-workbench-playtest.md, swarm004-workbench-playtest.md, ../architecture/experimental-workbench-authoring-patch.md]
---

# SWARM-006 bounded recovery Windows owner evaluation

**Draft/HOLD.** Programme [#704](https://github.com/techrote/cybersand/issues/704) extends the native SWARM-005 work in [#696](https://github.com/techrote/cybersand/pull/696) and the Workbench integration in [#697](https://github.com/techrote/cybersand/pull/697). SWARM-004/005 branches, receipts and comparison definitions remain historical evidence. This package is a new source-built evaluator. It does not promote a production default or provide owner NVIDIA acceptance by itself.

## Frozen native qualification status

The frozen two-round native holdout improved from **14/96 to 82/96 Apply-authorized cases** and from **3/96 to 81/96 Apply-authorized cases with a qualified foreign joint**, comparing SWARM-005 both ON with SWARM-006 recovery. The [independent evidence review](https://github.com/techrote/cybersand/issues/704#issuecomment-7062877115) retained four cache-digest inconsistencies in rejected, nonauthorizing histories, while the [acceptance coverage review](https://github.com/techrote/cybersand/issues/704#issuecomment-7063144002) found that some diagnostic causes remain combined; these keep the native candidate on **HOLD**. More rounds lost closure within the unchanged work allowances: three rounds produced 6/96 Apply-authorized cases, while four rounds exhausted all 96 cases. These are revealed native corpus findings, not owner NVIDIA or existing-World acceptance; both remain pending. The frozen native source and every unsuccessful result are retained.

## Obtain and verify the actual owner package

Download the GitHub artifact named `swarm006-owner-windows-<full 40-character Workbench SHA>` from the source-matched SWARM-006 Windows workflow. Build-evidence and Windows-runtime artifacts serve different purposes and are not complete evaluators. The owner artifact contains:

- `CyberSand-SWARM006-Draft-HOLD-Windows-<12-character SHA>.zip`, containing the complete Godot project, pinned Windows engine, newly compiled Gentek generator, source-matched Windows GDExtension, supporting runtime and licence files.
- A separate sidecar with the exact ZIP name plus `.sha256`.
- `CyberSand-SWARM006-Windows-Owner-Acceptance.ps1`, generated after sealing this particular package. It embeds the full source SHA, archive SHA-256 and manifest SHA-256.
- `swarm006-owner-seal.json`, recording the same source and sealed-file identities.

Extract the outer GitHub artifact to obtain the PowerShell script. Keep the inner ZIP and its sidecar together. Open Windows PowerShell in that directory and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-SWARM006-Windows-Owner-Acceptance.ps1 -Archive .\CyberSand-SWARM006-Draft-HOLD-Windows-<12-character SHA>.zip
```

Replace the SHA placeholder with the actual filename in the artifact. Alternatively, `-Archive` can name the downloaded outer `swarm006-owner-windows-<full SHA>.zip`; the script finds exactly one correctly named inner package and validates its sidecar. No SWARM-004/005 archive is substituted or renamed. If no `-Archive` is specified, discovery succeeds only when exactly one matching candidate exists beside the script or in Downloads.

The script uses a fresh extraction directory, validates the embedded SHA and separate sidecar, checks every manifest-listed file, rejects unlisted files and unsafe archive paths, verifies both native binary identities and checks the launch files. It refuses an existing destination. `-VerifyOnly` performs verification without launching. `-Destination C:\path\to\a\new-folder` selects a fresh location. After successful verification the ordinary `Open Workbench.cmd` launches the bundled project and clears inherited native executable overrides.

Read the full source SHA printed by the launcher and retain `candidate-manifest.json`, `reciprocal-runtime-provenance.json`, the archive and sidecar with your report. Hash consistency is part of custody; the same-run source producer and independent Windows consumer establish which binaries were actually built and tested.

## Experimental controls and native authority

Open **Reciprocal assembly…** in paused Shared Workbench. **Bounded reciprocal recovery (SWARM-006)** is **OFF by default**. The two SWARM-005 controls remain separately selectable and retain their original meaning:

| Control | Meaning |
|---|---|
| Source-feasible terminal parts | Allow genuine native source-time local termination where authored feasibility permits. Existing frozen foreign-required obligations remain obligations. |
| Source-bound MOSAIC receptors | Enable the SWARM-005 source-bound native receptor construction. |
| Bounded reciprocal recovery | Enable the separately versioned SWARM-006 candidate frontier, native receiver negotiation and recovery receipts. |

Recovery ON emits `SWARM006 4` with the two independent Gentek profile lines and explicit `compact supported recovery` flags. Its response is schema 6 and identifies `GENTEK-SWARM-006` / `gentek_swarm_006_negotiated_recovery_v1`. Recovery OFF preserves V3 when either SWARM-005 option is enabled, and the inherited V1/V2 controls otherwise. No higher work ceiling is selected by this checkbox.

The inspector reports native work, the stop reason, attempted alternatives, receptor reservations and unresolved required connectors with reasons. **A bid or reservation is not a qualified joint.** The Final composition Joints overlay draws actual native material paths. A local source-time termination does not count as a foreign join. Native status and full closure determine whether Apply is enabled; a visually attractive blocked proposal remains blocked.

Saving retains the original acknowledged native JSON, its checksum, source identity and native Apply receipt. Historical frozen SWARM-004/005 definitions remain inspectable without rerunning them under new semantics. Historical inspection cannot authorize a live Apply.

## Reproduction controls and scope

Automated Windows tests create a **new blank synthetic 2048×2048 native World** for the SWARM-006 cases. The owner's existing World may contain material, passages, paint or protected context that changes native feasibility. Matching seed and crop dimensions does not reproduce that physical World. Preserve a copy of the owner's original start map and context before using it for the paired owner comparison.

For the finite owner-style synthetic cases, pause, place a single activation dab at approximately `(64,48)`, and verify the captured native request has crop origin `(0,0)` and activation `[64,48]`. Use seed 605, two reciprocal rounds, interface reach 13, border 4, balanced orientation, optional negotiation ON, sharing ON, FRAME left / MOSAIC right, both SWARM-005 options ON, destruction 0 and independent parameter overrides disabled.

| Expression | Crop | Variation | Irregularity | Decoration | Branching | Environment affinity | Cohesion |
|---|---:|---:|---:|---:|---:|---:|---:|
| Industrial | 192×112 | 0.65 | 0.15 | **0** | 0.75 | 1.0 | 0.15 |
| Viaduct-like | 192×112 | 0.65 | 0.05 | 0.15 | 0.55 | 0.25 | 0.35 |
| Irregular Megastructure | 192×112 and 128×128 separately | 0.65 | 0.95 | 0.25 | 1.0 | 0.7 | 0.2 |

Industrial decoration 0 is the observed Workbench panel default. The native Industrial expression's decoration 0.35 is a separate development comparison, not an interchangeable owner control. Confirm values from the retained native input rather than a screenshot alone.

The known reciprocal positive uses a separate fresh 512×512 synthetic World, seed 4099, crop 128×96, origin 0,0, activation 64,48, **centered FRAME rectangle**, border 4, shared territory OFF, reach 13, two rounds, Viaduct-like profile and decoration 0. All three experimental controls are OFF. Its frozen native reference has 4001 material cells, eight qualified joints and zero unresolved obligations. The earlier seed 605 zero-joint transaction remains a separate Apply/Undo/Save regression and is not a reciprocal success.

## Owner exercises

Record source SHA, GPU/driver, world extent, the actual starting World, profile parameters, native material count, qualified joint count, remaining hard obligations, stop reason and work. Keep every unsuccessful, exhausted, invalid or cancelled attempt.

1. **Industrial 605 paired comparison.** Generate once with recovery OFF and once with recovery ON from the same source World and exact controls. The frozen blank synthetic V3 baseline has 6051 material cells, zero joints, two unresolved obligations and `fixed_point`. That is development reference evidence, not a substitute for the owner's approximately 6000-cell result. Retain both actual outcomes and native screenshots.
2. **Viaduct-like 605.** Repeat the matched comparison. The frozen synthetic V3 reference remains blocked with 6035 material cells, zero joints and one required obligation. If recovery remains infeasible, retain the negative and its diagnostics.
3. **Irregular Megastructure 605.** Run 192×112 and 128×128 independently. The 192×112 SWARM-005 both-ON synthetic reference is Apply-valid with 6026 cells and zero foreign joints through source-time local termination. A new result must be assessed by qualified foreign closure; local termination alone is not new reciprocal success. The owner's earlier 128×128 example with 4,889 cells and one joint example is a different physical case until its actual source context is captured.
4. **Seed4099 positive control.** Verify the inherited exact control above with recovery OFF, including its qualified foreign obligations. Preserve fixed-territory behaviour.
5. **Persistence for a native-authorized result.** Apply → inspect native materials → Undo → regenerate with identical controls → Apply → Save start → close the process completely → reopen the saved start in a fresh process. Compare the complete native material plane, not only its visual silhouette. Inspect saved ownership, paths and original receipts.
6. **Refusal and cancellation.** Cancel a running job, close the panel while running, exercise the 30-second child timeout, and retain the result of failed-child, stale-folder, corrupt-evidence and changed-World-source exercises. These actions must leave the uncommitted proposal absent from the live World. The source-matched automation exercises deterministic failed-child completion and long-running fixture processes; it does not deliberately crash the native World.

## Collect evidence from the actual World

Ordinary **Save start** preserves the authored starting setup and retained generation recipe or previously adopted baseline; it does **not** read a fresh live World plane. Preserve the accepted map and its `.swarm004.json` and `.swarm004-evidence.json` sidecars before further edits. These shared historical suffixes are intentional. The default Windows directory is `%APPDATA%\Godot\app_userdata\Cyber Sand Reference Sandbox\workbench`. Use distinct labels of 1–48 letters, digits, underscores or hyphens and retain Save warnings if optional evidence attachment fails. See the [Save implementation](../../godot/scripts/shared_workbench.gd) and [saved-map contract](../../godot/scripts/workbench_setup.gd).

Before **Apply or regenerate**, copy the settled `request.txt` and `result.json` from the corresponding `swarm004\job-<process-ID>-<serial>` directory beside `workbench` into a separate case/stage evidence folder. The wire request is a text protocol; the full JSON response also contains its native finite-crop input. Apply moves the response and removes the job; Undo, replacement Apply and exit can remove temporary accepted evidence. Capture every OFF/ON attempt separately, including unsuccessful previews. The [native job lifecycle](../../godot/scripts/workbench_reciprocal_panel.gd) owns this cleanup.

Complete **Apply → Undo → regenerate → Apply → Save** before **Flatten / Bake History…**. Flatten captures the actual native material plane but adopts a new authoring baseline and clears earlier Undo/Redo history. After the lifecycle, use Flatten followed by Save under a separate `…-after-native` label. Close the process, reopen the accepted authored map while paused, then take a fresh Flatten + Save under `…-reopened-native`. Compare the validated uint16 material payloads, not whole-file hashes or screenshots. A flattened file is binary despite its `.json` suffix; its plane is the last explicit capture, so later authored overlays must be accounted for. A full before-plane capture requires a separate, explicitly labeled adopted-baseline trial because Flatten changes authoring history; the untouched-history request supplies only its finite-crop before-context. See the [material baseline format and reader](../../godot/scripts/workbench_material_baseline.gd).

Cancellation, timeout, failed-child, malformed-output and stale-source cleanup can remove raw jobs immediately. Preserve available status, screenshots and files, and explicitly report missing raw evidence. The normal UI has no guaranteed export for these rapid failures or a dedicated whole-World plane-diff command. Automated `.le16` captures belong to the synthetic test and are not automatically produced during owner play.

## What automated qualification proves

The workflow builds both the Windows generator and native adapter from its exact checkout. It runs native suites and old/new transport controls and checks full source inputs and binary hashes. It seals the new package, executes the external launcher under Windows PowerShell 5, verifies direct and nested artifact extraction, challenges stale/corrupt/missing-sidecar cases, and invokes the actual sealed owner launcher without `-VerifyOnly` from paths containing spaces. That dispatch gate requires the bundled graphical Godot command, the Workbench entry marker, a visible responsive Workbench window sustained for ten seconds, and an original window screenshot. A private Windows Job owns the launcher before execution and retires only that test process tree; logs, process identities, hashes and the empty-job cleanup receipt are retained. Separate visible steps then qualify every native graphical exercise from a fresh pristine-package extraction and profile, followed by the actual graphical Main scene from source. The qualified owner upload requires all three gates.

The dispatch report explicitly versions its startup diagnostic policy. Only the exact pinned Godot 4.7 WASAPI error-and-stack sequence followed by its explicit Dummy-audio fallback in the same log and boot is recorded as recovered audio initialization. The raw error lines remain in the report and logs. An incomplete matching prefix gets at most two seconds to finish flushing and cannot authorize success; other errors remain fatal. This observer classification does not change the owner's audio setting or waive graphical stability, source hashes, native authority or cleanup checks. The earlier c313 dispatch remains a retained failed run under its original policy.

Graphical exercises dispatch actual UI input, retain full-window PNGs, save exact native request/response files and native material crop PNGs, compare full native World planes, and require a separate process for reopening. A negative native construction may pass its **disabled-Apply/unchanged-World exercise**; it remains a negative construction outcome in the report. Native counts, stop reasons and work are recorded separately from GUI test pass/fail.

Native preflight memory or input refusal is displayed as a nonauthorizing diagnostic with its original reason. The exact request and raw response remain in the shown job directory; Apply stays disabled and no geometry or missing source mask is invented. Ordinary proposals still require complete source masks, work receipts and native validation.

The inherited SWARM-005 run 44854238228 at 8ec6d3c passed source transaction, seed 4099, IrregularV3 Apply/reopen and negative ViaductV3 preview exercises, but its final lifecycle startup timed out after 60 seconds. Its pristine-package stage did not qualify. Those failed receipts remain historical. The new test records startup state and a 120-second watchdog; that change is not itself proof that the underlying startup delay is resolved.

Windows CI generally uses a Microsoft software/virtual graphics device. **Automated Windows qualification is not physical owner NVIDIA acceptance.** Owner acceptance remains pending until these exercises run on the actual hardware and actual World. All programme PRs remain Draft/HOLD; the owner must explicitly authorize any later Ready, merge or promotion.

## Evidence locations and interpretation

The workflow produces build evidence, a Windows-runtime custody artifact, source/pristine graphical evidence, launcher admission logs and the sealed owner artifact. In graphical evidence, each example records its native outcome separately; positive cases additionally contain applied/undone/saved/reopened screenshots and a complete `expected-native.le16` material plane. `initial-request.txt` / `initial-result.json` retain the actual native transport. Positive regeneration retains another exact request/result pair. Native-pixel crop PNGs come directly from the decoded native material cells.

The SWARM-005 preregistered holdout in [#698](https://github.com/techrote/cybersand/issues/698) is revealed development evidence. These GUI cases and transport examples are also declared development controls. They are not the separately frozen SWARM-006 unseen corpus, and no post-reveal tuning may be relabeled as holdout validation.
