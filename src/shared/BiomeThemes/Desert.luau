--!nonstrict
-- Track 7 (owner redesign 2026-10-31): Shibuyo Underground, a deep subway. The whole route runs inside an enclosed
-- tunnel (docs/BIOME_ENVIRONMENT_SPEC.md 3.5) of cream tiles with one teal band, a concrete ceiling with fluorescent
-- strips, opening into side platforms, a multi-level concourse and the deep main platform hall.
-- Data only (format in Kit). b2 (spec section 7, Track 7): Tunnel, earth over the roof, an Underground atmosphere,
-- audio and the asset ledger. Mesh props keep their part fallback (spec 4.2), scaled to the mesh's size.
-- Dressing inside the tunnel stands between the walls or on the bay platforms; only layers marked Surface = true go on
-- the earth over the roof (fw6, orchestrator default 2026-10-31), and those stay sparse (vents, stair entrances).
-- IP (spec 7): no real station, line or company names, letters, numbers, colours or logos; no real oval atrium; no
-- sealing-cube artifact; no character figures. Signs and maps carry abstract shapes and colour bands only, no text.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, part, post, prop, block, gate, patch =
	Kit.M, Kit.hex, Kit.v, Kit.BALL, Kit.part, Kit.post, Kit.prop, Kit.block, Kit.gate, Kit.patch

-- Palette (TRACKS_AND_BIOMES_SPEC Track 7, placeholders)
local TILE = hex("E9E4D6") -- tile cream
local CONCRETE = hex("8C8A84")
local BED = hex("2B2E33") -- track bed
local TACTILE = hex("F2D23A") -- tactile yellow
local TEAL = hex("3FA7A0") -- stripe band
local FLUO = hex("CFE8FF") -- fluorescent white
local RED = hex("B5281F") -- emergency red
local STEEL = hex("6E747C")
local DARK = hex("3A3F46")
local GLASS = hex("9FC7D0")

-- A mesh prop (spec 4.2): `def`'s parts, stretched to `size` per axis, are the fallback when the ledger row is
-- unusable. Stretched, not scaled by height, because the tunnel fit (BiomeDressing tunnelBox) also reads the fallback
-- parts' corners. `size` keeps the generated mesh's own proportions unless a comment says it is stretched.
local function meshed(def, key, size, extra)
	local k = size / def.Size
	local parts = {}
	for i, p in def.Parts do
		local q = table.clone(p)
		-- an upright cylinder (Kit.post) stretches along its own axes
		local kl = p.Shape == Kit.CYL and p.Rot and p.Rot:VectorToObjectSpace(k) or k
		q.Size = p.Size * Vector3.new(math.abs(kl.X), math.abs(kl.Y), math.abs(kl.Z))
		q.Pos = p.Pos * k
		parts[i] = q
	end
	local out = prop(def.Name, size, parts, { Mesh = key, Glow = def.Glow, Tag = def.Tag, Pad = def.Pad })
	for name, value in extra or {} do
		out[name] = value
	end
	return out
end

-- Hero 1: a box-shaped multi-level concourse void (never the real oval atrium): two balcony levels on grey columns,
-- criss-cross escalators between them, glass rails, a row of ticket gates in front and light strips under each level.
local function concourseAtrium()
	local parts = {
		part(v(30, 19, 1), v(0, 9.5, 7.5), TILE, M.CeramicTiles), -- back wall
		part(v(30, 1.2, 1.1), v(0, 4, 7), TEAL, M.SmoothPlastic), -- stripe band
		part(v(30, 1, 6), v(0, 7, 4.5), CONCRETE, M.Concrete), -- level 1 balcony
		part(v(30, 1, 6), v(0, 13.5, 4.5), CONCRETE, M.Concrete), -- level 2 balcony
		part(v(30, 0.8, 16), v(0, 18.6, 0), CONCRETE, M.Concrete), -- roof slab
		part(v(30, 1.6, 0.2), v(0, 8.3, 1.4), GLASS, M.Glass), -- glass rails
		part(v(30, 1.6, 0.2), v(0, 14.8, 1.4), GLASS, M.Glass),
		part(v(24, 0.2, 1), v(0, 6.4, 3), FLUO, M.Neon), -- light strips under the levels
		part(v(24, 0.2, 1), v(0, 12.9, 3), FLUO, M.Neon),
		part(v(24, 0.2, 1), v(0, 18.1, 0), FLUO, M.Neon),
		-- criss-cross escalators (slanted runs with dark steps and steel sides)
		part(v(12, 0.8, 2.6), v(-6, 3.5, -1), DARK, M.DiamondPlate, nil, CFrame.Angles(0, 0, math.rad(30))),
		part(v(12, 0.8, 2.6), v(6, 10, -1), DARK, M.DiamondPlate, nil, CFrame.Angles(0, 0, math.rad(-30))),
		part(v(12, 1.6, 0.4), v(-6, 4.3, -2.4), STEEL, M.Metal, nil, CFrame.Angles(0, 0, math.rad(30))),
		part(v(12, 1.6, 0.4), v(6, 10.8, -2.4), STEEL, M.Metal, nil, CFrame.Angles(0, 0, math.rad(-30))),
		part(v(16, 0.4, 3), v(0, 0.2, -6), TACTILE, M.SmoothPlastic), -- tactile strip in front of the gates
	}
	for _, x in { -14, -4.7, 4.7, 14 } do -- columns
		table.insert(parts, post(18, 1.4, v(x, 9, 2), STEEL, M.Metal))
	end
	for _, x in { -6, -2, 2, 6 } do -- ticket gate row (blank panels)
		table.insert(parts, part(v(0.8, 3, 3), v(x, 1.5, -4), hex("C9CCD0"), M.SmoothPlastic))
		table.insert(parts, part(v(0.9, 0.3, 0.6), v(x, 3.1, -5), TEAL, M.Neon))
	end
	return prop("ConcourseAtrium", v(30, 19, 16), parts, { Glow = FLUO })
