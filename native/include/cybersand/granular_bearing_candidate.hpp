#pragma once

// Diagnostic experiment GBD-2026-11-01. Ordinary admission does not call this ray.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <optional>
#include <string_view>

namespace cybersand::bearing_experiment {
enum class Mode { B0, Y1, A2 };
inline const char* name(Mode mode) noexcept {
    return mode == Mode::Y1 ? "Y1" : mode == Mode::A2 ? "A2" : "B0";
}
inline std::optional<Mode> parse(std::string_view value) noexcept {
    if (value == "B0") return Mode::B0;
    if (value == "Y1") return Mode::Y1;
    if (value == "A2") return Mode::A2;
    return std::nullopt;
}
inline double factor(Mode mode) noexcept { return mode == Mode::Y1 ? 1.0 : 0.18; }
inline double lookahead(double vy) noexcept {
    return std::clamp(std::max(vy, 0.0) * (1.0 / 60.0), 0.0, 2.0);
}

// Lower vertical intersection of the SAME rectangle at one raster column centre.
inline double lower_edge(double cx, double cy, double angle, double hx, double hy,
                         double column) noexcept {
    const double c = std::cos(angle), s = std::sin(angle);
    std::array<std::array<double,2>,4> corners{};
    constexpr std::array<std::array<int,2>,4> signs{{{-1,-1},{1,-1},{1,1},{-1,1}}};
    for (std::size_t i=0;i<4;++i) {
        const double x=signs[i][0]*hx, y=signs[i][1]*hy;
        corners[i]={cx+c*x-s*y,cy+s*x+c*y};
    }
    double lower=-std::numeric_limits<double>::infinity();
    for (std::size_t i=0;i<4;++i) {
        const auto a=corners[i], b=corners[(i+1)%4];
        if (b[0] == a[0]) {
            if (column == a[0]) lower=std::max({lower,a[1],b[1]});
            continue;
        }
        const double t=(column-a[0])/(b[0]-a[0]);
        if (t>=0.0 && t<=1.0) lower=std::max(lower,a[1]+t*(b[1]-a[1]));
    }
    return lower;
}
struct Cell {
    bool in_bounds=true, hard=false;
    std::uint16_t body=0;
    bool supported=false;
    std::uint8_t reason=1,stable_below=0,paused=0,fresh=0,unsupported=0,missing=0;
};
enum class Stop { Exhausted, Accepted, Bounds, Hard, Mask, InvalidGeometry };
struct Step { std::int32_t x=0,y=0; double distance=0; Cell cell{}; };
struct Ray {
    std::array<Step,3> steps{};
    std::uint32_t used=0;
    std::int32_t selected=-1;
    double lower=0, q=0, length=0;
    Stop stop=Stop::Exhausted;
};
template<class Read>
Ray admit(std::int32_t x, std::int32_t below_y, double lower, double length, Read&& read) {
    Ray ray;
    ray.lower=lower;
    if (!std::isfinite(lower) || !std::isfinite(length)) {
        ray.stop=Stop::InvalidGeometry;
        return ray;
    }
    ray.length=std::clamp(length,0.0,2.0);
    // Anchor to actual current mask; retain its continuous vertical raster phase.
    const double phase=lower+0.5-std::floor(lower+0.5);
    ray.q=static_cast<double>(below_y)+phase;
    for (std::int32_t index=0;index<3;++index) {
        const double distance=index == 0 ? 0.0 : static_cast<double>(below_y+index)-ray.q;
        if (distance>ray.length) break;
        const auto cell=read(x,below_y+index);
        ray.steps[ray.used++]={x,below_y+index,distance,cell};
        if (!cell.in_bounds) {ray.stop=Stop::Bounds; break;}
        if (cell.hard) {ray.stop=Stop::Hard; break;}
        if (cell.body!=0) {ray.stop=Stop::Mask; break;}
        if (cell.supported) {ray.selected=index;ray.stop=Stop::Accepted;break;}
    }
    return ray;
}
} // namespace cybersand::bearing_experiment
