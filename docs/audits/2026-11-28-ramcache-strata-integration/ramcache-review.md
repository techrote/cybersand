# RAMCACHE integration review — 28 November 2026

This is the RAMCACHE specialist's dated integration evidence for
RAMCACHE-STRATA-INTEGRATION-001. It records the source reviewed before the
principal's mainline merge. It does not re-label earlier execution or qualify a
later combined application. The owner explicitly accepted RAMCACHE's physical
Windows functionality and authorised its integration in this mission.

## Source and native custody

| Identity | Inspected value |
| --- | --- |
| Accepted main at reconnaissance | `7a15691a7c537d07ff10a1bc4da9d46491c0b9d6` |
| Accepted-main tree | `6a90d3ea9ff8dada4b50053aa34d830accc50a42` |
| [RAMCACHE PR #745](https://github.com/techrote/cybersand/pull/745) | `af45bfb332f9822780db9304779ff0cdf55661df` |
| Reviewed RAMCACHE tree | `91223c4427ef6896140368f7a28ca6c8e7ba75b0` |
| Native build/application source | `e48deb7fc292ded32bbfd6fb47ecafab4c1b31f4` |
| Native build/application tree | `790b071e118de953f7a063418951e7c7596e6337` |
| Guarded publication child | `fa0c7aa65c1b8a27426da69ae0d62c9227f56479` |
| Windows native DLL | 6,884,864 bytes; SHA-256 `3646940af7df53002db67260b8e45dc9500e434ca755ff0b2fa7c5613eb2c0f3` |
| Linux native SO | 5,617,072 bytes; SHA-256 `1584987d7d3d21474701d5228981ee1821e57f0647975b52a97b6b8642e62583` |

Local Git proves accepted main is an ancestor of the reviewed candidate. The
candidate is 79 commits ahead and zero behind that main. The publication child
has the exact build source as its sole parent, and the reviewed PR head has that
publication child as its sole parent. The seven paths changed since the build
source comprise the Windows DLL LFS pointer, both native manifests, and four
general-suite coverage verifier files. No product GDScript or native source
changed across those two follow-up commits.

The reviewer recalculated SHA-256 from canonical `git show HEAD:<path>` bytes for
every manifest native input: **114/114 match on each platform**, with identical
Windows and Linux input maps and no omissions from the recorded maps. Both LFS
pointers match their respective recorded byte count and binary digest. Runtime
materialisation and actual binary checks are recorded separately below; a
matching pointer alone is not an executable runtime test.

## Existing execution evidence recovered independently

The live [guarded producer run 45943912926](https://github.com/techrote/cybersand/actions/runs/45943912926)
has eight successful jobs, including source-built Linux graphical persistence,
actual Windows recovery, extracted owner evaluator execution and the branch-leased
runtime publication. The owner-tested [Windows artifact 15179331362](https://github.com/techrote/cybersand/actions/runs/45943912926/artifacts/15179331362)
belongs to the build/application source above. Its previously recorded inner ZIP
SHA-256 is `d21822c04a1b233291db34f5699d5fb25793513dc39d807c62822bf7cd9060eb`;
this review does not represent a new physical run of that archive.

The reviewer downloaded both original coverage artifacts of
[general run 45968901250](https://github.com/techrote/cybersand/actions/runs/45968901250),
checked their ZIP CRC and recalculated their full archive SHA-256 against the
GitHub artifact digests. The decoded receipts bind the actual reviewed PR head
and tree, not just a branch label:

| Original receipt | Source-bound recorded result | Archive SHA-256 |
| --- | --- | --- |
| Linux artifact `15185512638` | `passed`; 480 cases in 32 shards | `34039596272da03af7a3f11e290c909a6d7f73db041b425a9c28254b0ae6d793` |
| Windows artifact `15185278645` | `passed`; 457 unique applicable cases in 30 shards; 487 original logs verified by the producer | `ad7e7b9db7fb84290a97b227120fad6a8eba3194b46d54ffe6d91a067fb78c8f` |

This review checks those original aggregate receipts and their transport
integrity. It does not claim to have independently replayed all raw shard files.
The original general run's earlier aggregate refusal remains failed; its command
reconstruction correction and the fresh run above do not rewrite that history.
The live [collaborative Art run 45968908059](https://github.com/techrote/cybersand/actions/runs/45968908059)
has all four jobs successful, including displayed Linux controls and the Windows
extracted installation.

## Durability and ownership review

The review followed the existing controller, cache, immutable writeback owner,
storage schema, Main handoff and ordinary-launch fixtures. No bounded RAMCACHE
product repair was justified by this inspection.

- Active gameplay retains one native World on the existing simulation owner.
  HOT entries transfer unique native ownership; WARM continuation and COLD
  durable storage remain distinct. Native receipts fence identity, generation
  and completed work.
- Deferred travel remains optional. Its retained source and admitted destination
  can be handed off before disk publication, while Save all and normal exit
  require the applicable positive durable acknowledgement.
- Background writeback owns copied immutable values on one I/O thread, with one
  in-flight batch and one coalesced metadata request. A prior capture's ACK may
  advance durable metadata without clearing newer dirty work.
- Cache admission includes growth/preparation reservations. The mandatory active
  exception does not admit speculative inactive Worlds. Dirty eviction refuses
  until a sufficiently new durable authority is acknowledged.
- An uncertain native completion or publication stays retained for exact Retry.
  Failed native state remains quarantined. Normal Save & Menu refuses to discard
  it; explicit healthy-area recovery has its own disclosure and acknowledgement.
- The stored authoring envelope remains exactly `setup`, `definition`,
  `generated_packet`, `material_baseline`, and `camera`. Live actors, host
  emitters, alternate solvers and arbitrary layered scene replacement remain
  outside the three-area continuation domain.

The relevant current contracts remain
[native residency](../../systems/persistent-area-residency.md),
[persistent authored areas](../../systems/persistent-authored-areas.md) and the
[owner runbook](../../operations/persistent-area-ramcache-evaluation.md).

## Strata boundary requiring combined verification

The older Strata source adds its controller, scene loading and authored Save
route without knowing about the later persistent-area host. A syntactic merge
alone could therefore expose unsupported Strata composition in a profile whose
checkpoint schema cannot retain it. The Strata specialist owns the bounded
repair: refuse Strata admission/scene replacement explicitly while a persistent
profile owns the World, before native decorative World allocation or authored
document adoption. Preserve the normal Persistent Areas save route and unchanged
ordinary Workbench functionality.

Fresh combined tests must prove that refusal leaves active native identity,
authored state, durable revision and camera intact; ordinary Strata and
Persistent Areas must each remain accessible through their respective existing
launch paths. Do not extend the persistent schema, invent simultaneous feature
support or infer it from separate successful feature tests.

## Excluded ObjectShard implementation

The dynamically inspected [ObjectShard PR #754](https://github.com/techrote/cybersand/pull/754)
was still open and Draft at head `1ec3f214662f7d5a0a38ff727b684c15b41c067b`.
GitHub's comparison to RAMCACHE reports divergent histories, with common ancestor
`78e8d626c8ac2c5764c270ce7060732d33299d88`: excluded M4 is not an ancestor of this
candidate. That observation is supplemented by implementation checks rather than
treated as sufficient by itself.

The reviewer obtained #754's actual changed-file inventory and checked its 127
ObjectShard-specific native, Godot and tooling paths, including
`material_lifecycle.hpp`: **none exists in the RAMCACHE tree**. A source scan of
Main, the worker, native registration/adapter/kernel sources, build scripts,
project settings and the class cache found no ObjectShard implementation symbols,
M4 runtime hooks or the reported `SegmentMotionEnvelopeExceeded` /
`CompletedMainPoseCaptureFailed` paths. The only ObjectShard text in those source
areas is an existing Material Audition capability description explicitly stating
that this ownership is unsupported. The native manifests contain no ObjectShard
input, and all recorded RAMCACHE native inputs match.

## Owner acceptance and retained limitations

The owner reports successful persistent travel, authored/evolved state retained
after full application restart, roughly 200 ms deferred HOT travel between
Industrial Fire and Foundry Gallery, roughly 3.2 seconds into Waterworks even
while paused, and successful preparation initiated by hover. These are owner
observations supplied for this mission, not new measurements made by this agent.
The Waterworks delay is accepted and does not justify a scheduler rewrite.

Source confirms the deliberately conservative existing preparation budgets:
HOT at most two ticks or 5 ms per speculative pass; WARM/COLD at most 32 ticks or
100 ms; automatic prediction consideration approximately once per second.
Indivisible native ticks and actual debt still determine the latency. Those
budgets are unchanged.

The feature is opt-in through Persistent Areas. Its initial session settings are
512 MiB cache, strict durability, background saving enabled and preparation
disabled. Deferred travel requires **Allow travel before disk saving finishes**
and **Apply cache settings**. Ordinary Workbench Water and actor defaults retain
their existing behavior. Existing profiles are bound to the exact native binary
identity; no general migration or broader GEN-006 completion is claimed.

## Local verification scope

At reviewed head `af45bfb3`, `python3 tools/ci/test_verify_linux_godot_shards.py`
passes all 14 tests. The first local `check_repository.py` invocation correctly
reported six missing expected-fact references because the separate pinned
companion workspace had not been materialised. That environment failure is
retained; it is not a source defect or a waived provenance check. The exact
companion records are subsequently recovered from workflow-pinned commit
`6a58311982941b75f46e22109a0829e5acb83c7e` before rerunning the check.

After the exact five referenced companion files and all 20 Git LFS payloads were
materialised, `python3 tools/ci/check_repository.py --require-materialized`
passed: no documentation, dependency, native/Rapier/reciprocal provenance or
actual-binary errors. The documentation portion checked 186 pages, 334 canonical
claims, 4,461 local links and 33 retrieval questions. The exact pinned official
Godot `4.7.stable.official.5b4e0cb0f` then completed a headless editor import.
Its executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
Headless local execution does not establish graphical acceptance.

Eight unchanged focused fixtures then passed in fresh headless processes using
that pinned engine and the materialised source-matched Linux runtime. Each had
a 300-second process watchdog; no fixture exceeded 11 seconds. The original
commands, exit results, durations and log digests are in the adjacent
[machine-readable review](ramcache-review.json).

| Existing fixture | Successful assertions/checks |
| --- | ---: |
| Persistent-area clock | 28 |
| Background clock | 1,524 |
| Cache ledger/admission | 470 |
| Immutable writeback | 63 |
| Metadata bounds | 145 |
| Native continuation bridge | 136 |
| Native residency | 1,584 |
| Native ownership adversarial review | 66 |

All **4,016 checks** passed. The native residency fixture performed 188 actual
HOT ownership transfers. That adapter fixture's timings are not the complete
Workbench travel latency and are not substituted for the owner's observations.

The standalone documentation check also passed. The retained M11 integrity
check passed 18 historical records and 28 source hashes; that result is
explicitly historical integrity, not acceptance of the current runtime.
The lexical retrieval evaluation completed all 33 questions, finding the
canonical document first for 19 and within the first five for 31, with MRR
0.7197. These are search-quality metrics, not proof that each answer is correct;
the two misses remain recorded in the original evaluation output.

The final mainline/combined-source qualification, publication-reuse decision,
actual archive identity and extracted Windows launcher results belong to the
principal integration ledger. Existing RAMCACHE execution cannot alone certify
the later Strata reconciliation.
