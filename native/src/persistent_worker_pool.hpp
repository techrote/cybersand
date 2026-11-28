#pragma once

#include <array>
#include <atomic>
#include <bit>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>

namespace cybersand::detail {

#if defined(CYBERSAND_WORKER_POOL_TEST_HOOKS)
// Standalone lifetime tests can delay a thread before it takes any pool lock
// or borrows dispatch storage. Production builds contain no hook or callback.
struct WorkerPoolTestHooks {
    void* context = nullptr;
    void (*before_first_wait)(void*, std::uint32_t) noexcept = nullptr;
};
#endif

// Exclusive external owner. Each dispatch borrows its caller's context only
// until this function returns; pool workers never call engine APIs.
class PersistentWorkerPool final {
public:
    using TaskFunction = void (*)(void*, std::size_t) noexcept;

    explicit PersistentWorkerPool(std::uint32_t worker_count,
                                  bool task_completion_barrier = false
#if defined(CYBERSAND_WORKER_POOL_TEST_HOOKS)
                                  , WorkerPoolTestHooks hooks = {}
#endif
                                  ) : task_completion_barrier_(task_completion_barrier)
#if defined(CYBERSAND_WORKER_POOL_TEST_HOOKS)
                                    , test_hooks_(hooks)
#endif
    {
        if (worker_count == 0 || worker_count > 256)
            throw std::invalid_argument("persistent pool worker count must be within 1..256");
        try {
            workers_.reserve(worker_count);
            for (std::uint32_t index = 0; index < worker_count; ++index) {
                workers_.emplace_back([this,index] {
#if defined(CYBERSAND_WORKER_POOL_TEST_HOOKS)
                    if (test_hooks_.before_first_wait != nullptr)
                        test_hooks_.before_first_wait(test_hooks_.context, index);
#endif
                    if (task_completion_barrier_) worker_loop_actual_tasks(index);
                    else worker_loop_all_workers(index);
                });
            }
        } catch (...) {
            // A throwing constructor does not run our destructor. Wake/join
            // the already-started prefix while mutex/CVs and state still live;
            // jthread's stop token alone cannot wake this predicate-based wait.
            stop_and_join();
            throw;
        }
    }

    ~PersistentWorkerPool() { stop_and_join(); }

    PersistentWorkerPool(const PersistentWorkerPool&) = delete;
    PersistentWorkerPool& operator=(const PersistentWorkerPool&) = delete;

    void dispatch(std::size_t task_count, void* context, TaskFunction function) {
        if (task_count == 0) return;
        if (function == nullptr)
            throw std::invalid_argument("persistent pool task function must be present");
        // The World owns one dispatch at a time. Refuse accidental overlap or
        // callback re-entry BEFORE replacing storage still borrowed by tasks.
        // Waiting here would deadlock a task which re-enters its own pool.
        if (dispatching_.test_and_set(std::memory_order_acquire))
            throw std::logic_error("persistent pool already has an active dispatch");
        struct DispatchOwnership {
            std::atomic_flag& flag;
            ~DispatchOwnership() { flag.clear(std::memory_order_release); }
        } ownership{dispatching_};
        {
            std::lock_guard lock(mutex_);
            context_ = context;
            function_ = function;
            task_count_ = task_count;
            next_task_.store(0, std::memory_order_relaxed);
            workers_remaining_ = workers_.size();
            tasks_remaining_ = task_count;
            next_claim_ = 0;
            for (auto& mask:participants_) mask.store(0,std::memory_order_relaxed);
            ++generation_;
        }
        start_condition_.notify_all();

        std::unique_lock lock(mutex_);
        done_condition_.wait(lock, [this] {
            return task_completion_barrier_ ? tasks_remaining_ == 0 : workers_remaining_ == 0;
        });
        // Both modes report completed real tasks only. These owner-only
        // counters are observation, never admission or physical authority.
        ++completed_dispatches_;
        completed_tasks_ += task_count;
    }

