# Shared hand for the jk_* painted characters: the dark school uniform with real folds and sheen, an inked eye and jaw,
# hands, mirrored side faces, and lofted bespoke meshes (collars, hoods, skirts, the bob shell).
import math
import random

from atlas import INK, shade, swirl_d


def pal(base, dark, lite, sheen):
	return {"base": base, "dark": dark, "lite": lite, "sheen": sheen}


# ---- 2D: general


def crease(f, x0, y0, cx, cy, x1, y1, p, fat=6, w=1.3):
	"""One cloth fold: broad shadow under the line, an inked line, a lit edge above it."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}Q{cx} {cy + fat} {x0} {y0 + fat * 0.4}Z", p["dark"], opacity=0.85)
	f.taper(x0, y0, cx, cy, x1, y1, w)
	f.taper(x0, y0 - 2.4, cx, cy - 2.8, x1, y1 - 2.4, w * 0.75, p["lite"])


def creases(f, p, lines, seed=0, jitter=4):
	r = random.Random(f"{f.name}{seed}")
	j = lambda: r.uniform(-jitter, jitter)
	for ln in lines:
		x0, y0, cx, cy, x1, y1 = ln[:6]
		fat = ln[6] if len(ln) > 6 else 6
		crease(f, x0 + j(), y0 + j(), cx + j(), cy + j(), x1 + j(), y1 + j(), p, fat)


def form(f, dark="#080912", op=0.5):
	"""Soft shadow to both sides and the bottom: the block reads as a rounded form without hard stripes."""
	w, h = f.w, f.h
	f.soft(f"M-8-8H{w * 0.1}Q{w * 0.13} {h / 2} {w * 0.1} {h + 8}H-8Z", dark, op * 0.7, 5)
	f.soft(f"M{w + 8}-8H{w * 0.86}Q{w * 0.8} {h / 2} {w * 0.86} {h + 8}H{w + 8}Z", dark, op, 5)
	f.soft(f"M-8 {h + 8}V{h * 0.93}H{w + 8}V{h + 8}Z", dark, op, 3)


def flipped(f):
	"""Everything drawn inside is mirrored left to right: paint the +X side once, get the -X side from it."""

	class _Ctx:
		def __enter__(self):
			f.out.append(f'<g transform="translate({f.w} 0) scale(-1 1)">')
			return f

		def __exit__(self, *_):
			f.out.append("</g>")

	return _Ctx()


def clipped(f, d, key):
	class _Ctx:
		def __enter__(self):
			f.out.append(f'<clipPath id="k{f.name}{key}"><path d="{d}"/></clipPath><g clip-path="url(#k{f.name}{key})">')
			return f

		def __exit__(self, *_):
			f.out.append("</g>")

	return _Ctx()


def swirl_button(f, cx, cy, r=9, gold="#d9a93a"):
	"""The school's gold spiral button."""
	f.path(f"M{cx - r} {cy + 1.2}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z", "#000000", opacity=0.45, blur=1)
	f.path(f"M{cx - r} {cy}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z", gold, stroke=INK, sw=1.3)
	f.path(f"M{cx - r * 0.8} {cy - r * 0.15}a{r * 0.8} {r * 0.7} 0 0 1 {r * 1.6} 0Z", "#ffe9a0", opacity=0.55)
	f.path(swirl_d(cx, cy, r * 0.78, turns=2.2, a0=0.6), stroke="#4a2f08", sw=max(1.0, r * 0.15))


# ---- 2D: face


