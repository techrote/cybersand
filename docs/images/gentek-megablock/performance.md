# Native performance comparison

Same executable, compiler, 512×512 extent, seed0, bay96/floor64/wall4 and material roles. Five measured repeats after native capture and direct/native parity warm-up.
Direct sampler timing isolates geometry; chunk timing includes the existing generator, candidate evaluation, receipts and raster assembly. Timings are advisory on this shared host.

| Module | Direct median ms | Direct ns/cell | Native chunk median ms |
| --- | ---: | ---: | ---: |
| seeded_typology_megablock | 8.683 | 33.12 | 169.013 |
| cantilever_spine | 2.951 | 11.26 | 166.528 |
| staggered_balcony | 1.502 | 5.73 | 135.816 |
| bridgehouse | 1.621 | 6.18 | 156.099 |
| stacked_arcade | 2.935 | 11.20 | 139.059 |
