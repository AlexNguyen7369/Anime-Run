--!nonstrict
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

return {
	-- Track 1: forest village, wooden rooftops with round water tanks, red bridges over a river, training posts,
	-- a cliff of 4 generic stone faces. No biome gate: the plaza torii is Track 1's gate (owner 2026-10-30).
	Speedway = {
		DisplayName = "Leafwind Village",
		Ground = { Color = LEAF_GREEN, Material = M.Grass },
		Sky = { Color = hex("87CEEB") },
		Gate = gate(WOOD1, M.Wood, nil, { Skip = true }),
		Rhythm = {
			Every = 4,
			Offset = 10,
			Props = {
				prop("TrainingPosts", v(8, 6, 3), {
					post(5, 1.2, v(-3, 2.5, 0), WOOD1, M.Wood),
					post(6, 1.2, v(0, 3, 0), WOOD1, M.Wood),
					post(4.5, 1.2, v(3, 2.25, 0), WOOD1, M.Wood),
					part(v(8, 0.4, 0.4), v(0, 3.6, -0.7), DIRT1, M.Fabric),
				}),
				paperLantern,
				block("WoodFence", v(10, 3.4, 0.8), WOOD1, M.WoodPlanks, {
					part(v(10, 0.4, 0.8), v(0, 3.2, 0), DIRT1, M.Wood),
				}),
				pine("TallPine", 24, hex("6B4A2E"), hex("2C5E2E")),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				house(
					"VillageHouse",
					20,
					12,
					16,
					PLASTER1,
					hex("2F6B3A"),
					{ Trim = WOOD1, Tank = WOOD1, Glow = rgb(255, 200, 140) }
				),
				prop("FoodStall", v(15, 11.8, 8), {
					part(v(14, 3.5, 6), v(0, 1.75, 0), WOOD1, M.WoodPlanks),
					post(6, 0.6, v(-6.5, 6, 2.5), WOOD1, M.Wood),
					post(6, 0.6, v(6.5, 6, 2.5), WOOD1, M.Wood),
					part(v(15, 0.8, 8), v(0, 9.4, 0.5), BRIDGE_RED, M.Fabric),
					part(v(13, 2, 0.2), v(0, 7.8, -3.4), PLASTER1, M.Fabric), -- curtain, no text
					part(v(5, 2, 0.4), v(0, 10.8, -3), hex("2E2E2E"), M.Wood), -- blank sign board
				}, { Glow = rgb(255, 190, 120) }),
				prop("RedBridge", v(34, 7, 12), {
					part(v(30, 1, 8), v(0, 3, 0), BRIDGE_RED, M.WoodPlanks),
					part(v(14, 1, 8), v(0, 4, 0), BRIDGE_RED, M.WoodPlanks),
					part(v(30, 0.6, 0.6), v(0, 6.5, -4), BRIDGE_RED, M.Wood),
					part(v(30, 0.6, 0.6), v(0, 6.5, 4), BRIDGE_RED, M.Wood),
					post(6, 1, v(-14, 3, -4), BRIDGE_RED, M.Wood),
					post(6, 1, v(14, 3, -4), BRIDGE_RED, M.Wood),
					post(6, 1, v(-14, 3, 4), BRIDGE_RED, M.Wood),
					post(6, 1, v(14, 3, 4), BRIDGE_RED, M.Wood),
					part(v(34, 0.3, 12), v(0, 0.15, 0), hex("4F8FBF"), M.Glass), -- the river under it
				}, { Glow = rgb(255, 170, 90) }),
				house(
					"TallHouse",
					18,
					10,
					16,
					PLASTER1,
					BRIDGE_RED,
					{ Trim = WOOD1, Floors = 2, Tank = WOOD1, Glow = rgb(255, 200, 140) }
				),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = { faceCliff(), peak("ForestHill", v(70, 40, 20), hex("4A6E3E"), LEAF_GREEN) },
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"TallPine",
				"TrainingPosts",
				roundTree("LeafTree", 16, hex("6B4A2E"), hex("4F9A44")),
				block("Bush", v(6, 4, 6), hex("356B32"), M.Grass),
				"PaperLantern",
				block("Rock", v(5, 3, 4), CLIFF1, M.Slate),
			},
			Patches = {
				patch("DirtPath", 30, 8, DIRT1, M.Ground),
				patch("Stream", 26, 6, hex("4F8FBF"), M.Glass),
				patch("Clover", 18, 14, hex("57A24C"), M.Grass),
			},
		},
		Blocks = giants({
			pine("GiantPine", 70, hex("6B4A2E"), hex("2C5E2E")),
			house("ElderHouse", 30, 16, 26, PLASTER1, hex("2F6B3A"), { Trim = WOOD1, Floors = 2, Tank = WOOD1 }),
			prop("WatchTower", v(16, 46, 16), {
				post(40, 1.6, v(-5, 20, -5), WOOD1, M.Wood),
				post(40, 1.6, v(5, 20, -5), WOOD1, M.Wood),
				post(40, 1.6, v(-5, 20, 5), WOOD1, M.Wood),
				post(40, 1.6, v(5, 20, 5), WOOD1, M.Wood),
				part(v(14, 1.5, 14), v(0, 40, 0), WOOD1, M.WoodPlanks),
				part(v(16, 2, 16), v(0, 45, 0), BRIDGE_RED, M.Slate),
			}),
		}),
		Particles = particles(
			SPARKLE,
			hex("8FCB5A"),
			{ Size = 0.7, Lifetime = 5, Speed = 1.5, Acceleration = v(0.5, -1, 0) }
		),
	},

	-- Track 2: rocky plateaus with layered strata, craters, a stone tiled ring, floating boulders, small domed huts
	Forest = {
		DisplayName = "Tournament Wasteland",
		Ground = { Color = SAND2, Material = M.Sandstone },
		Sky = { Color = hex("7FB8E0") },
		Gate = gate(ROCK2, M.Rock, SUNSET2),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				strata("RockSpire", 4, 14, 4, ROCK2, STRATA2, 3),
				block("Boulder", v(6, 4, 5), ROCK2, M.Rock),
				deadTree("DeadShrub", 6, hex("7A5A3E"), M.Wood),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				tileRing(),
				strata("Mesa", 30, 34, 24, ROCK2, STRATA2, 5),
				prop("CapsuleHut", v(14, 7, 14), {
					part(v(14, 8, 14), v(0, 3, 0), hex("F2EFE6"), M.SmoothPlastic, BALL),
					part(v(4, 5, 0.6), v(0, 2.5, -6.6), hex("5A6878"), M.SmoothPlastic),
					part(v(14.4, 0.8, 14.4), v(0, 3, 0), SUNSET2, M.SmoothPlastic),
				}, { Glow = SUNSET2 }),
				prop("Crater", v(30, 3, 30), {
					part(v(0.4, 30, 30), v(0, 0.2, 0), STRATA2, M.Ground, CYL, UP),
					part(v(30, 2, 6), v(0, 1, -12), ROCK2, M.Rock),
					part(v(30, 2, 6), v(0, 1, 12), ROCK2, M.Rock),
					part(v(6, 2.5, 18), v(-12, 1.25, 0), ROCK2, M.Rock),
					part(v(6, 3, 18), v(12, 1.5, 0), ROCK2, M.Rock),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				strata("MesaPillar", 26, 70, 22, ROCK2, STRATA2, 6),
				prop("FloatingBoulder", v(20, 50, 18), {
					part(v(20, 24, 18), v(0, 12, 0), STRATA2, M.Rock),
					part(v(16, 12, 14), v(0, 40, 0), ROCK2, M.Rock, nil, CFrame.Angles(0.3, 0.4, 0.2)),
					part(v(10, 6, 9), v(4, 46, 3), STRATA2, M.Rock),
				}, { Tag = "BiomeBob" }),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 170,
			Props = {
				"Boulder",
				"DeadShrub",
				block("RockShard", v(3, 8, 3), STRATA2, M.Rock),
				"RockSpire",
				block("FlatRock", v(8, 2, 6), ROCK2, M.Rock),
			},
			Patches = {
				patch("Scorch", 18, 14, hex("4A3828"), M.Ground),
				patch("CrackedEarth", 26, 20, hex("C49E6C"), M.Sandstone),
				patch("Pebbles", 14, 10, DIRT1, M.Pebble),
			},
		},
		Blocks = giants({
			strata("GiantMesa", 50, 80, 40, ROCK2, STRATA2, 6),
			prop("GiantSpire", v(16, 90, 16), {
				part(v(16, 40, 16), v(0, 20, 0), ROCK2, M.Rock),
				part(v(11, 30, 11), v(0, 55, 0), STRATA2, M.Rock),
				part(v(6, 20, 6), v(0, 80, 0), ROCK2, M.Rock),
			}),
			prop("HoveringRock", v(30, 70, 30), {
				part(v(30, 6, 30), v(0, 3, 0), STRATA2, M.Rock),
				part(v(26, 16, 22), v(0, 58, 0), ROCK2, M.Rock, nil, CFrame.Angles(0.2, 0.6, 0.1)),
			}, { Tag = "BiomeBob" }),
		}),
		Particles = particles(SMOKE, SAND2, { Size = 3, Lifetime = 4, Rate = 4, Speed = 2, Transparency = 0.5 }),
	},

	-- Track 3: sandy island, plank docks, a moored caravel with a plain sail (no flag, no figurehead), palms,
	-- a windmill, white houses with red and blue roofs
	Docks = {
		DisplayName = "Pirate Harbor Isle",
		Ground = { Color = SAND3, Material = M.Sand },
		Sky = { Color = hex("7FD0F5") },
		Gate = gate(DOCK3, M.WoodPlanks),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				prop("Palm", v(10, 17, 10), {
					post(8, 1, v(0, 4, 0), hex("8A6A44"), M.Wood),
					part(v(1, 8, 1), v(0.8, 11, 0), hex("8A6A44"), M.Wood, nil, CFrame.Angles(0, 0, -0.2)),
					part(v(10, 0.6, 3), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0, 0, -0.3)),
					part(v(3, 0.6, 10), v(1.6, 15.5, 0), PALM3, M.Grass, nil, CFrame.Angles(0.3, 0, 0)),
				}),
				prop("Barrel", v(3.2, 4, 3.2), {
					post(4, 3, v(0, 2, 0), DOCK3, M.Wood),
					post(0.4, 3.2, v(0, 1, 0), rgb(70, 70, 70), M.Metal),
					post(0.4, 3.2, v(0, 3, 0), rgb(70, 70, 70), M.Metal),
				}),
				block("CrateStack", v(4, 7, 4), hex("A9783F"), M.WoodPlanks, {
					part(v(3, 3, 3), v(0.3, 5.5, 0.2), hex("C29055"), M.WoodPlanks),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				prop("Caravel", v(40, 29, 18), {
					part(v(36, 6, 10), v(0, 3, 0), DOCK3, M.WoodPlanks),
					part(v(10, 3, 8), v(12, 7.5, 0), hex("6E4421"), M.WoodPlanks),
					part(v(38, 1, 12), v(0, 6.5, 0), hex("A7774A"), M.WoodPlanks),
					post(22, 1, v(-6, 17, 0), hex("6E4421"), M.Wood),
					post(18, 1, v(8, 15, 0), hex("6E4421"), M.Wood),
					part(v(0.4, 12, 10), v(-6, 20, 0), WHITE3, M.Fabric), -- plain sail
					part(v(0.4, 9, 8), v(8, 17, 0), WHITE3, M.Fabric),
					part(v(40, 0.3, 18), v(0, 0.15, 0), SEA3, M.Glass), -- the water it rests in
				}, { Tag = "BiomeBob", Glow = rgb(255, 210, 140) }),
				prop("Windmill", v(22, 24, 12), {
					part(v(9, 20, 9), v(0, 10, 0), WHITE3, M.Plaster),
					part(v(11, 4, 11), v(0, 22, 0), ROOF3, M.Slate),
					part(v(2, 22, 0.6), v(0, 12, -5.2), hex("B08A5A"), M.WoodPlanks),
					part(v(22, 2, 0.6), v(0, 12, -5.2), hex("B08A5A"), M.WoodPlanks),
				}, { Glow = rgb(255, 210, 140) }),
				house(
					"HarborHouse",
					16,
					10,
					14,
					WHITE3,
					ROOF3,
					{ Trim = DOCK3, Window = SEA3, Glow = rgb(255, 210, 140) }
				),
				house("BlueRoofHouse", 14, 9, 12, WHITE3, hex("2E6FB0"), { Trim = DOCK3, Window = SEA3, Floors = 2 }),
				prop("Pier", v(14, 3, 38), {
					part(v(10, 1, 36), v(0, 2.5, 0), DOCK3, M.WoodPlanks),
					post(4, 1, v(-4.5, 1.5, -16), hex("6E4421"), M.Wood),
					post(4, 1, v(4.5, 1.5, -16), hex("6E4421"), M.Wood),
					post(4, 1, v(-4.5, 1.5, 16), hex("6E4421"), M.Wood),
					post(4, 1, v(4.5, 1.5, 16), hex("6E4421"), M.Wood),
					part(v(14, 0.3, 38), v(0, 0.15, 0), SEA3, M.Glass),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("SeaIslet", v(80, 18, 22), {
					part(v(80, 0.4, 22), v(0, 0.2, 0), SEA3, M.Glass), -- open sea
					part(v(30, 6, 18), v(0, 0, 0), SAND3, M.Sand, BALL),
					post(14, 1.4, v(2, 9, 0), hex("8A6A44"), M.Wood),
					part(v(14, 1, 4), v(2, 16.5, 0), PALM3, M.Grass),
					part(v(4, 1, 14), v(2, 16.5, 0), PALM3, M.Grass),
				}),
				prop("Lighthouse", v(12, 47, 12), {
					part(v(12, 4, 12), v(0, 2, 0), hex("8C8C8C"), M.Rock),
					post(36, 8, v(0, 22, 0), WHITE3, M.Plaster),
					post(5, 8.4, v(0, 18, 0), ROOF3, M.Plaster),
					post(5, 8.4, v(0, 30, 0), ROOF3, M.Plaster),
					part(v(6, 5, 6), v(0, 42.5, 0), hex("FFE8A0"), M.Neon),
					part(v(8, 2, 8), v(0, 46, 0), ROOF3, M.Metal),
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"Palm",
				"Barrel",
				prop("Buoy", v(3.1, 3, 3.1), {
					part(v(3, 3, 3), v(0, 1.5, 0), ROOF3, M.SmoothPlastic, BALL),
					part(v(3.1, 1, 3.1), v(0, 1.5, 0), WHITE3, M.SmoothPlastic),
				}),
				prop("RopeCoil", v(3, 1, 3), { post(1, 3, v(0, 0.5, 0), hex("C9AE7C"), M.Fabric) }),
				block("FishingNet", v(8, 4, 1), hex("6B5A3E"), M.Fabric),
				"CrateStack",
			},
			Patches = {
				patch("TidePool", 22, 14, SEA3, M.Glass),
				patch("WetSand", 26, 16, hex("D9C48E"), M.Sand),
				patch("Shells", 12, 10, hex("F7F0E0"), M.Pebble),
			},
		},
		Blocks = giants({
			prop("GiantPalm", v(24, 46, 24), {
				post(24, 3, v(0, 12, 0), hex("8A6A44"), M.Wood),
				part(v(2.6, 20, 2.6), v(2, 33, 0), hex("8A6A44"), M.Wood, nil, CFrame.Angles(0, 0, -0.2)),
				part(v(24, 1.2, 6), v(4, 44, 0), PALM3, M.Grass, nil, CFrame.Angles(0, 0, -0.3)),
				part(v(6, 1.2, 24), v(4, 44, 0), PALM3, M.Grass, nil, CFrame.Angles(0.3, 0, 0)),
			}),
			house("Warehouse", 40, 18, 28, hex("D8CDB4"), ROOF3, { WallMaterial = M.WoodPlanks, Trim = DOCK3 }),
			prop("DockCrane", v(10, 36, 30), {
				post(34, 3, v(0, 17, 6), hex("6E4421"), M.Wood),
				part(v(2, 2, 28), v(0, 34, -6), hex("6E4421"), M.Wood),
				part(v(0.4, 12, 0.4), v(0, 28, -18), hex("C9AE7C"), M.Fabric),
				part(v(4, 4, 4), v(0, 20, -18), hex("A9783F"), M.WoodPlanks),
			}),
		}),
		Particles = particles(SPARKLE, rgb(230, 248, 255), {
			Size = 0.5,
			Lifetime = 3,
			Speed = 3,
			Acceleration = v(0, -2, 0),
			LightEmission = 0.4,
		}),
	},

	-- Track 4 (night): Taisho-style wooden street, wisteria groves and arches, lit stone lanterns, a full moon.
	-- Tints only its own props and ground (never global Lighting).
	Suburb = {
		DisplayName = "Wisteria Night Mountain",
		Ground = { Color = NIGHT4, Material = M.Grass },
		Sky = { Color = hex("15142B") },
		Gate = gate(DARKWOOD4, M.Wood, LANTERN4),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				stoneLantern("StoneLantern", 7, rgb(110, 108, 120), LANTERN4),
				wisteriaTree,
				block("WoodFence", v(10, 3.4, 0.8), DARKWOOD4, M.WoodPlanks, {
					part(v(10, 0.4, 0.8), v(0, 3.2, 0), hex("2A1E15"), M.Wood),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 20,
			Props = {
				house("TaishoShop", 18, 10, 14, DARKWOOD4, hex("2B2B3A"), {
					WallMaterial = M.WoodPlanks,
					Trim = hex("1E140C"),
					Window = LANTERN4,
					WindowMaterial = M.Neon, -- glowing paper doors
					Floors = 2,
					Glow = LANTERN4,
				}),
				prop("WisteriaArch", v(20, 16, 6), {
					post(14, 1.2, v(-8, 7, 0), DARKWOOD4, M.Wood),
					post(14, 1.2, v(8, 7, 0), DARKWOOD4, M.Wood),
					part(v(20, 3, 6), v(0, 14.5, 0), WISTERIA4, M.Grass),
					part(v(1.4, 6, 1.4), v(-5, 10, 0), BLOSSOM4, M.Grass),
					part(v(1.4, 7, 1.4), v(0, 9.5, 0), WISTERIA4, M.Grass),
					part(v(1.4, 6, 1.4), v(5, 10, 0), BLOSSOM4, M.Grass),
				}, { Glow = BLOSSOM4 }),
				frameGate("PlainShrineGate", 10, 12, hex("6B4A2E"), M.Wood),
				prop("StoneStair", v(14, 8, 16), {
					part(v(14, 2, 16), v(0, 1, 0), rgb(90, 88, 100), M.Slate),
					part(v(14, 2, 12), v(0, 3, 2), rgb(90, 88, 100), M.Slate),
					part(v(14, 2, 8), v(0, 5, 4), rgb(90, 88, 100), M.Slate),
					part(v(14, 2, 4), v(0, 7, 6), rgb(90, 88, 100), M.Slate),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("MoonPeak", v(60, 105, 20), {
					part(v(60, 36, 20), v(0, 18, 0), hex("26243F"), M.Rock),
					part(v(34, 20, 14), v(0, 46, 0), WISTERIA4, M.Grass),
					part(v(1, 18, 18), v(0, 96, 8), MOON4, M.Neon, CYL, FACE), -- full moon disk
				}),
				prop("WisteriaHill", v(56, 40, 20), {
					part(v(56, 22, 20), v(0, 11, 0), hex("26243F"), M.Rock),
					part(v(40, 24, 20), v(0, 28, 0), WISTERIA4, M.Grass, BALL),
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"WisteriaTree",
				"StoneLantern",
				pine("DarkPine", 22, DARKWOOD4, hex("1F3A2E")),
				prop("HangingLantern", v(2.4, 8, 2.4), {
					post(6, 0.4, v(0, 3, 0), DARKWOOD4, M.Wood),
					part(v(2, 2.6, 2), v(0, 6.5, 0), hex("F2B66B"), M.Neon, BALL),
				}),
				block("Bush", v(6, 4, 6), hex("2A2848"), M.Grass),
			},
			Patches = {
				patch("PetalCarpet", 22, 16, BLOSSOM4, M.Grass),
				patch("StonePath", 26, 6, rgb(80, 78, 92), M.Slate),
				patch("DarkMoss", 18, 14, hex("232E2A"), M.Grass),
			},
		},
		Blocks = giants({
			prop("GiantWisteria", v(40, 54, 40), {
				post(30, 4, v(0, 15, 0), DARKWOOD4, M.Wood),
				part(v(40, 24, 40), v(0, 42, 0), WISTERIA4, M.Grass, BALL),
				part(v(4, 16, 4), v(-12, 26, -10), BLOSSOM4, M.Grass),
				part(v(4, 14, 4), v(12, 27, 8), BLOSSOM4, M.Grass),
			}),
			pine("DarkGiantPine", 70, DARKWOOD4, hex("1F3A2E")),
			house("TaishoHall", 30, 14, 24, DARKWOOD4, hex("2B2B3A"), {
				WallMaterial = M.WoodPlanks,
				Window = LANTERN4,
				WindowMaterial = M.Neon,
				Floors = 2,
			}),
		}),
		Particles = particles(SPARKLE, BLOSSOM4, {
			Size = 0.7,
			Lifetime = 6,
			Speed = 1,
			Acceleration = v(0.4, -1.2, 0),
			LightEmission = 0.5,
		}),
	},

	-- Track 5 (night): neon avenue, a scramble crossing, an overpass, a temple school on a hill, purple fog.
	-- Signs are abstract neon shapes with no text. Tints only its own props and ground.
	PirateCoast = {
		DisplayName = "Neon Cursed City",
		Ground = { Color = NIGHT5, Material = M.Asphalt },
		Sky = { Color = FOG5 },
		Gate = gate(CONCRETE5, M.Concrete, PINK5),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				prop("TrafficLight", v(2, 14, 2), {
					post(14, 0.6, v(0, 7, 0), rgb(40, 40, 48), M.Metal),
					part(v(1.4, 4, 1.4), v(0, 12, -0.6), rgb(30, 30, 36), M.Metal),
					part(v(1, 1, 0.3), v(0, 13, -1.4), hex("FF4040"), M.Neon),
					part(v(1, 1, 0.3), v(0, 11, -1.4), hex("40FF80"), M.Neon),
				}),
				prop("NeonSign", v(6, 12, 1), {
					post(12, 0.5, v(-2.5, 6, 0), CONCRETE5, M.Metal),
					part(v(6, 3, 0.6), v(0, 10, 0), PINK5, M.Neon),
					part(v(4, 1, 0.7), v(0, 7.5, 0), CYAN5, M.Neon),
				}),
				block("VendingMachine", v(3, 6, 2.4), hex("E8E8F0"), M.SmoothPlastic, {
					part(v(2.4, 3.4, 0.2), v(0, 3.8, -1.25), CYAN5, M.Neon),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 18,
			Props = {
				signTower(),
				prop("VideoScreen", v(24, 32, 16), {
					part(v(24, 30, 16), v(0, 15, 0), hex("2A2A34"), M.Concrete),
					part(v(18, 12, 0.6), v(0, 22, -8.3), hex("3C2A7A"), M.Neon),
					part(v(6, 6, 0.7), v(-4, 22, -8.4), PINK5, M.Neon),
					part(v(5, 8, 0.7), v(5, 21, -8.4), CYAN5, M.Neon),
					part(v(24.4, 2, 16.4), v(0, 31, 0), rgb(50, 50, 60), M.Concrete),
				}, { Glow = CYAN5 }),
				prop("Overpass", v(40, 18, 10), {
					part(v(4, 14, 4), v(-16, 7, 0), CONCRETE5, M.Concrete),
					part(v(4, 14, 4), v(16, 7, 0), CONCRETE5, M.Concrete),
					part(v(40, 3, 10), v(0, 15.5, 0), CONCRETE5, M.Concrete),
					part(v(40, 1, 0.6), v(0, 17.5, -4.7), YELLOW5, M.Neon),
				}, { Glow = YELLOW5 }),
				prop("TempleGate", v(20, 15, 9), {
					post(12, 1.4, v(-6, 6, 0), hex("4A2E22"), M.Wood),
					post(12, 1.4, v(6, 6, 0), hex("4A2E22"), M.Wood),
					part(v(18, 1.5, 8), v(0, 12.75, 0), hex("2A2A3A"), M.Slate),
					part(v(14, 1.5, 6), v(0, 14.25, 0), hex("2A2A3A"), M.Slate),
					part(v(20, 0.6, 9), v(0, 12, 0), hex("4A2E22"), M.Wood),
				}, { Glow = rgb(255, 180, 120) }),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("TempleHill", v(60, 37, 22), {
					part(v(60, 22, 20), v(0, 11, 1), hex("1E1A2E"), M.Rock),
					part(v(24, 10, 12), v(0, 27, 1), hex("4A2E22"), M.WoodPlanks),
					part(v(30, 2, 18), v(0, 33, 1), hex("2A2A3A"), M.Slate),
					part(v(20, 3, 10), v(0, 35.5, 1), hex("2A2A3A"), M.Slate),
					part(v(10, 22, 1), v(0, 11, -9.5), rgb(70, 66, 80), M.Slate), -- stairs up the hill
				}),
				prop("NeonSkyline", v(60, 60.5, 21), {
					part(v(18, 60, 18), v(-20, 30, 0), hex("1E1C2A"), M.Concrete),
					part(v(16, 44, 16), v(0, 22, 0), hex("24222F"), M.Concrete),
					part(v(18, 52, 18), v(20, 26, 0), hex("1E1C2A"), M.Concrete),
					part(v(18.4, 1, 18.4), v(-20, 60, 0), PINK5, M.Neon),
					part(v(16.4, 1, 16.4), v(0, 44, 0), CYAN5, M.Neon),
					part(v(18.4, 1, 18.4), v(20, 52, 0), YELLOW5, M.Neon),
					part(v(60, 30, 1), v(0, 30, 10), FOG5, M.SmoothPlastic), -- local fog backdrop
				}),
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
			},
			Patches = {
				patch("Crosswalk", 22, 6, hex("E8E8EE"), M.Concrete),
				patch("NeonPuddle", 14, 10, PINK5, M.Glass),
				patch("CyanPuddle", 12, 9, CYAN5, M.Glass),
			},
		},
		Blocks = giants({
			prop("GiantSignTower", v(30, 80.5, 30.6), {
				part(v(30, 80, 30), v(0, 40, 0), hex("2A2A34"), M.Concrete),
				part(v(24, 10, 0.6), v(0, 60, -15.3), PINK5, M.Neon),
				part(v(24, 10, 0.6), v(0, 40, -15.3), CYAN5, M.Neon),
				part(v(24, 10, 0.6), v(0, 20, -15.3), YELLOW5, M.Neon),
				part(v(30.4, 1, 30.4), v(0, 80, 0), PINK5, M.Neon),
			}),
			prop("ConcreteBlock", v(36, 50, 30), {
				part(v(36, 50, 30), v(0, 25, 0), CONCRETE5, M.Concrete),
				part(v(36.3, 4, 30.3), v(0, 30, 0), hex("3A3550"), M.Glass),
				part(v(36.3, 4, 30.3), v(0, 40, 0), hex("3A3550"), M.Glass),
			}),
			prop("RailPier", v(40, 33, 12), {
				part(v(6, 24, 6), v(-14, 12, 0), CONCRETE5, M.Concrete),
				part(v(6, 24, 6), v(14, 12, 0), CONCRETE5, M.Concrete),
				part(v(40, 5, 12), v(0, 26.5, 0), CONCRETE5, M.Concrete),
				part(v(12, 4, 6), v(0, 31, 0), hex("8A8AA0"), M.Metal),
			}),
		}),
		Particles = particles(
			SMOKE,
			FOG5,
			{ Size = 4, Lifetime = 5, Rate = 4, Speed = 1, Transparency = 0.4, LightEmission = 0.2 }
		),
	},

	-- Track 6: bright modern city, a single plain glass academy tower (not the real H shape), training grounds,
	-- boxy generic robots, billboards without text, no school emblem
	City = {
		DisplayName = "Hero Academy City",
		Ground = { Color = PARK6, Material = M.Grass },
		Sky = { Color = hex("A8D4F5") },
		Gate = gate(RED6, M.Metal, YELLOW6),
		-- The street walls need most of the budget (spec Layers 9); see BiomeDressing SHARE
		Shares = { Rhythm = 0.15, Blocks = 0.75 },
		Rhythm = {
			Every = 8,
			Offset = 10,
			Props = {
				prop("StreetLamp", v(3, 16.5, 3), {
					post(16, 0.8, v(0, 8, 0), ASPHALT6, M.Metal),
					part(v(3, 1, 3), v(0, 16, 0), rgb(255, 250, 220), M.Neon),
				}),
				block("CrashBarrier", v(10, 3, 1.5), CONCRETE6, M.Concrete, {
					part(v(10.2, 0.6, 1.5), v(0, 2.4, 0), RED6, M.SmoothPlastic),
				}),
				trainingRobot(),
				roundTree("ParkTree", 14, hex("6B4A2E"), hex("5BA85B")),
			},
		},
		Landmarks = {
			-- In the street wall: the Blocks rows leave room around each tower (spiral laps are ~110 studs apart)
			Offset = 18,
			Every = 60,
			Props = {
				tower(
					"AcademyTower",
					26,
					64,
					26,
					{ Body = CONCRETE6, Trim = hex("B8C0CC"), Glass = GLASS6, Neon = RED6, Floor = 5 }
				),
				tower(
					"GlassTower",
					22,
					70,
					22,
					{ Body = hex("D0D6DE"), Trim = hex("A8B0BC"), Glass = GLASS6, Neon = YELLOW6 }
				),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("Skyline", v(36, 60, 20), {
					part(v(14, 60, 18), v(-11, 30, 0), hex("C8D0DA"), M.Concrete),
					part(v(12, 44, 16), v(4, 22, 0), hex("D8DEE6"), M.Concrete),
					part(v(10, 52, 14), v(15, 26, 0), hex("C8D0DA"), M.Concrete),
					part(v(14.4, 30, 18.4), v(-11, 34, 0), GLASS6, M.Glass),
					part(v(10.4, 26, 14.4), v(15, 30, 0), GLASS6, M.Glass),
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 78, -- behind the two Blocks rows (Near 18 + RowDepth 34 + depth <= 30)
			Far = 84,
			Props = {
				"ParkTree",
				prop("Billboard", v(16, 16, 1.5), {
					post(9, 1, v(0, 4.5, 0), ASPHALT6, M.Metal),
					part(v(16, 7, 1.4), v(0, 12.5, 0), YELLOW6, M.SmoothPlastic),
					part(v(12, 3, 1.5), v(0, 12.5, 0), RED6, M.Neon),
				}),
				block("Bench", v(6, 2.5, 2), hex("6B4A2E"), M.WoodPlanks),
				block(
					"Planter",
					v(5, 3, 5),
					hex("B8C0CC"),
					M.Concrete,
					{ part(v(4, 2, 4), v(0, 3.5, 0), PARK6, M.Grass) }
				),
			},
			Patches = {
				patch("Crosswalk", 10, 4, hex("F4F4F4"), M.Concrete),
				patch("TrainingGround", 12, 8, hex("C8C2B4"), M.Concrete),
				patch("Lawn", 10, 8, hex("7CC47C"), M.Grass),
			},
		},
		Blocks = {
			Spacing = 32, -- just over the widest building (30.3), so the street wall has no wide gaps
			Near = 18,
			Rows = 2,
			RowDepth = 34,
			Props = {
				lowrise("Shops", 30, 16, 26, { Glass = GLASS6, Neon = RED6, Body = hex("DDE2E8") }),
				lowrise("Apartments", 28, 30, 28, { Glass = GLASS6, Neon = YELLOW6, Body = hex("E6D8C4") }),
				lowrise("Office", 30, 38, 30, { Glass = GLASS6, Neon = RED6, Body = hex("C8D0DA") }),
				lowrise("Gym", 30, 14, 26, { Glass = GLASS6, Neon = YELLOW6, Body = hex("B8C0CC") }),
			},
		},
		Particles = particles(
			SPARKLE,
			ColorSequence.new(RED6, YELLOW6),
			{ Size = 0.6, Lifetime = 3, Rate = 5, Speed = 2, LightEmission = 0.6 }
		),
	},

	-- Track 7: cherry blossom avenue, rows and tunnels of red gates, stone stairs, a hilltop shrine; plaques carry
	-- no text
	Desert = {
		DisplayName = "Blossom Shrine Path",
		Ground = { Color = hex("A9C98E"), Material = M.Grass },
		Sky = { Color = SKY7 },
		Gate = gate(VERMILION7, M.Wood),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				frameGate("RedGate", 10, 12, VERMILION7, M.Wood, rgb(40, 34, 32)),
				roundTree("CherryTree", 18, WOOD7, BLOSSOM7, M.Grass, hex("F2A9C4")),
				stoneLantern("StoneLantern", 7, STONE7, rgb(255, 220, 150)),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 20,
			Props = {
				house("ShrineHall", 20, 9, 16, WOOD7, ROOF7, {
					WallMaterial = M.WoodPlanks,
					Trim = VERMILION7,
					Window = hex("F2E6C8"),
					Glow = rgb(255, 210, 150),
				}),
				gateTunnel(),
				stoneStairs(),
				prop("StoneFox", v(4, 7.3, 5), { -- generic sitting fox on a plinth
					part(v(4, 2, 5), v(0, 1, 0), STONE7, M.Slate),
					part(v(2.4, 3, 2.4), v(0, 3.5, 0.4), hex("E8E8E4"), M.Marble),
					part(v(1.8, 1.6, 2), v(0, 5.6, -0.2), hex("E8E8E4"), M.Marble),
					part(v(0.5, 1, 0.5), v(-0.6, 6.8, 0), hex("E8E8E4"), M.Marble),
					part(v(0.5, 1, 0.5), v(0.6, 6.8, 0), hex("E8E8E4"), M.Marble),
					part(v(1.6, 0.8, 0.2), v(0, 4.6, -0.9), VERMILION7, M.Fabric), -- bib
				}),
				prop("WashBasin", v(8, 6.8, 5), {
					part(v(6, 2, 3), v(0, 1, 0), STONE7, M.Slate),
					part(v(5, 0.3, 2), v(0, 2.1, 0), hex("8CC8E8"), M.Glass),
					post(6, 0.5, v(-3.5, 3, 1.5), WOOD7, M.Wood),
					post(6, 0.5, v(3.5, 3, 1.5), WOOD7, M.Wood),
					part(v(8, 0.8, 5), v(0, 6.4, 0), ROOF7, M.Slate),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("HilltopShrine", v(60, 37, 22), {
					part(v(60, 24, 22), v(0, 12, 0), hex("7FA36A"), M.Grass),
					part(v(20, 8, 12), v(0, 28, 0), WOOD7, M.WoodPlanks),
					part(v(26, 2, 16), v(0, 33, 0), ROOF7, M.Slate),
					part(v(16, 2, 12), v(0, 35, 0), ROOF7, M.Slate),
					part(v(14, 14, 14), v(-20, 30, 3), BLOSSOM7, M.Grass, BALL),
					part(v(14, 14, 14), v(20, 30, 3), BLOSSOM7, M.Grass, BALL),
				}),
				prop("Pagoda", v(20, 45.5, 20), {
					part(v(14, 10, 14), v(0, 5, 0), WOOD7, M.WoodPlanks),
					part(v(20, 1.5, 20), v(0, 10.75, 0), ROOF7, M.Slate),
					part(v(11, 9, 11), v(0, 16, 0), WOOD7, M.WoodPlanks),
					part(v(17, 1.5, 17), v(0, 21.25, 0), ROOF7, M.Slate),
					part(v(8, 8, 8), v(0, 26, 0), WOOD7, M.WoodPlanks),
					part(v(14, 1.5, 14), v(0, 30.75, 0), ROOF7, M.Slate),
					post(14, 0.8, v(0, 38.5, 0), hex("B8A060"), M.Metal),
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"CherryTree",
				"StoneLantern",
				"StoneFox",
				block("Bush", v(6, 4, 6), hex("6E9A5A"), M.Grass),
				"RedGate",
			},
			Patches = {
				patch("PetalCarpet", 24, 16, BLOSSOM7, M.Grass),
				patch("StoneSlabs", 20, 8, hex("C2C2BE"), M.Slate),
				patch("Moss", 16, 12, hex("6E9A5A"), M.Grass),
			},
		},
		Blocks = giants({
			roundTree("GiantCherry", 50, WOOD7, BLOSSOM7, M.Grass, hex("F2A9C4")),
			frameGate("GiantGate", 30, 40, VERMILION7, M.Wood, rgb(40, 34, 32)),
			house(
				"TempleHall",
				30,
				14,
				24,
				WOOD7,
				ROOF7,
				{ WallMaterial = M.WoodPlanks, Trim = VERMILION7, Floors = 2 }
			),
		}),
		Particles = particles(SPARKLE, BLOSSOM7, {
			Size = 0.8,
			Lifetime = 6,
			Speed = 1,
			Acceleration = v(0.6, -1, 0.2),
			LightEmission = 0.2,
		}),
	},

	-- Track 8: floating grassy islands, waterfalls into clouds, vine bridges, generic stone columns and arches
	Snow = {
		DisplayName = "Sky Islands",
		Ground = { Color = GRASS8, Material = M.Grass },
		Sky = { Color = SKY8 },
		Gate = gate(RUIN8, M.Rock),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				prop("BrokenColumn", v(3.4, 10.4, 3.4), {
					part(v(3.4, 1, 3.4), v(0, 0.5, 0), RUIN8, M.Rock),
					post(8, 2.4, v(0, 5, 0), RUIN8, M.Rock),
					part(v(2.4, 1.6, 2.4), v(0.4, 9.6, 0), RUIN8, M.Rock, nil, CFrame.Angles(0.3, 0, 0.2)),
				}),
				roundTree("IslandTree", 14, ROCK8, hex("5FAE52")),
				block("MossRock", v(5, 3.6, 4), ROCK8, M.Rock, { part(v(4, 0.8, 3), v(0, 3.2, 0), GRASS8, M.Grass) }),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				prop("FloatingIsland", v(22, 40, 22), {
					part(v(20, 8, 20), v(0, 26, 0), ROCK8, M.Rock),
					part(v(12, 8, 12), v(0, 19, 0), ROCK8, M.Rock),
					part(v(5, 6, 5), v(0, 13, 0), ROCK8, M.Rock),
					part(v(22, 2, 22), v(0, 31, 0), GRASS8, M.Grass),
					part(v(8, 8, 8), v(4, 36, 2), hex("5FAE52"), M.Grass, BALL),
					part(v(0.6, 10, 0.6), v(-6, 16, -6), hex("5E7A3C"), M.Grass), -- hanging root
				}, { Tag = "BiomeBob" }),
				prop("Waterfall", v(24, 33, 18), {
					part(v(24, 30, 12), v(0, 15, 2), ROCK8, M.Rock),
					part(v(20, 3, 10), v(0, 31.5, 2), GRASS8, M.Grass),
					part(v(8, 28, 1), v(0, 16, -4.6), FALL8, M.Glass),
					part(v(14, 6, 10), v(0, 2, -6), CLOUD8, M.SmoothPlastic, BALL), -- cloud where it lands
				}, { Glow = rgb(180, 220, 255) }),
				prop("RuinArch", v(16, 16.9, 4.2), {
					post(14, 2.6, v(-6, 7, 0), RUIN8, M.Rock),
					post(14, 2.6, v(6, 7, 0), RUIN8, M.Rock),
					part(v(16, 2, 4), v(0, 15, 0), RUIN8, M.Rock),
					part(v(5, 1, 4.2), v(-3, 16.4, 0), GRASS8, M.Grass),
				}),
				prop("VineBridge", v(34, 7, 10), {
					part(v(30, 0.6, 6), v(0, 4, 0), DIRT1, M.WoodPlanks),
					part(v(30, 0.3, 0.3), v(0, 6.5, -3), hex("5E7A3C"), M.Fabric),
					part(v(30, 0.3, 0.3), v(0, 6.5, 3), hex("5E7A3C"), M.Fabric),
					post(7, 0.8, v(-14, 3.5, -3), hex("6B4A2E"), M.Wood),
					post(7, 0.8, v(14, 3.5, -3), hex("6B4A2E"), M.Wood),
					post(7, 0.8, v(-14, 3.5, 3), hex("6B4A2E"), M.Wood),
					post(7, 0.8, v(14, 3.5, 3), hex("6B4A2E"), M.Wood),
					part(v(34, 3, 10), v(0, 1.5, 0), CLOUD8, M.SmoothPlastic), -- clouds under it
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("CloudBank", v(70, 20, 22), {
					part(v(30, 16, 18), v(-18, 8, 0), CLOUD8, M.SmoothPlastic, BALL),
					part(v(36, 20, 22), v(6, 10, 0), CLOUD8, M.SmoothPlastic, BALL),
					part(v(24, 12, 16), v(26, 6, 0), hex("EEF6FF"), M.SmoothPlastic, BALL),
				}),
				prop("DistantIsland", v(40, 73, 22), {
					part(v(30, 12, 20), v(10, 6, 0), CLOUD8, M.SmoothPlastic, BALL),
					part(v(36, 12, 20), v(0, 50, 0), ROCK8, M.Rock),
					part(v(22, 12, 14), v(0, 40, 0), ROCK8, M.Rock),
					part(v(38, 3, 22), v(0, 57.5, 0), GRASS8, M.Grass),
					part(v(14, 14, 14), v(-6, 66, 2), hex("5FAE52"), M.Grass, BALL),
					part(v(6, 30, 1), v(16, 34, -8), FALL8, M.Glass),
				}, { Tag = "BiomeBob" }),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"BrokenColumn",
				"IslandTree",
				ball("CloudPuff", 8, CLOUD8, M.SmoothPlastic),
				"MossRock",
				block("FallenColumn", v(10, 2.4, 2.4), RUIN8, M.Rock),
			},
			Patches = {
				patch("CloudPool", 24, 16, hex("F2F8FF"), M.SmoothPlastic),
				patch("Meadow", 20, 14, hex("9AD47F"), M.Grass),
				patch("StoneTiles", 16, 12, RUIN8, M.Slate),
			},
		},
		Blocks = giants({
			roundTree("GiantTree", 60, ROCK8, hex("4E9C46"), M.Grass, hex("5FAE52")),
			prop("StonePillar", v(24, 104, 22), {
				part(v(24, 60, 22), v(0, 30, 0), ROCK8, M.Rock),
				part(v(18, 30, 16), v(0, 75, 0), hex("7A6A58"), M.Rock),
				part(v(20, 4, 18), v(0, 92, 0), GRASS8, M.Grass),
				part(v(12, 12, 12), v(0, 98, 0), hex("5FAE52"), M.Grass, BALL),
			}),
			prop("SkyIsle", v(40, 61, 38), {
				part(v(40, 10, 34), v(0, 5, 0), CLOUD8, M.SmoothPlastic, BALL),
				part(v(36, 12, 36), v(0, 52, 0), ROCK8, M.Rock),
				part(v(20, 14, 20), v(0, 40, 0), ROCK8, M.Rock),
				part(v(38, 3, 38), v(0, 59.5, 0), GRASS8, M.Grass),
			}, { Tag = "BiomeBob" }),
		}),
		Particles = particles(SMOKE, CLOUD8, { Size = 4, Lifetime = 5, Rate = 3, Speed = 1, Transparency = 0.5 }),
	},

	-- Track 9 (night): white dunes, dead white trees, a plain dome palace with a few towers on the horizon, a
	-- crescent moon on a local black backdrop, no mask designs. Tints only its own props and ground.
	Volcano = {
		DisplayName = "Spirit Realm Desert",
		Ground = { Color = SAND9, Material = M.Sand },
		Sky = { Color = SKY9 },
		Gate = gate(TREE9, M.Marble, MOON9),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				deadTree("DeadWhiteTree", 14, TREE9, M.Marble),
				block("WhiteRock", v(5, 3, 4), hex("E4E4DE"), M.Rock),
				prop("BrokenPillar", v(3, 8, 3), {
					part(v(3, 6, 3), v(0, 3, 0), TREE9, M.Marble),
					part(v(2.4, 2, 2.4), v(0.3, 7, 0), TREE9, M.Marble, nil, CFrame.Angles(0.2, 0, 0.3)),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				prop("BoneArch", v(22, 18, 4), {
					part(v(3, 14, 3), v(-8, 6.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, -0.3)),
					part(v(3, 14, 3), v(8, 6.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, 0.3)),
					part(v(14, 3, 3), v(0, 15, 0), TREE9, M.Marble),
					part(v(4, 3, 3.2), v(0, 16.5, 0), MOON9, M.Neon),
				}, { Glow = MOON9 }),
				deadTree("CrystalTree", 30, hex("EDEDF2"), M.Glass),
				block("ShadowOutcrop", v(20, 19, 14), ROCK9, M.Rock, {
					part(v(10, 8, 8), v(4, 15, 2), ROCK9, M.Rock),
				}),
				prop("PillarRuin", v(16, 16.5, 10), {
					part(v(16, 1, 10), v(0, 0.5, 0), TREE9, M.Marble),
					part(v(3, 14, 3), v(-5, 8, 0), TREE9, M.Marble),
					part(v(3, 9, 3), v(5, 5.5, 0), TREE9, M.Marble),
					part(v(12, 2, 3), v(-1, 15.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0, 0.1)),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("DomePalace", v(70, 40, 22), {
					part(v(70, 10, 22), v(0, 5, 0), hex("ECECE6"), M.Marble),
					part(v(44, 44, 20), v(0, 10, 0), hex("F6F6F2"), M.Marble, BALL),
					part(v(6, 40, 6), v(-30, 20, -7), hex("ECECE6"), M.Marble),
					part(v(6, 32, 6), v(30, 16, -7), hex("ECECE6"), M.Marble),
					part(v(6, 36, 6), v(30, 18, 7), hex("ECECE6"), M.Marble),
				}),
				prop("CrescentMoon", v(50, 117, 5), {
					part(v(50, 50, 1), v(0, 92, 2), SKY9, M.SmoothPlastic), -- local black sky backdrop
					part(v(1, 22, 22), v(0, 92, 1), MOON9, M.Neon, CYL, FACE),
					part(v(1, 20, 20), v(5, 95, 0.4), SKY9, M.SmoothPlastic, CYL, FACE), -- bites out the crescent
					part(v(4, 66, 4), v(0, 33, 4), ROCK9, M.Rock), -- holds it up, behind the backdrop
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"DeadWhiteTree",
				"WhiteRock",
				"BrokenPillar",
				block("ShadowRock", v(6, 3, 5), ROCK9, M.Rock),
				prop("BonePile", v(6, 1.7, 4), {
					part(v(6, 1, 1), v(0, 0.5, 0), TREE9, M.Marble, nil, CFrame.Angles(0, 0.4, 0)),
					part(v(5, 1, 1), v(0, 1.2, 0), TREE9, M.Marble, nil, CFrame.Angles(0, -0.6, 0)),
				}),
			},
			Patches = {
				patch("ShadowDune", 26, 16, SHADOW9, M.Sand),
				patch("BrightSand", 20, 14, hex("FAFAF8"), M.Sand),
				patch("DarkRock", 14, 10, ROCK9, M.Slate),
			},
		},
		Blocks = giants({
			deadTree("GiantDeadTree", 60, TREE9, M.Marble),
			prop("DomeTower", v(30, 59, 30), {
				part(v(20, 44, 20), v(0, 22, 0), hex("ECECE6"), M.Marble),
				part(v(30, 30, 30), v(0, 44, 0), hex("F6F6F2"), M.Marble, BALL),
			}),
			block("WhiteMonolith", v(16, 70, 10), hex("E4E4DE"), M.Marble, {
				part(v(16.4, 2, 10.4), v(0, 50, 0), SHADOW9, M.Slate),
			}),
		}),
		Particles = particles(SPARKLE, MOON9, {
			Size = 0.5,
			Lifetime = 5,
			Rate = 5,
			Speed = 1,
			Acceleration = v(0, 0.5, 0),
			LightEmission = 0.8,
		}),
	},

	-- Track 10: green sky on local backdrops, blue-green grass, small islands over teal water, plain white dome
	-- houses with round windows, tall thin ball-top trees, rock pillars, distant suns. No orb items.
	Space = {
		DisplayName = "Green Alien Planet",
		Ground = { Color = GRASS10, Material = M.Grass },
		Sky = { Color = SKY10 },
		Gate = gate(DOME10, M.SmoothPlastic, HAZE10),
		Rhythm = {
			Every = 3,
			Offset = 10,
			Props = {
				ballTree,
				block("Shrub", v(5, 3, 5), hex("4FC9A8"), M.Grass),
				prop("RockStack", v(4, 9, 4), {
					part(v(4, 4, 4), v(0, 2, 0), ROCK10, M.Rock),
					part(v(3, 3, 3), v(0.3, 5.5, 0), ROCK10, M.Rock),
					part(v(2, 2, 2), v(0, 8, 0.2), hex("7E8F68"), M.Rock),
				}),
			},
		},
		Landmarks = {
			Offset = 40,
			Every = 22,
			Props = {
				domeHouse("DomeHouse", 16),
				prop("DomeVillage", v(40, 8, 22), {
					part(v(16, 16, 16), v(-10, 0, 0), DOME10, M.SmoothPlastic, BALL),
					part(v(12, 12, 12), v(8, 0, 2), DOME10, M.SmoothPlastic, BALL),
					part(v(10, 10, 10), v(14, 0, -6), DOME10, M.SmoothPlastic, BALL),
					part(v(3, 4, 0.6), v(-10, 2, -7.6), hex("3F6E4F"), M.SmoothPlastic),
					part(v(2.5, 3, 0.6), v(8, 1.5, -4), hex("3F6E4F"), M.SmoothPlastic),
				}, { Glow = HAZE10 }),
				prop("RockPillar", v(10, 41.25, 10), {
					part(v(10, 26, 10), v(0, 13, 0), ROCK10, M.Rock),
					part(v(7, 14, 7), v(0, 33, 0), ROCK10, M.Rock),
					part(v(8, 1.5, 8), v(0, 40.5, 0), GRASS10, M.Grass),
				}),
				prop("CraterPool", v(24, 2, 24), {
					part(v(0.4, 20, 20), v(0, 0.4, 0), WATER10, M.Glass, CYL, UP),
					part(v(24, 2, 4), v(0, 1, -10), ROCK10, M.Rock),
					part(v(24, 2, 4), v(0, 1, 10), ROCK10, M.Rock),
					part(v(4, 2, 16), v(-10, 1, 0), ROCK10, M.Rock),
					part(v(4, 2, 16), v(10, 1, 0), ROCK10, M.Rock),
				}),
			},
		},
		Horizon = {
			Offset = 55, -- placeholder: x2 pieces span ~55-100 studs from the road, inside the ~110-stud gap between laps
			Props = {
				prop("GreenSkyMesa", v(60, 95, 20), {
					part(v(60, 30, 18), v(0, 15, -1), ROCK10, M.Rock),
					part(v(40, 4, 14), v(0, 32, -1), GRASS10, M.Grass),
					part(v(60, 40, 1), v(0, 70, 9.5), SKY10, M.SmoothPlastic), -- local green sky backdrop
					part(v(10, 10, 10), v(-12, 80, 7), hex("FFF6C8"), M.Neon, BALL), -- distant suns
					part(v(6, 6, 6), v(14, 88, 7), hex("FFF6C8"), M.Neon, BALL),
				}),
				prop("TealIsland", v(70, 25, 22), {
					part(v(70, 0.4, 22), v(0, 0.2, 0), WATER10, M.Glass),
					part(v(30, 8, 18), v(0, 0, 0), GRASS10, M.Grass, BALL),
					post(18, 0.8, v(-4, 13, 0), hex("7B6A4E"), M.Wood),
					part(v(6, 6, 6), v(-4, 22, 0), GRASS10, M.Grass, BALL),
					part(v(10, 10, 10), v(6, 3, 2), DOME10, M.SmoothPlastic, BALL),
				}),
			},
		},
		Scatter = {
			Every = 2,
			Near = 25,
			Far = 160,
			Props = {
				"BallTree",
				"Shrub",
				"RockStack",
				block("Pebble", v(3, 1.5, 3), ROCK10, M.Rock),
				domeHouse("SmallDome", 8),
			},
			Patches = {
				patch("Pond", 22, 14, WATER10, M.Glass),
				patch("HazeGrass", 20, 14, HAZE10, M.Grass),
				patch("RockFlat", 14, 10, ROCK10, M.Slate),
			},
		},
		Blocks = giants({
			prop("GiantBallTree", v(24, 70, 24), {
				post(50, 3, v(0, 25, 0), hex("7B6A4E"), M.Wood),
				part(v(24, 24, 24), v(0, 58, 0), GRASS10, M.Grass, BALL),
				part(v(10, 10, 10), v(8, 40, 0), hex("4FC9A8"), M.Grass, BALL),
			}),
			prop("TallPillar", v(20, 92, 20), {
				part(v(20, 60, 20), v(0, 30, 0), ROCK10, M.Rock),
				part(v(14, 30, 14), v(0, 75, 0), ROCK10, M.Rock),
				part(v(16, 2, 16), v(0, 91, 0), GRASS10, M.Grass),
			}),
			domeHouse("BigDome", 40),
		}),
		Particles = particles(SPARKLE, HAZE10, { Size = 0.6, Lifetime = 5, Rate = 5, Speed = 1, LightEmission = 0.6 }),
	},
}
