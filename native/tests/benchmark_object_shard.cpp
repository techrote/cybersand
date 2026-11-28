#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/material_rules.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <memory>
#include <new>
#include <numeric>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

// Requested C++ allocation bytes, including over-aligned allocations. This is
// not process RSS: malloc metadata, C-library allocations, stacks and executable
// mappings are explicitly outside this instrument. Counters cover construction
// separately from the already-reserved timed sample arrays.
namespace allocation_probe {
struct Header { void* allocation; std::size_t size; };
std::atomic<std::uint64_t> allocations{}, deallocations{}, requested{}, live{}, peak{};
void* allocate(std::size_t size, std::size_t alignment) {
    const auto count = std::max(size, std::size_t{1});
    alignment = std::max(alignment, alignof(Header));
    if (count > std::numeric_limits<std::size_t>::max() - alignment - sizeof(Header))
        throw std::bad_alloc();
    auto* raw = std::malloc(count + alignment + sizeof(Header));
    if (!raw) throw std::bad_alloc();
    const auto first = reinterpret_cast<std::uintptr_t>(raw) + sizeof(Header);
    const auto aligned = (first + alignment - 1) & ~(alignment - 1);
    auto* header = reinterpret_cast<Header*>(aligned) - 1;
    *header = {raw, size};
    allocations.fetch_add(1, std::memory_order_relaxed);
    requested.fetch_add(size, std::memory_order_relaxed);
    const auto current = live.fetch_add(size, std::memory_order_relaxed) + size;
    auto maximum = peak.load(std::memory_order_relaxed);
    while (current > maximum && !peak.compare_exchange_weak(maximum, current, std::memory_order_relaxed)) {}
    return reinterpret_cast<void*>(aligned);
}
void release(void* pointer) noexcept {
    if (!pointer) return;
    const auto* header = static_cast<Header*>(pointer) - 1;
    live.fetch_sub(header->size, std::memory_order_relaxed);
    deallocations.fetch_add(1, std::memory_order_relaxed);
    std::free(header->allocation);
}
struct Snapshot { std::uint64_t allocations, deallocations, requested, live, peak; };
Snapshot snapshot() noexcept { return {allocations.load(), deallocations.load(), requested.load(), live.load(), peak.load()}; }
void begin_interval() noexcept { peak.store(live.load()); }
}
void* operator new(std::size_t n) { return allocation_probe::allocate(n, alignof(std::max_align_t)); }
void* operator new[](std::size_t n) { return ::operator new(n); }
void* operator new(std::size_t n, std::align_val_t a) { return allocation_probe::allocate(n, static_cast<std::size_t>(a)); }
void* operator new[](std::size_t n, std::align_val_t a) { return ::operator new(n, a); }
void operator delete(void* p) noexcept { allocation_probe::release(p); }
void operator delete[](void* p) noexcept { allocation_probe::release(p); }
void operator delete(void* p, std::size_t) noexcept { allocation_probe::release(p); }
void operator delete[](void* p, std::size_t) noexcept { allocation_probe::release(p); }
void operator delete(void* p, std::align_val_t) noexcept { allocation_probe::release(p); }
void operator delete[](void* p, std::align_val_t) noexcept { allocation_probe::release(p); }
void operator delete(void* p, std::size_t, std::align_val_t) noexcept { allocation_probe::release(p); }
void operator delete[](void* p, std::size_t, std::align_val_t) noexcept { allocation_probe::release(p); }

// Native benchmarks acknowledge the exact protocol identities, but do not own
// RIDs. No result from this executable constitutes real physics installation.
namespace cybersand::object_shard {
struct CoordinatorTestAccess {
    static World& world(Coordinator& coordinator) { return *coordinator.world_; }
    static Registry& registry(Coordinator& coordinator) { return coordinator.registry_; }
    static std::span<const BodyView> bodies(const Coordinator& coordinator) { return coordinator.bodies_; }
    static void material_domain_step(Coordinator& coordinator) {
        coordinator.advance_chemistry();
        coordinator.advance_products_and_exchange();
    }
};
}
namespace cybersand {
class PrecisionProbe {
public:
    static void clock(World& world, std::uint64_t tick) {
        world.tick_index_ = tick; world.completed_tick_index_ = tick;
        world.update_epoch_ = static_cast<std::uint8_t>(tick);
    }
    // Minimal exclusive-owner boundary for the alternative implementation.
    // Both cell stores and temperatures are reserved before these writes. This
    // fixture has no concurrent command admission, queues, retries or RIDs.
    static bool move_product(World& source, World& destination, std::int64_t x, std::int64_t y) {
        const auto material = source.stored_material(x, y);
        if ((material != Material::Fire && material != Material::Smoke) ||
            destination.stored_material(x, y) != Material::Empty || destination.transient_obstacle_at(x, y)) return false;
        const auto a = source.stored_state_a(x, y);
        const auto b = source.stored_state_b(x, y);
        const auto temperature = source.stored_temperature(x, y);
        if (!destination.write_cell(x, y, material, a, b, nullptr, false)) return false;
        destination.set_temperature(x, y, temperature);
        return source.write_cell(x, y, Material::Empty, 0, 0, nullptr, false);
    }
    static void remove_captured(World& world, std::int64_t x, std::int64_t y) {
        (void)world.write_cell(x, y, Material::Empty, 0, 0, nullptr, false);
    }
};
}

