# CyberSand SWARM-006 — owner acceptance

**Draft/HOLD. This is an isolated evaluator for a subsequent owner decision.**

Candidate source: `428f842034a1f80d593bcc6bb32af2dd99cd0105`  
Tree: `cb1f4fdaf7b9cb487e850f1702a4f9085d0cb300`  
PR: [#716](https://github.com/techrote/cybersand/pull/716)  
Accepted foundation: `846fe0533b3170e7b01f690518da49fc40cc24d1`. The separate SWARM-004/005 accepted-main merge remains pending.

The package contains the current final-composition inspector, pending-input and busy-editing repairs. The old sealed SWARM-006 evaluator does not contain those corrections. Use this package's own launcher and sidecar.

## Verify and open the evaluator

Keep these three files together:

- `CyberSand-SWARM006-Draft-HOLD-Windows-428f842034a1.zip`
- `CyberSand-SWARM006-Draft-HOLD-Windows-428f842034a1.zip.sha256`
- `CyberSand-SWARM006-Windows-Owner-Acceptance.ps1`

ZIP SHA-256: `2462275ad0093097b3c80b6bfe6fb543780b2b53cf3ee2ec56829c4341c7f015`  
Launcher SHA-256: `66934e384542531747e9d8d0e9fd1f6e2d971c5a96ac05b4ec3c2e273a21f4fe`  
Bundled reciprocal CLI SHA-256: `f3f26a6c76238fb3cef37701f25d76eff709b5f77ddb71a09ee58a72a4c5257d`  
Bundled GDExtension SHA-256: `944ba3563653a0e774478bb6e1b1a9f7beedfb45111124dde885335e7f024d88`

From PowerShell in that directory, choose a destination that does not exist:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-SWARM006-Windows-Owner-Acceptance.ps1 -Archive .\CyberSand-SWARM006-Draft-HOLD-Windows-428f842034a1.zip -Destination C:\CyberSand-SWARM006-428f8420
```

Add `-VerifyOnly` to verify and extract without launching. After extraction, `Open Workbench.cmd` opens the bundled application and uses its bundled native generator manifest. The launcher verifies the archive, complete manifest, source and native identities. If it refuses, retain the error and use a fresh destination; a refused or altered package must not be adopted as qualified.

This does not replace the ordinary CyberSand installation. **The launcher does not isolate the user profile:** this executable can see the existing Cyber Sand Reference Sandbox saves. Preserve original saved files and choose a unique review save name, such as `swarm006-428f8420-review`, before creating or saving the test World. Record your Windows version, NVIDIA model and driver version, and retain the package manifest with your observations. The hosted qualification executes real Windows graphics through its recorded software/ANGLE environment; it does not substitute for this physical hardware check.

## Reproduce the bounded synthetic comparison

In **Details**, choose the unique review save name, set **New width** and **height** to 2048, and use **New blank**. Keep **Play/Pause paused** through Generate, Apply, Undo, regeneration and Save. This creates the **blank synthetic 2048×2048 World** used by the test. Open **Reciprocal assembly…**. Before changing settings, confirm the two SWARM-005 controls and **Bounded reciprocal recovery (SWARM-006)** start OFF.

The automated Industrial comparison uses this exact recipe:

| Control | Value |
| --- | --- |
| Expression | Industrial |
| Seed / rounds | 605 / 2 |
| Width / height | 192 / 112 |
| Crop origin | (0, 0) |
| Activation | One sampled point at (64, 48) |
| Ownership | FRAME left / MOSAIC right |
| Allow negotiated territory sharing | ON |
| Interface reach / clear border | 13 / 4 |
| Orientation / optional negotiation | Balanced / ON |
| Source-feasible terminal parts | ON |
| Source-bound MOSAIC receptors | ON |
| Complexity / variation; Irregularity; Decoration | 0.65 / 0.15 / 0 (Decoration is native `clutter`) |
| Destruction / branching | 0 / 0.75 |
| Environment affinity / cohesion | 1 / 0.15 |
| Independent FRAMEWEAVER/MOSAIC controls | Both OFF, so both Genteks use the shared values above |
| Recovery comparison | Generate OFF, then generate ON against the same unchanged World |

The exact crop, activation and World matter. A freehand stroke with several sampled points is a different request; record it as such. Compare the actual native status, Apply permission, material map, qualified joints and unresolved obligations with the final qualification report. Preview must leave every World cell unchanged. A blocked or exhausted native result is retained evidence and must never Apply.

## Check inspection and input authority

- With a valid final construction, select **Final composition**. Joints, Unresolved, Clearance and Revisions must be enabled. Inspect each and pick actual native cells.
- Select each provisional proposal round. The view and cell details must identify that exact native round; final-only layers remain restricted. Return to Final composition. Generate, load and reset must select or clear the appropriate final view without retaining stale picks.
- With an applicable preview, type a new seed without committing the field. The old preview/Apply authority must retire immediately. For the independent-field test, enable Independent FRAMEWEAVER or MOSAIC controls, regenerate an applicable preview, then type a numeric value without committing it. Enabling the independent toggle itself already invalidates the prior preview. Generate must use the typed value.
- Start a **Protect passage** gesture. The old authority must retire on the initial press, before its source mask changes.
- During native generation or retiring preparation, try ordinary Paint and World Undo/Redo. For the keyboard test, leave text fields unfocused so the shortcuts target World history. They must refuse without changing World/history, including when territory mode is OFF or the reciprocal panel is hidden. After work settles, ordinary Paint and Undo/Redo must work again.

## Check the transaction and reopen

The input checks deliberately change settings, marks and possibly World. Before this transaction comparison, use **New blank** again, restore the exact Industrial table values with independent toggles OFF, use **Clear marks**, repaint the single declared activation and Generate with Recovery ON. New blank alone does not clear the panel's activation/protected marks. Keep the World paused and retain the unique review save name.

- For a complete, natively authorized proposal, use the reciprocal panel's **Apply construction**, **Undo construction**, regenerate, **Apply construction**, then **Save start** under the unique review name. Ordinary World Undo/Redo is the separate busy-editing test above.
- Exit the application fully. Open it in a fresh process, select **Details**, enter the same review save name and use **Load start**. Then open **Reciprocal assembly… → Inspect saved evidence**; Load start alone does not populate that inspector. Verify materials, ownership/joint inspection and saved composition against the pre-exit result.
- Save start records authored state. **Flatten/Bake History** is a separate action that adopts a baseline and clears Undo/Redo; it is not interchangeable with saving the current evolved simulation.
- Change World or recipe settings after generating. The previous proposal must refuse Apply and leave the changed World intact. The automatic suite separately challenges altered native evidence and stale executable identities; an owner failure in any of these paths should include the exact error and unchanged/changed state observed.
- A genuine older saved construction may be inspected read-only. Its historical native evidence must not gain fresh Apply authority. Inspect does not restore editable recipe controls or activation marks: set the desired current recipe, paint a fresh activation and Generate to obtain a new authorization.

## Record the acceptance decision

Retain the exact package name/hash, hardware/driver information, native status, source and executable identities, screenshots of all four final layers and any failure. Include the saved setup only if you choose to supply it, keeping an untouched original copy.

The previous owner comparison used a blank 192×112 crop at (800,400): six OFF results were blocked, six ON results were complete, with seven qualified joint witnesses but **zero original FOREIGN_JOINED**. That observation does not prove repair of existing owner-created foreign-required sockets. The synthetic comparison above does not make that claim either. Exact original-owner-world reproduction remains a distinct gate if the original input is unavailable.

Remaining acceptance gates are the actual SWARM-004/005 accepted-main reconciliation and renewed affected qualification, physical Windows/NVIDIA acceptance, and a subsequent explicit owner merge decision. PR #716 remains **Draft/HOLD**. No merge, Ready promotion, auto-merge or production-default promotion follows from running this evaluator.
