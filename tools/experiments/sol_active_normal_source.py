#!/usr/bin/env python3
"""Mechanical source adapters; never edit the production header."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
HEADER='native/include/cybersand/granular_contact_response.hpp'
PIN='32877bbd6fc7eb85feabab5452250f4a318388cd7b5e7a64b93576123c7caedb'

def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new)

TRACE=r'''
inline constexpr std::size_t kTraceContacts=32;
struct BatchTrace {
    Vec before{},after{};
    double omega_before=0,omega_after=0,energy_before=0,energy_after=0,active_weight=0;
    std::uint32_t pass=0,axis=0,nodes=0,snapshots=0,active_count=0;
    std::uint32_t normal_unwinds=0,tangent_unwinds=0,shrunk_cones=0,normal_caps=0,tangent_caps=0;
    std::array<double,kTraceContacts> jn_before{},jn_after{},jt_before{},jt_after{},weight_used{};
    std::array<bool,kTraceContacts> active{};
};
'''

BEFORE=r'''
        auto& trace=workspace.trace[workspace.trace_batches++];trace={};
        trace.pass=pass;trace.axis=axis;trace.before=v;trace.omega_before=w;
        trace.energy_before=kinetic(b,v,w);trace.nodes=out.nodes;
        trace.snapshots=std::min(out.nodes,static_cast<std::uint32_t>(kTraceContacts));
        trace.normal_caps=out.normal_cap_hits;trace.tangent_caps=out.tangent_cap_hits;
        if(!axis) for(std::size_t i=0;i<out.nodes;++i) {
            const auto& node=contacts[i];const Vec r=node.position-b.com;
            const double speed=dot(v+Vec{-w*r.y,w*r.x},node.normal);
            workspace.active[i]=speed<0 || node.jn>0;
            if(workspace.active[i]) {trace.active_weight+=node.weight;++trace.active_count;}
        }
        for(std::size_t i=0;i<trace.snapshots;++i) {
            trace.jn_before[i]=contacts[i].jn;trace.jt_before[i]=contacts[i].jt;
            trace.active[i]=!axis && workspace.active[i];
            trace.weight_used[i]=__TRACE_WEIGHT__;
        }
'''

AFTER=r'''
        trace.after=v;trace.omega_after=w;trace.energy_after=kinetic(b,v,w);
        trace.normal_caps=out.normal_cap_hits-trace.normal_caps;
        trace.tangent_caps=out.tangent_cap_hits-trace.tangent_caps;
        for(std::size_t i=0;i<trace.snapshots;++i) {
            trace.jn_after[i]=contacts[i].jn;trace.jt_after[i]=contacts[i].jt;
        }
'''

def generate(candidate):
    raw=(ROOT/HEADER).read_bytes().replace(b'\r\n',b'\n')
    assert hashlib.sha256(raw).hexdigest()==PIN
    text=raw.decode();namespace='gcr_active_normal' if candidate else 'gcr_trace'
    text=once(text,'namespace cybersand::gcr {','namespace cybersand::'+namespace+' {')
    text=once(text,'struct CompoundWorkspace {',TRACE+'\nstruct CompoundWorkspace {')
    text=once(text,'    std::array<double,kCompoundNodes> delta{};',
        '    std::array<double,kCompoundNodes> delta{};\n    std::array<bool,kCompoundNodes> active{};\n    std::array<BatchTrace,8> trace{};\n    std::uint32_t trace_batches=0;')
    text=once(text,'    Result out;','    Result out;workspace.trace_batches=0;')
    beta='(trace.active_count==out.nodes ? contacts[i].weight : (workspace.active[i] && trace.active_weight>0 ? contacts[i].weight/trace.active_weight:0.))'
    trace_weight='(axis ? contacts[i].weight:'+beta+')' if candidate else 'contacts[i].weight'
    text=once(text,'        auto& delta=workspace.delta;','        auto& delta=workspace.delta;'+BEFORE.replace('__TRACE_WEIGHT__',trace_weight))
    text=once(text,'                delta[i]=next-contact.jn; contact.jn=next;',
        '                if(next<contact.jn) ++trace.normal_unwinds;\n                delta[i]=next-contact.jn; contact.jn=next;')
    text=once(text,'                delta[i]=next-contact.jt; contact.jt=next;',
        '                if(std::abs(contact.jt)>b.mu*contact.jn) ++trace.shrunk_cones;\n                if(std::abs(next)<std::abs(contact.jt)) ++trace.tangent_unwinds;\n                delta[i]=next-contact.jt; contact.jt=next;')
    anchor='            v=v+d*(delta[i]/b.mass); w+=cross(r,d)*delta[i]/b.inertia;\n        }\n    }'
    text=once(text,anchor,'            v=v+d*(delta[i]/b.mass); w+=cross(r,d)*delta[i]/b.inertia;\n        }'+AFTER+'    }')
    if candidate:
        text=once(text,'                const double target=contact.jn+requested*contact.weight;',
            '                const double normal_weight='+beta.replace('contacts[i].weight','contact.weight')+';\n                const double target=contact.jn+requested*normal_weight;')
    return text.encode()

def driver():
    original='native/tests/sol_passive_values.cpp'
    raw=(ROOT/original).read_bytes().replace(b'\r\n',b'\n')
    receipt=json.loads((ROOT/'docs/audits/sol-chamber-20261105/passive-values.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(raw).hexdigest()==receipt['input_sha256'][original]
    text=raw.decode();assert text.count('int main(')==1
    prefix=text.split('int main(',1)[0]
    includes='''#if SOL_ACTIVE_ARM == 0
#include "cybersand/granular_contact_response.hpp"
#elif SOL_ACTIVE_ARM == 1
#include "gcr_trace.hpp"
#else
#include "gcr_active_normal.hpp"
#endif'''
    aliases='''#if SOL_ACTIVE_ARM == 0
namespace g = cybersand::gcr;
#elif SOL_ACTIVE_ARM == 1
namespace g = cybersand::gcr_trace;
#else
namespace g = cybersand::gcr_active_normal;
#endif'''
    prefix=once(prefix,'#include "cybersand/granular_contact_response.hpp"',includes)
    prefix=once(prefix,'namespace g = cybersand::gcr;',aliases)
    return prefix.encode()+(ROOT/'native/tests/sol_active_normal_driver.inc').read_bytes().replace(b'\r\n',b'\n')
