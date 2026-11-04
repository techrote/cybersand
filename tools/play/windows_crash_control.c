/* Diagnostic controls only. These are never linked into CyberSand or Godot. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static void fault(void) {
    ULONG_PTR information[2] = { 1, 1 };
    RaiseException(EXCEPTION_ACCESS_VIOLATION, 0, 2, information);
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) return 64;
    puts("CRASH_CONTROL_READY"); fflush(stdout);
    if (wcscmp(argv[1], L"normal") == 0) return 0;
    if (wcscmp(argv[1], L"handled") == 0) {
        __try { fault(); }
        __except (GetExceptionCode() == EXCEPTION_ACCESS_VIOLATION
                ? EXCEPTION_EXECUTE_HANDLER : EXCEPTION_CONTINUE_SEARCH) {
            puts("CRASH_CONTROL_HANDLED"); fflush(stdout);
        }
        return 0;
    }
    if (wcscmp(argv[1], L"crash") == 0) { fault(); return 65; }
    if (wcscmp(argv[1], L"hang") == 0) { Sleep(20000); return 66; }
    if (wcscmp(argv[1], L"child-crash") == 0) {
        wchar_t image[32768], command[32768];
        STARTUPINFOW startup = { 0 }; PROCESS_INFORMATION child = { 0 };
        DWORD code = 67;
        startup.cb = sizeof(startup);
        if (!GetModuleFileNameW(NULL, image, 32768)) return 68;
        if (swprintf_s(command, 32768, L"\"%s\" crash", image) < 0) return 69;
        if (!CreateProcessW(image, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &child)) return 70;
        WaitForSingleObject(child.hProcess, INFINITE);
        if (!GetExitCodeProcess(child.hProcess, &code)) code = 71;
        CloseHandle(child.hThread); CloseHandle(child.hProcess);
        return (int)code;
    }
    return 64;
}
