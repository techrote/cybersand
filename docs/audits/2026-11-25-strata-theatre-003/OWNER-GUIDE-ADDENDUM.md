# Strata Optics Lab — navigation and saving addendum

This addendum clarifies the walkthrough included in the frozen application source **`fd0830abcfadd9ae19162e5677943bb131223e59`**, tree **`fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499`**. Check `evaluation-manifest.json` for the application actually in your package. These are documentation corrections; they do not change that application's code, native geometry, evaluator provenance or recorded qualification results.

The corrected archive walkthrough is [Strata Optics Lab owner evaluation](../../operations/strata-optics-evaluation.md). Its identity and the frozen guide's identity are recorded in the accompanying [independent guide review](b-owner-guide-review.md). The final decision packet identifies the documentation archive separately from the application. Preserve the package's original guide and use these clarified steps alongside it.

## Return from physical inspection to the whole scene

Open **Strata Theatre… → Layers**. Choose **Play · actors and collision**, then check **Solo** to inspect physical geometry.

To see the optical effects across all layers afterwards, **uncheck Solo**, then choose **Stack · all visible planes**. Stack and Solo are separate controls. Choosing Stack alone does not clear Solo. If only physical geometry is visible, check this before changing the optical strength.

## Find profiles and controls below the fold

Open the **Optics** tab. The profile menu is the wide dropdown immediately below **Enable optical processing**. Select a built-in profile there. **Bypass / before** temporarily restores the reference appearance while keeping your optical settings; the **Classic** button changes the authored profile to Classic.

Use the Optics tab's right-hand scrollbar or mouse wheel to reach **Depth and atmosphere**, **Per-plane composition** and **Named custom presets**. Switch on **Advanced optical experiments** to reveal the three filter methods and individual effect controls. Switch on **Advanced plane controls** to reveal light response, optical opacity, parallax response and tint. Move or resize the Strata window when comparing the controls with the world.

For a particular focal plane, first set the focus mode to **Selected focal plane**, then choose **Rear architecture**, **Atmosphere / effects** or **Distant background** in the next dropdown. That dropdown is disabled in the other focus modes. **Manual optical distance** instead enables the **Focus distance** slider. None of these optical selections changes the native edit target.

## Save an optical preset and save a complete scene

An optical preset and an authored scene have independent names and save actions.

1. In the Optics tab, scroll to **Named custom presets**. Enter a name in **Name for this optical composition**, then click **Save / duplicate as named preset**. This keeps the editable optical configuration for reuse.
2. Move or close the Strata window. In the ordinary Workbench, find the map-name field immediately beside **Save start [Ctrl+S]**. Enter a scene name such as `optics-underworks`, then click **Save start [Ctrl+S]**. This keeps the four authored layouts together with their optical settings.
3. Exit completely and reopen **Open Workbench.cmd**. Enter **the same scene name** in the Workbench's map-name field, then click **Load start**. Load start reads that name; it does not open a file-selection dialog.

After reopening, inspect the authored layouts and optical values. Bypass, temporary clarity assistance, wipe and inspection focus do not belong to the saved artistic state. Quality is an application preference. Save start records the authored scene rather than evolved simulation state or native Undo stacks.

The older actual Windows Lab capture used to check these navigation instructions belongs to source `a57aaeeabfb5bde47276a6e2981ea80823759730`. It does not establish the repaired shader's appearance or the final package's physical Windows 11/NVIDIA performance. Those observations remain separately identified in the final decision packet.
