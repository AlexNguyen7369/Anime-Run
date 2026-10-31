--!nonstrict
-- Track 3: sandy island, plank docks, a moored caravel with a plain sail (no flag, no figurehead), palms,
-- a windmill on the headland, a lighthouse, white houses with red and blue roofs.
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 3): the sea fills the gaps, one
-- headland on the cliff road, a tropical noon atmosphere, audio and the asset ledger. Mesh props keep their part
-- fallback (spec 4.2), scaled to the mesh's size.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, part, post, prop, block, house, gate, patch, giants, SPARKLE, particles, SAND3, SEA3, WHITE3, ROOF3, DOCK3, PALM3 =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.house,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SPARKLE,
	Kit.particles,
	Kit.SAND3,
	Kit.SEA3,
	Kit.WHITE3,
	Kit.ROOF3,
	Kit.DOCK3,
	Kit.PALM3

-- A mesh prop (spec 4.2): `def`'s parts, scaled to `size`'s height, are the fallback when the ledger row is unusable.
-- `size` keeps the mesh's own proportions (the registry stretches the mesh to it).
local function meshed(def, key, size, extra)
	local k = size.Y / def.Size.Y
	local parts = {}
	for i, p in def.Parts do
		local q = table.clone(p)
		q.Size = p.Size * k
		q.Pos = p.Pos * k
		parts[i] = q
	end
	local out = prop(def.Name, size, parts, { Mesh = key, Glow = def.Glow, Tag = def.Tag, Pad = def.Pad })
	for name, value in extra or {} do
		out[name] = value
	end
	return out
end

local HERO = { Hero = true }
local BLUE_ROOF = hex("2E6FB0")
local TRUNK = hex("8A6A44")
local LAMP = rgb(255, 210, 140)

-- Fallback shapes (the meshes replace them once reviewed)
local palm = prop("Palm", v(10, 17, 10), {
	post(8, 1, v(0, 4, 0), TRUNK, M.Wood),
	part(v(1, 8, 1), v(0.8, 11, 0), TRUNK, M.Wood, nil, CFrame.Angles(0, 0, -0.2)),
	part(v(10, 0.6, 3), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0, 0, -0.3)),
	part(v(3, 0.6, 10), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0.3, 0, 0)),
})
local cargo = prop("CargoPile", v(8, 5, 6), {
	post(4, 3, v(-2, 2, 0), DOCK3, M.Wood),
	post(0.4, 3.2, v(-2, 1, 0), rgb(70, 70, 70), M.Metal),
	post(0.4, 3.2, v(-2, 3, 0), rgb(70, 70, 70), M.Metal),
	part(v(3, 3, 3), v(2, 1.5, 0), hex("A9783F"), M.WoodPlanks),
	part(v(2.6, 2, 2.6), v(2, 4, 0), hex("C29055"), M.WoodPlanks),
})
-- Moored caravel; the mesh's hull runs along Z (bow toward the road), so its fallback does too
local caravel = prop("Caravel", v(12, 21.5, 22.4), {
	part(v(9, 5, 20), v(0, 2.5, 0), DOCK3, M.WoodPlanks),
	part(v(9, 3, 6), v(0, 6.5, 7), hex("6E4421"), M.WoodPlanks),
	post(16, 0.8, v(0, 13, -4), hex("6E4421"), M.Wood),
	post(14, 0.8, v(0, 12, 3), hex("6E4421"), M.Wood),
	part(v(10, 8, 0.4), v(0, 15, -4), WHITE3, M.Fabric), -- plain sail
	part(v(9, 6, 0.4), v(0, 13, 3), WHITE3, M.Fabric),
}, { Tag = "BiomeBob", Glow = LAMP })
-- No BiomeSpin (placeholder): the tag turns the whole model about its vertical axis, which would spin the tower,
-- not the sails (the sails are part of the one mesh).
local windmill = prop("Windmill", v(16, 22, 11.35), {
	part(v(8, 16, 8), v(0, 8, 0), WHITE3, M.Plaster),
	part(v(10, 4, 10), v(0, 18, 0), ROOF3, M.Slate),
	part(v(1.6, 16, 0.5), v(0, 14, 4.8), hex("B08A5A"), M.WoodPlanks),
	part(v(16, 1.6, 0.5), v(0, 14, 4.8), hex("B08A5A"), M.WoodPlanks),
}, { Glow = LAMP })
local lighthouse = prop("Lighthouse", v(12, 20.5, 11.9), {
	part(v(12, 2, 11.9), v(0, 1, 0), hex("8C8C8C"), M.Rock),
	post(13, 5.5, v(0, 8.5, 0), WHITE3, M.Plaster),
	post(1.6, 5.7, v(0, 7, 0), ROOF3, M.Plaster),
	post(1.6, 5.7, v(0, 11, 0), ROOF3, M.Plaster),
	part(v(4, 3, 4), v(0, 16.5, 0), hex("FFE8A0"), M.Neon),
	part(v(5, 2, 5), v(0, 19.5, 0), ROOF3, M.Metal),
}, { Glow = LAMP })
local dock = prop("PlankDock", v(8, 4.4, 5.6), {
	part(v(8, 0.8, 5.6), v(0, 2.6, 0), DOCK3, M.WoodPlanks),
	post(4.4, 0.8, v(-3.4, 2.2, -2.4), hex("6E4421"), M.Wood),
	post(4.4, 0.8, v(3.4, 2.2, -2.4), hex("6E4421"), M.Wood),
	post(4.4, 0.8, v(-3.4, 2.2, 2.4), hex("6E4421"), M.Wood),
	post(4.4, 0.8, v(3.4, 2.2, 2.4), hex("6E4421"), M.Wood),
})
local buoy = prop("Buoy", v(4, 4.8, 3.9), {
	part(v(4, 3, 3.9), v(0, 1.5, 0), ROOF3, M.SmoothPlastic, BALL),
	part(v(4.1, 1, 4), v(0, 1.5, 0), WHITE3, M.SmoothPlastic),
	post(1.8, 0.4, v(0, 3.9, 0), rgb(70, 70, 70), M.Metal),
})
local net = block("FishingNet", v(5.9, 4.2, 3), hex("6B5A3E"), M.Fabric)

