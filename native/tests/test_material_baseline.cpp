#include "cybersand/material_baseline.hpp"

#include <array>
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace cybersand {
class PrecisionProbe {
public:
    static void set_tick_in_progress(World& world, bool active) {
        world.tick_in_progress_ = active;
    }
};
}

namespace {
using namespace cybersand;

void require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}

template<class F> void refuses(F&& operation, const char* message) {
    bool refused = false;
    try { operation(); } catch (const std::exception&) { refused = true; }
    require(refused, message);
}

void complete_stored_identity_and_const_capture() {
    World world;
    world.reserve_region({0, 0, 512, 512});
    for (std::uint16_t id = 0; id <= static_cast<std::uint16_t>(kLastMaterial); ++id)
        if (valid_material(id)) world.set(id, 3, static_cast<Material>(id));
    world.set(511, 0, Material::HeatShieldTile);
    world.set(0, 1, Material::Empty);
    world.set(511, 511, Material::PolymerPanel);
    require(world.set_cell_state(19, 19, Material::Water, 1, 2), "fractional Water fixture");
    world.set_temperature(19, 19, 217);
    world.configure_transient_obstacles({0, 0, 512, 512});
    require(world.set_transient_obstacle(19, 19, 1), "masked stored Water fixture");
    require(world.get(19, 19) == Material::Wall, "mask must differ from stored material");
    const auto physical = world.physical_state_hash();
    const auto revision = world.hard_surface_revision();
    const auto chunks = world.chunk_count();
    const auto tick = world.tick_index();
    std::vector<std::uint8_t> bytes(material_baseline::byte_count(512, 512));
    material_baseline::copy(world, bytes, 512, 512);
    material_baseline::validate(bytes, 512, 512);
    require(bytes.size() == 524288U, "two bytes per complete cell plane");
    for (int y = 0; y < 512; ++y) for (int x = 0; x < 512; ++x) {
        const auto offset = (static_cast<std::size_t>(y) * 512U + static_cast<std::size_t>(x)) * 2U;
        require(bytes[offset] == static_cast<std::uint8_t>(world.stored_material(x, y)) && bytes[offset+1] == 0,
            "literal row-major LE16 oracle, including Empty and catalogue tail");
    }
    require(material_baseline::decode(bytes, 19U * 512U + 19U) == static_cast<std::uint16_t>(Material::Water),
        "stored Water must survive body masks and fractional render coverage");
    require(world.physical_state_hash() == physical && world.hard_surface_revision() == revision &&
        world.chunk_count() == chunks && world.tick_index() == tick && world.transient_obstacle_at(19, 19) == 1 &&
        world.stored_state_a(19, 19) == 1 && world.stored_state_b(19, 19) == 2 && world.stored_temperature(19, 19) == 217,
        "material capture must preserve tick, physics, thermal lanes, mask, activity and allocations");
    bytes[0] = 131;
    require(world.stored_material(0, 0) == Material::Empty, "owned output must not alias World storage");
}

void invalid_inputs_never_write_or_change_world() {
    World world;
    world.set(8, 8, Material::Copper);
    const auto before = world.physical_state_hash();
    std::vector<std::uint8_t> bytes(material_baseline::byte_count(512, 512), 0);
    for (const auto dimensions : std::array<std::array<std::int32_t,2>,7>{{
        {{0,512}}, {{512,0}}, {{-1,512}}, {{255,512}}, {{512,257}}, {{2112,512}}, {{512,2147483647}}}})
        refuses([&]{ (void)material_baseline::byte_count(dimensions[0], dimensions[1]); }, "invalid dimension accepted");
    refuses([&]{ (void)material_baseline::byte_count(2048, 2048, 8388607); }, "staging capacity must refuse before allocation");
    for (const auto bad : {10U,132U,256U,65535U}) {
        bytes[bytes.size()-2] = static_cast<std::uint8_t>(bad & 255U);
        bytes.back() = static_cast<std::uint8_t>(bad >> 8U);
        refuses([&]{ material_baseline::validate(bytes, 512, 512); }, "invalid wide material ID was narrowed or admitted");
    }
    bytes.assign(bytes.size(), 0);
    bytes.pop_back();
    refuses([&]{ material_baseline::validate(bytes, 512, 512); }, "truncated payload accepted");
    refuses([&]{ material_baseline::copy(world, bytes, 512, 512); }, "short capture buffer accepted");
    require(bytes.front() == 0 && bytes.back() == 0, "invalid capture buffer must not be partially written");
    bytes.resize(material_baseline::byte_count(512, 512)+1, 0);
    refuses([&]{ material_baseline::validate(bytes, 512, 512); }, "oversized payload accepted");
    bytes.resize(material_baseline::byte_count(512, 512));
    PrecisionProbe::set_tick_in_progress(world, true);
    refuses([&]{ material_baseline::copy(world, bytes, 512, 512); }, "in-progress tick capture accepted");
    PrecisionProbe::set_tick_in_progress(world, false);
    require(world.physical_state_hash() == before, "validation failures changed World authority");
    world.quarantine_external_coupling();
    refuses([&]{ material_baseline::copy(world, bytes, 512, 512); }, "failed World capture accepted");
}

