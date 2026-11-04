--!nonstrict
-- The UI sound ledger (design doc 4.33 and section 5, docs/UI_FEEDBACK_SPEC.md section 1): one row per slot. The Sounds
-- themselves are assets/sfx/ImpactSounds/<Slot>.model.json: a swap edits the id there and here.
local UiSounds = {}

-- What the review covered: Roblox's asset details say free and name this creator; the name has no anime IP; a Sound holds
-- no script. Nobody has heard them yet (docs/UI_AUDIT.md).
local REVIEWED = "2026-11-04 ui-juice u1, asset details only, not heard"

UiSounds.Assets = {
	Tap = {
		Id = "rbxassetid://9120888980",
		Creator = "ProSoundEffects",
		Name = "Wood Hits Board Impacts On Fence Post 7 (SFX)",
		Reviewed = REVIEWED,
	},
	Thunk = {
		Id = "rbxassetid://9118598279",
		Creator = "ProSoundEffects",
		Name = "Rock Hit Dirt Impact 14 (SFX)",
		Reviewed = REVIEWED,
	},
	Crack = {
		Id = "rbxassetid://9118617342",
		Creator = "ProSoundEffects",
		Name = "Rock Impact Large Hit Scrape 1 (SFX)",
		Reviewed = REVIEWED,
	},
	Boom = {
		Id = "rbxassetid://9113225986",
		Creator = "ProSoundEffects",
		Name = "Axe Impact Giant Thuddy Hits On Wood Floor 5 (SFX)",
		Reviewed = REVIEWED,
	},
	Slash = {
		Id = "rbxassetid://9120704057",
		Creator = "ProSoundEffects",
		Name = "Whoosh Combo Of Impacts Bys 4 (SFX)",
		Reviewed = REVIEWED,
	},
	Chime = {
		Id = "rbxassetid://9116394545",
		Creator = "ProSoundEffects",
		Name = "Magic Glows Soft Clusters Of Chiming Hits 1 (SFX)",
		Reviewed = REVIEWED,
	},
	Whoosh = {
		Id = "rbxassetid://9126283272",
		Creator = "ProSoundEffects",
		Name = "Wood Swish Ruler Whoosh Fast Movement In Air (SFX)",
		Reviewed = REVIEWED,
	},
	Coin = {
		Id = "rbxassetid://135483737426662",
		Creator = "G00byBBQSauce",
		Name = "Coin Collect",
		Reviewed = REVIEWED,
	},
	Denied = {
		Id = "rbxassetid://72577143736585",
		Creator = "killerguest7964",
		Name = "Buzzer WRONG",
		Reviewed = REVIEWED,
	},
}

return UiSounds
