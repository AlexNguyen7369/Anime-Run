--!nonstrict
-- Track 5 (night): neon avenue, a scramble crossing, an overpass, a temple school on a hill, purple fog.
-- Signs are abstract neon shapes with no text. Tints only its own props and ground (never global Lighting).
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 5): flat Blocks city on Asphalt
-- streets and Concrete lots, one Hills 40 Slate hill for the temple school, a night-city atmosphere, audio and the
-- asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- IP (spec 7): no real store or station names, no real landmarks (no dog statue), no logos; every sign and screen
-- shows abstract shapes only.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, CYL, FACE, part, post, prop, block, gate, patch, giants, SMOKE, particles, NIGHT5, FOG5, PINK5, CYAN5, YELLOW5, CONCRETE5 =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.FACE,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SMOKE,
	Kit.particles,
	Kit.NIGHT5,
	Kit.FOG5,
	Kit.PINK5,
	Kit.CYAN5,
	Kit.YELLOW5,
	Kit.CONCRETE5

local DARK_CONCRETE = hex("2A2A34")
local GLASS = hex("3A3550")
local METAL = rgb(40, 40, 48)
local TEMPLE_WOOD = hex("4A2E22")
local TEMPLE_ROOF = hex("2A2A3A")
local PAPER = rgb(255, 196, 130)
local SCREEN = hex("3C2A7A")

-- A mesh prop (spec 4.2): `def`'s parts, scaled to `size`'s height, are the fallback when the ledger row is unusable.
-- `size` keeps the mesh's own proportions (the registry stretches the mesh to it). Phase 1: sizes are the fallback's
-- own; step A replaces them with each generated mesh's measured size.
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

-- Hero 1: a tall concrete block hung with stacked neon signboards (bars, rings and blocks, no text) and a rooftop
-- billboard frame.
local function neonSignTower()
	local parts = {
		part(v(18, 46, 16), v(0, 23, 0), DARK_CONCRETE, M.Concrete),
		part(v(18.3, 3, 16.3), v(0, 6, 0), GLASS, M.Glass), -- shop-floor glazing
		part(v(20, 1, 18), v(0, 46.5, 0), CYAN5, M.Neon), -- crown ring
		post(6, 0.6, v(-6, 50, 2), METAL, M.Metal), -- billboard legs
		post(6, 0.6, v(6, 50, 2), METAL, M.Metal),
		part(v(16, 5, 0.6), v(0, 51.5, 2), PINK5, M.Neon), -- rooftop billboard
	}
	for i, c in { PINK5, CYAN5, YELLOW5, PINK5, CYAN5 } do
		local y = 10 + i * 6.5
		-- wide bars across the face and vertical blade signs alternating on the front corners
		table.insert(parts, part(v(12, 3.5, 0.6), v(0, y, -8.3), c, M.Neon))
		table.insert(parts, part(v(1, 5, 2.4), v(i % 2 == 0 and 8.5 or -8.5, y + 1, -9), c, M.Neon))
	end
	table.insert(parts, part(v(5, 5, 0.7), v(-4, 44, -8.4), YELLOW5, M.Neon, CYL, FACE)) -- round sign
	return prop("NeonSignTower", v(20, 54, 18), parts, { Glow = PINK5 })
end

-- Hero 2: a mid-rise block carrying one big video screen of abstract shapes (circle, bars, block).
local function videoScreen()
	local parts = {
		part(v(24, 34, 14), v(0, 17, 0), DARK_CONCRETE, M.Concrete),
		part(v(24.3, 3, 14.3), v(0, 5, 0), GLASS, M.Glass),
		part(v(21, 15, 0.6), v(0, 24, -7.3), METAL, M.Metal), -- screen frame
		part(v(19, 13, 0.6), v(0, 24, -7.5), SCREEN, M.Neon),
		part(v(7, 7, 0.7), v(-5, 25, -7.7), PINK5, M.Neon, CYL, FACE),
		part(v(6, 2, 0.7), v(5, 28, -7.7), CYAN5, M.Neon),
		part(v(6, 2, 0.7), v(5, 24.5, -7.7), CYAN5, M.Neon),
		part(v(4, 4, 0.7), v(5, 20.5, -7.7), YELLOW5, M.Neon),
		part(v(24.4, 1, 14.4), v(0, 34.5, 0), PINK5, M.Neon),
		part(v(6, 3.5, 6), v(-6, 36.75, 3), METAL, M.Metal), -- rooftop plant
	}
	return prop("VideoScreen", v(24.4, 38.5, 15), parts, { Glow = CYAN5 })
