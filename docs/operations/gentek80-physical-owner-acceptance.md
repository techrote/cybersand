---
title: GENTEK-WINDOWS-FINAL-B physical owner acceptance
status: Draft
document-kind: guide
scope: Source-bound portable Windows evaluator, physical acceptance and no-upload evidence export
canonical-for: [gentek-windows-final-owner-acceptance]
last-reviewed: 2026-11-22
related-documents: [gentek80-evaluation.md, architectural-generator-playtest.md]
---

# GENTEK-WINDOWS-FINAL-B — physical owner acceptance

This guide **supplements**, rather than replaces, [the current 80-Gentek catalogue and Test It procedure](gentek80-evaluation.md). The historical #673 candidate is preserved. PR #684's Windows ZIP is a qualified historical-source artifact, **not** automatically a current-main build. The acceptance owner must pin the **exact** source, original archive hash and build evidence of the chosen release.

## Source and archive trust

The verifier is committed at tools/acceptance/gentek80_owner.ps1; its companion Verify and Open Workbench.cmd is staged by the existing source-aware packaging tool. The final candidate also includes this complete guide as **OWNER-ACCEPTANCE.md**, alongside the existing **READ-ME.md** catalogue guide. The tool runs under Windows PowerShell 5.1 and requires no development checkout, separate Python/Godot/compiler installation, admin rights, network access or machine-global configuration changes.

**Always obtain the 64-digit expected ZIP SHA-256 from a separate trusted handoff.** A hash embedded inside the same untrusted ZIP cannot authenticate that ZIP. Provide the exact 40-digit Git commit in -ExpectedSource. The owner verifier compares original ZIP hash, archive member safety, complete extracted SHA-256 inventory, source/build identity, Godot executable hashes, native GDExtension, Rapier, Visual C++ runtime and unexpected files. It refuses inconsistent manifests, missing payload, ZipSlip, ZIP case collisions and manifest source mismatches. **Trust boundary:** a party able to rewrite both an extracted binary and the manifest can pass self-consistency checks while preserving the apparent source SHA. Neither an embedded manifest nor a bundled launcher authenticates itself. Obtain the independently published `*.zip.manifest.sha256` for this exact build and supply `-ExpectedManifestSha256` to subsequent VerifyPayload/Launch calls, or re-extract from the separately authenticated ZIP. The externally obtained ZIP digest remains the primary trust anchor.

The portable ZIP includes four original, same-source-qualified examples in examples/gentek80-final/: two editable five-style project JSON files, two corresponding named authored starting-map JSON files, plus a complete import guide. These bytes are admitted only after both original graphical native author/reopen phases pass, then individually recorded in candidate-manifest.json with original receipt SHA-256 and per-file hashes. Open the projects via the Architectural Generator's **Load** file chooser. To use a named starting map, use the checked launcher's source/native-keyed user profile and copy the appropriate setup-*.json into its Roaming/Godot/app_userdata/Cyber Sand Reference Sandbox/workbench folder without overwriting existing owner files; then load that name from ordinary Workbench. The map records an authored start and two ordered paint/erase edits; it is not evolved physics state.

The project can regenerate cache files inside godot/.godot/; this is the only expected unlisted mutable project subtree. Capture results **outside** the package. The familiar Open Workbench.cmd name is retained for backwards compatibility, but in **new** deliveries it delegates to Verify and Open Workbench.cmd. Both entry points now fail closed before import or GUI startup; previously published historical ZIPs retain their historical launcher behavior. The one-click launcher checks the **internal** manifest, so only use it after the original ZIP has been separately authenticated and the extracted directory has remained under your custody; the explicit PowerShell `Launch` command below additionally verifies the independently supplied manifest digest.

## Verify, extract and run

Use a trusted, separately obtained copy of gentek80_owner.ps1, or the script in an already authenticated archive. Replace the placeholders with the exact published source and ZIP digest. Example (PowerShell):

~~~powershell
$kit = 'C:\OwnerKit\gentek80_owner.ps1'
$archive = 'C:\Downloads\CyberSand-Gentek80-Windows-SOURCE.zip'
$sha = 'PASTE_64_DIGIT_PUBLISHED_SHA256'
$source = 'PASTE_40_DIGIT_PUBLISHED_SOURCE_SHA'
$manifestSha = 'PASTE_64_DIGIT_INDEPENDENT_MANIFEST_SHA256'

powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action VerifyArchive -ArchivePath $archive -ExpectedArchiveSha256 $sha
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action Extract -ArchivePath $archive -ExpectedArchiveSha256 $sha -ExpectedSource $source -ExpectedManifestSha256 $manifestSha -Destination 'D:\Gentek test (外部)\nested\candidate'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action VerifyPayload -PackagePath 'D:\Gentek test (外部)\nested\candidate' -ExpectedSource $source -ExpectedManifestSha256 $manifestSha
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action Launch -PackagePath 'D:\Gentek test (外部)\nested\candidate' -ExpectedSource $source -ExpectedManifestSha256 $manifestSha
~~~

Extraction **must target a new directory**. The verifier stages the entire payload in a random sibling on the same destination volume and moves it atomically into place only after verifying hashes, files, source and native build identity. A failed extraction cleans its staging tree and never leaves a partial final installation. Launch uses only the bundled pinned Godot 4.7 GUI/console, verifies again after import, opens the ordinary Shared Workbench and waits for its process. It **never** kills other Godot processes or silently invokes a system-installed engine. Close all Godot processes associated with the extracted package by inspecting executable paths in Task Manager before the fresh-process replay. Do not kill unrelated Godot instances.

