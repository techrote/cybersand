#include "cybersand/object_shard_coordinator.hpp"
#include "cybersand/object_shard_mutation.hpp"
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
bool promotable(Material m) noexcept { return m==Material::Wood || m==Material::RedBrick; }
}

struct Coordinator::Pending {
    struct Captured { std::int64_t x{}, y{}; std::uint32_t local{}; Payload payload{}; std::uint64_t witness{}; };
    bool present{};
    Handle shard{};
    std::uint64_t transaction{}, payload_digest{}, captured_tick{}, watch_incarnation{}, watch_revision{};
    std::vector<Captured> cells;
    std::vector<TerrainReceipt> terrain;
    std::array<std::uint64_t, 3> acknowledgements{};
};
struct Coordinator::Receipt {
    std::uint64_t sequence{}, fingerprint{};
    Result result{};
    std::array<std::uint64_t, 3> acknowledgements{};
};

Coordinator::Coordinator(Config config)
    : config_(config), session_(new_session()), world_incarnation_(session_),
      registry_(config.limits, session_, world_incarnation_), pending_(std::make_unique<Pending>()) {
    const auto area = config_.world_bounds.area();
    // Reject before halo arithmetic or floating point conversion. The Lab's
    // declared finite coordinate envelope also preserves exact cell centres.
    const auto bounds=config_.world_bounds;
    if (!valid_bounds(bounds) || bounds.x < -262144 || bounds.y < -262144 ||
        bounds.x > 262144-static_cast<std::int64_t>(bounds.width) ||
        bounds.y > 262144-static_cast<std::int64_t>(bounds.height) || bounds.width < 64 ||
        config_.world_bounds.height < 64 || area > 262144 || config_.limits.max_shapes > 512 ||
        config_.limits.max_shards > World::kMaximumTransientBodies || config_.discovery_budget == 0 ||
        config_.exposure_capacity == 0 || config_.exposure_capacity > 65536 || config_.transfer_budget > 1024 ||
        config_.max_pause_calls == 0 || !std::isfinite(config_.max_translation_per_step) ||
        config_.max_translation_per_step <= 0 || config_.max_translation_per_step > 8 ||
        !std::isfinite(config_.max_rotation_per_step) || config_.max_rotation_per_step <= 0 ||
        config_.max_rotation_per_step > .25)
        throw std::invalid_argument("ObjectShard Lab configuration outside bounded M0-M2 envelope");
    discovery_queue_.reserve(area); component_.reserve(config_.limits.max_area);
    seen_.resize(area); discovery_skip_.resize(area); proposed_mask_.resize(area); materials_.resize(area);
    exposures_.reserve(config_.exposure_capacity); receipts_.resize(64);
    bodies_.resize(config_.limits.max_shards); body_backup_.resize(config_.limits.max_shards);
    pending_->cells.reserve(config_.limits.max_area);
    const auto tiles = ((config_.world_bounds.width + 63U) / 64U) * ((config_.world_bounds.height + 63U) / 64U);
    pending_->terrain.reserve(tiles); terrain_.resize(tiles); terrain_scratch_.resize(4096);
    for (auto& tile : terrain_) tile.rectangles.reserve(4096);
    initialize_world();
}
Coordinator::~Coordinator() = default;

