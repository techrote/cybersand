#include "negotiated.hpp"
#include "resilience.hpp"
#include <fstream>
#include <iomanip>
#include <stdexcept>

namespace cybersand::gentek_swarm {
namespace {
void str(std::ostream& o,const std::string& s){o<<'"';for(const unsigned char c:s){switch(c){case '"':o<<"\\\"";break;case '\\':o<<"\\\\";break;case '\n':o<<"\\n";break;case '\r':o<<"\\r";break;case '\t':o<<"\\t";break;default:if(c<32)o<<"?";else o<<c;}}o<<'"';}
void point(std::ostream& o,Point p){o<<'['<<p.x<<','<<p.y<<']';}
template<class T>void numbers(std::ostream& o,const std::vector<T>& v){o<<'[';bool first=true;for(auto x:v){if(!first)o<<',';first=false;o<<static_cast<std::uint64_t>(x);}o<<']';}
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
void write_result_json(const std::string& path,const Request& r,const Result& s){auto o=output(path);o<<"{\"schema\":1,\"type\":\"single\",\"request\":";request(o,r);o<<",\"result\":";result(o,s);o<<"}\n";if(!o)throw std::runtime_error("evidence write failed");}
static void pair(std::ostream& o,const PairResult& p){o<<"{\"schema\":1,\"type\":\"pair\",\"fixture\":";str(o,p.fixture.id);o<<",\"fixture_digest\":";str(o,hex(p.fixture.digest));o<<",\"digest\":";str(o,hex(p.digest));o<<",\"policy\":";str(o,p.policy);o<<",\"left_request\":";request(o,p.left_request);o<<",\"right_request\":";request(o,p.right_request);o<<",\"left\":";result(o,p.left);o<<",\"right\":";result(o,p.right);o<<",\"initial_left\":";result(o,p.initial_left);o<<",\"initial_right\":";result(o,p.initial_right);o<<",\"clipped_left\":";result(o,p.clipped_left);o<<",\"clipped_right\":";result(o,p.clipped_right);
    o<<",\"cells\":";numbers(o,p.cells);o<<",\"initial_cells\":";numbers(o,p.initial_cells);o<<",\"clipped_cells\":";numbers(o,p.clipped_cells);o<<",\"side\":";numbers(o,p.fixture.side);o<<",\"work\":"<<p.work<<",\"conflicts\":"<<p.conflicts<<",\"protected_violations\":"<<p.protected_violations<<",\"bridges\":"<<p.bridges<<",\"typed_contacts\":"<<p.typed_contacts<<",\"bridge_cells\":"<<p.bridge_cells<<",\"unresolved_seams\":"<<p.unresolved_seams<<",\"seams\":";
    array(o,p.seams,[](auto& s,const auto& a){s<<"{\"left_affordance\":"<<a.left_affordance<<",\"right_affordance\":"<<a.right_affordance<<",\"a\":";point(s,a.a);s<<",\"b\":";point(s,a.b);s<<",\"joined\":"<<(a.joined?"true":"false")<<",\"reason\":";str(s,a.reason);s<<",\"cells\":";array(s,a.cells,point);s<<'}';});o<<"}\n";if(!o)throw std::runtime_error("evidence write failed");}
void write_pair_json(const std::string& path,const PairResult& p){auto o=output(path);pair(o,p);}

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
static void negotiated(std::ostream& o,const NegotiatedResult& n) {
    o<<"{\"schema\":2,\"type\":\"negotiated\",\"predecessor\":";str(o,swarm001_predecessor);
    o<<",\"digest\":";str(o,hex(n.digest));o<<",\"offer_policy\":";str(o,n.offer_policy);o<<",\"control\":";pair(o,n.control);
    o<<",\"frame_request\":";request(o,n.frame_request);o<<",\"mosaic_request\":";request(o,n.mosaic_request);
    o<<",\"residual_request\":";request(o,n.residual_request);
    o<<",\"frame\":{\"core\":";result(o,n.frame.core);o<<",\"result\":";result(o,n.frame.result);
    o<<",\"slots\":";array(o,n.frame.slots,slot);o<<",\"reservation_rejections\":";array(o,n.frame.reservation_rejections,str);o<<'}';
    o<<",\"mosaic\":";mosaic_plan(o,n.mosaic);o<<",\"no_offers\":";mosaic_plan(o,n.no_offers);
    o<<",\"final_frame\":";result(o,n.final_frame);o<<",\"final_mosaic\":";result(o,n.final_mosaic);
    o<<",\"residual\":";result(o,n.residual);
    o<<",\"planned_cells\":";numbers(o,n.planned_cells);o<<",\"cells\":";numbers(o,n.cells);
    o<<",\"finished_cells\":";numbers(o,n.finished_cells);o<<",\"no_offer_cells\":";numbers(o,n.no_offer_cells);
    o<<",\"metrics\":";stats(o,n.metrics);o<<",\"notes\":";array(o,n.notes,str);
    o<<",\"seams\":";array(o,n.seams,[](auto& s,const auto& a){s<<"{\"left_affordance\":"<<a.left_affordance<<",\"right_affordance\":"<<a.right_affordance<<",\"a\":";point(s,a.a);s<<",\"b\":";point(s,a.b);s<<",\"joined\":"<<(a.joined?"true":"false")<<",\"reason\":";str(s,a.reason);s<<",\"cells\":";array(s,a.cells,point);s<<'}';});
    o<<"}\n";if(!o)throw std::runtime_error("negotiated evidence write failed");
}
void write_negotiated_json(const std::string& path,const NegotiatedResult& n) {
    auto o=output(path);negotiated(o,n);
}
void write_admission_json(const std::string& path,const AdmissionResult& n) {
    auto o=output(path);const auto& a=n.admission;const auto& q=n.candidate.frame_request;
    o<<"{\"schema\":3,\"type\":\"optional_offer_admission\",\"frozen_c_source\":";
    str(o,"21617b14253cc6dcf35a83ded558565c8db517f5");
    o<<",\"digest\":";str(o,hex(n.digest));
    o<<",\"control_file\":";str(o,"controls-c/full_control_"+q.fixture+"_"+q.profile.name+"_"+std::to_string(q.seed)+".json");
    o<<",\"admission\":{\"mode\":";str(o,name(a.policy.mode));
    o<<",\"optional_cap\":"<<a.policy.optional_cap<<",\"omitted_optional_id\":"<<a.policy.omitted_optional_id;
    o<<",\"status\":";str(o,name(a.status));o<<",\"reason\":";str(o,a.reason);
    o<<",\"diagnostic\":"<<(a.diagnostic?"true":"false")<<",\"budget_mode\":";
    str(o,a.diagnostic?"equal-first-budget-2m":"primary");
    o<<",\"digest\":";str(o,hex(a.digest));o<<",\"selected_ids\":";numbers(o,a.selected_ids);
    o<<",\"work\":"<<a.work<<",\"work_limit\":"<<a.work_limit<<",\"ranking_work\":"<<a.ranking_work
     <<",\"selection_work\":"<<a.selection_work<<",\"join_work_limit\":"<<a.join_work_limit
     <<",\"structural_work_upper_bound\":"<<a.structural_work_upper_bound<<",\"solver_work_limit\":"<<a.solver_work_limit;
    o<<",\"decisions\":";array(o,a.decisions,[](auto& s,const auto& d){
        s<<"{\"slot_id\":"<<d.slot_id<<",\"mandatory\":"<<(d.mandatory?"true":"false")
         <<",\"selected\":"<<(d.selected?"true":"false")<<",\"witness_found\":"<<(d.witness_found?"true":"false")
         <<",\"rank\":"<<d.rank<<",\"nearest_forward_distance\":"<<d.nearest_forward_distance;
        s<<",\"witness_source\":";point(s,d.witness_source);s<<",\"witness_peer\":";point(s,d.witness_peer);
        s<<",\"reason\":";str(s,d.reason);s<<'}';
    });o<<"},\"candidate\":";negotiated(o,n.candidate);o<<"}\n";
    if(!o)throw std::runtime_error("admission evidence write failed");
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
} // namespace

void write_resilience_json(const std::string& path,const ResilienceResult& r) {
    auto o=output(path);
    o<<"{\"schema\":4,\"type\":\"resilient_negotiation\",\"parent\":";
    str(o,"5bf7b4b90616130577744e39c9fbc9c0376c52b2");
    o<<",\"digest\":";str(o,hex(r.digest));o<<",\"options\":{\"admission\":";str(o,name(r.options.admission));
    o<<",\"schedule\":";str(o,name(r.options.schedule));o<<",\"fallback\":";str(o,name(r.options.fallback));
    o<<",\"receivers\":";str(o,name(r.options.receivers));o<<",\"optional_capacity\":"<<r.options.optional_capacity<<'}';
    o<<",\"preparation_work\":"<<r.preparation_work<<",\"join_work_limit\":"<<r.join_work_limit;
    const auto& t=r.trace;
    o<<",\"trace\":{\"reason\":";str(o,t.reason);o<<",\"final_authorized_ids\":";numbers(o,t.final_authorized_ids);
    o<<",\"primary_selected_ids\":";numbers(o,t.primary_selected_ids);o<<",\"fallback_selected_ids\":";numbers(o,t.fallback_selected_ids);
    o<<",\"dropped_preference_ids\":";numbers(o,t.dropped_preference_ids);o<<",\"receivers\":";array(o,t.receivers,receiver_decision);
    o<<",\"admission\":";native_admission(o,t.admission);o<<",\"solver\":";resilient_solver(o,t.solver);
    o<<"},\"candidate\":";negotiated(o,r.candidate);o<<"}\n";
    if(!o)throw std::runtime_error("resilience evidence write failed");
}
} // namespace cybersand::gentek_swarm
