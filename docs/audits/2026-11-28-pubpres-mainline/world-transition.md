# Reviewed combined World source transition

PR #767, programme #717, source `378c478b800a87075f8f35fa24df9c3860720300`
preserves both accepted main `50e3bcb839211eac2abe1e065750cbcba4d36f8c`
and PUBPRES `957b4696b9f7987df18b4bf437e56ca3f391b956` through actual merge
parents. This record admits only the protected `native/src/world.cpp` source
transition. It is not runtime qualification or mainline merge acceptance.

- Accepted RAMCACHE LF SHA-256:
  `54a727f6eb0543c2d9cdd868ed0486bf6e68d1b98c03c7a86a260891b49b1c24`.
- Combined LF SHA-256:
  `9cdc78a8f14122c68f1d0357d75bf9b40dcb62c9ca563b6f33de2f5a0ddbda10`.

The result retains the previously selected PUBPRES native implementation and
adds accepted RAMCACHE's read-only resident-storage and reservation accounting.
The sole overlapping definition is the persistent worker pool. The selected
extracted class remains authoritative; its `resident_storage_bytes()` reports
its actual object size and allocated thread handles. No duplicate pool, changed
completion selector, altered Water law, material identity or catalogue lock is
introduced. All-worker completion remains the default. Existing experimental
selectors remain unselected and reproducible.

Independent native specialist A reviewed the World/ParallelState/pool storage
seam; qualification specialist C independently reviewed the selected pool,
World retirement and admitted persistent-host scope. Both found no source
blocker. Actual native, sanitizer and graphical resulting-source tests are
required separately. Thread stacks and optional non-admitted solver state are
not presented as measured process memory.

The current compatibility chain follows accepted main's RAMCACHE transition,
then this reviewed join. PUBPRES's earlier transition and its original audit
remain preserved in parent history; no historical hash or frozen lock changes.
