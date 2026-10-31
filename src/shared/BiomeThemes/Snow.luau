--!nonstrict
-- Track 8: Skypeia (owner redesign 2026-10-31; the key `Snow` is historical). A sky nation on a white cloud sea: a cloud
-- beach and a town of round white domed houses, a cloud river, a giant jungle island, sunken stepped stone ruins at the
-- root of a giant beanstalk, and high island clouds with a giant plain golden bell in a broken belfry.
-- Data only (format in Kit). b2 (docs/BIOME_ENVIRONMENT_SPEC.md section 7, Track 8). Mesh props keep their part
-- fallback (spec 4.2), scaled to the mesh's size. Every shape here is generic and original.
-- IP (spec 7, hard rules): no hat or skull-and-crossbones symbol, no character likeness anywhere in the scenery (no
-- drum ring), no shrine nameplate or gate sign text, no ark ship copy, no ancient-script stone blocks, no idol head on
-- any gate; the bell is plain, without inscription. No legible text anywhere.
--
-- Placement (orchestrator default 2026-10-31):
-- - Dressing layers are per biome, not per section, so cloud-town and jungle props mix along the whole route; the
--   terrain sections carry the change of scene.
-- - Small props (Rhythm, Scatter, the padded cloud house) stay inside 44 studs of the centre line, on corridor ground.
-- - Big props (Landmarks, Horizon, Blocks) start 60 studs out (past the 44-60 shoulder, where padded footprints can
--   float) and are at most about 21 studs deep, so they stay near this zone's half of the gap (midline about 77) and
--   well clear of the neighbours' corridors (Track 7's tunnel starts about 111 out).
-- - On the Drop stretches (0.28-0.30, 0.80-1.0) the ground past 60 is the cloud deck at -40: props there rise out of
--   the clouds.
local Kit = require(script.Parent.Kit)

local M, hex, v, BALL, CYL, part, post, prop, block, ball, gate, patch, giants, particles =
	Kit.M,
	Kit.hex,
	Kit.v,
	Kit.BALL,
	Kit.CYL,
	Kit.part,
	Kit.post,
	Kit.prop,
	Kit.block,
	Kit.ball,
	Kit.gate,
	Kit.patch,
	Kit.giants,
	Kit.particles

-- Palette (spec 7, placeholders)
local CLOUD = hex("FFFFFF")
local CLOUD_SHADE = hex("E6EEF8")
local SKY = hex("6EC6FF")
local JUNGLE = hex("2F7D3B")
local BARK = hex("6B4A2E")
local STALK = hex("9DBF5A")
local GOLD = hex("E3B341")
local RUIN = hex("B9A88A")
local DARK_STALK = hex("6F9440")
local VINE = hex("3E6B2E")
local TRIM_PINK = hex("F4B8C8")
local TRIM_BLUE = hex("9CCFF0")
local DARK_RUIN = hex("8E7F66")
local MOTE = hex("F2E8A8")
local BAND = CFrame.Angles(0, 0, math.pi / 2) -- a Cylinder's axis is X; this lays a disk flat

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

local function add(parts, more)
	for _, p in more do
		table.insert(parts, p)
	end
	return parts
end

-- A round white cloud house `d` across at `o`: a ball body, a domed cap, a pastel trim band, a door and a round window
-- on the road face (-Z)
local function cloudHouse(d, trim, o)
	o = o or v(0, 0, 0)
	return {
		part(v(d, d, d), o + v(0, d * 0.4, 0), CLOUD, M.SmoothPlastic, BALL),
		part(v(d * 0.55, d * 0.55, d * 0.55), o + v(0, d * 0.82, 0), CLOUD_SHADE, M.SmoothPlastic, BALL), -- dome cap
		part(v(d * 0.08, d * 1.02, d * 1.02), o + v(0, d * 0.5, 0), trim, M.SmoothPlastic, CYL, BAND), -- trim band
		part(v(d * 0.22, d * 0.32, 0.4), o + v(0, d * 0.16, -d * 0.47), trim, M.SmoothPlastic), -- door
		part(v(d * 0.14, d * 0.14, d * 0.14), o + v(d * 0.26, d * 0.45, -d * 0.4), SKY, M.Glass, BALL), -- round window
	}
end

