"""Summon altars (draft_altar.py): the great lotus, draft B (World 1), or the twin-roof stage, draft A (World 2), each locked and
unlocked: AltarGreatLotusLocked / Unlocked, AltarTwinRoofLocked / Unlocked. The model stands at SPOT (studs over the floor, altar frame);
the game puts the turning Mythic there.
Headless: blender -b --factory-startup --python tools/blender/plaza/build_altar_pieces.py -- [--check]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draft_altar as da  # noqa: E402
import piece_export  # noqa: E402


def pieces(concept, key):
	out = []
	for locked in (True, False):
		parts, spot, size, info = da.CONCEPTS[concept](locked)
		k = "Altar%s%s" % (key, "Locked" if locked else "Unlocked")
		out.append((k, piece_export.joined(k, [p for p in parts if p.f])))
		print("SPOT", k, "model", spot, "size", size, "label", info.get("label"), "beam", info.get("beam"))
	return out


if __name__ == "__main__":
	piece_export.run("altar_lotus", pieces("B", "GreatLotus"))
	piece_export.run("altar_roof", pieces("A", "TwinRoof"))
