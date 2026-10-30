// Standalone NONQUALIFYING passthrough check; no Godot/graphics/device is created.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3dcompiler.h>
#include <cstdio>
#include <cstring>
#include <string>

template <typename T> T resolve(HMODULE module, const char *name) {
    FARPROC address = GetProcAddress(module, name);
    if (!address) { std::fprintf(stderr, "missing export %s\n", name); ExitProcess(2); }
    T result;
    static_assert(sizeof(result) == sizeof(address), "x64 function pointer size");
    std::memcpy(&result, &address, sizeof(result));
    return result;
}

bool equal_blob(ID3DBlob *left, ID3DBlob *right) {
    if (!left || !right) return left == right;
    return left->GetBufferSize() == right->GetBufferSize() &&
           std::memcmp(left->GetBufferPointer(), right->GetBufferPointer(), left->GetBufferSize()) == 0;
}

void release(ID3DBlob *&blob) { if (blob) { blob->Release(); blob = nullptr; } }

class Includes final : public ID3DInclude {
public:
    unsigned int opens = 0, closes = 0;
    HRESULT __stdcall Open(D3D_INCLUDE_TYPE, LPCSTR name, LPCVOID, LPCVOID *data, UINT *bytes) override {
        static const char contents[] = "static const float GREEN_CHANNEL = 0.5f;\n";
        if (std::strcmp(name, "preflight.inc") != 0 || !data || !bytes) return E_INVALIDARG;
        *data = contents; *bytes = static_cast<UINT>(sizeof(contents) - 1); ++opens;
        return S_OK;
    }
    HRESULT __stdcall Close(LPCVOID) override { ++closes; return S_OK; }
};

