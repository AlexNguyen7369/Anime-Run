--!nonstrict
-- Shared builders and palettes for the biome modules beside it (one module per biome key).
-- Biome data format:
-- Anime biome themes, one per track Biome key (docs/TRACKS_AND_BIOMES_SPEC.md "Biomes" and "References"). Data only;
-- BiomeDressing builds it. Keys and track ids are kept from the fork (owner 2026-10-30); DisplayName is the
-- spec's working name. Every number here is a placeholder that can be tuned. All props are built from parts
-- (design doc 5: no logos, crests, symbols, show text or real place names; signs carry no text).
--
-- A prop: { Name, Size, Parts, Tag?, Glow? }
--   Size   bounding box (studs)
--   Parts  { Size, Pos, Color, Material, Shape?, Rot? }; Pos is the part centre relative to the prop's base centre
--          (Y up, -Z toward the road), Rot an optional CFrame rotation
--   Tag    "BiomeSpin" or "BiomeBob", animated on the client by Client/BiomeAmbience
--   Glow   Color3 of a local PointLight (landmarks only)
-- Layers: Rhythm { Every, Offset, Props }, Landmarks { Offset, Every, Props }, Horizon { Offset, Props },
-- Gate { Color, Material, Glow?, Index?, Skip? }, Ground { Color, Material }, Sky { Color }. Offset is studs from the
-- road edge. Sky.Color tints only the theme's own backdrop pieces (moon panels, haze); never global Lighting.
-- Scatter { Every, Near, Far, Props, Patches }: Props are prop tables or the Name of a rhythm or landmark prop;
--   Patches are flat slabs { Name, Size (X, Z), Color, Material }.
-- Blocks { Spacing, Near, Rows, RowDepth, Props }: rows of big props (street walls in the city).
-- Particles: one ParticleEmitter setting per biome, put on every landmark (Rate is capped by BiomeDressing).
--
-- b1 (docs/BIOME_ENVIRONMENT_SPEC.md section 9): each biome also carries Terrain (3.3), Atmosphere (5.2),
-- Audio { Loop, OneShots, Volume, Reverb } (6) and Assets, the asset ledger (4.4).

local M = Enum.Material
local hex = Color3.fromHex
local rgb = Color3.fromRGB
local v = Vector3.new
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's axis is X; this stands it up
local FACE = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder disk facing the road

local function part(size, pos, color, material, shape, rot)
	return { Size = size, Pos = pos, Color = color, Material = material, Shape = shape, Rot = rot }
end

-- Upright cylinder `h` tall, `d` across, centred at `pos`
local function post(h, d, pos, color, material)
	return part(v(h, d, d), pos, color, material, CYL, UP)
end

local function prop(name, size, parts, extra)
	local p = { Name = name, Size = size, Parts = parts }
	for k, value in extra or {} do
		p[k] = value
	end
	return p
end

local function block(name, size, color, material, extra)
	local parts = { part(size, v(0, size.Y / 2, 0), color, material) }
	for _, p in extra or {} do
		table.insert(parts, p)
	end
	return prop(name, size, parts)
end

local function ball(name, d, color, material)
	return prop(name, v(d, d, d), { part(v(d, d, d), v(0, d / 2, 0), color, material, BALL) })
end

-- Trunk and a round canopy, optional second smaller ball
local function roundTree(name, h, trunk, leaves, leafMaterial, second)
	local c = h * 0.55
	local parts = {
		post(h * 0.55, h * 0.1, v(0, h * 0.275, 0), trunk, M.Wood),
		part(v(c, c, c), v(0, h - c / 2, 0), leaves, leafMaterial or M.Grass, BALL),
	}
	if second then
		table.insert(
			parts,
			part(
				v(c * 0.7, c * 0.7, c * 0.7),
				v(c * 0.35, h - c * 0.75, c * 0.2),
				second,
				leafMaterial or M.Grass,
				BALL
			)
		)
	end
	return prop(name, v(c * 1.2, h, c * 1.2), parts)
