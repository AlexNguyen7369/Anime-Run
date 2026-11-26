--!nonstrict
-- BRIEF: docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)" (owner 2026-11-26, design doc change log).
-- The draft is off (TrackFxConfig.LIVE false) and never runs in World 1; every track's configured caps fit the budget;
-- every dragon loop keeps its clearance from its own track's centre line; every anchor names a prop of that biome's
-- approved draft; nothing is uploaded or unreviewed. Pure data and math: runs offline (lune) and in Studio, either world.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "track_fx", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

function Tests.track_fx()
	local r, flag = H.report("track_fx")
	local Config = require(Shared.TrackFxConfig)
	local Plan = require(Shared.TrackFxPlan)
	local B = Config.Budget

	-- Off by default, World 2 only
	flag("live_off_by_default", Config.LIVE == false)
	flag("off_world1", Config.Enabled(1) == false)
	flag("off_world2_while_not_live", Config.Enabled(2) == false)
	local saved = Config.LIVE
	Config.LIVE = true
	flag("world1_off_even_if_live", Config.Enabled(1) == false)
	flag("world2_on_only_if_live", Config.Enabled(2) == true)
	Config.LIVE = saved

	-- Only World 2 biome keys have rows (World 1's tracks are untouched)
	local w2 = {}
	for _, module in Shared.Tracks.World2:GetChildren() do
		if module:IsA("ModuleScript") then
			local spec = require(module)
			w2[spec.Biome] = spec
		end
	end
	local w1 = {}
	for _, module in Shared.Tracks:GetChildren() do
		if module:IsA("ModuleScript") then
			local spec = require(module)
			if spec.Biome then
				w1[spec.Biome] = true
			end
		end
	end
	local onlyW2, noW1 = true, true
	for key in Config.Tracks do
		onlyW2 = onlyW2 and w2[key] ~= nil
		noW1 = noW1 and not w1[key]
	end
	flag("rows_only_world2_biomes", onlyW2)
	flag("no_world1_biome_rows", noW1 and next(w1) ~= nil)

	-- Presets inside the caps
	local presetsOk = true
	for name, p in Config.Presets do
		local ok = p.Rate <= B.MaxRate
			and Plan.Cull(p) <= B.MaxCull
			and Config.Assets[p.Texture] ~= nil
			and Config.Assets[p.Texture].Kind == "Texture"
		if not ok then
			presetsOk = false
			flag("preset_" .. name, false)
		end
	end
	flag("presets_within_caps", presetsOk)

	-- Assets: in-house Lane B, not uploaded, or uploaded only with a review
	local assetsOk = true
	for key, row in Config.Assets do
		if
			row.Lane ~= "B"
			or (row.Id ~= nil and row.Reviewed == nil)
			or not string.match(row.Prompt or "", "^in%-house")
		then
			assetsOk = false
			flag("asset_" .. key, false)
		end
	end
	flag("assets_in_house_and_reviewed_before_use", assetsOk)

	-- Real-name check over every ledger key and prompt (BIOME_ENVIRONMENT_SPEC 4.1 step 2: "the real-name check scans it")
	local realNameIn = require(script.Parent.CatalogTests).realNameIn
	local namesOk, scanned = true, 0
	for key, row in Config.Assets do
		for _, text in { key, row.Prompt or "" } do
			scanned += #text > 0 and 1 or 0
			local hit = realNameIn(string.lower(text))
			if hit ~= nil then
				namesOk = false
				flag("real_name_" .. key, false, hit, "none")
			end
		end
	end
	flag("assets_no_real_names", namesOk)
	flag("real_name_scan_saw_every_key_and_prompt", scanned == 2 * #(function()
		local keys = {}
		for k in Config.Assets do
			table.insert(keys, k)
		end
		return keys
	end)(), scanned)

	-- Each track: worst case of its caps in budget, anchors name draft props, dragons and motion capped
	for key, track in Config.Tracks do
		local emitters, particles = Plan.WorstCase(track)
		flag(key .. "_emitters_in_budget", emitters <= B.MaxEmittersPerTrack, emitters, B.MaxEmittersPerTrack)
		flag(key .. "_particles_in_budget", particles <= B.MaxParticlesPerTrack, particles, B.MaxParticlesPerTrack)
		local draftModule = Shared.BiomeThemes.World2:FindFirstChild(key .. "Draft")
		local draft = draftModule and require(draftModule)
		local anchorsOk = draft ~= nil
		for _, row in track.Smoke or {} do
			local preset = Config.Presets[row.Preset]
			anchorsOk = anchorsOk
				and preset ~= nil
				and row.Max >= 1
				and #row.Color == 2
				and ((row.Prop and draft and draft.Props[row.Prop] ~= nil) or (row.Prop == nil and row.At ~= nil))
		end
		for _, row in track.Motion or {} do
			anchorsOk = anchorsOk and draft ~= nil and draft.Props[row.Prop] ~= nil
			anchorsOk = anchorsOk
				and row.Max <= B.MaxMovingProps
				and (row.Kind ~= "Sway" or row.Angle <= 5)
				and (row.Kind ~= "Bob" or row.Height <= 5)
		end
		flag(key .. "_anchors_are_draft_props", anchorsOk)
		local dragons = track.Dragons or {}
		flag(key .. "_dragons_capped", #dragons <= B.MaxDragonsPerTrack, #dragons, B.MaxDragonsPerTrack)
		if #dragons > 0 then
			local TrackBuilder = require(Shared.TrackBuilder)
			local waypoints = TrackBuilder.Layout(w2[key]).Waypoints
			for i, def in dragons do
				local c = Plan.Clearance(Plan.DragonPath(waypoints, def), waypoints)
				flag(
					("%s_dragon%d_clear_of_road"):format(key, i),
					c >= B.MinDragonClearance,
					math.floor(c),
					B.MinDragonClearance
				)
			end
		end
	end

	-- The nearest-first pick never passes a cap
	local candidates = {}
	for i = 1, 40 do
		table.insert(candidates, { Key = i, Position = Vector3.new(i * 20, 0, 0), Cost = 40, Cull = 600 })
	end
	local _, count, cost = Plan.Pick(candidates, Vector3.zero, B.MaxEmittersPerTrack, B.MaxParticlesPerTrack)
	flag("pick_count_capped", count <= B.MaxEmittersPerTrack, count, B.MaxEmittersPerTrack)
	flag("pick_cost_capped", cost <= B.MaxParticlesPerTrack, cost, B.MaxParticlesPerTrack)
	local kept = Plan.Pick(candidates, Vector3.zero, 3, 1e9)
	flag("pick_nearest_first", kept[1] and kept[2] and kept[3] and not kept[4])
	local culled =
		Plan.Pick({ { Key = "far", Position = Vector3.new(700, 0, 0), Cost = 1, Cull = 600 } }, Vector3.zero, 9, 99)
	flag("pick_culls_far", culled.far == nil)

	-- A row's Fill spreads its emitter over the prop's box, never below the preset's Area; the rate stays the preset's
	local steam = Config.Presets.Steam
	local wide = Plan.Area(steam, { Fill = Vector3.new(0.8, 0, 0.5) }, Vector3.new(158, 14, 57))
	flag("fill_spreads_area", math.abs(wide.X - 126.4) < 1e-3 and wide.Y == steam.Area.Y and wide.Z >= steam.Area.Z)
	flag("no_fill_keeps_area", Plan.Area(steam, {}, Vector3.new(158, 14, 57)) == steam.Area)

	-- Flicker stays in 0..1; motion is small
	local flickerOk = true
	for t = 0, 20, 0.05 do
		local k = Plan.Flicker({ Depth = 0.35, Speed = 9, Dropout = 0.03 }, t, 3)
		flickerOk = flickerOk and k >= 0 and k <= 1
	end
	flag("flicker_in_range", flickerOk)
	local sway = Plan.Motion({ Kind = "Sway", Angle = 2, Period = 4 }, 1, 0)
	local _, _, z = sway:ToEulerAnglesXYZ()
	flag("sway_small", math.abs(z) <= math.rad(2) + 1e-6)
	return r
end

return Tests
