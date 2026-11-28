// Selected external Fire ignition for OBJECTSHARD-001R. Included in the one
// coordinator translation unit: no extra simulation owner, Fire inventory or
// parallel chemistry clock. World's selected ignition law is unchanged; its
// opt-in spent-opportunity guard prevents a second effect in that same tick.
std::uint32_t& Coordinator::fire_opportunity(std::int64_t x,std::int64_t y) noexcept {
    const auto tick=world_->completed_tick_index()+1;
    if (fire_opportunity_tick_!=tick) {
        std::fill(fire_opportunities_.begin(),fire_opportunities_.end(),0);
        fire_opportunity_tick_=tick;
    }
    const auto wb=config_.world_bounds;
    const auto index=static_cast<std::uint32_t>(y-wb.y)*wb.width+static_cast<std::uint32_t>(x-wb.x);
    auto& token=fire_opportunities_[index];
    if (!token) token=index+1U;
    return token;
}

Outcome Coordinator::capture_fire_ignition(Shard& shard,const BodyView& body) {
    if (world_->quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Fire)]==0)
        return Outcome::Accepted;
    ScopedTime timing{metrics_.contact_ns};
    namespace chemistry=material_lifecycle;
    const auto bounds=shard.bounds();
    contact::Envelope envelope;
    envelope.max_translation=config_.max_translation_per_step;
    envelope.max_rotation=config_.max_rotation_per_step;
    const auto before=contact_pose(body.previous_pose),after=contact_pose(body.pose);
    const auto sweep=contact::plan_sweep(before,after,bounds.width,bounds.height,envelope);
    if (sweep.outcome!=Outcome::Accepted) return sweep.outcome;
    const auto tick=world_->completed_tick_index()+1;
    const auto wb=config_.world_bounds;
    for (std::uint16_t sample=0;sample<sweep.samples;++sample) {
        const auto pose=contact::interpolated_pose(before,after,static_cast<double>(sample)/(sweep.samples-1));
        const auto frame=contact::frame(pose);
        auto region=contact::transformed_bounds(frame,bounds.width,bounds.height);
        region.min_x-=1;region.min_y-=1;region.max_x+=1;region.max_y+=1;
        auto candidates=contact::grid_candidates(region);
        if (!candidates.valid) return Outcome::Unsupported;
        candidates.min_x=std::max(candidates.min_x,wb.x);
        candidates.min_y=std::max(candidates.min_y,wb.y);
        candidates.max_x=std::min(candidates.max_x,wb.x+wb.width-1);
        candidates.max_y=std::min(candidates.max_y,wb.y+wb.height-1);
        ++metrics_.sweep_samples;
        for (auto y=candidates.min_y;y<=candidates.max_y;++y)
            for (auto x=candidates.min_x;x<=candidates.max_x;++x) {
                if (world_->stored_material(x,y)!=Material::Fire) continue;
                auto& opportunity=fire_opportunity(x,y);
                if (opportunity&0x80000000U) continue;
                const auto anchor=(opportunity&0x7fffffffU)-1U;
                const auto anchor_x=wb.x+anchor%wb.width,anchor_y=wb.y+anchor/wb.width;
                if (!chemistry::lane_due(tick,anchor_x,anchor_y,120,10)) continue;
                // Conservative displacement must not re-roll cadence/direction
                // or multiply one Fire inventory's effect across real segments.
                const auto offset=chemistry::kNeighbours[chemistry::random(tick,anchor_x,anchor_y,10)%8];
                const auto target_x=x+offset.x,target_y=y+offset.y;
                if (!resident(target_x,target_y) || MaterialRules::is_hard_surface(world_->stored_material(target_x,target_y))) continue;
                const auto target=contact::to_local(frame,{static_cast<double>(target_x)+.5,static_cast<double>(target_y)+.5});
                if (target.x<0 || target.y<0 || target.x>=bounds.width || target.y>=bounds.height) continue;
                const auto lx=static_cast<std::uint16_t>(target.x),ly=static_cast<std::uint16_t>(target.y);
                const auto at=static_cast<std::uint32_t>(ly)*bounds.width+lx;
                if (!shard.structural(at) || shard.payload(at).material!=Material::Wood) continue;
                const auto source=contact::to_local(frame,{static_cast<double>(x)+.5,static_cast<double>(y)+.5});
                // A Moore sample cannot tunnel through an intervening rigid
                // cell. Check its short, exact local segment, excluding only
                // the target cell; all other structural/cargo cells occlude.
                bool blocked=false;
                const auto minx=std::max(0,static_cast<int>(std::floor(std::min(source.x,target.x))));
                const auto miny=std::max(0,static_cast<int>(std::floor(std::min(source.y,target.y))));
                const auto maxx=std::min(static_cast<int>(bounds.width)-1,static_cast<int>(std::floor(std::max(source.x,target.x))));
                const auto maxy=std::min(static_cast<int>(bounds.height)-1,static_cast<int>(std::floor(std::max(source.y,target.y))));
                for (auto cy=miny;cy<=maxy && !blocked;++cy) for (auto cx=minx;cx<=maxx && !blocked;++cx) {
                    const auto other=static_cast<std::uint32_t>(cy)*bounds.width+static_cast<std::uint32_t>(cx);
                    if (other==at || (!shard.structural(other) && shard.role(other)!=Role::Cargo)) continue;
                    blocked=contact::detail::segment_hits_box(source,target,
                        {static_cast<double>(cx),static_cast<double>(cy),cx+1.0,cy+1.0});
                }
                if (blocked) continue;
                if (exposures_.size()==exposures_.capacity()) {++metrics_.exposure_overflows;return Outcome::Capacity;}
                if (next_exposure_==std::numeric_limits<std::uint64_t>::max()) return Outcome::GenerationExhausted;
                exposures_.push_back({shard.handle(),at,shard.schedule(at).incarnation,shard.geometry().revision,
                    body.pose.pose_serial,tick,tick,next_exposure_++,false,ExposureKind::FireIgnition,x,y});
                opportunity|=0x80000000U;
                ++accounting_.accepted_exposures;
            }
    }
    return Outcome::Accepted;
}
