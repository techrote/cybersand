// Experimental neutral storage only. No World, solver, tick timer or production substitution.
#include "cybersand/precision_storage.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#ifndef MAT003_TAIL_BITS
#error MAT003_TAIL_BITS must be 8 or 16
#endif
static_assert(MAT003_TAIL_BITS == 8 || MAT003_TAIL_BITS == 16);
using Tail = std::conditional_t<MAT003_TAIL_BITS == 8, std::uint8_t, std::uint16_t>;
using Cell = cybersand::detail::PrecisionStorage;
constexpr std::size_t chunk_cells = 128 * 128;
constexpr unsigned tail_max = std::numeric_limits<Tail>::max();
std::uint64_t checks = 0;
void require(bool value, const char* message) {
    ++checks;
    if (!value) throw std::runtime_error(message);
}
struct Record {
    std::uint64_t bits = 0;
    unsigned tail = 0;
    bool operator==(const Record&) const = default;
};

class Store {
    std::vector<Cell> cells_;
    std::vector<std::unique_ptr<Tail[]>> tails_;
    std::size_t quota_;
public:
    std::uint64_t reads = 0, writes = 0, allocations = 0, refusals = 0, reclaims = 0;
    Store(std::size_t chunks, std::size_t quota) : cells_(chunks * chunk_cells), tails_(chunks), quota_(quota) {
        require(chunks > 0 && quota <= chunks, "owner bound");
    }
    std::size_t size() const { return cells_.size(); }
    std::size_t owners() const { return tails_.size(); }
    std::size_t allocated() const {
        return static_cast<std::size_t>(std::count_if(tails_.begin(), tails_.end(), [](const auto& p) { return bool(p); }));
    }
    bool owns(std::size_t chunk) const { return chunk < owners() && bool(tails_[chunk]); }
    // All allocation happens in this explicit quiescent preflight. Field operations
    // below never allocate. A failed staged allocation cannot publish a partial owner.
    bool preflight(std::vector<std::size_t> chunks, int fail_after = -1) {
        std::sort(chunks.begin(), chunks.end());
        chunks.erase(std::unique(chunks.begin(), chunks.end()), chunks.end());
        if (std::any_of(chunks.begin(), chunks.end(), [this](auto c) { return c >= owners(); })) { ++refusals; return false; }
        chunks.erase(std::remove_if(chunks.begin(), chunks.end(), [this](auto c) { return owns(c); }), chunks.end());
        if (chunks.size() > quota_ - allocated()) { ++refusals; return false; }
        std::vector<std::pair<std::size_t, std::unique_ptr<Tail[]>>> staged;
        try {
            staged.reserve(chunks.size());
            for (auto c : chunks) {
                if (fail_after == 0) throw std::bad_alloc();
                if (fail_after > 0) --fail_after;
                staged.emplace_back(c, std::make_unique<Tail[]>(chunk_cells));
            }
        } catch (const std::bad_alloc&) { ++refusals; return false; }
        for (auto& entry : staged) { tails_[entry.first] = std::move(entry.second); ++allocations; }
        return true;
    }
    Record peek(std::size_t index) const {
        if (index >= size()) throw std::out_of_range("cell coordinate");
        const auto chunk = index / chunk_cells;
        return {cells_[index].bits, tails_[chunk] ? unsigned(tails_[chunk][index % chunk_cells]) : 0U};
    }
    Record get(std::size_t index) { ++reads; return peek(index); }
    bool writable(std::size_t index, Record value) const {
        return index < size() && value.tail <= tail_max && (value.tail == 0 || owns(index / chunk_cells));
    }
    bool put(std::size_t index, Record value) {
        if (!writable(index, value)) { ++refusals; return false; }
        cells_[index].bits = value.bits;
        if (owns(index / chunk_cells)) tails_[index / chunk_cells][index % chunk_cells] = static_cast<Tail>(value.tail);
        ++writes;
        return true;
    }
    bool copy(std::size_t source, std::size_t destination) { return put(destination, get(source)); }
    bool move(std::size_t source, std::size_t destination) {
        if (source == destination) return true;
        const auto value = get(source);
        if (!writable(destination, value)) { ++refusals; return false; }
        return put(destination, value) && put(source, {});
    }
    bool swap(std::size_t a, std::size_t b) {
        const auto x = get(a), y = get(b);
        if (!writable(a, y) || !writable(b, x)) { ++refusals; return false; }
        return put(a, y) && put(b, x);
    }
    // Synthetic neutral-count split/merge. This does not assign physical meaning.
    bool split(std::size_t source, std::size_t destination, unsigned amount) {
        if (source == destination) return amount == 0;
        auto a = get(source), b = get(destination);
        if (amount > a.tail || amount > tail_max - b.tail) { ++refusals; return false; }
        a.tail -= amount; b.tail += amount;
        if (!writable(source, a) || !writable(destination, b)) { ++refusals; return false; }
        return put(source, a) && put(destination, b);
    }
    bool reclaim(std::size_t chunk) {
        if (!owns(chunk)) return true;
        if (std::any_of(tails_[chunk].get(), tails_[chunk].get() + chunk_cells, [](Tail v) { return v != 0; })) { ++refusals; return false; }
        tails_[chunk].reset(); ++reclaims; return true;
    }
    void reset() {
        std::fill(cells_.begin(), cells_.end(), Cell{});
        for (auto& p : tails_) p.reset();
    }
    std::uint64_t base_bytes() const { return cells_.capacity() * sizeof(Cell); }
    std::uint64_t pointer_bytes() const { return tails_.capacity() * sizeof(std::unique_ptr<Tail[]>); }
    std::uint64_t tail_bytes() const { return allocated() * chunk_cells * sizeof(Tail); }
};