    [[nodiscard]] std::uint32_t participating_workers() const noexcept {
        std::uint32_t count=0;
        for (const auto& mask:participants_)
            count+=static_cast<std::uint32_t>(std::popcount(mask.load(std::memory_order_relaxed)));
        return count;
    }

    // RAMCACHE's owner-side residency estimate includes the selected pool's
    // actual object and allocated thread handles; thread stacks stay separate.
    [[nodiscard]] std::size_t resident_storage_bytes() const noexcept {
        return sizeof(*this) + workers_.capacity() * sizeof(std::jthread);
    }

    [[nodiscard]] std::uint64_t completed_dispatches() const noexcept { return completed_dispatches_; }
    [[nodiscard]] std::uint64_t completed_tasks() const noexcept { return completed_tasks_; }

private:
    void stop_and_join() noexcept {
        {
            std::lock_guard lock(mutex_);
            stopping_ = true;
            ++generation_;
        }
        start_condition_.notify_all();
        workers_.clear();
    }

    // Frozen control: every awakened worker borrows the dispatch's context,
    // so even an idle worker must acknowledge before that context can retire.
    void worker_loop_all_workers(std::uint32_t worker_index) noexcept {
        std::uint64_t observed_generation = 0;
        for (;;) {
            TaskFunction function = nullptr;
            void* context = nullptr;
            std::size_t task_count = 0;
            {
                std::unique_lock lock(mutex_);
                start_condition_.wait(lock, [this, &observed_generation] {
                    return stopping_ || generation_ != observed_generation;
                });
                if (stopping_) return;
                observed_generation = generation_;
                function = function_;
                context = context_;
                task_count = task_count_;
            }

            bool participated=false;
            for (;;) {
                const auto task = next_task_.fetch_add(1, std::memory_order_relaxed);
                if (task >= task_count) break;
                if (!participated) {
                    participants_[worker_index/64U].fetch_or(std::uint64_t{1}<<(worker_index%64U),std::memory_order_relaxed);
                    participated=true;
                }
                function(context, task);
            }
            {
                std::lock_guard lock(mutex_);
                if (--workers_remaining_ == 0) done_condition_.notify_one();
            }
        }
    }

    // A worker can borrow context only while atomically claiming one real
    // task from the CURRENT dispatch under this mutex. It holds no context
    // across an idle wait and cannot claim retired work after a late wake.
    void worker_loop_actual_tasks(std::uint32_t worker_index) noexcept {
        std::unique_lock lock(mutex_);
        for (;;) {
            start_condition_.wait(lock, [this] {
                return stopping_ || next_claim_ < task_count_;
            });
            if (stopping_) return;
            const auto task = next_claim_++;
            const auto function = function_;
            void* const context = context_;
            participants_[worker_index/64U].fetch_or(
                std::uint64_t{1}<<(worker_index%64U),std::memory_order_relaxed);
            lock.unlock();
            function(context, task);
            // No task/context access, destructor or statistics write may be
            // moved after this completion edge. The caller acquires the SAME
            // mutex after every task returned before reusing its storage.
            lock.lock();
            if (--tasks_remaining_ == 0) done_condition_.notify_one();
        }
    }

    const bool task_completion_barrier_;
#if defined(CYBERSAND_WORKER_POOL_TEST_HOOKS)
    const WorkerPoolTestHooks test_hooks_;
#endif
    std::vector<std::jthread> workers_;
    std::mutex mutex_;
    std::condition_variable start_condition_;
    std::condition_variable done_condition_;
    std::atomic<std::size_t> next_task_{0};
    std::atomic_flag dispatching_ = ATOMIC_FLAG_INIT;
    std::array<std::atomic<std::uint64_t>,4> participants_{};
    std::uint64_t generation_ = 0;
    std::uint64_t completed_dispatches_ = 0, completed_tasks_ = 0;
    std::size_t task_count_ = 0;
    std::size_t workers_remaining_ = 0;
    std::size_t tasks_remaining_ = 0, next_claim_ = 0;
    void* context_ = nullptr;
    TaskFunction function_ = nullptr;
    bool stopping_ = false;
};

}  // namespace cybersand::detail