namespace {
using namespace cybersand;
using namespace cybersand::object_shard;
using Clock = std::chrono::steady_clock;
using Nanoseconds = std::chrono::nanoseconds;
std::uint64_t checks{};
void require(bool condition, const char* description) {
    ++checks;
    if (!condition) throw std::runtime_error(description);
}
void accepted(Result result, const char* description) {
    if (result.outcome != Outcome::Accepted)
        std::fprintf(stderr, "%s: %s (%s)\n", description, outcome_name(result.outcome), result.detail);
    require(result.outcome == Outcome::Accepted, description);
}
std::uint64_t elapsed(Clock::time_point start) {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<Nanoseconds>(Clock::now() - start).count());
}
struct Samples {
    std::vector<std::uint64_t> values;
    explicit Samples(std::size_t capacity) { values.reserve(capacity); }
    void add(std::uint64_t value) { values.push_back(value); }
    void print(const char* name) {
        std::sort(values.begin(), values.end());
        const auto quantile = [&](double p) -> double {
            if (values.empty()) return 0;
            const auto at = static_cast<std::size_t>(std::ceil(p * static_cast<double>(values.size()))) - 1;
            return static_cast<double>(values[std::min(at, values.size() - 1)]) / 1000.;
        };
        const auto total = std::accumulate(values.begin(), values.end(), std::uint64_t{});
        const auto mean = values.empty() ? 0. : static_cast<double>(total) / static_cast<double>(values.size()) / 1000.;
        std::printf("\"%s\":{\"samples\":%zu,\"mean_us\":%.3f,\"p50_us\":%.3f,\"p95_us\":%.3f,\"p99_us\":%.3f,\"max_us\":%.3f}",
            name, values.size(), mean, quantile(.5), quantile(.95), quantile(.99), quantile(1));
    }
};

