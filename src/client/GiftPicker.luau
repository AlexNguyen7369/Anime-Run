--!nonstrict
-- Recipient selection and confirmation; server validates and opens the purchase prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local Palette = UiTheme.Palette
local ICON = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons")).Shop.Image
local SPACE = AnimeSkin.Space
local px = AnimeSkin.Px
local SUMMARY_HEIGHT = 24 -- one Item line
local STATUS_HEIGHT = 20 -- one Body line
local Picker = {}
local function make(class, name, parent, props)
	local obj = Instance.new(class)
	obj.Name = name
	for key, value in props do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end
local function label(name, parent, props)
	props.BackgroundTransparency = 1
	props.TextWrapped = true
	return make("TextLabel", name, parent, props)
end
-- A popup over the whole Shop panel with the standard header (design doc 4.42): its Back is the header's art close.
function Picker.Create(panel, items, backdrop)
	local root = make("Frame", "GiftPicker", panel, {
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
		ZIndex = 10, -- over the Shop's own header and close
	})
	AnimeSkin.Body(root)
	local title = label("Title", root, { Text = "Send a gift" })
	local cancel = make("TextButton", "Cancel", root, { Text = "Back", AutoButtonColor = false })
	AnimeSkin.Header(root, {
		Header = make("Frame", "Header", root, { BackgroundTransparency = 1 }),
		Title = title,
		Icon = make("ImageLabel", "Icon", root, { Image = ICON }),
		Close = cancel,
	})
	local summary = label("Summary", root, { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	local recipients = make("ScrollingFrame", "Recipients", root, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, -- the bar sits beside the rows, not on them
	})
	local list = make("UIListLayout", "Layout", recipients, { SortOrder = Enum.SortOrder.LayoutOrder })
	local status = label("Status", root, { Text = "Choose a player", TextXAlignment = Enum.TextXAlignment.Left })
	local confirm = make("TextButton", "Confirm", root, {
		Text = "Confirm gift",
		BackgroundColor3 = Palette.MoneyDeep,
		Active = false,
		AutoButtonColor = false,
	})
	-- 16 insets, 12 gaps, 40 tall rows and button; the list ends on a whole row; Confirm spans the bottom-left, so it
	-- keeps 24 clear of the stripe art.
	local function layout()
		local inset, gap, row = px(SPACE.Inset), px(SPACE.Gap), px(SPACE.Button)
		local top = AnimeSkin.Top(false)
		local width = UDim2.new(1, -2 * inset, 0, 0)
		summary.Position, summary.Size = UDim2.fromOffset(inset, top), width + UDim2.fromOffset(0, px(SUMMARY_HEIGHT))
		local listTop = top + px(SUMMARY_HEIGHT) + gap
		local bottom = px(SPACE.BottomClear) + row + gap + px(STATUS_HEIGHT) + gap
		local rows = math.max(1, math.floor((root.AbsoluteSize.Y - listTop - bottom + gap) / (row + gap)))
		recipients.Position = UDim2.fromOffset(inset, listTop)
		recipients.Size = width + UDim2.fromOffset(0, rows * (row + gap) - gap)
		list.Padding = UDim.new(0, gap)
		status.Position = UDim2.new(0, inset, 1, -bottom + gap)
		status.Size = width + UDim2.fromOffset(0, px(STATUS_HEIGHT))
		confirm.Position = UDim2.new(0, inset, 1, -px(SPACE.BottomClear) - row)
		confirm.Size = width + UDim2.fromOffset(0, row)
		confirm.TextSize = px(AnimeSkin.Size.Body)
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local product, selected, submitting, generation, price = nil, nil, false, 0, nil
	local function update()
		confirm.Active = selected ~= nil and not submitting
		confirm.AutoButtonColor = confirm.Active
		confirm.BackgroundTransparency = confirm.Active and 0 or 0.55
		if product then
			summary.Text = product.Name
				.. (price and (" • " .. tostring(price) .. " R$") or " • Price shown by Roblox")
		end
	end
	local function render()
		for _, child in recipients:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local candidates = Players:GetPlayers()
		table.sort(candidates, function(a, b)
			return a.Name < b.Name
		end)
		local count = 0
		for _, recipient in candidates do
			if recipient ~= Players.LocalPlayer then
				count += 1
				local button = make("TextButton", tostring(recipient.UserId), recipients, {
					Size = UDim2.new(1, 0, 0, px(SPACE.Button)),
					LayoutOrder = count,
					BackgroundColor3 = Palette.Row,
					Text = recipient.DisplayName .. " (@" .. recipient.Name .. ")",
					TextSize = px(AnimeSkin.Size.Body),
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				-- Again next frame: UiTheme.Apply's DescendantAdded puts new text back on Fredoka.
				local tone = selected == recipient and "Go" or "Idle"
				AnimeSkin.Button(button, tone)
				task.defer(AnimeSkin.Button, button, tone)
				button.Activated:Connect(function()
					if submitting then
						return
					end
					selected = recipient
					status.Text = "Send to @" .. recipient.Name .. "?"
					render()
				end)
			end
		end
		if count == 0 then
			status.Text = "No other players in this server"
		end
		update()
	end
	local function close()
		generation += 1
		root.Visible = false
		items.Visible = true
		selected, product = nil, nil
	end
	cancel.Activated:Connect(function()
		if not submitting then
			close()
		end
	end)
	confirm.Activated:Connect(function()
		if not confirm.Active or not product or not selected then
			return
		end
		submitting = true
		update()
		local token = generation
		local remote = ReplicatedStorage.Remotes:FindFirstChild("PrepareGift")
		local ok, accepted, message = pcall(function()
			return remote:InvokeServer(product.Id, selected.UserId)
		end)
		submitting = false
		if token ~= generation then
			return
		end
		status.Text = ok and tostring(message) or "Gift request failed; try again"
		if accepted then
			selected = nil
		end
		update()
	end)
	Players.PlayerAdded:Connect(function()
		if root.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function(leaving)
		if selected == leaving then
			selected = nil
			status.Text = "Recipient left; choose another player"
		end
		task.defer(function()
			if root.Visible then
				render()
			end
		end)
	end)
	UiTheme.Apply(root)
	-- After UiTheme.Apply, which would put the fonts back on Fredoka (design doc 4.42).
	AnimeSkin.Button(confirm, "Go")
	AnimeSkin.Label(summary, "Item")
	AnimeSkin.Label(status, "Body")
	layout()
	backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
		if not backdrop.Visible then
			close()
		end
	end)
	return function(item)
		generation += 1
		product, selected, price = item, nil, nil
		items.Visible = false
		root.Visible = true
		status.Text = "Choose a player"
		render()
		local token = generation
		task.spawn(function()
			local ok, info =
				pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.GiftProductId, Enum.InfoType.Product)
			if token == generation and ok and type(info) == "table" then
				price = info.PriceInRobux
				update()
			end
		end)
	end
end
return Picker
