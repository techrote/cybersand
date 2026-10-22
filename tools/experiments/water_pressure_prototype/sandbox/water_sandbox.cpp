// Scratch-only liquid sandbox: Win32 + GDI window over the native World.
// Mouse:  Left drag water   Shift+Left oil   Right drag wall   Middle drag erase
// Scenes: 1 slab drop  2 dam break (D removes the dam)  3 rain cloud  4 U-tube
//         5 standing column  6 shallow basin mound  7 diving bell  8 sealed chamber
//         9 air cavity collapsing under a deep pool
//         R empty basin
// Keys:   B drop a floating box at the cursor (simple buoyancy; water pushes it)
//         Space pause   N single step   F 1/2/4 ticks per frame   +/- brush
//         V toggle overfill/velocity overlay (prototype builds)
//         S cycle presentation: seam fix (default) / seam fix + blur / raw
#define NOMINMAX
#include <windows.h>
#include "cybersand/world.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <memory>
#include <thread>
#include <vector>

using namespace cybersand;
#ifdef SANDBOX_TITLE_T
#define SANDBOX_STR2(x) #x
#define SANDBOX_STR(x) SANDBOX_STR2(x)
#undef SANDBOX_TITLE
#define SANDBOX_TITLE SANDBOX_STR(SANDBOX_TITLE_T)
#endif
#ifndef SANDBOX_TITLE
#define SANDBOX_TITLE "Water sandbox"
#endif
namespace {
constexpr int W = 384, H = 256, S = 3;
std::unique_ptr<World> world;
std::vector<std::uint32_t> pixels(W * H);
bool paused = false, overlay = false, step_once = false, smooth = true;
int smooth_mode = 1;  // 0 raw, 1 seam fix only, 2 seam fix + vertical blur
// Presentation-only smoothing (S): interior fill, previous-tick blend and a
// vertical [1 2 1] filter over water coverage. Simulation state is untouched.
std::vector<int> cover_now(W * H), cover_prev(W * H), cover_shown(W * H);
int brush = 4, steps = 1, scene_id = 1;
double tick_ms = 0;
std::uint64_t blocks = 0, total_mass = 0;

template <class Wd> std::uint64_t spare(const Wd& w, int x, int y) {
    if constexpr (requires { w.proto_spare_bits(x, y); }) return w.proto_spare_bits(x, y);
    else return 0;
}
template <class Wd> std::uint32_t hidden(const Wd& w, int x, int y) {
    if constexpr (requires { w.proto_hidden_mass(x, y); }) return w.proto_hidden_mass(x, y);
    else return 0;
}

struct Box {
    bool live = false;
    double x = 0, y = 0, vx = 0, vy = 0;
    static constexpr int size = 16;
} box;

void border() {
    for (int x = 0; x < W; ++x) { world->set(x, H - 1, Material::Wall); world->set(x, 0, Material::Wall); }
    for (int y = 0; y < H; ++y) { world->set(0, y, Material::Wall); world->set(W - 1, y, Material::Wall); }
}
void reset() {
    WorldConfig c{};
    world = std::make_unique<World>(c);
    world->reserve_region({-128, -128, W + 256, H + 256});
    world->configure_transient_obstacles({0, 0, W, H});
    border();
    box.live = false;
}
void fill(int x0, int y0, int x1, int y1, Material m) {
    for (int y = y0; y < y1; ++y) for (int x = x0; x < x1; ++x) world->set(x, y, m);
}
void scene(int n) {
    reset();
    scene_id = n;
    if (n == 1) { fill(1, H - 97, W - 1, H - 1, Material::Water); fill(120, 40, 200, 80, Material::Water); }
    if (n == 2) { fill(1, 60, 120, H - 1, Material::Water); fill(120, 60, 124, H - 1, Material::Wall); }
    if (n == 3) { fill(1, H - 40, W - 1, H - 1, Material::Water);
        for (int y = 4; y < 100; ++y) for (int x = 40; x < W - 40; ++x)
            if (((x * 7919 + y * 104729) % 100) < 35) world->set(x, y, Material::Water); }
    if (n == 4) { fill(180, 40, 200, H - 30, Material::Wall); fill(1, 40, 180, H - 1, Material::Water);
        fill(200, 200, W - 1, H - 1, Material::Water); fill(180, H - 30, 200, H - 1, Material::Water); }
    if (n == 5) fill(172, 20, 212, H - 1, Material::Water);
    if (n == 6) { fill(1, H - 13, W - 1, H - 1, Material::Water); fill(150, H - 73, 234, H - 13, Material::Water); }
    if (n == 7) { fill(1, 140, W - 1, H - 1, Material::Water); fill(220, 60, 300, 64, Material::Wall);
        fill(220, 64, 224, 210, Material::Wall); fill(296, 64, 300, 210, Material::Wall); fill(224, 64, 296, 200, Material::Empty); }
    if (n == 9) { fill(1, 80, W - 1, H - 1, Material::Water); fill(70, 180, 260, 250, Material::Empty);
        fill(140, 150, 190, 180, Material::Empty);
        for (int y = 140; y < 165; ++y) for (int x = 150; x < 190; ++x)
            if ((x - 170) * (x - 170) + (y - 162) * (y - 162) < 400) world->set(x, y, Material::Wall); }
    if (n == 8) { fill(1, 40, 200, H - 1, Material::Water); fill(200, 40, 204, H - 40, Material::Wall);
        fill(204, 100, W - 1, 104, Material::Wall); fill(200, H - 40, W - 1, H - 1, Material::Water); }
}
void paint(int cx, int cy, Material m) {
    for (int dy = -brush; dy <= brush; ++dy) for (int dx = -brush; dx <= brush; ++dx) {
        const int x = cx + dx, y = cy + dy;
        if (dx * dx + dy * dy > brush * brush || x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
        if (m == Material::Empty || world->stored_material(x, y) == Material::Empty || m == Material::Wall)
            world->set(x, y, m);
    }
}
bool in_box(int x, int y, int bx, int by) { return x >= bx && x < bx + Box::size && y >= by && y < by + Box::size; }

// Crude floating box (no Rapier here): half the density of Water, buoyancy
// from submerged rows beside it, plus the native contact impulses that Water
// transfers record against the body mask. Displaced Water is relocated above.
void update_box() {
    if (!box.live) return;
    const int bx0 = static_cast<int>(std::lround(box.x)), by0 = static_cast<int>(std::lround(box.y));
    int submerged = 0;
    for (int r = 0; r < Box::size; ++r) {
        const int y = by0 + r;
        submerged += world->stored_material(bx0 - 1, y) == Material::Water ||
                     world->stored_material(bx0 + Box::size, y) == Material::Water;
    }
    const double fx = static_cast<double>(world->transient_contact_impulse_x(1));
    box.vy += 0.05 - 0.1 * submerged / Box::size;
    box.vx += fx * 2e-6;
    box.vx *= 0.97; box.vy *= submerged ? 0.9 : 0.995;
    double nx = std::clamp(box.x + box.vx, 1.0, double(W - 1 - Box::size));
    double ny = std::clamp(box.y + box.vy, 1.0, double(H - 1 - Box::size));
    const int bx = static_cast<int>(std::lround(nx)), by = static_cast<int>(std::lround(ny));
    // Blocked by walls: keep the old position on that axis.
    auto blocked = [](int bx1, int by1) {
        for (int y = by1; y < by1 + Box::size; ++y) for (int x = bx1; x < bx1 + Box::size; ++x) {
            const auto m = world->stored_material(x, y);
            if (m != Material::Empty && m != Material::Water) return true;
        }
        return false;
    };
    int fx1 = bx, fy1 = by;
    if (blocked(fx1, by0)) { fx1 = bx0; box.vx = 0; }
    if (blocked(fx1, fy1)) { fy1 = by0; box.vy = 0; }
    box.x = fx1 == bx ? nx : bx0; box.y = fy1 == by ? ny : by0;
    world->clear_transient_obstacles();
    for (int y = fy1; y < fy1 + Box::size; ++y) for (int x = fx1; x < fx1 + Box::size; ++x) {
        if (world->stored_material(x, y) == Material::Water) {
            for (int up = fy1 - 1; up > 0; --up)
                if (world->stored_material(x, up) == Material::Empty) { (void)world->relocate_stored_cell(x, y, x, up); break; }
        }
        (void)world->set_transient_obstacle(x, y, 1);
    }
}

std::uint32_t rgb(int r, int g, int b) { return (r << 16) | (g << 8) | b; }
void sample_cover() {
    cover_prev.swap(cover_now);
    for (int y = 0; y < H; ++y) for (int x = 0; x < W; ++x) {
        int m = world->stored_material(x, y) == Material::Water ? std::min<int>(world->liquid_mass(x, y), 255) : 0;
        if (m > 0 && y > 0 && world->stored_material(x, y - 1) == Material::Water) m = 255;
        cover_now[y * W + x] = m;
    }
}
void render() {
    total_mass = 0;
    if (smooth) {
        std::vector<int> both(W * H);
        for (int i = 0; i < W * H; ++i)
            // Seam fix: interior cells (water above) count as full if full in
            // either of the last two ticks; surface cells show the current tick
            // unblurred in mode 1, so edges stay crisp.
            both[i] = cover_now[i] && cover_prev[i] && (cover_now[i] == 255 || cover_prev[i] == 255)
                ? 255 : smooth_mode < 2 ? cover_now[i] : (cover_now[i] + cover_prev[i]) / 2;
        for (int y = 0; y < H; ++y) for (int x = 0; x < W; ++x) {
            const int i = y * W + x;
            cover_shown[i] = smooth_mode < 2 || y == 0 || y == H - 1 ? both[i] : (both[i - W] + 2 * both[i] + both[i + W]) / 4;
        }
    }
    for (int y = 0; y < H; ++y) for (int x = 0; x < W; ++x) {
        const auto m = world->stored_material(x, y);
        std::uint32_t c = rgb(10, 12, 18);
        if (box.live && in_box(x, y, static_cast<int>(std::lround(box.x)), static_cast<int>(std::lround(box.y))))
            c = rgb(150, 100, 50);
        else if (smooth && !overlay && (m == Material::Water || m == Material::Empty)) {
            if (m == Material::Water) total_mass += std::min<int>(world->stored_state_a(x, y), 255) + hidden(*world, x, y);
            const int shown = cover_shown[y * W + x];
            if (shown > 24) {
                const int a = 60 + shown * 195 / 255;
                c = rgb(20 * a / 255 + 10, 110 * a / 255 + 12, 220 * a / 255 + 18);
            }
        } else if (m == Material::Water) {
            const int mass = std::min<int>(world->stored_state_a(x, y), 255);
            total_mass += mass + hidden(*world, x, y);
            const int a = 60 + mass * 195 / 255;
            c = rgb(20 * a / 255 + 10, 110 * a / 255 + 12, 220 * a / 255 + 18);
            if (overlay) {
                const auto bits = spare(*world, x, y);
                const int flow = static_cast<std::int8_t>((bits >> 40) & 255);
                const int over = static_cast<int>((bits >> 48) & 255);
                if (over) c = rgb(230, 120, 40);
                else if (flow > 0) c = rgb(40, std::min(255, 120 + flow * 4), 90);
                else if (flow < 0) c = rgb(std::min(255, 120 - flow * 4), 60, 160);
            }
        } else if (m == Material::Wall) c = rgb(82, 91, 106);
        else if (m == Material::Oil) c = rgb(110, 90, 60);
        else if (m != Material::Empty) c = rgb(200, 200, 200);
        pixels[y * W + x] = c;
    }
}
LRESULT CALLBACK proc(HWND h, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_DESTROY: PostQuitMessage(0); return 0;
    case WM_KEYDOWN:
        if (wp >= '1' && wp <= '9') scene(static_cast<int>(wp - '0'));
        if (wp == 'R') { reset(); scene_id = 0; }
        if (wp == 'D' && scene_id == 2) fill(120, 60, 124, H - 1, Material::Empty);
        if (wp == VK_SPACE) paused = !paused;
        if (wp == 'N') { paused = true; step_once = true; }
        if (wp == 'V') overlay = !overlay;
        if (wp == 'S') { smooth_mode = (smooth_mode + 1) % 3; smooth = smooth_mode != 0; }
        if (wp == 'F') steps = steps == 4 ? 1 : steps * 2;
        if (wp == 'B') {
            POINT p; GetCursorPos(&p); ScreenToClient(h, &p);
            box = {true, double(std::clamp(int(p.x / S) - Box::size / 2, 1, W - 1 - Box::size)),
                   double(std::clamp(int(p.y / S) - Box::size / 2, 1, H - 1 - Box::size)), 0, 0};
        }
        if (wp == VK_OEM_PLUS || wp == VK_ADD) brush = std::min(brush + 1, 30);
        if (wp == VK_OEM_MINUS || wp == VK_SUBTRACT) brush = std::max(brush - 1, 0);
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT ps; HDC dc = BeginPaint(h, &ps);
        BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
        bi.bmiHeader.biWidth = W; bi.bmiHeader.biHeight = -H; bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
        StretchDIBits(dc, 0, 0, W * S, H * S, 0, 0, W, H, pixels.data(), &bi, DIB_RGB_COLORS, SRCCOPY);
        EndPaint(h, &ps); return 0;
    }
    }
    return DefWindowProcA(h, msg, wp, lp);
}
}  // namespace

