#include "cybersand/settled_discovery.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using namespace cybersand::soliding;
using Journal = SettledDiscovery<4096, 1024>;
using Clock = std::chrono::steady_clock;
constexpr DiscoveryCell tuple{1, 17, 29, 200, false};
constexpr DiscoverySignals signals{true, true, true, false, false, false};
void check(bool pass, const char* reason) { if (!pass) throw std::runtime_error(reason); }
double ms(Clock::time_point start) { return std::chrono::duration<double, std::milli>(Clock::now() - start).count(); }
std::uint32_t integer(const char* value, std::uint32_t maximum) {
    char* end = nullptr;
    const auto parsed = std::strtoull(value, &end, 10);
    check(end != value && *end == '\0' && parsed > 0 && parsed <= maximum, "invalid positive argument");
    return static_cast<std::uint32_t>(parsed);
}
// Retain an actual service invocation in idle timing; call overhead is included.
[[gnu::noinline]] std::size_t service(Journal& journal, std::uint64_t epoch, std::size_t budget,
                                      const std::vector<DiscoveryCell>& source, std::uint32_t side) {
    return journal.advance(epoch, budget, [&](std::int64_t x, std::int64_t y) {
        return source[static_cast<std::size_t>(y) * side + static_cast<std::size_t>(x)];
    });
}
struct Phase {
    const char* name;
    double elapsed_ms{}, producer_ms{};
    std::uint64_t epochs{}, longest_drain{};
    std::size_t pending_before{}, pending_after{};
    DiscoveryMetrics before{}, after{};
};
void emit(const Phase& p) {
    const auto& a = p.after; const auto& b = p.before;
    std::cout << "{\"name\":\"" << p.name << "\",\"elapsed_ms\":" << p.elapsed_ms
        << ",\"producer_ms\":" << p.producer_ms << ",\"service_epochs\":" << p.epochs
        << ",\"longest_drain_epochs\":" << p.longest_drain << ",\"pending_before\":" << p.pending_before
        << ",\"pending_after\":" << p.pending_after << ",\"cells_inspected\":" << a.cells_inspected - b.cells_inspected
        << ",\"blocks_started\":" << a.blocks_started - b.blocks_started << ",\"work_units\":" << a.work_units - b.work_units
        << ",\"invalidations\":" << a.invalidations - b.invalidations << ",\"restarts\":" << a.restarts - b.restarts
        << ",\"publications\":" << a.publications - b.publications << ",\"refusals\":" << a.refusals - b.refusals
        << ",\"latency_total_epochs\":" << a.latency_total_ticks - b.latency_total_ticks
        << ",\"lifetime_latency_max_epochs\":" << a.latency_max_ticks
        << ",\"lifetime_queue_high_water\":" << a.queue_high_water << '}';
}
}
int main(int argc, char** argv) {
    try {
        check(argc == 5, "usage: settled_discovery SIDE BUDGET IDLE_EPOCHS LOCAL_ROUNDS");
        const auto side = integer(argv[1], 2048), budget = integer(argv[2], 8192);
        const auto idle_epochs = integer(argv[3], 10000000), local_rounds = integer(argv[4], 100000);
        check(side == 128 || side == 512 || side == 2048, "unregistered size");
        check(budget == 64 || budget == 1024 || budget == 8192, "unregistered budget");
        const auto tiles = side / 32, count = tiles * tiles;
        const auto area = static_cast<std::size_t>(side) * side;
        const auto allocate_source = Clock::now();
        std::vector<DiscoveryCell> source(area, tuple);
        const auto source_init_ms = ms(allocate_source);
        const auto allocate_journal_start = Clock::now();
        auto journal = std::make_unique<Journal>(1);
        const auto journal_init_ms = ms(allocate_journal_start);
        std::array<DiscoveryHandle, 4096> handles{};
        const auto register_start = Clock::now();
        for (std::uint32_t i = 0; i < count; ++i)
            check(journal->register_block({(i % tiles) * 32, (i / tiles) * 32, 32, 32}, signals, 0, handles[i]) == DiscoveryOutcome::Accepted, "registration failed");
        const auto registration_ms = ms(register_start);
        std::array<Phase, 5> phases{{{"initial"}, {"idle"}, {"local_aba"}, {"churn"}, {"recovery"}}};
        std::uint64_t epoch = 0;
        auto step = [&](Phase& p) {
            check(service(*journal, ++epoch, budget, source, side) <= budget, "budget exceeded"); ++p.epochs;
        };
        auto drain = [&](Phase& p) {
            const auto begin = p.epochs;
            while (journal->pending()) { check(p.epochs - begin < 100000000, "drain exhausted"); step(p); }
            p.longest_drain = std::max(p.longest_drain, p.epochs - begin);
        };
        const auto centre = (tiles / 2) * tiles + tiles / 2;
        const auto member = static_cast<std::size_t>(side / 2) * side + side / 2;
        auto aba = [&](Phase& p) {
            const auto begin = Clock::now();
            source[member].state_a ^= 1;
            check(journal->dirty(handles[centre], epoch) == DiscoveryOutcome::Accepted, "ABA mutate notification");
            source[member] = tuple;
            check(journal->dirty(handles[centre], epoch) == DiscoveryOutcome::Accepted, "ABA restore notification");
            p.producer_ms += ms(begin);
        };
        const auto churn_epochs = (static_cast<std::uint64_t>(count) * 1026 + budget - 1) / budget + 4096;
        std::uint64_t fair_blocks = 0;
        for (std::size_t index = 0; index < phases.size(); ++index) {
            auto& p = phases[index]; p.before = journal->metrics(); p.pending_before = journal->pending();
            const auto begin = Clock::now();
            if (index == 0 || index == 4) drain(p);
            if (index == 1) for (std::uint32_t i = 0; i < idle_epochs; ++i) step(p);
            if (index == 2) for (std::uint32_t i = 0; i < local_rounds; ++i) { aba(p); drain(p); }
            if (index == 3) {
                const auto enqueue_start = Clock::now();
                for (std::uint32_t i = 0; i < count; ++i)
                    check(journal->dirty(handles[i], epoch) == DiscoveryOutcome::Accepted, "churn seed notification");
                p.producer_ms += ms(enqueue_start);
                for (std::uint64_t i = 0; i < churn_epochs; ++i) { aba(p); step(p); }
            }
            p.elapsed_ms = ms(begin); p.after = journal->metrics(); p.pending_after = journal->pending();
            if (index == 3) for (std::uint32_t i = 0; i < count; ++i) if (i != centre) {
                const auto s = journal->snapshot(handles[i]);
                check(s && s->classification == DiscoveryClass::Uniform, "churn starved an unaffected tile"); ++fair_blocks;
            }
        }
        check(phases[0].after.cells_inspected == area && phases[0].after.work_units == area + 2 * count, "initial analytic work mismatch");
        check(phases[1].after.work_units == phases[1].before.work_units, "idle performed discovery work");
        check(phases[2].after.work_units - phases[2].before.work_units == static_cast<std::uint64_t>(local_rounds) * 1026, "local analytic work mismatch");
        check(std::all_of(source.begin(), source.end(), [](const auto& cell) { return cell == tuple; }), "source payload changed");
        bool capacity_probe = false;
        if (count == 4096) {
            DiscoveryHandle refused;
            check(journal->register_block({4096, 4096, 32, 32}, signals, epoch, refused) == DiscoveryOutcome::Capacity, "full capacity accepted");
            capacity_probe = true;
        }
        std::cout << std::setprecision(12) << "{\"schema\":\"settled-discovery-cost-v1\",\"side\":" << side
            << ",\"budget\":" << budget << ",\"slots\":4096,\"block_cells\":1024,\"blocks\":" << count
            << ",\"idle_epochs\":" << idle_epochs << ",\"local_rounds\":" << local_rounds << ",\"churn_epochs\":" << churn_epochs
            << ",\"cell_bytes\":" << sizeof(DiscoveryCell) << ",\"source_bytes\":" << source.size() * sizeof(DiscoveryCell)
            << ",\"journal_bytes\":" << journal->storage_bytes() << ",\"journal_bytes_per_tracked_cell\":" << static_cast<double>(journal->storage_bytes()) / static_cast<double>(area)
            << ",\"source_init_ms\":" << source_init_ms << ",\"journal_init_ms\":" << journal_init_ms
            << ",\"registration_ms\":" << registration_ms << ",\"fair_unaffected_blocks\":" << fair_blocks
            << ",\"capacity_probe\":" << (capacity_probe ? "true" : "false") << ",\"registration_refusals\":" << journal->metrics().refusals
            << ",\"source_exact\":true,\"phases\":[";
        for (std::size_t i = 0; i < phases.size(); ++i) { if (i) std::cout << ','; emit(phases[i]); }
        std::cout << "]}\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << "FAIL journal cost: " << e.what() << '\n'; return 1; }
}
