// GEN-006 #194: real threaded native generation -> bounded queue -> exclusive owner.
// Diagnostic-only; no production runtime World/physics/serializer changes.
// The unsafe prevalidated admission is a deliberate negative control.
#include "cybersand/world.hpp"
#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <deque>
#include <exception>
#include <future>
#include <iostream>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <thread>
#include <utility>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::generation::ChunkResult;
using cybersand::generation::Generator;
using cybersand::generation::HardOverride;
using cybersand::generation::Recipe;
using cybersand::generation::ResultState;

constexpr ChunkCoord kCoord{-1, 0};
std::uint64_t checks = 0;

void check(bool condition, const char* description) {
    ++checks;
    if (!condition) throw std::runtime_error(description);
}

WorldConfig make_config(std::uint32_t workers) {
    WorldConfig cfg{};
    cfg.chunk_size = 128;
    cfg.backend = SimulationBackend::PhasedInPlace;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 1;
    cfg.initial_chunk_reserve = 2;
    cfg.maximum_chunk_count = 16;
    cfg.active_chunk_capacity = 32;
    cfg.active_core_capacity = 256;
    return cfg;
}

std::shared_ptr<const Generator> make_generator(std::uint64_t revision, Material material) {
    Recipe r{};
    r.schema = cybersand::generation::kSchemaVersion;
    r.chunk_size = 128;
    r.seed = 713;
    r.revision = revision;
    HardOverride hard{};
    hard.id = "gen006-async-signed-chunk";
    hard.bounds = {-128, 0, 128, 128};
    hard.material = material;
    r.overrides.push_back(hard);
    return Generator::compile(std::move(r));
}

struct Token {
    std::uint64_t session{}, job{}, fingerprint{};
    ChunkCoord coord{};
    friend bool operator==(const Token&, const Token&) = default;
};

struct Delivery {
    Token token;
    ChunkResult proposal;
};

// One whole generated chunk maximum, regardless of worker pressure.
// Producers never block on owner consumption and never touch World.
class OneSlotMailbox {
public:
    bool try_offer(Delivery d) {
        std::lock_guard<std::mutex> guard(lock_);
        ++attempts_;
        if (!items_.empty()) {
            ++drops_;
            return false;
        }
        items_.push_back(std::move(d));
        maximum_ = std::max(maximum_, items_.size());
        return true;
    }

    std::optional<Delivery> take() {
        std::lock_guard<std::mutex> guard(lock_);
        if (items_.empty()) return std::nullopt;
        Delivery result = std::move(items_.front());
        items_.pop_front();
        return result;
    }

    std::size_t maximum() const {
        std::lock_guard<std::mutex> guard(lock_);
        return maximum_;
    }
    std::size_t drops() const {
        std::lock_guard<std::mutex> guard(lock_);
        return drops_;
    }
    std::size_t attempts() const {
        std::lock_guard<std::mutex> guard(lock_);
        return attempts_;
    }

private:
    mutable std::mutex lock_;
    std::deque<Delivery> items_;
    std::size_t maximum_ = 0, attempts_ = 0, drops_ = 0;
};

// All methods are called exclusively on the test owner/main thread.
// Production streaming would need its own admitted protocol and pin/lease rules.
class Owner {
public:
    Owner(WorldConfig cfg, std::shared_ptr<const Generator> gen)
        : cfg_(cfg), generator_(std::move(gen)), world_(std::make_unique<World>(cfg_)) {}

    Token demand(ChunkCoord coord) {
        pending_ = Token{session_, ++job_counter_, generator_->fingerprint(), coord};
        return *pending_;
    }

    void cancel() { pending_.reset(); }

    void reset(std::shared_ptr<const Generator> next) {
        pending_.reset();
        ++session_;
        generator_ = std::move(next);
        world_ = std::make_unique<World>(cfg_);
    }

    // This method exists solely to prove that a valid preflight is not a lease.
    bool preflight(const Delivery& item) const {
        return pending_.has_value() && item.token == *pending_ &&
               item.token.session == session_ &&
               item.token.fingerprint == generator_->fingerprint() &&
               item.proposal.chunk == item.token.coord &&
               generator_->accepts(item.proposal);
    }

    bool commit(const Delivery& item) {
        // Check at the exclusive owner commit boundary, after any reset/cancel.
        if (!preflight(item)) return false;
        if (world_->install_generated_chunk(item.proposal.chunk, item.proposal.cells) !=
            ChunkInstallOutcome::Installed)
            return false;
        pending_.reset();
        return true;
    }

    World& world() { return *world_; }

private:
    WorldConfig cfg_;
    std::shared_ptr<const Generator> generator_;
    std::unique_ptr<World> world_;
    std::optional<Token> pending_;
    std::uint64_t session_ = 1, job_counter_ = 0;
};

void produce(OneSlotMailbox& box, Token token,
             std::shared_ptr<const Generator> generator,
             std::atomic<std::uint32_t>& completed, std::promise<bool>& result) {
    try {
        // This is actual compiled native generation on an OS producer thread.
        auto proposal = generator->generate(token.coord);
        if (proposal.state != ResultState::Ready)
            throw std::runtime_error("native asynchronous generator did not publish Ready");
        completed.fetch_add(1, std::memory_order_relaxed);
        result.set_value(box.try_offer(Delivery{token, std::move(proposal)}));
    } catch (...) {
        result.set_exception(std::current_exception());
    }
}

