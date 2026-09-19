#include "cybersand/settled_world_discovery.hpp"

#include <limits>
#include <stdexcept>
#include <utility>
#include <vector>

namespace cybersand::soliding {
namespace {

void add(std::uint64_t& value, std::uint64_t amount = 1) noexcept {
    const auto room = std::numeric_limits<std::uint64_t>::max() - value;
    value += amount > room ? room : amount;
}

std::uint64_t hash_key(const DiscoveryTileKey& key) noexcept {
    std::uint64_t hash = 1469598103934665603ULL;
    const auto mix = [&hash](std::uint64_t value) {
        for (std::size_t i = 0; i < sizeof(value); ++i) {
            hash ^= static_cast<std::uint8_t>(value >> (i * 8U));
            hash *= 1099511628211ULL;
        }
    };
    mix(key.world_incarnation);
    mix(static_cast<std::uint64_t>(key.chunk_y));
    mix(static_cast<std::uint64_t>(key.chunk_x));
    mix(static_cast<std::uint64_t>(key.activity_y));
    mix(static_cast<std::uint64_t>(key.activity_x));
    mix(static_cast<std::uint64_t>(key.subtile_y));
    mix(static_cast<std::uint64_t>(key.subtile_x));
    return hash;
}

std::size_t index_size_for(std::size_t capacity) {
    if (capacity > kMaximumWorldDiscoveryTiles) {
        throw std::invalid_argument("settled discovery tile capacity exceeds compiled maximum");
    }
    if (capacity == 0) throw std::invalid_argument("settled discovery tile capacity must be positive");
    std::size_t result = 1;
    while (result < capacity * 2U) result *= 2U;
    return result;
}

} // namespace

struct SettledWorldDiscoveryCoordinator::Impl {
    using Journal = SettledDiscovery<kMaximumWorldDiscoveryTiles, 1024>;
    using Regions = SettledRegions<kMaximumIntegratedRegionTiles, 1024, 32,
                                   kMaximumIntegratedRegionTiles * 64,
                                   kMaximumIntegratedRegionTiles,
                                   kMaximumIntegratedRegionTiles * 32>;
    struct Record {
        DiscoveryTileKey key{};
        DiscoveryBounds bounds{};
        DiscoverySignals signals{};
        DiscoveryHandle handle{};
        std::uint64_t region_payload_revision{};
        std::int16_t ambient_temperature{};
    };
    struct IndexEntry {
        DiscoveryTileKey key{};
        std::size_t record{};
        bool occupied{};
    };

    Impl(std::uint64_t identity, std::size_t configured_capacity, bool enable_regions)
        : journal(identity), tile_capacity(configured_capacity), incarnation(identity),
          index(index_size_for(configured_capacity)) {
        if (identity == 0) throw std::invalid_argument("settled discovery incarnation must be nonzero");
        if (enable_regions && configured_capacity > kMaximumIntegratedRegionTiles)
            throw std::invalid_argument("integrated region tile capacity exceeds compiled maximum");
        records.reserve(tile_capacity);
        if (enable_regions) regions = std::make_unique<Regions>(identity);
    }

    std::optional<std::size_t> find_record(DiscoveryTileKey key) const noexcept {
        const auto mask = index.size() - 1U;
        auto slot = static_cast<std::size_t>(hash_key(key)) & mask;
        for (std::size_t probe = 0; probe < index.size(); ++probe) {
            add(metrics.index_probes);
            const auto& entry = index[slot];
            if (!entry.occupied) return std::nullopt;
            if (entry.key == key) return entry.record;
            slot = (slot + 1U) & mask;
        }
        return std::nullopt;
    }

    bool insert_index(DiscoveryTileKey key, std::size_t record) noexcept {
        const auto mask = index.size() - 1U;
        auto slot = static_cast<std::size_t>(hash_key(key)) & mask;
        for (std::size_t probe = 0; probe < index.size(); ++probe) {
            add(metrics.index_probes);
            auto& entry = index[slot];
            if (!entry.occupied) {
                entry = {key, record, true};
                return true;
            }
            if (entry.key == key) return false;
            slot = (slot + 1U) & mask;
        }
        return false;
    }

