--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md 4.2 "Redrafted spawn pieces" (owner 2026-11-25, "approved all": spot S4 and the
-- fuller layout), written red before the build.
--   gate_*: the world gate as gate draft B (tools/blender/plaza/draft_gate.py concept_b). Place, facing, destination and
--     lock rule unchanged; a touch part that is no disc and fills B's doorway; the label over B's roof; a locked and an
--     open mesh in Shared/PlazaPieces, inside today's gate footprint.
--   boss_gate_*: draft A (draft_boss_gate.py) at S4 facing the spawn, whole on the floor, its own prompt, a closed and an
--     open mesh, and the guide with a prompt of its own; its off switch (boss_gate_off_*), look and prompt rule.
--   altar_*: World 1 the great lotus (draft B), World 2 the twin-roof stage (draft A), a locked and an unlocked mesh of
--     each, so a player below rebirth 2 sees it locked. Place, prompt and the model spot stay.
--   merchant_*: Shared/PlazaMerchants' cast, the same in both worlds, standing static at the five stalls.
--   stall_*: the services' places, facings and prompts. The Index and the Team altar move to the fuller layout; every other
--     row passes before the build and must stay so.
--   layout_*: the statue and the sky loop's posts of the fuller layout.
-- Sizes are the drafts' (**proposed** in the spec). Names the build does not have yet (PlazaAssets keys and LoopPosts, the
-- altar's Look attribute, PlazaMerchants, MerchantSpot, BossGate, OpenBosses, TalkBossGuide) are this test's contract,
-- **proposed**.
-- It builds a fresh plaza outside the DataModel, so hub-local positions are read directly (world + (118, -80)). Not covered
-- here: the wiring of the client scripts (ui_boss_gate), the meshes' looks, the client's altar display and locked label, header heights, loading of the merchants' models
-- (4.47 "every world shows" is open), collision by walking, the boss event states, views from the spawn.
-- Offline: lune run tools/lune/server_scenarios <1|2> PlazaBuildTests.plaza_build PlazaBuildTests.plaza_build_pending
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local TOL = 0.15 -- studs: the approved spots are written to 0.1
local FLOOR = 1 -- SpawnArea.TOP_Y
local HUB = Vector2.new(118, -80) -- SpawnArea.CENTRE: the spawn, hub-local

-- Draft B (draft_gate.py: --stats, AR, SPRING, DAIS): studs over the floor, gate-local
local GATE = {
	At = Vector2.new(194, -176), -- hub-local, unchanged
	DoorWidth = 17.2, -- 2 * AR
	DoorMinWidth = 15, -- no gap wide enough to run past the touch part
	DoorTop = 24.2, -- SPRING + AR
	SillMax = 2.5, -- the touch part starts at a runner's feet (dais 1.2, threshold 1.9)
	ChestMin = 8, -- and reaches over a runner
	RoofTop = 36.5,
	MeshMax = Vector3.new(35.7, 36.6, 30), -- x, y, z: today's gate's footprint, B's height
}

-- Each service: hub-local spot (as built today, the Index and the Team altar as the fuller layout), what it faces, its prompt. Distances are the prompts' own.
local STALLS = {
	{
		Name = "ShopStall",
		At = Vector2.new(34.058, -83.109),
		Prompt = "OpenShop",
		Action = "Open Shop",
		Object = "SHOP",
		Distance = 10,
	},
	{
		Name = "PotionsStall",
		At = Vector2.new(60.842, -141.555),
		Prompt = "OpenPotions",
		Action = "Potions",
		Object = "POTIONS",
		Distance = 10,
	},
	{
		Name = "Marketplace",
		At = Vector2.new(121.109, -163.942),
		Prompt = "OpenMarket",
		Action = "Browse Market",
		Object = "Market",
		Distance = 8,
	},
	{
		Name = "IndexBoard",
		At = Vector2.new(194.7, -114.2),
		Prompt = "OpenIndex",
		Action = "Open Index",
		Object = "Runner Index",
		Distance = 12,
	},
	{
		Name = "CheckpointNpc",
		At = Vector2.new(38.021, -22.109),
		Face = Vector2.new(106.066, 51.170),
		Prompt = "OpenCheckpoints",
		Action = "Tracks",
		Object = "Track overview",
	},
	{
		Name = "TeamAltar",
		At = Vector2.new(83, -3.6),
		Prompt = "OpenTeam",
		Action = "Team",
		Object = "TEAM SETUP",
		Distance = 12,
	},
	{
		Name = "SidekickAltar",
		At = Vector2.new(175.158, -18.445),
		Prompt = "OpenSidekicks",
		Action = "Summon",
		Object = "SIDEKICKS",
		Distance = 16,
	},
}

