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

INSTANCES 8,769 (cap 8,798). Hero tris (previous round): Hand 2,592, DarkGate 516, Abyss 480. Mid tris: ArmA and ArmB 1,252 each,
Astronaut 1,100.

### Round note (2026-11-23): model close-ups
`MODEL_SHOTS` = Astronaut, Hand, ArmA, DarkGate, SkyDoor, DoorClosed (`m_<Name>_front.jpg` / `m_<Name>_34.jpg`).
- `Astronaut` (rebuilt to match `astronauts_row.jpg`): big round helmet with a thick rim round a glossy dark visor
  with a white highlight. Two big mitten gloves press palm to palm. The four fingers are held together and point up,
  with gap lines, a tucked thumb and ribbed gauntlet rings, and they cover the lower visor. Each helmet side has a
  narrow lamp box with three lenses. The suit is puffy and white, with ribbed knee and elbow bands and blank shoulder
  pockets (no emblem). It also has a chest box with hoses, a strapped backpack and boots with soles. The white
  self-light is lowered so the shading reads. 2,988 tris.
- `Hand`: one tapering forearm with a low muscle swell, and a wrist as wide as the forearm, so no joint bands show.
  The palm has a soft pad, a knuckle ridge on the back and a thumb muscle pad. The metacarpal ends no longer poke out.
  The finger curl now grows from index to little finger (0.55 to 1.35). It has a faint self-light so the skin stays
  pale.
- Joint balls stay the same size as the limb's tapered end. A wider ball was tried, but at full size it read as a
  ring on every finger.
- Doors: the `SkyDoor` lintel now sits on the slab (it had a sky gap), and the knobs on `SkyDoor`, `DoorClosed` and
  `DoorOpen` are round instead of cubes.

INSTANCES 8,769 (cap 8,798). Tris: Hand 3,500, Astronaut 2,988, ArmA and ArmB 1,252 each, DarkGate 516, Abyss 480,
DoorOpen 436, DoorClosed 424, Hill 320, SkyDoor 304, Grass 250, Void 92. Clearance: TRACK 10 CLEAR 4194/4194.

### Round note (2026-11-23): review 6.5/10, fixes
- `Abyss` is now one huge matte-black ellipsoid dome beyond the finish, with no walls or roof. It is a 1,280-tri
  sphere, 1.4 times wider across the road than along it and 1.25 tall. The build sizes it to the largest radius that
  still clears every road stretch by 50 studs (2,550 on this loop). From the approach (03, 04) it is an edgeless black
  field rising over a bright strip of plain. From the aisle (06, 07) it fills the whole view past the gate. The
  overview (00) shows it as one black oval. No sky door hangs within 700 studs of the dome edge, so none renders in
  front of the black.
- `DarkGate`: the posts now sink only 4 studs into the ground, so the slab reaches the sill in the close-up. The knob
  is a round ball on a backplate.
- Astronaut rows: they start 650 studs before the finish (the 06 camera no longer crops the nearest figure) and stand
  34 studs out. Each kneels on a low dark grass mound, which works as its shadow patch and lifts the whole figure above
  the edge wall. They face the aisle, turned 15 degrees back toward the runner, so the visor and praying hands read from
  the runner's camera. This is the reviewer's call; the source rows face down the aisle. The self-light is 0.15 (was
  0.5). The visor rim is thicker, and the side lamp is a small round pod.
- Plain: each `Grass` patch has 32 clumps (was 7) in an even sunflower fill and is 2.4 to 3.2 times larger. There are
  rows at 56, 96 and 140 studs each side, every 150 studs, all the way to the finish.
- Skin: `PALE` is a near-white cool tone (F6F6FA), with a 0.3 self-light on the hands and arms.
- `Hand`: the wrist oval is widest exactly where the forearm ends, so no ledge or seam ring shows. The metacarpals are
  sunk inside a taller palm pad, and the back knuckle ridge is narrower, so no bumps stick out at the base of the
  fingers.

### Round note (2026-11-23): round 3, hero models
- `Astronaut` (coordinator ruling, vs `astronauts_row.jpg`):
  - Helmet: a round bubble helmet with a medium white rim, and a glossy black visor that fills about 75% of the face
    with a highlight at top-left. The boxed side lamps keep their 3 lights.
  - Pose: kneeling with the weight back. The thighs slant about 40 degrees, and the hips and upper body sit back over
    the heels.
  - Gloves: wide mitten gloves pressed palm to palm, with blunt rounded tips and three finger-gap grooves on the back.
    Each has a flared gauntlet cuff and a dark wrist ring.
  - Base: the mound is now a flat dark shadow patch.
  - Colour: suit materials are cool white (F4F7FC) with a 0.35 cool self-light, and the shadowless fill sun is cool
    white at 2.0. Some orange still shows from the sky's ambient light.
