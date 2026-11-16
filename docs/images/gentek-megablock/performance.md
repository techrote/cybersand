# Native performance comparison

Same executable, compiler, 512×512 extent, seed0, bay96/floor64/wall4 and material roles. Five measured repeats after native capture and direct/native parity warm-up.
Direct sampler timing isolates geometry; chunk timing includes the existing generator, candidate evaluation, receipts and raster assembly. Timings are advisory on this shared host.

| Module | Direct median ms | Direct ns/cell | Native chunk median ms |
| --- | ---: | ---: | ---: |
| seeded_typology_megablock | 6.537 | 24.93 | 144.993 |
| cantilever_spine | 2.864 | 10.93 | 141.004 |
| staggered_balcony | 1.750 | 6.68 | 136.744 |
| bridgehouse | 1.646 | 6.28 | 138.399 |
| stacked_arcade | 2.194 | 8.37 | 153.610 |