Payload empty() { return {Material::Empty, 0, 0, 200}; }
Acknowledgement promotion_ack(Coordinator& coordinator, AckKind kind) {
    const auto& promotion = coordinator.snapshot().promotion;
    const auto* shard = coordinator.registry().find(promotion.shard);
    require(promotion.present && shard, "promotion snapshot contains its shard");
    const auto& g = shard->geometry();
    return {promotion.shard, promotion.transaction, promotion.shard.generation,
        promotion.payload_digest, g.revision, g.mask_digest, g.shape_digest, kind,
        kind == AckKind::TerrainInstalled ? promotion.terrain : std::span<const TerrainReceipt>{}};
}
Handle promote_one(Coordinator& coordinator) {
    Result result;
    const auto limit = coordinator.config().world_bounds.area() / coordinator.config().discovery_budget + 128;
    for (std::size_t attempt = 0; attempt < limit; ++attempt) {
        result = coordinator.prepare_next();
        if (result.outcome == Outcome::Accepted) break;
        require(result.outcome == Outcome::Busy || result.outcome == Outcome::Anchored,
            "ordinary support discovery did not fail");
    }
    accepted(result, "ordinary support loss prepares complete component");
    for (const auto kind : {AckKind::PhysicsReserved, AckKind::TerrainInstalled, AckKind::BodyActivated})
        accepted(coordinator.acknowledge(promotion_ack(coordinator, kind)), "native promotion acknowledgement");
    require(!coordinator.paused(), "activation releases native barrier");
    return result.shard;
}
void acknowledge_geometry(Coordinator& coordinator) {
    // No vector growth, resource creation or PhysicsServer calls are modelled.
    for (const auto& b : CoordinatorTestAccess::bodies(coordinator)) {
        if (!b.geometry_pending) continue;
        const auto* shard = coordinator.registry().find(b.shard);
        require(shard != nullptr, "geometry owner remains live");
        const auto& g = shard->geometry();
        const auto kind = shard->counts().structural == 0 ? AckKind::BodyRetired : AckKind::GeometryInstalled;
        accepted(coordinator.acknowledge({b.shard, b.transaction, b.body_generation, shard->payload_digest(),
            g.revision, g.mask_digest, g.shape_digest, kind, {}}), "native geometry acknowledgement");
    }
}
void cut_trees(Coordinator& coordinator, unsigned count) {
    const auto bounds = coordinator.config().world_bounds;
    const auto floor = bounds.y + bounds.height - 18;
    for (unsigned i = 0; i < count; ++i) {
        const auto x = bounds.x + (count == 1 ? bounds.width / 2 : (i + 1) * bounds.width / 4);
        for (int dx = -2; dx <= 1; ++dx) accepted(coordinator.edit(x + dx, floor - 6, empty()), "ordinary trunk erase");
    }
    for (unsigned i = 0; i < count; ++i) (void)promote_one(coordinator);
}
void prepare_dormant(Coordinator& coordinator, unsigned count) {
    for (unsigned i = 0; i < count; ++i) {
        const auto x = 20 + static_cast<std::int64_t>(i % 6) * 26;
        const auto y = 20 + static_cast<std::int64_t>(i / 6) * 32;
        for (int dy = 0; dy < 3; ++dy) for (int dx = 0; dx < 3; ++dx)
            accepted(coordinator.edit(x + dx, y + dy, {Material::Wood, 0, 0, 200}), "author dormant Wood fixture");
        for (int dx = 0; dx < 3; ++dx) accepted(coordinator.edit(x + dx, y + 3, {Material::Wall, 0, 0, 200}), "author support");
    }
    for (unsigned i = 0; i < count; ++i) {
        const auto x = 20 + static_cast<std::int64_t>(i % 6) * 26;
        const auto y = 20 + static_cast<std::int64_t>(i / 6) * 32;
        for (int dx = 0; dx < 3; ++dx) accepted(coordinator.edit(x + dx, y + 3, empty()), "ordinary support erase");
    }
    for (unsigned i = 0; i < count; ++i) (void)promote_one(coordinator);
}
void wake_all(Coordinator& coordinator) {
    for (const auto& shard : coordinator.registry().shards()) if (shard.chemistry_allowed()) {
        for (std::size_t cell = 0; cell < shard.area(); ++cell) if (shard.payload(cell).material == Material::Wood) {
            accepted(coordinator.ignite_shard(shard.handle(), static_cast<std::uint32_t>(cell)), "wake dormant Wood");
            break;
        }
    }
}

struct Case { const char* name; std::uint32_t scenario; unsigned bodies; bool moving, wake, saturated; };
constexpr std::array<Case, 9> kCases{{
    {"empty_lab", 0, 0, false, false, false},
    {"inert_stationary", 1, 1, false, false, false},
    {"inert_moving", 1, 1, true, false, false},
    {"reacting_one", 2, 1, false, false, false},
    {"reacting_three", 4, 3, false, false, false},
    {"perforated_reacting", 5, 1, false, true, false},
    {"saturated_world_destinations", 2, 1, false, false, true},
    {"dormant_twelve", 0, 12, false, false, false},
    {"wake_burst_twelve", 0, 12, false, true, false},
}};

