// GENTEK-SHOWCASE-ROSEWORK-001: a radial structure carried by a gatehouse.
// Integer geometry only. Every rose is one immutable 4-bay / 6-floor supercell;
// the 6/8/12-spoke programme is selected once conceptually, never per pixel.
class RoseworkGatehouse final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    struct Direction { std::int64_t x, y; };
    // Unit directions in Q10: fixed analytic coefficients, not raster stamps.
    static constexpr std::array<Direction,24> compass24_{{
        {1024,0},{989,265},{887,512},{724,724},{512,887},{265,989},
        {0,1024},{-265,989},{-512,887},{-724,724},{-887,512},{-989,265},
        {-1024,0},{-989,-265},{-887,-512},{-724,-724},{-512,-887},{-265,-989},
        {0,-1024},{265,-989},{512,-887},{724,-724},{887,-512},{989,-265}}};
    static constexpr std::array<Direction,16> compass16_{{
        {1024,0},{946,392},{724,724},{392,946},{0,1024},{-392,946},{-724,724},{-946,392},
        {-1024,0},{-946,-392},{-724,-724},{-392,-946},{0,-1024},{392,-946},{724,-724},{946,-392}}};
    static bool annulus(std::int64_t d2, std::int64_t radius, std::int64_t thickness) noexcept {
        return d2 >= (radius-thickness)*(radius-thickness) &&
            d2 <= (radius+thickness)*(radius+thickness);
    }
public:
    RoseworkGatehouse(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {
        require(p_.bay >= 40 && p_.level >= 32,
            "rosework_gatehouse needs room_size >= 40 and floor_height >= 32 for visible tracery");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto width=4*p_.bay, height=6*p_.level;
        const auto bx=positive_mod(x,width), fy=positive_mod(y,height);
        const auto programme=hash_xy(seed_,floor_div(x,width),floor_div(y,height),2903);
        const auto cx=width/2, cy=2*p_.level, dx=bx-cx, dy=fy-cy;
        const auto radius=std::min(p_.bay,2*p_.level-3*p_.wall);
        const auto hub=radius/6, ring=5*radius/6, rib=std::max<std::int64_t>(1,(p_.wall+1)/2);
        const auto d2=dx*dx+dy*dy;

        // ROSE CENTRE / RINGS. Three closed bands with distinct mass hierarchy.
        // This region takes precedence over the frame: glazing can never cut a rib.
        if (d2 <= (radius+p_.wall+2)*(radius+p_.wall+2)) {
            if (annulus(d2,radius,p_.wall+2)) return p_.shell;
            if (annulus(d2,ring,rib) || annulus(d2,hub,rib)) return p_.accent;
            const auto count=std::array<int,3>{6,8,12}[programme%3U];
            const auto half=(ring-hub)/2, centre=(ring+hub)/2;
            const auto petal_half_width=std::max<std::int64_t>(3,radius/(count+2));
            const auto circle=(half*half+petal_half_width*petal_half_width)/(2*petal_half_width);
            const auto offset=circle-petal_half_width;
            bool glazed=false;
            // SPOKES / PETALS. At most twelve rays and twelve intersecting-circle
            // lenses. Each lens touches the hub and main ring at its pointed ends.
            for (int n=0;n<count;++n) {
                const auto spoke=count==8?compass16_[static_cast<std::size_t>(2*n)]:
                    compass24_[static_cast<std::size_t>(n*(24/count))];
                const auto petal=count==8?compass16_[static_cast<std::size_t>(2*n+1)]:
                    compass24_[static_cast<std::size_t>(n*(24/count)+12/count)];
                const auto along=dx*spoke.x+dy*spoke.y, across=dx*spoke.y-dy*spoke.x;
                if (along>=hub*1024 && along<=radius*1024 && std::abs(across)<=rib*1024)
                    return p_.accent;
                const auto u=dx*petal.x+dy*petal.y-centre*1024;
                const auto v=dx*petal.y-dy*petal.x;
                // Keep Q10 until the squared comparison: early rounding makes
                // one-cell diagonal petals visibly stippled.
                const auto lens=u*u+(std::abs(v)+offset*1024)*(std::abs(v)+offset*1024);
                if (lens<=circle*circle*1048576) {
                    if (lens>=(circle-rib)*(circle-rib)*1048576) return p_.accent;
                    // Alternate clear and glazed petals, preserving visible voids
                    // even with windows enabled. The switch only changes infill.
                    glazed=glazed || ((static_cast<std::uint64_t>(n)+(programme>>4U))%2U==0);
                }
            }
            if (p_.windows && glazed) return p_.glazing;
            return Material::Empty;
        }

        // GATE. A monumental, permanently open portal sits directly below the
        // rose. Doors only affect the smaller side passages, never the main gate.
        const auto gate_half=std::max(p_.bay*3/4,radius-2*p_.wall);
        const auto gate_top=cy+radius+2*p_.wall, spring=5*p_.level;
        const auto roof=gate_top+(spring-gate_top)*dx*dx/(gate_half*gate_half);
        const auto foot=height-p_.wall-1, side=std::min(bx,width-bx);
        if (fy>=foot && side>=p_.bay/4) return p_.deck;
        if (std::abs(dx)<=gate_half+2*p_.wall && fy>=gate_top-2*p_.wall && fy<foot) {
            if (std::abs(fy-roof)<=2*p_.wall) return p_.shell;
            if (std::abs(dx)<gate_half && fy>roof) return Material::Empty;
        }

        // TOWERS. The upper piers remain slender; lower shoulders widen into the
        // portal. Slit voids and stepped crowns break the large masonry masses.
        const auto tower=p_.bay/2, crown=p_.level/4+static_cast<std::int64_t>((programme>>2U)&1U)*(p_.level/8);
        const auto tower_distance=std::abs(side-tower);
        const auto half_tower=fy<cy+radius?p_.bay/4:p_.bay/2;
        if (tower_distance<=half_tower && fy>=crown && fy<foot) {
            if (fy<crown+p_.level/5 && tower_distance>half_tower-p_.wall*2 &&
                positive_mod(side,p_.wall*4+4)>=p_.wall*2+2) return Material::Empty;
            const auto side_gate_top=height-p_.level;
            const auto side_gate_half=std::min(p_.bay/7,p_.door);
            const auto passage_roof=side_gate_top+tower_distance*tower_distance/
                std::max<std::int64_t>(1,side_gate_half);
            if (p_.doors && tower_distance<side_gate_half && fy>=passage_roof) return Material::Empty;
            const auto slit_bottom=cy+radius-p_.level/3;
            if (tower_distance<p_.bay/16 && fy>crown+p_.level/3 && fy<slit_bottom)
                return Material::Empty;
            if (positive_mod(fy-crown,p_.level)<p_.wall && tower_distance<=half_tower)
                return p_.deck;
            return p_.shell;
        }

        // TRANSFERS / LOWER ARCADE. Short horizontal ties and curved shoulders
        // attach the radial shell to both towers; no independently floating rose.
        if (std::abs(dy)<=2*p_.wall && std::abs(dx)>=radius && side>=tower)
            return p_.deck;
        const auto shoulder_top=cy+radius/2;
        const auto shoulder=shoulder_top+(std::abs(dx)-radius)*(std::abs(dx)-radius)/
            std::max<std::int64_t>(1,p_.bay/2);
        if (std::abs(dx)>=radius && side>=tower && fy>=shoulder_top &&
            std::abs(fy-shoulder)<=p_.wall) return p_.accent;
        return Material::Empty;
    }
};
