# Actor Compose on the Material Audition World

The [Material Audition native review](material-audition-live-20261124/independent-native-review.md)
and [original actor-capacity review](2026-11-22-workbench-actor-sandbox/material-source-transition.md)
retain the two independently authored changes from the common World.
The integration for #737 / #762 adds the original transient-body response bookkeeping to the
Material Audition input. The protected diff from the Material parent introduces the
same greatest-used-body-ID clearing bound and the historical ordinary mask reservation.
The combined World retains scene-local material identity, transaction revision checks and
the existing physical owner. Body admission continues to use the configured per-scene limits.

| Identity | Value |
| --- | --- |
| Protected path | `native/src/world.cpp` |
| Material source | `e24105327b73b2fe52fb2bbe97532af7438b4086` |
| Material LF SHA-256 | `c5bd52b8827e5edef262ae2e9df2ec286abb9140d2e7ba6471b40d187e24ef14` |
| Actor and Material source | `53b2202408fea7130fd354ae35540880e926ba5e` |
| Combined LF SHA-256 | `98254d531ca7ca8f8e76f6d963f15b26b772777dc5633718a92cc637217eb77c` |
