# Independent review of the owner walkthrough and actual Windows Lab

**Specialist B · 2026-11-26 · docs-only review · Draft/HOLD.** The available Lab image is an actual Windows capture from application `a57aaeeabfb5bde47276a6e2981ea80823759730`, not the repaired delivery candidate. This review compares visible controls in that image with the owner guide and the relevant source at `fd0830abcfadd9ae19162e5677943bb131223e59`. It transfers no shader-aesthetic or physical-performance verdict between those applications.

## Evidence identity and observation scope

| Item | Identity or scope |
| --- | --- |
| Captured application | `a57aaeeabfb5bde47276a6e2981ea80823759730` |
| Captured source tree | `f161fad574bc7f8233b159406f2b7db54959be6c` |
| Original Windows campaign manifest SHA-256 | `da13e1b88e4ac1254157cfe445b32a9cc7b451f8d4671642612b96be0d97d461` |
| Original capture | `industrial-underworks/install/optics-lab.png` |
| Original capture SHA-256 | `a1f80e4ff529149355f6a2ff0f6ecc23b02ec6ed8079fa3d93046f36ba3b5943` |
| Actual Lab framebuffer | 817 × 607 pixels |
| Recorded requested Workbench window | 1600 × 1000 pixels; this is not the Lab image size |
| Other original visually inspected | `industrial-underworks/install/profile-classic.png`, showing the ordinary Workbench name/Save/Load row |
| Original Workbench capture SHA-256 | `467bd6ed2d9052c2bfdacbfee0f209b14edfed7b6a6419e1c7d07ce511cf2b4b` |
| Guide/application checked in source | `fd0830abcfadd9ae19162e5677943bb131223e59` / `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499` |
| Frozen package-source guide SHA-256 | `1b8a1f993213ed4a8ae46b7bef7da5efd3a50444c786a3d40cadbb263aba2078` |
| Specialist correction at `f4cca346` SHA-256 | `788faa6a05865bb7f7003a16ccd6fab30561c2c9b60f850ef31690338aee90dc` |
| Integrated archive guide SHA-256 | `598db89ecf975791d5ca2d4a2ca593e9754fbb4c5bbec46419faa024dd0a102f` |

The original Lab image's hash agrees with its report and file ledger. Its capture scope explicitly identifies an actual separate Strata window, not a matched world capture. The screenshot shows the top part of a scrollable tab; it does not prove that every advanced control was reachable or legible through actual user interaction. The existing source-bound qualification reports carry their own interaction scope. This specialist's work here is image inspection and source review.

## What the image supports

The native edit target is prominent in a separate cyan line. That distinction makes the independence of optical selection visible before adjusting a parameter. The profile menu, Classic action, Bypass toggle, temporary physical-Play assistance, wipe and overall strength appear above the start of the focus section. The panel has a visible right-hand scrollbar, no apparent horizontal clipping in the inspected top view, and clear section spacing.

The selected named preset appears in the wide dropdown, followed by a description identifying editable scene values. The dropdown has no separate visible "Profile" caption, so a new owner benefits from its position being stated in the guide. The actual image has **Fixed Play focus** selected. The following focal-plane picker and manual distance control are disabled, which is consistent with their mode-specific roles.

The lower sections are outside this capture. At this window size, the walkthrough must explain scrolling before asking an owner to find quality, advanced settings, per-plane composition or named-preset saving. A requested desktop/window size of 1600 × 1000 does not make the separate Lab window's contents simultaneously visible.

The ordinary Workbench capture visibly places a map-name field before **Save start [Ctrl+S]** and **Load start**. Its long scene name is horizontally constrained. The label and position are usable when explained, but a reader should not expect a file browser to choose a saved scene.

## Concrete gaps and corrections

