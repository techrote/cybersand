#pragma once

// Issue 16 research-only, serialized owner observations. No mutable World views.
#include <cstddef>
#include <cstdint>
#include <vector>

namespace cybersand {
class World;
struct CellLayoutFootprint {
    std::size_t cell_size, alignment, stride;
    std::size_t cells, temperatures, activity, chunk_objects, map_buckets;
    std::size_t coordinator_vectors, parallel_vectors;
};
#ifdef CYBERSAND_CELL_EPOCH_OBSERVER
struct EpochClearChunk {
    std::int64_t x=0,y=0;
    std::uint64_t cells=0;
    std::uint32_t active_blocks=0;
    std::uint8_t selection=0; //0 excluded,1 partial,2 fully selected
    bool active=false;
};
struct EpochClearSample { std::uint64_t tick=0,ns=0,first=0,count=0; };
struct EpochClearTrace {
    std::vector<EpochClearSample> samples;
    std::vector<EpochClearChunk> chunks;
    std::size_t used=0,chunk_used=0,chunk_limit=0;
};
#endif
struct CellLayoutExperiment {
#ifdef CYBERSAND_CELL_EPOCH_OBSERVER
    static void configure_epochs(World&,std::size_t clears=64,std::size_t chunks=4096);
    // Serialized owner diagnostic values; never retain across clear/reconfiguration.
    static const EpochClearTrace* epochs(const World&);
    static std::size_t epoch_trace_bytes(const World&);
    static std::uint8_t epoch_at(const World&,std::int64_t,std::int64_t);
#endif
    static CellLayoutFootprint footprint(const World&);
    // Fixed-endian 22-byte records: signed x/y, u16 material, u8 a/b, i16 temp.
    // Only all-zero Empty/ambient cells are omitted, including their epoch.
    static std::vector<std::uint8_t> semantic_records(const World&);
};
} // namespace cybersand
