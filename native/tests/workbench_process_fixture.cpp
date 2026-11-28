#include <chrono>
#include <charconv>
#include <cstdint>
#include <limits>
#include <string_view>
#include <thread>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <cerrno>
#include <csignal>
#include <sys/types.h>
#endif

// Lifecycle test executable only. It produces no generator evidence and can
// never authorize Apply. Cancellation/timeout must retire this actual OS child.
int main(int argc, char** argv) {
    if (argc == 3 && std::string_view(argv[1]) == "probe") {
        const std::string_view text(argv[2]);
        std::uint64_t pid = 0;
        const auto parsed = std::from_chars(text.data(), text.data() + text.size(), pid);
        if (parsed.ec != std::errc{} || parsed.ptr != text.data() + text.size() || pid == 0) return 2;
#ifdef _WIN32
        if (pid > std::numeric_limits<DWORD>::max()) return 2;
        HANDLE process = OpenProcess(SYNCHRONIZE, FALSE, static_cast<DWORD>(pid));
        if (process == nullptr) return GetLastError() == ERROR_INVALID_PARAMETER ? 0 : 2;
        const DWORD result = WaitForSingleObject(process, 0);
        CloseHandle(process);
        return result == WAIT_OBJECT_0 ? 0 : 1;
#else
        if (pid > static_cast<std::uint64_t>(std::numeric_limits<pid_t>::max())) return 2;
        return ::kill(static_cast<pid_t>(pid), 0) == -1 && errno == ESRCH ? 0 : 1;
#endif
    }
    std::this_thread::sleep_for(std::chrono::seconds(60));
    return 0;
}
