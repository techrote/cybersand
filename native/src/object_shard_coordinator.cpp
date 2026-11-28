#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/object_shard_mutation.hpp"
#include "cybersand/object_shard_contact.hpp"
#include "cybersand/material_lifecycle.hpp"
#include "cybersand/material_rules.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <limits>
#include <stdexcept>

namespace cybersand::object_shard {
namespace {
using Clock = std::chrono::steady_clock;
std::uint64_t now_ns() noexcept {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(
        Clock::now().time_since_epoch()).count());
}
struct ScopedTime {
    std::uint64_t& counter;
    std::uint64_t started{now_ns()};
    ~ScopedTime() {counter+=now_ns()-started;}
};
std::uint64_t new_session() {
    static std::atomic<std::uint64_t> next{1};
    auto value=next.load(std::memory_order_relaxed);
    for (;;) {
        if (value==0 || value==std::numeric_limits<std::uint64_t>::max())
            throw std::overflow_error("ObjectShard session identity exhausted");
        if (next.compare_exchange_weak(value,value+1,std::memory_order_relaxed)) return value;
    }
}
void hash_word(std::uint64_t& hash, std::uint64_t value) noexcept {
    for (unsigned i = 0; i < 8; ++i) { hash ^= value & 255U; hash *= 1099511628211ULL; value >>= 8U; }
}
std::uint64_t ack_fingerprint(const Acknowledgement& a) noexcept {
    std::uint64_t h = 1469598103934665603ULL;
    for (auto v : {a.shard.session, a.shard.id, a.shard.generation, a.transaction,
                   a.body_generation, a.payload_digest, a.geometry_revision, a.mask_digest, a.shape_digest}) hash_word(h, v);
    hash_word(h, static_cast<std::uint8_t>(a.kind));
    for (const auto& t : a.terrain) { hash_word(h, t.id); hash_word(h, t.revision); hash_word(h, t.digest); }
    return h;
}
bool coherent_payload(Payload p) noexcept {
    return valid_material(static_cast<std::uint16_t>(p.material)) &&
        (p.material == Material::Water || p.state_a <= 255);
}
constexpr std::array<std::pair<int, int>, 4> kCardinal{{{-1,0},{1,0},{0,-1},{0,1}}};
std::uint64_t transfer_fingerprint(const TransferRequest& r,bool incoming) noexcept {
    std::uint64_t hash=1469598103934665603ULL;
    for (auto value:{r.shard.session,r.shard.id,r.shard.generation,r.sequence,r.body_generation,
        r.geometry_revision,r.pose_serial,r.world_witness}) hash_word(hash,value);
    hash_word(hash,r.cell);hash_word(hash,r.incarnation);hash_word(hash,r.capability_version);
    hash_word(hash,static_cast<std::uint64_t>(r.world_x));hash_word(hash,static_cast<std::uint64_t>(r.world_y));
    hash_word(hash,static_cast<std::uint8_t>(r.expected.material));hash_word(hash,r.expected.state_a);
    hash_word(hash,r.expected.state_b);hash_word(hash,static_cast<std::uint16_t>(r.expected.temperature));
    hash_word(hash,incoming);return hash;
}
std::uint64_t edit_fingerprint(const ShardEditRequest& r, ShardAction action) noexcept {
    std::uint64_t hash=1469598103934665603ULL;
    hash_word(hash,0x4552415345ULL); // A distinct operation domain from transfers.
    hash_word(hash,static_cast<std::uint8_t>(action));
    for (const auto value:{r.shard.session,r.shard.id,r.shard.generation,r.sequence,r.body_generation,
        r.geometry_revision,r.pose_serial,r.material_revision}) hash_word(hash,value);
    hash_word(hash,r.cell);hash_word(hash,r.incarnation);hash_word(hash,r.capability_version);
    hash_word(hash,static_cast<std::uint8_t>(r.expected.material));hash_word(hash,r.expected.state_a);
    hash_word(hash,r.expected.state_b);hash_word(hash,static_cast<std::uint16_t>(r.expected.temperature));
    return hash;
}
contact::Pose contact_pose(const PoseSample& p) noexcept {return {p.x,p.y,p.rotation};}
}

struct Coordinator::Pending {
    struct Captured { std::int64_t x{}, y{}; std::uint32_t local{}; Payload payload{}; std::uint64_t witness{}; };
    bool present{};
    bool reabsorption{}, world_committed{}, reabsorption_mask_removed{};
    Handle shard{};
    Handle source_parent{};
    std::uint64_t parent_material_revision{}, parent_geometry_revision{}, parent_pose_serial{}, parent_payload_digest{};
    std::uint64_t source_mask_digest{}, source_shape_digest{}, source_body_generation{}, action_fingerprint{};
    std::uint64_t transaction{}, payload_digest{}, captured_tick{}, watch_incarnation{}, watch_revision{};
    std::vector<Captured> cells;
    std::vector<TerrainReceipt> terrain;
    std::vector<PocketFence> fragment_fences;
    std::array<std::uint64_t, 3> acknowledgements{};
};
struct Coordinator::Receipt {
    std::uint64_t sequence{}, fingerprint{};
    Result result{};
    std::array<std::uint64_t, 3> acknowledgements{};
};

Coordinator::Coordinator(Config config) : Coordinator(config, nullptr) {}

Coordinator::Coordinator(World& attached_world, Config config)
    : Coordinator(config, &attached_world) {}

Coordinator::Coordinator(Config config, World* owner_world)
    : config_(config), session_(new_session()), world_incarnation_(session_),
      registry_(config.limits, session_, world_incarnation_), pending_(std::make_unique<Pending>()) {
    attached_ = owner_world != nullptr;
    const auto area = config_.world_bounds.area();
    // Reject before halo arithmetic or floating point conversion. The Lab's
    // declared finite coordinate envelope also preserves exact cell centres.
    const auto bounds=config_.world_bounds;
    if (!valid_bounds(bounds) || bounds.x < -262144 || bounds.y < -262144 ||
        bounds.x > 262144-static_cast<std::int64_t>(bounds.width) ||
        bounds.y > 262144-static_cast<std::int64_t>(bounds.height) || bounds.width < 64 ||
        config_.world_bounds.height < 64 || area > (attached_ ? 1048576U : 262144U) || config_.scenario > 6 || config_.limits.max_shapes > 512 ||
        config_.limits.max_shards > World::kMaximumTransientBodies || config_.discovery_budget == 0 ||
        config_.exposure_capacity == 0 || config_.exposure_capacity > 65536 || config_.transfer_budget > 1024 ||
        config_.max_pause_calls == 0 || !std::isfinite(config_.max_translation_per_step) ||
        config_.max_translation_per_step <= 0 || config_.max_translation_per_step > 8 ||
        !std::isfinite(config_.max_rotation_per_step) || config_.max_rotation_per_step <= 0 ||
        config_.max_rotation_per_step > .25 || config_.relocation_probe_budget==0 ||
        config_.relocation_probe_budget>kMaximumRelocationProbes)
        throw std::invalid_argument("ObjectShard Lab configuration outside bounded M0-M2 envelope");
    discovery_ = std::make_unique<ComponentDiscovery>(config_.world_bounds, config_.limits, attached_);
    component_.reserve(config_.limits.max_area);
    proposed_mask_.resize(area); materials_.resize(area);
    reserved_destinations_.resize(area);ingress_exclusion_.resize(area);
    // Each occupied source index is visited once per mask transaction. A
    // finite World can therefore request at most one relocation per cell.
    relocations_.reserve(std::min<std::size_t>(area, config_.limits.max_total_area * 4U));
    exposures_.reserve(config_.exposure_capacity); receipts_.resize(64);
    fire_opportunities_.resize(area);
    ingress_fences_.reserve(config_.limits.max_total_area);
    ingress_fences_backup_.reserve(config_.limits.max_total_area);
    ingress_proposals_.reserve(config_.transfer_budget);
    bodies_.resize(config_.limits.max_shards); body_backup_.resize(config_.limits.max_shards);
    pending_->cells.reserve(config_.limits.max_area);
    const auto tiles = ((config_.world_bounds.width + 63U) / 64U) * ((config_.world_bounds.height + 63U) / 64U);
    pending_->terrain.reserve(tiles); terrain_.resize(tiles); terrain_scratch_.resize(4096);
    for (auto& tile : terrain_) tile.rectangles.reserve(4096);
    if (attached_) initialize_attached_world(*owner_world);
    else initialize_world();
}
Coordinator::~Coordinator() {
    // The owning facade destroys us before replacing its World. Remove the
    // synchronous span into our Fire field before freeing that field, including
    // an exceptional World tick that did not reach after_owner_world_tick().
    if (attached_ && world_ && world_->object_shard_mutations_)
        world_->object_shard_mutations_.reset();
}

void Coordinator::initialize_world() {
    if (attached_) throw std::logic_error("ordinary owner cannot initialize a second shard World");
    WorldConfig wc;
    wc.chunk_size = 32; wc.activity_block_size = 16; wc.scheduling_core_size = 32;
    wc.backend = SimulationBackend::SerialInPlace; wc.worker_threads = 1;
    wc.initial_chunk_reserve = 128; wc.maximum_chunk_count = 1024;
    wc.active_chunk_capacity = 1024; wc.active_core_capacity = 1024;
    wc.deferred_event_capacity = 32;
    owned_world_ = std::make_unique<World>(wc);
    world_ = owned_world_.get();
    terrain_source_revision_=UINT64_MAX;
    const auto b = config_.world_bounds;
    const RectI64 bounds{b.x, b.y, b.width, b.height};
    world_->reserve_region({b.x - 32, b.y - 32, b.width + 64, b.height + 64});
    world_->reserve_temperature_region({b.x - 32, b.y - 32, b.width + 64, b.height + 64});
    world_->set_simulation_region(bounds);
    world_->configure_transient_obstacles(bounds, true);
    world_->enable_object_shard_mutation_watch(bounds);
    author_scenario(config_.scenario);
    // A healthy returned tick, not the early completed index alone, is the
    // admission boundary. Initial fixtures are supported during this tick.
    (void)world_->tick();
    const auto baseline=world_->quantity_ledger();
    for (std::size_t m=1;m<kQuantityMaterialSlots;++m) accounting_.setup_created[m]+=baseline.material_cells[m];
    rebuild_terrain();
}

void Coordinator::initialize_attached_world(World& owner) {
    // The host created, reserved, configured and ticked this same World. No
    // scenario authoring, tick, simulation-region change or private World.
    if (owner.has_failed() || owner.is_tick_in_progress() || owner.object_shard_mutations_ ||
        owner.completed_tick_index() == 0 || owner.config().chunk_size < 1 ||
        !owner.simulation_region().has_value() ||
        config_.limits.max_shards > OwnerReadback::kBodySlots ||
        owner.transient_occupancy_capacity() < config_.limits.max_total_area)
        throw std::invalid_argument("ObjectShard attachment requires a prepared bounded owner World");
    const auto bounds = owner.simulation_region().value();
    const auto region = config_.world_bounds;
    if (region.x < bounds.x || region.y < bounds.y ||
        region.x + region.width > bounds.x + bounds.width ||
        region.y + region.height > bounds.y + bounds.height)
        throw std::invalid_argument("ObjectShard attachment region outside owner simulation");
    world_ = &owner;
    immutable_occupancy_.reserve(owner.transient_occupancy_capacity());
    immutable_occupancy_backup_.reserve(owner.transient_occupancy_capacity());
    shard_occupancy_.reserve(std::min<std::size_t>(region.area(), config_.limits.max_total_area * 4U));
    proposed_indices_.reserve(shard_occupancy_.capacity());
    // This watch listens to the *existing* World and its real native tick.
    owner.enable_object_shard_mutation_watch({region.x, region.y, region.width, region.height});
    last_owner_tick_ = owner.completed_tick_index();
    last_owner_population_ = owner.quantity_ledger().material_cells;
    // Existing World inventory predated this attached coordinator. Account
    // for it as the inherited setup baseline, never as new shard material.
    for (std::size_t m = 1; m < kQuantityMaterialSlots; ++m)
        accounting_.setup_created[m] += last_owner_population_[m];
    rebuild_terrain();
}

void Coordinator::author_scenario(std::uint32_t scenario) {
    const auto b = config_.world_bounds;
    for (std::int64_t x = b.x; x < b.x + b.width; ++x) {
        world_->set(x, b.y, Material::Wall);
        world_->set(x, b.y + b.height - 1, Material::Wall);
        world_->set(x, b.y + b.height - 2, Material::Wall);
    }
    for (std::int64_t y = b.y; y < b.y + b.height; ++y) {
        world_->set(b.x, y, Material::Wall); world_->set(b.x + b.width - 1, y, Material::Wall);
    }
    if (scenario == 0) return;
    const auto floor = b.y + b.height - 18;
    for (std::int64_t x = b.x + 1; x < b.x + b.width - 1; ++x) world_->set(x, floor, Material::Wall);
    const unsigned count = scenario == 4 || scenario == 6 ? std::min(3U, config_.limits.max_shards) : 1U;
    for (unsigned body_index = 0; body_index < count; ++body_index) {
        const auto trunk_x = b.x + (count == 1 ? b.width / 2 : (body_index + 1U) * b.width / 4U);
        // Deliberately asymmetric native Wood crown, trunk and open lodging
        // pocket. These are ordinary cells; cutting uses the same edit API.
        for (auto y = floor - 42; y < floor; ++y)
            for (auto x = trunk_x - 2; x <= trunk_x + 1; ++x) world_->set(x, y, Material::Wood);
        for (auto y = floor - 49; y < floor - 31; ++y)
            for (auto x = trunk_x - 12; x < trunk_x + 16; ++x)
                if (!(y < floor - 45 && (x < trunk_x - 7 || x > trunk_x + 10))) world_->set(x, y, Material::Wood);
        // A real off-centre masonry ledge makes the falling trunk tip on
        // impact. No scripted impulse or authored body rotation is involved.
        if (scenario==1)
            for (auto y=floor-4;y<floor;++y) world_->set(trunk_x-2,y,Material::Wall);
        // The exchange scenario uses a real three-cell-wide aperture, giving
        // full World carriers room under the conservative rotated occupancy
        // mask. Other scenarios retain the original narrow crown recess.
        for (auto y = floor - 49; y <= floor - 36; ++y)
            for (auto dx=scenario==3 ? -1 : 0;dx<=(scenario==3 ? 1 : 0);++dx)
                world_->set(trunk_x+8+dx,y,Material::Empty);
        if (scenario == 5) {
            for (auto y = floor - 44; y < floor - 32; y += 2)
                for (auto x = trunk_x - 9; x < trunk_x + 14; x += 3) world_->set(x, y, Material::Empty);
        }
        if (scenario == 2 || scenario == 4) {
            (void)world_->set_cell_state(trunk_x + 15, floor - 40, Material::Wood, 0, 240);
            world_->set_temperature(trunk_x + 15, floor - 40, 650);
            // A separate, already-nearly-consumed surface cell demonstrates
            // erosion promptly even when native Fire re-ignites the longer
            // burning crown. Both are ordinary authored Wood burn states.
            (void)world_->set_cell_state(trunk_x - 12, floor - 40, Material::Wood, 0, 16);
            world_->set_temperature(trunk_x - 12, floor - 40, 650);
        }
        if (scenario == 3) {
            (void)world_->set_cell_state(trunk_x - 12, floor - 39, Material::Wood, 0, 240);
            for (auto y = floor - 60; y < floor - 55; ++y) world_->set(trunk_x + 8, y, Material::Sand);
        }
    }
}

