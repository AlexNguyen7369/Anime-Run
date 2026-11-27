--!nonstrict
-- Band-edge fog (World 2 only; owner 2026-11-27 "1a", then "Dense fog band (Recommended)", design log; docs/BIOME_ENVIRONMENT_SPEC.md
-- 5.4, docs/WORLD2_SPEC.md "Band-edge haze"; values proposed). Pure: where one track's land meets the next (the midline,
-- where the nearer centre line changes), a near-solid soft fog band about 200 studs tall stands just inside the land
-- edge, so the next track's skyline does not show from a run camera while the road and the sky stay as they are.
-- Client/EdgeHaze draws it as thin Part bands (Beams do not draw past about 500 studs).
local EdgeHaze = {}

EdgeHaze.REACH = 700 -- proposed: studs out from the road a midline is looked for; none past it (no track that near)
EdgeHaze.INSET = 25 -- proposed: studs the curtain stands inside its own edge
EdgeHaze.ROAD_CLEAR = 60 -- proposed: no curtain point nearer any centre line (the joints between tracks)
EdgeHaze.JUMP = 160 -- studs: two neighbouring curtain points farther apart than this are not joined (a corner)
-- proposed: the fog band's look bottom to top, { top (studs above the ground), transparency seen }: near solid to
-- 150, then a soft fade in 10-stud steps so it reads as fog, not a box (Studio 2026-11-27: 15-stud steps showed)
EdgeHaze.BANDS = {
	{ 150, 0.02 },
	{ 160, 0.12 },
	{ 170, 0.24 },
	{ 180, 0.36 },
	{ 190, 0.48 },
	{ 200, 0.6 },
	{ 210, 0.72 },
	{ 220, 0.84 },
	{ 230, 0.93 },
}
EdgeHaze.HEIGHT = 230 -- the band's top (the last step's)
EdgeHaze.BASE = -3 -- studs: every layer starts here, just below the ground
EdgeHaze.LAYER_GAP = 0.3 -- studs between nested layers (no two coplanar)
EdgeHaze.ZONE_MAX = 600 -- most curtain segments a zone
EdgeHaze.TOTAL_MAX = 3000 -- most curtain segments in all
EdgeHaze.PANEL_MAX = 1024 -- studs: longest panel (straight run of segments drawn as one)
EdgeHaze.PANEL_TOL = 6 -- studs: every joined segment end lies this near its panel's line
EdgeHaze.ZONE_PARTS_MAX = 1500 -- most fog parts a zone (panels x layers)
EdgeHaze.MID_TOL = 12 -- studs (tests): a curtain's midline point is this near as far from both centre lines

-- The band-edge haze is World 2's only (World 1 keeps its spiral and its own look)
function EdgeHaze.Enabled(worldId)
	return worldId == 2
end

