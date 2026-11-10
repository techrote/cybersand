// BS-001 ballistic_solids_v1: exact grid -> flying solid -> grid cell
// ownership, admission, swept contacts, liquid-surface landing, body impulse,
// persistence and worker parity.
#include "cybersand/world.hpp"

#include <array>
#include <cstdint>
#include <stdexcept>
#include <string>

namespace {
using namespace cybersand;
constexpr std::int64_t Q = BallisticWaterConfig::kQ;

void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}

std::int64_t centre(std::int64_t cell) { return cell * Q + Q / 2; }

WorldConfig solids_config(std::uint32_t workers = 1, std::uint32_t capacity = 256) {
    WorldConfig out;
    out.worker_threads = workers;
    out.parallel_job_threshold = 1;
    out.ballistic_water.enabled = true;
    out.ballistic_solids.enabled = true;
    out.ballistic_solids.capacity = capacity;
    return out;
}

void rect(World& world, std::int64_t x, std::int64_t y, std::int64_t w, std::int64_t h, Material m) {
    for (auto yy = y; yy < y + h; ++yy)
        for (auto xx = x; xx < x + w; ++xx) world.set(xx, yy, m);
}

void box(World& world, std::int64_t w, std::int64_t h) {
    rect(world, 0, h - 1, w, 1, Material::Wall);
    rect(world, 0, 0, 1, h, Material::Wall);
    rect(world, w - 1, 0, 1, h, Material::Wall);
    rect(world, 0, 0, w, 1, Material::Wall);
    world.reserve_region({-8, -8, w + 16, h + 16});
}

std::uint64_t count(const World& world, Material m, std::int64_t w, std::int64_t h) {
    std::uint64_t n = 0;
    for (std::int64_t y = 0; y < h; ++y)
        for (std::int64_t x = 0; x < w; ++x) n += world.stored_material(x, y) == m ? 1U : 0U;
    return n;
}

void closes(const World& world, const std::string& where) {
    (void)world.save_physical_state(); // runs the complete quantity and solids validators
    const auto s = world.ballistic_solids_snapshot();
    require(s.ledger.launched + s.ledger.injected == s.ledger.landed + s.live, where + ": cell ledger identity");
}

} // namespace

void test_ballistic_solids_admission_and_defaults() {
    // Disabled: refused, and a ballistic-Water World without solids keeps its version.
    WorldConfig water_only;
    water_only.ballistic_water.enabled = true;
    World plain(water_only);
    plain.set(4, 4, Material::Sand);
    require(plain.launch_ballistic_solid(4, 4, centre(4), centre(2), 0, -400).outcome == BallisticLaunchOutcome::Disabled &&
            plain.stored_material(4, 4) == Material::Sand, "disabled solids launch mutated authority");
    require(plain.physical_state_hash_version() == 4U && plain.physical_state_format_version() == 4U,
            "solids changed a ballistic-Water World's versions");
    // Solids need ballistic Water and an admitted envelope.
    WorldConfig orphan;
    orphan.ballistic_solids.enabled = true;
    bool threw = false;
    try { World refused(orphan); } catch (const std::invalid_argument&) { threw = true; }
    require(threw, "solids admitted without ballistic Water");
    auto bad = solids_config();
    bad.ballistic_solids.max_speed_q = 1;
    threw = false;
    try { World refused(bad); } catch (const std::invalid_argument&) { threw = true; }
    require(threw, "invalid solids configuration admitted");
    // Material admission: powders and breakable solids fly; liquids and walls never.
    require(ballistic_solid_admitted(Material::Sand) && ballistic_solid_admitted(Material::Stone) &&
            !ballistic_solid_admitted(Material::Water) && !ballistic_solid_admitted(Material::Wall) &&
            !ballistic_solid_admitted(Material::ReinforcedConcrete) && !ballistic_solid_admitted(Material::Empty),
            "solid admission set");
    World world(solids_config(1, 2));
    box(world, 32, 32);
    world.set(5, 20, Material::Water);
    require(world.launch_ballistic_solid(5, 20, centre(5), centre(18), 0, -200).outcome ==
            BallisticLaunchOutcome::NotAdmitted && world.stored_material(5, 20) == Material::Water, "Water launched as a solid");
    require(world.inject_ballistic_solid(centre(10), centre(10), 0, 0, Material::Wall).outcome ==
            BallisticLaunchOutcome::NotAdmitted, "a wall was injected");
    require(world.inject_ballistic_solid(centre(10), centre(10), 0, 0, Material::Sand).outcome == BallisticLaunchOutcome::Launched &&
            world.inject_ballistic_solid(centre(12), centre(10), 0, 0, Material::Sand).outcome == BallisticLaunchOutcome::Launched,
            "injection refused");
    require(world.inject_ballistic_solid(centre(14), centre(10), 0, 0, Material::Sand).outcome == BallisticLaunchOutcome::CapacityFull &&
            world.ballistic_solids_snapshot().ledger.refused_launches == 1U, "capacity not enforced");
    require(world.inject_ballistic_solid(centre(0), centre(10), 0, 0, Material::Sand).outcome != BallisticLaunchOutcome::Launched,
            "spawn inside a wall admitted");
    closes(world, "admission");
}

