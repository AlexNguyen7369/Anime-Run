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