end

-- Hero 3: a rail overpass segment: two concrete piers, a deck with two rails and side girders, catenary masts.
-- The deck runs along X (the road direction).
local function railOverpass()
	local parts = {
		part(v(4, 16, 6), v(-12, 8, 0), CONCRETE5, M.Concrete),
		part(v(4, 16, 6), v(12, 8, 0), CONCRETE5, M.Concrete),
		part(v(8, 1.5, 8), v(-12, 16.75, 0), CONCRETE5, M.Concrete), -- pier caps
		part(v(8, 1.5, 8), v(12, 16.75, 0), CONCRETE5, M.Concrete),
		part(v(34, 3, 10), v(0, 19, 0), CONCRETE5, M.Concrete), -- deck
		part(v(34, 2, 0.8), v(0, 20.5, -4.6), DARK_CONCRETE, M.Concrete), -- side girders
		part(v(34, 2, 0.8), v(0, 20.5, 4.6), DARK_CONCRETE, M.Concrete),
		part(v(34, 0.4, 0.4), v(0, 20.7, -1.5), rgb(150, 150, 165), M.Metal), -- rails
		part(v(34, 0.4, 0.4), v(0, 20.7, 1.5), rgb(150, 150, 165), M.Metal),
		part(v(34, 0.4, 0.6), v(0, 17.2, -5.1), YELLOW5, M.Neon), -- underside light strip
	}
	for _, x in { -14, 0, 14 } do
		table.insert(parts, part(v(0.5, 6, 0.5), v(x, 23, 4.2), METAL, M.Metal)) -- catenary mast
		table.insert(parts, part(v(0.4, 0.4, 6), v(x, 25.8, 1.4), METAL, M.Metal))
	end
	return prop("RailOverpass", v(34, 26, 10.2), parts, { Glow = YELLOW5 })
end

-- Hero 4: a wooden temple school hall on a stone plinth, two tiers of curved (upturned) tile roofs, lit paper windows.
local function templeSchool()
	local parts = {
		part(v(30, 2, 18), v(0, 1, 0), rgb(90, 88, 100), M.Slate), -- plinth
		part(v(10, 1, 3), v(0, 0.5, -10.5), rgb(90, 88, 100), M.Slate), -- front step
		part(v(24, 9, 13), v(0, 6.5, 0), TEMPLE_WOOD, M.WoodPlanks),
		part(v(30, 1.2, 18), v(0, 11.6, 0), TEMPLE_ROOF, M.Slate), -- lower roof
		part(v(5, 1, 18), v(-14.5, 12.3, 0), TEMPLE_ROOF, M.Slate, nil, CFrame.Angles(0, 0, 0.25)), -- upturned eaves
		part(v(5, 1, 18), v(14.5, 12.3, 0), TEMPLE_ROOF, M.Slate, nil, CFrame.Angles(0, 0, -0.25)),
		part(v(18, 6, 10), v(0, 15.2, 0), TEMPLE_WOOD, M.WoodPlanks), -- upper storey
		part(v(24, 1.2, 14), v(0, 18.8, 0), TEMPLE_ROOF, M.Slate),
		part(v(4, 1, 14), v(-11.5, 19.5, 0), TEMPLE_ROOF, M.Slate, nil, CFrame.Angles(0, 0, 0.3)),
		part(v(4, 1, 14), v(11.5, 19.5, 0), TEMPLE_ROOF, M.Slate, nil, CFrame.Angles(0, 0, -0.3)),
		part(v(14, 3, 8), v(0, 21, 0), TEMPLE_ROOF, M.Slate), -- hip
		part(v(16, 1.2, 1.2), v(0, 23, 0), TEMPLE_ROOF, M.Slate), -- ridge
		part(v(4, 6, 0.4), v(0, 5, -6.7), hex("2A1E15"), M.Wood), -- door
	}
	for _, x in { -8, 8 } do
		table.insert(parts, part(v(5, 3, 0.4), v(x, 7, -6.7), PAPER, M.Neon)) -- paper windows
		table.insert(parts, post(9, 1, v(x * 1.4, 6.5, -7), TEMPLE_WOOD, M.Wood)) -- veranda posts
	end
	table.insert(parts, part(v(10, 2, 0.4), v(0, 15.5, -5.2), PAPER, M.Neon))
	return prop("TempleSchool", v(30, 23.6, 18), parts, { Glow = PAPER })
