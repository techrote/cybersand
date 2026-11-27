# Persistent-area memory accounting on the combined World

The protected path `native/src/world.cpp` gains read-only estimates for scheduler storage, World storage and World reservations. The estimates use the existing containers and their capacities to budget an inactive resident area. They do not change material IDs, density, reaction tables, or per-tick movement. The original RAMCACHE change and measurements remain in the [residency qualification](2026-11-22-gen006-ramcache.md).

| Source | LF SHA-256 of the protected path |
| --- | --- |
| Actor and Material at `53b2202408fea7130fd354ae35540880e926ba5e` | `98254d531ca7ca8f8e76f6d963f15b26b772777dc5633718a92cc637217eb77c` |
| Combined RAMCACHE and reciprocal construction at `3ad6541a6211f85672789fcf9b8271ab02609d67` | `54a727f6eb0543c2d9cdd868ed0486bf6e68d1b98c03c7a86a260891b49b1c24` |

On 2026-11-27 the local Ubuntu 24.04 native `make persistent-area-test` passed continuation, refusal, three-area and resident memory checks on the Actor/Material/RAMCACHE source with these World bytes. A changed live material profile was refused at capture. The existing actor-free 512-square domain and source-matched hosted application gates apply.
