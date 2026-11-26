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

	-- An eel's segments keep their spacing all round the loop, the lap's closing span included: the body is laid out by
	-- distance (TrackFxPlan.ArcTable / SplineAt), not by the spline's uneven parameter
	do
		local TrackBuilder = require(Shared.TrackBuilder)
		local key, def = "HauntedTunnel", Config.Tracks.HauntedTunnel.Dragons[1]
		local path = Plan.DragonPath(TrackBuilder.Layout(w2[key]).Waypoints, def)
		local arc = Plan.ArcTable(path)
		local E = Config.Eel
		local lo, hi = math.huge, 0
		for step = 0, 199 do
			local head = arc.Length * step / 200
			local prev = Plan.SplineAt(path, arc, head)
			for i = 1, E.Segments do
				local p = Plan.SplineAt(path, arc, head - Plan.EelBack(i))
				local gap = (p - prev).Magnitude / (Plan.EelBack(i) - Plan.EelBack(i - 1))
				lo, hi = math.min(lo, gap), math.max(hi, gap)
				prev = p
			end
		end
		flag("eel_spacing_even_min", lo >= 0.95, lo, 0.95)
		flag("eel_spacing_even_max", hi <= 1.01, hi, 1.01)
		local a, b = Plan.SplineAt(path, arc, arc.Length - 0.01), Plan.SplineAt(path, arc, 0.01)
		flag("loop_closes_smoothly", (a - b).Magnitude < 0.1, (a - b).Magnitude, 0.1)
		-- what the parameter alone gives (the old layout): uneven, so the distance table is needed
		local uLo, uHi = math.huge, 0
		local step = E.Spacing / arc.Length
		for k = 0, 399 do
			local u = k / 400
			local gap = (Plan.Spline(path, u) - Plan.Spline(path, u - step)).Magnitude / E.Spacing
			uLo, uHi = math.min(uLo, gap), math.max(uHi, gap)
		end
		flag("parameter_alone_is_uneven", uHi / uLo > 1.1, uHi / uLo, 1.1)
	end

	-- 2026-11-26 Studio fixes (WORLD2_SPEC "Track effects"): the origin from the chain, smoke off the road, dragons over
	-- their own ground, an eel with no gaps. Values are the spec's, written here as literals.
	do
		local TrackBuilder = require(Shared.TrackBuilder)
		local TrackRegistry = require(Shared.TrackRegistry)
		local Themes = require(Shared.BiomeThemes)
		local chain = TrackRegistry.Chain()
		flag("road_clear_24", B.RoadClear == 24, B.RoadClear, 24)
		flag("min_spread_half", B.MinSpread == 0.5, B.MinSpread, 0.5)
		flag("own_margin_20", B.OwnMargin == 20, B.OwnMargin, 20)
		flag("eel_overlap_1_6", B.EelOverlap == 1.6, B.EelOverlap, 1.6)
		local api = type(Plan.ChainOrigins) == "function"
			and type(Plan.CentreLines) == "function"
			and type(Plan.ClearSpread) == "function"
			and type(Plan.SpreadClearance) == "function"
			and type(Plan.Owner) == "function"
			and type(Plan.OwnPath) == "function"
		flag("fix_api_exists", api)
		if api then
			-- 1. Each track's origin, from the chain alone, is the server-built Start less 0.5. In Studio: the live tracks.
			-- Offline the lune runner cannot build a track: tools/lune/biome_harness.luau (WORLD=2) builds them and checks it
			-- ("W2 FX ORIGIN CHECKS").
			local origins = Plan.ChainOrigins(TrackBuilder, chain)
			local live = workspace:FindFirstChild("Track")
			for _, spec in chain do
				local model = live and live:FindFirstChild(spec.Name)
				local start = model and model:FindFirstChild("Start", true)
				if start then
					local want = start.CFrame * CFrame.new(0, -0.5, 0)
					local got = origins[spec.Number]
					flag(
						("origin_%d_is_start"):format(spec.Number),
						got ~= nil
							and (got.Position - want.Position).Magnitude < 0.01
							and got.LookVector:Dot(want.LookVector) > 0.99999,
						got and (got.Position - want.Position).Magnitude or -1,
						0.01
					)
				end
			end
			local lines = Plan.CentreLines(TrackBuilder, chain, origins)
			local byBiome = {}
			for _, spec in chain do
				byBiome[spec.Biome] = spec
			end
			-- 2. Every smoke row's spread, on every placed prop of its key, is clear of every road by 24 after ClearSpread
			for key, track in Config.Tracks do
				local spec, theme = byBiome[key], Themes[key]
				local base = spec and origins[spec.Number]
				local worst, kept, dropped = math.huge, 0, 0
				local rowsKept = true
				for _, row in track.Smoke or {} do
					local preset = Config.Presets[row.Preset]
					local rowKept = 0
					for _, m in row.Prop and theme and theme.Placed or {} do
						if m[1] == row.Prop then
							local def = theme.Props[m[1]]
							local s = m[9] or m[6] or 1
							local size = def.Size * s
							local box = base
								* CFrame.new(m[2], m[3], m[4])
								* CFrame.fromEulerAnglesYXZ(m[7] or 0, m[5], m[8] or 0)
								* CFrame.new(0, size.Y / 2, 0)
							local at = Plan.BoxPoint(box, size, row.Offset).Position
							local pos, area = Plan.ClearSpread(at, Plan.Area(preset, row, size), lines)
							if pos then
								kept += 1
								rowKept += 1
								worst = math.min(worst, Plan.SpreadClearance(pos, area, lines))
							else
								dropped += 1
							end
						end
					end
					-- a row whose prop has no placement (AntIsland IslandVolcano, "when it is placed") has nothing to keep
					local placed = false
					for _, m in row.Prop and theme and theme.Placed or {} do
						placed = placed or m[1] == row.Prop
					end
					rowsKept = rowsKept and (not placed or rowKept > 0)
				end
				if kept + dropped > 0 then
					flag(key .. "_smoke_clear_of_roads", worst >= 24 - 1e-6, math.floor(worst * 10) / 10, 24)
					flag(key .. "_smoke_rows_keep_an_anchor", rowsKept, ("%d kept, %d dropped"):format(kept, dropped))
				end
			end
			-- 3. Every dragon loop, sampled, lies over its own track's ground and keeps 150 from its own centre line
			for key, track in Config.Tracks do
				local spec = byBiome[key]
				for i, def in track.Dragons or {} do
					local waypoints = TrackBuilder.Layout(spec).Waypoints
					local path = Plan.DragonPath(waypoints, def)
					for k, p in path do
						path[k] = origins[spec.Number]:PointToWorldSpace(p)
					end
					path = Plan.OwnPath(path, spec.Number, lines, Plan.DragonFoot(waypoints, def, origins[spec.Number]))
					local own, n = 0, 128
					for k = 0, n - 1 do
						local p = Plan.Spline(path, k / n)
						if Plan.Owner(lines, p.X, p.Z) == spec.Number then
							own += 1
						end
					end
					flag(("%s_dragon%d_over_own_ground"):format(key, i), own == n, own, n)
					local world = {}
					for k, w in waypoints do
						world[k] = origins[spec.Number]:PointToWorldSpace(w)
					end
					local c = Plan.Clearance(path, world)
					flag(("%s_dragon%d_own_clearance"):format(key, i), c >= B.MinDragonClearance, math.floor(c), 150)
				end
			end
		end
		-- 4. The eel has no gaps: each pair of neighbours (head first) overlaps, the tail's wave counted
		local E = Config.Eel
		local function len(i)
			return i == 0 and E.HeadSize.Z or E.SegmentSize.Z * (1 - 0.45 * i / E.Segments)
		end
		local function wave(i, t)
			return math.sin(t * math.pi * 2 - i / E.WaveLength * math.pi * 2) * E.Wave * (i / E.Segments)
		end
		local worstRatio = math.huge
		for i = 1, E.Segments do
			local along = Plan.EelBack(i) - Plan.EelBack(i - 1)
			local side = 0
			for t = 0, 1, 0.01 do
				side = math.max(side, math.abs(wave(i, t) - wave(i - 1, t)))
			end
			local chord = math.sqrt(along * along + side * side)
			worstRatio = math.min(worstRatio, (len(i - 1) + len(i)) / 2 / chord)
		end
		flag("eel_segments_overlap", worstRatio >= 1.6, math.floor(worstRatio * 100) / 100, 1.6)
		flag("eel_segment_count_kept", E.Segments == 14, E.Segments, 14)
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
