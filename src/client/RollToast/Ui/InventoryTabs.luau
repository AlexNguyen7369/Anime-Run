--!nonstrict
-- The Index header's tabs. Index is character discovery only (docs/HUD_LAYOUT_SPEC.md sections 1 and 3): consumables are
-- used from the Backpack's Misc tab, so the generated CONSUMABLES tab and its host are held hidden and stay empty.
-- ENEMIES (design doc 4.29) takes that tab's place: a copy, as generated code owns the original.
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

-- A copy of the retired tab that keeps following its desktop / phone layout. Returns the copy's Face button.
local function enemiesTab(refs)
	local source = refs.ConsumablesTab.Parent
	local tab = source:Clone()
	tab.Name = "EnemiesTab"
	tab.Visible = true
	local caption = tab.Face.ConsumablesTabLabel
	caption.Name = "EnemiesTabLabel"
	caption.Text = "ENEMIES"
	local hover = tab.Face:FindFirstChild("HoverScale") -- RacerMotion gives the copy its own
	if hover then
		hover:Destroy()
	end
	tab.Parent = source.Parent
	local function follow(from, to, property)
		from:GetPropertyChangedSignal(property):Connect(function()
			to[property] = from[property]
		end)
	end
	follow(source, tab, "Position")
	-- As wide as CHARACTERS: the retired tab's longer width reaches Close on phones
	local sized = refs.CharactersTab.Parent
	tab.Size = sized.Size
	follow(sized, tab, "Size")
	follow(refs.ConsumablesTabLabel, caption, "TextSize")
	return tab.Face
end

function Tabs.Attach(refs, player, refreshCars)
	local enemiesFace = enemiesTab(refs)
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
	local function show(tab)
		refs.Gui:SetAttribute("InventoryTab", tab)
		refs.GridHost.Visible = true
		gallery.Visible = tab == "Characters"
		enemiesPage.Visible = tab == "Enemies"
		markTab(refs.CharactersTab, tab == "Characters")
		markTab(enemiesFace, tab == "Enemies")
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
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(function()
			show(refs.Gui:GetAttribute("InventoryTab"))
		end)
	end)
	show("Characters")
end
return Tabs
