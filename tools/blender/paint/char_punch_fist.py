# punch_fist "Bange": an old master: white hair in wild spikes swept up, thick white brows and moustache, a lined face, a dark long-sleeved top, pale loose trousers, kung-fu shoes.
from w2_kit import *  # noqa: F403

SKIN = "#e6bc96"
R = Ramps(skin=ramp(SKIN), hair=["#8a90a0", "#b8bec8", "#e2e6ec", "#ffffff"], top=["#1a1c28", "#2a2e3e", "#40455a", "#666c86"], sash=ramp("#8a90a4"), pant=["#6e6658", "#978e7c", "#c2b9a4", "#e6decc"], shoe=ramp("#1c1c22"), sole=ramp("#d8d2c4"))
DEFAULT = "#1b1d28"
HAIR = {"colour": "#E2E6EC", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R)
	crown(k, [(0.96, 5.34), (1.02, 5.56), (0.92, 5.8), (0.56, 5.98), (0.2, 6.02)])
	locks(k, "Up", [((0, -0.5, 5.7), (0, -0.8, 6.6), 0.34), ((-0.4, -0.46, 5.7), (-0.6, -0.74, 6.5), 0.34), ((0.4, -0.46, 5.7), (0.6, -0.74, 6.5), 0.34), ((0, 0, 5.86), (0, 0.1, 6.86), 0.42)], flat=0.7)
	locks(k, "Mane", [((0.5, 0, 5.8), (0.96, 0.1, 6.66), 0.4), ((0.8, 0.1, 5.6), (1.56, 0.2, 6.16), 0.38), ((0.9, 0.1, 5.4), (1.66, 0.3, 5.5), 0.36), ((0.9, 0.3, 5.2), (1.5, 0.6, 4.86), 0.34), ((0.5, 0.6, 5.7), (0.9, 1.2, 6.3), 0.4), ((0.5, 0.7, 5.3), (0.8, 1.4, 5.3), 0.4), ((0.4, 0.7, 5.0), (0.6, 1.2, 4.5), 0.36)], mirror=True, flat=0.7)
	for s in (1, -1):
		gem(k, "Head", f"Brow{s}", (s * 0.18, -0.9, 5.06), (s * 0.98, -0.98, 5.28), 0.14, "hair", flat=0.5)
		gem(k, "Head", f"Must{s}", (s * 0.06, -0.94, 4.5), (s * 0.66, -1.0, 4.2), 0.15, "hair", flat=0.6)
		gem(k, "Head", f"Burn{s}", (s * 0.9, -0.3, 5.5), (s * 0.96, -0.42, 4.5), 0.24, "hair", flat=0.4, across=(0, 1, 0))
	back_hair(k)
	art_jacket(k)
	block(k, T, "Top", 0, 0, 4.0, 2.2, 1.08, 0.6, "top", ch=0.06, corner=0.14, sub=1, jit=0.015, mids=(3.1,))
	collar(k, "top", 4.18, 4.26, z0=3.86, rx=0.72, ry=0.66, a=0.6)
	block(k, T, "Seam", 0, -0.62, 3.96, 2.5, 0.04, 0.02, "sash", ch=0.01)
	for z in (3.7, 3.3, 2.9):
		block(k, T, f"Frog{z}", 0, -0.64, z + 0.05, z - 0.05, 0.24, 0.03, "sash", ch=0.02)
	block(k, T, "Sash", 0, 0, 2.52, 2.2, 1.12, 0.64, "sash", ch=0.05)
	back_panel(k, "top", "sash")
	for s in (1, -1):
		prism(k, T, f"Fold{s}", [(s * 0.3, 3.7), (s * 0.94, 3.5), (s * 0.8, 2.8), (s * 0.5, 2.6)], -0.66, -0.58, "top", a=0.62)
	arms(k, [("Sleeve", 4.0, 2.5, 0.54, "top"), ("Roll", 2.72, 2.44, 0.58, "top"), ("Hand", 2.52, 1.76, 0.5, "skin")])
	legs(k, [("Thigh", 2.02, 0.5, 0.5, "pant"), ("Bag", 1.2, 0.52, 0.56, "pant"), ("Ankle", 0.6, 0.36, 0.46, "pant")], shoe=(0.4, "shoe", "sole"))
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, ("#2a3240", "#546074", "#98a4b8"), None, up=8, dn=6, inner=4, outer=-4, lid=0.3, mouth="flat", ir=(8, 8))
	for s in (1, -1):
		x = 65 + s * 28
		f.path(f"M{x - s * 12} 80Q{x} 85 {x + s * 14} 78", stroke="#a87c58", sw=1.5)
		f.path(f"M{65 + s * 14} 88Q{65 + s * 26} 98 {65 + s * 27} 112", stroke="#a87c58", sw=1.6)
		f.path(f"M{x + s * 16} 68L{x + s * 24} 64M{x + s * 16} 72L{x + s * 24} 74", stroke="#a87c58", sw=1.2)
	f.path("M46 34Q65 30 84 34", stroke="#a87c58", sw=1.3)
	base(a, SKIN, "#2a2e3e", "#2a2e3e", "#c2b9a4", SKIN, hair="#b8bec8")