end

-- Hero 2: a stalled subway car derailed across the platform, its plain end toward the road (the generator makes long
-- shapes along Z and the registry cannot turn a mesh): cream body, one teal band, dark windows, no numbers or logos.
local function stalledTrain()
	return prop("StalledTrain", v(6.3, 8, 13.2), {
		part(v(6, 5.6, 13), v(0, 4.4, 0), hex("DCD8CC"), M.Metal), -- body
		part(v(6.1, 1.6, 13.1), v(0, 2.6, 0), TEAL, M.SmoothPlastic), -- band
		part(v(6.1, 1.6, 10), v(0, 5.4, 0), hex("2A3138"), M.Glass), -- side windows
		part(v(6.3, 0.8, 13.2), v(0, 7.6, 0), STEEL, M.Metal), -- roof
		part(v(5, 1.2, 11), v(0, 0.6, 0), BED, M.Metal), -- bogies
	}, { Glow = FLUO })
end

-- Hero 3: the deep main platform hall: a long island platform piece with rows of grey columns, half-height platform
-- screen doors along the edge, a yellow tactile strip, benches, and a ceiling beam with fluorescent strips.
local function platformHall()
	local parts = {
		part(v(34, 1, 16), v(0, 0.5, 0), CONCRETE, M.Concrete), -- platform slab
		part(v(34, 0.1, 1.2), v(0, 1.05, -6.6), TACTILE, M.SmoothPlastic), -- tactile strip
		part(v(34, 1.2, 14), v(0, 12.4, 0), CONCRETE, M.Concrete), -- ceiling beam
		part(v(30, 0.2, 1), v(0, 11.7, -3), FLUO, M.Neon),
		part(v(30, 0.2, 1), v(0, 11.7, 3), FLUO, M.Neon),
		part(v(34, 0.6, 0.6), v(0, 4.7, -7.6), STEEL, M.Metal), -- screen door head rail
	}
	for _, x in { -14, -7, 0, 7, 14 } do
		table.insert(parts, post(10.8, 1.6, v(x, 6.4, -3), STEEL, M.Metal)) -- column rows
		table.insert(parts, post(10.8, 1.6, v(x, 6.4, 3), STEEL, M.Metal))
		table.insert(parts, part(v(5, 3.2, 0.2), v(x + 3.5, 2.6, -7.6), GLASS, M.Glass)) -- screen door panels
		table.insert(parts, part(v(0.5, 3.6, 0.5), v(x, 2.8, -7.6), STEEL, M.Metal))
	end
	for _, x in { -10.5, 3.5 } do
		table.insert(parts, part(v(4, 1.4, 1.4), v(x, 1.7, 0), hex("8A6E52"), M.WoodPlanks)) -- benches
	end
	return prop("PlatformHall", v(34, 13, 16), parts, { Glow = FLUO })
end

