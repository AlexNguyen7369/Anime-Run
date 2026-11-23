"""World 2 Track 10: Hell Gate (Saw Man). The devils' Hell: dead flat ground under a blood-red sky, a vast field of
free-standing doors (closed, ajar, some open on nothing), giant pale hands rising out of the ground, broken stairs
floating in the air, and a great gate spanning the road before the finish as the landmark. No symbols or text
(design doc 5). Everything in-house, parts only. Track 10 is about 22,000 studs long, so spacing is wide to keep the
instance count down. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

GROUND, DUST = "3A1414", "4A1C18"
PALE, PALE2 = "F2E6DA", "D8C8BA"
WOOD, WOOD2, RED, BLACK = "5A3020", "3A2018", "A01818", "120808"


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0, spin=False):
	"""kit.along, but every prop stands on the ground (y = -1) even on ramps, and never near another road stretch."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], abs(o) * 0.9):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw = k.rng.uniform(0, math.tau) if spin else yaw + (math.pi / 2 if off > 0 else -math.pi / 2)  # -Z faces the road, as kit.along
			k.place(k.rng.choice(names), (pos[0], y, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def door(frame, slab, ajar=0, w=8, h=16, knob="C8A040"):
	"""A free-standing door: frame posts and lintel on a sill, the slab hinged on the left and swung `ajar` degrees."""
	a = math.radians(ajar)
	cx, cz = -w / 2 + math.cos(a) * w / 2, -math.sin(a) * w / 2  # slab centre after swinging about the left hinge
	parts = [
		("box", (w + 3, 0.8, 3), (0, 0.4, 0), frame),
		("box", (1.5, h + 1, 1.6), (-w / 2 - 0.75, h / 2 + 0.8, 0), frame),
		("box", (1.5, h + 1, 1.6), (w / 2 + 0.75, h / 2 + 0.8, 0), frame),
		("box", (w + 3, 1.5, 1.6), (0, h + 1.5, 0), frame),
		("box", (w, h, 0.6), (cx, h / 2 + 0.8, cz), slab, {"rot": (0, ajar, 0)}),
		("ball", (0.9, 0.9, 0.9), (cx + math.cos(a) * (w / 2 - 1.2), h / 2, cz - math.sin(a) * (w / 2 - 1.2) - 0.6), knob, {"metal": 1, "rough": 0.3}),
	]
	if ajar:
		parts.append(("box", (w - 0.2, h - 0.2, 0.2), (0, h / 2 + 0.8, 0.1), BLACK, {"emit": 0.0}))  # the dark beyond
	return parts


def hand(curl):
	"""A giant pale hand rising out of the ground: forearm, palm, four fingers and a thumb, fingers bent by `curl`."""
	parts = [
		("cyl", (12, 40, 10), (0, 20, 0), PALE2, {"seg": 10, "taper": 0.9}),
		("cone", (20, 4, 18), (0, 1.5, 0), DUST, {"seg": 8, "taper": 0.5}),  # earth heaped at the wrist
		("box", (14, 16, 6), (0, 47, 0), PALE),
	]
	for i, x in enumerate((-5.2, -1.8, 1.8, 5.2)):
		ln = (11, 13, 12, 9)[i]
		# chained from the knuckle on the palm top (y 55); Kit rot (a, 0, 0) tilts +Y toward +Z
		a1, a2 = math.radians(curl), math.radians(curl * 1.8)
		mid = (x, 55 + math.cos(a1) * ln / 2, math.sin(a1) * ln / 2)
		tip = (x, 55 + math.cos(a1) * ln, math.sin(a1) * ln)
		l2 = ln * 0.7
		parts.append(("box", (3, ln + 1, 3.4), mid, PALE, {"rot": (curl, 0, 0)}))
		parts.append(("box", (2.8, l2 + 1, 3.2), (x, tip[1] + math.cos(a2) * l2 / 2, tip[2] + math.sin(a2) * l2 / 2), PALE2, {"rot": (curl * 1.8, 0, 0)}))
	parts.append(("box", (3.4, 11, 3.6), (-9, 46, -2), PALE, {"rot": (20, 0, 40)}))
	return parts


def build(k):
	k.prop("DoorWood", door(WOOD, WOOD2))
	k.prop("DoorWhite", door(PALE2, PALE, ajar=35))
	k.prop("DoorRed", door(BLACK, RED))
	k.prop("DoorOpen", door(WOOD2, WOOD, ajar=80))
	k.prop("DoorTall", door(PALE2, "B8A898", w=12, h=28, ajar=15))
	k.prop("DoorRedTall", door(WOOD2, RED, w=11, h=24))
	k.prop("HandOpen", hand(10))
	k.prop("HandGrasp", hand(55))
	# Floating broken stairs: a run of steps, a gap, two steps, and a chunk of broken landing
	stairs = []
	for i in range(8):
		if i in (4, 5):
			continue
		stairs.append(("box", (10, 2, 4), (0, i * 2.4, -i * 4), PALE2 if i % 2 else "C0B0A4"))
	stairs.append(("box", (12, 2.4, 10), (0, 19, -36), "B0A096", {"rot": (8, 10, -6)}))
	stairs.append(("box", (3, 2, 3), (6, -3, 2), "B0A096", {"rot": (30, 20, 10)}))
	k.prop("Stairs", stairs)
	k.prop("Rubble", [("box", (6, 3, 5), (0, 1.5, 0), DUST, {"rot": (0, 20, 8)}), ("box", (4, 2, 4), (5, 1, 3), "2A1010", {"rot": (0, -30, 0)})])
	# Landmark: the great gate spanning the road; posts outside the lane, lintel far above, leaves swung open
	gate = [
		("box", (30, 160, 30), (-62, 80, 0), "2A1010"),
		("box", (30, 160, 30), (62, 80, 0), "2A1010"),
		("box", (164, 24, 34), (0, 172, 0), "1E0A0A"),
		("box", (180, 8, 40), (0, 188, 0), "3A1414"),
		("box", (40, 12, 40), (-62, 6, 0), "4A1C18"),
		("box", (40, 12, 40), (62, 6, 0), "4A1C18"),
		("box", (46, 150, 4), (-70, 76, -38), RED, {"rot": (0, 70, 0)}),  # left leaf swung back off the road
		("box", (46, 150, 4), (70, 76, -38), RED, {"rot": (0, -70, 0)}),
		("box", (90, 6, 26), (0, 157, 0), "C8B4A0"),
	]
	for x in (-100, 100):
		gate.append(("box", (20, 110, 20), (x * 1.0, 55, 14), "2A1010"))
		gate.append(("cone", (24, 30, 24), (x * 1.0, 125, 14), "1E0A0A", {"seg": 4}))
	k.prop("GreatGate", gate)

	k.ground(GROUND, margin=700, rough=1.0)
	doors = ["DoorWood", "DoorWhite", "DoorRed", "DoorOpen", "DoorWood", "DoorRed"]
	ground_along(k, 64, (-40, 40), doors, jitter=10, start=40, spin=True, scale=(0.9, 1.2))
	ground_along(k, 110, (-85, 85), doors + ["DoorTall", "DoorRedTall"], jitter=20, start=70, spin=True, scale=(1.0, 1.4))
	ground_along(k, 170, (-150, 150), ["DoorTall", "DoorRedTall", "DoorWhite"], jitter=30, start=20, spin=True, scale=(1.4, 2.0))
	ground_along(k, 420, (-60, 60), ["Rubble"], jitter=20, start=200, spin=True)
	ground_along(k, 520, (-120, 120), ["HandOpen", "HandGrasp"], jitter=40, start=300, scale=(1.6, 2.4))
	ground_along(k, 600, (-130, 130), ["Stairs"], jitter=25, start=500, y=40, spin=True, scale=(1.4, 2.0))
	k.field(260, doors + ["DoorTall", "DoorRedTall"], clearance=220, margin=600, scale=(1.4, 2.6))
	k.field(24, ["HandOpen", "HandGrasp"], clearance=300, margin=600, scale=(2.5, 4.0))
	pos, yaw = k.beside(k.length - 200, 0, 1.0)
	k.place("GreatGate", pos, yaw)
	k.sky([(0.0, "FF6A4A"), (0.1, "D82A1A"), (0.4, "8A0A10"), (1.0, "3A0208")], strength=1.2, sun=(2.0, "FFD0C0", 30, 200))
