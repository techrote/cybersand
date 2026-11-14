# D-1B: soft guidance and shadow critic — independent preparatory lane

**Status: DEVELOPMENT / HOLD.** Owner research roadmap: [#570](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). Shared five-record interchange is the **unaccepted** [D-COMMON-001 v1 candidate](https://github.com/techrote/cybersand/pull/594). This lane is stacked at original candidate source `b117bfb1a59b557d8c54da01751819b00bf95836`; candidate validation does not mean owner acceptance. Keep this code **outside** native driver/permissions and outside D-1A/D-2 until exact SHA approval.

## Capabilities and limits

- Pure-stdlib deterministic, world-aligned scalar preference field `H` in unsigned **u16 little-endian**, with row-major numeric bytes, dimensions, world origin and SHA-256. A scalar zero is **neutral**, not illegal. Hard exclusions remain exclusively native.
- Parameterised numeric radial airbrush (centre, radius, hardness and gradient length), with *independent* seeded speckle PNG rendering (seed and centre density). Sparse speckles are **visual sampling**, never actual holes in `H`. All PNGs here are derived previews or imports, **not** framebuffer captures and **not** d1 visual inference.
- Canonical numeric `.u16le`, deterministic seeded PNG preview and JSON manifest with byte counts and SHA-256, exact file hash verification, pixel-equivalent reproducibility across PNG compressors and versioned raster conversion. The CLI prints the manifest SHA-256 for external provenance pinning. Import supports PNG8 grayscale, grayscale-alpha, RGB and RGBA, non-interlaced, with strict CRC and PNG filters; conversion is **Rec.709 luminance × alpha** (round to nearest u16). Unsupported PNG variants must be normalised externally **with their original SHA** recorded; do not guess.
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


## Proposed parallel A1/A2/A3 comparison — local synthetic audit only

The owner has selected a **representation-neutral extensible D-COMMON v1 candidate**:
the positive u16 scalar remains mandatory, optional typed guidance channels
require explicitly declared semantics, encoding, frame, dimensions and
provenance. A1 is scalar-only; A2 is experimental typed multi-channel guidance;
A3 explicitly separates scalar preference from geometric measurements.
This is **design direction, not M1 acceptance**. Never modify D-COMMON from
this lane; wait for the exact owner-approved SHA and schema digest in #570.

The independent \`comparison.py\` checks paired **frozen-decision forks** under
\`d1b-shadow-comparison/0\`. Each frozen fork contains exactly **one**
host-supplied legal candidate list, source-World SHA, predicted candidate-effect
hashes, and the A1/A2/A3 choices. It reports the earliest *candidate-ID*
divergence separately from the earliest *predicted-effect* divergence: two
different action IDs may be semantically equivalent under the host's prediction.
Predicted equivalence does **not** certify the resulting native World. Every arm
must use the same source snapshot and same admissible options **at that fork**.

After the first consequential fork the resulting Worlds would diverge. Their
later observations and legal recovery candidates must be recalculated from
their own actual state; do **not** assume that later independently evolving
Worlds can be represented as one shared state or force an identical candidate
set on them. Instead compare equal *opportunities* at frozen forks and then
separate matched-budget follow-through from independent rollouts. The auditor
reports submitted productive cells, committed cells and net objective progress
per arm, and rejects productive counts exceeding committed counts. These
supplied numbers are presently **synthetic illustrations**, not actual native
measurements. No causal effect or model performance claim is supported.

Experiment controls for the future owner-approved study: identical initial
World, scenario SHA, model weights/backend, legal action space, decision budget,
prompt cost accounting and seeded order; arm-specific configuration SHA;
matched host-geometry and information-preserving ablations to separate extra
information from encoding effects. Once native evidence is authorized, source
the \`productive_cells\` metric from qualified post-World geometry, report
negative progress and failures, and establish exact receipt/provenance custody.
The shadow comparator deliberately refuses \`evidence_class=native\`; a new
owner-qualified native path must not silently reuse the local synthetic type.

Pre-M1 offline qualification of this **new comparison-only slice**:
\`python -m unittest discover -s experiments/driv3r/stage_d/guidance -p test_comparison.py -v\`
on a temporary isolated copy of the exact source passed **7/7** on 2026-11-14,
covering cosmetic vs consequential divergence, illegal candidates, missing
effect sources, forged native claims, bad source revisions, invalid rollout
counts, and unmatched arm/snapshot sets. This is **not** evidence that the
original 12 \`test_guidance.py\` methods executed, nor independent GitHub CI
qualification of the whole D-1B lane.


## Typed-channel information-accounting pilot (14 November 2026)

Added \`information.py\` and \`test_information.py\` **only within this lane**, in response to D-COMMON's latest **unaccepted** optional-channel candidate at [8fa90de6](https://github.com/techrote/cybersand/commit/8fa90de6be209ed0b7bd125039e6ec8b332fb1a6), schema SHA-256 \`ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d\`. The source/semantic candidate has passed its own synthetic conformance checks but has **not been explicitly M1-frozen by the owner**. The D-1B branch remains based on the earlier candidate; this pilot is *not* a schema-compatible D-COMMON adapter or silent rebase.

The new local \`d1b-channel-shadow/0\` builder accepts a host-**declared**, bounded legal-candidate catalog (ID, exact swept cells, destination, native cell limit) and separately calculates an order-independent \`legal_candidate_set_sha256\`; no model/guidance scores can be inserted into the legal catalog. The word "legal" means **supplied by the host**, not that the synthetic module can verify native permissions. Candidate presentation order and guidance content do not change the host catalog digest; actual candidate footprints do.

One identical, frozen source-World hash, snapshot, host geometry, candidate catalog and positive u16 scalar guide feeds three **non-executed** views: A1 = scalar only; A2 = scalar and explicitly registered optional preference channels; A3 = scalar and explicitly registered optional geometry channels. The local pilot recognises \`soft_attraction/v1\`, \`soft_avoidance/v1\`, \`signed_preference/v1\`, \`signed_distance/v1\` and \`flow_vector_xy/v1\` under bounded \`u16le\`, \`i16le\` and \`vec2_i16le\` tile encodings. It requires matched tile frames and exact producer revision, configuration hash and seed, with a maximum of 4,096 model-visible cells per tile and eight optional channels. Additional meanings need a deliberate reviewed revision.

**Information barrier:** each arm's \`model_view\` contains only channels consumed in that arm, with their actual numeric samples and byte-hash provenance. A separate \`audit_only\` record retains consumed **and** ignored channel hashes and their semantic identities. **Do not forward the audit object to an inference backend**; doing so would contaminate the ablation even without visible numeric values. The geometry vocabulary is deliberately restricted to prevent accidental hidden guidance/critic injection. No stippled PNG is treated as the numeric field or model-vision input, and the returned records cannot mutate native materials, permissions, Stop or Undo.

**Local exact-file qualification:** the two new files were tested as an independent, pure-Python temporary package using
\`python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p test_information.py -v\`.
**10/10 tests PASS** on 14 November 2026, including signed/vector decoding, source/legality equality, presentation-order independence, hidden-channel non-disclosure, copied-input isolation and adversarial invalid provenance, frame, encoding and catalog inputs. Git blob SHA-1 of the tested file bytes matches the committed GitHub files: \`information.py\` \`a5a59fa74ca283987e86b133cf5025d522573144\`, \`test_information.py\` \`a6f7386f5567d6b03cbb710a6cdeca13b92a3406\`. This validates **only the ten new tests**; it does **not** imply the original 19 tests or the full integrated repo suite ran locally, nor any native/material or model result.

**Next owner gates:** explicit issue #570 M1 approval for exact shared source SHA+schema hash; separate authority for native adapter/receipts and controlled evaluation; genuine multimodal projector preflight and real native Undo remain independent. A future qualified study must record first **actual native/procedural** divergence, not upgrade locally predicted-effect hashes into that status.
