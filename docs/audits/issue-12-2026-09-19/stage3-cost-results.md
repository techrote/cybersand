---
title: Integrated Stage 3 discovery costs, 2026-09-19
status: Current
document-kind: evidence
scope: Whole-system World producer, journal and connectivity cost model on Ryzen 2600X; read-only discovery only and no acceleration claim
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../operations/soliding-measurement.md, ../../operations/soliding-stage3-freeze.md, ../../systems/settled-region-discovery.md, ordinary-sleep-results.md, journal-cost-results.md]
---

# Integrated Stage 3 discovery cost results

## Result and evidence boundary

**Measured, 2026-09-19:** all **276/276** preregistered processes passed. All
cross-arm cohorts ended with identical authoritative content hashes. Three complete
repeats retained both normal and reversed process order, workers 1/4, quiet sizes
512/1024/2048, dynamic negative/positive controls, a 2048 sparse-edit case and a
translated negative-coordinate ring. No timeout, nonzero exit, malformed record or
cohort mismatch was removed. Before/after contender snapshots were empty.

This is a Stage-3 **cost model**, not a speedup. Current ordinary sleep has no
discovery manager and its discovery counter groups are recorded as not-applicable
JSON `null`. The complete candidate timing includes edit, World tick, journal feed/
copy/local extraction and region traversal. It does not include rendering, Godot,
Rapier, browser execution or any Stage-4 acceleration benefit.

The earlier complete run at commit `40db9f9` is retained under
`stage3-cost-registered-40db9f9`, but it is superseded for cost interpretation:
its candidate p95 omitted journal/region service and did not separate epoch clears.
All 276 processes passed, but accepting those timings would undercount discovery.
The corrected `2919106` campaign below was prepared and rerun from scratch.

### Post-campaign exact-head qualification

The repaired integration source at `7f681ec47fcc29f09a5736377e60c3ece5441074`
differs from the measured `2919106` runtime inputs only in four whitespace-only
statement-layout corrections in `settled_regions.hpp`; the harness, driver and
measurement contracts are unchanged. A fresh immutable artifact produced executable
SHA-256 `6c66f5a8dbe3759a61aed314cb63e3ff37255e1ceccca017ed28eabceef3ffce`,
which differs from the measured executable because the PE timestamp and path-bearing
metadata differ. Direct section extraction proves identical semantic payloads for
both executables: `.text` `f50e4749ecc923c3327ff56569373914263d5b04e16c1a643c9ccaac7bb09fad`,
`.rdata` `faa1b5251762b52ae235669062a87c92a84a3787bfd4eeaa34f6f7d49bd22984`,
`.data` `3d3b3a01678b4e3a7b28ad15bbbfdef660b0c12da8a534390a95c0ee01789e1b`
and `.pdata` `0ad3162f2a1b134a6f45c57a845154a10c8d2ea79eb80dee6df3c76e8329f7ad`.
The fresh artifact also passed the separate seven-case smoke 7/7. Raw qualification
outputs are retained under `stage3-cost-artifact-7f681ec`,
`stage3-cost-binary-compare` and `stage3-cost-smoke-7f681ec` in the dated local
evidence root. Therefore the 276-process timing record remains applicable to the
runtime semantics; the smoke timings are not pooled with it and no new performance
claim is made.

## Exact identities

| Input | Identity |
|---|---|
| Candidate commit | `2919106d9a8b3b91bab442fbb0e34bdee1b35afc`; clean working status at freeze |
| Compiler | LLVM-MinGW 20260826 UCRT Clang 23.1.0; C++20, `-O3 -DNDEBUG -flto -pthread` |
| Compiler SHA-256 | `bf58cf0e544a308660645aad1fe65ae9cbc44b0871e4010278f3d9551f86a690` |
| Executable SHA-256 | `4340345cc8b56d8655e1570d052b281ff5d638833054dba1b8f3477cf22dcc7d` |
| Artifact-manifest SHA-256 | `472f901a51d6031c633fde153a7391f1c87b663847a32a7450dbc8a482325c62` |
| Run-plan SHA-256 | `6bab61a50fb845a7feee9eac253fcfaca3940f8f227782854be3d80c912fc263` |
| Raw-results SHA-256 | `265106ec1b458b99a7ac90f84068a6ac76d44b3c689b5c6b325e46710a8fd462` |
| Summary SHA-256 | `055e06bbc54812bfa86b0a2718a562861e366eff976375b42b75a0a70fafe906` |
| Host | AMD Ryzen 5 2600X, 6 cores/12 logical; 34,265,985,024 physical-memory bytes; Windows 11 build 26200; Balanced plan |
| Interval | 2026-09-19 05:41:05.626854–05:43:27.239947 Europe/London; 137.873 summed child seconds |

Frozen artifact inputs are under
`C:/kybersand/validation/local/issue-12-2026-09-19/stage3-cost-artifact-2919106/`.
The plan, every stdout/stderr/execution record, incremental `results.json` and final
`summary.json` are under the sibling `stage3-cost-registered-2919106/` directory.
The seven-case corrected smoke is separate and excluded from the 276 results.

## Quiet-world decomposition

These are median milliseconds across three repeats for workers=1. Complete p95 is
edit + tick + services. Setup includes fixture writes and producer notifications.
The connectivity arm's initial-journal column includes the journal scan, the second
exact cell copy, local component extraction and boundary-adjacency maintenance;
initial-region is the separately timed resumable region-graph traversal.

