# D-1B: soft guidance and shadow critic — independent preparatory lane

**Status: DEVELOPMENT / HOLD.** Owner research roadmap: [#570](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). Shared five-record interchange is the **unaccepted** [D-COMMON-001 v1 candidate](https://github.com/techrote/cybersand/pull/594). This lane is stacked at original candidate source `b117bfb1a59b557d8c54da01751819b00bf95836`; candidate validation does not mean owner acceptance. Keep this code **outside** native driver/permissions and outside D-1A/D-2 until exact SHA approval.

## Capabilities and limits

- Pure-stdlib deterministic, world-aligned scalar preference field `H` in unsigned **u16 little-endian**, with row-major numeric bytes, dimensions, world origin and SHA-256. A scalar zero is **neutral**, not illegal. Hard exclusions remain exclusively native.
- Parameterised numeric radial airbrush (centre, radius, hardness and gradient length), with *independent* seeded speckle PNG rendering (seed and centre density). Sparse speckles are **visual sampling**, never actual holes in `H`. All PNGs here are derived previews or imports, **not** framebuffer captures and **not** d1 visual inference.
- Canonical numeric `.u16le`, deterministic PNG preview and JSON manifest with byte counts and SHA-256, exact load verification and versioned raster conversion. Import supports PNG8 grayscale, grayscale-alpha, RGB and RGBA, non-interlaced, with strict CRC and PNG filters; conversion is **Rec.709 luminance × alpha** (round to nearest u16). Unsupported PNG variants must be normalised externally **with their original SHA** recorded; do not guess.
- Positive-only two-threshold hysteresis: `exit_below < reenter_at_or_above`. Exiting offers a **proposal** to recover, not movement or paint.
- Matched isolated information-ablation views, plus factorial A/B/C/D arms with shared geometry baseline. Matched snapshot/candidate views: `geometry_only`, `guidance_only`, `critic_only`, `combined`, with the same frozen candidate IDs and original hashes. These intentionally separate information sets; for formal D arms A/B/C/D compare geometry baseline with optional guidance/critic under the future accepted protocol.
- A deterministic **shadow reference oracle** yields `KEEP / UNDO / STOP` cases from explicit before/after scalar metrics; **none** execute native Undo. Real material history/rollback, Stop fences, partial edits and no-write checks belong to the future central native integration owner. Model-generated critic answers are **not** claimed or simulated.

## Offline smoke/tests

From repository root:

```bash
python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_*.py' -v
python3 -m experiments.driv3r.stage_d.guidance.cli /tmp/d1b-guide --width 64 --height 64 --seed 570
python3 -m experiments.driv3r.stage_d.guidance.cli /tmp/imported-guide --source-png /path/to/original.png --seed 570
```

Do not commit generated binary fixtures as unquestioned empirical evidence. Keep original imported PNG SHA, numeric field SHA, display SHA, authoring parameters, code/source revision and input source identifiers together. The field and preview hashes are **different evidence kinds**. Material-native screenshots and actual framebuffers remain separate types.

## Contract/permission gates

1. No D-COMMON v1 conformance/integration claim until #570 contains owner approval of exact schema hash and source commit. The local `guidance-bundle/0` / `d1b-shadow/0` are explicitly **pre-M1** and may require adapters.
2. No actual Q8 visual inputs: current backend uses `--no-mmproj` and is text-only. Real image projector, compatible typed questions, latency and original native crop provenance need their own separate qualification.
3. No brush-down movement, native material writes, permission edits, undo, model/GPU/API/training or formal matched native A/B campaign in this lane. All provided unit tests are **synthetic offline**, not native acceptance.
4. Future native path must use host-originated exact before/after World fences, actual receipt hashes, fresh observations, at most six owner-authorised Undo attempts per 36-forward-decision episode, and oscillation detection. Silent fallbacks, inferred receipts or binary-field substitution from visual speckles are prohibited.

**Next useful work:** add fixture-level feedback and image/structured information-accounting test coverage; then seek approved contract adapter and independent native owner to qualify original receipt custody and real rollback before any formal comparisons.