bool Coordinator::resident(std::int64_t x, std::int64_t y) const noexcept {
    const auto b = config_.world_bounds;
    return x >= b.x && y >= b.y && x < b.x + b.width && y < b.y + b.height;
}
bool Coordinator::immutable_occupied(std::int64_t x, std::int64_t y) const noexcept {
    const auto found=std::lower_bound(immutable_occupancy_.begin(),immutable_occupancy_.end(),
        std::pair{y,x},[](const auto& cell,const auto& key) {
            return std::pair{cell.y,cell.x}<key;
        });
    return found!=immutable_occupancy_.end() && found->x==x && found->y==y;
}
Payload Coordinator::inspect_world(std::int64_t x, std::int64_t y) const noexcept {
    if (!world_) return {};
    return {world_->stored_material(x,y), world_->stored_state_a(x,y), world_->stored_state_b(x,y), world_->stored_temperature(x,y)};
}
std::uint64_t Coordinator::world_witness(std::int64_t x,std::int64_t y) const noexcept {
    if (!world_ || !world_->object_shard_mutations_) return 0;
    return world_->object_shard_mutations_->witness(x,y);
}
std::uint64_t Coordinator::world_material_revision() const noexcept {
    return world_ && world_->object_shard_mutations_ ? world_->object_shard_mutations_->revision() : 0;
}
Result Coordinator::finish(Result r) noexcept {
    last_result_ = r;
    if (r.outcome != Outcome::Accepted && r.outcome != Outcome::Anchored && r.outcome != Outcome::Busy) ++metrics_.refusals;
    return r;
}
Metrics Coordinator::lifetime_metrics() const noexcept {
    auto total=metrics_;
#define CS_ADD_METRIC(field) total.field+=historical_metrics_.field
    CS_ADD_METRIC(steps);CS_ADD_METRIC(paused_calls);CS_ADD_METRIC(discovered_cells);CS_ADD_METRIC(promotions);CS_ADD_METRIC(refusals);
    CS_ADD_METRIC(chemistry_cells);CS_ADD_METRIC(products_created);CS_ADD_METRIC(output_blocked);CS_ADD_METRIC(sand_ingested);
    CS_ADD_METRIC(exposure_overflows);CS_ADD_METRIC(stale_messages);CS_ADD_METRIC(mask_cells);CS_ADD_METRIC(sweep_samples);CS_ADD_METRIC(ingress_blocked);
    CS_ADD_METRIC(composed_overlap_cells);CS_ADD_METRIC(composed_reuses);CS_ADD_METRIC(fragments);CS_ADD_METRIC(fragment_refusals);CS_ADD_METRIC(reabsorptions);
    CS_ADD_METRIC(relocation_probes);CS_ADD_METRIC(relocation_probe_limit_hits);
    CS_ADD_METRIC(relocated_cells);CS_ADD_METRIC(relocated_water_cells);CS_ADD_METRIC(relocated_sand_cells);
    CS_ADD_METRIC(world_ns);CS_ADD_METRIC(chemistry_ns);CS_ADD_METRIC(contact_ns);CS_ADD_METRIC(occupancy_ns);CS_ADD_METRIC(geometry_ns);CS_ADD_METRIC(snapshot_ns);
    CS_ADD_METRIC(discovery_ns);CS_ADD_METRIC(terrain_ns);CS_ADD_METRIC(exchange_ns);CS_ADD_METRIC(relocation_ns);
#undef CS_ADD_METRIC
#define CS_MAX_METRIC(field) total.field=std::max(total.field,historical_metrics_.field)
    CS_MAX_METRIC(maximum_pause_ns);CS_MAX_METRIC(maximum_geometry_age);CS_MAX_METRIC(maximum_geometry_wait_ns);CS_MAX_METRIC(maximum_product_age);
    CS_MAX_METRIC(peak_bytes);
#undef CS_MAX_METRIC
    return total;
}
BodyView* Coordinator::body(Handle h) noexcept {
    for (auto& b : bodies_) if (b.shard == h) return &b;
    return nullptr;
}
const BodyView* Coordinator::body(Handle h) const noexcept {
    for (const auto& b : bodies_) if (b.shard == h) return &b;
    return nullptr;
}
void Coordinator::preserve_material_point_velocity(Handle handle, MassProperties previous) noexcept {
    auto* physical=body(handle);const auto* shard=registry_.find(handle);
    if (!physical || !physical->has_body || !shard || previous.mass<=0 || shard->geometry().mass.mass<=0) return;
    const auto& current=shard->geometry().mass;
    const auto dx=current.com_x-previous.com_x,dy=current.com_y-previous.com_y;
    const auto cs=std::cos(physical->pose.rotation),sn=std::sin(physical->pose.rotation);
    physical->pose.vx-=physical->pose.angular_velocity*(sn*dx+cs*dy);
    physical->pose.vy+=physical->pose.angular_velocity*(cs*dx-sn*dy);
    // Removing material removes that material's momentum. Preserve angular
    // velocity and every surviving point's velocity, matching the actual
    // Rapier mass/COM installer rather than amplifying spin after a small cut.
}
bool Coordinator::paused() const noexcept {
    if (!world_ || quarantined_ || pending_->present) return true;
    for (const auto& b : bodies_) if (b.geometry_pending) return true;
    return false;
}
OwnerReadback Coordinator::m4_owner_readback() const noexcept {
    // Exclusive owner only. No full World presentation copy or discovery
    // refresh, and no borrowed coordinator memory escapes this value object.
    OwnerReadback readback{};
    readback.session = session_;
    readback.world_incarnation = world_incarnation_;
    readback.world_available = world_ != nullptr;
    readback.tick = world_ ? world_->completed_tick_index() : 0;
    readback.paused = paused();
    readback.quarantined = quarantined_;
    readback.promotion_pending = pending_->present;
    for (const auto& body : bodies_) {
        if (body.has_body) ++readback.active_count;
        if (body.shard.id == 0) continue;
        if (readback.copied_count < readback.bodies.size()) {
            readback.bodies[readback.copied_count] = body;
            ++readback.copied_count;
        } else {
            readback.truncated = true;
        }
    }
    return readback;
}

Result Coordinator::edit(std::int64_t x, std::int64_t y, Payload value) {
    if (paused()) return finish({Outcome::Fenced, {}, 0, Phase::Empty, "Lab promotion/geometry barrier"});
    if (!resident(x,y)) return finish({Outcome::NotResident});
    if (!coherent_payload(value) || (value.material==Material::Water &&
        (value.state_a==0 || value.state_a>world_->config().water_experiment_policy.maximum() ||
         value.state_b>world_->config().water_experiment_policy.coherence_ticks()))) return finish({Outcome::Unsupported});
    if (world_->transient_obstacle_at(x,y)) return finish({Outcome::DestinationUnavailable});
    if (inspect_world(x,y) == value) return finish({Outcome::Accepted,{},0,Phase::Empty,"unchanged World cell"});
    // All cell/temperature storage is reserved at construction.
    const auto before=world_->stored_material(x,y);
    (void)world_->set_cell_state(x,y,value.material,value.state_a,value.state_b);
    world_->set_temperature(x,y,value.temperature);
    if (before!=value.material) {
        // Authored replacement is a new inventory identity. Same-Fire state
        // edits retain the existing opportunity; erase/recreate does not.
        fire_opportunities_[static_cast<std::size_t>(y-config_.world_bounds.y)*config_.world_bounds.width+
            static_cast<std::size_t>(x-config_.world_bounds.x)]=0;
        if (before!=Material::Empty) ++accounting_.authored_destroyed[static_cast<std::uint8_t>(before)];
        if (value.material!=Material::Empty) ++accounting_.authored_created[static_cast<std::uint8_t>(value.material)];
    }
    return finish({});
}
Result Coordinator::ignite(std::int64_t x, std::int64_t y) {
    auto p = inspect_world(x,y);
    if (p.material != Material::Wood) return finish({Outcome::Unsupported});
    p.state_b = 240;
    return edit(x,y,p);
}
Result Coordinator::ignite_shard(Handle h, std::uint32_t cell) {
    if (paused()) return finish({Outcome::Fenced,h});
    auto* shard = registry_.find(h);
    if (!shard || !shard->chemistry_allowed() || cell >= shard->area()) return finish({Outcome::Stale,h});
    auto p = shard->payload(cell);
    if (p.material != Material::Wood) return finish({Outcome::Unsupported,h});
    p.state_b = 240;
    const auto result = shard->set_cell(cell,p,Role::Structural,world_->completed_tick_index());
    return finish({result,h});
}

Result Coordinator::erase_shard(const ShardEditRequest& r) {
    return act_on_shard(r, ShardAction::Erase);
}

Result Coordinator::act_on_shard(const ShardEditRequest& r, ShardAction action) {
    const auto fingerprint=edit_fingerprint(r, action);
    if (r.shard.session!=session_) return finish({Outcome::Retired,r.shard,r.sequence});
    if (const auto* previous=prior(r.sequence)) return previous->fingerprint==fingerprint ? previous->result
        : finish({Outcome::Stale,r.shard,r.sequence});
    if (r.sequence!=next_transaction_) return finish({r.sequence<next_transaction_ ? Outcome::Expired : Outcome::Stale,r.shard,r.sequence});
    if (next_transaction_==std::numeric_limits<std::uint64_t>::max()) return finish({Outcome::GenerationExhausted,r.shard,r.sequence});
    ++next_transaction_;
    const auto done=[&](Outcome result,const char* detail) {
        const auto* current=registry_.find(r.shard);
        return remember({result,r.shard,r.sequence,current ? current->phase() : Phase::Empty,detail},fingerprint);
    };
    if (paused()) return done(Outcome::Fenced,"material/physics installation barrier");
    auto* shard=registry_.find(r.shard);auto* b=body(r.shard);
    // Keep stale/refusal semantics; identify exactly which native witness
    // failed instead of misclassifying an uncertain material edit.
    if (!shard || !b || !b->has_body || shard->phase()!=Phase::Active)
        return done(Outcome::Stale, "no active installed shard body");
    if (r.cell>=shard->area())
        return done(Outcome::Stale, "shard cell outside owned inventory");
    if (r.body_generation!=b->body_generation)
        return done(Outcome::Stale, "body incarnation changed");
    if (r.geometry_revision!=shard->geometry().revision)
        return done(Outcome::Stale, "native geometry revision changed");
    if (r.geometry_revision!=shard->applied_physics_revision())
        return done(Outcome::Stale, "geometry not acknowledged by Rapier");
    if (r.pose_serial!=b->pose.pose_serial)
        return done(Outcome::Stale, "native applied pose serial changed");
    if (r.material_revision!=shard->material_revision())
        return done(Outcome::Stale, "native material revision changed");
    if (r.incarnation!=shard->schedule(r.cell).incarnation)
        return done(Outcome::Stale, "cell incarnation changed");
    if (r.expected!=shard->payload(r.cell))
        return done(Outcome::Stale, "exact cell material/state/temperature changed");
    if (r.capability_version!=kCapabilityVersion)
        return done(Outcome::Unsupported,"unsupported material capability version");
    if (action==ShardAction::Inspect)
        return done(Outcome::Accepted,"exact native owned-cell observation acknowledged; no mutation");
    if (action==ShardAction::Reabsorb) {
        const auto prepared=prepare_reabsorption(r);
        if (prepared==Outcome::Accepted) {
            pending_->action_fingerprint=fingerprint;
            return done(prepared,"settled body staged for exact World handoff; physical freeze acknowledgement required");
        }
        return done(prepared,"settle requires a slow, lattice-aligned body and empty, fully resident destinations");
    }
    if (shard->role(r.cell)!=Role::Structural)
        return done(Outcome::Unsupported,"only explicitly owned structural cells admit erase");
    const auto tick=world_->completed_tick_index();
    if (action==ShardAction::Ignite) {
        auto payload=shard->payload(r.cell);
        if (payload.material!=Material::Wood)
            return done(Outcome::Unsupported,"only witnessed Wood can be ignited");
        payload.state_b=240;
        return done(shard->set_cell(r.cell,payload,Role::Structural,tick),
            "exact native Wood ignition applied; inventory unchanged");
    }
    const auto previous_mass=shard->geometry().mass;
    const auto result=registry_.erase_structural(r.shard,r.cell,tick);
    if (result==Outcome::Capacity) return done(result,"ShapeLimit: exact post-cut geometry refused before material debit");
    if (result!=Outcome::Accepted) {
        if (result==Outcome::Quarantined) {
            if (shard->payload(r.cell).material==Material::Empty)
                ++accounting_.authored_destroyed[static_cast<std::uint8_t>(r.expected.material)];
            quarantined_=true;
        }
        return done(result,"structural erase preflight/commit refused");
    }
    ++accounting_.authored_destroyed[static_cast<std::uint8_t>(r.expected.material)];
    preserve_material_point_velocity(r.shard,previous_mass);
    b->geometry_pending=true;b->geometry_pending_tick=tick;b->geometry_pending_ns=now_ns();
    return done(Outcome::Accepted,"owned structural cell erased; exact geometry awaits physics acknowledgement");
}

bool Coordinator::pending_conflict(Bounds bounds) const noexcept {
    for (const auto& explosion:world_->pending_explosions_)
        if (explosion.x+explosion.radius>=bounds.x && explosion.x-explosion.radius<bounds.x+bounds.width &&
            explosion.y+explosion.radius>=bounds.y && explosion.y-explosion.radius<bounds.y+bounds.height) return true;
    return false;
}

Outcome Coordinator::capture_component(std::uint32_t root) {
    const auto& candidate = discovery_->candidate(root);
    if (!candidate.valid || candidate.reason != AdmissionReason::Ready ||
        !discovery_->members(root,component_)) return Outcome::Stale;
    const auto w = config_.world_bounds.width;
    const auto b = config_.world_bounds;
    // One Empty ring provides spatial product carriers without changing the
    // stable lattice origin as structural edges erode.
    Bounds bounds{b.x+candidate.min_x-1,b.y+candidate.min_y-1,
        static_cast<std::uint16_t>(candidate.max_x-candidate.min_x+3),
        static_cast<std::uint16_t>(candidate.max_y-candidate.min_y+3)};
    if (pending_conflict(bounds)) return Outcome::PendingEvent;
    // Transient occupancy and payload can change without a connectivity edit.
    // Refuse before acquiring staging so repeated live admission never churns
    // carrier allocations; other complete candidates remain selectable.
    for (const auto at:component_) {
        const auto x=b.x+at%w,y=b.y+at/w;const auto p=inspect_world(x,y);
        if (!structural_material_supported(p.material) || !coherent_payload(p) || world_->transient_obstacle_at(x,y))
            return Outcome::Unsupported;
    }
    Handle handle;
    const auto prepared = registry_.prepare(bounds,world_->completed_tick_index(),handle);
    if (prepared != Outcome::Accepted) return prepared;
    auto* shard = registry_.find(handle);
    pending_->cells.clear(); pending_->terrain.clear(); pending_->acknowledgements = {};
    for (const auto at : component_) {
        const auto x = b.x + at % w, y = b.y + at / w;
        const auto p = inspect_world(x,y);
        if (!structural_material_supported(p.material) || !coherent_payload(p) || world_->transient_obstacle_at(x,y)) {
            (void)registry_.cancel_precommit(handle); return Outcome::Unsupported;
        }
        const auto local = static_cast<std::uint32_t>((y-bounds.y)*bounds.width + x-bounds.x);
        if (shard->set_cell(local,p,Role::Structural,world_->completed_tick_index()) != Outcome::Accepted) {
            (void)registry_.cancel_precommit(handle); return Outcome::Capacity;
        }
        pending_->cells.push_back({x,y,local,p,world_->object_shard_mutations_->witness(x,y)});
    }
    const auto ready = registry_.finish_preparation(handle);
    if (ready != Outcome::Accepted) {
        (void)registry_.cancel_precommit(handle);
        if (ready == Outcome::Capacity) discovery_->refuse(root,AdmissionReason::ShapeLimit);
        return ready;
    }
    pending_->present = true; pending_->reabsorption=false;pending_->world_committed=false;
    pending_->shard = handle; pending_->source_parent={};
    pending_->transaction = next_transaction_++;
    pending_->payload_digest = shard->payload_digest(); pending_->captured_tick = world_->completed_tick_index();
    pending_->watch_incarnation = world_->object_shard_mutations_->incarnation();
    pending_->watch_revision = world_->object_shard_mutations_->revision();
    auto slot = std::find_if(bodies_.begin(), bodies_.end(), [](const auto& body) { return body.shard.id == 0; });
    if (slot == bodies_.end()) { (void)registry_.cancel_precommit(handle); pending_->present=false; return Outcome::Capacity; }
    *slot = {}; slot->shard=handle; slot->transaction=pending_->transaction; slot->body_generation=handle.generation;
    slot->pose={handle,handle.generation,shard->geometry().revision,0,static_cast<double>(bounds.x),static_cast<double>(bounds.y)};
    slot->previous_pose=slot->pose;
    pause_started_ns_=now_ns(); pause_calls_=0;
    return Outcome::Accepted;
}

