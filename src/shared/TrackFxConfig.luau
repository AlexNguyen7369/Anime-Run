--!nonstrict
-- World 2 track effects and motion: DRAFT, owner approval pending (owner 2026-11-26: "Begin drafting vfx for dynamic
-- smoke on tracks and vfx for moving dragons and dyanmic movement for some track assets ... i iwll approve the vfx and
-- motions after it is fully finished"). docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)".
-- Client only (Client/TrackFx, BIOME_ENVIRONMENT_SPEC 5): the server never reads this. Every number is **proposed**.
-- Off: LIVE stays false until the owner approves the effects; World 1 never runs them (Enabled).
-- Anchors: a named placed prop (Prop = the draft prop key; Offset = a point of its box, -1..1 per axis) or a
-- track-local spot (At = fraction of the track length on its centre line, Side +1 right / -1 left, Lateral studs from
-- the centre line, Height studs above it). Never a world position: the World 2 tracks are being re-laid.
local v, hex = Vector3.new, Color3.fromHex

local TrackFxConfig = {}

TrackFxConfig.LIVE = false -- owner approval pending; nothing runs while false

-- Budget (all proposed). Only the track the camera is in (BiomeEnvironment.ZoneAt) runs; the rest are torn down.
TrackFxConfig.Budget = {
	MaxEmittersPerTrack = 14, -- particle emitters alive on the track at once
	MaxParticlesPerTrack = 400, -- steady-state particles on the track: sum of Rate x mean Lifetime of the live emitters
	MaxRate = 10, -- particles per second per emitter (BIOME_ENVIRONMENT_SPEC 5.2 allows 40; landmark emitters use 8)
	CullDistance = 600, -- studs from the camera past which an emitter is off (a preset's Cull overrides it)
	MaxCull = 1400, -- no preset culls further
	MaxDragonsPerTrack = 2,
	DragonCull = 3000, -- studs from the camera past which a dragon is hidden and not updated
	MinDragonClearance = 150, -- studs from any point of the dragon's path to its own track's centre line (3D)
	MinLoopRadius = 120, -- studs: a dragon whose loop would have to shrink below this to stay over its own ground is not built
	OwnMargin = 20, -- studs: every point of a dragon's loop is that much nearer its own centre line than any other track's
	RoadClear = 24, -- studs: an emitter's spread stays this far (horizontal) from every centre line (the props rule)
	MinSpread = 0.5, -- a spread too near a road narrows to this share of its width before the emitter moves away
	EelOverlap = 1.6, -- neighbouring eel segments' mean length over the distance between their centres (wave counted)
	MaxMovingProps = 40, -- swaying or bobbing props at once per track, nearest the camera
	MotionDistance = 350, -- studs; farther props stay still at their placed CFrame
	MaxFlickerLights = 24,
	FlickerDistance = 300,
	MotionHz = 30, -- prop motion and flicker updates per second (dragons update every frame)
	RescanSeconds = 1, -- how often the nearest-first picks are redone
}

-- Asset ledger (BIOME_ENVIRONMENT_SPEC 4.4). Lane B: in-house (Blender meshes, numpy textures). Assets approved by the lead
-- on the owner's 2026-11-26 word ("You can go ahead and approve the assets that you draft up"), IP review OK; uploaded
-- 2026-11-26 under the owner's account (tools/blender/world2/upload_track_fx.py, assets/world2_draft/track_fx/assets.json).
-- The effects stay off (LIVE). An effect whose asset has no Id is not built (no fallback).
TrackFxConfig.Assets = {
	TrackFx_SmokePuff = {
		Kind = "Texture",
		Lane = "B",
		Id = "rbxassetid://131238123745137", -- image of Decal 97289512542692 (upload_track_fx.py; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Size = "1024 x 1024, 4 x 4 flipbook",
		Prompt = "in-house numpy drawing: lumpy cel-shaded smoke billow, lit top and shadow side, holes tear it apart",
		File = "assets/world2_draft/track_fx/textures/TrackFx_SmokePuff.flipbook.png",
	},
	TrackFx_Wisp = {
		Kind = "Texture",
		Lane = "B",
		Id = "rbxassetid://121171857790986", -- image of Decal 109316241038637 (upload_track_fx.py; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Size = "1024 x 1024, 4 x 4 flipbook",
		Prompt = "in-house numpy drawing: thin curling smoke strand that draws on and frays",
		File = "assets/world2_draft/track_fx/textures/TrackFx_Wisp.flipbook.png",
	},
	TrackFx_Haze = {
		Kind = "Texture",
		Lane = "B",
		Id = "rbxassetid://133212472173493", -- image of Decal 134622627756910 (upload_track_fx.py; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Size = "512 x 512",
		Prompt = "in-house numpy drawing: wide low soft bank of ground mist",
		File = "assets/world2_draft/track_fx/textures/TrackFx_Haze.png",
	},
	TrackFx_Ember = {
		Kind = "Texture",
		Lane = "B",
		Id = "rbxassetid://130564448358590", -- image of Decal 118705205041971 (upload_track_fx.py; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Size = "128 x 128",
		Prompt = "in-house numpy drawing: hot round spark with a soft halo",
		File = "assets/world2_draft/track_fx/textures/TrackFx_Ember.png",
	},
	TrackFx_DrakeBody = {
		Kind = "Mesh",
		Lane = "B",
		Id = "rbxassetid://99358143355177", -- MeshId inside Model 128203234362835 (upload_track_fx.py, tools/lune/trackfx_meshids; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Tris = 196,
		Prompt = "in-house Blender low poly faceted generic drake: wedge head with two swept horns, long neck, "
			.. "barrel body, long tail ending in a plain spade, no legs, two-tone grey vertex colours",
		File = "assets/world2_draft/track_fx/meshes/TrackFx_DrakeBody.glb",
	},
	TrackFx_DrakeWing = {
		Kind = "Mesh",
		Lane = "B",
		Id = "rbxassetid://70831317809815", -- MeshId inside Model 97155744574570 (upload_track_fx.py, tools/lune/trackfx_meshids; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Tris = 60,
		Prompt = "in-house Blender low poly bat-like membrane wing with three finger spars, flat and double sided, "
			.. "hinge at its root; the right wing is the same mesh turned 180 degrees about the body's long axis",
		File = "assets/world2_draft/track_fx/meshes/TrackFx_DrakeWing.glb",
	},
	TrackFx_EelHead = {
		Kind = "Mesh",
		Lane = "B",
		Id = "rbxassetid://81336925420911", -- MeshId inside Model 129183633171315 (upload_track_fx.py, tools/lune/trackfx_meshids; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Tris = 92,
		Prompt = "in-house Blender low poly spirit eel head: blunt rounded snout, small eyes, a fin crest, no horns, "
			.. "no whiskers, no limbs",
		File = "assets/world2_draft/track_fx/meshes/TrackFx_EelHead.glb",
	},
	TrackFx_EelSegment = {
		Kind = "Mesh",
		Lane = "B",
		Id = "rbxassetid://125251547523736", -- MeshId inside Model 140101377134796 (upload_track_fx.py, tools/lune/trackfx_meshids; moderation Approved)
		Reviewed = "2026-11-26 rules auditor",
		Tris = 52,
		Prompt = "in-house Blender low poly eel body segment: six sided tube with a dorsal fin",
		File = "assets/world2_draft/track_fx/meshes/TrackFx_EelSegment.glb",
	},
}

-- Sizes and numbers of the meshes in game (studs; proposed)
TrackFxConfig.Drake = {
	-- the Blender meshes at x1.6, so a drake 300+ studs up still reads (mesh 11.1 x 13.7 x 71; wing 44 x 1.75 x 26)
	BodySize = v(17.7, 21.9, 113.6), -- MeshPart Size of TrackFx_DrakeBody (X wide, Y tall, Z long; -Z is the head)
	WingSize = v(70.4, 2.8, 41.6), -- one wing: X span from the hinge, Z chord
	WingHinge = v(8, 4.8, -9.6), -- body-local hinge of the left wing (the right one mirrors X)
	FlapPeriod = 1.8, -- seconds per wing beat
	FlapAngle = 32, -- degrees up and down from level
	GlideShare = 0.35, -- part of each lap spent gliding with wings level (no flap)
	Bank = 18, -- degrees of roll into the turn
	Bob = 4, -- studs the body rises on each down stroke
}
TrackFxConfig.Eel = {
	-- the Blender meshes at x2.5 (head 6.3 x 9 x 15, segment 5.9 x 9 x 11)
	HeadSize = v(15.7, 22.6, 37.5),
	-- the first segment; each next one is smaller (to 55% at the tail). 40 long (the mesh stretched along the path, same
	-- tris; was 27.5) so neighbours overlap by Budget.EelOverlap and no gap shows (WORLD2_SPEC "Track effects", 2026-11-26)
	SegmentSize = v(14.8, 22.5, 40),
	Segments = 14,
	Spacing = 21, -- studs between segment centres along the path
	Wave = 10, -- studs of side-to-side undulation at the tail (was 15: the tail's segments parted at its swing)
	WavePeriod = 3.2,
	WaveLength = 9, -- segments per full wave
	Transparency = 0.35, -- a ghostly eel
}

-- Particle presets. Rate is per second, Lifetime / Speed are { min, max }, Size and Transparency are
-- { { time 0..1, value } } keys, Area is the emitter part's box (studs), Cull overrides Budget.CullDistance.
TrackFxConfig.Presets = {
	SmokeColumn = {
		Texture = "TrackFx_SmokePuff",
		Flipbook = true,
		Rate = 3,
		Lifetime = { 8, 11 },
		Speed = { 7, 11 },
		Acceleration = v(1.2, 1.5, 0), -- a little drift downwind
		SpreadAngle = 12,
		Drag = 0.15,
		Size = { { 0, 18 }, { 0.5, 38 }, { 1, 52 } },
		Transparency = { { 0, 1 }, { 0.08, 0.25 }, { 0.75, 0.45 }, { 1, 1 } },
		RotSpeed = { -10, 10 },
		LightInfluence = 0.85,
		LightEmission = 0,
		Area = v(40, 6, 40),
		Cull = 1200,
	},
	RubbleSmoke = {
		Texture = "TrackFx_SmokePuff",
		Flipbook = true,
		Rate = 2,
		Lifetime = { 6, 8 },
		Speed = { 4, 7 },
		Acceleration = v(0.8, 0.8, 0),
		SpreadAngle = 18,
		Drag = 0.2,
		Size = { { 0, 6 }, { 0.6, 16 }, { 1, 22 } },
		Transparency = { { 0, 1 }, { 0.1, 0.4 }, { 0.7, 0.6 }, { 1, 1 } },
		RotSpeed = { -15, 15 },
		LightInfluence = 0.9,
		LightEmission = 0,
		Area = v(14, 2, 14),
		Cull = 700,
	},
	Chimney = {
		Texture = "TrackFx_Wisp",
		Flipbook = true,
		Rate = 2,
		Lifetime = { 4, 5.5 },
		Speed = { 3, 5 },
		Acceleration = v(1.5, 0.6, 0),
		SpreadAngle = 8,
		Drag = 0.3,
		Size = { { 0, 5 }, { 0.5, 12 }, { 1, 16 } },
		Transparency = { { 0, 1 }, { 0.1, 0.3 }, { 0.8, 0.55 }, { 1, 1 } },
		RotSpeed = { -6, 6 },
		LightInfluence = 0.8,
		LightEmission = 0,
		Area = v(2, 1, 2),
		Cull = 500,
	},
	Steam = {
		Texture = "TrackFx_Wisp",
		Flipbook = true,
		Rate = 4,
		Lifetime = { 2.5, 3.5 },
		Speed = { 5, 8 },
		Acceleration = v(0.5, 1, 0),
		SpreadAngle = 14,
		Drag = 0.4,
		Size = { { 0, 3 }, { 0.6, 8 }, { 1, 11 } },
		Transparency = { { 0, 1 }, { 0.1, 0.35 }, { 0.7, 0.6 }, { 1, 1 } },
		RotSpeed = { -20, 20 },
		LightInfluence = 0.6,
		LightEmission = 0.1,
		Area = v(6, 1, 6),
		Cull = 450,
	},
	GroundHaze = {
		Texture = "TrackFx_Haze",
		Flipbook = false,
		Rate = 1.2, -- was 0.6: reads as light haze from the run camera (WORLD2_SPEC "Track effects", 2026-11-27)
		Lifetime = { 14, 18 },
		Speed = { 0.6, 1.4 },
		Acceleration = v(0.3, 0, 0),
		SpreadAngle = 80,
		Drag = 0,
		Size = { { 0, 30 }, { 1, 46 } },
		Squash = { { 0, -0.55 }, { 1, -0.55 } }, -- wide and low
		Transparency = { { 0, 1 }, { 0.25, 0.55 }, { 0.75, 0.55 }, { 1, 1 } }, -- was 0.78
		RotSpeed = { 0, 0 },
		LightInfluence = 1,
		LightEmission = 0,
		Area = v(70, 2, 70),
		Cull = 700,
	},
	Embers = {
		Texture = "TrackFx_Ember",
		Flipbook = false,
		Rate = 6,
		Lifetime = { 2.5, 4 },
		Speed = { 6, 12 },
		Acceleration = v(1, 2, 0),
		SpreadAngle = 25,
		Drag = 0.5,
		Size = { { 0, 0.9 }, { 1, 0.2 } },
		Transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		RotSpeed = { 0, 0 },
		LightInfluence = 0,
		LightEmission = 1,
		Area = v(20, 4, 20),
		Cull = 500,
	},
	Motes = {
		Texture = "TrackFx_Ember",
		Flipbook = false,
		Rate = 4,
		Lifetime = { 6, 9 },
		Speed = { 0.5, 1.5 },
		Acceleration = v(0, 0.2, 0),
		SpreadAngle = 180,
		Drag = 0.6,
		Size = { { 0, 0.6 }, { 0.5, 1.3 }, { 1, 0.4 } },
		Transparency = { { 0, 1 }, { 0.2, 0.2 }, { 0.8, 0.3 }, { 1, 1 } },
		RotSpeed = { 0, 0 },
		LightInfluence = 0,
		LightEmission = 1,
		Area = v(40, 16, 40),
		Cull = 350,
	},
}

-- Per World 2 biome key (Shared/Tracks/World2 spec.Biome). Smoke rows: { Preset, Prop or At/Side/Lateral/Height,
-- Offset (a rising row at the prop's top or outside its box), Surface (true: starts on a surface inside it by design), Fill = part of the prop's box the emitter covers (optional, TrackFxPlan.Area), Transparency = keys replacing
-- the preset's (optional, TrackFxPlan.Transparency), Color = { bottom, top } colour
-- keys, Max = most anchors of the row alive at once }. Dragons: { Kind
-- "Drake"|"Eel", Color, At, Side, Lateral, Radius, Altitude, Period (s per lap), Phase }. Motion: { Prop, Kind
-- "Sway"|"Bob"|"Spin", numbers }; Flicker: lamps the draft placed (Lamp_<i>, BiomeDressing.PLACED_LIGHTS).
TrackFxConfig.Tracks = {
	-- Track 1, day plains: thin chimney smoke on the village houses, morning haze in the pine woods, pines sway, one
	-- green-bronze drake far off the road.
	ElvenPlains = {
		Smoke = {
			{
				Preset = "Chimney",
				Prop = "Cottage",
				Offset = v(0.35, 1, 0.2),
				Color = { hex("E4E2DA"), hex("F4F4F0") },
				Max = 4,
			},
			{
				Preset = "GroundHaze",
				Prop = "Forest",
				Offset = v(0, -0.85, 0),
				Color = { hex("E6F0E6"), hex("F2F6F0") },
				Max = 3,
			},
		},
		Dragons = {
			{
				Kind = "Drake",
				Color = hex("6E8A5A"),
				At = 0.45,
				Side = 1, -- was -1: on the C layout the left side is a neighbour's ground (WORLD2_SPEC "Track effects")
				Lateral = 420,
				Radius = 220,
				Altitude = 300,
				Period = 70,
			},
		},
		Motion = {
			{ Prop = "Pine", Kind = "Sway", Angle = 2, Period = 4.6, Max = 30 },
		},
	},
	-- Track 2, burning castle realm: dark violet smoke columns lit magenta from below on the smoke props, embers off the
	-- burning ruins, brazier smoke on the battlements, wyvern statues hover, fires flicker, two black drakes circle.
	DemonCastle = {
		Smoke = {
			{
				Preset = "SmokeColumn",
				Prop = "Smoke",
				Offset = v(0, 1, 0),
				Color = { hex("7A2A6A"), hex("241C28") },
				Max = 4,
			},
			{
				Preset = "Embers",
				Prop = "RuinB",
				Offset = v(0, 1, 0),
				Color = { hex("FF5FB8"), hex("FF9A3A") },
				Max = 3,
			},
			{
				Preset = "RubbleSmoke",
				Prop = "RuinB",
				Offset = v(0, 1, 0),
				Color = { hex("5A2A52"), hex("2A2230") },
				Max = 3,
			},
			{
				Preset = "Chimney",
				Prop = "Rampart",
				Offset = v(0, 0.2, -1.2),
				Color = { hex("4A3040"), hex("2A2430") },
				Max = 4,
			},
		},
		Dragons = {
			{
				Kind = "Drake",
				Color = hex("2E2236"),
				At = 0.3,
				Side = 1,
				Lateral = 380,
				Radius = 200,
				Altitude = 320,
				Period = 64,
			},
			{
				Kind = "Drake",
				Color = hex("3A2440"),
				At = 0.7,
				Side = -1,
				Lateral = 400,
				Radius = 240,
				Altitude = 360,
				Period = 80,
				Phase = 0.5,
			},
		},
		Motion = {
			{ Prop = "Wyvern", Kind = "Bob", Height = 3, Roll = 2, Period = 6, Max = 6 },
		},
		Flicker = { Depth = 0.35, Speed = 9, Dropout = 0 }, -- fire
	},
	-- Track 3, ruined city by day: dust smoke rising from the collapsed buildings, low dust over the rubble.
	RuinedCityZ = {
		Smoke = {
			{
				Preset = "RubbleSmoke",
				Prop = "Collapsed",
				Offset = v(0, 1, 0),
				Color = { hex("9A8E80"), hex("BEB3A4") },
				Max = 4,
			},
			{
				Preset = "RubbleSmoke",
				Prop = "OfficeBroken",
				Offset = v(0, 1, 0),
				Color = { hex("8A8278"), hex("B4ACA2") },
				Max = 3,
			},
			{
				Preset = "GroundHaze",
				Prop = "Rubble",
				Offset = v(0, -0.8, 0),
				Color = { hex("B8AC98"), hex("CFC6B6") },
				Max = 3,
			},
		},
	},
	-- Track 4, moonlit mountain road: cold mist through the cedars and at the tunnel mouths, cedars sway, street lamps
	-- stutter, one pale spirit eel winds overhead.
	HauntedTunnel = {
		Smoke = {
			{
				Preset = "GroundHaze",
				Prop = "Cedar",
				Offset = v(0, -0.95, 0),
				Color = { hex("8FA6C0"), hex("A8BAD0") },
				Max = 5,
			},
			{
				Preset = "GroundHaze",
				Prop = "Portal",
				Offset = v(0, -0.9, -0.9),
				Color = { hex("9AB0C8"), hex("B4C4D6") },
				Max = 2,
			},
		},
		Dragons = {
			{
				Kind = "Eel",
				Color = hex("BFE8F0"),
				At = 0.5,
				Side = 1,
				Lateral = 360,
				Radius = 200,
				Altitude = 240,
				Period = 75,
			},
		},
		Motion = {
			{ Prop = "Cedar", Kind = "Sway", Angle = 1.5, Period = 5.5, Max = 30 },
		},
		Flicker = { Depth = 0.15, Speed = 4, Dropout = 0.03 }, -- a buzzing lamp that cuts out now and then
	},
	-- Track 5, wrecked district: grey smoke columns on the smoke props, steam off the giant corpse, thin rubble smoke.
	KaijuBase = {
		Smoke = {
			{
				Preset = "SmokeColumn",
				Prop = "Smoke",
				Offset = v(0, 1, 0),
				Color = { hex("8C8884"), hex("B8B4AE") },
				Max = 4,
			},
			{
				Preset = "Steam",
				Prop = "GiantCorpse",
				Offset = v(0, 1, 0),
				Color = { hex("F2F4F5"), hex("FFFFFF") },
				Max = 2,
			},
			{
				Preset = "RubbleSmoke",
				Prop = "Rubble",
				Offset = v(0, 1, 0),
				Color = { hex("8A8580"), hex("ADA8A2") },
				Max = 4,
			},
		},
	},
	-- Track 6, night city: roof-vent steam on the shops, the overhead wires sway, street lamps buzz.
	DevilTokyo = {
		Smoke = {
			{
				Preset = "Steam",
				Prop = "Konbini",
				Offset = v(0.4, 1, 0.3),
				Color = { hex("D8DEE6"), hex("EEF2F6") },
				Max = 4,
			},
			{
				Preset = "Steam",
				Prop = "ShopHouse",
				Offset = v(-0.3, 1, 0.4),
				Color = { hex("D0D6DE"), hex("E8ECF0") },
				Max = 4,
			},
		},
		Motion = {
			{ Prop = "CrossWire", Kind = "Sway", Angle = 0.8, Period = 3.8, Max = 16 },
		},
		Flicker = { Depth = 0.1, Speed = 6, Dropout = 0.01 },
	},
	-- Track 7, dusk volcanic island: camp-fire smoke, cottage chimneys, a plume on the volcano when it is placed, boats bob,
	-- bushes sway, one rust drake.
	AntIsland = {
		Smoke = {
			{
				Preset = "SmokeColumn",
				Prop = "IslandVolcano",
				Offset = v(0, 1, 0),
				Color = { hex("4A4440"), hex("7A706A") },
				Max = 1,
			},
			{
				Preset = "RubbleSmoke",
				Prop = "Camp",
				Offset = v(0, 1, 0),
				Color = { hex("6E6258"), hex("A89A8A") },
				Max = 3,
			},
			{
				Preset = "Chimney",
				Prop = "ThatchHouse",
				Offset = v(0.3, 1, 0),
				Color = { hex("C9BFB2"), hex("E0D8CE") },
				Max = 4,
			},
		},
		Dragons = {
			{
				Kind = "Drake",
				Color = hex("7A3A2A"),
				At = 0.6,
				Side = 1,
				Lateral = 440,
				Radius = 260,
				Altitude = 340,
				Period = 85,
			},
		},
		Motion = {
			{ Prop = "Ship", Kind = "Bob", Height = 0.8, Roll = 3, Period = 5, Max = 10 },
			{ Prop = "Brush", Kind = "Sway", Angle = 3, Period = 3.4, Max = 24 },
		},
	},
	-- Track 8, underground cavern: hot steam and embers off the lava river, dim haze round the rock pillars, lamps flicker.
	MonsterDen = {
		Smoke = {
			{
				Preset = "Steam",
				Prop = "LavaChasm",
				Offset = v(0, 0, 0),
				Surface = true, -- on the lava river, inside the chasm's box by design (WORLD2_SPEC "Track effects")
				Fill = v(0.8, 0, 0.5),
				Color = { hex("FF9A4A"), hex("7A5A50") },
				Max = 3,
			},
			{
				Preset = "Embers",
				Prop = "LavaChasm",
				Offset = v(0, 0, 0),
				Surface = true, -- on the lava river, inside the chasm's box by design (WORLD2_SPEC "Track effects")
				Fill = v(0.8, 0, 0.5),
				Color = { hex("FF7A2A"), hex("FFC060") },
				Max = 3,
			},
			{
				Preset = "GroundHaze",
				Prop = "RockPillar",
				Offset = v(0, -0.95, 0),
				Color = { hex("5A5260"), hex("6A6270") },
				Max = 4,
			},
		},
		Flicker = { Depth = 0.3, Speed = 7, Dropout = 0 },
	},
	-- Track 9, a city turned to solid gold: its townsfolk, wagons and trees are gold statues caught mid-step (the
	-- approved draft's story), so no smoke rises and nothing sways; only gold motes drift over the squares.
	GoldenCity = {
		Smoke = {
			{
				Preset = "Motes",
				Prop = "Square",
				Offset = v(0, -0.2, 0),
				Fill = v(0.7, 0, 0.7),
				Color = { hex("FFD36A"), hex("FFF0B0") },
				Max = 4,
			},
		},
	},
	-- Track 10, red plain (the effects add nothing to its layout or meshes): low red haze on the
	-- hills, the doors in the sky drift, the hanging arms sway.
	HellGate = {
		Smoke = {
			{
				Preset = "GroundHaze",
				Prop = "Hill",
				Offset = v(0, -0.6, 0),
				Color = { hex("C8504A"), hex("D8786A") },
				-- a little less opaque than GroundHaze (plateau 0.55): 0.818 of its opacity, the ratio of owner 2026-11-26
				-- "tone down track 10 red haze tiny bit" (proposed)
				Transparency = { { 0, 1 }, { 0.25, 0.63 }, { 0.75, 0.63 }, { 1, 1 } },
				Max = 4,
			},
		},
		Motion = {
			{ Prop = "SkyDoor", Kind = "Bob", Height = 4, Roll = 1.5, Period = 9, Max = 24 },
			{ Prop = "ArmA", Kind = "Sway", Angle = 1.2, Period = 7, Max = 8 },
			{ Prop = "ArmB", Kind = "Sway", Angle = 1.2, Period = 7.5, Max = 8 },
		},
	},
}

-- Runs only in World 2 and only when LIVE; World 1 never builds anything (its biome keys have no row either).
function TrackFxConfig.Enabled(worldId)
	return TrackFxConfig.LIVE == true and worldId == 2
end

return TrackFxConfig
