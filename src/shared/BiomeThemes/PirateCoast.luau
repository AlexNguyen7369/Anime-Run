--!nonstrict
-- Track 5 (night, fire-lit): Burning Cursed City (owner redesign 2026-10-31; replaces Neon Cursed City). A city at
-- night lit by fire: high-rises burning from their broken top floors, a lava-split boulevard with burning cars, the
-- smouldering meteor in a crossroads crater, a broken rail viaduct, a tower split and slid apart, rubble everywhere.
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 5): flat Blocks city on Asphalt
-- streets and Concrete lots with craters, a CrackedLava meteor crater (Sections), a Basalt rubble mound under the
-- road's hill, a fire-lit night atmosphere, audio and the asset ledger. Mesh props keep their part fallback
-- (spec 4.2), scaled to the mesh's size. Tints only its own props and ground (never global Lighting).
-- IP (spec 7): no likeness of either fighter (no volcano-headed, four-armed or face-marked figure, no tattoo
-- patterns), no domain shrine copy (no skulls, no fanged gate), no technique symbol, hand sign or bow-shaped flame;
-- no real store or station names or signs, no real landmarks (no cylinder tower, no dog statue, no scramble
-- crossing copy), no logos. Every sign and billboard is blank or burnt.
local Kit = require(script.Parent.Kit)

local M, hex, rgb, v, BALL, CYL, UP, part, post, prop, block, gate, patch, giants, SMOKE, particles =
	Kit.M,
	Kit.hex,
	Kit.rgb,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.UP,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.SMOKE,
	Kit.particles

-- Palette (TRACKS_AND_BIOMES_SPEC Track 5, placeholders)
local CHAR = hex("0E0B12") -- char ground
local SMOKE5 = hex("2A1E1E") -- smoke
local FIRE = hex("FF6A1A") -- fire orange
local FLAME = hex("FFC23D") -- flame yellow
local EMBER = hex("C2261B") -- ember red
local BURNT = hex("4A4448") -- burnt concrete
local SOOT = hex("2A2628")
local STEEL = rgb(62, 58, 62)
local ASPHALT = hex("1E1618")
local SIGNAL = hex("1A1A1E") -- burnt-out traffic light box, lamps dark

-- A mesh prop (spec 4.2): `def`'s parts, scaled to `size`'s height, are the fallback when the ledger row is unusable.
-- `size` keeps the mesh's own proportions (the registry stretches the mesh to it), measured in Studio after generation.
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

-- A stack of neon flame blocks rising from `pos` (fire in a gap or on a roof), `w` across, `h` tall
local function flames(parts, pos, w, h)
	table.insert(parts, part(v(w, h * 0.5, w * 0.8), pos + v(0, h * 0.25, 0), EMBER, M.Neon))
	table.insert(parts, part(v(w * 0.7, h * 0.4, w * 0.6), pos + v(0, h * 0.6, 0), FIRE, M.Neon))
	table.insert(parts, part(v(w * 0.35, h * 0.3, w * 0.3), pos + v(0, h * 0.85, 0), FLAME, M.Neon))
end

-- Hero 1: a concrete high-rise whose top floors are blown open and burning; fire in the window rows below.
local function burningTower()
	local parts = {
		part(v(16, 38, 16), v(0, 19, 0), BURNT, M.Concrete),
		part(v(5, 6, 16), v(-5.5, 41, 0), BURNT, M.Concrete), -- broken wall stubs above the gap
		part(v(4, 4, 16), v(6, 40, 0), BURNT, M.Concrete),
		part(v(0.8, 8, 0.8), v(-2, 42, -6), STEEL, M.Metal), -- exposed girders
		part(v(0.8, 9, 0.8), v(3, 42.5, 5), STEEL, M.Metal),
		part(v(16, 0.8, 0.8), v(0, 44, -7), STEEL, M.Metal),
	}
	for i = 0, 4 do
		local y = 8 + i * 6
		table.insert(parts, part(v(16.3, 2.2, 16.3), v(0, y, 0), SOOT, M.Glass)) -- dark window bands
		if i >= 3 then
			table.insert(parts, part(v(10, 1.8, 0.4), v(i == 3 and -2 or 2, y, -8.25), FIRE, M.Neon)) -- burning floors
		end
	end
	flames(parts, v(0, 38, 0), 10, 9)
	return prop("BurningTower", v(16, 47, 16), parts, { Glow = FIRE })
end

