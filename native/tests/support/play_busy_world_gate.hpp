#pragma once

// PLAY-BUSY-001B test-only synchronization state.
// Included by native/src/world.cpp only when CYBERSAND_PLAY_BUSY_TEST_HOOK is
// defined. This file contains no Godot API and does not own or inspect a World.
#include <array>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <thread>

namespace cybersand::play_busy_test {

class WorldPhaseGate final {
public:
    using Clock = std::chrono::steady_clock;
    static constexpr std::size_t kMaximumTasks = 4096;
    static constexpr std::size_t kMaximumThreads = 64;

    struct Snapshot {
        std::uint64_t generation = 0;
        std::uint64_t tick = 0;
        std::uint32_t phase = 0;
        std::size_t expected_tasks = 0;
        std::size_t minimum_claims = 0;
        std::size_t entered = 0;
        std::size_t waiting = 0;
        std::size_t active = 0;
        std::size_t completed = 0;
        std::size_t distinct_threads = 0;
        std::size_t stop_waiting = 0;
        std::size_t stop_active = 0;
        std::uint64_t dispatch_started_sequence = 0;
        std::uint64_t first_arrival_sequence = 0;
        std::uint64_t stop_sequence = 0;
        std::uint64_t release_sequence = 0;
        std::uint64_t drained_sequence = 0;
        std::uint64_t dispatch_return_sequence = 0;
        bool armed = false;
        bool selected = false;
        bool released = false;
        bool timed_out = false;
        bool thread_identity_overflow = false;
    };

    std::uint64_t arm(std::size_t minimum_claims, std::chrono::milliseconds bound) noexcept {
        std::lock_guard lock(mutex_);
        if (minimum_claims < 2 || minimum_claims > kMaximumThreads ||
            bound.count() <= 0 || bound.count() > 15'000 ||
            (state_.selected && state_.dispatch_return_sequence == 0) ||
            generation_ == std::numeric_limits<std::uint64_t>::max()) {
            return 0;
        }
        state_ = {};
        state_.generation = ++generation_;
        state_.minimum_claims = minimum_claims;
        state_.armed = true;
        seen_.fill(false);
        ready_.fill(false);
        done_.fill(false);
        threads_.fill({});
        deadline_ = Clock::now() + bound;
        return state_.generation;
    }

    // Called by the exclusive World owner immediately before the real pool
    // dispatch. Arming during an already-running dispatch therefore cannot
    // retroactively select a partially claimed phase.
    std::uint64_t begin_dispatch(std::uint64_t tick, std::uint32_t phase,
                                 std::size_t task_count) noexcept {
        std::lock_guard lock(mutex_);
        if (!state_.armed || state_.selected || state_.released ||
            task_count < state_.minimum_claims || task_count > kMaximumTasks) {
            return 0;
        }
        if (Clock::now() >= deadline_) {
            release_locked(true);
            return 0;
        }
        state_.selected = true;
        state_.tick = tick;
        state_.phase = phase;
        state_.expected_tasks = task_count;
        state_.dispatch_started_sequence = ++sequence_;
        changed_.notify_all();
        return state_.generation;
    }

    // The pool has already atomically claimed this real task before entering.
    // Return true only when this task belongs to the selected dispatch.
    bool arrive_and_wait(std::uint64_t generation, std::uint64_t tick,
                         std::uint32_t phase, std::size_t task) noexcept {
        if (generation == 0) return false;
        std::unique_lock lock(mutex_);
        if (!matches_locked(generation, tick, phase) ||
            task >= state_.expected_tasks || seen_[task]) {
            return false;
        }
        seen_[task] = true;
        ++state_.entered;
        ++state_.active;
        if (state_.first_arrival_sequence == 0)
            state_.first_arrival_sequence = ++sequence_;

        const auto identity = std::this_thread::get_id();
        bool known = false;
        for (std::size_t index = 0; index < state_.distinct_threads; ++index)
            known = known || threads_[index] == identity;
        if (!known) {
            if (state_.distinct_threads < threads_.size())
                threads_[state_.distinct_threads++] = identity;
            else
                state_.thread_identity_overflow = true;
        }

        if (!state_.released) {
            ++state_.waiting;
            changed_.notify_all();
            if (!changed_.wait_until(lock, deadline_, [this] { return state_.released; }))
                release_locked(true);
            --state_.waiting;
        }
        ready_[task] = true;
        return true;
    }

    void complete(std::uint64_t generation, std::uint64_t tick,
                  std::uint32_t phase, std::size_t task) noexcept {
        if (generation == 0) return;
        std::lock_guard lock(mutex_);
        if (!matches_locked(generation, tick, phase) ||
            task >= state_.expected_tasks || !ready_[task] || done_[task]) {
            return;
        }
        done_[task] = true;
        if (state_.active != 0) --state_.active;
        ++state_.completed;
        if (state_.completed == state_.expected_tasks)
            state_.drained_sequence = ++sequence_;
        changed_.notify_all();
    }

    void end_dispatch(std::uint64_t generation, std::uint64_t tick,
                      std::uint32_t phase) noexcept {
        if (generation == 0) return;
        std::lock_guard lock(mutex_);
        if (!matches_locked(generation, tick, phase) ||
            state_.dispatch_return_sequence != 0) {
            return;
        }
        state_.dispatch_return_sequence = ++sequence_;
        state_.armed = false;
        changed_.notify_all();
    }

    bool mark_stop(std::uint64_t generation) noexcept {
        std::lock_guard lock(mutex_);
        if (generation == 0 || generation != state_.generation ||
            !state_.selected || state_.released || state_.stop_sequence != 0 ||
            state_.waiting < state_.minimum_claims ||
            state_.distinct_threads < state_.minimum_claims ||
            state_.dispatch_return_sequence != 0) {
            return false;
        }
        state_.stop_sequence = ++sequence_;
        state_.stop_waiting = state_.waiting;
        state_.stop_active = state_.active;
        changed_.notify_all();
        return true;
    }

    bool release(std::uint64_t generation) noexcept {
        std::lock_guard lock(mutex_);
        if (generation == 0 || generation != state_.generation ||
            !state_.selected || state_.released) {
            return false;
        }
        if (Clock::now() >= deadline_) {
            release_locked(true);
            return false;
        }
        release_locked(false);
        return true;
    }

    Snapshot snapshot() const noexcept {
        std::lock_guard lock(mutex_);
        return state_;
    }

private:
    bool matches_locked(std::uint64_t generation, std::uint64_t tick,
                        std::uint32_t phase) const noexcept {
        return state_.selected && generation == state_.generation &&
               tick == state_.tick && phase == state_.phase;
    }

    void release_locked(bool timed_out) noexcept {
        if (state_.released) return;
        state_.timed_out = timed_out;
        state_.released = true;
        state_.release_sequence = ++sequence_;
        changed_.notify_all();
    }

    mutable std::mutex mutex_;
    std::condition_variable changed_;
    Snapshot state_{};
    std::array<bool, kMaximumTasks> seen_{};
    std::array<bool, kMaximumTasks> ready_{};
    std::array<bool, kMaximumTasks> done_{};
    std::array<std::thread::id, kMaximumThreads> threads_{};
    Clock::time_point deadline_{};
    std::uint64_t generation_ = 0;
    std::uint64_t sequence_ = 0;
};

inline WorldPhaseGate& world_phase_gate() noexcept {
    static WorldPhaseGate gate;
    return gate;
}

}  // namespace cybersand::play_busy_test
