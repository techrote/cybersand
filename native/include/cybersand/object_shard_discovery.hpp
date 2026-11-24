#pragma once

#include "cybersand/object_shard.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <limits>
#include <span>
#include <vector>

namespace cybersand::object_shard {

enum class AdmissionReason : std::uint8_t {
    None, Discovering, Ready, Anchored, UnknownBoundary, ComponentCells,
    BoundingBox, ShapeLimit, BodySlots, TotalArea, PendingEvent, Obstructed,
    StorageCapacity, StalePayload
};
inline const char* admission_reason_name(AdmissionReason reason) noexcept {
    switch (reason) {
#define CS_ADMISSION(name) case AdmissionReason::name: return #name
    CS_ADMISSION(None); CS_ADMISSION(Discovering); CS_ADMISSION(Ready);
    CS_ADMISSION(Anchored); CS_ADMISSION(UnknownBoundary); CS_ADMISSION(ComponentCells);
    CS_ADMISSION(BoundingBox); CS_ADMISSION(ShapeLimit); CS_ADMISSION(BodySlots);
    CS_ADMISSION(TotalArea); CS_ADMISSION(PendingEvent); CS_ADMISSION(Obstructed);
    CS_ADMISSION(StorageCapacity); CS_ADMISSION(StalePayload);
#undef CS_ADMISSION
    }
    return "Invalid";
}
struct AdmissionCandidate {
    std::int64_t x{}, y{};
    std::uint32_t cells{}, bbox_area{};
    std::uint64_t age{}; // Completed admissions waited; independent of frame rate.
    AdmissionReason reason{AdmissionReason::None};
};
struct AdmissionStatus {
    bool census_complete{};
    std::uint32_t pending_mutations{}, pending_seeds{}, frontier_cells{};
    std::uint32_t components{}, eligible{}, deferred{}, anchored{}, unknown_boundary{}, refused_geometry{};
    std::uint32_t slots_used{}, slot_limit{}, active_bodies{}, largest_cells{};
    std::uint32_t work_last{}, work_peak{};
    std::uint64_t completed_components{}, invalidations{}, interrupted_searches{}, cached_capacity_calls{};
    AdmissionReason reason{AdmissionReason::None};
    // Bounded owner diagnostics; counts above cover every cached component.
    std::array<AdmissionCandidate, 16> candidates{};
    std::uint32_t candidate_count{};
};

// A resident, opt-in Lab catalogue. Mutation invalidation costs five labels;
// discovery resumes one BFS rather than restarting a large component each
// frame. Cached membership is derived evidence only: World remains its owner.
// Each coordinate occurs at most once in each fixed-capacity queue. All
// structures are allocated at construction, by the admitted resident area.
class ComponentDiscovery {
public:
    struct Candidate {
        std::uint64_t first_eligible{}, retry_after{};
        std::uint32_t generation{}, cells{}, canonical{}, position{kNone};
        std::uint16_t min_x{}, min_y{}, max_x{}, max_y{};
        Material material{Material::Empty};
        AdmissionReason reason{AdmissionReason::None};
        AdmissionReason blocked_reason{AdmissionReason::None};
        bool valid{}, anchored{}, unknown_boundary{};
        [[nodiscard]] std::uint32_t bbox_area() const noexcept {
            return (static_cast<std::uint32_t>(max_x) - min_x + 3U) *
                (static_cast<std::uint32_t>(max_y) - min_y + 3U);
        }
    };
    ComponentDiscovery(Bounds bounds, Limits limits, bool rooted_architecture = false)
        : bounds_(bounds), limits_(limits), rooted_architecture_(rooted_architecture), labels_(bounds.area(), kNone),
          generations_(bounds.area()), queued_(bounds.area()), queue_(bounds.area()),
          candidates_(bounds.area()) {
        frontier_.reserve(bounds.area()); roots_.reserve(bounds.area());
    }
    void reset() noexcept {
        std::fill(labels_.begin(), labels_.end(), kNone);
        std::fill(generations_.begin(), generations_.end(), 0);
        std::fill(queued_.begin(), queued_.end(), 0);
        std::fill(candidates_.begin(), candidates_.end(), Candidate{});
        roots_.clear(); frontier_.clear(); head_ = count_ = cursor_ = 0;
        active_ = false; generation_ = 0; exhausted_ = false; dirty_ = true;
        completed_ = invalidations_ = interrupted_ = visited_ = 0;
    }
    void invalidate(std::uint32_t at) noexcept {
        if (at >= labels_.size()) return;
        ++invalidations_;
        // Editing a representative coordinate retires its old age witness.
        // A later same-material ABA at that slot is a new candidate.
        candidates_[at].first_eligible=0;
        // The removed coordinate can join/split several neighbours. Retaining
        // all five seeds is what prevents a cut from losing one of its arms.
        visit_neighbours_and_self(at, [&](std::uint32_t cell) {
            if (active_ && labels_[cell] == root_ && generations_[cell] == generation_) {
                const auto old_root = root_;
                active_ = false; frontier_.clear(); cursor_ = 0; ++interrupted_;
                enqueue(old_root);
            }
            invalidate_label(cell);
            enqueue(cell);
        });
        dirty_ = true;
    }
    template<class MaterialAt>
    std::uint32_t advance(std::uint32_t budget, std::uint64_t admission_epoch, MaterialAt material_at) noexcept {
        std::uint32_t used = 0;
        while (used < budget && !exhausted_) {
            if (!active_) {
                if (count_ == 0) break;
                const auto seed = queue_[head_];
                head_ = (head_ + 1) % queue_.size(); --count_; queued_[seed] = 0;
                ++used;
                if (current_label(seed)) continue;
                const auto material = material_at(seed);
                if (!cohesive(material)) continue;
                if (generation_ == std::numeric_limits<std::uint32_t>::max()) { exhausted_ = true; break; }
                ++generation_; root_ = seed; cursor_ = 0; frontier_.clear(); active_ = true;
                const auto age = candidates_[seed].first_eligible;
                candidates_[seed] = {};
                auto& candidate = candidates_[seed];
                candidate.first_eligible = age;
                candidate.generation = generation_; candidate.material = material;
                candidate.canonical = seed;
                candidate.min_x = candidate.max_x = static_cast<std::uint16_t>(seed % bounds_.width);
                candidate.min_y = candidate.max_y = static_cast<std::uint16_t>(seed / bounds_.width);
                enqueue_frontier(seed);
            }
            if (used == budget) break;
            const auto at = frontier_[cursor_++]; ++used; ++visited_;
            auto& candidate = candidates_[root_];
            ++candidate.cells;
            candidate.canonical = std::min(candidate.canonical, at);
            const auto x = static_cast<std::uint16_t>(at % bounds_.width);
            const auto y = static_cast<std::uint16_t>(at / bounds_.width);
            candidate.min_x = std::min(candidate.min_x, x); candidate.max_x = std::max(candidate.max_x, x);
            candidate.min_y = std::min(candidate.min_y, y); candidate.max_y = std::max(candidate.max_y, y);
            candidate.unknown_boundary = candidate.unknown_boundary || x == 0 || y == 0 ||
                x + 1U == bounds_.width || y + 1U == bounds_.height;
            visit_neighbours(at, [&](std::uint32_t next) {
                const auto material = material_at(next);
                candidate.anchored = candidate.anchored || (!rooted_architecture_ && material == Material::Wall);
                if ((rooted_architecture_ ? cohesive(material) : material == candidate.material) &&
                    !(labels_[next] == root_ && generations_[next] == generation_)) {
                    invalidate_label(next);
                    enqueue_frontier(next);
                }
            });
            if (cursor_ == frontier_.size()) {
                candidate.valid = true;
                candidate.reason = candidate.unknown_boundary ? AdmissionReason::UnknownBoundary :
                    candidate.anchored ? AdmissionReason::Anchored :
                    candidate.cells > limits_.max_area ? AdmissionReason::ComponentCells :
                    candidate.bbox_area() > limits_.max_area ? AdmissionReason::BoundingBox : AdmissionReason::Ready;
                if (candidate.reason == AdmissionReason::Ready && candidate.first_eligible == 0)
                    candidate.first_eligible = admission_epoch + 1;
                candidate.position = static_cast<std::uint32_t>(roots_.size()); roots_.push_back(root_);
                active_ = false; ++completed_; dirty_ = true;
            }
        }
        return used;
    }
    [[nodiscard]] bool complete() const noexcept { return count_ == 0 && !active_; }
    [[nodiscard]] bool exhausted() const noexcept { return exhausted_; }
    [[nodiscard]] std::uint32_t pending() const noexcept { return static_cast<std::uint32_t>(count_); }
    [[nodiscard]] std::uint32_t frontier_pending() const noexcept {
        return active_ ? static_cast<std::uint32_t>(frontier_.size() - cursor_) : 0;
    }
    [[nodiscard]] std::uint64_t completed_components() const noexcept { return completed_; }
    [[nodiscard]] std::uint64_t visited_cells() const noexcept { return visited_; }
    [[nodiscard]] std::uint64_t invalidations() const noexcept { return invalidations_; }
    [[nodiscard]] std::uint64_t interrupted_searches() const noexcept { return interrupted_; }
    [[nodiscard]] std::span<const std::uint32_t> roots() const noexcept { return roots_; }
    [[nodiscard]] const Candidate& candidate(std::uint32_t root) const noexcept { return candidates_[root]; }
    [[nodiscard]] bool dirty() const noexcept { return dirty_; }
    void clear_dirty() noexcept { dirty_ = false; }
    void refuse(std::uint32_t root, AdmissionReason reason) noexcept {
        if (root < candidates_.size() && candidates_[root].valid) { candidates_[root].reason = reason; dirty_ = true; }
    }
    void defer(std::uint32_t root, AdmissionReason reason, std::uint64_t retry_after) noexcept {
        auto& c=candidates_[root];c.blocked_reason=reason;c.retry_after=retry_after;dirty_=true;
    }
    void retry(std::uint32_t root) noexcept {
        auto& c=candidates_[root];
        if (c.blocked_reason!=AdmissionReason::None) {c.blocked_reason=AdmissionReason::None;c.retry_after=0;dirty_=true;}
    }
    [[nodiscard]] std::uint32_t select(bool oldest, std::uint32_t available_area, std::uint64_t call) const noexcept {
        std::uint32_t selected = kNone;
        for (const auto root : roots_) {
            const auto& next = candidates_[root];
            if (next.reason != AdmissionReason::Ready || next.bbox_area() > available_area || next.retry_after>call) continue;
            if (selected == kNone) { selected = root; continue; }
            const auto& current = candidates_[selected];
            const bool better = oldest ?
                (next.first_eligible < current.first_eligible ||
                 (next.first_eligible == current.first_eligible && next.canonical < current.canonical)) :
                (next.cells > current.cells || (next.cells == current.cells &&
                 (next.first_eligible < current.first_eligible ||
                  (next.first_eligible == current.first_eligible && next.canonical < current.canonical))));
            if (better) selected = root;
        }
        return selected;
    }
    [[nodiscard]] bool members(std::uint32_t root, std::vector<std::uint32_t>& output) const noexcept {
        output.clear();
        if (root >= candidates_.size() || !candidates_[root].valid) return false;
        const auto& c = candidates_[root];
        if (c.cells > output.capacity()) return false;
        for (std::uint32_t y = c.min_y; y <= c.max_y; ++y)
            for (std::uint32_t x = c.min_x; x <= c.max_x; ++x) {
                const auto at = y * bounds_.width + x;
                if (labels_[at] == root && generations_[at] == c.generation) output.push_back(at);
            }
        return output.size() == c.cells;
    }
    [[nodiscard]] std::size_t storage_bytes() const noexcept {
        return sizeof(*this) + (labels_.capacity() + generations_.capacity() + queue_.capacity() +
            frontier_.capacity() + roots_.capacity()) * sizeof(std::uint32_t) + queued_.capacity() +
            candidates_.capacity() * sizeof(Candidate);
    }
    static constexpr std::uint32_t kNone = std::numeric_limits<std::uint32_t>::max();
private:
    [[nodiscard]] bool cohesive(Material value) const noexcept {
        return rooted_architecture_ ? structural_material_supported(value) :
            value == Material::Wood || value == Material::RedBrick;
    }
    template<class Visitor> void visit_neighbours(std::uint32_t at, Visitor visitor) noexcept {
        const auto width = static_cast<std::uint32_t>(bounds_.width);
        if (at % width) visitor(at - 1);
        if (at % width + 1 < width) visitor(at + 1);
        if (at >= width) visitor(at - width);
        if (at + width < labels_.size()) visitor(at + width);
    }
    template<class Visitor> void visit_neighbours_and_self(std::uint32_t at, Visitor visitor) noexcept {
        visitor(at); visit_neighbours(at, visitor);
    }
    [[nodiscard]] bool current_label(std::uint32_t cell) const noexcept {
        const auto root = labels_[cell];
        return root != kNone && candidates_[root].valid && candidates_[root].generation == generations_[cell];
    }
    void invalidate_label(std::uint32_t cell) noexcept {
        if (!current_label(cell)) return;
        auto& c = candidates_[labels_[cell]];
        const auto moved = roots_.back();
        roots_[c.position] = moved; candidates_[moved].position = c.position; roots_.pop_back();
        c.position = kNone; c.valid = false; dirty_ = true;
    }
    void enqueue(std::uint32_t cell) noexcept {
        if (queued_[cell]) return;
        queued_[cell] = 1; queue_[(head_ + count_) % queue_.size()] = cell; ++count_;
    }
    void enqueue_frontier(std::uint32_t cell) noexcept {
        labels_[cell] = root_; generations_[cell] = generation_; frontier_.push_back(cell);
    }
    Bounds bounds_;
    Limits limits_;
    bool rooted_architecture_{};
    std::vector<std::uint32_t> labels_, generations_;
    std::vector<std::uint8_t> queued_;
    std::vector<std::uint32_t> queue_, frontier_, roots_;
    std::vector<Candidate> candidates_;
    std::size_t head_{}, count_{}, cursor_{};
    std::uint32_t root_{}, generation_{};
    bool active_{}, exhausted_{}, dirty_{true};
    std::uint64_t completed_{}, invalidations_{}, interrupted_{}, visited_{};
};

} // namespace cybersand::object_shard
