--!nonstrict
-- The arena-wide impact layer of the Elf Mage, her Stone Golem and the Golden King (design doc 4.37 "Animation rework", owner
-- 2026-11-12; docs/BOSS_EVENT_SPEC.md "Animation rework", bullet "Impact layer, arena-wide", values proposed). Owned by
-- ui-test-writer. Red first (goal boss-anim-rework, task a5a). Big Raga is not part of the rework: his checks stay in UiBossVfx.
-- Driven by the same UiTestSetup boss_ui_* fixtures and BossVfxForce as UiBossMage / UiBossKing.
--
-- Contract these checks assume beyond the brief (implementer: build to this, report a change, do not loosen):
--   DEBUG FIELD LastImpact: string attribute on the arena's BossEffects folder, JSON
--     {"Move":<the BossVfxForce name: "Slam"|"Sweep"|"Lightning"|"Barrage"|"Gates"|"Enuma">,
--      "Hits":[{"T":<s after the move's first hit>,"Flash":"Full"|"Low"|"None","Kick":<deg>,"Full":<deg>,"Shift":<studs>,
--               "Distance":<studs>,"Lights":<n>},...]}
--     Written (and rewritten) as the move plays, one row per boss hit drawn on this client; a new move starts a new log.
--     Kick: the rotation kick this client's camera got for the hit, after any distance scaling. Full: that hit's kick at the
--     strike spot (no scaling). Shift: the positional kick, studs. Distance: camera to the strike spot. Lights: arena lights
--     pulsed by the hit (a full flash pulses them once). Under REDUCED EFFECTS (UiMotion.Reduced, which also covers Roblox
--     Reduced Motion) every hit is still logged, with Flash "None", Kick 0, Shift 0 and Lights 0.
--   A full flash adds one new ColorCorrectionEffect named BossImpactFlash to Lighting (gone again within FLASH_GONE s); a low
--   pulse never adds one (name its effect anything else, e.g. BossImpactPulse).
--   Single-hit moves (Slam, Sweep, Enuma): one hit, a full flash. Strike windows (Lightning, Barrage, Gates): one hit per
--   strike (14, 0.15 s apart, as LastStrikes), a full flash on the first strike only, a low pulse on each other strike, never
--   more than 3 full flashes in any 1 s.
--   Owner 2026-11-12 correction (coordinator, rules audit): no field-of-view punch; the event FOV stays locked through a hit
--     (design doc 4.37, owner 2026-11-06, BOSS_EVENT_SPEC "event FOV locked at 100").
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("BossEventConfig"))

