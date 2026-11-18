--!nonstrict
-- Turns the runner rig on the spawn-area Best Roll pedestal (docs/LEADERBOARD_SPEC.md 3a), bobs it when marked Hover and
-- flaps parts named Wing_L / Wing_R. Display only: the server picks the character. The
-- motion is local, so nothing replicates per frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local area = Workspace:WaitForChild("SpawnArea")
local best = area:WaitForChild("BestRoll")

local LIFT = 1 -- studs above the platform (before MODEL_SCALE): the lowest point of the bob stays clear of it
local BOB = 0.4 -- studs
local FLAP = math.rad(25)
-- runner -> { [part] = { Rel, Side, Hinge } }: each part's place relative to the pedestal's CharacterMount, read once from the
-- server's placement. Model pivots are not used: on the client a Model's pivot may sit at its box centre instead of
-- its base, which put the runners into the platform. Not a weak table (a lost entry would be re-read mid-motion);
-- entries go when their runner leaves the world.
local states = {}

local function animate(runner, t)
	local pedestal = runner.Parent and runner.Parent:FindFirstChild("Pedestal")
	local mount = pedestal and pedestal:FindFirstChild("CharacterMount")
	if not mount then
		return
	end
	local parts = states[runner]
	if not parts then
		parts = {}
		states[runner] = parts
	end
	local bob = runner:GetAttribute("Hover") and (LIFT + math.sin(t * 2) * BOB) * Config.BEST_ROLL.MODEL_SCALE or 0
	local frame = mount.WorldCFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, math.rad(Config.BEST_ROLL.SPIN) * t, 0)
	local flap = FLAP * math.sin(t * 5)
	for _, part in runner:GetDescendants() do
		if part:IsA("BasePart") then
			local entry = parts[part]
			if not entry then -- first sight (parts may stream in late): still where the server put it
				entry = { Rel = mount.WorldCFrame:ToObjectSpace(part.CFrame) }
				entry.Side = (part.Name == "Wing_L" and -1) or (part.Name == "Wing_R" and 1) or nil
				entry.Hinge = entry.Side and part.PivotOffset
				parts[part] = entry
			end
			local cf = frame * entry.Rel
			if entry.Side then -- turn about the wing's inner edge (its pivot)
				cf = cf * entry.Hinge * CFrame.Angles(0, 0, entry.Side * flap) * entry.Hinge:Inverse()
			end
			part.CFrame = cf
		end
	end
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for runner in states do
		if not runner.Parent then
			states[runner] = nil
		end
	end
	local runner = best:FindFirstChild("Runner")
	if runner then
		animate(runner, t)
	end
end)
