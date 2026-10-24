#include "cybersand/world.hpp"
#include "cybersand/interaction_rules.hpp"
#include "cybersand/sha256.hpp"
#include "cybersand/prepared_world.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <limits>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand;
void require(bool condition, const std::string& message) {
    if (!condition) throw std::runtime_error("quantity ledger: " + message);
}
WorldConfig config(std::uint32_t workers = 1, bool pressure = false) {
    WorldConfig result;
    result.chunk_size = 64;
    result.activity_block_size = 16;
    result.scheduling_core_size = 32;
    result.initial_chunk_reserve = 2;
    result.maximum_chunk_count = 128;
    result.active_chunk_capacity = 128;
    result.active_core_capacity = 512;
    result.worker_threads = workers;
    result.parallel_job_threshold = 1;
    if (pressure) {
        auto request = LiquidSolverPolicy::default_request();
        request[21] = 3;
        auto decoded = LiquidSolverPolicy::decode(std::span<const std::int32_t>(request));
        require(decoded.accepted(), "pressure policy admission");
        result.liquid_solver_policy = *decoded.policy;
    }
    return result;
}
void oracle(const World& world, RectI64 bounds) {
    const auto ledger = world.quantity_ledger();
    std::uint64_t visible = 0, overfill = 0;
    std::array<std::uint64_t, 256> counts{};
    for (std::int64_t y = bounds.y; y < bounds.y + bounds.height; ++y)
        for (std::int64_t x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const auto material = world.stored_material(x, y);
            if (material != Material::Empty) ++counts[static_cast<std::uint8_t>(material)];
            if (material != Material::Water) continue;
            visible += world.stored_state_a(x, y);
            overfill += world.pressure_cell(x, y).overfill;
        }
    require(visible == ledger.water_visible && overfill == ledger.water_overfill,
            "independent stored visible/overfill scan");
    require(counts == ledger.material_cells, "independent per-material cell scan");
    std::uint64_t produced = ledger.baseline_water, consumed = visible + overfill;
    for (const auto& flow : ledger.kinds) { produced += flow.produced; consumed += flow.consumed; }
    require(produced == consumed, "independent Water closure");
}
void box(World& world, int x, int y, int width, int height, Material material) {
    for (int yy = y; yy < y + height; ++yy)
        for (int xx = x; xx < x + width; ++xx) world.set(xx, yy, material);
}
const WaterQuantityFlow& kind(const QuantityLedgerSnapshot& ledger, QuantityKind value) {
    return ledger.kinds[static_cast<std::size_t>(value)];
}
void external_generated_events() {
    World world(config());
    require(world.set_cell_state(3, 3, Material::Water, 17, 0), "partial external setup");
    world.set(3, 3, Material::Water); // same identity keeps visible quantity
    require(world.set_cell_state(3, 3, Material::Water, 29, 0), "quantity-only external edit");
    world.set(4, 3, Material::Sand);
    world.configure_transient_obstacles({0, 0, 64, 64});
    require(world.set_transient_obstacle(3, 3, 1), "masked stored Water");
    require(world.liquid_mass(3, 3) == 0 && world.quantity_ledger().water_visible == 29,
            "world-wide accounting includes masked Water");
    const auto before_refusal = world.quantity_ledger();
    require(!world.set_cell_state(3, 3, Material::Water, 100, 0), "masked paint refusal");
    require(world.quantity_ledger() == before_refusal, "refusal books nothing");
    world.clear_transient_obstacles();
    world.set_simulation_region(RectI64{64, 64, 32, 32});
    (void)world.tick();
    oracle(world, {-64, -64, 256, 256});
    require(kind(world.quantity_ledger(), QuantityKind::ExternalEdit) == WaterQuantityFlow{29, 0},
            "external edits book actual delta, no same-material repaint source");
    std::vector<Material> payload(64U * 64U, Material::Empty);
    payload[3] = Material::Water; payload[4] = Material::Water; payload[5] = Material::Oil;
    require(world.install_generated_chunk({1, 0}, payload) == ChunkInstallOutcome::Installed,
            "generated chunk install");
    require(kind(world.quantity_ledger(), QuantityKind::GeneratedChunk) == WaterQuantityFlow{510, 0},
            "generated Water classified once");
    const auto after_generated = world.quantity_ledger();
    require(world.install_generated_chunk({1, 0}, payload) == ChunkInstallOutcome::AlreadyResident &&
            world.quantity_ledger() == after_generated, "generation refusal is transactional");
    world.set_simulation_region(std::nullopt);
    require(world.queue_explosion(3, 3, 1), "event queued");
    require(world.quantity_ledger() == after_generated, "future event acceptance is not a sink");
    (void)world.tick();
    require(kind(world.quantity_ledger(), QuantityKind::DeferredEvent).consumed == 29,
            "applied event sink classified separately");
    oracle(world, {-64, -64, 256, 256});
    world.clear();
    require(world.quantity_ledger().water_visible == 0 && world.quantity_ledger().material_cells ==
            std::array<std::uint64_t, 256>{}, "clear starts an empty accounting incarnation");
}
void pair_products(std::uint32_t workers) {
    for (const auto neighbor : {Material::Salt, Material::ToxicSludge, Material::Lava}) {
        World world(config(workers, true));
        box(world, 1, 1, 6, 5, Material::Wall);
        require(world.set_cell_state(3, 3, Material::Water, 17, 0), "partial pair Water");
        world.set(4, 3, neighbor);
        bool observed = false;
        for (int tick = 0; tick < 256 && !observed; ++tick) {
            (void)world.tick();
            const auto ledger = world.quantity_ledger();
            for (std::size_t i = 0; i < ledger.pair_events.size(); ++i) {
                if (ledger.pair_events[i] == 0) continue;
                observed = true;
                require(ledger.pair_events[i] == 1 && ledger.pair_rules[i].consumed == 17,
                        "reaction consumes actual partial quantity once");
                require(ledger.pair_rules[i].produced == (neighbor == Material::ToxicSludge ? 510U : 0U),
                        "same-material Water products book gross initialized source");
                require(!kPairInteractionRules[i].id.empty(), "native catalogue rule identity");
            }
            oracle(world, {0, 0, 64, 64});
        }
        require(observed, "registered pair reaction selected");
    }
}
void kernel_and_conservative(std::uint32_t workers, bool pressure) {
    World world(config(workers, pressure));
    box(world, 1, 5, 12, 1, Material::Wall);
    require(world.set_cell_state(3, 3, Material::Water, 17, 12), "gravity source");
    require(world.set_cell_state(3, 4, Material::Water, 250, 0), "gravity receiver");
    world.set(8, 3, Material::Steam);
    require(world.set_cell_state(8, 3, Material::Steam, 1, 0), "Steam at expiry");
    require(world.set_cell_state(11, 3, Material::Cloner, 0, static_cast<std::uint8_t>(Material::Water)),
            "Water Cloner");
    const auto initial = kind(world.quantity_ledger(), QuantityKind::ExternalEdit).produced;
    for (int t = 0; t < 4; ++t) {
        (void)world.tick();
        oracle(world, {-64, -64, 192, 192});
    }
    const auto ledger = world.quantity_ledger();
    require(kind(ledger, QuantityKind::ExternalEdit).produced == initial &&
            kind(ledger, QuantityKind::PairReaction) == WaterQuantityFlow{},
            "conservative motion does not double-book external or reaction Water");
    require(ledger.kernel_rules[0].produced == 255 && ledger.kernel_rules[12].produced >= 255,
            "Steam and Cloner sources retain distinct catalogue identities");
    const auto bytes = world.save_physical_state();
    auto restored = World::restore_physical_state(config(1), bytes);
    require(restored->quantity_ledger() == ledger && restored->physical_state_hash() == world.physical_state_hash(),
            "format2 restores exact accounting");
    for (int t = 0; t < 4; ++t) {
        (void)world.tick(); (void)restored->tick();
        require(restored->quantity_ledger() == world.quantity_ledger(), "1/4-worker ledger continuation");
        require(restored->physical_state_hash() == world.physical_state_hash(), "complete-state continuation");
    }
}
void pressure_overfill(std::uint32_t workers) {
    auto cfg = config(workers, true);
    cfg.chunk_size = 8; cfg.activity_block_size = 8; cfg.scheduling_core_size = 8;
    World world(cfg);
    world.set_simulation_region(RectI64{0, 400, 8, 8});
    box(world, 3, 1, 1, 400, Material::Water);
    world.set(2, 400, Material::Wall); world.set(5, 400, Material::Wall);
    box(world, 2, 401, 4, 1, Material::Wall);
    world.set(4, 400, Material::Water);
    const auto initial = world.quantity_ledger();
    (void)world.tick();
    oracle(world, {0, 0, 8, 408});
    const auto transported = world.quantity_ledger();
    require(transported.water_overfill != 0, "public pressure transport creates overfill");
    require(transported.kinds == initial.kinds, "overfill transfer has no source or sink");
    bool erased = false;
    for (int x = 3; x <= 4; ++x) if (world.pressure_cell(x, 400).overfill != 0) {
        const auto removed = static_cast<std::uint64_t>(world.stored_state_a(x, 400)) +
                             world.pressure_cell(x, 400).overfill;
        world.set(x, 400, Material::Empty);
        require(kind(world.quantity_ledger(), QuantityKind::ExternalEdit).consumed == removed,
                "external sink includes retired pressure overfill");
        erased = true;
    }
    require(erased, "erased pressure overfill owner");
    oracle(world, {0, 0, 8, 408});
}

