"""Boss gate A (draft_boss_gate.py gate), full size at Shared/BossGateConfig's place: BossGateClosed, BossGateOpen. Both are the
approved draft as it was (owner 2026-11-25).
Headless: blender -b --factory-startup --python tools/blender/plaza/build_gate_boss.py -- [--check]
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_plaza as bp  # noqa: E402
import draft_gate as dg  # noqa: E402
import draft_boss_gate as db  # noqa: E402
import piece_export  # noqa: E402

bp.PAL.update(dg.PAL)
bp.PAL.update(db.PAL)
bp.GLOW.update(db.GLOW)
SPOT, SHIFT = (2.5, 94.8), 1.5  # Shared/BossGateConfig SPOT, SHIFT: toward the spawn
_r = math.hypot(*SPOT)
POS = (SPOT[0] * (1 - SHIFT / _r), SPOT[1] * (1 - SHIFT / _r))


def gate(closed):
	return db.gate(closed, bp.place(*POS, bp.TOP, bp.to_spawn(*POS)), 1.0, "BossGate")


if __name__ == "__main__":
	piece_export.run("gate_boss", [("BossGateClosed", gate(True)), ("BossGateOpen", gate(False))])
