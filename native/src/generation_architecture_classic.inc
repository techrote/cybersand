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

// 25. FanTruss: one high central node fans several braces toward a lower deck.
class FanTruss final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit FanTruss(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto apex=p_.level/5, deck=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        for (const auto target : {p_.bay/8,3*p_.bay/8,5*p_.bay/8,7*p_.bay/8}) {
            const auto lhs=(bx-center)*(deck-apex), rhs=(fy-apex)*(target-center);
            if (std::abs(lhs-rhs)<=p_.wall*std::max(p_.bay,p_.level)) return p_.accent;
        }
        return Material::Empty;
    }
};

// 26. PrattTruss: two chords, vertical posts and alternating inward diagonals.
class PrattTruss final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit PrattTruss(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto top=p_.level/4, bottom=3*p_.level/4, panel=std::max<std::int64_t>(8,p_.bay/4);
        if (std::abs(fy-top)<=p_.wall || std::abs(fy-bottom)<=p_.wall) return p_.deck;
        if (positive_mod(bx,panel)<p_.wall && fy>top && fy<bottom) return p_.shell;
        const auto local=positive_mod(bx,panel), tolerance=p_.wall*std::max(panel,bottom-top);
        const bool flip=(bx/panel)%2!=0;
        const auto lhs=local*(bottom-top), rhs=(fy-top)*panel;
        if (std::abs((flip?panel*(bottom-top)-lhs:lhs)-rhs)<=tolerance) return p_.accent;
        return Material::Empty;
    }
};

// 27. VierendeelFrame: heavy rectangular bays with no diagonal bracing.
class VierendeelFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit VierendeelFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto top=p_.level/4, bottom=3*p_.level/4, panel=std::max<std::int64_t>(8,p_.bay/4);
        if (std::abs(fy-top)<=2*p_.wall || std::abs(fy-bottom)<=2*p_.wall) return p_.deck;
        if (positive_mod(bx,panel)<2*p_.wall && fy>=top && fy<=bottom) return p_.shell;
        return Material::Empty;
    }
};

// 28. SuspensionPylon: paired pylons, a low deck and sloping carrier stays.
class SuspensionPylon final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SuspensionPylon(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4, deck=3*p_.level/4, crown=p_.level/5;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>=crown) return p_.shell;
        const auto tol=p_.wall*std::max(p_.bay,p_.level);
        if (std::abs((bx-left)*(deck-crown)-(fy-crown)*(-left))<=tol ||
            std::abs((bx-right)*(deck-crown)-(fy-crown)*(p_.bay-1-right))<=tol) return p_.accent;
        return Material::Empty;
    }
};

// 29. HarpBridge: a single mast with several straight harp stays to a deck.
class HarpBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit HarpBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), mast=p_.bay/2;
        const auto deck=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if (std::abs(bx-mast)<=p_.wall) return p_.shell;
        const auto tol=p_.wall*std::max(p_.bay,p_.level);
        for (const auto target : {p_.bay/8,p_.bay/4,3*p_.bay/4,7*p_.bay/8}) {
            const auto anchor=p_.level/5+std::abs(target-mast)*(p_.level/3)/std::max<std::int64_t>(1,mast);
            if (std::abs((bx-mast)*(deck-anchor)-(fy-anchor)*(target-mast))<=tol) return p_.accent;
        }
        return Material::Empty;
    }
};

// 30. DoubleCantilever: twin piers carry inward shelves at three distinct levels.
class DoubleCantilever final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit DoubleCantilever(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4;
        if (std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) return p_.shell;
        for (const auto h : {p_.level/4,p_.level/2,3*p_.level/4}) {
            if (std::abs(fy-h)<=p_.wall && bx>=left && bx<=right) return p_.deck;
        }
        return Material::Empty;
    }
};

// 31. SteppedButtress: dense edge masses step inward as they rise.
class SteppedButtress final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SteppedButtress(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto tier=std::min<std::int64_t>(3,3*fy/std::max<std::int64_t>(1,p_.level));
        const auto reach=(3-tier)*p_.bay/10+p_.wall;
        if (bx<reach || bx>=p_.bay-reach || fy>=p_.level-p_.wall) return p_.shell;
        if (std::abs(fy-(tier+1)*p_.level/4)<=p_.wall) return p_.accent;
        return Material::Empty;
    }
};

