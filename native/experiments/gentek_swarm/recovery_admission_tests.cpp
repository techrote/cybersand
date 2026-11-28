// Representation-only regressions. The synthetic admitted history below is not
// a native construction, source authority, or an Apply-positive fixture.
#include "recovery_admission.hpp"
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace cybersand::gentek_swarm;
using cybersand::Material;
namespace a = cybersand::gentek_swarm::assembly004;
namespace {
std::uint64_t assertions{};
void require(bool okay, const std::string& why) { ++assertions; if (!okay) throw std::runtime_error(why); }
Result empty_result(int width, int height, Kind owner) {
    Result result; result.gentek = owner; result.width = width; result.height = height;
    const auto n = static_cast<std::size_t>(width) * height;
    result.cells.assign(n, Material::Empty); result.roles.assign(n, Role::Empty); result.provenance.assign(n, 0);
    return result;
}
a::Composition specimen(int width = 32, int height = 32) {
    a::Composition c; c.status = a::CompositionStatus::Blocked; c.input.options.negotiated_recovery = true;
    for (auto* q : {&c.input.frame, &c.input.mosaic}) {
        q->width = width; q->height = height; q->eligible.assign(static_cast<std::size_t>(width) * height, 0);
    }
    c.input.mosaic.gentek = Kind::Mosaic; c.input.shared_zone = c.input.frame.eligible;
    c.original_frame.core = c.original_frame.result = empty_result(width, height, Kind::Frameweaver);
    a::Round r; r.frame.result = r.proposed_frame = c.original_frame.result;
    r.mosaic.result = r.proposed_mosaic = empty_result(width, height, Kind::Mosaic);
    r.mosaic_request = c.input.mosaic;
    c.rounds.push_back(r);
    return c;
}
a::Composition nested_specimen() {
    auto c = specimen(); auto& r = c.rounds.front();
    Instance part; part.id = 1; part.cells.push_back({1,1}); part.kind = "test-metadata";
    c.original_frame.core.instances.push_back(part);
    Connector connector; connector.instance = 1; c.original_frame.core.connectors.push_back(connector);
    c.original_frame.core.attachments.emplace_back();
    c.original_frame.core.boundary.hard.emplace_back(); c.original_frame.core.boundary.soft.emplace_back();
    c.original_frame.core.notes.emplace_back("note"); c.original_frame.core.metrics["metric"] = 0;
    c.original_frame.core.rejected["rejected"] = 0;
    TransitionSlot slot; slot.id = 1; slot.facing = {1,0}; slot.envelope = {0,0,16,16}; slot.clearance.push_back({2,2});
    c.original_frame.slots.push_back(slot); c.original_frame.reservation_rejections.emplace_back("source rejection");
    SourceFeasibilityDecision opportunity; opportunity.facing = {1,0}; c.original_frame.source_feasibility.push_back(opportunity);
    r.frame.slots.push_back(slot); r.frame.rejections.emplace_back("frame rejection");
    a::Construction construction; construction.facing = {1,0}; construction.parts.push_back(1);
    construction.reused_host_components.push_back(1); construction.assembly.nodes.emplace_back();
    a::PlacedPart placed; placed.sockets.emplace_back(); construction.assembly.instances.push_back(placed);
    construction.assembly.claims.emplace_back(); construction.assembly.sockets.emplace_back();
    a::Joint local_joint; local_joint.cells.push_back({0,0}); construction.assembly.joints.push_back(local_joint);
    construction.assembly.rejections.emplace_back(); r.frame.constructions.push_back(construction);
    DomainDecision domain; domain.influences.emplace_back(); r.mosaic.domains.push_back(domain);
    r.mosaic.categories.push_back(0); r.mosaic.attempts.emplace_back(); r.mosaic.responses.emplace_back();
    auto& admission = r.mosaic_trace.admission;
    admission.selected_ids.push_back(1); admission.fallback_ids.push_back(1); admission.decisions.emplace_back();
    admission.original_domains.push_back(1); admission.hard_domains.push_back(1);
    admission.preferred_domains.push_back(1); admission.fallback_domains.push_back(1);
    auto& solver = r.mosaic_trace.solver;
    solver.category_ids.push_back(1); solver.primary_optional_ids.push_back(1); solver.fallback_optional_ids.push_back(1);
    ResilienceAttempt attempt; attempt.domains.push_back(1); attempt.optional_ids.push_back(1);
    attempt.categories.push_back(0); solver.attempts.push_back(attempt);
    r.mosaic_trace.final_authorized_ids.push_back(1); r.mosaic_trace.primary_selected_ids.push_back(1);
    r.mosaic_trace.fallback_selected_ids.push_back(1); r.mosaic_trace.dropped_preference_ids.push_back(1);
    RequiredReceiverDecision receiver; receiver.faces.emplace_back(); r.mosaic_trace.receivers.push_back(receiver);
    r.mosaic_bearing_replacements.emplace_back(); r.mosaic_bearing_rejections.emplace_back("bearing rejection");
    a::SupportedNativeReceptor supported; supported.facing = {1,0}; r.mosaic_supported_receptors.push_back(supported);
    a::RecoveryAttempt recovery; recovery.round = 1; r.recovery_attempts.push_back(recovery);
    a::MosaicRecoveryReceipt receipt; receipt.round = 1; receipt.edits.emplace_back(); r.mosaic_recovery_receipts.push_back(receipt);
    r.recovery_frontier.emplace_back(); c.rules.emplace_back("rule"); c.obligations.emplace_back();
    a::JointWitness witness; witness.normal = {1,0}; witness.path.push_back({0,0}); c.joints.push_back(witness);
    c.rejections.emplace_back("composition rejection"); c.metrics["metric"] = 0;
    a::DamageDerivative damage; damage.frame = r.frame; damage.mosaic = r.mosaic; c.damage_derivative = damage;
    return c;
}
void admitted(const a::Composition& c) {
    std::string reason; std::uint64_t bytes{};
    require(a::admit_recovery_history(c, reason, bytes), "bounded specimen rejected: " + reason);
    require(reason.empty() && bytes > 0 && bytes <= 16ULL * 1024 * 1024, "admission accounting outside fixed envelope");
}
void rejected(const a::Composition& c, const std::string& label) {
    std::string reason; std::uint64_t bytes{};
    require(!a::admit_recovery_history(c, reason, bytes), "forged metadata admitted: " + label);
    require(!reason.empty() && reason.size() <= 128, "rejection lacks bounded reason: " + label);
}
}

