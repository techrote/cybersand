---
title: ObjectShard external Fire reviewed World consumer transition
status: Historical
document-kind: audit
scope: Append-only authentication of the inherited 001R Fire opportunity guard; no native, runtime, material identity or production-default change
last-reviewed: 2026-11-22
related-documents: [2026-11-22-objectshard-world-transition.md, 2026-11-22-objectshard-m3-final-qualification.md, ../operations/material-catalogue-shadow.md]
---

# ObjectShard external Fire reviewed World consumer transition

Status: **Draft/HOLD**, completion in PR #741 for programme #281. The owner
authorized recovery, scoped implementation, independent review and integration
preparation; this record admits exact reviewed inherited source bytes through
the existing compatibility mechanism. It does not publish a native runtime,
change production defaults or authorize any merge or physical acceptance.

## Exact protected source

| Identity | Value |
| --- | --- |
| Protected consumer | `native/src/world.cpp` |
| Previous reviewed source | `5afe5643097c543f7d8a6840ced9afac58dd053e` |
| From LF SHA-256 | `bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214` |
| Exact source commit introducing the further edit | `c06550371ac5448642bff7e4ecb64fe9cd1df728` |
| To LF SHA-256 | `5bb8ccded21bb73077ea86086d6fb25b9cbca67bda84013e67fa87d96b1c8cd1` |
| Same protected bytes in qualified 001R | `514d76fbf4df30eb05353bc14b6a4ec3ea9bf61c` and #738 `44abd754d014a44078a41792d2d46967a9b8cf30` |
| Same protected bytes in qualified M3 | `e034f2294663e0485cfb9adcc8ada46a6e977cee`, tree `246e7324ca618d98c43a0ed54fe19bc86a155877` |
| Frozen compatibility-lock LF SHA-256 | `8b4d3351cbe4380e976655d10dc34c4bf9e81d95442719a53770b62d219183dc` |

The previously admitted ObjectShard transition ended at `bc24ccd2`. The finisher
subsequently changed the protected source but omitted the next reviewed entry.
The failure is reproduced by ordinary documentation runs
[44989675198](https://github.com/techrote/cybersand/actions/runs/44989675198)
on #738, [44999120750](https://github.com/techrote/cybersand/actions/runs/44999120750)
on qualified M3, and [45002794045](https://github.com/techrote/cybersand/actions/runs/45002794045)
on the M3 evidence descendant. Their material-catalogue failure is distinct from
the six retained native-runtime provenance mismatches; the Draft workflow skips
that separate provenance step.

## Reviewed behavior and claim lifetime

The complete `world.cpp` delta from the prior admitted source is one predicate:

```cpp
if (slow_interaction_due(10U) && (object_shard_mutations_ == nullptr ||
    !object_shard_mutations_->external_fire_claimed(x, y, tick_index_))) {
```

It replaces `if (slow_interaction_due(10U))` around the existing Fire ignition
attempt. An ordinary World with no ObjectShard mutation journal short-circuits
to the exact prior condition. The deterministic sample, ignition state value,
remaining Fire lifetime, gas transport, thermal behavior and surrounding rule
order are unchanged. Material IDs, descriptor bytes, capabilities, reaction
ordinals, quantity schema, policy identities and the frozen lock are unchanged.

The admitted experimental behavior is deliberately different only when a real
external Fire opportunity has already been claimed by a recorded contact with
shard-owned Wood. The resulting shard chemistry is applied after `World::tick`.
Mechanical displacement must not let that same opportunity also perform its
sampled World ignition in the immediately following native tick. A claimed
opportunity suppresses that one `ignite()` call for any target material the
ordinary call supports. The coordinator lends its
bounded, read-only per-cell claim span to the mutation journal around exactly
that `World::tick` call. The query checks the exact tick, nonempty span,
coordinate inside the watched bounds and claimed bit. The span is cleared on
both normal completion and exception. No claim creates new Fire, changes the ordinary Wood burn law,
prevents later unclaimed opportunities or freezes the Fire cell's lifetime or
movement.

This is an explicit opt-in ownership correction, not a claim that the enabled
ObjectShard path is behaviorally identical to a World without ObjectShards.

## Existing exact-source execution and independent review

The published [M3 campaign 44999117090](https://github.com/techrote/cybersand/actions/runs/44999117090)
freshly rebuilt the unchanged native implementation. Its six native ASan/UBSan
suites pass 93,529 checks, including the 3,683-check external-Fire suite. All 192
unfiltered ordinary World cases pass naturally. The external-Fire tests cover
single-use ignition opportunity ownership, retained source lifetime/transport,
reset and refused-motion recovery. Actual Windows/Linux Godot and delivered-ZIP
qualification remain attributed to `e034f229`; this audit does not relabel them
as execution of the compatibility tool change.

The independent physics and custody reviewers examined the two-line source
delta, ordinary null-journal path, claim authority and lifetime, exact source
ancestry, retained execution receipts and package inventory. They recommended
the existing append-only transition mechanism. Their completion evidence is
retained separately from their already-sealed runtime reviews; the final M3
qualification addendum records guard/tool validation results after publication.

## Guard integrity and qualification boundary

The only executable-tool edit appends one `REVIEWED_TRANSITIONS` entry for this
protected, non-identity consumer. It does not change `BASELINE`, the compatibility
lock, source-role or identity-input sets, Git-history checks, record validation,
hash normalization, target equality, generated metadata or any refusal rule.
The original source commit must remain reachable. A future edit of the consumer
still requires a separately reviewed successor entry, and unsupported identity
changes remain cutovers rather than per-file transitions.

`compatibility.py` is absent from the qualified native compilation, native build,
Lab/runtime, ObjectShard qualification-tool and Windows packaged input sets.
Native/Godot code, both bundled guides, packaging, verifier, selected engine and
Rapier inputs remain unchanged. The owner ZIP remains the qualified 93,168,827-byte
delivery with SHA-256
`61678a8c8ae3ab8e3b05cbb624fe15b4b259710fd879aa209542583a78b74a0b`.
No platform rebuild is claimed or required by this guard-only completion.

The resulting HEAD is a compatibility-tool/evidence descendant, not purely a
documentation descendant. Its final guard tests and ordinary workflow result
must be reported separately. The six production native-provenance failures
remain unpassed and require future authorized runtime publication.

## Dependency-ordered mergedown

The proposed order remains #726 -> #728 -> #730 -> #738 -> #741. Before a future
owner-authorized #738 merge, carry this reviewed entry and its committed record
onto that earliest dependent head containing `c06550371`, then validate its
exact resulting source and all applicable ordinary gates. This mission does
not change the donor #738 branch. The source ancestor and prior reviewed chain
must survive by merge commits; squash/rebase would require an explicit reviewed
repointing to the resulting retained source. A successful material-catalogue
check does not satisfy the separate native-runtime provenance gate.