end

-- Mid props (fallbacks for the meshes)
local trafficLight = prop("TrafficLight", v(5, 14, 2), {
	post(14, 0.6, v(-1.8, 7, 0), METAL, M.Metal),
	part(v(4, 0.4, 0.4), v(0, 12.5, 0), METAL, M.Metal), -- arm
	part(v(4, 1.3, 1.2), v(0.5, 12.5, -0.6), rgb(30, 30, 36), M.Metal), -- horizontal light box
	part(v(0.9, 0.9, 0.3), v(-0.8, 12.5, -1.3), hex("40FF80"), M.Neon),
	part(v(0.9, 0.9, 0.3), v(0.5, 12.5, -1.3), YELLOW5, M.Neon),
	part(v(0.9, 0.9, 0.3), v(1.8, 12.5, -1.3), hex("FF4040"), M.Neon),
})
local neonSign = prop("NeonSign", v(6, 12, 1), {
	post(12, 0.5, v(-2.5, 6, 0), CONCRETE5, M.Metal),
	part(v(6, 3, 0.6), v(0, 10, 0), PINK5, M.Neon),
	part(v(4, 1, 0.7), v(0, 7.5, 0), CYAN5, M.Neon),
})
local vending = block("VendingMachine", v(3, 6, 2.4), hex("E8E8F0"), M.SmoothPlastic, {
	part(v(2.4, 3.4, 0.2), v(0, 3.8, -1.25), CYAN5, M.Neon),
	part(v(1.6, 0.6, 0.2), v(0, 1, -1.25), rgb(30, 30, 36), M.Metal), -- pickup slot
})
local storefront = prop("GlassStorefront", v(16.4, 15, 12.4), {
	part(v(16, 14, 12), v(0, 7, 0), CONCRETE5, M.Concrete),
	part(v(14, 6, 0.4), v(0, 3.5, -6.2), GLASS, M.Glass), -- shop window
	part(v(14, 0.8, 0.5), v(0, 7, -6.3), PINK5, M.Neon), -- awning strip
	part(v(10, 2, 0.4), v(0, 10.5, -6.2), CYAN5, M.Neon), -- blank sign box
	part(v(16.4, 1, 12.4), v(0, 14.5, 0), DARK_CONCRETE, M.Concrete),
}, { Glow = CYAN5, Pad = true })
local concreteBlock = prop("ConcreteBlock", v(36.3, 50, 30.6), {
	part(v(36, 50, 30), v(0, 25, 0), CONCRETE5, M.Concrete),
	part(v(36.3, 4, 30.3), v(0, 30, 0), GLASS, M.Glass),
	part(v(36.3, 4, 30.3), v(0, 40, 0), GLASS, M.Glass),
	part(v(20, 8, 0.6), v(0, 18, -15.3), YELLOW5, M.Neon),
}, { Pad = true })
local templeGate = prop("TempleGate", v(20, 15, 9), {
	post(12, 1.4, v(-6, 6, 0), TEMPLE_WOOD, M.Wood),
	post(12, 1.4, v(6, 6, 0), TEMPLE_WOOD, M.Wood),
	part(v(18, 1.5, 8), v(0, 12.75, 0), TEMPLE_ROOF, M.Slate),
	part(v(14, 1.5, 6), v(0, 14.25, 0), TEMPLE_ROOF, M.Slate),
	part(v(20, 0.6, 9), v(0, 12, 0), TEMPLE_WOOD, M.Wood),
}, { Glow = rgb(255, 180, 120) })
-- Zebra crossing: white stripes laid flat on the lot (spec 7 "zebra crossings (decals)"; built from parts)
local zebraParts = {}
for i = -3, 3 do
	table.insert(zebraParts, part(v(1.6, 0.2, 10), v(i * 3, 0.1, 0), hex("E8E8EE"), M.Concrete))