| Finding | Why it matters | Corrected instruction |
| --- | --- | --- |
| "Return to Stack" follows a checked Solo control | Stack and Solo are independent fields. Leaving Solo active shows only Play and can make optical adjustments appear ineffective. | Uncheck Solo, then select **Stack · all visible planes**. |
| The opening scene-load step says only "Save first" | Two different save operations now exist. Saving an optical preset alone does not preserve the native scene that loading replaces. | Use ordinary **Save start [Ctrl+S]** before replacing a scene. |
| The guide says to choose a profile without identifying the unlabeled dropdown | The visible selected item may be a custom name, so the control's purpose is not self-evident. | Use the wide dropdown immediately below **Enable optical processing**. |
| The guide moves from manual distance to choosing a focal plane without changing mode explicitly | The focal-plane picker remains disabled in manual mode. | Choose **Selected focal plane**, then select the plane in the next dropdown. |
| Advanced and named-preset controls are described without a scroll route | The actual top view does not show those sections. | Use the tab scrollbar; name **Advanced optical experiments**, **Advanced plane controls** and **Named custom presets** explicitly. |
| Fresh reopen says only to load the saved start | Load reads the current map-name field and does not open a selection dialog. A different default name can load the wrong start or report no saved file. | Re-enter the exact scene name beside **Save start [Ctrl+S]**, then click **Load start**. |
| "Release" describes the temporary clarity control | It is a toggle, not a press-and-hold action. | Switch **Show physical Play** on, then switch it off. |

The corrected canonical [owner walkthrough](../../operations/strata-optics-evaluation.md) and short [owner addendum](OWNER-GUIDE-ADDENDUM.md) preserve the same application features and clarify those actions. They are kept outside the frozen package source; the original package guide remains identifiable by its hash. The final archive identity must be reported separately from the application identity.

## Source checks that establish the navigation findings

The same three relevant source files are byte-identical between the captured `a57aaeea` application and repaired `fd0830ab` candidate:

| Source | SHA-256 |
| --- | --- |
| `godot/scripts/depth/workbench_strata_panel.gd` | `77c72e4e62127d40bfe234b9973a781eb8dcdb22174123da1afdb07a2aca5870` |
| `godot/scripts/depth/workbench_layer_owner.gd` | `168cea01f60803caaad88cac8eaebdef8ca1c9140960d79ff6314d9a1fac01ed` |
| `godot/scripts/shared_workbench.gd` | `089e5ffeb44d3917115462db9ac0d300cd23d6060638178043ccfbc81257f5ae` |

The panel patches only `mode` when Stack is selected and only `solo` when the Solo checkbox changes. The owner applies only supplied presentation keys. `save_setup()` and `load_setup()` use the same map-name text; load calls `StrataDocument.read_named()` rather than a file dialog. These are source checks, not new mouse-driven tests.

The optical panel differs between the two sources: its captured version hashes to `854e26e7293782aee2410adef592b2fd40ef6afc1db3d363569cf9441af14afd`, and the repaired-source version to `192ff99cbb5c3e287e4599115f43ac5615ca16e32873a40050fa223d9a9558b7`. The current source still disables its focal-plane picker unless focus mode is `plane`, and its section labels match the corrected guide. This review does not claim that the old image displays every later tooltip or control change.

## Disposition and remaining checks

**Documentation correction recommended and prepared; no application change.** The inspected top-level grouping is understandable, with clear native-edit authority and immediate comparison controls. The most consequential issue was the incomplete Solo exit instruction. Exact names and scroll routes substantially improve the save/reopen path without requiring a new UI.

Actual final-source graphical captures, the complete lower-panel interaction sequence, keyboard navigation, different desktop scaling, and ordinary physical owner use remain separate checks. An image of a readable top section is insufficient to claim full UI qualification. The owner addendum openly preserves the frozen-guide limitation while providing concrete usable instructions.

Lead integration note: the integrated guide also specifies actor rotation and explicitly states that this Workbench has no rotated-camera control. The independent review above retains the specialist correction identity; the second digest identifies the integrated guide.
