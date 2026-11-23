--!nonstrict
-- Index presentation and the shared Scroll Dojo parts (design doc 4.46, docs/UI_SCROLL_SPEC.md Kit): the Index on a
-- horizontal handscroll (Client/DojoHandscroll) with the brush wordmark, vermilion kanji, seal close, paper tabs and
-- paper cards. Style.Dojo holds the parts Client/AnimeSkin and Client/QuestAnimeStyle share. The 4.42 art (ART, Text)
-- stays only for the Upgrades tree, which keeps today's look (owner 2026-11-20).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local DojoHandscroll = require(script.Parent:WaitForChild("DojoHandscroll"))
local Style = {}
local ART = {
	Body = "rbxassetid://105894082013432",
	Header = "rbxassetid://89849999905528",
	Tabs = {
		"rbxassetid://110525026310951",
		"rbxassetid://93619241022605",
		"rbxassetid://96700522803536",
		"rbxassetid://125278434531831",
	},
	Logo = "rbxassetid://79149512473529",
	Chrome = "rbxassetid://85567379215904",
	Close = "rbxassetid://83852954634304",
	Card = "rbxassetid://126554881187487",
	Plate = "rbxassetid://128657926524494",
}
-- Every panel and popup frame in design units (design doc 4.42 "Wider panels", owner 2026-11-10: 1.3 x the old
-- 920 x 620, phone 500 x 420). Client/AnimeSkin.Units reads it.
local FRAME = { W = 1200, H = 620, PhoneW = 650, PhoneH = 420 }
Style.Frame = FRAME
local INK = Color3.fromRGB(4, 6, 17)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local function make(class, name, parent, props)
	local o = Instance.new(class)
	o.Name = name
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function image(parent, name, id, pos, size, z)
	return make("ImageLabel", name, parent, {
		BackgroundTransparency = 1,
		Image = id,
		Position = pos,
		Size = size,
		ZIndex = z,
		ScaleType = Enum.ScaleType.Stretch,
	})
end

-- Scroll Dojo colours and fonts (assets/ui/scroll_redesign/drafts/kit.css), from UiTheme.Scroll and UiTheme.Dojo
-- where those have them. Proposed values.
local K, J = UiTheme.Scroll, UiTheme.Dojo
local C = {
	Ink = Color3.fromRGB(46, 30, 22), -- #2E1E16
	InkSoft = Color3.fromRGB(92, 70, 54), -- #5C4636
	Muted = Color3.fromRGB(138, 116, 98), -- #8A7462
	Verm = K.Accent,
	VermLight = Color3.fromRGB(213, 58, 51), -- #D53A33, the close seal's top
	VermDeep = Color3.fromRGB(142, 28, 26), -- #8E1C1A
	Brush = J.BrushRed, -- the active tab's red brush pill
	Cream = K.Cream,
	SealText = K.SealText,
	Rim = K.TileRim,
	Edge = K.TileEdge,
	TileTop = K.TileTop,
	TileBottom = K.TileBottom,
	CardTop = J.Card,
	CardBottom = Color3.fromRGB(243, 230, 200), -- #F3E6C8
	ArtTop = J.ArtTop,
	ArtBottom = J.ArtBottom,
	TabTop = Color3.fromRGB(251, 243, 224), -- #FBF3E0
	TabBottom = Color3.fromRGB(234, 217, 180), -- #EAD9B4
	Field = Color3.fromRGB(251, 245, 230), -- #FBF5E6, paper buttons
	Slip = K.Slip,
	SlipRim = Color3.fromRGB(201, 185, 150), -- #C9B996
	Lacquer = Color3.fromRGB(58, 50, 51), -- #3A3233
	LacquerDark = K.LacquerDark,
	GoldSoft = J.Gold,
	Gold = K.TagGold,
	GoTop = J.DeployTop,
	GoBottom = J.DeployBottom,
	GoRim = J.DeployRim,
	Track = Color3.fromRGB(216, 199, 163), -- #D8C7A3, a progress bar's track
}
local F = {
	Title = K.Heading, -- Permanent Marker
	Button = K.Script, -- Kalam Bold
	Body = K.BodyBold, -- Titillium Web Bold
	Caption = Font.new("rbxasset://fonts/families/TitilliumWeb.json", Enum.FontWeight.SemiBold),
}
-- Text roles on paper: font and default colour. Footer text sits on a lacquer plate.
local ROLES = {
	Title = { F.Title, C.Ink },
	Section = { F.Title, C.Ink },
	Item = { F.Button, C.Ink },
	Tab = { F.Button, C.Ink },
	Footer = { F.Button, C.Cream },
	Body = { F.Body, C.Ink },
	Caption = { F.Caption, C.Muted },
}
-- The vertical kanji and the short sub line beside each title (4.46; decoration only, labels stay English), by the
-- title in capitals; a title not listed gets none.
local HEADINGS = {
	INDEX = { "図鑑", "Every character you can roll" },
	BACKPACK = { "道具", "Your characters, potions and gear" },
	ITEMS = { "道具", "Your characters, potions and gear" },
	SHOP = { "商店", "Passes, potions and codes" },
	MARKET = { "市場", "Trails, auras and potions for Money" },
	QUESTS = { "任務", "Daily and weekly goals" },
	["DAILY REWARDS"] = { "日課", "7 days" },
	REBIRTH = { "転生", "Start again, run stronger" },
	STATS = { "能力", "Spend points from rebirths and the index" },
	SETTINGS = { "設定", "Sound, camera and selling" },
	TRACKS = { "道場", "Pick where your runs start" },
	BOSSES = { "討伐", "" },
	["CHOOSE YOUR STARTER"] = { "選択", "" },
	["PICK A TRACK"] = { "決闘", "" },
	["DUEL REQUEST"] = { "挑戦", "" },
	["SEND A GIFT"] = { "贈物", "" },
	SLOTS = { "装備", "" },
	SELL = { "売却", "" },
	["AUTO SELL"] = { "自動", "" },
	["ROLL ODDS"] = { "確率", "" },
}