-- Hero 4: a collapsed escalator hall: an escalator truss tilted down from a broken ceiling, fallen ceiling panels,
-- a bent handrail and rubble at its foot.
local function collapsedEscalator()
	return prop("CollapsedEscalator", v(20, 13, 14), {
		part(v(20, 1, 14), v(0, 12.5, 2), CONCRETE, M.Concrete), -- broken ceiling slab
		part(v(16, 1.6, 4), v(0, 6, 0), DARK, M.DiamondPlate, nil, CFrame.Angles(0, 0, math.rad(-35))), -- truss
		part(v(16, 2, 0.4), v(0, 7.4, -2.1), STEEL, M.Metal, nil, CFrame.Angles(0.15, 0, math.rad(-35))), -- rail
		part(v(16, 2, 0.4), v(0, 7.4, 2.1), STEEL, M.Metal, nil, CFrame.Angles(-0.2, 0, math.rad(-38))),
		part(v(6, 0.6, 5), v(-6, 1.8, -3), CONCRETE, M.Concrete, nil, CFrame.Angles(0.3, 0.4, 0.2)), -- fallen panels
		part(v(5, 0.6, 4), v(5, 1.6, 3), hex("A8A49A"), M.Concrete, nil, CFrame.Angles(-0.2, 0.9, 0.3)),
		part(v(3, 2, 3), v(8, 1.8, -4), CONCRETE, M.Slate, nil, CFrame.Angles(0, 0.5, 0.2)), -- rubble
		part(v(2.4, 1.6, 2), v(-8.5, 1.2, 4), hex("A8A49A"), M.Slate, nil, CFrame.Angles(0.2, 0.3, 0)),
		part(v(8, 3, 0.8), v(0, 10, 6.5), TILE, M.CeramicTiles), -- tile wall chunk
		part(v(8, 0.6, 0.85), v(0, 9.6, 6.5), TEAL, M.SmoothPlastic),
		part(v(1.2, 0.6, 3), v(-4, 11.8, -2), RED, M.Neon), -- emergency light
	}, { Glow = RED })
end

-- Mid props (parts are the mesh fallbacks)
local column = prop("PlatformColumn", v(2, 16, 2), {
	post(16, 1.6, v(0, 8, 0), STEEL, M.Metal),
	part(v(2, 2, 2), v(0, 1, 0), TILE, M.CeramicTiles), -- tiled foot
	part(v(1.8, 0.6, 1.8), v(0, 5, 0), TEAL, M.SmoothPlastic), -- band
})
local screenDoor = prop("ScreenDoor", v(10, 5, 1), {
	part(v(10, 0.5, 1), v(0, 4.75, 0), STEEL, M.Metal), -- head rail
	part(v(4.4, 4.2, 0.2), v(-2.5, 2.3, 0), GLASS, M.Glass),
	part(v(4.4, 4.2, 0.2), v(2.5, 2.3, 0), GLASS, M.Glass),
	part(v(0.5, 4.5, 1), v(0, 2.25, 0), STEEL, M.Metal),
	part(v(0.5, 4.5, 1), v(-4.75, 2.25, 0), STEEL, M.Metal),
	part(v(0.5, 4.5, 1), v(4.75, 2.25, 0), STEEL, M.Metal),
})
local bench = prop("PlatformBench", v(6, 2.5, 2), {
	part(v(6, 0.4, 1.8), v(0, 1.4, 0), hex("8A6E52"), M.WoodPlanks),
	part(v(6, 1, 0.3), v(0, 2, 0.8), hex("8A6E52"), M.WoodPlanks),
	part(v(0.4, 1.2, 1.6), v(-2.4, 0.6, 0), STEEL, M.Metal),
	part(v(0.4, 1.2, 1.6), v(2.4, 0.6, 0), STEEL, M.Metal),
})
local vending = prop("VendingMachine", v(4, 7, 3), { -- blank: colour blocks only, no text or logo
	part(v(4, 7, 3), v(0, 3.5, 0), hex("D8DCE0"), M.SmoothPlastic),
	part(v(3, 3.4, 0.2), v(0, 4.6, -1.5), GLASS, M.Glass),
	part(v(3, 0.6, 0.2), v(0, 6.5, -1.5), TEAL, M.Neon),
	part(v(1, 1.6, 0.2), v(1, 1.8, -1.5), DARK, M.SmoothPlastic),
}, { Glow = FLUO })
local ticketGate = prop("TicketGates", v(10, 4, 3), {
	part(v(1, 3, 3), v(-4.5, 1.5, 0), hex("C9CCD0"), M.SmoothPlastic),
	part(v(1, 3, 3), v(-1.5, 1.5, 0), hex("C9CCD0"), M.SmoothPlastic),
	part(v(1, 3, 3), v(1.5, 1.5, 0), hex("C9CCD0"), M.SmoothPlastic),
	part(v(1, 3, 3), v(4.5, 1.5, 0), hex("C9CCD0"), M.SmoothPlastic),
	part(v(1.2, 0.3, 0.8), v(-4.5, 3.15, -1), TEAL, M.Neon),
	part(v(1.2, 0.3, 0.8), v(-1.5, 3.15, -1), TEAL, M.Neon),
	part(v(1.2, 0.3, 0.8), v(1.5, 3.15, -1), RED, M.Neon),
	part(v(1.2, 0.3, 0.8), v(4.5, 3.15, -1), TEAL, M.Neon),
	part(v(2, 1, 0.2), v(-3, 2, 0), hex("E05A3A"), M.SmoothPlastic), -- swing flaps
	part(v(2, 1, 0.2), v(3, 2, 0), hex("E05A3A"), M.SmoothPlastic),
})
-- Wall map: a board of abstract coloured lines and dots on the tiles (no text, no real line colours or map)
local wallMap = prop("WallMap", v(8, 10, 1), {
	part(v(0.4, 5, 0.4), v(-3.5, 2.5, 0.3), STEEL, M.Metal), -- legs (the board stands on the floor)
	part(v(0.4, 5, 0.4), v(3.5, 2.5, 0.3), STEEL, M.Metal),
	part(v(8, 5, 0.4), v(0, 7.5, 0.3), hex("F4F2EC"), M.SmoothPlastic),
	part(v(8.2, 0.3, 0.5), v(0, 10.1, 0.3), STEEL, M.Metal),
	part(v(6, 0.3, 0.1), v(0, 8.4, 0.05), TEAL, M.Neon),
	part(v(0.3, 3.6, 0.1), v(-1.5, 7.5, 0.05), TACTILE, M.SmoothPlastic),
	part(v(4, 0.3, 0.1), v(1, 6.5, 0.05), hex("6A7FD0"), M.SmoothPlastic, nil, CFrame.Angles(0, 0, 0.5)),
	part(v(0.8, 0.8, 0.1), v(2.5, 8.4, 0), RED, M.SmoothPlastic, BALL),
})
local rubble = prop("Rubble", v(8, 2, 6), {
	part(v(4, 0.6, 3), v(-1.5, 0.6, -0.5), CONCRETE, M.Concrete, nil, CFrame.Angles(0, 0.4, 0)),
	part(v(3, 1.4, 2.4), v(2, 1.1, 1), hex("A8A49A"), M.Slate, nil, CFrame.Angles(0, 0.7, 0)),
	part(v(2.4, 0.3, 2), v(-2.5, 0.8, 2), TILE, M.CeramicTiles, nil, CFrame.Angles(0, 0.2, 0)), -- broken tiles
	part(v(2, 1.2, 1.6), v(3, 1, -2), hex("74706A"), M.Slate, nil, CFrame.Angles(0, 1.1, 0)),
})
-- Surface: a street stair entrance down to the subway, a glass canopy over the steps, a plain colour band, no sign
local stairEntrance = prop("StairEntrance", v(12, 8, 8), {
	part(v(12, 1, 8), v(0, 0.5, 0), CONCRETE, M.Concrete),
	part(v(8, 0.6, 6), v(0, 0.6, 0.5), BED, M.Concrete), -- the stair well
	part(v(0.6, 3, 7), v(-4.5, 2.5, 0.5), STEEL, M.Metal), -- side walls
	part(v(0.6, 3, 7), v(4.5, 2.5, 0.5), STEEL, M.Metal),
	part(v(9.6, 0.4, 7.6), v(0, 7.6, 0.5), GLASS, M.Glass), -- canopy
	part(v(10, 0.6, 0.6), v(0, 7.1, -3.5), TEAL, M.SmoothPlastic), -- colour band, no text
	post(7, 0.5, v(-4.6, 3.5, -3.4), STEEL, M.Metal),
	post(7, 0.5, v(4.6, 3.5, -3.4), STEEL, M.Metal),
	part(v(2, 0.3, 0.2), v(0, 6.4, -3.6), FLUO, M.Neon),
}, { Glow = FLUO })

