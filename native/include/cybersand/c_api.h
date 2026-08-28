#pragma once

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#  if defined(CYBERSAND_BUILD_SHARED)
#    define CYBERSAND_API __declspec(dllexport)
#  elif defined(CYBERSAND_USE_SHARED)
#    define CYBERSAND_API __declspec(dllimport)
#  else
#    define CYBERSAND_API
#  endif
#else
#  define CYBERSAND_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct cybersand_world cybersand_world;
typedef struct cybersand_render_exchange cybersand_render_exchange;
typedef struct cybersand_render_lease cybersand_render_lease;

typedef struct cybersand_config {
    int32_t chunk_size;
    uint32_t sleep_after_quiet_ticks;
    int16_t ambient_temperature;
} cybersand_config;

typedef struct cybersand_tick_stats {
    uint64_t tick;
    uint64_t visited_cells;
    uint64_t moved_cells;
    uint64_t active_chunks_before;
    uint64_t active_chunks_after;
    uint64_t dirty_chunks;
} cybersand_tick_stats;

typedef struct cybersand_material_info {
    uint16_t id;
    uint8_t state;
    uint16_t density;
    uint8_t rgba[4];
    uint8_t movable;
    uint8_t current_rule_available;
} cybersand_material_info;

typedef enum cybersand_backend {
    CYBERSAND_BACKEND_SERIAL_IN_PLACE = 0,
    CYBERSAND_BACKEND_PHASED_IN_PLACE = 1,
    CYBERSAND_BACKEND_BUFFERED = 2
} cybersand_backend;

#define CYBERSAND_CONFIG_V2_ABI_VERSION 2u
#define CYBERSAND_SIZE_ERROR ((size_t)-1)

typedef struct cybersand_config_v2 {
    uint32_t struct_size;
    uint32_t abi_version;
    int32_t chunk_size;
    uint32_t sleep_after_quiet_ticks;
    int16_t ambient_temperature;
    uint8_t backend;
    uint8_t reserved_0;
    int32_t activity_block_size;
    int32_t scheduling_core_size;
    int32_t maximum_rule_radius;
    uint32_t worker_threads;
    uint64_t initial_chunk_reserve;
    uint64_t parallel_job_threshold;
    uint64_t active_core_capacity;
    uint64_t active_chunk_capacity;
    uint64_t maximum_chunk_count;
    uint64_t deferred_event_capacity;
    int32_t maximum_explosion_radius;
} cybersand_config_v2;

typedef struct cybersand_tick_stats_v2 {
    uint64_t tick;
    uint64_t visited_cells;
    uint64_t moved_cells;
    uint64_t active_chunks_before;
    uint64_t active_chunks_after;
    uint64_t dirty_chunks;
    uint64_t scheduled_cores;
    uint64_t phase_jobs[4];
    uint64_t chunk_allocations;
    uint64_t temperature_field_allocations;
    uint64_t deferred_events;
} cybersand_tick_stats_v2;

typedef struct cybersand_material_info_v2 {
    cybersand_material_info base;
    uint8_t rule_kernel;
    uint8_t initial_state_a;
    uint8_t initial_state_b;
    uint8_t maximum_write_radius;
} cybersand_material_info_v2;

typedef enum cybersand_density_motion {
    CYBERSAND_DENSITY_MOTION_NONE = 0,
    CYBERSAND_DENSITY_MOTION_DOWN = 1,
    CYBERSAND_DENSITY_MOTION_UP = 2
} cybersand_density_motion;

typedef enum cybersand_lateral_flow_mode {
    CYBERSAND_LATERAL_FLOW_NONE = 0,
    CYBERSAND_LATERAL_FLOW_FREE_MASS = 1,
    CYBERSAND_LATERAL_FLOW_CELLULAR_YIELD = 2
} cybersand_lateral_flow_mode;

typedef struct cybersand_material_info_v3 {
    cybersand_material_info_v2 base;
    uint8_t density_motion;
    uint8_t accepts_density_exchange;
    uint8_t lateral_flow_mode;
    uint8_t reserved_0;
} cybersand_material_info_v3;

typedef struct cybersand_material_info_v4 {
    cybersand_material_info_v3 base;
    uint8_t viscosity_index;
    uint8_t reserved[3];
} cybersand_material_info_v4;

typedef struct cybersand_dirty_chunk {
    int64_t chunk_x;
    int64_t chunk_y;
    int64_t local_x;
    int64_t local_y;
    int64_t width;
    int64_t height;
} cybersand_dirty_chunk;

typedef enum cybersand_render_publish_status {
    CYBERSAND_RENDER_NO_CHANGES = 0,
    CYBERSAND_RENDER_PUBLISHED = 1,
    CYBERSAND_RENDER_BACKPRESSURE = 2,
    CYBERSAND_RENDER_CAPACITY_EXCEEDED = 3
} cybersand_render_publish_status;

typedef struct cybersand_render_publish_result {
    uint8_t status;
    uint8_t reserved[7];
    uint64_t snapshot_serial;
    size_t required_patches;
    size_t required_bytes;
} cybersand_render_publish_result;

typedef struct cybersand_render_patch {
    int64_t x;
    int64_t y;
    int64_t width;
    int64_t height;
    size_t data_offset;
    size_t stride_bytes;
} cybersand_render_patch;

