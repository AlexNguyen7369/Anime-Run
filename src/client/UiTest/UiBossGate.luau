--!nonstrict
-- ui_boss_gate: the boss gate's client half (WORLD_REDESIGN_SPEC 4.2), Client/BossGateView and the prompt in Client/BossEventUi
-- (its GatePrompt bindable stands in for the press). A client-only gate stands in while the suite runs, with
-- BossGateConfig.LIVE on for this client; the switch, attributes and gate are put back at the end.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectionService = game:GetService("CollectionService")
local Config = require(Shared:WaitForChild("BossGateConfig"))
local SidekickConfig = require(Shared:WaitForChild("SidekickConfig"))
local SpawnArea = require(Shared:WaitForChild("SpawnArea"))

local WAIT = 1 -- s: the popup's unroll or roll-up has finished

local Module = {}

function Module.Build(h)
	local scenarios = {}
	local player = Players.LocalPlayer
	local function ok(res, name, value)
		h.check(res, name, value, true, value == true)
	end

	function scenarios.ui_boss_gate(res)
		local root = player:WaitForChild("PlayerGui"):FindFirstChild("RacerBossEvent")
		local panel = root and root:FindFirstChild("BossesPanel")
		local press = root and root:FindFirstChild("GatePrompt")
		ok(res, "popup_exists", panel ~= nil)
		ok(res, "press_seam_exists", press ~= nil)
		local area = workspace:FindFirstChild("SpawnArea")
		if area then -- the hub can be streamed out
			ok(res, "gate_follows_live", (area:FindFirstChild("BossGate") ~= nil) == Config.LIVE)
		end
		if not (panel and press) then
			return
		end
		local need = SidekickConfig.HudFromRebirth
		local wasLive, wasOpen = Config.LIVE, ReplicatedStorage:GetAttribute(Config.OPEN_ATTRIBUTE)
		local wasRebirth = player:GetAttribute("RebirthLevel")
		Config.LIVE = true
		local gate = SpawnArea.BossGate(CFrame.new(0, -200, 0)) -- far under the map
		gate.Parent = workspace
		local done, err = pcall(function()
			local prompt = gate:FindFirstChild(Config.PROMPT, true)
			local function state(open, rebirth)
				ReplicatedStorage:SetAttribute(Config.OPEN_ATTRIBUTE, open)
				player:SetAttribute("RebirthLevel", rebirth)
				task.wait(0.2)
			end
			local function shows(tag)
				local seen = 0
				for _, part in CollectionService:GetTagged(tag) do
					seen += part:IsDescendantOf(gate) and part.Transparency == 0 and 1 or 0
				end
				return seen > 0
			end
			local function presses(p)
				press:Fire(p)
				task.wait(WAIT)
				return panel.Visible
			end
			ok(res, "starts_closed_popup", not panel.Visible)
			for _, c in
				{
					{ "closed", false, need },
					{ "below_rebirth", true, need - 1 },
				}
			do
				state(c[2], c[3])
				ok(res, c[1] .. "_doors", shows(Config.CLOSED_TAG) and not shows(Config.OPEN_TAG))
				ok(res, c[1] .. "_press_does_nothing", not presses(prompt))
			end
			state(true, need)
			ok(res, "open_fire", shows(Config.OPEN_TAG) and not shows(Config.CLOSED_TAG))
			local other = Instance.new("ProximityPrompt")
			other.Name = Config.GUIDE_PROMPT
			other.Parent = gate.PrimaryPart
			ok(res, "other_prompt_does_nothing", not presses(other))
			Config.LIVE = false
			ok(res, "off_press_does_nothing", not presses(prompt))
			Config.LIVE = true
			ok(res, "open_press_opens_bosses", presses(prompt))
			ok(res, "second_press_closes_it", not presses(prompt)) -- as the button
		end)
		gate:Destroy()
		Config.LIVE = wasLive
		ReplicatedStorage:SetAttribute(Config.OPEN_ATTRIBUTE, wasOpen)
		player:SetAttribute("RebirthLevel", wasRebirth)
		h.check(res, "completed", done and "ok" or tostring(err), "ok", done)
	end

	return { Scenarios = scenarios }
end

return Module