def head_front(f, skin, hair_shadow=38, jaw_y=86, chin_y=125, chin_w=20):
	"""Skin, hair shadow, cheek modelling and a drawn V jaw: everything under it is neck shadow, so the block reads sharp."""
	w = f.w
	dark = shade(skin, 0.72)
	deep = shade(skin, 0.5)
	f.fill(skin)
	f.soft(f"M-5-5H{w + 5}V{hair_shadow}Q{w / 2} {hair_shadow + 12} -5 {hair_shadow}Z", dark, 0.9, 2)
	f.soft(f"M{w + 5} 30H{w - 15}Q{w - 11} 70 {w - 26} {jaw_y + 8}H{w + 5}Z", dark, 0.85, 3)
	f.soft(f"M-5 30H15Q11 70 26 {jaw_y + 8}H-5Z", dark, 0.55, 3)
	# neck shadow under the jaw
	cl, cr = w / 2 - chin_w, w / 2 + chin_w
	f.path(f"M-5 {jaw_y}L8 {jaw_y}Q18 {chin_y - 12} {cl} {chin_y}L{cr} {chin_y}Q{w - 18} {chin_y - 12} {w - 8} {jaw_y}L{w + 5} {jaw_y}V{w + 5}H-5Z", deep)
	f.taper(7, jaw_y - 8, 16, chin_y - 14, cl - 1, chin_y + 0.5, 1.5)
	f.taper(w - 7, jaw_y - 8, w - 16, chin_y - 14, cr + 1, chin_y + 0.5, 1.5)
	f.taper(cl - 1, chin_y + 0.5, w / 2, chin_y + 2.5, cr + 1, chin_y + 0.5, 1.2)
	f.soft(f"M{w / 2 - 12} {chin_y - 5}Q{w / 2} {chin_y - 9} {w / 2 + 12} {chin_y - 5}V{chin_y}H{w / 2 - 12}Z", dark, 0.55, 1)


def nose(f, skin, y=76, h=14):
	dark = shade(skin, 0.68)
	f.path(f"M67 {y}L70 {y + h - 2}L63 {y + h}Q66 {y + h - 5} 67 {y}Z", dark, opacity=0.85)
	f.taper(62, y + h, 66, y + h + 2, 71, y + h - 1, 0.8, shade(skin, 0.4))


def eye2(f, cx, cy, sgn, w, h, iris, tilt=3.0, r=None, look=0.0, lid=0.0, lash=INK, lash_t=2.6, flick=2.5, pupil=0.48, sclera="#f4efe8", crease_line=True, slit=False):
	"""One inked eye clipped by its lids. sgn +1 = on the viewer's right. lid 0..1 closes the upper lid over the iris."""
	ix, iy = cx - sgn * w / 2, cy + tilt
	ox, oy = cx + sgn * w / 2, cy - tilt
	tx, ty = cx - sgn * w * 0.08, cy - h * (1.05 - lid * 0.7)
	bx, by = cx + sgn * w * 0.12, cy + h * 0.85
	shape = f"M{ix} {iy}Q{tx} {ty} {ox} {oy}Q{bx} {by} {ix} {iy}Z"
	r = r or h * 0.72
	gx = cx + look
	key = f"{int(cx)}"
	with clipped(f, shape, key):
		f.path(shape, sclera)
		f.path(f"M{gx - r} {cy}a{r} {r * 1.08} 0 1 0 {2 * r} 0a{r} {r * 1.08} 0 1 0 {-2 * r} 0Z", shade(iris, 0.8), stroke=shade(iris, 0.3), sw=0.9)
		f.path(f"M{gx - r * 0.74} {cy + r * 0.4}a{r * 0.74} {r * 0.52} 0 0 0 {1.48 * r} 0Z", shade(iris, 1.55), opacity=0.9)
		f.path(f"M{gx - r} {cy - r * 0.2}a{r} {r * 0.9} 0 0 1 {2 * r} 0Z", shade(iris, 0.35), opacity=0.9)
		p = r * pupil
		if slit:
			f.path(f"M{gx} {cy - r}Q{gx + p * 0.7} {cy} {gx} {cy + r}Q{gx - p * 0.7} {cy} {gx} {cy - r}Z", "#0a0406")
		else:
			f.path(f"M{gx - p} {cy}a{p} {p * 1.08} 0 1 0 {2 * p} 0a{p} {p * 1.08} 0 1 0 {-2 * p} 0Z", "#07060b")
		f.path(f"M{gx - sgn * r * 0.35 - 1.2} {cy - r * 0.34}a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0Z", "#ffffff")
		f.path(f"M{ix} {iy}Q{tx} {ty} {ox} {oy}V{oy + h * 0.45}Q{tx} {ty + h * 0.55} {ix} {iy}Z", "#1a1a30", opacity=0.3)
	# upper lash: a heavy wedge with a flick past the outer corner
	f.path(f"M{ix - sgn * 0.8} {iy + 0.6}Q{tx} {ty - lash_t} {ox + sgn * flick} {oy - flick * 0.45}Q{tx} {ty + lash_t * 0.5} {ix - sgn * 0.8} {iy + 0.6}Z", lash)
	f.path(f"M{ox + sgn * flick} {oy - flick * 0.45}L{ox - sgn * 1} {oy + h * 0.28}L{ox - sgn * 2.8} {oy + 0.5}Z", lash)
	# lower lid
	f.taper(cx - sgn * w * 0.05, cy + h * 0.5, bx, by + 0.3, ox - sgn * 0.5, oy + h * 0.25, 0.7, lash)
	if crease_line:
		f.taper(ix + sgn * w * 0.2, iy - h * 0.75, tx, ty - h * 0.5, ox - sgn * 0.5, oy - h * 0.45, 0.55, shade("#a06050", 0.8))


