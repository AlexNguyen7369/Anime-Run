--!nonstrict
-- Recipient selection and confirmation; server validates and opens the purchase prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local AnimeSkin = require(script.Parent:WaitForChild("AnimeSkin"))
local Palette = UiTheme.Palette
local ICON = require(script.Parent:WaitForChild("RollToast"):WaitForChild("Ui"):WaitForChild("HudIcons")).Shop.Image
-- Design units (AnimeSkin.IndexFrame): rows and the button 44 tall, 12 apart.
local U = AnimeSkin.Units
local SUMMARY_HEIGHT = 40 -- one Item line
local STATUS_HEIGHT = 32 -- one Body line
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
-- A popup over the whole Shop panel in the Index frame (design doc 4.42): its Back is the frame's art close.
function Picker.Create(panel, items, backdrop)
	local root = make("Frame", "GiftPicker", panel, {
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
		ZIndex = 20, -- over the Shop's own header, logo and close
	})
	local title = label("Title", root, { Text = "Send a gift" })
	local cancel = make("TextButton", "Cancel", root, { Text = "Back", AutoButtonColor = false })
	local g = AnimeSkin.IndexFrame(root, { Title = title, Close = cancel, Logo = ICON })
	local summary = label("Summary", root, { Text = "", TextXAlignment = Enum.TextXAlignment.Left })
	local recipients = make("ScrollingFrame", "Recipients", root, {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
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
	-- In the content area: the summary line, the list (whole rows only), the status line and Confirm at the bottom.
	local function layout()
		local c = g.Content
		g.Place(summary, c.X, c.Y, c.W, SUMMARY_HEIGHT)
		local confirmY = c.Y + c.H - U.Button
		local statusY = confirmY - U.Gap - STATUS_HEIGHT
		local listTop = c.Y + SUMMARY_HEIGHT + U.Gap
		local rows = math.max(1, math.floor((statusY - U.Gap - listTop + U.Gap) / (U.Button + U.Gap)))
		g.Place(recipients, c.X, listTop, c.W, rows * (U.Button + U.Gap) - U.Gap)
		recipients.ScrollBarThickness = g.px(8)
		list.Padding = UDim.new(0, g.px(U.Gap))
		for _, row in recipients:GetChildren() do
			if row:IsA("TextButton") then
				row.Size = UDim2.new(1, 0, 0, g.px(U.Button))
				g.Role(row, "Item")
			end
		end
		g.Place(status, c.X, statusY, c.W, STATUS_HEIGHT)
		g.Place(confirm, c.X, confirmY, c.W, U.Button)
		g.Role(summary, "Item")
		g.Role(status, "Body")
		g.Role(confirm, "Item")
	end
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
					Size = UDim2.new(1, 0, 0, g.px(U.Button)),
					LayoutOrder = count,
					BackgroundColor3 = Palette.Row,
					Text = recipient.DisplayName .. " (@" .. recipient.Name .. ")",
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				g.Button(button, selected == recipient and "Go" or "Idle") -- its role keeps UiTheme.Apply off it
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
	g.Button(confirm, "Go") -- after UiTheme.Apply's corner snap (design doc 4.42)
	g.OnLayout(layout)
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
