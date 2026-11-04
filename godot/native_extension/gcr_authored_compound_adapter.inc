// Included inside namespace godot. Authored hulls use the existing compound
// solver but own no detached material payload and cannot impersonate its lease.
namespace {
bool read_authored_compound_identity(const Dictionary& identity,
    std::uint64_t& session,std::uint64_t& generation) {
    if(identity.size()!=3)return false;
    const auto integer=[&](const char* key,std::uint64_t& output) {
        if(!identity.has(key) || Variant(identity[key]).get_type()!=Variant::INT)return false;
        const std::int64_t n=identity[key];
        if(n<1 || n>9'007'199'254'740'991LL)return false;
        output=static_cast<std::uint64_t>(n);return true;
    };
    std::uint64_t version=0;
    return integer("version",version) && version==1 &&
        integer("session_id",session) && integer("body_generation",generation);
}
}

bool CyberNativeCellWorld::prepare_gcr_authored_compound_coupling(
    const PackedFloat64Array& states,const PackedFloat64Array& geometry,
    const Dictionary& identity,bool resolve_overlaps,const Dictionary& rest_context) {
    const auto refuse=[this]() {invalidate_gcr_response();return false;};
    if(!gcr_authored_compound_enabled_ || !gcr_enabled_ || conservative_displacement_ ||
        !world_ || world_->has_failed() || world_->solid_detachment_fenced() ||
        !gcr_compound_workspace_ || gcr_authored_compound_.retired)return refuse();
    if(world_->inspect_solid_detachment().phase!=cybersand::soliding::SolidPhase::Disabled)return refuse();
    std::uint64_t session=0,generation=0;
    if(!read_authored_compound_identity(identity,session,generation))return refuse();
    const auto count=static_cast<std::size_t>(geometry.size()/4);
    if(geometry.size()%4!=0 || count<1 || count>8 ||
        states.size()!=static_cast<std::int64_t>(count*17))return refuse();
    if(gcr_authored_compound_.bound &&
        (session!=gcr_authored_compound_.session || generation!=gcr_authored_compound_.generation ||
         count!=gcr_compound_count_))return refuse();
    if(!gcr_authored_compound_.bound && (gcr_session_id_!=0 || gcr_compound_mode_))return refuse();
    if(!gcr_authored_compound_.bound && session<=gcr_authored_last_session_)return refuse();

    std::array<std::array<double,4>,8> next{};
    double area=0,moment_x=0,moment_y=0;
    double min_x=std::numeric_limits<double>::infinity(),min_y=min_x;
    double max_x=-min_x,max_y=max_x;
    double extent=1.;
    for(std::size_t i=0;i<count;++i) {
        auto& rectangle=next[i];
        for(std::size_t field=0;field<4;++field) {
            const double value=geometry[static_cast<std::int64_t>(i*4+field)];
            if(!std::isfinite(value))return refuse();
            if(gcr_authored_compound_.bound && value!=gcr_authored_compound_.rectangles[i][field])return refuse();
            rectangle[field]=value;
        }
        const auto& r=rectangle;
        if(std::abs(r[0])>128 || std::abs(r[1])>128 || r[2]<1 || r[3]<1 || r[2]>128 || r[3]>128)return refuse();
        const double a=r[2]*r[3];area+=a;moment_x+=a*r[0];moment_y+=a*r[1];
        min_x=std::min(min_x,r[0]-r[2]*.5);max_x=std::max(max_x,r[0]+r[2]*.5);
        min_y=std::min(min_y,r[1]-r[3]*.5);max_y=std::max(max_y,r[1]+r[3]*.5);
        extent=std::max({extent,std::abs(r[0])+r[2]*.5,std::abs(r[1])+r[3]*.5});
    }
    // The authored integer rectangles are nonoverlapping. COM recentering and
    // Rapier's real_t offsets can round a shared edge by one float ULP. Admit
    // only that explicitly bounded ambiguity; raster ownership remains unique.
    const double geometry_tolerance=4.*std::numeric_limits<real_t>::epsilon()*extent;
    if(max_x-min_x>128.+geometry_tolerance || max_y-min_y>128.+geometry_tolerance ||
        std::abs(moment_x/area)>geometry_tolerance || std::abs(moment_y/area)>geometry_tolerance)return refuse();
    for(std::size_t i=0;i<count;++i)for(std::size_t j=i+1;j<count;++j) {
        const auto& a=next[i];const auto& b=next[j];
        const double overlap_x=std::min(a[0]+a[2]*.5,b[0]+b[2]*.5)-std::max(a[0]-a[2]*.5,b[0]-b[2]*.5);
        const double overlap_y=std::min(a[1]+a[3]*.5,b[1]+b[3]*.5)-std::max(a[1]-a[3]*.5,b[1]-b[3]*.5);
        if(overlap_x>geometry_tolerance && overlap_y>geometry_tolerance)return refuse();
    }

    std::array<bool,9> seen{};
    for(std::int64_t offset=0;offset<states.size();offset+=17) {
        for(std::int64_t field=0;field<17;++field)if(!std::isfinite(states[offset+field]))return refuse();
        const double id=states[offset],serial=states[offset+10];
        if(id<1 || id>static_cast<double>(count) || std::trunc(id)!=id ||
            std::abs(states[offset+3])>static_cast<double>(std::numeric_limits<real_t>::max()) ||
            serial<0 || serial>=1'000'000 || std::trunc(serial)!=serial ||
            states[offset+16]!=static_cast<double>(session) ||
            states[offset+9]<1e-9 || states[offset+9]>1e12 ||
            states[offset+11]<1e-9 || states[offset+11]>1e12 ||
            states[offset+14]<0 || states[offset+14]>16 ||
            states[offset+15]<=0 || states[offset+15]>.1)return refuse();
        const auto index=static_cast<std::size_t>(id);if(seen[index])return refuse();seen[index]=true;
        for(const int field:{1,2,6,7,8,12,13})if(std::abs(states[offset+field])>1e6)return refuse();
        for(const int field:{3,6,7,8,9,10,11,12,13,14,15,16})if(states[offset+field]!=states[field])return refuse();
        if(gcr_session_id_!=0 && gcr_session_id_!=static_cast<double>(session))return refuse();
        const auto last=gcr_last_serials_[index];
        if(last>=0) {
            const auto advance=(static_cast<std::int32_t>(serial)-last+1'000'000)%1'000'000;
            if(advance==0 || advance>=500'000)return refuse();
        }
        if(gcr_authored_compound_.bound &&
            (states[offset+9]!=gcr_authored_compound_.mass || states[offset+11]!=gcr_authored_compound_.inertia ||
             states[offset+14]!=gcr_authored_compound_.friction))return refuse();
        const auto& shape=next[index-1];
        if(states[offset+4]!=shape[2] || states[offset+5]!=shape[3])return refuse();
        const Vector2 com{static_cast<real_t>(states[12]),static_cast<real_t>(states[13])};
        const Vector2 local{static_cast<real_t>(shape[0]),static_cast<real_t>(shape[1])};
        const Vector2 expected=com+local.rotated(static_cast<real_t>(states[3]));
        const double scale=std::max({1.,std::abs(states[12]),std::abs(states[13]),extent});
        const double tolerance=4.*std::numeric_limits<real_t>::epsilon()*scale;
        if(!expected.is_finite() || std::abs(states[offset+1]-expected.x)>tolerance ||
            std::abs(states[offset+2]-expected.y)>tolerance)return refuse();
    }
    RestContext context;
    if(!validate_rest_context(rest_context,states,context))return refuse();
    // All authoring/physical/identity checks precede occupancy and cell work.
    try {
        gcr_authored_compound_.bound=true;
        gcr_authored_last_session_=session;
        gcr_authored_compound_.session=session;gcr_authored_compound_.generation=generation;
        gcr_authored_compound_.rectangles=next;
        gcr_authored_compound_.mass=states[9];gcr_authored_compound_.inertia=states[11];
        gcr_authored_compound_.friction=states[14];
        gcr_compound_mode_=true;gcr_compound_count_=count;gcr_preparing_compound_=true;
        struct FlagGuard {bool& flag;~FlagGuard(){flag=false;}} guard{gcr_preparing_compound_};
        const bool accepted=prepare_gcr_coupling(states,resolve_overlaps,rest_context);
        return accepted && compound_lease_current();
    } catch(...) {
        world_->quarantine_external_coupling();invalidate_gcr_response();++tick_failure_count_;
        return false;
    }
}

bool CyberNativeCellWorld::retire_gcr_authored_compound(const Dictionary& identity) {
    std::uint64_t session=0,generation=0;
    if(!gcr_authored_compound_enabled_ || !gcr_authored_compound_.bound ||
        gcr_authored_compound_.retired || !read_authored_compound_identity(identity,session,generation) ||
        session!=gcr_authored_compound_.session || generation!=gcr_authored_compound_.generation ||
        !world_ || world_->has_failed() || world_->solid_detachment_fenced())return false;
    try {
        world_->clear_transient_obstacles();invalidate_gcr_response();
        current_bodies_={};previous_bodies_={};gcr_last_serials_.fill(-1);gcr_session_id_=0;
        gcr_compound_mode_=gcr_preparing_compound_=false;gcr_compound_count_=0;
        gcr_authored_compound_.retired=true;
        return true;
    } catch(...) {
        world_->quarantine_external_coupling();invalidate_gcr_response();++tick_failure_count_;
        return false;
    }
}
