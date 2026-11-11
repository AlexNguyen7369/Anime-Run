--!nonstrict
-- The band every hand-built panel opens in (docs/HUD_LAYOUT_SPEC.md section 6): below the Race button, above the
-- TURBO LUCK bar, and right of the left tile block, so a panel never covers a HUD entry. The right edge has no HUD
-- buttons (design doc 4.40 layout L2), so the band runs to GAP from the screen's right edge.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Band = {}
local GAP = 8
-- Owner 2026-11-10: panels run larger. The band keeps the HUD clear at its sides (GAP) but the panel may rise over the
-- hidden Race anchor and the top strip by REACH_UP, and sit this close to the TURBO bar.
local REACH_UP = 24
local REACH_DOWN = 4

-- left, top, right, bottom in IgnoreGuiInset screen offsets, or nil before the HUD exists.
function Band.Rect()
	local camera = workspace.CurrentCamera
	local hud = gui:FindFirstChild("RacerHud")
	local chrome = gui:FindFirstChild("HudChrome")
	local race = hud and hud:FindFirstChild("Race")
	local turbo = hud and hud:FindFirstChild("Turbo")
	local grid = chrome and chrome:FindFirstChild("Grid")
	if not (camera and race and turbo and grid) then
		return nil
	end
	-- AbsolutePosition starts below the top bar; the HUD ScreenGuis ignore the inset, so add it back.
	local inset = GuiService:GetGuiInset().Y
	local viewport = camera.ViewportSize
	-- The block's right edge includes anything that sticks out of it.
	local gridRight = grid.AbsolutePosition.X + grid.AbsoluteSize.X
	for _, child in grid:GetDescendants() do
		if child:IsA("GuiObject") and child.Visible then
			gridRight = math.max(gridRight, child.AbsolutePosition.X + child.AbsoluteSize.X)
		end
	end
	local margin = gridRight + GAP
	local right = viewport.X - GAP
	-- RaceMap is presentation-only and has a fixed anchor. Do not reserve space
	-- for it here: doing so re-centres the open Backpack/Shop panels whenever a
	-- race starts, which makes the persistent HUD appear to move.
	-- The bottom stops above the TURBO LUCK bar and above the Money readout in the bottom-left corner.
	local bottom = turbo.AbsolutePosition.Y
	local money = hud:FindFirstChild("Money")
	if
		money
		and money:IsA("GuiObject")
		and money.Visible
		and money.AbsolutePosition.X + money.AbsoluteSize.X > margin
	then
		bottom = math.min(bottom, money.AbsolutePosition.Y)
	end
	local top = math.max(inset + GAP, race.AbsolutePosition.Y + race.AbsoluteSize.Y + inset + GAP - REACH_UP)
	return margin, top, right, bottom + inset - REACH_DOWN
end

local function shown(object)
	while object and object:IsA("GuiObject") do
		if not object.Visible then
			return false
		end
		object = object.Parent
	end
	return true
end

-- Keeps `panel` centred in the band while it is shown, at most maxWidth wide.
function Band.Fit(panel, maxWidth)
	RunService.Heartbeat:Connect(function()
		if not shown(panel) then
			return
		end
		local left, top, right, bottom = Band.Rect()
		if not left then
			return
		end
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromOffset((left + right) / 2, (top + bottom) / 2)
		-- Never larger than the band: a minimum size would push the panel over the Race button on short phones.
		panel.Size = UDim2.fromOffset(math.max(0, math.min(maxWidth, right - left)), math.max(0, bottom - top))
	end)
end

return Band