-- Curtains along track n's own land edge: { { A = Vector2, B = Vector2, MidA = Vector2 }, ... } (A, B the curtain's ends
-- in XZ, MidA the midline point behind A). `polys`: n -> { Vector2 } centre-line points (the published BiomeZone_<n>,
-- POLY_STEP apart); `plaza`: the plaza radius (no curtain inside it).
function EdgeHaze.EdgesFor(polys, n, plaza)
	local own = polys[n]
	if not own or #own < 3 then
		return {}
	end
	plaza = plaza or 0
	local others = {}
	for m, list in polys do
		if m ~= n then
			for _, q in list do
				table.insert(others, q)
			end
		end
	end
	local all = {}
	for _, list in polys do
		for _, q in list do
			table.insert(all, q)
		end
	end
	local function clear(c)
		if c.Magnitude <= plaza then
			return false
		end
		local r2 = EdgeHaze.ROAD_CLEAR * EdgeHaze.ROAD_CLEAR
		for _, q in all do
			local d = c - q
			if d:Dot(d) < r2 then
				return false
			end
		end
		return true
	end
	-- on this track's ground by its nearest centre-line point, with INSET / 2 to spare
	local function owned(c)
		local cOwn, cOther = math.huge, math.huge
		for _, q in own do
			cOwn = math.min(cOwn, (c - q).Magnitude)
		end
		for _, q in others do
			cOther = math.min(cOther, (c - q).Magnitude)
		end
		return cOwn + EdgeHaze.INSET / 2 < cOther
	end
	local segs = {}
	for _, side in { -1, 1 } do
		local prev = nil -- { C, M } of the previous point on this side
		for i = 1, #own do
			local p = own[i]
			local a, b = own[math.max(1, i - 1)], own[math.min(#own, i + 1)]
			local t = b - a
			local cur = nil
			if t.Magnitude > 1e-6 then
				t = t.Unit
				local normal = Vector2.new(-t.Y, t.X) * side
				local best = EdgeHaze.REACH
				for _, q in others do
					local d = q - p
					local dn = d:Dot(normal)
					if dn > 1 then
						local s = d:Dot(d) / (2 * dn) -- where the square line is as far from q as from p
						if s < best then
							best = s
						end
					end
				end
				if best < EdgeHaze.REACH and best > EdgeHaze.INSET + EdgeHaze.ROAD_CLEAR then
					local m, c = p + normal * best, p + normal * (best - EdgeHaze.INSET)
					-- in a bend the square line's point is not the midline: keep it only where it is as far from the
					-- nearest own centre-line point as from the nearest other one
					local dOwn, dOther = math.huge, math.huge
					for _, q in own do
						dOwn = math.min(dOwn, (m - q).Magnitude)
					end
					for _, q in others do
						dOther = math.min(dOther, (m - q).Magnitude)
					end
					-- and the curtain itself on this track's ground, not the next's
					if math.abs(dOwn - dOther) <= EdgeHaze.MID_TOL / 2 and owned(c) and clear(c) then
						cur = { c, m }
					end
				end
			end
			if
				cur
				and prev
				and (cur[1] - prev[1]).Magnitude <= EdgeHaze.JUMP
				and clear((cur[1] + prev[1]) / 2)
				and owned((cur[1] + prev[1]) / 2)
			then
				table.insert(segs, { A = prev[1], B = cur[1], MidA = prev[2] })
			end
			prev = cur
		end
	end
	return segs
end

-- The parts that draw the band, bottom to top: nested layers that all start at BASE, { top, transparency }. Each band
-- step is the product of the layers over it (one colour, so seen transparency multiplies), and every layer is at least
-- the near-solid height: Roblox stops drawing small parts sooner with distance, so thin top strips vanished on far
-- panels and stepped the top line (Studio 2026-11-27).
function EdgeHaze.Layers()
	local layers = {}
	local b = EdgeHaze.BANDS
	for k = 1, #b do
		local t = k < #b and b[k][2] / b[k + 1][2] or b[k][2]
		table.insert(layers, { b[k][1], t })
	end
	return layers
end

-- Straight runs of joined segments as single panels { A, B } (fewer parts): a run continues while each next segment
-- starts where the last ended, the panel stays at most PANEL_MAX long and every segment end in it lies within
-- PANEL_TOL of the panel's line
function EdgeHaze.Panels(segs)
	local panels = {}
	local run = nil -- { points }
	local function lineOk(points)
		local a, b = points[1], points[#points]
		local ab = b - a
		local len = ab.Magnitude
		if len > EdgeHaze.PANEL_MAX then
			return false
		end
		if len < 1e-6 then
			return true
		end
		local u = ab / len
		for i = 2, #points - 1 do
			local d = points[i] - a
			if math.abs(d.X * u.Y - d.Y * u.X) > EdgeHaze.PANEL_TOL then
				return false
			end
		end
		return true
	end
	local function flush()
		if run then
			table.insert(panels, { A = run[1], B = run[#run] })
		end
		run = nil
	end
	for _, sg in segs do
		if run and (run[#run] - sg.A).Magnitude < 1e-3 then
			table.insert(run, sg.B)
			if not lineOk(run) then
				table.remove(run)
				flush()
				run = { sg.A, sg.B }
			end
		else
			flush()
			run = { sg.A, sg.B }
		end
	end
	flush()
	return panels
end

return EdgeHaze
