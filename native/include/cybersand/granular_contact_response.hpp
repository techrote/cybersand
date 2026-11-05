#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <span>

namespace cybersand::gcr {

// GCR-001 v1: all quantities are copied values in the adapter's cell units.
// Value-only contact solve in fixed workspace.
struct Vec {
    double x = 0, y = 0;
    Vec operator+(Vec b) const { return {x+b.x,y+b.y}; }
    Vec operator-(Vec b) const { return {x-b.x,y-b.y}; }
    Vec operator*(double s) const { return {x*s,y*s}; }
};
inline double dot(Vec a, Vec b) { return a.x*b.x+a.y*b.y; }
inline double cross(Vec a, Vec b) { return a.x*b.y-a.y*b.x; }
// Keep the Linux runtime floor independent of newer libm hypot symbol versions.
// Scaling avoids intermediate-square overflow/underflow for finite inputs.
inline double length(Vec a) {
    const double x=std::abs(a.x),y=std::abs(a.y);
    if(std::isinf(x) || std::isinf(y)) return std::numeric_limits<double>::infinity();
    if(std::isnan(x) || std::isnan(y)) return std::numeric_limits<double>::quiet_NaN();
    const double high=std::max(x,y),low=std::min(x,y);
    if(high==0) return 0.;
    const double ratio=low/high;
    return high*std::sqrt(1.+ratio*ratio);
}
struct Bin {
    std::uint32_t count = 0;
    std::uint64_t material_mask = 0;
    std::uint8_t state_b_min = 255, state_b_max = 0;
    Vec position_sum{}, normal{};
    double maximum_radius = 0;
    double tangent_mean = 0, tangent_m2 = 0, tangent_min = 0, tangent_max = 0;
    void add(Vec point, Vec inward, Vec com) {
        ++count; position_sum=position_sum+point; normal=inward;
        const double coordinate=dot(point,Vec{-inward.y,inward.x});
        if(count==1) tangent_mean=tangent_min=tangent_max=coordinate;
        else {
            const double previous=tangent_mean;
            tangent_mean+=(coordinate-tangent_mean)/count;
            tangent_m2+=(coordinate-previous)*(coordinate-tangent_mean);
            tangent_min=std::min(tangent_min,coordinate); tangent_max=std::max(tangent_max,coordinate);
        }
        maximum_radius=std::max(maximum_radius,length(point-com));
    }
};
struct Quadrature {
    Vec low{},high{};
    std::uint32_t nodes=0;
    bool clamped=false;
};
inline Quadrature quadrature(const Bin& bin) {
    if(!bin.count) return {};
    const Vec center=bin.position_sum*(1./bin.count),t{-bin.normal.y,bin.normal.x};
    const double sigma=std::sqrt(std::max(0.,bin.tangent_m2/bin.count));
    // Symmetric clipping preserves the first moment; represented variance may
    // decrease and is explicitly qualified rather than silently extrapolated.
    const double extent=std::max(0.,std::min(bin.tangent_mean-bin.tangent_min,
                                           bin.tangent_max-bin.tangent_mean));
    const double distance=std::min(sigma,extent);
    return {center-t*distance,center+t*distance,distance==0 ? 1U:2U,sigma>extent+1e-12};
}
struct Body { Vec velocity{}, com{}; double omega=0,mass=1,inertia=1,mu=0; };
// LA is opt-in. Preserve old arithmetic at scale1; no support is fabricated.
inline double load_scale(double mass) {
    return std::isfinite(mass) && mass>0 ? std::max(1.,std::min(mass,4096.)) : 0.;
}
struct ContactNode { Vec position{},normal{}; double weight=0,capacity=0,jn=0,jt=0; };
struct Result {
    Vec impulse{}, normal_impulse{}, tangent_impulse{}, raw_impulse{};
    double torque=0, raw_torque=0, normal=0, tangent=0, raw_normal=0, raw_tangent=0;
    double capacity=0, energy_before=0, energy_after=0, scale=1, max_radius=0;
    std::uint32_t bins=0, nodes=0, quadrature_clamps=0, updates=0, normal_cap_hits=0, tangent_cap_hits=0;
    bool passive_rejected=false;
};
inline double kinetic(const Body& b, Vec v, double w) {
    return .5*b.mass*dot(v,v)+.5*b.inertia*w*w;
}
inline constexpr std::size_t kCompoundShapes=64,kCompoundBins=kCompoundShapes*8,kCompoundNodes=kCompoundBins*2;
// Experimental policy is explicit; existing callers retain original arithmetic.
enum class NormalPolicy { Original, ActiveNormal001 };
struct CompoundWorkspace {
    using Contact=ContactNode;
    std::array<Contact,kCompoundNodes> contacts{};
    std::array<double,kCompoundNodes> delta{};
    std::array<bool,kCompoundNodes> active{};
};
// Optional copied-value observation. This cap never limits the physical solve.
inline constexpr std::size_t kTraceNodes=64,kTraceBatches=8;
enum class TraceStatus { NotExecuted, InputRefused, Complete, IncompleteNodeCap };
enum TraceFlag : std::uint32_t {
    DiagnosticActiveValid=1, DiagnosticActive=2, PolicyMaskValid=4, PolicyActive=8,
    CapHit=16, NormalUnwind=32, TangentUnwind=64
};
struct TraceNode {
    ContactNode input{};
    std::uint32_t bin_index=0,source_count=0,quadrature_index=0,quadrature_count=0;
    bool quadrature_clamped=false;
};
struct TraceNodeStep {
    double jn_before=0,jt_before=0,jn_after=0,jt_after=0;
    double speed=0,requested=0,weight_used=0,target=0,next=0,delta=0,limit=0;
    std::uint32_t flags=0;
};
struct TraceBatch {
    Vec velocity_before{},velocity_after{};
    double omega_before=0,omega_after=0,diagnostic_active_weight=0,policy_active_weight=0;
    std::uint32_t pass=0,axis=0,diagnostic_active_count=0,policy_active_count=0;
    std::uint32_t normal_cap_hits=0,tangent_cap_hits=0;
    bool policy_mask_valid=false;
    std::array<TraceNodeStep,kTraceNodes> nodes{};
};
struct SolveTrace {
    Body body{};
    double available=0,capacity_scale=0,base_budget=0,raw_energy_after=0;
    std::uint64_t samples=0;
    std::uint32_t input_bins=0,total_nodes=0,captured_nodes=0,dropped_nodes=0,batch_count=0;
    NormalPolicy policy=NormalPolicy::Original;
    TraceStatus status=TraceStatus::NotExecuted;
    Result result{};
    std::array<TraceNode,kTraceNodes> nodes{};
    std::array<TraceBatch,kTraceBatches> batches{};
    // Only metadata is cleared; unread tails are never published. No large temp.
    void reset() {
        status=TraceStatus::NotExecuted;result={};body={};
        available=capacity_scale=base_budget=raw_energy_after=0;samples=0;
        input_bins=total_nodes=captured_nodes=dropped_nodes=batch_count=0;
        policy=NormalPolicy::Original;
    }
};
// Same R2 arithmetic, with per-rectangle bins retained and one physical state,
// normalized source distribution, budget, provisional velocity and energy test.
template<bool Observe>
inline Result solve_compound_impl(const Body& b, std::span<const Bin* const> bins,
                             CompoundWorkspace& workspace, double available, double capacity_scale, double base_budget,
                             NormalPolicy normal_policy, SolveTrace* trace) {
    Result out;
    if constexpr(Observe) {
        const Body captured_body=b; // Also supports b aliasing this sink's body.
        trace->reset();trace->status=TraceStatus::InputRefused;trace->body=captured_body;
        trace->available=available;trace->capacity_scale=capacity_scale;trace->base_budget=base_budget;
        trace->policy=normal_policy;trace->input_bins=static_cast<std::uint32_t>(bins.size());
    }
    if(bins.size()>kCompoundBins) { out.passive_rejected=true; out.scale=0; if constexpr(Observe) trace->result=out; return out; }
    auto& contacts=workspace.contacts;
    std::uint64_t samples=0;
    for(const auto* bin:bins) { if(!bin) { out.passive_rejected=true; out.scale=0; if constexpr(Observe) trace->result=out; return out; } samples+=bin->count; }
    if constexpr(Observe) trace->samples=samples;
    if(!std::isfinite(capacity_scale) || capacity_scale<1 || capacity_scale>4096 || !std::isfinite(available) || !std::isfinite(base_budget) || base_budget<5 || base_budget>80) { out.passive_rejected=true; if constexpr(Observe) trace->result=out; return out; }
    out.capacity=std::min(std::clamp(available,0.,base_budget*capacity_scale),2.*static_cast<double>(samples)*capacity_scale);
    [[maybe_unused]] std::uint32_t input_bin=0;
    for(const auto* entry:bins) {
        const auto& bin=*entry;
        [[maybe_unused]] std::uint32_t source_bin=0;
        if constexpr(Observe) source_bin=input_bin++;
        if(!bin.count) continue;
        ++out.bins; out.max_radius=std::max(out.max_radius,bin.maximum_radius);
        const auto points=quadrature(bin);
        const double weight=static_cast<double>(bin.count)/static_cast<double>(samples);
        if(points.clamped) ++out.quadrature_clamps;
        [[maybe_unused]] const auto first_node=out.nodes;
        if(points.nodes==1) contacts[out.nodes++]={points.low,bin.normal,weight,out.capacity*weight};
        else {
            contacts[out.nodes++]={points.low,bin.normal,weight*.5,out.capacity*weight*.5};
            contacts[out.nodes++]={points.high,bin.normal,weight*.5,out.capacity*weight*.5};
        }
        if constexpr(Observe) for(std::size_t i=first_node;i<out.nodes && i<kTraceNodes;++i)
            trace->nodes[i]={contacts[i],source_bin,bin.count,static_cast<std::uint32_t>(i-first_node),points.nodes,points.clamped};
    }
    if constexpr(Observe) {
        trace->total_nodes=out.nodes;trace->captured_nodes=std::min(out.nodes,static_cast<std::uint32_t>(kTraceNodes));
        trace->dropped_nodes=out.nodes-trace->captured_nodes;
    }
    Vec v=b.velocity; double w=b.omega;
    for(unsigned pass=0;pass<4;++pass) for(unsigned axis=0;axis<2;++axis) {
        if constexpr(Observe) {
            auto& batch=trace->batches[pass*2+axis];batch.velocity_before=v;batch.omega_before=w;
            batch.velocity_after={};batch.omega_after=0;batch.pass=pass;batch.axis=axis;
            batch.diagnostic_active_count=batch.policy_active_count=0;
            batch.diagnostic_active_weight=batch.policy_active_weight=0;
            batch.normal_cap_hits=out.normal_cap_hits;batch.tangent_cap_hits=out.tangent_cap_hits;
            batch.policy_mask_valid=!axis && normal_policy==NormalPolicy::ActiveNormal001;
        }
        auto& delta=workspace.delta;
        std::size_t active_count=0; double active_weight=0;
        if(!axis && normal_policy==NormalPolicy::ActiveNormal001) {
            // Freeze from this batch's state; loaded separating contacts must unwind.
            // Capacity shares remain the original source distribution.
            for(std::size_t i=0;i<out.nodes;++i) {
                const auto& contact=contacts[i]; const Vec r=contact.position-b.com;
                const double speed=dot(v+Vec{-w*r.y,w*r.x},contact.normal);
                workspace.active[i]=speed<0 || contact.jn>0;
                if(workspace.active[i]) { active_weight+=contact.weight; ++active_count; }
            }
        }
        if constexpr(Observe) {
            auto& batch=trace->batches[pass*2+axis];
            if(batch.policy_mask_valid) {batch.policy_active_count=static_cast<std::uint32_t>(active_count);batch.policy_active_weight=active_weight;}
        }
        for(std::size_t i=0;i<out.nodes;++i) {
            auto& contact=contacts[i];
            const Vec r=contact.position-b.com,n=contact.normal,d=axis ? Vec{-n.y,n.x}:n;
            const double arm=cross(r,d),speed=dot(v+Vec{-w*r.y,w*r.x},d);
            const double requested=-speed/(1./b.mass+arm*arm/b.inertia);
            if constexpr(Observe) {
                auto& batch=trace->batches[pass*2+axis];
                // Original never initializes workspace.active: derive descriptive
                // activity from the existing pre-update locals, not that array.
                const bool diagnostic_active=!axis && (speed<0 || contact.jn>0);
                if(diagnostic_active) {++batch.diagnostic_active_count;batch.diagnostic_active_weight+=contact.weight;}
                if(i<kTraceNodes) {
                    auto& node=batch.nodes[i];node={};node.jn_before=contact.jn;node.jt_before=contact.jt;
                    node.speed=speed;node.requested=requested;
                    if(!axis) {node.flags=DiagnosticActiveValid;if(diagnostic_active) node.flags|=DiagnosticActive;}
                    if(batch.policy_mask_valid) {node.flags|=PolicyMaskValid;if(workspace.active[i]) node.flags|=PolicyActive;}
                }
            }
            if(axis) {
                out.raw_tangent+=std::abs(requested);
                const double target=contact.jt+requested*contact.weight;
                if(std::abs(target)>b.mu*contact.jn) ++out.tangent_cap_hits;
                const double next=std::clamp(target,-b.mu*contact.jn,b.mu*contact.jn);
                if constexpr(Observe) if(i<kTraceNodes) {
                    auto& node=trace->batches[pass*2+axis].nodes[i];node.weight_used=contact.weight;node.target=target;node.next=next;node.limit=b.mu*contact.jn;
                    if(std::abs(target)>b.mu*contact.jn) node.flags|=CapHit;
                    if(std::abs(next)<std::abs(contact.jt)) node.flags|=TangentUnwind;
                }
                delta[i]=next-contact.jt; contact.jt=next;
            } else {
                out.raw_normal+=std::max(0.,requested);
                const double normal_weight=normal_policy==NormalPolicy::Original || active_count==out.nodes
                    ? contact.weight : (workspace.active[i] && active_weight>0 ? contact.weight/active_weight:0.);
                const double target=contact.jn+requested*normal_weight;
                if(target>contact.capacity) ++out.normal_cap_hits;
                const double next=std::clamp(target,0.,contact.capacity);
                if constexpr(Observe) if(i<kTraceNodes) {
                    auto& node=trace->batches[pass*2+axis].nodes[i];node.weight_used=normal_weight;node.target=target;node.next=next;node.limit=contact.capacity;
                    if(target>contact.capacity) node.flags|=CapHit;
                    if(next<contact.jn) node.flags|=NormalUnwind;
                }
                delta[i]=next-contact.jn; contact.jn=next;
            }
            if constexpr(Observe) if(i<kTraceNodes) {
                auto& node=trace->batches[pass*2+axis].nodes[i];node.jn_after=contact.jn;node.jt_after=contact.jt;node.delta=delta[i];
            }
            ++out.updates;
        }
        for(std::size_t i=0;i<out.nodes;++i) {
            const auto& contact=contacts[i];
            const Vec r=contact.position-b.com,n=contact.normal,d=axis ? Vec{-n.y,n.x}:n;
            v=v+d*(delta[i]/b.mass); w+=cross(r,d)*delta[i]/b.inertia;
        }
        if constexpr(Observe) {
            auto& batch=trace->batches[pass*2+axis];batch.velocity_after=v;batch.omega_after=w;
            batch.normal_cap_hits=out.normal_cap_hits-batch.normal_cap_hits;batch.tangent_cap_hits=out.tangent_cap_hits-batch.tangent_cap_hits;
            ++trace->batch_count;
        }
    }
    for(std::size_t i=0;i<out.nodes;++i) {
        const auto& contact=contacts[i]; const Vec n=contact.normal,t{-n.y,n.x};
        const Vec j=n*contact.jn+t*contact.jt;
        out.impulse=out.impulse+j;
        out.normal_impulse=out.normal_impulse+n*contact.jn;
        out.tangent_impulse=out.tangent_impulse+t*contact.jt;
        out.torque+=cross(contact.position-b.com,j);
        out.normal+=contact.jn; out.tangent+=std::abs(contact.jt);
    }
    out.raw_impulse=out.impulse; out.raw_torque=out.torque;
    out.energy_before=kinetic(b,b.velocity,b.omega);
    out.energy_after=kinetic(b,b.velocity+out.impulse*(1./b.mass),b.omega+out.torque/b.inertia);
    if constexpr(Observe) trace->raw_energy_after=out.energy_after;
    if(!std::isfinite(out.energy_after) || out.energy_after>out.energy_before+1e-6*std::max(1.,out.energy_before)) {
        out.passive_rejected=true; out.scale=0;
        out.impulse={}; out.normal_impulse={}; out.tangent_impulse={};
        out.torque=0; out.normal=0; out.tangent=0; out.energy_after=out.energy_before;
    }
    if constexpr(Observe) {
        trace->result=out;trace->status=trace->dropped_nodes ? TraceStatus::IncompleteNodeCap:TraceStatus::Complete;
    }
    return out;
}

inline Result solve_compound(const Body& b,std::span<const Bin* const> bins,
        CompoundWorkspace& workspace,double available=20,double capacity_scale=1,double base_budget=20,
        NormalPolicy normal_policy=NormalPolicy::Original,SolveTrace* trace=nullptr) {
    if(trace) return solve_compound_impl<true>(b,bins,workspace,available,capacity_scale,base_budget,normal_policy,trace);
    return solve_compound_impl<false>(b,bins,workspace,available,capacity_scale,base_budget,normal_policy,nullptr);
}


// Map a stored cell centre to the nearest actual rectangle face; X wins exact
// corner ties, positive tangent wins half-face ties. Projection keeps the full
// lever arm relative to actual COM, including offset COM bodies.
struct Projection { Vec point{},inward{}; std::uint32_t bin=0; };
inline Projection project(Vec center,Vec half,double rotation,Vec point) {
    const double c=std::cos(rotation),s=std::sin(rotation);
    const Vec d=point-center;
    Vec p{c*d.x+s*d.y,-s*d.x+c*d.y},n;
    std::uint32_t face=0; double tangent=0;
    const double dx=std::abs(p.x)-half.x,dy=std::abs(p.y)-half.y;
    const double vertical_distance2=dx*dx+std::max(dy,0.)*std::max(dy,0.);
    const double horizontal_distance2=dy*dy+std::max(dx,0.)*std::max(dx,0.);
    if(vertical_distance2<=horizontal_distance2) {
        face=p.x>=0?1U:3U; p.x=p.x>=0?half.x:-half.x;
        p.y=std::clamp(p.y,-half.y,half.y); n={p.x>=0?-1.:1.,0}; tangent=p.y;
    } else {
        face=p.y>=0?2U:0U; p.y=p.y>=0?half.y:-half.y;
        p.x=std::clamp(p.x,-half.x,half.x); n={0,p.y>=0?-1.:1.}; tangent=p.x;
    }
    return {center+Vec{c*p.x-s*p.y,s*p.x+c*p.y},
            {c*n.x-s*n.y,s*n.x+c*n.y},face*2U+(tangent>=0?1U:0U)};
}
} // namespace cybersand::gcr
