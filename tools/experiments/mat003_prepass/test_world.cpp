// MAT-003PREPASS S1: correctness apparatus only, never a production build input.
// Each binary includes the exact or mechanically overlaid World implementation.
#include "world_adapter.hpp"
#include MAT003_WORLD_SOURCE

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <tuple>

namespace fixture {
using Bytes = std::vector<std::uint8_t>;
inline std::uint64_t assertions = 0;
void require(bool condition, const char* message) {
    ++assertions;
    if (!condition) throw std::runtime_error(message);
}
template<class T> void le(Bytes& out, T value) {
    using U = std::make_unsigned_t<T>;
    auto bits = static_cast<U>(value);
    for (std::size_t i = 0; i < sizeof(T); ++i) {
        out.push_back(static_cast<std::uint8_t>(bits & static_cast<U>(255)));
        bits = static_cast<U>(bits >> 8U);
    }
}
void flag(Bytes& out, bool value) { le(out, static_cast<std::uint8_t>(value)); }
struct Snapshot {
    Bytes bytes;
    std::uint64_t water = 0, sand = 0, cells = 0;
};
struct Memory {
    std::uint64_t cells = 0, cell_size = 0, cell_capacity = 0, temperature = 0;
    std::uint64_t activity = 0, tails = 0, descriptors = 0, scratch = 0;
    std::uint64_t world_size = 0, legacy_aggregate = 0;
};
using Point = std::pair<std::int64_t, std::int64_t>;
}