- Arms: long and straight, or bent only 12 or 42 degrees. Upper arm 17, forearm 15. They hang near vertical, hand
  down, within plus or minus 14 degrees (`darkness_devil.jpg`), with no random tumbling. Self-light is 0.2. Up to 100
  more hang over the open plain, 90-200 studs off the road (05).
- `Hand`: fingers taper by 0.8 per segment and curl more (28). A round root ball and a webbing pad smooth each finger
  base into the palm. An outer heel pad cups the palm, and the knuckles sit closer together.
- `DarkGate`: it stands at the road's end at x2 scale (220 studs tall, posts 70 off the line), front toward the runner.
  A black void slab 52 studs past the road's end fills the opening, and the door swings away from the runner.
- Darkness base: the ground and hill materials fade to black around the dome (smoothstep, from 1.05R to 1.8R from its
  centre), so the dark rises out of a darkening plain. It reads clearly from the overview and the aisle (06, 07). From
  the low approach angle in 04 a thin pale strip still shows under the dome.
- `SkyDoor`: a sill under the slab.

### Round note (2026-11-23): round 4 (coordinator rulings)
- Arms (`darkness_devil.jpg`): `ArmA` hangs straight (6 degree bend). `ArmB` bends 85 degrees at a clear elbow knob.
  Both are about 1.5 times thicker (upper arm r 1.95, forearm r 1.6) with a rounded shoulder end. The hand is 1.8
  times larger, about a third of the arm's reach.
- Arms over the darkness: they hang on an even jittered grid, one row every 120 studs along the last stretch and six
  lateral columns (140, 270 and 400 studs each side, alternate rows staggered by 55). They sit 95-230 studs up at
  scale 1.9-2.3, so they are fewer, larger and an arm-length apart. No arm hangs within 15 studs of a giant `Hand`'s
  bounds, which fixes the arm through the hand in 02.
- Astronauts: they face side-on down the aisle, turned 45 degrees from the road toward the gate, so the visor and
  backpack both read from the runner camera. The joined mittens are now about a third of the visor wide, with
  fingertips at visor mid-height, so the visor and its highlight stay open on both sides and above.
- Aisle ground: the black ground pools (`Void` prop) are removed. The plain stays pale with a dark shadow patch under
  each astronaut. The ground and hills fade to black only from just past the last astronaut to the dome edge.
- `Hand`: a slender flat palm (no bulging pads). The metacarpals are dropped on the ground hand so nothing pokes
  through the palm. There is a low thumb muscle and closer-set finger roots.
- `DarkGate`: the void is a black block inside the frame depth, not a free-standing panel. The gate stands 26 studs
  past the road's end, so the void is 28+ studs off the line. The door swings 115 degrees toward the runner, off to
  the side, so it reads from the aisle and from the side.

### Round note (2026-11-23): round 5
- Pink glow, root cause: the warm sky light tinted the white materials and the self-light bloomed. Suits, gloves and
  the pale hands and arms now use a cool bone-white base (E8EEF8). On top of that, `bone_white()` mixes a flat
  neutral-white tone (55%) with the lit material, staying below the bloom threshold. They read flat bone-white in 06
  and 07 with no salmon halo. In Roblox this is simply a near-white Color with low Reflectance.
- Astronaut (new ruling): each figure faces the road square on, so the runner's oblique view gets a 3/4 front with
  the visor, the joined hands and one side of the backpack.
  - Visor: about 1.3 times larger and deeper, about 80% of the helmet front, inside a thin rim, with the highlight
    top-left.
  - Lamp boxes: smaller than the visor, each with three dark lens dots.
  - Mittens: about 1.6 times wider and flatter, with finger grooves on the front and flared cuffs. They still cover
    only the lower-middle of the visor.
  - Shadow patch: longer (16 studs back) and darker.
- `ArmA` / `ArmB`: the palm core cylinder (the box collar) and the metacarpal caps (the grey square) are gone. One
  flat palm pad now follows the hand's heading. The fingers are thicker, and the hand is 2.25 times larger, about a
  quarter of the arm.
- `Hand`: the thumb root sits up on the side of the palm. Every joint ball is 2.5% wider than its segment end, which
  hides the cap rims (no seam rings) without a bulge.
- Arms: each new arm must sit a reach plus a hand length (50 x scale) from every placed arm, unless they hang more
  than 60 x scale apart in height, so no arm passes through another. They also keep 15 studs clear of giant hands.
- Hills: no hill stands within 1.4R + 900 of the dome centre, so no sunlit mound sits in front of the black.
