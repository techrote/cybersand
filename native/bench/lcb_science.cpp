// LCB-004 observation apparatus only. No World law or ABI is changed here.
// Contract: external lcb004-science-apparatus-contract-v2 + ordered-event v3 clarification.
#include "cybersand/world.hpp"

#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>

namespace {
using namespace cybersand;
using Clock = std::chrono::steady_clock;
constexpr std::string_view kSchema = "lcb-native-science-v1";
void require(bool condition, std::string_view text) {
    if (!condition) throw std::runtime_error(std::string(text));
}
std::uint64_t ns(Clock::time_point start) {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now()-start).count());
}
std::int64_t add(std::int64_t a, std::int64_t b) {
    require(!(b>0 && a>std::numeric_limits<std::int64_t>::max()-b) &&
            !(b<0 && a<std::numeric_limits<std::int64_t>::min()-b), "signed census overflow");
    return a+b;
}
std::int64_t sub(std::int64_t a, std::int64_t b) {
    require(!(b<0 && a>std::numeric_limits<std::int64_t>::max()+b) &&
            !(b>0 && a<std::numeric_limits<std::int64_t>::min()+b), "signed delta overflow");
    return a-b;
}
std::int64_t mul(std::int64_t a, std::int64_t b) {
    std::int64_t result=0;
    require(!__builtin_mul_overflow(a,b,&result), "coordinate/weighted census overflow");
    return result;
}
std::uint64_t uadd(std::uint64_t a, std::uint64_t b) {
    require(b<=std::numeric_limits<std::uint64_t>::max()-a, "unsigned census overflow"); return a+b;
}
std::int64_t signed_value(std::uint64_t v) {
    require(v<=static_cast<std::uint64_t>(std::numeric_limits<std::int64_t>::max()), "closure exceeds signed apparatus range");
    return static_cast<std::int64_t>(v);
}
std::string quote(std::string_view value) {
    std::string out="\"";
    for (char raw:value) {
        const auto ch=static_cast<unsigned char>(raw);
        if (ch=='"' || ch=='\\') { out+='\\'; out+=static_cast<char>(ch); }
        else if (ch<32U) {
            constexpr char hex[]="0123456789abcdef";
            out+="\\u00"; out+=hex[ch>>4U]; out+=hex[ch&15U];
        } else out+=static_cast<char>(ch);
    }
    return out+'"';
}
template<class T> std::string number(T value) { return std::to_string(value); }
template<class T> std::string integer(T value) { return quote(number(value)); }
std::string boolean(bool value) { return value?"true":"false"; }
struct Object {
    std::string text="{"; bool first=true;
    void put(std::string_view key, const std::string& encoded) {
        if (!first) text+=','; first=false; text+=quote(key)+':'+encoded;
    }
    std::string finish() const { return text+'}'; }
};
template<class Container, class Convert> std::string array(const Container& values, Convert convert) {
    std::string out="["; bool first=true;
    for (const auto& value:values) { if (!first) out+=','; first=false; out+=convert(value); }
    return out+']';
}
template<class Container> std::string integers(const Container& values) {
    return array(values,[](auto v){return integer(v);});
}
std::string hash64(std::uint64_t value) {
    std::ostringstream out; out<<std::hex<<std::setfill('0')<<std::setw(16)<<value; return quote(out.str());
}
std::vector<std::uint8_t> read_file(const std::filesystem::path& path, std::uintmax_t maximum) {
    require(std::filesystem::is_regular_file(path), "input is not a regular file");
    const auto size=std::filesystem::file_size(path); require(size<=maximum, "input byte limit exceeded");
    std::ifstream stream(path,std::ios::binary); require(stream.good(), "cannot open input");
    std::vector<std::uint8_t> bytes(static_cast<std::size_t>(size));
    if (!bytes.empty()) stream.read(reinterpret_cast<char*>(bytes.data()),static_cast<std::streamsize>(bytes.size()));
    require(stream.good() && stream.peek()==std::char_traits<char>::eof(), "input changed/truncated while reading");
    return bytes;
}
std::int64_t parse_integer(std::string_view token) {
    std::int64_t value=0; const auto result=std::from_chars(token.data(),token.data()+token.size(),value);
    require(result.ec==std::errc{} && result.ptr==token.data()+token.size() && !token.empty(), "malformed/overflow integer");
    return value;
}
std::vector<std::string> tokens(std::string_view line) {
    std::istringstream stream{std::string(line)}; std::vector<std::string> out;
    for (std::string token;stream>>token;) out.push_back(token); return out;
}
struct Event { std::int64_t tick,kind,x,y,width,height,material,a,b; };
std::vector<Event> events_for(const std::vector<std::uint8_t>& bytes, const World& world, std::int64_t horizon) {
    for (auto ch:bytes) require(ch<128U && (ch>=32U || ch=='\t' || ch=='\n' || ch=='\r' || ch=='\v' || ch=='\f'), "event wire is not ASCII text");
    std::istringstream input{std::string(bytes.begin(),bytes.end())}; std::string line;
    require(static_cast<bool>(std::getline(input,line)), "missing event wire header");
    auto header=tokens(line); require(header.size()==2 && header[0]=="lcb-science-events-v1", "unknown event wire");
    const auto count=parse_integer(header[1]); require(count>=0 && count<=128, "event count outside bound");
    std::vector<Event> out;
    for (std::int64_t i=0;i<count;++i) {
        require(static_cast<bool>(std::getline(input,line)), "event row missing"); const auto row=tokens(line);
        require(row.size()==9, "event row requires exactly nine integers");
        std::array<std::int64_t,9> v{}; for (std::size_t j=0;j<v.size();++j) v[j]=parse_integer(row[j]);
        Event e{v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8]};
        require(e.tick>=0 && e.tick<horizon && (out.empty() || e.tick>=out.back().tick), "event tick/order outside horizon");
        require(e.x>=0 && e.x<1024 && e.y>=0 && e.y<1024 && e.width>0 && e.width<=1024 && e.height>0 && e.height<=1024 &&
                e.x+e.width<=1024 && e.y+e.height<=1024, "event rectangle outside frame");
        if (e.kind==0) require(e.material==0 && e.a==0 && e.b==0, "erase payload must be zero");
        else {
            require(e.kind==1 && e.material==3 && e.a>0 && e.a<=world.config().water_experiment_policy.maximum() &&
                    e.b>=0 && e.b<=world.config().water_experiment_policy.coherence_ticks(), "unsupported Water fill");
            require(!world.whole_cell_water_enabled() || e.a==world.config().water_experiment_policy.maximum(), "fractional live whole-cell Water refused");
        }
        // Identical ordered action occurrences remain valid. The later identical
        // visible fill is a no-op, matching the host rather than retiring motion.
        out.push_back(e);
    }
    while (std::getline(input,line)) require(tokens(line).empty(), "trailing event data");
    return out;
}
class Reader {
public:
    explicit Reader(std::span<const std::uint8_t> bytes):data(bytes){}
    template<class T> T get() {
        require(sizeof(T)<=data.size()-position,"truncated roster prefix");
        using U=std::make_unsigned_t<T>; U v=0;
        for (std::size_t i=0;i<sizeof(T);++i) v=static_cast<U>(v | (static_cast<U>(data[position+i])<<(8U*i)));
        position+=sizeof(T); return static_cast<T>(v);
    }
    void skip(std::uint64_t count) { require(count<=data.size()-position,"truncated roster record");position+=static_cast<std::size_t>(count); }
private:
    std::span<const std::uint8_t> data; std::size_t position=0;
};
std::vector<ChunkCoord> roster(const std::vector<std::uint8_t>& bytes,const World& world) {
    require(bytes.size()>=40,"CYPS too short"); Reader in(std::span(bytes).first(bytes.size()-32));
    require(in.get<std::uint32_t>()==0x53505943U,"CYPS magic"); const auto version=in.get<std::uint32_t>();
    require(version==2 || version==3,"CYPS roster version");
    const auto side=in.get<std::int32_t>(); const auto activity=in.get<std::int32_t>();
    require(side==world.config().chunk_size && activity==world.config().activity_block_size && side>=8 && side<=1024 && activity>=1 && activity<=1024,"CYPS geometry mismatch");
    in.skip(31); // Through rest enum: eight geometry bytes consumed after magic/version; position47.
    const auto transport=in.get<std::uint32_t>(); require(transport==0 || transport==TransportPolicy::packed_size,"transport roster length");in.skip(4ULL*transport);
    const auto envelope=in.get<std::uint32_t>();require(envelope<=4096,"policy roster length");in.skip(4ULL*envelope);
    if(version==3) { require(in.get<std::uint16_t>()==InertialParameters::kVersion,"IN roster version");in.skip(32); }
    in.skip(26); // attempted/completed u64, epoch u8, hard revision u64, adhesion u8.
    const auto region=in.get<std::uint8_t>();require(region<=1,"region flag");if(region)in.skip(32);
    const auto applied=in.get<std::uint8_t>();require(applied<=1,"applied flag");if(applied)in.skip(32);
    const auto pending=in.get<std::uint32_t>();require(pending<=world.config().deferred_event_capacity,"pending roster count");in.skip(21ULL*pending);
    const auto count=in.get<std::uint32_t>();require(count==world.chunk_count() && count<=128,"resident roster count");
    const auto cells=static_cast<std::uint64_t>(side)*static_cast<std::uint64_t>(side);
    const auto axis=(static_cast<std::uint64_t>(side)+static_cast<std::uint64_t>(activity)-1U)/static_cast<std::uint64_t>(activity);
    const auto blocks=axis*axis;std::vector<ChunkCoord> out;out.reserve(count);
    for (std::uint32_t i=0;i<count;++i) {
        ChunkCoord c{in.get<std::int64_t>(),in.get<std::int64_t>()};
        require(out.empty() || out.back()<c,"duplicate/noncanonical roster coordinate");
        // A full public-query census needs representable coordinates for every slot.
        (void)add(mul(c.x,side),side-1);(void)add(mul(c.y,side),side-1);
        const auto flags=in.get<std::uint8_t>(); require(flags<8 && (version==3 || !(flags&4U)) &&
            ((flags&4U)!=0)==world.inertial_enabled() && ((flags&2U)!=0)==world.pressure_flow_enabled(),"roster sidecar flags");
        require(in.get<std::uint32_t>()==blocks,"roster activity count");
        in.skip(13U*blocks);in.skip(cells*(6U+((flags&1U)?2U:0U)+((flags&2U)?8U:0U)+((flags&4U)?6U:0U)));out.push_back(c);
    }
    // The remaining quantity/gas/ledger tail is validated by authoritative
    // restore plus exact byte roundtrip, not reimplemented by this prefix reader.
    return out;
}
std::string flow(const WaterQuantityFlow& value) { Object out;out.put("produced",integer(value.produced));out.put("consumed",integer(value.consumed));return out.finish(); }
std::string quantity(const QuantityLedgerSnapshot& value) {
    Object out;out.put("schema_version",number(value.schema_version));out.put("mass_bits",number(value.mass_bits));
    out.put("baseline_water",integer(value.baseline_water));out.put("water_visible",integer(value.water_visible));out.put("water_overfill",integer(value.water_overfill));
    out.put("kinds",array(value.kinds,flow));out.put("pair_rules",array(value.pair_rules,flow));out.put("pair_events",integers(value.pair_events));
    out.put("kernel_rules",array(value.kernel_rules,flow));out.put("material_cells",integers(value.material_cells));out.put("prepared_material_cells",integers(value.prepared_material_cells));
    if (value.construction) {
        const auto& c=*value.construction;Object item;item.put("mass_bits",number(c.mass_bits));
        item.put("baseline_water",integer(c.baseline_water));item.put("normalization_produced",integer(c.normalization_produced));
        item.put("normalization_consumed",integer(c.normalization_consumed));item.put("expected_final_water",integer(c.expected_final_water));
        item.put("original_setup_identity",quote(Sha256::hex(c.original_setup_identity)));item.put("prepared_setup_identity",quote(Sha256::hex(c.prepared_setup_identity)));
        item.put("original_payload_digest",quote(Sha256::hex(c.original_payload_digest)));item.put("prepared_payload_digest",quote(Sha256::hex(c.prepared_payload_digest)));
        item.put("normalization_receipt_digest",c.normalization_receipt_digest?quote(Sha256::hex(*c.normalization_receipt_digest)):"null");out.put("construction",item.finish());
    } else out.put("construction","null");
    return out.finish();
}
std::string ledger_json(const InertialLedger& s) {
    Object out;
#define FIELD(n) out.put(#n,integer(s.n))
    FIELD(gravity_y);FIELD(impulse_x);FIELD(impulse_y);FIELD(loss);FIELD(support);FIELD(remainder);
    FIELD(updates);FIELD(unit_moves);FIELD(density_swaps);FIELD(contacts);FIELD(rests);FIELD(velocity_retired);
    FIELD(retired_x);FIELD(retired_y);FIELD(external_x);FIELD(external_y);FIELD(maximum_read_reach);FIELD(maximum_write_reach);FIELD(external_speed);
#undef FIELD
    return out.finish();
}
struct Metric {
    std::uint64_t count=0; std::int64_t min_x=0,max_x=0,min_y=0,max_y=0,sum_x=0,sum_y=0;
    void include(std::int64_t x,std::int64_t y) {
        if(!count){min_x=max_x=x;min_y=max_y=y;}else{min_x=std::min(min_x,x);max_x=std::max(max_x,x);min_y=std::min(min_y,y);max_y=std::max(max_y,y);}
        count=uadd(count,1);sum_x=add(sum_x,x);sum_y=add(sum_y,y);
    }
};
struct Census {
    std::array<std::uint64_t,256> materials{};std::array<Metric,256> metrics{};
    std::uint64_t empty=0,visible=0,overfill=0,l1=0,nonzero=0,foreign=0;
    std::int64_t vx=0,vy=0,ax=0,ay=0,weighted_x=0,weighted_y=0,front=-1;
    std::uint64_t reservoir=0;int max_vx=0,max_vy=0,max_ax=0,max_ay=0;
};
Census census(const World& world,const std::vector<ChunkCoord>& coordinates) {
    Census c;const auto side=world.config().chunk_size;
    for(const auto coord:coordinates) for(int ly=0;ly<side;++ly)for(int lx=0;lx<side;++lx) {
        const auto x=add(mul(coord.x,side),lx),y=add(mul(coord.y,side),ly);const auto material=world.stored_material(x,y);
        const auto id=static_cast<std::uint16_t>(material);require(valid_material(id),"invalid resident material");
        require(world.transient_obstacle_at(x,y)==0,"body mask outside actor-free contract");
        if(material==Material::Empty)c.empty=uadd(c.empty,1);else {c.materials[id]=uadd(c.materials[id],1);c.metrics[id].include(x,y);}
        const auto state=world.inertial_cell(x,y);const bool nonzero=state.vx||state.vy||state.ax||state.ay;
        if(!world.inertial_family(material)){if(nonzero)c.foreign=uadd(c.foreign,1);require(!nonzero,"foreign/Empty IN state");}
        else {
            require(state.available && std::abs(static_cast<int>(state.vx))<=InertialParameters::kVmax && state.vy>=0 && state.vy<=InertialParameters::kVmax &&
                std::abs(static_cast<int>(state.ax))<InertialParameters::kQ && std::abs(static_cast<int>(state.ay))<InertialParameters::kQ,"IN state bound");
            c.vx=add(c.vx,state.vx);c.vy=add(c.vy,state.vy);c.ax=add(c.ax,state.ax);c.ay=add(c.ay,state.ay);
            c.l1=uadd(c.l1,static_cast<std::uint64_t>(std::abs(static_cast<int>(state.vx))+std::abs(static_cast<int>(state.vy))));
            if(nonzero)c.nonzero=uadd(c.nonzero,1);c.max_vx=std::max(c.max_vx,std::abs(static_cast<int>(state.vx)));c.max_vy=std::max(c.max_vy,static_cast<int>(state.vy));
            c.max_ax=std::max(c.max_ax,std::abs(static_cast<int>(state.ax)));c.max_ay=std::max(c.max_ay,std::abs(static_cast<int>(state.ay)));
        }
        if(material==Material::Water) {
            const auto mass=world.stored_state_a(x,y);const auto over=world.pressure_cell(x,y).overfill;const auto total=static_cast<std::uint64_t>(mass)+over;
            c.visible=uadd(c.visible,mass);c.overfill=uadd(c.overfill,over);c.weighted_x=add(c.weighted_x,mul(x,signed_value(total)));c.weighted_y=add(c.weighted_y,mul(y,signed_value(total)));
            if(y==255 && x>=240 && x<=983)c.front=std::max(c.front,x-240);
            if(x>=40 && x<=231 && y>=64 && y<=255)c.reservoir=uadd(c.reservoir,total);
        }
    }
    return c;
}
std::string census_json(const Census& c) {
    Object out;out.put("material_cells",integers(c.materials));out.put("empty_cells",integer(c.empty));out.put("water_visible",integer(c.visible));out.put("water_overfill",integer(c.overfill));out.put("water_total",integer(uadd(c.visible,c.overfill)));
    out.put("water_weighted_x",integer(c.weighted_x));out.put("water_weighted_y",integer(c.weighted_y));out.put("front_y255",integer(c.front));out.put("reservoir_water",integer(c.reservoir));
    Object motion;motion.put("sum_vx",integer(c.vx));motion.put("sum_vy",integer(c.vy));motion.put("l1",integer(c.l1));motion.put("sum_ax",integer(c.ax));motion.put("sum_ay",integer(c.ay));
    motion.put("nonzero_slots",integer(c.nonzero));motion.put("foreign_nonzero_slots",integer(c.foreign));motion.put("max_abs_vx",integer(c.max_vx));motion.put("max_vy",integer(c.max_vy));motion.put("max_abs_ax",integer(c.max_ax));motion.put("max_abs_ay",integer(c.max_ay));out.put("inertial",motion.finish());
    std::vector<std::string> metrics;
    for(std::size_t id=1;id<c.metrics.size();++id)if(c.metrics[id].count){const auto& m=c.metrics[id];Object item;item.put("id",number(id));item.put("count",integer(m.count));
        item.put("min_x",integer(m.min_x));item.put("max_x",integer(m.max_x));item.put("min_y",integer(m.min_y));item.put("max_y",integer(m.max_y));item.put("sum_x",integer(m.sum_x));item.put("sum_y",integer(m.sum_y));metrics.push_back(item.finish());}
    out.put("materials",array(metrics,[](const auto& value){return value;}));return out.finish();
}
std::string regions(const World& world) {
    Object out;const auto requested=world.simulation_region();out.put("requested",requested?integers(std::array{requested->x,requested->y,requested->width,requested->height}):"null");
    for(const auto& [name,value]:std::array{std::pair{"selected",world.selected_simulation_cores()},std::pair{"applied",world.applied_simulation_cores()}}) {
        out.put(name,value?integers(std::array{value->min_x,value->min_y,value->max_x,value->max_y}):"null");
    }
    return out.finish();
}
std::string stats_json(const TickStats& s,const World& world) {
    Object out;out.put("tick",integer(s.tick));out.put("configured_workers",integer(world.config().worker_threads));out.put("observed_workers",integer(s.worker_threads_observed));out.put("observed_available",boolean(world.backend()==SimulationBackend::PhasedInPlace));
    out.put("scheduled_cores",integer(s.scheduled_cores));out.put("visited_cells",integer(s.visited_cells));out.put("moved_cells",integer(s.moved_cells));out.put("chunk_allocations",integer(s.chunk_allocations));out.put("temperature_field_allocations",integer(s.temperature_field_allocations));out.put("deferred_events",integer(s.deferred_events));out.put("phase_jobs",integers(s.phase_jobs));return out.finish();
}
std::string config_json(const World& world) {
    const auto& c=world.config();Object out;
#define CONFIG(n) out.put(#n,number(c.n))
    CONFIG(chunk_size);CONFIG(activity_block_size);CONFIG(scheduling_core_size);CONFIG(maximum_rule_radius);CONFIG(sleep_after_quiet_ticks);CONFIG(ambient_temperature);
    CONFIG(initial_chunk_reserve);CONFIG(worker_threads);CONFIG(parallel_job_threshold);CONFIG(active_core_capacity);CONFIG(active_chunk_capacity);CONFIG(maximum_chunk_count);CONFIG(deferred_event_capacity);CONFIG(maximum_explosion_radius);
#undef CONFIG
    out.put("physics_diagnostics_enabled",boolean(c.physics_diagnostics.enabled));out.put("disable_powder_exchange_targets",boolean(c.physics_diagnostics.disable_powder_exchange_targets));out.put("mercury_viscosity",number(c.physics_diagnostics.mercury_viscosity));
    out.put("pressure_index_chunk_capacity",number(c.pressure_optimization.index_chunk_capacity));out.put("pressure_head_repair_cell_budget",number(c.pressure_optimization.head_repair_cell_budget));out.put("pressure_gas_member_capacity",number(c.pressure_optimization.gas_member_capacity));out.put("pressure_gas_invalidation_pair_budget",number(c.pressure_optimization.gas_invalidation_pair_budget));
    out.put("mass_bits",number(c.water_experiment_policy.mass_bits()));out.put("coherence_ticks",number(c.water_experiment_policy.coherence_ticks()));out.put("adhesion",boolean(world.liquid_surface_adhesion_enabled()));
    out.put("settled_discovery_enabled",boolean(c.settled_discovery_enabled));out.put("settled_region_connectivity_enabled",boolean(c.settled_region_connectivity_enabled));return out.finish();
}
std::string distribution(std::vector<std::uint64_t> values) {
    Object out;out.put("count",integer(values.size()));std::uint64_t total=0;for(auto v:values)total=uadd(total,v);out.put("total_ns",integer(total));
    if(!values.empty()){std::sort(values.begin(),values.end());out.put("min_ns",integer(values.front()));out.put("max_ns",integer(values.back()));
        for(std::size_t p:{50U,95U,99U})out.put("p"+number(p)+"_ns",integer(values[(values.size()*p+99U)/100U-1U]));}return out.finish();
}
class Output {
public:
    explicit Output(const char* path):stream(std::fopen(path,"wx")){require(stream!=nullptr,"output exists or cannot be created exclusively");}
    ~Output(){if(stream)std::fclose(stream);}
    void line(const std::string& text){require(std::fwrite(text.data(),1,text.size(),stream)==text.size() && std::fputc('\n',stream)!=EOF && std::fflush(stream)==0,"output write failed");}
private:std::FILE* stream;
};
void closure(const Census& previous,const InertialLedger& before,const Census& current,const InertialLedger& after) {
    const auto delta=[](auto a,auto b){if constexpr(std::is_unsigned_v<decltype(a)>)return sub(signed_value(a),signed_value(b));else return sub(a,b);};
    require(sub(current.vx,previous.vx)==sub(add(delta(after.impulse_x,before.impulse_x),delta(after.external_x,before.external_x)),delta(after.retired_x,before.retired_x)),"signed-x ledger does not close");
    require(sub(current.vy,previous.vy)==sub(add(add(delta(after.gravity_y,before.gravity_y),delta(after.impulse_y,before.impulse_y)),delta(after.external_y,before.external_y)),delta(after.retired_y,before.retired_y)),"signed-y ledger does not close");
    require(sub(signed_value(current.l1),signed_value(previous.l1))==sub(add(sub(delta(after.gravity_y,before.gravity_y),delta(after.loss,before.loss)),delta(after.external_speed,before.external_speed)),delta(after.velocity_retired,before.velocity_retired)),"L1 ledger does not close");
}
struct Observations {
    World& world;const std::vector<ChunkCoord>& coordinates;Output& output;
    std::uint64_t rows=0;std::vector<std::uint64_t> census_times,hash_times,output_times;
    Census previous{};InertialLedger previous_ledger{};bool have_previous=false;
    Observations(World& w,const std::vector<ChunkCoord>& c,Output& o):world(w),coordinates(c),output(o){}
    void emit(std::string_view phase,std::uint64_t tick,std::size_t events_applied,std::size_t batch,const TickStats& stats,std::uint64_t tick_time) {
        const auto entire=Clock::now();require(!world.has_failed() && world.chunk_count()==coordinates.size(),"World failed/resident roster changed");
        const auto start=Clock::now();const auto current=census(world,coordinates);const auto book=world.quantity_ledger();const auto ledger=world.inertial_ledger();
        require(book.material_cells==current.materials && book.water_visible==current.visible && book.water_overfill==current.overfill,"global census/quantity snapshot mismatch");
        if(have_previous)closure(previous,previous_ledger,current,ledger);previous=current;previous_ledger=ledger;have_previous=true;
        const auto census_time=ns(start);const auto hash_start=Clock::now();Object hashes;
        hashes.put("physical",hash64(world.physical_state_hash()));hashes.put("state",hash64(world.state_hash()));hashes.put("content",hash64(world.content_hash()));
        hashes.put("quiescent",hash64(world.liquid_comparison_hash(LiquidStateProjection::QuiescentPhysicalContentV1)));
        hashes.put("pf_equivalence",hash64(world.liquid_comparison_hash(LiquidStateProjection::PressureVariantEquivalenceV1)));const auto hash_time=ns(hash_start);
        Object row;row.put("type",quote("observation"));row.put("schema",quote(kSchema));row.put("phase",quote(phase));row.put("tick",integer(tick));row.put("events_applied",integer(events_applied));row.put("events_in_phase",integer(batch));
        row.put("census",census_json(current));row.put("ledger",ledger_json(ledger));row.put("quantity",quantity(book));row.put("hashes",hashes.finish());row.put("regions",regions(world));row.put("stats",stats_json(stats,world));
        Object timing;timing.put("tick_ns",integer(tick_time));timing.put("census_ns",integer(census_time));timing.put("hash_ns",integer(hash_time));row.put("timing",timing.finish());output.line(row.finish());
        census_times.push_back(census_time);hash_times.push_back(hash_time);output_times.push_back(ns(entire)-census_time-hash_time);++rows;
    }
};
int run(int argc,char** argv) {
    const auto begin=Clock::now();require(argc==6,"usage: lcb_science SNAPSHOT.cyps EVENTS.txt WORKERS HORIZON OUTPUT.ndjson");
    const auto workers=parse_integer(argv[3]),horizon=parse_integer(argv[4]);require((workers==1 || workers==4) && horizon>=0 && horizon<=4800,"workers/horizon outside protocol");
    require(!std::filesystem::exists(argv[5]),"output already exists");
    const auto snapshot=read_file(argv[1],128ULL*1024U*1024U);const auto wire=read_file(argv[2],128U*1024U);
    WorldConfig execution;execution.worker_threads=static_cast<std::uint32_t>(workers);execution.initial_chunk_reserve=64;execution.parallel_job_threshold=2;execution.active_core_capacity=1024;
    execution.active_chunk_capacity=128;execution.maximum_chunk_count=128;execution.deferred_event_capacity=1024;execution.physics_diagnostics.enabled=true;
    execution.physics_diagnostics.disable_powder_exchange_targets=false;execution.physics_diagnostics.mercury_viscosity=-1;execution.settled_discovery_enabled=false;execution.settled_region_connectivity_enabled=false;
    execution.pressure_optimization={4096,4194304,1048576,4194304};
    auto world=World::restore_physical_state(execution,snapshot);require(!world->has_failed() && world->tick_index()==0 && world->completed_tick_index()==0,"initial World is not healthy completed tick0");
    require(world->backend()==SimulationBackend::PhasedInPlace && !world->config().physics_diagnostics.disable_powder_exchange_targets && world->config().physics_diagnostics.mercury_viscosity==-1,"backend/diagnostic law differs");
    const auto roundtrip=world->save_physical_state();require(roundtrip==snapshot,"initial CYPS does not roundtrip byte-exactly");
    const auto coordinates=roster(snapshot,*world);const auto events=events_for(wire,*world,horizon);const auto snapshot_sha=Sha256::hex(Sha256::of(snapshot));const auto wire_sha=Sha256::hex(Sha256::of(wire));
    Object header;header.put("type",quote("header"));header.put("schema",quote(kSchema));header.put("workers",number(workers));header.put("backend",number(static_cast<unsigned>(world->backend())));header.put("config",config_json(*world));
    header.put("policy_hash",quote(world->liquid_solver_policy().policy_hash_hex()));header.put("inertial_identity",world->inertial_enabled()?quote(Sha256::hex(inertial_extension_identity(world->inertial_parameters()))):"null");
    header.put("snapshot_sha256",quote(snapshot_sha));header.put("roundtrip_sha256",quote(Sha256::hex(Sha256::of(roundtrip))));header.put("events_sha256",quote(wire_sha));header.put("cyps_version",number(world->physical_state_format_version()));
    header.put("consumer_source",quote("native/bench/lcb_science.cpp"));header.put("identity_binding",quote("external-driver-sidecar"));
    header.put("roster",array(coordinates,[](auto c){return integers(std::array{c.x,c.y});}));Object coverage;coverage.put("resident_chunks",integer(coordinates.size()));coverage.put("chunk_side",number(world->config().chunk_size));
    coverage.put("slots",integer(static_cast<std::uint64_t>(coordinates.size())*static_cast<std::uint64_t>(world->config().chunk_size)*static_cast<std::uint64_t>(world->config().chunk_size)));
    if(!coordinates.empty()){std::int64_t minx=0,maxx=0,miny=0,maxy=0;bool first=true;for(auto c:coordinates){const auto x=mul(c.x,world->config().chunk_size),y=mul(c.y,world->config().chunk_size);if(first){minx=maxx=x;miny=maxy=y;first=false;}minx=std::min(minx,x);maxx=std::max(maxx,add(x,world->config().chunk_size-1));miny=std::min(miny,y);maxy=std::max(maxy,add(y,world->config().chunk_size-1));}
        coverage.put("min_x",integer(minx));coverage.put("max_x",integer(maxx));coverage.put("min_y",integer(miny));coverage.put("max_y",integer(maxy));}
    else for(auto key:{"min_x","max_x","min_y","max_y"})coverage.put(key,"null");header.put("coverage",coverage.finish());
    const auto startup_time=ns(begin);Output output(argv[5]);output.line(header.finish());Observations observer{*world,coordinates,output};TickStats last{};
    observer.emit("completed",0,0,0,last,0);std::size_t cursor=0;std::vector<std::uint64_t> tick_times;
    for(std::int64_t tick=0;tick<horizon;++tick){const auto before=cursor;
        while(cursor<events.size() && events[cursor].tick==tick){const auto& e=events[cursor];
            for(auto y=e.y;y<e.y+e.height;++y)for(auto x=e.x;x<e.x+e.width;++x){const auto mat=static_cast<Material>(e.material);
                if(world->stored_material(x,y)==mat && (mat==Material::Empty || (world->stored_state_a(x,y)==e.a && world->stored_state_b(x,y)==e.b)))continue;
                require(world->set_cell_state(x,y,mat,static_cast<std::uint16_t>(e.a),static_cast<std::uint8_t>(e.b)),"live event write refused");}
            require(world->chunk_count()==coordinates.size(),"event grew resident roster");++cursor;}
        if(cursor!=before)observer.emit("post_event",static_cast<std::uint64_t>(tick),cursor,cursor-before,last,0);
        const auto start=Clock::now();last=world->tick();const auto elapsed=ns(start);tick_times.push_back(elapsed);
        require(last.chunk_allocations==0 && last.temperature_field_allocations==0,"native tick allocated chunk/thermal storage");
        require(last.worker_threads_observed<=static_cast<std::uint32_t>(workers),"actual workers exceed configured count");
        require(world->completed_tick_index()==static_cast<std::uint64_t>(tick+1) && world->tick_index()==world->completed_tick_index(),"native tick did not complete exactly once");
        observer.emit("completed",world->completed_tick_index(),cursor,0,last,elapsed);
    }
    require(cursor==events.size() && world->chunk_count()==coordinates.size(),"incomplete event/roster final state");Object footer;footer.put("type",quote("footer"));footer.put("schema",quote(kSchema));footer.put("status",quote("completed"));footer.put("completed_horizon",integer(horizon));footer.put("rows",integer(observer.rows));footer.put("events_applied",integer(cursor));
    footer.put("snapshot_sha256",quote(snapshot_sha));footer.put("events_sha256",quote(wire_sha));footer.put("roster_unchanged","true");footer.put("closure","true");Object timing;timing.put("startup_ns",integer(startup_time));timing.put("tick",distribution(tick_times));timing.put("census",distribution(observer.census_times));timing.put("hash",distribution(observer.hash_times));timing.put("output",distribution(observer.output_times));timing.put("total_ns_before_footer",integer(ns(begin)));timing.put("scope",quote("tick timing excludes census/hash/JSON/output; no render/Rapier/full-heap/utilization claim"));footer.put("timing",timing.finish());output.line(footer.finish());return 0;
}
} // namespace
int main(int argc,char** argv){try{return run(argc,argv);}catch(const std::exception& error){std::cerr<<"LCB_SCIENCE_REFUSED: "<<error.what()<<'\n';return 1;}}
