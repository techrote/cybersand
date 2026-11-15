# D-1B: soft guidance and shadow critic — independent preparatory lane

## Frozen shadow snapshot identity audit — 15 November 2026

A substantive cross-case consistency weakness in `feedback_audit.audit_shadow_cases`
allowed two separately SHA-256-sealed hypothetical cases to reuse the same
`snapshot_id` while asserting different frozen goal-score, violation-count or
progress-count metrics. Per-case hashing cannot detect this contradictory
*cross-case* identity claim, so reference KEEP/UNDO/STOP accounting could
silently compare inconsistent versions of the supposedly same snapshot.

The auditor now binds every scenario-local frozen snapshot ID to its first
validated metric tuple and rejects a conflicting reuse, including resealed
cases. Reuses with identical metrics remain legal (e.g., after-to-before
continuity or a revisited frozen state); different IDs are still permitted to
describe metric-identical retry attempts for the separate oscillation-risk
analysis. No new native state or hash identity is inferred from these synthetic
metric tuples.

**Exact committed Git blob verification and local offline qualification:**
`feedback_audit.py` blob `d5796d3d1579aeef4d5d5637c0df4e061efe9e05`,
`test_snapshot_identity.py` blob `99d80802fa985e96bcd294b532d55a1b5409ea08`,
`test_feedback_audit.py` `658ef918c33fb13bc0ae2f7c574ff6b5ec9d0806`,
`test_feedback_edgecases.py` `382777dca3f86eea07bbc671d5a5fa7e607b163b`,
and unchanged `shadow_policy.py` `baccf7f367c25cdfcaa9637dcd05d387ab68b9aa`.
All five original/blob-reproduced files matched the code actually run locally.
**21/21 focused stdlib tests passed**: the original 16 feedback tests plus
five new identity/continuity tests. Commands:
`python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_feedback*.py' -v`
and separately `-p 'test_snapshot_identity.py'`.

This is a **focused byte-verified subset, not the full 23-file D-1B suite**,
and not integrated five-record M1 conformance. PR #596 stays Draft/HOLD.
Accepted source `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6` and schema
`ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`
remain unmodified. No real material Undo, multimodal input, native action,
model inference, paid use, formal A/B, merge or Ready promotion.


