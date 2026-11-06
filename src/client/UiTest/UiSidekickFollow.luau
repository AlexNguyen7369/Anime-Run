--!nonstrict
-- Sidekick followers (design doc 4.36; docs/SIDEKICK_SPEC.md "Display"; task b7d). Owned by ui-test-writer. Follow motion only:
-- attacks wait for the owner's key frames. Fixtures: UiTestSetup sidekick_follow_*, a rig of this player's drawn by the real
-- Client/RunnerView, so nobody really runs. Shared/SidekickFollow's own contract: Server/CarTest/SidekickFollowTests.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   A follower Model carries attribute SidekickId, and holds a clone of ReplicatedStorage.SidekickModels/<id>'s parts, scaled:
--   every part keeps its name, and the part sizes scale with the model.
--   A runner counts as hidden when its Torso's LocalTransparencyModifier or Transparency is 1. A hidden follower is
--   gone, or has every part at 1.
--   Fake players: a VisibleRunner with attribute FollowerFixtureId (tests only: no Player owns it, as a solo Studio run has no
--   other player) wears that Sidekick. Any other runner reads its Owner's SidekickGear and SidekickBag with SidekickFollow.WornId.
--   The drawn count stays at or under SidekickFollow.MaxFollowers, and the local player's own follower is always among them.
--   On foot there is no VisibleRunner, so no follower (design doc 4.36 "follows that character"; the avatar on foot is not one).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local Config = require(Shared:WaitForChild("SidekickConfig"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))

local WAIT = 5 -- s: a follower may need a frame or a model load
local MODELS_WAIT = 30 -- s
local SIZE_MIN, SIZE_MAX = 1.7, 2.3
local SIZE_MATCH = 0.15 -- studs from SidekickFollow.Size
local SPREAD_LIMIT = 1.6 -- world height over the scaled height: a pose that ignores the scale tears the model far past this
local RAGA_SCALE_MIN, RAGA_SCALE_MAX = 0.184, 0.249 -- docs/char_evidence/side_raga.md
local NEAR = 8 -- studs from the runner, sideways
local GROUND_SINK, GROUND_LIFT = 0.3, 0.5 -- studs around the runner's feet
local BESIDE_SLACK = 0.3 -- studs a walker's box may overlap the runner's middle
local SHOULDER_SLACK = 1.3 -- studs: the box centre moves with the wings
local FLY_OVER_WALK = 0.8 -- studs
local BOB_MIN, BOB_MAX = 0.03, 1 -- studs, whole range
local FLAP_MIN = 5 -- degrees
local WATCH = 1.6 -- s: longer than one bob or flap
local GAP_SLACK = 0.3 -- fraction of the two dogs' scaled gap
local RUN_SPEED = 120 -- studs/s
local CROWD_MANY = 8
local FAR = 1e6 -- studs: reported when there is nothing to measure, as an inf would break the JSON report
local FAKE_ID = -1001 -- UiTestSetup's first crowd runner
local FLYERS = { "side_crow", "side_reaper", "side_wyvern" } -- the flying models with wing parts
local BUDGET = 90 -- s: the whole scenario

local Module = {}

