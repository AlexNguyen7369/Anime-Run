--!nonstrict
-- The live boss and its effects (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks"; task b7b). Owned by
-- ui-test-writer. ui_boss_vfx drives the published attributes through UiTestSetup boss_ui_*, as ui_boss does.
--
-- Contract these checks assume beyond the brief (implementer: report a change, do not loosen):
--   workspace.BossArenaPreview holds, at any depth, a Model BigRaga with parts Wheel, LeftFoot and RightFoot, built with the
--   arena, and no BossStandIn or WheelStandIn. Before the spawn every BigRaga part has Transparency 1.
--   workspace.BossArenaPreview holds, at any depth, a Folder BossEffects; every effect lives in it.
--   Client-local ReplicatedStorage attribute BossVfxForce: not nil holds off scheduled effects; a change to an event name
--   (Impact, Roar, WheelClick) plays that event at once; "" plays nothing. nil returns to the schedule.
--   BossEffects attribute LastParticles: particles the last event asked for, emitted and by Rate, reduced or not.
--   Impact makes at least one BasePart named Shockwave in BossEffects, reduced or not.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared:WaitForChild("BossArenaConfig"))
local Cfg = require(Shared:WaitForChild("BossEventConfig"))

local FORCE = "BossVfxForce"
local BUILD_WAIT = 8 -- s: the arena builds over frames, and the state replicates
local SETTLE_WAIT = 2 -- s
local EVENTS = { "Impact", "Roar", "WheelClick" }
local HEIGHT_SLACK = 8 -- studs, the brief's +-8
local FULL_HEIGHT = 804 * Arena.BossScale -- the model's feet to wheel top, times the owner's BossScale. The head top is about 560 before the scale; the mesh named Head reads higher, it holds the wings
local IDLE_NEEDED = 2 -- s of idle kept for the height read
local IDLE_SEARCH = 120 -- s after the rise
local PEAK_WATCH = 1 -- s an effect is watched for its peak
local CLEAN_SECONDS = 6 -- s, the brief's limit
local MAX_EMITTERS, MAX_PARTICLES = 12, 150 -- proposed, a phone's budget in a server of many players
local REDUCED_EMITTERS, REDUCED_PARTICLES = 3, 30 -- proposed
local BUDGET = 60 -- s: the whole scenario

local Module = {}