void run_case(const Case& test, unsigned ticks, unsigned repetitions) {
    const auto sample_count = static_cast<std::size_t>(ticks) * repetitions;
    Samples construction(repetitions), promotion(repetitions), discovery(repetitions), step(sample_count), world(sample_count),
        chemistry(sample_count), contact(sample_count), occupancy(sample_count), geometry(sample_count),
        terrain(sample_count), exchange(sample_count), relocation(sample_count),
        snapshot(sample_count), acknowledgement(sample_count), frame(sample_count), wake(repetitions);
    std::uint64_t construction_allocations{}, construction_requested{}, steady_allocations{}, steady_requested{};
    std::uint64_t live_cpp_max{}, peak_cpp_max{}, retained_native_max{}, world_cells_max{}, registry_retained_max{};
    std::uint64_t native_pause_max{}, geometry_wait_max{}, geometry_age_max{}, product_age_max{}, shapes_max{}, products_created{}, output_blocked{};
    std::uint64_t fire_emitted{}, smoke_emitted{}, chemistry_cells{}, final_structural{}, final_products{}, final_cargo{};
    std::uint64_t source_smoke_samples{};
    for (unsigned repetition = 0; repetition < repetitions; ++repetition) {
        Config config;
        config.scenario = test.scenario;
        if (test.bodies > 3) {
            config.limits.max_shards = test.bodies;
            config.limits.max_area = 64;
            config.limits.max_total_area = test.bodies * 64;
            config.limits.max_shapes = 64;
        }
        allocation_probe::begin_interval();
        const auto allocation_start = allocation_probe::snapshot();
        auto started = Clock::now();
        auto coordinator = std::make_unique<Coordinator>(config);
        construction.add(elapsed(started));
        started = Clock::now();
        const auto discovery_before = coordinator->metrics().discovery_ns;
        if (test.bodies > 3) prepare_dormant(*coordinator, test.bodies);
        else if (test.bodies) cut_trees(*coordinator, test.bodies);
        if (test.saturated) {
            for (const auto& shard : coordinator->registry().shards()) if (shard.owns_inventory()) {
                const auto bounds = shard.bounds();
                for (std::size_t cell = 0; cell < shard.area(); ++cell) if (!shard.occupied(cell)) {
                    const auto x = bounds.x + static_cast<std::int64_t>(cell % bounds.width);
                    const auto y = bounds.y + static_cast<std::int64_t>(cell / bounds.width);
                    accepted(coordinator->edit(x, y, {Material::Wall, 0, 0, 200}), "fill actual external product destinations");
                }
            }
        }
        promotion.add(elapsed(started));
        discovery.add(coordinator->metrics().discovery_ns - discovery_before);
        if (test.scenario == 5) wake_all(*coordinator);
        const auto constructed = allocation_probe::snapshot();
        construction_allocations += constructed.allocations - allocation_start.allocations;
        construction_requested += constructed.requested - allocation_start.requested;
        live_cpp_max = std::max(live_cpp_max, constructed.live - allocation_start.live);
        peak_cpp_max = std::max(peak_cpp_max, constructed.peak - allocation_start.live);

        std::array<PoseSample, kMaximumShards> poses{};
        std::array<PoseSample, kMaximumShards> anchors{};
        for (std::size_t i = 0; i < CoordinatorTestAccess::bodies(*coordinator).size(); ++i)
            anchors[i] = CoordinatorTestAccess::bodies(*coordinator)[i].pose;
        allocation_probe::begin_interval();
        const auto steady_start = allocation_probe::snapshot();
        for (unsigned tick = 0; tick < ticks; ++tick) {
            const auto frame_started = Clock::now();
            if (test.wake && test.bodies > 3 && tick == ticks / 2) {
                started = Clock::now(); wake_all(*coordinator); wake.add(elapsed(started));
            }
            std::size_t pose_count = 0;
            const auto bodies = CoordinatorTestAccess::bodies(*coordinator);
            for (std::size_t i = 0; i < bodies.size(); ++i) if (bodies[i].has_body) {
                auto pose = bodies[i].pose;
                ++pose.pose_serial;
                pose.sleeping = !test.moving;
                if (test.moving) {
                    // Bounded benchmark pose input, not simulated rigid motion.
                    const auto phase = static_cast<double>(tick + 1) * .02;
                    pose.x = anchors[i].x + .025 * std::sin(phase);
                    pose.y = anchors[i].y - .05 * (1 - std::cos(phase));
                    pose.rotation = .0005 * std::sin(phase);
                }
                poses[pose_count++] = pose;
            }
            const auto before = coordinator->metrics();
            started = Clock::now();
            accepted(coordinator->step(std::span<const PoseSample>(poses.data(), pose_count)), "native benchmark step");
            step.add(elapsed(started));
            const auto after = coordinator->metrics();
            world.add(after.world_ns - before.world_ns);
            chemistry.add(after.chemistry_ns - before.chemistry_ns);
            contact.add(after.contact_ns - before.contact_ns);
            occupancy.add(after.occupancy_ns - before.occupancy_ns);
            geometry.add(after.geometry_ns - before.geometry_ns);
            terrain.add(after.terrain_ns - before.terrain_ns);
            exchange.add(after.exchange_ns - before.exchange_ns);
            relocation.add(after.relocation_ns - before.relocation_ns);
            started = Clock::now(); acknowledge_geometry(*coordinator); acknowledgement.add(elapsed(started));
            started = Clock::now(); const auto& view = coordinator->snapshot(); snapshot.add(elapsed(started));
            retained_native_max = std::max(retained_native_max, static_cast<std::uint64_t>(view.metrics.retained_bytes));
            world_cells_max = std::max(world_cells_max, static_cast<std::uint64_t>(view.metrics.world_bytes));
            registry_retained_max = std::max(registry_retained_max,
                static_cast<std::uint64_t>(coordinator->registry().memory_usage().retained_bytes));
            for (const auto& shard : coordinator->registry().shards()) if (shard.owns_inventory())
                shapes_max = std::max(shapes_max, static_cast<std::uint64_t>(shard.geometry().shapes.size()));
            source_smoke_samples += coordinator->world().quantity_ledger().material_cells[static_cast<std::size_t>(Material::Smoke)];
            require(!view.quarantined && !view.paused, "native frame exits with bounded applied geometry");
            frame.add(elapsed(frame_started));
        }
        const auto steady_end = allocation_probe::snapshot();
        steady_allocations += steady_end.allocations - steady_start.allocations;
        steady_requested += steady_end.requested - steady_start.requested;
        live_cpp_max = std::max(live_cpp_max, steady_end.live - allocation_start.live);
        peak_cpp_max = std::max(peak_cpp_max, steady_end.peak - allocation_start.live);
        const auto& metrics = coordinator->metrics();
        native_pause_max = std::max(native_pause_max, metrics.maximum_pause_ns);
        geometry_wait_max = std::max(geometry_wait_max, metrics.maximum_geometry_wait_ns);
        geometry_age_max = std::max(geometry_age_max, metrics.maximum_geometry_age);
        product_age_max = std::max(product_age_max, metrics.maximum_product_age);
        products_created += metrics.products_created;
        output_blocked += metrics.output_blocked;
        chemistry_cells += metrics.chemistry_cells;
        fire_emitted += coordinator->accounting().emitted[static_cast<std::size_t>(Material::Fire)];
        smoke_emitted += coordinator->accounting().emitted[static_cast<std::size_t>(Material::Smoke)];
        const auto counts = coordinator->registry().inventory_counts();
        final_structural += counts.structural; final_products += counts.products; final_cargo += counts.cargo;
        require(metrics.promotions == test.bodies, "requested native shard population actually promoted");
    }
    if (test.scenario == 2 || test.scenario == 4) {
        require(products_created > 0, "reacting benchmark creates actual Wood products");
        if (!test.saturated)
            require(fire_emitted > 0 && source_smoke_samples > 0, "reacting benchmark delivers real Fire followed by World Smoke");
    }
    if (test.saturated) require(output_blocked > 0 && final_products > 0, "saturated output retains real material inventory");
    if (test.scenario == 5) require(shapes_max > 8, "perforated geometry exceeds historical eight-shape envelope");
    std::printf("{\"name\":\"%s\",\"scope\":\"native_integrated_synthetic_pose_and_receipts\",\"repetitions\":%u,\"ticks_per_repetition\":%u,\"timings\":{",
        test.name, repetitions, ticks);
    construction.print("construction"); std::printf(","); promotion.print("promotion_and_fixture_admission"); std::printf(",");
    discovery.print("discovery"); std::printf(",");
    step.print("coordinator_step"); std::printf(","); world.print("world"); std::printf(",");
    chemistry.print("chemistry"); std::printf(","); contact.print("contact"); std::printf(",");
    occupancy.print("occupancy_inclusive"); std::printf(","); geometry.print("shard_geometry"); std::printf(",");
    terrain.print("terrain_geometry"); std::printf(","); exchange.print("product_exchange"); std::printf(",");
    relocation.print("overlap_relocation"); std::printf(",");
    acknowledgement.print("synthetic_geometry_receipt"); std::printf(","); snapshot.print("native_snapshot"); std::printf(",");
    frame.print("native_frame_including_snapshot_receipt"); std::printf(","); wake.print("wake_burst");
    std::printf("},\"memory\":{\"cpp_live_max_bytes\":%llu,\"cpp_peak_max_bytes\":%llu,\"native_reported_retained_max_bytes\":%llu,\"registry_retained_max_bytes\":%llu,\"world_cell_storage_max_bytes\":%llu,\"construction_allocations\":%llu,\"construction_requested_bytes\":%llu,\"steady_allocations\":%llu,\"steady_requested_bytes\":%llu},",
        static_cast<unsigned long long>(live_cpp_max), static_cast<unsigned long long>(peak_cpp_max),
        static_cast<unsigned long long>(retained_native_max), static_cast<unsigned long long>(registry_retained_max),
        static_cast<unsigned long long>(world_cells_max), static_cast<unsigned long long>(construction_allocations),
        static_cast<unsigned long long>(construction_requested), static_cast<unsigned long long>(steady_allocations),
        static_cast<unsigned long long>(steady_requested));
    std::printf("\"observations\":{\"products_created\":%llu,\"fire_emitted\":%llu,\"smoke_emitted\":%llu,\"world_smoke_cell_samples\":%llu,\"output_blocked_attempts\":%llu,\"chemistry_cells\":%llu,\"shapes_max_per_body\":%llu,\"promotion_pause_max_us\":%.3f,\"geometry_wait_max_us\":%.3f,\"geometry_age_max_ticks\":%llu,\"product_age_max_ticks\":%llu,\"final_structural_sum\":%llu,\"final_products_sum\":%llu,\"final_cargo_sum\":%llu}}",
        static_cast<unsigned long long>(products_created), static_cast<unsigned long long>(fire_emitted),
        static_cast<unsigned long long>(smoke_emitted), static_cast<unsigned long long>(source_smoke_samples),
        static_cast<unsigned long long>(output_blocked), static_cast<unsigned long long>(chemistry_cells),
        static_cast<unsigned long long>(shapes_max), static_cast<double>(native_pause_max) / 1000.,
        static_cast<double>(geometry_wait_max) / 1000.,
        static_cast<unsigned long long>(geometry_age_max), static_cast<unsigned long long>(product_age_max),
        static_cast<unsigned long long>(final_structural), static_cast<unsigned long long>(final_products),
        static_cast<unsigned long long>(final_cargo));
}

