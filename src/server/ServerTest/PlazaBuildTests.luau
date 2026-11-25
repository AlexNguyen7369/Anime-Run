--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md 4.2 "Redrafted spawn pieces" (owner 2026-11-25, "approved all": spot S4 and the
-- fuller layout), written red before the build.
--   gate_*: the world gate as gate draft B (tools/blender/plaza/draft_gate.py concept_b). Place, facing, destination and
--     lock rule unchanged; a touch part that is no disc and fills B's doorway; the label over B's roof; a locked and an
--     open mesh in Shared/PlazaAssets, inside today's gate footprint.
--   boss_gate_*: draft A (draft_boss_gate.py) at S4 facing the spawn, whole on the floor, its own prompt, a closed and an
--     open mesh, and the guide with a prompt of its own. What the prompts do is client code (not covered here).
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
-- here: the meshes' looks, the client's altar display and locked label, header heights, loading of the merchants' models
-- (4.47 "every world shows" is open), collision by walking, the boss event states, views from the spawn.
-- Offline: lune run tools/lune/server_scenarios <1|2> PlazaBuildTests.plaza_build
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

function Tests.plaza_build()
	local r, flag = H.report("plaza_build")
	local WorldConfig, SpawnArea = require(Shared.WorldConfig), require(Shared.SpawnArea)
	local PlazaAssets, Catalog = require(Shared.PlazaAssets), require(Shared.CharacterCatalog)
	local world = WorldConfig.Id
	local function text(v)
		return v == nil and "missing" or tostring(v)
	end

	local oldOpen = WorldConfig.GATE_OPEN
	local ok, err = xpcall(function()
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
		local posts = PlazaAssets.LoopPosts
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
			local asset = PlazaAssets.Assets[key]
			flag("boss_gate_mesh_" .. key, asset ~= nil, asset and 1 or "no PlazaAssets.Assets." .. key, 1)
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
		-- The guide is its own model (Server/BossGuide, feature/alex/boss-guide): red until that branch merges
		local Guide = H.module(script.Parent.Parent, "BossGuide")
		local guide = Guide and Guide.Build(CFrame.new())
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
			local CollectionService = game:GetService("CollectionService")
			for _, d in boss and boss:GetDescendants() or {} do
				built.Closed += CollectionService:HasTag(d, GateConfig.CLOSED_TAG) and (d.Transparency or 0) == 0 and 1 or 0
				built.Open += CollectionService:HasTag(d, GateConfig.OPEN_TAG) and d.Transparency == 1 and 1 or 0
			end
			flag("boss_gate_built_closed", built.Closed > 0 and built.Open > 0)
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

		-- World gate B
		local function gate(open)
			WorldConfig.GATE_OPEN = open
			local m = SpawnArea.WorldGate(CFrame.new())
			WorldConfig.GATE_OPEN = oldOpen
			return m
		end
		for _, state in { { "locked", false }, { "open", true } } do
			local name, m = state[1], gate(state[2])
			local locked = world == 1 and not state[2] -- World 2's gate leads back and is always open
			local portal = m:FindFirstChild("Portal")
			local key = "gate_" .. name
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
			flag(key .. "_touch_not_a_disc", portal.Shape ~= Enum.PartType.Cylinder, text(portal.Shape), "no Cylinder")
			flag(
				key .. "_touch_fits_doorway",
				x <= GATE.DoorWidth + TOL and top <= GATE.DoorTop + TOL,
				x,
				GATE.DoorWidth
			)
			flag(key .. "_touch_fills_doorway", x >= GATE.DoorMinWidth, x, GATE.DoorMinWidth)
			flag(
				key .. "_touch_at_runner_height",
				bottom <= GATE.SillMax and top >= GATE.ChestMin,
				bottom,
				GATE.SillMax
			)
			local label = find(m, "BillboardGui", "Label")
			local offset = label and (label.StudsOffsetWorldSpace or Vector3.zero).Y or 0
			local height = portal.CFrame.Position.Y - FLOOR + offset
			flag(key .. "_label_over_roof", label ~= nil and height >= GATE.RoofTop, height, GATE.RoofTop)
			local state2 = find(label, "TextLabel", "State")
			local want = locked and "COMING SOON" or "ENTER"
			flag(key .. "_label_text", state2 ~= nil and state2.Text == want, text(state2 and state2.Text), want)
		end
		for _, key in { "WorldGateLocked", "WorldGateOpen" } do
			local asset = PlazaAssets.Assets[key]
			flag("gate_mesh_" .. key, asset ~= nil, asset and 1 or "no PlazaAssets.Assets." .. key, 1)
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
		local look = altar and altar:GetAttribute("Look")
		local wantLook = world == 1 and "GreatLotus" or "TwinRoof"
		flag("altar_look_of_this_world", look == wantLook, text(look), wantLook)
		for _, state in { "Locked", "Unlocked" } do
			local key = "Altar" .. wantLook .. state
			flag(
				"altar_mesh_" .. state,
				PlazaAssets.Assets[key] ~= nil,
				PlazaAssets.Assets[key] and 1 or "no PlazaAssets.Assets." .. key,
				1
			)
		end
		local spot = find(altar, "Attachment", "ModelSpot")
		flag("altar_model_spot", spot ~= nil)
		if spot then
			local off = (flat(spot.WorldCFrame.Position) - Vector2.new(175.158, -18.445)).Magnitude
			flag("altar_model_spot_centred", off <= 1, off, 1) -- draft A's spot is 0.8 ahead of the centre
		end

		-- Merchants
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
		flag(
			"merchant_sensei_replaces_the_dummy",
			npc ~= nil and npc:FindFirstChild("Rig") == nil and find(npc, "Attachment", "MerchantSpot") ~= nil
		)
	end, debug.traceback)
	WorldConfig.GATE_OPEN = oldOpen
	flag("plaza_build_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
