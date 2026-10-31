// Opt-in diagnostic broker. No code from this file runs in the production host.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <dbghelp.h>
#include <psapi.h>
#include <shellapi.h>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cwchar>
#include <cstdint>
#include <fcntl.h>
#include <io.h>
#include <map>
#include <string>
#include <vector>

static_assert(sizeof(void *) == 8, "Only the pinned x86_64 target is supported");
static constexpr DWORD CAPTURE_LIMIT_MS = 15000;
static constexpr unsigned MAX_CAPTURES = 8;
static constexpr unsigned MAX_EVENTS = 20000;
static FILE *events = nullptr;
static ULONGLONG began = 0;

static std::string utf8(const std::wstring &s) {
    if (s.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
    if (size <= 0) return "<unavailable-path>";
    std::string result(static_cast<size_t>(size), '\0');
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, s.data(), static_cast<int>(s.size()), result.data(), size, nullptr, nullptr);
    return result;
}
static std::string json(const std::wstring &s) {
    const std::string bytes = utf8(s);
    std::string result = "\"";
    for (unsigned char c : bytes) {
        if (c == '"' || c == '\\') { result += '\\'; result += static_cast<char>(c); }
        else if (c < 32) { char escaped[7]; sprintf_s(escaped, "\\u%04x", c); result += escaped; }
        else result += static_cast<char>(c);
    }
    return result + "\"";
}
static void emit(const std::string &line) {
    fprintf(events, "%s\n", line.c_str()); fflush(events);
}
static std::string number(ULONGLONG n) { return std::to_string(n); }
static ULONGLONG elapsed() { return GetTickCount64() - began; }
static std::wstring quote(const std::wstring &s) {
    std::wstring result = L"\""; unsigned slash = 0;
    for (wchar_t c : s) {
        if (c == L'\\') { ++slash; continue; }
        result.append(c == L'"' ? slash * 2 + 1 : slash, L'\\');
        slash = 0; result += c;
    }
    result.append(slash * 2, L'\\'); return result + L'"';
}
static std::wstring command(const std::vector<std::wstring> &args) {
    std::wstring result;
    for (const auto &arg : args) { if (!result.empty()) result += L' '; result += quote(arg); }
    return result;
}
static std::wstring file_path(HANDLE file) {
    if (!file || file == INVALID_HANDLE_VALUE) return {};
    std::vector<wchar_t> value(32768);
    DWORD size = GetFinalPathNameByHandleW(file, value.data(), static_cast<DWORD>(value.size()), FILE_NAME_NORMALIZED);
    if (!size || size >= value.size()) return {};
    std::wstring path(value.data(), size);
    if (path.rfind(L"\\\\?\\", 0) == 0) path.erase(0, 4);
    return path;
}
static std::wstring image_path(HANDLE process, HMODULE module, HANDLE file, bool executable) {
    auto result = file_path(file);
    if (!result.empty()) return result;
    std::vector<wchar_t> value(32768);
    DWORD length = static_cast<DWORD>(value.size());
    if (executable) {
        if (!QueryFullProcessImageNameW(process, 0, value.data(), &length)) return {};
    } else {
        length = K32GetModuleFileNameExW(process, module, value.data(), length);
        if (!length || length >= value.size()) return {};
    }
    return std::wstring(value.data(), length);
}
static bool write_bytes(const std::wstring &path, const void *data, DWORD size) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    bool ok = WriteFile(file, data, size, &written, nullptr) && written == size && FlushFileBuffers(file);
    CloseHandle(file); return ok;
}

