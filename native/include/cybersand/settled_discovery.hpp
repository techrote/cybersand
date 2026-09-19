#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <optional>

// Stage 3 substrate only: the serialized producer supplies complete invalidation
// and activity signals. This is NOT wired into World and cannot authorize skips,
// cohesion, colliders or transfers. It owns observations, never material.
namespace cybersand::soliding {

struct DiscoveryCell {
    std::uint8_t material{};
    std::uint16_t state_a{};
    std::uint8_t state_b{};
    std::int16_t temperature{};
    bool occupied{};
    bool operator==(const DiscoveryCell&) const = default;
};
struct DiscoveryBounds {
    std::int64_t x{}, y{};
    std::uint32_t width{}, height{};
    bool operator==(const DiscoveryBounds&) const = default;
};
struct DiscoveryHandle {
    std::uint64_t incarnation{};
    std::uint32_t slot{};
    bool operator==(const DiscoveryHandle&) const = default;
};
struct DiscoverySignals {
    bool witness_complete{};
    bool healthy{};
    bool included{};
    bool active{true};
    bool pending_event{};
    bool occupied{};
    bool operator==(const DiscoverySignals&) const = default;
    [[nodiscard]] bool inspectable() const noexcept {
        return witness_complete && healthy && included && !active && !pending_event && !occupied;
    }
};
enum class DiscoveryClass : std::uint8_t { Invalid, Blocked, Empty, Uniform, Mixed };
enum class DiscoveryOutcome : std::uint8_t { Accepted, Unchanged, Stale, Invalid, Capacity, Halted };
enum class DiscoveryHalt : std::uint8_t { None, RevisionExhausted, InvalidClock, SourceFailure, ProducerFailure };
struct DiscoverySummary {
    DiscoveryHandle handle{};
    DiscoveryBounds bounds{};
    DiscoveryClass classification{DiscoveryClass::Invalid};
    DiscoveryCell uniform{};
    std::uint64_t revision{}, classified_tick{}, dirty_tick{};
    // Uniform describes a complete tile, not a connected region or eligibility.
};
struct DiscoveryMetrics {
    std::uint64_t cells_inspected{}, blocks_started{}, work_units{}, signal_observations{};
    std::uint64_t invalidations{}, restarts{}, publications{}, blocked{}, mixed{}, refusals{};
    std::uint64_t queue_high_water{}, latency_max_ticks{}, latency_total_ticks{};
};

// One deduplicated queue entry per registered slot: queue capacity == Slots.
// There is no overflow list, allocation, slot reuse or hot resize. Registration
// is a bounded setup operation; unregister/reset requires a new unique incarnation.
// Saturation refuses new blocks and leaves existing observations/cells intact.
template<std::size_t Slots, std::uint32_t MaximumBlockCells = 1024,
         std::uint64_t RevisionLimit = std::numeric_limits<std::uint64_t>::max()>
class SettledDiscovery {
    static_assert(Slots > 0 && Slots <= std::numeric_limits<std::uint32_t>::max());
    static_assert(MaximumBlockCells > 0 && RevisionLimit > 0);
public:
    explicit SettledDiscovery(std::uint64_t unique_incarnation) noexcept : incarnation_(unique_incarnation) {}
    SettledDiscovery(const SettledDiscovery&) = delete;
    SettledDiscovery& operator=(const SettledDiscovery&) = delete;
    SettledDiscovery(SettledDiscovery&&) = delete;
    SettledDiscovery& operator=(SettledDiscovery&&) = delete;

