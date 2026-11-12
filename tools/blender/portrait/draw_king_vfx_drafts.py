#!/usr/bin/env python3
# Design drafts for the owner (BOSS_EVENT_SPEC "Animation rework", "Gates portals and Ea's wind", owner 2026-11-12): nothing here
# ships until he picks. Writes
#   assets/ui/boss_king/portal_draft/portal_a.png, portal_b.png, portal_c.png  three Gates of Babylon portal decals, 512 x 512,
#       transparent, drawn in their own colours (the decal's Color3 stays white)
#   assets/ui/boss_king/portal_draft/portal_sheet.png  the current plain ring, then A, B and C at rest (1.25 x the current portal,
#       proposed) and as a 5-step opening strip, on the vault brown and on the sunset orange, with small sizes for a far runner
#   assets/ui/boss_king/wind_draft/ea_wind_strip.png  Ea's white wind: 8 frames of one swirl cycle (frame 8 leads back to 1),
#       early charge above, late charge below, with the proposed turn rates and Roblox build
# Look-only references (docs/char_evidence/boss_king.md "Owner reference clips" 1 to 3): nothing traced or copied; the rim patterns
# are plain wedges, dots, studs and rays (design doc 5).
# Same method and helpers as draw_mage_ui.py: numpy signed distances, supersampled, PNG through zlib, text through CoreText.
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_king_vfx_drafts.py
import os
import struct
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_mage_ui import GOLD, GOLD_HI, GOLD_LOW, INK, WHITE, canvas, circle, finish, from_rgba8, grid, over, polygon, rbox, resize, ring, stamp, text_image, text_masks, to_rgba8, write_png  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
PORTAL_DIR = os.path.join(ROOT, "assets", "ui", "boss_king", "portal_draft")
WIND_DIR = os.path.join(ROOT, "assets", "ui", "boss_king", "wind_draft")
CURRENT = os.path.join(ROOT, "assets", "characters_avatar", "boss_raga", "vfx", "Ring.png")  # Art.Ring, tinted GOLD in game today
CURRENT_TINT = (255, 196, 64)  # BossKingVfx GOLD
BRONZE, DEEP, WELL, CORE = (150, 86, 18), (84, 42, 10), (36, 17, 5), (255, 252, 236)
STEEL = (226, 222, 206)
VAULT, SKY_TOP, SKY_LOW = (52, 34, 22), (206, 92, 72), (255, 192, 104)
SANS, BOLD = "HelveticaNeue-Medium", "HelveticaNeue-Bold"
SS = 3  # supersampling of every drawing


def ramp(t, stops):
	"""Colour (0..255) per pixel from (t, rgb) stops, t rising."""
	ts = np.array([s[0] for s in stops], np.float32)
	cs = np.array([s[1] for s in stops], np.float32)
	return np.stack([np.interp(t, ts, cs[:, c]) for c in range(3)], axis=-1)


def glow(img, color, d, width, alpha=1.0):
	"""A soft light falling off from the shape d <= 0."""
	over(img, color, np.exp(-np.maximum(d, 0) / width), alpha)


def polar_cell(r, a, cells, phase=0.0):
	"""Local coordinates in each of `cells` equal angular cells: index, across (arc length), the cell's centre angle."""
	k = np.floor((a - phase) / (2 * np.pi) * cells)
	mid = (k + 0.5) / cells * 2 * np.pi + phase
	return k, r * np.sin(a - mid), r * np.cos(a - mid)


def core(img, x, y, r0, reach):
	"""The white-gold hot core every design shares: a solid heart, a gold halo, a small four-point glint."""
	r = np.hypot(x, y)
	glow(img, GOLD, r - r0, reach, 0.9)
	glow(img, GOLD_HI, r - r0, reach * 0.45)
	glint = np.minimum(np.hypot(x / (r0 * 3.2), y / (r0 * 0.35)), np.hypot(x / (r0 * 0.35), y / (r0 * 3.2))) - 1
	over(img, CORE, glint <= 0, 0.9)
	over(img, CORE, r <= r0)


