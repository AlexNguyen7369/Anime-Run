--!nonstrict
-- Team Setup page (design doc 4.45, owner 2026-11-17; docs/TEAM_AND_STAMINA_SPEC.md "Team" and "Team Setup page";
-- replaces layout A of 4.40). Opened by the second column's Team button and its key T (Client/BossEventUi), a click on
-- the team minibar (Client/TeamHud) and the plaza Team altar (Client/PlazaPrompts), all PanelSwitch "Team", with the
-- shared Sakura transition (cyan accent).
-- Look: T2 "Ledger scroll" (4.45 "Hanging-scroll look", owner 2026-11-19) on the Client/DojoScroll kit, as the Summon
-- page: a tall ledger scroll on the left (wordmark, Team 1 and its status, n / 3, one numbered row per slot, Team Bonus
-- with View, Quick Setup and Deploy on its bottom mount), the three altars beside it with a numbered seal each, and the
-- roster as a handscroll along the bottom. Every control keeps its name and parent so the UI tests still find it.
-- Three stacked octagonal altars hold a local draft of the Team: tap an altar or its ledger row, then a roster card (or
-- the other way round); a member put on another altar swaps; Remove takes one off. Quick Setup asks the server
-- (TeamQuickPick) for the best owned characters for the empty altars; Deploy sends the draft through the unchanged
-- SetTeam and closes with the altars' activation. Closing with an undeployed draft asks Deploy or Discard. The Sidekicks
-- tab equips a Sidekick on a member at once (SidekickEquip). The server decides every figure; the client only displays.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CharacterCatalog = require(shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local HudFormat = require(shared:WaitForChild("HudFormat"))
local RaceConfig = require(shared:WaitForChild("RaceConfig"))
local SeriesCatalog = require(shared:WaitForChild("SeriesCatalog"))
local SidekickConfig = require(shared:WaitForChild("SidekickConfig"))
local SpawnArea = require(shared:WaitForChild("SpawnArea"))
local StaminaConfig = require(shared:WaitForChild("StaminaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local Components = require(script.Parent.RollToast.Ui:WaitForChild("RacerComponents"))
local DojoScroll = require(script.Parent:WaitForChild("DojoScroll"))
local PanelSwitch = require(script.Parent:WaitForChild("PanelSwitch"))
local RosterCard = require(script.Parent:WaitForChild("RosterCard"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local SlotPicker = require(script.Parent:WaitForChild("SlotPicker"))
local TouchTarget = require(script.Parent:WaitForChild("TouchTarget"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))
local UiTooltip = require(script.Parent:WaitForChild("UiTooltip"))

local D = UiTheme.Dojo
local K = UiTheme.Scroll
local SLOTS = 3
local SIZE = StaminaConfig.TEAM_SIZE
-- Altar tiers in studs (bottom up) as the plaza Team altar; the viewport frames them. Proposed.
local SLAB_W, SLAB_H = 12, 1.6 -- the Sakura altar slab (SpawnArea.SakuraAltar), as the plaza Team altar
local FLY = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CARD_W, CARD_H = 100, 130 -- roster paper cards, design units
local DESIGN_H = 720 -- the full-screen page is laid out in units of a 720-tall screen (owner 2026-11-17 mockup)
local MIN_TEXT = 11 -- px: the smallest paper text at any screen (a phone's 390 px height would scale it to ~6 px)
local KANJI = { "一", "二", "三" } -- decoration only (4.45); every label stays English
local READY = D.Ready -- the ledger's "Ready" green on paper (T2)
local WARN = D.Warn -- "Unsaved changes" on paper
local CARD = D.Card -- a roster paper card
local ART_TOP, ART_BOTTOM = D.ArtTop, D.ArtBottom -- behind a drawn portrait
local BACKDROP = "rbxassetid://119528763151983" -- the approved blossom-shrine clean plate (assets/ui/summon_shrine)
local BACKDROP_SHIFT = 170 -- units: the stage view shifts right beside the ledger (T2; an offset, no new art)
-- The ledger scroll in units (DojoScroll design px = units): its top-left, size and bottom mount (Quick Setup, Deploy).
local LX, LY, LW, LH, CHI = 20, 4, 300, 704, 92

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props or {} do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.TextScaled = props.TextScaled ~= false
	return make("TextLabel", name, parent, props)
end
local function edge(gui, color, thickness, transparency)
	local s = gui:FindFirstChild("Edge") or make("UIStroke", "Edge", gui, {})
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color, s.Thickness, s.Transparency = color, thickness, transparency or 0
	return s
end
local function round(gui)
	local c = gui:FindFirstChildOfClass("UICorner") or make("UICorner", "Round", gui, {})
	c.CornerRadius = UDim.new(0.5, 0)
end
local function gradient(gui, top, bottom, rotation)
	local g = gui:FindFirstChild("Shade") or make("UIGradient", "Shade", gui, {})
	g.Color, g.Rotation = ColorSequence.new(top, bottom), rotation or 90
	return g
end
-- Lacquer button on the scroll's bottom mount (Quick Setup) or the vermilion one (Deploy), as T2's chi buttons. The
-- gradient would tint the button's own text, so its words show in a Label child (the button keeps its Text, hidden).
local function lacquer(button, primary)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.TextTransparency = 1
	make("TextLabel", "Label", button, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = button.Text,
		TextColor3 = K.SealText,
		FontFace = K.Heading,
		TextScaled = true,
		ZIndex = button.ZIndex + 1,
	})
	UiTheme.Corner(button, 5)
	if primary then
		gradient(button, D.DeployTop, D.DeployBottom)
		edge(button, D.DeployRim, 2)
	else
		gradient(button, K.Lacquer, K.LacquerDark)
		edge(button, K.Accent, 2)
	end
	return button
end
-- A round numbered seal (T2 altars and ledger rows): paper disc, vermilion ring and kanji. `object`'s own Text stays.
local function numSeal(object, n)
	object.BackgroundColor3, object.BackgroundTransparency, object.BorderSizePixel = K.Paper, 0, 0
	if object:IsA("TextLabel") then
		object.TextTransparency, object.TextStrokeTransparency = 1, 1
	end
	round(object)
	edge(object, K.Accent, 2)
	return DojoScroll.Text("Kanji", object, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = KANJI[n],
		TextColor3 = K.Accent,
		Font = Enum.Font.GothamBold, -- CJK through Roblox's font fallback; decoration only (4.45)
		ZIndex = object.ZIndex + 1,
	})
end

local function hoverable(button)
	local scale = button:FindFirstChild("HoverScale") or make("UIScale", "HoverScale", button, {})
	button.MouseEnter:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		UiMotion.Create(scale, HOVER, { Scale = 1 }):Play()
	end)
end

local root = make("ScreenGui", "RacerTeam", player:WaitForChild("PlayerGui"), {
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2, -- the panels' order (Backpack, Checkpoints)
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
-- Full screen (owner 2026-11-17, from the mockup): the dojo scene behind everything.
local panel = make("Frame", "Panel", root, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = D.Ink,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
})

-- The ledger scroll (T2): its paper's words are page controls laid over it (they keep their names and parents).
local scroll = DojoScroll.new(panel, { Name = "Ledger", Px = Vector2.new(LW, LH), Chi = CHI, ZIndex = 2 })

local header = make("Frame", "Header", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
-- The title's words stay for the page's name; the baked brush wordmark "Team" shows instead (assets/ui/hanging_scroll).
local title = caption("Title", header, {
	Text = "TEAM SETUP",
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	ZIndex = 6,
})
DojoScroll.Wordmark("Wordmark", title, "Team", { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
local kanjiTitle = caption("Kanji", header, {
	Text = "編\n成",
	TextColor3 = K.Accent,
	Font = Enum.Font.GothamBold, -- CJK through Roblox's font fallback; decoration only (4.45)
	LineHeight = 0.95,
	ZIndex = 6,
})
local close =
	make("TextButton", "Close", header, { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, ZIndex = 6 })
DojoScroll.Knot(close)
close.Glyph:Destroy() -- the kit's cross; this page's X label below carries it
local closeX = caption("X", close, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.5),
	Text = "X",
	TextColor3 = K.SealText,
	FontFace = K.BodyBold,
	ZIndex = 7,
})
-- Team Bonus with its View link (opens the popover).
local bonusButton =
	make("TextButton", "BonusButton", header, { Text = "View", TextColor3 = K.Ink, Selectable = true, ZIndex = 6 })
DojoScroll.Link(bonusButton, "View")
local bonusLabel = caption("BonusLabel", header, {
	Text = "Team Bonus",
	TextColor3 = K.Ink,
	FontFace = K.Heading,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 6,
})
local brushes =
	{ DojoScroll.Brush("Brush1", header, { ZIndex = 6 }), DojoScroll.Brush("Brush2", header, { ZIndex = 6 }) }

-- Units of a 720-tall screen (k px each); W is the screen's width in units. The roles size text as the panels do.
local ROLE = { Title = 44, Section = 32, Item = 24, Body = 19, Caption = 15, Footer = 16 }
local g = { k = 1, W = 1280, Small = false }
function g.px(u)
	return math.floor(u * g.k + 0.5)
end
function g.at(x, y)
	return UDim2.fromOffset(g.px(x), g.px(y))
end
function g.Place(gui, x, y, w, h)
	gui.AnchorPoint = Vector2.zero
	gui.Position, gui.Size = g.at(x, y), g.at(w, h)
end
function g.Role(label, role)
	local size = ROLE[role] or ROLE.Body
	label:SetAttribute("AnimeRole", role)
	label.Font = UiTheme.Font
	label.TextScaled = true
	label.TextColor3 = D.Cream -- callers recolour after
	local limit = label:FindFirstChild("RoleLimit") or make("UITextSizeConstraint", "RoleLimit", label, {})
	limit.MaxTextSize = math.max(1, g.px(size))
	limit.MinTextSize = math.max(1, math.min(g.px(size), g.px(9)))
	local stroke = label:FindFirstChild("RoleStroke")
		or make("UIStroke", "RoleStroke", label, { ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	stroke.Color = D.Ink
	stroke.Thickness = (role == "Title" or role == "Item") and 2 or 1
	stroke.Transparency = role == "Caption" and 1 or 0.15
	return label
end
-- Ink on paper: the role's size in the kit's font and colour, no outline, never under MIN_TEXT px (phones).
function g.Ink(label, role, face, color)
	g.Role(label, role)
	label.FontFace, label.TextColor3 = face or K.Body, color or K.Ink
	label.RoleStroke.Transparency = 1
	local limit = label.RoleLimit
	limit.MaxTextSize = math.max(MIN_TEXT, limit.MaxTextSize)
	limit.MinTextSize = MIN_TEXT
	return label
end

-- State: the draft (slot -> id or nil), the picked altar, the picked card (character id or Sidekick entry).
local draft = {}
local selected = nil
local chosen = nil
local chosenSidekick = nil
local tab = "Characters"
local busy = false
local render -- set below
local figureOn -- set below

local function saved()
	local out = {}
	for i, id in SlotPicker.Team() do
		out[i] = id ~= "" and id or nil
	end
	return out
end
local function list(t)
	local out = {}
	for i = 1, SIZE do
		if t[i] then
			table.insert(out, t[i])
		end
	end
	return out
end
local function filled()
	return #list(draft)
end
-- Slot by slot: a gap the altars show (a member moved to slot 3) is a change too; Deploy closes it up.
local function differs(a, b)
	for i = 1, SIZE do
		if a[i] ~= b[i] then
			return true
		end
	end
	return false
end
local function dirty()
	return differs(draft, saved())
end
local base = {} -- the saved Team the open draft started from
-- The draft slot holding `id` (the draft may have gaps, so not table.find).
local function slotOf(id)
	for i = 1, SIZE do
		if draft[i] == id then
			return i
		end
	end
	return nil
end
local openCount = 0 -- each open; a delayed close of an earlier open does nothing

-- Backdrop: the approved blossom-shrine scene (as the summon page's), shifted right beside the ledger and darkened
-- toward the roster so text reads.
local backdrop = make("ImageLabel", "Backdrop", panel, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Image = BACKDROP,
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 0,
})
local shade = make("Frame", "Shade", backdrop, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = D.Ink,
	BorderSizePixel = 0,
	ZIndex = 0,
})
make("UIGradient", "Fade", shade, {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.25, 0.8),
		NumberSequenceKeypoint.new(0.62, 0.7),
		NumberSequenceKeypoint.new(1, 0.15),
	}),
})

-- The top-centre slot dots went with T2 (the ledger shows the slots); kept hidden, still following the draft.
local dots = make("Frame", "Dots", panel, { BackgroundTransparency = 1, Visible = false })
for n = 1, SLOTS do
	make("Frame", "Dot" .. n, dots, { BackgroundColor3 = D.Cyan })
end

-- The three altars: a ViewportFrame pedestal of stacked octagons (SpawnArea.Octagon, as the plaza's), the member
-- standing on it as its 3D model, a numbered seal over it (T2: instead of the SLOT label and the name line); an empty
-- one shows "+" and "Add Character".
local altarsFrame = make("Frame", "Altars", panel, { BackgroundTransparency = 1 })
local altars = {}
for n = 1, SLOTS do
	local b = make("TextButton", "Altar" .. n, altarsFrame, {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = true,
	})
	local view = make("ViewportFrame", "Pedestal", b, {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 150, 150),
		LightColor = Color3.fromRGB(255, 235, 220),
		LightDirection = Vector3.new(-0.6, -2, -1),
		ZIndex = 2,
	})
	local model = make("Model", "Altar", view)
	-- One slab with the sakura emblem (owner 2026-11-17), as the plaza Team altar.
	local altar = SpawnArea.SakuraAltar(model, CFrame.new(), SLAB_W, SLAB_H)
	local edges = altar.Rim
	local core = altar.Top
	local deck = SLAB_H + 0.1
	-- The light column over the slab (pink under a member, cyan over an empty altar), as the mockup.
	local column = make("Part", "Column", model, {
		Anchored = true,
		Size = Vector3.new(SLAB_W - 4, 9, SLAB_W - 4),
		CFrame = CFrame.new(0, deck + 4.5, 0),
		Material = Enum.Material.Neon,
		Color = D.Sakura,
		Transparency = 0.78,
		CastShadow = false,
	})
	local camera = make("Camera", "Camera", view, { FieldOfView = 30 })
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 8, 24), Vector3.new(0, 3.6, 0))
	view.CurrentCamera = camera
	local plus = caption("Plus", b, { Text = "+", TextColor3 = D.Cyan, ZIndex = 4 })
	local add = caption("Add", b, { Text = "Add Character", TextColor3 = D.Cream, ZIndex = 4 })
	local remove = make("TextButton", "Remove", b, { Text = "Remove", Visible = false, ZIndex = 6 })
	DojoScroll.Slip(remove)
	remove.AutoButtonColor = false
	-- The picked altar's seal glows cyan (a halo behind the seal).
	local glow = make("Frame", "SealGlow", b, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = D.Cyan,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	})
	round(glow)
	-- The seal: the SlotLabel keeps its words "SLOT n" (hidden) under the kanji.
	local seal = caption("SlotLabel", b, { Text = "SLOT " .. n, TextColor3 = K.Ink, ZIndex = 4 })
	numSeal(seal, n)
	-- Name line pieces from the 2026-11-17 layout: T2 moves them to the ledger; kept hidden for the fly-in's target.
	altars[n] = {
		Button = b,
		Edges = edges,
		Core = core,
		Column = column,
		View = view,
		Deck = deck,
		SlotLabel = seal,
		Glow = glow,
		Portrait = make("ImageLabel", "Portrait", b, { BackgroundTransparency = 1, Visible = false, ZIndex = 4 }),
		Name = caption("Name", b, { TextColor3 = D.Cream, Visible = false, ZIndex = 4 }),
		Info = caption("Info", b, { TextColor3 = D.Gold, Visible = false, ZIndex = 4 }),
		Plus = plus,
		Add = add,
		Remove = remove,
	}
