---
title: Owner actor observations on the quick-play builds
status: Current
document-kind: audit
scope: Owner-supplied notes received 2026-10-18; subjective observations and preferences, not runtime validation
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../operations/physical-actor-programme.md]
---

# Owner notes received 2026-10-18

Original filename: `october 18 cybersand observations.txt`.
Original byte SHA-256: `84a9667157327a68bb5283769d629487da10eeb7faf2b076189a39d3c5c67d94`.
The following is the supplied text, with line endings and trailing whitespace normalized. Later
conversational additions are preserved in the linked programme.

```text
player barrel-rapier horizontal impulse only very interesting and "physical"/kinetic feeling, some "sands" interactions not super realistic (tunnels right through it) but that can be tuned. player/water/barrels interaction VERY convincing. Could be even better with torque control.
"burial safe" mode in 03-actor-sandbox pins characters in place if only a single pixel overlaps. So I think we should consider treating most actors as rapier objects and controlling with impulses.

Player sampled baseline mode in 05-material-effects-sandbox fixes the "getting stuck" problem, but that player motion  seems to look more visually jittery, but maybe that's an optical illusion just because it's held perfectly upright.

With regards to torque, I like that you made the actors with the most "magic" torque have a hardscifi justification: gyros! And my favs scripted bots are definitely vector and jolt. You should give the rest of the little bots a similar level of energy and vigour.

I think what may have been missing from my initital description, is that some of these actors should be built from several hinged rapier objects. These objects can then torque against each other, for grounded realism and strong interactions.

For example I had imagined the scrabbler to be very much like the leaper from arc raiders.
The ripper similar to a Bursa from warframe crossed with an RC drift crawler.
The pouncer like a cybernetic headcrabbed flying squirrel
The digger like a little rocket powered mole, and once it's "dug in" it should then have the ability to "screw in" to it's burrowed hole and travel horizontally/vertically.

I do like how unstable the copter is, but I think it should be slightly easier to recover/hold in precarious balance. Not easy, but possible.
Maybe you should include a few more multirotor "fliers" with different flight properties and tradeoffs in shape/speed/COG/other stats.


Lineshank should be slim, like a katana, and have a centre of mass around where the hilt would be gripped. Also maybe it should become rocket propelled rather than bungee pulled.

Rocketjumper should spawn a blob of fire surrounded by a ring of gunpowder in the area of explosion.

Gyrocrate is great fun, it already feels alive!

Bellows also has character, feels like it's a food delivery bot that's just had enough of being underappreciated.

I see that you've given yourself the most capable seeming example script and a very reactive actor. Good decision, you'll need it!
```
