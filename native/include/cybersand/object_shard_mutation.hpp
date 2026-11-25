#pragma once

#include "cybersand/material.hpp"
#include <algorithm>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <vector>

namespace cybersand::object_shard {

// One opt-in bounded journal for the resident Lab, never one World-sized field
// per shard. Ordinary serial writes and merged worker effects converge here.
// Payload witnesses change even on ABA; topology seeds are separately deduped.
class MutationJournal {
public:
    MutationJournal(std::int64_t x, std::int64_t y, std::uint32_t width,
                    std::uint32_t height)
        : x_(x), y_(y), width_(width), height_(height),
          revisions_(checked_area(width, height)),
          materials_(revisions_.size(), Material::Empty),
          queued_(revisions_.size()), queue_(revisions_.size()) {}

    void observe(std::int64_t x, std::int64_t y, Material material) noexcept {
        if (!contains(x, y)) return;
        const auto at = index(x, y);
        if (revision_ == std::numeric_limits<std::uint64_t>::max()) {
            exhausted_ = true;
            return;
        }
        revisions_[at] = ++revision_;
        if (materials_[at] != material) {
            materials_[at] = material;
            if (!queued_[at]) {
                // One bit and one slot per admitted coordinate: no overflow
                // can be hidden by dropping an invalidation.
                if (count_ == queue_.size()) { exhausted_ = true; return; }
                queued_[at] = 1;
                queue_[(head_ + count_) % queue_.size()] = static_cast<std::uint32_t>(at);
                ++count_;
            }
        }
    }
    [[nodiscard]] bool pop(std::int64_t& x, std::int64_t& y) noexcept {
        if (count_ == 0) return false;
        const auto at = queue_[head_];
        head_ = (head_ + 1) % queue_.size();
        --count_; queued_[at] = 0;
        x = x_ + static_cast<std::int64_t>(at % width_);
        y = y_ + static_cast<std::int64_t>(at / width_);
        return true;
    }
    void requeue(std::int64_t x, std::int64_t y) noexcept {
        if (!contains(x,y)) return;
        const auto at=index(x,y);
        if (queued_[at]) return;
        if (count_==queue_.size()) {exhausted_=true;return;}
        queued_[at]=1;
        queue_[(head_+count_)%queue_.size()]=static_cast<std::uint32_t>(at);
        ++count_;
    }
    void invalidate_all() noexcept {
        // Destructive replacement/reset is a new source incarnation. It must
        // invalidate a prepared capture even when the new tuples are identical.
        if (incarnation_ == std::numeric_limits<std::uint64_t>::max()) exhausted_ = true;
        else ++incarnation_;
        for (std::size_t i = 0; i < revisions_.size(); ++i) {
            if (revision_ == std::numeric_limits<std::uint64_t>::max()) { exhausted_ = true; break; }
            revisions_[i] = ++revision_;
            if (!queued_[i]) {
                queued_[i] = 1;
                queue_[(head_ + count_) % queue_.size()] = static_cast<std::uint32_t>(i);
                ++count_;
            }
        }
    }
    void reset_empty() noexcept {
        std::fill(materials_.begin(),materials_.end(),Material::Empty);
        invalidate_all();
    }
    [[nodiscard]] std::uint64_t witness(std::int64_t x, std::int64_t y) const noexcept {
        return contains(x, y) ? revisions_[index(x, y)] : 0;
    }
    [[nodiscard]] std::uint64_t revision() const noexcept { return revision_; }
    [[nodiscard]] std::uint64_t incarnation() const noexcept { return incarnation_; }
    [[nodiscard]] std::size_t pending() const noexcept { return count_; }
    [[nodiscard]] bool exhausted() const noexcept { return exhausted_; }
    [[nodiscard]] std::size_t storage_bytes() const noexcept {
        return revisions_.capacity() * sizeof(std::uint64_t) +
            materials_.capacity() * sizeof(Material) + queued_.capacity() +
            queue_.capacity() * sizeof(std::uint32_t);
    }
private:
    static std::size_t checked_area(std::uint32_t width, std::uint32_t height) {
        if (width == 0 || height == 0 || width > 1024 || height > 1024 ||
            static_cast<std::uint64_t>(width) * height > 262144)
            throw std::invalid_argument("ObjectShard mutation window exceeds admitted bound");
        return static_cast<std::size_t>(width) * height;
    }
    [[nodiscard]] bool contains(std::int64_t x, std::int64_t y) const noexcept {
        return x >= x_ && y >= y_ &&
            static_cast<std::uint64_t>(x) - static_cast<std::uint64_t>(x_) < width_ &&
            static_cast<std::uint64_t>(y) - static_cast<std::uint64_t>(y_) < height_;
    }
    [[nodiscard]] std::size_t index(std::int64_t x, std::int64_t y) const noexcept {
        return static_cast<std::size_t>(y - y_) * width_ + static_cast<std::size_t>(x - x_);
    }
    std::int64_t x_{}, y_{};
    std::uint32_t width_{}, height_{};
    std::uint64_t revision_{}, incarnation_{1};
    bool exhausted_{};
    std::vector<std::uint64_t> revisions_;
    std::vector<Material> materials_;
    std::vector<std::uint8_t> queued_;
    std::vector<std::uint32_t> queue_;
    std::size_t head_{}, count_{};
};

} // namespace cybersand::object_shard
