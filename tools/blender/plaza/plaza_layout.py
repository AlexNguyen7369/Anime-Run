#!/usr/bin/env python3
# The plaza's one transform (WORLD_REDESIGN_SPEC 3 and 4 "Plaza size", lead's choice under owner 2026-11-26, proposed), the same as
# src/shared/PlazaLayout.luau. The Blender drafts (build_plaza.py and the piece builders) stay in the approved frame, spawn at (0, 0);
# upload_plaza.py and upload_pieces.py pass every position through here when they write Shared/PlazaAssets and PlazaPieceAssets.
# An anchor's spot scales about the spawn; what belongs to an anchor moves with it unscaled, so its look stays.
#   python3 tools/blender/plaza/plaza_layout.py --self-test
import sys

SCALE = 1.2
CENTRE = (20.0, 0.0)  # world (x, z) of the spawn

SPAWN = (0.0, 0.0)
PAD = (-84.0, 78.0)
SHOP = (-83.942, -3.109)
POTIONS = (-57.158, -61.555)
MARKET = (3.109, -83.942)
INDEX = (76.7, -34.2)
ALTAR = (57.158, 61.555)
BOSS_GATE = (2.5, 94.8)  # spot S4 (BossGateConfig.SPOT); the meshes stand 1.5 studs toward the spawn from it
WORLD_GATE = (76.0, -96.0)
GREAT_SAKURA = (80.0, 118.0)

# What each generated row moves with: key -> anchor (a row's own spot when it is an anchor)
PLACED = {
	"MainPath": PAD,
	"HeroTorii": PAD,
	"Lantern": PAD,
	"Showpiece": SPAWN,
	"SkyLoop": SPAWN,
	"LegendPedestal": SPAWN,
	"MarketSign": MARKET,
	"GreatSakura": GREAT_SAKURA,
	"SHOPStall": SHOP,
	"POTIONSStall": POTIONS,
	"MarketStall": MARKET,
	"IndexBoard": INDEX,
	"SenseiDais": PAD,
	"AltarGreatLotusLocked": ALTAR,
	"AltarGreatLotusUnlocked": ALTAR,
	"AltarTwinRoofLocked": ALTAR,
	"AltarTwinRoofUnlocked": ALTAR,
	"BossGateClosed": BOSS_GATE,
	"BossGateOpen": BOSS_GATE,
	"WorldGateLocked": WORLD_GATE,
	"WorldGateOpen": WORLD_GATE,
}
SIGNS = {"SHOP": SHOP, "POTIONS": POTIONS, "RUNNER INDEX": INDEX, "RACE START": PAD, "MARKET": MARKET}
LANDMARKS = {"Market": MARKET, "RaceStart": PAD}


def spot(x, z):
	return (CENTRE[0] + x * SCALE, CENTRE[1] + z * SCALE)


def with_anchor(x, z, anchor):
	a = spot(*anchor)
	return (x + a[0] - anchor[0], z + a[1] - anchor[1])


def move3(pos, anchor):
	"""A Roblox (x, y, z) position that moves with `anchor`; y is kept."""
	x, z = with_anchor(pos[0], pos[2], anchor)
	return [x, pos[1], z]


def apply_layout(layout):
	"""Shared/PlazaAssets' layout (build_plaza.py export) from the approved frame to the world, in place."""
	for row in layout["Placed"]:
		row["Pos"] = move3(row["Pos"], PLACED[row["Key"]])
	layout["Exclusive"]["Pos"] = move3(layout["Exclusive"]["Pos"], SPAWN)
	for row in layout["Signs"]:
		row["Pos"] = move3(row["Pos"], SIGNS[row["Text"]])
	for name, pos in layout["Landmarks"].items():
		layout["Landmarks"][name] = move3(pos, LANDMARKS[name])
	return layout


def apply_pieces(pieces):
	"""Shared/PlazaPieceAssets' rows (key -> piece with Pos) from the approved frame to the world, in place."""
	for key, piece in pieces.items():
		if not key.endswith("Draft"):  # a draft row is never written to the table
			piece["Pos"] = move3(piece["Pos"], PLACED[key])
	return pieces


def self_test():
	assert spot(0, 0) == CENTRE
	x, z = spot(*PAD)
	assert abs(x + 80.8) < 1e-9 and abs(z - 93.6) < 1e-9
	lx, lz = with_anchor(-69.605, 52.897, PAD)  # a lantern keeps its offset from the pad
	assert abs((lx - x) - (-69.605 + 84)) < 1e-9 and abs((lz - z) - (52.897 - 78)) < 1e-9
	print("plaza_layout self-test ok")


if __name__ == "__main__" and "--self-test" in sys.argv:
	self_test()
