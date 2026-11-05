// Forwarding d3dcompiler_47 proxy: records each D3DCompile call (source, flags, target, timing)
// into %CYBERSAND_FXC_TRACE% and forwards to the System32 compiler unchanged.
#include <windows.h>
#include <stdio.h>
#include <string.h>
typedef struct { const char *Name; const char *Definition; } MACRO;
typedef HRESULT (WINAPI *PFN_Compile)(LPCVOID, SIZE_T, LPCSTR, const MACRO*, void*, LPCSTR, LPCSTR, UINT, UINT, void**, void**);
typedef HRESULT (WINAPI *PFN_Disasm)(LPCVOID, SIZE_T, UINT, LPCSTR, void**);
static HMODULE real; static PFN_Compile real_compile; static PFN_Disasm real_disasm;
static CRITICAL_SECTION lock; static LONG counter; static LARGE_INTEGER freq;
static void ensure(void) {
    if (real) return;
    char path[MAX_PATH]; GetSystemDirectoryA(path, MAX_PATH); strcat_s(path, MAX_PATH, "/d3dcompiler_47.dll");
    real = LoadLibraryA(path);
    real_compile = (PFN_Compile)GetProcAddress(real, "D3DCompile");
    real_disasm = (PFN_Disasm)GetProcAddress(real, "D3DDisassemble");
}
BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
    if (reason == DLL_PROCESS_ATTACH) { InitializeCriticalSection(&lock); QueryPerformanceFrequency(&freq); }
    return TRUE;
}
__declspec(dllexport) HRESULT WINAPI D3DCompile(LPCVOID src, SIZE_T size, LPCSTR name, const MACRO *defines, void *include,
        LPCSTR entry, LPCSTR target, UINT flags1, UINT flags2, void **code, void **errors) {
    ensure();
    LONG id = InterlockedIncrement(&counter);
    char dir[MAX_PATH]; DWORD n = GetEnvironmentVariableA("CYBERSAND_FXC_TRACE", dir, MAX_PATH);
    LARGE_INTEGER t0, t1; QueryPerformanceCounter(&t0);
    FILETIME ct0, et, kt0, ut0, kt1, ut1; GetThreadTimes(GetCurrentThread(), &ct0, &et, &kt0, &ut0);
    HRESULT hr = real_compile(src, size, name, defines, include, entry, target, flags1, flags2, code, errors);
    QueryPerformanceCounter(&t1); GetThreadTimes(GetCurrentThread(), &ct0, &et, &kt1, &ut1);
    if (n > 0 && n < MAX_PATH) {
        char file[MAX_PATH * 2]; sprintf_s(file, sizeof(file), "%s/call_%04ld.hlsl", dir, id);
        FILE *f; if (fopen_s(&f, file, "wb") == 0) { fwrite(src, 1, size, f); fclose(f); }
        double wall = (double)(t1.QuadPart - t0.QuadPart) / (double)freq.QuadPart;
        ULONGLONG u0 = ((ULONGLONG)ut0.dwHighDateTime << 32) | ut0.dwLowDateTime, u1 = ((ULONGLONG)ut1.dwHighDateTime << 32) | ut1.dwLowDateTime;
        size_t out = 0; if (SUCCEEDED(hr) && code && *code) { typedef struct { void *vt; } B; /* ID3DBlob GetBufferSize is vtable slot 4 */
            SIZE_T (WINAPI *gs)(void*) = (SIZE_T (WINAPI*)(void*))((void**)(*(void***)(*code)))[4]; out = gs(*code); }
        char line[2048]; int k = sprintf_s(line, sizeof(line), "{\"id\":%ld,\"tid\":%lu,\"target\":\"%s\",\"entry\":\"%s\",\"flags1\":%u,\"flags2\":%u,\"bytes\":%zu,\"hr\":%ld,\"wall\":%.6f,\"thread_user\":%.6f,\"out\":%zu,\"defines\":[",
            id, GetCurrentThreadId(), target ? target : "", entry ? entry : "", flags1, flags2, (size_t)size, (long)hr, wall, (double)(u1 - u0) / 1e7, out);
        for (const MACRO *m = defines; m && m->Name && k < 1800; ++m) k += sprintf_s(line + k, sizeof(line) - k, "%s\"%s=%s\"", m == defines ? "" : ",", m->Name, m->Definition ? m->Definition : "");
        sprintf_s(line + k, sizeof(line) - k, "]}\n");
        char jl[MAX_PATH * 2]; sprintf_s(jl, sizeof(jl), "%s/calls.jsonl", dir);
        EnterCriticalSection(&lock); FILE *j; if (fopen_s(&j, jl, "ab") == 0) { fputs(line, j); fclose(j); } LeaveCriticalSection(&lock);
    }
    return hr;
}
__declspec(dllexport) HRESULT WINAPI D3DDisassemble(LPCVOID data, SIZE_T size, UINT flags, LPCSTR comments, void **out) {
    ensure(); return real_disasm(data, size, flags, comments, out);
}
