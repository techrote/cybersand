#define main original_external_fire_main
#include "repaired-source/native/tests/test_object_shard_external_fire.cpp"
#undef main
int main() {
 Coordinator c(fixture_config()); const auto h=promote(c,48,11); if(!h.id)return 2;
 advance_to(c,212); CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
 auto p=poses(c); CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 std::printf("first exposures=%zu\n",ignition_events(c));
 p=poses(c);p[0].y+=1;CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 std::printf("after relocation exposures=%zu fire(47,11)=%d\n",ignition_events(c),int(c.inspect_world(47,11).material));
 p=poses(c);p[0].x-=2;CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 std::printf("after second opportunity exposures=%zu\n",ignition_events(c));
 for(const auto&e:CoordinatorTestAccess::exposures(c))std::printf("event source=(%lld,%lld) tick=%llu cell=%u\n",(long long)e.source_x,(long long)e.source_y,(unsigned long long)e.first_tick,e.cell);
 CHECK(c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Fire)]==1);
 CHECK(ignition_events(c)==1);
 std::printf("%llu checks, %llu failures\n",(unsigned long long)checks,(unsigned long long)failures);
 return failures?1:0;
}
