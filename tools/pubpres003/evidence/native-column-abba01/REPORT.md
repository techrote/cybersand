# Native column invalidation: paired development diagnosis

**Status: qualified native diagnostic; graphical playability and owner acceptance HOLD.**

The candidate preserves the column/half invalidation value while avoiding a store when it is already false/zero. This comparison tests that native change on identical application and observer source. Four sequential fresh-process runs used D0/C1/C1/D0, with four actual participating workers, the active reference2048 current-gameplay fixture, two native rounds, spill/parcels and ballistic transport. The native probe was ON and same-frame continuation OFF in every arm.

| Run | Source | Mean column wall time per tick over first 144 steps | Native tick p50 | Native tick p95 | Native tick maximum |
|---|---|---:|---:|---:|---:|
| 0 | D0 | 58.996ms | 122.661ms | 155.048ms | 234.796ms |
| 1 | C1 | 57.682ms | 125.090ms | 143.159ms | 169.466ms |
| 2 | C1 | 52.201ms | 110.921ms | 129.105ms | 165.595ms |
| 3 | D0 | 60.355ms | 125.083ms | 167.624ms | 273.148ms |

The two run-level column means average 59.675 ms for D0 and 54.942 ms for C1, a 7.93% reduction. The range between candidate repeats is material; this is a modest favorable signal, not a settled estimate or evidence of acceptable continuous gameplay. Preparation, flux and apply times also varied. No confidence interval or averaged tail percentile is presented from two repeats.

Every arm passed the explicit native actor/body/sample/terrain/input/Water/callback-credit checks. Fixture, requested/effective apparatus, CPU and engine identities match. All first 144 body trajectories and admitted moves have identical hashes. Complete live material-map parity is a separate native differential gate; the construction receipt is prepared-source identity, not the final World hash.

The unchanged graphical v3 validator refuses all four headless arms. Native-stage wall time is the causal endpoint here; headless step rates, callbacks and material upload durations cannot qualify graphical playability. The original full receipts, traces, process logs, requested settings and native binaries/build receipts are retained in the accompanying raw archive.

## Exact source and runtime identities

- D0 application/native source: `1dc272df857407187596bbdc52b4125e2252551c`.
- C1 application/native source: `4215a9b2b3681b11a0115fc896c23fbde3d6ed6f`.
- Application subtree equality: `git diff --exit-code D0 C1 -- godot` passed.
- D0 native SHA256: `a842d77977644ea330d826710ac7cf50a7b1150f0e8b65a27101e481e73b06ae`. It was independently rebuilt for D0 and naturally matches frozen F bytes; it is not a rewritten F receipt.
- C1 native SHA256: `f4b4ab71d4900a9244d76253cf5294f774b6e15a70ebb181fef50b660f44ca71`.
- Measurement driver: `7e75e5352` (complete40-digit identity and file closure in each request).
- Local GCC 14.2 drift was explicitly allowed and recorded. Final qualification requires the pinned hosted build.

## Next justified work

The dominant native column cost remains tens of milliseconds even before graphical handoff delay. Test a bounded scheduling change that keeps both existing half-column tasks on one worker where enough parallel tasks remain, then repeat live native-state parity and the same controlled workload. Separately inspect source-matched graphical producer→mailbox→Main→terrain→actual-Rapier traces to determine the avoidable noncompute delay.

[Retained raw evidence and exact native binaries](https://chatgpt.com/library?file_id=libfile_fac2344dd62c8191860a27723ada6cbc&account_id=personal) — 7,209,692 bytes; SHA-256 `d5b85b2d122ea9c27061a3cf25dbf3f80326beb6c8e2e42256582dfbdc5b8e75`.