-- Parts-only props
local emergencyLight = prop("EmergencyLight", v(2, 9, 1), {
	part(v(0.3, 7.5, 0.3), v(0, 3.75, 0.3), DARK, M.Metal), -- conduit down to the floor (the prop stands on it)
	part(v(1.6, 1, 0.8), v(0, 8, 0.1), DARK, M.Metal),
	part(v(1.2, 0.6, 0.3), v(0, 7.8, -0.35), RED, M.Neon),
})
local fireCabinet = block("FireCabinet", v(3, 5, 1), RED, M.Metal, {
	part(v(2.4, 3, 0.1), v(0, 3, -0.5), hex("D8443A"), M.Glass),
})
local ventGrille = block("VentGrille", v(6, 3, 1), DARK, M.DiamondPlate, {
	part(v(6.2, 0.3, 1.1), v(0, 3, 0), STEEL, M.Metal),
})
local ventStack = prop("VentStack", v(8, 7, 8), { -- surface air shaft
	part(v(8, 5, 8), v(0, 2.5, 0), CONCRETE, M.Concrete),
	part(v(7, 1.6, 7), v(0, 5.8, 0), DARK, M.DiamondPlate),
	part(v(8.4, 0.4, 8.4), v(0, 6.8, 0), STEEL, M.Metal),
})
local streetPost = prop("StreetPost", v(3, 12, 3), { -- surface street lamp
	post(12, 0.6, v(0, 6, 0), DARK, M.Metal),
	part(v(2.4, 0.5, 1), v(-0.8, 11.8, 0), DARK, M.Metal),
	part(v(1.6, 0.3, 0.8), v(-1.2, 11.5, 0), FLUO, M.Neon),
})

