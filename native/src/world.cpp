#include "cybersand/world.hpp"

#include "cybersand/material_rules.hpp"
#include "cybersand/material_appearance.hpp"
#include "cybersand/render_snapshot.hpp"

#include "render_snapshot_internal.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <condition_variable>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <type_traits>
#include <utility>

namespace cybersand {
namespace {

[[nodiscard]] constexpr std::int64_t floor_div(std::int64_t value, std::int64_t divisor) noexcept {
    const auto quotient = value / divisor;
    const auto remainder = value % divisor;
    return remainder < 0 ? quotient - 1 : quotient;
}

[[nodiscard]] constexpr std::int32_t positive_mod(std::int64_t value, std::int32_t divisor) noexcept {
    const auto remainder = value % divisor;
    return static_cast<std::int32_t>(remainder < 0 ? remainder + divisor : remainder);
}

[[nodiscard]] constexpr std::uint64_t mix64(std::uint64_t value) noexcept {
    value ^= value >> 30U;
    value *= 0xbf58476d1ce4e5b9ULL;
    value ^= value >> 27U;
    value *= 0x94d049bb133111ebULL;
    return value ^ (value >> 31U);
}

void hash_byte(std::uint64_t& hash, std::uint8_t byte) noexcept {
    hash ^= byte;
    hash *= 1099511628211ULL;
}

template <typename Integer>
void hash_integer(std::uint64_t& hash, Integer value) noexcept {
    using Unsigned = std::make_unsigned_t<Integer>;
    auto bits = static_cast<Unsigned>(value);
    for (std::size_t index = 0; index < sizeof(Integer); ++index) {
        hash_byte(hash, static_cast<std::uint8_t>(bits & static_cast<Unsigned>(0xffU)));
        bits = static_cast<Unsigned>(bits >> 8U);
    }
}

struct RelativeCell {
    std::int8_t x;
    std::int8_t y;
};

inline constexpr std::array<RelativeCell, 8> kMooreNeighbours{{
    {-1, -1}, {0, -1}, {1, -1}, {-1, 0},
    {1, 0},   {-1, 1}, {0, 1},  {1, 1},
}};

[[nodiscard]] constexpr bool is_combustible(Material material) noexcept {
    return material_definition(material).kernel == RuleKernel::Combustible ||
           material == Material::Plant ||
           material == Material::Fungus || material == Material::Oil ||
           material == Material::Coal;
}

[[nodiscard]] constexpr bool is_timber(Material material) noexcept {
    return material == Material::Wood || material == Material::OakTimber;
}

[[nodiscard]] constexpr bool is_hot(Material material) noexcept {
    return material == Material::Fire || material == Material::Lava ||
           material == Material::Spark || material == Material::MoltenGlass;
}

struct CopyLayout {
    std::size_t row_bytes = 0;
    std::size_t required_bytes = 0;
};

[[nodiscard]] CopyLayout validate_copy_layout(RectI64 region, std::size_t bytes_per_cell,
                                              std::size_t stride_bytes,
                                              std::size_t destination_size) {
    if (region.width < 0 || region.height < 0) {
        throw std::invalid_argument("region dimensions must not be negative");
    }
    const auto width = static_cast<std::uint64_t>(region.width);
    const auto height = static_cast<std::uint64_t>(region.height);
    if (width > std::numeric_limits<std::size_t>::max() / bytes_per_cell) {
        throw std::overflow_error("region row byte count exceeds addressable size");
    }
    const auto row_bytes = static_cast<std::size_t>(width) * bytes_per_cell;
    if (stride_bytes < row_bytes) {
        throw std::invalid_argument("destination stride is too small");
    }
    std::size_t required = 0;
    if (height != 0U) {
        if (stride_bytes != 0U && height - 1U >
                                         (std::numeric_limits<std::size_t>::max() - row_bytes) /
                                             stride_bytes) {
            throw std::overflow_error("region destination byte count exceeds addressable size");
        }
        required = static_cast<std::size_t>(height - 1U) * stride_bytes + row_bytes;
    }
    if (destination_size < required) {
        throw std::invalid_argument("destination buffer is too small");
    }
    return {row_bytes, required};
}

class PersistentWorkerPool final {
public:
    using TaskFunction = void (*)(void*, std::size_t) noexcept;

    explicit PersistentWorkerPool(std::uint32_t worker_count) {
        workers_.reserve(worker_count);
        for (std::uint32_t index = 0; index < worker_count; ++index) {
            workers_.emplace_back([this] { worker_loop(); });
        }
    }

    ~PersistentWorkerPool() {
        {
            std::lock_guard lock(mutex_);
            stopping_ = true;
            ++generation_;
        }
        start_condition_.notify_all();
        workers_.clear();
    }

    PersistentWorkerPool(const PersistentWorkerPool&) = delete;
    PersistentWorkerPool& operator=(const PersistentWorkerPool&) = delete;

    void dispatch(std::size_t task_count, void* context, TaskFunction function) {
        if (task_count == 0) return;
        {
            std::lock_guard lock(mutex_);
            context_ = context;
            function_ = function;
            task_count_ = task_count;
            next_task_.store(0, std::memory_order_relaxed);
            workers_remaining_ = workers_.size();
            ++generation_;
        }
        start_condition_.notify_all();

        std::unique_lock lock(mutex_);
        done_condition_.wait(lock, [this] { return workers_remaining_ == 0; });
    }

private:
    void worker_loop() noexcept {
        std::uint64_t observed_generation = 0;
        for (;;) {
            TaskFunction function = nullptr;
            void* context = nullptr;
            std::size_t task_count = 0;
            {
                std::unique_lock lock(mutex_);
                start_condition_.wait(lock, [this, &observed_generation] {
                    return stopping_ || generation_ != observed_generation;
                });
                if (stopping_) return;
                observed_generation = generation_;
                function = function_;
                context = context_;
                task_count = task_count_;
            }

            for (;;) {
                const auto task = next_task_.fetch_add(1, std::memory_order_relaxed);
                if (task >= task_count) break;
                function(context, task);
            }
            {
                std::lock_guard lock(mutex_);
                if (--workers_remaining_ == 0) done_condition_.notify_one();
            }
        }
    }

    std::vector<std::jthread> workers_;
    std::mutex mutex_;
    std::condition_variable start_condition_;
    std::condition_variable done_condition_;
    std::atomic<std::size_t> next_task_{0};
    std::uint64_t generation_ = 0;
    std::size_t task_count_ = 0;
    std::size_t workers_remaining_ = 0;
    void* context_ = nullptr;
    TaskFunction function_ = nullptr;
    bool stopping_ = false;
};

}  // namespace

struct World::Chunk {
    struct Cell {
        Material material = Material::Empty;
        std::uint8_t state_a = 0;
        std::uint8_t state_b = 0;
        std::uint8_t updated_epoch = 0;

        [[nodiscard]] static constexpr Cell for_material(Material value) noexcept {
            const auto& definition = material_definition(value);
            return {
                value,
                definition.initial_state_a,
                definition.initial_state_b,
                0,
            };
        }
    };
    static_assert(sizeof(Cell) == 4, "hot cell layout must remain four bytes");

    struct ActivityBlock {
        std::uint32_t quiet_ticks = 0;
        bool active = false;
        bool changed_this_tick = false;
    };

    explicit Chunk(std::int32_t size, std::int32_t activity_block_size)
        : cells(static_cast<std::size_t>(size) * static_cast<std::size_t>(size),
                Cell::for_material(Material::Empty)),
          activity_blocks_per_axis((size + activity_block_size - 1) / activity_block_size),
          activity_blocks(static_cast<std::size_t>(activity_blocks_per_axis) *
                          static_cast<std::size_t>(activity_blocks_per_axis)) {}

    // Four-byte hot cell: byte material ID, two material-specific state
    // registers, and one update epoch. Temperature remains an optional
    // structure-of-arrays field rather than consuming every resident cell.
    std::vector<Cell> cells;
    std::unique_ptr<std::vector<std::int16_t>> temperatures;
    std::int32_t activity_blocks_per_axis = 0;
    std::vector<ActivityBlock> activity_blocks;
    std::size_t non_empty_cell_count = 0;
    bool active = false;
    bool changed_this_tick = false;
    std::uint32_t quiet_ticks = 0;
    bool dirty = false;
    std::int32_t dirty_min_x = 0;
    std::int32_t dirty_min_y = 0;
    std::int32_t dirty_max_x = 0;
    std::int32_t dirty_max_y = 0;
};

struct World::Address {
    ChunkCoord chunk;
    std::int32_t local_x = 0;
    std::int32_t local_y = 0;
    std::size_t index = 0;
};

struct World::JobEffects {
    struct ChunkEffect {
        ChunkCoord chunk;
        std::int32_t minimum_x = 0;
        std::int32_t minimum_y = 0;
        std::int32_t maximum_x = 0;
        std::int32_t maximum_y = 0;
        std::int64_t non_empty_delta = 0;
    };

    static constexpr std::size_t kMaximumTouchedChunks = 16;
    std::array<ChunkEffect, kMaximumTouchedChunks> chunks{};
    std::size_t chunk_count = 0;
    bool overflow = false;
    bool hard_surface_changed = false;
    PhysicsJobHistogram* physics = nullptr;

    void reset() noexcept {
        chunk_count = 0;
        overflow = false;
        hard_surface_changed = false;
        if (physics != nullptr) *physics = {};
    }

    void record(const Address& address_value, std::int64_t non_empty_delta = 0) noexcept {
        for (std::size_t index = 0; index < chunk_count; ++index) {
            auto& effect = chunks[index];
            if (effect.chunk != address_value.chunk) continue;
            effect.minimum_x = std::min(effect.minimum_x, address_value.local_x);
            effect.minimum_y = std::min(effect.minimum_y, address_value.local_y);
            effect.maximum_x = std::max(effect.maximum_x, address_value.local_x);
            effect.maximum_y = std::max(effect.maximum_y, address_value.local_y);
            effect.non_empty_delta += non_empty_delta;
            return;
        }
        if (chunk_count == chunks.size()) {
            overflow = true;
            return;
        }
        chunks[chunk_count++] = {
            address_value.chunk,
            address_value.local_x,
            address_value.local_y,
            address_value.local_x,
            address_value.local_y,
            non_empty_delta,
        };
    }
};

struct World::ParallelState {
    struct JobResult {
        TickStats stats;
        JobEffects effects;
    };

    ParallelState(std::uint32_t worker_count, std::size_t capacity, bool diagnostics)
        : results(capacity) {
        if (diagnostics) {
            physics.resize(capacity);
            for (std::size_t i = 0; i < capacity; ++i) results[i].effects.physics = &physics[i];
        }
        phase_job_indices.reserve(capacity);
        if (worker_count > 1) pool = std::make_unique<PersistentWorkerPool>(worker_count);
    }

    std::unique_ptr<PersistentWorkerPool> pool;
    std::vector<JobResult> results;
    std::vector<PhysicsJobHistogram> physics;
    std::vector<std::size_t> phase_job_indices;
};

struct World::TransientObstacleState {
    RectI64 region{};
    std::vector<std::uint16_t> body_ids;
    std::vector<std::size_t> occupied_indices;
    std::array<std::atomic<std::uint64_t>, kMaximumTransientBodies + 1U> contacts{};
    std::array<std::atomic<std::int64_t>, kMaximumTransientBodies + 1U> impulse_x{};
    std::array<std::atomic<std::int64_t>, kMaximumTransientBodies + 1U> impulse_y{};