end
local zebra = prop("ZebraCrossing", v(20, 0.2, 10), zebraParts)

-- Mesh props (Lane A). Sizes are the fallback's until step A measures each mesh.
local trafficLightMesh = meshed(trafficLight, "TrafficLightMesh", v(5, 14, 2))
local neonSignMesh = meshed(neonSign, "NeonSignMesh", v(6, 12, 1))
local vendingMesh = meshed(vending, "VendingMachineMesh", v(3, 6, 2.4))
local storefrontMesh = meshed(storefront, "StorefrontMesh", v(16.4, 15, 12.4))
local concreteBlockMesh = meshed(concreteBlock, "ConcreteBlockMesh", v(36.3, 50, 30.6))
local templeGateMesh = meshed(templeGate, "TempleGateMesh", v(20, 15, 9))

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Id is filled in step A. Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups go in
-- assets/biomes/PirateCoast/review/.
local function meshRow(texture, prompt, tris, notes)
	return { Kind = "Mesh", Lane = "A", Prompt = prompt, Texture = texture, Tris = tris, Notes = notes }
end
local function textureRow(mesh)
	return { Kind = "Texture", Lane = "A", Prompt = "generated with " .. mesh .. " (same prompt)" }
end

return {
	DisplayName = "Neon Cursed City",
	Ground = { Color = NIGHT5, Material = M.Asphalt },
	Sky = { Color = FOG5 },
	Gate = gate(CONCRETE5, M.Concrete, PINK5),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { trafficLightMesh, neonSignMesh, vendingMesh, neonSignMesh },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight; on a straight odd p stands on
	-- the outer side, even p on the inner side. Fractions of the 7200-stud track: 0-0.120 the opening neon avenue,
	-- 0.277-0.344 the straight after the scramble crossing, 0.411-0.580 the overpass straight (crest 0.467-0.478),
	-- 0.647-0.827 the hill straight (crest 0.702-0.711).
	Landmarks = {
		Offset = 20, -- placeholder: x1.75 heroes are at most 31.5 deep, so they span about 40-72 studs from the centre
		Every = 18,
		Props = {
			-- p 1, outer: the neon avenue
			meshed(neonSignTower(), "NeonSignTowerMesh", v(20, 54, 18), { Hero = true, At = 0.06 }), -- x1.75: 35 x 94.5
			-- p 2, inner: just past the scramble crossing
			meshed(videoScreen(), "VideoScreenMesh", v(24.4, 38.5, 15), { Hero = true, At = 0.3 }), -- x1.75: 42.7 x 67.4
			-- p 3, outer: beside the road's overpass crest
			meshed(railOverpass(), "RailOverpassMesh", v(34, 26, 10.2), { Hero = true, At = 0.472 }), -- 59.5 x 45.5
			-- p 4, inner: on the temple hill (Terrain Sections below)
			meshed(templeSchool(), "TempleSchoolMesh", v(30, 23.6, 18), { Hero = true, At = 0.706 }), -- 52.5 x 41.3
			storefrontMesh,
			templeGateMesh,
			storefrontMesh,
		},
	},
	Horizon = {
		-- placeholder: 20 (was 55). The x2 pieces are 36 deep, so they span about 40-76 studs from the centre line and
		-- keep inside this zone's half of the gap.
		Offset = 20,
		Props = {
			prop("NeonSkyline", v(60, 60.5, 18), {
				part(v(18, 60, 16), v(-20, 30, 0), hex("1E1C2A"), M.Concrete),
				part(v(16, 44, 14), v(0, 22, 0), hex("24222F"), M.Concrete),
				part(v(18, 52, 16), v(20, 26, 0), hex("1E1C2A"), M.Concrete),
				part(v(18.4, 1, 16.4), v(-20, 60, 0), PINK5, M.Neon),
				part(v(16.4, 1, 14.4), v(0, 44, 0), CYAN5, M.Neon),
				part(v(18.4, 1, 16.4), v(20, 52, 0), YELLOW5, M.Neon),
				part(v(60, 30, 1), v(0, 30, 8.5), FOG5, M.SmoothPlastic), -- local fog backdrop
			}, { Pad = true }),
			prop("RooftopRow", v(56, 36, 18), {
				part(v(26, 30, 16), v(-14, 15, 0), hex("24222F"), M.Concrete),
				part(v(26, 22, 16), v(14, 11, 0), hex("1E1C2A"), M.Concrete),
				part(v(20, 6, 0.6), v(-14, 24, -8.3), PINK5, M.Neon),
				part(v(20, 4, 0.6), v(14, 16, -8.3), CYAN5, M.Neon),
				post(6, 3, v(-8, 33, 2), GLASS, M.Metal), -- rooftop tank
				part(v(56, 24, 1), v(0, 12, 8.5), FOG5, M.SmoothPlastic), -- local fog backdrop
			}, { Pad = true }),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 150,
		Props = {
			"VendingMachine",
			"NeonSign",
			block("Bollard", v(1.4, 3, 1.4), YELLOW5, M.Metal),
			prop("FogPuff", v(14, 7, 14), { part(v(14, 7, 14), v(0, 3.5, 0), FOG5, M.SmoothPlastic, BALL) }),
			"TrafficLight",
			zebra,
		},
		Patches = {
			patch("NeonPuddle", 14, 10, PINK5, M.Glass),
			patch("CyanPuddle", 12, 9, CYAN5, M.Glass),
			patch("OilStain", 16, 12, hex("1C1828"), M.Asphalt),
		},
	},
	Blocks = giants({
		prop("GiantSignTower", v(30.4, 80.5, 30.6), {
			part(v(30, 80, 30), v(0, 40, 0), DARK_CONCRETE, M.Concrete),
			part(v(24, 10, 0.6), v(0, 60, -15.3), PINK5, M.Neon),
			part(v(24, 10, 0.6), v(0, 40, -15.3), CYAN5, M.Neon),
			part(v(24, 10, 0.6), v(0, 20, -15.3), YELLOW5, M.Neon),
			part(v(30.4, 1, 30.4), v(0, 80, 0), PINK5, M.Neon),
		}, { Pad = true }),
		concreteBlockMesh,
		meshed(railOverpass(), "RailOverpassMesh", v(40, 30.6, 12)), -- rail piers between the blocks (no pad)
	}),
	-- Landmark emitters (BiomeDressing): slow purple fog wisps
	Particles = particles(
		SMOKE,
		FOG5,
		{ Size = 4, Lifetime = 5, Rate = 4, Speed = 1, Transparency = 0.4, LightEmission = 0.2 }
	),
	-- Spec 3.3 / 7: flat Blocks city, Asphalt streets and Concrete lots, no embank (the overpass and hill ramps ride on
	-- the road's supports). One Hills 40 Slate hill on the inner side of the hill straight (slopes 0.674-0.738) for the
	-- temple school (hero p 4). Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Blocks" },
		Sections = {
			{
				From = 0.66,
				To = 0.75,
				Side = "Inner",
				Ridge = { Shape = "Hills", Height = 40, Noise = 0.04, Amp = 4 },
				Material = M.Slate,
			},
		},
		Materials = { Corridor = M.Asphalt, Ridge = M.Concrete, Cliff = M.Slate, Bed = M.Concrete },
		CliffSlope = 0.9,
		Embank = false,
	},
	-- Spec 5.2 / 7: night city. ClockTime 22, Atmosphere Color #3A1F5C, Density 0.5, Haze 1, Bloom 1.6 / 0.9 and
	-- Contrast +0.2 are from section 7; the rest are placeholders. No skybox row (engine stars and moon); a Lane D
	-- skybox needs the script / remote check first (docs/BUGS.md creator-store-backdoor-skybox).
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 22,
			Brightness = 1,
			Ambient = hex("2A2040"),
			OutdoorAmbient = hex("4A3A6A"),
		},
		Atmosphere = { Density = 0.5, Offset = 0.1, Color = FOG5, Decay = NIGHT5, Glare = 0, Haze = 1 },
		Grade = { Contrast = 0.35, TintColor = hex("EDE4FF") }, -- baseline Contrast 0.15 + 0.2
		Bloom = { Intensity = 1.6, Threshold = 0.9 }, -- neon glows
		SunRays = { Intensity = 0 },
		Sky = {
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 800, -- placeholder: city glow hides most stars
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.4, Density = 0.35, Color = FOG5 },
		Particles = {
			{
				Texture = "MoteParticle", -- drifting dark-purple motes
				Color = hex("5B3A8C"),
				Size = 0.6,
				Rate = 12,
				Lifetime = 6,
				Speed = 0.6,
				SpreadAngle = 180,
				LightEmission = 0.3,
				Area = v(90, 20, 90),
			},
		},
	}),
	Audio = { Loop = "AmbCityNight", OneShots = { "SfxCrossingChime", "SfxTrainPass" }, Volume = 0.3, Reverb = "City" },
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Tris is the generation cap. Reviewed is left for the
	-- rules auditor (spec 4.1). Sound rows: Creator Store audio ids used directly (no insert, nothing to strip).
	Assets = {
		-- generate_mesh size 20 x 54 x 18
		NeonSignTowerMesh = meshRow(
			"NeonSignTowerTex",
			"tall narrow dark concrete city building at night, many glowing neon signboards stacked up the front in pink, cyan and yellow showing only simple abstract shapes like bars, rings and squares with no letters and no writing, vertical blade signs on the corners, a blank glowing billboard frame on the roof, stylized cartoon style",
			15000,
			"hero 1: signs abstract, no text; front faces -Z"
		),
		-- generate_mesh size 24 x 38 x 15
		VideoScreenMesh = meshRow(
			"VideoScreenTex",
			"mid rise dark concrete city building with one huge glowing video screen on its front wall, the screen shows only colorful abstract shapes, a pink circle, cyan bars and a yellow square, on a purple background, no letters, no logos and no faces, thin neon trim on the roof edge, stylized cartoon style",
			15000,
			"hero 2: screen abstract only; front faces -Z"
		),
		-- generate_mesh size 34 x 26 x 10
		RailOverpassMesh = meshRow(
			"RailOverpassTex",
			"short segment of an elevated concrete railway overpass, a straight concrete deck carrying two steel rails, resting on two thick rectangular concrete piers, low side walls along the deck, a few thin metal overhead wire masts, a yellow light strip under the deck, no train, no signs and no writing, stylized cartoon style",
			10000,
			"hero 3: deck runs along X; also the Blocks rail pier"
		),
		-- generate_mesh size 30 x 24 x 18
		TempleSchoolMesh = meshRow(
			"TempleSchoolTex",
			"traditional wooden temple hall used as a school, dark brown timber walls on a grey stone base, two tiers of dark grey tiled roofs with gently curved upturned eaves, a wooden veranda with posts, paper windows glowing warm orange, plain with no plaque, no crest and no writing, stylized cartoon style",
			15000,
			"hero 4: no plaque or crest; front faces -Z"
		),
		-- generate_mesh size 5 x 14 x 2
		TrafficLightMesh = meshRow(
			"TrafficLightTex",
			"city traffic light on a thin dark grey metal pole with a side arm holding a horizontal three lamp signal box, green, yellow and red round lamps, plain with no signs, stylized cartoon style",
			1500
		),
		-- generate_mesh size 6 x 12 x 1
		NeonSignMesh = meshRow(
			"NeonSignTex",
			"standing street neon sign on a thin metal pole, a glowing pink rectangular sign box above a smaller cyan glowing bar, only abstract shapes with no letters and no writing, stylized cartoon style",
			1500,
			"no text"
		),
		-- generate_mesh size 3 x 6 x 2.4
		VendingMachineMesh = meshRow(
			"VendingMachineTex",
			"white drink vending machine with a glowing cyan front panel showing rows of plain unlabeled bottles, buttons and a pickup slot at the bottom, no brand, no logo and no writing, stylized cartoon style",
			2000,
			"bottles unlabeled, no brand"
		),
		-- generate_mesh size 16 x 15 x 12
		StorefrontMesh = meshRow(
			"StorefrontTex",
			"small two storey city shop building at night, grey concrete walls, a wide glass shop window on the ground floor lit from inside, a pink neon strip awning and a blank glowing cyan sign box with no writing, flat roof, stylized cartoon style",
			3000,
			"sign box blank; Pad = true"
		),
		-- generate_mesh size 36 x 50 x 30
		ConcreteBlockMesh = meshRow(
			"ConcreteBlockTex",
			"tall plain grey concrete office block, two bands of dark tinted glass windows wrapping around, one blank glowing yellow sign panel on the front with no writing, flat roof with small rooftop units, stylized low poly cartoon style",
			3000,
			"Blocks giant; Pad = true"
		),
		-- generate_mesh size 20 x 15 x 9
		TempleGateMesh = meshRow(
			"TempleGateTex",
			"traditional wooden temple gate with two round dark brown wooden pillars, a wide dark grey tiled roof with gently curved upturned ends on top, plain with no plaque and no writing, stylized cartoon style",
			3000,
			"no plaque"
		),
		NeonSignTowerTex = textureRow("NeonSignTowerMesh"),
		VideoScreenTex = textureRow("VideoScreenMesh"),
		RailOverpassTex = textureRow("RailOverpassMesh"),
		TempleSchoolTex = textureRow("TempleSchoolMesh"),
		TrafficLightTex = textureRow("TrafficLightMesh"),
		NeonSignTex = textureRow("NeonSignMesh"),
		VendingMachineTex = textureRow("VendingMachineMesh"),
		StorefrontTex = textureRow("StorefrontMesh"),
		ConcreteBlockTex = textureRow("ConcreteBlockMesh"),
		TempleGateTex = textureRow("TempleGateMesh"),
		MoteParticle = {
			Kind = "Texture",
			Lane = "A",
			Prompt = "in-house 128 px soft round mote with a slightly lumpy edge and a brighter core, white on transparent, tinted dark purple by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/PirateCoast/mote_particle.png); Id after upload in step A",
		},
		AmbCityNight = {
			Kind = "Sound",
			Id = "rbxassetid://9112759663",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112759663: City Night Ambience 2, distant traffic wash and pass bys, loop, 36 s",
		},
		SfxCrossingChime = {
			Kind = "Sound",
			Id = "rbxassetid://9114133612",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9114133612: Door Chime Single Dings 1, one resonant ding, 12 s (stands in for a crossing chime)",
		},
		SfxTrainPass = {
			Kind = "Sound",
			Id = "rbxassetid://9117151457",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9117151457: elevated train pass by, track clack and metal rattle, 22 s",
		},
	},
}
