---
title: Collaborative architecture planning and composition
status: Current
document-kind: contract
scope: WORLD-STEER-COLLABORATIVE-ARCHITECTURE-M6-M7-001
canonical-for: [bounded-architecture-delegation, architecture-proposal-bridge]
last-reviewed: 2026-11-24
related-documents: [architecture-staged-construction.md, native-detail-jobs.md, architectural-knowledge-and-evaluation.md]
---

# Bounded architecture planning and compositional retrieval

Status: Draft/HOLD. These interfaces extend the existing native staged authoring pathway. They do not replace the Art provider, conversation, credential, transport or session lifecycle.

## Host boundary

`architecture_workflow.gd` is the host facade used by the Architecture workbench. The planning adapter emits proposals; the campaign coordinator tracks a finite task graph; the existing StageSession compiles, previews and executes each selected native leaf after owner approval. Only the host has the actual World, library and execution receipts.

| Component | Responsibility | Authority it does not have |
| --- | --- | --- |
| `architecture_planning_adapter.gd` | Bounded natural-intent grammar, clarification, offline alternatives, proposal-only transport correlation | Native writes, approvals, provider transport or credentials |
| `architecture_campaign.gd` | Graph validation, dependency readiness, aggregate accounting, one live reservation, historical state | Model-supplied completion claims or direct World mutation |
| `architecture_delegation.gd` | Immutable local worker contract, fresh-source preparation and permission-preserving stage handoff | Automatic approval, model dispatch or native mutation |
| `architecture_compositional_retrieval.gd` | Finite joint module/pose selection, authored connector compatibility and compact reference context | Native admission, physical load or fluid behavior |
| `goldmaps_consumer.gd` | Explicitly identified versioned knowledge import and read-only browsing | Corpus mutation, automatic module qualification or owner acceptance |
| Existing StagePlan/StageSession | Exact footprints, permitted materials, source freshness, connections, native budgets and receipts | Treating a queued proposal as completed construction |

Ordinary Art responses must not be intercepted by attaching another listener to the provider's normal completion signal: that lifecycle may immediately parse and apply its own response. The coherent mergedown candidate uses the [explicit Art-owned proposal seam](architecture-proposal-owner-seam.md): Prepare discloses a current request, explicit Send routes one owned response to this adapter, and native application remains behind the host preview/approval boundary. Its resulting-source platform and owner gates remain separate from predecessor qualification.

## Intent and proposals

`submit_intent(intent, inspection, module_summaries, options)` takes a dictionary containing `text`, optional `family` and `seed`, a copied native inspection, trusted host library summaries, and bounded options. The supported offline grammar recognizes industrial hangars, arcologies, viaducts, biomechanical structures, service networks and organic caverns. An ambiguous or unknown intent returns a clarification choice; it does not claim general language understanding.

The required inspection has `kind: native-inspection-snapshot`, `ok: true`, `cells`, `region`, `source_sha256`, `generation`, `captured_revision` and `stale: false`. Cells are copied row-major LE16 material identities. Regions in this first planner are 64–512 cells per side. The adapter checks the bytes against the source digest before deriving a proposal. The host recaptures and verifies the actual source again for execution.

Offline planning returns up to three different finite structural alternatives. It also queries the current native module library for a suitable interior component. When a currently observed compatible component fits, one option contains an outer frame followed by that exact module and pose; both leaves still require fresh host compilation and approval. When the library is empty or no admissible component fits, `library_retrieval.status` explicitly records no-fit and the offline typed alternatives remain available. An imported metadata flag never grants current native qualification.

Proposal transport is injected through the `transport_requested` signal. The host may submit a real authorized response through `accept_response(request_id, response)`. The request contains a compact source description and hashes, not the complete source plane or original artwork. Responses use `cybersand-architecture-proposal-v1` and must echo the request ID, inspection hash and generation. Each alternative contains a typed campaign. Responses are bounded to 4 MiB, three alternatives and the inspected region/material scope. The adapter allows at most 32 requests per runtime instance.

`revise_intent` and `cancel_planning` retire the prior request. IDs include a runtime lifetime and monotonic sequence, so a late or duplicate response cannot replace the current proposal. Reopening saved planning history clears live requests. Fixtures and offline rules are identified as such; dispatching a fixture is not an inference call. Summary objects omit full geometry; `result()` and `alternative(id)` provide the full payload separately.