# 1. Portal designs ---------------------------------------------------------------------------------------------------------------
def draw_a(size=512):
	"""A, thin and elegant: a one-arm spiral of fine ripples, a double hairline rim with beads, a few uneven needle rays."""
	x, y = grid(size, SS, 1.0)
	img = canvas(size * SS, size * SS)
	r, a = np.hypot(x, y), np.arctan2(y, x)
	R = 0.84
	# Rays first, under the rim: 9 needles at uneven angles and lengths (the asymmetry that shows a slow turn).
	rays = np.full(x.shape, np.inf, np.float32)
	for ang, length in ((-100, 0.15), (-62, 0.09), (-20, 0.12), (24, 0.07), (70, 0.13), (112, 0.08), (160, 0.11), (205, 0.07), (240, 0.1)):
		t = np.radians(ang)
		c, s = np.cos(t), np.sin(t)
		u, v = x * c + y * s - R, -x * s + y * c  # along the ray, across it
		rays = np.minimum(rays, np.maximum(np.abs(v) - 0.012 * np.clip(1 - u / length, 0, 1), np.abs(u - length / 2) - length / 2))
	over(img, INK, rays <= 0.012, 0.8)
	over(img, GOLD_HI, rays <= 0)
	# The well: dark at the rim, lighter toward the core, so it reads as a funnel; a dark rim outline holds it on the orange sky.
	over(img, INK, r <= R + 0.065, 0.85)
	over(img, ramp(r, [(0.0, GOLD_HI), (0.32, GOLD), (0.6, GOLD_LOW), (0.74, DEEP), (R, WELL)]), r <= R)
	# Spiral ripples: one arm, lines 0.085 apart, brighter toward the core and on the glinting side.
	pitch = 0.085
	ph = r / pitch + a / (2 * np.pi)
	d = np.abs(ph - np.round(ph)) * pitch - 0.0075 * (1.2 - r)
	lit = np.clip(1.25 - r * 0.8, 0.4, 1) * (0.7 + 0.3 * np.cos(a + 2.3))
	keep = (r > 0.11) & (r < R - 0.07)
	glow(img, GOLD, np.where(keep, d, 1), 0.012, 0.5)
	over(img, ramp(r, [(0.1, CORE), (0.45, CORE), (0.75, GOLD_HI)]), (d <= 0) & keep, lit)
	# Rim: a bright hairline, a fainter inner one, a ring of 36 beads between, and a brighter arc on the upper left.
	over(img, GOLD_HI, ring(x, y, 0, 0, R, 0.012) <= 0)
	over(img, GOLD, ring(x, y, 0, 0, R - 0.06, 0.006) <= 0)
	_, u, v = polar_cell(r, a, 36)
	over(img, GOLD_HI, np.hypot(u, v - (R - 0.03)) <= 0.011)
	arc = (ring(x, y, 0, 0, R, 0.02) <= 0) & (np.cos(a + 2.1) > 0.75)
	over(img, CORE, arc, 0.9)
	core(img, x, y, 0.055, 0.09)
	return img