| Side | Arm | Setup | Ordinary tick p95 | Complete p95 | Initial journal/feed | Initial region | Peak RSS bytes |
|---:|---|---:|---:|---:|---:|---:|---:|
| 512 | Current | 11.8776 | 0.0024 | 0.0024 | N/A | N/A | 9,932,800 |
| 512 | Producer | 72.0159 | 0.0292 | 0.0293 | not serviced | N/A | 12,558,336 |
| 512 | Journal | 72.0099 | 0.0281 | 0.0282 | 4.5676 | N/A | 12,554,240 |
| 512 | Connectivity | 91.9056 | 0.0280 | 0.0282 | 16.8769 | 1.2566 | 80,314,368 |
| 1024 | Current | 48.2540 | 0.0105 | 0.0105 | N/A | N/A | 16,715,776 |
| 1024 | Producer | 284.5306 | 0.1260 | 0.1261 | not serviced | N/A | 19,431,424 |
| 1024 | Journal | 283.2126 | 0.1258 | 0.1260 | 18.3395 | N/A | 19,427,328 |
| 1024 | Connectivity | 322.4620 | 0.1247 | 0.1249 | 97.1554 | 5.8611 | 87,199,744 |
| 2048 | Current | 193.4748 | 0.0626 | 0.0639 | N/A | N/A | 43,220,992 |
| 2048 | Producer | 1134.9401 | 0.5395 | 0.5397 | not serviced | N/A | 46,239,744 |
| 2048 | Journal | 1135.7959 | 0.5604 | 0.5608 | 74.6033 | N/A | 46,235,648 |
| 2048 | Connectivity | 1334.6222 | 0.5465 | 0.5466 | 961.7359 | 36.9600 | 114,003,968 |

Workers=4 produces the same qualitative decomposition and authoritative results.
The idle steady overhead is almost entirely the producer's resident activity/deadline
metadata feed: journal and connectivity service are quiescent after initial drain.
At 2048² the producer raises ordinary p95 from 0.0626 to 0.5395 ms. Connectivity
adds little steady idle time beyond that but makes startup/local extraction much
more expensive.

The compiled connectivity object is **67,703,136 bytes** and the coordinator/journal
reports **3,058,080 bytes**, fixed across occupancy. Median connectivity-minus-Current
peak RSS is about 67.1–67.5 MiB. Fixed connectivity bytes per represented source
cell are approximately 258.3 at 512², 64.6 at 1024² and 16.1 at 2048². This is a
material small-world penalty, not a capacity recommendation.

## Dynamic costs and bounded negative results

Workers=1 median complete p95 values across three repeats:

| Fixture | Side | Current ms | Connectivity ms | Absolute excess ms |
|---|---:|---:|---:|---:|
| local edit | 512 | 0.0176 | 1.6202 | 1.6026 |
| local edit | 2048 | 0.0754 | 39.3214 | 39.2460 |
| bridge add/remove | 512 | 0.1407 | 3.0962 | 2.9555 |
| churn | 512 | 0.0677 | 2.3924 | 2.3247 |
| mask add/remove | 512 | 0.0158 | 0.6448 | 0.6290 |
| pending event | 512 | 0.0147 | 0.4087 | 0.3940 |
| exclusion/re-entry | 512 | 0.8679 | 19.4216 | 18.5537 |
| granular rest | 512 | 0.0025 | 0.0300 | 0.0275 |
| granular release | 512 | 0.0151 | 0.1667 | 0.1516 |

All paired complete-p95 comparisons cross the programme's >15% review trigger;
very small Current denominators make percentage ratios visually extreme. Absolute
cost is therefore retained alongside ratios. No quiet Wall/RedBrick epoch-clear
comparison crosses the separate >1 ms excess trigger: the largest retained median
excess is 0.8492 ms for 2048² Wall, workers=1 (4.1083 to 4.9575 ms).

The 2048 local-edit cost is dominated by bounded whole-region rediscovery: median
region-service p95 is about 36.2 ms and the deterministic run performs 1,351,685
connectivity work units. A tile edit immediately retires the one 4096-tile region;
the next complete publication must scan canonical seeds/dependencies again. This is
safe and bounded but not local-cost scaling.

At 512², bridge and churn publish 193/129 generations and retire 192/128 respectively.
Exclusion/re-entry repeatedly rescans complete tiles: journal p95 is about 17.18 ms.
Mask churn and pending events correctly publish no partial replacement after the
initial region; representative runs retain 955/698 refused builds and end with
RevisionChanged/UnknownBoundary refusal. Granular rest ends with two stable regions;
granular release is a positive-motion control and remains incomplete while activity
continues. These refusals are accepted safety outcomes, not missing results.

## Interpretation and Stage disposition

- Producer metadata passes dominate quiet steady overhead and fixture-write setup.
- Exact journal scan alone is moderate (74.6 ms initial at 2048²), while the integrated
  copy/local-component feed raises that phase to about 961.7 ms.
- Region traversal is inexpensive for one initial uniform large region (37.0 ms at
  2048²) but expensive after sparse edits because the present seed/dependency search
  revisits the large connected candidate.
- Fixed 4096-tile connectivity storage is material even for small worlds.
- Capacity/refusal never changed World material, all workers1/4 cross-arm content
  hashes matched, and no partial region was used to hide lag.

This campaign satisfies the whole-system CPU/memory/latency and large-world churn/
fanout measurement items for the bounded Stage 3A reference. It rejects any claim
that read-only discovery is free or already an acceleration. It does not choose a
Stage-4 representation or threshold. Stage 3B must first resolve or explicitly
disposition the observed locality/scalability failures; only then may a Stage-4
bake-off compare alternatives against Current ordinary sleep while accounting for
these producer, feed, rebuild and fixed-memory costs.
