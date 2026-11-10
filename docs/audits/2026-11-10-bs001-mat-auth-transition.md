---
title: BS-001 ballistic solids proposed material-source transition
status: Planned
document-kind: evidence
scope: Proposed reviewed per-file transitions for three protected native consumers changed by BS-001; awaiting owner approval before any REVIEWED_TRANSITIONS entry is added
last-reviewed: 2026-11-10
related-documents: [../architecture/ballistic-solids-v1.md, 2026-11-10-bs001-ballistic-solids.md, 2026-11-07-native-copy292-mat-auth-transition.md]
---

# BS-001 / PR #561 — proposed material-source transition

**Proposed, not admitted.** The material-catalogue compatibility gate
(`tools/material_catalogue/compatibility.py`) protects these consumers. BS-001
changes them additively; no material identifier, catalogue entry, material law,
density, appearance, capability digest or identity input changes. The
transition table is owner-approved code, so no entry is added until the owner
approves this record.

| Protected source | Currently admitted LF SHA-256 | Proposed LF SHA-256 at `db05c904be1ded1f79bf28fab9c7c4b5e7a50a2a` |
|---|---|---|
| `native/src/world.cpp` | `36f928740f554cde7542bc16e8ef897317ea51f3897af665ff6bb7f9e1ca812b` | `e1efd918b476180e4fc84c65ab1db0ed7144410a3180e53065c538bbfb46f60a` |
| `native/src/world_pressure.inc` | `899ada71b89d30ba063e047bdd5b02346948008f1b7c0bec9fa0f2272e4d86ec` | `18ce00f8eb4488625a024528ff198c21c24f8af0b994f2a39f38cc7b3801adae` |
| `native/src/world_quantity.inc` | `d9e6835d092193e4976c728d90121c6dee4b421337e056b5fc3c74975491af6e` | `7d8c5a9be8fbc4b51832ad1ddacf7c221102cdd883ec625dd924e1e7f4857a8c` |

Issue / PR: [#361](https://github.com/techrote/cybersand/issues/361) /
[#561](https://github.com/techrote/cybersand/pull/561).

## Bounded change

- `world.cpp`: includes `world_ballistic_solids.inc`; constructs, validates,
  reserves, clears and advances the opt-in solids owner at tick entry right after
  ballistic Water; draws flying solids in the three presentation copies.
- `world_pressure.inc`: appends a solids section to the physical-state hash and
  CYPS (extension bit 16) only when solids are enabled; restores it with
  validation; carries flying solids across a retained workbench rebuild.
- `world_quantity.inc`: the authority-scan validator also runs the solids cell
  ledger validator.

Worlds without ballistic solids keep identical hash, persistence and ledger
bytes. Evidence: [BS-001 record](2026-11-10-bs001-ballistic-solids.md).

The commit holding these bytes must stay reachable from HEAD: merge #561 with a
merge commit (not squash/rebase), or point `source_commit` at the merged commit.
