# Enemy aura: plan (proposed, not built)

Owner 2026-11-04: draft only. Nothing here is a rule until the owner approves it and it moves into the design doc.

## Goal
Each track enemy gets a signature effect, so the player can read it at a glance and it feels like a boss. Effects only: no gameplay
change, no new models.

## Effect per enemy (proposed)

| Track | Enemy | Effect | Note |
|---|---|---|---|
| 1 | Paine | slow gravity ripple rings at the feet | |
| 2 | Selle | green energy wisps | |
| 3 | Arlon | water droplets and spray | |
| 4 | Akazo | a pale blue compass ring on the ground | any ring pattern is a mark: a clearly different shape (design doc 5) |
| 5 | Jogoh | embers and heat smoke from the head | |
| 6 | Shigaraky | dust flakes falling from the hands | |
| 7 | Mahitoh | drifting blue-grey soul specks | |
| 8 | Enelu | blue-white sparks over the drum ring | |
| 9 | Ulquiorro | dark green mist, low to the ground | same effect only on the enemy, not the rollable character |
| 10 | Freezo | violet energy glow | |

## How it would be built
- `roblox-vfx` skill: layered ParticleEmitters with in-house flipbooks drawn for this game.
- Data: an `Aura` field on `NpcConfig.Tracks[n]`, naming one effect. A client-only builder attaches it in `NpcRacer.BuildModel`.
- The enemy exists on one client, so nothing replicates. Reduced Effects removes the aura, as it does other effects.
- Budget (proposed): at most 2 emitters, 30 particles per second per enemy.

## Tests
- `npc`: every track names a known effect; a rig with Reduced Effects has no emitters.
- Studio: one screenshot per enemy; performance on Track 10 at speed.

## Open questions (owner)
1. Do you want the same aura on the character when a player owns it? Proposed no: it keeps the enemy distinct. Ulquiorro and Freezo are both also rollable.
2. Always on, or only near the player? Proposed always on, since one enemy costs little.
3. Should the effects be subtle or big? Proposed: readable at 100 studs, never covering the road.