-- Hero 1: the giant beanstalk. Two twisted green stems wind round each other up into a cloud, broad leaves on the way.
local function beanstalk()
	local h, steps = 126, 9
	local seg = (h - 14) / steps
	local parts = { part(v(5, 3, 5), v(0, 1.5, 0), DARK_STALK, M.Grass) } -- root knot
	for i = 0, steps - 1 do
		local y, a = (i + 0.5) * seg, i * 0.9
		local w, r = 4.2 - i * 0.2, 2.4 - i * 0.12
		for s = 0, 1 do
			local ang = a + s * math.pi
			table.insert(
				parts,
				part(
					v(w, seg + 2, w),
					v(math.cos(ang) * r, y, math.sin(ang) * r),
					s == 0 and STALK or DARK_STALK,
					M.Grass,
					nil,
					CFrame.Angles(math.sin(ang) * 0.18, 0, math.cos(ang) * 0.18)
				)
			)
		end
		if i % 2 == 1 then -- a broad leaf
			table.insert(
				parts,
				part(
					v(7, 0.6, 4),
					v(math.cos(a) * 5, y + 2, math.sin(a) * 4),
					STALK,
					M.Grass,
					nil,
					CFrame.Angles(0, -a, 0.35)
				)
			)
		end
	end
	return prop(
		"GiantBeanstalk",
		v(16, h, 12),
		add(parts, {
			part(v(12, 12, 12), v(0, h - 6, 0), CLOUD, M.SmoothPlastic, BALL), -- the cloud it grows into
			part(v(9, 9, 9), v(-3.5, h - 10, 1), CLOUD_SHADE, M.SmoothPlastic, BALL),
			part(v(9, 9, 9), v(3.5, h - 9, -1), CLOUD, M.SmoothPlastic, BALL),
		})
	)
end

-- Hero 2: sunken golden ruins. Stepped stone temple tiers (a generic stepped-pyramid shape), a central stair, vines,
-- a few gold-clad wall panels and two broken gold pillars. Plain faces: no script blocks, no idol head.
local function sunkenRuins()
	return prop("SunkenRuins", v(24, 36, 12), {
		part(v(24, 6, 12), v(0, 3, 0), RUIN, M.Sandstone),
		part(v(19, 6, 10), v(0, 9, 0.5), RUIN, M.Sandstone),
		part(v(14, 6, 8), v(0, 15, 1), DARK_RUIN, M.Sandstone),
		part(v(9, 6, 6), v(0, 21, 1.5), RUIN, M.Sandstone),
		part(v(6, 5, 5), v(0, 26.5, 1.5), RUIN, M.Sandstone), -- shrine block on top
		part(v(6.2, 0.8, 5.2), v(0, 29.4, 1.5), GOLD, M.Metal), -- gold roof slab
		part(v(5, 26, 0.6), v(0, 12, -3.5), DARK_RUIN, M.Slate, nil, CFrame.Angles(-0.45, 0, 0)), -- central stair
		part(v(6, 4, 0.4), v(-8, 3, -6.2), GOLD, M.Metal), -- gold-clad wall panels
		part(v(5, 4, 0.4), v(6.5, 9, -4.7), GOLD, M.Metal),
		part(v(3, 3, 0.4), v(-4.5, 15, -3.2), GOLD, M.Metal),
		post(10, 1.8, v(-10.5, 11, -4), GOLD, M.Metal), -- broken gold pillars
		post(6, 1.8, v(10.5, 9, -4), GOLD, M.Metal),
		part(v(0.5, 10, 0.5), v(-5, 7, -6.3), VINE, M.Grass), -- vines down the tiers
		part(v(0.5, 8, 0.5), v(8, 13, -4.6), VINE, M.Grass),
		part(v(0.5, 7, 0.5), v(3, 18, -3.2), VINE, M.Grass),
		part(v(24.4, 1, 12.4), v(0, 6, 0), JUNGLE, M.Grass), -- moss on the first ledge
		post(4, 1.6, v(0, 33.8, 1.5), GOLD, M.Metal), -- a plain gold spire stump
	})
end