end

-- Tall pine of stacked shrinking tiers
local function pine(name, h, trunk, leaves)
	local w = h * 0.45
	return prop(name, v(w, h, w), {
		post(h * 0.3, h * 0.08, v(0, h * 0.15, 0), trunk, M.Wood),
		part(v(w, h * 0.3, w), v(0, h * 0.4, 0), leaves, M.Grass),
		part(v(w * 0.7, h * 0.28, w * 0.7), v(0, h * 0.64, 0), leaves, M.Grass),
		part(v(w * 0.4, h * 0.22, w * 0.4), v(0, h * 0.87, 0), leaves, M.Grass),
	})
end

-- Plain shrine-style gate frame: two posts, a top beam with overhang and a lower tie beam, facing the road
local function frameGate(name, w, h, color, material, beam)
	return prop(name, v(w + 4, h + 1.5, 2), {
		post(h, 1.4, v(-w / 2, h / 2, 0), color, material),
		post(h, 1.4, v(w / 2, h / 2, 0), color, material),
		part(v(w + 4, 1.2, 1.8), v(0, h + 0.6, 0), beam or color, material),
		part(v(w + 1, 0.8, 1.2), v(0, h * 0.78, 0), color, material),
	})
end

-- Stone lantern: base, shaft, lit fire box, cap
local function stoneLantern(name, h, stone, glow)
	return prop(name, v(3, h, 3), {
		part(v(2.6, h * 0.12, 2.6), v(0, h * 0.06, 0), stone, M.Slate),
		post(h * 0.45, 1, v(0, h * 0.345, 0), stone, M.Slate),
		part(v(2, h * 0.2, 2), v(0, h * 0.67, 0), glow, M.Neon),
		part(v(3, h * 0.13, 3), v(0, h * 0.84, 0), stone, M.Slate),
		part(v(1, h * 0.1, 1), v(0, h * 0.95, 0), stone, M.Slate),
	}, { Glow = glow })
end

-- House: walls, an overhanging roof slab and ridge, a door and a window on the road face (-Z).
-- o = { WallMaterial?, RoofMaterial?, Trim?, Window?, WindowMaterial?, Tank? (rooftop water tank), Floors?, Glow? }
local function house(name, w, h, d, wall, roof, o)
	o = o or {}
	local wallM, roofM = o.WallMaterial or M.Plaster, o.RoofMaterial or M.Slate
	local window, windowM = o.Window or rgb(60, 80, 100), o.WindowMaterial or M.Glass
	local parts = {
		part(v(w, h, d), v(0, h / 2, 0), wall, wallM),
		part(v(w + 3, 1.2, d + 3), v(0, h + 0.6, 0), roof, roofM),
		part(v(w * 0.7, 1.6, d * 0.5), v(0, h + 2, 0), roof, roofM),
		part(v(w * 0.22, h * 0.55, 0.4), v(-w * 0.2, h * 0.275, -d / 2 - 0.2), o.Trim or rgb(80, 56, 36), M.Wood),
		part(v(w * 0.3, h * 0.2, 0.4), v(w * 0.2, h * 0.6, -d / 2 - 0.2), window, windowM),
	}
	local top = h + 2.8
	if o.Floors == 2 then -- a second, narrower storey under its own roof
		table.insert(parts, part(v(w * 0.8, h * 0.7, d * 0.8), v(0, h * 1.55, 0), wall, wallM))
		table.insert(parts, part(v(w * 0.8 + 3, 1.2, d * 0.8 + 3), v(0, h * 1.9 + 0.6, 0), roof, roofM))
		table.insert(parts, part(v(w * 0.6, h * 0.25, 0.4), v(0, h * 1.55, -d * 0.4 - 0.2), window, windowM))
		top = h * 1.9 + 1.2
	end
	if o.Tank then -- round rooftop water tank
		table.insert(parts, post(w * 0.22, w * 0.22, v(w * 0.3, top + w * 0.11, d * 0.2), o.Tank, M.Wood))
		top += w * 0.22
	end
	return prop(name, v(w + 3, top, d + 3), parts, { Glow = o.Glow })