void test_ballistic_solids_arc_and_landing() {
    World world(solids_config());
    box(world, 96, 64);
    rect(world, 10, 50, 3, 1, Material::Sand);
    const auto sand = count(world, Material::Sand, 96, 64);
    // Launch the middle cell up and right; it lands as the same Sand cell.
    require(world.launch_ballistic_solid(11, 50, centre(11), centre(48), 700, -900).outcome == BallisticLaunchOutcome::Launched,
            "launch refused");
    require(world.stored_material(11, 50) == Material::Empty, "launch left the source cell");
    std::int64_t top = 64;
    for (int t = 0; t < 400 && world.ballistic_solid_count() != 0U; ++t) {
        (void)world.tick();
        std::array<BallisticSolid, 1> out{};
        if (world.copy_ballistic_solids(out) == 1U) top = std::min(top, out[0].y / Q);
        require(count(world, Material::Sand, 96, 64) + world.ballistic_solid_count() == sand, "Sand cells not conserved");
    }
    require(world.ballistic_solid_count() == 0U && top < 48, "the solid did not rise and land");
    require(count(world, Material::Sand, 96, 64) == sand, "landing lost the cell");
    closes(world, "arc");
}

void test_ballistic_solids_liquid_surface_landing() {
    World world(solids_config());
    box(world, 48, 48);
    rect(world, 1, 30, 46, 17, Material::Water);
    world.set(24, 6, Material::Sand);
    require(world.launch_ballistic_solid(24, 6, centre(24), centre(8), 0, 600).outcome == BallisticLaunchOutcome::Launched,
            "launch refused");
    for (int t = 0; t < 120 && world.ballistic_solid_count() != 0U; ++t) (void)world.tick();
    const auto s = world.ballistic_solids_snapshot();
    require(s.ledger.liquid_contacts == 1U && s.ledger.surface_landings == 1U, "the solid did not settle on the surface");
    // Native density exchange then sinks the Sand below the surface.
    for (int t = 0; t < 200; ++t) (void)world.tick();
    std::int64_t deepest = 0;
    for (std::int64_t y = 0; y < 48; ++y)
        for (std::int64_t x = 0; x < 48; ++x)
            if (world.stored_material(x, y) == Material::Sand) deepest = std::max(deepest, y);
    require(deepest > 30, "the landed Sand did not sink into the Water");
    closes(world, "surface");
}

void test_ballistic_solids_body_contact() {
    World world(solids_config());
    box(world, 40, 40);
    world.set(10, 30, Material::Stone);
    world.configure_transient_obstacles({0, 0, 40, 40});
    for (std::int64_t y = 10; y < 30; ++y)
        for (std::int64_t x = 20; x < 24; ++x) require(world.set_transient_obstacle(x, y, 3), "body mask");
    require(world.launch_ballistic_solid(10, 30, centre(10), centre(25), 1200, -200).outcome == BallisticLaunchOutcome::Launched,
            "body launch refused");
    std::int64_t delivered = 0;
    for (int t = 0; t < 200 && world.ballistic_solid_count() != 0U; ++t) {
        (void)world.tick();
        delivered += world.transient_ballistic_impulse_x(3);
        std::array<BallisticSolid, 1> p{};
        if (world.copy_ballistic_solids(p) == 1U) require(p[0].x / Q < 20, "solid entered the body");
        world.clear_transient_contact_observations();
    }
    const auto s = world.ballistic_solids_snapshot();
    require(s.ledger.body_contacts > 0U && delivered > 0 && delivered == -s.ledger.body_px,
            "body did not receive exactly the solid's momentum change");
    world.clear_transient_obstacles();
    closes(world, "body");
}

