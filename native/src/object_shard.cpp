#include "cybersand/object_shard.hpp"
#include "cybersand/interaction_rules.hpp"

#include <algorithm>
#include <chrono>
#include <limits>
#include <new>
#include <stdexcept>

namespace cybersand::object_shard {
namespace {
constexpr std::uint64_t kHashOffset = 1469598103934665603ULL;
constexpr std::uint64_t kHashPrime = 1099511628211ULL;
constexpr std::uint64_t kNever = std::numeric_limits<std::uint64_t>::max();
constexpr std::uint32_t kNoShape = std::numeric_limits<std::uint32_t>::max();
void hash_value(std::uint64_t& hash, std::uint64_t value) noexcept {
    for (unsigned byte = 0; byte < 8; ++byte) {
        hash ^= value & 255U;
        hash *= kHashPrime;
        value >>= 8U;
    }
}
bool bit(std::span<const std::uint64_t> words, std::size_t index) noexcept {
    return index / 64U < words.size() && ((words[index / 64U] >> (index % 64U)) & 1U) != 0;
}
void set_bit(std::vector<std::uint64_t>& words, std::size_t index, bool value) noexcept {
    const auto mask = std::uint64_t{1} << (index % 64U);
    if (value) words[index / 64U] |= mask;
    else words[index / 64U] &= ~mask;
}
bool valid_limits(const Limits& limits) noexcept {
    return limits.max_shards != 0 && limits.max_shards <= kMaximumShards &&
        limits.max_area != 0 && limits.max_area <= kMaximumArea &&
        limits.max_total_area != 0 &&
        limits.max_total_area <= kMaximumShards * kMaximumArea &&
        limits.max_shapes != 0 && limits.max_shapes <= kMaximumShapes;
}
bool permitted(Payload payload, Role role) noexcept {
    switch (role) {
    case Role::Empty: return payload.material == Material::Empty;
    case Role::Structural: return structural_material_supported(payload.material);
    case Role::Product: return payload.material == Material::Fire || payload.material == Material::Smoke;
    case Role::Cargo: return payload.material == Material::Sand;
    }
    return false;
}
void adjust(Counts& counts, Role role, bool add) noexcept {
    auto* count = role == Role::Structural ? &counts.structural :
        role == Role::Product ? &counts.products : role == Role::Cargo ? &counts.cargo : nullptr;
    if (count != nullptr) {
        if (add) ++*count;
        else --*count;
    }
}
bool legal_advance(Phase expected, Phase next) noexcept {
    return (expected == Phase::CommittedInactive && next == Phase::TerrainInstalled) ||
        (expected == Phase::TerrainInstalled && next == Phase::MaskApplied) ||
        (expected == Phase::MaskApplied && next == Phase::ReadyToActivate) ||
        (expected == Phase::ReadyToActivate && next == Phase::Active) ||
        (expected == Phase::Active && next == Phase::Draining) ||
        (expected == Phase::Active && next == Phase::Suspended) ||
        (expected == Phase::Draining && next == Phase::Suspended) ||
        (expected == Phase::Suspended && next == Phase::Active) ||
        (expected == Phase::Suspended && next == Phase::Draining);
}
template <typename T>
std::size_t live(const std::vector<T>& values) noexcept { return values.size() * sizeof(T); }
template <typename T>
std::size_t retained(const std::vector<T>& values) noexcept { return values.capacity() * sizeof(T); }
} // namespace

bool valid_bounds(Bounds bounds) noexcept {
    return bounds.width != 0 && bounds.height != 0 &&
        bounds.x <= std::numeric_limits<std::int64_t>::max() - (bounds.width - 1) &&
        bounds.y <= std::numeric_limits<std::int64_t>::max() - (bounds.height - 1);
}

// A future catalogue update cannot quietly remove a reaction on a moving
// architecture cell. Admitting any reacting material needs its real lifecycle
// and pair/sidecar support, not simply another case in the palette whitelist.
static_assert([] {
    for (const auto material:{Material::Concrete,Material::GraniteBlock,
        Material::IndustrialBrick,Material::ReinforcedConcrete,Material::SteelPlate,
        Material::PaintedSteel,Material::CorrugatedSteel,Material::SteelGrating,
        Material::CeramicTile,Material::ChemicalGlass,Material::DarkGlass})
        if (material_definition(material).kernel!=RuleKernel::None ||
            InteractionRules::has_pair_rule(material)) return false;
    return true;
}(), "ObjectShard inert admission requires review of newly introduced material laws");

Payload Shard::payload(std::size_t index) const noexcept {
    if (index >= cells_.size()) return {Material::Empty, 0, 0, ambient_temperature_};
    const auto& cell = cells_[index];
    return {cell.material_value(), cell.state_a_value(), cell.state_b_value(),
        temperatures_.empty() ? ambient_temperature_ : temperatures_[index]};
}
Role Shard::role(std::size_t index) const noexcept {
    return index < roles_.size() ? roles_[index] : Role::Empty;
}
const CellSchedule& Shard::schedule(std::size_t index) const noexcept {
    static const CellSchedule invalid{0, kNever, 0};
    return index < schedule_.size() ? schedule_[index] : invalid;
}
bool Shard::occupied(std::size_t index) const noexcept { return bit(occupied_mask_, index); }
bool Shard::structural(std::size_t index) const noexcept { return bit(structural_mask_, index); }
bool Shard::surface(std::size_t index) const noexcept { return bit(surface_mask_, index); }

Outcome Shard::prepare(Handle handle, std::uint64_t world, Bounds bounds,
        std::uint64_t tick, const Limits& limits) {
    const auto area = bounds.area();
    const auto words = (area + 63U) / 64U;
    // Each vector is created at the exact admitted bounding-box size. Geometry
    // capacity is independent of area and never grows during an admitted tick.
    cells_ = std::vector<detail::PrecisionStorage>(area);
    roles_ = std::vector<Role>(area, Role::Empty);
    schedule_ = std::vector<CellSchedule>(area, CellSchedule{tick, kNever, 1});
    if (limits.temperature_storage)
        temperatures_ = std::vector<std::int16_t>(area, limits.ambient_temperature);
    occupied_mask_ = std::vector<std::uint64_t>(words);
    structural_mask_ = std::vector<std::uint64_t>(words);
    surface_mask_ = std::vector<std::uint64_t>(words);
    geometry_.shapes.reserve(limits.max_shapes);
    handle_ = handle;
    world_incarnation_ = world;
    captured_tick_ = tick;
    bounds_ = bounds;
    phase_ = Phase::Prepared;
    authoritative_ = false;
    geometry_dirty_ = true;
    geometry_dirty_tick_ = tick;
    material_revision_ = topology_revision_ = 1;
    applied_physics_revision_ = 0;
    ambient_temperature_ = limits.ambient_temperature;
    max_shapes_ = limits.max_shapes;
    counts_ = {};
    construction_allocations_ = limits.temperature_storage ? 8 : 7;
    peak_bytes_ = memory_usage().retained_bytes;
    return Outcome::Accepted;
}

void Shard::refresh_surface(std::size_t index) noexcept {
    if (index >= area()) return;
    const auto width = static_cast<std::size_t>(bounds_.width);
    const auto x = index % width;
    const auto y = index / width;
    const bool edge = x == 0 || y == 0 || x + 1 == width || y + 1 == bounds_.height;
    const bool boundary = structural(index) && (edge || !structural(index - 1) ||
        !structural(index + 1) || !structural(index - width) || !structural(index + width));
    set_bit(surface_mask_, index, boundary);
}
void Shard::refresh_neighbor_surfaces(std::size_t index) noexcept {
    const auto width = static_cast<std::size_t>(bounds_.width);
    refresh_surface(index);
    if (index % width != 0) refresh_surface(index - 1);
    if (index % width + 1 < width) refresh_surface(index + 1);
    if (index >= width) refresh_surface(index - width);
    if (index + width < area()) refresh_surface(index + width);
}

Outcome Shard::validate_cell_write(std::size_t index, Payload value, Role role_value,
        std::uint64_t tick, bool replace_identity) const noexcept {
    if (index >= area() || !permitted(value, role_value)) return Outcome::Unsupported;
    if (phase_ == Phase::Empty || phase_ == Phase::Retired) return Outcome::Retired;
    if (phase_ == Phase::Quarantined) return Outcome::Quarantined;
    if (phase_ != Phase::Prepared && !chemistry_allowed()) return Outcome::Fenced;
    if (tick < captured_tick_ || tick == kNever) return Outcome::Stale;
    if (temperatures_.empty() && value.temperature != ambient_temperature_) return Outcome::Unsupported;
    if (value.material == Material::Empty && (value.state_a != 0 || value.state_b != 0)) return Outcome::Invalid;
    const auto before = payload(index);
    const auto old_role = roles_[index];
    if (before == value && old_role == role_value && !replace_identity) return Outcome::Accepted;
    const bool new_identity = replace_identity || before.material != value.material || old_role != role_value;
    const bool topology_changed = (old_role == Role::Structural) != (role_value == Role::Structural);
    if (material_revision_ == kNever || (topology_changed && topology_revision_ == kNever) ||
        (new_identity && schedule_[index].incarnation == std::numeric_limits<std::uint32_t>::max()))
        return Outcome::GenerationExhausted;
    return Outcome::Accepted;
}

Outcome Shard::set_cell(std::size_t index, Payload value, Role role_value,
        std::uint64_t tick, bool replace_identity) noexcept {
    const auto admitted = validate_cell_write(index, value, role_value, tick, replace_identity);
    if (admitted != Outcome::Accepted) return admitted;
    const auto before = payload(index);
    const auto old_role = roles_[index];
    if (before == value && old_role == role_value && !replace_identity) return Outcome::Accepted;
    auto& scheduling = schedule_[index];
    const bool new_identity = replace_identity || before.material != value.material || old_role != role_value;
    const bool topology_changed = (old_role == Role::Structural) != (role_value == Role::Structural);
    const bool geometry_changed = topology_changed ||
        ((old_role == Role::Cargo) != (role_value == Role::Cargo));

    // No capacity acquisition or fallible operation follows the first write.
    auto& cell = cells_[index];
    cell.set_material(value.material);
    cell.set_state_a(value.state_a);
    cell.set_state_b(value.state_b);
    cell.set_epoch(0); // Traversal epoch is deliberately remapped.
    if (!temperatures_.empty()) temperatures_[index] = value.temperature;
    roles_[index] = role_value;
    adjust(counts_, old_role, false);
    adjust(counts_, role_value, true);
    set_bit(occupied_mask_, index, role_value != Role::Empty);
    set_bit(structural_mask_, index, role_value == Role::Structural);
    if (new_identity) {
        ++scheduling.incarnation;
        scheduling.birth_tick = tick;
    }
    scheduling.next_due_tick = role_value == Role::Empty ? kNever : tick + 1;
    ++material_revision_;
    if (topology_changed) {
        ++topology_revision_;
        refresh_neighbor_surfaces(index);
    }
    if (geometry_changed) {
        if (!geometry_dirty_) geometry_dirty_tick_ = tick;
        geometry_dirty_ = true;
    }
    // Inventory persists after rigid skeleton loss. Body retirement is a
    // separate main-thread operation; no RID lifetime owns these carriers.
    if (authoritative_ && phase_ == Phase::Active && counts_.structural == 0)
        phase_ = Phase::Draining;
    return Outcome::Accepted;
}

Outcome Shard::set_due(std::size_t index, std::uint64_t next_tick) noexcept {
    if (index >= area() || !occupied(index)) return Outcome::Invalid;
    if (phase_ != Phase::Prepared && !chemistry_allowed()) return Outcome::Fenced;
    if (next_tick <= schedule_[index].birth_tick) return Outcome::Stale;
    schedule_[index].next_due_tick = next_tick;
    return Outcome::Accepted;
}

std::uint64_t Shard::payload_digest() const noexcept {
    std::uint64_t hash = kHashOffset;
    hash_value(hash, static_cast<std::uint64_t>(bounds_.x));
    hash_value(hash, static_cast<std::uint64_t>(bounds_.y));
    hash_value(hash, bounds_.width); hash_value(hash, bounds_.height);
    for (std::size_t index = 0; index < area(); ++index) {
        const auto value = payload(index);
        hash_value(hash, static_cast<std::uint8_t>(value.material));
        hash_value(hash, value.state_a); hash_value(hash, value.state_b);
        hash_value(hash, static_cast<std::uint16_t>(value.temperature));
        hash_value(hash, static_cast<std::uint8_t>(roles_[index]));
        hash_value(hash, schedule_[index].incarnation);
        hash_value(hash, schedule_[index].birth_tick);
        hash_value(hash, schedule_[index].next_due_tick);
    }
    return hash;
}

GeometryScratch::GeometryScratch(const Limits& limits) {
    if (!valid_limits(limits)) throw std::invalid_argument("invalid ObjectShard limits");
    queue_.resize(limits.max_area);
    seen_.resize(limits.max_area);
    shapes_.reserve(limits.max_shapes);
}

Outcome Shard::build_shape_cover(GeometryScratch& scratch, std::size_t erased_cell,
        std::span<const std::uint8_t> excluded) const noexcept {
    if (area() > scratch.queue_.size() || area() > scratch.seen_.size()) return Outcome::Capacity;
    scratch.shapes_.clear();
    const auto width = static_cast<std::size_t>(bounds_.width);
    std::fill_n(scratch.queue_.begin(), width, kNoShape);
    const auto included = [&](std::size_t at) {
        return at != erased_cell && (excluded.empty() || excluded[at] == 0) && structural(at);
    };

    // Exact horizontal runs; merge only matching spans in the previous row.
    // queue_[x] temporarily holds that row's rectangle, making the cover linear
    // in bounding-box area rather than searching every earlier rectangle.
    for (std::size_t y = 0; y < bounds_.height; ++y) {
        for (std::size_t x = 0; x < width;) {
            if (!included(y * width + x)) { scratch.queue_[x++] = kNoShape; continue; }
            const auto first = x;
            const auto previous = scratch.queue_[x];
            do {
                scratch.queue_[x] = kNoShape;
                ++x;
            } while (x < width && included(y * width + x));
            const auto span = static_cast<std::uint16_t>(x - first);
            std::uint32_t chosen = previous;
            if (previous < scratch.shapes_.size() && scratch.shapes_[previous].x == first &&
                scratch.shapes_[previous].width == span &&
                static_cast<std::size_t>(scratch.shapes_[previous].y) + scratch.shapes_[previous].height == y) {
                ++scratch.shapes_[previous].height;
            } else {
                if (scratch.shapes_.size() == max_shapes_) {
                    return Outcome::Capacity;
                }
                chosen = static_cast<std::uint32_t>(scratch.shapes_.size());
                scratch.shapes_.push_back({static_cast<std::uint16_t>(first),
                    static_cast<std::uint16_t>(y), span, 1});
            }
            scratch.queue_[first] = chosen;
        }
    }
    return Outcome::Accepted;
}

Outcome Shard::rebuild_geometry(GeometryScratch& scratch, std::uint64_t tick,
        bool prepared_cover) noexcept {
    if (!geometry_dirty_) return Outcome::Accepted;
    if (geometry_.revision == kNever) return Outcome::GenerationExhausted;
    const auto cover = prepared_cover ? Outcome::Accepted : build_shape_cover(scratch,area());
    if (cover != Outcome::Accepted) {
        if (authoritative_ && cover == Outcome::Capacity) phase_ = Phase::Suspended;
        return cover;
    }
    const auto width = static_cast<std::size_t>(bounds_.width);

    std::fill_n(scratch.seen_.begin(), area(), std::uint8_t{0});
    std::uint32_t islands = 0;
    for (std::size_t start = 0; start < area(); ++start) {
        if (!structural(start) || scratch.seen_[start] != 0) continue;
        ++islands;
        std::size_t head = 0, tail = 1;
        scratch.queue_[0] = static_cast<std::uint32_t>(start);
        scratch.seen_[start] = 1;
        while (head < tail) {
            const auto index = static_cast<std::size_t>(scratch.queue_[head++]);
            const auto enqueue = [&](std::size_t neighbour) {
                if (structural(neighbour) && scratch.seen_[neighbour] == 0) {
                    scratch.seen_[neighbour] = 1;
                    scratch.queue_[tail++] = static_cast<std::uint32_t>(neighbour);
                }
            };
            if (index % width != 0) enqueue(index - 1);
            if (index % width + 1 < width) enqueue(index + 1);
            if (index >= width) enqueue(index - width);
            if (index + width < area()) enqueue(index + width);
        }
    }

    MassProperties mass{};
    for (std::size_t index = 0; index < area(); ++index) {
        if (roles_[index] != Role::Structural && roles_[index] != Role::Cargo) continue;
        mass.mass += 1.0;
        mass.com_x += static_cast<double>(index % width) + 0.5;
        mass.com_y += static_cast<double>(index / width) + 0.5;
    }
    if (mass.mass != 0.0) {
        mass.com_x /= mass.mass; mass.com_y /= mass.mass;
        for (std::size_t index = 0; index < area(); ++index) {
            if (roles_[index] != Role::Structural && roles_[index] != Role::Cargo) continue;
            const auto dx = static_cast<double>(index % width) + 0.5 - mass.com_x;
            const auto dy = static_cast<double>(index / width) + 0.5 - mass.com_y;
            mass.inertia += dx * dx + dy * dy + 1.0 / 6.0;
        }
    }
    std::uint64_t mask_hash = kHashOffset, shape_hash = kHashOffset;
    hash_value(mask_hash, bounds_.width); hash_value(mask_hash, bounds_.height);
    for (const auto word : structural_mask_) hash_value(mask_hash, word);
    for (const auto& rect : scratch.shapes_) {
        hash_value(shape_hash, rect.x); hash_value(shape_hash, rect.y);
        hash_value(shape_hash, rect.width); hash_value(shape_hash, rect.height);
    }
    hash_value(shape_hash, kPolicyVersion);
    hash_value(shape_hash, counts_.structural);
    hash_value(shape_hash, counts_.cargo);
    // Integer lattice carriers determine mass, COM and inertia exactly under
    // the declared unit-cell policy. Bind them without platform float encoding.
    for (std::size_t index = 0; index < area(); ++index) {
        if (roles_[index] != Role::Structural && roles_[index] != Role::Cargo) continue;
        hash_value(shape_hash, index);
        hash_value(shape_hash, static_cast<std::uint8_t>(roles_[index]));
    }
    // All potentially refusing work completed. Publish one coherent geometry.
    geometry_.shapes.assign(scratch.shapes_.begin(), scratch.shapes_.end());
    geometry_.mass = mass;
    geometry_.islands = islands;
    geometry_.split_pending = islands > 1;
    geometry_.mask_digest = mask_hash;
    geometry_.shape_digest = shape_hash;
    geometry_.material_revision = material_revision_;
    geometry_.topology_revision = topology_revision_;
    ++geometry_.revision;
    geometry_dirty_ = false;
    geometry_dirty_tick_ = tick;
    return Outcome::Accepted;
}

Outcome Shard::acknowledge_geometry(std::uint64_t revision, std::uint64_t mask,
        std::uint64_t shapes) noexcept {
    if (phase_ == Phase::Retired || phase_ == Phase::Empty) return Outcome::Retired;
    if (phase_ == Phase::Quarantined) return Outcome::Quarantined;
    if (geometry_dirty_ || revision != geometry_.revision || mask != geometry_.mask_digest ||
        shapes != geometry_.shape_digest || revision < applied_physics_revision_) return Outcome::Stale;
    applied_physics_revision_ = revision;
    return Outcome::Accepted;
}

MemoryUsage Shard::memory_usage() const noexcept {
    MemoryUsage result;
    result.live_bytes = sizeof(Shard) + live(cells_) + live(roles_) + live(schedule_) +
        live(temperatures_) + live(occupied_mask_) + live(structural_mask_) +
        live(surface_mask_) + live(geometry_.shapes);
    result.retained_bytes = sizeof(Shard) + retained(cells_) + retained(roles_) + retained(schedule_) +
        retained(temperatures_) + retained(occupied_mask_) + retained(structural_mask_) +
        retained(surface_mask_) + retained(geometry_.shapes);
    result.peak_bytes = std::max(peak_bytes_, result.retained_bytes);
    result.construction_allocations = construction_allocations_;
    return result;
}

void Shard::clear_inventory() noexcept {
    // Explicit retirement/reset boundary, never a chemistry operation. Release
    // the empty domain so retired slots cannot consume unreported bbox budget.
    std::vector<detail::PrecisionStorage>{}.swap(cells_);
    std::vector<Role>{}.swap(roles_);
    std::vector<CellSchedule>{}.swap(schedule_);
    std::vector<std::int16_t>{}.swap(temperatures_);
    std::vector<std::uint64_t>{}.swap(occupied_mask_);
    std::vector<std::uint64_t>{}.swap(structural_mask_);
    std::vector<std::uint64_t>{}.swap(surface_mask_);
    std::vector<Rect>{}.swap(geometry_.shapes);
    counts_ = {};
    authoritative_ = false;
    geometry_dirty_ = false;
}

Registry::Registry(Limits limits, std::uint64_t session, std::uint64_t world)
    : limits_(limits), session_(session), world_incarnation_(world), scratch_(limits) {
    if (!valid_limits(limits) || session == 0 || world == 0)
        throw std::invalid_argument("invalid ObjectShard registry identity or limits");
    shards_.resize(limits.max_shards);
    slot_generations_.resize(limits.max_shards);
    peak_retained_bytes_ = memory_usage().retained_bytes;
}
Shard* Registry::find(Handle handle) noexcept {
    if (handle.session != session_ || handle.id == 0 || handle.generation == 0) return nullptr;
    for (auto& shard : shards_)
        if (shard.handle_ == handle && shard.phase_ != Phase::Empty && shard.phase_ != Phase::Retired)
            return &shard;
    return nullptr;
}
const Shard* Registry::find(Handle handle) const noexcept {
    return const_cast<Registry*>(this)->find(handle);
}

Outcome Registry::prepare(Bounds bounds, std::uint64_t tick, Handle& result) {
    if (!valid_bounds(bounds) || tick == kNever) return Outcome::Invalid;
    if (bounds.area() > limits_.max_area) return Outcome::Capacity;
    std::size_t slot = shards_.size(), total_area = 0;
    for (std::size_t i = 0; i < shards_.size(); ++i) {
        if (shards_[i].phase_ == Phase::Empty || shards_[i].phase_ == Phase::Retired) {
            if (slot == shards_.size()) slot = i;
        } else total_area += shards_[i].area();
    }
    if (slot == shards_.size() || total_area + bounds.area() > limits_.max_total_area)
        return Outcome::Capacity;
    if (next_id_ == kNever || slot_generations_[slot] == kNever) return Outcome::GenerationExhausted;
    const Handle handle{session_, next_id_ + 1, slot_generations_[slot] + 1};
    // No retired inventory remains. Drop its retained carrier before acquiring
    // the replacement, so a reused slot does not temporarily double its area.
    shards_[slot] = Shard{};
    try {
        Shard candidate;
        const auto outcome = candidate.prepare(handle, world_incarnation_, bounds, tick, limits_);
        if (outcome != Outcome::Accepted) return outcome;
        shards_[slot] = std::move(candidate);
    } catch (const std::bad_alloc&) { return Outcome::Capacity; }
    ++next_id_;
    ++slot_generations_[slot];
    construction_allocations_ += shards_[slot].construction_allocations_;
    peak_retained_bytes_ = std::max(peak_retained_bytes_, memory_usage().retained_bytes);
    result = handle;
    return Outcome::Accepted;
}

Outcome Registry::finish_preparation(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != Phase::Prepared) return Outcome::Stale;
    if (shard->counts_.structural == 0 || shard->counts_.products != 0 || shard->counts_.cargo != 0)
        return Outcome::Unsupported;
    return shard->rebuild_geometry(scratch_, shard->captured_tick_);
}