end

-- Dome: a ball sunk to its equator, two round windows and a door on the road face
local function dome(name, d, color, window, door)
	return prop(name, v(d, d / 2, d), {
		part(v(d, d, d), v(0, 0, 0), color, M.SmoothPlastic, BALL),
		part(v(d * 0.25, d * 0.3, 0.6), v(0, d * 0.15, -d / 2 + 0.6), door, M.SmoothPlastic),
		part(v(d * 0.12, d * 0.12, d * 0.12), v(-d * 0.25, d * 0.3, -d * 0.38), window, M.Glass, BALL),
		part(v(d * 0.12, d * 0.12, d * 0.12), v(d * 0.25, d * 0.3, -d * 0.38), window, M.Glass, BALL),
	})
end

-- Layered rock: blocks of shrinking width, alternating two strata colours
local function strata(name, w, h, d, a, b, layers)
	local parts = {}
	for i = 1, layers do
		local k = 1 - (i - 1) * 0.12
		table.insert(
			parts,
			part(v(w * k, h / layers, d * k), v(0, h / layers * (i - 0.5), 0), i % 2 == 0 and b or a, M.Sandstone)
		)
	end
	return prop(name, v(w, h, d), parts)
end

-- Bare branching tree: trunk and slanted branches
local function deadTree(name, h, color, material)
	return prop(name, v(h * 0.6, h, h * 0.6), {
		post(h * 0.7, h * 0.08, v(0, h * 0.35, 0), color, material),
		part(v(h * 0.05, h * 0.4, h * 0.05), v(-h * 0.12, h * 0.75, 0), color, material, nil, CFrame.Angles(0, 0, 0.6)),
		part(v(h * 0.05, h * 0.35, h * 0.05), v(h * 0.13, h * 0.7, 0), color, material, nil, CFrame.Angles(0, 0, -0.7)),
		part(v(h * 0.04, h * 0.3, h * 0.04), v(0, h * 0.82, h * 0.1), color, material, nil, CFrame.Angles(0.6, 0, 0)),
	})
end

-- Cheap street-wall building for the City Blocks layer (3 parts): body, a window band, a lit shopfront strip
local function lowrise(name, w, h, d, o)
	return prop(name, v(w + 0.3, h, d + 0.4), {
		part(v(w, h, d), v(0, h / 2, 0), o.Body, M.Concrete),
		part(v(w + 0.3, h * 0.35, d + 0.3), v(0, h * 0.6, 0), o.Glass, M.Glass),
		part(v(w * 0.7, 1.4, 0.4), v(0, 4, -d / 2 - 0.2), o.Neon, M.Neon),
	})
end

