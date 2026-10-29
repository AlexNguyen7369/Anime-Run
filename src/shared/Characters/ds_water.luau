--!strict
-- Permanent catalog contract (docs/CHARACTER_GACHA_SPEC.md): Id is a save key, never rename or reuse it.
-- Event-only: rolled only while the "rain" weather event runs (GachaConfig).
return {
	Id = "ds_water",
	Name = "Giyo",
	Rarity = "Epic",
	Chance = 160000,
	SpeedMulti = 6,
	Order = 16,
	Category = "Marathoner",
	Series = "ds",
	Archetype = "swordsman",
	Event = "rain",
	Model = nil,
}