std::uint64_t mix(std::uint64_t h, std::uint64_t value) {
    for (unsigned i = 0; i < 8; ++i) { h ^= value & 255U; h *= 1099511628211ULL; value >>= 8; }
    return h;
}
std::uint64_t fingerprint(const Store& store) {
    auto h = 1469598103934665603ULL;
    for (std::size_t i = 0; i < store.size(); ++i) { const auto r = store.peek(i); h = mix(mix(h, r.bits), r.tail); }
    for (std::size_t i = 0; i < store.owners(); ++i) h = mix(h, store.owns(i));
    return h;
}
void equal(const Store& store, const std::vector<Record>& reference) {
    require(store.size() == reference.size(), "reference size");
    for (std::size_t i = 0; i < store.size(); ++i) require(store.peek(i) == reference[i], "independent dense reference");
}

void lifecycle() {
    Store s(4, 2);
    const auto fresh = fingerprint(s);
    require(!s.put(0, {0xFEDCBA9876543210ULL, tail_max}), "missing owner refused");
    require(fingerprint(s) == fresh && s.allocated() == 0, "refusal nonmutation");
    require(!s.preflight({0, 1}, 1), "injected second allocation refusal");
    require(fingerprint(s) == fresh && s.allocated() == 0, "staged allocation rollback");
    require(!s.preflight({0, 1, 2}) && !s.preflight({4}), "quota and owner bounds");
    require(s.preflight({0, 1, 1}), "deduplicated reservation");
    require(s.put(0, {0xFEDCBA9876543210ULL, tail_max}), "high base and high tail write");
    const auto high = fingerprint(s);
    require(!s.put(0, {0, tail_max + 1U}) && fingerprint(s) == high, "tail width refusal");
    require(!s.put(s.size(), {}) && fingerprint(s) == high, "index refusal");
    require(!s.move(0, chunk_cells * 2) && fingerprint(s) == high, "move owner refusal");
    require(s.copy(0, chunk_cells + 7), "cross-chunk copy");
    require(s.peek(0) == s.peek(chunk_cells + 7), "complete copy tuple");
    require(s.move(chunk_cells + 7, chunk_cells + 8) && s.peek(chunk_cells + 7) == Record{}, "move source reset");
    require(s.put(1, {0x800100FFFF0000AAULL, 0}) && s.swap(0, 1), "whole tuple swap");
    require(s.peek(1).tail == tail_max && s.peek(0).bits == 0x800100FFFF0000AAULL, "swap preserves unrelated base bits");
    require(s.split(1, 2, tail_max / 2), "neutral split");
    require(s.peek(1).tail + s.peek(2).tail == tail_max, "neutral split exact total");
    require(s.split(2, 1, s.peek(2).tail), "neutral merge");
    require(s.peek(1).tail == tail_max && s.peek(2).tail == 0, "neutral merge exact total");
    require(!s.reclaim(0), "nonzero owner cannot be reclaimed");
    require(s.put(1, {}) && s.reclaim(0), "zero owner reclaimed");
    require(!s.owns(0) && s.get(1) == Record{}, "absent default after reclaim");
    s.reset();
    require(s.allocated() == 0 && fingerprint(s) == fresh, "complete reset");
}

std::uint64_t random64(std::uint64_t& state) {
    state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state;
}
std::size_t physical(std::size_t logical, std::size_t chunks, bool dispersed) {
    return dispersed ? (logical % chunks) * chunk_cells + logical / chunks : logical;
}

