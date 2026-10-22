#include "carriers.hpp"
#include <algorithm>
#include <array>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {
using namespace mat003;
std::uint64_t checks = 0;
void require(bool condition, const char* message) {
    ++checks;
    if (!condition) throw std::runtime_error(message);
}

std::uint32_t random_value(std::uint32_t& seed) {
    seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
    return seed;
}

// Semantic bytes: little-endian material16/a16/b8/extra8-or16, no padding,
// epoch or reserved bits. Temperature is outside this isolated carrier fixture.
std::vector<std::uint8_t> semantic_bytes(const std::array<Record, 64>& records,
                                         unsigned extra_bytes) {
    std::vector<std::uint8_t> result;
    for (const auto& record : records) {
        for (const auto value : {record.material, record.a}) {
            result.push_back(static_cast<std::uint8_t>(value));
            result.push_back(static_cast<std::uint8_t>(value >> 8));
        }
        result.push_back(record.b);
        for (unsigned i = 0; i < extra_bytes; ++i)
            result.push_back(static_cast<std::uint8_t>(record.extra >> (i * 8)));
    }
    return result;
}
std::string digest(const std::vector<std::uint8_t>& bytes) {
    std::uint64_t value = 14695981039346656037ULL;
    for (const auto byte : bytes) { value ^= byte; value *= 1099511628211ULL; }
    std::ostringstream out;
    out << std::hex << std::setw(16) << std::setfill('0') << value;
    return out.str();
}
std::string hex_bytes(const std::vector<std::uint8_t>& bytes) {
    std::ostringstream out;
    out << std::hex << std::setfill('0');
    for (const auto byte : bytes) out << std::setw(2) << static_cast<unsigned>(byte);
    return out.str();
}
struct SemanticResult { std::string digest, hex; };

template<class C> void field_checks() {
    using ExpectedEpoch = std::conditional_t<C::epoch_bits == 8, std::uint8_t, std::uint16_t>;
    static_assert(std::is_same_v<decltype(std::declval<const C&>().epoch()), ExpectedEpoch>);
    require(std::is_trivially_copyable_v<C>, "carrier must remain trivially copyable");
    C zero;
    require(zero.read() == Record{}, "zero initialization");
    const Record original{0x8123, 0xa55a, 0x5a,
        static_cast<std::uint16_t>(C::extra_limit),
        static_cast<std::uint16_t>(C::reserved_limit),
        static_cast<std::uint32_t>(C::epoch_limit)};
    const std::array<std::uint32_t, 12> values{
        0, 1, 127, 128, 255, 256, 32767, 32768, 65535, 65536,
        0xffffffffU, static_cast<std::uint32_t>(-1)};
    for (const auto value : values) {
        C cell;
        require(cell.write(original), "write initial fields");
        auto expected = original;
        cell.material(value); expected.material = static_cast<std::uint16_t>(value);
        require(cell.read() == expected, "material isolation/full-width roundtrip");
        cell.a(value); expected.a = static_cast<std::uint16_t>(value);
        require(cell.read() == expected, "state_a isolation/full-width roundtrip");
        cell.b(value); expected.b = static_cast<std::uint8_t>(value);
        require(cell.read() == expected, "state_b isolation/boundary clipping");
        cell.epoch(value); expected.epoch = value & static_cast<std::uint32_t>(C::epoch_limit);
        require(cell.read() == expected, "epoch isolation/boundary clipping");
        cell.reserved(value); expected.reserved = static_cast<std::uint16_t>(value & C::reserved_limit);
        require(cell.read() == expected, "reserved-bit isolation");
        const bool admitted = cell.extra(value);
        require(admitted == (C::extra_bytes != 0 || value == 0), "extra capacity refusal");
        if constexpr (C::extra_bytes != 0)
            expected.extra = static_cast<std::uint16_t>(value & C::extra_limit);
        require(cell.read() == expected, "tail isolation/high-bit roundtrip");
        const auto copy = cell;
        C assigned; assigned = copy;
        const auto moved = std::move(assigned);
        require(copy.read() == expected && moved.read() == expected, "copy/move/assignment");
        C other;
        std::swap(cell, other);
        require(cell.read() == Record{} && other.read() == expected, "swap preserves all fields");
    }
    for (const auto pattern : {0U, 1U, 128U, 165U, 255U, 256U, 32768U, 42330U, 65535U}) {
        C cell;
        require(cell.write(original), "tail pattern initial write");
        const bool admitted = cell.extra(pattern);
        require(admitted == (C::extra_bytes != 0 || pattern == 0), "tail pattern admission");
        require(cell.extra() == (pattern & C::extra_limit), "tail pattern roundtrip");
    }
    if constexpr (C::extra_bytes < 2) {
        C cell;
        require(cell.write(original), "unrepresentable payload initial write");
        auto bad = original; bad.extra = static_cast<std::uint16_t>(C::extra_limit + 1); bad.material = 7;
        require(!cell.write(bad) && cell.read() == original, "capacity refusal must not alter base");
    }
}