Repeat clean extraction and tamper-refusal tests under spaces, parentheses, Unicode, nested directories and a non-default user-profile path. Intentionally corrupt only *copies* of the archive/package (missing Rapier, changed executable/DLL, truncated ZIP, altered manifest/source, unlisted GDScript, ZIP traversal). Keep exact failure messages and do not bypass a refusal with the legacy launcher. tools/acceptance/tests/test_gentek80_owner.py contains strictly synthetic Windows admission adversaries; they **do not prove actual generator quality or physical GUI interaction**.

The engine process inherits an isolated, persistent owner profile under the current user's Local AppData, keyed by the **source SHA and native runtime SHA**. This changes only the launched process environment, not machine-global settings. Fresh launches of the same verified ZIP reuse that profile; unrelated CyberSand saves are not read or changed. The source revision variable is explicitly propagated to the Godot process.

## Owner graphical acceptance

Run the actual candidate on **Windows 11 with a local NVIDIA graphics driver and physical keyboard/mouse**. Record OS build, GPU, graphics driver, renderer and DPI/scaling. Hosted Windows Server 2022/ANGLE, headless, RDP software rendering and simulated input are *not* equivalent to this gate.

Use the standard [80-Gentek Test It instructions](gentek80-evaluation.md) alongside this additional explicit checklist. Check all eight advanced showcases and the six repaired CLASSIC structures (Ring Pier, Tripod Frame, Cascade Terrace, Scalloped Vault, Suspended Deck and Buttress Wall). Perform individual generation, preview, Stop/cancellation, native install, paint/erase, reseed and identical-seed restoration, meaningful Room/bay/floor/wall changes, invalid-input refusal and existing legacy regression examples.

Create **two different five-style projects**, with one signed negative-coordinate origin. Record all ten module selections, both seeds, exact geometry/material parameters, the selected Room/bay variance and project names. Save the **two editable projects and two named starting maps**, not simply screenshots. Close *every* packaged engine/editor process, launch a genuinely new app process, reopen both projects and both named starts, compare original identities/parameters and inspect the restored painted material. Preserve genuine screenshots that clearly identify case, software build, original source and result.

Manual physical judgments remain explicit **PASS, FAIL or SKIP**; a missing observation is never automated into a PASS. Record natural gameplay feel, freezing/stalls, preview stability and generator legibility without deleting negative results.

For quantitative performance, measure generation/preview/install wall times and sample real frame intervals with a declared capture tool. The optional -FrameIntervalsCsv expects 100+ positive frame_ms values; it reports nearest-rank p50/p95/p99 and worst interval **from the owner-supplied CSV**. The harness does not measure frames itself, and missing measurements remain **NOT RUN**.

## Export evidence locally, with no uploads

Run these commands in PowerShell **after** a full physical acceptance session:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action NewChecklist -ResultsDirectory 'D:\GentekAcceptance\form'

# Edit all 20 entries in owner-decisions.json:
# Set decision to PASS, FAIL or SKIP and record real notes, two five-style projects and two saved maps.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $kit -Action Collect -PackagePath 'D:\Gentek test (外部)\nested\candidate' -ExpectedSource $source -ExpectedManifestSha256 $manifestSha -ArchivePath $archive -ExpectedArchiveSha256 $sha -DecisionsPath 'D:\GentekAcceptance\form\owner-decisions.json' -ResultsDirectory 'D:\GentekAcceptance\result-001' -Renderer 'OWNER OBSERVED RENDERER' -EvidenceFiles @('D:\Captures\showcase.png','D:\Captures\reopened-map.png','D:\Logs\workbench.log')
~~~

Optional, explicitly supplied profiler evidence: -FrameIntervalsCsv 'D:\Captures\real-frames.csv' -FrameCaptureTool 'tool and version'.

The output includes a structured gentek80-owner-report.json, OS/driver/DPI information and SHA-256 hashes of *only the evidence files explicitly selected*. An independent manifest SHA-256 pin is required for OWNER-PASS-RECORDED; if you also supply the original ZIP to Collect, supply its independently authenticated -ExpectedArchiveSha256. Missing external pins force INCOMPLETE; mismatched pins or an original ZIP whose manifest differs from the installed payload force PACKAGE-REJECTED. A hash copied from inside the package is not independent authentication. It performs no uploads, credentials collection, desktop capture, synthetic screenshots or mouse/keyboard trace fabrication. Inspect and redact selected logs before sharing. The report distinguishes OWNER-PASS-RECORDED, OWNER-FAILED, INCOMPLETE and PACKAGE-REJECTED. Even all-PASS owner declarations remain **INCOMPLETE** when the two distinct five-style projects, their recorded negative origin, two named maps, real screenshot, renderer, original frame samples or physical Windows 11/NVIDIA evidence are missing. Owner statements remain subject to independent review.

## Outstanding gates

| Gate | Requirement | Initial status |
| --- | --- | --- |
| Exact current-source Windows package | Newly produced native library, Godot 4.7, Rapier, full inventory, SHA manifest, same-source graphical replay | Requires current branch CI |
| Eight showcase / six repair / 80 distinct output suite | Actual Workbench, native project material identity, saved map fresh-process reopening and original frames | Requires current branch CI |
| Two advanced five-style Workbench compositions | Two independent editable project files, two named starting maps, paint/erase, negative origin, source/native identity, genuine frames and fresh-process replay, on source tree and pristine ZIP | Requires new exact-source Windows CI; not physical acceptance |
| Adversarial archive and process handling | Windows PowerShell synthetic corruptions, safe extraction and no global process termination | Requires Windows CI |
| Local owner Windows 11/NVIDIA performance and physical input | Owner's genuine decisions, screenshots, GPU/renderer/DPI, measured stalls | **NOT RUN** |
| Integrator/owner merge gate | Review exact source and runtime, accept outstanding failures, explicit merge authority | **HOLD** |

This guide does not itself grant merge, auto-merge or Ready promotion authority.
