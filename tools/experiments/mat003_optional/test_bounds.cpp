// Focused regression registered separately from the frozen overnight specimens.
#define main mat003_archived_fixture_main
#include "fixture.cpp"
#undef main

int main() {
    try {
        Store store(2, 1);
        require(store.preflight({0}) && store.put(7, {0xFEDCBA9876543210ULL, tail_max}), "seed owner");
        const auto state = fingerprint(store);
        const auto allocations = store.allocations, writes = store.writes, reads = store.reads;
        const auto reclaims = store.reclaims;
        const auto refused = [&store, state, allocations, writes, reads, reclaims](bool outcome, std::uint64_t before) {
            require(!outcome && store.refusals == before + 1, "one explicit coordinate refusal");
            require(fingerprint(store) == state && store.allocations == allocations && store.writes == writes &&
                    store.reads == reads && store.reclaims == reclaims, "refusal preserves complete state/accounting");
        };
        for (const auto bad : {store.size(), std::numeric_limits<std::size_t>::max()}) {
            auto before = store.refusals; refused(store.move(bad, bad), before);
            before = store.refusals; refused(store.move(bad, 0), before);
            before = store.refusals; refused(store.move(0, bad), before);
            before = store.refusals; refused(store.split(bad, bad, 0), before);
            before = store.refusals; refused(store.split(bad, 0, 0), before);
            before = store.refusals; refused(store.split(0, bad, 0), before);
        }
        for (const auto bad : {store.owners(), std::numeric_limits<std::size_t>::max()}) {
            const auto before = store.refusals; refused(store.reclaim(bad), before);
        }
        const auto before = store.refusals;
        require(store.move(7, 7) && store.split(7, 7, 0) && store.reclaim(1), "valid no-ops");
        require(store.refusals == before && fingerprint(store) == state, "no-op state and refusals");
        std::cout << "{\"status\":\"passed\",\"timing\":false,\"tail_bits\":" << MAT003_TAIL_BITS
                  << ",\"checks\":" << checks << ",\"coordinate_refusals\":" << store.refusals << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n'; return 1;
    }
}
