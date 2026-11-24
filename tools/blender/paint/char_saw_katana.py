# saw_katana "Katanah Man": a dark armoured head like a folded blade housing with a long sword out of the brow and toothed jaws, swords out of both forearms, a torn dark suit.
from w2_kit import *  # noqa: F403

SKIN = "#2c2a30"
R = Ramps(skin=ramp(SKIN), shell=["#1e1d26", "#34323e", "#52505e", "#84828e"], steel=["#7a828e", "#aab2bc", "#dae0e6", "#ffffff"], edge=["#a8b0bc", "#d0d6de", "#f2f5f8", "#ffffff"], tooth=["#a89c84", "#d0c6b0", "#f0eadc", "#ffffff"], red=ramp("#8a1a1c"), suit=["#181b26", "#2a2f3e", "#424a5c", "#6a7286"], shirt=ramp("#e4e4e8"), sole=ramp("#0e0e12"))
DEFAULT = "#191b22"
HAIR = {"colour": "#34323A", "locks": []}
PROPS = []


def _blade(k, part, name, grip, tip, w=0.16):
	from mathutils import Vector

	g, t = Vector(grip), Vector(tip)
	d = (t - g).normalized()
	u = d.cross(Vector((0, 1, 0))).normalized()
	pts = [g - u * w, g + u * w * 0.7, g + d * ((t - g).length * 0.84) + u * w * 0.7, t, g + d * ((t - g).length * 0.8) - u * w]
	prism(k, part, name, [(p.x, p.z) for p in pts], grip[1] - 0.05, grip[1] + 0.05, "steel", a=0.6, b=0.36)
	rim = [g - u * (w + 0.07), g - u * w, g + d * ((t - g).length * 0.8) - u * w, t, g + d * ((t - g).length * 0.8) - u * (w + 0.07)]
	prism(k, part, name + "Edge", [(p.x, p.z) for p in rim], grip[1] - 0.03, grip[1] + 0.03, "edge", a=0.7, b=0.2)


def model(parts, kit):
	k = start(kit, parts, R, ear=False)
	h = "Head"
	block(k, h, "Skull", 0, 0, 5.78, 4.7, 1.0, 0.94, "shell", ch=0.14, corner=0.26, sub=1)
	block(k, h, "Jaw", 0, -0.1, 4.46, 3.98, 0.86, 0.86, "shell", ch=0.1, corner=0.26, a=0.44)
	# a sloped visor over the jaw, its middle swelling into the collar the brow sword grows from
	gem(k, h, "Visor", (0, 0.3, 5.66), (0, -1.4, 5.1), 0.74, "shell", flat=0.5, across=(1, 0, 0), a=0.58)
	gem(k, h, "Collar", (0, -0.4, 5.3), (0, -1.5, 6.5), 0.46, "shell", flat=0.8, across=(1, 0, 0), a=0.6)
	for s in (1, -1):
		prism(k, h, f"VisorP{s}", [(s * 0.1, 5.5), (s * 1.0, 5.6), (s * 1.02, 5.28), (s * 0.2, 4.96)], -1.06, -0.84, "shell", a=0.62)
		gem(k, h, f"JawH{s}", (s * 0.96, 0.2, 4.7), (s * 0.5, -1.1, 4.06), 0.28, "shell", flat=0.6, across=(0, 0, 1), a=0.54)
	block(k, h, "Nape", 0, 0.7, 5.5, 4.2, 0.8, 0.34, "shell", ch=0.14, corner=0.3, mids=(4.8,), jit=0.03)
	# the long sword out of the brow, rising forward and up
	from mathutils import Vector
	b, t = Vector((0, -0.9, 5.62)), Vector((0, -2.1, 7.5))
	n = Vector((0, t.z - b.z, -(t.y - b.y))).normalized() * 0.2
	slab(k, "Brow", [(b.y + n.y, b.z + n.z), (b.y - n.y, b.z - n.z), (t.y * 0.9 + b.y * 0.1 - n.y, t.z * 0.9 + b.z * 0.1 - n.z), (t.y, t.z), (t.y * 0.8 + b.y * 0.2 + n.y, t.z * 0.8 + b.z * 0.2 + n.z)], -0.07, 0.07, "steel", a=0.64, b=0.3)
	for s in (1, -1):
		gem(k, h, f"Fin{s}", (s * 0.8, 0.1, 5.4), (s * 1.34, 0.9, 6.0), 0.32, "shell", flat=0.5, across=(0, 1, 0))
		gem(k, h, f"Cheek{s}", (s * 0.9, 0.1, 4.8), (s * 1.16, -0.72, 4.2), 0.24, "shell", across=(0, 1, 0))
		prism(k, h, f"Slit{s}", [(s * 0.2, 5.02), (s * 0.84, 5.24), (s * 0.84, 5.12), (s * 0.26, 4.94)], -1.1, -1.0, "red", a=0.7)
	for i in range(7):
		x = -0.66 + i * 0.22
		gem(k, h, f"TeethU{i}", (x, -0.9, 4.72), (x, -0.98, 4.42), 0.12, "tooth")
		gem(k, h, f"TeethL{i}", (x + 0.1, -0.92, 4.22), (x + 0.1, -0.98, 4.5), 0.1, "tooth")
	art_jacket(k)
	block(k, T, "Coat", 0, 0, 3.98, 1.9, 1.08, 0.6, "suit", ch=0.06, corner=0.14, sub=1, jit=0.015)
	prism(k, T, "Shirt", [(-0.4, 3.98), (0.4, 3.98), (0, 3.0)], -0.65, -0.58, "shirt")
	prism(k, T, "Tie", [(-0.1, 3.9), (0.1, 3.9), (0.12, 3.3), (0, 3.06), (-0.12, 3.3)], -0.69, -0.64, "red")
	for s in (1, -1):
		prism(k, T, f"Lapel{s}", [(s * 0.4, 4.0), (s * 0.7, 4.0), (s * 0.72, 3.5), (s * 0.04, 2.9)], -0.7, -0.6, "suit", a=0.66)
	back_panel(k, "suit")
	for s in (1, -1):
		block(k, T, f"Pocket{s}", s * 0.66, -0.64, 2.74, 2.64, 0.26, 0.03, "suit", ch=0.01, a=0.7)
		for i in range(3):
			gem(k, f"{'Left' if s > 0 else 'Right'}UpperArm", f"Tatter{i}", (s * 1.5 + (i - 1) * 0.34, -0.48, 2.86), (s * 1.5 + (i - 1) * 0.36, -0.58, 2.4), 0.16, "suit", flat=0.4)
	arms(k, [("Sleeve", 3.98, 2.9, 0.53, "suit"), ("Roll", 3.0, 2.76, 0.56, "suit"), ("Fore", 2.8, 2.1, 0.5, "shell"), ("Hand", 2.2, 1.76, 0.53, "shell")])
	for s, side in ((1, "Left"), (-1, "Right")):
		arm = f"{side}UpperArm"
		block(k, arm, "Tsuba", s * 1.5, -0.1, 2.02, 1.88, 0.6, 0.4, "steel", ch=0.04, corner=0.3)
		_blade(k, arm, "Sword", (s * 1.56, -0.3, 1.96), (s * 2.6, -0.3, -0.5))
	legs(k, [("Leg", 2.02, 0.3, 0.5, "suit")], shoe=(0.4, "suit", "sole"))
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.fill("#141318")
	base(a, SKIN, "#2a2f3e", "#2a2f3e", "#2a2f3e")
