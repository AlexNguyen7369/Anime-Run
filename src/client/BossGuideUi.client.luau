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
local Layout = require(Shared:WaitForChild("BossGuideLayout"))
local Gate = require(Shared:WaitForChild("BossGateConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local Dojo = require(script.Parent:WaitForChild("IndexAnimeStyle")).Dojo
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local TouchTarget = require(script.Parent:WaitForChild("TouchTarget"))

local NAME = "BossGuide"
local WIDTH = 640 * AnimeSkin.Units.W / 920 -- px at most, as Client/World2Welcome (placeholder)

local ART = Color3.fromRGB(190, 212, 222) -- the portrait card's fill, as the approved mock-up

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
local g = AnimeSkin.IndexFrame(panel, { Title = title, Close = closeButton, H = Layout.FRAME_H, Top = Layout.TOP })
-- Layout B: the portrait in a framed card, the line on a paper slip with a vermilion edge (no slip on phones)
local function plate(name, zIndex)
	return make("Frame", name, panel, { Active = false, BorderSizePixel = 0, ZIndex = zIndex })
end
local card, slip, bar = plate("Card", 2), plate("Slip", 2), plate("SlipBar", 3)
local portrait = make("ImageLabel", "Portrait", panel, {
	BackgroundTransparency = 1,
	ZIndex = 3,
	ScaleType = Enum.ScaleType.Fit,
	Image = CharacterPortraits[Config.ID] or "",
})
local line = make("TextLabel", "Line", panel, {
	BackgroundTransparency = 1,
	ZIndex = 4,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	Text = "",
})
local nextButton = make("TextButton", "Next", panel, { Text = "Next", AutoButtonColor = false, ZIndex = 5 })
nextButton:SetAttribute("FirstFocus", true) -- gamepad: A pages on, B closes (PanelSwitch)

local function size()
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local U = AnimeSkin.Units
	local w, h = AnimeSkin.Compact() and U.PhoneW or U.W, AnimeSkin.Compact() and U.PhoneH or Layout.FRAME_H
	local width = math.min(WIDTH, (view.X - 32) * w / (w + 80), (view.Y - 32) * w / (h + 100))
	panel.Size = UDim2.fromOffset(math.floor(width), math.floor(width * h / w))
end
size()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(size)
end
local function layout()
	local at = Layout.Rects(g.Content, g.Small)
	local function place(gui, rect)
		g.Place(gui, rect.X, rect.Y, rect.W, rect.H)
	end
	place(card, at.Card)
	place(portrait, at.Portrait)
	place(line, at.Line)
	place(nextButton, at.Next)
	slip.Visible, bar.Visible = at.Slip ~= nil, at.Bar ~= nil
	if at.Slip then
		place(slip, at.Slip)
		place(bar, at.Bar)
	end
	g.Role(line, at.Role)
	g.Role(nextButton, "Item")
end
UiTheme.Apply(panel)
Dojo.Fill(card, ART) -- after UiTheme.Apply, as the button below
Dojo.Rim(card, Dojo.Colors.SlipRim, 2)
Dojo.Fill(slip, Dojo.Colors.Field)
Dojo.Rim(slip, Dojo.Colors.SlipRim, 2)
Dojo.Fill(bar, Dojo.Colors.Verm)
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
	if
		PanelSwitch.IsOpen(NAME)
		or player:GetAttribute("BossEvent") == true
		or not Config.Talks(player:GetAttribute("RebirthLevel"))
	then
		return -- already talking, in the arena, or below rebirth 1
	end
	pages = Config.Pages(ReplicatedStorage:GetAttribute(Gate.OPEN_ATTRIBUTE) == true)
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
		pages = Config.Pages(false)
		draw()
	end
	if not panel.Visible then
		pages, page = {}, 1
	end
end)
closeButton.Activated:Connect(close)
nextButton.Activated:Connect(advance)
TouchTarget.Add(nextButton, advance) -- the drawn button is 24 to 31 px tall
TouchTarget.Add(closeButton, close)
PanelFrame.CloseOnOutsideClick(panel, close)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == Gate.GUIDE_PROMPT and prompt:IsDescendantOf(workspace) then
		open()
	end
end)
player:GetAttributeChangedSignal("BossEvent"):Connect(function()
	if player:GetAttribute("BossEvent") == true then
		close()
	end
end)
-- His prompt is built off and shows only to a player he talks to. Found again whenever the hub streams back in.
local function refreshPrompt(d)
	if d:IsA("ProximityPrompt") and d.Name == Gate.GUIDE_PROMPT then
		d.Enabled = Config.Talks(player:GetAttribute("RebirthLevel"))
	end
end
local function watch(model)
	if model.Name == NAME then
		model.DescendantAdded:Connect(refreshPrompt)
		for _, d in model:GetDescendants() do
			refreshPrompt(d)
		end
	end
end
workspace.ChildAdded:Connect(watch)
for _, child in workspace:GetChildren() do
	watch(child)
end
player:GetAttributeChangedSignal("RebirthLevel"):Connect(function()
	for _, child in workspace:GetChildren() do
		if child.Name == NAME then
			for _, d in child:GetDescendants() do
				refreshPrompt(d)
			end
		end
	end
end)
-- Test seams (UiBossGuide): the prompt press and the Next press.
make("BindableEvent", "Open", root, {}).Event:Connect(open)
make("BindableEvent", "Advance", root, {}).Event:Connect(advance)
