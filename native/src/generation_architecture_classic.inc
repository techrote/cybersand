// GENTEK-CLASSIC-001: compact schema-4 architectural samplers.
// Each is deliberately small and uses the existing immutable ArchitectureForm.

class TrestleFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit TrestleFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (bx<p_.wall || bx>=p_.bay-p_.wall) return p_.shell;
        const auto tolerance=p_.wall*std::max(p_.bay,p_.level);
        if (std::abs(bx*p_.level-fy*p_.bay)<=tolerance ||
            std::abs((p_.bay-1-bx)*p_.level-fy*p_.bay)<=tolerance) return p_.accent;
        return Material::Empty;
    }
};

class StackedArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit StackedArcade(const ModuleInstance& i) : p_(i) {
        require(p_.bay>=4*p_.wall+12 && p_.level>=4*p_.wall+12,
            "stacked_arcade requires room for two visible arch tiers");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), tier=p_.level/2;
        const auto span=fy<tier?p_.bay/2:p_.bay, sy=fy<tier?fy:fy-tier, sx=positive_mod(bx,span);
        const auto radius=span/2-p_.wall, dx=std::abs(sx-span/2);
        const auto roof=p_.wall+(tier-p_.wall)*dx*dx/(radius*radius);
        if (sy<p_.wall) return p_.deck;
        if (dx<radius && sy>=roof) return Material::Empty;
        if (p_.windows && sy>p_.wall+2 && sy<roof-2 && dx>radius/2) return p_.glazing;
        return p_.shell;
    }
};

class FlyingButtress final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit FlyingButtress(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (bx<p_.wall || bx>=p_.bay-p_.wall) return p_.shell;
        const auto center=p_.bay/2;
        const auto left=center-fy*center/std::max<std::int64_t>(1,p_.level-1);
        const auto right=p_.bay-1-left;
        if (std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) return p_.accent;
        return Material::Empty;
    }
};

class SawtoothGallery final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SawtoothGallery(const ModuleInstance& i) : p_(i) {
        require(p_.bay/2>=2*p_.wall+4, "sawtooth_gallery bay is too narrow for roof teeth");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto tooth=p_.bay/2, tx=positive_mod(bx,tooth);
        const auto roof=p_.wall+tx*(p_.level/3)/std::max<std::int64_t>(1,tooth-1);
        if (std::abs(fy-roof)<=p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (tx<p_.wall) return p_.shell;
        if (p_.windows && tx>2*p_.wall && tx<tooth-2*p_.wall &&
            fy>roof+p_.wall && fy<p_.level-2*p_.wall) return p_.glazing;
        return Material::Empty;
    }
};

class CantileverSpine final : public FeatureSampler {
    ArchitectureForm p_; std::uint64_t seed_;
public:
    CantileverSpine(const ModuleInstance& i, std::uint64_t seed) : p_(i), seed_(seed) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall || std::abs(bx-center)<=p_.wall) return fy<p_.wall?p_.deck:p_.shell;
        const bool left=(hash_xy(seed_,floor_div(x,p_.bay),floor_div(y,p_.level),431)&1U)!=0;
        const auto upper=p_.level/3, lower=2*p_.level/3;
        if (std::abs(fy-upper)<=p_.wall && (left?bx<=center:bx>=center)) return p_.deck;
        if (std::abs(fy-lower)<=p_.wall && (left?bx>=center:bx<=center)) return p_.deck;
        const auto hanger=left?p_.bay/4:3*p_.bay/4;
        if (std::abs(bx-hanger)<=p_.wall && fy>upper && fy<lower) return p_.accent;
        return Material::Empty;
    }
};

class RibVault final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit RibVault(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto apex=2*p_.wall+1, base=p_.level-p_.wall-1;
        const auto span=std::max<std::int64_t>(1,center-p_.wall);
        const auto expected=apex+std::min(std::abs(bx-center),span)*(base-apex)/span;
        if (fy>=base) return p_.deck;
        if (bx<p_.wall || bx>=p_.bay-p_.wall) return p_.shell;
        if (std::abs(fy-expected)<=p_.wall) return p_.accent;
        if (p_.windows && std::abs(bx-center)<center/2 && fy>expected+p_.wall && fy<base-p_.wall)
            return p_.glazing;
        return Material::Empty;
    }
};

class NestedArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit NestedArcade(const ModuleInstance& i) : p_(i) {
        require(p_.bay>=4*p_.wall+12 && p_.level>=4*p_.wall+12,
            "nested_arcade requires room for large and small arch spans");
    }
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        const auto radius=center-p_.wall, dx=std::abs(bx-center);
        const auto outer_roof=p_.wall+(p_.level-p_.wall)*dx*dx/(radius*radius);
        if (!(dx<radius && fy>=outer_roof)) return p_.shell;
        const auto mid=p_.level/2;
        if (fy<mid) return Material::Empty;
        const auto sub=p_.bay/2, sx=positive_mod(bx,sub), sr=sub/2-p_.wall;
        const auto sy=fy-mid, sdx=std::abs(sx-sub/2);
        const auto small_roof=p_.wall+(p_.level-mid-p_.wall)*sdx*sdx/(sr*sr);
        if (sy<p_.wall) return p_.deck;
        if (sdx<sr && sy>=small_roof) return Material::Empty;
        return p_.accent;
    }
};

class SuspendedDeck final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SuspendedDeck(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto lower=p_.level/2, q1=p_.bay/4, q3=3*p_.bay/4;
        if (fy<p_.wall || std::abs(fy-lower)<=p_.wall) return p_.deck;
        if (bx<p_.wall || bx>=p_.bay-p_.wall) return p_.shell;
        if ((std::abs(bx-q1)<=p_.wall || std::abs(bx-q3)<=p_.wall) &&
            fy>p_.wall && fy<lower) return p_.accent;
        if (p_.windows && fy>lower+2*p_.wall && fy<p_.level-2*p_.wall &&
            std::abs(bx-p_.bay/2)<=p_.bay/6) return p_.glazing;
        return Material::Empty;
    }
};