-- Hero 3: a giant plain golden bell in a broken stone belfry, on a small island cloud high over the cloud sea
-- (BiomeBob). The cloud body reaches down into the deck; the bell hangs from a cracked beam. No inscription.
local function goldenBell()
	return prop("GoldenBell", v(14, 48, 12), {
		part(v(8, 8, 8), v(0, 4, 0), CLOUD_SHADE, M.SmoothPlastic, BALL), -- cloud body, narrowing downward
		part(v(10, 10, 10), v(0, 11, 0), CLOUD, M.SmoothPlastic, BALL),
		part(v(12, 12, 12), v(0, 18, 0), CLOUD, M.SmoothPlastic, BALL),
		part(v(14, 3, 12), v(0, 26.5, 0), CLOUD, M.SmoothPlastic), -- flat top to stand the belfry on
		part(v(12, 1.2, 9), v(0, 28.6, 0), RUIN, M.Sandstone), -- belfry floor
		part(v(2, 16, 2), v(-5, 37, 0), RUIN, M.Sandstone), -- two stone posts, one broken lower
		part(v(2, 12, 2), v(5, 35, 0), DARK_RUIN, M.Sandstone),
		part(v(13, 1.6, 2.4), v(0, 45.8, 0), RUIN, M.Sandstone, nil, CFrame.Angles(0, 0, -0.06)), -- cracked beam
		part(v(0.5, 3, 0.5), v(0, 43.5, 0), BARK, M.Wood), -- hanger
		part(v(4, 2, 4), v(0, 41, 0), GOLD, M.Metal, BALL), -- bell crown
		part(v(7, 7, 7), v(0, 37.5, 0), GOLD, M.Metal, BALL), -- plain bell body
		part(v(1.2, 8, 8), v(0, 34.4, 0), GOLD, M.Metal, CYL, BAND), -- flared lip
		part(v(0.5, 10, 0.5), v(-5.6, 38, -1.1), VINE, M.Grass), -- vines over the belfry
		part(v(0.5, 6, 0.5), v(4, 42, 1.1), VINE, M.Grass),
	}, { Tag = "BiomeBob", Glow = GOLD })
end

-- Hero 4: the cloud town. A cluster of round white domed houses with pastel trims round a taller round tower.
local function cloudTown()
	local parts = {
		part(v(24, 2, 12), v(0, 1, 0), CLOUD, M.SmoothPlastic), -- cloud ground
		post(22, 8, v(0, 13, 2), CLOUD, M.SmoothPlastic), -- round tower
		part(v(9, 9, 9), v(0, 25, 2), CLOUD_SHADE, M.SmoothPlastic, BALL), -- its dome
		part(v(1.2, 4, 1.2), v(0, 31, 2), TRIM_BLUE, M.SmoothPlastic), -- plain finial
	}
	add(parts, cloudHouse(9, TRIM_PINK, v(-7.5, 2, -1)))
	add(parts, cloudHouse(8, TRIM_BLUE, v(7.5, 2, -1.5)))
	add(parts, cloudHouse(6, TRIM_PINK, v(-2, 2, -3)))
	return prop("CloudTown", v(24, 34, 12), parts, { Pad = true })
end