## Finite campaign contracts

The campaign format is `cybersand-architecture-campaign-v1`. A graph declares an overall region, aggregate native/raster budgets and typed group or leaf nodes. Every leaf supplies an existing v1 stage whose ID and region match the node. Hierarchy is bounded to 64 nodes, depth four and 32 native leaves. The graph is at most 4 MiB; its flattened native plan must also satisfy the existing 2 MiB limit. Aggregate ceilings are 4,194,304 native checks and 16,777,216 raster candidates. Existing per-stage limits remain in force.

Dependencies on a group expand to its descendant leaves. Cycles, unknown parents, unknown dependencies and invalid containment are refused. A skipped prerequisite is not completed. Readiness is invalidated when the host reports that an earlier native dependency no longer matches its retained result, including after ordinary editing or Undo.

Each node can describe write, guard, clearance and connector scopes. The host may add exact module or interface scopes after compilation. Reservation includes the whole selected stage region conservatively as well as these scopes. Only one leaf may be reserved or queued for native mutation at once.

`bind_preview` accepts an actual host preview and constructs an exact ticket containing campaign/plan/stage/source/projected/preview identities, generation, module identity hash, actual compiled budgets, runtime lifetime and revision. `reserve_approval` rechecks both the ticket and remaining aggregate budgets at approval time. This matters after partial execution or retries: an older preview cannot spend a budget that another attempt has consumed. The limit is two retries, hence at most three attempts for a leaf, and at most 16 campaign revisions.

The facade marks a ticket queued only after an actual native submission. `observe_terminal` accepts the corresponding real StageSession record, requiring the bound plan, stage, request/submission, source, preview and generation. It validates receipt counters and completion evidence. An uncorrelated late record cannot retire the active job. A correlated malformed terminal quarantines the job, charges the reserved ceiling conservatively and blocks further execution; it cannot turn uncertainty into available budget.

Revision uses `validate_revision` as a pure preflight, followed by the host's synchronous StageSession revision and `revise_job`. `note_preview_refusal` records actual host compilation refusal. `note_stale_dependencies` invalidates dependents without deleting historical evidence. Cancellation retires proposed work or requests a stop of the queued operation; an actual partial native record remains visible.

Campaign histories retain bounded snapshots and events. Opening history resets execution readiness: approvals, live reservations, completed dependencies and pending external requests are not resumed automatically.

## Executable local delegation

A delegated node starts with an empty stage and a `delegation` descriptor. `ArchitectureDelegation.declare(stage, job_kind, params, instance_id)` captures the original region, permitted materials, native ceiling, protected boundaries, clearances and connection requirements into the immutable contract. The worker is explicitly `procedural`; accepted job kinds come from the eight code-owned `NativeDetailJobs` functions. Common parameters explicitly supply `region`, `material`, `seed` and `max_cells`. A job is at most 128×128 cells inside a completely inspected stage of at most 512×512. Wear additionally names a current native part instance; imported history does not grant variable geometry scope.

`validate(node)` accepts either the initial empty shape or a structurally prepared output with the same descriptor digest and explicit source/generation pins. This is schema validation, not execution authority. The host keeps a runtime prepared-stage identity; reopening or importing a document must never manufacture that live identity from serialized flags.

`compile(node, detail_context_result)` consumes the exact `{ok, context, instances, selected_instance}` result from the host's fresh `StageSession.detail_context`. It intersects the current host permissions with the declared stage permissions, preserves original and newly observed guards, invokes `NativeDetailJobs.compile_job` and `stage_from_job`, and returns the generated stage plus proposal, descriptor/source/stage hashes and worker/native cost fields. It does not mutate either the supplied snapshot or the planned node. The original node identity and dependencies remain unchanged.

The generated stage cannot widen the original region, materials or native resource ceiling, remove original protection/clearance/contact requirements, or hide extra module placements and assembly bindings. Preparation is followed by ordinary finite campaign revision, host preview and owner approval. A later source or World-generation change refuses the pinned output. Current worker output is bounded by 16,384 cells, 1,048,576 worker scan cells and the tighter stage/host limits. Worker scan cost is reported separately from the host's authoritative native check count.

