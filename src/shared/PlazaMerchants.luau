--!nonstrict
-- The merchants' cast (WORLD_REDESIGN_SPEC 4.2, owner 2026-11-25), the same in both worlds: service model (Shared/SpawnArea)
-- -> character and where its feet stand, in the service's frame (X right, Y up, -Z the front). Only markers for now: no
-- merchant is spawned. Feet are draft set B's (tools/blender/plaza/draft_merchants.py CAST), proposed.
return {
	ShopStall = { Id = "sea_navigator", Feet = Vector3.new(0, 1.5, -0.95) },
	PotionsStall = { Id = "leaf_medic", Feet = Vector3.new(0, 1.2, -0.6) },
	Marketplace = { Id = "ds_flame", Feet = Vector3.new(0, 1.5, -1.4) },
	IndexBoard = { Id = "fr_mage", Feet = Vector3.new(3.7, 0.75, -1.5) },
	CheckpointNpc = { Id = "leaf_copycat", Feet = Vector3.new(0, 0.65, -0.5) },
}
