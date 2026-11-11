--!nonstrict
-- Sidekick attacks at the boss (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks", docs/SIDEKICK_SPEC.md). Contract:
-- Client/UiTest/UiSidekickAttack. Visual only: it draws what Remotes.BossHits brings and nothing reads back into damage.
-- Poses come from Shared/SidekickAttacks; Client/SidekickFollower lays them over its follow motion. Effects use BossVfxArt's textures,
-- Neon parts and flat sprites, all in workspace.AttackEffects. All sizes, counts and colours are placeholders for the owner's capture.
-- A particle tops out near 100 studs and the boss is about 900 away, so shapes that must read at range are parts, and they grow in flight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Art = require(Shared:WaitForChild("BossVfxArt"))
local BossCatalog = require(Shared:WaitForChild("BossCatalog"))
local Attacks = require(Shared:WaitForChild("SidekickAttacks"))
local Catalog = require(Shared:WaitForChild("CharacterCatalog"))
local GachaConfig = require(Shared:WaitForChild("GachaConfig"))
local HudFormat = require(Shared:WaitForChild("HudFormat"))
local BossTeamRig = require(script.Parent:WaitForChild("BossTeamRig"))
local UiMotion = require(script.Parent:WaitForChild("UiMotion"))

local LEAD = 0.12 -- s from the batch to the first shot; a wind-up longer than this is entered part way
local FLIGHT = 0.28 -- s, so the impact lands 0.4 s after the batch
local BLEND_IN = 0.1 -- s from rest into a pose entered part way
local LINGER = 0.35 -- s a landed shot stays, invisible, for its particles and trail to die
local IMPACT_SECONDS = 1.2
local NUMBER_SECONDS = 1.1
local NUMBER_POP = 0.18 -- s of the pop out, placeholder
local NUMBER_DRIFT = 40 -- studs sideways at most, placeholder
local BUDGET = 400 -- particles alive at once, with 7 players (brief)
local REDUCED_BUDGET = 60 -- the same under REDUCED EFFECTS, proposed
local OTHERS_BUDGET = 0.5 -- of the budget: others' 18 characters stop adding there, so the local 3 still draw
local OTHERS = 0.3 -- of the counts for someone else's attack
local OTHERS_SIZE = 0.7
local SURFACE = 110 -- studs from the boss's chest toward the shooter: the hit shows on its near side
local JITTER = 30 -- studs, so that hits do not stack
-- Per boss when its BossCatalog row has AttackSurface / AttackJitter, else these (proposed: The Elf Mage's chest is about 12 studs
-- deep and her torso 21 tall); a boss with neither gets Big Raga's SURFACE and JITTER.
-- Impact: the size of every hit's effect at her; Smoke = false leaves out the unlit puffs (proposed, Studio verify 2026-11-11: a
-- 100-stud dark puff every 1.5 s, 7 studs in front of her 21-stud torso, hid her for most of the fight).
local AIM = {
	boss_mage = { Surface = 7, Jitter = 6, Impact = 0.4, Smoke = false },
	boss_golem = { Surface = 8, Jitter = 6 }, -- proposed: her Stone Golem, the target while it stands
}
local FLAP_OVERRIDE = 12 -- degrees off rest at which an attack's key has taken the wing from the flap
local TEXT_COLOR = Color3.fromRGB(255, 244, 200)
local C = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)) -- Blender's axes to Roblox's

local HOT, ORANGE, RED = Color3.fromRGB(255, 236, 200), Color3.fromRGB(255, 126, 36), Color3.fromRGB(226, 22, 34)
local DUST, DARK = Color3.fromRGB(216, 196, 164), Color3.fromRGB(34, 28, 40)
local WIND, PINK = Color3.fromRGB(198, 232, 255), Color3.fromRGB(255, 150, 190)
local BLUE, VIOLET = Color3.fromRGB(70, 110, 255), Color3.fromRGB(170, 70, 255)
local PAGE, CURSE = Color3.fromRGB(244, 240, 226), Color3.fromRGB(120, 30, 170)

-- Layers ---------------------------------------------------------------------------------------------------------------------------

