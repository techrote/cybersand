# Inherited owner-evaluated palette source admission

PR #767 / programme #717 already shipped
`godot/shaders/material_palette.gdshader` from source
`910ac36d5804cb49d2d7d13c67a6ee42115a8bdc` in owner-evaluated application
`9f2127256a555d177536cbb5fad2be7dcb322c8e`. The earlier compatibility table
stopped at `1d4b6756b1ef245ecd9c9aeba88733fdce513a19`. This checkpoint records
the missing reviewed transition; it changes no shader byte or frozen lock.

- Previous admitted LF SHA-256:
  `c63cc54c572a1c5a3cd26cc3480057f6fcbb4a0280764cafa27cea06ed706057`.
- Inherited owner-evaluated LF SHA-256:
  `57053b4c0aab9b9c7a811c017e0df752bfd1388319d5f7dfd49ff65677330f36`.

Independent presentation specialist B reviewed the complete source delta:
ambient bounds are default-invalid for unsupported hosts; the valid bound is
expanded by nine cells, covering ember offsets 2/5/9, rocket distance at most
two, growth vertical five/horizontal one and fumes distance four. Material
sampling clamps to the World; clamping cannot increase those separations.
Main derives bounds from exact published material bytes, excluding only
Empty/Water/Steel/Glass IDs 0/2/3/58, and dirty patches expand conservatively.
The separate decaying vapour history remains rendered outside source bounds.

The retained definitive PUBPRES audit records nineteen exact HDR framebuffer
pairs / 13,248 pixel pairs, including an ember, an emissive Water edit and
lingering Steam/Smoke, plus the world-edge correction. That evidence remains
bound to its original source. This source admission supplies neither a new
performance result nor resulting-source graphical qualification. The current
combined application's fresh graphical and package gates remain required.
