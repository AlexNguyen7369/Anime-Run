--!nonstrict
-- The boss gate guide's conversation (docs/BOSS_GUIDE_SPEC.md), display only: Workspace.BossGuide's E prompt opens one
-- handscroll (4.46) that pages through Shared/BossGuideConfig's lines. PanelSwitch keeps one panel open at a time and gives
-- it gamepad focus and Back. No remote is called. Contract: Client/UiTest/UiBossGuide.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterPortraits = require(Shared:WaitForChild("CharacterPortraits"))
local Config = require(Shared:WaitForChild("BossGuideConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))

local NAME = "BossGuide"
local WIDTH = 640 * AnimeSkin.Units.W / 920 -- px at most, as Client/World2Welcome (placeholder)

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local root = make("ScreenGui", "BossGuideUi", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	DisplayOrder = 2, -- as Client/CheckpointUi
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
})
local title = make("TextLabel", "Title", panel, { Text = Config.Name() })
local closeButton = make("TextButton", "CloseButton", panel, { Text = "" })
local g = AnimeSkin.IndexFrame(panel, { Title = title, Close = closeButton })
local portrait = make("ImageLabel", "Portrait", panel, {
	BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit,
	Image = CharacterPortraits[Config.ID] or "",
})
local line = make("TextLabel", "Line", panel, {
	BackgroundTransparency = 1,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	Text = "",
})
local nextButton = make("TextButton", "Next", panel, { Text = "Next", AutoButtonColor = false })
nextButton:SetAttribute("FirstFocus", true) -- gamepad: A pages on, B closes (PanelSwitch)

local function size()
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local U = AnimeSkin.Units
	local w, h = AnimeSkin.Compact() and U.PhoneW or U.W, AnimeSkin.Compact() and U.PhoneH or U.H
	local width = math.min(WIDTH, (view.X - 32) * w / (w + 80), (view.Y - 32) * w / (h + 100))
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(width * h / w))
end
size()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(size)
end
-- The portrait on the left, the line beside it, Next under both.
local function layout()
	local c, U = g.Content, AnimeSkin.Units
	local body = c.H - U.Button - U.Gap
	local art = math.min(body, c.W * 0.3)
	g.Place(portrait, c.X, c.Y + (body - art) / 2, art, art)
	g.Place(line, c.X + art + U.Gap, c.Y, c.W - art - U.Gap, body)
	g.Place(nextButton, c.X + (c.W - 200) / 2, c.Y + c.H - U.Button, 200, U.Button)
	g.Role(line, "Item")
	g.Role(nextButton, "Item")
end
UiTheme.Apply(panel)
g.Button(nextButton, "Go") -- after UiTheme.Apply's corner snap (design doc 4.42)
g.OnLayout(layout)
PanelSwitch.Register(NAME, panel)

local pages, page = {}, 1
local function draw()
	line.Text = pages[page].Text
	nextButton.Text = page == #pages and "Done" or "Next"
	g.Footer(("%d / %d"):format(page, #pages))
end

local function open()
	if PanelSwitch.IsOpen(NAME) or player:GetAttribute("BossEvent") == true then
		return -- already talking, or in the arena
	end
	pages =
		Config.Pages(ReplicatedStorage:GetAttribute("BossEventPhase") ~= nil, player:GetAttribute("RebirthLevel") or 0)
	page = 1
	draw()
	PanelSwitch.Toggle(NAME)
end
local function close()
	PanelSwitch.Close(NAME)
end
local function advance()
	if not PanelSwitch.IsOpen(NAME) then
		return
	end
	if page == #pages then
		close()
	else
		page += 1
		draw()
	end
end

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible and #pages == 0 then -- opened by name (the UI tests), not by the prompt
		pages = Config.Pages(false, 0)
		draw()
	end
	if not panel.Visible then
		pages, page = {}, 1
	end
end)
closeButton.Activated:Connect(close)
nextButton.Activated:Connect(advance)
PanelFrame.CloseOnOutsideClick(panel, close)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == Config.PROMPT and prompt:IsDescendantOf(workspace) then
		open()
	end
end)
player:GetAttributeChangedSignal("BossEvent"):Connect(function()
	if player:GetAttribute("BossEvent") == true then
		close()
	end
end)
-- Test seams (UiBossGuide): the prompt press and the Next press.
make("BindableEvent", "Open", root, {}).Event:Connect(open)
make("BindableEvent", "Advance", root, {}).Event:Connect(advance)
