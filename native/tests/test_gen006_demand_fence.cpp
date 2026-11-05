// GEN-006 #194: actual native generator -> owner admission session-fence preflight.
// Test-only model. No production streaming, reset transaction or persistence API.
#include "cybersand/world.hpp"
#include "cybersand/world_generation.hpp"

#include <cstdint>
#include <iostream>
#include <memory>
#include <optional>
#include <stdexcept>
#include <utility>

namespace {
using cybersand::ChunkCoord;
using cybersand::ChunkInstallOutcome;
using cybersand::Material;
using cybersand::SimulationBackend;
using cybersand::World;
using cybersand::WorldConfig;
using cybersand::generation::ChunkResult;
using cybersand::generation::Generator;
using cybersand::generation::HardOverride;
using cybersand::generation::Recipe;
using cybersand::generation::ResultState;

constexpr ChunkCoord kChunk{-1, 0};
std::uint64_t checks = 0;

void require(bool ok, const char* why) {
    ++checks;
    if (!ok) throw std::runtime_error(why);
}

WorldConfig config(std::uint32_t workers) {
    WorldConfig cfg{};
    cfg.chunk_size = 128;
    cfg.backend = SimulationBackend::PhasedInPlace;
    cfg.worker_threads = workers;
    cfg.parallel_job_threshold = 1;
    cfg.initial_chunk_reserve = 2;
    cfg.maximum_chunk_count = 16;
    cfg.active_chunk_capacity = 32;
    cfg.active_core_capacity = 256;
    return cfg;
}

std::shared_ptr<const Generator> generator(std::uint64_t revision, Material hard) {
    Recipe recipe{};
    recipe.schema = cybersand::generation::kSchemaVersion;
    recipe.chunk_size = 128;
    recipe.seed = 713;
    recipe.revision = revision;
    HardOverride override{};
    override.id = "session-fence-test-hard-override";
    override.bounds = {-128, 0, 128, 128};
    override.material = hard;
    recipe.overrides.push_back(override);
    return Generator::compile(std::move(recipe));
}

struct Token {
    std::uint64_t session{}, job{}, fingerprint{};
    ChunkCoord chunk{};
    friend bool operator==(const Token&, const Token&) = default;
};

enum class Outcome { Installed, StaleOrCancelled, InvalidProposal, NativeRefused };

// This is deliberately a local *host contract experiment*. The native installer
// has no knowledge of session, request incarnation or accepted recipe.
class FencedOwner {
public:
    FencedOwner(WorldConfig cfg, std::shared_ptr<const Generator> gen)
        : cfg_(cfg), generator_(std::move(gen)), world_(std::make_unique<World>(cfg_)) {}

    Token request(ChunkCoord coord) {
        pending_ = Token{session_, ++next_job_, generator_->fingerprint(), coord};
        return *pending_;
    }

    void cancel() { pending_.reset(); }

    void reset(std::shared_ptr<const Generator> next) {
        pending_.reset();
        ++session_;
        generator_ = std::move(next);
        world_ = std::make_unique<World>(cfg_);
    }

    Outcome offer(const Token& token, const ChunkResult& proposal) {
        if (!pending_.has_value() || token != *pending_ ||
            token.session != session_ || token.fingerprint != generator_->fingerprint())
            return Outcome::StaleOrCancelled;
        if (proposal.chunk != token.chunk || !generator_->accepts(proposal))
            return Outcome::InvalidProposal;
        const auto result = world_->install_generated_chunk(proposal.chunk, proposal.cells);
        if (result != ChunkInstallOutcome::Installed) return Outcome::NativeRefused;
        pending_.reset(); // Receipt is single-use even for a successful native call.
        return Outcome::Installed;
    }