-- Mid props
-- A row of small round white dome cottages on a flat cloud base (the CloudHouseMesh shape): a building, so Pad
local cloudCottages = prop("CloudCottages", v(13, 4.1, 12), {
	part(v(13, 1, 12), v(0, 0.5, 0), CLOUD, M.SmoothPlastic),
	part(v(3.6, 3.6, 3.6), v(-4.5, 2, 0), CLOUD, M.SmoothPlastic, BALL),
	part(v(3.6, 3.6, 3.6), v(-1.5, 2, 2), CLOUD_SHADE, M.SmoothPlastic, BALL),
	part(v(3.6, 3.6, 3.6), v(1.5, 2, -1), CLOUD, M.SmoothPlastic, BALL),
	part(v(3.6, 3.6, 3.6), v(4.5, 2, 1.5), CLOUD_SHADE, M.SmoothPlastic, BALL),
	part(v(13.2, 0.3, 0.3), v(0, 3.2, -2), TRIM_BLUE, M.SmoothPlastic),
}, { Pad = true })
local skyPalm = prop("SkyPalm", v(7, 12.2, 7), {
	post(11, 0.9, v(0, 5.5, 0), BARK, M.Wood),
	part(v(7, 0.4, 2), v(0, 11.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, 0, 0.3)),
	part(v(7, 0.4, 2), v(0, 11.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, math.pi / 2, 0.3)),
	part(v(7, 0.4, 2), v(0, 11.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, math.pi, 0.3)),
	part(v(7, 0.4, 2), v(0, 11.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, -math.pi / 2, 0.3)),
	part(v(3, 3, 3), v(0.6, 0.6, 0), CLOUD, M.SmoothPlastic, BALL), -- a cloud puff at its foot
})
local brokenPillar = prop("BrokenPillar", v(3.4, 10, 3.4), {
	part(v(3.4, 1, 3.4), v(0, 0.5, 0), RUIN, M.Sandstone),
	post(5, 2.4, v(0, 3.5, 0), RUIN, M.Sandstone),
	post(3.5, 2.4, v(0, 7.75, 0), GOLD, M.Metal), -- the gold-clad upper half
	part(v(2.2, 1.4, 2.2), v(0.3, 9.3, 0), GOLD, M.Metal, nil, CFrame.Angles(0.3, 0, 0.2)), -- broken top
	part(v(0.4, 6, 0.4), v(1.1, 5, -1.1), VINE, M.Grass),
})
local giantFern = prop("GiantFern", v(8, 5, 8), {
	part(v(7, 0.4, 2), v(0, 2.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, 0, 0.5)),
	part(v(7, 0.4, 2), v(0, 2.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, math.pi / 3, 0.5)),
	part(v(7, 0.4, 2), v(0, 2.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, 2 * math.pi / 3, 0.5)),
	part(v(7, 0.4, 2), v(0, 2.6, 0), JUNGLE, M.Grass, nil, CFrame.Angles(0, math.pi, 0.5)),
	part(v(2, 1.6, 2), v(0, 0.8, 0), VINE, M.Grass),
})
-- A giant jungle tree: buttress roots, a tall trunk, a broad flat crown, hanging vines
local jungleTree = prop("JungleTree", v(16, 51, 10), {
	post(34, 3.6, v(0, 17, 0), BARK, M.Wood),
	part(v(7, 6, 1.2), v(-3, 3, 0), BARK, M.Wood, nil, CFrame.Angles(0, 0, 0.5)), -- buttress roots
	part(v(7, 6, 1.2), v(3, 3, 0), BARK, M.Wood, nil, CFrame.Angles(0, 0, -0.5)),
	part(v(1.2, 6, 7), v(0, 3, -2.5), BARK, M.Wood, nil, CFrame.Angles(0.5, 0, 0)),
	part(v(16, 8, 10), v(0, 40, 0), JUNGLE, M.Grass),
	part(v(10, 10, 10), v(-3, 46, 0), JUNGLE, M.Grass, BALL),
	part(v(9, 9, 9), v(4, 45, 0), hex("3A8F45"), M.Grass, BALL),
	part(v(0.5, 14, 0.5), v(-6, 31, -3), VINE, M.Grass),
	part(v(0.5, 10, 0.5), v(5, 33, 3), VINE, M.Grass),
})
-- A cloud-river ribbon beside the road: a long, low translucent white band along the road (X), visual only
local cloudRiver = prop("CloudRiver", v(24, 1.6, 5), {
	part(v(24, 0.8, 5), v(0, 0.4, 0), CLOUD_SHADE, M.Glass),
	part(v(8, 1.6, 3), v(-6, 0.8, 0.5), CLOUD, M.SmoothPlastic, BALL),
	part(v(6, 1.4, 3), v(7, 0.7, -0.5), CLOUD, M.SmoothPlastic, BALL),
})
-- Cloud puffs hanging in the air (BiomeBob): over the jungle they float above the hills, on the Drop over the deck
local cloudPuffs = prop("CloudPuffs", v(16, 56, 10), {
	part(v(10, 10, 10), v(-3, 47, 0), CLOUD, M.SmoothPlastic, BALL),
	part(v(9, 9, 9), v(4, 49, 0), CLOUD, M.SmoothPlastic, BALL),
	part(v(8, 8, 8), v(0, 52, 0), CLOUD_SHADE, M.SmoothPlastic, BALL),
	part(v(6, 6, 6), v(-6, 22, 0), CLOUD, M.SmoothPlastic, BALL),
	part(v(5, 5, 5), v(5, 12, 0), CLOUD_SHADE, M.SmoothPlastic, BALL),
}, { Tag = "BiomeBob" })

-- Mesh props (Lane A). Each size is the generated mesh's own proportions (Studio 2026-10-31).
-- Lesson (a): the generator keeps every mesh within about 2:1 and short sides near 16 or under, so tall shapes
-- (the 220-stud beanstalk) stay part-built.
local cloudHouseMesh = meshed(cloudCottages, "CloudHouseMesh", v(13.05, 4.11, 12))
local skyPalmMesh = meshed(skyPalm, "SkyPalmMesh", v(6.64, 8.07, 7))
local brokenPillarMesh = meshed(brokenPillar, "BrokenPillarMesh", v(3.4, 7.92, 3.39))
local giantFernMesh = meshed(giantFern, "GiantFernMesh", v(6.4, 5, 6.26))
-- The jungle tree mesh came out squat (9.9 x 10.8 x 10): a bushy scatter tree, not the giant
local jungleBush = table.clone(jungleTree)
jungleBush.Name = "JungleBush"
local jungleBushMesh = meshed(jungleBush, "JungleTreeMesh", v(9.9, 10.8, 10))

