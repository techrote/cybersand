---
title: Carried RedBrick shader consumer transition
status: Current
document-kind: audit
scope: Independent non-identity shader consumer review for Draft510; frozen material identities retained
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../operations/material-catalogue-shadow.md, 2026-11-07-workbench-cut-feedback.md]
---

# Carried RedBrick shader consumer transition

Owner requests material appearance on freed bodies. Reviewed source commit is
299866d81a02d2a516f2109d0feef5bfeb0235c0, descendant of frozen baseline
0fd4af5987e77db4da3e37c757cf2c0917ae9e15 and2253eb2. Preserve ancestry/all9
existing entries. Add one entry for Draft[#510](https://github.com/techrote/cybersand/pull/510), issue364.

| Path | From admitted LF SHA256 | To reviewed LF SHA256 |
|---|---|---|
| `godot/shaders/material_palette.gdshader` | `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1` | `d7e412b687971e5f17d2af680c3f3b138054e64befb71dfb1c3131a53ecc80f8` |

Independent read-only `rigid_visual_trace` gives scoped technical GO after full
SOURCE_ROLES27/IDENTITY_INPUTS12 inventory: exactly shader changed;26 protected
and all12 identity inputs unchanged. Native include/src/GDExtension diff empty.
Frozen lock SHA2568b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc.
Catalogue82b5ab9a/capability33c608f8 unchanged. Both ancestry checks exit0.

Zero-default texture origin affects four sampling paths; false-default carried
mode discards Empty only when selected. Ordinary world/Water material arithmetic
stays unchanged with default uniforms. No catalogue, native transport, quantity,
tuple, authority or contact-law change. Actual graphical tests separately qualify
source agreement/holes/rotation. Review alone grants no platform/cost/physics,
original SOL, #365 or integration acceptance. Never refresh frozen hashes.
