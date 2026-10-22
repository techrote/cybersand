#pragma once
// Scratch-only Water flow prototype parameters (environment tunable).
#include <cstdint>
#include <cstdlib>
namespace cybersand::proto {
struct Params {
    int mode;    // 0 HEAD, 3 pressure + overfill + velocity
    int g;       // pressure acceleration gain
    int hmin;    // minimum column run for depth-adaptive gain
    int decay;   // velocity retained per processed tick, /256
    int dead;    // velocity dead band
    int head_db; // head-difference dead band (mass units)
    int skin;    // HEAD 3/4 skin leveling: 0 off, 1 only free-surface cells, 2 always
    int cap;     // pressure walk cap (rows)
    int relief;  // 1: same-tick upward overfill relay
    int freefall;// 1: unsupported runs carry no pressure
    int reflect; // velocity kept (reversed) at solids, /8
    int lateral_epoch; // 1: lateral pushes into Water epoch-mark the receiver
    int dither_cell;   // 1: per-cell dither, 0: shared by 2^shift columns
    int dither_shift;
    int low_speed;
    int hole_full;
    int wide;
    int relief_min;
    int bed;
    int skin_frac;
    int settle_speed;
    int diffusion;
    int edge_db;
    int lump;
    int slow_drag;
    int head_db_depth;
    int snapshot_gradient;
    int air;
    int air_leak;
    int air_span;
    int air_min;
    int air_pressurized;
    int head_db_start;
    int skin_tolerance;
    int air_reference_passes;
    int air_state;
    int air_atm_rows;
    int air_max_cells;
    int air_quantum;
    int air_damping;
    int air_band;
    int air_wake;
    int over_hold;
    int box_full_height;
};
inline int env(const char* name, int fallback) {
    const char* v = std::getenv(name);
    return v ? std::atoi(v) : fallback;
}
inline const Params& params() {
    static const Params p{env("WMODE", 3), env("WG", 12), env("WHM", 4), env("WDEC", 252),
                          env("WDB", 1), env("WTH", 10), env("WSKIN", 1), env("WCAP", 255),
                          env("WREL", 1), env("WFF", 1), env("WRF", 0), env("WLEP", 0), env("WDC", 0), env("WDS", 6), env("WLOW", 0), env("WHF", 1), env("WWIDE", 1), env("WRMIN", 1), env("WBED", 64), env("WSKF", 3), env("WSET", 0), env("WDIF", 0), env("WEDB", 4), env("WLUMP", 1), env("WSLOW", 0), env("WTHD", 0), env("WPG", 0), env("WAIR", 1), env("WLEAK", 0), env("WASPAN", 512), env("WAMIN", 16), env("WAPR", 255), env("WTHS", 30), env("WSKT", 4), env("WAREF", 4), env("WASTATE", 1), env("WATM", 512), env("WAMAX", 24576), env("WAQ", 16), env("WAD", 0), env("WABAND", 0), env("WAWAKE", 1), env("WOHOLD", 0), env("WBOXV", 1)};
    return p;
}
// Mass-weighted velocity blend, rounded to nearest (ties away from zero) so
// small velocities survive dilution by slow incoming mass.
inline std::int32_t blend(std::int32_t fa, std::int32_t ma, std::int32_t fb, std::int32_t mb) {
    const std::int64_t total = static_cast<std::int64_t>(ma) + mb;
    if (total <= 0) return 0;
    const std::int64_t num = static_cast<std::int64_t>(fa) * ma + static_cast<std::int64_t>(fb) * mb;
    const auto q = (num >= 0 ? num + total / 2 : num - total / 2) / total;
    return static_cast<std::int32_t>(q);
}
}  // namespace cybersand::proto
