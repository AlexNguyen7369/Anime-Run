--!nonstrict
-- Per-world progress in the one shared save (design doc 4.46, docs/WORLD2_SPEC.md "Save"). Money, Gems, Rebirth, the
-- Index and everything else stay shared; only WorldConfig.PROGRESS_KEYS are per world. World 1 keeps them at the top
-- level (unchanged layout); world n keeps them in record.Worlds["W<n>"]. Pure: inputs are never changed.
local WorldConfig = require(script.Parent.WorldConfig)

local WorldSave = {}

-- The record as world `id`'s services read it: the progress keys swapped for that world's (absent = a fresh world).
function WorldSave.View(record, id)
	local key = WorldConfig.SaveKey(id)
	if not key or type(record) ~= "table" then
		return record
	end
	local view = table.clone(record)
	local worlds = type(record.Worlds) == "table" and record.Worlds or {}
	local mine = type(worlds[key]) == "table" and worlds[key] or {}
	for _, name in WorldConfig.PROGRESS_KEYS do
		view[name] = mine[name]
	end
	return view
end

-- The payload world `id` writes: its progress keys moved into Worlds[key] next to the stored record's other worlds, so
-- World 1's top-level progress is never overwritten from World 2.
function WorldSave.Fold(payload, current, id)
	local key = WorldConfig.SaveKey(id)
	if not key then
		return payload
	end
	local out = table.clone(payload)
	local worlds = type(current) == "table" and type(current.Worlds) == "table" and table.clone(current.Worlds) or {}
	local mine = {}
	for _, name in WorldConfig.PROGRESS_KEYS do
		mine[name] = out[name]
		out[name] = nil
	end
	worlds[key] = mine
	out.Worlds = worlds
	return out
end

return WorldSave