local Dojo = { Colors = C, Fonts = F, Roles = ROLES }
Style.Dojo = Dojo

-- The object's own gradients and border strokes give way to `name`'s (created once, enabled again on every call).
local function own(gui, class, name)
	for _, d in gui:GetChildren() do
		if
			d:IsA(class)
			and d.Name ~= name
			and (class ~= "UIStroke" or d.ApplyStrokeMode == Enum.ApplyStrokeMode.Border)
		then
			d.Enabled = false
		end
	end
	local found = gui:FindFirstChild(name) or make(class, name, gui, {})
	found.Enabled = true
	return found
end

-- A vertical fill from `top` to `bottom` on `gui` (its own fill shows again).
function Dojo.Fill(gui, top, bottom)
	gui.BackgroundColor3 = Color3.new(1, 1, 1)
	gui.BackgroundTransparency = 0
	gui.BorderSizePixel = 0
	local g = own(gui, "UIGradient", "DojoFill")
	g.Color, g.Rotation, g.Transparency = ColorSequence.new(top, bottom or top), 90, NumberSequence.new(0)
	return g
end

-- A border rim on `gui` (the object's other border strokes are disabled).
function Dojo.Rim(gui, color, thickness)
	local s = own(gui, "UIStroke", "DojoRim")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Thickness, s.Transparency = color, thickness or 2, 0
	return s
end

-- Corner radius in px, again next frame (UiTheme.Apply snaps new corners to 8).
function Dojo.Corner(gui, px)
	local c = gui:FindFirstChildOfClass("UICorner") or make("UICorner", "Corner", gui, {})
	c.CornerRadius = UDim.new(0, px)
	task.defer(function()
		c.CornerRadius = UDim.new(0, px)
	end)
	return c
end

-- A text role on paper: its font and colour (the DojoTextColor attribute, set by a lit tab, wins), no outline. Marks
-- the label with AnimeRole, so UiTheme.Apply never puts it back on Fredoka.
function Dojo.Text(label, role, color)
	local spec = ROLES[role] or ROLES.Body
	if not label:GetAttribute("AnimeRole") then
		label:SetAttribute("AnimeRole", role)
	end
	label.FontFace = spec[1]
	label.TextColor3 = label:GetAttribute("DojoTextColor") or color or spec[2]
	label.TextStrokeTransparency = 1
	for _, d in label:GetChildren() do
		if d:IsA("UIStroke") and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			d.Enabled = false
		end
	end
	return label
end

-- The close: a vermilion seal (the button itself, so it stays red for the close rules) with a cream X. `caption` is
-- the button's own X label if it has one; else the button's text hides and a SealX label shows the X.
function Dojo.Seal(button, caption)
	-- The red lives in BackgroundColor3 (the close rules read it); the gradient only darkens it towards the bottom.
	Dojo.Fill(button, Color3.new(1, 1, 1), Color3.new(0.66, 0.66, 0.66))
	button.BackgroundColor3 = C.VermLight
	Dojo.Rim(button, C.VermDeep, 2)
	Dojo.Corner(button, 6)
	if button:IsA("GuiButton") then
		button.AutoButtonColor = false
	end
	button.Rotation = -4
	local old = button:FindFirstChild("AnimeCloseArt")
	if old then
		old.Visible = false
	end
	local inner = button:FindFirstChild("SealRim")
		or make("Frame", "SealRim", button, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			Active = false,
		})
	inner.ZIndex = button.ZIndex
	if not inner:FindFirstChild("Corner") then
		make("UICorner", "Corner", inner, { CornerRadius = UDim.new(0, 4) })
	end
	local ring = inner:FindFirstChildOfClass("UIStroke") or make("UIStroke", "Ring", inner, {})
	ring.Color, ring.Thickness, ring.Transparency = C.SealText, 2, 0.6
	local x = caption
	if not x and not (button:IsA("TextButton") and button.Text == "X") then -- else the button's own X shows
		x = button:FindFirstChild("SealX")
			or make("TextLabel", "SealX", button, {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "X",
				TextScaled = true,
				Active = false,
			})
		if button:IsA("TextButton") then
			button.TextTransparency = 1
		end
	end
	local glyph = x or button
	glyph:SetAttribute("AnimeRole", glyph:GetAttribute("AnimeRole") or "Item")
	glyph:SetAttribute("DojoTextColor", C.SealText) -- a later button tone or text role keeps the cream X
	glyph.Visible = true
	if x then
		x.ZIndex = button.ZIndex + 1
	end
	glyph.FontFace = F.Body
	glyph.TextColor3 = C.SealText
	glyph.TextTransparency = 0
	glyph.TextStrokeTransparency = 1
	for _, d in glyph:GetChildren() do
		if d:IsA("UIStroke") then
			d.Enabled = false
		end
	end
	if x then
		x.AnchorPoint = Vector2.new(0.5, 0.5)
		x.Position, x.Size = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.62, 0.62)
		x.TextScaled = true
	end
	return glyph
