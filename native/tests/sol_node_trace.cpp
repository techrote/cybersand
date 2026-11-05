// Copied-value observation parity. No World, Godot or Rapier objects.
#define main retained_passive_values_main
#include "sol_passive_values.cpp"
#undef main
#include <memory>
#include <stdexcept>

static std::uint64_t checks=0;
static void require(bool value) {++checks;if(!value)throw std::runtime_error("node trace invariant");}
static std::string fingerprint(const g::SolveTrace& t) {
    std::ostringstream s;s<<std::hexfloat<<unsigned(t.status)<<' '<<unsigned(t.policy)<<' '<<t.samples<<' '<<t.input_bins<<' '<<t.total_nodes<<' '<<t.captured_nodes<<' '<<t.dropped_nodes<<' '<<t.batch_count<<' '<<t.raw_energy_after;
    s<<' '<<t.body.velocity.x<<' '<<t.body.velocity.y<<' '<<t.body.com.x<<' '<<t.body.com.y<<' '<<t.body.omega<<' '<<t.body.mass<<' '<<t.body.inertia<<' '<<t.body.mu<<' '<<t.available<<' '<<t.capacity_scale<<' '<<t.base_budget;
    for(std::size_t i=0;i<t.captured_nodes;++i) {
        const auto& n=t.nodes[i];const auto& c=n.input;
        s<<' '<<c.position.x<<' '<<c.position.y<<' '<<c.normal.x<<' '<<c.normal.y<<' '<<c.weight<<' '<<c.capacity<<' '<<n.bin_index<<' '<<n.source_count<<' '<<n.quadrature_index<<' '<<n.quadrature_count<<' '<<n.quadrature_clamped;
    }
    for(std::size_t j=0;j<t.batch_count;++j) {
        const auto& b=t.batches[j];s<<' '<<b.velocity_before.x<<' '<<b.velocity_before.y<<' '<<b.omega_before<<' '<<b.velocity_after.x<<' '<<b.velocity_after.y<<' '<<b.omega_after<<' '<<b.pass<<' '<<b.axis<<' '<<b.diagnostic_active_count<<' '<<b.diagnostic_active_weight<<' '<<b.policy_active_count<<' '<<b.policy_active_weight<<' '<<b.policy_mask_valid<<' '<<b.normal_cap_hits<<' '<<b.tangent_cap_hits;
        for(std::size_t i=0;i<t.captured_nodes;++i) {const auto& n=b.nodes[i];s<<' '<<n.jn_before<<' '<<n.jt_before<<' '<<n.jn_after<<' '<<n.jt_after<<' '<<n.speed<<' '<<n.requested<<' '<<n.weight_used<<' '<<n.target<<' '<<n.next<<' '<<n.delta<<' '<<n.limit<<' '<<n.flags;}
    }
    return s.str();
}
static void inspect(const g::SolveTrace& t) {
    require(t.captured_nodes==std::min(t.total_nodes,64U));require(t.dropped_nodes==t.total_nodes-t.captured_nodes);
    if(t.status==g::TraceStatus::InputRefused) {require(t.batch_count==0 && t.captured_nodes==0 && t.result.passive_rejected);return;}
    require(t.batch_count==8);require(t.status==(t.dropped_nodes ? g::TraceStatus::IncompleteNodeCap:g::TraceStatus::Complete));
    for(unsigned j=0;j<8;++j) {
        const auto& b=t.batches[j];require(b.pass==j/2 && b.axis==j%2);
        require(b.policy_mask_valid==(!b.axis && t.policy==g::NormalPolicy::ActiveNormal001));
        if(j) {const auto& prior=t.batches[j-1];require(b.velocity_before.x==prior.velocity_after.x && b.velocity_before.y==prior.velocity_after.y && b.omega_before==prior.omega_after);}
        std::uint32_t caps=0;
        for(std::size_t i=0;i<t.captured_nodes;++i) {
            const auto& n=b.nodes[i];const auto& c=t.nodes[i].input;const auto r=c.position-t.body.com;
            const auto d=b.axis ? g::Vec{-c.normal.y,c.normal.x}:c.normal;
            const double speed=g::dot(b.velocity_before+g::Vec{-b.omega_before*r.y,b.omega_before*r.x},d);
            require(n.speed==speed);require(n.requested==-speed/(1./t.body.mass+g::cross(r,d)*g::cross(r,d)/t.body.inertia));
            const double prior=b.axis ? n.jt_before:n.jn_before;
            require(n.target==prior+n.requested*n.weight_used);require(n.delta==n.next-prior);
            require(n.next==std::clamp(n.target,b.axis ? -n.limit:0.,n.limit));
            require(n.limit==(b.axis ? t.body.mu*n.jn_before:c.capacity));
            const bool hit=b.axis ? std::abs(n.target)>n.limit:n.target>n.limit;
            require(bool(n.flags&g::CapHit)==hit);caps+=hit ? 1U:0U;
            if(b.axis) {require(!(n.flags&(g::DiagnosticActiveValid|g::PolicyMaskValid)));require(n.jn_after==n.jn_before && n.jt_after==n.next && n.weight_used==c.weight);}
            else {
                const bool active=speed<0 || n.jn_before>0;require(bool(n.flags&g::DiagnosticActiveValid));require(bool(n.flags&g::DiagnosticActive)==active);
                require(n.jt_after==n.jt_before && n.jn_after==n.next);
                if(b.policy_mask_valid) {require(bool(n.flags&g::PolicyMaskValid) && bool(n.flags&g::PolicyActive)==active);
                    const double expected=b.policy_active_count==t.total_nodes ? c.weight:(active && b.policy_active_weight>0 ? c.weight/b.policy_active_weight:0.);require(n.weight_used==expected);}
                else require(n.weight_used==c.weight && !(n.flags&g::PolicyMaskValid));
            }
        }
        require(t.dropped_nodes ? caps<=(b.axis ? b.tangent_cap_hits:b.normal_cap_hits):caps==(b.axis ? b.tangent_cap_hits:b.normal_cap_hits));
    }
}
static Case boundary(unsigned nodes) {
    Case c;c.id="observer-nodes-"+std::to_string(nodes);c.body={{3,.2},{0,0},.1,2,17,.78};
    for(unsigned i=0;i<(nodes==1024 ? 512:nodes);++i) {g::Bin b;b.add({0,-1},{-1,0},c.body.com);if(nodes==1024)b.add({0,1},{-1,0},c.body.com);c.bins.push_back(b);}return c;
}
int main(int argc,char** argv) {
    if(argc!=2)return 2;
    std::ifstream input(argv[1]);unsigned count=0;input>>count;if(count!=38)return 3;
    std::vector<Case> cases;
    for(unsigned i=0;i<count;++i) {
        Case c;unsigned null=0,bins=0;
        input>>c.id>>c.body.velocity.x>>c.body.velocity.y>>c.body.com.x>>c.body.com.y>>c.body.omega>>c.body.mass>>c.body.inertia>>c.body.mu>>c.available>>c.scale>>c.budget>>null>>bins;
        if(!input || bins>513)return 4;
        c.null_bin=null!=0;
        for(unsigned j=0;j<bins;++j) {unsigned points=0;g::Vec normal;input>>points>>normal.x>>normal.y;if(points>1024)return 5;g::Bin b;
            for(unsigned k=0;k<points;++k) {g::Vec point;input>>point.x>>point.y;b.add(point,normal,c.body.com);}c.bins.push_back(b);}
        if(!input)return 6;
        cases.push_back(c);
    }
    for(unsigned n:{0U,1U,64U,65U,1024U})cases.push_back(boundary(n));
    auto sink=std::make_unique<g::SolveTrace>();const Case poison=boundary(1024);const auto poison_ptrs=poison.pointers();
    for(const auto policy:{g::NormalPolicy::Original,g::NormalPolicy::ActiveNormal001}) for(const auto& c:cases) {
        g::CompoundWorkspace reference{},fresh{},reused{};const auto ptrs=c.pointers();
        const auto baseline=g::solve_compound(c.body,ptrs,reference,c.available,c.scale,c.budget,policy);const auto encoded=encode(c,baseline,reference);
        const auto on=g::solve_compound(c.body,ptrs,fresh,c.available,c.scale,c.budget,policy,sink.get());require(encoded==encode(c,on,fresh));require(encoded==encode(c,sink->result,fresh));inspect(*sink);const auto capture=fingerprint(*sink);
        g::solve_compound(poison.body,poison_ptrs,reused,20,1,20,g::NormalPolicy::ActiveNormal001,sink.get());
        const auto again=g::solve_compound(c.body,ptrs,reused,c.available,c.scale,c.budget,policy,sink.get());require(encoded==encode(c,again,reused));require(capture==fingerprint(*sink));
        sink->body=c.body;
        const auto alias=g::solve_compound(sink->body,ptrs,reused,c.available,c.scale,c.budget,policy,sink.get());require(encoded==encode(c,alias,reused));require(capture==fingerprint(*sink));
    }
    Case bad=boundary(1);bad.available=std::numeric_limits<double>::quiet_NaN();g::CompoundWorkspace workspace{};
    g::solve_compound(bad.body,bad.pointers(),workspace,bad.available,1,20,g::NormalPolicy::Original,sink.get());inspect(*sink);require(std::isnan(sink->available));
    std::cout<<"{\"registration\":\"SOL-NODE-TRACE-001\",\"cases\":"<<cases.size()<<",\"policies\":2,\"checks\":"<<checks<<",\"workspace_bytes\":"<<sizeof(g::CompoundWorkspace)<<",\"trace_bytes\":"<<sizeof(g::SolveTrace)<<",\"physical_parity\":true,\"reused_trace_parity\":true,\"body_alias_parity\":true}\n";
}