    void reset_contacts() noexcept {
        for (std::size_t index = 0; index < contacts.size(); ++index) {
            contacts[index].store(0, std::memory_order_relaxed);
            impulse_x[index].store(0, std::memory_order_relaxed);
            impulse_y[index].store(0, std::memory_order_relaxed);
        }
    }
};

World::World(WorldConfig config)
    : config_(config),
      scheduler_geometry_(config.scheduling_core_size, config.maximum_rule_radius) {
    if (config.physics_diagnostics.mercury_viscosity < -1 ||
        config.physics_diagnostics.mercury_viscosity > 255) {
        throw std::invalid_argument("diagnostic Mercury viscosity must be -1 or 0..255");
    }
    if (config.physics_diagnostics.enabled) physics_totals_ = std::make_unique<PhysicsTotals>();
    if (config_.chunk_size < 8 || config_.chunk_size > 1'024) {
        throw std::invalid_argument("chunk_size must be between 8 and 1024");
    }
    if (config_.sleep_after_quiet_ticks == 0) {
        throw std::invalid_argument("sleep_after_quiet_ticks must be greater than zero");
    }
    if (config_.initial_chunk_reserve == 0) {
        throw std::invalid_argument("initial_chunk_reserve must be greater than zero");
    }
    if (config_.activity_block_size <= 0 || config_.activity_block_size > 1'024) {
        throw std::invalid_argument("activity_block_size must be between one and 1024");
    }
    if (config_.worker_threads == 0) {
        throw std::invalid_argument("worker_threads must be greater than zero");
    }
    if (config_.worker_threads > 256) {
        throw std::invalid_argument("worker_threads must not exceed 256");
    }
    if (config_.active_core_capacity == 0) {
        throw std::invalid_argument("active_core_capacity must be greater than zero");
    }
    if (config_.active_chunk_capacity == 0) {
        throw std::invalid_argument("active_chunk_capacity must be greater than zero");
    }
    if (config_.maximum_chunk_count == 0) {
        throw std::invalid_argument("maximum_chunk_count must be greater than zero");
    }
    if (config_.deferred_event_capacity == 0) {
        throw std::invalid_argument("deferred_event_capacity must be greater than zero");
    }
    if (config_.maximum_explosion_radius <= 0 || config_.maximum_explosion_radius > 256) {
        throw std::invalid_argument("maximum_explosion_radius must be between one and 256");
    }
    if (config_.initial_chunk_reserve > config_.maximum_chunk_count) {
        throw std::invalid_argument("initial_chunk_reserve must not exceed maximum_chunk_count");
    }
    if (config_.parallel_job_threshold == 0) {
        throw std::invalid_argument("parallel_job_threshold must be greater than zero");
    }
    for (const auto& definition : MaterialRules::descriptors()) {
        if (definition.current_rule_available &&
            definition.maximum_write_radius >
                static_cast<std::uint8_t>(config_.maximum_rule_radius)) {
            throw std::invalid_argument("maximum_rule_radius is smaller than an active material rule");
        }
    }
    // The default bucket table stays cache-friendly. reserve_region() expands
    // it to the exact planned interest region before inserting chunk payloads.
    chunks_.reserve(config_.initial_chunk_reserve);
    active_chunk_scratch_.reserve(config_.active_chunk_capacity);
    active_core_scratch_.reserve(config_.active_core_capacity);
    pending_explosions_.reserve(config_.deferred_event_capacity);
    if (config_.worker_threads > 1) {
        if (config_.backend != SimulationBackend::PhasedInPlace) {
            throw std::invalid_argument("multiple workers currently require the phased backend");
        }
        if (config_.chunk_size < config_.scheduling_core_size ||
            config_.chunk_size % config_.scheduling_core_size != 0 ||
            config_.chunk_size % config_.activity_block_size != 0 ||
            config_.scheduling_core_size % config_.activity_block_size != 0) {
            throw std::invalid_argument(
                "parallel phased geometry requires aligned chunk, core, and activity sizes");
        }
    }
    if (config_.backend == SimulationBackend::PhasedInPlace) {
        parallel_ = std::make_unique<ParallelState>(config_.worker_threads,
                                                    config_.active_core_capacity,
                                                    config_.physics_diagnostics.enabled);
    }
    transient_obstacles_ = std::make_unique<TransientObstacleState>();
}

World::~World() = default;
World::World(World&&) noexcept = default;
World& World::operator=(World&&) noexcept = default;

const PhysicsTotals* World::physics_diagnostics() const noexcept { return physics_totals_.get(); }

void World::record_physics(PhysicsEvent kind, Material source, Material target,
    std::int64_t dx, std::int64_t dy, JobEffects* effects, std::uint64_t count) noexcept {
    if (physics_totals_ == nullptr) return;
    const auto key = physics_event_key(kind, static_cast<std::uint8_t>(source),
                                     static_cast<std::uint8_t>(target), dx, dy);
    if (effects != nullptr) effects->physics->add(key, count);
    else physics_totals_->add(key, count);
}

RenderPublishResult RenderSnapshotExchange::publish(World& world) {
    world.require_healthy();
    auto& state = *state_;
    std::scoped_lock lock(state.mutex);

    std::size_t required_patches = 0;
    std::size_t required_bytes = 0;
    bool byte_count_overflow = false;
    for (const auto& [coord, chunk] : world.chunks_) {
        (void)coord;
        if (!chunk->dirty) continue;
        ++required_patches;
        const auto width = static_cast<std::size_t>(chunk->dirty_max_x -
                                                    chunk->dirty_min_x + 1);
        const auto height = static_cast<std::size_t>(chunk->dirty_max_y -
                                                     chunk->dirty_min_y + 1);
        if (width > std::numeric_limits<std::size_t>::max() / 2U) {
            byte_count_overflow = true;
            continue;
        }
        const auto stride = width * 2U;
        if (height > std::numeric_limits<std::size_t>::max() / stride) {
            byte_count_overflow = true;
            continue;
        }
        const auto patch_bytes = height * stride;
        if (required_bytes > std::numeric_limits<std::size_t>::max() - patch_bytes) {
            byte_count_overflow = true;
            continue;
        }
        required_bytes += patch_bytes;
    }

    if (required_patches == 0) {
        return {RenderPublishStatus::NoChanges, state.next_serial, 0, 0};
    }
    if (byte_count_overflow ||
        required_patches > state.patch_capacity_per_slot ||
        required_bytes > state.byte_capacity_per_slot) {
        ++state.capacity_failure_count;
        return {RenderPublishStatus::CapacityExceeded, state.next_serial, required_patches,
                byte_count_overflow ? std::numeric_limits<std::size_t>::max()
                                    : required_bytes};
    }

    std::optional<std::size_t> selected_slot;
    for (std::size_t index = 0; index < state.slots.size(); ++index) {
        const auto& candidate = state.slots[index];
        if (candidate.lease_count != 0) continue;
        if (!selected_slot.has_value() ||
            candidate.serial < state.slots[*selected_slot].serial) {
            selected_slot = index;
        }
    }
    if (!selected_slot.has_value()) {
        ++state.backpressure_count;
        return {RenderPublishStatus::Backpressure, state.next_serial, required_patches,
                required_bytes};
    }

    state.dirty_coordinate_scratch.clear();
    for (const auto& [coord, chunk] : world.chunks_) {
        if (chunk->dirty) state.dirty_coordinate_scratch.push_back(coord);
    }
    std::sort(state.dirty_coordinate_scratch.begin(),
              state.dirty_coordinate_scratch.end());

    auto& slot = state.slots[*selected_slot];
    std::size_t byte_offset = 0;
    for (std::size_t patch_index = 0;
         patch_index < state.dirty_coordinate_scratch.size(); ++patch_index) {
        const auto coord = state.dirty_coordinate_scratch[patch_index];
        auto* chunk = world.find_chunk(coord);
        if (chunk == nullptr || !chunk->dirty) {
            throw std::logic_error("dirty snapshot source changed during publication");
        }
        const auto width = static_cast<std::size_t>(chunk->dirty_max_x -
                                                    chunk->dirty_min_x + 1);
        const auto height = static_cast<std::size_t>(chunk->dirty_max_y -
                                                     chunk->dirty_min_y + 1);
        const auto stride = width * 2U;
        slot.patches[patch_index] = RenderSnapshotPatch{
            {coord.x * world.config_.chunk_size + chunk->dirty_min_x,
             coord.y * world.config_.chunk_size + chunk->dirty_min_y,
             static_cast<std::int64_t>(width),
             static_cast<std::int64_t>(height)},
            byte_offset,
            stride,
        };

        for (std::size_t row = 0; row < height; ++row) {
            const auto source_y = static_cast<std::size_t>(chunk->dirty_min_y) + row;
            auto* output = slot.cells.data() + byte_offset + row * stride;
            for (std::size_t column = 0; column < width; ++column) {
                const auto source_x = static_cast<std::size_t>(chunk->dirty_min_x) + column;
                const auto& cell = chunk->cells[
                    source_y * static_cast<std::size_t>(world.config_.chunk_size) + source_x];
                output[column * 2U] = static_cast<std::uint8_t>(cell.material);
                output[column * 2U + 1U] =
                    project_visual_state(cell.material, cell.state_a, cell.state_b);
            }
        }
        byte_offset += height * stride;
    }

    // Dirty state is acknowledged only after every byte has been captured.
    for (const auto coord : state.dirty_coordinate_scratch) {
        auto* chunk = world.find_chunk(coord);
        if (chunk != nullptr) chunk->dirty = false;
    }

    slot.patch_count = required_patches;
    slot.byte_count = required_bytes;
    slot.tick = world.tick_index_;
    slot.serial = ++state.next_serial;
    state.latest_slot = selected_slot;
    state.patch_high_water = std::max(state.patch_high_water, required_patches);
    state.byte_high_water = std::max(state.byte_high_water, required_bytes);
    return {RenderPublishStatus::Published, slot.serial, required_patches, required_bytes};
}

std::size_t ChunkCoordHash::operator()(const ChunkCoord& coord) const noexcept {
    const auto x = mix64(static_cast<std::uint64_t>(coord.x));
    const auto y = mix64(static_cast<std::uint64_t>(coord.y));
    return static_cast<std::size_t>(x ^ std::rotl(y, 29));
}

const WorldConfig& World::config() const noexcept { return config_; }
SimulationBackend World::backend() const noexcept { return config_.backend; }

World::Address World::address(std::int64_t x, std::int64_t y) const noexcept {
    const auto chunk_x = floor_div(x, config_.chunk_size);
    const auto chunk_y = floor_div(y, config_.chunk_size);
    const auto local_x = positive_mod(x, config_.chunk_size);
    const auto local_y = positive_mod(y, config_.chunk_size);
    return {
        {chunk_x, chunk_y},
        local_x,
        local_y,
        static_cast<std::size_t>(local_y) * static_cast<std::size_t>(config_.chunk_size) +
            static_cast<std::size_t>(local_x),
    };
}

World::Chunk* World::find_chunk(ChunkCoord coord) noexcept {
    const auto found = chunks_.find(coord);
    return found == chunks_.end() ? nullptr : found->second.get();
}

const World::Chunk* World::find_chunk(ChunkCoord coord) const noexcept {
    const auto found = chunks_.find(coord);
    return found == chunks_.end() ? nullptr : found->second.get();
}

World::Chunk& World::ensure_chunk(ChunkCoord coord) {
    if (auto* existing = find_chunk(coord); existing != nullptr) return *existing;
    if (chunks_.size() >= config_.maximum_chunk_count) {
        throw std::runtime_error("maximum chunk capacity exhausted");
    }
    auto chunk = std::make_unique<Chunk>(config_.chunk_size, config_.activity_block_size);
    const auto [iterator, inserted] = chunks_.try_emplace(coord, std::move(chunk));
    (void)inserted;
    if (tick_in_progress_) ++tick_chunk_allocations_;
    return *iterator->second;
}

void World::ensure_temperature_field(Chunk& chunk) {
    if (chunk.temperatures != nullptr) return;
    chunk.temperatures = std::make_unique<std::vector<std::int16_t>>(
        chunk.cells.size(), config_.ambient_temperature);
    if (tick_in_progress_) ++tick_temperature_field_allocations_;
}

Material World::get(std::int64_t x, std::int64_t y) const noexcept {
    if (transient_obstacle_at(x, y) != 0U) return Material::Wall;
    return stored_material(x, y);
}

Material World::stored_material(std::int64_t x, std::int64_t y) const noexcept {
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr ? Material::Empty : chunk->cells[target.index].material;
}

std::uint8_t World::stored_state_a(std::int64_t x, std::int64_t y) const noexcept {
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr ? 0 : chunk->cells[target.index].state_a;
}

std::uint8_t World::stored_state_b(std::int64_t x, std::int64_t y) const noexcept {
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr ? 0 : chunk->cells[target.index].state_b;
}

std::uint8_t World::liquid_mass(std::int64_t x, std::int64_t y) const noexcept {
    if (transient_obstacle_at(x, y) != 0U) return 0;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) return 0;
    const auto& cell = chunk->cells[target.index];
    return cell.material == Material::Water ? cell.state_a : 0;
}

std::int16_t World::temperature(std::int64_t x, std::int64_t y) const noexcept {
    if (transient_obstacle_at(x, y) != 0U) return config_.ambient_temperature;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr || chunk->temperatures == nullptr
               ? config_.ambient_temperature
               : (*chunk->temperatures)[target.index];
}

std::uint8_t World::state_a(std::int64_t x, std::int64_t y) const noexcept {
    if (transient_obstacle_at(x, y) != 0U) return 0;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr ? 0 : chunk->cells[target.index].state_a;
}

std::uint8_t World::state_b(std::int64_t x, std::int64_t y) const noexcept {
    if (transient_obstacle_at(x, y) != 0U) return 0;
    const auto target = address(x, y);
    const auto* chunk = find_chunk(target.chunk);
    return chunk == nullptr ? 0 : chunk->cells[target.index].state_b;
}

std::uint8_t World::deterministic_random(std::int64_t x, std::int64_t y,
                                         std::uint32_t stream) const noexcept {
    return static_cast<std::uint8_t>(
        mix64(static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
              std::rotl(static_cast<std::uint64_t>(y), 23) ^
              tick_index_ * 0xd6e8feb86659fd93ULL ^
              static_cast<std::uint64_t>(stream) * 0xa0761d6478bd642fULL) &
        0xffU);
}

bool World::rule_is_active(Material material, std::uint8_t state_a_value,
                           std::uint8_t state_b_value) const noexcept {
    const auto& definition = MaterialRules::descriptor(material);
    if (!definition.current_rule_available) return false;
    const auto kernel = definition.kernel;
    switch (kernel) {
        case RuleKernel::None:
            return false;
        case RuleKernel::Combustible:
            return state_b_value != 0;
        case RuleKernel::Metal:
            return state_b_value != 0;
        case RuleKernel::Plant:
        case RuleKernel::Fungus:
            return state_a_value != 0 || state_b_value != 0;
        case RuleKernel::Sand:
        case RuleKernel::Water:
        case RuleKernel::Gas:
        case RuleKernel::Cloner:
        case RuleKernel::Fire:
        case RuleKernel::Lava:
        case RuleKernel::Ice:
        case RuleKernel::Acid:
        case RuleKernel::Stone:
        case RuleKernel::Dust:
        case RuleKernel::Mite:
        case RuleKernel::Oil:
        case RuleKernel::Rocket:
        case RuleKernel::Seed:
        case RuleKernel::YieldingLiquid:
        case RuleKernel::Steam:
        case RuleKernel::Gunpowder:
        case RuleKernel::Coal:
        case RuleKernel::Cement:
        case RuleKernel::Spark:
        case RuleKernel::MoltenGlass:
        case RuleKernel::Foam:
            return true;
    }
    return false;
}

bool World::write_cell(std::int64_t x, std::int64_t y, Material material,
                       std::uint8_t state_a_value, std::uint8_t state_b_value,
                       JobEffects* effects) {
    if (material != Material::Empty && transient_obstacle_at(x, y) != 0U) return false;
    const auto target = address(x, y);
    auto* chunk = find_chunk(target.chunk);
    if (chunk == nullptr) {
        if (effects != nullptr) {
            effects->overflow = true;
            return false;
        }
        chunk = &ensure_chunk(target.chunk);
    }
    auto& cell = chunk->cells[target.index];
    if (cell.material == material && cell.state_a == state_a_value &&
        cell.state_b == state_b_value) {
        return false;
    }
    const auto before = cell.material;
    if (tick_in_progress_ && before != material)
        record_physics(PhysicsEvent::Conversion, before, material, 0, 0, effects);
    const bool hard_surface_changed =
        MaterialRules::is_hard_surface(before) != MaterialRules::is_hard_surface(material);
    const auto delta = before == Material::Empty && material != Material::Empty
                           ? std::int64_t{1}
                       : before != Material::Empty && material == Material::Empty
                           ? std::int64_t{-1}
                           : std::int64_t{0};
    cell = Chunk::Cell::for_material(material);
    cell.state_a = state_a_value;
    cell.state_b = state_b_value;
    cell.updated_epoch = update_epoch_;

    if (effects != nullptr) {
        effects->record(target, delta);
        effects->hard_surface_changed =
            effects->hard_surface_changed || hard_surface_changed;
    } else {
        chunk->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(chunk->non_empty_cell_count) + delta);
        chunk->changed_this_tick = true;
        mark_cell_dirty(*chunk, target.local_x, target.local_y);
        wake_cell_neighborhood(x, y);
        if (hard_surface_changed) ++hard_surface_revision_;
    }
    return true;
}

void World::mark_cell_dirty(Chunk& chunk, std::int32_t local_x, std::int32_t local_y) {
    const auto block_x = local_x / config_.activity_block_size;
    const auto block_y = local_y / config_.activity_block_size;
    const auto block_index =
        static_cast<std::size_t>(block_y) *
            static_cast<std::size_t>(chunk.activity_blocks_per_axis) +
        static_cast<std::size_t>(block_x);
    auto& block = chunk.activity_blocks[block_index];
    block.active = true;
    block.changed_this_tick = true;
    block.quiet_ticks = 0;
    chunk.active = true;

    if (!chunk.dirty) {
        chunk.dirty = true;
        chunk.dirty_min_x = local_x;
        chunk.dirty_max_x = local_x;
        chunk.dirty_min_y = local_y;
        chunk.dirty_max_y = local_y;
        return;
    }
    chunk.dirty_min_x = std::min(chunk.dirty_min_x, local_x);
    chunk.dirty_max_x = std::max(chunk.dirty_max_x, local_x);
    chunk.dirty_min_y = std::min(chunk.dirty_min_y, local_y);
    chunk.dirty_max_y = std::max(chunk.dirty_max_y, local_y);
}

