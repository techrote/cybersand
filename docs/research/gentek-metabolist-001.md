---
title: Metabolist Spine classic Gentek showcase
status: Current
document-kind: research
scope: Branch-local Draft/HOLD Metabolist Spine v1 geometry, controls, qualification and evidence reproduction; not merged product acceptance
canonical-for: [gentek-metabolist-spine-experiment]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, gentek-classic-001.md]
---

# Metabolist Spine — GENTEK-SHOWCASE-METABOLIST-001

This isolated Draft/HOLD experiment adds `metabolist_spine` **version 1** and the
**Metabolist Spine** preset to the ordinary GEN-007 schema-4 Architectural
Generator. Its immutable parent is
`615828b28337f85e4663e03ba479616db4ddf764` from PR #624. It does not change the
72 parent classic samplers, Viaduct v1/v2, material catalogue, physics, renderer,
Workbench controls or recipe schemas. It remains a coordinate sampler, with no
runtime component assembly or neighbour negotiation.

## Architectural programme

The complete new sampler is in `native/src/generation_architecture_metabolist.inc`.
A three-bay repeat anchors the first spine one base bay into the map, retaining
substantial structure in small native previews. Each spine has two continuous broad
rails with a narrow vertical slot and common deck datums. Each vertical band has
two independently selected attachment positions. One whole band in six remains
vacant on both sides; other vacancies come from the same bounded seed programme.

| Private family | Distinct geometry and root |
| --- | --- |
| Compact pod | Short enclosed volume and a concrete haunch rooted into the spine |
| Tall open frame | Deep rectangular frame, central post and cross-member |
| Service platform | Long open deck and a knee brace that reaches the core |
| Stepped habitat | Two roof heights and optional actual glass cells |
| Hanging pod | Upper boom rooted in the core, two hangers and an outer lower module |
| Structural outrigger | A high core root and long diagonal meeting an open deck |

Sparse bridges join occupied facing attachment floors across the inter-spine
gap. Both halves derive the decision from the same boundary/band hash, so a
chunk seam cannot invent an endpoint. Hanging modules may receive a bridge at
their lower floor while transferring to the spine through their upper boom.
The bridges are geometry; there is no physical structural-engineering claim.

The 72-form source study reused the small immutable `ArchitectureForm` contract,
signed floor/modulo coordinates, material roles and bounded integer segment
tests. Cantilever Spine and Shelf Stack show useful core/deck vocabulary but
repeat a single shelf motif. Staggered Balcony shows side staggering. This
showcase adds genuinely different attachment silhouettes, paired bridge
eligibility and explicit whole-band vacancies. No parent sampler was copied or
edited into a new name.

## Existing controls

| Control | Metabolist response |
| --- | --- |
| Room size | Base horizontal scale; spine spacing is three rooms and attachment lengths are bounded inside it |
| Floor height | Attachment-band cadence and the vertical positions of roofs, hangers and roots |
| Wall thickness | Spine rails, members, frames and root haunches |
| Automatic windows | Actual glazing infill in enclosed families; off clears glazing and preserves all structural members |
| Automatic doors | Outer service portals in compact, framed and stepped pods; off restores their wall cells |
| Shaft width | Existing global vertical exclusion, disabled in the hero preset |

The hero uses room **96**, floor **88**, wall **3**, doors/windows on, no shaft
or deterioration, and Reinforced Concrete / Rusted Steel / Frosted Glass material
roles. Both `examples/worldgen/architectural/metabolist-spine.style.json` and the
built-in style carry this configuration. Native admission requires room size at
least `6 × wall + 24` and floor height at least `6 × wall + 28`; narrower
configurations fail explicitly instead of collapsing into unreadable pods.

## Qualification and reproduction

Run from the repository root:

```sh
make -j2 worldgen-test metabolist-test CXX=g++
python3 tools/architecture/qualify_metabolist.py --compiler g++ --output build/metabolist-qualification
python3 tools/architecture/render_metabolist_spine.py --compiler g++ --require-clean-source --output build/metabolist-spine-gallery
make -j2 metabolist-sanitize CXX=g++
```

The branch extends native and ordinary Godot CLASSIC uniqueness to **73**.
Focused black-box checks compare chunk and direct sampling at multiple chunk
sizes, reverse traversal, work slices including zero budget, concurrent calls,
cancellation, negative origins and distant signed coordinates. Across **32
seeds × three wall settings**, a material-cell flood from the continuous cores
must reach every emitted cell. Separate gates check bounded cantilevers, full
vacant bands and bridge floor endpoints. Windows/doors and all geometric controls
must change the intended actual cells.

The qualification runner independently extracts and compiles the exact parent.
It compares materials, native fingerprints and chunk receipts for **72 modules ×
three configurations × four chunks**, and separately for **Viaduct v1 and v2**.
Performance records seven warm trials after one warm-up at 512² and 1024², with
rotating order against Cantilever Spine, Shelf Stack and Staggered Balcony.

The capture runner retains **50 native PNGs**: four hero dimensions, every seed
0–31 without cherry-picking, ten control cases, an unaligned negative origin and
three classics. Two unaltered 1:1 root detail crops and labelled contact sheets
accompany the originals. `seed-survey.json` records hashes, occupied ratios,
attachment/family counts, left/right occupancy and bridge counts. Its programme
ledger explains seed choices and never supplies or changes a native cell.

`manifest.json`, exact source-input SHA-256 ledgers, compiler identity, exporter
binary hash, raw `.cells`, per-chunk receipts and an exact-source input archive
bind every output to the source that actually ran. The scoped Draft workflow
also builds the Linux GDExtension, exercises the ordinary selectable preset,
renders the 73-map Godot gallery and requires its Metabolist material SHA-256 to
match the standalone hero. CI artifacts retain the library and build receipts.

## Evidence and limitations

The first candidate at `a72dc773fa720eee38369ab45863faf6457e87bb` passed the
large-area support survey but failed the preserved CLASSIC first-128² occupied
cell floor: its nearest core was outside that intake. The successor moves the
immutable core phase half a base bay left, preserving three-bay spacing and
nearest-core ownership. The threshold and all 72 existing samplers remain
unchanged. The failed attempt's source, cells, gallery and log are retained.


Actual commands, pass/fail counts, source commits, timing measurements and the
rendered gallery are recorded in the PR conversation and retained campaign
artifacts. This document describes the apparatus and its claims, not an assertion
that every platform gate has already passed at every branch revision.

The PNGs use native material cells through the existing opaque `BASE_RGBA8`
preview palette; they are not framebuffer screenshots or physical Windows
acceptance. Rectangle crops may clip attachment ends at map edges. The source
remains a fixed repeating spine field, does not negotiate adjacent styles, and
does not prove actor traversal or physical stability. The 32-seed survey covers
a finite sample, not every 64-bit seed. Owner aesthetic acceptance remains open.

Keep the PR **Draft / HOLD**. Do not modify #624, merge or promote Ready.
