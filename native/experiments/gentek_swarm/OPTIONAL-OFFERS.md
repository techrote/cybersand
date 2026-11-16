# SWARM-002 — bounded optional-offer admission

**Isolated native research. Draft / HOLD. No product acceptance.**

This is the owner-authorized follow-up to the [SWARM-002 finding](SWARM-002.md),
on the same `experiment/gentek-swarm-002-negotiated-boundary` branch and
[Draft PR #662](https://github.com/techrote/cybersand/pull/662). Original full-offer
candidate C is frozen at `21617b14253cc6dcf35a83ded558565c8db517f5` (tree
`6bb4f1f55684c1da69f31c60f3c2ac908d877fe8`). Control B remains the exact
[SWARM-001 predecessor #625](https://github.com/techrote/cybersand/pull/625) at
`345ecc3ef939523f247b3eb192aa7502bd4d83ca`. Neither control is redefined.

The question is whether fewer optional offers preserve the island's architectural
benefit while reducing concave solve failure. This experiment changes admission
only. It does not alter GEN-003, MOSAIC's vocabulary, FRAMEWEAVER's geometry,
mandatory conditions, fixture definitions, materials, seeds or profiles.

## Contents

- **Finding** — One matched-budget concave recovery; useful island retention, with fewer validated interfaces.
- **Registered comparison** — Fixed caps, exhaustive single removals, and separate diagnostic lanes.
- **Admission semantics** — Geometric ranking before solving, unchanged hard conditions and full masks.
- **Work and solver semantics** — Original aggregate ceiling and explicit first-attempt allocation effects.
- **Matched results** — Reliability, common-case seam work, and optional-specific motif evidence.
- **Case interpretation** — Concave recovery, island retention, and retained negative results.
- **Qualification and custody** — Frozen B/C regression, independent checks, sanitizer scope and exact identities.
- **Implementation and reproduction** — Small experimental API, complete raw receipts and image gallery.
- **Research disposition** — What this additional complexity supports, and the next bounded question.

## Finding

**A fixed cap of four recovers one concave case without a budget increase and
preserves a substantial part of the island benefit. It is not a generally more
reliable replacement for SWARM-001.**

The original 36-case C corpus has 20 complete MOSAIC solves, 12 proven UNSAT
outcomes and four exhausted solves. Cap four changes that to 21 complete,
12 UNSAT and three exhausted. Caps one and two leave those counts unchanged.
No originally complete case becomes UNSAT or exhausted under these caps.
SWARM-001 still completes 26 of the same 36 cases.

All policies retain the original aggregate of 70 unresolved mandatory FRAMEWEAVER
connectors. A complete MOSAIC solve is not a claim that the whole structure is
resolved. Every claimed join has an actual qualified material path; omission of
an optional offer removes its join authority, not necessarily all incidental
material contact at that location.

The useful local result is concave intrusion / branching irregular / seed 1701.
Cap four completes at the same 2,000,000 first-attempt limit as the exhausted
full-offer control, records three joints and adds 18 late cells. Dropping just
optional slot `280363` also completes, recording four joints and 27 late cells.
These are two interventions on **one case**, not two independent recoveries.

## Registered comparison

The case universe is unchanged: stepped/diagonal frontier, concave intrusion,
protected corridor, foreign solid, island and narrow neck; sparse regular,
branching irregular and dense cohesive profiles; seeds 605 and 1701.

| Lane | Registration | Retained records |
| --- | --- | ---: |
| Full C reference | All original optional and mandatory offers | 36 |
| Primary admission policies | First one, two or four optional offers, plus every mandatory/hard offer | 108 |
| Hard-only diagnostic | Zero optional offers; mandatory/hard offers unchanged | 36 |
| Single-removal diagnostic | Remove each optional offer individually from every originally non-complete full-C case | 67 |
| Equal-first-budget diagnostic | Replay a recovery at 2M if its first-attempt allocation changed from full C's 2M to 4M | 4 |

The 67 single-removal trials cover 15 of the 16 original failed cases. The
remaining failure has no removable optional offer. No promising-case subset,
second-round deletion, adaptive refill, per-case best cap or new fixture is used.
The full ranking is frozen before even the B control is solved. Selection does
not inspect categories, solver outcomes or validated paths.

RECEPTOR is disabled in every admission variant. The unchanged full-C reference
retains its original D view for regression, but all comparisons use structural
C, before residual finishing. The original A clipping control and full B control
remain embedded in every case and in the complete predecessor qualification.

## Admission semantics

`prepare_admission` produces the original frozen FRAMEWEAVER preparation and
ranks only optional, nonhard reservations. Each reservation remains the same
mechanical point socket or short bearing segment, with its original stable ID,
owner, geometry, facing, envelope, clearance, strength and hardness.

The deterministic rank is a geometric lower bound:

1. Enumerate prospective exposed eligible MOSAIC cells in the original envelope
   and transition band, using the frozen ownership/protected masks.
2. Require positive projection along the FRAMEWEAVER facing and an ineligible
   cell immediately behind the prospective face.
3. Measure Manhattan distance from the nearest point on the actual reserved
   segment. Break witness ties by peer coordinates, then source coordinates.
4. Rank reservations with a witness first, then by distance and stable ID.
   An offer without a witness ranks last and still consumes a cap position.

This rank does not test native motif compatibility or search a material path.
It does not guarantee that an admitted offer can be satisfied. Every required
or already-hard reservation is retained outside the cap with unchanged hardness.
Invalid caps, removal of mandatory/hard offers and mutated preparations are
rejected before solving.

The full original slot universe, FRAMEWEAVER graph/material and union of all
reserved clearance masks remain unchanged. A withheld optional slot cannot
influence a MOSAIC domain or authorize a shared join, but stays visible in the
unresolved-opportunity denominator. Its reservation is not deleted from the
evidence. Unreservable mandatory FRAMEWEAVER connectors remain unresolved.

Only the filtered reservation vector enters the existing `negotiate_mosaic`
path before `PreparedRegions::compile`. MOSAIC's actual original, hard,
preferred and effective domains and selected categories remain inspectable.
Removing an offer is **not monotone relaxation**: an original alternative can
return while an offer-admitted receiving alternative disappears. The gallery
therefore lists both added and removed alternatives relative to full C.

## Work and solver semantics

All primary requests preserve the original configured ceilings: 2M FRAMEWEAVER
generator work, 2M MOSAIC generator work, 4M total categorical allowance and 2M
shared work. The structural charged upper bound remains 10M per trial. The
admission scan and fixed selection charge debit the existing shared allowance;
they do not create a new allowance. Controls and counterfactual ablations are
separate experimental trials, not extra retries inside a candidate.

At most eight original slots are considered. Scanning at most eight 64×64
envelopes, bounded ranking and selection cost at most 32,912 charged units,
leaving at least 1,967,088 for final joins. The existing finite route enumeration
can inspect at most 12,672 path cells. The reduced join allowance cannot bind
for a valid preparation, and no retained case hits it. Validation, hashing,
fixed-array scans and serialization remain finitely bounded and are not claimed
as exact CPU-operation counts or peak memory telemetry.

GEN-003 and the existing soft-preference attempt policy are unchanged. Effective
soft domains get a 2M preferred attempt; proven UNSAT permits the existing
remaining-budget hard fallback. Exhaustion does not permit fallback. With no
effective soft change, the sole solve may receive the original full 4M ceiling.
Consequently a fixed total ceiling alone does not prove equal first-attempt
effort. The separate 2M diagnostics expose that distinction without increasing
any candidate budget.

Successful solver work is retained. Failed-attempt used work and backtrack
counts are not exposed by GEN-003 and remain explicitly unavailable; an
exhausted result is not reclassified as UNSAT.

## Matched results

Complete means MOSAIC's solve completed, with mandatory FRAMEWEAVER failures
reported separately. These all-case totals include failures:

| Method, same 36 cases | Complete | UNSAT | Exhausted | Validated joints | Late seam cells |
| --- | ---: | ---: | ---: | ---: | ---: |
| B: SWARM-001 | 26 | 10 | 0 | 64 | 904 |
| C: all original offers | 20 | 12 | 4 | 72 | 262 |
| One optional offer | 20 | 12 | 4 | 34 | 36 |
| Two optional offers | 20 | 12 | 4 | 44 | 38 |
| Four optional offers | 21 | 12 | 3 | 61 | 173 |
| Hard-only diagnostic | 24 | 12 | 0 | 21 | 36 |

The hard-only diagnostic is not an optional-negotiation success. Its four
recovered concave cases make zero joints; three recoveries also depend on the
changed first-attempt allocation, as detailed below.

For the **same 20 cases solved by B, C and all three primary caps**, the seam
comparison removes changing-success denominators:

| Method | Validated joints | Original C joint IDs retained | Post-hoc cells | Change from C |
| --- | ---: | ---: | ---: | ---: |
| B | 45 | Different interface vocabulary | 654 | — |
| C | 72 | 72 | 262 | — |
| One optional offer | 34 | 33 | 36 | −86.3% cells |
| Two optional offers | 44 | 43 | 38 | −85.5% cells |
| Four optional offers | 58 | 58 | 155 | −40.8% cells |

These reductions accompany fewer authorized, validated interfaces. They are
not like-for-like improvements in interface coverage, nor proof that material
connectivity worsened. Caps one and two each also validate one joint ID not
joined by original C. All retain 33 unresolved mandatory connectors in this
common subset. The same 548 preplanned FRAMEWEAVER terminal cells remain in
every method derived from C; admission cannot take credit for changing them.

The optional-only counterfactual is cap zero with the same frame and hard
conditions. Original no-offer ablations also remove mandatory reservations and
must not be used to attribute every changed motif to optional admission.
Among the common 20 solved cases, caps one/two/four respectively produce
**12/18/17 directly affected category changes** against hard-only, and
**9/14/17 newly compatible optional responses**. The recovered cap-four concave
case adds one of each. Thus some native architecture genuinely responds to
optional offers; other retained interfaces would already have compatible
material without their optional preference.

## Case interpretation

### Concave intrusion / branching irregular / 1701

Full C exhausts its 2M preferred attempt. Caps one and two also exhaust. Cap four
uses 1,983,124 exposed successful solver work within the same 2M first-attempt
limit and completes, with three validated joints and 18 late cells. One
directly affected category differs from hard-only and supplies a newly
compatible optional response. The independent visual review can therefore
inspect an actual native motif response, rather than only a successful status.

There are six optional reservations and no mandatory reservation in this case;
the one unreservable mandatory frame connector remains unresolved under all
variants. Keeping hard reservations hard does not resolve an obligation that
FRAMEWEAVER could not reserve in the first place. The original B control
completes with two joints and 44 late cells.

Of all 67 registered single removals, only omitting optional slot `280363`
recovers a case: this same one. It uses the same 1,983,124 successful work,
validates four joints and adds 27 cells. The other 66 trials retain 41 UNSAT
and 25 exhausted outcomes.

Slot `280363` is an east-facing optional bearing segment from (42,71) to
(42,73), sixth in the geometric ranking, with distance 13. It changes tile 51
at (48,64) from `{termination_west, portal_west}` to
`{buttress, termination_west}`. Removing it restores the first domain, but the
recovered solve selects `termination_west` anyway. The complete recovered
assignment lies inside the original full-C preferred domains and still obeys
unchanged adjacency. It is therefore a concrete SAT witness for the original
categorical problem: the full-C exhaustion reflects bounded-search sensitivity,
not incompatible architecture or proven UNSAT.

The actual optional-driven architectural change occurs elsewhere. Slot
`67379507` changes tile 27 from `portal_west` to `buttress`; its adjacent tiles
28/29 change from gallery/east termination to the paired arch categories.
B and hard-only share the earlier motifs at those three origins. This trace
separates the offer whose removal changes search behavior from the retained
offer that visibly changes MOSAIC architecture.

### Island / branching irregular

At seed **605**, full C has four mandatory and only two optional reservations.
Caps two and four therefore retain the entire original selection: six joints,
four late cells, no unresolved mandatory connector, versus B's two joints,
25 late cells and one unresolved mandatory connector. This preserves the
original benefit but does not demonstrate pruning. Cap one retains five
validated joints and four late cells, with some changed native masonry.

At seed **1701**, six optional offers are available. Cap four genuinely prunes
two: it retains six of C's eight joints, all three original optional-driven
selected motif changes against hard-only, and four rather than six late cells.
B has four joints and 47 late cells. C and the caps retain one unresolved
mandatory connector. Visually, the authored receiving masonry and mechanical
frame remain legible. The entire selected category array and 1,435,168 solver
work match C. Only two final material cells change: the one-cell bridge for each
omitted reservation is absent. Cap four preserves the preplanned composition
with less validated coverage; it does not create a new architectural improvement
over C. The useful visual advantage over B is inherited from SWARM-002.

Across all four solved island cases, cap four retains 22 joints and 16 late
cells, versus C's 26 and 20 and B's 12 and 148. It preserves seven original
optional-causal tile selections against hard-only. The two sparse island cases
remain UNSAT under every cap and every single removal.

### Hard-only and remaining failures

Hard-only completes all four originally exhausted concave cases at the unchanged
4M aggregate categorical ceiling, but none has a validated joint. Its sole
solve receives 4M because the soft-domain changes disappear. Replaying at 2M:

| Concave profile / seed | Successful work at original ceiling | Outcome with equal 2M first limit |
| --- | ---: | --- |
| Branching / 1701 | 1,984,324 | Complete, zero joints |
| Branching / 605 | 2,095,676 | Exhausted |
| Dense / 1701 | 2,070,720 | Exhausted |
| Dense / 605 | 2,069,552 | Exhausted |

All twelve original C UNSAT cases remain UNSAT under caps zero, one, two and
four. Cap four recovers only one of the four exhausted cases; the other three
remain exhausted. Mandatory unresolved counts do not improve. No per-fixture
or per-seed best-policy chooser is selected from these outcomes.

## Qualification and custody

The exact final HEAD/tree, input hashes, build hashes, commands, timeouts,
outcomes and source revalidation belong to the evidence manifest and PR handoff.
The runner requires a clean checkout and fresh output directory for final
qualification; development output explicitly labels its dirty source.

The seven added native test groups cover the full 144 capped matrix, exact
all-offer equivalence to C, deterministic replay/reversed preparation and
evaluation, nested cap selections and ranking witnesses, every registered
single removal, malformed policies, unchanged hardness, frozen-input mutation,
actual material paths and lower-only diagnostic budgets. A test does not require
the research hypothesis to succeed.

Final qualification also rebuilds the frozen sources and compares all **171
SWARM-001 records** and **72 original SWARM-002 records**, including the original
all-hard lane. Only explicitly enumerated source-dependent identity fields,
their dependent digests and the compiled-definition hash suffix are normalized.
All material arrays/digests, parts, domains, categories, work, failures, joins and
residual results remain exact. Native legacy, original negotiated and admission
suites run with warnings as errors and under ASan/UBSan. Leak checking remains
disabled on this instrumented host and is not claimed.

The independent reviewer audits the full raw admission corpus, recomputes
ranking and cap membership, verifies unchanged requests and B/C controls,
rechecks material paths and domain evidence, and challenges the scientific
interpretation. Review scripts and findings are retained with the evidence.
All development raw audits report zero protected-space violations, illegal
overlap or frozen-geometry changes. Final-source outcomes must agree before
the PR handoff claims qualification.

The repository's existing six unavailable companion-workspace expected-fact
references remain an explicitly retained documentation-check limitation.
Production retrieval routes remain unchanged because no product behavior or
canonical product semantics change. No broad runtime, Godot, Windows or GPU
campaign belongs to this experiment.

## Implementation and reproduction

| File | Added responsibility |
| --- | --- |
| `negotiated.hpp` / `negotiated.cpp` | Small prepared-admission container, bounded geometric rank, fixed policies, original frozen preparation and join-authority filtering |
| `io.cpp` | Schema-3 admission receipt enclosing the unchanged full schema-2 candidate |
| `admission_main.cpp` | Registered cap matrix, original-failure single removals, separate lower-budget diagnostics |
| `admission_tests.cpp` | Seven invariant/regression groups; positive and negative results both admissible |
| `admission_gallery.py` | Exact native-material B/C/cap images, rank/domain overlays, optional-only causality, common-case statistics and failure tables |
| `run_admission.py` / `Makefile` | Fresh source-qualified builds, original B/C rebuilds, sanitizer gates and custody inventory |

From the clean research branch, with C++20, GNU Make, Python and Pillow:

```sh
python3 native/experiments/gentek_swarm/run_admission.py \
  --out /tmp/gentek-swarm-002-admission-evidence --sanitize
```

Use a fresh external output directory. `--allow-dirty` is development-only and
does not claim clean-source qualification. The direct native executable accepts
`quick` for development, but the qualification runner always uses the full
matrix. No runtime libraries, Godot or LFS payloads are consumed.

Open `index.html`. Each case has B, original C, hard-only, cap-one, cap-two and
cap-four native-palette panels plus a separate reservation/domain overlay.
Expandable tables list every ranked reservation and witness, selected/withheld
state, original and admitted category sets, selected category, both directions
of domain change and final joins. Failure diagnostics keep full C, pre-join
variant and final variant visible separately. The CSV and JSON summaries retain
all-case, common-success, optional-causal and budget-diagnostic denominators.

`controls-c/` holds the 36 direct C references. `frozen-c/` and
`control-qualification/` retain independent frozen-C generation and the complete
legacy/original negotiated qualification. The full candidate JSON includes
actual material IDs/arrays, full slot universe, protected masks, FRAMEWEAVER
graph, MOSAIC domains/attempts/categories, final paths and unresolved conditions.
Nothing requires a hypothetical score or a rendered approximation to inspect it.

## Research disposition

The added admission mechanism is justified as a small research control: it
isolates optional influence, exposes a genuine local recovery, and demonstrates
that some island architecture survives pruning. **The evidence does not justify
a new default policy or a larger negotiation framework.** Twelve hard-only or
intrinsic-domain UNSAT outcomes and three of four exhausted concave cases survive cap four;
caps one and two offer no reliability gain. Shared seam reductions often follow
reduced join authority and cannot alone establish better architecture.

The next bounded research question would separate offer content from the
existing preferred/fallback budget allocation: hold the same registered offer
sets and aggregate solver ceiling, predeclare one alternative split, preserve
hard conditions, and compare retained native motifs plus material paths. That
would test the observed near-2M sensitivity without changing GEN-003 or searching
subsets adaptively. It is a recommendation, not work begun by this follow-up.

All changes remain in `native/experiments/gentek_swarm/`. No Workbench integration,
production registration/schema change, Viaduct v3 work, renderer/material change,
Ready promotion, auto-merge or merge occurred. Human architectural judgment and
the original Draft / HOLD remain in force.
