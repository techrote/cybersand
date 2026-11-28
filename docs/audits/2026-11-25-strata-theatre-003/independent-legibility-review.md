---
title: Strata 003 independent gameplay legibility and authoring review
status: Current
document-kind: evidence
scope: Original graphical corpus critique, authority-focused UI review, native apparatus diagnostics and pending successor graphical adjudication
canonical-for: []
last-reviewed: 2026-11-25
related-documents: [qualification-registration.md, ../../systems/strata-workbench.md, ../../systems/strata-environments.md]
---

# Independent legibility and authoring review

This record separates inspection of the original Strata 002 application captures
from execution of the Strata 003 successor. Attractive screenshots and passing
headless controls cannot establish successor graphical or physical acceptance.

## Original corpus inspection

The five original `qualification/windows/<scene>/stack.png` captures came from
the immutable qualified evaluator for application
`934cc0c0eef70dad528155e9a92eebe25e2757eb`. The evaluator identity remains
`1a619b8b9c6af51529517f1609b457a7f25ed727deccbac8cd92269c7c23a547`.
These are real application images, not generated concept art.

| Scene | Useful existing hierarchy | Concrete potential ambiguity to retain in comparisons |
| --- | --- | --- |
| Orbital Terminal | Bright substantial floors and thin distant framing already separate many shapes | The long rear horizontal gantry crosses open gaps and resembles an alternate physical floor. It remains recognizable architecture worth preserving. |
| Neon Rain Arcology | Strong physical rooftop caps, large negative spaces and a coherent distant building pattern | The orange rear truss appears to connect a physical rooftop. The upper grey truss also reads as a plausible traversable bridge. Dense lit windows compete with the small actor at overview scale. |
| Industrial Underworks | The central turbine has a readable distant silhouette and the true platforms have bright thick caps | The orange lower truss can appear to be a floor. Similar hollow silver machinery frames and real platforms reuse a visual vocabulary. More darkening alone risks losing the turbine. |
| Abyss Foundry | Organic contours and sparse thick ledges create distinct negative space | The central orange gantry looks traversable; its disappearance in Play-only inspection is the relevant ground truth. Cave texture must remain legible rather than becoming an undifferentiated dark field. |
| Vertical Transfer Spine | Alternating bright side platforms give the shaft a clear rhythm | Repeated rear trusses cross the shaft and can appear to close it. The small actor depends heavily on the pilot label at the full-scene overview. |

The exact physical/decorative interpretation must be confirmed by the isolated
Play capture or actual native readback. These observations identify ambiguity;
they do not claim a measured human error rate. Independent A review identified
the same bridge/gantry risk in the actual isolated Play comparisons.

## Adversarial fixture

`strata_optics_fixtures.gd` creates a real 1024 × 768 native composition with
the same material ID in Play and decoration. It includes an aligned false
platform extension, a decorative stair and ladder, a rear-filled physical
passage, repeated high-frequency beams, a detailed actor background and native
Sand/Water. No isometric floor tops or extra physical World are introduced.

Eight declared points are checked against actual native material bytes. For
example, the false extension at `(350,214)` is Empty in Play and material 58 in
the rear plane; the apparently blocked passage at `(560,360)` has the same
distinction. The scene recipe is an authored challenge, not perceptual proof.
The full qualification also reads all native material cells before and after
optical changes and verifies the complete geometry is unchanged.

## Authoring review and repairs

The Lab remains a tab inside the ordinary Strata panel. Its controller interface
has no native World, camera or renderer ownership. The plane used to inspect
optical settings is explicitly independent from the native edit target. Play
accepts only an optical focus-anchor depth; its processing, brightness, blur,
opacity and parallax controls are disabled and backend-refused.

Actual-control tests cover pending numeric input during asynchronous refresh,
committing typed values before saving a preset, complete effect-switch patches,
custom preset selection and deletion fences, no recurring UI process, temporary
comparison state and separate application quality. Independent review corrected
the preset-name field to the store's 48-character limit and corrected the
aperture-like defocus description against the shader formula.

An optical opacity of zero leaves native edit permissions unchanged. The Lab
now prominently warns when the actual decorative edit target is optically
invisible, directing the author to Bypass or layer inspection. It does not
silently change editing authority. Layered presentation OFF also has explicit
guidance because changing optics while Strata is hidden cannot produce visible
depth. Wipe explains that its partial comparison temporarily shares Classic
parallax, avoiding a misleading coordinate comparison.

## Native diagnostics before graphical qualification

A development execution using pinned Godot
`4.7.stable.official.5b4e0cb0f` ran the integrated ordinary Workbench in explicitly
headless diagnostic mode. The challenge install passed 833 checks, and a
separate fresh process passed 317 reopen checks. Actual native readback,
Brush/Eraser viewport events, Undo/Redo/restoration on Background and Play,
custom optical persistence and decorative-owner teardown were exercised.
Both complete four-plane native hash sets were unchanged by optical changes.

These runs used the active integration working tree, not a frozen qualified
application. Their `source_revision` is deliberately
`development-diagnostic`. They do not provide framebuffer, scene-admission
performance, software-rendering or physical Windows/NVIDIA acceptance.
The complete source-pinned hosted campaign must supersede them as qualification.

The first progression diagnostic exposed a real apparatus error: assigning an
untyped empty Array to a dynamically accessed `Array[Dictionary]` field produced
Godot script errors while the process still returned zero. Its empty sample
records are rejected. The repair clears the existing typed arrays, requires
the complete sample population, rejects incomplete observation records and
checks that every actual completed Rapier tick is represented without gaps.
The independent Python campaign must also reject script-error logs. This failed
diagnostic remains a negative result; its wrapper check count is not a pass.

## Graphical and performance disposition

**Pending actual successor graphical execution and independent image review.**
The local display setup was blocked by a kernel socket permission failure;
headless tests do not substitute for it. Hosted graphical evidence must include
the exact Classic-return pixel witness, matched catalogue images, actual Optics
window, focus/assistance comparisons, boundary/alpha tests and the registered
live physical progression sample population.

Physical completion timestamps come from the existing hook immediately after
the real Rapier `complete_step`. Native publication observations can coalesce
native ticks and are explicitly not presented as individual native completion
intervals. The observer performs no additional native simulation or texture
capture. All timed samples start with a fresh authored scene and native Play
readback, and their optical warmup is physically paused. Capture/readback and
scene admission remain outside the timed window with separately recorded costs.

The unchanged 45-second scene-admission target and all five previous extracted
Windows misses remain in force. Human foreground/background recognition,
physical NVIDIA playfeel and acceptance of the more stylised profiles remain
owner decisions even after a successful hosted engineering campaign.
