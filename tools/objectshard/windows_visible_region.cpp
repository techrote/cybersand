// Diagnostic for one externally visible, source-specified Workbench region.
// Build with MSVC: cl /std:c++20 /EHsc windows_visible_region.cpp /link d3d11.lib dxgi.lib dwmapi.lib user32.lib
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dwmapi.h>
#include <dxgi1_2.h>
#include <wrl/client.h>
#include <algorithm>
#include <array>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;
namespace fs = std::filesystem;

void require(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
void check(HRESULT hr, const char* message) {
    if (FAILED(hr)) { std::cerr << std::hex << static_cast<unsigned long>(hr) << ' '; throw std::runtime_error(message); }
}

bool clear_region(HWND game, RECT rect) {
    if (!IsWindowVisible(game) || IsIconic(game)) return false;
    for (HWND above = GetTopWindow(nullptr); above != game; above = GetWindow(above, GW_HWNDNEXT)) {
        if (!above) return false;
        if (!IsWindowVisible(above) || IsIconic(above)) continue;
        DWORD cloaked{}; RECT frame{}, overlap{};
        if (SUCCEEDED(DwmGetWindowAttribute(above,DWMWA_CLOAKED,&cloaked,sizeof(cloaked))) && cloaked) continue;
        if (FAILED(DwmGetWindowAttribute(above,DWMWA_EXTENDED_FRAME_BOUNDS,&frame,sizeof(frame))))
            GetWindowRect(above,&frame);
        if (IntersectRect(&overlap,&frame,&rect)) return false;
    }
    CURSORINFO cursor{sizeof(CURSORINFO)};
    return GetCursorInfo(&cursor) && (!(cursor.flags & CURSOR_SHOWING) || !PtInRect(&rect,cursor.ptScreenPos));
}

int wmain(int argc, wchar_t** argv) try {
    require(argc == 9,"need HWND, PID, four client-pixel edges, evidence directory, timeout seconds");
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    HWND game = reinterpret_cast<HWND>(std::stoull(argv[1]));
    DWORD pid{}; GetWindowThreadProcessId(game,&pid);
    require(pid != 0 && pid == std::stoul(argv[2]),"game PID/HWND mismatch");
    RECT client{}, roi{std::stol(argv[3]),std::stol(argv[4]),std::stol(argv[5]),std::stol(argv[6])};
    GetClientRect(game,&client);
    require(roi.left>=0 && roi.top>=0 && roi.right<=client.right && roi.bottom<=client.bottom &&
            roi.right>roi.left && roi.bottom>roi.top,"outside game client");
    POINT origin{}; require(ClientToScreen(game,&origin),"cannot locate game client");
    OffsetRect(&roi,origin.x,origin.y);
    const auto monitor = MonitorFromWindow(game,MONITOR_DEFAULTTONULL);
    ComPtr<IDXGIFactory1> factory;
    check(CreateDXGIFactory1(IID_PPV_ARGS(&factory)),"DXGI factory");
    ComPtr<IDXGIAdapter1> adapter; ComPtr<IDXGIOutput1> output; DXGI_OUTPUT_DESC desc{};
    for (UINT i=0;!output && factory->EnumAdapters1(i,&adapter)!=DXGI_ERROR_NOT_FOUND;++i) {
        ComPtr<IDXGIOutput> current;
        for (UINT j=0;adapter->EnumOutputs(j,&current)!=DXGI_ERROR_NOT_FOUND;++j) {
            check(current->GetDesc(&desc),"output description");
            std::wcerr << desc.DeviceName << L" attached " << desc.AttachedToDesktop << L" rotation "
                << desc.Rotation << L" matches " << (desc.Monitor==monitor) << L'\n';
            if (desc.Monitor==monitor && desc.AttachedToDesktop) { check(current.As(&output),"output1"); break; }
            current.Reset();
        }
        if (!output) adapter.Reset();
    }
    require(output && adapter && desc.Rotation==DXGI_MODE_ROTATION_IDENTITY,"no unrotated attached game output");
    const RECT bounds=desc.DesktopCoordinates;
    require(roi.left>=bounds.left && roi.top>=bounds.top && roi.right<=bounds.right && roi.bottom<=bounds.bottom,"region crosses displays");
    ComPtr<ID3D11Device> device; ComPtr<ID3D11DeviceContext> context;
    check(D3D11CreateDevice(adapter.Get(),D3D_DRIVER_TYPE_UNKNOWN,nullptr,0,nullptr,0,D3D11_SDK_VERSION,
                            &device,nullptr,&context),"D3D11");
    ComPtr<IDXGIOutputDuplication> duplication;
    check(output->DuplicateOutput(device.Get(),&duplication),"desktop duplication");
    const UINT width=roi.right-roi.left,height=roi.bottom-roi.top;
    D3D11_TEXTURE2D_DESC stage{};
    stage.Width=width; stage.Height=height; stage.MipLevels=1; stage.ArraySize=1;
    stage.Format=DXGI_FORMAT_B8G8R8A8_UNORM; stage.SampleDesc.Count=1;
    stage.Usage=D3D11_USAGE_STAGING; stage.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
    ComPtr<ID3D11Texture2D> crop; check(device->CreateTexture2D(&stage,nullptr,&crop),"region staging");
    const D3D11_BOX box{UINT(roi.left-bounds.left),UINT(roi.top-bounds.top),0,
                        UINT(roi.right-bounds.left),UINT(roi.bottom-bounds.top),1};
    const fs::path dir=argv[7]; const auto limit=GetTickCount64()+1000*std::stoul(argv[8]);
    std::ofstream csv(dir/"visible.csv");
    LARGE_INTEGER frequency{}; QueryPerformanceFrequency(&frequency);
    csv << "phase,qpc,desktop_qpc,accumulated,changed_pixels,nonuniform_pixels\n";
    std::ofstream(dir/"ready.txt") << pid << ' ' << width << ' ' << height << ' ' << frequency.QuadPart;
    std::vector<std::uint32_t> previous(width*height);
    int old_phase=0; bool baseline=false;
    while (GetTickCount64()<limit) {
        int phase=0; std::ifstream(dir/"phase.txt") >> phase;
        if (phase==3) { std::ofstream(dir/"done.txt") << "complete"; return 0; }
        if (phase!=old_phase) { old_phase=phase; baseline=false; }
        DXGI_OUTDUPL_FRAME_INFO frame{}; ComPtr<IDXGIResource> resource;
        const auto hr=duplication->AcquireNextFrame(30,&frame,&resource);
        if (hr==DXGI_ERROR_WAIT_TIMEOUT) continue;
        check(hr,"acquire desktop");
        if (phase==1 || phase==2) {
            LARGE_INTEGER now{}; QueryPerformanceCounter(&now);
            POINT actual_origin{}; RECT actual_client{};
            const bool stable=ClientToScreen(game,&actual_origin) && GetClientRect(game,&actual_client)
                && actual_origin.x==origin.x && actual_origin.y==origin.y && EqualRect(&actual_client,&client);
            if (!stable || !clear_region(game,roi)) {
                csv << phase << ',' << now.QuadPart << ",0,0,-2,0\n";
                baseline=false;
            } else if (frame.LastPresentTime.QuadPart>0) {
                ComPtr<ID3D11Texture2D> desktop; check(resource.As(&desktop),"desktop texture");
                context->CopySubresourceRegion(crop.Get(),0,0,0,0,desktop.Get(),0,&box);
                D3D11_MAPPED_SUBRESOURCE mapped{}; check(context->Map(crop.Get(),0,D3D11_MAP_READ,0,&mapped),"read owned region");
                int changed=0,nonuniform=0;
                const auto first=*static_cast<const std::uint32_t*>(mapped.pData)&0x00ffffffU;
                for (UINT y=0;y<height;++y) {
                    const auto* row=reinterpret_cast<const std::uint32_t*>(static_cast<const char*>(mapped.pData)+y*mapped.RowPitch);
                    for (UINT x=0;x<width;++x) {
                        const auto color=row[x]&0x00ffffffU;
                        auto& prev=previous[y*width+x];
                        changed+=prev!=color; nonuniform+=color!=first; prev=color;
                    }
                }
                context->Unmap(crop.Get(),0);
                csv << phase << ',' << now.QuadPart << ',' << frame.LastPresentTime.QuadPart << ','
                    << frame.AccumulatedFrames << ',' << (baseline?changed:-1) << ',' << nonuniform << '\n';
                baseline=true;
            }
        }
        check(duplication->ReleaseFrame(),"release desktop");
    }
    throw std::runtime_error("measurement phase timeout");
} catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