constexpr std::size_t kLedgerBytesWithoutConstruction =
    2U + 1U + 3U * 8U + kQuantityKindCount * 16U + kQuantityPairRuleSlots * 24U +
    kQuantityKernelRuleSlots * 16U + kQuantityMaterialSlots * 16U + 1U;
std::size_t ledger_offset(const std::vector<std::uint8_t>& bytes) {
    // Format2 non-pressure fixtures: bounded fixed accounting section followed
    // by pressure-present=false and the integrity digest.
    return bytes.size() - 32U - 1U - kLedgerBytesWithoutConstruction;
}
void put64(std::vector<std::uint8_t>& bytes, std::size_t at, std::uint64_t value) {
    for (unsigned i = 0; i < 8; ++i) bytes[at + i] = static_cast<std::uint8_t>(value >> (i * 8U));
}
void seal(std::vector<std::uint8_t>& bytes) {
    const auto digest = Sha256::of(std::span<const std::uint8_t>(bytes.data(), bytes.size() - 32));
    std::copy(digest.begin(), digest.end(), bytes.end() - 32);
}
void refusal_and_overflow() {
    World original(config());
    const auto bytes = original.save_physical_state();
    const auto refuses = [&](std::vector<std::uint8_t> bad) {
        seal(bad);
        try { (void)World::restore_physical_state(config(), bad); }
        catch (const std::invalid_argument&) { return true; }
        return false;
    };
    auto bad = bytes;
    bad[4] = 1;
    require(refuses(bad), "historical format1 explicitly refused");
    bad = bytes; bad[ledger_offset(bad)] = 2;
    require(refuses(bad), "unknown accounting schema refused");
    bad = bytes; put64(bad, ledger_offset(bad) + 11U, 1U);
    require(refuses(bad), "forged actual quantity refused");
    const auto kinds_offset = ledger_offset(bytes) + 27U;
    const auto kernels_offset = kinds_offset + kQuantityKindCount * 16U + kQuantityPairRuleSlots * 24U;
    bad = bytes;
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::ExternalEdit) * 16U, 1U);
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::GeneratedChunk) * 16U + 8U, 1U);
    require(refuses(bad), "generated chunks cannot explain a Water sink");
    bad = bytes;
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::ExternalEdit) * 16U + 8U, 1U);
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::DeferredEvent) * 16U, 1U);
    require(refuses(bad), "deferred events cannot explain a Water source");
    bad = bytes;
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::ExternalEdit) * 16U + 8U, 255U);
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::KernelConversion) * 16U, 255U);
    put64(bad, kernels_offset + 16U, 255U); // Fire's registered kernel cannot produce Water.
    require(refuses(bad), "incapable kernel cannot forge balanced Water production");
    bad = bytes;
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::ExternalEdit) * 16U + 8U, 1U);
    put64(bad, kinds_offset + static_cast<std::size_t>(QuantityKind::KernelConversion) * 16U, 1U);
    put64(bad, kernels_offset, 1U); // Steam creates maximum(), never a one-unit partial product.
    require(refuses(bad), "kernel Water products retain their exact full-cell quantum");
    bad = bytes;
    const auto external = ledger_offset(bad) + 27U + 16U;
    put64(bad, external, std::numeric_limits<std::uint64_t>::max());
    put64(bad, external + 8U, std::numeric_limits<std::uint64_t>::max());
    seal(bad);
    auto full = World::restore_physical_state(config(), bad);
    const auto before = full->quantity_ledger();
    const auto before_chunks = full->chunk_count();
    const auto before_hash = full->physical_state_hash();
    bool overflow = false;
    try { full->set(3, 3, Material::Water); } catch (const std::overflow_error&) { overflow = true; }
    require(overflow && full->stored_material(3, 3) == Material::Empty && full->quantity_ledger() == before &&
            !full->has_failed() && full->chunk_count() == before_chunks &&
            full->physical_state_hash() == before_hash, "external overflow refuses before continuation state changes");
    overflow = false;
    try { (void)full->set_cell_state(3, 3, Material::Water, 17, 0); }
    catch (const std::overflow_error&) { overflow = true; }
    require(overflow && full->chunk_count() == before_chunks && full->physical_state_hash() == before_hash &&
            full->quantity_ledger() == before, "bool setter overflow also refuses before allocation");
    std::vector<Material> payload(64U * 64U, Material::Water);
    const auto chunks = full->chunk_count(); overflow = false;
    try { (void)full->install_generated_chunk({1, 0}, payload); }
    catch (const std::overflow_error&) { overflow = true; }
    require(overflow && full->chunk_count() == chunks && full->quantity_ledger() == before,
            "generated batch overflow preflights before allocation or any payload write");

    World steam(config());
    require(steam.set_cell_state(3, 3, Material::Steam, 1, 0), "overflow Steam fixture");
    auto tick_bytes = steam.save_physical_state();
    const auto tick_external = ledger_offset(tick_bytes) + 27U + 16U;
    put64(tick_bytes, tick_external, std::numeric_limits<std::uint64_t>::max());
    put64(tick_bytes, tick_external + 8U, std::numeric_limits<std::uint64_t>::max()); seal(tick_bytes);
    auto tick_full = World::restore_physical_state(config(4), tick_bytes);
    overflow = false;
    try { (void)tick_full->tick(); } catch (const std::overflow_error&) { overflow = true; }
    require(overflow && tick_full->has_failed() && tick_full->completed_tick_index() == 0,
            "worker merge overflow quarantines partial tick");
    bool read_refused = false;
    try { (void)tick_full->quantity_ledger(); } catch (const std::logic_error&) { read_refused = true; }
    require(read_refused, "failed partial ledger cannot be read as completed accounting");
}

