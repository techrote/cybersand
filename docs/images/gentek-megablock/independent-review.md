# GENTEK-SHOWCASE-MEGABLOCK-001 — independent source and visual review

**Final verdict: PASS for Draft research publication.** The architecture, deterministic material output, source-matched gallery, repaired catalogue metadata, actual Linux Godot integration and hosted Windows/Linux material parity pass independent review at `c846223ee0411662268f0a40942fd5e31002da6f`. Both jobs of fresh hosted run `43972648873` completed successfully, and their downloaded artifacts were independently verified. Initial run `43969027723` exposed a stale parent contract test and a missing minimum-schema catalogue field; the failure and narrow repair remain documented below. No blocking finding remains within this research scope. Keep the PR **Draft / HOLD**; this review is not merge authorization, Ready promotion, a Windows GDExtension qualification or physical Windows acceptance.

## Reviewed identity and independence

| Item | Identity |
| --- | --- |
| Latest reviewed source commit | `c846223ee0411662268f0a40942fd5e31002da6f` |
| Latest reviewed source tree | `8077dc18e35f82a2f30bbc300b9cc32afe1a41f8` |
| Original geometry source commit | `aedf1ba98b0a07669c1781ec4c5519072d5ca949` |
| Original geometry source tree | `bb692ebf048a3d7b46af3a27706a899ad57c0bf6` |
| Frozen parent #624 | `615828b28337f85e4663e03ba479616db4ddf764` |
| Showcase branch | `experiment/gentek-showcase-megablock-001` |
| Stacked PR | [#665](https://github.com/techrote/cybersand/pull/665) |
| Module | `seeded_typology_megablock`, version 1 |
| Reviewer | Independent `programme_review` agent; no production edits |
| Review date | 16 November 2026 |

I checked the local HEAD, tree and clean worktree at the reviewed commit. I read the entire parent CLASSIC catalogue, the complete new sampler and programme helper, registry/schema admission changes, preset/compiler integration, native tests, capture/measurement code, workflow and source contract. I did not inspect or incorporate Cathedral Megaframe or Megatruss Station implementation changes.

Source references are the reviewed commit's [sampler](https://github.com/techrote/cybersand/blob/c846223ee0411662268f0a40942fd5e31002da6f/native/src/generation_architecture_megablock.inc), [programme](https://github.com/techrote/cybersand/blob/c846223ee0411662268f0a40942fd5e31002da6f/native/src/generation_megablock_programme.hpp), [native tests](https://github.com/techrote/cybersand/blob/c846223ee0411662268f0a40942fd5e31002da6f/native/tests/test_seeded_typology_megablock.cpp), [Godot wrapper](https://github.com/techrote/cybersand/blob/c846223ee0411662268f0a40942fd5e31002da6f/godot/native_extension/cyber_world_generator.cpp) and [source contract](https://github.com/techrote/cybersand/blob/c846223ee0411662268f0a40942fd5e31002da6f/docs/research/gentek-showcase-megablock-001.md).

## Does the architecture support the research claim?

**Yes, within its deliberately finite, local scope.** The implementation changes the programme occupying architectural lots: core position, bridge level, habitation, open frame, cantilever, lower mass and crown handedness. It does not merely alternate one existing bay motif, randomly colour a fixed structure, or dispatch to a collection of existing samplers.

Nine private families share one 4-column by 4-band grammar. The core/atrium/support construction is legal for all four core positions. The atrium is always interior and has a known core on one side and a substantial support on the other. Selecting either middle bridge band therefore cannot leave a bridge adjoining another empty atrium. The spare lot is always an outer lot, making the inward cantilever anchor rule valid for every core choice.

Cooperation changes real native material geometry. Core and support lots expose middle landings when a bridge or cantilever requires them. Piers grow thicker against an atrium or bridge. Ordinary floors stop at atrium lots, and the protected empty band takes precedence over generic floor rules. Bridges and their two landings share one material datum. The lower slab connects all lots.

This cooperation is **intra-supercell only**. The helper treats an outer logical neighbour as a terminated interface rather than evaluating the next supercell. The shared transfer slab supplies the inter-supercell contract. That is sufficient for this classic experiment and is described honestly; it is not arbitrary neighbouring-typology negotiation, a WFC system or GENTEK-SWARM.

## Source quality and determinism

The production addition remains compact: 100 lines in the sampler and 49 in its private programme header at the reviewed commit. The concepts are visible as programme selection, common interfaces, protected void, and family-specific material expressions. A reader can follow the grammar without a reusable solver framework.

Each sample uses immutable coordinates, prepared parameters and seed. One coordinate hash identifies its supercell; local programme bits choose legal alternatives. Neighbour identity lookup is bounded and does not recursively search or rehash pixels. Sampling allocates no heap storage, has no unbounded loop or mutable cache, and reads no World or neighbouring chunk state. Integer member geometry has bounded dimensions and explicit clearance checks. The existing schema, material catalogue and renderer remain unchanged.

The minimum `6 * wall + 12` lot/band clearance prevents zero-width architectural spaces and unsafe geometric denominators. Signed world origins use the existing module-local anchor. The tests exercise origins that are not aligned to chunk boundaries, different chunk partitions, reverse requests, small work slices and concurrent sampling.

## Review findings and repairs

| Finding | Resolution | Disposition |
| --- | --- | --- |
| Initial doors-off geometry added a low centre pedestal inside an otherwise open arcade. That looked like an obstacle rather than a closed gateway. | The sampler now fills the actual lower arcade aperture with masonry when doors are off, retaining the arch, piers and slab. The revised toggle images were inspected. | Repaired |
| Survey caption text exceeded some 256-pixel thumbnail widths and visually ran into adjacent captions. | The capture script now uses the shorter caption `43.8% filled · 1 component`, with singular/plural handling, instead of the longer overflowing text. I inspected the final rendered survey sheet and confirmed that captions fit. | Repaired and visually verified |
| The smallest work budget originally selected an out-of-module chunk in one origin fixture. | The qualification agent changed all tiny-budget checks to chunk `(0,0)`, which intersects the module in both tested origin cases. | Repaired |
| Minimum square dimensions alone did not stress very steep/thin members. | Tests now include 18×256 and 256×18 lots with wall 1, all minimum-clearance wall sizes, and independent four-neighbour flood fills. | Repaired |
| New standalone preset/compiler test needed exact-source workflow coverage. | The workflow invokes `test_megablock_project.gd` and its path filter includes `godot/**`. | Repaired |

None of these changes altered a parent CLASSIC sampler or Viaduct implementation.

## Visual review and seed evidence

I visually inspected all 32 predetermined seeds, all ten required dimension/mass/opening comparisons, and the 1024×1024 hero. The principal seed set was 0–7 and the complete survey was 0–31 before image selection. Both hero captures use seed 0.

Across the survey, the recurring double-rail cores, stepped lower supports, restrained glazed habitation bands, large courts and bridge datums establish a stable family identity. Core positions, bridges and occupied programmes move visibly between seeds. The output contains useful large negative spaces rather than only narrow decorative holes. No inspected sample showed empty or dense collapse, random-looking detail noise, detached fragments, bridges ending into nothing, or arbitrary clipping at internal lot seams.

The controls have clear material consequences. Compact and large lots change the footprint; short and tall bands change vertical proportion; thin and heavy walls change mass. Windows off replaces habitation glazing with structural material while leaving other families alone. Doors off closes lower gateways. Crown and core continuity remain legible in the large hero.

I independently checked all 32 survey raw-material hashes and their corresponding PNG hashes in the first campaign. Its geometry inputs, including the sampler, programme and generator source, match the reviewed commit byte for byte. Its evidence is correctly labelled as a commit plus recorded local delta, not falsely claimed to have executed the later commit. The final clean-commit campaign is a separate publication gate.

| Survey measure | Verified development-campaign result |
| --- | ---: |
| Seeds | 32 |
| Distinct full-map SHA-256 identities | 32 |
| Occupied fraction | 39.049%–44.905% |
| Typology families per captured map | 8–9 |
| Solid four-connected components | Exactly 1 for every map |
| Survey warnings | 0 |
| Matching raw-material hashes | 32/32 |
| Matching individual PNG hashes | 32/32 |

These measurements support the visual judgment; they do not replace it. In particular, one solid material component includes glazing and does not certify load-bearing physics or player traversal.

## Tests and preservation evidence

I inspected the test source and local execution logs. The complete normal native generation suite passed **10/10 executables**. Five executables report assertion counts totalling **1,433,746**: 416,267 main generation, 19,750 Megablock, 14,162 typed fields, 208,725 semantic grammar and 774,842 semantic planes. Five additional executables passed without printing numerical assertion totals. The summed number is therefore the total of reported assertions, not a fabricated count for the entire suite.

Megablock qualification includes output-level core continuity, complete protected atrium rectangles, full bridge/landing material strips and transfer slabs. It covers all eight core-column/bridge-level combinations, seven interface dimension regimes, and 224 complete-supercell four-neighbour connectivity cases across stretched and minimum-clearance dimensions. These checks validate actual material output instead of treating programme labels as proof that the geometry cooperates.

The parent-output oracle was captured by a separately compiled executable from the exact frozen parent before the implementation. It covers 72 CLASSIC samplers plus Viaduct v1/v2 under two complete 256×256 profiles: **148 fixed hash oracles for complete material maps**. Every oracle passed. I also checked that `generation_architecture_classic.inc` and `generation_architecture_modules.inc` have no diff from the frozen parent.

The local pure GDScript project/preset test reported **188 checks, 0 failures**. Its invocation also reported unmaterialized native-library/LFS loading errors, so this result is credited only to the explicitly native-independent project/compiler test. It is not evidence of a locally loaded source-matched GDExtension. The hosted workflow owns that native Godot integration check.

The unchanged spatial allocation-probe test needed a local GCC 14 `-Wno-error=mismatched-new-delete` compilation workaround. The relevant source and repository CI gate were not weakened. This is a local toolchain qualification caveat, not a claim that the pristine local build command passed unchanged.

At this report's initial freeze, serial sanitizer execution and hosted run `43969027723` were pending. This report does not claim either passed. Their actual results belong in the final evidence ledger or an explicit dated addendum.

## Limits and remaining acceptance scope

- The finite 4×4 programme, single core/atrium pairing and repeated vertical band hierarchy remain visible. This is a useful classic grammar, not an unbounded urban planner.
- Cross-supercell continuity uses transfer slabs. Roof/core alignment does not negotiate between programmes.
- Full-supercell guarantees require an intact, complete, unmasked supercell with shaft 0 and no later deterioration, tunnels or explicit path carving. Partial style crops can truncate motifs legitimately.
- `door_width` remains a validated inherited field; this family's arch width derives from the bay. It has no independent width response and the documentation says so.
- Connected native material is not physical engineering validation, continuous playable circulation, or accepted gameplay performance.
- The retained parent native binaries predate this new module. Practical use needs a source-matched rebuilt extension; this review does not claim a new Windows owner package exists.
- Physical Windows and owner visual acceptance remain outstanding owner decisions. Draft/HOLD and no-merge requirements remain in force.

## Original aedf gallery publication check

**Original committed-source gallery: independently verified and approved for research publication.** This campaign is in `build/gentek-megablock-gallery` and records `clean_commit` at original geometry source `aedf1ba98b0a07669c1781ec4c5519072d5ca949` and its tree. Its source-input ledger is `1c71c4d8e856a69d2cd473c5d01f229178e15330a6d9838d6e6bf7d5bfa165d2`. The fresh c846 campaign and its expanded source ledger are reviewed below.

I independently recomputed every manifest digest, compared every source-input hash with the clean checkout, and decoded all native PNGs to compare their pixels against the raw native materials mapped through the unchanged canonical palette. I also checked protected voids and physical material strips directly in the captured arrays, independently of the telemetry labels.

| Final artifact check | Result |
| --- | ---: |
| Source inputs matched | 82/82 |
| Manifest entries matched | 185/185 |
| Missing or unlisted payload files | 0 |
| Raw native material maps matched | 55/55 |
| Native PNGs with exact raw-material/LUT pixel parity | 55/55 |
| PNG files retained, including five contact sheets | 60 |
| Visible protected-void rectangles checked | 200 |
| Complete programmes with actual core, bridge/landing and transfer-slab material checks | 104 |
| Final survey material hashes versus visually reviewed survey | 32/32 identical |

The final source-frozen survey retains exactly the same occupancy, family-count and connectivity values recorded above. I inspected the corrected 16–31 contact sheet and the matched CLASSIC comparison sheet. The repaired captions fit their allotted columns. The comparison makes the research distinction clear: the controls repeat a bay-level motif, whereas Megablock changes the architectural programme around its persistent common interfaces.

The original aedf campaign's local performance record uses one executable and common parameters. Megablock's direct geometry median was **24.93 ns/cell**, versus **6.28–10.93 ns/cell** for the four control samplers. Full native chunk raster medians were **144.993 ms** for Megablock versus **136.744–153.610 ms** for the controls over 512×512 cells. These are historical measurements; the fresh c846 capture's final timings appear below. Noisy shared-host timings do not justify claiming that Megablock beats a control in total generator performance.

I independently fetched hosted job status for [run 43969027723](https://github.com/techrote/cybersand/actions/runs/43969027723). Its native-generation/focused-test step and fixed-seed campaign step have completed successfully. The checked workflow uses `set -euo pipefail` and runs both `make worldgen-test` and `make megablock-sanitize`; the latter retains its default leak detection. This hosted completion is the sanitizer authority. At this addendum, the source-matched Linux extension build is in progress, and native Godot integration and Windows parity remain pending.

The local sanitizer sequence must remain accurately qualified: the original leak-enabled attempt stopped with LeakSanitizer's explicit ptrace-environment refusal. The local retry with leak detection disabled printed the main procedural-suite pass, but was stopped before the focused Megablock test completed after the hosted check had passed. **The local focused sanitizer retry is unqualified, not a PASS.**

I also independently fetched the completed [Documentation/provenance run 43969119160](https://github.com/techrote/cybersand/actions/runs/43969119160): its consistency job succeeded, including documentation, provider policy, Actions syntax, retained M11 records and retrieval checks. The retained-runtime provenance step was intentionally skipped for the Draft PR. That skip is not evidence that the inherited runtime binaries implement Megablock.

**Review disposition at gallery freeze:** no blocking architectural, seed-survey or artifact-integrity finding remained. The completed-run findings below supersede the earlier pending integration status. Keep the PR Draft / HOLD and preserve parent #624; owner acceptance and merge permission remain separate.

## Completed hosted run 43969027723 — integration failure and precise scope

The Linux job completed with **failure** in `Qualify actual Architectural Generator integration`. Windows completed as **skipped** because it depends on the Linux job. The exact completed outcomes are:

| Gate | Actual outcome |
| --- | --- |
| Complete normal native generation suite | PASS |
| Main generation ASan/UBSan, leak detection enabled | PASS, 416,267 assertions |
| Focused Megablock ASan/UBSan, leak detection enabled | PASS, 19,750 assertions |
| Fixed 32-seed native gallery/performance campaign | PASS |
| Source-matched Linux extension build | PASS |
| Native Architectural Generator campaign | PASS, 2,490 checks, zero failures, complete |
| Architectural project contract | FAIL, 2,748 checks, 72 failures |
| Focused Megablock GDScript project test in this run | NOT EXECUTED after previous command failed |
| Windows native tests and material parity | SKIPPED |

I fetched and inspected the completed job log and downloaded [artifact 14279975551](https://github.com/techrote/cybersand/actions/runs/43969027723/artifacts/14279975551). Its ZIP digest is `7e86e1d06f972cd6cece39461c64c35f524636c232e301b22ef5099910ed7a67`, matching GitHub's recorded digest. All 181 entries in the hosted gallery manifest match. Its source identity is clean `aedf1ba98b0a07669c1781ec4c5519072d5ca949` with the same source-input ledger as the local final campaign, and all 32 hosted survey raw-material hashes equal the independently reviewed local maps. The differing manifest count reflects locally added qualification logs, not missing native gallery payloads.

The 72 contract failures come from an inherited stale expectation in `godot/tests/test_architectural_project_contract.gd::native_identity_edges()`: it considers only Terraced/Hive/Arcade and the two legacy v2 variants to require schema 4, so it incorrectly classifies all 72 CLASSIC samplers as legacy. The existing adapter correctly marks those 72 as schema-4-only. I checked the parent source to establish that this stale test is inherited.

That investigation also exposed a genuine omission in the original showcase: `godot/native_extension/cyber_world_generator.cpp::get_catalogue()` had not added `seeded_typology_megablock` to its `schema4_only` metadata list. Native admission enforced schema 4 and native generation succeeded, but catalogue metadata omitted the minimum schema. The stale contract test accidentally accepted that omission. The correction below repairs it without suppressing the test.

The required minimal repair was to add the Megablock catalogue metadata, distinguish the three true legacy v1 identities from schema-4-only identities in the test, include Megablock in the project's CLASSIC uniqueness campaign, and rerun the exact-source integration workflow. This did not require changing the reviewed geometry, parent samplers or palette. Integration approval was held at that stage until the fresh Godot/Windows gates actually completed; their successful outcomes are recorded below.

## Independently reviewed correction — c846223

I reviewed the complete four-file delta from evidence publication `396c9f6aac213b935ba1b1acd9fc83bb79b2bcb3` to clean source `c846223ee0411662268f0a40942fd5e31002da6f` (tree `8077dc18e35f82a2f30bbc300b9cc32afe1a41f8`). The correction is narrow and sound:

- `get_catalogue()` now includes Megablock in its schema-4-only set. Independent extraction confirms the adapter and native admission sets contain exactly the same 76 module IDs, with no missing or extra ID.
- The project contract retains precisely `arcology:1`, `vault:1` and `aqueduct:1` as legacy identities without minimum-schema metadata; every other current catalogue entry must explicitly require schema 4.
- The contract now runs all 73 CLASSIC modules and requires 73 distinct material identities. It explicitly requires Megablock v1 and rejects an advertised Megablock v2.
- The source-input ledger now includes the Godot wrapper implementation/header, and the source contract maps the corrected adapter/test responsibilities.

No file under `native/src` or `native/include` changed from the original reviewed geometry commit. No test was removed, disabled or loosened to excuse a real catalogue mismatch. The repaired expectation strengthens coverage of the actual intended schema contract.

The fresh local campaign at `build/gentek-megablock-gallery-final` records this exact clean commit. I independently verified all **84 source-input hashes**, all **181 payload-manifest entries**, and the new ledger `b403d9e2a963f9e53522879523a56dc96f4e94557b648c3b2fd9ad5e5e274f26`. All **60 PNGs** and **55 raw native material maps** are byte-identical to the preceding independently inspected packet. The worktree was still clean at this verification. The new machine-readable record is `megablock-independent-final-artifact-verification.json`.

The final c846 performance packet retains five repetitions per module with common parameters and the same capture binary. Its medians are:

| Sampler | Direct geometry, ms | Direct geometry, ns/cell | Complete native raster, ms |
| --- | ---: | ---: | ---: |
| Seeded Typology Megablock | 8.683 | 33.12 | 169.013 |
| Cantilever Spine | 2.951 | 11.26 | 166.528 |
| Staggered Balcony | 1.502 | 5.73 | 135.816 |
| Bridgehouse | 1.621 | 6.18 | 156.099 |
| Stacked Arcade | 2.935 | 11.20 | 139.059 |

Megablock's direct sampler is about 2.9–5.8 times the cost of these simpler motifs; measured complete generation is 1.01–1.24 times their cost. The earlier capture of the same binary produced different timing medians, so these are advisory shared-host observations, not a guaranteed throughput or gameplay-performance claim.

Fresh [Documentation/provenance run 43972660053](https://github.com/techrote/cybersand/actions/runs/43972660053) completed successfully; the retained-runtime provenance step remains intentionally skipped for Draft status. I independently fetched that completed result. The initial integration failure remains retained above; no pending or skipped check is reported as passed.

## Fresh hosted qualification — c846 exact source

Both jobs of [qualification run 43972648873](https://github.com/techrote/cybersand/actions/runs/43972648873) completed successfully. I fetched the completed job logs, downloaded [Linux artifact 14280303022](https://github.com/techrote/cybersand/actions/runs/43972648873/artifacts/14280303022) and [Windows artifact 14279273693](https://github.com/techrote/cybersand/actions/runs/43972648873/artifacts/14279273693), verified their ZIP digests and inspected their actual retained logs, runtime report and raw material arrays.

| Fresh Linux gate | Actual completed outcome |
| --- | --- |
| Complete normal native generation suite | PASS, 10/10 executables; 1,433,746 reported assertions |
| Main generation ASan/UBSan, leak detection enabled | PASS, 416,267 assertions |
| Focused Megablock ASan/UBSan, leak detection enabled | PASS, 19,750 assertions |
| Fixed 32-seed native campaign | PASS |
| Source-matched Linux extension build | PASS |
| Native Architectural Generator campaign, Godot 4.7 headless | PASS, 2,490 checks; zero failures; complete |
| Repaired Architectural project contract | PASS, 2,757 checks; zero failures |
| Focused Megablock project test | PASS, 188 checks; zero failures |

The Linux artifact ZIP SHA-256 is `09f5cace482a202cfe2e38cf945d1184ac007f90150bbeffad855aebd8cde3dc`. Its source identity is clean `c846223ee0411662268f0a40942fd5e31002da6f`, tree `8077dc18e35f82a2f30bbc300b9cc32afe1a41f8`, input ledger `b403d9e2a963f9e53522879523a56dc96f4e94557b648c3b2fd9ad5e5e274f26`. I independently verified all 84 source inputs against Git objects at that commit and all 181 hosted gallery manifest entries. All 55 raw material maps and all 60 PNGs are byte-identical to the visually reviewed final local packet, including all 32 survey maps.

The source-matched Linux GDExtension digest is `dab33da6d93e06c81baeccf7e39c9edf7f866191c8a5b31c2c553c92c1ed6837`. The actual native Godot report includes the Megablock v1 preset at seed 271828, with material SHA-256 `f06684e0b9ed69f252b26a2599c9c34a1d66172fdc2ce93c54b19a78324843db` and recipe SHA-256 `4b663c19163905a6d2202ee840e86d29efcd903de09725a0988b8f8023e6846b`. This establishes that the rebuilt extension, project compiler and registered preset work together in the current Architectural Generator.

| Fresh Windows gate | Actual completed outcome |
| --- | --- |
| MSVC C++20 optimized main native generation test | PASS, 416,263 assertions |
| MSVC focused Megablock test | PASS, 19,750 assertions; 148 frozen parent full-map hash oracles |
| Predetermined Windows seeds 0–31 versus Linux | PASS, 32/32 full material maps |
| Independent downloaded-map verification | PASS, all 32 hashes recomputed; all 32 raw maps byte-identical to Linux |

The Windows artifact ZIP SHA-256 is `d6c6332f1ea2bee4186085246508fa08e91fabd2f7733071f4ff1b44fc435dac`. Its `parity.json` records exact source c846 and `all_match: true`; I checked every 512×512 uint16 raw map against both that report and the separately downloaded Linux map rather than accepting the summary flag alone.

The Windows main test has four fewer assertions than Linux because the inherited schema-2/3 receipt fingerprints contain ABI-dependent preparation sizes. Its source and execution log explicitly restrict those four captured literals to Linux x86_64/libstdc++ with its C++11 ABI. All 24 legacy material hashes and schema-1 receipts remain checked on Windows, as do all 148 frozen parent material-map oracles in the focused test. No independently built Windows legacy-receipt baseline was produced. Windows evidence here is native C++ qualification and material parity, not a Windows GDExtension build, packaged owner runtime or physical display acceptance.

Machine-readable verification is retained in `megablock-independent-final-artifact-verification.json` and `megablock-independent-hosted-verification.json`. Artifact and run links above make the review independently readable without access to the reviewer's scratch workspace.

## Final disposition

**The acceptance question is answered convincingly within the classic boundary:** one immutable sampler produces visibly different local architectural programmes while maintaining shared structural datums, purposeful negative space, supported connections, a recognizable family identity and reproducible native material output. That conclusion is supported by independent source review, all 32 predetermined seed visuals, actual material interface checks, frozen-parent hash oracles, source-bound artifacts, rebuilt Linux Godot integration and Windows/Linux raw-map equality.

I independently rechecked the live PR records after qualification: parent [#624](https://github.com/techrote/cybersand/pull/624) still points to `615828b28337f85e4663e03ba479616db4ddf764`; [#665](https://github.com/techrote/cybersand/pull/665) remains open, Draft, unmerged and stacked on that exact parent branch/head. The known limits above remain explicit. **GO for final Draft evidence publication; no merge, auto-merge or Ready promotion.**
