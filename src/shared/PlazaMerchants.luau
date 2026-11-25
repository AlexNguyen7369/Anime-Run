--!nonstrict
-- The merchants' cast (WORLD_REDESIGN_SPEC 4.2, owner 2026-11-25), the same in both worlds: service model (Shared/SpawnArea)
-- -> character and where its feet stand, in the service's frame (X right, Y up, -Z the front). Nobody stands there while
-- PlazaPieces.MERCHANTS_LIVE is off. Scale 1 is the built rig (a runner in game is RunnerFactory.SCALE of it); Kakashe is the smaller one, under the
-- Sensei header as it is (owner 2026-11-25; 0.75 is the draft's). Feet are draft set B's (tools/blender/plaza/draft_merchants.py CAST), proposed.
-- Pose: limb -> degrees { x, y, z } about its top (the head about its bottom), as the draft turns it (draft_merchants.py turn(): its own axes, x
-- right to the keeper's left, y to the back, z up); arms that rest on a counter hold the angle the draft solved. Yaw: degrees. Static poses on the
-- existing rigs, proposed. HideName: no floating name, the Sensei header is there (proposed).
return {
	ShopStall = {
		Id = "sea_navigator",
		Scale = 1,
		Feet = Vector3.new(0, 1.5, -0.95),
		Pose = { RightArm = { -52.55, 24, 0 }, LeftArm = { -54.35, -10, 0 } },
	},
	PotionsStall = {
		Id = "leaf_medic",
		Scale = 1,
		Feet = Vector3.new(0, 1.2, -0.6),
		Pose = { RightArm = { -56.01, 2, 0 }, LeftArm = { -56.01, -2, 0 } },
	},
	Marketplace = {
		Id = "ds_flame",
		Scale = 1,
		Feet = Vector3.new(0, 1.5, -1.4),
		Pose = { RightArm = { -54.82, 16, 0 }, LeftArm = { -54.82, -16, 0 } },
	},
	IndexBoard = {
		Id = "fr_mage",
		Scale = 1,
		Feet = Vector3.new(3.7, 0.75, -1.5),
		Yaw = 4,
		Pose = { RightArm = { -8, 4, 0 }, LeftArm = { -59.01, -4, 0 } },
	},
	CheckpointNpc = {
		Id = "leaf_copycat",
		Scale = 0.75,
		Feet = Vector3.new(0, 0.65, -0.5),
		HideName = true,
		Pose = { RightArm = { -152, -20, 0 }, LeftArm = { 14, -16, 0 }, RightLeg = { 0, 6, 0 }, LeftLeg = { 0, -6, 0 } },
	},
}