void serial_and_phased_transactions() {
    auto serial_config = config();
    serial_config.backend = SimulationBackend::SerialInPlace;
    World serial(serial_config);
    World phased(config(4));
    const auto populate = [](World& world) {
        for (const auto x : {2, 66, 130, 194}) {
            box(world, x, 1, 3, 3, Material::Wall);
            require(world.set_cell_state(x + 1, 2, Material::Steam, 1, 0),
                    "serial/worker Steam conversion fixture");
            box(world, x, 9, 4, 3, Material::Wall);
            require(world.set_cell_state(x + 1, 10, Material::Water, 17, 0),
                    "serial/worker partial reaction input");
            world.set(x + 2, 10, Material::ToxicSludge);
            world.set(x + 2, 10, Material::ToxicSludge); // no accounting change
        }
    };
    populate(serial); populate(phased);
    require(serial.quantity_ledger() == phased.quantity_ledger(), "identical serial construction accounting");
    bool parallel_batch = false;
    for (int tick = 0; tick < 128; ++tick) {
        (void)serial.tick();
        const auto stats = phased.tick();
        parallel_batch = parallel_batch || std::any_of(stats.phase_jobs.begin(), stats.phase_jobs.end(),
            [](const auto count) { return count >= 4U; });
        require(serial.quantity_ledger() == phased.quantity_ledger(),
                "serial scalar and four-worker-configured exact per-rule accounting");
        oracle(serial, {0, 0, 256, 64}); oracle(phased, {0, 0, 256, 64});
    }
    const auto ledger = serial.quantity_ledger();
    require(parallel_batch && ledger.kernel_rules[0].produced == 4U * 255U,
            "four-worker batch and serial Steam source both executed");
    std::uint64_t events = 0;
    for (const auto count : ledger.pair_events) events += count;
    require(events == 4U && kind(ledger, QuantityKind::PairReaction) == WaterQuantityFlow{4U * 510U, 4U * 17U},
            "same-material products preserve gross pair sources and actual partial sinks");
}