void World::wake_cell_neighborhood(std::int64_t x, std::int64_t y) {
    const auto centre = address(x, y);
    const auto block_x = centre.local_x / config_.activity_block_size;
    const auto block_y = centre.local_y / config_.activity_block_size;
    const auto block_right =
        std::min((block_x + 1) * config_.activity_block_size, config_.chunk_size) - 1;
    const auto block_bottom =
        std::min((block_y + 1) * config_.activity_block_size, config_.chunk_size) - 1;

    std::array<std::int64_t, 3> x_offsets{0, 0, 0};
    std::array<std::int64_t, 3> y_offsets{0, 0, 0};
    std::size_t x_count = 1;
    std::size_t y_count = 1;
    if (centre.local_x == block_x * config_.activity_block_size) x_offsets[x_count++] = -1;
    if (centre.local_x == block_right) x_offsets[x_count++] = 1;
    if (centre.local_y == block_y * config_.activity_block_size) y_offsets[y_count++] = -1;
    if (centre.local_y == block_bottom) y_offsets[y_count++] = 1;

    for (std::size_t y_index = 0; y_index < y_count; ++y_index) {
        for (std::size_t x_index = 0; x_index < x_count; ++x_index) {
            const auto offset_x = x_offsets[x_index];
            const auto offset_y = y_offsets[y_index];
            if (offset_x == 0 && offset_y == 0) continue;
            const auto target = address(x + offset_x, y + offset_y);
            auto* chunk = find_chunk(target.chunk);
            if (chunk == nullptr || chunk->non_empty_cell_count == 0) continue;
            const auto neighbour_block_x = target.local_x / config_.activity_block_size;
            const auto neighbour_block_y = target.local_y / config_.activity_block_size;
            const auto block_index =
                static_cast<std::size_t>(neighbour_block_y) *
                    static_cast<std::size_t>(chunk->activity_blocks_per_axis) +
                static_cast<std::size_t>(neighbour_block_x);
            auto& block = chunk->activity_blocks[block_index];
            block.active = true;
            block.quiet_ticks = 0;
            chunk->active = true;
        }
    }
}

void World::keep_cell_active(std::int64_t x, std::int64_t y) noexcept {
    const auto source = address(x, y);
    auto* chunk = find_chunk(source.chunk);
    if (chunk == nullptr) return;
    const auto block_x = source.local_x / config_.activity_block_size;
    const auto block_y = source.local_y / config_.activity_block_size;
    const auto block_index =
        static_cast<std::size_t>(block_y) *
            static_cast<std::size_t>(chunk->activity_blocks_per_axis) +
        static_cast<std::size_t>(block_x);
    auto& block = chunk->activity_blocks[block_index];
    // Temporal fidelity lanes may intentionally perform no authoritative write
    // for several ticks. Keep their source block scheduled without creating a
    // dirty render patch or pretending the cell changed.
    block.active = true;
    block.changed_this_tick = true;
    block.quiet_ticks = 0;
    chunk->active = true;
}

void World::set(std::int64_t x, std::int64_t y, Material material) {
    require_healthy();
    if (!valid_material(static_cast<std::uint16_t>(material))) {
        throw std::invalid_argument("invalid material identifier");
    }
    if (material != Material::Empty && transient_obstacle_at(x, y) != 0U) return;
    const auto target = address(x, y);
    if (material == Material::Empty && find_chunk(target.chunk) == nullptr) {
        return;
    }
    auto& chunk = ensure_chunk(target.chunk);
    if (chunk.cells[target.index].material == material) {
        return;
    }
    const auto previous_material = chunk.cells[target.index].material;
    const bool hard_surface_changed =
        MaterialRules::is_hard_surface(previous_material) !=
        MaterialRules::is_hard_surface(material);
    if (previous_material == Material::Empty && material != Material::Empty) {
        ++chunk.non_empty_cell_count;
    } else if (previous_material != Material::Empty && material == Material::Empty) {
        --chunk.non_empty_cell_count;
    }
    chunk.cells[target.index] = Chunk::Cell::for_material(material);
    chunk.cells[target.index].updated_epoch = update_epoch_;
    chunk.changed_this_tick = true;
    mark_cell_dirty(chunk, target.local_x, target.local_y);
    wake_cell_neighborhood(x, y);
    if (hard_surface_changed) ++hard_surface_revision_;
}

bool World::set_cell_state(std::int64_t x, std::int64_t y, Material material,
                           std::uint8_t state_a_value,
                           std::uint8_t state_b_value) {
    if (tick_failed_) return false;
    if (!valid_material(static_cast<std::uint16_t>(material))) {
        throw std::invalid_argument("invalid material identifier");
    }
    if (material != Material::Empty && transient_obstacle_at(x, y) != 0U) return false;
    return write_cell(x, y, material, state_a_value, state_b_value, nullptr);
}

void World::set_simulation_region(std::optional<RectI64> region) {
    if (region.has_value() && (region->width <= 0 || region->height <= 0)) {
        throw std::invalid_argument("simulation region dimensions must be positive");
    }
    std::optional<CoreRange> selected;
    if (region) {
        if (region->x > std::numeric_limits<std::int64_t>::max() - (region->width - 1) ||
            region->y > std::numeric_limits<std::int64_t>::max() - (region->height - 1)) {
            throw std::overflow_error("simulation region endpoint overflow");
        }
        const auto first = scheduler_geometry_.core_for_cell(region->x, region->y);
        const auto last = scheduler_geometry_.core_for_cell(
            region->x + region->width - 1, region->y + region->height - 1);
        selected = CoreRange{first.x, first.y, last.x, last.y};
    }
    simulation_region_ = region;
    selected_core_region_ = selected;
}

void World::set_liquid_surface_adhesion_enabled(bool enabled) noexcept {
    liquid_surface_adhesion_enabled_ = enabled;
}

std::optional<RectI64> World::simulation_region() const noexcept { return simulation_region_; }

bool World::liquid_surface_adhesion_enabled() const noexcept {
    return liquid_surface_adhesion_enabled_;
}

void World::configure_transient_obstacles(RectI64 region) {
    require_healthy();
    if (region.width <= 0 || region.height <= 0) {
        throw std::invalid_argument("transient obstacle dimensions must be positive");
    }
    const auto width = static_cast<std::uint64_t>(region.width);
    const auto height = static_cast<std::uint64_t>(region.height);
    if (width > std::numeric_limits<std::size_t>::max() / height) {
        throw std::overflow_error("transient obstacle field exceeds addressable size");
    }
    clear_transient_obstacles();
    transient_obstacles_->region = region;
    const auto required = static_cast<std::size_t>(width * height);
    if (transient_obstacles_->body_ids.size() != required) {
        transient_obstacles_->body_ids.assign(required, 0U);
    }
    transient_obstacles_->occupied_indices.reserve(
        std::min<std::size_t>(required, 16U * 256U));
}

void World::clear_transient_obstacles() {
    require_healthy();
    auto& state = *transient_obstacles_;
    const auto width = state.region.width;
    if (width > 0) {
        for (const auto index : state.occupied_indices) {
            if (index >= state.body_ids.size()) continue;
            state.body_ids[index] = 0U;
            const auto local_x = static_cast<std::int64_t>(index % static_cast<std::size_t>(width));
            const auto local_y = static_cast<std::int64_t>(index / static_cast<std::size_t>(width));
            wake_cell_neighborhood(state.region.x + local_x, state.region.y + local_y);
        }
    }
    state.occupied_indices.clear();
    state.reset_contacts();
}

std::uint16_t World::transient_obstacle_at(std::int64_t x, std::int64_t y) const noexcept {
    const auto& state = *transient_obstacles_;
    if (state.region.width <= 0 || state.region.height <= 0 ||
        x < state.region.x || y < state.region.y) {
        return 0U;
    }
    const auto local_x = x - state.region.x;
    const auto local_y = y - state.region.y;
    if (local_x >= state.region.width || local_y >= state.region.height) return 0U;
    const auto index = static_cast<std::size_t>(local_y) *
                           static_cast<std::size_t>(state.region.width) +
                       static_cast<std::size_t>(local_x);
    return index < state.body_ids.size() ? state.body_ids[index] : 0U;
}

bool World::set_transient_obstacle(std::int64_t x, std::int64_t y,
                                   std::uint16_t body_id) {
    if (tick_failed_) return false;
    auto& state = *transient_obstacles_;
    if (body_id == 0U || body_id > kMaximumTransientBodies ||
        state.region.width <= 0 || state.region.height <= 0 ||
        x < state.region.x || y < state.region.y) {
        return false;
    }
    const auto local_x = x - state.region.x;
    const auto local_y = y - state.region.y;
    if (local_x >= state.region.width || local_y >= state.region.height) return false;
    const auto index = static_cast<std::size_t>(local_y) *
                           static_cast<std::size_t>(state.region.width) +
                       static_cast<std::size_t>(local_x);
    auto& slot = state.body_ids[index];
    if (slot != 0U) return false;
    slot = body_id;
    state.occupied_indices.push_back(index);
    wake_cell_neighborhood(x, y);
    return true;
}

bool World::relocate_stored_cell(std::int64_t from_x, std::int64_t from_y,
                                 std::int64_t to_x, std::int64_t to_y) {
    if (tick_failed_) return false;
    if (stored_material(from_x, from_y) == Material::Empty ||
        stored_material(to_x, to_y) != Material::Empty ||
        transient_obstacle_at(to_x, to_y) != 0U) {
        return false;
    }
    move_cell(from_x, from_y, to_x, to_y, false, nullptr);
    return true;
}

std::uint64_t World::transient_contact_count(std::uint16_t body_id) const noexcept {
    if (body_id > kMaximumTransientBodies) return 0U;
    return transient_obstacles_->contacts[body_id].load(std::memory_order_relaxed);
}

std::int64_t World::transient_contact_impulse_x(std::uint16_t body_id) const noexcept {
    if (body_id > kMaximumTransientBodies) return 0;
    return transient_obstacles_->impulse_x[body_id].load(std::memory_order_relaxed);
}

std::int64_t World::transient_contact_impulse_y(std::uint16_t body_id) const noexcept {
    if (body_id > kMaximumTransientBodies) return 0;
    return transient_obstacles_->impulse_y[body_id].load(std::memory_order_relaxed);
}

