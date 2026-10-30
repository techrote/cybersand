#pragma once

#if !defined(CYBERSAND_PLAY_BUSY_TEST_HOOK)
#error "CyberPlayBusyTestGate is test-only and requires CYBERSAND_PLAY_BUSY_TEST_HOOK"
#endif

#include "play_busy_world_gate.hpp"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <chrono>
#include <cstdint>

namespace godot {

// Test-only copied-value adapter to the native phase gate. It contains no World
// pointer and does not authorize Main to inspect mutable native storage.
class CyberPlayBusyTestGate final : public RefCounted {
    GDCLASS(CyberPlayBusyTestGate, RefCounted)

public:
    std::int64_t arm(std::int64_t minimum_claims, std::int64_t timeout_ms) {
        if (minimum_claims < 0 || timeout_ms < 0) return 0;
        return static_cast<std::int64_t>(
            cybersand::play_busy_test::world_phase_gate().arm(
                static_cast<std::size_t>(minimum_claims),
                std::chrono::milliseconds(timeout_ms)));
    }

    bool mark_stop(std::int64_t generation) {
        if (generation <= 0) return false;
        return cybersand::play_busy_test::world_phase_gate().mark_stop(
            static_cast<std::uint64_t>(generation));
    }

    bool release(std::int64_t generation) {
        if (generation <= 0) return false;
        return cybersand::play_busy_test::world_phase_gate().release(
            static_cast<std::uint64_t>(generation));
    }

    Dictionary status() const {
        const auto snapshot = cybersand::play_busy_test::world_phase_gate().snapshot();
        Dictionary out;
        out["generation"] = static_cast<std::int64_t>(snapshot.generation);
        out["tick"] = static_cast<std::int64_t>(snapshot.tick);
        out["phase"] = static_cast<std::int64_t>(snapshot.phase);
        out["expected_tasks"] = static_cast<std::int64_t>(snapshot.expected_tasks);
        out["minimum_claims"] = static_cast<std::int64_t>(snapshot.minimum_claims);
        out["entered"] = static_cast<std::int64_t>(snapshot.entered);
        out["waiting"] = static_cast<std::int64_t>(snapshot.waiting);
        out["active"] = static_cast<std::int64_t>(snapshot.active);
        out["completed"] = static_cast<std::int64_t>(snapshot.completed);
        out["distinct_threads"] = static_cast<std::int64_t>(snapshot.distinct_threads);
        out["stop_waiting"] = static_cast<std::int64_t>(snapshot.stop_waiting);
        out["stop_active"] = static_cast<std::int64_t>(snapshot.stop_active);
        out["dispatch_started_sequence"] =
            static_cast<std::int64_t>(snapshot.dispatch_started_sequence);
        out["first_arrival_sequence"] =
            static_cast<std::int64_t>(snapshot.first_arrival_sequence);
        out["stop_sequence"] = static_cast<std::int64_t>(snapshot.stop_sequence);
        out["release_sequence"] = static_cast<std::int64_t>(snapshot.release_sequence);
        out["drained_sequence"] = static_cast<std::int64_t>(snapshot.drained_sequence);
        out["dispatch_return_sequence"] =
            static_cast<std::int64_t>(snapshot.dispatch_return_sequence);
        out["armed"] = snapshot.armed;
        out["selected"] = snapshot.selected;
        out["released"] = snapshot.released;
        out["timed_out"] = snapshot.timed_out;
        out["thread_identity_overflow"] = snapshot.thread_identity_overflow;
        out["scope"] =
            "test-only copied phase-job synchronization; no World pointer or Godot call from pool tasks";
        return out;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("arm", "minimum_claims", "timeout_ms"),
                             &CyberPlayBusyTestGate::arm);
        ClassDB::bind_method(D_METHOD("mark_stop", "generation"),
                             &CyberPlayBusyTestGate::mark_stop);
        ClassDB::bind_method(D_METHOD("release", "generation"),
                             &CyberPlayBusyTestGate::release);
        ClassDB::bind_method(D_METHOD("status"), &CyberPlayBusyTestGate::status);
    }
};

}  // namespace godot
