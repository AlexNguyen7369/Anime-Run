--!nonstrict
-- BRIEF: docs/WORLD_REDESIGN_SPEC.md 4.2 "Boss gate guide" (owner 2026-11-25), docs/BOSS_GUIDE_SPEC.md. Gojio (jk_strongest)
-- stands at the boss gate with one E prompt; the conversation is text only: a full text table, no remote, nothing granted.
-- On demand: ReplicatedStorage attributes ServerTestOnly = "boss_guide", then ServerTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local Tests = {}

local TOPICS = { "Intro", "What", "When", "Join", "Rewards", "Gate" }
local LINE_MAX = 170 -- characters: one short line per page (BOSS_GUIDE_SPEC)
-- Design doc section 5: no real character, series or boss name in the conversation.
local REAL = {
	"gojo",
	"mahoraga",
	"frieren",
	"gilgamesh",
	"jujutsu",
	"fate/stay",
	"sukuna",
	"saitama",
}

local function prompts(root)
	local found = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			table.insert(found, d)
		end
	end
	return found
end

local function words(list)
	return table.concat(list, " ")
end

function Tests.boss_guide()
	local r, flag = H.report("boss_guide")
	local Config = H.module(Shared, "BossGuideConfig")
	local Guide = H.module(Server, "BossGuide")
	flag("config_exists", Config ~= nil)
	flag("service_exists", Guide ~= nil)
	if not (Config and Guide) then
		return r
	end
	local SpawnArea = require(Shared.SpawnArea)
	local Boss = require(Shared.BossEventConfig)
	local Sidekick = require(Shared.SidekickConfig)

	-- The guide: one rig of Gojio, one prompt, at the one config spot, off the gate's centre.
	local start = CFrame.new(-118, 0, 80)
	local model = Guide.Build(start)
	flag("model_name", model.Name == "BossGuide", model.Name, "BossGuide")
	local rig = model:FindFirstChild("Rig")
	flag("rig_is_gojio", rig ~= nil and rig:GetAttribute("CharacterId") == "jk_strongest")
	flag("name_is_tweaked", Config.Name() == "Gojio", Config.Name(), "Gojio")
	local found = prompts(model)
	flag("one_prompt", #found == 1, #found, 1)
	local p = found[1]
	if p then
		flag("prompt_name", p.Name == "TalkBossGuide", p.Name, "TalkBossGuide")
		flag("prompt_text", p.ActionText == "Talk" and p.ObjectText == "Gojio", p.ActionText, "Talk")
		flag("prompt_key_e", p.KeyboardKeyCode == Enum.KeyCode.E)
		flag("prompt_hold", p.HoldDuration == 0, p.HoldDuration, 0)
		flag("prompt_distance", p.MaxActivationDistance == 8)
		flag("prompt_always_on", p.Enabled ~= false) -- usable whether the gate is open or closed
	end
	local moving, solid = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			moving += d.Anchored and 0 or 1
			solid += d.CanCollide and 1 or 0
		end
	end
	flag("static", moving == 0, moving, 0)
	flag("not_in_the_way", solid == 0, solid, 0)

	-- One position value: the guide's spot follows GATE_POS.
	local world = Guide.CFrame(start)
	local gate = Vector3.new(Config.GATE_POS.X, world.Position.Y, Config.GATE_POS.Y)
	local away = (world.Position - gate).Magnitude
	flag("stands_at_the_gate", away <= 30, away, 30)
	flag("clear_of_the_gate_prompt", away > 2 * Config.PROMPT_DISTANCE, away, 2 * Config.PROMPT_DISTANCE)
	local saved = Config.GATE_POS
	Config.GATE_POS = saved + Vector2.new(-5, -3)
	local moved = Guide.CFrame(start).Position - world.Position
	Config.GATE_POS = saved
	-- the facing turns with the spot, so the shift is near, not exactly, the same
	flag("follows_gate_pos", (moved - Vector3.new(-5, 0, -3)).Magnitude < 1.6, moved.Magnitude)
	local area = SpawnArea.Bounds(start).Area
	local at = world.Position
	flag("on_plaza", at.X > area.Min.X and at.X < area.Max.X and at.Z > area.Min.Z and at.Z < area.Max.Z)

	-- The text table: every topic, both gate states, both rebirth states, short, tweaked names only.
	for _, gateOpen in { false, true } do
		for _, rebirth in { 0, Sidekick.HudFromRebirth } do
			local label = ("%s_r%d"):format(gateOpen and "open" or "closed", rebirth)
			local pages = Config.Pages(gateOpen, rebirth)
			flag("topics_" .. label, #pages == #TOPICS, #pages, #TOPICS)
			local long, real, text = {}, {}, {}
			for i, page in pages do
				flag(("topic_%s_%d"):format(label, i), page.Id == TOPICS[i], page.Id, TOPICS[i])
				table.insert(text, page.Text)
				if #page.Text == 0 or #page.Text > LINE_MAX then
					table.insert(long, page.Id .. " " .. #page.Text)
				end
				for _, name in REAL do
					if string.find(string.lower(page.Text), name, 1, true) then
						table.insert(real, name)
					end
				end
			end
			flag("lines_short_" .. label, #long == 0, words(long), "")
			flag("no_real_names_" .. label, #real == 0, words(real), "")
			local all = string.lower(words(text))
			flag("no_odds_or_prices_" .. label, not string.find(all, "%d%.%d") and not string.find(all, "robux"))
			flag("says_sidekick_" .. label, string.find(all, "sidekick", 1, true) ~= nil)
			local every = ("every %d minutes"):format(Boss.IntervalSeconds / 60)
			flag("interval_from_config_" .. label, string.find(all, every, 1, true) ~= nil, every)
			local share = ("%d%%"):format(Boss.MinDamageShare * 100)
			flag("share_from_config_" .. label, string.find(all, share, 1, true) ~= nil, share)
			local rewards = pages[5].Text
			flag("defeat_only_" .. label, string.find(rewards, "Only a defeat pays", 1, true) ~= nil)
			flag("share_is_per_phase_" .. label, string.find(rewards, "that phase's HP", 1, true) ~= nil)
			local last = pages[#pages].Text
			local early = rebirth < Sidekick.HudFromRebirth
			flag(
				"gate_line_" .. label,
				string.find(last, early and ("Rebirth " .. Sidekick.HudFromRebirth) or gateOpen and "open" or "closed")
					~= nil,
				last
			)
		end
	end
	flag("open_and_closed_differ", Config.Pages(true, 1)[6].Text ~= Config.Pages(false, 1)[6].Text)
	flag("early_same_open_or_closed", Config.Pages(true, 0)[6].Text == Config.Pages(false, 0)[6].Text)

	-- Text only: the module answers no remote, and the server half has no handler to grant anything from.
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local named = {}
	for _, remote in remotes and remotes:GetChildren() or {} do
		if string.find(remote.Name, "Guide") then
			table.insert(named, remote.Name)
		end
	end
	flag("no_remote", #named == 0, words(named), "")
	local api = {}
	for key in Guide do
		table.insert(api, key)
	end
	table.sort(api)
	flag("server_api_only_builds", words(api) == "Build CFrame Start", words(api), "Build CFrame Start")

	-- In a live server: exactly one guide in the world.
	local built = 0
	for _, child in workspace:GetChildren() do
		built += child.Name == "BossGuide" and 1 or 0
	end
	local live = Config.LIVE and workspace:FindFirstChild("SpawnArea") ~= nil
	flag("off_until_the_gate_is_built", Config.LIVE == false)
	flag("live_one_guide", built == (live and 1 or 0), built, live and 1 or 0)
	model:Destroy()
	return r
end

return Tests
