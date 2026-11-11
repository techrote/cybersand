---
title: BS-001 ballistic solids reviewed material-source transition
status: Current
document-kind: evidence
scope: Owner-approved reviewed per-file transitions for three protected native consumers changed by BS-001
last-reviewed: 2026-11-11
related-documents: [../architecture/ballistic-solids-v1.md, 2026-11-10-bs001-ballistic-solids.md, 2026-11-07-native-copy292-mat-auth-transition.md]
---

# BS-001 / PR #561 — reviewed material-source transition

**Owner-approved 2026-11-11.** The material-catalogue compatibility gate
(`tools/material_catalogue/compatibility.py`) protects these consumers. BS-001
changes them additively; no material identifier, catalogue entry, material law,
density, appearance, capability digest or identity input changes. The owner
approved this record on 2026-11-11, and the three entries below are now in
`REVIEWED_TRANSITIONS`. Each target is the file's bytes at its source commit;
the commits also carry the later ballistic-naming comment edits.

| Protected source | Previously admitted LF SHA-256 | Admitted LF SHA-256 | Source commit |
|---|---|---|---|
| `native/src/world.cpp` | `36f928740f554cde7542bc16e8ef897317ea51f3897af665ff6bb7f9e1ca812b` | `0270e9e3748bdc53ea3d0545974be5db21e0e1e517643c9bf493f428e7bd2c96` | `bfe32564993d1ee05f03b9647569c355bad4ced8` |
| `native/src/world_pressure.inc` | `899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec` | `a335e98d9438daf980ab0258713c92a1bcdaca788db1fec046a2df99a1b59ae7` | `bfe32564993d1ee05f03b9647569c355bad4ced8` |
| `native/src/world_quantity.inc` | `d9e6835d092193e4976c728d90121c6dee4b421337e056b5fc3c74975491af6e` | `7d8c5a9be8fbc4b51832ad1ddacf7c221102cdd883ec625dd924e1e7f4857a8c` | `eb77c7e52dab5515f7033018a7b034ca90e732c5` |

Issue / PR: [#361](https://github.com/techrote/cybersand/issues/361) /
[#561](https://github.com/techrote/cybersand/pull/561).

## Bounded change

- `world.cpp`: includes `world_ballistic_solids.inc`; constructs, validates,
  reserves, clears and advances the opt-in solids owner at tick entry right after
  ballistic Water; draws ballistic solids in the three presentation copies.
- `world_pressure.inc`: appends a solids section to the physical-state hash and
  CYPS (extension bit 16) only when solids are enabled; restores it with
  validation; carries ballistic solids across a retained workbench rebuild.
- `world_quantity.inc`: the authority-scan validator also runs the solids cell
  ledger validator.

Worlds without ballistic solids keep identical hash, persistence and ledger
bytes. Evidence: [BS-001 record](2026-11-10-bs001-ballistic-solids.md).

The commit holding these bytes must stay reachable from HEAD: merge #561 with a
merge commit (not squash/rebase), or point `source_commit` at the merged commit.
