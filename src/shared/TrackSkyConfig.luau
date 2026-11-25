--!nonstrict
-- World 2 track skies (owner 2026-11-25, owner question 33 "Four tracks"; docs/WORLD2_SPEC.md "Track skies"): Hell's Gate,
-- Demon Castle, Golden City and Ant Island get in-house gradient skyboxes (ledger rows Kit.draftSky). The switch stays off
-- until the owner has seen the renders, the images are uploaded, their ids are in the rows and the rules audit signed them.
-- While off, and for any row whose ids are still 0, every track shows the place's own sky as today (BiomeEnvironment.Row).
local TrackSkyConfig = {}

TrackSkyConfig.LIVE = false

return TrackSkyConfig
