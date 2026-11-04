#include "penetration_corridor.hpp"

#include <chrono>
#include <iomanip>
#include <iostream>
#include <memory>
#include <string>
#include <vector>

namespace p = sol364b;
static void number(double value) {
    if (std::isfinite(value)) std::cout << value;
    else std::cout << "null";
}
static void witness(const p::Witness& value) {
    if (!value.present) { std::cout << "null";return; }
    std::cout << "{\"proxy\":" << value.proxy << ",\"cell\":[" << value.x << ',' << value.y
        << "],\"material\":" << value.material << ",\"interval_begin\":";
    number(value.begin);
    std::cout << ",\"interval_end\":";number(value.end);
    std::cout << ",\"depth\":";number(value.depth);std::cout << '}';
}
int main() {
    try {
        std::string schema;
        std::int32_t width=0,height=0,x=0,y=0;
        std::size_t shape_count=0;
        p::Pose pose;
        double remaining=0.0;
        if (!(std::cin>>schema) || schema!="SOL364B_CORRIDOR_V1" ||
            !(std::cin>>x>>y>>width>>height>>shape_count) ||
            width<=0 || height<=0 || width>1024 || height>1024 || shape_count==0 || shape_count>p::max_proxies ||
            !(std::cin>>pose.origin.x>>pose.origin.y>>pose.source_com.x>>pose.source_com.y>>pose.angle>>remaining)) {
            std::cerr << "Invalid or incomplete corridor input header\n";return 2;
        }
        std::vector<p::SourceShape> shapes(shape_count);
        for (auto& shape:shapes) if (!(std::cin>>shape.x>>shape.y>>shape.width>>shape.height)) {
            std::cerr << "Incomplete source partition\n";return 2;
        }
        std::vector<std::uint16_t> cells(static_cast<std::size_t>(width)*height);
        for (auto& cell:cells) {
            std::uint32_t material=0;
            if (!(std::cin>>material) || material>65535) { std::cerr<<"Invalid material field\n";return 2; }
            cell=static_cast<std::uint16_t>(material);
        }
        std::string trailing;
        if (std::cin>>trailing) { std::cerr<<"Trailing unbound input\n";return 2; }
        auto scratch=std::make_unique<p::Workspace>();
        const auto start=std::chrono::steady_clock::now();
        const auto result=p::analyze(shapes,pose,{x,y,width,height,cells},*scratch,remaining);
        const double elapsed=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
        std::cout<<std::setprecision(17)
            <<"{\"schema\":\"cybersand.sol364b.corridor-geometry.v1\",\"live_authority\":false,"
              "\"application_count\":0,\"position_work_applied\":0,\"kinetic_change_applied\":0,"
              "\"potential_change_applied\":0,\"introduced_energy_spent_applied\":0,"
              "\"outcome\":\""<<result.outcome<<"\",\"remaining_distance\":"<<remaining
            <<",\"geometry_probes\":"<<result.geometry_probes<<",\"pair_count\":"<<result.pair_count
            <<",\"initial_pairs\":"<<result.initial_pairs<<",\"initial_sand_pairs\":"<<result.initial_sand_pairs
            <<",\"excluded_initial_pairs\":"<<result.excluded_initial_pairs
            <<",\"initial_area\":"<<result.initial_area<<",\"initial_sand_area\":"<<result.initial_sand_area
            <<",\"initial_excluded_area\":"<<result.initial_excluded_area
            <<",\"initial_maximum_depth\":"<<result.initial_maximum_depth
            <<",\"geometric_routes\":"<<result.geometric_routes<<",\"selected_direction\":";
        if (result.selected_direction<p::max_directions) std::cout<<result.selected_direction;else std::cout<<"null";
        std::cout<<",\"first_excluded\":";witness(result.first_excluded);
        std::cout<<",\"workspace_bytes\":"<<sizeof(p::Workspace)<<",\"elapsed_ms\":"<<elapsed
            <<",\"timing_scope\":\"offline diagnostic query wall interval; not registered live contact CPU\",\"directions\":[";
        for (std::size_t i=0;i<result.direction_count;++i) {
            const auto& d=result.directions[i];
            if (i!=0) std::cout<<',';
            std::cout<<"{\"direction\":["<<d.direction.x<<','<<d.direction.y<<"],\"outcome\":\""<<d.outcome
                <<"\",\"geometric_route\":"<<(d.geometric_route?"true":"false")<<",\"required_distance\":";
            number(d.required_distance);
            std::cout<<",\"maximum_swept_depth_within_admitted_budget\":"<<d.maximum_swept_depth
                <<",\"new_pairs_within_budget\":"<<d.new_pairs_within_budget<<",\"required_by\":";
            witness(d.required_by);std::cout<<",\"first_new_pair\":";witness(d.first_new_pair);
            std::cout<<",\"deepest_pair\":";witness(d.deepest_pair);std::cout<<'}';
        }
        std::cout<<"]}\n";
    } catch (const std::exception& error) { std::cerr<<error.what()<<'\n';return 2; }
    return 0;
}