-- Detailed glass tower (City landmarks, >= 25 parts): podium, setback tiers with glass window bands, corner fins,
-- a neon crown ring per tier, rooftop gear and an antenna. o = { Body, Trim, Glass, Neon, Tiers?, Floor?, MaxBands? }
local function tower(name, w, h, d, o)
	local parts = {}
	local function add(size, pos, color, material, shape)
		table.insert(parts, part(size, pos, color, material, shape))
	end
	local podium = math.max(4, h * 0.08)
	add(v(w + 4, podium, d + 4), v(0, podium / 2, 0), o.Trim, M.Concrete)
	add(v(w * 0.6, podium * 0.7, 0.4), v(0, podium * 0.35, -(d + 4) / 2 - 0.2), o.Glass, M.Glass) -- lobby
	local tiers = o.Tiers or 2
	local y, tw, td = podium, w, d
	for t = 1, tiers do
		local th = (h - podium) * (tiers == 1 and 1 or t == 1 and 0.62 or 0.38)
		add(v(tw, th, td), v(0, y + th / 2, 0), o.Body, M.Concrete)
		local bands = math.max(1, math.min(o.MaxBands or 10, math.floor(th / (o.Floor or 6))))
		local step = th / bands
		for b = 1, bands do
			add(v(tw + 0.3, step * 0.55, td + 0.3), v(0, y + step * (b - 0.5), 0), o.Glass, M.Glass)
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				add(v(1.2, th, 1.2), v(sx * tw / 2, y + th / 2, sz * td / 2), o.Trim, M.Concrete)
			end
		end
		y += th
		add(v(tw + 0.6, 1, td + 0.6), v(0, y, 0), o.Neon, M.Neon) -- crown ring
		if t < tiers then
			tw, td = tw * 0.7, td * 0.7
		end
	end
	add(v(tw * 0.25, 2.5, td * 0.25), v(-tw * 0.2, y + 1.75, td * 0.15), o.Trim, M.Metal)
	local mast = h * 0.12
	add(v(0.6, mast, 0.6), v(tw * 0.3, y + mast / 2, td * 0.3), rgb(160, 160, 170), M.Metal)
	add(v(1.4, 1.4, 1.4), v(tw * 0.3, y + mast, td * 0.3), o.Neon, M.Neon, BALL)
	return prop(name, v(w + 4, y + mast + 0.7, d + 4), parts, { Glow = o.Neon })
end

local function peak(name, size, rock, cap)
	return prop(name, size, {
		part(v(size.X, size.Y * 0.7, size.Z), v(0, size.Y * 0.35, 0), rock, M.Rock),
		part(v(size.X * 0.55, size.Y * 0.3, size.Z * 0.55), v(0, size.Y * 0.85, 0), cap, M.Grass),
	})
end

local function gate(color, material, glow, extra)
	local g = { Color = color, Material = material, Glow = glow }
	for k, value in extra or {} do
		g[k] = value
	end
	return g
end

local function patch(name, x, z, color, material)
	return { Name = name, Size = v(x, 0.2, z), Color = color, Material = material }
end

