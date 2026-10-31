--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md sections 3, 5 and 7 (owner 2026-10-28), design doc sections 3 and 4.10. Written
-- by test-writer BEFORE the world build; never loosen a limit to make it pass.
-- `world_layout` (section 3 + 7): "hub at the centre, 7 plots around it, Track 1 start at the start gate, no overlaps,
--   baseplate covers everything, one SpawnLocation". Coordinates are chosen by the world build, so every check reads
--   the LIVE world and tests relationships, never positions:
--     * hub = Workspace.SpawnArea, its plaza floor = SpawnArea.Floor; "world centre" = the world origin (x 0, z 0).
--     * plots = Workspace.Workshops.Plot_1 .. Plot_7 (tag WorkshopPlot), footprint = the plot's Base part.
--     * ring: plot centres at about one radius from the hub centre (min / max >= RING_RADIUS_RATIO) and all the way
--       around it (largest angle between neighbouring plots <= RING_MAX_GAP_DEG). Test-side readings of "ring".
--     * start gate = SpawnArea.StartPad (tag StartPad); Track 1's Start part lies within one road width of it.
--     * safety baseplate = Workspace.Baseplate (a BasePart, or a Model / Folder of tiles), below the plaza floor,
--       covering every part of the hub, the plots and the track chain plus BASEPLATE_MARGIN studs.
-- `dojo` (section 5 + 7): Dojos are the 7 workshop plots (48 x 48, lowest free plot on join, freed on leave); the Dojo
--   squad is the IVS Showcase (GachaService.SetShowcase, 3 slots, unchanged formula); a character is in the Team or
--   the squad, never both. Until stamina ships the Team is the single equipped character (EquippedCar), so the
--   Team setter is GachaService.Equip (and GachaService.SetTeam too, once it exists). Standing in the Dojo's zone
--   (Plot_N.Workshop.Zone) earns idle Speed at WorkshopService.Rate, which scales with the squad multiplier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local H = require(script.Parent.AcceptanceSupport)
local TrackChain = require(script.Parent.TrackChainTests)
local Server = script.Parent.Parent
local Shared = ReplicatedStorage:WaitForChild("Shared")

local PLOT_COUNT = 7 -- design doc 3 / spec 5: 7 plots
local PLOT_SIZE = 48 -- spec 5: Dojos 48 x 48
local PLOT_GAP = 8 -- IVS no-overlap rule for plots (workshop scenario: 8-stud gaps)
local SQUAD = 3 -- spec 5: the player picks 3
local SPEC = { SCALE = 0.25, COPY_BONUS = 0.1, MAX_COPIES = 50 } -- IVS Showcase numbers, unchanged (spec 5)
local CENTRE_TOL = 8 -- studs: hub centre from the world origin, SpawnLocation from the plaza centre (IVS SPAWN_MIDDLE)
local RING_RADIUS_RATIO = 0.75 -- test reading of "ring": nearest plot centre >= 0.75 x farthest, from the hub centre
local RING_MAX_GAP_DEG = 135 -- test reading of "around it": no side of the hub is left without a plot
local BASEPLATE_MARGIN = 20 -- studs; "plus a margin" (test-side value, owner may tune)
local GEOM_TOL = 0.5
local OVERLAP_TOL = 0.05
local UID = 991300000

local Tests = {}

local function near(a, b, rel)
	return type(a) == "number"
		and type(b) == "number"
		and a == a
		and math.abs(a - b) <= (rel or 1e-9) * math.max(1, math.abs(b))
end

local function flatDist(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function parts(root)
	local list = {}
	if root == nil then
		return list
	end
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- World XZ corners of a part's footprint.
local function corners(part)
	local cf, s = part.CFrame, part.Size / 2
	local pts = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(pts, cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z)))
			end
		end
	end
	return pts
end

local function track1Start()
	local registry = H.module(Shared, "TrackRegistry")
	local specs = registry and type(registry.Chain) == "function" and registry.Chain() or {}
	local folder = Workspace:FindFirstChild("Track")
	local model = folder and specs[1] and folder:FindFirstChild(specs[1].Name)
	local start = model and model:FindFirstChild("Start")
	return start and start:IsA("BasePart") and start or nil, specs[1] and specs[1].Width or 40
end

local function livePlots()
	local folder = Workspace:FindFirstChild("Workshops")
	local list = {}
	for i = 1, PLOT_COUNT do
		local m = folder and folder:FindFirstChild("Plot_" .. i)
		local base = m and m:FindFirstChild("Base")
		if m and base and base:IsA("BasePart") then
			list[i] = { Model = m, Base = base }
		end
	end
	return list, folder