WorldConfig miniature_config() {
    WorldConfig config;
    config.backend = SimulationBackend::SerialInPlace;
    config.worker_threads = 1;
    config.chunk_size = 8;
    config.activity_block_size = 4;
    config.scheduling_core_size = 8;
    config.initial_chunk_reserve = 4;
    config.maximum_chunk_count = 16;
    config.active_chunk_capacity = 16;
    config.active_core_capacity = 16;
    config.deferred_event_capacity = 4;
    return config;
}
Payload tuple(const World& world, std::int64_t x, std::int64_t y) {
    return {world.stored_material(x, y), world.stored_state_a(x, y),
        world.stored_state_b(x, y), world.stored_temperature(x, y)};
}
void compare_domains(unsigned repetitions) {
    // The equivalence envelope is deliberate: a stationary burning Wood cell,
    // the same semantic/random anchor, immediate physical-port output, and an
    // identical external World. Fire evolves to Smoke in that external World.
    // No internal transport is needed; retained-gas transport is NOT equivalent
    // and is not smuggled into a benchmark of the admitted compact capability.
    constexpr std::int64_t x = 30, y = 30;
    constexpr unsigned ticks = 64;
    const auto count = static_cast<std::size_t>(ticks) * repetitions;
    Samples compact_time(count), miniature_time(count), common_world_time(count * 2),
        compact_construction(repetitions), miniature_construction(repetitions);
    std::uint64_t compact_bytes{}, compact_cpp_bytes{}, miniature_bytes{}, miniature_cell_bytes{},
        compact_construction_allocations{}, miniature_construction_allocations{};
    std::uint64_t compact_allocations{}, miniature_allocations{}, products{}, smoke_samples{};
    for (unsigned repetition = 0; repetition < repetitions; ++repetition) {
        Config config;
        config.scenario = 0; config.world_bounds = {0, 0, 64, 64};
        config.limits.max_shards = 1; config.limits.max_area = 9;
        config.limits.max_total_area = 9; config.limits.max_shapes = 8;
        Coordinator compact(config), alternative_external(config);
        const Payload wood{Material::Wood, 170, 240, 600};
        for (auto* owner : {&compact, &alternative_external}) {
            accepted(owner->edit(x, y, wood), "comparison authors identical burning Wood");
            accepted(owner->edit(x, y + 1, {Material::Wall, 0, 0, 200}), "comparison support");
            accepted(owner->edit(x, y + 1, empty()), "comparison ordinary support loss");
        }
        const auto handle = promote_one(compact);
        auto& external = CoordinatorTestAccess::world(alternative_external);
        PrecisionProbe::remove_captured(external, x, y);
        require(external.set_transient_obstacle(x, y, 1), "alternative uses equal fixed external occupancy");

        // Isolate allocation/construction of the selected compact carrier using
        // the real Registry preparation and exact geometry path. Chemistry below
        // still runs the integrated production Coordinator, not this carrier.
        {
            const auto before = allocation_probe::snapshot();
            const auto start = Clock::now();
            auto carrier = std::make_unique<Registry>(config.limits, 1, 1);
            Handle prepared;
            require(carrier->prepare({x - 1, y - 1, 3, 3}, compact.world().completed_tick_index(), prepared) == Outcome::Accepted,
                "compact comparison carrier admits exact bounding box");
            require(carrier->find(prepared)->set_cell(4, wood, Role::Structural,
                compact.world().completed_tick_index()) == Outcome::Accepted, "compact comparison captures exact Wood tuple");
            require(carrier->finish_preparation(prepared) == Outcome::Accepted, "compact comparison constructs real geometry");
            compact_construction.add(elapsed(start));
            const auto after = allocation_probe::snapshot();
            compact_cpp_bytes = std::max(compact_cpp_bytes, after.live - before.live);
            compact_construction_allocations += after.allocations - before.allocations;
        }

        const auto memory_before = allocation_probe::snapshot();
        auto started = Clock::now();
        auto miniature = std::make_unique<World>(miniature_config());
        miniature->reserve_region({x - 1, y - 1, 3, 3});
        miniature->reserve_temperature_region({x - 1, y - 1, 3, 3});
        miniature->set_simulation_region(RectI64{x - 1, y - 1, 3, 3});
        PrecisionProbe::clock(*miniature, compact.world().completed_tick_index());
        (void)miniature->set_cell_state(x, y, wood.material, wood.state_a, wood.state_b);
        miniature->set_temperature(x, y, wood.temperature);
        miniature_construction.add(elapsed(started));
        const auto memory_after = allocation_probe::snapshot();
        miniature_bytes = std::max(miniature_bytes, memory_after.live - memory_before.live);
        miniature_construction_allocations += memory_after.allocations - memory_before.allocations;
        miniature_cell_bytes = std::max(miniature_cell_bytes, static_cast<std::uint64_t>(miniature->resident_cell_bytes()));
        compact_bytes = std::max(compact_bytes, static_cast<std::uint64_t>(compact.registry().memory_usage().retained_bytes));
        auto* shard = CoordinatorTestAccess::registry(compact).find(handle);
        require(shard && shard->bounds() == Bounds{x - 1, y - 1, 3, 3}, "comparison has identical bounded local payload");
        for (unsigned tick = 0; tick < ticks; ++tick) {
            // Common external simulation is outside the material-domain timer,
            // executed once per semantic tick on both sides and reported apart.
            started = Clock::now(); (void)CoordinatorTestAccess::world(compact).tick(); common_world_time.add(elapsed(started));
            started = Clock::now(); (void)external.tick(); common_world_time.add(elapsed(started));
            const auto run_compact = [&] {
                const auto before = allocation_probe::snapshot();
                const auto start = Clock::now();
                CoordinatorTestAccess::material_domain_step(compact);
                compact_time.add(elapsed(start));
                compact_allocations += allocation_probe::snapshot().allocations - before.allocations;
            };
            const auto run_miniature = [&] {
                const auto before = allocation_probe::snapshot();
                const auto start = Clock::now();
                (void)miniature->tick();
                for (auto wy = y - 1; wy <= y + 1; ++wy) for (auto wx = x - 1; wx <= x + 1; ++wx) {
                    const auto material = miniature->stored_material(wx, wy);
                    if (material == Material::Fire || material == Material::Smoke)
                        require(PrecisionProbe::move_product(*miniature, external, wx, wy), "comparison output remains immediately admissible");
                }
                miniature_time.add(elapsed(start));
                miniature_allocations += allocation_probe::snapshot().allocations - before.allocations;
            };
            if ((tick + repetition) % 2 == 0) { run_compact(); run_miniature(); }
            else { run_miniature(); run_compact(); }
            require(!compact.snapshot().quarantined, "actual compact coordinator remains healthy");
            require(shard->counts().products == 0, "comparison compact output remains immediately admissible");
            require(compact.world().completed_tick_index() == miniature->completed_tick_index(), "domain semantic clocks agree");
            for (std::size_t cell = 0; cell < shard->area(); ++cell) {
                const auto wx = shard->bounds().x + static_cast<std::int64_t>(cell % shard->bounds().width);
                const auto wy = shard->bounds().y + static_cast<std::int64_t>(cell / shard->bounds().width);
                require(shard->payload(cell) == tuple(*miniature, wx, wy), "actual compact and mini-World material tuples agree every tick");
            }
            for (std::int64_t wy = 0; wy < 64; ++wy) for (std::int64_t wx = 0; wx < 64; ++wx)
                require(tuple(compact.world(), wx, wy) == tuple(external, wx, wy), "equal outputs produce identical actual external World tuples");
            smoke_samples += compact.world().quantity_ledger().material_cells[static_cast<std::size_t>(Material::Smoke)];
        }
        products += compact.accounting().emitted[static_cast<std::size_t>(Material::Fire)];
        require(compact.metrics().output_blocked == 0, "comparison does not hide unavailable destinations");
    }
    require(products > 0 && smoke_samples > 0, "comparison executes real Fire delivery and downstream World Smoke");
    std::printf("{\"name\":\"compact_vs_tuned_serial_miniature\",\"scope\":\"native_material_domain_with_actual_output_excludes_common_World_physics_render\",\"equivalence\":\"every_local_and_external_payload_each_tick\",\"ticks_per_repetition\":%u,\"repetitions\":%u,\"miniature_configuration\":{\"chunk_size\":8,\"activity_block_size\":4,\"backend\":\"SerialInPlace\",\"workers\":1,\"maximum_chunks\":16,\"deferred_events\":4},\"timings\":{", ticks, repetitions);
    compact_time.print("actual_compact_chemistry_and_emission"); std::printf(",");
    miniature_time.print("actual_serial_World_and_minimal_boundary_adapter"); std::printf(",");
    common_world_time.print("common_external_World_tick"); std::printf(",");
    compact_construction.print("compact_carrier_construction_and_geometry"); std::printf(",");
    miniature_construction.print("miniature_construction");
    std::printf("},\"memory\":{\"compact_registry_including_shared_scratch_bytes\":%llu,\"compact_carrier_Cpp_live_bytes\":%llu,\"miniature_World_Cpp_live_bytes\":%llu,\"miniature_cell_storage_bytes\":%llu,\"compact_construction_allocations\":%llu,\"miniature_construction_allocations\":%llu,\"compact_steady_allocations\":%llu,\"miniature_steady_allocations\":%llu},\"observations\":{\"fire_deliveries\":%llu,\"World_smoke_cell_samples\":%llu}}",
        static_cast<unsigned long long>(compact_bytes), static_cast<unsigned long long>(compact_cpp_bytes),
        static_cast<unsigned long long>(miniature_bytes), static_cast<unsigned long long>(miniature_cell_bytes),
        static_cast<unsigned long long>(compact_construction_allocations), static_cast<unsigned long long>(miniature_construction_allocations),
        static_cast<unsigned long long>(compact_allocations), static_cast<unsigned long long>(miniature_allocations),
        static_cast<unsigned long long>(products), static_cast<unsigned long long>(smoke_samples));
}
}

