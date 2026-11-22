# SWARM-006: feasible sources and bounded native recovery

**Experimental / Draft / HOLD.** Canonical programme:
[#704](https://github.com/techrote/cybersand/issues/704). The focused
[implementation contract](../../../docs/systems/gentek-negotiated-recovery.md)
owns current semantics; the [comparison runbook](SWARM-006-EXPERIMENTS.md)
owns reproducible executions. Neither document authorizes merging, Ready state
or a production default.

The exact predecessor is SWARM-005 native
`c178feeb39899fd155b7deb9d5bde3f50ee28548`, descended from SWARM-004
`2c4b8061ef5315de6a31df933e9f84c31865284e`. Their definitions, tests, branches
and revealed evidence remain controls. New recovery is explicitly OFF by default.

## Implementation entry points

- `frameweaver.cpp` and `mosaic.cpp`: optional prospective source feasibility,
  using the existing authored source parts and MOSAIC receiving predicates.
- `mosaic_recovery.cpp`: MOSAIC-owned finite bearing/corbel candidates,
  source-bound reservations, provisional withdrawal and deterministic cursors.
- `reciprocal.cpp`: FRAME-owned grammar revisions, canonical arbitration,
  native custody, exact masonry certificates, unchanged final joint/obligation
  rules and atomic composition authorization.
- `recovery_admission.cpp`: bounded metadata and retained-memory admission.
- `custody_hash.hpp` / `reciprocal_io.cpp`: constant-state SHA-256 custody over
  the exact native proposal transcript; the public JSON is evidence, not a token.
- `reciprocal_main.cpp`: V1/V2/V3 compatibility and explicit `SWARM006 4`.

## Local qualification

```sh
make -C native/experiments/gentek_swarm -f Makefile.reciprocal \
  BUILD=/absolute/fresh/native-build -j2 test
make -C native/experiments/gentek_swarm -f Makefile.reciprocal \
  BUILD=/absolute/fresh/sanitized-build SANITIZE=1 -j2 test
python3 -m unittest discover -s native/experiments/gentek_swarm \
  -p 'test_swarm006_runner.py'
```

The native definition includes every `.cpp` and `.hpp` in this experiment,
including tests. Rebuild after source/test changes; do not relabel an earlier
binary or evidence directory. Failed or exhausted generations and rejected
proposals retain their original receipts. Existing output paths are refused.

The shared-work cost model is versioned as recovery protocol v1: metadata
admission prepays `8192 + cell_count * (history_count + 1)` units per pass;
stream encoding and SHA-256 prepay four units per 64-byte block, including
padding. Minting and validation are separate charged passes. Numeric planes use
an unambiguous NUL marker, ULEB128 length and ULEB128 values; other fields retain
named canonical boundaries and strings. No intermediate JSON allocation is
needed. These are declared operation units, not CPU instructions or wall time.
No existing generator, solver or shared-work ceiling is increased.

Receiver input admission prepays the greater of the ordinary wrapper bound and
the measured bounded footprint/metadata traversal bound in `mosaic_recovery.cpp`.
Unusually dense public inputs therefore consume the larger amount before any
footprint traversal or proposal copy. Individual lengths and retained capacities
are checked; failed admission and failed candidates retain consumed work.

The 16 MiB limit is conservative admitted native storage, not process RSS.
Retained vector/string capacities, bounded native proof scratch and the opaque
authority are admitted before encoding. Exact-source sanitizers and adversarial
tests are separate gates. LeakSanitizer unavailable in an execution environment
must be reported explicitly; ASan/UBSan are not a substitute leak result.
