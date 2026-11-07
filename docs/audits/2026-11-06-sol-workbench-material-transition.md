---
title: SOL and main per-file material source reconciliation
status: Current
document-kind: audit
scope: Reviewed non-identity consumer transitions for the dependent SOL workbench-law experiment; no frozen lock refresh or physical admission
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [../operations/material-catalogue-shadow.md, ../systems/solid-detachment.md, 2026-11-04-workbench394-material-source-transition.md]
---

# SOL and main per-file material source reconciliation

Draft [#466](https://github.com/techrote/cybersand/pull/466) reconciles parent
#461cba3c0de and main554d27b1 under owner D1/D2. The retained source commit is
`89c7b5931dd18601b72c5ce0f77186eaac16cbc1`. A subsequent commit adds these entries;
retain merge ancestry. Never squash/cherry-pick away the admitted source commits.

The independent read-only source review gives scoped technical GO for these two
non-identity consumer transitions. It finds exactly two changed consumers among
27 protected paths; all other protected and identity inputs match main. Runtime,
physics, original SOL and integration admission remain separate. The frozen
`materials/catalogue/compatibility-lock.json`, BASELINE, all five previous reviewed
entries and all catalogue/capability/policy identities remain unchanged.

| Protected path | From admitted main LF SHA-256 | Reconciled LF SHA-256 |
|---|---|---|
| `native/src/world.cpp` | `a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7` | `b0a8ad4b20b46fa005bbf7f594e3e96a40d8d5920a258e69d7c8c218262a77a1` |
| `native/src/world_pressure.inc` | `7b28bf216bf70af7059267cae31117f1f01e88d0e5f276f61d67280ab5c6d2e5` | `75c9897aa0eec69900d2e37d69a83b513d7c8ae2894d95e41a09cc0493195079` |

World's34 additions preserve main's full arrivals, one-use retirement, pressure,
scheduling, granular admission, occupancy reservations and quarantine. Additions
are the bounded read-only contact-cell availability query; SOL transaction
mutation fences; SOL retirement on clear; and detachment/conservative kernel
includes. The two adjacent contact-query functions are separately complete.
Transient configuration keeps main's full-occupancy parameter and adds the SOL
fence. With no SOL transaction pending, ordinary behavior is unchanged.

Pressure's four additions refuse physical hashing and CYPS save when an aggregate
or transaction cannot be represented by CYPS2/3. Main's pressure algorithms,
caches, codec and scheduling remain unchanged. This prevents a false complete
serialization claim; it does not implement aggregate save/restore or unblock#365.

The new native extension and headers are not frozen SOURCE_ROLES consumers, but
must be rebuilt and source-authenticated in full, including every new SOL and
workbench include. Existing binaries/validation records cannot qualify this
combined source. Ordinary workbench arithmetic, Water policy and frozen material
identities are retained. This review grants no new cross-owner recovery path.

Validation must run the original guard, compiler/shadow/adverse tools and native
parity/oracles, followed by actual rebuilt Windows/Linux host qualification.
Historical SOL guard failures retain their original source/denominators; these
reviewed entries do not rewrite or relabel those failures. Every later protected
edit requires another reviewed source transition, not replacement of these hashes.
