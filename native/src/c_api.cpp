#include "cybersand/c_api.h"

#include "cybersand/material.hpp"
#include "cybersand/material_rules.hpp"
#include "cybersand/render_snapshot.hpp"
#include "cybersand/world.hpp"

#include <exception>
#include <limits>
#include <new>
#include <memory>
#include <span>

struct cybersand_world {
    explicit cybersand_world(cybersand::WorldConfig config) : implementation(config) {}
    cybersand::World implementation;
};

struct cybersand_render_exchange {
    cybersand_render_exchange(std::size_t slot_count, std::size_t patch_capacity,
                               std::size_t byte_capacity)
        : implementation(std::make_shared<cybersand::RenderSnapshotExchange>(
              slot_count, patch_capacity, byte_capacity)) {}
    std::shared_ptr<cybersand::RenderSnapshotExchange> implementation;
};

struct cybersand_render_lease {
    cybersand_render_lease(std::shared_ptr<cybersand::RenderSnapshotExchange> owner_value,
                           cybersand::RenderSnapshotLease lease_value)
        : owner(std::move(owner_value)), implementation(std::move(lease_value)) {}
    std::shared_ptr<cybersand::RenderSnapshotExchange> owner;
    cybersand::RenderSnapshotLease implementation;
};

namespace {

static_assert(static_cast<std::uint8_t>(cybersand::DensityMotion::None) ==
              CYBERSAND_DENSITY_MOTION_NONE);
static_assert(static_cast<std::uint8_t>(cybersand::DensityMotion::Down) ==
              CYBERSAND_DENSITY_MOTION_DOWN);
static_assert(static_cast<std::uint8_t>(cybersand::DensityMotion::Up) ==
              CYBERSAND_DENSITY_MOTION_UP);
static_assert(static_cast<std::uint8_t>(cybersand::LateralFlowMode::None) ==
              CYBERSAND_LATERAL_FLOW_NONE);
static_assert(static_cast<std::uint8_t>(cybersand::LateralFlowMode::FreeMass) ==
              CYBERSAND_LATERAL_FLOW_FREE_MASS);
static_assert(static_cast<std::uint8_t>(cybersand::LateralFlowMode::CellularYield) ==
              CYBERSAND_LATERAL_FLOW_CELLULAR_YIELD);

[[nodiscard]] bool checked_size(std::uint64_t value, std::size_t& destination) noexcept {
    if (value > std::numeric_limits<std::size_t>::max()) return false;
    destination = static_cast<std::size_t>(value);
    return true;
}

[[nodiscard]] bool native_config_from_v2(const cybersand_config_v2* source,
                                         cybersand::WorldConfig& destination) noexcept {
    if (source == nullptr || source->struct_size < sizeof(cybersand_config_v2) ||
        source->abi_version != CYBERSAND_CONFIG_V2_ABI_VERSION ||
        source->backend > CYBERSAND_BACKEND_BUFFERED) {
        return false;
    }
    destination.chunk_size = source->chunk_size;
    destination.sleep_after_quiet_ticks = source->sleep_after_quiet_ticks;
    destination.ambient_temperature = source->ambient_temperature;
    destination.backend = static_cast<cybersand::SimulationBackend>(source->backend);
    destination.activity_block_size = source->activity_block_size;
    destination.scheduling_core_size = source->scheduling_core_size;
    destination.maximum_rule_radius = source->maximum_rule_radius;
    destination.maximum_explosion_radius = source->maximum_explosion_radius;
    destination.worker_threads = source->worker_threads;
    return checked_size(source->initial_chunk_reserve, destination.initial_chunk_reserve) &&
           checked_size(source->parallel_job_threshold, destination.parallel_job_threshold) &&
           checked_size(source->active_core_capacity, destination.active_core_capacity) &&
           checked_size(source->active_chunk_capacity, destination.active_chunk_capacity) &&
           checked_size(source->maximum_chunk_count, destination.maximum_chunk_count) &&
           checked_size(source->deferred_event_capacity, destination.deferred_event_capacity);
}

void fill_material_info(std::uint16_t material, const cybersand::MaterialDefinition& definition,
                        cybersand_material_info& destination) noexcept {
    destination.id = material;
    destination.state = static_cast<std::uint8_t>(definition.state);
    destination.density = definition.density;
    for (std::size_t index = 0; index < 4; ++index) {
        destination.rgba[index] = definition.rgba[index];
    }
    destination.movable = definition.movable ? 1 : 0;
    destination.current_rule_available = definition.current_rule_available ? 1 : 0;
}

void fill_tick_stats(const cybersand::TickStats& source,
                     cybersand_tick_stats_v2& destination) noexcept {
    destination.tick = source.tick;
    destination.visited_cells = source.visited_cells;
    destination.moved_cells = source.moved_cells;
    destination.active_chunks_before = source.active_chunks_before;
    destination.active_chunks_after = source.active_chunks_after;
    destination.dirty_chunks = source.dirty_chunks;
    destination.scheduled_cores = source.scheduled_cores;
    for (std::size_t phase = 0; phase < source.phase_jobs.size(); ++phase) {
        destination.phase_jobs[phase] = source.phase_jobs[phase];
    }
    destination.chunk_allocations = source.chunk_allocations;
    destination.temperature_field_allocations = source.temperature_field_allocations;
    destination.deferred_events = source.deferred_events;
}

}  // namespace