namespace cybersand {
// The friend is already present in the unchanged production World header.
class PrecisionProbe {
public:
    using Epoch = decltype(World::update_epoch_);
    static_assert(sizeof(Epoch) * 8 == MAT003_EPOCH_BITS);
    static Epoch epoch(const World& world) { return world.update_epoch_; }
    static unsigned stride() { return sizeof(World::Chunk::Cell); }
    static unsigned alignment() { return alignof(World::Chunk::Cell); }
    static unsigned counter_bytes() { return sizeof(Epoch); }
    static unsigned accessor_bytes() { return sizeof(decltype(World::Chunk::Cell{}.epoch_value())); }
    static Epoch cell_epoch(const World& world, std::int64_t x, std::int64_t y) {
        const auto a = world.address(x, y);
        return world.find_chunk(a.chunk)->cells[a.index].epoch_value();
    }
    static void stale_stamp(World& world, std::int64_t x, std::int64_t y) {
        const auto a = world.address(x, y);
        world.find_chunk(a.chunk)->cells[a.index].set_epoch(
            world.update_epoch_ == 0 ? Epoch{1} : Epoch{0});
    }
    static std::uint16_t extra(const World& world, std::int64_t x, std::int64_t y) {
        const auto a = world.address(x, y);
        const auto* chunk = world.find_chunk(a.chunk);
        fixture::require(chunk != nullptr, "extra read has no resident owner");
#if MAT003_SPLIT
        return chunk->mat003_tails[a.index];
#else
        return mat003_world::get_extra(chunk->cells[a.index]);
#endif
    }
    static void extra(World& world, std::int64_t x, std::int64_t y, std::uint16_t value) {
        const auto a = world.address(x, y);
        auto* chunk = world.find_chunk(a.chunk);
        fixture::require(chunk != nullptr, "extra write has no resident owner");
#if MAT003_SPLIT
        chunk->mat003_tails[a.index] = static_cast<mat003_world::Tail>(value);
#else
        mat003_world::set_extra(chunk->cells[a.index], value);
#endif
    }
    static void raw_a(World& world, std::int64_t x, std::int64_t y, std::uint16_t a) {
        const auto address = world.address(x, y);
        world.find_chunk(address.chunk)->cells[address.index].set_state_a(a);
    }
    static void move(World& world, std::int64_t x, std::int64_t y,
                     std::int64_t tx, std::int64_t ty, bool swap) {
        world.move_cell(x, y, tx, ty, swap, nullptr);
    }
    static std::uint16_t transfer(World& world, std::int64_t x, std::int64_t y,
                                 std::int64_t tx, std::int64_t ty, std::uint16_t n) {
        return world.transfer_water(x, y, tx, ty, n, nullptr);
    }
    static std::uint64_t event_count(const World& world, PhysicsEvent event) {
        std::uint64_t count = 0;
        if (world.physics_totals_) for (const auto& entry : world.physics_totals_->entries)
            if ((entry.key >> 24U) == static_cast<unsigned>(event)) count += entry.count;
        return count;
    }
    static std::uint64_t mix(World& world, std::int64_t x, std::int64_t y) {
        // Direct entry to the existing registered transport consumer. This is
        // a separately labelled fixture call, not a new material rule.
        fixture::require(!world.tick_in_progress_, "transport probe entered during real tick");
        world.tick_in_progress_ = true;
        world.mix_after_motion(Material::Water, x, y, x + 1, y, 255, nullptr);
        world.tick_in_progress_ = false;
        return event_count(world, PhysicsEvent::GrainTransport);
    }
    static void seed_epoch(World& world, Epoch value) {
        const auto previous = world.update_epoch_;
        for (auto& [coord, chunk] : world.chunks_) {
            (void)coord;
            for (auto& cell : chunk->cells)
                cell.set_epoch(cell.epoch_value() == previous ? value : Epoch{0});
        }
        world.update_epoch_ = value;
    }
    static std::vector<ChunkCoord> coordinates(const World& world) {
        std::vector<ChunkCoord> coords;
        coords.reserve(world.chunks_.size());
        for (const auto& [coord, chunk] : world.chunks_) { (void)chunk; coords.push_back(coord); }
        std::sort(coords.begin(), coords.end(), [](const auto& a, const auto& b) {
            return std::tie(a.y, a.x) < std::tie(b.y, b.x);
        });
        return coords;
    }
    static fixture::Snapshot snapshot(const World& world, const TickStats& stats,
                                      const std::vector<fixture::Point>& supports) {
        using fixture::le;
        using fixture::flag;
        fixture::Snapshot result;
        auto& out = result.bytes;
        const auto coords = coordinates(world);
        out.reserve(coords.size() * static_cast<std::size_t>(world.config_.chunk_size) *
                    static_cast<std::size_t>(world.config_.chunk_size) * 8 + 4096);
        le(out, world.tick_index_); le(out, world.completed_tick_index_);
        flag(out, world.tick_failed_); le(out, static_cast<std::uint8_t>(world.backend()));
        le(out, static_cast<std::uint32_t>(world.config_.chunk_size));
        le(out, static_cast<std::uint32_t>(coords.size()));
        std::array<std::uint64_t, kMaterialDefinitions.size()> species{};
        for (const auto coord : coords) {
            const auto& chunk = *world.find_chunk(coord);
            le(out, coord.x); le(out, coord.y);
            le(out, static_cast<std::uint32_t>(chunk.cells.size()));
            for (std::size_t i = 0; i < chunk.cells.size(); ++i) {
                const auto& cell = chunk.cells[i];
                const auto m = static_cast<std::uint16_t>(cell.material_value());
                fixture::require(m < species.size(), "record material outside catalogue");
                ++species[m]; ++result.cells;
                if (cell.material_value() == Material::Water) result.water += cell.state_a_value();
                if (cell.material_value() == Material::Sand) ++result.sand;
                le(out, m); le(out, cell.state_a_value()); le(out, cell.state_b_value());
                le(out, chunk.temperatures ? (*chunk.temperatures)[i] : world.config_.ambient_temperature);
                // Compare the actual consumer predicate, never numeric epochs.
                flag(out, cell.epoch_value() == world.update_epoch_);
            }
            le(out, static_cast<std::uint32_t>(chunk.activity_blocks.size()));
            for (const auto& block : chunk.activity_blocks) {
                le(out, block.next_interaction_tick); le(out, block.quiet_ticks);
                flag(out, block.active); flag(out, block.changed_this_tick);
            }
            le(out, static_cast<std::uint64_t>(chunk.non_empty_cell_count));
            le(out, chunk.quiet_ticks); flag(out, chunk.active); flag(out, chunk.changed_this_tick);
            flag(out, chunk.dirty); le(out, chunk.dirty_min_x); le(out, chunk.dirty_min_y);
            le(out, chunk.dirty_max_x); le(out, chunk.dirty_max_y);
        }
        flag(out, world.simulation_region_.has_value());
        if (world.simulation_region_) {
            const auto r = *world.simulation_region_;
            le(out, r.x); le(out, r.y); le(out, r.width); le(out, r.height);
        }
        const auto range = [&](const auto& r) {
            flag(out, r.has_value());
            if (r) { le(out, r->min_x); le(out, r->min_y); le(out, r->max_x); le(out, r->max_y); }
        };
        range(world.selected_core_region_); range(world.applied_core_region_);
        le(out, static_cast<std::uint32_t>(world.pending_explosions_.size()));
        for (const auto& event : world.pending_explosions_) {
            le(out, event.x); le(out, event.y); le(out, event.radius); le(out, event.collapse_strength);
        }
        le(out, world.hard_surface_revision_);
        le(out, stats.tick); le(out, stats.visited_cells); le(out, stats.moved_cells);
        le(out, stats.active_chunks_before); le(out, stats.active_chunks_after);
        le(out, stats.active_blocks_after); le(out, stats.dirty_chunks); le(out, stats.scheduled_cores);
        for (const auto jobs : stats.phase_jobs) le(out, jobs);
        le(out, stats.chunk_allocations); le(out, stats.temperature_field_allocations);
        le(out, stats.deferred_events); le(out, result.water); le(out, result.sand);
        le(out, static_cast<std::uint32_t>(species.size()));
        for (const auto n : species) le(out, n);
        le(out, static_cast<std::uint32_t>(supports.size()));
        for (const auto& [x, y] : supports) {
            le(out, x); le(out, y);
            flag(out, world.granular_support_at(x, y, false, false));
            flag(out, world.granular_support_at(x, y, true, false));
        }
        std::vector<std::pair<std::uint32_t, std::uint64_t>> diagnostics;
        if (world.physics_totals_) {
            for (const auto& entry : world.physics_totals_->entries)
                if (entry.key != 0) diagnostics.emplace_back(entry.key, entry.count);
            fixture::require(world.physics_totals_->overflow == 0, "diagnostic ledger overflow");
        }
        std::sort(diagnostics.begin(), diagnostics.end());
        le(out, static_cast<std::uint32_t>(diagnostics.size()));
        for (const auto& [key, count] : diagnostics) { le(out, key); le(out, count); }
        le(out, world.physics_totals_ ? world.physics_totals_->overflow : std::uint64_t{0});
        return result;
    }
    static fixture::Memory memory(const World& world) {
        fixture::Memory m;
        for (const auto& [coord, chunk] : world.chunks_) {
            (void)coord;
            m.cells += chunk->cells.size();
            m.cell_size += chunk->cells.size() * sizeof(World::Chunk::Cell);
            m.cell_capacity += chunk->cells.capacity() * sizeof(World::Chunk::Cell);
            if (chunk->temperatures) m.temperature += chunk->temperatures->capacity() * sizeof(std::int16_t);
            m.activity += chunk->activity_blocks.capacity() * sizeof(World::Chunk::ActivityBlock);
            m.descriptors += sizeof(World::Chunk);
#if MAT003_SPLIT
            m.tails += chunk->mat003_tails.capacity() * sizeof(mat003_world::Tail);
#endif
        }
        m.world_size = sizeof(World);
        m.scratch = world.active_chunk_scratch_.capacity() * sizeof(ChunkCoord) +
                    world.active_core_scratch_.capacity() * sizeof(SchedulingCoreCoord) +
                    world.pending_explosions_.capacity() * sizeof(World::ExplosionCommand);
        if (world.parallel_) {
            m.scratch += world.parallel_->results.capacity() * sizeof(World::ParallelState::JobResult);
            m.scratch += world.parallel_->phase_job_indices.capacity() * sizeof(std::size_t);
            m.scratch += world.parallel_->physics.capacity() * sizeof(PhysicsJobHistogram);
        }
        m.legacy_aggregate = world.resident_cell_bytes();
        return m;
    }
    static void fill_forced(World& world) {
        // Raw storage stress, explicitly outside valid material-state APIs.
        // Empty high-a and reserved bits test preservation, not new semantics.
        std::uint64_t ordinal = 0;
        for (const auto coord : coordinates(world)) {
            auto& chunk = *world.find_chunk(coord);
            for (std::size_t i = 0; i < chunk.cells.size(); ++i, ++ordinal) {
                auto& cell = chunk.cells[i];
                cell.set_state_a(static_cast<std::uint16_t>((ordinal * 257U + 0x8101U) & 65535U));
                cell.set_state_b(static_cast<std::uint8_t>(ordinal * 17U + 129U));
                cell.set_epoch(static_cast<Epoch>(std::numeric_limits<Epoch>::max() - 1U));
                const auto reserved = static_cast<std::uint16_t>((ordinal * 31U + 0x81a5U) &
                    (MAT003_EPOCH_BITS == 8 ? 65535U : 255U));
#if MAT003_STORAGE_KIND == 0
                cell.bits = (cell.bits & ~(std::uint64_t{65535} << 40U)) |
                            (std::uint64_t{reserved} << 40U);
#else
                cell.reserved(reserved);
#endif
                if (chunk.temperatures) (*chunk.temperatures)[i] =
                    static_cast<std::int16_t>(static_cast<int>(ordinal % 4001U) - 2000);
                const auto tail = static_cast<std::uint16_t>((ordinal * 73U + 0x81a5U) &
                    (MAT003_EXTRA_BYTES == 1 ? 255U : 65535U));
#if MAT003_SPLIT
                chunk.mat003_tails[i] = static_cast<mat003_world::Tail>(tail);
#else
                mat003_world::set_extra(cell, tail);
#endif
            }
        }
        world.update_epoch_ = static_cast<Epoch>(std::numeric_limits<Epoch>::max() - 1U);
    }
    static std::uint64_t check_forced(const World& world) {
        std::uint64_t ordinal = 0;
        for (const auto coord : coordinates(world)) {
            const auto& chunk = *world.find_chunk(coord);
            for (std::size_t i = 0; i < chunk.cells.size(); ++i, ++ordinal) {
                const auto& cell = chunk.cells[i];
                fixture::require(cell.epoch_value() == 0, "forced clear missed resident stamp");
                fixture::require(cell.material_value() == Material::Empty &&
                    cell.state_a_value() == static_cast<std::uint16_t>((ordinal * 257U + 0x8101U) & 65535U) &&
                    cell.state_b_value() == static_cast<std::uint8_t>(ordinal * 17U + 129U),
                    "forced clear changed non-epoch fields");
                const auto expected_reserved = static_cast<std::uint16_t>((ordinal * 31U + 0x81a5U) &
                    (MAT003_EPOCH_BITS == 8 ? 65535U : 255U));
#if MAT003_STORAGE_KIND == 0
                fixture::require(((cell.bits >> 40U) & 65535U) == expected_reserved,
                                 "forced clear changed source reserved bits");
#else
                fixture::require(cell.reserved() == expected_reserved,
                                 "forced clear changed candidate reserved bits");
#endif
                if (chunk.temperatures)
                    fixture::require((*chunk.temperatures)[i] ==
                        static_cast<std::int16_t>(static_cast<int>(ordinal % 4001U) - 2000),
                        "forced clear changed nonambient temperature");
#if MAT003_EXTRA_BYTES > 0
                const auto expected = static_cast<std::uint16_t>((ordinal * 73U + 0x81a5U) &
                    (MAT003_EXTRA_BYTES == 1 ? 255U : 65535U));
#if MAT003_SPLIT
                fixture::require(chunk.mat003_tails[i] == expected, "forced clear changed split payload");
#else
                fixture::require(mat003_world::get_extra(cell) == expected, "forced clear changed AoS payload");
#endif
#endif
            }
        }
        return ordinal;
    }
};
}