-- Mesh props (Lane A); sizes keep each mesh's own proportions unless a comment says it is stretched. Benches,
-- vending machines and ticket gates face +Z (away from the road), so they are scatter props only (random yaw).
local columnMesh = meshed(column, "PlatformColumnMesh", v(2, 11.5, 2)) -- mesh 2 x 3.83 x 2, stretched x3 up
local screenDoorMesh = meshed(screenDoor, "ScreenDoorMesh", v(5.8, 3.9, 1)) -- mesh 3.88 x 3.92 x 1, stretched x1.5 wide
local benchMesh = meshed(bench, "PlatformBenchMesh", v(3.74, 2.5, 1.79))
local vendingMesh = meshed(vending, "VendingMachineMesh", v(4, 6.25, 2.78))
local ticketGateMesh = meshed(ticketGate, "TicketGatesMesh", v(5.26, 4, 1.97))
local wallMapMesh = meshed(wallMap, "WallMapMesh", v(6.4, 6.08, 1))
local rubbleMesh = meshed(rubble, "RubbleMesh", v(3.82, 3.2, 3.88)) -- mesh 2.39 x 2 x 2.43, x1.6
local entranceMesh = meshed(stairEntrance, "StairEntranceMesh", v(8.19, 8, 5.14))

-- Mesh rows: generated in Studio (Lane A) with the stored prompt; each mesh's own generated texture is a Texture row
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups are in assets/biomes/Desert/review/.
-- Notes give the generate_mesh call: size (studs) and segmentation, and the mesh's own size; Tris is its maxTriangles.
local function meshRow(id, texture, prompt, tris, notes)
	return { Kind = "Mesh", Id = id, Lane = "A", Prompt = prompt, Texture = texture, Tris = tris, Notes = notes }
end
local function textureRow(id, mesh)
	return { Kind = "Texture", Id = id, Lane = "A", Prompt = "generated with " .. mesh .. " (same prompt)" }
end

