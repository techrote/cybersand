#define main original_coordinator_main
#include "sand-source/native/tests/test_object_shard_coordinator.cpp"
#undef main
int main() {
 Coordinator c(small_config());const auto h=open_pocket(c);if(!h.id)return 2;
 auto p=next_poses(c);p[0].x+=2;CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 CHECK(c.edit(31,31,{Material::Sand,213,217,-470}).outcome==Outcome::Accepted);
 p=next_poses(c);p[0].x-=2;CHECK(c.accept_motion(p).outcome==Outcome::Accepted);
 CHECK(CoordinatorTestAccess::ingress_fences(c)==1);
 CHECK(c.edit(34,31,{Material::Sand,71,0,200}).outcome==Outcome::Accepted);
 const auto pose=c.snapshot().bodies[0].pose;
 auto old=CoordinatorTestAccess::disable_relocation(c);
 p=next_poses(c);p[0].x+=2;auto result=c.accept_motion(p);
 std::printf("refusal=%s fences=%zu pose_x=%.3f original_x=%.3f\n",outcome_name(result.outcome),CoordinatorTestAccess::ingress_fences(c),c.snapshot().bodies[0].pose.x,pose.x);
 CHECK(result.outcome==Outcome::Capacity);CHECK(c.snapshot().bodies[0].pose.x==pose.x);
 CHECK(CoordinatorTestAccess::ingress_fences(c)==1);
 CoordinatorTestAccess::restore_relocation(c,old);
 CHECK(c.accept_motion(next_poses(c)).outcome==Outcome::Accepted);
 CHECK(c.step(next_poses(c)).outcome==Outcome::Accepted);
 std::printf("cargo=%llu fences=%zu\n",(unsigned long long)c.registry().find(h)->counts().cargo,CoordinatorTestAccess::ingress_fences(c));
 CHECK(c.registry().find(h)->counts().cargo==0);
 check_population_balance(c);
 std::printf("%llu checks, %llu failures\n",(unsigned long long)checks,(unsigned long long)failures);
 return failures?1:0;
}