local palmMesh = meshed(palm, "PalmMesh", v(12.3, 16.7, 12.8))
local cargoMesh = meshed(cargo, "CargoPileMesh", v(8.9, 5.2, 9))
local dockMesh = meshed(dock, "PlankDockMesh", v(12, 6.6, 8.4))
local redHouse = meshed(
	house("HarborHouse", 12, 9, 12, WHITE3, ROOF3, { Trim = DOCK3, Window = SEA3, Glow = LAMP }),
	"HouseRedRoofMesh",
	v(14.3, 16.8, 14.6)
)
local blueHouse = meshed(
	house("BlueRoofHouse", 11, 8, 12, WHITE3, BLUE_ROOF, { Trim = DOCK3, Window = SEA3, Floors = 2 }),
	"HouseBlueRoofMesh",
	v(12.6, 17.9, 14.4)
)

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups are in assets/biomes/Docks/review/.
local function meshRow(id, texture, prompt, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Tris = tris,
		Reviewed = "2026-10-31 rules-auditor",
		Notes = notes,
	}
end
local function textureRow(id, mesh)
	return {
		Kind = "Texture",
		Id = id,
		Lane = "A",
		Prompt = "generated with " .. mesh .. " (same prompt)",
		Reviewed = "2026-10-31 rules-auditor",
	}
end