// Separate process: DbgHelp can block, so the debugger imposes an independent
// 15-second/remaining-case bound without releasing the stopped exception event.
static std::wstring hex_record(const EXCEPTION_RECORD &record) {
    const auto *bytes = reinterpret_cast<const unsigned char *>(&record);
    std::wstring result;
    for (size_t i = 0; i < sizeof(record); ++i) {
        result += L"0123456789abcdef"[bytes[i] >> 4]; result += L"0123456789abcdef"[bytes[i] & 15];
    }
    return result;
}
static int dump_worker(DWORD pid, DWORD tid, const std::wstring &prefix, const std::wstring &encoded) {
    wchar_t control[2]{};
    if (GetEnvironmentVariableW(L"CYBERSAND_CRASH_DUMP_TIMEOUT_CONTROL", control, 2) == 1 && control[0] == L'1') Sleep(20000);
    CONTEXT context{}; EXCEPTION_RECORD exception{};
    if (encoded.size() != sizeof(exception) * 2) return 81;
    auto *bytes = reinterpret_cast<unsigned char *>(&exception);
    for (size_t i = 0; i < sizeof(exception); ++i) {
        unsigned value = 0;
        if (swscanf_s(encoded.substr(i * 2, 2).c_str(), L"%2x", &value) != 1) return 81;
        bytes[i] = static_cast<unsigned char>(value);
    }
    HANDLE thread = OpenThread(THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION, FALSE, tid);
    context.ContextFlags = CONTEXT_ALL;
    bool captured = thread && GetThreadContext(thread, &context);
    if (thread) CloseHandle(thread);
    if (!captured || !write_bytes(prefix + L".context", &context, sizeof(context)) ||
        !write_bytes(prefix + L".exception", &exception, sizeof(exception))) return 81;
    // The original nested-record address remains in the raw .exception bytes.
    // No foreign pointer is followed in this helper's address space.
    exception.ExceptionRecord = nullptr;
    EXCEPTION_POINTERS pointers{&exception, &context};
    MINIDUMP_EXCEPTION_INFORMATION info{tid, &pointers, FALSE};
    HANDLE process = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!process) return 82;
    HANDLE file = CreateFileW((prefix + L".dmp").c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) { CloseHandle(process); return 83; }
    BOOL ok = MiniDumpWriteDump(process, pid, file,
        static_cast<MINIDUMP_TYPE>(MiniDumpNormal | MiniDumpWithThreadInfo), &info, nullptr, nullptr);
    DWORD error = ok ? 0 : GetLastError();
    FlushFileBuffers(file); CloseHandle(file); CloseHandle(process);
    fprintf(stderr, "MINIDUMP pid=%lu tid=%lu result=%d error=%lu\n", pid, tid, ok ? 1 : 0, error);
    return ok ? 0 : 84;
}

struct Process { HANDLE handle = nullptr; std::map<DWORD, HANDLE> threads; bool loader_breakpoint = false; };

