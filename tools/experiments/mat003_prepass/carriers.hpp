#pragma once
// MAT-003PREPASS S0: isolated storage fixtures, never production World types.
#include "cybersand/precision_storage.hpp"
#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <memory>
#include <stdexcept>
#include <type_traits>
#include <utility>

namespace mat003 {

struct Record {
    std::uint16_t material = 0;
    std::uint16_t a = 0;
    std::uint8_t b = 0;
    std::uint16_t extra = 0;
    std::uint16_t reserved = 0;
    std::uint32_t epoch = 0;
    bool operator==(const Record&) const = default;
};

struct Source {
    cybersand::detail::PrecisionStorage cell{};
    static constexpr unsigned extra_bytes = 0;
    static constexpr bool is_source = true;
    std::uint64_t word() const { return cell.bits; }
    void word(std::uint64_t value) { cell.bits = value; }
    std::uint16_t tail() const { return 0; }
    void tail(std::uint16_t) {}
};

struct Word {
    std::uint64_t bits = 0;
    static constexpr unsigned extra_bytes = 0;
    static constexpr bool is_source = false;
    std::uint64_t word() const { return bits; }
    void word(std::uint64_t value) { bits = value; }
    std::uint16_t tail() const { return 0; }
    void tail(std::uint16_t) {}
};

struct Padded {
    std::uint64_t bits = 0;
    std::array<std::uint8_t, 8> padding{};
    static constexpr unsigned extra_bytes = 0;
    static constexpr bool is_source = false;
    std::uint64_t word() const { return bits; }
    void word(std::uint64_t value) { bits = value; }
    std::uint16_t tail() const { return 0; }
    void tail(std::uint16_t) {}
};

template<unsigned Extra> struct Packed {
    static_assert(Extra == 1 || Extra == 2);
    std::array<std::uint8_t, 8 + Extra> bytes{};
    static constexpr unsigned extra_bytes = Extra;
    static constexpr bool is_source = false;
    std::uint64_t word() const {
        std::uint64_t value = 0;
        for (unsigned i = 0; i < 8; ++i)
            value |= std::uint64_t{bytes[i]} << (i * 8);
        return value;
    }
    void word(std::uint64_t value) {
        for (unsigned i = 0; i < 8; ++i)
            bytes[i] = static_cast<std::uint8_t>(value >> (i * 8));
    }
    std::uint16_t tail() const {
        unsigned value = bytes[8];
        if constexpr (Extra == 2) value |= unsigned{bytes[9]} << 8;
        return static_cast<std::uint16_t>(value);
    }
    void tail(std::uint16_t value) {
        bytes[8] = static_cast<std::uint8_t>(value);
        if constexpr (Extra == 2) bytes[9] = static_cast<std::uint8_t>(value >> 8);
    }
};

template<unsigned Extra> struct Aligned {
    static_assert(Extra == 1 || Extra == 2);
    using Tail = std::conditional_t<Extra == 1, std::uint8_t, std::uint16_t>;
    std::uint64_t bits = 0;
    Tail extra = 0;
    static constexpr unsigned extra_bytes = Extra;
    static constexpr bool is_source = false;
    std::uint64_t word() const { return bits; }
    void word(std::uint64_t value) { bits = value; }
    std::uint16_t tail() const { return extra; }
    void tail(std::uint16_t value) { extra = static_cast<Tail>(value); }
};

template<class Representation, unsigned EpochBits> struct Cell {
    static_assert(EpochBits == 8 || EpochBits == 16);
    static_assert(!Representation::is_source || EpochBits == 8);
    using Epoch = std::conditional_t<EpochBits == 8, std::uint8_t, std::uint16_t>;
    Representation storage{};
    static constexpr unsigned extra_bytes = Representation::extra_bytes;
    static constexpr unsigned epoch_bits = EpochBits;
    static constexpr unsigned epoch_offset = 64 - EpochBits;
    static constexpr std::uint64_t epoch_limit = (std::uint64_t{1} << EpochBits) - 1;
    static constexpr std::uint64_t reserved_limit = (std::uint64_t{1} << (24 - EpochBits)) - 1;
    static constexpr std::uint64_t material_mask = 65535;
    static constexpr std::uint64_t a_mask = std::uint64_t{65535} << 16;
    static constexpr std::uint64_t b_mask = std::uint64_t{255} << 32;
    static constexpr std::uint64_t reserved_mask = reserved_limit << 40;
    static constexpr std::uint64_t epoch_mask = epoch_limit << epoch_offset;
    static constexpr std::uint32_t extra_limit = extra_bytes == 0 ? 0U :
        ((std::uint32_t{1} << (extra_bytes * 8)) - 1);
    static_assert((material_mask | a_mask | b_mask | reserved_mask | epoch_mask) ==
                  std::numeric_limits<std::uint64_t>::max());
    static_assert((material_mask + a_mask + b_mask + reserved_mask + epoch_mask) ==
                  std::numeric_limits<std::uint64_t>::max());

    void field(std::uint64_t mask, unsigned shift, std::uint32_t value) {
        storage.word((storage.word() & ~mask) | ((std::uint64_t{value} << shift) & mask));
    }
    std::uint16_t material() const { return static_cast<std::uint16_t>(storage.word()); }
    std::uint16_t a() const {
        if constexpr (Representation::is_source) return storage.cell.state_a_value();
        return static_cast<std::uint16_t>(storage.word() >> 16);
    }
    std::uint8_t b() const {
        if constexpr (Representation::is_source) return storage.cell.state_b_value();
        return static_cast<std::uint8_t>(storage.word() >> 32);
    }
    Epoch epoch() const {
        if constexpr (Representation::is_source) return storage.cell.epoch_value();
        return static_cast<Epoch>(storage.word() >> epoch_offset);
    }
    std::uint16_t reserved() const {
        return static_cast<std::uint16_t>((storage.word() >> 40) & reserved_limit);
    }
    std::uint16_t extra() const { return storage.tail(); }
    void material(std::uint32_t value) {
        // Raw high material bits test storage capability, never valid catalogue IDs.
        if constexpr (Representation::is_source) {
            if (value <= 255) storage.cell.set_material(static_cast<cybersand::Material>(value));
            else field(material_mask, 0, value);
        } else field(material_mask, 0, value);
    }
    void a(std::uint32_t value) {
        if constexpr (Representation::is_source) storage.cell.set_state_a(static_cast<std::uint16_t>(value));
        else field(a_mask, 16, value);
    }
    void b(std::uint32_t value) {
        if constexpr (Representation::is_source) storage.cell.set_state_b(static_cast<std::uint8_t>(value));
        else field(b_mask, 32, value);
    }
    void epoch(std::uint32_t value) {
        if constexpr (Representation::is_source) storage.cell.set_epoch(static_cast<std::uint8_t>(value));
        else field(epoch_mask, epoch_offset, value);
    }
    void reserved(std::uint32_t value) { field(reserved_mask, 40, value); }
    bool extra(std::uint32_t value) {
        if constexpr (extra_bytes == 0) return value == 0;
        storage.tail(static_cast<std::uint16_t>(value & extra_limit));
        return true;
    }
    Record read() const { return {material(), a(), b(), extra(), reserved(), epoch()}; }
    bool write(const Record& record) {
        // Whole-record admission is lossless; unlike individual field setters,
        // it refuses an unrepresentable tail before changing any field.
        if (record.extra > extra_limit) return false;
        material(record.material); a(record.a); b(record.b);
        reserved(record.reserved); epoch(record.epoch);
        return extra(record.extra);
    }
};

template<class CellType, std::size_t Count> struct AoSStore {
    std::array<CellType, Count> cells{};
    Record read(std::size_t index) const { return cells.at(index).read(); }
    bool write(std::size_t index, const Record& value) { return cells.at(index).write(value); }
};

// Bounded dense-per-chunk sidecar. No per-cell index/free list exists in this arm.
// Capacity/refusal is explicit, with allocation only at ensure_tail boundaries.
template<unsigned Extra, unsigned EpochBits, std::size_t Chunks = 4,
         std::size_t CellsPerChunk = 16> class SplitStore {
    static_assert(Extra == 1 || Extra == 2);
public:
    using Base = Cell<Word, EpochBits>;
    using Tail = std::conditional_t<Extra == 1, std::uint8_t, std::uint16_t>;
    struct Chunk {
        std::array<Base, CellsPerChunk> cells{};
        std::unique_ptr<Tail[]> tails{};
    };
    static constexpr std::size_t count = Chunks * CellsPerChunk;
    static constexpr std::size_t cells_per_chunk = CellsPerChunk;
    static constexpr std::size_t chunk_count = Chunks;
    static constexpr std::uint32_t extra_limit = (std::uint32_t{1} << (Extra * 8)) - 1;
    explicit SplitStore(std::size_t tail_capacity = Chunks) : capacity_(tail_capacity) {
        if (tail_capacity > Chunks) throw std::invalid_argument("tail capacity exceeds chunk count");
    }
    Record read(std::size_t index) const {
        const auto& chunk = chunks_.at(index / CellsPerChunk);
        auto result = chunk.cells.at(index % CellsPerChunk).read();
        if (chunk.tails) result.extra = chunk.tails[index % CellsPerChunk];
        return result;
    }
    bool ensure_tail(std::size_t chunk_index) {
        auto& chunk = chunks_.at(chunk_index);
        if (chunk.tails) return true;
        if (live_ == capacity_) { ++refusals_; return false; }
        chunk.tails = std::make_unique<Tail[]>(CellsPerChunk);
        ++live_; ++allocations_;
        return true;
    }
    bool write(std::size_t index, const Record& value) {
        auto& chunk = chunks_.at(index / CellsPerChunk);
        if (value.extra > extra_limit) { ++refusals_; return false; }
        if (value.extra != 0 && !ensure_tail(index / CellsPerChunk)) return false;
        auto base = value; base.extra = 0;
        if (!chunk.cells.at(index % CellsPerChunk).write(base)) return false;
        if (chunk.tails) chunk.tails[index % CellsPerChunk] = static_cast<Tail>(value.extra);
        return true;
    }
    bool move(std::size_t source, std::size_t destination) {
        if (source == destination) return true;
        if (!write(destination, read(source))) return false;
        return write(source, Record{});
    }
    bool swap(std::size_t first, std::size_t second) {
        const auto a = read(first), b = read(second);
        const auto c1 = first / CellsPerChunk, c2 = second / CellsPerChunk;
        const bool need1 = b.extra != 0 && !chunks_[c1].tails;
        const bool need2 = a.extra != 0 && !chunks_[c2].tails;
        const std::size_t needed = static_cast<std::size_t>(need1) +
            static_cast<std::size_t>(need2 && c1 != c2);
        if (needed > capacity_ - live_) { ++refusals_; return false; }
        // Allocate all required destinations before touching either source.
        // At most one is missing: a missing tail cannot contain the opposing
        // nonzero payload. If allocation throws, both cell records stay intact.
        if (need1 && !ensure_tail(c1)) return false;
        if (need2 && !ensure_tail(c2)) return false;
        return write(first, b) && write(second, a);
    }
    bool reclaim(std::size_t index) {
        auto& chunk = chunks_.at(index);
        if (!chunk.tails) return true;
        for (std::size_t i = 0; i < CellsPerChunk; ++i)
            if (chunk.tails[i] != 0) return false;
        chunk.tails.reset(); --live_; ++reclaims_;
        return true;
    }
    std::size_t live() const { return live_; }
    std::size_t allocations() const { return allocations_; }
    std::size_t refusals() const { return refusals_; }
    std::size_t reclaims() const { return reclaims_; }
    std::size_t base_array_bytes() const { return count * sizeof(Base); }
    std::size_t allocated_tail_bytes() const { return live_ * CellsPerChunk * sizeof(Tail); }
    std::size_t tail_capacity_bytes() const { return capacity_ * CellsPerChunk * sizeof(Tail); }
    std::size_t metadata_bytes() const { return sizeof(*this) - base_array_bytes(); }
    std::size_t nonzero_tail_bytes() const {
        std::size_t used = 0;
        for (const auto& chunk : chunks_) if (chunk.tails)
            for (std::size_t i = 0; i < CellsPerChunk; ++i)
                if (chunk.tails[i] != 0) used += sizeof(Tail);
        return used;
    }
private:
    std::array<Chunk, Chunks> chunks_{};
    std::size_t capacity_, live_ = 0, allocations_ = 0, refusals_ = 0, reclaims_ = 0;
};

template<unsigned Bits> struct EpochClock {
    static_assert(Bits == 8 || Bits == 16);
    using Value = std::conditional_t<Bits == 8, std::uint8_t, std::uint16_t>;
    Value value = 0;
    template<class Clear> bool advance(Clear clear) {
        value = static_cast<Value>(static_cast<unsigned>(value) + 1U);
        if (value != 0) return false;
        clear();
        value = Value{1};
        return true;
    }
};

static_assert(sizeof(Source) == 8 && alignof(Source) == 8);
static_assert(sizeof(Word) == 8 && alignof(Word) == 8);
static_assert(sizeof(Padded) == 16 && alignof(Padded) == 8);
static_assert(sizeof(Packed<1>) == 9 && alignof(Packed<1>) == 1);
static_assert(sizeof(Packed<2>) == 10 && alignof(Packed<2>) == 1);
// Aligned size/stride is reported, not assumed portable across ABIs.
} // namespace mat003
