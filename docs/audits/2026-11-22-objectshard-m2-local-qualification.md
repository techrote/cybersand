# OBJECTSHARD-001 M2 local qualification checkpoint — 22 November 2026

This is source-specific Draft/HOLD evidence, not Windows execution, published
runtime acceptance, owner physical acceptance or merge permission. The candidate
is the M2 child of M1 `1b85782a15565bad7e4dae28755b17d630daaf46`; the remote M2
commit and hosted artifacts are recorded in the PR conversation after publication.

## Exact reviewed implementation

| File | SHA256 |
| --- | --- |
| `native/src/object_shard_coordinator.cpp` | `048411c19605f52c9a25793ca7752e7b8f2ad7248dffb934762e209c0c834078` |
| `native/include/cybersand/object_shard_coordinator.hpp` | `de31d9404a364268a46f2413c56a919614c65a37d22a4f26342241d2e27a46c6` |
| `native/include/cybersand/object_shard_contact.hpp` | `69c4682e277380866b97600eb941eaf8288b39df1c6fea8b12913006f616407f` |
| Protected `native/src/world.cpp` | `bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214` |

## Native and independent evidence

| Executed scope | Result | Identity / limitation |
| --- | --- | --- |
| Compact storage | 8,125 checks / 0 failures | Unchanged storage source, exact captured inputs |
| Contact geometry | 44,817 / 0 | Final relocation-helper and aperture tests |
| Coordinator | 3,018 / 0 | Final side-entry history, quota, relocation and population regressions |
| World shared-chemistry oracle | 4,472 / 0 | Actual original/extracted World wrappers, not helper-only tests |
| Existing full World inventory | 192 test cases / 0 | All unchanged tests, no name filter; established warning policy for old test TUs |
| Independent final protocol deltas | 350 checks / 0 | 52 budget-history,154 relocation,144 injected-write fault checks |
| Python package/custody/performance contracts | 28 tests / 0 | Includes missing/ambiguous custody, altered source/runtime and false completion |

The applicable ObjectShard total is **60,432 atomic checks / 0**, with World
test-case and Python counts kept separate. Final affected native input digest:
`ecccb237c69a2f05ccef8f723818d4fbd563b8821ae3816296be8c7afec1a1f0`.
The matching sanitizer capture is
`7256bac9948febb728d56704e4713be21497d9eb0d0f2558791196fd512e62f3`;
both normal and ASan/UBSan affected suites completed47,835 checks with zero
failures, with identical captured source maps verified. Earlier whole-catalogue
ASan/UBSan passed60,261 checks before the last relocation repair; the affected
delta, not that older pass alone, qualifies the repair. LeakSanitizer was
explicitly disabled.

The fresh reviewer independently rebuilt accepted original World source at
`30e1cddd3d678456df10f52f7a2fb2210a9daaad` and the current extracted wrapper.
All20 JSON fixture records and4,248 semantic observations were byte-identical.
The comparison includes16 original fixtures plus four independently authored
serial/phased fixtures for signed coordinates, Wood/Plant combustion, Fire/Smoke
lifetime boundaries,320-tick epoch wrap, temperature, accounting and hashes.
Identical output SHA256:
`b8e82e4781ef559e15633da37e9eb78d182db2a4794336e78f1227e63e2973a1`.

Independent review manifest SHA256:
`1b82a9f5e7f70484dc56828806e2810576961b5390b7dd840f8584ed2d3c3b71`.
The reviewer authored no implementation and made no tracked or remote changes.
Its verdict found no unresolved confirmed Class A/B finding in the inspected
native ownership, chemistry, physical transfer/history or custody boundaries.
Exact committed-head, platform, rendered and package evidence still require a
final delta review.

## Actual local Godot execution

Godot **4.7.2**, GCC14.2 local iteration and the selected verified Rapier runtime
executed the source-built extension; these are not the pinned hosted4.7 tools.
The final M2c actual-Lab suite passed **373 checks / 0**. DLL/ELF identity here is
the Linux extension SHA256
`36c04d20a1ae713466342b26454eb73f13e79f93ac9ec29c20df4d62c67584ef`.
Evidence resides in `build/objectshard-iteration-m2c` with frozen source and logs.

The suite observes actual Rapier sleeping while chemistry continues, ordinary
support removal, genuine falling/rotation/impact, changed exact geometry, real
products and delivery, C's physical Sand lodging and non-consuming Water
extinction, and three independently owned bodies. A moved body is consumed and
retired while product inventory remains; inspection/render coordinates now keep
the last authoritative pose. Native ACK mocks alone are not this result.

## Retained failures and repairs

Earlier M0/M1/M2 fixture failures remain attached to their old source, including
the enclosed burn opportunity, overly narrow lodging opening and legitimate
Fire re-ignition delaying erosion. The implementation was not qualified by
changing chemistry to satisfy those observations.

Independent adversarial review reproduced invalid sideways entry becoming valid
on a stationary frame, missing entry history when transfer quota was exhausted,
and mechanical relocation placing rejected Sand inside a pocket. Persistent
aperture fences, unconditional first-pass history sampling, then bounded transfer
proposals, and shared pocket-column relocation exclusions repaired those paths.
Original failed probes remain in the review directory beside passing deltas.

The newest permanent regression initially omitted its contact-header include;
the failed test build is retained, then the corrected test was recaptured. The
production source hashes above did not change for that harness repair.

## Documentation, provenance and remaining acceptance

Documentation structure passes147 documents,4,144 local links and806 anchors.
Frozen lexical retrieval reports18/32 top-one and30/32 top-five canonical hits;
the five additive ObjectShard questions report4/5 and5/5. Canonical hits are not
semantic answer verification. Historical M11 integrity passes18 records and28
hashes without rewriting historical evidence. The hosted-provider checker passes.

`check_repository.py` correctly refuses current-runtime acceptance: retained
repository native binaries still describe earlier source. That gate was not
weakened or relabelled. The dedicated workflow builds exact candidate binaries
and a self-verifying Windows evaluator; it does not perform four-path production
runtime publication. Therefore even successful candidate artifacts do not make
these Draft branches merge-ready under ordinary publication policy.

Final hosted Linux/Windows execution, ten actual PNG captures per platform,
registered performance budgets, delivered-package replay and final-source review
remain explicit gates. The owner must separately evaluate the package on the
intended Windows11/NVIDIA machine. No Ready promotion, merge, auto-merge,
production-default change or release occurred.
