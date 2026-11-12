--!nonstrict
-- BRIEF: design doc 4.37 "Second boss" (owner 2026-11-11), docs/BOSS_EVENT_SPEC.md "The Elf Mage": the second boss, picked at
-- random per event, one stage, 2 moves (lightning 20% of a full bar, barrage 30%, each striking for a 2 s window) and the Stone
-- Golem miniboss (owner 2026-11-11: slam then sweep, 15% plus a Crushed 20% damage cut for 15 s each; owner 2026-11-12: 1,000 HP per
-- player in the arena at its start, dodged by 3 rhythm circles 0.9 s apart in a 3 s window at +/- 0.35 s; her clock stops while it stands), an enclosed colosseum (inner 70, width 56, 7 lanes, wall 164 by
-- the orchestrator's 2026-11-11 default). Red first: written before the code (task boss-mage T1; golem miniboss boss-mage-2).
--
-- Contract these tests assume beyond the brief (boss-mage-code-plan.md sections 1-3 and 6, boss-mage-2-code-plan.md section A;
-- implementer: report a change, do not loosen):
--   Shared/BossCatalog: Default, Order = { "boss_raga", "boss_mage" }, Get(id) (nil or unknown -> the boss_raga row), Current()
--     (Get of ReplicatedStorage attribute BossEventBoss). Row fields of plan A1: her Moves Lightning and Barrage only, Statuses
--     { { Id = "Crushed", Minion = true, Cut } }, Minion { Id, Name, HpPerPlayer (no Hp), Attacks { Slam, Sweep }, Caption }, Chests, Relics.
--   Shared/BossOsu: Count, ApproachSeconds, Tolerance, Diameter, DiameterPhone, OpenSeconds, Circles(userId, startAt, k) -> 3 rows
--     { X, Y, Lead } in click order (named fields), on the golem clock (startAt = BossMinionStart, k = golem attack number),
--     Judge(lead, momentAt, stamp, slack).
--   Shared/BossArenaConfig.For(bossId): "boss_mage" -> the colosseum table (Raga's fields plus WallRadius, WallHeight, HoverY,
--     BobStuds, BobSeconds); anything else -> BossArenaConfig itself.
--   Shared/BossDodge: Moment(index, boss), IndexAtOrBefore(since, boss), EventsOf(boss); boss nil = Raga. Slot(boss) -> slotAt,
--     cycle (nil for Raga), MinionMoment(k, boss) -> tau, name, MinionIndexAtOrBefore(tau, boss) -> k.
--   Shared/BossEventConfig.WaitCameraCFrame(center, runnerPosition, wait): wait = { Out, Up, Down }.
--   Server/BossEventService: Start(source, bossId) (unknown id: false, "Unknown boss"), State().Boss, ReplicatedStorage attribute
--     BossEventBoss, Hooks.PickBoss() (default "boss_raga" while CarTestRunning, uniform otherwise: decision D1 option A),
--     picked when the next event is scheduled and published as BossEventNextBoss, Hooks.DamageMulti(t, spared, stage, boss,
--     crushes), Hooks.PayStage(player, stage, boss), Osu(player, k, circle, stamp) -> ok, reason, Dodge while the golem stands ->
--     false, "No bar", RewardPopup summary field Boss. BossStatus JSON row { Id = "Crushed", EndsAt, Count }. Golem attributes
--     BossMinionHp, BossMinionMaxHp, BossMinionStart (the slot's schedule time) on ReplicatedStorage while it stands.
--   ServerStorage.LateData.BossMagePoses (generated; design doc 7 "Join size"): Moves (idle, lightning, barrage, golem, watch, watch_in, golem_fall, plus lightning_in,
--     golem_in, barrage_in with no events), GolemMoves (golem_idle, golem_slam, golem_sweep), Approved, Bind, Scale (studs per
--     unit), Sample(move, t) -> parts, root (studs), Schedule, RiseAt, CycleSeconds, GolemSlotAt, GolemFirstHit, GolemEvery,
--     GolemHit(k) -> tau, name, GolemAt(tau) -> herMove, herTime, golemMove, golemTime, SampleGolem(move, t) -> scale
--     (0 = hidden), parts, locs, root; GolemBind (15 blocks).
--   The rework (task a4-mage, design doc 4.37 "Animation rework"): Bind names the jointed parts (MAGE_JOINTED below, no LeftArm,
--     RightArm, LeftLeg, RightLeg, TailL, TailR); every rework move's row (Moves, and GolemMoves for the golem's tracks) has
--     Approved = its 10 rework/keys.json key times; Poses.Approved[move] has those 10 rows for her moves; RootStuds divides
--     Sample's root back to keys.json root_offset units.
-- Proposed values the plan fixes and these tests assert literally (owner may retune): her move chat lines, camera pitch 14,
--   wall 164, HoverY 8, bob 1.5 studs / 3 s, WaitCamera { Out = 28, Up = 40, Down = 22 }, golem HP 1,000 per player, one attack every 6 s,
--   cycle 32.55 s, the golem chat lines, circle leads.
-- On demand: ReplicatedStorage attributes CarTestOnly = "boss_mage_event,boss_mage_arena,boss_mage_anim", then CarTestRun = true.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Server = script.Parent.Parent
local PathDriver = require(Shared.PathDriver)
local Tests = {}

local MAGE, RAGA = "boss_mage", "boss_raga"
local UID = 990158000
local T0 = 1000000 -- the fake server clock's start
local COST = { Lightning = 20, Barrage = 30 } -- owner 2026-11-11, % of a full bar (stamina is 0..100)
local GOLEM_COST = 15 -- owner 2026-11-11: each golem attack
local GOLEM_HP = 1000 -- owner 2026-11-12: per player in the arena when it rises (one player in most tests)
local GOLEM_FIRST, GOLEM_EVERY = 4.2, 6 -- approved keys.json golem Slam; proposed: one attack every 6 s (5 s until 2026-11-12)
local CYCLE_SECONDS = 32.55 -- the 2026-11-11 bake (proposed)
local CRUSHED_CUT = 0.2 -- owner 2026-11-11
local STATUS_SECONDS = 15 -- proposed: the stage's status time
local SLAM_AT = 4.2 -- approved keys.json: golem's Slam
-- Her moves' events: the window moves strike from the window's start (owner 2026-11-11, cost charged there, proposed).
local MOVE_EVENTS = { lightning = { "Lightning", 2.0 }, golem = { "Slam", 4.2 }, barrage = { "Barrage", 2.0 } }
local CHAT = "THE ELF MAGE HAS AWAKENED, TAKE HER DOWN FOR REWARDS" -- design doc 4.37 (proposed)
local MOVE_CHAT = { -- plan section 1 (proposed)
	Lightning = "The Elf Mage calls lightning! -20% stamina",
	Barrage = "The Elf Mage fires a barrage! -30% stamina",
}
local GOLEM_CHAT = { -- BOSS_EVENT_SPEC "Texts" (proposed)
	Slam = "The Elf Mage's golem slams! -15% stamina, damage down for 15 s",
	Sweep = "The Stone Golem sweeps! -15% stamina, damage down for 15 s",
}
local MINION_ATTRIBUTES = { "BossMinionHp", "BossMinionMaxHp", "BossMinionStart" }

-- Golem attack k: seconds after BossMinionStart, and its name (slam, then sweep, in turn).
local function golemTau(k)
	return GOLEM_FIRST + GOLEM_EVERY * (k - 1)
end
local function golemName(k)
	return k % 2 == 1 and "Slam" or "Sweep"
end
local MODEL_HEIGHT_UNITS = 6.2582 -- keys.json scale.model_height_units
local SCAN = 40 -- moments looked at
-- djb2 { length, hash } of the real source names (section 5 safeguard): kept as hashes so no real name sits in the game's files.
local REAL_NAMES = {
	{ 7, 1090972917 },
	{ 8, 963842139 },
	{ 7, 2081047238 },
	{ 6, 473633273 },
	{ 6, 35734055 },
	{ 6, 143515654 },
}

-- The rework (design doc 4.37 "Animation rework" and "Rework approvals", owner 2026-11-12; BOSS_EVENT_SPEC "Animation rework"):
-- the jointed Elf Mage and 10 key frames per move, copied by hand from assets/characters_avatar/boss_mage/keyframes/rework/keys.json.
local MAGE_LIMBS = {
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"RightUpperLeg",
	"RightLowerLeg",
	"TailL1",
	"TailL2",
	"TailL3",
	"TailR1",
	"TailR2",
	"TailR3",
	"Staff",
}
local MAGE_JOINTED = table.clone(MAGE_LIMBS)
table.insert(MAGE_JOINTED, "Torso")
table.insert(MAGE_JOINTED, "Head")
local MAGE_UNJOINTED = { "LeftArm", "RightArm", "LeftLeg", "RightLeg", "TailL", "TailR" }
-- keys.json golem part names: the golem's rig is unchanged by the rework (BOSS_EVENT_SPEC "Animation rework" Rigs).
local GOLEM_PARTS = {
	"FistL",
	"FistR",
	"ForearmL",
	"ForearmR",
	"Head",
	"Hip",
	"ShinL",
	"ShinR",
	"ShoulderL",
	"ShoulderR",
	"ThighL",
	"ThighR",
	"Torso",
	"UpperArmL",
	"UpperArmR",
}
-- The 10 key times of every rework move (her moves in Moves, golem_fall in Moves, the golem's tracks in GolemMoves).
local KEY_TIMES = {
	lightning = { 0, 0.45, 0.95, 1.4, 1.8, 2, 2.6, 3.35, 4, 5.2 },
	idle = { 0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 2.7 },
	watch = { 0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 2.7 },
	barrage = { 0, 0.5, 1, 1.45, 1.85, 2, 2.6, 3.35, 4, 5.4 },
	golem = { 0, 0.4, 0.8, 1.3, 1.9, 2.5, 3, 3.6, 4.2, 5 },
	golem_idle = { 0, 0.24, 0.48, 0.72, 0.96, 1.2, 1.44, 1.68, 1.92, 2.16 },
	golem_slam = { 0, 0.4, 0.9, 1.5, 2.25, 2.6, 2.8, 3, 3.3, 3.6 },
	golem_sweep = { 0, 0.4, 1, 1.6, 2.2, 2.6, 2.85, 3.2, 3.7, 4.2 },
	golem_fall = { 0, 0.2, 0.4, 0.6, 0.8, 1, 1.2, 1.45, 1.7, 2 },
}
local GOLEM_TRACKS = { "golem_idle", "golem_slam", "golem_sweep", "golem_fall" }
-- { move, key number, part, keys.json rotation }: keys 1, the hit (key 6, the window's first strike at 2.0 s) and 10. Body (her
-- hip turn) folds into Torso and the upper legs as the king's does, so those are spotted only on keys where Body is 0.
local MAGE_SPOTS = {
	{ "lightning", 1, "Torso", Vector3.new(8, 0, 2) },
	{ "lightning", 1, "Head", Vector3.new(-4, 0, -4) },
	{ "lightning", 1, "RightUpperArm", Vector3.new(-33.204, -0.647, 31.13) },
	{ "lightning", 1, "RightLowerArm", Vector3.new(-20.985, 0, 0) },
	{ "lightning", 1, "Staff", Vector3.new(102.64, 51.4, 59.752) },
	{ "lightning", 1, "LeftLowerLeg", Vector3.new(28, 0, 0) },
	{ "lightning", 1, "TailL1", Vector3.new(-4, -26, 0) },
	{ "lightning", 6, "RightUpperArm", Vector3.new(-15.526, 21.346, 17.577) },
	{ "lightning", 6, "RightLowerArm", Vector3.new(-76.126, 0, 0) },
	{ "lightning", 6, "LeftUpperArm", Vector3.new(-58.988, 43.359, -45.023) },
	{ "lightning", 6, "Staff", Vector3.new(103.007, 61.477, -97.861) },
	{ "lightning", 6, "Head", Vector3.new(-14, 0, -30) },
	{ "lightning", 6, "TailR2", Vector3.new(22, 6, 0) },
	{ "lightning", 6, "RightLowerLeg", Vector3.new(48, 0, 0) },
	{ "lightning", 10, "Torso", Vector3.new(8, 0, 2) },
	{ "lightning", 10, "RightUpperArm", Vector3.new(-33.204, -0.647, 31.13) },
	{ "lightning", 10, "LeftLowerArm", Vector3.new(-83.653, 0, 0) },
	{ "lightning", 10, "Staff", Vector3.new(102.64, 51.4, 59.752) },
	{ "lightning", 10, "LeftUpperLeg", Vector3.new(22, 0, -3) },
	{ "lightning", 10, "TailL3", Vector3.new(8, -6, 0) },
	{ "barrage", 1, "Torso", Vector3.new(8, 0, 2) },
	{ "barrage", 1, "RightUpperArm", Vector3.new(-33.204, -0.647, 31.13) },
	{ "barrage", 1, "LeftUpperArm", Vector3.new(-22.705, -0.724, -30.778) },
	{ "barrage", 1, "Staff", Vector3.new(102.64, 51.4, 59.752) },
	{ "barrage", 1, "Head", Vector3.new(-4, 0, -4) },
	{ "barrage", 6, "RightUpperArm", Vector3.new(-15.526, 21.346, 17.577) },
	{ "barrage", 6, "RightLowerArm", Vector3.new(-76.126, 0, 0) },
	{ "barrage", 6, "LeftUpperArm", Vector3.new(-61.912, 46.328, -46.596) },
	{ "barrage", 6, "LeftLowerArm", Vector3.new(-1.25, 0, 0) },
	{ "barrage", 6, "Staff", Vector3.new(100.804, 53.861, -104.511) },
	{ "barrage", 6, "TailL2", Vector3.new(20, 0, 0) },
	{ "barrage", 6, "LeftLowerLeg", Vector3.new(72, 0, 0) },
	{ "barrage", 10, "Torso", Vector3.new(8, 0, 2) },
	{ "barrage", 10, "RightLowerArm", Vector3.new(-20.985, 0, 0) },
	{ "barrage", 10, "Staff", Vector3.new(102.64, 51.4, 59.752) },
	{ "barrage", 10, "RightUpperLeg", Vector3.new(10, 0, 3) },
	{ "barrage", 10, "TailR1", Vector3.new(-4, 26, 0) },
}
-- { move, key number, Torso rotation, UpperArmR rotation, Torso loc } through SampleGolem: golem_slam keys 1, the hit (7, 2.8 s)
-- and 10, and a few keys of the other tracks and of her golem move (4: the blocks gathering, 9: the 4.2 s Slam).
local GOLEM_SPOTS = {
	{ "golem_slam", 1, Vector3.new(6, 0, 0), Vector3.new(-12, 0, -4), Vector3.new(0, -0.05, 0.4) },
	{ "golem_slam", 7, Vector3.new(56, 0, 0), Vector3.new(-141, -14, 0), Vector3.new(0, -0.05, 0.4) },
	{ "golem_slam", 10, Vector3.new(6, 0, 0), Vector3.new(-12, 0, -4), Vector3.new(0, -0.05, 0.4) },
	{ "golem_sweep", 1, Vector3.new(6, 0, 0), Vector3.new(-12, 0, -4), Vector3.new(0, -0.05, 0.4) },
	{ "golem_sweep", 6, Vector3.new(22, 0, 10), Vector3.new(0, 88, 90), Vector3.new(0, -0.05, 0.4) },
	{ "golem_sweep", 10, Vector3.new(6, 0, 0), Vector3.new(-12, 0, -4), Vector3.new(0, -0.05, 0.4) },
	{ "golem_idle", 1, Vector3.new(6, 0, 0), Vector3.new(-12, 0, -4), Vector3.new(0, -0.05, 0.4) },
	{ "golem_fall", 1, Vector3.new(-16, 0, 0), Vector3.new(-30, 14, 0), Vector3.new(0, -0.05, 0.4) },
	{
		"golem_fall",
		10,
		Vector3.new(-125.61, 12.27, 73.39),
		Vector3.new(-171.19, -8.41, -40.03),
		Vector3.new(1.208, -1.234, 1.528),
	},
	{
		"golem",
		4,
		Vector3.new(28.62, -16.34, 10.79),
		Vector3.new(17.34, 34.21, 13.7),
		Vector3.new(1.123, -0.699, -1.668),
	},
	{ "golem", 9, Vector3.new(56, 0, 0), Vector3.new(-141, -14, 0), Vector3.new(0, -0.05, 0.4) },
}
local KEY_DEGREES = 0.01
local FRAME = 1 / 60
local MAX_DEGREES_PER_FRAME = 12 -- BOSS_EVENT_SPEC "Animation rework" Tests, as BossAnimTests for Big Raga
local MAX_OFFSET_PER_FRAME = 0.05 -- root, in key units (her root_offset model units; the golem's golem units)
local SNAP_WINDOW = 0.05 -- s after an event where the hit snap still runs (with the key segment into it)

-- XYZ Euler degrees as the client poses them (Z, then Y, then X), in doubles: CFrame is float32.
local function matrixOf(v)
	local x, y, z = math.rad(v.X), math.rad(v.Y), math.rad(v.Z)
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	return {
		cz * cy,
		cz * sy * sx - sz * cx,
		cz * sy * cx + sz * sx,
		sz * cy,
		sz * sy * sx + cz * cx,
		sz * sy * cx - cz * sx,
		-sy,
		cy * sx,
		cy * cx,
	}
end

-- Degrees between two Euler rotations: ||A - B|| = 2 sqrt(2) sin(angle / 2), exact for small angles.
local function rotationApart(a, b)
	local ma, mb, sum = matrixOf(a), matrixOf(b), 0
	for i = 1, 9 do
		sum += (ma[i] - mb[i]) ^ 2
	end
	return math.deg(2 * math.asin(math.min(1, math.sqrt(sum) / (2 * math.sqrt(2)))))
end

-- The hit snap (BOSS_EVENT_SPEC "Animation rework" Tests, 2026-11-12): for each event, the key segment that ends on it (from the
-- last key frame before it) plus SNAP_WINDOW after it. Returns a function t -> inside a snap.
local function snapsOf(events, keyTimes)
	local snaps = {}
	for _, event in events or {} do
		local from = nil
		for _, k in keyTimes do
			if k < event.Time - 1e-6 and (from == nil or k > from) then
				from = k
			end
		end
		table.insert(snaps, { from or event.Time, event.Time + SNAP_WINDOW })
	end
	return function(t)
		for _, snap in snaps do
			if t > snap[1] and t <= snap[2] then
				return true
			end
		end
		return false
	end
end

local function approx(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 1e-6)
end

local function nameHash(s)
	local x = 5381
	for i = 1, #s do
		x = (x * 33 + string.byte(s, i)) % 2147483647
	end
	return x
end

local function realNameIn(text)
	text = string.lower(text)
	for _, entry in REAL_NAMES do
		for i = 1, #text - entry[1] + 1 do
			if nameHash(string.sub(text, i, i + entry[1] - 1)) == entry[2] then
				return entry[2]
			end
		end
	end
	return nil
end

local function stringsIn(value, out)
	if type(value) == "string" then
		table.insert(out, value)
	elseif type(value) == "table" then
		for _, item in value do
			stringsIn(item, out)
		end
	end
	return out
end

-- The first `count` moments of a boss: { Index, At, Name }, At in seconds since the intro's end.
local function momentsOf(BossDodge, boss, count)
	local list = {}
	for index = 1, count or SCAN do
		local at, name = BossDodge.Moment(index, boss)
		table.insert(list, { Index = index, At = at, Name = name })
	end
	return list
end

local function firstOf(list, name, after)
	for _, row in list do
		if row.Name == name and (after == nil or row.Index > after) then
			return row
		end
	end
	return nil
end

local function reporter(name)
	local r, flag = H.report(name)
	local function section(label, body)
		local ok, err = xpcall(body, debug.traceback)
		flag(label .. "_completed", ok, ok and 1 or tostring(err))
	end
	local function eq(label, actual, expected)
		flag(label, actual == expected, actual, expected)
	end
	local function near(label, actual, expected, tolerance)
		flag(label, approx(actual, expected, tolerance), actual, expected)
	end
	return r, flag, section, eq, near
end

function Tests.make()
	local function boss_mage_event()
		local r, flag, section, eq, near = reporter("boss_mage_event")
		local cleanup = {}
		local Cfg = H.module(Shared, "BossEventConfig")
		local S = H.module(Server, "BossEventService")
		local BossDodge = H.module(Shared, "BossDodge")
		local Catalog = H.module(Shared, "BossCatalog")
		local Osu = H.module(Shared, "BossOsu")
		flag("service_exists", S ~= nil)
		flag("catalog_exists", Catalog ~= nil)
		flag("osu_exists", Osu ~= nil)
		flag("dodge_exists", BossDodge ~= nil)
		if not (Cfg and S and BossDodge) then
			return r
		end
		local realHooks = table.clone(S.Hooks)
		local Poses = H.lateData("BossMagePoses") -- design doc 7 "Join size"
		local SLOT = Poses and Poses.GolemSlotAt -- seconds after the intro: the end of golem_in
		local CYCLE = Poses and Poses.CycleSeconds
		flag("golem_slot_exported", type(SLOT) == "number", SLOT)

		local gacha = require(Server.GachaService)
		local sidekick = require(Server.SidekickService)
		local catalog = require(Shared.CharacterCatalog)
		local module = Server.PlayerData:Clone()
		module.Name, module.Parent = "CarTestBossMageData", Server
		table.insert(cleanup, module)
		local data = require(module)
		data.SetStore(H.store())
		local nextId = UID
		local function newPlayer()
			nextId += 1
			local p = H.player(cleanup, nextId)
			data.Load(p, nextId)
			return p
		end
		local chars = {}
		for _, spec in catalog.All() do
			if spec.Rollable and spec.Id ~= catalog.STARTER_ID then
				table.insert(chars, spec.Id)
			end
		end
		local function wear(p, charId, sideId)
			gacha.Grant(p, charId)
			local _, entry = sidekick.Grant(p, sideId)
			sidekick.Equip(p, charId, entry)
		end
		local function fighter()
			local p = newPlayer()
			wear(p, chars[1], "side_knight")
			return p
		end
		-- Three characters, each with a Sidekick, set as the event team.
		local function trio()
			local p, ids = newPlayer(), {}
			for i, sideId in { "side_knight", "side_chain", "side_fox" } do
				wear(p, chars[i], sideId)
				table.insert(ids, chars[i])
			end
			return p, ids
		end

		local PREP, INTRO = Cfg.PrepSeconds, Cfg.IntroSeconds
		local FIGHT = PREP + INTRO
		local clock = T0
		local log
		local function install()
			log = { Chat = {}, MoveChat = {}, Paid = {}, Popups = {}, Runs = {}, Lanes = {} }
			S.Hooks.DamageMulti = function()
				return 1
			end
			S.Hooks.Arrive = function() end
			S.Hooks.Depart = function() end
			S.Hooks.BossHits = function() end
			S.Hooks.Chat = function(text)
				table.insert(log.Chat, text)
			end
			S.Hooks.MoveChat = function(p, text)
				table.insert(log.MoveChat, { Player = p, Text = text })
			end
			S.Hooks.PayStage = function(p, stage)
				table.insert(log.Paid, { Player = p, Stage = stage })
				return true
			end
			S.Hooks.RewardPopup = function(p, summary)
				table.insert(log.Popups, { Player = p, Summary = summary })
			end
			S.Hooks.SwitchLane = function(_, lane)
				table.insert(log.Lanes, lane)
			end
			S.Hooks.StartRun = function(p, team, lane)
				local line = {}
				for slot in team do
					table.insert(line, slot)
				end
				local run = {
					TargetSpeed = 0,
					Waiting = false,
					Team = team,
					Lane = lane,
					Slot = 1,
					Line = line,
					Stamina = { 100, 100, 100 },
					Revives = {},
				}
				function run:Destroy() end
				function run:ReviveAt(seconds)
					table.insert(self.Revives, seconds)
				end
				log.Runs[p] = run
				return run
			end
		end
		local function to(t)
			clock = T0 + t
			S.Advance(clock)
		end
		-- A fresh server at T0 with `boss`'s event started: time t in a test is the event's own clock.
		local function begin(boss)
			clock = T0
			S.Reset(T0)
			install()
			return S.Start("Test", boss)
		end
		local function statusRow(p, id)
			for _, row in HttpService:JSONDecode(p:GetAttribute("BossStatus") or "[]") do
				if row.Id == id then
					return row
				end
			end
			return nil
		end
		local function timesPaid(p, stage)
			local n = 0
			for _, row in log.Paid do
				n += (row.Player == p and row.Stage == stage) and 1 or 0
			end
			return n
		end
		local function popupsOf(p)
			local list = {}
			for _, row in log.Popups do
				if row.Player == p then
					table.insert(list, row.Summary)
				end
			end
			return list
		end
		-- Every moment before event-clock time t passes in the wait: spared, sets nothing.
		local function spareUntil(run, t)
			run.Waiting = true
			to(t)
			run.Waiting = false
		end
		-- One hit that empties HP.
		local function kill(p)
			local old = S.Hooks.DamageMulti
			S.Hooks.DamageMulti = function()
				return 1e9
			end
			local dealt = S.RecordHit(p)
			S.Hooks.DamageMulti = old
			return dealt
		end
		local function serviceSection(name, body)
			section(name, function()
				S.SetClock(function()
					return clock
				end)
				clock = T0
				S.Reset(T0)
				install()
				body()
			end)
		end

		local moments = momentsOf(BossDodge, MAGE)
		local function momentT(row) -- on the event clock
			return FIGHT + row.At
		end
		local found = {}
		for name in COST do
			found[name] = firstOf(moments, name)
			flag("moment_found_" .. string.lower(name), found[name] ~= nil)
		end

		-- Which boss: named, refused, random (decision D1 option A).
		serviceSection("pick", function()
			for _, id in { MAGE, RAGA } do
				local tag = id == MAGE and "mage" or "raga"
				eq("pick_named_" .. tag .. "_starts", begin(id), true)
				eq("pick_named_" .. tag, S.State().Boss, id)
				eq("pick_named_" .. tag .. "_attribute", ReplicatedStorage:GetAttribute("BossEventBoss"), id)
				S.End("Timeout")
				eq("pick_attribute_cleared_" .. tag, ReplicatedStorage:GetAttribute("BossEventBoss"), nil)
			end
			S.Reset(T0)
			install()
			local ok, why = S.Start("Test", "boss_nobody")
			eq("pick_unknown_refused", ok, false)
			eq("pick_unknown_reason", why, "Unknown boss")
			eq("pick_unknown_no_event", S.State().Phase, "Idle")
		end)

		serviceSection("pick_random", function()
			eq("pick_hook_exists", type(realHooks.PickBoss), "function")
			local calls = 0
			local function stub(id)
				calls = 0
				S.Hooks.PickBoss = function()
					calls += 1
					return id
				end
			end
			for _, id in { MAGE, RAGA } do
				local tag = id == MAGE and "mage" or "raga"
				S.Reset(T0)
				install()
				stub(id)
				S.Start("Test")
				eq("pick_hook_test_start_" .. tag, S.State().Boss, id)
				eq("pick_hook_called_once_" .. tag, calls, 1)
			end
			-- The timer starts the boss picked when it was scheduled (BossEventNextBoss), then picks the following one.
			stub(MAGE)
			S.Reset(T0)
			calls = 0
			S.Advance(T0 + Cfg.IntervalSeconds)
			eq("pick_timer_source", S.State().Source, "Timer")
			eq("pick_hook_timer_start", S.State().Boss, MAGE)
			eq("pick_hook_called_by_timer", calls, 1)
			S.Reset(T0)
			stub(MAGE)
			S.Start("Paid")
			eq("pick_hook_paid_start", S.State().Boss, MAGE)
			eq("pick_hook_called_by_paid", calls, 1)
			S.Reset(T0)

			-- The real hook: Raga in the test harness, both bosses otherwise. No yield while CarTestRunning is off.
			local inTests = {}
			for _ = 1, 50 do
				inTests[realHooks.PickBoss()] = true
			end
			flag("pick_default_in_tests_is_raga", inTests[RAGA] == true and next(inTests, next(inTests)) == nil)
			local seen, unknown = {}, nil
			local was = ReplicatedStorage:GetAttribute("CarTestRunning")
			local okRun, err = pcall(function()
				ReplicatedStorage:SetAttribute("CarTestRunning", false)
				for _ = 1, 200 do
					local id = realHooks.PickBoss()
					seen[id] = true
					if id ~= RAGA and id ~= MAGE and id ~= "boss_king" then -- the third boss (owner 2026-11-11)
						unknown = id
					end
				end
			end)
			ReplicatedStorage:SetAttribute("CarTestRunning", was)
			flag("pick_default_ran", okRun, okRun and 1 or tostring(err))
			flag("pick_random_both_raga", seen[RAGA] == true)
			flag("pick_random_both_mage", seen[MAGE] == true)
			eq("pick_random_only_known_ids", unknown, nil)
		end)

		-- Costs (owner 2026-11-11): every slot in run.Line, x VulnerableMulti once Vulnerable, Kami untouched.
		local function freshTrio(kamiSlot)
			begin(MAGE)
			local p, ids = trio()
			S.Join(p)
			S.SetTeam(p, ids)
			to(FIGHT)
			local run = log.Runs[p]
			if kamiSlot then
				run.Team = table.clone(run.Team)
				run.Team[kamiSlot] = catalog.KAMI_ID
			end
			return p, run
		end
		for name, cost in COST do
			serviceSection("cost_" .. string.lower(name), function()
				local row = found[name]
				if not row then
					return
				end
				local _, run = freshTrio()
				spareUntil(run, momentT(row) - 0.3)
				to(momentT(row) + 0.05)
				for slot = 1, 3 do
					near(("cost_%s_%d_slot_%d"):format(string.lower(name), cost, slot), run.Stamina[slot], 100 - cost)
				end
			end)
		end
		serviceSection("cost_rules", function()
			local first = found.Lightning
			if not first then
				return
			end
			local nextRow = moments[first.Index + 1]
			local p, run = freshTrio()
			spareUntil(run, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			flag("cost_sets_vulnerable", statusRow(p, "Vulnerable") ~= nil)
			to(momentT(nextRow) + 0.05)
			near(
				"cost_vulnerable_x1_5",
				run.Stamina[1],
				100 - COST.Lightning - COST[nextRow.Name] * Cfg.VulnerableMulti
			)
			eq("cost_vulnerable_multi_is_1_5", Cfg.VulnerableMulti, 1.5)

			local _, kamiRun = freshTrio(2)
			spareUntil(kamiRun, momentT(first) - 0.3)
			to(momentT(first) + 0.05)
			near("cost_kami_slot_untouched", kamiRun.Stamina[2], 100)
			near("cost_kami_team_others_pay", kamiRun.Stamina[1], 100 - COST.Lightning)

			local _, lineRun = freshTrio()
			spareUntil(lineRun, momentT(first) - 0.3)
			lineRun.Line = { 1, 3 }
			to(momentT(first) + 0.05)
			near("cost_skips_slot_out_of_line", lineRun.Stamina[2], 100)
			near("cost_line_slot_pays", lineRun.Stamina[3], 100 - COST.Lightning)

			local waitP, waitRun = freshTrio()
			spareUntil(waitRun, momentT(first) + 0.05)
			near("cost_none_in_wait", waitRun.Stamina[1], 100)
			eq("cost_wait_sets_nothing", statusRow(waitP, "Vulnerable"), nil)

			-- Joined after the moment: never charged for it.
			begin(MAGE)
			local early = fighter()
			S.Join(early)
			to(momentT(first) + 0.1)
			local late = fighter()
			S.Join(late)
			to(momentT(first) + 0.3)
			local lateRun = log.Runs[late]
			flag("cost_late_run_started", lateRun ~= nil)
			near("cost_none_before_join", lateRun and lateRun.Stamina[1], 100)
		end)

		-- The Stone Golem miniboss (design doc 4.37, owner 2026-11-11). Sections need the bake's slot; without it they fail once.
		local function golemSection(name, body)
			serviceSection(name, function()
				if type(SLOT) ~= "number" or type(CYCLE) ~= "number" then
					flag(name .. "_ready", false)
					return
				end
				body()
			end)
		end
		local function minionAttribute(name)
			return ReplicatedStorage:GetAttribute(name)
		end
		local function minionCleared()
			for _, name in MINION_ATTRIBUTES do
				if minionAttribute(name) ~= nil then
					return false
				end
			end
			return true
		end
		-- A fighter in her event, every move of hers before the slot passed in the wait, the golem just up. Her and the golem's
		-- damage held at 0, so it stands until a test kills it. Returns the player, the run and BossMinionStart.
		local function golemFresh(p, ids)
			p = p or fighter()
			begin(MAGE)
			S.Hooks.DamageMulti = function()
				return 0
			end
			S.Join(p)
			if ids then
				S.SetTeam(p, ids)
			end
			to(FIGHT)
			local run = log.Runs[p]
			spareUntil(run, FIGHT + SLOT + 0.05)
			return p, run, minionAttribute("BossMinionStart") or T0 + FIGHT + SLOT
		end

		golemSection("golem_start", function()
			local p = fighter()
			begin(MAGE)
			S.Hooks.DamageMulti = function()
				return 0
			end
			S.Join(p)
			to(FIGHT)
			local hp = S.State().Hp
			to(FIGHT + SLOT - 0.05)
			flag("golem_start_none_before_slot", minionCleared())
			to(FIGHT + SLOT + 0.05)
			eq("golem_start_hp_1000", minionAttribute("BossMinionHp"), GOLEM_HP)
			eq("golem_start_max_hp_1000", minionAttribute("BossMinionMaxHp"), GOLEM_HP)
			-- The slot's schedule time, not the tick that saw it.
			near("golem_start_at_slot", minionAttribute("BossMinionStart"), T0 + FIGHT + SLOT, 1e-6)
			eq("golem_start_her_hp_unchanged", S.State().Hp, hp)
			eq("golem_start_her_attribute_unchanged", ReplicatedStorage:GetAttribute("BossEventHp"), hp)
		end)

		-- Owner 2026-11-12: 1,000 HP per player in the arena when it rises; a join or a leave while it stands changes nothing.
		golemSection("golem_hp_per_player", function()
			local players = { fighter(), fighter(), fighter() }
			begin(MAGE)
			S.Hooks.DamageMulti = function()
				return 0
			end
			for i, p in players do
				eq("golem_hp_join_" .. i, S.Join(p), true)
			end
			to(FIGHT)
			for _, p in players do -- every move of hers before the slot passes in the wait: all 3 still in the arena
				log.Runs[p].Waiting = true
			end
			to(FIGHT + SLOT + 0.05)
			for _, p in players do
				log.Runs[p].Waiting = false
			end
			eq("golem_hp_3_players_3000", minionAttribute("BossMinionHp"), 3 * GOLEM_HP)
			eq("golem_max_hp_3_players_3000", minionAttribute("BossMinionMaxHp"), 3 * GOLEM_HP)
			local ms = minionAttribute("BossMinionStart") or T0 + FIGHT + SLOT
			to(ms - T0 + 1)
			eq("golem_hp_late_join_ok", S.Join(fighter()), true)
			S.Leave(players[1], "Left")
			to(ms - T0 + 1.5)
			eq("golem_max_hp_join_leave_unchanged", minionAttribute("BossMinionMaxHp"), 3 * GOLEM_HP)
			eq("golem_hp_join_leave_unchanged", minionAttribute("BossMinionHp"), 3 * GOLEM_HP)
		end)

		golemSection("golem_takes_damage", function()
			local p, _, ms = golemFresh()
			to(ms - T0 + 1)
			local golemHp, herHp = minionAttribute("BossMinionHp"), ReplicatedStorage:GetAttribute("BossEventHp")
			local damage, stageDamage = S.DamageOf(p), S.StageDamageOf(p, 1)
			S.Hooks.DamageMulti = function()
				return 1
			end
			local dealt = S.RecordHit(p)
			S.Hooks.DamageMulti = function()
				return 0
			end
			flag("golem_hit_dealt", type(dealt) == "number" and dealt > 0, dealt, "> 0")
			near("golem_hit_lowers_golem_hp", minionAttribute("BossMinionHp"), (golemHp or 0) - (dealt or 0))
			eq("golem_hit_her_hp_untouched", ReplicatedStorage:GetAttribute("BossEventHp"), herHp)
			eq("golem_hit_her_state_hp_untouched", S.State().Hp, herHp)
			near("golem_hit_counts_in_damage", S.DamageOf(p), damage + (dealt or 0))
			near("golem_hit_not_in_stage_damage", S.StageDamageOf(p, 1), stageDamage)
		end)

		golemSection("golem_pauses_her", function()
			local p, run, ms = golemFresh()
			table.clear(log.MoveChat)
			-- Her next moment on the stale clock: its bar would be open now if her clock still ran.
			local herNext = BossDodge.IndexAtOrBefore(SLOT + 0.01, MAGE) + 1
			local herAt = BossDodge.Moment(herNext, MAGE)
			to(FIGHT + herAt - 0.5)
			local ok, why = S.Dodge(p, herNext, clock)
			eq("golem_dodge_bar_refused", ok, false)
			eq("golem_dodge_bar_reason", why, "No bar")
			to(ms - T0 + 60)
			flag("golem_kept_alive_60_s", minionAttribute("BossMinionHp") == GOLEM_HP, minionAttribute("BossMinionHp"))
			local hers, golems = {}, 0
			for _, row in log.MoveChat do
				if row.Text == MOVE_CHAT.Lightning or row.Text == MOVE_CHAT.Barrage then
					table.insert(hers, row.Text)
				elseif row.Text == GOLEM_CHAT.Slam or row.Text == GOLEM_CHAT.Sweep then
					golems += 1
				end
			end
			eq("golem_pauses_her_moves", table.concat(hers, " | "), "")
			flag("golem_attacks_while_she_waits", golems >= 10, golems, 10)
			flag("golem_pause_run_kept", log.Runs[p] == run)
		end)

		golemSection("golem_attacks", function()
			-- A full line of 3 (trio), so every slot pays.
			local p, run, ms = golemFresh(trio())
			local stamina = 100
			for k = 1, 4 do
				local at, name = ms - T0 + golemTau(k), golemName(k)
				local tag = ("golem_attack_%d_%s"):format(k, string.lower(name))
				to(at - 0.05)
				near(tag .. "_not_before", run.Stamina[1], stamina)
				table.clear(log.MoveChat)
				to(at + 0.05)
				-- An undodged hit leaves the player Vulnerable (proposed: as on her moves): every later one costs 1.5 x.
				local cost = GOLEM_COST * (k == 1 and 1 or Cfg.VulnerableMulti)
				stamina -= cost
				for slot = 1, 3 do
					near(("%s_costs_%s_slot_%d"):format(tag, tostring(cost), slot), run.Stamina[slot], stamina)
				end
				local last = log.MoveChat[#log.MoveChat]
				eq("move_chat_" .. tag, last and last.Text, GOLEM_CHAT[name])
				local count = 0
				for j = 1, k do
					count += golemTau(j) + STATUS_SECONDS > golemTau(k) + 0.05 and 1 or 0
				end
				local row = statusRow(p, "Crushed")
				eq(tag .. "_crushed_count", row and row.Count, count)
				near(tag .. "_crushed_ends_at", row and row.EndsAt, ms + golemTau(k) + STATUS_SECONDS, 0.01)
			end
		end)

		golemSection("golem_falls_resume", function()
			local p, run, ms = golemFresh()
			local oldStart = ReplicatedStorage:GetAttribute("BossScheduleStart")
			local fall = ms - T0 + 1 -- before its first attack: nothing charged, nothing Vulnerable
			to(fall)
			kill(p)
			flag("golem_fall_attributes_clear", minionCleared())
			eq("golem_fall_event_runs", S.State().Phase, "Fight")
			near(
				"golem_fall_schedule_shifted",
				ReplicatedStorage:GetAttribute("BossScheduleStart"),
				oldStart + (T0 + fall - ms)
			)
			local lightning = found.Lightning
			if lightning then
				-- Her clock resumes at the slot: the next Lightning is the next cycle's.
				local due = fall + lightning.At + CYCLE - SLOT
				to(due - 0.3)
				near("golem_fall_no_lightning_early", run.Stamina[1], 100)
				to(due + 0.05)
				near("golem_fall_lightning_on_time", run.Stamina[1], 100 - COST.Lightning)
			end
			to(fall + CYCLE - 0.05)
			flag("golem_fall_no_second_golem_early", minionCleared())
			to(fall + CYCLE + 0.05)
			eq("golem_second_starts", minionAttribute("BossMinionHp"), GOLEM_HP)
			near("golem_second_on_time", minionAttribute("BossMinionStart"), T0 + fall + CYCLE, 1e-6)
		end)

		golemSection("golem_wait_spared", function()
			local p, run, ms = golemFresh()
			spareUntil(run, ms - T0 + golemTau(1) + 0.05)
			near("golem_wait_no_cost", run.Stamina[1], 100)
			eq("golem_wait_no_crushed", statusRow(p, "Crushed"), nil)
			eq("golem_wait_not_vulnerable", statusRow(p, "Vulnerable"), nil)
			to(ms - T0 + golemTau(1) + 1)
			near("golem_wait_never_owed", run.Stamina[1], 100)
			to(ms - T0 + golemTau(2) + 0.05)
			near("golem_after_wait_charged", run.Stamina[1], 100 - GOLEM_COST)
		end)

		golemSection("golem_late_join", function()
			local _, _, ms = golemFresh()
			to(ms - T0 + golemTau(1) + 1.8)
			local late = fighter()
			eq("golem_late_join_ok", S.Join(late), true)
			local lateRun = log.Runs[late]
			flag("golem_late_run_started", lateRun ~= nil)
			if not lateRun then
				return
			end
			to(ms - T0 + golemTau(1) + 2.1)
			near("golem_late_no_charge_before_join", lateRun.Stamina[1], 100)
			to(ms - T0 + golemTau(2) + 0.05)
			near("golem_late_charged_after_join", lateRun.Stamina[1], 100 - GOLEM_COST)
			local fall = ms - T0 + golemTau(2) + 0.1
			to(fall)
			kill(late)
			flag("golem_late_fall_clears", minionCleared())
			local lightning = found.Lightning
			if lightning then
				local before = lateRun.Stamina[1]
				to(fall + lightning.At + CYCLE - SLOT + 0.05)
				-- Vulnerable since the golem's hit (proposed rule as on her moves).
				near("golem_late_pays_her_lightning", lateRun.Stamina[1], before - COST.Lightning * Cfg.VulnerableMulti)
			end
		end)

		golemSection("golem_timeout", function()
			local p = golemFresh()
			to(Cfg.TotalSeconds - 1)
			eq("golem_timeout_still_standing", minionAttribute("BossMinionHp"), GOLEM_HP)
			to(Cfg.TotalSeconds + 1)
			eq("golem_timeout_ends", S.State().LastEnd, "Timeout")
			eq("golem_timeout_pays_nothing", #log.Paid, 0)
			eq("golem_timeout_no_popup", #popupsOf(p), 0)
			flag("golem_timeout_attributes_clear", minionCleared())
		end)

		-- Crushed (owner 2026-11-11): each golem hit's 20% damage cut for 15 s, stacking; her schedule cuts nothing.
		section("crushed_pure", function()
			local multi = realHooks.DamageMulti
			eq("damage_multi_hook_exists", type(multi), "function")
			if type(multi) ~= "function" then
				return
			end
			local t = INTRO + 1
			near("crushed_cut_0_8", multi(t, {}, 1, MAGE, 1), 1 - CRUSHED_CUT)
			near("crushed_two_stacks_0_64", multi(t, {}, 1, MAGE, 2), (1 - CRUSHED_CUT) ^ 2)
			near("crushed_no_stack_1", multi(t, {}, 1, MAGE, 0), 1)
			near("crushed_nil_stacks_1", multi(t, {}, 1, MAGE), 1)
			-- Her own schedule never cuts her damage (the golem's hits are not on it).
			local cut = nil
			for k = 0, math.ceil(2 * (CYCLE or 33) / 0.25) do
				local at = INTRO + k * 0.25
				if cut == nil and multi(at, {}, 1, MAGE) ~= 1 then
					cut = at
				end
			end
			eq("mage_schedule_no_cut", cut, nil)
			-- Raga's statuses never apply to her, nor hers to Raga.
			local differ = nil
			for k = 0, 120 do
				local at = INTRO + k * 0.5
				if differ == nil and multi(at, {}, 1, RAGA) ~= multi(at, {}, 1) then
					differ = at
				end
			end
			eq("raga_multi_unchanged", differ, nil)
			near("raga_ignores_crushes", multi(INTRO + 1, {}, 1, RAGA, 2), multi(INTRO + 1, {}, 1, RAGA))
		end)

		golemSection("crushed_service", function()
			local p, run, ms = golemFresh()
			local live = false
			S.Hooks.DamageMulti = function(...)
				return live and realHooks.DamageMulti(...) or 0
			end
			to(ms - T0 + golemTau(1) + 0.05)
			local row = statusRow(p, "Crushed")
			flag("crushed_row_listed", row ~= nil)
			eq("crushed_row_count", row and row.Count, 1)
			near("crushed_row_ends_at", row and row.EndsAt, ms + golemTau(1) + STATUS_SECONDS, 0.01)
			local base, golemHp = S.TeamDamage(p), minionAttribute("BossMinionHp") or 0
			live = true
			local dealt = S.RecordHit(p)
			live = false
			near("crushed_hit_dealt_0_8", dealt, math.min(base * (1 - CRUSHED_CUT), golemHp))
			local ids = {}
			for _, item in HttpService:JSONDecode(p:GetAttribute("BossStatus") or "[]") do
				ids[item.Id] = true
			end
			flag("crushed_rows_only_mage", ids.Shouted == nil and ids.Adapted == nil)
			spareUntil(run, ms - T0 + golemTau(1) + STATUS_SECONDS + 0.1)
			eq("crushed_row_gone_after_15_s", statusRow(p, "Crushed"), nil)

			for _, name in { "Lightning", "Barrage" } do
				local move = found[name]
				if move then
					local q = fighter()
					begin(MAGE)
					S.Join(q)
					to(FIGHT)
					spareUntil(log.Runs[q], momentT(move) - 0.3)
					to(momentT(move) + 0.05)
					local rows = HttpService:JSONDecode(q:GetAttribute("BossStatus") or "[]")
					local others = {}
					for _, item in rows do
						if item.Id ~= "Vulnerable" then
							table.insert(others, item.Id)
						end
					end
					eq(string.lower(name) .. "_only_vulnerable_row", table.concat(others, ","), "")
					flag(string.lower(name) .. "_sets_vulnerable", statusRow(q, "Vulnerable") ~= nil)
				end
			end
		end)

		-- Rhythm circles (owner 2026-11-11, proposed values): the server judges each circle's stamp, on the golem's clock.
		local function osuFresh(k)
			k = k or 1
			local p, run, ms = golemFresh()
			-- Attack 1's circles open at the golem's start (OpenSeconds 4.2): never step the clock back before it.
			spareUntil(run, math.max(ms - T0 + golemTau(k) - Osu.OpenSeconds - 0.2, ms - T0 + 0.05))
			local rows = Osu.Circles(p:GetAttribute("UserId"), ms, k)
			local M = ms + golemTau(k)
			local function beat(c)
				return M - rows[c].Lead
			end
			local function pressAt(c, stamp, arrives, attack)
				to((arrives or stamp) - T0)
				return S.Osu(p, attack or k, c, stamp)
			end
			return p, run, M, beat, pressAt, ms
		end
		-- Presses { circle, stamp, arrives } in arrival order; returns each circle's ok, reason.
		local function pressAll(pressAt, list)
			table.sort(list, function(a, b)
				return (a[3] or a[2]) < (b[3] or b[2])
			end)
			local results = {}
			for _, press in list do
				local ok, why = pressAt(press[1], press[2], press[3])
				results[press[1]] = { ok, why }
			end
			return results
		end
		golemSection("osu", function()
			if not Osu then
				flag("osu_ready", false)
				return
			end
			local p, run, M, beat, pressAt = osuFresh()
			local lane = S.LaneOf(p)
			local results = {}
			for c = 1, 3 do
				results[c] = { pressAt(c, beat(c)) }
			end
			for c = 1, 2 do
				eq("osu_all_three_press_" .. c .. "_ok", results[c][1], true)
			end
			eq("osu_all_three_spares", results[3][1], true)
			eq("osu_all_three_reason_dodged", results[3][2], "Dodged")
			eq("osu_duplicate_circle_refused", pressAt(1, clock), false)
			eq("osu_duplicate_circle_reason", select(2, S.Osu(p, 1, 2, clock)), "Already pressed")
			to(M - T0 + 0.05)
			for slot = 1, 3 do
				near("osu_spared_no_cost_slot_" .. slot, run.Stamina[slot], 100)
			end
			eq("osu_spared_no_crushed", statusRow(p, "Crushed"), nil)
			flag("osu_spared_lane_switch_hook", #log.Lanes >= 1)
			flag("osu_spared_lane_moved", S.LaneOf(p) ~= lane, S.LaneOf(p), lane)

			p, run, M, beat, pressAt = osuFresh()
			for c = 1, 2 do
				pressAt(c, beat(c))
			end
			to(M - T0 + 0.05)
			near("osu_two_of_three_hits", run.Stamina[1], 100 - GOLEM_COST)
			flag("osu_two_of_three_crushed", statusRow(p, "Crushed") ~= nil)

			p, run, M, beat, pressAt = osuFresh()
			results = pressAll(pressAt, {
				{ 1, beat(1) },
				{ 2, beat(2) - 0.45 },
				{ 3, beat(3) },
			})
			eq("osu_one_miss_refused", results[2][1], false)
			eq("osu_one_miss_reason", results[2][2], "Missed")
			flag("osu_after_miss_not_dodged", results[3][2] ~= "Dodged", results[3][2])
			to(M - T0 + 0.05)
			near("osu_one_miss_hits", run.Stamina[1], 100 - GOLEM_COST)
			flag("osu_one_miss_crushed", statusRow(p, "Crushed") ~= nil)

			-- Each bad press: refused, and that circle is spent, so the attack hits.
			-- Attack 2: its circles open OpenSeconds before its hit, while the golem stands (attack 1's open at its start).
			p, run, M, beat, pressAt = osuFresh(2)
			eq("osu_before_open_refused", pressAt(1, M - Osu.OpenSeconds - 0.1), false)
			eq("osu_before_open_reason", select(2, S.Osu(p, 2, 1, clock)), "No circles")
			to(M - Osu.OpenSeconds - T0 + 0.01)
			local _, openWhy = S.Osu(p, 2, 2, clock)
			flag("osu_open_from_open_seconds", openWhy ~= "No circles", openWhy)
			eq("osu_future_stamp_refused", pressAt(1, beat(1), beat(1) - 0.1), false)
			p, run, M, beat, pressAt = osuFresh()
			eq("osu_late_stamp_refused", pressAt(1, beat(1), beat(1) + 0.52), false)
			eq("osu_late_stamp_spends_circle", pressAt(1, clock), false)
			for _, bad in { 0, 4, 1.5, 0 / 0, math.huge, "1" } do
				local ok, why = S.Osu(p, 1, bad, clock)
				eq("osu_bad_circle_refused_" .. tostring(bad), ok, false)
				eq("osu_bad_circle_reason_" .. tostring(bad), why, "Invalid press")
			end
			for _, bad in { "1", 0, -1, 1.5, math.huge, 0 / 0 } do
				eq("osu_bad_index_refused_" .. tostring(bad), S.Osu(p, bad, 2, clock), false)
			end
			eq("osu_bad_stamp_text", S.Osu(p, 1, 2, "x"), false)
			eq("osu_bad_stamp_nan", S.Osu(p, 1, 2, 0 / 0), false)
			eq("osu_outsider_reason", select(2, S.Osu(fighter(), 1, 2, clock)), "Not in the event")
			to(M - T0 + 0.01)
			eq("osu_after_moment_refused", S.Osu(p, 1, 3, beat(3)), false)
			eq("osu_after_moment_reason", select(2, S.Osu(p, 1, 2, M - 0.01)), "No circles")
			near("osu_bad_presses_hit", run.Stamina[1], 100 - GOLEM_COST)

			-- No golem standing: no circles.
			local q = fighter()
			begin(MAGE)
			S.Join(q)
			to(FIGHT + 1)
			local ok, why = S.Osu(q, 1, 1, clock)
			eq("osu_no_golem_refused", ok, false)
			eq("osu_no_golem_reason", why, "No circles")

			-- Attack k's stamps sent again for k + 1: a different beat.
			p, run, M, beat, pressAt = osuFresh(1)
			local old = {}
			for c = 1, 3 do
				old[c] = beat(c)
				pressAt(c, old[c])
			end
			local nextM = M + GOLEM_EVERY
			to(nextM - Osu.OpenSeconds - T0 + 0.5)
			local replayed = 0
			for c = 1, 3 do
				replayed += S.Osu(p, 2, c, old[c]) == true and 1 or 0
			end
			eq("osu_replay_next_attack_refused", replayed, 0)
			to(nextM - T0 + 0.05)
			near("osu_replay_next_attack_hits", run.Stamina[1], 100 - GOLEM_COST)

			-- The previous golem's k = 1 stamps sent for the next golem's k = 1.
			local ms
			p, run, M, beat, pressAt, ms = osuFresh(1)
			for c = 1, 3 do
				old[c] = beat(c)
			end
			local lastOk, lastWhy
			for c = 1, 3 do
				lastOk, lastWhy = pressAt(c, old[c])
			end
			eq("osu_first_golem_dodged", lastWhy, "Dodged")
			to(M - T0 + 0.1)
			kill(p)
			local fall = clock - T0
			spareUntil(run, fall + CYCLE + 1.5)
			local ms2 = minionAttribute("BossMinionStart")
			flag("osu_second_golem_up", type(ms2) == "number" and ms2 ~= ms, ms2, ms)
			replayed = 0
			for c = 1, 3 do
				replayed += S.Osu(p, 1, c, old[c]) == true and 1 or 0
			end
			eq("osu_replay_next_golem_refused", replayed, 0)
			to((ms2 or 0) - T0 + golemTau(1) + 0.05)
			near("osu_replay_next_golem_hits", run.Stamina[1], 100 - GOLEM_COST)
			flag("osu_first_dodge_ok", lastOk == true)

			-- In the wait: not running.
			p, run, M, beat, pressAt = osuFresh()
			run.Waiting = true
			ok, why = pressAt(1, beat(1))
			eq("osu_in_wait_refused", ok, false)
			eq("osu_in_wait_reason", why, "Not running")
		end)

		-- The next timed event's boss is picked when it is scheduled (BOSS_EVENT_SPEC "Bosses cards", proposed).
		serviceSection("next_boss", function()
			local function nextBoss()
				return ReplicatedStorage:GetAttribute("BossEventNextBoss")
			end
			S.Hooks.PickBoss = realHooks.PickBoss
			S.Reset(T0)
			eq("next_boss_default_raga", nextBoss(), RAGA)
			local queue, calls = {}, 0
			S.Hooks.PickBoss = function()
				calls += 1
				return table.remove(queue, 1) or RAGA
			end
			queue = { MAGE, RAGA }
			S.Reset(T0)
			eq("next_boss_picked_mage", nextBoss(), MAGE)
			S.Advance(T0 + Cfg.IntervalSeconds)
			eq("next_boss_timer_source", S.State().Source, "Timer")
			eq("next_boss_timer_starts_announced", S.State().Boss, MAGE)
			eq("next_boss_repicked", nextBoss(), RAGA)
			eq("next_boss_two_picks", calls, 2)
			S.End("Timeout")
			eq("next_boss_kept_after_end", nextBoss(), RAGA)
			queue = { MAGE }
			S.Reset(T0)
			queue = { RAGA }
			eq("next_boss_paid_start", S.Start("Paid"), true)
			eq("next_boss_paid_picks_fresh", S.State().Boss, RAGA)
			eq("next_boss_paid_leaves_announced", nextBoss(), MAGE)
			S.Hooks.PickBoss = realHooks.PickBoss
		end)

		-- Her defeat pays her own chest (design doc 4.37, RELIC_SPEC "The Elf Mage's drops"); nil boss stays Raga's.
		serviceSection("pay_mage_chest", function()
			local Relic = require(Server.RelicService)
			local money = require(Server.MoneyService)
			for _, case in { { "mage", MAGE, "relic_chest_mage" }, { "default", nil, "relic_chest_raga" } } do
				local tag, boss, chest = case[1], case[2], case[3]
				local p = newPlayer()
				local cash = money.Setup(p)
				local start = cash.Value
				eq("pay_" .. tag .. "_ok", realHooks.PayStage(p, 1, boss), true)
				local bag = Relic.Snapshot(p).Relics or {}
				eq("pay_" .. tag .. "_one_chest", #bag, 1)
				eq("pay_" .. tag .. "_chest", bag[1] and bag[1].Id, chest)
				eq("pay_" .. tag .. "_phase_1_money", cash.Value, start + Cfg.Phase1Money)
			end
		end)

		-- One stage only (owner 2026-11-11): her defeat ends the event and pays Phase 1 once.
		serviceSection("no_stage_2", function()
			local p = fighter()
			begin(MAGE)
			S.Join(p)
			to(FIGHT + 1)
			kill(p)
			eq("no_stage_2_defeated", S.State().LastEnd, "Defeated")
			eq("no_stage_2_idle", S.State().Phase, "Idle")
			flag("no_stage_2_never_stage_2", ReplicatedStorage:GetAttribute("BossEventStage") ~= 2)
			eq("no_stage_2_no_scream", ReplicatedStorage:GetAttribute("BossScreamEndsAt"), nil)
			eq("no_stage_2_pays_stage_1_once", timesPaid(p, 1), 1)
			eq("no_stage_2_pays_no_stage_2", timesPaid(p, 2), 0)
			local popups = popupsOf(p)
			eq("no_stage_2_one_popup", #popups, 1)
			local summary = popups[1] or {}
			eq("no_stage_2_popup_outcome", summary.Outcome, "Defeated")
			eq("no_stage_2_popup_boss", summary.Boss, MAGE)
			eq("no_stage_2_popup_stage1", summary.Stage1, true)
			eq("no_stage_2_popup_stage2", summary.Stage2, false)

			local q = fighter()
			begin(MAGE)
			S.Join(q)
			to(FIGHT)
			log.Runs[q].Waiting = true -- no hits on the way: the timeout must not be a defeat
			to(Cfg.TotalSeconds + 1)
			eq("timeout_ends", S.State().LastEnd, "Timeout")
			eq("timeout_pays_nothing", #log.Paid, 0)
			eq("timeout_no_popup", #log.Popups, 0)
		end)

		serviceSection("chat", function()
			local p = fighter()
			begin(MAGE)
			S.Join(p)
			to(PREP + 0.25)
			eq("chat_text_mage", log.Chat[1], CHAT)
			to(FIGHT)
			for name, text in MOVE_CHAT do
				local row = found[name]
				if row then
					local q = fighter()
					begin(MAGE)
					S.Join(q)
					to(FIGHT)
					spareUntil(log.Runs[q], momentT(row) - 0.3)
					table.clear(log.MoveChat)
					to(momentT(row) + 0.05)
					local last = log.MoveChat[#log.MoveChat]
					eq("move_chat_" .. string.lower(name), last and last.Text, text)
				end
			end
		end)

		-- Big Raga stays as he was (design doc 4.37).
		serviceSection("raga_unchanged", function()
			local p = fighter()
			eq("raga_starts", begin(RAGA), true)
			eq("raga_named", S.State().Boss, RAGA)
			S.Join(p)
			to(FIGHT)
			local run = log.Runs[p]
			local ragaMoments = momentsOf(BossDodge, RAGA, 3)
			for i, want in { "Impact", "WheelClick", "Roar" } do
				eq("raga_moment_" .. i, ragaMoments[i].Name, want)
				eq("raga_moment_default_" .. i, (select(2, BossDodge.Moment(i))), want)
			end
			to(FIGHT + ragaMoments[1].At + 0.05)
			near("raga_impact_costs_15", run.Stamina[1], 100 - Cfg.Stage(1).AttackStaminaCost)
			eq("raga_attack_cost_is_15", Cfg.Stage(1).AttackStaminaCost, 15)
			to(FIGHT + ragaMoments[2].At + 0.05)
			near("raga_wheel_costs_nothing", run.Stamina[1], 100 - Cfg.Stage(1).AttackStaminaCost)
			to(FIGHT + ragaMoments[3].At + 0.05)
			flag("raga_shouted_listed", statusRow(p, "Shouted") ~= nil)
			flag("raga_adapted_listed", statusRow(p, "Adapted") ~= nil)
			eq("raga_no_crushed", statusRow(p, "Crushed"), nil)
			eq("raga_shout_cut", Cfg.ShoutDamageCut, 0.25)
			eq("raga_adapted_cut", Cfg.AdaptedCut, 0.1)
			kill(p)
			eq("raga_stage_2_starts", S.State().Stage, 2)
			eq("raga_pays_stage_1", timesPaid(p, 1), 1)
		end)

		-- Run speed cap (design doc 4.37): her colosseum caps the travel at 100 studs/s, the Cruise attribute keeps the real
		-- cruise; the sky arena has no cap. The service's own StartRun hook, a real run on a test runner.
		local CarService = require(Server.CarService)
		local realRunHeld = CarService.RunHeld
		local capRuns = {}
		serviceSection("run_speed_cap", function()
			local race = require(Server.RaceService)
			local factory = require(Shared.RunnerFactory)
			local RaceConfig = require(Shared.RaceConfig)
			CarService.RunHeld = function(p, route, options)
				local car = factory.build(options.Team[1])
				car.Name, car.Parent = "CarTestBossRunner", p
				local run = race.NewRun(car, route, p, options)
				table.insert(capRuns, run)
				return run
			end
			local fast = chars[1]
			for _, id in chars do
				if RaceConfig.Cruise(catalog.Get(id), 1) > RaceConfig.Cruise(catalog.Get(fast), 1) then
					fast = id
				end
			end
			for _, boss in { MAGE, RAGA } do
				local tag = boss == MAGE and "mage" or "raga"
				local p, team = newPlayer(), { fast }
				wear(p, fast, "side_knight")
				p:SetAttribute("EquippedCar", fast)
				local cruise = gacha.CruiseFor(p, fast, 1, team)
				flag("cap_" .. tag .. "_cruise_above_100", cruise > 100, cruise, 100)
				begin(boss)
				local run = realHooks.StartRun(p, team, 1)
				flag("cap_" .. tag .. "_run_started", type(run) == "table")
				if type(run) == "table" then
					local want = boss == MAGE and math.min(cruise, 100) or cruise
					eq("cap_" .. tag .. "_target_speed", run.TargetSpeed, want)
					eq("cap_" .. tag .. "_cruise_attribute_real", p:GetAttribute("Cruise"), cruise)
					local shown = run.Car:GetAttribute("RunSpeed")
					if boss == MAGE then
						flag("cap_mage_runner_speed_at_most_100", type(shown) == "number" and shown <= 100, shown, 100)
					end
				end
			end
		end)
		CarService.RunHeld = realRunHeld
		for _, run in capRuns do
			pcall(run.Destroy, run)
		end

		pcall(function()
			for name in table.clone(S.Hooks) do
				S.Hooks[name] = realHooks[name]
			end
			for name, fn in realHooks do
				S.Hooks[name] = fn
			end
			S.SetClock(nil)
			S.Reset(workspace:GetServerTimeNow())
		end)
		for _, item in cleanup do
			pcall(function()
				item:Destroy()
			end)
		end
		return r
	end

	local function boss_mage_arena()
		local r, flag, section, eq, near = reporter("boss_mage_arena")
		local Arena = H.module(Shared, "BossArenaConfig")
		local Cfg = require(Shared.BossEventConfig)
		local Catalog = H.module(Shared, "BossCatalog")
		flag("arena_for_exists", Arena ~= nil and type(Arena.For) == "function")
		flag("catalog_exists", Catalog ~= nil)
		if not (Arena and type(Arena.For) == "function") then
			return r
		end
		flag("raga_arena_unchanged", rawequal(Arena.For(RAGA), Arena))
		flag("nil_arena_is_raga", rawequal(Arena.For(nil), Arena))
		local M = Arena.For(MAGE)
		flag("mage_arena_differs", type(M) == "table" and not rawequal(M, Arena))
		if type(M) ~= "table" or rawequal(M, Arena) then
			return r
		end

		section("numbers", function()
			eq("inner_radius_70", M.InnerRadius, 70)
			eq("width_56", M.Width, 56)
			eq("lanes_7", M.Lanes, 7)
			eq("wall_height_70", M.WallHeight, 70)
			eq("wall_radius_164", M.WallRadius, 164)
			eq("y_1200", M.Y, 1200)
			flag("center_at_y", typeof(M.Center) == "Vector3" and approx(M.Center.Y, M.Y, 0.01))
			eq("boss_height_44", M.BossHeight, 44)
			flag("hover_6_to_10", type(M.HoverY) == "number" and M.HoverY >= 6 and M.HoverY <= 10, M.HoverY)
			eq("bob_studs_1_5", M.BobStuds, 1.5)
			eq("bob_seconds_3", M.BobSeconds, 3)
			flag("wall_outside_ring", M.WallRadius > M.InnerRadius + M.Width, M.WallRadius, M.InnerRadius + M.Width)
		end)

		section("camera", function()
			local row = Catalog and Catalog.Get(MAGE)
			local cam = row and row.Camera or {}
			eq("camera_yaw_75", cam.Yaw, 75)
			eq("camera_pitch_14", cam.Pitch, 14)
			eq("camera_zoom_40", cam.Zoom, 40)
			if not (cam.Yaw and cam.Pitch and cam.Zoom) then
				return
			end
			-- The running eye, outward of lane 7, stays inside the wall with 3 studs to spare (decision R1).
			local need = M.LaneRadius(7) + cam.Zoom * math.cos(math.rad(cam.Pitch)) * math.sin(math.rad(cam.Yaw)) + 3
			flag("wall_clears_running_eye", M.WallRadius >= need, M.WallRadius, need)
			local wait = row.WaitCamera
			flag("wait_camera_set", type(wait) == "table")
			if type(wait) ~= "table" then
				return
			end
			eq("wait_camera_out_28", wait.Out, 28)
			eq("wait_camera_up_40", wait.Up, 40)
			eq("wait_camera_down_22", wait.Down, 22)
			eq("max_run_speed_100", M.MaxRunSpeed, 100) -- run speed cap (design doc 4.37)
			eq("raga_max_run_speed_none", Arena.For(RAGA).MaxRunSpeed, nil)
			local worstOut, worstUp = 0, -math.huge
			local function judge(eye)
				worstOut = math.max(worstOut, ((eye - M.Center) * Vector3.new(1, 0, 1)).Magnitude)
				worstUp = math.max(worstUp, eye.Y - M.Y)
			end
			for lane = 1, M.Lanes do
				for i = 0, 11 do
					local a = i * math.pi / 6
					local at = M.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * M.LaneRadius(lane)
					judge(Cfg.WaitCameraCFrame(M.Center, at, wait).Position)
				end
			end
			judge(Cfg.WaitCameraCFrame(M.Center, nil, wait).Position)
			flag("wait_eye_inside_wall", worstOut < M.WallRadius, worstOut, M.WallRadius)
			flag("wait_eye_under_wall_top", worstUp < M.WallHeight, worstUp, M.WallHeight)
		end)

		section("site", function()
			local C = M.Center
			local ragaOuter = Arena.InnerRadius + Arena.Width
			local apart = ((C - Arena.Center) * Vector3.new(1, 0, 1)).Magnitude - ragaOuter - M.WallRadius
			flag("clear_of_raga_arena_1500", apart >= 1500, apart, 1500)
			local reach = math.max(math.abs(C.X), math.abs(C.Z)) + M.WallRadius
			flag("inside_8192", reach < 8192 and C.Y + M.WallHeight < 8192, reach, 8192)
			local skip = {}
			for _, name in { "BossArena", "BossArenaPreview" } do
				local folder = workspace:FindFirstChild(name)
				if folder then
					table.insert(skip, folder)
				end
			end
			local nearest, nearestName = math.huge, "none"
			for _, part in workspace:GetDescendants() do
				if part:IsA("BasePart") and not part:IsA("Terrain") then
					local skipped = false
					for _, folder in skip do
						skipped = skipped or part:IsDescendantOf(folder)
					end
					if not skipped then
						local d = ((part.Position - C) * Vector3.new(1, 0, 1)).Magnitude - part.Size.Magnitude / 2
						if d < nearest then
							nearest, nearestName = d, part:GetFullName()
						end
					end
				end
			end
			r.metrics.nearest_part = nearestName
			flag("clear_of_world_1500", nearest >= 1500, nearest, 1500)
		end)

		section("routes", function()
			local counts, ragaCount = {}, #Arena.LaneRoute(1).WorldWaypoints
			for lane = 1, M.Lanes do
				local tag = "_lane_" .. lane
				local route = M.LaneRoute(lane)
				local wps = route.WorldWaypoints
				local radius = M.LaneRadius(lane)
				flag("route_cached" .. tag, rawequal(route, M.LaneRoute(lane)))
				flag("route_closed" .. tag, route.Closed == true)
				flag("route_repeats_first" .. tag, (wps[#wps] - wps[1]).Magnitude < 1e-3)
				flag("lane_inside_ring" .. tag, radius > M.InnerRadius and radius < M.InnerRadius + M.Width, radius)
				local lap = PathDriver.Arc(wps)[#wps]
				local circle = 2 * math.pi * radius
				flag("route_length" .. tag, math.abs(lap - circle) <= 0.0025 * circle, lap, circle)
				near("route_length_api" .. tag, M.LaneLength(lane), lap, 0.01)
				local onCircle = true
				for _, p in wps do
					onCircle = onCircle
						and approx(((p - M.Center) * Vector3.new(1, 0, 1)).Magnitude, radius, 0.01)
						and approx(p.Y, M.Y, 0.01)
				end
				flag("route_on_circle" .. tag, onCircle)
				counts[lane] = #wps
			end
			local same = true
			for lane = 1, M.Lanes do
				same = same and counts[lane] == ragaCount
			end
			flag("waypoint_counts_match_raga", same, counts[1], ragaCount)
			flag("route_not_raga", not rawequal(M.LaneRoute(1), Arena.LaneRoute(1)))
		end)

		return r
	end

	local function boss_mage_anim()
		local r, flag, section, eq, near = reporter("boss_mage_anim")
		local Event = require(Shared.BossEventConfig)
		local Poses = H.lateData("BossMagePoses") -- design doc 7 "Join size"
		local BossDodge = H.module(Shared, "BossDodge")
		local Osu = H.module(Shared, "BossOsu")
		local Catalog = H.module(Shared, "BossCatalog")
		local Art = H.module(Shared, "BossMageArt")
		flag("poses_module_loads", Poses ~= nil)
		flag("dodge_module_loads", BossDodge ~= nil)
		flag("osu_module_loads", Osu ~= nil)
		flag("catalog_module_loads", Catalog ~= nil)
		flag("art_module_loads", Art ~= nil)

		if Poses then
			section("poses", function()
				eq("bind_is_table", type(Poses.Bind), "table")
				eq("sample_is_function", type(Poses.Sample), "function")
				eq("schedule_is_function", type(Poses.Schedule), "function")
				eq("cycle_is_number", type(Poses.CycleSeconds), "number")
				-- Scale is studs per model unit (as BossRagaPoses): about 44 studs tall, 8 x a character (owner 2026-11-11).
				local Arena = H.module(Shared, "BossArenaConfig")
				local scale = Arena and type(Arena.For) == "function" and Arena.For(MAGE).BossScale or 1
				near("scale_gives_about_44_studs", Poses.Scale * scale * MODEL_HEIGHT_UNITS, 44, 2)
				-- keys.json ends; lightning and barrage merged with their 2 s windows (owner 2026-11-11); the rest proposed.
				local ends = {
					idle = 3.0,
					lightning = 5.2,
					golem = 5.0,
					barrage = 5.4,
					watch = 3.0,
					watch_in = 0.75,
					golem_fall = 2.0,
					lightning_in = 0.75,
					barrage_in = 0.45,
					golem_in = 0.75,
				}
				for name, duration in ends do
					local move = Poses.Moves[name]
					flag(name .. "_exists", move ~= nil)
					near(name .. "_duration", move and move.Duration, duration, 0.01)
				end
				local windows = {}
				for name in Poses.Moves do
					if string.find(name, "_window", 1, true) then
						table.insert(windows, name)
					end
				end
				eq("window_moves_merged", table.concat(windows, ","), "")
				for _, name in { "lightning", "barrage" } do
					local window = Poses.Moves[name] and Poses.Moves[name].Window
					flag(name .. "_window_2_to_4", type(window) == "table" and window[1] == 2 and window[2] == 4)
				end
				for name, move in Poses.Moves do
					local want = MOVE_EVENTS[name]
					local count, at = 0, nil
					for _, event in move.Events do
						count += 1
						at = event.Name == (want and want[1]) and event.Time or at
					end
					eq(name .. "_event_count", count, want and 1 or 0)
					if want then
						near(name .. "_" .. want[1] .. "_time", at, want[2])
					end
				end
				eq("slam_time_4_2", Poses.Moves.golem and Poses.Moves.golem.Events[1].Time, SLAM_AT)
				-- The golem's own tracks (proposed leads and recovers around the approved keys).
				local tracks =
					{ golem_idle = { 2.4 }, golem_slam = { 3.6, "Slam", 2.8 }, golem_sweep = { 4.2, "Sweep", 2.6 } }
				for name, want in tracks do
					local move = Poses.GolemMoves and Poses.GolemMoves[name]
					flag(name .. "_exists", move ~= nil)
					near(name .. "_duration", move and move.Duration, want[1], 0.01)
					local events = move and move.Events or {}
					eq(name .. "_event_count", #events, want[2] and 1 or 0)
					if want[2] then
						eq(name .. "_event_name", events[1] and events[1].Name, want[2])
						near(name .. "_event_time", events[1] and events[1].Time, want[3])
					end
				end
			end)

			-- Approved keys: Sample at each approved time gives the approved pose. 10 per move (was idle 4, lightning 8, golem 6,
			-- barrage 8, watch 2, the golem tracks fewer): design doc 4.37 "Animation rework" (owner 2026-11-12: 10 key frames per
			-- move, replacing 3 to 5) and "Rework approvals" (a move's 2 s window counts inside its 10).
			section("approved", function()
				local counts = { idle = 10, lightning = 10, golem = 10, barrage = 10, watch = 10 }
				for name, want in counts do
					local worst = 0
					local keys = Poses.Approved[name] or {}
					for _, key in keys do
						local parts = Poses.Sample(name, key.Time)
						for part, v in key.Parts do
							local got = parts[part]
							local d = got and (got - Vector3.new(v[1], v[2], v[3])) or Vector3.new(1e9, 0, 0)
							worst = math.max(worst, math.abs(d.X), math.abs(d.Y), math.abs(d.Z))
						end
					end
					flag(name .. "_approved_reproduced", worst <= 0.01, worst, 0.01)
					eq(name .. "_approved_count", #keys, want)
				end
				local stale = {}
				for name in Poses.Approved do
					if string.find(name, "_window", 1, true) then
						table.insert(stale, name)
					end
				end
				eq("approved_no_window_names", table.concat(stale, ","), "")
			end)

			-- The rework keys (design doc 4.37 "Animation rework"): every move's 10 key times equal rework/keys.json (her moves and
			-- golem_fall in Moves, the golem's tracks in GolemMoves, each with Approved = its key times as the king's moves), and spot
			-- poses at keys 1, the hit and 10, compared as rotations (Euler wraps do not matter), so a bake drifting from the keys is
			-- caught. Replaces the hand-copied spot checks of the 2026-11-11 keys (keyframes/keys.json), which the rework supersedes.
			section("mage_rework_keys", function()
				for name, want in KEY_TIMES do
					local move = Poses.Moves[name] or (Poses.GolemMoves and Poses.GolemMoves[name])
					local times = move and move.Approved or {}
					eq(name .. "_rework_key_count", #times, #want)
					local same = #times == #want
					for i, t in want do
						same = same and approx(times[i], t)
					end
					flag(name .. "_rework_key_times", same, table.concat(times, ","), table.concat(want, ","))
					local rows = Poses.Approved[name]
					if Poses.Moves[name] and name ~= "golem_fall" then
						local rowsSame = rows ~= nil and #rows == #want
						for i, t in want do
							rowsSame = rowsSame and approx(rows[i].Time, t)
						end
						flag(name .. "_rework_expected_times", rowsSame, rows and #rows, #want)
					end
				end
				for _, spot in MAGE_SPOTS do
					local name, key, part, want = spot[1], spot[2], spot[3], spot[4]
					local got = (Poses.Sample(name, KEY_TIMES[name][key]))[part]
					local off = typeof(got) == "Vector3" and rotationApart(got, want) or 1e9
					flag(("rework_%s_key_%d_%s"):format(name, key, part), off <= KEY_DEGREES, off, KEY_DEGREES)
				end
				for _, spot in GOLEM_SPOTS do
					local name, key = spot[1], spot[2]
					local ran, _, parts, locs = pcall(Poses.SampleGolem, name, KEY_TIMES[name][key])
					local function turn(got, want)
						return typeof(got) == "Vector3" and rotationApart(got, want) or 1e9
					end
					local function loc(got, want)
						return typeof(got) == "Vector3"
								and math.max(
									math.abs(got.X - want.X),
									math.abs(got.Y - want.Y),
									math.abs(got.Z - want.Z)
								)
							or 1e9
					end
					local ok = ran and type(parts) == "table" and type(locs) == "table"
					local degrees = ok and math.max(turn(parts.Torso, spot[3]), turn(parts.UpperArmR, spot[4])) or 1e9
					local offset = ok and loc(locs.Torso, spot[5]) or 1e9
					flag(
						("rework_golem_%s_key_%d_turn"):format(name, key),
						degrees <= KEY_DEGREES,
						degrees,
						KEY_DEGREES
					)
					flag(("rework_golem_%s_key_%d_loc"):format(name, key), offset <= 0.01, offset, 0.01)
				end
			end)

			-- The jointed rig (BOSS_EVENT_SPEC "Animation rework" Rigs): elbows, knees and 3 segments per tail, in the bind and in
			-- every key of every move of hers (Parts or Held). The golem's rig stays (its 15 keys.json parts).
			section("jointed_rig", function()
				local bind = Poses.Bind or {}
				for _, part in MAGE_JOINTED do
					flag("bind_has_" .. part, bind[part] ~= nil)
				end
				for _, part in MAGE_UNJOINTED do
					eq("bind_no_unjointed_" .. part, bind[part], nil)
				end
				for name, move in Poses.Moves do
					local missing = {}
					for _, key in move.Keys or {} do
						for _, part in MAGE_LIMBS do
							if key.Parts[part] == nil and (move.Held or {})[part] == nil then
								missing[part] = true
							end
						end
					end
					flag(name .. "_keys_carry_limbs", next(missing) == nil and #(move.Keys or {}) > 0, next(missing))
				end
				local golemMissing = {}
				for _, part in GOLEM_PARTS do
					if (Poses.GolemBind or {})[part] == nil then
						table.insert(golemMissing, part)
					end
				end
				eq("golem_bind_unchanged", table.concat(golemMissing, ","), "")
			end)

			-- Per-frame continuity, as BossAnimTests has for Big Raga (BOSS_EVENT_SPEC "Animation rework" Tests): at most 12 degrees
			-- of any part and 0.05 root (key units) per 60 Hz frame, outside the hit snap. Her moves through Sample (root in studs,
			-- / RootStuds), the golem's tracks through SampleGolem (root already golem units).
			section("continuous", function()
				local function keyTimesOf(name, move)
					if KEY_TIMES[name] then
						return KEY_TIMES[name]
					end
					local times = {}
					for _, key in move.Keys or {} do
						table.insert(times, key.Time)
					end
					return (move.Approved and #move.Approved > 0) and move.Approved or times
				end
				local function judge(name, duration, nearEvent, sample)
					local worstDegrees, worstOffset, worstAt, worstPart = 0, 0, 0, nil
					local parts, root = sample(0)
					for k = 1, math.floor(duration / FRAME) do
						local t = k * FRAME
						local nextParts, nextRoot = sample(t)
						if not nearEvent(t) then
							for part, v in nextParts do
								local before = parts[part]
								local d = typeof(before) == "Vector3" and rotationApart(before, v) or 0
								if d > worstDegrees then
									worstDegrees, worstAt, worstPart = d, t, part
								end
							end
							local step = nextRoot - root
							worstOffset = math.max(worstOffset, math.abs(step.X), math.abs(step.Y), math.abs(step.Z))
						end
						parts, root = nextParts, nextRoot
					end
					r.metrics[name .. "_worst_frame_at"] = worstAt
					r.metrics[name .. "_worst_frame_part"] = worstPart
					flag(
						name .. "_frame_degrees",
						worstDegrees <= MAX_DEGREES_PER_FRAME,
						worstDegrees,
						MAX_DEGREES_PER_FRAME
					)
					flag(
						name .. "_frame_offset",
						worstOffset <= MAX_OFFSET_PER_FRAME,
						worstOffset,
						MAX_OFFSET_PER_FRAME
					)
				end
				local rootUnit = Poses.RootStuds or 1
				for name, move in Poses.Moves do
					judge(name, move.Duration, snapsOf(move.Events, keyTimesOf(name, move)), function(t)
						local parts, root = Poses.Sample(name, t)
						return parts, root / rootUnit
					end)
				end
				for _, name in GOLEM_TRACKS do
					local move = Poses.Moves[name] or (Poses.GolemMoves and Poses.GolemMoves[name])
					flag(name .. "_track_exists", move ~= nil)
					if move then
						judge("golem_track_" .. name, move.Duration, snapsOf(move.Events, KEY_TIMES[name]), function(t)
							local _, parts, _, root = Poses.SampleGolem(name, t)
							return parts, root
						end)
					end
				end
			end)

			section("golem", function()
				local count = 0
				for _ in Poses.GolemBind or {} do
					count += 1
				end
				eq("golem_bind_15_parts", count, 15)
				eq("golem_sampler_exists", type(Poses.SampleGolem), "function")
				local function scaleOf(move, t)
					local ran, scale = pcall(Poses.SampleGolem, move, t)
					return ran and scale or nil
				end
				-- Shown through its first slam (owner 2026-11-12: its first circles open at tau 0, 4.2 - OpenSeconds); standing at the move's end.
				for _, t in { 1.26, 2.0, 3.0, SLAM_AT, 5.0 } do
					local scale = scaleOf("golem", t)
					flag("golem_visible_at_" .. t, type(scale) == "number" and scale > 0, scale, "> 0")
				end
				near("golem_stands_at_move_end", scaleOf("golem", 5.0), 1)
				for _, move in { "idle", "lightning", "barrage", "watch" } do
					eq("golem_absent_in_" .. move, scaleOf(move, 1), 0)
				end
				flag("golem_fall_starts_shown", (scaleOf("golem_fall", 0) or 0) > 0, scaleOf("golem_fall", 0))
				eq("golem_fall_ends_at_scale_0", scaleOf("golem_fall", 2.0), 0)
				eq("golem_first_hit_4_2", Poses.GolemFirstHit, GOLEM_FIRST)
				eq("golem_every_6", Poses.GolemEvery, GOLEM_EVERY)
				eq("golem_hit_is_function", type(Poses.GolemHit), "function")
				eq("golem_at_is_function", type(Poses.GolemAt), "function")
				if type(Poses.GolemHit) ~= "function" or type(Poses.GolemAt) ~= "function" then
					return
				end
				local hitsOk = true
				for k = 1, 12 do
					local tau, name = Poses.GolemHit(k)
					hitsOk = hitsOk and approx(tau, golemTau(k)) and name == golemName(k)
				end
				flag("golem_hits_every_6_alternating", hitsOk)
				-- Her rig: the golem move, a lead into watch, then watch on its 3 s loop.
				local herMove, herTime = Poses.GolemAt(2)
				eq("golem_at_her_golem_move", herMove, "golem")
				near("golem_at_her_golem_time", herTime, 2)
				herMove = Poses.GolemAt(5.3)
				eq("golem_at_her_watch_in", herMove, "watch_in")
				herMove, herTime = Poses.GolemAt(5.75 + 4)
				eq("golem_at_her_watch", herMove, "watch")
				near("golem_at_her_watch_loops", herTime, 1)
				-- The golem rig: each hit k >= 2 on its own track, at that track's event; tracks never overlap, and each set of
				-- circles opens only once the previous track has ended.
				local open = Osu and Osu.OpenSeconds or 4.2
				local trackOk, lastEnd = true, Poses.Moves.golem and Poses.Moves.golem.Duration or 5
				local bad = {}
				for k = 2, 10 do
					local tau = golemTau(k)
					local track = k % 2 == 1 and "golem_slam" or "golem_sweep"
					local _, _, golemMove, golemTime = Poses.GolemAt(tau)
					local row = Poses.GolemMoves and Poses.GolemMoves[track]
					local eventAt = row and row.Events[1] and row.Events[1].Time or 0
					trackOk = trackOk and golemMove == track and approx(golemTime, eventAt, 0.01)
					local start = tau - eventAt
					if start < lastEnd - 1e-6 then
						table.insert(bad, "overlap_" .. k)
					end
					if tau - open < lastEnd - 1e-6 then
						table.insert(bad, "circles_" .. k)
					end
					lastEnd = start + (row and row.Duration or 0)
				end
				flag("golem_tracks_on_hits", trackOk)
				eq("golem_tracks_apart", table.concat(bad, ","), "")
				-- The next attack's circles open only after the longest attack track's follow-through (time after its hit).
				local follow = 0
				for _, track in { "golem_slam", "golem_sweep" } do
					local row = Poses.GolemMoves and Poses.GolemMoves[track]
					local eventAt = row and row.Events[1] and row.Events[1].Time or 0
					follow = math.max(follow, (row and row.Duration or 0) - eventAt)
				end
				local gap = (Poses.GolemEvery or 0) - open
				flag("golem_circles_open_after_follow_through", gap >= follow - 1e-6, gap, follow)
				local _, _, idleMove = Poses.GolemAt(3)
				eq("golem_idles_between", idleMove, "golem")
				_, _, idleMove = Poses.GolemAt(golemTau(2) - 3)
				eq("golem_idle_track_between", idleMove, "golem_idle")
				local shown = true
				for tau = 1.26, 60, 1 / 60 do
					local _, _, golemMove, golemTime = Poses.GolemAt(tau)
					shown = shown and (scaleOf(golemMove, golemTime) or 0) > 0
				end
				flag("golem_shown_while_standing", shown)
			end)

			section("schedule", function()
				local START = 5000
				local idle = true
				for t = 0, Event.IntroSeconds - 0.05, 0.1 do
					idle = idle and Poses.Schedule(START, START + t) == "idle"
				end
				flag("schedule_idle_during_intro", idle)
				local seen = {}
				local slotSeen = nil
				local last = nil
				for t = Event.IntroSeconds, Event.IntroSeconds + 2 * Poses.CycleSeconds, 0.01 do
					local move = Poses.Schedule(START, START + t)
					seen[move] = true
					if slotSeen == nil and last == "golem_in" and move == "golem_fall" then
						slotSeen = t - Event.IntroSeconds
					end
					last = move
				end
				for _, name in { "lightning", "barrage", "golem_fall" } do
					flag("schedule_covers_" .. name, seen[name] == true)
				end
				eq("schedule_never_golem", seen.golem, nil)
				near("cycle_32_55", Poses.CycleSeconds, CYCLE_SECONDS, 0.01)
				near("golem_slot_27_55", Poses.GolemSlotAt, 27.55, 0.01)
				near("golem_slot_is_golem_in_end", Poses.GolemSlotAt, slotSeen, 0.02)
				eq("rise_starts_at_0", Poses.RiseAt(0), 0)
				eq("rise_ends_at_1", Poses.RiseAt(Event.RiseSeconds), 1)
			end)
		end

		if BossDodge then
			section("dodge_timeline", function()
				eq("events_of_exists", type(BossDodge.EventsOf), "function")
				local moments = momentsOf(BossDodge, MAGE)
				local ordered, names, last = true, {}, 0
				local onPose = true
				local minBar = math.huge
				for _, row in moments do
					ordered = ordered and type(row.At) == "number" and row.At > last
					names[tostring(row.Name)] = true
					minBar = math.min(minBar, (row.At or 0) - last)
					if Poses and type(row.At) == "number" then
						local move, localTime = Poses.Schedule(0, Event.IntroSeconds + row.At + 0.001)
						local want = MOVE_EVENTS[move]
						onPose = onPose and want ~= nil and want[1] == row.Name and approx(localTime, want[2], 0.01)
					end
					last = row.At or last
				end
				flag("mage_moments_in_order", ordered)
				for _, name in { "Lightning", "Barrage" } do
					flag("mage_moments_have_" .. string.lower(name), names[name] == true)
				end
				local stray = {}
				for name in names do
					if not COST[name] then
						table.insert(stray, name)
					end
				end
				eq("mage_moments_only_her_events", table.concat(stray, ","), "")
				flag("mage_moments_on_pose_events", onPose)
				-- Room for the Dodge bar's 1.5 s and its 0.3 s pop before each bar moment.
				flag("gap_before_bar_moment", minBar >= 1.5 + 0.3, minBar, 1.8)
				local back = true
				for _, row in moments do
					back = back and BossDodge.IndexAtOrBefore(row.At + 0.01, MAGE) == row.Index
				end
				flag("index_at_or_before_mage", back)
				local raga = true
				for i = 1, 10 do
					local a1, n1 = BossDodge.Moment(i)
					local a2, n2 = BossDodge.Moment(i, RAGA)
					raga = raga and a1 == a2 and n1 == n2
				end
				flag("raga_moments_unchanged", raga)
				flag("raga_events_table_kept", rawequal(BossDodge.EventsOf(RAGA), BossDodge.Events))
				eq("hit_text_lightning", BossDodge.HitText.Lightning, "You were struck by her lightning")
				eq("hit_text_barrage", BossDodge.HitText.Barrage, "You were blasted by her barrage")
				eq("hit_text_slam", BossDodge.HitText.Slam, "The golem crushed you")
				eq("hit_text_sweep", BossDodge.HitText.Sweep, "The golem swept you")
				-- The golem's clock (plan A4).
				eq("slot_is_function", type(BossDodge.Slot), "function")
				eq("minion_moment_is_function", type(BossDodge.MinionMoment), "function")
				eq("minion_index_is_function", type(BossDodge.MinionIndexAtOrBefore), "function")
				if type(BossDodge.Slot) == "function" then
					local slot, cycle = BossDodge.Slot(MAGE)
					near("slot_matches_poses", slot, Poses and Poses.GolemSlotAt)
					near("slot_cycle_matches_poses", cycle, Poses and Poses.CycleSeconds)
					eq("slot_none_for_raga", BossDodge.Slot(RAGA), nil)
					eq("slot_none_for_default", BossDodge.Slot(nil), nil)
				end
				if type(BossDodge.MinionMoment) == "function" then
					local same = true
					for k = 1, 8 do
						local tau, name = BossDodge.MinionMoment(k, MAGE)
						same = same and approx(tau, golemTau(k)) and name == golemName(k)
					end
					flag("minion_moments_every_6_alternating", same)
				end
				if type(BossDodge.MinionIndexAtOrBefore) == "function" then
					for _, case in { { 0, 0 }, { 4.19, 0 }, { 4.2, 1 }, { 10.19, 1 }, { 10.21, 2 }, { 60, 10 } } do
						eq("minion_index_at_" .. case[1], BossDodge.MinionIndexAtOrBefore(case[1], MAGE), case[2])
					end
				end
			end)
		end

		if Osu then
			section("osu", function()
				eq("osu_count_3", Osu.Count, 3)
				eq("osu_approach_1_5", Osu.ApproachSeconds, 1.5)
				eq("osu_tolerance_0_35", Osu.Tolerance, 0.35)
				eq("osu_diameter_0_145", Osu.Diameter, 0.145)
				eq("osu_diameter_phone_0_19", Osu.DiameterPhone, 0.19)
				near("osu_open_seconds_4_2", Osu.OpenSeconds, 4.2)
				local bad = {}
				local function note(label, ok)
					if not ok and #bad < 10 then
						table.insert(bad, label)
					end
				end
				local maxLead = 0
				for seed = 1, 500 do
					local user, start, index = 1000 + seed * 7, 1e6 + seed * 13.25, seed % 20 + 1
					local rows = Osu.Circles(user, start, index)
					local tag = "seed_" .. seed
					note(tag .. "_count", #rows == 3)
					for k, row in rows do
						note(tag .. "_x_" .. k, row.X >= 0.295 and row.X <= 0.705)
						note(tag .. "_y_" .. k, row.Y >= 0.295 and row.Y <= 0.705)
						-- Every beat inside the 3 s before the golem's attack (owner 2026-11-12).
						note(tag .. "_beat_in_window_" .. k, row.Lead > 0 and row.Lead <= 3.0)
						-- Attack 1's circles all show at or after the golem's start (its hit is GOLEM_FIRST after it).
						if index == 1 then
							note(
								tag .. "_first_attack_after_start_" .. k,
								GOLEM_FIRST - row.Lead - Osu.ApproachSeconds >= -1e-9
							)
						end
						maxLead = math.max(maxLead, row.Lead)
						if k > 1 then
							note(tag .. "_lead_order_" .. k, rows[k - 1].Lead > row.Lead)
							-- 0.9 s apart (owner 2026-11-12): more than 2 x Tolerance, so one stamp never fits two circles.
							note(tag .. "_gap_" .. k, rows[k - 1].Lead - row.Lead >= 0.70 - 1e-9)
						end
						-- At least one phone diameter apart, in screen heights, on a 16:9 and a 4:3 screen.
						for j = 1, k - 1 do
							local other = rows[j]
							for _, aspect in { 16 / 9, 4 / 3 } do
								local d = math.sqrt(((row.X - other.X) * aspect) ^ 2 + (row.Y - other.Y) ^ 2)
								note(tag .. "_apart_" .. j .. "_" .. k .. "_" .. aspect, d >= 0.19 - 1e-9)
							end
						end
					end
					-- The last click stays 0.35 s before the attack: the Dodge bar's server margin (slack 0.03).
					local lastLead = rows[#rows] and rows[#rows].Lead or 0
					note(tag .. "_last_lead", lastLead - Osu.Tolerance - 0.03 >= 0.35 - 1e-9)
					local again = Osu.Circles(user, start, index)
					note(tag .. "_deterministic", H.same(rows, again))
				end
				flag("osu_circles_all_seeds", #bad == 0, table.concat(bad, ","))
				flag("osu_open_covers_first_circle", maxLead + Osu.ApproachSeconds <= Osu.OpenSeconds + 1e-9, maxLead)
				flag("osu_differs_by_index", not H.same(Osu.Circles(5, 1e6, 1), Osu.Circles(5, 1e6, 2)))
				flag("osu_differs_by_user", not H.same(Osu.Circles(5, 1e6, 1), Osu.Circles(6, 1e6, 1)))
				flag("osu_differs_by_golem", not H.same(Osu.Circles(5, 1e6, 1), Osu.Circles(5, 1e6 + 40, 1)))
				eq("osu_judge_on_beat", Osu.Judge(1, 10, 9, 0), true)
				eq("osu_judge_inside_tolerance", Osu.Judge(1, 10, 9.34, 0), true)
				eq("osu_judge_early_inside", Osu.Judge(1, 10, 8.66, 0), true)
				eq("osu_judge_outside_tolerance", Osu.Judge(1, 10, 9.36, 0), false)
				eq("osu_judge_early_outside", Osu.Judge(1, 10, 8.64, 0), false)
				eq("osu_judge_slack_widens", Osu.Judge(1, 10, 9.36, 0.03), true)
			end)
		end

		if Catalog then
			section("catalog", function()
				eq("catalog_default_raga", Catalog.Default, RAGA)
				flag("catalog_order", H.same(Catalog.Order, { RAGA, MAGE, "boss_king" }))
				local mage, raga = Catalog.Get(MAGE), Catalog.Get(RAGA)
				flag("catalog_get_nil_is_raga", rawequal(Catalog.Get(nil), raga))
				flag("catalog_get_unknown_is_raga", rawequal(Catalog.Get("boss_nobody"), raga))
				local fields = {
					"Id",
					"Name",
					"Poses",
					"Stages",
					"Moves",
					"Statuses",
					"ChatMessage",
					"WarningText",
					"InviteTitle",
					"InviteHint",
					"DefeatedTitle",
					"Portrait",
					"ModelName",
					"TargetPart",
					"Camera",
					"Chests",
					"Relics",
				}
				for _, row in { mage, raga } do
					for _, field in fields do
						flag(("catalog_%s_has_%s"):format(row.Id, field), row[field] ~= nil)
					end
				end
				eq("mage_id", mage.Id, MAGE)
				eq("mage_name", mage.Name, "The Elf Mage")
				eq("mage_poses", mage.Poses, "BossMagePoses")
				eq("mage_stages_1", mage.Stages, 1)
				eq("mage_lightning_cost", mage.Moves.Lightning and mage.Moves.Lightning.Cost, 20)
				eq("mage_barrage_cost", mage.Moves.Barrage and mage.Moves.Barrage.Cost, 30)
				eq("mage_no_slam_move", mage.Moves.Slam, nil) -- the golem's now (owner 2026-11-11)
				local status = mage.Statuses[1] or {}
				eq("mage_one_status", #mage.Statuses, 1)
				eq("mage_status_crushed", status.Id, "Crushed")
				eq("mage_status_minion", status.Minion, true)
				eq("mage_status_no_event", status.Event, nil)
				-- The Stone Golem miniboss (plan A1; HP, chat and captions proposed).
				local minion = mage.Minion or {}
				local attacks = minion.Attacks or {}
				local caption = minion.Caption or {}
				eq("mage_minion_id", minion.Id, "boss_golem")
				eq("mage_minion_name", minion.Name, "Stone Golem")
				eq("mage_minion_hp_per_player", minion.HpPerPlayer, GOLEM_HP)
				eq("mage_minion_no_flat_hp", minion.Hp, nil)
				for name, text in GOLEM_CHAT do
					local tag = string.lower(name)
					eq("mage_minion_" .. tag .. "_cost", attacks[name] and attacks[name].Cost, GOLEM_COST)
					eq("mage_minion_" .. tag .. "_chat", attacks[name] and attacks[name].Chat, text)
				end
				eq("mage_minion_caption_slam", caption.Slam, "Golem Slam! Hit every circle!")
				eq("mage_minion_caption_sweep", caption.Sweep, "Golem Sweep! Hit every circle!")
				flag("mage_chests", H.same(mage.Chests, { "relic_chest_mage" }))
				eq("mage_relics", mage.Relics, "boss_mage")
				flag("raga_chests", H.same(raga.Chests, { "relic_chest_raga", "relic_chest_adapted" }))
				eq("raga_relics", raga.Relics, "big_raga")
				eq("raga_no_minion", raga.Minion, nil)
				near("mage_status_cut_0_2", status.Cut, CRUSHED_CUT)
				eq("mage_chat", mage.ChatMessage, CHAT)
				eq("mage_warning", mage.WarningText, "The Elf Mage has awakened, take her down!!!")
				-- ActiveText (the old popup line) may go with the Bosses cards (plan A1); kept, it keeps its text.
				if mage.ActiveText ~= nil then
					eq("mage_active", mage.ActiveText, "The Elf Mage is casting right now")
				end
				eq("mage_invite_title", mage.InviteTitle, "THE ELF MAGE EVENT")
				eq("mage_invite_hint", mage.InviteHint, "Teleport to fight The Elf Mage before the timer ends")
				eq("mage_defeated_title", mage.DefeatedTitle, "The Elf Mage Defeated!")
				eq("mage_model_name", mage.ModelName, "ElfMage")
				eq("mage_target_part", mage.TargetPart, "Torso")
				eq("mage_portrait", mage.Portrait, Art and Art.Portrait)
				eq("mage_dodge_icon", mage.DodgeIcon, Art and Art.StaffIcon)
				eq("raga_name", raga.Name, "Big Raga")
				eq("raga_poses", raga.Poses, "BossRagaPoses")
				eq("raga_stages_2", raga.Stages, 2)
				eq("raga_impact_stage_cost", raga.Moves.Impact and raga.Moves.Impact.StageCost, true)
				eq("raga_chat", raga.ChatMessage, Event.ChatMessage)
				eq("raga_model_name", raga.ModelName, "BigRaga")
				eq("raga_target_part", raga.TargetPart, "UpperTorso")
				eq("raga_dodge_icon_none", raga.DodgeIcon, nil)
				eq("raga_wait_camera_none", raga.WaitCamera, nil)
				eq("raga_defeated_title", raga.DefeatedTitle, "Raga Defeated!")
				if raga.ActiveText ~= nil then
					eq("raga_active", raga.ActiveText, "Big Raga is raging right now")
				end
				eq("raga_portrait", raga.Portrait, require(Shared.SidekickArt).side_raga.Portrait)
				local cam = raga.Camera or {}
				flag("raga_camera_kept", cam.Yaw == 75 and cam.Pitch == 26 and cam.Zoom == 40)
				local ids = {}
				for _, row in raga.Statuses do
					ids[row.Id] = row.Cut
				end
				eq("raga_shouted_cut", ids.Shouted, Event.ShoutDamageCut)
				eq("raga_adapted_cut", ids.Adapted, Event.AdaptedCut)
				-- Section 5 safeguard: only the tweaked names reach players.
				local leaks = {}
				for _, row in { mage, raga } do
					for _, text in stringsIn(row, {}) do
						if realNameIn(text) then
							table.insert(leaks, row.Id)
						end
					end
				end
				eq("catalog_no_real_names", table.concat(leaks, ","), "")
				-- Current reads the attribute; restored before any yield.
				local was = ReplicatedStorage:GetAttribute("BossEventBoss")
				local okSet, current = pcall(function()
					ReplicatedStorage:SetAttribute("BossEventBoss", MAGE)
					local row = Catalog.Current()
					ReplicatedStorage:SetAttribute("BossEventBoss", nil)
					return { row, Catalog.Current() }
				end)
				ReplicatedStorage:SetAttribute("BossEventBoss", was)
				flag("catalog_current_ran", okSet)
				flag("catalog_current_mage", okSet and rawequal(current[1], mage))
				flag("catalog_current_nil_is_raga", okSet and rawequal(current[2], raga))
			end)
		end

		return r
	end

	return { boss_mage_event = boss_mage_event, boss_mage_arena = boss_mage_arena, boss_mage_anim = boss_mage_anim }
end

return Tests