    void block_capacity() noexcept {
        if (!capacity_blocked) add(metrics.capacity_halts);
        capacity_blocked = true;
        journal.fail();
        if (regions != nullptr) regions->fail(RegionRefusal::TileCapacity);
    }

    Journal journal;
    std::size_t tile_capacity{};
    std::uint64_t incarnation{};
    std::vector<Record> records;
    std::vector<IndexEntry> index;
    std::unique_ptr<Regions> regions;
    std::array<DiscoveryCell, 1024> region_scratch{};
    mutable WorldDiscoveryMetrics metrics{};
    bool capacity_blocked{};
};

SettledWorldDiscoveryCoordinator::SettledWorldDiscoveryCoordinator(
    std::uint64_t incarnation, std::size_t tile_capacity, bool regions_enabled)
    : impl_(std::make_unique<Impl>(incarnation, tile_capacity, regions_enabled)) {}

SettledWorldDiscoveryCoordinator::~SettledWorldDiscoveryCoordinator() = default;
SettledWorldDiscoveryCoordinator::SettledWorldDiscoveryCoordinator(
    SettledWorldDiscoveryCoordinator&&) noexcept = default;
SettledWorldDiscoveryCoordinator& SettledWorldDiscoveryCoordinator::operator=(
    SettledWorldDiscoveryCoordinator&&) noexcept = default;

DiscoveryOutcome SettledWorldDiscoveryCoordinator::register_tile(
    DiscoveryTileKey key, DiscoveryBounds bounds, std::int16_t ambient_temperature,
    DiscoverySignals signals, std::uint64_t tick) noexcept {
    auto& state = *impl_;
    add(state.metrics.notifications[static_cast<std::size_t>(ProducerReason::Registration)]);
    add(state.metrics.registration_work);
    if (state.capacity_blocked || state.journal.halted() != DiscoveryHalt::None)
        return DiscoveryOutcome::Halted;
    if (key.world_incarnation != state.incarnation) return DiscoveryOutcome::Invalid;
    if (const auto existing = state.find_record(key); existing.has_value()) {
        auto& record = state.records[*existing];
        if (record.bounds != bounds) {
            state.journal.fail();
            return DiscoveryOutcome::Invalid;
        }
        const auto outcome = state.journal.observe(record.handle, signals, tick);
        if (outcome == DiscoveryOutcome::Accepted || outcome == DiscoveryOutcome::Unchanged) {
            record.signals = signals;
            if (outcome == DiscoveryOutcome::Accepted && state.regions != nullptr) {
                const auto summary = state.journal.snapshot(record.handle);
                if (summary.has_value()) {
                    (void)state.regions->invalidate(record.key, summary->revision);
                    record.region_payload_revision = 0;
                }
            }
        }
        return outcome;
    }
    if (state.records.size() == state.tile_capacity) {
        add(state.metrics.registration_refusals);
        state.block_capacity();
        return DiscoveryOutcome::Capacity;
    }
    DiscoveryHandle handle{};
    const auto outcome = state.journal.register_unique_block(bounds, signals, tick, handle);
    if (outcome != DiscoveryOutcome::Accepted) {
        if (outcome == DiscoveryOutcome::Capacity) {
            add(state.metrics.registration_refusals);
            state.block_capacity();
        }
        return outcome;
    }
    const auto record = state.records.size();
    state.records.push_back({key, bounds, signals, handle, 0, ambient_temperature});
    if (!state.insert_index(key, record)) {
        state.journal.fail();
        if (state.regions != nullptr) state.regions->fail();
        return DiscoveryOutcome::Invalid;
    }
    if (state.regions != nullptr) {
        const auto region_outcome = state.regions->register_unknown(key, bounds, 1);
        if (region_outcome != RegionOutcome::Accepted) {
            state.journal.fail();
            state.regions->fail();
            return DiscoveryOutcome::Invalid;
        }
    }
    add(state.metrics.mapped_tiles);
    return DiscoveryOutcome::Accepted;
}

DiscoveryOutcome SettledWorldDiscoveryCoordinator::dirty(
    DiscoveryTileKey key, ProducerReason reason, std::uint64_t tick) noexcept {
    auto& state = *impl_;
    add(state.metrics.notifications[static_cast<std::size_t>(reason)]);
    const auto record = state.find_record(key);
    if (!record.has_value()) return DiscoveryOutcome::Stale;
    const auto outcome = state.journal.dirty(state.records[*record].handle, tick);
    if (outcome == DiscoveryOutcome::Accepted) {
        add(state.metrics.invalidated_tiles[static_cast<std::size_t>(reason)]);
        if (state.regions != nullptr) {
            const auto summary = state.journal.snapshot(state.records[*record].handle);
            if (summary.has_value()) {
                (void)state.regions->invalidate(key, summary->revision);
                state.records[*record].region_payload_revision = 0;
            }
        }
    }
    return outcome;
}

DiscoveryOutcome SettledWorldDiscoveryCoordinator::observe(
    DiscoveryTileKey key, DiscoverySignals signals, ProducerReason reason,
    std::uint64_t tick) noexcept {
    auto& state = *impl_;
    add(state.metrics.notifications[static_cast<std::size_t>(reason)]);
    add(state.metrics.signal_observations);
    const auto record_index = state.find_record(key);
    if (!record_index.has_value()) return DiscoveryOutcome::Stale;
    auto& record = state.records[*record_index];
    const auto outcome = state.journal.observe(record.handle, signals, tick);
    if (outcome == DiscoveryOutcome::Accepted) {
        record.signals = signals;
        add(state.metrics.invalidated_tiles[static_cast<std::size_t>(reason)]);
        if (state.regions != nullptr) {
            const auto summary = state.journal.snapshot(record.handle);
            if (summary.has_value()) {
                (void)state.regions->invalidate(key, summary->revision);
                record.region_payload_revision = 0;
            }
        }
    } else if (outcome == DiscoveryOutcome::Unchanged) {
        record.signals = signals;
    }
    return outcome;
}

std::size_t SettledWorldDiscoveryCoordinator::advance(
    std::uint64_t tick, std::size_t budget, const void* context,
    ReadCellFunction read) {
    if (read == nullptr) throw std::invalid_argument("settled discovery read callback is null");
    auto& state = *impl_;
    try {
        return state.journal.advance_with_publication(tick, budget,
            [context, read](std::int64_t x, std::int64_t y) { return read(context, x, y); },
            [&state, context, read](const DiscoverySummary& summary) {
                if (state.regions == nullptr || summary.handle.slot >= state.records.size()) return;
                auto& record = state.records[summary.handle.slot];
                if (summary.classification == DiscoveryClass::Invalid ||
                    summary.classification == DiscoveryClass::Blocked ||
                    !record.signals.inspectable() ||
                    record.region_payload_revision == summary.revision) return;
                const auto area = static_cast<std::size_t>(record.bounds.width) * record.bounds.height;
                for (std::uint32_t y = 0; y < record.bounds.height; ++y)
                    for (std::uint32_t x = 0; x < record.bounds.width; ++x) {
                        const auto index = static_cast<std::size_t>(y) * record.bounds.width + x;
                        state.region_scratch[index] = read(context,
                            record.bounds.x + static_cast<std::int64_t>(x),
                            record.bounds.y + static_cast<std::int64_t>(y));
                    }
                const RegionTileInput input{
                    record.key,
                    record.bounds,
                    summary.revision,
                    record.ambient_temperature,
                    record.signals,
                    std::span<const DiscoveryCell>{state.region_scratch.data(), area},
                    0x0f,
                };
                const auto outcome = state.regions->upsert(input);
                if (outcome == RegionOutcome::Invalid || outcome == RegionOutcome::Stale) {
                    state.journal.fail();
                    state.regions->fail();
                    return;
                }
                record.region_payload_revision = summary.revision;
            });
    } catch (...) {
        if (state.regions != nullptr) state.regions->fail(RegionRefusal::SourceFailure);
        throw;
    }
}

std::size_t SettledWorldDiscoveryCoordinator::advance_regions(std::size_t budget) noexcept {
    return impl_->regions == nullptr ? 0 : impl_->regions->advance(budget);
}

void SettledWorldDiscoveryCoordinator::fail() noexcept {
    impl_->journal.fail();
    if (impl_->regions != nullptr) impl_->regions->fail(RegionRefusal::SourceFailure);
}
void SettledWorldDiscoveryCoordinator::note_global_fence() noexcept {
    add(impl_->metrics.global_fences);
}

std::optional<WorldDiscoveryTileSnapshot> SettledWorldDiscoveryCoordinator::tile(
    std::size_t index) const noexcept {
    const auto& state = *impl_;
    if (index >= state.records.size()) return std::nullopt;
    const auto& record = state.records[index];
    const auto summary = state.journal.snapshot(record.handle);
    if (!summary.has_value()) return std::nullopt;
    return WorldDiscoveryTileSnapshot{record.key, record.signals, *summary};
}

std::optional<std::size_t> SettledWorldDiscoveryCoordinator::find(
    DiscoveryTileKey key) const noexcept { return impl_->find_record(key); }
std::size_t SettledWorldDiscoveryCoordinator::size() const noexcept { return impl_->records.size(); }
std::size_t SettledWorldDiscoveryCoordinator::capacity() const noexcept { return impl_->tile_capacity; }
std::size_t SettledWorldDiscoveryCoordinator::pending() const noexcept { return impl_->journal.pending(); }
std::uint64_t SettledWorldDiscoveryCoordinator::incarnation() const noexcept { return impl_->incarnation; }
bool SettledWorldDiscoveryCoordinator::capacity_blocked() const noexcept { return impl_->capacity_blocked; }
DiscoveryHalt SettledWorldDiscoveryCoordinator::halted() const noexcept { return impl_->journal.halted(); }
WorldDiscoveryMetrics SettledWorldDiscoveryCoordinator::producer_metrics() const noexcept { return impl_->metrics; }
DiscoveryMetrics SettledWorldDiscoveryCoordinator::journal_metrics() const noexcept { return impl_->journal.metrics(); }
std::size_t SettledWorldDiscoveryCoordinator::storage_bytes() const noexcept {
    const auto& state = *impl_;
    return sizeof(Impl) + state.records.capacity() * sizeof(Impl::Record) +
           state.index.capacity() * sizeof(Impl::IndexEntry);
}
bool SettledWorldDiscoveryCoordinator::regions_enabled() const noexcept {
    return impl_->regions != nullptr;
}
std::size_t SettledWorldDiscoveryCoordinator::region_count() const noexcept {
    return impl_->regions == nullptr ? 0 : impl_->regions->region_count();
}
std::optional<SettledRegionSnapshot> SettledWorldDiscoveryCoordinator::region(
    std::size_t slot) const noexcept {
    return impl_->regions == nullptr ? std::nullopt : impl_->regions->region_at(slot);
}
SettledRegionMetrics SettledWorldDiscoveryCoordinator::region_metrics() const noexcept {
    return impl_->regions == nullptr ? SettledRegionMetrics{} : impl_->regions->metrics();
}
RegionRefusal SettledWorldDiscoveryCoordinator::region_refusal() const noexcept {
    return impl_->regions == nullptr ? RegionRefusal::None : impl_->regions->last_refusal();
}
std::size_t SettledWorldDiscoveryCoordinator::region_storage_bytes() const noexcept {
    return impl_->regions == nullptr ? 0 : sizeof(Impl::Regions);
}

} // namespace cybersand::soliding
