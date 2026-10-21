#include "cybersand/generation_grammar.hpp"
#include "cybersand/generation_numeric.hpp"

#include <algorithm>
#include <bit>
#include <cmath>
#include <limits>
#include <set>
#include <stdexcept>
#include <tuple>
#include <utility>

namespace cybersand::generation {
namespace {
constexpr std::int64_t coordinate_limit = INT64_C(1) << 40;
constexpr std::uint64_t fnv_offset = UINT64_C(14695981039346656037);
constexpr std::uint64_t fnv_prime = UINT64_C(1099511628211);
void need(bool value, const std::string& message) {
    if (!value) throw std::invalid_argument("grammar: " + message);
}
void hash_int(std::uint64_t& h, std::uint64_t value) noexcept {
    for (unsigned i = 0; i < 64; i += 8) { h ^= (value >> i) & 255; h *= fnv_prime; }
}
void hash_text(std::uint64_t& h, const std::string& s) noexcept {
    hash_int(h, s.size());
    for (const unsigned char c : s) { h ^= c; h *= fnv_prime; }
}
void hash_real(std::uint64_t& h, double value) noexcept { hash_int(h, std::bit_cast<std::uint64_t>(value == 0 ? 0.0 : value)); }
void hash_rect(std::uint64_t& h, RectI64 b) noexcept {
    hash_int(h, b.x); hash_int(h, b.y); hash_int(h, b.width); hash_int(h, b.height);
}
std::uint64_t identity_seed(std::uint64_t seed, const std::string& id) noexcept {
    auto h = fnv_offset; hash_int(h, seed); hash_text(h, id); return h;
}
void identifier(const std::string& id) {
    need(!id.empty() && id.size() <= 64, "identifier must have 1..64 characters");
    for (const char c : id) need((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.', "invalid identifier: " + id);
}
void reference(const std::string& id) { need(id.size() <= 2048, "reference length exceeds 2048"); }
bool contains(RectI64 b, std::int64_t x, std::int64_t y) noexcept {
    return x >= b.x && y >= b.y && x < b.x + b.width && y < b.y + b.height;
}
bool encloses(RectI64 a, RectI64 b) noexcept {
    return b.x >= a.x && b.y >= a.y && b.x + b.width <= a.x + a.width && b.y + b.height <= a.y + a.height;
}
bool overlaps(RectI64 a, RectI64 b) noexcept {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}
double area(RectI64 b) noexcept { return static_cast<double>(b.width) * static_cast<double>(b.height); }
double separation(RectI64 a, RectI64 b) noexcept {
    const double dx = static_cast<double>(std::max<std::int64_t>({0, a.x - b.x - b.width, b.x - a.x - a.width}));
    const double dy = static_cast<double>(std::max<std::int64_t>({0, a.y - b.y - b.height, b.y - a.y - a.height}));
    return detail::magnitude(dx, dy);
}
RectI64 interior(RectI64 b, std::uint32_t w) noexcept {
    return {b.x + w, b.y + w, b.width - 2 * static_cast<std::int64_t>(w), b.height - 2 * static_cast<std::int64_t>(w)};
}
void valid_rect(RectI64 b, bool local = false) {
    need(b.width > 0 && b.height > 0 && b.width <= 16384 && b.height <= 16384,
         "rectangle dimensions must be in 1..16384");
    const auto lim = local ? INT64_C(16384) : coordinate_limit;
    need(b.x >= -lim && b.y >= -lim && b.x <= lim - b.width && b.y <= lim - b.height,
         "rectangle exceeds coordinate domain");
}
bool solid(std::optional<Material> material) noexcept {
    if (!material) return false;
    const auto& d = material_definition(*material);
    return d.valid && d.state == MaterialState::Solid;
}
bool valid_material(Material m) noexcept { return cybersand::valid_material(static_cast<std::uint16_t>(m)); }
bool opposite(SocketDirection a, SocketDirection b) noexcept {
    return (a == SocketDirection::West && b == SocketDirection::East) ||
        (a == SocketDirection::East && b == SocketDirection::West) ||
        (a == SocketDirection::North && b == SocketDirection::South) ||
        (a == SocketDirection::South && b == SocketDirection::North);
}
RectI64 segment_box(spatial::Point a, spatial::Point b, std::uint32_t width) noexcept {
    const auto radius = static_cast<std::int64_t>(width / 2);
    const auto x0 = static_cast<std::int64_t>(std::min(a.x, b.x));
    const auto y0 = static_cast<std::int64_t>(std::min(a.y, b.y));
    const auto x1 = static_cast<std::int64_t>(std::max(a.x, b.x));
    const auto y1 = static_cast<std::int64_t>(std::max(a.y, b.y));
    return {x0-radius, y0-radius, x1-x0+2*radius+1, y1-y0+2*radius+1};
}
bool route_contains(const SemanticRoute& route, std::int64_t x, std::int64_t y) noexcept {
    for (std::size_t i = 1; i < route.points.size(); ++i)
        if (contains(segment_box(route.points[i-1], route.points[i], route.width), x, y)) return true;
    return false;
}
double route_distance(const SemanticRoute& route, RectI64 box) noexcept {
    double result = std::numeric_limits<double>::infinity();
    for (std::size_t i = 1; i < route.points.size(); ++i)
        result = std::min(result, separation(box, segment_box(route.points[i-1], route.points[i], route.width)));
    return result;
}
bool route_intersects(const SemanticRoute& route, RectI64 box) noexcept {
    for (std::size_t i = 1; i < route.points.size(); ++i)
        if (overlaps(box, segment_box(route.points[i-1], route.points[i], route.width))) return true;
    return false;
}
spatial::RegionId cell_owner(const GrammarDefinition& d,std::int64_t x,std::int64_t y) noexcept {
    const auto n=d.region_size;return {x/n-static_cast<std::int64_t>(x%n<0),y/n-static_cast<std::int64_t>(y%n<0)};
}
std::string region_id(const GrammarDefinition& d, spatial::RegionId r) {
    // Append into our own string to preserve the retained libstdc++ floor;
    // GCC 13's rvalue concatenation can import its newer replacement helper.
    auto id=d.id;
    id.append("/grid").append(std::to_string(d.region_size)).append("/region(");
    id.append(std::to_string(r.x)).append(",").append(std::to_string(r.y)).append(")");
    return id;
}
std::uint64_t curve_rank(const GrammarDefinition& d, const GrammarCandidate& c) {
    if (d.curve == GrammarCurve::Peano) return spatial::peano_index(d.curve_order, c.order_x, c.order_y);
    return curve_index(d.curve == GrammarCurve::Hilbert ? FieldKind::Hilbert : FieldKind::Morton,
                       d.curve_order, c.order_x, c.order_y);
}
void strings(std::vector<std::string>& values, std::size_t max, const char* name) {
    need(values.size() <= max, std::string(name) + " capacity exceeded");
    for (const auto& value : values) identifier(value);
    std::sort(values.begin(), values.end());
    need(std::adjacent_find(values.begin(), values.end()) == values.end(), std::string("duplicate ") + name);
}
void themes(std::vector<GrammarTheme>& values) {
    need(values.size() <= 16, "theme blend capacity exceeded");
    std::sort(values.begin(), values.end(), [](const auto& a, const auto& b) { return a.id < b.id; });
    double sum = 0;
    for (std::size_t i=0; i<values.size(); ++i) {
        identifier(values[i].id);
        need(std::isfinite(values[i].weight) && values[i].weight > 0 && values[i].weight <= 1e6, "theme weights must be finite positive");
        need(i == 0 || values[i-1].id != values[i].id, "duplicate theme");
        sum += values[i].weight;
    }
    if (sum > 0) for (const auto& value : values)
        need(value.weight / sum > 0, "theme blend normalization underflows a positive weight");
}
std::vector<GrammarTheme> normalized_themes(const std::vector<GrammarTheme>& authored) {
    auto result=authored;double sum=0;for(const auto& value:result)sum+=value.weight;
    if(sum>0)for(auto& value:result)value.weight/=sum;
    return result;
}
bool tag(const SemanticFeature& f, const std::string& t) { return std::binary_search(f.tags.begin(), f.tags.end(), t); }
std::uint64_t feature_revision(const SemanticFeature& f) {
    auto h = fnv_offset; hash_text(h,f.id); hash_text(h,f.parent); hash_text(h,f.rule_id); hash_text(h,f.candidate_id);
    hash_rect(h,f.bounds); hash_int(h,f.seed); hash_int(h,static_cast<unsigned>(f.kind)); hash_int(h,f.priority); hash_int(h,f.order);
    hash_int(h,f.material ? static_cast<unsigned>(*f.material)+1 : 0);
    hash_int(h,f.interior ? static_cast<unsigned>(*f.interior)+1 : 0);
    hash_int(h,f.wall_thickness); hash_text(h,f.aggregate); hash_text(h,f.application); hash_text(h,f.exclusion);
    for (const auto& t : f.tags) hash_text(h,t);
    for (const auto& t : f.themes) { hash_text(h,t.id); hash_real(h,t.weight); }
    for (const auto& [key,v] : f.parameters) {
        hash_text(h,key); hash_int(h,static_cast<unsigned>(v.type)); hash_real(h,v.x); hash_real(h,v.y);
        hash_int(h,v.category.x); hash_int(h,v.category.y); hash_int(h,v.category.domain);
    }
    for (const auto m : f.allowed_materials) hash_int(h,static_cast<unsigned>(m));
    for(const auto& child:f.children)hash_text(h,child);
    for(const auto& socket:f.sockets)hash_text(h,socket);
    const auto& c=f.constraints;
    hash_int(h,c.intersects_route); hash_real(h,c.minimum_separation); hash_int(h,c.floor); hash_int(h,c.ceiling);
    hash_int(h,c.wall); hash_int(h,c.open_volume); hash_text(h,c.service); hash_real(h,c.neighbor_distance);
    hash_text(h,c.exclusive_family); hash_int(h,c.minimum_sockets); hash_int(h,c.maximum_sockets); hash_int(h,c.connected);
    hash_real(h,c.occupancy_min); hash_real(h,c.occupancy_max);
    for(const auto& t:c.required_neighbors)hash_text(h,t);
    for(const auto& t:c.forbidden_neighbors)hash_text(h,t);
    return h;
}
}

struct GrammarPlan::Impl {
    GrammarDefinition definition;
    std::uint64_t seed{}, fingerprint=fnv_offset, work{};
    std::size_t bytes{};
    RectI64 bounds;
    std::vector<SemanticFeature> features;
    std::vector<std::size_t> feature_depths;
    static constexpr std::int64_t bin_size = 64;
    std::size_t bin_columns = 0;
    std::vector<std::vector<std::size_t>> feature_bins, route_bins;
    std::uint64_t sample_cost = 64;
    [[nodiscard]] std::size_t bin(std::int64_t x, std::int64_t y) const noexcept {
        return static_cast<std::size_t>((y-bounds.y)/bin_size)*bin_columns + static_cast<std::size_t>((x-bounds.x)/bin_size);
    }
    std::vector<SemanticSocket> sockets;
    std::vector<SemanticRoute> routes;
    std::vector<ConstraintReceipt> receipts;
    std::shared_ptr<const spatial::PreparedRegions> assignment;
    std::map<std::string,std::size_t> rule_indices;

    void charge(std::uint64_t n) {
        if (n > definition.limits.max_work - work) throw std::runtime_error("grammar: logical work exhausted");
        work += n;
    }
    void memory(std::size_t n) {
        if (n > definition.limits.max_prepared_bytes - bytes) throw std::runtime_error("grammar: prepared memory exhausted");
        bytes += n;
    }
    const GrammarRule& rule(const std::string& id) const { return definition.rules.at(rule_indices.at(id)); }
    void receipt(const std::string& feature, const std::string& rule_id, const std::string& constraint,
                 bool passed, std::string detail, bool fallback=false) {
        charge(16); memory(512 + 2*(feature.size() + rule_id.size() + constraint.size() + detail.size()));
        receipts.push_back({feature, rule_id, constraint, std::move(detail), passed, fallback});
    }
    void add_feature(SemanticFeature f) {
        need(features.size() < definition.limits.max_features, "feature capacity exceeded");
        charge(64); memory(4096 + f.id.size()*8 + f.parameters.size()*384 + f.tags.size()*192 + f.themes.size()*192 +
            2*(f.aggregate.size()+f.application.size()+f.exclusion.size()));
        f.seed=identity_seed(seed,f.id); f.revision=feature_revision(f);
        features.push_back(std::move(f));
    }
    void add_socket(SemanticSocket socket) {
        const auto found=std::find_if(sockets.begin(),sockets.end(),[&](const auto& s){return s.id==socket.id;});
        charge(sockets.size()+32);
        if(found!=sockets.end()) {
            need(found->shared && socket.shared && found->x==socket.x && found->y==socket.y &&
                found->type==socket.type && found->width==socket.width && found->owner==socket.owner,
                "incompatible shared socket " + socket.id);
            return;
        }
        need(sockets.size()<definition.limits.max_sockets,"socket capacity exceeded");
        memory(1024+2*(socket.id.size()+socket.feature_id.size()+socket.matched.size()));
        sockets.push_back(std::move(socket));
    }
    void add_route(SemanticRoute route) {
        need(routes.size()<definition.limits.max_routes,"route capacity exceeded");
        need(route.points.size()>=2 && route.points.size()<=256,"route point capacity");
        for(std::size_t i=1;i<route.points.size();++i)
            need(route.points[i-1].x==route.points[i].x || route.points[i-1].y==route.points[i].y,"route must be rectilinear");
        charge(32+route.points.size()*8); memory(1024+2*(route.id.size()+route.from_socket.size()+route.to_socket.size()+route.points.size()*sizeof(spatial::Point)));
        routes.push_back(std::move(route));
    }
    void build_region_routes(spatial::RegionId owner) {
        const auto& d=definition; const auto n=static_cast<std::int64_t>(d.region_size);
        const auto x=owner.x*n, y=owner.y*n;
        const auto rid=region_id(d,owner);
        const spatial::Point hub{static_cast<double>(x+n/2),static_cast<double>(y+n/2)};
        add_socket({rid+"/hub",rid,"passage","",owner,x+n/2,y+n/2,SocketDirection::North,d.route_width,false,false});
        const char* names[]={"west","east","north","south"};
        for(unsigned side=0;side<4;++side) {
            const bool vertical=side<2;
            const auto bx=owner.x+static_cast<std::int64_t>(side==1);
            const auto by=owner.y+static_cast<std::int64_t>(side==3);
            auto key=d.id;
            key.append("/grid").append(std::to_string(d.region_size)).append("/boundary/").append(vertical?"x/":"y/");
            key.append(std::to_string(bx)).append("/").append(std::to_string(by));
            const auto h=identity_seed(seed,key);
            // Width-independent central aperture coordinate. The boundary key
            // and seed, never either neighbor's compilation window, determine it.
            const auto offset=n/3+static_cast<std::int64_t>(h%static_cast<std::uint64_t>(n/3));
            const std::int64_t sx=vertical?bx*n:x+offset;
            const std::int64_t sy=vertical?y+offset:by*n;
            const spatial::RegionId boundary_owner{vertical?bx-1:owner.x,vertical?owner.y:by-1};
            const auto local=rid+"/port/"+names[side];
            add_socket({key,region_id(d,boundary_owner),"passage","",boundary_owner,sx,sy,
                        vertical?SocketDirection::East:SocketDirection::South,d.route_width,true,true});
            add_socket({local,rid,"passage",key,owner,sx,sy,static_cast<SocketDirection>(side),d.route_width,true,false});
            const spatial::Point port{static_cast<double>(sx),static_cast<double>(sy)};
            std::vector<spatial::Point> points{hub};
            if(vertical)points.push_back({hub.x,port.y}); else points.push_back({port.x,hub.y});
            points.push_back(port);
            add_route({rid+"/route/"+names[side],"passage",rid+"/hub",local,owner,std::move(points),d.route_width,true,Material::Empty});
        }
        if(d.secondary_loop) {
            const double left=static_cast<double>(x+n/4), right=static_cast<double>(x+3*n/4);
            const double top=static_cast<double>(y+n/4), bottom=static_cast<double>(y+3*n/4);
            add_route({rid+"/route/loop","passage","","",owner,
                {{left,top},{right,top},{right,bottom},{left,bottom},{left,top}},d.route_width,true,Material::Empty});
            // The loop is an explicit connected edge chain, never an inference
            // from curve ordering. A named link joins it to the primary hub.
            add_route({rid+"/route/loop-link","passage","","",owner,
                {hub,{hub.x,top}},d.route_width,true,Material::Empty});
        }
        const auto utility=[&](const std::string& type,std::int64_t row,std::uint32_t width,Material material) {
            for(unsigned side=0;side<2;++side) {
                const auto bx=owner.x+side;const spatial::RegionId boundary_owner{bx-1,owner.y};
                auto key=d.id;
                key.append("/grid").append(std::to_string(d.region_size)).append("/boundary/").append(type).append("/x/");
                key.append(std::to_string(bx)).append("/").append(std::to_string(owner.y));
                add_socket({key,region_id(d,boundary_owner),type,"",boundary_owner,bx*n,row,SocketDirection::East,width,false,true});
                add_socket({rid+"/port/"+type+(side==0?"-west":"-east"),rid,type,key,owner,bx*n,row,
                    side==0?SocketDirection::West:SocketDirection::East,width,false,false});
            }
            add_route({rid+"/route/"+type,type,rid+"/port/"+type+"-west",rid+"/port/"+type+"-east",owner,
                {{static_cast<double>(x),static_cast<double>(row)},{static_cast<double>(x+n),static_cast<double>(row)}},width,false,material});
        };
        if(d.service_trunk)utility("service",y+n/4-8,1,d.service_material);
        if(d.liquid_trunk)utility("liquid",y+3*n/4+8,3,d.liquid_material);
        if(d.curve_services) {
            const auto side=d.curve==GrammarCurve::Peano?spatial::peano_side(d.curve_order):(1U<<d.curve_order);
            const auto inset=n/8, extent=n-2*inset;
            std::vector<spatial::Point> points;
            for(std::uint32_t rank=0;rank<side*side;++rank) {
                std::uint32_t cx{},cy{};
                if(d.curve==GrammarCurve::Peano){const auto p=spatial::peano_point(d.curve_order,rank);cx=p.x;cy=p.y;}
                else {const auto p=curve_point(d.curve==GrammarCurve::Hilbert?FieldKind::Hilbert:FieldKind::Morton,d.curve_order,rank);cx=p.x;cy=p.y;}
                const spatial::Point site{static_cast<double>(x+inset+(2*cx+1)*extent/(2*side)),
                    static_cast<double>(y+inset+(2*cy+1)*extent/(2*side))};
                if(points.empty())points.push_back({site.x,static_cast<double>(y+n/4-8)});
                else if(points.back().x!=site.x&&points.back().y!=site.y)points.push_back({site.x,points.back().y});
                points.push_back(site);
            }
            points.push_back({points.back().x,static_cast<double>(y+n/4-8)});
            add_route({rid+"/route/service-tour","service","","",owner,std::move(points),1,false,d.service_material});
        }
    }
    bool supported(const SemanticFeature& parent, RectI64 candidate, const GrammarConstraints& c,
                   const std::vector<std::size_t>& siblings) {
        bool floor=false,ceiling=false,wall=false;
        if(solid(parent.material) && parent.wall_thickness>0) {
            const auto in=interior(parent.bounds,parent.wall_thickness);
            floor=candidate.y+candidate.height==in.y+in.height && candidate.x>=in.x && candidate.x+candidate.width<=in.x+in.width;
            ceiling=candidate.y==in.y && candidate.x>=in.x && candidate.x+candidate.width<=in.x+in.width;
            wall=(candidate.x==in.x || candidate.x+candidate.width==in.x+in.width) && candidate.y>=in.y && candidate.y+candidate.height<=in.y+in.height;
        }
        for(const auto index:siblings) {
            charge(8); const auto& f=features[index]; if(f.candidate_id.empty()||!solid(f.material))continue;
            const auto b=f.bounds;
            const bool horizontal=candidate.x<b.x+b.width && b.x<candidate.x+candidate.width;
            const bool vertical=candidate.y<b.y+b.height && b.y<candidate.y+candidate.height;
            floor|=horizontal&&candidate.y+candidate.height==b.y;
            ceiling|=horizontal&&candidate.y==b.y+b.height;
            wall|=vertical&&(candidate.x+candidate.width==b.x || candidate.x==b.x+b.width);
        }
        return (!c.floor||floor)&&(!c.ceiling||ceiling)&&(!c.wall||wall);
    }
    std::string candidate_failure(const SemanticFeature& parent, RectI64 b, const GrammarRule& r,
                                  const std::vector<std::size_t>& siblings) {
        std::uint64_t route_work=0;for(const auto& route:routes)route_work+=16+route.points.size()*16;
        charge(32+route_work+siblings.size()*16);
        if(!encloses(parent.bounds,b))return "bounds: candidate lies outside its canonical parent";
        if(r.wall_thickness>0 && (2*r.wall_thickness>=b.width || 2*r.wall_thickness>=b.height))
            return "bounds: shell consumes its interior";
        if(r.constraints.open_volume && parent.interior && *parent.interior!=Material::Empty)
            return "open_volume: parent declares occupied interior";
        if(r.constraints.open_volume && parent.wall_thickness>0 && !encloses(interior(parent.bounds,parent.wall_thickness),b))
            return "open_volume: candidate intersects parent shell";
        if(r.constraints.intersects_route) {
            bool found=false;for(const auto& route:routes)if(route.owner==parent.owner&&route.type=="passage"&&route_intersects(route,b)){found=true;break;}
            if(!found)return "intersects_route: no declared passage intersects candidate";
        }
        if(!r.constraints.service.empty()) {
            bool found=false;for(const auto& route:routes)if(route.owner==parent.owner&&route.type==r.constraints.service&&
                route_distance(route,b)<=r.constraints.neighbor_distance){found=true;break;}
            if(!found)return "service: required declared service is out of reach";
        }
        if(r.sockets.size()<r.constraints.minimum_sockets||r.sockets.size()>r.constraints.maximum_sockets)
            return "socket_count: declared socket count cannot satisfy constraints";
        for(const auto& socket:r.sockets) {
            const bool vertical=socket.direction==SocketDirection::West||socket.direction==SocketDirection::East;
            const auto edge=vertical?b.height:b.width;const auto half=static_cast<std::int64_t>(socket.width/2);
            if(socket.offset<half||socket.offset+half>=edge)return "socket_geometry: aperture exceeds feature edge";
            if(socket.attach_to_route) {
                const auto sx=vertical?(socket.direction==SocketDirection::West?b.x:b.x+b.width-1):b.x+socket.offset;
                const auto sy=vertical?b.y+socket.offset:(socket.direction==SocketDirection::North?b.y:b.y+b.height-1);
                const auto rx=parent.owner.x*definition.region_size,ry=parent.owner.y*definition.region_size;
                if(sx<rx+half||sy<ry+half||sx>=rx+definition.region_size-half||sy>=ry+definition.region_size-half)
                    return "socket_geometry: aperture escapes owner region";
                const auto space=socket.direction==SocketDirection::West?sx-rx-half:
                    socket.direction==SocketDirection::East?rx+definition.region_size-1-half-sx:
                    socket.direction==SocketDirection::North?sy-ry-half:ry+definition.region_size-1-half-sy;
                if(space<1)return "socket_geometry: outward connector escapes owner region";
                bool available=false;
                for(const auto& route:routes)if(route.owner==parent.owner&&route.type==socket.type&&route.width>=socket.width)available=true;
                if(socket.required&&!available)return "socket_geometry: no compatible route aperture";
            }
        }
        if(!supported(parent,b,r.constraints,siblings))return "support: required floor, ceiling or wall is absent";
        for(const auto index:siblings) {
            const auto& other=features[index];
            if(other.candidate_id.empty())continue;
            if((r.constraints.open_volume||other.constraints.open_volume)&&overlaps(b,other.bounds))return "open_volume: occupied by "+other.id;
            if(separation(b,other.bounds)<std::max(r.constraints.minimum_separation,other.constraints.minimum_separation))
                return "separation: too close to "+other.id;
            if(!r.constraints.exclusive_family.empty()&&r.constraints.exclusive_family==other.constraints.exclusive_family)
                return "exclusive_family: already occupied by "+other.id;
            for(const auto& forbidden:r.constraints.forbidden_neighbors)if(tag(other,forbidden)&&
                separation(b,other.bounds)<=r.constraints.neighbor_distance)return "forbidden_neighbors: "+other.id;
        }
        return {};
    }
    double preference_score(const SemanticFeature& parent, RectI64 b, const GrammarRule& r,
                            const GrammarCandidate& candidate, const std::vector<std::size_t>& siblings) {
        double score=0;
        for(const auto& pref:r.preferences) {
            std::uint64_t route_work=0;for(const auto& route:routes)route_work+=16+route.points.size()*16;
            charge(16+route_work+siblings.size()*16);
            double value=0;
            if(pref.kind=="route") {
                double distance=definition.region_size*2;
                for(const auto& route:routes)if(route.owner==parent.owner&&route.type=="passage")distance=std::min(distance,route_distance(route,b));
                value=-distance;
            } else if(pref.kind=="floor")value=-std::abs(static_cast<double>(b.y+b.height-parent.bounds.y-parent.bounds.height+parent.wall_thickness));
            else if(pref.kind=="ceiling")value=-std::abs(static_cast<double>(b.y-parent.bounds.y-parent.wall_thickness));
            else if(pref.kind=="wall")value=-std::min(std::abs(static_cast<double>(b.x-parent.bounds.x-parent.wall_thickness)),
                std::abs(static_cast<double>(b.x+b.width-parent.bounds.x-parent.bounds.width+parent.wall_thickness)));
            else if(pref.kind=="curve_density")value=-static_cast<double>(curve_rank(definition,candidate));
            else if(pref.kind=="theme_boundary") {
                // Declared sibling feature boxes carry the two named themes;
                // preferences use semantic geometry, never material samples.
                double first=definition.region_size*2,second=first;
                for(const auto index:siblings) {
                    const auto& f=features[index];
                    if(f.candidate_id.empty())continue;
                    for(const auto& t:f.themes)if(t.id==pref.themes[0])first=std::min(first,separation(b,f.bounds));
                        else if(t.id==pref.themes[1])second=std::min(second,separation(b,f.bounds));
                }
                value=-std::max(first,second);
            }
            score+=pref.weight*value;
        }
        return score;
    }
    void attach(std::size_t feature_index,const GrammarRule& r) {
        // Copy: appending sockets/routes never mutates or reallocates features.
        auto& f=features[feature_index];
        for(const auto& templ:r.sockets) {
            const auto b=f.bounds;const bool vertical=templ.direction==SocketDirection::West||templ.direction==SocketDirection::East;
            const auto edge=vertical?b.height:b.width;
            need(templ.offset>=static_cast<std::int64_t>(templ.width/2)&&templ.offset+templ.width/2<edge,
                "socket aperture exceeds feature edge: "+f.id+"/"+templ.id);
            const std::int64_t x=vertical?(templ.direction==SocketDirection::West?b.x:b.x+b.width-1):b.x+templ.offset;
            const std::int64_t y=vertical?b.y+templ.offset:(templ.direction==SocketDirection::North?b.y:b.y+b.height-1);
            SemanticSocket socket{f.id+"/socket/"+templ.id,f.id,templ.type,"",f.owner,x,y,templ.direction,templ.width,templ.required,false};
            if(templ.attach_to_route) {
                const SemanticRoute* closest=nullptr;spatial::Point destination{};double distance=std::numeric_limits<double>::infinity();
                for(const auto& route:routes) {
                    charge(16*route.points.size());
                    if(route.owner!=f.owner||route.type!=templ.type)continue;
                    if(route.width<templ.width)continue;
                    // Attach only to predeclared regional routes. This makes
                    // attachments independent of sibling declaration order.
                    if(route.id.find("/route/")==std::string::npos)continue;
                    for(std::size_t j=1;j<route.points.size();++j) {
                        const auto a=route.points[j-1],bpoint=route.points[j];
                        const spatial::Point point{std::clamp(static_cast<double>(x),std::min(a.x,bpoint.x),std::max(a.x,bpoint.x)),
                            std::clamp(static_cast<double>(y),std::min(a.y,bpoint.y),std::max(a.y,bpoint.y))};
                        const auto dist=std::abs(point.x-static_cast<double>(x))+std::abs(point.y-static_cast<double>(y));
                        if(dist<distance || (dist==distance && closest && route.id<closest->id)){closest=&route;destination=point;distance=dist;}
                    }
                }
                if(closest) {
                    const auto radius=static_cast<std::int64_t>(templ.width/2);
                    const auto region_x=f.owner.x*definition.region_size,region_y=f.owner.y*definition.region_size;
                    destination.x=std::clamp(destination.x,static_cast<double>(region_x+radius),static_cast<double>(region_x+definition.region_size-1-radius));
                    destination.y=std::clamp(destination.y,static_cast<double>(region_y+radius),static_cast<double>(region_y+definition.region_size-1-radius));
                    socket.matched=closest->id;
                    const auto mate=socket.id+"/attachment";
                    socket.matched=mate;
                    const spatial::Point start{static_cast<double>(x),static_cast<double>(y)};
                    // First step follows the socket's declared outward normal;
                    // the rest is an explicit L route to a compatible trunk.
                    const auto half=static_cast<std::int64_t>(templ.width/2);
                    const auto space=templ.direction==SocketDirection::West?x-region_x-half:
                        templ.direction==SocketDirection::East?region_x+definition.region_size-1-half-x:
                        templ.direction==SocketDirection::North?y-region_y-half:region_y+definition.region_size-1-half-y;
                    need(space>=1,"socket outward connector escapes canonical owner: "+socket.id);
                    const auto reach=static_cast<double>(std::min<std::int64_t>(space,std::max<std::uint32_t>(templ.width,f.wall_thickness+1)));
                    const spatial::Point exit{start.x+(templ.direction==SocketDirection::West?-reach:templ.direction==SocketDirection::East?reach:0),
                        start.y+(templ.direction==SocketDirection::North?-reach:templ.direction==SocketDirection::South?reach:0)};
                    std::vector<spatial::Point> path{start,exit,{destination.x,exit.y},destination};
                    auto previous=path.size()-2;
                    while(previous>0&&path[previous].x==destination.x&&path[previous].y==destination.y)--previous;
                    const auto direction=path[previous].x<destination.x?SocketDirection::West:
                        path[previous].x>destination.x?SocketDirection::East:
                        path[previous].y<destination.y?SocketDirection::North:SocketDirection::South;
                    add_socket({mate,closest->id,templ.type,socket.id,f.owner,static_cast<std::int64_t>(destination.x),static_cast<std::int64_t>(destination.y),direction,templ.width,templ.required,false});
                    add_route({f.id+"/connection/"+templ.id,templ.type,socket.id,mate,f.owner,
                        std::move(path),templ.width,templ.type=="passage"&&templ.required,
                        templ.type=="passage"?Material::Empty:closest->material});
                }
            }
            f.sockets.push_back(socket.id);add_socket(std::move(socket));
        }
    }
    void expand(std::size_t parent_index,const std::vector<std::string>& children,std::size_t depth) {
        if(children.empty())return;
        need(depth<=definition.limits.max_depth,"hierarchy depth exhausted");
        need(children.size()<=definition.limits.max_children,"child rule capacity exceeded");
        auto ordered=children;
        std::sort(ordered.begin(),ordered.end(),[&](const auto& a,const auto& b){
            const auto& ra=rule(a);const auto& rb=rule(b);return ra.priority!=rb.priority?ra.priority>rb.priority:a<b;});
        std::vector<std::size_t> siblings;
        for(const auto& id:ordered) {
            const auto& r=rule(id);
            const auto parent=features[parent_index]; // no alias across vector growth
            std::set<std::string> used;
            std::vector<std::size_t> placed;
            for(std::uint32_t slot=0;slot<r.count;++slot) {
                auto fid=parent.id;fid.append("/").append(r.id).append("/").append(std::to_string(slot));
                struct Choice{const GrammarCandidate* c;RectI64 bounds;double score;std::uint64_t rank;};
                std::vector<Choice> choices;choices.reserve(r.candidates.size());
                for(const auto& c:r.candidates) {
                    charge(16);
                    if(used.contains(c.id))continue;
                    RectI64 b{parent.bounds.x+c.bounds.x,parent.bounds.y+c.bounds.y,c.bounds.width,c.bounds.height};
                    choices.push_back({&c,b,preference_score(parent,b,r,c,siblings),curve_rank(definition,c)});
                }
                std::sort(choices.begin(),choices.end(),[](const auto& a,const auto& b){
                    if(a.score!=b.score)return a.score>b.score;
                    if(a.rank!=b.rank)return a.rank<b.rank;
                    return a.c->id<b.c->id;});
                const Choice* selected=nullptr;std::string failure="multiplicity: no unused candidate";
                for(const auto& choice:choices) {
                    failure=candidate_failure(parent,choice.bounds,r,siblings);
                    if(failure.empty()){selected=&choice;break;}
                    receipt(fid,r.id,"candidate",false,choice.c->id+": "+failure);
                }
                if(!selected) {
                    if(r.fallback==GrammarFallback::Reject)throw std::runtime_error("grammar: "+fid+": "+failure);
                    receipt(fid,r.id,"fallback",false,"authored omit: "+failure,true);continue;
                }
                SemanticFeature f;f.id=fid;f.parent=parent.id;f.rule_id=r.id;f.candidate_id=selected->c->id;f.kind=r.kind;
                f.bounds=selected->bounds;f.owner=parent.owner;f.order=selected->rank;f.priority=r.priority;
                f.tags=r.tags;f.themes=r.themes.empty()?parent.themes:normalized_themes(r.themes);f.parameters=r.parameters;
                f.allowed_materials=r.allowed_materials;f.constraints=r.constraints;f.material=r.material;f.interior=r.interior;
                f.wall_thickness=r.wall_thickness;f.aggregate=r.aggregate;f.application=r.application;f.exclusion=r.exclusion;
                const auto index=features.size();add_feature(std::move(f));
                features[parent_index].children.push_back(fid);siblings.push_back(index);placed.push_back(index);used.insert(selected->c->id);
                std::string placement("candidate=");
                placement.append(selected->c->id).append("; hard constraints passed; preference=").append(std::to_string(selected->score));
                placement.append("; curve rank=").append(std::to_string(selected->rank));
                receipt(fid,r.id,"placement",true,std::move(placement));
                attach(index,r);
            }
            double occupied=0;for(const auto index:placed)occupied+=area(features[index].bounds);
            const double fraction=occupied/area(parent.bounds);
            const bool quota=fraction>=r.constraints.occupancy_min&&fraction<=r.constraints.occupancy_max;
            if(!quota) {
                if(r.fallback==GrammarFallback::Reject)throw std::runtime_error("grammar: "+parent.id+"/"+r.id+": occupancy range unsatisfied");
                // No alternate quota is silently substituted. Explicit omit
                // removes this rule's complete sibling group before recursion.
                for(const auto index:placed)features[index].candidate_id.clear();
                std::string detail("authored omit: area fraction ");detail.append(std::to_string(fraction));
                receipt(parent.id,r.id,"occupancy",false,std::move(detail),true);
            } else {
                std::string detail("area fraction ");detail.append(std::to_string(fraction));
                receipt(parent.id,r.id,"occupancy",true,std::move(detail));
            }
        }
        // Sibling declarations are all visible before semantic neighbor checks.
        // Greedy priority placement is deliberately finite, not a claim of a
        // complete general-purpose constraint solver.
        for(const auto index:siblings) {
            auto& f=features[index];if(f.candidate_id.empty())continue;const auto& r=rule(f.rule_id);
            std::string failure;
            for(const auto& required:f.constraints.required_neighbors) {
                bool found=false;for(const auto other:siblings) {
                    charge(8);if(other!=index&&!features[other].candidate_id.empty()&&tag(features[other],required)&&
                        separation(f.bounds,features[other].bounds)<=f.constraints.neighbor_distance){found=true;break;}
                }
                if(!found){failure="required_neighbors: missing "+required;break;}
            }
            for(const auto& forbidden:f.constraints.forbidden_neighbors)for(const auto other:siblings) {
                charge(8);if(other!=index&&!features[other].candidate_id.empty()&&tag(features[other],forbidden)&&
                    separation(f.bounds,features[other].bounds)<=f.constraints.neighbor_distance)failure="forbidden_neighbors: "+features[other].id;
            }
            if(!failure.empty()) {
                if(r.fallback==GrammarFallback::Reject)throw std::runtime_error("grammar: "+f.id+": "+failure);
                receipt(f.id,r.id,"neighbors",false,"authored omit: "+failure,true);f.candidate_id.clear();
            } else receipt(f.id,r.id,"neighbors",true,"required and forbidden neighbor tags satisfied");
        }
        // Recheck after omission so an omitted neighbor cannot satisfy a later
        // published hard requirement. Fail transactionally rather than recurse.
        for(const auto index:siblings) {
            const auto f=features[index];if(f.candidate_id.empty())continue;
            for(const auto& required:f.constraints.required_neighbors) {
                bool found=false;for(const auto other:siblings){charge(8);if(other!=index&&!features[other].candidate_id.empty()&&tag(features[other],required)&&separation(f.bounds,features[other].bounds)<=f.constraints.neighbor_distance)found=true;}
                if(!found)throw std::runtime_error("grammar: "+f.id+": required neighbor removed by authored fallback");
            }
            expand(index,rule(f.rule_id).children,depth+1);
        }
    }
};

std::shared_ptr<const GrammarPlan> GrammarPlan::compile(GrammarDefinition definition,std::uint64_t seed) {
    const auto& l=definition.limits;
    need(definition.schema==kGrammarSchemaVersion,"unsupported schema");identifier(definition.id);
    need(l.max_regions>0&&l.max_regions<=64&&l.max_rules>0&&l.max_rules<=128&&l.max_depth>0&&l.max_depth<=12&&
         l.max_children>0&&l.max_children<=64&&l.max_candidates>0&&l.max_candidates<=256&&
         l.max_features>0&&l.max_features<=8192&&l.max_sockets>0&&l.max_sockets<=16384&&l.max_routes>0&&l.max_routes<=16384,
         "invalid structural limits");
    need(l.max_work>0&&l.max_work<=UINT64_C(1'000'000'000)&&l.max_prepared_bytes>0&&l.max_prepared_bytes<=256*1024*1024&&
         l.max_raster_cells>0&&l.max_raster_cells<=UINT64_C(16'777'216)&&l.max_raster_operations>0&&l.max_raster_operations<=UINT64_C(16'000'000'000),
         "invalid work/memory limits");
    need(definition.region_size>=64&&definition.region_size<=2048,"region_size must be in 64..2048");
    const auto window=definition.region_window;
    need(window.width>0&&window.height>0&&window.width<=64&&window.height<=64&&
         static_cast<std::uint64_t>(window.width)*window.height<=l.max_regions,"region window exceeds finite region capacity");
    const auto n=static_cast<std::int64_t>(definition.region_size);
    const auto bound=coordinate_limit/n-2;
    need(window.x>=-bound&&window.y>=-bound&&window.x<=bound-window.width&&window.y<=bound-window.height,
         "region window exceeds coordinate domain");
    need(definition.curve==GrammarCurve::Hilbert||definition.curve==GrammarCurve::Morton||definition.curve==GrammarCurve::Peano,"invalid curve");
    need(definition.curve_order>0&&definition.curve_order<=6,"curve_order must be in 1..6");
    const auto side=definition.curve==GrammarCurve::Peano?spatial::peano_side(definition.curve_order):(1U<<definition.curve_order);
    need(!definition.curve_services || (definition.service_trunk && side*side<=16),"curve_services needs service trunk and at most16 finite sites");
    need(definition.clearance>0&&definition.clearance<=31&&(definition.clearance&1U)!=0,"clearance must be odd in 1..31");
    need(definition.route_width>=definition.clearance&&definition.route_width<=31&&(definition.route_width&1U)!=0&&definition.route_width<=static_cast<std::uint32_t>(definition.region_size/4),
         "route_width must be odd, fit region and meet clearance");
    need(valid_material(definition.service_material)&&valid_material(definition.liquid_material),"invalid service/liquid material");
    need(definition.geometry_exports.size()<=16,"geometry export capacity exceeded");
    for(const auto& [alias,target]:definition.geometry_exports){identifier(alias);reference(target);need(!target.empty(),"empty geometry export target");}
    need(!definition.roots.empty()&&!definition.rules.empty(),"grammar needs roots and rules");
    strings(definition.roots,l.max_children,"root rules");
    need(definition.rules.size()<=l.max_rules,"rule capacity exceeded");
    std::sort(definition.rules.begin(),definition.rules.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    std::map<std::string,std::size_t> indices;
    std::set<std::string> theme_names;
    need(definition.district_themes.size()<=16,"district theme mapping capacity exceeded");
    for(auto& [category,blend]:definition.district_themes){(void)category;themes(blend);for(const auto& t:blend)theme_names.insert(t.id);}
    for(std::size_t i=0;i<definition.rules.size();++i) {
        auto& r=definition.rules[i];identifier(r.id);need(indices.emplace(r.id,i).second,"duplicate rule "+r.id);
        need(static_cast<unsigned>(r.kind)<=static_cast<unsigned>(SemanticKind::Detail),"invalid feature kind");
        need(r.count>0&&r.count<=l.max_children,"exact multiplicity exceeds child capacity");
        need(r.priority>=-1'000'000&&r.priority<=1'000'000,"priority outside supported range");
        strings(r.tags,16,"tags");strings(r.children,l.max_children,"child rules");themes(r.themes);
        for(const auto& t:r.themes)theme_names.insert(t.id);
        need(r.parameters.size()<=32,"typed parameter capacity exceeded");
        for(const auto& [key,value]:r.parameters) {
            identifier(key);need(static_cast<unsigned>(value.type)<=static_cast<unsigned>(SpatialType::Boolean)&&
                std::isfinite(value.x)&&std::isfinite(value.y)&&std::abs(value.x)<=1e100&&std::abs(value.y)<=1e100,"invalid typed parameter");
            if(value.type==SpatialType::Normalized)need(value.x>=0&&value.x<=1,"normalized parameter outside [0,1]");
            if(value.type==SpatialType::Boolean)need(value.x==0||value.x==1,"boolean parameter must be 0 or 1");
            if(value.type!=SpatialType::Vector2)need(value.y==0,"nonvector parameter has nonzero y payload");
            if(value.type==SpatialType::Category)need(value.x==0&&value.y==0,"category parameter carries floating payload");
            else need(value.category==SpatialCategory{},"noncategory parameter carries category payload");
            if(value.type==SpatialType::Distance)need(value.x>=0,"distance parameter must be nonnegative");
        }
        need(r.allowed_materials.size()<=132,"material constraint capacity exceeded");
        std::sort(r.allowed_materials.begin(),r.allowed_materials.end());
        need(std::adjacent_find(r.allowed_materials.begin(),r.allowed_materials.end())==r.allowed_materials.end(),"duplicate allowed material");
        for(const auto m:r.allowed_materials)need(valid_material(m),"invalid allowed material");
        for(const auto m:{r.material,r.interior})if(m) {
            need(valid_material(*m),"invalid feature material");
            need(r.allowed_materials.empty()||std::binary_search(r.allowed_materials.begin(),r.allowed_materials.end(),*m),"feature material violates declared material constraints");
        }
        need(r.wall_thickness<=128,"wall thickness exceeds128");
        for(const auto& ref:{r.aggregate,r.application,r.exclusion})reference(ref);
        if(!r.aggregate.empty())identifier(r.aggregate);
        need(r.candidates.size()>0&&r.candidates.size()<=l.max_candidates,"candidate capacity exceeded");
        std::sort(r.candidates.begin(),r.candidates.end(),[](const auto& a,const auto& b){return a.id<b.id;});
        for(std::size_t j=0;j<r.candidates.size();++j) {
            const auto& c=r.candidates[j];identifier(c.id);need(j==0||r.candidates[j-1].id!=c.id,"duplicate candidate ID");
            valid_rect(c.bounds,true);need(c.order_x<side&&c.order_y<side,"candidate outside finite curve domain");
        }
        auto& c=r.constraints;
        need(std::isfinite(c.minimum_separation)&&c.minimum_separation>=0&&c.minimum_separation<=16384&&
             std::isfinite(c.neighbor_distance)&&c.neighbor_distance>=0&&c.neighbor_distance<=16384,
             "invalid separation/neighbor radius");
        need(std::isfinite(c.occupancy_min)&&std::isfinite(c.occupancy_max)&&c.occupancy_min>=0&&
             c.occupancy_max<=1&&c.occupancy_min<=c.occupancy_max,"invalid occupancy range");
        strings(c.required_neighbors,16,"required neighbors");strings(c.forbidden_neighbors,16,"forbidden neighbors");
        for(const auto& required:c.required_neighbors)need(!std::binary_search(c.forbidden_neighbors.begin(),c.forbidden_neighbors.end(),required),"contradictory required/forbidden neighbor");
        need(c.service.empty()||c.service=="service"||c.service=="liquid","unknown service type");
        if(!c.exclusive_family.empty())identifier(c.exclusive_family);
        need(c.minimum_sockets<=c.maximum_sockets&&c.maximum_sockets<=16,"invalid socket counts");
        need(r.sockets.size()<=16,"socket declaration capacity exceeded");
        std::sort(r.sockets.begin(),r.sockets.end(),[](const auto& a,const auto& b){return a.id<b.id;});
        for(std::size_t j=0;j<r.sockets.size();++j) {
            const auto& s=r.sockets[j];identifier(s.id);need(j==0||r.sockets[j-1].id!=s.id,"duplicate socket ID");
            need(s.type=="passage"||s.type=="service"||s.type=="liquid","unsupported socket type");
            need(static_cast<unsigned>(s.direction)<=static_cast<unsigned>(SocketDirection::South),"invalid socket direction");
            need(s.offset>=0&&s.offset<=16384&&s.width>0&&s.width<=31&&(s.width&1U)!=0,"invalid socket aperture");
            if(s.type=="passage")need(s.width>=definition.clearance,"passage socket narrower than clearance");
        }
        need(r.preferences.size()<=16,"preference capacity exceeded");
        std::sort(r.preferences.begin(),r.preferences.end(),[](const auto& a,const auto& b){return a.id<b.id;});
        for(std::size_t j=0;j<r.preferences.size();++j) {
            auto& pref=r.preferences[j];identifier(pref.id);need(j==0||r.preferences[j-1].id!=pref.id,"duplicate preference ID");
            need(pref.kind=="route"||pref.kind=="theme_boundary"||pref.kind=="floor"||pref.kind=="ceiling"||pref.kind=="wall"||pref.kind=="curve_density","unknown weighted preference");
            need(std::isfinite(pref.weight)&&std::abs(pref.weight)<=1e6,"invalid preference weight");
            strings(pref.themes,2,"preference themes");
            need(pref.kind=="theme_boundary"?pref.themes.size()==2:pref.themes.empty(),"theme preference needs exactly two themes");
        }
        need(r.fallback==GrammarFallback::Reject||r.fallback==GrammarFallback::Omit,"invalid fallback");
    }
    for(const auto& r:definition.rules)for(const auto& pref:r.preferences)for(const auto& t:pref.themes)
        need(theme_names.contains(t),"unknown theme-boundary preference theme: "+t);
    std::vector<unsigned> visiting(definition.rules.size());
    std::vector<std::uint64_t> expansion(definition.rules.size());
    std::vector<std::size_t> depths(definition.rules.size());
    // Visiting recursion has at most128 rules; explicit depth is checked before
    // descent and unused declarations receive the same cycle/depth checks.
    auto visit=[&](auto&& self,std::size_t index,std::size_t depth)->std::uint64_t {
        need(depth<=l.max_depth,"hierarchy depth exhausted during declaration validation");
        need(visiting[index]!=1,"cyclic grammar reference");
        if(visiting[index]==2){need(depth+depths[index]-1<=l.max_depth,"hierarchy depth exhausted");return expansion[index];}
        visiting[index]=1;const auto& r=definition.rules[index];std::uint64_t total=1;std::size_t max_depth=1;
        std::uint64_t direct=0;
        for(const auto& child:r.children) {
            need(indices.contains(child),"unknown child rule: "+child);
            const auto ci=indices.at(child);const auto child_total=self(self,ci,depth+1);
            need(child_total<=l.max_features&&total<=l.max_features-child_total,"declared expansion exceeds feature capacity");
            total+=child_total;direct+=definition.rules[ci].count;max_depth=std::max(max_depth,1+depths[ci]);
        }
        need(direct<=l.max_children,"expanded direct child capacity exceeded");
        need(total<=l.max_features/r.count,"declared multiplicity exceeds feature capacity");
        visiting[index]=2;depths[index]=max_depth;expansion[index]=total*r.count;return expansion[index];
    };
    for(std::size_t i=0;i<definition.rules.size();++i)(void)visit(visit,i,1);
    std::uint64_t regional_features=1,direct_roots=0;
    for(const auto& root:definition.roots) {
        need(indices.contains(root),"unknown root rule: "+root);const auto index=indices.at(root);
        need(regional_features<=l.max_features-expansion[index],"root expansion exceeds feature capacity");
        regional_features+=expansion[index];direct_roots+=definition.rules[index].count;
    }
    need(direct_roots<=l.max_children,"expanded root capacity exceeded");
    const auto region_count=static_cast<std::uint64_t>(window.width)*window.height;
    need(regional_features<=l.max_features/region_count,"finite plan feature capacity exceeded");
    need(static_cast<std::uint64_t>(n)*n<=l.max_raster_cells/region_count,"finite raster cell capacity exceeded");
    auto impl=std::make_unique<Impl>();impl->definition=std::move(definition);impl->seed=seed;impl->rule_indices=std::move(indices);
    impl->bounds={window.x*n,window.y*n,window.width*n,window.height*n};
    impl->charge(1024+impl->definition.rules.size()*512);
    impl->memory(8192+impl->definition.rules.size()*8192);
    for(const auto& r:impl->definition.rules) {
        impl->charge(r.candidates.size()*64+r.parameters.size()*64+r.preferences.size()*64+r.sockets.size()*64);
        impl->memory(r.candidates.size()*256+r.parameters.size()*256+r.sockets.size()*256+r.preferences.size()*256);
    }
    for(const auto& [category,blend]:impl->definition.district_themes) {
        (void)category;impl->charge(64+blend.size()*128);impl->memory(128+blend.size()*192);
    }
    if(impl->definition.district_assignment) {
        impl->assignment=spatial::PreparedRegions::compile(*impl->definition.district_assignment,impl->definition.assignment_limits);
        impl->charge(impl->assignment->declared_preparation_work());impl->memory(impl->assignment->storage_bytes()+spatial::kRegionSolverScratchBytes);
        for(const auto category:impl->definition.district_assignment->categories)
            need(impl->definition.district_themes.contains(category),"region category lacks theme blend");
    } else need(impl->definition.district_themes.empty(),"district themes require a discrete assignment");
    // No owning chunk or neighboring plan is requested. Only this bounded
    // compile window is enumerated, and each region sees its own skeleton/tree.
    for(std::int64_t ry=window.y;ry<window.y+window.height;++ry)for(std::int64_t rx=window.x;rx<window.x+window.width;++rx) {
        const spatial::RegionId owner{rx,ry};SemanticFeature region;
        region.id=region_id(impl->definition,owner);region.candidate_id=std::string("region");region.kind=SemanticKind::Region;
        region.bounds={rx*n,ry*n,n,n};region.owner=owner;
        if(impl->assignment)region.themes=normalized_themes(impl->definition.district_themes.at(impl->assignment->sample({static_cast<double>(rx*n+n/2),static_cast<double>(ry*n+n/2)})));
        const auto index=impl->features.size();impl->add_feature(std::move(region));impl->build_region_routes(owner);
        for(const auto& socket:impl->sockets)if(socket.feature_id==impl->features[index].id&&!socket.shared)impl->features[index].sockets.push_back(socket.id);
        impl->expand(index,impl->definition.roots,1);
    }
    // Delete authored omissions, including their sockets/routes and descendants.
    auto prune=[&](const std::string& id) {
        impl->charge(32+impl->features.size()*64+impl->sockets.size()*16+impl->routes.size()*48);
        const auto under=[&](const std::string& value){return value==id||value.starts_with(id+"/");};
        std::erase_if(impl->features,[&](const auto& f){return under(f.id);});
        std::erase_if(impl->sockets,[&](const auto& s){return under(s.id)||under(s.feature_id);});
        std::erase_if(impl->routes,[&](const auto& r){return under(r.id)||under(r.from_socket)||under(r.to_socket);});
        for(auto& f:impl->features)std::erase_if(f.children,[&](const auto& child){return under(child);});
        for(auto& s:impl->sockets)if(under(s.matched))s.matched.clear();
    };
    for(;;) {
        const auto omitted=std::find_if(impl->features.begin(),impl->features.end(),[](const auto& f){return f.candidate_id.empty();});
        if(omitted==impl->features.end())break;
        const auto id=omitted->id;prune(id);
    }
    // Match authored adjoining sockets after all sibling geometry is immutable.
    for(std::size_t i=0;i<impl->sockets.size();++i) {
        auto& a=impl->sockets[i];if(a.shared||!a.matched.empty())continue;
        for(std::size_t j=i+1;j<impl->sockets.size();++j) {
            impl->charge(16);auto& b=impl->sockets[j];if(b.shared||!b.matched.empty()||a.feature_id==b.feature_id||a.owner!=b.owner)continue;
            const bool same=a.x==b.x&&a.y==b.y;
            const bool adjacent=(a.direction==SocketDirection::West&&a.x-1==b.x&&a.y==b.y)||
                (a.direction==SocketDirection::East&&a.x+1==b.x&&a.y==b.y)||
                (a.direction==SocketDirection::North&&a.y-1==b.y&&a.x==b.x)||
                (a.direction==SocketDirection::South&&a.y+1==b.y&&a.x==b.x);
            if(a.type==b.type&&a.width==b.width&&opposite(a.direction,b.direction)&&(same||adjacent)) {
                a.matched=b.id;b.matched=a.id;
                impl->add_route({a.id+"/join",a.type,a.id,b.id,a.owner,
                    {{static_cast<double>(a.x),static_cast<double>(a.y)},{static_cast<double>(b.x),static_cast<double>(b.y)}},a.width,
                    a.type=="passage"&&(a.required||b.required),a.type=="passage"?Material::Empty:
                        a.type=="liquid"?impl->definition.liquid_material:impl->definition.service_material});break;
            }
        }
    }
    // Required socket/connected constraints may explicitly omit a feature. Each
    // pass removes at least one feature, so even fallback propagation is bounded.
    for(std::size_t pass=0;pass<=impl->definition.limits.max_features;++pass) {
        bool changed=false;
        std::set<std::string> connected;
        for(const auto& s:impl->sockets)if(s.type=="passage"&&!s.matched.empty()&&s.matched.ends_with("/attachment"))connected.insert(s.feature_id);
        for(std::size_t step=0;step<impl->features.size();++step) {
            bool progress=false;
            for(const auto& s:impl->sockets) {
                impl->charge(8);if(s.type!="passage"||s.matched.empty())continue;
                const auto mate=std::find_if(impl->sockets.begin(),impl->sockets.end(),[&](const auto& other){return other.id==s.matched;});
                impl->charge(impl->sockets.size());
                if(mate!=impl->sockets.end()&&connected.contains(mate->feature_id)&&!connected.contains(s.feature_id)){connected.insert(s.feature_id);progress=true;}
            }
            if(!progress)break;
        }
        for(const auto& f:impl->features) {
            if(f.rule_id.empty())continue;
            std::size_t count=0;bool all=true;
            impl->charge(impl->sockets.size()*8);
            for(const auto& s:impl->sockets)if(s.feature_id==f.id) {
                impl->charge(8);count+=!s.matched.empty();if(s.required&&s.matched.empty())all=false;
            }
            std::string failure;
            if(!all)failure=std::string("required socket has no compatible attachment");
            if(count<f.constraints.minimum_sockets||f.sockets.size()>f.constraints.maximum_sockets)failure=std::string("required compatible socket count is unsatisfied");
            if(f.constraints.connected&&!connected.contains(f.id))failure=std::string("feature lacks a connected passage socket");
            if(failure.empty())continue;
            const auto& r=impl->rule(f.rule_id);
            if(r.fallback==GrammarFallback::Reject)throw std::runtime_error("grammar: "+f.id+": "+failure);
            const auto id=f.id;impl->receipt(id,r.id,"sockets",false,"authored omit: "+failure,true);prune(id);changed=true;break;
        }
        if(!changed)break;
        need(pass<impl->definition.limits.max_features,"fallback resolution exhausted");
    }
    // Final semantic validation covers all published neighbor/support relations
    // after optional omissions. No receipt for a removed neighbor is reused.
    for(std::size_t i=0;i<impl->features.size();++i) {
        const auto& f=impl->features[i];if(f.rule_id.empty())continue;
        std::vector<std::size_t> siblings;for(std::size_t j=0;j<impl->features.size();++j)if(i!=j&&impl->features[j].parent==f.parent)siblings.push_back(j);
        impl->charge(impl->features.size());
        for(const auto& required:f.constraints.required_neighbors) {
            bool found=false;for(const auto index:siblings){impl->charge(8);if(tag(impl->features[index],required)&&separation(f.bounds,impl->features[index].bounds)<=f.constraints.neighbor_distance)found=true;}
            if(!found)throw std::runtime_error("grammar: "+f.id+": final required neighbor absent");
        }
        const auto parent=std::find_if(impl->features.begin(),impl->features.end(),[&](const auto& p){return p.id==f.parent;});
        impl->charge(impl->features.size());need(parent!=impl->features.end(),"missing semantic parent");
        if(!impl->supported(*parent,f.bounds,f.constraints,siblings))throw std::runtime_error("grammar: "+f.id+": final support absent");
        impl->receipt(f.id,f.rule_id,"sockets",true,"compatible counts and declared connectivity satisfied");
    }
    std::sort(impl->features.begin(),impl->features.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    std::sort(impl->sockets.begin(),impl->sockets.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    std::sort(impl->routes.begin(),impl->routes.end(),[](const auto& a,const auto& b){return a.id<b.id;});
    impl->memory(impl->features.size()*sizeof(std::size_t)*2);
    impl->feature_depths.reserve(impl->features.size());
    for(auto& f:impl->features) {
        impl->charge(f.id.size()+f.children.size()*16+f.sockets.size()*32);
        impl->feature_depths.push_back(static_cast<std::size_t>(std::count(f.id.begin(),f.id.end(),'/')));
        std::sort(f.children.begin(),f.children.end());std::sort(f.sockets.begin(),f.sockets.end());f.revision=feature_revision(f);
        for(const auto& id:f.sockets) {
            const auto found=std::lower_bound(impl->sockets.begin(),impl->sockets.end(),id,[](const auto& socket,const auto& key){return socket.id<key;});
            need(found!=impl->sockets.end()&&found->id==id,"missing feature socket");
            hash_text(f.revision,found->type);hash_text(f.revision,found->matched);hash_int(f.revision,found->x);hash_int(f.revision,found->y);
            hash_int(f.revision,static_cast<unsigned>(found->direction));hash_int(f.revision,found->width);hash_int(f.revision,found->required);
        }
    }
    // Build a bounded conservative 64-cell candidate index after canonical
    // ordering. Rectangles and route halos are clipped only for indexing; the
    // original tests still decide coverage. Negative regions retain exact IDs.
    impl->bin_columns = static_cast<std::size_t>((impl->bounds.width+Impl::bin_size-1)/Impl::bin_size);
    const auto bin_rows = static_cast<std::size_t>((impl->bounds.height+Impl::bin_size-1)/Impl::bin_size);
    const auto bin_count = impl->bin_columns*bin_rows;
    impl->charge(bin_count*2); impl->memory(bin_count*sizeof(std::vector<std::size_t>)*4);
    impl->feature_bins.resize(bin_count); impl->route_bins.resize(bin_count);
    const auto index_box = [&](std::vector<std::vector<std::size_t>>& bins, std::size_t record, RectI64 box, const SemanticRoute* route = nullptr) {
        const auto x0=std::max(box.x,impl->bounds.x), y0=std::max(box.y,impl->bounds.y);
        const auto x1=std::min(box.x+box.width,impl->bounds.x+impl->bounds.width);
        const auto y1=std::min(box.y+box.height,impl->bounds.y+impl->bounds.height);
        if(x0>=x1||y0>=y1)return;
        const auto left=static_cast<std::size_t>((x0-impl->bounds.x)/Impl::bin_size);
        const auto top=static_cast<std::size_t>((y0-impl->bounds.y)/Impl::bin_size);
        const auto right=static_cast<std::size_t>((x1-1-impl->bounds.x)/Impl::bin_size);
        const auto bottom=static_cast<std::size_t>((y1-1-impl->bounds.y)/Impl::bin_size);
        const auto count=(right-left+1)*(bottom-top+1);
        impl->charge(count*(8+(route?route->points.size()*16:0))); impl->memory(count*sizeof(std::size_t)*2);
        for(auto by=top;by<=bottom;++by)for(auto bx=left;bx<=right;++bx) {
            const auto cell_x=impl->bounds.x+static_cast<std::int64_t>(bx)*Impl::bin_size;
            const auto cell_y=impl->bounds.y+static_cast<std::int64_t>(by)*Impl::bin_size;
            const RectI64 tile{cell_x,cell_y,std::min(Impl::bin_size,impl->bounds.x+impl->bounds.width-cell_x),
                std::min(Impl::bin_size,impl->bounds.y+impl->bounds.height-cell_y)};
            if(route&&!route_intersects(*route,tile))continue;
            bins[by*impl->bin_columns+bx].push_back(record);
        }
    };
    for(std::size_t i=0;i<impl->features.size();++i)index_box(impl->feature_bins,i,impl->features[i].bounds);
    for(std::size_t i=0;i<impl->routes.size();++i) {
        const auto& route=impl->routes[i];
        auto box=segment_box(route.points[0],route.points[1],route.width);
        for(std::size_t p=2;p<route.points.size();++p) {
            const auto segment=segment_box(route.points[p-1],route.points[p],route.width);
            const auto right=std::max(box.x+box.width,segment.x+segment.width);
            const auto bottom=std::max(box.y+box.height,segment.y+segment.height);
            box.x=std::min(box.x,segment.x);box.y=std::min(box.y,segment.y);
            box.width=right-box.x;box.height=bottom-box.y;
        }
        index_box(impl->route_bins,i,box,&route);
    }
    for(std::size_t i=0;i<bin_count;++i) {
        std::uint64_t cost=64+impl->feature_bins[i].size()*64;
        for(auto r:impl->route_bins[i])cost+=32+32*impl->routes[r].points.size();
        impl->sample_cost=std::max(impl->sample_cost,cost);
    }
    // Receipt identity is separate from semantic IDs and binds declaration
    // versions, finite window, selected geometry, material constraints and seeds.
    auto& h=impl->fingerprint;hash_int(h,kGrammarAlgorithmVersion);hash_int(h,seed);hash_text(h,impl->definition.id);hash_rect(h,window);
    hash_int(h,n);hash_int(h,static_cast<unsigned>(impl->definition.curve));hash_int(h,impl->definition.curve_order);
    const auto& limits=impl->definition.limits;
    for(const auto value:{static_cast<std::uint64_t>(limits.max_regions),static_cast<std::uint64_t>(limits.max_rules),static_cast<std::uint64_t>(limits.max_depth),
        static_cast<std::uint64_t>(limits.max_children),static_cast<std::uint64_t>(limits.max_candidates),static_cast<std::uint64_t>(limits.max_features),
        static_cast<std::uint64_t>(limits.max_sockets),static_cast<std::uint64_t>(limits.max_routes),limits.max_work,static_cast<std::uint64_t>(limits.max_prepared_bytes),
        limits.max_raster_cells,limits.max_raster_operations})hash_int(h,value);
    hash_int(h,impl->definition.assignment_limits.max_work);hash_int(h,impl->definition.assignment_limits.max_scratch_bytes);
    hash_int(h,impl->definition.route_width);hash_int(h,impl->definition.clearance);
    hash_int(h,impl->definition.curve_services);hash_int(h,impl->definition.service_trunk);hash_int(h,impl->definition.secondary_loop);hash_int(h,impl->definition.liquid_trunk);
    hash_int(h,static_cast<unsigned>(impl->definition.service_material));hash_int(h,static_cast<unsigned>(impl->definition.liquid_material));
    for(const auto& root:impl->definition.roots)hash_text(h,root);
    for(const auto& r:impl->definition.rules) {
        SemanticFeature declaration;declaration.id=r.id;declaration.rule_id=r.id;declaration.kind=r.kind;declaration.priority=r.priority;
        declaration.tags=r.tags;declaration.themes=r.themes;declaration.parameters=r.parameters;declaration.allowed_materials=r.allowed_materials;
        declaration.constraints=r.constraints;declaration.material=r.material;declaration.interior=r.interior;declaration.wall_thickness=r.wall_thickness;
        declaration.aggregate=r.aggregate;declaration.application=r.application;declaration.exclusion=r.exclusion;
        hash_int(h,feature_revision(declaration));hash_int(h,r.count);hash_int(h,static_cast<unsigned>(r.fallback));
        for(const auto& child:r.children)hash_text(h,child);
        for(const auto& candidate:r.candidates){hash_text(h,candidate.id);hash_rect(h,candidate.bounds);hash_int(h,candidate.order_x);hash_int(h,candidate.order_y);}
        for(const auto& socket:r.sockets){hash_text(h,socket.id);hash_text(h,socket.type);hash_int(h,static_cast<unsigned>(socket.direction));hash_int(h,socket.offset);hash_int(h,socket.width);hash_int(h,socket.required);hash_int(h,socket.attach_to_route);}
        for(const auto& preference:r.preferences){hash_text(h,preference.id);hash_text(h,preference.kind);hash_real(h,preference.weight);for(const auto& theme:preference.themes)hash_text(h,theme);}
    }
    for(const auto& [category,blend]:impl->definition.district_themes){hash_int(h,category);for(const auto& theme:blend){hash_text(h,theme.id);hash_real(h,theme.weight);}}
    for(const auto& f:impl->features){hash_text(h,f.id);hash_int(h,f.revision);for(const auto& child:f.children)hash_text(h,child);}
    for(const auto& s:impl->sockets) {
        hash_text(h,s.id);hash_text(h,s.matched);hash_text(h,s.type);hash_int(h,s.x);hash_int(h,s.y);hash_int(h,s.width);
    }
    for(const auto& r:impl->routes) {
        hash_text(h,r.id);hash_text(h,r.type);hash_int(h,r.width);hash_int(h,r.required);hash_int(h,static_cast<unsigned>(r.material));
        for(const auto p:r.points){hash_real(h,p.x);hash_real(h,p.y);}
    }
    for(const auto& r:impl->receipts){hash_text(h,r.feature_id);hash_text(h,r.rule_id);hash_text(h,r.constraint);hash_text(h,r.detail);hash_int(h,r.passed);hash_int(h,r.fallback);}
    if(impl->assignment)hash_int(h,impl->assignment->fingerprint());
    for(const auto& [alias,target]:impl->definition.geometry_exports){hash_text(h,alias);hash_text(h,target);}
    auto result=std::shared_ptr<const GrammarPlan>(new GrammarPlan(std::move(impl)));
    (void)result->geometry_inputs(); // validate every requested export before publication
    return result;
}

GrammarPlan::GrammarPlan(std::unique_ptr<Impl> impl):impl_(std::move(impl)){}
GrammarPlan::~GrammarPlan()=default;
const GrammarDefinition& GrammarPlan::definition()const noexcept{return impl_->definition;}
const std::vector<SemanticFeature>& GrammarPlan::features()const noexcept{return impl_->features;}
const std::vector<SemanticSocket>& GrammarPlan::sockets()const noexcept{return impl_->sockets;}
const std::vector<SemanticRoute>& GrammarPlan::routes()const noexcept{return impl_->routes;}
const std::vector<ConstraintReceipt>& GrammarPlan::receipts()const noexcept{return impl_->receipts;}
RectI64 GrammarPlan::bounds()const noexcept{return impl_->bounds;}
std::uint64_t GrammarPlan::fingerprint()const noexcept{return impl_->fingerprint;}
std::uint64_t GrammarPlan::preparation_work()const noexcept{return impl_->work;}
std::uint64_t GrammarPlan::operations_per_sample()const noexcept { return impl_->sample_cost; }
GenerationIndexInfo GrammarPlan::index_info()const noexcept {
    GenerationIndexInfo result; result.bins=impl_->feature_bins.size();
    for(std::size_t i=0;i<result.bins;++i) {
        const auto count=impl_->feature_bins[i].size()+impl_->route_bins[i].size();
        result.entries+=count;result.maximum_candidates=std::max(result.maximum_candidates,count);
    }
    return result;
}
std::size_t GrammarPlan::storage_bytes()const noexcept{return impl_->bytes;}
const SemanticFeature* GrammarPlan::feature(const std::string& id)const noexcept {
    const auto found=std::lower_bound(impl_->features.begin(),impl_->features.end(),id,[](const auto& f,const auto& key){return f.id<key;});
    return found!=impl_->features.end()&&found->id==id?&*found:nullptr;
}
std::vector<const SemanticFeature*> GrammarPlan::query(RectI64 box)const {
    valid_rect(box);std::vector<const SemanticFeature*> result;
    for(const auto& f:impl_->features)if(overlaps(f.bounds,box))result.push_back(&f);
    return result;
}
std::vector<std::string> GrammarPlan::ancestry(const std::string& id)const {
    std::vector<std::string> result;const auto* current=feature(id);
    need(current!=nullptr,"unknown feature ancestry "+id);
    while(current){result.push_back(current->id);current=current->parent.empty()?nullptr:feature(current->parent);}
    std::reverse(result.begin(),result.end());return result;
}
SemanticProposal GrammarPlan::proposal(std::int64_t x,std::int64_t y)const noexcept {
    return proposal(x,y,nullptr,nullptr);
}
SemanticProposal GrammarPlan::proposal(std::int64_t x,std::int64_t y,
                                      FeatureEligibility eligible,const void* context)const {
    SemanticProposal result;
    if(!contains(impl_->bounds,x,y))return result;
    std::size_t best_depth=0;int priority=std::numeric_limits<int>::min();
    for(const auto index:impl_->feature_bins[impl_->bin(x,y)]) {
        const auto& f=impl_->features[index];if(!contains(f.bounds,x,y))continue;
        const auto depth=impl_->feature_depths[index];
        // Features are already in canonical lexical order, so a later equal
        // priority/depth feature is exactly the existing lexical winner.
        if(result.feature&&(depth<best_depth||(depth==best_depth&&f.priority<priority)))continue;
        const bool inside=f.wall_thickness==0||contains(interior(f.bounds,f.wall_thickness),x,y);
        const auto material=inside?f.interior:f.material;
        // Semantic scopes without a material retain an enclosing contribution.
        if(!material&&(inside||f.aggregate.empty()))continue;
        if(eligible&&!eligible(index,f,context))continue;
        result={material,&f,nullptr,inside};best_depth=depth;priority=f.priority;
    }
    // Service trunks are structural material proposals. Traversable passages
    // are restored separately after modifiers and remain below hard overrides.
    for(const auto index:impl_->route_bins[impl_->bin(x,y)]) {
        const auto& r=impl_->routes[index];
        if(r.owner==cell_owner(impl_->definition,x,y)&&r.type!="passage"&&route_contains(r,x,y))result={r.material,nullptr,&r,false};
    }
    return result;
}
const SemanticRoute* GrammarPlan::route_at(std::int64_t x,std::int64_t y)const noexcept {
    if(!contains(impl_->bounds,x,y))return nullptr;
    for(const auto index:impl_->route_bins[impl_->bin(x,y)]) {
        const auto& r=impl_->routes[index];
        if(r.owner==cell_owner(impl_->definition,x,y)&&r.type=="passage"&&route_contains(r,x,y))return &r;
    }
    return nullptr;
}
std::vector<SpatialGeometry> GrammarPlan::geometry_inputs()const {
    std::vector<SpatialGeometry> result;
    for(const auto& [alias,target]:impl_->definition.geometry_exports) {
        if(const auto* f=feature(target)) {
            const auto b=f->bounds;
            result.push_back({alias,{{static_cast<double>(b.x),static_cast<double>(b.y)},
                {static_cast<double>(b.x+b.width),static_cast<double>(b.y)},
                {static_cast<double>(b.x+b.width),static_cast<double>(b.y+b.height)},
                {static_cast<double>(b.x),static_cast<double>(b.y+b.height)}},true});
        } else {
            const auto r=std::find_if(impl_->routes.begin(),impl_->routes.end(),[&](const auto& route){return route.id==target;});
            need(r!=impl_->routes.end(),"geometry export target does not exist: "+target);
            result.push_back({alias,r->points,false});
        }
    }
    return result;
}
GrammarDefinition GrammarPlan::example() {
    GrammarDefinition d;d.id=std::string("industrial");d.region_window={-1,-1,2,2};d.region_size=128;d.curve_services=true;
    GrammarRule district;district.id=std::string("district");district.kind=SemanticKind::District;
    district.candidates={{"whole",{0,0,128,128},0,0}};district.material.reset();district.interior.reset();district.wall_thickness=0;
    district.themes={{"industrial",3},{"garden",1}};district.tags={"district"};district.children={"complex"};
    GrammarRule complex;complex.id=std::string("complex");complex.kind=SemanticKind::Complex;
    complex.candidates={{"north",{12,28,104,72},0,0},{"south",{12,36,104,72},0,1}};
    complex.tags={"building"};complex.children={"room"};complex.constraints.intersects_route=true;
    complex.sockets={{"entry","passage",SocketDirection::West,36,7,true,true}};
    complex.constraints.connected=true;complex.constraints.minimum_sockets=1;
    complex.preferences={{"tour","curve_density",1,{}}};
    GrammarRule room;room.id=std::string("room");room.kind=SemanticKind::Room;room.candidates={{"interior",{4,4,96,64},0,0}};
    room.tags={"workshop"};room.children={"pump","console"};room.constraints.open_volume=true;
    GrammarRule pump;pump.id=std::string("pump");pump.kind=SemanticKind::Apparatus;
    pump.candidates={{"floor",{8,54,8,8},0,0}};pump.material=Material::Copper;pump.interior=Material::Copper;pump.wall_thickness=0;
    pump.tags={"service","pump"};pump.constraints.floor=true;pump.constraints.service=std::string("service");pump.constraints.neighbor_distance=64;
    pump.children={"detail"};pump.parameters["flow"]={SpatialType::Scalar,0.75};
    GrammarRule console;console.id=std::string("console");console.kind=SemanticKind::Apparatus;
    console.candidates={{"ceiling",{64,2,12,6},1,0}};console.material=Material::Metal;console.interior=Material::Metal;console.wall_thickness=0;
    console.constraints.ceiling=true;console.constraints.open_volume=true;console.constraints.minimum_separation=8;
    GrammarRule detail;detail.id=std::string("detail");detail.kind=SemanticKind::Detail;detail.candidates={{"gauge",{2,2,3,3},0,0}};
    detail.material=Material::Glass;detail.interior=Material::Glass;detail.wall_thickness=0;detail.tags={"gauge"};
    d.rules={district,complex,room,pump,console,detail};d.roots={"district"};
    d.geometry_exports={{"industrial_loop","industrial/grid128/region(0,0)/route/loop"},{"industrial_room","industrial/grid128/region(0,0)/district/0/complex/0/room/0"}};
    return d;
}
const char* semantic_kind_name(SemanticKind kind)noexcept {
    switch(kind){case SemanticKind::Region:return "region";case SemanticKind::District:return "district";case SemanticKind::Complex:return "complex";case SemanticKind::Room:return "room";case SemanticKind::Apparatus:return "apparatus";case SemanticKind::Detail:return "detail";}return "invalid";
}
std::optional<SemanticKind> parse_semantic_kind(const std::string& name)noexcept {
    for(unsigned i=0;i<=static_cast<unsigned>(SemanticKind::Detail);++i)
        if(name==semantic_kind_name(static_cast<SemanticKind>(i)))return static_cast<SemanticKind>(i);
    return {};
}
const char* grammar_curve_name(GrammarCurve curve)noexcept {
    switch(curve){case GrammarCurve::Hilbert:return "hilbert";case GrammarCurve::Morton:return "morton";case GrammarCurve::Peano:return "peano";}return "invalid";
}
std::optional<GrammarCurve> parse_grammar_curve(const std::string& name)noexcept {
    for(unsigned i=0;i<=static_cast<unsigned>(GrammarCurve::Peano);++i)
        if(name==grammar_curve_name(static_cast<GrammarCurve>(i)))return static_cast<GrammarCurve>(i);
    return {};
}
const char* socket_direction_name(SocketDirection direction)noexcept {
    switch(direction){case SocketDirection::West:return "west";case SocketDirection::East:return "east";case SocketDirection::North:return "north";case SocketDirection::South:return "south";}return "invalid";
}
std::optional<SocketDirection> parse_socket_direction(const std::string& name)noexcept {
    for(unsigned i=0;i<=static_cast<unsigned>(SocketDirection::South);++i)
        if(name==socket_direction_name(static_cast<SocketDirection>(i)))return static_cast<SocketDirection>(i);
    return {};
}
} // namespace cybersand::generation
