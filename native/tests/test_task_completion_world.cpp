// Equal required native work and state under the two production pool lifetime
// policies. This is semantic qualification, not a timing benchmark.
#include "cybersand/world.hpp"

#include <array>
#include <cstdio>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <vector>

namespace {
using namespace cybersand;
unsigned checks = 0;

void require(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}

enum class Law { FreeMass, Wave, PressureReference, PressureCached, PressureDormant };

WorldConfig configuration(Law law, unsigned workers, bool actual_tasks) {
    WorldConfig config;
    config.worker_threads = workers;
    config.pubpres_task_completion_barrier = actual_tasks;
    config.parallel_job_threshold = 1;
    config.maximum_chunk_count = config.active_chunk_capacity = 128;
    config.active_core_capacity = 512;
    config.wave_flow.enabled = law == Law::Wave;
    if (config.wave_flow.enabled) {
        config.wave_flow.substeps = 2;
        config.wave_flow.body_push_by_mass = 1;
        config.wave_flow.spill.enabled = true;
        config.ballistic_water.enabled = true;
        config.ballistic_water.capacity = 64;
    }
    if (law >= Law::PressureReference) {
        auto words = LiquidSolverPolicy::default_request();
        words[21] = 3;
        words[22] = static_cast<std::int32_t>(law) - static_cast<std::int32_t>(Law::PressureReference);
        const auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(words));
        require(decoded.accepted(), "pressure reference policy construction");
        config.liquid_solver_policy = *decoded.policy;
        config.workbench_parallel_pressure_heads = true;
    }
    return config;
}

constexpr RectI64 kBounds{-64,-64,384,256};

void fill(World& world, int x, int y, int width, int height, Material material) {
    for (int row = y; row < y + height; ++row)
        for (int column = x; column < x + width; ++column) world.set(column,row,material);
}

void populate(World& world) {
    world.reserve_region(kBounds);
    world.configure_transient_obstacles(kBounds, true);
    fill(world,-64,-64,384,1,Material::Wall);
    fill(world,-64,191,384,1,Material::Wall);
    fill(world,-64,-64,1,256,Material::Wall);
    fill(world,319,-64,1,256,Material::Wall);
    fill(world,-63,140,382,51,Material::Water);
    fill(world,-48,40,88,3,Material::Wall);
    fill(world,-48,5,88,35,Material::Water);
    fill(world,50,10,30,10,Material::Sand);
    fill(world,180,35,25,8,Material::Oil);
    fill(world,240,20,12,10,Material::Mercury);
    // Sealed and vented regions keep the pressure variants substantive.
    fill(world,100,145,60,2,Material::Wall);
    fill(world,100,145,2,32,Material::Wall);
    fill(world,158,145,2,32,Material::Wall);
    fill(world,100,176,60,2,Material::Wall);
}

std::optional<BallisticLaunchResult> external_input(World& world, unsigned tick) {
    world.clear_transient_obstacles();
    if (tick % 9U == 0) world.paint_disc(70 + static_cast<int>(tick % 37U),54,3,Material::Sand);
    if (tick == 17) fill(world,170,126,35,12,Material::Water);
    if (tick == 31) fill(world,180,132,7,7,Material::Empty);
    if (tick == 33) fill(world,180,132,7,7,Material::Water);
    if (tick == 36) world.set_simulation_region(RectI64{-64,-64,256,256});
    if (tick == 47) world.set_simulation_region(RectI64{64,-64,256,256});
    if (tick == 58) world.set_simulation_region(std::nullopt);
    if (tick == 61) world.set(128,145,Material::Empty);
    const int first_x = 30 + static_cast<int>((tick * 3U) % 170U);
    const int first_y = 128 + static_cast<int>(tick % 18U);
    for (int y = first_y; y < first_y + 4; ++y)
        for (int x = first_x; x < first_x + 8; ++x)
            require(world.set_transient_obstacle(x,y,1), "first real native mask admission");
    for (int y = 153; y < 158; ++y)
        for (int x = 270 - static_cast<int>(tick % 19U); x < 277 - static_cast<int>(tick % 19U); ++x)
            require(world.set_transient_obstacle(x,y,2), "second real native mask admission");
    if (world.wave_flow_enabled() && tick % 13U == 0) {
        const auto request = world.inject_ballistic_water(230*256+128,50*256+128,128,-128,11);
        require(request.outcome == BallisticLaunchOutcome::Launched ||
                    request.outcome == BallisticLaunchOutcome::Paused ||
                    request.outcome == BallisticLaunchOutcome::CapacityFull,
                "declared ballistic input has explicit legitimate outcome");
        if (request.outcome == BallisticLaunchOutcome::CapacityFull)
            require(request.quantity == 0 && request.live == world.config().ballistic_water.capacity,
                    "capacity refusal must correspond to the actual full parcel pool");
        return request;
    }
    return std::nullopt;
}

