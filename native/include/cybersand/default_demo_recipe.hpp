#pragma once

#include "cybersand/demo_snapshot.hpp"
#include <algorithm>
#include <cmath>
#include <string_view>

namespace cybersand::demo {

// Native-authored desktop bootstrap recipe. The legacy constructor and explicit
// prepared constructor consume this same ordered sequence. All work is finite
// construction work; the simulation kernel never invokes this visitor.
inline constexpr std::string_view kDefaultRecipeIdentity = "cybersand-desktop-default-demo-v1";

template<class Place>
inline void visit_default_demo_recipe(Place&& place) {
    for (std::int32_t x = 0; x < kWidth; ++x) {
        place(x, kHeight - 1, cybersand::Material::Wall);
    }
    for (std::int32_t y = 0; y < kHeight; ++y) {
        place(0, y, cybersand::Material::Wall);
        place(kWidth - 1, y, cybersand::Material::Wall);
    }
    for (std::int32_t x = 1; x < kWidth - 1; ++x) {
        auto floor_y = (kHeight - 79) +
                       static_cast<std::int32_t>(18.0 * std::sin(x * 0.018));
        floor_y += static_cast<std::int32_t>(7.0 * std::sin(x * 0.071));
        for (std::int32_t y = floor_y; y < kHeight - 1; ++y) {
            place(x, y, cybersand::Material::Wall);
        }
    }
    for (std::int32_t x = 18; x < 338; ++x) {
        place(x, 172, cybersand::Material::Wall);
    }
    for (std::int32_t y = 24; y < 112; ++y) {
        for (std::int32_t x = 55; x < 108; ++x) {
            if (((x * 17 + y * 31) % 7) < 4) place(x, y, cybersand::Material::Sand);
        }
    }
    for (std::int32_t y = 128; y < 172; ++y) {
        for (std::int32_t x = 216; x < 300; ++x) {
            if (((x + y) % 3) != 0) place(x, y, cybersand::Material::Water);
        }
    }
    for (std::int32_t platform = 0; platform < 5; ++platform) {
        const auto start_x = 360 + platform * 112;
        const auto platform_y = 128 + ((platform * 67) % 260);
        const auto end_x = std::min(kWidth - 18, start_x + 92);
        for (auto x = start_x; x < end_x; ++x) {
            place(x, platform_y, cybersand::Material::Wall);
        }
    }
    for (std::int32_t y = kHeight - 164; y < kHeight - 106; ++y) {
        for (std::int32_t x = 430; x < 492; ++x) {
            if (((x * 13 + y * 19) % 9) < 5) place(x, y, cybersand::Material::Smoke);
        }
    }
}

} // namespace cybersand::demo