void production_checks() {
    static_assert(CYBERSAND_MASS_BITS == 8 && CYBERSAND_DELAY_BITS == 8);
    for (std::uint16_t id = 0; id < cybersand::kMaterialDefinitions.size(); ++id) {
        if (!cybersand::valid_material(id)) continue;
        const auto material = static_cast<cybersand::Material>(id);
        auto current = cybersand::detail::PrecisionStorage::for_material(material);
        Cell<Word, 8> matched;
        const auto& definition = cybersand::material_definition(material);
        matched.material(id);
        matched.a(material == cybersand::Material::Water ? cybersand::precision::maximum : definition.initial_state_a);
        matched.b(definition.initial_state_b);
        require(current.bits == matched.storage.bits, "production initialization parity");
        for (const auto value : {0U, 1U, 255U, 256U, 32768U, 65535U}) {
            current.set_state_a(static_cast<std::uint16_t>(value)); matched.a(value);
            current.set_state_b(static_cast<std::uint8_t>(value)); matched.b(value);
            current.set_epoch(static_cast<std::uint8_t>(value)); matched.epoch(value);
            require(current.bits == matched.storage.bits, "direct production accessor parity");
            require(current.material_value() == material, "unrelated material preserved");
        }
    }
    Packed<2> packed;
    packed.word(0x0123456789abcdefULL); packed.tail(0xa55a);
    require(packed.bytes == std::array<std::uint8_t, 10>{0xef,0xcd,0xab,0x89,0x67,0x45,0x23,0x01,0x5a,0xa5},
            "packed wire order independent of native endianness");
    Padded padded;
    require(padded.padding == std::array<std::uint8_t, 8>{}, "explicit physical padding initialized");
}

