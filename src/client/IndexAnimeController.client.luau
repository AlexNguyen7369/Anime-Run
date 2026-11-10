--!nonstrict
local gui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("RacerIndex")
local band=gui:WaitForChild("Panel"):WaitForChild("Face"):WaitForChild("Header"):WaitForChild("Face")
band:WaitForChild("RelicsTab")
task.wait(0.5)
require(script.Parent:WaitForChild("IndexAnimeStyle")).Apply(gui)
