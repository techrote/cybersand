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
