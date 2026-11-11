--!nonstrict
-- The Elf Mage's rhythm circles for her golem slam (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"). Pure:
-- server and client derive the same circles from one seed, so the circles need no network traffic. The server judges the click
-- times only; where a click landed is the client's hit test. All numbers proposed.
local BossOsu = {}

BossOsu.Count = 4
BossOsu.ApproachSeconds = 1.0 -- proposed: a circle shows this long before its beat
BossOsu.Tolerance = 0.18 -- proposed: s either side of the beat
BossOsu.Diameter, BossOsu.DiameterPhone = 0.12, 0.16 -- proposed: of the screen height
-- Leads: seconds before the moment, latest beat last. The last at 0.53 or more keeps every valid click 0.35 s before the
-- moment (the Dodge bar's server margin); gaps stay at least 0.35 s.
local LEADS = { 1.85, 1.40, 0.95, 0.55 } -- proposed
local LEAD_JITTER = 0.02
local LOW, HIGH = 0.28, 0.72 -- the square the 2 x 2 cells split
local SPOT_JITTER = 0.025
BossOsu.OpenSeconds = 2.875 -- largest Lead + ApproachSeconds: the UI opens and the server accepts from here

-- Circles of one Slam moment, in click order: { { X, Y, Lead } x Count }. X, Y: 0..1 of the screen. Lead: s before the moment.
function BossOsu.Circles(userId, startAt, index)
	local random = Random.new((userId % 1e6) * 31337 + (math.floor(startAt) % 1e6) * 613 + index * 7919 + 104729)
	random:NextNumber() -- nearby seeds start alike
	local cells = { 1, 2, 3, 4 }
	for i = #cells, 2, -1 do
		local j = random:NextInteger(1, i)
		cells[i], cells[j] = cells[j], cells[i]
	end
	local size = (HIGH - LOW) / 2
	local circles = {}
	for k = 1, BossOsu.Count do
		local cell = cells[k] - 1
		table.insert(circles, {
			X = LOW + (cell % 2 + 0.5) * size + (random:NextNumber() * 2 - 1) * SPOT_JITTER,
			Y = LOW + (cell // 2 + 0.5) * size + (random:NextNumber() * 2 - 1) * SPOT_JITTER,
			Lead = LEADS[k] + (random:NextNumber() * 2 - 1) * LEAD_JITTER,
		})
	end
	return circles
end

-- True when stamp is within Tolerance (+ slack) of momentAt - lead.
function BossOsu.Judge(lead, momentAt, stamp, slack)
	return math.abs(stamp - (momentAt - lead)) <= BossOsu.Tolerance + (slack or 0)
end

return BossOsu
