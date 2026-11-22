#define main original_external_fire_main
#include "crossdomain-repaired-source/native/tests/test_object_shard_external_fire.cpp"
#undef main
int main() {
 Coordinator c(fixture_config()); const auto a=promote(c,48,11); const auto b=promote(c,46,12);if(!a.id||!b.id)return 2;
 advance_to(c,212); CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
 auto p=poses(c);CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 p=poses(c);for(auto& q:p)if(q.shard==a)q.y+=1;CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 CHECK(c.inspect_world(47,11).material==Material::Fire);
 p=poses(c);CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 for(const auto&e:CoordinatorTestAccess::exposures(c))std::printf("event source=(%lld,%lld) tick=%llu shard=%llu cell=%u\n",(long long)e.source_x,(long long)e.source_y,(unsigned long long)e.first_tick,(unsigned long long)e.shard.id,e.cell);
 CHECK(c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Fire)]==1);
 CHECK(ignition_events(c)==1);
 CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
 std::printf("external_ignitions=%llu burnA=%u burnB=%u\n",(unsigned long long)c.accounting().external_ignitions,c.registry().find(a)->payload(wood_cell(c,a)).state_b,c.registry().find(b)->payload(wood_cell(c,b)).state_b);
 CHECK(c.accounting().external_ignitions==1);
 inventory_balance(c);
 std::printf("%llu checks, %llu failures\n",(unsigned long long)checks,(unsigned long long)failures);
 return failures?1:0;
}
