--!nonstrict
-- The Stone Golem's rhythm circles for its slam and sweep (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf
-- Mage"). Pure: server and client derive the same circles from one seed, so the circles need no network traffic. The server
-- judges the click times only; where a click landed is the client's hit test. All numbers proposed (owner eased 2026-11-11).
local BossOsu = {}

BossOsu.Count = 3
BossOsu.ApproachSeconds = 1.0 -- a circle shows this long before its beat
BossOsu.Tolerance = 0.28 -- s either side of the beat
BossOsu.Diameter, BossOsu.DiameterPhone = 0.145, 0.19 -- of the screen height
-- Leads: seconds before the attack, latest beat last, all inside its 2 s window. Gaps stay >= 0.58 > 2 x Tolerance; the last
-- lead >= 0.66 keeps every valid click 0.35 s before the attack (the Dodge bar's server margin).
local LEADS = { 1.92, 1.30, 0.68 }
local LEAD_JITTER = 0.02
-- Centres on 3 of this square's 4 corners: on any landscape screen they sit >= 0.35 apart on one axis (over one phone diameter of the
-- height) and every circle stays inside the middle 60%.
local LOW, HIGH = 0.31, 0.69
local SPOT_JITTER = 0.015
BossOsu.OpenSeconds = 2.94 -- largest Lead + ApproachSeconds: the UI opens and the server accepts from here

-- Circles of one golem attack, in click order: { { X, Y, Lead } x Count }. X, Y: 0..1 of the screen. Lead: s before the attack.
-- startAt: BossMinionStart; index: the golem's attack number k.
function BossOsu.Circles(userId, startAt, index)
	local random = Random.new((userId % 1e6) * 31337 + (math.floor(startAt) % 1e6) * 613 + index * 7919 + 104729)
	random:NextNumber() -- nearby seeds start alike
	local corners = { 1, 2, 3, 4 }
	for i = #corners, 2, -1 do
		local j = random:NextInteger(1, i)
		corners[i], corners[j] = corners[j], corners[i]
	end
	local circles = {}
	for k = 1, BossOsu.Count do
		local corner = corners[k] - 1
		table.insert(circles, {
			X = (corner % 2 == 0 and LOW or HIGH) + (random:NextNumber() * 2 - 1) * SPOT_JITTER,
			Y = (corner // 2 == 0 and LOW or HIGH) + (random:NextNumber() * 2 - 1) * SPOT_JITTER,
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