CYBERSAND_API cybersand_world* cybersand_world_create(cybersand_config config);
CYBERSAND_API void cybersand_world_destroy(cybersand_world* world);
CYBERSAND_API uint16_t cybersand_world_get(const cybersand_world* world, int64_t x, int64_t y);
CYBERSAND_API void cybersand_world_set(cybersand_world* world, int64_t x, int64_t y, uint16_t material);
CYBERSAND_API cybersand_tick_stats cybersand_world_tick(cybersand_world* world);
CYBERSAND_API uint64_t cybersand_world_hash(const cybersand_world* world);
CYBERSAND_API size_t cybersand_world_resident_cell_bytes(const cybersand_world* world);
CYBERSAND_API int cybersand_material_get_info(uint16_t material, cybersand_material_info* destination);
CYBERSAND_API int cybersand_world_copy_rgba(const cybersand_world* world, int64_t x, int64_t y,
                                             int64_t width, int64_t height, uint8_t* destination,
                                             size_t destination_size, size_t stride_bytes);

CYBERSAND_API cybersand_config_v2 cybersand_default_config_v2(void);
CYBERSAND_API cybersand_world* cybersand_world_create_v2(const cybersand_config_v2* config);
CYBERSAND_API int cybersand_world_set_v2(cybersand_world* world, int64_t x, int64_t y,
                                         uint16_t material);
CYBERSAND_API int cybersand_world_tick_v2(cybersand_world* world,
                                          cybersand_tick_stats_v2* destination);
CYBERSAND_API int cybersand_world_reserve_region(cybersand_world* world, int64_t x, int64_t y,
                                                  int64_t width, int64_t height);
CYBERSAND_API int cybersand_world_reserve_temperature_region(cybersand_world* world, int64_t x,
                                                              int64_t y, int64_t width,
                                                              int64_t height);
CYBERSAND_API int cybersand_world_queue_explosion(cybersand_world* world, int64_t x,
                                                   int64_t y, int32_t radius,
                                                   uint8_t collapse_strength);
CYBERSAND_API uint8_t cybersand_world_liquid_mass(const cybersand_world* world, int64_t x,
                                                   int64_t y);
CYBERSAND_API uint64_t cybersand_world_content_hash(const cybersand_world* world);
CYBERSAND_API uint64_t cybersand_world_tick_index(const cybersand_world* world);
CYBERSAND_API size_t cybersand_world_chunk_count(const cybersand_world* world);
CYBERSAND_API int cybersand_material_get_info_v2(uint16_t material,
                                                  cybersand_material_info_v2* destination);
CYBERSAND_API int cybersand_material_get_info_v3(uint16_t material,
                                                  cybersand_material_info_v3* destination);
CYBERSAND_API int cybersand_material_get_info_v4(uint16_t material,
                                                  cybersand_material_info_v4* destination);
CYBERSAND_API int cybersand_world_copy_render_cells(const cybersand_world* world, int64_t x,
                                                     int64_t y, int64_t width, int64_t height,
                                                     uint8_t* destination,
                                                     size_t destination_size,
                                                     size_t stride_bytes);
/* With destination == NULL or insufficient capacity, returns the required
 * count without clearing dirty state. Returns CYBERSAND_SIZE_ERROR on failure. */
CYBERSAND_API size_t cybersand_world_take_dirty_chunks(cybersand_world* world,
                                                        cybersand_dirty_chunk* destination,
                                                        size_t capacity);

CYBERSAND_API cybersand_render_exchange* cybersand_render_exchange_create(
    size_t slot_count, size_t patch_capacity_per_slot, size_t byte_capacity_per_slot);
CYBERSAND_API void cybersand_render_exchange_destroy(cybersand_render_exchange* exchange);
/* The caller must serialize publication with World mutation/ticking. A
 * successful call returns 1 and reports whether a snapshot was published,
 * retained for backpressure, or rejected for configured capacity. */
CYBERSAND_API int cybersand_world_publish_render_snapshot(
    cybersand_world* world, cybersand_render_exchange* exchange,
    cybersand_render_publish_result* destination);
CYBERSAND_API cybersand_render_lease* cybersand_render_exchange_acquire_latest(
    cybersand_render_exchange* exchange, uint64_t after_serial);
CYBERSAND_API void cybersand_render_lease_destroy(cybersand_render_lease* lease);
CYBERSAND_API uint64_t cybersand_render_lease_serial(const cybersand_render_lease* lease);
CYBERSAND_API uint64_t cybersand_render_lease_tick(const cybersand_render_lease* lease);
CYBERSAND_API size_t cybersand_render_lease_patch_count(const cybersand_render_lease* lease);
CYBERSAND_API size_t cybersand_render_lease_byte_count(const cybersand_render_lease* lease);
CYBERSAND_API int cybersand_render_lease_get_patch(const cybersand_render_lease* lease,
                                                   size_t index,
                                                   cybersand_render_patch* destination);
/* Returned bytes are immutable and remain valid until the lease is destroyed. */
CYBERSAND_API const uint8_t* cybersand_render_lease_cells(
    const cybersand_render_lease* lease, size_t* byte_count);
CYBERSAND_API size_t cybersand_render_exchange_patch_high_water(
    const cybersand_render_exchange* exchange);
CYBERSAND_API size_t cybersand_render_exchange_byte_high_water(
    const cybersand_render_exchange* exchange);
CYBERSAND_API uint64_t cybersand_render_exchange_backpressure_count(
    const cybersand_render_exchange* exchange);
CYBERSAND_API uint64_t cybersand_render_exchange_capacity_failure_count(
    const cybersand_render_exchange* exchange);

#ifdef __cplusplus
}
#endif
