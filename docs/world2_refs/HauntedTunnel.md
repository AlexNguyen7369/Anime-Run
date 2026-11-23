# Track 4 HauntedTunnel: source references

Source: Dandadan (anime season 1, episodes 1-4, and the manga's opening chapters). Reference images are look-only.
They sit in `build/world2/refs/HauntedTunnel/`, which is gitignored and never ships. Everything in the biome is
modelled in-house from primitives. It has no text: the no-entry board, the rooftop sign and the notice boards are
blank panels. It has no logos, and no character likenesses (Turbo Granny's faces on the tunnel wall are not modelled).

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| Turbo Granny's tunnel portal | An old tunnel mouth, closed off, in Shono City (fans place it at the real Hata Tunnel in Hanno, Saitama). Horseshoe arch of dressed grey-green stone blocks in running bond, a raised voussoir ring, ivy pouring over the top and down the sides, yellow-and-black striped barriers and a red-and-white no-entry board in front, a small notice board on a pole at the side, green night light | https://dandadan.fandom.com/wiki/Tunnel, https://www.fun-japan.jp/en/articles/14048 | `tunnel_anime.ref.jpg` | `Portal` (hero, at both mouths; run shot 2 faces the entry): masonry laid block by block with uneven sizes, depths and tones, a 19-stone voussoir ring with a keystone, moss and water stains, ivy curtains down both spandrels to the ground and over the ring, barriers and the blank no-entry board by the walkways, a forested hill above, and the tunnel's only lamps (two per mouth, far inside) |
| Inside the tunnel | A round concrete lining in darkness, lit by pools of yellow light | https://dandadan.fandom.com/wiki/Tunnel | `tunnel_inside_anime.ref.jpg` | `TunnelSeg`: near-black round vault with walkways. The tunnel runs into the bend, so the exit is hidden and the mouth reads as a black void with a few separate yellow pools |
| Kami High | A white modern 4-floor block on a regular grid of white pillars and floor bands with large glass bays, a glass stair tower at the right end, an entrance canopy, brown brick gate walls and a green lattice sliding gate | https://dandadan.fandom.com/wiki/Kami_High | `school_anime.ref.jpg`, `school_rooftop.jpg` | `School` (hero, side shot and run shot 3): pillar grid, glass bays with mullions, glass stair tower, canopy, roof fence, blank clock face, rear wing, gym, brick gate walls with coping, lattice gate, forecourt trees |
| Nagi Hospital | An abandoned high-rise hospital outside Kamigoe City, said to be a UFO spot. A tall stained block with a grid of dark windows under a full moon in deep blue light, a rooftop sign of large characters, and a construction hoarding of corrugated panels with a hazard-striped post in front | https://dandadan.fandom.com/wiki/Nagi_Hospital | `hospital_anime.ref.jpg` | `Hospital` (hero, run shot 3): 12-floor block plus a side shaft and a lower wing, window grid with a few glowing windows, rain streaks, blank sign frame, water tank, corrugated hoarding with bars and hazard posts; blue key light and a big moon in the sky |
| Seiko's house | Momo's grandmother's home and shrine: a grey granite torii and stone pillars at a small stone bridge over a canal, a slatted wooden fence on a stone base, a house with white walls, timber framing and a rust-red tiled roof, garden trees | https://dandadan.fandom.com/wiki/Seiko_Ayase | `seiko_house_barrier.jpg` | `SeikoHouse` (hero, run shot 1): canal and bridge, granite torii, slat fence, two-floor plastered house with timber frame, engawa and rust-red kawara roofs, small hokora shrine with a straw rope and paper streamers, stone lanterns, garden pines |
| Night mountain road and rural town | A rural Japanese town at night and a winding mountain road through cedar forest: white W-beam guardrails, orange curve mirrors, tiled-roof houses, block walls, concrete utility poles, glowing vending machines | real Japanese road and town furniture (episode 1 setting, Shono City) | (none) | `Guardrail` (48-stud run with a concrete U-ditch and a grassy verge), `Mirror` (with a blank chevron curve sign), `House` (two floors, dark kawara gable, vending machine, utility pole) and `House2` (one floor, brown hip roof); both carry block walls across the whole lot and are placed at varied scales and facings. Also `Cedar`, `Mountain` (irregular stepped ridges covered in cedars) and `Fill` |

Not matched: the rooftop sign's lettering and the no-entry text (text is not allowed). The tunnel in the source is a
narrow single-lane tunnel. The game road is 36 studs wide, so the opening is wider and taller in proportion. The
hospital's later UFO damage is not modelled. The torii over the road from the first draft was dropped to stay within
the 12-mesh budget. Seiko's stone torii now carries the shrine read. Round 2 (2026-11-23): mirrored the school (glass tower now
on the viewer's right) and the hospital wings to match the source framing. The moon is placed up-left of run shot 3.

Round 3 (2026-11-23), judged in the 6 review shots:
- Seiko's torii is weathered grey granite (thick round pillars, a curved kasagi with upturned ends, shimaki, a nuki
  through the pillars, speckles) with stone bridge rails. It is placed downhill of run shot 1 at 2x scale, so the torii,
  the fence and the house fill the left of the frame.
- The portal hill rises back from the parapet under ivy and cedars. The voussoirs are 10 large stones in one grey-green
  tone with a stepped reveal. The ivy hangs as a heavy, uneven mass over the right of the arch. Three large A-frame
  barriers and a tall red-and-white board stand at the mouth. The vault is a black void, under a stronger green wash.

Round 4 (2026-11-23): curve mirrors are turned 50 degrees toward the oncoming runner, so they read as round discs. The
hospital sign is a dark frame of six blank panels on a stepped crown. The ivy is small, flat leaf clusters, and the
ring is left bare. Houses have sliding-door bays, balconies, capped block walls, lit vending fronts and linked poles.
The school has a deep slab canopy and tall brick piers.

Round 5 (2026-11-23):
- Seiko's set stands on a raised embankment. A dark canal runs at its front edge, with a stone bridge and square-post
  parapets. The torii is warm-grey speckled granite with round pillars. A brown slatted fence stands on a stone base.
- The hospital is at 1.3x scale with a regular grid of framed windows and dark unlit sign panels. Its hoarding and
  hazard posts are 26 from the road.
- Run shot 3's left half is filled with a ridge, cedars and houses.
- The no-entry board stands beside the left barriers, and the green wash is dimmer.
- Clearance was measured against the road centre line (segment distance). Front-row houses were at 18.5 and are now
  at 52 out (scale capped at 1.1). Guardrails were at 19.8 on bends and are now 34 out. Everything now measures 24+.
