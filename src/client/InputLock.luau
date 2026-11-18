--!nonstrict
-- Gameplay input lock while a full page is open (design doc 4.45, owner 2026-11-17): walk and jump input is sunk while
-- any holder holds the lock and passes again when the last one releases. Only player input: a run the server drives
-- keeps going. ContextActionService, not PlayerModule controls (this place has no PlayerModule). Player attribute
-- PageInputLocked mirrors it (display and tests).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local ACTION = "PageInputLock"
local InputLock = {}
local holders = {}

local function sink()
	return Enum.ContextActionResult.Sink
end

local function apply()
	local locked = next(holders) ~= nil
	local player = Players.LocalPlayer
	if player:GetAttribute("PageInputLocked") == locked then
		return
	end
	player:SetAttribute("PageInputLocked", locked)
	if locked then
		ContextActionService:BindActionAtPriority(
			ACTION,
			sink,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump,
			Enum.KeyCode.W,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Space,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Thumbstick1
		)
	else
		ContextActionService:UnbindAction(ACTION)
	end
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
