#include "penetration_corridor.hpp"

#include <array>
#include <cmath>
#include <iostream>
#include <limits>
#include <memory>
#include <numbers>
#include <stdexcept>
#include <string_view>
#include <vector>

namespace p = sol364b;
static std::size_t checks=0, groups=0;
static void expect(bool condition,const char* message) {
    ++checks;if (!condition) throw std::runtime_error(message);
}
static void near(double actual,double expected,double tolerance,const char* message) {
    expect(std::isfinite(actual)&&std::abs(actual-expected)<=tolerance,message);
}
struct Fixture {
    std::vector<std::uint16_t> cells=std::vector<std::uint16_t>(64*64,0);
    std::vector<p::SourceShape> shapes{{20,20,2,2}};
    p::Pose pose{{21,20.75},{21,21},0.0};
    std::unique_ptr<p::Workspace> scratch=std::make_unique<p::Workspace>();
    p::Result run(double remaining=p::maximum_distance) {
        return p::analyze(shapes,pose,{0,0,64,64,cells},*scratch,remaining);
    }
    void cell(int x,int y,std::uint16_t value) { cells[static_cast<std::size_t>(y)*64+x]=value; }
};

static p::Pair axis_pair(double x,double y,double hx,double hy) {
    p::Pair pair;
    pair.center={x,y,x,y};pair.radius={hx,hy,hx,hy};return pair;
}
static void analytic_continuous_geometry() {
    const auto basis=p::axes(0.0);
    const auto pair=axis_pair(3.0,0.0,1.0,1.0);
    const auto sweep=p::interval(pair,basis,{1.0,0.0});
    near(sweep.begin,2.0,0.0,"continuous obstacle entry is exact");
    near(sweep.end,4.0,0.0,"continuous obstacle exit is exact");
    near(p::depth(pair,basis,{1.0,0.0},0.0),0.0,0.0,"start is clear");
    near(p::depth(pair,basis,{1.0,0.0},5.0),0.0,0.0,"end is clear");
    near(p::maximum_depth(pair,basis,{1.0,0.0},5.0),1.0,0.0,"interior obstacle cannot hide between clear endpoints");
    auto touching=axis_pair(1.0,1.0,1.0,1.0);
    expect(!p::interval(touching,basis,{1.0,0.0}).present,"a parallel touching axis never becomes positive area");
    auto contained=axis_pair(0.25,0.0,2.5,3.5);
    near(p::depth(contained,basis,{1,0},0),2.25,0.0,"containment depth uses exit distance");
    near(p::maximum_depth(contained,basis,{1,0},1),2.5,0.0,"continuous depth maximum occurs at interior containment center");
    auto oblique=axis_pair(0.75,0.0,1.0,1.0);
    const auto margin=p::interval(oblique,basis,{-0.5,std::sqrt(0.75)},p::clearance);
    const double stop=margin.end;
    double gap=-1e10;
    for (std::size_t a=0;a<4;++a)
        gap=std::max(gap,std::abs(oblique.center[a]-p::dot({-0.5,std::sqrt(0.75)},basis[a])*stop)-oblique.radius[a]);
    near(gap,p::clearance,2e-15,"oblique margin is projected rather than added directly to travel");
    ++groups;
}

static void exact_partition_and_unique_route() {
    Fixture f;f.cell(20,21,p::sand);
    auto result=f.run();
    expect(std::string_view(result.outcome)=="GeometryOnlyUniqueCorridor","asymmetric shallow overlap has a unique geometric corridor");
    expect(result.direction_count==4,"collinear world/body directions are deduplicated");
    const auto& route=result.directions[result.selected_direction];
    near(route.direction.x,0.0,0.0,"unique route has no arbitrary lateral correction");
    near(route.direction.y,-1.0,0.0,"shortest witnessed exit is upward in this authored positive control");
    near(route.required_distance,0.75002,1e-8,"whole square must clear at the registered margin");
    expect(route.maximum_swept_depth<=result.initial_maximum_depth,"accepted path does not deepen this contact");
    f.pose={{20.5,20.5},{21,21},0.0};f.cells.assign(64*64,0);f.cell(20,20,p::sand);
    result=f.run();
    expect(std::string_view(result.outcome)=="AmbiguousShortestCorridor","symmetric interior ties do not invent an outward normal");
    f.pose.origin.x+=0.000001;
    expect(std::string_view(f.run().outcome)=="AmbiguousShortestCorridor","sub-tolerance near ties cannot manufacture a normal from roundoff");
    f.shapes.push_back({21,20,2,2});
    expect(std::string_view(f.run().outcome)=="OverlappingSiblings","overlapping source proxies refuse before path search");
    f.shapes={{20,20,2,2},{22,20,2,2}};
    result=f.run();
    expect(std::string_view(result.outcome)!="OverlappingSiblings","a true shared seam is not filled or rejected as overlap");
    ++groups;
}

