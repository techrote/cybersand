#pragma once
#include "maps.hpp"
#include "trace.hpp"
#include "cybersand/material.hpp"
#include "cybersand/precision_storage.hpp"
#include <atomic>
#ifndef MAT003_CAPACITY
#error "isolated capacity macro required"
#endif
namespace mat003_world {
inline constexpr unsigned epoch_bits=MAT003_EPOCH_BITS;
using Epoch=std::conditional_t<epoch_bits==8,std::uint8_t,std::uint16_t>;
inline constexpr bool source_control=false,dispatch_observed=true,split_storage=false;
inline constexpr unsigned extra_bytes=2;
using Tail=std::uint16_t;
struct EngineCell : mat003_correctness::Cell<MAT003_CAPACITY,epoch_bits> {
    using Base=mat003_correctness::Cell<MAT003_CAPACITY,epoch_bits>;
    EngineCell() noexcept {const Base zero{};mat003_correctness::trace(2,static_cast<const Base&>(*this),static_cast<const Base*>(nullptr),zero);}
    EngineCell(const EngineCell& other) noexcept : Base(static_cast<const Base&>(other)) {const Base zero{};mat003_correctness::trace(1,static_cast<const Base&>(*this),static_cast<const Base*>(&other),zero);}
    EngineCell& operator=(const EngineCell& other) noexcept {
        const Base before=*this;static_cast<Base&>(*this)=static_cast<const Base&>(other);
        mat003_correctness::trace(0,static_cast<const Base&>(*this),static_cast<const Base*>(&other),before);return *this;
    }
    cybersand::Material material_value() const noexcept {return static_cast<cybersand::Material>(this->get(0,16));}
    std::uint16_t state_a_value() const noexcept {return this->get(16,16);}
    std::uint8_t state_b_value() const noexcept {
        auto value=static_cast<std::uint8_t>(this->get(32,8));
        return material_value()==cybersand::Material::Water?value&((1U<<CYBERSAND_DELAY_BITS)-1U):value;
    }
    Epoch epoch_value() const noexcept {return this->get(Base::epoch_start,epoch_bits);}
    void set_material(cybersand::Material v) noexcept {this->put(0,16,static_cast<std::uint16_t>(v));}
    void set_state_a(std::uint16_t v) noexcept {this->put(16,16,v);}
    void set_state_b(std::uint8_t v) noexcept {this->put(32,8,material_value()==cybersand::Material::Water?v&((1U<<CYBERSAND_DELAY_BITS)-1U):v);}
    void set_epoch(Epoch v) noexcept {this->put(Base::epoch_start,epoch_bits,v);}
    std::uint16_t neutral_extra() const noexcept {return this->read().r;}
    bool set_neutral_extra(std::uint64_t v) noexcept {
        const Base before=*this;const bool ok=v<=65535&&(Base::supports_r||v==0);
        if constexpr(Base::supports_r)if(ok)this->put(Base::r_start,16,v);
        mat003_correctness::trace(3,static_cast<const Base&>(*this),static_cast<const Base*>(nullptr),before,v,ok);
        return ok;
    }
    static EngineCell for_material(cybersand::Material m) noexcept {
        EngineCell c; c.set_material(m);const auto& d=cybersand::material_definition(m);
        c.set_state_a(m==cybersand::Material::Water?cybersand::precision::maximum:d.initial_state_a);c.set_state_b(d.initial_state_b);return c;
    }
};
using Cell=EngineCell;
static_assert(sizeof(Cell)==sizeof(Cell::Base)&&alignof(Cell)==alignof(Cell::Base));
inline auto get_extra(const Cell& c) {return c.neutral_extra();}
inline void set_extra(Cell& c,std::uint16_t v) {if(!c.set_neutral_extra(v))throw std::invalid_argument("neutral16 capability refusal");}
struct DispatchObservations {std::uint64_t calls,dispatched_tasks,worker_tasks;};
inline std::uint64_t clear_count=0,clear_cells=0;
inline std::atomic<std::uint64_t> calls{0},tasks{0},workers{0};
inline void observe_dispatch(std::size_t n){++calls;tasks+=n;}
inline void observe_worker_task(){++workers;}
inline DispatchObservations dispatch_observations(){return {calls.load(),tasks.load(),workers.load()};}
inline void reset_dispatch_observations(){calls=0;tasks=0;workers=0;clear_count=0;clear_cells=0;}
}
