# Provenance and numeric-boundary follow-up for #3 / #19

**Source-scoped preparation discovered during fresh validation. No production code, binary or release-manifest change.** See [the observed checks](validation.md).

## Separate three identities

The fresh Linux native test executable passed all 55 existing tests. The standalone C++ and Python projection oracles also agree. Neither result attests the existing Godot GDExtension artifacts: the repository checker independently found seven changed source inputs for each of Windows and Linux, fourteen provenance errors in total, with all required LFS objects present.

A release task should therefore distinguish the source checkpoint, the compiled GDExtension hash and actual runtime execution. Preserve current historical manifests. Rebuild the affected artifact from a named source state with the normal pinned toolchain, run the intended platform checks, and then publish its own provenance. A native unit-test executable, a loaded DLL from the owner's workspace and a retained Git LFS library are different artifacts.

This is a bounded issue #3/release follow-up, not permission to retune toolchain pins, certify Web exports or rewrite historical M11 records. The research branch has not changed any of the seven inputs identified by the checker.

## Four observed conversion warnings

The successful `make build/tests` invocation emitted these warnings at source `f0907126339033f849df40e9525caa66462e744a`:

| Source location | Boundary | Review question |
|---|---|---|
| `native/src/world.cpp:545` | `RenderSnapshotExchange::publish`: 16-bit state_a passed to byte visual projection | Is Water normalized before a changed mass lattice reaches the existing display byte? |
| `native/src/world.cpp:3062` | `World::copy_render_cells`: stored 16-bit state_a passed to byte projection | Does the ordinary/full-refresh path agree with snapshot projection? |
| `native/src/c_api.cpp:286` | `cybersand_world_liquid_mass`: integer quantity returned through `uint8_t` | Does this API promise legacy byte units, a normalized view, or raw experimental quantity? |
| `native/src/world.cpp:1400` | `mix_after_motion`: integer moved_mass passed to `uint16_t` | Is the range checked/proven before conversion, including experimental callers? |

Warnings identify review points, not demonstrated runtime corruption. All mass3..8 quantities fit a byte, but a full mass3 value of 7 still has the wrong normalized appearance when interpreted directly on a 0..255 scale. The separate mass10 research arm can exceed a byte and is outside the proposed #19 GUI range. Do not conflate those two problems or change non-Water semantics as a shortcut.

## Prepared acceptance cases for the next implementation

For both snapshot and full-refresh projection, enumerate each legal mass3..8 value. Require Empty to project to zero and every full cell to 255; retain mass8 identity and exact non-Water control bytes. Use the independently generated 504-state, 1,512-comparison projection oracle. Exercise negative coordinates, chunk/core edges, stale packet rejection, delayed consumption and a reset between different mass lattices.

For C API calls, first document the function's units and supported experimental range. Test boundary values 0, 1, 7, 15, 63, 127 and 255; test 256 and 1023 only through an explicitly supported wide research path or explicit refusal. Do not silently truncate a raw quantity, and do not call a normalized byte an exact mass ledger. A versioned wider diagnostic accessor may be preferable to changing an established byte ABI, but that choice needs implementation review.

For moved-quantity conversion, verify the maximum transfer reachable through each caller and assert/check the bound before narrowing where required. Keep reaction and mixing behavior unchanged. Run existing Water/Mercury/material controls and the relevant new boundary tests before accepting a fix.

These cases are a test plan derived from actual build evidence. They were not run against a new bridge implementation, and no release artifact was rebuilt by this preparation task.
