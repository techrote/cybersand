#include "cybersand/world_generation.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <iostream>
#include <map>
#include <random>
#include <stdexcept>
#include <thread>

using namespace cybersand;
using namespace cybersand::generation;
namespace {
void check(bool v, const char *why) {
    if (!v)
        throw std::runtime_error(why);
}
SpatialNode node(const char *id, SpatialKind kind, std::vector<std::string> inputs = {}) {
    SpatialNode n;
    n.id = id;
    n.kind = kind;
    n.inputs = std::move(inputs);
    return n;
}
Recipe fixture() {
    Recipe r;
    r.schema = 2;
    r.seed = 190;
    r.chunk_size = 8;
    r.parameters.surface_y = 0;
    r.parameters.relief = 0;
    auto circle = node("distance", SpatialKind::CircleDistance);
    circle.parameters = {{"radius", 13}, {"x", -3}, {"y", 5}};
    auto gradient = node("gradient", SpatialKind::Gradient, {"distance"});
    auto mask = node("mask", SpatialKind::ToMask, {"distance"});
    mask.parameters = {{"low", -4}, {"high", 5}};
    auto n = node("noise", SpatialKind::Noise);
    n.sampling_scale = 16;
    auto category = node("district", SpatialKind::VoronoiRegion);
    category.parameters = {{"spacing", 16}, {"jitter", 0}};
    category.sampling_scale = 4;
    r.spatial.nodes = {circle, gradient, mask, n, category};
    Modifier m;
    m.id = "typed_carve";
    m.application = "spatial:mask";
    m.material = Material::Empty;
    r.modifiers = {m};
    HardOverride h;
    h.id = "final_override";
    h.bounds = {-8, -8, 4, 4};
    h.material = Material::Metal;
    r.overrides = {h};
    return r;
}
void partition_receipts() {
    const auto base = Generator::compile(fixture());
    const std::array<std::string, 4> channels{"spatial:distance", "spatial:gradient", "spatial:district",
                                              "spatial:noise"};
    for (const auto &channel : channels) {
        using Cell = std::pair<Material, SpatialValue>;
        std::map<std::pair<std::int64_t, std::int64_t>, Cell> reference;
        for (int size : {8, 16, 32}) {
            auto r = fixture();
            r.chunk_size = size;
            auto g = Generator::compile(r);
            std::vector<ChunkCoord> coords;
            for (int y = -32 / size; y < 32 / size; ++y)
                for (int x = -32 / size; x < 32 / size; ++x)
                    coords.push_back({x, y});
            if (size == 16)
                std::reverse(coords.begin(), coords.end());
            if (size == 32)
                std::shuffle(coords.begin(), coords.end(), std::mt19937(190));
            for (const auto c : coords) {
                auto job = g->begin(c, channel);
                check(job->state() == ResultState::Pending, "valid typed job admitted");
                const auto budget = size == 8 ? 1U : size == 16 ? 17U : 1024U;
                while (job->state() == ResultState::Pending)
                    (void)job->advance(budget);
                const auto &out = job->result();
                check(g->accepts(out), "typed receipt accepted");
                check(out.diagnostics.empty() && out.typed_diagnostics.size() == out.cells.size(),
                      "typed channel exclusive and complete");
                for (int y = 0; y < size; ++y)
                    for (int x = 0; x < size; ++x) {
                        auto wx = c.x * size + x, wy = c.y * size + y;
                        auto i = static_cast<std::size_t>(y * size + x);
                        Cell v{out.cells[i], out.typed_diagnostics[i]};
                        if (size == 8)
                            reference[{wx, wy}] = v;
                        else
                            check(reference.at({wx, wy}) == v,
                                  "chunk partition/budget/order changes values or materials");
                        check(v.second == g->spatial_graph().sample(channel.substr(8), wx, wy),
                              "chunk payload matches pure graph");
                        if (wx >= -8 && wx < -4 && wy >= -8 && wy < -4)
                            check(v.first == Material::Metal,
                                  "final material override remains authoritative");
                    }
                auto forged = out;
                forged.typed_diagnostics[0].x += 1;
                check(!g->accepts(forged), "typed payload forgery rejected");
                forged = out;
                ++forged.diagnostic_info.unit_power;
                check(!g->accepts(forged), "typed metadata forgery rejected");
            }
        }
        std::atomic<bool> okay = true;
        std::array<std::thread, 4> workers;
        for (std::size_t w = 0; w < workers.size(); ++w)
            workers[w] = std::thread([&, w] {
                for (std::size_t index = w; index < 64; index += workers.size()) {
                    const ChunkCoord c{-4 + static_cast<std::int64_t>(index % 8),
                                       -4 + static_cast<std::int64_t>(index / 8)};
                    auto out = base->generate(c, channel);
                    if (!base->accepts(out)) {
                        okay = false;
                        continue;
                    }
                    for (std::int64_t y = 0; y < 8; ++y)
                        for (std::int64_t x = 0; x < 8; ++x) {
                            const auto expected = reference.at({c.x * 8 + x, c.y * 8 + y});
                            const auto offset = static_cast<std::size_t>(y * 8 + x);
                            if (expected != Cell{out.cells[offset], out.typed_diagnostics[offset]})
                                okay = false;
                        }
                }
            });
        for (auto &worker : workers)
            worker.join();
        check(okay, "worker count changes typed packets");
    }
}
void failures() {
    auto r = fixture();
    auto g = Generator::compile(r);
    auto job = g->begin({0, 0}, "spatial:gradient");
    (void)job->advance(3);
    bool hidden = false;
    try {
        (void)job->result();
    } catch (const std::logic_error &) {
        hidden = true;
    }
    check(hidden, "partial job leaked");
    job->cancel();
    check(job->result().cells.empty() && job->result().typed_diagnostics.empty(),
          "cancel leaked partial typed payload");
    r.limits.max_operations_per_chunk = 1;
    auto low = Generator::compile(r)->begin({0, 0}, "spatial:distance");
    check(low->state() == ResultState::Failed && low->completed_cells() == 0 && low->result().cells.empty() &&
              low->result().typed_diagnostics.empty(),
          "budget request not refused before output allocation");
    r = fixture();
    r.modifiers[0].application = "spatial:distance";
    bool refused = false;
    try {
        (void)Generator::compile(r);
    } catch (const std::invalid_argument &) {
        refused = true;
    }
    check(refused, "signed distance silently accepted as mask");
    r = fixture();
    r.schema = 1;
    refused = false;
    try {
        (void)Generator::compile(r);
    } catch (const std::invalid_argument &) {
        refused = true;
    }
    check(refused, "typed fields admitted without schema migration");
    r = fixture();
    auto stretch = node("stretch", SpatialKind::Transform, {"distance"});
    stretch.parameters = {{"sx", 0.0001}, {"sy", 0.0001}};
    r.spatial.nodes.push_back(stretch);
    g = Generator::compile(r);
    auto fail = g->generate({(kCoordinateLimit / 8) - 1, 0}, "spatial:stretch");
    check(fail.state == ResultState::Failed && fail.cells.empty() && fail.typed_diagnostics.empty() &&
              fail.content_hash == 0 && fail.receipt_hash == 0,
          "out-of-domain transform exposed partial results");
    r = fixture();
    g = Generator::compile(r);
    auto edge = g->generate({-(kCoordinateLimit / 8), -1}, "spatial:gradient");
    check(g->accepts(edge), "valid world-limit derivative halo rejected");
}
void legacy_schema_identity() {
    Recipe a;
    a.chunk_size = 8;
    auto b = a;
    b.schema = 2;
    auto old = Generator::compile(a), current = Generator::compile(b);
    check(old->fingerprint() != current->fingerprint(), "schema migration needs distinct identity");
    for (auto coord : {ChunkCoord{-1, -1}, ChunkCoord{0, 0}, ChunkCoord{1, -2}})
        check(old->generate(coord).cells == current->generate(coord).cells,
              "schema migration without new fields changed materials");
}
} // namespace
int main() {
    try {
        partition_receipts();
        failures();
        legacy_schema_identity();
        std::cout
            << "PASS typed generator integration: complete rectangle partition/worker/budget parity, "
               "immutable diagnostics, mask conversion, final override, rejection and schema compatibility\n";
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "FAIL typed generator integration: " << e.what() << '\n';
        return 1;
    }
}
