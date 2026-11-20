--!nonstrict
-- Phone tap targets (audit fix U1, owner approved the audit fixes 2026-11-20): on a touch screen, a control drawn smaller
-- than MIN px gets a see-through hit area of at least MIN px centred on it (along `axes`, "X", "Y" or both), so the look
-- stays as drawn. A GuiButton cannot be fired from code, so the hit area calls `fn` itself; with no `fn` it only takes
-- the tap (the caller binds what it needs to the returned button). Mouse and gamepad never see it.
local UserInputService = game:GetService("UserInputService")

local TouchTarget = { MIN = 44 }

function TouchTarget.Add(control, fn, axes)
	local hit = Instance.new("TextButton")
	hit.Name = "TouchHit"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AutoButtonColor = false
	hit.Selectable = false
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.fromScale(1, 1)
	hit.Visible = false
	hit.ZIndex = control.ZIndex + 1
	hit.Parent = control
	local growX, growY = axes ~= "Y", axes ~= "X"
	local function fit()
		local size = control.AbsoluteSize
		if not UserInputService.TouchEnabled or size.X <= 0 or size.Y <= 0 then
			hit.Visible = false
			return
		end
		local sx = growX and math.max(1, TouchTarget.MIN / size.X) or 1
		local sy = growY and math.max(1, TouchTarget.MIN / size.Y) or 1
		hit.Size = UDim2.fromScale(sx, sy) -- scale, so it follows any UIScale above
		hit.ZIndex = control.ZIndex + 1
		hit.Visible = sx > 1 or sy > 1
	end
	control:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	if fn then
		hit.Activated:Connect(fn)
	end
	return hit
end

return TouchTarget
