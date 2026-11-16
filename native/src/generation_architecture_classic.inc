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

// 9. BowstringTruss: curved upper chord, straight lower deck and vertical hangers.
class BowstringTruss final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit BowstringTruss(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto radius=std::max<std::int64_t>(1,center-p_.wall), dx=std::abs(bx-center);
        const auto chord=p_.wall+(p_.level/3)*dx*dx/(radius*radius), deck=2*p_.level/3;
        if (std::abs(fy-chord)<=p_.wall) return p_.accent;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        const auto hanger=std::max<std::int64_t>(8,p_.bay/5);
        if (positive_mod(bx,hanger)<p_.wall && fy>chord && fy<deck) return p_.shell;
        return Material::Empty;
    }
};

// 10. DiamondTruss: a central spine wrapped by a large four-sided truss cell.
class DiamondTruss final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit DiamondTruss(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto cx=p_.bay/2, cy=p_.level/2;
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (std::abs(bx-cx)<=p_.wall) return p_.shell;
        const auto value=std::abs(bx-cx)*p_.level+std::abs(fy-cy)*p_.bay;
        const auto edge=cx*p_.level, tolerance=p_.wall*std::max(p_.bay,p_.level);
        if (std::abs(value-edge)<=tolerance) return p_.accent;
        return Material::Empty;
    }
};

// 11. PortalFrame: repeated two-leg portals with a high crossbeam and open centre.
class PortalFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit PortalFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4, beam=p_.level/3;
        if (std::abs(fy-beam)<=p_.wall && bx>=left && bx<=right) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>=beam)
            return p_.shell;
        if (fy>=p_.level-p_.wall) return p_.accent;
        return Material::Empty;
    }
};

// 12. LadderBridge: paired long chords joined by closely spaced vertical rungs.
class LadderBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit LadderBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto upper=p_.level/3, lower=2*p_.level/3;
        if (std::abs(fy-upper)<=p_.wall || std::abs(fy-lower)<=p_.wall) return p_.deck;
        const auto rung=std::max<std::int64_t>(8,p_.bay/5);
        if (positive_mod(bx,rung)<p_.wall && fy>upper && fy<lower) return p_.accent;
        return Material::Empty;
    }
};

// 13. SteppedAqueduct: narrowing terraces connected by paired masonry piers.
class SteppedAqueduct final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SteppedAqueduct(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        for (std::int64_t tier=1;tier<=3;++tier) {
            const auto height=tier*p_.level/4, margin=(3-tier)*p_.bay/10;
            if (std::abs(fy-height)<=p_.wall && bx>=margin && bx<p_.bay-margin) return p_.deck;
        }
        if ((std::abs(bx-p_.bay/4)<=p_.wall || std::abs(bx-3*p_.bay/4)<=p_.wall) &&
            fy>=p_.level/4) return p_.shell;
        return Material::Empty;
    }
};

// 14. SplitPier: one lower pier divides into two diagonal branches beneath a deck.
class SplitPier final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SplitPier(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        if (fy>=p_.level/2 && std::abs(bx-center)<=p_.wall) return p_.shell;
        if (fy<p_.level/2) {
            const auto spread=(p_.level/2-fy)*(p_.bay/4)/std::max<std::int64_t>(1,p_.level/2);
            if (std::abs(bx-(center-spread))<=p_.wall || std::abs(bx-(center+spread))<=p_.wall)
                return p_.accent;
        }
        return Material::Empty;
    }
};

// 15. CableGallery: parabolic carrier cable, lower deck and repeated hangers.
class CableGallery final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CableGallery(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto radius=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto cable=p_.wall+(p_.level/3)*(radius*radius-dx*dx)/(radius*radius);
        const auto deck=2*p_.level/3;
        if (std::abs(fy-cable)<=p_.wall) return p_.accent;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        const auto hanger=std::max<std::int64_t>(8,p_.bay/6);
        if (positive_mod(bx,hanger)<p_.wall && fy>cable && fy<deck) return p_.shell;
        return Material::Empty;
    }
};

// 16. ClerestoryHall: tall hall walls, roof, upper glazing band and internal columns.
class ClerestoryHall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ClerestoryHall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (bx<p_.wall || bx>=p_.bay-p_.wall || std::abs(bx-p_.bay/2)<=p_.wall) return p_.shell;
        if (p_.windows && fy>p_.level/5 && fy<p_.level/3) return p_.glazing;
        return Material::Empty;
    }
};

