// PLAY-BUSY-001A: generated header contains the verbatim production pool class.
// This does not compile or exercise World::simulation_tick or Godot Main.
#include "play_busy001_source_pool.hpp"
#include "support/play_busy001_barrier.hpp"
#include <atomic>
#include <chrono>
#include <iostream>
#include <memory>
#include <thread>

using Pool = cybersand::source_probe::PersistentWorkerPool;
using Gate = cybersand::test::PhaseGate;
using namespace std::chrono_literals;
namespace {
int assertions = 0, failures = 0;
void expect(bool condition, const char* message) {
    ++assertions;
    if (!condition) { ++failures; std::cerr << "FAIL: " << message << '\n'; }
}
struct Context {
    Gate& gate;
    Gate::Ticket ticket;
    std::atomic<std::size_t> checksum{0}, rejected{0};
    std::atomic<bool> alive{true};
    static void invoke(void* raw, std::size_t task) noexcept {
        auto& self = *static_cast<Context*>(raw);
        if (!self.gate.arrive_and_wait(self.ticket, task)) { ++self.rejected; return; }
        if (!self.alive.load()) ++self.rejected;
        self.checksum.fetch_add(task + 1);
        if (!self.gate.complete(self.ticket, task)) ++self.rejected;
    }
};

void held_dispatch(Gate& gate, std::size_t tasks, std::uint32_t workers,
                   std::uint64_t epoch, Gate::Ticket stale = {}) {
    const auto ticket = gate.arm(epoch, 17, tasks, workers, 5000ms);
    expect(ticket.generation != 0, "valid multiworker dispatch admits bounded gate");
    if (!ticket.generation) return;
    Context context{gate, ticket};
    std::atomic<bool> returned{false}, destroyed{false};
    std::atomic<std::uint32_t> participants{0};
    std::jthread dispatcher([&] {
        {
            Pool pool(workers);
            pool.dispatch(tasks, &context, &Context::invoke);
            participants = pool.participating_workers();
            returned = true;
        }
        destroyed = true;
    });
    const bool held = gate.wait_for_held(ticket, 2, 2000ms);
    expect(held, "at least two distinct real pool threads reached claimed callbacks");
    const auto before = gate.snapshot();
    expect(!returned.load() && !destroyed.load(), "dispatch and pool lifetime remain outstanding");
    expect(before.active >= 2 && before.completed == 0 && !before.released,
           "copied observation proves jobs outstanding before test stop");
    expect(!gate.complete(ticket, 0), "completion cannot retire a still-waiting claim");
    expect(!gate.arm(epoch, 18, tasks, workers, 100ms).generation,
           "cannot replace a gate with unfinished tasks");
    auto wrong = ticket; ++wrong.phase;
    expect(!gate.release(wrong), "wrong phase cannot release active jobs");
    expect(!gate.release(stale), "old or empty generation cannot release current jobs");
    expect(gate.mark_stop(ticket), "test stop recorded while at least two claims are held");
    expect(!gate.mark_stop(ticket), "duplicate stop fence refused");
    const auto stopped = gate.snapshot();
    expect(stopped.stop_waiting >= 2 && stopped.stop_active >= 2 && !stopped.released,
           "test stop record contains observed held jobs, not after-tick counters");
    // A helper accesses only the gate, not a live World or callback context.
    std::atomic<bool> release_ok{false};
    std::jthread releaser([&] { release_ok = gate.release(ticket); });
    releaser.join();
    dispatcher.join();
    const auto after = gate.snapshot();
    expect(release_ok.load() && !after.timed_out, "positive release is manual, not watchdog masking");
    expect(after.entered == tasks && after.completed == tasks && after.active == 0 && after.waiting == 0,
           "all actual tasks drained exactly once");
    expect(after.first_arrival < after.stop && after.stop < after.release && after.release < after.drained,
           "gate trace orders claim, test stop, release and drain");
    expect(returned.load() && destroyed.load() && !dispatcher.joinable(),
           "dispatch returned, actual pool threads destroyed, dispatcher joined");
    expect(participants.load() >= 2 && context.checksum == tasks * (tasks + 1) / 2 && context.rejected == 0,
           "pool participation and task work are real and exact");
    expect(!gate.complete(ticket, 0), "duplicate completion refused after drain");
    expect(!gate.release(ticket), "release is one-shot");
    context.alive = false;  // Test context retires only after actual dispatcher join.
    std::cout << "PLAY_BUSY001_POOL_ROW {\"generation\":" << ticket.generation
              << ",\"tasks\":" << tasks << ",\"workers\":" << workers
              << ",\"participants\":" << participants.load()
              << ",\"held_at_test_stop\":" << stopped.stop_waiting
              << ",\"first_arrival\":" << after.first_arrival
              << ",\"test_stop\":" << after.stop << ",\"release\":" << after.release
              << ",\"drained\":" << after.drained << ",\"timed_out\":"
              << (after.timed_out ? "true" : "false") << "}\n";
}

void timeout_control() {
    Gate gate;
    const auto ticket = gate.arm(101, 3, 4, 2, 30ms);
    Context context{gate, ticket};
    const auto started = Gate::Clock::now();
    {
        Pool pool(2);
        pool.dispatch(4, &context, &Context::invoke);  // No manual release: expected timeout.
    }
    const auto snapshot = gate.snapshot();
    expect(snapshot.timed_out && snapshot.released && snapshot.completed == 4,
           "safety deadline releases tasks and remains explicitly timed out");
    expect(!gate.release(ticket) && !gate.mark_stop(ticket),
           "late release or stop cannot reclassify a timeout as positive evidence");
    expect(snapshot.stop == 0 && snapshot.release < snapshot.drained && context.rejected == 0,
           "timeout trace has no invented stop fence and drains normally");
    expect(Gate::Clock::now() - started < 5s, "safety control finishes within apparatus bound");
}

void refusal_and_unblocked_controls() {
    Gate gate;
    expect(!gate.arm(1, 1, 1, 4, 100ms).generation, "single task cannot qualify overlapping jobs");
    expect(!gate.arm(1, 1, 4, 1, 100ms).generation, "single worker cannot qualify overlapping jobs");
    expect(!gate.arm(0, 1, 4, 4, 100ms).generation, "zero epoch refused");
    expect(!gate.arm(1, 0, 4, 4, 100ms).generation, "zero phase refused");
    expect(!gate.arm(1, 1, 65, 4, 100ms).generation, "bounded job storage refuses overflow");
    expect(!gate.arm(1, 1, 4, 65, 100ms).generation, "bounded thread storage refuses overflow");
    expect(!gate.arm(1, 1, 4, 4, 0ms).generation, "zero hold deadline refused");
    expect(!gate.arm(1, 1, 4, 4, 5001ms).generation, "unbounded hold deadline refused");
    for (std::uint32_t workers : {1U, 4U}) {
        Pool pool(workers);
        std::atomic<std::size_t> sum{0};
        auto task = +[](void* raw, std::size_t index) noexcept {
            static_cast<std::atomic<std::size_t>*>(raw)->fetch_add(index + 1);
        };
        pool.dispatch(0, &sum, task);
        expect(sum == 0, "zero-task production dispatch returns without callbacks");
        pool.dispatch(8, &sum, task);
        expect(sum == 36, "unblocked production dispatch preserves every task");
    }
    const auto ticket = gate.arm(1, 1, 2, 2, 5000ms);
    expect(!gate.arrive_and_wait({}, 0), "unarmed ticket rejected");
    expect(!gate.arrive_and_wait(ticket, 64), "out-of-range task rejected");
    expect(!gate.mark_stop(ticket), "cannot invent test stop before any claims");
    expect(!gate.wait_for_held(ticket, 1, 1ms), "one claim cannot satisfy overlap observation");
    expect(gate.release(ticket), "unused armed gate can be safely released");
    expect(gate.arrive_and_wait(ticket, 0), "released phase can finish a valid claimed callback");
    expect(!gate.arrive_and_wait(ticket, 0), "duplicate task claim rejected");
    expect(gate.complete(ticket, 0), "released valid claim completes");
    expect(gate.arrive_and_wait(ticket, 1) && gate.complete(ticket, 1), "remaining expected task drains");
}
}  // namespace

int main() {
    refusal_and_unblocked_controls();
    Gate reusable;
    Gate::Ticket previous{};
    for (unsigned iteration = 0; iteration < 8; ++iteration) {
        held_dispatch(reusable, 8, iteration % 2 ? 2U : 4U, 10U + iteration, previous);
        previous = reusable.snapshot().ticket;
    }
    timeout_control();
    std::cout << "PLAY_BUSY001_POOL_RESULT {\"assertions\":" << assertions
              << ",\"failures\":" << failures
              << ",\"positive_dispatches\":8,\"expected_timeout_controls\":1,"
              << "\"pool_class_sha256\":\"" << PLAY_BUSY001_POOL_SHA256 << "\","
              << "\"scope\":{\"literal_production_pool_class\":true,\"world_tick\":false,"
              << "\"godot_main\":false,\"production_stop_fence\":false,"
              << "\"native_busy_host_shutdown_qualified\":false}}\n";
    return failures == 0 ? 0 : 1;
}
