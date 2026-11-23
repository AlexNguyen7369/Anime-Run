--!nonstrict
-- Tracks panel card copy (design doc 4.15, docs/TRACKS_AND_BIOMES_SPEC.md "Track card definitions"), by track number.
-- Road: rbxassetid of the track's road screenshot. Blurb: its proposed one-line definition, tweaked names only.

local WorldConfig = require(script.Parent.WorldConfig)

local WORLD1 = {
	[1] = {
		Road = "rbxassetid://91684524991802",
		Blurb = "Hidden ninja village of Narito's youth, left a crater by Paine's assault.",
	},
	[2] = {
		Road = "rbxassetid://104268253792616",
		Blurb = "Selle's tournament ring on the wasteland, where the fate of the world is fought.",
	},
	[3] = {
		Road = "rbxassetid://118755457982374",
		Blurb = "Island harbor ruled by Arlon's fish-man crew, until Lufy's pirates land.",
	},
	[4] = {
		Road = "rbxassetid://87822821986975",
		Blurb = "Wisteria-ringed mountain where slayers train and demons like Akazo hunt by moonlight.",
	},
	[5] = {
		Road = "rbxassetid://114828278568180",
		Blurb = "Sukana fights Jogoh and Mahoraka here, and the streets burn to molten rock.",
	},
	[6] = {
		Road = "rbxassetid://108386941987005",
		Blurb = "Home of the hero academy, where Shigaraky's villains strike at the next generation.",
	},
	[7] = {
		Road = "rbxassetid://83860642947314",
		Blurb = "Subway station packed with crowds trapped on Halloween night, with Mahitoh waiting below.",
	},
	[8] = {
		Road = "rbxassetid://137423732311551",
		Blurb = "Sky island above the clouds, ruled by the self-made god Enelu and his golden bell.",
	},
	[9] = {
		Road = "rbxassetid://91240645905742",
		Blurb = "Endless white sand under a black sky, where Ulquiorro guards the dome palace.",
	},
	[10] = { Road = "rbxassetid://131465650836799", Blurb = "Green planet where Freezo hunts the wish-granting orbs." },
}

-- World 2 (design doc 4.47, docs/WORLD2_SPEC.md "Tracks"): proposed copy, tweaked names only. Road screenshots come
-- after the owner approves the Blender drafts.
local WORLD2 = {
	[1] = { Blurb = "Night streets of the devil hunters, where Katanah Man's blades wait in the alleys." },
	[2] = { Blurb = "The Demon King's black castle, its stairs guarded by Barran's red sky." },
	[3] = { Blurb = "A ghost town of cracked avenues and meteor craters, hunted by Garoo." },
	[4] = { Blurb = "A cursed mountain tunnel road where Turbo Grammy races anyone after dark." },
	[5] = { Blurb = "A city wrecked by kaiju, where Kaijo No. 9 slips past the defense force walls." },
	[6] = { Blurb = "Flowered plains and old elven ruins, where Ora's puppet army once marched." },
	[7] = { Blurb = "A black volcanic island hollowed by the ant nest, ruled by Berru." },
	[8] = { Blurb = "The monsters' underground den of caverns and bone bridges, deep in Orochy's lair." },
	[9] = { Blurb = "A city turned to gold by Machto's curse, frozen in one golden instant." },
	[10] = { Blurb = "The red sky of Hell, a field of doors, and Makina waiting at the last gate." },
}

return WorldConfig.Id == 2 and WORLD2 or WORLD1
