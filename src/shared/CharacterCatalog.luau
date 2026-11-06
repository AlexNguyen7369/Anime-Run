--!nonstrict
-- The character catalog (docs/CHARACTER_GACHA_SPEC.md): auto-loads every ModuleScript in Shared/Characters, so adding
-- a character is just adding a file. Ids are permanent save keys, never list positions. The starter is built in
-- here: every player has it, it can not be rolled and it is not in the index.

local Characters = script.Parent:WaitForChild("Characters")

local CharacterCatalog = {}

CharacterCatalog.STARTER_ID = "starter"

local STARTER = {
	Id = CharacterCatalog.STARTER_ID,
	Name = "Starter",
	Rarity = "Common",
	Chance = nil,
	SpeedMulti = 1,
	Order = 0,
	Category = "Balanced",
	Model = nil,
	Rollable = false,
}

-- Admin-only test runner (owner 2026-11-01, docs/GAME_DESIGN_REQUIREMENTS.md 4.13): granted for the session by /kami,
-- never saved, never rolled, not in the index. Its AdminSpeed is used as-is.
CharacterCatalog.KAMI_ID = "kami"
local KAMI = {
	Id = CharacterCatalog.KAMI_ID,
	Name = "Kami",
	Rarity = "Secret",
	Chance = nil,
	SpeedMulti = 1,
	AdminSpeed = 7e31, -- runs at RaceConfig.MAX_CRUISE: the curve's 800 anchor, raise it with the cap (owner 2026-11-01)
	Order = 0,
	Category = "Balanced",
	Model = nil,
	Rollable = false,
}

-- Starter choice (design doc 4.21): picked once in a popup, then owned like a rolled character. Never rolled, not in
-- the Index. Model = whose uploaded model they wear. Stats proposed.
CharacterCatalog.STARTER_PICKS = { "starter_sea", "starter_leaf", "starter_db" }
local PICKS = {}
for id, row in
	{
		starter_sea = { "Ruffy", "sea_captain" },
		starter_leaf = { "Karate Kid", "leaf_hero", "NinjaRun" },
		starter_db = { "Sayan", "db_hero" },
	}
do
	PICKS[id] = {
		Id = id,
		Name = row[1],
		Rarity = "Common",
		Chance = nil,
		SpeedMulti = 1,
		Order = 0,
		Category = "Balanced",
		Model = row[2],
		RunStyle = row[3],
		Rollable = false,
	}
end

local specs = {} -- Id -> spec
for _, module in Characters:GetChildren() do
	if module:IsA("ModuleScript") then
		local spec = require(module)
		spec.Id = spec.Id or module.Name
		spec.Rollable = true
		assert(spec.Id ~= CharacterCatalog.STARTER_ID, "character id 'starter' is reserved")
		assert(spec.Id ~= CharacterCatalog.KAMI_ID, "character id 'kami' is reserved")
		assert(PICKS[spec.Id] == nil, "character id " .. spec.Id .. " is a reserved starter")
		assert(specs[spec.Id] == nil, "duplicate character id " .. spec.Id)
		specs[spec.Id] = spec
	end
end

local byOrder = {}
local rarestFirst = {}
for _, spec in specs do
	table.insert(byOrder, spec)
	if not spec.Event then -- event-only characters stay in the Index but are not rolled (owner 2026-11-03)
		table.insert(rarestFirst, spec)
	end
end
table.sort(byOrder, function(a, b)
	return a.Order < b.Order
end)
-- Largest "1 in N" first; the catch-all (Chance = 1) last
table.sort(rarestFirst, function(a, b)
	return (a.Chance or 0) > (b.Chance or 0)
end)

-- The spec for an Id (the starter and Kami included), or nil.
function CharacterCatalog.Get(id)
	if id == CharacterCatalog.STARTER_ID then
		return STARTER
	end
	if id == CharacterCatalog.KAMI_ID then
		return KAMI
	end
	return PICKS[id] or specs[id]
end

-- Every index character (the starter excluded), in index Order. Do not modify the returned table.
function CharacterCatalog.All()
	return byOrder
end

-- Every character a roll can give, rarest first, the catch-all last. Do not modify the returned table.
function CharacterCatalog.Rollable()
	return rarestFirst
end

-- Kept for the old car API: there are no gamepass characters, so always empty.
local NO_PASSES = {}
function CharacterCatalog.Passes()
	return NO_PASSES
end

return CharacterCatalog
