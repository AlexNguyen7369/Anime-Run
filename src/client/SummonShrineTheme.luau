--!nonstrict
-- Blossom-shrine presentation only; summon actions, costs and server rules are unchanged.
local Theme = {}
local C = {
	Gold = Color3.fromRGB(237, 183, 93),
	GoldLight = Color3.fromRGB(255, 220, 155),
	Ink = Color3.fromRGB(48, 19, 22),
	Cream = Color3.fromRGB(255, 243, 216),
	Rose = Color3.fromRGB(244, 145, 171),
	Wood = Color3.fromRGB(107, 47, 32),
	Dark = Color3.fromRGB(47, 19, 22),
}
local primary = { Once = true, Many = true, Auto = true, AutoFuse = true }
local function gradient(o, top, bottom)
	local g = o:FindFirstChildOfClass("UIGradient")
	if not g then
		g = Instance.new("UIGradient")
		g.Name = "Gradient"
		g.Parent = o
	end
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	return g
end
local function corner(o, r)
	local c = o:FindFirstChildOfClass("UICorner")
	if not c then
		c = Instance.new("UICorner")
		c.Name = "Corner"
		c.Parent = o
	end
	c.CornerRadius = UDim.new(0, r)
end
local function stroke(o)
	local s = o:FindFirstChildOfClass("UIStroke")
	if not s then
		s = Instance.new("UIStroke")
		s.Name = "Border"
		s.Parent = o
	end
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = C.Gold
	s.Thickness = 1.6
	s.Transparency = 0.05
	return s
end
local function flower(button)
	if button:FindFirstChild("ShrineBlossomStamp") then
		return
	end
	local root = Instance.new("Frame")
	root.Name = "ShrineBlossomStamp"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(12, 12)
	root.Position = UDim2.new(1, -17, 0, 4)
	root.Active = false
	root.ZIndex = button.ZIndex + 3
	root.Parent = button
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		local p = Instance.new("Frame")
		p.Name = "Petal"
		p.BorderSizePixel = 0
		p.BackgroundColor3 = C.Rose
		p.BackgroundTransparency = 0.2
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Size = UDim2.fromOffset(4, 6)
		p.Position = UDim2.fromOffset(6 + math.sin(a) * 3, 6 - math.cos(a) * 3)
		p.Rotation = math.deg(a)
		p.ZIndex = root.ZIndex
		p.Active = false
		p.Parent = root
		corner(p, 4)
	end
	local p = Instance.new("Frame")
	p.Name = "Center"
	p.Size = UDim2.fromOffset(3, 3)
	p.Position = UDim2.fromOffset(4.5, 4.5)
	p.BackgroundColor3 = C.GoldLight
	p.BorderSizePixel = 0
	p.ZIndex = root.ZIndex + 1
	p.Active = false
	p.Parent = root
	corner(p, 3)
