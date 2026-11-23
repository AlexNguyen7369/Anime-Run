# World 2 Track 3 `RuinedCityZ`: source references

Source: One Punch Man (anime season 1, manga). Look-only references for the Blender draft
`tools/blender/world2/biomes/RuinedCityZ.py`. The images sit in `build/world2/refs/RuinedCityZ/` (gitignored). They
never ship and nothing is traced or copied from them. Every prop is built in-house from primitives. No text and no
official logos or symbols (design doc 5).

| Landmark | Visual facts | Source | Local ref | Prop |
|---|---|---|---|---|
| The hero's apartment block (Z-City ghost town) | Narrow mid-rise, about 8 floors. The street face is a stack of brown brick balconies with AC units on each balcony. The end wall is blank grey concrete, stained, with square patches and bolt points. It has a roof railing, rolled shutters at street level and a low fence with shrubs. | https://onepunchman.fandom.com/wiki/Saitama%27s_Apartment | `Saitamas_Apartment_Anime.ref.jpg`, `Saitamas_apartment_at_night_-_S1E4.ref.jpg` | `SaitamaApt` (hero) |
| Ghost-town cordon | Chain-link fence with barbed wire. A yellow-black striped barrier. A red-and-white warning board (its text is left out here), concrete utility poles and street trees. | https://onepunchman.fandom.com/wiki/Z-City_Ghost_Town | `Z-City_Ghost_Town_Anime_Profile.ref.jpg` | `Barricade`, `UtilityPole`, `Tree` |
| Elevated expressway over the ghost town | A dark, heavy concrete deck on square piers with girders underneath. It runs over the empty streets. | https://onepunchman.fandom.com/wiki/Z-City_Ghost_Town | `Z-City_Ghost_Town_Anime_Profile.ref.jpg` | `Overpass` (crosses the road, broken off at one end) |
| Empty grey high-rises and mid-rises | Grey and beige concrete blocks with window grids, balconies, rooftop water tanks and stair cores. Many windows are smashed. Some blocks are half-collapsed with exposed floors and rebar (monster raids). | https://onepunchman.fandom.com/wiki/Z-City_Ghost_Town | `Saitamas_Apartment_Anime.ref.jpg` (street context) | `MidRise`, `OfficeBroken`, `HighRise`, `Collapsed`, `Rubble` |
| Hero Association HQ on the horizon | A stepped cluster of dark towers, tallest in the middle. It stands on a ribbed, sloped hull over a round base, with highways radiating out on piers. | https://onepunchman.fandom.com/wiki/A-City | `New_Hero_Association_Headquarters_Anime.ref.jpg`, `Hero_Association_HQ.ref.jpg` | `HeroHQ` (hero, horizon; no emblem) |
| Meteor damage (City Z/A) | Impact crater with upturned asphalt plates on the rim, a scorched bowl, buried building stumps and radial cracks. | https://onepunchman.fandom.com/wiki/Z-City | (no image kept; described from the anime episode 2 meteor arc) | `Crater` (hero, infield) |

Not matched 1-1: the hero's real apartment has more balcony units per floor and a separate outside stair. The draft
keeps 3 units per floor and leaves out the stair, so the block stays inside the tri budget. Fubuki-arc details (burn
marks) are left out.