-- Fuller layout (owner 2026-11-25). PosTol as the spawn_area scenario: a small inward shift of the boss gate stays inside
-- it (its base is 0.2 from the floor's south edge at the exact spot, a fault to fix while building).
local LAYOUT = {
	PosTol = 2.5,
	BossGate = Vector2.new(2.5, 94.8) + HUB,
	Statue = Vector2.new(-16.5, 4.4), -- world
	Posts = { 19, 75, 200, 250, 322 }, -- degrees in the world (x, z) plane from +x
	Floor = Vector2.new(94, 110), -- half of SpawnArea.FLOOR_SIZE
	FloorMargin = 1, -- studs (proposed)
	GuideApart = 4, -- studs between the gate's and the guide's prompt parts, so both can be reached (proposed)
}

local CAST = { -- owner 2026-11-25, "approved merchant casts"; names are the tweaked ones (design doc 5)
	ShopStall = { "sea_navigator", "Nammi" },
	PotionsStall = { "leaf_medic", "Sakara" },
	Marketplace = { "ds_flame", "Rengoko" },
	IndexBoard = { "fr_mage", "Frierin" },
	CheckpointNpc = { "leaf_copycat", "Kakashe" },
}

local function find(root, class, name)
	for _, d in root and root:GetDescendants() or {} do
		if d:IsA(class) and (name == nil or d.Name == name) then
			return d
		end
	end
	return nil
end

local function flat(v)
	return Vector2.new(v.X, v.Z)
end

-- The union of an asset's parts, as Vector3 size and lowest y; nil without the asset.
local function bounds(asset)
	local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, p in asset and asset.Parts or {} do
		local a, b = p.Center - p.Size / 2, p.Center + p.Size / 2
		lo = Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z))
		hi = Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z))
	end
	return hi.X >= lo.X and hi - lo or nil, lo.Y
end

