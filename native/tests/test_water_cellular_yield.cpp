// LCB-001 W-CY: Water identity/hooks with whole-cell yielding motion. This is
// intentionally separate from setup normalization, host receipts and ledgers.
#include "cybersand/world.hpp"
#include "cybersand/sha256.hpp"
#include "cybersand/demo_snapshot.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error(message);
}
std::vector<std::int32_t> request(std::optional<int> viscosity = std::nullopt, int block_version = 2) {
    auto words = LiquidSolverPolicy::default_request();
    words[21] = 2;
    if (viscosity) {
        words.back() = 1;
        words.insert(words.end(), {3,block_version,1,*viscosity});
    }
    return words;
}
WorldConfig config(std::uint8_t bits = 8, std::uint8_t coherence = 12,
                   std::uint32_t workers = 1, std::optional<int> viscosity = std::nullopt) {
    WorldConfig result;
    result.worker_threads = workers;
    result.parallel_job_threshold = 1;
    result.water_experiment_policy = WaterExperimentPolicy(bits, coherence);
    const auto words = request(viscosity);
    auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
    require(decoded.accepted(), "W-CY policy refused: " + decoded.refusal.message());
    result.liquid_solver_policy = *decoded.policy;
    return result;
}
void rect(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx,yy,material);
}
void enclose_pair(World& world, Material left, Material right) {
    rect(world,7,7,4,3,Material::Wall);
    world.set(8,8,left); world.set(9,8,right);
}
void compare_cells(const World& a, const World& b, RectI64 region, const char* reason) {
    for (auto y = region.y; y < region.y + region.height; ++y)
        for (auto x = region.x; x < region.x + region.width; ++x)
            require(a.stored_material(x,y) == b.stored_material(x,y) &&
                        a.stored_state_a(x,y) == b.stored_state_a(x,y) &&
                        a.stored_state_b(x,y) == b.stored_state_b(x,y) && a.temperature(x,y) == b.temperature(x,y), reason);
}
void check_full_water(const World& world, RectI64 region) {
    for (auto y = region.y; y < region.y + region.height; ++y)
        for (auto x = region.x; x < region.x + region.width; ++x)
            if (world.stored_material(x,y) == Material::Water)
                require(world.stored_state_a(x,y) == world.config().water_experiment_policy.maximum(),
                        "W-CY produced fractional Water");
}

void admission_and_ingress() {
    static_assert(WaterCellularYieldParameters::kMaterialBlockVersion ==
                  LiquidPolicyBuild::kWaterCellularYieldBlockVersion);
    World default_world;
    require(!default_world.water_cellular_yield_enabled(), "default changed Water family");
    for (const int viscosity : {0,1,192,240,255}) {
        World world(config(8,12,1,viscosity));
        require(world.water_cellular_yield_enabled() && !world.pressure_flow_enabled() &&
                    world.water_cellular_yield_parameters().viscosity_index == viscosity,
                "Water v2 material parameter not applied");
    }
    for (const int viscosity : {-1,256}) {
        const auto words = request(viscosity);
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        require(!decoded.accepted() && decoded.refusal.code == LiquidPolicyRefusalCode::MalformedPolicy,
                "out-of-range viscosity accepted");
    }
    const auto old_block = request(500,1);
    require(LiquidSolverPolicy::decode(std::span<const std::int32_t>(old_block)).refusal.code ==
                LiquidPolicyRefusalCode::UnknownParameter, "illustrative v1 block reinterpreted");
    for (std::uint8_t bits = 3; bits <= 8; ++bits) {
        World world(config(bits));
        world.set(8,8,Material::Water);
        world.set_temperature(8,8,777);
        const auto maximum = world.config().water_experiment_policy.maximum();
        const auto before = world.physical_state_hash();
        const auto chunks = world.chunk_count();
        require(!world.set_cell_state(8,8,Material::Water,maximum-1U,0) &&
                    !world.set_cell_state(1000,1000,Material::Water,1,0), "partial external write accepted");
        require(world.physical_state_hash() == before && world.chunk_count() == chunks &&
                    world.temperature(8,8) == 777, "partial refusal mutated or allocated authority");
        std::vector<std::uint8_t> level(demo::kPayloadBytes,0);
        level[0]=static_cast<std::uint8_t>(Material::Water);
        level[1]=static_cast<std::uint8_t>(maximum-1U);
        bool import_refused=false;
        try { (void)demo::reconstruct(world.config(),level); }
        catch(const LiquidPolicyRefused& refusal) {
            import_refused=refusal.refusal().code==LiquidPolicyRefusalCode::NormalizationRequired;
        }
        require(import_refused && world.physical_state_hash()==before,
                "native CYSD1 reconstruction silently dropped fractional Water");
        require(world.set_cell_state(8,8,Material::Water,0,0) && world.get(8,8) == Material::Empty,
                "zero Water did not retain established erase semantics");
        world.paint_disc(8,8,2,Material::Water);
        check_full_water(world,{0,0,16,16});
        std::vector<Material> generated(128U*128U,Material::Water);
        require(world.install_generated_chunk({1,0},generated) == ChunkInstallOutcome::Installed,
                "generated whole-cell ingress refused");
        check_full_water(world,{128,0,128,128});
    }
}

