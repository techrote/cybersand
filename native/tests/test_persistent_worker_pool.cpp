// Exercise the production class, including deterministic delayed idle workers.
// This tests lifetime/completion, not physical simulation or performance.
#define CYBERSAND_WORKER_POOL_TEST_HOOKS
#include "../src/persistent_worker_pool.hpp"

#include <array>
#include <chrono>
#include <cstdio>
#include <memory>
#include <stdexcept>
#include <string>

namespace {
using cybersand::detail::PersistentWorkerPool;
using cybersand::detail::WorkerPoolTestHooks;
using namespace std::chrono_literals;
unsigned checks = 0;

void require(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}

struct Signal {
    std::mutex mutex;
    std::condition_variable condition;
    bool value = false;
    void set() {
        { std::lock_guard lock(mutex); value = true; }
        condition.notify_all();
    }
    bool wait(std::chrono::milliseconds timeout = 5000ms) {
        std::unique_lock lock(mutex);
        return condition.wait_for(lock, timeout, [this] { return value; });
    }
};

struct DelayedWorkers {
    std::mutex mutex;
    std::condition_variable condition;
    std::uint32_t arrived = 0;
    bool released = false;
    static void before_wait(void* raw, std::uint32_t worker) noexcept {
        if (worker == 0) return;
        auto& state = *static_cast<DelayedWorkers*>(raw);
        std::unique_lock lock(state.mutex);
        ++state.arrived;
        state.condition.notify_all();
        state.condition.wait(lock, [&state] { return state.released; });
    }
    bool ready(std::uint32_t count) {
        std::unique_lock lock(mutex);
        return condition.wait_for(lock, 5000ms, [this,count] { return arrived == count; });
    }
    void release() {
        { std::lock_guard lock(mutex); released = true; }
        condition.notify_all();
    }
    ~DelayedWorkers() { release(); }
    WorkerPoolTestHooks hooks() { return {this, before_wait}; }
};

constexpr std::size_t kCapacity = 257;
struct Batch {
    std::array<std::atomic<std::uint32_t>,kCapacity> visits{};
    std::array<std::uint64_t,kCapacity> outputs{};
    std::atomic<bool> error{false};
    std::size_t count = 0;
    std::uint64_t generation = 0;
    static void run(void* raw, std::size_t task) noexcept {
        auto& batch = *static_cast<Batch*>(raw);
        if (task >= batch.count || task >= kCapacity) {
            batch.error.store(true, std::memory_order_relaxed);
            return;
        }
        if (batch.visits[task].fetch_add(1, std::memory_order_relaxed) != 0) {
            batch.error.store(true, std::memory_order_relaxed);
            return;
        }
        batch.outputs[task] = (batch.generation << 32U) ^ (task * 101U + 7U);
    }
};

bool exact(const Batch& batch) {
    if (batch.error.load(std::memory_order_relaxed)) return false;
    for (std::size_t index = 0; index < kCapacity; ++index) {
        if (batch.visits[index].load(std::memory_order_relaxed) != (index < batch.count ? 1U : 0U)) return false;
        if (index < batch.count && batch.outputs[index] != ((batch.generation << 32U) ^ (index * 101U + 7U))) return false;
    }
    return true;
}

void late_idle_worker_context_retirement() {
    DelayedWorkers delayed;
    PersistentWorkerPool pool(4, true, delayed.hooks());
    if (!delayed.ready(3)) { delayed.release(); require(false, "idle workers did not enter the controlled pre-claim delay"); }
    Signal finished;
    bool valid = true;
    std::uint64_t expected_tasks = 0;
    std::jthread owner([&] {
        for (std::uint64_t generation = 1; generation <= 192; ++generation) {
            auto batch = std::make_unique<Batch>();
            batch->count = std::array<std::size_t,6>{1,3,17,129,257,0}[generation % 6U];
            batch->generation = generation;
            const auto dispatches_before = pool.completed_dispatches();
            const auto tasks_before = pool.completed_tasks();
            pool.dispatch(batch->count, batch.get(), Batch::run);
            valid = valid && exact(*batch);
            if (batch->count != 0) {
                valid = valid && pool.participating_workers() == 1;
                valid = valid && pool.completed_dispatches() == dispatches_before + 1;
            } else valid = valid && pool.completed_dispatches() == dispatches_before;
            valid = valid && pool.completed_tasks() == tasks_before + batch->count;
            expected_tasks += batch->count;
            // The delayed threads have still not taken a pool lock. The
            // caller may destroy each old borrowed context RIGHT HERE.
            batch.reset();
        }
        finished.set();
    });
    const bool returned_without_idle_ack = finished.wait();
    delayed.release();
    owner.join();
    require(returned_without_idle_ack, "actual-task completion waited for a thread that borrowed no task");
    require(valid, "context reuse/task counts/participant identity failed before late workers arrived");
    require(pool.completed_tasks() == expected_tasks, "actual task counter is not the completed work count");
    // Late workers now observe only the currently published dispatch, never
    // one of the192 retired heap contexts. ASan checks those freed contexts.
    for (std::uint64_t generation = 193; generation <= 320; ++generation) {
        auto batch = std::make_unique<Batch>();
        batch->count = 257;
        batch->generation = generation;
        pool.dispatch(batch->count, batch.get(), Batch::run);
        require(exact(*batch), "late worker claimed stale or duplicate work after retirement");
        require(pool.participating_workers() > 0 && pool.participating_workers() <= 4,
                "participant mask counts anything other than actual task workers");
    }
}

void unchanged_control_waits_for_borrowers() {
    DelayedWorkers delayed;
    PersistentWorkerPool pool(4, false, delayed.hooks());
    if (!delayed.ready(3)) { delayed.release(); require(false, "control delayed workers did not arrive"); }
    Signal task_finished, dispatch_finished;
    std::jthread owner([&] {
        pool.dispatch(1, &task_finished, [](void* context, std::size_t) noexcept {
            static_cast<Signal*>(context)->set();
        });
        dispatch_finished.set();
    });
    const bool real_task_returned = task_finished.wait();
    const bool premature_return = dispatch_finished.wait(30ms);
    delayed.release();
    const bool drained = dispatch_finished.wait();
    owner.join();
    require(real_task_returned, "control did not execute its actual task");
    require(!premature_return, "frozen all-worker control lost its borrowed-context barrier");
    require(drained && pool.completed_tasks() == 1 && pool.completed_dispatches() == 1,
            "control did not drain after genuine worker acknowledgements");
    require(pool.participating_workers() == 1, "control counted delayed idle workers as participants");
}

void final_task_and_destructor_are_part_of_completion(bool actual_tasks) {
    PersistentWorkerPool pool(4, actual_tasks);
    struct Context {
        Signal entered, release;
        std::array<std::uint64_t,17> result{};
        std::uint64_t destructor_write = 0;
        static void run(void* raw, std::size_t index) noexcept {
            auto& context = *static_cast<Context*>(raw);
            if (index == 16) {
                context.entered.set();
                if (!context.release.wait()) return;
                struct FinalWrite {
                    Context& context;
                    ~FinalWrite() { context.destructor_write = 0xAC7A11U; }
                } final_write{context};
                context.result[index] = index + 1U;
            } else context.result[index] = index + 1U;
        }
    } context;
    Signal finished;
    std::jthread owner([&] { pool.dispatch(17, &context, Context::run); finished.set(); });
    const bool held_task_entered = context.entered.wait();
    const bool premature_return = finished.wait(30ms);
    context.release.set();
    const bool completed = finished.wait();
    owner.join();
    require(held_task_entered && !premature_return, "dispatch returned before its last actual task");
    require(completed && context.destructor_write == 0xAC7A11U,
            "dispatch lifetime ended before final task destructor/write");
    for (std::size_t index = 0; index < context.result.size(); ++index)
        require(context.result[index] == index + 1U, "task write not visible at caller completion");
    require(pool.completed_tasks() == 17 && pool.completed_dispatches() == 1,
            "completion counters advance without all real task returns");
}

void construction_retirement_and_zero_work() {
    for (const bool actual_tasks : {false,true}) {
        for (const std::uint32_t workers : {1U,2U,4U,8U}) {
            for (unsigned round = 0; round < 12; ++round) {
                PersistentWorkerPool pool(workers, actual_tasks);
                Batch batch;
                pool.dispatch(0, nullptr, nullptr);
                require(pool.completed_tasks() == 0 && pool.completed_dispatches() == 0,
                        "zero work created completion credit or used a null context");
                batch.count = 257;
                batch.generation = round + 1U;
                pool.dispatch(batch.count, &batch, Batch::run);
                require(exact(batch), "construction/retirement loses tasks");
            }
        }
    }
}

void invalid_admission_and_overlapping_callers(bool actual_tasks) {
    for (const auto workers : {0U, 257U}) {
        bool refused = false;
        try { PersistentWorkerPool invalid(workers, actual_tasks); }
        catch (const std::invalid_argument&) { refused = true; }
        require(refused, "invalid pool capacity must refuse before worker creation");
    }
    PersistentWorkerPool pool(4, actual_tasks);
    bool null_refused = false;
    try { pool.dispatch(1, nullptr, nullptr); }
    catch (const std::invalid_argument&) { null_refused = true; }
    require(null_refused && pool.completed_tasks() == 0 && pool.completed_dispatches() == 0,
            "missing task function must refuse without completion credit");
    struct HeldContext {
        PersistentWorkerPool& pool;
        Signal entered, release;
        std::uint64_t final_write = 0;
        bool nested_refused = false;
        static void run(void* raw, std::size_t) noexcept {
            auto& context = *static_cast<HeldContext*>(raw);
            try { context.pool.dispatch(1, nullptr, [](void*, std::size_t) noexcept {}); }
            catch (const std::logic_error&) { context.nested_refused = true; }
            context.entered.set();
            if (context.release.wait()) context.final_write = 0xC011EC7U;
        }
    } held{pool};
    Signal finished;
    std::jthread owner([&] { pool.dispatch(1, &held, HeldContext::run); finished.set(); });
    const bool entered = held.entered.wait();
    bool overlap_refused = false;
    try { pool.dispatch(1, nullptr, [](void*, std::size_t) noexcept {}); }
    catch (const std::logic_error&) { overlap_refused = true; }
    // A zero-work request owns no storage and creates no completion credit.
    pool.dispatch(0, nullptr, nullptr);
    const bool premature_return = finished.wait(30ms);
    held.release.set();
    const bool completed = finished.wait();
    owner.join();
    require(entered && held.nested_refused && overlap_refused,
            "nested or concurrent dispatch overwrote borrowed context");
    require(!premature_return && completed && held.final_write == 0xC011EC7U,
            "refused overlap damaged the active task's completion edge");
    require(pool.completed_tasks() == 1 && pool.completed_dispatches() == 1,
            "refused overlap or zero work received completion credit");
    Batch followup;
    followup.count = kCapacity;
    followup.generation = 99;
    pool.dispatch(followup.count, &followup, Batch::run);
    require(exact(followup) && pool.completed_tasks() == 258 && pool.completed_dispatches() == 2,
            "refusal leaked dispatch ownership or poisoned later work");
}
}  // namespace

int main() {
    try {
        late_idle_worker_context_retirement();
        unchanged_control_waits_for_borrowers();
        final_task_and_destructor_are_part_of_completion(false);
        final_task_and_destructor_are_part_of_completion(true);
        construction_retirement_and_zero_work();
        invalid_admission_and_overlapping_callers(false);
        invalid_admission_and_overlapping_callers(true);
        std::printf("PUBPRES_POOL_LIFETIME_RESULT {\"checks\":%u,\"failures\":[]}\n", checks);
        return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "PUBPRES pool lifetime failed after%u checks: %s\n", checks, error.what());
        return 1;
    }
}