    World& world() { return *world_; }

private:
    WorldConfig cfg_;
    std::shared_ptr<const Generator> generator_;
    std::unique_ptr<World> world_;
    std::optional<Token> pending_;
    std::uint64_t session_ = 1, next_job_ = 0;
};

void run(std::uint32_t workers) {
    const auto cfg = config(workers);
    const auto old_gen = generator(1, Material::Wall);
    const auto new_gen = generator(2, Material::Glass);
    const auto old = old_gen->generate(kChunk);
    const auto fresh = new_gen->generate(kChunk);
    require(old.state == ResultState::Ready && fresh.state == ResultState::Ready,
            "both real native generated proposals must be Ready");
    require(old_gen->accepts(old) && new_gen->accepts(fresh),
            "exact original recipe receipts must validate");
    require(!new_gen->accepts(old) && !old_gen->accepts(fresh),
            "different recipe revisions may not be interchangeable");
    require(old.cells != fresh.cells, "test recipes must produce distinct native contents");

    // Native bare installer correctly checks resident/coordinate/material shape,
    // but has no host world incarnation or accepted-recipe proof.
    World raw(cfg);
    require(raw.install_generated_chunk(kChunk, old.cells) == ChunkInstallOutcome::Installed,
            "bare native fresh installer unexpectedly refused old proposal");
    require(raw.stored_material(-128, 0) == Material::Wall,
            "negative control did not actually admit old material");
    require(new_gen->sample(-128, 0) == Material::Glass,
            "new recipe is not distinguishable at the same world coordinate");

    FencedOwner owner(cfg, old_gen);
    const auto abandoned = owner.request(kChunk);
    owner.reset(new_gen); // Same chunk becomes absent in a new native World.
    const auto current = owner.request(kChunk);
    require(owner.offer(abandoned, old) == Outcome::StaleOrCancelled,
            "old World session was allowed through the host boundary");
    require(owner.world().chunk_count() == 0,
            "stale World session allocated a current resident");
    require(owner.offer(current, old) == Outcome::InvalidProposal,
            "old recipe payload admitted under a current session");
    require(owner.world().chunk_count() == 0,
            "invalid recipe proposal mutated the native World");

    auto altered = fresh;
    altered.cells.front() = Material::Wall; // still a valid material, but invalid receipt
    require(!new_gen->accepts(altered), "tampered material cells passed native generator receipt");
    require(owner.offer(current, altered) == Outcome::InvalidProposal,
            "tampered valid-material payload was accepted by host");
    require(owner.world().chunk_count() == 0,
            "tampered proposal allocated a resident");

    auto wrong_chunk = fresh;
    wrong_chunk.chunk = {0, -1};
    require(owner.offer(current, wrong_chunk) == Outcome::InvalidProposal,
            "wrong signed chunk coordinate passed host admission");

    owner.cancel();
    const auto replacement = owner.request(kChunk);
    require(owner.offer(current, fresh) == Outcome::StaleOrCancelled,
            "cancelled same-session job was accepted after replacement request");
    require(owner.offer(replacement, fresh) == Outcome::Installed,
            "current exact native generation payload was not admitted");
    require(owner.offer(replacement, fresh) == Outcome::StaleOrCancelled,
            "same receipt was consumed more than once");
    require(owner.world().chunk_count() == 1 &&
                owner.world().stored_material(-128, 0) == Material::Glass,
            "current native resident differs from approved recipe");

    World reference(cfg);
    require(reference.install_generated_chunk(kChunk, fresh.cells) == ChunkInstallOutcome::Installed,
            "uninterrupted native reference installation refused");
    std::uint32_t observed_max = 0;
    for (int n = 0; n < 3; ++n) {
        const auto selected = owner.world().tick();
        const auto control = reference.tick();
        require(!owner.world().has_failed() && !reference.has_failed(),
                "native tick quarantined during admitted continuation");
        require(selected.tick == control.tick &&
                    owner.world().physical_state_hash() == reference.physical_state_hash() &&
                    owner.world().quantity_ledger() == reference.quantity_ledger(),
                "fenced native World continuation differs from current-recipe control");
        observed_max = std::max(observed_max, selected.worker_threads_observed);
    }
    std::cout << "GEN006_NATIVE_DEMAND_FENCE configured_workers=" << workers
              << " observed_max=" << observed_max
              << " signed_chunk=-1,0"
              << " raw_stale_admitted=1 fenced_stale_refused=1"
              << " current_admitted=1 continuation_ticks=3"
              << " result=PASS checks_so_far=" << checks << '\n';
}
}  // namespace

int main() {
    try {
        run(1);
        run(4);
        std::cout << "GEN006_DEMAND_FENCE_PASS checks=" << checks << '\n';
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "GEN006_DEMAND_FENCE_FAIL checks=" << checks
                  << " message=" << e.what() << '\n';
        return 1;
    }
}