void coherence_viscosity_and_masks() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) for (std::uint8_t delay : std::array<std::uint8_t,2>{0,12}) {
        World world(config(bits,delay));
        rect(world,0,10,32,1,Material::Wall);
        const auto maximum = world.config().water_experiment_policy.maximum();
        require(world.set_cell_state(8,9,Material::Water,maximum,delay), "coherent setup");
        world.set_temperature(8,9,321);
        world.set_liquid_surface_adhesion_enabled(true);
        (void)world.tick();
        if (delay != 0)
            require(world.get(8,9) == Material::Water && world.stored_state_b(8,9) == delay-1,
                    "coherence failed to suppress lateral motion");
        else {
            require(world.get(8,9) == Material::Empty &&
                        (world.get(7,9) == Material::Water || world.get(9,9) == Material::Water),
                    "Water default viscosity0 used Paste/Slush law or failed full-cell lateral move");
            auto fm=config(bits,0);fm.liquid_solver_policy=LiquidSolverPolicy{};
            World current(fm);rect(current,0,10,32,1,Material::Wall);current.set(8,9,Material::Water);
            (void)current.tick();
            bool fractional=false;
            for(int x=6;x<=10;++x)
                fractional=fractional || (current.stored_material(x,9)==Material::Water &&
                                          current.stored_state_a(x,9)!=maximum);
            require(fractional,"FreeMass negative control did not exercise fractional relaxation");
        }
        check_full_water(world,{0,0,32,12});

        World falling(config(bits,12));
        require(falling.set_cell_state(8,8,Material::Water,maximum,12), "falling setup");
        falling.set_temperature(8,8,456);
        (void)falling.tick();
        require(falling.get(8,9) == Material::Water && falling.stored_state_b(8,9) == 11 &&
                    falling.temperature(8,9) == 456, "coherence blocked gravity or lost temperature");
    }
    // Same Water setup, distinct real viscosity parameters: default0 always
    // admits a lateral yield; 255 often waits. No foreign descriptor is read.
    int waiting = 0;
    for (int x = 4; x < 40; ++x) {
        World slow(config(8,0,1,255)); rect(slow,0,10,64,1,Material::Wall); slow.set(x,9,Material::Water);
        (void)slow.tick(); if (slow.get(x,9) == Material::Water) ++waiting;
    }
    require(waiting >= 30, "Water v2 viscosity parameter not used");
    World masked(config()); masked.reserve_region({0,0,128,128});
    masked.set(8,8,Material::Water);
    masked.configure_transient_obstacles({0,0,128,128});
    require(masked.set_transient_obstacle(8,8,1) && masked.set_transient_obstacle(8,9,1), "mask setup");
    (void)masked.tick();
    require(masked.stored_material(8,8) == Material::Water && masked.stored_material(8,9) == Material::Empty,
            "masked stored Water moved");
    masked.clear_transient_obstacles();
    for(int x=7;x<=9;++x) require(masked.set_transient_obstacle(x,9,1), "contact mask setup");
    (void)masked.tick();
    require(masked.transient_contact_count(1) > 0 && masked.stored_material(8,9) == Material::Empty,
            "W-CY missed body contact or entered body mask");
}

