// Independent exhaustive prefix-sum oracle; candidate uses row-pair intersection.
static SolidShape rectangle_oracle(const std::array<bool,9>& cells) {
    int sums[4][4]{};
    for(int y=0;y<3;++y)for(int x=0;x<3;++x)
        sums[y+1][x+1]=sums[y][x+1]+sums[y+1][x]-sums[y][x]+(cells[static_cast<std::size_t>(y*3+x)]?1:0);
    SolidShape best{};
    for(int top=0;top<3;++top)for(int left=0;left<3;++left)
        for(int bottom=top+1;bottom<=3;++bottom)for(int right=left+1;right<=3;++right) {
            const int area=(bottom-top)*(right-left);
            if(sums[bottom][right]-sums[top][right]-sums[bottom][left]+sums[top][left]!=area)continue;
            const auto old=static_cast<int>(best.width)*best.height;
            const SolidShape c{20+left,20+top,static_cast<std::uint16_t>(right-left),static_cast<std::uint16_t>(bottom-top)};
            if(area>old || (area==old && (c.y<best.y || (c.y==best.y && (c.x<best.x ||
                (c.x==best.x && (c.width>best.width || (c.width==best.width && c.height>best.height))))))))best=c;
        }
    return best;
}
static void rectangle_core(unsigned workers) {
    World w(config(workers));
    const auto fresh=[&] {w.clear();w.reserve_region({0,0,128,128});
        expect(w.configure_workbench_solids({0,0,512,512})==SolidOutcome::Accepted,"rectangle core setup");};
    for(unsigned mask=1;mask<512;++mask) {
        fresh();std::array<bool,9> component{};std::vector<int> queue;
        for(int i=0;i<9;++i)if(mask&(1U<<i)){w.set(20+i%3,20+i/3,Material::RedBrick);if(queue.empty()){queue.push_back(i);component[static_cast<std::size_t>(i)]=true;}}
        const int first=queue[0];
        for(std::size_t i=0;i<queue.size();++i) {
            const int x=queue[i]%3,y=queue[i]/3;
            for(const auto d:std::array<std::array<int,2>,4>{{{{0,-1}},{{-1,0}},{{1,0}},{{0,1}}}}) {
                const int nx=x+d[0],ny=y+d[1];if(nx<0||ny<0||nx>=3||ny>=3)continue;
                const int n=ny*3+nx;if((mask&(1U<<n)) && !component[static_cast<std::size_t>(n)]) {
                    component[static_cast<std::size_t>(n)]=true;queue.push_back(n);
                }
            }
        }
        expect(w.prepare_workbench_solid(20+first%3,20+first/3,0,true)==SolidOutcome::Accepted,"explicit rough control accepted");
        const auto s=w.inspect_solid_detachment();const auto oracle=rectangle_oracle(component);
        std::array<SolidShape,kSolidShapes> shapes{};(void)w.copy_solid_detachment_shapes(shapes);
        expect(shapes[0].x==oracle.x && shapes[0].y==oracle.y && shapes[0].width==oracle.width && shapes[0].height==oracle.height,"independent rectangle oracle");
        expect(s.source_member_count==queue.size() && s.member_count==static_cast<std::size_t>(oracle.width)*oracle.height &&
            s.member_count+s.fringe_count==s.source_member_count && s.shape_count==1,"source/core/fringe partition");
        const double inertia=s.mass*(oracle.width*oracle.width+oracle.height*oracle.height)/12.;
        expect(std::abs(s.inertia-inertia)<1e-8 && s.mass==static_cast<double>(s.member_count),"core only unit mass/inertia");
        std::vector<SolidMember> core(s.member_count),fringe(s.fringe_count);
        (void)w.copy_solid_detachment_members(core);(void)w.copy_solid_detachment_fringe(fringe);
        if(mask%7==0) {
            expect(w.acknowledge_solid_detachment({s.token,1,2,s.payload_digest,s.shape_digest,1})==SolidOutcome::Accepted,"core reservation");
            expect(w.commit_solid_detachment(s.token)==SolidOutcome::Accepted,"atomic core/fringe mutation");
            for(const auto& m:core)expect(w.stored_material(m.x,m.y)==Material::Empty,"only core retired");
            for(const auto& m:fringe)expect(w.stored_material(m.x,m.y)==Material::Sand && w.stored_state_a(m.x,m.y)==0 && w.stored_state_b(m.x,m.y)==0,"fringe ordinary Sand");
            const auto revision=w.hard_surface_revision();
            expect(w.commit_solid_detachment(s.token)==SolidOutcome::Stale && w.hard_surface_revision()==revision,"duplicate is one-use");
            expect(w.rollback_solid_detachment(s.token)==SolidOutcome::Ineligible && w.hard_surface_revision()==revision,"no partial restoration");
            expect(w.finalize_solid_detachment({s.token,1,2,revision,2})==SolidOutcome::Accepted,"matching all-mutations terrain");
            expect(w.archive_workbench_solid(s.token)==SolidOutcome::Accepted,"core custody archive");
            expect(w.workbench_solid_record(0).aggregate_owned_count==s.member_count,"archive owns no fringe");
            expect(w.workbench_rectangle_core_ledger()==std::array<std::uint64_t,4>{1,s.source_member_count,s.member_count,s.fringe_count},"split ledger");
        } else {
            expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"rough cancellation");
            for(int i:queue)expect(w.stored_material(20+i%3,20+i/3)==Material::RedBrick,"cancel retains all source");
        }
    }
    fresh();
    for(int y=20;y<53;++y)for(int x=20;x<53;++x)if((y-20)%2==0 || (x-20)%2==0)w.set(x,y,Material::RedBrick);
    expect(w.prepare_workbench_solid(20,20)==SolidOutcome::ShapeCapacity,"exact capacity control");
    expect(w.prepare_workbench_solid(20,20,16,true)==SolidOutcome::Accepted,"rough selection before obsolete partition cap");
    auto s=w.inspect_solid_detachment();expect(s.source_member_count==833 && s.member_count==33 && s.fringe_count==800,"lattice counts");
    expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"lattice cancellation");
    fresh();for(int x=20;x<36;++x)w.set(x,20,Material::RedBrick);w.set(20,21,Material::RedBrick);
    expect(w.prepare_workbench_solid(20,20,16,true)==SolidOutcome::Accepted,"17-source L");
    s=w.inspect_solid_detachment();expect(s.source_member_count==17 && s.member_count==16 && s.rectangle_core && !s.granular_piece,"threshold uses original source");
    expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"17-source cancellation");w.set(20,21,Material::Empty);
    expect(w.prepare_workbench_solid(20,20,16,true)==SolidOutcome::Accepted && w.inspect_solid_detachment().granular_piece,"16-source crumble unchanged");
    expect(w.cancel_solid_detachment(w.inspect_solid_detachment().token)==SolidOutcome::Accepted,"small cancellation");
    fresh();
    const auto fill=[&](int x,int y,int width,int height,Material m) {for(int yy=y;yy<y+height;++yy)for(int xx=x;xx<x+width;++xx)w.set(xx,yy,m);};
    fill(0,72,128,4,Material::Wall);fill(50,40,4,32,Material::RedBrick);fill(44,27,29,13,Material::RedBrick);fill(54,40,11,4,Material::RedBrick);w.set(60,32,Material::Empty);fill(50,65,4,2,Material::Empty);
    w.set(73,27,Material::Wall);expect(w.prepare_workbench_solid(51,64,16,true)==SolidOutcome::Anchored,"discarded-tail anchor binds");w.set(73,27,Material::Empty);
    w.set_temperature(72,27,201);expect(w.prepare_workbench_solid(51,64,16,true)==SolidOutcome::Thermal,"hot fringe refuses");w.set_temperature(72,27,200);
    w.set(73,27,Material::Wood);expect(w.prepare_workbench_solid(51,64,16,true)==SolidOutcome::Ineligible,"foreign fringe refuses");w.set(73,27,Material::Empty);
    w.configure_transient_obstacles({0,0,128,128});expect(w.set_transient_obstacle(72,27,1),"fringe mask");
    expect(w.prepare_workbench_solid(51,64,16,true)==SolidOutcome::Occupied,"masked fringe refuses");w.clear_transient_obstacles();
    expect(w.prepare_workbench_solid(51,64,16,true)==SolidOutcome::Accepted,"actual cut tree");
    s=w.inspect_solid_detachment();expect(s.source_member_count==520 && s.member_count==208 && s.fringe_count==312 && std::abs(s.inertia-22100./3)<1e-8,"independent tree expected core");
    const auto digest=s.payload_digest;expect(w.cancel_solid_detachment(s.token)==SolidOutcome::Accepted,"tree cancellation");
    expect(w.prepare_workbench_solid(72,27,16,true)==SolidOutcome::Accepted && w.inspect_solid_detachment().payload_digest==digest,"seed independent selection/digest");
}
