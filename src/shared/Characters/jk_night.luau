--!strict
-- Permanent catalog contract (docs/CHARACTER_GACHA_SPEC.md): Id is a save key, never rename or reuse it.
-- Event-only: rolled only while the "night" weather event runs (GachaConfig).
return {
	Id = "jk_night",
	Name = "Toje",
	Rarity = "Legendary",
	Chance = 4.3e7,
	SpeedMulti = 8,
	Order = 22,
	Category = "Sprinter",
	Series = "jk",
	Archetype = "brawler",
	Event = "night",
	Model = nil,
}
