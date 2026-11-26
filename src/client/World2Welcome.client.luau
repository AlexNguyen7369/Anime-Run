--!nonstrict
-- World 2's first-arrival welcome (docs/WORLD2_SPEC.md "Welcome", design doc 4.47), display only: one small handscroll
-- popup (4.46) when the server sets World2WelcomeShow (Server/WorldWelcome, once per save). Close, OK or a click outside
-- rolls it up; reduced effects get DojoHandscroll's short fade. Contract: Client/UiTest/UiWorld2.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WorldConfig")).Id ~= 2 then
	return -- World 2 only: in World 1 the server never welcomes, so nothing is built
end
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local DojoHandscroll = require(script.Parent:WaitForChild("DojoHandscroll"))
local PanelFrame = require(script.Parent:WaitForChild("PanelFrame"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))

local WIDTH = 640 * AnimeSkin.Units.W / 920 -- px at most, as Client/BossRewardPopup (placeholder)
local LINES = { -- placeholder words (design doc 4.47)
	Intro = "Welcome to the Rift Shrine",
	"New summon pool",
	Hint = "The World 1 gate in the plaza takes you back",
}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function label(name, parent, text)
	return make("TextLabel", name, parent, { BackgroundTransparency = 1, Text = text, TextWrapped = true })
end

local root = make("ScreenGui", "World2Welcome", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	DisplayOrder = 60, -- over the HUD and panels, under the boss rewards (62)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false,
})
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
})
PanelSwitch.DimWith(panel) -- design doc 4.42: it dims the world like every popup
local title = make("TextLabel", "Title", panel, { Text = "World 2" })
local closeButton = make("TextButton", "CloseButton", panel, { Text = "" })
local g = AnimeSkin.IndexFrame(panel, { Title = title, Close = closeButton })
local intro = label("Intro", panel, LINES.Intro)
local items = {}
for i, text in ipairs(LINES) do
	items[i] = label("Line" .. i, panel, text)
end
local hint = label("Hint", panel, LINES.Hint)
local ok = make("TextButton", "OK", panel, { Text = "OK", AutoButtonColor = false })

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
-- Top down in the content area: the intro (Section), one Item line each, the hint (Body), OK at the bottom.
local function layout()
	local c, U, T = g.Content, AnimeSkin.Units, AnimeSkin.UnitSize
	local y = c.Y
	g.Place(intro, c.X, y, c.W, T.Section + 8)
	y += T.Section + 8 + U.Gap
	for _, line in items do
		g.Place(line, c.X, y, c.W, T.Item + 6)
		y += T.Item + 6 + U.Gap
	end
	g.Place(hint, c.X, y, c.W, c.Y + c.H - U.Button - U.Gap - y)
	g.Place(ok, c.X + (c.W - 200) / 2, c.Y + c.H - U.Button, 200, U.Button)
	g.Role(intro, "Section")
	for _, line in items do
		g.Role(line, "Item")
	end
	g.Role(hint, "Body")
	g.Role(ok, "Item")
end
UiTheme.Apply(panel)
g.Button(ok, "Go") -- after UiTheme.Apply's corner snap (design doc 4.42)
g.OnLayout(layout)

local closing = false
local function close()
	if not panel.Visible or closing then
		return
	end
	closing = true
	player:SetAttribute("World2WelcomeShow", nil) -- local only: the server's flag is already saved
	DojoHandscroll.Close(panel, function()
		closing = false
		panel.Visible = false
		root.Enabled = false
	end)
end
closeButton.Activated:Connect(close)
ok.Activated:Connect(close)
PanelFrame.CloseOnOutsideClick(panel, close)

-- Once a session: root attribute Done (the UI test clears it to show it again).
local function update()
	if player:GetAttribute("World2WelcomeShow") == true then
		if root:GetAttribute("Done") or (panel.Visible and not closing) then
			return
		end
		root:SetAttribute("Done", true)
		closing = false
		root.Enabled = true
		panel.Visible = true
		DojoHandscroll.Open(panel) -- design doc 4.46: unrolls from its centre, reduced effects fade
		UiFeedback.Play("ToastHigh")
	else
		close()
	end
end
player:GetAttributeChangedSignal("World2WelcomeShow"):Connect(update)
update()
