// GEN-006 real-native coordinate binding refusal regression, adapted from #490.
// Include the implementation candidate unchanged, replacing only its CLI main.
// Requires a correct B restore and a refused relabelled native A-as-B checkpoint.
// This test FAILS on the original unsafe-acceptance implementation.
#define main gen006_original_slice_main
#include "gen006_streaming_slice.cpp"
#undef main

int main(int argc, char** argv) {
    try {
        check(argc == 3, "usage: gen006-coordinate-probe NEW-DIRECTORY 1|4");
        const fs::path root(argv[1]);
        check(!fs::exists(root), "GEN006_PROBE_NEEDS_FRESH_DIRECTORY");

        const ChunkCoord a{-1, -3}, b{0, -3}, c{1, -3};
        const auto workers = static_cast<std::uint32_t>(std::stoul(argv[2]));
        StreamingSlice controller(root, 1, workers);
        check(controller.config().maximum_chunk_count == 1,
              "GEN006_PROBE_CAPACITY_CONTRACT");

        controller.focus(a);
        controller.edit(a, 18, 30, Material::Water, 17, 417);
        check(controller.at(a).liquid_mass(-64 + 18, -192 + 30) == 17,
              "initial native Water17 missing");
        const auto a_hash = controller.at(a).physical_state_hash();

        // A no-ABI, no-mutation membership guard is possible with the existing
        // native installer, but ONLY while maximum_chunk_count == 1 and exactly
        // one World chunk is resident. For a present coordinate it returns
        // AlreadyResident before writing; for an absent coordinate the capacity
        // check returns CapacityFull before writing. A full Empty payload is
        // still needed to satisfy the length precondition.
        const std::vector<Material> empty_materials(kSide * kSide, Material::Empty);
        auto assert_readonly_membership = [&](World& world, ChunkCoord query,
                                              ChunkInstallOutcome expected) {
            check(!world.has_failed() && world.chunk_count() == 1,
                  "GEN006_PROBE_REQUIRES_ONE_HEALTHY_CHUNK");
            const auto hash_before = world.physical_state_hash();
            const auto bytes_before = world.resident_cell_bytes();
            const auto ticks_before = world.completed_tick_index();
            const auto count_before = world.chunk_count();
            const auto outcome = world.install_generated_chunk(query, empty_materials);
            check(outcome == expected, "GEN006_PROBE_UNEXPECTED_OUTCOME");
            check(world.physical_state_hash() == hash_before &&
                  world.resident_cell_bytes() == bytes_before &&
                  world.completed_tick_index() == ticks_before &&
                  world.chunk_count() == count_before,
                  "GEN006_MEMBERSHIP_PROBE_MUTATED_WORLD");
        };
        assert_readonly_membership(controller.at(a), a,
                                   ChunkInstallOutcome::AlreadyResident);
        assert_readonly_membership(controller.at(a), b,
                                   ChunkInstallOutcome::CapacityFull);

        controller.focus(b); // persists A, destroys A World
        controller.edit(b, 18, 30, Material::Water, 17, 417);
        controller.edit(b, 5, 5, Material::Empty);
        const auto initial_observed = controller.simulate(2);
        const auto b_hash = controller.at(b).physical_state_hash();
        const auto b_state = controller.at(b).save_physical_state();
        const auto b_bytes = controller.at(b).resident_cell_bytes();
        const auto b_ticks = controller.at(b).completed_tick_index();
        const auto b_generation = controller.generation(b);
        controller.focus(c); // persists B, destroys B World
        check(!controller.contains(a) && !controller.contains(b),
              "eviction setup failure");

        // Positive control: restore B's intact native CYPS separately from the
        // owner map and verify the same identity guard admits the right chunk.
        // This uses the known G6SLICE1 envelope layout only in test apparatus.
        const auto correct_b_record = read_record(controller.path_for(b));
        constexpr std::size_t kHeaderBytes = 68;
        check(correct_b_record.size() > kHeaderBytes + kMaskBytes,
              "GEN006_VALID_B_RECORD_TRUNCATED");
        auto valid_b = World::restore_physical_state(
            controller.config(),
            std::span<const std::uint8_t>(correct_b_record).subspan(
                kHeaderBytes + kMaskBytes));
        check(valid_b && valid_b->chunk_count() == 1 && !valid_b->has_failed(),
              "GEN006_VALID_B_RESTORE_REFUSED");
        assert_readonly_membership(*valid_b, b,
                                   ChunkInstallOutcome::AlreadyResident);
        assert_readonly_membership(*valid_b, a,
                                   ChunkInstallOutcome::CapacityFull);

        // Positive high-level restore must retain actual physical state,
        // mutation generation, edit intent, and deterministic continuation.
        check(valid_b->physical_state_hash() == b_hash &&
              valid_b->save_physical_state() == b_state,
              "GEN006_VALID_B_NATIVE_MISMATCH");
        const World& actual_b = controller.focus(b);
        check(controller.contains(b) && controller.resident() == 1 &&
              actual_b.physical_state_hash() == b_hash &&
              actual_b.save_physical_state() == b_state &&
              actual_b.resident_cell_bytes() == b_bytes &&
              actual_b.completed_tick_index() == b_ticks &&
              controller.generation(b) == b_generation &&
              controller.intent(b, 5, 5),
              "GEN006_VALID_B_RESTORATION_CHANGED_STATE");
        const auto continuation_observed = controller.simulate(1);
        (void)valid_b->tick();
        check(controller.at(b).physical_state_hash() ==
                  valid_b->physical_state_hash(),
              "GEN006_VALID_B_CONTINUATION_DIVERGED");
        std::cout << "GEN006_VALID_B_RESTORE_CONTINUATION_PASS"
                  << " configured_workers=" << workers << '\n';

        // Re-establish live C, now with unsaved new edits. A refused B must
        // not publish C's checkpoint, destroy it or lose its newest intent.
        controller.focus(c);
        controller.edit(c, 18, 30, Material::Water, 11, 500);
        controller.edit(c, 5, 5, Material::Empty);
        const World* live_c = &controller.at(c);
        const auto c_hash = live_c->physical_state_hash();
        const auto c_state = live_c->save_physical_state();
        const auto c_bytes = live_c->resident_cell_bytes();
        const auto c_tick = live_c->completed_tick_index();
        const auto c_count = live_c->chunk_count();
        const auto c_generation = controller.generation(c);
        const auto saved_c_bytes = read_record(controller.path_for(c));
        const auto saved_a_bytes = read_record(controller.path_for(a));
        check(controller.intent(c, 5, 5) &&
              controller.at(c).liquid_mass(64 + 18, -192 + 30) == 11,
              "GEN006_NEW_LIVE_C_EDITS_ABSENT");
        auto assert_live_untouched = [&] {
            check(controller.resident() == 1 && controller.contains(c) &&
                  !controller.contains(b) && &controller.at(c) == live_c &&
                  !live_c->has_failed() &&
                  live_c->physical_state_hash() == c_hash &&
                  live_c->save_physical_state() == c_state &&
                  live_c->resident_cell_bytes() == c_bytes &&
                  live_c->completed_tick_index() == c_tick &&
                  live_c->chunk_count() == c_count &&
                  controller.generation(c) == c_generation &&
                  controller.intent(c, 5, 5) &&
                  read_record(controller.path_for(c)) == saved_c_bytes &&
                  read_record(controller.path_for(a)) == saved_a_bytes,
                  "GEN006_FAILED_RESTORE_MUTATED_LIVE_OWNER");
        };

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

        auto require_refusal = [&](const std::vector<std::uint8_t>& bytes,
                                   const std::string& expected) {
            {
                std::ofstream out(controller.path_for(b),
                                  std::ios::binary | std::ios::trunc);
                check(bool(out), "GEN006_NEGATIVE_RECORD_OPEN");
                out.write(reinterpret_cast<const char*>(bytes.data()),
                          static_cast<std::streamsize>(bytes.size()));
                out.close();
                check(bool(out), "GEN006_NEGATIVE_RECORD_WRITE");
            }
            std::string observed;
            try { (void)controller.focus(b); }
            catch (const std::exception& error) { observed = error.what(); }
            check(observed == expected, "GEN006_REQUIRED_REFUSAL_MISSING");
            check(read_record(controller.path_for(b)) == bytes,
                  "GEN006_REFUSAL_REWROTE_SOURCE_RECORD");
            assert_live_untouched();
        };
        require_refusal(forged, "GEN006_RESTORED_CHUNK_COORDINATE");

        // Native CYPS inside the forged envelope still contains A. Verify the
        // existing installer identifies its actual coordinate and never mutates.
        const auto actual_a = World::restore_physical_state(
            controller.config(), std::span<const std::uint8_t>(forged).subspan(
                kHeaderBytes + kMaskBytes));
        check(actual_a && actual_a->physical_state_hash() == a_hash,
              "GEN006_A_NATIVE_BODY_WAS_MODIFIED");
        assert_readonly_membership(*actual_a, b,
                                   ChunkInstallOutcome::CapacityFull);
        assert_readonly_membership(*actual_a, a,
                                   ChunkInstallOutcome::AlreadyResident);
        std::cout << "GEN006_RESTORED_CHUNK_COORDINATE_REFUSAL_PASS"
                  << " outer_B=(0,-3) native_A=(-1,-3)"
                  << " water17=17 live_C_unsaved_edits=preserved\n";

        // Existing envelope/identity/size refusal controls also remain intact.
        auto corrupt = correct_b_record;
        corrupt.back() ^= 0x40;
        require_refusal(corrupt, "GEN006_RECORD_INTEGRITY");
        auto recipe = correct_b_record;
        recipe[28] ^= 0x01;
        require_refusal(recipe, "GEN006_RECIPE_CHANGED_PIN");
        auto realm = correct_b_record;
        realm[36] ^= 0x01;
        require_refusal(realm, "GEN006_REALM_CHANGED_PIN");
        auto length = correct_b_record;
        length[56] ^= 0x01;
        require_refusal(length, "GEN006_RECORD_LENGTH");
        auto outer = correct_b_record;
        outer[kOuterXOffset] ^= 0x01;
        require_refusal(outer, "GEN006_RECORD_COORDINATE");
        const std::vector<std::uint8_t> truncated(
            correct_b_record.begin(), correct_b_record.begin() + 67);
        require_refusal(truncated, "GEN006_RECORD_MAGIC");
        std::string invalid_coordinate;
        try { (void)controller.focus({1'000'001, -3}); }
        catch (const std::exception& error) { invalid_coordinate = error.what(); }
        check(invalid_coordinate == "GEN006_DEMAND_COORDINATE_RANGE",
              "GEN006_INVALID_DEMAND_NOT_REFUSED");
        assert_live_untouched();
        std::cout << "GEN006_NONMUTATING_IDENTITY_GUARD_PASS"
                  << " physical_hash=unchanged resident_bytes=unchanged"
                  << " ticks=unchanged native_checkpoint=unchanged\n";
        std::cout << "GEN006_RESTORE_NEGATIVE_CONTROLS_PASS"
                  << " corrupt=REFUSED recipe=REFUSED realm=REFUSED"
                  << " length=REFUSED outer=REFUSED invalid_demand=REFUSED\n";
        std::cout << "GEN006_RESTORE_COORDINATE_BINDING_PASS"
                  << " configured_workers=" << workers
                  << " initial_observed=" << initial_observed
                  << " continuation_observed=" << continuation_observed
                  << " valid_B=RESTORED native_A_as_B=REFUSED"
                  << " live_owner=UNCHANGED\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "GEN006_RESTORE_COORDINATE_BINDING_FAIL "
                  << error.what() << '\n';
        return 1;
    }
}
