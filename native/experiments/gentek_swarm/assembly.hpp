#pragma once

// SWARM-004 experimental, immutable structural grammar. No World/renderer API.
#include "swarm.hpp"
#include <atomic>

namespace cybersand::gentek_swarm::assembly004 {

enum class Owner : std::uint8_t { Frameweaver = 1, Mosaic = 2 };
enum class Obligation : std::uint8_t { Optional, LocalTerminable, ForeignRequired };
enum class Outcome : std::uint8_t { Complete, Invalid, Exhausted, Cancelled };
const char* name(Owner) noexcept;
const char* name(Obligation) noexcept;
const char* name(Outcome) noexcept;

struct Transform {
    Point translation{};
    unsigned quarter_turns{}; // exactly 0..3, never silently normalized
};
struct CellSpec {
    Point point{};
    Material material = Material::SteelPlate;
    Role role = Role::Structure;
};
struct SocketSpec {
    std::uint32_t id{};
    Point a{}, b{}, facing{};
    Family family = Family::Frame;
    Obligation obligation = Obligation::Optional;
};
struct PartSpec {
    std::uint32_t id{};
    std::string name, rule;
    std::vector<CellSpec> cells;
    std::vector<SocketSpec> sockets;
};
struct Symbol {
    std::uint32_t id{};
    bool assembly{};
};
struct ChildSpec {
    std::uint32_t slot{};
    Symbol symbol;
    Transform transform;
};
struct AttachmentSpec {
    std::uint32_t child_a{}, socket_a{}, child_b{}, socket_b{};
    bool required = true;
};
struct SocketExport {
    std::uint32_t id{}, child_slot{}, socket{};
};
struct AssemblySpec {
    std::uint32_t id{};
    std::string name, rule;
    std::vector<ChildSpec> children;
    std::vector<AttachmentSpec> attachments;
    std::vector<SocketExport> sockets;
};
struct Grammar {
    Owner owner = Owner::Frameweaver;
    std::string identity = "gentek_swarm_004_parts_v1";
    std::vector<PartSpec> parts;
    std::vector<AssemblySpec> assemblies;
};

struct Limits {
    std::uint32_t max_depth = 6, max_nodes = 64, max_instances = 64;
    std::uint32_t max_frontier = 256, max_candidates = 8192, max_proposals = 10;
    std::uint64_t max_work = 2'000'000;
    std::size_t max_bytes = 16 * 1024 * 1024;
};
// One caller-owned ledger across candidates/rounds. Work, candidates and bytes
// remain charged after rejected candidates. nodes/instances are live capacity:
// the coordinator may restore only these two counters after discarding a trial,
// or replacing its own uncommitted proposal, never after accepting additional
// geometry. bytes is conservative cumulative admission, not heap telemetry.
struct Budget {
    Limits limits;
    std::uint32_t nodes{}, instances{}, candidates{}, proposals{}, peak_frontier{};
    std::uint64_t work{};
    std::size_t bytes{};
    const std::atomic_bool* cancel = nullptr;
};
struct PlacedSocket {
    std::uint32_t id{}, instance{}, source_socket{};
    Point a{}, b{}, facing{};
    Family family = Family::Frame;
    Obligation obligation = Obligation::Optional;
};
struct PlacedPart {
    std::uint32_t instance{}, parent{}, spec{}, depth{};
    std::string name, rule;
    Transform transform;
    std::vector<PlacedSocket> sockets;
    std::uint32_t node{};
};
struct ExpandedNode {
    std::uint32_t id{}, parent{}, spec{}, depth{}, child_slot{};
    bool assembly{};
    std::string rule;
    Transform transform;
};
struct Claim {
    Point point{};
    Material material = Material::Empty;
    Role role = Role::Empty;
    Owner owner = Owner::Frameweaver;
    std::uint32_t instance{}, spec{}, round{}, revision{};
    std::string rule;
};
struct Joint {
    std::uint32_t instance_a{}, socket_a{}, instance_b{}, socket_b{};
    Family family = Family::Frame;
    std::vector<Point> cells;
};
struct Rejection {
    std::uint32_t symbol{}, child_slot{};
    std::string reason;
};
struct ExpandedAssembly {
    Outcome outcome = Outcome::Invalid;
    std::string reason;
    Owner owner = Owner::Frameweaver;
    std::uint32_t round{}, revision{};
    std::vector<ExpandedNode> nodes;
    std::vector<PlacedPart> instances;
    std::vector<Claim> claims; // exactly one canonical structural owner per cell
    std::vector<PlacedSocket> sockets; // explicit root exports only
    std::vector<Joint> joints;
    std::vector<Rejection> rejections;
    std::uint64_t digest{};
    std::uint64_t declared_cells{}, shared_joint_cells{};
};

// Any failure returns NO partial claims/instances/sockets/joints. Receipts and
// budget charges survive. Input vectors are never edited. Instance numbers are
// local to this expansion; the coordinator assigns composition IDs explicitly.
ExpandedAssembly expand(const Grammar&, Symbol root, Transform, std::uint32_t round,
                        std::uint32_t revision, Budget&);
// Proposal accounting belongs to the Gentek revision boundary, not each part
// candidate. Returns false without increment if cancelled or at the limit.
bool begin_proposal(Budget&) noexcept;
bool transform_point(Point local, Transform, Point& world) noexcept;
bool compose(Transform parent, Transform local, Transform& world) noexcept;

inline constexpr std::uint32_t cap = 1, plate = 2, member = 3, elbow = 4;
inline constexpr std::uint32_t termination_plate = 9;
inline constexpr std::uint32_t brace = 5, junction = 6, upright = 7, bracket_arm = 8;
inline constexpr std::uint32_t truss = 100, bracket = 101, nested_truss = 102;
inline constexpr std::uint32_t bearing_face = 10, bearing_seat = 11, bearing_diagonal = 12;
inline constexpr std::uint32_t backward_bearing = 103;
// Parameterized finite authored footprint family; span 1..24, rise 1..16.
// Invalid dimensions return an empty grammar, which expand rejects.
// member/truss/bracket/nested_truss export input1=(0,0), west, and
// output2=(span,0), east. Truss rises toward negative local y.
Grammar frame_grammar(unsigned span = 8, unsigned rise = 6, Family input_family = Family::Frame);
// Three-part receiving support behind an already adjacent foreign contact.
// Both exported sockets are at (0,0): input1 west/local-terminable with the
// requested Frame/Brace type, output2 east/Frame/foreign-required. No cell has
// x>0. handedness=-1 rises upward, +1 downward; no inferred mirror/normalization.
// Finite authored parameter range: span2..12, rise2..8. The default 2x2 shape
// overlaps a horizontal three-cell host only within Manhattan radius two.
Grammar bearing_grammar(unsigned span = 2, unsigned rise = 2,
                        Family input_family = Family::Frame, int handedness = -1);

} // namespace cybersand::gentek_swarm::assembly004