void World::record_transient_contact(std::uint16_t body_id, Material material,
                                     std::int64_t delta_x,
                                     std::int64_t delta_y) noexcept {
    if (body_id == 0U || body_id > kMaximumTransientBodies) return;
    const auto density = std::clamp<std::int64_t>(
        static_cast<std::int64_t>(MaterialRules::descriptor(material).density), 50, 1'600);
    const auto direction_x = delta_x == 0 ? 0 : (delta_x > 0 ? 1 : -1);
    const auto direction_y = delta_y == 0 ? 0 : (delta_y > 0 ? 1 : -1);
    transient_obstacles_->contacts[body_id].fetch_add(1U, std::memory_order_relaxed);
    transient_obstacles_->impulse_x[body_id].fetch_add(direction_x * density,
                                                        std::memory_order_relaxed);
    transient_obstacles_->impulse_y[body_id].fetch_add(direction_y * density,
                                                        std::memory_order_relaxed);
}

void World::set_temperature(std::int64_t x, std::int64_t y, std::int16_t value) {
    require_healthy();
    const auto target = address(x, y);
    if (value == config_.ambient_temperature) {
        auto* existing = find_chunk(target.chunk);
        if (existing == nullptr || existing->temperatures == nullptr ||
            (*existing->temperatures)[target.index] == value) {
            return;
        }
    }
    auto& chunk = ensure_chunk(target.chunk);
    ensure_temperature_field(chunk);
    if ((*chunk.temperatures)[target.index] == value) {
        return;
    }
    (*chunk.temperatures)[target.index] = value;
    chunk.changed_this_tick = true;
    mark_cell_dirty(chunk, target.local_x, target.local_y);
    wake_cell_neighborhood(x, y);
}

void World::paint_disc(std::int64_t centre_x, std::int64_t centre_y, std::int32_t radius, Material material) {
    require_healthy();
    if (radius < 0) {
        throw std::invalid_argument("radius must not be negative");
    }
    const auto radius_squared = static_cast<std::int64_t>(radius) * radius;
    for (std::int32_t offset_y = -radius; offset_y <= radius; ++offset_y) {
        for (std::int32_t offset_x = -radius; offset_x <= radius; ++offset_x) {
            const auto distance_squared = static_cast<std::int64_t>(offset_x) * offset_x +
                                          static_cast<std::int64_t>(offset_y) * offset_y;
            if (distance_squared <= radius_squared) {
                set(centre_x + offset_x, centre_y + offset_y, material);
            }
        }
    }
}

void World::reserve_region(RectI64 region) {
    require_healthy();
    if (region.width <= 0 || region.height <= 0) {
        throw std::invalid_argument("reserve region dimensions must be positive");
    }
    const auto maximum = std::numeric_limits<std::int64_t>::max();
    if (region.x > maximum - (region.width - 1) ||
        region.y > maximum - (region.height - 1)) {
        throw std::overflow_error("reserve region exceeds coordinate range");
    }
    const auto minimum_address = address(region.x, region.y);
    const auto maximum_address =
        address(region.x + region.width - 1, region.y + region.height - 1);
    const auto chunks_wide = maximum_address.chunk.x - minimum_address.chunk.x + 1;
    const auto chunks_high = maximum_address.chunk.y - minimum_address.chunk.y + 1;
    if (chunks_wide <= 0 || chunks_high <= 0 ||
        static_cast<std::uint64_t>(chunks_wide) > config_.maximum_chunk_count ||
        static_cast<std::uint64_t>(chunks_high) >
            config_.maximum_chunk_count / static_cast<std::uint64_t>(chunks_wide)) {
        throw std::runtime_error("reserve region exceeds maximum chunk capacity");
    }

    std::size_t missing = 0;
    for (auto chunk_y = minimum_address.chunk.y; chunk_y <= maximum_address.chunk.y; ++chunk_y) {
        for (auto chunk_x = minimum_address.chunk.x; chunk_x <= maximum_address.chunk.x; ++chunk_x) {
            if (find_chunk({chunk_x, chunk_y}) == nullptr) ++missing;
        }
    }
    if (missing > config_.maximum_chunk_count - chunks_.size()) {
        throw std::runtime_error("reserve region exceeds remaining chunk capacity");
    }
    chunks_.reserve(chunks_.size() + missing);
    for (auto chunk_y = minimum_address.chunk.y; chunk_y <= maximum_address.chunk.y; ++chunk_y) {
        for (auto chunk_x = minimum_address.chunk.x; chunk_x <= maximum_address.chunk.x; ++chunk_x) {
            (void)ensure_chunk({chunk_x, chunk_y});
        }
    }
}

void World::reserve_temperature_region(RectI64 region) {
    require_healthy();
    reserve_region(region);
    const auto minimum_address = address(region.x, region.y);
    const auto maximum_address =
        address(region.x + region.width - 1, region.y + region.height - 1);
    for (auto chunk_y = minimum_address.chunk.y; chunk_y <= maximum_address.chunk.y; ++chunk_y) {
        for (auto chunk_x = minimum_address.chunk.x; chunk_x <= maximum_address.chunk.x; ++chunk_x) {
            ensure_temperature_field(ensure_chunk({chunk_x, chunk_y}));
        }
    }
}

bool World::queue_explosion(std::int64_t x, std::int64_t y, std::int32_t radius,
                            std::uint8_t collapse_strength) {
    if (tick_failed_) return false;
    if (radius <= 0 || radius > config_.maximum_explosion_radius ||
        pending_explosions_.size() >= config_.deferred_event_capacity) {
        return false;
    }
    const auto margin = static_cast<std::int64_t>(radius) + 2;
    if (x < std::numeric_limits<std::int64_t>::min() + margin ||
        x > std::numeric_limits<std::int64_t>::max() - margin ||
        y < std::numeric_limits<std::int64_t>::min() + margin ||
        y > std::numeric_limits<std::int64_t>::max() - margin) {
        return false;
    }
    pending_explosions_.push_back({x, y, radius, collapse_strength});
    return true;
}

void World::apply_pending_explosions(TickStats& stats) {
    for (std::size_t event_index = 0; event_index < pending_explosions_.size();
         ++event_index) {
        const auto event = pending_explosions_[event_index];
        const auto inner_radius = static_cast<std::int64_t>(event.radius);
        const auto outer_radius = inner_radius + 2;
        const auto inner_squared = inner_radius * inner_radius;
        const auto outer_squared = outer_radius * outer_radius;
        for (auto offset_y = -outer_radius; offset_y <= outer_radius; ++offset_y) {
            for (auto offset_x = -outer_radius; offset_x <= outer_radius; ++offset_x) {
                const auto distance_squared = offset_x * offset_x + offset_y * offset_y;
                if (distance_squared > outer_squared) continue;
                const auto target_x = event.x + offset_x;
                const auto target_y = event.y + offset_y;
                const auto target = get(target_x, target_y);
                if (distance_squared <= inner_squared) {
                    if (target != Material::Empty) set(target_x, target_y, Material::Empty);
                    continue;
                }
                if (target != Material::Wall || event.collapse_strength == 0U) continue;
                const auto stream = static_cast<std::uint32_t>(100U + event_index);
                if (deterministic_random(target_x, target_y, stream) <=
                    event.collapse_strength) {
                    // state_b=1 marks event-created Stone as granular. This is
                    // distinct from cooled/static Stone, which may remain
                    // braced by neighboring Stone.
                    (void)write_cell(target_x, target_y, Material::Stone, 0, 1, nullptr);
                }
            }
        }
        if (find_chunk(address(event.x, event.y).chunk) != nullptr) {
            set(event.x, event.y, Material::Fire);
        }
        ++stats.deferred_events;
    }
    pending_explosions_.clear();
}

void World::clear() {
    if (physics_totals_ != nullptr) *physics_totals_ = {};
    if (tick_in_progress_) throw std::logic_error("cannot clear during a world tick");
    tick_failed_ = false;
    clear_transient_obstacles();
    chunks_.clear();
    active_chunk_scratch_.clear();
    active_core_scratch_.clear();
    pending_explosions_.clear();
    tick_index_ = 0;
    completed_tick_index_ = 0;
    applied_core_region_.reset();
    update_epoch_ = 0;
    tick_in_progress_ = false;
    tick_chunk_allocations_ = 0;
    tick_temperature_field_allocations_ = 0;
    ++hard_surface_revision_;
}

std::int32_t World::deterministic_direction(std::int64_t x, std::int64_t y) const noexcept {
    const auto value = mix64(static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
                             std::rotl(static_cast<std::uint64_t>(y), 23) ^
                             tick_index_ * 0xd6e8feb86659fd93ULL);
    return (value & 1ULL) == 0 ? -1 : 1;
}

void World::move_cell(std::int64_t from_x, std::int64_t from_y, std::int64_t to_x, std::int64_t to_y,
                      bool swap, JobEffects* effects) {
    const auto source_address = address(from_x, from_y);
    const auto destination_address = address(to_x, to_y);
    auto* source_pointer = effects == nullptr ? &ensure_chunk(source_address.chunk)
                                             : find_chunk(source_address.chunk);
    auto* destination_pointer = effects == nullptr ? &ensure_chunk(destination_address.chunk)
                                                  : find_chunk(destination_address.chunk);
    if (source_pointer == nullptr || destination_pointer == nullptr) {
        throw std::logic_error("parallel write domain was not prepared");
    }
    auto& source = *source_pointer;
    auto& destination = *destination_pointer;

    const auto source_cell = source.cells[source_address.index];
    const auto destination_cell = destination.cells[destination_address.index];
    const auto source_material = source_cell.material;
    const auto destination_material = destination_cell.material;
    const auto source_temperature =
        source.temperatures == nullptr ? config_.ambient_temperature
                                       : (*source.temperatures)[source_address.index];
    const auto destination_temperature =
        destination.temperatures == nullptr ? config_.ambient_temperature
                                            : (*destination.temperatures)[destination_address.index];
    const auto source_replacement = swap ? destination_material : Material::Empty;
    const auto source_replacement_temperature =
        swap ? destination_temperature : config_.ambient_temperature;

    if (effects != nullptr &&
        ((source_temperature != config_.ambient_temperature && destination.temperatures == nullptr) ||
         (source_replacement_temperature != config_.ambient_temperature &&
          source.temperatures == nullptr))) {
        effects->overflow = true;
        return;
    }

    const auto non_empty_delta = [](Material before, Material after) -> std::int64_t {
        if (before == Material::Empty && after != Material::Empty) return 1;
        if (before != Material::Empty && after == Material::Empty) return -1;
        return 0;
    };
    const auto destination_delta = non_empty_delta(destination_material, source_material);
    const auto source_delta = non_empty_delta(source_material, source_replacement);
    const bool hard_surface_changed =
        MaterialRules::is_hard_surface(source_material) !=
            MaterialRules::is_hard_surface(source_replacement) ||
        MaterialRules::is_hard_surface(destination_material) !=
            MaterialRules::is_hard_surface(source_material);
    if (effects == nullptr) {
        destination.non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(destination.non_empty_cell_count) + destination_delta);
        source.non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(source.non_empty_cell_count) + source_delta);
    }

    destination.cells[destination_address.index] = source_cell;
    record_physics(!tick_in_progress_ ? PhysicsEvent::BodyDisplacement :
                   swap ? PhysicsEvent::DensitySwap : PhysicsEvent::EmptyMove,
                   source_material, destination_material, to_x - from_x, to_y - from_y, effects);
    destination.cells[destination_address.index].updated_epoch = update_epoch_;
    source.cells[source_address.index] =
        swap ? destination_cell : Chunk::Cell::for_material(Material::Empty);
    source.cells[source_address.index].updated_epoch = update_epoch_;

    const auto write_temperature = [this](Chunk& chunk, std::size_t index, std::int16_t value) {
        if (chunk.temperatures == nullptr && value != config_.ambient_temperature) {
            ensure_temperature_field(chunk);
        }
        if (chunk.temperatures != nullptr) (*chunk.temperatures)[index] = value;
    };
    write_temperature(destination, destination_address.index, source_temperature);
    write_temperature(source, source_address.index, source_replacement_temperature);

    if (effects != nullptr) {
        effects->record(source_address, source_delta);
        effects->record(destination_address, destination_delta);
        effects->hard_surface_changed =
            effects->hard_surface_changed || hard_surface_changed;
    } else {
        source.changed_this_tick = true;
        destination.changed_this_tick = true;
        mark_cell_dirty(source, source_address.local_x, source_address.local_y);
        mark_cell_dirty(destination, destination_address.local_x, destination_address.local_y);
        wake_cell_neighborhood(from_x, from_y);
        wake_cell_neighborhood(to_x, to_y);
        if (hard_surface_changed) ++hard_surface_revision_;
    }
}

bool World::try_move(Material material, std::int64_t x, std::int64_t y, std::int64_t target_x,
                     std::int64_t target_y, bool allow_swap, JobEffects* effects) {
    const auto obstacle = transient_obstacle_at(target_x, target_y);
    if (obstacle != 0U) {
        record_physics(PhysicsEvent::BodyContact, material, Material::Empty,
                       target_x - x, target_y - y, effects);
        record_transient_contact(obstacle, material, target_x - x, target_y - y);
        return false;
    }
    const auto target = get(target_x, target_y);
    if (target == Material::Empty) {
        if (effects != nullptr && find_chunk(address(target_x, target_y).chunk) == nullptr) {
            effects->overflow = true;
            return false;
        }
        move_cell(x, y, target_x, target_y, false, effects);
        return true;
    }
    if (allow_swap && !(config_.physics_diagnostics.disable_powder_exchange_targets &&
        MaterialRules::descriptor(target).state == MaterialState::Powder) &&
        MaterialRules::can_density_exchange(material, target, target_y - y)) {
        move_cell(x, y, target_x, target_y, true, effects);
        return true;
    }
    record_physics(PhysicsEvent::RejectedMove, material, target,
                   target_x - x, target_y - y, effects);
    return false;
}

std::uint16_t World::transfer_water(std::int64_t from_x, std::int64_t from_y,
                                    std::int64_t to_x, std::int64_t to_y,
                                    std::uint16_t requested, JobEffects* effects) {
    if (requested == 0 || (from_x == to_x && from_y == to_y)) return 0;
    const auto obstacle = transient_obstacle_at(to_x, to_y);
    if (obstacle != 0U) {
        record_transient_contact(obstacle, Material::Water, to_x - from_x, to_y - from_y);
        return 0;
    }
    const auto source_address = address(from_x, from_y);
    const auto destination_address = address(to_x, to_y);
    auto* source = find_chunk(source_address.chunk);
    if (source == nullptr || source->cells[source_address.index].material != Material::Water) return 0;

    auto* destination = find_chunk(destination_address.chunk);
    if (destination == nullptr) {
        if (effects != nullptr) {
            effects->overflow = true;
            return 0;
        }
        destination = &ensure_chunk(destination_address.chunk);
    }

    auto& source_cell = source->cells[source_address.index];
    auto& destination_cell = destination->cells[destination_address.index];
    if (destination_cell.material != Material::Empty &&
        destination_cell.material != Material::Water) {
        return 0;
    }

    const auto source_mass = static_cast<std::uint16_t>(source_cell.state_a);
    const auto source_coherence = source_cell.state_b;
    const auto destination_mass =
        destination_cell.material == Material::Water
            ? static_cast<std::uint16_t>(destination_cell.state_a)
            : std::uint16_t{0};
    const auto capacity = static_cast<std::uint16_t>(255U - destination_mass);
    const auto amount = std::min({requested, source_mass, capacity});
    if (amount == 0) return 0;

    const auto source_after = static_cast<std::uint16_t>(source_mass - amount);
    record_physics(PhysicsEvent::WaterTransfer, Material::Water, destination_cell.material,
                   to_x - from_x, to_y - from_y, effects, amount);
    const auto destination_after = static_cast<std::uint16_t>(destination_mass + amount);
    const bool source_becomes_empty = source_after == 0;
    const bool destination_was_empty = destination_cell.material == Material::Empty;

    if (destination_was_empty) destination_cell = Chunk::Cell::for_material(Material::Water);
    destination_cell.state_a = static_cast<std::uint8_t>(destination_after);
    destination_cell.state_b = std::max(destination_cell.state_b, source_coherence);
    destination_cell.updated_epoch = update_epoch_;
    if (source_becomes_empty) {
        source_cell = Chunk::Cell::for_material(Material::Empty);
    } else {
        source_cell.state_a = static_cast<std::uint8_t>(source_after);
    }
    source_cell.updated_epoch = update_epoch_;

    const auto source_delta = source_becomes_empty ? std::int64_t{-1} : std::int64_t{0};
    const auto destination_delta = destination_was_empty ? std::int64_t{1} : std::int64_t{0};
    if (effects != nullptr) {
        effects->record(source_address, source_delta);
        effects->record(destination_address, destination_delta);
    } else {
        source->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(source->non_empty_cell_count) + source_delta);
        destination->non_empty_cell_count = static_cast<std::size_t>(
            static_cast<std::int64_t>(destination->non_empty_cell_count) + destination_delta);
        source->changed_this_tick = true;
        destination->changed_this_tick = true;
        mark_cell_dirty(*source, source_address.local_x, source_address.local_y);
        mark_cell_dirty(*destination, destination_address.local_x, destination_address.local_y);
        wake_cell_neighborhood(from_x, from_y);
        wake_cell_neighborhood(to_x, to_y);
    }
    return amount;
}

bool World::update_water(std::int64_t x, std::int64_t y, JobEffects* effects) {
    bool changed = false;
    const auto direction = deterministic_direction(x, y);
    const auto coherence_delay = state_b(x, y);
    if (coherence_delay != 0U) {
        changed = write_cell(x, y, Material::Water, state_a(x, y),
                             static_cast<std::uint8_t>(coherence_delay - 1U), effects);
    }

    // Gravity first merges conserved mass into Water, moves the complete
    // fixed-point cell into Empty, or exchanges it with a lighter material
    // such as Smoke or Oil. The same directional descriptor rule also lets a
    // rising gas initiate the inverse exchange when it is scheduled first.
    const auto fall_or_exchange = [this, x, y, effects, &changed](
                                      std::int64_t target_x, std::int64_t target_y) {
        if (liquid_mass(x, y) == 0U) return false;
        if (get(target_x, target_y) == Material::Water) {
            const auto moved = transfer_water(x, y, target_x, target_y, 255, effects);
            changed = changed || moved != 0;
            return moved != 0;
        }
        const auto moved = try_move(Material::Water, x, y, target_x, target_y, true, effects);
        changed = changed || moved;
        return moved;
    };

    (void)fall_or_exchange(x, y + 1);
    if (liquid_mass(x, y) == 0) return changed;
    (void)fall_or_exchange(x + direction, y + 1);
    if (liquid_mass(x, y) == 0) return changed;
    (void)fall_or_exchange(x - direction, y + 1);
    if (liquid_mass(x, y) == 0) return changed;

    // Calm/coherent emission suppresses only source-time lateral spray. The
    // countdown travels with the conserved mass and expires quickly, so water
    // later falling from a ledge regains the emergent spray behaviour.
    if (coherence_delay != 0U) return changed;

    // Retain a small supported film when adhesion is enabled. Disabling the
    // toggle removes this threshold for active/dangerous liquids.
    const auto support = get(x, y + 1);
    if (liquid_surface_adhesion_enabled_ && liquid_mass(x, y) <= 48U &&
        support != Material::Empty && support != Material::Water) {
        return changed;
    }

    const auto level_with = [this, x, y, effects, &changed](
                                std::int64_t target_x, std::int64_t target_y) {
        const auto source_mass = static_cast<std::uint16_t>(liquid_mass(x, y));
        if (source_mass == 0) return;
        const auto target_material = get(target_x, target_y);
        if (target_material != Material::Empty && target_material != Material::Water) return;
        const auto target_mass = static_cast<std::uint16_t>(liquid_mass(target_x, target_y));
        if (source_mass <= target_mass + 1U) return;
        const auto requested = MaterialRules::apply_lateral_viscosity(
            Material::Water,
            static_cast<std::uint16_t>((source_mass - target_mass) / 2U));
        changed = transfer_water(x, y, target_x, target_y, requested, effects) != 0 || changed;
    };
    level_with(x + direction, y);
    level_with(x - direction, y);
    return changed;
}

