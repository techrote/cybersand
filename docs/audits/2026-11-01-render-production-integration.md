---
title: Production render retention and extraction integration
status: Current
document-kind: audit
scope: Frozen-main strict E integration, existing R ownership reconciliation, source-matched qualification and explicit remaining external gates
canonical-for: []
last-reviewed: 2026-11-01
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/configuration-reference.md, ../operations/current-and-historical-validation.md]
---

# Production render retention and extraction integration

## Source and ownership

This pass freezes main `25ce0731d89b9540c2d95cfa8bae321c37e6e118`, tree
`26bac27fb535f15e594dc62df8eac183d7b75fea`. Main was fetched once for selection;
later movement does not silently rebase the candidate. The isolated E branch is
`codex/render-retention-production-20261101`. Native R remains owned by existing
[PR #344](https://github.com/techrote/cybersand/pull/344), branch
`codex/render-copy-production-20261101`, source
`6fff6cf6b75ecfa224bb4e9c0cd341d2453f79e1`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`. No duplicate R implementation is added.
The E-only comparison commit `e62dcf5f` is retained on the frozen main. After
the external R merge described below, the production E branch is explicitly
stacked on the already-selected R `6fff6cf6` source. This is not a refetch or a
silent move to a newer main. Only the E delta is proposed above R; the existing
R observation seams are preserved. Thus production E is the intended combined
path, while the separate E-only comparison attributes its accounting effect.

Historical [#290](https://github.com/techrote/cybersand/pull/290),
[#301](https://github.com/techrote/cybersand/pull/301) and
[#333](https://github.com/techrote/cybersand/pull/333) retain their original
branches and evidence. Their corrected World blob is
`a6afd8cad4264ac2eca0362d14711158e3606760`, also the exact R production World blob.
No historical experiment stack or unrelated material/physical/shader worktree
is merged wholesale. Original worktrees were inspected read-only and preserved.

The task explicitly forbids merging. Another session marked #344 ready under
an earlier R-only acceptance scope during intake. This pass added a no-merge
qualification hold without changing its source. The GitHub connector rejected
conversion back to draft with a permission error. Subsequent read-only API
reconciliation found that `techrote` merged it at 2026-11-01 13:31:41 UTC, merge
commit `809fd30dfac0c5e127302997075be9c4b279e5aa`, whose tree is exactly the
selected R tree above. This execution issued no merge command. The external
merge cannot be represented as an unmerged review candidate or as completion of
the broader hardware/interactive gates. Its original acceptance text is retained
with a dated clarification; no duplicate R PR or automatic revert is created.

## Verified investigation evidence

[PR #335](https://github.com/techrote/cybersand/pull/335) is retained unchanged at
`902fc5b518855911c1b6761a7165573843e567ed`, branch
`codex/render-publication-abc-20261031`; its frozen baseline is
`adaaa37ae35ffcdaa961b80353be3a23b805c0cc`. The evidence document and curated
receipts were read from that exact Git object. Frozen #283 remains historical
evidence at `254235ec4c3d58782bba44b478caca86bf57c856`.

The original Windows paths are not mounted on this Linux executor. The separately
available raw archive was obtained and verified: 13,614,573 bytes, 526 members,
ZIP CRC pass, SHA-256
`cc6d3254bac3c86765ee21e924e2d7fcfec4b3917b2a56ec9ca527d2829e944c`.
This authenticates the supplied archive; it does not claim those Windows paths
or diagnostic binaries are currently available here.

The retained-full-plus-dirty byte-overflow mechanism remains in frozen main.
R's completed hosted paused comparison has normal Control 6/605 retries and R
1/605; withheld ACK gives 595/605 for both. Therefore the earlier R-only judgment
“E NOT NEEDED” is a narrower provisional selection, not proof that R removes
retention feedback. The current owner explicitly authorizes strict E when that
mechanism persists. E addresses retry frequency; R addresses legitimate native
full-copy cost. Neither observation establishes hardware frame pacing.

## Production E policy

The ordinary worker admits exactly one complete current-generation baseline
exemption: its own full-frame byte extent and one six-integer rectangle record.
All subsequent dirty bytes and records count against the unchanged 2,097,152-byte
and 256-record budgets. Exact limits pass; one-over requests existing full
recovery before append. RG8 pending retention is therefore at most 4,194,304
bytes and 257 records. Consumer-held immutable generations and total process
memory are separate from this worker-pending bound.

The baseline remains until a normal valid covering ACK or explicit existing full
recovery replaces the pending publication. No early/synthetic ACK, baseline
drop/rebase, coalescing, serial weakening or new publication policy is introduced.
Current World generation, channels, exact dimensions and contiguous metadata
are mandatory. Invalid/ambiguous state gets no exemption. New-generation dirty
bytes cannot append to an old baseline. Rejected data cannot certify a new
render revision; a required full recovery remains armed until actual validated
full pixels arrive. The legacy `snapshot.cells` keeps exactly the last complete
frame, while immutable patch arrays carry its dirty suffix.

The new retained-baseline regression uses monotonic test-subclass owner counters.
It covers byte/record boundaries, stale/latest/previous-generation ACKs,
reset/replacement, malformed types/metadata/channels, rejected upload/no ACK,
real native reconstruction, published immutability and ordinary tail catch-up.
Existing handoff/Tower synthetic packets are corrected to exercise their real
ownership/serial purpose with honest protocol envelopes. No production trace
counter, clock, observer or per-cell instrumentation is added by E.

Independent review identified a defensive full-recovery hole: retiring an older
ACK could erase the recovery requirement before an incomplete full response.
The correction keeps ACK retirement independent from recovery and requires a
validated complete response before certification. The failure and correction
are retained in the source-bound evidence, rather than inferred from #335's
earlier successful suite. The native adapter currently honors the force request;
this is an adverse-protocol guard, not a claimed observed normal-native failure.

## Source-matched native artifacts

Both baseline manifests bind all 80 baseline native inputs exactly. E changes
GDScript only and follows the explicit reuse rule in the build guide. The E-only
comparison retains baseline libraries; the stacked production E retains R's
published libraries. Its new
script execution requires fresh qualification, not rewritten historical build
ledgers. All 18 required LFS objects were materialized and `git lfs fsck` passed.

| Path scope | Linux SHA-256 | Windows SHA-256 |
|---|---|---|
| Frozen main / E-only comparison | `496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6` | `e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb` |
| R / stacked production E+R | `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45` | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` |

R's canonical [publication run 41301725876](https://github.com/techrote/cybersand/actions/runs/41301725876)
built source `a7ee10f251f647a16dec8a1d7f18c4f299100cba`; publication commit
`c405db68310042089b8bf4aa51c3ea7622312606` appends only two LFS pointers and
two provenance manifests. Actual R libraries are Linux 4,222,424 bytes and
Windows 4,824,064 bytes. All 80 native inputs still match R's tested final head.
The six mismatches in #335 came from its diagnostic native changes; no such
diagnostic source or binary is promoted here. Historical manifests remain intact.

## Native and graphical qualification

Fresh current-R debug and release oracle executions each pass 153,284 assertions,
231 regions, 8,338,180 compared bytes, 42 nonmutation receipts and 18 refusal
checks. The independent scalar getter oracle stays test-only. Fresh Linux
benchmarks use GCC 13.3, `-O3 -DNDEBUG` or `-O0 -g3`, three processes per
implementation/configuration and 41 measured samples per case. All 12 processes,
108 case records and 4,428 measured equality pairs pass. Dense full-frame release
p50/p95/max is Control 31.7566/37.0440/58.8442 ms versus R
1.66373/2.21350/3.39989 ms; debug is 510.464/572.328/707.097 versus
14.6881/17.4570/22.7346 ms. Sparse/absent/dirty-region distributions and every
sample are retained separately. These are shared-executor CPU timings, not GPU
profiling, an exact hash-lookup cost fraction or Windows timing evidence.

The broader graphical campaign is registered separately from #344's paused
fixture. It compares source-selected Control/E/R/combined behavior through real
Main, actual Jet Barrel PLAY, normal ACK, withheld ACK, an explicitly slower
consumer and ordinary reset/replacement. It requires native and Rapier progress,
consumer-complete ordinary tail drain, final CPU/native equality and actual
texture readback. Bounded test subclasses own all timing/counters; any source
observation overlay is authenticated and declared, not called clean-head source.
Campaign outcomes and final exact-head gates are appended after execution.

## Current external acceptance boundaries

This executor has no `/dev/dri` or NVIDIA GPU device and no native Windows
desktop. X11/llvmpipe graphical evidence can establish actual texture-path byte
correctness but cannot satisfy hardware GPU completion/presentation qualification.
GitHub-hosted Windows headless execution is separate from physical desktop
evidence. Required hardware completion latency and interactive presentation must
be measured on an accessible hardware-backed desktop with the final source and
matching runtime identities; CPU `Texture.update` timing/readback alone is not
that evidence. No approval or ready-state claim is inferred from AI review.

## Documentation and validation checklist

Canonical changes cover the bridge behavior, retained ownership, unchanged wire
layout, invariant register and byte/rectangle capacities. The build guide adds
the discovered regression and source-matched reuse boundary. Roadmap/index and
supplementary retrieval questions route to the canonical bridge. Existing corpus
entries already cover those homes; historical audits are not silently inserted
as current behavior. ADR-003, native APIs, Web behavior, user controls, toolchain
pins, licenses and runner/provider policy require no change.

Baseline local Documentation/provenance initially failed on two unavailable
companion records; they were restored from the same pinned companion commit as
CI (`6a58311982941b75f46e22109a0829e5acb83c7e`) outside source. Original failure
outputs are retained. Historical M11 passed 18 records/28 hashes. Frozen
retrieval starts at 19/32 hit@1 and 32/32 hit@5; final values and source-sensitive
checks are recorded after the final edits. No checker is weakened or failure
relabeled as a pass.
