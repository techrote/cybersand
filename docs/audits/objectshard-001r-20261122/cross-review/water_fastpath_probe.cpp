#define main original_external_fire_main
#include "crossdomain-repaired-source/native/tests/test_object_shard_external_fire.cpp"
#undef main
int main() {
 Coordinator c(fixture_config());const auto h=promote(c,48,11);if(!h.id)return 2;
 advance_to(c,212);CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
 CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);CHECK(ignition_events(c)==1);
 CHECK(c.edit(49,11,{Material::Water,255,0,200}).outcome==Outcome::Accepted);
 CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
 CHECK(CoordinatorTestAccess::exposures(c).size()==2);
 CHECK(c.edit(49,11,{Material::Empty,0,0,200}).outcome==Outcome::Accepted);
 CHECK(c.world().quantity_ledger().material_cells[static_cast<std::uint8_t>(Material::Water)]==0);
 CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);
 CHECK(CoordinatorTestAccess::exposures(c).size()==2);
 CHECK(c.step(poses(c)).outcome==Outcome::Accepted);
 CHECK(c.accounting().external_ignitions==1);CHECK(c.accounting().extinguished==1);
 CHECK(c.registry().find(h)->payload(wood_cell(c,h)).state_b==0);
 inventory_balance(c);
 std::printf("%llu checks, %llu failures\n",(unsigned long long)checks,(unsigned long long)failures);return failures?1:0;
}
