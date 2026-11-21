# GENTEK-80 + accepted actor-composition reconciliation — Draft/HOLD

- Original #691 source with durable Art receipt repair: `d6ef45e9b2b8dc4354e237ea975aa52623f36879`
- Accepted main: `69209acaffb34ebe18c45e19290b5976b7fb2c82` (#683 Workbench actor composition and intervening main)
- Staging base: two-parent merge `60c9f926975a7ce1075452cfcd305b9007fecfc1`
- Result: all non-overlapping source changes preserved, plus additive docs and a reconciled Art traffic regression.

This is a **source-only preflight, not a qualified runtime**. The four overlapping Windows/Linux DLL/SO and provenance files are accepted-main placeholders while the combined Gentek + actor source is rebuilt; they are not source-matched to this tree and must not be used for production or a merge decision.

The combined Workbench keeps the accepted **lazy Art construction** contract. If a native Undo/Redo receipt occurs while Art has never been opened, the Workbench writes a small sanitized, individually atomically published receipt journal, without constructing the Art panel, copying a previous conversation or blocking the next Redo. On explicit Art opening the same-conversation receipts are replayed in chronological order, with deduplication after interrupted cleanup. The regression includes native events while Art is absent, 75 durable entries through Workbench shutdown/reopen, and preservation of the original archive hash.

The public 80-Gentek gallery and all original reference identities stay immutable. The merged-source source-input-drift policy enumerates **49** changed/introduced paths relative to the original 371 reference inputs (the current source contains 378 input paths). Enumerating these differences does not accept any changed output: the strict 80/80 default material/occupancy/recipe/project and decoded RGBA pixel comparison, full 520-capture campaign, 240 expected refusal cases, 80 independent-process replays, ordinary Workbench author/save/reopen and extracted Windows owner package are still mandatory.

## Remaining gates

1. Rebuild both native runtimes from the exact combined source, under the guarded Workbench qualification workflow.
2. Publish only the two qualified libraries and their two matching provenance records; reject stale source or branch leases.
3. Run the exact final-HEAD C++/GDExtension/Documentation/Wave/Palette and focused Art/Flatten CI.
4. Independently inspect native provenance, receipt safety, source lineage and owner ZIP.
5. Require physical Windows/NVIDIA acceptance and explicit owner merge authorization.

No Ready promotion or automatic merge.
