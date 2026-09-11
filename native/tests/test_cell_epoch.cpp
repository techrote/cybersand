#include "cybersand/world.hpp"
#include "cybersand/cell_layout_experiment.hpp"
#include "cybersand/cell_layout_storage.hpp"
#include <array>
#include <iostream>
#include <stdexcept>
#include <source_location>
#include <string>
using namespace cybersand;
static void check(bool b,std::source_location loc=std::source_location::current()){if(!b)throw std::runtime_error("epoch mapping/clear/capacity invariant line"+std::to_string(loc.line()));}
int main(){try{
 using Cell=detail::CellLayoutStorage;
 constexpr unsigned mask=(1U<<CYBERSAND_CELL_LAYOUT_EPOCH_BITS)-1U;
 std::uint64_t cases=0;
 for(unsigned id=0;id<256;++id)if(valid_material(static_cast<std::uint16_t>(id)))
  for(unsigned state=0;state<65536;++state)for(unsigned e:std::array<unsigned,5>{0,1,mask/2,mask-1,mask}){
   Cell c{};c.set_material(static_cast<Material>(id));c.set_state_a(static_cast<std::uint8_t>(state));c.set_state_b(static_cast<std::uint8_t>(state>>8U));c.set_epoch(static_cast<std::uint8_t>(e));
   const auto expected=id|((state&255U)<<8U)|((state>>8U)<<16U)|(e<<Cell::epoch_shift);
   check(c.bits==expected&&c.unused_zero()&&c.epoch_value()==e);
   auto d=c;d.set_epoch(static_cast<std::uint8_t>(mask-e));
   check(c.bits==expected&&d.material_value()==c.material_value()&&d.state_a_value()==c.state_a_value()&&d.state_b_value()==c.state_b_value()&&d.epoch_value()==mask-e&&d.unused_zero());++cases;
  }
 check(cases==26'214'400);
 for(unsigned workers:{1U,4U}){
  WorldConfig cfg{};cfg.worker_threads=workers;World w(cfg);CellLayoutExperiment::configure_epochs(w);
  w.reserve_region({-128,0,384,128});
  for(int x:{-128,0,128})w.set(x,0,Material::Wall);
  (void)w.tick();
  for(int x:{-128,0,128}){check(w.set_cell_state(x,0,Material::Wall,255,255));w.set_temperature(x,0,315);check(CellLayoutExperiment::epoch_at(w,x,0)==1);}
  w.set_simulation_region(RectI64{0,0,192,128});
  for(unsigned tick=2;tick<=2048;++tick){(void)w.tick();if(tick>=mask+1&&(tick-mask-1)%mask==0){
   for(int x:{-128,0,128})check(CellLayoutExperiment::epoch_at(w,x,0)==0&&w.stored_state_a(x,0)==255&&w.temperature(x,0)==315);
  }}
  const auto* tr=CellLayoutExperiment::epochs(w);check(tr&&tr->used==(CYBERSAND_CELL_LAYOUT_EPOCH_BITS==6?32U:8U));
  for(std::size_t i=0;i<tr->used;++i){const auto& e=tr->samples[i];check(e.tick==mask+1+i*mask&&e.count==3);
   unsigned excluded=0,partial=0,sleeping=0;for(std::size_t j=0;j<e.count;++j){const auto& c=tr->chunks[e.first+j];check(c.cells==16384);excluded+=c.selection==0;partial+=c.selection==1;sleeping+=!c.active;}
   check(excluded==1&&partial==1&&sleeping>=1);
  }
 }
 for(bool limit_chunks:{false,true}){
  World w;CellLayoutExperiment::configure_epochs(w,limit_chunks?64:1,limit_chunks?0:4096);w.set(0,0,Material::Wall);
  bool failed=false;try{for(unsigned i=0;i<2*mask+1;++i)(void)w.tick();}catch(const std::runtime_error&){failed=true;}
  check(failed&&w.has_failed());const auto completed=w.completed_tick_index();
  bool rejected=false;try{(void)w.tick();}catch(const std::logic_error&){rejected=true;}check(rejected);
  check(w.completed_tick_index()==completed);w.clear();check(!w.has_failed()&&CellLayoutExperiment::epochs(w)->used==0);(void)w.tick();
 }
 std::cout<<"epoch_bits="<<CYBERSAND_CELL_LAYOUT_EPOCH_BITS<<" mappings="<<cases<<" sleeping/excluded/partial/capacity checks passed\n";
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
