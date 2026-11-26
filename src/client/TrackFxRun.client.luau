--!nonstrict
-- Starts Client/TrackFx: the World 2 track effects draft. It builds nothing while TrackFxConfig.LIVE is false (owner
-- approval pending, docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)") and never in World 1.
if not game:IsLoaded() then
	game.Loaded:Wait() -- WorldConfig reads ReplicatedStorage.WorldId (docs/BUGS.md w2-worldid-race)
end
require(script.Parent:WaitForChild("TrackFx")).Start()
