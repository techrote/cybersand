# Source ledger — accessed 12 September 2026

The repository defines Current behavior and programme authority. Outside sources supply ideas and API context, not permission to replace the architecture. No third-party implementation or full paper is copied into this bundle.

## Pinned repository sources

All paths in this table are interpreted at `d39e31f03f2e39b0022d507b79fbee5c2439436d`, not mutable `main`. Research implementation and validation have their own later identities.

| ID | Source | Specific use |
|---|---|---|
| R1 | [AGENTS.md](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/AGENTS.md) | Ownership, immutable publication, preservation of historical evidence and validation obligations |
| R2 | [Roadmap](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/docs/reference/status-and-roadmap.md) | G-C/G-L/G-P complete; #19 V/H-preparation refinement; #18/#20 hold and #11 source/evidence gap |
| R3 | [State-precision registration](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/docs/operations/state-precision-experiment.md) | Exact input quantization, thresholds, pre-decrement/max-merge countdown and shared fixture geometry |
| R4 | [precision_storage.hpp](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/native/include/cybersand/precision_storage.hpp) | Existing compile-time research carrier permits mass4/6/8/10; it is not the proposed runtime mass3..8 policy |
| R5 | [material_appearance.hpp](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/native/include/cybersand/material_appearance.hpp) | Current Water visual projection returns raw state_a |
| R6 | [Rendering bridge](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/docs/architecture/rendering-and-gameplay-bridges.md) and [appearance](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/docs/systems/material-appearance-and-rendering.md) | Immutable RG8 snapshots, full-image upload, temporal presentation and non-authoritative visuals |
| R7 | [Issues #14](https://github.com/techrote/cybersand/issues/14), [#19](https://github.com/techrote/cybersand/issues/19), [#18](https://github.com/techrote/cybersand/issues/18), [#20](https://github.com/techrote/cybersand/issues/20), [#12](https://github.com/techrote/cybersand/issues/12) | Live programme contracts read at intake; issue pages are mutable, unlike the pinned documents above |
| R8 | [Documentation workflow](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/.github/workflows/documentation.yml) and [native workflow](https://github.com/techrote/cybersand/blob/d39e31f03f2e39b0022d507b79fbee5c2439436d/.github/workflows/native.yml) | Existing action/workspace pins, full-checkout checks and Linux native build commands reused without changing their policies |

The read header blobs include precision storage `92788b111182b977ba7a781f367732560fefb8fc` and appearance `42e427b6c0f4b3c7fd11e17e92b78b20e010d77d`. No temporary signed download URL, credential or author email is retained in this ledger.

## External primary sources

**S1 — Geometric volume fractions.** [Basilisk geometry](https://basilisk.fr/src/geometry.h) defines the unit-cell normal/intercept/fraction relationship; [fraction reconstruction](https://basilisk.fr/src/fractions.h) provides neighboring-fraction reconstruction context. The useful adaptation is bounded **presentation** geometry. It is not adoption of a VOF fluid solver, imported upstream code or a claim that fractions uniquely determine topology.

**S2 — Texture replacement.** [Godot 4.7 ImageTexture](https://docs.godotengine.org/en/4.7/classes/class_imagetexture.html) documents update versus set_image, matching texture dimensions/format/mipmaps, and reallocation behavior. The actual 1024-square full-update path is established by R6, not assumed from the existence of an API. GPU cost remains unmeasured.

**S3 — Data samplers.** [Godot 4.7 shading language](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html) documents sampler types, filtering hints and source-color treatment. This motivates auditing data-texture sampling separately from color textures. It is not evidence of a successfully compiled candidate shader.

**S4 — Controlled comparisons.** [NIST randomized block designs](https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm) explains keeping nuisance factors constant within blocks. Here that supports fixed scenario/seed/camera/presentation and separate semantic axes. The specific counterbalanced orders are generated and checked by this repository's new tool; no human results or significance claims exist.

**S5 — Specification scope.** [Leslie Lamport, Specifying Systems](https://lamport.azurewebsites.net/tla/book.html) supplies an author-maintained entry to asynchronous interfaces, safety/liveness reasoning and model checking. The current study is a small Python state explorer, not a TLA+/TLC execution or an implementation proof. The book and its licensed contents are not redistributed.

**S6 — Swept rigid-body motion.** [Rapier CCD guide](https://rapier.rs/docs/user_guides/bevy_plugin/rigid_body_ccd/) describes motion clamping and nonlinear CCD for fast bodies. The page is general Rapier/Bevy context, not a version-pinned review of the Godot adapter. Persistent granular support, cellular ownership and sparse reinsertion remain separate engine responsibilities.

External pages can evolve; the access date, inspected concepts and adaptation limits are retained here. The independently generated arithmetic/state/geometry results have their own exact source/data hashes.