-- Mesh rows: generated in Studio (Lane A) with `generate_mesh` (textPrompt = Prompt, size = Gen, maxTriangles = Tris,
-- segmentation "none"); each mesh's own generated texture is a Texture row. Id comes with the phase 2 upload.
-- Reviewed is left for the rules auditor (spec 4.1 step 3); close-ups go in assets/biomes/Snow/review/.
-- Lesson (c): prompts use generic words only and are checked with realNameIn.
local function meshRow(id, texture, prompt, size, tris, notes)
	return {
		Kind = "Mesh",
		Id = id,
		Lane = "A",
		Prompt = prompt,
		Texture = texture,
		Gen = string.format("size %g x %g x %g, maxTriangles %d, segmentation none", size.X, size.Y, size.Z, tris),
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

-- Blocks: one row of giants. Near 40 puts each road-side face 60 studs out, past the 44-60 shoulder; at most 13 deep,
-- so they end inside the ~77 midline. Orchestrator default 2026-10-31.
local blocks = giants({
	jungleTree,
	cloudPuffs,
	prop("BeanSprout", v(10, 70, 10), {
		post(60, 3, v(0, 30, 0), STALK, M.Grass),
		post(40, 2, v(2.5, 20, 1), DARK_STALK, M.Grass),
		part(v(7, 0.6, 4), v(3, 45, 0), STALK, M.Grass, nil, CFrame.Angles(0, 0.4, 0.35)),
		part(v(7, 0.6, 4), v(-3, 30, 0), STALK, M.Grass, nil, CFrame.Angles(0, -0.4, -0.35)),
		part(v(10, 10, 10), v(0, 65, 0), CLOUD, M.SmoothPlastic, BALL),
	}),
}, 90)
blocks.Near = 40
blocks.Rows = 1 -- a second row would sit across the midline

return {
	DisplayName = "Skypeia",
	Ground = { Color = CLOUD_SHADE, Material = M.SmoothPlastic },
	Sky = { Color = SKY },
	Gate = gate(RUIN, M.Sandstone, GOLD),
	-- Offset 10: road-side faces 30 studs out; every rhythm prop ends inside 44 (the cloud house, Pad, spans 30-40)
	Rhythm = {
		Every = 3,
		Offset = 10,
		Props = { cloudHouseMesh, skyPalmMesh, brokenPillarMesh, cloudRiver, skyPalmMesh, cloudRiver },
	},
	-- Pinned heroes (At, spec 4.3) snap to the nearest corner exit or 200+ stud straight. Fractions of the 14076-stud
	-- track (spec 7 values): 0.1 snaps to the first corner's exit (0.111, the cloud beach); 0.55 = the 260-stud
	-- straight (0.532-0.551) in the ruins bowl; 0.6 = the 611-stud straight (0.591-0.635) by the ruins; 0.92 lies inside
	-- the last corner and snaps to its exit (0.958), on the high island clouds.
	Landmarks = {
		-- placeholder: edge 20 + 40 puts every landmark's road-side face 60 studs out; x1.75 heroes 12 deep reach about
		-- 81 (pinned, so never slid) and the others, at most 10 deep, about 77.
		Offset = 40,
		Every = 20,
		Props = {
			-- part-built: the generated town read as a face (two windows over a pink nub), rejected 2026-10-31
			prop("CloudTown", cloudTown().Size, cloudTown().Parts, { Pad = true, Hero = true, At = 0.1 }),
			-- x1.667 of the mesh: 20 deep (x1.75 = 35, about 60-95 out; pinned, its pad stops short of the
			-- neighbour's corridor at about 111). Orchestrator default 2026-10-31.
			meshed(sunkenRuins(), "SunkenRuinsMesh", v(15.1, 16.5, 20), { Hero = true, At = 0.55 }),
			-- part-built: the generator caps a mesh near 2:1, so a 220-stud stalk cannot come out of it
			prop("GiantBeanstalk", beanstalk().Size, beanstalk().Parts, { Hero = true, At = 0.6 }),
			-- x1.333 of the mesh: 16 deep (x1.75 = 28, about 60-88 out)
			meshed(goldenBell(), "GoldenBellMesh", v(18, 21.4, 16), { Hero = true, At = 0.92, Tag = "BiomeBob" }),
			jungleTree,
			cloudPuffs,
		},
	},
	Horizon = {
		-- placeholder: the placement floor is Landmarks.Offset (60 studs out); x2 pieces at most 8 deep span about
		-- 60-76 and stay in this zone's half of the gap.
		Offset = 40,
		Props = {
			prop("CloudTower", v(18, 38, 8), {
				part(v(8, 8, 8), v(-5, 34, 0), CLOUD, M.SmoothPlastic, BALL),
				part(v(8, 8, 8), v(4, 32, 0), CLOUD, M.SmoothPlastic, BALL),
				part(v(8, 8, 8), v(0, 26, 0), CLOUD_SHADE, M.SmoothPlastic, BALL),
				part(v(8, 8, 8), v(-3, 18, 0), CLOUD, M.SmoothPlastic, BALL),
				part(v(7, 7, 7), v(2, 10, 0), CLOUD_SHADE, M.SmoothPlastic, BALL),
				part(v(6, 6, 6), v(0, 3, 0), CLOUD, M.SmoothPlastic, BALL),
			}, { Tag = "BiomeBob" }),
			prop("FarStalk", v(10, 48, 8), {
				post(40, 2.4, v(0, 20, 0), STALK, M.Grass),
				post(30, 1.6, v(2, 15, 1), DARK_STALK, M.Grass),
				part(v(6, 0.5, 3), v(2.5, 30, 0), STALK, M.Grass, nil, CFrame.Angles(0, 0, 0.4)),
				part(v(8, 8, 8), v(0, 44, 0), CLOUD, M.SmoothPlastic, BALL),
			}),
		},
	},
	-- Scatter on corridor ground: x1.5 props start 28 studs out (the road's clearance) and mostly end inside 44.
	-- Lesson (e): a mesh that comes out facing away from the road moves here (scatter turns freely).
	Scatter = {
		Every = 2,
		Near = 8,
		Far = 16,
		Props = {
			giantFernMesh,
			jungleBushMesh,
			"BrokenPillar",
			"SkyPalm",
			ball("CloudPuff", 5, CLOUD, M.SmoothPlastic),
			block(
				"FallenStone",
				v(7, 2.2, 3),
				RUIN,
				M.Sandstone,
				{ part(v(2.5, 0.3, 3.1), v(1.5, 2.3, 0), GOLD, M.Metal) }
			),
		},
		Patches = {
			patch("CloudDrift", 18, 10, CLOUD, M.SmoothPlastic),
			patch("Moss", 14, 10, JUNGLE, M.Ground),
			patch("RuinTiles", 12, 8, RUIN, M.Sandstone),
		},
	},
	Blocks = blocks,
	-- Landmark particles (Kit format): soft cloud mist drifting off every landmark
	Particles = particles(Kit.SMOKE, CLOUD_SHADE, { Size = 4, Lifetime = 5, Rate = 4, Speed = 1, Transparency = 0.55 }),
	-- Spec 3.3 / 7: default ridge Drop to the Snow cloud deck at -40. Sections (fractions of the track length): the
	-- cloud town and beach in Snow with soft mounds; the jungle island (Hills 40; Ground corridor and Grass ridge from
	-- the biome Materials); a swamp; the sunken ruins bowl in Sandstone; the high island clouds (Drop, Snow).
	-- Overlaps resolve to the first listed at equal weight, so the swamp and the ruins come before the jungle.
	-- Lesson (b): Grass is never under the road (the biome Corridor is Ground; sections set Snow or Sandstone).
	-- Every number is a placeholder.
	Terrain = {
		Ridge = { Shape = "Drop" },
		Sections = {
			{ From = 0.4, To = 0.46, Side = "Both", Ridge = { Shape = "Water" }, Water = { Level = -3 } }, -- swamp
			{
				From = 0.5,
				To = 0.6,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = -10, Noise = 0.04, Amp = 3 }, -- the sunken bowl
				Material = M.Sandstone,
			},
			{
				From = 0,
				To = 0.28,
				Side = "Both",
				Ridge = { Shape = "Hills", Height = 10, Noise = 0.03, Amp = 3 }, -- soft cloud mounds
				Material = M.Snow,
			},
			{ From = 0.3, To = 0.8, Side = "Both", Ridge = { Shape = "Hills", Height = 40, Noise = 0.04, Amp = 8 } },
			-- high island clouds. Inner (the side the bell's pin lands on, checked in the Lune harness): heaped Snow
			-- cloud mounds, so the bell (its mesh has no cloud column down to the deck) stands in view. Outer stays the
			-- open Drop.
			-- Orchestrator default 2026-10-31.
			{
				From = 0.82,
				To = 1,
				Side = "Inner",
				Ridge = { Shape = "Hills", Height = 30, Noise = 0.05, Amp = 8 },
				Material = M.Snow,
			},
			{ From = 0.82, To = 1, Side = "Outer", Material = M.Snow },
		},
		Materials = { Corridor = M.Ground, Ridge = M.Grass, Cliff = M.Rock, Bed = M.Snow },
		CliffSlope = 0.8,
		Embank = true,
	},
	-- Spec 5.2 / 7: bright high noon. ClockTime, Atmosphere Density / Offset / Color / Haze, Clouds, Bloom, SunRays and
	-- Saturation are section 7's; the rest are placeholders. No skybox row yet: the engine sky with Terrain clouds over
	-- the cloud deck (a generated cloud-sea skybox is optional in phase 2; the far thundercloud stays an open question).
	Atmosphere = Kit.Atmosphere({
		Lighting = {
			ClockTime = 12,
			Brightness = 3,
			Ambient = hex("5A6878"),
			OutdoorAmbient = hex("A8BCD0"),
			ExposureCompensation = 0.1,
		},
		Atmosphere = {
			Density = 0.3,
			Offset = 0.5,
			Color = hex("EAF6FF"),
			Decay = hex("BFE4FA"),
			Glare = 0.2,
			Haze = 0.5,
		},
		Grade = { TintColor = hex("F6FBFF"), Saturation = 0.15 },
		Bloom = { Intensity = 0.8 },
		SunRays = { Intensity = 0.15, Spread = 0.6 },
		Sky = {
			SunAngularSize = 21,
			MoonAngularSize = 11,
			StarCount = 3000,
			CelestialBodiesShown = true,
		},
		Clouds = { Cover = 0.55, Density = 0.4, Color = CLOUD },
		-- the swamp is the only water: murky green and nearly opaque, so the Snow bed under it does not show
		Water = { Color = hex("4A6B3A"), Transparency = 0.15, Reflectance = 0.1, WaveSize = 0.05, WaveSpeed = 4 },
		Particles = {
			{
				Texture = "CloudWispParticle", -- slow cloud wisps; the tall box puts many below the road
				Color = CLOUD,
				Size = 9,
				Rate = 6,
				Lifetime = 10,
				Speed = 1.5,
				SpreadAngle = 40,
				LightEmission = 0.15,
				Area = v(160, 50, 160),
			},
			{
				Texture = "MoteParticle", -- drifting jungle motes
				Color = MOTE,
				Size = 0.4,
				Rate = 10,
				Lifetime = 6,
				Speed = 0.5,
				SpreadAngle = 180,
				LightEmission = 0.4,
				Area = v(160, 50, 160),
			},
		},
	}),
	-- Spec 6 / 7: wind with far jungle birds (loop); a deep distant bell toll (in-house) and a far thunder roll
	Audio = {
		Loop = "AmbSkyJungle",
		OneShots = { "SfxBellToll", "SfxThunderRoll" },
		Volume = 0.35,
		Reverb = "Mountains",
	},
	-- Asset ledger (spec 4.4): key = { Kind = "Mesh"|"Texture"|"Skybox"|"Sound", Id = "rbxassetid://N",
	-- Lane = "A"|"B"|"C"|"D", Prompt = "...", Creator = "<Lane D only>", Tris = N, Reviewed = "<date> <who>",
	-- Notes = "..." }. Only reviewed rows with an Id are used. Reviewed is left for the rules auditor (spec 4.1).
	-- Creator Store sounds are used by id (no insert, nothing to strip; BUGS creator-store-backdoor-skybox); creator,
	-- type and length checked on the Roblox economy API 2026-10-31.
	Assets = {
		SunkenRuinsMesh = meshRow(
			"rbxassetid://126469436535700",
			"SunkenRuinsTex",
			"ancient stepped stone temple ruin, four weathered sandy grey stone tiers like a stepped pyramid, a steep central stair, green vines and moss hanging down the tiers, a few walls still clad in gold panels, two broken gold pillars at the front corners, plain stone faces with no carvings, no faces and no writing, stylized cartoon style",
			v(24, 36, 12),
			15000,
			"hero 2: came out 9.07 x 9.89 x 12, stair faces -Z; GiantBeanstalk and CloudTown heroes are part-built (rejected tries in review/)"
		),
		GoldenBellMesh = meshRow(
			"rbxassetid://126293817674763",
			"GoldenBellTex",
			"a large shiny plain gold church bell hanging under a simple stone archway made of two stone pillars and a stone beam, green vines growing on the stone, the whole archway standing on a soft round white cloud base, smooth bell with no pattern, no symbols and no writing, stylized cartoon style",
			v(14, 24, 12),
			15000,
			"hero 3 (BiomeBob): came out 13.55 x 16.12 x 12; plain bell, no inscription; try 1 (tan bell under a stone disk) rejected"
		),
		CloudHouseMesh = meshRow(
			"rbxassetid://131403200281516",
			"CloudHouseTex",
			"a row of four small round white dome-shaped cottages side by side on a flat white cloud base, smooth white walls with thin pastel blue roof rims, each cottage with one small arched door at ground level only, no windows, no faces, no signs and no writing, stylized cartoon style",
			v(24, 12, 12),
			15000,
			"rhythm building (Pad = true): came out 13.05 x 4.11 x 12, spans 30-42; doors face -Z"
		),
		SkyPalmMesh = meshRow(
			"rbxassetid://137901134436781",
			"SkyPalmTex",
			"slender tropical palm tree with a gently curved trunk and a crown of bright green fronds, a small white cloud puff at its foot, stylized low poly cartoon style",
			v(7, 12.2, 7),
			1500,
			"came out 6.64 x 8.07 x 7"
		),
		BrokenPillarMesh = meshRow(
			"rbxassetid://74813000226989",
			"BrokenPillarTex",
			"broken ancient pillar, lower half weathered sandy stone and upper half clad in worn gold, jagged broken top, one green vine wrapped around it, plain with no carvings or writing, stylized low poly cartoon style",
			v(3.4, 10, 3.4),
			1500,
			"came out 3.4 x 7.92 x 3.39"
		),
		GiantFernMesh = meshRow(
			"rbxassetid://140631904053033",
			"GiantFernTex",
			"large jungle fern plant, long arching bright green fronds spreading out from a low center, stylized low poly cartoon style",
			v(8, 5, 8),
			1500,
			"scatter (turns freely); came out 6.4 x 5 x 6.26"
		),
		JungleTreeMesh = meshRow(
			"rbxassetid://123217431765070",
			"JungleTreeTex",
			"giant tropical jungle tree, tall straight brown trunk with wide buttress roots at the base, a broad flat dense green crown, long vines hanging from the branches, stylized low poly cartoon style",
			v(16, 30, 10),
			3000,
			"came out squat (9.9 x 10.8 x 10): used as the scatter JungleBush; the giant jungle tree is part-built"
		),
		SunkenRuinsTex = textureRow("rbxassetid://137501926790557", "SunkenRuinsMesh"),
		GoldenBellTex = textureRow("rbxassetid://70665510604030", "GoldenBellMesh"),
		CloudHouseTex = textureRow("rbxassetid://75903342491127", "CloudHouseMesh"),
		SkyPalmTex = textureRow("rbxassetid://127128116797158", "SkyPalmMesh"),
		BrokenPillarTex = textureRow("rbxassetid://90830005002524", "BrokenPillarMesh"),
		GiantFernTex = textureRow("rbxassetid://125168368959366", "GiantFernMesh"),
		JungleTreeTex = textureRow("rbxassetid://85055805672566", "JungleTreeMesh"),
		CloudWispParticle = {
			Kind = "Texture",
			Lane = "A",
			Id = "rbxassetid://94569224375165",
			Prompt = "in-house 128 px soft stretched cloud puff with lumpy noise inside, white on transparent",
			Notes = "drawn with python3 + numpy (assets/biomes/Snow/cloud_wisp_particle.png), uploaded from Studio",
			Reviewed = "2026-10-31 rules-auditor",
		},
		MoteParticle = {
			Kind = "Texture",
			Lane = "A",
			Id = "rbxassetid://98654695655274",
			Prompt = "in-house 128 px round soft glow with faint grain, white on transparent, tinted pale gold by the emitter",
			Notes = "drawn with python3 + numpy (assets/biomes/Snow/mote_particle.png), uploaded from Studio",
			Reviewed = "2026-10-31 rules-auditor",
		},
		AmbSkyJungle = {
			Kind = "Sound",
			Id = "rbxassetid://9112748018",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9112748018: Birds And Cicadas 2, distant birds, insects, light wind, loop, 46.3 s",
			Reviewed = "2026-10-31 rules-auditor",
		},
		-- The in-house toll (assets/audio/Snow/bell_toll.ogg / .wav) has no upload path from the Studio tools (image upload
		-- only), so the one-shot is a Creator Store bell. Orchestrator default 2026-10-31.
		SfxBellToll = {
			Kind = "Sound",
			Id = "rbxassetid://9113804175",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9113804175: Church Bell Single Hits Double At Head 2, one hit, long ringing decay, 8.8 s",
			Reviewed = "2026-10-31 rules-auditor",
		},
		SfxThunderRoll = {
			Kind = "Sound",
			Id = "rbxassetid://9120021237",
			Lane = "D",
			Creator = "ProSoundEffects",
			Notes = "Creator Store 9120021237: Thunder Rumbling 1, rumbling, booming, long decays, 24.3 s",
			Reviewed = "2026-10-31 rules-auditor",
		},
	},
}
