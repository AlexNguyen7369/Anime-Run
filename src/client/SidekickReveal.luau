--!nonstrict
-- The summon reveal (docs/SIDEKICK_SPEC.md "Summon reveal", owner 2026-11-05): 1x charges a vortex, hits, and shows one Sidekick
-- on moving graphics; 10x drops 10 cards that flip one by one, and a Mythic or Secret interrupts with its own showcase. A tap
-- skips to the end; a click at the end continues. Reduced effects start at the end. Display only: the server already decided every
-- result. Textures are original: vfx/summon_reveal/textures.py.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("SidekickConfig"))
local GachaConfig = require(shared:WaitForChild("GachaConfig"))
local UiTheme = require(shared:WaitForChild("UiTheme"))
local SidekickView = require(script.Parent:WaitForChild("SidekickView"))
local UiFeedback = require(script.Parent:WaitForChild("UiFeedback"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local OUTLINE = UiTheme.Outline
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local NEAR_BLACK = Color3.fromRGB(8, 8, 16)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 255, 150)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(100, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 120, 255)),
})
-- Uploaded by vfx/summon_reveal/upload.py; ledger vfx/summon_reveal/assets.json.
local TEXTURES = {
	Vortex = "rbxassetid://112820698671575",
	SpeedLines = "rbxassetid://137127744790592",
	Impact = "rbxassetid://132733406310246",
	Ring = "rbxassetid://138039615347256",
	Flare = "rbxassetid://90675872332302",
	Glow = "rbxassetid://87567001235917",
	Rays = "rbxassetid://136507228397919",
}
local MODEL_VIEW_DIR = Vector3.new(0.45, 0.15, -1).Unit -- from the model to the camera, as Client/StarterPick
local MODEL_LIGHT_DIR = Vector3.new(-1, -2, -1)
-- All timings and counts are placeholders.
local CHARGE_SECONDS = { Common = 1, Rare = 1.1, Legendary = 1.3, Mythic = 1.7, Secret = 2 }
local FLIP_GAP = { Common = 0.1, Rare = 0.18, Legendary = 0.42 }
local FLIP_SPARKS = { Common = 3, Rare = 8, Legendary = 16 }
local HIT_SPARKS = { Common = 14, Rare = 20, Legendary = 28, Mythic = 36, Secret = 44 }
local SHOWCASE_HOLD = 1.6
local RAY_SPEED, TURN_SPEED, MODEL_SWAY = 28, math.rad(40), math.rad(14)
local BOB_SPEED, BOB_HEIGHT = 2.2, 0.012
local BIG_MOMENT = { Mythic = true, Secret = true }
local CENTRE = UDim2.fromScale(0.5, 0.4)

local Reveal = {}

local function make(class, name, parent, props)
	local object = Instance.new(class)
	object.Name = name
	for key, value in props do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function caption(name, parent, props)
	props.BackgroundTransparency = 1
	props.Font = UiTheme.Font
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	local label = make("TextLabel", name, parent, props)
	make("UIStroke", "Outline", label, { Color = OUTLINE, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round })
	make("UITextSizeConstraint", "Max", label, { MaxTextSize = props.TextSize or 20 })
	return label
end
local function paintRarity(label, rarity)
	local rainbow = rarity == "Mythic" or rarity == "Secret"
	label.TextColor3 = rainbow and WHITE or SidekickView.RarityColor(rarity)
	if rainbow then
		make("UIGradient", "Rainbow", label, { Color = RAINBOW })
	end
end
local function tellColor(rarity)
	-- Secret's catalog colour is black, which would not read on the dark screen.
	return rarity == "Secret" and Color3.fromRGB(215, 120, 255) or SidekickView.RarityColor(rarity)
end
local function landCue(rarity)
	return SidekickView.LAND_CUES[rarity] or "RollLand1"
end

