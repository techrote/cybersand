# Native benchmark evidence — OBJECTSHARD-001

Runtime source: `1bb6185be05f5ef838543a0e13c81428b751d969` (Draft/HOLD PR #730).
The [performance report](../2026-11-22-objectshard-native-performance.md) explains
scope, results, registered budgets and limitations.

This directory retains source identities and JSON evidence, without binaries or
logs. `manifest.json` hashes the retained files. The original source snapshots,
executables and logs remain in the referenced campaign artifact directories.

- `native-benchmark-result.json`: all nine native workloads and the committed
  single-cell comparison.
- `native-benchmark-summary.json`: 74 passing registered limits and exact
  executable identity.
- `native-benchmark-inputs.json`: source/compiler/host input ledger.
- `native-commit-binding.json`: all 92 frozen source files matched to the M2 commit.
- `fulltree-result.json`, `fulltree-inputs.json`, `fulltree-summary.json`: the
  supplementary full-tree experiment, including its exact native object hashes.
- `fulltree-shape-readback.json`, `fulltree-shape-inputs.json`: actual native
  fixture dimensions, inventory and geometry.
- `fulltree-fixture-history.json`: the two retained failed interior-cell fixtures
  and their correction to a real surface emission port.
- `fulltree-comparison.patch`: the reproducible full-tree extension to the
  committed benchmark; no production runtime edit.
- `patch-replay.json`: applying that patch to the exact committed harness
  reproduced the executed fixture's source hash in an ignored checkout.

## Reproduce the registered qualification

In a checkout of the runtime source commit:

```sh
python3 tools/objectshard/run_benchmarks.py --qualify --jobs 2
```

The exact sampled durations vary by host. The runner freezes source inputs,
rebuilds them, records compiler identity, and retains every observed maximum.
The recorded native budgets are development-host budgets, not a substitute for
actual Godot, Rapier, Windows or owner physical acceptance.

## Reproduce the supplementary full-tree comparison

From a checkout containing this evidence directory, create a disposable checkout
of the measured runtime source and apply only the retained harness patch:

```sh
git worktree add --detach ../cybersand-objectshard-fulltree \
  1bb6185be05f5ef838543a0e13c81428b751d969
git -C ../cybersand-objectshard-fulltree apply \
  "$PWD/docs/audits/objectshard-001-20261122/fulltree-comparison.patch"
python3 ../cybersand-objectshard-fulltree/tools/objectshard/run_benchmarks.py \
  --case compact_tree_vs_tuned_serial_miniature --repetitions 16 --jobs 2
```

The patched harness SHA256 must be
`03ee85efeac3a5b35a5c37a5f5dfddab9fadfb7c808f7f0a5c0f716cdaab8c6f`.
This is a supplemental measurement; do not pass `--qualify` for a single case.
It preserves the original single-cell comparison and nine-workload matrix.

Both candidates hold the same 550-cell Wood tree inside a stable 30×45 local
carrier and execute the same semantic clock. The comparison checks all local
and external material/state/temperature tuples after every tick. Real Fire
crosses the boundary and follows World lifecycle to Smoke. The alternative
uses a small `SerialInPlace` World and the eight known emitter ports, while the
compact path invokes the actual Coordinator chemistry and emission methods.

Common external World execution is excluded from the domain timer and reported
separately. The fixture has immediate product output, so it does not claim
internal gas transport equivalence. The alternative's smaller domain time does
not establish a second qualified promotion/contact/physics/transaction system.
The measured tradeoff is retained without extrapolating the single-cell memory
ratio to complete trees.