bool World::update_rule_kernel(RuleKernel kernel, std::int64_t x, std::int64_t y,
                               JobEffects* effects) {
    const auto material = get(x, y);
    const auto direction = deterministic_direction(x, y);
    const auto neighbour = [this, x, y](std::size_t index) {
        const auto offset = kMooreNeighbours[index % kMooreNeighbours.size()];
        return std::pair{x + offset.x, y + offset.y};
    };
    const auto find_neighbour = [this, x, y](auto predicate)
        -> std::optional<std::pair<std::int64_t, std::int64_t>> {
        for (const auto offset : kMooreNeighbours) {
            const auto target_x = x + offset.x;
            const auto target_y = y + offset.y;
            if (predicate(get(target_x, target_y), target_x, target_y)) {
                return std::pair{target_x, target_y};
            }
        }
        return std::nullopt;
    };
    // Transport remains full-rate, while secondary work occupies spatially
    // staggered temporal lanes. This is the gameplay-fidelity path: every lane
    // is eventually visited, but a short-lived contact may intentionally be
    // missed. Stable phases avoid whole material fields pulsing in lockstep.
    const auto temporal_lane_due = [this, x, y](std::uint64_t period,
                                                 std::uint32_t stream) {
        const auto phase = mix64(
            static_cast<std::uint64_t>(x) * 0x9e3779b185ebca87ULL ^
            std::rotl(static_cast<std::uint64_t>(y), 23) ^
            static_cast<std::uint64_t>(stream) * 0xa0761d6478bd642fULL) % period;
        return tick_index_ % period == phase;
    };
    const bool contact_chemistry_due = temporal_lane_due(4U, 190U);
    const bool lifecycle_due = temporal_lane_due(2U, 191U);
    const bool thermal_change_due = temporal_lane_due(4U, 192U);
    const bool slow_lifecycle_due = temporal_lane_due(8U, 193U);
    const auto slow_interaction_due = [&temporal_lane_due](std::uint32_t stream) {
        return temporal_lane_due(120U, stream);
    };
    const auto ignite = [this, effects](std::int64_t target_x, std::int64_t target_y,
                                        std::uint8_t duration) {
        const auto target = get(target_x, target_y);
        if (target == Material::Dust || target == Material::Seed) {
            return write_cell(target_x, target_y, Material::Fire, duration, 0, effects);
        }
        if (target == Material::Gunpowder) {
            return write_cell(target_x, target_y, Material::Fire, duration, 0, effects);
        }
        if (!is_combustible(target)) return false;
        const auto burn = std::max(state_b(target_x, target_y), duration);
        return write_cell(target_x, target_y, target, state_a(target_x, target_y), burn,
                          effects);
    };
    const auto fall_as_powder = [this, material, x, y, direction, effects]() {
        if (try_move(material, x, y, x, y + 1, true, effects)) return true;
        if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
        return try_move(material, x, y, x - direction, y + 1, true, effects);
    };
    const auto flow_as_yielding_liquid =
        [this, material, x, y, direction, effects](std::uint32_t random_stream) {
            if (try_move(material, x, y, x, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x - direction, y + 1, true, effects)) return true;
            const auto viscosity = material == Material::Mercury &&
                config_.physics_diagnostics.mercury_viscosity >= 0
                ? static_cast<std::uint8_t>(config_.physics_diagnostics.mercury_viscosity)
                : MaterialRules::descriptor(material).viscosity_index;
            const auto mobility = static_cast<std::uint16_t>(256U - viscosity);
            if (deterministic_random(x, y, random_stream) >= mobility) return false;
            if (try_move(material, x, y, x + direction, y, false, effects)) return true;
            return try_move(material, x, y, x - direction, y, false, effects);
        };

    if (contact_chemistry_due && MaterialRules::has_pair_reactions(material)) {
        const auto start = deterministic_random(x, y, 200U);
        const auto probability_roll = deterministic_random(x, y, 201U);
        for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
            const auto [target_x, target_y] = neighbour(start + step);
            const auto target = get(target_x, target_y);
            const auto reaction =
                MaterialRules::pair_reaction(material, target, probability_roll);
            if (!reaction.has_value()) continue;
            const auto& source_definition =
                MaterialRules::descriptor(reaction->source_product);
            const auto& target_definition =
                MaterialRules::descriptor(reaction->target_product);
            bool changed = write_cell(
                target_x, target_y, reaction->target_product,
                target_definition.initial_state_a, target_definition.initial_state_b,
                effects);
            changed = write_cell(
                          x, y, reaction->source_product,
                          source_definition.initial_state_a,
                          source_definition.initial_state_b, effects) ||
                      changed;
            return changed;
        }
    }

    switch (kernel) {
        case RuleKernel::None:
            return false;

        case RuleKernel::Sand:
            return fall_as_powder();

        case RuleKernel::Water:
            return update_water(x, y, effects);

        case RuleKernel::YieldingLiquid: {
            // Viscosity affects only lateral yield. Gravity and density exchange
            // remain responsive, while paste/slush deliberately retain stable
            // heap-capable behaviour unavailable to free-leveling Water.
            return flow_as_yielding_liquid(91U);
        }

        case RuleKernel::Steam: {
            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) {
                return write_cell(x, y, Material::Water, 255, 0, effects);
            }
            bool changed = write_cell(x, y, Material::Steam,
                                      static_cast<std::uint8_t>(lifetime - 1U), 0,
                                      effects);
            if (try_move(material, x, y, x, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x - direction, y - 1, true, effects)) return true;
            return try_move(material, x, y, x + direction, y, false, effects) || changed;
        }

        case RuleKernel::Foam: {
            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) {
                return write_cell(x, y, Material::Empty, 0, 0, effects);
            }
            bool changed = write_cell(x, y, Material::Foam,
                                      static_cast<std::uint8_t>(lifetime - 1U), 0,
                                      effects);
            if (try_move(material, x, y, x, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x - direction, y - 1, true, effects)) return true;
            return try_move(material, x, y, x + direction, y, false, effects) || changed;
        }

        case RuleKernel::Gas: {
            bool changed = false;
            if (slow_lifecycle_due) {
                auto lifetime = state_a(x, y);
                if (lifetime == 0U) {
                    lifetime = MaterialRules::descriptor(material).initial_state_a;
                }
                std::uint8_t smoke_neighbours = 0;
                for (const auto offset : kMooreNeighbours) {
                    smoke_neighbours += static_cast<std::uint8_t>(
                        get(x + offset.x, y + offset.y) == Material::Smoke);
                }
                // Dense clouds thin from within twice as quickly, producing a
                // slow collapsing-bubble texture without a separate gas field.
                const auto decay = static_cast<std::uint8_t>(
                    smoke_neighbours >= 5U ? 2U : 1U);
                if (lifetime <= decay) {
                    return write_cell(x, y, Material::Empty, 0, 0, effects);
                }
                changed = write_cell(
                    x, y, material, static_cast<std::uint8_t>(lifetime - decay), 0,
                    effects);
            }
            if (try_move(material, x, y, x, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x - direction, y - 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y, false, effects)) return true;
            keep_cell_active(x, y);
            return changed;
        }

        case RuleKernel::Fire: {
            bool changed = false;
            if (slow_interaction_due(10U)) {
                const auto sample_index = deterministic_random(x, y, 10U);
                const auto [sample_x, sample_y] = neighbour(sample_index);
                changed = ignite(sample_x, sample_y, 240) || changed;
            }

            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) {
                const auto& smoke = MaterialRules::descriptor(Material::Smoke);
                return write_cell(x, y, Material::Smoke, smoke.initial_state_a,
                                  smoke.initial_state_b, effects) ||
                       changed;
            }
            changed = write_cell(x, y, Material::Fire,
                                 static_cast<std::uint8_t>(lifetime - 1U), 0, effects) ||
                      changed;

            const auto drift = kMooreNeighbours[static_cast<std::size_t>(
                deterministic_random(x, y, 11U) % kMooreNeighbours.size())];
            if (drift.y <= 0 && get(x + drift.x, y + drift.y) == Material::Empty) {
                move_cell(x, y, x + drift.x, y + drift.y, false, effects);
                return true;
            }
            return changed;
        }

        case RuleKernel::Combustible: {
            const auto burn = state_b(x, y);
            if (burn == 0U) return false;
            if (!lifecycle_due) {
                keep_cell_active(x, y);
                return false;
            }
            if (find_neighbour([](Material candidate, auto, auto) {
                    return candidate == Material::Water;
                })) {
                return write_cell(x, y, material, state_a(x, y), 0, effects);
            }
            if (burn <= 1U) return write_cell(x, y, Material::Empty, 0, 0, effects);

            bool changed = write_cell(x, y, material, state_a(x, y),
                                      static_cast<std::uint8_t>(burn - 1U), effects);
            if ((burn & 7U) == 0U) {
                const auto [target_x, target_y] = neighbour(deterministic_random(x, y, 12U));
                if (get(target_x, target_y) == Material::Empty) {
                    changed = write_cell(target_x, target_y, Material::Fire, 32, 0, effects) ||
                              changed;
                }
            }
            return changed;
        }

        case RuleKernel::Gunpowder:
            if (lifecycle_due && find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Fire, 64, 0, effects);
            }
            return fall_as_powder();

        case RuleKernel::Coal: {
            auto burn = state_b(x, y);
            if (burn == 0U) {
                if (lifecycle_due && find_neighbour([](Material candidate, auto, auto) {
                        return is_hot(candidate);
                    })) {
                    return write_cell(x, y, Material::Coal, state_a(x, y), 160,
                                      effects);
                }
                return fall_as_powder();
            }
            if (!lifecycle_due) {
                keep_cell_active(x, y);
                return false;
            }
            if (find_neighbour([](Material candidate, auto, auto) {
                    return candidate == Material::Water || candidate == Material::Brine;
                })) {
                return write_cell(x, y, Material::Coal, state_a(x, y), 0, effects);
            }
            if (burn <= 1U) return write_cell(x, y, Material::Dust, 0, 0, effects);
            bool changed = write_cell(x, y, Material::Coal, state_a(x, y),
                                      static_cast<std::uint8_t>(burn - 1U), effects);
            if ((burn & 7U) == 0U) {
                const auto [target_x, target_y] = neighbour(deterministic_random(x, y, 121U));
                if (get(target_x, target_y) == Material::Empty) {
                    const auto emission = (burn & 15U) == 0U ? Material::Fire : Material::Smoke;
                    const auto& definition = MaterialRules::descriptor(emission);
                    changed = write_cell(target_x, target_y, emission,
                                         definition.initial_state_a,
                                         definition.initial_state_b, effects) ||
                              changed;
                }
            }
            return changed;
        }

        case RuleKernel::Metal: {
            const auto charge = state_b(x, y);
            if (charge == 0U) return false;
            if (!lifecycle_due) {
                keep_cell_active(x, y);
                return false;
            }
            bool changed = false;
            const auto start = deterministic_random(x, y, 122U);
            for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
                const auto [target_x, target_y] = neighbour(start + step);
                if (get(target_x, target_y) == Material::Metal &&
                    state_b(target_x, target_y) == 0U) {
                    changed = write_cell(target_x, target_y, Material::Metal, 0,
                                         static_cast<std::uint8_t>(charge / 2U), effects) ||
                              changed;
                    break;
                }
            }
            if ((charge & 3U) == 0U) {
                const auto [target_x, target_y] = neighbour(deterministic_random(x, y, 123U));
                if (get(target_x, target_y) == Material::Water) {
                    changed = write_cell(target_x, target_y, Material::Steam, 90, 0,
                                         effects) ||
                              changed;
                }
            }
            changed = write_cell(x, y, Material::Metal, 0,
                                 static_cast<std::uint8_t>(charge - 1U), effects) ||
                      changed;
            return changed;
        }

        case RuleKernel::Cement: {
            auto cure = state_a(x, y);
            bool changed = false;
            if (lifecycle_due) {
                bool touches_air = false;
                bool touches_water = false;
                bool touches_concrete = false;
                for (const auto offset : kMooreNeighbours) {
                    const auto candidate = get(x + offset.x, y + offset.y);
                    touches_air = touches_air || candidate == Material::Empty;
                    touches_water = touches_water || candidate == Material::Water ||
                                    candidate == Material::Brine;
                    touches_concrete = touches_concrete || candidate == Material::Concrete;
                }
                if (touches_air || touches_water || touches_concrete) {
                    const auto cure_rate = static_cast<std::uint8_t>(
                        touches_water ? 4U : (touches_concrete ? 2U : 1U));
                    if (cure <= cure_rate) {
                        return write_cell(x, y, Material::Concrete, 0, 0, effects);
                    }
                    cure = static_cast<std::uint8_t>(cure - cure_rate);
                    changed = write_cell(x, y, Material::Cement, cure, 0, effects);
                }
            }
            return flow_as_yielding_liquid(124U) || changed;
        }

        case RuleKernel::Spark: {
            if (const auto metal = find_neighbour([](Material candidate, auto, auto) {
                    return candidate == Material::Metal;
                })) {
                bool changed = write_cell(metal->first, metal->second, Material::Metal, 0,
                                          24, effects);
                changed = write_cell(x, y, Material::Empty, 0, 0, effects) || changed;
                return changed;
            }
            const auto [sample_x, sample_y] = neighbour(deterministic_random(x, y, 125U));
            if (ignite(sample_x, sample_y, 48)) {
                (void)write_cell(x, y, Material::Empty, 0, 0, effects);
                return true;
            }
            const auto lifetime = state_a(x, y);
            if (lifetime <= 1U) return write_cell(x, y, Material::Empty, 0, 0, effects);
            bool changed = write_cell(x, y, Material::Spark,
                                      static_cast<std::uint8_t>(lifetime - 1U), 0,
                                      effects);
            const auto drift = kMooreNeighbours[static_cast<std::size_t>(
                deterministic_random(x, y, 126U) % kMooreNeighbours.size())];
            if (drift.y <= 0 && get(x + drift.x, y + drift.y) == Material::Empty) {
                move_cell(x, y, x + drift.x, y + drift.y, false, effects);
                return true;
            }
            return changed;
        }

        case RuleKernel::MoltenGlass: {
            auto cooling = state_a(x, y);
            bool changed = false;
            if (thermal_change_due) {
                const auto cooling_before = cooling;
                if (find_neighbour([](Material candidate, auto, auto) {
                        return candidate == Material::Fire || candidate == Material::Lava ||
                               candidate == Material::MoltenGlass;
                    })) {
                    cooling = 180;
                } else if (cooling != 0U) {
                    --cooling;
                }
                if (cooling == 0U) {
                    return write_cell(x, y, Material::Glass, 0, 0, effects);
                }
                if (cooling != cooling_before) {
                    changed = write_cell(x, y, Material::MoltenGlass, cooling, 0,
                                         effects);
                }
            }
            return flow_as_yielding_liquid(127U) || changed;
        }

        case RuleKernel::Lava: {
            bool changed = false;
            if (contact_chemistry_due) {
                const auto sample_index = deterministic_random(x, y, 20U);
                const auto [sample_x, sample_y] = neighbour(sample_index);
                const auto sampled = get(sample_x, sample_y);
                if (sampled == Material::Ice) {
                    changed = write_cell(sample_x, sample_y, Material::Water, 255, 0,
                                         effects);
                } else {
                    changed = ignite(sample_x, sample_y, 64);
                }
            }
            if (try_move(material, x, y, x, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x - direction, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y, true, effects)) return true;
            return changed;
        }

        case RuleKernel::Ice: {
            if (!thermal_change_due) return false;
            if (find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Water, 255, 0, effects);
            }
            if (!temporal_lane_due(16U, 192U)) return false;
            const auto [target_x, target_y] = neighbour(deterministic_random(x, y, 30U));
            if (get(target_x, target_y) != Material::Water) return false;
            return write_cell(target_x, target_y, Material::Ice, 0, 0, effects);
        }

        case RuleKernel::Acid: {
            if (try_move(material, x, y, x, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y, true, effects)) return true;

            if (!lifecycle_due) return false;
            const auto strength = state_a(x, y);
            const auto [target_x, target_y] = neighbour(deterministic_random(x, y, 40U));
            const auto target = get(target_x, target_y);
            if (target == Material::Empty || target == Material::Wall ||
                target == Material::Acid) {
                return false;
            }
            const auto remaining = strength > 24U
                                       ? static_cast<std::uint8_t>(strength - 24U)
                                       : std::uint8_t{0};
            bool changed = write_cell(target_x, target_y, Material::Empty, 0, 0, effects);
            changed = write_cell(x, y, remaining == 0U ? Material::Empty : Material::Acid,
                                 remaining, 0, effects) ||
                      changed;
            return changed;
        }

        case RuleKernel::Stone:
            if (state_b(x, y) == 0U && get(x - 1, y - 1) == Material::Stone &&
                get(x + 1, y - 1) == Material::Stone) {
                return false;
            }
            return try_move(material, x, y, x, y + 1, true, effects);

        case RuleKernel::Dust:
            if (contact_chemistry_due && find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Fire, 40, 0, effects);
            }
            if (try_move(material, x, y, x, y + 1, true, effects)) return true;
            if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
            return try_move(material, x, y, x - direction, y + 1, true, effects);

        case RuleKernel::Oil: {
            auto burn = state_b(x, y);
            bool changed = false;
            if (burn == 0U && contact_chemistry_due &&
                find_neighbour([this](Material candidate, auto target_x,
                                      auto target_y) {
                    return is_hot(candidate) ||
                           (candidate == Material::Oil && state_b(target_x, target_y) != 0U);
                })) {
                burn = 64;
                changed = write_cell(x, y, Material::Oil, state_a(x, y), burn, effects);
            }
            if (burn != 0U && lifecycle_due) {
                if (find_neighbour([](Material candidate, auto, auto) {
                        return candidate == Material::Water;
                    })) {
                    burn = 0;
                    changed = write_cell(x, y, Material::Oil, state_a(x, y), 0, effects) ||
                              changed;
                } else if (burn <= 1U) {
                    return write_cell(x, y, Material::Empty, 0, 0, effects) || changed;
                } else {
                    burn = static_cast<std::uint8_t>(burn - 1U);
                    changed = write_cell(x, y, Material::Oil, state_a(x, y), burn, effects) ||
                              changed;
                    if ((burn & 3U) == 0U) {
                        const auto [target_x, target_y] =
                            neighbour(deterministic_random(x, y, 50U));
                        if (get(target_x, target_y) == Material::Empty) {
                            changed = write_cell(target_x, target_y, Material::Fire, 32, 0,
                                                 effects) ||
                                      changed;
                        }
                    }
                }
            }
            if (try_move(material, x, y, x, y + 1, false, effects)) return true;
            if (try_move(material, x, y, x + direction, y + 1, false, effects)) return true;
            if (try_move(material, x, y, x - direction, y + 1, false, effects)) return true;
            if (try_move(material, x, y, x + direction, y, false, effects)) return true;
            return changed;
        }

        case RuleKernel::Cloner: {
            if (!contact_chemistry_due) {
                keep_cell_active(x, y);
                return false;
            }
            auto captured = state_b(x, y);
            if (!valid_material(captured) || captured == static_cast<std::uint8_t>(Material::Empty) ||
                captured == static_cast<std::uint8_t>(Material::Wall) ||
                captured == static_cast<std::uint8_t>(Material::Cloner)) {
                const auto start = deterministic_random(x, y, 60U);
                for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
                    const auto [target_x, target_y] = neighbour(start + step);
                    const auto candidate = get(target_x, target_y);
                    if (candidate == Material::Empty || candidate == Material::Wall ||
                        candidate == Material::Cloner) {
                        continue;
                    }
                    captured = static_cast<std::uint8_t>(candidate);
                    return write_cell(x, y, Material::Cloner, state_a(x, y), captured,
                                      effects);
                }
                return false;
            }

            const auto start = deterministic_random(x, y, 61U);
            for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
                const auto [target_x, target_y] = neighbour(start + step);
                if (get(target_x, target_y) != Material::Empty) continue;
                const auto cloned = static_cast<Material>(captured);
                const auto& definition = MaterialRules::descriptor(cloned);
                return write_cell(target_x, target_y, cloned, definition.initial_state_a,
                                  definition.initial_state_b, effects);
            }
            return false;
        }

        case RuleKernel::Plant:
        case RuleKernel::Fungus: {
            if (state_b(x, y) != 0U) {
                return update_rule_kernel(RuleKernel::Combustible, x, y, effects);
            }
            if (contact_chemistry_due && find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, material, state_a(x, y), 48, effects);
            }

            const auto energy = state_a(x, y);
            if (energy == 0U) return false;
            if (!contact_chemistry_due) {
                keep_cell_active(x, y);
                return false;
            }
            const auto start = deterministic_random(
                x, y, kernel == RuleKernel::Plant ? 70U : 71U);
            for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
                const auto [target_x, target_y] = neighbour(start + step);
                const auto target = get(target_x, target_y);
                const bool eligible =
                    kernel == RuleKernel::Plant
                        ? (target == Material::Empty || target == Material::Water ||
                           target == Material::Fungus)
                        : (target == Material::Empty || is_timber(target));
                if (!eligible) continue;

                const auto child_energy = static_cast<std::uint8_t>((energy - 1U) / 2U);
                const auto parent_energy = static_cast<std::uint8_t>(energy - 1U - child_energy);
                bool changed = write_cell(target_x, target_y, material, child_energy, 0,
                                          effects);
                changed = write_cell(x, y, material, parent_energy, 0, effects) || changed;
                return changed;
            }
            return false;
        }

        case RuleKernel::Mite: {
            std::size_t nearby_mites = 0;
            for (const auto offset : kMooreNeighbours) {
                const auto candidate = get(x + offset.x, y + offset.y);
                if (candidate == Material::Mite) ++nearby_mites;
                if (candidate == Material::Fire || candidate == Material::Lava ||
                    candidate == Material::Water || candidate == Material::Oil) {
                    return write_cell(x, y, Material::Empty, 0, 0, effects);
                }
            }
            if (nearby_mites >= 5U) {
                return write_cell(x, y, Material::Empty, 0, 0, effects);
            }

            if (try_move(material, x, y, x, y + 1, false, effects)) return true;
            const auto heading = state_a(x, y) == 255U ? -1 : 1;
            const auto target_x = x + heading;
            const auto target = get(target_x, y);
            if (target == Material::Empty) {
                move_cell(x, y, target_x, y, false, effects);
                return true;
            }
            const bool edible_target = target == Material::Plant || is_timber(target) ||
                                         target == Material::Seed ||
                                         target == Material::Dust;
            if (edible_target && !contact_chemistry_due) {
                keep_cell_active(x, y);
                return false;
            }
            if (edible_target) {
                bool changed = write_cell(target_x, y, Material::Mite, state_a(x, y),
                                          state_b(x, y), effects);
                changed = write_cell(x, y, Material::Empty, 0, 0, effects) || changed;
                return changed;
            }
            if (get(x, y + 1) == Material::Ice &&
                try_move(material, x, y, target_x, y, false, effects)) {
                return true;
            }
            if ((deterministic_random(x, y, 80U) & 3U) == 0U &&
                try_move(material, x, y, target_x, y - 1, false, effects)) {
                return true;
            }
            const auto reversed = state_a(x, y) == 255U ? std::uint8_t{1} : std::uint8_t{255};
            return write_cell(x, y, Material::Mite, reversed, state_b(x, y), effects);
        }

        case RuleKernel::Rocket: {
            auto flight = state_a(x, y);
            auto payload = state_b(x, y);
            if (!valid_material(payload) || payload == static_cast<std::uint8_t>(Material::Empty) ||
                payload == static_cast<std::uint8_t>(Material::Wall) ||
                payload == static_cast<std::uint8_t>(Material::Cloner) ||
                payload == static_cast<std::uint8_t>(Material::Rocket)) {
                payload = static_cast<std::uint8_t>(Material::Sand);
            }

            if (flight == 0U) {
                if (find_neighbour([](Material candidate, auto, auto) {
                        return is_hot(candidate);
                    }) ||
                    temperature(x, y) > static_cast<std::int32_t>(config_.ambient_temperature) +
                                            400) {
                    flight = static_cast<std::uint8_t>(
                        deterministic_random(x, y, 90U) % kMooreNeighbours.size() + 1U);
                    return write_cell(x, y, Material::Rocket, flight, payload, effects);
                }

                const auto start = deterministic_random(x, y, 91U);
                for (std::size_t step = 0; step < kMooreNeighbours.size(); ++step) {
                    const auto [target_x, target_y] = neighbour(start + step);
                    const auto candidate = get(target_x, target_y);
                    if (candidate == Material::Empty || candidate == Material::Wall ||
                        candidate == Material::Cloner || candidate == Material::Rocket) {
                        continue;
                    }
                    payload = static_cast<std::uint8_t>(candidate);
                    break;
                }
                (void)write_cell(x, y, Material::Rocket, 0, payload, effects);
                if (try_move(material, x, y, x, y + 1, true, effects)) return true;
                if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
                return try_move(material, x, y, x - direction, y + 1, true, effects);
            }

            const auto offset = kMooreNeighbours[static_cast<std::size_t>(flight - 1U)];
            const auto target_x = x + static_cast<std::int64_t>(offset.x) * 2;
            const auto target_y = y + static_cast<std::int64_t>(offset.y) * 2;
            const auto target = get(target_x, target_y);
            if (target == Material::Empty || target == Material::Fire ||
                target == Material::Smoke) {
                const auto payload_material = static_cast<Material>(payload);
                const auto& payload_definition = MaterialRules::descriptor(payload_material);
                bool changed = write_cell(target_x, target_y, Material::Rocket, flight, payload,
                                          effects);
                changed = write_cell(x, y, payload_material,
                                     payload_definition.initial_state_a,
                                     payload_definition.initial_state_b, effects) ||
                          changed;
                return changed;
            }
            return write_cell(x, y, Material::Fire, 24, 0, effects);
        }

        case RuleKernel::Seed: {
            if (contact_chemistry_due && find_neighbour([](Material candidate, auto, auto) {
                    return is_hot(candidate);
                })) {
                return write_cell(x, y, Material::Fire, 24, 0, effects);
            }

            auto stage = state_a(x, y);
            auto germinated = state_b(x, y);
            if (germinated == 0U) {
                const auto support = get(x, y + 1);
                if (support == Material::Sand || support == Material::Plant ||
                    support == Material::Fungus) {
                    if (!contact_chemistry_due) {
                        keep_cell_active(x, y);
                        return false;
                    }
                    return write_cell(x, y, Material::Seed, 8, 1, effects);
                }
                if (try_move(material, x, y, x, y + 1, true, effects)) return true;
                if (try_move(material, x, y, x + direction, y + 1, true, effects)) return true;
                return try_move(material, x, y, x - direction, y + 1, true, effects);
            }

            if (!contact_chemistry_due) {
                keep_cell_active(x, y);
                return false;
            }
            if (stage == 0U) return write_cell(x, y, Material::Plant, 16, 0, effects);
            bool changed = false;
            if ((stage & 1U) == 0U && get(x, y - 1) == Material::Empty) {
                changed = write_cell(x, y - 1, Material::Plant,
                                     static_cast<std::uint8_t>(stage / 2U), 0, effects);
            }
            --stage;
            changed = write_cell(x, y, Material::Seed, stage, germinated, effects) || changed;
            return changed;
        }
    }
    return false;
}

