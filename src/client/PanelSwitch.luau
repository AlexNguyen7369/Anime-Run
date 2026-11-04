--!nonstrict
-- One big panel open at a time: opening the index closes the stats panel and the other way round, so two
-- panels never cover each other's buttons. Client UI scripts register their panel and call Toggle/Close.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local PanelSwitch = {}

local panels = {} -- name -> Frame
local wanted = {} -- name -> true while PanelSwitch opened it
local changed = Instance.new("BindableEvent")
PanelSwitch.Changed = changed.Event -- fires after any panel opens or closes (deferred)
local listeners = {}

-- Calls fn right away (same frame) whenever Toggle / Close / a registered panel's Visible changes the open set.
function PanelSwitch.OnChange(fn)
	table.insert(listeners, fn)
end

local function notify()
	for _, fn in listeners do
		-- One UI listener must not prevent the remaining panel chrome from refreshing.
		pcall(fn)
	end
	changed:Fire()
end

local closing = {} -- panel -> true while its close motion plays (design doc 4.20)

-- True while any registered panel is open.
function PanelSwitch.AnyOpen()
	for _, p in panels do
		if p.Visible and not closing[p] then
			return true
		end
	end
	return false
end

-- Gamepad focus (docs/HUD_LAYOUT_SPEC.md section 7): an opened panel takes the selection and traps it; closing
-- gives the previous selection back. Mouse, touch and keyboard are untouched.
local FOCUS_GROUP, CLOSE_ACTION = "PanelSwitchFocus", "PanelSwitchClose"
local focused, restoreTo = nil, nil

local function usesGamepad()
	local ok, preferred = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and preferred then
		return preferred == Enum.PreferredInput.Gamepad
	end
	return UserInputService:GetLastInputType().Name:find("^Gamepad") ~= nil
end

local function shown(inst, root)
	while inst and inst ~= root do
		if inst:IsA("GuiObject") and not inst.Visible then
			return false
		end
		inst = inst.Parent
	end
	return true
end

-- The top-left visible, selectable button in the panel.
local function firstButton(panel)
	local best
	for _, inst in panel:GetDescendants() do
		if inst:IsA("GuiButton") and inst.Selectable and inst.Name ~= "Backdrop" and shown(inst, panel) then
			local p = inst.AbsolutePosition
			if
				inst.AbsoluteSize.X > 0
				and (not best or p.Y < best.Y - 1 or (math.abs(p.Y - best.Y) <= 1 and p.X < best.X))
			then
				best = { Button = inst, Y = p.Y, X = p.X }
			end
		end
	end
	return best and best.Button
end

local function releaseFocus(panel)
	if focused ~= panel then
		return
	end
	focused = nil
	GuiService:RemoveSelectionGroup(FOCUS_GROUP)
	ContextActionService:UnbindAction(CLOSE_ACTION)
	local selected = GuiService.SelectedObject
	if selected == nil or selected:IsDescendantOf(panel) then
		GuiService.SelectedObject = (restoreTo and restoreTo:IsDescendantOf(game)) and restoreTo or nil
	end
	restoreTo = nil
end

local function takeFocus(panel)
	if not usesGamepad() then
		return
	end
	if focused then
		releaseFocus(focused)
	end
	focused = panel
	restoreTo = GuiService.SelectedObject
	GuiService:AddSelectionParent(FOCUS_GROUP, panel)
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin and focused == panel then
			panel.Visible = false
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	task.defer(function() -- the layout settles first, so AbsolutePosition is real
		if focused == panel and panel.Visible then
			GuiService.SelectedObject = firstButton(panel)
		end
	end)
end

-- Open motion (docs/HUD_LAYOUT_SPEC.md section 10): scale from 90% to 100%; a panel with a layout UIScale (Racer
-- panels) slides 12 px up instead. Closing is instant: a hide cancels the motion and puts the panel back home.
-- Design doc 4.20 close motion: Toggle / Close shrink the panel to 95% over 0.12 s, then hide it (input is off
-- meanwhile). A panel hidden any other way (Visible = false, another panel opening) still hides at once.
local CLOSE_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local OPEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local motions = {} -- target -> { Tween, Home (position or nil) }

-- A registered full-screen backdrop animates the PanelFrame card inside it, not the whole screen.
local function motionTarget(panel)
	if panel:GetAttribute("PanelFrame") then
		return panel
	end
	for _, inst in panel:GetDescendants() do
		if inst:IsA("GuiObject") and inst:GetAttribute("PanelFrame") then
			return inst
		end
	end
	return panel
end

local function stopMotion(target)
	local motion = motions[target]
	if not motion then
		return
	end
	motions[target] = nil
	motion.Tween:Cancel()
	if motion.Home then
		target.Position = motion.Home
	else
		motion.Scale.Scale = 1
	end