Outcome Registry::prepare_fragment(Handle parent_handle, std::uint64_t tick, Handle& child_handle) {
    auto* parent=find(parent_handle);
    if (!parent) return Outcome::Stale;
    if (parent->phase_!=Phase::Active || !parent->authoritative_ || parent->geometry_dirty_ ||
        parent->applied_physics_revision_!=parent->geometry_.revision) return Outcome::Fenced;
    if (!parent->geometry_.split_pending || parent->geometry_.islands<2) return Outcome::Unsupported;
    // Fragment-only scratch is acquired at this explicit preparation boundary,
    // before any authority moves. Inactive/standalone laboratories retain
    // their historical bounded-memory envelope.
    if (scratch_.labels_.empty()) {
        try {scratch_.labels_.resize(limits_.max_area);++construction_allocations_;}
        catch (const std::bad_alloc&) {return Outcome::Capacity;}
    }
    const auto width=parent->bounds_.width, height=parent->bounds_.height;
    const auto area=parent->area();
    std::fill_n(scratch_.labels_.begin(),area,std::uint32_t{0});
    std::uint32_t largest_root=0, largest_count=0, child_root=0, child_count=0;
    const auto visit_neighbors=[&](std::uint32_t at,const auto& visit) {
        if (at%width) visit(at-1);
        if (at%width+1<width) visit(at+1);
        if (at>=width) visit(at-width);
        if (at+width<area) visit(at+width);
    };
    for (std::uint32_t start=0;start<area;++start) {
        if (!parent->structural(start) || scratch_.labels_[start]) continue;
        const auto root=start+1;
        std::size_t head=0,tail=1;scratch_.queue_[0]=start;scratch_.labels_[start]=root;
        while (head<tail) {
            const auto at=scratch_.queue_[head++];
            visit_neighbors(at,[&](std::uint32_t next) {
                if (parent->structural(next) && !scratch_.labels_[next]) {
                    scratch_.labels_[next]=root;scratch_.queue_[tail++]=next;
                }
            });
        }
        const auto count=static_cast<std::uint32_t>(tail);
        // Stable row-major ties keep the oldest/lower local island in parent.
        if (count>largest_count) {
            child_root=largest_root;child_count=largest_count;
            largest_root=root;largest_count=count;
        } else if (count>child_count) {child_root=root;child_count=count;}
    }
    if (!child_root || !child_count) return Outcome::Stale;
    // A bounded multi-source flood assigns every nonstructural carrier to its
    // nearest structural island. Row-major seed order resolves equal distance;
    // products and lodged Sand therefore travel with one exact owner.
    std::size_t head=0,tail=0;
    for (std::uint32_t at=0;at<area;++at)
        if (parent->structural(at)) scratch_.queue_[tail++]=at;
    while (head<tail) {
        const auto at=scratch_.queue_[head++];
        visit_neighbors(at,[&](std::uint32_t next) {
            if (!scratch_.labels_[next]) {
                scratch_.labels_[next]=scratch_.labels_[at];scratch_.queue_[tail++]=next;
            }
        });
    }
    std::uint32_t min_x=width,min_y=height,max_x=0,max_y=0;
    for (std::uint32_t at=0;at<area;++at) if (parent->occupied(at) && scratch_.labels_[at]==child_root) {
        min_x=std::min(min_x,at%width);max_x=std::max(max_x,at%width);
        min_y=std::min(min_y,at/width);max_y=std::max(max_y,at/width);
    }
    if (min_x) --min_x;
    if (min_y) --min_y;
    if (max_x+1<width) ++max_x;
    if (max_y+1<height) ++max_y;
    const Bounds bounds{parent->bounds_.x+min_x,parent->bounds_.y+min_y,
        static_cast<std::uint16_t>(max_x-min_x+1),static_cast<std::uint16_t>(max_y-min_y+1)};
    const auto prepared=prepare(bounds,tick,child_handle);
    if (prepared!=Outcome::Accepted) return prepared;
    auto* child=find(child_handle);
    for (std::uint32_t at=0;at<area;++at) if (parent->occupied(at) && scratch_.labels_[at]==child_root) {
        const auto local=(at/width-min_y)*bounds.width+at%width-min_x;
        const auto copied=child->set_cell(local,parent->payload(at),parent->role(at),tick);
        if (copied!=Outcome::Accepted) {(void)cancel_precommit(child_handle);return copied;}
        child->schedule_[local]=parent->schedule_[at];
    }
    const auto ready=child->rebuild_geometry(scratch_,tick);
    if (ready!=Outcome::Accepted) {(void)cancel_precommit(child_handle);return ready;}
    return Outcome::Accepted;
}