int main() {
    unsigned passed{}, failed{};
    const auto test = [&](const char* label, const std::function<void()>& run) {
        try { run(); ++passed; std::cout << "PASS " << label << '\n'; }
        catch (const std::exception& error) { ++failed; std::cerr << "FAIL " << label << ": " << error.what() << '\n'; }
    };
    test("bounded history and every nested representation admit without becoming Apply authority", [] {
        const auto c = nested_specimen(); admitted(c);
        require(!c.can_apply, "representation admission manufactured Apply authority");
        admitted(specimen(256,128));
        auto four = specimen(192,112); four.input.options.rounds = 4;
        for (unsigned i=1;i<=4;++i) { auto r=four.rounds.front(); r.number=i; four.rounds.push_back(r); }
        admitted(four);
    });
    test("all nested vector families reject oversized payloads before traversal", [] {
        using Change = std::function<void(a::Composition&)>;
        const std::vector<std::pair<const char*, Change>> mutations{
            {"rounds",[](auto& c){c.rounds.resize(6);}},
            {"source instances",[](auto& c){c.original_frame.core.instances.resize(257);}},
            {"source footprint",[](auto& c){c.original_frame.core.instances[0].cells.resize(1025);}},
            {"source connectors",[](auto& c){c.original_frame.core.connectors.resize(2049);}},
            {"source attachments",[](auto& c){c.original_frame.core.attachments.resize(2049);}},
            {"source hard ports",[](auto& c){c.original_frame.core.boundary.hard.resize(257);}},
            {"source soft ports",[](auto& c){c.original_frame.core.boundary.soft.resize(257);}},
            {"source notes",[](auto& c){c.original_frame.core.notes.resize(65);}},
            {"source masks",[](auto& c){c.original_frame.core.boundary.transition.resize(1025);}},
            {"source reservations",[](auto& c){c.original_frame.slots.resize(9);}},
            {"clearance",[](auto& c){c.original_frame.slots[0].clearance.resize(1025);}},
            {"source opportunities",[](auto& c){c.original_frame.source_feasibility.resize(513);}},
            {"source rejections",[](auto& c){c.original_frame.reservation_rejections.resize(8193);}},
            {"construction count",[](auto& c){c.rounds[0].frame.constructions.resize(9);}},
            {"construction parts",[](auto& c){c.rounds[0].frame.constructions[0].parts.resize(65);}},
            {"construction reused components",[](auto& c){c.rounds[0].frame.constructions[0].reused_host_components.resize(257);}},
            {"expansion nodes",[](auto& c){c.rounds[0].frame.constructions[0].assembly.nodes.resize(65);}},
            {"expansion instances",[](auto& c){c.rounds[0].frame.constructions[0].assembly.instances.resize(65);}},
            {"expansion part sockets",[](auto& c){c.rounds[0].frame.constructions[0].assembly.instances[0].sockets.resize(9);}},
            {"expansion claims",[](auto& c){c.rounds[0].frame.constructions[0].assembly.claims.resize(8193);}},
            {"expansion joints",[](auto& c){c.rounds[0].frame.constructions[0].assembly.joints.resize(513);}},
            {"expansion joint cells",[](auto& c){c.rounds[0].frame.constructions[0].assembly.joints[0].cells.resize(1025);}},
            {"expansion rejections",[](auto& c){c.rounds[0].frame.constructions[0].assembly.rejections.resize(8193);}},
            {"domains",[](auto& c){c.rounds[0].mosaic.domains.resize(5);}},
            {"influences",[](auto& c){c.rounds[0].mosaic.domains[0].influences.resize(9);}},
            {"categories",[](auto& c){c.rounds[0].mosaic.categories.resize(5);}},
            {"attempts",[](auto& c){c.rounds[0].mosaic.attempts.resize(17);}},
            {"responses",[](auto& c){c.rounds[0].mosaic.responses.resize(9);}},
            {"admission decisions",[](auto& c){c.rounds[0].mosaic_trace.admission.decisions.resize(9);}},
            {"admission domains",[](auto& c){c.rounds[0].mosaic_trace.admission.original_domains.resize(5);}},
            {"solver categories",[](auto& c){c.rounds[0].mosaic_trace.solver.category_ids.resize(17);}},
            {"solver attempts",[](auto& c){c.rounds[0].mosaic_trace.solver.attempts.resize(17);}},
            {"solver attempt domains",[](auto& c){c.rounds[0].mosaic_trace.solver.attempts[0].domains.resize(5);}},
            {"solver optional IDs",[](auto& c){c.rounds[0].mosaic_trace.solver.attempts[0].optional_ids.resize(9);}},
            {"solver attempt categories",[](auto& c){c.rounds[0].mosaic_trace.solver.attempts[0].categories.resize(5);}},
            {"receiver choices",[](auto& c){c.rounds[0].mosaic_trace.receivers.resize(9);}},
            {"receiver faces",[](auto& c){c.rounds[0].mosaic_trace.receivers[0].faces.resize(65);}},
            {"native bearing cells",[](auto& c){c.rounds[0].mosaic_bearing_replacements.resize(17);}},
            {"native receptors",[](auto& c){c.rounds[0].mosaic_supported_receptors.resize(9);}},
            {"recovery attempts",[](auto& c){c.rounds[0].recovery_attempts.resize(521);}},
            {"recovery receipts",[](auto& c){c.rounds[0].mosaic_recovery_receipts.resize(9);}},
            {"recovery edit footprint",[](auto& c){c.rounds[0].mosaic_recovery_receipts[0].edits.resize(15);}},
            {"recovery frontier",[](auto& c){c.rounds[0].recovery_frontier.resize(9);}},
            {"result ledger",[](auto& c){c.ledger.resize(1025);}},
            {"final joint path",[](auto& c){c.joints[0].path.resize(1025);}},
            {"damage notes",[](auto& c){c.damage_derivative->frame.result.notes.resize(65);}},
            {"dictionary",[](auto& c){for(unsigned i=0;i<=256;++i)c.metrics[std::to_string(i)]=0;}}
        };
        for (const auto& [label, mutate] : mutations) { auto c=nested_specimen(); mutate(c); rejected(c,label); }
    });
    test("all string families reject control normalization collisions and overlong data", [] {
        using Locate = std::function<std::string&(a::Composition&)>;
        const std::vector<Locate> strings{
            [](auto& c)->auto&{return c.reason;}, [](auto& c)->auto&{return c.stop_reason;},
            [](auto& c)->auto&{return c.input.frame.profile.name;}, [](auto& c)->auto&{return c.input.mosaic.source_identity;},
            [](auto& c)->auto&{return c.input.frame.fixture;}, [](auto& c)->auto&{return c.input.frame.definition_fingerprint;},
            [](auto& c)->auto&{return c.original_frame.core.implementation;}, [](auto& c)->auto&{return c.original_frame.core.termination;},
            [](auto& c)->auto&{return c.original_frame.core.instances[0].kind;}, [](auto& c)->auto&{return c.original_frame.core.instances[0].reason;},
            [](auto& c)->auto&{return c.original_frame.core.connectors[0].state;}, [](auto& c)->auto&{return c.original_frame.core.attachments[0].kind;},
            [](auto& c)->auto&{return c.original_frame.core.attachments[0].reason;}, [](auto& c)->auto&{return c.original_frame.core.boundary.hard[0].tag;},
            [](auto& c)->auto&{return c.original_frame.core.boundary.soft[0].preference;}, [](auto& c)->auto&{return c.original_frame.core.notes[0];},
            [](auto& c)->auto&{return c.original_frame.slots[0].owner;}, [](auto& c)->auto&{return c.original_frame.slots[0].reason;},
            [](auto& c)->auto&{return c.original_frame.reservation_rejections[0];}, [](auto& c)->auto&{return c.original_frame.source_feasibility[0].part;},
            [](auto& c)->auto&{return c.original_frame.source_feasibility[0].reason;}, [](auto& c)->auto&{return c.rounds[0].frame.rejections[0];},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].rule;}, [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.reason;},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.nodes[0].rule;},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.instances[0].name;},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.instances[0].rule;},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.claims[0].rule;},
            [](auto& c)->auto&{return c.rounds[0].frame.constructions[0].assembly.rejections[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic.domains[0].influences[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic.attempts[0].policy;}, [](auto& c)->auto&{return c.rounds[0].mosaic.attempts[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic.responses[0].reason;}, [](auto& c)->auto&{return c.rounds[0].mosaic_trace.reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.admission.reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.admission.decisions[0].disposition;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.admission.decisions[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.solver.attempts[0].solver.policy;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.solver.attempts[0].solver.reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.solver.attempts[0].trigger;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_trace.receivers[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_proposal_reason;}, [](auto& c)->auto&{return c.rounds[0].mosaic_bearing_replacements[0].rule;},
            [](auto& c)->auto&{return c.rounds[0].mosaic_bearing_rejections[0];}, [](auto& c)->auto&{return c.rounds[0].recovery_attempts[0].phase;},
            [](auto& c)->auto&{return c.rounds[0].recovery_attempts[0].outcome;}, [](auto& c)->auto&{return c.rounds[0].recovery_attempts[0].reason;},
            [](auto& c)->auto&{return c.rounds[0].reason;}, [](auto& c)->auto&{return c.damage_derivative->reason;},
            [](auto& c)->auto&{return c.rules[0];}, [](auto& c)->auto&{return c.obligations[0].origin;},
            [](auto& c)->auto&{return c.obligations[0].state;}, [](auto& c)->auto&{return c.obligations[0].reason;},
            [](auto& c)->auto&{return c.rejections[0];}
        };
        for (const auto& locate : strings) {
            for (const char control : {'\0','\n','\t','\r','\x1f','\x7f'}) {
                auto c=nested_specimen(); locate(c)=std::string("same")+control+"string"; rejected(c,"control byte");
            }
            auto c=nested_specimen(); locate(c).assign(4097,'x'); rejected(c,"oversized string");
        }
        auto c=nested_specimen(); c.metrics[std::string("key\0collision",13)]=1; rejected(c,"dictionary control byte");
    });
    test("invalid enums and dangerous geometry fail before arithmetic or material lookup", [] {
        using Change = std::function<void(a::Composition&)>;
        const std::vector<Change> mutations{
            [](auto& c){c.status=static_cast<a::CompositionStatus>(-1);},
            [](auto& c){c.input.frame.gentek=static_cast<Kind>(77);},
            [](auto& c){c.original_frame.core.status=static_cast<Status>(77);},
            [](auto& c){c.original_frame.core.cells[0]=static_cast<Material>(255);},
            [](auto& c){c.original_frame.core.roles[0]=static_cast<Role>(255);},
            [](auto& c){c.original_frame.core.connectors[0].family=static_cast<Family>(255);},
            [](auto& c){c.original_frame.slots[0].kind=static_cast<SlotKind>(77);},
            [](auto& c){c.rounds[0].frame.constructions[0].assembly.outcome=static_cast<a::Outcome>(255);},
            [](auto& c){c.rounds[0].frame.constructions[0].assembly.owner=static_cast<a::Owner>(0);},
            [](auto& c){c.rounds[0].frame.constructions[0].assembly.sockets[0].obligation=static_cast<a::Obligation>(255);},
            [](auto& c){c.rounds[0].mosaic_trace.admission.status=static_cast<Status>(-1);},
            [](auto& c){c.rounds[0].mosaic_trace.solver.attempts[0].solver.status=static_cast<Status>(-1);},
            [](auto& c){c.rounds[0].mosaic_recovery_receipts[0].source_family=static_cast<Family>(255);},
            [](auto& c){c.rounds[0].mosaic_recovery_receipts[0].edits[0].after_role=static_cast<Role>(255);},
            [](auto& c){c.input.frame.width=std::numeric_limits<int>::max();},
            [](auto& c){c.original_frame.core.instances[0].cells[0].x=std::numeric_limits<int>::min();},
            [](auto& c){c.original_frame.slots[0].envelope.w=std::numeric_limits<int>::max();},
            [](auto& c){c.original_frame.source_feasibility[0].facing.x=std::numeric_limits<int>::min();},
            [](auto& c){c.rounds[0].mosaic_recovery_receipts[0].axis.x=std::numeric_limits<int>::max();},
            [](auto& c){c.rounds[0].recovery_frontier[0].next=263;},
            [](auto& c){c.input.frame.profile.clutter=std::numeric_limits<double>::quiet_NaN();},
            [](auto& c){c.rounds[0].mosaic_trace.admission.decisions[0].tile=std::numeric_limits<int>::max();}
        };
        for(const auto& mutate:mutations){auto c=nested_specimen(); mutate(c); rejected(c,"enum or scalar");}
    });
    test("capacity and aggregate memory are checked without raising the 16 MiB envelope", [] {
        auto c=specimen();
        using Note = decltype(c.original_frame.core.notes)::value_type;
        constexpr std::size_t allowance = 16ULL * 1024 * 1024;
        c.original_frame.core.notes.reserve(allowance / sizeof(Note) + 1);
        require(c.original_frame.core.notes.empty() &&
                c.original_frame.core.notes.capacity() > allowance / sizeof(Note),
                "empty reserved-vector fixture must exceed the 16 MiB byte allowance");
        rejected(c,"empty large reserved vector");
        c=specimen(); c.reason.reserve(17ULL*1024*1024); rejected(c,"empty large reserved string");
        c=specimen(); c.input.frame.limits.max_bytes=1; rejected(c,"lower request memory allowance");
        c=specimen(); c.input.frame.limits.max_bytes=17ULL*1024*1024; rejected(c,"raised memory allowance");
        c=specimen(192,112); c.input.options.rounds=4;
        Instance part; part.id=1; part.cells.assign(192*112,{0,0});
        for(unsigned i=0;i<8;++i){part.id=i+1; c.rounds[0].frame.result.instances.push_back(part);}
        c.rounds[0].proposed_frame=c.rounds[0].frame.result;
        for(unsigned i=1;i<=4;++i){auto r=c.rounds[0];r.number=i;c.rounds.push_back(r);}
        rejected(c,"aggregate admitted-size footprints");
    });
    std::cout << "recovery admission tests: " << passed << " passed, " << failed << " failed, " << assertions << " assertions\n";
    return failed ? 1 : 0;
}
