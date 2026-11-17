--!nonstrict
-- Gameplay input lock while a full page is open (design doc 4.45, owner 2026-11-17): movement and jump controls are
-- off while any holder holds the lock and come back when the last one releases. Only player input: a run the server
-- drives keeps going. Player attribute PageInputLocked mirrors it (display and tests).
local Players = game:GetService("Players")

local InputLock = {}
local holders = {}

local function controls()
	local ok, module = pcall(function()
		return require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)
	return ok and module or nil
end

local function apply()
	local locked = next(holders) ~= nil
	local player = Players.LocalPlayer
	if player:GetAttribute("PageInputLocked") == locked then
		return
	end
	player:SetAttribute("PageInputLocked", locked)
	task.spawn(function()
		local c = controls()
		if c then
			if next(holders) ~= nil then -- the state now: controls() may have yielded past a later Release
				c:Disable()
			else
				c:Enable()
			end
		end
	end)
end

function InputLock.Hold(key)
	holders[key] = true
	apply()
end

function InputLock.Release(key)
	holders[key] = nil
	apply()
end

return InputLock