void material_hooks() {
    struct Pair {Material left,right,left_product,right_product; int ticks;};
    const Pair cases[] = {
        {Material::Water,Material::Salt,Material::Brine,Material::Brine,1024},
        {Material::Lava,Material::Water,Material::Stone,Material::Steam,1024},
        {Material::Fire,Material::Water,Material::Smoke,Material::Steam,8},
    };
    for (const auto& item : cases) for (std::uint32_t workers : {1U,4U}) {
        auto wc = config(8,12,workers); auto fm = wc; fm.liquid_solver_policy = LiquidSolverPolicy{};
        World current(fm), candidate(wc);
        enclose_pair(current,item.left,item.right); enclose_pair(candidate,item.left,item.right);
        bool completed = false;
        for (int tick = 0; tick < item.ticks; ++tick) {
            (void)current.tick(); (void)candidate.tick();
            compare_cells(current,candidate,{7,7,4,3},"material chemistry changed under W-CY");
            if (candidate.stored_material(8,8) == item.left_product &&
                candidate.stored_material(9,8) == item.right_product) { completed = true; break; }
        }
        require(completed,"material hook fixture never reacted");
    }
    for (std::uint32_t workers : {1U,4U}) {
        auto wc = config(3,12,workers); auto fm = wc; fm.liquid_solver_policy = LiquidSolverPolicy{};
        World current(fm), candidate(wc);
        for (auto* world : {&current,&candidate}) {
            enclose_pair(*world,Material::Oil,Material::Water);
            require(world->set_cell_state(8,8,Material::Oil,0,120),"burning Oil setup");
        }
        for (int tick = 0; tick < 16; ++tick) {
            (void)current.tick(); (void)candidate.tick();
            compare_cells(current,candidate,{7,7,4,3},"Oil extinguish no longer observes Water identity");
        }
        require(candidate.stored_state_b(8,8) == 0,"Water failed to extinguish Oil");
        current.clear(); candidate.clear();
        for (auto* world : {&current,&candidate}) enclose_pair(*world,Material::Cement,Material::Water);
        for (int tick = 0; tick < 400; ++tick) { (void)current.tick(); (void)candidate.tick(); }
        compare_cells(current,candidate,{7,7,4,3},"Cement cure changed under W-CY");
        require(candidate.get(8,8) == Material::Concrete,"Water-adjacent Cement did not cure");
        current.clear(); candidate.clear();
        for (auto* world : {&current,&candidate}) {
            enclose_pair(*world,Material::Steam,Material::Wall);
            require(world->set_cell_state(8,8,Material::Steam,1,0),"condensing Steam setup");
        }
        for (int tick = 0; tick < 16 && candidate.get(8,8) != Material::Water; ++tick) {
            (void)current.tick(); (void)candidate.tick();
            compare_cells(current,candidate,{7,7,4,3},"Steam product changed under W-CY");
        }
        require(candidate.get(8,8) == Material::Water && candidate.stored_state_a(8,8) == 7,
                "Steam product did not use Water family full mass");
    }
}