Outcome Coordinator::capture_fragment(Handle parent_handle) {
    auto* parent=registry_.find(parent_handle);auto* parent_body=body(parent_handle);
    if (!parent || !parent_body || !parent_body->has_body) return Outcome::Stale;
    auto slot=std::find_if(bodies_.begin(),bodies_.end(),[](const auto& value){return value.shard.id==0;});
    if (slot==bodies_.end()) return Outcome::Capacity;
    Handle child_handle;
    const auto ready=registry_.prepare_fragment(parent_handle,world_->completed_tick_index(),child_handle);
    if (ready!=Outcome::Accepted) return ready;
    const auto* child=registry_.find(child_handle);
    pending_->fragment_fences.clear();
    const auto fence_count=static_cast<std::size_t>(std::count_if(ingress_fences_.begin(),ingress_fences_.end(),
        [&](const auto& fence){return fence.shard_id==parent_handle.id;}));
    if (fence_count>config_.limits.max_area) {(void)registry_.cancel_precommit(child_handle);return Outcome::Capacity;}
    try {pending_->fragment_fences.reserve(fence_count);}
    catch (const std::bad_alloc&) {(void)registry_.cancel_precommit(child_handle);return Outcome::Capacity;}
    const auto child_dx=child->bounds().x-parent->bounds().x,child_dy=child->bounds().y-parent->bounds().y;
    for (const auto& fence:ingress_fences_) if (fence.shard_id==parent_handle.id) {
        const auto minimum=std::max<std::int64_t>(0,static_cast<std::int64_t>(fence.min_x)-child_dx);
        const auto maximum=std::min<std::int64_t>(child->bounds().width,static_cast<std::int64_t>(fence.max_x)-child_dx);
        if (minimum>=maximum) continue;
        if (pending_->fragment_fences.size()==pending_->fragment_fences.capacity() ||
            ingress_fences_.size()+pending_->fragment_fences.size()==ingress_fences_.capacity()) {
            (void)registry_.cancel_precommit(child_handle);return Outcome::Capacity;
        }
        pending_->fragment_fences.push_back({child_handle.id,static_cast<std::uint16_t>(minimum),
            static_cast<std::uint16_t>(maximum),static_cast<std::uint16_t>(std::clamp<std::int64_t>(
                static_cast<std::int64_t>(fence.row)-child_dy,0,child->bounds().height-1))});
    }
    pending_->present=true;pending_->reabsorption=false;pending_->world_committed=false;
    pending_->shard=child_handle;pending_->source_parent=parent_handle;
    pending_->transaction=next_transaction_++;pending_->payload_digest=child->payload_digest();
    pending_->captured_tick=world_->completed_tick_index();
    pending_->watch_incarnation=world_->object_shard_mutations_->incarnation();
    pending_->watch_revision=world_->object_shard_mutations_->revision();
    pending_->parent_material_revision=parent->material_revision();
    pending_->parent_geometry_revision=parent->geometry().revision;
    pending_->parent_pose_serial=parent_body->pose.pose_serial;
    pending_->parent_payload_digest=parent->payload_digest();
    pending_->cells.clear();pending_->terrain.clear();pending_->acknowledgements={};
    *slot={};slot->shard=child_handle;slot->source_parent=parent_handle;
    slot->transaction=pending_->transaction;slot->body_generation=child_handle.generation;
    const auto dx=static_cast<double>(child->bounds().x-parent->bounds().x);
    const auto dy=static_cast<double>(child->bounds().y-parent->bounds().y);
    const auto cs=std::cos(parent_body->pose.rotation),sn=std::sin(parent_body->pose.rotation);
    slot->pose=parent_body->pose;slot->pose.shard=child_handle;
    slot->pose.body_generation=child_handle.generation;slot->pose.pose_serial=0;
    slot->pose.geometry_revision=child->geometry().revision;
    slot->pose.x+=cs*dx-sn*dy;slot->pose.y+=sn*dx+cs*dy;
    const auto com_dx=dx+child->geometry().mass.com_x-parent->geometry().mass.com_x;
    const auto com_dy=dy+child->geometry().mass.com_y-parent->geometry().mass.com_y;
    const auto world_dx=cs*com_dx-sn*com_dy,world_dy=sn*com_dx+cs*com_dy;
    slot->pose.vx-=parent_body->pose.angular_velocity*world_dy;
    slot->pose.vy+=parent_body->pose.angular_velocity*world_dx;
    slot->previous_pose=slot->pose;
    pause_started_ns_=now_ns();pause_calls_=0;
    return Outcome::Accepted;
}

Outcome Coordinator::prepare_reabsorption(const ShardEditRequest& request) {
    if (!attached_) return Outcome::Unsupported;
    auto* shard=registry_.find(request.shard);auto* physical=body(request.shard);
    if (!shard || !physical || !physical->has_body || shard->phase()!=Phase::Active)
        return Outcome::Stale;
    const auto& pose=physical->pose;
    // Explicit authoring conversion to the cellular grid, never automatic
    // disposal of a moving body. No arbitrary-angle many-to-one rasterization.
    if (contact::magnitude(pose.vx,pose.vy)>.25 || std::abs(pose.angular_velocity)>.01)
        return Outcome::Busy;
    constexpr double half_pi=1.57079632679489661923;
    const auto angle=std::remainder(pose.rotation,4.*half_pi);
    const auto quadrant=static_cast<int>(std::llround(angle/half_pi));
    if (std::abs(angle-quadrant*half_pi)>.001) return Outcome::Unsupported;
    const auto origin_x=static_cast<std::int64_t>(std::llround(pose.x));
    const auto origin_y=static_cast<std::int64_t>(std::llround(pose.y));
    const auto turn=(quadrant+4)%4;
    const auto tick=world_->completed_tick_index();
    for (const auto& exposure:exposures_) if (exposure.shard==request.shard &&
        !exposure.consumed && exposure.expiry_tick>=tick) return Outcome::PendingEvent;
    const auto count=shard->counts().total();
    if (shard->material_revision()>UINT64_MAX-count || shard->topology_revision()>UINT64_MAX-count)
        return Outcome::GenerationExhausted;
    pending_->cells.clear();pending_->terrain.clear();pending_->fragment_fences.clear();
    std::fill(reserved_destinations_.begin(),reserved_destinations_.end(),std::uint8_t{0});
    const auto own_id=static_cast<std::uint16_t>(kFirstMutableBodyId+(physical-bodies_.data()));
    for (std::uint32_t at=0;at<shard->area();++at) if (shard->occupied(at)) {
        const auto lx=static_cast<std::int64_t>(at%shard->bounds().width);
        const auto ly=static_cast<std::int64_t>(at/shard->bounds().width);
        const auto x=origin_x+(turn==0 ? lx : turn==1 ? -ly-1 : turn==2 ? -lx-1 : ly);
        const auto y=origin_y+(turn==0 ? ly : turn==1 ? lx : turn==2 ? -ly-1 : -lx-1);
        if (!resident(x,y)) return Outcome::NotResident;
        const auto index=static_cast<std::size_t>(y-config_.world_bounds.y)*config_.world_bounds.width+
            static_cast<std::size_t>(x-config_.world_bounds.x);
        const auto obstacle=world_->transient_obstacle_at(x,y);
        if (reserved_destinations_[index] || immutable_occupied(x,y) ||
            (obstacle && obstacle!=own_id) || inspect_world(x,y).material!=Material::Empty)
            return Outcome::DestinationUnavailable;
        const auto value=shard->payload(at);
        const auto admitted=shard->validate_cell_write(at,{Material::Empty,0,0,value.temperature},Role::Empty,tick);
        if (admitted!=Outcome::Accepted) return admitted;
        reserved_destinations_[index]=1;
        pending_->cells.push_back({x,y,at,value,world_witness(x,y)});
    }
    // Shared conservative cells can hide a second shard behind a lower slot
    // in the derived union. Check every other physical carrier's actual square
    // against the destination set before permitting a static terrain credit.
    for (const auto& other:bodies_) {
        if (!other.has_body || other.shard==request.shard) continue;
        const auto* retained=registry_.find(other.shard);
        if (!retained || !retained->owns_inventory()) continue;
        const auto cs=std::cos(other.pose.rotation),sn=std::sin(other.pose.rotation);
        const auto half=(std::abs(cs)+std::abs(sn))*.5;
        for (std::size_t at=0;at<retained->area();++at) if (retained->structural(at) || retained->role(at)==Role::Cargo) {
            const auto lx=static_cast<double>(at%retained->bounds().width)+.5;
            const auto ly=static_cast<double>(at/retained->bounds().width)+.5;
            const auto cx=other.pose.x+cs*lx-sn*ly,cy=other.pose.y+sn*lx+cs*ly;
            for (auto y=static_cast<std::int64_t>(std::floor(cy-half));y<=static_cast<std::int64_t>(std::floor(cy+half));++y)
                for (auto x=static_cast<std::int64_t>(std::floor(cx-half));x<=static_cast<std::int64_t>(std::floor(cx+half));++x) {
                    if (!resident(x,y)) continue;
                    const auto index=static_cast<std::size_t>(y-config_.world_bounds.y)*config_.world_bounds.width+
                        static_cast<std::size_t>(x-config_.world_bounds.x);
                    if (!reserved_destinations_[index]) continue;
                    const auto dx=static_cast<double>(x)+.5-cx,dy=static_cast<double>(y)+.5-cy;
                    if (std::abs(dx)<half+.5-1e-9 && std::abs(dy)<half+.5-1e-9 &&
                        std::abs(dx*cs+dy*sn)<half+.5-1e-9 && std::abs(-dx*sn+dy*cs)<half+.5-1e-9)
                        return Outcome::DestinationUnavailable;
                }
        }
    }
    pending_->present=true;pending_->reabsorption=true;pending_->world_committed=false;pending_->reabsorption_mask_removed=false;
    pending_->shard=request.shard;pending_->source_parent={};pending_->transaction=request.sequence;
    pending_->payload_digest=shard->payload_digest();pending_->captured_tick=tick;
    pending_->watch_incarnation=world_->object_shard_mutations_->incarnation();
    pending_->watch_revision=world_->object_shard_mutations_->revision();
    pending_->parent_material_revision=shard->material_revision();
    pending_->parent_geometry_revision=shard->geometry().revision;pending_->parent_pose_serial=pose.pose_serial;
    pending_->source_mask_digest=shard->geometry().mask_digest;pending_->source_shape_digest=shard->geometry().shape_digest;
    pending_->source_body_generation=physical->body_generation;pending_->acknowledgements={};
    pause_started_ns_=now_ns();pause_calls_=0;
    return Outcome::Accepted;
}

bool Coordinator::validate_reabsorption() const noexcept {
    if (!pending_->present || !pending_->reabsorption || pending_->world_committed ||
        world_->has_failed() || world_->is_tick_in_progress() || world_->completed_tick_index()!=pending_->captured_tick ||
        world_->object_shard_mutations_->incarnation()!=pending_->watch_incarnation ||
        world_->object_shard_mutations_->revision()!=pending_->watch_revision) return false;
    const auto* shard=registry_.find(pending_->shard);const auto* physical=body(pending_->shard);
    if (!shard || !physical || !physical->has_body || shard->phase()!=Phase::Active ||
        shard->payload_digest()!=pending_->payload_digest || shard->material_revision()!=pending_->parent_material_revision ||
        shard->geometry().revision!=pending_->parent_geometry_revision ||
        physical->pose.pose_serial!=pending_->parent_pose_serial) return false;
    for (const auto& cell:pending_->cells)
        if (inspect_world(cell.x,cell.y).material!=Material::Empty ||
            world_witness(cell.x,cell.y)!=cell.witness || shard->payload(cell.local)!=cell.payload)
            return false;
    return true;
}