-- Hero 2: a tower split along a straight diagonal, its upper block shifted and leaning (plain split, no symbol).
local function slicedTower()
	local parts = {
		part(v(16, 20, 15.6), v(0, 10, 0), BURNT, M.Concrete),
		part(v(16, 4, 15.6), v(0, 21, 0), BURNT, M.Concrete, nil, CFrame.Angles(0, 0, 0.35)), -- slanted split face
		part(v(16, 17, 15.6), v(2.5, 31.5, 0), BURNT, M.Concrete, nil, CFrame.Angles(0, 0, 0.12)), -- shifted top block
		part(v(14, 0.6, 14), v(0, 22.5, 0), FIRE, M.Neon, nil, CFrame.Angles(0, 0, 0.35)), -- glowing split line
	}
	for i = 0, 2 do
		table.insert(parts, part(v(16.3, 2, 15.9), v(0, 4 + i * 5.5, 0), SOOT, M.Glass))
	end
	return prop("SlicedTower", v(16, 41, 15.6), parts, { Glow = FIRE })
end

-- Hero 3: the smouldering meteor, a dark faceted boulder half-sunk in a crater with glowing cracks and a rubble rim.
local function meteor()
	local parts = {
		part(v(2, 28, 28), v(0, 1, 0), CHAR, M.Basalt, CYL, UP), -- crater floor
		part(v(0.6, 26, 26), v(0, 2.2, 0), EMBER, M.Neon, CYL, UP), -- glowing ring
		part(v(22, 22, 22), v(0, 5, 0), hex("1C1A20"), M.Basalt, BALL), -- the boulder, half sunk
		part(v(18, 0.6, 1.2), v(0, 9, -9.4), FIRE, M.Neon, nil, CFrame.Angles(0.4, 0.3, 0.2)), -- molten cracks
		part(v(1.2, 0.6, 16), v(-8, 10, 0), FIRE, M.Neon, nil, CFrame.Angles(0.2, 0, 0.5)),
		part(v(12, 0.6, 1), v(4, 13, -6), FLAME, M.Neon, nil, CFrame.Angles(0.6, -0.4, 0)),
	}
	for i = 0, 5 do
		local a = i * math.pi / 3
		table.insert(
			parts,
			part(
				v(6, 3, 4),
				v(math.cos(a) * 12, 1.5, math.sin(a) * 12),
				BURNT,
				M.Concrete,
				nil,
				CFrame.Angles(0.3, a, 0.2)
			)
		)
	end
	return prop("Meteor", v(28, 16, 28), parts, { Glow = FIRE })
end

-- Hero 4: a broken elevated rail viaduct: a deck on one pier, cracked through the middle, a burning rubble heap under
-- the break. The deck runs along X (the road direction).
local function brokenViaduct()
	local parts = {
		part(v(4, 15, 5), v(-9, 7.5, 0), BURNT, M.Concrete), -- pier
		part(v(7, 1.5, 7), v(-9, 15.75, 0), BURNT, M.Concrete), -- pier cap
		part(v(16, 2.4, 9), v(-7, 17.7, 0), BURNT, M.Concrete), -- deck, intact half
		part(v(15, 2.4, 9), v(8, 15, 0), BURNT, M.Concrete, nil, CFrame.Angles(0, 0, -0.35)), -- broken half, sagging
		part(v(31, 0.4, 0.4), v(0, 19.2, -1.5), STEEL, M.Metal), -- rails
		part(v(31, 0.4, 0.4), v(0, 19.2, 1.5), STEEL, M.Metal),
		part(v(10, 4, 8), v(6, 2, 0), BURNT, M.Concrete, nil, CFrame.Angles(0.2, 0.4, 0.15)), -- rubble heap
		part(v(6, 3, 5), v(11, 1.5, 2), SOOT, M.Basalt, nil, CFrame.Angles(-0.2, 0.9, 0)),
	}
	flames(parts, v(6, 3, 0), 4, 5)
	return prop("CollapsedViaduct", v(31, 21.4, 14), parts, { Glow = FIRE })
end