void workers_persistence_and_transport() {
    for (std::uint8_t bits = 3; bits <= 8; ++bits) for (std::uint8_t coherence : std::array<std::uint8_t,2>{0,12}) {
        World one(config(bits,coherence,1)), four(config(bits,coherence,4));
        for (auto* world : {&one,&four}) {
            world->reserve_region({-128,-128,384,384});
            rect(*world,-8,80,160,1,Material::Wall);
            rect(*world,-8,0,1,80,Material::Wall); rect(*world,151,0,1,80,Material::Wall);
            rect(*world,0,16,70,35,Material::Water);
            rect(*world,80,55,12,12,Material::Oil); rect(*world,96,55,12,12,Material::Brine);
            if (coherence) for(int y=16;y<51;++y) for(int x=0;x<70;++x)
                (void)world->set_cell_state(x,y,Material::Water,world->config().water_experiment_policy.maximum(),coherence);
        }
        const auto quantity = one.water_quantity({-128,-128,384,384});
        for (int tick=0;tick<80;++tick) {
            const auto a=one.tick(), b=four.tick();
            require(a.chunk_allocations+a.temperature_field_allocations+b.chunk_allocations+b.temperature_field_allocations == 0,
                    "prepared W-CY tick allocated");
            require(one.water_quantity({-128,-128,384,384}) == quantity &&
                        four.water_quantity({-128,-128,384,384}) == quantity,"whole-cell Water quantity drift");
            require(one.physical_state_hash() == four.physical_state_hash(),"W-CY 1/4 worker divergence");
        }
        check_full_water(one,{-8,0,160,81});
        const auto bytes = one.save_physical_state();
        auto restored = World::restore_physical_state(config(bits,coherence,4),bytes);
        require(restored->water_cellular_yield_enabled() && restored->physical_state_hash() == one.physical_state_hash(),
                "W-CY persistence lost applied policy or state");
        for(int tick=0;tick<8;++tick) { (void)one.tick();(void)restored->tick(); }
        require(restored->physical_state_hash() == one.physical_state_hash(),"W-CY continuation differs");
    }
    // Full moved mass must reach the existing Water carrying hook at every
    // precision. The enabled path carries a real grain; disabled is a control.
    for(std::uint8_t bits : std::array<std::uint8_t,2>{3,8}) {
        std::uint64_t carried = 0;
        for(int x=8;x<40;++x) {
            auto wc=config(bits,0); wc.physics_diagnostics.enabled=true;wc.transport_policy.configured=true;
            wc.transport_policy.pairs[3U*81U+2U].carrying=255;
            wc.transport_policy.pairs[3U*81U+2U].erosion=1;
            auto disabled=wc;disabled.transport_policy.pairs[3U*81U+2U].carrying=0;
            World world(wc), control(disabled);
            for(auto* item:{&world,&control}) {
                rect(*item,0,11,64,1,Material::Wall);
                rect(*item,x-1,10,3,1,Material::Wall);item->set(x,10,Material::Sand);item->set(x,9,Material::Water);
                (void)item->tick();
            }
            for(const auto& entry:world.physics_diagnostics()->entries)
                if(entry.key>>24U == static_cast<unsigned>(PhysicsEvent::GrainTransport)) carried+=entry.count;
            for(const auto& entry:control.physics_diagnostics()->entries)
                require(entry.key>>24U != static_cast<unsigned>(PhysicsEvent::GrainTransport),
                        "disabled carrying negative control transported a grain");
            require(world.water_quantity({0,0,64,16}) == world.config().water_experiment_policy.maximum(),
                    "transport did not preserve whole-cell Water moved mass");
        }
        require(carried>0,"W-CY full moved quantity never reached carrying hook");
    }
    // Rehash an otherwise valid snapshot after injecting a fractional cell, so
    // the refusal proves family ingress validation rather than checksum failure.
    World original(config()); original.set(3,4,Material::Water);
    require(original.set_cell_state(3,4,Material::Water,255,11),"snapshot marker setup");
    auto corrupted=original.save_physical_state();
    const std::array<std::uint8_t,6> marker{3,0,255,0,11,0};
    const auto at=std::search(corrupted.begin(),corrupted.end()-32,marker.begin(),marker.end());
    require(at!=corrupted.end()-32,"snapshot cell marker missing");
    at[2]=127;
    const auto digest=Sha256::of(std::span<const std::uint8_t>(corrupted.data(),corrupted.size()-32));
    std::copy(digest.begin(),digest.end(),corrupted.end()-32);
    bool rejected=false;
    try { (void)World::restore_physical_state(config(),corrupted); }
    catch(const std::invalid_argument& error) {
        rejected=std::string(error.what()).find("whole-cell Water")!=std::string::npos;
    }
    require(rejected && original.stored_state_a(3,4)==255,"fractional CYPS ingress not refused transactionally");
}

