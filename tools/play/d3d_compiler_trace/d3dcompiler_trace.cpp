// NONQUALIFYING Windows x64 shader diagnostic. Never deploy with gameplay.
// Every compiler argument, flag, pointer, HRESULT, blob, and LastError is forwarded.
// DllMain does no I/O, loading, allocation, logging, waiting, or synchronization.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#include <d3dcompiler.h>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <sstream>
#include <string>
#include <vector>
#include "proxy_exports.h"

namespace {
constexpr LONG kMaxEvents = 10000;
constexpr LONG kMaxCompileCaptures = 256;
constexpr unsigned long long kMaxOneDump = 32ull * 1024 * 1024;
constexpr LONG64 kMaxTotalDump = 256ll * 1024 * 1024;
INIT_ONCE g_once = INIT_ONCE_STATIC_INIT;
SRWLOCK g_logLock = SRWLOCK_INIT;
HMODULE g_proxy = nullptr;
HMODULE g_real = nullptr;
FARPROC g_functions[kExportCount] = {};
volatile LONG g_forwardSeen[kExportCount] = {};
HANDLE g_log = INVALID_HANDLE_VALUE;
std::wstring g_directory;
LARGE_INTEGER g_frequency = {};
volatile LONG g_events = 0, g_droppedEvents = 0, g_compileCalls = 0;
volatile LONG g_loggingErrors = 0, g_skippedCaptures = 0;
volatile LONG64 g_dumpBytes = 0;

[[noreturn]] void fail_closed() {
    // A diagnostic helper that cannot forward the authentic API must fail visibly.
    TerminateProcess(GetCurrentProcess(), 0xE0000309u);
    __assume(0);
}

template <typename T> T function_pointer(FARPROC pointer) {
    T result;
    static_assert(sizeof(result) == sizeof(pointer), "x64 function pointer size");
    std::memcpy(&result, &pointer, sizeof(result));
    return result;
}

std::string utf8(const wchar_t *text) {
    if (!text) return {};
    int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, nullptr, 0, nullptr, nullptr);
    if (count <= 0) return {};
    std::string result(static_cast<size_t>(count), '\0');
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, result.data(), count, nullptr, nullptr) != count) return {};
    result.pop_back();
    return result;
}

std::string quoted(const std::string &value) {
    static const char hex[] = "0123456789abcdef";
    std::string result = "\"";
    for (unsigned char character : value) {
        if (character == '"' || character == '\\') {
            result += '\\'; result += static_cast<char>(character);
        } else if (character < 32) {
            result += "\\u00"; result += hex[character >> 4]; result += hex[character & 15];
        } else {
            result += static_cast<char>(character);
        }
    }
    result += '"';
    return result;
}

std::string text_field(const char *value) {
    if (!value) return "null";
    constexpr size_t limit = 4096;
    size_t length = 0;
    while (length < limit && value[length]) ++length;
    // Exact shader bytes are separate files; a metadata truncation is explicit.
    return "{\"value\":" + quoted(std::string(value, length)) +
           ",\"truncated\":" + (length == limit ? "true}" : "false}");
}

std::string sha256_file(const wchar_t *path) {
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    HANDLE input = INVALID_HANDLE_VALUE;
    std::string result;
    DWORD objectSize = 0, received = 0;
    std::vector<unsigned char> object;
    unsigned char digest[32] = {};
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0) return {};
    if (BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, reinterpret_cast<PUCHAR>(&objectSize),
                          sizeof(objectSize), &received, 0) >= 0 && objectSize && objectSize <= 1024 * 1024) {
        object.resize(objectSize);
        if (BCryptCreateHash(algorithm, &hash, object.data(), objectSize, nullptr, 0, 0) >= 0) {
            input = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                nullptr, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
            if (input != INVALID_HANDLE_VALUE) {
                unsigned char buffer[65536];
                bool valid = true;
                for (;;) {
                    DWORD count = 0;
                    if (!ReadFile(input, buffer, sizeof(buffer), &count, nullptr)) { valid = false; break; }
                    if (!count) break;
                    if (BCryptHashData(hash, buffer, count, 0) < 0) { valid = false; break; }
                }
                if (valid && BCryptFinishHash(hash, digest, sizeof(digest), 0) >= 0) {
                    static const char hex[] = "0123456789abcdef";
                    for (unsigned char byte : digest) { result += hex[byte >> 4]; result += hex[byte & 15]; }
                }
            }
        }
    }
    if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
    if (hash) BCryptDestroyHash(hash);
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return result;
}

uintptr_t address_value(FARPROC pointer) {
    uintptr_t value = 0;
    static_assert(sizeof(value) == sizeof(pointer), "x64 address size");
    std::memcpy(&value, &pointer, sizeof(value));
    return value;
}

