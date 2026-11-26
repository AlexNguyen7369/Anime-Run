# VFX lessons

Rules the developer has taught about effects, each with the moment behind it. Newest
at the bottom. These win over the references when they disagree. Add one entry
per piece of feedback: the rule, then **Why** (what happened) and **How to
apply**.

## 1. Actual VFX, never 3D objects

Build effects from ParticleEmitters, Beams and Trails with textures. Never
from 3D objects such as sphere or ball-cluster "puffs".

**Why:** after a "flat, terrible coloring" complaint on a strategy game's
explosions, they were remade as shaded 3D ball clusters, and those were rejected
too: they read as 3D objects, not effects.

**How to apply:** fix flatness with particle technique instead:
- layered flipbook emitters with offset spawn shapes, random rotation and
  staggered `EmitDelay`;
- colour and size sequences; a dark layer or black twin for value
  (`vfx-design.md` §3);
- soft opaque smoke textures at `LightInfluence` 1 so the scene shades them;
- warm colour ramps, and smoke beside fire carrying the fire's colour.

## 2. Cosmetic trails are flamboyant and long, never stubs

Vehicle trails and auras are paid show-off cosmetics: long (well past the car's
own length), layered, and full of particles. A clean flat ribbon with one or two
accents is not enough.

**Why:** a first redesign of an idle racer's Rainbow and Void trails (ribbons of
40-54 studs, one sparkle or wisp layer each) was rejected: "more flamboyant and
longer trails", the Void trail "too one dimensional and no particle effects", the
Rainbow "a bit thinner with the same fx but not like a stub and more longer".

**How to apply:**
- Trail `Lifetime` 1.8-2.5 s (80-110 studs at cruise speed), with a tail that
  breaks up rather than ending in a blunt cut.
- Height as well as length: rising particles, flames or shards above the
  ribbon, so the effect is not a flat stripe on the road.
- At least three particle layers per trail (body, sparkle, debris or smoke),
  plus a dark layer for value.
- Thin is fine when the effect is long; width is not what makes it read.

## 3. Auras frame the car; they are not a show of their own

An aura stays close to the vehicle and reads as energy coming off it. Keep it
calmer than a trail: no gyroscopes, orbiting planets, tornadoes or extra
geometry spinning round the car.

**Why:** a round of "eccentric" auras (atom rings with orbs, a fire tornado
with an orbiting fireball, an orrery of tilted rune rings and planets) was
judged too flamboyant and eccentric, and the Ember aura still "too static".
The owner pointed at the Dragon Ball Z aura as the model.

**How to apply:**
- Dragon Ball Z style: a sheath of short-lived flame tongues hugging the
  body (`LockedToPart`), emitted from round the outline and rising fast
  (lifetime 0.25-0.5 s, upward speed and acceleration), so it flickers
  constantly instead of sitting still.
- Two layers: a white-hot inner sheath (`LightEmission` 1) and a coloured
  outer one, plus fast streaks shooting up and a soft ground glow or pulse.
- Motion comes from short lifetimes and speed, not from objects orbiting.