    DiscoveryOutcome register_block(DiscoveryBounds bounds, DiscoverySignals signals,
                                    std::uint64_t tick, DiscoveryHandle& output) noexcept {
        if (halt_ != DiscoveryHalt::None) return DiscoveryOutcome::Halted;
        const auto area = static_cast<std::uint64_t>(bounds.width) * bounds.height;
        if (incarnation_ == 0 || area == 0 || area > MaximumBlockCells ||
            bounds.x > std::numeric_limits<std::int64_t>::max() - (bounds.width - 1) ||
            bounds.y > std::numeric_limits<std::int64_t>::max() - (bounds.height - 1))
            return DiscoveryOutcome::Invalid;
        for (std::size_t i = 0; i < count_; ++i)
            if (records_[i].summary.bounds == bounds) return DiscoveryOutcome::Invalid;
        if (count_ == Slots) { increment(metrics_.refusals); return DiscoveryOutcome::Capacity; }
        if (!clock(tick)) return DiscoveryOutcome::Halted;
        const auto index = count_++;
        auto& record = records_[index];
        record.summary.handle = {incarnation_, static_cast<std::uint32_t>(index)};
        record.summary.bounds = bounds;
        record.summary.revision = 1;
        record.summary.dirty_tick = tick;
        record.signals = signals;
        output = record.summary.handle;
        enqueue(index);
        return DiscoveryOutcome::Accepted;
    }

    // Must be called for every relevant mutation, even change-and-restore, plus
    // affected halo dependents. Render publication cannot acknowledge this journal.
    DiscoveryOutcome dirty(DiscoveryHandle handle, std::uint64_t tick) noexcept {
        auto* record = find(handle);
        if (!record) return DiscoveryOutcome::Stale;
        if (!clock(tick)) return DiscoveryOutcome::Halted;
        return invalidate(*record, tick);
    }
    DiscoveryOutcome observe(DiscoveryHandle handle, DiscoverySignals signals,
                              std::uint64_t tick) noexcept {
        auto* record = find(handle);
        if (!record) return DiscoveryOutcome::Stale;
        if (!clock(tick)) return DiscoveryOutcome::Halted;
        increment(metrics_.signal_observations);
        if (record->signals == signals) return DiscoveryOutcome::Unchanged;
        record->signals = signals;
        return invalidate(*record, tick);
    }

    // Each dequeue/start, individual cell read and final validation/publication
    // costs one unit. A source read must be bounded, read-only and owner-serialized.
    // Calls may span ticks. No partially scanned tile is publicly classified.
    template<class ReadCell>
    std::size_t advance(std::uint64_t tick, std::size_t budget, ReadCell&& read) {
        if (!clock(tick)) return 0;
        std::size_t used = 0;
        try {
            while (used < budget && queued_ != 0) {
                auto& record = records_[queue_[head_]];
                ++used;
                increment(metrics_.work_units);
                if (!record.scanning) {
                    increment(metrics_.blocks_started);
                    if (!record.signals.inspectable()) {
                        record.summary.classification = DiscoveryClass::Blocked;
                        record.summary.classified_tick = tick;
                        increment(metrics_.blocked);
                        publication(record, tick);
                        pop(record);
                        continue;
                    }
                    record.scanning = true;
                    record.cursor = 0;
                    record.scan_revision = record.summary.revision;
                    record.mixed = false;
                    record.saw_occupied = false;
                    continue;
                }
                const auto& bounds = record.summary.bounds;
                const auto area = static_cast<std::uint64_t>(bounds.width) * bounds.height;
                if (record.cursor < area) {
                    const auto value = read(bounds.x + record.cursor % bounds.width,
                                            bounds.y + record.cursor / bounds.width);
                    increment(metrics_.cells_inspected);
                    if (record.cursor == 0) record.first = value;
                    else if (value != record.first) record.mixed = true;
                    record.saw_occupied = record.saw_occupied || value.occupied;
                    ++record.cursor;
                    continue;
                }
                // Mutations supplied between advances reset scanning and revision.
                // This check also makes the full-result publication witness explicit.
                if (record.scan_revision != record.summary.revision || !record.signals.inspectable()) {
                    record.scanning = false;
                    increment(metrics_.restarts);
                    continue;
                }
                record.summary.uniform = record.first;
                record.summary.classification = record.saw_occupied ? DiscoveryClass::Blocked
                    : record.mixed ? DiscoveryClass::Mixed
                    : record.first.material == 0 ? DiscoveryClass::Empty : DiscoveryClass::Uniform;
                record.summary.classified_tick = tick;
                publication(record, tick);
                if (record.mixed) increment(metrics_.mixed);
                if (record.saw_occupied) increment(metrics_.blocked);
                pop(record);
            }
        } catch (...) {
            if (halt_ == DiscoveryHalt::None) halt_ = DiscoveryHalt::SourceFailure;
            throw;
        }
        return used;
    }