end

-- A paper tab under `face`'s caption: a child DojoTab frame carries the fill (the face's own colour stays for whoever
-- tweens it). Returns lit(on): the active tab is a red brush pill with cream text.
function Dojo.Tab(face, captions)
	local plate = face:FindFirstChild("DojoTab")
		or make("Frame", "DojoTab", face, { Size = UDim2.fromScale(1, 1), ZIndex = 1, Active = false })
	local corner = plate:FindFirstChild("Corner") or make("UICorner", "Corner", plate, {})
	local rim = Dojo.Rim(plate, C.Rim, 2)
	return function(on)
		if on then
			Dojo.Fill(plate, C.Brush)
			rim.Color = C.VermDeep
			corner.CornerRadius = UDim.new(0, 14)
		else
			Dojo.Fill(plate, C.TabTop, C.TabBottom)
			rim.Color = C.Rim
			corner.CornerRadius = UDim.new(0, 4)
		end
		for _, label in captions do
			label:SetAttribute("DojoTextColor", on and C.Cream or C.Ink)
			label.TextColor3 = on and C.Cream or C.Ink
		end
	end
end

-- A dark lacquer plate with a gold rim (footer counts, reward boxes).
function Dojo.Lacquer(frame)
	Dojo.Fill(frame, C.Lacquer, C.LacquerDark)
	Dojo.Rim(frame, C.GoldSoft, 2)
	Dojo.Corner(frame, 4)
	return frame
end

