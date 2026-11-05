// Appended to the authenticated original value-driver declaration/export seam.
template<class T,std::size_t N>
static void values_json(std::ostream& out,const std::array<T,N>& values,std::size_t count) {
    out<<'[';for(std::size_t i=0;i<count;++i){if(i)out<<',';out<<values[i];}out<<']';
}
static std::string trace_json(const g::CompoundWorkspace& workspace) {
    std::ostringstream out;out<<std::setprecision(17)<<std::boolalpha<<'[';
#if SOL_ACTIVE_ARM != 0
    for(std::size_t i=0;i<workspace.trace_batches;++i) {
        if(i){out<<',';}
        const auto& t=workspace.trace[i];
        out<<"{\"pass\":"<<t.pass<<",\"axis\":"<<t.axis<<",\"before\":";vector_json(out,t.before);
        out<<",\"after\":";vector_json(out,t.after);
        out<<",\"omega_before\":"<<t.omega_before<<",\"omega_after\":"<<t.omega_after;
        out<<",\"energy_before\":"<<t.energy_before<<",\"energy_after\":"<<t.energy_after;
        out<<",\"active_weight\":"<<t.active_weight<<",\"active_count\":"<<t.active_count;
        out<<",\"nodes\":"<<t.nodes<<",\"snapshots\":"<<t.snapshots;
        out<<",\"normal_unwinds\":"<<t.normal_unwinds<<",\"tangent_unwinds\":"<<t.tangent_unwinds<<",\"shrunk_cones\":"<<t.shrunk_cones;
        out<<",\"normal_caps\":"<<t.normal_caps<<",\"tangent_caps\":"<<t.tangent_caps;
        out<<",\"jn_before\":";values_json(out,t.jn_before,t.snapshots);
        out<<",\"jn_after\":";values_json(out,t.jn_after,t.snapshots);
        out<<",\"jt_before\":";values_json(out,t.jt_before,t.snapshots);
        out<<",\"jt_after\":";values_json(out,t.jt_after,t.snapshots);
        out<<",\"weight_used\":";values_json(out,t.weight_used,t.snapshots);
        out<<",\"active\":";values_json(out,t.active,t.snapshots);out<<'}';
    }
#else
    (void)workspace;
#endif
    return out.str()+']';
}

int main(int argc,char** argv) {
    if(argc!=2)return 2;
    std::ifstream input(argv[1]);unsigned count_cases=0;
    if(!(input>>count_cases) || count_cases!=38)return 3;
    std::vector<Case> cases;
    for(unsigned index=0;index<count_cases;++index) {
        Case c;unsigned bin_count=0,mode=0;
        if(!(input>>c.id>>c.body.velocity.x>>c.body.velocity.y>>c.body.com.x>>c.body.com.y>>c.body.omega>>c.body.mass>>c.body.inertia>>c.body.mu>>c.available>>c.scale>>c.budget>>mode>>bin_count))return 4;
        if(bin_count>513 || mode>1)return 5;
        c.null_bin=mode==1;
        for(unsigned bin_index=0;bin_index<bin_count;++bin_index) {
            unsigned points=0;g::Vec normal;g::Bin bin;
            if(!(input>>points>>normal.x>>normal.y) || points>1024)return 6;
            for(unsigned point_index=0;point_index<points;++point_index) {
                g::Vec point;if(!(input>>point.x>>point.y))return 7;
                bin.add(point,normal,c.body.com);
            }
            c.bins.push_back(bin);
        }
        cases.push_back(c);
    }
    const auto poison=std::find_if(cases.begin(),cases.end(),[](const Case& c){return c.id=="max-two-nodes";});
    if(poison==cases.end())return 8;
    std::cout<<"{\"registration\":\"SOL-ACTIVE-NORMAL-001\",\"cases\":[";
    bool first=true;std::size_t equal=0;
    for(const auto& c:cases) {
        const auto pointers=c.pointers();g::CompoundWorkspace fresh{},second{},reused{};
        const auto result=g::solve_compound(c.body,pointers,fresh,c.available,c.scale,c.budget);
        const auto one=encode(c,result,fresh),trace=trace_json(fresh);
        const auto other=g::solve_compound(c.body,pointers,second,c.available,c.scale,c.budget);
        const auto prior=poison->pointers();g::solve_compound(poison->body,prior,reused,poison->available,poison->scale,poison->budget);
        const auto repeated=g::solve_compound(c.body,pointers,reused,c.available,c.scale,c.budget);
        const bool same=one==encode(c,other,second) && one==encode(c,repeated,reused) && trace==trace_json(second) && trace==trace_json(reused);
        equal+=same?1U:0U;
        if(!first)std::cout<<',';
        first=false;
        std::cout<<"{\"id\":\""<<c.id<<"\",\"replays_equal\":"<<(same?"true":"false")<<",\"observation\":"<<one<<",\"trace\":"<<trace<<'}';
    }
    std::cout<<"],\"replay_equal_cases\":"<<equal<<"}\n";
    return equal==cases.size()?0:9;
}