namespace fixture {
using cybersand::Material;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::PrecisionProbe;
using cybersand::SimulationBackend;
using cybersand::TickStats;
using cybersand::RectI64;

// Lossless byte-range delta format, version 1. The independent Python decoder
// reconstructs every full snapshot; no hash substitutes for semantic bytes.
class Trace {
public:
    explicit Trace(const std::filesystem::path& path) : output_(path, std::ios::binary) {
        require(output_.is_open(), "cannot open trace output");
        output_.write("M3WDEL1\n", 8);
    }
    void write(const Bytes& bytes) {
        require(bytes.size() <= std::numeric_limits<std::uint32_t>::max(), "trace frame too large");
        std::vector<std::pair<std::uint32_t, std::uint32_t>> ranges;
        std::size_t i = 0;
        while (i < bytes.size()) {
            if (i < previous_.size() && bytes[i] == previous_[i]) { ++i; continue; }
            const auto start = i++;
            std::size_t last_difference = i;
            while (i < bytes.size()) {
                if (i >= previous_.size() || bytes[i] != previous_[i]) last_difference = i + 1;
                else if (i - last_difference >= 8) break;
                ++i;
            }
            i = last_difference;
            ranges.emplace_back(static_cast<std::uint32_t>(start),
                                static_cast<std::uint32_t>(i - start));
        }
        Bytes prefix;
        le(prefix, static_cast<std::uint32_t>(bytes.size()));
        le(prefix, static_cast<std::uint32_t>(ranges.size()));
        put(prefix);
        for (const auto& [start, size] : ranges) {
            prefix.clear(); le(prefix, start); le(prefix, size); put(prefix);
            output_.write(reinterpret_cast<const char*>(bytes.data() + start), size);
        }
        require(static_cast<bool>(output_), "trace write failed");
        previous_ = bytes; ++frames;
    }
    void close() { output_.close(); require(!output_.fail(), "trace close failed"); }
    std::uint64_t frames = 0;
private:
    void put(const Bytes& bytes) {
        output_.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    }
    std::ofstream output_;
    Bytes previous_;
};

std::string array_json(const std::vector<std::uint64_t>& values) {
    std::ostringstream out; out << '[';
    for (std::size_t i = 0; i < values.size(); ++i) { if (i) out << ','; out << values[i]; }
    out << ']'; return out.str();
}
std::string memory_json(const Memory& m) {
    std::ostringstream out;
    out << "{\"resident_cells\":" << m.cells << ",\"cell_array_used_bytes\":" << m.cell_size
        << ",\"cell_array_capacity_bytes\":" << m.cell_capacity
        << ",\"temperature_capacity_bytes\":" << m.temperature
        << ",\"activity_capacity_bytes\":" << m.activity << ",\"tail_capacity_bytes\":" << m.tails
        << ",\"chunk_descriptor_bytes\":" << m.descriptors << ",\"scratch_capacity_bytes\":" << m.scratch
        << ",\"world_object_bytes\":" << m.world_size << ",\"legacy_aggregate_bytes\":" << m.legacy_aggregate
        << ",\"allocator_overhead_bytes\":null,\"legacy_aggregate_is_component_sum_not_additive\":true}";
    return out.str();
}
std::string dispatch_json() {
    const auto d = mat003_world::dispatch_observations();
    std::ostringstream out;
    out << "{\"observed\":" << (mat003_world::dispatch_observed ? "true" : "false")
        << ",\"calls\":" << d.calls << ",\"dispatched_tasks\":" << d.dispatched_tasks
        << ",\"worker_tasks\":" << d.worker_tasks << '}';
    return out.str();
}
void box(World& world, std::int64_t x, std::int64_t y, int width, int height) {
    for (int iy = 0; iy < height; ++iy) for (int ix = 0; ix < width; ++ix)
        if (ix == 0 || iy == 0 || ix == width - 1 || iy == height - 1)
            world.set(x + ix, y + iy, Material::Wall);
}
void seed_sentinels(World& world, std::int64_t x, std::int64_t y) {
    world.set(x, y, Material::Wall);
    PrecisionProbe::raw_a(world, x, y, 0xcdefU);
    world.set_temperature(x, y, -1234);
    require(world.set_cell_state(x + 1, y, Material::Empty, 17, 29), "nonzero Empty fixture write");
    require(world.stored_state_a(x, y) == 0xcdefU && world.stored_state_a(x + 1, y) == 17,
            "sentinel widths not retained");
}
void check_step(World& world, const TickStats& stats, std::uint64_t tick) {
    require(stats.tick == tick && world.tick_index() == tick &&
            world.completed_tick_index() == tick && !world.has_failed(),
            "tick did not complete exactly once");
}
struct ClearObservation {
    std::uint64_t tick;
    std::uint32_t before, after;
    bool sentinel_observed = false;
    std::uint32_t sentinel_before = 0, sentinel_after = 0;
};
inline std::vector<ClearObservation> clear_observations;
void note_clear(std::vector<std::uint64_t>& clears, PrecisionProbe::Epoch before,
                const World& world, std::uint64_t tick) {
    const auto after = PrecisionProbe::epoch(world);
    if (before > after) {
        clears.push_back(tick);
        clear_observations.push_back({tick, before, after});
    }
}
void check_clears(const std::vector<std::uint64_t>& clears, std::uint64_t ticks) {
    std::vector<std::uint64_t> expected;
    const auto period = std::uint64_t{1} << MAT003_EPOCH_BITS;
    for (auto tick = period; tick <= ticks; tick += period - 1) expected.push_back(tick);
    require(clears == expected, "actual World rollover schedule mismatch");
}
std::string suite_json(const std::string& name, const std::string& file, std::uint64_t ticks,
                       std::uint64_t frames, const std::string& backend, unsigned workers,
                       const std::vector<std::uint64_t>& clears, const Snapshot& initial,
                       const Snapshot& final, const World& world) {
    std::ostringstream out;
    out << "{\"name\":\"" << name << "\",\"file\":\"" << file << "\",\"ticks\":" << ticks
        << ",\"frames\":" << frames << ",\"backend\":\"" << backend << "\",\"workers\":" << workers
        << ",\"clears\":" << array_json(clears) << ",\"water_initial\":" << initial.water
        << ",\"water_final\":" << final.water << ",\"sand_initial\":" << initial.sand
        << ",\"sand_final\":" << final.sand << ",\"maximum_observed_cells\":" << final.cells
        << ",\"dispatch\":" << dispatch_json() << ",\"memory\":" << memory_json(PrecisionProbe::memory(world))
        << ",\"clear_observations\":[";
    for (std::size_t i = 0; i < clear_observations.size(); ++i) {
        if (i) out << ',';
        const auto& c = clear_observations[i];
        out << "{\"tick\":" << c.tick << ",\"before\":" << c.before << ",\"after\":" << c.after
            << ",\"sentinel_observed\":" << (c.sentinel_observed ? "true" : "false")
            << ",\"sentinel_before\":" << c.sentinel_before << ",\"sentinel_after\":" << c.sentinel_after << '}';
    }
    out << ']' << '}';
    return out.str();
}

std::string ordinary(const std::filesystem::path& output, SimulationBackend backend, unsigned workers) {
    const std::string name = backend == SimulationBackend::SerialInPlace ? "ordinary-serial" :
        "ordinary-phased-" + std::to_string(workers);
    clear_observations.clear();
    WorldConfig config;
    config.backend = backend; config.worker_threads = workers; config.parallel_job_threshold = 1;
    config.physics_diagnostics.enabled = true;
    mat003_world::reset_dispatch_observations();
    World world(config);
    world.reserve_region({-128, -128, 256, 256});
    box(world, -4, -3, 9, 12);
    for (int y = 3; y < 8; ++y) for (int x = -3; x < 4; ++x) world.set(x, y, Material::Water);
    for (int x = -2; x < 2; ++x) world.set(x, 0, Material::Sand);
    // The basin crosses zero: a signed 64-core and 128-storage seam.
    box(world, -34, 0, 4, 3);
    world.set(-33, 1, Material::Brine); world.set(-32, 1, Material::BareIron);
    box(world, 30, 4, 5, 5);
    seed_sentinels(world, -20, -20);
    const std::vector<Point> support{{-1, 0}, {-1, 7}, {-33, 1}, {-20, -20}};
    Trace trace(output / (name + ".bin"));
    const auto initial = PrecisionProbe::snapshot(world, {}, support);
    trace.write(initial.bytes);
    auto final = initial;
    std::vector<std::uint64_t> clears;
    for (std::uint64_t tick = 1; tick <= 2048; ++tick) {
        if (tick == 255 || tick == 256 || tick == 1021)
            require(world.queue_explosion(32, 6, 1, 0), "ordinary event queue refused");
        const auto before = PrecisionProbe::epoch(world);
        const auto stats = world.tick(); check_step(world, stats, tick); note_clear(clears, before, world, tick);
        if (tick == 255 || tick == 256 || tick == 1021)
            require(world.get(32, 6) == Material::Fire && world.stored_state_a(32, 6) ==
                cybersand::material_definition(Material::Fire).initial_state_a && stats.deferred_events == 1,
                "event-prewritten destination received a same-tick rule");
        final = PrecisionProbe::snapshot(world, stats, support);
        require(final.water == initial.water, "ordinary closed Water ledger changed");
        require(final.sand == initial.sand, "ordinary closed Sand ledger changed");
        trace.write(final.bytes);
    }
    check_clears(clears, 2048);
    if (workers == 4 && mat003_world::dispatch_observed) {
        const auto d = mat003_world::dispatch_observations();
        require(d.calls > 0 && d.dispatched_tasks > 0 && d.worker_tasks == d.dispatched_tasks,
                "configured workers did not execute every dispatched task");
    }
    require(world.get(-32, 1) == Material::RustedSteel && world.get(-33, 1) == Material::Brine,
            "Brine/BareIron reactive specimen did not produce the declared products");
    require(PrecisionProbe::event_count(world, cybersand::PhysicsEvent::Conversion) > 0,
            "reactive source/sink ledger was vacuous");
    trace.close();
    return suite_json(name, name + ".bin", 2048, trace.frames,
                      backend == SimulationBackend::SerialInPlace ? "serial" : "phased",
                      workers, clears, initial, final, world);
}

std::string natural(const std::filesystem::path& output) {
    clear_observations.clear();
    WorldConfig config;
    config.chunk_size = 16; config.scheduling_core_size = 4; config.activity_block_size = 4;
    config.initial_chunk_reserve = 1; config.maximum_chunk_count = 1;
    config.active_chunk_capacity = 1; config.active_core_capacity = 16;
    config.physics_diagnostics.enabled = false;
    mat003_world::reset_dispatch_observations();
    World world(config);
    world.reserve_region({0, 0, 16, 16});
    world.set_simulation_region(RectI64{4, 4, 8, 4});
    box(world, 4, 4, 4, 4);
    require(world.set_cell_state(5, 6, Material::Water, 173, 0), "natural first Water write");
    require(world.set_cell_state(6, 6, Material::Water, 82, 0), "natural second Water write");
    box(world, 8, 8, 4, 4);
    for (int y = 9; y < 11; ++y) for (int x = 9; x < 11; ++x) world.set(x, y, Material::Sand);
    box(world, 8, 3, 5, 5);
    seed_sentinels(world, 1, 1);
    const std::vector<Point> support{{9, 9}, {10, 9}, {9, 10}, {5, 6}, {1, 1}};
    Trace trace(output / "natural.bin");
    const auto initial = PrecisionProbe::snapshot(world, {}, support);
    require(PrecisionProbe::epoch(world) == 0 && world.tick_index() == 0 && initial.cells == 256,
            "natural fixture is not a fresh bounded real World");
    trace.write(initial.bytes);
    auto final = initial;
    std::vector<std::uint64_t> clears;
    for (std::uint64_t tick = 1; tick <= 131080; ++tick) {
        if (tick == 65534 || tick == 131069)
            require(world.relocate_stored_cell(5, 6, 5, 5), "natural near-wrap Water wake relocation");
        if (tick == 65535 || tick == 131070) {
            require(world.set_cell_state(9, 9, Material::Sand, static_cast<std::uint16_t>(tick == 65535 ? 1 : 2), 0),
                    "natural paused grain edit");
            // Same input schedule in every arm. Refresh the inert sentinel's
            // actual stamp; its full-a16 raw payload remains independently labelled.
            require(world.set_cell_state(1, 1, Material::Wall, 23, 0), "near-wrap inert sentinel stamp");
            PrecisionProbe::raw_a(world, 1, 1, 0xcdefU);
        }
        if (tick == 65536 || tick == 131071)
            require(world.queue_explosion(10, 5, 1, 0), "natural near-wrap event refusal");
        if (tick == 65540 || tick == 131075) world.set_simulation_region(RectI64{4, 4, 8, 8});
        if (tick == 65550) world.set_simulation_region(RectI64{4, 4, 8, 4});
        const auto before = PrecisionProbe::epoch(world);
        const auto sentinel_before = PrecisionProbe::cell_epoch(world, 1, 1);
        const auto stats = world.tick(); check_step(world, stats, tick); note_clear(clears, before, world, tick);
        if (tick == 65536 || tick == 131071) {
            const auto sentinel_after = PrecisionProbe::cell_epoch(world, 1, 1);
            require(sentinel_before != 0 && sentinel_after == 0,
                    "natural clear did not reset nonzero excluded inert sentinel");
            require(!clear_observations.empty() && clear_observations.back().tick == tick,
                    "natural sentinel reset has no observed counter rollover");
            auto& observed = clear_observations.back();
            observed.sentinel_observed = true;
            observed.sentinel_before = sentinel_before;
            observed.sentinel_after = sentinel_after;
        }
        if (tick == 65536 || tick == 131071)
            require(world.get(10, 5) == Material::Fire && world.stored_state_a(10, 5) ==
                cybersand::material_definition(Material::Fire).initial_state_a && stats.deferred_events == 1,
                "natural rollover event double-updated");
        if (tick == 65537 || tick == 131072) {
            unsigned fires = 0, life = 0;
            for (int y = 4; y <= 6; ++y) for (int x = 9; x <= 11; ++x)
                if (world.get(x, y) == Material::Fire) { ++fires; life += world.stored_state_a(x, y); }
            require(fires == 1 && life + 1 == cybersand::material_definition(Material::Fire).initial_state_a,
                    "post-rollover Fire received missed or double lifetime update");
        }
        if (tick == 65539) require(!world.granular_support_at(9, 9, false, false), "excluded active grain bears load");
        if (tick == 65540 || tick == 131075)
            require(world.granular_support_at(9, 9, false, false), "reentered settled grains lost support");
        final = PrecisionProbe::snapshot(world, stats, support);
        require(final.cells == 256 && world.chunk_count() == 1, "natural fixture grew outside registered capacity");
        require(final.water == initial.water, "natural closed Water ledger changed");
        require(final.sand == initial.sand, "natural closed Sand ledger changed");
        trace.write(final.bytes);
    }
    check_clears(clears, 131080); trace.close();
    return suite_json("natural", "natural.bin", 131080, trace.frames, "phased", 1,
                      clears, initial, final, world);
}

std::string forced(unsigned side) {
    WorldConfig config;
    World world(config);
    world.reserve_region({0, 0, side, side});
    world.reserve_temperature_region({0, 0, 128, 128});
    world.set_simulation_region(RectI64{static_cast<std::int64_t>(side) + 256, 0, 64, 64});
    PrecisionProbe::fill_forced(world);
    require(world.tick_index() == 0, "forced seeding altered global clock");
    const auto before = PrecisionProbe::memory(world);
    auto stats = world.tick(); check_step(world, stats, 1);
    require(PrecisionProbe::epoch(world) == std::numeric_limits<PrecisionProbe::Epoch>::max(),
            "forced first tick did not reach actual maximum");
    stats = world.tick(); check_step(world, stats, 2);
    require(PrecisionProbe::epoch(world) == 1 && stats.visited_cells == 0,
            "forced all-resident rollover changed work schedule");
    const auto cells = PrecisionProbe::check_forced(world);
    require(cells == static_cast<std::uint64_t>(side) * side, "forced residency was not the requested scale");
    std::ostringstream out;
    out << "{\"resident_side\":" << side << ",\"resident_cells\":" << cells
        << ",\"cleared_cells\":" << cells << ",\"global_tick_before\":0,\"global_tick_after\":2,"
        << "\"non_epoch_preserved\":true,\"raw_storage_stress\":true,\"natural_run\":false,\"memory\":"
        << memory_json(before) << '}';
    return out.str();
}

std::string lifecycle() {
    std::vector<std::string> checks;
    World world;
    world.reserve_region({-256, -128, 512, 256});
    world.set(-129, -1, Material::Sand); world.set_temperature(-129, -1, 777);
    PrecisionProbe::extra(world, -129, -1, MAT003_EXTRA_BYTES == 1 ? 0xa5 : 0x81a5);
    PrecisionProbe::move(world, -129, -1, -128, 0, false);
    require(world.get(-128, 0) == Material::Sand && world.get(-129, -1) == Material::Empty &&
            world.temperature(-128, 0) == 777 && world.temperature(-129, -1) == 200,
            "signed seam whole-cell move lost material/temperature");
#if MAT003_EXTRA_BYTES > 0
    require(PrecisionProbe::extra(world, -128, 0) == (MAT003_EXTRA_BYTES == 1 ? 0xa5 : 0x81a5) &&
            PrecisionProbe::extra(world, -129, -1) == 0, "whole-cell move lost neutral payload ownership");
#endif
    world.set(-127, 0, Material::Wood);
    PrecisionProbe::extra(world, -127, 0, MAT003_EXTRA_BYTES == 1 ? 0x80 : 0x8001);
    PrecisionProbe::move(world, -128, 0, -127, 0, true);
    require(world.get(-128, 0) == Material::Wood && world.get(-127, 0) == Material::Sand,
            "swap changed source/destination ownership");
#if MAT003_EXTRA_BYTES > 0
    require(PrecisionProbe::extra(world, -128, 0) == (MAT003_EXTRA_BYTES == 1 ? 0x80 : 0x8001) &&
            PrecisionProbe::extra(world, -127, 0) == (MAT003_EXTRA_BYTES == 1 ? 0xa5 : 0x81a5),
            "swap failed to exchange neutral payloads");
#endif
    checks.push_back("signed_move_swap_temperature_neutral_tail");
    require(world.set_cell_state(-1, -1, Material::Water, 173, 7) &&
            world.set_cell_state(0, -1, Material::Water, 20, 2), "partial Water setup");
    PrecisionProbe::extra(world, -1, -1, 128); PrecisionProbe::extra(world, 0, -1, 129);
    require(PrecisionProbe::transfer(world, -1, -1, 0, -1, 50) == 50 &&
            world.liquid_mass(-1, -1) == 123 && world.liquid_mass(0, -1) == 70 &&
            world.stored_state_b(0, -1) == 7, "partial Water transfer mass/coherence mismatch");
#if MAT003_EXTRA_BYTES > 0
    require(PrecisionProbe::extra(world, -1, -1) == 128 && PrecisionProbe::extra(world, 0, -1) == 129,
            "partial Water transfer changed endpoint neutral payload");
#endif
    require(PrecisionProbe::transfer(world, -1, -1, 0, -1, 255) == 123 &&
            world.get(-1, -1) == Material::Empty && world.liquid_mass(0, -1) == 193,
            "full Water transfer/reset ledger mismatch");
    require(PrecisionProbe::extra(world, -1, -1) == 0, "exhausted Water retained extra state");
    world.set(0, -1, Material::Wall);
    require(PrecisionProbe::extra(world, 0, -1) == 0, "replacement retained neutral payload");
    checks.push_back("partial_full_water_and_replacement_reset");

    require(world.set_cell_state(2, -1, Material::Water, 120, 6) &&
            world.set_cell_state(3, -1, Material::Empty, 17, 29), "new Water destination setup");
    PrecisionProbe::extra(world, 2, -1, 130); PrecisionProbe::extra(world, 3, -1, 131);
    require(PrecisionProbe::transfer(world, 2, -1, 3, -1, 50) == 50 &&
            world.liquid_mass(2, -1) == 70 && world.liquid_mass(3, -1) == 50 &&
            world.stored_state_b(3, -1) == 6 && PrecisionProbe::extra(world, 3, -1) == 0,
            "new Water destination retained stale Empty payload");
#if MAT003_EXTRA_BYTES > 0
    require(PrecisionProbe::extra(world, 2, -1) == 130, "partial transfer changed surviving source payload");
#endif
    require(world.set_cell_state(2, -1, Material::Water, 71, 6) &&
            PrecisionProbe::extra(world, 2, -1) == 0, "changed write_cell retained neutral payload");
    PrecisionProbe::extra(world, 2, -1, 132);
    const auto noop_stamp = PrecisionProbe::cell_epoch(world, 2, -1);
    require(!world.set_cell_state(2, -1, Material::Water, 71, 6) &&
            PrecisionProbe::cell_epoch(world, 2, -1) == noop_stamp,
            "same-value write_cell changed stamp or reported mutation");
#if MAT003_EXTRA_BYTES > 0
    require(PrecisionProbe::extra(world, 2, -1) == 132, "same-value write_cell cleared neutral payload");
#endif
    checks.push_back("new_water_destination_changed_write_and_noop_payload");

    World admission;
    (void)admission.tick();
    std::vector<Material> payload(128 * 128, Material::Empty);
    payload[65 * 128 + 65] = Material::Sand;
    require(admission.install_generated_chunk({-1, -1}, payload) == cybersand::ChunkInstallOutcome::Installed,
            "new generated chunk was refused");
    const auto admitted = admission.tick();
    require(admitted.tick == 2 && admission.get(-63, -62) == Material::Sand,
            "newly admitted grain missed its first update");
    admission.clear();
    require(PrecisionProbe::epoch(admission) == 0 && admission.tick_index() == 0 && admission.chunk_count() == 0,
            "clear retained epoch or chunks");
    admission = World{};
    admission.set(10, 10, Material::Sand);
    require(admission.tick().tick == 1 && admission.get(10, 11) == Material::Sand,
            "replacement World missed a fresh first update");
    checks.push_back("admission_clear_replacement_first_update");

    World general(WorldConfig{16, 3, 200});
    general.set(-1, -1, Material::Sand);
    require(general.tick().tick == 1 && general.get(-1, 0) == Material::Sand,
            "general cross-chunk scan missed or double-updated grain");
    checks.push_back("general_scan_path_signed_seam");

    WorldConfig failure_config;
    failure_config.active_core_capacity = 1;
    failure_config.active_chunk_capacity = 8;
    World failure(failure_config);
    failure.set(20, 20, Material::Sand);
    require(failure.tick().tick == 1, "failed-world baseline tick");
    failure.set(20, 20, Material::Wall); failure.set(21, 20, Material::Wall);
    failure.set(160, 20, Material::Sand);
    require(failure.queue_explosion(20, 20, 1, 0), "failed-world event refused");
    PrecisionProbe::seed_epoch(failure, std::numeric_limits<PrecisionProbe::Epoch>::max());
    bool threw = false;
    try { (void)failure.tick(); } catch (const std::runtime_error&) { threw = true; }
    require(threw && failure.has_failed() && failure.tick_index() == 2 &&
            failure.completed_tick_index() == 1 && PrecisionProbe::epoch(failure) == 1,
            "failed rollover did not quarantine attempted progress");
    const auto failed_hash = failure.state_hash();
    threw = false; try { (void)failure.tick(); } catch (const std::exception&) { threw = true; }
    require(threw && failure.state_hash() == failed_hash &&
            !failure.queue_explosion(20, 20, 1, 0), "quarantined World resumed or accepted event");
    require(!failure.set_cell_state(40, 20, Material::Water, 255, 0),
            "quarantined World accepted cell state");
    require(!failure.relocate_stored_cell(160, 20, 161, 20),
            "quarantined World relocated a cell");
    std::vector<Material> failed_payload(128 * 128, Material::Empty);
    require(failure.install_generated_chunk({5, 5}, failed_payload) == cybersand::ChunkInstallOutcome::WorldFailed,
            "quarantined World admitted generated storage");
    threw = false; try { failure.set(40, 20, Material::Sand); } catch (const std::logic_error&) { threw = true; }
    require(threw, "quarantined World accepted material edit");
    threw = false; try { failure.set_temperature(40, 20, 777); } catch (const std::logic_error&) { threw = true; }
    require(threw && failure.state_hash() == failed_hash, "quarantine mutation changed failed state");
    failure.clear(); failure.set(20, 20, Material::Sand);
    require(failure.tick().tick == 1 && failure.get(20, 21) == Material::Sand,
            "failed-world clear did not recover");
    checks.push_back("failed_rollover_quarantine_clear_recovery");

    // Configured transport entry is exercised directly; ordinary defaults do
    // not imply that mix_after_motion was reached.
    WorldConfig transport_config;
    transport_config.physics_diagnostics.enabled = true;
    transport_config.transport_policy.configured = true;
    auto& pair = transport_config.transport_policy.pairs[3 * 81 + 2];
    pair.carrying = 255; pair.erosion = true;
    World transport(transport_config);
    // At (0,0), the existing four-tick transport lane is zero. Both calls
    // retain global tick zero, mass255 and identical geometry; only the grain
    // stamp changes from current to stale for this declared direct-entry probe.
    transport.set(0, 1, Material::Sand);
    transport.set(1, 0, Material::Water);
    require(PrecisionProbe::mix(transport, 0, 0) == 0 &&
            transport.get(0, 1) == Material::Sand && transport.get(1, 0) == Material::Water,
            "current-epoch grain was picked up twice");
    PrecisionProbe::stale_stamp(transport, 0, 1);
    const auto transport_count = PrecisionProbe::mix(transport, 0, 0);
    require(transport_count == 1 && transport.get(0, 1) == Material::Water &&
            transport.get(1, 0) == Material::Sand && transport.liquid_mass(0, 1) == 255,
            "eligible unstamped grain did not enter conservative horizontal transport");
    require(PrecisionProbe::mix(transport, 0, 0) == 1, "transport repeated an already completed pickup");
    checks.push_back("configured_transport_current_stamp_rejection_and_stale_pickup");

    std::ostringstream out;
    out << "{\"checks\":[";
    for (std::size_t i = 0; i < checks.size(); ++i) { if (i) out << ','; out << '"' << checks[i] << '"'; }
    out << "],\"configured_transport_grain_events\":" << transport_count
        << ",\"coverage_gaps\":[\"Godot bearing/collision adapters not executed\"],"
           "\"neutral_payload_is_synthetic\":true,\"high_a16_is_inert_raw_storage_probe\":true}";
    return out.str();
}
}