-- Landmark-layer extras (corners): a fire column and a fire-gutted storefront
local fireColumn = prop("FireColumn", v(10, 26, 10), {
	part(v(10, 3, 10), v(0, 1.5, 0), SOOT, M.Basalt),
	-- tongues of flame: twisted, offset blocks narrowing upward (stacked balls read as a traffic light, Play 2026-10-31)
	part(v(8, 6, 8), v(0, 6, 0), EMBER, M.Neon, nil, CFrame.Angles(0, 0.4, 0)),
	part(v(5, 8, 5), v(0.8, 11, 0.5), FIRE, M.Neon, nil, CFrame.Angles(0.15, 0.8, 0.1)),
	part(v(3.5, 7, 3.5), v(-1, 15.5, -0.5), FIRE, M.Neon, nil, CFrame.Angles(-0.2, 0.2, 0.15)),
	part(v(2.2, 6, 2.2), v(0.6, 20, 0.3), FLAME, M.Neon, nil, CFrame.Angles(0.1, 1, -0.2)),
	part(v(1.2, 4, 1.2), v(-0.4, 24, 0), FLAME, M.Neon, nil, CFrame.Angles(0, 0.5, 0.25)),
}, { Glow = FIRE })
local storefront = prop("BrokenStorefront", v(15, 20, 11.8), {
	part(v(15, 19, 11.8), v(0, 9.5, 0), BURNT, M.Concrete),
	part(v(12, 6, 0.4), v(0, 3.5, -6.1), FIRE, M.Neon), -- fire behind the shattered shop window
	part(v(10, 2.4, 0.4), v(0, 8.5, -6.1), SOOT, M.Concrete), -- blank burnt sign board
	part(v(12, 3, 0.3), v(0, 14, -6.05), SOOT, M.Glass),
	part(v(15.4, 1, 12.2), v(0, 19.5, 0), SOOT, M.Concrete),
}, { Glow = FIRE, Pad = true })

-- Rhythm / scatter props (fallbacks for the meshes, plus part-only props)
local trafficLight = prop("TrafficLight", v(5, 14, 2), {
	post(14, 0.6, v(-1.8, 7, 0), STEEL, M.Metal),
	part(v(4, 0.4, 0.4), v(0, 12.5, 0), STEEL, M.Metal), -- arm
	part(v(4, 1.3, 1.2), v(0.5, 12.5, -0.6), SIGNAL, M.Metal), -- light box, lamps out
})
local bentLamp = prop("BentLamp", v(5, 12, 2), {
	post(7, 0.5, v(0, 3.5, 0), STEEL, M.Metal),
	part(v(0.5, 6, 0.5), v(1.5, 9, 0), STEEL, M.Metal, nil, CFrame.Angles(0, 0, -0.6)), -- bent upper pole
	part(v(1.4, 0.8, 1.2), v(3.6, 11, 0), FLAME, M.Neon), -- lamp head still lit
})
local burningCar = prop("BurningCar", v(5.9, 8.4, 8.5), {
	part(v(5.9, 2.6, 8.5), v(0, 1.8, 0), SOOT, M.Metal),
	part(v(5, 2, 4.5), v(0, 4.1, 0.5), SOOT, M.Glass),
	part(v(4, 2, 3), v(0, 6, 0.3), FIRE, M.Neon, BALL),
	part(v(2.2, 1.6, 1.8), v(0, 7.5, 0.3), FLAME, M.Neon, BALL),
})
local rubblePile = prop("RubblePile", v(12, 5.7, 12), {
	part(v(9, 3.5, 7), v(-1, 1.75, 0), BURNT, M.Concrete, nil, CFrame.Angles(0.15, 0.4, 0.1)),
	part(v(6, 3, 5), v(3, 2.8, 2), BURNT, M.Concrete, nil, CFrame.Angles(-0.25, 1.1, 0)),
	part(v(5, 2, 4), v(-3, 3.8, -2), SOOT, M.Basalt, nil, CFrame.Angles(0.3, 0.2, 0.4)),
	part(v(0.3, 0.3, 7), v(1, 4.5, 0), STEEL, M.Metal, nil, CFrame.Angles(0.5, 0.3, 0)), -- rebar
	part(v(2, 0.6, 2), v(0, 0.4, -4), EMBER, M.Neon),
})
local billboard = prop("BurntBillboard", v(14, 13.9, 3.9), {
	post(6, 0.8, v(-4, 3, 0), STEEL, M.Metal),
	post(6, 0.8, v(4, 3, 0), STEEL, M.Metal),
	part(v(14, 7.5, 0.6), v(0, 9.9, 0), SOOT, M.Concrete), -- blank, burnt board
	part(v(14, 0.6, 0.8), v(0, 6.2, 0), EMBER, M.Neon), -- glowing burnt lower edge
})
local girders = prop("SteelGirders", v(14, 3, 6), {
	part(v(14, 1, 1.2), v(0, 0.5, -1.5), STEEL, M.Metal, nil, CFrame.Angles(0, 0.15, 0)),
	part(v(12, 1, 1.2), v(0, 1.5, 1), STEEL, M.Metal, nil, CFrame.Angles(0, -0.3, 0.12)),
	part(v(10, 1, 1.2), v(1, 2.5, 0), STEEL, M.Metal, nil, CFrame.Angles(0, 0.6, -0.1)),
})
local toppledLight = prop("ToppledTrafficLight", v(14, 2, 4), {
	part(v(14, 0.6, 0.6), v(0, 0.3, 0), STEEL, M.Metal, nil, CFrame.Angles(0, 0.1, 0)),
	part(v(1.3, 1.2, 4), v(6.5, 0.6, 0.5), SIGNAL, M.Metal),
})
local smoulder = prop("SmoulderingDebris", v(8, 3, 8), {
	part(v(8, 1.2, 8), v(0, 0.6, 0), SOOT, M.Basalt),
	part(v(3, 2.4, 3), v(0, 1.8, 0), FIRE, M.Neon, BALL),
	part(v(1.4, 1.4, 1.4), v(1.5, 2.6, 1), FLAME, M.Neon, BALL),
})