// 32. Colonnade: entablature over a dense rhythm of slender columns and plinth.
class Colonnade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit Colonnade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto pitch=std::max<std::int64_t>(8,p_.bay/5);
        if (fy<p_.wall*2 || fy>=p_.level-p_.wall*2) return p_.deck;
        if (positive_mod(bx,pitch)<p_.wall*2) return p_.shell;
        if (fy<p_.level/5 && positive_mod(bx,pitch)<pitch/2) return p_.accent;
        return Material::Empty;
    }
};

// 33. Basilica: tall nave roof with lower side aisles and paired interior columns.
class Basilica final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit Basilica(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto dx=std::abs(bx-center), nave=p_.bay/4;
        const auto roof=dx<=nave?p_.level/6+dx*(p_.level/5)/std::max<std::int64_t>(1,nave):
            p_.level/3+(dx-nave)*(p_.level/8)/std::max<std::int64_t>(1,center-nave);
        if (std::abs(fy-roof)<=p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        if (std::abs(dx-nave)<=p_.wall && fy>roof) return p_.shell;
        if (p_.windows && dx<nave && fy>p_.level/3 && fy<p_.level/2) return p_.glazing;
        return Material::Empty;
    }
};

// 34. CrenellatedBridge: a high deck with repeated merlons and deep supporting piers.
class CrenellatedBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CrenellatedBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), deck=p_.level/3;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        const auto pitch=std::max<std::int64_t>(8,p_.bay/6);
        if (fy<deck && positive_mod(bx,pitch)<pitch/2 && fy>=deck-p_.level/6) return p_.accent;
        if ((bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) && fy>deck) return p_.shell;
        return Material::Empty;
    }
};

// 35. PointedArcade: Gothic V-curves form pointed openings under a continuous deck.
class PointedArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit PointedArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        const auto roof=p_.wall+std::abs(bx-center)*(p_.level-p_.wall)/std::max<std::int64_t>(1,center-p_.wall);
        if (bx>p_.wall && bx<p_.bay-p_.wall && fy>=roof) return Material::Empty;
        if (p_.windows && fy>p_.wall*3 && fy<roof-p_.wall && std::abs(bx-center)>center/2) return p_.glazing;
        return p_.shell;
    }
};

// 36. InvertedArch: a hanging quadratic rib descends from an upper carrier deck.
class InvertedArch final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit InvertedArch(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        const auto radius=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto rib=p_.level/5+(p_.level/2)*(radius*radius-dx*dx)/(radius*radius);
        if (std::abs(fy-rib)<=p_.wall) return p_.accent;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy<rib) return p_.shell;
        return Material::Empty;
    }
};

// 37. HourglassPier: a single support narrows at mid-height and flares at both ends.
class HourglassPier final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit HourglassPier(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        const auto dy=std::abs(fy-p_.level/2);
        const auto reach=p_.wall+dy*(p_.bay/5)/std::max<std::int64_t>(1,p_.level/2);
        if (std::abs(bx-center)<=reach) return dy>p_.level/3?p_.accent:p_.shell;
        return Material::Empty;
    }
};

// 38. TripodFrame: three splayed legs converge below a compact crown deck.
class TripodFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit TripodFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto crown=p_.level/4;
        if (std::abs(fy-crown)<=p_.wall && std::abs(bx-center)<=p_.bay/4) return p_.deck;
        const auto spread=(fy-crown)*(p_.bay/3)/std::max<std::int64_t>(1,p_.level-crown);
        if (fy>=crown && (std::abs(bx-center)<=p_.wall ||
            std::abs(bx-(center-spread))<=p_.wall || std::abs(bx-(center+spread))<=p_.wall)) return p_.accent;
        return Material::Empty;
    }
};

// 39. ChevronHall: repeated peaked roof with sparse load-bearing side columns.
class ChevronHall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ChevronHall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto roof=p_.wall+std::abs(bx-center)*(p_.level/3)/std::max<std::int64_t>(1,center);
        if (std::abs(fy-roof)<=p_.wall) return p_.accent;
        if ((bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) && fy>=roof) return p_.shell;
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

// 40. HangingArcade: repeated shallow hanging arches descend from a top deck.
class HangingArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit HangingArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        const auto radius=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto rib=p_.level/5+(p_.level/3)*dx*dx/(radius*radius);
        if (std::abs(fy-rib)<=p_.wall) return p_.accent;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy<2*p_.level/3) return p_.shell;
        return Material::Empty;
    }
};