static void holes_and_new_pairs() {
    Fixture f;
    // Four disjoint bars surround an actual empty 2x2 hole. Native material in
    // that hole is not an initial overlap and must not become a recovery target.
    f.shapes={{20,20,6,2},{20,24,6,2},{20,22,2,2},{24,22,2,2}};
    f.pose={{23,23},{23,23},0};f.cell(22,22,p::sand);
    expect(std::string_view(f.run().outcome)=="NoInitialPenetration","hole remains empty aggregate geometry");
    f.cell(20,20,p::sand);
    auto r=f.run();
    expect(r.initial_pairs==1,"the hole cell is not counted through a filled hull");
    bool blocked=false;
    for (std::size_t i=0;i<r.direction_count;++i) blocked=blocked||r.directions[i].new_pairs_within_budget>0;
    expect(blocked,"moving a sibling bar into an initially empty hole pair is detected continuously");
    // Endpoint-only translation would miss the cell at x25 on a long rightward
    // sweep. It was not in contact with the starting proxy.
    Fixture g;g.cell(20,21,p::sand);g.cell(25,20,p::sand);
    auto q=g.run();
    expect(q.directions[0].new_pairs_within_budget>0,"previously clear forward cell appears in continuous sweep witness");
    expect(q.directions[0].first_new_pair.present,"new-pair counter retains an actual cell/proxy witness");
    ++groups;
}

static void exclusions_and_bounds() {
    for (const auto material : {std::uint16_t(1),std::uint16_t(3),p::thermal}) {
        Fixture f;f.cell(20,21,material);
        auto r=f.run();
        expect(std::string_view(r.outcome)=="InitialExcludedOverlap","hard Water and thermal initial overlap refuse");
        expect(r.excluded_initial_pairs>0&&r.first_excluded.present,"excluded topology retains positive-area witness");
        for (std::size_t i=0;i<r.direction_count;++i) expect(!r.directions[i].geometric_route,"exclusion cannot be ignored by another direction");
    }
    Fixture f;f.cell(20,21,p::sand);f.cell(18,19,p::unknown);
    expect(std::string_view(f.run().outcome)=="UnknownResidency","missing native coverage refuses complete corridor");
    f.cell(18,19,p::foreign);
    expect(std::string_view(f.run().outcome)=="ForeignBodyOrMask","foreign owner witness refuses");
    f.cell(18,19,0);
    expect(std::string_view(f.run(0.5).outcome)=="NoRegisteredCorridor","required clearance exceeding remaining lifetime budget refuses");
    expect(std::string_view(f.run(0).outcome)=="DistanceBudgetExhausted","zero remaining distance cannot refill a budget");
    f.pose.origin.x=1.0;
    expect(std::string_view(f.run().outcome)=="UnknownBoundary","sweep beyond complete field coverage refuses");
    f.pose.origin.x=std::numeric_limits<double>::infinity();
    expect(std::string_view(f.run().outcome)=="InvalidInput","nonfinite geometry refuses");
    f.pose.origin={32,32};f.pose.source_com={32,32};
    f.shapes={{8,8,48,24},{8,32,48,24},{8,56,48,1}};
    auto r=f.run();
    // Use a larger fully known field so capacity, rather than boundary, is the
    // reason the three disjoint large strips cannot enter this query.
    std::vector<std::uint16_t> larger(128*128,0);
    f.shapes={{24,24,64,20},{24,44,64,20},{24,64,64,20},{24,84,64,20}};
    r=p::analyze(f.shapes,{{56,60},{56,60},0},{0,0,128,128,larger},*f.scratch);
    expect(std::string_view(r.outcome)=="GeometryCapacity","whole broadphase capacity refuses without truncated records");
    Fixture no_vacancy;
    for (int y=12;y<32;++y) for (int x=12;x<32;++x) no_vacancy.cell(x,y,p::sand);
    r=no_vacancy.run();
    expect(std::string_view(r.outcome)=="NoRegisteredCorridor"&&r.geometric_routes==0,
           "a complete no-vacancy Sand wall cannot be cleared by tunnelling through new cells");
    ++groups;
}

