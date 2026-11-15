# D-1A selected-wall strict-band decision horizon

**Status:** DEVELOPMENT-only synthetic diagnostic; frozen M1 source and schema unchanged. Run with `python -m unittest experiments.driv3r.stage_d.direct.test_band_horizon -v`.

The existing unconstrained shortest-decision BFS can report a 36-choice completion even when every legal detour must leave the required **6–10-cell distance band from the selected wall**. `band_horizon.exact_band_decisions` reuses the independent reverse BFS but admits only entire swept paths that remain in that band. It cannot jump over a blocked intermediate cell with an eight-cell macro. It uses the **identified wall**, not nearby decoy geometry. It reports unreachable states as absent, not successful.

`audit_development_band_horizon` first source-/seed-/trajectory-replays the original **DEVELOPMENT** record through `paired.verify_episode`. It retains original STOP and arrival fields and distinguishes:
- unrestricted vs strict-band minimum remaining macro decisions and budget slack;
- original-path prefix entirely inside the band, with failures sticky after reentry;
- hypothetical completion from the current cursor vs hypothetical completion preserving the entire original in-band prefix;
- first loss of strict-band reachability and first post-choice decision-budget deficit.

These are **geometric lower bounds**, not proof of ordered forward traversal, retrace freedom, model utility or native painting. The prior independent ordered/continuous wall-progress diagnostics remain necessary. Held-out behavior must remain sealed. Synthetic metadata always reports zero native receipts.

**Qualification:** Six new regression methods authored. Four exact new-source pure-helper methods were locally run against the preexisting Git-blob-exact `horizon.py` (SHA-1 `d3e4840dcebda17b62bc6bbb84b4f7bd9297d036`) and minimal dependency stubs: **4/4 PASS**. The two replay/integration methods and the expanded full D-1A suite have **not** been executed against a complete exact-head checkout; do not treat ordinary Stage A CI as qualifying this suite.

**Gates:** M1 owner accepted immutable `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`. No D-1A native long-horizon campaign authorization; no model, GPU/API, training, held-out model results, merge or Ready.
