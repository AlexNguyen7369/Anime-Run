# Track 5 KaijuBase: source references

Source: Kaiju No. 8 (manga chapters 1-3 and the Raid on Tachikawa Base arc; anime season 1, episodes 1-2 and 9-10).
Reference images are look-only. They sit in `build/world2/refs/KaijuBase/`, which is gitignored and never ships.
Everything in the biome is modelled in-house from primitives. It has no text. It does not use the real Defense Force
insignia or the Monster Sweeper logo: the base badge is an invented orange diamond, and the vans carry a plain red band.
It has no gore: the corpse is intact.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| Giant kaiju corpse under cleanup | A huge reddish-brown kaiju body lying in the city. Monster Sweeper crews in white hooded suits with visors and green backpacks hang on blue and yellow ropes down its flank. A line of metal stakes with rope lines runs along its back, and teal steel gantries stand overhead | https://kaiju-no-8.fandom.com/wiki/Monster_Sweeper_Inc. | `sweeper_cleaning1.jpg`, `sweeper_cleaning2.jpg` | `KaijuCorpse` (hero, run shots 1 and 2): three-part body, horned head with a tapered snout and a row of teeth on the ground, grey dorsal and flank armour plates, a clawed forelimb, a folded hind leg, faceted rock crags over the hide, a craggy rock-ridge spine, a continuous tapering tail; a stake-and-rope line along the back, two teal gantries with 16 blue and yellow ropes hanging onto it, large white-suited workers on the ropes, the back and the ground, skip bins |
| Monster Sweeper crews and vans | White hooded overalls, white vans with roof racks parked near the site, crews waiting on the vans | https://kaiju-no-8.fandom.com/wiki/Monster_Sweeper_Inc. | `sweeper_members.jpg`, `sweeper_hq.jpg` | `SweeperVan`: one-box white van with a sloped nose, raked windscreen, side windows, a plain red band, a raised roof rack with crew sitting on top, workers, cones, a light tower |
| Tachikawa Base HQ | The Third Division's base in Nishi-Tokyo. A wide, symmetric white 8-floor block with a regular window grid, a central entrance tower with a tall glass strip and a portico, slightly taller end pavilions with roof masts, a parking lot of white cars and a tree row | https://kaiju-no-8.fandom.com/wiki/Tachikawa_Base | `tachikawa_base.jpg` | `DefenseHQ` (hero, run shot 3; placed square-on to that camera): one symmetric block with window grids, end pavilions with masts, the central tower with a glass strip and pilasters, an invented badge, portico, two rows of parked cars, a hedge row, and the observation tower beside it |
| Observation tower | Beside the HQ, a slender tower with a ribbed shaft, a ringed observation cab, white radar domes and a lattice antenna mast | https://kaiju-no-8.fandom.com/wiki/Tachikawa_Base | `tachikawa_base.jpg` | part of `DefenseHQ` (on the viewer's left): ribbed shaft, glazed cab with balcony rings, deck with two radar domes, five-stage lattice mast, beacon, base block |
| Anti-kaiju rail cannon | A huge cannon barrel on a rail track, ring coils around its breech, cable bundles, a square muzzle, tanks on both sides | https://kaiju-no-8.fandom.com/wiki/Defense_Force | `railgun.jpg` | `Railgun` (hero, side shot and run shot 4): a 250-stud rail bed with ballast and sleepers, a heavy carriage, a massive barrel at 6 degrees, a 12-ring coil stack at the breech, a riveted square muzzle, 8 tall striped tanks, 24 drooping cable bundles, a support truck |
| Wrecked Tokyo districts and the base perimeter | Residential and office districts wrecked by kaiju: balconied apartment blocks, office towers, rubble, crushed cars. The base has walls, hangars and armoured vehicles | anime episodes 1 and 9 (city and base raid) | `sweeper_members.jpg` (town in the background) | `Apartment` and `Office`: a collapsed corner where the floor plates jut from the break, a slab rests onto the lower roof, and scorch marks show; some are placed leaning. `CityBlock`: a 160-stud street-grid tile with streets, sidewalks, wrecked low-rises, a crater and wrecked cars, laid over the city and the infield. `Smoke`: a smoke column over a scorched base. `Rubble`: varied chunks, crushed and flipped cars, a pole and rebar, randomly turned. `Hangar`: arched roof, door seams, abstract chevrons, an armoured vehicle. `BaseWall`: low, so the runner sees over it. `Pier` |