int main(int argc, char** argv) {
    try {
        if (argc != 3) throw std::runtime_error("expected side and registered state");
        const auto side = std::stoul(argv[1]); const std::string mode = argv[2];
        require(side == 512 || side == 1024 || side == 2048, "registered side");
        require(mode == "absent" || mode == "allocated-unread" || mode == "accessed-clustered" || mode == "accessed-dispersed", "registered state");
        lifecycle();
        const std::size_t chunks = (side / 128) * (side / 128);
        Store store(chunks, chunks);
        std::vector<Record> reference(store.size());
        const bool accessed = mode.starts_with("accessed-");
        const bool dispersed = mode == "accessed-dispersed";
        std::vector<std::size_t> owners;
        if (mode == "allocated-unread" || accessed) {
            if (dispersed) { for (std::size_t i = 0; i < chunks; ++i) owners.push_back(i); }
            else owners = {0, 1};
            require(store.preflight(owners), "registered owner allocation");
        }
        if (mode == "absent") require(store.get(0) == Record{} && store.allocated() == 0, "default read does not allocate");
        std::uint64_t seed = 204;
        if (accessed) {
            for (std::size_t i = 0; i < 8192; ++i) {
                const auto at = physical(i, chunks, dispersed);
                const Record value{random64(seed), static_cast<unsigned>((i % tail_max) + 1)};
                require(store.put(at, value), "initial neutral payload"); reference[at] = value;
            }
            for (std::size_t i = 0; i < 8192; ++i) {
                const auto a = physical(random64(seed) % 8192, chunks, dispersed);
                auto b = physical(random64(seed) % 8192, chunks, dispersed);
                if (a == b) b = physical((random64(seed) % 8191 + 1) % 8192, chunks, dispersed);
                const auto x = reference[a], y = reference[b];
                switch (i % 8) {
                case 0: require(store.copy(a, b), "copy stream"); reference[b] = x; break;
                case 1:
                    require(store.move(a, b), "move stream");
                    if (a != b) { reference[b] = x; reference[a] = {}; } break;
                case 2: require(store.swap(a, b), "swap stream"); std::swap(reference[a], reference[b]); break;
                case 3: require(store.put(a, {}), "replacement stream"); reference[a] = {}; break;
                case 4: case 5: {
                    const unsigned amount = i % 8 == 5 ? x.tail : x.tail / 2;
                    const bool ok = a == b ? amount == 0 : amount <= tail_max - y.tail;
                    require(store.split(a, b, amount) == ok, "split/merge capacity reference");
                    if (ok && a != b) { reference[a].tail -= amount; reference[b].tail += amount; }
                    break;
                }
                case 6: {
                    const Record value{random64(seed), static_cast<unsigned>(random64(seed) & tail_max)};
                    require(store.put(a, value), "field write stream"); reference[a] = value; break;
                }
                default: require(store.get(a) == x, "read stream"); break;
                }
            }
        }
        const auto consumer_reads = store.reads, consumer_writes = store.writes;
        equal(store, reference);
        std::uint64_t nonzero = 0;
        for (const auto& r : reference) nonzero += r.tail != 0;
        require(store.tail_bytes() == store.allocated() * chunk_cells * sizeof(Tail), "tail allocation accounting");
        if (mode == "allocated-unread") require(consumer_reads == 0 && consumer_writes == 0 && store.allocated() == 2, "allocated unread is not accessed");
        if (accessed) require(nonzero > 0 && consumer_reads > 0 && consumer_writes > 0, "nonvacuous accessed population");
        auto projection = 1469598103934665603ULL;
        for (std::size_t i = 0; i < 8192; ++i) {
            const auto r = store.peek(physical(i, chunks, dispersed));
            projection = mix(mix(projection, r.bits), r.tail);
        }
        std::cout << "{\"status\":\"passed\",\"timing\":false,\"tail_bits\":" << MAT003_TAIL_BITS
                  << ",\"side\":" << side << ",\"mode\":\"" << mode << "\",\"checks\":" << checks
                  << ",\"cell_size\":" << sizeof(Cell) << ",\"cell_alignment\":" << alignof(Cell)
                  << ",\"tail_element_size\":" << sizeof(Tail) << ",\"tail_element_alignment\":" << alignof(Tail)
                  << ",\"owner_object_size\":" << sizeof(Store) << ",\"base_capacity_bytes\":" << store.base_bytes()
                  << ",\"pointer_capacity_bytes\":" << store.pointer_bytes() << ",\"tail_array_bytes\":" << store.tail_bytes()
                  << ",\"allocated_owners\":" << store.allocated() << ",\"resident_owners\":" << chunks
                  << ",\"dense_tail_arithmetic_bytes\":" << store.size() * sizeof(Tail)
                  << ",\"nonzero_payloads\":" << nonzero << ",\"consumer_reads\":" << consumer_reads
                  << ",\"consumer_writes\":" << consumer_writes << ",\"allocations\":" << store.allocations
                  << ",\"refusals\":" << store.refusals << ",\"operation_projection_hash\":" << projection
                  << ",\"logical_hash\":" << fingerprint(store) << "}\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