def brow2(f, cx, cy, sgn, w, thick, tilt, colour, arc=-2.0):
	"""A tapered brow: blunt at the inner end, pointed at the outer. tilt > 0 = inner end low (angry)."""
	ix, iy = cx - sgn * w / 2, cy + tilt
	ox, oy = cx + sgn * w / 2, cy - tilt * 0.6
	mx, my = cx, cy + arc
	f.path(f"M{ix} {iy - thick * 0.5}Q{mx} {my - thick * 0.75} {ox} {oy}Q{mx} {my + thick * 0.55} {ix + sgn * 0.5} {iy + thick * 0.5}Z", colour, stroke=shade(colour, 0.6), sw=0.5)


def side_face(f, skin, ear_x=64, ear_y=60):
	"""Head side, front at the left: skin, jaw line and neck shadow, an inked ear. Hair is painted over by the caller."""
	w, h = f.w, f.h
	dark = shade(skin, 0.72)
	deep = shade(skin, 0.5)
	f.fill(skin)
	f.path(f"M{ear_x + 4} 92Q50 112 14 124L-5 126V{h + 5}H{w + 5}V92Z", deep)
	f.taper(ear_x + 4, 90, 44, 114, 6, 124, 1.4)
	f.soft(f"M{ear_x - 2} 60Q44 84 22 106L{ear_x + 6} 92Z", dark, 0.75, 3)
	f.soft("M-8 30H6V126H-8Z", dark, 0.5, 2)
	f.path(f"M{ear_x - 9} {ear_y - 8}q9 -9 18 0q2 11 -6 24q-5 4 -8 -2q-5 -11 -4 -22Z", skin, stroke=INK, sw=1.3)
	f.ink(f"M{ear_x - 4} {ear_y - 4}q5 -5 9 1q0 7 -4 12", 0.9, shade(skin, 0.5))


# ---- 2D: body


def hand(f, skin, key, top=178):
	"""A hanging fist below the sleeve, different per side: thumb in front, knuckles out, curled fingers in."""
	d = shade(skin, 0.68)
	line = shade(skin, 0.42)
	f.path(f"M-5 {top}H105V215H-5Z", skin)
	f.soft(f"M-5 {top}H105V{top + 8}H-5Z", d, 0.9, 2)
	if key == "F":  # thumb side: thumb laid across the curled fingers
		for x in (58, 74, 90):
			f.ink(f"M{x} {top + 6}Q{x + 2} {top + 16} {x} {top + 28}", 0.9, line)
		f.path(f"M18 {top + 3}Q42 {top + 2} 62 {top + 14}Q66 {top + 22} 56 {top + 22}Q34 {top + 22} 16 {top + 14}Z", shade(skin, 1.05), stroke=line, sw=1.0)
		f.soft(f"M84 {top}H105V215H84Z", d, 0.7, 3)
	elif key == "O":  # back of the hand: knuckle ridge
		for x in (26, 50, 74):
			f.taper(x, top + 14, x + 1, top + 20, x, 205, 0.9, line)
		f.ink(f"M12 {top + 13}Q50 {top + 8} 88 {top + 13}", 0.9, line)
		f.soft(f"M-5 {top + 14}H105V{top + 18}H-5Z", "#fff0e0", 0.45, 2)
	elif key == "I":  # curled fingers
		for x in (24, 46, 68):
			f.ink(f"M{x} {top + 6}Q{x + 2} {top + 15} {x + 1} {top + 24}", 1.0, line)
		f.ink(f"M12 {top + 6}Q50 {top + 2} 88 {top + 6}", 0.9, line)
	else:  # little finger edge
		f.taper(40, top + 6, 36, top + 16, 44, 205, 0.9, line)
		f.soft(f"M60 {top}H105V215H60Z", d, 0.6, 3)
	f.soft("M-5 200H105V215H-5Z", d, 0.8, 1)