Not matched: the source's corpse shows cut flesh. The draft shows the corpse intact instead, to keep it free of gore. The Defense Force and Monster Sweeper emblems are replaced by invented shapes. The real Tachikawa layout,
including its training grounds and Self-Defense Force camp, is not reproduced. Only the HQ, the tower, the hangars and
the walls stand in for it.
The clouds are sky dressing (the game's Sky), not prop assets.

Round 3 (2026-11-23), judged in the 6 review shots:
- The corpse flank is a tall wall of layered ridge plates with grooves over a pale belly band. The head (horns, open
  toothed jaw) faces the runner. Rappel lines carry large sweepers (hood, round visor, big green pack).
- The rail cannon's barrel is 30 thick at 10 degrees and runs through two rail gantries. It has a 14-ring coil stack
  and 32 drooping cables. The second cannon's muzzle faces run shot 4.
- The HQ has taller end pavilions, strong floor bands and a front row of white cars. Nothing tall stands behind it.
  City tiles have streets on all four edges, random quarter turns and a park corner. The base wall has a grass verge.

Round 4 (2026-11-23): the corpse flank is a cliff about 165 tall, roughly twice the tallest blocks. About ten
sweepers hang on long gantry ropes. The rail cannon has 42 drooping coil cables, ribbed tanks, a rack-tooth rail and
side walkways. The blocks have blown-out wall chunks and rubble heaps. The tower has visible ribs and a second
balcony ring. The hangar chevrons are small and do not glow.

Round 5 (2026-11-23):
- The flank is three tiers of bulging hide masses with 16 big crag plates, dark folds and a pale band low on the side.
- The head has brow ridges, eye sockets and one row of teeth. The stars are gone.
- The sweepers are 4.4x to 6x scale, three of them on the near gantry's ropes.
- The ridge stake line is thin grey stakes with sagging rope.
- The cannon's coils are rings square to the barrel on a sleeve, and its cables hang in 3-segment drooping arcs.
- Clearance was measured against the road centre line. The second cannon had crossed the start straight (0.0) and now
  stands on the left of the last straight, 110 out, with its muzzle to run shot 4. Other fixes: offices at the start
  (3.8 to 7.8) are clear because props now need their offset's worth of clearance from every lap; hangars (12 to 14)
  are now 92 out; rubble (17) is now 50 out; road-side blocks are now 64 out; the second corpse (1.4 at the bend) is
  now at d 2400, 175 out. Everything now measures 24+.

Round 6 (2026-11-23), judged in the close-ups and run shots 1 and 2:
- The spine is a craggy rock ridge of 26 jagged, leaning outcrops of uneven height, as in `sweeper_cleaning2.jpg`,
  in place of the even row of plates. Faceted rock lumps cover the back and the hip, so no smooth dome shows.
- The flank crags are faceted rock plates, not flat tiles.
- The tail is one continuous tapering tail to a point with rock crags on top, in place of a string of balls and a bone tip.
- The corpses had drifted out of run shots 1 and 2. They now stand ahead of each camera on the left, at d 800
  (190 out) and d 2750 (200 out), with the sweeper vans beside them. clearance.py measures both as clear.
- The close-up camera frames the whole prop and its 760-wide ground disc, so the corpse fills only the middle third.

Round 7 (2026-11-23):
- Corpse: the hide is large smooth salmon-red masses that overlap into one cliff. A pale shell runs low on each mass as
  the pale band, mottled with darker spots, with shallow darker patches above it. Short beige crags sit on the top
  ridge only. The horns are shorter and the skull crest is smaller. The flank crags and back lumps are gone.
- Sweepers: an open white parka hood round a skin-tone face, a respirator block with one disc filter, harness straps
  and a belt, and a tall green pack. They have no helmet sphere and no black visor.
- Van: a one-box Hiace-style van, nose to -Z. It has small wheels, a lower body, a raked windscreen over a short
  nose, a grille, headlamps, a blank plate, side and rear windows, sliding-door seams and a long roof rack with crew.
- Rail cannon: the tanks stand either side of the breech coils, five cables per coil ring drape out to both sides,
  and the muzzle has a black square bore.
- Smoke: three tapered plumes that merge, bend downwind and darken toward the base. No stacked balls.
- City: rubble cones at the foot of each damaged block, sheared tops with bent rebar, and more soot on the facades.

Round 8 (2026-11-23), coordinator ruling on the hide (sweeper_cleaning1/2):
- Corpse: a red-brown rocky cliff of hard-faceted masses, taller for its length. Rows of broad angular rock facets and
  ledges cover it, each with a hard dark shadow facet under it, with some cracks. A pale exposed band runs at the
  foot. Angular rock plates sit on the ridge. It has no sphere lumps and no spikes.
- Stake-and-rope lines: A-frame stakes every 9 studs with sagging rope, one line along the back and one along the
  flank.
- Head: a heavy angular cranium with brow crests, eye sockets and rock plates, a lifted upper jaw and the lower jaw
  resting open on the ground with teeth, and short horns.
- Crew: a full white hood with a rim round the face, a dark goggles band, a white respirator with a round side filter,
  harness straps and a tall green pack.
- Rail cannon: eight thick coil discs, each with 16 radial fins, and 84 cables. A third of the cables end on the rail bed.
- Smoke: three columns of faceted puffs that widen, lighten and drift as they rise, dark at the base. They cast no shadow.
- Van: the light tower stands behind the van, clear of the roof crew.

Round 9 (2026-11-23), final coordinator ruling on the corpse (sweeper_cleaning1/2):
- Corpse: a few large, smooth, bulging hide masses that overlap heavily into one continuous red-brown wall. The surface
  detail is thin, dark, angular shadow streaks lying flush on the bulges, like the ink shadows in the refs. A jagged
  rocky ridge runs along the top silhouette only. One wide pale band runs low on the side, with flush mottling. The
  loose angled plates are gone. The flank and ridge helpers now measure the merged surface, so details and rope
  anchors sit on the hide instead of floating.
- Gantry ropes are tied onto the hide, and a large sweeper hangs on each of three ropes per gantry just off the hide.
  The ground crew is at human scale next to the vans; the crew on the back is 1.8x.
- Sweepers: a rounded, loose hood and rim round the face, dark goggles, a white respirator with a round side filter, a
  loose tapered suit with baggy rounded arms and legs, harness straps, and a taller green pack.
- Rail cannon: 84 long cable bundles run from the coil rings out and down both sides in sagging loops, along the
  ground and back up onto the side decks (railgun.jpg). They stay 24+ from the road.
- Van: a taller windscreen raked back along the nose slope, and bigger side windows.

Round 10 (2026-11-23):
- Rail cannon: two ribbed tanks stand on each side of the barrel axis, behind the coil drum. 84 thick black cable
  bundles leave the coil discs and run in long sagging arcs over both side-deck rails to the ground, clear of the tanks
  and the rail bed (railgun.jpg).
- Corpse (the form is settled): large dark-maroon ink shadows in jagged, branching runs on the lower half of each
  bulge (sweeper_cleaning1). The pale band is grey-beige with dense dark speckle and a ragged top edge broken by red
  tongues (sweeper_cleaning2). 16 thin blue, teal and yellow ropes drape from the ridge over the hide to the ground, and
  10 more hang straight from the gantry beams. The stake lines have stout posts every 18 studs and a deep rope sag.
- Crew: a teal hose loops from each sweeper's pack to the hip. On the van, two sweepers sit on the front of the rack
  with their legs over the windscreen, one lies on the rack, and one leans on the van with arms crossed
  (sweeper_members).
- City tiles now keep clear of each corpse's full length, so the tail no longer runs through blocks.

Round 11 (2026-11-23), new builder, shaped live in Blender against `sweeper_cleaning1/2.jpg` and `railgun.jpg`:
- Corpse torso: four large smooth hide masses sunk below the ground, so the flank rises as one steep wall with a few
  gentle bulges. No horizontal tier seam: the separate pale-band shell and the hip bulge are gone.
- The pale band and the ink shadows are painted onto the hide's own faces, so they lie exactly in the surface. The band
  is grey-beige over the lower 38% of the flank, with a ragged top edge, mixed face tones and about 300 dark speckle
  chips lying flat on it. The ink shadows are large maroon runs slanting down with branches, spread over every bulge
  between the band and the upper flank. They end well above the band, so no dark seam forms along it. The upright ink
  plates are gone.
- Ridge: big beige-salmon jagged crags (8-15% of body height) lean along the top silhouette, with broken slabs leaning
  on them. The back stake line runs among them.
- Gantry sweepers face the hide with their boots on its surface, 16-36 studs off the gantry legs. Each rope runs from
  the gantry beam to the sweeper's chest and on down to an anchor on the hide.
- Van: four sweepers sit in a row along the rack at 0.65 scale, looking out to the side, and one lies in front of them
  (sweeper_members). The standing ground worker was dropped to stay in the mid-prop tri budget.
- Rail cannon: 64 thin black cables leave the top of the coil drum, arc up and out over its shoulders on both sides,
  sag over the side-deck handrails and run onto the ground. The side decks now stand outside the drum (38 out), so the
  cables clear the drum, the tanks and the rails. The support truck is on the far side.
- Small and distant sweepers use a coarser hood, box gloves and a lower-segment hood rim (tri budget).

Round 12 (2026-11-23), coordinator ruling on the cables (railgun.jpg), shaped live in Blender:
- Rail cannon: the eight coil discs are big rings (2x the barrel) with a ring of square fins round each rim, and they
  stay open from the front and the top. 24 bundles of 3-4 cables leave the discs' outer rims at the sides, arc out,
  sag over the side-deck handrails and run to the ground. Each cable is a smooth 7-piece curve. The side decks
  stand 46 out, so the cables spread sideways. The cannon now stands 90 out (was 80), and the support truck is on
  the far side.
- The muzzle is a square block with chamfered corners, rivet rows on the face and the outer faces, and a stepped bore:
  an inner step ring 3 behind the face, then the black bore.
- The two rail gantries, which read as lone posts from the side, are replaced by two support pillars with saddles
  under the barrel.
- Stake lines (sweeper_cleaning1): separate upright grey A-frame posts with a cross bar, and a thin dark rope with a
  smooth three-piece sag between the post tops. This replaces the zigzag.
- Corpse limbs: the forelimb bends at an elbow that rests on the ground, and the forearm turns forward along the
  ground. The hind leg bends at the knee. No other corpse change.
- City tiles (sweeper_members, background): a dense low-rise town of gabled houses with red, brown and grey roofs
  fills each tile around two kaiju-broken low-rises, the park and the crater. This adds no new mesh.
- Van: the lying sweeper is stretched out full length along the rack, clear of the seated row.

Round 13 (2026-11-23), shaped live in Blender against railgun.jpg, sweeper_cleaning1/2 and sweeper_members:
- Rail cannon coil stack: eight separate thick discs with 2.8-stud air gaps and smooth rims. They step up from radius
  26 at the back to 34 at the front (muzzle) disc. Each front face carries 24 thin radial blades from the hub out.
  The rim teeth are gone.
- Cables: 20 loose bunches of 8 thin cables (160 in all, about half the old thickness) spill off the discs' outer rims
  on both sides, sag over both side-deck handrails and run onto the ground. Near-side cables leave the rim at or below
  the axis, so the side view keeps the upper discs open. Far-side cables leave higher on the rim and arc out past the
  stack's far edge, so the three-quarter view shows them.
- Corpse hide: smooth-shaded, with the pale band as one flat grey-beige area (no per-face tones). The painted ink
  triangles are gone. The ink shadows are long, near-black maroon flame-shaped streaks, slanting mostly down-left.
  Each streak is a chain of thin flat plates lying in the hide's tangent plane just off the surface, wide at the top
  and tapering to a point.
- Ridge rocks are hide red-brown. Only their upward-facing faces are light.
- The first corpse is turned 40 degrees about a point behind its head, with the tail swung away from the road. Run
  shots 1 and 4 now see its flank, ridge and stake line, and it stays clear of the road.
- Van roof crew: four off-duty sweepers sit slouched with their knees up and forearms on their knees, hoods down,
  without packs. The lying one has no pack, and his face sits in the top of his hood (it was floating above the head).

Round 14 (2026-11-23), shaped live in Blender against railgun.jpg, sweeper_cleaning1/2 and sweeper_members:
- Rail cannon cables: 16 bundles of 3-5 cables, on both sides. Each cable leaves a disc rim at mid-height, arcs out
  over the side-deck handrail, then runs back along the rail in long, low, sagging loops between the post tops. It ends
  on the deck at one of two junction boxes at the back of each deck. Each cable has 9-11 pieces, and nothing stands up
  from the ground. From the side they read as drooping arcs; from the muzzle they spill sideways onto both decks.
- Ink shadows: pointed flame tongues, broad at the base and pointed at the top, slanted, in groups of 2-3 with uneven
  tips. They are dark red-brown, not black, and lie just off the hide. There are no closed or curved shapes, so
  nothing reads as lettering.
- Ridge crags: pale tan, about 2x larger, of very uneven height and leaning, against the sky. Their top faces are a
  lighter tan. This supersedes round 13's red-brown crags.
- Pale band edge: torn steps of mixed width and height (band-coloured flat plates over the painted band's edge), each
  with a thin dark shadow lip under the hide.
- The tail-side gantry moved to x 140, clear of the folded hind leg.
- Van: the four roof sitters each have their own pose (knees up; legs out leaning back on the hands; one knee up;
  cross-legged and hunched) and their own turn. Every other van along the road is mirrored, and the vans' yaw varies
  more. The lying sweeper lies flat on his front along the rack, head forward on his folded arms at the front rail.

Round 15 (2026-11-23), new builder, shaped live in Blender (scene W2_T5) against sweeper_cleaning1/2, railgun.jpg and
sweeper_members, after the owner's 6.5/10 review:
- Hide about 20% darker (deep brick red-brown, 86402E), and the ink shadows near-black red-brown. Flame-tongue groups
  are bigger (56-104 tall) and denser: 7 groups of 3-4 per bulge, about 40% of the flank.
- Pale band edge: the rectangular steps are gone. Pointed hide-red tongues of mixed width (7-26) and depth dip down into
  the band, some with a dark shadow sliver, and band-coloured shards point up between them. Speckle chips are 2x larger
  (3-7) and denser (300 tries), so they read from run shot 02.
- Ridge crags: faceted 3-sided crags with sloped, truncated tops and wedge outcrops, overlapping in runs that lean the
  same way, bases sunk into the hide: one continuous saw-tooth silhouette, still pale tan.
- Rail cannon: 32 bundles of 3-5 cables at about 60% of the old thickness (twice the count), half of them leaving the
  disc rims high up. Cables are 3-sided (8 tris a piece) to stay in budget. The muzzle keeps small rivets on its face
  edges only; its outer faces carry plain plate seams.
- Van: Hiace front with a short sloped nose, a windscreen raked back 43 degrees whose top sits below the roof, thick
  A-pillars and two wipers. Roof sitters moved back onto the rack (the front sitter's limbs no longer pass through it);
  each has his hood bunched behind the neck and his own hair: black spiky, brown, orange spiky, grey beanie.