// Plain Record reference deliberately has no mask/shift or packed accessors.
template<class Store, class C> SemanticResult operation_stream(Store& store) {
    std::array<Record, 64> reference{};
    std::uint32_t seed = 204;
    for (std::size_t step = 0; step < 4096; ++step) {
        const auto number = random_value(seed);
        const std::size_t first = number % 64;
        const std::size_t second = (first + 1 + ((number >> 6) % 63)) % 64;
        const auto operation = (number >> 12) % 10;
        auto a = store.read(first), b = store.read(second);
        const auto before = reference;
        bool admitted = true;
        switch (operation) {
        case 0: a.material = static_cast<std::uint16_t>(number >> 8);
            reference[first].material = static_cast<std::uint16_t>(number >> 8); break;
        case 1: a.a = static_cast<std::uint16_t>(number >> 3);
            reference[first].a = static_cast<std::uint16_t>(number >> 3); break;
        case 2: a.b = static_cast<std::uint8_t>(number >> 5);
            reference[first].b = static_cast<std::uint8_t>(number >> 5); break;
        case 3: a.extra = static_cast<std::uint16_t>((number >> 7) & C::extra_limit);
            reference[first].extra = static_cast<std::uint16_t>((number >> 7) & C::extra_limit); break;
        case 4: b = a; a = Record{};
            reference[second] = before[first]; reference[first] = Record{}; break;
        case 5: std::swap(a, b);
            reference[first] = before[second]; reference[second] = before[first]; break;
        case 6: { // Synthetic integer split, no liquid/pressure interpretation.
            b = a; b.extra = static_cast<std::uint16_t>(a.extra / 2);
            a.extra = static_cast<std::uint16_t>(a.extra - b.extra);
            reference[second] = before[first];
            reference[second].extra = static_cast<std::uint16_t>(before[first].extra / 2);
            reference[first].extra = static_cast<std::uint16_t>(before[first].extra - reference[second].extra);
            break;
        }
        case 7: { // Synthetic bounded merge, overflow refuses without mutation.
            const unsigned sum = unsigned{a.extra} + b.extra;
            if (sum <= C::extra_limit) {
                b.extra = static_cast<std::uint16_t>(sum); a = Record{};
                reference[second].extra = static_cast<std::uint16_t>(unsigned{before[first].extra} + before[second].extra);
                reference[first] = Record{};
            } else admitted = false;
            break;
        }
        case 8: a = Record{}; reference[first] = Record{}; break; // reaction reset
        case 9: b = a; reference[second] = before[first]; break;
        default: throw std::runtime_error("unreachable operation");
        }
        if (admitted) {
            a.epoch = static_cast<std::uint32_t>(step & C::epoch_limit);
            a.reserved = static_cast<std::uint16_t>((step * 17) & C::reserved_limit);
            reference[first].epoch = static_cast<std::uint32_t>(step % (C::epoch_limit + 1));
            reference[first].reserved = static_cast<std::uint16_t>((step * 17) % (C::reserved_limit + 1));
            require(store.write(first, a) && store.write(second, b), "operation admission");
        } else {
            require(store.read(first) == before[first] && store.read(second) == before[second],
                    "refused synthetic merge preserves every field and stamp");
        }
        for (std::size_t i = 0; i < reference.size(); ++i)
            require(store.read(i) == reference[i], "lossless operation/model mismatch");
    }
    // Explicit Empty state survives the semantic oracle (content_hash omits it).
    auto nonzero_empty = reference[0];
    nonzero_empty.material = 0; nonzero_empty.a = 0x8001; nonzero_empty.b = 0x80;
    require(store.write(0, nonzero_empty), "nonzero Empty state write");
    reference[0] = nonzero_empty;
    std::array<Record, 64> actual{};
    for (std::size_t i = 0; i < actual.size(); ++i) actual[i] = store.read(i);
    const auto actual_bytes = semantic_bytes(actual, C::extra_bytes);
    const auto expected_bytes = semantic_bytes(reference, C::extra_bytes);
    require(actual_bytes == expected_bytes, "exact semantic bytes (digest is supplementary)");
    return {digest(actual_bytes), hex_bytes(actual_bytes)};
}

template<class Store, unsigned Bits> std::vector<unsigned> epoch_fixture(Store& store) {
    EpochClock<Bits> clock;
    static_assert(sizeof(typename EpochClock<Bits>::Value) == Bits / 8);
    static_assert(std::is_same_v<typename EpochClock<Bits>::Value,
                  std::conditional_t<Bits == 8, std::uint8_t, std::uint16_t>>);
    std::vector<unsigned> clears;
    std::array<unsigned, 6> updates{};
    // All eight initially stamped1, including two long sleepers, before tick1.
    // Seeded cell state is explicitly synthetic; the counter itself starts0.
    for (std::size_t i = 0; i < 8; ++i) {
        auto record = store.read(i); record.epoch = 1;
        require(store.write(i, record), "initial scheduling stamp");
    }
    for (unsigned tick = 1; tick <= 131080; ++tick) {
        const bool cleared = clock.advance([&] {
            for (std::size_t i = 0; i < 64; ++i) {
                const auto before = store.read(i);
                auto record = before; record.epoch = 0;
                require(store.write(i, record), "epoch clear write");
                auto after = store.read(i); after.epoch = before.epoch;
                require(after == before, "epoch clear preserves all unrelated fields");
            }
        });
        if (cleared) {
            clears.push_back(tick);
            require(store.read(6).epoch == 0 && store.read(7).epoch == 0, "clear includes synthetic sleepers");
            require(clock.value == 1, "restart at one");
        }
        for (std::size_t i = 0; i < updates.size(); ++i) {
            auto record = store.read(i);
            const bool eligible = record.epoch != clock.value;
            require(eligible == (tick != 1), "first/prewritten versus subsequent eligibility");
            if (eligible) { ++updates[i]; record.epoch = clock.value; require(store.write(i, record), "stamp update"); }
            require(store.read(i).epoch == clock.value, "no second update in same synthetic tick");
        }
    }
    for (const auto count : updates) require(count == 131079, "exact primitive update accounting");
    const unsigned period = (1U << Bits) - 1;
    require(!clears.empty() && clears.front() == period + 1, "natural first rollover");
    for (std::size_t i = 1; i < clears.size(); ++i)
        require(clears[i] - clears[i - 1] == period, "natural subsequent rollover period");
    if constexpr (Bits == 16) require(clears == std::vector<unsigned>{65536, 131071}, "both natural16 clears");
    // Separate forced-boundary check; never mislabelled as natural-run evidence.
    clock.value = std::numeric_limits<typename EpochClock<Bits>::Value>::max();
    unsigned calls = 0;
    require(clock.advance([&] { ++calls; }) && calls == 1 && clock.value == 1, "forced boundary primitive");
    return clears;
}