-- What waits (owner 2026-11-25: guards always on in plaza_build, these on demand in plaza_build_pending). 0 checks (the merchants landed
-- 2026-11-25; TestConfig's OnDemand entry went with them). The gate's and the
-- altar's geometry is judged as if the pieces were uploaded (Shared/PlazaPieces; plaza_pieces has the state before). When a
-- row's work lands, take the row out here: the check is then a guard of plaza_build. Keep the count in TestConfig's comment.
local PENDING = {}

local function run(scenario, pending)
	local r, record = H.report(scenario)
	local seen = {}
	local function flag(key, ...)
		seen[key] = true
		if (PENDING[key] ~= nil) == pending then
			record(key, ...)
		end
	end
	local WorldConfig, SpawnArea = require(Shared.WorldConfig), require(Shared.SpawnArea)
	local PlazaAssets, Catalog = require(Shared.PlazaAssets), require(Shared.CharacterCatalog)
	local Pieces = H.module(Shared, "PlazaPieces")
	local pieceRows = Pieces and Pieces.Assets or {}
	-- Runs fn as if the spawn pieces were uploaded (made-up ids, put back)
	local function uploaded(fn)
		local ids = {}
		for key, row in pieceRows do
			ids[key], row.Asset = row.Asset, 1
		end
		local okRun, result = pcall(fn)
		for key, row in pieceRows do
			row.Asset = ids[key]
		end
		if not okRun then
			error(result, 0)
		end
		return result
	end
	local world = WorldConfig.Id
	local function text(v)
		return v == nil and "missing" or tostring(v)
	end

	local oldOpen = WorldConfig.GATE_OPEN
	-- The boss gate's off switch (lead 2026-11-25): its checks below run with it on; boss_gate_off_* with it off.
	local Switch, GuideSwitch = H.module(Shared, "BossGateConfig"), H.module(Shared, "BossGuideConfig")
	local gateWas, guideWas = Switch and Switch.LIVE, GuideSwitch and GuideSwitch.LIVE
	local ok, err = xpcall(function()
		flag("boss_gate_off_by_default", gateWas == false, text(gateWas), "false")
		Switch.LIVE = false
		local offArea = SpawnArea.Build(CFrame.new())
		flag("boss_gate_off_not_built", offArea:FindFirstChild("BossGate") == nil)
		flag("boss_gate_off_no_prompt", find(offArea, "ProximityPrompt", "OpenBosses") == nil)
		local CollectionService = game:GetService("CollectionService")
		local tagged = 0
		for _, d in offArea:GetDescendants() do
			tagged += (CollectionService:HasTag(d, Switch.CLOSED_TAG) or CollectionService:HasTag(d, Switch.OPEN_TAG)) and 1 or 0
		end
		flag("boss_gate_off_no_tag", tagged == 0, tagged, 0)
		flag("boss_gate_off_never_open", not Switch.IsOpen(true, 99))
		-- the fuller layout does not wait for the gate
		for _, name in { "IndexBoard", "TeamAltar" } do
			flag("boss_gate_off_keeps_" .. name, offArea:FindFirstChild(name) ~= nil)
		end
		local live = workspace:FindFirstChild("SpawnArea")
		if live then
			flag("boss_gate_live_as_switched", (live:FindFirstChild("BossGate") ~= nil) == (gateWas == true))
		end
		local Service = H.module(script.Parent.Parent, "BossGate")
		if Service and not live then
			ReplicatedStorage:SetAttribute(Switch.OPEN_ATTRIBUTE, nil)
			Service.Start()
			ReplicatedStorage:SetAttribute("BossEventPhase", "Fight")
			local state = ReplicatedStorage:GetAttribute(Switch.OPEN_ATTRIBUTE)
			flag("boss_gate_off_no_attribute", state == nil, text(state), "nil")
			ReplicatedStorage:SetAttribute("BossEventPhase", nil)
		end
		Switch.LIVE = true
		local area = SpawnArea.Build(CFrame.new())

		-- Guards: positions, facings and prompts (green before the build too)
		for _, s in STALLS do
			local model = area:FindFirstChild(s.Name)
			local prompt = find(model, "ProximityPrompt", s.Prompt)
			local key = "stall_" .. s.Name
			flag(key .. "_prompt", prompt ~= nil)
			if prompt then
				flag(key .. "_action", prompt.ActionText == s.Action, prompt.ActionText, s.Action)
				flag(key .. "_object", prompt.ObjectText == s.Object, prompt.ObjectText, s.Object)
				local reach = s.Distance or require(Shared.CheckpointConfig).PROMPT_DISTANCE
				flag(key .. "_distance", prompt.MaxActivationDistance == reach, prompt.MaxActivationDistance, reach)
				flag(key .. "_key_e", prompt.KeyboardKeyCode == Enum.KeyCode.E and prompt.HoldDuration == 0)
				-- the prompt part stands on the service's axis, on its front or at its centre
				local part = prompt.Parent
				local dir = ((s.Face or HUB) - s.At).Unit
				local rel = flat(part.CFrame.Position) - s.At
				local aside = math.abs(rel.X * dir.Y - rel.Y * dir.X)
				flag(key .. "_on_axis", aside <= TOL, aside, TOL)
				flag(key .. "_front", rel:Dot(dir) >= -TOL and rel:Dot(dir) <= 5, rel:Dot(dir), 5)
				if s.Name ~= "SidekickAltar" and s.Name ~= "TeamAltar" then -- their prompt part is one bar of an octagon, turned its own way
					local look = flat(part.CFrame.LookVector)
					flag(key .. "_facing", look:Dot(dir) >= 0.999, look:Dot(dir), 0.999)
				end
			end
		end

		-- The fuller layout's statue and posts
		local exclusive = PlazaAssets.Exclusive
		local moved = (flat(exclusive.Pos) - LAYOUT.Statue).Magnitude
		flag("layout_statue", moved <= LAYOUT.PosTol, moved, LAYOUT.PosTol)
		local front = flat(exclusive.Face).Unit:Dot(-LAYOUT.Statue.Unit)
		flag("layout_statue_faces_spawn", front >= 0.98, front, 0.98)
		local posts = Pieces and Pieces.Ready("SkyLoop") and pieceRows.SkyLoop.Posts
		local same = type(posts) == "table" and #posts == #LAYOUT.Posts
		for i, deg in LAYOUT.Posts do
			same = same and posts[i] == deg
		end
		flag(
			"layout_loop_posts",
			same,
			posts and table.concat(posts, " ") or "missing",
			table.concat(LAYOUT.Posts, " ")
		)

		-- Boss gate A and its guide
		local boss = area:FindFirstChild("BossGate")
		flag("boss_gate_model", boss ~= nil, boss and 1 or "no SpawnArea.BossGate", 1)
		local bossPrompt = find(boss, "ProximityPrompt", "OpenBosses")
		flag(
			"boss_gate_prompt",
			bossPrompt ~= nil and bossPrompt.KeyboardKeyCode == Enum.KeyCode.E,
			bossPrompt and 1 or "missing",
			1
		)
		local root = boss and boss.PrimaryPart
		local bossAt = root and flat(root.CFrame.Position)
		local bossLook = root and flat(root.CFrame.LookVector) or Vector2.zero
		local far = bossAt and (bossAt - LAYOUT.BossGate).Magnitude or -1
		flag("boss_gate_at_s4", bossAt ~= nil and far <= LAYOUT.PosTol, far, LAYOUT.PosTol)
		local toSpawn = bossAt and bossLook:Dot((HUB - bossAt).Unit) or -1
		flag("boss_gate_faces_spawn", toSpawn >= 0.98, toSpawn, 0.98)
		for _, key in { "BossGateClosed", "BossGateOpen" } do
			local asset = pieceRows[key]
			flag(
				"boss_gate_mesh_" .. key,
				asset ~= nil and asset.Asset ~= 0,
				asset and asset.Asset or "no row",
				"an id"
			)
			-- every corner of its parts' boxes, stood at the gate's spot, is over the floor (an asset's front is its +Z)
			local margin = nil
			for _, p in bossAt and asset and asset.Parts or {} do
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local lx, lz = p.Center.X + sx * p.Size.X / 2, p.Center.Z + sz * p.Size.Z / 2
						local at = bossAt - HUB + bossLook * lz + Vector2.new(bossLook.Y, -bossLook.X) * lx
						local gap = math.min(LAYOUT.Floor.X - math.abs(at.X), LAYOUT.Floor.Y - math.abs(at.Y))
						margin = math.min(margin or gap, gap)
					end
				end
			end
			local wide = margin ~= nil and margin >= LAYOUT.FloorMargin
			flag("boss_gate_mesh_" .. key .. "_on_plaza", wide, margin or "missing", LAYOUT.FloorMargin)
		end
		-- The guide is its own model (Server/BossGuide): in the world only while both switches are on (BossGuideTests has
		-- all four states). Its checks read what Start puts there; a live server's own guide is judged as switched.
		local Guide = H.module(script.Parent.Parent, "BossGuide")
		local guide
		if live then
			local want = gateWas == true and guideWas == true
			guide = workspace:FindFirstChild("BossGuide")
			flag("boss_guide_live_as_switched", (guide ~= nil) == want, guide and 1 or 0, want and 1 or 0)
			guide = guide or Guide and Guide.Build(CFrame.new())
		elseif Guide then
			GuideSwitch.LIVE = false
			Guide.Start(CFrame.new())
			flag("boss_guide_absent_while_off", workspace:FindFirstChild("BossGuide") == nil)
			GuideSwitch.LIVE = true
			Guide.Start(CFrame.new())
			guide = workspace:FindFirstChild("BossGuide")
			flag("boss_guide_present_while_on", guide ~= nil)
			if guide then
				guide.Parent = nil
			end
		end
		local talk = find(guide, "ProximityPrompt", "TalkBossGuide")
		flag("boss_guide_prompt", talk ~= nil and talk.KeyboardKeyCode == Enum.KeyCode.E, talk and 1 or "missing", 1)
		local guideRig = guide and guide:FindFirstChild("Rig")
		local guideId = guideRig and guideRig:GetAttribute("CharacterId")
		flag("boss_guide_is_jk_strongest", guideId == "jk_strongest", text(guideId), "jk_strongest")
		local apart = bossPrompt
				and talk
				and (bossPrompt.Parent.CFrame.Position - talk.Parent.CFrame.Position).Magnitude
			or -1
		flag("boss_gate_prompts_apart", apart >= LAYOUT.GuideApart, apart, LAYOUT.GuideApart)
		local reach = bossPrompt and talk and bossPrompt.MaxActivationDistance + talk.MaxActivationDistance or math.huge
		flag("boss_gate_prompts_never_both", apart > reach, apart, reach == math.huge and "missing" or reach)
		-- The shared layout (Shared/BossGateConfig): the gate stands by it, and its two prompts' reaches never meet
		local GateConfig = H.module(Shared, "BossGateConfig")
		flag("boss_gate_config", GateConfig ~= nil)
		if GateConfig then
			local a, b = GateConfig.At(GateConfig.PROMPT_OFFSET), GateConfig.At(GateConfig.GUIDE_OFFSET)
			local gap, both = (a - b).Magnitude, GateConfig.PROMPT_DISTANCE + GateConfig.GUIDE_PROMPT_DISTANCE
			flag("boss_gate_config_reaches_apart", gap > both, gap, both)
			local at = bossPrompt and flat(bossPrompt.Parent.CFrame.Position) - HUB
			local off = at and (at - a).Magnitude or -1
			flag("boss_gate_prompt_by_config", at ~= nil and off <= TOL, off, TOL)
			local placed = bossAt and (bossAt - HUB - GateConfig.POS).Magnitude or -1
			flag("boss_gate_by_config", bossAt ~= nil and placed <= TOL, placed, TOL)
			-- a stand-in inside the mesh's box, on the floor with the same margin
			local least = math.huge
			for _, d in boss and boss:GetDescendants() or {} do
				if d:IsA("BasePart") then
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = d.CFrame * Vector3.new(sx * d.Size.X / 2, 0, sz * d.Size.Z / 2)
							local gapX = LAYOUT.Floor.X - math.abs(w.X - HUB.X)
							least = math.min(least, gapX, LAYOUT.Floor.Y - math.abs(w.Z - HUB.Y))
						end
					end
				end
			end
			flag("boss_gate_stand_in_on_plaza", least >= LAYOUT.FloorMargin and least < math.huge, least, 1)
			-- open only with an active event and past the rebirth that shows the Bosses button
			local need = require(Shared.SidekickConfig).HudFromRebirth
			flag(
				"boss_gate_closed_without_event",
				not GateConfig.IsOpen(false, need) and not GateConfig.IsOpen(nil, need)
			)
			flag(
				"boss_gate_closed_below_rebirth",
				not GateConfig.IsOpen(true, need - 1) and not GateConfig.IsOpen(true)
			)
			flag("boss_gate_open_in_event", GateConfig.IsOpen(true, need))
			local built = { Closed = 0, Open = 0 }
			for _, d in boss and boss:GetDescendants() or {} do
				built.Closed += CollectionService:HasTag(d, GateConfig.CLOSED_TAG) and (d.Transparency or 0) == 0 and 1 or 0
				built.Open += CollectionService:HasTag(d, GateConfig.OPEN_TAG) and d.Transparency == 1 and 1 or 0
			end
			flag("boss_gate_built_closed", built.Closed > 0 and built.Open > 0)

			-- The client's part (Client/BossGateView, Client/BossEventUi) through the functions it runs.
			local Look = H.module(Shared, "BossGateLook")
			flag("boss_gate_look_module", Look ~= nil)
			if Look and not live then -- never repaints a live server's gate
				boss.Parent = workspace
				for _, state in { { "open", true }, { "closed", false } } do
					Look.Apply(state[2])
					local wrong, shadows = 0, 0
					for tag, shown in { [GateConfig.CLOSED_TAG] = not state[2], [GateConfig.OPEN_TAG] = state[2] } do
						for _, part in CollectionService:GetTagged(tag) do
							wrong += part.Transparency == (shown and 0 or 1) and 0 or 1
							local shadow = shown and tag == GateConfig.CLOSED_TAG
							shadows += part.CastShadow == shadow and 0 or 1
						end
					end
					flag("boss_gate_look_" .. state[1], wrong == 0, wrong, 0)
					flag("boss_gate_look_shadows_" .. state[1], shadows == 0, shadows, 0)
				end
			end
			flag("boss_gate_prompt_rule", type(GateConfig.PromptOpens) == "function")
			if GateConfig.PromptOpens and not live then
				local function press(p, button, panel, active, rebirth)
					return GateConfig.PromptOpens(p, button, panel, active, rebirth)
				end
				local outside = Instance.new("ProximityPrompt")
				outside.Name = GateConfig.PROMPT
				flag("boss_gate_press_open", press(bossPrompt, true, false, true, need) == true)
				flag("boss_gate_press_closed_nothing", press(bossPrompt, true, false, false, need) == false)
				flag("boss_gate_press_no_state_nothing", press(bossPrompt, true, false, nil, need) == false)
				flag("boss_gate_press_below_rebirth_nothing", press(bossPrompt, true, false, true, need - 1) == false)
				flag("boss_gate_press_no_button_nothing", press(bossPrompt, false, false, true, need) == false)
				flag("boss_gate_press_panel_open_nothing", press(bossPrompt, true, true, true, need) == false)
				flag("boss_gate_press_other_prompt_nothing", press(talk, true, false, true, need) == false)
				flag("boss_gate_press_not_in_world_nothing", press(outside, true, false, true, need) == false)
				GateConfig.LIVE = false
				flag("boss_gate_press_off_nothing", press(bossPrompt, true, false, true, need) == false)
				GateConfig.LIVE = true
			end
			if not live and boss then
				boss.Parent = area
			end
		end
		-- The server's state follows the attribute the Bosses panel reads
		local Gate = H.module(script.Parent.Parent, "BossGate")
		flag("boss_gate_service", Gate ~= nil)
		if Gate and GateConfig and not workspace:FindFirstChild("SpawnArea") then -- never moves a live event's state
			local before = ReplicatedStorage:GetAttribute("BossEventPhase")
			ReplicatedStorage:SetAttribute("BossEventPhase", nil)
			Gate.Start()
			local key = GateConfig.OPEN_ATTRIBUTE
			flag("boss_gate_state_closed", ReplicatedStorage:GetAttribute(key) == false)
			for _, phase in { "Prep", "Fight" } do
				ReplicatedStorage:SetAttribute("BossEventPhase", phase)
				flag("boss_gate_state_open_" .. phase, ReplicatedStorage:GetAttribute(key) == true)
			end
			ReplicatedStorage:SetAttribute("BossEventPhase", nil)
			flag("boss_gate_state_closes", ReplicatedStorage:GetAttribute(key) == false)
			ReplicatedStorage:SetAttribute("BossEventPhase", before)
		end

		-- World gate B. The gate that ships (the table's own ids) and the one with ids filled in hold the same rules; draft B's
		-- geometry is judged on the second, under the first's names.
		local function gate(open)
			WorldConfig.GATE_OPEN = open
			local shipped = SpawnArea.WorldGate(CFrame.new())
			local piece = uploaded(function()
				return SpawnArea.WorldGate(CFrame.new())
			end)
			WorldConfig.GATE_OPEN = oldOpen
			return { { "", shipped }, { "piece_", piece } }
		end
		for _, state in { { "locked", false }, { "open", true } } do
			local locked = world == 1 and not state[2] -- World 2's gate leads back and is always open
			for _, build in gate(state[2]) do
				local m = build[2]
				local portal = m:FindFirstChild("Portal")
				local key = "gate_" .. build[1] .. state[1]
				flag(key .. "_portal", portal ~= nil)
				if not portal then
					continue
				end
				local at = flat(portal.CFrame.Position)
				flag(key .. "_place", (at - GATE.At).Magnitude <= TOL, (at - GATE.At).Magnitude, TOL)
				local target = world == 1 and 2 or 1
				flag(
					key .. "_destination",
					portal:GetAttribute("TargetWorld") == target,
					portal:GetAttribute("TargetWorld"),
					target
				)
				flag(
					key .. "_lock_rule",
					portal:GetAttribute("Locked") == locked,
					text(portal:GetAttribute("Locked")),
					text(locked)
				)
				flag(key .. "_touch", (portal.CanTouch == true) == not locked)
				local barrier = m:FindFirstChild("Barrier")
				flag(key .. "_barrier", (barrier ~= nil and barrier.CanCollide ~= false) == locked)
				-- the box of the touch part in the gate's own frame: x across the doorway, z through it
				local frame = CFrame.lookAt(Vector3.new(GATE.At.X, FLOOR, GATE.At.Y), Vector3.new(HUB.X, FLOOR, HUB.Y))
				local rel, s = frame:ToObjectSpace(portal.CFrame), portal.Size
				local x = math.abs(rel.RightVector.X) * s.X
					+ math.abs(rel.UpVector.X) * s.Y
					+ math.abs(rel.LookVector.X) * s.Z
				local y = math.abs(rel.RightVector.Y) * s.X
					+ math.abs(rel.UpVector.Y) * s.Y
					+ math.abs(rel.LookVector.Y) * s.Z
				local bottom, top = rel.Position.Y - y / 2, rel.Position.Y + y / 2
				flag(key .. "_touch_fills_doorway", x >= GATE.DoorMinWidth, x, GATE.DoorMinWidth)
				local named = "gate_" .. state[1]
				if build[1] == "piece_" then
					flag(
						named .. "_touch_not_a_disc",
						portal.Shape ~= Enum.PartType.Cylinder,
						text(portal.Shape),
						"no Cylinder"
					)
					flag(
						named .. "_touch_fits_doorway",
						x <= GATE.DoorWidth + TOL and top <= GATE.DoorTop + TOL,
						x,
						GATE.DoorWidth
					)
					flag(
						named .. "_touch_at_runner_height",
						bottom <= GATE.SillMax and top >= GATE.ChestMin,
						bottom,
						GATE.SillMax
					)
				end
				local label = find(m, "BillboardGui", "Label")
				local offset = label and (label.StudsOffsetWorldSpace or Vector3.zero).Y or 0
				local height = portal.CFrame.Position.Y - FLOOR + offset
				if build[1] == "piece_" then
					flag(named .. "_label_over_roof", label ~= nil and height >= GATE.RoofTop, height, GATE.RoofTop)
				end
				local state2 = find(label, "TextLabel", "State")
				local want = locked and "COMING SOON" or "ENTER"
				flag(key .. "_label_text", state2 ~= nil and state2.Text == want, text(state2 and state2.Text), want)
			end
		end
		for _, key in { "WorldGateLocked", "WorldGateOpen" } do
			local asset = pieceRows[key]
			flag("gate_mesh_" .. key, asset ~= nil and asset.Asset ~= 0, asset and asset.Asset or "no row", "an id")
			local size, low = bounds(asset)
			local m = GATE.MeshMax
			flag(
				"gate_mesh_" .. key .. "_footprint",
				size ~= nil and size.X <= m.X + TOL and size.Z <= m.Z + TOL and size.Y <= m.Y + TOL,
				text(size),
				tostring(m)
			)
			flag("gate_mesh_" .. key .. "_on_floor", size ~= nil and math.abs(low) <= TOL, size and low or "missing", 0)
		end

		-- Summon altar per world
		local altar = area:FindFirstChild("SidekickAltar")
		local look = uploaded(function()
			return SpawnArea.Build(CFrame.new()).SidekickAltar:GetAttribute("Look")
		end)
		local wantLook = world == 1 and "GreatLotus" or "TwinRoof"
		flag("altar_look_of_this_world", look == wantLook, text(look), wantLook)
		for _, state in { "Locked", "Unlocked" } do
			local key = "Altar" .. wantLook .. state
			flag(
				"altar_mesh_" .. state,
				pieceRows[key] ~= nil and pieceRows[key].Asset ~= 0,
				pieceRows[key] and pieceRows[key].Asset or "no row",
				"an id"
			)
		end
		local spot = find(altar, "Attachment", "ModelSpot")
		flag("altar_model_spot", spot ~= nil)
		if spot then
			local off = (flat(spot.WorldCFrame.Position) - Vector2.new(175.158, -18.445)).Magnitude
			flag("altar_model_spot_centred", off <= 1, off, 1) -- draft A's spot is 0.8 ahead of the centre
		end

		-- Merchants (on: owner 2026-11-25), stood as PlazaDressing does once the stalls are in
		local Rigs = H.module(script.Parent.Parent, "PlazaMerchantRigs")
		flag("merchants_switch_on", Pieces.MERCHANTS_LIVE == true)
		if Rigs then
			uploaded(function()
				Rigs.Stand(area)
			end)
		end
		local source = Shared:FindFirstChild("PlazaMerchants")
		local cast = source and require(source) or nil
		flag("merchant_cast_module", cast ~= nil, cast and 1 or "no Shared/PlazaMerchants", 1)
		local rows = 0
		for _ in cast or {} do
			rows += 1
		end
		flag("merchant_cast_is_five", rows == 5, rows, 5)
		for stall, want in CAST do
			local id, name = want[1], want[2]
			local row = cast and cast[stall]
			flag("merchant_" .. stall .. "_id", row ~= nil and row.Id == id, text(row and row.Id), id)
			local spec = Catalog.Get(id)
			flag(
				"merchant_" .. stall .. "_tweaked_name",
				spec ~= nil and spec.Name == name,
				text(spec and spec.Name),
				name
			)
			local model = area:FindFirstChild(stall)
			local at = find(model, "Attachment", "MerchantSpot")
			flag(
				"merchant_" .. stall .. "_stands_there",
				at ~= nil and at:GetAttribute("CharacterId") == id,
				at and text(at:GetAttribute("CharacterId")) or "no MerchantSpot",
				id
			)
			-- whatever stands at the stall as the merchant is scenery: nothing moves, collides or answers a touch or query
			local moving = 0
			local rig = find(model, "Model", "Merchant")
			for _, d in rig and rig:GetDescendants() or {} do
				local still = not d:IsA("BasePart")
					or (d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery)
				if not still or d:IsA("Script") or d:IsA("Animator") or d:IsA("ProximityPrompt") then
					moving += 1
				end
			end
			flag("merchant_" .. stall .. "_static", at ~= nil and moving == 0, at and moving or "no MerchantSpot", 0)
		end
		local npc = area:FindFirstChild("CheckpointNpc")
		-- the Sensei merchant replaced SpawnArea's dummy (a guard since the switch is on, owner 2026-11-25). Offline SpawnArea
		-- builds no dummy rig, so offline this only sees the merchant standing; on a server it also sees the dummy gone.
		local dummy = npc ~= nil and npc:FindFirstChild("Rig") ~= nil
		flag(
			"merchant_sensei_replaces_the_dummy",
			npc ~= nil
				and not dummy
				and find(npc, "Attachment", "MerchantSpot") ~= nil
				and npc:FindFirstChild("Merchant") ~= nil,
			dummy and "the dummy still stands" or 1,
			"no dummy"
		)
	end, debug.traceback)
	WorldConfig.GATE_OPEN = oldOpen
	if Switch and GuideSwitch then
		Switch.LIVE, GuideSwitch.LIVE = gateWas, guideWas
	end
	record(scenario .. "_completed", ok, ok and 1 or tostring(err))
	if not pending then -- a pending name that no check carries would hide nothing and count for nothing
		local lost = {}
		for key in PENDING do
			if not seen[key] then
				table.insert(lost, key)
			end
		end
		record("pending_names_are_checks", #lost == 0, #lost == 0 and 1 or table.concat(lost, " "), 1)
	end
	return r
end

function Tests.plaza_build()
	return run("plaza_build", false)
end

function Tests.plaza_build_pending()
	return run("plaza_build_pending", true)
end

return Tests
