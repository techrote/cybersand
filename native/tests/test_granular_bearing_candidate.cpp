#include "cybersand/granular_bearing_candidate.hpp"
#include <iostream>
#include <stdexcept>
#include <vector>
using namespace cybersand::bearing_experiment;
static int checks=0;
void check(bool value,const char* message) {++checks;if (!value) throw std::runtime_error(message);}

// Literal current raster membership, including native real_t=float rounding.
int raster_below(double cx,double cy,double angle,int x) {
    int last=-10000;
    const double c=std::cos(angle),s=std::sin(angle);
    for(int y=130;y<=175;++y) {
        const double dx=x+0.5-cx,dy=y+0.5-cy;
        const float local_x=static_cast<float>(c*dx+s*dy),local_y=static_cast<float>(-s*dx+c*dy);
        if (std::abs(local_x)<=4 && std::abs(local_y)<=7) last=y;
    }
    return last+1;
}
int main() {
    try {
        check(parse("B0")==Mode::B0 && parse("Y1")==Mode::Y1 && parse("A2")==Mode::A2,"mode parser");
        check(!parse("Y1+A2") && !parse("y1"),"combined/malformed mode admitted");
        check(factor(Mode::B0)==0.18 && factor(Mode::A2)==0.18 && factor(Mode::Y1)==1,"formula isolation");
        for(double v:{-20.,0.,1.,30.,90.,100000.}) {
            check(lookahead(v)>=0 && lookahead(v)<=2,"lookahead cap");
            if(v>0) {
                const double g=92./60.,cap=std::min(20.,4.*2.);
                const double y1=std::min({v,g+std::max(0.,v-g)*factor(Mode::Y1),cap});
                check(y1<=v && y1<=cap,"Y1 exceeded arrest/capacity");
            }
        }
        auto none=[](int,int){return Cell{};};
        auto all=admit(0,10,9.7,2,none);
        check(all.used==3 && all.selected<0,"bounded exhaustive ray");
        check(all.steps[1].distance>0 && all.steps[2].distance<=2,"crossing bounds");
        const double crossing=all.steps[1].distance;
        check(admit(0,10,9.7,crossing,none).used==2,"inclusive terminal crossing");
        check(admit(0,10,9.7,std::nextafter(crossing,0.),none).used==1,"ray overshot lookahead");
        check(admit(0,10,9.7,200,none).used==3,"velocity multiplied work");
        auto first=admit(0,10,9.7,2,[](int,int){Cell c;c.supported=true;return c;});
        check(first.used==1 && first.selected==0,"multiple hits multiplied support");
        auto second=admit(0,10,9.7,2,[](int,int y){Cell c;c.supported=y>=11;return c;});
        check(second.selected==1 && second.used==2,"earliest qualifying hit lost");
        for(int kind:{0,1,2,3}) {
            auto blocked=admit(0,10,9.7,2,[kind](int,int y){Cell c;c.supported=y>10;
                if(y==10){c.in_bounds=kind!=0;c.hard=kind==1;c.body=kind==2?1:kind==3?2:0;}return c;});
            check(blocked.used==1 && blocked.selected<0,"bounds/hard/own/foreign barrier crossed");
        }
        check(admit(0,10,9.7,0,none).used==1,"zero lookahead changed current test");
        check(admit(0,10,std::numeric_limits<double>::infinity(),2,none).used==0,"malformed geometry queried world");
        int comparisons=0,ties=0,vanished=0;
        for(float angle:{0.F,.08F,.7F,-.3F,1.3F,1.57079637F})
            for(float phase:{0.F,.2F,.5F,.9F}) for(float xphase:{0.F,.2F,.5F,.9F}) for(int x=103;x<123;++x) {
                const double cx=112.F+xphase,cy=150.F+phase;
                const int below=raster_below(cx,cy,angle,x);
                if(below<-1000) continue;
                const double h=lower_edge(cx,cy,angle,4,7,x+.5,true);
                check(std::isfinite(h),"current raster column has no polygon lower edge");
                for(double d:{0.,.125,.5,.875,1.,1.5,2.}) {
                    const auto ray=admit(x,below,h,d,none);
                    check(ray.used>=1 && ray.used<=3 && ray.steps[0].y==below,"phase anchor/work bound");
                    for(std::size_t i=0;i<ray.used;++i)check(ray.steps[i].distance>=0 && ray.steps[i].distance<=d,"crossing outside segment");
                    const double nearest=std::abs((h+.5+d)-std::round(h+.5+d));
                    if(nearest<2e-5 && angle!=0.F){++ties;continue;}
                    const int expected=raster_below(cx,static_cast<float>(cy+d),angle,x);
                    // The registered primitive retains ORIGINAL boundary rays.
                    // A thin corner column can contain no prospective raster cell;
                    // that does not remove its continuous original sample ray.
                    if(expected<-1000) {
                        check(ray.steps[ray.used-1].y==static_cast<int>(std::floor(h+.5+d)),"vanished column lower-edge phase");
                        ++vanished;continue;
                    }
                    if(ray.steps[ray.used-1].y!=expected) std::cerr<<"angle="<<angle<<" cy="<<cy<<" x="<<x
                        <<" d="<<d<<" h="<<h<<" below="<<below<<" q="<<ray.q<<" actual="<<ray.steps[ray.used-1].y<<" expected="<<expected<<"\n";
                    check(ray.steps[ray.used-1].y==expected,"translated raster differential mismatch");
                    ++comparisons;
                }
            }
        std::cout<<checks<<" candidate checks passed; translated-raster comparisons="<<comparisons
                 <<"; non-axis float-boundary cases separately labelled="<<ties<<"\n";
        std::cout<<"original-boundary rays whose future raster column vanishes="<<vanished<<"\n";
    } catch(const std::exception& e) {std::cerr<<e.what()<<"\n";return 1;}
}
