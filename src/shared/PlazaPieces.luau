--!nonstrict
-- The spawn pieces (WORLD_REDESIGN_SPEC 4.2): which mesh stands where, by world and state. Every row of PlazaPieceAssets with Asset 0
-- is not uploaded yet, and the plaza keeps today's mesh or stand-in there; the upload only fills the ids. Read by Shared/SpawnArea
-- (stand-ins, collision), Server/PlazaDressing (meshes, signs), Server/PlazaAccents, Server/PlazaMerchantRigs and the clients.
-- Sizes are the drafts', **proposed**. Frames: a service's -Z is its front (SpawnArea), so a draft's (x, y, z) is (-x, z, y) here.
local BossGateConfig = require(script.Parent.BossGateConfig)
local WorldConfig = require(script.Parent.WorldConfig)

local PlazaPieces = {}

PlazaPieces.Assets = require(script.Parent.PlazaPieceAssets)
local TODAYS_MODEL_SIZE = 7 -- studs, the turning Mythic's largest extent in today's altar
-- The merchants' switch, off until the lead turns it on: cast, poses and rulings are in (owner 2026-11-25: Frierin may load in World 1,
-- Kakashe is the smaller one). The Sensei dummy stays while off.
PlazaPieces.MERCHANTS_LIVE = false
PlazaPieces.ALTAR_TAGS = { Locked = "PlazaAltarLocked", Unlocked = "PlazaAltarUnlocked" } -- Shared/PlazaPieceLook, per player

-- The locked Mythic's silhouette. Today's altar: placeholder. Per new altar (below): the colours are the owner's (2026-11-25); opaque is
-- **proposed** (WORLD_REDESIGN_SPEC 4.2).
local TODAYS_LOCKED = { Color = Color3.fromRGB(24, 22, 30), Transparency = 0.25 } -- placeholders
-- Per world: the altar's look, what its model stands on over the floor (studs, and studs ahead of the centre), its lock label's
-- spot (altar frame) and the height of its floating header (over the crest, owner 2026-11-25)
local ALTARS = {
	{
		Look = "GreatLotus",
		ModelSize = 17.5, -- owner 2026-11-25
		Stand = 10.3,
		Ahead = 0,
		Lock = Vector3.new(0, 8.9, -13.4),
		Locked = { Color = Color3.fromRGB(74, 66, 92), Transparency = 0 },
		HeaderY = 66,
	},
	{
		Look = "TwinRoof",
		ModelSize = 25, -- owner 2026-11-25
		Stand = 8.55,
		Ahead = 0.8,
		Lock = Vector3.new(0, 8, -17.2),
		Locked = { Color = Color3.fromRGB(132, 120, 152), Transparency = 0 },
		HeaderY = 80,
	},
}