struct SidecarControls {
    std::size_t absent_refusals = 0, lifecycle_allocations = 0, lifecycle_refusals = 0, lifecycle_reclaims = 0;
    std::size_t unread_allocated_bytes = 0, clustered_allocated_bytes = 0, dispersed_allocated_bytes = 0;
    std::size_t clustered_used_bytes = 0, dispersed_used_bytes = 0;
};
struct LayoutResult {
    std::string id, representation, semantic_digest, semantic_records_hex;
    std::string width_only_semantic_digest, width_only_records_hex;
    unsigned logical_bits = 0, epoch_bits = 0;
    std::size_t size_bytes = 0, align_bytes = 0, stride_bytes = 0, tail_stride_bytes = 0;
    std::size_t tail_offset_bytes = 0, base_array_bytes = 0, allocated_tail_bytes = 0;
    std::size_t tail_capacity_bytes = 0, descriptor_bytes = 0, record_bytes = 0;
    std::uint64_t check_count = 0;
    std::size_t natural_clear_count = 0;
    unsigned natural_first_clear = 0, natural_last_clear = 0;
    SidecarControls sidecar{};
};

template<class Representation, unsigned Bits>
LayoutResult run_aos(const std::string& name, const std::string& representation) {
    using C = Cell<Representation, Bits>;
    const auto before = checks;
    field_checks<C>();
    AoSStore<C, 64> store;
    const auto stride = reinterpret_cast<const char*>(&store.cells[1]) -
                        reinterpret_cast<const char*>(&store.cells[0]);
    require(stride == static_cast<std::ptrdiff_t>(sizeof(C)), "observed array stride");
    const auto width_only = operation_stream<decltype(store), Cell<Word, Bits>>(store);
    store = {};
    const auto result = operation_stream<decltype(store), C>(store);
    const auto clears = epoch_fixture<decltype(store), Bits>(store);
    std::size_t tail_offset = 0;
    if constexpr (C::extra_bytes != 0) {
        if constexpr (alignof(Representation) == 1) tail_offset = 8;
        else tail_offset = offsetof(Representation, extra);
    }
    return {name, representation, result.digest, result.hex, width_only.digest, width_only.hex,
        64 + C::extra_bytes * 8, Bits,
        sizeof(C), alignof(C), static_cast<std::size_t>(stride), 0, tail_offset,
        64 * sizeof(C), 0, 0, 0, 5 + C::extra_bytes, checks - before,
        clears.size(), clears.front(), clears.back(), {}};
}

