# Track 2 DemonCastle: source references

Source: Solo Leveling (webtoon and anime), the Demon Castle S-rank dungeon (100 floors; Cerberus at the gate, Vulcan on
floor 50, Metus on 75, Baran on 100). The game uses the tweaked names (Solo Levelup, Barran). Reference images are
look-only. They sit in `build/world2/refs/DemonCastle/`, which is gitignored and never ships. Everything in the biome is
modelled in-house from primitives. It has no logos and no text, and its banners carry a plain changed shape.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| The castle: a chained tower | A tall rectangular tower with rows of windows (the floors), bound by huge iron chains, with fire at its foot and smoky sky behind | Wiki page images (webtoon panel and anime ep. 7): https://solo-leveling.fandom.com/wiki/Demon_Castle | `webtoon_castle.ref.jpg`, `anime_castle.ref.jpg` | `ChainTower` (hero): one plain window-gridded slab (900 studs), thick rust-orange chains wrapped across its faces and drooping to anchor blocks, a wall of fire up its lower third; placed so the 6/33/90% run cameras see it on the skyline |
| Inside the floors: ruined burning city | The castle's floors show a destroyed city: high-rises with window grids, pink-purple fire, burning debris floating in the air, a pillar of light on the horizon | https://solo-leveling.fandom.com/wiki/Demon_Castle_Arc (anime image), wiki text "a destroyed version of Seoul ... set on fire" | `anime_castle2.ref.jpg` | `RuinA` (twin window-grid high-rises with a translucent flame curtain), `RuinB`, `Chunk` (irregular ember-lit rock slabs), `Smoke` (cloud slabs), light beam on the `ChainTower` summit |
| Gate and gatekeeper | A three-headed hound with horns guards the entrance in front of a fiery gate with tall pillars | https://solo-leveling.fandom.com/wiki/Cerberus | `cerberus_gate.ref.jpg` | `Gate` (hero, spans the road twice): spired gate towers, pointed arch, open iron doors, fire glow behind the arch; `Hound` (hero, own prop): the three-headed gatekeeper as a statue on a plinth each side of the approach: dark green upright brute, arms forward, pale mane, jaws wide open with rows of fangs and red tongues, curled tan horns on two heads, a pale helm with pointed ears on the left head (generic monster) |
| Top floor: the Demon King | Purple armoured demon with gold plates, horns, blue lightning blade, ringed by curved pale horn-spikes under a dark stormy sky | https://solo-leveling.fandom.com/wiki/Baran | `baran_anime.ref.jpg` | `ChainTower` summit: horn-spike ring round a throne; rider on `Wyvern` |
| The wyvern | Pale grey-white wyvern with swept horns, red eyes and dark wing membranes | https://solo-leveling.fandom.com/wiki/Kaisellin | `kaisel_flight.ref.jpg` | `Wyvern` (circles the tower top with the rider) |
| Castle mood | Black stone, purple-black sky, crimson and lava glow | design brief + all refs above | (all) | `Rampart` (plain merlons, a brazier in front), `Crag`, `Edge` (flagstone strip with ember cracks), sky ramp from purple-black to an ember-orange horizon |

Round 2 (2026-11-23, owner: follow the source 1-1): fire is orange as in the source; the sky keeps a purple-black top
over an ember-orange horizon. The tower is placed up to three times (one copy per runner camera that would otherwise
miss it), because the review cameras are fixed and the source castle must top the skyline in each.

Not matched: characters are not modelled as likenesses; the rider and the hounds are generic shapes.

Round 4 (2026-11-23): `ChainTower` chains now sag in from anchors high in the sky (as `webtoon_castle`, `anime_castle`),
fire tiers climb about 70% of the slab with ash flecks; the ruins' pink fire is tall tapered flame curtains on the
high-rise faces (`anime_castle2`); `Hound` heads sit side by side above the shoulders with gaping jaws, the left one in a
pale pointed-ear helm, the tan mane rising behind them (`cerberus_gate`); `Wyvern` has a long narrow skull with six
horns swept back and red eyes (`kaisel_flight`).

Round 5 (2026-11-23, new builder, shaped live in Blender then ported): `ChainTower` huge chains now sag diagonally in
from anchors far off to the sides (1150 out, 2050 up) into the upper faces, with thinner chains crossing every face
(`webtoon_castle`); the tower fire is continuous translucent flame bands with tongues and wide black ash streaks over the
floor bands, not separate spikes. The ruins' pink fire is soft, wide, low-opacity sheets hugging the front and outer
side faces, with more lit (pale pink) windows (`anime_castle2`). `Hound` heads have jaws thrown open with fang rows on
both jaws, a red maw and tongue, and the pale pointed-ear helm on the viewer's left head (`cerberus_gate`). `Wyvern`
has a diamond-section ridged skull with swept-back and flared horns, full dark membranes in a raised V that read from
the front, and a rider at about 1.3 times the body height: purple armour, gold pauldrons, belt and knee plates, antler
horns, a white flame mane, a tail and a blue blade (a changed design after `baran_anime`, no logos). `Gate` gains
tall dark-red square pillars wrapped in fire on both sides (`cerberus_gate`). The 33% shot's dark slab is the road deck
on the stair climb (shared road, not a biome prop); a lamp now lights it.

Round 6 (2026-11-23): `Hound` heads face the viewer, tipped a little down at the road: a short muzzle with the upper jaw
tipped back 40 degrees and the lower jaw dropped round a round red maw ringed with fangs; the chest and arms are about
twice the mass, the arms flung wide with open clawed hands, and the middle and right heads carry thick curled ram horns
(`cerberus_gate`); the statues stand 84 from the road centre. `ChainTower` fire is translucent bands with tongues only up
the face edges, so the floor ledges and a lit window grid read over the full height (`webtoon_castle`). The ruins' fire
is soft vertical wisp strips with ragged flat tops, and every facade has lit pale pink window rows (`anime_castle2`).
`Wyvern` has a sleek body of tapered eight-sided segments with dorsal and belly plates and near-black membranes
(`kaisel_flight`); the rider's legs sit astride outside the flanks and a large white flame mane streams back and to one
side behind the antlers (`baran_anime`). The sky below the horizon takes the ground colour, so the ground's far edge no
longer shows against the orange band.
