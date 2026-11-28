#define main original_external_fire_main
#include "crossdomain-repaired-source/native/tests/test_object_shard_external_fire.cpp"
#undef main
int main() {
 Coordinator c(fixture_config());const auto h=promote(c,48,11);if(!h.id)return 2;
 advance_to(c,212);CHECK(c.edit(48,12,{Material::Fire,32,0,650}).outcome==Outcome::Accepted);
 auto original=c.snapshot().bodies[0].pose;
 auto old=CoordinatorTestAccess::disable_relocation(c);auto p=poses(c);p[0].y+=1;
 auto result=c.accept_motion(p);CHECK(result.outcome==Outcome::Capacity);CHECK(ignition_events(c)==0);
 CHECK(c.accounting().accepted_exposures==0);CHECK(c.snapshot().bodies[0].pose.y==original.y);
 CHECK(c.inspect_world(48,12).material==Material::Fire);
 CoordinatorTestAccess::restore_relocation(c,old);
 CHECK(c.accept_motion(poses(c)).outcome==Outcome::Accepted);CHECK(ignition_events(c)==1);
 CHECK(c.step(poses(c)).outcome==Outcome::Accepted);CHECK(c.accounting().external_ignitions==1);
 std::size_t continued_fire=0;
 for(int y=0;y<96;++y)for(int x=0;x<96;++x){auto q=c.inspect_world(x,y);continued_fire+=(q.material==Material::Fire&&q.state_a==31);}
 CHECK(continued_fire==1);inventory_balance(c);
 std::printf("%llu checks, %llu failures\n",(unsigned long long)checks,(unsigned long long)failures);return failures?1:0;
}
