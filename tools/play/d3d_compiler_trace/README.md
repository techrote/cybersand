# Windows D3DCompiler source capture — NONQUALIFYING

This helper observes the original compiler API while a separately labelled diagnostic process runs. It is not a runtime repair, a replacement renderer, a qualification apparatus, or an optimization setting. The real compiler receives the same shader bytes, entry point, profile, macros, include pointer, flags, secondary data, output pointers and call sequence. Its HRESULT, output blobs and LastError are returned unchanged. The exact System32 compiler is loaded by absolute path and checked against the build-time SHA-256; its bytes are never overwritten or copied under a new compiler name.

No Godot process or Windows compiler has been run from this local helper development lane. Native MSVC build and preflight must succeed on the actual hosted Windows machine before its measurements can be used. Eight parser/custody regressions pass both normally and with `python -O`. They use explicitly synthetic bytes in temporary directories, not shader evidence.

## Source-matched loader path

The retained Windows artifact `13015948557` logs `Godot Engine v4.7.stable.official.5b4e0cb0f` and `ANGLE 2.1.1 git hash: aaebda1c5a40`. Resolve that actual runtime identifier to ANGLE commit **aaebda1c5a40c15340d7a01a935a7c5398443272**. Godot's vendored `thirdparty/README.md` header-package pin and `install_angle.py` default package version are not substitutes for the version reported by the tested binary.

The primary-source chain is:

