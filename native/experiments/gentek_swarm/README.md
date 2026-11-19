# GENTEK-SWARM-001 — three self-assembling architecture proofs

The separately authorized stacked successor is documented in
[GENTEK-SWARM-002 — preplanned negotiated bearings](SWARM-002.md). The SWARM-001
description and frozen predecessor evidence below remain the control record.
The authorized [bounded optional-offer follow-up](OPTIONAL-OFFERS.md) retains
both frozen controls and compares caps of one, two and four optional offers.
The [SWARM-003 continuation](SWARM-003-CONTINUATION.md) reconstructs the
unpublished resilience source under a new identity and compares fixed native
capacities of four, six and eight. Its known regression seeds and fresh
validation follow a separate [registration](CONTINUATION-PLAN.md); the original
saved evidence is historical.

**Experimental native research. Draft / HOLD. No product acceptance.**

This programme implements the owner-authorised three-Gentek brief of 15 November
2026, following the design record in [issue #605](https://github.com/techrote/cybersand/issues/605).
It starts at accepted main `018bd09503d7f079ddac52e225c2f7daf8d678bf`.
The older read-only gates in the issue were superseded for this isolated trial by
the attached implementation brief; they were not superseded for production work.

Every changed source file belongs to this directory. Nothing registers a
production module, changes a recipe, calls World/Godot/Workbench, edits Viaduct
v1/v2, changes a material definition, publishes a runtime, or authorises a merge.

## Contents

- **Research result** — What the native comparison supports, including failures.
- **Reproduce and inspect** — One command for native tests, sanitizers and gallery.
- **Implementation map** — Separate methods, common contract and donor boundaries.
- **External authoring contract** — What a coding agent needs to implement a fourth Gentek.
- **Parameters and bounds** — Family-specific responses and finite resource semantics.
- **Meshing experiment** — Controls, ownership, exact joint decisions and corpus.
- **Qualification and review** — Meaningful checks, repaired defects and limits.
- **Next investment** — Questions answered and the remaining architectural work.

## Research result

The approaches remain recognisably different:

| Gentek | Implemented mechanism | Useful result | Limit retained |
| --- | --- | --- | --- |
| FRAMEWEAVER | Explicit parts, typed point/segment receptors, deterministic frontier growth | Connected skeletal frameworks, brace attachment, caps, externally qualified joints | Irregular growth can leave mandatory sockets unresolved; a compatible graph does not prove physical support |
| MOSAIC | Actual GEN-003 `PreparedRegions` categorical solve, followed by motif rasterization | Vaults, galleries, paired arches and contour-aware termination pieces | Fixed pitch remains visible; sparse domains can be UNSAT; foreign adaptation is currently a separate template pass |
| RECEPTOR | Immutable raster distance/source field, contour growth and normal ribs | Surface wrapping, local buttressing and seam/infill morphology | Free-space fallback produces disconnected shell clusters and is weak as a primary macrostructure generator |

**Recommendation:** retain FRAMEWEAVER as the primary structural direction, with
MOSAIC providing constrained architectural pattern and edge vocabulary. Keep
RECEPTOR as a complementary surface/seam specialist. Do not turn all three into
one internal representation.

The retained comparison has **171 cases: 63 single/failure cases and 108 pair
cases**. Each pairing uses six hostile fixtures, three intact profiles and two
seeds. These are measurements, not a quality score:

| Pairing | Cases | Cases with new bridges | New bridges | Adjacent typed contacts, no new cells | Cells added by shared bridges |
| --- | ---: | ---: | ---: | ---: | ---: |
| FRAMEWEAVER × MOSAIC | 36 | 23 | 59 | 5 | 590 |
| FRAMEWEAVER × RECEPTOR | 36 | 32 | 121 | 4 | 1,554 |
| MOSAIC × RECEPTOR | 36 | 27 | 75 | 38 | 959 |

All emitted outputs in this corpus preserve protected geometry and immutable
context: **zero hard overlaps and zero protected-space violations**. The table
includes unsuccessful cases. In particular, MOSAIC is UNSAT in ten
FRAMEWEAVER×MOSAIC cases and eight MOSAIC×RECEPTOR cases; those outputs remain in
the gallery. A zero-cell adjacent contact is reported separately and is never
counted as a new geometric bridge.

The visually inspected concave and foreign-solid cases support materially better
termination and interface construction than simple clipping, across at least
two pairings. The three-stage gallery makes the incremental foreign negotiation
visible separately from each generator's independent boundary awareness. Human
architectural judgment is still required; these native palette images are not
Workbench screenshots, simulated stability, traversal acceptance or a finished
level-design aesthetic.

### Matched free-space profiles

Same 192×112 territory, activation point and seed 605; destruction is zero:

| Gentek / profile | Occupied cells | Instances | Material components | Cohesion cells | Mandatory joints fulfilled / declared |
| --- | ---: | ---: | ---: | ---: | ---: |
| FRAMEWEAVER sparse | 925 | 31 | 1 | 0 | 50 / 50 |
| FRAMEWEAVER branching | 1,419 | 51 | 1 | 8 | 77 / 78 |
| FRAMEWEAVER dense | 1,518 | 59 | 1 | 69 | 84 / 85 |
| MOSAIC sparse | 7,414 | 84 | 1 | 0 | 0 / 0 |
| MOSAIC branching | 7,434 | 84 | 2 | 0 | 0 / 0 |
| MOSAIC dense | 8,198 | 84 | 2 | 0 | 0 / 0 |
| RECEPTOR sparse | 259 | 7 | 7 | 0 | 0 / 0 |
| RECEPTOR branching | 958 | 25 | 17 | 8 | 0 / 0 |
| RECEPTOR dense | 1,145 | 29 | 21 | 14 | 0 / 0 |

`Blocked` on the two irregular FRAMEWEAVER rows means one explicit mandatory
socket remains unresolved; it does not mean the process hung or that the raster
was discarded. The unfulfilled sockets remain visible. MOSAIC and RECEPTOR do
not declare a mandatory mechanical connector graph, so their `0 / 0` must not be
read as superior support qualification. Connected components are material
connectivity facts, not structural stability ratings.

## Reproduce and inspect

Requirements: C++20 compiler, GNU Make, Python 3 and Pillow. The retained run uses
GCC 14.2 on Linux. No Godot, native runtime library, LFS payload or network access
is needed to execute this research harness after cloning the source.

From the repository root, with a clean checkout:

```sh
python3 native/experiments/gentek_swarm/run.py \
  --out /tmp/gentek-swarm-evidence --sanitize
```

Use a new evidence destination on each run. The runner creates a **fresh build
directory** under `/tmp/gentek-swarm-build`, prefixed with the input fingerprint;
it never accepts an unverified cached executable. It records the Git commit,
source-input SHA-256 map, exact commands, compiler/platform, binary hashes,
durations and log hashes in `manifest.json`, then verifies source custody again.
`--allow-dirty` explicitly labels development iterations with a dirty fingerprint;
they are not clean-HEAD qualification. `--quick` reduces the visual corpus and
does not replace the full comparison.

The output contains:

- `index.html`: filterable offline gallery with every retained case.
- `gentek_comparison.png`: matched three-profile, three-method material overview.
- `meshing_comparison.png`: identical concave fixture across all three pairings.
- `images/`: actual material, instance/role and transition/affordance views.
- `single_*.json`, `pair_*.json`, `failure_*.json`: complete requests, masks,
  native material IDs, footprints, connector/attachment decisions and digests.
- `metrics.csv`, `summary.json`: measured facts and aggregate counts.
- `manifest.json` and logs: exact execution/source identity and outcomes.

The PR and the single evidence comment on #605 identify the retained review pack.
Generated images, binaries and bulk raw arrays are intentionally kept out of Git.
The palette renderer reads all 132 swatches from the unchanged native material
catalogue. It performs nearest-neighbour enlargement; there is no invented
geometry, smoothing, shader treatment or image generation. Semantic colours are
explicitly separate. Magenta is non-structural cohesion, cyan is a shared typed
joint, and hatched space includes fixture corridors and exported aperture
reservations.

LeakSanitizer is disabled because it cannot operate under the execution host's
ptrace instrumentation. AddressSanitizer and UndefinedBehaviorSanitizer remain
enabled with immediate failure. No leak-check pass is claimed.

## Implementation map

| File / symbols | Responsibility |
| --- | --- |
| `swarm.hpp` — `Request`, `Result`, `Boundary` | Finite research value contract; no production schema |
| `common.cpp` — `begin_result`, `finish_result`, `apply_damage` | Validation, bounded accounting, separate damage, deterministic identities and metrics |
| `frameweaver.cpp` — `generate_frameweaver`, `adapt_frameweaver` | Mechanical vocabulary and frontier growth |
| `mosaic.cpp` — `generate_mosaic`, `adapt_mosaic` | GEN-003 motif domains/solve and bounded foreign-contact additions |
| `receptor.cpp` — `make_field`, `generate_receptor`, `adapt_receptor` | Immutable environment field, contour/rib growth and residual cohesion |
| `fixtures.cpp` — `fixture`, `request_for` | Shared masks and fixed-scale profiles |
| `meshing.cpp` — `mesh` | Frozen snapshots, bounded typed interface joins and controls |
| `tests.cpp` | Focused replay, failures, masks, ownership, damage and meshing regressions |
| `main.cpp`, `io.cpp`, `run.py`, `gallery.py` | Retained native corpus, serialization, source custody and review views |

### Donor audit

GEN-003's unchanged `generation_spatial.cpp` is linked directly. MOSAIC invokes
`PreparedRegions::compile`, using finite per-cell category domains, reciprocal
cardinal adjacency, deterministic propagation and the donor's bounded
backtracking. It stays within 16 categories and 16×16 logical cells. This is
regular-grid motif assignment, not variable-footprint part assembly.

Successful solver work comes from `preparation_work()`. The donor does **not**
expose actual backtrack counts, and does not expose used work when it throws.
`backtracks = -1` means unavailable. Failed solver work serializes as `null`,
with an attempted/observed flag and configured upper bound; it is not zero work.
UNSAT and work exhaustion remain distinct outcomes, and neither rasterizes a
partial assignment.

GEN-004 is a conceptual donor for named identities, hard versus soft conditions,
receipts and immutable preparation. Its cardinal feature-edge passage sockets
are not imported as arbitrary mechanical connectors. GEN-003 geometry/Voronoi
utilities were considered for RECEPTOR; direct finite raster L1 distances fit
its actual material masks better. No utility is imported merely to increase
reuse claims.

[ADR-013](../../../docs/decisions/ADR-013-canonical-semantic-generation.md)'s
planning-before-external-sampling rule remains intact. Every complete result is
prepared from finite immutable inputs before any consumer samples the returned
material array. Evaluation never reads live World chunks, mutable simulation
state, or neighboring chunk completion. A future immutable `FeatureSampler`
wrapper is plausible; none is registered here.

## External authoring contract

A **Gentek** is a parametrically controlled, mechanically specified
self-assembling fill system. Its implementation owns architectural vocabulary,
growth/selection rules, adaptation, termination and parametric expression.
Activation provides rough placement only; no gesture recognizer exists.

To author a fourth Gentek, a coding agent needs the following explicit decisions:

1. Its algorithm, distinct identity/version and definition inputs. The harness
   fingerprints compiled research inputs with SHA-256; the exact Git source is a
   separate identity. Instance IDs are deterministic **within a prepared plan**,
   not a promise of stable names across arbitrary topology edits.
2. Whole geometry, coordinate convention, actual material-role mapping,
   exclusions and rejection rules. Arrays and affordances use local integer
   coordinates; `origin` records the finite world placement separately.
3. What each parameter does, and which stages it can affect. Destruction is an
   independent derivative of intact geometry; do not use damage as variation.
4. Which attachments it can honestly claim. A structural part, a locally
   compatible motif, and environment-derived growth are different semantics.
5. A small exported boundary: hard point/segment offers, soft preferences,
   protected geometry and a bounded transition band. Do not export the whole
   internal grammar or pretend every material adjacency is a validated joint.
6. Limits and explicit `Complete`, `Blocked`, `Exhausted`, `Unsat`, `Invalid` or
   `Damaged` outcomes, with per-cell provenance and intelligible reasons.
7. An additions-only transition adapter against an immutable foreign initial
   snapshot. Frozen accepted geometry cannot be removed or silently overwritten.
8. Matched controls, explicit negative examples, deterministic replay and honest
   structural/traversal/physics limitations.

### Annotated examples

**FRAMEWEAVER:** a post/span/junction/brace/cap catalogue enumerates quarter-turn
placements against an open connector frontier. Whole candidate footprints are
rejected before commit. Secondary braces attach only to declared segment
receptors. External sockets are exported on the **exposed material face**, not
the buried weld centre. A fulfilled local connector and an exported affordance
have different ID namespaces; a foreign join resolves a unique exact geometry
match. Caps are authored parts, not a claim that an unmet structural condition
has magically disappeared.

**MOSAIC:** each fixed-pitch tile gets an admitted category domain. Reciprocal
doorway signatures and strict paired-arch conditions constrain adjacent tiles.
Partial tiles select contour/termination categories whose shapes are constructed
from admitted spans; they do not crop an interior vault. Portal reservations
remain empty and are exported as protected geometry. The complete assignment is
solved before material cells are emitted.

**RECEPTOR:** immutable context cells seed a bounded four-neighbour distance and
source field. Surface tangents and normals guide local contours and ribs.
At zero environmental affinity, context ceases to attract sites or orientation,
but collision exclusion remains active. Cohesion uses a frozen local residual
mask, so new filler cannot expand its own flood eligibility.

Common mistakes demonstrated by this work include buried socket coordinates,
confusing offer IDs with connector IDs, checking only whole-displacement facing,
leaving damaged segment affordances published, failing to hash exported protected
geometry, counting zero-cell contacts as new bridges, and interpreting unavailable
solver statistics as measured zeroes. Focused regressions retain these lessons.

## Parameters and bounds

| Shared intent | FRAMEWEAVER | MOSAIC | RECEPTOR |
| --- | --- | --- | --- |
| Structural variation | Bounded member-length variants | Arch/rib category availability | Local shell-envelope variation |
| Irregularity | Frontier order and candidate preferences | Routing-domain rhythm | Site jitter, contour skew and rib bends |
| Branching | Junction activation and frontier breadth | Shaft/crossing/portal domains | Growth-event count and rib branching |
| Clutter | Secondary qualified braces | Attached corbels/trim | Shell bands and local detail |
| Cohesion | Separate bounded corner infill | Buttress/solid motif availability | Separate residual-slot/concavity infill |
| Environmental affinity | Root/contact preferences | Soft boundary strength/contact additions | Whether/how context attracts morphology |
| Destruction | Shared independent post-assembly cell removal and support revocation | Same stage | Same stage |

Territory is held at 192×112 for comparison. Width/height are request geometry,
not a profile slider. The four profiles are sparse regular, branching irregular,
dense cohesive, and a damaged derivative of the branching intact plan. High/zero
affinity comparisons are retained for all three families. Separate cohesion
regressions verify that filler changes neither structural footprints nor
mandatory-joint qualification.

| Bound | Default / research ceiling |
| --- | --- |
| Territory | At most 256×128 cells |
| Structural/growth instances | 64; MOSAIC requests explicitly allow 192 finite motifs |
| Frontier / candidates | 256 live frontier; 8,192 candidate evaluations |
| Connectors / boundary offers | At most 8 per instance; 256 hard and 256 soft offers |
| Cohesion | At most 8 patches, 512 cells per patch; shared across initial/adaptation stages |
| Charged generator work | 2,000,000 units, separate from categorical solver work |
| GEN-003 solver | 4,000,000 work units, fixed 256 KiB donor scratch |
| Memory admission | 16 MiB per request; conservative finite storage admission, not measured peak allocator telemetry |
| Shared negotiation | 8,192 offer-pair candidates; 2,000,000 charged comparisons/path checks; at most 12 accepted contacts/bridges |
| Joint geometry | At most 32 path cells, wholly inside the transition band |

The generic validation ceiling permits modest explicit experiments up to 256
instances, 512 frontier entries, 65,536 candidates and 64 million work units;
the retained corpus uses the defaults above. MOSAIC's instance exception reflects
84 logical tiles in a full 192×112 canvas, not an expansion of its category cap.
Fixed-size final validation/digest/image passes are separately bounded by the
finite arrays; their costs are not mislabeled as generator candidate evaluations.

## Meshing experiment

The six fixtures are stepped/diagonal frontier, concave intrusion, protected
traversal corridor, immutable foreign solid crossing, island and narrow neck.
The transition band is a finite Manhattan dilation of the actual irregular
ownership interface. All Genteks encounter the same masks; the tests exercise
both sides. Pair seeds are 605 and 1701.

Each case retains three material controls:

1. Independently generate both sides over the full canvas from the same activation
   locations and profiles, then clip to ownership. Severed joints stay recorded.
2. Generate each side aware of its own territory, without foreign offers.
3. Adapt both sides from the same frozen initial foreign snapshots, then run one
   common typed joint pass. Reversing evaluation order must give identical output.

There is no first-writer territorial ownership. The fixture fixes disjoint cell
ownership in advance. The shared pass orders candidate pairs canonically by
distance and geometry; this ordering is explicit policy, not a simultaneous
global optimiser. Each offer is used at most once. Short routes leave and enter
cardinal socket faces exactly, use at most three finite centre-route candidates,
and reject protected apertures, existing material, foreign core overlap, repeated
path cells and escape from the declared transition band. Failed offers remain
unpaired; there is no unbounded repair loop.

FRAMEWEAVER adapters may extend a socket towards a compatible foreign offer.
MOSAIC may add a bounded ledge or pier-cap piece anchored to existing masonry.
RECEPTOR may add field-driven contours/ribs and separately labelled cohesion.
The shared bridge then supplies an independently inspectable cross-owner path.
Neither filler nor cosmetic adjacency can discharge a mandatory joint.

**Important MOSAIC limitation:** the current pair harness runs its GEN-003 solve
before foreign offers are available. Foreign contacts therefore influence the
later template adapter, not a new categorical solve. Direct generation has a
foreign-Passage domain hook, but FRAMEWEAVER/RECEPTOR do not emit that passage
vocabulary in these pairs. The corpus demonstrates GEN-003's useful irregular
edge/termination selection; it does not demonstrate negotiated foreign motif
reselection or a newly carved doorway through an accepted wall.

## Qualification and review

The focused suite has 21 named groups covering native compilation, replay,
all hostile masks/profiles on both sides, invalid requests, bounded exhaustion,
real GEN-003 UNSAT versus exhaustion, protected voids, illegal overlap,
independent damage, zero-affinity invariance, exported-boundary digest identity,
cohesion/structural separation, frozen cores, actual joint paths, exact socket
facing, required-connector resolution and reversed pair evaluation order.
`manifest.json` and the retained logs give actual clean-source outcomes.

The independent reviewer additionally uses a 576-request adversarial sweep across
tiny and maximum territories, absent optional masks, irregular masks/context and
low budgets under ASan/UBSan. The retained independent review identifies its exact
source, probe hash and results; preliminary runs are not substituted for the
final source-matched record.

Substantive issues found and repaired during review:

- Foreign affordance IDs were incorrectly treated as internal connector IDs.
  Fulfilment now requires a unique exact instance/family/geometry/facing match.
- A route could satisfy a coarse target-direction test while leaving a frame
  socket sideways. Explicit outward endpoint stubs and route assertions fix it.
- FRAMEWEAVER exported buried centreline sockets. Exposed material-face contacts
  and explicit exposed side receptors now match the actual raster.
- Semantic digests omitted exported masks. Keep-clear/transition geometry is now
  included with explicit sizes.
- Shared work charging could exceed its stated ceiling by one and continue into
  path validation. Pre-charge checks now fence the whole negotiation pass.
- Damage could leave a segment offer spanning removed interior material. Damaged
  owners now lose hard offers, paired support is revoked and lost attachments are
  explicitly labelled.
- Reusable build caches could weaken evidence custody. Every runner invocation
  now builds from scratch in a fresh fingerprinted directory.

Failures worth retaining: the early sparse FRAMEWEAVER cross motivated regular
junction cadence; strict socket validation exposed the buried-face defect;
MOSAIC sparse UNSAT demonstrates the cost of a rigid grammar; a protected-corridor
FRAMEWEAVER×RECEPTOR case still has no offered join; RECEPTOR's disconnected
free-space shells show why it should not yet own primary architecture. All final
blocked, UNSAT, damaged and explicit zero-work/memory cases are retained.

### Repository-wide context

No broad runtime CI campaign is launched. The source-only repository's
documentation and repository checks report six unchanged missing
companion-workspace expected-fact references (`SOURCE-PROVENANCE.json`,
`docs/WEB_THREADING.md`, `tools/dev.py` twice, `docs/LOCAL_DEVELOPMENT.md`, and
`validation/browser-results.json`). They are not repaired or bypassed here.
Retained runtime LFS payloads are not materialized because this isolated build
does not consume them. Historical M11 integrity passes 18 records and 28 source
hashes. Unchanged retrieval evaluation reports canonical hit@1 19/32, hit@5
30/32 and MRR 0.7292; these lexical figures do not certify answer quality.

This single adjacent authoring/research document is discoverable from the PR and
#605. It is deliberately not promoted into the default canonical production RAG
corpus. Production subsystem docs, ownership, recipe schemas, runtime pins,
roadmap and UI controls remain unchanged because no such behaviour changes.

## Next investment

| Research question | Evidence-based answer |
| --- | --- |
| Is a common interchange useful? | Yes: all three methods exchange real hard/soft offers and protected geometry without sharing internal algorithms |
| What is universal? | Finite immutable territory/context, provenance, resource/failure semantics, explicit offers, protected space and transition ownership |
| Does mechanical frontier growth deserve more work? | Yes: it gives coherent connected skeletal output, inspectable construction and the most direct structural authoring vocabulary |
| What unique value does GEN-003 add? | Reciprocal motif compatibility and irregular edge/termination domain solving; foreign-driven motif reselection remains unproven |
| Where does RECEPTOR fit? | Surface, residual-gap and seam work; current free-space morphology is too disconnected for the primary role |
| Where should transition logic live? | Shape-specific termination/adaptation inside each Gentek; shared ownership, hard validation and a small explicit joint policy outside |
| Do parameters change more than scale? | Yes: fixed-size cases change junction/brace topology, motif routing/rhythm, shell count/orientation and interface decisions |
| Can cohesion help without hiding joints? | Locally yes; separate provenance and exclusions preserve unresolved mechanical facts. It is not a support repair |
| What must a fourth author know? | Algorithm-specific vocabulary/rules, exact geometry and materials, parameter response, failure/budget policy and honest boundary claims |
| What merits investment toward Viaduct v3? | A FRAMEWEAVER-led hybrid with constrained MOSAIC edge slots and optional RECEPTOR seam finishing, behind a new explicit future identity |

The next bounded investigation should reserve transition slots **before** the
macrostructure is frozen, then let MOSAIC reselect a small boundary domain against
real frame offers while preserving its core. FRAMEWEAVER needs better mandatory
termination at constrained limits and more interesting structural macro-patterns.
RECEPTOR needs stronger evidence about when a contact is useful buttressing versus
decorative wrapping. Minimum path clearance, meaningful global support, structural
load behaviour, larger territories, richer Gentek vocabularies and production
sampler integration remain open. No Workbench integration or Viaduct v3 production
implementation follows automatically from this research result.
