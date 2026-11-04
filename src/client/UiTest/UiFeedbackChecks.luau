--!nonstrict
-- ui_feedback (design doc 4.33, docs/UI_FEEDBACK_SPEC.md; limits: UiSpec.Feedback). Owned by ui-test-writer.
-- Cue sounds load, the server folder matches the ledger, presets under reduced and normal motion, UiFx pieces, the cue
-- rate limit. The SOUND toggle needs a real click: the sound_off / sound_on clicks run cue_sounds_muted / _restored.
-- Expected red until ui-juice u4: pop_grows_gui_with_hover_scale (UiMotion.Pop skips a gui with a HoverScale today).
-- A game cue that shows UiFx pieces during this run can redden the "gone" checks: rerun alone with UiTestScenario.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Spec = require(script.Parent.UiSpec)
local UiSounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiSounds"))
local cfg = Spec.Feedback
local REDUCE_ATTR = Spec.Accessibility.ReduceAttr

local Checks = {}

function Checks.Build(h)
	local check, checkList = h.check, h.checkList
	local player, playerGui = h.player, h.playerGui
	local client = script.Parent.Parent
	local scenarios, after = {}, {}

	-- Every Sound of a cue row: { Name under the UiSfx group, slot } (UiFeedback names the Also sound cue .. slot).
	local function cueSlots(cue, row)
		local slots = {}
		if row.Slot then
			table.insert(slots, { cue, row.Slot })
		end
		if row.Also then
			table.insert(slots, { cue .. row.Also, row.Also })
		end
		return slots
	end

	-- Sounds and the Volume each must have with SOUND on, or offenders for what is missing.
	local function cueSounds(feedback, group)
		local list, missing = {}, {}
		for cue, row in feedback.Cues do
			for _, entry in cueSlots(cue, row) do
				local sound = group and group:FindFirstChild(entry[1])
				if sound and sound:IsA("Sound") then
					table.insert(
						list,
						{
							Sound = sound,
							Name = entry[1],
							Volume = entry[2] == row.Also and row.AlsoVolume or row.Volume,
						}
					)
				else
					table.insert(missing, entry[1] .. ": no Sound under " .. cfg.Group)
				end
			end
		end
		return list, missing
	end

	local function waitAllLoaded(sounds)
		local deadline = os.clock() + cfg.LoadWait
		local unloaded
		repeat
			unloaded = {}
			for slot, sound in sounds do
				if sound.TimeLength <= 0 then
					table.insert(unloaded, slot .. ": TimeLength 0")
				end
			end
			if #unloaded > 0 then
				task.wait(0.1)
			end
		until #unloaded == 0 or os.clock() >= deadline
		return unloaded
	end

	local function replicatedSoundChecks(res, feedback)
		local folder = ReplicatedStorage:WaitForChild(cfg.Folder, cfg.LoadWait)
		check(res, "replicated_folder_present", folder ~= nil, true, folder ~= nil)
		if not folder then
			return
		end
		local sounds, unresolved = {}, {}
		for cue, row in feedback.Cues do
			for _, entry in cueSlots(cue, row) do
				local sound = folder:FindFirstChild(entry[2])
				if sound and sound:IsA("Sound") then
					sounds[entry[2]] = sound
				else
					table.insert(unresolved, cue .. ": no Sound " .. entry[2])
				end
			end
		end
		checkList(res, "every_cue_slot_resolves", unresolved)
		local preload = {}
		for _, sound in sounds do
			table.insert(preload, sound)
		end
		task.spawn(function() -- can yield long on a bad id: the wait below judges it
			pcall(ContentProvider.PreloadAsync, ContentProvider, preload)
		end)
		checkList(res, "every_cue_sound_loaded", waitAllLoaded(sounds))
	end

	local function cueSoundChecks(res, feedback, group)
		check(res, "cue_group_present", group and group.ClassName, "SoundGroup", group and group:IsA("SoundGroup"))
		local list, wrong = cueSounds(feedback, group)
		for _, entry in list do
			if entry.Sound.SoundGroup ~= group then
				table.insert(wrong, entry.Name .. ": not in the group")
			end
			if math.abs(entry.Sound.Volume - entry.Volume) > 0.001 then
				table.insert(wrong, ("%s: Volume %s, want %s"):format(entry.Name, entry.Sound.Volume, entry.Volume))
			end
		end
		checkList(res, "one_sound_per_cue_at_its_volume", wrong)
		local inRoll = {}
		for cue, row in feedback.Cues do
			if string.find(cue, "^Roll") or cue == "Turbo" then
				if table.find(row.Motion or {}, "Burst") then
					table.insert(inRoll, cue)
				end
			end
		end
		checkList(res, "no_burst_in_the_roll", inRoll)
	end

	-- ServerStorage is not readable here: UiTestSetup publishes the folder's contents as an attribute.
	local function serverFolderChecks(res)
		local ok, err = h.requestSetup(cfg.ServerSetup)
		check(res, "server_report_setup", ok == true or tostring(err), true, ok == true)
		local deadline = os.clock() + cfg.ReportWait
		local raw = ReplicatedStorage:GetAttribute(cfg.ServerAttr)
		while raw == nil and os.clock() < deadline do
			task.wait(0.1)
			raw = ReplicatedStorage:GetAttribute(cfg.ServerAttr)
		end
		local decoded, report = pcall(HttpService.JSONDecode, HttpService, raw or "")
		if not (decoded and type(report) == "table") then
			check(res, "server_folder_reported", raw, "JSON list of the ServerStorage folder", false)
			return
		end
		local names, extras, wrong = {}, 0, {}
		for _, item in report do
			names[item.Name] = true
			if not table.find(cfg.Impacts, item.Name) then
				extras += 1
			end
			local ledger = UiSounds.Assets[item.Name]
			if item.Class ~= "Sound" then
				table.insert(wrong, item.Name .. " is a " .. tostring(item.Class))
			elseif not ledger then
				table.insert(wrong, item.Name .. " is not in UiSounds.Assets")
			elseif ledger.Id ~= item.SoundId then
				table.insert(wrong, ("%s: SoundId %s, ledger %s"):format(item.Name, item.SoundId, ledger.Id))
			elseif not (ledger.Creator and ledger.Name) then
				table.insert(wrong, item.Name .. ": ledger row without Creator or Name")
			end
		end
		local missing = {}
		for _, slot in cfg.Impacts do
			if not names[slot] then
				table.insert(missing, slot)
			end
		end
		checkList(res, "server_has_every_impact", missing)
		check(res, "server_extras_count", extras, "<= " .. cfg.MaxExtras, extras <= cfg.MaxExtras)
		checkList(res, "server_sounds_in_ledger", wrong)
	end

	local function visiblePieces()
		local fx = playerGui:FindFirstChild(cfg.FxGui)
		local count = 0
		for _, piece in fx and fx:GetDescendants() or {} do
			if piece:IsA("GuiObject") and piece.Visible then
				count += 1
			end
		end
		return count
	end

	-- Seconds until no piece shows, or nil if some still show after `limit`.
	local function piecesGoneIn(limit)
		local started = os.clock()
		while visiblePieces() > 0 and os.clock() - started < limit do
			RunService.Heartbeat:Wait()
		end
		return visiblePieces() == 0 and os.clock() - started or nil
	end

	local function newFrame(gui)
		local frame = Instance.new("Frame")
		frame.Position = UDim2.fromOffset(120, 120)
		frame.Size = UDim2.fromOffset(100, 40)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		return frame
	end

	local function reducedChecks(res, motion, feedback, group, gui)
		player:SetAttribute(REDUCE_ATTR, true)
		piecesGoneIn(cfg.BurstGone) -- a game cue from before
		local target = newFrame(gui)
		local presets = {
			Pop = motion.Pop,
			Slam = motion.Slam,
			Impact = motion.Impact,
			Shake = motion.Shake,
			Shine = motion.Shine,
			Burst = motion.Burst,
			Fly = function(frame)
				motion.Fly(frame, target, 8)
			end,
		}
		local wrong = {}
		for name, preset in presets do
			local frame = newFrame(gui)
			local home = frame.Position
			preset(frame)
			local scale = frame:FindFirstChild("MotionScale")
			if scale and math.abs(scale.Scale - 1) > 0.001 then
				table.insert(wrong, name .. ": MotionScale " .. scale.Scale)
			end
			if frame.Position ~= home then
				table.insert(wrong, name .. ": moved off home")
			end
			if frame:FindFirstChild("MotionShine") then
				table.insert(wrong, name .. ": left a shine overlay")
			end
			if visiblePieces() > 0 then
				table.insert(wrong, name .. ": " .. visiblePieces() .. " visible UiFx pieces")
			end
		end
		local landed = false
		motion.Fly(newFrame(gui), target, 8, nil, function()
			landed = true
		end)
		if not landed then
			table.insert(wrong, "Fly: onLanded did not fire at once")
		end
		local bar = newFrame(gui)
		local goal = UDim2.fromOffset(60, 40)
		motion.Fill(bar, goal)
		if bar.Size ~= goal then
			table.insert(wrong, "Fill: size not exact on return")
		end
		checkList(res, "reduced_presets_end_at_rest", wrong)

		-- Spec section 2: motion lands at once, sound still plays. Rebirth uses Slam, Burst and Shake.
		local sound = group and group:FindFirstChild("Rebirth")
		local played = 0
		local connection = sound and sound.Played:Connect(function()
			played += 1
		end)
		local frame = newFrame(gui)
		feedback.Play("Rebirth", frame)
		check(res, "reduced_cue_shows_no_pieces", visiblePieces(), 0, visiblePieces() == 0)
		task.wait(cfg.PlayedWait)
		check(res, "reduced_cue_still_plays_sound", played, ">= 1", played >= 1)
		if connection then
			connection:Disconnect()
			sound:Stop()
		end
	end

	local function normalChecks(res, motion, gui)
		player:SetAttribute(REDUCE_ATTR, false)
		local gone = piecesGoneIn(cfg.BurstGone)
		check(res, "no_pieces_before_normal_checks", gone ~= nil, true, gone ~= nil)

		-- Burst: shows pieces, all gone within BurstGone
		motion.Burst(Vector2.new(200, 200))
		local shown = visiblePieces()
		check(res, "burst_shows_pieces", shown, "> 0", shown > 0)
		gone = piecesGoneIn(cfg.BurstGone)
		check(res, "burst_gone_seconds", gone or "still showing", "<= " .. cfg.BurstGone, gone ~= nil)

		-- Every preset's pieces, on screen at once: no input, and the pool holds the cap
		local from, to = newFrame(gui), newFrame(gui)
		to.Position = UDim2.fromOffset(400, 120)
		motion.Impact(from)
		motion.Fly(from, to, 3)
		for _ = 1, 3 do
			motion.Burst(Vector2.new(200, 200))
		end
		shown = visiblePieces()
		check(res, "pieces_within_cap", shown, "1 to " .. cfg.MaxPieces, shown > 0 and shown <= cfg.MaxPieces)
		local fx = playerGui:FindFirstChild(cfg.FxGui)
		local takesInput = {}
		for _, piece in fx and fx:GetDescendants() or {} do
			if piece:IsA("GuiButton") then
				table.insert(takesInput, piece.Name .. " is a GuiButton")
			elseif piece:IsA("GuiObject") and (piece.Active or piece.Interactable) then
				table.insert(takesInput, piece.Name .. " takes input")
			end
		end
		checkList(res, "pieces_never_take_input", takesInput)
		gone = piecesGoneIn(cfg.PiecesGone)
		check(res, "all_pieces_gone_seconds", gone or "still showing", "<= " .. cfg.PiecesGone, gone ~= nil)

		-- Slam: Back easing crosses 1 on its way, so judge the last sampled moment it was away from 1
		local slammed = newFrame(gui)
		local started = os.clock()
		motion.Slam(slammed)
		local scale = slammed:FindFirstChild("MotionScale")
		check(res, "slam_starts_large", scale and scale.Scale, cfg.SlamStart, scale and scale.Scale == cfg.SlamStart)
		local lastMoving = started
		while scale and os.clock() - started < cfg.SampleSeconds do
			RunService.Heartbeat:Wait()
			if math.abs(scale.Scale - 1) > 0.001 then
				lastMoving = os.clock()
			end
		end
		check(res, "slam_rest_seconds", lastMoving - started, "< " .. cfg.SlamRest, lastMoving - started < cfg.SlamRest)

		-- Pop on a button: measured on screen, whichever UIScale ends up carrying it (a gui draws only one)
		local button = newFrame(gui)
		local hover = Instance.new("UIScale")
		hover.Name = "HoverScale"
		hover.Parent = button
		h.frames(2)
		local rest = button.AbsoluteSize.X
		motion.Pop(button)
		local peak = rest
		started = os.clock()
		while os.clock() - started < cfg.SampleSeconds do
			RunService.Heartbeat:Wait()
			peak = math.max(peak, button.AbsoluteSize.X)
		end
		local growth = rest > 0 and peak / rest or 0
		check(res, "pop_grows_gui_with_hover_scale", growth, ">= " .. cfg.PopPeak, growth >= cfg.PopPeak)
		local settled = rest > 0 and button.AbsoluteSize.X / rest or 0
		check(res, "pop_rests_gui_with_hover_scale", settled, 1, math.abs(settled - 1) <= 0.005)
	end

	local function rateLimitChecks(res, feedback, group)
		local sound = group and group:FindFirstChild(cfg.RateCue)
		if not (sound and sound:IsA("Sound")) then
			check(res, "rate_limit_cue_sound", "missing", cfg.RateCue, false)
			return
		end
		task.wait(cfg.RateLimit * 2) -- clear of any earlier play
		local played = 0
		local connection = sound.Played:Connect(function()
			played += 1
		end)
		for _ = 1, 20 do
			feedback.Play(cfg.RateCue)
		end
		task.wait(cfg.PlayedWait)
		check(res, "rate_limit_plays_once_in_a_tight_loop", played, 1, played == 1)
		feedback.Play(cfg.RateCue)
		task.wait(cfg.PlayedWait)
		check(res, "rate_limit_plays_again_after_it", played, 2, played == 2)
		connection:Disconnect()
		sound:Stop()
	end

	function scenarios.ui_feedback(res)
		h.waitGuis()
		local feedbackModule = client:FindFirstChild(cfg.Module)
		local motionModule = client:FindFirstChild(Spec.Accessibility.MotionModule)
		check(
			res,
			"modules_present",
			(feedbackModule and 1 or 0) + (motionModule and 1 or 0),
			2,
			feedbackModule ~= nil and motionModule ~= nil
		)
		if not (feedbackModule and motionModule) then
			return
		end
		local feedback, motion = require(feedbackModule), require(motionModule)

		replicatedSoundChecks(res, feedback)
		serverFolderChecks(res)
		local group = SoundService:WaitForChild(cfg.Group, cfg.LoadWait)
		cueSoundChecks(res, feedback, group)
		rateLimitChecks(res, feedback, group)

		if GuiService.ReducedMotionEnabled then
			h.stateMissing(res, "normal_motion", "roblox_reduced_motion_off", "Roblox Reduced Motion is on")
			return
		end
		local saved = player:GetAttribute(REDUCE_ATTR)
		local gui = Instance.new("ScreenGui")
		gui.Name = cfg.ProbeGui
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		local ok, err = pcall(function()
			reducedChecks(res, motion, feedback, group, gui)
			normalChecks(res, motion, gui)
		end)
		player:SetAttribute(REDUCE_ATTR, saved)
		gui:Destroy()
		check(res, "motion_checks_ran", ok or tostring(err), true, ok)
	end

	-- After conditions of the sound_off / sound_on clicks.
	local function volumeCheck(name, wantFor)
		return function(res)
			local feedbackModule = client:FindFirstChild(cfg.Module)
			if not feedbackModule then
				check(res, name, "missing", cfg.Module, false)
				return
			end
			local list, wrong = cueSounds(require(feedbackModule), SoundService:FindFirstChild(cfg.Group))
			for _, entry in list do
				local want = wantFor(entry)
				if math.abs(entry.Sound.Volume - want) > 0.001 then
					table.insert(wrong, ("%s: Volume %s, want %s"):format(entry.Name, entry.Sound.Volume, want))
				end
			end
			checkList(res, name, wrong)
		end
	end
	after.cue_sounds_muted = volumeCheck("cue_sounds_muted", function()
		return 0
	end)
	after.cue_sounds_restored = volumeCheck("cue_sounds_restored", function(entry)
		return entry.Volume
	end)

	return { Scenarios = scenarios, After = after }
end

return Checks
