---
title: MAT-003 isolated resident reentry and scratch provisioning repair
status: Current
document-kind: audit
scope: Source-only repair, adjacent code review and independent closure; builds, cases and timing held
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-containment-correctness-attempt.md, ../research/mat003-correctness-only-plan.md]
---

# Source diagnosis and repair boundary

Owner authorized isolated investigation/fix and independent source review, including review of accessed code for adjacent bugs. Intake is1bf96938a2c9928965c2df7ca77e8528f9c721e7 on codex/mat003-continuation, source workspace C:/Users/_/.codex/worktrees/mat003-continuation/khybersand, origin techrote/cybersand. The preexisting same-content wclear-admitted-registration.json status marker remains untouched. Required LFS/dependency pins, accepted source/evidence and production remain unchanged; no tag at intake HEAD. Raw output stays outside Git.

The [authorized86345703 attempt](2026-10-23-mat003-containment-correctness-attempt.md) remains incomplete:15 exit0 processes, resident-015 failed on attempted257 after clear256,136 unattempted. Its final4203-entry inventory, independent refusal and complete4256-entry archive SHA-256842d9444c8c376060014e5a5b7b739b2ed89e96165459f551defbff8b27aada4 remain immutable. The prior293-tick fixture failure and failed warning build are also retained. Nothing is rerun or reconstructed.

Inspected native/src/world.cpp begin_tick, gather_active_cores, finish_tick, set_simulation_region and write-domain preparation explain the failure. gather_active_cores checks its capacity before sorting/uniquing: each aligned32-square activity block appends one64-square core, and four blocks can append the same core. The128-entry cap was insufficient for a newly included512-square window's worst-case256 entries. This is not evidence of128 distinct jobs, cache behavior or a carrier defect. begin_tick lists all active resident chunks, including excluded ones; excluded blocks do not age to sleep. A second latent fixture defect was the2048 grid's64 active-chunk cap: the list is not clipped to interest and can exceed64; provisioning the full256 resident population supplies a conservative bound. Its old1024x2048 initial selection could independently require512 unique cores/2048 raw entries, beyond the64-core target. No failed2048 run is claimed.

# Bounded replacement fixture

Only tools/experiments/mat003_correctness changes. The historical reviewed plan/hash and both failed registrations remain unchanged; this dated source supplement changes the exact64 resident cases and future verifier, requiring a new registration. The other88 case schedules are unchanged. Source cases() now labels resident fixture bounded-reentry-v2 and records exact regions/capacities.

| Resident side | Full resident cells/chunks | Initial interest | Reentry interest | Core scratch entries | Active-chunk scratch |
|---|---:|---|---|---:|---:|
|512|262144 /16|origin256x512|origin512x512|256|16|
|2048|4194304 /256|origin256x512|origin512x512|256|256|

At guarded chunk128/block32/core64/radius2 geometry, initial selection has at most32 unique cores/128 pre-dedup entries; reentry has64/256. The core scratch also provisions parallel result/physics arrays;256 entries are a list bound, not permission for256 unique jobs. The reader retains its64 scheduled-core cap. Chunk scratch covers the entire resident population, without pretending interest clips begin_tick's list. This provisioning is isolated apparatus configuration, not a production scheduler correction or owner-budget compliance claim.

The512 fixture retains its original initial selection and full-world reentry;2048 deliberately narrows both. Full2048 reentry is NOT qualified by this replacement. Full resident clearing and all eight complete B/P/Q/R endpoint datasets per process remain required for both sizes. Both roles still have255 setup ticks, real Q256 and four reentry ticks throughR260. Before Q is captured, interest/selected/applied remain initial; the reentry request follows Q and is applied by the next begin_tick. No synthetic activity reset, direct scratch mutation or clear substitution is introduced.

Resident input pulses use x16,80,144,208 (Sand at x+8), ticks248 through255 only in the active scene, for both sizes; the small schedule stays unchanged. Excluded Sand at504,8 is inside future reentry and safely outside initial selection. The independent reader requires this witness unchanged at B/P/Q and moved downward within the newly included region atR; totals still come from every resident cell and the complete input ledger. Current Sand movement is radius1 and the witness is eight cells from the outer boundary; four reentry ticks leave halo room. The boxed central Water/Sand setup, temperatures, neutral/high-state seeds, resident anchors and floor remain. Distant residents can remain excluded afterR at2048, while the clear traverses all of them.