local FORCE = "BossVfxForce"
local FLASH = "BossImpactFlash"
local KICK_FLOOR = 0.5 -- BOSS_EVENT_SPEC "Impact layer, arena-wide": the kick never under 0.5 x the full one (proposed)
local STRIKE_COUNT, STRIKE_EVERY, STRIKE_TIME_SLACK = 14, 0.15, 0.02 -- owner 2026-11-11, unchanged by the rework
local MAX_FULL_PER_SECOND = 3
local FLASH_GONE = 0.6 -- s: a 0.1 s pulse plus its fade, generous
local FOV_SLACK = 0.01 -- degrees
local BUILD_WAIT = 8
local MOVE_WAIT = 8 -- s: the longest lead (Enuma's charge) plus the 2 s window
local SETTLE = 0.5 -- s after the last expected hit, to catch an extra one
local KICK_EPS = 1e-3
local ARENA_BUILD_WAIT = 15 -- s: the whole arena, torches last
local LIGHTS_STABLE = 1 -- s the arena's Light count must hold before the first move

local Module = {}

function Module.Build(h)
	local scenarios = {}
	local function check(res, name, got, want)
		h.check(res, name, got, want, got == want)
	end
	local function setup(res, request)
		local ok, err = h.requestSetup(request)
		if not ok then
			h.check(res, "setup_" .. request, tostring(err), "ok", false)
		end
	end
	local function state(res, phase, elapsed)
		setup(res, ("boss_ui_state:%s:%s:4000:4000:true:100"):format(phase, tostring(elapsed)))
	end
	local function inArena(name)
		local folder = workspace:FindFirstChild("BossArenaPreview")
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
	local function readLog()
		local holder = inArena("BossEffects")
		local raw = holder and holder:GetAttribute("LastImpact")
		local decoded, log = pcall(HttpService.JSONDecode, HttpService, raw or "")
		return decoded and type(log) == "table" and log or nil
	end

	-- Plays `name` and watches it: its LastImpact log once `hits` hits are in (plus SETTLE), the BossImpactFlash effects added
	-- to Lighting, the most the camera's FOV moved off its value before the move, and whether every flash went away.
	local function play(name, hits)
		ReplicatedStorage:SetAttribute(FORCE, "")
		task.wait()
		local holder = inArena("BossEffects")
		if holder then
			holder:SetAttribute("LastImpact", nil)
		end
		local camera = workspace.CurrentCamera
		local fov0 = camera and camera.FieldOfView or 0
		local flashes, fovOff = {}, 0
		local added = Lighting.ChildAdded:Connect(function(child)
			if child.Name == FLASH and child:IsA("ColorCorrectionEffect") then
				table.insert(flashes, child)
			end
		end)
		ReplicatedStorage:SetAttribute(FORCE, name)
		local deadline, doneAt = os.clock() + MOVE_WAIT, nil
		while os.clock() < deadline and not (doneAt and os.clock() >= doneAt) do
			task.wait()
			camera = workspace.CurrentCamera
			fovOff = math.max(fovOff, camera and math.abs(camera.FieldOfView - fov0) or 0)
			local log = readLog()
			if not doneAt and log and log.Move == name and type(log.Hits) == "table" and #log.Hits >= hits then
				doneAt = os.clock() + SETTLE
			end
		end
		task.wait(FLASH_GONE)
		added:Disconnect()
		local lingering = 0
		for _, effect in flashes do
			lingering += effect.Parent and 1 or 0
		end
		return readLog(), #flashes, fovOff, lingering
	end

	-- The rule for one move, full effects. tag e.g. "mage_slam".
	local function checkFull(res, tag, name, hits)
		local log, flashes, fovOff, lingering = play(name, hits)
		check(res, tag .. "_impact_log", log ~= nil and log.Move, name)
		local list = log and type(log.Hits) == "table" and log.Hits or {}
		check(res, tag .. "_hit_count", #list, hits)
		local weak, still, unlit = {}, {}, {}
		local full, fullTimes, badFlash, offTime = 0, {}, {}, {}
		for k, hit in list do
			local kick, spot = tonumber(hit.Kick) or 0, tonumber(hit.Full) or 0
			-- every fighter, near or far: at least 0.5 x the kick at the spot (BOSS_EVENT_SPEC "Impact layer, arena-wide")
			if spot <= 0 or kick < KICK_FLOOR * spot - KICK_EPS then
				table.insert(weak, ("%d: %.3f of %.3f at %s studs"):format(k, kick, spot, tostring(hit.Distance)))
			end
			if (tonumber(hit.Shift) or 0) <= 0 then
				table.insert(still, tostring(k))
			end
			local want = k == 1 and "Full" or "Low"
			if hit.Flash ~= want then
				table.insert(badFlash, ("%d is %s, want %s"):format(k, tostring(hit.Flash), want))
			end
			if hit.Flash == "Full" then
				full += 1
				table.insert(fullTimes, tonumber(hit.T) or 0)
				if (tonumber(hit.Lights) or 0) <= 0 then
					table.insert(unlit, tostring(k))
				end
			end
			if hits > 1 then
				local at = STRIKE_EVERY * (k - 1)
				if type(hit.T) ~= "number" or math.abs(hit.T - at) > STRIKE_TIME_SLACK then
					table.insert(offTime, ("%d at %s, want %.2f"):format(k, tostring(hit.T), at))
				end
			end
		end
		h.checkList(res, tag .. "_kick_floor_0_5", weak)
		h.checkList(res, tag .. "_positional_kick", still)
		h.checkList(res, tag .. (hits > 1 and "_full_first_then_low" or "_full_flash"), badFlash)
		h.checkList(res, tag .. "_full_flash_pulses_lights", unlit)
		if hits > 1 then
			h.checkList(res, tag .. "_hits_every_0_15", offTime)
			local most = 0
			for _, t in fullTimes do
				local n = 0
				for _, u in fullTimes do
					n += (u >= t and u < t + 1) and 1 or 0
				end
				most = math.max(most, n)
			end
			h.check(
				res,
				tag .. "_at_most_3_full_per_second",
				most,
				"<= " .. MAX_FULL_PER_SECOND,
				most <= MAX_FULL_PER_SECOND
			)
		end
		-- one arena-wide flash per full flash in the log: a BossImpactFlash in Lighting, gone after its pulse
		h.check(res, tag .. "_one_flash_effect", flashes, 1, flashes == 1 and full == 1)
		check(res, tag .. "_flash_effect_gone", lingering, 0)
		h.check(res, tag .. "_fov_stays_locked", fovOff, "<= " .. FOV_SLACK, fovOff <= FOV_SLACK)
	end

	-- REDUCED EFFECTS: the hits still happen and are logged, with no flash and no shake.
	local function checkReduced(res, tag, name, hits)
		local log, flashes, fovOff = play(name, hits)
		local list = log and type(log.Hits) == "table" and log.Hits or {}
		check(res, tag .. "_reduced_hit_count", #list, hits)
		local loud = {}
		for k, hit in list do
			if
				hit.Flash ~= "None"
				or (tonumber(hit.Kick) or 0) ~= 0
				or (tonumber(hit.Shift) or 0) ~= 0
				or (tonumber(hit.Lights) or 0) ~= 0
			then
				table.insert(
					loud,
					("%d: Flash %s Kick %s Shift %s Lights %s"):format(
						k,
						tostring(hit.Flash),
						tostring(hit.Kick),
						tostring(hit.Shift),
						tostring(hit.Lights)
					)
				)
			end
		end
		h.checkList(res, tag .. "_reduced_no_flash_no_shake", loud)
		check(res, tag .. "_reduced_no_flash_effect", flashes, 0)
		h.check(res, tag .. "_reduced_fov_stays_locked", fovOff, "<= " .. FOV_SLACK, fovOff <= FOV_SLACK)
	end

	local MOVES = {
		boss_mage = {
			Model = "ElfMage",
			Minion = true, -- the golem stands for Slam and Sweep
			{ "mage_lightning", "Lightning", STRIKE_COUNT },
			{ "mage_barrage", "Barrage", STRIKE_COUNT },
			{ "golem_slam", "Slam", 1 },
			{ "golem_sweep", "Sweep", 1 },
		},
		boss_king = {
			Model = "GoldenKing",
			{ "king_gates", "Gates", STRIKE_COUNT },
			{ "king_enuma", "Enuma", 1 },
		},
	}

	-- True once the arena's own Lights (outside BossEffects) number above 0 and hold still for LIGHTS_STABLE s; false after
	-- ARENA_BUILD_WAIT.
	local function arenaBuilt()
		local deadline = os.clock() + ARENA_BUILD_WAIT
		local last, since = -1, os.clock()
		while os.clock() < deadline do
			local folder = workspace:FindFirstChild("BossArenaPreview")
			local effects = inArena("BossEffects")
			local n = 0
			for _, d in folder and folder:GetDescendants() or {} do
				if d:IsA("Light") and not (effects and d:IsDescendantOf(effects)) then
					n += 1
				end
			end
			if n ~= last then
				last, since = n, os.clock()
			elseif n > 0 and os.clock() - since >= LIGHTS_STABLE then
				return true
			end
			task.wait(0.05)
		end
		return false
	end

	function scenarios.ui_boss_impact(res)
		local savedReduce = h.player:GetAttribute("ReduceEffects")
		local ok, err = xpcall(function()
			setup(res, "boss_ui_gear:2")
			for _, id in { "boss_mage", "boss_king" } do
				local moves = MOVES[id]
				h.player:SetAttribute("ReduceEffects", nil)
				state(res, "Idle", 0)
				setup(res, "boss_ui_boss:" .. id)
				state(res, "Prep", 5)
				local model = waitFor(function()
					return inArena(moves.Model)
				end, BUILD_WAIT)
				check(res, id .. "_impact_model_present", model ~= nil, true)
				-- The arena builds over frames and its torches come near the end; a real event's Prep covers that. No build-done
				-- signal exists for both arenas, so: its Light count above 0 and unchanged for LIGHTS_STABLE s.
				local built = model ~= nil and arenaBuilt()
				check(res, id .. "_arena_built", built, true)
				if model and built then
					state(res, "Fight", Cfg.PrepSeconds + Cfg.IntroSeconds + 1)
					if moves.Minion then
						setup(res, "boss_ui_minion:640,1000")
					end
					for _, row in ipairs(moves) do
						checkFull(res, row[1], row[2], row[3])
					end
					h.player:SetAttribute("ReduceEffects", true)
					for _, row in ipairs(moves) do
						checkReduced(res, row[1], row[2], row[3])
					end
					if moves.Minion then
						setup(res, "boss_ui_minion:none")
					end
				end
				ReplicatedStorage:SetAttribute(FORCE, nil)
			end
		end, debug.traceback)
		h.check(res, "impact_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		ReplicatedStorage:SetAttribute(FORCE, nil)
		h.player:SetAttribute("ReduceEffects", savedReduce)
		state(res, "Idle", 0)
		setup(res, "restore:boss_ui")
	end

	-- Runners' auras and trails in the event (design doc 4.37, owner 2026-11-12, replaces "more visible in the event", owner
	-- 2026-11-06, and "a little lighter", owner 2026-11-09; BOSS_EVENT_SPEC "Animation rework", bullet "Runners' auras and trails
	-- in the event", proposed). The drawn copy (<rig>_Visible, Client/RunnerView) against the hidden server rig, which keeps the
	-- track values: in the event Market emitters at 0.25 x Rate, Market trails at 0.35 x opacity, no boost (same Size, Speed and
	-- trail Lifetime); out of it every value back to the rig's. Contract: RunnerView follows the local
	-- Player's BossEvent attribute both ways without a rebuild being needed (a rebuild is allowed). The run_visual fixture's rig
	-- (Owner 0) runs far above every track; BossEvent is set on this client only, as UiBossMage sets ReduceEffects.
	local AURA_RATE, TRAIL_OPACITY = 0.25, 0.35
	local APPLY_WAIT = 2
	local EPS = 1e-3
	local function relPath(model, d)
		local parts = {}
		while d and d ~= model do
			table.insert(parts, 1, d.Name)
			d = d.Parent
		end
		return parts
	end
	local function at(model, parts)
		local d = model
		for _, name in parts do
			d = d and d:FindFirstChild(name)
		end
		return d
	end
	local function marketPieces(rig)
		local list = {}
		for _, d in rig:GetDescendants() do
			if
				(d:IsA("ParticleEmitter") and d.Parent:GetAttribute("MarketEffect"))
				or (d:IsA("Trail") and d.Parent.Name == "MarketEffects")
			then
				table.insert(list, d)
			end
		end
		return list
	end
	local function sameSequence(a, b, map)
		if #a.Keypoints ~= #b.Keypoints then
			return false
		end
		for i, k in a.Keypoints do
			local want = map and map(k.Value) or k.Value
			if math.abs(b.Keypoints[i].Value - want) > EPS then
				return false
			end
		end
		return true
	end
	-- Every Market piece of the copy against the rig's; `inEvent` picks the rule. Returns the mismatches.
	local function compare(rig, copy, inEvent)
		local bad = {}
		local rate = inEvent and AURA_RATE or 1
		local opacity = inEvent and TRAIL_OPACITY or 1
		for _, piece in marketPieces(rig) do
			local path = relPath(rig, piece)
			local mine = at(copy, path)
			local label = table.concat(path, "/")
			if not mine then
				table.insert(bad, label .. " missing")
			elseif piece:IsA("ParticleEmitter") then
				if math.abs(mine.Rate - piece.Rate * rate) > EPS then
					table.insert(bad, ("%s Rate %.3f, want %.3f"):format(label, mine.Rate, piece.Rate * rate))
				end
				if not sameSequence(piece.Size, mine.Size) then
					table.insert(bad, label .. " Size scaled")
				end
				if math.abs(mine.Speed.Max - piece.Speed.Max) > EPS then
					table.insert(bad, label .. " Speed scaled")
				end
			else
				if math.abs(mine.Lifetime - piece.Lifetime) > EPS then
					table.insert(bad, ("%s Lifetime %.3f, want %.3f"):format(label, mine.Lifetime, piece.Lifetime))
				end
				local fade = function(v)
					return math.clamp(1 - (1 - v) * opacity, 0, 1)
				end
				if not sameSequence(piece.Transparency, mine.Transparency, fade) then
					table.insert(bad, label .. " Transparency not " .. opacity .. " x opacity")
				end
			end
		end
		return bad
	end
	local function invoke(request)
		local rf = ReplicatedStorage:FindFirstChild("UiTestSetupRequest")
		if not (rf and rf:IsA("RemoteFunction")) then
			return false, "no ReplicatedStorage.UiTestSetupRequest"
		end
		local okCall, ok, why = pcall(rf.InvokeServer, rf, request)
		return okCall and ok == true, tostring(okCall and why or ok)
	end

	function scenarios.ui_event_auras(res)
		local savedEvent = h.player:GetAttribute("BossEvent")
		local ok, err = xpcall(function()
			local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))
			local name = "UiEventAurasRig"
			local started, why = invoke(
				("run_visual_rig:%s:%s:%s:%s:%.3f"):format(
					name,
					CharacterCatalog.STARTER_PICKS[1],
					"ember_aura",
					"void_trail",
					40
				)
			)
			h.check(res, "event_auras_rig_started", started and "ok" or why, "ok", started)
			local rig = waitFor(function()
				local r = workspace:FindFirstChild(name)
				return r and #marketPieces(r) >= 2 and r
			end, BUILD_WAIT)
			local copy = waitFor(function()
				local c = workspace:FindFirstChild(name .. "_Visible")
				return c and rig and #marketPieces(c) >= #marketPieces(rig) and c
			end, BUILD_WAIT)
			check(res, "event_auras_copy_drawn", rig ~= nil and copy ~= nil, true)
			if not (rig and copy) then
				return
			end
			h.player:SetAttribute("BossEvent", nil)
			task.wait(0.3)
			h.checkList(
				res,
				"track_auras_trails_full",
				compare(rig, workspace:FindFirstChild(name .. "_Visible"), false)
			)
			h.player:SetAttribute("BossEvent", true)
			local bad = nil
			waitFor(function()
				local c = workspace:FindFirstChild(name .. "_Visible")
				bad = c and compare(rig, c, true) or { "no copy" }
				return #bad == 0
			end, APPLY_WAIT)
			h.checkList(res, "event_aura_rate_0_25_trail_opacity_0_35_no_boost", bad)
			h.player:SetAttribute("BossEvent", nil)
			waitFor(function()
				local c = workspace:FindFirstChild(name .. "_Visible")
				bad = c and compare(rig, c, false) or { "no copy" }
				return #bad == 0
			end, APPLY_WAIT)
			h.checkList(res, "event_left_auras_trails_full_again", bad)
		end, debug.traceback)
		h.check(res, "event_auras_checks_completed", ok and "yes" or tostring(err), "yes", ok)
		h.player:SetAttribute("BossEvent", savedEvent)
		invoke("run_visual_clear")
	end

	return { Scenarios = scenarios }
end

return Module