-- Plays `results` ({ Id, Sold }, or { Row } for a catalog row of another kind) over the game world. onClose runs when the player clicks
-- to continue. With `chestImage`, a chest opening (docs/RELIC_SPEC.md "Chests"): results play one after another on the 1x sequence.
function Reveal.Play(results, onClose, chestImage)
	local player = Players.LocalPlayer
	local gui = make("ScreenGui", "RacerSidekickReveal", player:WaitForChild("PlayerGui"), {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15, -- above the roll view (14), below the starter popup (19)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local skip = UiMotion.Reduced()
	local closed, ended = false, false
	local close

	make("Frame", "Backdrop", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NEAR_BLACK,
		BackgroundTransparency = 0.6, -- the world stays in view (owner 2026-11-05)
		BorderSizePixel = 0,
	})
	-- Everything that shakes.
	local stage = make("Frame", "Stage", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})
	local tap = make("TextButton", "Tap", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 7,
	})
	tap.Activated:Connect(function()
		if ended then
			close()
		else
			skip = true
		end
	end)
	local flash = make("Frame", "Flash", gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
	})
	local function doFlash(seconds)
		if skip then
			return
		end
		flash.BackgroundTransparency = 0
		UiMotion.Create(flash, TweenInfo.new(seconds or 0.3), { BackgroundTransparency = 1 }):Play()
	end

	-- One Heartbeat runs every moving part: flipbooks, spins, model turn and bob.
	local flipbooks, spins, views, bobs = {}, {}, {}, {}
	local clock = 0
	local function image(name, parent, texture, props)
		props.BackgroundTransparency = 1
		props.Image = texture
		props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
		return make("ImageLabel", name, parent, props)
	end
	-- grid: frames along a side of the 1024 sheet, 4 unless given.
	local function flipbook(name, parent, texture, fps, loop, props, grid)
		grid = grid or 4
		local cell = 1024 // grid
		props.ImageRectSize = Vector2.new(cell, cell)
		local label = image(name, parent, texture, props)
		flipbooks[label] = { Time = 0, Fps = fps, Loop = loop, Grid = grid, Cell = cell }
		return label
	end
	local function spin(label, speed)
		spins[label] = speed
		return label
	end
	local turning = RunService.Heartbeat:Connect(function(dt)
		clock += dt
		local reduced = UiMotion.Reduced()
		for label, book in flipbooks do
			book.Time += dt
			local frame = math.floor(book.Time * book.Fps)
			local count = book.Grid * book.Grid
			if book.Loop then
				frame %= count
			end
			if frame >= count or not label.Parent then
				flipbooks[label] = nil
				label:Destroy()
			else
				label.ImageRectOffset = Vector2.new((frame % book.Grid) * book.Cell, (frame // book.Grid) * book.Cell)
			end
		end
		for label, speed in spins do
			if not label.Parent then
				spins[label] = nil
			elseif not reduced then
				label.Rotation = (label.Rotation + speed * dt) % 360
			end
		end
		if reduced then
			return
		end
		local turn = CFrame.Angles(0, math.sin(clock * TURN_SPEED) * MODEL_SWAY, 0)
		for view, spot in views do
			if view.Parent then
				view.CurrentCamera.CFrame =
					CFrame.lookAt(spot.Focus + turn * MODEL_VIEW_DIR * spot.Distance, spot.Focus)
				view.LightDirection = turn * MODEL_LIGHT_DIR
			else
				views[view] = nil
			end
		end
		for view, home in bobs do
			if view.Parent then
				view.Position = home + UDim2.fromScale(0, math.sin(clock * BOB_SPEED) * BOB_HEIGHT)
			else
				bobs[view] = nil
			end
		end
	end)

	close = function()
		if closed then
			return
		end
		closed = true
		turning:Disconnect()
		gui:Destroy()
		onClose()
	end
	local function pause(seconds)
		local stop = os.clock() + seconds
		while os.clock() < stop and not skip and not closed do
			task.wait()
		end
	end
	local function shake(px, seconds)
		if not skip then
			UiMotion.Shake(stage, px, seconds)
		end
	end

	-- A glint that flies from one point to another and goes out.
	local function spark(parent, from, to, color, size, seconds, z)
		if skip or closed then
			return
		end
		local bit = image("Spark", parent, TEXTURES.Flare, {
			Position = from,
			Size = UDim2.fromOffset(size, size),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ImageColor3 = color,
			Rotation = math.random(0, 90),
			ZIndex = z or 6,
		})
		UiMotion.Create(bit, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = to,
			Size = UDim2.fromOffset(size * 0.2, size * 0.2),
			ImageTransparency = 0.7,
			Rotation = bit.Rotation + 120,
		}):Play()
		task.delay(seconds, function()
			bit:Destroy()
		end)
	end
	local function scatter(parent, centre, count, color, reach, z)
		for _ = 1, count do
			local angle = math.random() * 2 * math.pi
			local far = reach * (0.45 + math.random() * 0.75)
			local to = centre + UDim2.fromScale(math.cos(angle) * far, math.sin(angle) * far * 1.7)
			spark(
				parent,
				centre,
				to,
				math.random() < 0.3 and WHITE or color,
				math.random(22, 56),
				0.35 + math.random() * 0.4,
				z
			)
		end
	end

	local function modelView(parent, row, props)
		props.BackgroundTransparency = 1
		props.Ambient = Color3.fromRGB(235, 235, 240) -- 3D light, not UI
		props.LightColor = WHITE
		props.LightDirection = MODEL_LIGHT_DIR
		local view = make("ViewportFrame", "Model", parent, props)
		view.CurrentCamera = make("Camera", "Camera", view, { FieldOfView = 30 })
		local models = ReplicatedStorage:FindFirstChild("SidekickModels")
		local source = row and models and models:FindFirstChild(row.Id)
		if source then
			local model = source:Clone()
			model.Parent = view
			local box, extents = model:GetBoundingBox()
			local spot = { Focus = box.Position, Distance = 0.72 * extents.Magnitude / 2 / math.sin(math.rad(15)) }
			view.CurrentCamera.CFrame = CFrame.lookAt(spot.Focus + MODEL_VIEW_DIR * spot.Distance, spot.Focus)
			views[view] = spot
		end
		return view
	end

	-- The vortex winds up: lines rush in, energy pours to the centre, the orb swells and shows the rarity's colour partway.
	local function charge(rarity)
		if skip then
			return
		end
		local seconds = CHARGE_SECONDS[rarity] or CHARGE_SECONDS.Common
		local color = tellColor(rarity)
		local layer =
			make("Frame", "Charge", stage, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 })
		local lines = flipbook("Lines", layer, TEXTURES.SpeedLines, 14, true, {
			Position = CENTRE,
			Size = UDim2.fromScale(1.1, 1.1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ImageTransparency = 0.7,
			ZIndex = 1,
		}, 2)
		local vortex = spin(
			flipbook("Vortex", layer, TEXTURES.Vortex, 18, true, {
				Position = CENTRE,
				Size = UDim2.fromScale(0.3, 0.3),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ImageColor3 = WHITE,
				ZIndex = 2,
			}),
			-160
		)
		local glow = image("Glow", layer, TEXTURES.Glow, {
			Position = CENTRE,
			Size = UDim2.fromScale(0.3, 0.3),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 3,
		})
		local core = image("Core", layer, TEXTURES.Flare, {
			Position = CENTRE,
			Size = UDim2.fromScale(0.1, 0.1),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 4,
		})
		spin(core, 90)
		local easeIn = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UiMotion.Create(vortex, easeIn, { Size = UDim2.fromScale(0.75, 0.75) }):Play()
		UiMotion.Create(glow, easeIn, { Size = UDim2.fromScale(0.55, 0.55) }):Play()
		UiMotion.Create(core, easeIn, { Size = UDim2.fromScale(0.4, 0.4) }):Play()
		UiMotion.Create(lines, easeIn, { ImageTransparency = 0.4 }):Play()
		task.delay(seconds * 0.55, function()
			local tell = TweenInfo.new(seconds * 0.25)
			if vortex.Parent then
				UiMotion.Create(vortex, tell, { ImageColor3 = color }):Play()
				UiMotion.Create(glow, tell, { ImageColor3 = color }):Play()
				UiMotion.Create(lines, tell, { ImageColor3 = color }):Play()
			end
		end)
		local stop = os.clock() + seconds
		while os.clock() < stop and not skip and not closed do
			local done = 1 - (stop - os.clock()) / seconds
			for _ = 1, 2 do
				local angle = math.random() * 2 * math.pi
				local from = CENTRE + UDim2.fromScale(math.cos(angle) * 0.24, math.sin(angle) * 0.42)
				spark(layer, from, CENTRE, done > 0.55 and color or WHITE, math.random(18, 44), 0.34, 5)
			end
			shake(1 + done * 4, 0.12)
			pause(0.09)
		end
		-- The breath before the hit: all of it collapses to a point.
		if not skip then
			local collapse = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, part in { vortex, glow, core } do
				UiMotion.Create(part, collapse, { Size = UDim2.fromScale(0.02, 0.02) }):Play()
			end
			pause(0.1)
		end
		layer:Destroy()
	end

	-- The hit: flash, a comic burst, two shock rings, sparks everywhere, a hard shake.
	local function hit(rarity, parent)
		if skip then
			return
		end
		local color = tellColor(rarity)
		doFlash(0.22)
		shake(BIG_MOMENT[rarity] and 10 or 6, 0.35)
		flipbook("Impact", parent, TEXTURES.Impact, 30, false, {
			Position = CENTRE,
			Size = UDim2.fromScale(0.95, 0.95),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ImageColor3 = color:Lerp(WHITE, 0.25),
			ZIndex = 2,
		})
		for index, grow in { 1.2, 0.85 } do
			task.delay((index - 1) * 0.09, function()
				if not closed then
					flipbook("Ring", parent, TEXTURES.Ring, 26, false, {
						Position = CENTRE,
						Size = UDim2.fromScale(grow, grow),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						ImageColor3 = index == 1 and WHITE or color,
						ZIndex = 3,
					})
				end
			end)
		end
		scatter(parent, CENTRE, HIT_SPARKS[rarity] or HIT_SPARKS.Common, color, 0.26, 8)
	end

	-- One Sidekick large, on moving graphics that keep going until it closes.
	local function showcase(row, result)
		local rarity = row and row.Rarity
		local color = tellColor(rarity)
		local rainbow = BIG_MOMENT[rarity]
		local layer = make("Frame", "Showcase", stage, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 5,
		})
		local big = spin(
			image("RaysBig", layer, TEXTURES.Rays, {
				Position = CENTRE,
				Size = UDim2.fromScale(1.5, 1.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ImageColor3 = rainbow and WHITE or color,
				ImageTransparency = 0.2,
				ZIndex = 1,
			}),
			RAY_SPEED
		)
		if rainbow then
			make("UIGradient", "Rainbow", big, { Color = RAINBOW })
		end
		spin(
			image("RaysSmall", layer, TEXTURES.Rays, {
				Position = CENTRE,
				Size = UDim2.fromScale(0.95, 0.95),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ImageColor3 = WHITE,
				ImageTransparency = 0.45,
				ZIndex = 2,
			}),
			-RAY_SPEED * 1.6
		)
		local glow = image("Glow", layer, TEXTURES.Glow, {
			Position = CENTRE,
			Size = UDim2.fromScale(0.7, 0.7),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ImageColor3 = color:Lerp(WHITE, 0.3),
			ImageTransparency = 0.2,
			ZIndex = 4,
		})
		UiMotion.Pulse(glow, { Size = UDim2.fromScale(0.85, 0.85) }, 0.7)
		local home = CENTRE
		local viewProps = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = home,
			Size = UDim2.fromScale(skip and 0.56 or 0.12, skip and 0.56 or 0.12),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			ZIndex = 5,
		}
		local view
		if row and row.Image then
			viewProps.ScaleType = Enum.ScaleType.Fit
			view = image("Art", layer, row.Image, viewProps)
		else
			view = modelView(layer, row, viewProps)
		end
		UiMotion.Create(view, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.56, 0.56),
		}):Play()
		bobs[view] = home
		local name = caption("Name", layer, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromScale(0.5, 0.085),
			Text = row and row.Name or "?",
			TextSize = 46,
			ZIndex = 7,
		})
		-- The divider draws outward from its centre, with a diamond on each end.
		local divider = make("Frame", "Divider", layer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.715),
			Size = UDim2.new(skip and 0.5 or 0, 0, 0, 4),
			BackgroundColor3 = NEAR_BLACK,
			BorderSizePixel = 0,
			ZIndex = 7,
		})
		UiMotion.Create(divider, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.5, 0, 0, 4),
		}):Play()
		for _, side in { 0, 1 } do
			local diamond = make("Frame", "Diamond", divider, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(side, 0.5),
				Size = UDim2.fromOffset(14, 14),
				Rotation = 45,
				BackgroundColor3 = color,
				ZIndex = 8,
			})
			make("UIStroke", "Edge", diamond, {
				Color = NEAR_BLACK,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
		end
		local rarityLabel = caption("Rarity", layer, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.73),
			Size = UDim2.fromScale(0.5, 0.075),
			Text = result.Sold and row and string.format("%s: SOLD +%d", row.Rarity, row.SellGems) or rarity or "",
			TextSize = 42,
			ZIndex = 7,
		})
		paintRarity(rarityLabel, rarity)
		UiMotion.Slam(name)
		UiMotion.Slam(rarityLabel)
		UiFeedback.Play(landCue(rarity), name)
		hit(rarity, layer)
		-- Glints keep rising for as long as it is on screen.
		task.spawn(function()
			while layer.Parent and not closed and not UiMotion.Reduced() do
				local x = 0.38 + math.random() * 0.24
				local from = UDim2.fromScale(x, 0.62)
				local saved = skip
				skip = false
				spark(
					layer,
					from,
					from + UDim2.fromScale((math.random() - 0.5) * 0.1, -0.42),
					color:Lerp(WHITE, 0.4),
					math.random(18, 40),
					0.9 + math.random() * 0.5,
					6
				)
				skip = saved
				task.wait(rainbow and 0.06 or 0.11)
			end
		end)
		return layer
	end

	-- Nothing to press: a click anywhere continues (owner 2026-11-05).
	local function finish()
		ended = true
		caption("Hint", gui, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.82),
			Size = UDim2.fromOffset(420, 28),
			Text = "(Click anywhere to continue)",
			TextSize = 22,
			ZIndex = 9,
		})
	end

	local function playOne()
		-- On the gui, not Stage: the charge shakes Stage, and the chest stays still.
		local chest = chestImage
			and not skip
			and image("Chest", gui, chestImage, {
				Position = CENTRE,
				Size = UDim2.fromScale(0.42, 0.42),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			})
		local layer = nil
		for i, result in results do
			local row = result.Row or Config.Get(result.Id)
			if i == 1 then
				charge(row and row.Rarity)
				if chest then
					chest:Destroy()
				end
			else
				pause(SHOWCASE_HOLD)
				layer:Destroy()
				doFlash(0.2)
			end
			layer = showcase(row, result)
		end
	end

	local function playMany()
		spin(
			image("Rays", stage, TEXTURES.Rays, {
				Position = CENTRE,
				Size = UDim2.fromScale(1.4, 1.4),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ImageColor3 = Color3.fromRGB(150, 150, 220),
				ImageTransparency = 0.55,
				ZIndex = 1,
			}),
			RAY_SPEED * 0.5
		)
		local grid = make("Frame", "Grid", stage, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.62, 0.68),
			BackgroundTransparency = 1,
			ZIndex = 4,
		})
		make("UIGridLayout", "Layout", grid, {
			CellSize = UDim2.fromScale(0.19, 0.48),
			CellPadding = UDim2.fromScale(0.01, 0.02),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		local cards = {}
		for order, result in results do
			local row = Config.Get(result.Id)
			local cell = make("Frame", "Result" .. order, grid, { LayoutOrder = order, BackgroundTransparency = 1 })
			local aura = image("Aura", cell, TEXTURES.Glow, {
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.6, 1.6),
				ImageTransparency = 1,
				ZIndex = 1,
			})
			-- The holder narrows and widens to flip: a grid layout owns the cell's own size.
			local holder = make("Frame", "Holder", cell, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = WHITE,
				ZIndex = 2,
			})
			UiTheme.Corner(holder, "M")
			local gradient = UiTheme.Gradient(holder, Color3.fromRGB(70, 70, 95), NEAR_BLACK)
			local edge = make("UIStroke", "Edge", holder, {
				Thickness = 3,
				Color = WHITE,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
			local edgeRainbow = make("UIGradient", "Rainbow", edge, { Color = RAINBOW })
			local mark = caption("Mark", holder, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.6, 0.6),
				Text = "?",
				TextSize = 72,
				ZIndex = 3,
			})
			table.insert(cards, {
				Row = row,
				Result = result,
				Cell = cell,
				Aura = aura,
				Holder = holder,
				Gradient = gradient,
				Edge = edge,
				EdgeRainbow = edgeRainbow,
				Mark = mark,
			})
		end
		local function faceUp(card)
			if card.Up then
				return
			end
			card.Up = true
			local row, holder = card.Row, card.Holder
			local rarity = row and row.Rarity
			card.Mark:Destroy()
			local color = tellColor(rarity)
			card.Gradient.Color = ColorSequence.new(color:Lerp(BLACK, 0.15), NEAR_BLACK)
			if not BIG_MOMENT[rarity] then
				card.EdgeRainbow:Destroy()
				card.Edge.Color = color
			else
				card.EdgeRainbow.Enabled = true
				card.Edge.Color = WHITE
			end
			if BIG_MOMENT[rarity] or rarity == "Legendary" then
				card.Aura.ImageColor3 = color
				card.Aura.ImageTransparency = 0.25
				UiMotion.Pulse(card.Aura, { ImageTransparency = 0.6 }, 0.6)
			end
			modelView(holder, row, {
				Position = UDim2.fromScale(0, 0.14),
				Size = UDim2.fromScale(1, 0.66),
				ZIndex = 3,
			})
			caption("Name", holder, {
				Position = UDim2.fromScale(0.04, 0.03),
				Size = UDim2.fromScale(0.92, 0.15),
				Text = row and row.Name or "?",
				TextSize = 24,
				ZIndex = 4,
			})
			paintRarity(
				caption("Rarity", holder, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0.04, 0.98),
					Size = UDim2.fromScale(0.92, 0.17),
					Text = card.Result.Sold and row and string.format("SOLD +%d", row.SellGems) or rarity or "",
					TextSize = 24,
					ZIndex = 4,
				}),
				rarity
			)
		end
		-- The cards drop in from above with a tumble, one after another.
		if not skip then
			for _, card in cards do
				card.Holder.Position = UDim2.fromScale(0.5, -2)
				card.Holder.Rotation = math.random(-22, 22)
			end
			for _, card in cards do
				if skip then
					break
				end
				local fall = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				UiMotion.Create(card.Holder, fall, { Position = UDim2.fromScale(0.5, 0.5), Rotation = 0 }):Play()
				task.delay(0.2, function()
					shake(3, 0.1)
				end)
				pause(0.07)
			end
			pause(0.45)
		end
		for _, card in cards do
			if skip then
				break
			end
			local rarity = card.Row and card.Row.Rarity
			local color = tellColor(rarity)
			-- The tell: a card worth waiting for trembles and glows its colour before it turns.
			if BIG_MOMENT[rarity] or rarity == "Legendary" then
				card.EdgeRainbow.Enabled = false
				card.Edge.Color = color
				card.Edge.Thickness = 5
				card.Aura.ImageColor3 = color
				UiMotion.Create(card.Aura, TweenInfo.new(0.4), { ImageTransparency = 0.1 }):Play()
				UiMotion.Shake(card.Holder, 7, 0.42)
				shake(4, 0.3)
				pause(0.45)
				card.Holder.Position = UDim2.fromScale(0.5, 0.5)
			end
			if skip then
				break
			end
			UiMotion.Create(card.Holder, TweenInfo.new(0.07), { Size = UDim2.fromScale(0, 1) }):Play()
			pause(0.07)
			faceUp(card)
			UiMotion.Create(card.Holder, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
			UiFeedback.Play(landCue(rarity), card.Holder)
			flipbook("Ring", card.Cell, TEXTURES.Ring, 30, false, {
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.8, 1.8),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				ImageColor3 = color,
				ZIndex = 5,
			})
			local at = card.Cell.AbsolutePosition + card.Cell.AbsoluteSize / 2
			local viewport = gui.AbsoluteSize
			scatter(
				stage,
				UDim2.fromScale(at.X / viewport.X, at.Y / viewport.Y),
				FLIP_SPARKS[rarity] or 3,
				color,
				0.14,
				6
			)
			if BIG_MOMENT[rarity] then
				local layer = showcase(card.Row, card.Result)
				pause(SHOWCASE_HOLD)
				layer:Destroy()
				doFlash(0.2)
			else
				pause(FLIP_GAP[rarity] or FLIP_GAP.Common)
			end
		end
		-- A skip, or reduced effects, lands here with every card face up and the best one marked.
		local best, bestRank = nil, 0
		for _, card in cards do
			local rank = card.Row and table.find(GachaConfig.RARITY_ORDER, card.Row.Rarity) or 0
			if rank > bestRank then
				best, bestRank = card, rank
			end
			faceUp(card)
			card.Holder.Size = UDim2.fromScale(1, 1)
			card.Holder.Position = UDim2.fromScale(0.5, 0.5)
			card.Holder.Rotation = 0
		end
		if best then
			best.Edge.Thickness = 5
			UiMotion.Pop(best.Holder)
			UiMotion.Shine(best.Holder)
		end
	end

	UiTheme.Apply(gui)
	task.spawn(function()
		if #results > 1 and not chestImage then
			playMany()
		else
			playOne()
		end
		if not closed then
			finish()
		end
	end)
end

return Reveal
