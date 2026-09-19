#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <optional>
#include <stdexcept>
#include <utility>

namespace cybersand::soliding {

// Runtime-capacity AVL index backed by one construction-time node pool.
// Nodes are append-only and never move; tree rotations only relink pool indices.
// In-order traversal is therefore canonical key order regardless of insertion order
// or the particular sequence of AVL rotations.
template<class Key, class Value, class Less>
class BoundedOrderedIndex final {
public:
    struct Entry {
        Key key{};
        Value value{};
    };
    enum class InsertResult : std::uint8_t { Inserted, Duplicate, Capacity };

    explicit BoundedOrderedIndex(std::size_t capacity, Less less = Less{})
        : capacity_(checked_capacity(capacity)),
          nodes_(std::make_unique<Node[]>(capacity_)),
          less_(std::move(less)) {}

    BoundedOrderedIndex(const BoundedOrderedIndex&) = delete;
    BoundedOrderedIndex& operator=(const BoundedOrderedIndex&) = delete;
    BoundedOrderedIndex(BoundedOrderedIndex&&) = delete;
    BoundedOrderedIndex& operator=(BoundedOrderedIndex&&) = delete;

    [[nodiscard]] std::optional<Value> find(
        const Key& key, std::size_t* probes = nullptr) const noexcept {
        const auto node = find_node(key, probes);
        return node == npos ? std::nullopt : std::optional<Value>{nodes_[node].value};
    }

    [[nodiscard]] std::optional<Entry> lower_bound(
        const Key& key, std::size_t* probes = nullptr) const noexcept {
        auto current = root_;
        auto best = npos;
        while (current != npos) {
            count_probe(probes);
            if (!less_(nodes_[current].key, key)) {
                best = current;
                current = nodes_[current].left;
            } else {
                current = nodes_[current].right;
            }
        }
        return best == npos ? std::nullopt
                            : std::optional<Entry>{{nodes_[best].key, nodes_[best].value}};
    }

    [[nodiscard]] std::optional<Entry> predecessor(
        const Key& key, std::size_t* probes = nullptr) const noexcept {
        auto current = root_;
        auto best = npos;
        while (current != npos) {
            count_probe(probes);
            if (less_(nodes_[current].key, key)) {
                best = current;
                current = nodes_[current].right;
            } else {
                current = nodes_[current].left;
            }
        }
        return best == npos ? std::nullopt
                            : std::optional<Entry>{{nodes_[best].key, nodes_[best].value}};
    }

    InsertResult insert(const Key& key, const Value& value,
                        std::size_t* probes = nullptr) noexcept {
        if (size_ == capacity_) {
            return find_node(key, probes) == npos ? InsertResult::Capacity
                                                  : InsertResult::Duplicate;
        }
        const auto candidate = size_;
        auto& node = nodes_[candidate];
        node.key = key;
        node.value = value;
        node.left = node.right = npos;
        node.height = 1;

        InsertResult result = InsertResult::Inserted;
        root_ = insert_node(root_, candidate, result, probes);
        if (result == InsertResult::Inserted) ++size_;
        return result;
    }

    template<class Function>
    void for_each_in_order(Function&& function) const {
        traverse(root_, function);
    }

    [[nodiscard]] std::size_t size() const noexcept { return size_; }
    [[nodiscard]] std::size_t capacity() const noexcept { return capacity_; }
    [[nodiscard]] std::size_t height() const noexcept {
        return root_ == npos ? 0U : static_cast<std::size_t>(nodes_[root_].height);
    }
    [[nodiscard]] std::size_t storage_bytes() const noexcept {
        return sizeof(BoundedOrderedIndex) + capacity_ * sizeof(Node);
    }

private:
    static constexpr std::size_t npos = std::numeric_limits<std::size_t>::max();

    struct Node {
        Key key{};
        Value value{};
        std::size_t left{npos}, right{npos};
        std::uint32_t height{1};
    };

    static std::size_t checked_capacity(std::size_t capacity) {
        if (capacity == 0) throw std::invalid_argument("bounded ordered index capacity must be nonzero");
        return capacity;
    }

    static void count_probe(std::size_t* probes) noexcept {
        if (probes != nullptr && *probes != std::numeric_limits<std::size_t>::max()) ++*probes;
    }

    [[nodiscard]] std::uint32_t node_height(std::size_t node) const noexcept {
        return node == npos ? 0U : nodes_[node].height;
    }

    void update_height(std::size_t node) noexcept {
        nodes_[node].height = 1U + std::max(node_height(nodes_[node].left),
                                            node_height(nodes_[node].right));
    }

    [[nodiscard]] int balance(std::size_t node) const noexcept {
        return static_cast<int>(node_height(nodes_[node].left)) -
               static_cast<int>(node_height(nodes_[node].right));
    }

    std::size_t rotate_left(std::size_t root) noexcept {
        const auto pivot = nodes_[root].right;
        const auto transfer = nodes_[pivot].left;
        nodes_[pivot].left = root;
        nodes_[root].right = transfer;
        update_height(root);
        update_height(pivot);
        return pivot;
    }

    std::size_t rotate_right(std::size_t root) noexcept {
        const auto pivot = nodes_[root].left;
        const auto transfer = nodes_[pivot].right;
        nodes_[pivot].right = root;
        nodes_[root].left = transfer;
        update_height(root);
        update_height(pivot);
        return pivot;
    }

    std::size_t rebalance(std::size_t root) noexcept {
        update_height(root);
        const auto skew = balance(root);
        if (skew > 1) {
            if (balance(nodes_[root].left) < 0)
                nodes_[root].left = rotate_left(nodes_[root].left);
            return rotate_right(root);
        }
        if (skew < -1) {
            if (balance(nodes_[root].right) > 0)
                nodes_[root].right = rotate_right(nodes_[root].right);
            return rotate_left(root);
        }
        return root;
    }

    std::size_t insert_node(std::size_t root, std::size_t candidate,
                            InsertResult& result, std::size_t* probes) noexcept {
        if (root == npos) return candidate;
        count_probe(probes);
        if (less_(nodes_[candidate].key, nodes_[root].key)) {
            nodes_[root].left = insert_node(nodes_[root].left, candidate, result, probes);
        } else if (less_(nodes_[root].key, nodes_[candidate].key)) {
            nodes_[root].right = insert_node(nodes_[root].right, candidate, result, probes);
        } else {
            result = InsertResult::Duplicate;
            return root;
        }
        return result == InsertResult::Inserted ? rebalance(root) : root;
    }

    [[nodiscard]] std::size_t find_node(
        const Key& key, std::size_t* probes) const noexcept {
        auto current = root_;
        while (current != npos) {
            count_probe(probes);
            if (less_(key, nodes_[current].key)) {
                current = nodes_[current].left;
            } else if (less_(nodes_[current].key, key)) {
                current = nodes_[current].right;
            } else {
                return current;
            }
        }
        return npos;
    }

    template<class Function>
    void traverse(std::size_t node, Function& function) const {
        if (node == npos) return;
        traverse(nodes_[node].left, function);
        function(nodes_[node].key, nodes_[node].value);
        traverse(nodes_[node].right, function);
    }

    std::size_t capacity_{}, size_{}, root_{npos};
    std::unique_ptr<Node[]> nodes_;
    Less less_;
};

} // namespace cybersand::soliding
