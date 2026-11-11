---
title: Native explicit material capability consumer qualification
status: Current
document-kind: audit
scope: Separate Draft capability-map cutover; preserves native values and saved policy identity; not production acceptance or a full catalogue migration
last-reviewed: 2026-11-11
related-documents: [../operations/material-catalogue-shadow.md, ../operations/materials-lab-authoring.md, ../architecture/material-authoring-catalogue-plan.md]
---

# Native explicit material capability consumer

This separate #353-B candidate makes the canonical authored `hard_surface` and
`granular_support` fields the source of the two native capability predicates.
It replaces the numeric hard-material range and hand-maintained granular switch
with two generated four-word masks. The masks occupy 64 bytes in total and have
constant bounded lookup; there is no tick-time parsing, allocation or mutable
registry. Other catalogue properties remain on their existing native consumers.

The cutover is separate from Materials Lab #562. Existing #384 still owns its
Main display-name migration and is not imported or modified. MoltenGlass H1,
World scheduling, chemistry and endpoint effects are outside this change.

## Source and transition

- Accepted main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Immediate parent and independently compiled reference: `f684dcffb18614dd9557e85d3c811abcb28cf325`.
- Implementation tree: `d97b020e6cadd8fc96cc9ec033d6041b50edc277`.
- Local implementation checkpoint: `8d472da48a4d116e4f14c9ae57e725f3b56b1647`.
- Public implementation source: `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087`.
- Separate [Draft #563](https://github.com/techrote/cybersand/pull/563), stacked on #562.

`native/src/material_rules.cpp` moves through the existing reviewed per-file
transition mechanism. Its LF SHA-256 changes from
`3afda824571842e387b0cac70218ee5f1f96005d07aaaafcf95c146c3eee3254` to
`94928fa8f16010efaa3326750a3e951101e6905f3eafe8f99c0935ab33f0de8d`.
The old frozen compatibility lock remains byte-identical. The new generated
route separately authenticates these inputs at the retained source commit:

| Input | LF SHA-256 |
|---|---|
| `materials/catalogue/catalogue.json` | `3a5250a07912dc9530172cb2fccecd526606e242209d666cb2da202e1cfc9f14` |
| `tools/material_catalogue/compiler.py` | `81a0658655574ee5e65ecc144db9750b9128380595d51af70c2b04d0a209a098` |
| `tools/material_catalogue/native_capabilities.py` | `a72f20047ac1619d0149ee3da29e97477c53815f79d79f6b2981542c8ae7e2d5` |
| `native/include/cybersand/material_capabilities.hpp` | `564c15e56a7bbed737d5a495e24d311e3522bd57bcdff9a2d2752500532492c8` |

Both digest-bearing catalogue headers, all 132 identities including invalid 10,
all 56 sparse rules and their positional quantities, native/default policies,
capability-matrix bytes, policy identity generator and saved-state formats are
unchanged. The existing catalogue digest remains
`82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3`
and capability digest remains
`33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237`.

Only `native/src/material_rules.cpp` may consume the generated namespace. A
coherent edit to authored JSON and generated output still fails the code-pinned
source guard; unknown imports, missing files, changed generators and forged pins
are refused. The header cannot become an unguarded second source of physics.
The transition source must stay in Git ancestry: merge this Draft with a merge
commit if later accepted, not squash/rebase. Runtime artifacts require their own
source-matched rebuild/publication; the #562 runtime is not this runtime.

## Regeneration and rollback

```sh
python3 tools/material_catalogue/native_capabilities.py
python3 tools/material_catalogue/native_capabilities.py --check
python3 tools/material_catalogue/compatibility.py --check
```

The generator calls the existing strict schema validator. Only the canonical
source can write its one owned native header inside the repository. Invalid or
unsupported input fails before publication, and check mode never rewrites.
Synthetic powder 132 uses the existing isolated schema and an external output.
Actual compiled lookup verifies that it is non-hard and granular while the
production roster still ends at 131.

Routine Lab candidate edits remain external experiments. Capability edits are
still qualified by the descriptor backend, not silently installed in the Lab
World backend. This cutover establishes a real canonical native consumer for
future reviewed authored changes; it does not admit arbitrary live edits or
new production IDs. Revert the native consumer, generated route and transition
entry together against the recorded predecessor; retain this audit and proof.

## Independent native and persistence evidence

`check_capability_transition.py` extracts the original native tree from the
retained reference commit and separately builds original/candidate executables
with the same compiler and flags. Both native snapshots are byte-identical:
`58d22545a1f29e49a8c141cb1c5df84101e48ed457fbaaaec09937997c2ce802`.
Each independently compiled side passes all 256 capability/query inputs,
65,536 uint16 validity inputs, 16,777,216 pair rolls and wrappers, density,
viscosity and visual-state projection checks. These query checks are explicitly
not World execution.

The separate World executable populates all 130 valid nonempty materials in
bounded chambers. It runs 24 ticks, saves an actual CYPS checkpoint, then
continues to tick 48. The other executable restores the first executable's
checkpoint and runs the same continuation. All four Water solver families,
one/four configured workers and both source directions are covered: **16
cross-build exchanges per campaign**. Actual worker counts 1 and 4 are observed;
stored material/state/temperature hashes, policy identity, full physical hashes,
final saved bytes and quantity balance agree. Invalid 10 and unallocated IDs are
never stored. This qualifies these fixed cases, not arbitrary cross-version
migration beyond the unchanged identity contract.

An isolated compiled poison changes Wood's hard bit to false and fails exactly
`parity: capability mismatch at 7,0,0`, proving the actual MaterialRules consumer
uses the generated maps. The poison never writes production input.

| Initial capability-source Linux check | Result |
|---|---|
| Generator and output controls | 9 tests passed; actual C++ synthetic 132 and byte-domain readback included |
| Normal source-paired native transition | PASS; 16 cross-build exchanges |
| ASan+UBSan source-paired transition | PASS; 16 cross-build exchanges |
| `make build/tests` then `./build/tests` | 192 tests passed |
| Full production-native ASan+UBSan suite | 192 tests passed; no sanitizer diagnostics |
| Generated consumer guard controls | 12 tests passed, including Git-authenticated positive admission and adversarial refusal |
| Full catalogue discovery | 224 tests passed in 337.569 s; no skips |
| GDScript receipt controls after test-only cleanup | 16 tests passed |
| Canonical and native generation checks; current native parity | PASS; authenticated two-field cutover reported accurately |
| Current documentation and historical integrity | PASS; 126 documents / 250 claims; 18 historical records / 28 source hashes |
| Retrieval regression | Frozen 31/32, challenge 163/164, Lab 8/8 canonical hits at k; unchanged |
| Retained-runtime repository identity | FAIL with four explicit source rebuild errors; no artifact reattestation |

Reproducible commands (run from this branch):

```sh
python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py' -v
python3 tools/material_catalogue/compiler.py --check
python3 tools/material_catalogue/native_capabilities.py --check
python3 tools/material_catalogue/compatibility.py --check
python3 tools/material_catalogue/check_native_parity.py --output build/capability-transition/final-parity.json
python3 tools/material_catalogue/check_capability_transition.py --output build/capability-transition/normal-first
python3 tools/material_catalogue/check_capability_transition.py --output build/capability-transition/sanitized-first --sanitize
make build/tests
./build/tests
make build/tests_sanitized
ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/tests_sanitized
```

At the initial capability-source checkpoint, `check_repository.py` refused the
retained Linux and Windows runtimes for changed
`godot/native_extension/cyber_demo_bridge.hpp` (the parent Lab branch) and
`native/src/material_rules.cpp` (this cutover). Both require a source-matched
rebuild; the new header must enter the retained runtime source inventory. This
worktree materialized only the two Linux runtime libraries; the remaining 16
retained paths are reported as unmaterialized. No runtime gate is claimed from
identity checking or from this native-only qualification.

Linux Python 3.12/GCC 14.2 apply. Sanitizers use
`ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and
`UBSAN_OPTIONS=halt_on_error=1`. LeakSanitizer, ThreadSanitizer, actual Windows,
Godot/renderer acceptance and retained-runtime publication are not established
by the local native proof. The frozen source lock is never refreshed.

Receipts retain the exact working-file/native inputs and informational HEAD at
execution, which preceded the source commit. Their inputs match that commit;
commit metadata alone is not source custody. Durable receipts:
[normal](materials-native-capabilities-v1/normal-first.json),
[sanitized](materials-native-capabilities-v1/sanitized-first.json).

## Bounded advisory cost

Same-build flags are `-O2 -pthread` without LTO. Four ABBA blocks each perform
100 million combined hard/granular queries over a permuted complete byte domain.
The reference/candidate median is 114.536/102.497 ms. The query executable grows
by 168 bytes (ELF text+read-only data +48 bytes); the small World executable grows
by 176 bytes (text+read-only data +64 bytes). Neither BSS nor writable data grows.

A small ABBA process comparison covers all four Water families and one/four
workers: construction, 48 native ticks, checkpoint IO and stored-state readback.
Pooled reference/candidate medians are 160.678/151.120 ms. These shared-host
observations are advisory, not a tick-only metric or a gameplay speed claim.
All timed checksums and World results match the qualified controls. No timing
threshold was created, relaxed or used as a correctness gate. See the
[raw timing observations](materials-native-capabilities-v1/timing.json).

## Stack reconciliation — 2026-11-11

The completed capability source/guard tree was published as
`9cb21c93cb89de61b7f32664279bd8dbc77a5c3c`, retaining `b432d52` in ancestry.
This branch then merged the explicit Lab completion source
`9eb90272cb2261e429c965dfbd21c6adc862a021`. The merge preserves the native contact
inspector, process owner, package/publisher tools and each dated audit. The
`lab.py` merge retains process-owner custody plus the capability header/generator
custody entries; the architecture conflict keeps both scopes in their own
sections. No other branch was changed by this reconciliation.

All `native/` files, `Makefile`, canonical catalogue/lock, generator and native
proof/benchmark inputs remain byte-identical to the capability implementation
source `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087`. The recorded 192-test native
and sanitizer suites and independent cross-build proofs therefore still name
the same native inputs; they were not rerun or relabelled as a new campaign.
The combined authoring implementation was exercised by a fresh full catalogue
discovery run because `lab.py` and process ownership changed: **228 tests passed
in 305.080 seconds, exit 0, no skips**. This includes the four actual process-owner
fixtures and compiled native candidate effects/World/persistence cases. The
command was `python3 -m unittest discover -s tools/material_catalogue -p 'test_*.py' -v`.

Fresh compatibility, documentation, historical M11 and CI-provider policy checks
pass after reconciliation. Retrieval observes 31/32 frozen canonical hits at k
(MRR 0.7474), 163/164 challenge hits (MRR 0.8797), and all 10/10 Lab questions
at rank 1. The current repository checker
again refuses the retained artifacts with four source-rebuild errors: Linux
and Windows for `cyber_demo_bridge.hpp` and `material_rules.cpp`. This is a fresh
observation on the merged source, separate from the initial failure above.
The merged source imported no runtime binaries or provenance updates. The #562
publisher is admitted only for its own branch; its artifacts cannot qualify the
changed native capability consumer in #563. This Draft still requires its own
source-matched runtime and platform qualification.

## Remaining release boundary

This is a bounded Draft with a genuine native consumer and local native proof.
It does not close the wider #353 programme. Full descriptor/appearance generation,
#384 display-name admission, production candidate installation and arbitrary
runtime effects remain separate scopes. Hosted exact-head native/platform gates,
source-matched retained runtime publication and owner acceptance remain required
before integration. No Ready promotion, merge or auto-merge is performed here.