Outcome Registry::commit_fragment(Handle parent_handle, Handle child_handle, std::uint64_t tick) noexcept {
    auto* parent=find(parent_handle);auto* child=find(child_handle);
    if (!parent || !child || parent==child) return Outcome::Stale;
    if (parent->phase_!=Phase::Active || !parent->authoritative_ || parent->geometry_dirty_ ||
        parent->applied_physics_revision_!=parent->geometry_.revision ||
        child->phase_!=Phase::PhysicsReserved || child->authoritative_ || child->geometry_dirty_)
        return Outcome::Fenced;
    const auto dx=child->bounds_.x-parent->bounds_.x,dy=child->bounds_.y-parent->bounds_.y;
    if (dx<0 || dy<0 || dx+child->bounds_.width>parent->bounds_.width ||
        dy+child->bounds_.height>parent->bounds_.height || !child->counts_.structural ||
        child->counts_.structural>=parent->counts_.structural) return Outcome::Invalid;
    const auto count=child->counts_.total();
    if (parent->material_revision_>kNever-count || parent->topology_revision_>kNever-count ||
        parent->geometry_.revision==kNever) return Outcome::GenerationExhausted;
    const Payload empty{Material::Empty,0,0,limits_.ambient_temperature};
    std::fill_n(scratch_.seen_.begin(),parent->area(),std::uint8_t{0});
    const auto source_index=[&](std::size_t at) {
        return static_cast<std::size_t>(dy+at/child->bounds_.width)*parent->bounds_.width+
            static_cast<std::size_t>(dx)+at%child->bounds_.width;
    };
    for (std::size_t at=0;at<child->area();++at) if (child->occupied(at)) {
        const auto source=source_index(at);const auto& a=parent->schedule_[source];const auto& b=child->schedule_[at];
        if (parent->payload(source)!=child->payload(at) || parent->role(source)!=child->role(at) ||
            a.incarnation!=b.incarnation || a.birth_tick!=b.birth_tick || a.next_due_tick!=b.next_due_tick)
            return Outcome::Stale;
        const auto admitted=parent->validate_cell_write(source,empty,Role::Empty,tick);
        if (admitted!=Outcome::Accepted) return admitted;
        scratch_.seen_[source]=1;
    }
    const auto cover=parent->build_shape_cover(scratch_,parent->area(),
        std::span<const std::uint8_t>(scratch_.seen_.data(),parent->area()));
    if (cover!=Outcome::Accepted) return cover;
    // All capacities, counters and every source tuple are validated. This is
    // one exclusive native transaction; no World/Rapier callback can observe
    // its staging. Unexpected failures retain only actually debited inventory.
    if (commit(child_handle)!=Outcome::Accepted) return Outcome::Stale;
    std::size_t debited=0;
    for (std::size_t at=0;at<child->area();++at) if (child->occupied(at)) {
        if (parent->set_cell(source_index(at),empty,Role::Empty,tick)!=Outcome::Accepted) {
            (void)quarantine_partial_commit(child_handle,
                std::span<const std::uint32_t>(scratch_.queue_.data(),debited));
            parent->phase_=Phase::Quarantined;return Outcome::Quarantined;
        }
        scratch_.queue_[debited++]=static_cast<std::uint32_t>(at);
    }
    if (parent->rebuild_geometry(scratch_,tick)!=Outcome::Accepted) {
        parent->phase_=child->phase_=Phase::Quarantined;return Outcome::Quarantined;
    }
    return Outcome::Accepted;
}
Outcome Registry::erase_structural(Handle handle, std::size_t cell, std::uint64_t tick) noexcept {
    if (cell > std::numeric_limits<std::uint32_t>::max()) return Outcome::Unsupported;
    const auto index=static_cast<std::uint32_t>(cell);
    return erase_structural_batch(handle,std::span<const std::uint32_t>(&index,1),tick);
}
Outcome Registry::erase_structural_batch(Handle handle,
        std::span<const std::uint32_t> cells, std::uint64_t tick,StructuralEditTiming* timing) noexcept {
    using Clock=std::chrono::steady_clock;
    const auto elapsed=[](auto start) {return static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());};
    if (timing) *timing={};
    if (cells.size()>kMaximumEditCells) return Outcome::Capacity;
    auto* shard=find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_!=Phase::Active || !shard->authoritative_ || shard->geometry_dirty_ ||
        shard->applied_physics_revision_!=shard->geometry_.revision) return Outcome::Fenced;
    if (cells.empty()) return Outcome::Accepted;
    const Payload empty{Material::Empty,0,0,limits_.ambient_temperature};
    std::fill_n(scratch_.seen_.begin(),shard->area(),std::uint8_t{0});
    std::uint32_t unique=0;
    for (const auto cell:cells) {
        if (cell>=shard->area() || !shard->structural(cell)) return Outcome::Unsupported;
        if (scratch_.seen_[cell]) continue;
        const auto admitted=shard->validate_cell_write(cell,empty,Role::Empty,tick);
        if (admitted!=Outcome::Accepted) return admitted;
        scratch_.seen_[cell]=1;
        ++unique;
    }
    if (shard->material_revision_>kNever-unique || shard->topology_revision_>kNever-unique)
        return Outcome::GenerationExhausted;
    if (shard->geometry_.revision==kNever) return Outcome::GenerationExhausted;
    const auto cover_start=Clock::now();
    const auto cover=shard->build_shape_cover(scratch_,shard->area(),
        std::span<const std::uint8_t>(scratch_.seen_.data(),shard->area()));
    if (timing) timing->geometry_ns=elapsed(cover_start);
    if (cover!=Outcome::Accepted) return cover;
    // All geometry/storage capacities are reserved and the coordinator is the
    // exclusive owner. No writer or physics step can interleave this commit.
    const auto mutation_start=Clock::now();
    for (const auto cell:cells) {
        if (!scratch_.seen_[cell]) continue;
        scratch_.seen_[cell]=0;
        if (shard->set_cell(cell,empty,Role::Empty,tick)!=Outcome::Accepted) {
            if (timing) timing->mutation_ns=elapsed(mutation_start);
            shard->phase_=Phase::Quarantined;
            return Outcome::Quarantined;
        }
    }
    if (timing) timing->mutation_ns=elapsed(mutation_start);
    // The exact cover was reserved and computed before the first debit. Cell
    // writes do not use geometry scratch; reuse it for one coherent rebuild.
    const auto geometry_start=Clock::now();
    const auto rebuilt=shard->rebuild_geometry(scratch_,tick,true);
    if (timing) timing->geometry_ns+=elapsed(geometry_start);
    if (rebuilt!=Outcome::Accepted) {
        shard->phase_=Phase::Quarantined;
        return Outcome::Quarantined;
    }
    return Outcome::Accepted;
}
Outcome Registry::reserve_physics(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != Phase::Prepared || shard->geometry_dirty_ ||
        shard->geometry_.revision == 0 || shard->geometry_.shapes.empty()) return Outcome::Stale;
    shard->phase_ = Phase::PhysicsReserved;
    return Outcome::Accepted;
}
Outcome Registry::commit(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != Phase::PhysicsReserved) return Outcome::Stale;
    shard->authoritative_ = true;
    shard->phase_ = Phase::CommittedInactive;
    return Outcome::Accepted;
}
Outcome Registry::advance(Handle handle, Phase expected, Phase next) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != expected || !legal_advance(expected, next)) return Outcome::Stale;
    if (next == Phase::Active && (shard->counts_.structural == 0 || shard->geometry_dirty_ ||
        shard->applied_physics_revision_ != shard->geometry_.revision)) return Outcome::Fenced;
    if (next == Phase::Draining && shard->counts_.structural != 0) return Outcome::Invalid;
    shard->phase_ = next;
    return Outcome::Accepted;
}
Outcome Registry::cancel_precommit(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != Phase::Prepared && shard->phase_ != Phase::PhysicsReserved) return Outcome::Fenced;
    shard->clear_inventory();
    shard->phase_ = Phase::Retired;
    return Outcome::Cancelled;
}
Outcome Registry::quarantine_partial_commit(Handle handle,
        std::span<const std::uint32_t> debited) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ != Phase::CommittedInactive || !shard->authoritative_)
        return Outcome::Fenced;
    if (shard->area() > scratch_.seen_.size() || debited.size() > shard->counts_.total())
        return Outcome::Invalid;
    std::fill_n(scratch_.seen_.begin(), shard->area(), std::uint8_t{0});
    for (const auto index : debited) {
        if (index >= shard->area() || !shard->occupied(index) || scratch_.seen_[index] != 0)
            return Outcome::Invalid;
        scratch_.seen_[index] = 1;
    }
    bool removed = false;
    for (std::size_t index = 0; index < shard->area(); ++index) {
        if (!shard->occupied(index) || scratch_.seen_[index] != 0) continue;
        adjust(shard->counts_, shard->roles_[index], false);
        shard->cells_[index] = {};
        shard->roles_[index] = Role::Empty;
        if (!shard->temperatures_.empty()) shard->temperatures_[index] = shard->ambient_temperature_;
        shard->schedule_[index].next_due_tick = kNever;
        set_bit(shard->occupied_mask_, index, false);
        set_bit(shard->structural_mask_, index, false);
        removed = true;
    }
    if (removed) {
        // A fresh prepared payload cannot normally exhaust either counter. If
        // fault injection supplies one at its limit, quarantine still preserves
        // ownership without wrapping an identity or publishing new geometry.
        if (shard->material_revision_ != kNever) ++shard->material_revision_;
        if (shard->topology_revision_ != kNever) ++shard->topology_revision_;
        shard->geometry_dirty_ = true;
        for (std::size_t index = 0; index < shard->area(); ++index) shard->refresh_surface(index);
    }
    shard->phase_ = Phase::Quarantined;
    return Outcome::Quarantined;
}
Outcome Registry::quarantine(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    shard->phase_ = Phase::Quarantined;
    return Outcome::Quarantined;
}
Outcome Registry::retire(Handle handle) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->counts_.total() != 0) return Outcome::Busy;
    if (!shard->authoritative_) return Outcome::Fenced;
    shard->clear_inventory();
    shard->phase_ = Phase::Retired;
    return Outcome::Accepted;
}
Outcome Registry::rebuild_geometry(Handle handle, std::uint64_t tick) noexcept {
    auto* shard = find(handle);
    if (!shard) return Outcome::Stale;
    if (shard->phase_ == Phase::Quarantined) return Outcome::Quarantined;
    return shard->rebuild_geometry(scratch_, tick);
}
Counts Registry::inventory_counts() const noexcept {
    Counts counts;
    for (const auto& shard : shards_) if (shard.authoritative_) {
        counts.structural += shard.counts_.structural;
        counts.products += shard.counts_.products;
        counts.cargo += shard.counts_.cargo;
    }
    return counts;
}
MemoryUsage Registry::memory_usage() const noexcept {
    MemoryUsage result;
    result.live_bytes = sizeof(Registry) + live(slot_generations_) +
        live(scratch_.queue_) + live(scratch_.seen_) + live(scratch_.labels_) + live(scratch_.shapes_);
    result.retained_bytes = sizeof(Registry) + retained(slot_generations_) +
        retained(scratch_.queue_) + retained(scratch_.seen_) + retained(scratch_.labels_) + retained(scratch_.shapes_);
    for (const auto& shard : shards_) {
        const auto current = shard.memory_usage();
        result.live_bytes += current.live_bytes;
        result.retained_bytes += current.retained_bytes;
    }
    result.construction_allocations = construction_allocations_;
    result.peak_bytes = std::max(peak_retained_bytes_, result.retained_bytes);
    return result;
}
Outcome Registry::reset(std::uint64_t new_session, std::uint64_t new_world, Counts& disposed) noexcept {
    if (new_session <= session_ || new_world == 0) return Outcome::Stale;
    disposed = inventory_counts();
    for (auto& shard : shards_) { shard.clear_inventory(); shard.phase_ = Phase::Retired; }
    session_ = new_session;
    world_incarnation_ = new_world;
    return Outcome::Accepted;
}