end

-- The ledger rows (T2): seal, drawn portrait, name, rarity, cruise, relic and Sidekick; a tap picks that slot.
local ledger =
	make("Frame", "LedgerRows", panel, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 })
local rows = {}
for n = 1, SLOTS do
	local r = make("TextButton", "Row" .. n, ledger, {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Selectable = true,
	})
	local pick = make("Frame", "Pick", r, {
		BackgroundColor3 = D.Cyan,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	UiTheme.Corner(pick, 4)
	make("Frame", "Bar", pick, { BackgroundColor3 = D.Cyan, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0) })
	local seal = make("Frame", "Seal", r, { ZIndex = 2 })
	numSeal(seal, n)
	local portrait = make("ImageLabel", "Portrait", r, {
		BackgroundColor3 = Color3.new(1, 1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 2,
	})
	gradient(portrait, ART_TOP, ART_BOTTOM)
	UiTheme.Corner(portrait, 4)
	edge(portrait, K.Accent, 1.5)
	rows[n] = {
		Button = r,
		Pick = pick,
		Seal = seal,
		Portrait = portrait,
		Name = caption("Name", r, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }),
		Rarity = caption("Rarity", r, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }),
		Cruise = caption("Cruise", r, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 }),
	}
end

-- Ledger header and bottom mount: Team 1 and its status, the count (Footer keeps its name and children), Quick Setup and
-- Deploy. The thin count bar went with T2 (kept hidden, still following the draft).
local footer = make("Frame", "Footer", panel, { BackgroundTransparency = 1, ZIndex = 6 })
local teamName = caption("TeamName", footer, { Text = "Team 1", TextXAlignment = Enum.TextXAlignment.Left })
local status = caption("Status", footer, { Text = "Ready", TextXAlignment = Enum.TextXAlignment.Left })
local count = caption("Count", footer, { Text = "", TextXAlignment = Enum.TextXAlignment.Right })
local progress = make("Frame", "Progress", footer, { BackgroundTransparency = 1, Visible = false })
local fill = make("Frame", "Fill", progress, { BackgroundColor3 = D.Cyan, BorderSizePixel = 0 })
local quick = lacquer(make("TextButton", "QuickSetup", panel, { Text = "Quick Setup", ZIndex = 6 }), false)
local deploy = lacquer(make("TextButton", "Deploy", panel, { Text = "Deploy", ZIndex = 6 }), true)

