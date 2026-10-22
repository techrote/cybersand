// Scratch-only poor-man's sampling profiler (Windows): a helper thread
// suspends the target thread every ~0.5 ms, records its RIP, and at exit
// resolves samples to function+line through DbgHelp and the PDB.
#pragma once
#define NOMINMAX
#include <windows.h>
#include <dbghelp.h>
#include <algorithm>
#include <atomic>
#include <cstdio>
#include <map>
#include <string>
#include <thread>
#include <vector>
#pragma comment(lib, "dbghelp.lib")

struct Sampler {
    HANDLE target = nullptr;
    std::atomic<bool> stop{false};
    std::vector<DWORD64> samples;
    std::thread worker;
    void start() {
        DuplicateHandle(GetCurrentProcess(), GetCurrentThread(), GetCurrentProcess(), &target,
                        THREAD_ALL_ACCESS, FALSE, 0);
        timeBeginPeriod(1);
        worker = std::thread([this] {
            samples.reserve(1 << 20);
            while (!stop.load()) {
                if (SuspendThread(target) != static_cast<DWORD>(-1)) {
                    CONTEXT ctx{};
                    ctx.ContextFlags = CONTEXT_CONTROL;
                    if (GetThreadContext(target, &ctx)) samples.push_back(ctx.Rip);
                    ResumeThread(target);
                }
                Sleep(0);
                std::this_thread::sleep_for(std::chrono::microseconds(500));
            }
        });
    }
    void finish(int top = 40) {
        stop = true;
        worker.join();
        HANDLE process = GetCurrentProcess();
        SymSetOptions(SYMOPT_LOAD_LINES | SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS);
        SymInitialize(process, nullptr, TRUE);
        std::map<std::string, int> by_function, by_line;
        alignas(SYMBOL_INFO) char buffer[sizeof(SYMBOL_INFO) + 512];
        for (const auto rip : samples) {
            auto* symbol = reinterpret_cast<SYMBOL_INFO*>(buffer);
            symbol->SizeOfStruct = sizeof(SYMBOL_INFO);
            symbol->MaxNameLen = 500;
            DWORD64 displacement = 0;
            std::string name = SymFromAddr(process, rip, &displacement, symbol) ? symbol->Name : "?";
            ++by_function[name];
            IMAGEHLP_LINE64 line{};
            line.SizeOfStruct = sizeof(line);
            DWORD line_displacement = 0;
            if (SymGetLineFromAddr64(process, rip, &line_displacement, &line)) {
                std::string file = line.FileName;
                file = file.substr(file.find_last_of("\\/") + 1);
                ++by_line[file + ":" + std::to_string(line.LineNumber)];
            }
        }
        const auto print = [&](const char* title, const std::map<std::string, int>& m, int n) {
            std::vector<std::pair<int, std::string>> v;
            for (const auto& [k, c] : m) v.push_back({c, k});
            std::sort(v.rbegin(), v.rend());
            std::fprintf(stderr, "== %s (%zu samples)\n", title, samples.size());
            for (int i = 0; i < n && i < static_cast<int>(v.size()); ++i)
                std::fprintf(stderr, "%6.2f%%  %s\n", 100.0 * v[i].first / samples.size(), v[i].second.c_str());
        };
        print("functions", by_function, top);
        print("lines", by_line, top);
    }
};
