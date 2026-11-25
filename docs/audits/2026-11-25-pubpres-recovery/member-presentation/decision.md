# Actual multipart history and Follow ownership

The actual native reproduction at source `e14c94c1f1ccdf02508a5e9e3ebce45b45f03b3d`
failed 56 of 129 assertions. Six accepted authored actors had 24 actual physical
members. Every member at index8–23 lacked a presentation observation at initial
step0, after twelve real Rapier steps, and after native owner replacement.
Follow for authored actors3–6 (and replacement60) selected a different body's
pose. Original source hashes, independent actual member mappings, clocks and
all failure bytes are retained under `original/`.

The cause is two index-domain mistakes. The history's historical eight-actor
limit was applied to the physical member index passed by production. Follow
indexed selected physical poses with an authored actor slot, without resolving
that actor's root body through the bridge's actual multipart mapping.

The repair preserves the frozen unbound eight-slot history API. Production
explicitly binds the current actual bridge/session/epoch and exact admitted
member identities before recording physical observations. The bound capacity
cannot exceed the native coupling limit64; a different owner or member list
clears every old timeline. Invalid slots and wrong identities still refuse.
The original128-step ring and completion-clock semantics remain unchanged.
Follow resolves the selected actor through `actor_body_index` before reading
its actually selected root pose.

This binding belongs to true physical-observation history, not visible history.
Preparing or rejecting a draw may observe an already real physical state; it
cannot renew that state's completion time or advance submitted pose, Follow,
camera, material or fairness journals. The existing immutable transaction still
commits those journals only at actual engine admission.

Required qualification is the unchanged frozen history test, adversarial bound
ownership/ring/lifecycle tests, and replay of the actual24-member fixture with
graphical body visibility and selected mapping. No timing improvement or owner
hardware acceptance is claimed by this correctness repair.
