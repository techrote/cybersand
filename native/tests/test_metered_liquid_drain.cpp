// #361-A native primitive controls. This is deliberately NOT an equipment,
// Godot adapter, Rapier, command-lease, or desktop-input acceptance test.
// The test-only preflight explores the restricted existing writer; production
// application behavior is tested separately through its actual owner.
#include "cybersand/world.hpp"
#include "cybersand/material_rules.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <numeric>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
std::uint64_t assertions = 0;
std::vector<std::string> cases;
void require(bool condition, const std::string& message) {
    ++assertions;
    if (!condition) throw std::runtime_error(message);
}
struct Point {
    int x, y;
    bool operator==(const Point&) const = default;
};
struct Profile {
    const char* id;
    Material material;
    LiquidSolverFamily family;
    std::uint8_t bits;
};
constexpr std::array<Profile, 8> profiles{{
    {"water-in-3", Material::Water, LiquidSolverFamily::InertialCellularV1, 3},
    {"water-in-8", Material::Water, LiquidSolverFamily::InertialCellularV1, 8},
    {"water-fm-3", Material::Water, LiquidSolverFamily::FreeMassV1, 3},
    {"water-fm-8", Material::Water, LiquidSolverFamily::FreeMassV1, 8},
    {"brine-cy-8", Material::Brine, LiquidSolverFamily::CellularYieldV1, 8},
    {"brine-in-8", Material::Brine, LiquidSolverFamily::InertialCellularV1, 8},
    {"water-cy-3", Material::Water, LiquidSolverFamily::CellularYieldV1, 3},
    {"water-cy-8", Material::Water, LiquidSolverFamily::CellularYieldV1, 8},
}};
WorldConfig configuration(const Profile& p, std::uint32_t workers = 1) {
    auto request = LiquidSolverPolicy::default_request();
    request[p.material == Material::Water ? 21U : 39U] = static_cast<std::int32_t>(p.family);
    const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
    require(decoded.accepted(), "registered policy was refused");
    WorldConfig config;
    config.liquid_solver_policy = *decoded.policy;
    config.maximum_rule_radius = 3;
    config.water_experiment_policy = WaterExperimentPolicy(p.bits, 12);
    config.worker_threads = workers;
    config.parallel_job_threshold = 1;
    config.initial_chunk_reserve = 16;
    config.maximum_chunk_count = 128;
    config.active_chunk_capacity = 128;
    config.active_core_capacity = 1024;
    return config;
}
std::uint64_t quantity(const World& w, Material material) {
    const auto l = w.quantity_ledger();
    return material == Material::Water ? l.water_visible + l.water_overfill
        : l.material_cells[static_cast<std::uint8_t>(material)];
}
std::uint64_t water_sink(const World& w) {
    return w.quantity_ledger().kinds[static_cast<std::size_t>(QuantityKind::ExternalEdit)].consumed;
}
void close_water_ledger(const World& w) {
    const auto l = w.quantity_ledger();
    std::uint64_t sources = l.baseline_water, sinks = l.water_visible + l.water_overfill;
    for (const auto& f : l.kinds) { sources += f.produced; sinks += f.consumed; }
    require(sources == sinks, "native Water source/sink ledger failed to close");
    require(l.water_overfill == 0, "no-PF fixture acquired overfill");
}
bool in_adapter_bounds(Point p) { return p.x >= 0 && p.y >= 0 && p.x < 1024 && p.y < 1024; }
bool blocked(const World& w, Point p) {
    return !in_adapter_bounds(p) || w.transient_obstacle_at(p.x, p.y) != 0 ||
        MaterialRules::is_hard_surface(w.stored_material(p.x, p.y));
}
// Cell-centre supercover: corner-touching hard terrain/body cells also block.
bool clear_line(const World& w, Point from, Point to, std::size_t& reads) {
    const auto check = [&](Point p) { ++reads; return !blocked(w, p); };
    if (!check(from)) return false;
    const int nx = std::abs(to.x - from.x), ny = std::abs(to.y - from.y);
    const int sx = to.x > from.x ? 1 : -1, sy = to.y > from.y ? 1 : -1;
    int ix = 0, iy = 0;
    while (ix < nx || iy < ny) {
        const int a = (1 + 2 * ix) * ny, b = (1 + 2 * iy) * nx;
        if (a == b) {
            if (!check({from.x + sx, from.y}) || !check({from.x, from.y + sy})) return false;
            from.x += sx; from.y += sy; ++ix; ++iy;
        } else if (a < b) { from.x += sx; ++ix; }
        else { from.y += sy; ++iy; }
        if (!check(from)) return false;
    }
    return true;
}
struct Result {
    std::string reason;
    std::uint64_t water_units = 0, brine_cells = 0;
    std::size_t cells = 0, reads = 0;
};
// Native TEST-SIDE composition, not a public gameplay command or receipt.
// A nonempty stored source proves residency. No producer may interleave a tick,
// edit or new mask between this preflight and the point erasures/readback.
Result guarded_remove(World& w, Material material, const std::vector<Point>& targets,
                      std::uint64_t& resource, std::uint64_t operation_budget,
                      std::size_t read_capacity = 2048, std::size_t write_capacity = 128,
                      std::optional<Point> origin = std::nullopt) {
    Result result;
    const auto refuse = [&](const char* reason) { result.reason = reason; return result; };
    if (w.has_failed()) return refuse("failed_world");
    if (material != Material::Water && material != Material::Brine) return refuse("unsupported_material");
    for (const auto& a : w.liquid_solver_policy().assignments())
        if (a.family == LiquidSolverFamily::PressureFlowV1) return refuse("pressure_world");
    const auto family = w.liquid_solver_policy().assignment(static_cast<std::uint16_t>(material));
    if (!family || family->variant != LiquidSolverVariant::Reference ||
        (material == Material::Water && family->family != LiquidSolverFamily::FreeMassV1 &&
            family->family != LiquidSolverFamily::CellularYieldV1 &&
            family->family != LiquidSolverFamily::InertialCellularV1) ||
        (material == Material::Brine && family->family != LiquidSolverFamily::CellularYieldV1 &&
            family->family != LiquidSolverFamily::InertialCellularV1)) return refuse("unsupported_policy");
    if (family->family == LiquidSolverFamily::InertialCellularV1 &&
        w.config().maximum_rule_radius != 3) return refuse("radius");
    if (targets.empty()) return refuse("empty_intake");
    if (targets.size() > 16) return refuse("effect_cap");
    if (resource == 0 || operation_budget == 0) return refuse("budget");
    if (write_capacity < targets.size() || read_capacity < targets.size() * 2) return refuse("capacity");
    const auto tick = w.completed_tick_index();
    std::uint64_t planned = 0;
    std::vector<std::uint16_t> amounts;
    for (std::size_t i = 0; i < targets.size(); ++i) {
        const auto p = targets[i];
        if (!in_adapter_bounds(p)) return refuse("bounds");
        if (std::find(targets.begin(), targets.begin() + static_cast<std::ptrdiff_t>(i), p) !=
            targets.begin() + static_cast<std::ptrdiff_t>(i)) return refuse("duplicate_target");
        ++result.reads;
        if (w.transient_obstacle_at(p.x, p.y) != 0) return refuse("body_mask");
        if (w.stored_material(p.x, p.y) != material) return refuse("wrong_material");
        const auto amount = material == Material::Water ? w.stored_state_a(p.x, p.y) : std::uint16_t{1};
        if (amount == 0 || (material == Material::Water &&
            (amount > w.config().water_experiment_policy.maximum() ||
            (family->family != LiquidSolverFamily::FreeMassV1 &&
             amount != w.config().water_experiment_policy.maximum())))) return refuse("quantity");
        if (origin && !clear_line(w, *origin, p, result.reads)) return refuse("blocked_path");
        if (result.reads + targets.size() > read_capacity) return refuse("capacity");
        amounts.push_back(amount);
        planned += amount;
    }
    if (planned > resource || planned > operation_budget) return refuse("budget");
    if (result.reads + targets.size() > read_capacity) return refuse("capacity");
    for (std::size_t i = 0; i < targets.size(); ++i) {
        const auto p = targets[i];
        (void)w.set_cell_state(p.x, p.y, Material::Empty, 0, 0); // Not the success oracle.
        ++result.reads;
        require(!w.has_failed() && w.completed_tick_index() == tick &&
            w.stored_material(p.x, p.y) == Material::Empty && w.stored_state_a(p.x, p.y) == 0 &&
            w.stored_state_b(p.x, p.y) == 0 && w.transient_obstacle_at(p.x, p.y) == 0,
            "unexpected write/readback fault; no clean refusal is permitted");
        const auto motion = w.inertial_cell(p.x, p.y);
        require(motion.vx == 0 && motion.vy == 0 && motion.ax == 0 && motion.ay == 0,
                "erased cell retained motion");
        if (material == Material::Water) result.water_units += amounts[i]; else ++result.brine_cells;
        ++result.cells;
    }
    resource -= planned;
    result.reason = "applied";
    return result;
}
void refusal_is_unchanged(World& w, Material material, std::vector<Point> targets,
                          std::uint64_t resource, std::uint64_t budget, const char* expected,
                          std::size_t reads = 2048, std::size_t writes = 128,
                          std::optional<Point> origin = std::nullopt) {
    const auto state = w.save_physical_state();
    const auto ledger = w.quantity_ledger();
    const auto motion = w.inertial_ledger();
    const auto chunks = w.chunk_count(), initial_resource = resource;
    const auto result = guarded_remove(w, material, targets, resource, budget, reads, writes, origin);
    require(result.reason == expected, "wrong refusal reason: " + result.reason);
    require(result.cells == 0 && result.water_units == 0 && result.brine_cells == 0,
            "refusal reported a removal");
    require(w.save_physical_state() == state && w.quantity_ledger() == ledger &&
        w.inertial_ledger() == motion && w.chunk_count() == chunks && resource == initial_resource,
        "normal refusal changed quantity, motion, storage, or effect budget");
}
void add_case(const std::string& id, const std::string& fields = "") {
    cases.push_back("{\"case_id\":\"" + id + "\",\"status\":\"pass\"" + fields + "}");
}
void exact_controls(const Profile& p, int count) {
    auto w = std::make_unique<World>(configuration(p));
    std::vector<Point> targets;
    std::uint64_t expected = 0;
    for (int i = 0; i < count; ++i) {
        const Point point{20 + i % 4, 20 + i / 4};
        targets.push_back(point);
        const auto q = w->config().water_experiment_policy.maximum();
        const auto value = p.material == Material::Brine ? static_cast<std::uint16_t>(i % 2 ? 201 : 3)
            : p.family == LiquidSolverFamily::FreeMassV1
                ? static_cast<std::uint16_t>(1 + (i * 17 + 2) % (q - 1)) : q;
        require(w->set_cell_state(point.x, point.y, p.material, value, 0), "fixture source refused");
        expected += p.material == Material::Water ? value : 1;
    }
    const auto initial = quantity(*w, p.material), initial_sink = water_sink(*w), chunks = w->chunk_count();
    std::uint64_t resource = expected + 11;
    const auto result = guarded_remove(*w, p.material, targets, resource, expected);
    require(result.reason == "applied" && result.cells == static_cast<std::size_t>(count), "bounded removal failed");
    require(result.water_units == (p.material == Material::Water ? expected : 0) &&
        result.brine_cells == (p.material == Material::Brine ? expected : 0), "quantity dimensions confused");
    require(initial == expected && quantity(*w, p.material) == 0 && resource == 11 &&
        w->chunk_count() == chunks && w->completed_tick_index() == 0, "stored removal/resource closure failed");
    require(water_sink(*w) - initial_sink == result.water_units, "native sink differs from observed removal");
    close_water_ledger(*w);
    refusal_is_unchanged(*w, p.material, targets, resource, expected, "wrong_material");
    std::ostringstream fields;
    fields << ",\"cells\":" << count << ",\"water_units\":" << result.water_units
        << ",\"brine_cells\":" << result.brine_cells << ",\"initial_quantity\":" << initial
        << ",\"remaining_quantity\":0,\"remaining_resource\":" << resource
        << ",\"native_water_sink_delta\":" << water_sink(*w) - initial_sink
        << ",\"mass_bits\":" << static_cast<int>(p.bits)
        << ",\"policy_hash\":\"" << w->liquid_solver_policy().policy_hash_hex() << "\"";
    add_case(std::string("exact.") + p.id + "." + std::to_string(count), fields.str());
}
void refusal_controls() {
    auto w = std::make_unique<World>(configuration(profiles[1]));
    w->reserve_region({0, 0, 128, 128}); w->configure_transient_obstacles({0, 0, 128, 128});
    w->set(20, 20, Material::Water); w->set(21, 20, Material::Water);
    (void)w->tick(); // Actual gravity, no diagnostic velocity assignment.
    require(w->inertial_cell(20, 20).vy > 0, "refusal fixture has no motion witness");
    w->set(22, 20, Material::Oil); w->set(23, 20, Material::Wall);
    refusal_is_unchanged(*w, Material::Water, {}, 1024, 1024, "empty_intake");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{22,20}}, 1024, 1024, "wrong_material");
    refusal_is_unchanged(*w, Material::Oil, {{22,20}}, 1024, 1024, "unsupported_material");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{-1,20}}, 1024, 1024, "bounds");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{1024,20}}, 1024, 1024, "bounds");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{20,20}}, 1024, 1024, "duplicate_target");
    refusal_is_unchanged(*w, Material::Water, {{20,20}}, 0, 1024, "budget");
    refusal_is_unchanged(*w, Material::Water, {{20,20}}, 1024, 0, "budget");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{21,20}}, 509, 1024, "budget");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{21,20}}, 1024, 509, "budget");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{21,20}}, 1024, 1024, "capacity", 3, 128);
    refusal_is_unchanged(*w, Material::Water, {{20,20},{21,20}}, 1024, 1024, "capacity", 2048, 1);
    refusal_is_unchanged(*w, Material::Water, std::vector<Point>(17, {20,20}), 1024, 1024, "effect_cap");
    require(w->set_transient_obstacle(21,20,1), "mask fixture failed");
    refusal_is_unchanged(*w, Material::Water, {{20,20},{21,20}}, 1024, 1024, "body_mask");
    require(w->transient_obstacle_at(21,20) == 1, "refusal changed mask ownership");
    w->clear_transient_obstacles();
    w->set(25, 20, Material::Water);
    refusal_is_unchanged(*w, Material::Water, {{20,20},{25,20}}, 1024, 1024, "blocked_path",2048,128,Point{19,20});
    w->set(24, 19, Material::Wall); w->set(24, 20, Material::Water);
    refusal_is_unchanged(*w, Material::Water, {{24,20}}, 1024, 1024, "blocked_path",2048,128,Point{23,19});
    require(w->stored_material(23,20) == Material::Wall && w->stored_material(25,20) == Material::Water &&
            w->stored_material(24,19) == Material::Wall, "wall/forbidden-side spatial proof failed");
    add_case("refusal.complete-preflight", ",\"refusals\":16,\"motion_witness\":true,\"spatial_wall_checks\":true");
}
void masked_raw_hazard() {
    for (const auto& p : profiles) {
        auto w = std::make_unique<World>(configuration(p));
        w->reserve_region({0,0,128,128}); w->configure_transient_obstacles({0,0,128,128});
        w->set(10,10,p.material);
        require(w->set_transient_obstacle(10,10,7), "raw-hazard mask refused");
        refusal_is_unchanged(*w,p.material,{{10,10}},4096,4096,"body_mask");
        const auto before = quantity(*w,p.material);
        require(w->set_cell_state(10,10,Material::Empty,0,0), "raw erasure hazard semantics changed");
        require(before > 0 && quantity(*w,p.material) == 0 && w->transient_obstacle_at(10,10) == 7 &&
            w->stored_material(10,10) == Material::Empty && w->get(10,10) == Material::Wall,
            "raw erase did not expose masked stored-content destruction");
        close_water_ledger(*w);
    }
    add_case("hazard.raw-empty-under-mask",
        ",\"profiles\":8,\"guarded_refusal_preserves_state\":true,\"raw_erasure_removes_stored_material\":true");
}
void unsupported_controls() {
    for (const auto& p : {profiles[0], profiles[1], profiles[6], profiles[7]}) {
        auto w = std::make_unique<World>(configuration(p)); w->set(10,10,Material::Water);
        const auto before = w->save_physical_state();
        for (auto q : {std::uint16_t{1}, static_cast<std::uint16_t>(w->config().water_experiment_policy.maximum()-1)}) {
            require(!w->set_cell_state(10,10,Material::Water,q,0) &&
                !w->set_cell_state(1000,1000,Material::Water,q,0), "fractional live whole-cell source admitted");
        }
        require(w->save_physical_state() == before, "fractional ingress refusal changed authority");
        auto bad = configuration(p); bad.maximum_rule_radius=2;
        bool refused=false; try { World candidate(bad); } catch(const std::invalid_argument&) { refused=true; }
        require(refused == (p.family==LiquidSolverFamily::InertialCellularV1) &&
            w->save_physical_state() == before, "radius-two construction policy or old authority changed");
    }
    auto cfg = configuration(profiles[4]);
    auto words = LiquidSolverPolicy::default_request(); words[21] = 3;
    auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "PF negative-control policy unavailable"); cfg.liquid_solver_policy = *decoded.policy;
    auto pf = std::make_unique<World>(cfg); pf->set(10,10,Material::Brine);
    refusal_is_unchanged(*pf,Material::Brine,{{10,10}},5,5,"pressure_world");
    const auto retained=pf->save_physical_state();
    words=LiquidSolverPolicy::default_request(); words[24]=4; // Unsupported Oil IN.
    decoded=LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(!decoded.accepted() && pf->save_physical_state()==retained,"unsupported Oil IN changed old authority");
    add_case("refusal.policy-and-fractional-whole-cell",
        ",\"water_quanta\":[7,255],\"pressure_world_refused\":true,\"oil_in_refused\":true,\"water_cy_full_cells_only\":true");
}
void capacity_and_quarantine() {
    auto cfg=configuration(profiles[1]); cfg.chunk_size=8; cfg.initial_chunk_reserve=1;
    cfg.maximum_chunk_count=1; cfg.backend=SimulationBackend::SerialInPlace;
    auto w=std::make_unique<World>(cfg); w->set(4,7,Material::Water);
    const auto count=w->chunk_count(); std::uint64_t stock=255;
    require(guarded_remove(*w,Material::Water,{{4,7}},stock,255).reason=="applied" &&
            w->chunk_count()==count && stock==0,"resident sink incorrectly needs new chunk capacity");
    w->set(4,7,Material::Water); bool failed=false;
    for (int i=0;i<8&&!failed;++i) { try {(void)w->tick();} catch(const std::exception&) {failed=true;} }
    require(failed && w->has_failed() && w->completed_tick_index()<w->tick_index(),"capacity tick did not quarantine");
    const auto stored=w->stored_material(4,7);
    const auto state=w->stored_state_a(4,7);
    stock=255; const auto result=guarded_remove(*w,Material::Water,{{4,7}},stock,255);
    require(result.reason=="failed_world" && result.cells==0 && stock==255 &&
        w->stored_material(4,7)==stored && w->stored_state_a(4,7)==state,"failed World accepted sink");
    const auto policy=w->liquid_solver_policy().policy_hash_hex(); w->clear();
    require(!w->has_failed() && w->completed_tick_index()==0 && quantity(*w,Material::Water)==0 &&
        w->liquid_solver_policy().policy_hash_hex()==policy,"clear failed to reconstruct healthy authority");
    add_case("capacity.resident-erase-and-failed-tick",
        ",\"resident_erase_at_chunk_limit\":true,\"failed_tick_quarantined\":true,\"clear_recovery\":true");
}
void persistence_and_retirement() {
    for (const auto& p : profiles) {
        auto cfg=configuration(p); auto w=std::make_unique<World>(cfg);
        w->reserve_region({0,0,128,128}); w->set(20,20,p.material); w->set(21,20,p.material);
        // FM/CY can move on the first tick; only the IN arms need a live
        // motion witness, still at the observed source after one native tick.
        if(p.family==LiquidSolverFamily::InertialCellularV1)(void)w->tick();
        const auto pre=w->inertial_cell(20,20);
        const auto ledger=w->inertial_ledger();
        std::uint64_t stock=1000; const auto r=guarded_remove(*w,p.material,{{20,20}},stock,1000);
        require(r.reason=="applied","retirement sink failed");
        if (p.family==LiquidSolverFamily::InertialCellularV1) {
            require(pre.vy>0,"IN retirement needs actual native motion");
            const auto post=w->inertial_ledger();
            require(post.retired_x-ledger.retired_x==pre.vx && post.retired_y-ledger.retired_y==pre.vy &&
                post.velocity_retired-ledger.velocity_retired==static_cast<std::uint64_t>(std::abs(pre.vx)+std::abs(pre.vy)),
                "native retirement ledger does not match removed carrier motion");
        }
        const auto bytes=w->save_physical_state(); auto restored=World::restore_physical_state(cfg,bytes);
        require(restored->save_physical_state()==bytes && restored->quantity_ledger()==w->quantity_ledger() &&
            restored->inertial_ledger()==w->inertial_ledger(),"sink persistence mismatch");
        for(int tick=0;tick<8;++tick) { (void)w->tick(); (void)restored->tick();
            require(w->physical_state_hash()==restored->physical_state_hash() &&
                w->quantity_ledger()==restored->quantity_ledger(),"post-sink restored continuation diverged");
            require(w->inertial_ledger()==restored->inertial_ledger(),
                "restored IN diagnostic ledger diverged separately from physical hash"); }
        const auto retained=w->save_physical_state(); auto fresh=std::make_unique<World>(cfg);
        require(quantity(*fresh,p.material)==0 && fresh->completed_tick_index()==0 &&
            w->save_physical_state()==retained,"fresh construction changed old authority");
    }
    add_case("lifecycle.native-retirement-persistence-reconstruction",
        ",\"profiles\":8,\"continuation_ticks_per_profile\":8,\"native_motion_witness\":true,"
        "\"inertial_ledger_continuation_parity\":true,\"application_lifecycle_tested\":false");
}
constexpr std::array<Point,8> tanks{{
    {16,16},{144,16},{272,16},{400,16},{16,144},{144,144},{272,144},{400,144}}};