-- The footer's lacquer plate behind `line` (a TextLabel): a FooterPlate sibling sized to the text, shown only while
-- the line has text. `pad` is the room round the text in px.
function Dojo.FooterPlate(line, pad)
	local parent = line.Parent
	local plate = parent:FindFirstChild("FooterPlate")
		or Dojo.Lacquer(make("Frame", "FooterPlate", parent, { AnchorPoint = Vector2.new(0.5, 0.5), Active = false }))
	local function fit()
		local p = pad or 14
		plate.ZIndex = math.max(line.ZIndex - 1, 1)
		plate.Visible = line.Visible and line.Text ~= ""
		local center = line.Position + UDim2.new(line.Size.X.Scale / 2, line.Size.X.Offset / 2, 0, 0)
		plate.Position = center + UDim2.new(0, 0, line.Size.Y.Scale / 2, line.Size.Y.Offset / 2)
		plate.Size = UDim2.new(
			0,
			math.min(line.TextBounds.X, line.AbsoluteSize.X) + 4 * p,
			line.Size.Y.Scale,
			line.Size.Y.Offset + p
		)
	end
	for _, prop in { "TextBounds", "Position", "Size", "Visible", "Text" } do
		line:GetPropertyChangedSignal(prop):Connect(fit)
	end
	fit()
	return plate
end