int wmain(int argc, wchar_t **argv) {
    if (argc == 6 && wcscmp(argv[1], L"--dump-worker") == 0)
        return dump_worker(wcstoul(argv[2], nullptr, 10), wcstoul(argv[3], nullptr, 10), argv[4], argv[5]);
    if (argc < 7 || wcscmp(argv[1], L"--output") || wcscmp(argv[3], L"--timeout-ms") || wcscmp(argv[5], L"--")) return 64;
    const std::wstring output = argv[2];
    const DWORD limit = wcstoul(argv[4], nullptr, 10);
    if (limit == 0 || limit > 240000) return 64;
    std::vector<std::wstring> arguments(argv + 6, argv + argc);
    std::wstring line = command(arguments);
    if (line.size() >= 32767) return 64;
    HANDLE event_file = CreateFileW((output + L"\\events.jsonl").c_str(), GENERIC_WRITE, FILE_SHARE_READ,
        nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (event_file == INVALID_HANDLE_VALUE) return 74;
    int event_fd = _open_osfhandle(reinterpret_cast<intptr_t>(event_file), _O_WRONLY | _O_BINARY);
    if (event_fd == -1) { CloseHandle(event_file); return 74; }
    events = _fdopen(event_fd, "wb");
    if (!events) { _close(event_fd); return 74; }
    HANDLE dump_job = CreateJobObjectW(nullptr, nullptr);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION job_limits{};
    job_limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!dump_job || !SetInformationJobObject(dump_job, JobObjectExtendedLimitInformation, &job_limits, sizeof(job_limits))) {
        if (dump_job) CloseHandle(dump_job); fclose(events); return 74;
    }
    began = GetTickCount64();
    emit("{\"type\":\"start\",\"schema\":\"play-windows-crash-v1\",\"broker_pid\":" + number(GetCurrentProcessId()) +
         ",\"timeout_ms\":" + number(limit) + ",\"command_line\":" + json(line) + "}");
    SECURITY_ATTRIBUTES attributes{sizeof(attributes), nullptr, TRUE};
    HANDLE log = CreateFileW((output + L"\\engine.log").c_str(), GENERIC_WRITE, FILE_SHARE_READ, &attributes, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (log == INVALID_HANDLE_VALUE) { CloseHandle(dump_job); fclose(events); return 74; }
    STARTUPINFOW startup{}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdOutput = log; startup.hStdError = log; startup.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    PROCESS_INFORMATION child{};
    if (!CreateProcessW(arguments[0].c_str(), line.data(), nullptr, nullptr, TRUE,
            DEBUG_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_UNICODE_ENVIRONMENT,
            nullptr, nullptr, &startup, &child)) {
        emit("{\"type\":\"error\",\"operation\":\"CreateProcess\",\"win32_error\":" + number(GetLastError()) + "}");
        CloseHandle(log); CloseHandle(dump_job); fclose(events); return 74;
    }
    const DWORD root = child.dwProcessId;
    CloseHandle(child.hProcess); CloseHandle(child.hThread);
    if (!DebugSetProcessKillOnExit(TRUE)) { CloseHandle(log); CloseHandle(dump_job); fclose(events); return 74; }
    std::map<DWORD, Process> processes;
    DWORD root_exit = STILL_ACTIVE, failure_exit = 0; unsigned captures = 0, errors = 0, event_count = 0;
    bool timed_out = false, saw_root = false;
    std::wstring broker(32768, L'\0');
    DWORD broker_size = GetModuleFileNameW(nullptr, broker.data(), static_cast<DWORD>(broker.size()));
    broker.resize(broker_size);
    for (;;) {
        const ULONGLONG now = elapsed();
        if (now >= limit) { timed_out = true; break; }
        DEBUG_EVENT event{};
        if (!WaitForDebugEvent(&event, static_cast<DWORD>(std::min<ULONGLONG>(100, limit - now)))) {
            DWORD error = GetLastError();
            if (error == ERROR_SEM_TIMEOUT) continue;
            emit("{\"type\":\"error\",\"operation\":\"WaitForDebugEvent\",\"win32_error\":" + number(error) + "}");
            ++errors; break;
        }
        if (++event_count > MAX_EVENTS) { ++errors; break; }
        DWORD disposition = DBG_CONTINUE;
        const DWORD pid = event.dwProcessId, tid = event.dwThreadId;
        const std::string common = ",\"pid\":" + number(pid) + ",\"tid\":" + number(tid) +
            ",\"event_id\":" + number(event_count) + ",\"time_ms\":" + number(elapsed());
        switch (event.dwDebugEventCode) {
        case CREATE_PROCESS_DEBUG_EVENT: {
            auto &value = event.u.CreateProcessInfo;
            processes[pid].handle = value.hProcess; processes[pid].threads[tid] = value.hThread;
            if (pid == root) saw_root = true;
            std::wstring image = image_path(value.hProcess, nullptr, value.hFile, true);
            emit("{\"type\":\"process\"" + common + ",\"root\":" + (pid == root ? "true" : "false") +
                 ",\"image\":" + json(image) + ",\"base\":" + number(reinterpret_cast<ULONG_PTR>(value.lpBaseOfImage)) + "}");
            if (value.hFile) CloseHandle(value.hFile);
            break;
        }
        case CREATE_THREAD_DEBUG_EVENT: processes[pid].threads[tid] = event.u.CreateThread.hThread; break;
        case EXIT_THREAD_DEBUG_EVENT: processes[pid].threads.erase(tid); break;
        case LOAD_DLL_DEBUG_EVENT: {
            auto &value = event.u.LoadDll;
            emit("{\"type\":\"module\"" + common + ",\"path\":" + json(image_path(processes[pid].handle,
                 static_cast<HMODULE>(value.lpBaseOfDll), value.hFile, false)) +
                 ",\"base\":" + number(reinterpret_cast<ULONG_PTR>(value.lpBaseOfDll)) + "}");
            if (value.hFile) CloseHandle(value.hFile);
            break;
        }
        case UNLOAD_DLL_DEBUG_EVENT:
            emit("{\"type\":\"unload\"" + common + ",\"base\":" +
                 number(reinterpret_cast<ULONG_PTR>(event.u.UnloadDll.lpBaseOfDll)) + "}");
            break;
        case EXCEPTION_DEBUG_EVENT: {
            auto &value = event.u.Exception; auto &process = processes[pid];
            const DWORD code = value.ExceptionRecord.ExceptionCode;
            const bool loader = value.dwFirstChance && code == EXCEPTION_BREAKPOINT && !process.loader_breakpoint;
            if (loader) process.loader_breakpoint = true;
            disposition = loader ? DBG_CONTINUE : DBG_EXCEPTION_NOT_HANDLED;
            const unsigned event_id = event_count;
            emit("{\"type\":\"exception\"" + common + ",\"code\":" + number(code) + ",\"first_chance\":" + (value.dwFirstChance ? "true" : "false") +
                 ",\"address\":" + number(reinterpret_cast<ULONG_PTR>(value.ExceptionRecord.ExceptionAddress)) +
                 ",\"loader_breakpoint\":" + (loader ? "true" : "false") + ",\"continued_as\":" + number(disposition) + "}");
            if (!loader && (code == EXCEPTION_ACCESS_VIOLATION || !value.dwFirstChance)) {
                if (++captures > MAX_CAPTURES) { ++errors; break; }
                const ULONGLONG capture_started = GetTickCount64();
                const std::wstring name = L"fault-" + std::to_wstring(pid) + L"-" + std::to_wstring(tid) + L"-" + std::to_wstring(event_id);
                const std::wstring prefix = output + L"\\" + name;
                DWORD dump_exit = 85, helper_pid = 0; bool capture_timeout = false, joined = false, terminated = false;
                wchar_t control[2]{};
                const bool hung_control = GetEnvironmentVariableW(L"CYBERSAND_CRASH_DUMP_TIMEOUT_CONTROL", control, 2) == 1 && control[0] == L'1';
                const DWORD capture_limit = hung_control ? 1000 : CAPTURE_LIMIT_MS;
                if (elapsed() < limit) {
                    std::wstring dump_command = command({broker, L"--dump-worker", std::to_wstring(pid), std::to_wstring(tid), prefix, hex_record(value.ExceptionRecord)});
                    SIZE_T attribute_bytes = 0;
                    InitializeProcThreadAttributeList(nullptr, 1, 0, &attribute_bytes);
                    std::vector<unsigned char> attribute_storage(attribute_bytes);
                    STARTUPINFOEXW dump_start{}; dump_start.StartupInfo.cb = sizeof(dump_start);
                    dump_start.lpAttributeList = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attribute_storage.data());
                    bool initialized = attribute_bytes && InitializeProcThreadAttributeList(dump_start.lpAttributeList, 1, 0, &attribute_bytes);
                    bool attributes_ready = initialized && UpdateProcThreadAttribute(dump_start.lpAttributeList, 0,
                        PROC_THREAD_ATTRIBUTE_JOB_LIST, &dump_job, sizeof(dump_job), nullptr, nullptr);
                    PROCESS_INFORMATION dump{};
                    // Atomic creation-time job membership closes the orphan gap
                    // between process creation and a later AssignProcess call.
                    if (attributes_ready && CreateProcessW(broker.c_str(), dump_command.data(), nullptr, nullptr, FALSE,
                            CREATE_NO_WINDOW | CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT,
                            nullptr, nullptr, &dump_start.StartupInfo, &dump)) {
                        helper_pid = dump.dwProcessId;
                        const ULONGLONG until = std::min(capture_started + capture_limit, began + limit);
                        const ULONGLONG created_at = GetTickCount64();
                        const ULONGLONG available = until > created_at ? until - created_at : 0;
                        const ULONGLONG work_until = until - std::min<ULONGLONG>(2000, available / 2);
                        DWORD wait = WAIT_TIMEOUT;
                        bool assigned = ResumeThread(dump.hThread) != static_cast<DWORD>(-1);
                        while (assigned && wait == WAIT_TIMEOUT) {
                            const ULONGLONG tick = GetTickCount64();
                            if (tick >= work_until) break;
                            wait = WaitForSingleObject(dump.hProcess, static_cast<DWORD>(std::min<ULONGLONG>(100, work_until - tick)));
                        }
                        if (wait != WAIT_OBJECT_0) {
                            capture_timeout = assigned && wait == WAIT_TIMEOUT;
                            terminated = TerminateProcess(dump.hProcess, capture_timeout ? 124 : 86) != FALSE;
                            do {
                                const ULONGLONG tick = GetTickCount64();
                                if (tick >= until) break;
                                wait = WaitForSingleObject(dump.hProcess, static_cast<DWORD>(std::min<ULONGLONG>(100, until - tick)));
                            } while (wait == WAIT_TIMEOUT);
                        }
                        joined = wait == WAIT_OBJECT_0;
                        if (joined) GetExitCodeProcess(dump.hProcess, &dump_exit);
                        CloseHandle(dump.hProcess); CloseHandle(dump.hThread);
                    }
                    if (initialized) DeleteProcThreadAttributeList(dump_start.lpAttributeList);
                }
                if (dump_exit != 0 || !joined) ++errors;
                emit("{\"type\":\"capture\"" + common + ",\"prefix\":" + json(name) + ",\"capture_ms\":" + number(GetTickCount64() - capture_started) +
                     ",\"capture_exit\":" + number(dump_exit) + ",\"timed_out\":" + (capture_timeout ? "true" : "false") +
                     ",\"context_bytes\":" + number(sizeof(CONTEXT)) + ",\"exception_bytes\":" + number(sizeof(value.ExceptionRecord)) +
                     ",\"helper_pid\":" + number(helper_pid) + ",\"helper_joined\":" + (joined ? "true" : "false") +
                     ",\"helper_terminated\":" + (terminated ? "true" : "false") +
                     ",\"helper_control\":" + (hung_control ? "true" : "false") + ",\"capture_limit_ms\":" + number(capture_limit) + "}");
            }
            break;
        }
        case EXIT_PROCESS_DEBUG_EVENT: {
            DWORD code = event.u.ExitProcess.dwExitCode;
            if (pid == root) root_exit = code;
            if (code != 0 && failure_exit == 0) failure_exit = code;
            emit("{\"type\":\"exit\"" + common + ",\"code\":" + number(code) + "}");
            processes.erase(pid); break;
        }
        case RIP_EVENT: ++errors; break;
        default: break;
        }
        if (!ContinueDebugEvent(pid, tid, disposition)) { ++errors; break; }
        emit("{\"type\":\"continued\"" + common + ",\"kind\":" + number(event.dwDebugEventCode) +
             ",\"status\":" + number(disposition) + "}");
        if (errors) break;
        if (saw_root && processes.empty()) break;
    }
    // On deadline or infrastructure failure only tracked owned processes die.
    // DebugSetProcessKillOnExit is an additional guarantee if the broker dies.
    for (const auto &item : processes) TerminateProcess(item.second.handle, timed_out ? 124 : 74);
    DWORD effective = timed_out ? 124 : errors ? 74 : failure_exit ? failure_exit : root_exit;
    emit("{\"type\":\"end\",\"root_pid\":" + number(root) + ",\"root_exit\":" + number(root_exit) +
         ",\"effective_exit\":" + number(effective) + ",\"timed_out\":" + (timed_out ? "true" : "false") +
         ",\"errors\":" + number(errors) + ",\"all_processes_exited\":" + (saw_root && processes.empty() ? "true" : "false") +
         ",\"elapsed_ms\":" + number(elapsed()) + "}");
    CloseHandle(log); CloseHandle(dump_job); fclose(events);
    return static_cast<int>(effective);
}
