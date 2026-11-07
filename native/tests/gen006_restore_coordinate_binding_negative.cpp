// GEN-006 independent builder-support regression.
// This TU includes the exact implementation candidate, renaming only its CLI
// entry point. It never changes the production World, renderer, or builder branch.
// EXPECTED ON UNREPAIRED #486: the valid native checkpoint for chunk A can be
// re-labelled as B and accepted by B's outer record parser. This test passes
// only when that unsafe acceptance is reproduced.
#define main gen006_original_slice_main
#include "gen006_streaming_slice.cpp"
#undef main

int main(int argc, char** argv) {
    try {
        check(argc == 2, "usage: gen006-coordinate-probe NEW-DIRECTORY");
        const fs::path root(argv[1]);
        check(!fs::exists(root), "GEN006_PROBE_NEEDS_FRESH_DIRECTORY");

        const ChunkCoord a{-1, -3}, b{0, -3}, c{1, -3};
        StreamingSlice controller(root, 1, 1);

        controller.focus(a);
        controller.edit(a, 18, 30, Material::Water, 17, 417);
        check(controller.at(a).liquid_mass(-64 + 18, -192 + 30) == 17,
              "initial native Water17 missing");
        const auto a_hash = controller.at(a).physical_state_hash();

        controller.focus(b); // persists A, destroys A World
        controller.focus(c); // persists B, destroys B World
        check(!controller.contains(a) && !controller.contains(b),
              "eviction setup failure");

        // The outer record envelope's body checksum covers edit intent and
        // native CYPS bytes but not the outer chunk coordinates. Copy A's
        // entire valid record into B's path and edit ONLY the outer x field.
        // The native CYPS checkpoint remains intact and still owns chunk A.
        auto forged = read_record(controller.path_for(a));
        check(forged.size() > 68, "native record too short");
        constexpr std::size_t kOuterXOffset = 8 + 4;
        const auto bits = std::bit_cast<std::uint64_t>(b.x);
        for (unsigned i = 0; i < 8; ++i)
            forged[kOuterXOffset + i] =
                static_cast<std::uint8_t>(bits >> (8 * i));
        // No need to recompute anything; outer x is not in the body checksum.
        check(forged[kOuterXOffset] == 0, "outer coordinate rewrite failed");
        const auto forged_file = controller.path_for(b);
        {
            std::ofstream out(forged_file, std::ios::binary | std::ios::trunc);
            check(static_cast<bool>(out), "forged record open failed");
            out.write(reinterpret_cast<const char*>(forged.data()),
                      static_cast<std::streamsize>(forged.size()));
            check(static_cast<bool>(out), "forged record write failed");
        }

        // This currently accepts a B-labeled record containing the valid
        // A-native World. A fixed implementation should refuse before
        // evicting the unrelated currently resident C.
        const auto resident_before = controller.resident();
        World& rebound = controller.focus(b);
        check(controller.resident() == resident_before && controller.contains(b),
              "rebound record did not pass the existing envelope checks");
        check(rebound.chunk_count() == 1, "unexpected native chunk count");
        check(rebound.physical_state_hash() == a_hash,
              "native checkpoint changed unexpectedly during relabelling");
        check(rebound.liquid_mass(-64 + 18, -192 + 30) == 17,
              "loaded native World does not retain original A chunk");
        check(rebound.liquid_mass(18, -192 + 30) == 0,
              "unexpected B material appeared in native A chunk");

        std::cout << "GEN006_REBIND_NEGATIVE_CONTROL_PASS"
                  << " outer_chunk=(0,-3)"
                  << " actual_native_water_chunk=(-1,-3)"
                  << " water17=17"
                  << " b_lookup=0"
                  << " checksum=unchanged"
                  << " physical_hash=" << a_hash << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_REBIND_NEGATIVE_CONTROL_FAIL "
                  << error.what() << '\n';
        return 1;
    }
}
