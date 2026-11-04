# Painted texture atlas (docs/CHARACTER_GACHA_SPEC.md "Painted textures"). A character's paint script draws each body
# face in stud/100 units (a torso front is 200 x 200, origin top-left); this writes the SVG and rasterises it with
# headless Chrome: python3 tools/blender/paint/atlas.py <id> -> assets/characters_avatar/<id>/atlas.{svg,png}
import importlib
import math
import os
import random
import subprocess
import sys
import tempfile

SIZE = 1024
STRIP_TOP = 896  # the bottom rows hold the flat colour swatches of hair and props (avatar_merge fills them)
INK = "#14101a"
# name: (x, y, px width, px height, unit width, unit height)
FACES = {
	"Head_F": (0, 0, 300, 300, 130, 130),
	"Torso_F": (300, 0, 256, 256, 200, 200),
	"Torso_B": (556, 0, 256, 256, 200, 200),
	"Torso_L": (812, 0, 106, 212, 100, 200),
	"Torso_R": (918, 0, 106, 212, 100, 200),
	"Head_B": (880, 300, 144, 144, 130, 130),
	"Head_L": (880, 444, 72, 78, 120, 130),
	"Head_R": (952, 444, 72, 78, 120, 130),
	"Head_T": (880, 525, 78, 72, 130, 120),
	"Head_Bo": (958, 525, 66, 60, 130, 120),
	"Torso_T": (880, 600, 120, 60, 200, 100),
	"Torso_Bo": (880, 660, 120, 60, 200, 100),
}
FACES["Hair"] = (0, 805, 1024, 91, 1024, 91)  # painted strands, one zone per HAIR_COLOURS entry (paint_hair)
for i, side in enumerate(("Left", "Right")):
	for j, f in enumerate(("F", "B", "O", "I")):
		FACES[f"{side}Arm_{f}"] = (i * 440 + j * 110, 300, 110, 225, 100, 205)
		FACES[f"{side}Leg_{f}"] = (i * 440 + j * 110, 525, 110, 220, 100, 200)
	FACES[f"{side}Arm_T"] = (i * 240, 745, 60, 60, 100, 100)
	FACES[f"{side}Arm_Bo"] = (i * 240 + 60, 745, 60, 60, 100, 100)
	FACES[f"{side}Leg_T"] = (i * 240 + 120, 745, 60, 60, 100, 100)
	FACES[f"{side}Leg_Bo"] = (i * 240 + 180, 745, 60, 60, 100, 100)


def shade(hexcol, k):
	h = hexcol.lstrip("#")
	return "#%02x%02x%02x" % tuple(max(0, min(255, int(int(h[i : i + 2], 16) * k))) for i in (0, 2, 4))


