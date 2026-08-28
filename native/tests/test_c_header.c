#include "cybersand/c_api.h"

int main(void) {
    const cybersand_config config = {128, 3, 200};
    cybersand_world* world = cybersand_world_create(config);
    if (world == NULL) return 1;
    cybersand_material_info material_info = {0};
    if (!cybersand_material_get_info(2, &material_info)) return 2;
    cybersand_world_set(world, 0, 0, 2);
    (void)cybersand_world_tick(world);
    cybersand_world_destroy(world);

    cybersand_config_v2 config_v2 = cybersand_default_config_v2();
    config_v2.worker_threads = 2;
    cybersand_world* world_v2 = cybersand_world_create_v2(&config_v2);
    if (world_v2 == NULL) return 3;
    if (!cybersand_world_queue_explosion(world_v2, 0, 0, 2, 255)) return 4;
    cybersand_tick_stats_v2 stats_v2 = {0};
    if (!cybersand_world_tick_v2(world_v2, &stats_v2)) return 5;
    if (stats_v2.deferred_events != 1) return 6;
    if (!cybersand_world_set_v2(world_v2, 3, 3, 2)) return 7;
    cybersand_render_exchange* exchange = cybersand_render_exchange_create(2, 8, 128);
    if (exchange == NULL) return 8;
    cybersand_render_publish_result publish_result = {0};
    if (!cybersand_world_publish_render_snapshot(world_v2, exchange, &publish_result)) return 9;
    if (publish_result.status != CYBERSAND_RENDER_PUBLISHED) return 10;
    cybersand_render_lease* lease = cybersand_render_exchange_acquire_latest(exchange, 0);
    if (lease == NULL || cybersand_render_lease_patch_count(lease) == 0) return 11;
    cybersand_render_lease_destroy(lease);
    cybersand_render_exchange_destroy(exchange);
    cybersand_material_info_v3 material_v3 = {0};
    if (!cybersand_material_get_info_v3(4, &material_v3)) return 12;
    if (material_v3.density_motion != CYBERSAND_DENSITY_MOTION_UP) return 13;
    cybersand_material_info_v4 material_v4 = {0};
    if (!cybersand_material_get_info_v4(3, &material_v4)) return 14;
    if (material_v4.viscosity_index != 0) return 15;
    cybersand_world_destroy(world_v2);
    return 0;
}