bool World::update_cell(std::int64_t x, std::int64_t y, JobEffects* effects) {
    const auto source_address = address(x, y);
    auto* source_chunk = find_chunk(source_address.chunk);
    if (source_chunk == nullptr ||
        source_chunk->cells[source_address.index].updated_epoch == update_epoch_) {
        return false;
    }

    const auto material = source_chunk->cells[source_address.index].material;
    const auto& definition = MaterialRules::descriptor(material);
    return update_rule_kernel(definition.kernel, x, y, effects);
}

void World::begin_tick(TickStats& stats) {
    ++tick_index_;
    update_epoch_ = static_cast<std::uint8_t>(update_epoch_ + 1U);
    if (update_epoch_ == 0) {
        for (auto& [coord, chunk] : chunks_) {
            (void)coord;
            for (auto& cell : chunk->cells) cell.updated_epoch = 0;
        }
        update_epoch_ = 1;
    }
    stats.tick = tick_index_;

    active_chunk_scratch_.clear();
    const bool transition = config_.backend == SimulationBackend::PhasedInPlace &&
                            selected_core_region_ != applied_core_region_;
    // Reuse the existing metadata pass, with no cell scan or region-sized
    // allocation. Coalesced/equivalent windows do not repeatedly wake blocks.
    for (auto& [coord, chunk] : chunks_) {
        chunk->changed_this_tick = false;
        for (std::size_t index = 0; index < chunk->activity_blocks.size(); ++index) {
            auto& block = chunk->activity_blocks[index];
            block.changed_this_tick = false;
            if (!transition) continue;
            const auto bounds = block_core_range(coord, index);
            const auto included = clip_core_range(bounds, selected_core_region_);
            const auto previous = clip_core_range(included, applied_core_region_);
            if (included.min_x <= included.max_x && included.min_y <= included.max_y &&
                included != previous) {
                block.active = true;
                block.quiet_ticks = 0;
                chunk->active = true;
            }
        }
    }
    applied_core_region_ = selected_core_region_;

    // Gameplay events are committed only at a tick boundary. Applying them
    // after resetting change flags makes their edits visible to activity,
    // dirty-region, and sleep accounting for this tick. Event-written cells
    // carry the current epoch and therefore begin material simulation on the
    // following tick instead of receiving an accidental double update.
    apply_pending_explosions(stats);

    for (const auto& [coord, chunk] : chunks_) {
        if (chunk->active) {
            if (active_chunk_scratch_.size() >= config_.active_chunk_capacity) {
                throw std::runtime_error("active chunk capacity exhausted");
            }
            active_chunk_scratch_.push_back(coord);
        }
    }
    stats.active_chunks_before = active_chunk_scratch_.size();
}