void run(std::uint32_t workers) {
    const auto start = std::chrono::steady_clock::now();
    const auto cfg = make_config(workers);
    const auto earlier = make_generator(1, Material::Wall);
    const auto adopted = make_generator(2, Material::Glass);
    Owner owner(cfg, earlier);
    OneSlotMailbox box;
    std::atomic<std::uint32_t> producer_completed{0};

    const Token earlier_token = owner.demand(kCoord);
    std::promise<bool> first_promise;
    auto first_result = first_promise.get_future();
    std::thread first(produce, std::ref(box), earlier_token, earlier,
                      std::ref(producer_completed), std::ref(first_promise));
    first.join();
    check(first_result.get(), "old native producer could not enqueue in empty queue");
    auto old_delivery = box.take();
    check(old_delivery.has_value(), "old native delivery missing from mailbox");
    check(owner.preflight(*old_delivery), "old delivery was not valid before owner reset");
    check(earlier->accepts(old_delivery->proposal), "old generator receipt not valid");
    // The owner changes after a successful preflight but before a possible commit.
    owner.reset(adopted);
    check(!owner.preflight(*old_delivery), "cached preflight remained fresh after reset");
    check(!owner.commit(*old_delivery), "old prevalidated delivery crossed reset boundary");
    check(owner.world().chunk_count() == 0, "stale delivery allocated a resident");

    // Negative control: trusting the earlier preflight boolean and calling the
    // unchanged native material-only API on a new World DOES admit old content.
    World unsafe(cfg);
    check(unsafe.install_generated_chunk(kCoord, old_delivery->proposal.cells) ==
              ChunkInstallOutcome::Installed,
          "negative control did not demonstrate cached-preflight admission hazard");
    check(unsafe.stored_material(-128, 0) == Material::Wall,
          "unsafe result did not retain the old recipe's material");

    // Real asynchronous producers deliver a superseded request and a current
    // request to a deliberately full one-slot queue. The newer result is lost;
    // the owner must not interpret the loss as an ACK or silently mark completion.
    const Token superseded = owner.demand(kCoord);
    owner.cancel();
    const Token current = owner.demand(kCoord);
    std::promise<bool> stale_promise, dropped_promise;
    std::shared_future<bool> stale_enqueued = stale_promise.get_future().share();
    auto dropped_result = dropped_promise.get_future();
    std::thread stale_thread(produce, std::ref(box), superseded, adopted,
                             std::ref(producer_completed), std::ref(stale_promise));
    std::thread current_thread([&] {
        stale_enqueued.wait(); // Force bounded queue overflow, not timing luck.
        produce(box, current, adopted, producer_completed, dropped_promise);
    });
    stale_thread.join();
    current_thread.join();
    check(stale_enqueued.get(), "stale proposal was not queued first");
    check(!dropped_result.get(), "current proposal did not report a full-queue drop");
    check(box.maximum() == 1 && box.drops() == 1,
          "bounded queue did not record its maximum and one loss");
    auto stale_delivery = box.take();
    check(stale_delivery.has_value(), "superseded proposal was not retained");
    check(!owner.commit(*stale_delivery), "cancelled job mutated native World");
    check(owner.world().chunk_count() == 0, "stale queued job allocated a chunk");

    // The current demand remains open; retry after reported overflow, without
    // skipping ticks or treating the dropped proposal as an accepted receipt.
    std::promise<bool> retry_promise;
    auto retry_result = retry_promise.get_future();
    std::thread retry(produce, std::ref(box), current, adopted,
                      std::ref(producer_completed), std::ref(retry_promise));
    retry.join();
    check(retry_result.get(), "retry could not use available queue capacity");
    auto retry_delivery = box.take();
    check(retry_delivery.has_value(), "retry receipt missing");
    check(adopted->accepts(retry_delivery->proposal), "retry source receipt invalid");
    check(owner.commit(*retry_delivery), "fresh retried receipt was refused");
    check(!owner.commit(*retry_delivery), "receipt replay was accepted twice");
    check(owner.world().chunk_count() == 1, "accepted demand did not create exactly one chunk");
    check(owner.world().stored_material(-128, 0) == Material::Glass,
          "new World contains stale recipe material");
    check(producer_completed.load() == 4, "not all four real producer threads executed");
    check(box.attempts() == 4 && box.maximum() == 1 && box.drops() == 1,
          "bounded publication accounting diverged");

    // Actual World continuation control, not a synthetic cell-state model.
    World reference(cfg);
    check(reference.install_generated_chunk(kCoord, retry_delivery->proposal.cells) ==
              ChunkInstallOutcome::Installed, "reference native admission refused");
    std::uint32_t observed = 0;
    for (int i = 0; i < 3; ++i) {
        const auto selected = owner.world().tick();
        const auto control = reference.tick();
        check(!owner.world().has_failed() && !reference.has_failed(),
              "native continuation failed/quarantined");
        check(selected.tick == control.tick &&
                  owner.world().physical_state_hash() == reference.physical_state_hash() &&
                  owner.world().quantity_ledger() == reference.quantity_ledger(),
              "retained current-result trajectory diverged from control");
        observed = std::max(observed, selected.worker_threads_observed);
    }
    const auto elapsed_us = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now() - start).count();
    std::cout << "GEN006_ASYNC_OWNER configured_world_workers=" << workers
              << " native_world_workers_observed_max=" << observed
              << " native_producer_tasks_completed=" << producer_completed.load()
              << " queue_capacity=1 queue_peak=" << box.maximum()
              << " queue_drops=" << box.drops()
              << " preflight_reset_hazard=1 stale_commit_refused=1"
              << " overflow_current_retry_admitted=1 continuation_ticks=3"
              << " elapsed_us=" << elapsed_us << " result=PASS checks_so_far="
              << checks << '\n';
}
} // namespace

int main() {
    try {
        run(1);
        run(4);
        std::cout << "GEN006_ASYNC_OWNER_PASS checks=" << checks << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_ASYNC_OWNER_FAIL checks=" << checks
                  << " detail=" << error.what() << '\n';
        return 1;
    }
}
