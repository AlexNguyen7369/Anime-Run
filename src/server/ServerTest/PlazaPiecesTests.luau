--!nonstrict
-- BRIEF: WORLD_REDESIGN_SPEC 4.2, the spawn pieces' code before and after their upload (Shared/PlazaPieces, Shared/PlazaPieceAssets,
-- Server/PlazaDressing, Shared/SpawnArea). off_*: with every Asset 0 the plaza is today's: the dressing plan is PlazaAssets'
-- own, no new stand-in, look, touch part, tag or merchant. on_*: with ids filled in (made up, put back after) each piece stands once,
-- by world and state, the old mesh and sign of its place go, and the stand-in is hidden only by a loaded mesh.
-- Not covered: loading, how anything looks, walking against the collision parts, the client scripts' wiring.
-- Offline: lune run tools/lune/server_scenarios <1|2> PlazaPiecesTests.plaza_pieces
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local KEYS = {
	"WorldGateLocked",
	"WorldGateOpen",
	"BossGateClosed",
	"BossGateOpen",
	"AltarGreatLotusLocked",
	"AltarGreatLotusUnlocked",
	"AltarTwinRoofLocked",
	"AltarTwinRoofUnlocked",
	"SHOPStall",
	"POTIONSStall",
	"MarketStall",
	"IndexBoard",
	"SenseiDais",
	"SkyLoop",
}