// 17. MushroomDeck: a broad top deck carried by tapered mushroom-cap columns.
class MushroomDeck final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit MushroomDeck(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        if (fy>=p_.level/3 && std::abs(bx-center)<=p_.wall) return p_.shell;
        if (fy<p_.level/3) {
            const auto reach=p_.wall+(p_.level/3-fy)*(p_.bay/3)/std::max<std::int64_t>(1,p_.level/3);
            if (std::abs(bx-center)<=reach) return p_.accent;
        }
        return Material::Empty;
    }
};

// 18. ZigzagBridge: a continuous folded deck with periodic vertical supports.
class ZigzagBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ZigzagBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto half=std::max<std::int64_t>(1,p_.bay/2);
        const auto tri=bx<=half?bx:p_.bay-bx;
        const auto deck=p_.level/3+tri*(p_.level/3)/half;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy>=deck) return p_.shell;
        return Material::Empty;
    }
};

// 19. ScallopedVault: three smaller quadratic vaults share one repeating bay.
class ScallopedVault final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ScallopedVault(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto span=std::max<std::int64_t>(8,p_.bay/3), sx=positive_mod(bx,span);
        const auto radius=std::max<std::int64_t>(1,span/2-p_.wall), dx=std::abs(sx-span/2);
        const auto roof=p_.wall+(p_.level/2-p_.wall)*dx*dx/(radius*radius);
        if (fy>=p_.level-p_.wall) return p_.deck;
        if (std::abs(fy-roof)<=p_.wall || sx<p_.wall) return p_.accent;
        return Material::Empty;
    }
};

// 20. LatticeTower: narrow tower bays with edge rails, floors and crossed braces.
class LatticeTower final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit LatticeTower(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4, width=right-left;
        if (bx<left-p_.wall || bx>right+p_.wall) return Material::Empty;
        if (std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) return p_.shell;
        if (fy<p_.wall || std::abs(fy-p_.level/2)<=p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        const auto local=bx-left, tolerance=p_.wall*std::max(width,p_.level);
        if (std::abs(local*p_.level-fy*width)<=tolerance ||
            std::abs((width-local)*p_.level-fy*width)<=tolerance) return p_.accent;
        return Material::Empty;
    }
};

// 21. OffsetArcade: successive levels shift their arch centres left and right.
class OffsetArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit OffsetArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto level=floor_div(y,p_.level), shift=(positive_mod(level,2)==0?-p_.bay/6:p_.bay/6);
        const auto center=p_.bay/2+shift, radius=std::max<std::int64_t>(1,p_.bay/2-p_.wall);
        const auto dx=std::abs(bx-center);
        if (fy<p_.wall) return p_.deck;
        const auto roof=p_.wall+(p_.level-p_.wall)*dx*dx/(radius*radius);
        if (dx<radius && fy>=roof) return Material::Empty;
        if (p_.windows && dx>radius/2 && fy>p_.wall+2 && fy<roof-2) return p_.glazing;
        return p_.shell;
    }
};

// 22. Bridgehouse: a mid-level bridge carries repeated gabled structural rooms.
class Bridgehouse final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit Bridgehouse(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto deck=p_.level/2, left=p_.bay/4, right=3*p_.bay/4, center=p_.bay/2;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>deck) return p_.shell;
        if (fy<deck) {
            const auto roof=p_.wall+std::abs(bx-center)*(deck/2)/std::max<std::int64_t>(1,p_.bay/4);
            if (std::abs(fy-roof)<=p_.wall || std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall)
                return p_.accent;
            if (p_.windows && bx>left+p_.wall && bx<right-p_.wall && fy>deck/3) return p_.glazing;
        }
        return Material::Empty;
    }
};

// 23. ForkedGantry: central lower stem splits into two upper legs beneath a deck.
class ForkedGantry final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ForkedGantry(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        if (fy>=p_.level/2 && std::abs(bx-center)<=p_.wall) return p_.shell;
        if (fy<p_.level/2) {
            const auto offset=(p_.level/2-fy)*(p_.bay/3)/std::max<std::int64_t>(1,p_.level/2);
            if (std::abs(bx-(center-offset))<=p_.wall || std::abs(bx-(center+offset))<=p_.wall)
                return p_.accent;
        }
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

// 24. ButtressWall: heavy edge piers, deep diagonal buttresses and a central light slot.
class ButtressWall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ButtressWall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (bx<2*p_.wall || bx>=p_.bay-2*p_.wall || fy>=p_.level-p_.wall) return p_.shell;
        const auto reach=(p_.level-1-fy)*(p_.bay/4)/std::max<std::int64_t>(1,p_.level);
        if (bx<=reach+p_.wall || bx>=p_.bay-1-reach-p_.wall) return p_.accent;
        if (p_.windows && std::abs(bx-center)<=p_.bay/10 &&
            fy>p_.level/4 && fy<3*p_.level/4) return p_.glazing;
        return Material::Empty;
    }
};