void resident_serial_overflow_transaction() {
    World original(config());
    original.set(3, 3, Material::Wall); // resident writes bypass absent-chunk preflight
    auto bytes = original.save_physical_state();
    const auto kinds_offset = ledger_offset(bytes) + 27U;
    const auto external = kinds_offset + static_cast<std::size_t>(QuantityKind::ExternalEdit) * 16U;
    const auto generated = kinds_offset + static_cast<std::size_t>(QuantityKind::GeneratedChunk) * 16U;
    constexpr auto maximum = std::numeric_limits<std::uint64_t>::max();
    // Every category fits and lifetime totals equal UINT64_MAX. An external
    // source would overflow the aggregate while its own category still fits.
    put64(bytes, external, maximum - 255U);
    put64(bytes, external + 8U, maximum);
    put64(bytes, generated, 255U);
    seal(bytes);
    auto full = World::restore_physical_state(config(), bytes);
    const auto before = full->quantity_ledger();
    const auto before_hash = full->physical_state_hash();
    const auto before_bytes = full->save_physical_state();
    for (const auto bool_setter : {false, true}) {
        bool overflow = false;
        try {
            if (bool_setter) (void)full->set_cell_state(3, 3, Material::Water, 1, 0);
            else full->set(3, 3, Material::Water);
        } catch (const std::overflow_error&) { overflow = true; }
        require(overflow && !full->has_failed() && full->quantity_ledger() == before &&
                full->physical_state_hash() == before_hash && full->save_physical_state() == before_bytes &&
                full->stored_material(3, 3) == Material::Wall,
                "resident aggregate overflow commits no population, quantity, authority or continuation field");
    }
    full->set(3, 3, Material::Wall);
    require(full->quantity_ledger() == before && full->physical_state_hash() == before_hash,
            "same-visible no-op remains allowed at exhausted lifetime total");
    full->set(3, 3, Material::Sand);
    const auto replaced = full->quantity_ledger();
    require(replaced.kinds == before.kinds && replaced.pair_rules == before.pair_rules &&
            replaced.kernel_rules == before.kernel_rules && replaced.pair_events == before.pair_events &&
            replaced.material_cells[static_cast<std::uint8_t>(Material::Wall)] == 0U &&
            replaced.material_cells[static_cast<std::uint8_t>(Material::Sand)] == 1U,
            "non-Water replacement changes only its two populations at lifetime limit");
    oracle(*full, {0, 0, 64, 64});

    for (const auto backend : {SimulationBackend::SerialInPlace, SimulationBackend::PhasedInPlace}) {
        auto cfg = config(backend == SimulationBackend::SerialInPlace ? 1U : 4U);
        cfg.backend = backend;
        World steam(cfg);
        require(steam.set_cell_state(3, 3, Material::Steam, 1, 0), "serial/worker overflow fixture");
        auto tick_bytes = steam.save_physical_state();
        const auto tick_external = ledger_offset(tick_bytes) + 27U + 16U;
        put64(tick_bytes, tick_external, maximum);
        put64(tick_bytes, tick_external + 8U, maximum); seal(tick_bytes);
        auto tick_full = World::restore_physical_state(cfg, tick_bytes);
        bool overflow = false;
        try { (void)tick_full->tick(); } catch (const std::overflow_error&) { overflow = true; }
        require(overflow && tick_full->has_failed() && tick_full->completed_tick_index() == 0U,
                "serial scalar and worker merge both quarantine lifetime overflow");
    }
}