Outcome Coordinator::commit_reabsorption() {
    if (!validate_reabsorption()) return Outcome::Stale;
    auto* shard=registry_.find(pending_->shard);auto* physical=body(pending_->shard);
    const auto tick=world_->completed_tick_index();
    // A genuine physical freeze receipt has arrived. Withdraw only this body's
    // derived occupancy while both simulations remain fenced, so ordinary
    // World writes retain their obstacle checks. Material custody stays with
    // the shard until each corresponding World credit succeeds.
    pending_->reabsorption_mask_removed=true;
    const auto released=rebuild_mask(false);
    if (released!=Outcome::Accepted) {
        pending_->reabsorption_mask_removed=false;
        if (released==Outcome::Quarantined) quarantined_=true;
        return released;
    }
    for (const auto& cell:pending_->cells) {
        bool credited=false,debited=false;
        try {
            credited=world_->write_cell(cell.x,cell.y,cell.payload.material,cell.payload.state_a,cell.payload.state_b,nullptr,false);
            if (!credited) throw std::logic_error("reserved reabsorption destination changed");
            world_->set_temperature(cell.x,cell.y,cell.payload.temperature);
            debited=shard->set_cell(cell.local,{Material::Empty,0,0,cell.payload.temperature},Role::Empty,tick)==Outcome::Accepted;
            if (!debited) throw std::logic_error("reserved reabsorption source changed");
        } catch (...) {
            const auto actual=inspect_world(cell.x,cell.y);
            credited=actual.material==cell.payload.material && actual.state_a==cell.payload.state_a && actual.state_b==cell.payload.state_b;
            if (credited) {
                world_->set_temperature(cell.x,cell.y,cell.payload.temperature);
                if (!debited) debited=shard->set_cell(cell.local,{Material::Empty,0,0,cell.payload.temperature},Role::Empty,tick)==Outcome::Accepted;
                if (debited) ++accounting_.emitted[static_cast<std::uint8_t>(cell.payload.material)];
            }
            (void)registry_.quarantine(pending_->shard);quarantined_=true;
            return Outcome::Quarantined;
        }
        ++accounting_.emitted[static_cast<std::uint8_t>(cell.payload.material)];
    }
    pending_->world_committed=true;physical->geometry_pending=false;
    rebuild_terrain();pending_->terrain.clear();
    const auto bounds=config_.world_bounds;const auto columns=(bounds.width+63U)/64U;
    for (const auto& cell:pending_->cells) {
        const auto tile=static_cast<std::uint32_t>((cell.y-bounds.y)/64)*columns+
            static_cast<std::uint32_t>((cell.x-bounds.x)/64);
        if (std::find_if(pending_->terrain.begin(),pending_->terrain.end(),[&](const auto& value){return value.id==tile;})==pending_->terrain.end())
            pending_->terrain.push_back(terrain_[tile].identity);
    }
    std::sort(pending_->terrain.begin(),pending_->terrain.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    return Outcome::Accepted;
}

Result Coordinator::acknowledge_reabsorption(const Acknowledgement& receipt) {
    const auto fingerprint=ack_fingerprint(receipt);
    const auto kind=receipt.kind==AckKind::ReabsorptionFrozen ? 0U : 1U;
    if (receipt.shard.session!=session_) return finish({Outcome::Retired,receipt.shard,receipt.transaction});
    if (!pending_->present || !pending_->reabsorption || receipt.shard!=pending_->shard ||
        receipt.transaction!=pending_->transaction) {
        if (const auto* previous=prior(receipt.transaction);previous && previous->acknowledgements[kind]==fingerprint)
            return previous->result;
        return finish({Outcome::Stale,receipt.shard,receipt.transaction});
    }
    if (pending_->acknowledgements[kind]) return pending_->acknowledgements[kind]==fingerprint
        ? finish({Outcome::Accepted,receipt.shard,receipt.transaction,Phase::Draining,"duplicate reabsorption receipt"})
        : finish({Outcome::Stale,receipt.shard,receipt.transaction});
    if (receipt.body_generation!=pending_->source_body_generation || receipt.payload_digest!=pending_->payload_digest ||
        receipt.geometry_revision!=pending_->parent_geometry_revision || receipt.mask_digest!=pending_->source_mask_digest ||
        receipt.shape_digest!=pending_->source_shape_digest) return finish({Outcome::Stale,receipt.shard,receipt.transaction});
    if (receipt.kind==AckKind::ReabsorptionFrozen) {
        if (!receipt.terrain.empty()) return finish({Outcome::Invalid,receipt.shard,receipt.transaction});
        const auto committed=commit_reabsorption();
        if (committed!=Outcome::Accepted) return finish({committed,receipt.shard,receipt.transaction});
        pending_->acknowledgements[0]=fingerprint;
        return finish({Outcome::Accepted,receipt.shard,receipt.transaction,Phase::Draining,
            "World owns every credited cell; frozen body awaits physical removal and exact terrain installation"});
    }
    if (!pending_->world_committed || receipt.terrain.size()!=pending_->terrain.size())
        return finish({Outcome::Stale,receipt.shard,receipt.transaction});
    for (std::size_t i=0;i<receipt.terrain.size();++i)
        if (receipt.terrain[i]!=pending_->terrain[i]) return finish({Outcome::Stale,receipt.shard,receipt.transaction});
    auto* physical=body(receipt.shard);auto* shard=registry_.find(receipt.shard);
    if (!physical || !shard || shard->counts().total()!=0 || registry_.retire(receipt.shard)!=Outcome::Accepted)
        return quarantine(receipt.shard,"reabsorption completion source inventory mismatch");
    *physical={};++metrics_.reabsorptions;
    std::erase_if(ingress_fences_,[&](const auto& fence){return fence.shard_id==receipt.shard.id;});
    std::erase_if(exposures_,[&](const auto& exposure){return exposure.shard==receipt.shard;});
    pending_->acknowledgements[1]=fingerprint;
    const auto completed=remember({Outcome::Accepted,receipt.shard,receipt.transaction,Phase::Retired,
        "same-World reabsorption completed; physical body removed and exact terrain installed"},pending_->action_fingerprint);
    receipts_[receipt.transaction%receipts_.size()].acknowledgements=pending_->acknowledgements;
    pending_->present=false;
    metrics_.maximum_pause_ns=std::max(metrics_.maximum_pause_ns,now_ns()-pause_started_ns_);
    return completed;
}

void Coordinator::refresh_admission(std::uint32_t work) {
    std::uint32_t used_slots=0,used_area=0,active_bodies=0;
    for (const auto& shard:registry_.shards())
        if (shard.phase()!=Phase::Empty && shard.phase()!=Phase::Retired) {
            ++used_slots; used_area+=static_cast<std::uint32_t>(shard.area());
        }
    for (const auto& b:bodies_) active_bodies+=b.has_body ? 1U : 0U;
    const auto available=config_.limits.max_total_area-used_area;
    const bool changed=!admission_resource_valid_ || used_slots!=admission_slots_ || available!=admission_area_ || discovery_->dirty();
    admission_slots_=used_slots;admission_area_=available;admission_resource_valid_=true;
    admission_.pending_mutations=static_cast<std::uint32_t>(world_->object_shard_mutations_->pending());
    admission_.pending_seeds=discovery_->pending();admission_.frontier_cells=discovery_->frontier_pending();
    admission_.census_complete=admission_.pending_mutations==0 && discovery_->complete();
    admission_.work_last=work;admission_.work_peak=std::max(admission_.work_peak,work);
    admission_.completed_components=discovery_->completed_components();
    admission_.invalidations=discovery_->invalidations();admission_.interrupted_searches=discovery_->interrupted_searches();
    admission_.slots_used=used_slots;admission_.slot_limit=config_.limits.max_shards;admission_.active_bodies=active_bodies;
    if (!changed) {
        if (!admission_.census_complete) admission_.reason=AdmissionReason::Discovering;
        return;
    }
    admission_.components=admission_.eligible=admission_.deferred=admission_.anchored=0;
    admission_.unknown_boundary=admission_.refused_geometry=admission_.largest_cells=admission_.candidate_count=0;
    admission_.reason=AdmissionReason::None;
    std::uint32_t available_ready=0,area_deferred=0;
    for (const auto root:discovery_->roots()) {
        const auto& c=discovery_->candidate(root);++admission_.components;
        admission_.anchored+=c.anchored ? 1U : 0U;
        admission_.unknown_boundary+=c.unknown_boundary ? 1U : 0U;
        admission_.refused_geometry+=(c.reason==AdmissionReason::ComponentCells || c.reason==AdmissionReason::BoundingBox ||
            c.reason==AdmissionReason::ShapeLimit) ? 1U : 0U;
        auto reason=c.reason;
        if (reason==AdmissionReason::Ready) {
            ++admission_.eligible;admission_.largest_cells=std::max(admission_.largest_cells,c.cells);
            if (used_slots==config_.limits.max_shards) reason=AdmissionReason::BodySlots;
            else if (c.bbox_area()>available) {reason=AdmissionReason::TotalArea;++area_deferred;}
            else if (c.retry_after>admission_calls_) reason=c.blocked_reason;
            else ++available_ready;
            if (reason!=AdmissionReason::Ready) ++admission_.deferred;
        }
        AdmissionCandidate view{config_.world_bounds.x+c.min_x,config_.world_bounds.y+c.min_y,c.cells,c.bbox_area(),
            c.first_eligible ? metrics_.promotions+1-c.first_eligible : 0,reason};
        std::size_t position=0;
        while (position<admission_.candidate_count &&
            (admission_.candidates[position].cells>view.cells ||
             (admission_.candidates[position].cells==view.cells &&
              std::pair{admission_.candidates[position].y,admission_.candidates[position].x}<std::pair{view.y,view.x}))) ++position;
        if (position<admission_.candidates.size()) {
            const auto end=std::min<std::size_t>(admission_.candidate_count,admission_.candidates.size()-1);
            for (auto i=end;i>position;--i) admission_.candidates[i]=admission_.candidates[i-1];
            admission_.candidates[position]=view;
            admission_.candidate_count=std::min<std::uint32_t>(admission_.candidate_count+1,admission_.candidates.size());
        }
    }
    if (!admission_.census_complete) admission_.reason=AdmissionReason::Discovering;
    else if (admission_.eligible) admission_.reason=used_slots==config_.limits.max_shards ? AdmissionReason::BodySlots :
        available_ready ? AdmissionReason::Ready : area_deferred==admission_.eligible ? AdmissionReason::TotalArea :
        admission_.candidate_count ? admission_.candidates[0].reason : AdmissionReason::None;
    else if (admission_.candidate_count) admission_.reason=admission_.candidates[0].reason;
    discovery_->clear_dirty();
}

Result Coordinator::prepare_next() {
    ScopedTime timing{metrics_.discovery_ns};
    if (next_transaction_==std::numeric_limits<std::uint64_t>::max()) return finish({Outcome::GenerationExhausted});
    if (paused()) return finish({Outcome::Busy, pending_->shard, pending_->transaction,
        pending_->present ? registry_.find(pending_->shard)->phase() : Phase::Suspended, "barrier already pending"});
    if (world_->has_failed() || world_->is_tick_in_progress() || world_->completed_tick_index()==0 ||
        world_->object_shard_mutations_->exhausted()) return finish({Outcome::Quarantined});
    if (attached_) for (const auto& shard:registry_.shards()) {
        if (shard.phase()!=Phase::Active || !shard.geometry().split_pending) continue;
        const auto fragmented=capture_fragment(shard.handle());
        if (fragmented==Outcome::Accepted) return finish({fragmented,pending_->shard,pending_->transaction,
            Phase::Prepared,"disconnected island staged; parent retains inventory until physical reservation"});
        ++metrics_.fragment_refusals;
        if (fragmented!=Outcome::Capacity && fragmented!=Outcome::Unsupported)
            return finish({fragmented,shard.handle(),0,shard.phase(),"fragment source preflight refused"});
        if (auto* physical=body(shard.handle())) physical->fragment_deferred=true;
        // A refused split retains its complete compound body and continues
        // play. Another smaller detached World component may still fit.
    }
    if (admission_calls_>std::numeric_limits<std::uint64_t>::max()-9) return finish({Outcome::GenerationExhausted});
    ++admission_calls_;
    const bool cached=admission_.census_complete && !discovery_->dirty() &&
        world_->object_shard_mutations_->pending()==0;
    const auto old_slots=admission_slots_,old_area=admission_area_;
    std::uint32_t work=0;std::int64_t x{},y{};
    const auto b=config_.world_bounds;
    while (work<config_.discovery_budget && world_->object_shard_mutations_->pop(x,y)) {
        discovery_->invalidate(static_cast<std::uint32_t>((y-b.y)*b.width+x-b.x));++work;
    }
    if (world_->object_shard_mutations_->pending()==0) {
        const auto before=discovery_->visited_cells();
        work+=discovery_->advance(config_.discovery_budget-work,metrics_.promotions,[&](std::uint32_t at) {
            return world_->stored_material(b.x+at%b.width,b.y+at/b.width);
        });
        metrics_.discovered_cells+=discovery_->visited_cells()-before;
    }
    refresh_admission(work);
    if (discovery_->exhausted()) return finish({Outcome::GenerationExhausted});
    if (!admission_.census_complete) return finish({Outcome::Busy,{},0,Phase::Empty,"Discovering: bounded complete-component census in progress"});
    if (admission_.reason==AdmissionReason::BodySlots || admission_.reason==AdmissionReason::TotalArea) {
        const bool unchanged=cached && old_slots==admission_slots_ && old_area==admission_area_;
        if (unchanged) ++admission_.cached_capacity_calls;
        return finish({unchanged ? Outcome::Busy : Outcome::Capacity,{},0,Phase::Empty,
            admission_.reason==AdmissionReason::BodySlots ? "BodySlots: eligible inventory deferred in World; all owner slots occupied" :
                "TotalArea: eligible inventory deferred in World; retained bounding-box budget occupied"});
    }
    if (admission_.eligible==0) {
        const bool unchanged=cached && old_slots==admission_slots_ && old_area==admission_area_;
        if (admission_.reason==AdmissionReason::UnknownBoundary) return finish({unchanged ? Outcome::Busy : Outcome::UnknownBoundary,{},0,Phase::Empty,"UnknownBoundary: complete component touches the resident boundary"});
        if (admission_.refused_geometry) return finish({unchanged ? Outcome::Busy : Outcome::Capacity,{},0,Phase::Empty,admission_reason_name(admission_.reason)});
        return finish({Outcome::Busy,{},0,Phase::Empty,"no eligible detached component"});
    }
    // Three size-priority admissions followed by one oldest eligible admission.
    // A stable small candidate cannot be starved by an endless stream of larger
    // arrivals, and no frame-rate-dependent timing decides the priority.
    const auto root=discovery_->select((metrics_.promotions+1)%4==0,admission_area_,admission_calls_);
    if (root==ComponentDiscovery::kNone) {
        return finish({Outcome::Busy,{},0,Phase::Empty,"complete candidates await bounded live-admission retry"});
    }
    discovery_->retry(root);
    const auto result=capture_component(root);
    if (result==Outcome::Accepted) {
        refresh_admission(work);
        return finish({result,pending_->shard,pending_->transaction,Phase::Prepared,"complete priority-selected component"});
    }
    if (result==Outcome::Stale) discovery_->invalidate(root);
    const auto reason=result==Outcome::PendingEvent ? AdmissionReason::PendingEvent :
        result==Outcome::Unsupported ? AdmissionReason::Obstructed :
        result==Outcome::Capacity && discovery_->candidate(root).reason==AdmissionReason::Ready ? AdmissionReason::StorageCapacity :
        discovery_->candidate(root).reason;
    if (result==Outcome::PendingEvent || result==Outcome::Unsupported ||
        (result==Outcome::Capacity && reason==AdmissionReason::StorageCapacity))
        discovery_->defer(root,reason,admission_calls_+8);
    refresh_admission(work);
    // Payload/obstacle refusals can change without a topology mutation. Keep
    // their complete membership cached, but reconsider the live admission.
    admission_.reason=reason;
    return finish({result,{},0,Phase::Empty,admission_reason_name(reason)});
}

bool Coordinator::validate_prepared() const noexcept {
    if (!pending_->present || world_->has_failed() || world_->is_tick_in_progress() ||
        world_->completed_tick_index()!=pending_->captured_tick ||
        world_->object_shard_mutations_->incarnation()!=pending_->watch_incarnation ||
        world_->object_shard_mutations_->revision()!=pending_->watch_revision) return false;
    const auto* shard=registry_.find(pending_->shard);
    if (pending_->source_parent.id) {
        const auto* parent=registry_.find(pending_->source_parent);const auto* physical=body(pending_->source_parent);
        return shard && parent && physical && physical->has_body && parent->phase()==Phase::Active &&
            parent->material_revision()==pending_->parent_material_revision &&
            parent->geometry().revision==pending_->parent_geometry_revision &&
            parent->applied_physics_revision()==pending_->parent_geometry_revision &&
            physical->pose.pose_serial==pending_->parent_pose_serial &&
            parent->payload_digest()==pending_->parent_payload_digest;
    }
    if (!shard || pending_conflict(shard->bounds())) return false;
    for (const auto& c : pending_->cells)
        if (inspect_world(c.x,c.y)!=c.payload || world_->transient_obstacle_at(c.x,c.y) ||
            world_->object_shard_mutations_->witness(c.x,c.y)!=c.witness) return false;
    return true;
}
Outcome Coordinator::commit_prepared() {
    if (!validate_prepared()) return Outcome::Stale;
    auto* shard=registry_.find(pending_->shard);
    if (!shard || shard->phase()!=Phase::PhysicsReserved) return Outcome::Stale;
    if (pending_->source_parent.id) {
        auto* parent=registry_.find(pending_->source_parent);auto* physical=body(pending_->source_parent);
        const auto old_mass=parent->geometry().mass;
        if (ingress_fences_.size()+pending_->fragment_fences.size()>ingress_fences_.capacity())
            return Outcome::Capacity;
        const auto transferred=registry_.commit_fragment(pending_->source_parent,pending_->shard,pending_->captured_tick);
        if (transferred!=Outcome::Accepted) {
            if (transferred==Outcome::Quarantined) quarantined_=true;
            return transferred;
        }
        preserve_material_point_velocity(pending_->source_parent,old_mass);
        physical->geometry_pending=true;physical->geometry_pending_tick=pending_->captured_tick;
        physical->geometry_pending_ns=now_ns();
        physical->fragment_deferred=false;
        ingress_fences_.insert(ingress_fences_.end(),pending_->fragment_fences.begin(),pending_->fragment_fences.end());
        const auto offset_x=shard->bounds().x-parent->bounds().x,offset_y=shard->bounds().y-parent->bounds().y;
        for (auto& exposure:exposures_) {
            if (exposure.shard!=pending_->source_parent || exposure.consumed) continue;
            const auto x=static_cast<std::int64_t>(exposure.cell%parent->bounds().width)-offset_x;
            const auto y=static_cast<std::int64_t>(exposure.cell/parent->bounds().width)-offset_y;
            if (x<0 || y<0 || x>=shard->bounds().width || y>=shard->bounds().height) continue;
            const auto local=static_cast<std::uint32_t>(y*shard->bounds().width+x);
            if (!shard->occupied(local) || shard->schedule(local).incarnation!=exposure.incarnation) continue;
            exposure.shard=pending_->shard;exposure.cell=local;
            exposure.geometry_revision=shard->geometry().revision;exposure.pose_serial=0;
        }
        ++metrics_.fragments;
        // No World debit, terrain mutation or chemistry clock occurs here.
        return Outcome::Accepted;
    }
    // Destination, temperatures, discovery, geometry and control receipt slots
    // are already reserved. Only admitted non-Water tuples cross this boundary.
    // No callbacks or physics step can observe the bounded exclusive commit.
    if (registry_.commit(pending_->shard)!=Outcome::Accepted) return Outcome::Stale;
    try {
        for (const auto& c : pending_->cells) {
            if (!world_->write_cell(c.x,c.y,Material::Empty,0,0,nullptr,false))
                throw std::logic_error("prepared World debit did not commit");
        }
    } catch (...) {
        // Exclusive commit has no callback or external observer. If an
        // unexpected writer failure nevertheless occurs, retain only debited
        // cells in this quarantined owner; undebited cells still belong to World.
        // Never blindly restore source cells or label partial progress a refusal.
        component_.clear();
        for (const auto& c:pending_->cells) {
            if (world_->stored_material(c.x,c.y)==Material::Empty) {
                ++accounting_.promoted[static_cast<std::uint8_t>(c.payload.material)];
                component_.push_back(c.local);
            }
        }
        (void)registry_.quarantine_partial_commit(pending_->shard,component_);quarantined_=true;
        return Outcome::Quarantined;
    }
    for (const auto& c : pending_->cells) ++accounting_.promoted[static_cast<std::uint8_t>(c.payload.material)];
    ++metrics_.promotions;
    rebuild_terrain();
    pending_->terrain.clear();
    const auto bounds=config_.world_bounds;
    const auto columns=(bounds.width+63U)/64U;
    for (const auto& c : pending_->cells) {
        const auto tile=static_cast<std::uint32_t>((c.y-bounds.y)/64)*columns+static_cast<std::uint32_t>((c.x-bounds.x)/64);
        if (std::find_if(pending_->terrain.begin(),pending_->terrain.end(),[&](const auto& t){return t.id==tile;})==pending_->terrain.end())
            pending_->terrain.push_back(terrain_[tile].identity);
    }
    std::sort(pending_->terrain.begin(),pending_->terrain.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    return Outcome::Accepted;
}

const Coordinator::Receipt* Coordinator::prior(std::uint64_t sequence) const noexcept {
    for (const auto& receipt : receipts_) if (receipt.sequence==sequence && sequence!=0) return &receipt;
    return nullptr;
}
Result Coordinator::remember(Result result,std::uint64_t fingerprint) noexcept {
    auto& slot=receipts_[result.transaction % receipts_.size()];
    retired_transaction_=std::max(retired_transaction_,slot.sequence);
    slot={result.transaction,fingerprint,result,{}};
    return finish(result);
}
Result Coordinator::quarantine(Handle h,const char* detail) noexcept {
    if (h.id) (void)registry_.quarantine(h);
    quarantined_=true;
    return finish({Outcome::Quarantined,h,pending_->transaction,Phase::Quarantined,detail});
}

Result Coordinator::acknowledge(const Acknowledgement& a) {
    if (static_cast<unsigned>(a.kind)>static_cast<unsigned>(AckKind::ReabsorptionComplete))
        return finish({Outcome::Invalid,a.shard,a.transaction,Phase::Empty,"unknown acknowledgement kind"});
    if (a.kind==AckKind::ReabsorptionFrozen || a.kind==AckKind::ReabsorptionComplete)
        return acknowledge_reabsorption(a);
    if (pending_->present && pending_->reabsorption && pending_->shard==a.shard)
        return finish({Outcome::Fenced,a.shard,a.transaction,Phase::Active,"reabsorption requires its exact physical handoff receipts"});
    const auto fingerprint=ack_fingerprint(a);
    if (a.shard.session!=session_) return finish({Outcome::Retired,a.shard,a.transaction});
    auto* shard=registry_.find(a.shard); auto* b=body(a.shard);
    if (!shard || !b) return finish({Outcome::Stale,a.shard,a.transaction});
    const auto& geometry=shard->geometry();
    if (a.kind==AckKind::GeometryInstalled) {
        if (!shard->chemistry_allowed() || !b->has_body || a.body_generation!=b->body_generation || a.geometry_revision!=geometry.revision ||
            a.mask_digest!=geometry.mask_digest || a.shape_digest!=geometry.shape_digest)
            return finish({Outcome::Stale,a.shard,a.transaction,shard->phase(),"stale geometry receipt"});
        const auto result=shard->acknowledge_geometry(a.geometry_revision,a.mask_digest,a.shape_digest);
        if (result==Outcome::Accepted) {
            if (rebuild_mask(false)!=Outcome::Accepted) return quarantine(a.shard,"new geometry mask application failed");
            b->geometry_pending=false; b->pose.geometry_revision=geometry.revision;
            if (b->geometry_pending_ns) metrics_.maximum_geometry_wait_ns=std::max(metrics_.maximum_geometry_wait_ns,now_ns()-b->geometry_pending_ns);
            metrics_.maximum_geometry_age=std::max(metrics_.maximum_geometry_age,world_->completed_tick_index()-b->geometry_pending_tick);
            b->geometry_pending_ns=0;
        }
        return finish({result,a.shard,a.transaction,shard->phase()});
    }
    if (a.kind==AckKind::BodyRetired) {
        if (shard->phase()!=Phase::Draining || shard->counts().structural || a.body_generation!=b->body_generation ||
            a.geometry_revision!=geometry.revision || a.mask_digest!=geometry.mask_digest || a.shape_digest!=geometry.shape_digest)
            return finish({Outcome::Stale,a.shard});
        b->has_body=false; b->geometry_pending=false;
        if (b->geometry_pending_ns) metrics_.maximum_geometry_wait_ns=std::max(metrics_.maximum_geometry_wait_ns,now_ns()-b->geometry_pending_ns);
        b->geometry_pending_ns=0;
        if (rebuild_mask(false)!=Outcome::Accepted) return quarantine(a.shard,"retired-body occupancy removal failed");
        return finish({Outcome::Accepted,a.shard,a.transaction,shard->phase()});
    }
    const auto kind=static_cast<std::size_t>(a.kind);
    if (!pending_->present || pending_->transaction!=a.transaction || pending_->shard!=a.shard) {
        if (const auto* done=prior(a.transaction); done && kind<3 && done->acknowledgements[kind]==fingerprint) return done->result;
        return finish({a.transaction<next_transaction_ ? Outcome::Expired : Outcome::Stale,a.shard,a.transaction});
    }
    if (pending_->acknowledgements[kind]) {
        if (pending_->acknowledgements[kind]!=fingerprint) return finish({Outcome::Stale,a.shard,a.transaction});
        return finish({Outcome::Accepted,a.shard,a.transaction,shard->phase(),"duplicate acknowledgement"});
    }
    if (a.body_generation!=b->body_generation || a.payload_digest!=pending_->payload_digest ||
        a.geometry_revision!=geometry.revision || a.mask_digest!=geometry.mask_digest || a.shape_digest!=geometry.shape_digest)
        return finish({Outcome::Stale,a.shard,a.transaction,shard->phase(),"receipt identity mismatch"});
    if (a.kind==AckKind::PhysicsReserved) {
        if (shard->phase()!=Phase::Prepared || !validate_prepared()) return finish({Outcome::Stale,a.shard,a.transaction});
        auto result=registry_.reserve_physics(a.shard);
        if (result==Outcome::Accepted) result=commit_prepared();
        if (result!=Outcome::Accepted) return finish({result,a.shard,a.transaction,shard->phase()});
        b->has_body=true;
    } else if (a.kind==AckKind::TerrainInstalled) {
        if (shard->phase()!=Phase::CommittedInactive || a.terrain.size()!=pending_->terrain.size())
            return finish({Outcome::Stale,a.shard,a.transaction});
        for (std::size_t i=0;i<a.terrain.size();++i)
            if (a.terrain[i]!=pending_->terrain[i]) return finish({Outcome::Stale,a.shard,a.transaction,shard->phase(),"terrain was not installed exactly"});
        (void)registry_.advance(a.shard,Phase::CommittedInactive,Phase::TerrainInstalled);
        const auto result=rebuild_mask(false);
        if (result!=Outcome::Accepted) return quarantine(a.shard,"postcommit mask application refused; inventory retained");
        (void)registry_.advance(a.shard,Phase::TerrainInstalled,Phase::MaskApplied);
        (void)registry_.advance(a.shard,Phase::MaskApplied,Phase::ReadyToActivate);
    } else if (a.kind==AckKind::BodyActivated) {
        if (shard->phase()!=Phase::ReadyToActivate) return finish({Outcome::Stale,a.shard,a.transaction});
        if (pending_->source_parent.id) {
            const auto* parent=registry_.find(pending_->source_parent);
            if (!parent || parent->applied_physics_revision()!=parent->geometry().revision)
                return finish({Outcome::Fenced,a.shard,a.transaction,shard->phase(),
                    "fragment activation requires exact parent geometry installation"});
        }
        if (shard->acknowledge_geometry(geometry.revision,geometry.mask_digest,geometry.shape_digest)!=Outcome::Accepted ||
            registry_.advance(a.shard,Phase::ReadyToActivate,Phase::Active)!=Outcome::Accepted)
            return quarantine(a.shard,"activation storage identity failed");
        pending_->acknowledgements[kind]=fingerprint;
        const auto result=remember({Outcome::Accepted,a.shard,a.transaction,Phase::Active},fingerprint);
        receipts_[a.transaction % receipts_.size()].acknowledgements=pending_->acknowledgements;
        pending_->present=false;
        metrics_.maximum_pause_ns=std::max(metrics_.maximum_pause_ns,now_ns()-pause_started_ns_);
        return result;
    }
    pending_->acknowledgements[kind]=fingerprint;
    return finish({Outcome::Accepted,a.shard,a.transaction,shard->phase()});
}

Result Coordinator::cancel(std::uint64_t transaction) {
    if (const auto* done=prior(transaction);done && !(pending_->present && pending_->reabsorption && pending_->transaction==transaction))
        return done->result;
    if (!pending_->present || transaction!=pending_->transaction)
        return finish({transaction<next_transaction_ ? Outcome::Expired : Outcome::Stale,{},transaction});
    const auto h=pending_->shard;
    if (pending_->reabsorption) {
        if (pending_->world_committed) return finish({Outcome::Fenced,h,transaction,Phase::Draining,
            "World handoff already committed; complete physical retirement"});
        pending_->present=false;
        return remember({Outcome::Cancelled,h,transaction,Phase::Active,
            "reabsorption cancelled before physical freeze; inventory remains with body"},pending_->action_fingerprint);
    }
    auto* shard=registry_.find(h);
    if (shard->owns_inventory()) return quarantine(h,"cancel after commit retains inactive shard inventory");
    const auto result=registry_.cancel_precommit(h);
    if (auto* b=body(h)) *b={};
    pending_->present=false;
    return remember({result==Outcome::Accepted ? Outcome::Cancelled : result,h,transaction,Phase::Retired},0);
}

void Coordinator::rebuild_terrain() {
    const auto source_revision=world_->hard_surface_revision();
    if (terrain_source_revision_==source_revision) return;
    const auto start=now_ns(); const auto bounds=config_.world_bounds;
    const auto columns=(bounds.width+63U)/64U;
    for (std::size_t index=0;index<terrain_.size();++index) {
        auto& tile=terrain_[index]; tile.x=bounds.x+static_cast<std::int64_t>(index%columns)*64;
        tile.y=bounds.y+static_cast<std::int64_t>(index/columns)*64;
        std::uint64_t digest=1469598103934665603ULL;
        for (unsigned y=0;y<64;++y) for (unsigned x=0;x<64;++x) {
            const bool solid=resident(tile.x+x,tile.y+y) && MaterialRules::is_hard_surface(world_->stored_material(tile.x+x,tile.y+y));
            terrain_scratch_[y*64+x]=solid ? 1U : 0U; hash_word(digest,solid);
        }
        if (tile.identity.revision && tile.identity.digest==digest) continue;
        tile.identity={static_cast<std::uint32_t>(index),tile.identity.revision+1,digest};
        tile.rectangles.clear();
        for (std::uint16_t y=0;y<64;++y) for (std::uint16_t x=0;x<64;) {
            if (!terrain_scratch_[y*64+x]) {++x;continue;}
            const auto first=x;
            while (x<64 && terrain_scratch_[y*64+x]) ++x;
            const auto width=static_cast<std::uint16_t>(x-first);
            bool joined=false;
            for (auto& rect:tile.rectangles) if (rect.x==first && rect.width==width && rect.y+rect.height==y) {
                ++rect.height;joined=true;break;
            }
            if (!joined) tile.rectangles.push_back({first,y,width,1});
        }
    }
    metrics_.terrain_ns+=now_ns()-start;
    terrain_source_revision_=source_revision;
}

// One derived World mask is shared by all bodies. Contact history is captured
// before conservative relocation, so a brief Water touch cannot be erased by
// the mechanical overlap solver before the next combustion opportunity.
Outcome Coordinator::rebuild_mask(bool capture_contact) {
    const auto start=now_ns(); const auto wb=config_.world_bounds;
    if (attached_) {
        // Includes a previously refused partial raster: every nonzero entry
        // acquires its index before the write, so retry cannot retain ghosts.
        for (const auto at:proposed_indices_) proposed_mask_[at]=0;
        proposed_indices_.clear();
    } else std::fill(proposed_mask_.begin(),proposed_mask_.end(),0);
    for (std::size_t slot=0;slot<bodies_.size();++slot) {
        const auto& b=bodies_[slot]; const auto* shard=registry_.find(b.shard);
        if (!shard || !shard->owns_inventory() || !b.has_body) continue;
        if (pending_->present && pending_->reabsorption && pending_->reabsorption_mask_removed && pending_->shard==b.shard)
            continue;
        const auto sb=shard->bounds(); const auto c=std::cos(b.pose.rotation),s=std::sin(b.pose.rotation);
        for (std::size_t at=0;at<shard->area();++at) if (shard->structural(at) || shard->role(at)==Role::Cargo) {
            const auto lx=static_cast<double>(at%sb.width)+.5,ly=static_cast<double>(at/sb.width)+.5;
            const auto cx=b.pose.x+c*lx-s*ly,cy=b.pose.y+s*lx+c*ly;
            const auto half=(std::abs(c)+std::abs(s))*.5;
            const auto minx=static_cast<std::int64_t>(std::floor(cx-half));
            const auto maxx=static_cast<std::int64_t>(std::floor(cx+half));
            const auto miny=static_cast<std::int64_t>(std::floor(cy-half));
            const auto maxy=static_cast<std::int64_t>(std::floor(cy+half));
            for (auto y=miny;y<=maxy;++y) for (auto x=minx;x<=maxx;++x) {
                const auto dx=static_cast<double>(x)+.5-cx,dy=static_cast<double>(y)+.5-cy;
                // SAT for rotated unit square against an axis-aligned cell.
                if (std::abs(dx)>=half+.5-1e-9 || std::abs(dy)>=half+.5-1e-9 ||
                    std::abs(dx*c+dy*s)>=half+.5-1e-9 || std::abs(-dx*s+dy*c)>=half+.5-1e-9) continue;
                if (!resident(x,y)) return Outcome::NotResident;
                const auto wi=static_cast<std::size_t>(y-wb.y)*wb.width+static_cast<std::size_t>(x-wb.x);
                const auto id=static_cast<std::uint16_t>(slot+1);
                if (attached_ && !proposed_mask_[wi]) {
                    if (proposed_indices_.size()==proposed_indices_.capacity()) return Outcome::Capacity;
                    proposed_indices_.push_back(static_cast<std::uint32_t>(wi));
                }
                // Two physically disjoint subcell shapes can cover the same
                // World carrier. This derived mask is their union, not an
                // inventory arbitration rule or an additional material owner.
                if (!proposed_mask_[wi] || id<proposed_mask_[wi]) proposed_mask_[wi]=id;
            }
        }
    }
    // Preserve exactly the old row-major relocation priority and the native
    // composer's ordered-input contract, independently of body/shape order.
    if (attached_) std::sort(proposed_indices_.begin(),proposed_indices_.end());
    const auto exposure_start=exposures_.size();
    const auto accepted_start=accounting_.accepted_exposures;
    ingress_fences_backup_.assign(ingress_fences_.begin(),ingress_fences_.end());
    const auto rollback_contact=[&]() {
        for (std::size_t at=exposure_start;at<exposures_.size();++at) {
            const auto& e=exposures_[at];
            if (e.kind==ExposureKind::FireIgnition) fire_opportunity(e.source_x,e.source_y)&=0x7fffffffU;
        }
        exposures_.resize(exposure_start);accounting_.accepted_exposures=accepted_start;
        ingress_fences_.assign(ingress_fences_backup_.begin(),ingress_fences_backup_.end());
    };
    if (capture_contact) for (const auto& b:bodies_) {
        auto* shard=registry_.find(b.shard);
        if (!shard || !b.has_body || !shard->chemistry_allowed()) continue;
        auto result=capture_fire_ignition(*shard,b);
        if (result==Outcome::Accepted) result=capture_water(*shard,b);
        if (result!=Outcome::Accepted) {
            rollback_contact();
            return result;
        }
    }
    // The next semantic tick may supply an already-applied zero-length pose.
    // Preserve illegal aperture-entry history from every real motion segment
    // before relocation, so that zero-length sample cannot authorize a grain
    // that crossed solid material. Ownership/mass transfer still waits for
    // semantic ingress, where exact current inventory is validated again.
    if (capture_contact) {
        automatic_ingress(false);
        if (quarantined_) return Outcome::Quarantined;
    }
    const auto result=reconcile_overlap();
    if (result!=Outcome::Accepted && result!=Outcome::Quarantined) {
        rollback_contact();
    }
    metrics_.occupancy_ns+=now_ns()-start;
    return result;
}

Outcome Coordinator::reconcile_overlap() {
    ScopedTime timing{metrics_.relocation_ns};
    const auto wb=config_.world_bounds;
    World::TransientCompositionReceipt composed;
    const auto maximum_radius=attached_ ? kAttachedRelocationRadius : kStandaloneRelocationRadius;
    std::uint32_t probes=0;
    relocations_.clear();std::fill(reserved_destinations_.begin(),reserved_destinations_.end(),0);
    std::fill(ingress_exclusion_.begin(),ingress_exclusion_.end(),0);
    // Mechanical displacement is not a lodging authority. Never move World
    // material into a pocket's capture column: doing so could manufacture an
    // "already inside" witness after an otherwise correctly refused entry.
    // This is one shared bounded Lab field, including temporarily full ports.
    for (const auto& b:bodies_) {
        const auto* shard=registry_.find(b.shard);
        if (!shard || !shard->owns_inventory() || !b.has_body) continue;
        const auto bounds=shard->bounds();const auto frame=contact::frame(contact_pose(b.pose));
        for (std::size_t at=0;at<shard->area();++at) {
            const auto opening=contact::pocket_opening(*shard,at,false);
            if (opening.outcome!=Outcome::Accepted || at%bounds.width!=opening.min_x) continue;
            const auto origin=contact::to_world(frame,{static_cast<double>(opening.min_x),0});
            const auto port_frame=contact::frame({origin.x,origin.y,b.pose.rotation});
            const auto candidates=contact::grid_candidates(contact::transformed_bounds(port_frame,
                static_cast<std::uint16_t>(opening.max_x-opening.min_x),static_cast<std::uint16_t>(opening.row+1)));
            for (auto y=candidates.min_y;y<=candidates.max_y;++y) for (auto x=candidates.min_x;x<=candidates.max_x;++x) {
                if (!resident(x,y)) continue;
                const auto local=contact::to_local(frame,{static_cast<double>(x)+.5,static_cast<double>(y)+.5});
                if (local.x>=opening.min_x && local.x<opening.max_x && local.y>=0 && local.y<opening.row+1.0)
                    ingress_exclusion_[static_cast<std::size_t>(y-wb.y)*wb.width+static_cast<std::size_t>(x-wb.x)]=1;
            }
        }
    }
    // Reserve every destination before moving the first World inventory cell.
    // Static terrain is Rapier's responsibility; movable material is displaced
    // by its canonical World move, preserving all World-owned solver sidecars.
    const auto mask_entries=attached_ ? proposed_indices_.size() : proposed_mask_.size();
    for (std::size_t entry=0;entry<mask_entries;++entry) {
        const auto at=attached_ ? static_cast<std::size_t>(proposed_indices_[entry]) : entry;
        if (!proposed_mask_[at]) continue;
        const auto x=wb.x+static_cast<std::int64_t>(at%wb.width),y=wb.y+static_cast<std::int64_t>(at/wb.width);
        const auto payload=inspect_world(x,y);
        if (payload.material==Material::Empty || MaterialRules::is_hard_surface(payload.material)) continue;
        if (relocations_.size()==relocations_.capacity()) return Outcome::Capacity;
        bool found=false;
        for (int radius=1;radius<=maximum_radius && !found;++radius)
            for (int dy=-radius;dy<=radius && !found;++dy)
                // Same row-major ring order as the original solver, without
                // revisiting the interior square at every larger radius.
                for (int dx=-radius;dx<=radius && !found;dx+=(std::abs(dy)==radius ? 1 : 2*radius)) {
                    if (attached_ && probes==config_.relocation_probe_budget) {
                        ++metrics_.relocation_probe_limit_hits;
                        return Outcome::Capacity;
                    }
                    ++probes;++metrics_.relocation_probes;
                    if (!resident(x+dx,y+dy)) continue;
                    const auto dest=static_cast<std::size_t>(y+dy-wb.y)*wb.width+static_cast<std::size_t>(x+dx-wb.x);
                    if (proposed_mask_[dest] || reserved_destinations_[dest] || ingress_exclusion_[dest] ||
                        (attached_ && immutable_occupied(x+dx,y+dy)) ||
                        world_->stored_material(x+dx,y+dy)!=Material::Empty) continue;
                    reserved_destinations_[dest]=1;relocations_.push_back({x,y,x+dx,y+dy,payload});found=true;
                }
        if (!found) return Outcome::DestinationUnavailable;
    }
    if (attached_) {
        shard_occupancy_.clear();
        std::uint64_t overlaps=0;
        for (const auto at:proposed_indices_) {
            const auto x=wb.x+static_cast<std::int64_t>(at%wb.width);
            const auto y=wb.y+static_cast<std::int64_t>(at/wb.width);
            // Both disjoint rigid surfaces can conservatively cover one cell.
            // The derived collision union stays occupied; GCR receives that
            // cell's contact ID. This never changes either material inventory.
            if (immutable_occupied(x,y)) {++overlaps;continue;}
            if (shard_occupancy_.size() >= shard_occupancy_.capacity()) return Outcome::Capacity;
            shard_occupancy_.push_back({
                wb.x + static_cast<std::int64_t>(at % wb.width),
                wb.y + static_cast<std::int64_t>(at / wb.width),
                static_cast<std::uint16_t>(kFirstMutableBodyId + proposed_mask_[at] - 1U)});
        }
        // One native ownership transaction, including the GCR domain. A GCR
        // proxy and mutable shard cannot silently claim the same cell.
        composed = world_->compose_transient_obstacles(immutable_occupancy_,
            shard_occupancy_, kFirstMutableBodyId);
        if (composed.outcome != World::TransientCompositionOutcome::Applied ||
            !world_->transient_composition_current(composed))
            return composed.outcome == World::TransientCompositionOutcome::Quarantined
                ? Outcome::Quarantined : Outcome::DestinationUnavailable;
        metrics_.mask_cells += shard_occupancy_.size();
        metrics_.composed_overlap_cells += overlaps;
    } else {
        world_->clear_transient_obstacles();
        for (std::size_t at=0;at<proposed_mask_.size();++at) if (proposed_mask_[at]) {
            const auto x=wb.x+static_cast<std::int64_t>(at%wb.width),y=wb.y+static_cast<std::int64_t>(at/wb.width);
            if (!world_->set_transient_obstacle(x,y,proposed_mask_[at])) return Outcome::Quarantined;
            ++metrics_.mask_cells;
        }
    }
    try {
        for (const auto& move:relocations_) {
            const auto fire_token=move.payload.material==Material::Fire ? fire_opportunity(move.from_x,move.from_y) : 0U;
            if (inspect_world(move.from_x,move.from_y)!=move.payload ||
                !world_->relocate_stored_cell(move.from_x,move.from_y,move.to_x,move.to_y) ||
                inspect_world(move.to_x,move.to_y)!=move.payload) return Outcome::Quarantined;
            if (move.payload.material==Material::Fire) {
                // Mechanical movement preserves both cadence anchor and claim.
                // The next real World tick starts a new opportunity inventory.
                fire_opportunity(move.to_x,move.to_y)=fire_token;
                fire_opportunity(move.from_x,move.from_y)=0;
            }
        }
    } catch (...) {return Outcome::Quarantined;}
    // A search or refused preflight is not a fluid interaction witness. These
    // counters publish only completely committed native carrier relocations.
    metrics_.relocated_cells+=relocations_.size();
    for (const auto& move:relocations_) {
        metrics_.relocated_water_cells+=move.payload.material==Material::Water ? 1U : 0U;
        metrics_.relocated_sand_cells+=move.payload.material==Material::Sand ? 1U : 0U;
    }
    if (attached_) {
        accepted_composition_=composed;
        composed_material_revision_=world_material_revision();
    }
    return Outcome::Accepted;
}

Outcome Coordinator::apply_poses(std::span<const PoseSample> poses) {
    std::size_t required=0;
    for (const auto& b:bodies_) if (b.has_body) ++required;
    if (poses.size()!=required) return Outcome::Stale;
    for (const auto& p:poses) {
        auto* b=body(p.shard); const auto* shard=registry_.find(p.shard);
        if (!b || !shard || !b->has_body || p.body_generation!=b->body_generation ||
            p.geometry_revision!=shard->applied_physics_revision() || p.pose_serial<=b->pose.pose_serial ||
            !std::isfinite(p.x) || !std::isfinite(p.y) || !std::isfinite(p.rotation) ||
            !std::isfinite(p.vx) || !std::isfinite(p.vy) || !std::isfinite(p.angular_velocity)) return Outcome::Stale;
        const auto domain=contact::motion_domain(*shard);
        const auto envelope=contact::motion_envelope(domain,
            config_.max_translation_per_step,config_.max_rotation_per_step);
        if (contact::plan_sweep(contact_pose(b->pose),contact_pose(p),domain,envelope).outcome!=Outcome::Accepted)
            return Outcome::Unsupported;
        for (const auto& other:poses) if (&other!=&p && other.shard==p.shard) return Outcome::Invalid;
    }
    std::copy(bodies_.begin(),bodies_.end(),body_backup_.begin());
    for (const auto& p:poses) {auto* b=body(p.shard);b->previous_pose=b->pose;b->pose=p;}
    const auto result=rebuild_mask(true);
    if (result!=Outcome::Accepted && result!=Outcome::Quarantined)
        std::copy(body_backup_.begin(),body_backup_.end(),bodies_.begin());
    return result;
}

Result Coordinator::accept_motion(std::span<const PoseSample> poses) {
    if (quarantined_) return finish({Outcome::Quarantined});
    if (paused()) return finish({Outcome::Fenced, {}, 0, Phase::Suspended,
        "motion awaits installed geometry or promotion acknowledgement"});
    const auto limit_hits=metrics_.relocation_probe_limit_hits;
    const auto accepted = apply_poses(poses);
    if (accepted == Outcome::Quarantined)
        return quarantine({}, "partial substep occupancy application; clocks held");
    if (accepted != Outcome::Accepted) return finish({accepted, {}, 0, Phase::Suspended,
        metrics_.relocation_probe_limit_hits!=limit_hits
            ? "World displacement candidate-work budget exhausted before material mutation"
            : "actual motion segment refused; no semantic tick advanced"});
    return finish({Outcome::Accepted, {}, 0, Phase::Active,
        "motion segment occupancy and contact applied; semantic tick unchanged"});
}

Result Coordinator::begin_owner_world_tick() {
    if (!attached_ || quarantined_ || paused() || world_->has_failed() ||
        world_->is_tick_in_progress() || owner_tick_admitted_ ||
        world_->completed_tick_index() != last_owner_tick_)
        return finish({Outcome::Fenced, {}, 0, Phase::Suspended,
            "only an idle exact same-World owner may authorize its next native tick"});
    last_owner_population_ = world_->quantity_ledger().material_cells;
    // The normal material tick consumes pre-existing Fire opportunity claims
    // exactly once. The Coordinator does NOT call World::tick() here.
    world_->object_shard_mutations_->set_external_fire_claims(
        fire_opportunities_, fire_opportunity_tick_);
    owner_tick_admitted_ = true;
    return finish({});
}

Result Coordinator::after_owner_world_tick(std::span<const PoseSample> poses) {
    if (!world_) return finish({Outcome::Retired,{},0,Phase::Retired,"World attachment retired"});
    if (attached_ && owner_tick_admitted_)
        world_->object_shard_mutations_->set_external_fire_claims({}, 0);
    if (!attached_) return finish({Outcome::Unsupported, {}, 0, Phase::Suspended,
        "only the owner-local attachment accepts external World ticks"});
    if (quarantined_ || world_->has_failed() || world_->is_tick_in_progress())
        return finish({Outcome::Quarantined});
    if (!owner_tick_admitted_ || world_->completed_tick_index() != last_owner_tick_ + 1)
        return finish({Outcome::Stale, {}, 0, Phase::Suspended,
            "an exact single native owner tick is required"});
    if (paused()) return finish({Outcome::Fenced, {}, 0, Phase::Suspended,
        "physics/geometry owner barrier cannot be bypassed by a World tick"});
    // Actual physics segments have already been applied through accept_motion.
    // An empty batch does NOT manufacture a zero-motion receipt for active RIDs.
    const auto accepted = poses.empty() && std::any_of(bodies_.begin(), bodies_.end(),
        [](const auto& b) { return b.has_body; }) ? Outcome::Accepted : apply_poses(poses);
    if (accepted != Outcome::Accepted)
        return accepted == Outcome::Quarantined
            ? quarantine({}, "owner post-tick motion occupancy partial")
            : finish({accepted, {}, 0, Phase::Suspended});
    // No second tick occurs here; world material laws (including Water)
    // executed once in CyberNativeCellWorld::simulation_tick().
    const auto current = world_->quantity_ledger().material_cells;
    for (std::size_t m = 1; m < kQuantityMaterialSlots; ++m)
        accounting_.world_tick_delta[m] += static_cast<std::int64_t>(current[m]) -
            static_cast<std::int64_t>(last_owner_population_[m]);
    last_owner_population_ = current;
    last_owner_tick_ = world_->completed_tick_index();
    owner_tick_admitted_ = false;
    ++metrics_.steps;
    try {
        automatic_ingress();
        if (quarantined_) return last_result_;
        advance_chemistry();
        advance_products_and_exchange();
        rebuild_terrain();
        for (const auto& shard : registry_.shards())
            if (shard.owns_inventory() && shard.geometry_dirty()) {
                const auto previous_mass=shard.geometry().mass;
                const auto result = registry_.rebuild_geometry(shard.handle(), last_owner_tick_);
                if (result != Outcome::Accepted) return quarantine(shard.handle(),
                    "owner geometry rebuild capacity; inventory retained");
                preserve_material_point_velocity(shard.handle(),previous_mass);
                if (auto* b = body(shard.handle())) {
                    b->geometry_pending = b->has_body;
                    b->geometry_pending_tick = last_owner_tick_;
                    b->geometry_pending_ns = b->geometry_pending ? now_ns() : 0;
                }
            }
    } catch (...) {
        return quarantine({}, "owner post-tick shard service failed");
    }
    return finish({});
}

Result Coordinator::set_immutable_occupancy(
    std::span<const World::TransientCompositionCell> cells) {
    if (!attached_) return finish({Outcome::Unsupported});
    if (paused() || world_->has_failed() || world_->is_tick_in_progress())
        return finish({Outcome::Fenced});
    if (cells.size() > immutable_occupancy_.capacity())
        return finish({Outcome::Capacity});
    for (std::size_t i=0;i<cells.size();++i) {
        const auto& cell=cells[i];
        if (cell.body_id==0 || cell.body_id>=kFirstMutableBodyId ||
            (i && std::pair{cells[i-1].y,cells[i-1].x}>=std::pair{cell.y,cell.x}))
            return finish({Outcome::Invalid,{},0,Phase::Suspended,
                "immutable roster must be ordered and outside the mutable ID range"});
    }
    // Every admitted pose/geometry change reaches rebuild_mask before its
    // owner barrier opens. The actual native receipt additionally expires on
    // World tick, clear/set, retirement and replacement. A World mutation
    // witness prevents an unchanged roster from hiding new material overlap.
    if (!world_->object_shard_mutations_->exhausted() &&
        composed_material_revision_==world_material_revision() &&
        world_->transient_composition_current(accepted_composition_) &&
        cells.size()==immutable_occupancy_.size() &&
        std::equal(cells.begin(),cells.end(),immutable_occupancy_.begin(),[](const auto& a,const auto& b) {
            return a.x==b.x && a.y==b.y && a.body_id==b.body_id;
        })) {
        ++metrics_.composed_reuses;
        return finish({});
    }
    immutable_occupancy_backup_.assign(immutable_occupancy_.begin(), immutable_occupancy_.end());
    immutable_occupancy_.assign(cells.begin(), cells.end());
    // Workbench supplies sorted values with body IDs strictly below the
    // reserved mutable range. The World composer checks all coordinates,
    // collisions, capacity and receipt identity without modifying on refusal.
    const auto verdict = rebuild_mask(false);
    if (verdict != Outcome::Accepted) {
        immutable_occupancy_.swap(immutable_occupancy_backup_);
        if (verdict==Outcome::Quarantined)
            return quarantine({}, "immutable/mutable occupancy partially applied");
        return finish({verdict,{},0,Phase::Suspended,
            "immutable/mutable occupancy refused before material mutation"});
    }
    return finish({});
}

bool Coordinator::can_detach() const noexcept {
    if (!attached_ || !world_ || pending_->present || owner_tick_admitted_ ||
        world_->is_tick_in_progress()) return false;
    for (const auto& shard:registry_.shards())
        if (shard.owns_inventory() || (shard.phase()!=Phase::Empty && shard.phase()!=Phase::Retired))
            return false;
    return true;
}

Result Coordinator::detach() {
    if (!can_detach()) return finish({Outcome::Fenced,{},0,Phase::Suspended,
        "live owned or prepared inventory requires explicit whole-World disposal"});
    const auto receipt=world_->compose_transient_obstacles(immutable_occupancy_,{},kFirstMutableBodyId);
    if (receipt.outcome!=World::TransientCompositionOutcome::Applied)
        return finish({Outcome::Fenced,{},0,Phase::Suspended,"retirement occupancy refused"});
    world_->object_shard_mutations_.reset();
    world_=nullptr;
    return finish({Outcome::Retired,{},0,Phase::Retired,"empty attachment retired; World inventory retained"});
}

Result Coordinator::step(std::span<const PoseSample> poses) {
    if (attached_) return finish({Outcome::Unsupported, {}, 0, Phase::Suspended,
        "ordinary World must be ticked only by CyberSimulationWorker"});
    if (quarantined_) return finish({Outcome::Quarantined});
    if (paused()) {
        ++metrics_.paused_calls;
        auto waiting=pending_->present ? pending_->shard : Handle{};
        if (!waiting.id) for (const auto& b:bodies_) if (b.geometry_pending) {waiting=b.shard;break;}
        if (++pause_calls_>config_.max_pause_calls) return quarantine(waiting,"bounded main-thread barrier deadline expired");
        return finish({Outcome::Fenced,waiting,pending_->present ? pending_->transaction : 0,Phase::Suspended,"awaiting installed-content/activation receipt"});
    }
    pause_calls_=0;
    const auto accepted=apply_poses(poses);
    if (accepted==Outcome::Quarantined) return quarantine({},"partial occupancy application; clocks held");
    if (accepted!=Outcome::Accepted) return finish({accepted,{},0,Phase::Suspended,"pose outside admitted source/motion envelope"});
    try {
        const auto before_ingress=metrics_.sand_ingested;
        automatic_ingress();
        if (quarantined_) return last_result_;
        if (metrics_.sand_ingested!=before_ingress && rebuild_mask(false)!=Outcome::Accepted)
            return quarantine({},"cargo mask application failed after exact transfer");
        const auto before_tick=world_->quantity_ledger();
        const auto start=now_ns();
        world_->object_shard_mutations_->set_external_fire_claims(fire_opportunities_,fire_opportunity_tick_);
        try { (void)world_->tick(); }
        catch (...) {world_->object_shard_mutations_->set_external_fire_claims({},0);throw;}
        world_->object_shard_mutations_->set_external_fire_claims({},0);
        metrics_.world_ns+=now_ns()-start;
        const auto after_tick=world_->quantity_ledger();
        for (std::size_t m=1;m<kQuantityMaterialSlots;++m)
            accounting_.world_tick_delta[m]+=static_cast<std::int64_t>(after_tick.material_cells[m])-
                static_cast<std::int64_t>(before_tick.material_cells[m]);
        ++metrics_.steps;
        advance_chemistry(); advance_products_and_exchange(); rebuild_terrain();
        if (quarantined_) return last_result_;
        for (const auto& shard:registry_.shards()) if (shard.owns_inventory() && shard.geometry_dirty()) {
            ScopedTime geometry_time{metrics_.geometry_ns};
            const auto previous_mass=shard.geometry().mass;
            const auto result=registry_.rebuild_geometry(shard.handle(),world_->completed_tick_index());
            if (result!=Outcome::Accepted) return quarantine(shard.handle(),"geometry capacity; exact inventory retained");
            preserve_material_point_velocity(shard.handle(),previous_mass);
            if (auto* b=body(shard.handle())) {
                b->geometry_pending=b->has_body;b->geometry_pending_tick=world_->completed_tick_index();
                b->geometry_pending_ns=b->geometry_pending ? now_ns() : 0;
            }
        }
    } catch (...) { return quarantine({},"unexpected native progress; whole owner quarantined"); }
    return finish({});
}

Outcome Coordinator::capture_water(Shard& shard,const BodyView& body) {
    if (world_->quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Water)]==0)
        return Outcome::Accepted;
    const auto started=now_ns();
    const auto bounds=shard.bounds();
    const auto domain=contact::motion_domain(shard);
    const auto envelope=contact::motion_envelope(domain,
        config_.max_translation_per_step,config_.max_rotation_per_step);
    const auto before=contact_pose(body.previous_pose),after=contact_pose(body.pose);
    const auto sweep=contact::plan_sweep(before,after,domain,envelope);
    if (sweep.outcome!=Outcome::Accepted) return sweep.outcome;
    for (std::size_t at=0;at<shard.area();++at) {
        const auto payload=shard.payload(at);
        if (payload.material!=Material::Wood) continue;
        const bool ignition_pending=std::any_of(exposures_.begin(),exposures_.end(),[&](const auto& e){
            return !e.consumed && e.kind==ExposureKind::FireIgnition && e.shard==shard.handle() && e.cell==at &&
                e.incarnation==shard.schedule(at).incarnation && e.expiry_tick>=world_->completed_tick_index()+1;
        });
        if (payload.state_b==0 && !ignition_pending) continue;
        const auto incarnation=shard.schedule(at).incarnation;
        if (std::any_of(exposures_.begin(),exposures_.end(),[&](const auto& e){return !e.consumed && e.kind==ExposureKind::WaterExtinction &&
            e.shard==shard.handle() && e.cell==at && e.incarnation==incarnation &&
            e.expiry_tick>=world_->completed_tick_index()+1;})) continue;
        bool touched=false;
        for (std::uint16_t sample=0;sample<sweep.samples && !touched;++sample) {
            const auto pose=contact::interpolated_pose(before,after,static_cast<double>(sample)/(sweep.samples-1),domain.reference);
            const auto frame=contact::frame(pose);++metrics_.sweep_samples;
            // Existing combustible Moore-neighbour semantics, with exact
            // transformed unit ports. Occupied structural neighbours cannot
            // provide contact through solid material. Include the swept cell
            // itself before overlap relocation moves its touching Water away.
            for (int dy=-1;dy<=1 && !touched;++dy) for (int dx=-1;dx<=1 && !touched;++dx) {
                const auto lx=static_cast<int>(at%bounds.width)+dx,ly=static_cast<int>(at/bounds.width)+dy;
                if (lx<0 || ly<0 || lx>=bounds.width || ly>=bounds.height) continue;
                const auto local=static_cast<std::size_t>(ly)*bounds.width+static_cast<std::size_t>(lx);
                if ((dx || dy) && shard.structural(local)) continue;
                const auto candidates=contact::grid_candidates(contact::transformed_cell_aabb(frame,
                    static_cast<std::uint16_t>(lx),static_cast<std::uint16_t>(ly)));
                if (!candidates.valid) return Outcome::Unsupported;
                for (auto y=candidates.min_y;y<=candidates.max_y && !touched;++y)
                    for (auto x=candidates.min_x;x<=candidates.max_x && !touched;++x)
                        if (resident(x,y) && world_->stored_material(x,y)==Material::Water &&
                            contact::cell_overlap(frame,static_cast<std::uint16_t>(lx),static_cast<std::uint16_t>(ly),x,y)) touched=true;
            }
        }
        if (!touched) continue;
        if (exposures_.size()==exposures_.capacity()) {++metrics_.exposure_overflows;return Outcome::Capacity;}
        if (next_exposure_==std::numeric_limits<std::uint64_t>::max()) return Outcome::GenerationExhausted;
        const auto tick=world_->completed_tick_index();
        exposures_.push_back({shard.handle(),static_cast<std::uint32_t>(at),incarnation,shard.geometry().revision,
            body.pose.pose_serial,tick+1,tick+2,next_exposure_++,false});
        ++accounting_.accepted_exposures;
    }
    metrics_.contact_ns+=now_ns()-started;
    return Outcome::Accepted;
}
#include "object_shard_fire.inc"