end
local function button(o)
	o.BackgroundColor3 = Color3.new(1, 1, 1)
	o.BackgroundTransparency = 0
	o.BorderSizePixel = 0
	o.TextColor3 = C.Cream
	o.TextStrokeColor3 = C.Ink
	o.TextStrokeTransparency = 0.12
	o.Font = Enum.Font.FredokaOne
	corner(o, 8)
	stroke(o)
	local top, bottom = C.Wood, C.Dark
	if primary[o.Name] then
		top, bottom = Color3.fromRGB(180, 65, 81), Color3.fromRGB(87, 25, 44)
	elseif o.Name == "Buy" then
		top, bottom = Color3.fromRGB(56, 94, 57), Color3.fromRGB(23, 49, 33)
	elseif o.Name == "Close" then
		top, bottom = Color3.fromRGB(150, 43, 48), Color3.fromRGB(73, 22, 30)
	end
	gradient(o, top, bottom)
	for _, d in o:GetDescendants() do
		if d:IsA("UIStroke") then
			d.Color = C.Gold
			if d.Parent.Name == "HoverGlow" or d.Parent.Name == "Glow" then
				d.Thickness = 4
				d.Transparency = 0.82
			end
		elseif d:IsA("UIGradient") and d.Parent ~= o and not d.Parent:IsA("ImageLabel") then
			d.Color = ColorSequence.new(C.GoldLight, C.Rose)
		elseif d:IsA("TextLabel") and d.Name == "Caption" then
			d.TextColor3 = C.Cream
			d.TextStrokeColor3 = C.Ink
			d.TextStrokeTransparency = 0.10
			d.Font = Enum.Font.FredokaOne
		elseif d:IsA("Frame") and (d.Name == "Gloss" or d.Name == "TopLight") then
			d.BackgroundColor3 = C.GoldLight
			d.BackgroundTransparency = d.Name == "Gloss" and 0.9 or 0.55
		end
	end
	if o.Name == "Close" then
		local art = o:FindFirstChild("CloseIcon")
		if art then
			art.Visible = false
		end
		local caption = o:FindFirstChild("Caption")
		if caption then
			caption.Visible = true
			caption.Text = utf8.char(0x00D7)
			caption.Position = UDim2.fromScale(0.5, 0.5)
			caption.AnchorPoint = Vector2.new(0.5, 0.5)
			caption.Size = UDim2.fromScale(1, 1)
			caption.TextSize = 32
		end
		o.Text = ""
		o.Rotation = 0
	elseif o.Name ~= "Option" and o.Name ~= "Dismiss" and o.Name ~= "Buy" then
		flower(o)
	end
	o:SetAttribute("ShrineButtonTheme", 1)
end
function Theme.Apply(gui)
	local canvas = gui:FindFirstChild("Canvas")
	if not canvas then
		return
	end
	for _, o in gui:GetDescendants() do
		if o:IsA("TextButton") then
			button(o)
		end
	end
	for _, o in canvas:GetChildren() do
		if o:IsA("Frame") and o.Name:match("Depth$") then
			o.BackgroundColor3 = C.Ink
			corner(o, 8)
			for _, d in o:GetDescendants() do
				if d:IsA("UIGradient") then
					d.Color = ColorSequence.new(C.Ink, C.Dark)
				end
			end
		elseif o:IsA("Frame") and o.Name:match("^PityCard") then
			o.BackgroundColor3 = Color3.new(1, 1, 1)
			gradient(o, Color3.fromRGB(85, 37, 29), C.Dark)
			stroke(o)
			local track = o:FindFirstChild("Track")
			if track then
				track.BackgroundColor3 = C.Ink
			end
		end
	end
	for i = 1, 2 do
		local offer = canvas:FindFirstChild("Offer" .. i)
		if offer then
			offer.BackgroundColor3 = Color3.new(1, 1, 1)
			corner(offer, 10)
			stroke(offer)
			gradient(offer, Color3.fromRGB(112, 60, 35), Color3.fromRGB(55, 24, 30))
			for _, d in offer:GetDescendants() do
				if d:IsA("UIStroke") then
					d.Color = C.Gold
				elseif
					d:IsA("UIGradient")
					and d.Parent ~= offer
					and not d.Parent:IsA("TextButton")
					and not d.Parent:IsA("ImageLabel")
				then
					d.Color = ColorSequence.new(C.GoldLight, C.Rose)
				elseif d:IsA("TextLabel") then
					d.TextColor3 = C.Cream
					d.TextStrokeColor3 = C.Ink
				end
			end
			local price = offer:FindFirstChild("Price")
			if price then
				price.BackgroundColor3 = C.Ink
				price.TextColor3 = C.GoldLight
			end
		end
	end
	for name, color in
		{ Title = C.Cream, Subtitle = C.Rose, Tagline = Color3.fromRGB(243, 218, 191), Timer = C.GoldLight }
	do
		local label = canvas:FindFirstChild(name)
		if label then
			label.TextColor3 = color
			label.TextStrokeColor3 = C.Ink
		end
	end
	local modal = canvas:FindFirstChild("Modal")
	local panel = modal and modal:FindFirstChild("Panel")
	if panel then
		panel.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient(panel, Color3.fromRGB(80, 35, 30), C.Dark)
		stroke(panel)
		corner(panel, 12)
	end
	gui:SetAttribute("SummonTheme", "BlossomShrine")
end
return Theme