uintptr_t compiler_address(const char *name) {
    FARPROC pointer = GetProcAddress(g_real, name);
    if (!pointer) fail_closed();
    uintptr_t value = address_value(pointer);
    HMODULE owner = nullptr;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(value), &owner) || owner != g_real) fail_closed();
    return value;
}

struct Stamp { LONGLONG qpc; ULONGLONG kernel; ULONGLONG user; bool cpuValid; };
ULONGLONG ticks(FILETIME time) { return (static_cast<ULONGLONG>(time.dwHighDateTime) << 32) | time.dwLowDateTime; }
Stamp stamp() {
    LARGE_INTEGER wall = {};
    QueryPerformanceCounter(&wall);
    FILETIME creation = {}, exit = {}, kernel = {}, user = {};
    bool valid = GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernel, &user) != FALSE;
    return {wall.QuadPart, ticks(kernel), ticks(user), valid};
}

void emit(const std::string &fields) noexcept {
    try {
        LONG index = InterlockedIncrement(&g_events);
        if (index > kMaxEvents) { InterlockedIncrement(&g_droppedEvents); return; }
        if (g_log == INVALID_HANDLE_VALUE) { InterlockedIncrement(&g_loggingErrors); return; }
        std::ostringstream line;
        line << "{\"event_index\":" << index << ",\"pid\":" << GetCurrentProcessId()
             << ",\"tid\":" << GetCurrentThreadId() << ',' << fields << "}\n";
        std::string data = line.str();
        AcquireSRWLockExclusive(&g_logLock);
        DWORD written = 0;
        BOOL ok = WriteFile(g_log, data.data(), static_cast<DWORD>(data.size()), &written, nullptr);
        ReleaseSRWLockExclusive(&g_logLock);
        if (!ok || written != data.size()) InterlockedIncrement(&g_loggingErrors);
    } catch (...) { InterlockedIncrement(&g_loggingErrors); }
}

BOOL CALLBACK initialize(PINIT_ONCE, PVOID, PVOID *) {
    try {
        wchar_t system[MAX_PATH + 1] = {};
        UINT length = GetSystemDirectoryW(system, MAX_PATH);
        if (!length || length >= MAX_PATH) fail_closed();
        std::wstring original = std::wstring(system) + L"\\d3dcompiler_47.dll";
        // Absolute path + System32 dependency search; no renamed or modified compiler.
        g_real = LoadLibraryExW(original.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!g_real || g_real == g_proxy) fail_closed();
        wchar_t loaded[32768] = {};
        DWORD count = GetModuleFileNameW(g_real, loaded, 32768);
        if (!count || count >= 32768 || CompareStringOrdinal(loaded, -1, original.c_str(), -1, TRUE) != CSTR_EQUAL) fail_closed();
        std::string actualHash = sha256_file(loaded);
        if (actualHash != kExpectedOriginalSha256) fail_closed();
        for (unsigned int index = 0; index < kExportCount; ++index) {
            g_functions[index] = GetProcAddress(g_real, MAKEINTRESOURCEA(kExportOrdinals[index]));
            if (!g_functions[index]) fail_closed();
        }
        if (!QueryPerformanceFrequency(&g_frequency) || g_frequency.QuadPart <= 0) fail_closed();
        wchar_t directory[32768] = {};
        count = GetEnvironmentVariableW(L"PACE003_D3D_TRACE_DIR", directory, 32768);
        if (count && count < 32768) {
            wchar_t full[32768] = {};
            DWORD fullCount = GetFullPathNameW(directory, 32768, full, nullptr);
            DWORD attributes = GetFileAttributesW(directory);
            if (fullCount && fullCount < 32768 && CompareStringOrdinal(full, -1, directory, -1, TRUE) == CSTR_EQUAL &&
                attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
                g_directory = directory;
                std::wstring path = g_directory + L"\\d3d-trace-" + std::to_wstring(GetCurrentProcessId()) + L".jsonl";
                g_log = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
            }
        }
        wchar_t proxyPath[32768] = {};
        GetModuleFileNameW(g_proxy, proxyPath, 32768);
        std::string proxyHash = sha256_file(proxyPath);
        std::ostringstream fields;
        fields << "\"event\":\"identity\",\"scope\":\"NONQUALIFYING D3DCompiler passthrough\""
               << ",\"system_module\":" << quoted(utf8(loaded)) << ",\"system_sha256\":" << quoted(actualHash)
               << ",\"expected_system_sha256\":" << quoted(kExpectedOriginalSha256)
               << ",\"proxy_module\":" << quoted(utf8(proxyPath))
               << ",\"proxy_sha256\":" << quoted(proxyHash)
               << ",\"system_module_base\":" << reinterpret_cast<uintptr_t>(g_real)
               << ",\"d3dcompile_address\":" << compiler_address("D3DCompile")
               << ",\"d3dcompile2_address\":" << compiler_address("D3DCompile2")
               << ",\"qpc_frequency\":" << g_frequency.QuadPart << ",\"exports_forwarded\":" << kExportCount
               << ",\"max_events\":" << kMaxEvents << ",\"max_compile_captures\":" << kMaxCompileCaptures
               << ",\"max_one_dump_bytes\":" << kMaxOneDump << ",\"max_total_dump_bytes\":" << kMaxTotalDump;
        emit(fields.str());
        return TRUE;
    } catch (...) { fail_closed(); }
}

