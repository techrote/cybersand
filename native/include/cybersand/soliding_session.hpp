#pragma once
// ADR-012: isolated diagnostic owner. Never hand its World to another adapter.
#include "cybersand/soliding.hpp"
#include <cmath>

namespace cybersand::soliding {
struct PayloadCell {
    std::int64_t x=0,y=0;
    Material material=Material::Empty;
    std::uint16_t a=0;
    std::uint8_t b=0;
    std::int16_t temperature=200;
    friend bool operator==(const PayloadCell&,const PayloadCell&)=default;
};
using Token=std::array<std::uint64_t,7>;
enum class Phase { Cells, PromotionPrepared, PromotionAcknowledged, PromotionCommitted,
                   Aggregate, ReversalPrepared, ReversalAcknowledged, ReversalCommitted, Quarantine };
struct Motion { double x=0,y=0,angle=0,vx=0,vy=0,omega=0; };
struct MaskResult { bool complete=false; unsigned required=0,written=0,conflicts=0; };
struct SessionStatus {
    Phase phase=Phase::Cells;
    unsigned members=0,cell_members=0,slot_members=0,rest=0,motion_rest=0;
    std::uint64_t payload_hash=0;
    bool failed=false,excluded=false;
    double snap_x=0,snap_y=0,snap_angle=0,speed_bound=0,discarded_energy=0;
    RectI64 rectangle{};
};
class Session {
    friend struct SessionTestAccess;
    World world_;
    Observer observer_;
    Phase phase_=Phase::Cells;
    bool slot_owns_=false,excluded_=false,mask_ready_=false;
    std::uint64_t incarnation_=0,generation_=0,topology_=0,motion_serial_=0;
    Token token_{};
    RectI64 rectangle_{};
    unsigned count_=0,motion_rest_=0;
    std::array<PayloadCell,224> payload_{},writes_{};
    std::array<Member,1024> mask_cells_{};
    Motion motion_{};
    SessionStatus measurements_{};
    [[nodiscard]] bool valid_token(const Token& token)const noexcept {return incarnation_!=0 && token==token_;}
    [[nodiscard]] bool near_rest(const Motion& m)const noexcept;
    [[nodiscard]] const Candidate* source_candidate() const noexcept;
    [[nodiscard]] bool eligible() const noexcept {return source_candidate()!=nullptr;}
    [[nodiscard]] bool advance_token(unsigned direction) noexcept;
    [[nodiscard]] bool source_matches() const noexcept;
public:
    explicit Session(unsigned width=8,unsigned height=14,unsigned workers=1);
    Session(const Session&)=delete;
    Session& operator=(const Session&)=delete;
    [[nodiscard]] bool tick();
    [[nodiscard]] bool edit(int x,int y,Material material,std::int16_t temperature=200);
    [[nodiscard]] bool prepare_promotion();
    [[nodiscard]] bool prepare_reversal(const Motion& frozen);
    [[nodiscard]] bool acknowledge(const Token&) noexcept;
    [[nodiscard]] bool commit(const Token&) noexcept;
    [[nodiscard]] bool finalize(const Token&,bool topology_verified) noexcept;
    [[nodiscard]] bool cancel(const Token&) noexcept;
    [[nodiscard]] MaskResult occupancy(const Motion&) noexcept;
    [[nodiscard]] bool observe_motion(const Motion&,std::uint64_t serial) noexcept;
    [[nodiscard]] bool set_excluded(bool excluded) noexcept;
    void quarantine() noexcept {phase_=Phase::Quarantine;mask_ready_=false;}
    [[nodiscard]] bool persistence_allowed()const noexcept {return phase_==Phase::Cells&&!excluded_&&!world_.has_failed();}
    [[nodiscard]] Token token()const noexcept{return token_;}
    [[nodiscard]] SessionStatus status()const noexcept;
};
} // namespace cybersand::soliding