int main(int argc, char** argv) {
    try {
        fixture::require(argc == 3 && std::string(argv[1]) == "--output", "usage: test_world --output <new-directory>");
        const std::filesystem::path output(argv[2]);
        fixture::require(!std::filesystem::exists(output), "fixture output already exists");
        std::filesystem::create_directories(output);
        const auto serial = fixture::ordinary(output, cybersand::SimulationBackend::SerialInPlace, 1);
        const auto phased1 = fixture::ordinary(output, cybersand::SimulationBackend::PhasedInPlace, 1);
        const auto phased4 = fixture::ordinary(output, cybersand::SimulationBackend::PhasedInPlace, 4);
        const auto natural = fixture::natural(output);
        std::vector<std::string> forced;
        for (const unsigned side : {512U, 1024U, 2048U}) forced.push_back(fixture::forced(side));
        const auto lifecycle = fixture::lifecycle();
        const char* representations[] = {"source", "word", "padded", "packed", "aligned", "split"};
        std::ostringstream json;
        json << "{\"schema_version\":1,\"stage\":\"S1-World-correctness\",\"status\":\"passed\","
             << "\"arm_id\":\"" << MAT003_ARM_ID << "\",\"logical_bits\":" << 64 + 8 * MAT003_EXTRA_BYTES
             << ",\"epoch_bits\":" << MAT003_EPOCH_BITS << ",\"representation\":\"" << representations[MAT003_STORAGE_KIND]
             << "\",\"cell_stride\":" << cybersand::PrecisionProbe::stride()
             << ",\"cell_alignment\":" << cybersand::PrecisionProbe::alignment()
             << ",\"epoch_counter_bytes\":" << cybersand::PrecisionProbe::counter_bytes()
             << ",\"epoch_accessor_bytes\":" << cybersand::PrecisionProbe::accessor_bytes()
             << ",\"assertions\":" << fixture::assertions << ",\"ordinary\":[" << serial << ',' << phased1 << ',' << phased4
             << "],\"natural\":" << natural << ",\"forced\":[";
        for (std::size_t i = 0; i < forced.size(); ++i) { if (i) json << ','; json << forced[i]; }
        json << "],\"lifecycle\":" << lifecycle
             << ",\"scope\":{\"production_changed\":false,\"primary_timing\":false,\"natural_real_world\":true}}\n";
        const auto text = json.str();
        std::ofstream file(output / "result.json", std::ios::binary);
        fixture::require(file.is_open(), "result file open failed");
        file << text; file.close(); fixture::require(!file.fail(), "result file write failed");
        std::cout << text;
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "MAT003 World fixture failed: " << error.what() << '\n';
        return 1;
    }
}
