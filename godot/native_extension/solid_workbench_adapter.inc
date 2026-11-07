// Diagnostic attachment only: retain the World that will author/cut/own SOL.
// No new contact arithmetic, constructor swap, force budget or material policy.
bool CyberNativeCellWorld::diagnostic_enable_solid_workbench() {
    if (!diagnostic_fixture_ || !world_ || world_->has_failed() || workbench_) return false;
    const auto phase = world_->inspect_solid_detachment().phase;
    if (phase != cybersand::soliding::SolidPhase::Disabled &&
        phase != cybersand::soliding::SolidPhase::Idle) return false;
    try {
        auto next = std::make_unique<Workbench>();
        next->response = "LA-SELECTIVE";
        next->solid_aggregate = true;
        world_->configure_transient_obstacles({0,0,extent_.x,extent_.y},true);
        world_->enable_transient_granular_wrenches(true);
        world_->enable_granular_arrival_witness(true);
        raster_indices_.reserve(static_cast<std::size_t>(extent_.x)*extent_.y);
        // Main's workbench uses its own existing overlap/reaction route. The
        // separately selected SOL conservative-displacement law is legacy only.
        conservative_displacement_ = false;
        workbench_ = std::move(next);
        return true;
    } catch (const std::exception& error) {
        last_tick_error_ = error.what();
        return false;
    }
}

bool CyberNativeCellWorld::admit_solid_workbench_sample(const WorkbenchSample& next,
    std::int64_t epoch) {
    const auto source = world_->inspect_solid_detachment();
    using cybersand::soliding::SolidPhase;
    if (!workbench_->solid_generation || source.phase != SolidPhase::Active || source.body_id != 1 ||
        source.physics_epoch != static_cast<std::uint64_t>(epoch) ||
        source.member_count == 0 || source.aggregate_owned_count != source.member_count ||
        source.shape_count < 1 || source.shape_count > 8) return false;
    const auto& owner = next.owners[1];
    if (!owner.instance || owner.first != 1 || owner.count != static_cast<int>(source.shape_count) ||
        owner.budget != 20.0 || owner.generation != epoch || owner.external_drive) return false;
    for (std::size_t i=2;i<next.owners.size();++i) if (next.owners[i].instance) return false;
    if (workbench_->solid_token != source.token || workbench_->solid_generation != source.body_generation) return false;
    const auto& physical = next.proxies[1];
    if (!workbench_->sampled && workbench_->sample.session) {
        for (int i=1;i<=owner.count;++i) {
            const auto& a=next.proxies[i];const auto& b=workbench_->sample.proxies[i];
            if (a.center!=b.center || a.com!=b.com || a.rotation!=b.rotation ||
                a.velocity!=b.velocity || a.angular_velocity!=b.angular_velocity ||
                a.sample_serial!=b.sample_serial) return false;
        }
    }
    const auto close = [](double a,double b) {
        return std::abs(a-b) <= 4*std::numeric_limits<real_t>::epsilon()*std::max({1.,std::abs(a),std::abs(b)});
    };
    if (!close(physical.mass,source.mass) || !close(physical.inertia,source.inertia)) return false;
    std::array<cybersand::soliding::SolidShape,cybersand::soliding::kSolidShapes> shapes{};
    if (world_->copy_solid_detachment_shapes(shapes) != source.shape_count) return false;
    const double cx=source.domain.x+source.com_x,cy=source.domain.y+source.com_y;
    constexpr double tolerance=4*std::numeric_limits<real_t>::epsilon()*128.;
    for (std::size_t i=0;i<source.shape_count;++i) {
        const auto& a=shapes[i];const auto& b=next.geometry[i+1];
        if (b[2]!=a.width || b[3]!=a.height ||
            std::abs(b[0]-(a.x+a.width*.5-cx))>tolerance ||
            std::abs(b[1]-(a.y+a.height*.5-cy))>tolerance) return false;
    }
    return true;
}