**Status: OWNER-ACCEPTED M1 / M2 LANE PREPARATION / DRAFT-HOLD.** Owner research roadmap: [#570](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). Shared five-record interchange is the now **M1-accepted** [D-COMMON-001 v1 contract](https://github.com/techrote/cybersand/pull/594), pinned to `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`. This lane was originally stacked on earlier source `b117bfb1a59b557d8c54da01751819b00bf95836`; that ancestry is not the approved contract. Keep the research implementation outside native driver/permissions and other D-1A/D-2 lanes. Native integration remains owner-gated.

## Independent frozen-arm object custody — 15 November 2026

`information.make_shadow_arms` previously returned A1/A2/A3 model views with
**aliased mutable host geometry and legal-candidate structures**. A caller
normalising/redacting or accidentally mutating A1's clearance samples or a
candidate's nested swept/destination coordinates could silently change the
other controls *after* their `model_view_sha256` audits were computed. This
does not establish any model influence, but invalidates independent frozen
views and could contaminate synthetic paired studies.

The producer now deep-copies host geometry and the complete host-declared
legal catalog **per arm**. New adversarial
`test_information.InformationTests.test_mutating_one_model_view_cannot_contaminate_other_frozen_arms`
mutates A1 nested geometry, swept coordinates and destination, then requires
A2/A3 to remain byte-content-equivalent to their prior independent records,
their original view hashes to remain valid, A1's recorded hash to expose its
own mutation, and the supplied original fixture to remain unchanged.
Retain the same host-computed legal candidate IDs/footprints/hashes across
arms at construction; this repair does not grant legal/native authority.

The changed Python and test blobs are committed; **the new regression and
complete exact-head D-1B Python suite are not independently executed here**.
Run the full lane suite via
`python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_*.py' -v`
before source qualification or M2 absorption. The accepted M1 schema and
native/visual/Undo/formal-comparison gates remain unchanged.

## Shadow-observation information isolation repair — 14 November 2026

**Boundary:** pure Python/synthetic, lane-only; no changes to the accepted five-record D-COMMON v1 schema or the native owner. A source review found two false-equivalence/information-contamination risks.

1. In `study.matched_arms`, values withheld from geometry-only / guidance-only / critic-only arms were `None`, **but hashes of all three inputs were still exposed inside every arm's model-facing `input_hashes`**. A withheld critic/guidance revision could therefore change a control observation despite unchanged visible data. The updated local `cybersand.driv3r.d1b-shadow/1` view contains hashes **only for included inputs**. The A/B/C/D factorial builder recalculates hashes after restoring common host geometry. Full-source digests must be retained separately by the host as audit-only information; do not send those to a model. Old `d1b-shadow/0` model-view records are not silently upgraded.
2. Synthetic candidate hashes were presentation-order sensitive and combined candidate IDs with *predicted* effects. `d1b-shadow-comparison/1` now publishes **distinct** order-independent `candidate_id_set_sha256_by_fork` and `predicted_effect_catalog_sha256_by_fork`; modifying host-predicted effects does not change candidate-ID identity. **These ID-only hashes are NOT M1's host-authoritative `legal_candidate_set_sha256`**, because this synthetic comparator has no swept-footprint/native-limit catalog. Only the accepted host catalog algorithm can assert the actual legal footprint identity.

**Exact-source local qualification:** `study.py` blob `18fdf0d83e6af2a6e7c8cbabf6cb1a9a6b5c127f` passed four focused information-isolation/order assertions on a byte-matched standalone copy. `comparison.py` blob `619c790eb9be740055dc74e1a25df13399b70a9a` and `test_comparison.py` blob `b89e94292f2b9d31cb6e934a77e87515d6fff1fc` passed **9/9** exact-blob stdlib unit methods (`python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p test_comparison.py -v`). `test_guidance.py` now has **14** methods, including two added adversarial isolation cases; **those 14 and the entire D-1B suite have not been independently rerun** at this head. In particular, do not count unrelated Stage A workflow success as execution of these tests. No A/B superiority, real native Undo, model inference, vision, training or paid execution is claimed.

**Owner gate:** M1 accepted source `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`; integration owner must explicitly absorb and requalify this independent lane revision. PR #596 remains Draft/HOLD.

## M1 acceptance and M2 lane adaptation — 14 November 2026

**Owner M1 approval is recorded in [#570](https://github.com/techrote/cybersand/issues/570#issuecomment-6881686675).** The immutable shared source is `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`; the immutable `interface.schema.json` SHA-256 is `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`. The earlier `b117bfb...` base is historical ancestry, **not** the approved contract. Historical development notes below that say "unaccepted"/"pre-M1" describe their original checkpoint, not the current M1 decision.

- New lane-only `m1_compat.py`: projects frozen synthetic A1/A2/A3 `information.make_shadow_arms` data into a **v1-shaped guidance record**, canonical numeric byte artifacts, and **separate audit-only** `observation.guidance_channel_handling` fragments for each arm. It maps local `geometry` to M1 `geometry_metric`, pins all five built-in auxiliary semantics (sign, rational scale, units), requires a named boundary for signed-distance data, verifies channel sample bytes and SHA-256, refuses inconsistent frozen Worlds/candidate catalogs and information leakage, and rejects any purported native evidence.
- Numeric artifacts are returned as in-memory bytes with safe relative names and exact digests; **no actual native material, Undo, model invocation or image projection occurs**. `display=None` deliberately avoids inventing a framebuffer or a speckle-preview witness. The caller must explicitly supply speckle/hysteresis provenance, and any physical artifact writing and full cross-record validation belongs to an independent integration owner.
- Verification: `python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_m1_compat.py' -v` — **10/10 offline synthetic tests PASS**, locally using exact GitHub-committed blobs `310eaa28505e80ae1e6d6b01b3eafc3ea646a53b` (adapter) and `7b90fe83154dcf0b561c1c39e986ca6086451e88` (tests). These tests verify wire-field mapping and adversarial rejection, **not** complete M1 five-record semantic conformance, actual native evidence or the previously committed D-1B suites.
- **Gates:** The M1 contract itself is accepted; the D-1B lane remains **Draft/HOLD**. No branch rebase or shared-workflow repair has been performed by this lane due to exclusive write ownership. M2 single-owner reconciliation and full schema/cross-record qualification remain pending; M3 native execution and M4 formal A/B comparisons require later separate approval.

## M2 lane-only provenance hardening (14 November 2026)

The synthetic adapter now checks **every arm-visible numeric channel copy** against
its declared raw byte length and SHA-256. Previously A1/A2 corruption of the
mandatory scalar could be obscured by a valid later A3 copy during
semantic-ID de-duplication. It also recomputes the canonical legal-candidate
digest from strict host-declared footprints, checks the original producer's
per-arm model-view hash, requires matching audit arm/protocol/host-catalog
identity, and rejects nonempty unregistered-channel use. No legal-candidate
set or native permission may be derived from guidance.

The `test_m1_compat.py` fixture now invokes the actual lane-local
`information.make_shadow_arms` producer rather than manufacturing incomplete
audit stubs. Six additional adversarial methods cover hidden early/middle-arm
scalar corruption, altered model-view digests, host-catalog mutation despite
matched arms, legal-catalog ledger drift and undeclared channel semantics.
Its 16 cases remain **synthetic**. Run:

```bash
python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_*.py' -v
```

These newly committed tests have **not** been independently executed in
this run. A green generic Stage A workflow does not establish their success.
The single M2 integration owner must perform exact-source offline-suite and
five-record M1 validation after reconciliation. No native execution, image
conditioning, real Undo or experimental dispatch is authorized by this patch.

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


## Synthetic feedback accounting and no-rollback guard (14 November 2026)

`feedback_audit.py` provides a deliberately **non-native, non-inference** bounded feedback auditor. It consumes SHA-256-sealed authored before/after metric probes, keeps scenario and decision-index identity, and compares a hypothetical KEEP/UNDO/STOP choice against an explicit deterministic reference based on goal score, violations, progress, and hypothetical Undo eligibility. It records a full confusion table and separately counts false KEEP, false UNDO, false STOP, inadmissible Undo proposals and repeated-pair oscillation *risk*. The hard study caps default to **36 forward decision indices** and **six hypothetical Undo proposals**. A hypothetical STOP is terminal; cross-scenario pairs, metric/case hash tampering, ambiguous controls, replayed IDs and budget overflow are rejected. Neither a passing reference judgment nor a synthetic receipt flag authorizes a native Undo.

Tests: `python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_feedback_audit.py' -v`. **10/10 passed locally** against byte-for-byte committed file blobs `feedback_audit.py` `27bf92dfee1c674969e1b8511128691a40dca8cd`, `test_feedback_audit.py` `658ef918c33fb13bc0ae2f7c574ff6b5ec9d0806`. This verifies the new isolated slice, not the earlier D-1B suites or full accepted D-COMMON five-record semantic conformance. Hashes of authored synthetic probes are not actual World material SHA-256 values; the returned `native_material_writes=0`, `native_undo_executions=0`, `model_inference_performed=false` and `actual_receipts_verified=false` are explicit scope markers. No original model decisions, genuine rendered frames or native rollback occurred.

M1 accepted source remains `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`, schema `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`; do not rebase the worker branch, edit the frozen contract or use a green synthetic audit to bypass separate M2 integration, M3 native and M4 formal A/B owner gates.

### Shadow-feedback error-accounting correction (14 Nov 2026)

The hypothetical `false_undo` counter now covers **every** shadow UNDO whose deterministic reference is not UNDO, including cases where a regression's only admissible hypothetical reference is STOP because Undo eligibility/receipt is absent. `inadmissible_undo` remains a separate overlapping safety-risk counter, not a substitute for the confusion matrix. Repeated **metric-identical** before/after UNDO proposals are counted as oscillation *risk* even if synthetic snapshot identifiers change between retries; distinct metric pairs are not. Matching metrics alone cannot prove actual native oscillation or World identity.

Cheap isolated qualification: `python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_feedback*.py' -v`. Six new adversarial cases cover STOP-vs-UNDO, absent hypothetical receipt, admissible but unwarranted Undo, and same/different metric-pair retries. Tests do not authorize or execute material rollback or model inference.


### Typed host-geometry information boundary (14 Nov 2026, offline)

The three matched A1/A2/A3 shadow views previously validated host geometry
**field names** but not their **value shapes**. This allowed a value such as
`{"clearance_cells":{"critic_verdict":"UNDO"}}` to pass the name allowlist
and enter every model-visible arm as purported geometry. The lane-local
`geometry_guard.py` now requires bounded integer clearance samples, paired
integer coordinates, signed distance/progress counts, bounded wall identifiers
and exact lowercase SHA-256 mask digests. It copies lists before exposure and
rejects booleans, nonfinite numbers, arbitrary nested payloads and freeform text.
The existing scalar and two-sample clearance fixtures remain supported.

This is structural information isolation, **not** proof that the supplying host
computed accurate geometry or did not encode guidance numerically. Native source
and permissions remain host-owned; no painter lane or accepted M1 contract
was altered. The five new cheap tests in `test_geometry_guard.py` exercise the
local validator only; final combined-suite and M1 conformance require separate
exact-source verification.

### D-1B scalar/critic provenance guards (15 Nov 2026)

The frozen 16-bit scalar field now refuses mutable list-backed storage and
coordinate frames that overflow the bounded World coordinate domain; native
material values and permissions remain untouched. The local hysteresis
state and hypothetical KEEP/UNDO/STOP eligibility/receipt flags must be actual
booleans. Typed shadow snapshots require finite non-boolean numeric scores and
bounded string identities. An untyped or truthy string such as `"false"`
cannot become a hypothetical Undo authorization.

The guidance bundle loader now accepts an **optional out-of-band**
`expected_manifest_sha256`. The CLI already prints the exact manifest digest;
record it independently alongside the numeric and preview hashes when provenance
matters. Without the external digest, raw/preview hashes authenticate artifact
bytes **only** and do not protect editable authoring metadata. The bundle format
and frozen M1 contract/schema were not changed.

Added four no-model/no-native regression methods in `test_guidance.py`:
mutable scalar alias and frame overflow; manifest metadata drift; truthy
hysteresis state; and truthy shadow receipt/eligibility plus malformed
snapshot metrics. These are test implementations, **not yet an executed
exact-head full-suite qualification**. The repository's scoped CI jobs must
not be substituted for the standalone Python tests without their logs.

### Shared synthetic shadow-reference policy /1 (15 Nov 2026)

A targeted parity review found that a **decrease in host-declared violation count**
with unchanged goal score and cursor progress was incorrectly classified as
`no_progress`, causing a hypothetical UNDO/STOP instead of KEEP. Both the
single-pair `study.shadow_verdict` and batch `feedback_audit.audit_shadow_cases`
had copied the same flawed predicate. They now call a single lane-owned pure
reference function in `shadow_policy.py`, explicitly identified as
`cybersand.driv3r.d1b-shadow-reference/1` for future source-pinned comparisons.

The policy treats more violations or a lower goal score as regression (even
if other metrics improve); absent regression, any lower violation count,
increased goal score, or increased cursor progress counts as improvement.
An entirely flat outcome still yields shadow UNDO when both hypothetical flags
are true and STOP otherwise. All decisions remain **non-executable**, with
zero native material or permission authority. This is a local **reference
policy semantic revision**, not a change to the owner-frozen D-COMMON M1 schema
or proof of critic quality. Prior synthetic outcomes using the old duplicated
policy must be labelled as a different reference revision if compared.

`test_shadow_policy.py` cross-checks both callers and their reason/counter
accounting for 108 matched metric/control combinations, deliberate violation
reductions, flat outcomes, conflicting metrics, and strict flags. Run with
`python3 -m unittest discover -s experiments/driv3r/stage_d/guidance -p 'test_*.py' -v`.
Unit tests are synthetic only; external M2 owner is responsible for complete
exact-head and five-record M1 integration qualification.
