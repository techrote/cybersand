# OBJECTSHARD-001 native performance qualification

The repaired M2 native source passes all **74 registered performance limits**.
Every measured source input matches commit
`1bb6185be05f5ef838543a0e13c81428b751d969` (Draft/HOLD PR #730).
These measurements cover native C++ execution with synthetic pose inputs and
exact protocol receipts. They do not establish Rapier stepping, Godot resource
installation, presentation performance, Windows execution, or owner acceptance.

The supplementary full-tree comparison also passed exact material equivalence.
It found a real tradeoff: compact storage uses less memory, while the tuned
miniature World's scheduler is faster for this sparsely reacting stationary
tree. There is no claim that compact chemistry is universally faster.

## Reproduction and source custody

Run the committed benchmark and its previously registered native budgets:

```sh
python3 tools/objectshard/run_benchmarks.py --qualify \
  --output build/objectshard-benchmarks-final --jobs 2
```

The authoritative run is
`build/objectshard-benchmarks-final/20261122T014005.798855Z-5977462b93e0/`.
Its `inputs.json`, `builds.json`, compiler logs, executable, `benchmark.json`,
`summary.json`, and `commit-binding.json` retain the chain of evidence.
The [retained evidence manifest](objectshard-001-20261122/manifest.json) also
contains the JSON results, input hashes, source binding, and a reproducible
full-tree harness patch without committing binaries or logs.

| Identity | Value |
| --- | --- |
| Native input digest | `5977462b93e0589aefbdc6b6d2e94d3f61c804e921a80e40dcf9a6cf1e3bd5f6` |
| Executable SHA256 | `f9b9927c056bf83d166c1090e6cdf0ce899bd9b0989e32593760cbf2c52aa58d` |
| Coordinator SHA256 | `048411c19605f52c9a25793ca7752e7b8f2ad7248dffb934762e209c0c834078` |
| Contact helper SHA256 | `69c4682e277380866b97600eb941eaf8288b39df1c6fea8b12913006f616407f` |
| Source-to-commit binding | 92 source files checked; zero mismatches |
| Host | Intel Xeon Platinum 8573C; Linux x86-64; GCC 14.2.0 |
| Build | C++20, `-O3 -DNDEBUG`, no LTO; one native owner |

The source snapshot was captured before the M2 commit existed. The separate
binding receipt verifies every captured file against the published commit's
Git blobs, rather than relabelling an older build by its current branch name.

## Registered budgets and observed native frames

Budgets were registered from the initial measured baseline before this final
run: p95 at most 2 ms, p99 at most 10 ms, maximum at most 50 ms, no steady C++
allocations, live/peak requested C++ bytes at most 6 MiB, registry retention at
most 256 KiB, and applied geometry age at most one semantic tick.

Each row contains three independent constructions and 480 semantic ticks per
construction: **1,440 native frame samples**. A native frame includes the actual
Coordinator step, native snapshot, and synthetic geometry acknowledgement.

| Workload | p50 ms | p95 ms | p99 ms | Maximum ms |
| --- | ---: | ---: | ---: | ---: |
| Empty Lab | 0.536 | 0.723 | 0.877 | 4.715 |
| One inert stationary tree | 0.750 | 1.046 | 1.317 | 8.999 |
| One inert moving tree | 0.749 | 0.995 | 1.577 | 5.070 |
| One reacting tree | 0.759 | 0.980 | 1.200 | 5.318 |
| Three reacting trees | 1.178 | 1.431 | 1.750 | 2.691 |
| Perforated reacting tree | 0.775 | 0.989 | 1.308 | 3.982 |
| Saturated World destinations | 0.763 | 1.029 | 1.802 | 4.692 |
| Twelve dormant shards | 0.647 | 0.806 | 1.007 | 2.566 |
| Twelve-shard wake burst | 0.660 | 0.845 | 1.054 | 4.976 |

All 74 limits pass, with no dropped outliers. The benchmark performed 4,237,384
fixture assertions, most of them exact tuple observations in the comparison;
this count should remain separate from the native correctness-suite totals.

The three-tree workload delivered **102 actual Fire cells** and observed
25,368 World Smoke cell-samples across its three runs. The perforated fixture
reached **70 exact collider rectangles**. Saturated destinations produced 3,465
blocked attempts, retained nine real products, and emitted none; retained
products continued their supported lifecycle, reaching a maximum recorded age
of 416 semantic ticks. No tested workload allocated C++ memory in steady state.

The greatest requested C++ live/peak retention was **4,669,272 bytes**. The
corresponding registry retained 173,438 bytes. Requested C++ bytes are not RSS:
they omit allocator metadata, C-library allocations, stacks and executable
mappings. Runtime counters also omit some World non-cell allocations: the final
three-tree counter reported 4,322,054 bytes. Neither value should be described
as complete process residency.

## Costs and measurement boundaries

For three reacting trees, native p95 component measurements were 0.236 ms for
World, 0.025 ms for shard chemistry, 0.017 ms for product exchange, 0.376 ms for
terrain geometry, and 0.304 ms for the native snapshot. Inclusive occupancy was
0.531 ms. Contact and relocation timers are nested within other measurements;
**these percentiles and inclusive counters must not be summed** as disjoint
frame costs. These results identify terrain scanning, occupancy and publication
as larger costs than the selected chemistry in this workload.

Shard geometry rebuilds were sparse. The largest three-tree rebuild was
0.174 ms, with zero semantic-tick geometry age after the immediate synthetic
acknowledgements. The largest geometry receipt wait was 1.463 ms. This is not a
measurement of real main-thread shape installation.

Construction is separate: the largest three-tree Coordinator construction was
1.752 ms, and the largest individual promotion pause was 1.371 ms. Only three
construction samples were taken, so their displayed upper percentiles do not
establish reliable construction-tail statistics. They share one process and do
not measure cold application launch. The saturated fixture spends
up to 244 ms authoring blocked destinations through repeated ordinary edits;
that setup is excluded from steady frames and is not misreported as promotion
pause. No second full qualification campaign is implied by this setup cost.

## Compact storage versus a tuned serial miniature World

Both experiments invoke real production chemistry. Compact uses the actual
Coordinator's chemistry and emission methods; the alternative uses World with
8-cell chunks, 4-cell activity blocks, `SerialInPlace`, one worker, four deferred
event slots, and explicitly small capacities. Both transfer real material into
identical external Worlds. Every local and external material/state/temperature
tuple is compared each semantic tick. Common external World execution is timed
separately; physics, contact and rendering are outside this domain comparison.

| Equivalent-output fixture | Candidate | Carrier bytes | p50 µs | p95 µs | p99 µs | Maximum µs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Single burning Wood cell | Compact | 1,112 | 0.306 | 1.155 | 2.976 | 20.672 |
| Single burning Wood cell | Serial mini-World | 57,002 | 0.781 | 1.372 | 2.250 | 21.350 |
| Complete Wood tree, one burning surface cell | Compact | 60,666 | 9.704 | 12.820 | 39.458 | 2,879.324 |
| Complete Wood tree, one burning surface cell | Serial mini-World | 91,412 | 1.349 | 3.322 | 7.884 | 65.372 |

The single-cell test has 1,024 samples and is part of the registered matrix.
The supplementary full-tree experiment has 2,048 samples: 16 constructions and
128 ticks each, **550 structural Wood cells in a 30×45 carrier (1,350 cells)**.
Its stable lattice origin is (83, 60), with six initial exact collider rectangles;
the [native shape readback](objectshard-001-20261122/fulltree-shape-readback.json)
records those values. It uses a 64-chunk limit and scans only the known eight emission ports in
the mini-World adapter, avoiding an unnecessary whole-box output scan. It
delivered 48 actual Fire cells and observed 2,272 external World Smoke
cell-samples. Both candidates allocated zero C++ memory in steady state.

The full-tree result supports retaining the compact implementation for this
slice without claiming a scheduler speed advantage. The alternative saves
about 9.5 µs at p95 in this sparse fixture, while retaining about 30.7 KB more
memory. The fixture does not implement a second qualified promotion, mutable
physics, historical-contact or transaction system. No correctness or delivery
advantage requiring an architecture rewrite was established.

Full-tree evidence is retained in `build/objectshard-fulltree-probe-v3/`,
including its complete reproducible C++ harness, input/object hashes, executable,
raw output and summary. It reuses the exact frozen native objects bound to the
M2 commit; it is supplementary experiment evidence rather than an additional
registered matrix gate. Harness SHA256:
`03ee85efeac3a5b35a5c37a5f5dfddab9fadfb7c808f7f0a5c0f716cdaab8c6f`.
The [reproduction instructions](objectshard-001-20261122/README.md) apply its
161-line patch in a disposable checkout, leaving the published harness and
runtime untouched.

The first two full-tree fixtures remain under `objectshard-fulltree-probe/` and
`objectshard-fulltree-probe-v2/`. They correctly failed the real-output assertion
because the selected Wood cell was interior, with no Empty product neighbor.
The corrected fixture explicitly requires an exposed surface cell. No runtime
source was altered to make that comparison pass.

## Acceptance limits

The registered native budgets pass on the exact repaired M2 source. The tuned
miniature World remains a viable alternative, with honest measured strengths
and additional integration work. These results do not establish full fracture,
internal gas transport, general liquid transfer, persistence, Windows gameplay
or owner physical acceptance. The separate actual-Godot and Windows evidence
must retain those distinctions.
