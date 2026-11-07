// GEN-006 experimental native executable: bounded interest -> generator -> native World
// -> atomic single-shard checkpoint -> actual World destruction -> restore -> ticks.
// This is deliberately a sharded-World prototype, NOT a production selective
// eviction API for the one shared World. Adjacent-chunk transport is unsupported.
#include "cybersand/world.hpp"
#include "cybersand/world_generation.hpp"

#include <algorithm>
#include <array>
#include <bit>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <map>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>
#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <io.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

namespace {
using namespace cybersand;
namespace fs = std::filesystem;
constexpr std::int32_t kSide = 64;
constexpr std::size_t kMaskBytes = kSide * kSide / 8;
constexpr std::size_t kMaximumRecordBytes = 2'097'152;
constexpr std::uint64_t kSeed = UINT64_C(0x74A612FF3E91B07D);

void check(bool valid, const char* why) {
    if (!valid) throw std::runtime_error(why);
}
std::uint64_t checksum(std::span<const std::uint8_t> data) {
    std::uint64_t h = UINT64_C(14695981039346656037);
    for (const auto v : data) { h ^= v; h *= UINT64_C(1099511628211); }
    return h;
}
void put(std::vector<std::uint8_t>& output, std::uint64_t value, unsigned bytes) {
    for (unsigned i = 0; i < bytes; ++i) output.push_back(static_cast<std::uint8_t>(value >> (i * 8)));
}
std::uint64_t get(std::span<const std::uint8_t> input, std::size_t& p, unsigned bytes) {
    if (bytes > input.size() - std::min(p, input.size()))
        throw std::invalid_argument("GEN006_RECORD_TRUNCATED");
    std::uint64_t v = 0;
    for (unsigned i = 0; i < bytes; ++i) v |= static_cast<std::uint64_t>(input[p++]) << (i * 8);
    return v;
}
std::vector<std::uint8_t> read_record(const fs::path& file) {
    std::ifstream input(file, std::ios::binary | std::ios::ate);
    if (!input) throw std::runtime_error("GEN006_RECORD_UNREADABLE");
    const auto length = input.tellg();
    if (length < 0 || length > static_cast<std::streamoff>(kMaximumRecordBytes))
        throw std::invalid_argument("GEN006_RECORD_LENGTH");
    std::vector<std::uint8_t> bytes(static_cast<std::size_t>(length));
    input.seekg(0);
    input.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    if (!input) throw std::runtime_error("GEN006_RECORD_SHORT_READ");
    return bytes;
}

// Publication is serialized on the calling thread. Flush the file before its
// atomic same-directory replacement, then sync the POSIX parent directory.
// No claim of tested hardware power-loss durability or distributed filesystem safety.
void publish_file(const fs::path& destination, std::span<const std::uint8_t> bytes) {
    fs::create_directories(destination.parent_path());
    fs::path staging = destination;
    staging += ".staging";
#ifdef _WIN32
    std::FILE* f = nullptr;
    if (_wfopen_s(&f, staging.c_str(), L"wb") != 0) f = nullptr;
#else
    std::FILE* f = std::fopen(staging.c_str(), "wb");
#endif
    if (!f) throw std::runtime_error("GEN006_STAGE_OPEN_FAILED");
    bool ok = std::fwrite(bytes.data(), 1, bytes.size(), f) == bytes.size();
    if (ok) ok = std::fflush(f) == 0;
#ifdef _WIN32
    if (ok) ok = _commit(_fileno(f)) == 0;
#else
    if (ok) ok = ::fsync(::fileno(f)) == 0;
#endif
    if (std::fclose(f) != 0) ok = false;
    if (!ok) throw std::runtime_error("GEN006_STAGE_FLUSH_FAILED");
#ifdef _WIN32
    if (!MoveFileExW(staging.c_str(), destination.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        throw std::runtime_error("GEN006_PUBLISH_FAILED");
#else
    fs::rename(staging, destination);
    const int fd = ::open(destination.parent_path().c_str(), O_RDONLY | O_DIRECTORY);
    if (fd < 0) throw std::runtime_error("GEN006_DIRECTORY_OPEN_FAILED");
    const bool synced = ::fsync(fd) == 0;
    const bool closed = ::close(fd) == 0;
    if (!synced || !closed) throw std::runtime_error("GEN006_DIRECTORY_SYNC_FAILED");
#endif
}

struct Resident {
    std::unique_ptr<World> world;
    std::array<std::uint8_t, kMaskBytes> edit_intent{};
    std::uint64_t generation = 0;
    std::uint64_t use = 0;
    bool restored = false;
};

class StreamingSlice {
public:
    StreamingSlice(fs::path directory, std::size_t capacity, std::uint32_t workers)
        : directory_(std::move(directory)), capacity_(capacity), config_(make_config(workers)) {
        check(capacity_ >= 1 && capacity_ <= 4, "resident budget must be 1..4");
        generation::Recipe recipe;
        recipe.seed = kSeed;
        recipe.chunk_size = kSide;
        recipe.candidate = generation::Candidate::Strata;
        generator_ = generation::Generator::compile(std::move(recipe));
        fs::create_directories(directory_);
    }
    const WorldConfig& config() const { return config_; }
    std::size_t resident() const { return residents_.size(); }
    std::size_t bytes() const {
        std::size_t total = 0;
        for (const auto& [_, entry] : residents_) total += entry.world->resident_cell_bytes();
        return total;
    }
    bool contains(ChunkCoord c) const { return residents_.find(c) != residents_.end(); }
    bool saved(ChunkCoord c) const { return fs::exists(path_for(c)); }
    bool intent(ChunkCoord c, int x, int y) const {
        check(x >= 0 && y >= 0 && x < kSide && y < kSide, "invalid local cell");
        const auto& e = residents_.at(c);
        const auto index = static_cast<std::size_t>(y * kSide + x);
        return (e.edit_intent[index / 8] & (1U << (index % 8))) != 0;
    }
    World& focus(ChunkCoord c) {
        // Keep candidate staging distinct from resident ownership. A refused
        // restore leaves every resident and its newest unsaved edits untouched.
        if (c.x < -1'000'000 || c.x > 1'000'000 ||
            c.y < -1'000'000 || c.y > 1'000'000)
            throw std::invalid_argument("GEN006_DEMAND_COORDINATE_RANGE");
        const auto found = residents_.find(c);
        if (found != residents_.end()) {
            found->second.use = ++clock_;
            return *found->second.world;
        }
        Resident candidate = saved(c) ? restore(c) : generate(c);
        check(candidate.world && !candidate.world->has_failed() &&
              candidate.world->chunk_count() == 1, "GEN006_STAGE_UNSUPPORTED_WORLD");
        // Only one extra native World exists in bounded staging. The live map
        // never exceeds the resident budget; no selected chunk is regenerated.
        if (residents_.size() == capacity_) {
            const auto victim = std::min_element(residents_.begin(), residents_.end(),
                [](const auto& a, const auto& b) { return a.second.use < b.second.use; });
            check(victim != residents_.end(), "no eviction candidate");
            persist(victim->first, victim->second); // failure refuses eviction
            std::cout << "EVICT x=" << victim->first.x << " y=" << victim->first.y
                      << " generation=" << victim->second.generation << '\n';
            residents_.erase(victim); // ACTUAL destruction of native World
        }
        candidate.use = ++clock_;
        const bool reloaded = candidate.restored;
        auto [placed, inserted] = residents_.emplace(c, std::move(candidate));
        check(inserted, "duplicate resident");
        std::cout << (reloaded ? "RELOAD " : "GENERATE ") << "x=" << c.x
                  << " y=" << c.y << " resident=" << residents_.size() << '\n';
        return *placed->second.world;
    }
    void edit(ChunkCoord c, int x, int y, Material material,
              std::uint16_t amount = 0, std::int16_t temp = 200) {
        check(x >= 0 && y >= 0 && x < kSide && y < kSide, "invalid local edit");
        auto& world = focus(c);
        auto& e = residents_.at(c);
        const std::int64_t gx = c.x * kSide + x, gy = c.y * kSide + y;
        if (material == Material::Water) {
            check(world.set_cell_state(gx, gy, material, amount, 0),
                  "GEN006_WATER_STATE_REFUSED");
            world.set_temperature(gx, gy, temp);
        } else {
            world.set(gx, gy, material);
        }
        const std::size_t index = static_cast<std::size_t>(y * kSide + x);
        e.edit_intent[index / 8] |= static_cast<std::uint8_t>(1U << (index % 8));
        check(e.generation != std::numeric_limits<std::uint64_t>::max(),
              "GEN006_MUTATION_GENERATION_EXHAUSTED");
        ++e.generation; // even if content returns to a previous value
    }
    std::uint32_t simulate(unsigned ticks) {
        check(ticks <= 64, "GEN006_TICK_BUDGET");
        std::uint32_t maximum_observed = 0;
        for (unsigned t = 0; t < ticks; ++t) {
            for (auto& [_, e] : residents_) {
                check(!e.world->has_failed(), "GEN006_WORLD_QUARANTINED");
                const auto stats = e.world->tick();
                maximum_observed = std::max(maximum_observed, stats.worker_threads_observed);
                check(e.world->chunk_count() == 1 && !e.world->has_failed(),
                      "GEN006_CROSS_CHUNK_DOMAIN_PIN");
                check(e.generation != std::numeric_limits<std::uint64_t>::max(),
                      "GEN006_MUTATION_GENERATION_EXHAUSTED");
                ++e.generation; // conservative: simulator can mutate without a host edit
            }
        }
        return maximum_observed;
    }
    void save_all() {
        // Normal interactive quit/EOF must preserve currently loaded edits,
        // not merely those removed by capacity pressure.
        for (auto& [coordinate, entry] : residents_) persist(coordinate, entry);
    }
    const World& at(ChunkCoord c) const { return *residents_.at(c).world; }
    World& at(ChunkCoord c) { return *residents_.at(c).world; }
    std::uint64_t generation(ChunkCoord c) const { return residents_.at(c).generation; }
    void status() const {
        std::cout << "STATUS resident=" << resident() << "/" << capacity_
                  << " native_cell_bytes=" << bytes() << '\n';
        for (const auto& [c, e] : residents_)
            std::cout << "  chunk=(" << c.x << "," << c.y << ") gen="
                      << e.generation << " physical_hash="
                      << e.world->physical_state_hash() << " ticks="
                      << e.world->completed_tick_index() << '\n';
    }
    fs::path path_for(ChunkCoord c) const {
        return directory_ / ("chunk_x" + std::to_string(c.x) +
                             "_y" + std::to_string(c.y) + ".g6s");
    }
private:
    static WorldConfig make_config(std::uint32_t workers) {
        check(workers == 1 || workers == 4, "workers must be 1 or 4");
        WorldConfig c;
        c.chunk_size = kSide;
        c.activity_block_size = 16;
        c.scheduling_core_size = 64;
        c.initial_chunk_reserve = 1;
        c.maximum_chunk_count = 1;
        c.active_chunk_capacity = 16;
        c.active_core_capacity = 16;
        c.worker_threads = workers;
        c.parallel_job_threshold = 1;
        return c;
    }
    Resident generate(ChunkCoord c) {
        const auto proposal = generator_->generate(c);
        check(proposal.state == generation::ResultState::Ready &&
              generator_->accepts(proposal) && proposal.chunk == c &&
              proposal.chunk_size == kSide, "GEN006_PROPOSAL_REFUSED");
        Resident e;
        e.world = std::make_unique<World>(config_);
        check(e.world->install_generated_chunk(c, proposal.cells) ==
              ChunkInstallOutcome::Installed, "GEN006_NATIVE_ADMISSION_REFUSED");
        return e;
    }
    std::vector<std::uint8_t> encode(ChunkCoord c, const Resident& e) const {
        check(!e.world->has_failed() && e.world->chunk_count() == 1,
              "GEN006_UNSUPPORTED_SAVE_DOMAIN");
        const auto native = e.world->save_physical_state();
        check(!native.empty() && native.size() <= kMaximumRecordBytes - 1024,
              "GEN006_CHECKPOINT_BUDGET");
        std::vector<std::uint8_t> body(e.edit_intent.begin(), e.edit_intent.end());
        body.insert(body.end(), native.begin(), native.end());
        std::vector<std::uint8_t> record;
        for (char b : std::string("G6SLICE1")) record.push_back(static_cast<std::uint8_t>(b));
        put(record, 1, 4);
        put(record, static_cast<std::uint64_t>(c.x), 8);
        put(record, static_cast<std::uint64_t>(c.y), 8);
        put(record, generator_->fingerprint(), 8);
        put(record, kSeed, 8);
        put(record, e.generation, 8);
        put(record, static_cast<std::uint32_t>(kMaskBytes), 4);
        put(record, static_cast<std::uint32_t>(native.size()), 4);
        put(record, checksum(body), 8);
        record.insert(record.end(), body.begin(), body.end());
        check(record.size() <= kMaximumRecordBytes, "GEN006_RECORD_BUDGET");
        return record;
    }
    Resident restore(ChunkCoord c) const {
        const auto bytes = read_record(path_for(c));
        const std::span<const std::uint8_t> input(bytes);
        if (input.size() < 68 ||
            !std::equal(input.begin(), input.begin() + 8, std::string("G6SLICE1").begin()))
            throw std::invalid_argument("GEN006_RECORD_MAGIC");
        std::size_t cursor = 8;
        check(get(input, cursor, 4) == 1, "GEN006_RECORD_SCHEMA");
        const auto stored_x = std::bit_cast<std::int64_t>(get(input, cursor, 8));
        const auto stored_y = std::bit_cast<std::int64_t>(get(input, cursor, 8));
        check(stored_x == c.x && stored_y == c.y, "GEN006_RECORD_COORDINATE");
        check(get(input, cursor, 8) == generator_->fingerprint(),
              "GEN006_RECIPE_CHANGED_PIN");
        check(get(input, cursor, 8) == kSeed, "GEN006_REALM_CHANGED_PIN");
        Resident e;
        e.generation = get(input, cursor, 8);
        const auto mask_len = get(input, cursor, 4);
        const auto native_len = get(input, cursor, 4);
        const auto digest = get(input, cursor, 8);
        check(mask_len == kMaskBytes && native_len > 0 &&
              native_len <= kMaximumRecordBytes &&
              cursor <= input.size() &&
              mask_len + native_len == input.size() - cursor,
              "GEN006_RECORD_LENGTH");
        const auto body = input.subspan(cursor);
        check(checksum(body) == digest, "GEN006_RECORD_INTEGRITY");
        std::copy_n(body.begin(), kMaskBytes, e.edit_intent.begin());
        e.world = World::restore_physical_state(config_, body.subspan(kMaskBytes));
        check(e.world && !e.world->has_failed() && e.world->chunk_count() == 1 &&
              config_.maximum_chunk_count == 1,
              "GEN006_RESTORED_WORLD_REFUSED");
        // This prototype contains exactly one native World chunk per shard.
        // The outer record's coordinates are insufficient: a valid checkpoint
        // for A could be relabelled as B without changing its body checksum.
        // At single-chunk capacity the real native installer's preflight is
        // read-only: AlreadyResident means c is the chunk, CapacityFull means
        // the one resident chunk belongs elsewhere. Never use this temporary
        // probe as a general multi-chunk native residency API.
        const std::array<Material, kSide * kSide> empty_materials = [] {
            std::array<Material, kSide * kSide> materials{};
            materials.fill(Material::Empty);
            return materials;
        }();
        check(e.world->install_generated_chunk(c, empty_materials) ==
                  ChunkInstallOutcome::AlreadyResident,
              "GEN006_RESTORED_CHUNK_COORDINATE");
        e.restored = true;
        return e;
    }
    void persist(ChunkCoord c, Resident& e) {
        const auto record = encode(c, e);
        publish_file(path_for(c), record);
        // In this strictly synchronous owner prototype, the generation cannot
        // advance during publication. There is NO async-save ACK contract.
    }
    fs::path directory_;
    std::size_t capacity_;
    WorldConfig config_;
    std::shared_ptr<const generation::Generator> generator_;
    std::map<ChunkCoord, Resident> residents_;
    std::uint64_t clock_ = 0;
};

void self_test(const fs::path& path, std::uint32_t workers) {
    check(!fs::exists(path), "GEN006_SELF_TEST_REQUIRES_FRESH_DIRECTORY");
    StreamingSlice controller(path, 2, workers);
    const ChunkCoord a{-1, -3}, b{0, -3}, distant{24, -3};
    controller.focus(a);
    // Single-chunk walled basin; no unrepresented cross-boundary effects.
    for (int x = 12; x <= 24; ++x) controller.edit(a, x, 36, Material::Wall);
    for (int y = 29; y <= 36; ++y) {
        controller.edit(a, 12, y, Material::Wall);
        controller.edit(a, 24, y, Material::Wall);
    }
    controller.edit(a, 18, 30, Material::Water, 17, 417);
    controller.edit(a, 5, 5, Material::Empty); // explicit player air tombstone
    check(controller.intent(a, 5, 5), "Empty tombstone missing");
    check(controller.at(a).liquid_mass(-64 + 18, -192 + 30) == 17,
          "native Water17 setup failed");
    check(controller.at(a).stored_temperature(-64 + 18, -192 + 30) == 417,
          "native temperature417 setup failed");
    const auto first_observed = controller.simulate(4);
    const auto before_hash = controller.at(a).physical_state_hash();
    const auto water_before = controller.at(a).water_quantity({-64 + 12, -192 + 28, 13, 10});
    check(water_before == 17, "Water17 was duplicated or lost before save");
    const auto snapshot = controller.at(a).save_physical_state();
    auto uninterrupted = World::restore_physical_state(controller.config(), snapshot);
    check(uninterrupted->physical_state_hash() == before_hash,
          "native same-World checkpoint did not restore");
    controller.focus(b);
    controller.focus(distant); // x = 1536; forces genuine native World destruction
    check(controller.resident() == 2 && !controller.contains(a) &&
          controller.saved(a), "capacity miss did not actually evict and save");
    controller.focus(a); // restores from disk, not fresh generator
    check(controller.resident() == 2 && controller.intent(a, 5, 5) &&
          controller.at(a).physical_state_hash() == before_hash &&
          controller.at(a).water_quantity({-64 + 12, -192 + 28, 13, 10}) == water_before,
          "native selective shard reload changed authoritative state");
    std::uint32_t second_observed = 0;
    for (int t = 0; t < 3; ++t) {
        const auto observed = controller.at(a).tick();
        const auto reference = uninterrupted->tick();
        second_observed = std::max(second_observed, observed.worker_threads_observed);
        check(!controller.at(a).has_failed() &&
              controller.at(a).physical_state_hash() == uninterrupted->physical_state_hash(),
              "fixed-tick native continuation diverged");
        (void)reference;
    }
    // Corruption must fail closed before any LRU resident is destroyed.
    controller.focus(b);
    controller.focus(distant);
    check(!controller.contains(a), "corruption precondition: victim must be unloaded");
    auto packet = read_record(controller.path_for(a));
    check(packet.size() > 100, "checkpoint too short for corruption test");
    packet.back() ^= 0x40;
    // Fault injection intentionally replaces the record without pretending it
    // was a successful durable persistence transaction.
    {
        std::ofstream out(controller.path_for(a), std::ios::binary | std::ios::trunc);
        out.write(reinterpret_cast<const char*>(packet.data()),
                  static_cast<std::streamsize>(packet.size()));
        check(bool(out), "corruption injection failed");
    }
    const auto residents_before_refusal = controller.resident();
    bool refused = false;
    try { controller.focus(a); } catch (const std::exception&) { refused = true; }
    check(refused && controller.resident() == residents_before_refusal &&
          !controller.contains(a), "malformed saved record must preserve live owners");
    // Independent negative and positive coordinate-binding controls against
    // the actual native CYPS decoder and one-shard World. The same valid A
    // checkpoint cannot be laundered into B by relabelling its outer envelope.
    {
        StreamingSlice binding(path / "coordinate-binding", 1, workers);
        const ChunkCoord source{-1, -3}, target{0, -3}, other{1, -3};
        binding.focus(source);
        binding.edit(source, 18, 30, Material::Water, 17, 417);
        const auto source_hash = binding.at(source).physical_state_hash();
        binding.focus(target); // preserves and evicts source
        binding.focus(other); // preserves and evicts target
        check(binding.saved(source) && binding.saved(target) &&
              binding.contains(other), "coordinate fixture not resident");

        const auto valid_target = read_record(binding.path_for(target));
        auto relabelled = read_record(binding.path_for(source));
        check(relabelled.size() > 68, "coordinate fixture truncated");
        constexpr std::size_t coordinate_offset = 8 + 4; // magic, schema
        const auto requested_x = std::bit_cast<std::uint64_t>(target.x);
        for (unsigned byte = 0; byte < 8; ++byte)
            relabelled[coordinate_offset + byte] =
                static_cast<std::uint8_t>(requested_x >> (8 * byte));
        // Test-only record injection: native bytes/checksum are not modified.
        {
            std::ofstream out(binding.path_for(target),
                              std::ios::binary | std::ios::trunc);
            out.write(reinterpret_cast<const char*>(relabelled.data()),
                      static_cast<std::streamsize>(relabelled.size()));
            check(static_cast<bool>(out), "coordinate injection write failed");
        }
        const auto other_hash = binding.at(other).physical_state_hash();
        bool refused_coordinate = false;
        try { binding.focus(target); }
        catch (const std::exception& e) {
            refused_coordinate =
                std::string(e.what()) == "GEN006_RESTORED_CHUNK_COORDINATE";
        }
        check(refused_coordinate && binding.resident() == 1 &&
              binding.contains(other) && !binding.contains(target) &&
              binding.at(other).physical_state_hash() == other_hash,
              "relabelled native shard must refuse before resident eviction");

        // Restore original B record and check real positive reconstitution.
        {
            std::ofstream out(binding.path_for(target),
                              std::ios::binary | std::ios::trunc);
            out.write(reinterpret_cast<const char*>(valid_target.data()),
                      static_cast<std::streamsize>(valid_target.size()));
            check(static_cast<bool>(out), "valid record repair failed");
        }
        binding.focus(target);
        check(binding.contains(target) && binding.resident() == 1,
              "valid native target refused by coordinate guard");
        binding.focus(source);
        check(binding.contains(source) &&
              binding.at(source).physical_state_hash() == source_hash &&
              binding.at(source).liquid_mass(-64 + 18, -192 + 30) == 17,
              "source Water17 failed exact identity-backed native restore");
        std::cout << "GEN006_NATIVE_CHUNK_IDENTITY_PASS configured_workers="
                  << workers << " wrong_record=REFUSED live_owner=PRESERVED"
                  << " valid_target=RESTORED source_Water17=17\n";
    }
    std::cout << "GEN006_NATIVE_SHARDED_STREAM_PASS configured_workers=" << workers
              << " initial_observed=" << first_observed
              << " continuation_observed=" << second_observed
              << " resident_budget=2 far_pixel_x=1536 saved_Water=" << water_before
              << " continuing_ticks=3 corruption=REFUSED\n";
}

void interactive(const fs::path& path, std::uint32_t workers,
                 std::istream& commands) {
    StreamingSlice streamer(path, 2, workers);
    std::cout << "GEN006 experimental native stream (independent World per shard). "
                 "Commands: focus X Y | wall X Y | dig X Y | water X Y Q | "
                 "watertemp X Y Q T | "
                 "tick N | inspect LOCAL_X LOCAL_Y | render | status | quit. " 
                 "X/Y are world chunk coords for focus, "
                 "local 0..63 for edits. No cross-shard physics.\n";
    ChunkCoord active{-1,-3};
    streamer.focus(active);
    std::string command;
    while (commands >> command) {
        try {
            if (command == "quit") break;
            if (command == "focus") {
                commands >> active.x >> active.y;
                streamer.focus(active);
            } else if (command == "wall" || command == "dig" ||
                       command == "water" || command == "watertemp") {
                int x, y;
                commands >> x >> y;
                if (command == "water" || command == "watertemp") {
                    unsigned mass;
                    commands >> mass;
                    int temp = 200;
                    if (command == "watertemp") commands >> temp;
                    check(mass >= 1 && mass <= 31, "Water mass must be 1..31");
                    check(temp >= std::numeric_limits<std::int16_t>::min() &&
                          temp <= std::numeric_limits<std::int16_t>::max(),
                          "GEN006_WATER_TEMPERATURE_RANGE");
                    streamer.edit(active, x, y, Material::Water,
                                  static_cast<std::uint16_t>(mass),
                                  static_cast<std::int16_t>(temp));
                } else streamer.edit(active, x, y, command == "wall" ?
                                           Material::Wall : Material::Empty);
            } else if (command == "tick") {
                unsigned n;
                commands >> n;
                const auto observed = streamer.simulate(n);
                std::cout << "TICK configured=" << workers << " observed=" << observed << '\n';
            } else if (command == "inspect") {
                int x, y;
                commands >> x >> y;
                check(x >= 0 && x < kSide && y >= 0 && y < kSide,
                      "GEN006_INSPECT_LOCAL_COORDINATE");
                const std::int64_t gx = active.x * kSide + x;
                const std::int64_t gy = active.y * kSide + y;
                const auto& world = streamer.at(active);
                std::cout << "CELL chunk=(" << active.x << "," << active.y
                          << ") local=(" << x << "," << y << ")"
                          << " material=" << static_cast<int>(world.get(gx, gy))
                          << " liquid=" << world.liquid_mass(gx, gy)
                          << " temp=" << world.stored_temperature(gx, gy)
                          << " intent=" << int(streamer.intent(active, x, y))
                          << '\n';
            } else if (command == "render") {
                // Opt-in native RGBA byte handoff for the Godot demonstration.
                // Native World remains authoritative; no native/Godot object or
                // mutable storage crosses the process boundary. 64x64 only.
                const std::int64_t gx = active.x * kSide;
                const std::int64_t gy = active.y * kSide;
                std::array<std::uint8_t, kSide * kSide * 4> rgba{};
                streamer.at(active).copy_rgba(
                    RectI64{gx, gy, kSide, kSide}, rgba, kSide * 4);
                const fs::path image_file = path / "gen006-current.rgba";
                std::ofstream output(image_file,
                                     std::ios::binary | std::ios::trunc);
                check(bool(output), "GEN006_RENDER_OPEN_REFUSED");
                output.write(reinterpret_cast<const char*>(rgba.data()),
                             static_cast<std::streamsize>(rgba.size()));
                output.flush();
                check(bool(output), "GEN006_RENDER_WRITE_REFUSED");
                std::cout << "RENDER_RGBA chunk=(" << active.x << ","
                          << active.y << ") width=64 height=64"
                          << " bytes=" << rgba.size()
                          << " checksum=" << checksum(rgba)
                          << '\n';
            } else if (command == "status") {
                streamer.status();
            } else {
                std::cout << "UNKNOWN_COMMAND\n";
            }
            check(bool(commands), "GEN006_INPUT_ERROR");
        } catch (const std::exception& e) {
            std::cerr << "REFUSED " << e.what() << '\n';
            if (!commands) break;
        }
    }
    streamer.save_all();
    std::cout << "SAVE_ALL resident=" << streamer.resident() << '\n';
}

} // namespace

int main(int argc, char** argv) {
    try {
        const std::string mode(argv[1]);
        const bool batch = mode == "--batch";
        check(argc >= 3 && argc <= 5 &&
              ((batch && (argc == 4 || argc == 5)) ||
               (!batch && (argc == 3 || argc == 4))),
              "usage: slice --self-test|--interactive DIRECTORY [1|4] OR "
              "slice --batch DIRECTORY COMMAND_FILE [1|4]");
        const std::uint32_t workers = (batch ? argc == 5 : argc == 4) ?
            static_cast<std::uint32_t>(std::stoul(argv[batch ? 4 : 3])) : 1;
        if (mode == "--self-test") self_test(argv[2], workers);
        else if (mode == "--interactive") interactive(argv[2], workers, std::cin);
        else if (batch) {
            std::ifstream script(argv[3]);
            check(bool(script), "GEN006_BATCH_UNREADABLE");
            interactive(argv[2], workers, script);
            check(!script.bad(), "GEN006_BATCH_READ_ERROR");
        } else throw std::invalid_argument("GEN006_MODE");
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_NATIVE_SHARDED_STREAM_FAIL " << error.what() << '\n';
        return 1;
    }
}