def jacket_front(f, p, seed=0, hem=184, extra=()):
	"""Front of the dark jacket: shoulder and chest sheen, pull folds from the arm pits and waist, hem ripples."""
	f.fill(p["base"])
	f.soft("M14 20Q58 2 92 22Q92 70 56 82Q20 74 14 20Z", p["sheen"], 0.34, 8)
	f.soft("M186 20Q146 4 110 22Q110 66 146 78Q182 70 186 20Z", p["sheen"], 0.22, 8)
	f.soft(f"M24 110Q60 96 88 112Q84 150 50 {hem - 14}Q26 150 24 110Z", p["sheen"], 0.14, 8)
	f.soft(f"M-5 92Q100 128 205 92V{hem}H-5Z", p["dark"], 0.28, 8)
	creases(
		f,
		p,
		[
			(2, 30, 30, 44, 72, 84, 9),  # arm pit towards the navel
			(198, 32, 170, 46, 128, 88, 9),
			(4, 66, 26, 84, 58, 104, 6),
			(196, 70, 174, 86, 142, 106, 6),
			(48, 6, 56, 30, 46, 58, 5),  # hanging from the shoulder
			(152, 6, 146, 32, 156, 56, 5),
			(62, 104, 56, 136, 60, 168, 6),  # long drape over the belly
			(136, 106, 146, 138, 140, 170, 6),
			(4, 122, 26, 118, 46, 128, 5),  # waist pull
			(196, 126, 176, 120, 156, 132, 5),
			*extra,
		],
		seed,
	)
	# Fold ripples above the hem.
	for x in (24, 84, 118, 176):
		crease(f, x, hem - 22, x + 3, hem - 10, x - 2, hem, p, 4, 1.0)


def jacket_back(f, p, seed=0, hem=184):
	f.fill(p["base"])
	f.soft("M10 18Q60 0 96 16Q96 66 58 76Q18 68 10 18Z", p["sheen"], 0.3, 8)
	f.soft("M190 18Q140 0 104 16Q104 66 142 76Q182 68 190 18Z", p["sheen"], 0.2, 8)
	f.soft(f"M-5 104Q100 136 205 104V{hem}H-5Z", p["dark"], 0.22, 8)
	f.soft(f"M20 96Q58 86 88 100Q84 {hem - 34} 54 {hem - 10}Q24 {hem - 34} 20 96Z", p["sheen"], 0.22, 8)
	f.soft(f"M180 96Q142 86 112 100Q116 {hem - 34} 146 {hem - 10}Q176 {hem - 34} 180 96Z", p["sheen"], 0.14, 8)
	f.taper(-5, 40, 100, 58, 205, 40, 1.2)  # yoke seam
	f.taper(-5, 37.5, 100, 55, 205, 37.5, 0.8, p["lite"])
	f.taper(100, 52, 102, 120, 100, hem, 1.2)  # centre seam
	creases(
		f,
		p,
		[
			(4, 56, 34, 72, 84, 112, 8),  # shoulder blades towards the waist
			(196, 58, 166, 74, 116, 116, 8),
			(26, 104, 34, 134, 28, 166, 6),
			(174, 106, 166, 136, 172, 168, 6),
			(68, 132, 66, 150, 72, 172, 5),
			(132, 134, 136, 152, 128, 174, 5),
			(30, 12, 44, 22, 62, 32, 4),
			(170, 12, 156, 22, 138, 32, 4),
		],
		seed,
	)
	for x in (50, 150):
		crease(f, x, hem - 20, x - 3, hem - 10, x + 2, hem, p, 4, 1.0)


def jacket_side(f, p, seed=0, hem=184):
	f.fill(p["base"])
	f.soft("M10 8Q50 -4 90 8Q88 46 50 60Q14 48 10 8Z", p["sheen"], 0.3, 8)
	f.soft(f"M-5 110Q50 124 105 110V{hem}H-5Z", p["dark"], 0.28, 8)
	f.taper(50, -5, 54, 90, 49, hem, 1.2)
	f.taper(47.5, -5, 51.5, 90, 46.5, hem, 0.7, p["lite"])
	creases(f, p, [(4, 40, 28, 52, 48, 72, 6), (96, 46, 74, 58, 52, 80, 6), (6, 96, 28, 104, 48, 120, 7), (96, 100, 74, 110, 52, 126, 7), (6, 146, 26, 152, 46, 164, 5), (96, 150, 72, 156, 54, 168, 5)], seed)