int wmain() {
    wchar_t traceDirectory[32768] = {};
    DWORD traceLength = GetEnvironmentVariableW(L"PACE003_D3D_TRACE_DIR", traceDirectory, 32768);
    if (!traceLength || traceLength >= 32768) { std::fprintf(stderr, "absolute PACE003_D3D_TRACE_DIR required\n"); return 2; }
    // This mimics ANGLE's actual basename loader, with the proxy adjacent to this executable.
    HMODULE proxy = LoadLibraryA("d3dcompiler_47.dll");
    if (!proxy) { std::fprintf(stderr, "basename loader failed\n"); return 2; }
    wchar_t system[MAX_PATH + 1] = {};
    UINT systemLength = GetSystemDirectoryW(system, MAX_PATH);
    if (!systemLength || systemLength >= MAX_PATH) return 2;
    std::wstring path = std::wstring(system) + L"\\d3dcompiler_47.dll";
    HMODULE original = LoadLibraryExW(path.c_str(), nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!original || original == proxy) { std::fprintf(stderr, "proxy was not selected independently of System32\n"); return 2; }
    wchar_t proxyName[32768] = {}, originalName[32768] = {};
    if (!GetModuleFileNameW(proxy, proxyName, 32768) || !GetModuleFileNameW(original, originalName, 32768)) return 2;
    if (CompareStringOrdinal(originalName, -1, path.c_str(), -1, TRUE) != CSTR_EQUAL) return 2;
    auto realCompile = resolve<decltype(&D3DCompile)>(original, "D3DCompile");
    auto tracedCompile = resolve<decltype(&D3DCompile)>(proxy, "D3DCompile");
    auto realCompile2 = resolve<decltype(&D3DCompile2)>(original, "D3DCompile2");
    auto tracedCompile2 = resolve<decltype(&D3DCompile2)>(proxy, "D3DCompile2");
    auto realDisassemble = resolve<decltype(&D3DDisassemble)>(original, "D3DDisassemble");
    auto tracedDisassemble = resolve<decltype(&D3DDisassemble)>(proxy, "D3DDisassemble");
    if (realCompile == tracedCompile || realCompile2 == tracedCompile2 || realDisassemble == tracedDisassemble) return 2;
    static const char shader[] = "#include \"preflight.inc\"\nfloat4 main(float4 position:SV_Position):SV_Target0 { return float4(RED_CHANNEL,GREEN_CHANNEL,position.x * 0.0f,1.0f); }\n";
    D3D_SHADER_MACRO macros[] = {{"RED_CHANNEL", "0.25f"}, {nullptr, nullptr}};
    constexpr UINT flags = D3DCOMPILE_OPTIMIZATION_LEVEL2 | D3DCOMPILE_IEEE_STRICTNESS;
    ID3DBlob *codeA = nullptr, *codeB = nullptr, *errorsA = nullptr, *errorsB = nullptr;
    bool compilationExact = true, lastErrorExact = true, includeCallbacks = true, disassemblyExact = true;
    unsigned int disassemblyChecks = 0;
    for (unsigned int api = 0; api < 2; ++api) {
        Includes includeA, includeB;
        HRESULT resultA, resultB;
        SetLastError(0x12345678u);
        if (api == 0)
            resultA = realCompile(shader, sizeof(shader) - 1, "pace003-proxy-preflight.hlsl", macros, &includeA,
                                  "main", "ps_5_0", flags, 0, &codeA, &errorsA);
        else
            resultA = realCompile2(shader, sizeof(shader) - 1, "pace003-proxy-preflight.hlsl", macros, &includeA,
                                   "main", "ps_5_0", flags, 0, 0, nullptr, 0, &codeA, &errorsA);
        DWORD errorA = GetLastError();
        SetLastError(0x12345678u);
        if (api == 0)
            resultB = tracedCompile(shader, sizeof(shader) - 1, "pace003-proxy-preflight.hlsl", macros, &includeB,
                                    "main", "ps_5_0", flags, 0, &codeB, &errorsB);
        else
            resultB = tracedCompile2(shader, sizeof(shader) - 1, "pace003-proxy-preflight.hlsl", macros, &includeB,
                                     "main", "ps_5_0", flags, 0, 0, nullptr, 0, &codeB, &errorsB);
        DWORD errorB = GetLastError();
        compilationExact = compilationExact && SUCCEEDED(resultA) && resultA == resultB && equal_blob(codeA, codeB) &&
                           equal_blob(errorsA, errorsB) && codeA && codeB;
        lastErrorExact = lastErrorExact && errorA == errorB;
        includeCallbacks = includeCallbacks && includeA.opens == 1 && includeA.closes == 1 &&
                           includeB.opens == 1 && includeB.closes == 1;
        if (codeA && codeB) {
            ID3DBlob *assemblyA = nullptr, *assemblyB = nullptr;
            HRESULT disA = realDisassemble(codeA->GetBufferPointer(), codeA->GetBufferSize(), 0, "passthrough", &assemblyA);
            HRESULT disB = tracedDisassemble(codeB->GetBufferPointer(), codeB->GetBufferSize(), 0, "passthrough", &assemblyB);
            ++disassemblyChecks;
            disassemblyExact = disassemblyExact && SUCCEEDED(disA) && disA == disB && equal_blob(assemblyA, assemblyB);
            release(assemblyA); release(assemblyB);
        }
        release(codeA); release(codeB); release(errorsA); release(errorsB);
    }
    static const char invalid[] = "not a valid HLSL shader";
    HRESULT failA = realCompile(invalid, sizeof(invalid) - 1, "pace003-invalid.hlsl", nullptr, nullptr,
                                "main", "ps_5_0", flags, 0, &codeA, &errorsA);
    HRESULT failB = tracedCompile(invalid, sizeof(invalid) - 1, "pace003-invalid.hlsl", nullptr, nullptr,
                                  "main", "ps_5_0", flags, 0, &codeB, &errorsB);
    bool failureExact = FAILED(failA) && failA == failB && equal_blob(codeA, codeB) && equal_blob(errorsA, errorsB) && errorsA && errorsB;
    release(codeA); release(codeB); release(errorsA); release(errorsB);
    disassemblyExact = disassemblyExact && disassemblyChecks == 2;
    bool ok = compilationExact && lastErrorExact && includeCallbacks && disassemblyExact && failureExact;
    std::printf("{\"scope\":\"NONQUALIFYING standalone proxy preflight\",\"passed\":%s,\"compile_and_compile2_byte_exact\":%s,\"last_error_exact\":%s,\"disassemble_forwarder_passed\":%s,\"source_include_callbacks_passed\":%s,\"failure_result_passed\":%s}\n",
                ok ? "true" : "false", compilationExact ? "true" : "false", lastErrorExact ? "true" : "false",
                disassemblyExact ? "true" : "false", includeCallbacks ? "true" : "false", failureExact ? "true" : "false");
    return ok ? 0 : 1;
}