def draw_b(size=512):
	"""B, bold and blocky: a thick bevelled rim with square notches and one keystone, a deep dark band, three fat ripples."""
	x, y = grid(size, SS, 1.0)
	img = canvas(size * SS, size * SS)
	r, a = np.hypot(x, y), np.arctan2(y, x)
	# The rim band 0.72 - 0.9, 10 square notches cut into its outer edge, a keystone block standing out on the upper right.
	band = np.abs(r - 0.81) - 0.09
	k, u, v = polar_cell(r, a, 10, phase=0.3)
	band = np.maximum(band, -rbox(u, v - 0.9, 0, 0, 0.06, 0.06))
	ka = np.radians(-58)
	ku, kv = x * np.cos(ka) + y * np.sin(ka), -x * np.sin(ka) + y * np.cos(ka)
	key = rbox(ku, kv, 0.86, 0, 0.11, 0.1, 0.015)
	rim = np.minimum(band, key)
	over(img, INK, rim <= 0.035)
	over(img, ramp(r, [(0.0, CORE), (0.3, GOLD_HI), (0.5, GOLD), (0.62, GOLD_LOW), (0.72, WELL)]), r <= 0.73)
	# The rim's bevel: lit from the upper left as the game's flat cel icons are.
	gy, gx = np.gradient(rim)
	facing = -(gx + gy) / np.maximum(np.hypot(gx, gy), 1e-9) / np.sqrt(2)
	edge = rim > -0.035
	rgb = np.where((edge & (facing > 0.1))[..., None], GOLD_HI, np.where((edge & (facing <= 0.1))[..., None], GOLD_LOW, GOLD))
	over(img, rgb.astype(np.float32), rim <= 0)
	# Studs between the notches, a gem in the keystone.
	_, su, sv = polar_cell(r, a, 10, phase=0.3 + np.pi / 10)
	stud = rbox(su, sv - 0.8, 0, 0, 0.032, 0.032, 0.006)
	over(img, DEEP, stud <= 0)
	over(img, GOLD_HI, rbox(su + 0.01, sv - 0.81, 0, 0, 0.014, 0.014) <= 0)
	over(img, DEEP, circle(ku, kv, 0.86, 0, 0.05) <= 0)
	over(img, (255, 90, 60), circle(ku, kv, 0.86, 0, 0.034) <= 0)
	over(img, CORE, circle(ku, kv, 0.85, -0.012, 0.011) <= 0)
	# The deep band just inside the rim, then three thick ripples, each a little off centre toward the lower right: a tunnel.
	over(img, WELL, np.abs(r - 0.665) - 0.05 <= 0, 0.85)
	for i, (rr, w, col) in enumerate(((0.52, 0.03, GOLD), (0.37, 0.032, GOLD_HI), (0.22, 0.034, CORE))):
		off = 0.035 * (3 - i) / 3
		d = ring(x, y, off * 0.8, off, rr, w)
		over(img, INK, d <= 0.018, 0.7)
		over(img, col, d <= 0)
	# The highlight crescent on the rim's upper left.
	over(img, CORE, (np.abs(r - 0.84) <= 0.018) & (np.cos(a + 2.2) > 0.82))
	core(img, x, y, 0.1, 0.1)
	return img


def draw_c(size=512):
	"""C, in between: a three-arm spiral of ripples, a mid rim with inward wedge notches and dots, a pinwheel of slanted rays."""
	x, y = grid(size, SS, 1.0)
	img = canvas(size * SS, size * SS)
	r, a = np.hypot(x, y), np.arctan2(y, x)
	R = 0.8
	# 12 rays, alternately long and short, slanted 14 degrees: the slant shows the way it turns.
	rays = np.full(x.shape, np.inf, np.float32)
	for i in range(12):
		t = 2 * np.pi * i / 12
		length = 0.15 if i % 2 else 0.09
		if i == 5:
			length = 0.19  # one long ray: the mark that shows a slow turn
		base = (np.cos(t) * (R + 0.04), np.sin(t) * (R + 0.04))
		tip_t = t + np.radians(14)
		tip = (np.cos(tip_t) * (R + 0.04 + length), np.sin(tip_t) * (R + 0.04 + length))
		half = 0.06 if i % 2 else 0.05
		left = (base[0] - np.sin(t) * half, base[1] + np.cos(t) * half)
		right = (base[0] + np.sin(t) * half, base[1] - np.cos(t) * half)
		rays = np.minimum(rays, polygon(x, y, [left, tip, right]))
	over(img, INK, rays <= 0.012, 0.85)
	over(img, GOLD, rays <= 0)
	over(img, GOLD_HI, (rays <= 0) & (rays > -0.012))
	# Well and dark band.
	over(img, INK, r <= R + 0.07, 0.9)
	over(img, ramp(r, [(0.0, GOLD_HI), (0.3, GOLD), (0.52, GOLD_LOW), (0.62, DEEP), (R - 0.06, WELL)]), r <= R)
	# Three spiral arms, 0.12 apart along a radius, thinning outward.
	pitch = 0.12
	ph = r / pitch - 3 * a / (2 * np.pi)
	d = np.abs(ph - np.round(ph)) * pitch - 0.017 * np.clip(1.1 - r, 0.3, 1)
	keep = (r > 0.12) & (r < R - 0.12)
	glow(img, GOLD, np.where(keep, d, 1), 0.015, 0.55)
	over(img, ramp(r, [(0.1, CORE), (0.4, CORE), (0.65, GOLD_HI)]), (d <= 0) & keep, np.clip(1.3 - r, 0.6, 1))
	# Rim band 0.7 - 0.8 with 16 wedge notches from the outer edge, a dark dot between each pair.
	band = np.abs(r - 0.75) - 0.05
	k, u, v = polar_cell(r, a, 16)
	notch = polygon(u, v, [(-0.035, 0.81), (0.035, 0.81), (0.0, 0.735)])
	band = np.maximum(band, -notch)
	over(img, GOLD, band <= 0)
	over(img, GOLD_HI, (band <= 0) & (r > 0.775))
	over(img, GOLD_LOW, (band <= 0) & (r < 0.715))
	_, du, dv = polar_cell(r, a, 16, phase=np.pi / 16)
	over(img, DEEP, np.hypot(du, dv - 0.75) <= 0.018)
	over(img, CORE, (np.abs(r - 0.78) <= 0.012) & (np.cos(a + 2.2) > 0.8))
	core(img, x, y, 0.075, 0.1)
	return img