def hem_line(f, p, hem, trouser):
	"""Jacket hem over the trousers."""
	f.path(f"M-5 {hem}H{f.w + 5}V{f.h + 5}H-5Z", trouser)
	f.soft(f"M-5 {hem}H{f.w + 5}V{hem + 10}H-5Z", "#000000", 0.6, 2)
	f.ink(f"M-5 {hem}Q{f.w / 2} {hem + 2} {f.w + 5} {hem}", 1.8)
	f.taper(-5, hem - 2.4, f.w / 2, hem - 0.8, f.w + 5, hem - 2.4, 0.7, p["lite"])


def sleeve(f, p, key, seed=0, cuff=154, skin=None, hand_top=168, cuff_button=None):
	"""A sleeve from shoulder to cuff, with a hand under it."""
	f.fill(p["base"])
	sx = {"F": 24, "B": 66, "O": 36, "I": 62}[key]
	f.soft(f"M{sx - 18} 8Q{sx} 2 {sx + 18} 8L{sx + 14} 90Q{sx} 96 {sx - 14} 90Z", p["sheen"], 0.36, 5)
	f.soft(f"M{sx - 12} 112L{sx + 12} 112L{sx + 10} 160L{sx - 10} 160Z", p["sheen"], 0.2, 5)
	f.taper(-5, 14, 50, 22, 105, 14, 0.9)  # sleeve cap seam
	f.taper(-5, 12, 50, 20, 105, 12, 0.6, p["lite"])
	creases(
		f,
		p,
		[
			(4, 66, 26, 84, 48, 98, 7),  # towards the elbow from above
			(96, 70, 76, 84, 56, 98, 7),
			(4, 128, 24, 114, 46, 106, 5),  # and from below
			(96, 124, 76, 112, 56, 104, 5),
			(30, 100, 50, 104, 70, 101, 4),
			(10, 24, 22, 34, 40, 42, 5),  # shoulder
			(92, 28, 78, 36, 64, 42, 4),
			(8, 150, 24, 146, 42, 150, 3),  # wrist
		],
		seed,
	)
	form(f)
	if skin:
		hand(f, skin, key, hand_top)
	f.path(f"M-5 {cuff}H105V{hand_top}H-5Z", shade(p["base"], 0.85))
	f.ink(f"M-5 {cuff}H105", 1.3)
	f.taper(-5, cuff + 2.2, 50, cuff + 2.8, 105, cuff + 2.2, 0.6, p["lite"])
	f.ink(f"M-5 {hand_top}H105", 1.8)
	if cuff_button and key == cuff_button:
		swirl_button(f, 50, (cuff + hand_top) / 2, 4.5)


def trouser(f, p, key, seed=0, shoe_top=168, knee=100):
	"""A trouser leg: pressed crease, knee and thigh folds, stacked break above the shoe."""
	f.fill(p["base"])
	sx = {"F": 34, "B": 64, "O": 38, "I": 62}[key]
	f.soft(f"M{sx - 15} 8L{sx + 15} 8L{sx + 12} 86L{sx - 12} 86Z", p["sheen"], 0.32, 5)
	f.soft(f"M{sx - 12} 118L{sx + 12} 118L{sx + 8} 158L{sx - 8} 158Z", p["sheen"], 0.2, 5)
	if key == "O":  # outseam
		f.taper(52, -5, 50, 90, 52, shoe_top, 1.0)
		f.taper(49.5, -5, 47.5, 90, 49.5, shoe_top, 0.5, p["lite"])
	elif key == "I":
		f.taper(50, -5, 52, 90, 50, shoe_top, 0.9)
	elif key == "F":
		f.taper(50, 6, 48, 80, 50, knee - 8, 0.5, p["lite"])
	creases(
		f,
		p,
		[
			(96, 6, 76, 22, 48, 32, 6),  # pull from the hip
			(4, 62, 24, 78, 44, 94, 6),  # towards the knee from above
			(96, 66, 78, 80, 58, 94, 6),
			(4, 122, 22, 110, 44, 104, 5),  # and from below
			(96, 118, 78, 110, 58, 102, 5),
			(32, 98, 50, 102, 68, 99, 4),
			(4, shoe_top - 20, 28, shoe_top - 12, 60, shoe_top - 14, 5),  # break above the shoe
			(96, shoe_top - 12, 70, shoe_top - 6, 40, shoe_top - 4, 4),
		],
		seed,
	)
	form(f)