-- Rows of giant props shared by every non-City biome (wider than the City's street walls, so small props show between)
local function giants(props, spacing)
	return { Spacing = spacing or 70, Near = 28, Rows = 2, RowDepth = 90, Props = props }
end

-- Built-in particle textures only
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function particles(texture, color, o)
	return {
		Texture = texture,
		Color = color,
		Size = o.Size or 0.6,
		Lifetime = o.Lifetime or 4,
		Rate = o.Rate or 6,
		Speed = o.Speed or 2,
		Spread = o.Spread,
		Acceleration = o.Acceleration,
		LightEmission = o.LightEmission or 0,
		Transparency = o.Transparency,
	}
end

-- Palettes (spec References, hex codes per track)
local LEAF_GREEN, WOOD1, PLASTER1 = hex("3E7D3A"), hex("C9A36B"), hex("E8DCC0")
local BRIDGE_RED, CLIFF1, DIRT1 = hex("B23A2E"), hex("7C8C99"), hex("A07B52")
local SAND2, ROCK2, STRATA2, TILE2, SUNSET2 = hex("D9B98A"), hex("B8834F"), hex("8A5A3B"), hex("E6E1D3"), hex("F2A23A")
local SAND3, SEA3, WHITE3, ROOF3, DOCK3, PALM3 =
	hex("F3E2B3"), hex("2E8BC0"), hex("FFFFFF"), hex("C0392B"), hex("8B5A2B"), hex("4CAF50")
local NIGHT4, WISTERIA4, BLOSSOM4, DARKWOOD4, LANTERN4, MOON4 =
	hex("1B1A33"), hex("8E6BBF"), hex("C9A9E8"), hex("3B2A1E"), hex("F5E6A8"), hex("E8E8F0")
local NIGHT5, FOG5, PINK5, CYAN5, YELLOW5, CONCRETE5 =
	hex("120F1F"), hex("3A1F5C"), hex("FF2E88"), hex("2EE6FF"), hex("F2D64B"), hex("6B6B78")
local GLASS6, CONCRETE6, RED6, YELLOW6, ASPHALT6, PARK6 =
	hex("4A90D9"), hex("E6E9EE"), hex("D63A3A"), hex("F2C12E"), hex("2F3542"), hex("8FD18F")
local BLOSSOM7, VERMILION7, STONE7, ROOF7, WOOD7, SKY7 =
	hex("F7C6D9"), hex("E14B3B"), hex("9E9E9E"), hex("4F8F6F"), hex("6B4A2E"), hex("CDE7F7")
local GRASS8, ROCK8, RUIN8, CLOUD8, SKY8, FALL8 =
	hex("7CC36A"), hex("8C7A66"), hex("BFB7A8"), hex("FFFFFF"), hex("6FC3F0"), hex("3F8FD2")
local SAND9, TREE9, SKY9, MOON9, SHADOW9, ROCK9 =
	hex("F2F2EE"), hex("DADAD2"), hex("0A0A12"), hex("E9EEF5"), hex("8892A6"), hex("2E2E3A")
local SKY10, GRASS10, WATER10, DOME10, ROCK10, HAZE10 =
	hex("8FD18A"), hex("3FB59A"), hex("2E8B8B"), hex("F0F0E6"), hex("6E7F5A"), hex("B9E4A6")

-- Track 1: the carved cliff with 4 generic, unnamed stone faces (owner-approved 2026-10-28; no real likeness)
local function faceCliff()
	local parts = {
		part(v(64, 40, 15), v(0, 20, 1.5), CLIFF1, M.Rock),
		part(v(56, 10, 12), v(0, 45, 3), CLIFF1, M.Rock),
		part(v(40, 4, 10), v(0, 52, 4), LEAF_GREEN, M.Grass),
	}
	for i = 1, 4 do
		local x = -24 + (i - 1) * 16
		table.insert(parts, part(v(10, 12, 3), v(x, 28, -7.5), hex("8A9AA6"), M.Rock)) -- face
		table.insert(parts, part(v(10, 1.4, 1.5), v(x, 32, -9.25), hex("6B7A86"), M.Rock)) -- brow
		table.insert(parts, part(v(2, 3, 1.5), v(x, 28, -9.25), hex("6B7A86"), M.Rock)) -- nose
	end
	return prop("StoneFaceCliff", v(64, 54, 20), parts)
end

-- Track 2: square tiled ring with corner posts and steps; no banner, no text
local function tileRing()
	local parts = {
		part(v(40, 3, 40), v(0, 1.5, 0), TILE2, M.Marble),
		part(v(42, 0.6, 42), v(0, 3.3, 0), hex("CFC8B6"), M.Marble),
		part(v(12, 1.5, 4), v(0, 0.75, -22), TILE2, M.Marble),
	}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(parts, part(v(2, 6, 2), v(sx * 20, 6, sz * 20), hex("CFC8B6"), M.Marble))
		end
	end
	return prop("TileRing", v(42, 9, 44), parts, { Glow = SUNSET2 })
end

-- Track 5: concrete block with stacked abstract signboards (no text)
local function signTower()
	local parts = { part(v(20, 44, 18), v(0, 22, 0), CONCRETE5, M.Concrete) }
	for i, c in { PINK5, CYAN5, YELLOW5, PINK5 } do
		table.insert(parts, part(v(16, 4, 0.6), v(0, 8 + i * 8, -9.3), c, M.Neon))
	end
	table.insert(parts, part(v(20.4, 0.8, 18.4), v(0, 44.4, 0), CYAN5, M.Neon))
	return prop("SignTower", v(20, 45, 19), parts, { Glow = PINK5 })
end

-- Track 7: a short tunnel of red gates running along the road (gates spaced along X, the road direction)
local function gateTunnel()
	local parts = {}
	for i = -2, 2 do
		local x = i * 4
		table.insert(parts, post(11, 1.2, v(x, 5.5, -4), VERMILION7, M.Wood))
		table.insert(parts, post(11, 1.2, v(x, 5.5, 4), VERMILION7, M.Wood))
		table.insert(parts, part(v(1.6, 1.2, 12), v(x, 11.6, 0), rgb(40, 34, 32), M.Wood))
		table.insert(parts, part(v(1, 0.8, 9), v(x, 8.6, 0), VERMILION7, M.Wood))
	end
	return prop("GateTunnel", v(18, 12.2, 12), parts, { Glow = rgb(255, 200, 150) })
end

-- Track 7: stone stairs with a small gate on top
local function stoneStairs()
	local parts = {}
	for i = 0, 4 do
		table.insert(parts, part(v(12, 2, 20 - i * 4), v(0, 1 + i * 2, i * 2), STONE7, M.Slate))
	end
	for _, p in frameGate("Top", 6, 8, VERMILION7, M.Wood).Parts do
		local q = table.clone(p)
		q.Pos = p.Pos + v(0, 10, 8)
		table.insert(parts, q)
	end
	return prop("StoneStairs", v(12, 19.5, 20), parts)
end

-- Track 6: boxy generic training robot
local function trainingRobot()
	local grey, dark = hex("8A94A4"), hex("444C5A")
	return prop("TrainingRobot", v(20, 25, 8), {
		part(v(4, 10, 4), v(-4, 5, 0), dark, M.Metal),
		part(v(4, 10, 4), v(4, 5, 0), dark, M.Metal),
		part(v(14, 10, 8), v(0, 15, 0), grey, M.Metal),
		part(v(3, 9, 3), v(-8.5, 15, 0), dark, M.Metal),
		part(v(3, 9, 3), v(8.5, 15, 0), dark, M.Metal),
		part(v(7, 5, 6), v(0, 22.5, 0), grey, M.Metal),
		part(v(5, 1.2, 0.4), v(0, 23, -3.2), YELLOW6, M.Neon),
	})
end

local function domeHouse(name, d)
	return dome(name, d, DOME10, hex("2E6B6B"), hex("3F6E4F"))
end

local paperLantern = prop("PaperLantern", v(2.4, 9, 2.4), {
	post(7, 0.5, v(0, 3.5, 0), DIRT1, M.Wood),
	part(v(2.4, 2.8, 2.4), v(0, 7.6, 0), BRIDGE_RED, M.Neon, BALL),
})

local wisteriaTree = prop("WisteriaTree", v(14, 18, 14), {
	post(10, 1.4, v(0, 5, 0), DARKWOOD4, M.Wood),
	part(v(14, 8, 14), v(0, 13, 0), WISTERIA4, M.Grass, BALL),
	part(v(1.5, 6, 1.5), v(-4, 8, -4), BLOSSOM4, M.Grass),
	part(v(1.5, 5, 1.5), v(4, 8.5, -3), WISTERIA4, M.Grass),
	part(v(1.5, 6, 1.5), v(3, 8, 4), BLOSSOM4, M.Grass),
})

local ballTree = prop("BallTree", v(7, 20.5, 7), {
	post(14, 0.8, v(0, 7, 0), hex("7B6A4E"), M.Wood),
	part(v(7, 7, 7), v(0, 17, 0), GRASS10, M.Grass, BALL),
	part(v(3, 3, 3), v(2.5, 11, 0), hex("4FC9A8"), M.Grass, BALL),
})

local LightingConfig = require(script.Parent.Parent.LightingConfig)

-- The LightingConfig baseline as an Atmosphere profile (spec 5.2), with `overrides` merged in one level deep.
-- Zone 0 (the plaza) uses Atmosphere() unchanged.
local function atmosphere(overrides)
	local effects = {}
	for _, e in LightingConfig.Effects do
		effects[e[2]] = table.clone(e[3])
	end
	local light = {}
	for _, name in
		{
			"ClockTime",
			"Brightness",
			"Ambient",
			"OutdoorAmbient",
			"ExposureCompensation",
			"EnvironmentDiffuseScale",
			"EnvironmentSpecularScale",
		}
	do
		light[name] = LightingConfig.Lighting[name]
	end
	local profile = {
		Lighting = light,
		Atmosphere = effects.Atmosphere,
		Grade = effects.Grade,
		Bloom = effects.Bloom,
		SunRays = effects.SunRays,
	}
	for group, values in overrides or {} do
		if type(values) == "table" and type(profile[group]) == "table" then
			for k, value in values do
				profile[group][k] = value
			end
		else
			profile[group] = values
		end
	end
	return profile
end

return {
	M = M,
	hex = hex,
	rgb = rgb,
	v = v,
	BALL = BALL,
	CYL = CYL,
	UP = UP,
	FACE = FACE,
	part = part,
	post = post,
	prop = prop,
	block = block,
	ball = ball,
	roundTree = roundTree,
	pine = pine,
	frameGate = frameGate,
	stoneLantern = stoneLantern,
	house = house,
	dome = dome,
	strata = strata,
	deadTree = deadTree,
	lowrise = lowrise,
	tower = tower,
	peak = peak,
	gate = gate,
	patch = patch,
	giants = giants,
	SPARKLE = SPARKLE,
	SMOKE = SMOKE,
	particles = particles,
	LEAF_GREEN = LEAF_GREEN,
	WOOD1 = WOOD1,
	PLASTER1 = PLASTER1,
	BRIDGE_RED = BRIDGE_RED,
	CLIFF1 = CLIFF1,
	DIRT1 = DIRT1,
	SAND2 = SAND2,
	ROCK2 = ROCK2,
	STRATA2 = STRATA2,
	TILE2 = TILE2,
	SUNSET2 = SUNSET2,
	SAND3 = SAND3,
	SEA3 = SEA3,
	WHITE3 = WHITE3,
	ROOF3 = ROOF3,
	DOCK3 = DOCK3,
	PALM3 = PALM3,
	NIGHT4 = NIGHT4,
	WISTERIA4 = WISTERIA4,
	BLOSSOM4 = BLOSSOM4,
	DARKWOOD4 = DARKWOOD4,
	LANTERN4 = LANTERN4,
	MOON4 = MOON4,
	NIGHT5 = NIGHT5,
	FOG5 = FOG5,
	PINK5 = PINK5,
	CYAN5 = CYAN5,
	YELLOW5 = YELLOW5,
	CONCRETE5 = CONCRETE5,
	GLASS6 = GLASS6,
	CONCRETE6 = CONCRETE6,
	RED6 = RED6,
	YELLOW6 = YELLOW6,
	ASPHALT6 = ASPHALT6,
	PARK6 = PARK6,
	BLOSSOM7 = BLOSSOM7,
	VERMILION7 = VERMILION7,
	STONE7 = STONE7,
	ROOF7 = ROOF7,
	WOOD7 = WOOD7,
	SKY7 = SKY7,
	GRASS8 = GRASS8,
	ROCK8 = ROCK8,
	RUIN8 = RUIN8,
	CLOUD8 = CLOUD8,
	SKY8 = SKY8,
	FALL8 = FALL8,
	SAND9 = SAND9,
	TREE9 = TREE9,
	SKY9 = SKY9,
	MOON9 = MOON9,
	SHADOW9 = SHADOW9,
	ROCK9 = ROCK9,
	SKY10 = SKY10,
	GRASS10 = GRASS10,
	WATER10 = WATER10,
	DOME10 = DOME10,
	ROCK10 = ROCK10,
	HAZE10 = HAZE10,
	faceCliff = faceCliff,
	tileRing = tileRing,
	signTower = signTower,
	gateTunnel = gateTunnel,
	stoneStairs = stoneStairs,
	trainingRobot = trainingRobot,
	domeHouse = domeHouse,
	paperLantern = paperLantern,
	wisteriaTree = wisteriaTree,
	ballTree = ballTree,
	Atmosphere = atmosphere,
}