extern "C" {

cybersand_world* cybersand_world_create(cybersand_config config) {
    try {
        cybersand::WorldConfig native_config{};
        native_config.chunk_size = config.chunk_size;
        native_config.sleep_after_quiet_ticks = config.sleep_after_quiet_ticks;
        native_config.ambient_temperature = config.ambient_temperature;
        return new cybersand_world(native_config);
    } catch (...) {
        return nullptr;
    }
}

void cybersand_world_destroy(cybersand_world* world) { delete world; }

uint16_t cybersand_world_get(const cybersand_world* world, int64_t x, int64_t y) {
    if (world == nullptr) return 0;
    return static_cast<uint16_t>(world->implementation.get(x, y));
}

void cybersand_world_set(cybersand_world* world, int64_t x, int64_t y, uint16_t material) {
    if (world == nullptr || !cybersand::valid_material(material)) return;
    try {
        world->implementation.set(x, y, static_cast<cybersand::Material>(material));
    } catch (...) {
    }
}

cybersand_tick_stats cybersand_world_tick(cybersand_world* world) {
    if (world == nullptr) return {};
    try {
        const auto stats = world->implementation.tick();
        return {stats.tick, stats.visited_cells, stats.moved_cells, stats.active_chunks_before,
                stats.active_chunks_after, stats.dirty_chunks};
    } catch (...) {
        return {};
    }
}

uint64_t cybersand_world_hash(const cybersand_world* world) {
    return world == nullptr ? 0 : world->implementation.state_hash();
}

size_t cybersand_world_resident_cell_bytes(const cybersand_world* world) {
    return world == nullptr ? 0 : world->implementation.resident_cell_bytes();
}

int cybersand_material_get_info(uint16_t material, cybersand_material_info* destination) {
    if (destination == nullptr || !cybersand::MaterialRules::is_valid(material)) return 0;
    const auto id = static_cast<cybersand::Material>(material);
    const auto& definition = cybersand::MaterialRules::descriptor(id);
    fill_material_info(material, definition, *destination);
    return 1;
}

int cybersand_world_copy_rgba(const cybersand_world* world, int64_t x, int64_t y, int64_t width,
                              int64_t height, uint8_t* destination, size_t destination_size,
                              size_t stride_bytes) {
    if (world == nullptr || destination == nullptr) return 0;
    try {
        world->implementation.copy_rgba({x, y, width, height},
                                        std::span<std::uint8_t>(destination, destination_size), stride_bytes);
        return 1;
    } catch (...) {
        return 0;
    }
}

cybersand_config_v2 cybersand_default_config_v2(void) {
    const cybersand::WorldConfig native{};
    return {
        sizeof(cybersand_config_v2),
        CYBERSAND_CONFIG_V2_ABI_VERSION,
        native.chunk_size,
        native.sleep_after_quiet_ticks,
        native.ambient_temperature,
        static_cast<uint8_t>(native.backend),
        0,
        native.activity_block_size,
        native.scheduling_core_size,
        native.maximum_rule_radius,
        native.worker_threads,
        static_cast<uint64_t>(native.initial_chunk_reserve),
        static_cast<uint64_t>(native.parallel_job_threshold),
        static_cast<uint64_t>(native.active_core_capacity),
        static_cast<uint64_t>(native.active_chunk_capacity),
        static_cast<uint64_t>(native.maximum_chunk_count),
        static_cast<uint64_t>(native.deferred_event_capacity),
        native.maximum_explosion_radius,
    };
}

cybersand_world* cybersand_world_create_v2(const cybersand_config_v2* config) {
    try {
        cybersand::WorldConfig native{};
        if (!native_config_from_v2(config, native)) return nullptr;
        return new cybersand_world(native);
    } catch (...) {
        return nullptr;
    }
}

int cybersand_world_set_v2(cybersand_world* world, int64_t x, int64_t y,
                           uint16_t material) {
    if (world == nullptr || !cybersand::valid_material(material)) return 0;
    try {
        world->implementation.set(x, y, static_cast<cybersand::Material>(material));
        return 1;
    } catch (...) {
        return 0;
    }
}

int cybersand_world_tick_v2(cybersand_world* world, cybersand_tick_stats_v2* destination) {
    if (world == nullptr || destination == nullptr) return 0;
    try {
        const auto stats = world->implementation.tick();
        fill_tick_stats(stats, *destination);
        return 1;
    } catch (...) {
        *destination = {};
        return 0;
    }
}

int cybersand_world_reserve_region(cybersand_world* world, int64_t x, int64_t y,
                                   int64_t width, int64_t height) {
    if (world == nullptr) return 0;
    try {
        world->implementation.reserve_region({x, y, width, height});
        return 1;
    } catch (...) {
        return 0;
    }
}

int cybersand_world_reserve_temperature_region(cybersand_world* world, int64_t x, int64_t y,
                                               int64_t width, int64_t height) {
    if (world == nullptr) return 0;
    try {
        world->implementation.reserve_temperature_region({x, y, width, height});
        return 1;
    } catch (...) {
        return 0;
    }
}

int cybersand_world_queue_explosion(cybersand_world* world, int64_t x, int64_t y,
                                    int32_t radius, uint8_t collapse_strength) {
    if (world == nullptr) return 0;
    try {
        return world->implementation.queue_explosion(x, y, radius, collapse_strength) ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

uint8_t cybersand_world_liquid_mass(const cybersand_world* world, int64_t x, int64_t y) {
    return world == nullptr ? 0 : world->implementation.liquid_mass(x, y);
}

uint64_t cybersand_world_content_hash(const cybersand_world* world) {
    return world == nullptr ? 0 : world->implementation.content_hash();
}

uint64_t cybersand_world_tick_index(const cybersand_world* world) {
    return world == nullptr ? 0 : world->implementation.tick_index();
}

size_t cybersand_world_chunk_count(const cybersand_world* world) {
    return world == nullptr ? 0 : world->implementation.chunk_count();
}

int cybersand_material_get_info_v2(uint16_t material,
                                   cybersand_material_info_v2* destination) {
    if (destination == nullptr || !cybersand::MaterialRules::is_valid(material)) return 0;
    const auto& definition =
        cybersand::MaterialRules::descriptor(static_cast<cybersand::Material>(material));
    fill_material_info(material, definition, destination->base);
    destination->rule_kernel = static_cast<uint8_t>(definition.kernel);
    destination->initial_state_a = definition.initial_state_a;
    destination->initial_state_b = definition.initial_state_b;
    destination->maximum_write_radius = definition.maximum_write_radius;
    return 1;
}

int cybersand_material_get_info_v3(uint16_t material,
                                   cybersand_material_info_v3* destination) {
    if (destination == nullptr || !cybersand::MaterialRules::is_valid(material)) return 0;
    const auto& definition =
        cybersand::MaterialRules::descriptor(static_cast<cybersand::Material>(material));
    fill_material_info(material, definition, destination->base.base);
    destination->base.rule_kernel = static_cast<uint8_t>(definition.kernel);
    destination->base.initial_state_a = definition.initial_state_a;
    destination->base.initial_state_b = definition.initial_state_b;
    destination->base.maximum_write_radius = definition.maximum_write_radius;
    destination->density_motion = static_cast<uint8_t>(definition.density_motion);
    destination->accepts_density_exchange = definition.accepts_density_exchange ? 1 : 0;
    destination->lateral_flow_mode = static_cast<uint8_t>(definition.lateral_flow);
    destination->reserved_0 = 0;
    return 1;
}

int cybersand_material_get_info_v4(uint16_t material,
                                   cybersand_material_info_v4* destination) {
    if (destination == nullptr || !cybersand::MaterialRules::is_valid(material)) return 0;
    if (!cybersand_material_get_info_v3(material, &destination->base)) return 0;
    const auto& definition =
        cybersand::MaterialRules::descriptor(static_cast<cybersand::Material>(material));
    destination->viscosity_index = definition.viscosity_index;
    for (auto& value : destination->reserved) value = 0;
    return 1;
}

int cybersand_world_copy_render_cells(const cybersand_world* world, int64_t x, int64_t y,
                                      int64_t width, int64_t height, uint8_t* destination,
                                      size_t destination_size, size_t stride_bytes) {
    if (world == nullptr || destination == nullptr) return 0;
    try {
        world->implementation.copy_render_cells(
            {x, y, width, height},
            std::span<std::uint8_t>(destination, destination_size), stride_bytes);
        return 1;
    } catch (...) {
        return 0;
    }
}

size_t cybersand_world_take_dirty_chunks(cybersand_world* world,
                                         cybersand_dirty_chunk* destination,
                                         size_t capacity) {
    if (world == nullptr) return CYBERSAND_SIZE_ERROR;
    try {
        const auto required = world->implementation.dirty_chunk_count();
        if (destination == nullptr || capacity < required) return required;
        const auto dirty = world->implementation.take_dirty_chunks();
        for (std::size_t index = 0; index < dirty.size(); ++index) {
            destination[index] = {
                dirty[index].chunk.x,
                dirty[index].chunk.y,
                dirty[index].local_rect.x,
                dirty[index].local_rect.y,
                dirty[index].local_rect.width,
                dirty[index].local_rect.height,
            };
        }
        return dirty.size();
    } catch (...) {
        return CYBERSAND_SIZE_ERROR;
    }
}

cybersand_render_exchange* cybersand_render_exchange_create(
    size_t slot_count, size_t patch_capacity_per_slot, size_t byte_capacity_per_slot) {
    try {
        return new cybersand_render_exchange(slot_count, patch_capacity_per_slot,
                                              byte_capacity_per_slot);
    } catch (...) {
        return nullptr;
    }
}

void cybersand_render_exchange_destroy(cybersand_render_exchange* exchange) {
    delete exchange;
}

int cybersand_world_publish_render_snapshot(
    cybersand_world* world, cybersand_render_exchange* exchange,
    cybersand_render_publish_result* destination) {
    if (world == nullptr || exchange == nullptr || destination == nullptr) return 0;
    try {
        const auto result = exchange->implementation->publish(world->implementation);
        *destination = {};
        destination->status = static_cast<uint8_t>(result.status);
        destination->snapshot_serial = result.snapshot_serial;
        destination->required_patches = result.required_patches;
        destination->required_bytes = result.required_bytes;
        return 1;
    } catch (...) {
        *destination = {};
        return 0;
    }
}

cybersand_render_lease* cybersand_render_exchange_acquire_latest(
    cybersand_render_exchange* exchange, uint64_t after_serial) {
    if (exchange == nullptr) return nullptr;
    try {
        auto lease = exchange->implementation->acquire_latest(after_serial);
        if (!lease.has_value()) return nullptr;
        return new cybersand_render_lease(exchange->implementation, std::move(*lease));
    } catch (...) {
        return nullptr;
    }
}

void cybersand_render_lease_destroy(cybersand_render_lease* lease) { delete lease; }

uint64_t cybersand_render_lease_serial(const cybersand_render_lease* lease) {
    return lease == nullptr ? 0 : lease->implementation.serial();
}

uint64_t cybersand_render_lease_tick(const cybersand_render_lease* lease) {
    return lease == nullptr ? 0 : lease->implementation.tick();
}

size_t cybersand_render_lease_patch_count(const cybersand_render_lease* lease) {
    return lease == nullptr ? 0 : lease->implementation.patches().size();
}

size_t cybersand_render_lease_byte_count(const cybersand_render_lease* lease) {
    return lease == nullptr ? 0 : lease->implementation.cells().size();
}

int cybersand_render_lease_get_patch(const cybersand_render_lease* lease, size_t index,
                                     cybersand_render_patch* destination) {
    if (lease == nullptr || destination == nullptr) return 0;
    const auto patches = lease->implementation.patches();
    if (index >= patches.size()) return 0;
    const auto& patch = patches[index];
    *destination = {
        patch.world_rect.x,
        patch.world_rect.y,
        patch.world_rect.width,
        patch.world_rect.height,
        patch.data_offset,
        patch.stride_bytes,
    };
    return 1;
}

const uint8_t* cybersand_render_lease_cells(const cybersand_render_lease* lease,
                                            size_t* byte_count) {
    if (byte_count != nullptr) *byte_count = 0;
    if (lease == nullptr) return nullptr;
    const auto cells = lease->implementation.cells();
    if (byte_count != nullptr) *byte_count = cells.size();
    return cells.data();
}

size_t cybersand_render_exchange_patch_high_water(
    const cybersand_render_exchange* exchange) {
    return exchange == nullptr ? 0 : exchange->implementation->patch_high_water();
}

size_t cybersand_render_exchange_byte_high_water(
    const cybersand_render_exchange* exchange) {
    return exchange == nullptr ? 0 : exchange->implementation->byte_high_water();
}

uint64_t cybersand_render_exchange_backpressure_count(
    const cybersand_render_exchange* exchange) {
    return exchange == nullptr ? 0 : exchange->implementation->backpressure_count();
}

uint64_t cybersand_render_exchange_capacity_failure_count(
    const cybersand_render_exchange* exchange) {
    return exchange == nullptr ? 0 : exchange->implementation->capacity_failure_count();
}

}  // extern "C"
