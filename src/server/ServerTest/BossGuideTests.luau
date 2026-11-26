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
local GATE_NEAR = 30 -- studs from the gate's centre at most: he stands at the gate (proposed)
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
		flag("prompt_built_off", p.Enabled == false) -- each client turns it on from rebirth 1 (owner 2026-11-25)
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

	-- One source: the spot and the reach are Shared/BossGateConfig's, and the two prompts never overlap.
	local Gate = require(Shared.BossGateConfig)
	local world = Guide.CFrame(start)
	-- from the spawn: the plaza's centre is world (20, 0) since 2026-11-26 (WORLD_REDESIGN_SPEC 3, lead's choice under owner)
	local SPAWN_AT = Vector2.new(20, 0)
	local function flatAt()
		local at = Guide.CFrame(start).Position
		return Vector2.new(at.X, at.Z) - SPAWN_AT
	end
	flag("stands_by_the_gate_config", (flatAt() - Gate.At(Gate.GUIDE_OFFSET)).Magnitude < 0.01)
	local near = (flatAt() - Gate.POS).Magnitude
	flag("stands_at_the_gate", near <= GATE_NEAR, near, GATE_NEAR)
	flag("no_second_source", Config.GATE_POS == nil and Config.OFFSET == nil and Config.PROMPT_DISTANCE == nil)
	local apart = (flatAt() - Gate.At(Gate.PROMPT_OFFSET)).Magnitude
	local reach = Gate.PROMPT_DISTANCE + Gate.GUIDE_PROMPT_DISTANCE
	flag("clear_of_the_gate_prompt", apart > reach, apart, reach)
	local saved = Gate.POS
	Gate.POS = saved + Vector2.new(-5, -3)
	flag("follows_gate_pos", (flatAt() - Gate.At(Gate.GUIDE_OFFSET)).Magnitude < 0.01)
	local moved = (flatAt() - Gate.POS).Magnitude
	flag("stands_at_the_moved_gate", moved <= GATE_NEAR, moved, GATE_NEAR)
	Gate.POS = saved
	local toSpawn = -Gate.POS.Unit
	local look = world.LookVector
	flag("faces_like_the_gate", look.X * toSpawn.X + look.Z * toSpawn.Y > 0.99)
	local area = SpawnArea.Bounds(start).Area
	local at = world.Position
	flag("on_plaza", at.X > area.Min.X and at.X < area.Max.X and at.Z > area.Min.Z and at.Z < area.Max.Z)

	-- Popup layout B (owner 2026-11-25): the frame, the sizes and where everything stands, in design units.
	local Layout = H.module(Shared, "BossGuideLayout")
	flag("layout_exists", Layout ~= nil)
	if Layout then
		flag("layout_frame_520", Layout.FRAME_H == 520, Layout.FRAME_H, 520)
		flag("layout_content_from_120", Layout.TOP == 120, Layout.TOP, 120)
		flag("layout_text_48", Layout.TEXT == 48, Layout.TEXT, 48)
		local function inside(a, b)
			return a.X >= b.X and a.Y >= b.Y and a.X + a.W <= b.X + b.W and a.Y + a.H <= b.Y + b.H
		end
		local function separate(a, b)
			return a.X + a.W <= b.X or b.X + b.W <= a.X or a.Y + a.H <= b.Y or b.Y + b.H <= a.Y
		end
		for _, case in
			{
				{ "desktop", false, { X = 56, Y = 120, W = 1200 - 112, H = 520 - 120 - 82 } },
				{ "phone", true, { X = 56, Y = 144, W = 650 - 112, H = 420 - 144 - 82 } },
			}
		do
			local label, small, content = case[1], case[2], case[3]
			local rects = Layout.Rects(content, small)
			for _, key in { "Card", "Line", "Next" } do
				flag(("layout_%s_%s_in_content"):format(label, key), inside(rects[key], content))
			end
			flag(("layout_%s_portrait_in_card"):format(label), inside(rects.Portrait, rects.Card))
			flag(("layout_%s_line_clear_of_next"):format(label), separate(rects.Line, rects.Next))
			flag(("layout_%s_line_clear_of_card"):format(label), separate(rects.Line, rects.Card))
			flag(("layout_%s_next_200_by_44"):format(label), rects.Next.W == 200 and rects.Next.H == 44)
			flag(("layout_%s_card_square"):format(label), rects.Card.W == rects.Card.H)
			flag(("layout_%s_slip"):format(label), (rects.Slip ~= nil) == not small) -- phones have no paper slip
			flag(("layout_%s_role"):format(label), rects.Role == (small and "Item" or "Speech"), rects.Role)
			if rects.Slip then
				flag(
					"layout_slip_holds_line_and_next",
					inside(rects.Line, rects.Slip) and inside(rects.Next, rects.Slip)
				)
				flag("layout_slip_beside_card", separate(rects.Slip, rects.Card) and rects.Slip.H == rects.Card.H)
				flag("layout_card_fills_height", rects.Card.H == content.H, rects.Card.H, content.H)
			else
				flag("layout_phone_card_110", rects.Card.W == 110, rects.Card.W, 110)
			end
		end
	end

	-- The text table: every topic, both gate states, short, tweaked names only.
	for _, gateOpen in { false, true } do
		local label = gateOpen and "open" or "closed"
		local pages = Config.Pages(gateOpen)
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
		flag("gate_line_" .. label, string.find(last, gateOpen and "open" or "closed", 1, true) ~= nil, last)
	end
	flag("open_and_closed_differ", Config.Pages(true)[6].Text ~= Config.Pages(false)[6].Text)
	-- Owner 2026-11-25: he does not talk to a player below rebirth 1.
	local talks = type(Config.Talks) == "function" and Config.Talks
	flag("talks_from_rebirth_1", talks and talks(Sidekick.HudFromRebirth) == true)
	flag("talks_above", talks and talks(Sidekick.HudFromRebirth + 5) == true)
	flag("silent_below_rebirth_1", talks and talks(Sidekick.HudFromRebirth - 1) == false)
	flag("silent_without_a_level", talks and talks(nil) == false)

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

	-- One switch pair: he is in the world only while both his switch and the gate's are on.
	local function count()
		local built = 0
		for _, child in workspace:GetChildren() do
			built += child.Name == "BossGuide" and 1 or 0
		end
		return built
	end
	local isLive = type(Config.IsLive) == "function" and Config.IsLive
	local inServer = workspace:FindFirstChild("SpawnArea") ~= nil
	flag("off_until_turned_on", Config.LIVE == false)
	local want = inServer and isLive and isLive() and 1 or 0
	flag("live_one_guide", count() == want, count(), want)
	local guideWas, gateWas = Config.LIVE, Gate.LIVE
	for _, state in { { false, false }, { false, true }, { true, false }, { true, true } } do
		Config.LIVE, Gate.LIVE = state[1], state[2]
		local label = ("guide_%s_gate_%s"):format(state[1] and "on" or "off", state[2] and "on" or "off")
		local on = state[1] and state[2]
		flag("is_live_" .. label, isLive and isLive() == on)
		if not inServer then -- never beside a live server's own
			Guide.Start(start)
			flag("built_" .. label, count() == (on and 1 or 0), count(), on and 1 or 0)
			local extra = workspace:FindFirstChild("BossGuide")
			while extra do
				extra:Destroy()
				extra = workspace:FindFirstChild("BossGuide")
			end
		end
	end
	Config.LIVE, Gate.LIVE = guideWas, gateWas
	model:Destroy()
	return r
end

return Tests
