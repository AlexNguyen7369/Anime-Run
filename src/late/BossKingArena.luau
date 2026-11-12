--!nonstrict
-- The Golden King's arena images (design doc 4.37 "The Golden King's own arena", 7 "Join size"; BOSS_EVENT_SPEC "The Golden
-- King's arena"): name -> "rbxassetid://<id>". Per-boss late data: in ServerStorage.LateData, delivered to ReplicatedStorage.LateData
-- with his poses (BossCatalog row's Arena) and removed after his event, never loaded at join. Client/BossKingArena builds the arena
-- from engine primitives and materials today: no arena image is uploaded yet, so the list is empty. The draft's textures
-- (tools/blender/arena/build_king_arena.py: paving, masonry, glazed brick, meander, the stands' steps) go here once uploaded.
return {}
