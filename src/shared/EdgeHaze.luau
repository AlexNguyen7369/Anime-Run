--!nonstrict
-- Band-edge haze (World 2 only; owner 2026-11-27 "1a", design log; docs/BIOME_ENVIRONMENT_SPEC.md 5.4, docs/WORLD2_SPEC.md
-- "Band-edge haze"; values proposed). Pure: where one track's land meets the next (the midline, where the nearer centre
-- line changes), a ring of low soft curtains thickens the haze, so the next track's skyline does not show from a run
-- camera while the road view and the sky stay as they are. Client/EdgeHaze draws them.
local EdgeHaze = {}

EdgeHaze.REACH = 700 -- proposed: studs out from the road a midline is looked for; none past it (no track that near)
EdgeHaze.INSET = 25 -- proposed: studs the curtain stands inside its own edge
EdgeHaze.ROAD_CLEAR = 60 -- proposed: no curtain point nearer any centre line (the joints between tracks)
EdgeHaze.JUMP = 160 -- studs: two neighbouring curtain points farther apart than this are not joined (a corner)
EdgeHaze.HEIGHT = 260 -- proposed: studs tall
EdgeHaze.BOTTOM = 0.35 -- proposed: transparency at the ground, fading to 1 at the top
EdgeHaze.ZONE_MAX = 600 -- most curtains a zone
EdgeHaze.TOTAL_MAX = 3000 -- most curtains in all
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

return EdgeHaze
