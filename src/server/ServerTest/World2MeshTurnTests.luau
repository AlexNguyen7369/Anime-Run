--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "Blender first", import turn (2026-11-26, the lead under the owner's "fix rendering on all
-- tracks"). Roblox's Open Cloud import of a GLB turns its geometry 180 degrees about Y; World 2 biome placement turns each
-- uploaded draft mesh back about its own centre, so a prop faces as in its approved Blender draft and the split ChainTower
-- joins. Checked offline from measured geometry: for each mesh below, the area-weighted centroid of its triangles relative
-- to its box centre, read from the exported GLB (the Draft's frame) and from the uploaded mesh in Studio (EditableMesh,
-- 2026-11-26). Placed with BiomeDressing.MeshCFrame, the uploaded centroid must land where the Draft puts the GLB's, within
-- 0.1 stud; the ChainTower's four pieces at their Draft rows therefore reassemble. Only World 2 draft meshes turn.
-- Offline: lune run tools/lune/server_scenarios <1|2> World2MeshTurnTests.w2_mesh_turn
-- On demand in Studio: ReplicatedStorage attributes ServerTestOnly = "w2_mesh_turn", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local TOLERANCE = 0.1 -- studs
-- key = { GLB centroid, uploaded mesh centroid } (studs, relative to the box centre), measured 2026-11-26
local MEASURED = {
	W2_DemonCastle_ChainTower_p1 = { Vector3.new(112.465, -16.364, 3.243), Vector3.new(-112.465, -16.365, -3.243) },
	W2_DemonCastle_ChainTower_p2 = { Vector3.new(142.698, -222.48, 77.312), Vector3.new(-142.698, -222.48, -77.312) },
	W2_DemonCastle_ChainTower_p3 = { Vector3.new(-85.353, 2.327, 126.438), Vector3.new(85.352, 2.327, -126.438) },
	W2_DemonCastle_ChainTower_p4 = {
		Vector3.new(-227.464, -230.013, 195.844),
		Vector3.new(227.464, -230.013, -195.844),
	},
	W2_DevilTokyo_Konbini = { Vector3.new(-0.795, -2.172, -1.847), Vector3.new(0.795, -2.172, 1.847) },
	W2_DevilTokyo_ShopHouse = { Vector3.new(-4.046, -2.187, -0.549), Vector3.new(4.046, -2.187, 0.549) },
	W2_KaijuBase_Railgun = { Vector3.new(-10.9, -7.137, -14.322), Vector3.new(10.9, -7.137, 14.323) },
	W2_KaijuBase_GiantCorpse = { Vector3.new(-1.041, -36.4, -6.481), Vector3.new(1.041, -36.4, 6.481) },
	W2_DemonCastle_Hound = { Vector3.new(0.393, 3.175, 3.231), Vector3.new(-0.393, 3.175, -3.231) },
	W2_KaijuBase_DefenseHQ = { Vector3.new(-5.869, -60.387, 19.45), Vector3.new(5.869, -60.388, -19.45) },
	W2_HauntedTunnel_Portal = { Vector3.new(-0.314, -23.732, -10.379), Vector3.new(0.314, -23.732, 10.379) },
	W2_HellGate_Hand = { Vector3.new(-0.372, -7.307, -0.827), Vector3.new(0.372, -7.307, 0.827) },
	W2_ElvenPlains_Town = { Vector3.new(0.449, -19.665, -7.537), Vector3.new(-0.449, -19.664, 7.537) },
	W2_AntIsland_Ship = { Vector3.new(-0.247, -9.902, 5.912), Vector3.new(0.247, -9.902, -5.912) },
}

-- the theme def of a ledger key W2_<Biome>_<Prop>, or nil
local function defOf(Themes, key)
	local biome, name = string.match(key, "^W2_(%w+)_(.+)$")
	local theme = biome and Themes[biome]
	return theme and theme.Props and theme.Props[name], biome, name
end

function Tests.w2_mesh_turn()
	local r, flag = H.report("w2_mesh_turn")
	local Dressing = require(Shared.BiomeDressing)
	local Themes = require(Shared.BiomeThemes)
	local worldId = require(Shared.WorldConfig).Id
	local api = type(Dressing.MeshCFrame) == "function"
	flag("mesh_cframe_api", api)

	-- The measured import turn itself: X and Z negated, Y kept (the reason for the rule)
	local turned = true
	for key, m in MEASURED do
		local g, u = m[1], m[2]
		if (Vector3.new(-g.X, g.Y, -g.Z) - u).Magnitude > 0.01 then
			turned = false
			flag("import_turn_" .. key, false)
		end
	end
	flag("import_turns_geometry_180", turned)

	if worldId == 2 then
		-- Every World 2 draft mesh carries the turn; a parts-only prop has no mesh to turn
		local marked, unmarked = 0, {}
		for key, theme in Themes do
			for name, def in theme.Props or {} do
				if def.Mesh and string.sub(def.Mesh, 1, 3) == "W2_" then
					if def.ImportTurn == true then
						marked += 1
					else
						table.insert(unmarked, key .. "/" .. name)
					end
				elseif def.ImportTurn ~= nil then
					table.insert(unmarked, key .. "/" .. name .. " (no mesh)")
				end
			end
		end
		table.sort(unmarked)
		flag(
			"w2_meshes_marked",
			marked > 0 and #unmarked == 0,
			#unmarked == 0 and marked or table.concat(unmarked, " "),
			0
		)

		-- Placed, the uploaded geometry lands where the Draft puts the GLB's: facing as approved
		local base = CFrame.new(100, 3, -50) * CFrame.fromEulerAnglesYXZ(0, 0.7, 0)
		local worst, missing = 0, {}
		for key, m in MEASURED do
			local def = defOf(Themes, key)
			if not (def and api) then
				table.insert(missing, key)
				continue
			end
			local want = base * CFrame.new(0, def.Size.Y / 2, 0) * m[1]
			local got = Dressing.MeshCFrame(def, base) * m[2]
			worst = math.max(worst, (got - want).Magnitude)
		end
		table.sort(missing)
		flag("fixture_defs_found", #missing == 0, #missing == 0 and 0 or table.concat(missing, " "), 0)
		flag(
			"placed_faces_as_draft",
			api and #missing == 0 and worst <= TOLERANCE,
			math.floor(worst * 1000) / 1000,
			TOLERANCE
		)

		-- The split ChainTower at its own Draft rows: each piece's geometry lands as in the joined Blender model
		local draft = require(Shared.BiomeThemes.World2.DemonCastleDraft)
		local origin = CFrame.new(-300, 0, 200) * CFrame.Angles(0, math.pi, 0) -- a track turned half round
		local pieces, joinWorst = 0, 0
		for _, row in draft.Placed or {} do
			local name = row[1]
			local m = MEASURED["W2_DemonCastle_" .. name]
			if m and string.match(name, "^ChainTower_p%d$") then
				pieces += 1
				local def = Themes.DemonCastle.Props[name]
				local rowBase = origin
					* CFrame.new(row[2], row[3], row[4])
					* CFrame.fromEulerAnglesYXZ(row[7] or 0, row[5], row[8] or 0)
				local want = rowBase * CFrame.new(0, def.Size.Y / 2, 0) * m[1]
				local got = api and Dressing.MeshCFrame(def, rowBase) * m[2] or want + Vector3.new(1e3, 0, 0)
				joinWorst = math.max(joinWorst, (got - want).Magnitude)
			end
		end
		flag("chaintower_four_pieces", pieces == 4, pieces, 4)
		flag(
			"chaintower_reassembles",
			pieces == 4 and joinWorst <= TOLERANCE,
			math.floor(joinWorst * 1000) / 1000,
			TOLERANCE
		)
	end

	-- World 1 biome meshes (generated in Studio) and anything not from a World 2 draft keep their placement
	local strays = {}
	for key, theme in Themes do
		for name, def in theme.Props or {} do
			if def.ImportTurn and not (def.Mesh and string.sub(def.Mesh, 1, 3) == "W2_") then
				table.insert(strays, key .. "/" .. name)
			end
		end
	end
	flag("only_w2_draft_meshes_turn", #strays == 0, #strays == 0 and 0 or table.concat(strays, " "), 0)
	if api then
		local plain = { Size = Vector3.new(10, 20, 30) }
		local base = CFrame.new(5, 0, 5) * CFrame.Angles(0, 0.3, 0)
		flag("unmarked_def_unturned", Dressing.MeshCFrame(plain, base) == base * CFrame.new(0, 10, 0))
	end
	return r
end

return Tests