bool CyberNativeCellWorld::diagnostic_bind_solid_workbench(const Dictionary& request) {
    if (!diagnostic_fixture_ || !world_ || world_->has_failed() || !workbench_ ||
        !workbench_->solid_aggregate || workbench_->solid_generation || workbench_->sampled) return false;
    const auto source=world_->inspect_solid_detachment();
    const String token=(std::to_string(source.token.incarnation)+":"+std::to_string(source.token.sequence)).c_str();
    if (request.get("token",Variant()).get_type()!=Variant::STRING || String(request["token"])!=token ||
        request.get("body_generation",Variant()).get_type()!=Variant::INT ||
        static_cast<std::int64_t>(request["body_generation"])!=static_cast<std::int64_t>(source.body_generation) ||
        request.get("sample",Variant()).get_type()!=Variant::DICTIONARY) return false;
    const Dictionary sample=request["sample"];
    if (sample.get("states",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
        sample.get("geometry",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
        sample.get("bodies",Variant()).get_type()!=Variant::ARRAY ||
        sample.get("session",Variant()).get_type()!=Variant::INT || sample.get("epoch",Variant()).get_type()!=Variant::INT) return false;
    WorkbenchSample initial;
    const auto epoch=static_cast<std::int64_t>(sample["epoch"]);
    if (!parse_workbench_sample(initial,*workbench_,sample["states"],sample["geometry"],sample["bodies"],sample["session"],epoch)) return false;
    // Bind explicit native ownership before validating the corresponding exact
    // source shape. Failed requests roll back these context scalars only.
    workbench_->solid_token=source.token;workbench_->solid_generation=source.body_generation;
    bool valid=admit_solid_workbench_sample(initial,epoch);
    constexpr double tolerance=4*std::numeric_limits<real_t>::epsilon()*128.;
    const double cx=source.domain.x+source.com_x,cy=source.domain.y+source.com_y;
    for (int i=1;i<=static_cast<int>(source.shape_count) && valid;++i) {
        const auto& b=initial.proxies[i];
        valid=b.rotation==0 && b.velocity==Vector2{} && b.angular_velocity==0 &&
            std::abs(b.com.x-cx)<=tolerance && std::abs(b.com.y-cy)<=tolerance;
    }
    if (!valid) { workbench_->solid_token={};workbench_->solid_generation=0;return false; }
    workbench_->sample=initial; // Locks session/instance/roster/geometry on first prepare.
    return true;
}

// Ordinary workbench lane. The worker holds authoring/ticks across this value
// protocol; only the main-thread owner constructs or applies Rapier objects.
Dictionary CyberNativeCellWorld::workbench_cut_command(const Dictionary& request) {
    using namespace cybersand::soliding;
    using namespace solid_adapter;
    const String action=request.get("action","");
    auto finish=[&](SolidOutcome outcome,bool payload=false) {
        auto result=reply(world_.get(),outcome,payload);
        result["schema"]="cybersand.workbench-cut.v1";
        result["active_count"]=world_ ? static_cast<std::int64_t>(world_->workbench_solid_count()) : 0;
        const auto debris=world_ ? world_->workbench_debris_ledger() : std::array<std::uint64_t,4>{};
        result["debris_pieces"]=static_cast<std::int64_t>(debris[0]);
        result["brick_converted"]=static_cast<std::int64_t>(debris[1]);
        result["sand_produced"]=static_cast<std::int64_t>(debris[2]);
        result["rust_produced"]=static_cast<std::int64_t>(debris[3]);
        result["small_debris_limit"]=static_cast<std::int64_t>(workbench_cut_.small_debris_limit);
        if (world_) {
            const auto source=world_->inspect_solid_detachment();
            result["representation"]=source.granular_piece ? "granular" : "rigid";
            result["granular_converted_count"]=static_cast<std::int64_t>(source.granular_converted_count);
        }
        const auto work=world_ ? world_->workbench_solid_discovery_work() : std::array<std::uint64_t,2>{};
        result["discovery_cells"]=static_cast<std::int64_t>(work[0]);
        result["discovery_neighbours"]=static_cast<std::int64_t>(work[1]);
        result["frontier_checks"]=static_cast<std::int64_t>(workbench_cut_.frontier_checks);
        result["frontier_candidates"]=static_cast<std::int64_t>(workbench_cut_.frontier_candidates);
        result["discovery_attempts"]=static_cast<std::int64_t>(workbench_cut_.count);
        result["frontier_complete"]=workbench_cut_.frontier_complete;
        result["frontier_limited"]=workbench_cut_.frontier_limited;
        result["held"]=workbench_cut_.held;
        result["roster_session"]=workbench_ ? workbench_->sample.session : 0;
        result["roster_epoch"]=workbench_ ? workbench_->sample.epoch : 0;
        return result;
    };
    if (!world_ || world_->has_failed()) return finish(SolidOutcome::WorldFailed);
    if (!workbench_ || diagnostic_fixture_ || workbench_->solid_aggregate) return finish(SolidOutcome::Ineligible);
    auto& cut=workbench_cut_;
    try {
        if (action=="begin") {
            if (cut.held || world_->solid_detachment_fenced()) return finish(SolidOutcome::Busy);
            std::int64_t debris_limit=0;
            if (request.has("small_debris_limit") &&
                (!integer(request,"small_debris_limit",0,kWorkbenchSmallDebrisCells,debris_limit) ||
                 (debris_limit!=0 && debris_limit!=static_cast<std::int64_t>(kWorkbenchSmallDebrisCells))))
                return finish(SolidOutcome::Invalid);
            if (request.get("dabs",Variant()).get_type()!=Variant::PACKED_INT32_ARRAY ||
                request.get("sample",Variant()).get_type()!=Variant::DICTIONARY) return finish(SolidOutcome::Invalid);
            const PackedInt32Array dabs=request["dabs"];
            if (dabs.is_empty() || dabs.size()%3 || dabs.size()>256*3) return finish(SolidOutcome::Invalid);
            // Validate all inputs before even reserving the custody store.
            for (int i=0;i<dabs.size();i+=3)
                if (dabs[i]<0 || dabs[i]>=extent_.x || dabs[i+1]<0 || dabs[i+1]>=extent_.y ||
                    dabs[i+2]<1 || dabs[i+2]>24) return finish(SolidOutcome::Invalid);
            const Dictionary sample=request["sample"];
            WorkbenchSample checked;
            if (!sample.is_empty()) {
                if (sample.get("states",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                    sample.get("geometry",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                    sample.get("bodies",Variant()).get_type()!=Variant::ARRAY) return finish(SolidOutcome::Invalid);
                if (!parse_workbench_sample(checked,*workbench_,sample["states"],sample["geometry"],sample["bodies"],
                    sample.get("session",0),sample.get("epoch",0))) return finish(SolidOutcome::Stale);
            } else {
                for (const auto& owner:workbench_->sample.owners)
                    if (owner.instance) return finish(SolidOutcome::Stale);
            }
            const auto configured=world_->configure_workbench_solids({0,0,static_cast<std::uint16_t>(extent_.x),static_cast<std::uint16_t>(extent_.y)});
            if (configured!=SolidOutcome::Accepted) return finish(configured);
            cut={};cut.held=true;
            cut.small_debris_limit=static_cast<std::size_t>(debris_limit);
            // Traverse the frontier lazily after each handoff. Other boundary
            // cells of a retired piece are then Empty, not extra investigations.
            // All storage and work remain bounded by the validated stroke.
            cut.dab_count=static_cast<std::size_t>(dabs.size()/3);
            for (std::size_t i=0;i<cut.dab_count;++i)
                cut.dabs[i]={dabs[static_cast<int>(3*i)],dabs[static_cast<int>(3*i+1)],dabs[static_cast<int>(3*i+2)]};
            if (!sample.is_empty() && !prepare_workbench_coupling(sample["states"],sample["geometry"],sample["bodies"],
                sample.get("session",0),sample.get("epoch",0),false)) return finish(SolidOutcome::Stale);
            return finish(SolidOutcome::Accepted);
        }
        // A failed begin still owns the worker hold until an unchanged roster
        // is re-primed. No source tuple or transaction is cancelled by end.
        if (!cut.held && action!="end") return finish(SolidOutcome::Stale);
        // Bounded paused-owner value observer; no UI or mutable storage escape.
        if (action=="census") {
            if (request.get("area",Variant()).get_type()!=Variant::RECT2I) return finish(SolidOutcome::Invalid);
            const Rect2i area=request["area"];
            if (area.position.x<0 || area.position.y<0 || area.position.x>=extent_.x || area.position.y>=extent_.y ||
                area.size.x<1 || area.size.y<1 || area.size.x>64 || area.size.y>64 ||
                area.size.x>extent_.x-area.position.x || area.size.y>extent_.y-area.position.y)
                return finish(SolidOutcome::Invalid);
            PackedInt32Array pixels;
            for (int y=area.position.y;y<area.position.y+area.size.y;++y)
                for (int x=area.position.x;x<area.position.x+area.size.x;++x) {
                if (!world_->contact_cell_available(x,y)) return finish(SolidOutcome::NotResident);
                pixels.push_back(x);pixels.push_back(y);pixels.push_back(static_cast<int>(world_->stored_material(x,y)));
            }
            auto result=finish(SolidOutcome::Accepted);result["pixels"]=pixels;result["area"]=area;return result;
        }
        if (action=="next") {
            if (world_->inspect_solid_detachment().phase!=SolidPhase::Idle) return finish(SolidOutcome::Busy);
            if (cut.frontier_limited) {auto r=finish(SolidOutcome::MemberCapacity);r["done"]=true;return r;}
            constexpr std::array<Vector2i,4> neighbours{{{0,-1},{-1,0},{1,0},{0,1}}};
            while (cut.dab_cursor<cut.dab_count) {
                const auto& dab=cut.dabs[cut.dab_cursor];
                const int radius=dab[2],side=2*radius+1;
                const auto bound=static_cast<std::size_t>(side*side*4);
                if (cut.frontier_cursor==bound) {++cut.dab_cursor;cut.frontier_cursor=0;continue;}
                const auto index=cut.frontier_cursor++;
                ++cut.frontier_checks;
                const int dx=static_cast<int>((index/4)%static_cast<std::size_t>(side))-radius;
                const int dy=static_cast<int>((index/4)/static_cast<std::size_t>(side))-radius;
                if (dx*dx+dy*dy>radius*radius) continue;
                const auto offset=neighbours[index%4];
                const int nx=dx+offset.x,ny=dy+offset.y;
                if (nx*nx+ny*ny<=radius*radius) continue;
                ++cut.frontier_candidates;
                const Vector2i point{dab[0]+nx,dab[1]+ny};
                if (point.x<0 || point.y<0 || point.x>=extent_.x || point.y>=extent_.y ||
                    world_->stored_material(point.x,point.y)!=cybersand::Material::RedBrick) continue;
                bool duplicate=false;
                for (std::size_t k=0;k<cut.count;++k) duplicate|=cut.seeds[k]==point;
                if (duplicate) continue;
                if (cut.count==cut.seeds.size()) {
                    cut.frontier_limited=true;
                    auto r=finish(SolidOutcome::MemberCapacity);r["done"]=true;return r;
                }
                cut.seeds[cut.count++]=point;
                const auto outcome=world_->prepare_workbench_solid(point.x,point.y,cut.small_debris_limit);
                auto result=finish(outcome,outcome==SolidOutcome::Accepted);result["seed"]=point;return result;
            }
            cut.frontier_complete=true;
            auto r=finish(SolidOutcome::Accepted);r["done"]=true;return r;
        }
        if (action=="end") {
            const auto phase=world_->inspect_solid_detachment().phase;
            if (phase!=SolidPhase::Idle && phase!=SolidPhase::Disabled) return finish(SolidOutcome::Busy);
            if (request.get("sample",Variant()).get_type()!=Variant::DICTIONARY) return finish(SolidOutcome::Invalid);
            const Dictionary sample=request["sample"];
            if (sample.is_empty()) {
                for (const auto& owner:workbench_->sample.owners) if (owner.instance) return finish(SolidOutcome::Stale);
            } else {
                WorkbenchSample checked;
                if (sample.get("states",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                    sample.get("geometry",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                    sample.get("bodies",Variant()).get_type()!=Variant::ARRAY ||
                    !parse_workbench_sample(checked,*workbench_,sample["states"],sample["geometry"],sample["bodies"],
                        sample.get("session",0),sample.get("epoch",0))) return finish(SolidOutcome::Stale);
            }
            auto result=finish(SolidOutcome::Accepted);
            result["held"]=false;
            cut={};return result;
        }
        const auto source=world_->inspect_solid_detachment();
        if (!text_matches(request,"token",token_text(source.token))) return finish(SolidOutcome::Stale);
        if (action=="cancel") {
            const auto result=world_->cancel_solid_detachment(source.token);
            if (result==SolidOutcome::Accepted) cut.staged=false;
            return finish(result);
        }
        if (action=="crumble") {
            const auto result=cut.staged ? SolidOutcome::Stale : world_->crumble_workbench_solid(source.token);
            if (result==SolidOutcome::Accepted) {
                ++revision_;render_snapshot_full_refresh_required_=true;
                workbench_->sampled=false;workbench_->valid=false;workbench_->bins={};
            }
            return finish(result,result==SolidOutcome::Accepted);
        }
        if (action=="finalize_debris") {
            if (!text_matches(request,"terrain_revision",decimal(source.committed_terrain_revision))) return finish(SolidOutcome::Stale);
            return finish(world_->finalize_workbench_crumble(source.token,source.committed_terrain_revision));
        }
        if (action=="acknowledge") {
            if (source.phase!=SolidPhase::Prepared || request.get("sample",Variant()).get_type()!=Variant::DICTIONARY)
                return finish(SolidOutcome::Stale);
            const Dictionary sample=request["sample"];
            if (sample.get("states",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                sample.get("geometry",Variant()).get_type()!=Variant::PACKED_FLOAT64_ARRAY ||
                sample.get("bodies",Variant()).get_type()!=Variant::ARRAY) return finish(SolidOutcome::Invalid);
            Workbench empty;empty.response=workbench_->response;
            WorkbenchSample next;
            if (!parse_workbench_sample(next,empty,sample["states"],sample["geometry"],sample["bodies"],
                    sample.get("session",0),sample.get("epoch",0))) return finish(SolidOutcome::Invalid);
            const auto& old=workbench_->sample;
            if (next.session<=old.session || next.epoch<=old.epoch) return finish(SolidOutcome::Stale);
            int bodies=0,proxies=0;
            for (std::size_t id=1;id<old.owners.size();++id) {
                const auto& a=old.owners[id];const auto& b=next.owners[id];
                if (!a.instance) continue;
                ++bodies;proxies+=a.count;
                if (static_cast<int>(id)!=bodies || a.instance!=b.instance || b.generation!=next.epoch ||
                    a.first!=b.first || a.count!=b.count || a.budget!=b.budget || a.gravity!=b.gravity ||
                    b.external_drive) return finish(SolidOutcome::Invalid);
                for (int p=a.first;p<a.first+a.count;++p) {
                    const auto& x=old.proxies[p];const auto& y=next.proxies[p];
                    if (x.center!=y.center || x.com!=y.com || x.rotation!=y.rotation || x.velocity!=y.velocity ||
                        x.angular_velocity!=y.angular_velocity || x.mass!=y.mass || x.inertia!=y.inertia ||
                        x.friction!=y.friction || x.dt!=y.dt || old.geometry[p]!=next.geometry[p]) return finish(SolidOutcome::Stale);
                }
            }
            if (bodies>=8) return finish(SolidOutcome::MemberCapacity);
            const auto& owner=next.owners[bodies+1];
            if (!owner.instance || owner.generation!=next.epoch || owner.first!=proxies+1 ||
                owner.count!=static_cast<int>(source.shape_count) || owner.budget!=20 || owner.external_drive)
                return finish(SolidOutcome::Invalid);
            for (std::size_t id=bodies+2;id<next.owners.size();++id) if (next.owners[id].instance) return finish(SolidOutcome::Invalid);
            std::array<SolidShape,kSolidShapes> shapes{};
            if (world_->copy_solid_detachment_shapes(shapes)!=source.shape_count) return finish(SolidOutcome::Invalid);
            const auto close=[](double a,double b) {return std::abs(a-b)<=4*std::numeric_limits<real_t>::epsilon()*std::max({128.,std::abs(a),std::abs(b)});};
            const double cx=source.domain.x+source.com_x,cy=source.domain.y+source.com_y;
            for (int i=0;i<owner.count;++i) {
                const auto p=owner.first+i;const auto& body=next.proxies[p];const auto& shape=shapes[i];const auto& g=next.geometry[p];
                if (body.rotation!=0 || body.velocity!=Vector2{} || body.angular_velocity!=0 ||
                    !close(owner.gravity,92.12) || !close(body.friction,.78) || !close(body.dt,1./60.) ||
                    !close(body.com.x,cx) || !close(body.com.y,cy) || !close(body.mass,source.mass) || !close(body.inertia,source.inertia) ||
                    !close(g[0],shape.x+shape.width*.5-cx) || !close(g[1],shape.y+shape.height*.5-cy) ||
                    g[2]!=shape.width || g[3]!=shape.height) return finish(SolidOutcome::Invalid);
            }
            const auto result=world_->acknowledge_solid_detachment({source.token,static_cast<std::uint16_t>(owner.first),
                static_cast<std::uint64_t>(next.epoch),source.payload_digest,source.shape_digest,source.shape_count});
            if (result==SolidOutcome::Accepted) {cut.next=next;cut.staged=true;}
            return finish(result);
        }
        if (action=="commit") {
            const auto result=cut.staged ? world_->commit_solid_detachment(source.token) : SolidOutcome::Stale;
            if (result==SolidOutcome::Accepted) {++revision_;render_snapshot_full_refresh_required_=true;}
            return finish(result,result==SolidOutcome::Accepted);
        }
        if (action=="finalize") {
            if (!cut.staged || source.phase!=SolidPhase::Committed || source.committed_terrain_revision!=world_->hard_surface_revision() ||
                !text_matches(request,"terrain_revision",decimal(source.committed_terrain_revision))) return finish(SolidOutcome::Stale);
            const auto rebound=world_->rebind_workbench_solids(static_cast<std::uint64_t>(workbench_->sample.epoch),static_cast<std::uint64_t>(cut.next.epoch));
            if (rebound!=SolidOutcome::Accepted) return finish(rebound);
            auto result=world_->finalize_solid_detachment({source.token,source.body_id,source.body_generation,
                source.committed_terrain_revision,static_cast<std::uint64_t>(cut.next.epoch)});
            if (result==SolidOutcome::Accepted) result=world_->archive_workbench_solid(source.token);
            if (result!=SolidOutcome::Accepted) {world_->quarantine_external_coupling();return finish(result);}
            workbench_->sample=cut.next;workbench_->sampled=false;workbench_->valid=false;workbench_->bins={};
            cut.staged=false;
            // No tick, contact application or transport provenance is replayed.
            current_bodies_=cut.next.proxies;
            prepare_body_coupling(false);
            return finish(SolidOutcome::Accepted);
        }
        if (action=="fail") {world_->quarantine_external_coupling();return finish(SolidOutcome::Quarantined);}
        return finish(SolidOutcome::Invalid);
    } catch (const std::exception& error) {
        world_->quarantine_external_coupling();last_tick_error_=error.what();return finish(SolidOutcome::Quarantined);
    }
}