int WINAPI WinMain(HINSTANCE inst, HINSTANCE, LPSTR, int) {
    WNDCLASSA wc{}; wc.lpfnWndProc = proc; wc.hInstance = inst; wc.lpszClassName = "cs_sandbox";
    wc.hCursor = LoadCursor(nullptr, IDC_CROSS); RegisterClassA(&wc);
    RECT r{0, 0, W * S, H * S}; AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);
    HWND hwnd = CreateWindowA("cs_sandbox", SANDBOX_TITLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                              CW_USEDEFAULT, CW_USEDEFAULT, r.right - r.left, r.bottom - r.top,
                              nullptr, nullptr, inst, nullptr);
    scene(1);
    MSG msg{};
    auto last = std::chrono::steady_clock::now();
    for (;;) {
        while (PeekMessageA(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) return 0;
            TranslateMessage(&msg); DispatchMessageA(&msg);
        }
        POINT p; GetCursorPos(&p); ScreenToClient(hwnd, &p);
        const int cx = p.x / S, cy = p.y / S;
        if (GetForegroundWindow() == hwnd) {
            if (GetAsyncKeyState(VK_LBUTTON) & 0x8000)
                paint(cx, cy, (GetAsyncKeyState(VK_SHIFT) & 0x8000) ? Material::Oil : Material::Water);
            if (GetAsyncKeyState(VK_RBUTTON) & 0x8000) paint(cx, cy, Material::Wall);
            if (GetAsyncKeyState(VK_MBUTTON) & 0x8000) paint(cx, cy, Material::Empty);
        }
        if (!paused || step_once) {
            const auto t0 = std::chrono::steady_clock::now();
            for (int i = 0; i < (step_once ? 1 : steps); ++i) {
                update_box();
                blocks = world->tick().active_blocks_after;
            }
            sample_cover();
            tick_ms = tick_ms * 0.9 + 0.1 * std::chrono::duration<double, std::milli>(
                std::chrono::steady_clock::now() - t0).count() / (step_once ? 1 : steps);
            step_once = false;
        }
        render();
        InvalidateRect(hwnd, nullptr, FALSE); UpdateWindow(hwnd);
        char title[256];
        std::snprintf(title, sizeof title, "%s  |  %.2f ms/tick  |  %llu active blocks  |  mass %.1f cells  |  x%d %s%s",
                      SANDBOX_TITLE, tick_ms, static_cast<unsigned long long>(blocks), total_mass / 255.0, steps,
                      paused ? "[paused]" : "", overlay ? " [overlay]" : smooth_mode == 1 ? " [seam fix S]" : smooth_mode == 2 ? " [seam fix + blur S]" : " [raw S]");
        SetWindowTextA(hwnd, title);
        const auto next = last + std::chrono::milliseconds(16);
        std::this_thread::sleep_until(next);
        last = std::chrono::steady_clock::now();
    }
}
