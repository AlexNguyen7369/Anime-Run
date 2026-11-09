--!nonstrict
-- What Client/BossPrepRun and Client/BossLineRun share (docs/BOSS_EVENT_SPEC.md "Preparation run and cutscene", "Line run"): the local
-- rigs of a team's characters behind its held runner, their smoke, and whether a player's line run has reached this client.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Follow = require(Shared:WaitForChild("SidekickFollow"))
local RunnerFactory = require(Shared:WaitForChild("RunnerFactory"))
local VehicleEffects = require(Shared:WaitForChild("VehicleEffects"))
local RunnerVisual = require(script.Parent:WaitForChild("RunnerVisual"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local SERVER_TAG = "RunnerRig" -- Server/CarService.RUNNER_TAG
-- Placeholders.
local PUFFS, PUFFS_SMALL, PUFFS_REDUCED = 7, 4, 3
local PUFF_SECONDS = 0.7
local SMALL_SCALE = 0.5

local BossTeamRig = {}

BossTeamRig.TEAM_GAP = 12 -- placeholder: studs between runners in line

BossTeamRig.Holder = Instance.new("Folder")
BossTeamRig.Holder.Name = "BossTeamRigs"
BossTeamRig.Holder.Parent = workspace

-- A rig's Owner: no real player has it, so it gets a Sidekick of its own and nothing takes it for the player's runner.
function BossTeamRig.Owner(userId, slot)
	return -(userId * 10 + slot)
end

function BossTeamRig.HeldCopy(who)
	for _, model in CollectionService:GetTagged(RunnerVisual.TAG) do
		if model:GetAttribute("Owner") == who.UserId then
			return model
		end
	end
	return nil
end

-- A rig for a place behind the first: a VisibleRunner, so it gets its Sidekick.
function BossTeamRig.New(who, slot, id)
	local rig = RunnerFactory.build(id)
	rig.Name = "TeamRunner"
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	rig:SetAttribute("Owner", BossTeamRig.Owner(who.UserId, slot))
	rig:SetAttribute(
		"FollowerFixtureId",
		Follow.WornId(who:GetAttribute("SidekickGear"), who:GetAttribute("SidekickBag"), id)
	)
	VehicleEffects.Apply(rig, who, slot)
	VehicleEffects.Boost(rig, VehicleEffects.EVENT_BOOST)
	rig.Parent = BossTeamRig.Holder
	CollectionService:AddTag(rig, RunnerVisual.TAG)
	return rig
end

function BossTeamRig.Smoke(position, small)
	local scale = small and SMALL_SCALE or 1
	for i = 1, UiMotion.Reduced() and PUFFS_REDUCED or small and PUFFS_SMALL or PUFFS do
		local puff = Instance.new("Part")
		puff.Shape = Enum.PartType.Ball
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = Color3.fromRGB(240, 240, 240)
		puff.Anchored = true
		puff.CanCollide = false
		puff.CanQuery = false
		puff.CanTouch = false
		puff.CastShadow = false
		puff.Size = Vector3.one * 3 * scale
		puff.Position = position + Vector3.new(math.random(-3, 3), math.random(0, 4), math.random(-3, 3)) * scale
		puff.Parent = BossTeamRig.Holder
		local info = TweenInfo.new(PUFF_SECONDS * (0.7 + i * 0.06), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(puff, info, {
			Size = Vector3.one * math.random(9, 13) * scale,
			Transparency = 1,
			Position = puff.Position + Vector3.new(0, 4, 0) * scale,
		}):Play()
		task.delay(info.Time, function()
			puff:Destroy()
		end)
	end
end

-- The player's line run as this client has it: the server rig and its route, or nil until all of it has replicated. Both scripts ask
-- this, so the prep rigs go in the frame the line's come.
function BossTeamRig.RunOf(who)
	if who:GetAttribute("BossEvent") ~= true or type(who:GetAttribute("BossLine")) ~= "string" then
		return nil
	end
	for _, rig in CollectionService:GetTagged(SERVER_TAG) do
		if rig:GetAttribute("Owner") == who.UserId then
			local route = RunnerVisual.RouteOf(rig:GetAttribute("RunRoute"))
			if
				route
				and type(rig:GetAttribute("RunDistance")) == "number"
				and type(rig:GetAttribute("RunSpeed")) == "number"
			then
				return rig, route
			end
			return nil
		end
	end
	return nil
end

return BossTeamRig
