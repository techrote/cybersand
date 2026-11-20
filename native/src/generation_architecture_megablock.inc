// GENTEK-SHOWCASE-MEGABLOCK-001: one local grammar, not a mixture of samplers.
// A 4-bay by 4-band programme shares decks, attachment levels and protected voids.
class SeededTypologyMegablock final : public FeatureSampler {
    ArchitectureForm p_;
    std::uint64_t seed_;
    using T = megablock::Typology;
    static bool member(std::int64_t x, std::int64_t y, std::int64_t ax, std::int64_t ay,
                       std::int64_t bx, std::int64_t by, std::int64_t w) noexcept {
        // A bounded integer strip; dominant-axis thickness keeps steep/thin ribs connected.
        return x >= std::min(ax,bx)-w && x <= std::max(ax,bx)+w &&
            y >= std::min(ay,by)-w && y <= std::max(ay,by)+w &&
            std::abs((x-ax)*(by-ay)-(y-ay)*(bx-ax)) <= w*std::max(std::abs(bx-ax),std::abs(by-ay));
    }
public:
    SeededTypologyMegablock(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {
        require(p_.bay >= 6*p_.wall+12 && p_.level >= 6*p_.wall+12,
            "seeded_typology_megablock needs bay/floor >= 6 * wall + 12 for protected clearances");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto b=p_.bay, h=p_.level, w=p_.wall;
        const auto sx=positive_mod(x,4*b), sy=positive_mod(y,4*h);
        const int column=static_cast<int>(sx/b), band=static_cast<int>(sy/h);
        const auto u=sx%b, v=sy%h, mid=h/2, foot=h-w, center=b/2;
        const auto plan=megablock::programme(hash_xy(seed_,floor_div(x,4*b),floor_div(y,4*h),megablock::hash_lane));
        const auto type=megablock::typology(plan,column,band);
        const auto left=megablock::typology(plan,column-1,band), right=megablock::typology(plan,column+1,band);
        const bool landing=left==T::Bridge || right==T::Bridge || left==T::Cantilever || right==T::Cantilever;
        const auto edge=std::min(u,b-1-u);
        // All lower lots meet one transfer slab. Other floors stop at an atrium;
        // only the selected bridge crosses it, at exactly the shared mid datum.
        if (band==3 && v>=foot) return p_.deck;
        if (type==T::Atrium) return Material::Empty;
        if (type!=T::Bridge && type!=T::Cantilever && v>=foot) return p_.deck;
        if (landing && std::abs(v-mid)<=w) return p_.deck;
        if (type==T::Core) {
            if (std::abs(u-center)<=b/5 && std::abs(u-center)>=w) return p_.spine;
            if (v<w || std::abs(v-mid)<=w) return p_.deck;
            // Short regular ribs remain attached to the two continuous core rails.
            if (v%(std::max<std::int64_t>(8,h/4))<w && std::abs(u-center)<=b/3) return p_.accent;
            return Material::Empty;
        }
        if (type==T::Bridge) {
            if (std::abs(v-mid)<=w) return p_.deck;
            const auto rail=mid-h/6, pitch=std::max<std::int64_t>(6,b/4);
            if (std::abs(v-rail)<=w || (u%pitch<w && v>=rail && v<=mid)) return p_.accent;
            // Knee members terminate in the occupied mid landings on both neighbours.
            if (member(u,v,0,mid+w,b/2,mid+h/4,w) ||
                member(u,v,b/2,mid+h/4,b-1,mid+w,w)) return p_.shell;
            return Material::Empty;
        }
        if (type==T::Cantilever) {
            const auto q=column==0?b-1-u:u; // Anchor always faces the known inner support.
            if (q<2*w) return p_.shell;
            if (q<=3*b/4 && std::abs(v-mid)<=w) return p_.deck;
            if (member(q,v,0,3*h/4,3*b/4,mid+w,w)) return p_.accent;
            return Material::Empty;
        }
        if (type==T::Crown) {
            const auto apex=(plan.choices&16U)?b/3:2*b/3, shoulder=2*h/3;
            if (edge<w && v>=shoulder) return p_.shell;
            if (member(u,v,0,shoulder,apex,h/4,w) ||
                member(u,v,apex,h/4,b-1,shoulder,w)) return p_.accent;
            return Material::Empty;
        }
        // Dense/open interfaces have thicker piers. This is an actual neighbour
        // response, not a label: a void never receives a blind mid-level beam.
        const auto lw=left==T::Atrium || left==T::Bridge ? 2*w : w;
        const auto rw=right==T::Atrium || right==T::Bridge ? 2*w : w;
        if (u<lw || u>=b-rw) return p_.shell;
        if (type==T::OpenFrame) {
            if (v<w) return p_.deck;
            if (member(u,v,lw,h/3,b/3,0,w) || member(u,v,2*b/3,0,b-rw-1,h/3,w)) return p_.accent;
            return Material::Empty;
        }
        if (type==T::Habitation) {
            const auto sill=3*h/4, head=h/4, pitch=std::max<std::int64_t>(6,b/5);
            if (v<w || std::abs(v-head)<=w || std::abs(v-sill)<=w) return p_.deck;
            if (v>head && v<sill) {
                if (u%pitch<w) return p_.shell;
                return p_.windows?p_.glazing:p_.shell;
            }
            return Material::Empty;
        }
        if (type==T::Buttress) {
            const auto step=std::min<std::int64_t>(3,4*v/h);
            const auto reach=2*w+(step+1)*(b/2-3*w)/5;
            if (edge<reach) return edge<reach-w?p_.shell:p_.accent;
            if (v<w) return p_.deck;
            return Material::Empty;
        }
        // Automatic doors open the complete lower gateway, with its arch and
        // piers retained. Off restores masonry, never a loose centre obstacle.
        const auto radius=center-2*w, dx=std::abs(u-center);
        const auto arch=w+(h/2)*dx*dx/(radius*radius);
        if (v<arch) return v<arch-w?p_.shell:p_.accent;
        return p_.doors?Material::Empty:p_.shell;
    }
};