void liveness_and_cadence() {
    // A rare yield must retain a future opportunity after the quiet threshold.
    // Compare ordinary sleeping against a deliberately always-awake oracle.
    for (std::uint8_t cadence : std::array<std::uint8_t,2>{1,17})
        for (std::uint8_t horizontal : std::array<std::uint8_t,2>{1,2}) {
            auto one_config=std::make_unique<WorldConfig>(config(8,0,1,255));
            one_config->transport_policy.configured=true;
            one_config->transport_policy.cadence[3]=cadence;
            one_config->transport_policy.horizontal[3]=horizontal;
            auto four_config=std::make_unique<WorldConfig>(*one_config);
            four_config->worker_threads=4;
            auto awake_config=std::make_unique<WorldConfig>(*one_config);
            awake_config->sleep_after_quiet_ticks=100000;
            auto one=std::make_unique<World>(*one_config);
            auto four=std::make_unique<World>(*four_config);
            auto awake=std::make_unique<World>(*awake_config);
            for(auto* world:{one.get(),four.get(),awake.get()}) {
                rect(*world,6,8,6,3,Material::Wall);
                rect(*world,8,9,3,1,Material::Empty);
                world->set(8,9,Material::Water);
            }
            bool moved=false;
            for(int tick=0;tick<8192;++tick) {
                (void)one->tick();(void)four->tick();(void)awake->tick();
                compare_cells(*one,*awake,{6,8,6,3},"rare W-CY yield slept past a future opportunity");
                require(one->physical_state_hash()==four->physical_state_hash(),"rare W-CY yield worker divergence");
                moved=moved || one->stored_material(8,9)!=Material::Water;
                if(moved && tick>=64) break;
            }
            require(moved,"rare W-CY yield never exercised a successful opportunity");
        }
    // A permanently blocked source has no stochastic work to retain. Masked
    // Empty is blocked too, while due probes still report the body contact.
    auto blocked_config=std::make_unique<WorldConfig>(config(8,0,1,0));
    blocked_config->physics_diagnostics.enabled=true;
    blocked_config->transport_policy.configured=true;
    blocked_config->transport_policy.horizontal[3]=1;
    World blocked(*blocked_config);
    rect(blocked,6,8,5,3,Material::Wall);
    blocked.set(8,9,Material::Water);blocked.set(9,9,Material::Empty);
    blocked.configure_transient_obstacles({0,0,128,128});
    require(blocked.set_transient_obstacle(9,9,1),"liveness mask setup");
    std::uint64_t contacts=0,probes=0,updates=0;
    TickStats last;
    for(int tick=0;tick<16;++tick) {
        last=blocked.tick();contacts+=blocked.transient_contact_count(1);
        for(const auto& entry:blocked.physics_diagnostics()->entries) {
            if(entry.key>>24U==static_cast<unsigned>(PhysicsEvent::LateralProbe))probes+=entry.count;
            if(entry.key>>24U==static_cast<unsigned>(PhysicsEvent::WaterUpdate))updates+=entry.count;
        }
    }
    require(last.active_blocks_after==0,"enclosed W-CY source stayed awake without a legal lateral target");
    require(probes<=updates,"horizontal1 attempted more than one lateral candidate per update");
    require(contacts>0 && blocked.stored_material(9,9)==Material::Empty,"liveness scheduling lost body probe or entered mask");
}
} // namespace

void test_water_cy_admission_ingress() { admission_and_ingress(); }
void test_water_cy_coherence_masks() { coherence_viscosity_and_masks(); }
void test_water_cy_material_hooks() { material_hooks(); }
void test_water_cy_workers_persistence_transport() { workers_persistence_and_transport(); }
void test_water_cy_liveness_cadence() { liveness_and_cadence(); }
