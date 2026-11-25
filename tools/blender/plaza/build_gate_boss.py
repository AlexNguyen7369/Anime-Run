"""Boss gate A (draft_boss_gate.py gate), full size at Shared/BossGateConfig's place: BossGateClosed, BossGateOpen. Two faults of
the blind review mended on the closed one (BossGateClosedDraft is it unmended, the approved draft): the light sliver round the shut doors (a dark rim behind the joint) and the plain
back of the seal (a gold plate, studs and a point, as the front's).
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


def gate(closed, mended=True):
	m = db.gate(closed, bp.place(*POS, bp.TOP, bp.to_spawn(*POS)), 1.0, "BossGate")
	if closed and mended:
		db.annulus(m, db.RI - 0.7, db.RI + 0.6, 1.6, 2.7, "d2", "d2")
		c = db.C
		dg.prism(m, [(2.6 * math.cos(k / 8 * math.tau + math.pi / 8), c + 2.6 * math.sin(k / 8 * math.tau + math.pi / 8)) for k in range(8)], 4.05, 4.5, "gd2", "gd2", 0.2, "gd1")
		for k in range(8):
			a = k / 8 * math.tau
			m.box((0.6, 0.5, 0.6), (2.95 * math.cos(a), 4.2, c + 2.95 * math.sin(a)), "gd1")
		for k in range(4):
			a, b = k / 4 * math.tau, (k + 1) / 4 * math.tau
			at = lambda t: (1.6 * math.cos(t), 4.5, c + 1.6 * math.sin(t))
			m.face([at(a), at(b), (0, 6.0, c)], "ir3" if k in (0, 1) else "ir2")
	return m


if __name__ == "__main__":
	piece_export.run("gate_boss", [("BossGateClosed", gate(True)), ("BossGateOpen", gate(False)), ("BossGateClosedDraft", gate(True, False))])