World::CoreRange World::block_core_range(ChunkCoord coord, std::size_t index) const noexcept {
    const auto blocks_per_axis = static_cast<std::size_t>(
        (config_.chunk_size + config_.activity_block_size - 1) / config_.activity_block_size);
    const auto x = static_cast<std::int32_t>(index % blocks_per_axis) * config_.activity_block_size;
    const auto y = static_cast<std::int32_t>(index / blocks_per_axis) * config_.activity_block_size;
    const auto first = scheduler_geometry_.core_for_cell(
        coord.x * config_.chunk_size + x, coord.y * config_.chunk_size + y);
    const auto last = scheduler_geometry_.core_for_cell(
        coord.x * config_.chunk_size + std::min(x + config_.activity_block_size, config_.chunk_size) - 1,
        coord.y * config_.chunk_size + std::min(y + config_.activity_block_size, config_.chunk_size) - 1);
    return {first.x, first.y, last.x, last.y};
}

World::CoreRange World::clip_core_range(CoreRange block, std::optional<CoreRange> region) noexcept {
    if (!region) return block;
    return {std::max(block.min_x, region->min_x), std::max(block.min_y, region->min_y),
            std::min(block.max_x, region->max_x), std::min(block.max_y, region->max_y)};
}

void World::finish_tick(TickStats& stats) {
    for (auto& [coord, chunk] : chunks_) {
        bool any_active_block = false;
        for (std::size_t index = 0; index < chunk->activity_blocks.size(); ++index) {
            auto& block = chunk->activity_blocks[index];
            if (!block.active) continue;
            // Quiet time belongs to simulated work. For custom single-worker
            // geometry, retain a straddling block until all its cores are eligible.
            const auto bounds = block_core_range(coord, index);
            const bool age = config_.backend == SimulationBackend::SerialInPlace ||
                             clip_core_range(bounds, selected_core_region_) == bounds;
            if (block.changed_this_tick) {
                block.quiet_ticks = 0;
            } else if (age && ++block.quiet_ticks >= config_.sleep_after_quiet_ticks) {
                block.active = false;
            }
            any_active_block = any_active_block || block.active;
        }
        chunk->active = any_active_block;
        chunk->quiet_ticks = any_active_block ? 0 : config_.sleep_after_quiet_ticks;
        if (chunk->active) ++stats.active_chunks_after;
        if (chunk->dirty) ++stats.dirty_chunks;
    }
}

TickStats World::tick_serial() {
    TickStats stats{};
    begin_tick(stats);
    std::sort(active_chunk_scratch_.begin(), active_chunk_scratch_.end(),
              [this](const ChunkCoord& left, const ChunkCoord& right) {
        if (left.y != right.y) return left.y > right.y;
        return (tick_index_ & 1ULL) == 0 ? left.x < right.x : left.x > right.x;
    });

    for (const auto coord : active_chunk_scratch_) {
        auto* chunk = find_chunk(coord);
        if (chunk == nullptr || !chunk->active) continue;

        for (std::int32_t local_y = config_.chunk_size - 1; local_y >= 0; --local_y) {
            const bool left_to_right = ((static_cast<std::uint64_t>(local_y) + tick_index_) & 1ULL) == 0;
            for (std::int32_t step = 0; step < config_.chunk_size; ++step) {
                const auto local_x = left_to_right ? step : config_.chunk_size - 1 - step;
                const auto index = static_cast<std::size_t>(local_y) * static_cast<std::size_t>(config_.chunk_size) +
                                   static_cast<std::size_t>(local_x);
                const auto& cell = chunk->cells[index];
                if (cell.updated_epoch == update_epoch_ ||
                    !rule_is_active(cell.material, cell.state_a, cell.state_b)) {
                    continue;
                }
                ++stats.visited_cells;
                const auto world_x = coord.x * config_.chunk_size + local_x;
                const auto world_y = coord.y * config_.chunk_size + local_y;
                if (update_cell(world_x, world_y)) {
                    ++stats.moved_cells;
                }
            }
        }
    }

    finish_tick(stats);
    return stats;
}

void World::gather_active_cores() {
    active_core_scratch_.clear();
    for (const auto chunk_coord : active_chunk_scratch_) {
        const auto* chunk = find_chunk(chunk_coord);
        if (chunk == nullptr) continue;
        const auto chunk_origin_x = chunk_coord.x * config_.chunk_size;
        const auto chunk_origin_y = chunk_coord.y * config_.chunk_size;
        for (std::int32_t block_y = 0; block_y < chunk->activity_blocks_per_axis; ++block_y) {
            for (std::int32_t block_x = 0; block_x < chunk->activity_blocks_per_axis; ++block_x) {
                const auto block_index =
                    static_cast<std::size_t>(block_y) *
                        static_cast<std::size_t>(chunk->activity_blocks_per_axis) +
                    static_cast<std::size_t>(block_x);
                if (!chunk->activity_blocks[block_index].active) continue;

                const auto local_minimum_x = block_x * config_.activity_block_size;
                const auto local_minimum_y = block_y * config_.activity_block_size;
                const auto local_maximum_x =
                    std::min(local_minimum_x + config_.activity_block_size, config_.chunk_size) - 1;
                const auto local_maximum_y =
                    std::min(local_minimum_y + config_.activity_block_size, config_.chunk_size) - 1;
                const auto minimum_core = scheduler_geometry_.core_for_cell(
                    chunk_origin_x + local_minimum_x, chunk_origin_y + local_minimum_y);
                const auto maximum_core = scheduler_geometry_.core_for_cell(
                    chunk_origin_x + local_maximum_x, chunk_origin_y + local_maximum_y);

                for (auto core_y = minimum_core.y; core_y <= maximum_core.y; ++core_y) {
                    for (auto core_x = minimum_core.x; core_x <= maximum_core.x; ++core_x) {
                        if (selected_core_region_ &&
                            (core_x < selected_core_region_->min_x || core_x > selected_core_region_->max_x ||
                             core_y < selected_core_region_->min_y || core_y > selected_core_region_->max_y)) continue;
                        if (active_core_scratch_.size() >= config_.active_core_capacity) {
                            throw std::runtime_error("active scheduling-core capacity exhausted");
                        }
                        active_core_scratch_.push_back({core_x, core_y});
                    }
                }
            }
        }
    }
    std::sort(active_core_scratch_.begin(), active_core_scratch_.end());
    active_core_scratch_.erase(
        std::unique(active_core_scratch_.begin(), active_core_scratch_.end()),
        active_core_scratch_.end());
}

void World::scan_rect(CellRect rect, TickStats& stats, JobEffects* effects) {
    const auto end_x = rect.x + rect.width;
    const auto end_y = rect.y + rect.height;
    const auto first_address = address(rect.x, rect.y);
    const auto last_address = address(end_x - 1, end_y - 1);
    if (first_address.chunk == last_address.chunk) {
        auto* chunk = find_chunk(first_address.chunk);
        if (chunk == nullptr || !chunk->active) return;
        for (auto local_y = last_address.local_y + 1; local_y-- > first_address.local_y;) {
            const auto world_y = first_address.chunk.y * config_.chunk_size + local_y;
            const bool left_to_right =
                ((static_cast<std::uint64_t>(world_y) + tick_index_) & 1ULL) == 0;
            for (std::int32_t step = 0; step < static_cast<std::int32_t>(rect.width); ++step) {
                const auto local_x = left_to_right ? first_address.local_x + step
                                                  : last_address.local_x - step;
                const auto index =
                    static_cast<std::size_t>(local_y) * static_cast<std::size_t>(config_.chunk_size) +
                    static_cast<std::size_t>(local_x);
                const auto& cell = chunk->cells[index];
                if (cell.updated_epoch == update_epoch_ ||
                    !rule_is_active(cell.material, cell.state_a, cell.state_b)) {
                    continue;
                }
                ++stats.visited_cells;
                const auto world_x = first_address.chunk.x * config_.chunk_size + local_x;
                if (update_cell(world_x, world_y, effects)) ++stats.moved_cells;
            }
        }
        return;
    }

    for (auto world_y = end_y; world_y-- > rect.y;) {
        const bool left_to_right =
            ((static_cast<std::uint64_t>(world_y) + tick_index_) & 1ULL) == 0;
        for (std::int64_t step = 0; step < rect.width; ++step) {
            const auto world_x = left_to_right ? rect.x + step : end_x - 1 - step;
            const auto source = address(world_x, world_y);
            auto* chunk = find_chunk(source.chunk);
            if (chunk == nullptr || !chunk->active) continue;
            const auto& cell = chunk->cells[source.index];
            if (cell.updated_epoch == update_epoch_ ||
                !rule_is_active(cell.material, cell.state_a, cell.state_b)) {
                continue;
            }
            ++stats.visited_cells;
            if (update_cell(world_x, world_y, effects)) ++stats.moved_cells;
        }
    }
}

void World::prepare_write_domain(CellRect core_rect) {
    const auto core_minimum = address(core_rect.x, core_rect.y);
    const auto core_maximum =
        address(core_rect.x + core_rect.width - 1, core_rect.y + core_rect.height - 1);
    for (auto chunk_y = core_minimum.chunk.y; chunk_y <= core_maximum.chunk.y; ++chunk_y) {
        for (auto chunk_x = core_minimum.chunk.x; chunk_x <= core_maximum.chunk.x; ++chunk_x) {
            (void)ensure_chunk({chunk_x, chunk_y});
        }
    }

    const auto radius = static_cast<std::int64_t>(scheduler_geometry_.write_radius());
    const CellRect expanded{
        core_rect.x - radius,
        core_rect.y - radius,
        core_rect.width + radius * 2,
        core_rect.height + radius * 2,
    };
    const auto expanded_minimum = address(expanded.x, expanded.y);
    const auto expanded_maximum =
        address(expanded.x + expanded.width - 1, expanded.y + expanded.height - 1);
    for (auto chunk_y = expanded_minimum.chunk.y; chunk_y <= expanded_maximum.chunk.y; ++chunk_y) {
        for (auto chunk_x = expanded_minimum.chunk.x; chunk_x <= expanded_maximum.chunk.x; ++chunk_x) {
            const ChunkCoord candidate{chunk_x, chunk_y};
            if (find_chunk(candidate) != nullptr) continue;

            const CellRect candidate_rect{
                chunk_x * config_.chunk_size,
                chunk_y * config_.chunk_size,
                config_.chunk_size,
                config_.chunk_size,
            };
            const auto source_minimum_x =
                std::max(core_rect.x, candidate_rect.x - radius);
            const auto source_minimum_y =
                std::max(core_rect.y, candidate_rect.y - radius);
            const auto source_maximum_x =
                std::min(core_rect.x + core_rect.width,
                         candidate_rect.x + candidate_rect.width + radius);
            const auto source_maximum_y =
                std::min(core_rect.y + core_rect.height,
                         candidate_rect.y + candidate_rect.height + radius);

            bool needs_destination = false;
            for (auto y = source_minimum_y; y < source_maximum_y && !needs_destination; ++y) {
                for (auto x = source_minimum_x; x < source_maximum_x; ++x) {
                    const auto material = get(x, y);
                    if (rule_is_active(material, state_a(x, y), state_b(x, y))) {
                        needs_destination = true;
                        break;
                    }
                }
            }
            if (needs_destination) (void)ensure_chunk(candidate);
        }
    }

    bool temperature_field_required = false;
    for (auto chunk_y = core_minimum.chunk.y; chunk_y <= core_maximum.chunk.y; ++chunk_y) {
        for (auto chunk_x = core_minimum.chunk.x; chunk_x <= core_maximum.chunk.x; ++chunk_x) {
            const auto* chunk = find_chunk({chunk_x, chunk_y});
            temperature_field_required =
                temperature_field_required || (chunk != nullptr && chunk->temperatures != nullptr);
        }
    }
    if (temperature_field_required) {
        for (auto chunk_y = expanded_minimum.chunk.y; chunk_y <= expanded_maximum.chunk.y; ++chunk_y) {
            for (auto chunk_x = expanded_minimum.chunk.x; chunk_x <= expanded_maximum.chunk.x; ++chunk_x) {
                auto* chunk = find_chunk({chunk_x, chunk_y});
                if (chunk != nullptr && chunk->temperatures == nullptr) {
                    ensure_temperature_field(*chunk);
                }
            }
        }
    }
}

void World::merge_job_effects(const JobEffects& effects) {
    if (effects.overflow) {
        throw std::runtime_error("per-job touched-chunk capacity exhausted");
    }
    if (effects.physics != nullptr) {
        for (const auto& entry : effects.physics->entries)
            if (entry.key != 0) physics_totals_->add(entry.key, entry.count);
        physics_totals_->overflow += effects.physics->overflow;
    }
    if (effects.hard_surface_changed) ++hard_surface_revision_;
    for (std::size_t effect_index = 0; effect_index < effects.chunk_count; ++effect_index) {
        const auto& effect = effects.chunks[effect_index];
        auto* chunk = find_chunk(effect.chunk);
        if (chunk == nullptr) {
            throw std::logic_error("job effect references missing chunk");
        }
        const auto updated_non_empty =
            static_cast<std::int64_t>(chunk->non_empty_cell_count) + effect.non_empty_delta;
        if (updated_non_empty < 0 ||
            updated_non_empty > static_cast<std::int64_t>(chunk->cells.size())) {
            throw std::logic_error("job effect produced an invalid non-empty-cell count");
        }
        chunk->non_empty_cell_count = static_cast<std::size_t>(updated_non_empty);

        chunk->changed_this_tick = true;
        if (!chunk->dirty) {
            chunk->dirty = true;
            chunk->dirty_min_x = effect.minimum_x;
            chunk->dirty_min_y = effect.minimum_y;
            chunk->dirty_max_x = effect.maximum_x;
            chunk->dirty_max_y = effect.maximum_y;
        } else {
            chunk->dirty_min_x = std::min(chunk->dirty_min_x, effect.minimum_x);
            chunk->dirty_min_y = std::min(chunk->dirty_min_y, effect.minimum_y);
            chunk->dirty_max_x = std::max(chunk->dirty_max_x, effect.maximum_x);
            chunk->dirty_max_y = std::max(chunk->dirty_max_y, effect.maximum_y);
        }

        const auto minimum_block_x = effect.minimum_x / config_.activity_block_size;
        const auto minimum_block_y = effect.minimum_y / config_.activity_block_size;
        const auto maximum_block_x = effect.maximum_x / config_.activity_block_size;
        const auto maximum_block_y = effect.maximum_y / config_.activity_block_size;
        for (auto block_y = minimum_block_y; block_y <= maximum_block_y; ++block_y) {
            for (auto block_x = minimum_block_x; block_x <= maximum_block_x; ++block_x) {
                const auto block_index =
                    static_cast<std::size_t>(block_y) *
                        static_cast<std::size_t>(chunk->activity_blocks_per_axis) +
                    static_cast<std::size_t>(block_x);
                auto& block = chunk->activity_blocks[block_index];
                block.active = true;
                block.changed_this_tick = true;
                block.quiet_ticks = 0;
                chunk->active = true;

                const auto local_left = block_x * config_.activity_block_size;
                const auto local_top = block_y * config_.activity_block_size;
                const auto local_right =
                    std::min(local_left + config_.activity_block_size, config_.chunk_size) - 1;
                const auto local_bottom =
                    std::min(local_top + config_.activity_block_size, config_.chunk_size) - 1;
                const auto world_origin_x = effect.chunk.x * config_.chunk_size;
                const auto world_origin_y = effect.chunk.y * config_.chunk_size;
                wake_cell_neighborhood(world_origin_x + local_left, world_origin_y + local_top);
                wake_cell_neighborhood(world_origin_x + local_right, world_origin_y + local_top);
                wake_cell_neighborhood(world_origin_x + local_left, world_origin_y + local_bottom);
                wake_cell_neighborhood(world_origin_x + local_right, world_origin_y + local_bottom);
            }
        }
    }
}

