--!nonstrict
-- The plaza's ProximityPrompts (Shared/SpawnArea, docs/WORLD_REDESIGN_SPEC.md section 4) open the existing panels,
-- exactly as their HUD tiles do. The Market (MarketService) and the sensei (CheckpointUi) wire their own prompts.
local ProximityPromptService = game:GetService("ProximityPromptService")
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local PANEL = {
	OpenShop = "Shop",
	OpenPotions = "Shop", -- the Potions section lives in the Shop panel
	OpenRebirth = "Rebirth",
	OpenIndex = "Index",
}

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local panel = PANEL[prompt.Name]
	if panel and prompt:IsDescendantOf(workspace) then
		PanelSwitch.Action(panel)
	end
end)
