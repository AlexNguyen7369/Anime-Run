--!nonstrict
-- World 2 track skies (owner 2026-11-25, owner question 33 "Four tracks"; docs/WORLD2_SPEC.md "Track skies"): Hell's Gate,
-- Demon Castle, Golden City and Ant Island get in-house gradient skyboxes (ledger rows Kit.draftSky). Owner 2026-11-26,
-- choice F: "the four track skies ... are uploaded, then each is reviewed and checked in Studio before it is switched on".
-- Steps: upload (done), rules review of every image (done), ids in the rows, a Studio check of each sky (its faces in its
-- zone only, the default back on leaving, the fog meeting the sky, Ant Island's light), then LIVE = true in its own commit.
-- While off, or for a row with an id 0 or unreviewed, every track shows the place's own sky (BiomeEnvironment.Row).
local TrackSkyConfig = {}

TrackSkyConfig.LIVE = true -- switched on for the Studio check before merging (owner choice F, 2026-11-26)

return TrackSkyConfig