-- Mesh props (Lane A); sizes keep each mesh's own proportions
local trafficLightMesh = meshed(trafficLight, "TrafficLightMesh", v(7.7, 10.5, 3.2))
local burningCarMesh = meshed(burningCar, "BurningCarMesh", v(5.9, 8.4, 8.5)) -- x1.4 of the generated 4.2 x 6 x 6.1
local rubblePileMesh = meshed(rubblePile, "RubblePileMesh", v(12, 5.7, 12))
local billboardMesh = meshed(billboard, "BurntBillboardMesh", v(14, 13.9, 3.9)) -- x1.3 of 10.8 x 10.7 x 3
-- orchestrator default 2026-10-31: the BrokenStorefront mesh read as an angry face in Play (T5_Storefront.jpg), so the
-- part-built storefront is used; the mesh row stays in the ledger for a later regenerate
local storefrontMesh = storefront
local concreteBlock = prop("ConcreteBlock", v(36.3, 50, 30.6), {
	part(v(36, 50, 30), v(0, 25, 0), BURNT, M.Concrete),
	part(v(36.3, 4, 30.3), v(0, 30, 0), SOOT, M.Glass),
	part(v(36.3, 4, 30.3), v(0, 40, 0), SOOT, M.Glass),
	part(v(20, 8, 0.6), v(0, 18, -15.3), FIRE, M.Neon), -- fire in the lower floor
}, { Pad = true })
local concreteBlockMesh = meshed(concreteBlock, "ConcreteBlockMesh", v(29.5, 47.8, 30))
-- The signed intact viaduct mesh, kept as the rail piers between the street blocks (no pad)
local railOverpass = prop("RailOverpass", v(34, 26, 10.2), {
	part(v(4, 16, 6), v(-12, 8, 0), BURNT, M.Concrete),
	part(v(4, 16, 6), v(12, 8, 0), BURNT, M.Concrete),
	part(v(34, 3, 10), v(0, 19, 0), BURNT, M.Concrete), -- deck
	part(v(34, 0.4, 0.4), v(0, 20.7, -1.5), STEEL, M.Metal), -- rails
	part(v(34, 0.4, 0.4), v(0, 20.7, 1.5), STEEL, M.Metal),
})

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row.
-- Every row is signed by the rules auditor (spec 4.1 step 3; close-ups are in assets/biomes/PirateCoast/review/).
-- The three kept rows are unchanged from the Neon Cursed City version and keep their signature.
local function meshRow(id, texture, prompt, tris, notes, reviewed)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Tris = tris,
		Reviewed = reviewed,
		Notes = notes,
	}
end
local function textureRow(id, mesh, reviewed)
	return {
		Kind = "Texture",
		Id = id,
		Lane = "A",
		Prompt = "generated with " .. mesh .. " (same prompt)",
		Reviewed = reviewed,
	}
end
local SIGNED = "2026-10-31 rules-auditor" -- the kept rows' signature