void Coordinator::advance_chemistry() {
    const auto start=now_ns();
    const auto tick=world_->completed_tick_index();
    namespace chemistry=material_lifecycle;
    const auto require=[](Outcome result) {
        if (result!=Outcome::Accepted) throw std::logic_error("reserved shard chemistry mutation refused");
    };
    for (const auto& view:registry_.shards()) {
        auto* shard=registry_.find(view.handle());
        if (!shard || !shard->chemistry_allowed()) continue;
        const auto bounds=shard->bounds();
        // A recorded external Fire opportunity affects this surviving Wood
        // incarnation once. It neither consumes nor copies World Fire. Waking
        // a dormant cell runs the existing combustion lane on this tick.
        for (auto& exposure:exposures_) {
            if (exposure.consumed || exposure.kind!=ExposureKind::FireIgnition ||
                exposure.shard!=shard->handle() || exposure.first_tick>tick || exposure.expiry_tick<tick ||
                exposure.cell>=shard->area() || exposure.incarnation!=shard->schedule(exposure.cell).incarnation)
                continue;
            exposure.consumed=true;
            ++accounting_.consumed_exposures;
            auto wood=shard->payload(exposure.cell);
            if (wood.material!=Material::Wood || !shard->structural(exposure.cell)) continue;
            wood.state_b=std::max<std::uint8_t>(wood.state_b,240);
            require(shard->set_cell(exposure.cell,wood,Role::Structural,tick));
            if (shard->schedule(exposure.cell).birth_tick<tick) require(shard->set_due(exposure.cell,tick));
            ++accounting_.external_ignitions;
        }
        const auto neighbor=[&](std::size_t at,chemistry::NeighbourOffset offset) -> std::size_t {
            const auto x=static_cast<int>(at%bounds.width)+offset.x;
            const auto y=static_cast<int>(at/bounds.width)+offset.y;
            return x>=0 && y>=0 && x<bounds.width && y<bounds.height
                ? static_cast<std::size_t>(y)*bounds.width+static_cast<std::size_t>(x) : shard->area();
        };
        for (std::size_t at=0;at<shard->area();++at) {
            if (!shard->occupied(at) || shard->schedule(at).birth_tick>=tick ||
                shard->schedule(at).next_due_tick>tick) continue;
            ++metrics_.chemistry_cells;
            auto before=shard->payload(at);
            const auto x=bounds.x+static_cast<std::int64_t>(at%bounds.width);
            const auto y=bounds.y+static_cast<std::int64_t>(at/bounds.width);
            // Reuse the canonical oriented resolver. None of the v1 admitted
            // local material pairs consumes another cell. A future catalogue
            // change must receive an explicit transactional adapter first.
            if (chemistry::lane_due(tick,x,y,4,190) && MaterialRules::has_pair_reactions(before.material)) {
                const auto first=chemistry::random(tick,x,y,200);
                for (std::size_t n=0;n<chemistry::kNeighbours.size();++n) {
                    const auto target=neighbor(at,chemistry::kNeighbours[(first+n)%8]);
                    if (target<shard->area() && MaterialRules::pair_reaction(before.material,
                        shard->payload(target).material,chemistry::random(tick,x,y,201)))
                        throw std::logic_error("unadvertised local consuming reaction requires adapter");
                }
            }
            chemistry::Transition transition{before.material,before.state_a,before.state_b};
            std::uint64_t period=1,stream=0;
            bool expiry=false;
            if (before.material==Material::Wood) {
                if (!before.state_b) {require(shard->set_due(at,std::numeric_limits<std::uint64_t>::max()));continue;}
                period=chemistry::kCombustionPeriod;stream=chemistry::kCombustionStream;
                const bool due=chemistry::lane_due(tick,x,y,period,static_cast<std::uint32_t>(stream));
                bool water=false;
                if (due) for (auto& exposure:exposures_) {
                    if (!exposure.consumed && exposure.kind==ExposureKind::WaterExtinction &&
                        exposure.shard==shard->handle() && exposure.cell==at &&
                        exposure.incarnation==shard->schedule(at).incarnation &&
                        exposure.first_tick<=tick && exposure.expiry_tick>=tick) {
                        exposure.consumed=true;water=true;++accounting_.consumed_exposures;
                    }
                }
                transition=chemistry::combustible(before.material,before.state_a,before.state_b,due,water);
                if (water) ++accounting_.extinguished;
            } else if (before.material==Material::Fire) {
                // The existing specialized ignition opportunity is separate
                // from Fire lifetime. Ports do not simulate internal gas drift.
                if (chemistry::lane_due(tick,x,y,120,10)) {
                    const auto target=neighbor(at,chemistry::kNeighbours[chemistry::random(tick,x,y,10)%8]);
                    if (target<shard->area() && shard->payload(target).material==Material::Wood) {
                        auto wood=shard->payload(target);wood.state_b=std::max<std::uint8_t>(wood.state_b,240);
                        require(shard->set_cell(target,wood,Role::Structural,tick));
                    }
                }
                transition=chemistry::fire_lifetime(before.state_a);
            } else if (before.material==Material::Smoke) {
                period=chemistry::kSmokePeriod;stream=chemistry::kSmokeStream;
                std::uint8_t crowd=0;
                for (const auto offset:chemistry::kNeighbours) {
                    const auto target=neighbor(at,offset);
                    crowd+=static_cast<std::uint8_t>(target<shard->area() && shard->payload(target).material==Material::Smoke);
                }
                transition=chemistry::smoke_lifetime(before.material,before.state_a,crowd,
                    chemistry::lane_due(tick,x,y,period,static_cast<std::uint32_t>(stream)));
                expiry=transition.material==Material::Empty;
            } else {
                // Inert structural fixtures and lodged Sand have no internal
                // transport. Their inventory still participates in geometry.
                require(shard->set_due(at,std::numeric_limits<std::uint64_t>::max()));continue;
            }
            if (transition.write) {
                const Payload after{transition.material,transition.state_a,transition.state_b,before.temperature};
                require(shard->set_cell(at,after,after.material==Material::Empty ? Role::Empty : shard->role(at),tick));
                record_transition(before,after,expiry);
            }
            if (transition.sample_fire_emission) {
                const auto target=neighbor(at,chemistry::kNeighbours[chemistry::random(tick,x,y,12)%8]);
                if (target<shard->area() && !shard->occupied(target)) {
                    const auto empty=shard->payload(target);
                    const Payload fire{Material::Fire,chemistry::kWoodFireLifetime,0,empty.temperature};
                    require(shard->set_cell(target,fire,Role::Product,tick));
                    record_transition(empty,fire);++metrics_.products_created;
                }
            }
            if (shard->occupied(at)) {
                const auto phase=chemistry::lane_phase(x,y,period,static_cast<std::uint32_t>(stream));
                const auto distance=(phase+period-tick%period)%period;
                require(shard->set_due(at,tick+(distance ? distance : period)));
            }
        }
    }
    // Bounded historical facts are consumed once or expire. A geometry revision
    // does not erase a fact about the same surviving cell incarnation.
    std::erase_if(exposures_,[&](const auto& e){return e.consumed || e.expiry_tick<tick || !registry_.find(e.shard);});
    metrics_.chemistry_ns+=now_ns()-start;
}
bool Coordinator::pocket_fenced(Handle handle,std::uint32_t cell) const noexcept {
    const auto* shard=registry_.find(handle);
    if (!shard || cell>=shard->area()) return true;
    const auto x=cell%shard->bounds().width;
    return std::any_of(ingress_fences_.begin(),ingress_fences_.end(),[&](const auto& fence){
        return fence.shard_id==handle.id && x>=fence.min_x && x<fence.max_x;
    });
}
Outcome Coordinator::fence_invalid_entry(Handle handle,std::uint32_t cell) {
    const auto* shard=registry_.find(handle);
    if (!shard) return Outcome::Stale;
    const auto opening=contact::pocket_opening(*shard,cell);
    if (opening.outcome!=Outcome::Accepted) return opening.outcome;
    for (auto& fence:ingress_fences_) if (fence.shard_id==handle.id &&
        fence.min_x<opening.max_x && opening.min_x<fence.max_x) {
        fence.min_x=std::min(fence.min_x,opening.min_x);fence.max_x=std::max(fence.max_x,opening.max_x);
        fence.row=std::max(fence.row,opening.row);return Outcome::Accepted;
    }
    if (ingress_fences_.size()==ingress_fences_.capacity()) return Outcome::Capacity;
    ingress_fences_.push_back({handle.id,opening.min_x,opening.max_x,opening.row});return Outcome::Accepted;
}
void Coordinator::refresh_ingress_fences() {
    // A failed swept entry must not become "already inside" on the next pose.
    // Keep the entire aperture column fenced until it is genuinely clear of
    // World Sand, or its owner is retired. This conservative historical guard
    // stores no duplicate material and follows the stable local lattice.
    std::erase_if(ingress_fences_,[&](const PocketFence& fence) {
        const BodyView* b=nullptr;
        for (const auto& current:bodies_) if (current.shard.id==fence.shard_id) { b=&current;break; }
        const auto* shard=b ? registry_.find(b->shard) : nullptr;
        if (!shard || !shard->owns_inventory() || !b || !b->has_body) return true;
        const auto frame=contact::frame(contact_pose(b->pose));
        const auto origin=contact::to_world(frame,{static_cast<double>(fence.min_x),0});
        const auto port_frame=contact::frame({origin.x,origin.y,b->pose.rotation});
        const auto candidates=contact::grid_candidates(contact::transformed_bounds(port_frame,
            static_cast<std::uint16_t>(fence.max_x-fence.min_x),static_cast<std::uint16_t>(fence.row+1)));
        for (auto y=candidates.min_y;y<=candidates.max_y;++y) for (auto x=candidates.min_x;x<=candidates.max_x;++x) {
            if (!resident(x,y) || world_->stored_material(x,y)!=Material::Sand) continue;
            const auto local=contact::to_local(frame,{static_cast<double>(x)+.5,static_cast<double>(y)+.5});
            if (local.x>=fence.min_x && local.x<fence.max_x && local.y>=0 && local.y<fence.row+1.0) return false;
        }
        return true;
    });
}

