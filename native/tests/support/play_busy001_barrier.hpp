#pragma once
// Test-only gate. It never owns or inspects a World, Godot Object, or pool.
#include <array>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <mutex>
#include <thread>

namespace cybersand::test {
class PhaseGate final {
public:
    using Clock = std::chrono::steady_clock;
    static constexpr std::size_t max_tasks = 64;
    struct Ticket {
        std::uint64_t generation = 0, epoch = 0, phase = 0;
        bool operator==(const Ticket&) const = default;
    };
    struct Snapshot {
        Ticket ticket{};
        std::size_t expected = 0, entered = 0, completed = 0;
        std::size_t active = 0, waiting = 0, distinct_threads = 0;
        std::size_t stop_active = 0, stop_waiting = 0;
        std::uint64_t first_arrival = 0, stop = 0, release = 0, drained = 0;
        bool released = false, timed_out = false;
    };

    Ticket arm(std::uint64_t epoch, std::uint64_t phase, std::size_t tasks,
               std::size_t workers, std::chrono::milliseconds bound) {
        std::lock_guard lock(mutex_);
        if (epoch == 0 || phase == 0 || tasks < 2 || tasks > max_tasks || workers < 2 ||
            workers > max_tasks || bound.count() <= 0 || bound.count() > 5000 ||
            (state_.expected != 0 && state_.completed != state_.expected) ||
            generation_ == std::numeric_limits<std::uint64_t>::max()) return {};
        state_ = {};
        state_.ticket = {++generation_, epoch, phase};
        state_.expected = tasks;
        seen_.fill(false); ready_.fill(false); done_.fill(false); threads_.fill({});
        deadline_ = Clock::now() + bound;
        return state_.ticket;
    }

    // Called only after the real pool has claimed the task and invoked its callback.
    // The callback must call complete() once after doing its work, even after a timeout.
    bool arrive_and_wait(Ticket ticket, std::size_t task) {
        std::unique_lock lock(mutex_);
        if (!matches(ticket) || task >= state_.expected || seen_[task]) return false;
        seen_[task] = true;
        ++state_.entered; ++state_.active;
        if (!state_.first_arrival) state_.first_arrival = ++sequence_;
        const auto id = std::this_thread::get_id();
        bool known = false;
        for (std::size_t i = 0; i < state_.distinct_threads; ++i) known |= threads_[i] == id;
        if (!known) threads_[state_.distinct_threads++] = id;
        ++state_.waiting;
        changed_.notify_all();
        if (!changed_.wait_until(lock, deadline_, [this] { return state_.released; }))
            release_locked(true);
        --state_.waiting;
        ready_[task] = true;
        return true;
    }

    bool complete(Ticket ticket, std::size_t task) {
        std::lock_guard lock(mutex_);
        if (!matches(ticket) || task >= state_.expected || !ready_[task] || done_[task]) return false;
        done_[task] = true;
        --state_.active; ++state_.completed;
        if (state_.completed == state_.expected) state_.drained = ++sequence_;
        changed_.notify_all();
        return true;
    }

    bool wait_for_held(Ticket ticket, std::size_t minimum, std::chrono::milliseconds bound) {
        std::unique_lock lock(mutex_);
        if (!matches(ticket) || minimum < 2 || minimum > state_.expected || bound.count() <= 0)
            return false;
        const auto limit = Clock::now() + bound;
        changed_.wait_until(lock, limit, [this, minimum] {
            return state_.waiting >= minimum || state_.released;
        });
        if (!state_.released && Clock::now() >= deadline_) release_locked(true);
        return !state_.released && state_.waiting >= minimum &&
               state_.distinct_threads >= minimum;
    }

    // This marks the TEST's stop request. It is not a production worker stop fence.
    bool mark_stop(Ticket ticket) {
        std::lock_guard lock(mutex_);
        if (!matches(ticket)) return false;
        if (!state_.released && Clock::now() >= deadline_) release_locked(true);
        if (state_.released || state_.stop || state_.waiting < 2) return false;
        state_.stop = ++sequence_;
        state_.stop_active = state_.active;
        state_.stop_waiting = state_.waiting;
        return true;
    }

    bool release(Ticket ticket) {
        std::lock_guard lock(mutex_);
        if (!matches(ticket) || state_.released) return false;
        if (Clock::now() >= deadline_) { release_locked(true); return false; }
        release_locked(false);
        return true;
    }

    Snapshot snapshot() const {
        std::lock_guard lock(mutex_);
        return state_;
    }

private:
    bool matches(Ticket ticket) const {
        return ticket.generation != 0 && ticket == state_.ticket;
    }
    void release_locked(bool timed_out) {
        if (state_.released) return;
        state_.timed_out = timed_out;
        state_.released = true;
        state_.release = ++sequence_;
        changed_.notify_all();
    }
    mutable std::mutex mutex_;
    std::condition_variable changed_;
    Snapshot state_{};
    std::array<bool, max_tasks> seen_{}, ready_{}, done_{};
    std::array<std::thread::id, max_tasks> threads_{};
    Clock::time_point deadline_{};
    std::uint64_t generation_ = 0, sequence_ = 0;
};
}  // namespace cybersand::test
