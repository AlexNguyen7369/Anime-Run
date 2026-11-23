# Track 10 HellGate: source references

Source: Chainsaw Man manga, the Hell arc (chapters 63-65: "Trip to Hell", "Welcome to Hell"). The game uses the
tweaked name Saw Man. Reference images are look-only. They sit in `build/world2/refs/HellGate/`, which is gitignored
and never ships. Everything in the biome is modelled in-house from primitives. It has no text and no symbols. The
astronauts carry no mission patch. The figures are whole and non-gory: the source's split bodies and blood are left
out for a Roblox audience. The Darkness Devil itself is not modelled (it is a character). Its presence is shown through
its setting: the darkness, the floating arms and the kneeling astronauts.

| Landmark | Visual facts from the source | Source | Local ref | Prop |
|---|---|---|---|---|
| The plain of Hell | A wide grassy, flowery plain with low hills; the brief asks for a red-orange sky | chapter 63 summaries: https://daddyjim.ai/chainsaw-man/manga-chapter/Chapter-63 | `astronauts_welcome.jpg` (grass tufts on the plain) | ground (olive grass), `Grass` (blade clumps with pale flowers), `Hill` (flattened mounds, also spread out to the horizon). The ground and far hills fade into the orange horizon colour, so the plain has no visible edge. Sky: orange at the horizon to deep crimson overhead |
| Doors everywhere | The sky is covered with countless identical doors in parallel rows; one door opens and the darkness spills out. The brief also asks for rows of free-standing doors | chapter 63/64 summaries; chapter 214 recap: https://www.soapcentral.com/anime/chainsaw-man-chapter-214-ending-explained-did-door-hell-appear-denji-death-devil | (none, text sources) | `SkyDoor` (single upright doors on an even jittered grid over the track, all facing one way, 320-1100 studs up); `DoorClosed`, `DoorOpen` (6-panel doors with frame, architrave, sill, knob, plate and hinges, black beyond when open) in three straight rows each side |
| The giant pale hands | Huge pale human arms and hands around the Darkness Devil; an enormous hand also crushes the building in chapter 63 | chapter 63 summaries (as above); epicstream (below) | `darkness_devil.jpg` | `HandOpen`, `HandGrasp` (hero-size): tapered forearm flowing through a rounded wrist into a tapered palm, five fingers of natural length with one gentle curl per joint and nails, and a thumb on the palm base |
| The darkness and its arms | Pitch-black space full of floating pale severed arms, bent at the elbow, with open hands | https://epicstream.com/article/chainsaw-man-darkness-devil-astronauts-explained | `darkness_devil.jpg` | `Void` (black ground discs, sparse at the edge of the darkness and thickening toward the finish), `Haze` (translucent black haze mounds off the road), `ArmReach` (pale arms reaching up out of the black ground and haze with open hands) |
| The praying astronauts | Two rows of astronauts kneeling in prayer and facing each other across an aisle, with the darkness at the far end; white suits, round helmets with dark visors and side lamps, backpacks, gloved hands pressed together before the visor | https://www.themarysue.com/chainsaw-man-astronaut-panel-explained/ ; epicstream (as above) | `astronauts_welcome.jpg`, `astronauts_row.jpg` | `Astronaut` (kneeling, praying, no patch), two rows 30 studs either side of the road, one every 12 studs, over the last stretch before the finish |
| The door the darkness came through | The single door that swings open in the sky before the darkness drops out | chapter 64 summaries | (none) | `DarkGate` (hero landmark): giant panel door frame over the road (lintel 110 studs up), slab swung 140 degrees open and away from the runner, darkness pooled beyond |

Not matched: the source is a black-and-white manga, so the colours (the red-orange sky, olive grass and wood doors)
follow the brief and the colour covers rather than any panel. The astronauts form two rows across an aisle, as in the
manga panel, not a circle. The brief's "circle" does not match the panel. The source's gore (split bodies, intestines)
is left out on purpose. The Darkness Devil figure is not modelled.

## Round note, 2026-11-23 (review FAIL 4/10, owner asked for closer 1-1 and more detail)

Props now (12): `DoorClosed`, `DoorOpen`, `SkyDoor`, `Hand`, `ArmA`, `ArmB`, `Astronaut`, `DarkGate`, `Abyss`, `Grass`,
`Hill`, `Void`. `HandGrasp` and the translucent `Haze` are gone (the haze caused ghosting over the hills).

- The darkness (`Abyss`, hero, matte black, no specular): a curved back wall 900 studs high behind the gate, side walls
  640 studs out along the last 1000 studs that swell up out of the plain from 1750 studs out, a roof over the last
  1000 studs, and black ground beyond the threshold. The aisle now runs into a pitch-black wall and sky, as in
  `astronauts_welcome.jpg`. From the overview it is a large black region. It casts no shadow, so the plain inside stays
  lit. `Void` discs pool on the ground over the last 1000 studs, sparse at first and closing in toward the gate.
- Floating arms (`ArmA`, `ArmB`), as in `darkness_devil.jpg`: long thin arms with a rounded shoulder end, bent at the
  elbow (70 and 115 degrees), and slender hands. Each hand has four separated three-segment fingers that curl and
  spread, plus a three-segment thumb. There are no cuffs. They float 35-65 studs up, 85-160 studs off the aisle, and
  more float deeper in the dark. They hang at random yaw, pitch and roll.
- Hero `Hand`: the same slender hand at hero size with a short forearm out of a mound. Hands beside the road are about
  85 studs tall at 180 studs out, so the whole hand stays in frame. Colossal hands stand 900+ studs out.
- `Astronaut`: the visor is centred and rimmed. The palms are pressed together upright before the visor. Lamp boxes
  with three lenses sit on both sides of the helmet, as in `astronauts_row.jpg`. The suit is white with a faint
  self-light, and the backpack is large. Each figure is turned 40 degrees from the road toward the gate.
- `DarkGate`: raised panels and knobs on both faces of the slab, three hinges, and pilaster capitals and fluting on the
  posts. The Abyss back wall fills the view through the opening. Nothing stands in the opening, which keeps the road
  clear.
- Sky doors: strict rows parallel to the road, a row every 250 studs along it. Three tiers (300, 470 and 680 studs up;
  4, 8 and 10 doors) make the sky denser higher up. Every door is face-on to the road's heading at that point. They
  cast no shadow on the plain.
- Plain: the ground is pale and dotted with dark grass-clump patches (`Grass`). The door rows on the ground are straight
  and square to the road, with no scattered field doors. The sun is warm white and lights the finale from the runner's
  side.

INSTANCES 8,769 (cap 8,798). Hero tris: Hand 2,592, DarkGate 516, Abyss 480. Mid tris: ArmA and ArmB 1,252 each,
Astronaut 1,100.
