#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <cstdint>

#if defined(WINDOWS_ENABLED)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

namespace godot {

class CyberThreadCpuClock final : public RefCounted {
    GDCLASS(CyberThreadCpuClock, RefCounted);

public:
    std::int64_t thread_cpu_time_100ns() {
#if defined(WINDOWS_ENABLED)
        FILETIME creation{}, exit{}, kernel{}, user{};
        if (!::GetThreadTimes(::GetCurrentThread(), &creation, &exit, &kernel, &user)) {
            last_error_code_ = static_cast<std::int64_t>(::GetLastError());
            return -1;
        }
        ULARGE_INTEGER k{}, u{};
        k.LowPart = kernel.dwLowDateTime;
        k.HighPart = kernel.dwHighDateTime;
        u.LowPart = user.dwLowDateTime;
        u.HighPart = user.dwHighDateTime;
        last_error_code_ = 0;
        const auto total = k.QuadPart + u.QuadPart;
        if (total > static_cast<unsigned long long>(INT64_MAX)) return -1;
        return static_cast<std::int64_t>(total);
#else
        last_error_code_ = -1;
        return -1;
#endif
    }

    [[nodiscard]] std::int64_t last_error_code() const noexcept {
        return last_error_code_;
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("thread_cpu_time_100ns"), &CyberThreadCpuClock::thread_cpu_time_100ns);
        ClassDB::bind_method(D_METHOD("last_error_code"), &CyberThreadCpuClock::last_error_code);
    }

private:
    std::int64_t last_error_code_ = 0;
};

}  // namespace godot