function Module.Build(h)
	local scenarios = {}

	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function state(res, phase, elapsed)
		setup(res, ("boss_ui_state:%s:%s:4000:4000:true:100"):format(phase, tostring(elapsed)))
	end

	local function arena()
		return workspace:FindFirstChild("BossArenaPreview")
	end
	local function inArena(name)
		local folder = arena()
		return folder and folder:FindFirstChild(name, true)
	end
	local function waitFor(fn, seconds)
		local deadline = os.clock() + seconds
		local value = fn()
		while not value and os.clock() < deadline do
			task.wait(0.05)
			value = fn()
		end
		return value
	end

	local function shownParts(model)
		local count = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				count += 1
			end
		end
		return count
	end

	local function verticalHalf(part)
		local cf, s = part.CFrame, part.Size
		return (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
	end
	local function wheelTop(model)
		local wheel = model:FindFirstChild("Wheel", true)
		return wheel and wheel.Position.Y + verticalHalf(wheel)
	end
	local function feetBottom(model)
		local left, right = model:FindFirstChild("LeftFoot", true), model:FindFirstChild("RightFoot", true)
		return left and right and math.min(left.Position.Y - verticalHalf(left), right.Position.Y - verticalHalf(right))
	end

	local function noPhysics(res, tag, root)
		local bad = 0
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and (d.CanCollide or d.CanQuery) then
				bad += 1
			end
		end
		h.check(res, tag .. "_no_cancollide_or_canquery", bad, 0, bad == 0)
	end

	-- Seconds after the spawn at which idle holds for IDLE_NEEDED: Schedule is pure, so any start gives the same answer.
	local function idleSpell(Poses)
		local spawnAt = 0
		for e = Cfg.IntroSeconds + 1, Cfg.IntroSeconds + IDLE_SEARCH, 0.25 do
			local all = true
			for t = 0, IDLE_NEEDED, 0.25 do
				all = all and Poses.Schedule(spawnAt, e + t) == "idle"
			end
			if all then
				return e
			end
		end
		return nil
	end

	local function checkRise(res, Poses)
		state(res, "Idle", 0)
		task.wait(0.2)
		state(res, "Prep", 5)
		local model = waitFor(function()
			return inArena("BigRaga")
		end, BUILD_WAIT)
		h.check(res, "boss_model_present", model ~= nil, true, model ~= nil)
		if not model then
			return nil
		end
		h.check(res, "boss_is_a_model", model.ClassName, "Model", model:IsA("Model"))
		h.check(res, "standin_gone", inArena("BossStandIn"), nil, inArena("BossStandIn") == nil)
		h.check(res, "wheel_standin_gone", inArena("WheelStandIn"), nil, inArena("WheelStandIn") == nil)
		local hidden = shownParts(model)
		h.check(res, "boss_hidden_before_spawn", hidden, 0, hidden == 0)

		local fullTop = Arena.DaisY + FULL_HEIGHT
		if not GuiService.ReducedMotionEnabled then
			state(res, "Fight", Cfg.PrepSeconds + Cfg.RiseSeconds / 4) -- early: the rise is over in RiseSeconds, well inside the intro
			local shown = waitFor(function()
				return shownParts(model) > 0
			end, SETTLE_WAIT)
			h.check(res, "boss_shown_in_rise", shown, true, shown == true)
			local top = wheelTop(model)
			h.check(
				res,
				"boss_below_full_height_in_rise",
				top,
				"< " .. fullTop,
				top ~= nil and top < fullTop - HEIGHT_SLACK
			)
		end

		local spell = idleSpell(Poses)
		h.check(res, "schedule_has_idle_spell", spell ~= nil, true, spell ~= nil)
		state(res, "Fight", Cfg.PrepSeconds + (spell or Cfg.IntroSeconds + 5))
		task.wait(0.5)
		local top, bottom = wheelTop(model), feetBottom(model)
		h.check(
			res,
			"boss_wheel_at_full_height",
			top and top - Arena.DaisY,
			FULL_HEIGHT .. " +-" .. HEIGHT_SLACK,
			top ~= nil and math.abs(top - fullTop) <= HEIGHT_SLACK
		)
		h.check(
			res,
			"boss_feet_on_dais",
			bottom and bottom - Arena.DaisY,
			"0 +-" .. HEIGHT_SLACK,
			bottom ~= nil and math.abs(bottom - Arena.DaisY) <= HEIGHT_SLACK
		)
		noPhysics(res, "boss", model)
		return model
	end

	-- Plays one event; returns the peak emitter count, whether a Shockwave showed, LastParticles and the seconds to clean.
	local function fire(res, tag, name)
		ReplicatedStorage:SetAttribute(FORCE, "")
		task.wait() -- deferred signals: the listener must read "" before the name, or it plays the name twice
		ReplicatedStorage:SetAttribute(FORCE, name)
		local emitters, shockwave, effects, judged = 0, false, nil, false
		local stop = os.clock() + PEAK_WATCH
		local started = os.clock()
		while os.clock() < stop do
			effects = inArena("BossEffects")
			if effects then
				local count = 0
				for _, d in effects:GetDescendants() do
					if d:IsA("ParticleEmitter") then
						count += 1
					elseif d:IsA("BasePart") and d.Name == "Shockwave" then
						shockwave = true
					end
				end
				emitters = math.max(emitters, count)
				if not judged and #effects:GetChildren() > 0 then
					judged = true
					noPhysics(res, tag, effects)
				end
			end
			task.wait(0.1)
		end
		h.check(res, tag .. "_effects_folder", effects ~= nil, true, effects ~= nil)
		local clean = waitFor(function()
			return effects ~= nil and #effects:GetChildren() == 0
		end, CLEAN_SECONDS - (os.clock() - started))
		h.check(res, tag .. "_cleans_up", os.clock() - started, "<= " .. CLEAN_SECONDS, clean == true)
		return emitters, shockwave, effects and effects:GetAttribute("LastParticles")
	end

	local function checkEffects(res, reduced)
		local tagBase = reduced and "reduced_" or "full_"
		local maxEmitters = reduced and REDUCED_EMITTERS or MAX_EMITTERS
		local maxParticles = reduced and REDUCED_PARTICLES or MAX_PARTICLES
		for _, name in EVENTS do
			local tag = tagBase .. string.lower(name)
			local emitters, shockwave, particles = fire(res, tag, name)
			h.check(res, tag .. "_emitters", emitters, "<= " .. maxEmitters, emitters <= maxEmitters)
			h.check(
				res,
				tag .. "_particles",
				particles,
				"<= " .. maxParticles,
				type(particles) == "number" and particles <= maxParticles
			)
			if name == "Impact" then
				h.check(res, tag .. "_has_shockwave", shockwave, true, shockwave)
			end
		end
	end

	function scenarios.ui_boss_vfx(res)
		local loaded, Poses = pcall(function()
			return require(Shared:FindFirstChild("BossRagaPoses"))
		end)
		h.check(res, "poses_module_loads", loaded, true, loaded)
		if not loaded then
			return
		end
		local started = os.clock()
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			-- The height and the full-strength limits are judged with the toggle off, whatever the player had.
			h.player:SetAttribute("ReduceEffects", nil)
			if checkRise(res, Poses) then
				checkEffects(res, false)
				h.player:SetAttribute("ReduceEffects", true)
				checkEffects(res, true)
			end
		end, debug.traceback)
		h.check(res, "vfx_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute(FORCE, nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		setup(res, "restore:boss_ui")
		local spent = os.clock() - started
		h.check(res, "vfx_scenario_time", spent, "< " .. BUDGET, spent < BUDGET)
	end

	return { Scenarios = scenarios }
end

return Module
