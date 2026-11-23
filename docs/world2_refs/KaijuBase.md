# Track 5 KaijuBase: source references

Source: Kaiju No. 8 (manga chapters 1-3 and the Raid on Tachikawa Base arc; anime season 1, episodes 1-2 and 9-10).
Reference images are look-only. They sit in `build/world2/refs/KaijuBase/`, which is gitignored and never ships.
Everything in the biome is modelled in-house from primitives. It has no text. It does not use the real Defense Force
insignia or the Monster Sweeper logo: the base badge is an invented orange diamond, and the vans carry a plain red band.
It has no gore: the corpse is intact, or stripped to bare bone where the crews have finished.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| Giant kaiju corpse under cleanup | A huge reddish-brown kaiju body lying in the city. Monster Sweeper crews in white hooded suits with visors and green backpacks hang on blue and yellow ropes down its flank. A line of metal stakes with rope lines runs along its back, and teal steel gantries stand overhead | https://kaiju-no-8.fandom.com/wiki/Monster_Sweeper_Inc. | `sweeper_cleaning1.jpg`, `sweeper_cleaning2.jpg` | `KaijuCorpse` (hero, run shots 1 and 2): three-part body, horned head with a tapered snout and a row of teeth on the ground, grey dorsal and flank armour plates, a clawed forelimb, a folded hind leg, rocky ridged plates over a faceted hide, the rear stripped to bleached ribs, a tail; a stake-and-rope line along the back, two teal gantries with 16 blue and yellow ropes hanging onto it, large white-suited workers on the ropes, the back and the ground, skip bins |
| Monster Sweeper crews and vans | White hooded overalls, white vans with roof racks parked near the site, crews waiting on the vans | https://kaiju-no-8.fandom.com/wiki/Monster_Sweeper_Inc. | `sweeper_members.jpg`, `sweeper_hq.jpg` | `SweeperVan`: one-box white van with a sloped nose, raked windscreen, side windows, a plain red band, a raised roof rack with crew sitting on top, workers, cones, a light tower |
| Tachikawa Base HQ | The Third Division's base in Nishi-Tokyo. A wide, symmetric white 8-floor block with a regular window grid, a central entrance tower with a tall glass strip and a portico, slightly taller end pavilions with roof masts, a parking lot of white cars and a tree row | https://kaiju-no-8.fandom.com/wiki/Tachikawa_Base | `tachikawa_base.jpg` | `DefenseHQ` (hero, run shot 3; placed square-on to that camera): one symmetric block with window grids, end pavilions with masts, the central tower with a glass strip and pilasters, an invented badge, portico, two rows of parked cars, a hedge row, and the observation tower beside it |
| Observation tower | Beside the HQ, a slender tower with a ribbed shaft, a ringed observation cab, white radar domes and a lattice antenna mast | https://kaiju-no-8.fandom.com/wiki/Tachikawa_Base | `tachikawa_base.jpg` | part of `DefenseHQ` (on the viewer's left): ribbed shaft, glazed cab with balcony rings, deck with two radar domes, five-stage lattice mast, beacon, base block |
| Anti-kaiju rail cannon | A huge cannon barrel on a rail track, ring coils around its breech, cable bundles, a square muzzle, tanks on both sides | https://kaiju-no-8.fandom.com/wiki/Defense_Force | `railgun.jpg` | `Railgun` (hero, side shot and run shot 4): a 250-stud rail bed with ballast and sleepers, a heavy carriage, a massive barrel at 6 degrees, a 12-ring coil stack at the breech, a riveted square muzzle, 8 tall striped tanks, 24 drooping cable bundles, a support truck |
| Wrecked Tokyo districts and the base perimeter | Residential and office districts wrecked by kaiju: balconied apartment blocks, office towers, rubble, crushed cars. The base has walls, hangars and armoured vehicles | anime episodes 1 and 9 (city and base raid) | `sweeper_members.jpg` (town in the background) | `Apartment` and `Office`: a collapsed corner where the floor plates jut from the break, a slab rests onto the lower roof, and scorch marks show; some are placed leaning. `CityBlock`: a 160-stud street-grid tile with streets, sidewalks, wrecked low-rises, a crater and wrecked cars, laid over the city and the infield. `Smoke`: a smoke column over a scorched base. `Rubble`: varied chunks, crushed and flipped cars, a pole and rebar, randomly turned. `Hangar`: arched roof, door seams, abstract chevrons, an armoured vehicle. `BaseWall`: low, so the runner sees over it. `Pier` |

Not matched: the source's corpse shows cut flesh. The draft shows the corpse intact or as bare bone instead, to keep it
free of gore. The Defense Force and Monster Sweeper emblems are replaced by invented shapes. The real Tachikawa layout,
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
