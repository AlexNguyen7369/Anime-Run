local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local repo = assert(require("@lune/process").args[1], "absolute repository path required") .. "/"
local env = setmetatable({}, { __index = getfenv() })
for _, key in { "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "Enum" } do
	env[key] = rb[key]
end
local chunk = assert(loadstring(fs.readFile(repo .. "src/client/SummonHybrid.luau")))
setfenv(chunk, env)
local Hybrid = chunk()
local assets = rb.deserializeModel(fs.readFile(repo .. "assets/studio/SummonScreenAssets.rbxm"))[1]
local registered = assets:GetAttribute("HybridBackdropImage")
assets:SetAttribute("HybridBackdropImage", nil)
local original = assets.SummoningStage
local fallback = original:Clone()
assert(Hybrid.Attach(fallback, assets) == nil, "unregistered image must keep existing stage")
assert(fallback:FindFirstChild("Backdrop") and fallback:FindFirstChild("GalaxyVFX"))
-- Format-only local fixture; never uploaded or registered in the project.
assets:SetAttribute("HybridBackdropImage", registered or "rbxassetid://1")
local stage = original:Clone()
local roots = {}
for _, unit in stage.Units:GetChildren() do
	roots[unit] = unit.Root.CFrame
end
local h = assert(Hybrid.Attach(stage, assets))
assert(not stage:FindFirstChild("GalaxyVFX") and not stage:FindFirstChild("BackgroundStars"))
assert(not stage:FindFirstChild("Backdrop") and stage:FindFirstChild("BlossomHybrid"))
for unit, cf in roots do
	assert(unit.Root.CFrame == cf, "unit/aura placement changed")
end
local tests = 0
local maxPixelDrift = 0
local function project(cf, fov, view, p)
	local v = cf:PointToObjectSpace(p)
	local focal = view.Y / (2 * math.tan(math.rad(fov) / 2))
	return rb.Vector2.new(view.X / 2 + v.X * focal / -v.Z, view.Y / 2 - v.Y * focal / -v.Z)
end
local function floorPoints(cf, fov, view)
	local points = {}
	for _, entry in h.FixedFloorParts do
		local part = entry.Part
		points[part] = project(cf, fov, view, part.CFrame.Position)
	end
	points[h.Backdrop] = project(cf, fov, view, h.Backdrop.CFrame.Position)
	return points
end
for _, view in
	{ rb.Vector2.new(1808, 870), rb.Vector2.new(1920, 1080), rb.Vector2.new(844, 390), rb.Vector2.new(1366, 768) }
do
	local baselineCf, baselineFov = h:Frame(view, rb.Vector2.zero, 4.2, false)
	local baseline = floorPoints(baselineCf, baselineFov, view)
	for _, drift in { rb.Vector2.zero, rb.Vector2.new(-1, -1), rb.Vector2.new(1, 1) } do
		for _, reduced in { false, true } do
			local cf, fov = h:Frame(view, drift, 4.2, reduced)
			for part, pixel in floorPoints(cf, fov, view) do
				local delta = (pixel - baseline[part]).Magnitude
				maxPixelDrift = math.max(maxPixelDrift, delta)
				assert(delta < 0.02, "floor or backdrop moved on screen")
			end
			assert(fov > 10 and fov < 40, "invalid FOV")
			assert(cf.Position.Y > 9990 and cf.Position.Z < 0)
			for _, petal in h.Petals do
				assert(petal.Part.CFrame.Position.Z >= 4.5, "petal in character zone")
			end
			tests += 1
		end
	end
end
for _, p in h.Root:GetDescendants() do
	if p:IsA("BasePart") then
		assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch)
		assert(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, "degenerate foreground geometry")
		assert(p.CFrame.Position.Magnitude < math.huge, "invalid geometry transform")
	end
end
local cf1 = h:Frame(rb.Vector2.new(1808, 870), rb.Vector2.new(-1, -1), 2, true)
local cf2 = h:Frame(rb.Vector2.new(1808, 870), rb.Vector2.new(1, 1), 20, true)
assert(cf1 == cf2, "reduced motion should eliminate camera drift")
stage:Destroy()
assert(h.Root.Parent == nil, "local geometry did not clean up")
assert(original:FindFirstChild("GalaxyVFX"), "saved source asset changed")
print("Max floor/backdrop pixel drift", maxPixelDrift)
print(
	"PASS: native model build, galaxy fallback, unit preservation, local cleanup, reduced motion and",
	tests,
	"camera/petal frame cases"
)