-- The kanji and sub line after `title` (its parent's coordinates, Offset positions): Kanji and Sub labels beside it.
-- Returns place(px, width): px turns design units into px, width is the frame's width in px. Follows the title.
function Dojo.Heading(title)
	local parent = title.Parent
	local kanji = parent:FindFirstChild("Kanji")
		or make("TextLabel", "Kanji", parent, {
			BackgroundTransparency = 1,
			TextColor3 = C.Verm,
			TextScaled = true,
			Active = false,
		})
	kanji:SetAttribute("AnimeRole", "Kanji") -- UiTheme.Apply leaves it (it reset the font when it was parented)
	kanji.Font = Enum.Font.GothamBold -- CJK through Roblox's font fallback; decoration only
	local sub = parent:FindFirstChild("Sub")
		or make("TextLabel", "Sub", parent, {
			BackgroundTransparency = 1,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Active = false,
		})
	Dojo.Text(sub, "Item", C.InkSoft)
	local last = nil
	local function place(px, width)
		last = { px, width }
		local upper = string.upper(title.Text)
		local words = HEADINGS[upper] or (string.find(upper, "DEFEATED", 1, true) and { "勝利", "" }) or nil
		local glyphs = {}
		for _, code in utf8.codes(words and words[1] or "") do
			table.insert(glyphs, utf8.char(code))
		end
		kanji.Text = table.concat(glyphs, "\n")
		sub.Text = words and words[2] or ""
		kanji.ZIndex, sub.ZIndex = title.ZIndex, title.ZIndex
		kanji.Visible, sub.Visible = title.Visible and kanji.Text ~= "", title.Visible and sub.Text ~= ""
		local x = title.Position.X.Offset + math.min(title.TextBounds.X, title.AbsoluteSize.X) + px(8)
		local y = title.Position.Y.Offset
		kanji.Position, kanji.Size = UDim2.fromOffset(x, y + px(2)), UDim2.fromOffset(px(30), px(64))
		local subX = x + px(42)
		sub.Position = UDim2.fromOffset(subX, y + px(34))
		sub.Size = UDim2.fromOffset(math.max(0, width - subX - px(120)), px(28))
	end
	for _, prop in { "TextBounds", "Text", "Visible" } do
		title:GetPropertyChangedSignal(prop):Connect(function()
			if last then
				place(last[1], last[2])
			end
		end)
	end
	return place
end

-- The handscroll behind a panel (design doc 4.46): DojoHandscroll on `target`, the object PanelSwitch animates.
function Dojo.Scroll(target)
	return DojoHandscroll.Build(target)
end

-- Retired 4.42 chrome art: an empty frame now (the handscroll is the frame; design doc 4.46). Same returns: the Frame
-- and place(x, y, w, h), which does nothing.
function Style.Chrome(parent, name, z)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local root = make("Frame", name, parent, { BackgroundTransparency = 1, ZIndex = z, Active = false })
	return root, function() end
end
local function transparent(o)
	o.BackgroundTransparency = 1
	for _, d in o:GetChildren() do
		if d:IsA("UIStroke") or d:IsA("UIGradient") then
			d.Enabled = false
		end
		if d:IsA("GuiObject") and (d.Name == "Shadow" or d.Name == "Lift") then
			d.Visible = false
		end
	end
end
local function text(label, max)
	label.FontFace = FONT
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 1
	local outline = label:FindFirstChildOfClass("UIStroke") or make("UIStroke", "AnimeOutline", label, {})
	outline.Color = INK
	outline.Thickness = 2.5
	outline.Enabled = true
	if max then
		label.TextScaled = true
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
			or make("UITextSizeConstraint", "AnimeLimit", label, {})
		limit.MinTextSize = 10
		limit.MaxTextSize = max
	end
end
function Style.Apply(gui)
	if gui:GetAttribute("AnimeIndexApplied") then
		return
	end
	gui:SetAttribute("AnimeIndexApplied", true)
	gui:SetAttribute("IndexCustomLayout", true)
	local panel = gui:WaitForChild("Panel")
	local face = panel:WaitForChild("Face")
	local header = face:WaitForChild("Header")
	local band = header:WaitForChild("Face")
	local host = face:WaitForChild("GridHost")
	for _, name in { "AnimeChrome", "AnimeBanner", "ProgressPlate", "GridPlate" } do
		local old = face:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, name in { "IndexTitle", "IndexIcon" } do
		local old = band:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	transparent(face)
	transparent(band)
	panel.Shadow.Visible = false
	header.Shadow.Visible = false
	header.ZIndex = 8
	-- Design doc 4.46: the handscroll on the panel PanelSwitch unrolls (the wrapper, not its Face).
	Dojo.Scroll(panel)
	local banner = make("Frame", "AnimeBanner", face, {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 98),
		ZIndex = 6,
	})
	local logo = image(banner, "Logo", ART.Logo, UDim2.fromOffset(28, 14), UDim2.fromOffset(70, 70), 11)
	logo.ScaleType = Enum.ScaleType.Fit
	local title = make("TextLabel", "Title", banner, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(108, 12),
		Size = UDim2.fromOffset(420, 72),
		Text = "INDEX",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	local heading = Dojo.Heading(title)
	local rule = make("Frame", "HeaderRule", banner, {
		BackgroundColor3 = C.InkSoft,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(28, 90),
		ZIndex = 6,
		Active = false,
	})
	local tabs = { "CharactersTab", "EnemiesTab", "SidekicksTab", "RelicsTab" }
	local captions = {}
	for _, name in tabs do
		local tab = band:FindFirstChild(name)
		if tab then
			tab.Rotation = 0
			tab.ZIndex = 8
			transparent(tab.Face)
			if tab:FindFirstChild("Shadow") then
				tab.Shadow.Visible = false
			end
			for _, old in tab.Face:GetChildren() do
				if
					old.Name == "AnimeTab"
					or old.Name == "TabColor"
					or old.Name == "Shine"
					or old.Name == "AnimeTabArt"
				then
					old:Destroy()
				end
			end
			local labels = {}
			for _, d in tab.Face:GetChildren() do
				if d:IsA("TextLabel") then
					d.ZIndex = 4
					d.Position = UDim2.fromOffset(8, 0)
					d.Size = UDim2.new(1, -16, 1, 0)
					table.insert(captions, d)
					table.insert(labels, d)
				end
			end
			local lit = Dojo.Tab(tab.Face, labels)
			local function mark()
				tab.Face.BackgroundTransparency = 1
				for _, d in labels do
					Dojo.Text(d, "Tab")
				end
				lit(tab.Face:GetAttribute("TabLit") == true)
			end
			tab.Face:GetAttributeChangedSignal("TabLit"):Connect(function()
				task.defer(mark)
			end)
			task.defer(mark)
		end
	end
	local close = band.Close
	close.Rotation = 0
	close.ZIndex = 10
	local closeCaption = close.Face:FindFirstChildWhichIsA("TextLabel")
	if close:FindFirstChild("Shadow") then
		close.Shadow.Visible = false
	end
	close.Face.Text = ""
	transparent(close.Face)
	Dojo.Seal(close.Face, closeCaption)
	local progress = face.IndexProgress
	local function layout()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1366, 768)
		local phone = viewport.Y <= 500
		local target = phone and UDim2.fromOffset(FRAME.PhoneW, FRAME.PhoneH) or UDim2.fromOffset(FRAME.W, FRAME.H)
		if panel.Size ~= target then
			panel.Size = target
		end
		local w, h = panel.Size.X.Offset, panel.Size.Y.Offset
		if w < 1 then
			w = 780
		end
		if h < 1 then
			h = 524
		end
		local tabsY = phone and 90 or 98
		header.Position = UDim2.fromOffset(56, tabsY)
		header.Size = UDim2.fromOffset(w - 112, 44)
		transparent(band)
		header.Shadow.Visible = false
		local width = (w - 136) / 4
		for i, name in tabs do
			local tab = band:FindFirstChild(name)
			if tab then
				tab.Position = UDim2.fromOffset((i - 1) * (width + 8), 0)
				tab.Size = UDim2.fromOffset(width, 40)
				tab.Face.Position = UDim2.fromOffset(0, 0)
				tab.Face.AnchorPoint = Vector2.zero
				tab.Face.Size = UDim2.fromScale(1, 1)
			end
		end
		-- The seal close at the frame's top-right (64 x 64 at x w - 92, y 16), in the band's coordinates.
		close.Position = UDim2.fromOffset(w - 92 - 56, 16 - tabsY)
		close.Size = UDim2.fromOffset(64, 64)
		rule.Size = UDim2.fromOffset(w - 56, 3)
		title.Size = UDim2.fromOffset(w - 108 - 120, 72)
		heading(function(x)
			return x
		end, w)
		local top = phone and 144 or 164
		host.Position = UDim2.fromOffset(56, top)
		host.Size = UDim2.fromOffset(w - 112, h - top - 82)
		host.ZIndex = 3
		progress.Position = UDim2.fromOffset(w * 303 / 920, h - 60)
		progress.Size = UDim2.fromOffset(w * 312 / 920, 28)
		progress.Rotation = 0
		progress.ZIndex = 4
	end
	local queued = false
	local function queue()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			layout()
		end)
	end
	panel:GetPropertyChangedSignal("Size"):Connect(queue)
	-- Generated fits can run after startup or a window resize. Reconcile once after that pass.
	for _, object in { header, host, close } do
		object:GetPropertyChangedSignal("Position"):Connect(queue)
		object:GetPropertyChangedSignal("Size"):Connect(queue)
	end
	for _, name in tabs do
		local tab = band:FindFirstChild(name)
		if tab then
			tab:GetPropertyChangedSignal("Position"):Connect(queue)
			tab:GetPropertyChangedSignal("Size"):Connect(queue)
		end
	end
	band:GetPropertyChangedSignal("BackgroundTransparency"):Connect(queue)
	gui:GetAttributeChangedSignal("InventoryTab"):Connect(queue)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.delay(0.15, queue)
		end)
	end
	layout()
	Dojo.FooterPlate(progress, 8)
	-- Design doc 4.46 Index frame: paper cards with a brown rim, the drawn portrait on a pink art field, the rarity as
	-- a coloured strip under it; name in the brush face, odds and multi in the body face.
	local styled = {}
	local function restyleTile(tile)
		if
			styled[tile]
			or not tile:IsA("Frame")
			or not tile:FindFirstChild("Art")
			or not tile:FindFirstChild("CharacterName")
		then
			return
		end
		styled[tile] = true
		local rim = tile:FindFirstChild("Rim")
		local rarity = rim and rim:FindFirstChildOfClass("UIStroke")
		if rim then
			rim.Visible = false
		end
		for _, name in { "IndexOutlineGlow", "AngularOutlineGlow", "AngularCard", "AngularName" } do
			local old = tile:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local shade = tile:FindFirstChild("Shade")
		if shade then
			shade.Visible = false
		end
		Dojo.Fill(tile, C.CardTop, C.CardBottom)
		Dojo.Rim(tile, C.Rim, 2)
		Dojo.Corner(tile, 6)
		local field = make("Frame", "ArtField", tile, {
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.55),
			ZIndex = 1,
			Active = false,
		})
		Dojo.Fill(field, C.ArtTop, C.ArtBottom)
		Dojo.Corner(field, 6)
		local strip = make("Frame", "RarityStrip", tile, {
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.55),
			Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 2,
			Active = false,
		})
		local function tint()
			strip.BackgroundColor3 = rarity and rarity.Color or C.Muted
		end
		tint()
		if rarity then
			rarity:GetPropertyChangedSignal("Color"):Connect(tint)
		end
		local art = tile.Art
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.fromScale(0.5, 0.02)
		art.Size = UDim2.fromScale(0.86, 0.53)
		art.ZIndex = math.max(art.ZIndex, 3)
		local name = tile.CharacterName
		name.Position = UDim2.new(0, 8, 0.55, 8)
		name.Size = UDim2.new(1, -16, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		Dojo.Text(name, "Item")
		local info = tile:FindFirstChild("Info")
		if info then
			info.Position = UDim2.new(0, 8, 0.55, 30)
			info.Size = UDim2.new(1, -16, 0, 14)
			Dojo.Text(info, "Caption")
		end
		local odds = tile:FindFirstChild("Odds")
		if odds then
			odds.Position = UDim2.fromOffset(8, 6)
			odds.Size = UDim2.new(1, -16, 0, 18)
			Dojo.Text(odds, "Body")
		end
		local category = tile:FindFirstChild("Category")
		if category then
			category.Visible = false
		end
		local equip = tile:FindFirstChild("Equip")
		if equip then
			equip.Position = UDim2.new(0, 8, 1, -24)
			equip.Size = UDim2.new(1, -16, 0, 20)
			for _, c in equip:GetChildren() do
				if c:IsA("UICorner") then
					c.CornerRadius = UDim.new(0, 4)
				end
				if c:IsA("TextLabel") then
					Dojo.Text(c, "Item")
				end
			end
		end
	end
	local gallery = host:FindFirstChild("Gallery")
	if gallery then
		local grid = gallery:FindFirstChildOfClass("UIGridLayout")
		if grid then
			local function fitGallery()
				local phone = workspace.CurrentCamera.ViewportSize.Y <= 500
				local cols = phone and 3 or 7 -- design doc 4.42 "Wider panels": 7 across (proposed)
				local width = host.Size.X.Offset - 14
				local cell =
					UDim2.fromOffset(math.min(178, math.floor((width - (cols - 1) * 16) / cols)), phone and 150 or 176)
				if grid.CellSize ~= cell then
					grid.CellSize = cell
				end
				grid.CellPadding = UDim2.fromOffset(16, 16)
			end
			grid:GetPropertyChangedSignal("CellSize"):Connect(function()
				task.defer(fitGallery)
			end)
			host:GetPropertyChangedSignal("Size"):Connect(function()
				task.defer(fitGallery)
			end)
			fitGallery()
		end
		for _, tile in gallery:GetChildren() do
			restyleTile(tile)
		end
		gallery.ChildAdded:Connect(function(tile)
			task.defer(restyleTile, tile)
		end)
	end
	local function styleCard(d)
		if d:IsA("UICorner") then
			d.CornerRadius = UDim.new(0, 6)
		end
		if d:IsA("TextLabel") and d.Name == "CharacterName" then
			Dojo.Text(d, "Item")
		end
	end
	for _, d in host:GetDescendants() do
		styleCard(d)
	end
	host.DescendantAdded:Connect(function(d)
		task.defer(styleCard, d)
	end)
	-- Again after UiTheme.Apply's deferred pass, which puts new text back on its own font.
	task.defer(function()
		Dojo.Text(title, "Title")
		Dojo.Text(progress, "Footer")
		progress.TextScaled = true
		progress.TextXAlignment = Enum.TextXAlignment.Center
		for _, label in captions do
			Dojo.Text(label, "Tab")
		end
		layout()
	end)
end
-- The 4.42 art and text treatment, kept for the Upgrades tree (Client/AnimeSkin's legacy path; design doc 4.46 scope).
Style.Art, Style.Ink, Style.Image, Style.Text = ART, INK, image, text
return Style
