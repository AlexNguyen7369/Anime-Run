--!strict
-- Permanent catalog contract (docs/CHARACTER_GACHA_SPEC.md): Id is a save key, never rename or reuse it.
return {
	Id = "db_scholar",
	Name = "Gohon",
	Rarity = "Rare",
	Chance = 600, -- audit 2026-11-20 (was 1,000)
	SpeedMulti = 2.6,
	Order = 10,
	Category = "Balanced",
	Series = "db",
	Archetype = "brawler",
	Model = nil,
}
