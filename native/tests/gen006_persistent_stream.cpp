// GEN-006 opt-in persistent native session. Real native World/Generator,
// one native World per shard: NOT shared-World selective chunk eviction.
// The Godot host communicates through a bounded atomic-file mailbox. The
// native owner never exposes mutable World memory and ticks independently.
#include <chrono>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>
#include <system_error>

#define main gen006_reference_cli_main
#include "gen006_streaming_slice.cpp"
#undef main

namespace {
using Clock = std::chrono::steady_clock;
using namespace std::chrono_literals;

void atomic_ephemeral(const fs::path& destination,
                      std::span<const std::uint8_t> bytes) {
    const fs::path temporary = destination.string() + ".writing";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        check(bool(output), "GEN006_SESSION_WRITE_OPEN");
        output.write(reinterpret_cast<const char*>(bytes.data()),
                     static_cast<std::streamsize>(bytes.size()));
        output.flush();
        check(bool(output), "GEN006_SESSION_WRITE_FAILED");
    }
#ifdef _WIN32
    check(MoveFileExW(temporary.c_str(), destination.c_str(),
                      MOVEFILE_REPLACE_EXISTING) != 0,
          "GEN006_SESSION_ATOMIC_RENAME");
#else
    fs::rename(temporary, destination);
#endif
}
void atomic_message(const fs::path& destination, const std::string& message) {
    const auto* p = reinterpret_cast<const std::uint8_t*>(message.data());
    atomic_ephemeral(destination, {p, message.size()});
}

// A cross-process, atomic single-writer lease. A stale lock after a crash is
// intentionally a fail-closed condition requiring manual owner verification.
class SaveLease {
public:
    explicit SaveLease(const fs::path& root) : path_(root / ".gen006_session_lock") {
        fs::create_directories(root);
        check(fs::create_directory(path_), "GEN006_SAVE_ROOT_ALREADY_OWNED");
    }
    ~SaveLease() {
        std::error_code ignored;
        fs::remove(path_, ignored);
    }
    SaveLease(const SaveLease&) = delete;
    SaveLease& operator=(const SaveLease&) = delete;
private:
    fs::path path_;
};

class NativeSession {
public:
    NativeSession(fs::path saves, fs::path control, std::uint32_t workers)
        : saves_(std::move(saves)), control_(std::move(control)),
          lease_(saves_), stream_(saves_, 2, workers), workers_(workers) {
        fs::create_directories(control_);
        check(!fs::exists(control_ / "state.txt") &&
              !fs::exists(control_ / "command.txt") &&
              !fs::exists(control_ / "ack.txt"),
              "GEN006_SESSION_CONTROL_NOT_FRESH");
        stream_.focus(active_);
    }

    void run() {
        publish_frame();
        std::cout << "GEN006_PERSISTENT_NATIVE_BEGIN"
                  << " configured_workers=" << workers_
                  << " tick_period_ms=100"
                  << " budget_worlds=2"
                  << " transport=atomic_mailbox" << std::endl;
        auto next_tick = Clock::now() + 100ms;
        auto next_save = Clock::now() + 2500ms;
        auto heartbeat_check = Clock::now() + 1500ms;
        const auto boot = Clock::now();
        while (running_) {
            if (fs::exists(control_ / "shutdown.txt")) {
                // The Godot owner can exit while a command is outstanding.
                // Save and release the lease without waiting for its receipt.
                std::cout << "GEN006_SESSION_CLIENT_SHUTDOWN" << std::endl;
                break;
            }
            const fs::path command_file = control_ / "command.txt";
            if (fs::exists(command_file)) {
                std::ifstream input(command_file, std::ios::binary);
                check(bool(input), "GEN006_SESSION_COMMAND_OPEN");
                std::string line;
                std::getline(input, line);
                check(!input.bad() && line.size() <= 256,
                      "GEN006_SESSION_COMMAND_LENGTH");
                input.close();
                fs::remove(command_file);
                handle(line);
            }
            const auto now = Clock::now();
            if (running_ && now >= next_tick) {
                if (!paused_) {
                    last_observed_ = stream_.simulate(1);
                    ++session_ticks_;
                    publish_frame();
                }
                // No runaway catch-up: one bounded simulation tick per
                // elapsed interval, even when the machine is overloaded.
                next_tick = Clock::now() + 100ms;
            }
            if (running_ && now >= next_save) {
                stream_.save_all();
                next_save = Clock::now() + 2500ms;
            }
            if (running_ && now >= heartbeat_check) {
                const fs::path heartbeat = control_ / "heartbeat.txt";
                const bool recent = fs::exists(heartbeat) &&
                    (fs::file_time_type::clock::now() -
                     fs::last_write_time(heartbeat)) < 12s;
                if (!recent && Clock::now() - boot > 12s) {
                    std::cout << "GEN006_SESSION_OWNER_HEARTBEAT_EXPIRED" << std::endl;
                    running_ = false;
                }
                heartbeat_check = Clock::now() + 1500ms;
            }
            if (running_) std::this_thread::sleep_for(15ms);
        }
        stream_.save_all();
        std::cout << "GEN006_PERSISTENT_NATIVE_STOP"
                  << " ticks=" << session_ticks_
                  << " frames=" << frame_sequence_
                  << " observed_workers=" << last_observed_ << std::endl;
    }
private:
    void publish_frame() {
        std::array<std::uint8_t, kSide * kSide * 4> rgba{};
        stream_.at(active_).copy_rgba(
            RectI64{active_.x * kSide, active_.y * kSide, kSide, kSide},
            rgba, kSide * 4);
        const std::uint64_t frame = ++frame_sequence_;
        const std::string name = "frame-" + std::to_string(frame) + ".rgba";
        atomic_ephemeral(control_ / name, rgba);
        std::ostringstream status;
        const auto& world = stream_.at(active_);
        status << "FRAME " << frame << " " << active_.x << " " << active_.y
               << " " << world.completed_tick_index()
               << " " << stream_.resident() << " " << last_observed_
               << " " << world.physical_state_hash() << " "
               << name << "\n";
        atomic_message(control_ / "state.txt", status.str());
        if (frame > 12) {
            std::error_code ignored;
            fs::remove(control_ / ("frame-" + std::to_string(frame - 12) + ".rgba"),
                       ignored);
        }
    }