void prepared_population_binding() {
    const auto cfg = config();
    normalization::FinalSetupInput input;
    input.setup.domain = {0, 0, 8, 8};
    input.cells.push_back({3, 3, Material::Water, 17, 0, 200});
    auto result = PreparedWorldBuilder::prepare(cfg, input, normalization::NormalizationOptIn::WaterNormalizeV1);
    require(std::holds_alternative<PreparedWorld>(result), "normalized prepared population fixture");
    const auto& prepared = std::get<PreparedWorld>(result);
    const auto ledger = prepared.world().quantity_ledger();
    require(ledger.construction && ledger.construction->normalization_receipt_digest &&
            ledger.prepared_material_cells[3] == 0 && ledger.water_visible == 0,
            "down-rounded prepared Water population is distinct from original quantity");
    auto bytes = prepared.world().save_physical_state();
    constexpr std::size_t seed_bytes = 1U + 4U * 8U + 4U * 32U + 1U + 32U;
    const auto offset = bytes.size() - 32U - 1U - kLedgerBytesWithoutConstruction - seed_bytes;
    const auto prepared_cells = offset + 27U + kQuantityKindCount * 16U +
        kQuantityPairRuleSlots * 24U + kQuantityKernelRuleSlots * 16U + kQuantityMaterialSlots * 8U;
    put64(bytes, prepared_cells + 3U * 8U, 1U);
    seal(bytes);
    bool refused = false;
    try { (void)World::restore_physical_state(cfg, bytes); }
    catch (const std::invalid_argument&) { refused = true; }
    require(refused, "CYPS cannot invent a prepared Water cell incompatible with normalization mass");
}
} // namespace

void test_quantity_ledger() {
    external_generated_events();
    for (const auto workers : {1U, 4U}) {
        pair_products(workers);
        kernel_and_conservative(workers, false);
        kernel_and_conservative(workers, true);
        pressure_overfill(workers);
    }
    refusal_and_overflow();
    prepared_population_binding();
    serial_and_phased_transactions();
    resident_serial_overflow_transaction();
}
