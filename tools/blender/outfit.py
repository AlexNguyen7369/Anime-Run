# Outfit pieces and accessories, named presets plus raw primitive "extras" (docs/CHARACTER_GACHA_SPEC.md).
# Character faces -Y; its left side is +X. Every object is parented to an R15 part.
import math

from chibi_base import (
	ANKLE,
	HEAD_R,
	HEAD_Z,
	HIP,
	KNEE,
	SHOULDER_X,
	TORSO_TOP,
	WAIST,
	box,
	cone,
	cyl,
	mark_mesh,
	sphere,
	toon,
	torus,
)

D = math.pi / 180


def build_outfit(c, parts):
	o = c.get("outfit", {})
	bulk = c.get("bulk", 1.0)
	ut, lt = parts["UpperTorso"], parts["LowerTorso"]
	tw, td = 0.74 * bulk, 0.44 * bulk
	th = TORSO_TOP - WAIST
	tz = (TORSO_TOP + WAIST) / 2
	for piece in o.get("pieces", []):
		kind = piece["kind"]
		col = toon(piece["colour"])
		if kind == "jacket_open":  # open front: back + two side panels, slightly bigger than the torso
			box("UpperTorso_JacketBack", (tw + 0.08, 0.06, th + 0.08), (0, td / 2 + 0.03, tz), col, ut)
			for sgn in (-1, 1):
				box(f"UpperTorso_JacketSide{sgn}", (tw * 0.32, td + 0.08, th + 0.1), (sgn * tw * 0.36, -0.02, tz), col, ut)
		elif kind == "vest":
			box("UpperTorso_Vest", (tw + 0.05, td + 0.05, th * 0.85), (0, 0, tz + 0.03), col, ut, bevel=0.04)
		elif kind == "collar_high":
			cyl("UpperTorso_Collar", 0.3, 0.2, (0, 0, TORSO_TOP + 0.06), col, ut, verts=10, r2=0.33)
		elif kind == "scarf":
			torus("UpperTorso_Scarf", 0.27, 0.08, (0, 0, TORSO_TOP + 0.02), col, ut, scale=(1.1, 1.0, 1.0))
			box("UpperTorso_ScarfTail", (0.14, 0.05, 0.5), (0.18, 0.24, TORSO_TOP - 0.2), col, ut, rot=(0.2, 0, 0.2))
		elif kind == "cape":
			box("UpperTorso_Cape", (tw + 0.25, 0.05, piece.get("length", 1.4)), (0, td / 2 + 0.1, TORSO_TOP - piece.get("length", 1.4) / 2 + 0.05), col, ut, rot=(-6 * D, 0, 0))
			for sgn in (-1, 1):
				box(f"UpperTorso_Pauldron{sgn}", (0.32, 0.4, 0.14), (sgn * (SHOULDER_X * bulk + 0.05), 0, TORSO_TOP + 0.04), col, ut, bevel=0.05)
		elif kind == "haori":  # long open coat, shoulders to knees
			L = piece.get("length", 1.1)
			box("UpperTorso_HaoriBack", (tw + 0.14, 0.06, L), (0, td / 2 + 0.05, TORSO_TOP - L / 2), col, ut)
			for sgn in (-1, 1):
				box(f"UpperTorso_HaoriSide{sgn}", (0.2, td + 0.12, L), (sgn * (tw / 2 + 0.03), 0, TORSO_TOP - L / 2), col, ut)
				box(f"UpperTorso_HaoriFront{sgn}", (tw * 0.2, 0.05, L), (sgn * tw * 0.42, -td / 2 - 0.04, TORSO_TOP - L / 2), col, ut)
			if piece.get("trim"):
				trim = toon(piece["trim"])
				box("UpperTorso_HaoriHem", (tw + 0.18, td + 0.16, 0.12), (0, 0, TORSO_TOP - L + 0.06), trim, ut)
		elif kind == "skirt":
			cyl("LowerTorso_Skirt", 0.34, piece.get("length", 0.42), (0, 0, HIP - 0.05), col, lt, verts=10, r2=0.44)
		elif kind == "belt":
			box("LowerTorso_Belt", (0.66 * bulk, 0.44 * bulk, 0.09), (0, 0, WAIST - 0.02), col, lt)
		elif kind == "sash":
			box("LowerTorso_Sash", (0.68 * bulk, 0.46 * bulk, 0.14), (0, 0, WAIST + 0.02), col, lt)
			box("LowerTorso_SashTail", (0.12, 0.05, 0.4), (0.2, -0.24, WAIST - 0.2), col, lt)
		elif kind == "flak_vest":
			box("UpperTorso_FlakVest", (tw + 0.08, td + 0.1, th * 0.9), (0, 0, tz), col, ut, bevel=0.05)
			for sgn in (-1, 1):
				box(f"UpperTorso_FlakShoulder{sgn}", (0.24, 0.42, 0.1), (sgn * tw * 0.42, 0, TORSO_TOP + 0.02), col, ut)
		elif kind == "wristbands":
			for side in ("Left", "Right"):
				p = parts[side + "LowerArm"]
				cyl(side + "LowerArm_Band", 0.125 * bulk, 0.1, (p.location.x, 0, TORSO_TOP - 0.5), col, p, verts=8)
		elif kind == "gauntlets":  # big grenade-style bracers, made-up shape
			for side in ("Left", "Right"):
				p = parts[side + "LowerArm"]
				cyl(side + "LowerArm_Gauntlet", 0.2, 0.32, (p.location.x, 0, TORSO_TOP - 0.45), col, p, verts=8)
				sphere(side + "LowerArm_GauntletPin", 0.06, (p.location.x, -0.2, TORSO_TOP - 0.4), toon(piece.get("trim", "#222222")), p, seg=6, rings=4)
		elif kind == "boots":
			for side in ("Left", "Right"):
				p = parts[side + "LowerLeg"]
				cyl(side + "LowerLeg_Boot", 0.14, KNEE - ANKLE + 0.05, (p.location.x, 0, (KNEE + ANKLE) / 2), col, p, verts=8)
		elif kind == "leg_wraps":
			for side in ("Left", "Right"):
				p = parts[side + "LowerLeg"]
				cyl(side + "LowerLeg_Wrap", 0.13, 0.22, (p.location.x, 0, ANKLE + 0.14), col, p, verts=8)
		elif kind == "chest_stripe":  # a horizontal band across the shirt
			box("UpperTorso_Stripe", (tw + 0.02, td + 0.02, piece.get("height", 0.12)), (0, 0, piece.get("z", tz)), col, ut)
		elif kind == "chest_panel":  # a front panel (shirt opening, tank top, emblem plate)
			box("UpperTorso_Panel", (piece.get("w", 0.3), 0.04, piece.get("h", th * 0.8)), (0, -td / 2 - 0.02, piece.get("z", tz)), col, ut)
		elif kind == "hood_collar":
			torus("UpperTorso_Hood", 0.3, 0.1, (0, 0.04, TORSO_TOP + 0.02), col, ut, scale=(1.15, 1.1, 1.0))
		elif kind == "buttons":
			for i in range(piece.get("count", 3)):
				cyl(f"UpperTorso_Button{i}", 0.035, 0.02, (0, -td / 2 - 0.035, TORSO_TOP - 0.12 - i * 0.15), col, ut, rot=(math.pi / 2, 0, 0), verts=8)
		elif kind == "tail":
			cyl("LowerTorso_Tail", 0.13, 0.9, (0, 0.55, HIP - 0.15), col, lt, rot=(-60 * D, 0, 0), verts=8, r2=0.05)
		else:
			raise ValueError("unknown outfit piece " + kind)


