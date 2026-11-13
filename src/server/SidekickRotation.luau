--!nonstrict
-- The 30 minute summon rotation (design doc 4.36, docs/SIDEKICK_SPEC.md "Rotation"): computed from the UTC slot alone, so every
-- server agrees with no store. Server only, so a client learns the current slot's Secret and never a future one. Clients read
-- only the ReplicatedStorage attribute SidekickRotation (Public). SidekickArt is read at call time: no Model, out of the tier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.SidekickConfig)
local Art = require(ReplicatedStorage.Shared.SidekickArt)

local Rotation = {}
Rotation.SLOT_SECONDS = 1800

local SECRET_SALT = 0x2F6B91D7 -- never replicated: the Secret's seed cannot be rebuilt from the slot
local SEED_STEP = 1000003 -- spreads neighbouring slots across the seed range
local DRAWN = { { "Mythic", 1 }, { "Legendary", 2 }, { "Rare", 2 } }

local function idsOf(rarity, needsModel)
	local ids = {}
	for _, row in Config.List do
		if row.Rarity == rarity and (not needsModel or (Art[row.Id] and Art[row.Id].Model)) then
			table.insert(ids, row.Id)
		end
	end
	return ids
end

function Rotation.Slot(utc)
	return math.floor(utc / Rotation.SLOT_SECONDS)
end

-- { Mythic, Legendary, Rare, Common = id arrays, Secret = id }. Holds the whole rotation of any slot: only Public goes to clients.
function Rotation.For(slot)
	local rng = Random.new(slot * SEED_STEP)
	local rotation = { Common = idsOf("Common") }
	for _, tier in DRAWN do
		local pool, drawn = idsOf(tier[1], true), {}
		for _ = 1, math.min(tier[2], #pool) do
			table.insert(drawn, table.remove(pool, rng:NextInteger(1, #pool)))
		end
		rotation[tier[1]] = drawn
	end
	local featured = Config.Get(Config.FeaturedMythic)
	if featured and featured.Rarity == "Mythic" and Art[featured.Id] and Art[featured.Id].Model then
		rotation.Mythic = { featured.Id }
	end
	local secrets = idsOf("Secret")
	rotation.Secret = secrets[Random.new(slot * SEED_STEP + SECRET_SALT):NextInteger(1, #secrets)]
	return rotation
end

local function publicIds(rotation)
	local ids = {}
	for _, tier in { "Mythic", "Legendary", "Rare", "Common" } do
		table.move(rotation[tier], 1, #rotation[tier], #ids + 1, ids)
	end
	return ids
end

-- id -> percent, in-rotation ids only: listed odds, with what the rest leaves split evenly across Commons. Sums to 100.
function Rotation.Odds(slot)
	local rotation = Rotation.For(slot)
	local odds, rest = {}, 100
	local ids = publicIds(rotation)
	table.insert(ids, rotation.Secret)
	for _, id in ids do
		odds[id] = Config.Get(id).Odds
		rest -= odds[id]
	end
	for _, id in rotation.Common do
		odds[id] += rest / #rotation.Common
	end
	return odds
end

-- All a client may see. SecretChoices is the same every slot; SecretId is this slot's Secret, for the Details silhouette (owner 2026-11-05).
-- Odds holds this slot's ids only, so it reveals no more than Ids and SecretId.
function Rotation.Public(slot)
	local choices = {}
	for _, row in Config.List do
		if row.Rarity == "Secret" then
			table.insert(choices, { Name = row.Name, Odds = row.Odds })
		end
	end
	local rotation = Rotation.For(slot)
	return {
		Ids = publicIds(rotation),
		SecretChoices = choices,
		SecretId = rotation.Secret,
		Odds = Rotation.Odds(slot),
		EndsAt = (slot + 1) * Rotation.SLOT_SECONDS,
	}
end

return Rotation