-- The merchants' poses: where a limb's end stands in the approved draft (tools/blender/plaza/draft_merchants.py turn() on (0, 0, -1), in the built
-- rig's studs from its feet), as (-x, z, y): right, up, back of the rig
local LIMB_ENDS = {
	ShopStall = {
		RightArm = Vector3.new(1.895, 2.889, -1.588),
		LeftArm = Vector3.new(-1.602, 2.852, -1.625),
	},
	PotionsStall = {
		RightArm = Vector3.new(1.439, 2.883, -1.658),
		LeftArm = Vector3.new(-1.439, 2.883, -1.658),
	},
	Marketplace = {
		RightArm = Vector3.new(1.718, 2.892, -1.635),
		LeftArm = Vector3.new(-1.718, 2.892, -1.635),
	},
	IndexBoard = {
		LeftArm = Vector3.new(-1.472, 2.973, -1.715),
		RightArm = Vector3.new(1.538, 2.024, -0.278),
	},
	CheckpointNpc = {
		RightArm = Vector3.new(2.004, 5.659, -0.939),
		LeftArm = Vector3.new(-1.935, 2.135, 0.484),
		RightLeg = Vector3.new(0.709, 0.011, 0),
		LeftLeg = Vector3.new(-0.709, 0.011, 0),
	},
}

local function find(root, class, name)
	for _, d in root and root:GetDescendants() or {} do
		if d:IsA(class) and (name == nil or d.Name == name) then
			return d
		end
	end
	return nil
end

local function count(list, key)
	local n, row = 0, nil
	for _, r in list do
		if r.Key == key then
			n, row = n + 1, r
		end
	end
	return n, row
end

function Tests.plaza_pieces()
	local r, flag = H.report("plaza_pieces")
	local Pieces = H.module(Shared, "PlazaPieces")
	flag("module", Pieces ~= nil)
	if not Pieces then
		return r
	end
	local Layout, SpawnArea = require(Shared.PlazaAssets), require(Shared.SpawnArea)
	local WorldConfig, Boss = require(Shared.WorldConfig), require(Shared.BossGateConfig)
	local oldWorld, oldOpen, oldLive = WorldConfig.Id, WorldConfig.GATE_OPEN, Boss.LIVE
	local oldMerchants = Pieces.MERCHANTS_LIVE
	local ids = {}
	for key, row in Pieces.Assets do
		ids[key] = row.Asset
	end
	local function fill(n)
		for _, row in Pieces.Assets do
			row.Asset = n
		end
	end
	local function restore()
		for key, row in Pieces.Assets do
			row.Asset = ids[key]
		end
		WorldConfig.Id, WorldConfig.GATE_OPEN, Boss.LIVE = oldWorld, oldOpen, oldLive
		Pieces.MERCHANTS_LIVE = oldMerchants
	end
	local ok, err = xpcall(function()
		for _, key in KEYS do
			local row = Pieces.Assets[key]
			flag("row_" .. key, row ~= nil and type(row.Asset) == "number" and next(row.Parts) ~= nil)
		end
		-- owner 2026-11-25: 17.5 on the lotus, 25 on the roof stage, Kakashe the smaller one; today's altar keeps 7
		for world, size in { 17.5, 25 } do
			WorldConfig.Id = world
			fill(0)
			flag("altar_model_size_before_w" .. world, Pieces.AltarModelSize() == 7, Pieces.AltarModelSize(), 7)
			fill(1)
			flag("altar_model_size_w" .. world, Pieces.AltarModelSize() == size, Pieces.AltarModelSize(), size)
		end
		for name, row in H.module(Shared, "PlazaMerchants") do
			local want = name == "CheckpointNpc" and 0.75 or 1
			flag("merchant_scale_" .. name, row.Scale == want, row.Scale or -1, want)
		end
		-- the locked Mythic is not near-black any more; today's altar keeps its look. Whether it reads against what is behind it:
		-- plaza_build_pending, altar_locked_reads
		for world = 1, 2 do
			WorldConfig.Id = world
			fill(0)
			local old = Pieces.LockedLook and Pieces.LockedLook()
			flag(
				"locked_look_before_w" .. world,
				old ~= nil and old.Color == Color3.fromRGB(24, 22, 30) and old.Transparency == 0.25
			)
			fill(1)
			local new = Pieces.LockedLook and Pieces.LockedLook()
			local dark = new and H.contrast(Color3.fromRGB(24, 22, 30), new.Color) or 0
			flag("locked_look_not_near_black_w" .. world, dark >= 1.5, dark, 1.5)
		end
		WorldConfig.Id = oldWorld
		local posts = Pieces.Assets.SkyLoop.Posts -- measured on the mesh (build_loop.py), written with the table
		local degrees = posts and table.concat(posts, " ") or "missing"
		flag("sky_loop_posts", degrees == "19 75 200 250 322", degrees, "19 75 200 250 322")
		-- the uploads carry Blender's number on repeated names (seen in Studio 2026-11-25: "Body.001", "Glow_g_cyan.003")
		flag(
			"part_name_number",
			Pieces.PartName("Body.001") == "Body" and Pieces.PartName("Glow_g_cyan.003") == "Glow_g_cyan"
		)
		flag("part_name_plain", Pieces.PartName("Body") == "Body" and Pieces.PartName("Glow_e1") == "Glow_e1")
		flag(
			"part_missing_not_complete",
			Pieces.Complete({ Parts = { Body = 1, Glow_a = 1 } }, { Glow_a = {} }) == false
		)
		flag("parts_all_complete", Pieces.Complete({ Parts = { Body = 1 } }, { Body = {} }))
		flag("merchants_off_by_default", oldMerchants == false)

		for _, world in { 1, 2 } do
			WorldConfig.Id = world
			local w = "w" .. world .. "_"

			-- Nothing uploaded: today's plaza
			fill(0)
			Boss.LIVE = false
			local off = Pieces.Plan(Layout, false)
			local same = #off.Placed == #Layout.Placed and #off.Signs == #Layout.Signs
			for i, row in Layout.Placed do
				local got = off.Placed[i]
				same = same and got.Key == row.Key and got.Pos == row.Pos and got.Face == row.Face and got.Tag == nil
			end
			for i, row in Layout.Signs do
				same = same and off.Signs[i].Text == row.Text and off.Signs[i].Pos == row.Pos
			end
			for key, row in Layout.Assets do
				same = same and off.Assets[key] == row
			end
			for key in off.Assets do
				same = same and Layout.Assets[key] ~= nil
			end
			flag(w .. "off_plan_is_todays", same)
			local area = SpawnArea.Build(CFrame.new())
			local altar, gate = area:FindFirstChild("SidekickAltar"), area:FindFirstChild("WorldGate")
			flag(w .. "off_no_look", altar:GetAttribute("Look") == nil)
			flag(w .. "off_no_lock_spot", find(altar, "Attachment", "LockSpot") == nil)
			flag(
				w .. "off_gate_is_the_ring",
				gate.Portal.Shape == Enum.PartType.Cylinder and find(gate, "Part", "Ring") ~= nil
			)
			flag(w .. "off_no_merchant", find(area, "Model", "Merchant") == nil)
			-- A gate off and ids there: still no boss gate
			fill(1)
			local silent = Pieces.Plan(Layout, false)
			flag(
				w .. "on_boss_gate_off_not_planned",
				count(silent.Placed, "BossGateOpen") + count(silent.Placed, "BossGateClosed") == 0
			)
			flag(w .. "on_boss_gate_off_not_loaded", silent.Assets.BossGateOpen == nil)
			Boss.LIVE = true

			for _, locked in { true, false } do
				local plan = Pieces.Plan(Layout, locked)
				local key = w .. (locked and "locked_" or "open_")
				local lockedGate, openGate = count(plan.Placed, "WorldGateLocked"), count(plan.Placed, "WorldGateOpen")
				flag(key .. "one_world_gate", lockedGate == (locked and 1 or 0) and openGate == (locked and 0 or 1))
				local mine, theirs = "AltarGreatLotus", "AltarTwinRoof"
				if world == 2 then
					mine, theirs = theirs, mine
				end
				for _, state in { "Locked", "Unlocked" } do
					local n, row = count(plan.Placed, mine .. state)
					flag(key .. "altar_" .. state, n == 1 and row.Tag == Pieces.ALTAR_TAGS[state], n, 1)
					flag(
						key .. "no_other_altar_" .. state,
						count(plan.Placed, theirs .. state) == 0 and plan.Assets[theirs .. state] == nil
					)
				end
				for state, tag in { Closed = Boss.CLOSED_TAG, Open = Boss.OPEN_TAG } do
					local n, row = count(plan.Placed, "BossGate" .. state)
					flag(key .. "boss_" .. state, n == 1 and row.Tag == tag, n, 1)
				end
				for _, name in { "SHOPStall", "POTIONSStall", "MarketStall", "IndexBoard", "SenseiDais", "SkyLoop" } do
					local n = count(plan.Placed, name)
					flag(key .. "once_" .. name, n == 1 and plan.Assets[name] == Pieces.Assets[name], n, 1)
				end
				flag(
					key .. "no_old_market_sign",
					count(plan.Placed, "MarketSign") == 0 and plan.Assets.MarketSign == nil
				)
				flag(
					key .. "other_meshes_stay",
					count(plan.Placed, "HeroTorii") == 1 and count(plan.Placed, "Lantern") == 4
				)
				flag(key .. "signs_stay_five", #plan.Signs == #Layout.Signs)
				-- a stand-in is hidden only when all its meshes loaded; a half-loaded pair stands nowhere
				local half = { [mine .. "Locked"] = true, BossGateOpen = true }
				for _, row in plan.Placed do
					if row.Key == mine .. "Locked" or row.Key == "BossGateOpen" then
						flag(key .. "half_pair_not_placed_" .. row.Key, Pieces.Loaded(row.Needs, half) == false)
					end
				end
				flag(key .. "half_pair_keeps_altar", Pieces.Loaded(plan.Replaces.SidekickAltar, half) == false)
				flag(key .. "half_pair_keeps_boss_gate", Pieces.Loaded(plan.Replaces.BossGate, half) == false)
				for name, needs in plan.Replaces do
					flag(key .. "hides_by_mesh_" .. name, #needs > 0 and Pieces.Loaded(needs, {}) == false)
				end
			end
			flag(w .. "altar_shown_once", Pieces.ALTAR_TAGS.Locked ~= Pieces.ALTAR_TAGS.Unlocked)

			-- The stand-ins of the filled table
			local on = SpawnArea.Build(CFrame.new())
			local onAltar = on:FindFirstChild("SidekickAltar")
			flag(
				w .. "on_look",
				onAltar:GetAttribute("Look") == (world == 1 and "GreatLotus" or "TwinRoof"),
				tostring(onAltar:GetAttribute("Look"))
			)
			flag(w .. "on_lock_spot", find(onAltar, "Attachment", "LockSpot") ~= nil)
			local spot = find(onAltar, "Attachment", "ModelSpot")
			local stand = world == 1 and 10.3 or 8.55 -- what the draft's model stands on, studs over the floor
			local want = 1 + stand + (world == 1 and 17.5 or 25) / 2
			flag(
				w .. "on_model_stands",
				spot ~= nil and math.abs(spot.WorldCFrame.Position.Y - want) < 0.05,
				spot and spot.WorldCFrame.Position.Y,
				want
			)
			flag(w .. "on_altar_prompt", find(onAltar, "ProximityPrompt", "OpenSidekicks") ~= nil)
			local widest, tiers = 0, 0
			for _, d in onAltar:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Tier" then
					tiers += d.CanCollide ~= false and 1 or 0
					widest = math.max(widest, d.Size.X, d.Size.Y, d.Size.Z)
				end
			end
			flag(w .. "on_altar_tiers_collide", tiers >= 3 and widest >= (world == 1 and 36.7 or 60), widest)
			flag(w .. "on_gate_not_the_ring", find(on.WorldGate, "Part", "Ring") == nil)
			for name, old in
				{ ShopStall = "Curtain", PotionsStall = "Curtain", Marketplace = "Curtain", IndexBoard = "Post" }
			do
				local model = on:FindFirstChild(name)
				flag(
					w .. "on_new_stand_in_" .. name,
					model:FindFirstChild("Deck") ~= nil and model:FindFirstChild(old) == nil
				)
			end
			for stall, prompt in
				{
					ShopStall = "OpenShop",
					PotionsStall = "OpenPotions",
					Marketplace = "OpenMarket",
					IndexBoard = "OpenIndex",
				}
			do
				local model = on:FindFirstChild(stall)
				flag(w .. "on_prompt_" .. stall, find(model, "ProximityPrompt", prompt) ~= nil)
				flag(w .. "on_marker_" .. stall, find(model, "Attachment", "MerchantSpot") ~= nil)
			end
			local pad = false
			for _, d in on.Marketplace:GetDescendants() do
				pad = pad or CollectionService:HasTag(d, "MarketPad")
			end
			flag(w .. "on_market_pad_tag", pad)

			-- Merchants: one switch, and only on stalls that are there
			local Merchants = H.module(script.Parent.Parent, "PlazaMerchantRigs")
			flag(w .. "merchant_service", Merchants ~= nil)
			if Merchants then
				Pieces.MERCHANTS_LIVE = false
				Merchants.Stand(on)
				flag(w .. "merchants_off_none", find(on, "Model", "Merchant") == nil)
				Pieces.MERCHANTS_LIVE = true
				fill(0)
				Merchants.Stand(on)
				flag(w .. "merchants_need_the_stalls", find(on, "Model", "Merchant") == nil)
				fill(1)
				Merchants.Stand(on)
				Merchants.Stand(on) -- twice: still one each
				local n, loose = 0, 0
				for _, m in on:GetDescendants() do
					if m:IsA("Model") and m.Name == "Merchant" then
						n += 1
						for _, d in m:GetDescendants() do
							if
								d:IsA("BasePart")
								and not (
									d.Anchored
									and d.CanCollide == false
									and d.CanTouch == false
									and d.CanQuery == false
								)
							then
								loose += 1
							end
							loose += (d:IsA("Script") or d:IsA("ProximityPrompt")) and 1 or 0
						end
					end
				end
				flag(w .. "merchants_on_five", n == 5, n, 5)
				flag(w .. "merchants_static", loose == 0, loose, 0)
				-- posed as the draft, standing at the marker, at the row's scale
				for name, row in H.module(Shared, "PlazaMerchants") do
					local service = on:FindFirstChild(name)
					local rig = service and service:FindFirstChild("Merchant")
					local marker = find(service, "Attachment", "MerchantSpot")
					if not (rig and marker) then
						flag(w .. "merchant_posed_" .. name, false)
						continue
					end
					flag(w .. "merchant_posed_" .. name, next(row.Pose or {}) ~= nil)
					local frame = marker.WorldCFrame * CFrame.Angles(0, math.rad(row.Yaw or 0), 0)
					for limb, at in LIMB_ENDS[name] or {} do
						local part = rig:FindFirstChild(limb)
						local tip = part.CFrame * Vector3.new(0, -row.Scale, 0) -- half of the built limb's 2 studs
						local away = (frame:PointToObjectSpace(tip) - at * row.Scale).Magnitude
						flag(w .. "merchant_" .. name .. "_" .. limb, away < 0.01, away, 0.01)
					end
					local label = rig:FindFirstChild("NameLabel")
					local hidden = label ~= nil and label.Enabled == false
					flag(w .. "merchant_label_" .. name, hidden == (name == "CheckpointNpc"))
				end
				flag(w .. "merchants_dummy_gone", on.CheckpointNpc:FindFirstChild("Rig") == nil)
				Pieces.MERCHANTS_LIVE = false
			end
		end

		-- The locked and unlocked altar, one shown
		local Look = H.module(Shared, "PlazaPieceLook")
		flag("look_module", Look ~= nil)
		if Look and not workspace:FindFirstChild("SpawnArea") then
			local made = {}
			for state, tag in Pieces.ALTAR_TAGS do
				for _, name in { "Body", "Glow_g_pink" } do
					local part = Instance.new("Part")
					part.Name = name
					CollectionService:AddTag(part, tag)
					part.Parent = workspace
					local light = Instance.new("PointLight")
					light.Range = 18
					light.Parent = part
					table.insert(made, { part, state, name, light })
				end
			end
			for _, locked in { true, false } do
				Look.Altar(locked)
				for _, m in made do
					local shown = (m[2] == "Locked") == locked
					flag(
						("look_%s_%s_%s"):format(locked and "locked" or "unlocked", m[2], m[3]),
						m[1].Transparency == (shown and 0 or 1) and m[1].CastShadow == (shown and m[3] == "Body")
					)
					-- by its range: REDUCED EFFECTS (Client/BiomeEnvironment) owns Enabled and Brightness
					local range = shown and 18 or 0
					flag(
						("look_%s_%s_%s_light"):format(locked and "locked" or "unlocked", m[2], m[3]),
						m[4].Range == range,
						m[4].Range,
						range
					)
				end
			end
			for _, m in made do
				m[1]:Destroy()
			end
		end
	end, debug.traceback)
	restore()
	flag("plaza_pieces_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
