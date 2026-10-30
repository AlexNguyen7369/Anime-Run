--!nonstrict
-- Global leaderboards (docs/LEADERBOARD_SPEC.md): the boards, their signs and their OrderedDataStores.
local LeaderboardConfig = {}

LeaderboardConfig.TOP_N = 10
LeaderboardConfig.REFRESH = 60 -- seconds between reads
LeaderboardConfig.WRITE_INTERVAL = 300 -- seconds between writes of the players in the server
LeaderboardConfig.NO_DATA = "No data yet"

-- In sign order. A store name is permanent: a new one starts an empty board.
LeaderboardConfig.Boards = {
	{ Id = "Speed", Title = "TOP SPEED", Store = "LB_Speed_v3" }, -- v3: log-scaled score; v2 held raw scores (Speed stat scale, owner 2026-10-30)
	{ Id = "MoneyEarned", Title = "MONEY EARNED", Store = "LB_MoneyEarned_v1" },
	{ Id = "Rolls", Title = "MOST ROLLS", Store = "LB_Rolls_v1" },
	{ Id = "RarestCar", Title = "RAREST CHARACTER", Store = "LB_RarestCar_v1" },
}

-- Signs: local (x, z) of each board's centre on the plaza: a row along its west edge (x = SIGN_X), facing the spawn,
-- read left to right from the spawn (z = SIGN_Z[i]).
LeaderboardConfig.SIGN_SIZE = Vector3.new(32, 20, 1)
LeaderboardConfig.SIGN_X = 40
LeaderboardConfig.SIGN_Z = { -32, -64, -96, -128 }

-- Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a): local (X, Z) of its centre, south-east of the spawn.
LeaderboardConfig.BEST_ROLL = {
	X = 148,
	Z = -140,
	RADIUS = 12,
	HEIGHT = 2,
	CAR_SCALE = 3.5, -- the car stands at this scale, so it reads from across the hub
	SPIN = 45, -- degrees per second (client only)
	TEXT_DISTANCE = 150, -- studs: MaxDistance of the stats above the car
}

return LeaderboardConfig