void tank_setup(World& w,Material material) {
    w.reserve_region({0,0,512,256}); w.configure_transient_obstacles({0,0,512,256});
    for (const auto t:tanks) {
        for(int y=0;y<=18;++y)for(int x=0;x<=19;++x) {
            if (x==0||x==19||y==0||y==18) w.set(t.x+x,t.y+y,Material::Wall);
            else if(y>=9) w.set(t.x+x,t.y+y,material);
        }
    }
}
std::uint64_t spatial_census(const World& w,Material material) {
    std::uint64_t total=0;
    for(const auto t:tanks) {
        for(int y=0;y<=18;++y)for(int x=0;x<=19;++x) {
            const auto m=w.stored_material(t.x+x,t.y+y);
            if(x==0||x==19||y==0||y==18) require(m==Material::Wall,"tank boundary position changed");
            else if(m==material) total+=material==Material::Water?w.stored_state_a(t.x+x,t.y+y):1U;
            else require(m==Material::Empty,"unregistered chemistry or source in controlled tank");
        }
        for(int x=-1;x<=20;++x)require(w.stored_material(t.x+x,t.y-1)==Material::Empty &&
            w.stored_material(t.x+x,t.y+19)==Material::Empty,"liquid crossed a tank floor/ceiling");
        for(int y=-1;y<=19;++y)require(w.stored_material(t.x-1,t.y+y)==Material::Empty &&
            w.stored_material(t.x+20,t.y+y)==Material::Empty,"liquid crossed a tank side");
    }
    require(quantity(w,material)==total,"full native material ledger differs from spatial tank census");
    return total;
}
// Independent complete stored-cell oracle at registered checkpoints. The
// incremental ledger is the subject of comparison, never the inventory source.
// Every resident coordinate is covered, including the wide gaps between tanks;
// an additional chunk or any nonempty forbidden-side coordinate fails closed.
void full_resident_census(const World& w,Material material,std::uint64_t expected) {
    require(w.config().chunk_size==128 && w.chunk_count()==8,
        "registered resident census domain changed");
    std::array<std::uint64_t,256> population{};
    std::uint64_t water=0,selected=0;
    for(int y=0;y<256;++y)for(int x=0;x<512;++x) {
        const int rx=x%128-16, ry=y%128-16;
        const bool tank=rx>=0&&rx<=19&&ry>=0&&ry<=18;
        const bool wall=tank&&(rx==0||rx==19||ry==0||ry==18);
        const auto stored=w.stored_material(x,y);
        if(wall)require(stored==Material::Wall,"resident census found moved/missing barrier");
        else if(tank)require(stored==material||stored==Material::Empty,
            "resident census found unregistered material inside tank");
        else require(stored==Material::Empty,"resident census found escaped material");
        if(stored==Material::Empty)continue;
        ++population[static_cast<std::uint8_t>(stored)];
        if(stored==Material::Water)water+=w.stored_state_a(x,y);
        if(stored==material)selected+=material==Material::Water?w.stored_state_a(x,y):1U;
    }
    const auto ledger=w.quantity_ledger();
    require(ledger.material_cells==population && ledger.water_visible==water && ledger.water_overfill==0,
        "native incremental ledger differs from complete stored-cell inventory");
    require(selected==expected,"resident inventory does not close registered source/sink balance");
}
void census_oracle_controls() {
    for(int corruption=0;corruption<5;++corruption) {
        auto w=std::make_unique<World>(configuration(profiles[3]));tank_setup(*w,Material::Water);
        const auto initial=8U*18U*9U*255U;
        full_resident_census(*w,Material::Water,initial);
        switch(corruption) {
            case 0:w->set(80,80,Material::Water);break; // Escaped material beyond adjacent wall checks.
            case 1:w->set(16,20,Material::Empty);break; // One missing barrier, even if totals look similar.
            case 2:w->set(600,20,Material::Water);break; // Additional resident chunk outside census domain.
            case 3:w->set(20,30,Material::Oil);break; // Unregistered chemistry/material substitution.
            default:break;
        }
        bool rejected=false;
        try {full_resident_census(*w,Material::Water,initial+(corruption==4?1U:0U));}
        catch(const std::runtime_error&) {rejected=true;}
        require(rejected,"complete census accepted deliberately corrupted inventory/domain/geometry");
    }
    add_case("oracle.complete-resident-census",
        ",\"resident_cells\":131072,\"resident_chunks\":8,\"negative_controls\":5");
}
struct Flow {
    std::vector<std::uint64_t> hashes;
    std::vector<InertialLedger> inertial_trace;
    std::uint64_t initial=0,removed=0,remaining=0,phase_jobs=0,operations=0,moved_after_stop=0;
    std::uint32_t claimants=0;
};
Flow flow(const Profile& p,std::uint32_t workers) {
    auto w=std::make_unique<World>(configuration(p,workers)); tank_setup(*w,p.material);
    Flow result; result.initial=spatial_census(*w,p.material);
    full_resident_census(*w,p.material,result.initial);
    result.inertial_trace.push_back(w->inertial_ledger());
    std::uint64_t resource=result.initial, sink_at_stop=0;
    for(int tick=0;tick<64;++tick) {
        if(tick<20&&tick%4==0)for(const auto t:tanks) {
            std::vector<Point> targets;
            for(int y=14;y<=17;++y)for(int x=7;x<=10;++x)
                if(w->stored_material(t.x+x,t.y+y)==p.material)targets.push_back({t.x+x,t.y+y});
            if(targets.empty())continue;
            const auto before=quantity(*w,p.material), external=water_sink(*w);
            const auto r=guarded_remove(*w,p.material,targets,resource,resource);
            require(r.reason=="applied"&&r.cells<=16,"registered bounded pulse refused");
            const auto removed=r.water_units+r.brine_cells;
            require(before-quantity(*w,p.material)==removed && water_sink(*w)-external==r.water_units,
                "per-operation native sink closure failed");
            result.removed+=removed; ++result.operations;
        }
        if(tick==20)sink_at_stop=water_sink(*w);
        const auto stats=w->tick();
        result.claimants=std::max(result.claimants,stats.worker_threads_observed);
        result.phase_jobs+=std::accumulate(stats.phase_jobs.begin(),stats.phase_jobs.end(),std::uint64_t{0});
        if(tick>=20) { result.moved_after_stop+=stats.moved_cells;
            require(water_sink(*w)==sink_at_stop,"drain-off continuation generated a new sink"); }
        close_water_ledger(*w);
        const auto remaining=spatial_census(*w,p.material);
        require(remaining+result.removed==result.initial && resource==remaining,"per-tick material/resource closure failed");
        result.hashes.push_back(w->physical_state_hash());
        result.inertial_trace.push_back(w->inertial_ledger());
        if(tick+1==8||tick+1==20||tick+1==32||tick+1==64)
            full_resident_census(*w,p.material,result.initial-result.removed);
    }
    result.remaining=quantity(*w,p.material);
    require(result.removed>0&&result.remaining>0&&result.operations>0,"flow did not retain liquid after bounded sinks");
    return result;
}
void worker_controls(const Profile& p) {
    const auto one=flow(p,1), four=flow(p,4);
    require(one.hashes==four.hashes&&one.initial==four.initial&&one.removed==four.removed&&
        one.remaining==four.remaining&&one.operations==four.operations,"worker-count physical/quantity parity failed");
    require(one.inertial_trace==four.inertial_trace && one.inertial_trace.size()==65,
        "worker-count IN diagnostic ledger trace differs independently of physical hash");
    require(one.claimants==1 && four.claimants>=2 && four.claimants<=4 && four.phase_jobs>0,
        "configured workers did not establish actual parallel participation");
    std::ostringstream fields;
    fields<<",\"ticks_per_arm\":64,\"initial_quantity\":"<<one.initial<<",\"removed_quantity\":"<<one.removed
        <<",\"remaining_quantity\":"<<one.remaining<<",\"operations_per_arm\":"<<one.operations
        <<",\"maximum_cells_per_operation\":16,\"workers1_observed\":"<<one.claimants
        <<",\"workers4_observed\":"<<four.claimants<<",\"phase_jobs_workers4\":"<<four.phase_jobs
        <<",\"moved_cells_after_stop_workers1\":"<<one.moved_after_stop
        <<",\"moved_cells_after_stop_workers4\":"<<four.moved_after_stop
        <<",\"water_units\":"<<(p.material==Material::Water?one.removed:0)
        <<",\"brine_cells\":"<<(p.material==Material::Brine?one.removed:0)
        <<",\"physical_hash_parity\":true,\"inertial_ledger_parity\":true,"
        "\"resident_census_cells\":131072,\"resident_census_ticks\":[0,8,20,32,64],"
        "\"resident_domain_chunk_count\":8,\"flow_initial_water_model\":\"whole-cells-for-matched-geometry\"";
    add_case(std::string("workers.")+p.id,fields.str());
}
}
int main() {
    try {
        for(const auto& p:profiles)for(const int count:{1,16})exact_controls(p,count);
        refusal_controls(); masked_raw_hazard(); unsupported_controls();
        capacity_and_quarantine(); persistence_and_retirement(); census_oracle_controls();
        for(const auto& p:profiles)worker_controls(p);
        std::cout<<"{\"schema\":\"metered-drain-native-primitives-v1\",\"scope\":\"native-core-only\","
            "\"production_application_executed\":false,\"status\":\"pass\",\"assertions\":"<<assertions<<",\"cases\":[";
        for(std::size_t i=0;i<cases.size();++i)std::cout<<(i?",":"")<<cases[i];
        std::cout<<"]}\n";
        return 0;
    } catch(const std::exception& error) {
        std::cerr<<"metered drain native controls FAILED after "<<assertions<<" assertions: "<<error.what()<<"\n";
        return 1;
    }
}
