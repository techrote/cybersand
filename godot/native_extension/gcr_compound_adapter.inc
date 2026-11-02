// Included inside namespace godot. One active native aggregate, many geometric
// masks, one physical COM state and one R2 response budget. No backend calls.
bool CyberNativeCellWorld::compound_lease_current() const {
    if (!world_ || world_->has_failed() || world_->solid_detachment_fenced()) return false;
    const auto s=world_->inspect_solid_detachment();
    return s.phase==cybersand::soliding::SolidPhase::Active && s.body_id==1 &&
        s.token==gcr_compound_token_ && s.body_generation==gcr_compound_generation_ &&
        s.physics_epoch==gcr_compound_physics_epoch_ && s.shape_count==gcr_compound_count_;
}

bool CyberNativeCellWorld::prepare_gcr_compound_coupling(const PackedFloat64Array& states,
    const Dictionary& lease, bool resolve_overlaps) {
    if (!gcr_enabled_ || !conservative_displacement_ || !world_ || world_->has_failed() ||
        world_->solid_detachment_fenced() || !gcr_compound_workspace_) return false;
    const auto refuse=[this]() { invalidate_gcr_response(); return false; };
    const auto solid=world_->inspect_solid_detachment();
    if (solid.phase!=cybersand::soliding::SolidPhase::Active || solid.body_id!=1 ||
        solid.shape_count<1 || solid.shape_count>cybersand::World::kMaximumTransientBodies) return refuse();
    const String token=String(std::to_string(solid.token.incarnation).c_str())+":"+
        String(std::to_string(solid.token.sequence).c_str());
    const auto integer=[&](const char* name,std::uint64_t expected) {
        return lease.has(name) && Variant(lease[name]).get_type()==Variant::INT &&
            static_cast<std::int64_t>(lease[name])>0 &&
            static_cast<std::uint64_t>(static_cast<std::int64_t>(lease[name]))==expected;
    };
    if (!lease.has("token") || Variant(lease["token"]).get_type()!=Variant::STRING ||
        String(lease["token"])!=token || !integer("body_id",1) ||
        !integer("body_generation",solid.body_generation) || !integer("physics_epoch",solid.physics_epoch)) return refuse();
    if (gcr_compound_mode_ && (gcr_compound_token_!=solid.token ||
        gcr_compound_generation_!=solid.body_generation || gcr_compound_physics_epoch_!=solid.physics_epoch)) return refuse();
    if (states.is_empty()) return refuse();
    if (states.size()!=static_cast<std::int64_t>(solid.shape_count*17)) return refuse();
    std::array<cybersand::soliding::SolidShape,cybersand::soliding::kSolidShapes> shapes{};
    if (world_->copy_solid_detachment_shapes(shapes)!=solid.shape_count) return refuse();
    std::array<bool,cybersand::World::kMaximumTransientBodies+1U> seen{};
    for(std::int64_t offset=0;offset<states.size();offset+=17) {
        for(int field=0;field<17;++field) if(!std::isfinite(states[offset+field])) return refuse();
        if(std::abs(states[offset+3])>static_cast<double>(std::numeric_limits<real_t>::max())) return refuse();
        const double identity=states[offset];
        if(identity<1 || identity>static_cast<double>(solid.shape_count) || std::trunc(identity)!=identity) return refuse();
        const auto id=static_cast<std::size_t>(identity);if(seen[id]) return refuse();seen[id]=true;
        const double serial=states[offset+10],session=states[offset+16];
        if(serial<0 || serial>=1'000'000 || std::trunc(serial)!=serial || session<1 ||
            session>9'007'199'254'740'991. || std::trunc(session)!=session ||
            (gcr_session_id_!=0 && session!=gcr_session_id_) || states[offset+4]<1 || states[offset+5]<1 ||
            states[offset+4]>128 || states[offset+5]>128 || states[offset+9]<1e-9 || states[offset+9]>1e12 ||
            states[offset+11]<1e-9 || states[offset+11]>1e12 || states[offset+14]<0 || states[offset+14]>16 ||
            states[offset+15]<=0 || states[offset+15]>.1) return refuse();
        for(const int field:{1,2,6,7,8,12,13}) if(std::abs(states[offset+field])>1e6) return refuse();
        if(gcr_last_serials_[id]>=0) {
            const auto advance=(static_cast<std::int32_t>(serial)-gcr_last_serials_[id]+1'000'000)%1'000'000;
            if(advance==0 || advance>=500'000) return refuse();
        }
        // One actual COM state is repeated. Proxy point velocity or area-mass
        // records are not a valid representation of this physical owner.
        for(const int field:{3,6,7,8,9,10,11,12,13,14,15,16})
            if(states[offset+field]!=states[field]) return refuse();
        if(states[offset+9]!=solid.mass ||
            (states[offset+11]!=solid.inertia && states[offset+11]!=static_cast<double>(static_cast<real_t>(solid.inertia)))) return refuse();
        const auto& shape=shapes[id-1];
        if(states[offset+4]!=shape.width || states[offset+5]!=shape.height) return refuse();
        const Vector2 initial_com{static_cast<real_t>(static_cast<double>(solid.domain.x)+solid.com_x),
                                  static_cast<real_t>(static_cast<double>(solid.domain.y)+solid.com_y)};
        const Vector2 center{static_cast<real_t>(static_cast<double>(shape.x)+shape.width*.5),
                              static_cast<real_t>(static_cast<double>(shape.y)+shape.height*.5)};
        const Vector2 local=center-initial_com;
        const Vector2 com{static_cast<real_t>(states[12]),static_cast<real_t>(states[13])};
        const Vector2 expected=com+local.rotated(static_cast<real_t>(states[3]));
        const double scale=std::max({1.,std::abs(states[12]),std::abs(states[13]),
            std::abs(static_cast<double>(local.x))+shape.width*.5,
            std::abs(static_cast<double>(local.y))+shape.height*.5});
        const double tolerance=4.*std::numeric_limits<real_t>::epsilon()*scale;
        if(!expected.is_finite() || !std::isfinite(tolerance)) return refuse();
        if(std::abs(states[offset+1]-expected.x)>tolerance || std::abs(states[offset+2]-expected.y)>tolerance) return refuse();
    }
    // All lease/shape/physical checks precede masks, serials and material work.
    gcr_response_valid_=false;
    try {
        gcr_compound_mode_=true;gcr_compound_count_=solid.shape_count;
        gcr_compound_token_=solid.token;gcr_compound_generation_=solid.body_generation;
        gcr_compound_physics_epoch_=solid.physics_epoch;gcr_preparing_compound_=true;
        struct FlagGuard {bool& flag;~FlagGuard(){flag=false;}} guard{gcr_preparing_compound_};
        const bool accepted=prepare_gcr_coupling(states,resolve_overlaps);
        return accepted && compound_lease_current();
    } catch (...) {
        world_->quarantine_external_coupling();
        invalidate_gcr_response(); ++tick_failure_count_;
        return false;
    }
}

CyberNativeCellWorld::CompoundEvaluation CyberNativeCellWorld::evaluate_gcr_compound() const {
    CompoundEvaluation out;auto& response=out.response;
    if(!compound_lease_current() || !gcr_compound_workspace_ || !current_bodies_[1].valid) {response.refused=true;return out;}
    const auto& body=current_bodies_[1];
    std::array<const cybersand::gcr::Bin*,cybersand::gcr::kCompoundBins> bins{};
    std::size_t count=0;
    std::int64_t gx=0,gy=0,moment2=0;
    const auto add=[](std::int64_t& total,std::int64_t value) {
        if((value>0 && total>std::numeric_limits<std::int64_t>::max()-value) ||
            (value<0 && total<std::numeric_limits<std::int64_t>::min()-value)) return false;
        total+=value;return true;
    };
    const double gain=contact_gain_/1000.;
    cybersand::gcr::Vec raw_legacy{};double legacy_moment=0,total_area=0;
    for(std::size_t id=1;id<=gcr_compound_count_;++id) {
        const auto native_id=static_cast<std::uint16_t>(id);const auto& proxy=current_bodies_[id];
        if(!proxy.valid || world_->transient_granular_wrench_refused(native_id)) {response.refused=true;return out;}
        const auto px=world_->transient_granular_impulse_x(native_id),py=world_->transient_granular_impulse_y(native_id);
        if(!add(gx,px) || !add(gy,py) || !add(moment2,world_->transient_granular_moment2(native_id))) {response.refused=true;return out;}
        for(const auto& bin:gcr_bins_[id]) bins[count++]=&bin;
        const auto& observation=observations_[id];
        const cybersand::gcr::Vec legacy{
            observation.impulse.x+(static_cast<double>(world_->transient_contact_impulse_x(native_id))-static_cast<double>(px))*gain,
            observation.impulse.y+(static_cast<double>(world_->transient_contact_impulse_y(native_id))-static_cast<double>(py))*gain};
        raw_legacy=raw_legacy+legacy;out.legacy_budget+=cybersand::gcr::length(legacy);
        const auto r=proxy.center-body.com;legacy_moment+=static_cast<double>(r.x)*legacy.y-static_cast<double>(r.y)*legacy.x;
        const double area=4.*proxy.half_size.x*proxy.half_size.y;
        out.precise_correction=out.precise_correction+cybersand::gcr::Vec{observation.correction.x*area,observation.correction.y*area};total_area+=area;
        out.contacts+=observation.contacts+world_->transient_contact_count(native_id);
        out.displaced+=observation.displaced;out.unresolved+=observation.unresolved;
        // Exact current rectangle-corner bound around the one physical COM.
        const double c=std::cos(proxy.rotation),s=std::sin(proxy.rotation);
        for(const double x:{-static_cast<double>(proxy.half_size.x),static_cast<double>(proxy.half_size.x)})
        for(const double y:{-static_cast<double>(proxy.half_size.y),static_cast<double>(proxy.half_size.y)}) {
            out.radius=std::max(out.radius,cybersand::gcr::length({proxy.center.x+c*x-s*y-body.com.x,
                proxy.center.y+s*x+c*y-body.com.y}));
        }
    }
    out.radius+=2.;
    const cybersand::gcr::Vec event_raw{static_cast<double>(gx)*gain,static_cast<double>(gy)*gain};
    response.event_raw={event_raw.x,event_raw.y};
    response.event_raw_torque=(static_cast<double>(moment2)*.5-body.com.x*static_cast<double>(gy)+body.com.y*static_cast<double>(gx))*gain;
    const double event_cost=std::max(cybersand::gcr::length(event_raw),std::abs(response.event_raw_torque)/out.radius);
    response.event_scale=event_cost>20 ? 20/event_cost:1.;
    const auto event=event_raw*response.event_scale;
    response.event={event.x,event.y};
    response.event_torque=response.event_raw_torque*response.event_scale;response.event_cost=event_cost*response.event_scale;
    cybersand::gcr::Body state;
    state.velocity={body.velocity.x+event.x/body.mass,body.velocity.y+event.y/body.mass};
    state.omega=body.angular_velocity+response.event_torque/body.inertia;state.mass=body.mass;state.inertia=body.inertia;
    state.com={body.com.x,body.com.y};state.mu=body.friction;
    response.passive=cybersand::gcr::solve_compound(state,{bins.data(),count},*gcr_compound_workspace_,20-response.event_cost);
    out.legacy_scale=out.legacy_budget>impulse_cap_ ? impulse_cap_/out.legacy_budget:1.;
    const auto legacy=raw_legacy*out.legacy_scale;
    response.legacy={legacy.x,legacy.y};out.legacy_raw_torque=legacy_moment;out.legacy_torque=legacy_moment*out.legacy_scale;
    out.precise_impulse=legacy+event+response.passive.impulse;
    response.impulse={out.precise_impulse.x,out.precise_impulse.y};
    response.torque=out.legacy_torque+response.event_torque+response.passive.torque;
    if(total_area>0) out.precise_correction=out.precise_correction*(1./total_area);
    const double correction_length=cybersand::gcr::length(out.precise_correction);
    if(correction_length>.5) out.precise_correction=out.precise_correction*(.5/correction_length);
    out.correction={out.precise_correction.x,out.precise_correction.y};
    if(!std::isfinite(out.precise_impulse.x) || !std::isfinite(out.precise_impulse.y) ||
        !std::isfinite(response.torque) || !std::isfinite(out.precise_correction.x) || !std::isfinite(out.precise_correction.y)) response.refused=true;
    return out;
}

PackedFloat64Array CyberNativeCellWorld::gcr_compound_results() const {
    PackedFloat64Array result;
    if(!gcr_compound_mode_ || !gcr_response_valid_ || !compound_lease_current() ||
        world_->completed_tick_index()>gcr_sample_tick_+1 || !current_bodies_[1].valid) return result;
    if(!gcr_compound_last_valid_ || gcr_compound_last_tick_!=world_->completed_tick_index()) {
        gcr_compound_last_=evaluate_gcr_compound();gcr_compound_last_valid_=true;
        gcr_compound_last_tick_=world_->completed_tick_index();
    }
    const auto& e=gcr_compound_last_;if(e.response.refused) return result;
    const auto& b=current_bodies_[1];
    for(const double value:{1.,e.precise_impulse.x,e.precise_impulse.y,
        e.precise_correction.x,e.precise_correction.y,static_cast<double>(e.contacts),
        static_cast<double>(e.displaced),static_cast<double>(e.unresolved),static_cast<double>(b.sample_serial),
        e.response.torque,static_cast<double>(b.com.x),static_cast<double>(b.com.y),2.,gcr_session_id_}) result.append(value);
    return result;
}

Dictionary CyberNativeCellWorld::gcr_compound_diagnostics() const {
    Dictionary d;d["enabled"]=gcr_compound_mode_;d["protocol_version"]=2;d["physical_body_id"]=1;
    d["admission_variant"]=get_gcr_admission_variant();d["proxy_count"]=static_cast<std::int64_t>(gcr_compound_count_);
    d["source_bins"]=static_cast<std::int64_t>(gcr_compound_count_*8);
    d["scratch_bytes"]=static_cast<std::int64_t>(sizeof(cybersand::gcr::CompoundWorkspace));
    d["response_valid"]=gcr_response_valid_ && compound_lease_current();
    d["computed"]=gcr_compound_last_valid_;d["sample_native_tick"]=static_cast<std::int64_t>(gcr_sample_tick_);
    const bool overlap_valid=gcr_compound_overlap_measured_ && gcr_response_valid_ && compound_lease_current();
    d["overlap_measured"]=overlap_valid;
    d["cellular_overlap_pre"]=overlap_valid ? Variant(static_cast<std::int64_t>(gcr_compound_overlap_pre_)):Variant();
    d["cellular_overlap_post"]=overlap_valid ? Variant(static_cast<std::int64_t>(gcr_compound_overlap_post_)):Variant();
    d["overlap_geometry_tests"]=static_cast<std::int64_t>(gcr_compound_overlap_geometry_tests_);
    d["overlap_scope"]="movable non-hard cell centers in current rectangle union; pre-ejection and post-ejection";
    if(!gcr_compound_mode_ || !current_bodies_[1].valid) return d;
    const auto& b=current_bodies_[1];d["mass"]=b.mass;d["inertia"]=b.inertia;d["sample_com"]=b.com;
    d["sample_serial"]=b.sample_serial;d["session_id"]=gcr_session_id_;
    if(!gcr_compound_last_valid_) return d;
    const auto& e=gcr_compound_last_;const auto& r=e.response;const auto& p=r.passive;
    d["nodes"]=p.nodes;d["updates"]=p.updates;d["normal_capacity"]=p.capacity;d["normal_accepted"]=p.normal;
    d["tangent_accepted"]=p.tangent;d["event_budget_cost"]=r.event_cost;d["event_scale"]=r.event_scale;
    d["event_raw"]=r.event_raw;d["event_accepted"]=r.event;d["event_raw_torque"]=r.event_raw_torque;d["event_torque"]=r.event_torque;
    d["passive_impulse"]=Vector2{p.impulse.x,p.impulse.y};d["passive_torque"]=p.torque;
    d["legacy_impulse"]=r.legacy;d["legacy_raw_torque"]=e.legacy_raw_torque;d["legacy_torque"]=e.legacy_torque;
    d["legacy_scale"]=e.legacy_scale;d["legacy_budget"]=e.legacy_budget;d["radius"]=e.radius;
    d["impulse"]=r.impulse;d["impulse_x"]=e.precise_impulse.x;d["impulse_y"]=e.precise_impulse.y;
    d["torque"]=r.torque;d["correction"]=e.correction;
    d["correction_x"]=e.precise_correction.x;d["correction_y"]=e.precise_correction.y;
    d["energy_before"]=p.energy_before;d["energy_after"]=p.energy_after;d["passivity_rejected"]=p.passive_rejected;
    d["refused"]=r.refused;d["contacts"]=static_cast<std::int64_t>(e.contacts);
    d["displaced"]=static_cast<std::int64_t>(e.displaced);d["unresolved"]=static_cast<std::int64_t>(e.unresolved);
    return d;
}