static void continuous_depth_adversary() {
    // Neither endpoint is the maximum: a translation that first moves towards
    // a contained cell and then away must pay the intermediate depth increase.
    const auto pair=axis_pair(1.2,0.0,2.5,4.0);
    const auto basis=p::axes(0.0);
    const double start=p::depth(pair,basis,{1,0},0);
    const double finish=p::depth(pair,basis,{1,0},3.8);
    const double maximum=p::maximum_depth(pair,basis,{1,0},3.8);
    expect(finish==0.0&&maximum>start+p::additional_depth,"end clearance cannot hide a violation of registered depth growth");
    // Independent dense samples provide a lower bound for the analytic maximum
    // across rotated directions. They do not replace the exact interval check.
    for (int angle_step=0;angle_step<11;++angle_step) {
        const double angle=0.137*angle_step;
        const auto rotated=p::axes(angle);
        p::Pair q;
        const p::Vec offset{0.37,-0.23};
        for (std::size_t a=0;a<4;++a) {
            q.center[a]=p::dot(offset,rotated[a]);
            q.radius[a]=1.1*std::abs(p::dot(rotated[2],rotated[a]))+
                0.7*std::abs(p::dot(rotated[3],rotated[a]))+0.5*(std::abs(rotated[a].x)+std::abs(rotated[a].y));
        }
        for (auto direction : rotated) {
            double sampled=0.0;
            for (int i=0;i<=400;++i) sampled=std::max(sampled,p::depth(q,rotated,direction,i/100.0));
            const double exact=p::maximum_depth(q,rotated,direction,4.0);
            expect(exact+1e-12>=sampled&&exact<=sampled+0.02,"continuous depth envelope bounds independent dense samples");
        }
    }
    ++groups;
}

static void proposed_work_budget() {
    const double mass=520,full=mass*p::repair_acceleration*p::maximum_distance;
    auto receipt=p::account(mass,{0,p::repair_acceleration},{0,-0.125},0,0,4,full,0);
    expect(receipt.admissible,"bounded upward control accounts introduced reservoir work");
    near(receipt.potential_change,mass*p::repair_acceleration*0.125,1e-9,"upward potential increase has the correct sign");
    near(receipt.residual_dissipation,0,1e-9,"aligned gravity accounts all charged work as potential");
    receipt=p::account(mass,{0,0},{0,-0.125},0,0,4,full,0);
    expect(receipt.admissible&&receipt.introduced_energy_spent>0&&receipt.residual_dissipation>0,
           "zero gravity projection still spends explicit introduced repair energy");
    receipt=p::account(mass,{0,p::repair_acceleration},{0,0.125},0,0,4,full,0);
    expect(receipt.admissible&&receipt.potential_change<0&&receipt.residual_dissipation>receipt.introduced_energy_spent,
           "downward potential loss is separately accounted");
    expect(!p::account(mass,{0,0},{0,0.25},0,0,4,full,0).admissible,"step above registered half-drift bound refuses");
    expect(!p::account(mass,{0,0},{0,0.125},0,0,4,full,32).admissible,"correction count cannot replay beyond lifetime cap");
    expect(!p::account(mass,{0,0},{0,0.125},0,0,4,0,0).admissible,"energy reservoir cannot silently refill");
    expect(!p::account(mass,{0,100},{0,0.125},0,0,4,full,0).admissible,"unregistered gravity magnitude refuses");
    expect(!p::account(mass,{0,0},{0,0.125},0,1,4,full,0).admissible,"kinetic injection does not disappear in reservoir accounting");
    expect(!p::account(mass,{0,0},{0,0.125},0,std::numeric_limits<double>::quiet_NaN(),4,full,0).admissible,
           "nonfinite readback cannot bypass mechanical accounting");
    expect(!p::account(5e305,{0,0},{0.125,0},0,0,4,1e308,0).admissible,
           "a finite mass cannot hide an overflowing registered reservoir cap");
    double distance=4,energy=full;
    for (std::size_t i=0;i<32;++i) {
        auto r=p::account(mass,{0,0},{0,-0.125},0,0,distance,energy,i);
        expect(r.admissible,"every admitted step spends the same finite lifetime budgets");
        distance=r.remaining_distance;energy=r.remaining_energy;
    }
    near(distance,0,1e-12,"32 steps exhaust exactly four cells");
    near(energy,0,1e-7,"32 steps exhaust the explicitly introduced energy");
    expect(!p::account(mass,{0,0},{0,-0.125},0,0,distance,energy,32).admissible,"a further correction cannot replay the exhausted budget");
    ++groups;
}

int main() {
    try {
        analytic_continuous_geometry();exact_partition_and_unique_route();holes_and_new_pairs();
        exclusions_and_bounds();continuous_depth_adversary();proposed_work_budget();
    } catch (const std::exception& error) {
        std::cerr<<"SOL364B_CORRIDOR_TEST_FAILURE "<<error.what()<<" after "<<checks<<" checks\n";return 1;
    }
    std::cout<<"{\"schema\":\"cybersand.sol364b.corridor-native-tests.v1\",\"groups\":"<<groups
        <<",\"checks\":"<<checks<<",\"failures\":0,\"live_application\":false}\n";
    return 0;
}