void Coordinator::automatic_ingress(bool transfer) {
    ScopedTime timing{metrics_.contact_ns};
    if (!transfer && world_->quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Sand)]==0) {
        ingress_fences_.clear();
        return;
    }
    refresh_ingress_fences();
    ingress_proposals_.clear();
    // Stable registry order resolves two-shard source contention. Native
    // ownership, not a transient raster ID, decides who can debit Sand.
    for (auto& b:bodies_) {
        auto* shard=registry_.find(b.shard);b.pocket_open=false;b.ingress_fenced=false;
        if (!shard || !b.has_body || shard->phase()!=Phase::Active) continue;
        const auto bounds=shard->bounds();const auto frame=contact::frame(contact_pose(b.pose));
        const auto domain=contact::motion_domain(*shard);
        for (std::size_t at=0;at<shard->area();++at) {
            if (shard->occupied(at)) continue;
            const auto x=static_cast<std::uint16_t>(at%bounds.width),y=static_cast<std::uint16_t>(at/bounds.width);
            if (contact::pocket_opening(*shard,at).outcome!=Outcome::Accepted) continue;
            b.pocket_open=true;b.pocket_cell=static_cast<std::uint32_t>(at);
            if (pocket_fenced(shard->handle(),static_cast<std::uint32_t>(at))) {
                b.ingress_fenced=true;++metrics_.ingress_blocked;continue;
            }
            const auto candidates=contact::grid_candidates(contact::transformed_cell_aabb(frame,x,y));
            for (auto wy=candidates.min_y;wy<=candidates.max_y;++wy)
                for (auto wx=candidates.min_x;wx<=candidates.max_x;++wx) {
                    if (!resident(wx,wy) || world_->stored_material(wx,wy)!=Material::Sand) continue;
                    const auto witness=contact::sand_pocket_witness(*shard,contact_pose(b.previous_pose),contact_pose(b.pose),
                        {static_cast<double>(wx)+.5,static_cast<double>(wy)+.5},
                        contact::motion_envelope(domain,config_.max_translation_per_step,config_.max_rotation_per_step),domain);
                    if (witness.outcome!=Outcome::Accepted || witness.slot!=at) {
                        const auto local=contact::to_local(frame,{static_cast<double>(wx)+.5,static_cast<double>(wy)+.5});
                        if (witness.outcome==Outcome::DestinationUnavailable &&
                            std::floor(local.x)==x && std::floor(local.y)==y) {
                            if (fence_invalid_entry(shard->handle(),static_cast<std::uint32_t>(at))!=Outcome::Accepted) {
                                (void)quarantine(shard->handle(),"bounded invalid-entry history exhausted");return;
                            }
                            b.ingress_fenced=true;++metrics_.ingress_blocked;
                        }
                        continue;
                    }
                    if (ingress_proposals_.size()==ingress_proposals_.capacity()) continue;
                    TransferRequest r{shard->handle(),0,b.body_generation,shard->geometry().revision,
                        b.pose.pose_serial,static_cast<std::uint32_t>(at),shard->schedule(at).incarnation,wx,wy,inspect_world(wx,wy)};
                    r.world_witness=world_witness(wx,wy);ingress_proposals_.push_back(r);
                }
        }
    }
    // Contact/history capacity is independent of material-transfer capacity.
    // Capture every admitted pocket's history before any Cargo write can dirty
    // geometry or exhaust the transfer budget for a later body.
    if (!transfer) return;
    for (auto& request:ingress_proposals_) {
        request.sequence=next_transaction_;(void)ingest(request);
        if (quarantined_) return;
    }
}