int main(int argc, char** argv) {
    try {
        unsigned ticks = 480, repetitions = 3;
        std::string_view only;
        for (int i = 1; i < argc; ++i) {
            const std::string_view argument = argv[i];
            if ((argument == "--ticks" || argument == "--repetitions" || argument == "--case") && i + 1 < argc) {
                if (argument == "--case") only = argv[++i];
                else {
                    const auto number = std::stoul(argv[++i]);
                    require(number > 0 && number <= 10000, "benchmark bound is positive and finite");
                    if (argument == "--ticks") ticks = static_cast<unsigned>(number);
                    else repetitions = static_cast<unsigned>(number);
                }
            } else throw std::invalid_argument("usage: benchmark_object_shard [--ticks N] [--repetitions N] [--case NAME]");
        }
        require(static_cast<std::uint64_t>(ticks) * repetitions <= 100000, "benchmark sample budget");
        std::printf("{\"schema\":1,\"scope\":\"Linux_or_Windows_native_CPP_only\",\"physics\":\"synthetic_pose_and_ACK_no_Rapier\",\"allocation_scope\":\"requested_C++_new_bytes_not_RSS\",\"timer_semantics\":\"nested_inclusive_counters_must_not_be_summed_as_disjoint_costs\",\"cases\":[");
        bool comma = false;
        for (const auto& test : kCases) if (only.empty() || only == test.name) {
            if (comma) std::printf(",");
            run_case(test, ticks, repetitions); comma = true;
        }
        if (only.empty() || only == "compact_vs_tuned_serial_miniature") {
            if (comma) std::printf(",");
            compare_domains(std::max(16U, repetitions)); comma = true;
        }
        require(comma, "selected benchmark case exists");
        std::printf("],\"checks\":%llu,\"failures\":0}\n", static_cast<unsigned long long>(checks));
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "ObjectShard native benchmark failed: %s\n", error.what());
        return 1;
    }
}