// 41. ShelfStack: one central spine carries alternating full and half-width shelves.
class ShelfStack final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ShelfStack(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (std::abs(bx-center)<=p_.wall) return p_.shell;
        for (std::int64_t n=1;n<=4;++n) {
            const auto h=n*p_.level/5;
            if (std::abs(fy-h)<=p_.wall && (n%2==0 || std::abs(bx-center)<=p_.bay/3)) return p_.deck;
        }
        return Material::Empty;
    }
};

// 42. StaggeredBalcony: alternating side balconies project from paired edge towers.
class StaggeredBalcony final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit StaggeredBalcony(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) return p_.shell;
        const auto band=std::max<std::int64_t>(1,p_.level/4), row=fy/band, h=row*band;
        if (std::abs(fy-h)<=p_.wall) {
            const bool left=row%2==0;
            if ((left && bx<p_.bay/2) || (!left && bx>=p_.bay/2)) return p_.deck;
        }
        return Material::Empty;
    }
};

// 43. MonopodTower: a central mast supports periodic diamond-shaped observation pods.
class MonopodTower final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit MonopodTower(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (std::abs(bx-center)<=p_.wall) return p_.shell;
        const auto pod=std::max<std::int64_t>(12,p_.level/3), py=positive_mod(fy,pod), cy=pod/2;
        const auto diamond=std::abs(bx-center)*pod+std::abs(py-cy)*(p_.bay/2);
        const auto edge=(p_.bay/5)*pod, tol=p_.wall*std::max(p_.bay,pod);
        if (std::abs(diamond-edge)<=tol) return p_.accent;
        return Material::Empty;
    }
};

// 44. WedgeGallery: paired sloping shelves create an asymmetric wedge-shaped passage.
class WedgeGallery final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit WedgeGallery(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto upper=p_.level/5+bx*(p_.level/4)/std::max<std::int64_t>(1,p_.bay-1);
        const auto lower=4*p_.level/5-bx*(p_.level/5)/std::max<std::int64_t>(1,p_.bay-1);
        if (std::abs(fy-upper)<=p_.wall || std::abs(fy-lower)<=p_.wall) return p_.deck;
        if (bx<p_.wall && fy>=upper && fy<=lower) return p_.shell;
        return Material::Empty;
    }
};

// 45. CrownBridge: repeated triangular crown ribs stand above a heavy mid-level deck.
class CrownBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CrownBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto deck=2*p_.level/3;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        const auto crown=p_.level/6+std::abs(bx-center)*(deck-p_.level/6)/std::max<std::int64_t>(1,center);
        if (std::abs(fy-crown)<=p_.wall && fy<deck) return p_.accent;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy>=deck) return p_.shell;
        return Material::Empty;
    }
};

// 46. ZigzagPier: a single load path switches left/right at each vertical quarter.
class ZigzagPier final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ZigzagPier(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (fy<p_.wall) return p_.deck;
        const auto seg=std::max<std::int64_t>(1,p_.level/4), row=std::min<std::int64_t>(3,fy/seg), local=positive_mod(fy,seg);
        const auto a=row%2==0?p_.bay/3:2*p_.bay/3, b=row%2==0?2*p_.bay/3:p_.bay/3;
        const auto expected=a+(b-a)*local/seg;
        if (std::abs(bx-expected)<=p_.wall) return row%2==0?p_.accent:p_.shell;
        return Material::Empty;
    }
};

// 47. DrumVault: a broad rounded barrel shell with straight side walls.
class DrumVault final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit DrumVault(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto radius=std::max<std::int64_t>(1,center-p_.wall), dx=std::min(std::abs(bx-center),radius);
        const auto roof=p_.level/5+(p_.level/3)*dx*dx/(radius*radius);
        if (std::abs(fy-roof)<=p_.wall) return p_.accent;
        if ((bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) && fy>=roof) return p_.shell;
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

// 48. PyramidalFrame: triangular outer frame with three internal horizontal ties.
class PyramidalFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit PyramidalFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto edge=p_.wall+fy*center/std::max<std::int64_t>(1,p_.level-1);
        if (std::abs(std::abs(bx-center)-edge)<=p_.wall) return p_.accent;
        for (const auto h : {p_.level/3,p_.level/2,2*p_.level/3})
            if (std::abs(fy-h)<=p_.wall && std::abs(bx-center)<=edge) return p_.deck;
        if (fy>=p_.level-p_.wall) return p_.shell;
        return Material::Empty;
    }
};

