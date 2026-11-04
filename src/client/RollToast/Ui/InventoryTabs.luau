--!nonstrict
-- The Index header's tabs. Index is character discovery only (docs/HUD_LAYOUT_SPEC.md sections 1 and 3): consumables are
-- used from the Backpack's Misc tab, so the generated CONSUMABLES tab and its host are held hidden and stay empty.
-- ENEMIES (design doc 4.29) takes that tab's place: a copy, as generated code owns the original.
local Tabs = {}
local Components = require(script.Parent.RacerComponents)
local UiMotion = require(script.Parent.Parent.Parent:WaitForChild("UiMotion"))
local CYAN = Color3.fromRGB(30, 216, 255)
local IDLE = Color3.fromRGB(59, 68, 93)

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
	follow(source, tab, "Size")
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
		Components.Tint(refs.CharactersTab, tab == "Characters" and CYAN or IDLE)
		Components.Tint(enemiesFace, tab == "Enemies" and CYAN or IDLE)
		refreshCars()
	end
	refs.CharactersTab.Activated:Connect(function()
		show("Characters")
	end)
	enemiesFace.Activated:Connect(function()
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
