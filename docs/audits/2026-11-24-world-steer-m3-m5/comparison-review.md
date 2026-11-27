# Independent architectural comparison review

**Development result: 30/30 native-completed attempts and 30/30 evaluable material planes.** All six matched family × seed blocks use the same initial native plane, context and exactly **144 newly painted detail cells** in every arm. Each attempt has six components of 24 cells. No registered case is missing, and no protected marker changes.

This review was performed by the architectural knowledge/evaluation specialist independently of the native comparison harness author. It records the development run at `50ad8265226030b6fc5f6f63936c4c06c6dde5ef`. It is **Draft/HOLD** evidence, not qualification of a later integrated source. The final qualification campaign must regenerate and retain its own exact source, runtime and artifact identities.

## Native result and interpretation

The hand-authored, deterministic-module, reference-guided and retrieval-guided arms each complete six attempts and pass the declared contextual checks in all six. Their final native material bytes are **identical within each family × seed block**. This equivalence was deliberate: the controls exercise alternative authoring pathways while keeping the construction outcome matched. It provides no evidence that retrieval or references improve architecture relative to the other contextual pathways.

The random-valid arm also completes 6/6 attempts and paints the same realized area and component count, but passes contextual checks in 0/6. It rejects source/part overlap while allowing contextually unsuitable positions. The independent reducer measures these differences directly from the retained native material planes:

| Family | Seed | Unanchored cells | Detached cells | New clearance intrusion | Outside detail zones |
| --- | ---: | ---: | ---: | ---: | ---: |
| industrial_hangar | 37901 | 144 | 144 | 24 | 144 |
| industrial_hangar | 37917 | 144 | 144 | 24 | 144 |
| service_network | 37901 | 144 | 144 | 48 | 144 |
| service_network | 37917 | 144 | 120 | 24 | 144 |
| organic_cavern | 37901 | 144 | 144 | 0 | 144 |
| organic_cavern | 37917 | 120 | 120 | 48 | 144 |

“Detached” means no face contact with actual host structural material. “Unanchored” means no contact with actual structural material inside the declared anchor regions. A contact elsewhere does not establish the intended architectural relationship. Every random case has 144 detail cells outside the declared zones; therefore a chance contact or a clear route does not make the contextual construction checks pass.

All 30 attempts preserve the declared protected marker. All also retain the tested five-cell-wide square clearance route. This is a static geometric path test, not actor movement or gravity-aware traversal. Its uniform success, alongside the random controls’ attachment and zone failures, demonstrates why painted area, broad connectivity and route existence alone are insufficient greeble criteria. No aesthetic score or significance test is inferred from this small diagnostic fixture set.

## Retrieval and reference authority

The reference-guided strategies use the authored interpretations of GOLDMAPS cards 146, 159 and 125 for the hangar, service and cavern families respectively. These are independent typed recipes, not model responses or copied source geometry.

The actual retrieval results are:

| Task | Ranked reference cards | Selected native part | Context characters |
| --- | --- | --- | ---: |
| Industrial hangar | 146, 153, 159 | `comparison-industrial-hangar` | 8,497 |
| Service network | **136, 159, 168** | `comparison-service-network` | 8,486 |
| Organic cavern | 125, 130, 207 | `comparison-organic-cavern` | 8,724 |

Both seeds return the same rankings. In particular, service card **136 ranks first**; card 159 is second and is separately the reference-guided strategy’s fixed card. The module pool contains only **three deliberately typed, natively harvested parts**. The experiment establishes the retrieval-to-qualified-module-to-native-application pathway. It does not establish broad module retrieval quality or a causal architectural benefit.

The design-card file remains bound to the GOLDMAPS evidence authority `40f196f792e4d9e19bbd57fdafd6a90420fadf32` and archival decision packet `b9535405853a5cd16e4bba968ec7167222861c42`. Original artwork admission, native policy admission, graphical qualification, architectural recommendation and physical owner acceptance remain separate. The new comparison parts are not admitted copies of original GOLDMAPS geometry. The separate family-exclusion retrieval exercise is documented in [Architectural knowledge and evaluation](../../systems/architectural-knowledge-and-evaluation.md); its results are not pooled with these native diagnostics.

## Exact custody and reproducibility

The retained manifest is `architecture-comparison/cases.json`; the independent reduction is `architecture-comparison/independent-analysis-b.json`. The accompanying [machine-readable review](comparison-review.json) records all six matched blocks, per-arm counts, random result vectors, selected module hashes and claim limits.

| Identity | Value |
| --- | --- |
| Executed development source | `50ad8265226030b6fc5f6f63936c4c06c6dde5ef` |
| Runtime | Godot `4.7-stable (official)`, Linux |
| Native bridge SHA-256 | `a15fc422313eb01e79bc904f44cc8879816484ae4fc98c63ac4b815afdb6a5e7` |
| Harness SHA-256 | `ad289bb2d1283f4b6caf4c83a7b4a7927d3c0b3204f262704583d569e3bca98f` |
| Manifest SHA-256 | `59e60594c3dd70e938fdac05f20265687568ee62c6b5c912420c48466e7a1e94` |
| Independent reduction SHA-256 | `c23d6bc3ba513cea72acb744bf926d6ef9c398b323da26870e461f3e81d3a703` |
| Frozen registration SHA-256 | `aa25936785d542f74fef1183b0ba394b6224d9aebc5cb0459679c863f7a3e028` |
| Frozen design-card file SHA-256 | `9153480ea622d5dc6a78543269840af64b3adbef43074af8cf78cfe685d0b057` |
| Independent reducer SHA-256 | `af04a5a35a842ec611bdbc03af0dc44aed702d55f74fa951c02e102682b74422` |
| Base readback reducer SHA-256 | `24dadd0c2bfa2a096004a80d0a08d3d48c1d2a84383c39483b65c6f8881c0916` |

Reproduce the independent reduction from the repository root, replacing `EVIDENCE` with the extracted evidence directory:

```sh
python3 tools/batch_lab/evaluate_architecture.py EVIDENCE/architecture-comparison/cases.json \
  --registration godot/data/batch_lab/architecture_experiment_registration.v1.json \
  --output EVIDENCE/architecture-comparison/independent-analysis.json
```

The reducer verifies full-plane hashes, dimensions and terminal native receipt/counter consistency; it preserves failed, stopped, partial and unevaluable attempts in the denominator. This run contains none of those outcomes. Completion and geometric checks do not substitute for actual graphical qualification or physical owner acceptance.

## Explicit remaining gates

No authorized model endpoint was used: the manifest records **zero model calls**, and the model-assisted arm remains unqualified. No blinded human preference study or owner acceptance occurred. Structural stress, pipe flow, dynamic gameplay and actor traversal are outside this experiment. The six larger staged constructions are separate demonstrations and require their own source-bound native and graphical evidence; they are not six additional comparative trials.
