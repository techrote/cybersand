#include "cybersand/granular_contact_response.hpp"

namespace {
void gcr_require(bool value, const char* message) {
    if (!value) throw std::runtime_error(message);
}
bool gcr_near(double a,double b,double tolerance=1e-10) {
    return std::abs(a-b)<=tolerance*std::max({1.,std::abs(a),std::abs(b)});
}
void test_gcr_analytic_wrench() {
    using namespace cybersand::gcr;
    Body body; body.mass=2; body.inertia=4; body.velocity={0,1};
    std::array<Bin,8> bins{};
    bins[0].add({1,0},{0,-1},body.com);
    const auto result=solve(body,bins);
    // Independent scalar oracle: 1/(1/m + (r cross n)^2/I).
    const double impulse=1./(.5+.25);
    gcr_require(gcr_near(result.impulse.y,-impulse) && gcr_near(result.torque,-impulse),
                "GCR one-contact effective mass or moment differs from analytic oracle");
    gcr_require(result.tangent==0 && !result.passive_rejected && result.energy_after<result.energy_before,
                "GCR frictionless normal contact did not dissipate");
    bins={}; bins[0].add({-1,0},{0,-1},body.com);
    const auto mirror=solve(body,bins);
    gcr_require(gcr_near(mirror.impulse.y,result.impulse.y) && gcr_near(mirror.torque,-result.torque),
                "GCR mirrored normal contact did not reverse torque");
    body.velocity={0,-1};
    const auto separating=solve(body,bins);
    gcr_require(length(separating.impulse)==0 && separating.torque==0,
                "GCR separating contact attracted body");
    body.velocity={0,0}; body.omega=1;
    bins={}; bins[0].add({1,0},{0,-1},body.com);
    const auto angular=solve(body,bins);
    gcr_require(angular.normal>0 && angular.torque<0,
                "GCR ignored angular contact-point closing velocity");
    // At Y1 coefficient1, gravity+max(v-g,0) is >=v for v>=0;
    // min(arrest,yield,capacity) therefore equals min(m*max(v,0),capacity).
    for (const double mass:{.5,1.,2.}) for (const double speed:{-1.,0.,.2,1.5,4.,90.}) {
        const double gravity=92./60.;
        const double old=std::max(0.,std::min({mass*speed,mass*(gravity+std::max(0.,speed-gravity)),20.}));
        gcr_require(gcr_near(old,std::min(mass*std::max(speed,0.),20.)),"Y1 coefficient1 simplification failed");
    }
}

void test_gcr_friction_symmetry_and_budget() {
    using namespace cybersand::gcr;
    Body body; body.velocity={6,10}; body.inertia=4; body.mu=.78;
    std::array<Bin,8> bins{};
    for (int i=0;i<20;++i) {
        bins[4].add({-1,1},{0,-1},body.com);
        bins[5].add({1,1},{0,-1},body.com);
    }
    const auto result=solve(body,bins);
    gcr_require(result.tangent>0 && result.tangent_impulse.x<0,"GCR friction did not oppose slip");
    gcr_require(result.normal<=20+1e-10 && result.tangent<=body.mu*result.normal+1e-10,
                "GCR normal/tangent capacity exceeded");
    gcr_require(length(result.impulse)<=20*std::sqrt(1+body.mu*body.mu)+1e-10 &&
                std::abs(result.torque)<=20*std::sqrt(1+body.mu*body.mu)*std::sqrt(2.)+1e-10,
                "GCR wrench exceeded common linear/angular bound");
    gcr_require(result.energy_after<=result.energy_before+1e-6 && result.updates==2*2*4,
                "GCR passivity/work bound failed");
    body.velocity={0,10};
    const auto symmetric=solve(body,bins);
    gcr_require(symmetric.torque==0 && symmetric.impulse.x==0,
                "GCR symmetric flat support introduced turning bias");
    body.mu=0; body.velocity={6,10};
    const auto zero_mu=solve(body,bins);
    gcr_require(zero_mu.tangent==0 && zero_mu.impulse.x==0,"GCR zero-mu ablation retained friction");
    const auto exhausted=solve(body,bins,0);
    gcr_require(length(exhausted.impulse)==0 && exhausted.torque==0,"GCR zero shared capacity leaked response");
    // Fill all8 bins and stress speed/inertia/mu without changing coefficients.
    for (int i=0;i<8;++i) bins[static_cast<std::size_t>(i)].add({double(i)-3.,1},{0,-1},body.com);
    for (const double inertia:{.01,1.,100.}) for(const double mu:{0.,.78,16.}) {
        body.inertia=inertia; body.mu=mu; body.velocity={100,100}; body.omega=20;
        const auto stressed=solve(body,bins);
        gcr_require(std::isfinite(stressed.torque) && stressed.normal<=20+1e-9 &&
                    stressed.tangent<=mu*stressed.normal+1e-9 && stressed.updates<=64,
                    "GCR finite8-bin capacity/work stress failed");
        gcr_require(stressed.energy_after<=stressed.energy_before+1e-6*stressed.energy_before,
                    "GCR stress injected passive energy");
    }
}

void test_gcr_geometry_and_reduction() {
    using namespace cybersand::gcr;
    const auto tie=project({0,0},{2,2},0,{3,3});
    gcr_require(tie.bin==3 && tie.inward.x==-1 && tie.inward.y==0,
                "GCR corner/half tie differs from registered X-before-Y rule");
    const auto near_corner=project({0,0},{2,3},0,{3,2.9});
    gcr_require(near_corner.inward.x==-1 && near_corner.inward.y==0,
                "GCR nearest finite face confused nearby infinite face plane");
    const double geometry_angle=.37,geometry_c=std::cos(geometry_angle),geometry_s=std::sin(geometry_angle);
    const auto rotated=project({10,12},{2,3},geometry_angle,{10+4*geometry_c,12+4*geometry_s});
    gcr_require(gcr_near(rotated.point.x,10+2*geometry_c) && gcr_near(rotated.point.y,12+2*geometry_s) &&
                gcr_near(rotated.inward.x,-geometry_c) && gcr_near(rotated.inward.y,-geometry_s),
                "GCR used raster stair-step normal instead of actual rectangle face");
    const auto geometry_mirror=project({-10,12},{2,3},-geometry_angle,
        {-10-4*geometry_c,12+4*geometry_s});
    gcr_require(gcr_near(geometry_mirror.point.x,-rotated.point.x) &&
                gcr_near(geometry_mirror.point.y,rotated.point.y) &&
                gcr_near(geometry_mirror.inward.x,-rotated.inward.x) &&
                gcr_near(geometry_mirror.inward.y,rotated.inward.y),
                "GCR mirrored actual rectangle projection changed geometry");
    // Independent unreduced geometric moment oracle: an equal force on every
    // sample reduces exactly to force at its arithmetic centroid. Keep offset
    // COM in this test so an accidental proxy-centre torque cannot pass.
    const Vec com{7,11},force{-.3,-.7};
    Bin reduced; double oracle_moment=0; Vec oracle_force{};
    for (const Vec point:std::array<Vec,4>{{{3,4},{4,4},{5,4},{6,4}}}) {
        reduced.add(point,{0,-1},com);
        oracle_moment+=cross(point-com,force); oracle_force=oracle_force+force;
    }
    const Vec centroid=reduced.position_sum*(1./reduced.count);
    gcr_require(gcr_near(cross(centroid-com,oracle_force),oracle_moment),
                "GCR centroid reduction lost first moment");
    // A centroid is not an exact inertia oracle for distributed samples.
    // Explicitly retain that approximation instead of asserting false identity.
    const double centroid_arm=cross(centroid-com,Vec{0,-1});
    double mean_arm_squared=0;
    for(const double x:{3.,4.,5.,6.}) mean_arm_squared+=(x-com.x)*(x-com.x)/4.;
    gcr_require(mean_arm_squared>centroid_arm*centroid_arm,
                "GCR oracle no longer exposes second-moment reduction approximation");
    // Independent unreduced4-pass oracle: one load per physical sample,
    // independent scalar equations and per-sample cone projection.
    double maximum_normalized_error=0;
    bool approximation_gate=true;
    for(const unsigned distribution:{0U,1U,2U}) for(const bool mirror:{false,true})
    for(const double angle:{0.,.7853981633974483}) for(const double mass:{.5,1.,2.}) {
        const std::array<double,8> symmetric_x{{-1.75,-1.25,-.75,-.25,.25,.75,1.25,1.75}};
        const std::array<double,8> asymmetric_x{{-1.75,-1.5,-1.25,-1.,-.75,-.5,-.25,-.125}};
        const std::array<double,8> unequal_x{{-1.75,-1.5,-1.25,-1.,-.75,-.25,.75,1.75}};
        const auto& xs=distribution==1 ? asymmetric_x : distribution==2 ? unequal_x : symmetric_x;
        const double c=std::cos(angle),s=std::sin(angle),sign=mirror ? -1.:1.;
        const double cx=.4*sign*c-.2*s,cy=.4*sign*s+.2*c;
        const double nx=s,ny=-c,tx=c,ty=s,inertia=4*mass,mu=.78;
        const double initial_vx=3*sign*c-7*s,initial_vy=3*sign*s+7*c,initial_w=.5*sign;
        double vx=initial_vx,vy=initial_vy,omega=initial_w,radius=0;
        std::array<double,8> normal{},tangent{},delta{},rx{},ry{};
        std::array<Bin,8> bins{};
        for(std::size_t i=0;i<8;++i) {
            const double px=xs[i]*sign*c-s,py=xs[i]*sign*s+c;
            rx[i]=px-cx; ry[i]=py-cy;
            radius=std::max(radius,std::hypot(rx[i],ry[i]));
            bins[xs[i]*sign>=0 ? 5U:4U].add({px,py},{nx,ny},{cx,cy});
        }
        for(int pass=0;pass<4;++pass) for(int axis=0;axis<2;++axis) {
            const double dx=axis ? tx:nx,dy=axis ? ty:ny;
            for(std::size_t i=0;i<8;++i) {
                const double arm=rx[i]*dy-ry[i]*dx;
                const double speed=(vx-omega*ry[i])*dx+(vy+omega*rx[i])*dy;
                const double request=-speed/(1/mass+arm*arm/inertia);
                if(axis==0) {
                    const double next=std::clamp(normal[i]+request/8.,0.,2.);
                    delta[i]=next-normal[i]; normal[i]=next;
                } else {
                    const double next=std::clamp(tangent[i]+request/8.,-mu*normal[i],mu*normal[i]);
                    delta[i]=next-tangent[i]; tangent[i]=next;
                }
            }
            for(std::size_t i=0;i<8;++i) {
                vx+=dx*delta[i]/mass; vy+=dy*delta[i]/mass;
                omega+=(rx[i]*dy-ry[i]*dx)*delta[i]/inertia;
            }
        }
        double oracle_x=0,oracle_y=0,oracle_l=0;
        for(std::size_t i=0;i<8;++i) {
            const double jx=nx*normal[i]+tx*tangent[i],jy=ny*normal[i]+ty*tangent[i];
            oracle_x+=jx; oracle_y+=jy; oracle_l+=rx[i]*jy-ry[i]*jx;
        }
        Body body; body.velocity={initial_vx,initial_vy}; body.omega=initial_w; body.mass=mass;
        body.inertia=inertia; body.mu=mu; body.com={cx,cy};
        const auto response=solve(body,bins);
        const double reference_norm=std::sqrt(oracle_x*oracle_x+oracle_y*oracle_y+oracle_l*oracle_l/(radius*radius));
        const double ex=response.impulse.x-oracle_x,ey=response.impulse.y-oracle_y,el=(response.torque-oracle_l)/radius;
        const double error=std::sqrt(ex*ex+ey*ey+el*el);
        const double ratio=error/std::max(1e-9,reference_norm);
        maximum_normalized_error=std::max(maximum_normalized_error,ratio);
        approximation_gate=approximation_gate && (reference_norm==0 ? error<=1e-5:ratio<=.10);
        std::cout << "[GCR reduction oracle] distribution=" << distribution << " mirror=" << mirror
                  << " angle=" << angle << " mass=" << mass << " normalized_error=" << ratio << '\n';
    }
    std::cout << "[GCR reduction oracle maximum] " << maximum_normalized_error << " gate0.10=" << approximation_gate << '\n';
    gcr_require(approximation_gate,"GCR nonlinear bin reduction exceeds registered10% normalized wrench gate");
    Body still; std::array<Bin,8> still_bins{}; still_bins[0].add({1,1},{0,-1},{});
    const auto zero=solve(still,still_bins);
    gcr_require(length(zero.impulse)<=1e-5 && std::abs(zero.torque)<=1e-5,"GCR zero reference absolute oracle failed");
}

} // namespace
