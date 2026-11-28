# Reviewed transport compiler value reuse

Date: 28 November 2026. Mission: PUBPRES-MAINLINE-CONVERGENCE-001, PR #767.
This dated engineering record grants no physical acceptance or merge authority.

The protected `godot/scripts/transport_profiles.gd` consumer changes from LF
SHA-256 `5497757c0950082b57be0f95760680cb05c631422940a1d6efcbff010a42b6a0`
to `4e97c1d67ef87b8a610024c71837a506ff13d95181179bbc7bd8e17cd361241a`
at committed integrated source `d906d18d0c63b471b176f99a8e4f57e87b836c2c`.

The compiler retains one deeply copied and recursively frozen valid input,
its independently owned 39,529-integer compiled packet and its existing hash.
Every public request still performs the original schema, range, material and
pair-policy validation. An exact input match returns copies; every miss runs the
unchanged expansion and directed carrying-law validation. A mutex protects the
bounded three-field value transfer. Compilation runs outside that lock. No
World, native worker, physical body, publication or material history is cached.

The independent pre-repair output hashes for all three presets are:

- `1b27b4e934dc7560e6901eb09e634ed604c0111dcf26d5dac6b10885a3e5e268`
- `a4593c9c8632463d5b9100233809b530ef7043502bcd66444fa7930a422816e7`
- `57d8ed905b2ad52c6f1372560c4fafb9dad5a03135ca987dee05f6167428e079`

`test_transport_profile_reuse.gd` checks those complete packets, nested caller
and returned-value mutations, changes and restoration of actual inputs, renamed
metadata, invalid carrying direction/ranges/schema, and two concurrent callers.
Its local 18 assertions passed. The original native transport regression also
passed; resulting-source Linux and Windows execution is registered separately.
The presentation specialist and principal independently reviewed the value,
validation, mutation and concurrency contracts. No material law or field
precedence changed. This transition admits those reviewed source bytes; it does
not waive any native, Water, graphical, performance or physical acceptance gate.

The first hosted source gate correctly refused the otherwise reviewed edit
because this explicit identity record was missing. Its failed result is retained
in run `46134343592`; it is not relabelled as a pass. The corrected campaign must
execute the original compatibility checker and native-parity reader again.

## Object lifetime refinement

The independently reviewed subsequent source
`7f9bc26c1c5e51de9497868f4604ea07458c870c` changes
`godot/scripts/transport_profiles.gd` from
`4e97c1d67ef87b8a610024c71837a506ff13d95181179bbc7bd8e17cd361241a` to
`ca36baa34c14cf4d95519cf7b7bc9b46dc9f794bf1882110eae5e7353b4c9b21`.
The existing validator stringifies dictionary keys, permitting unusual scripted
Object keys. Such keys now bypass value reuse while retaining the original
acceptance and compilation behavior. The bounded cache cannot prolong those
objects' lifetimes. Ordinary JSON/Workbench scalar keys retain the measured path.
A new WeakRef lifetime control extends the focused gate from 18 to 20 checks.
The native specialist executed those 20 checks successfully; the presentation
specialist independently reviewed the new lifetime boundary and test. Earlier
18-check timing evidence remains attributed to its original source. The final
20-check source must pass the new Linux and Windows hosted campaign.
