--!nonstrict
-- HUD icons: the Tab tilt set (design doc 4.40, owner 2026-11-10), source PNGs assets/ui/hud_tabtilt/; each comment
-- names its uploaded Decal. Auto uses the AutoPlay art (Tab tilt has no whole Auto icon).
-- Standalone transparent images, no atlas rectangles.
return {
	-- Tab tilt: hud_tabtilt/Shop.png, Decal 110580195719414
	Shop = { Image = "rbxassetid://77923693818307" },
	-- Tab tilt: hud_tabtilt/Items.png, Decal 78892919732157
	Items = { Image = "rbxassetid://136513915327711" },
	-- Tab tilt: hud_tabtilt/Index.png, Decal 132282595074039
	Index = { Image = "rbxassetid://91719313688362" },
	-- Tab tilt: hud_tabtilt/Upgrade.png, Decal 129349138813136
	Upgrade = { Image = "rbxassetid://118850768375463" },
	-- Tab tilt: hud_tabtilt/Stats.png, Decal 73954775657229
	Stats = { Image = "rbxassetid://81847846244460" },
	-- Tab tilt: hud_tabtilt/Rebirth.png, Decal 85715725860894
	Rebirth = { Image = "rbxassetid://121256395009677" },
	-- Tab tilt: hud_tabtilt/Daily.png, Decal 83054825153265
	Daily = { Image = "rbxassetid://131962436360313" },
	-- Tab tilt: hud_tabtilt/Quests.png, Decal 79061962625846
	Quests = { Image = "rbxassetid://90087117762301" },
	-- Tab tilt: hud_tabtilt/Market.png, Decal 98688871503572
	Market = { Image = "rbxassetid://105239292796755" },
	-- Tab tilt: hud_tabtilt/Settings.png, Decal 134508580763362
	Settings = { Image = "rbxassetid://75526281382537" },
	-- Tab tilt: hud_tabtilt/Gem.png, Decal 70694025124718
	Gem = { Image = "rbxassetid://115837117925526" },
	-- Tab tilt has no whole Auto icon: HudChrome draws AutoPlay under AutoArrows. Point Auto at AutoPlay's Image id.
	Auto = { Image = "rbxassetid://85172904732896" },
	-- Tab tilt: hud_tabtilt/AutoArrows.png, Decal 123515801089798 (arrows alone, centred on the image)
	AutoArrows = { Image = "rbxassetid://71294529066561" },
	-- Tab tilt: hud_tabtilt/AutoPlay.png, Decal 108577153797017 (tab and still green triangle)
	AutoPlay = { Image = "rbxassetid://85172904732896" },
	-- Design doc 4.40 boss popup icon (the purple horned mask). Tab tilt: hud_tabtilt/Boss.png, Decal 101005378032856
	Boss = { Image = "rbxassetid://137818614263751" },
}
