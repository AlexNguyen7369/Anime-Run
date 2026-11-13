--!nonstrict
-- Track power-ups (design doc 4.44, docs/POWERUP_SPEC.md). The server rolls each player's own set when a track starts
-- and applies every pickup (Server/RaceService); Client/PowerUpView only draws them.
local StaminaConfig = require(script.Parent.StaminaConfig)

local PowerUpConfig = {}

PowerUpConfig.SPEED_MULTI = 1.2 -- owner 2026-11-12 (was 1.5); may pass MAX_CRUISE
PowerUpConfig.SPEED_SECONDS = 2 -- owner 2026-11-12 (was 3)
PowerUpConfig.STAMINA_SECONDS = 3 -- owner 2026-11-12 (was 5); may overfill the seconds, the bar stays full
PowerUpConfig.STAMINA_SECONDS_LATE = 2 -- owner 2026-11-12: past Track 5
PowerUpConfig.LATE_FROM_TRACK = 6

-- Seconds a Stamina power-up gives on track `trackNumber` (owner 2026-11-12: 3 s on Tracks 1-5, 2 s past Track 5)
function PowerUpConfig.StaminaSeconds(trackNumber)
	if (trackNumber or 1) >= PowerUpConfig.LATE_FROM_TRACK then
		return PowerUpConfig.STAMINA_SECONDS_LATE
	end
	return PowerUpConfig.STAMINA_SECONDS
end
PowerUpConfig.PER_STUDS = 1000 -- placeholder: about 1 power-up per this many studs of track
PowerUpConfig.EDGE = 0.1 -- proposed: none in the first or last 10% of a track
PowerUpConfig.MIN_GAP = 300 -- proposed: studs between two power-ups

-- Look (proposed): orange chevrons for Speed, the stamina bar's blue for Stamina.
PowerUpConfig.COLORS = { Speed = Color3.fromRGB(255, 154, 31), Stamina = StaminaConfig.COLORS.Full }

-- The set for a track from arc distance `from`, `length` studs long: { { Id, Kind, Dist }, ... } in Dist order.
-- One per equal stretch of the middle 80%, jittered inside its stretch so neighbours stay MIN_GAP apart.
function PowerUpConfig.Roll(from, length, rng)
	rng = rng or Random.new()
	local list = {}
	if length <= 0 then
		return list
	end
	local count = math.ceil(length / PowerUpConfig.PER_STUDS)
	local span = length * (1 - 2 * PowerUpConfig.EDGE)
	local width = span / count
	local jitter = math.max(0, width - PowerUpConfig.MIN_GAP) / 2
	for i = 1, count do
		local centre = from + length * PowerUpConfig.EDGE + width * (i - 0.5)
		table.insert(list, {
			Id = i,
			Kind = rng:NextNumber() < 0.5 and "Speed" or "Stamina", -- proposed 50/50
			Dist = centre + (jitter > 0 and rng:NextNumber(-jitter, jitter) or 0),
		})
	end
	return list
end

return PowerUpConfig
