#include "cybersand/cell_layout_storage.hpp"
#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>

using namespace cybersand;
using Cell = detail::CellLayoutStorage;
static void require(bool value) { if (!value) throw std::runtime_error("cell storage mapping/copy/isolation failed"); }

int main() {
    try {
        std::uint64_t cases = 0, checksum = 0;
        constexpr std::array<std::uint8_t,5> epochs{0,1,63,64,255};
        for (std::uint16_t id=0; id<256; ++id) {
            if (!valid_material(id)) continue;
            const auto material = static_cast<Material>(id);
            for (unsigned state=0; state<65536; ++state) for (auto epoch : epochs) {
                const auto a=static_cast<std::uint8_t>(state & 255U);
                const auto b=static_cast<std::uint8_t>(state >> 8U);
                auto cell=Cell::for_material(material);
                cell.set_state_a(a); cell.set_state_b(b); cell.set_epoch(epoch);
                require(cell.material_value()==material && cell.state_a_value()==a &&
                        cell.state_b_value()==b && cell.epoch_value()==epoch && cell.unused_zero());
#if defined(CYBERSAND_CELL_LAYOUT_PACKED) && CYBERSAND_CELL_LAYOUT_PACKED
#if CYBERSAND_CELL_LAYOUT_EXPERIMENT == 8
                const auto expected=std::uint64_t{id} | (std::uint64_t{a}<<16U) |
                    (std::uint64_t{b}<<24U) | (std::uint64_t{epoch}<<56U);
#else
                const auto expected=std::uint32_t{id} | (std::uint32_t{a}<<8U) |
                    (std::uint32_t{b}<<16U) | (std::uint32_t{epoch}<<24U);
#endif
                require(cell.bits==expected);
#endif
                auto copy=cell;
                copy.set_state_a(static_cast<std::uint8_t>(255U-a));
                require(copy.material_value()==material && copy.state_b_value()==b &&
                        copy.epoch_value()==epoch && cell.state_a_value()==a);
                copy.set_state_b(static_cast<std::uint8_t>(255U-b));
                require(copy.material_value()==material && copy.state_a_value()==255U-a && copy.epoch_value()==epoch);
                copy.set_epoch(static_cast<std::uint8_t>(255U-epoch));
                copy.set_material(Material::Wall);
                require(copy.material_value()==Material::Wall && copy.state_a_value()==255U-a &&
                        copy.state_b_value()==255U-b && copy.epoch_value()==255U-epoch && copy.unused_zero());
                require(cell.material_value()==material && cell.state_a_value()==a &&
                        cell.state_b_value()==b && cell.epoch_value()==epoch);
                checksum+=cell.state_a_value()+cell.state_b_value()+cell.epoch_value()+id;
                ++cases;
            }
        }
        require(cases==26'214'400);
        std::cout<<"lossless mappings="<<cases<<" size="<<sizeof(Cell)<<" alignment="<<alignof(Cell)
                 <<" checksum="<<checksum<<'\n';
    } catch (const std::exception& e) { std::cerr<<e.what()<<'\n';return 1; }
}