-- A layer is { Count = burst, or Rate = per second while flying, Delay, Props }. Size lists stay plain numbers: others scale them.
local function flare(from, to, count, size, life, delay)
	return {
		Count = count,
		Delay = delay,
		Props = {
			Texture = Art.Flare,
			Color = ColorSequence.new(from, to),
			LightEmission = 1,
			Size = { 0, size * 0.6, 0.3, size, 1, size * 0.8 },
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(life * 0.7, life),
			Rotation = NumberRange.new(0, 360),
			Speed = NumberRange.new(0),
			ZOffset = 4,
		},
	}
end

local function sparks(from, to, count, size, life, speed, delay)
	return {
		Count = count,
		Delay = delay,
		Props = {
			Texture = Art.Spark,
			Color = ColorSequence.new(from, to),
			LightEmission = 1,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = { 0, size, 1, size * 0.1 },
			Lifetime = NumberRange.new(life * 0.5, life),
			Speed = NumberRange.new(speed * 0.5, speed),
			Drag = 1.2,
		},
	}
end

local function puff(from, to, count, size, life, speed, glow)
	return {
		Count = count,
		Props = {
			Texture = Art.Dust,
			Color = ColorSequence.new(from, to),
			LightEmission = glow or 0,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = { 0, size * 0.4, 1, size },
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.6, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(life * 0.6, life),
			Speed = NumberRange.new(speed * 0.4, speed),
			Drag = 2,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
		},
	}
end

-- Tumbling chips: stone, feathers or notebook pages, by colour and fall.
local function chips(color, count, size, life, speed, fall)
	return {
		Count = count,
		Props = {
			Texture = Art.Shard,
			Color = ColorSequence.new(color),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Size = { 0, size, 1, size * 0.7 },
			Lifetime = NumberRange.new(life * 0.6, life),
			Speed = NumberRange.new(speed * 0.4, speed),
			Acceleration = Vector3.new(0, -fall, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-320, 320),
		},
	}
end

-- A layer's particles leave the shot all through its flight.
local function flying(layer, rate)
	layer.Count, layer.Rate = nil, rate
	return layer
end

-- Recipes ---------------------------------------------------------------------------------------------------------------------------

