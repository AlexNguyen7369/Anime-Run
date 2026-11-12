--!nonstrict
-- The bosses one event can be (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md). Pure data. ReplicatedStorage attribute
-- BossEventBoss names the running one; nil reads as Big Raga. Pose modules are named, not required: BossEventConfig,
-- BossArenaConfig and the pose modules must not require this one (they would cycle).
local BossKingArt = require(script.Parent.BossKingArt)
local BossMageArt = require(script.Parent.BossMageArt)
local Cfg = require(script.Parent.BossEventConfig)
local SidekickArt = require(script.Parent.SidekickArt)

local BossCatalog = {}

BossCatalog.Default = "boss_raga"
BossCatalog.Order = { "boss_raga", "boss_mage", "boss_king" } -- the random pick's pool

local ROWS = {
	boss_raga = {
		Id = "boss_raga",
		Name = "Big Raga",
		Poses = "BossRagaPoses",
		Stages = 2,
		Moves = { Impact = { StageCost = true }, Roar = {}, WheelClick = {} },
		Statuses = {
			{ Id = "Shouted", Event = "Roar", Cut = Cfg.ShoutDamageCut },
			{ Id = "Adapted", Event = "WheelClick", Cut = Cfg.AdaptedCut },
		},
		Chests = { "relic_chest_raga", "relic_chest_adapted" }, -- by stage
		Relics = "big_raga", -- RelicConfig.Bosses key
		ChatMessage = Cfg.ChatMessage,
		WarningText = "Big Raga has emerged, take him down!!!",
		ActiveText = "Big Raga is raging right now",
		InviteTitle = "BIG RAGA EVENT",
		InviteHint = "Teleport to fight Big Raga before the timer ends",
		DefeatedTitle = "Raga Defeated!",
		Portrait = SidekickArt.side_raga.Portrait,
		DodgeIcon = nil, -- the UI falls back to RelicConfig.WheelArt
		ModelName = "BigRaga",
		TargetPart = "UpperTorso",
		Camera = { Yaw = 75, Pitch = 26, Zoom = 40 },
		WaitCamera = nil, -- BossEventConfig's own
	},
	boss_mage = {
		Id = "boss_mage",
		Name = "The Elf Mage",
		Poses = "BossMagePoses",
		Stages = 1, -- owner 2026-11-11: her defeat starts no Phase 2
		-- Costs owner 2026-11-11; chat lines proposed.
		Moves = {
			Lightning = { Cost = 20, Chat = "The Elf Mage calls lightning! -20% stamina" },
			Barrage = { Cost = 30, Chat = "The Elf Mage fires a barrage! -30% stamina" },
		},
		Statuses = { { Id = "Crushed", Minion = true, Cut = 0.20 } }, -- owner 2026-11-11; stacks from golem hits
		-- The Stone Golem miniboss (owner 2026-11-11), replacing her golem move. Chat lines proposed.
		Minion = {
			Id = "boss_golem",
			Name = "Stone Golem",
			HpPerPlayer = 1000, -- owner 2026-11-12; x players in the arena when it rises
			Attacks = { -- event names from BossMagePoses.GolemHit
				Slam = { Cost = 15, Chat = "The Elf Mage's golem slams! -15% stamina, damage down for 15 s" },
				Sweep = { Cost = 15, Chat = "The Stone Golem sweeps! -15% stamina, damage down for 15 s" },
			},
			Caption = { Slam = "Golem Slam! Hit every circle!", Sweep = "Golem Sweep! Hit every circle!" },
		},
		Chests = { "relic_chest_mage" }, -- by stage
		Relics = "boss_mage", -- RelicConfig.Bosses key
		ChatMessage = "THE ELF MAGE HAS AWAKENED, TAKE HER DOWN FOR REWARDS", -- proposed
		WarningText = "The Elf Mage has awakened, take her down!!!", -- proposed
		ActiveText = "The Elf Mage is casting right now", -- proposed
		InviteTitle = "THE ELF MAGE EVENT", -- proposed
		InviteHint = "Teleport to fight The Elf Mage before the timer ends", -- proposed
		DefeatedTitle = "The Elf Mage Defeated!", -- proposed
		Portrait = BossMageArt.Portrait,
		DodgeIcon = BossMageArt.StaffIcon,
		ModelName = "ElfMage",
		TargetPart = "Torso",
		Camera = { Yaw = 75, Pitch = 14, Zoom = 40 }, -- proposed: pitch 14 for a 44-stud boss
		-- proposed: inside the wall, under its 70 studs. Down 22 (was 32, Studio verify 2026-11-11): at 32 her top sat behind the HP
		-- bar from every lane; at 22 her top is >= 20 px under it and the runner above the Team row at 1271 x 601.
		WaitCamera = { Out = 28, Up = 40, Down = 22 },
	},
	-- The Golden King (design doc 4.37 "Third boss", BOSS_EVENT_SPEC "The Golden King"). Costs owner 2026-11-11; texts proposed
	-- except the two move chat lines and "Enuma Elish tore through you". Cost is a percent of a full bar, as the mage's.
	boss_king = {
		Id = "boss_king",
		Name = "The Golden King",
		Poses = "BossKingPoses",
		Stages = 1, -- his defeat starts no Phase 2
		-- A move with Cost 0 has no Dodge bar, charges nothing and never sets Vulnerable (BossEventService). HitText: the hit header.
		Moves = {
			gates = {
				Cost = 20,
				Chat = "The Golden King opens his vault! -20% stamina",
				HitText = "The King's treasures struck you",
			},
			enuma = {
				Cost = 40,
				Chat = "The Golden King unleashes Enuma Elish! -40% stamina",
				HitText = "Enuma Elish tore through you",
			},
			shields = {
				Cost = 0,
				Chat = "The Golden King raises his shields! He takes 40% less damage until his next move",
			},
		},
		-- Self: on the boss, not a player. Held from its Event's moment to the next moment of the schedule (the next move's start).
		Statuses = { { Id = "Fortified", Self = true, Event = "shields", Cut = 0.4 } },
		FortifiedText = "The Golden King has fortified his defenses", -- the red header when BossFortified turns true
		Chests = { "relic_chest_king" }, -- by stage
		Relics = "boss_king", -- RelicConfig.Bosses key
		ChatMessage = "THE GOLDEN KING HAS ARRIVED, TAKE HIM DOWN FOR REWARDS",
		WarningText = "The Golden King has arrived, take him down!!!",
		ActiveText = "The Golden King is judging you right now",
		InviteTitle = "THE GOLDEN KING EVENT",
		InviteHint = "Teleport to fight The Golden King before the timer ends",
		DefeatedTitle = "The Golden King Defeated!",
		Portrait = BossKingArt.Portrait,
		DodgeIcon = BossKingArt.KeyIcon,
		ModelName = "GoldenKing",
		TargetPart = "Torso",
		Camera = { Yaw = 75, Pitch = 14, Zoom = 40 }, -- the mage's; he stands lower than her hover, checked in Studio (k8)
		WaitCamera = { Out = 28, Up = 40, Down = 22 }, -- the mage's
	},
}

-- nil or an unknown id: Big Raga's row.
function BossCatalog.Get(id)
	return ROWS[id] or ROWS[BossCatalog.Default]
end

function BossCatalog.Current()
	return BossCatalog.Get(game:GetService("ReplicatedStorage"):GetAttribute("BossEventBoss"))
end

return BossCatalog