The pure delegation suite covers all eight workers and permission, malformed-control, stale-generation, source-hash, selected-instance and revision adversaries. Native recovery and approval qualification still requires the live facade. `Campaign.can_skip(id)` provides a pure state/history preflight so the facade can coordinate its Session skip and campaign skip atomically.

## Compositional retrieval

`retrieve(query, module_catalog, corpus, inspection)` accepts a `cybersand-compositional-query-v1` query. It supports up to eight slots, 256 compact module summaries and 16 declared face-contact relations. Each slot can constrain type, required or preferred tags, material roles, connection tags, scale, allowed transforms and placement alignment. A relation names two slot instances, an authored connector role and a compatibility tag.

Retrieval filters native observation, transforms, extents, materials and explicit exclusions, then ranks compatible candidates by the frozen structural, motif, reference and scale rules. It considers at most 12 candidates per slot and at most 2,048 search states; the registered comparison uses 256. Joint search enforces nonoverlapping module bounds, native cost ceilings and authored opposing connector faces, including capacity and exclusive span usage. Exhaustion and no-fit remain explicit. The result is the best found within the finite search, not a proof of global optimality.

Occupied-source and guard checks use bounding boxes conservatively. A module with a useful internal void may therefore be rejected even when a more elaborate exact geometry planner could fit it around existing material. Conversely, a successful retrieval still requires exact StagePlan admission and native readback; declared connector metadata alone is insufficient.

Context packs retain a small set of source-bound design references: three by default, at most five, and at most 12,000 characters. Observed source facts, architectural interpretation, historical native qualification and owner acceptance remain separate. Existing donor/visual-family exclusions are retained. Full private artwork and the entire corpus are not inserted into a prompt.

## Versioned GOLDMAPS consumer

`GoldmapsConsumer.load_identified(path, identity)` requires an explicit local file plus an acquired repository/commit/path/SHA-256 identity. `inspect_bytes` checks the digest before parsing. The first supported schema is `goldmaps.architectural-knowledge.v1`, pinned to scientific evidence `40f196f792e4d9e19bbd57fdafd6a90420fadf32` and archive `b9535405853a5cd16e4bba968ec7167222861c42`. The output has a distinct read-only view schema and cannot silently replace the frozen 25-card retrieval population.

The consumer preserves 70 recovered maps, the distinct 67-map primary policy/schema population, 25 nominees, 27 protected features, 76 immutable states, 12 comparative families, retained negative interventions, and zero owner acceptances. Original #155 and #183 refusal identities remain separate from derived policies. Module-candidate hints grant neither native geometry admission nor socket semantics.

Source static planes are uint8; current native authoring planes are LE16. `widen_source_static_plane` performs an explicit lossless identity conversion after checking extent and source digest, retaining both hashes. This conversion is not native execution or material-policy qualification. The consumer reads source family names as supplied; it does not invent equivalence between a new export taxonomy and the frozen design-card taxonomy.

The compatibility tests cover bounded schema fixtures and hostile inputs. The separately identified actual archive member `corpus-export/knowledge.v1.json` (SHA-256 `711e501597f0c9fa90a2553a643aabdbcbe5552693efc2dd578e626ca6c56557`) also passed the optional read-only intake invocation at consumer source `b49a0947e614e09a7807dd35043f20f88e31381b`: nineteen synthetic assertions, eleven actual-export assertions and one retention assertion. The initial longer-source-tag refusal is preserved; a consumer-specific 512-character bound retains the source text exactly. See [the actual intake review](../audits/2026-11-24-world-steer-m6-m7/goldmaps-consumer-review-b.md). This is knowledge-schema/browsing qualification, with no native module import or owner acceptance. No corpus file is modified by this consumer.

## Qualification and scientific scope

Pure tests exercise graph bounds, stale and duplicate responses, approval-ticket budgets, exact transformed module selection, hostile knowledge input and source conversion. Native qualification separately executes the host pathway and preserves receipts. The registered comparison in `godot/data/batch_lab/m67/comparison-registration.v1.json` freezes selector, corpus, budgets, seeds and independent brief reveal before the held-out run. Its development result and a retained contradictory brief are documented in the M6/M7 audit directory.

The module/tool comparison measures concrete finite capabilities. It does not establish language-model planning quality, human preference, stress behavior, fluid operation or actor traversal. Those conclusions require their respective genuine provider, rendered, gameplay or owner evidence.
