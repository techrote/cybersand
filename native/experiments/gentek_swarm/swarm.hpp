#pragma once

// GENTEK-SWARM-001: unregistered, finite native research only.
// No World, ModuleRegistry, mutable chunks, Godot or production recipe access.
#include "cybersand/material.hpp"
#include <cstddef>
#include <cstdint>
#include <map>
#include <string>
#include <vector>

namespace cybersand::gentek_swarm {

struct Point {
    int x{}, y{};
    auto operator<=>(const Point&) const = default;
};
struct Rect { int x{}, y{}, w{}, h{}; };
enum class Kind { Frameweaver, Mosaic, Receptor };
enum class Role : std::uint8_t { Empty, Structure, Brace, Detail, Cohesion, Transition };
enum class Family : std::uint8_t { Frame, Brace, Surface, Passage };
enum class Status { Complete, Blocked, Exhausted, Unsat, Invalid, Damaged };

struct Profile {
    std::string name = "branching_irregular";
    double variation = 0.65, irregularity = 0.75, clutter = 0.25;
    double destruction = 0.0, branching = 0.8, environment_affinity = 0.7, cohesion = 0.15;
};
struct Limits {
    std::uint32_t max_instances = 64, max_frontier = 256, max_candidates = 8192;
    std::uint32_t max_connectors_per_instance = 8, max_affordances = 256;
    std::uint32_t max_cohesion_patches = 8, max_cohesion_cells_per_patch = 512;
    std::uint64_t max_work = 2'000'000, max_solver_work = 4'000'000;
    std::size_t max_bytes = 16 * 1024 * 1024;
};

// Boundary interchange deliberately omits each generator's internal representation.
struct Affordance {
    std::uint32_t id{}, instance{};
    Point a{}, b{}, facing{}; // a==b: point; otherwise finite segment
    Family family = Family::Frame;
    bool required = false;
    double strength = 1.0;
    std::string tag;
};
struct SoftAffordance {
    Point point{}, direction{};
    double strength = 1.0;
    std::string preference;
};
struct Boundary {
    std::vector<Affordance> hard;
    std::vector<SoftAffordance> soft;
    std::vector<std::uint8_t> protected_geometry, transition;
};
struct Request {
    Kind gentek = Kind::Frameweaver;
    std::uint32_t version = 0;
    std::string definition_fingerprint; // empty: use compiled definition
    std::string source_identity;
    std::string fixture = "free";
    std::uint64_t seed = 605;
    int width = 192, height = 112;
    Point origin{}; // explicit finite world origin; arrays use local coordinates
    std::vector<std::uint8_t> eligible, protected_void, transition;
    std::vector<Material> context, neighbor_cells;
    std::vector<Point> activation; // placement hint only; never a gesture grammar
    Boundary neighbors;
    Profile profile;
    Limits limits;
};
struct Instance {
    std::uint32_t id{};
    std::string kind;
    Point origin{};
    int orientation{}; // quarter turns, or implementation-documented direction
    bool structural = true, damaged = false;
    std::vector<Point> cells; // immutable planned footprint, retained after damage
    std::string reason;
};
struct Connector {
    std::uint32_t id{}, instance{};
    Family family = Family::Frame;
    Point a{}, b{}, facing{};
    bool required = false, fulfilled = false;
    std::uint32_t counterpart{}; // local connector ID; foreign joins have receipts
    std::string state = "open"; // open / joined / terminated / unresolved / lost
};
struct Attachment {
    std::uint32_t instance{};
    Point point{}, target{};
    std::string kind, reason;
};
struct Result {
    Kind gentek = Kind::Frameweaver;
    std::string implementation, definition_fingerprint, source_identity;
    std::uint64_t seed{}, request_digest{}, material_digest{}, digest{};
    int width{}, height{};
    Status status = Status::Complete;
    std::string termination = "complete";
    std::vector<Material> cells;
    std::vector<Role> roles;
    std::vector<std::uint32_t> provenance;
    std::vector<Instance> instances;
    std::vector<Connector> connectors;
    std::vector<Attachment> attachments;
    Boundary boundary;
    std::map<std::string, std::uint64_t> metrics;
    std::map<std::string, std::uint64_t> rejected;
    std::vector<std::string> notes;
    std::uint64_t work{}, candidates{}, solver_work{};
    std::int64_t backtracks = -1; // -1: donor API does not expose this metric
    std::uint32_t protected_violations{}, illegal_overlaps{}, unresolved_joints{};
};

const char* name(Kind) noexcept;
const char* name(Status) noexcept;
const char* name(Family) noexcept;
std::string definition(Kind);
std::uint64_t mix(std::uint64_t) noexcept;
double unit(std::uint64_t) noexcept;
std::string hex(std::uint64_t);
bool inside(const Request&, Point) noexcept;
std::size_t index(const Request&, Point) noexcept;
bool allowed(const Request&, Point) noexcept;
bool transition_at(const Request&, Point) noexcept;
bool validate_request(const Request&, std::string& reason);
Result begin_result(const Request&, const std::string& implementation);
bool charge(const Request&, Result&, std::uint64_t amount = 1);
bool candidate(const Request&, Result&);
bool write_cell(const Request&, Result&, Point, Material, Role, std::uint32_t instance,
                bool allow_same_material_join = false);
void finish_result(const Request&, Result&);
void apply_damage(const Request&, Result&); // independent post-assembly derivative
std::vector<Point> line(Point, Point); // bounded, 4-connected supercover staircase
Profile profile(const std::string&);

Result generate_frameweaver(const Request&);
Result generate_mosaic(const Request&);
Result generate_receptor(const Request&);
// One bounded transition-local addition pass; immutable foreign initial snapshot.
// Never remove/replace a frozen core cell or claim cohesion as a structural join.
void adapt_frameweaver(const Request&, Result&);
void adapt_mosaic(const Request&, Result&);
void adapt_receptor(const Request&, Result&);
Result generate(const Request&);

struct Fixture {
    std::string id;
    int width = 192, height = 112;
    std::vector<std::uint8_t> side, protected_void, transition;
    std::vector<Material> context;
    std::uint64_t digest{};
};
Fixture fixture(const std::string&);
std::vector<std::string> fixture_names();
Request request_for(const Fixture&, Kind, int side, const Profile&, std::uint64_t,
                    const std::string& source);
struct Seam {
    std::uint32_t left_affordance{}, right_affordance{};
    Point a{}, b{};
    bool joined = false;
    std::string reason;
    std::vector<Point> cells;
};
struct PairResult {
    Fixture fixture;
    Request left_request, right_request;
    Result left, right, initial_left, initial_right, clipped_left, clipped_right;
    std::vector<Material> cells, initial_cells, clipped_cells;
    std::vector<Seam> seams;
    std::uint64_t digest{}, work{};
    std::uint32_t conflicts{}, protected_violations{}, bridges{}, typed_contacts{}, bridge_cells{}, unresolved_seams{};
    std::string policy = "simultaneous-initial-snapshots; transition-local adaptation; canonical typed joint pass";
};
PairResult mesh(const Fixture&, Kind, Kind, const Profile&, std::uint64_t,
                const std::string& source, bool reverse_evaluation = false);
void write_result_json(const std::string&, const Request&, const Result&);
void write_pair_json(const std::string&, const PairResult&);

} // namespace cybersand::gentek_swarm