TickStats World::tick_phased() {
    TickStats stats{};
    begin_tick(stats);
    gather_active_cores();
    stats.scheduled_cores = active_core_scratch_.size();
    if (parallel_ == nullptr || parallel_->results.size() < active_core_scratch_.size()) {
        throw std::logic_error("phased scheduler scratch capacity is unavailable");
    }

    const auto first_phase = static_cast<std::uint8_t>(tick_index_ % SchedulerGeometry::kPhaseCount);
    for (std::uint8_t pass = 0; pass < SchedulerGeometry::kPhaseCount; ++pass) {
        const auto phase = static_cast<std::uint8_t>(
            (first_phase + pass) % SchedulerGeometry::kPhaseCount);
        parallel_->phase_job_indices.clear();
        for (std::size_t core_index = 0; core_index < active_core_scratch_.size(); ++core_index) {
            const auto core = active_core_scratch_[core_index];
            if (scheduler_geometry_.phase(core) != phase) continue;
            parallel_->phase_job_indices.push_back(core_index);
            prepare_write_domain(scheduler_geometry_.core_rect(core));
            auto& result = parallel_->results[core_index];
            result.stats = {};
            result.effects.reset();
            ++stats.phase_jobs[phase];
        }

        struct DispatchContext {
            World* world;
            ParallelState* parallel;
        } context{this, parallel_.get()};
        const auto execute_task = +[](void* raw_context, std::size_t task_index) noexcept {
            auto& dispatch = *static_cast<DispatchContext*>(raw_context);
            const auto core_index = dispatch.parallel->phase_job_indices[task_index];
            auto& result = dispatch.parallel->results[core_index];
            dispatch.world->scan_rect(
                dispatch.world->scheduler_geometry_.core_rect(
                    dispatch.world->active_core_scratch_[core_index]),
                result.stats, &result.effects);
        };

        if (parallel_->pool != nullptr &&
            parallel_->phase_job_indices.size() >= config_.parallel_job_threshold) {
            parallel_->pool->dispatch(parallel_->phase_job_indices.size(), &context, execute_task);
        } else {
            for (std::size_t task_index = 0;
                 task_index < parallel_->phase_job_indices.size(); ++task_index) {
                execute_task(&context, task_index);
            }
        }

        for (const auto core_index : parallel_->phase_job_indices) {
            const auto& result = parallel_->results[core_index];
            stats.visited_cells += result.stats.visited_cells;
            stats.moved_cells += result.stats.moved_cells;
            merge_job_effects(result.effects);
        }
    }

    finish_tick(stats);
    return stats;
}

TickStats World::tick() {
    require_healthy();
    if (tick_in_progress_) throw std::logic_error("world tick is not reentrant");
    tick_in_progress_ = true;
    tick_chunk_allocations_ = 0;
    tick_temperature_field_allocations_ = 0;
    try {
        TickStats stats{};
        switch (config_.backend) {
            case SimulationBackend::SerialInPlace:
                stats = tick_serial();
                break;
            case SimulationBackend::PhasedInPlace:
                stats = tick_phased();
                break;
            case SimulationBackend::Buffered:
                throw std::logic_error("buffered simulation backend is not implemented");
        }
        stats.chunk_allocations = tick_chunk_allocations_;
        stats.temperature_field_allocations = tick_temperature_field_allocations_;
        completed_tick_index_ = tick_index_;
        tick_in_progress_ = false;
        return stats;
    } catch (...) {
        // Partial cell/event/epoch/metadata progress is diagnostic only. Workers
        // have drained at the phase barrier; never resume this in-place state.
        tick_failed_ = true;
        tick_in_progress_ = false;
        throw;
    }
}

void World::require_healthy() const {
    if (tick_failed_) throw std::logic_error("world is failed; clear or replace it before continuing");
}

bool World::has_failed() const noexcept { return tick_failed_; }
std::uint64_t World::completed_tick_index() const noexcept { return completed_tick_index_; }
std::uint64_t World::tick_index() const noexcept { return tick_index_; }
std::size_t World::chunk_count() const noexcept { return chunks_.size(); }

std::size_t World::active_chunk_count() const noexcept {
    return static_cast<std::size_t>(std::count_if(chunks_.begin(), chunks_.end(), [](const auto& entry) {
        return entry.second->active;
    }));
}

std::size_t World::resident_cell_bytes() const noexcept {
    std::size_t result = 0;
    for (const auto& [coord, chunk] : chunks_) {
        (void)coord;
        result += chunk->cells.capacity() * sizeof(Chunk::Cell);
        if (chunk->temperatures != nullptr) {
            result += chunk->temperatures->capacity() * sizeof(std::int16_t);
        }
        result += chunk->activity_blocks.capacity() * sizeof(Chunk::ActivityBlock);
    }
    return result;
}

std::uint64_t World::state_hash() const noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    hash_integer(hash, tick_index_);
    hash_integer(hash, completed_tick_index_);
    hash_integer(hash, static_cast<std::uint8_t>(tick_failed_));
    hash_integer(hash, update_epoch_);
    for (const auto& region : {selected_core_region_, applied_core_region_}) {
        hash_integer(hash, static_cast<std::uint8_t>(region.has_value()));
        if (region) {
            hash_integer(hash, region->min_x);
            hash_integer(hash, region->min_y);
            hash_integer(hash, region->max_x);
            hash_integer(hash, region->max_y);
        }
    }
    hash_integer(hash, config_.chunk_size);
    hash_integer(hash, static_cast<std::uint8_t>(config_.backend));
    hash_integer(hash, config_.sleep_after_quiet_ticks);
    hash_integer(hash, config_.ambient_temperature);
    hash_integer(hash, config_.activity_block_size);
    hash_integer(hash, config_.scheduling_core_size);
    hash_integer(hash, config_.maximum_rule_radius);
    hash_integer(hash, config_.maximum_explosion_radius);
    hash_integer(hash, static_cast<std::uint64_t>(config_.active_core_capacity));
    hash_integer(hash, static_cast<std::uint64_t>(config_.active_chunk_capacity));
    hash_integer(hash, static_cast<std::uint64_t>(config_.maximum_chunk_count));
    hash_integer(hash, static_cast<std::uint64_t>(config_.deferred_event_capacity));
    hash_integer(hash, static_cast<std::uint64_t>(pending_explosions_.size()));
    for (const auto& event : pending_explosions_) {
        hash_integer(hash, event.x);
        hash_integer(hash, event.y);
        hash_integer(hash, event.radius);
        hash_integer(hash, event.collapse_strength);
    }
    std::vector<ChunkCoord> coordinates;
    coordinates.reserve(chunks_.size());
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end());
    for (const auto coord : coordinates) {
        const auto* chunk = find_chunk(coord);
        if (chunk == nullptr) continue;
        hash_integer(hash, coord.x);
        hash_integer(hash, coord.y);
        hash_integer(hash, static_cast<std::uint8_t>(chunk->active ? 1U : 0U));
        hash_integer(hash, chunk->quiet_ticks);
        hash_integer(hash, chunk->non_empty_cell_count);
        for (const auto& block : chunk->activity_blocks) {
            hash_integer(hash, static_cast<std::uint8_t>(block.active ? 1U : 0U));
            hash_integer(hash, block.quiet_ticks);
        }
        for (std::size_t index = 0; index < chunk->cells.size(); ++index) {
            const auto& cell = chunk->cells[index];
            hash_integer(hash, static_cast<std::uint16_t>(cell.material));
            hash_integer(hash, cell.state_a);
            hash_integer(hash, cell.state_b);
            hash_integer(hash, cell.updated_epoch);
            hash_integer(hash, chunk->temperatures == nullptr
                                   ? config_.ambient_temperature
                                   : (*chunk->temperatures)[index]);
        }
    }
    return hash;
}

std::uint64_t World::content_hash() const noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    hash_integer(hash, config_.chunk_size);
    hash_integer(hash, config_.ambient_temperature);
    std::vector<ChunkCoord> coordinates;
    coordinates.reserve(chunks_.size());
    for (const auto& [coord, chunk] : chunks_) {
        (void)chunk;
        coordinates.push_back(coord);
    }
    std::sort(coordinates.begin(), coordinates.end());
    for (const auto coord : coordinates) {
        const auto* chunk = find_chunk(coord);
        if (chunk == nullptr) continue;
        for (std::size_t index = 0; index < chunk->cells.size(); ++index) {
            const auto& cell = chunk->cells[index];
            const auto temperature_value =
                chunk->temperatures == nullptr ? config_.ambient_temperature
                                               : (*chunk->temperatures)[index];
            if (cell.material == Material::Empty &&
                temperature_value == config_.ambient_temperature) {
                continue;
            }
            const auto local_x =
                static_cast<std::int64_t>(index % static_cast<std::size_t>(config_.chunk_size));
            const auto local_y =
                static_cast<std::int64_t>(index / static_cast<std::size_t>(config_.chunk_size));
            hash_integer(hash, coord.x * config_.chunk_size + local_x);
            hash_integer(hash, coord.y * config_.chunk_size + local_y);
            hash_integer(hash, static_cast<std::uint16_t>(cell.material));
            hash_integer(hash, cell.state_a);
            hash_integer(hash, cell.state_b);
            hash_integer(hash, temperature_value);
        }
    }
    return hash;
}

std::uint64_t World::hard_surface_revision() const noexcept {
    return hard_surface_revision_;
}

std::size_t World::dirty_chunk_count() const noexcept {
    return static_cast<std::size_t>(
        std::count_if(chunks_.begin(), chunks_.end(), [](const auto& entry) {
            return entry.second->dirty;
        }));
}

std::vector<DirtyChunk> World::take_dirty_chunks() {
    require_healthy();
    std::vector<DirtyChunk> result;
    for (auto& [coord, chunk] : chunks_) {
        if (!chunk->dirty) continue;
        result.push_back({coord,
                          {chunk->dirty_min_x,
                           chunk->dirty_min_y,
                           static_cast<std::int64_t>(chunk->dirty_max_x - chunk->dirty_min_x + 1),
                           static_cast<std::int64_t>(chunk->dirty_max_y - chunk->dirty_min_y + 1)}});
        chunk->dirty = false;
    }
    std::sort(result.begin(), result.end(), [](const DirtyChunk& left, const DirtyChunk& right) {
        return left.chunk < right.chunk;
    });
    return result;
}

void World::copy_render_cells(RectI64 region, std::span<std::uint8_t> destination,
                              std::size_t stride_bytes) const {
    (void)validate_copy_layout(region, 2U, stride_bytes, destination.size());
    for (std::int64_t row = 0; row < region.height; ++row) {
        auto* output = destination.data() + static_cast<std::size_t>(row) * stride_bytes;
        for (std::int64_t column = 0; column < region.width; ++column) {
            const auto world_x = region.x + column;
            const auto world_y = region.y + row;
            const auto offset = static_cast<std::size_t>(column) * 2U;
            const auto material = stored_material(world_x, world_y);
            output[offset] = static_cast<std::uint8_t>(material);
            output[offset + 1U] = project_visual_state(
                material, stored_state_a(world_x, world_y), stored_state_b(world_x, world_y));
        }
    }
}

void World::copy_material_cells(RectI64 region, std::span<std::uint8_t> destination,
                                std::size_t stride_bytes) const {
    (void)validate_copy_layout(region, 1U, stride_bytes, destination.size());
    const auto end_x = region.x + region.width;
    for (std::int64_t row = 0; row < region.height; ++row) {
        auto* output = destination.data() + static_cast<std::size_t>(row) * stride_bytes;
        const auto world_y = region.y + row;
        auto world_x = region.x;
        while (world_x < end_x) {
            const auto first = address(world_x, world_y);
            const auto* chunk = find_chunk(first.chunk);
            const auto run = std::min<std::int64_t>(
                end_x - world_x,
                static_cast<std::int64_t>(config_.chunk_size - first.local_x));
            for (std::int64_t offset = 0; offset < run; ++offset) {
                const auto output_index = static_cast<std::size_t>(world_x - region.x + offset);
                if (chunk == nullptr) {
                    output[output_index] = static_cast<std::uint8_t>(Material::Empty);
                    continue;
                }
                const auto cell_index = first.index + static_cast<std::size_t>(offset);
                auto material = chunk->cells[cell_index].material;
                if (material == Material::Water) {
                    const auto mass = chunk->cells[cell_index].state_a;
                    const auto sample_x = world_x + offset;
                    const auto threshold = static_cast<std::uint8_t>(
                        mix64(static_cast<std::uint64_t>(sample_x) *
                                  0x9e3779b185ebca87ULL ^
                              std::rotl(static_cast<std::uint64_t>(world_y), 17)) &
                        0xffU);
                    if (threshold >= mass) material = Material::Empty;
                }
                output[output_index] = static_cast<std::uint8_t>(material);
            }
            world_x += run;
        }
    }
}

void World::copy_rgba(RectI64 region, std::span<std::uint8_t> destination, std::size_t stride_bytes) const {
    (void)validate_copy_layout(region, 4U, stride_bytes, destination.size());

    for (std::int64_t row = 0; row < region.height; ++row) {
        auto* output = destination.data() + static_cast<std::size_t>(row) * stride_bytes;
        for (std::int64_t column = 0; column < region.width; ++column) {
            const auto world_x = region.x + column;
            const auto world_y = region.y + row;
            auto material = stored_material(world_x, world_y);
            if (material == Material::Water) {
                const auto mass = stored_state_a(world_x, world_y);
                const auto threshold = static_cast<std::uint8_t>(
                    mix64(static_cast<std::uint64_t>(world_x) * 0x9e3779b185ebca87ULL ^
                          std::rotl(static_cast<std::uint64_t>(world_y), 17)) &
                    0xffU);
                if (threshold >= mass) material = Material::Empty;
            }
            const auto colour = MaterialRules::descriptor(material).rgba;
            const auto offset = static_cast<std::size_t>(column) * 4U;
            std::copy(colour.begin(), colour.end(), output + offset);
        }
    }
}

}  // namespace cybersand
