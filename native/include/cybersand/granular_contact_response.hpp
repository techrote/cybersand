#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

namespace cybersand::gcr {

// GCR-001 v1: all quantities are copied values in the adapter's cell units.
// No World/backend ownership, dynamic allocation or persistent support state.
struct Vec {
    double x = 0, y = 0;
    Vec operator+(Vec b) const { return {x+b.x,y+b.y}; }
    Vec operator-(Vec b) const { return {x-b.x,y-b.y}; }
    Vec operator*(double s) const { return {x*s,y*s}; }
};
inline double dot(Vec a, Vec b) { return a.x*b.x+a.y*b.y; }
inline double cross(Vec a, Vec b) { return a.x*b.y-a.y*b.x; }
inline double length(Vec a) { return std::hypot(a.x,a.y); }
struct Bin {
    std::uint32_t count = 0;
    std::uint64_t material_mask = 0;
    std::uint8_t state_b_min = 255, state_b_max = 0;
    Vec position_sum{}, normal{};
    double maximum_radius = 0;
    void add(Vec point, Vec inward, Vec com) {
        ++count; position_sum=position_sum+point; normal=inward;
        maximum_radius=std::max(maximum_radius,length(point-com));
    }
};
struct Body { Vec velocity{}, com{}; double omega=0,mass=1,inertia=1,mu=0; };
struct Result {
    Vec impulse{}, normal_impulse{}, tangent_impulse{}, raw_impulse{};
    double torque=0, raw_torque=0, normal=0, tangent=0, raw_normal=0, raw_tangent=0;
    double capacity=0, energy_before=0, energy_after=0, scale=1, max_radius=0;
    std::uint32_t bins=0, updates=0, normal_cap_hits=0, tangent_cap_hits=0;
    bool passive_rejected=false;
};
inline double kinetic(const Body& b, Vec v, double w) {
    return .5*b.mass*dot(v,v)+.5*b.inertia*w*w;
}
// Four deterministic projected Jacobi passes. Accumulated contact loads
// may be released; the sum of current nonnegative loads owns the one budget.
inline Result solve(const Body& b, const std::array<Bin,8>& bins,
                    double available=20) {
    Result out;
    std::array<double,8> jn{},jt{},caps{};
    std::uint64_t samples=0;
    for(const auto& bin:bins) samples+=bin.count;
    out.capacity=std::min(std::clamp(available,0.,20.),2.*static_cast<double>(samples));
    for(std::size_t i=0;i<8;++i) {
        caps[i]=samples ? out.capacity*static_cast<double>(bins[i].count)/static_cast<double>(samples):0;
        if(bins[i].count) ++out.bins;
        out.max_radius=std::max(out.max_radius,bins[i].maximum_radius);
    }
    Vec v=b.velocity; double w=b.omega;
    for(unsigned pass=0;pass<4;++pass) for(unsigned axis=0;axis<2;++axis) {
        // Evaluate every bin from one provisional state before applying the
        // phase. Sample-count weights preserve the unreduced quadrature weight
        // and mirrors without traversal-order torque on flat support.
        std::array<double,8> delta{};
        for(std::size_t i=0;i<8;++i) {
            const auto& bin=bins[i]; if(!bin.count) continue;
            const double relaxation=static_cast<double>(bin.count)/static_cast<double>(samples);
            const Vec r=bin.position_sum*(1./bin.count)-b.com;
            const Vec n=bin.normal,d=axis ? Vec{-n.y,n.x} : n;
            const double arm=cross(r,d);
            const double speed=dot(v+Vec{-w*r.y,w*r.x},d);
            const double requested=-speed/(1./b.mass+arm*arm/b.inertia);
            if(axis) {
                out.raw_tangent+=std::abs(requested);
                const double target=jt[i]+requested*relaxation;
                if (std::abs(target)>b.mu*jn[i]) ++out.tangent_cap_hits;
                const double next=std::clamp(target,-b.mu*jn[i],b.mu*jn[i]);
                delta[i]=next-jt[i]; jt[i]=next;
            } else {
                out.raw_normal+=std::max(0.,requested);
                const double target=jn[i]+requested*relaxation;
                if (target>caps[i]) ++out.normal_cap_hits;
                const double next=std::clamp(target,0.,caps[i]);
                delta[i]=next-jn[i]; jn[i]=next;
            }
            ++out.updates;
        }
        for(std::size_t i=0;i<8;++i) if(bins[i].count) {
            const Vec r=bins[i].position_sum*(1./bins[i].count)-b.com;
            const Vec n=bins[i].normal,d=axis ? Vec{-n.y,n.x} : n;
            v=v+d*(delta[i]/b.mass); w+=cross(r,d)*delta[i]/b.inertia;
        }
    }
    for(std::size_t i=0;i<8;++i) if(bins[i].count) {
        const Vec n=bins[i].normal,t{-n.y,n.x};
        const Vec j=n*jn[i]+t*jt[i];
        out.impulse=out.impulse+j;
        out.normal_impulse=out.normal_impulse+n*jn[i];
        out.tangent_impulse=out.tangent_impulse+t*jt[i];
        out.torque+=cross(bins[i].position_sum*(1./bins[i].count)-b.com,j);
        out.normal+=jn[i]; out.tangent+=std::abs(jt[i]);
    }
    out.raw_impulse=out.impulse; out.raw_torque=out.torque;
    out.energy_before=kinetic(b,b.velocity,b.omega);
    out.energy_after=kinetic(b,b.velocity+out.impulse*(1./b.mass),b.omega+out.torque/b.inertia);
    // A cone projection can redistribute a previous pass. Independently refuse
    // the whole passive wrench if it injects energy beyond the registered bound.
    if(!std::isfinite(out.energy_after) || out.energy_after>out.energy_before+1e-6*std::max(1.,out.energy_before)) {
        out.passive_rejected=true; out.scale=0;
        out.impulse={}; out.normal_impulse={}; out.tangent_impulse={};
        out.torque=0; out.normal=0; out.tangent=0; out.energy_after=out.energy_before;
    }
    return out;
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