return {
	DisplayName = "Pirate Harbor Isle",
	Ground = { Color = SAND3, Material = M.Sand },
	Sky = { Color = hex("7FD0F5") },
	Gate = gate(DOCK3, M.WoodPlanks),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { palmMesh, cargoMesh, redHouse, palmMesh, blueHouse },
	},
	-- Pinned defs (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight; on a straight odd p stands on
	-- the outer side, even p on the inner side.
	Landmarks = {
		Offset = 20, -- placeholder: landmarks span about 42-75 studs from the centre line: beach and sea channel
		Every = 22,
		Props = {
			-- p 1, outer: the cliff road's crest (slopes 0.735-0.822), on the headland section
			-- No Yaw: placed as is, its sails already face the road (checked in Play 2026-10-31; Yaw = pi turned them away)
			meshed(windmill, "WindmillMesh", v(16, 22, 11.35), { Hero = true, At = 0.78 }), -- x1.75: 28 x 20
			-- p 2, inner: moored at the end of the dock run (straight 0.101-0.147)
			meshed(caravel, "CaravelMesh", v(10, 17.9, 18.7), { Hero = true, At = 0.12 }), -- x1.75: 17.5 x 32.7
			dockMesh,
			redHouse,
			dockMesh,
			blueHouse,
		},
	},
	-- Hero landmarks without a pin: x2 at the horizon scale, footprint at most 60 x 60 (placeholder)
	Horizon = {
		-- placeholder: 20, not 30. The x2 pieces are 30 deep, so they span about 42-72 studs from the centre line and
		-- keep inside this zone's half of the ~150-stud gap (midline about 77).
		Offset = 20,
		Props = {
			meshed(lighthouse, "LighthouseMesh", v(15, 25.6, 14.9), HERO), -- x2: 30 x 51 x 30
			meshed(caravel, "CaravelMesh", v(8, 14.3, 15), HERO), -- x2: 16 x 29 x 30
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 160,
		Props = {
			"Palm",
			"CargoPile",
			meshed(buoy, "BuoyMesh", v(4, 4.8, 3.9)),
			meshed(net, "FishingNetMesh", v(7, 5, 3.6)),
			prop("RopeCoil", v(3, 1, 3), { post(1, 3, v(0, 0.5, 0), hex("C9AE7C"), M.Fabric) }),
		},
		Patches = {
			patch("WetSand", 26, 16, hex("D9C48E"), M.Sand),
			patch("Shells", 12, 10, hex("F7F0E0"), M.Pebble),
			patch("Seaweed", 14, 8, hex("5E7A3E"), M.Grass),
		},
	},
	Blocks = giants({
		meshed(palm, "PalmMesh", v(25.1, 34, 26.1)),
		meshed(
			house("Warehouse", 24, 16, 24, WHITE3, BLUE_ROOF, { Trim = DOCK3, Floors = 2 }),
			"HouseBlueRoofMesh",
			v(21.1, 29.9, 24)
		),
		meshed(
			house("BigHarborHouse", 24, 16, 24, WHITE3, ROOF3, { Trim = DOCK3 }),
			"HouseRedRoofMesh",
			v(23.8, 28, 24.4)
		),
	}),
	-- Landmark emitters (BiomeDressing): pale and dim, so bloom does not light them into sparks
	Particles = particles(SPARKLE, rgb(200, 228, 240), {
		Size = 0.4,
		Lifetime = 2,
		Rate = 3,
		Speed = 1,
		LightEmission = 0,
	}),
	-- Spec 3.3 / 7: the sea fills the gaps (ridge Water at Level -3 over a Sand bed), sand beaches in the shoulder,
	-- and one Hills 30 headland on the cliff road. Every number is a placeholder. Sections (From / To = fractions of
	-- the track length): the cliff road's slopes run 0.735-0.822 inside the straight 0.696-0.887.
	Terrain = {
		Ridge = { Shape = "Water" },
		Water = { Level = -3 },
		Sections = {
			{
				From = 0.7,
				To = 0.87,
				Side = "Outer",
				Ridge = { Shape = "Hills", Height = 30, Noise = 0.03, Amp = 3 },
				Material = M.Ground,
			},
		},
		Materials = { Corridor = M.Sand, Ridge = M.Sand, Cliff = M.Ground, Bed = M.Sand },
		CliffSlope = 0.9,
		Embank = true,
	},
	-- Spec 5.2 / 7: tropical noon. Values are placeholders except where section 7 gives them.
	Atmosphere = Kit.Atmosphere({
		Lighting = { ClockTime = 12.5 },
		Atmosphere = { Density = 0.25, Haze = 0.3, Color = hex("CFE8F5"), Decay = hex("8FB8D0") },
		Grade = { Saturation = 0.38 }, -- baseline 0.18 + 0.2
		SunRays = { Intensity = 0.08 },
		Sky = {
			Skybox = "SkyTropicalNoon",
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.45, Density = 0.4, Color = hex("FFFFFF") },
		Water = { Color = hex("2E8BC0"), Transparency = 0.4, Reflectance = 0.3, WaveSize = 0.3, WaveSpeed = 10 },
		Particles = {
			{
				Texture = "SparkleParticle",
				Color = hex("C8E6F5"), -- below white so bloom does not flare them
				Size = 0.8,
				Rate = 10,
				Lifetime = 1.5,
				Speed = 0.5,
				SpreadAngle = 180,
				LightEmission = 0,
				Area = v(90, 6, 90),
			},
		},
	}),
	Audio = { Loop = "AmbSurfGulls", OneShots = { "SfxShipBell", "SfxRopeCreak" }, Volume = 0.35, Reverb = "Plain" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Tris is the generation cap.
	Assets = {
		CaravelMesh = meshRow(
			"rbxassetid://108723388126227",
			"CaravelTex",
			"wooden caravel sailing ship, long tall brown wooden hull with a raised rear deck cabin, three tall wooden masts with large plain white square canvas sails, rope rigging, plain rounded bow, stylized cartoon style",
			15000,
			"hero 1: plain white sails, no flag, plain stem post (no figurehead); hull along Z"
		),
		WindmillMesh = meshRow(
			"rbxassetid://75897665570424",
			"WindmillTex",
			"seaside windmill, round white plaster tower with a small wooden door and windows, conical red tiled roof, four large wooden lattice windmill sails covered with plain white cloth on the front, small stone base, stylized cartoon style",
			10000,
			"hero 2: placed unturned, sails and door face the road"
		),
		LighthouseMesh = meshRow(
			"rbxassetid://97514919612423",
			"LighthouseTex",
			"tall white lighthouse tower with two red horizontal stripes, round glass lantern room with a warm yellow light at the top, red domed roof, small balcony railing, standing on a rocky base, stylized cartoon style",
			10000,
			"hero 3"
		),
		HouseRedRoofMesh = meshRow(
			"rbxassetid://129843673544432",
			"HouseRedRoofTex",
			"small seaside house with smooth white plaster walls, red tiled gable roof, blue wooden door and blue window shutters, small chimney, stylized cartoon style",
			3000
		),
		HouseBlueRoofMesh = meshRow(
			"rbxassetid://103734483364353",
			"HouseBlueRoofTex",
			"two storey seaside town house with smooth white plaster walls, blue tiled roof, wooden balcony on the upper floor, arched wooden door, small square windows with wooden frames, stylized cartoon style",
			3000
		),
		PalmMesh = meshRow(
			"rbxassetid://116552039322572",
			"PalmTex",
			"very tall thin coconut palm tree, long slender curved brown ringed trunk, small crown of drooping green palm fronds at the very top with a few coconuts, stylized low poly cartoon style",
			2000
		),
		PlankDockMesh = meshRow(
			"rbxassetid://119274329107262",
			"PlankDockTex",
			"long narrow wooden jetty walkway, brown weathered wooden planks laid across, raised on rows of round wooden piles, simple rope rail on one side, stylized cartoon style",
			3000,
			"comes out as a short dock section with rope rails"
		),
		CargoPileMesh = meshRow(
			"rbxassetid://105426139677300",
			"CargoPileTex",
			"small pile of cargo on a harbor dock: two wooden barrels with dark metal bands and a stack of two plain wooden crates beside them, no labels and no markings, stylized cartoon style",
			2000,
			"barrels and crates are blank"
		),
		BuoyMesh = meshRow(
			"rbxassetid://108126305979752",
			"BuoyTex",
			"round harbor marker buoy floating on water, red and white striped body, short metal frame on top with a small lamp, plain with no text, stylized cartoon style",
			1500
		),
		FishingNetMesh = meshRow(
			"rbxassetid://105326359595340",
			"FishingNetTex",
			"fishing net hung to dry on a simple wooden drying rack of two posts and a crossbar, brown rope net with a few round cork floats, a small coil of rope at the base, stylized cartoon style",
			2000
		),
		CaravelTex = textureRow("rbxassetid://134227632396000", "CaravelMesh"),
		WindmillTex = textureRow("rbxassetid://87229536902543", "WindmillMesh"),
		LighthouseTex = textureRow("rbxassetid://71284937393260", "LighthouseMesh"),
		HouseRedRoofTex = textureRow("rbxassetid://138590076478413", "HouseRedRoofMesh"),
		HouseBlueRoofTex = textureRow("rbxassetid://82098018415906", "HouseBlueRoofMesh"),
		PalmTex = textureRow("rbxassetid://109882449279598", "PalmMesh"),
		PlankDockTex = textureRow("rbxassetid://117677672428242", "PlankDockMesh"),
		CargoPileTex = textureRow("rbxassetid://83203716860528", "CargoPileMesh"),
		BuoyTex = textureRow("rbxassetid://105625027376029", "BuoyMesh"),
		FishingNetTex = textureRow("rbxassetid://108808231820047", "FishingNetMesh"),
		SparkleParticle = {
			Kind = "Texture",
			Id = "rbxassetid://77726919089756",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "A",
			Prompt = "in-house 128 px four-point glint with a soft core, white on transparent, tinted sea-blue by the emitter",
			Notes = "drawn with python3 (assets/biomes/Docks/sparkle_particle.png), uploaded from Studio",
		},
		SkyTropicalNoon = {
			Kind = "Skybox",
			Id = "rbxassetid://679786546",
			Faces = {
				Bk = "rbxassetid://679786546",
				Dn = "rbxassetid://680029379",
				Ft = "rbxassetid://679786832",
				Lf = "rbxassetid://679786679",
				Rt = "rbxassetid://679786411",
				Up = "rbxassetid://679787023",
			},
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "User727116306",
			Notes = "Creator Store 2716603671 (Realistic Cloudy Sky: blue sky, white cumulus, plain); no scripts",
		},
		AmbSurfGulls = {
			Kind = "Sound",
			Id = "rbxassetid://9112751378",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112751378: British Surf Birds 1, surf on rocks with seagulls, loop, 36 s",
		},
		SfxShipBell = {
			Kind = "Sound",
			Id = "rbxassetid://9113584742",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9113584742: brass hand bell, single taps, long ring, 6.6 s",
		},
		SfxRopeCreak = {
			Kind = "Sound",
			Id = "rbxassetid://9120806093",
			Reviewed = "2026-10-31 rules-auditor",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9120806093: wood creaking while hanging on a rope, 7.1 s",
		},
	},
}
