# Exact Classic wipe and blend precision

The actual Linux campaign at application `146cead1ac41147efa993b0bf8b634da08695182`
reached the real renderer and failed one of 108 checks: its Classic wipe region
was not byte-identical under haze 0.3 and parent opacity 0.5. The original
[run](https://github.com/techrote/cybersand/actions/runs/45720008446) and
[artifact](https://github.com/techrote/cybersand/actions/runs/45720008446/artifacts/15070878821)
retain the process, inputs and all captures. Their identities and the three
unmodified PNG copies here are recorded in [provenance.json](provenance.json).

This was a comparison defect, not a failed dense aperture. The same actual
Godot execution measured checker contrast 0.8000000045 at zero radius and zero
at radii 1, 2, 3 and 6, with white RGB/coverage preserved. It also passed the
isolated highlight, detail-coverage and bounded texture-edge checks. Those
successes do not erase the exact-wipe failure.

## Independent reproduction

The lead implemented [isolated_mesa_blend.py](isolated_mesa_blend.py), using a
surfaceless EGL context and an RGBA8 pbuffer. It compares the legacy
straight-alpha fragment/output blend with the algebraically equivalent
premultiplied output and with a direct legacy straight-alpha branch. This
experiment does not run Godot, does not qualify a physical GPU, and does not
replace the hosted graphical gate. The actual local renderer was llvmpipe,
LLVM 19.1.7, Mesa 25.0.7; the failing Godot job used llvmpipe, LLVM 20.1.2,
Mesa 25.2.8. Exact original results are in
[isolated_mesa_result.json](isolated_mesa_result.json).

For haze 0.3 and parent opacity 0.5:

| Source RGBA8 | Legacy straight-alpha output | Premultiplied output | Direct straight branch |
| --- | --- | --- | --- |
| 229,229,229,255 | 83,84,86,128 | 82,84,86,128 | 83,84,86,128 |
| 25,25,25,255 | 11,13,15,128 | 11,13,14,128 | 11,13,15,128 |
| 0,0,127,127 | 1,2,25,64 | 1,2,25,64 | 1,2,25,64 |
| 255,255,255,255 | 92,94,95,128 | 91,93,95,128 | 92,94,95,128 |

Five of the sixteen source/opacity cases differed between the two blend
arrangements. The direct straight branch matched the legacy branch in all
sixteen. The premultiplied values above also match the retained actual Godot
wipe pixels. This supports a finite-precision blend explanation; it does not
establish an implementation-specific account of every rounding stage.

## Repair requirement

Keep source sampling, filtering and optical interpolation premultiplied so
transparent neighbours cannot introduce dark colour. Use the legacy final
blend operation and an exact direct legacy expression for the Classic side.
Convert the processed premultiplied result to straight colour only at the final
blend boundary. Do not relax the exact Classic pixel oracle to a tolerance.

Retain a dedicated Classic haze/opacity capture in the next run and compare its
actual region with the wipe. Re-run the complete alpha/frequency tests and
ordinary Workbench qualification on both hosted backends. At the time this
research record was written, the repair was being implemented and its actual
Godot result was still pending.