def hair_ink(a, i, n, colour, count=26, gap=0.3, shine=1.4, root=None):
	"""Repaints one strand zone over paint_hair's even band: a smooth root-to-tip ramp with dark gaps and bright streaks."""
	f = a["Hair"]
	zone = f.w / n
	x0 = i * zone
	f.path(f"M{x0} -5H{x0 + zone}V96H{x0}Z", colour)
	f.path(f"M{x0} 96V52H{x0 + zone}V96Z", root or shade(colour, 0.7), opacity=0.8, blur=8)
	f.path(f"M{x0} -5H{x0 + zone}V22H{x0}Z", shade(colour, 1.15), opacity=0.7, blur=8)
	for k in range(count):
		x = x0 + (k + f.rng.uniform(0.2, 0.8)) * zone / count
		f.taper(x, f.rng.uniform(16, 44), x + f.rng.uniform(-4, 4), 60, x + f.rng.uniform(-2, 2), 91, 1.5, shade(colour, gap))
		if k % 3 == 0:
			f.taper(x + 4, f.rng.uniform(0, 8), x + 5, 22, x + 4, f.rng.uniform(34, 50), 1.5, shade(colour, shine))


# ---- 3D


def buried(locks, k=0.8, centre=(0, 0, 4.95)):
	"""Pulls every lock's root into the skull, so no flat root cap ever shows from behind or the side."""
	for l in locks:
		l["b"] = [centre[i] + (l["b"][i] - centre[i]) * k for i in range(3)]
	return locks


def sq(angle, a, b, p=4.0):
	"""A point on a rounded rectangle (superellipse) of half sizes a, b."""
	c, s = math.cos(angle), math.sin(angle)
	e = 2 / p
	return math.copysign(abs(c) ** e, c) * a, math.copysign(abs(s) ** e, s) * b


def loft(kit, part, name, colour, grid, closed_u=True, closed_v=False, smooth=False, root=None, tip=None):
	"""A quad mesh from grid[v][u] = (x, y, z). Open ends of a closed profile are capped."""
	import bmesh  # Blender only; the atlas step imports this module outside Blender

	bm = bmesh.new()
	rows = [[bm.verts.new(p) for p in row] for row in grid]
	nu, nv = len(rows[0]), len(rows)
	for v in range(nv if closed_v else nv - 1):
		for u in range(nu if closed_u else nu - 1):
			v2, u2 = (v + 1) % nv, (u + 1) % nu
			bm.faces.new((rows[v][u], rows[v][u2], rows[v2][u2], rows[v2][u]))
	if closed_v and not closed_u:
		bm.faces.new([rows[v][0] for v in range(nv)])
		bm.faces.new([rows[v][-1] for v in reversed(range(nv))])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = kit.bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	if smooth:
		for poly in mesh.polygons:
			poly.use_smooth = True
	o = kit._obj(name, mesh, colour, part)
	if root and tip:
		o["lock"] = (list(root), list(tip))
	return o


def collar(kit, part, name, colour, a, b, z0, height, thick=0.07, gap=0.28, n=28, lean=0.0):
	"""A standing collar open at the front. height(t) gives the top per position, t = 0 at the front opening, 1 at the back.
	lean widens the top."""
	grid = []
	for k in range(n + 1):
		u = k / n
		ang = -math.pi / 2 + gap + u * (2 * math.pi - 2 * gap)
		t = 1 - abs(2 * u - 1)
		top = z0 + height(t)
		ox, oy = sq(ang, a, b)
		ox2, oy2 = sq(ang, a + lean, b + lean)
		ix, iy = sq(ang, a - thick, b - thick)
		ix2, iy2 = sq(ang, a + lean - thick, b + lean - thick)
		grid.append([(ox, oy, z0), (ox2, oy2, top), (ix2, iy2, top), (ix, iy, z0)])
	# grid[u][profile] -> grid[v][u]
	grid = [list(row) for row in zip(*grid)]
	return loft(kit, part, name, colour, grid, closed_u=False, closed_v=True)
