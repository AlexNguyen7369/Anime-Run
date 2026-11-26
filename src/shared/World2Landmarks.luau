--!nonstrict
-- World 2's landmarks that stream Persistent (WORLD2_SPEC "Hero landmarks always loaded", lead 2026-11-26, **proposed**):
-- the big pieces a runner sees across the wide layout's 600+ stud gaps, which would otherwise stream out at the 1,024-stud
-- StreamingTargetRadius (Track 2's ChainTower from 1,100 to 2,300, Track 10's Abyss past 1,300). Only these; every other
-- Placed prop keeps its streaming mode, and World 1 has none. Read by Shared/BiomeDressing in World 2 only.
-- Names: every Placed row of that prop (a cut mesh by its pieces, "<Name>_p<i>"). At: one row of a prop that also stands
-- elsewhere, by its base centre in world x, z (cross_track.py LANDMARK, Track 6), matched within AT_TOLERANCE studs; the
-- biome harness fails if a listed row is no longer found.
local World2Landmarks = {}

World2Landmarks.AT_TOLERANCE = 3

World2Landmarks.Biomes = {
	ElvenPlains = { Names = { "RuinedCastle", "Town" } },
	DemonCastle = { Names = { "ChainTower" } },
	RuinedCityZ = { Names = { "HeroHQ" } },
	HauntedTunnel = { Names = {} },
	KaijuBase = { Names = { "DefenseHQ" } },
	DevilTokyo = {
		Names = { "HQ" },
		At = {
			{ Prop = "Mansion", X = 2290.0, Z = -263.7 }, -- the bend's lit landmark
			{ Prop = "Office", X = -2267.9, Z = 2414.0 }, -- the finish's lit landmark
		},
	},
	AntIsland = { Names = { "IslandVolcano" } },
	MonsterDen = { Names = { "LairTower" } },
	GoldenCity = { Names = { "Church" } },
	HellGate = { Names = { "DarkGate", "Abyss" } },
}

-- True when the Placed row of `prop` (its draft name, pieces "_p<i>" included) whose base centre is world `x`, `z` is one
-- of `biome`'s landmarks.
function World2Landmarks.Is(biome, prop, x, z)
	local entry = World2Landmarks.Biomes[biome]
	if not entry then
		return false
	end
	local whole = string.match(prop, "^(.-)_p%d+$") or prop
	for _, name in entry.Names or {} do
		if name == whole then
			return true
		end
	end
	for _, at in entry.At or {} do
		if
			at.Prop == whole
			and math.abs(at.X - x) <= World2Landmarks.AT_TOLERANCE
			and math.abs(at.Z - z) <= World2Landmarks.AT_TOLERANCE
		then
			return true
		end
	end
	return false
end

return World2Landmarks
