--!nonstrict
-- The plaza's one transform (WORLD_REDESIGN_SPEC 3 and 4 "Plaza size", lead's choice under owner 2026-11-26, proposed): every
-- approved spot is written as approved, with the spawn at (0, 0); in the world it stands at CENTRE + SCALE x the spot. An anchor
-- (a stall, a building, the gate pad) scales; what belongs to it moves with it unscaled (With), so its look stays. The same
-- transform is tools/blender/plaza/plaza_layout.py, which wrote the generated Shared/PlazaAssets and PlazaPieceAssets positions.
local PlazaLayout = {}

PlazaLayout.SCALE = 1.2
PlazaLayout.CENTRE = Vector2.new(20, 0) -- world (x, z) of the spawn; the track chains stay at TrackBuilder.CHAIN_ORIGIN
PlazaLayout.APPROVED_FLOOR = Vector2.new(188, 220) -- studs (x, z) as approved (design doc 4.43)

local function flat(v)
	return typeof(v) == "Vector3" and Vector2.new(v.X, v.Z) or v
end

local function out(like, v2)
	return typeof(like) == "Vector3" and Vector3.new(v2.X, like.Y, v2.Y) or v2
end

-- World spot of an anchor's approved spot (Vector2 x, z or Vector3, whose Y is kept).
function PlazaLayout.Spot(v)
	return out(v, PlazaLayout.CENTRE + flat(v) * PlazaLayout.SCALE)
end

-- World spot of an approved point that moves unscaled with `anchor` (its approved spot).
function PlazaLayout.With(v, anchor)
	local a = flat(anchor)
	return out(v, flat(v) + PlazaLayout.CENTRE + a * PlazaLayout.SCALE - a)
end

-- An approved offset from the spawn, scaled (an anchor's place relative to the spawn).
function PlazaLayout.Offset(v)
	return out(v, flat(v) * PlazaLayout.SCALE)
end

return PlazaLayout