void Coordinator::advance_products_and_exchange() {
    ScopedTime timing{metrics_.exchange_ns};
    const auto tick=world_->completed_tick_index();
    const auto quota=config_.transfer_budget==0 ? 0U : std::max(1U,config_.transfer_budget/config_.limits.max_shards);
    std::uint32_t remaining=config_.transfer_budget;
    for (auto& b:bodies_) {
        auto* shard=registry_.find(b.shard);
        if (!shard || !shard->chemistry_allowed()) continue;
        const auto bounds=shard->bounds();const auto frame=contact::frame(contact_pose(b.pose));
        std::uint32_t attempts=0;
        const auto first=static_cast<std::size_t>((tick%shard->area())*quota%shard->area());
        for (std::size_t offset=0;offset<shard->area();++offset) {
            const auto at=(first+offset)%shard->area();
            const auto role=shard->role(at);
            if (role!=Role::Product && !(role==Role::Cargo && !b.has_body && shard->phase()==Phase::Draining)) continue;
            metrics_.maximum_product_age=std::max(metrics_.maximum_product_age,tick-shard->schedule(at).birth_tick);
            if (attempts>=quota || remaining==0) continue;
            ++attempts;--remaining;
            const auto center=contact::to_world(frame,{static_cast<double>(at%bounds.width)+.5,
                static_cast<double>(at/bounds.width)+.5});
            const auto wx=static_cast<std::int64_t>(std::floor(center.x)),wy=static_cast<std::int64_t>(std::floor(center.y));
            if (!resident(wx,wy) || world_->stored_material(wx,wy)!=Material::Empty || world_->transient_obstacle_at(wx,wy)) {
                ++metrics_.output_blocked;continue;
            }
            TransferRequest r{shard->handle(),next_transaction_,b.body_generation,shard->geometry().revision,
                b.pose.pose_serial,static_cast<std::uint32_t>(at),shard->schedule(at).incarnation,wx,wy,shard->payload(at)};
            r.world_witness=world_witness(wx,wy);
            const auto result=emit(r);
            if (result.outcome!=Outcome::Accepted) ++metrics_.output_blocked;
            if (quarantined_) return;
        }
        if (!b.has_body && shard->counts().total()==0 && shard->phase()==Phase::Draining) {
            if (registry_.retire(shard->handle())!=Outcome::Accepted) throw std::logic_error("empty draining retirement refused");
            b={};
        }
    }
}
void Coordinator::record_transition(Payload before,Payload after,bool expiry) noexcept {
    if (before.material==after.material) return;
    if (before.material!=Material::Empty)
        ++(expiry ? accounting_.expired : accounting_.destroyed)[static_cast<std::uint8_t>(before.material)];
    if (after.material!=Material::Empty) ++accounting_.created[static_cast<std::uint8_t>(after.material)];
}
Result Coordinator::ingest(const TransferRequest& r) {
    const auto fingerprint=transfer_fingerprint(r,true);
    if (r.shard.session!=session_) return finish({Outcome::Retired,r.shard,r.sequence});
    if (const auto* previous=prior(r.sequence)) return previous->fingerprint==fingerprint ? previous->result
        : finish({Outcome::Stale,r.shard,r.sequence});
    if (r.sequence!=next_transaction_) return finish({r.sequence<next_transaction_ ? Outcome::Expired : Outcome::Stale,r.shard,r.sequence});
    if (next_transaction_==std::numeric_limits<std::uint64_t>::max()) return finish({Outcome::GenerationExhausted,r.shard,r.sequence});
    ++next_transaction_; // Terminal refusals are receipts too; replay never reopens one.
    const auto done=[&](Outcome value,const char* detail="ingress refused") {
        return remember({value,r.shard,r.sequence,Phase::Active,detail},fingerprint);
    };
    if (paused()) return done(Outcome::Fenced);
    auto* shard=registry_.find(r.shard);auto* b=body(r.shard);
    if (!shard || !b || !shard->chemistry_allowed() || !b->has_body || r.cell>=shard->area() ||
        r.body_generation!=b->body_generation || r.geometry_revision!=shard->geometry().revision ||
        r.geometry_revision!=shard->applied_physics_revision() || r.pose_serial!=b->pose.pose_serial ||
        r.incarnation!=shard->schedule(r.cell).incarnation) return done(Outcome::Stale);
    if (r.capability_version!=kCapabilityVersion || r.expected.material!=Material::Sand || !coherent_payload(r.expected))
        return done(Outcome::Unsupported);
    if (!resident(r.world_x,r.world_y)) return done(Outcome::NotResident);
    if (r.world_witness!=world_witness(r.world_x,r.world_y) || inspect_world(r.world_x,r.world_y)!=r.expected)
        return done(Outcome::Stale);
    if (shard->occupied(r.cell) || world_->transient_obstacle_at(r.world_x,r.world_y)) return done(Outcome::DestinationUnavailable);
    if (pocket_fenced(r.shard,r.cell)) return done(Outcome::Fenced,"previous side entry awaits a genuinely empty aperture");
    const auto domain=contact::motion_domain(*shard);
    const auto witness=contact::sand_pocket_witness(*shard,contact_pose(b->previous_pose),contact_pose(b->pose),
        {static_cast<double>(r.world_x)+.5,static_cast<double>(r.world_y)+.5},
        contact::motion_envelope(domain,config_.max_translation_per_step,config_.max_rotation_per_step),domain);
    if (witness.outcome!=Outcome::Accepted || witness.slot!=r.cell || witness.incarnation!=r.incarnation) {
        const auto local=contact::to_local(contact::frame(contact_pose(b->pose)),
            {static_cast<double>(r.world_x)+.5,static_cast<double>(r.world_y)+.5});
        if (witness.outcome==Outcome::DestinationUnavailable && std::floor(local.x)==r.cell%shard->bounds().width &&
            std::floor(local.y)==r.cell/shard->bounds().width &&
            contact::pocket_opening(*shard,r.cell).outcome==Outcome::Accepted &&
            fence_invalid_entry(r.shard,r.cell)!=Outcome::Accepted)
            return done(Outcome::Capacity);
        return done(witness.outcome==Outcome::Accepted ? Outcome::Stale : witness.outcome);
    }
    const auto tick=world_->completed_tick_index();
    const auto admitted=shard->validate_cell_write(r.cell,r.expected,Role::Cargo,tick);
    if (admitted!=Outcome::Accepted) return done(admitted);
    bool debited=false,credited=false;
    try {
        debited=world_->write_cell(r.world_x,r.world_y,Material::Empty,0,0,nullptr,false);
        if (!debited || shard->set_cell(r.cell,r.expected,Role::Cargo,tick)!=Outcome::Accepted)
            throw std::logic_error("reserved Sand transfer failed");
        credited=true;
    } catch (...) {
        // An injected exception may occur immediately after the canonical
        // World write. Read back under the same exclusive owner and complete
        // the already reserved credit before quarantining, never duplicate it.
        debited=world_->stored_material(r.world_x,r.world_y)==Material::Empty;
        if (debited && !credited) credited=shard->set_cell(r.cell,r.expected,Role::Cargo,tick)==Outcome::Accepted;
        if (debited && credited) {++accounting_.ingested[static_cast<std::uint8_t>(Material::Sand)];++metrics_.sand_ingested;}
        auto result=quarantine(r.shard,"partial ingress retained under exact owner");result.transaction=r.sequence;
        return remember(result,fingerprint);
    }
    ++accounting_.ingested[static_cast<std::uint8_t>(Material::Sand)];++metrics_.sand_ingested;
    b->pocket_open=false;b->pocket_cell=r.cell;
    return done(Outcome::Accepted,"physical Sand pocket transfer committed");
}

