#pragma once
namespace fixture {
inline void input(cybersand::World& world,unsigned tick,std::int64_t x,std::int64_t y,cybersand::Material material,std::ostream& out) {
    const auto before=cybersand::PrecisionProbe::raw_at(world,x,y);const auto temperature=world.temperature(x,y);
    const auto epoch=cybersand::PrecisionProbe::epoch(world);world.set(x,y,material);
    out<<tick<<' '<<x<<' '<<y<<' '<<unsigned(material)<<' '<<unsigned(epoch)<<' ';
    constexpr char h[]="0123456789abcdef";for(auto b:before)out<<h[b>>4]<<h[b&15];out<<' ';
    for(auto b:cybersand::PrecisionProbe::raw_at(world,x,y))out<<h[b>>4]<<h[b&15];
    out<<' '<<temperature<<' '<<world.temperature(x,y)<<'\n';
}
inline void operations(cybersand::World& world,const std::filesystem::path& path) {
    using namespace cybersand;
    std::ofstream out(path);
    const auto hex=[&](const auto& bytes){constexpr char h[]="0123456789abcdef";for(auto b:bytes)out<<h[b>>4]<<h[b&15];};
    const auto observe=[&](const char* kind,std::int64_t x,std::int64_t y,std::int64_t tx,std::int64_t ty,unsigned value,const auto& action){
        const auto a=PrecisionProbe::raw_at(world,x,y),b=PrecisionProbe::raw_at(world,tx,ty);
        const auto ta=world.temperature(x,y),tb=world.temperature(tx,ty);action();
        out<<kind<<' '<<x<<' '<<y<<' '<<tx<<' '<<ty<<' '<<value<<' ';hex(a);out<<' ';hex(b);out<<' ';
        hex(PrecisionProbe::raw_at(world,x,y));out<<' ';hex(PrecisionProbe::raw_at(world,tx,ty));
        out<<' '<<ta<<' '<<tb<<' '<<world.temperature(x,y)<<' '<<world.temperature(tx,ty)<<'\n';
    };
    world.reserve_temperature_region({0,0,256,256});
    world.set(126,24,Material::Sand);world.set_temperature(126,24,777);
    (void)PrecisionProbe::neutral_admit(world,126,24,0x7f00);PrecisionProbe::seed_unused(world,126,24);
    observe("move",126,24,128,24,0,[&]{PrecisionProbe::move(world,126,24,128,24,false);});
    world.set(129,24,Material::Wood);(void)PrecisionProbe::neutral_admit(world,129,24,0x8001);
    observe("swap",128,24,129,24,0,[&]{PrecisionProbe::move(world,128,24,129,24,true);});
    require(world.set_cell_state(60,60,Material::Water,173,7)&&world.set_cell_state(61,60,Material::Water,20,2),"transfer fixture setup");
    (void)PrecisionProbe::neutral_admit(world,60,60,128);(void)PrecisionProbe::neutral_admit(world,61,60,129);
    observe("partial",60,60,61,60,50,[&]{require(PrecisionProbe::transfer(world,60,60,61,60,50)==50,"partial transfer amount");});
    observe("drain",60,60,61,60,123,[&]{require(PrecisionProbe::transfer(world,60,60,61,60,255)==123,"draining transfer amount");});
    require(world.set_cell_state(62,60,Material::Empty,17,29),"nonzero Empty transfer fixture");
    (void)PrecisionProbe::neutral_admit(world,62,60,131);
    observe("new-water",61,60,62,60,50,[&]{require(PrecisionProbe::transfer(world,61,60,62,60,50)==50,"Empty destination transfer amount");});
    observe("replace",61,60,61,60,0,[&]{world.set(61,60,Material::Wall);});
    require(bool(out),"lifecycle operation evidence failed");
}
inline void quarantine(const std::filesystem::path& root) {
    using namespace cybersand;
    mat003_correctness::trace_enabled=false;
    WorldConfig config;config.active_core_capacity=1;config.active_chunk_capacity=4;
    config.maximum_chunk_count=4;config.initial_chunk_reserve=4;config.physics_diagnostics.enabled=true;
    World world(config);world.set(20,20,Material::Sand);auto stats=world.tick();
    world.set(20,20,Material::Wall);world.set(21,20,Material::Wall);world.set(160,20,Material::Sand);
    require(world.queue_explosion(20,20,1,0),"failure setup event refused");
    PrecisionProbe::prepare_clear(world,(std::uint64_t{1}<<MAT003_EPOCH_BITS)-1);
    bool threw=false;try{(void)world.tick();}catch(const std::runtime_error&){threw=true;}
    require(threw&&world.has_failed()&&world.tick_index()==2&&world.completed_tick_index()==1,"expected genuine failed tick/quarantine");
    PrecisionProbe::canonical_endpoint(world,stats,root/"failed-before");
    std::ofstream attempts(root/"attempts.txt",std::ios::app);
    const auto emit=[&](const auto& bytes){constexpr char h[]="0123456789abcdef";for(auto b:bytes)attempts<<h[b>>4]<<h[b&15];};
    for(unsigned i=224;i<256;++i){const unsigned kind=7+(i-224)%8;bool accepted=false;const auto before=PrecisionProbe::raw_at(world,20,20);
        PrecisionProbe::canonical_endpoint(world,stats,root/("attempt-"+std::to_string(i)+"-pre"),true);
        try{
            switch(kind){
            case 7:(void)world.tick();accepted=true;break;
            case 8:accepted=world.set_cell_state(40,20,Material::Water,255,0);break;
            case 9:accepted=world.relocate_stored_cell(160,20,161,20);break;
            case 10:accepted=world.queue_explosion(20,20,1,0);break;
            case 11:world.set_temperature(40,20,777);accepted=true;break;
            case 12:world.set(40,20,Material::Sand);accepted=true;break;
            case 13:accepted=PrecisionProbe::neutral_admit(world,20,20,1);break;
            case 14:{WorldConfig invalid;invalid.maximum_chunk_count=0;invalid.initial_chunk_reserve=0;World rejected(invalid);accepted=true;break;}
            }
        }catch(const std::logic_error&){}
        const auto after=PrecisionProbe::raw_at(world,20,20);
        PrecisionProbe::canonical_endpoint(world,stats,root/("attempt-"+std::to_string(i)+"-post"),true);
        attempts<<i<<' '<<kind<<' '<<accepted<<' ';emit(before);attempts<<' ';emit(after);attempts<<'\n';
        require(!accepted&&before==after,"quarantine/construction refusal violated");
    }
    PrecisionProbe::canonical_endpoint(world,stats,root/"failed-after");
    world.clear();mat003_world::reset_dispatch_observations();world.set(20,20,Material::Sand);stats=world.tick();
    require(stats.tick==1&&world.get(20,21)==Material::Sand,"clear/reentry recovery failed");
    PrecisionProbe::canonical_endpoint(world,stats,root/"recovered");
    require(bool(attempts),"lifecycle attempt output failure");
}
}