-- Effect: its name. Color: the Neon core and trail. Core: studs across at the Sidekick, Grow: times that at the boss. Blade: the core is
-- a thin ellipse this many times wider than high, Tilt its degrees. Arc: studs up at mid flight. Sprites: { texture, colour, studs, degrees
-- a second }, flat and facing the camera. Rings at the impact: { from, to, seconds, colour, delay }. Streaks at the impact: { degrees,
-- length, width, colour, delay, starts this far off and closes on the point }.
local EFFECTS = {
	side_chain = {
		Effect = "SawBlade",
		Color = ORANGE,
		Core = 5,
		Grow = 7,
		Sprites = { { Art.Ring, HOT, 13, 1100 }, { Art.Flare, ORANGE, 12, -500 } },
		Muzzle = { sparks(HOT, ORANGE, 16, 5, 0.35, 90), flying(sparks(HOT, ORANGE, 0, 9, 0.3, 120), 40) },
		Impact = {
			flare(HOT, ORANGE, 3, 95, 0.25),
			sparks(HOT, ORANGE, 50, 30, 0.6, 620),
			puff(DARK, DARK, 8, 70, 0.9, 120),
		},
		Rings = { { 80, 520, 0.4, ORANGE, 0 } },
		Streaks = { { 30, 360, 26, ORANGE, 0 } },
	},
	side_pig = {
		Effect = "DustBurst",
		Color = DUST,
		Core = 7,
		Grow = 6,
		Sprites = { { Art.Flare, DUST, 15, 200 } },
		Muzzle = { puff(DUST, DUST, 14, 9, 0.5, 26), flying(puff(DUST, DUST, 0, 18, 0.4, 20), 20) },
		Impact = {
			flare(HOT, DUST, 2, 90, 0.25),
			puff(DUST, DARK, 34, 95, 1.0, 280),
			chips(DUST, 14, 20, 0.9, 340, 500),
		},
		Rings = { { 90, 600, 0.45, DUST, 0 } },
	},
	side_crow = {
		Effect = "WingGust",
		Color = WIND,
		Core = 6,
		Blade = 5,
		Tilt = -12,
		Grow = 8,
		Sprites = { { Art.Ring, WIND, 18, 0 } },
		Muzzle = { chips(DARK, 10, 2.5, 0.7, 26, 30), flying(sparks(WIND, WIND, 0, 12, 0.3, 90), 25) },
		Impact = {
			flare(WIND, WIND, 2, 80, 0.25),
			sparks(WIND, WIND, 24, 36, 0.5, 700),
			chips(DARK, 16, 18, 1.0, 300, 220),
		},
		Rings = { { 70, 480, 0.4, WIND, 0 }, { 70, 620, 0.5, WIND, 0.1 } },
	},
	side_dogs = {
		Effect = "ShadowBite",
		Color = VIOLET,
		Core = 5,
		Grow = 7,
		Sprites = { { Art.Flare, DARK, 16, 300 } },
		Muzzle = { puff(DARK, DARK, 8, 8, 0.4, 20), flying(puff(DARK, VIOLET, 0, 18, 0.35, 20), 20) },
		Impact = {
			flare(VIOLET, DARK, 2, 80, 0.25),
			puff(DARK, DARK, 16, 85, 0.8, 200),
			sparks(VIOLET, DARK, 10, 24, 0.4, 420),
		},
		Streaks = { { 0, 300, 44, DARK, 0, 90 }, { 180, 300, 44, DARK, 0, 90 } }, -- two jaws closing
	},
	side_reindeer = {
		Effect = "HoofShock",
		Color = PINK,
		Core = 5,
		Grow = 7,
		Sprites = { { Art.Ring, HOT, 14, 0 } },
		Muzzle = { sparks(HOT, PINK, 12, 6, 0.3, 90), flying(sparks(HOT, PINK, 0, 9, 0.25, 90), 30) },
		Impact = {
			flare(HOT, PINK, 3, 100, 0.25),
			puff(DUST, PINK, 26, 80, 0.9, 260),
			chips(DUST, 12, 18, 0.9, 340, 500),
		},
		Rings = { { 90, 760, 0.45, HOT, 0 }, { 90, 560, 0.45, PINK, 0.1 } },
	},
	side_ant = {
		Effect = "ClawFlurry",
		Color = BLUE,
		Core = 5,
		Blade = 4,
		Tilt = 45,
		Grow = 8,
		Sprites = {},
		Muzzle = { sparks(WIND, BLUE, 12, 5, 0.3, 80), flying(sparks(WIND, BLUE, 0, 12, 0.3, 90), 30) },
		Impact = {
			flare(WIND, BLUE, 2, 85, 0.2),
			sparks(WIND, BLUE, 14, 30, 0.45, 560),
			sparks(WIND, BLUE, 14, 30, 0.45, 560, 0.09),
			sparks(WIND, BLUE, 14, 30, 0.45, 560, 0.18),
		},
		Streaks = {
			{ 50, 380, 30, WIND, 0 },
			{ -50, 380, 30, BLUE, 0.09 },
			{ 80, 420, 30, WIND, 0.18 },
		},
	},
	side_reaper = {
		Effect = "NotebookPages",
		Color = PAGE,
		Core = 4,
		Grow = 8,
		Arc = 320, -- thrown up over the boss, so the pages fall on it
		Sprites = { { Art.Shard, PAGE, 11, 400 } },
		Muzzle = { chips(PAGE, 10, 3, 0.6, 26, 30), flying(chips(PAGE, 0, 11, 0.5, 40, 40), 30) },
		Impact = {
			flare(PAGE, PAGE, 2, 70, 0.25),
			chips(PAGE, 44, 34, 1.1, 300, 340),
			puff(DARK, DARK, 8, 60, 0.9, 90),
		},
	},
	side_fist = {
		Effect = "PunchBarrage",
		Color = VIOLET,
		Core = 6,
		Grow = 8,
		Sprites = { { Art.Flare, VIOLET, 16, 700 } },
		Muzzle = { flare(HOT, VIOLET, 6, 11, 0.2), flying(flare(HOT, VIOLET, 0, 16, 0.25), 24) },
		Impact = {
			flare(HOT, VIOLET, 4, 90, 0.16),
			flare(HOT, VIOLET, 4, 90, 0.16, 0.07),
			flare(HOT, VIOLET, 4, 90, 0.16, 0.14),
			flare(HOT, VIOLET, 4, 90, 0.16, 0.21),
			flare(HOT, VIOLET, 4, 90, 0.16, 0.28),
			sparks(HOT, VIOLET, 30, 30, 0.5, 620),
		},
		Rings = { { 70, 420, 0.25, VIOLET, 0 }, { 70, 420, 0.25, VIOLET, 0.14 }, { 70, 520, 0.3, VIOLET, 0.28 } },
	},
	side_wyvern = {
		Effect = "FlameBurst",
		Color = ORANGE,
		Core = 7,
		Grow = 8,
		Sprites = { { Art.Flare, ORANGE, 20, 200 } },
		Muzzle = { puff(HOT, ORANGE, 14, 9, 0.4, 40, 1), flying(puff(HOT, RED, 0, 24, 0.35, 30, 1), 50) },
		Impact = {
			flare(HOT, ORANGE, 3, 100, 0.3),
			puff(HOT, RED, 26, 100, 0.8, 300, 1),
			sparks(ORANGE, RED, 30, 22, 1.0, 460),
		},
		Rings = { { 80, 440, 0.4, ORANGE, 0 } },
	},
	side_knight = {
		Effect = "CrimsonSlash",
		Color = RED,
		Core = 7,
		Blade = 6,
		Tilt = 32,
		Grow = 9,
		Sprites = {},
		Muzzle = { sparks(RED, DARK, 12, 6, 0.3, 90), flying(sparks(RED, RED, 0, 14, 0.3, 90), 40) },
		Impact = {
			flare(HOT, RED, 3, 90, 0.2),
			sparks(HOT, RED, 34, 34, 0.55, 640),
			puff(DARK, RED, 10, 70, 0.8, 130),
		},
		Streaks = { { 32, 620, 42, RED, 0 }, { -32, 480, 26, HOT, 0.07 } },
	},
	side_curse = {
		Effect = "CursedScream",
		Color = CURSE,
		Core = 5,
		Grow = 7,
		Sprites = { { Art.Ring, VIOLET, 15, 0 }, { Art.Ring, CURSE, 24, 0 } },
		Muzzle = { flare(VIOLET, CURSE, 6, 12, 0.25), flying(puff(CURSE, DARK, 0, 22, 0.4, 30), 20) },
		Impact = {
			flare(VIOLET, CURSE, 2, 90, 0.3),
			puff(CURSE, DARK, 22, 90, 0.9, 240),
			sparks(VIOLET, CURSE, 16, 26, 0.5, 520),
		},
		Rings = { { 60, 560, 0.45, VIOLET, 0 }, { 60, 700, 0.5, CURSE, 0.12 }, { 60, 840, 0.55, VIOLET, 0.24 } },
	},
	side_fox = {
		Effect = "BeastBall",
		Color = BLUE,
		Core = 8,
		Grow = 9,
		Sprites = { { Art.Flare, VIOLET, 24, 500 }, { Art.Ring, BLUE, 26, 0 } },
		Muzzle = {
			flare(WIND, BLUE, 6, 18, 0.3),
			sparks(WIND, BLUE, 14, 7, 0.4, 110),
			flying(sparks(WIND, VIOLET, 0, 14, 0.3, 90), 30),
		},
		Impact = {
			flare(WIND, BLUE, 4, 100, 0.35),
			sparks(WIND, VIOLET, 42, 36, 0.7, 760),
			puff(DARK, VIOLET, 20, 100, 1.0, 340),
		},
		Rings = { { 110, 900, 0.55, BLUE, 0 }, { 110, 680, 0.5, WIND, 0.08 } },
	},
	-- design doc 4.37: no approved attack, so a simple shot and no pose, for the owner to rule on.
	side_raga = { Color = RED, Plain = true },
}