template<unsigned Extra, unsigned Bits> SidecarControls sidecar_ownership_checks() {
    using S = SplitStore<Extra, Bits>;
    const Record payload{17, 0x8001, 0xff, static_cast<std::uint16_t>(S::extra_limit), 0, 1};
    S absent(0);
    require(absent.live() == 0 && absent.allocated_tail_bytes() == 0, "absent tails cost no buffer bytes");
    require(!absent.write(0, payload) && absent.read(0) == Record{}, "absent capacity refusal atomic");
    S unread(2);
    require(unread.ensure_tail(0) && unread.ensure_tail(1), "allocate-unread control");
    require(unread.allocated_tail_bytes() == 32 * Extra && unread.allocations() == 2, "unread allocation accounting");
    // Do not call read() on the unread control: it is allocation-only.
    S bounded(1);
    require(bounded.write(0, payload), "bounded initial payload");
    const auto original = bounded.read(0);
    require(!bounded.move(0, 16), "preflight cross-chunk move refusal");
    require(bounded.read(0) == original && bounded.read(16) == Record{}, "refused move retains source/destination");
    require(!bounded.swap(0, 16), "preflight cross-chunk swap refusal");
    require(bounded.read(0) == original && bounded.read(16) == Record{} && bounded.live() == 1,
            "refused swap retains fields and live allocation");
    require(!bounded.reclaim(0), "nonzero payload cannot reclaim");
    require(bounded.write(0, Record{}) && bounded.reclaim(0) && bounded.live() == 0, "reaction reset/reclaim");
    require(bounded.write(16, payload) && bounded.read(16) == payload, "reclaimed capacity reusable");
    require(bounded.reclaims() == 1 && bounded.allocations() == 2 && bounded.refusals() == 2, "bounded lifecycle counters");
    S clustered, dispersed;
    for (std::size_t i = 0; i < 8; ++i) require(clustered.write(i, payload), "clustered payload");
    for (std::size_t i = 0; i < 4; ++i) require(dispersed.write(i * 16, payload), "dispersed payload");
    require(clustered.live() == 1 && clustered.nonzero_tail_bytes() == 8 * Extra, "clustered accounting");
    require(dispersed.live() == 4 && dispersed.nonzero_tail_bytes() == 4 * Extra, "dispersed accounting");
    require(clustered.allocated_tail_bytes() == 16 * Extra && dispersed.allocated_tail_bytes() == 64 * Extra,
            "resident sidecar bytes differ from payload occupancy");
    require(dispersed.swap(0, 17) && dispersed.move(17, 33), "admitted sidecar swap/move");
    require(dispersed.read(0) == Record{} && dispersed.read(17) == Record{} && dispersed.read(33) == payload,
            "admitted movement owns exact full payload");
    if constexpr (Extra == 1) {
        auto oversized = payload; oversized.extra = 256; oversized.material = 3;
        require(!dispersed.write(33, oversized) && dispersed.read(33) == payload,
                "whole split record rejects oversized tail without base mutation");
    }
    return {absent.refusals(), bounded.allocations(), bounded.refusals(), bounded.reclaims(),
        unread.allocated_tail_bytes(), clustered.allocated_tail_bytes(), dispersed.allocated_tail_bytes(),
        clustered.nonzero_tail_bytes(), dispersed.nonzero_tail_bytes()};
}

template<unsigned Extra, unsigned Bits> LayoutResult run_split(const std::string& name) {
    using S = SplitStore<Extra, Bits>;
    using C = Cell<Packed<Extra>, Bits>; // logical traits only, never split storage
    const auto before = checks;
    const auto controls = sidecar_ownership_checks<Extra, Bits>();
    S width_only_store;
    const auto width_only = operation_stream<S, Cell<Word, Bits>>(width_only_store);
    require(width_only_store.live() == 0, "zero-extra width control keeps split tails absent");
    S store;
    for (std::size_t c = 0; c < S::chunk_count; ++c) require(store.ensure_tail(c), "prepared operation tails");
    const auto result = operation_stream<S, C>(store);
    const auto clears = epoch_fixture<S, Bits>(store);
    require(sizeof(typename S::Base) == 8 && sizeof(typename S::Tail) == Extra, "split independent strides");
    return {name, "split", result.digest, result.hex, width_only.digest, width_only.hex,
        64 + Extra * 8, Bits, sizeof(typename S::Base),
        alignof(typename S::Base), sizeof(typename S::Base), sizeof(typename S::Tail), 0,
        store.base_array_bytes(), store.allocated_tail_bytes(), store.tail_capacity_bytes(),
        store.metadata_bytes(), 5 + Extra, checks - before,
        clears.size(), clears.front(), clears.back(), controls};
}

