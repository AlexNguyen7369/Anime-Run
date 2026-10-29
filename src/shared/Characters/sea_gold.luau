--!strict
-- Permanent catalog contract (docs/CHARACTER_GACHA_SPEC.md): Id is a save key, never rename or reuse it.
-- Event-only: rolled only while the "gold" weather event runs (GachaConfig).
return {
	Id = "sea_gold",
	Name = "Rojer",
	Rarity = "Legendary",
	Chance = 6.2e8,
	SpeedMulti = 10,
	Order = 26,
	Category = "Balanced",
	Series = "sea",
	Archetype = "swordsman",
	Event = "gold",
	Model = nil,
}