def build_accessories(c, parts):
	head = parts["Head"]
	hs = c.get("head_scale", 1.0)
	r = HEAD_R * hs
	for a in c.get("accessories", []):
		kind = a["kind"]
		col = toon(a.get("colour", "#888888"))
		if kind == "headband":
			torus("Head_Band", r * 1.01, 0.05, (0, 0, HEAD_Z + r * 0.38), col, head, scale=(1, 1, 1.6))
			plate = toon(a.get("plate", "#b8c0c8"))
			box("Head_BandPlate", (r * 0.75, 0.05, r * 0.32), (0, -r * 0.96, HEAD_Z + r * 0.38), plate, head, bevel=0.02)
			if a.get("mark"):
				mark_mesh("Head_BandMark", a["mark"], r * 0.26, (0, -r * 0.99 - 0.03, HEAD_Z + r * 0.38), toon(a.get("mark_colour", "#555555")), head)
				if a.get("slash"):
					box("Head_BandSlash", (r * 0.6, 0.02, 0.025), (0, -r * 1.0 - 0.04, HEAD_Z + r * 0.38), toon("#333333"), head, rot=(0, 0.3, 0))
		elif kind == "mask_mouth":
			box("Head_MouthMask", (r * 1.5, r * 1.25, r * 0.55), (0, -r * 0.36, HEAD_Z - r * 0.5), col, head, bevel=0.06)
		elif kind == "blindfold":
			torus("Head_Blindfold", r * 1.0, 0.09, (0, 0, HEAD_Z - r * 0.02), col, head, scale=(1, 1, 2.2))
		elif kind == "eyepatch_slant":  # headband pulled over one eye
			sgn = 1 if a.get("side", "left") == "left" else -1
			box("Head_EyeCover", (r * 0.5, 0.06, r * 0.34), (sgn * r * 0.36, -r * 0.92, HEAD_Z - r * 0.08), col, head, rot=(0, sgn * 0.25, 0))
		elif kind == "boar_mask":  # made-up boar head with its own snout and tusks, worn over the face
			sphere("Head_Mask", r * 1.18, (0, 0, HEAD_Z + 0.05), col, head, scale=(1.0, 1.08, 0.96), seg=12, rings=8)
			cyl("Head_MaskSnout", r * 0.36, r * 0.5, (0, -r * 1.15, HEAD_Z - r * 0.15), col, head, rot=(math.pi / 2, 0, 0), verts=8)
			cyl("Head_MaskNose", r * 0.26, 0.05, (0, -r * 1.42, HEAD_Z - r * 0.15), toon(a.get("nose", "#c48a8a")), head, rot=(math.pi / 2, 0, 0), verts=8)
			for sgn in (-1, 1):
				cone(f"Head_MaskTusk{sgn}", 0.05, 0.25, (sgn * r * 0.3, -r * 1.25, HEAD_Z - r * 0.4), toon("#f3efe0"), head, rot=(0.4, 0, 0), verts=4)
				cone(f"Head_MaskEar{sgn}", 0.16, 0.35, (sgn * r * 0.7, 0, HEAD_Z + r * 0.95), col, head, rot=(0, sgn * 0.5, 0), verts=4)
				sphere(f"Head_MaskEye{sgn}", 0.07, (sgn * r * 0.42, -r * 1.04, HEAD_Z + r * 0.2), toon("#2a4a8a"), head, seg=6, rings=4)
		elif kind == "bamboo_gag":
			cyl("Head_Bamboo", 0.07, r * 1.5, (0, -r * 0.88, HEAD_Z - r * 0.42), col, head, rot=(0, math.pi / 2, 0), verts=8)
			for sgn in (-1, 1):
				box(f"Head_BambooTie{sgn}", (0.05, r * 1.3, 0.05), (sgn * r * 0.8, -r * 0.2, HEAD_Z - r * 0.4), toon("#c84a4a"), head)
		elif kind == "hair_ribbon":
			for sgn in (-1, 1):
				cone(f"Head_Ribbon{sgn}", 0.18, 0.3, (sgn * 0.17, r * 0.6, HEAD_Z + r * 0.75), col, head, rot=(0, sgn * math.pi / 2, 0), verts=3)
		elif kind == "hat_straw":
			cyl("Head_HatBrim", r * 1.75, 0.05, (0, 0.05, HEAD_Z + r * 0.72), col, head, verts=16)
			cyl("Head_HatCrown", r * 0.95, r * 0.45, (0, 0.05, HEAD_Z + r * 0.95), col, head, verts=12, r2=r * 0.85)
			cyl("Head_HatBand", r * 0.97, 0.1, (0, 0.05, HEAD_Z + r * 0.8), toon(a.get("band", "#c03030")), head, verts=12)
		elif kind == "hat_cowboy":
			cyl("Head_HatBrim", r * 1.6, 0.05, (0, 0.05, HEAD_Z + r * 0.72), col, head, verts=16)
			cyl("Head_HatCrown", r * 0.85, r * 0.55, (0, 0.05, HEAD_Z + r * 1.0), col, head, verts=10, r2=r * 0.75)
			if a.get("mark"):
				for sgn in (-1, 1):
					mark_mesh(f"Head_HatMark{sgn}", a["mark"], 0.14, (sgn * 0.12, -r * 0.82, HEAD_Z + r * 1.0), toon(a.get("mark_colour", "#3070c0")), head)
		elif kind == "turban":
			sphere("Head_Turban", r * 1.1, (0, 0.04, HEAD_Z + r * 0.32), col, head, scale=(1, 1, 0.75), seg=12, rings=8)
			torus("Head_TurbanBand", r * 1.02, 0.07, (0, 0, HEAD_Z + r * 0.22), toon(a.get("band", "#7a3fa0")), head)
			for sgn in (-1, 1):
				cone(f"Head_Antenna{sgn}", 0.04, 0.3, (sgn * 0.12, -r * 0.7, HEAD_Z + r * 0.7), toon(c["skin"], "skin_" + c["skin"]), head, rot=(-0.4, sgn * 0.2, 0), verts=4)
		elif kind == "pointed_ears":
			for sgn in (-1, 1):
				cone(f"Head_Ear{sgn}", 0.12, 0.38, (sgn * r * 1.05, 0, HEAD_Z), toon(c["skin"], "skin_" + c["skin"]), head, rot=(0, sgn * 75 * D, 0), verts=4)
		elif kind == "horns":
			for sgn in (-1, 1):
				cone(f"Head_Horn{sgn}", 0.11, a.get("length", 0.45), (sgn * r * 0.75, 0, HEAD_Z + r * 0.75), col, head, rot=(0, sgn * a.get("spread", 0.6), 0), verts=6)
		elif kind == "dome_head":  # tyrant-style smooth dome, purple top
			sphere("Head_Dome", r * 1.04, (0, 0.04, HEAD_Z + r * 0.2), col, head, scale=(1, 1, 0.85), seg=14, rings=8)
		elif kind == "earrings":
			for sgn in (-1, 1):
				mark_mesh(f"Head_Earring{sgn}", a.get("mark", "hex"), 0.14, (sgn * r * 0.98, -0.05, HEAD_Z - r * 0.45), col, head, rot=(math.pi / 2, 0, math.pi / 2))
		elif kind == "face_lines":  # altered cheek marks: straight bars
			n = a.get("count", 2)
			for sgn in (-1, 1):
				for i in range(n):
					box(f"Head_Line{sgn}_{i}", (r * 0.28, 0.02, 0.025), (sgn * r * 0.55, -r * 0.82 - 0.02, HEAD_Z - r * (0.28 + i * 0.1)), col, head)
		elif kind == "freckles":
			for sgn in (-1, 1):
				for i in range(3):
					sphere(f"Head_Freckle{sgn}_{i}", 0.025, (sgn * r * (0.42 + i * 0.08), -r * 0.86, HEAD_Z - r * (0.3 + (i % 2) * 0.06)), col, head, seg=6, rings=4)
		elif kind == "glasses":
			for sgn in (-1, 1):
				torus(f"Head_Glass{sgn}", r * 0.17, 0.02, (sgn * r * 0.36, -r * 0.95, HEAD_Z - r * 0.1), col, head, rot=(math.pi / 2, 0, 0))
		elif kind == "goggles":
			for sgn in (-1, 1):
				cyl(f"Head_Goggle{sgn}", 0.12, 0.08, (sgn * 0.17, -r * 0.55, HEAD_Z + r * 0.75), col, head, rot=(0.5, 0, 0), verts=8)
			torus("Head_GoggleBand", r * 1.0, 0.035, (0, 0, HEAD_Z + r * 0.62), toon("#222222"), head, rot=(0.25, 0, 0))
		elif kind == "sword_hip":
			n = a.get("count", 1)
			for i in range(n):
				x = 0.34 + i * 0.06
				cyl(f"LowerTorso_Sheath{i}", 0.05, 1.05, (x, -0.05 + i * 0.07, WAIST - 0.25), col, parts["LowerTorso"], rot=(0, 0, 0), verts=6)
				parts["LowerTorso"].children[-1].rotation_euler = (60 * D, 0, 0)
				guard = toon(a.get("guard", "#c8a040"))
				if a.get("mark"):
					mark_mesh(f"LowerTorso_Guard{i}", a["mark"], 0.16, (x, -0.38, WAIST + 0.04), guard, parts["LowerTorso"], rot=(60 * D, 0, 0))
				else:
					cyl(f"LowerTorso_Guard{i}", 0.09, 0.03, (x, -0.38, WAIST + 0.04), guard, parts["LowerTorso"], rot=(60 * D, 0, 0), verts=8)
		elif kind == "sword_back":
			cyl("UpperTorso_BackSword", 0.05, 1.1, (0.15, 0.3, TORSO_TOP - 0.1), col, parts["UpperTorso"], rot=(0, -35 * D, 0), verts=6)
		elif kind == "staff":
			cyl("RightHand_Staff", 0.04, 1.4, (parts["RightHand"].location.x, -0.05, TORSO_TOP - 0.6), col, parts["RightHand"], verts=6)
		elif kind == "hammer":
			p = parts["RightHand"]
			cyl("RightHand_HammerHandle", 0.035, 0.6, (p.location.x, -0.1, p.location.z), toon("#7a5030"), p, rot=(math.pi / 2, 0, 0), verts=6)
			box("RightHand_HammerHead", (0.14, 0.12, 0.26), (p.location.x, -0.42, p.location.z), col, p, rot=(math.pi / 2, 0, 0))
		elif kind == "necklace":
			torus("UpperTorso_Necklace", 0.3, 0.035, (0, -0.03, TORSO_TOP - 0.08), col, parts["UpperTorso"], rot=(0.35, 0, 0))
		elif kind == "headphones_jack":  # small earplug jacks, made-up shape
			for sgn in (-1, 1):
				cyl(f"Head_Jack{sgn}", 0.05, 0.3, (sgn * r * 1.0, 0, HEAD_Z - r * 0.3), col, head, verts=6)
		elif kind == "hairpin":
			for i in range(a.get("count", 2)):
				box(f"Head_Pin{i}", (0.1, 0.03, 0.03), (-r * 0.5 - i * 0.06, -r * 0.75, HEAD_Z + r * 0.45 - i * 0.07), col, head, rot=(0, 0.4, 0))
		elif kind == "mark_on":  # an altered mark on a named part, e.g. a cloak cloud or chest emblem
			p = parts[a["part"]]
			mark_mesh(f"{a['part']}_Mark_{a['mark']}", a["mark"], a.get("size", 0.2), tuple(a["at"]), col, p, rot=tuple(a.get("rot", (math.pi / 2, 0, 0))))
		else:
			raise ValueError("unknown accessory " + kind)
	for i, e in enumerate(c.get("extras", [])):  # raw primitives for one-off shapes
		p = parts[e["part"]]
		col = toon(e["colour"])
		nm = f"{e['part']}_Extra{i}"
		at = tuple(e["at"])
		rot = tuple(v * D for v in e.get("rot", (0, 0, 0)))
		t = e["type"]
		if t == "box":
			box(nm, tuple(e["size"]), at, col, p, rot=rot, bevel=e.get("bevel", 0.0))
		elif t == "cyl":
			cyl(nm, e["r"], e["depth"], at, col, p, rot=rot, verts=e.get("verts", 8), r2=e.get("r2"))
		elif t == "cone":
			cone(nm, e["r"], e["depth"], at, col, p, rot=rot, verts=e.get("verts", 6))
		elif t == "sphere":
			sphere(nm, e["r"], at, col, p, scale=tuple(e.get("scale", (1, 1, 1))), seg=e.get("seg", 10), rings=e.get("rings", 6))
		else:
			raise ValueError("unknown extra type " + t)
