--!nonstrict
-- Global leaderboards (docs/LEADERBOARD_SPEC.md): the boards, their signs and their OrderedDataStores.
local LeaderboardConfig = {}

LeaderboardConfig.TOP_N = 10
LeaderboardConfig.REFRESH = 60 -- seconds between reads
LeaderboardConfig.WRITE_INTERVAL = 300 -- seconds between writes of the players in the server
LeaderboardConfig.NO_DATA = "No data yet"

-- In sign order. A store name is permanent: a new one starts an empty board.
LeaderboardConfig.Boards = {
	-- The Speed board (LB_Speed_v3) is removed with the Speed stat (owner 2026-11-01, design doc 4.13); its store is
	-- left untouched.
	{ Id = "MoneyEarned", Title = "MONEY EARNED", Store = "LB_MoneyEarned_v1" },
	{ Id = "Rolls", Title = "MOST ROLLS", Store = "LB_Rolls_v1" },
	{ Id = "RarestCar", Title = "RAREST CHARACTER", Store = "LB_RarestCar_v1" },
}

-- Signs: local (x, z) of each board's centre on the plaza: a row along its west edge (x = SIGN_X), facing the spawn,
-- read left to right from the spawn (z = SIGN_Z[i]).
LeaderboardConfig.SIGN_SIZE = Vector3.new(32, 20, 1)
LeaderboardConfig.SIGN_X = 40
LeaderboardConfig.SIGN_Z = { -32, -64, -96, -128 }

-- Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md 3a): local (X, Z) of its centre, in the gap between Plots 1 and 2
-- (WORLD_REDESIGN_SPEC 7).
LeaderboardConfig.BEST_ROLL = {
	X = 161.34, -- hub-local: world (43.3, 14.3), the summon wing's spawn end (design doc 4.24 Two wings, proposed)
	Z = -65.658,
	RADIUS = 9,
	HEIGHT = 2,
	CAR_SCALE = 3.5, -- the car stands at this scale, so it reads from across the hub
	SPIN = 45, -- degrees per second (client only)
	TEXT_DISTANCE = 150, -- studs: MaxDistance of the stats above the car
}

return LeaderboardConfig
