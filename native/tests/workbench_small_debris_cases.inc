// Component routing and existing-law equivalence, independent of Rapier.
static void small_debris(unsigned workers) {
    for (const int n : {1,15,16,17}) {
        World w(config(workers));w.reserve_region({0,0,128,128});
        expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"debris source configure");
        for (int x=0;x<n;++x) w.set(20+x,20,Material::RedBrick);
        expect(w.prepare_workbench_solid(20,20,16)==SolidOutcome::Accepted,"inclusive size classification");
        const auto s=w.inspect_solid_detachment();
        expect(s.member_count==static_cast<std::size_t>(n) && s.granular_piece==(n<=16),"cell area, not bounding-box area");
        if (n==17) {
            expect(w.crumble_workbench_solid(s.token)==SolidOutcome::Invalid,"large piece cannot enter debris commit");
            expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"large control source retained");
            continue;
        }
        expect(w.acknowledge_solid_detachment({s.token,1,2,s.payload_digest,s.shape_digest,s.shape_count})==SolidOutcome::Invalid,"debris cannot be reserved as a duplicate rigid owner");
        expect(w.crumble_workbench_solid(s.token)==SolidOutcome::Accepted,"native material conversion");
        const auto converted=w.inspect_solid_detachment();
        expect(converted.phase==SolidPhase::DebrisCommitted && converted.granular_converted_count==static_cast<std::size_t>(n) && converted.aggregate_owned_count==0,"native pixel ownership retained under terrain fence");
        expect(w.workbench_solid_count()==0 && w.solid_detachment_fenced(),"no Rapier archive; clocks fenced");
        refuses_serialization([&]{(void)w.physical_state_hash();});
        expect(w.crumble_workbench_solid(s.token)==SolidOutcome::Stale,"one-use conversion token");
        expect(w.finalize_workbench_crumble(s.token,w.hard_surface_revision()+1)==SolidOutcome::Stale,"stale terrain receipt refuses");
        for (int x=0;x<n;++x) {
            expect(w.stored_material(20+x,20)==(x%2 ? Material::Rust : Material::Sand),"exact deterministic output map");
            expect(w.stored_state_a(20+x,20)==0 && w.stored_state_b(20+x,20)==0,"ordinary fresh granular state");
        }
        expect(w.finalize_workbench_crumble(s.token,w.hard_surface_revision())==SolidOutcome::Accepted,"current terrain admits native motion");
        expect(w.workbench_debris_ledger()==std::array<std::uint64_t,4>{1,static_cast<std::uint64_t>(n),static_cast<std::uint64_t>((n+1)/2),static_cast<std::uint64_t>(n/2)},"exact source/sink cell accounting");
        expect(w.crumble_workbench_solid(s.token)==SolidOutcome::Stale,"retry cannot replenish grains");
    }
    World w(config(workers)),control(config(workers));
    for (World* world:{&w,&control}) {
        world->reserve_region({0,0,128,128});
        for (int x=0;x<128;++x)world->set(x,60,Material::Wall);
        for (int y=20;y<24;++y)for(int x=20;x<24;++x)world->set(x,y,Material::RedBrick);
    }
    expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"law control configure");
    expect(w.prepare_workbench_solid(20,20,16)==SolidOutcome::Accepted,"law source");
    auto s=w.inspect_solid_detachment();
    expect(w.crumble_workbench_solid(s.token)==SolidOutcome::Accepted,"law conversion");
    expect(w.finalize_workbench_crumble(s.token,w.hard_surface_revision())==SolidOutcome::Accepted,"law terrain receipt");
    for (int y=20;y<24;++y)for(int x=20;x<24;++x)control.set(x,y,((y-20)*4+x-20)%2 ? Material::Rust : Material::Sand);
    expect(w.state_hash()==control.state_hash(),"ordinary material tuple initialization equivalence");
    for (int tick=0;tick<120;++tick) {
        (void)w.tick();(void)control.tick();
        expect(w.state_hash()==control.state_hash(),"identical existing granular evolution, no new law");
    }
    expect(w.stored_material(20,20)==Material::Empty,"small debris actually falls");
    unsigned sand=0,rust=0;
    for(int y=0;y<64;++y)for(int x=0;x<128;++x){sand+=w.stored_material(x,y)==Material::Sand;rust+=w.stored_material(x,y)==Material::Rust;}
    expect(sand==8 && rust==8,"fall/settling retains all generated pixels");
    w.set(80,20,Material::RedBrick);
    expect(w.prepare_workbench_solid(80,20,0)==SolidOutcome::Accepted && !w.inspect_solid_detachment().granular_piece,"disabled threshold retains rigid route");
    s=w.inspect_solid_detachment();expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"disabled control cancel");
    w.set(81,20,Material::Wall);expect(w.prepare_workbench_solid(80,20,16)==SolidOutcome::Anchored,"small anchored brick never crumbles");
    w.set(81,20,Material::Empty);w.set_temperature(80,20,201);
    expect(w.prepare_workbench_solid(80,20,16)==SolidOutcome::Thermal,"small hot brick refuses");
    w.set_temperature(80,20,200);w.set(81,20,Material::Wood);
    expect(w.prepare_workbench_solid(80,20,16)==SolidOutcome::Ineligible,"small foreign contact refuses");
    w.set(81,20,Material::Empty);
    expect(w.prepare_workbench_solid(80,20,16)==SolidOutcome::Accepted,"cancellable small source");
    s=w.inspect_solid_detachment();expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"precommit cancel");
    expect(w.stored_material(80,20)==Material::RedBrick,"cancel does not convert material");
}