-- Roster handscroll (T2): rollers at both ends, a linen mount, paper; the Characters / Sidekicks tabs, Sort and Search
-- at its left end, one row of paper cards. The tray clips while it unrolls.
local tray = make("Frame", "Tray", panel, { BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3 })
local mount = make("Frame", "Mount", tray, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
gradient(mount, K.Mount, K.MountDark)
local paperStrip = make("Frame", "Paper", tray, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
gradient(paperStrip, K.Paper, K.PaperShade)
edge(paperStrip, K.RuleBottom, 2, 0.2)
local rollers = {}
for i, name in { "LeftRoller", "RightRoller" } do
	local rod = make("Frame", name, tray, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4 })
	gradient(rod, K.RodTop, K.RodBottom, 0)
	UiTheme.Corner(rod, 4)
	for _, cap in { "CapTop", "CapBottom" } do
		local c = make("Frame", cap, rod, { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 })
		gradient(c, K.CapLight, K.CapDark, 45)
		UiTheme.Corner(c, 4)
	end
	rollers[i] = rod
end
local tabs = make("Frame", "Tabs", tray, { BackgroundTransparency = 1, ZIndex = 5 })
local tabButtons = {}
for i, name in { "Characters", "Sidekicks" } do
	local t = make("TextButton", name, tabs, {
		Text = name,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = K.Paper,
		ZIndex = 5,
	})
	UiTheme.Corner(t, 4)
	-- The shown tab's vermilion top line (T2).
	make("Frame", "Underline", t, {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = K.Accent,
		BorderSizePixel = 0,
		ZIndex = 6,
	})
	tabButtons[i] = t
end
local sortMode = RosterCard.Sorts[1]
local sortButton = make("TextButton", "Sort", tray, {
	Text = "Sort: " .. sortMode,
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
local search = make("TextBox", "Search", tray, {
	ClearTextOnFocus = false,
	PlaceholderText = "Search",
	PlaceholderColor3 = K.Muted,
	Text = "",
	TextColor3 = K.Ink,
	FontFace = K.Body,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 5,
})
DojoScroll.Slip(search)
make("UIPadding", "Pad", search, { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
local roster = make("ScrollingFrame", "Roster", tray, {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = K.Ink,
	HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	ZIndex = 5,
})
local rosterLayout = make("UIListLayout", "Layout", roster, {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
})

-- Popovers on paper slips: the team bonus, and the unsaved-draft question.
local popover = make("Frame", "BonusPopover", panel, { Visible = false, ZIndex = 20 })
DojoScroll.Slip(popover)
local bonusName = caption("Name", popover, { ZIndex = 21 })
local bonusEffect = caption("Effect", popover, { ZIndex = 21, TextWrapped = true })
local bonusTotal = caption("Total", popover, { ZIndex = 21 })
-- While the question shows, a see-through blocker under it takes every tap on the page behind.
local confirmBlocker = make("Frame", "ConfirmBlocker", panel, {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Active = true,
	Visible = false,
	ZIndex = 29,
})
local confirm = make("Frame", "ConfirmClose", panel, { Visible = false, ZIndex = 30 })
confirm:GetPropertyChangedSignal("Visible"):Connect(function()
	confirmBlocker.Visible = confirm.Visible
end)
DojoScroll.Slip(confirm)
local confirmText = caption("Question", confirm, { Text = "Deploy your changes?", ZIndex = 31 })
local confirmDeploy = lacquer(make("TextButton", "Deploy", confirm, { Text = "Deploy", ZIndex = 31 }), true)
local confirmDiscard = lacquer(make("TextButton", "Discard", confirm, { Text = "Discard", ZIndex = 31 }), false)

for _, b in { quick, deploy, sortButton, confirmDeploy, confirmDiscard, table.unpack(tabButtons) } do
	hoverable(b)
end

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or READY
end

-- The page's parts that ink in with the scroll, and the ones that rise or fade in after it (4.45 motion).
local scrollItems =
	{ title, kanjiTitle, footer, ledger, bonusLabel, bonusButton, brushes[1], brushes[2], quick, deploy }
local stageItems = { close }
for _, a in altars do
	table.insert(stageItems, a.SlotLabel)
end
local trayItems = { tabs, sortButton, search }

-- Full-screen layout in units of a 720-tall screen: the ledger scroll on the left, the altars beside it, the roster
-- handscroll along the bottom right of the ledger, Close top right (T2).
local trayFull = UDim2.new() -- the tray's unrolled size (the open animation grows it to this)
local function layout()
	local size = panel.AbsoluteSize
	if size.Y <= 0 then
		return
	end
	g.k = size.Y / DESIGN_H
	g.W = size.X / g.k
	g.Small = size.Y < 500
	local W = g.W
	local M = DojoScroll.MARGIN
	backdrop.Position, backdrop.Size = UDim2.new(), UDim2.new(1, g.px(2 * BACKDROP_SHIFT), 1, 0)
	-- Ledger scroll; paper x LX+15 .. LX+LW-15, y LY+101 .. LY+LH-21-CHI-8 (DojoScroll PARTS).
	scroll.Root.Size = g.at(LW + 2 * M.X, LH + 2 * M.Y)
	scroll.SetHome(g.at(LX - M.X, LY - M.Y))
	local x0, x1 = LX + 28, LX + LW - 28 -- the paper's writing width
	g.Place(title, x0, LY + 108, 127, 62)
	g.Place(kanjiTitle, x1 - 26, LY + 106, 28, 66)
	g.Place(footer, 0, 0, W, DESIGN_H)
	g.Place(teamName, x0, LY + 184, 74, 26)
	g.Ink(teamName, "Item", K.Heading)
	g.Place(status, x0 + 78, LY + 186, 120, 22)
	local statusColor = status.TextColor3
	g.Ink(status, "Body", K.BodyBold, statusColor)
	g.Place(count, x1 - 60, LY + 186, 60, 22)
	g.Ink(count, "Body", K.BodyBold)
	g.Place(brushes[1], x0, LY + 220, x1 - x0, 3)
	local rowY, rowH = LY + 232, 74
	for n, r in rows do
		g.Place(r.Button, LX + 18, rowY + (n - 1) * (rowH + 4), LW - 40, rowH)
		r.Pick.Bar.Size = UDim2.new(0, g.px(4), 1, 0)
		g.Place(r.Seal, 8, rowH / 2 - 15, 30, 30)
		g.Place(r.Portrait, 46, rowH / 2 - 27, 54, 54)
		g.Place(r.Name, 108, 6, 92, 24)
		g.Ink(r.Name, "Item", K.Heading)
		g.Place(r.Rarity, 108, 31, 92, 18)
		g.Ink(r.Rarity, "Caption", K.BodyBold)
		g.Place(r.Cruise, 108, 50, 92, 18)
		g.Ink(r.Cruise, "Caption")
		r.GearY, r.GearSize = g.px(rowH / 2 - 13), g.px(26)
	end
	local after = rowY + SLOTS * (rowH + 4)
	g.Place(brushes[2], x0, after + 6, x1 - x0, 3)
	g.Place(bonusLabel, x0, after + 20, 150, 26)
	g.Ink(bonusLabel, "Item", K.Heading)
	g.Place(bonusButton, x1 - 46, after + 20, 46, 28)
	g.Ink(bonusButton.LinkLabel, "Body", K.BodyBold)
	-- Bottom mount (chi): Quick Setup and Deploy.
	local chiY = LY + LH - 21 - CHI
	g.Place(quick, LX + 22, chiY + 16, 112, 62)
	g.Ink(quick.Label, "Body", K.Heading, K.SealText)
	g.Place(deploy, LX + 142, chiY + 12, LW - 164, 70)
	g.Ink(deploy.Label, "Section", K.Heading, K.SealText)
	-- Close knot, top right.
	g.Place(close, W - 70, 16, 52, 52)
	g.Ink(closeX, "Item", K.BodyBold, K.SealText)
	-- Altars, right of the ledger.
	local left = LX + LW + 30
	local top, altarsH = 56, 440
	local spacing = math.min((W - left) / 3, 420)
	local aw = math.min(spacing * 0.84, 320)
	g.Place(altarsFrame, 0, top, W, altarsH)
	for n, a in altars do
		local cx = left + (n - 0.5) * spacing
		g.Place(a.Button, cx - aw / 2, 0, aw, altarsH)
		g.Place(a.SlotLabel, aw / 2 - 24, 64, 48, 48)
		a.Glow.Position, a.Glow.Size = g.at(aw / 2, 88), g.at(66, 66)
		g.Place(a.Portrait, aw / 2 - 30, 200, 60, 60) -- the fly-in lands here, on the figure
		g.Place(a.Add, 0, 290, aw, 30)
		g.Role(a.Add, "Item").TextColor3 = D.Cream
		g.Place(a.View, 0, 96, aw, altarsH - 96)
		g.Place(a.Plus, aw / 2 - 60, 160, 120, 120)
		g.Role(a.Plus, "Title").TextColor3 = D.Cyan
		a.Plus:FindFirstChild("RoleLimit").MaxTextSize = g.px(120)
		-- The icons sit at the figure's top-right, right of the seal (clear of it at 4:3); Remove under them.
		a.GearPos = g.at(math.min(aw / 2 + 30 + 2 * 24 + 6, aw), 104)
		a.GearSize = g.px(24)
		g.Place(a.Remove, aw - 104, 140, 96, 30)
		g.Ink(a.Remove, "Caption", K.BodyBold, K.Accent)
	end
	-- Roster handscroll along the bottom, right of the ledger.
	local tx, ty = LX + LW + 24, 512
	local tw, th = W - tx - 12, DESIGN_H - ty - 8
	g.Place(tray, tx, ty, tw, th)
	trayFull = tray.Size
	for i, rod in rollers do
		rod.AnchorPoint = Vector2.new(i - 1, 0)
		rod.Position = UDim2.new(i - 1, g.px(i == 1 and 3 or -3), 0, g.px(6))
		rod.Size = UDim2.new(0, g.px(14), 1, -g.px(12))
		for j, cap in { rod.CapTop, rod.CapBottom } do
			cap.AnchorPoint = Vector2.new(0.5, j - 1)
			cap.Position = UDim2.new(0.5, 0, j - 1, g.px(j == 1 and -6 or 6))
			cap.Size = g.at(20, 9)
		end
	end
	mount.Position, mount.Size = g.at(10, 14), UDim2.new(1, -g.px(20), 1, -g.px(28))
	paperStrip.Position, paperStrip.Size = g.at(14, 24), UDim2.new(1, -g.px(28), 1, -g.px(48))
	tabs.Position, tabs.Size = g.at(32, 34), g.at(120, 80)
	for i, t in tabButtons do
		t.Position, t.Size = g.at(0, (i - 1) * 42), g.at(120, 36)
		g.Ink(t, "Body", K.BodyBold)
	end
	g.Place(sortButton, 34, 118, 118, 20)
	g.Ink(sortButton, "Caption", K.Body, K.Muted)
	g.Place(search, 32, 140, 120, 22)
	g.Ink(search, "Caption")
	g.Place(roster, 164, 28, tw - 164 - 30, th - 56)
	rosterLayout.Padding = UDim.new(0, g.px(12))
	-- Popovers: the bonus beside its View link; the question over the stage.
	g.Place(popover, x1 + 30, after - 60, 270, 120)
	g.Place(bonusName, 12, 10, 246, 26)
	g.Ink(bonusName, "Body", K.Heading, K.Accent)
	g.Place(bonusEffect, 12, 40, 246, 42)
	g.Ink(bonusEffect, "Body")
	g.Place(bonusTotal, 12, 88, 246, 22)
	g.Ink(bonusTotal, "Body", K.BodyBold)
	g.Place(confirm, left + (W - left) / 2 - 200, 220, 400, 150)
	g.Place(confirmText, 20, 18, 360, 40)
	g.Ink(confirmText, "Item", K.Heading)
	g.Place(confirmDeploy, 36, 84, 150, 48)
	g.Ink(confirmDeploy.Label, "Body", K.Heading, K.SealText)
	g.Place(confirmDiscard, 214, 84, 150, 48)
	g.Ink(confirmDiscard.Label, "Body", K.Heading, K.SealText)
	if panel.Visible then
		task.defer(render)
	end
end

local function drawBonus()
	local kind, seriesId = string.match(player:GetAttribute("TeamBonus") or "", "^(%a+):(.+)$")
	local series = seriesId and SeriesCatalog.Get(seriesId)
	local function percent(multi)
		return math.floor((multi - 1) * 100 + 0.5)
	end
	if series and kind == "Preset" then
		bonusName.Text = "★ " .. string.upper(series.Preset.Name)
		bonusEffect.Text = string.format(
			"+%d%% STAMINA, +%d%% SPEED",
			percent(StaminaConfig.TEAM_BONUS.Preset),
			percent(RaceConfig.PRESET_CRUISE)
		)
	elseif series and kind == "Series" then
		bonusName.Text = string.upper(series.Name)
		bonusEffect.Text = string.format("+%d%% STAMINA", percent(StaminaConfig.TEAM_BONUS.Series))
	else
		bonusName.Text = "No team bonus"
		bonusEffect.Text = string.format("3 of one series: +%d%% stamina", percent(StaminaConfig.TEAM_BONUS.Series))
	end
	local total = 0
	for n, id in saved() do
		local spec = CharacterCatalog.Get(id)
		local seconds = tonumber(player:GetAttribute("TeamStamina" .. n)) or (spec and StaminaConfig.Seconds(spec)) or 0
		total += math.round(seconds * 10) / 10
	end
	bonusTotal.Text = string.format("Total %.1f s", total)
end

-- Puts character `id` on draft slot `slot` (nil: takes it off); a member on another slot swaps there.
local function place(slot, id)
	if id then
		for i = 1, SIZE do
			if draft[i] == id then
				draft[i] = draft[slot]
			end
		end
	end
	draft[slot] = id
end

-- The portrait flies from a roster card onto its altar's figure, then the altar's edges pulse (4.45 placement).
local GuiService = game:GetService("GuiService")
-- Where a card's art is now (read before a render redraws the roster).
local function artSnapshot(card)
	local art = card and card:FindFirstChild("Art")
	if not (art and art:IsA("ImageLabel") and art.Image ~= "") then
		return nil
	end
	return { Image = art.Image, Position = art.AbsolutePosition, Size = art.AbsoluteSize }
end
local function landed(slot)
	UiMotion.Pop(altars[slot].SlotLabel, 0.12)
	UiMotion.Pop(rows[slot].Portrait, 0.08)
end
local function flyIn(from, slot)
	local a = altars[slot]
	if not from or UiMotion.Reduced() then
		landed(slot)
		return
	end
	local inset = GuiService:GetGuiInset().Y -- RacerTeam ignores the inset; AbsolutePosition does not
	local ghost = make("ImageLabel", "Fly", root, {
		BackgroundTransparency = 1,
		Image = from.Image,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(from.Position.X, from.Position.Y + inset),
		Size = UDim2.fromOffset(from.Size.X, from.Size.Y),
		ZIndex = 50,
	})
	local target = a.Portrait
	local t = UiMotion.Create(ghost, FLY, {
		Position = UDim2.fromOffset(target.AbsolutePosition.X, target.AbsolutePosition.Y + inset),
		Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y),
		ImageTransparency = 0.6,
	})
	t.Completed:Connect(function()
		ghost:Destroy()
		landed(slot)
	end)
	t:Play()
end

-- An altar's edge colour: bright cyan while selected, else cyan.
local function paintEdges(slot)
	local a = altars[slot]
	for _, part in a.Edges do
		part.Color = selected == slot and D.Cyan:Lerp(Color3.new(1, 1, 1), 0.45) or D.Cyan
	end
end

local function pulseEdges(slot, delay)
	task.delay(delay or 0, function()
		for _, part in altars[slot].Edges do
			part.Color = D.Sakura
		end
		task.delay(0.3, function()
			paintEdges(slot)
		end)
	end)
end

local function selectSlot(slot)
	selected = slot
	if chosen and slot then
		local from = artSnapshot(roster:FindFirstChild(chosen))
		local here = draft[slot] == chosen
		place(slot, not here and chosen or nil)
		chosen, selected = nil, nil -- placed: the next tap on this altar selects it again
		render()
		if not here then
			flyIn(from, slot)
			pulseEdges(slot, 0.35)
			UiFeedback.Play("Equip", altars[slot].Button)
		end
		return
	end
	if chosenSidekick and slot and draft[slot] then
		-- Sidekicks tab: equip on that member at once (SidekickEquip; not part of the draft).
		local entry = chosenSidekick
		chosenSidekick = nil
		local ok, done, message = pcall(function()
			return remotes:WaitForChild("SidekickEquip"):InvokeServer(draft[slot], entry)
		end)
		setStatus(
			ok and done and "Sidekick equipped" or tostring(ok and message or "Connection error"),
			not (ok and done) and K.Accent or nil
		)
		UiFeedback.Play((ok and done) and "Equip" or "Denied", altars[slot].Button)
	end
	render()
end

local function deployDraft(thenClose)
	if busy then
		return
	end
	local team = list(draft)
	if #team == 0 then
		setStatus("Your Team needs at least 1 character", K.Accent)
		UiFeedback.Play("Denied", deploy)
		return
	end
	busy = true
	local ok, done, message = pcall(function()
		return remotes:WaitForChild("SetTeam"):InvokeServer(team)
	end)
	busy = false
	if not (ok and done) then
		setStatus(ok and tostring(message or "Try again") or "Connection error", K.Accent)
		UiFeedback.Play("Denied", deploy)
		confirm.Visible = false
		return
	end
	-- Saved: the three altars fire together (cyan then sakura), then the page closes.
	UiFeedback.Play("Equip", deploy)
	for n = 1, SLOTS do
		pulseEdges(n, (n - 1) * 0.08)
		if draft[n] then
			task.delay((n - 1) * 0.08, function()
				landed(n)
			end)
		end
	end
	-- The draft is now what the server saved (gaps closed up), so the Team change that follows is not "unsaved"
	draft, base = table.clone(team), table.clone(team)
	confirm.Visible = false
	setStatus("Deployed")
	if thenClose ~= false then
		local this = openCount
		task.delay(UiMotion.Reduced() and 0 or 0.8, function()
			if openCount == this and panel.Visible then
				PanelSwitch.ForceClose("Team")
			end
		end)
	end
end

local function applySearch()
	local query = string.lower(search.Text)
	for _, card in roster:GetChildren() do
		if card:IsA("GuiButton") then
			card.Visible = query == ""
				or string.find(string.lower(card:GetAttribute("SearchName") or ""), query, 1, true) ~= nil
		end
	end
end

-- Marks, strokes and seals follow the draft in place; the cards are rebuilt only when what they list changes.
local rosterKey = nil
local gearKey = nil -- the gear the Characters cards show; a change redraws their icons in place
local views = nil -- RosterCard.Views for the render under way (four JSON decodes, once)
local function markRoster()
	for _, card in roster:GetChildren() do
		if not card:IsA("GuiButton") then
			continue
		end
		local stroke = card.Stroke
		if tab == "Characters" then
			local slot = slotOf(card.Name)
			-- The Badge keeps the words "TEAM n" (green) for the code that reads it; the slot seal shows the number.
			card.Badge.Text = slot and ("TEAM " .. slot) or ""
			card.SlotSeal.Visible = slot ~= nil
			card.SlotSeal.Number.Text = slot and tostring(slot) or ""
			local on = card.Name == chosen
			stroke.Color, stroke.Thickness, stroke.Transparency = on and D.Cyan or K.Ink, on and 3 or 1, on and 0 or 0.8
		else
			local spec = SidekickConfig.Get(card:GetAttribute("SidekickId"))
			stroke.Color = card.Name == chosenSidekick and D.Cyan or SidekickView.RarityColor(spec and spec.Rarity)
		end
	end
end
local function ownedKey()
	local data = player:FindFirstChild("GachaData")
	local ids = {}
	for _, entry in data and data:GetChildren() or {} do
		table.insert(ids, entry.Name)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end
-- A paper card (T2): drawn portrait, name, rarity and its colour strip, the team-slot seal, relic and Sidekick icons.
local function paperCard(name, order, size)
	local card = make("TextButton", name, roster, {
		LayoutOrder = order,
		Size = size,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CARD,
		BorderSizePixel = 0,
	})
	UiTheme.Corner(card, 4)
	make(
		"UIStroke",
		"Stroke",
		card,
		{ ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = K.Ink, Transparency = 0.8 }
	)
	return card
end
local function cardText(card, name, y, h, text, face, color, role)
	return g.Ink(
		caption(name, card, {
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, h),
			Text = text,
			ZIndex = 5,
		}),
		role or "Caption",
		face,
		color
	)
end
local function rarityStrip(card, color)
	make("Frame", "RarityStrip", card, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, g.px(4)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 5,
	})
end
local function drawRoster()
	-- Gear lives on the Characters cards (updated in place below); the Sidekicks cards list the bag and who wears what.
	local key = table.concat({
		tab,
		sortMode,
		tostring(g.k),
		ownedKey(),
		tab == "Sidekicks" and (player:GetAttribute("SidekickBag") or "") or "",
		tab == "Sidekicks" and (player:GetAttribute("SidekickGear") or "") or "",
	}, "|")
	local worn = table.concat({
		player:GetAttribute("SidekickBag") or "",
		player:GetAttribute("SidekickGear") or "",
		player:GetAttribute("RelicBag") or "",
		player:GetAttribute("RelicGear") or "",
	}, "|")
	if key == rosterKey then
		if tab == "Characters" and worn ~= gearKey then
			gearKey = worn
			for _, card in roster:GetChildren() do
				if card:IsA("GuiButton") then
					RosterCard.Gear(card, card.Name, player, g.px(5), g.px(18), views)
				end
			end
		end
		markRoster()
		return
	end
	rosterKey, gearKey = key, worn
	for _, child in roster:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local size = UDim2.fromOffset(g.px(CARD_W), g.px(CARD_H))
	if tab == "Characters" then
		for order, spec in RosterCard.Owned(player, sortMode, true) do
			local card = paperCard(spec.Id, order, size)
			card:SetAttribute("SearchName", spec.Name)
			local art = make("ImageLabel", "Art", card, {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Image = Components.PortraitImage(spec) or "",
				ScaleType = Enum.ScaleType.Crop,
				Size = UDim2.fromScale(1, 0.7),
				ZIndex = 2,
			})
			gradient(art, ART_TOP, ART_BOTTOM)
			UiTheme.Corner(art, 4)
			cardText(card, "Name", 0.71, 0.13, spec.Name, K.BodyBold, K.Ink)
			local rarityColor = GachaConfig.RARITY_COLORS[spec.Rarity] or K.Muted
			cardText(card, "Rarity", 0.84, 0.1, spec.Rarity, K.Body, K.Muted)
			rarityStrip(card, rarityColor)
			caption("Badge", card, { Text = "", TextTransparency = 1, TextColor3 = UiTheme.Palette.Money, ZIndex = 5 })
			local seal = make("Frame", "SlotSeal", card, {
				Position = g.at(5, 5),
				Size = g.at(20, 20),
				Rotation = -6,
				BackgroundColor3 = K.Accent,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 6,
			})
			UiTheme.Corner(seal, 3)
			DojoScroll.Text("Number", seal, {
				Size = UDim2.fromScale(1, 1),
				TextColor3 = K.SealText,
				FontFace = K.BodyBold,
				ZIndex = 7,
			})
			RosterCard.Gear(card, spec.Id, player, g.px(5), g.px(18), views)
			card.Activated:Connect(function()
				chosenSidekick = nil
				if selected then
					chosen = spec.Id
					selectSlot(selected)
					return
				end
				chosen = chosen ~= spec.Id and spec.Id or nil
				render()
				local picked = roster:FindFirstChild(spec.Id)
				if picked then
					UiMotion.Pop(picked, 0.06)
				end
			end)
		end
	else
		local gear = SidekickView.Gear(player)
		local wearer = {}
		for id, entry in gear do
			wearer[entry] = id
		end
		-- Highest rarity first, then bag order (Sort's Speed / Stamina are character stats; a Sidekick sorts by rarity).
		local bag = SidekickView.Bag(player)
		local rank = {}
		for i, row in bag do
			local spec = SidekickConfig.Get(row.Id)
			rank[row] = { table.find(GachaConfig.RARITY_ORDER, spec and spec.Rarity) or 0, i }
		end
		table.sort(bag, function(a, b)
			if rank[a][1] ~= rank[b][1] then
				return rank[a][1] > rank[b][1]
			end
			return rank[a][2] < rank[b][2]
		end)
		for order, row in bag do
			local spec = SidekickConfig.Get(row.Id)
			local card = paperCard(row.Entry, order, size)
			card:SetAttribute("SidekickId", row.Id)
			card:SetAttribute("SearchName", spec and spec.Name or row.Id)
			card.Stroke.Transparency, card.Stroke.Thickness = 0, 2
			card.Stroke.Color = row.Entry == chosenSidekick and D.Cyan or SidekickView.RarityColor(spec and spec.Rarity)
			SidekickView.Art(card, spec, UDim2.fromScale(0.5, 0.36), UDim2.fromScale(0.8, 0.6))
			local who = wearer[row.Entry] and CharacterCatalog.Get(wearer[row.Entry])
			cardText(card, "Name", 0.71, 0.13, spec and spec.Name or row.Id, K.BodyBold, K.Ink)
			cardText(card, "Worn", 0.84, 0.1, who and ("on " .. who.Name) or "", K.Body, K.Accent)
			rarityStrip(card, SidekickView.RarityColor(spec and spec.Rarity))
			card.Activated:Connect(function()
				chosen = nil
				chosenSidekick = chosenSidekick ~= row.Entry and row.Entry or nil
				setStatus(
					chosenSidekick and "Tap a member to equip" or (dirty() and "Unsaved changes" or "Ready"),
					chosenSidekick and K.Ink or (dirty() and WARN or READY)
				)
				render()
			end)
		end
	end
	markRoster()
	applySearch()
end

function render()
	views = RosterCard.Views(player)
	for n, a in altars do
		local id = draft[n]
		local spec = id and CharacterCatalog.Get(id)
		local isSelected = selected == n
		a.Button:SetAttribute("Selected", isSelected)
		a.Plus.Visible, a.Add.Visible = spec == nil, spec == nil
		a.Remove.Visible = isSelected and spec ~= nil
		a.Glow.Visible = isSelected
		a.SlotLabel.Edge.Color = isSelected and D.Cyan or K.Accent
		a.SlotLabel.Edge.Thickness = isSelected and 3 or 2
		paintEdges(n)
		-- A failed build is not retried every render; CharacterModels.Ready clears it (and ShownId) to build again.
		if a.ShownId ~= id or (spec and not a.View:FindFirstChild("Figure") and a.FailedId ~= id) then
			figureOn(a, spec)
		end
		if spec then
			-- The hidden name line still names the member (the fly-in lands on it; T2 shows it in the ledger).
			a.Portrait.Image = Components.PortraitImage(spec) or ""
			a.Name.Text = spec.Name
			a.Info.Text = string.format("%s · %s", spec.Rarity, HudFormat.RateText(RaceConfig.Cruise(spec)))
			RosterCard.Gear(a.Button, id, player, 0, a.GearSize or g.px(22), views).Position = a.GearPos or UDim2.new()
		else
			local gearFrame = a.Button:FindFirstChild("Gear")
			if gearFrame then
				gearFrame:Destroy()
			end
		end
		a.ShownId = id
		-- Its ledger row.
		local r = rows[n]
		r.Button:SetAttribute("Selected", isSelected)
		r.Pick.Visible = isSelected
		r.Portrait.Image = spec and Components.PortraitImage(spec) or ""
		r.Name.Text = spec and spec.Name or "Add Character"
		r.Name.TextColor3 = spec and K.Ink or K.Muted
		r.Rarity.Text = spec and spec.Rarity or ""
		r.Rarity.TextColor3 = spec and (GachaConfig.RARITY_COLORS[spec.Rarity] or K.Muted) or K.Muted
		r.Cruise.Text = spec and HudFormat.RateText(RaceConfig.Cruise(spec)) or ""
		if spec then
			RosterCard.Gear(r.Button, id, player, r.GearY or 0, r.GearSize or g.px(26), views)
		else
			local gearFrame = r.Button:FindFirstChild("Gear")
			if gearFrame then
				gearFrame:Destroy()
			end
		end
	end
	local n = filled()
	for i = 1, SLOTS do
		dots["Dot" .. i].BackgroundTransparency = draft[i] and 0 or 0.7
	end
	count.Text = string.format("%d / %d", n, SLOTS)
	fill.Size = UDim2.fromScale(n / SLOTS, 1)
	local changed = dirty()
	-- An off button greys (its gradient off), never fades: DojoScroll.Ink owns the transparencies.
	for button, on in { [deploy] = changed and n > 0, [quick] = n < SLOTS } do
		button:SetAttribute("Enabled", on)
		button.Shade.Enabled = on
		button.BackgroundColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(128, 120, 118)
	end
	if status.Text == "Ready" or status.Text == "Unsaved changes" or status.Text == "Deployed" then
		setStatus(changed and "Unsaved changes" or "Ready", changed and WARN or READY)
	end
	for i, t in tabButtons do
		local active = (i == 1) == (tab == "Characters")
		t:SetAttribute("Active", active)
		t.Underline.Visible = active
		t.BackgroundColor3 = active and K.Paper or K.Mount:Lerp(K.Paper, 0.45)
		t.TextColor3 = active and K.Ink or K.Muted
	end
	drawBonus()
	drawRoster()
end

local function tapSlot(n)
	if selected == n and not chosen and not chosenSidekick then
		selected = nil -- a second tap lets go of it
		render()
		return
	end
	UiFeedback.Play("Toggle", altars[n].Button)
	selectSlot(n)
end
for n, a in altars do
	a.Button.Activated:Connect(function()
		tapSlot(n)
	end)
	rows[n].Button.Activated:Connect(function()
		tapSlot(n) -- a ledger row picks its slot as its altar does (T2)
	end)
	local function remove()
		place(n, nil)
		selected = nil
		render()
	end
	a.Remove.Activated:Connect(remove)
	TouchTarget.Add(a.Remove, remove) -- phones: a 44 px tap area (audit 2026-11-20)
end
altars[1].Button:SetAttribute("FirstFocus", true) -- a gamepad starts on the first altar, not on Close
quick.Activated:Connect(function()
	if busy or filled() >= SLOTS then
		return
	end
	busy = true
	local ok, done, ids = pcall(function()
		return remotes:WaitForChild("TeamQuickPick"):InvokeServer(list(draft))
	end)
	busy = false
	if not (ok and done and type(ids) == "table") then
		setStatus(ok and tostring(ids or "Try again") or "Connection error", K.Accent)
		UiFeedback.Play("Denied", quick)
		return
	end
	-- Keep each member on its altar; the new picks fill the empty altars left to right.
	local new = {}
	for _, id in ids do
		if not slotOf(id) then
			table.insert(new, id)
		end
	end
	local delay = 0
	for i = 1, SIZE do
		if not draft[i] and #new > 0 then
			draft[i] = table.remove(new, 1)
			pulseEdges(i, delay)
			local slot = i
			task.delay(delay, function()
				landed(slot)
			end)
			delay += 0.15
		end
	end
	selected, chosen = nil, nil
	UiFeedback.Play("Equip", quick)
	render()
end)
deploy.Activated:Connect(function()
	if deploy:GetAttribute("Enabled") then
		deployDraft(true)
	else
		UiFeedback.Play("Denied", deploy)
	end
end)
confirmDeploy.Activated:Connect(function()
	deployDraft(true)
end)
confirmDiscard.Activated:Connect(function()
	confirm.Visible = false
	draft = saved()
	PanelSwitch.ForceClose("Team")
end)
local function toggleBonus()
	popover.Visible = not popover.Visible
	if popover.Visible then
		drawBonus()
		UiMotion.Pop(popover, 0.04)
	end
end
bonusButton.Activated:Connect(toggleBonus)
TouchTarget.Add(bonusButton, toggleBonus)
local function setTab(i)
	tab = i == 1 and "Characters" or "Sidekicks"
	chosen, chosenSidekick = nil, nil
	render()
end
for i, t in tabButtons do
	t.Activated:Connect(function()
		setTab(i)
	end)
end
local function closePage()
	PanelSwitch.Close("Team")
end
close.Activated:Connect(closePage)
TouchTarget.Add(close, closePage)
sortButton.Activated:Connect(function()
	sortMode = RosterCard.Sorts[table.find(RosterCard.Sorts, sortMode) % #RosterCard.Sorts + 1]
	sortButton.Text = "Sort: " .. sortMode
	render()
end)
search:GetPropertyChangedSignal("Text"):Connect(applySearch)

-- An undeployed draft asks before the page closes (4.45).
PanelSwitch.SetCloseGuard("Team", function()
	if dirty() then
		confirm.Visible = true
		popover.Visible = false
		UiMotion.Pop(confirm, 0.04)
		if GuiService.SelectedObject then -- a gamepad moves onto the question
			GuiService.SelectedObject = confirmDeploy
		end
		return true
	end
	return false
end)
-- Back (gamepad B, Escape): the question or the bonus popover closes first, then the page (U6, audit 2026-11-20).
PanelSwitch.SetBack("Team", function()
	if confirm.Visible then
		confirm.Visible = false
		if GuiService.SelectedObject then
			GuiService.SelectedObject = deploy
		end
		return true
	end
	if popover.Visible then
		popover.Visible = false
		return true
	end
	return false
end)
-- L1 / R1 switch the roster's tabs while the page is open.
local TAB_ACTION = "TeamSetupTabs"
local function bumper(_, state, input)
	if state == Enum.UserInputState.Begin and not confirm.Visible then
		setTab(input.KeyCode == Enum.KeyCode.ButtonL1 and 1 or 2)
		UiFeedback.Play("TabSwitch")
	end
	return Enum.ContextActionResult.Sink
end

-- Open: the ledger drops and unrolls, its words ink in, the seals and Close fade in, the roster handscroll unrolls left
-- to right (4.45 motion; reduced effects: fades only). Close: the ledger rolls up and the rest fades, under the wash.
local trayTween = nil
local function openScroll()
	scroll.Open()
	DojoScroll.Ink(scrollItems, true, DojoScroll.INK_AT)
	DojoScroll.Ink(stageItems, true, 0.3)
	DojoScroll.Ink(trayItems, true, DojoScroll.INK_AT)
	if trayTween then
		trayTween:Cancel()
	end
	if UiMotion.Reduced() then
		tray.Size = trayFull
		return
	end
	tray.Size = UDim2.fromOffset(g.px(34), trayFull.Y.Offset)
	trayTween = UiMotion.Create(
		tray,
		TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.1),
		{ Size = trayFull }
	)
	trayTween:Play()
end
local function closeScroll()
	if not scroll.Opened() then
		return
	end
	scroll.Close()
	DojoScroll.Ink(scrollItems, false, 0, 0.12)
	DojoScroll.Ink(stageItems, false, 0, 0.2)
	DojoScroll.Ink(trayItems, false, 0, 0.2)
end
task.spawn(function()
	local wash = player:WaitForChild("PlayerGui"):WaitForChild("UiTransition")
	wash:GetAttributeChangedSignal("Playing"):Connect(function()
		if wash:GetAttribute("Playing") and panel.Visible then
			closeScroll()
		end
	end)
end)

panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		openCount += 1
		rosterKey = nil
		draft, selected, chosen, chosenSidekick = saved(), nil, nil, nil
		base = saved()
		tab = "Characters"
		confirm.Visible, popover.Visible = false, false
		setStatus("Ready")
		render()
		openScroll()
		ContextActionService:BindAction(TAB_ACTION, bumper, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	else
		ContextActionService:UnbindAction(TAB_ACTION)
		UiTooltip.Hide()
		confirm.Visible = false
	end
end)
player.AttributeChanged:Connect(function(attr)
	if
		panel.Visible
		and (
			attr == "Team"
			or attr == "TeamBonus"
			or attr == "SidekickGear"
			or attr == "SidekickBag"
			or attr == "RelicGear"
			or string.match(attr, "^TeamStamina%d$")
		)
	then
		if attr == "Team" then
			-- The saved Team changed under an open page (another device, a Deploy): an untouched draft follows it
			if not differs(draft, base) then
				draft = saved()
			end
			base = saved()
		end
		render()
	end
end)
task.spawn(function()
	local data = player:WaitForChild("GachaData")
	local function changed()
		if panel.Visible then
			render()
		end
	end
	data.ChildAdded:Connect(changed)
	data.ChildRemoved:Connect(changed)
	local models = ReplicatedStorage:WaitForChild("CharacterModels")
	if models:GetAttribute("Ready") ~= true then
		models:GetAttributeChangedSignal("Ready"):Wait()
	end
	-- The figures built before the models arrived are placeholders: build every altar's again.
	for _, a in altars do
		a.ShownId, a.FailedId = false, nil
	end
	changed()
end)

-- The 3D member standing on its altar (owner 2026-11-17: the mockup's models; an exception to the portrait rule for
-- Team Setup only), turned a little toward the camera, feet on the deck.
function figureOn(a, spec)
	local old = a.View:FindFirstChild("Figure")
	if old then
		old:Destroy()
	end
	a.Column.Color = spec and D.Sakura or D.Cyan
	if not spec then
		return
	end
	local ok, rig = pcall(function()
		return require(shared:WaitForChild("RunnerFactory")).build(spec.Id)
	end)
	if not ok or not rig then
		a.FailedId = spec.Id
		return
	end
	a.FailedId = nil
	rig.Name = "Figure"
	local label = rig:FindFirstChild("NameLabel")
	if label then
		label:Destroy()
	end
	rig:PivotTo(CFrame.Angles(0, math.pi - 0.3, 0))
	local box, extents = rig:GetBoundingBox()
	rig:PivotTo(rig:GetPivot() + Vector3.new(-box.X, a.Deck - (box.Y - extents.Y / 2), -box.Z))
	rig.Parent = a.View
end

panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
PanelSwitch.Register("Team", panel, D.Cyan)
layout()
