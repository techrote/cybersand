---
title: Interlaced Viaduct showcase qualification
status: Current
document-kind: guide
scope: Isolated CLASSIC Interlaced Viaduct v1 composition, qualification and native evidence reproduction
canonical-for: [gentek-interlaced-viaduct]
last-reviewed: 2026-11-16
related-documents: [../systems/architectural-generator.md, ../reference/status-and-roadmap.md]
---

# Interlaced Viaduct — Draft / HOLD

This isolated showcase adds `interlaced_viaduct` v1 and the **Interlaced
Viaduct** style to the existing schema-4 Architectural Generator. Its fixed
parent is CLASSIC-001 commit `615828b28337f85e4663e03ba479616db4ddf764`
from PR #624. Each sibling showcase starts independently from that parent.
The parent branch and all 72 existing classic sampler bodies are unchanged.
No merge or Ready promotion is authorized.

## Design and source study

The complete 72-classic corpus was inspected before implementation. The relevant
lessons are the ordinary Viaduct's quadratic soffit and material precedence,
Nested Arcade's deliberate nested void, Hanging Arcade and Inverted Arch's
opposing curves, Suspended Deck's paired levels, Bowstring Truss and Cable
Gallery's rooted hangers, Crown Bridge's hierarchy, Spine Arcade's asymmetric
programme and Rib Vault's bounded member thickness. Their implementations are
retained unchanged. The new sampler lives in
`native/src/generation_interlaced_viaduct.inc`.

One supercell covers three ordinary bays and three ordinary floor heights.
The primary system is a thick normal arch, continuous edge piers and an elevated
deck. The secondary is an opposing sagging rib, a lower partial-width gallery
and two hangers rooted in that rib. A bounded seed choice shifts the secondary
centre, selects a gallery elevation, sometimes shortens its left termination
and chooses each crossing's plate or hollow collar.

The ribs share their actual geometric crossing. The shared plate thickens only
the intersection. The alternative collar encloses four small void pockets around
the still-continuous members. Neither is an arbitrary last-writer material
overlap: pier terminations, main deck, crossing node and secondary-member
precedence are explicit. The two opposite arches form a large central lens;
their galleries and terminations form additional side and lower voids.

This is a two-dimensional shared-node interpretation of interlacing. It does
not claim three-dimensional over/under crossings, structural simulation or
runtime negotiation. Programme choices are derived from immutable module-local
supercell coordinates and the recipe seed. Translating a signed module origin
translates both systems together; changing chunk size or request order cannot
rephase them. Existing zone clipping and optional shared macro tunnels retain
their normal behavior.

## Existing controls

| Control | Interlaced meaning |
| --- | --- |
| Room size | One third of the primary repeat span; scales arch radius and gallery reach |
| Floor height | One third of the vertical repeat; separates deck, arches and gallery |
| Wall thickness | Primary mass is twice the secondary rib thickness; crossing collars scale with it |
| Automatic windows | Substitutes glazing only in bounded pierhead transfer chambers |
| Automatic doors | Opens service portals at the feet of the shared boundary piers |
| Shaft width | Preserves the existing global module-local shaft exclusion |

The built-in and standalone `interlaced-viaduct.style.json` use bay 80, floor
64, wall 3, door 10, shaft 0, wall material 98, floor/accent/shaft 65 and window
121. These are existing materials. The diagnostic primary/secondary switch is
compiled only into the native evidence executable; no owner-facing control or
recipe field is added.

## Reproduction and qualification

Run from the source repository with C++20, Python 3 and Pillow installed:

```sh
make -j2 worldgen-test CXX=g++
python3 tools/architecture/qualify_interlaced.py --compiler g++
python3 tools/architecture/render_interlaced_viaduct.py --compiler g++ --require-clean-source
build/interlaced-render/interlaced_viaduct_export --check-layers
```

The existing native and Godot catalogue uniqueness gates increase from 72 to
73, retaining every original case. The focused black-box test exercises work
slices of 1, 7, 31, 257 and 4096 cells, cancellation, zero work, exhausted work
budgets, reverse and concurrent requests, 8/32/64/128/256 chunk partitions,
large signed coordinates, six seed outputs, heavy/thin members, apertures,
schema-4 admission and v1-only refusal. The independently compiled parent
comparison covers all 72 classic modules plus both accepted Viaduct versions,
with three parameter/seed profiles and four chunks per profile. Complete cells,
native fingerprints and receipts must match byte for byte on the same host.

The diagnostic executable calls the production compose function for primary
only, secondary only and combined output. Its 32-seed sweep measures independent
contributions, crossing additions, major protected lower voids, negative-origin
translation and distinct crossing programmes. It does not reimplement geometry
in a test oracle. The ordinary combined PNGs come from normal GEN-007 chunk jobs.

The campaign retains 26 one-pixel-per-cell native previews, six requested seed
variants, 512-square/1024-wide/1024-square heroes, control variants, three
matched classic comparisons and all three layer diagnostics. Four labeled
contact/comparison sheets supplement the unmodified images. Every ordinary PNG
has raw material bytes, native receipts, configuration, hashes and timings.
Source and executable ledgers are captured before rendering and rechecked
afterward. `--require-clean-source` refuses uncommitted generation inputs.

`.github/workflows/gentek-interlaced-draft.yml` is restricted to this showcase
branch and checks out the triggering commit. Separate native and pinned Godot
4.7 jobs retain their artifacts; a final job requires the hero material hash
to match the ordinary built-in Workbench preset's native gallery. The workflow
does not push source, alter #624 or change PR state.

## Evidence interpretation and limits

Local `build/interlaced-qualification/qualification.json` records actual native
results and timings. `build/interlaced-viaduct-gallery/manifest.json` records
the exact source, input ledger, binary and each image. Published PR comments
identify retained artifacts, the final qualified source and independent review.
Generated build output and logs are artifacts rather than repository source.

The native PNGs use the same opaque `BASE_RGBA8` material palette as the ordinary
Architectural Generator preview. They are native material evidence, not Godot
framebuffer screenshots or physical Windows acceptance. The 1024×512 campaign
is a native rectangular extent; the ordinary project compiler still uses square
map extents. Performance reports include complete native chunk generation and
hashing, with seven timed trials after warmup, and compare Arched Viaduct,
Hanging Arcade, Suspended Deck and Interlaced Viaduct at 512 and 1024 squares.
No physics support or traversal certification is implied by geometric coherence.
