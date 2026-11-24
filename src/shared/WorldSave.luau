--!nonstrict
-- Per-world progress in the one shared save (design doc 4.47, docs/WORLD2_SPEC.md "Save"). Money, Gems, Rebirth, the
-- Index and everything else stay shared; only WorldConfig.PROGRESS_KEYS are per world. World 1 keeps them at the top
-- level (unchanged layout); world n keeps them in record.Worlds["W<n>"]. Pure: inputs are never changed.
local WorldConfig = require(script.Parent.WorldConfig)

local WorldSave = {}

-- The per-world keys: WorldConfig's, plus Awakening (World 2's stars, docs/WORLD2_SPEC.md "Awakening"), design doc
-- 4.47; never at the top level.
local KEYS = table.clone(WorldConfig.PROGRESS_KEYS)
table.insert(KEYS, "Awakening")

-- One-way flags of world n, kept in Worlds["W<n>"] next to its progress: once true they stay true (a payload without
-- the flag never clears it). Welcomed: the first-arrival welcome was given (Server/WorldWelcome, docs/WORLD2_SPEC.md).
WorldSave.FLAG_KEYS = { "Welcomed" }

-- The id GachaService gives an empty team (CharacterCatalog.STARTER_ID; not required here, this module stays pure).
WorldSave.PLACEHOLDER = "starter"

-- True when a saved team names nobody: absent, empty, or only the placeholder (an old save has just Equipped).
local function noTeam(team, equipped)
	if type(team) == "table" and #team > 0 then
		return #team == 1 and team[1] == WorldSave.PLACEHOLDER
	end
	return type(equipped) ~= "string" or equipped == "" or equipped == WorldSave.PLACEHOLDER
end

-- The record as world `id`'s services read it: the progress keys swapped for that world's (absent = a fresh world).
function WorldSave.View(record, id)
	local key = WorldConfig.SaveKey(id)
	if not key or type(record) ~= "table" then
		return record
	end
	local view = table.clone(record)
	local worlds = type(record.Worlds) == "table" and record.Worlds or {}
	local mine = type(worlds[key]) == "table" and worlds[key] or {}
	for _, name in KEYS do
		view[name] = mine[name]
	end
	-- First entry keeps the team (design doc 4.47, owner 2026-11-24): this world has no team yet, so the top-level one
	-- (World 1's) is read; the first save here writes it to this world's keys.
	if noTeam(mine.Team, mine.Equipped) and not noTeam(record.Team, record.Equipped) then
		view.Team, view.Equipped = record.Team, record.Equipped
	end
	for _, name in WorldSave.FLAG_KEYS do
		view[name] = mine[name] == true or nil
	end
	return view
end

-- The payload world `id` writes: its progress keys moved into Worlds[key] next to the stored record's other worlds, so
-- World 1's top-level progress is never overwritten from World 2. Keys of Worlds[key] this version does not know are
-- kept, as PlayerData keeps unknown top-level keys.
function WorldSave.Fold(payload, current, id)
	local key = WorldConfig.SaveKey(id)
	if not key then
		return payload
	end
	local out = table.clone(payload)
	local worlds = type(current) == "table" and type(current.Worlds) == "table" and table.clone(current.Worlds) or {}
	local mine = type(worlds[key]) == "table" and table.clone(worlds[key]) or {}
	for _, name in KEYS do
		mine[name] = out[name]
		out[name] = nil
	end
	for _, name in WorldSave.FLAG_KEYS do
		mine[name] = (out[name] == true or mine[name] == true) or nil
		out[name] = nil
	end
	worlds[key] = mine
	out.Worlds = worlds
	return out
end

return WorldSave