-- Tunnel bays (spec 7, Track 7; fractions of the 11,245-stud track)
-- orchestrator default 2026-10-31: the concourse bay is Left (Both reached Track 6's corridor, fw5)
local BAYS = {
	{ From = 0.12, To = 0.17, Side = "Left", Depth = 40, Height = 30 }, -- first side platform
	{ From = 0.33, To = 0.40, Side = "Left", Depth = 60, Height = 40 }, -- concourse and atrium void
	{ From = 0.58, To = 0.63, Side = "Right", Depth = 40, Height = 30 }, -- second platform, stalled train
	{ From = 0.82, To = 0.90, Side = "Both", Depth = 50, Height = 30 }, -- deep main platform hall
}

return {
	DisplayName = "Shibuyo Underground",
	Ground = { Color = CONCRETE, Material = M.Concrete },
	Sky = { Color = hex("1A2224") },
	-- orchestrator default 2026-10-31: the framework gate (beam 28 high) cannot fit under the 20-stud ceiling, so it
	-- stands in the open in front of the start portal (waypoint 2, about 10 studs from the start; the portal face is
	-- at 16) and reads as the portal's frame, in its concrete colour
	Gate = gate(CONCRETE, M.Concrete, FLUO, { Index = 2 }),
	Tunnel = {
		Width = 60,
		Height = 20,
		Wall = { Material = M.CeramicTiles, Color = "#E9E4D6", Stripe = "#3FA7A0" },
		Ceiling = { Material = M.Concrete, Color = "#8C8A84" },
		Floor = { Material = M.Concrete, Color = "#8C8A84" },
		LightEvery = 24,
		Bays = BAYS,
		Portals = true,
	},
	-- Wall-hugging props between the road clearance and the tunnel wall (28-30 studs from the centre line)
	Rhythm = {
		Every = 6,
		Offset = 6,
		Props = { wallMapMesh, emergencyLight, fireCabinet, ventGrille },
	},
	-- Pinned heroes (At, spec 4.3), each inside its bay (fw6: a pinned hero takes the covering bay's side). Offset 10
	-- puts a hero's road face 32 studs from the centre line, on the bay platform (30 out to the bay wall).
	-- At values: 0.16 = the 462-stud straight in the first platform (0.155-0.196); 0.36 = the 572-stud concourse
	-- straight (0.348-0.399); 0.6 = the 496-stud straight in the second platform (0.565-0.609); 0.83 = the 330-stud
	-- straight in the main hall (0.811-0.840).
	-- Heights at x1.75 stay under each bay's ceiling less its 4-stud platform (26 in platforms and the hall, 36 in the
	-- concourse); depths stay inside the bay.
	Landmarks = {
		Offset = 10,
		Every = 60,
		Props = {
			-- mesh 5.9 x 10.76 x 14, x1.1 (x1.75: 11.4 x 20.7 x 27); runs down toward the road. x1.3 did not fit: the first
			-- platform sits on the ramp, which eats headroom
			meshed(collapsedEscalator(), "CollapsedEscalatorMesh", v(6.5, 11.8, 15.4), { Hero = true, At = 0.16 }),
			-- mesh 24.85 x 19 x 9.49, own size (x1.75: 43.5 x 33.25 x 16.6)
			meshed(concourseAtrium(), "ConcourseAtriumMesh", v(24.85, 19, 9.49), { Hero = true, At = 0.36 }),
			-- mesh 6.31 x 8 x 13.2, x1.5 (x1.75: 16.6 x 21 x 34.7)
			meshed(stalledTrain(), "StalledTrainMesh", v(9.47, 12, 19.8), { Hero = true, At = 0.6 }),
			-- mesh 17.07 x 13 x 9.98, x1.1 (x1.75: 32.9 x 25 x 19.2)
			meshed(platformHall(), "PlatformHallMesh", v(18.8, 14.3, 11), { Hero = true, At = 0.83 }),
		},
	},
	-- Surface (earth over the roof): sparse stair entrances, air shafts and street lamps
	Horizon = {
		Surface = true,
		Offset = 18,
		Props = { entranceMesh, ventStack, streetPost },
	},
	-- Platform clutter in the bays
	Scatter = {
		Every = 3,
		Near = 8,
		Far = 40,
		Props = { columnMesh, benchMesh, screenDoorMesh, rubbleMesh, vendingMesh, ticketGateMesh },
		Patches = {
			patch("TactileStrip", 12, 1.2, TACTILE, M.SmoothPlastic),
			patch("BrokenTiles", 8, 6, TILE, M.CeramicTiles),
			patch("Puddle", 6, 4, hex("3A4A50"), M.Glass),
		},
	},
	-- No landmark emitters (the zone dust below is enough in the enclosed tunnel)
	-- Spec 3.5 option A / 7: the ridge stays solid earth over the tunnel (Ground, Rock cliffs). No Grass under the road
	-- (lesson b). Embank off. Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Hills", Height = 14, Noise = 0.03, Amp = 4 },
		Materials = { Corridor = M.Ground, Ridge = M.Ground, Cliff = M.Rock, Bed = M.Rock },
		CliffSlope = 0.9,
		Embank = false,
	},
	-- Spec 3.5 / 5.2 / 7: underground, lit only by the tunnel strips and Ambient. Values from section 7; the rest are
	-- placeholders. The plain dark skybox (in-house, 6 faces) only shows through the portals.
	Atmosphere = Kit.Atmosphere({
		Underground = true,
		Lighting = {
			ClockTime = 0,
			Brightness = 0,
			Ambient = hex("3A4A48"),
			OutdoorAmbient = hex("1A2224"),
			EnvironmentDiffuseScale = 0.2,
			EnvironmentSpecularScale = 0.2,
		},
		Atmosphere = { Density = 0.3, Offset = 0, Color = hex("2A3532"), Decay = hex("1A2224"), Glare = 0, Haze = 1 },
		Grade = { Saturation = -0.02, Contrast = 0.3, TintColor = hex("E6FFF4") }, -- baseline 0.18 - 0.2, 0.15 + 0.15
		Bloom = { Intensity = 1.0, Threshold = 0.9 }, -- the light strips glow
		SunRays = { Intensity = 0 },
		Sky = { Skybox = "SkyUnderground", StarCount = 0, CelestialBodiesShown = false },
		Clouds = { Cover = 0, Density = 0, Color = hex("1A2224") },
		Particles = {
			{
				Texture = "DustParticle", -- slow dust motes in the light strips
				Color = hex("D8D2C0"),
				Size = 0.35,
				Rate = 10,
				Lifetime = 8,
				Speed = 0.3,
				SpreadAngle = 180,
				LightEmission = 0.15,
				Area = v(80, 16, 80),
			},
		},
	}),
	Audio = {
		Loop = "AmbTunnelHum",
		OneShots = { "SfxTrainRumble", "SfxChime" },
		Volume = 0.3,
		Reverb = "StoneCorridor",
	},
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Sound rows: Creator Store audio ids used directly (no insert, nothing to strip); creator, free and public-domain
	-- checked on economy.roblox.com asset details 2026-10-31.
	Assets = {
		CollapsedEscalatorMesh = meshRow(
			"rbxassetid://95717321326261",
			"CollapsedEscalatorTex",
			"broken escalator lying diagonally from a high concrete landing down to the floor, metal steps visible, black rubber handrails on grey metal side panels, the landing slab cracked and tilted, grey concrete chunks and broken cream tiles piled around its foot, plain surfaces with no markings, no signs, no text, stylized cartoon style",
			15000,
			"hero 4 (At 0.16, first platform): generate_mesh size 20 x 13 x 14, segmentation none; second try (the first had odd marks under a slab); mesh 5.9 x 10.76 x 14"
		),
		ConcourseAtriumMesh = meshRow(
			"rbxassetid://117670017289451",
			"ConcourseAtriumTex",
			"box shaped multi level underground concourse hall, two straight concrete balcony levels on grey steel columns, two escalators crossing each other in an X between the levels, glass balcony rails, fluorescent light strips under each level, cream tiled back wall with one teal stripe, a row of plain grey ticket gates in front, rectangular not round, no signs, no text, no logo, stylized cartoon style",
			15000,
			"hero 1 (At 0.36, concourse): generate_mesh size 30 x 19 x 16, segmentation none; open side faces -Z; box void only, never an oval atrium; mesh 24.85 x 19 x 9.49"
		),
		StalledTrainMesh = meshRow(
			"rbxassetid://114093523046760",
			"StalledTrainTex",
			"one generic boxy subway train car, long body running front to back, plain cream metal sides with one teal band and a row of dark side windows and sliding doors, flat grey roof, dark wheel bogies, both ends are flat plain cream walls with a single narrow closed grey door in the middle and no windows and no lights, no numbers, no letters, no logo, stylized cartoon style",
			12000,
			"hero 2 (At 0.6, second platform): generate_mesh size 7 x 8 x 16, segmentation none; fourth try (the generator makes long shapes along Z; earlier cab ends had a big window under two lamps, a face risk); plain end faces -Z; mesh 6.31 x 8 x 13.2"
		),
		PlatformHallMesh = meshRow(
			"rbxassetid://72257775317628",
			"PlatformHallTex",
			"long island subway platform section, grey concrete platform floor with a yellow tactile strip along the front edge, two rows of slim grey steel columns, half height glass platform screen doors along the edge, two wooden benches, a concrete ceiling beam with fluorescent light strips, no signs, no text, stylized cartoon style",
			15000,
			"hero 3 (At 0.83, main hall): generate_mesh size 34 x 13 x 16, segmentation none; screen doors face -Z; mesh 17.07 x 13 x 9.98"
		),
		PlatformColumnMesh = meshRow(
			"rbxassetid://74635002549927",
			"PlatformColumnTex",
			"slim grey steel subway platform column, round shaft on a square cream tiled foot, one teal painted band, stylized low poly cartoon style",
			600,
			"mid: generate_mesh size 2 x 16 x 2, segmentation none; mesh 2 x 3.83 x 2"
		),
		ScreenDoorMesh = meshRow(
			"rbxassetid://85305644705712",
			"ScreenDoorTex",
			"half height subway platform screen door section, two glass sliding panels in a grey steel frame with a steel head rail, no text, stylized low poly cartoon style",
			1000,
			"mid: generate_mesh size 10 x 5 x 1, segmentation none; faces -Z; mesh 3.88 x 3.92 x 1"
		),
		PlatformBenchMesh = meshRow(
			"rbxassetid://95311727005276",
			"PlatformBenchTex",
			"simple subway platform bench, wooden slat seat and backrest on two grey steel legs, stylized low poly cartoon style",
			800,
			"mid: generate_mesh size 6 x 2.5 x 2, segmentation none; seat faces +Z (scatter only); mesh 3.74 x 2.5 x 1.79"
		),
		VendingMachineMesh = meshRow(
			"rbxassetid://86163788454964",
			"VendingMachineTex",
			"plain blank vending machine, light grey metal cabinet, a glass front window showing rows of small colourful boxes, a teal light strip at the top, a dark slot at the bottom, no logo, no letters, no text, stylized low poly cartoon style",
			1200,
			"mid: generate_mesh size 4 x 7 x 3, segmentation none; second prompt (the first failed moderation); front faces +Z (scatter only), blank labels; mesh 4 x 6.25 x 2.78"
		),
		TicketGatesMesh = meshRow(
			"rbxassetid://136019329692135",
			"TicketGatesTex",
			"four waist high long grey station ticket gate cabinets standing in a parallel row with narrow walkways between them, short flat red paddle barriers sticking sideways into each walkway, a small flat teal light panel on top of each cabinet, plain with no signs and no text, stylized low poly cartoon style",
			1500,
			"mid: generate_mesh size 10 x 4 x 5, segmentation none; second try (the first read as phone handsets); paddles face +Z (scatter only); mesh 5.26 x 4 x 1.97"
		),
		WallMapMesh = meshRow(
			"rbxassetid://117284770195643",
			"WallMapTex",
			"standing information board on two short grey metal legs, a solid flat white rectangular panel in a thin grey frame, the panel face printed with a few smooth abstract coloured stripes and round dots only, teal, yellow and blue stripes, no letters, no words, no numbers, no logo, stylized low poly cartoon style",
			600,
			"mid: generate_mesh size 8 x 8 x 1, segmentation none; second try (the first was an open frame with no panel); abstract swooshes only, never a real line map; faces -Z; mesh 6.4 x 6.08 x 1"
		),
		RubbleMesh = meshRow(
			"rbxassetid://129012579914034",
			"RubbleTex",
			"small pile of broken grey concrete chunks, a fallen ceiling panel and broken cream tiles, stylized low poly cartoon style",
			800,
			"mid: generate_mesh size 8 x 2 x 6, segmentation none; mesh 2.39 x 2 x 2.43"
		),
		StairEntranceMesh = meshRow(
			"rbxassetid://95781847098590",
			"StairEntranceTex",
			"street level stair entrance down to an underground railway, concrete base, steps going down between grey steel side walls, a flat glass canopy on four thin posts, one plain teal colour band, no sign, no letters, no logo, stylized low poly cartoon style",
			3000,
			"surface: generate_mesh size 12 x 8 x 8, segmentation none; reads as a glass canopy kiosk; mesh 8.19 x 8 x 5.14"
		),
		CollapsedEscalatorTex = textureRow("rbxassetid://75156016092304", "CollapsedEscalatorMesh"),
		ConcourseAtriumTex = textureRow("rbxassetid://130300687469660", "ConcourseAtriumMesh"),
		StalledTrainTex = textureRow("rbxassetid://70667078539368", "StalledTrainMesh"),
		PlatformHallTex = textureRow("rbxassetid://98442300433706", "PlatformHallMesh"),
		PlatformColumnTex = textureRow("rbxassetid://134730479076036", "PlatformColumnMesh"),
		ScreenDoorTex = textureRow("rbxassetid://109098640807472", "ScreenDoorMesh"),
		PlatformBenchTex = textureRow("rbxassetid://115541908054893", "PlatformBenchMesh"),
		VendingMachineTex = textureRow("rbxassetid://74284002497401", "VendingMachineMesh"),
		TicketGatesTex = textureRow("rbxassetid://90339791416430", "TicketGatesMesh"),
		WallMapTex = textureRow("rbxassetid://77806575378984", "WallMapMesh"),
		RubbleTex = textureRow("rbxassetid://77033815446802", "RubbleMesh"),
		StairEntranceTex = textureRow("rbxassetid://97946062884952", "StairEntranceMesh"),
		DustParticle = {
			Kind = "Texture",
			Id = "rbxassetid://77443196483447",
			Lane = "A",
			Prompt = "in-house 128 px soft irregular dust speck with a slightly brighter core, white on transparent, tinted pale grey by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/Desert/draw_textures.py, dust_particle.png), uploaded from Studio 2026-10-31",
		},
		-- Faces drawn in-house with numpy (assets/biomes/Desert/sky/SkyUnderground<Face>.png): plain near-black
		-- blue-grey, no shapes or text. No Creator Store skybox (docs/BUGS.md creator-store-backdoor-skybox). Uploaded
		-- from Studio 2026-10-31; Id is the Bk face.
		SkyUnderground = {
			Kind = "Skybox",
			Id = "rbxassetid://126814177699454",
			Faces = {
				Bk = "rbxassetid://126814177699454",
				Dn = "rbxassetid://90423288718397",
				Ft = "rbxassetid://91385232590200",
				Lf = "rbxassetid://119320290687932",
				Rt = "rbxassetid://98579734251070",
				Up = "rbxassetid://89593505205012",
			},
			Lane = "A",
			Prompt = "in-house plain dark underground skybox, 6 faces 1024 px, near-black blue-grey with a faint lighter band low on the sides",
			Notes = "drawn with python3 + numpy (assets/biomes/Desert/draw_textures.py)",
		},
		AmbTunnelHum = {
			Kind = "Sound",
			Id = "rbxassetid://9112795463",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112795463: Hollow Rumble 1, deep steady drone, dark, loop, 106 s (tunnel hum and ventilation drone)",
		},
		SfxTrainRumble = {
			Kind = "Sound",
			Id = "rbxassetid://9117150616",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9117150616: old elevated train pass-by, track clack, metal rattle, brake squeal, 30 s (a distant train rumble; no announcement)",
		},
		SfxChime = {
			Kind = "Sound",
			Id = "rbxassetid://9125491593",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9125491593: Door Chimes Various Tone Sequences Door Bell, generic tone sequence, 5 s (a made-up chime; never a real station melody)",
		},
	},
}
