"""Market set B with the merchants' fixes (draft_merchants.py stall(), the approved cast's stalls): SHOPStall, POTIONSStall,
MarketStall (its sign is in the mesh, so MarketSign goes), IndexBoard, SenseiDais. No merchant is in a mesh.
Headless: blender -b --factory-startup --python tools/blender/plaza/build_market_pieces.py -- [--check]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as bp  # noqa: E402
import draft_markets as dm  # noqa: E402
import draft_merchants as dr  # noqa: E402
import piece_export  # noqa: E402

KEYS = {"Shop": "SHOPStall", "Potions": "POTIONSStall", "Market": "MarketStall", "Index": "IndexBoard", "Sensei": "SenseiDais"}
bp.PAL.update(dm.PAL)
bp.GLOW.update(dm.GLOW)

if __name__ == "__main__":
	dm.MAX_TRIS.update(B_Market=4500, B_Shop=4500, B_Potions=4500)
	bp.rng.seed(11)  # draft_merchants.build's: the stalls as approved, built in its order
	out = []
	for name, (pos, face, _a, fn, top) in dm.PIECES.items():
		boards, board = [], dm.K.board
		dm.K.board = lambda self, *a, **k: (boards.append(a[:5]), board(self, *a, **k))[1]
		m = dr.stall(name, fn)
		dm.K.board = board
		dm.check(m, "B_" + name, top)
		print("BOARD", KEYS[name], boards, "top limit", top)
		out.append((KEYS[name], m))
	piece_export.run("market", out)