def read_png(path):
	"""8-bit RGBA, no line filter: what vfxtex.py and write_png write."""
	with open(path, "rb") as f:
		data = f.read()
	pos, idat, head = 8, b"", None
	while pos < len(data):
		length, kind = struct.unpack(">I4s", data[pos : pos + 8])
		if kind == b"IHDR":
			head = struct.unpack(">IIBBBBB", data[pos + 8 : pos + 8 + length])
		elif kind == b"IDAT":
			idat += data[pos + 8 : pos + 8 + length]
		pos += 12 + length
	w, h, depth, colour = head[:4]
	assert (depth, colour) == (8, 6), path
	rows = np.frombuffer(zlib.decompress(idat), np.uint8).reshape(h, w * 4 + 1)
	assert not rows[:, 0].any(), path
	return rows[:, 1:].reshape(h, w, 4)


# The opening, in five steps, drawn at full resolution and shrunk ---------------------------------------------------------------
def step_dot(hi):
	n = hi.shape[0]
	x, y = grid(n // SS, SS, 1.0)
	img = canvas(n, n)
	core(img, x, y, 0.06, 0.08)
	return img


def step_small(hi):
	n = hi.shape[0]
	img = canvas(n, n)
	m = int(n * 0.42)
	stamp(img, resize(hi, m, m), (n - m) / 2, (n - m) / 2)
	x, y = grid(n // SS, SS, 1.0)
	core(img, x, y, 0.05, 0.06)
	return img


def step_tip(hi):
	"""A weapon's tip through the core, toward the viewer: a foreshortened blade, edge line and a bright ridge."""
	img = hi.copy()
	x, y = grid(hi.shape[0] // SS, SS, 1.0)
	blade = [(-0.46, 0.5), (0.06, -0.14), (0.14, 0.0), (0.0, 0.1)]
	d = polygon(x, y, blade)
	over(img, WELL, polygon(x - 0.03, y - 0.03, blade) <= 0, 0.5)  # its shadow on the portal
	over(img, INK, d <= 0.018)
	over(img, STEEL, d <= 0)
	ridge = polygon(x, y, [(-0.46, 0.5), (0.08, -0.07), (0.07, -0.03)])
	over(img, WHITE, ridge <= 0)
	guard = rbox((x - 0.07) * 0.7 + (y + 0.03) * 0.7, -(x - 0.07) * 0.7 + (y + 0.03) * 0.7, 0, 0, 0.04, 0.24, 0.012)
	over(img, INK, guard <= 0.015)
	over(img, GOLD, guard <= 0)
	return img


def step_flash(hi):
	img = hi.copy()
	img[..., :3] = img[..., :3] * 0.5 + img[..., 3:4] * np.array([1.0, 0.95, 0.8], np.float32) * 0.5  # washed toward warm white
	x, y = grid(hi.shape[0] // SS, SS, 1.0)
	r = np.hypot(x, y)
	glow(img, WHITE, r - 0.12, 0.16)
	flare = np.minimum(np.hypot(x / 0.95, y / 0.05), np.hypot(x / 0.05, y / 0.95)) - 1
	over(img, WHITE, np.exp(-np.maximum(flare, 0) * 6))
	over(img, CORE, r <= 0.16)
	return img


STEPS = (("1 bright dot", step_dot), ("2 small ring", step_small), ("3 full size", lambda hi: hi), ("4 weapon tip through", step_tip), ("5 firing flash", step_flash))


# The comparison sheet --------------------------------------------------------------------------------------------------------
DESIGNS = (
	("A  Ripple veil (thin, elegant)", "a one-arm spiral of fine ripples, double hairline rim, 36 beads,", "9 uneven needle rays; asymmetry: the rays and a lit arc"),
	("B  Bastion (bold, blocky)", "thick bevelled rim, 10 square notches, studs, a red-gem keystone,", "deep dark band, 3 fat off-centre ripples (a tunnel)"),
	("C  Sun wheel (in between)", "a 3-arm ripple spiral, rim with 16 wedge notches and dots,", "12 slanted rays, one long: the slant shows the turn"),
)
LABEL_W, REST_W, STEP_W, SMALL_W, ROW_H, HEAD_H = 640, 300, 230, 250, 300, 90
REST_PX = 260  # a design at rest; the current ring is drawn at REST_PX / 1.25
STEP_PX = 210


def background(kind, w, h):
	img = canvas(w, h)
	if kind == "vault":
		over(img, VAULT, np.ones((h, w)))
	else:
		t = np.repeat(np.linspace(0, 1, h, dtype=np.float32)[:, None], w, axis=1)
		over(img, ramp(t, [(0, SKY_TOP), (1, SKY_LOW)]), np.ones((h, w)))
	return img


def panel(kind, current, hires, art, masks):
	w = LABEL_W + REST_W + 5 * STEP_W + SMALL_W
	img = background(kind, w, HEAD_H + 4 * ROW_H)
	ink = WHITE if kind == "vault" else (40, 18, 8)

	def text(words, x0, y0, bold=False):
		piece = text_image(masks[(BOLD if bold else SANS, 26 if bold else 20, words)], ink)
		stamp(img, piece, x0, y0)

	text("On the vault brown" if kind == "vault" else "On the sunset sky (open-air stadium): gold must hold against orange", 20, 14, True)
	for j, (name, _) in enumerate(STEPS):
		text(name, LABEL_W + REST_W + j * STEP_W + 10, 56)
	text("far runner: 48, 24 px", LABEL_W + REST_W + 5 * STEP_W + 4, 56)
	text("at rest", LABEL_W + 10, 56)
	rows = [("Current: Art.Ring tinted gold", ("a plain glowing ring; drawn at 1 x", "(14 studs); the designs at 1.25 x"), current, None)]
	rows += [(d[0], d[1:], art[k], hires[k]) for d, k in zip(DESIGNS, "abc")]
	for i, (name, lines, small, hi) in enumerate(rows):
		y0 = HEAD_H + i * ROW_H
		text(name, 20, y0 + 20, True)
		for j, line in enumerate(lines):
			text(line, 20, y0 + 64 + 30 * j)
		px = REST_PX if hi is not None else int(REST_PX / 1.25)
		stamp(img, resize(small, px, px), LABEL_W + (REST_W - px) / 2, y0 + (ROW_H - px) / 2)
		sx = LABEL_W + REST_W + 5 * STEP_W
		stamp(img, resize(small, 48, 48), sx + 20, y0 + ROW_H / 2 - 24)
		stamp(img, resize(small, 24, 24), sx + 100, y0 + ROW_H / 2 - 12)
		if hi is None:
			continue
		for j, (_, step) in enumerate(STEPS):
			frame = finish(step(hi), hi.shape[0] // SS)
			stamp(img, resize(frame, STEP_PX, STEP_PX), LABEL_W + REST_W + j * STEP_W + (STEP_W - STEP_PX) / 2, y0 + (ROW_H - STEP_PX) / 2)
	return img


def portal_sheet(hires, art, masks):
	current = from_rgba8(read_png(CURRENT))
	current[..., :3] *= np.asarray(CURRENT_TINT, np.float32) / 255
	vault, sky = panel("vault", current, hires, art, masks), panel("sky", current, hires, art, masks)
	w = vault.shape[1]
	title_h = 120
	sheet = canvas(w, title_h + vault.shape[0] + sky.shape[0])
	over(sheet, (24, 22, 26), np.ones(sheet.shape[:2]))
	for j, line in enumerate(SHEET_TITLE):
		stamp(sheet, text_image(masks[(BOLD if j == 0 else SANS, 30 if j == 0 else 20, line)], WHITE), 20, 14 + j * 40 + (0 if j == 0 else 10))
	stamp(sheet, vault, 0, title_h)
	stamp(sheet, sky, 0, title_h + vault.shape[0])
	return sheet


SHEET_TITLE = (
	"Gates of Babylon portal drafts (proposed, for the owner's pick): drawn 1.25 x the current portal",
	"Each is a 512 x 512 transparent decal in its own colours (decal Color3 white), slowly turned in game; the weapon tip and flash are in-game parts and particles, shown here for staging.",
)


# 2. Ea's wind: a swirl cycle -------------------------------------------------------------------------------------------------
FW, FH = 300, 440  # one frame, px
WIND_ROWS = (
	# name, ribbons, turns along the height, seconds a turn, dashes, radius at the feet and at the tip (frame units)
	("Early charge (from 1.45 s): 4 ribbons, 1 turn per 0.8 s (proposed)", 4, 1.3, 0.8, 6, 0.9, 0.3),
	("Late charge (2.4 - 3.0 s): 6 ribbons, tighter, 1 turn per 0.35 s (proposed)", 6, 2.3, 0.35, 12, 0.72, 0.2),
)
WIND_NOTES = (
	"Read across: one turn of the swirl per row (8 frames, frame 8 leads back to frame 1); the ribbons in front of him run right to left. Faint copies behind each ribbon are its motion smear.",
	"Ribbons thicken and brighten toward Ea's tip and fade at both ends; those passing in front of him are drawn thin and faint so the pose stays readable; short dashes climb between them.",
	"Roblox build (proposed, cheapest that reads): the EnumaWind holder that already follows Ea's tip is turned about Ea's axis every frame at the turn rate (ramping with the drums);",
	"on it 4 (early) to 6 (late) Attachment pairs climb from his feet to the tip on a loop, each pair with a Trail (FaceCamera, LightEmission 1, WidthScale thin-thick-thin, Transparency faded at both",
	"ends, Lifetime about one turn: 0.8 s early, 0.35 s late). Orbit plus climb draws the helix in world space. Dashes: the existing Wind emitter. Cost: 1 part, up to 12 Attachments, 6 Trails,",
	"no new image (Trails use the uploaded Art.Shaft or none), no mesh upload. Not a rotating mesh with a scrolling texture: that needs a new mesh and image upload and cannot taper or fade each ribbon.",
)


def splat(buf, xs, ys, rs, vs, ss):
	"""Max-blend soft discs (frame units -> px) into buf: a stroke of varying width without a per-segment full-frame pass."""
	h, w = buf.shape
	for x0, y0, r0, v0 in zip(xs, ys, rs, vs):
		cx, cy, rp = (x0 + 1) / 2 * (w - 1), (y0 + FH / FW) / (2 * FH / FW) * (h - 1), max(r0 / 2 * (w - 1), 0.6 * ss)
		ax, bx, ay, by = int(cx - rp - 2), int(cx + rp + 3), int(cy - rp - 2), int(cy + rp + 3)
		if bx <= 0 or by <= 0 or ax >= w or ay >= h:
			continue
		ax, ay, bx, by = max(ax, 0), max(ay, 0), min(bx, w), min(by, h)
		yy, xx = np.mgrid[ay:by, ax:bx]
		cov = np.clip(rp + 0.5 * ss - np.hypot(xx - cx, yy - cy), 0, ss) / ss * v0
		np.maximum(buf[ay:by, ax:bx], cov, out=buf[ay:by, ax:bx])


def wind_figure(img, x, y):
	"""Stand-in for the king at the charge (a plain block figure, not the model) holding Ea up: grooves red, white ball at the tip."""
	parts = [rbox(x, y, -0.02, 0.86, 0.06, 0.2, 0.01), rbox(x, y, 0.13, 0.86, 0.06, 0.2, 0.01), rbox(x, y, 0.055, 0.45, 0.15, 0.22, 0.02), rbox(x, y, 0.055, 0.13, 0.1, 0.1, 0.02), rbox(x, y, 0.25, 0.5, 0.05, 0.2, 0.01), rbox(x, y, -0.14, 0.12, 0.05, 0.2, 0.01)]
	body = np.minimum.reduce(parts)
	over(img, INK, body <= 0.02)
	over(img, (205, 150, 52), body <= 0)
	over(img, (240, 196, 92), (body <= 0) & (x < 0.0))
	ea = rbox(x, y, -0.14, -0.55, 0.05, 0.5, 0.01)
	over(img, INK, ea <= 0.018)
	over(img, (40, 14, 14), ea <= 0)
	for gy in (-0.85, -0.6, -0.35):
		over(img, (230, 40, 40), (rbox(x, y, -0.14, gy, 0.05, 0.012) <= 0))
	r = np.hypot(x + 0.14, y + 1.1)
	glow(img, (255, 200, 200), r - 0.07, 0.07)
	over(img, WHITE, r <= 0.07)


def wind_frame(row, f, masks):
	"""Frame f of 8 of a wind row: helix ribbons round Ea's axis, back half behind the figure, front half thin over it."""
	_, n, turns, _, dashes, r_low, r_high = row
	ss = 2
	h, w = FH * ss, FW * ss
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	x, y = (xx + 0.5) / w * 2 - 1, ((yy + 0.5) / h * 2 - 1) * FH / FW
	img = canvas(w, h)
	over(img, ramp(y, [(-1.5, (78, 14, 18)), (1.5, (26, 5, 8))]), np.ones((h, w)))
	glow(img, (150, 20, 26), np.hypot(x + 0.14, y + 1.1) - 0.1, 0.35, 0.8)
	axis_x, y_low, y_high, tilt = -0.06, 1.12, -1.18, 0.16
	spin = 2 * np.pi * f / 8  # one turn a cycle: frame 8 leads back to frame 1
	back, front, smear = np.zeros((h, w), np.float32), np.zeros((h, w), np.float32), np.zeros((h, w), np.float32)

	def helix(phase, s0, length, width, samples):
		s = np.linspace(s0, s0 + length, samples)
		u = np.linspace(0, 1, samples)
		env = np.sin(np.pi * u) ** 0.7
		R = r_low + (r_high - r_low) * s
		th = phase + 2 * np.pi * turns * s
		px = axis_x + R * np.cos(th)
		py = y_low + (y_high - y_low) * s + tilt * R * np.sin(th)
		wd = width * (0.35 + 0.65 * s) * env
		val = env * (0.45 + 0.55 * s)
		return px, py, wd, val, np.sin(th) > 0

	for i in range(n):
		base = 2 * np.pi * i / n
		s0 = 0.04 + 0.12 * (i % 2)
		for lag, buf_alpha in ((0.0, 1.0), (0.18, 0.4), (0.36, 0.18)):
			px, py, wd, val, near = helix(base + spin - lag, s0, 0.82, 0.05, 700)
			if lag:
				splat(smear, px, py, wd * 0.8, val * buf_alpha, ss)
				continue
			splat(back, px[~near], py[~near], wd[~near], val[~near], ss)
			splat(front, px[near], py[near], wd[near] * 0.35, val[near] * 0.6, ss)
	for j in range(dashes):  # dashes climb one full height a cycle, so they loop too
		s0 = ((j * 0.37 + f / 8) % 1.0) * 0.85 + 0.05
		px, py, wd, val, near = helix(2 * np.pi * (j * 0.61) + spin + np.pi / n, s0, 0.05, 0.022, 40)
		splat(back if j % 2 else front, px, py, wd, val * 0.9, ss)
	over(img, (255, 150, 160), smear, 0.5)
	over(img, (255, 170, 180), np.clip(back * 1.6, 0, 1) ** 0.6, 0.5)  # a pink halo round each ribbon
	over(img, (255, 248, 248), back)
	wind_figure(img, x, y)
	over(img, (255, 170, 180), np.clip(front * 1.6, 0, 1) ** 0.6, 0.3)
	over(img, (255, 248, 248), front, 0.85)
	return img.reshape(FH, ss, FW, ss, 4).mean(axis=(1, 3))


def wind_strip(masks):
	gap, label, title_h = 8, 40, 70
	row_h = label + FH + gap
	w = 8 * FW + 9 * gap
	img = canvas(w, title_h + 2 * row_h + 30 + 32 * len(WIND_NOTES))
	over(img, (20, 16, 18), np.ones(img.shape[:2]))
	stamp(img, text_image(masks[(BOLD, 30, WIND_TITLE)], WHITE), gap, 18)
	for r, row in enumerate(WIND_ROWS):
		y0 = title_h + r * row_h
		stamp(img, text_image(masks[(BOLD, 22, row[0])], WHITE), gap, y0 + 6)
		for f in range(8):
			x0 = gap + f * (FW + gap)
			stamp(img, wind_frame(row, f, masks), x0, y0 + label)
			stamp(img, text_image(masks[(SANS, 18, f"{f + 1}   {f * row[3] / 8:.2f} s")], WHITE), x0 + 8, y0 + label + FH - 30)
	for j, line in enumerate(WIND_NOTES):
		stamp(img, text_image(masks[(SANS, 19, line)], (230, 222, 222)), gap, title_h + 2 * row_h + 12 + 32 * j)
	return img


WIND_TITLE = "Enuma Elish charge: Ea's white wind swirls round Ea and him (draft, proposed; stand-in figure)"


def text_wanted():
	reqs = {(BOLD, 26, "On the vault brown"), (BOLD, 26, "On the sunset sky (open-air stadium): gold must hold against orange"), (SANS, 20, "far runner: 48, 24 px"), (SANS, 20, "at rest")}
	reqs |= {(SANS, 20, s[0]) for s in STEPS} | {(BOLD, 26, "Current: Art.Ring tinted gold"), (SANS, 20, "a plain glowing ring; drawn at 1 x"), (SANS, 20, "(14 studs); the designs at 1.25 x")}
	for d in DESIGNS:
		reqs |= {(BOLD, 26, d[0]), (SANS, 20, d[1]), (SANS, 20, d[2])}
	reqs |= {(BOLD, 30, SHEET_TITLE[0]), (SANS, 20, SHEET_TITLE[1]), (BOLD, 30, WIND_TITLE)}
	reqs |= {(BOLD, 22, row[0]) for row in WIND_ROWS} | {(SANS, 19, line) for line in WIND_NOTES}
	reqs |= {(SANS, 18, f"{f + 1}   {f * row[3] / 8:.2f} s") for row in WIND_ROWS for f in range(8)}
	return sorted(reqs)


def main():
	os.makedirs(PORTAL_DIR, exist_ok=True)
	os.makedirs(WIND_DIR, exist_ok=True)
	masks = text_masks(text_wanted())
	hires, art = {}, {}
	for k, draw in (("a", draw_a), ("b", draw_b), ("c", draw_c)):
		hires[k] = draw(512)
		art[k] = from_rgba8(to_rgba8(finish(hires[k], 512, os.path.join(PORTAL_DIR, f"portal_{k}.png"))))
	write_png(os.path.join(PORTAL_DIR, "portal_sheet.png"), to_rgba8(portal_sheet(hires, art, masks)))
	write_png(os.path.join(WIND_DIR, "ea_wind_strip.png"), to_rgba8(wind_strip(masks)))


if __name__ == "__main__":
	main()