-- The shot of REDUCED EFFECTS and of side_raga, in the Sidekick's colour.
for _, row in EFFECTS do
	row.Simple = {
		Effect = "Simple",
		Color = row.Color,
		Core = 3,
		Grow = 6,
		Sprites = {},
		Muzzle = { flare(HOT, row.Color, 4, 7, 0.2) },
		Impact = { flare(HOT, row.Color, 8, 80, 0.25) },
	}
end

local player = Players.LocalPlayer
local folder = nil
local followers = {}
local shots = {} -- shots in the air
local live = 0 -- particles asked for by everything in the folder

local SidekickAttackView = {}

-- Helpers --------------------------------------------------------------------------------------------------------------------------

local function newPart(name, cframe, size, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function ellipse(part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function tween(instance, seconds, goal, style)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- What these layers ask for. Rate x lifetime is what the emitter can hold at once.
local function particlesOf(layers, mine)
	local total = 0
	for _, layer in layers or {} do
		if layer.Rate then
			total += layer.Rate * (mine and 1 or OTHERS) * layer.Props.Lifetime.Max
		else
			total += mine and layer.Count or math.ceil(layer.Count * OTHERS)
		end
	end
	return total
end

local function hasRoom(layers, mine)
	local budget = UiMotion.Reduced() and REDUCED_BUDGET or BUDGET
	return live + particlesOf(layers, mine) <= budget * (mine and 1 or OTHERS_BUDGET)
end

-- particles of a shot, particles of its impact, for the budget's books.
function SidekickAttackView.Particles(id, mine, simple)
	local row = EFFECTS[id]
	local recipe = (simple or row.Plain) and row.Simple or row
	return particlesOf(recipe.Muzzle, mine), particlesOf(recipe.Impact, mine)
end

local function addLayers(part, layers, mine, look)
	local grow = look and look.Impact or 1
	for _, layer in layers or {} do
		if look and look.Smoke == false and (layer.Props.LightEmission or 0) == 0 then
			continue
		end
		local e = Instance.new("ParticleEmitter")
		e.Enabled = layer.Rate ~= nil
		e.Rate = layer.Rate and layer.Rate * (mine and 1 or OTHERS) or 0
		e.LightInfluence = 0
		for key, value in layer.Props do
			if key ~= "Size" then
				e[key] = value
			end
		end
		local size, keys = layer.Props.Size, {}
		for i = 1, #size, 2 do
			table.insert(keys, NumberSequenceKeypoint.new(size[i], size[i + 1] * (mine and 1 or OTHERS_SIZE) * grow))
		end
		e.Size = NumberSequence.new(keys)
		e.Parent = part
		if layer.Count then
			-- After a beat: a just-parented emitter can drop an Emit.
			task.delay(0.03 + (layer.Delay or 0), function()
				if e.Parent then
					e:Emit(mine and layer.Count or math.ceil(layer.Count * OTHERS))
				end
			end)
		end
	end
end

local function faceCamera(position)
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or position + Vector3.new(0, 0, 1)
	return CFrame.lookAt(position, eye)
end

local function tagged(part, kind, hit, particles)
	part:SetAttribute("Kind", kind)
	part:SetAttribute("OwnerId", hit.UserId)
	part:SetAttribute("SidekickId", hit.SidekickId)
	part:SetAttribute("Particles", particles)
	live += particles
	task.delay(kind == "Impact" and IMPACT_SECONDS or FLIGHT + LINGER, function()
		live -= particles
		part:Destroy()
	end)
end

-- Where the attack lands now: the boss's target part (BigRaga's chest) when it is shown, else the arena's centre. While a Stone
-- Golem stands (BossMinionHp) the hits go to it.
local function bossPoint(from)
	local row = BossCatalog.Current()
	local golem = ReplicatedStorage:GetAttribute("BossMinionHp") ~= nil
	local aim = AIM[golem and "boss_golem" or row.Id] or {}
	local surface = not golem and row.AttackSurface or aim.Surface or SURFACE
	local jitter = not golem and row.AttackJitter or aim.Jitter or JITTER
	local arena = Workspace:FindFirstChild("BossArenaPreview")
	local boss = arena and arena:FindFirstChild(golem and "Golem" or row.ModelName)
	local chest = boss and boss:FindFirstChild(golem and "Torso" or row.TargetPart)
	local point = chest and chest.Transparency < 1 and chest.Position or Arena.For(row.Id).Center
	local flat = (from - point) * Vector3.new(1, 0, 1)
	local near = flat.Magnitude > 1 and flat.Unit * surface or Vector3.zero
	return point + near + Vector3.new(0, math.random(-jitter, jitter), 0)
end

-- Impact ---------------------------------------------------------------------------------------------------------------------------

local function damageNumber(impact, hit)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumber"
	gui.Size = UDim2.fromOffset(88, 29) -- pops up to its full size
	gui.AlwaysOnTop = true
	local drift = math.random(-NUMBER_DRIFT, NUMBER_DRIFT)
	gui.StudsOffsetWorldSpace = Vector3.new(drift * 0.2, 40, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	local character = Catalog.Get(hit.CharacterId)
	local colour = character and GachaConfig.RARITY_COLORS[character.Rarity] or Color3.new(1, 1, 1)
	label.TextColor3 = colour
	if colour.R + colour.G + colour.B < 0.6 then
		label.TextStrokeColor3 = Color3.new(1, 1, 1) -- a near-black Secret reads only on a light outline
	end
	label.TextStrokeTransparency = 0
	label.Text = HudFormat.Short(math.round(hit.Damage))
	label.Parent = gui
	gui.Parent = impact
	tween(gui, NUMBER_POP, { Size = UDim2.fromOffset(220, 72) }, Enum.EasingStyle.Back)
	tween(gui, NUMBER_SECONDS, { StudsOffsetWorldSpace = Vector3.new(drift, 170, 0) })
	task.delay(NUMBER_SECONDS * 0.6, function()
		tween(label, NUMBER_SECONDS * 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(NUMBER_SECONDS, function()
		gui:Destroy()
	end)
end

-- The number of a hit with no follower to draw it from: at the boss, when a shot would have landed.
local function numberAlone(hit)
	local impact =
		newPart("Impact", CFrame.new(bossPoint(Arena.For(BossCatalog.Current().Id).Center)), Vector3.new(30, 30, 30))
	tagged(impact, "Impact", hit, 0)
	impact.Parent = folder
	damageNumber(impact, hit)
end

local function addRing(impact, row, mine, grow)
	task.delay(row[5] or 0, function()
		if not impact.Parent then
			return
		end
		local to, seconds = row[2] * (mine and 1 or OTHERS_SIZE) * grow, row[3]
		local part =
			newPart("Ring", faceCamera(impact.Position), Vector3.new(row[1] * grow, row[1] * grow, 0.2), impact)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local d = Instance.new("Decal")
			d.Texture = Art.Ring
			d.Color3 = row[4]
			d.Face = face
			d.Parent = part
			tween(d, seconds, { Transparency = 1 })
		end
		tween(part, seconds, { Size = Vector3.new(to, to, 0.2) }, Enum.EasingStyle.Quart)
	end)
end

local function addStreak(impact, row, mine, grow)
	task.delay(row[5] or 0, function()
		if not impact.Parent then
			return
		end
		local scale = (mine and 1 or OTHERS_SIZE) * grow
		local length, width = row[2] * scale, row[3] * scale
		local base = faceCamera(impact.Position) * CFrame.Angles(0, 0, math.rad(row[1]))
		local part =
			newPart("Streak", base * CFrame.new(0, row[6] or 0, 0), Vector3.new(length * 0.3, width, 1), impact)
		part.Material = Enum.Material.Neon
		part.Color = row[4]
		part.Transparency = 0
		ellipse(part)
		local goal = { Size = Vector3.new(length, width * 0.25, 1), Transparency = 1, CFrame = base }
		tween(part, 0.28, goal)
	end)
end

local function land(shot)
	local hit, recipe, mine = shot.Hit, shot.Recipe, shot.Mine
	local point = shot.Target
	local particles = hasRoom(recipe.Impact, mine) and recipe.Impact or nil
	local impact = newPart("Impact", CFrame.new(point), Vector3.new(30, 30, 30))
	tagged(impact, "Impact", hit, particlesOf(particles, mine))
	impact.Parent = folder
	local look = AIM[BossCatalog.Current().Id]
	local grow = look and look.Impact or 1
	addLayers(impact, particles, mine, look)
	for i, row in recipe.Rings or {} do
		if mine or i == 1 then
			addRing(impact, row, mine, grow)
		end
	end
	for i, row in recipe.Streaks or {} do
		if mine or i == 1 then
			addStreak(impact, row, mine, grow)
		end
	end
	if shot.Number then
		damageNumber(impact, hit)
	end
end

-- Shot -----------------------------------------------------------------------------------------------------------------------------

local function launch(hit, follower, recipe, mine, number)
	local source = follower.Parts[1]
	if not (source and source.Parent) then
		if number then
			task.delay(FLIGHT, numberAlone, hit)
		end
		return
	end
	local from = source.Position
	local scale = mine and 1 or OTHERS_SIZE
	local core = recipe.Core * scale
	local size = recipe.Blade and Vector3.new(core * recipe.Blade, core * 0.45, 1) or Vector3.one * core
	local part = newPart("Shot", faceCamera(from), size)
	if recipe.Blade then
		ellipse(part)
	else
		part.Shape = Enum.PartType.Ball
	end
	part.Material = Enum.Material.Neon
	part.Color = recipe.Color
	part.Transparency = 0
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Parent, bottom.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(HOT, recipe.Color)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Lifetime = 0.22
	trail.MinLength = 0
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = part
	local sprites = {}
	for i, row in recipe.Sprites do
		if mine or i == 1 then
			local sprite = newPart("Sprite", part.CFrame, Vector3.new(row[3] * scale, row[3] * scale, 0.2), part)
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local d = Instance.new("Decal")
				d.Texture = row[1]
				d.Color3 = row[2]
				d.Face = face
				d.Parent = sprite
			end
			table.insert(sprites, { Part = sprite, Size = sprite.Size, Spin = math.rad(row[4]) })
		end
	end
	local layers = hasRoom(recipe.Muzzle, mine) and recipe.Muzzle or nil
	tagged(part, "Shot", hit, particlesOf(layers, mine))
	part:SetAttribute("Effect", recipe.Effect)
	part.Parent = folder
	addLayers(part, layers, mine)
	table.insert(shots, {
		Part = part,
		Hit = hit,
		Recipe = recipe,
		Mine = mine,
		Number = number,
		Source = source,
		From = from,
		Target = bossPoint(from),
		Started = os.clock(),
		Size = size,
		Top = top,
		Bottom = bottom,
		Trail = trail,
		Sprites = sprites,
		Width = core * 0.8,
	})
end

local function stepShots(now)
	for i = #shots, 1, -1 do
		local shot = shots[i]
		local since = now - shot.Started
		local u = math.min(since / FLIGHT, 1)
		if shot.Source.Parent then
			shot.From = shot.Source.Position -- from the Sidekick as it runs
		end
		local eased = u ^ 1.7 -- slow out of the Sidekick, so it is seen leaving
		local arc = (shot.Recipe.Arc or 0) * 4 * u * (1 - u)
		local position = shot.From:Lerp(shot.Target, eased) + Vector3.new(0, arc, 0)
		local grow = 1 + (shot.Recipe.Grow - 1) * eased
		local part = shot.Part
		local cframe = faceCamera(position) * CFrame.Angles(0, 0, math.rad(shot.Recipe.Tilt or 0))
		part.Size = shot.Size * grow
		part.CFrame = cframe
		local half = shot.Width * grow / 2
		shot.Top.Position, shot.Bottom.Position = Vector3.new(0, half, 0), Vector3.new(0, -half, 0)
		for _, sprite in shot.Sprites do
			sprite.Part.Size = sprite.Size * Vector3.new(grow, grow, 1)
			sprite.Part.CFrame = cframe * CFrame.Angles(0, 0, sprite.Spin * since)
		end
		if u >= 1 then
			table.remove(shots, i)
			part.Transparency = 1
			for _, sprite in shot.Sprites do
				sprite.Part:Destroy()
			end
			for _, child in part:GetChildren() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			land(shot)
		end
	end
end

-- Pose -----------------------------------------------------------------------------------------------------------------------------

-- Ties the keys' model units and pivots to this follower's scaled parts. False if the model does not match the rig.
local function bindPose(follower)
	local attack = Attacks.Attacks[follower.Id]
	local indexOf = {}
	for i, part in follower.Parts do
		indexOf[part.Name] = i
	end
	local known = {}
	for _, row in attack.Rig do
		known[row.Name] = true
	end
	for name in indexOf do
		if not known[name] then
			return false
		end
	end
	local fit = attack.Fit
	local i = indexOf[fit.Part]
	if not i then
		return false
	end
	-- A MeshPart sits at the centre of its mesh's box, which is how an unturned root fixes the scale and the origin.
	local scale = follower.Parts[i].Size.Y / fit.Height
	local center = Vector3.new(fit.Center[1], fit.Center[2], fit.Center[3]) * scale
	local world = CFrame.new(follower.Rests[i].Position - C:VectorToWorldSpace(center)) * C
	local restParts, restRoots = Attacks.Sample(follower.Id, 0)
	local inverse = {}
	for name, frame in Attacks.Frames(follower.Id, restParts, restRoots, scale) do
		inverse[name] = frame:Inverse()
	end
	return {
		Scale = scale,
		World = world,
		WorldInverse = world:Inverse(),
		Rest = restParts,
		RestInverse = inverse,
		Pose = table.create(#follower.Parts),
		Flaps = table.create(#follower.Parts),
	}
end

local function startPose(follower, id)
	local attack = Attacks.Attacks[id]
	if follower.Id ~= id or follower.Attack or not attack.Rig then
		return
	end
	if follower.AttackBind == nil then
		follower.AttackBind = bindPose(follower)
	end
	if follower.AttackBind then
		follower.Attack = { Started = os.clock(), From = math.max(0, attack.Release[1] - LEAD) }
	end
end

-- For Client/SidekickFollower: part index -> a turn to apply in the model's space, and part index -> how much of the wing's flap stays.
-- nil outside an attack. Both ends of an attack are rest, so nothing snaps when this starts or stops returning.
function SidekickAttackView.Pose(follower, now)
	local attack = follower.Attack
	if not attack then
		return nil
	end
	local since = now - attack.Started
	local t = attack.From + since
	if t >= Attacks.Attacks[follower.Id].Duration then
		follower.Attack = nil
		return nil
	end
	local bind = follower.AttackBind
	local parts, roots = Attacks.Sample(follower.Id, t)
	local frames = Attacks.Frames(follower.Id, parts, roots, bind.Scale)
	local weight = math.min(since / BLEND_IN, 1)
	for i, part in follower.Parts do
		local name = part.Name
		local turn = bind.World * frames[name] * bind.RestInverse[name] * bind.WorldInverse
		bind.Pose[i] = weight < 1 and CFrame.new():Lerp(turn, weight) or turn
		local off = parts[name] - bind.Rest[name]
		local largest = math.max(math.abs(off.X), math.abs(off.Y), math.abs(off.Z))
		bind.Flaps[i] = math.clamp(1 - largest / FLAP_OVERRIDE, 0, 1)
	end
	return bind.Pose, bind.Flaps
end

-- Hits -----------------------------------------------------------------------------------------------------------------------------

-- The batch's drawable hits, one attack each.
local function ordered(entries)
	local list = {}
	for _, entry in entries do
		if type(entry) == "table" and EFFECTS[entry.SidekickId] then
			table.insert(list, entry)
		end
	end
	-- The local player's first: the budget favours what it wants most visible.
	table.sort(list, function(a, b)
		return a.UserId == player.UserId and b.UserId ~= player.UserId
	end)
	return list
end

-- That character's own follower (BOSS_EVENT_SPEC "Run rules"). The line's front has no rig, and a rig past the follower budget falls back
-- to the front's.
local function shooter(hit)
	return hit.Slot and followers[BossTeamRig.Owner(hit.UserId, hit.Slot)] or followers[hit.UserId]
end

local function onHits(entries)
	if type(entries) ~= "table" or not folder then
		return
	end
	local reduced = UiMotion.Reduced()
	for _, hit in ordered(entries) do
		local id = hit.SidekickId
		local follower = shooter(hit)
		if not follower or follower.Hidden then
			task.delay(LEAD + FLIGHT, numberAlone, hit)
		else
			local row = EFFECTS[id]
			local simple = reduced or row.Plain
			local recipe = simple and row.Simple or row
			local mine = hit.UserId == player.UserId
			if not reduced then
				startPose(follower, id)
			end
			local release = Attacks.Attacks[id].Release
			for i, at in release do
				if i == 1 or not simple then
					task.delay(LEAD + at - release[1], launch, hit, follower, recipe, mine, i == 1)
				end
			end
		end
	end
end

-- followers: Client/SidekickFollower's table, owner UserId -> follower.
function SidekickAttackView.Start(list)
	followers = list
	folder = Instance.new("Folder")
	folder.Name = "AttackEffects"
	folder.Parent = Workspace
	RunService.Heartbeat:Connect(function()
		stepShots(os.clock())
	end)
	task.spawn(function()
		ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BossHits").OnClientEvent:Connect(onHits)
	end)
end

return SidekickAttackView