Result Coordinator::emit(const TransferRequest& r) {
    const auto fingerprint=transfer_fingerprint(r,false);
    if (r.shard.session!=session_) return finish({Outcome::Retired,r.shard,r.sequence});
    if (const auto* previous=prior(r.sequence)) return previous->fingerprint==fingerprint ? previous->result
        : finish({Outcome::Stale,r.shard,r.sequence});
    if (r.sequence!=next_transaction_) return finish({r.sequence<next_transaction_ ? Outcome::Expired : Outcome::Stale,r.shard,r.sequence});
    if (next_transaction_==std::numeric_limits<std::uint64_t>::max()) return finish({Outcome::GenerationExhausted,r.shard,r.sequence});
    ++next_transaction_;
    const auto done=[&](Outcome value,const char* detail="emission refused") {
        return remember({value,r.shard,r.sequence,Phase::Active,detail},fingerprint);
    };
    if (paused()) return done(Outcome::Fenced);
    auto* shard=registry_.find(r.shard);auto* b=body(r.shard);
    if (!shard || !b || !shard->chemistry_allowed() || r.cell>=shard->area() ||
        r.body_generation!=b->body_generation || r.geometry_revision!=shard->geometry().revision ||
        r.pose_serial!=b->pose.pose_serial || r.incarnation!=shard->schedule(r.cell).incarnation ||
        shard->payload(r.cell)!=r.expected) return done(Outcome::Stale);
    const bool product=shard->role(r.cell)==Role::Product &&
        (r.expected.material==Material::Fire || r.expected.material==Material::Smoke);
    const bool draining_sand=shard->role(r.cell)==Role::Cargo && r.expected.material==Material::Sand &&
        shard->phase()==Phase::Draining && !b->has_body;
    if (r.capability_version!=kCapabilityVersion || (!product && !draining_sand)) return done(Outcome::Unsupported);
    if (!resident(r.world_x,r.world_y)) return done(Outcome::NotResident);
    if (r.world_witness!=world_witness(r.world_x,r.world_y)) return done(Outcome::Stale);
    if (world_->stored_material(r.world_x,r.world_y)!=Material::Empty || world_->transient_obstacle_at(r.world_x,r.world_y))
        return done(Outcome::DestinationUnavailable);
    const auto bounds=shard->bounds();
    const auto center=contact::to_world(contact::frame(contact_pose(b->pose)),
        {static_cast<double>(r.cell%bounds.width)+.5,static_cast<double>(r.cell/bounds.width)+.5});
    if (r.world_x!=static_cast<std::int64_t>(std::floor(center.x)) ||
        r.world_y!=static_cast<std::int64_t>(std::floor(center.y))) return done(Outcome::DestinationUnavailable);
    const auto tick=world_->completed_tick_index();
    const Payload empty{Material::Empty,0,0,r.expected.temperature};
    const auto admitted=shard->validate_cell_write(r.cell,empty,Role::Empty,tick);
    if (admitted!=Outcome::Accepted) return done(admitted);
    bool credited=false,debited=false;
    try {
        credited=world_->write_cell(r.world_x,r.world_y,r.expected.material,r.expected.state_a,r.expected.state_b,nullptr,false);
        if (!credited) throw std::logic_error("reserved output destination changed");
        world_->set_temperature(r.world_x,r.world_y,r.expected.temperature);
        debited=shard->set_cell(r.cell,empty,Role::Empty,tick)==Outcome::Accepted;
        if (!debited) throw std::logic_error("reserved output source changed");
    } catch (...) {
        const auto actual=inspect_world(r.world_x,r.world_y);
        credited=actual.material==r.expected.material && actual.state_a==r.expected.state_a && actual.state_b==r.expected.state_b;
        if (credited) {
            world_->set_temperature(r.world_x,r.world_y,r.expected.temperature);
            if (!debited) debited=shard->set_cell(r.cell,empty,Role::Empty,tick)==Outcome::Accepted;
            if (debited) ++accounting_.emitted[static_cast<std::uint8_t>(r.expected.material)];
        }
        auto result=quarantine(r.shard,"partial emission retained under exact owner");result.transaction=r.sequence;
        return remember(result,fingerprint);
    }
    ++accounting_.emitted[static_cast<std::uint8_t>(r.expected.material)];
    return done(Outcome::Accepted,"exact owned product admitted to World");
}

Result Coordinator::reset(std::uint32_t scenario,std::uint64_t seed) {
    if (attached_) return finish({Outcome::Unsupported, {}, 0, Phase::Suspended,
        "ordinary World replacement belongs solely to CyberNativeCellWorld"});
    if (scenario>6) return finish({Outcome::Invalid});
    // Reset is also the recovery control for a quarantined World. The public
    // healthy-ledger API intentionally refuses that state; this exclusive
    // coordinator can still account the retained native population directly.
    const auto world_disposed=world_->quantity_;
    for (std::size_t m=1;m<kQuantityMaterialSlots;++m) accounting_.reset_disposed[m]+=world_disposed.material_cells[m];
    accounting_.reset_water_quanta+=world_disposed.water_visible+world_disposed.water_overfill+world_disposed.water_ballistic;
    for (const auto& shard:registry_.shards()) if (shard.owns_inventory())
        for (std::size_t at=0;at<shard.area();++at) if (shard.occupied(at)) ++accounting_.reset_disposed[static_cast<std::uint8_t>(shard.payload(at).material)];
    Counts disposed;
    const auto session=new_session();
    const auto result=registry_.reset(session,session,disposed);
    if (result!=Outcome::Accepted) return finish({result});
    session_=session;world_incarnation_=session;config_.scenario=scenario;config_.seed=seed;
    pending_->present=false;pending_->cells.clear();pending_->terrain.clear();
    for (auto& b:bodies_) b={};
    for (auto& r:receipts_) r={};
    for (auto& t:terrain_) {t.identity={};t.rectangles.clear();}
    exposures_.clear();ingress_fences_.clear();ingress_proposals_.clear();quarantined_=false;pause_calls_=0;
    std::fill(fire_opportunities_.begin(),fire_opportunities_.end(),0);fire_opportunity_tick_=0;
    ingress_fences_backup_.clear();
    discovery_->reset();admission_={};admission_resource_valid_=false;admission_calls_=0;
    historical_metrics_=lifetime_metrics();metrics_={};
    // Cancellation takes a transaction sequence, so sequences may never be
    // reused by a new session even after detailed receipts have been retired.
    retired_transaction_=next_transaction_-1;
    initialize_world();
    return finish({});
}

const Snapshot& Coordinator::snapshot(bool include_world) {
    if (!world_) {
        snapshot_={};snapshot_.session=session_;snapshot_.world_incarnation=world_incarnation_;
        snapshot_.bounds=config_.world_bounds;snapshot_.paused=true;snapshot_.next_transaction=next_transaction_;
        snapshot_.last_result={Outcome::Retired,{},0,Phase::Retired,"World attachment retired"};
        snapshot_.metrics=metrics_;snapshot_.lifetime_metrics=lifetime_metrics();snapshot_.accounting=accounting_;
        return snapshot_;
    }
    const auto start=now_ns();const auto b=config_.world_bounds;
    // Edits can precede the next discovery pass. Never label an old catalogue
    // complete while new topology invalidations are waiting in World.
    refresh_admission(admission_.work_last);
    rebuild_terrain();
    if (include_world) for (std::size_t at=0;at<materials_.size();++at)
        materials_[at]=static_cast<std::uint8_t>(world_->stored_material(b.x+static_cast<std::int64_t>(at%b.width),
            b.y+static_cast<std::int64_t>(at/b.width)));
    const auto memory=registry_.memory_usage();
    metrics_.world_bytes=world_->resident_cell_bytes();
    metrics_.coordinator_bytes=sizeof(Coordinator)+sizeof(Pending)+materials_.capacity()+proposed_mask_.capacity()*sizeof(std::uint16_t)+
        proposed_indices_.capacity()*sizeof(std::uint32_t)+
        discovery_->storage_bytes()+
        component_.capacity()*sizeof(std::uint32_t)+exposures_.capacity()*sizeof(Exposure)+
        (ingress_fences_.capacity()+ingress_fences_backup_.capacity())*sizeof(PocketFence)+
        fire_opportunities_.capacity()*sizeof(std::uint32_t)+
        ingress_proposals_.capacity()*sizeof(TransferRequest)+
        receipts_.capacity()*sizeof(Receipt)+pending_->cells.capacity()*sizeof(Pending::Captured)+
        pending_->terrain.capacity()*sizeof(TerrainReceipt)+pending_->fragment_fences.capacity()*sizeof(PocketFence)+terrain_scratch_.capacity()+
        reserved_destinations_.capacity()+ingress_exclusion_.capacity()+relocations_.capacity()*sizeof(Relocation)+
        (bodies_.capacity()+body_backup_.capacity())*sizeof(BodyView)+terrain_.capacity()*sizeof(TerrainChunk)+
        (immutable_occupancy_.capacity()+immutable_occupancy_backup_.capacity()+shard_occupancy_.capacity())*
            sizeof(World::TransientCompositionCell)+
        world_->object_shard_mutations_->storage_bytes();
    for (const auto& tile:terrain_) metrics_.coordinator_bytes+=tile.rectangles.capacity()*sizeof(Rect);
    metrics_.live_bytes=memory.live_bytes+metrics_.coordinator_bytes+metrics_.world_bytes;
    metrics_.retained_bytes=memory.retained_bytes+metrics_.coordinator_bytes+metrics_.world_bytes;
    metrics_.peak_bytes=std::max(metrics_.peak_bytes,metrics_.retained_bytes);
    snapshot_={};snapshot_.session=session_;snapshot_.world_incarnation=world_incarnation_;
    snapshot_.next_transaction=next_transaction_;
    snapshot_.tick=world_->completed_tick_index();snapshot_.bounds=b;snapshot_.paused=paused();snapshot_.quarantined=quarantined_;
    snapshot_.last_result=last_result_;
    if (include_world) snapshot_.world_materials=materials_;
    snapshot_.terrain_chunks=terrain_;
    snapshot_.shards=registry_.shards();snapshot_.bodies=bodies_;snapshot_.accounting=accounting_;snapshot_.admission=admission_;
    if (pending_->present && !pending_->reabsorption) snapshot_.promotion={true,pending_->shard,pending_->transaction,pending_->payload_digest,
        pending_->captured_tick,registry_.find(pending_->shard)->phase(),pending_->terrain,pending_->source_parent};
    if (pending_->present && pending_->reabsorption) snapshot_.reabsorption={true,pending_->world_committed,pending_->shard,
        pending_->transaction,pending_->payload_digest,pending_->captured_tick,pending_->source_body_generation,
        pending_->parent_geometry_revision,pending_->source_mask_digest,pending_->source_shape_digest,pending_->terrain};
    metrics_.snapshot_ns+=now_ns()-start;snapshot_.metrics=metrics_;snapshot_.lifetime_metrics=lifetime_metrics();
    return snapshot_;
}

} // namespace cybersand::object_shard
