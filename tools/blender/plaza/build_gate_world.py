"""World gate B (draft_gate.py concept_b), locked and open: WorldGateLocked, WorldGateOpen. Violet (the gate to World 2); the
World 1 return gate in World 2 is the open mesh with its glow parts recoloured cyan (PlazaLook.Glow, CYAN below).
Headless: blender -b --factory-startup --python tools/blender/plaza/build_gate_world.py -- [--check]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as bp  # noqa: E402
import draft_gate as dg  # noqa: E402
import piece_export  # noqa: E402

bp.PAL.update(dg.PAL)
bp.GLOW.update(dg.COLOURS["violet"])
CYAN = {"Glow_" + n: c[0] for n, c in dg.COLOURS["cyan"].items()}

if __name__ == "__main__":
	piece_export.run("gate_world", [("WorldGateLocked", dg.gate("B", True)), ("WorldGateOpen", dg.gate("B", False))])
	print("CYAN", CYAN)