const char* outcome_name(Outcome value) noexcept {
    switch (value) {
#define CS_OUTCOME(name) case Outcome::name: return #name
    CS_OUTCOME(Accepted); CS_OUTCOME(Invalid); CS_OUTCOME(Stale); CS_OUTCOME(Capacity);
    CS_OUTCOME(Unsupported); CS_OUTCOME(Busy); CS_OUTCOME(Fenced); CS_OUTCOME(Expired);
    CS_OUTCOME(Retired); CS_OUTCOME(UnknownBoundary); CS_OUTCOME(DestinationUnavailable);
    CS_OUTCOME(PendingEvent); CS_OUTCOME(Quarantined); CS_OUTCOME(GenerationExhausted);
    CS_OUTCOME(Anchored); CS_OUTCOME(NotResident); CS_OUTCOME(Cancelled);
#undef CS_OUTCOME
    }
    return "Invalid";
}
const char* phase_name(Phase value) noexcept {
    switch (value) {
#define CS_PHASE(name) case Phase::name: return #name
    CS_PHASE(Empty); CS_PHASE(Prepared); CS_PHASE(PhysicsReserved); CS_PHASE(CommittedInactive);
    CS_PHASE(TerrainInstalled); CS_PHASE(MaskApplied); CS_PHASE(ReadyToActivate); CS_PHASE(Active);
    CS_PHASE(Draining); CS_PHASE(Suspended); CS_PHASE(Quarantined); CS_PHASE(Retired);
#undef CS_PHASE
    }
    return "Empty";
}
} // namespace cybersand::object_shard