void simulation_derived_identity() {
    World world;
    for (int y = 7; y <= 9; ++y) for (int x = 7; x <= 10; ++x) world.set(x, y, Material::Wall);
    world.set(8, 8, Material::Ice);
    world.set(9, 8, Material::Water);
    std::vector<std::uint8_t> initial(material_baseline::byte_count(512, 512));
    material_baseline::copy(world, initial, 512, 512);
    for (int tick = 0; tick < 512 && world.stored_material(9, 8) != Material::Ice; ++tick) (void)world.tick();
    require(world.stored_material(9, 8) == Material::Ice && world.completed_tick_index() > 0,
        "actual native simulation must transform Water into Ice");
    const auto hash = world.physical_state_hash();
    const auto tick = world.tick_index();
    std::vector<std::uint8_t> captured(initial.size());
    material_baseline::copy(world, captured, 512, 512);
    require(captured != initial && material_baseline::decode(captured, 8U*512U+9U) == static_cast<std::uint16_t>(Material::Ice),
        "capture must contain evolved stored IDs, not construction recipe");
    require(world.physical_state_hash() == hash && world.tick_index() == tick,
        "simulation-derived capture reset or modified physical state");
    (void)world.tick();
    require(world.completed_tick_index() == tick + 1, "same live World must continue ticking");
}

void supported_full_planes() {
    for (const int side : {512,1024,2048}) {
        World world;
        world.reserve_region({0, 0, side, side});
        world.set(side-1, 0, Material::HeatShieldTile);
        world.set(0, 1, Material::Water);
        world.set(side-1, side-1, Material::CopperPipe);
        const auto chunk_count = world.chunk_count();
        std::vector<std::uint8_t> bytes(material_baseline::byte_count(side, side));
        const auto start = std::chrono::steady_clock::now();
        material_baseline::copy(world, bytes, side, side);
        const auto copied = std::chrono::steady_clock::now();
        material_baseline::validate(bytes, side, side);
        const auto validated = std::chrono::steady_clock::now();
        require(bytes.size() == static_cast<std::size_t>(side)*static_cast<std::size_t>(side)*2U,
            "scale capture has wrong plane length");
        require(material_baseline::decode(bytes, static_cast<std::size_t>(side)-1U) == 131 &&
            material_baseline::decode(bytes, static_cast<std::size_t>(side)) == 3 &&
            material_baseline::decode(bytes, static_cast<std::size_t>(side)*static_cast<std::size_t>(side)-1U) == 69 &&
            material_baseline::decode(bytes, 0) == 0, "scale edge/row/Empty identity mismatch");
        require(world.chunk_count() == chunk_count, "readback allocated native material storage");
        std::cout << "MATERIAL_BASELINE_PERF side=" << side << " bytes=" << bytes.size()
            << " copy_us=" << std::chrono::duration_cast<std::chrono::microseconds>(copied-start).count()
            << " validate_us=" << std::chrono::duration_cast<std::chrono::microseconds>(validated-copied).count() << '\n';
    }
}
}

int main() {
    try {
        complete_stored_identity_and_const_capture();
        invalid_inputs_never_write_or_change_world();
        simulation_derived_identity();
        supported_full_planes();
        std::cout << "PASS material baseline native contracts\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL material baseline native contracts: " << error.what() << '\n';
        return 1;
    }
}