void same_physics(const World& reference, const World& candidate, const TickStats& expected,
                  const TickStats& observed) {
    require(!reference.has_failed() && !candidate.has_failed(), "native World unexpectedly quarantined");
    require(reference.completed_tick_index() == candidate.completed_tick_index(), "real native completion differs");
    require(reference.content_hash() == candidate.content_hash(), "material content differs");
    require(reference.state_hash() == candidate.state_hash(), "retained native state differs");
    require(reference.physical_state_hash() == candidate.physical_state_hash(), "complete physical state differs");
    require(reference.quantity_ledger() == candidate.quantity_ledger(), "physical quantity or source/sink ledger differs");
    require(expected.phase_jobs == observed.phase_jobs && expected.visited_cells == observed.visited_cells &&
                expected.active_blocks_after == observed.active_blocks_after &&
                expected.scheduled_cores == observed.scheduled_cores,
            "candidate performs different required material/scheduler work");
    for (std::uint16_t body = 1; body <= 2; ++body) {
        require(reference.transient_contact_count(body) == candidate.transient_contact_count(body), "native body contact count differs");
        require(reference.transient_contact_impulse_x(body) == candidate.transient_contact_impulse_x(body) &&
                    reference.transient_contact_impulse_y(body) == candidate.transient_contact_impulse_y(body),
                "native body response differs");
    }
    if (reference.pressure_flow_enabled())
        require(reference.save_physical_state() == candidate.save_physical_state(), "portable pressure bytes differ");
}

void run(Law law) {
    std::array<std::unique_ptr<World>,4> worlds;
    const std::array<unsigned,4> workers{1,4,4,1};
    const std::array<bool,4> actual_tasks{false,false,true,true};
    for (std::size_t index = 0; index < worlds.size(); ++index) {
        worlds[index] = std::make_unique<World>(configuration(law,workers[index],actual_tasks[index]));
        populate(*worlds[index]);
    }
    std::uint64_t body_contacts = 0;
    unsigned injected = 0, capacity_refusals = 0;
    for (unsigned tick = 0; tick < 80; ++tick) {
        std::array<TickStats,4> stats;
        std::array<std::optional<BallisticLaunchResult>,4> injection;
        for (std::size_t index = 0; index < worlds.size(); ++index) {
            injection[index] = external_input(*worlds[index],tick);
            stats[index] = worlds[index]->tick();
            require(worlds[index]->completed_tick_index() == tick + 1U, "one required material turn completes per request");
        }
        if (injection[0]) {
            injected += injection[0]->outcome == BallisticLaunchOutcome::Launched;
            capacity_refusals += injection[0]->outcome == BallisticLaunchOutcome::CapacityFull;
        }
        body_contacts += worlds[0]->transient_contact_count(1) + worlds[0]->transient_contact_count(2);
        for (std::size_t index = 1; index < worlds.size(); ++index) {
            require(injection[0].has_value() == injection[index].has_value(), "injection requests differ");
            if (injection[0])
                require(injection[0]->outcome == injection[index]->outcome &&
                            injection[0]->quantity == injection[index]->quantity &&
                            injection[0]->live == injection[index]->live,
                        "actual injection/refusal receipt differs across completion modes");
            same_physics(*worlds[0],*worlds[index],stats[0],stats[index]);
        }
    }
    if (law == Law::Wave) {
        require(injected > 0, "Wave fixture never admitted a real ballistic injection");
        require(capacity_refusals > 0, "Wave fixture never exercised actual capacity refusal");
        std::printf("Wave actual injection receipts: launched=%u capacity_refused=%u\n",injected,capacity_refusals);
    }
    require(body_contacts > 0, "native parity fixture missed actual body/material contact");
    for (std::size_t index = 0; index < worlds.size(); ++index) {
        const auto diagnostics = worlds[index]->worker_pool_diagnostics();
        require(diagnostics.task_completion_barrier == actual_tasks[index], "active execution mode is not the actual World config");
        require((diagnostics.completed_dispatches > 0) == (workers[index] > 1) &&
                    (diagnostics.completed_tasks > 0) == (workers[index] > 1),
                "selected mode did not execute real parallel tasks or one-worker fallback fabricated them");
        std::printf("law=%d workers=%u actual_tasks=%u ticks=%llu dispatches=%llu tasks=%llu physical_hash=%llu\n",
                    static_cast<int>(law),workers[index],actual_tasks[index] ? 1U : 0U,
                    static_cast<unsigned long long>(worlds[index]->completed_tick_index()),
                    static_cast<unsigned long long>(diagnostics.completed_dispatches),
                    static_cast<unsigned long long>(diagnostics.completed_tasks),
                    static_cast<unsigned long long>(worlds[index]->physical_state_hash()));
    }
    require(worlds[1]->worker_pool_diagnostics().completed_dispatches == worlds[2]->worker_pool_diagnostics().completed_dispatches &&
                worlds[1]->worker_pool_diagnostics().completed_tasks == worlds[2]->worker_pool_diagnostics().completed_tasks,
            "control/treatment task dispatch quantities differ");
    // Retire pool ownership through an actual World move; its heap ParallelState
    // and current task storage remain owned until the moved owner is destroyed.
    const auto final_hash = worlds[2]->physical_state_hash();
    World moved(std::move(*worlds[2]));
    require(moved.physical_state_hash() == final_hash, "World move changed physical state");
    require(moved.worker_pool_diagnostics().task_completion_barrier, "World move lost task completion mode");
}
}  // namespace

int main() {
    try {
        for (const auto law : {Law::FreeMass,Law::Wave,Law::PressureReference,Law::PressureCached,Law::PressureDormant}) run(law);
        std::printf("PUBPRES_TASK_COMPLETION_WORLD_RESULT {\"checks\":%u,\"failures\":[]}\n",checks);
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr,"PUBPRES task-completion World failed after%u checks: %s\n",checks,error.what());
        return 1;
    }
}