class Face:
	"""One clipped body face. All coordinates are stud/100 units."""

	def __init__(self, name):
		self.name = name
		self.w, self.h = FACES[name][4:6]
		self.out = []
		self.rng = random.Random(name)

	def fill(self, colour):
		return self.path(f"M-5-5H{self.w + 5}V{self.h + 5}H-5Z", colour)

	def path(self, d, fill="none", stroke=None, sw=1.2, opacity=None, blur=None):
		a = f'd="{d}" fill="{fill}"'
		if stroke:
			a += f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"'
		if opacity is not None:
			a += f' opacity="{opacity}"'
		if blur:
			a += f' filter="url(#b{blur})"'
		self.out.append(f"<path {a}/>")
		return self

	def ink(self, d, sw=1.2, colour=INK):
		return self.path(d, stroke=colour, sw=sw)

	def soft(self, d, colour="#000000", opacity=0.3, blur=3):
		"""Airbrushed shadow or light."""
		return self.path(d, colour, opacity=opacity, blur=blur)

	def edges(self, opacity=0.26):
		"""Cel shadow down the right side and along the bottom, softer on the left: the block reads as lit."""
		w, h = self.w, self.h
		self.path(f"M{w + 5}-5H{w * 0.84}C{w * 0.9} {h * 0.25} {w * 0.8} {h * 0.55} {w * 0.86} {h + 5}H{w + 5}Z", "#120a20", opacity=opacity, blur=1)
		self.path(f"M-5-5H{w * 0.07}C{w * 0.1} {h * 0.4} {w * 0.05} {h * 0.7} {w * 0.08} {h + 5}H-5Z", "#120a20", opacity=opacity * 0.6, blur=1)
		return self.path(f"M-5 {h + 5}V{h * 0.93}Q{w * 0.5} {h * 0.97} {w + 5} {h * 0.93}V{h + 5}Z", "#120a20", opacity=opacity, blur=1)

	def taper(self, x0, y0, cx, cy, x1, y1, width=1.6, colour=INK):
		"""A hand-inked line: pointed at both ends, thick in the middle."""
		return self.path(f"M{x0:.1f} {y0:.1f}Q{cx:.1f} {cy - width:.1f} {x1:.1f} {y1:.1f}Q{cx:.1f} {cy + width:.1f} {x0:.1f} {y0:.1f}Z", colour)

	def folds(self, n, dark, light=None, y0=0.0, y1=1.0, pinch=None, width=1.7):
		"""Cloth folds pulled towards a pinch point (waist, elbow, knee): a broad painted shadow, an inked edge and a
		lit edge. Evenly spread along both sides, seeded by the face name."""
		r = self.rng
		w, h = self.w, self.h
		px, py = pinch or (w / 2, h * (y0 + y1) / 2)
		for i in range(n):
			side = -1 if i % 2 == 0 else 1
			x0 = px + side * r.uniform(0.3, 0.46) * w
			t = (i // 2 + r.uniform(0.2, 0.8)) / max(1, (n + 1) // 2)
			y = h * (y0 + (y1 - y0) * t)
			k = r.uniform(0.25, 0.5)  # how far it runs towards the pinch
			x1 = x0 + (px - x0) * (1 - k * 0.5)
			yb = y + (py - y) * (1 - k)
			cx = (x0 + x1) / 2
			cy = (y + yb) / 2 + r.uniform(2, 6)
			fat = r.uniform(6, 11)
			self.path(f"M{x0:.1f} {y:.1f}Q{cx:.1f} {cy:.1f} {x1:.1f} {yb:.1f}Q{cx:.1f} {cy + fat:.1f} {x0:.1f} {y + fat * 0.5:.1f}Z", dark, opacity=0.8)
			self.taper(x0, y, cx, cy, x1, yb, width)
			if light:
				self.taper(x0, y - 3, cx, cy - 3.5, x1, yb - 3, width * 0.7, light)
		return self


class Atlas:
	def __init__(self):
		self.faces = {n: Face(n) for n in FACES}

	def __getitem__(self, name):
		return self.faces[name]

	def svg(self, default):
		defs = "".join(f'<filter id="b{b}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="{b}"/></filter>' for b in (1, 2, 3, 5, 8))
		parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}"><defs>{defs}</defs>', f'<rect width="{SIZE}" height="{SIZE}" fill="{default}"/>']
		for n, (x, y, pw, ph, uw, uh) in FACES.items():
			parts.append(f'<clipPath id="c{n}"><rect x="{x}" y="{y}" width="{pw}" height="{ph}"/></clipPath>')
			parts.append(f'<g clip-path="url(#c{n})"><g transform="translate({x} {y}) scale({pw / uw:.5f} {ph / uh:.5f})">')
			parts.append(f'<rect x="-5" y="-5" width="{uw + 10}" height="{uh + 10}" fill="{default}"/>')
			parts.extend(self.faces[n].out)
			parts.append("</g></g>")
		parts.append("</svg>")
		return "\n".join(parts)


CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def render(cid):
	here = os.path.dirname(os.path.abspath(__file__))
	sys.path.insert(0, here)
	mod = importlib.import_module("char_" + cid)
	atlas = Atlas()
	mod.paint(atlas)
	out = os.path.join(here, "..", "..", "..", "assets", "characters_avatar", cid)
	os.makedirs(out, exist_ok=True)
	svg_path = os.path.abspath(os.path.join(out, "atlas.svg"))
	png_path = os.path.abspath(os.path.join(out, "atlas.png"))
	with open(svg_path, "w") as f:
		f.write(atlas.svg(mod.DEFAULT))
	with tempfile.TemporaryDirectory() as tmp:
		html = os.path.join(tmp, "a.html")
		with open(html, "w") as f:
			f.write('<!doctype html><html><body style="margin:0;background:#000">' + atlas.svg(mod.DEFAULT) + "</body></html>")
		subprocess.run(
			[CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={tmp}/p", "--force-device-scale-factor=1", f"--window-size={SIZE},{SIZE}", f"--screenshot={png_path}", "file://" + html],
			check=True,
			capture_output=True,
			timeout=120,
		)
	print("ATLAS", png_path)


# ---- shared drawing: the anime face, keeps all three in one hand


def eye(f, cx, cy, sgn, iris, w=19, h=12, slant=2.5, lash=INK):
	"""One sharp anime eye. sgn +1 = eye on the viewer's right."""
	inner, outer = cx - sgn * w / 2, cx + sgn * w / 2
	top = cy - h * 0.55
	bot = cy + h * 0.5
	f.path(f"M{inner} {cy + 1}Q{cx - sgn * w * 0.15} {top - 1} {outer} {top + slant * -0.4}Q{outer + sgn * 1.5} {cy} {cx + sgn * w * 0.25} {bot}Q{cx - sgn * w * 0.2} {bot + 1} {inner} {cy + 1}Z", "#fbf8f4")
	f.path(f"M{inner} {cy + 1}Q{cx} {top - 2} {outer} {top}L{outer} {top + 3}Q{cx} {top + 2} {inner} {cy + 2}Z", "#000000", opacity=0.18)
	r = h * 0.56
	ix = cx - sgn * 0.8
	f.path(f"M{ix - r} {cy}a{r} {r * 1.1} 0 1 0 {2 * r} 0a{r} {r * 1.1} 0 1 0 {-2 * r} 0Z", iris)
	f.path(f"M{ix - r} {cy - 2}a{r} {r * 0.75} 0 0 1 {2 * r} 0Z", shade(iris, 0.45))
	f.path(f"M{ix - r * 0.75} {cy + r * 0.5}a{r * 0.75} {r * 0.45} 0 0 0 {1.5 * r} 0Z", shade(iris, 1.5), opacity=0.8)
	p = r * 0.5
	f.path(f"M{ix - p} {cy}a{p} {p * 1.1} 0 1 0 {2 * p} 0a{p} {p * 1.1} 0 1 0 {-2 * p} 0Z", "#0c0a10")
	f.path(f"M{ix - sgn * r * 0.4 - 1.4} {cy - r * 0.4}a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0 -2.8 0Z", "#ffffff")
	# heavy upper lash line with a flick, thin lower line
	f.path(f"M{inner - sgn} {cy + 2}Q{cx - sgn * w * 0.1} {top - 3.6} {outer + sgn * 1.6} {top - 0.4}L{outer} {top + 2}Q{cx} {top + 0.8} {inner - sgn} {cy + 2}Z", lash)
	f.ink(f"M{cx - sgn * w * 0.2} {bot + 0.8}Q{cx + sgn * w * 0.15} {bot + 1} {outer - sgn * 1.5} {cy + 2.5}", 0.7, shade(lash, 1.0))


def brow(f, cx, cy, sgn, colour, angry=3.5, w=23, thick=4.6):
	inner, outer = cx - sgn * w / 2, cx + sgn * w / 2
	f.path(f"M{inner} {cy + angry}Q{cx} {cy - thick * 0.6} {outer} {cy - angry * 0.4}Q{cx} {cy + thick * 0.45} {inner + sgn * 1} {cy + angry + thick * 0.55}Z", colour)


def face_base(f, skin, shadow_top=46):
	"""Skin with hair shadow on the forehead, cheek and jaw modelling, nose."""
	w = f.w
	f.fill(skin)
	dark = shade(skin, 0.72)
	f.path(f"M-5-5H{w + 5}V{shadow_top - 6}L{w - 16} {shadow_top - 2}L{w - 30} {shadow_top - 9}L{w - 48} {shadow_top}L{w / 2} {shadow_top - 8}L46 {shadow_top + 1}L28 {shadow_top - 8}L14 {shadow_top - 1}L-5 {shadow_top - 6}Z", dark, opacity=0.95, blur=1)
	f.soft(f"M-5 40H12Q7 90 26 135H-5Z", dark, 0.75, 3)
	f.soft(f"M{w + 5} 40H{w - 12}Q{w - 7} 90 {w - 26} 135H{w + 5}Z", dark, 0.95, 3)
	f.soft(f"M30 133Q65 118 100 133V136H30Z", dark, 0.85, 2)
	f.path("M66 76L62 85L67 86Z", dark, opacity=0.7)
	f.ink("M61 86Q64 88 68 86", 0.9, shade(skin, 0.42))


def side_head(f, skin, hair, ear_side):
	"""A head side: hair to the jaw, an inked ear, skin below."""
	w, h = f.w, f.h
	f.fill(skin)
	f.soft(f"M-5 {h + 5}V{h * 0.72}Q{w / 2} {h * 0.84} {w + 5} {h * 0.72}V{h + 5}Z", shade(skin, 0.62), 0.9, 2)
	back = w * 0.45 if ear_side > 0 else w * 0.55
	if ear_side > 0:
		f.path(f"M{back} -5H{w + 5}V{h * 0.86}Q{back + 25} {h * 0.75} {back} {h * 0.45}Z", hair)
		f.path(f"M-5 -5H{w + 5}V{h * 0.26}Q{w / 2} {h * 0.34} -5 {h * 0.22}Z", hair)
		ex = back - 2
	else:
		f.path(f"M{back} -5H-5V{h * 0.86}Q{back - 25} {h * 0.75} {back} {h * 0.45}Z", hair)
		f.path(f"M-5 -5H{w + 5}V{h * 0.22}Q{w / 2} {h * 0.34} -5 {h * 0.26}Z", hair)
		ex = back + 2
	f.path(f"M{ex - 9} {h * 0.42}q9 -11 18 0q2 11 -6 22q-5 4 -8 -2q-5 -10 -4 -20Z", skin, stroke=INK, sw=1.4)
	f.ink(f"M{ex - 4} {h * 0.45}q5 -5 9 1q0 7 -4 12", 1.0, shade(skin, 0.5))


def paint_hair(a, colours):
	"""Fills the Hair strip: one zone per colour, root at the bottom, tip at the top. Dark roots, a lit band and inked
	strands. Colours are the hex strings of the locks that should use it (HAIR_COLOURS)."""
	f = a["Hair"]
	zone = f.w / len(colours)
	for i, hexcol in enumerate(colours):
		x0 = i * zone
		f.path(f"M{x0} -5H{x0 + zone}V96H{x0}Z", hexcol)
		f.path(f"M{x0} 96V62Q{x0 + zone / 2} 54 {x0 + zone} 62V96Z", shade(hexcol, 0.55), opacity=0.9, blur=2)
		f.path(f"M{x0} 46Q{x0 + zone / 2} 26 {x0 + zone} 46V24Q{x0 + zone / 2} 10 {x0} 24Z", shade(hexcol, 1.35), opacity=0.8, blur=1)
		n = max(6, int(zone / 14))
		for k in range(n):
			x = x0 + (k + f.rng.uniform(0.2, 0.8)) * zone / n
			f.taper(x, f.rng.uniform(0, 30), x + f.rng.uniform(-5, 5), 50, x + f.rng.uniform(-3, 3), 91, 1.2, shade(hexcol, 0.35))


def swirl_d(cx, cy, r, turns=2.3, n=40, a0=0.0):
	pts = []
	for i in range(n + 1):
		t = i / n
		a = a0 + t * turns * 2 * math.pi
		q = r * (0.1 + 0.9 * t)
		pts.append(f"{'M' if i == 0 else 'L'}{cx + q * math.cos(a):.2f} {cy + q * math.sin(a):.2f}")
	return "".join(pts)


if __name__ == "__main__":
	for cid in sys.argv[1:]:
		render(cid)