# Adjacent code review and closed findings

Reviewed world.cpp, matrix.py, readback.py, world_oracle.py, negative.py, probe.inc, lifecycle.hpp and their production scheduling/region/movement interfaces. Production paths supply source semantics; no native/Godot/Water/GEN-006 implementation is edited.

| Finding | Source-only disposition |
|---|---|
|Observed pre-dedup scratch exhaustion|Provision256 entries with geometry guard and independent literal region/config proof. Runtime repair unproved.|
|Latent2048 active-chunk exhaustion and oversized selected work|Provision256 chunk entries; bound selected work to64 unique cores. Explicit coverage change.|
|Reader accepted population count without exact coordinates|Require the entire origin-aligned chunk grid for every World role, in addition to owner/stride/overlap checks.|
|Inactive flag did not prove a sleeping resident|Independent review required the same included chunk inactive/quiet>=3 and all16 blocks inactive/quiet>=3; exact patch now checks this.|
|Paused/resumed witness and configuration could drift|Reader independently checks literal geometry, capacities, complete grid, selected/applied interest, sleeping/excluded activity and excluded Sand before/after reentry; inputs independently bounded.|

Nine new future rejection fixtures cover core/chunk cap drift, wrong interest/applied coverage, all-active or inactive-but-unaged sleep claims, shifted grid, prematurely simulated Sand and Sand never resumed. They join the prior18 negatives and decoder cross-check, but **none is executed at this checkpoint**. Missing witnesses refuse qualification; no fallback or automatic retry exists. Static review found no additional definite blocker in the accessed probe, input/refusal/lifecycle, stamp, region-application and reader-comparison paths. This is bounded inspection, not proof those paths are bug-free or that watchdog/output/sanitizer budgets will pass.

# Independent source review and next gate

Independent reviewer /root/independent_review inspected the exact seven-file source patch without executing it. It identified the sleeping-witness gap, then re-read the corrected implementation and closed it: no remaining definite implementation blocker identified. The compact [source review record](mat003-correctness-2026-10-23/resident-reentry-source-review.json) binds canonical LF input hashes and the explicit limits. Source-only closure is neither binary admission nor runtime success.

No generator, apparatus import, build, candidate, verifier negative fixture, qualification case, probe or timing was run. Static Python AST parsing and repository documentation/retrieval maintenance are the only executable checks in this checkpoint. No new execution registration or authority is supplied. Old certificates/authorization cannot admit changed source. Next requires separate build-only authority at the frozen repair commit,32 fresh builds, independent binary admission, then a newly sealed/reviewed152-case execution registration and owner hash authorization. Linux remains unqualified. R16-T1 conditional, PR211/221 draft, production unchanged; no new timing authority.

Documentation checklist: canonical continuation report/roadmap/index/handover route current source versus historical runtime; historical audits and reviewed plan remain immutable. ADR/schema/owner budgets are unchanged because no semantics, production layout, lifetime/interface, dependency, persistence or user control changes. Root README remains unaffected. Retrieval adds one supplementary question, preserving all131 prior objects and frozen32. Exact source/check outcomes follow in the compact review record. Publication uses [skip ci].

## Frozen repair identity and maintenance

Repair source commit e655166989661617cd8d6cb4d58a71b9d88c9467, treec302420be202ac05f393c556375bf4acf7686089, contains only the seven reviewed isolated apparatus files. The compact review record verifies every LF hash against Git. Final independent review matched the descriptive contract revision and required one audit correction:256 is a conservative resident-population bound, not a measured active count for the old fixture. That wording is corrected. No definite source blocker remains identified.

Static AST parsing, docs/current-repository/historical M11 and diff checks passed. Frozen32 lexical retrieval stays21 rank1/32 top5/MRR0.7937; the132-question supplementary set has106 rank1/131 top5/MRR0.8822, new MATSCHEMA13 rank1. Prior131 objects and frozen32 are unchanged; C09 remains the disclosed lexical miss. The existing complete failure ZIP was rehashed read-only and still matches842d9444c8c376060014e5a5b7b739b2ed89e96165459f551defbff8b27aada4. Maintenance outputs are local ignored build/mat003-continuation/reentry-*. No runtime library materialization or runtime acceptance follows the repository check.