end

-- Design doc 4.20: the panel's main list / grid (the layout with the most items) staggers in on open.
local function cascadeList(target)
	local items = {}
	for _, layout in target:GetDescendants() do
		if layout:IsA("UIGridLayout") or layout:IsA("UIListLayout") then
			local found = {}
			for _, item in layout.Parent:GetChildren() do
				if item:IsA("GuiObject") and item.Visible and item.BackgroundTransparency < 1 then
					table.insert(found, item)
				end
			end
			if #found > #items then
				items = found
			end
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	UiMotion.Cascade(items)
end

local function openMotion(panel)
	local target = motionTarget(panel)
	stopMotion(target)
	if UiMotion.Reduced() then
		return
	end
	local scale = target:FindFirstChildOfClass("UIScale")
	local motion
	if scale and scale.Name ~= "MotionScale" then
		local home = target.Position
		target.Position = home + UDim2.fromOffset(0, 12)
		motion = { Tween = UiMotion.Create(target, OPEN_INFO, { Position = home }), Home = home }
	else
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "MotionScale"
			scale.Parent = target
		end
		scale.Scale = 0.9 -- design doc 4.20 (proposed)
		motion = { Tween = UiMotion.Create(scale, OPEN_INFO, { Scale = 1 }), Scale = scale }
	end
	cascadeList(target)
	motions[target] = motion
	motion.Tween.Completed:Connect(function()
		if motions[target] == motion then
			motions[target] = nil
		end
	end)
	motion.Tween:Play()
end

-- Hides `panel` with the close motion (instant while reduced, or for a layout-UIScale panel, which slides on open).
local function closeMotion(panel)
	local target = motionTarget(panel)
	stopMotion(target)
	local scale = target:FindFirstChildOfClass("UIScale")
	if UiMotion.Reduced() or (scale and scale.Name ~= "MotionScale") then
		panel.Visible = false
		return
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MotionScale"
		scale.Parent = target
	end
	closing[panel] = true
	target.Interactable = false
	local motion = { Tween = UiMotion.Create(scale, CLOSE_INFO, { Scale = 0.95 }), Scale = scale }
	motions[target] = motion
	motion.Tween.Completed:Connect(function(state)
		if motions[target] ~= motion then
			return -- reopened or hidden meanwhile
		end
		motions[target] = nil
		closing[panel] = nil
		target.Interactable = true
		scale.Scale = 1
		if state == Enum.PlaybackState.Completed then
			panel.Visible = false
		end
	end)
	motion.Tween:Play()
end

-- Stops a running close motion (the panel is wanted open again, or hidden directly).
local function cancelClose(panel)
	if closing[panel] then
		closing[panel] = nil
		local target = motionTarget(panel)
		target.Interactable = true
		stopMotion(target)
	end
end

function PanelSwitch.Register(name, panel)
	panels[name] = panel
	wanted[name] = panel.Visible
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		-- Generated responsive fits re-apply the authored Visible = true on viewport changes; only Toggle opens
		-- a panel, so an unrequested show is undone (it would stack two panels on join).
		if panel.Visible and not wanted[name] then
			panel.Visible = false
			return
		end
		if panel.Visible then
			openMotion(panel)
			takeFocus(panel)
		else
			wanted[name] = false
			cancelClose(panel)
			stopMotion(motionTarget(panel))
			releaseFocus(panel)
		end
		notify()
	end)
end

-- Shows `name` and hides every other registered panel; hides it if it was already open. Returns the new state.
function PanelSwitch.Toggle(name)
	local panel = panels[name]
	if not panel then
		return false
	end
	local open = not panel.Visible or closing[panel] == true
	wanted[name] = open
	if open then
		for other, p in panels do
			if other ~= name then
				p.Visible = false
			end
		end
		if closing[panel] then
			cancelClose(panel) -- reopened mid-close: still Visible, so play the open motion again
			openMotion(panel)
		end
		panel.Visible = true
	else
		closeMotion(panel)
	end
	notify()
	return open
end

-- A HUD entry whose panel needs more than Toggle (it rebuilds its content, or two entries share one panel)
-- registers its own action; Action falls back to Toggle. The owning script decides toggle behaviour.
local actions = {}
function PanelSwitch.SetAction(name, fn)
	actions[name] = fn
end

function PanelSwitch.Action(name)
	if actions[name] then
		actions[name]()
	else
		PanelSwitch.Toggle(name)
	end
end

function PanelSwitch.IsOpen(name)
	return panels[name] ~= nil and panels[name].Visible and not closing[panels[name]]
end

function PanelSwitch.Close(name)
	if PanelSwitch.IsOpen(name) then
		wanted[name] = false
		closeMotion(panels[name])
		notify()
	end
end

return PanelSwitch