// 49. WarrenTruss: triangular diagonals repeat between two long chords.
class WarrenTruss final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit WarrenTruss(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto top=p_.level/4, bottom=3*p_.level/4, panel=std::max<std::int64_t>(8,p_.bay/4);
        if (std::abs(fy-top)<=p_.wall || std::abs(fy-bottom)<=p_.wall) return p_.deck;
        const auto local=positive_mod(bx,panel), row=bx/panel;
        const auto target=(row%2==0)?top+(bottom-top)*local/panel:bottom-(bottom-top)*local/panel;
        if (std::abs(fy-target)<=p_.wall) return p_.accent;
        return Material::Empty;
    }
};

class KingpostFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit KingpostFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto apex=p_.level/5, deck=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if (std::abs(bx-center)<=p_.wall && fy>=apex && fy<=deck) return p_.shell;
        const auto roof=apex+std::abs(bx-center)*(deck-apex)/std::max<std::int64_t>(1,center);
        if (std::abs(fy-roof)<=p_.wall && fy<=deck) return p_.accent;
        return Material::Empty;
    }
};

class QueenpostFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit QueenpostFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/3, right=2*p_.bay/3, tie=p_.level/3, deck=3*p_.level/4;
        if (std::abs(fy-tie)<=p_.wall && bx>=left && bx<=right) return p_.deck;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>=tie && fy<=deck) return p_.shell;
        const auto tol=p_.wall*std::max(p_.bay,p_.level);
        if (std::abs(bx*(deck-tie)-(fy-tie)*left)<=tol ||
            std::abs((p_.bay-1-bx)*(deck-tie)-(fy-tie)*(p_.bay-1-right))<=tol) return p_.accent;
        return Material::Empty;
    }
};

class LenticularBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit LenticularBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto r=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto curve=(p_.level/4)*(r*r-dx*dx)/(r*r);
        const auto upper=p_.level/2-curve, lower=p_.level/2+curve;
        if (std::abs(fy-upper)<=p_.wall || std::abs(fy-lower)<=p_.wall) return p_.accent;
        const auto tie=std::max<std::int64_t>(8,p_.bay/6);
        if (positive_mod(bx,tie)<p_.wall && fy>upper && fy<lower) return p_.shell;
        return Material::Empty;
    }
};

class RadialStayBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit RadialStayBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), mast=p_.bay/2;
        const auto hub=p_.level/4, deck=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if (std::abs(bx-mast)<=p_.wall && fy>=hub) return p_.shell;
        const auto tol=p_.wall*std::max(p_.bay,p_.level);
        for (const auto target : {p_.bay/10,p_.bay/4,3*p_.bay/4,9*p_.bay/10})
            if (std::abs((bx-mast)*(deck-hub)-(fy-hub)*(target-mast))<=tol) return p_.accent;
        return Material::Empty;
    }
};

class TwinMastBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit TwinMastBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4, crown=p_.level/5, deck=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>=crown) return p_.shell;
        const auto tol=p_.wall*std::max(p_.bay,p_.level);
        if (std::abs((bx-left)*(deck-crown)-(fy-crown)*(right-left))<=tol ||
            std::abs((bx-right)*(deck-crown)-(fy-crown)*(left-right))<=tol) return p_.accent;
        return Material::Empty;
    }
};

class AFrameHall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit AFrameHall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto edge=p_.wall+fy*center/std::max<std::int64_t>(1,p_.level-1);
        if (std::abs(std::abs(bx-center)-edge)<=p_.wall) return p_.shell;
        if (fy>=p_.level-p_.wall) return p_.deck;
        if (p_.windows && fy>p_.level/2 && std::abs(bx-center)<p_.bay/8) return p_.glazing;
        return Material::Empty;
    }
};

class ButterflyHall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ButterflyHall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto roof=p_.level/5+(center-std::abs(bx-center))*(p_.level/4)/std::max<std::int64_t>(1,center);
        if (std::abs(fy-roof)<=p_.wall) return p_.accent;
        if ((bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) && fy>=roof) return p_.shell;
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

class ZigguratArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ZigguratArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto tier=std::min<std::int64_t>(3,3*fy/std::max<std::int64_t>(1,p_.level));
        const auto inset=tier*p_.bay/10;
        if (bx<inset || bx>=p_.bay-inset) return Material::Empty;
        const auto slot=p_.bay/8+tier*p_.wall;
        if (std::abs(bx-center)<slot && fy>p_.level/4) return Material::Empty;
        if (std::abs(fy-(tier+1)*p_.level/4)<=p_.wall) return p_.deck;
        return p_.shell;
    }
};

class CorbelArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CorbelArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy<p_.wall) return p_.deck;
        const auto step=std::max<std::int64_t>(1,p_.level/6), course=fy/step;
        const auto half=std::max<std::int64_t>(p_.wall+2,p_.bay/2-course*p_.bay/18);
        if (std::abs(bx-center)<half && fy>p_.level/5) return Material::Empty;
        if (std::abs(std::abs(bx-center)-half)<=p_.wall) return p_.accent;
        return p_.shell;
    }
};

class ChainVault final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ChainVault(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto r=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto band=(floor_div(x,p_.bay)&1)==0?p_.level/3:p_.level/2;
        const auto curve=p_.level/6+band*(r*r-dx*dx)/(r*r);
        if (std::abs(fy-curve)<=p_.wall) return p_.accent;
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

class RingPier final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit RingPier(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), cx=p_.bay/2, cy=p_.level/2;
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        const auto metric=std::abs(bx-cx)*p_.level+std::abs(fy-cy)*p_.bay;
        const auto outer=(p_.bay/3)*p_.level, inner=(p_.bay/5)*p_.level;
        if (metric<=outer && metric>=inner) return p_.accent;
        return Material::Empty;
    }
};

class FoldedPlateHall final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit FoldedPlateHall(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto panel=std::max<std::int64_t>(8,p_.bay/4), local=positive_mod(bx,panel);
        const auto tri=local<=panel/2?local:panel-local;
        const auto roof=p_.level/5+tri*(p_.level/3)/std::max<std::int64_t>(1,panel/2);
        if (std::abs(fy-roof)<=p_.wall) return p_.deck;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy>=roof) return p_.shell;
        return Material::Empty;
    }
};

class SpaceFrame final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SpaceFrame(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto top=p_.level/4, bottom=3*p_.level/4, panel=std::max<std::int64_t>(8,p_.bay/6);
        if (std::abs(fy-top)<=p_.wall || std::abs(fy-bottom)<=p_.wall) return p_.deck;
        const auto local=positive_mod(bx,panel), span=bottom-top, tol=p_.wall*std::max(panel,span);
        if (std::abs(local*span-(fy-top)*panel)<=tol ||
            std::abs((panel-local)*span-(fy-top)*panel)<=tol) return p_.accent;
        return Material::Empty;
    }
};

class CrossbeamStack final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CrossbeamStack(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (std::abs(bx-center)<=p_.wall) return p_.shell;
        for (std::int64_t n=1;n<=5;++n) {
            const auto h=n*p_.level/6, reach=(n%2==0?p_.bay/2:p_.bay/4);
            if (std::abs(fy-h)<=p_.wall && std::abs(bx-center)<=reach)
                return n%2==0?p_.deck:p_.accent;
        }
        return Material::Empty;
    }
};

class YokeBridge final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit YokeBridge(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto left=p_.bay/4, right=3*p_.bay/4, yoke=p_.level/4, deck=2*p_.level/3;
        if (std::abs(fy-yoke)<=p_.wall && bx>=left && bx<=right) return p_.accent;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        if ((std::abs(bx-left)<=p_.wall || std::abs(bx-right)<=p_.wall) && fy>=yoke) return p_.shell;
        return Material::Empty;
    }
};

class LanternTower final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit LanternTower(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (fy>=p_.level/2 && std::abs(bx-center)<=p_.bay/10) return p_.shell;
        if (fy<p_.level/2 && std::abs(bx-center)<=p_.bay/3) {
            if (fy<p_.wall || std::abs(fy-p_.level/2)<=p_.wall) return p_.deck;
            if (std::abs(bx-center)>=p_.bay/3-p_.wall) return p_.accent;
            if (p_.windows) return p_.glazing;
        }
        return Material::Empty;
    }
};

class SpineArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit SpineArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        if (std::abs(bx-center)<=p_.wall) return p_.shell;
        const bool left=(floor_div(y,p_.level)&1)==0;
        const auto side=left?center-bx:bx-center;
        if (side<0) return Material::Empty;
        const auto r=std::max<std::int64_t>(1,center-p_.wall), roof=p_.wall+(p_.level-p_.wall)*side*side/(r*r);
        if (side<r && fy>=roof) return Material::Empty;
        if (side<=r) return p_.accent;
        return Material::Empty;
    }
};

class CascadeTerrace final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CascadeTerrace(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        for (std::int64_t n=0;n<4;++n) {
            const auto h=(n+1)*p_.level/5, start=n*p_.bay/8;
            if (std::abs(fy-h)<=p_.wall && bx>=start) return p_.deck;
            if (std::abs(bx-start)<=p_.wall && fy>=h && fy<(n+2)*p_.level/5) return p_.shell;
        }
        return Material::Empty;
    }
};

class InvertedTrestle final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit InvertedTrestle(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto deck=p_.level/4, foot=3*p_.level/4;
        if (std::abs(fy-deck)<=p_.wall) return p_.deck;
        const auto spread=(fy-deck)*center/std::max<std::int64_t>(1,foot-deck);
        if (fy>=deck && fy<=foot &&
            (std::abs(bx-(center-spread))<=p_.wall || std::abs(bx-(center+spread))<=p_.wall)) return p_.accent;
        return Material::Empty;
    }
};

class CrankedBeam final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit CrankedBeam(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        const auto quarter=std::max<std::int64_t>(1,p_.bay/4), seg=std::min<std::int64_t>(3,bx/quarter);
        const auto local=positive_mod(bx,quarter);
        const std::array<std::int64_t,5> levels{p_.level/3,p_.level/2,2*p_.level/5,3*p_.level/5,p_.level/2};
        const auto beam=levels[seg]+(levels[seg+1]-levels[seg])*local/quarter;
        if (std::abs(fy-beam)<=p_.wall) return p_.accent;
        if ((bx<p_.wall || bx>=p_.bay-p_.wall) && fy>=beam) return p_.shell;
        return Material::Empty;
    }
};

class BarrelArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit BarrelArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto r=std::max<std::int64_t>(1,center), dx=std::abs(bx-center);
        const auto roof=p_.level/6+(p_.level/3)*dx*dx/(r*r);
        if (std::abs(fy-roof)<=p_.wall) return p_.accent;
        if ((bx<p_.wall*2 || bx>=p_.bay-p_.wall*2) && fy>=roof) return p_.shell;
        if (std::abs(fy-2*p_.level/3)<=p_.wall && (bx<p_.bay/4 || bx>3*p_.bay/4)) return p_.deck;
        return Material::Empty;
    }
};

class ButtressCrown final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit ButtressCrown(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level), center=p_.bay/2;
        const auto reach=(p_.level-fy)*(p_.bay/4)/std::max<std::int64_t>(1,p_.level);
        if (bx<reach+p_.wall || bx>=p_.bay-reach-p_.wall) return p_.shell;
        if (fy<p_.level/3 && std::abs(bx-center)<=p_.bay/8) return p_.accent;
        if (fy>=p_.level-p_.wall) return p_.deck;
        return Material::Empty;
    }
};

class TriptychArcade final : public FeatureSampler {
    ArchitectureForm p_;
public:
    explicit TriptychArcade(const ModuleInstance& i) : p_(i) {}
    std::optional<Material> sample(const ModuleContext& c, Material) const override {
        const auto x=c.x-p_.bounds.x, y=c.y-p_.bounds.y;
        if (p_.in_shaft(x)) return Material::Empty;
        const auto bx=positive_mod(x,p_.bay), fy=positive_mod(y,p_.level);
        if (fy<p_.wall || fy>=p_.level-p_.wall) return p_.deck;
        const auto third=std::max<std::int64_t>(8,p_.bay/3), which=std::min<std::int64_t>(2,bx/third);
        const auto start=which*third, width=(which==1?p_.bay-2*third:third), center=start+width/2;
        const auto r=std::max<std::int64_t>(1,width/2-p_.wall), dx=std::abs(bx-center);
        const auto roof=p_.wall+dx*(p_.level-p_.wall)/r;
        if (dx<r && fy>=roof) return Material::Empty;
        if (std::abs(dx-r)<=p_.wall) return p_.accent;
        return p_.shell;
    }
};