void emit(const std::vector<LayoutResult>& results) {
    std::cout << "{\"schema_version\":1,\"status\":\"passed\",\"scope\":\"synthetic-storage-only\","
              << "\"checks\":" << checks << ",\"natural_epoch_ticks\":131080,"
              << "\"natural_epoch16_clear_ticks\":[65536,131071],\"epoch8_first_clear\":256,"
              << "\"epoch8_clear_period\":255,\"operation_stream_length\":4096,"
              << "\"semantic_record_count\":64,\"semantic_digest_algorithm\":\"fnv1a64-le\","
              << "\"semantic_record_fields\":[\"material_u16\",\"state_a_u16\",\"state_b_u8\",\"extra_u0_u8_u16\"],"
              << "\"world_qualification\":false,\"timing_qualification\":false,\"arms\":[";
    bool first = true;
    for (const auto& r : results) {
        if (!first) std::cout << ',';
        first = false;
        std::cout << "{\"id\":\"" << r.id << "\",\"representation\":\"" << r.representation
          << "\",\"logical_bits\":" << r.logical_bits << ",\"epoch_bits\":" << r.epoch_bits
          << ",\"size_bytes\":" << r.size_bytes << ",\"align_bytes\":" << r.align_bytes
          << ",\"stride_bytes\":" << r.stride_bytes << ",\"tail_stride_bytes\":" << r.tail_stride_bytes
          << ",\"tail_offset_bytes\":" << r.tail_offset_bytes << ",\"base_array_bytes\":" << r.base_array_bytes
          << ",\"allocated_tail_bytes\":" << r.allocated_tail_bytes << ",\"tail_capacity_bytes\":" << r.tail_capacity_bytes
          << ",\"descriptor_bytes\":" << r.descriptor_bytes << ",\"record_bytes\":" << r.record_bytes
          << ",\"record_count\":64,\"width_only_record_bytes\":5,\"width_only_record_count\":64"
          << ",\"semantic_digest\":\"" << r.semantic_digest
          << "\",\"semantic_records_hex\":\"" << r.semantic_records_hex
          << "\",\"width_only_semantic_digest\":\"" << r.width_only_semantic_digest
          << "\",\"width_only_records_hex\":\"" << r.width_only_records_hex
          << "\",\"checks\":" << r.check_count
          << ",\"natural_clear_count\":" << r.natural_clear_count
          << ",\"natural_first_clear\":" << r.natural_first_clear
          << ",\"natural_last_clear\":" << r.natural_last_clear;
        if (r.representation == "split") {
            const auto& s = r.sidecar;
            std::cout << ",\"sidecar_controls\":{\"absent_refusals\":" << s.absent_refusals
              << ",\"lifecycle_allocations\":" << s.lifecycle_allocations
              << ",\"lifecycle_refusals\":" << s.lifecycle_refusals
              << ",\"lifecycle_reclaims\":" << s.lifecycle_reclaims
              << ",\"unread_allocated_bytes\":" << s.unread_allocated_bytes
              << ",\"clustered_allocated_bytes\":" << s.clustered_allocated_bytes
              << ",\"dispersed_allocated_bytes\":" << s.dispersed_allocated_bytes
              << ",\"clustered_used_bytes\":" << s.clustered_used_bytes
              << ",\"dispersed_used_bytes\":" << s.dispersed_used_bytes << '}';
        }
        std::cout << '}';
    }
    std::cout << "]}\n";
}
} // namespace

int main() {
    try {
        production_checks();
        std::vector<LayoutResult> results;
        results.push_back(run_aos<Source, 8>("C64-E8-source", "source"));
        results.push_back(run_aos<Word, 8>("C64-E8-word", "word"));
        results.push_back(run_aos<Word, 16>("C64-E16-word", "word"));
        results.push_back(run_aos<Padded, 8>("C64-E8-padded", "padded"));
        results.push_back(run_aos<Padded, 16>("C64-E16-padded", "padded"));
        results.push_back(run_aos<Packed<1>, 8>("C72-E8-packed", "packed"));
        results.push_back(run_aos<Packed<1>, 16>("C72-E16-packed", "packed"));
        results.push_back(run_aos<Packed<2>, 8>("C80-E8-packed", "packed"));
        results.push_back(run_aos<Packed<2>, 16>("C80-E16-packed", "packed"));
        results.push_back(run_aos<Aligned<1>, 8>("C72-E8-aligned", "aligned"));
        results.push_back(run_aos<Aligned<1>, 16>("C72-E16-aligned", "aligned"));
        results.push_back(run_aos<Aligned<2>, 8>("C80-E8-aligned", "aligned"));
        results.push_back(run_aos<Aligned<2>, 16>("C80-E16-aligned", "aligned"));
        results.push_back(run_split<1, 8>("C72-E8-split"));
        results.push_back(run_split<1, 16>("C72-E16-split"));
        results.push_back(run_split<2, 8>("C80-E8-split"));
        results.push_back(run_split<2, 16>("C80-E16-split"));
        for (const auto& a : results) for (const auto& b : results) {
            require(a.width_only_records_hex == b.width_only_records_hex,
                    "cross-width exact zero-extra semantic records");
            if (a.logical_bits == b.logical_bits) {
                require(a.semantic_records_hex == b.semantic_records_hex,
                        "cross-representation/epoch exact full-payload records");
                require(a.semantic_digest == b.semantic_digest, "cross-representation/epoch semantic digest");
            }
        }
        emit(results);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "MAT-003PREPASS failed after " << checks << " checks: " << error.what() << '\n';
        return 1;
    }
}
