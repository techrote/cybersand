# Windows recovery evaluator — independent source review

**Reviewer:** Specialist B, presentation and engine integration.  
**Reviewed repair:** `7491b1699f3db44d059692e77cef8ca4b9307bf1`.  
**Disposition:** reviewed source seams pass; actual extracted Windows commands,
authoring/reopen, collector and physical owner acceptance remain unexecuted by
this reviewer.

The review covered `tools/pubpres_recovery_windows/recovery_policy.py`,
`Start-PUBPRES-Final.ps1` and `owner_start.gd`, followed by the changed actual
authoring/reopen readback and extraction adversaries. The old c2 evaluator and
frozen owner tooling remain separate and unchanged.

## Findings and resulting repairs

The first draft allowed the Python correctness preflight to accept explicit
retained native input reuse, while the inherited package/runtime reader required
the original native build source and dependency builder source to equal the new
application. That is an inconsistent delivery contract. The repair explicitly
requires a fresh native `build_commit` and dependency `builder_commit` at the
resulting application and refuses a reuse binding for this owner delivery path.
Both fields are actually supplied by the original runtime validator. Original
build provenance is preserved rather than relabeled. Local development reuse
remains separately qualified under its additive input-equivalence contract.

The first draft's command argument validator still allowed Selected mode to
choose the older EGL/Separate renderer or three image slots when Water was off,
although the declared architecture and qualification were Stock Safe with two
slots. The repair requires **Stock / Safe / Full two slots** for both Selected
and Fallback modes and refuses optional old-engine packaging. Water selection
is explicit and source-pinned, with an actual native graphical prerequisite;
atomic submission, bounded lookahead, material-step coalescing and sample-idle
experiments remain disabled. No unqualified architecture is labeled selected.

The startup receipt already observed `OS.get_user_data_dir()`, but the launcher
did not compare it with the intended isolated profile. The repair checks the
actual absolute directory against the selected run's
`profile/APPDATA/godot/app_userdata/Cyber Sand Reference Sandbox`, observes the
application name and disabled custom-user-directory policy, and performs the
same direct directory check during authoring and fresh-process reopen. The
Windows comparison uses canonical paths and case-insensitive equality. An
extracted-package wrong-profile adversary was added by the qualification
specialist. These are stronger identity checks, not a change to save semantics.

## Source properties retained

The persistent profile name includes application source, package manifest,
source role, renderer, slot count, selected/fallback mode and representative
scene. An exclusive lock prevents overlapping use. The launcher verifies exact
source/runtime inventories, actual process ID, executable/native/Rapier hashes,
renderer ownership, ordinary publication policy and explicit recovery readback.
The one-time startup observer disconnects after its receipt; ordinary play does
not retain a diagnostic polling loop. Frozen control and fallback use their
explicit Water-off selection.

The reviewed startup receipt describes an installed native World and uploaded
material. It does not claim a GPU fence, monitor scanout, physical input latency
or sustained playability. The separate graphical/authoring/package gates must
still establish their stated behaviors on the shipped bytes.

## Remaining execution gates

This source review found no remaining blocker in the repaired selection,
profile or native-provenance seams. It is not actual Windows execution.
Resulting-source native/Windows correctness, all shipped commands from a
pristine extracted archive, authoring and fresh-process reopen, shutdown,
collector behavior and independent archive verification remain required.
Performance selection and physical Windows 11/NVIDIA acceptance are separate
gates. Draft/HOLD and no default promotion remain in force.
