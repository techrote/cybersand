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
struct CellLayoutExperiment {
    static CellLayoutFootprint footprint(const World&);
    // Fixed-endian 22-byte records: signed x/y, u16 material, u8 a/b, i16 temp.
    // Only all-zero Empty/ambient cells are omitted, including their epoch.
    static std::vector<std::uint8_t> semantic_records(const World&);
};
} // namespace cybersand