void Coordinator::initialize_world() {
    WorldConfig wc;
    wc.chunk_size = 32; wc.activity_block_size = 16; wc.scheduling_core_size = 32;
    wc.backend = SimulationBackend::SerialInPlace; wc.worker_threads = 1;
    wc.initial_chunk_reserve = 128; wc.maximum_chunk_count = 1024;
    wc.active_chunk_capacity = 1024; wc.active_core_capacity = 1024;
    wc.deferred_event_capacity = 32;
    world_ = std::make_unique<World>(wc);
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
    const unsigned count = scenario == 4 ? std::min(3U, config_.limits.max_shards) : 1U;
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
        // Three-cell-wide clear channel to an open, one-cell lodging pocket.
        for (auto y = floor - 49; y <= floor - 36; ++y) world_->set(trunk_x + 8, y, Material::Empty);
        if (scenario == 5) {
            for (auto y = floor - 44; y < floor - 32; y += 2)
                for (auto x = trunk_x - 9; x < trunk_x + 14; x += 3) world_->set(x, y, Material::Empty);
        }
        if (scenario == 2 || scenario == 4) {
            (void)world_->set_cell_state(trunk_x + 14, floor - 40, Material::Wood, 0, 240);
            world_->set_temperature(trunk_x + 14, floor - 40, 650);
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
Payload Coordinator::inspect_world(std::int64_t x, std::int64_t y) const noexcept {
    return {world_->stored_material(x,y), world_->stored_state_a(x,y), world_->stored_state_b(x,y), world_->stored_temperature(x,y)};
}
Result Coordinator::finish(Result r) noexcept {
    last_result_ = r;
    if (r.outcome != Outcome::Accepted && r.outcome != Outcome::Anchored && r.outcome != Outcome::Busy) ++metrics_.refusals;
    return r;
}
BodyView* Coordinator::body(Handle h) noexcept {
    for (auto& b : bodies_) if (b.shard == h) return &b;
    return nullptr;
}
const BodyView* Coordinator::body(Handle h) const noexcept {
    for (const auto& b : bodies_) if (b.shard == h) return &b;
    return nullptr;
}
bool Coordinator::paused() const noexcept {
    if (quarantined_ || pending_->present) return true;
    for (const auto& b : bodies_) if (b.geometry_pending) return true;
    return false;
}
Result Coordinator::edit(std::int64_t x, std::int64_t y, Payload value) {
    if (paused()) return finish({Outcome::Fenced, {}, 0, Phase::Empty, "Lab promotion/geometry barrier"});
    if (!resident(x,y)) return finish({Outcome::NotResident});
    if (!coherent_payload(value) || (value.material==Material::Water &&
        (value.state_a>world_->config().water_experiment_policy.maximum() ||
         value.state_b>world_->config().water_experiment_policy.coherence_ticks()))) return finish({Outcome::Unsupported});
    if (world_->transient_obstacle_at(x,y)) return finish({Outcome::DestinationUnavailable});
    // All cell/temperature storage is reserved at construction.
    (void)world_->set_cell_state(x,y,value.material,value.state_a,value.state_b);
    world_->set_temperature(x,y,value.temperature);
    rebuild_terrain();
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

Outcome Coordinator::capture_component(std::int64_t sx, std::int64_t sy) {
    const auto material = world_->stored_material(sx,sy);
    if (!promotable(material)) return Outcome::Unsupported;
    const auto w = config_.world_bounds.width;
    const auto b = config_.world_bounds;
    const auto index = [&](std::int64_t x, std::int64_t y) { return static_cast<std::uint32_t>((y-b.y)*w + (x-b.x)); };
    if (++discovery_serial_ == 0) { std::fill(seen_.begin(),seen_.end(),0); discovery_serial_ = 1; }
    discovery_queue_.clear(); component_.clear(); discovery_queue_.push_back(index(sx,sy)); seen_[index(sx,sy)] = discovery_serial_;
    auto min_x = sx, max_x = sx, min_y = sy, max_y = sy;
    bool anchored = false;
    std::size_t cursor = 0;
    while (cursor < discovery_queue_.size()) {
        if (discovery_remaining_==0 || component_.size() >= config_.limits.max_area)
            return Outcome::Capacity; // incomplete membership is never promoted
        const auto at = discovery_queue_[cursor++];
        const auto x = b.x + at % w, y = b.y + at / w;
        component_.push_back(at); ++metrics_.discovered_cells; --discovery_remaining_;
        min_x = std::min(min_x,x); max_x = std::max(max_x,x); min_y = std::min(min_y,y); max_y = std::max(max_y,y);
        for (const auto& [dx,dy] : kCardinal) {
            const auto nx = x + dx, ny = y + dy;
            if (!resident(nx,ny)) return Outcome::UnknownBoundary;
            const auto neighbor = world_->stored_material(nx,ny);
            // Explicit v1 anchoring: Wall is scenery. Only like admitted
            // structural materials cohere; loose Sand never creates a bond.
            if (neighbor == Material::Wall) anchored = true;
            if (neighbor != material) continue;
            const auto ni = index(nx,ny);
            if (seen_[ni] == discovery_serial_) continue;
            seen_[ni] = discovery_serial_; discovery_queue_.push_back(ni);
        }
    }
    if (anchored) return Outcome::Anchored;
    if (min_x <= b.x || min_y <= b.y || max_x >= b.x+b.width-1 || max_y >= b.y+b.height-1)
        return Outcome::UnknownBoundary;
    // One Empty ring provides spatial product carriers without changing the
    // stable lattice origin as structural edges erode.
    Bounds bounds{min_x-1,min_y-1,static_cast<std::uint16_t>(max_x-min_x+3),static_cast<std::uint16_t>(max_y-min_y+3)};
    if (bounds.area() > config_.limits.max_area) return Outcome::Capacity;
    for (const auto& explosion : world_->pending_explosions_)
        if (explosion.x + explosion.radius >= bounds.x && explosion.x - explosion.radius < bounds.x+bounds.width &&
            explosion.y + explosion.radius >= bounds.y && explosion.y - explosion.radius < bounds.y+bounds.height)
            return Outcome::PendingEvent;
    Handle handle;
    const auto prepared = registry_.prepare(bounds,world_->completed_tick_index(),handle);
    if (prepared != Outcome::Accepted) return prepared;
    auto* shard = registry_.find(handle);
    pending_->cells.clear(); pending_->terrain.clear(); pending_->acknowledgements = {};
    for (const auto at : component_) {
        const auto x = b.x + at % w, y = b.y + at / w;
        const auto p = inspect_world(x,y);
        if (!coherent_payload(p) || world_->transient_obstacle_at(x,y)) {
            (void)registry_.cancel_precommit(handle); return Outcome::Unsupported;
        }
        const auto local = static_cast<std::uint32_t>((y-bounds.y)*bounds.width + x-bounds.x);
        if (shard->set_cell(local,p,Role::Structural,world_->completed_tick_index()) != Outcome::Accepted) {
            (void)registry_.cancel_precommit(handle); return Outcome::Capacity;
        }
        pending_->cells.push_back({x,y,local,p,world_->object_shard_mutations_->witness(x,y)});
    }
    const auto ready = registry_.finish_preparation(handle);
    if (ready != Outcome::Accepted) { (void)registry_.cancel_precommit(handle); return ready; }
    pending_->present = true; pending_->shard = handle; pending_->transaction = next_transaction_++;
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

Result Coordinator::prepare_next() {
    if (next_transaction_==std::numeric_limits<std::uint64_t>::max()) return finish({Outcome::GenerationExhausted});
    if (paused()) return finish({Outcome::Busy, pending_->shard, pending_->transaction,
        pending_->present ? registry_.find(pending_->shard)->phase() : Phase::Suspended, "barrier already pending"});
    if (world_->has_failed() || world_->is_tick_in_progress() || world_->completed_tick_index()==0 ||
        world_->object_shard_mutations_->exhausted()) return finish({Outcome::Quarantined});
    std::int64_t x{},y{};
    std::uint32_t seeds=0;
    discovery_remaining_=config_.discovery_budget;
    std::fill(discovery_skip_.begin(),discovery_skip_.end(),0);
    while (seeds++ < config_.discovery_budget && world_->object_shard_mutations_->pop(x,y)) {
        // A removed support is itself Empty. Its four live neighbours are the
        // seeds, so fire and ordinary erasing share this exact path.
        for (const auto& [dx,dy] : std::array<std::pair<int,int>,5>{{{0,0},{-1,0},{1,0},{0,-1},{0,1}}}) {
            const auto nx=x+dx,ny=y+dy;
            if (!resident(nx,ny) || !promotable(world_->stored_material(nx,ny))) continue;
            const auto b=config_.world_bounds;
            const auto at=static_cast<std::size_t>(ny-b.y)*b.width+static_cast<std::size_t>(nx-b.x);
            if (discovery_skip_[at]) continue;
            if (discovery_remaining_==0) {
                world_->object_shard_mutations_->requeue(x,y);
                return finish({Outcome::Capacity,{},0,Phase::Empty,"discovery budget; no partial promotion"});
            }
            const auto result=capture_component(nx,ny);
            for (const auto member:component_) discovery_skip_[member]=1;
            if (result==Outcome::Accepted) {
                // One erase can sever several independent arms. Preserve the
                // original seed until every neighbouring component is seen.
                world_->object_shard_mutations_->requeue(x,y);
                return finish({result,pending_->shard,pending_->transaction,Phase::Prepared});
            }
            if (result!=Outcome::Anchored && result!=Outcome::Unsupported) {
                world_->object_shard_mutations_->requeue(x,y);
                return finish({result,{},0,Phase::Empty,"component not admitted"});
            }
        }
    }
    return finish({Outcome::Busy,{},0,Phase::Empty,"no unsupported complete component pending"});
}

bool Coordinator::validate_prepared() const noexcept {
    if (!pending_->present || world_->has_failed() || world_->is_tick_in_progress() ||
        world_->completed_tick_index()!=pending_->captured_tick || !world_->pending_explosions_.empty() ||
        world_->object_shard_mutations_->incarnation()!=pending_->watch_incarnation ||
        world_->object_shard_mutations_->revision()!=pending_->watch_revision) return false;
    for (const auto& c : pending_->cells)
        if (inspect_world(c.x,c.y)!=c.payload || world_->transient_obstacle_at(c.x,c.y) ||
            world_->object_shard_mutations_->witness(c.x,c.y)!=c.witness) return false;
    return true;
}
Outcome Coordinator::commit_prepared() {
    if (!validate_prepared()) return Outcome::Stale;
    auto* shard=registry_.find(pending_->shard);
    if (!shard || shard->phase()!=Phase::PhysicsReserved) return Outcome::Stale;
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
    if (static_cast<unsigned>(a.kind)>static_cast<unsigned>(AckKind::BodyRetired))
        return finish({Outcome::Invalid,a.shard,a.transaction,Phase::Empty,"unknown acknowledgement kind"});
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
        }
        return finish({result,a.shard,a.transaction,shard->phase()});
    }
    if (a.kind==AckKind::BodyRetired) {
        if (shard->phase()!=Phase::Draining || shard->counts().structural || a.body_generation!=b->body_generation ||
            a.geometry_revision!=geometry.revision || a.mask_digest!=geometry.mask_digest || a.shape_digest!=geometry.shape_digest)
            return finish({Outcome::Stale,a.shard});
        b->has_body=false; b->geometry_pending=false;
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
    if (const auto* done=prior(transaction)) return done->result;
    if (!pending_->present || transaction!=pending_->transaction)
        return finish({transaction<next_transaction_ ? Outcome::Expired : Outcome::Stale,{},transaction});
    const auto h=pending_->shard;
    auto* shard=registry_.find(h);
    if (shard->owns_inventory()) return quarantine(h,"cancel after commit retains inactive shard inventory");
    const auto result=registry_.cancel_precommit(h);
    if (auto* b=body(h)) *b={};
    pending_->present=false;
    return remember({result==Outcome::Accepted ? Outcome::Cancelled : result,h,transaction,Phase::Retired},0);
}

void Coordinator::rebuild_terrain() {
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
    metrics_.geometry_ns+=now_ns()-start;
}

// M0 occupies the exact union of rotated structural unit cells. M2 contact and
// conservative overlap reconciliation extend this bounded same-owner seam.
Outcome Coordinator::rebuild_mask(bool) {
    const auto start=now_ns(); const auto wb=config_.world_bounds;
    std::fill(proposed_mask_.begin(),proposed_mask_.end(),0);
    for (std::size_t slot=0;slot<bodies_.size();++slot) {
        const auto& b=bodies_[slot]; const auto* shard=registry_.find(b.shard);
        if (!shard || !shard->owns_inventory() || !b.has_body) continue;
        const auto sb=shard->bounds(); const auto c=std::cos(b.pose.rotation),s=std::sin(b.pose.rotation);
        for (std::size_t at=0;at<shard->area();++at) if (shard->structural(at)) {
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
                // Two physically disjoint subcell shapes can cover the same
                // World carrier. This derived mask is their union, not an
                // inventory arbitration rule or an additional material owner.
                if (!proposed_mask_[wi] || id<proposed_mask_[wi]) proposed_mask_[wi]=id;
            }
        }
    }
    world_->clear_transient_obstacles();
    for (std::size_t at=0;at<proposed_mask_.size();++at) if (proposed_mask_[at]) {
        const auto x=wb.x+static_cast<std::int64_t>(at%wb.width),y=wb.y+static_cast<std::int64_t>(at/wb.width);
        if (!world_->set_transient_obstacle(x,y,proposed_mask_[at])) return Outcome::Quarantined;
        ++metrics_.mask_cells;
    }
    metrics_.occupancy_ns+=now_ns()-start;
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
        if (std::hypot(p.x-b->pose.x,p.y-b->pose.y)>config_.max_translation_per_step ||
            std::abs(p.rotation-b->pose.rotation)>config_.max_rotation_per_step) return Outcome::Unsupported;
        for (const auto& other:poses) if (&other!=&p && other.shard==p.shard) return Outcome::Invalid;
    }
    std::copy(bodies_.begin(),bodies_.end(),body_backup_.begin());
    for (const auto& p:poses) {auto* b=body(p.shard);b->previous_pose=b->pose;b->pose=p;}
    const auto result=rebuild_mask(true);
    if (result!=Outcome::Accepted && result!=Outcome::Quarantined)
        std::copy(body_backup_.begin(),body_backup_.end(),bodies_.begin());
    return result;
}

Result Coordinator::step(std::span<const PoseSample> poses) {
    if (quarantined_) return finish({Outcome::Quarantined});
    if (paused()) {
        ++metrics_.paused_calls;
        if (++pause_calls_>config_.max_pause_calls) return quarantine(pending_->shard,"bounded main-thread barrier deadline expired");
        return finish({Outcome::Fenced,pending_->shard,pending_->transaction,Phase::Suspended,"awaiting installed-content/activation receipt"});
    }
    pause_calls_=0;
    const auto accepted=apply_poses(poses);
    if (accepted==Outcome::Quarantined) return quarantine({},"partial occupancy application; clocks held");
    if (accepted!=Outcome::Accepted) return finish({accepted,{},0,Phase::Suspended,"pose outside admitted source/motion envelope"});
    try {
        const auto start=now_ns(); (void)world_->tick(); metrics_.world_ns+=now_ns()-start;
        ++metrics_.steps;
        advance_chemistry(); advance_products_and_exchange(); rebuild_terrain();
        for (const auto& shard:registry_.shards()) if (shard.owns_inventory() && shard.geometry_dirty()) {
            const auto result=registry_.rebuild_geometry(shard.handle(),world_->completed_tick_index());
            if (result!=Outcome::Accepted) return quarantine(shard.handle(),"geometry capacity; exact inventory retained");
            if (auto* b=body(shard.handle())) b->geometry_pending=b->has_body;
        }
    } catch (...) { return quarantine({},"unexpected native progress; whole owner quarantined"); }
    return finish({});
}

void Coordinator::capture_water(Shard&,const BodyView&,const PoseSample&) {}
void Coordinator::advance_chemistry() {}
void Coordinator::advance_products_and_exchange() {}
void Coordinator::record_transition(Payload before,Payload after,bool expiry) noexcept {
    if (before.material==after.material) return;
    if (before.material!=Material::Empty)
        ++(expiry ? accounting_.expired : accounting_.destroyed)[static_cast<std::uint8_t>(before.material)];
    if (after.material!=Material::Empty) ++accounting_.created[static_cast<std::uint8_t>(after.material)];
}
Result Coordinator::ingest(const TransferRequest& request) {return finish({Outcome::Unsupported,request.shard,request.sequence});}
Result Coordinator::emit(const TransferRequest& request) {return finish({Outcome::Unsupported,request.shard,request.sequence});}

Result Coordinator::reset(std::uint32_t scenario,std::uint64_t seed) {
    if (scenario>6) return finish({Outcome::Invalid});
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
    exposures_.clear();quarantined_=false;pause_calls_=0;
    // Cancellation takes a transaction sequence, so sequences may never be
    // reused by a new session even after detailed receipts have been retired.
    retired_transaction_=next_transaction_-1;
    initialize_world();
    return finish({});
}

const Snapshot& Coordinator::snapshot() {
    const auto start=now_ns();const auto b=config_.world_bounds;
    for (std::size_t at=0;at<materials_.size();++at)
        materials_[at]=static_cast<std::uint8_t>(world_->stored_material(b.x+static_cast<std::int64_t>(at%b.width),
            b.y+static_cast<std::int64_t>(at/b.width)));
    const auto memory=registry_.memory_usage();
    metrics_.world_bytes=world_->resident_cell_bytes();
    metrics_.coordinator_bytes=materials_.capacity()+proposed_mask_.capacity()*sizeof(std::uint16_t)+
        seen_.capacity()*sizeof(std::uint32_t)+discovery_queue_.capacity()*sizeof(std::uint32_t)+
        component_.capacity()*sizeof(std::uint32_t)+exposures_.capacity()*sizeof(Exposure)+
        receipts_.capacity()*sizeof(Receipt)+pending_->cells.capacity()*sizeof(Pending::Captured)+
        world_->object_shard_mutations_->storage_bytes();
    for (const auto& tile:terrain_) metrics_.coordinator_bytes+=tile.rectangles.capacity()*sizeof(Rect);
    metrics_.live_bytes=memory.live_bytes+metrics_.coordinator_bytes+metrics_.world_bytes;
    metrics_.retained_bytes=memory.retained_bytes+metrics_.coordinator_bytes+metrics_.world_bytes;
    metrics_.peak_bytes=std::max(metrics_.peak_bytes,metrics_.retained_bytes);
    snapshot_={};snapshot_.session=session_;snapshot_.world_incarnation=world_incarnation_;
    snapshot_.tick=world_->completed_tick_index();snapshot_.bounds=b;snapshot_.paused=paused();snapshot_.quarantined=quarantined_;
    snapshot_.last_result=last_result_;snapshot_.world_materials=materials_;snapshot_.terrain_chunks=terrain_;
    snapshot_.shards=registry_.shards();snapshot_.bodies=bodies_;snapshot_.accounting=accounting_;
    if (pending_->present) snapshot_.promotion={true,pending_->shard,pending_->transaction,pending_->payload_digest,
        pending_->captured_tick,registry_.find(pending_->shard)->phase(),pending_->terrain};
    metrics_.snapshot_ns+=now_ns()-start;snapshot_.metrics=metrics_;
    return snapshot_;
}

} // namespace cybersand::object_shard
