#include "reciprocal_io.hpp"

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <stdexcept>

namespace cybersand::gentek_swarm::assembly004 {
namespace {
int custody_encoding_index(){static const int index=std::ios_base::xalloc();return index;}
void varuint(std::ostream& o,std::uint64_t value){while(value>=128){o.put(static_cast<char>((value&127U)|128U));value>>=7U;}o.put(static_cast<char>(value));}
void str(std::ostream& o,const std::string& s){o<<'"';for(const unsigned char c:s){switch(c){case '"':o<<"\\\"";break;case '\\':o<<"\\\\";break;case '\n':o<<"\\n";break;case '\r':o<<"\\r";break;case '\t':o<<"\\t";break;default:if(c<32)o<<"?";else o<<c;}}o<<'"';}
void point(std::ostream& o,Point p){o<<'['<<p.x<<','<<p.y<<']';}
template<class T>void numbers(std::ostream& o,const std::vector<T>& v){
    if(o.iword(custody_encoding_index())){o.put('\0');varuint(o,v.size());for(auto x:v)varuint(o,static_cast<std::uint64_t>(x));return;}
    o<<'[';bool first=true;for(auto x:v){if(!first)o<<',';first=false;o<<static_cast<std::uint64_t>(x);}o<<']';}
template<class T,class F>void array(std::ostream& o,const std::vector<T>& v,F f){o<<'[';bool first=true;for(const auto& x:v){if(!first)o<<',';first=false;f(o,x);}o<<']';}
void stats(std::ostream& o,const std::map<std::string,std::uint64_t>& m){o<<'{';bool first=true;for(const auto& [k,v]:m){if(!first)o<<',';first=false;str(o,k);o<<':'<<v;}o<<'}';}
void offer(std::ostream& o,const Affordance& a){o<<"{\"id\":"<<a.id<<",\"instance\":"<<a.instance<<",\"a\":";point(o,a.a);o<<",\"b\":";point(o,a.b);o<<",\"facing\":";point(o,a.facing);o<<",\"family\":";str(o,name(a.family));o<<",\"required\":"<<(a.required?"true":"false")<<",\"strength\":"<<a.strength<<",\"tag\":";str(o,a.tag);o<<'}';}
void boundary(std::ostream& o,const Boundary& b){o<<"{\"hard\":";array(o,b.hard,offer);o<<",\"soft\":";array(o,b.soft,[](auto& s,const auto& a){s<<"{\"point\":";point(s,a.point);s<<",\"direction\":";point(s,a.direction);s<<",\"strength\":"<<a.strength<<",\"preference\":";str(s,a.preference);s<<'}';});o<<",\"protected\":";numbers(o,b.protected_geometry);o<<",\"transition\":";numbers(o,b.transition);o<<'}';}
void request(std::ostream& o,const Request& r){o<<"{\"gentek\":";str(o,name(r.gentek));o<<",\"version\":"<<r.version<<",\"definition\":";str(o,definition(r.gentek));o<<",\"source\":";str(o,r.source_identity);o<<",\"fixture\":";str(o,r.fixture);o<<",\"seed\":"<<r.seed<<",\"width\":"<<r.width<<",\"height\":"<<r.height<<",\"origin\":";point(o,r.origin);
    const auto& p=r.profile;o<<",\"profile\":{\"name\":";str(o,p.name);o<<",\"variation\":"<<p.variation<<",\"irregularity\":"<<p.irregularity<<",\"clutter\":"<<p.clutter<<",\"destruction\":"<<p.destruction<<",\"branching\":"<<p.branching<<",\"environment_affinity\":"<<p.environment_affinity<<",\"cohesion\":"<<p.cohesion<<'}';
    const auto& l=r.limits;o<<",\"limits\":{\"instances\":"<<l.max_instances<<",\"frontier\":"<<l.max_frontier<<",\"candidates\":"<<l.max_candidates<<",\"connectors_per_instance\":"<<l.max_connectors_per_instance<<",\"affordances\":"<<l.max_affordances<<",\"cohesion_patches\":"<<l.max_cohesion_patches<<",\"cohesion_cells_per_patch\":"<<l.max_cohesion_cells_per_patch<<",\"work\":"<<l.max_work<<",\"solver_work\":"<<l.max_solver_work<<",\"bytes\":"<<l.max_bytes<<'}';
    o<<",\"activation\":";array(o,r.activation,point);o<<",\"eligible\":";numbers(o,r.eligible);o<<",\"protected\":";numbers(o,r.protected_void);o<<",\"transition\":";numbers(o,r.transition);o<<",\"context\":";numbers(o,r.context);o<<",\"neighbor_cells\":";numbers(o,r.neighbor_cells);o<<",\"neighbors\":";boundary(o,r.neighbors);o<<'}';}
void result(std::ostream& o,const Result& r){o<<"{\"gentek\":";str(o,name(r.gentek));o<<",\"implementation\":";str(o,r.implementation);o<<",\"definition\":";str(o,r.definition_fingerprint);o<<",\"source\":";str(o,r.source_identity);o<<",\"seed\":"<<r.seed<<",\"status\":";str(o,name(r.status));o<<",\"termination\":";str(o,r.termination);
    o<<",\"request_digest\":";str(o,hex(r.request_digest));o<<",\"material_digest\":";str(o,hex(r.material_digest));o<<",\"digest\":";str(o,hex(r.digest));o<<",\"width\":"<<r.width<<",\"height\":"<<r.height<<",\"work\":"<<r.work<<",\"candidates\":"<<r.candidates<<",\"solver_work\":"<<(r.metrics.contains("solver_attempted") && !r.metrics.at("solver_work_observed") ? std::string("null") : std::to_string(r.solver_work))<<",\"backtracks\":"<<r.backtracks<<",\"protected_violations\":"<<r.protected_violations<<",\"illegal_overlaps\":"<<r.illegal_overlaps<<",\"unresolved_joints\":"<<r.unresolved_joints;
    o<<",\"metrics\":";stats(o,r.metrics);o<<",\"rejected\":";stats(o,r.rejected);o<<",\"notes\":";array(o,r.notes,str);o<<",\"cells\":";numbers(o,r.cells);o<<",\"roles\":";numbers(o,r.roles);o<<",\"provenance\":";numbers(o,r.provenance);
    o<<",\"instances\":";array(o,r.instances,[](auto& s,const auto& p){s<<"{\"id\":"<<p.id<<",\"kind\":";str(s,p.kind);s<<",\"origin\":";point(s,p.origin);s<<",\"orientation\":"<<p.orientation<<",\"structural\":"<<(p.structural?"true":"false")<<",\"damaged\":"<<(p.damaged?"true":"false")<<",\"reason\":";str(s,p.reason);s<<",\"cells\":";array(s,p.cells,point);s<<'}';});
    o<<",\"connectors\":";array(o,r.connectors,[](auto& s,const auto& c){s<<"{\"id\":"<<c.id<<",\"instance\":"<<c.instance<<",\"family\":";str(s,name(c.family));s<<",\"a\":";point(s,c.a);s<<",\"b\":";point(s,c.b);s<<",\"facing\":";point(s,c.facing);s<<",\"required\":"<<(c.required?"true":"false")<<",\"fulfilled\":"<<(c.fulfilled?"true":"false")<<",\"counterpart\":"<<c.counterpart<<",\"state\":";str(s,c.state);s<<'}';});
    o<<",\"attachments\":";array(o,r.attachments,[](auto& s,const auto& a){s<<"{\"instance\":"<<a.instance<<",\"point\":";point(s,a.point);s<<",\"target\":";point(s,a.target);s<<",\"kind\":";str(s,a.kind);s<<",\"reason\":";str(s,a.reason);s<<'}';});o<<",\"boundary\":";boundary(o,r.boundary);o<<'}';}
std::ofstream output(const std::string& path){std::ofstream o(path,std::ios::binary);if(!o)throw std::runtime_error("cannot create evidence "+path);o<<std::setprecision(17);return o;}
}
namespace {
void slot(std::ostream& o,const TransitionSlot& s) {
    o<<"{\"id\":"<<s.id<<",\"instance\":"<<s.instance<<",\"connector\":"<<s.connector<<",\"kind\":";str(o,name(s.kind));
    o<<",\"a\":";point(o,s.a);o<<",\"b\":";point(o,s.b);o<<",\"facing\":";point(o,s.facing);
    o<<",\"envelope\":["<<s.envelope.x<<','<<s.envelope.y<<','<<s.envelope.w<<','<<s.envelope.h<<"],\"clearance\":";array(o,s.clearance,point);
    o<<",\"required\":"<<(s.required?"true":"false")<<",\"hard\":"<<(s.hard?"true":"false")<<",\"strength\":"<<s.strength;
    o<<",\"owner\":";str(o,s.owner);o<<",\"reason\":";str(o,s.reason);o<<'}';
}
void mosaic_plan(std::ostream& o,const MosaicPlan& p) {
    o<<"{\"result\":";result(o,p.result);o<<",\"categories\":[";
    for(std::size_t i=0;i<p.categories.size();++i){if(i)o<<',';o<<p.categories[i];}o<<"],\"domains\":";
    array(o,p.domains,[](auto& s,const auto& d){
        s<<"{\"tile\":"<<d.tile<<",\"origin\":";point(s,d.origin);
        s<<",\"original_domain\":"<<d.original_domain<<",\"hard_domain\":"<<d.hard_domain<<",\"preferred_domain\":"<<d.preferred_domain
         <<",\"modified_domain\":"<<d.modified_domain<<",\"selected\":"<<d.selected<<",\"selected_name\":";
        str(s,d.selected<0?"unselected":mosaic_category_name(static_cast<unsigned>(d.selected)));
        s<<",\"preference_satisfied\":"<<(d.preference_satisfied?"true":"false")<<",\"fallback\":"<<(d.fallback?"true":"false")<<",\"influences\":";
        array(s,d.influences,[](auto& t,const auto& i){t<<"{\"slot_id\":"<<i.slot_id<<",\"compatible_domain\":"<<i.compatible_domain
            <<",\"hard\":"<<(i.hard?"true":"false")<<",\"admitted\":"<<(i.admitted?"true":"false")<<",\"contact\":";
            point(t,i.contact);t<<",\"reason\":";str(t,i.reason);t<<'}';});s<<'}';
    });
    o<<",\"attempts\":";array(o,p.attempts,[](auto& s,const auto& a){
        s<<"{\"policy\":";str(s,a.policy);s<<",\"status\":";str(s,name(a.status));s<<",\"reason\":";str(s,a.reason);
        s<<",\"attempted\":"<<(a.attempted?"true":"false")<<",\"work_observed\":"<<(a.work_observed?"true":"false")
         <<",\"work\":"<<(a.work_observed?std::to_string(a.work):"null")<<",\"work_limit\":"<<a.work_limit<<'}';
    });
    o<<",\"responses\":";array(o,p.responses,[](auto& s,const auto& r){
        s<<"{\"slot_id\":"<<r.slot_id<<",\"tile\":"<<r.tile<<",\"admitted\":"<<(r.admitted?"true":"false")
         <<",\"satisfied\":"<<(r.satisfied?"true":"false")<<",\"compatible_domain\":"<<r.compatible_domain<<",\"contact\":";
        point(s,r.contact);s<<",\"facing\":";point(s,r.facing);s<<",\"reason\":";str(s,r.reason);s<<'}';
    });o<<'}';
}
}

namespace {
void solver_record(std::ostream& o,const SolverAttempt& a) {
    o<<"{\"policy\":";str(o,a.policy);o<<",\"status\":";str(o,name(a.status));
    o<<",\"reason\":";str(o,a.reason);
    o<<",\"attempted\":"<<(a.attempted?"true":"false")<<",\"work_observed\":"<<(a.work_observed?"true":"false")
     <<",\"work\":"<<(a.work_observed?std::to_string(a.work):"null")<<",\"work_limit\":"<<a.work_limit<<'}';
}
void native_admission(std::ostream& o,const NativeAdmissionReceipt& a) {
    o<<"{\"status\":";str(o,name(a.status));o<<",\"reason\":";str(o,a.reason);
    o<<",\"work\":"<<a.work<<",\"optional_capacity\":"<<a.optional_capacity
     <<",\"fallback_optional_capacity\":"<<a.fallback_optional_capacity;
    o<<",\"selected_ids\":";numbers(o,a.selected_ids);o<<",\"fallback_ids\":";numbers(o,a.fallback_ids);
    o<<",\"original_domains\":";numbers(o,a.original_domains);o<<",\"hard_domains\":";numbers(o,a.hard_domains);
    o<<",\"preferred_domains\":";numbers(o,a.preferred_domains);o<<",\"fallback_domains\":";numbers(o,a.fallback_domains);
    o<<",\"decisions\":";array(o,a.decisions,[](auto& s,const auto& d) {
        s<<"{\"slot_id\":"<<d.slot_id<<",\"tile\":"<<d.tile
         <<",\"hard\":"<<(d.hard?"true":"false")<<",\"geometry_admitted\":"<<(d.geometry_admitted?"true":"false")
         <<",\"selected\":"<<(d.selected?"true":"false")<<",\"fallback_selected\":"<<(d.fallback_selected?"true":"false")
         <<",\"domain_changed\":"<<(d.domain_changed?"true":"false")
         <<",\"fallback_domain_changed\":"<<(d.fallback_domain_changed?"true":"false")
         <<",\"rank\":"<<d.rank<<",\"distance\":"<<d.distance<<",\"contact\":";point(s,d.contact);
        s<<",\"compatible_domain\":"<<d.compatible_domain<<",\"locally_supported_domain\":"<<d.locally_supported_domain
         <<",\"original_domain\":"<<d.original_domain<<",\"hard_domain\":"<<d.hard_domain
         <<",\"projected_domain\":"<<d.projected_domain<<",\"fallback_domain\":"<<d.fallback_domain<<",\"neighbor_pool\":[";
        for(std::size_t i=0;i<d.neighbor_pool.size();++i){if(i)s<<',';s<<d.neighbor_pool[i];}
        s<<"],\"neighbor_support\":"<<d.neighbor_support<<",\"conflicts_with\":"<<d.conflicts_with<<",\"disposition\":";
        str(s,d.disposition);s<<",\"reason\":";str(s,d.reason);s<<'}';
    });o<<'}';
}
void receiver_decision(std::ostream& o,const RequiredReceiverDecision& r) {
    o<<"{\"slot_id\":"<<r.slot_id<<",\"original_tile\":"<<r.original_tile<<",\"selected_tile\":"<<r.selected_tile
     <<",\"original_contact\":";point(o,r.original_contact);o<<",\"selected_contact\":";point(o,r.selected_contact);
    o<<",\"original_compatible_domain\":"<<r.original_compatible_domain<<",\"original_supported_domain\":"<<r.original_supported_domain
     <<",\"selected_compatible_domain\":"<<r.selected_compatible_domain<<",\"selected_supported_domain\":"<<r.selected_supported_domain
     <<",\"original_admitted\":"<<(r.original_admitted?"true":"false")<<",\"changed\":"<<(r.changed?"true":"false")
     <<",\"work\":"<<r.work<<",\"points_examined\":"<<r.points_examined<<",\"reason\":";str(o,r.reason);
    o<<",\"faces\":";array(o,r.faces,[](auto& s,const auto& f) {
        s<<"{\"contact\":";point(s,f.contact);s<<",\"tile\":"<<f.tile<<",\"original_domain\":"<<f.original_domain
         <<",\"compatible_domain\":"<<f.compatible_domain<<",\"supported_domain\":"<<f.supported_domain
         <<",\"distance\":"<<f.distance<<",\"selected\":"<<(f.selected?"true":"false")<<'}';
    });o<<'}';
}
void resilient_solver(std::ostream& o,const ResilienceSolverTrace& s) {
    o<<"{\"width\":"<<s.width<<",\"height\":"<<s.height<<",\"seed\":"<<s.seed
     <<",\"aggregate_limit\":"<<s.aggregate_limit<<",\"allocated_limit\":"<<s.allocated_limit
     <<",\"attempted_limit\":"<<s.attempted_limit<<",\"preparation_work\":"<<s.preparation_work
     <<",\"fallback_used\":"<<(s.fallback_used?"true":"false")<<",\"category_ids\":";numbers(o,s.category_ids);
    o<<",\"adjacency\":[";
    for(std::size_t direction=0;direction<s.adjacency.size();++direction) {
        if(direction)o<<',';
        o<<'[';for(std::size_t category=0;category<s.adjacency[direction].size();++category) {
            if(category)o<<',';
            o<<s.adjacency[direction][category];
        }o<<']';
    }o<<"],\"primary_optional_ids\":";numbers(o,s.primary_optional_ids);
    o<<",\"fallback_optional_ids\":";numbers(o,s.fallback_optional_ids);
    o<<",\"attempts\":";array(o,s.attempts,[](auto& stream,const auto& a) {
        stream<<"{\"solver\":";solver_record(stream,a.solver);stream<<",\"domains\":";numbers(stream,a.domains);
        stream<<",\"optional_ids\":";numbers(stream,a.optional_ids);stream<<",\"categories\":[";
        for(std::size_t i=0;i<a.categories.size();++i){if(i)stream<<',';stream<<a.categories[i];}
        stream<<"],\"trigger\":";str(stream,a.trigger);stream<<",\"fallback\":"<<(a.fallback?"true":"false")<<'}';
    });o<<'}';
}
void resilience_trace(std::ostream& stream, const ResilienceTrace& trace) {
    stream << "{\"reason\":"; str(stream, trace.reason);
    stream << ",\"final_authorized_ids\":"; numbers(stream, trace.final_authorized_ids);
    stream << ",\"primary_selected_ids\":"; numbers(stream, trace.primary_selected_ids);
    stream << ",\"fallback_selected_ids\":"; numbers(stream, trace.fallback_selected_ids);
    stream << ",\"dropped_preference_ids\":"; numbers(stream, trace.dropped_preference_ids);
    stream << ",\"receivers\":"; array(stream, trace.receivers, receiver_decision);
    stream << ",\"admission\":"; native_admission(stream, trace.admission);
    stream << ",\"solver\":"; resilient_solver(stream, trace.solver); stream << '}';
}
} // namespace


namespace {
void transform(std::ostream& o, const Transform& value) {
    o << "{\"translation\":"; point(o, value.translation);
    o << ",\"quarter_turns\":" << value.quarter_turns << '}';
}
void placed_socket(std::ostream& o, const PlacedSocket& socket) {
    o << "{\"id\":" << socket.id << ",\"instance\":" << socket.instance << ",\"source_socket\":" << socket.source_socket;
    o << ",\"a\":"; point(o, socket.a); o << ",\"b\":"; point(o, socket.b); o << ",\"facing\":"; point(o, socket.facing);
    o << ",\"family\":"; str(o, name(socket.family)); o << ",\"obligation\":"; str(o, name(socket.obligation)); o << '}';
}
void expanded_assembly(std::ostream& o, const ExpandedAssembly& assembly) {
    o << "{\"outcome\":"; str(o, name(assembly.outcome)); o << ",\"reason\":"; str(o, assembly.reason);
    o << ",\"owner\":"; str(o, name(assembly.owner)); o << ",\"round\":" << assembly.round << ",\"revision\":" << assembly.revision;
    o << ",\"digest\":"; str(o, hex(assembly.digest)); o << ",\"declared_cells\":" << assembly.declared_cells
      << ",\"shared_joint_cells\":" << assembly.shared_joint_cells << ",\"nodes\":";
    array(o, assembly.nodes, [](auto& s, const ExpandedNode& node) {
        s << "{\"id\":" << node.id << ",\"parent\":" << node.parent << ",\"spec\":" << node.spec
          << ",\"depth\":" << node.depth << ",\"child_slot\":" << node.child_slot
          << ",\"assembly\":" << (node.assembly ? "true" : "false") << ",\"rule\":"; str(s, node.rule);
        s << ",\"transform\":"; transform(s, node.transform); s << '}';
    });
    o << ",\"instances\":";
    array(o, assembly.instances, [](auto& s, const PlacedPart& part) {
        s << "{\"instance\":" << part.instance << ",\"parent\":" << part.parent << ",\"spec\":" << part.spec
          << ",\"depth\":" << part.depth << ",\"node\":" << part.node << ",\"name\":"; str(s, part.name);
        s << ",\"rule\":"; str(s, part.rule); s << ",\"transform\":"; transform(s, part.transform);
        s << ",\"sockets\":"; array(s, part.sockets, placed_socket); s << '}';
    });
    o << ",\"claims\":";
    array(o, assembly.claims, [](auto& s, const Claim& claim) {
        s << "{\"point\":"; point(s, claim.point); s << ",\"material\":" << static_cast<unsigned>(claim.material)
          << ",\"role\":" << static_cast<unsigned>(claim.role) << ",\"owner\":" << static_cast<unsigned>(claim.owner)
          << ",\"instance\":" << claim.instance << ",\"spec\":" << claim.spec << ",\"round\":" << claim.round
          << ",\"revision\":" << claim.revision << ",\"rule\":"; str(s, claim.rule); s << '}';
    });
    o << ",\"sockets\":"; array(o, assembly.sockets, placed_socket);
    o << ",\"joints\":";
    array(o, assembly.joints, [](auto& s, const Joint& joint) {
        s << "{\"instance_a\":" << joint.instance_a << ",\"socket_a\":" << joint.socket_a
          << ",\"instance_b\":" << joint.instance_b << ",\"socket_b\":" << joint.socket_b << ",\"family\":";
        str(s, name(joint.family)); s << ",\"cells\":"; array(s, joint.cells, point); s << '}';
    });
    o << ",\"rejections\":";
    array(o, assembly.rejections, [](auto& s, const Rejection& rejection) {
        s << "{\"symbol\":" << rejection.symbol << ",\"child_slot\":" << rejection.child_slot << ",\"reason\":";
        str(s, rejection.reason); s << '}';
    });
    o << '}';
}
void frame_revision(std::ostream& stream, const FrameRevision& frame) {
    stream << "{\"result\":"; result(stream, frame.result);
    stream << ",\"slots\":"; array(stream, frame.slots, slot);
    stream << ",\"local_terminations\":" << frame.local_terminations << ",\"rejections\":";
    array(stream, frame.rejections, str);
    stream << ",\"constructions\":";
    array(stream, frame.constructions, [](auto& s, const Construction& construction) {
        s << "{\"slot\":" << construction.slot << ",\"connector\":" << construction.connector
          << ",\"base_instance\":" << construction.base_instance << ",\"root\":"; point(s, construction.root);
        s << ",\"face\":"; point(s, construction.face); s << ",\"facing\":"; point(s, construction.facing);
        s << ",\"parts\":"; numbers(s, construction.parts);
        s << ",\"reused_host_components\":"; numbers(s, construction.reused_host_components);
        s << ",\"authored_symbol\":{\"id\":" << construction.authored_symbol.id
          << ",\"assembly\":" << (construction.authored_symbol.assembly ? "true" : "false") << '}'
          << ",\"span\":" << construction.span << ",\"rise\":" << construction.rise
          << ",\"handedness\":" << construction.handedness << ",\"input_family\":";
        str(s, name(construction.input_family));
        s << ",\"rule\":"; str(s, construction.rule);
        s << ",\"assembly\":"; expanded_assembly(s, construction.assembly); s << '}';
    });
    stream << '}';
}
}

namespace {
void composition_json(std::ostream& o,const Composition& c,bool custody) {
    o << "{\"schema\":" << (c.input.options.negotiated_recovery?6:5)
      << ",\"type\":\"reciprocal_assembly\",\"programme\":";
    str(o,c.input.options.negotiated_recovery?"GENTEK-SWARM-006":"GENTEK-SWARM-004");o<<",\"identity\":";
    str(o, c.input.options.negotiated_recovery?recovery_identity:composition_identity);
    o << ",\"source\":"; str(o, c.input.frame.source_identity);
    if(!custody) {
    o << ",\"status\":"; str(o, name(c.status));
    o << ",\"reason\":"; str(o, c.reason);
    o << ",\"stop_reason\":"; str(o, c.stop_reason);
    o << ",\"can_apply\":" << (c.can_apply ? "true" : "false") << ",\"digest\":"; str(o, hex(c.digest));
    }
    o << ",\"input\":{\"frame\":"; request(o, c.input.frame);
    o << ",\"mosaic\":"; request(o, c.input.mosaic);
    o << ",\"shared_zone\":"; numbers(o, c.input.shared_zone);
    const auto& options = c.input.options;
    o << ",\"options\":{\"rounds\":" << options.rounds
      << ",\"vocabulary\":" << (options.vocabulary ? "true" : "false")
      << ",\"hierarchy\":" << (options.hierarchy ? "true" : "false")
      << ",\"shared_ownership\":" << (options.shared_ownership ? "true" : "false")
      << ",\"frame_adaptation\":" << (options.frame_adaptation ? "true" : "false")
      << ",\"mosaic_adaptation\":" << (options.mosaic_adaptation ? "true" : "false")
      << ",\"optional_negotiation\":" << (options.optional_negotiation ? "true" : "false")
      << ",\"native_mosaic_bearing\":" << (options.native_mosaic_bearing ? "true" : "false")
      << ",\"supported_native_receptors\":" << (options.supported_native_receptors ? "true" : "false")
      << ",\"compact_native_termination\":" << (options.compact_native_termination ? "true" : "false")
      << ",\"final_validation\":" << (options.final_validation ? "true" : "false")
      << ",\"shared_extent\":" << options.shared_extent
      << ",\"orientation_preference\":" << options.orientation_preference;
    if(options.negotiated_recovery)o<<",\"negotiated_recovery\":true,\"recovery_offers\":"<<(options.recovery_offers?"true":"false");
    o<<"}}";
    o << ",\"original_frame\":{\"core\":"; result(o, c.original_frame.core);
    o << ",\"result\":"; result(o, c.original_frame.result);
    o << ",\"slots\":"; array(o, c.original_frame.slots, slot);
    o << ",\"reservation_rejections\":"; array(o, c.original_frame.reservation_rejections, str);
    if(options.negotiated_recovery) {
        o<<",\"source_feasibility\":";
        array(o,c.original_frame.source_feasibility,[](auto& s,const SourceFeasibilityDecision& d){
            s<<"{\"connector\":"<<d.connector<<",\"instance\":"<<d.instance<<",\"source\":";point(s,d.source);
            s<<",\"face\":";point(s,d.face);s<<",\"facing\":";point(s,d.facing);s<<",\"contact\":";point(s,d.contact);
            s<<",\"backing\":";point(s,d.backing);s<<",\"receiver_categories\":"<<d.receiver_categories
             <<",\"local_termination_possible\":"<<(d.local_termination_possible?"true":"false")
             <<",\"foreign_opportunity\":"<<(d.foreign_opportunity?"true":"false")<<",\"work\":"<<d.work
             <<",\"part\":";str(s,d.part);s<<",\"reason\":";str(s,d.reason);s<<'}';});
    }
    o<<'}';
    o << ",\"rounds\":";
    array(o, c.rounds, [&](auto& stream, const Round& round) {
        stream << "{\"number\":" << round.number << ",\"reason\":"; str(stream, round.reason);
        stream << ",\"geometry_digest\":"; str(stream, hex(round.geometry_digest));
        stream << ",\"semantic_digest\":"; str(stream, hex(round.semantic_digest));
        stream << ",\"frame_changed\":" << round.frame_changed << ",\"mosaic_changed\":" << round.mosaic_changed
               << ",\"frame_footprint_changed\":" << round.frame_footprint_changed
               << ",\"mosaic_footprint_changed\":" << round.mosaic_footprint_changed
               << ",\"category_changed\":" << round.category_changed << ",\"frame_work\":" << round.frame_work
               << ",\"mosaic_work\":" << round.mosaic_work << ",\"solver_work\":" << round.solver_work
               << ",\"shared_work\":" << round.shared_work
               << ",\"frame_accepted\":" << (round.frame_accepted ? "true" : "false")
               << ",\"mosaic_accepted\":" << (round.mosaic_accepted ? "true" : "false");
        stream << ",\"frame_reused\":" << (round.frame_reused ? "true" : "false")
               << ",\"mosaic_reused\":" << (round.mosaic_reused ? "true" : "false")
               << ",\"frame_reuse_round\":" << round.frame_reuse_round
               << ",\"mosaic_reuse_round\":" << round.mosaic_reuse_round;
        stream << ",\"frame\":"; frame_revision(stream, round.frame);
        stream << ",\"mosaic\":"; mosaic_plan(stream, round.mosaic);
        stream << ",\"mosaic_request\":"; request(stream, round.mosaic_request);
        stream << ",\"proposed_frame\":"; result(stream, round.proposed_frame);
        stream << ",\"proposed_mosaic\":"; result(stream, round.proposed_mosaic);
        stream << ",\"mosaic_proposal_reason\":"; str(stream, round.mosaic_proposal_reason);
        stream << ",\"mosaic_proposal_work\":" << round.mosaic_proposal_work
               << ",\"mosaic_proposal_solver_debit\":" << round.mosaic_proposal_solver_debit;
        stream << ",\"mosaic_bearing_work\":" << round.mosaic_bearing_work << ",\"mosaic_bearing_rejections\":";
        array(stream, round.mosaic_bearing_rejections, str);
        stream << ",\"mosaic_bearing_replacements\":";
        array(stream, round.mosaic_bearing_replacements, [](auto& s, const MosaicBearingReplacement& replacement) {
            s << "{\"slot\":" << replacement.slot << ",\"instance\":" << replacement.instance << ",\"point\":";
            point(s, replacement.point); s << ",\"before\":" << static_cast<unsigned>(replacement.before)
              << ",\"after\":" << static_cast<unsigned>(replacement.after) << ",\"rule\":";
            str(s, replacement.rule); s << '}';
        });
        stream << ",\"mosaic_supported_receptor_work\":" << round.mosaic_supported_receptor_work
               << ",\"mosaic_supported_receptors\":";
        array(stream, round.mosaic_supported_receptors, [](auto& s, const SupportedNativeReceptor& r) {
            s << "{\"slot\":" << r.slot << ",\"connector\":" << r.connector
              << ",\"source_instance\":" << r.source_instance
              << ",\"receiving_instance\":" << r.receiving_instance
              << ",\"port_id\":" << r.port_id << ",\"root\":"; point(s, r.root);
            s << ",\"contact\":"; point(s, r.contact); s << ",\"backing\":"; point(s, r.backing);
            s << ",\"facing\":"; point(s, r.facing); s << '}';
        });
        stream << ",\"mosaic_trace\":"; resilience_trace(stream, round.mosaic_trace);
        if(options.negotiated_recovery) {
            stream<<",\"recovery_work\":"<<round.recovery_work
                  <<",\"recovery_frontier_exhausted\":"<<(round.recovery_frontier_exhausted?"true":"false")
                  <<",\"recovery_frontier\":";
            array(stream,round.recovery_frontier,[](auto& s,const RecoveryCursor& r){
                s<<"{\"slot\":"<<r.slot<<",\"next\":"<<r.next<<",\"observation\":";str(s,hex(r.observation));
                s<<",\"exhausted\":"<<(r.exhausted?"true":"false")<<'}';});
            stream<<",\"recovery_attempts\":";
            array(stream,round.recovery_attempts,[](auto& s,const RecoveryAttempt& r){
                s<<"{\"slot\":"<<r.slot<<",\"connector\":"<<r.connector<<",\"ordinal\":"<<r.ordinal
                 <<",\"round\":"<<r.round<<",\"source_instance\":"<<r.source_instance<<",\"host_instance\":"<<r.host_instance
                 <<",\"root\":";point(s,r.root);s<<",\"contact\":";point(s,r.contact);s<<",\"axis\":";point(s,r.axis);
                s<<",\"length\":"<<r.length<<",\"variant\":"<<r.variant<<",\"work\":"<<r.work<<",\"phase\":";str(s,r.phase);
                s<<",\"outcome\":";str(s,r.outcome);s<<",\"reason\":";str(s,r.reason);s<<'}';});
            stream<<",\"mosaic_recovery_receipts\":";
            array(stream,round.mosaic_recovery_receipts,[](auto& s,const MosaicRecoveryReceipt& r){
                s<<"{\"slot\":"<<r.slot<<",\"connector\":"<<r.connector<<",\"source_instance\":"<<r.source_instance
                 <<",\"host_instance\":"<<r.host_instance<<",\"receiving_instance\":"<<r.receiving_instance
                 <<",\"port_id\":"<<r.port_id<<",\"round\":"<<r.round<<",\"candidate\":"<<r.candidate;
                s<<",\"root\":";point(s,r.root);s<<",\"contact\":";point(s,r.contact);s<<",\"backing\":";point(s,r.backing);
                s<<",\"axis\":";point(s,r.axis);s<<",\"cross\":";point(s,r.cross);s<<",\"host\":";point(s,r.host);
                s<<",\"length\":"<<r.length<<",\"variant\":"<<r.variant<<",\"source_family\":";str(s,name(r.source_family));
                s<<",\"receiving_family\":";str(s,name(r.receiving_family));s<<",\"source_digest\":";str(s,hex(r.source_digest));
                s<<",\"prior_digest\":";str(s,hex(r.prior_digest));s<<",\"work\":"<<r.work<<",\"edits\":";
                array(s,r.edits,[](auto& t,const RecoveryEdit& e){t<<"{\"point\":";point(t,e.point);
                    t<<",\"before\":"<<static_cast<unsigned>(e.before)<<",\"after\":"<<static_cast<unsigned>(e.after)
                     <<",\"before_role\":"<<static_cast<unsigned>(e.before_role)<<",\"after_role\":"<<static_cast<unsigned>(e.after_role)
                     <<",\"before_owner\":"<<e.before_owner<<",\"after_owner\":"<<e.after_owner<<'}';});s<<'}';});
        }
        stream << '}';
    });
    o << ",\"damage_derivative\":";
    if (c.damage_derivative) {
        const auto& damage = *c.damage_derivative;
        o << "{\"frame\":"; frame_revision(o, damage.frame);
        o << ",\"mosaic\":"; mosaic_plan(o, damage.mosaic);
        o << ",\"frame_changed\":" << damage.frame_changed << ",\"mosaic_changed\":" << damage.mosaic_changed
          << ",\"frame_footprint_changed\":" << damage.frame_footprint_changed
          << ",\"mosaic_footprint_changed\":" << damage.mosaic_footprint_changed
          << ",\"work\":" << damage.work << ",\"reason\":"; str(o, damage.reason); o << '}';
    } else o << "null";
    if(custody) {
        // JSON renders unavailable solver work as null. The in-process seal
        // also binds the raw native fields; no hidden field can be rewritten.
        o << ",\"raw_solver_debits\":[";
        const auto raw=[&](const Result& r){o<<r.solver_work<<',';};
        raw(c.original_frame.core);raw(c.original_frame.result);
        for(const auto& round:c.rounds){raw(round.frame.result);raw(round.mosaic.result);
            raw(round.proposed_frame);raw(round.proposed_mosaic);
            for(const auto& attempt:round.mosaic.attempts)o<<attempt.work<<',';
            for(const auto& attempt:round.mosaic_trace.solver.attempts)o<<attempt.solver.work<<',';
        }
        if(c.damage_derivative){raw(c.damage_derivative->frame.result);raw(c.damage_derivative->mosaic.result);
            for(const auto& attempt:c.damage_derivative->mosaic.attempts)o<<attempt.work<<',';}
        o<<"0],\"raw_request_definitions\":[";str(o,c.input.frame.definition_fingerprint);o<<',';str(o,c.input.mosaic.definition_fingerprint);
        for(const auto& round:c.rounds){o<<',';str(o,round.mosaic_request.definition_fingerprint);}
        o<<"],\"rejections\":";array(o,c.rejections,str);o<<'}';return;
    }
    o << ",\"cells\":"; numbers(o, c.cells);
    o << ",\"ledger_columns\":[\"owner\",\"instance\",\"rule\",\"first_round\",\"last_round\",\"revision_mask\"]";
    o << ",\"owner_names\":[\"empty\",\"FRAMEWEAVER\",\"MOSAIC\",\"immutable_environment\"],\"ledger\":";
    array(o, c.ledger, [](auto& stream, const CellLedger& ledger) {
        stream << '[' << static_cast<unsigned>(ledger.owner) << ',' << ledger.instance << ',' << ledger.rule << ','
               << static_cast<unsigned>(ledger.first_round) << ',' << static_cast<unsigned>(ledger.last_round) << ','
               << static_cast<unsigned>(ledger.revision_mask) << ']';
    });
    o << ",\"rules\":"; array(o, c.rules, str);
    o << ",\"obligations\":";
    array(o, c.obligations, [](auto& stream, const ObligationReceipt& obligation) {
        stream << "{\"connector\":" << obligation.connector << ",\"instance\":" << obligation.instance
               << ",\"slot\":" << obligation.slot << ",\"original\":"; point(stream, obligation.original);
        stream << ",\"facing\":"; point(stream, obligation.facing);
        stream << ",\"origin\":"; str(stream, obligation.origin);
        stream << ",\"foreign_joined\":" << (obligation.foreign_joined ? "true" : "false")
               << ",\"local_terminated\":" << (obligation.local_terminated ? "true" : "false") << ",\"state\":";
        str(stream, obligation.state); stream << ",\"reason\":"; str(stream, obligation.reason); stream << '}';
    });
    o << ",\"joints\":";
    array(o, c.joints, [](auto& stream, const JointWitness& joint) {
        stream << "{\"connector\":" << joint.connector << ",\"slot\":" << joint.slot
               << ",\"frame_instance\":" << joint.frame_instance << ",\"mosaic_instance\":" << joint.mosaic_instance
               << ",\"root\":"; point(stream, joint.root);
        stream << ",\"frame_face\":"; point(stream, joint.frame_face);
        stream << ",\"masonry_face\":"; point(stream, joint.masonry_face);
        stream << ",\"normal\":"; point(stream, joint.normal);
        stream << ",\"family\":"; str(stream, name(joint.family));
        stream << ",\"path\":"; array(stream, joint.path, point); stream << '}';
    });
    o << ",\"metrics\":"; stats(o, c.metrics);
    o << ",\"rejections\":"; array(o, c.rejections, str);
    o << "}\n";
}
} // namespace

CustodyDigest fingerprint_native_custody(const Composition& c,std::uint64_t& charged,std::uint64_t ceiling) {
    CustodyHashBuffer buffer(charged,ceiling,c.input.cancel);std::ostream stream(&buffer);
    stream.exceptions(std::ios::badbit|std::ios::failbit);stream<<std::setprecision(17);
    stream.iword(custody_encoding_index())=1;
    stream<<"SWARM006/native-custody-binary-arrays-v1:";
    composition_json(stream,c,true);return buffer.finish();
}

void write_composition_json(const std::string& path,const Composition& c) {
    const std::filesystem::path destination(path),temporary(path+".partial");
    if(std::filesystem::exists(destination)||std::filesystem::exists(temporary))
        throw std::invalid_argument("refusing to overwrite retained reciprocal evidence: "+path);
    auto o=output(temporary.string());composition_json(o,c,false);o.close();
    if(!o)throw std::runtime_error("reciprocal evidence write failed; partial retained: "+temporary.string());
    std::filesystem::rename(temporary,destination);
}

void write_matched_mosaic_control_json(const std::string& path, const std::string& policy,
    const Composition& candidate, const Request& accepted_request,
    const MosaicRevision& control, std::uint64_t changed_frame_cells) {
    const std::filesystem::path destination(path), temporary(path + ".partial");
    if (candidate.rounds.empty() || std::filesystem::exists(destination) || std::filesystem::exists(temporary))
        throw std::invalid_argument("invalid or already retained matched FRAME control destination");
    const auto& final = candidate.rounds.back();
    auto stream = output(temporary.string());
    stream << "{\"schema\":6,\"type\":\"matched_final_frame_no_offer\",\"programme\":\"GENTEK-SWARM-004\",\"source\":";
    str(stream, candidate.input.frame.source_identity);
    stream << ",\"candidate_policy\":"; str(stream, policy);
    stream << ",\"candidate_digest\":"; str(stream, hex(candidate.digest));
    stream << ",\"candidate_round\":" << final.number << ",\"frame_changed_from_initial_cells\":" << changed_frame_cells;
    stream << ",\"status\":"; str(stream, name(control.status)); stream << ",\"reason\":"; str(stream, control.reason);
    stream << ",\"control_only\":true,\"can_apply\":false,\"offered_slots\":[],\"budget\":{\"generator\":2000000,\"solver\":4000000,\"bytes\":16777216,\"proposals\":1}";
    stream << ",\"work\":{\"preparation\":" << control.wrapper_work << ",\"generator\":" << control.generator_work
           << ",\"solver_debit\":" << control.solver_debit << ",\"solver_work_observed\":" << (control.solver_work_observed ? "true" : "false")
           << ",\"total\":" << control.wrapper_work + control.generator_work + control.solver_debit << '}';
    stream << ",\"accepted_request\":"; request(stream, accepted_request);
    stream << ",\"request\":"; request(stream, control.request);
    stream << ",\"shared_zone\":"; numbers(stream, candidate.input.shared_zone);
    stream << ",\"frame\":"; result(stream, final.frame.result);
    stream << ",\"candidate_mosaic\":"; mosaic_plan(stream, final.mosaic);
    stream << ",\"mosaic\":"; mosaic_plan(stream, control.plan);
    stream << ",\"trace\":"; resilience_trace(stream, control.trace);
    stream << ",\"material_diff_available\":" << (control.plan.result.cells.size() == final.mosaic.result.cells.size() &&
        control.plan.result.cells.size() == static_cast<std::size_t>(accepted_request.width) * static_cast<std::size_t>(accepted_request.height) ? "true" : "false");
    stream << ",\"category_diff_available\":" << (!control.plan.categories.empty() && control.plan.categories.size() == final.mosaic.categories.size() ? "true" : "false");
    stream << ",\"material_changes\":";
    array(stream, control.geometry_changes, [](auto& out, const MosaicCellRevision& change) {
        out << "{\"cell\":" << change.cell << ",\"before\":" << static_cast<unsigned>(change.before)
            << ",\"after\":" << static_cast<unsigned>(change.after) << ",\"before_part\":" << change.before_part
            << ",\"after_part\":" << change.after_part << '}';
    });
    stream << ",\"category_changes\":";
    array(stream, control.category_changes, [](auto& out, const MosaicCategoryRevision& change) {
        out << "{\"tile\":" << change.tile << ",\"before\":" << change.before << ",\"after\":" << change.after << '}';
    });
    stream << ",\"cells\":[";
    const auto& cells = control.plan.result.cells;
    if (cells.size() == final.frame.result.cells.size()) {
        for (std::size_t i = 0; i < cells.size(); ++i) {
            if (i) stream << ',';
            const auto context = control.request.context.empty() ? Material::Empty : control.request.context[i];
            stream << static_cast<unsigned>(final.frame.result.cells[i] != Material::Empty ? final.frame.result.cells[i] :
                cells[i] != Material::Empty ? cells[i] : context);
        }
    }
    stream << "]}\n";
    stream.close();
    if (!stream) throw std::runtime_error("matched FRAME control write failed; partial retained");
    std::filesystem::rename(temporary, destination);
}

} // namespace cybersand::gentek_swarm::assembly004