void ensure_initialized() {
    if (!InitOnceExecuteOnce(&g_once, initialize, nullptr, nullptr)) fail_closed();
}

std::string dump_bytes(LONG call, const wchar_t *kind, const void *data, SIZE_T size) {
    if (!data && size) return "{\"complete\":false,\"reason\":\"null_data\"}";
    if (g_directory.empty()) return "{\"complete\":false,\"reason\":\"no_trace_directory\"}";
    if (size > kMaxOneDump) { InterlockedIncrement(&g_skippedCaptures); return "{\"complete\":false,\"reason\":\"per_file_bound\"}"; }
    LONG64 reserved = InterlockedAdd64(&g_dumpBytes, static_cast<LONG64>(size));
    if (reserved > kMaxTotalDump) { InterlockedIncrement(&g_skippedCaptures); return "{\"complete\":false,\"reason\":\"total_dump_bound\"}"; }
    std::wstring name = L"d3d-" + std::to_wstring(GetCurrentProcessId()) + L"-" + std::to_wstring(call) + L"-" + kind;
    HANDLE output = CreateFileW((g_directory + L"\\" + name).c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                                nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    DWORD written = 0;
    bool ok = output != INVALID_HANDLE_VALUE && WriteFile(output, data, static_cast<DWORD>(size), &written, nullptr) && written == size;
    if (output != INVALID_HANDLE_VALUE) CloseHandle(output);
    if (!ok) InterlockedIncrement(&g_loggingErrors);
    return "{\"file\":" + quoted(utf8(name.c_str())) + ",\"bytes\":" + std::to_string(size) +
           ",\"written\":" + std::to_string(written) + ",\"complete\":" + (ok ? "true}" : "false}");
}

LONG begin_call(const char *api, LPCVOID source, SIZE_T size, LPCSTR sourceName, const D3D_SHADER_MACRO *defines,
                ID3DInclude *include, LPCSTR entry, LPCSTR target, UINT flags1, UINT flags2,
                UINT secondaryFlags, LPCVOID secondary, SIZE_T secondarySize) noexcept {
    LONG call = InterlockedIncrement(&g_compileCalls);
    try {
        if (call > kMaxCompileCaptures) {
            InterlockedIncrement(&g_skippedCaptures);
            if (call == kMaxCompileCaptures + 1)
                emit("\"event\":\"compile_capture_limit\",\"call\":" + std::to_string(call));
            return call;
        }
        std::ostringstream fields;
        fields << "\"event\":\"compile_begin\",\"call\":" << call << ",\"api\":" << quoted(api)
               << ",\"source\":" << dump_bytes(call, L"source.hlsl", source, size)
               << ",\"source_name\":" << text_field(sourceName) << ",\"entry\":" << text_field(entry)
               << ",\"target\":" << text_field(target) << ",\"flags1\":" << flags1 << ",\"flags2\":" << flags2
               << ",\"include_pointer_present\":" << (include ? "true" : "false")
               << ",\"secondary_flags\":" << secondaryFlags << ",\"secondary_size\":" << secondarySize;
        if (secondary || secondarySize) fields << ",\"secondary\":" << dump_bytes(call, L"secondary.bin", secondary, secondarySize);
        fields << ",\"defines_present\":" << (defines ? "true" : "false") << ",\"defines\":[";
        unsigned int macros = 0;
        if (defines) {
            while (macros < 256 && defines[macros].Name) {
                if (macros) fields << ',';
                fields << "{\"name\":" << text_field(defines[macros].Name) << ",\"definition\":" << text_field(defines[macros].Definition) << '}';
                ++macros;
            }
        }
        Stamp now = stamp();
        fields << "],\"defines_truncated\":" << (macros == 256 ? "true" : "false")
               << ",\"begin_qpc\":" << now.qpc << ",\"begin_thread_kernel_100ns\":" << now.kernel
               << ",\"begin_thread_user_100ns\":" << now.user << ",\"begin_cpu_valid\":" << (now.cpuValid ? "true" : "false");
        emit(fields.str());
    } catch (...) { InterlockedIncrement(&g_loggingErrors); }
    return call;
}

void end_call(LONG call, HRESULT result, Stamp before, Stamp after, ID3DBlob **code, ID3DBlob **errors) noexcept {
    try {
        if (call > kMaxCompileCaptures) return;
        std::ostringstream fields;
        fields << std::setprecision(17) << "\"event\":\"compile_end\",\"call\":" << call
               << ",\"hresult\":" << static_cast<unsigned long>(result)
               << ",\"call_start_qpc\":" << before.qpc << ",\"call_end_qpc\":" << after.qpc
               << ",\"wall_s\":" << static_cast<double>(after.qpc - before.qpc) / static_cast<double>(g_frequency.QuadPart)
               << ",\"cpu_valid\":" << (before.cpuValid && after.cpuValid ? "true" : "false")
               << ",\"thread_kernel_start_100ns\":" << before.kernel << ",\"thread_kernel_end_100ns\":" << after.kernel
               << ",\"thread_user_start_100ns\":" << before.user << ",\"thread_user_end_100ns\":" << after.user;
        if (before.cpuValid && after.cpuValid)
            fields << ",\"thread_cpu_s\":" << static_cast<double>((after.kernel - before.kernel) + (after.user - before.user)) / 10000000.0;
        if (code && *code) fields << ",\"bytecode\":" << dump_bytes(call, L"bytecode.bin", (*code)->GetBufferPointer(), (*code)->GetBufferSize());
        if (errors && *errors) fields << ",\"messages\":" << dump_bytes(call, L"messages.bin", (*errors)->GetBufferPointer(), (*errors)->GetBufferSize());
        fields << ",\"compile_calls_seen\":" << g_compileCalls << ",\"logging_errors\":" << g_loggingErrors
               << ",\"dropped_events\":" << g_droppedEvents << ",\"skipped_captures\":" << g_skippedCaptures;
        emit(fields.str());
    } catch (...) { InterlockedIncrement(&g_loggingErrors); }
}
}  // namespace