function Module.Build(h)
	local scenarios = {}
	local check = function(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local inRange = function(res, name, got, low, high)
		h.check(res, name, got, ("%s..%s"):format(tostring(low), tostring(high)), got >= low and got <= high)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function waitUntil(fn, seconds)
		local deadline = os.clock() + (seconds or WAIT)
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value or nil
	end

	local function folder()
		return workspace:FindFirstChild("SidekickFollowers")
	end
	local function followerOf(userId)
		local holder = folder()
		return holder and holder:FindFirstChild("Follower_" .. tostring(userId))
	end
	local function mine()
		return followerOf(h.player.UserId)
	end
	local function followerCount()
		local holder = folder()
		return holder and #holder:GetChildren() or 0
	end
	-- This player's drawn runner. RunnerView rebuilds it on a re-skin.
	local function runner()
		for _, model in CollectionService:GetTagged("VisibleRunner") do
			if model:GetAttribute("Owner") == h.player.UserId and model:FindFirstChild("Torso") then
				return model
			end
		end
		return nil
	end
	local function partsOf(model)
		local parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		return parts
	end
	-- World box from the parts. A model's own box turns with its pivot, and a flap would change it.
	local function boxOfParts(parts)
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, part in parts do
			local cf, half = part.CFrame, part.Size / 2
			local reach = Vector3.new(
				math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
				math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
				math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
			)
			low = low:Min(cf.Position - reach)
			high = high:Max(cf.Position + reach)
		end
		return low, high
	end
	local function boxOf(model)
		return boxOfParts(partsOf(model))
	end
	local function sourceOf(id)
		local models = ReplicatedStorage:FindFirstChild("SidekickModels")
		return models and models:FindFirstChild(id)
	end
	-- The follower's scale, from its largest part against the same part of the source. Not moved by any pose.
	local function scaleOf(follower, source)
		local largest = nil
		for _, part in partsOf(source) do
			if not largest or part.Size.Magnitude > largest.Size.Magnitude then
				largest = part
			end
		end
		local twin = largest and follower:FindFirstChild(largest.Name, true)
		return twin and twin:IsA("BasePart") and twin.Size.Magnitude / largest.Size.Magnitude or 0
	end
	local function hiddenFollower(follower)
		if not follower then
			return true
		end
		for _, part in partsOf(follower) do
			if part.Transparency < 1 and part.LocalTransparencyModifier < 1 then
				return false
			end
		end
		return true
	end

	-- The follower wearing `id`, once it is there.
	local function waitWearing(id)
		return waitUntil(function()
			local follower = mine()
			return follower and follower:GetAttribute("SidekickId") == id and #partsOf(follower) > 0 and follower
		end)
	end
	local function wear(res, characterId, id)
		setup(res, ("sidekick_follow_wear:%s:%s"):format(characterId, id))
	end

	local function checkBuilt(res, tag, follower, id)
		local source = sourceOf(id)
		check(res, tag .. "_class", follower.ClassName, "Model")
		check(res, tag .. "_source_present", source ~= nil, true)
		if not source then
			return
		end
		local parts = partsOf(follower)
		check(res, tag .. "_parts_kept", #parts, #partsOf(source))
		local solid = 0
		for _, part in parts do
			if part.CanCollide or part.CanQuery or part.CanTouch then
				solid += 1
			end
		end
		check(res, tag .. "_parts_not_collide_query_touch", solid, 0)
		local sourceLow, sourceHigh = boxOf(source)
		local native = sourceHigh.Y - sourceLow.Y
		local height = native * scaleOf(follower, source)
		inRange(res, tag .. "_height", height, SIZE_MIN, SIZE_MAX)
		local low, high = boxOf(follower)
		inRange(res, tag .. "_not_torn_apart", high.Y - low.Y, 0, height * SPREAD_LIMIT)
		return height, native
	end

	local function offsetFromRunner(follower)
		local copy = runner()
		local low, high = boxOf(follower)
		return copy.Torso.CFrame:PointToObjectSpace((low + high) / 2),
			low,
			high,
			copy.Torso.Position.Y - RunnerFactory.HIP_HEIGHT
	end

	local function checkPlaced(res, tag, Follow, follower, row)
		local offset, low, high, feet = offsetFromRunner(follower)
		inRange(res, tag .. "_near_runner", Vector3.new(offset.X, 0, offset.Z).Magnitude, 0, NEAR)
		if row.Movement == "Walk" then
			inRange(res, tag .. "_on_ground", low.Y - feet, -GROUND_SINK, GROUND_LIFT)
			inRange(res, tag .. "_beside", math.abs(offset.X) - (high.X - low.X) / 2, -BESIDE_SLACK, NEAR)
		else
			local shoulder = Follow.Offset(row, 0).Y
			inRange(
				res,
				tag .. "_at_shoulder",
				(low.Y + high.Y) / 2 - feet,
				shoulder - SHOULDER_SLACK,
				shoulder + SHOULDER_SLACK
			)
		end
	end

	local function checkEveryId(res, Follow, character)
		for _, list in { Config.List, Config.BossDrops } do
			for _, row in list do
				local tag = "worn_" .. row.Id
				wear(res, character, row.Id)
				local follower = waitWearing(row.Id)
				check(res, tag .. "_present", follower ~= nil, true)
				if follower then
					local height, native = checkBuilt(res, tag, follower, row.Id)
					if height then
						inRange(res, tag .. "_matches_size", math.abs(height - Follow.Size(row.Id)), 0, SIZE_MATCH)
						if row.Id == "side_raga" then
							inRange(res, "raga_scale", height / native, RAGA_SCALE_MIN, RAGA_SCALE_MAX)
						end
					end
					checkPlaced(res, tag, Follow, follower, row)
				end
			end
		end
	end

	local function dogGroups(follower)
		local white, black = {}, {}
		for _, part in partsOf(follower) do
			if string.sub(part.Name, 1, 5) == "White" then
				table.insert(white, part)
			elseif string.sub(part.Name, 1, 5) == "Black" then
				table.insert(black, part)
			end
		end
		return white, black
	end
	local function centreOf(parts)
		local low, high = boxOfParts(parts)
		return (low + high) / 2
	end

	local function checkDogs(res, character)
		wear(res, character, "side_dogs")
		local follower = waitWearing("side_dogs")
		local source = sourceOf("side_dogs")
		check(res, "dogs_present", follower ~= nil and source ~= nil, true)
		if not (follower and source) then
			return
		end
		task.wait(0.5) -- the bodies have moved a little
		local white, black = dogGroups(follower)
		local sourceWhite, sourceBlack = dogGroups(source)
		check(res, "dogs_source_has_both", #sourceWhite > 0 and #sourceBlack > 0, true)
		check(res, "dogs_white_parts", #white, #sourceWhite)
		check(res, "dogs_black_parts", #black, #sourceBlack)
		if #white == 0 or #black == 0 or #sourceWhite == 0 or #sourceBlack == 0 then
			return
		end
		local flat = Vector3.new(1, 0, 1)
		local gap = ((centreOf(white) - centreOf(black)) * flat).Magnitude
		local want = ((centreOf(sourceWhite) - centreOf(sourceBlack)) * flat).Magnitude * scaleOf(follower, source)
		inRange(res, "dogs_stay_apart", gap, want * (1 - GAP_SLACK), want * (1 + GAP_SLACK))
		local feet = runner().Torso.Position.Y - RunnerFactory.HIP_HEIGHT
		for _, dog in { white, black } do
			local low = boxOfParts(dog)
			inRange(
				res,
				("dogs_%s_on_ground"):format(dog == white and "white" or "black"),
				low.Y - feet,
				-GROUND_SINK,
				GROUND_LIFT
			)
		end
	end

	-- Watches one wing against the body it hangs from, and that body's height.
	local function watchFlight(follower)
		local wing = follower:FindFirstChild("WingLeft", true)
		local body = follower:FindFirstChild("Body", true) or follower:FindFirstChild("Torso", true)
		if not (wing and body) then
			return nil
		end
		local first = body.CFrame:ToObjectSpace(wing.CFrame).Rotation
		local turned, lowest, highest = 0, math.huge, -math.huge
		local deadline = os.clock() + WATCH
		while os.clock() < deadline do
			task.wait()
			local now = body.CFrame:ToObjectSpace(wing.CFrame).Rotation
			local _, angle = (first:Inverse() * now):ToAxisAngle()
			turned = math.max(turned, math.deg(angle))
			lowest, highest = math.min(lowest, body.Position.Y), math.max(highest, body.Position.Y)
		end
		return turned, highest - lowest
	end

	local function centreY(follower)
		local low, high = boxOf(follower)
		return (low.Y + high.Y) / 2
	end

	local function checkFlyers(res, character)
		wear(res, character, "side_chain")
		local walker = waitWearing("side_chain")
		local walkCentre = walker and centreY(walker)
		for _, id in FLYERS do
			wear(res, character, id)
			local follower = waitWearing(id)
			check(res, "fly_present_" .. id, follower ~= nil, true)
			if follower then
				if walkCentre then
					inRange(res, "fly_above_walk_" .. id, centreY(follower) - walkCentre, FLY_OVER_WALK, FAR)
				end
				local turned, bob = watchFlight(follower)
				check(res, "fly_has_wing_parts_" .. id, turned ~= nil, true)
				if turned then
					inRange(res, "fly_flap_loops_" .. id, turned, FLAP_MIN, 180)
					inRange(res, "fly_bob_" .. id, bob, BOB_MIN, BOB_MAX)
				end
			end
		end
	end

	-- The running character changes: the follower is that character's Sidekick, on the rebuilt runner, and only one.
	local function checkSwap(res, Follow, team)
		wear(res, team[1], "side_chain")
		wear(res, team[2], "side_wyvern")
		wear(res, team[3], "side_dogs")
		wear(res, team[4], "none")
		for _, step in { { 2, "side_wyvern" }, { 3, "side_dogs" }, { 1, "side_chain" } } do
			setup(res, "sidekick_follow_swap:" .. team[step[1]])
			local tag = "swap_to_" .. step[2]
			local follower = waitWearing(step[2])
			check(res, tag, follower ~= nil, true)
			check(res, tag .. "_one_follower", followerCount(), 1)
			if follower then
				waitUntil(function()
					return runner() and runner():GetAttribute("CharacterId") == team[step[1]]
				end)
				checkPlaced(res, tag, Follow, follower, Config.Get(step[2]))
			end
		end
		setup(res, "sidekick_follow_swap:" .. team[4])
		check(res, "swap_to_character_wearing_none_gone", waitUntil(function()
			return mine() == nil
		end) == true, true)
		setup(res, "sidekick_follow_swap:" .. team[1])
		check(res, "swap_back", waitWearing("side_chain") ~= nil, true)
		wear(res, team[1], "none")
		check(res, "taken_off_while_running_gone", waitUntil(function()
			return mine() == nil
		end) == true, true)
		wear(res, team[1], "side_chain")
		waitWearing("side_chain")
	end

	local function sideways(follower)
		local copy = runner()
		if not (copy and follower and follower.Parent) then
			return FAR
		end
		local low, high = boxOf(follower)
		return (((low + high) / 2 - copy.Torso.Position) * Vector3.new(1, 0, 1)).Magnitude
	end

	local function checkAttached(res)
		local follower = mine()
		if not follower then
			check(res, "attached_follower_present", false, true)
			return
		end
		setup(res, "sidekick_follow_run:" .. RUN_SPEED)
		task.wait(0.5)
		local worst = 0
		local deadline = os.clock() + WATCH
		while os.clock() < deadline do
			task.wait()
			worst = math.max(worst, sideways(mine()))
		end
		inRange(res, "attached_while_running", worst, 0, NEAR)
		setup(res, "sidekick_follow_stop")
		task.wait(0.2)
		inRange(res, "attached_after_stop", sideways(mine()), 0, NEAR)
	end

	local function checkHidden(res)
		local copy = runner()
		if not copy then
			check(res, "hidden_runner_present", false, true)
			return
		end
		for _, part in partsOf(copy) do
			part.LocalTransparencyModifier = 1
		end
		check(res, "hidden_with_runner", waitUntil(function()
			return hiddenFollower(mine())
		end) == true, true)
		for _, part in partsOf(copy) do
			part.LocalTransparencyModifier = 0
		end
		check(res, "shown_with_runner", waitUntil(function()
			return not hiddenFollower(mine())
		end) == true, true)
	end

	local function checkOthers(res, Follow)
		setup(res, "sidekick_follow_crowd:3")
		local fake = waitUntil(function()
			return followerOf(FAKE_ID)
		end)
		check(res, "others_followers_seen", fake ~= nil, true)
		check(res, "others_right_sidekick", fake and fake:GetAttribute("SidekickId") or "none", "side_chain")
		check(res, "others_count", waitUntil(function()
			return followerCount() == 4
		end) == true, true)
		setup(res, "sidekick_follow_crowd:" .. CROWD_MANY)
		waitUntil(function()
			return followerCount() >= Follow.MaxFollowers
		end)
		task.wait(1) -- a client over budget would keep adding
		check(res, "budget_count", followerCount(), Follow.MaxFollowers)
		check(res, "budget_keeps_own", mine() ~= nil, true)
		setup(res, "sidekick_follow_crowd:0")
		check(res, "others_gone_on_leave", waitUntil(function()
			return followerCount() == 1 and followerOf(FAKE_ID) == nil
		end) == true, true)
	end

	function scenarios.ui_sidekick_follow(res)
		local started = os.clock()
		local module = Shared:FindFirstChild("SidekickFollow")
		local view = script.Parent.Parent:FindFirstChild("SidekickFollower")
		check(res, "follow_module_present", module ~= nil, true)
		check(res, "follower_viewpresent", view ~= nil, true)
		if not (module and view) then
			return
		end
		local Follow = require(module)
		local models = ReplicatedStorage:WaitForChild("SidekickModels", MODELS_WAIT)
		check(res, "models_ready", waitUntil(function()
			return models and models:GetAttribute("Ready") == true
		end, MODELS_WAIT) == true, true)
		local team = {}
		for i = 1, 4 do
			team[i] = Catalog.Rollable()[i].Id
		end
		local ok, err = xpcall(function()
			setup(res, "sidekick_follow_start")
			check(res, "fixture_runner_drawn", waitUntil(function()
				return runner() ~= nil
			end) == true, true)
			if not runner() then
				return
			end
			task.wait(0.3)
			check(res, "none_worn_no_follower", mine() == nil, true)
			check(res, "none_worn_no_followers_at_all", followerCount(), 0)
			checkEveryId(res, Follow, team[1])
			check(res, "follower_folder", folder() and folder().ClassName or "missing", "Folder")
			check(res, "worn_one_follower", followerCount(), 1)
			checkDogs(res, team[1])
			checkFlyers(res, team[1])
			checkSwap(res, Follow, team)
			checkAttached(res)
			checkHidden(res)
			checkOthers(res, Follow)
			setup(res, "sidekick_follow_end")
			check(res, "gone_at_end_of_run", waitUntil(function()
				return followerCount() == 0
			end) == true, true)
		end, debug.traceback)
		h.check(res, "follow_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		setup(res, "restore:sidekick_follow")
		check(res, "gone_after_restore", waitUntil(function()
			return followerOf(h.player.UserId) == nil
		end) == true, true)
		local spent = os.clock() - started
		h.check(res, "follow_scenario_time", spent, "< " .. BUDGET, spent < BUDGET)
	end

	return { Scenarios = scenarios }
end

return Module
