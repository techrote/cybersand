# OBJECTSHARD-001 reviewed World consumer transition

Status: Draft/HOLD, associated with PR #726 and programme #281. This entry
admits the exact reviewed source bytes; it is not runtime publication or owner
physical acceptance. Merge commits must preserve the source ancestor.

- Protected path: `native/src/world.cpp`.
- From LF SHA256: `ec3034850af97e790dfc3855411bba5be60c820cb623a6df62ca09c70aeb761a`.
- To LF SHA256: `bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214`.
- Source commit: `5afe5643097c543f7d8a6840ced9afac58dd053e`.
- Parent accepted source: `30e1cddd3d678456df10f52f7a2fb2210a9daaad`.

The owner explicitly authorized native ObjectShard M0–M2 implementation while
preserving production defaults. This narrow shared-file edit adds an optional,
private mutation journal for the bounded Lab and extracts existing Wood, Fire
and Smoke decisions into one shared header. Ordinary Worlds never enable the
journal. Their rule order, traversal, transport, activity, quantity schema and
Water defaults remain unchanged. Catalogue IDs, capability identities, the
frozen compatibility lock and retained identity inputs are unchanged.

Chemistry implementation-track review inspected the extraction and null-journal
paths and found no concrete default-behavior defect. The final combined World
hooks were rebuilt and compared against immutable original source: 4,472
assertions, zero failures;16 serial/phased fixture records and2,964 semantic
observations match exact tuples, lifecycle timing, products, temperatures,
populations, Water accounting and physical hashes. The combined input digest is
`d08f40b058a03aaa0cb606642b7e70d2abbac8ae88a3495d6e4758896925dc30`.

The fresh final-source reviewer subsequently regenerated the16 original records
from immutable accepted source and added four independent serial/phased fixtures
covering signed origins, Wood/Plant burn boundaries, Fire/Smoke lifetimes,
320semantic ticks across epoch wrap, temperatures, populations and physical
hashes. All20 original/extracted JSON records were byte-identical. That reviewer
did not author the shared helper or World extraction. The protected World hash
above was unchanged throughout these M2 reviews. Evidence is retained under
`build/objectshard-final-review/world-independent-oracle` in the qualification
artifacts; this independent result supplements rather than renames the earlier
implementation-track assessment.

A separate independent protocol reviewer executed969 coordinator checks and229
partial-debit fault-injection checks after repairs, including journal clear,
ABA witnesses, cancellation/reset and exact quarantined ownership. Its evidence
manifest SHA256 is
`e13ed952f5a15222736e9c390faf9fc119cb6d2042562e978fe7b9afc4149334`.
The coordinator TU used UBSan; this is not whole-World sanitizer coverage.

The new Chunk coordinate is scheduler metadata used only by the opt-in journal.
It does not enter the existing cell carrier or serialized material identities.
Further changes to the protected World file require another reviewed step;
there is no refreshed baseline, bypass flag or relaxation of provenance checks.
See [the implementation record](../research/objectshard-001.md).
