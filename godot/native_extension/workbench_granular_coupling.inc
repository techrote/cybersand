namespace {
Vector2 sampled_vec(double x, double y) {
    return {static_cast<real_t>(x),static_cast<real_t>(y)};
}
bool add_checked(std::int64_t& total, std::int64_t value) {
    if ((value > 0 && total > std::numeric_limits<std::int64_t>::max()-value) ||
        (value < 0 && total < std::numeric_limits<std::int64_t>::min()-value)) return false;
    total += value;
    return true;
}
}
// Included in CyberNativeCellWorld's namespace. One immutable physical roster per
// prepared World. Shape slots only own occupancy and contact bins, never an application.
bool CyberNativeCellWorld::parse_workbench_sample(WorkbenchSample& next, const Workbench& retained,
        const PackedFloat64Array& states, const PackedFloat64Array& geometry, const Array& owners,
        std::int64_t session, std::int64_t epoch) {
    constexpr std::int64_t exact_integer_limit = 9'007'199'254'740'991LL;
    const auto proxy_count = states.size() / 17;
    if (session < 1 || session > exact_integer_limit || epoch < 1 || epoch > exact_integer_limit ||
        states.size() % 17 || proxy_count > cybersand::World::kMaximumTransientBodies ||
        geometry.size() != 4 * proxy_count || owners.size() > static_cast<int>(kWorkbenchBodies)) return false;
    const auto& old = retained.sample;
    if (old.session && (session != old.session || epoch != old.epoch)) return false;
    next.session = session;
    next.epoch = epoch;
    const auto integer = [](const Dictionary& row, const char* key) -> std::int64_t {
        const Variant value = row.get(key,Variant());
        return value.get_type() == Variant::INT ? static_cast<std::int64_t>(value) : -1;
    };
    const auto number = [](const Dictionary& row, const char* key) {
        const Variant value = row.get(key,Variant());
        return value.get_type() == Variant::FLOAT || value.get_type() == Variant::INT
            ? static_cast<double>(value) : std::numeric_limits<double>::quiet_NaN();
    };
    for (int i = 0; i < owners.size(); ++i) {
        if (owners[i].get_type() != Variant::DICTIONARY) return false;
        const Dictionary row = owners[i];
        const auto id = integer(row,"id"), first = integer(row,"first_proxy"), count = integer(row,"count");
        const auto instance = integer(row,"instance_id"), generation = integer(row,"generation");
        const double budget = number(row,"budget"), gravity = number(row,"gravity");
        if (id < 1 || id > static_cast<int>(kWorkbenchBodies) || next.owners[id].instance ||
            instance < 1 || generation < 1 || first < 1 || count < 1 || count > 8 ||
            first > proxy_count - count + 1 || !std::isfinite(budget) || budget < 5 || budget > 80 ||
            (retained.response == "RFT" && budget != 20) || !std::isfinite(gravity) || gravity < 0 ||
            row.get("external_drive",Variant()).get_type() != Variant::BOOL) return false;
        for (const auto& owner : next.owners) if (owner.instance == instance) return false;
        next.owners[id] = {instance,generation,static_cast<int>(first),static_cast<int>(count),budget,gravity,row["external_drive"]};
        const auto& previous = old.owners[id];
        if (old.session && (previous.instance != instance || previous.generation != generation ||
            previous.first != first || previous.count != count || previous.budget != budget)) return false;
        for (auto proxy = first; proxy < first + count; ++proxy) {
            if (next.owner_of[proxy]) return false;
            next.owner_of[proxy] = static_cast<std::uint16_t>(id);
        }
    }
    for (std::size_t id = 1; id < old.owners.size(); ++id)
        if (old.session && old.owners[id].instance != next.owners[id].instance) return false;
    for (std::int64_t offset = 0; offset < states.size(); offset += 17) {
        const auto* v = states.ptr() + offset;
        for (int k = 0; k < 17; ++k) if (!std::isfinite(v[k])) return false;
        if (v[0] < 1 || v[0] > proxy_count || std::trunc(v[0]) != v[0] || v[16] != session ||
            v[10] < 0 || v[10] >= 1'000'000 || std::trunc(v[10]) != v[10] ||
            v[9] < 1e-9 || v[9] > 1e12 || v[11] < 1e-9 || v[11] > 1e12 ||
            v[14] < 0 || v[14] > 16 || v[15] <= 0 || v[15] > .1) return false;
        for (int k : {1,2,3,6,7,8,12,13}) if (std::abs(v[k]) > 1e6) return false;
        const auto proxy = static_cast<std::uint16_t>(v[0]);
        if (!next.owner_of[proxy] || next.proxies[proxy].valid) return false;
        auto& shape = next.geometry[proxy];
        for (int k = 0; k < 4; ++k) {
            shape[k] = geometry[(proxy-1)*4 + k];
            if (!std::isfinite(shape[k]) || std::abs(shape[k]) > 128) return false;
        }
        if (shape[2] != v[4] || shape[3] != v[5] || shape[2] < 1 || shape[3] < 1) return false;
        const Vector2 com=sampled_vec(v[12],v[13]), center=sampled_vec(v[1],v[2]);
        const auto expected = com + sampled_vec(shape[0],shape[1]).rotated(static_cast<real_t>(v[3]));
        const double tolerance = 4*std::numeric_limits<real_t>::epsilon() *
            std::max({128.,std::abs(v[12]),std::abs(v[13])});
        if (std::abs(expected.x-center.x)>tolerance || std::abs(expected.y-center.y)>tolerance) return false;
        auto& b = next.proxies[proxy];
        b.id = proxy; b.valid = true; b.center = center; b.com = com; b.rotation = v[3];
        b.half_size = sampled_vec(v[4]*.5,v[5]*.5); b.velocity = sampled_vec(v[6],v[7]); b.angular_velocity=v[8];
        b.mass=v[9]; b.sample_serial=static_cast<int>(v[10]); b.inertia=v[11]; b.friction=v[14]; b.dt=v[15];
        const auto& previous = old.proxies[proxy];
        if (old.session && (!previous.valid || previous.mass != b.mass || previous.inertia != b.inertia ||
            previous.friction != b.friction || old.geometry[proxy] != shape)) return false;
        if (retained.sampled) {
            const int advance = (b.sample_serial - previous.sample_serial + 1'000'000) % 1'000'000;
            if (advance == 0 || advance >= 500'000) return false;
        }
    }
    for (const auto& owner : next.owners) {
        if (!owner.instance) continue;
        const auto& first = next.proxies[owner.first];
        double area=0, mx=0, my=0, min_x=128, min_y=128, max_x=-128, max_y=-128;
        constexpr double tolerance = 4. * std::numeric_limits<real_t>::epsilon() * 128.;
        for (int i=owner.first; i<owner.first+owner.count; ++i) {
            const auto& b=next.proxies[i]; const auto& r=next.geometry[i];
            if (!b.valid || b.rotation != first.rotation || b.velocity != first.velocity ||
                b.angular_velocity != first.angular_velocity || b.mass != first.mass ||
                b.inertia != first.inertia || b.sample_serial != first.sample_serial ||
                b.com != first.com || b.friction != first.friction || b.dt != first.dt) return false;
            const auto a=r[2]*r[3];
            area+=a; mx+=a*r[0]; my+=a*r[1];
            min_x=std::min(min_x,r[0]-r[2]*.5); max_x=std::max(max_x,r[0]+r[2]*.5);
            min_y=std::min(min_y,r[1]-r[3]*.5); max_y=std::max(max_y,r[1]+r[3]*.5);
            for (int j=owner.first; j<i; ++j) {
                const auto& q=next.geometry[j];
                if (std::abs(q[0]-r[0])+tolerance < .5*(q[2]+r[2]) &&
                    std::abs(q[1]-r[1])+tolerance < .5*(q[3]+r[3])) return false;
            }
        }
        if (max_x-min_x>128+tolerance || max_y-min_y>128+tolerance ||
            (owner.count>1 && (std::abs(mx/area)>tolerance || std::abs(my/area)>tolerance))) return false;
    }
    return true;
}

bool CyberNativeCellWorld::prepare_workbench_coupling(const PackedFloat64Array& states,
        const PackedFloat64Array& geometry, const Array& owners, std::int64_t session,
        std::int64_t epoch, bool resolve_overlaps) {
    if (!world_ || world_->has_failed() || !workbench_) return false;
    workbench_->valid = false;
    WorkbenchSample next;
    if (!parse_workbench_sample(next,*workbench_,states,geometry,owners,session,epoch)) return false;
    try {
        workbench_->sample = next;
        current_bodies_ = next.proxies;
        workbench_->bins = {};
        prepare_body_coupling(resolve_overlaps);
        if (world_->has_failed()) return false;
        workbench_->prepared_tick = world_->completed_tick_index();
        workbench_->sampled = workbench_->valid = true;
        return true;
    } catch (...) {
        world_->quarantine_external_coupling(); ++tick_failure_count_;
        last_tick_error_ = "Workbench occupancy preparation failed";
        return false;
    }
}


bool CyberNativeCellWorld::authored_entry_normal(std::uint16_t body_id,
    std::int32_t x, std::int32_t y, Vector2& outward, double& penetration) const {
    // A current nearest face can be the far side of a thin moving hull.
    // Preserve a uniquely witnessed entry face only for unchanged-orientation
    // translation in the explicitly authored route. Other owners keep their
    // existing rule; ambiguous history falls back rather than inventing CCD.
    const auto& owner = workbench_->sample.owners[workbench_->sample.owner_of[body_id]];
    if (owner.count < 2) return false;
    const auto& body = current_bodies_[body_id];
    const auto& previous = previous_bodies_[body_id];
    if (!body.valid || !previous.valid || body.rotation != previous.rotation ||
        body.half_size != previous.half_size || !cell_inside_body(body, x, y) ||
        (body.sample_serial - previous.sample_serial + 1'000'000) % 1'000'000 != 1) return false;
    const double travel_squared = body.center.distance_squared_to(previous.center);
    if (!(travel_squared > 0.0) || travel_squared > kMaximumBodySweepDistance * kMaximumBodySweepDistance)
        return false;

    const auto local_point = [x, y](const BodyState& shape) {
        const double dx = x + 0.5 - shape.center.x, dy = y + 0.5 - shape.center.y;
        const double c = std::cos(shape.rotation), s = std::sin(shape.rotation);
        return std::array<double, 2>{c * dx + s * dy, -s * dx + c * dy};
    };
    struct SlabHit { bool intersects = false, ambiguous = false; int axis = -1; double sign = 0.0; };
    const auto intersect = [](const std::array<double, 2>& first,
        const std::array<double, 2>& last, Vector2 half_size) {
        SlabHit hit;
        const std::array<double, 2> half{half_size.x, half_size.y};
        double enter = 0.0, leave = 1.0;
        for (int axis = 0; axis < 2; ++axis) {
            const double delta = last[axis] - first[axis];
            if (delta == 0.0) {
                if (std::abs(first[axis]) > half[axis]) return hit;
                continue;
            }
            double near = (-half[axis] - first[axis]) / delta;
            double far = (half[axis] - first[axis]) / delta;
            const double sign = delta > 0.0 ? -1.0 : 1.0;
            if (near > far) std::swap(near, far);
            if (near > enter) {
                enter = near; hit.axis = axis; hit.sign = sign; hit.ambiguous = false;
            } else if (near == enter && hit.axis >= 0) hit.ambiguous = true;
            leave = std::min(leave, far);
            if (enter > leave) return SlabHit{};
        }
        hit.intersects = enter <= leave;
        if (hit.axis >= 0) {
            const int other = 1 - hit.axis;
            const double entry_other = first[other] + (last[other] - first[other]) * enter;
            if (std::abs(entry_other) >= half[other]) hit.ambiguous = true;
        }
        return hit;
    };
    // A point previously inside any piece has no new exterior-side witness.
    // Crossing any other proxy also makes this deliberately local witness
    // ambiguous, including a shared seam or an intervening concave piece.
    for (int proxy = owner.first; proxy < owner.first + owner.count; ++proxy) {
        const auto& old = previous_bodies_[proxy];
        const auto& current = current_bodies_[proxy];
        if (!old.valid || !current.valid || old.rotation != current.rotation ||
            old.half_size != current.half_size || cell_inside_body(old, x, y)) return false;
        if (proxy != body_id && intersect(local_point(old), local_point(current), current.half_size).intersects)
            return false;
    }
    const auto first = local_point(previous), last = local_point(body);
    if (std::abs(last[0]) > body.half_size.x || std::abs(last[1]) > body.half_size.y) return false;
    const auto hit = intersect(first, last, body.half_size);
    if (!hit.intersects || hit.ambiguous || hit.axis < 0) return false;
    const double half = hit.axis == 0 ? body.half_size.x : body.half_size.y;
    const double depth = half - hit.sign * last[hit.axis] + 0.5;
    const double c = std::cos(body.rotation), s = std::sin(body.rotation);
    const double nx = hit.axis == 0 ? hit.sign : 0.0, ny = hit.axis == 1 ? hit.sign : 0.0;
    outward = sampled_vec(c * nx - s * ny, s * nx + c * ny);
    penetration = depth;
    return true;
}

void CyberNativeCellWorld::accumulate_workbench_contacts() {
    constexpr std::array<Vector2i,4> directions{{{0,-1},{1,0},{0,1},{-1,0}}};
    for (const auto index : raster_indices_) {
        const int x=index%extent_.x, y=index/extent_.x;
        const auto id=world_->transient_obstacle_at(x,y);
        if (!id) continue;
        const auto& b=current_bodies_[id];
        const auto owner=workbench_->sample.owner_of[id];
        for (const auto direction : directions) {
            const auto sx=x+direction.x, sy=y+direction.y;
            if (!in_bounds(sx,sy) || world_->transient_obstacle_at(sx,sy)) continue;
            const auto material=world_->stored_material(sx,sy);
            if (!cybersand::MaterialRules::supports_granular_load(material)) continue;
            // The first adjacent face of this physical body owns this source.
            // Two independent bodies in contact with one grain remain independent.
            bool owns=false;
            for (const auto adjacent : directions) {
                const auto proxy=world_->transient_obstacle_at(sx+adjacent.x,sy+adjacent.y);
                if (workbench_->sample.owner_of[proxy] == owner) {
                    owns=proxy==id && sx+adjacent.x==x && sy+adjacent.y==y;
                    break;
                }
            }
            if (!owns) continue;
            const auto contact=cybersand::gcr::project({b.center.x,b.center.y},{b.half_size.x,b.half_size.y},
                b.rotation,{sx+.5,sy+.5});
            const bool side=contact.inward.y >= -std::sqrt(.5);
            const bool admitted=side && workbench_->response!="RFT"
                ? world_->granular_contact_admission_at(sx,sy,-contact.inward.x,-contact.inward.y).admitted
                : world_->granular_support_at(sx,sy,side,false);
            if (!admitted) continue;
            workbench_->bins[id][contact.bin].add(contact.point,contact.inward,{b.com.x,b.com.y});
            ++observations_[id].contacts;
            const auto& previous=previous_bodies_[id];
            const double downward=b.velocity.y+(workbench_->sample.owners[owner].count>1
                ? b.angular_velocity*(b.center.x-b.com.x) : 0.);
            if (!side && previous.valid && downward>0 && downward<=kGranularSettleVelocity) {
                const double travel=std::max(0.,static_cast<double>(b.center.y-previous.center.y));
                observations_[id].correction.y=-std::min(kMaximumGranularBearingCorrection,travel*kGranularBearingCorrectionFraction);
            }
        }
    }
}

Dictionary CyberNativeCellWorld::workbench_body_result(std::size_t id) const {
    const auto& owner=workbench_->sample.owners[id];
    const auto& body=current_bodies_[owner.first];
    using cybersand::gcr::Vec;
    using cybersand::gcr::length;
    const double gain=contact_gain_/1000.;
    Vec legacy{}, correction{};
    std::int64_t gx_sum=0, gy_sum=0, ax_sum=0, ay_sum=0, event_moment=0, arrival_moment=0;
    double legacy_moment=0, legacy_cost=0, area=0, radius=0;
    std::int64_t arrivals=0, missing=0, misaligned=0, contacts=0, displaced=0, unresolved=0;
    std::array<const cybersand::gcr::Bin*,8*8> bins{};
    std::size_t bin_count=0;
    for (int i=owner.first; i<owner.first+owner.count; ++i) {
        const auto proxy=static_cast<std::uint16_t>(i);
        if (world_->transient_granular_wrench_refused(proxy)) return {};
        const auto& b=current_bodies_[proxy];
        const auto& obs=observations_[proxy];
        const auto gx=world_->transient_granular_impulse_x(proxy), gy=world_->transient_granular_impulse_y(proxy);
        const auto ax=world_->transient_arrival_impulse_x(proxy), ay=world_->transient_arrival_impulse_y(proxy);
        const Vec contributing{obs.impulse.x+(static_cast<double>(world_->transient_contact_impulse_x(proxy))-gx)*gain,
                               obs.impulse.y+(static_cast<double>(world_->transient_contact_impulse_y(proxy))-gy)*gain};
        legacy=legacy+contributing;
        legacy_cost+=length(contributing);
        if (owner.count>1) legacy_moment+=cybersand::gcr::cross({b.center.x-body.com.x,b.center.y-body.com.y},contributing);
        if (!add_checked(gx_sum,gx) || !add_checked(gy_sum,gy) ||
            !add_checked(ax_sum,ax) || !add_checked(ay_sum,ay) ||
            !add_checked(event_moment,world_->transient_granular_moment2(proxy)) ||
            !add_checked(arrival_moment,world_->transient_arrival_moment2(proxy))) return {};
        arrivals+=world_->transient_arrival_count(proxy); missing+=world_->transient_arrival_missing(proxy);
        misaligned+=world_->transient_arrival_misaligned(proxy);
        const double shape_area=4.*b.half_size.x*b.half_size.y;
        area+=shape_area; correction=correction+Vec{obs.correction.x*shape_area,obs.correction.y*shape_area};
        contacts+=obs.contacts+world_->transient_contact_count(proxy);
        displaced+=obs.displaced; unresolved+=obs.unresolved;
        for (const auto& bin : workbench_->bins[proxy]) bins[bin_count++]=&bin;
        const double c=std::cos(b.rotation), s=std::sin(b.rotation);
        for (double x : {-static_cast<double>(b.half_size.x),static_cast<double>(b.half_size.x)})
            for (double y : {-static_cast<double>(b.half_size.y),static_cast<double>(b.half_size.y)})
                radius=std::max(radius,length({b.center.x+c*x-s*y-body.com.x,b.center.y+s*x+c*y-body.com.y}));
    }
    if (owner.count==1) radius=(body.com-body.center).length()+body.half_size.length();
    radius+=2.;
    correction=correction*(1./area);
    if (length(correction)>.5) correction=correction*(.5/length(correction));
    const double legacy_scale=legacy_cost>impulse_cap_ ? impulse_cap_/legacy_cost : 1.;
    const bool selective=workbench_->response=="LA-SELECTIVE";
    const Vec selected{static_cast<double>(selective ? ax_sum : gx_sum),static_cast<double>(selective ? ay_sum : gy_sum)};
    const double moment=(.5*static_cast<double>(selective ? arrival_moment : event_moment)
        -body.com.x*selected.y+body.com.y*selected.x)*gain;
    // The reference independent-body packet uses Godot real_t for event and
    // legacy vectors; the compound route sums/caps in double across all pieces.
    const bool single=owner.count==1;
    const Vec selected_impulse=selected*gain;
    const Vector2 rectangular_raw=sampled_vec(selected_impulse.x,selected_impulse.y);
    const double magnitude=single ? rectangular_raw.length() : length(selected_impulse);
    const double cost=std::max(magnitude,std::abs(moment)/radius);
    const double mass_scale=workbench_->response=="RFT" ? 1. : cybersand::gcr::load_scale(body.mass);
    const double cap=owner.budget*mass_scale, allowance=std::min(20.,cap);
    const double event_scale=workbench_->response=="LA-EVENT-OFF" ? 0. : (cost>allowance ? allowance/cost : 1.);
    Vec event=selected_impulse*event_scale;
    if (single) {
        const auto event32=rectangular_raw*event_scale;
        event={event32.x,event32.y};
    }
    const double event_torque=moment*event_scale;
    cybersand::gcr::Body state;
    state.velocity={body.velocity.x+event.x/body.mass,body.velocity.y+event.y/body.mass};
    state.omega=body.angular_velocity+event_torque/body.inertia;
    state.com={body.com.x,body.com.y}; state.mass=body.mass; state.inertia=body.inertia; state.mu=body.friction;
    const auto passive=cybersand::gcr::solve_compound(state,{bins.data(),bin_count},workbench_->workspace,
        cap-cost*event_scale,mass_scale,owner.budget);
    Vec impulse=legacy*legacy_scale+event+passive.impulse;
    if (single) {
        const auto proxy=static_cast<std::uint16_t>(owner.first);
        Vector2 legacy32=observations_[proxy].impulse+sampled_vec(
            (static_cast<double>(world_->transient_contact_impulse_x(proxy))-gx_sum)*gain,
            (static_cast<double>(world_->transient_contact_impulse_y(proxy))-gy_sum)*gain);
        if (legacy32.length()>impulse_cap_) legacy32=legacy32.normalized()*impulse_cap_;
        const auto combined=legacy32+sampled_vec(event.x,event.y)+sampled_vec(passive.impulse.x,passive.impulse.y);
        impulse={combined.x,combined.y};
    }
    // WCX/BW-001 droplets that struck this body deliver their booked momentum.
    for (int i=owner.first; i<owner.first+owner.count; ++i) {
        const auto droplet=spray_droplet_impulse(static_cast<std::uint16_t>(i));
        impulse=impulse+Vec{droplet.x,droplet.y};
    }
    const double torque=legacy_moment*legacy_scale+event_torque+passive.torque;
    if (!std::isfinite(impulse.x) || !std::isfinite(impulse.y) || !std::isfinite(torque)) return {};
    Dictionary row;
    row["id"]=static_cast<std::int64_t>(id); row["instance_id"]=owner.instance; row["generation"]=owner.generation;
    row["sample"]=body.sample_serial; row["com"]=body.com;
    row["impulse"]=sampled_vec(impulse.x,impulse.y); row["torque"]=torque;
    row["correction"]=sampled_vec(correction.x,correction.y); row["budget"]=owner.budget;
    row["mass"]=body.mass; row["inertia"]=body.inertia; row["gravity"]=owner.gravity;
    row["external_drive"]=owner.external_drive; row["proxy_count"]=owner.count;
    row["contacts"]=contacts; row["displaced"]=displaced; row["unresolved"]=unresolved;
    row["normal_accepted"]=passive.normal; row["tangent_accepted"]=passive.tangent;
    row["event_accepted"]=sampled_vec(event.x,event.y); row["event_torque"]=event_torque; row["arrival_count"]=arrivals;
    row["arrival_missing"]=missing; row["arrival_misaligned"]=misaligned;
    row["normal_capacity"]=passive.capacity; row["body_capacity"]=cap; row["event_cost"]=cost*event_scale;
    row["passive_impulse"]=sampled_vec(passive.impulse.x,passive.impulse.y); row["passive_torque"]=passive.torque;
    row["passivity_rejected"]=passive.passive_rejected; row["nodes"]=passive.nodes;
    return row;
}

Dictionary CyberNativeCellWorld::workbench_coupling_results() const {
    if (!workbench_ || !world_ || world_->has_failed()) return {};
    Dictionary result; Array rows;
    result["session"]=workbench_->sample.session; result["epoch"]=workbench_->sample.epoch;
    result["response"]=workbench_->response; result["extent"]=extent_;
    result["proxy_limit"]=cybersand::World::kMaximumTransientBodies;
    result["body_limit"]=static_cast<std::int64_t>(kWorkbenchBodies);
    result["world_mask_cell_limit"]=static_cast<std::int64_t>(extent_.x)*extent_.y;
    result["native_mask_reserved"]=static_cast<std::int64_t>(world_->transient_occupancy_capacity());
    result["raster_indices_reserved"]=static_cast<std::int64_t>(raster_indices_.capacity());
    result["arrival_storage_bytes"]=static_cast<std::int64_t>(world_->granular_arrival_storage_bytes());
    const bool valid=workbench_->valid && world_->completed_tick_index()-workbench_->prepared_tick<=1;
    result["valid"]=valid; result["sample_tick"]=static_cast<std::int64_t>(workbench_->prepared_tick);
    if (valid) for (std::size_t id=1; id<workbench_->sample.owners.size(); ++id) {
        if (!workbench_->sample.owners[id].instance) continue;
        auto row=workbench_body_result(id);
        if (row.is_empty()) { result["valid"]=false; rows.clear(); break; }
        rows.push_back(row);
    }
    result["rows"]=rows;
    return result;
}