return {
	DisplayName = "Burning Cursed City",
	Ground = { Color = ASPHALT, Material = M.Asphalt },
	Sky = { Color = SMOKE5 },
	Gate = gate(BURNT, M.Concrete, FIRE),
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { trafficLightMesh, burningCarMesh, bentLamp, rubblePileMesh, burningCarMesh, bentLamp },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight; on a straight odd p stands on
	-- the outer side, even p on the inner side (the inner strip toward Track 4 is only ~41 studs, so the deepest heroes
	-- are odd). Fractions of the 7200-stud track: 0-0.120 the opening avenue, 0.277-0.344 the straight after the
	-- crossing jinks, 0.411-0.580 the overpass straight (crest 0.467-0.478, road back at ground 0.500), 0.647-0.827 the
	-- rubble-mound straight (crest 0.702-0.711), 0.894-1 the finish straight.
	Landmarks = {
		Offset = 20, -- placeholder: x1.75 heroes are at most 49 deep
		Every = 18,
		Props = {
			-- p 1, outer: the opening avenue. Y stretched x1.3: the generator capped the 60-tall request at 36 (lesson a).
			meshed(burningTower(), "BurningTowerMesh", v(16, 47, 16), { Hero = true, At = 0.06 }), -- x1.75: 28 x 82
			-- p 2, inner: the finish straight. Y stretched x1.3 (the generator capped height at 32).
			meshed(slicedTower(), "SlicedTowerMesh", v(16, 41, 15.6), { Hero = true, At = 0.93 }), -- 28 x 72 x 27
			-- p 3, outer: the crossroads crater (Terrain Sections below), where the road comes back down to the ground.
			-- X/Z x1.75 and Y x2.5 of the 16 x 6.4 x 16 generation: a low wide boulder reads too flat from the road.
			meshed(meteor(), "MeteorMesh", v(28, 16, 28), { Hero = true, At = 0.5 }), -- x1.75: 49 x 28 x 49
			-- p 4, inner: the rubble-mound straight (24.5 deep fits the narrow inner gap)
			meshed(brokenViaduct(), "CollapsedViaductMesh", v(31, 21.4, 14), { Hero = true, At = 0.72 }), -- 54 x 37
			storefrontMesh,
			fireColumn,
			storefrontMesh,
		},
	},
	Horizon = {
		-- placeholder: 20. The x2 pieces are 36 deep, so they span about 40-76 studs from the centre line and keep
		-- inside this zone's half of the gap.
		Offset = 20,
		Props = {
			prop("BurningSkyline", v(60, 65, 18), {
				part(v(18, 60, 16), v(-20, 30, 0), hex("1E1A1E"), M.Concrete),
				part(v(16, 40, 14), v(0, 20, 0), hex("26201F"), M.Concrete),
				part(v(18, 50, 16), v(20, 25, 0), hex("1E1A1E"), M.Concrete),
				part(v(12, 3, 0.6), v(-20, 46, -8.3), FIRE, M.Neon), -- burning floors
				part(v(10, 2, 0.6), v(0, 30, -7.3), EMBER, M.Neon),
				part(v(12, 3, 0.6), v(20, 40, -8.3), FIRE, M.Neon),
				part(v(8, 5, 8), v(-20, 62.5, 0), FLAME, M.Neon, BALL), -- roof fire
				part(v(60, 30, 1), v(0, 30, 8.5), SMOKE5, M.SmoothPlastic), -- local smoke backdrop
			}, { Pad = true }),
			prop("RuinedRooftops", v(56, 36, 18), {
				part(v(26, 30, 16), v(-14, 15, 0), hex("26201F"), M.Concrete),
				part(v(26, 20, 16), v(14, 10, 0), hex("1E1A1E"), M.Concrete),
				part(v(20, 4, 0.6), v(-14, 22, -8.3), FIRE, M.Neon),
				part(v(16, 2, 0.6), v(14, 14, -8.3), EMBER, M.Neon),
				part(v(6, 6, 6), v(16, 23, 0), FIRE, M.Neon, BALL),
				part(v(56, 24, 1), v(0, 12, 8.5), SMOKE5, M.SmoothPlastic), -- local smoke backdrop
			}, { Pad = true }),
		},
	},
	Scatter = {
		Every = 2,
		Near = 25,
		Far = 150,
		Props = {
			"RubblePile",
			billboardMesh,
			girders,
			"BurningCar",
			toppledLight,
			smoulder,
			block("Barrier", v(6, 2.4, 1.2), hex("6B5F58"), M.Concrete),
		},
		Patches = {
			patch("LavaCrack", 18, 3, FIRE, M.Neon), -- glowing cracks in the lots (spec 7)
			patch("LavaPool", 12, 10, EMBER, M.Neon),
			patch("Scorch", 16, 12, CHAR, M.Basalt),
		},
	},
	Blocks = giants({
		prop("BurningBlock", v(30.4, 78, 30.6), {
			-- lighter burnt concrete: its walls get only ambient light at night, and darker read as a black slab (Play)
			part(v(30, 70, 30), v(0, 35, 0), hex("7A6E68"), M.Concrete),
			part(v(30.6, 2, 30.6), v(0, 47, 0), FIRE, M.Neon), -- a burning floor round all four sides
			part(v(30.4, 3, 30.4), v(0, 22, 0), SOOT, M.Glass), -- window bands
			part(v(30.4, 3, 30.4), v(0, 40, 0), SOOT, M.Glass),
			part(v(30.4, 3, 30.4), v(0, 60, 0), SOOT, M.Glass),
			part(v(24, 6, 0.6), v(0, 52, -15.3), FIRE, M.Neon), -- burning floors
			part(v(18, 4, 0.6), v(0, 14, -15.3), EMBER, M.Neon),
			part(v(12, 5, 10), v(4, 72.5, 0), EMBER, M.Neon, nil, CFrame.Angles(0, 0.4, 0)), -- roof fire
			part(v(7, 6, 6), v(5, 76, 1), FIRE, M.Neon, nil, CFrame.Angles(0.15, 0.9, 0.1)),
		}, { Pad = true }),
		concreteBlockMesh,
		meshed(railOverpass, "RailOverpassMesh", v(39.6, 26.9, 12.5)), -- rail piers between the blocks (no pad)
	}),
	-- Landmark emitters (BiomeDressing): a dark smoke column rising from every landmark (built-in smoke texture)
	Particles = particles(SMOKE, SMOKE5, {
		Size = 7,
		Lifetime = 7,
		Rate = 6,
		Speed = 5,
		Spread = 12,
		Acceleration = v(0, 2, 0),
		Transparency = 0.35,
		LightEmission = 0.05,
	}),
	-- Spec 3.3 / 7: flat Blocks city, Asphalt streets and Concrete lots with craters, no embank. The meteor crater is a
	-- CrackedLava Hills -12 bowl on both sides at 0.47-0.53. orchestrator default 2026-10-31: the road still climbs 30
	-- studs at 0.674-0.738, so a Basalt rubble mound (Hills 32) on the outer side carries it instead of bare stilts.
	-- Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Blocks" },
		Craters = { Count = 10, Radius = 36, Depth = 10 },
		Sections = {
			{
				From = 0.47,
				To = 0.53,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = -12, Noise = 0.04, Amp = 3 },
				Material = M.CrackedLava,
			},
			{
				From = 0.66,
				To = 0.75,
				Side = "Outer",
				Ridge = { Shape = "Hills", Height = 32, Noise = 0.05, Amp = 5 },
				Material = M.Basalt,
			},
		},
		Materials = { Corridor = M.Asphalt, Ridge = M.Concrete, Cliff = M.Basalt, Bed = M.Basalt },
		CliffSlope = 0.9,
		Embank = false,
	},
	-- Spec 5.2 / 7: night on fire. ClockTime 0, Atmosphere Color / Decay / Haze / Glare, Grade tint, Bloom and Clouds
	-- are from section 7. orchestrator default 2026-10-31 (lesson h, the neon version read too dark): Brightness,
	-- Ambient, OutdoorAmbient and exposure are raised above section 7's 0.5 / #3A1A10 / #5A2A18 to a warm fire-lit
	-- level, Density 0.32 / Haze 1.2 (were 0.45 / 2) and a lighter Grade tint / baseline Saturation, so the road and
	-- heroes read and the frame is not one flat red (Play check 2026-10-31). No skybox row (engine moon through the
	-- clouds); a Lane D skybox needs the script / remote check first (docs/BUGS.md creator-store-backdoor-skybox).
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 0,
			Brightness = 2,
			Ambient = hex("7A5646"),
			OutdoorAmbient = hex("9A7462"),
			ExposureCompensation = 0.4,
		},
		Atmosphere = { Density = 0.32, Offset = 0.1, Color = hex("3A2420"), Decay = FIRE, Glare = 0.3, Haze = 1.2 },
		Grade = { Contrast = 0.35, Saturation = 0.18, TintColor = hex("FFE6D2") }, -- Contrast baseline + 0.2
		Bloom = { Intensity = 1.4, Threshold = 0.85 }, -- fire and lava glow
		SunRays = { Intensity = 0 },
		Sky = {
			SunAngularSize = 21,
			MoonAngularSize = 14,
			StarCount = 300, -- placeholder: smoke hides most stars
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.8, Density = 0.5, Color = SMOKE5 },
		Particles = {
			{
				Texture = "EmberParticle", -- rising orange embers
				Color = FIRE,
				Size = 0.35,
				Rate = 30,
				Lifetime = 5,
				Speed = 3,
				SpreadAngle = 35,
				LightEmission = 1,
				Area = v(120, 20, 120),
			},
			{
				Texture = "SmokeParticle", -- drifting ash and smoke
				Color = hex("4A4040"),
				Size = 5,
				Rate = 6,
				Lifetime = 8,
				Speed = 0.8,
				SpreadAngle = 180,
				LightEmission = 0,
			},
		},
	}),
	Audio = {
		Loop = "AmbFireRoar",
		OneShots = { "SfxDistantExplosion", "SfxSiren" },
		Volume = 0.35,
		Reverb = "City",
	},
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Tris is the generation cap. Reviewed is the rules
	-- auditor's signature (spec 4.1). Sound rows: Creator Store audio ids used directly (no insert, nothing to strip).
	Assets = {
		-- generate_mesh size 16 x 60 x 16 (came back 15.9 x 35.9 x 16)
		BurningTowerMesh = meshRow(
			"rbxassetid://110026199515917",
			"BurningTowerTex",
			"very tall slender dark grey concrete office skyscraper with a regular grid of square windows on every side, the top floors are ruined with missing wall panels and exposed steel girders, orange fire glowing inside many windows and bursting from the broken top floors, black soot streaks, plain building with no face, no signs, no writing and no logos, stylized cartoon style",
			15000,
			"hero 1: no signs or face; front faces -Z",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 16 x 56 x 16 (came back 16 x 31.7 x 15.6)
		SlicedTowerMesh = meshRow(
			"rbxassetid://118384879998435",
			"SlicedTowerTex",
			"tall grey concrete office tower split in two along a straight diagonal line halfway up, the upper half shifted sideways and leaning on the lower half, a flat smooth diagonal split surface, a regular grid of square windows, soot streaks, small orange flames along the split, plain building, no signs and no writing, stylized cartoon style",
			15000,
			"hero 2: plain diagonal split, no symbol; the upper block floats just above the split (generator); front faces -Z",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 16 x 10 x 16 (came back 16 x 6.4 x 16)
		MeteorMesh = meshRow(
			"rbxassetid://129629428349458",
			"MeteorTex",
			"giant jagged angular black meteorite rock lying half buried and tilted in a wide cracked crater, rough faceted stone surface split by thin glowing orange lava crack lines, broken asphalt slabs pushed up around the crater rim, low wide shape, stylized cartoon style",
			15000,
			"hero 3: a plain boulder, no face; round, any yaw",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 40 x 18 x 10 (came back 22.2 x 15.3 x 10)
		CollapsedViaductMesh = meshRow(
			"rbxassetid://104055839246591",
			"CollapsedViaductTex",
			"damaged elevated concrete railway track section: a long flat concrete deck with two steel rails on top, one end supported by a tall square concrete pillar, the other end cracked and tilted down diagonally so it rests on a pile of concrete chunks on the ground, scorched grey concrete, small orange flames on the chunks, no train, no signs and no writing, stylized cartoon style",
			15000,
			"hero 4: deck runs along X, cracked over a burning rubble heap (the generator kept the deck level)",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 14 x 6 x 7 (came back 4.2 x 6 x 6.1, nose toward -Z)
		BurningCarMesh = meshRow(
			"rbxassetid://75112982054894",
			"BurningCarTex",
			"generic small four door car wrecked and on fire, burnt black paint, broken windows, orange flames rising from the hood and roof, no logo, no license plate and no writing, stylized cartoon style",
			3000,
			"generic car, blank plate; nose faces -Z",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 14 x 6 x 12
		RubblePileMesh = meshRow(
			"rbxassetid://90775659169182",
			"RubblePileTex",
			"pile of broken grey concrete rubble chunks and bent steel rebar, scorched black edges, a few glowing orange embers between the pieces, stylized cartoon style",
			3000,
			nil,
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 14 x 14 x 3
		BurntBillboardMesh = meshRow(
			"rbxassetid://99613692659503",
			"BurntBillboardTex",
			"roadside billboard on two steel legs, the board burnt, blackened and torn, completely blank with no picture, no letters and no logo, glowing embers on the torn edge, stylized cartoon style",
			2000,
			"board blank; front faces -Z",
			"2026-10-31 rules-auditor"
		),
		-- generate_mesh size 16 x 15 x 13
		BrokenStorefrontMesh = meshRow(
			"rbxassetid://90903812309143",
			"BrokenStorefrontTex",
			"small two storey city shop building damaged by fire, grey concrete walls scorched black above the windows, a wide shattered glass shop window with orange fire glowing inside, a blank burnt sign board with no writing, flat roof, stylized cartoon style",
			3000,
			"sign board blank; Pad = true; front faces -Z",
			"2026-10-31 rules-auditor"
		),
		-- Kept from the Neon Cursed City version, unchanged (still signed)
		-- generate_mesh size 34 x 26 x 10
		RailOverpassMesh = meshRow(
			"rbxassetid://117805018716612",
			"RailOverpassTex",
			"short segment of an elevated concrete railway overpass, a straight concrete deck carrying two steel rails, resting on two thick rectangular concrete piers, low side walls along the deck, a few thin metal overhead wire masts, a yellow light strip under the deck, no train, no signs and no writing, stylized cartoon style",
			10000,
			"hero 3: deck runs along X; also the Blocks rail pier",
			SIGNED
		),
		-- generate_mesh size 5 x 14 x 2
		TrafficLightMesh = meshRow(
			"rbxassetid://113808741498152",
			"TrafficLightTex",
			"city traffic light on a thin dark grey metal pole with a side arm holding a horizontal three lamp signal box, green, yellow and red round lamps, plain with no signs, stylized cartoon style",
			1500,
			nil,
			SIGNED
		),
		-- generate_mesh size 36 x 50 x 30
		ConcreteBlockMesh = meshRow(
			"rbxassetid://134508562216971",
			"ConcreteBlockTex",
			"tall plain grey concrete office block, two bands of dark tinted glass windows wrapping around, one blank glowing yellow sign panel on the front with no writing, flat roof with small rooftop units, stylized low poly cartoon style",
			3000,
			"Blocks giant; Pad = true",
			SIGNED
		),
		BurningTowerTex = textureRow("rbxassetid://111995406996497", "BurningTowerMesh", "2026-10-31 rules-auditor"),
		SlicedTowerTex = textureRow("rbxassetid://79499249668457", "SlicedTowerMesh", "2026-10-31 rules-auditor"),
		MeteorTex = textureRow("rbxassetid://127234806169781", "MeteorMesh", "2026-10-31 rules-auditor"),
		CollapsedViaductTex = textureRow(
			"rbxassetid://105638459114043",
			"CollapsedViaductMesh",
			"2026-10-31 rules-auditor"
		),
		BurningCarTex = textureRow("rbxassetid://137060689993765", "BurningCarMesh", "2026-10-31 rules-auditor"),
		RubblePileTex = textureRow("rbxassetid://135149187378761", "RubblePileMesh", "2026-10-31 rules-auditor"),
		BurntBillboardTex = textureRow(
			"rbxassetid://124515013244308",
			"BurntBillboardMesh",
			"2026-10-31 rules-auditor"
		),
		BrokenStorefrontTex = textureRow(
			"rbxassetid://122708716943483",
			"BrokenStorefrontMesh",
			"2026-10-31 rules-auditor"
		),
		RailOverpassTex = textureRow("rbxassetid://132514294558613", "RailOverpassMesh", SIGNED),
		TrafficLightTex = textureRow("rbxassetid://93198540892928", "TrafficLightMesh", SIGNED),
		ConcreteBlockTex = textureRow("rbxassetid://135390520256208", "ConcreteBlockMesh", SIGNED),
		EmberParticle = {
			Kind = "Texture",
			Id = "rbxassetid://123619002889840",
			Lane = "A",
			Prompt = "in-house 128 px ember: a hot white core with a soft glow, slightly stretched upward, white on transparent, tinted fire orange by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/PirateCoast/ember_particle.png), uploaded from Studio",
			Reviewed = "2026-10-31 rules-auditor",
		},
		SmokeParticle = {
			Kind = "Texture",
			Id = "rbxassetid://108000399126683",
			Lane = "A",
			Prompt = "in-house 128 px lumpy soft smoke puff from summed blurred blobs and noise, light grey on transparent, tinted ash grey by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/PirateCoast/smoke_particle.png), uploaded from Studio",
			Reviewed = "2026-10-31 rules-auditor",
		},
		AmbFireRoar = {
			Kind = "Sound",
			Id = "rbxassetid://9112823563",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112823563: Lava Rumble 2 (SFX), thick rumbling eruptive roar, loop, 59.8 s (the low fire roar; search found no ProSoundEffects fire-crackle loop)",
			Reviewed = "2026-10-31 rules-auditor",
		},
		SfxDistantExplosion = {
			Kind = "Sound",
			Id = "rbxassetid://9114224675",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9114224675: Earthquake Explosion 5 (SFX), hard impact, crumbling debris, booms and a long rumbling tail, 13.2 s",
			Reviewed = "2026-10-31 rules-auditor",
		},
		SfxSiren = {
			Kind = "Sound",
			Id = "rbxassetid://9119165420",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9119165420: Siren Yelp 1 (SFX), emergency siren start, pass and stop, 31.7 s",
			Reviewed = "2026-10-31 rules-auditor",
		},
	},
}
