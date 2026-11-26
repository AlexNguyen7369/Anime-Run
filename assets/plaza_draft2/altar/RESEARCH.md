# Summon altar draft: market research (2026-11-25)

General style only. No image, model, texture, emblem or name was copied or downloaded. Web pages were read as text;
no game was played and no lobby was measured, so anything about a game's built structure is only what the page says.

## What the pages say

| Topic | Finding | Source |
|---|---|---|
| Anime Vanguards lobby | A large screen over the summon area shows three Mythic units (search summary of guides); banners sit to one side of the plaza and a menu teleports there; each banner shows 3 featured units, the middle one weighted higher | [allthings.how](https://allthings.how/anime-vanguards-on-roblox-how-to-get-and-equip-units/), [droidgamers](https://www.droidgamers.com/guides/anime-vanguards-banner/) (search result only) |
| Anime Adventures | Featured board above the summon sign (search summary; the page opened has no physical description) | [bloxodes](https://bloxodes.com/wiki/anime-adventures) |
| Anime Expeditions | Separate portals for showcase, summon and upgrades in a central hub (search summary) | [allthings.how](https://allthings.how/anime-expeditions-what-makes-it-roblox-s-standout-tower-defense-game/) (search result only) |
| SpongeBob TD | 3 banners, pity counter above the banner art (search summary) | [wiki](https://spongebobtd.fandom.com/wiki/Summon) (search result only) |
| Gacha pull scenes | Opening flash, a glowing orb against a dark ground as the focal point, light from the bottom that draws the eye up, a repeated "ritual" opening | [Toronto Metropolitan University, ch. 6](https://pressbooks.library.torontomu.ca/visualculture-howtosee/chapter/chapter-6/) |
| Honkai: Star Rail | Players wait for the pull scene and read small differences as a rarity tell (search summary) | [PC Gamer](https://www.pcgamer.com/uk/honkai-star-rails-gacha-animations-have-no-right-to-go-this-hard/) (search result only) |
| Landmarks | "Flags": tall, rise above the surroundings, contrast with the skyline; moving smoke, leaves and particles carry them further; short ones fail because they are not seen from afar; objects blocking the view were removed | [Ghost of Tsushima talk](https://gamedeveloper.com/design/a-taxonomy-of-weenies-the-landmarks-that-define-i-ghost-of-tsushima-i-) |
| Scene budget | Example baseline device: below 1,000 draw calls and 1,000,000 triangles; avoid transparency other than 0 and 1; reuse meshes and textures; draw distance is at least 500 studs at the lowest quality | [Roblox: Design for performance](https://create.roblox.com/docs/performance-optimization/design) |
| Cost order | Triangles matter less than draw calls; layered partial transparency redraws pixels; particles batch badly; lights and shadows are costly: fewer lights, no shadows; images at most 512 px | [Roblox: Improve performance](https://create.roblox.com/docs/performance-optimization/improve) |
| Particles | 400/s per emitter, 100/s on mobile; big particles cost fill rate, many layers cost overdraw; flipbooks switch off on low memory | [Roblox: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) |
| Low graphics | Forum only: at quality 1 an effect of 50-100/s is unusable, 3-5 good. The altar must read with no particles | [DevForum](https://devforum.roblox.com/t/how-to-optimize-vfx-and-retain-quality-at-low-graphics/2804870) |
| Beams | Flat strip between 2 attachments, 2 triangles between segments, can face the camera; test at lowest quality | [Roblox: Beams](https://create.roblox.com/docs/effects/beams) |
| Mesh limit | 20,000 triangles per mesh; watertight; no zero thickness | [Roblox: Mesh specifications](https://create.roblox.com/docs/art/modeling/specifications) |

## Read across to our altar (our conclusions, not the sources')

1. The featured unit is the advert. Ours is a live 3D model: it should be bigger and framed (a disc, petals or rings).
2. One dominant silhouette above the neighbours, then one vertical light. The sky loop (top y 30) is the bar to beat.
3. The vertical light is one Beam pair, not stacked transparent meshes. Solid Neon geometry carries the glow.
4. The shape must hold with particles off. Motion (petals, rings, turning model) is cheap and reads at every quality.
5. A locked altar that is the same thing asleep (closed, unlit, chained) also advertises.

## Proposed phone budget for the whole altar (ours, not a Roblox number)

- At most 12,000 triangles in at most 12 MeshParts, one 128 px palette texture, no SurfaceAppearance; the rotation
  model comes on top, as today.
- At most 3 Beams, 3 ParticleEmitters, 30 particles a second in total, life up to 3 s (about 90 alive), size up to 2
  studs, no flipbooks. Off beyond 150 studs and under reduced effects.
- At most 2 PointLights, no shadows. Neon parts cast no shadow. Collision is simple Parts for steps only.
