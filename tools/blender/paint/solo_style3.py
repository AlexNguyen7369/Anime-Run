# Target look kit for the solo_ series (design doc section 5): the shared jk_style3 and ds_style3 solids plus what these hunters
# wear: a body-art jacket, a suit front, boots, a long split coat. Hair and faces stay in each char_<id>.py. bpy stays lazy: atlas.py runs this under python3.
from ds_style3 import block as rblock  # noqa: F401  takes rot
from ds_style3 import gem  # noqa: F401  the version with a tip ramp
from jk_style3 import block, collar, dress_shoe, ears, head_rest, prism, slab, sleeve, stroke, trouser  # noqa: F401
from style2 import Kit, Ramps  # noqa: F401
from style3 import big_head, finish  # noqa: F401

T = "UpperTorso"


def art_jacket(k, hem=1.86, hw=1.06, hd=0.57):
	"""The torso's own painted art on a block shell, so folds, seams and stripes come from the atlas."""
	k.reshape(T, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.05, 0.95, 0.45)], corner=0.1, nc=1)
	k.tube(T, "Jacket", [(0, 0, 4.0, hw - 0.08, hd - 0.07), (0, 0, 3.92, hw, hd), (0, 0, 3.4, hw, hd), (0, 0, 2.6, hw - 0.01, hd), (0, 0, hem + 0.1, hw + 0.02, hd + 0.02), (0, 0, hem, hw + 0.04, hd + 0.04)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)


def suit_front(k, shirt, tie, lapel, y=-0.6, top=4.0, low=2.96, wide=0.76, knot=True):
	"""Shirt V, tie and two raised lapels, the jacket's front opening. y is the jacket's surface."""
	prism(k, T, "ShirtV", [(-wide + 0.08, top), (wide - 0.08, top), (0, low)], y - 0.01, y + 0.04, shirt, a=0.6, b=0.3)
	if tie:
		prism(k, T, "Tie", [(-0.09, top - 0.26), (0.09, top - 0.26), (0.12, low + 0.34), (0, low + 0.1), (-0.12, low + 0.34)], y - 0.03, y + 0.01, tie, a=0.5, b=0.4)
		if knot:
			prism(k, T, "TieKnot", [(-0.13, top - 0.04), (0.13, top - 0.04), (0.09, top - 0.3), (-0.09, top - 0.3)], y - 0.045, y + 0.01, tie, a=0.58, b=0.4)
	for s in (1, -1):
		prism(k, T, f"Lapel{s}", [(s * (wide - 0.1), top), (s * (wide + 0.14), top), (s * (wide + 0.18), top - 0.42), (s * 0.34, low + 0.02), (s * 0.03, low - 0.02)], y - 0.045, y + 0.02, lapel, a=0.54, b=0.46)


def boot(k, leg, px, ramp, sole, top=0.92, cuff=None):
	"""A chunky boot over the trouser: shaft, foot, toe and a thick sole."""
	block(k, leg, "Shaft", px, 0, top, 0.14, 0.53, 0.59, ramp, ch=0.05, corner=0.18, jit=0.012, mids=(0.5,), a=0.5, b=0.56)
	block(k, leg, "Foot", px, -0.34, 0.44, 0.13, 0.5, 0.44, ramp, ch=0.08, corner=0.24, a=0.54, b=0.56)
	block(k, leg, "Sole", px, -0.14, 0.15, 0.0, 0.55, 0.72, sole, ch=0.03, a=0.52)
	if cuff:
		block(k, leg, "BootCuff", px, 0, top + 0.05, top - 0.12, 0.56, 0.62, cuff, ch=0.03, corner=0.18, a=0.5, b=0.5)


def long_coat(k, ramp, lining, hem=0.7, gap=0.2):
	"""A long coat split at the front below the waist. Each panel rides a leg and stays at z <= 2; the lining faces inward at the split."""
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		w = 0.5 - gap / 2
		cx = s * (gap + w)
		block(k, leg, "CoatF", cx, -0.68, 2.0, hem, w, 0.06, ramp, ch=0.02, flare=0.05, a=0.46, b=0.56, g=0.1)
		block(k, leg, "CoatInner", s * (gap + 0.04), -0.74, 2.0, hem + 0.02, 0.05, 0.03, lining, ch=0.01, a=0.6, b=0.4)
		block(k, leg, "CoatS", s * 1.14, 0, 2.0, hem, 0.06, 0.74, ramp, ch=0.02, flare=0.05, a=0.46, b=0.56, g=0.1)
		block(k, leg, "CoatB", s * 0.56, 0.68, 2.0, hem, 0.63, 0.07, ramp, ch=0.02, flare=0.05, a=0.44, b=0.56, g=0.1)

