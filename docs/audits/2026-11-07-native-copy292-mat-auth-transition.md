---
title: Native signed-copy #292 reviewed material-source transition
status: Current
document-kind: evidence
scope: Native material/RGBA display-copy boundary safety without material-law changes
last-reviewed: 2026-11-07
related-documents: [../architecture/data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md]
---

# Issue #292 / PR #538 — bounded native copy transition

This is a single reviewed transition for the already implemented and independently reviewed
extreme-coordinate overflow correction. It is **not** a material, physics, quantity,
scheduler, ABI or production-default migration. The immutable legacy catalogue
lock is unchanged. The old and new byte identities are deliberately explicit.

| Field | Exact value |
|---|---|
| Protected source | `native/src/world.cpp` |
| Prior admitted LF SHA-256 | `b6cedf52e795073630f12f77668a461b6f9c3bb5fe02c64e7b6649bee4a6239a` |
| Proposed new LF SHA-256 | `36f928740f554cde7542bc16e8ef897317ea51f3897af665ff6bb7f9e1ca812b` |
| Source commit containing the new bytes | `7a2bab58bfb193b3f10e55bf63cdeec2a17f549f` |
| Source baseline | `662ed4d88c08070dbb6f313931146a23e3631471` |
| Issue / implementation PR | [#292](https://github.com/techrote/cybersand/issues/292) / [#538](https://github.com/techrote/cybersand/pull/538) |
| Pre-transition source review | [Independent exact-head code review](https://github.com/techrote/cybersand/pull/538#pullrequestreview-5814459587) |

## Bounded change

- `copy_material_cells` uses signed last-included x/y preflight after the existing
  layout validation and before any destination write, then processed-length
  chunk runs instead of computing a potentially unrepresentable exclusive x endpoint.
- `copy_rgba` adds the same signed last-included preflight before writing any output.
- A valid single included coordinate at `INT64_MAX` remains legal, including the
  C ABI's RGBA projection. Impossible endpoints reject before partial output.
  A zero-width/zero-height copy returns after existing destination-layout checks.
- Existing native Water coverage projection, RGBA palette, ballistic overlay, row
  padding, material IDs, physical-state and quantity behavior are unchanged.
  No source outside these copy routines is changed by this transition.

## Actual source-matched executable evidence

On candidate `b4a5c5337efa27a18ca3b4f06655d7c8bcad0785`,
[paired GitHub Actions run 42401878035](https://github.com/techrote/cybersand/actions/runs/42401878035)
executed the same 17-case source-pinned C++ test against real `World` and C ABI:

- **Five actual baseline UBSan RED** cases using immutable accepted source:
  [original source and stderr](https://github.com/techrote/cybersand/actions/runs/42401878035/artifacts/13585911484).
- **17/17 repaired UBSan GREEN**:
  [candidate native evidence](https://github.com/techrote/cybersand/actions/runs/42401878035/artifacts/13585603286).
- **17/17 repaired ASan GREEN** (leak detection disabled, not a leak-clean claim):
  [address evidence](https://github.com/techrote/cybersand/actions/runs/42401878035/artifacts/13585971063).
- **17/17 actual Windows Server 2022 MSVC GREEN**:
  [Windows binary and logs](https://github.com/techrote/cybersand/actions/runs/42401878035/artifacts/13585806218).

The original pre-fix candidate RED run [42401307258](https://github.com/techrote/cybersand/actions/runs/42401307258)
remains available, and the independent source review separately confirms
no copy-function changes beyond the guarded behavior described here.

## Alternative, reversal and remaining qualification

**Chosen:** inclusive-coordinate preflight and bounded processed-index traversal,
matching the existing safe `copy_render_cells` contract. **Rejected alternative:**
reject any region for which `x + width` cannot fit int64, because that also
incorrectly rejects `x=INT64_MAX,width=1`, a valid last included native cell.
To reverse this choice would require a separately reviewed visible C ABI/API
contract change and fully rerun copy/material/readback qualification.

This transition is a *source authorization record*, not itself a runtime release:
new source-matched Linux/Windows native GDExtensions and provenance, full
applicable Native and Godot tests, independent final-head review and guarded
owner-approved integration remain separately required. A Draft skip is never
evidence of runtime qualification. Preserve all existing reviewed transitions,
immutable materials catalogue baseline and prior artifacts.