extern "C" FARPROC pace003_resolve(unsigned int index) {
    DWORD previousError = GetLastError();
    ensure_initialized();
    if (index >= kExportCount || !g_functions[index]) fail_closed();
    if (InterlockedCompareExchange(&g_forwardSeen[index], 1, 0) == 0) {
        try { emit("\"event\":\"forward_export_first_use\",\"name\":" + quoted(kExportNames[index]) +
                   ",\"ordinal\":" + std::to_string(kExportOrdinals[index])); }
        catch (...) { InterlockedIncrement(&g_loggingErrors); }
    }
    FARPROC result = g_functions[index];
    SetLastError(previousError);
    return result;
}

extern "C" HRESULT WINAPI pace003_D3DCompile(LPCVOID source, SIZE_T size, LPCSTR sourceName,
    const D3D_SHADER_MACRO *defines, ID3DInclude *include, LPCSTR entry, LPCSTR target,
    UINT flags1, UINT flags2, ID3DBlob **code, ID3DBlob **errors) {
    DWORD previousError = GetLastError();
    ensure_initialized();
    auto real = function_pointer<decltype(&D3DCompile)>(GetProcAddress(g_real, "D3DCompile"));
    if (!real) fail_closed();
    LONG call = begin_call("D3DCompile", source, size, sourceName, defines, include, entry, target, flags1, flags2, 0, nullptr, 0);
    Stamp before = stamp();
    SetLastError(previousError);
    HRESULT result = real(source, size, sourceName, defines, include, entry, target, flags1, flags2, code, errors);
    DWORD resultError = GetLastError();
    Stamp after = stamp();
    end_call(call, result, before, after, code, errors);
    SetLastError(resultError);
    return result;
}

extern "C" HRESULT WINAPI pace003_D3DCompile2(LPCVOID source, SIZE_T size, LPCSTR sourceName,
    const D3D_SHADER_MACRO *defines, ID3DInclude *include, LPCSTR entry, LPCSTR target,
    UINT flags1, UINT flags2, UINT secondaryFlags, LPCVOID secondary, SIZE_T secondarySize,
    ID3DBlob **code, ID3DBlob **errors) {
    DWORD previousError = GetLastError();
    ensure_initialized();
    auto real = function_pointer<decltype(&D3DCompile2)>(GetProcAddress(g_real, "D3DCompile2"));
    if (!real) fail_closed();
    LONG call = begin_call("D3DCompile2", source, size, sourceName, defines, include, entry, target, flags1, flags2, secondaryFlags, secondary, secondarySize);
    Stamp before = stamp();
    SetLastError(previousError);
    HRESULT result = real(source, size, sourceName, defines, include, entry, target, flags1, flags2, secondaryFlags, secondary, secondarySize, code, errors);
    DWORD resultError = GetLastError();
    Stamp after = stamp();
    end_call(call, result, before, after, code, errors);
    SetLastError(resultError);
    return result;
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_proxy = module;
    return TRUE;
}