end

-- helpers = { newFakeCharacter, partPoly, polySeparation } (locals of Scenarios.luau, passed in)
function Tests.make(helpers)
	local partPoly, separation = helpers.partPoly, helpers.polySeparation

	-- Worst separation between any part of `a` and any part of `b` (parts lists); count of overlaps.
	-- Broad-phased and yielding (TrackChainTests.footprintOverlaps): the count is exact; the worst separation is
	-- exact whenever some pair lies within BROAD_MARGIN studs (math.huge, shown as -1, when none does).
	local function overlaps(a, b)
		local hits, worst, pa, pb = TrackChain.footprintOverlaps(a, b, partPoly, separation, OVERLAP_TOL)
		return hits, worst, pa and (pa:GetFullName() .. "/" .. pb:GetFullName()) or ""
	end

	local function roadParts()
		local list = {}
		for _, d in parts(Workspace:FindFirstChild("Track")) do
			if d.Name ~= "Ground" and d.Name ~= "Start" then -- as in spawn_area: neither is road
				table.insert(list, d)
			end
		end
		return list
	end

	local W = {}

	function W.world_layout()
		local r, flag = H.report("world_layout")
		local m = r.metrics
		local area = Workspace:FindFirstChild("SpawnArea")
		local floor = area and area:FindFirstChild("Floor")
		local hubOk = area ~= nil and area:IsA("Model") and floor ~= nil and floor:IsA("BasePart")
		flag("world_hub_exists", hubOk)
		local plots, plotFolder = livePlots()
		local plotCount = 0
		for _ in plots do
			plotCount += 1
		end
		local start, roadWidth = track1Start()
		flag("world_track1_start_exists", start ~= nil)
		if not hubOk then
			return r
		end
		local centre = Vector3.new(floor.Position.X, 0, floor.Position.Z)

		-- 1. Hub at the world centre; the one SpawnLocation at the plaza centre
		local dOrigin = flatDist(centre, Vector3.zero)
		m.hub_centre = ("%.1f, %.1f"):format(centre.X, centre.Z)
		flag("world_hub_at_world_centre", dOrigin <= CENTRE_TOL, dOrigin, CENTRE_TOL)
		local spawns = {}
		for _, d in Workspace:GetDescendants() do
			if d:IsA("SpawnLocation") then
				table.insert(spawns, d)
			end
		end
		local spawn = area:FindFirstChild("Spawn")
		flag("world_one_spawn_location", #spawns == 1 and spawns[1] == spawn, #spawns, 1)
		local dSpawn = spawn and flatDist(spawn.Position, centre) or math.huge
		flag("world_spawn_at_plaza_centre", dSpawn <= CENTRE_TOL, dSpawn == math.huge and -1 or dSpawn, CENTRE_TOL)

		-- 2. Seven Dojo plots, 48 x 48, in a ring around the hub, 8 studs apart
		local tagged = 0
		for _, p in plots do
			if CollectionService:HasTag(p.Model, "WorkshopPlot") then
				tagged += 1
			end
		end
		flag("world_seven_plots", plotCount == PLOT_COUNT and tagged == PLOT_COUNT, plotCount, PLOT_COUNT)
		local square = plotCount == PLOT_COUNT
		local radii, angles = {}, {}
		for i = 1, PLOT_COUNT do
			local p = plots[i]
			if p then
				local s = p.Base.Size
				square = square and math.abs(s.X - PLOT_SIZE) <= GEOM_TOL and math.abs(s.Z - PLOT_SIZE) <= GEOM_TOL
				local off = p.Base.Position - centre
				table.insert(radii, Vector2.new(off.X, off.Z).Magnitude)
				table.insert(angles, math.deg(math.atan2(off.Z, off.X)))
			end
		end
		flag("world_plots_48_square", square)
		local rMin, rMax = math.huge, 0
		for _, rad in radii do
			rMin, rMax = math.min(rMin, rad), math.max(rMax, rad)
		end
		local ratio = rMax > 0 and rMin / rMax or 0
		m.plot_radius = ("%.1f .. %.1f"):format(rMin == math.huge and -1 or rMin, rMax)
		flag("world_plots_ring_radius", #radii == PLOT_COUNT and ratio >= RING_RADIUS_RATIO, ratio, RING_RADIUS_RATIO)
		table.sort(angles)
		local maxGap = #angles > 0 and 360 or 0
		if #angles > 1 then
			maxGap = angles[1] + 360 - angles[#angles]
			for i = 2, #angles do
				maxGap = math.max(maxGap, angles[i] - angles[i - 1])
			end
		end
		flag("world_plots_surround_hub", #angles == PLOT_COUNT and maxGap <= RING_MAX_GAP_DEG, maxGap, RING_MAX_GAP_DEG)
		local minGap = math.huge
		for i = 1, PLOT_COUNT do
			for j = i + 1, PLOT_COUNT do
				if plots[i] and plots[j] then
					minGap = math.min(minGap, separation(partPoly(plots[i].Base), partPoly(plots[j].Base)))
				end
			end
		end
		flag(
			"world_plots_no_overlap_gap_8",
			plotCount == PLOT_COUNT and minGap >= PLOT_GAP - OVERLAP_TOL,
			minGap == math.huge and -1 or minGap,
			PLOT_GAP
		)

		-- 3. No overlaps: plots vs roads, plots vs the hub's buildings, hub vs roads
		local roads = roadParts()
		local plotParts = parts(plotFolder)
		local hubParts = {}
		for _, d in parts(area) do
			if d ~= floor then -- the plaza floor may run under the plots; its buildings may not
				table.insert(hubParts, d)
			end
		end
		local hits, worst, name = overlaps(plotParts, roads)
		m.plot_road_gap = worst == math.huge and -1 or worst
		if hits > 0 then
			m.plot_road_overlap = name
		end
		flag("world_plots_clear_of_tracks", #roads > 0 and #plotParts > 0 and hits == 0, hits, 0)
		hits, _, name = overlaps(plotParts, hubParts)
		if hits > 0 then
			m.plot_hub_overlap = name
		end
		flag("world_plots_clear_of_hub_buildings", #plotParts > 0 and hits == 0, hits, 0)
		hits, worst, name = overlaps(parts(area), roads)
		m.hub_road_gap = worst == math.huge and -1 or worst
		if hits > 0 then
			m.hub_road_overlap = name
		end
		flag("world_hub_clear_of_tracks", #roads > 0 and hits == 0, hits, 0)

		-- 4. Track 1 starts at the start gate
		local pad = area:FindFirstChild("StartPad")
		local padOk = pad ~= nil and pad:IsA("BasePart") and CollectionService:HasTag(pad, "StartPad")
		local gateGap = (padOk and start) and separation(partPoly(pad), partPoly(start)) or math.huge
		flag(
			"world_track1_start_at_start_gate",
			padOk and start ~= nil and gateGap <= roadWidth,
			gateGap == math.huge and -1 or gateGap,
			roadWidth
		)

		-- 5. Safety baseplate under everything, plus a margin
		local plate = Workspace:FindFirstChild("Baseplate")
		local tiles = parts(plate)
		local plateOk = #tiles > 0
		local top = -math.huge
		for _, t in tiles do
			plateOk = plateOk and t.Anchored
			top = math.max(top, t.Position.Y + t.Size.Y / 2)
		end
		flag("world_baseplate_exists", plateOk)
		local floorTop = floor.Position.Y + floor.Size.Y / 2
		flag("world_baseplate_below_plaza", plateOk and top < floorTop, top, floorTop)
		local function covered(x, z)
			for _, t in tiles do
				local l = t.CFrame:PointToObjectSpace(Vector3.new(x, t.Position.Y, z))
				if math.abs(l.X) <= t.Size.X / 2 and math.abs(l.Z) <= t.Size.Z / 2 then
					return true
				end
			end
			return false
		end
		-- shortcut: samples the margin-grown corners of each part's world box, not the whole area; enough for the
		-- convex tiles a baseplate is made of, upgrade if tiles leave holes between sample points
		local uncovered, checked, firstMiss = 0, 0, nil
		for _, root in { area, plotFolder, Workspace:FindFirstChild("Track") } do
			for i, p in parts(root) do
				if i % 500 == 0 then
					task.wait() -- yield only: tens of thousands of parts x 5 points x every tile
				end
				local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
				for _, c in corners(p) do
					lo = Vector2.new(math.min(lo.X, c.X), math.min(lo.Y, c.Z))
					hi = Vector2.new(math.max(hi.X, c.X), math.max(hi.Y, c.Z))
				end
				lo -= Vector2.new(BASEPLATE_MARGIN, BASEPLATE_MARGIN)
				hi += Vector2.new(BASEPLATE_MARGIN, BASEPLATE_MARGIN)
				for _, pt in { lo, hi, Vector2.new(lo.X, hi.Y), Vector2.new(hi.X, lo.Y), (lo + hi) / 2 } do
					checked += 1
					if not covered(pt.X, pt.Y) then
						uncovered += 1
						firstMiss = firstMiss or p:GetFullName()
					end
				end
			end
		end
		m.baseplate_points_checked = checked
		m.baseplate_first_miss = firstMiss
		flag("world_baseplate_covers_everything", plateOk and checked > 0 and uncovered == 0, uncovered, 0)

		-- 6. No real names on the hub or the Dojos (spec 4 "no logos or real names", design doc section 5)
		local realNameIn = require(script.Parent.CatalogTests).realNameIn
		local named = {}
		for _, root in { area, plotFolder } do
			for _, d in root and root:GetDescendants() or {} do
				local text = (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text or d.Name
				local key = string.gsub(string.lower(text), "[^%w]+", "_")
				if realNameIn(key) then
					table.insert(named, d:GetFullName())
				end
			end
		end
		m.real_name_at = named[1]
		flag("world_no_real_names_in_hub_or_dojos", #named == 0, #named, 0)
		return r
	end

	function W.dojo()
		local r, flag = H.report("dojo")
		local m = r.metrics
		local catalog = H.module(Shared, "CharacterCatalog")
		local gconfig = H.module(Shared, "GachaConfig")
		local wconfig = H.module(Shared, "WorkshopConfig")
		local gacha = H.module(Server, "GachaService")
		local data = H.module(Server, "PlayerData")
		local money = H.module(Server, "MoneyService")
		local wservice = H.module(Server, "WorkshopService")
		local api = catalog
			and gconfig
			and wconfig
			and gacha
			and data
			and money
			and wservice
			and type(gacha.Grant) == "function"
			and type(gacha.Equip) == "function"
			and type(gacha.SetShowcase) == "function"
			and type(gacha.ShowcaseMulti) == "function"
			and type(gacha.Copies) == "function"
			and type(wservice.Assign) == "function"
			and type(wservice.Release) == "function"
			and type(wservice.PlotOf) == "function"
			and type(wservice.Rate) == "function"
			and type(wservice.Tick) == "function"
			and type(data.SetStore) == "function"
			and type(data.Load) == "function"
			and type(data.KeyFor) == "function"
		flag("dojo_api_exists", api == true)
		if not api then
			return r
		end
		flag(
			"dojo_config_seven_48_plots_squad_3",
			wconfig.PLOT_COUNT == PLOT_COUNT and wconfig.PLOT_SIZE == PLOT_SIZE and gconfig.SHOWCASE_SLOTS == SQUAD
		)
		local plots = livePlots()

		local cleanup, assigned = {}, {}
		local function fake(name)
			UID += 1
			local p = H.player(cleanup, UID)
			p.Name = "CarTestDojo" .. name
			p:SetAttribute("DisplayName", "DJ " .. name)
			pcall(money.Setup, p)
			pcall(data.Setup, p)
			pcall(gacha.Setup, p)
			return p
		end
		local function owners()
			local taken = {}
			for i = 1, PLOT_COUNT do
				local o = plots[i] and plots[i].Model:GetAttribute("Owner")
				if type(o) == "number" and o ~= 0 then
					taken[i] = true
				end
			end
			return taken
		end
		local function lowestFree()
			local taken = owners()
			for i = 1, PLOT_COUNT do
				if not taken[i] then
					return i
				end
			end
			return 0
		end
		local function assign(p)
			table.insert(assigned, p)
			local ok, idx = pcall(wservice.Assign, p)
			return ok and idx or -1
		end

		local ok, err = pcall(function()
			-- 1. Assignment: lowest free plot on join, freed on leave (IVS rules, spec 5)
			local want1 = lowestFree()
			local a = fake("A")
			local ia = assign(a)
			flag("dojo_join_lowest_free_plot", want1 > 0 and ia == want1 and wservice.PlotOf(a) == ia, ia, want1)
			local want2 = lowestFree()
			local b = fake("B")
			local ib = assign(b)
			flag("dojo_second_join_next_free_plot", want2 > 0 and ib == want2 and ib ~= ia, ib, want2)
			pcall(wservice.Release, a)
			local freed = wservice.PlotOf(a) == 0 and plots[ia] ~= nil and plots[ia].Model:GetAttribute("Owner") == 0
			flag("dojo_leave_frees_plot", freed)
			local c = fake("C")
			local ic = assign(c)
			flag("dojo_rejoin_gets_freed_plot", ic == ia, ic, ia)

			-- 2. Squad of 3 owned characters not in the Team; cross-rejection both ways
			local ids = {}
			for _, spec in catalog.Rollable() do
				if #ids < 5 then
					table.insert(ids, spec.Id)
				end
			end
			local s = fake("Squad")
			for _, id in ids do
				gacha.Grant(s, id)
			end
			gacha.Grant(s, ids[2]) -- one copy, so the multiplier depends on copies too
			flag("dojo_team_equip_ok", gacha.Equip(s, ids[1]) == true and s:GetAttribute("EquippedCar") == ids[1])
			local team = s:GetAttribute("EquippedCar")
			local okSet = gacha.SetShowcase(s, { ids[2], ids[3], ids[4] })
			flag(
				"dojo_squad_of_three_accepted",
				okSet == true and s:GetAttribute("Showcase") == table.concat({ ids[2], ids[3], ids[4] }, ",")
			)
			local shown, multi = s:GetAttribute("Showcase"), s:GetAttribute("ShowcaseMulti")
			local okFour = gacha.SetShowcase(s, { ids[2], ids[3], ids[4], ids[5] })
			flag("dojo_squad_of_four_rejected", okFour == false and s:GetAttribute("Showcase") == shown)
			local okTeamIn = gacha.SetShowcase(s, { ids[2], team })
			flag(
				"dojo_squad_with_team_member_rejected",
				okTeamIn == false and s:GetAttribute("Showcase") == shown and s:GetAttribute("ShowcaseMulti") == multi
			)
			local okEquipSquad = gacha.Equip(s, ids[3])
			flag(
				"dojo_team_with_squad_member_rejected",
				okEquipSquad == false and s:GetAttribute("EquippedCar") == team and s:GetAttribute("Showcase") == shown
			)
			if type(gacha.SetTeam) == "function" then -- SetTeam lands with stamina (TEAM_AND_STAMINA_SPEC)
				local okT = gacha.SetTeam(s, { ids[3] })
				flag("dojo_set_team_with_squad_member_rejected", okT == false and s:GetAttribute("Showcase") == shown)
			end
			flag(
				"dojo_team_equip_non_squad_ok",
				gacha.Equip(s, ids[5]) == true and s:GetAttribute("EquippedCar") == ids[5]
			)
			-- ids[1] left the Team, so it may now join the squad; the new Team member may not
			local okFormer = gacha.SetShowcase(s, { ids[1], ids[2], ids[3] })
			flag("dojo_former_team_member_may_join_squad", okFormer == true)
			local okNew = gacha.SetShowcase(s, { ids[5] })
			flag("dojo_new_team_member_rejected_from_squad", okNew == false)
			gacha.SetShowcase(s, { ids[2], ids[3], ids[4] })

			-- 3. Multiplier: the IVS Showcase formula with unchanged numbers
			local want = 1
			for _, id in { ids[2], ids[3], ids[4] } do
				local spec = catalog.Get(id)
				local mult = spec and spec.SpeedMulti or 1
				if mult > 1 then
					local copies = math.min(gacha.Copies(s, id), SPEC.MAX_COPIES)
					want += SPEC.SCALE * math.log10(mult) * (1 + SPEC.COPY_BONUS * copies)
				end
			end
			local got = gacha.ShowcaseMulti(s)
			flag(
				"dojo_squad_multiplier_unchanged",
				near(got, want) and near(s:GetAttribute("ShowcaseMulti"), want),
				got,
				want
			)

			-- 3b. Old save (owner 2026-10-30, spec section 5): an equipped character also in the Showcase is dropped from
			-- the squad on load, its slot left empty; the other members keep their order; the Team is unchanged.
			-- Case "last": equipped in slot 3; case "middle": equipped in slot 2. Empty entries are ignored when reading
			-- the squad, so either "a,,c" or "a,c" may represent the empty slot.
			local function squadOf(p)
				local list = {}
				for _, id in string.split(p:GetAttribute("Showcase") or "", ",") do
					if id ~= "" then
						table.insert(list, id)
					end
				end
				return list
			end
			local base = UID + 500
			local cases = {
				{ Name = "last", Uid = base + 1, Squad = { ids[2], ids[3], ids[1] }, Keep = { ids[2], ids[3] } },
				{ Name = "middle", Uid = base + 2, Squad = { ids[2], ids[1], ids[3] }, Keep = { ids[2], ids[3] } },
			}
			local records = {}
			for _, case in cases do
				records[data.KeyFor(case.Uid)] = {
					Version = 12,
					Money = 10,
					Speed = 1000,
					WorkshopLevel = 1,
					Cars = { ids[1], ids[2], ids[3] },
					Copies = {},
					Showcase = case.Squad,
					Equipped = ids[1],
				}
			end
			data.SetStore(H.store(records))
			for _, case in cases do
				local p = H.player(cleanup, case.Uid)
				p.Name = "CarTestDojoOldSave_" .. case.Name
				local loaded = data.Load(p, case.Uid) == true
				local squad = squadOf(p)
				local wantMulti = 1
				for _, id in case.Keep do
					local spec = catalog.Get(id)
					local mult = spec and spec.SpeedMulti or 1
					if mult > 1 then
						wantMulti += SPEC.SCALE * math.log10(mult)
					end
				end
				flag("dojo_old_save_loads_" .. case.Name, loaded)
				flag(
					"dojo_old_save_drops_team_member_from_squad_" .. case.Name,
					loaded and not table.find(squad, ids[1]),
					table.concat(squad, ","),
					table.concat(case.Keep, ",")
				)
				flag(
					"dojo_old_save_keeps_other_squad_members_" .. case.Name,
					loaded and H.same(squad, case.Keep),
					table.concat(squad, ","),
					table.concat(case.Keep, ",")
				)
				flag("dojo_old_save_team_unchanged_" .. case.Name, p:GetAttribute("EquippedCar") == ids[1])
				flag(
					"dojo_old_save_multiplier_without_dropped_" .. case.Name,
					near(p:GetAttribute("ShowcaseMulti"), wantMulti),
					p:GetAttribute("ShowcaseMulti"),
					wantMulti
				)
			end
			data.SetStore(nil)

			-- 4. Idle Speed in the Dojo's training zone, multiplied by the squad
			local iS = assign(s)
			local withSquad = wservice.Rate(s)
			gacha.SetShowcase(s, {})
			local noSquad = wservice.Rate(s)
			gacha.SetShowcase(s, { ids[2], ids[3], ids[4] })
			flag(
				"dojo_rate_scales_with_squad",
				noSquad > 0 and near(withSquad / noSquad, want, 1e-6),
				noSquad > 0 and withSquad / noSquad or -1,
				want
			)
			local plot = iS > 0 and plots[iS]
			local zone = plot
				and plot.Model:FindFirstChild("Workshop")
				and plot.Model.Workshop:FindFirstChild("Zone", true)
			flag("dojo_zone_exists", zone ~= nil and zone:IsA("BasePart"))
			if zone then
				local area = Workspace:FindFirstChild("SpawnArea")
				local floor = area and area:FindFirstChild("Floor")
				local function avatarAt(pos)
					local model = helpers.newFakeCharacter(CFrame.new(pos))
					model.Name = "CarTestDojoCharacter"
					for _, d in model:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
						end
					end
					model:PivotTo(CFrame.new(pos))
					table.insert(cleanup, model)
					return model
				end
				local floorY = zone.Position.Y - zone.Size.Y / 2
				local inside = avatarAt(Vector3.new(zone.Position.X, floorY + 3, zone.Position.Z))
				local rate = wservice.Rate(s)
				local gain = wservice.Tick(s, 1, inside)
				flag("dojo_zone_earns_idle_speed", gain > 0 and near(gain, rate, 1e-6), gain, rate)
				local plaza = floor and floor.Position + Vector3.new(0, floor.Size.Y / 2 + 3, 0)
					or zone.Position + Vector3.new(500, 0, 500)
				local outside = avatarAt(plaza)
				local none = wservice.Tick(s, 1, outside)
				flag("dojo_outside_zone_earns_nothing", none == 0, none, 0)
			end
			m.plots = ("%d/%d/%d/%d"):format(ia, ib, ic, iS)
		end)
		flag("dojo_no_error", ok)
		if not ok then
			m.error = tostring(err)
		end
		pcall(data.SetStore, nil)
		for _, p in assigned do
			pcall(wservice.Release, p)
		end
		for _, x in cleanup do
			x:Destroy()
		end
		return r
	end

	return W
end

return Tests