    [[nodiscard]] std::optional<DiscoverySummary> snapshot(DiscoveryHandle handle) const noexcept {
        if (halt_ != DiscoveryHalt::None || handle.incarnation != incarnation_ || handle.slot >= count_)
            return std::nullopt;
        return records_[handle.slot].summary; // immutable value; never live World bytes
    }
    void fail() noexcept { if (halt_ == DiscoveryHalt::None) halt_ = DiscoveryHalt::ProducerFailure; }
    [[nodiscard]] DiscoveryHalt halted() const noexcept { return halt_; }
    [[nodiscard]] DiscoveryMetrics metrics() const noexcept { return metrics_; }
    [[nodiscard]] std::size_t pending() const noexcept { return queued_; }
    [[nodiscard]] std::size_t size() const noexcept { return count_; }
    [[nodiscard]] static constexpr std::size_t storage_bytes() noexcept { return sizeof(SettledDiscovery); }

private:
    struct Record {
        DiscoverySummary summary{};
        DiscoverySignals signals{};
        DiscoveryCell first{};
        std::uint64_t scan_revision{};
        std::uint32_t cursor{};
        bool queued{}, scanning{}, mixed{}, saw_occupied{};
    };
    static void add(std::uint64_t& value, std::uint64_t amount) noexcept {
        const auto remaining = std::numeric_limits<std::uint64_t>::max() - value;
        value += amount > remaining ? remaining : amount;
    }
    static void increment(std::uint64_t& value) noexcept { add(value, 1); }
    bool clock(std::uint64_t tick) noexcept {
        if (halt_ != DiscoveryHalt::None) return false;
        if (tick < clock_) { halt_ = DiscoveryHalt::InvalidClock; return false; }
        clock_ = tick;
        return true;
    }
    Record* find(DiscoveryHandle handle) noexcept {
        return handle.incarnation == incarnation_ && handle.slot < count_ ? &records_[handle.slot] : nullptr;
    }
    void publication(const Record& record, std::uint64_t tick) noexcept {
        const auto latency = tick - record.summary.dirty_tick;
        if (latency > metrics_.latency_max_ticks) metrics_.latency_max_ticks = latency;
        add(metrics_.latency_total_ticks, latency);
        increment(metrics_.publications); // Includes explicit Blocked classifications.
    }
    void enqueue(std::size_t index) noexcept {
        auto& record = records_[index];
        if (record.queued) return;
        record.queued = true;
        queue_[(head_ + queued_) % Slots] = index;
        ++queued_;
        if (queued_ > metrics_.queue_high_water) metrics_.queue_high_water = queued_;
    }
    void pop(Record& record) noexcept {
        record.queued = record.scanning = false;
        head_ = (head_ + 1) % Slots;
        --queued_;
    }
    DiscoveryOutcome invalidate(Record& record, std::uint64_t tick) noexcept {
        if (record.summary.revision == RevisionLimit) {
            halt_ = DiscoveryHalt::RevisionExhausted;
            return DiscoveryOutcome::Halted;
        }
        ++record.summary.revision;
        increment(metrics_.invalidations);
        if (record.scanning) {
            increment(metrics_.restarts);
            // A repeatedly changed head must not starve quiet blocks behind it.
            // Rotation is constant work charged to invalidation, never a scan.
            if (queued_ > 1 && queue_[head_] == record.summary.handle.slot) {
                queue_[(head_ + queued_) % Slots] = queue_[head_];
                head_ = (head_ + 1) % Slots;
            }
        }
        // Preserve the first outstanding dirty tick, so churn cannot hide latency.
        if (!record.queued) record.summary.dirty_tick = tick;
        record.summary.classification = DiscoveryClass::Invalid;
        record.scanning = false;
        enqueue(record.summary.handle.slot);
        return DiscoveryOutcome::Accepted;
    }
    std::uint64_t incarnation_{}, clock_{};
    DiscoveryHalt halt_{DiscoveryHalt::None};
    std::size_t count_{}, head_{}, queued_{};
    DiscoveryMetrics metrics_{};
    std::array<Record, Slots> records_{};
    std::array<std::size_t, Slots> queue_{};
};
} // namespace cybersand::soliding