1. Godot commit **5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88**, [`platform/windows/detect.py`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/platform/windows/detect.py): the ANGLE build defines `ANGLE_ENABLED` and `EGL_STATIC` and links the static ANGLE/EGL/GLES libraries. This agrees with the original minidump module inventory, which contains no separate EGL/GLES/ANGLE DLL.
2. The same Godot commit, [`platform/windows/gl_manager_windows_angle.cpp`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/platform/windows/gl_manager_windows_angle.cpp): the manager selects `EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE` and an OpenGL ES 3 context.
3. Runtime-matched ANGLE commit, [`HLSLCompiler.cpp`](https://github.com/google/angle/blob/aaebda1c5a40c15340d7a01a935a7c5398443272/src/libANGLE/renderer/d3d/HLSLCompiler.cpp): `ensureInitialized` optionally checks build-configured preloaded compiler names, otherwise calls **`LoadLibraryA(D3DCOMPILER_DLL_A)`** and resolves **`D3DCompile`** and **`D3DDisassemble`**. This call has no `LOAD_LIBRARY_SEARCH_SYSTEM32` restriction. `compileToBinary` forwards the translated HLSL, fake source path, entry `main`, target profile, selected flags and optional macro array to the resolved function. Its internal retries happen only after a returned compiler failure; they do not explain an unfinished first compiler invocation.
4. Runtime-matched [`Renderer11.cpp`](https://github.com/google/angle/blob/aaebda1c5a40c15340d7a01a935a7c5398443272/src/libANGLE/renderer/d3d/d3d11/Renderer11.cpp#L3134-L3198): the ordinary starting configuration is optimization level 2, optionally IEEE strictness, with `ANGLE_ENABLE_LOOP_FLATTEN=1`. Capture the actual flags; do not assume debug-build conditionals or fallback flags were inactive solely from this source.
5. Runtime-matched [`OutputHLSL.cpp`](https://github.com/google/angle/blob/aaebda1c5a40c15340d7a01a935a7c5398443272/src/compiler/translator/hlsl/OutputHLSL.cpp): that macro defines `LOOP` as `[loop]` and `FLATTEN` as `[flatten]`. The translator emits them under its gradient/call-graph conditions. The identifier does not mean that every loop or conditional is flattened. Inspect the retained actual HLSL before attributing a particular expansion.

Microsoft documents the default [DLL search order](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order), and that modules with the same basename in different directories are distinct in [run-time dynamic linking](https://learn.microsoft.com/en-us/windows/win32/dlls/run-time-dynamic-linking). Process policy, preloaded modules, DLL redirection or build-specific ANGLE configuration can still make an adjacent proxy ineffective. The preflight and every actual engine trace must prove selection. No registry or process DLL-search policy is changed by this helper.

## Build, preflight and installation

Use a native **x64 MSVC developer environment** with Windows SDK, Python 3.12 and `ml64.exe`. Do not use a 32-bit Python process: `System32` redirection would select the wrong original.

```powershell
python <helper>/test_helpers.py
python -O <helper>/test_helpers.py
python <helper>/build_proxy.py --output <new-absolute-build-directory>
```

The output directory must be new. The script reads the native System32 DLL, preserves its complete actual export-name/ordinal mapping, and builds with `/W4 /WX`. Assembler, compiler and preflight-build subprocesses each have a 120-second bound. It records the System32 file before and after building and requires identical bytes. It parses the built proxy to verify that its exports exactly match the original. A non-function export, unsupported architecture, alias requiring review or changed original causes a visible failure.

Retain all outputs: `d3dcompiler_47.dll`, `proxy_preflight.exe`, `proxy.def`, `proxy_forward.asm`, `proxy_exports.h`, `system-compiler-before.json`, `build-receipt.json`, all original build logs, and the source helper files. The build receipt exposes `system_original.sha256`, `proxy.sha256`, original path/image size, complete export mappings, and source/build identities.

Create a fresh absolute preflight evidence directory. Set **`PACE003_D3D_TRACE_DIR`** to that directory and launch `proxy_preflight.exe` in a separate bounded process (30 seconds is sufficient as a diagnostic preflight limit; retain a failure/timeout). Its executable and proxy already share the build directory. It calls `LoadLibraryA("d3dcompiler_47.dll")`, matching ANGLE's basename request, and independently loads the absolute System32 compiler. It compares exact compiled bytecode/error blobs for `D3DCompile` and `D3DCompile2`, include/macro callbacks, and a failed compile. It exercises the generic x64 forwarding thunk through `D3DDisassemble`. Each check has its own honest boolean and overall exit status.

Then validate the original preflight trace:

```powershell
python <helper>/readback.py --directory <preflight-directory> `
  --manifest <build-directory>/build-receipt.json `
  --output <new-preflight-readback.json> --preflight
```

After both checks succeed, place the built proxy beside the **actual** extracted pinned `Godot_v4.7-stable_win64.exe` (the console launcher is adjacent in the retained package). Refuse to overwrite a pre-existing adjacent compiler DLL. Record the engine binaries' hashes before and after this installation and preserve the original compiler and proxy hashes. Do not install in System32, alter the engine executable or registry, or use the helper in a qualifying workload.

For each independently cold diagnostic variant, create its own fresh existing trace directory and set `PACE003_D3D_TRACE_DIR` only for that measured process. Strip it from headless import/version probes. Preserve the unchanged 180-second case timeout, source/runtime/cache receipts, original stdout/stderr, process captures and exit status. The helper changes no flags and performs no warm-up.

## Evidence, including timeouts

Initialization records actual original and proxy module paths, both SHA-256 values, mapped original base, actual resolved `D3DCompile`/`D3DCompile2` addresses (verified to belong to that System32 module), export count and capture bounds. If the actual original differs from the build-time SHA or cannot be forwarded faithfully, the helper fails visibly with process exit code `0xE0000309`.

Before every intercepted compiler call, it writes the **exact raw HLSL bytes** into `d3d-<pid>-<call>-source.hlsl` and synchronously records `compile_begin`, thread ID, entry, target, both flags, macros, include-pointer presence and secondary data metadata. A 180-second timeout can therefore retain a complete source and an open call. The call's eventual `compile_end`, if it occurs, records wall time from `QueryPerformanceCounter`, kernel/user thread CPU time from `GetThreadTimes`, HRESULT, exact returned bytecode/messages, and loss counters. Compiler timings exclude the initial source-dump/logging work; they include the small timestamp/LastError call overhead. The current-thread CPU counter does not include work delegated by the compiler to other threads. Windows thread accounting granularity also limits sub-millisecond CPU interpretation.

Run `readback.py` on each row even after a workload failure. It checks actual original/proxy identities, resolved-address ranges, export count, PID/call/file custody, complete HLSL/metadata, monotonic call times and instrumentation-loss counters. It hashes original dump bytes and retains incomplete call IDs with `completed=false`, null completion timing and null HRESULT. Successful readback means valid observed instrumentation, **never** a completed compile, frame, Main acknowledgement or graphical success. Keep the case's original nonzero/timeout result red.

An absent trace or absent intercepted compiler begin proves nothing about the shader. An open call carrying palette identifiers can connect an actively timed D3DCompile invocation to the actual palette input; pair it with the original process CPU/thread/minidump evidence. It still does not symbolize an internal Microsoft optimization pass. If another compiler API such as `D3DCompileFromFile` is observed through an uninstrumented forwarding export, readback refuses complete standalone source attribution. It also refuses nonpreflight include callbacks because their external bytes are not captured. ANGLE's source-matched path passes a null include pointer.

Capture is bounded to 256 compiler calls, 10,000 events, 32 MiB per binary/source file and 256 MiB aggregate dumped bytes per process. Reaching a bound is explicitly recorded/refused. Every actual API call continues to the original implementation even if capture reaches a bound. Other exports are dynamically forwarded, with their first use logged. No footer is assumed after process termination. Observation covers the selected API pointers only; it does not claim global process interception or that a separately preloaded original cannot bypass the proxy.

## What the next experiments can establish

The existing Windows baseline and seven-to-one structured-flair hoist both timed out at 180 seconds without an atlas frame; the captured hot instruction was in `d3dcompiler_47.dll`. This establishes compiler-dominated CPU activity but does not yet name the active shader. Linux independently established a palette program link and first-draw cost with paired GL calls. Do not equate the internal mechanisms across platforms.

Microsoft's [HLSL function syntax documentation](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-function-syntax) specifies inline function expansion at call sites. The palette still calls the large `material_colour` path for current content, conditional previous content and the outside-view fallback; the first correction also retains distinct structured/nonstructured flair call sites. Remaining expanded control-flow and procedural-building/flair costs are therefore reasonable **hypotheses**. They become causal evidence only when the original HLSL, pending/completed compiler call and bounded controlled exclusions or equivalent factoring line up.

Useful independent diagnostic comparisons are unchanged hoist, building exclusion, ordinary-flair exclusion, semantics-preserving shared flair/outside-view dispatch, and an equivalent bounded temporal loop with a single material-colour call site. Exclusions deliberately remove visuals and are nonqualifying. Equivalent candidates still need same-renderer exact raw/PNG atlas comparison and full actual Main cold qualification on each OS. Keep the same compiler flags, original workload/cache controls and every first failure. Do not disable optimization, change profile, substitute a renderer, extend 180 seconds or call a diagnostic image an acceptance result.
