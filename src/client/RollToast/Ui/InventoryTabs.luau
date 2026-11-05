--!nonstrict
-- The Index header's tabs. Index is character discovery only (docs/HUD_LAYOUT_SPEC.md sections 1 and 3): consumables are
-- used from the Backpack's Misc tab, so the generated CONSUMABLES tab and its host are held hidden and stay empty.
-- ENEMIES (design doc 4.29) takes that tab's place: a copy, as generated code owns the original. SIDEKICKS (design doc 4.36) is
-- another copy, after ENEMIES.
local Tabs = {}
local Components = require(script.Parent.RacerComponents)
local UiFeedback = require(script.Parent.Parent.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent.Parent.Parent:WaitForChild("UiMotion"))
local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
local LIT = UiTheme.Palette.White -- not the bar's colour, so the active tab stands out
local IDLE = UiTheme.Palette.Row

-- The active tab's colour tweens (design doc 4.20): a white-to-grey gradient over a tweened fill, as a gradient's own
-- colours cannot tween.
local function markTab(button, active)
	Components.Tint(button, Color3.new(1, 1, 1))
	button.BackgroundColor3 = button:GetAttribute("TabLit") and LIT or IDLE
	button:SetAttribute("TabLit", active)
	UiMotion.Mark(button, { BackgroundColor3 = active and LIT or IDLE })
	local caption = button:FindFirstChildWhichIsA("TextLabel")
	if caption then
		caption.TextColor3 = active and UiTheme.Palette.PanelDeep or UiTheme.Palette.White
		local glyph = caption:FindFirstChildOfClass("UIStroke")
		if glyph then
			glyph.Enabled = not active
		end
	end
end

local function follow(from, to, property)
	from:GetPropertyChangedSignal(property):Connect(function()
		to[property] = from[property]
	end)
end

-- A copy of the retired tab named `name`, without hover (RacerMotion gives it its own). Returns the copy and its caption.
local function copyTab(refs, name, text)
	local source = refs.ConsumablesTab.Parent
	local tab = source:Clone()
	tab.Name = name .. "Tab"
	tab.Visible = true
	local caption = tab.Face.ConsumablesTabLabel
	caption.Name = name .. "TabLabel"
	caption.Text = text
	local hover = tab.Face:FindFirstChild("HoverScale") -- RacerMotion gives the copy its own
	if hover then
		hover:Destroy()
	end
	tab.Parent = source.Parent
	return tab, caption
end

-- The ENEMIES copy keeps following its desktop / phone layout. Returns the tab.
local function enemiesTab(refs)
	local source = refs.ConsumablesTab.Parent
	local tab, caption = copyTab(refs, "Enemies", "ENEMIES")
	follow(source, tab, "Position")
	-- As wide as CHARACTERS: the retired tab's longer width reaches Close on phones
	local sized = refs.CharactersTab.Parent
	tab.Size = sized.Size
	follow(sized, tab, "Size")
	follow(refs.ConsumablesTabLabel, caption, "TextSize")
	return tab
end

-- Right after ENEMIES, narrowed to stop short of Close: on phones only about 100 of the design pixels are left.
local function sidekicksTab(refs, enemies)
	local tab, caption = copyTab(refs, "Sidekicks", "SIDEKICKS")
	caption.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = caption
	local close = refs.Close.Parent
	local function place()
		local x = enemies.Position.X.Offset + enemies.Size.X.Offset + 16
		local room = close.Position.X.Offset - x - 8
		tab.Position = UDim2.fromOffset(x, enemies.Position.Y.Offset)
		tab.Size = UDim2.fromOffset(math.min(enemies.Size.X.Offset, room), enemies.Size.Y.Offset)
	end
	enemies:GetPropertyChangedSignal("Position"):Connect(place)
	enemies:GetPropertyChangedSignal("Size"):Connect(place)
	close:GetPropertyChangedSignal("Position"):Connect(place)
	place()
	return tab
end

function Tabs.Attach(refs, player, refreshCars)
	local enemies = enemiesTab(refs)
	local enemiesFace = enemies.Face
	local sidekicksFace = sidekicksTab(refs, enemies).Face
	-- The generated fit re-applies the authored Visible = true on every refit. refs.ConsumablesTab is the tab's
	-- Face button; its wrapper Frame (Header/Face/ConsumablesTab) is the visible tab.
	for _, retired in { refs.ConsumablesTab.Parent, refs.ConsumablesHost } do
		retired.Visible = false
		retired:GetPropertyChangedSignal("Visible"):Connect(function()
			if retired.Visible then
				retired.Visible = false
			end
		end)
	end
	local gallery = refs.GridHost:WaitForChild("Gallery")
	local enemiesPage, enemyTiles = Components.EnemiesPage(refs, player)
	local sidekicksPage, sidekickTiles = Components.SidekicksPage(refs, player)
	local function show(tab)
		refs.Gui:SetAttribute("InventoryTab", tab)
		refs.GridHost.Visible = true
		gallery.Visible = tab == "Characters"
		enemiesPage.Visible = tab == "Enemies"
		sidekicksPage.Visible = tab == "Sidekicks"
		markTab(refs.CharactersTab, tab == "Characters")
		markTab(enemiesFace, tab == "Enemies")
		markTab(sidekicksFace, tab == "Sidekicks")
		refreshCars()
	end
	refs.CharactersTab.Activated:Connect(function()
		if refs.Gui:GetAttribute("InventoryTab") ~= "Characters" then
			UiFeedback.Play("TabSwitch")
		end
		show("Characters")
	end)
	enemiesFace.Activated:Connect(function()
		if refs.Gui:GetAttribute("InventoryTab") ~= "Enemies" then
			UiFeedback.Play("TabSwitch")
		end
		show("Enemies")
		UiMotion.Cascade(enemyTiles, "Stroke")
	end)
	sidekicksFace.Activated:Connect(function()
		if refs.Gui:GetAttribute("InventoryTab") ~= "Sidekicks" then
			UiFeedback.Play("TabSwitch")
		end
		show("Sidekicks")
		UiMotion.Cascade(sidekickTiles, "Stroke")
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(function()
			show(refs.Gui:GetAttribute("InventoryTab"))
		end)
	end)
	show("Characters")
end
return Tabs