void test_ballistic_solids_persistence_and_parity() {
    std::array<std::uint64_t, 2> hashes{};
    for (std::size_t run = 0; run < 2; ++run) {
        World world(solids_config(run == 0 ? 1U : 4U));
        box(world, 64, 64);
        rect(world, 1, 50, 62, 13, Material::Sand);
        for (std::int64_t x = 4; x < 60; x += 2)
            (void)world.launch_ballistic_solid(x, 50, centre(x), centre(47), static_cast<std::int32_t>((x % 5 - 2) * 150),
                                              static_cast<std::int32_t>(-700 - (x % 7) * 40));
        for (int t = 0; t < 9; ++t) (void)world.tick();
        require(world.ballistic_solid_count() > 0U, "no solid in flight");
        const auto bytes = world.save_physical_state();
        auto restored = World::restore_physical_state(world.config(), bytes);
        require(restored->physical_state_hash() == world.physical_state_hash(), "CYPS restore changed solids state");
        for (int t = 0; t < 150; ++t) {
            (void)world.tick();
            (void)restored->tick();
        }
        require(restored->physical_state_hash() == world.physical_state_hash(), "restored solids diverged");
        hashes[run] = world.physical_state_hash();
        world.clear();
        require(world.ballistic_solid_count() == 0U && world.ballistic_solids_snapshot().ledger == BallisticSolidsLedger{},
                "clear() left ballistic solids");
    }
    require(hashes[0] == hashes[1], "1/4-worker ballistic solids results differ");
}

void test_ballistic_solids_render_overlay() {
    World world(solids_config());
    box(world, 32, 32);
    require(world.inject_ballistic_solid(centre(10), centre(8), 0, 0, Material::Sand).outcome == BallisticLaunchOutcome::Launched,
            "inject refused");
    std::array<std::uint8_t, 32 * 32> cells{};
    world.copy_material_cells({0, 0, 32, 32}, cells, 32);
    require(cells[8 * 32 + 10] == static_cast<std::uint8_t>(Material::Sand), "flying solid not presented");
    require(world.stored_material(10, 8) == Material::Empty, "presentation wrote authority");
}

void test_ballistic_solids_buried_climb() {
    World world(solids_config());
    box(world, 32, 48);
    require(world.inject_ballistic_solid(centre(10), centre(30), 0, 0, Material::Stone).outcome ==
            BallisticLaunchOutcome::Launched, "inject refused");
    rect(world, 5, 26, 11, 21, Material::Sand); // bury the resting solid in Sand
    const auto sand = count(world, Material::Sand, 32, 48);
    for (int t = 0; t < 40 && world.ballistic_solid_count() != 0U; ++t) (void)world.tick();
    require(world.ballistic_solid_count() == 0U, "the buried solid never landed");
    require(count(world, Material::Stone, 32, 48) == 1U && count(world, Material::Sand, 32, 48) == sand,
            "buried landing changed the cell populations");
    std::int64_t stone_y = 0;
    for (std::int64_t y = 0; y < 48; ++y)
        for (std::int64_t x = 0; x < 32; ++x)
            if (world.stored_material(x, y) == Material::Stone) stone_y = y;
    require(stone_y < 30, "the buried solid did not climb to free space");
    closes(world, "buried");
}

void test_ballistic_solids_launch_in_place() {
    World world(solids_config());
    box(world, 48, 48);
    rect(world, 10, 30, 12, 17, Material::Sand);    // a solid pile: interior cells have no free neighbour
    rect(world, 26, 30, 12, 17, Material::Water);   // a full pool
    const auto sand = count(world, Material::Sand, 48, 48);
    const auto water = world.water_quantity({0, 0, 48, 48});
    require(world.launch_ballistic_solid(15, 40, centre(15), centre(40), 0, -900).outcome == BallisticLaunchOutcome::Launched,
            "interior solid launch from its own cell refused");
    require(world.launch_ballistic_water(31, 40, centre(31), centre(40), 0, -900).outcome == BallisticLaunchOutcome::Launched,
            "interior Water launch from its own cell refused");
    require(world.launch_ballistic_solid(15, 39, centre(16), centre(39), 0, -900).outcome == BallisticLaunchOutcome::InvalidRequest,
            "spawn in a foreign occupied cell admitted");
    for (int t = 0; t < 300 && (world.ballistic_solid_count() != 0U || world.ballistic_parcel_count() != 0U); ++t) (void)world.tick();
    require(count(world, Material::Sand, 48, 48) + world.ballistic_solid_count() == sand, "interior launch lost Sand");
    require(world.water_quantity({0, 0, 48, 48}) + world.ballistic_water_snapshot().in_flight_quantity == water,
            "interior launch lost Water");
    closes(world, "in place");
}
