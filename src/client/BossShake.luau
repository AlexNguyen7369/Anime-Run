--!nonstrict
-- Camera shake for big effects (roblox-vfx vfx-camera-world): rotation only, and each frame's offset is taken back off before the
-- camera scripts run, so that it never builds up in the view. Touches no camera code. Off while effects are reduced.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local UNDO, APPLY = "BossShakeUndo", "BossShakeApply"
-- Outside RunnerView's Camera - 1 and TunnelCamera's Camera + 1
local UNDO_PRIORITY, APPLY_PRIORITY = Enum.RenderPriority.Camera.Value - 2, Enum.RenderPriority.Camera.Value + 2

local BossShake = {}

local kicks = {} -- { Magnitude, Roughness, Fade, Start }
local held = {} -- name -> { Magnitude, Roughness }
local last = CFrame.identity
local bound = false

local function offset(now)
	local x, y, z = 0, 0, 0
	local function add(magnitude, roughness)
		local a = now * roughness
		x += magnitude * math.noise(a, 11.3)
		y += magnitude * math.noise(a, 27.1)
		z += 0.5 * magnitude * math.noise(a, 41.9)
	end
	for i = #kicks, 1, -1 do
		local kick = kicks[i]
		local left = 1 - (now - kick.Start) / kick.Fade
		if left <= 0 then
			table.remove(kicks, i)
		else
			add(kick.Magnitude * left * left, kick.Roughness)
		end
	end
	for _, hold in held do
		add(hold.Magnitude, hold.Roughness)
	end
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function ensureBound()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep(UNDO, UNDO_PRIORITY, function()
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame *= last:Inverse()
		end
		last = CFrame.identity
	end)
	RunService:BindToRenderStep(APPLY, APPLY_PRIORITY, function()
		local camera = Workspace.CurrentCamera
		local shake = offset(os.clock())
		if #kicks == 0 and next(held) == nil then
			bound = false
			RunService:UnbindFromRenderStep(UNDO)
			RunService:UnbindFromRenderStep(APPLY)
		elseif camera then
			last = shake
			camera.CFrame *= last
		end
	end)
end

-- A shake that fades out. magnitude is degrees at its start; roughness is how fast it moves.
function BossShake.Kick(magnitude, roughness, fade)
	if UiMotion.Reduced() or magnitude <= 0 then
		return
	end
	table.insert(kicks, { Magnitude = magnitude, Roughness = roughness, Fade = fade, Start = os.clock() })
	ensureBound()
end

-- A shake that lasts until the same name is set to 0.
function BossShake.Hold(name, magnitude, roughness)
	if magnitude <= 0 or UiMotion.Reduced() then
		held[name] = nil
		return
	end
	held[name] = { Magnitude = magnitude, Roughness = roughness }
	ensureBound()
end

return BossShake