-- Meshes of today's that a piece of the same key stands in for; the Market's sign board is in its new mesh
local SAME_KEY = { "SHOPStall", "POTIONSStall", "MarketStall", "IndexBoard", "SkyLoop" }
-- Flat signs on the new boards: piece -> { sign text, studs ahead of the piece's origin, height over the floor }
local SIGNS = {
	SHOPStall = { "SHOP", 5.93, 11.2 },
	POTIONSStall = { "POTIONS", 5.93, 11.2 },
	MarketStall = { "MARKET", 4.15, 11.7 },
	IndexBoard = { "RUNNER INDEX", -0.1, 10.7 },
}

function PlazaPieces.Ready(key)
	local row = PlazaPieces.Assets[key]
	return row ~= nil and row.Asset ~= 0
end

function PlazaPieces.GateKey(locked)
	return locked and "WorldGateLocked" or "WorldGateOpen"
end

-- True when the world gate in that state has its mesh.
function PlazaPieces.GateReady(locked)
	return PlazaPieces.Ready(PlazaPieces.GateKey(locked))
end

-- This world's altar, or nil until both its states are uploaded.
function PlazaPieces.Altar()
	local altar = ALTARS[WorldConfig.Id]
	local key = "Altar" .. altar.Look
	return PlazaPieces.Ready(key .. "Locked") and PlazaPieces.Ready(key .. "Unlocked") and altar or nil
end

-- Studs: the turning Mythic's largest extent on the altar that stands here.
function PlazaPieces.AltarModelSize()
	local altar = PlazaPieces.Altar()
	return altar and altar.ModelSize or TODAYS_MODEL_SIZE
end

-- How the Mythic looks on the altar that stands here while it is locked: { Color, Transparency }.
function PlazaPieces.LockedLook()
	local altar = PlazaPieces.Altar()
	return altar and altar.Locked or TODAYS_LOCKED
end

-- A mesh's name without the number Blender adds to a repeated one ("Body.001"): the key of the table's Parts.
function PlazaPieces.PartName(name)
	return (string.gsub(name, "%.%d+$", ""))
end

-- True when every part of the row is in `parts`: a piece with a part missing counts as not loaded, so its stand-in stays.
function PlazaPieces.Complete(row, parts)
	for name in row.Parts do
		if not parts[name] then
			return false
		end
	end
	return true
end

-- True when every key of `needs` is in `loaded`.
function PlazaPieces.Loaded(needs, loaded)
	for _, key in needs or {} do
		if not loaded[key] then
			return false
		end
	end
	return true
end

-- What Server/PlazaDressing stands: Assets (key -> row to load), Placed ({ Key, Pos, Face, Tag?, Needs? }: placed when every key of
-- Needs loaded), Signs, and Replaces (SpawnArea path -> the keys that must have loaded before that stand-in is hidden).
function PlazaPieces.Plan(layout, gateLocked)
	local assets, placed, signs = table.clone(layout.Assets), {}, {}
	local replaces = {}
	local swapped = {}
	for _, key in SAME_KEY do
		if PlazaPieces.Ready(key) then
			swapped[key] = true
			assets[key] = PlazaPieces.Assets[key]
		end
	end
	if swapped.MarketStall then
		assets.MarketSign = nil
	end
	for _, row in layout.Placed do
		if not (row.Key == "MarketSign" and swapped.MarketStall) then
			table.insert(placed, row)
		end
	end
	local function stand(key, tag, needs)
		local row = PlazaPieces.Assets[key]
		assets[key] = row
		table.insert(placed, { Key = key, Pos = row.Pos, Face = row.Face, Tag = tag, Needs = needs })
	end
	if PlazaPieces.GateReady(gateLocked) then
		local key = PlazaPieces.GateKey(gateLocked)
		stand(key)
		replaces.WorldGate = { key }
	end
	local altar = PlazaPieces.Altar()
	if altar then
		local needs = { "Altar" .. altar.Look .. "Locked", "Altar" .. altar.Look .. "Unlocked" }
		stand(needs[1], PlazaPieces.ALTAR_TAGS.Locked, needs)
		stand(needs[2], PlazaPieces.ALTAR_TAGS.Unlocked, needs)
		replaces.SidekickAltar = needs
	end
	local closed, open = BossGateConfig.MESH.Closed, BossGateConfig.MESH.Open
	if BossGateConfig.LIVE and PlazaPieces.Ready(closed) and PlazaPieces.Ready(open) then
		local needs = { closed, open }
		stand(closed, BossGateConfig.CLOSED_TAG, needs)
		stand(open, BossGateConfig.OPEN_TAG, needs)
		replaces.BossGate = needs
	end
	if PlazaPieces.Ready("SenseiDais") then
		stand("SenseiDais")
		replaces["CheckpointNpc/Dais"] = { "SenseiDais" }
	end
	for _, row in layout.Signs do
		local sign = row
		for key, at in SIGNS do
			if swapped[key] and at[1] == row.Text then
				local piece = PlazaPieces.Assets[key]
				sign = table.clone(row)
				sign.Pos = piece.Pos + piece.Face * at[2] + Vector3.new(0, at[3], 0)
			end
		end
		table.insert(signs, sign)
	end
	return { Assets = assets, Placed = placed, Signs = signs, Replaces = replaces }
end

return PlazaPieces