    void handle(const std::string& line) {
        std::istringstream in(line);
        std::uint64_t id = 0;
        std::string command;
        in >> id >> command;
        check(bool(in) && id > last_command_ && command.size() <= 32,
              "GEN006_SESSION_COMMAND_SEQUENCE");
        last_command_ = id;
        std::string outcome = "OK";
        std::string reason = "accepted";
        bool publish = true;
        auto require_end = [&] {
            std::string trailing;
            check(!(in >> trailing), "GEN006_SESSION_COMMAND_TRAILING");
        };
        try {
            if (command == "FOCUS") {
                std::int64_t x = 0, y = 0;
                check(bool(in >> x >> y), "GEN006_SESSION_FOCUS_SYNTAX");
                check(x >= -1'000'000 && x <= 1'000'000 &&
                      y >= -1'000'000 && y <= 1'000'000,
                      "GEN006_DEMAND_COORDINATE_RANGE");
                require_end();
                const ChunkCoord target{x, y};
                stream_.focus(target);
                active_ = target;
            } else if (command == "WALL" || command == "DIG" ||
                       command == "WATER") {
                int x = 0, y = 0;
                check(bool(in >> x >> y), "GEN006_SESSION_EDIT_SYNTAX");
                check(x >= 0 && x < kSide && y >= 0 && y < kSide,
                      "GEN006_SESSION_EDIT_COORDINATE");
                if (command == "WATER") {
                    int mass = 0, temp = 200;
                    check(bool(in >> mass >> temp),
                          "GEN006_SESSION_WATER_SYNTAX");
                    check(mass >= 1 && mass <= 31 &&
                          temp >= -32768 && temp <= 32767,
                          "GEN006_SESSION_WATER_RANGE");
                    require_end();
                    stream_.edit(active_, x, y, Material::Water,
                                 static_cast<std::uint16_t>(mass),
                                 static_cast<std::int16_t>(temp));
                } else {
                    require_end();
                    stream_.edit(active_, x, y,
                                 command == "WALL" ? Material::Wall :
                                                     Material::Empty);
                }
            } else if (command == "PAUSE") {
                require_end();
                paused_ = true;
            } else if (command == "RESUME") {
                require_end();
                paused_ = false;
            } else if (command == "STEP") {
                unsigned n = 0;
                check(bool(in >> n) && n >= 1 && n <= 4,
                      "GEN006_SESSION_STEP_BUDGET");
                require_end();
                last_observed_ = stream_.simulate(n);
                session_ticks_ += n;
            } else if (command == "SAVE") {
                require_end();
                stream_.save_all();
            } else if (command == "STATUS") {
                require_end();
                // Force a native state readback without mutating the World.
            } else if (command == "QUIT") {
                require_end();
                stream_.save_all();
                running_ = false;
                publish = false;
            } else {
                throw std::runtime_error("GEN006_SESSION_COMMAND_UNKNOWN");
            }
            if (publish) publish_frame();
        } catch (const std::exception& error) {
            outcome = "ERR";
            reason = error.what();
            std::replace(reason.begin(), reason.end(), ' ', '_');
        }
        std::ostringstream ack;
        ack << "ACK " << id << " " << outcome << " " << reason << "\n";
        atomic_message(control_ / "ack.txt", ack.str());
        std::cout << "GEN006_PERSISTENT_NATIVE_ACK"
                  << " id=" << id << " command=" << command
                  << " outcome=" << outcome << " reason=" << reason
                  << " active=(" << active_.x << "," << active_.y << ")"
                  << std::endl;
    }
    fs::path saves_;
    fs::path control_;
    SaveLease lease_;
    StreamingSlice stream_;
    const std::uint32_t workers_;
    ChunkCoord active_{-1, -3};
    std::uint64_t frame_sequence_ = 0;
    std::uint64_t last_command_ = 0;
    std::uint64_t session_ticks_ = 0;
    std::uint32_t last_observed_ = 0;
    bool paused_ = false;
    bool running_ = true;
};
} // namespace

int main(int argc, char** argv) {
    try {
        check(argc == 4 || argc == 5,
              "usage: gen006-persistent --serve SAVE_ROOT CONTROL_ROOT [1|4]");
        check(std::string(argv[1]) == "--serve", "GEN006_SESSION_MODE");
        const std::uint32_t workers =
            argc == 5 ? static_cast<std::uint32_t>(std::stoul(argv[4])) : 1;
        check(workers == 1 || workers == 4, "GEN006_SESSION_WORKERS");
        NativeSession session(argv[2], argv[3], workers);
        session.run();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_PERSISTENT_NATIVE_FAIL " << error.what() << '\n';
        return 1;
    }
}
