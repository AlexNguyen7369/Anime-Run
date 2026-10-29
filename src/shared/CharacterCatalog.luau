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

local specs = {} -- Id -> spec
for _, module in Characters:GetChildren() do
	if module:IsA("ModuleScript") then
		local spec = require(module)
		spec.Id = spec.Id or module.Name
		spec.Rollable = true
		assert(spec.Id ~= CharacterCatalog.STARTER_ID, "character id 'starter' is reserved")
		assert(specs[spec.Id] == nil, "duplicate character id " .. spec.Id)
		specs[spec.Id] = spec
	end
end

local byOrder = {}
local rarestFirst = {}
for _, spec in specs do
	table.insert(byOrder, spec)
	table.insert(rarestFirst, spec)
end
table.sort(byOrder, function(a, b)
	return a.Order < b.Order
end)
-- Largest "1 in N" first; the catch-all (Chance = nil) last
table.sort(rarestFirst, function(a, b)
	return (a.Chance or 0) > (b.Chance or 0)
end)

-- The spec for an Id (the starter included), or nil.
function CharacterCatalog.Get(id)
	if id == CharacterCatalog.STARTER_ID then
		return STARTER
	end
	return specs[id]
end

-- Every index character (the starter excluded), in index Order. Do not modify the returned table.
function CharacterCatalog.All()
	return byOrder
end

-- Every rollable character, rarest first, the catch-all last. Do not modify the returned table.
function CharacterCatalog.Rollable()
	return rarestFirst
end

-- Kept for the old car API: there are no gamepass characters, so always empty.
local NO_PASSES = {}
function CharacterCatalog.Passes()
	return NO_PASSES
end

return CharacterCatalog
